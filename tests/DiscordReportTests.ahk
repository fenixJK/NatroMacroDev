TestDiscordReports() {
	prefix := Chr(34) "\", label := 'A "quoted" name C:\new' "`n🐝"
	token := Gdip_Startup(), bitmap := Gdip_CreateBitmap(8, 8)
	try {
		catalog := Map("Paper", {name: label, bitmap: bitmap, color: 123})
		vars := Map("PlanterMode", 1, "PlanterName1", "None", "PlanterName2", "Paper", "PlanterName3", "Paper",
			"PlanterHarvestTime2", 100, "PlanterHarvestTime3", 100, "MPlanterHold2", 1, "MPlanterSmoking3", 1,
			"PlanterField2", label, "PlanterNectar2", "Comforting", "PlanterGlitter3", 1)
		before := JSON.stringify(vars), report := nm_DiscordPlanterReport(vars, catalog, prefix, "123", 100)
		embeds := JSON.parse(JSON.stringify(report.Payload))["embeds"]
		AssertEqual(embeds.Length, 3, "Only occupied planter slots included")
		AssertEqual(embeds[2]["title"], "Slot 2", "Sparse slots preserve actual slot numbers")
		AssertEqual(embeds[2]["fields"][2]["value"], "Holding", "Expired held planter is holding")
		AssertEqual(embeds[3]["fields"][2]["value"], "Smoking", "Expired smoking planter is smoking")
		AssertEqual(embeds[3]["fields"][3]["value"], "Yes", "Glitter flag retained")
		Assert(InStr(embeds[2]["fields"][1]["value"], label), "Planter field text survives serialization")
		AssertEqual(embeds[2]["author"]["name"], label, "Planter author text survives serialization")
		AssertEqual(report.Files.Length, 1, "Repeated catalog bitmap has one attachment")
		AssertEqual(report.Files[1]["name"], "files[0]", "Sparse slots cannot leave file index gaps")
		AssertEqual(embeds[2]["author"]["icon_url"], embeds[3]["author"]["icon_url"], "Repeated planter icons refer to the same attached filename")
		AssertEqual(embeds[2]["author"]["icon_url"], "attachment://" report.Files[1]["filename"], "Icon points to the generated attachment name")
		TestDiscordReplies.Sent := []
		AssertEqual(report.Send(TestDiscordReplies), "fixture-response", "Report uses existing synchronous transport contract")
		Assert(InStr(TestDiscordReplies.Sent[1].kind, "multipart/form-data") && nm_DeliveryPayloadSize(TestDiscordReplies.Sent[1].data) > 0, "Native multipart encoding succeeds")
		AssertEqual(Gdip_GetImageWidth(bitmap), 8, "Encoding does not dispose borrowed catalog bitmap")
		AssertEqual(JSON.stringify(vars), before, "Planter display does not mutate source state")
		vars["PlanterHarvestTime2"] := 150
		AssertEqual(nm_DiscordPlanterReport(vars, catalog, prefix, "123", 100).Payload["embeds"][2]["fields"][2]["value"], "50s", "Future growth precedes hold status")
		vars["PlanterMode"] := 0, vars["PlanterHarvestTime2"] := 100
		AssertEqual(nm_DiscordPlanterReport(vars, catalog, prefix, "123", 100).Payload["embeds"][2]["fields"][2]["value"], "Ready", "Automatic planters ignore manual hold state")

		catalog["Paper"].color := 239233142
		vars := Map("BlenderItem1", "Paper", "BlenderIndex1", "Infinite", "BlenderAmount1", 20, "BlenderTime1", 150,
			"BlenderItem2", "Paper", "BlenderIndex2", 0)
		report := nm_DiscordBlenderReport(vars, catalog, "123", 100)
		AssertEqual(report.Payload["embeds"].Length, 2, "Exhausted blender slot omitted")
		AssertEqual(report.Payload["embeds"][2]["color"], 5066239, "Invalid catalog color uses valid fallback")
		AssertEqual(report.Payload["embeds"][2]["fields"][1]["value"], "20", "Blender amounts serialize as field strings")
		AssertEqual(report.Payload["embeds"][2]["fields"][2]["value"], "Infinite", "Infinite recipe loops retained")

		vars := Map("ShrineRot", 2, "ShrineItem1", label, "ShrineItem2", "Cloud", "LastShrine", 0)
		report := nm_DiscordShrineReport(vars, "123", 3600)
		AssertEqual(report.Payload["embeds"][1]["fields"][1]["value"], "Cloud", "Shrine uses rotation from supplied snapshot")
		AssertEqual(report.Payload["embeds"][1]["fields"][2]["value"], label, "Shrine rotation wraps from two to one")
		AssertEqual(report.Payload["embeds"][1]["fields"][3]["value"], "Ready", "Shrine cooldown boundary is ready")
		vars["ShrineRot"] := 3
		AssertEqual(nm_DiscordShrineReport(vars, "123", 3600).Payload["embeds"][1]["fields"][1]["value"], "Unknown", "Invalid shrine rotation does not invent a donation")

		timers := {Mobs: {color: 123, bitmap: bitmap, values: [ {varname: "Bug", name: label, cooldown: 100} ]},
			Machines: {color: 456, bitmap: bitmap, values: [ {varname: "Clock", name: "Clock", cooldown: 100} ]},
			Beesmas: {color: 789, bitmap: bitmap, values: [ {varname: "Feast", name: "Feast", cooldown: 100} ]}}
		vars := Map("LastBug", 100, "MonsterRespawnTime", 50, "ClockCheck", 0, "FeastCheck", 1, "LastFeast", 100)
		report := nm_DiscordTimerReport(vars, timers, prefix, "123", 150)
		AssertEqual(report.Payload["embeds"].Length, 3, "Disabled machine group omitted while Beesmas retained")
		AssertEqual(report.Payload["embeds"][2]["fields"][1]["value"], "Alive", "Monster respawn reduction applied")
		AssertEqual(report.Payload["embeds"][3]["fields"][1]["value"], "50s", "Machine/event cooldown is not reduced")
		AssertEqual(report.Files[1]["name"], "files[0]", "Enabled groups use dense attachment indexes")
		vars["MonsterRespawnTime"] := "invalid"
		report := nm_DiscordTimerReport(vars, timers, prefix, "123", 150)
		AssertEqual(report.Payload["embeds"][2]["fields"][1]["value"], "Unknown", "Invalid monster modifier does not invent a mob timer")
		AssertEqual(report.Payload["embeds"][3]["fields"][1]["value"], "50s", "Unrelated monster modifier does not invalidate machine/event timers")
		AssertEqual(nm_DiscordReport.Remaining("invalid", 100), "Unknown", "Invalid time does not become ready")

		games := Map("Normal", {bit: 1, cooldown: 100}, "Mega", {bit: 2, cooldown: 100})
		items := Map("Ticket", {name: label}, "Glue", {name: "Glue"})
		vars := Map("NormalMemoryMatchCheck", 1, "MegaMemoryMatchCheck", 1, "LastNormalMemoryMatch", 0,
			"LastMegaMemoryMatch", 0, "TicketMatchIgnore", 1, "GlueMatchIgnore", 0)
		report := nm_DiscordMemoryReport(vars, games, items, prefix, "123", 100)
		AssertEqual(report.Payload["embeds"].Length, 3, "Only enabled memory games shown")
		AssertEqual(report.Payload["embeds"][2]["fields"][2]["value"], label, "Ignored items use matching game bit and raw names")
		AssertEqual(report.Payload["embeds"][3]["fields"][2]["value"], "None", "Empty ignored list stays None")
		TestDiscordReplies.Sent := []
		report.Send(TestDiscordReplies)
		AssertEqual(TestDiscordReplies.Sent[1].kind, "application/json", "Reports without icons avoid empty multipart bodies")
		honey := JSON.parse(nm_DiscordHoneyPayload(label, 123))
		AssertEqual(honey["embeds"][1]["description"], label, "Honey description serialized")
		AssertEqual(honey["attachments"].Length, 0, "Honey edit explicitly replaces old attachments")
		AssertEqual(honey["embeds"][1]["image"]["url"], "attachment://honey.png", "Honey image reference retained")
	} finally {
		Gdip_DisposeImage(bitmap), Gdip_Shutdown(token)
	}
}
