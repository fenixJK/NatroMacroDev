#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "%A_ScriptDir%\..\lib\RuntimePolicy.ahk"
#Include "%A_ScriptDir%\..\lib\PlanterRecovery.ahk"
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\BlenderAccounting.ahk"
#Include "%A_ScriptDir%\..\lib\TimeTracking.ahk"
#Include "%A_ScriptDir%\..\lib\CollectionRecovery.ahk"
#Include "%A_ScriptDir%\..\lib\DispenserCollection.ahk"
#Include "%A_ScriptDir%\..\lib\CollectionInterrupts.ahk"
#Include "%A_ScriptDir%\..\lib\Conversion.ahk"
#Include "%A_ScriptDir%\..\lib\DurationFromSeconds.ahk"
#Include "%A_ScriptDir%\..\lib\PlanterObservation.ahk"
#Include "%A_ScriptDir%\..\lib\FailureLog.ahk"
#Include "%A_ScriptDir%\..\lib\Gdip_All.ahk"
#Include "%A_ScriptDir%\..\lib\Gdip_ImageSearch.ahk"
#Include "%A_ScriptDir%\..\lib\AutoFieldBoost.ahk"
#Include "%A_ScriptDir%\..\lib\Discord.ahk"
#Include "%A_ScriptDir%\..\lib\HourlyReportDelivery.ahk"
#Include "%A_ScriptDir%\DeliveryTests.ahk"
#Include "%A_ScriptDir%\..\lib\WindowGeometry.ahk"
#Include "%A_ScriptDir%\..\lib\InventorySearchEngine.ahk"
#Include "%A_ScriptDir%\..\lib\InventoryDrag.ahk"
#Include "%A_ScriptDir%\GeometryTests.ahk"
#Include "%A_ScriptDir%\InventoryDragTests.ahk"
#Include "%A_ScriptDir%\..\lib\QuestObservation.ahk"
#Include "%A_ScriptDir%\..\lib\QuestActions.ahk"
#Include "%A_ScriptDir%\QuestTests.ahk"
#Include "%A_ScriptDir%\..\lib\HealthObservation.ahk"
#Include "%A_ScriptDir%\HealthTests.ahk"
#Include "%A_ScriptDir%\..\lib\BossHealthEstimation.ahk"
#Include "%A_ScriptDir%\BossHealthTests.ahk"
#Include "%A_ScriptDir%\..\lib\ImageObservation.ahk"
#Include "%A_ScriptDir%\ImageObservationTests.ahk"
#Include "%A_ScriptDir%\..\lib\CombatPresence.ahk"
#Include "%A_ScriptDir%\..\lib\RemoteCapabilities.ahk"
#Include "%A_ScriptDir%\RemoteCapabilityTests.ahk"

; No Roblox or external service is used. HTTP tests contact a loopback fixture.
; Unexpected game observation/input throws; native GUI checks run separately.
TestNow := 10000
TestQuestMode := false
webhook := "https://discord.invalid/test", bottoken := "fixture-token", discordMode := 0
MainChannelCheck := 0, MainChannelID := "", commandPrefix := "!", command_buffer := []
TestCollectionMode := false, TestCollectionReads := 0, TestCollectionThrow := false
HoneyDisCheck := TreatDisCheck := BlueberryDisCheck := StrawberryDisCheck := CoconutDisCheck := 0
LastHoneyDis := LastTreatDis := LastBlueberryDis := LastStrawberryDis := LastCoconutDis := 0
CoconutBoosterCheck := BoostChaserCheck := 0
beesmasActive := BeesmasGatherInterruptCheck := MemoryMatchInterruptCheck := 0
StockingsCheck := FeastCheck := RBPDelevelCheck := GingerbreadCheck := SnowMachineCheck := 0
CandlesCheck := SamovarCheck := LidArtCheck := GummyBeaconCheck := WinterMemoryMatchCheck := 0
NormalMemoryMatchCheck := MegaMemoryMatchCheck := ExtremeMemoryMatchCheck := 0
LastStockings := LastFeast := LastRBPDelevel := LastGingerbread := LastSnowMachine := 0
LastCandles := LastSamovar := LastLidArt := LastGummyBeacon := LastWinterMemoryMatch := 0
LastNormalMemoryMatch := LastMegaMemoryMatch := LastExtremeMemoryMatch := 0
HideErrors := 1, AutoFieldBoostRefresh := 10, FieldBooster := Map()
windowX := windowY := windowWidth := 0, bitmaps := Map(), CurrentField := ""
LastBlueBoost := LastRedBoost := LastMountainBoost := 0
AutoFieldBoostActive := MacroState := 0
AFBHoursLimitEnable := AFBHoursLimit := serverStart := 0
AFBDiceEnable := AFBGlitterEnable := AFBFieldEnable := 0
AFBrollingDice := AFBuseGlitter := AFBuseBooster := 0
AFBDiceLimitEnable := AFBGlitterLimitEnable := 0
AFBDiceLimit := AFBGlitterLimit := AFBdiceUsed := AFBglitterUsed := 0
AFBDiceHotbar := 2, AFBGlitterHotbar := 3
AFBGui := Map(), MainGui := Map(), LastTestStatus := ""
for setupItem in ["Dice", "Glitter", "Hours"] {
	AFBGui["AFB" setupItem "LimitEnableSel"] := {Text: "None"}
	AFBGui["AFB" setupItem "Limit"] := {Enabled: false}
}
AFBGui["AutoFieldBoostActive"] := {Value: 0}
MainGui["AutoFieldBoostButton"] := {Text: ""}

