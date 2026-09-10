TestDeliveryCooldown() {
	AssertEqual(nm_DeliveryCooldown.Hash("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "Native SHA256 matches a known vector")
	for terminal in ["expire", "exhaust", "cancel"] {
		fixture := TestDeliveryFixture([{status: 429, retryAfter: 300}, {status: 200, retryAfter: 0}])
		if terminal = "exhaust"
			fixture.queue.MaxAttempts := 1
		else if terminal = "expire"
			fixture.queue.MaxAge := 60000
		fixture.Add("first"), fixture.queue.Pump()
		if terminal = "expire"
			fixture.tick += 60000, fixture.queue.Pump()
		else if terminal = "cancel" {
			fixture.queue.Items[1].cancelled := true
			fixture.queue.Pump()
		}
		AssertEqual(fixture.queue.Items.Length, 0, "First message removed after " terminal)
		fixture.queue.MaxAge := 3600000
		fixture.Add("second"), fixture.queue.Pump()
		AssertEqual(fixture.started, 1, "Next message cannot bypass cooldown after " terminal)
		fixture.tick := 300999, fixture.queue.Pump()
		AssertEqual(fixture.started, 1, "No new send a millisecond before retained deadline")
		fixture.tick++, fixture.queue.Pump()
		AssertEqual(fixture.started, 2, "Next message may send at retained deadline")
		AssertEqual(fixture.queue.Items.Length, 0, "Second message completes")
	}
	gate := nm_DeliveryCooldown(), first := {token: "token-a"}, same := {token: "token-a"}, other := {token: "token-b"}
	AssertEqual(gate.Defer(first, 1000, 2.5001), 3501, "Fractional milliseconds round up")
	AssertEqual(gate.Deadline(same, 1000), 3501, "Same bot identity shares cooldown")
	AssertEqual(gate.Deadline(other, 1000), 0, "Independent bot token does not inherit delay")
	AssertEqual(gate.Defer(same, 1000, 1), 3501, "A shorter response cannot shorten an existing delay")
	AssertEqual(gate.Defer(same, 1000, 10), 11000, "A longer response extends delay")
	anon := {token: "", url: "https://discord.invalid/one"}, anonOther := {token: "", url: "https://discord.invalid/two"}
	gate.Defer(anon, 1000, 2)
	AssertEqual(gate.Deadline(anonOther, 1000), 3000, "Unauthenticated requests share a conservative gate")
	AssertEqual(gate.Defer(other, 1000, -1), 61000, "Invalid server delay uses a minute fallback")
	AssertEqual(gate.Defer(other, 1000, 1.0e30), 0x1fffffffffffff, "Pathological duration cannot overflow to an early send")

	; Model a response just before any timer edge, then the earliest tick at
	; which the queue could send. The server measures real elapsed time.
	for quantum in [10, 15.625, 16] {
		Loop 32 {
			observed := quantum * 64, actual := observed + quantum * (A_Index - 0.01) / 32
			guarded := nm_DeliveryCooldown(false, 32)
			deadline := guarded.Defer({token: "quantized"}, observed, 2.5001)
			earliestSend := Ceil(deadline / quantum) * quantum
			Assert(earliestSend - actual >= 2500.1, "Coarse clock cannot shorten the requested real interval")
		}
	}
	guarded := nm_DeliveryCooldown(false, 32)
	AssertEqual(guarded.Defer(first, 1000, 2.5), 3532, "Native clock allowance extends the published deadline")
	AssertEqual(guarded.Defer(other, 0x1fffffffffffff - 16, 0.001), 0x1fffffffffffff, "Clock allowance also saturates near the maximum")
	AssertEqual(nm_DeliveryCooldown(true).ClockMarginMs, 32, "Native shared coordinators enable the clock allowance")

	fixture := TestDeliveryFixture([{status: 429, retryAfter: 300}])
	fixture.Add(), fixture.queue.Pump(), fixture.queue.Close()
	second := TestDeliveryFixture([{status: 200, retryAfter: 0}])
	second.queue.Cooldown := fixture.queue.Cooldown
	second.Add(), second.queue.Pump()
	AssertEqual(second.started, 0, "Replacing a queue preserves the shared coordinator's delay")
	second.queue.Close()

	fixture := TestDeliveryFixture([])
	fixture.queue.Factory := (job) => TestDelayedRateRequest(fixture, {status: 429, retryAfter: 3})
	fixture.queue.MaxAttempts := 1
	fixture.Add(), fixture.queue.Pump()
	AssertEqual(fixture.queue.Cooldown.Deadline({token: "fixture-token"}, fixture.tick), 9000,
		"Server delay starts after response handling advances the clock")
}

class TestDelayedRateRequest extends TestDeliveryRequest {
	Poll() {
		this.owner.tick += 5000
		return this.response
	}
}

TestLocalCooldown() {
	failures := [], delivered := [], token := "native-rate-" DllCall("GetCurrentProcessId")
	queue := nm_DeliveryQueue(,, (job, reason) => failures.Push(reason))
	queue.MaxAttempts := 1
	url := "http://127.0.0.1:" A_Args[1] "/rate?fixture=" A_PtrSize * 8
	try {
		queue.Enqueue('{"phase":1}', "application/json", url, token)
		start := A_TickCount
		while queue.Items.Length && A_TickCount - start < 10000 {
			queue.Pump()
			Sleep 10
		}
		AssertEqual(failures.Length, 1, "Native 429 exhausts the one-attempt first message")
		AssertEqual(queue.Items.Length, 0, "Native rate-limited message removed")
		queue.Enqueue('{"phase":2}', "application/json", url, token,, (ok) => delivered.Push(ok))
		queue.Pump()
		AssertEqual(queue.Items[1].attempts, 0, "Next native message is held before creating HTTP request")
		start := A_TickCount
		while queue.Items.Length && A_TickCount - start < 10000 {
			queue.Pump()
			Sleep 10
		}
		AssertEqual(delivered.Length, 1, "Next native message finishes")
		if FileExist(A_Args[2] ".rate")
			FileAppend "Native cooldown server elapsed seconds: " FileRead(A_Args[2] ".rate") "`n", "*"
		Assert(delivered[1], "Server independently confirms the cross-message Retry-After interval")
		AssertEqual(failures.Length, 1, "Only the deliberately exhausted first message fails")
	} finally queue.Close()
}
