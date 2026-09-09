#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "%A_ScriptDir%\..\lib\Gdip_All.ahk"
#Include "%A_ScriptDir%\..\lib\Gdip_ImageSearch.ahk"
#Include "%A_ScriptDir%\..\lib\Roblox.ahk"

bitmaps := Map(), windowX := windowY := windowWidth := windowHeight := 0
fixture := Gui("-DPIScale", "Natro geometry fixture")
try {
	fixture.Show("NA x40 y50 w300 h250")
	first := nm_ClientSnapshot(fixture.Hwnd)
	Require(IsObject(first) && first.width = 300 && first.height = 250, "Read real client dimensions")
	Require(GetRobloxClientPos(fixture.Hwnd) && windowX = first.x && windowY = first.y, "Publish a coherent real client origin")
	fixture.Move(100, 120, 500, 400)
	second := nm_ClientSnapshot(fixture.Hwnd)
	Require(!nm_SameClient(first, second) && second.width > first.width, "Real move/resize invalidates snapshot")
	Require(ActivateRoblox(fixture.Hwnd), "Explicit HWND activation")
	fixture.Minimize()
	Require(!nm_ClientSnapshot(fixture.Hwnd), "Minimized client is unusable")
	Require(ActivateRoblox(fixture.Hwnd), "Explicit activation restores minimized target")
	fixture.Hide()
	Require(!nm_ClientSnapshot(fixture.Hwnd), "Hidden client is unusable")
	Require(!GetRobloxClientPos(0) && !windowX && !windowY && !windowWidth && !windowHeight, "Missing HWND clears geometry rather than using last-found window")
	Require(GetYOffset(0, &failed) = 0 && failed = 1, "Missing HWND never reports successful zero offset")
	FileAppend "PASS Windows geometry integration (" A_PtrSize * 8 "-bit)`n", "*"
} catch as err {
	FileAppend "FAIL Windows geometry integration: " err.Message "`n" err.Stack "`n", "*"
	ExitApp 1
} finally fixture.Destroy()
ExitApp 0

Require(condition, message) {
	if !condition
		throw Error(message)
}