testDirectory := A_Temp "\natro-tests-" DllCall("GetCurrentProcessId") "-" A_TickCount
DirCreate testDirectory "\settings"
SetWorkingDir testDirectory
passed := failed := 0
try {
	for test in [TestPriorities, TestReconnect, TestBudgets, TestLimitsUpdateLive,
		TestCancellation, TestHourCap, TestDisabledAFB, TestPermissions, TestWaitUnits, TestFailureLogging, TestUpdateAssets, TestPlanterRecovery, TestPlanterObservation, TestBlenderAccounting, TestTimeTracking, TestConversionCleanup, TestCollectionRecovery, TestDispenserFailures, TestCollectionInterrupts, TestDiscordPayload, TestDeliveryQueue, TestHourlyReportDelivery, TestLocalHttpDelivery, TestGeometryCache, TestInventoryEngine, TestInventoryReader, TestPointerLease, TestInventoryDrag, TestQuestObservation, TestQuestFrames, TestQuestActions, TestQuestUnknownPublication, TestQuestRecovery, TestQuestTurnInRecovery, TestHealthObservation, TestBossHealthEstimation, TestBossHealthReporting, TestImageObservation, TestCombatPresence, TestRemoteCapabilities] {
		try {
			test.Call()
			passed++
			FileAppend "PASS " test.Name "`n", "*"
		} catch as testFailure {
			failed++
			FileAppend "FAIL " test.Name ": " testFailure.Message "`n" testFailure.Stack "`n", "*"
		}
	}
} finally {
	SetWorkingDir A_ScriptDir
	DirDelete testDirectory, true
}
FileAppend passed " passed; " failed " failed (" A_PtrSize * 8 "-bit AHK " A_AhkVersion ")`n", "*"
ExitApp failed ? 1 : 0

Assert(condition, message) {
	if !condition
		throw Error(message)
}
AssertEqual(actual, expected, message) {
	Assert(actual == expected, message " (expected " expected ", got " actual ")")
}
AssertThrows(action, message) {
	try action.Call()
	catch ValueError
		return
	throw Error(message)
}

TestPriorities() {
	first := nm_BuildPriorityList("12345678")
	second := nm_BuildPriorityList("87654321")
	AssertEqual(first.Length, 8, "One entry per task")
	AssertEqual(second.Length, 8, "Rebuilding must not append old entries")
	AssertEqual(first[1], "Night", "Default first task")
	AssertEqual(second[1], "GoGather", "Edited first task")
	for invalid in ["11111111", "1234567", "123456789", "01234567", "abcdefgh"]
		AssertThrows(nm_BuildPriorityList.Bind(invalid), "Reject invalid priority: " invalid)
}

TestReconnect() {
	code := "12345678901234567890123456789012"
	private := nm_ParsePrivateServer("https://www.roblox.com/games/1537690962/?privateServerLinkCode=" code)
	share := nm_ParsePrivateServer("https://www.roblox.com/share?code=" code "&type=Server")
	AssertEqual(private["type"], "LinkCode", "Private link recognized")
	AssertEqual(share["code"], code, "Share code preserved")
	for invalid in ["", "garbage", "https://evil.example/share?code=" code "&type=Server",
		"https://www.roblox.com/share?code=short&type=Server",
		"https://www.roblox.com/games/1/?privateServerLinkCode=" code]
		Assert(!nm_ParsePrivateServer(invalid), "Malformed link rejected")
	for attempt in [1, 5, 6, 20, 21, 100]
		AssertEqual(nm_SelectReconnectServer([1], attempt, false), 1, "Private-only remains private")
	AssertEqual(nm_SelectReconnectServer([1, 4], 6, false), 4, "Empty backup slots skipped")
	AssertEqual(nm_SelectReconnectServer([1, 4], 11, false), 1, "Private candidates cycle")
	AssertEqual(nm_SelectReconnectServer([1, 4], 11, true), 0, "Public used after private attempts")
	AssertEqual(nm_SelectReconnectServer([], 1, false), -1, "No valid private candidate is an error")
	AssertEqual(nm_SelectReconnectServer([], 1, true), 0, "Public-only mode supported")
}

TestBudgets() {
	Assert(!nm_BudgetAvailable(false, true, false, 0, 0), "Master off denies items")
	Assert(!nm_BudgetAvailable(true, false, false, 0, 0), "Item off denies items")
	Assert(nm_BudgetAvailable(true, true, false, 100, 0), "Explicit unlimited policy")
	Assert(!nm_BudgetAvailable(true, true, true, 0, 0), "Zero limit denies first attempt")
	Assert(nm_BudgetAvailable(true, true, true, 0, 1), "One remaining attempt")
	Assert(!nm_BudgetAvailable(true, true, true, 1, 1), "Exhausted budget denies another attempt")
	Assert(!nm_BudgetAvailable(true, true, true, 5, 1), "Lowered limit applies immediately")
	Assert(!nm_BudgetAvailable(true, true, true, 0, "bad"), "Malformed limit fails closed")
	Assert(!nm_BudgetAvailable(true, true, false, -1, 0), "Negative usage rejected")
}

TestLimitsUpdateLive() {
	global AFBGui, AFBDiceLimitEnable, AFBGlitterLimitEnable, AFBHoursLimitEnable
	for selection in ["Limit", "None"] {
		for item in ["Dice", "Glitter", "Hours"]
			AFBGui["AFB" item "LimitEnableSel"].Text := selection
		nm_AFBDiceLimitEnable(), nm_AFBGlitterLimitEnable(), nm_AFBHoursLimitEnable()
		expected := selection = "Limit"
		AssertEqual(AFBDiceLimitEnable, expected, "Dice live flag")
		AssertEqual(AFBGlitterLimitEnable, expected, "Glitter live flag")
		AssertEqual(AFBHoursLimitEnable, expected, "Hours live flag")
		for item in ["Dice", "Glitter", "Hours"] {
			AssertEqual(IniRead("settings\nm_config.ini", "Boost", "AFB" item "LimitEnable"), expected, "Persisted flag")
			AssertEqual(AFBGui["AFB" item "Limit"].Enabled, expected, "UI matches live flag")
		}
	}
}

TestCancellation() {
	global AutoFieldBoostActive, AFBrollingDice, AFBuseGlitter, AFBuseBooster
	AutoFieldBoostActive := AFBrollingDice := AFBuseGlitter := AFBuseBooster := 1
	nm_CancelAFB("test cancellation")
	AssertEqual(AutoFieldBoostActive | AFBrollingDice | AFBuseGlitter | AFBuseBooster, 0, "All pending actions canceled")
	AssertEqual(IniRead("settings\nm_config.ini", "Boost", "AutoFieldBoostActive"), 0, "Master off persisted")
	AssertEqual(AFBGui["AutoFieldBoostActive"].Value, 0, "GUI off")
}

