TestQuestObservation() {
	AssertEqual(nm_QuestObservation.Color(0x96D88D), 1, "Explicit completed background")
	for color in [0xF46C55, 0x6EFF60]
		AssertEqual(nm_QuestObservation.Color(color), 0, "Partial progress is incomplete")
	for color in [0, 0xFFFFFF, 0x96C3DE, 0xE5F0F7, 0x1B2A35, 0x123456]
		AssertEqual(nm_QuestObservation.Color(color), -1, "Unexpected color is unknown")
	for rowCount in [1, 2, 3, 4] {
		rows := []
		Loop rowCount
			rows.Push(1)
		AssertEqual(nm_QuestObservation.Aggregate(rows, rowCount), 1, "All recognized rows complete")
		AssertEqual(nm_QuestObservation.Aggregate(rows, rowCount, false), -1, "Missing title invalidates completion")
		AssertEqual(nm_QuestObservation.Aggregate(rows, rowCount + 1), -1, "Partial row set cannot complete quest")
		rows[-1] := 0
		AssertEqual(nm_QuestObservation.Aggregate(rows, rowCount), 0, "One incomplete objective keeps quest incomplete")
		rows[-1] := -1
		AssertEqual(nm_QuestObservation.Aggregate(rows, rowCount), -1, "One unreadable objective invalidates completion")
	}
	AssertEqual(nm_QuestObservation.Aggregate([], 0), -1, "No objectives is not completion")
}

TestQuestFrames() {
	token := Gdip_Startup(), capture := Gdip_CreateBitmap(306, 130), title := Gdip_CreateBitmap(5, 5), anchor := Gdip_CreateBitmap(3, 25)
	graphics := Gdip_GraphicsFromImage(capture), tg := Gdip_GraphicsFromImage(title), ag := Gdip_GraphicsFromImage(anchor)
	try {
		Gdip_GraphicsClear(tg, 0xFFCC00CC), Gdip_GraphicsClear(ag, 0xFF96C3DE)
		Gdip_GraphicsClear(graphics, 0xFF96D88D)
		Gdip_DrawImage(graphics, title, 100, 10, 5, 5)
		Gdip_DrawImage(graphics, anchor, 0, 40, 3, 25), Gdip_DrawImage(graphics, anchor, 0, 90, 3, 25)
		rows := nm_QuestObservation.Frame(capture, 2, [title], anchor)
		AssertEqual(nm_QuestObservation.Aggregate(rows, 2), 1, "Anchored title and completed rows from one GDI frame")
		AssertEqual(nm_QuestObservation.Aggregate(nm_QuestObservation.Frame(capture, 3, [title], anchor), 3), -1, "Clipped quest is unknown")
		AssertEqual(nm_QuestObservation.Aggregate(nm_QuestObservation.Frame(capture, 2, [], anchor), 2), -1, "Unknown title is unknown")
		AssertEqual(nm_QuestObservation.Aggregate(nm_QuestObservation.Frame(capture, 2, [title], anchor, 16, 50, 10, ["unknown", "unknown"], Map()), 2), -1, "Unknown Brown objectives cannot be completed by color alone")
		brown := Gdip_CreateBitmap(306, 180), bg := Gdip_GraphicsFromImage(brown)
		try {
			Gdip_GraphicsClear(bg, 0xFF96D88D)
			Gdip_DrawImage(bg, title, 100, 10, 5, 5)
			Gdip_DrawImage(bg, anchor, 0, 40, 3, 25), Gdip_DrawImage(bg, anchor, 0, 90, 3, 25)
			Gdip_DrawImage(bg, title, 70, 50, 5, 5), Gdip_DrawImage(bg, title, 70, 100, 5, 5)
			assets := Map("s16blueflower", title, "questbartitle", title)
			AssertEqual(nm_QuestObservation.Aggregate(nm_QuestObservation.Frame(brown, 2, [title], anchor, 16, 50, 10, ["blueflower", "blueflower"], assets), 2), -1, "Dynamic quest without current endpoint is unknown")
			Gdip_DrawImage(bg, title, 0, 140, 5, 5)
			AssertEqual(nm_QuestObservation.Aggregate(nm_QuestObservation.Frame(brown, 2, [title], anchor, 16, 50, 10, ["blueflower", "blueflower"], assets), 2), 1, "Dynamic rows and endpoint verified in one frame")
		} finally {
			Gdip_DeleteGraphics(bg), Gdip_DisposeImage(brown)
		}
		brush := Gdip_BrushCreateSolid(0xFFF46C55)
		try Gdip_FillRectangle(graphics, brush, 16, 90, 288, 40)
		finally Gdip_DeleteBrush(brush)
		rows := nm_QuestObservation.Frame(capture, 2, [title], anchor)
		AssertEqual(rows[1], 1, "Completed row preserved")
		AssertEqual(rows[2], 0, "Incomplete row recognized in same capture")
		AssertEqual(nm_QuestObservation.Aggregate(rows, 2), 0, "Mixed complete/incomplete frame")
		Gdip_GraphicsClear(graphics, 0xFF96D88D)
		Gdip_DrawImage(graphics, title, 100, 10, 5, 5)
		AssertEqual(nm_QuestObservation.Aggregate(nm_QuestObservation.Frame(capture, 2, [title], anchor), 2), -1, "Green overlay without row borders is not completion")
		AssertEqual(Gdip_LockBits(capture, 0, 0, 306, 130, &stride, &scan, &locked), 0, "Lock quest fixture")
		try AssertEqual(nm_QuestObservation.Aggregate(nm_QuestObservation.Frame(capture, 2, [title], anchor), 2), -1, "Capture read errors remain unknown")
		finally Gdip_UnlockBits(capture, &locked)
	} finally {
		Gdip_DeleteGraphics(graphics), Gdip_DeleteGraphics(tg), Gdip_DeleteGraphics(ag)
		Gdip_DisposeImage(capture), Gdip_DisposeImage(title), Gdip_DisposeImage(anchor), Gdip_Shutdown(token)
	}
}

