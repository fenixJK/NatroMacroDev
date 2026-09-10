class TestBotFixture {
	__New(allowed := "200000000000000002") {
		this.delivery := TestDeliveryFixture([]), this.commands := [], this.logs := [], this.requests := []
		this.delivery.queue.Factory := ObjBindMethod(this, "Start")
		this.config := {token: "fixture-bot-token", channel: "100000000000000001", prefix: "!", allowed: allowed}
		this.inbox := nm_BotInbox(this.commands, this.delivery.queue, () => this.delivery.tick, (message) => this.logs.Push(message))
		this.inbox.Configure(this.config)
	}
	Start(job) {
		this.requests.Push({url: job.url, token: job.token, method: job.method})
		return this.delivery.Start(job)
	}
	Receive(body) {
		this.delivery.tick := Max(this.delivery.tick, this.inbox.Next)
		this.delivery.results.Push({status: 200, retryAfter: 0, id: "", text: JSON.stringify(body), bodyValid: true})
		this.inbox.Pump(), this.inbox.Pump()
	}
	static Message(id, content := "!pause", author := "200000000000000002") {
		return Map("id", id, "channel_id", "100000000000000001", "author", Map("id", author), "content", content, "attachments", [], "type", 0,
			"timestamp", FormatTime(A_NowUTC, "yyyy-MM-dd'T'HH:mm:ss") "+00:00")
	}
}

TestBotInbox() {
	Assert(!nm_BotInbox.SameID(100000000000000001, "100000000000000001"), "Numeric identity cannot substitute for the API string ID")
	Assert(!nm_BotInbox.SameID("99999999999999999998", "99999999999999999999"), "Large decimal identities compare exactly without floating point")
	f := TestBotFixture(), baseline := "100000000000000010", first := "100000000000000011", last := "100000000000000013"
	f.Receive([TestBotFixture.Message(baseline, "!restart")])
	AssertEqual(f.commands.Length, 0, "Startup watermark does not execute a historical restart command")
	AssertEqual(f.inbox.Cursor, baseline, "Startup records the latest observed ID")
	AssertEqual(f.requests[1].method, "GET", "Command polling uses queued GET")
	bot := TestBotFixture.Message("100000000000000014"), bot["author"]["bot"] := JSON.true
	f.Receive([TestBotFixture.Message(last, "!stop", "200000000000000003"), bot,
		TestBotFixture.Message(first), TestBotFixture.Message("100000000000000012", "ordinary text"), TestBotFixture.Message(first)])
	AssertEqual(f.commands.Length, 2, "Only new user commands are admitted, without duplicate IDs")
	AssertEqual(f.commands[1].id, first, "Commands are ordered oldest first")
	AssertEqual(f.commands[2].id, last, "Command order is independent of response order")
	Assert(f.inbox.Ready(f.commands[1]) && f.inbox.Authorized(f.commands[1], f.config), "Explicit user permission needs no role request")
	Assert(!f.inbox.Authorized(f.commands[2], f.config), "Wrong user cannot execute a command")
	AssertEqual(f.inbox.Cursor, "100000000000000014", "Cursor also advances over ignored bot messages")
	old := f.commands[1], owner := f.inbox.Owner, changed := f.config.Clone(), changed.token := "Fixture-bot-token"
	Assert(!f.inbox.Authorized(old, changed), "Case-sensitive token change invalidates dispatch immediately")
	f.inbox.Configure(changed)
	AssertEqual(f.commands.Length, 0, "Configuration change discards prior buffered commands")
	Assert(!f.inbox.Authorized(old, changed), "Old ownership cannot authorize after reconfiguration")
	f.inbox.Completed(owner, "messages", 0, true, {bodyValid: true, text: JSON.stringify([TestBotFixture.Message(last)])})
	AssertEqual(f.inbox.Cursor, "", "Late old response cannot establish a new watermark")
	f.inbox.Close()

	f := TestBotFixture(), f.inbox.Cursor := baseline
	bad := TestBotFixture.Message(last), bad["channel_id"] := "100000000000000099"
	AssertDeliveryError(() => f.inbox.Messages([TestBotFixture.Message(first), bad]), "Wrong-channel page rejected")
	AssertEqual(f.commands.Length, 0, "Invalid page cannot partially admit an earlier valid command")
	AssertEqual(f.inbox.Cursor, baseline, "Invalid page cannot advance cursor")
	f.inbox.Messages([TestBotFixture.Message(first)])
	Loop 98
		f.commands.Push(f.commands[1].Clone())
	f.inbox.Messages([TestBotFixture.Message("100000000000000012"), TestBotFixture.Message(last)])
	AssertEqual(f.commands.Length, 100, "Command inbox is bounded")
	AssertEqual(f.inbox.Cursor, "100000000000000012", "Cursor stops before first unadmitted command")
	f.commands.Length := 0
	f.inbox.Messages([TestBotFixture.Message(last)])
	AssertEqual(f.commands[1].id, last, "Previously unadmitted command remains eligible on refetch")
	f.delivery.tick += f.inbox.CommandAge
	f.inbox.Pump()
	AssertEqual(f.commands.Length, 0, "Commands expire before delayed dispatch")
	Assert(f.logs.Length, "Expiry is recorded locally")
	f.inbox.Close()

	f := TestBotFixture(), f.inbox.Cursor := baseline
	stale := TestBotFixture.Message(first, "!restart"), stale["timestamp"] := "2000-01-01T00:00:00Z"
	future := TestBotFixture.Message(last, "!restart"), future["timestamp"] := "2099-01-01T00:00:00Z"
	f.inbox.Messages([stale, future])
	AssertEqual(f.commands.Length, 0, "Outage backlog and future-dated commands cannot trigger delayed actions")
	AssertEqual(f.inbox.Cursor, last, "Ignored stale commands do not stall later polling")
	f.inbox.Completed(f.inbox.Owner, "messages", 0, true, {bodyValid: false})
	AssertEqual(f.inbox.PageLimit, 50, "Unavailable large response reduces page size without losing cursor")
	Assert(!f.inbox.Blocked && f.inbox.Cursor = last, "Adaptive page retry preserves progress")
	f.inbox.Close()
}