TestHourCap() {
	global AutoFieldBoostActive, MacroState, AFBHoursLimitEnable, AFBHoursLimit, serverStart
	global AFBrollingDice, AFBuseGlitter, AFBuseBooster, TestNow
	MacroState := 2, AFBHoursLimitEnable := 1, AFBHoursLimit := 1, serverStart := TestNow - 3599
	AutoFieldBoostActive := 1
	Assert(nm_AFBReady(), "Available one second before cap")
	serverStart := TestNow - 3600
	AFBrollingDice := AFBuseGlitter := AFBuseBooster := 1
	Assert(!nm_AFBReady(), "Cap includes exact boundary")
	AssertEqual(AFBrollingDice | AFBuseGlitter | AFBuseBooster, 0, "Hour cap clears pending actions")
}

TestDisabledAFB() {
	global AutoFieldBoostActive, MacroState, AFBrollingDice, AFBuseGlitter, AFBuseBooster
	AutoFieldBoostActive := 0, MacroState := 2
	AFBrollingDice := AFBuseGlitter := AFBuseBooster := 1
	; Observation stubs throw if any function proceeds to the game.
	nm_fieldBoostDice(), nm_fieldBoostGlitter(), nm_fieldBoostBooster()
	AutoFieldBoostActive := 1, MacroState := 1
	Assert(!nm_AFBReady(), "Paused macro cannot use items")
}

TestPermissions() {
	owner := "123456789012345678", other := "234567890123456789", role := "345678901234567890"
	Assert(!nm_CommandAuthorized("", owner), "Blank allowlist denies commands")
	Assert(!nm_CommandAuthorized(owner, other), "Wrong user denied")
	Assert(nm_CommandAuthorized(owner, owner), "Explicit owner allowed")
	Assert(!nm_CommandAuthorized("&" role, owner, -1), "Role lookup failure denied")
	Assert(!nm_CommandAuthorized("&" role, owner, [other]), "Missing role denied")
	Assert(nm_CommandAuthorized("&" role, owner, [other, role]), "Role member allowed")
	Assert(!nm_CommandAuthorized("invalid", "invalid"), "Malformed identities denied")
}

TestWaitUnits() {
	AssertEqual(nm_RemainingWaitMs(20000, 1000, 11000), 10000, "Ten seconds already elapsed")
	AssertEqual(nm_RemainingWaitMs(20000, 1000, 21000), 0, "Minimum met exactly")
	AssertEqual(nm_RemainingWaitMs(20000, 1000, 31000), 0, "Long reset needs no extra sleep")
	AssertEqual(nm_RemainingWaitMs(-1000, 1000, 1000), 0, "Negative waits clamped")
}

TestFailureLogging() {
	err := Error("Request failed: https://discord.com/api/webhooks/123/private-token")
	path := nm_Failures.Write(err, "unit test", A_WorkingDir "\errors")
	Assert(FileExist(path), "Exception recorded locally")
	entry := FileRead(path)
	Assert(InStr(entry, "Stack:") && InStr(entry, "unit test"), "Useful error context retained")
	Assert(!InStr(entry, "private-token"), "Webhook credential redacted")
	Assert(!InStr(nm_Failures.Redact("privateServerLinkCode=abc123"), "abc123"), "Private server code redacted")
}

nowUnix() => TestNow
nm_setStatus(state, objective) {
	global LastTestStatus := state ": " objective
}
GetRobloxHWND() => TestCollectionMode ? 1 : UnexpectedObservation()
GetRobloxClientPos(*) => TestCollectionMode ? 0 : UnexpectedObservation()
GetYOffset(*) => TestCollectionMode ? 0 : UnexpectedObservation()
nm_Reset(*) => TestCollectionMode ? 0 : UnexpectedObservation()
nm_updateAction(*) => (TestCollectionMode || TestQuestMode) ? 0 : UnexpectedObservation()
nm_gotoCollect(*) => TestCollectionMode ? 0 : UnexpectedObservation()
nm_imgSearch(*) {
	global TestCollectionReads
	if !TestCollectionMode
		return UnexpectedObservation()
	TestCollectionReads++
	if TestCollectionThrow
		throw Error("Interrupted collection observation")
	return [1] ; Prompt absent: production routines must never reach SendInput.
}
ActivateRoblox(*) => UnexpectedObservation()
nm_toBooster(*) => UnexpectedObservation()
UnexpectedObservation() {
	throw Error("Test unexpectedly attempted game observation or input")
}

TestUpdateAssets() {
	asset := Map("browser_download_url", "https://github.com/NatroTeam/NatroMacro/releases/download/v1.2/Natro_Macro.zip", "size", 100)
	other := Map("browser_download_url", "https://github.com/NatroTeam/NatroMacro/releases/download/v1.2/SHA256.txt", "size", 10)
	Assert(nm_SelectUpdateAsset([other, asset]) = asset, "Choose ZIP rather than first asset")
	AssertThrows(nm_SelectUpdateAsset.Bind([other]), "No ZIP must fail")
	AssertThrows(nm_SelectUpdateAsset.Bind([asset, asset]), "Ambiguous ZIP must fail")
	bad := asset.Clone(), bad["size"] := 0
	AssertThrows(nm_SelectUpdateAsset.Bind([bad]), "Zero size must fail")
	bad := asset.Clone(), bad["browser_download_url"] := "https://example.com/fake.zip"
	AssertThrows(nm_SelectUpdateAsset.Bind([bad]), "Non-release download must fail")
}

