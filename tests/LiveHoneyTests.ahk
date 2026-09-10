TestLiveHoneyDelivery() {
	destination := {url: "https://discord.invalid/webhook?thread_id=7&wait=false", token: "", webhook: true}
	fixture := TestDeliveryFixture(["pending"]), live := nm_LiveHoneyDelivery(fixture.queue, () => fixture.tick)
	live.Configure(destination)
	Assert(live.Ready() && live.Submit("first", "application/json"), "First frame accepted")
	Assert(!live.Ready() && !live.Submit("second", "application/json"), "Pending frame suppresses another capture/submission")
	AssertEqual(fixture.queue.Items.Length, 1, "One outstanding live frame")
	AssertEqual(fixture.queue.Items[1].url, "https://discord.invalid/webhook?thread_id=7&wait=true", "Create preserves query and requests a message receipt")
	fixture.queue.Pump()
	fixture.queue.Items[1].request.response := {status: 200, retryAfter: 0, id: "123"}
	fixture.queue.Pump()
	AssertEqual(live.ID, "123", "Successful create receipt sets message ID")
	Assert(live.Ready(), "Receipt permits a fresh frame")
	fixture.results.Push({status: 200, retryAfter: 0, id: "123"})
	live.Submit("latest", "application/json")
	AssertEqual(fixture.queue.Items[1].method, "PATCH", "Subsequent frame edits the message")
	AssertEqual(fixture.queue.Items[1].url, "https://discord.invalid/webhook/messages/123?thread_id=7&wait=false", "Edit ID belongs before the query")
	fixture.queue.Pump()
	AssertEqual(live.ID, "123", "Edit keeps the established ID")

	fixture.results.Push("pending"), live.Submit("old", "application/json"), fixture.queue.Pump()
	oldOwner := live.Owner
	live.Configure({url: "https://discord.invalid/new", token: "new-token", webhook: false})
	Assert(fixture.queue.Items[1].cancelled, "Destination change cancels the old frame")
	live.Completed(oldOwner, true, true, {status: 200, id: "999"})
	AssertEqual(live.ID, "", "Late result cannot contaminate a new destination")
	fixture.queue.Pump()
	AssertEqual(fixture.aborted, 3, "Cancellation aborts the old request as well as completed request cleanup")
	AssertEqual(fixture.queue.Bytes, 0, "Cancellation releases encoded payload accounting")
	fixture.results.Push({status: 200, retryAfter: 0, id: "456"})
	live.Submit("new", "application/json"), fixture.queue.Pump()
	AssertEqual(live.ID, "456", "New destination creates its own message")
	live.Configure(0)
	Assert(!live.Ready() && live.ID = "", "Disable drops session identity and suppresses frames")

	fixture := TestDeliveryFixture([{status: 200, retryAfter: 0, id: ""}])
	live := nm_LiveHoneyDelivery(fixture.queue, () => fixture.tick), live.Configure(destination)
	live.Submit("no receipt", "application/json"), fixture.queue.Pump()
	fixture.tick += 600000
	Assert(!live.Ready() && live.Blocked, "Success without an ID cannot repeatedly create messages")
	live.Configure(0), live.Configure(destination)
	Assert(live.Ready(), "Explicit session reset clears a missing-ID pause")
	fixture.results.Push({status: 403, retryAfter: 0})
	live.Submit("forbidden", "application/json"), fixture.queue.Pump()
	Assert(live.Blocked, "Permanent authorization errors do not retry every frame")

	fixture := TestDeliveryFixture([{status: 429, retryAfter: 300}])
	live := nm_LiveHoneyDelivery(fixture.queue, () => fixture.tick), live.Configure(destination)
	live.Submit("rate limited", "application/json"), fixture.queue.Pump()
	fixture.tick += 60000, fixture.queue.Pump()
	Assert(!live.Ready(), "Expired frame cannot bypass server backoff")
	fixture.tick += 239999
	Assert(!live.Ready(), "Fresh frame still waits for the full server delay")
	fixture.tick++
	Assert(live.Ready(), "Fresh frame allowed after server delay")
	fixture.queue.Close()
	Assert(!live.Ready(), "Closed outbox cannot acquire another frame")

	fixture := TestDeliveryFixture([{status: 404, retryAfter: 0}])
	live := nm_LiveHoneyDelivery(fixture.queue, () => fixture.tick), live.Configure(destination), live.ID := "123"
	live.Submit("deleted", "application/json"), fixture.queue.Pump()
	Assert(live.ID = "" && !live.Ready() && !live.Blocked, "Deleted edit target resets ID with backoff")
	fixture.tick += 60000
	Assert(live.Ready(), "Deleted message can be recreated from a fresh frame")
	AssertEqual(nm_LiveHoneyRoute({url: "https://discord.invalid/channels/1/messages", webhook: false}, "2"),
		"https://discord.invalid/channels/1/messages/2", "Bot edit route uses the existing messages collection")
}

TestLocalLiveHoney() {
	queue := nm_DeliveryQueue(), live := nm_LiveHoneyDelivery(queue)
	live.Configure({url: "http://127.0.0.1:" A_Args[1] "/live", token: "", webhook: false})
	Loop 2 {
		Assert(live.Submit('{"frame":' A_Index '}', "application/json"), "Native live frame enqueued")
		started := A_TickCount
		while live.InFlight && A_TickCount - started < 10000 {
			queue.Pump()
			Sleep 10
		}
		Assert(!live.InFlight && live.ID = "123" && live.Ready(), "Native POST/PATCH returned and consumed the message ID")
	}
	AssertEqual(queue.Bytes, 0, "Native live requests release payload bytes")
	queue.Close()
}
