#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "%A_ScriptDir%\..\lib\Gdip_All.ahk"
#Include "%A_ScriptDir%\..\lib\Gdip_ImageSearch.ahk"
#Include "%A_ScriptDir%\..\lib\Roblox.ahk"
#Include "%A_ScriptDir%\..\lib\nm_OpenMenu.ahk"
#Include "%A_ScriptDir%\..\lib\nm_InventorySearch.ahk"
#Include "%A_ScriptDir%\..\lib\HealthObservation.ahk"
#Include "%A_ScriptDir%\..\lib\ImageObservation.ahk"
#Include "%A_ScriptDir%\..\lib\RemoteCapabilities.ahk"
#Include "%A_ScriptDir%\..\lib\PlanterDialog.ahk"
#Include "%A_ScriptDir%\..\lib\StartupControl.ahk"
#Include "%A_ScriptDir%\StartupWindowsTests.ahk"
#Include "%A_ScriptDir%\..\lib\GuiGraphics.ahk"
#Include "%A_ScriptDir%\..\lib\GuiScripts.ahk"
#Include "%A_ScriptDir%\..\lib\InlineScripts.ahk"
#Include "%A_ScriptDir%\NativeGuiGraphicsTests.ahk"
#Include "%A_ScriptDir%\..\lib\AutoJellySafety.ahk"
#Include "%A_ScriptDir%\..\lib\AutoJellyLimits.ahk"
#Include "%A_ScriptDir%\NativeAutoJellyTests.ahk"
#Include "%A_ScriptDir%\..\lib\AutoJellyOcr.ahk"
#Include "%A_ScriptDir%\NativeAutoJellyOcrTests.ahk"
#Include "%A_ScriptDir%\NativeScreenCaptureTests.ahk"
#Include "%A_ScriptDir%\NativeTextGraphicsTests.ahk"
#Include "%A_ScriptDir%\NativeMenuTests.ahk"
#Include "%A_ScriptDir%\..\lib\ResetRecovery.ahk"
#Include "%A_ScriptDir%\..\lib\HiveObservation.ahk"
#Include "%A_ScriptDir%\NativeHiveTests.ahk"

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
	TestNativePlanterInput()
	Require(ActivateRoblox(fixture.Hwnd), "Restore geometry fixture focus after planter tests")
	TestNativePointer(fixture)
	TestNativeHealth()
	TestNativeRemotePermissions(fixture)
	TestNativeStartupDialogs(fixture)
	TestNativeGuiGraphics()
	TestNativeAutoJellySafety()
	TestNativeAutoJellyOcr()
	TestNativeScreenCapture()
	TestNativeTextGraphics()
	TestNativeMenus()
	TestNativeHiveObservation()
	Require(ActivateRoblox(fixture.Hwnd), "Restore fixture focus after startup settings dialogs")
	fixture.Minimize()
	Require(!nm_ClientSnapshot(fixture.Hwnd), "Minimized client is unusable")
	Require(ActivateRoblox(fixture.Hwnd), "Explicit activation restores minimized target")
	fixture.Hide()
	Require(!nm_ClientSnapshot(fixture.Hwnd), "Hidden client is unusable")
	Require(!GetRobloxClientPos(0) && !windowX && !windowY && !windowWidth && !windowHeight, "Missing HWND clears geometry rather than using last-found window")
	Require(GetYOffset(0, &offsetFailed) = 0 && offsetFailed = 1, "Missing HWND never reports successful zero offset")
	FileAppend "PASS Windows geometry integration (" A_PtrSize * 8 "-bit)`n", "*"
} catch as geometryTestError {
	FileAppend "FAIL Windows geometry integration: " geometryTestError.Message "`n" geometryTestError.Stack "`n", "*"
	ExitApp 1
} finally fixture.Destroy()
ExitApp 0

Require(condition, message) {
	if !condition
		throw Error(message)
}