TestPlanterRecovery() {
	global TestNow
	TestNow := 10000
	IniWrite "PaperPlanter", "settings\nm_config.ini", "Planters", "PlanterName1"
	IniWrite "Sunflower", "settings\nm_config.ini", "Planters", "PlanterField1"
	IniWrite 3, "settings\nm_config.ini", "Planters", "MaxAllowedPlanters"
	planterState := {calls: 0, result: 0}
	action := (slot) => (planterState.calls++, planterState.result)
	AssertEqual(nm_PlanterRecovery.Harvest(1, "PaperPlanter", "Sunflower", action), 0, "Failed harvest stays unconfirmed")
	AssertEqual(planterState.calls, 5, "Harvest retry count bounded")
	AssertEqual(IniRead("settings\nm_config.ini", "Planters", "PlanterName1"), "PaperPlanter", "Failure retains identity")
	AssertEqual(IniRead("settings\nm_config.ini", "Planters", "PlanterField1"), "Sunflower", "Failure retains field")
	AssertEqual(nm_PlanterRecovery.Harvest(1, "PaperPlanter", "Sunflower", action), 0, "Persistent delay applies")
	AssertEqual(planterState.calls, 5, "Deferred action receives no input")
	Assert(!nm_PlanterRecovery.Ready("Harvest1", "PaperPlanter:Sunflower", 10299), "Delay holds until boundary")
	Assert(nm_PlanterRecovery.Ready("Harvest1", "PaperPlanter:Sunflower", 10300), "Delay expires at boundary")
	Assert(nm_PlanterRecovery.Ready("Harvest1", "PlasticPlanter:Sunflower", 10000), "Changed planter does not inherit delay")
	TestNow := 10300, planterState.result := 1
	AssertEqual(nm_PlanterRecovery.Harvest(1, "PaperPlanter", "Sunflower", action), 1, "Successful retry returns success")
	AssertEqual(planterState.calls, 6, "Success stops retry loop")
	AssertEqual(IniRead("settings\nm_config.ini", "PlanterRecovery", "Harvest1"), "", "Success clears recovery marker")
	planterState.result := 2
	AssertEqual(nm_PlanterRecovery.Harvest(1, "PaperPlanter", "Sunflower", action), 2, "Not-ready/held result preserved")
	AssertThrows(() => nm_PlanterRecovery.Harvest(2, "PlasticPlanter", "Rose", (slot) => ThrowPlanterInterruption()), "Interruption propagates")
	Assert(!nm_PlanterRecovery.Ready("Harvest2", "PlasticPlanter:Rose", TestNow), "Interruption leaves reservation")
	nm_PlanterRecovery.Clear("Placement")
	place := () => (planterState.calls++, 3)
	AssertEqual(nm_PlanterRecovery.Placement(place), 3, "Capacity rejection retained")
	calls := planterState.calls
	AssertEqual(nm_PlanterRecovery.Placement(place), 3, "Placement delay stops caller")
	AssertEqual(planterState.calls, calls, "Placement delay does not repeat input")
	nm_PlanterRecovery.PlacementFailed()
	AssertEqual(IniRead("settings\nm_config.ini", "Planters", "MaxAllowedPlanters"), 3, "Failure must not lower configured capacity")
	Assert(nm_PlanterRecovery.Ready("Placement", "Planters", TestNow - 1000), "Clock rollback does not strand placement")
	for name in ["PaperPlanter", "TicketPlanter", "FestivePlanter", "UnknownPlanter"]
		Assert(!nm_PlanterInventoryConfirmsAbsent(name, [30, 200]), "Stack/unknown inventory is not absence evidence")
	Assert(nm_PlanterInventoryConfirmsAbsent("PlasticPlanter", [30, 200]), "Reusable inventory observation accepted")
	for pos in [0, -1, "error", [], [0, 200], [30, -1]]
		Assert(!nm_PlanterInventoryConfirmsAbsent("PlasticPlanter", pos), "Invalid observation rejected")
}
ThrowPlanterInterruption() {
	throw ValueError("Interrupted planter action")
}

TestPlanterObservation() {
	token := Gdip_Startup()
	Assert(token, "GDI+ must initialize for bitmap tests")
	screen := 0
	try {
		AssertEqual(nm_PlanterProgressReader.Read(0), 0, "Capture failure is unknown")
		screen := Gdip_CreateBitmap(150, 30)
		Assert(screen, "Synthetic screen allocated")
		graphics := Gdip_GraphicsFromImage(screen)
		try Gdip_GraphicsClear(graphics, 0xff000000)
		finally Gdip_DeleteGraphics(graphics)
		AssertEqual(nm_PlanterProgressReader.Read(screen), 0, "Blank image is unknown")
		for filled in [25, 50, 75, 99] {
			DrawPlanterTestBar(screen, filled, true)
			Assert(Abs(nm_PlanterProgressReader.Read(screen) - filled / 100) < 0.00001, "Known bar proportion: " filled)
		}
		AssertEqual(Gdip_LockBits(screen, 0, 0, 150, 30, &stride, &scan, &locked), 0, "Test can lock the source bitmap")
		try AssertEqual(nm_PlanterProgressReader.Read(screen), 0, "Image-search lock failure is unknown, not an unset-variable error")
		finally Gdip_UnlockBits(screen, &locked)
		DrawPlanterTestBar(screen, 75, false)
		AssertEqual(nm_PlanterProgressReader.Read(screen), 0, "Missing remaining-bar anchor is unknown")
		nm_PlanterProgressReader.Release()
		DrawPlanterTestBar(screen, 50, true)
		AssertEqual(nm_PlanterProgressReader.Read(screen), 0.5, "Reader rebuilds after resource release")
		AssertEqual(nm_PlanterProgressReader.Needles.Length, 3, "Needles are cached rather than leaked per observation")
	} finally {
		nm_PlanterProgressReader.Release()
		if screen
			Gdip_DisposeImage(screen)
		Gdip_Shutdown(token)
	}
}
DrawPlanterTestBar(screen, filled, remaining) {
	graphics := Gdip_GraphicsFromImage(screen)
	green := Gdip_BrushCreateSolid(0xff86d570)
	dark := Gdip_BrushCreateSolid(0xff567848)
	try {
		Gdip_GraphicsClear(graphics, 0xff000000)
		Gdip_FillRectangle(graphics, green, 10, 10, filled, 8)
		if remaining
			Gdip_FillRectangle(graphics, dark, 10+filled, 10, 100-filled, 8)
	} finally {
		Gdip_DeleteBrush(green), Gdip_DeleteBrush(dark)
		Gdip_DeleteGraphics(graphics)
	}
}