; Execute the real six action consumers with controlled reader results. No input,
; travel, game capture or external reporting is allowed in these fixtures.
TestQuestActions() {
	global
	HoneyQuestCheck := PolarQuestCheck := RileyQuestCheck := BuckoQuestCheck := BlackQuestCheck := BrownQuestCheck := 0
	HoneyQuestComplete := PolarQuestComplete := RileyQuestComplete := BuckoQuestComplete := BlackQuestComplete := BrownQuestComplete := -1
	HoneyQuest := PolarQuest := RileyQuest := BuckoQuest := BlackQuest := BrownQuest := ""
	LastBugrunLadybugs := LastBugrunRhinoBeetles := LastBugrunSpider := LastBugrunMantis := LastBugrunScorpions := LastBugrunWerewolf := 0
	MonsterRespawnTime := 0, QuestBarSize := 50, QuestBarGapSize := 10, QuestBarInset := 16
	TestQuestMode := true
	try {
		for family in ["Honey", "Polar", "Riley", "Bucko", "Black", "Brown"] {
			%family%QuestCheck := 1
			%family%Quest := "fixture"
			for readings in [[-1], [0], [2], [1, -1], [1, 0]] {
				TestQuestReadings := readings.Clone(), TestQuestVisits := 0
				TotalQuestsComplete := SessionQuestsComplete := 0
				LastBlackQuest := LastBrownQuest := 0
				QuestLadybugs := QuestRhinoBeetles := QuestSpider := QuestMantis := QuestScorpions := QuestWerewolf := 0
				RileyLadybugs := RileyScorpions := BuckoRhinoBeetles := BuckoMantis := 0
				QuestAnt := QuestRedBoost := QuestBlueBoost := 0, QuestFeed := QuestGatherField := "None"
				nm_%family%Quest()
				expectedVisit := readings[1] = 1 ? 1 : 0
				expectedCount := family != "Honey" && readings.Length = 2 && readings[2] = 0 ? 1 : 0
				AssertEqual(TestQuestVisits, expectedVisit, family " turns in only a positively complete quest")
				AssertEqual(TotalQuestsComplete, expectedCount, family " does not count unreadable post-visit state")
				AssertEqual(SessionQuestsComplete, expectedCount, family " session count requires observed new incomplete progress")
				if family = "Black" || family = "Brown"
					AssertEqual(Last%family%Quest, expectedCount ? TestNow : 0, family " cooldown only advances after verified transition")
			}
		}
	} finally TestQuestMode := false
}

TestReadQuest(family) {
	global
	if !TestQuestMode
		return UnexpectedObservation()
	%family%QuestComplete := TestQuestReadings.Length ? TestQuestReadings.RemoveAt(1) : -1
}
nm_HoneyQuestProg() => TestReadQuest("Honey")
nm_PolarQuestProg() => TestReadQuest("Polar")
nm_RileyQuestProg() => TestReadQuest("Riley")
nm_BuckoQuestProg() => TestReadQuest("Bucko")
nm_BlackQuestProg() => TestReadQuest("Black")
nm_BrownQuestProg() => TestReadQuest("Brown")
nm_gotoQuestgiver(*) => TestQuestMode ? TestQuestVisit() : UnexpectedObservation()
TestQuestVisit() {
	global TestQuestVisits
	TestQuestVisits++
}
nm_setShiftLock(*) => TestQuestMode ? 0 : UnexpectedObservation()
nm_Bugrun(*) => UnexpectedObservation()
nm_Feed(*) => UnexpectedObservation()
nm_Collect(*) => UnexpectedObservation()
nm_ToAnyBooster(*) => UnexpectedObservation()

TestQuestUnknownPublication() {
	global
	HoneyQuestProgress := PolarQuestProgress := RileyQuestProgress := BuckoQuestProgress := BlackQuestProgress := BrownQuestProgress := ""
	for family in ["Honey", "Polar", "Riley", "Bucko", "Black", "Brown"] {
		%family%QuestProgress := "Complete"
		MainGui[family "QuestProgress"] := {Text: "Complete"}
		QuestGatherField := "Pine Tree", QuestGatherFieldSlot := 1
		QuestLadybugs := QuestRhinoBeetles := QuestSpider := QuestMantis := QuestScorpions := QuestWerewolf := 1
		RileyLadybugs := RileyScorpions := RileyAll := BuckoRhinoBeetles := BuckoMantis := 1
		QuestAnt := QuestRedBoost := QuestBlueBoost := 1, QuestFeed := "Strawberry"
		nm_PublishUnknownQuest(family)
		Assert(InStr(MainGui[family "QuestProgress"].Text, "Unknown"), family " clears stale completed display")
		Assert(InStr(IniRead("settings\nm_config.ini", "Quests", family "QuestProgress"), "Unknown"), family " persists unknown progress")
		AssertEqual(QuestGatherField, family = "Honey" ? "Pine Tree" : "None", family " clears only its own gather planning")
		if family = "Polar"
			Assert(!QuestLadybugs && !QuestRhinoBeetles && !QuestSpider && !QuestMantis && !QuestScorpions && !QuestWerewolf, "Unknown Polar does not leave kill objectives")
		if family = "Riley" || family = "Bucko"
			Assert(!QuestAnt && QuestFeed = "None", family " unknown does not leave spending/action objectives")
	}
}
