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
				ResetQuestRecoveryFixture()
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
	if TestQuestTravelThrows
		throw Error("Injected travel interruption")
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

ResetQuestRecoveryFixture() {
	global TestQuestTravelThrows
	TestQuestTravelThrows := false
	try IniDelete "settings\nm_config.ini", "QuestRecovery"
	nm_QuestRecovery.Cache := Map(), nm_QuestRecovery.Active := Map()
}

TestQuestRecovery() {
	global TestNow, TestQuestTick
	previousNow := TestNow, originalClock := nm_QuestRecovery.Clock, originalTick := nm_QuestRecovery.Tick
	nm_QuestRecovery.Clock := () => TestNow, nm_QuestRecovery.Tick := () => TestQuestTick
	try {
		for kind in ["read", "visit"] {
			ResetQuestRecoveryFixture(), TestNow := 10000, TestQuestTick := 100000
			delay := kind = "read" ? 30 : 300
			Assert(nm_QuestRecovery.Begin("Black", kind), "Initial " kind " reservation allowed")
			AssertEqual(IniRead("settings\nm_config.ini", "QuestRecovery", "Black." kind), "10000|" 10000 + delay, "Reservation exists before work")
			TestQuestTick += (delay + 1) * 1000, TestNow += delay + 1
			Assert(!nm_QuestRecovery.Begin("Black", kind), "In-flight " kind " cannot overlap even after delay expires")
			nm_QuestRecovery.Finish("Black", kind, false)
			AssertEqual(nm_QuestRecovery.Remaining("Black", kind), delay, "Failed " kind " renews delay after work finishes")
			Assert(!nm_QuestRecovery.Begin("Black", kind), "Failed " kind " cannot immediately restart")
			TestNow += 50000
			AssertEqual(nm_QuestRecovery.Remaining("Black", kind), delay, "Forward wall-clock jump cannot shorten an in-process delay")
			TestQuestTick += (delay - 1) * 1000
			AssertEqual(nm_QuestRecovery.Remaining("Black", kind), 1, "Delay remains active through final second")
			TestQuestTick += 1000
			Assert(nm_QuestRecovery.Begin("Black", kind), "Next " kind " allowed at expiration")
			nm_QuestRecovery.Finish("Black", kind, true)
			Assert(nm_QuestRecovery.Ready("Black", kind), "Confirmed result clears only its retry reservation")

			ResetQuestRecoveryFixture(), TestNow := 10000, TestQuestTick := 100000
			Assert(nm_QuestRecovery.Begin("Polar", kind), "Reserve interrupted " kind)
			; Simulate process loss: no Finish, no in-memory cache/active operation.
			nm_QuestRecovery.Cache := Map(), nm_QuestRecovery.Active := Map(), TestNow += 5
			AssertEqual(nm_QuestRecovery.Remaining("Polar", kind), delay - 5, "Restart retains interrupted " kind " reservation")
			nm_QuestRecovery.Cache := Map(), TestNow := 9000
			AssertEqual(nm_QuestRecovery.Remaining("Polar", kind), delay, "Backward clock after restart receives bounded delay")
			TestQuestTick += delay * 1000
			Assert(nm_QuestRecovery.Ready("Polar", kind), "Repaired clock reservation eventually expires")
			for corrupt in ["bad", "10", "-1|50", "10000|99999999", "1.5|31.5"] {
				IniWrite corrupt, "settings\nm_config.ini", "QuestRecovery", "Riley." kind
				AssertEqual(nm_QuestRecovery.Remaining("Riley", kind), delay, "Corrupt metadata gets one bounded delay")
				TestQuestTick += delay * 1000
				Assert(nm_QuestRecovery.Ready("Riley", kind), "Corrupt metadata repair does not renew forever")
			}
		}
		ResetQuestRecoveryFixture()
		Assert(nm_QuestRecovery.Begin("Bucko", "visit") && nm_QuestRecovery.Begin("Bucko", "read"), "Read and visit reservations are independent")
		nm_QuestRecovery.Finish("Bucko", "read", true)
		Assert(nm_QuestRecovery.Ready("Bucko", "read") && !nm_QuestRecovery.Ready("Bucko", "visit"), "Successful reading does not clear failed/in-flight visit")
		Assert(nm_QuestRecovery.Begin("Brown", "visit"), "Other quest family is not blocked")
		AssertThrows(() => nm_QuestRecovery.Begin("invalid", "visit"), "Invalid family rejected")
		AssertThrows(() => nm_QuestRecovery.Begin("Honey", "invalid"), "Invalid operation rejected")
	} finally {
		nm_QuestRecovery.Clock := originalClock, nm_QuestRecovery.Tick := originalTick, TestNow := previousNow
		ResetQuestRecoveryFixture()
	}
}

TestQuestTurnInRecovery() {
	global
	local family, originalTick := nm_QuestRecovery.Tick, savedNow := TestNow, interrupted, failedWrite
	nm_QuestRecovery.Tick := () => TestQuestTick
	TestQuestMode := true
	try {
		for family in ["Honey", "Polar", "Riley", "Bucko", "Black", "Brown"] {
			ResetQuestRecoveryFixture(), TestQuestTick := 100000, TestNow := 10000
			%family%QuestCheck := 1, %family%QuestComplete := 1
			TestQuestVisits := 0, TotalQuestsComplete := SessionQuestsComplete := 0
			LastBlackQuest := LastBrownQuest := 0
			TestQuestReadings := [-1]
			Assert(!nm_TryQuestTurnIn(family, TestReadQuest.Bind(family)), family " unreadable post-visit state is unconfirmed")
			AssertEqual(TestQuestVisits, 1, family " first trip occurred")
			AssertEqual(TotalQuestsComplete, 0, family " failed visit is not counted")
			%family%QuestComplete := 1, TestQuestReadings := [0]
			Assert(!nm_TryQuestTurnIn(family, TestReadQuest.Bind(family)), family " repeated trip blocked by reservation")
			AssertEqual(TestQuestVisits, 1, family " no repeated travel during backoff")
			TestQuestTick += 300000, TestNow += 300
			Assert(nm_TryQuestTurnIn(family, TestReadQuest.Bind(family)), family " succeeds after delay")
			Assert(nm_QuestRecovery.Ready(family, "visit"), family " confirmed transition clears retry delay")
			AssertEqual(TotalQuestsComplete, family = "Honey" ? 0 : 1, family " only confirmed attempt counted")

			%family%QuestComplete := 1, TestQuestTravelThrows := true, interrupted := false
			try nm_TryQuestTurnIn(family, TestReadQuest.Bind(family))
			catch Error
				interrupted := true
			Assert(interrupted && !nm_QuestRecovery.Ready(family, "visit"), family " interruption leaves retry delay")
			Assert(!nm_QuestRecovery.Active.Has(family ".visit"), family " interruption releases in-process ownership")
		}
		ResetQuestRecoveryFixture(), BlackQuestComplete := 1, TestQuestVisits := 0, failedWrite := false
		FileMove "settings\nm_config.ini", "settings\quest-fixture-config.ini"
		DirCreate "settings\nm_config.ini"
		try {
			try nm_TryQuestTurnIn("Black", TestReadQuest.Bind("Black"))
			catch Error
				failedWrite := true
			Assert(failedWrite && !TestQuestVisits, "Persistence failure prevents travel")
		} finally {
			DirDelete "settings\nm_config.ini"
			FileMove "settings\quest-fixture-config.ini", "settings\nm_config.ini"
		}
	} finally {
		TestQuestMode := false, TestNow := savedNow, nm_QuestRecovery.Tick := originalTick
		ResetQuestRecoveryFixture()
	}
}