ResetBlenderTest() {
	global BlenderRot := 1, LastBlenderRot := 1, TimerInterval := 0, BlenderCheck := 1, BlenderEnd := 0
		, BlenderIndex1 := 1, BlenderIndex2 := 1, BlenderIndex3 := 0
		, BlenderItem1 := "Glue", BlenderItem2 := "Oil", BlenderItem3 := "None"
		, BlenderAmount1 := 2, BlenderAmount2 := 1, BlenderAmount3 := 0
		, BlenderTime1 := 0, BlenderTime2 := 0, BlenderTime3 := 0
		, BlenderCount1 := 2, BlenderCount2 := 3, BlenderCount3 := 0, MainGui
	Loop 3
	{
		MainGui["BlenderData" A_Index] := {Text: ""}
		IniWrite 0, "settings\nm_config.ini", "Blender", "Unavailable" A_Index
	}
	IniWrite "", "settings\nm_config.ini", "Blender", "PendingAttempt"
	IniWrite "", "settings\nm_config.ini", "Blender", "PendingCommit"
}
TestBlenderWriter(state, key, value) {
	state.calls++
	if state.calls = 4
		throw ValueError("Injected interruption during Blender persistence")
	nm_BlenderWriteSetting(key, value)
}
TestBlenderAccounting() {
	global BlenderRot, LastBlenderRot, BlenderIndex1, BlenderIndex2, BlenderAmount1, BlenderCheck
		, BlenderTime1, BlenderTime2, BlenderTime3
	ResetBlenderTest()
	recipes := nm_BlenderReadRecipes()
	plan := nm_BlenderPlanCraft(recipes, 1, 10000)
	AssertEqual(plan["BlenderIndex1"], 0, "Charge executed finite slot")
	Assert(!plan.Has("BlenderIndex2"), "Next recipe must not be charged")
	AssertEqual(plan["BlenderRot"], 2, "Advance after charging current slot")
	AssertEqual(plan["LastBlenderRot"], 1, "Keep executed slot separately")
	AssertEqual(plan["BlenderTime1"], 10600, "Actual batch completion estimate")
	AssertEqual(plan["BlenderTime2"], 10900, "Queue estimate follows actual batch")
	AssertEqual(plan["BlenderTime3"], 0, "Empty recipe has no fabricated timer")
	AssertEqual(recipes[1].remaining, 1, "Planner does not mutate input")
	recipes[2].remaining := "Infinite"
	plan := nm_BlenderPlanCraft(recipes, 2, 10000)
	AssertEqual(plan["BlenderIndex2"], "Infinite", "Infinite executed recipe is unchanged")
	AssertEqual(plan["BlenderRot"], 1, "Wrap to finite recipe")
	recipes[1].remaining := 0
	plan := nm_BlenderPlanCraft(recipes, 2, 10000)
	AssertEqual(plan["BlenderRot"], 2, "Single infinite recipe repeats")
	AssertThrows(() => nm_BlenderPlanCraft(recipes, 1, 10000), "Exhausted slot cannot start")
	recipes[2].amount := 0
	AssertThrows(() => nm_BlenderPlanCraft(recipes, 2, 10000), "Zero quantity cannot start")

	expected := nm_BlenderReadRecipes()[1]
	for observation in [0, -1] {
		AssertEqual(nm_BlenderCommitAccepted(1, expected, observation, 10000), 0, "Unconfirmed craft not committed")
		AssertEqual(BlenderIndex1, 1, "Rejection preserves current count")
		AssertEqual(BlenderTime1, 0, "Rejection preserves timer")
	}
	Assert(nm_BlenderRecipeUnchanged(1, expected), "Observed recipe initially matches configuration")
	BlenderAmount1 := 3
	Assert(!nm_BlenderRecipeUnchanged(1, expected), "Pre-confirm check detects live recipe edit")
	AssertEqual(nm_BlenderCommitAccepted(1, expected, 1, 10000), 0, "Live recipe edit rejects stale charge")
	ResetBlenderTest()
	expected := nm_BlenderReadRecipes()[1]
	AssertEqual(nm_BlenderCommitAccepted(1, expected, 1, 10000), 1, "Confirmed craft committed")
	AssertEqual(BlenderIndex1, 0, "Runtime current count updated")
	AssertEqual(BlenderIndex2, 1, "Runtime next count retained")
	AssertEqual(LastBlenderRot, 1, "Runtime last slot updated alongside INI")
	AssertEqual(BlenderRot, 2, "Runtime next slot selected")
	AssertEqual(IniRead("settings\nm_config.ini", "Blender", "BlenderIndex1"), 0, "Charged count persisted")
	AssertEqual(IniRead("settings\nm_config.ini", "Blender", "PendingCommit"), "", "Completed commit clears journal")

	ResetBlenderTest()
	expected := nm_BlenderReadRecipes()[1], fault := {calls: 0}
	AssertThrows(() => nm_BlenderCommitAccepted(1, expected, 1, 10000, TestBlenderWriter.Bind(fault)), "Write interruption propagated")
	Assert(IniRead("settings\nm_config.ini", "Blender", "PendingCommit") != "", "Interrupted commit retains journal")
	nm_BlenderRecoverCommit()
	AssertEqual(BlenderIndex1, 0, "Recovery completes the recorded decrement")
	AssertEqual(BlenderIndex2, 1, "Recovery leaves next slot intact")
	nm_BlenderRecoverCommit()
	AssertEqual(BlenderIndex1, 0, "Repeated recovery does not double charge")

	ResetBlenderTest()
	BlenderIndex2 := 0
	expected := nm_BlenderReadRecipes()[1]
	nm_BlenderCommitAccepted(1, expected, 1, 10000)
	AssertEqual(nm_BlenderRotation(), 0, "No next recipe after final finite batch")
	AssertEqual(BlenderCheck, 1, "Final batch must remain scheduled for collection")
	BlenderTime1 := 0
	AssertEqual(nm_BlenderRotation(), 0, "Empty queue has no next slot")
	AssertEqual(BlenderCheck, 0, "Stop scheduling after final batch collected")
	ResetBlenderTest()
	IniWrite nowUnix() + 300, "settings\nm_config.ini", "Blender", "Unavailable1"
	AssertEqual(nm_BlenderRotation(), 2, "Ingredient shortage temporarily skips only the affected recipe")
	AssertEqual(BlenderIndex1, 1, "Skipping unavailable recipe preserves its repetitions")
	IniWrite nowUnix() + 300, "settings\nm_config.ini", "Blender", "Unavailable2"
	AssertEqual(nm_BlenderRotation(), 0, "All unavailable recipes defer travel")
	AssertEqual(BlenderCheck, 1, "Unavailable recipes remain configured for later retry")
	ResetBlenderTest()
	expected := nm_BlenderReadRecipes()[1]
	nm_BlenderRememberAttempt(1, expected, 10000)
	attempt := nm_BlenderReadAttempt()
	AssertEqual(attempt["slot"], 1, "Pending input record survives INI round trip")
	AssertEqual(nm_BlenderResolveAttempt(attempt, "Oil", 1, 0, 10300), 0, "Wrong visible recipe cannot resolve an attempt")
	AssertEqual(nm_BlenderResolveAttempt(attempt, "Glue", -1, 1, 10300), 0, "Failed observation cannot resolve an attempt")
	AssertEqual(nm_BlenderResolveAttempt(attempt, "Glue", 0, 1, 10600), 1, "Late completed-craft observation resolves original attempt")
	AssertEqual(BlenderIndex1, 0, "Late confirmation charges original slot once")
	AssertEqual(BlenderTime1, 10600, "Late confirmation retains original start time")
	Assert(!nm_BlenderReadAttempt(), "Committed attempt is removed")
	ResetBlenderTest()
	attempt := nm_BlenderRememberAttempt(1, nm_BlenderReadRecipes()[1], 10000)
	attempt["pid"] := 0
	AssertEqual(nm_BlenderResolveAttempt(attempt, "Glue", 1, 0, 10300), 0, "A restarted process needs explicit reconciliation for unconfirmed input")
}

