#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "%A_ScriptDir%\..\lib\Gdip_All.ahk"
#Include "%A_ScriptDir%\..\lib\Gdip_ImageSearch.ahk"
#Include "%A_ScriptDir%\..\lib\Roblox.ahk"
#Include "%A_ScriptDir%\..\lib\nm_OpenMenu.ahk"
#Include "%A_ScriptDir%\..\lib\nm_InventorySearch.ahk"

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
	TestNativePointer(fixture)
	fixture.Minimize()
	Require(!nm_ClientSnapshot(fixture.Hwnd), "Minimized client is unusable")
	Require(ActivateRoblox(fixture.Hwnd), "Explicit activation restores minimized target")
	fixture.Hide()
	Require(!nm_ClientSnapshot(fixture.Hwnd), "Hidden client is unusable")
	Require(!GetRobloxClientPos(0) && !windowX && !windowY && !windowWidth && !windowHeight, "Missing HWND clears geometry rather than using last-found window")
	Require(GetYOffset(0, &offsetFailed) = 0 && offsetFailed = 1, "Missing HWND never reports successful zero offset")
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

class FixturePointerSurface {
	__New(hwnd) => this.Hwnd := hwnd
	Current(snapshot) => nm_WindowOwnsFocus(this.Hwnd) && nm_SameClient(snapshot, nm_ClientSnapshot(this.Hwnd))
}

TestNativePointer(fixture) {
	pointer := nm_InventoryPointer(FixturePointerSurface(fixture.Hwnd))
	snapshot := nm_ClientSnapshot(fixture.Hwnd)
	try {
		Require(pointer.Begin(), "Native pointer obtains lease")
		Require(pointer.Move(snapshot, 30, 30) && pointer.Down(snapshot), "Native fixture receives press")
		Require(GetKeyState("LButton") && !GetKeyState("LButton", "P"), "Mouse hook distinguishes owned synthetic input from physical input")
		Require(pointer.Current(snapshot) && pointer.Move(snapshot, 80, 60), "Owned press permits target movement")
		pointer.Up()
		Require(!GetKeyState("LButton"), "Native release clears held button")
		Require(pointer.Begin() && pointer.Down(snapshot), "Next operation can acquire pointer")
		SetTimer (*) => nm_InventoryPointer.Cancel(), -25
		pointer.Wait(100)
		Require(!pointer.Move(snapshot, 90, 70) && !GetKeyState("LButton"), "Timer cancellation releases input and prevents suspended movement")
		pointer.Up()
		Require(pointer.Begin() && pointer.Down(snapshot), "Pointer can be reused after cancellation")
		fixture.Move(snapshot.x + 100, snapshot.y + 100)
		Require(!pointer.Move(snapshot, 90, 70), "Real geometry change prevents further held-pointer movement")
	} finally {
		pointer.Up()
		nm_InventoryPointer.Cancel()
	}
	Require(!GetKeyState("LButton"), "Native interruption cleanup releases button")
	FileAppend "PASS Windows pointer integration (" A_PtrSize * 8 "-bit)`n", "*"
}