TestNativeRemotePermissions(fixture) {
	originalDirectory := A_WorkingDir
	fixtureDirectory := A_Temp "\natro-remote-permissions-" DllCall("GetCurrentProcessId")
	DirCreate fixtureDirectory "\settings"
	token := Gdip_Startup(), panel := 0, bitmap := 0
	try {
		SetWorkingDir fixtureDirectory
		nm_RemotePermissionsWindow.Open()
		panel := nm_RemotePermissionsWindow.Window
		Require(WinExist("ahk_id " panel.Hwnd), "Local permission window opens")
		for key in nm_RemoteCapabilities.Flags
			Require(!panel[key].Value, "Optional native checkbox starts disabled: " key)
		panel["DesktopCapture"].Value := 1
		panel["Diagnostics"].Value := 1
		nm_RemotePermissionsWindow.Save(panel), panel := 0
		Require(nm_RemoteCapabilities.Read() = 33 && !nm_RemotePermissionsWindow.Window, "Native save persists only selected permissions and closes")
		nm_RemotePermissionsWindow.Open()
		panel := nm_RemotePermissionsWindow.Window
		Require(panel["DesktopCapture"].Value && panel["Diagnostics"].Value && !panel["DesktopControl"].Value, "Reopening reflects saved permissions")
		panel["DesktopControl"].Value := 1
		nm_RemotePermissionsWindow.Close(panel), panel := 0
		Require(nm_RemoteCapabilities.Read() = 33, "Cancel discards unsaved permissions")
		Require(ActivateRoblox(fixture.Hwnd), "Capture fixture owns focus")
		bitmap := nm_RemoteCapture("Window")
		snapshot := nm_ClientSnapshot(fixture.Hwnd)
		Require(bitmap > 0 && Gdip_GetImageWidth(bitmap) = snapshot.width && Gdip_GetImageHeight(bitmap) = snapshot.height, "Granted active-window screenshot captures exact client dimensions")
		Gdip_DisposeImage(bitmap), bitmap := 0
		Require(!nm_RemoteCapture("invalid"), "Invalid mode cannot fall back to desktop even when granted")
		Require(!GetRobloxHWND() && !nm_RemoteCapture(), "Missing Roblox does not capture active fixture or desktop")
		nm_RemotePermissionsWindow.Open()
		panel := nm_RemotePermissionsWindow.Window
		panel["DesktopCapture"].Value := 0
		nm_RemotePermissionsWindow.Save(panel), panel := 0
		Require(!nm_RemoteCapture("Window") && !nm_RemoteCapture("All") && !nm_RemoteCapture("Screen"), "Local revocation immediately prevents all desktop modes")
		FileAppend "PASS Windows remote permissions integration (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		if bitmap > 0
			Gdip_DisposeImage(bitmap)
		if panel
			nm_RemotePermissionsWindow.Close(panel)
		Gdip_Shutdown(token)
		SetWorkingDir originalDirectory
		DirDelete fixtureDirectory, true
	}
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
		SendEvent "{LButton down}"
		try Require(!pointer.Begin(), "Existing unowned synthetic press cannot be taken over")
		finally SendEvent "{LButton up}"
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

TestNativeHealth() {
	capturedGui := Gui("-DPIScale +AlwaysOnTop", "Natro health observation fixture")
	token := Gdip_Startup()
	try {
		capturedGui.BackColor := "000000"
		for spec in [[10, 25, "1FE744"], [35, 75, "6B131A"], [200, 20, "1FE744"], [220, 20, "6B131A"]]
			capturedGui.AddText("x" spec[1] " y30 w" spec[2] " h8 Background" spec[3], "")
		capturedGui.Show("x60 y60 w301 h120")
		Require(ActivateRoblox(capturedGui.Hwnd), "Health fixture owns focus")
		Sleep 150
		DllCall("dwmapi\DwmFlush")
		bars := nm_ReadHealthWindow(capturedGui.Hwnd)
		Require(bars.Length = 2 && bars[1] = 25 && bars[2] = 50, "Actual client capture finds both painted health bars")
		bars := nm_ReadHealthWindow(capturedGui.Hwnd, 1)
		Require(bars.Length = 1 && bars[1] = 50, "Right-half capture excludes the left health bar")
		TestNativeSharedImage(capturedGui)
		capturedGui.Hide()
		observationFailed := false
		try nm_ReadHealthWindow(capturedGui.Hwnd)
		catch Error
			observationFailed := true
		Require(observationFailed, "Hidden client fails explicitly instead of returning no bars")
		FileAppend "PASS Windows health capture integration (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		capturedGui.Destroy()
		nm_HealthBarReader.Release()
		Gdip_Shutdown(token)
	}
}

TestNativeSharedImage(capturedGui) {
	originalDirectory := A_WorkingDir, originalMode := A_CoordModePixel
	fixtureDirectory := A_Temp "\natro-image-search-" DllCall("GetCurrentProcessId")
	DirCreate fixtureDirectory "\nm_image_assets"
	needle := Gdip_CreateBitmap(3, 3), graphics := Gdip_GraphicsFromImage(needle)
	try {
		Gdip_GraphicsClear(graphics, 0xFF1FE744)
		Require(Gdip_SaveBitmapToFile(needle, fixtureDirectory "\nm_image_assets\native-needle.png") = 0, "Save native image-search template")
		SetWorkingDir fixtureDirectory
		CoordMode "Pixel", "Client"
		surface := nm_ImageSearchSurface(capturedGui.Hwnd)
		result := nm_ImageObservation.Find("native-needle.png", 0, "full", "none", surface)
		Require(result[1] = 0 && result[2] = 10 && result[3] = 30, "Native image result uses client-relative coordinates")
		client := nm_ClientSnapshot(capturedGui.Hwnd)
		Require(windowX = client.x && windowY = client.y && windowWidth = client.width, "Legacy geometry agrees with the verified native result")
		Require(A_CoordModePixel = "Client", "Native search restores caller coordinate mode")
		result := nm_ImageObservation.Find("native-needle.png", 0, "right", "none", surface)
		Require(result[1] = 0 && result[2] = 200 && result[3] = 30, "Native right region excludes the left match")
		Require(nm_ImageObservation.Find("native-needle.png", 0, "low", "none", surface)[1] = 1, "Valid native no-match result")
		FileAppend "invalid image", "nm_image_assets\invalid.png"
		nativeFailed := false
		try nm_ImageObservation.Find("invalid.png", 0, "full", "none", surface)
		catch Error
			nativeFailed := true
		Require(nativeFailed && A_CoordModePixel = "Client", "Actual native decode failure propagates and restores coordinate mode")
		FileAppend "PASS Windows shared image search integration (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		CoordMode "Pixel", originalMode
		SetWorkingDir originalDirectory
		Gdip_DeleteGraphics(graphics), Gdip_DisposeImage(needle)
		DirDelete fixtureDirectory, true
	}
}

TestNativePlanterInput() {
	panel := Gui("-DPIScale", "Planter input fixture"), other := Gui("-DPIScale", "Planter focus fixture"), clicks := 0
	previousDelay := A_KeyDelay, previousDuration := A_KeyDuration
	try {
		button := panel.AddButton("x20 y20 w100 h30", "Fixture")
		button.OnEvent("Click", (*) => clicks++)
		panel.Show("w200 h100"), other.Show("NA x500 y500 w200 h100")
		ActivateRoblox(panel.Hwnd)
		surface := nm_PlanterDialogSurface("F13", panel.Hwnd)
		frame := {valid: true, snapshot: nm_ClientSnapshot(panel.Hwnd), tick: surface.Clock(), yes: {x: 60, y: 35}}
		Require(surface.Click(frame, "yes"), "Native current-frame planter click")
		Sleep 50
		Require(clicks = 1, "Native button received one click")
		frame.tick := surface.Clock() - 500
		Require(!surface.Click(frame, "yes") && clicks = 1, "Stale planter observation cannot click")
		frame.tick := surface.Clock()
		Require(surface.Press(frame) && !GetKeyState("F13"), "Native interaction releases its key")
		SetKeyDelay 250
		frame.tick := surface.Clock()
		Require(surface.Press(frame) && !GetKeyState("F13"), "Configured key delay does not expire an already authorized press")
		SetKeyDelay previousDelay, previousDuration
		frame.tick := surface.Clock()
		SwitchFocus() => ActivateRoblox(other.Hwnd)
		SetTimer SwitchFocus, -25
		Require(!surface.Press(frame), "Focus change during held input is unconfirmed")
		Require(!GetKeyState("F13") && nm_PlanterDialogSurface.HeldKey = "", "Focus loss releases held input")
		Require(!surface.Click(frame, "yes") && clicks = 1, "Lost-focus planter observation cannot click")
		FileAppend "PASS Windows planter input lifecycle (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		SetKeyDelay previousDelay, previousDuration
		nm_PlanterDialogSurface.Release()
		panel.Destroy(), other.Destroy()
	}
}