ResetTimeTest() {
	global TestTick := 1000000, TestNow := 10000
		, TotalRuntime := 0, SessionRuntime := 0, TotalGatherTime := 0, SessionGatherTime := 0
		, TotalConvertTime := 0, SessionConvertTime := 0
		, MacroStartTime := 0, GatherStartTime := 0, ConvertStartTime := 0
	nm_TimeTracking.Clock := nm_ActivityClock()
	nm_TimeTracking.TickSource := TestMonotonicTick
}
TestMonotonicTick() => TestTick
TestTimeTracking() {
	global TestTick, TestNow, TotalRuntime, SessionRuntime, TotalGatherTime, SessionGatherTime
		, TotalConvertTime, SessionConvertTime, MacroStartTime, GatherStartTime, ConvertStartTime
	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime")
	TestTick += 5000
	nm_TimeTracking.Begin("Gather")
	TestTick += 20000
	nm_TimeTracking.Pause()
	AssertEqual(TotalRuntime, 25, "Pause credits runtime once")
	AssertEqual(TotalGatherTime, 20, "Pause credits active gathering")
	AssertEqual(TotalConvertTime, 0, "Pause does not invent conversion")
	AssertEqual(MacroStartTime + GatherStartTime + ConvertStartTime, 0, "Paused markers are cleared")
	TestTick += 60000
	nm_TimeTracking.Pause()
	nm_TimeTracking.Stop()
	nm_TimeTracking.Stop()
	AssertEqual(TotalRuntime, 25, "Pause then stop never charges paused or already credited time")
	AssertEqual(TotalGatherTime, 20, "Repeated stop does not double count gathering")
	AssertEqual(IniRead("settings\nm_config.ini", "Status", "TotalRuntime"), 25, "Credited totals persisted")

	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime"), nm_TimeTracking.Begin("Convert")
	TestTick += 10000
	nm_TimeTracking.Pause()
	TestTick += 120000
	AssertEqual(nm_TimeTracking.Elapsed("Convert"), 10, "Action deadline excludes paused interval")
	nm_TimeTracking.Resume(), nm_TimeTracking.Resume()
	Assert(!nm_TimeTracking.Active("Gather"), "Resume does not start gathering during conversion")
	Assert(nm_TimeTracking.Active("Convert"), "Resume restores active conversion")
	TestTick += 20000
	nm_TimeTracking.End("Convert")
	AssertEqual(TotalConvertTime, 30, "Conversion counts both active segments")
	AssertEqual(nm_TimeTracking.Elapsed("Convert"), 30, "Action elapsed time survives pause and end")
	AssertEqual(ConvertStartTime, 0, "Ended conversion marker cleared")
	TestTick += 5000
	nm_TimeTracking.Stop()
	AssertEqual(TotalRuntime, 35, "Runtime includes non-conversion activity")
	AssertEqual(TotalConvertTime, 30, "Stop does not re-credit completed conversion")

	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime"), nm_TimeTracking.Begin("Gather")
	TestTick += 20000
	nm_TimeTracking.Flush()
	TotalRuntime := TotalGatherTime := 0 ; same boundary used before total-stat reset
	TestTick += 5000
	nm_TimeTracking.Stop()
	AssertEqual(TotalRuntime, 5, "Reset totals only include subsequent activity")
	AssertEqual(SessionRuntime, 25, "Reset total scope preserves session activity")
	AssertEqual(SessionGatherTime, 25, "Gathering session survives total-stat reset")
	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime"), nm_TimeTracking.Begin("Convert")
	TestTick += 20000
	nm_TimeTracking.Flush()
	SessionRuntime := SessionConvertTime := 0
	TestTick += 5000
	nm_TimeTracking.Stop()
	AssertEqual(SessionRuntime, 5, "Reset session only includes subsequent activity")
	AssertEqual(TotalRuntime, 25, "Session reset preserves total runtime")
	AssertEqual(TotalConvertTime, 25, "Session reset preserves total conversion")

	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime")
	TestTick += 250, TestNow += 86400
	nm_TimeTracking.Flush()
	TestTick += 250, TestNow -= 172800
	nm_TimeTracking.Stop()
	AssertEqual(TotalRuntime, 0.5, "Fractional intervals retained and wall-clock changes ignored")
	clock := nm_ActivityClock()
	clock.Begin("Runtime", 10000)
	AssertEqual(clock.Drain("Runtime", 9000), 0, "Backward tick cannot subtract time")
	AssertEqual(clock.Drain("Runtime", 11000), 1, "Backward tick does not move the accounting baseline")
}
AdvanceConversion(returnValue, fail := false) {
	global TestTick
	TestTick += 4000
	if fail
		throw ValueError("Injected conversion interruption")
	return returnValue
}
TestTimedOutConversion() {
	global TestTick
	TestTick += 300000
	return nm_ConvertAtHive(0, 0)
}
TestAFBInterruptedConversion() {
	global TestTick
	TestTick += 5000
	return nm_ConvertAtHive(0, 0)
}
TestConversionCleanup() {
	global TestTick, TotalRuntime, TotalConvertTime, ConvertStartTime, LastTestStatus, AutoFieldBoostActive, AFBuseGlitter
	global HiveConfirmed := 1, EnzymesKey := "none", LastEnzymes := 0, BackpackPercent := 50, BackpackPercentFiltered := 50
		, PFieldBoosted := 0, GatherFieldBoosted := 0, GatherFieldBoostedStart := 0, LastGlitter := 0, GlitterKey := "none"
		, GameFrozenCounter := 0, LastConvertBalloon := 0, ConvertBalloon := "Never", ConvertMins := 0, HiveBees := 1, ConvertGatherFlag := 0
		, state := "", windowHeight := 600, SC_E := "e"
	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime")
	AssertEqual(nm_TimeTracking.Run("Convert", AdvanceConversion.Bind("interrupted")), "interrupted", "Scoped conversion preserves early-return result")
	AssertEqual(TotalConvertTime, 4, "Early return credits elapsed conversion")
	AssertEqual(ConvertStartTime, 0, "Early return closes conversion marker")
	AssertThrows(() => nm_TimeTracking.Run("Convert", AdvanceConversion.Bind(0, true)), "Exception propagates through conversion scope")
	AssertEqual(TotalConvertTime, 8, "Exception still credits its active interval")
	AssertEqual(ConvertStartTime, 0, "Exception closes interval")
	nm_TimeTracking.Stop()
	AssertEqual(TotalConvertTime, 8, "Stop after exception cannot charge twice")
	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime")
	nm_TimeTracking.Run("Convert", TestConversionDisconnect)
	AssertEqual(TotalConvertTime, 10, "Reconnect wait is excluded from conversion")
	AssertEqual(nm_TimeTracking.Elapsed("Convert"), 10, "Ended action does not accrue during recovery")
	nm_TimeTracking.Stop()
	AssertEqual(TotalRuntime, 130, "Reconnect wait remains runtime")
	AssertEqual(TotalConvertTime, 10, "Finally after reconnect cannot re-credit the ended interval")
	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime")
	nm_TimeTracking.Run("Convert", TestTimedOutConversion)
	Assert(InStr(LastTestStatus, "timed out"), "Actual conversion body reports timeout")
	Assert(!InStr(LastTestStatus, "Emptied"), "Timeout cannot report empty backpack")
	AssertEqual(TotalConvertTime, 300, "Actual timeout closes and credits conversion")
	AssertEqual(ConvertStartTime, 0, "Timeout marker cleared")
	ResetTimeTest()
	nm_TimeTracking.Begin("Runtime")
	AutoFieldBoostActive := 0, AFBuseGlitter := 1
	nm_TimeTracking.Run("Convert", TestAFBInterruptedConversion)
	Assert(InStr(LastTestStatus, "AFB"), "Actual AFB branch returns before observation/input")
	AssertEqual(TotalConvertTime, 5, "Actual AFB early return credits its interval")
	AssertEqual(ConvertStartTime, 0, "Actual AFB early return clears marker")
	AFBuseGlitter := 0
	for value in [-1, "", "unknown", 1, 100]
		Assert(!nm_BackpackConversionComplete(value), "Only a valid zero reading is empty")
	Assert(nm_BackpackConversionComplete(0), "Zero backpack reading recognized")
	BackpackPercentFiltered := -1
	nm_TimeTracking.Run("Convert", nm_ConvertAtHive.Bind(0, 0))
	Assert(InStr(LastTestStatus, "unavailable"), "Invalid backpack observation cannot begin balloon conversion")
	nm_TimeTracking.Stop()
	nm_TimeTracking.TickSource := 0
}
nm_NightInterrupt() => TestQuestMode ? true : UnexpectedObservation()
nm_MondoInterrupt() => UnexpectedObservation()
disconnectcheck() => UnexpectedObservation()
nm_activeHoney() => UnexpectedObservation()
PostSubmacroMessage(*) => TestQuestMode ? 0 : UnexpectedObservation()

