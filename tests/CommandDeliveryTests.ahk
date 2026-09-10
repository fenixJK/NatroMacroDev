TestCommandDelivery() {
	global webhook, bottoken, discordMode, MainChannelCheck, MainChannelID
	previous := [discord.Outbox, webhook, bottoken, discordMode, MainChannelCheck, MainChannelID]
	fixture := TestDeliveryFixture([{status: 429, retryAfter: 2.5}, {status: 200, retryAfter: 0}])
	discord.Outbox := fixture.queue
	try {
		webhook := "https://discord.invalid/webhook?thread_id=123", discordMode := 0
		Assert(nm_DiscordCommandReply.DeliveryQueue() == discord.Outbox, "Command replies share the existing Status outbox")
		Assert(nm_DiscordCommandReply.SendEmbed('reply "quoted" 🐝', 123,,,, "123"), "Reply returns queue acceptance")
		AssertEqual(fixture.started, 0, "Reply handoff does not wait for or start HTTP")
		job := fixture.queue.Items[1], body := job.data
		AssertEqual(job.url, webhook "&wait=true", "Webhook query and persistence request retained")
		AssertEqual(job.token, "", "Webhook reply does not receive bot credentials")
		AssertEqual(JSON.parse(body)["message_reference"]["message_id"], "123", "Queued reply retains original message reference")
		fixture.queue.Pump()
		AssertEqual(fixture.queue.Items.Length, 1, "Rate-limited reply remains queued")
		fixture.tick += 2499, fixture.queue.Pump()
		AssertEqual(fixture.started, 1, "Command retry respects fractional server delay")
		fixture.tick++, fixture.queue.Pump()
		AssertEqual(fixture.started, 2, "Command retries at server deadline")
		AssertEqual(job.data, body, "Retry preserves the encoded reply")
		AssertEqual(fixture.queue.Bytes, 0, "Successful reply releases queue bytes")

		discordMode := 1, MainChannelCheck := 1, MainChannelID := "456", bottoken := "first-token"
		Assert(nm_DiscordCommandReply.SendEmbed("bot reply",,,,, "123"), "Bot reply accepted")
		job := fixture.queue.Items[1]
		AssertEqual(job.url, discord.baseURL "channels/456/messages", "Bot reply targets configured channel")
		MainChannelID := "789", bottoken := "second-token"
		AssertEqual(job.token, "first-token", "Queued reply retains token from handoff")
		AssertEqual(job.url, discord.baseURL "channels/456/messages", "Queued reply retains destination from handoff")
		Assert(nm_DiscordCommandReply.SendEmbed("explicit channel",,,, "987", "123"), "Explicit channel reply accepted")
		AssertEqual(fixture.queue.Items[2].url, discord.baseURL "channels/987/messages", "Explicit channel takes precedence")
		for payload in nm_DiscordHelpPayloads("useful", 'q"', Map(), "123")
			Assert(nm_DiscordCommandReply.SendMessageAPI(payload), "Help page accepted")
		Assert(nm_DiscordCommandReply.SendMessageAPI(nm_DiscordSettingPayload("name", "value", "123")), "Setting display accepted")
		report := nm_DiscordReport("123")
		report.Add("fixture report")
		Assert(report.Send(nm_DiscordCommandReply), "Structured report uses command handoff")
		AssertEqual(fixture.started, 2, "Multiple command builders do not perform synchronous transport")
		fixture.queue.Close()

		fixture := TestDeliveryFixture([]), discord.Outbox := fixture.queue
		pToken := Gdip_Startup(), bitmap := Gdip_CreateBitmap(8, 8)
		try Assert(nm_DiscordCommandReply.SendImage(bitmap, "ss.png", "123"), "Image reply accepted")
		finally Gdip_DisposeImage(bitmap), Gdip_Shutdown(pToken)
		AssertEqual(Type(fixture.queue.Items[1].data), "ComObjArray", "Queue owns encoded image bytes after bitmap disposal")
		path := A_WorkingDir "\command-upload.txt"
		FileAppend "file contents", path
		Assert(nm_DiscordCommandReply.SendFile(path, "123"), "File reply accepted")
		AssertEqual(FileRead(path), "file contents", "Queued file upload preserves caller source")
		FileDelete path
		AssertEqual(Type(fixture.queue.Items[2].data), "ComObjArray", "Queue owns file bytes independently of source lifetime")
		AssertEqual(fixture.started, 0, "Image and file preparation do not perform HTTP")
		fixture.queue.Limit := 2
		Assert(!nm_DiscordCommandReply.SendEmbed("full"), "Full queue returns rejection")
		AssertEqual(fixture.failures.Length, 1, "Full queue records failed command handoff")
		fixture.queue.Close()
		Assert(!nm_DiscordCommandReply.SendEmbed("closed"), "Closed queue rejects replies")
	} finally {
		fixture.queue.Close()
		discord.Outbox := previous[1], webhook := previous[2], bottoken := previous[3]
		discordMode := previous[4], MainChannelCheck := previous[5], MainChannelID := previous[6]
	}
}