TestBotRoles() {
	role := "300000000000000003", guild := "400000000000000004"
	f := TestBotFixture("&" role)
	f.Receive([TestBotFixture.Message("100000000000000010")])
	f.Receive([TestBotFixture.Message("100000000000000011")])
	command := f.commands[1]
	Assert(!f.inbox.Ready(command) && !f.inbox.Authorized(command, f.config), "Role command waits for fresh authorization")
	f.Receive(Map("id", f.config.channel, "guild_id", guild))
	AssertEqual(f.delivery.queue.Items[1].url, "https://discord.com/api/v10/guilds/" guild "/members/" command.user_id, "Member lookup uses verified guild and message author")
	f.Receive(Map("user", Map("id", command.user_id), "roles", [role]))
	Assert(f.inbox.Ready(command) && f.inbox.Authorized(command, f.config), "Fresh matching member role authorizes dispatch")
	f.delivery.tick += f.inbox.RoleAge + 1
	Assert(!f.inbox.Ready(command) && !f.inbox.Authorized(command, f.config), "Expired role result cannot authorize delayed dispatch")
	f.Receive(Map("user", Map("id", "200000000000000099"), "roles", [role]))
	Assert(f.inbox.Ready(command) && !f.inbox.Authorized(command, f.config), "Wrong member response becomes a denial, never an authorization")
	changed := f.config.Clone(), changed.allowed := "&300000000000000099"
	Assert(!f.inbox.Authorized(command, changed), "Local allowlist change invalidates previously read roles")
	f.inbox.Close()

	f := TestBotFixture(), f.inbox.Pump()
	Assert(f.inbox.Pending && f.delivery.started = 0, "Polling submission returns before starting HTTP")
	oldOwner := f.inbox.Owner
	f.inbox.Configure(0), f.inbox.Pump()
	Assert(f.delivery.queue.Items.Length = 0 && f.delivery.started = 0, "Disable cancels pending read before network start")
	f.inbox.Completed(oldOwner, "messages", 0, true, {bodyValid: true, text: "[]"})
	Assert(!IsObject(f.inbox.Config) && f.inbox.Cursor = "", "Late disabled response is ignored")
	f.inbox.Close()
}

TestBotRecovery() {
	f := TestBotFixture()
	f.delivery.results.Push({status: 429, retryAfter: 300})
	f.inbox.Pump(), f.inbox.Pump()
	f.delivery.tick += 20000, f.inbox.Pump()
	Assert(!f.inbox.Pending && f.inbox.Next >= 301000, "Expired read retains the server delay before another poll")
	f.delivery.tick := 300999, f.inbox.Pump()
	AssertEqual(f.delivery.started, 1, "Poller does not bypass a long shared cooldown")
	f.delivery.tick++, f.inbox.Pump()
	Assert(f.inbox.Pending, "Polling can resume after the server deadline")
	f.inbox.Close()

	f := TestBotFixture()
	Loop 8
		f.inbox.Failed("messages", 0, 0, 0)
	Assert(!f.inbox.Blocked && f.inbox.Next - f.delivery.tick = 60000, "Repeated transient failures back off without permanently disabling recovery")
	f.inbox.Failed("messages", 0, 403, 0)
	Assert(f.inbox.Blocked, "Permanent channel permission failure pauses polling")
	f.inbox.Configure(0), f.inbox.Configure(f.config)
	Assert(!f.inbox.Blocked, "Explicit configuration reset permits retry")
	Loop 5
		f.inbox.Completed(f.inbox.Owner, "messages", 0, true, {bodyValid: false})
	Assert(f.inbox.Blocked, "Repeated unusable responses pause rather than repeatedly parsing or executing")
	f.inbox.Close()
}

TestLocalBotInbox() {
	commands := [], logs := [], inbox := nm_BotInbox(commands,,, (message) => logs.Push(message), "http://127.0.0.1:" A_Args[1] "/inbox/")
	config := {token: "native-inbox-fixture", channel: "100000000000000001", prefix: "!", allowed: "&300000000000000003"}
	try {
		inbox.Configure(config), started := A_TickCount
		while (!commands.Length || !inbox.Ready(commands[1])) && A_TickCount - started < 15000 {
			inbox.Pump()
			Sleep 10
		}
		AssertEqual(commands.Length, 1, "Native poller admits only the post-baseline message")
		Assert(inbox.Authorized(commands[1], config), "Native channel/member JSON supplies current role authorization")
		AssertEqual(logs.Length, 0, "Native polling and authorization complete without failures")
	} finally inbox.Close()

	responses := [], queue := nm_DeliveryQueue()
	try {
		queue.Enqueue("", "application/json", "http://127.0.0.1:" A_Args[1] "/inbox/channels/100000000000000001", config.token,,,
			{method: "GET", responseLimit: 16, result: (ok, response) => responses.Push(response)})
		started := A_TickCount
		while queue.Items.Length && A_TickCount - started < 10000 {
			queue.Pump()
			Sleep 10
		}
		AssertEqual(responses.Length, 1, "Native bounded GET completes")
		Assert(!responses[1].bodyValid && responses[1].text = "", "Oversized response cannot escape the adapter as usable body data")
	} finally queue.Close()
}