TestConversionDisconnect() {
	global TestTick
	TestTick += 10000
	nm_TimeTracking.InterruptActions() ; same boundary used when DisconnectCheck detects a disconnect
	TestTick += 120000
	return 0
}

TestCollectionRecovery() {
	global TestNow := 100000
	key := "LastTestDispenser"
	IniWrite 123, "settings\nm_config.ini", "Collect", key
	Assert(nm_CollectionRecovery.Begin(key), "First failed visit eligible")
	TestNow += 400 ; Failure after long travel renews the delay from its end.
	nm_CollectionRecovery.Failed(key)
	AssertEqual(IniRead("settings\nm_config.ini", "Collect", key), 123, "Failed visit preserves cooldown")
	Assert(!nm_CollectionRecovery.Begin(key), "Failure backs off even after long travel")
	TestNow += 300
	Assert(nm_CollectionRecovery.Begin(key), "Second visit eligible at retry boundary")
	nm_CollectionRecovery.Failed(key)
	AssertEqual(IniRead("settings\nm_config.ini", "Collect", key), 123, "Second failure still preserves cooldown")
	TestNow += 300
	Assert(nm_CollectionRecovery.Begin(key), "Later interaction eligible")
	AssertEqual(nm_CollectionRecovery.Interacted(key), TestNow, "Interaction returns persisted timestamp")
	AssertEqual(IniRead("settings\nm_config.ini", "Collect", key), TestNow, "Only interaction updates cooldown")
	values := nm_CollectionRecovery.Read(key)
	AssertEqual(values[2], 0, "Interaction clears recovery delay")
	AssertEqual(values[3], TestNow, "Last interaction recorded separately from attempts")
	TestNow += 4000
	Assert(nm_CollectionRecovery.Begin(key), "New visit reserves delay")
	Assert(!nm_CollectionRecovery.Begin(key), "Persisted reservation survives abandoned call")
	AssertEqual(nm_CollectionRecovery.Read(key)[3], values[3], "New attempt preserves interaction history")
	TestNow -= 3600
	Assert(nm_CollectionRecovery.Begin(key), "Backward wall clock cannot strand recovery forever")
	IniWrite "bad|data|here", "settings\nm_config.ini", "CollectionRecovery", key
	Assert(nm_CollectionRecovery.Begin(key), "Malformed recovery metadata recovers")
}

