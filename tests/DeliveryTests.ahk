TestDiscordPayload() {
	message := 'A "quoted" name, C:\new\file' "`n" Chr(1) "`v" "🐝"
	payload := nm_DiscordEmbedPayload(message, 123, 'ping "name"')
	parsed := JSON.parse(payload)
	AssertEqual(parsed["embeds"][1]["description"], message, "Raw text survives JSON serialization")
	Assert(InStr(payload, "\u0001") && InStr(payload, "\u000b"), "Control characters use valid JSON escapes")
	AssertEqual(Type(parsed["embeds"][1]["color"]), "Integer", "Discord color is numeric")
	AssertEqual(StrLen(JSON.parse(nm_DiscordEmbedPayload(StrReplace(Format("{:4100}", "x"), " ", "x")))["embeds"][1]["description"]), 4096, "Embed description bounded")
	bytes := ComObjArray(0x11, 4)
	AssertEqual(nm_DeliveryPayloadSize(bytes), 4, "Encoded byte payload size")
}

class TestDeliveryFixture {
	__New(results) {
		this.results := results, this.tick := 1000, this.started := 0, this.aborted := 0
		this.failures := [], this.delivered := []
		this.queue := nm_DeliveryQueue(ObjBindMethod(this, "Start"), () => this.tick,
			(job, reason) => this.failures.Push([job.label, reason]))
	}
	Start(job) {
		this.started++
		if !this.results.Length
			throw Error("No fixture response")
		response := this.results.RemoveAt(1)
		if response = "throw"
			throw Error("Fixture network failure")
		return TestDeliveryRequest(this, response)
	}
	Add(label := "test") => this.queue.Enqueue("{}", "application/json", "https://discord.invalid/test", "fixture-token", label,
		(delivered) => this.delivered.Push(delivered))
}

class TestDeliveryRequest {
	__New(owner, response) => (this.owner := owner, this.response := response)
	Poll() => this.response = "pending" ? 0 : this.response
	Abort() => this.owner.aborted++
}

TestDeliveryQueue() {
	fixture := TestDeliveryFixture([{status: 429, retryAfter: 2.5}, {status: 503, retryAfter: 0}, {status: 200, retryAfter: 0}])
	fixture.Add(), fixture.queue.Pump()
	AssertEqual(fixture.queue.Items.Length, 1, "429 keeps queued report")
	fixture.tick += 2499, fixture.queue.Pump()
	AssertEqual(fixture.started, 1, "No retry before fractional server delay")
	fixture.tick++, fixture.queue.Pump()
	AssertEqual(fixture.started, 2, "Retry at server delay")
	fixture.tick += 3999, fixture.queue.Pump()
	AssertEqual(fixture.started, 2, "5xx exponential delay")
	fixture.tick++, fixture.queue.Pump()
	AssertEqual(fixture.queue.Items.Length, 0, "Remove only after HTTP success")
	AssertEqual(fixture.delivered[1], true, "Success callback once")
	AssertEqual(fixture.queue.Bytes, 0, "Encoded payload released")

	fixture := TestDeliveryFixture(["pending", {status: 204, retryAfter: 0}])
	fixture.Add(), fixture.queue.Pump(), fixture.queue.Pump()
	AssertEqual(fixture.started, 1, "Polling does not restart a live request")
	fixture.tick += fixture.queue.Timeout, fixture.queue.Pump()
	AssertEqual(fixture.aborted, 1, "Timeout aborts active request")
	fixture.tick += 2000, fixture.queue.Pump()
	AssertEqual(fixture.delivered[1], true, "Timeout can recover")

	fixture := TestDeliveryFixture([{status: 401, retryAfter: 0}])
	fixture.Add(), fixture.queue.Pump()
	AssertEqual(fixture.failures.Length, 1, "Permanent HTTP failure recorded")
	AssertEqual(fixture.delivered[1], false, "Permanent failure is not success")
	fixture := TestDeliveryFixture(["throw", "throw"])
	fixture.queue.MaxAttempts := 2
	fixture.Add(), fixture.queue.Pump(), fixture.tick += 2000, fixture.queue.Pump()
	AssertEqual(fixture.started, 2, "Network retry cap enforced")
	AssertEqual(fixture.failures.Length, 1, "Exhaustion recorded once")

	fixture := TestDeliveryFixture([{status: 429, retryAfter: 7200}])
	fixture.Add(), fixture.queue.Pump(), fixture.tick += 3600000, fixture.queue.Pump()
	AssertEqual(fixture.started, 1, "Age expiry never shortens server delay into an early send")
	AssertEqual(fixture.failures.Length, 1, "Old report expires visibly")
	fixture := TestDeliveryFixture([])
	fixture.queue.Limit := 1
	Assert(fixture.Add("first") && !fixture.Add("overflow"), "Queue count bounded")
	AssertEqual(fixture.queue.Items[1].label, "first", "Overflow preserves existing report")
	fixture.queue.Close()
	AssertEqual(fixture.failures.Length, 2, "Overflow and shutdown retained locally")
	fixture.queue.ByteLimit := 1
	Assert(!fixture.Add(), "Queue bytes bounded")
}

