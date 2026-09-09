#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "%A_ScriptDir%\..\lib\RuntimePolicy.ahk"
#Include "%A_ScriptDir%\..\lib\FailureLog.ahk"
#Include "%A_ScriptDir%\..\lib\Gdip_All.ahk"
#Include "%A_ScriptDir%\..\lib\Gdip_ImageSearch.ahk"
#Include "%A_ScriptDir%\..\lib\AutoFieldBoost.ahk"

; No Roblox, network, real GUI, or keyboard input is used by these tests.
; AFB's observation/travel functions below throw if unexpectedly reached.
TestNow := 10000
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
		TestCancellation, TestHourCap, TestDisabledAFB, TestPermissions, TestWaitUnits, TestFailureLogging, TestUpdateAssets] {
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
GetRobloxHWND() => UnexpectedObservation()
GetRobloxClientPos(*) => UnexpectedObservation()
GetYOffset(*) => UnexpectedObservation()
ActivateRoblox() => UnexpectedObservation()
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