TestDispenserFailures() {
	global TestNow := 1000000, TestCollectionMode := true, TestCollectionReads := 0, TestCollectionThrow := false
	global HoneyDisCheck := 1, TreatDisCheck := 1, BlueberryDisCheck := 1, StrawberryDisCheck := 1, CoconutDisCheck := 1
	global LastHoneyDis := 123, LastTreatDis := 123, LastBlueberryDis := 123, LastStrawberryDis := 123, LastCoconutDis := 123
	global CoconutBoosterCheck := 0, BoostChaserCheck := 0
	try {
		for entry in [[nm_HoneyDis, "HoneyDis"], [nm_TreatDis, "TreatDis"], [nm_BlueberryDis, "BlueberryDis"], [nm_StrawberryDis, "StrawberryDis"], [nm_CoconutDis, "CoconutDis"]] {
			key := "Last" entry[2]
			IniWrite 123, "settings\nm_config.ini", "Collect", key
			before := TestCollectionReads
			entry[1].Call()
			AssertEqual(TestCollectionReads - before, 2, "Actual dispenser retries twice: " key)
			AssertEqual(IniRead("settings\nm_config.ini", "Collect", key), 123, "Actual failure preserves persisted cooldown: " key)
			entry[1].Call()
			AssertEqual(TestCollectionReads - before, 2, "Immediate scheduler revisit performs no search: " key)
			TestNow += 300
			entry[1].Call()
			AssertEqual(TestCollectionReads - before, 4, "Actual failure retries after five minutes: " key)
		}
		AssertEqual(LastHoneyDis + LastTreatDis + LastBlueberryDis + LastStrawberryDis + LastCoconutDis, 615, "All in-memory cooldowns preserved")
		TestNow += 300, TestCollectionThrow := true
		try nm_HoneyDis()
		catch as observationError
			AssertEqual(observationError.Message, "Interrupted collection observation", "Expected observation interruption")
		Assert(!nm_CollectionRecovery.Begin("LastHoneyDis"), "Actual interrupted route retains reservation")
		TestCollectionThrow := false
		TestNow += 300, CoconutBoosterCheck := BoostChaserCheck := 1
		before := TestCollectionReads
		oldCoconutAttempt := nm_CollectionRecovery.Read("LastCoconutDis")[1]
		oldHoneyAttempt := nm_CollectionRecovery.Read("LastHoneyDis")[1]
		nm_CoconutDis()
		HoneyDisCheck := 0
		nm_HoneyDis()
		AssertEqual(TestCollectionReads, before, "Disabled and boost-chaser exclusions preserved")
		AssertEqual(nm_CollectionRecovery.Read("LastCoconutDis")[1], oldCoconutAttempt, "Excluded coconut route reserves no attempt")
		AssertEqual(nm_CollectionRecovery.Read("LastHoneyDis")[1], oldHoneyAttempt, "Disabled route reserves no attempt")
	} finally {
		TestCollectionMode := false, TestCollectionThrow := false
	}
}

TestCollectionInterrupts() {
	global TestNow := 2000000, beesmasActive := 1, BeesmasGatherInterruptCheck := 1, MemoryMatchInterruptCheck := 1
	global StockingsCheck := 1, NormalMemoryMatchCheck := 1
	Assert(nm_BeesmasInterrupt(), "Eligible seasonal collection interrupts gathering")
	Assert(nm_MemoryMatchInterrupt(), "Eligible Memory Match interrupts gathering")
	Assert(nm_CollectionRecovery.Begin("LastStockings"), "Reserve stockings visit")
	Assert(nm_CollectionRecovery.Begin("LastNormalMemoryMatch"), "Reserve Memory Match visit")
	nm_CollectionRecovery.Failed("LastStockings")
	nm_CollectionRecovery.Failed("LastNormalMemoryMatch")
	Assert(!nm_BeesmasInterrupt(), "Failed seasonal visit permits gathering during backoff")
	Assert(!nm_MemoryMatchInterrupt(), "Failed Memory Match permits gathering during backoff")
	TestNow += 299
	Assert(!nm_BeesmasInterrupt() && !nm_MemoryMatchInterrupt(), "No early interruption")
	TestNow += 1
	Assert(nm_BeesmasInterrupt() && nm_MemoryMatchInterrupt(), "Interrupts resume at retry boundary")
	beesmasActive := MemoryMatchInterruptCheck := 0
	Assert(!nm_BeesmasInterrupt() && !nm_MemoryMatchInterrupt(), "Feature gates remain authoritative")
}
