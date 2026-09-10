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
	AssertEqual(nm_DiscordTextLimit("abc🐝", 4), "abc", "Truncation preserves Unicode pairs")
}

class TestDiscordReplies extends discord {
	static Sent := []
	static SendMessageAPI(postdata, contentType := "application/json", channel := "", url := "") {
		this.Sent.Push({data: postdata, kind: contentType, channel: channel})
		return "fixture-response"
	}
}

TestDiscordRepliesEncoding() {
	TestDiscordReplies.Sent := []
	message := 'Window "quoted" C:\new\file literal \n' "`n" Chr(1) "🐝"
	AssertEqual(TestDiscordReplies.SendEmbed(message, 123, 'content "quoted"', 0, "fixture-channel", "123456789012345678"),
		"fixture-response", "SendEmbed preserves its synchronous response contract")
	sent := TestDiscordReplies.Sent[1], parsed := JSON.parse(sent.data)
	AssertEqual(parsed["embeds"][1]["description"], message, "Production SendEmbed preserves raw text and literal backslash-n")
	AssertEqual(parsed["content"], 'content "quoted"', "Content serialized once")
	AssertEqual(parsed["embeds"][1]["color"], 123, "Reply color is numeric")
	AssertEqual(sent.channel, "fixture-channel", "Explicit reply channel retained")
	AssertEqual(parsed["message_reference"]["message_id"], "123456789012345678", "Reply ID retained as a string")
	AssertEqual(parsed["allowed_mentions"]["parse"].Length, 0, "Reply does not enable parsed mentions")
	Assert(InStr(sent.data, '"fail_if_not_exists":false'), "Missing original message uses a JSON boolean")
	AssertThrows(() => nm_DiscordEmbedPayload("reply",,,, 'bad"id'), "Malformed reply ID rejected")
	AssertThrows(() => nm_DiscordEmbedPayload("reply",,,, "123456789012345678901"), "Oversized reply ID rejected")
	Assert(!JSON.parse(nm_DiscordEmbedPayload("ordinary" )).Has("message_reference"), "Ordinary messages have no reply reference")
	parsed := JSON.parse(nm_DiscordEmbedPayload("image",,, "ss.png", "123"))
	AssertEqual(parsed["embeds"][1]["image"]["url"], "attachment://ss.png", "Image attachment survives reply serialization")
	parsed := JSON.parse(nm_DiscordSettingPayload('a"key', message, "123"))
	AssertEqual(parsed["embeds"][1]["fields"][1]["name"], 'a"key', "Setting field name is serialized")
	AssertEqual(parsed["embeds"][1]["fields"][1]["value"], message, "Setting field value is serialized")
	AssertEqual(JSON.parse(nm_DiscordSettingPayload("empty", "", "123"))["embeds"][1]["fields"][1]["value"], "<blank>", "Blank setting remains visible")
	long := StrReplace(Format("{:1023}", ""), " ", "x") "🐝"
	AssertEqual(StrLen(JSON.parse(nm_DiscordSettingPayload("long", long, "123"))["embeds"][1]["fields"][1]["value"]), 1023,
		"Setting value length limit preserves Unicode pairs")
	TestDiscordReplies.SendFile('missing "quoted" file.txt', "123")
	AssertEqual(JSON.parse(TestDiscordReplies.Sent[2].data)["embeds"][1]["description"],
		Chr(96) 'missing "quoted" file.txt' Chr(96) ' does not exist or could not be read!', "File-error caller passes raw text")
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
		AssertDeliveryError(() => discord.CreateFormData(&data, &kind, [Map("name", "files[0]", "filename", "missing.png", "content-type", "image/png", "file", "missing.png")]), "Missing attachment must fail preparation")
		AssertDeliveryError(() => discord.CreateFormData(&data, &kind, [Map("name", "files[0]", "filename", "bad.png", "content-type", "image/png", "pBitmap", 0)]), "Invalid bitmap must fail preparation")
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
	if A_Args.Length < 2 || !RegExMatch(A_Args[1], "^\d+$")
		throw Error("Windows runner must supply the local HTTP fixture port and response gate")
	delivered := [], failures := []
	queue := nm_DeliveryQueue(,, (job, reason) => failures.Push(reason))
	queue.Enqueue(nm_DiscordEmbedPayload('Quoted "text"' "`n" Chr(1)), "application/json", "http://127.0.0.1:" A_Args[1] "/gated?gate=" A_PtrSize * 8, , , (ok) => delivered.Push(ok))
	start := A_TickCount
	while !FileExist(A_Args[2] ".received") && A_TickCount - start < 10000 {
		queue.Pump()
		Sleep 10
	}
	Assert(FileExist(A_Args[2] ".received"), "Real server received request while response remains gated")
	queue.Pump()
	AssertEqual(queue.Items.Length, 1, "Real gated request remains in flight")
	Assert(IsObject(queue.Items[1].request) && queue.Items[1].attempts = 1, "Poll returns with original request active before server can respond")
	AssertEqual(delivered.Length, 0, "No completion callback before server response")
	; Release only after polling returned. This proves non-blocking response polling
	; without assuming COM startup or shared-runner scheduling takes under one second.
	FileAppend "release", A_Args[2] ".release"
	start := A_TickCount
	while queue.Items.Length && A_TickCount - start < 10000 {
		Sleep 10
		queue.Pump()
	}
	AssertEqual(queue.Items.Length, 0, "Real HTTP response completes")
	AssertEqual(failures.Length, 0, "Real server accepted serialized JSON")
	AssertEqual(delivered[1], true, "Real success callback confirmed")
	AssertEqual(queue.Bytes, 0, "Real delivery releases payload")

	pToken := Gdip_Startup(), bitmap := Gdip_CreateBitmap(8, 8)
	try discord.CreateFormData(&data, &contentType, [Map("name", "payload_json", "content-type", "application/json", "content", nm_DiscordEmbedPayload("Image",,, "ss.png")),
		Map("name", "files[0]", "filename", "ss.png", "content-type", "image/png", "pBitmap", bitmap)])
	finally Gdip_DisposeImage(bitmap), Gdip_Shutdown(pToken)
	queue.Enqueue(data, contentType, "http://127.0.0.1:" A_Args[1] "/multipart",,, (ok) => delivered.Push(ok))
	start := A_TickCount
	while queue.Items.Length && A_TickCount - start < 10000 {
		queue.Pump()
		Sleep 10
	}
	AssertEqual(failures.Length, 0, "Real server accepts attachment framing and JSON")
	AssertEqual(delivered.Length, 2, "Both real requests complete")
	AssertEqual(delivered[2], true, "Encoded image remains valid after source bitmap disposal")
}

AssertDeliveryError(action, message) {
	try action.Call()
	catch
		return
	throw Error(message)
}