TestHourlyReportDelivery() {
	IniWrite 0, "settings\nm_config.ini", "Status", "discordMode"
	IniWrite "https://discord.invalid/test", "settings\nm_config.ini", "Status", "webhook"
	pToken := Gdip_Startup(), bitmap := Gdip_CreateBitmap(8, 8)
	try {
		fixture := TestDeliveryFixture([{status: 200, retryAfter: 0}])
		discord.Outbox := fixture.queue
		Assert(nm_QueueHourlyReport(bitmap), "Prepared report accepted")
		AssertEqual(CountPendingPng(), 1, "PNG persisted before queue handoff")
		Assert(nm_DeliveryPayloadSize(fixture.queue.Items[1].data) > 100, "Multipart owns encoded PNG bytes")
		fixture.queue.Pump()
		AssertEqual(CountPendingPng(), 0, "HTTP success clears pending PNG")
		fixture := TestDeliveryFixture([{status: 403, retryAfter: 0}])
		discord.Outbox := fixture.queue
		Assert(nm_QueueHourlyReport(bitmap), "Second report accepted")
		fixture.queue.Pump()
		AssertEqual(CountPendingPng(), 1, "HTTP failure retains PNG")
		fixture.queue.Limit := 0
		Assert(!nm_QueueHourlyReport(bitmap), "Full queue rejects sample-window handoff")
		AssertEqual(CountPendingPng(), 2, "Rejected report also remains on disk")
	} finally {
		discord.Outbox := 0
		Gdip_DisposeImage(bitmap), Gdip_Shutdown(pToken)
	}
}

CountPendingPng() {
	count := 0
	Loop Files "settings\pending-reports\*.png"
		count++
	return count
}

TestLocalHttpDelivery() {
	if !A_Args.Length || !RegExMatch(A_Args[1], "^\d+$")
		throw Error("Windows runner must supply the local HTTP fixture port")
	delivered := [], failures := []
	queue := nm_DeliveryQueue(,, (job, reason) => failures.Push(reason))
	queue.Enqueue(nm_DiscordEmbedPayload('Quoted "text"' "`n" Chr(1)), "application/json", "http://127.0.0.1:" A_Args[1] "/slow", , , (ok) => delivered.Push(ok))
	start := A_TickCount
	queue.Pump()
	Assert(A_TickCount - start < 1000, "Real WinHTTP poll returns before delayed response")
	AssertEqual(queue.Items.Length, 1, "Real delayed request remains in flight")
	while queue.Items.Length && A_TickCount - start < 10000 {
		Sleep 10
		queue.Pump()
	}
	AssertEqual(queue.Items.Length, 0, "Real HTTP response completes")
	AssertEqual(failures.Length, 0, "Real server accepted serialized JSON")
	AssertEqual(delivered[1], true, "Real success callback confirmed")
	AssertEqual(queue.Bytes, 0, "Real delivery releases payload")
}
