TestNativeHiveObservation() {
	global bitmaps
	savedBitmaps := bitmaps, token := Gdip_Startup(), needle := graphics := 0
	panel := Gui("-Caption -DPIScale", "Hive observation fixture"), foreign := Gui("-DPIScale", "Foreign hive fixture")
	try {
		needle := Gdip_CreateBitmap(3, 3), graphics := Gdip_GraphicsFromImage(needle)
		Gdip_GraphicsClear(graphics, 0xff2468ac)
		bitmaps := Map("colhey", needle, "hive", Map("fixture", needle))
		panel.BackColor := "2468AC", panel.Show("x60 y70 w600 h400")
		foreign.Show("NA x750 y70 w100 h100")
		Require(ActivateRoblox(panel.Hwnd), "Activate owned hive fixture")
		Sleep 50
		observer := NativeHiveObservation(panel.Hwnd)
		Require(observer.Read() = 1, "Native prompt match")
		Require(observer.Read("alignment") = 1, "Native alignment match-count threshold")
		panel.BackColor := "334455"
		Sleep 50
		Require(observer.Read() = 0 && observer.Read("alignment") = 0, "Readable absence differs from error")
		bitmaps["colhey"] := 0
		Require(observer.Read() = -1, "Missing template is unknown")
		bitmaps["colhey"] := needle
		panel.Move(80, 70)
		Require(observer.Read() = -1, "Movement invalidates anchored observation")
		observer := NativeHiveObservation(panel.Hwnd)
		Require(ActivateRoblox(foreign.Hwnd), "Foreign window owns focus")
		Require(observer.Read() = -1, "Lost focus is unknown and not reacquired")
		Require(ActivateRoblox(panel.Hwnd), "Restore owned fixture")
		observer := NativeHiveObservation(panel.Hwnd), observer.OffsetDelay := 300
		Require(observer.Read() = -1, "Late observation cannot establish presence or absence")
		observer := NativeHiveObservation(panel.Hwnd), observer.ValidIdentity := false
		Require(observer.Read() = -1, "Invalidated identity is unknown")
		recovery := nm_ResetRecovery(), snapshot := nm_ClientSnapshot(panel.Hwnd)
		capture := recovery.Capture(snapshot.x "|" snapshot.y "|20|20")
		Require(capture > 0 && recovery.Frames.Count = 1, "Capture registered for abort cleanup")
		try recovery.Run((active) => nm_ResetImageSearch(capture, 0), () => 0)
		catch nm_ResetExhausted {
		}
		Require(recovery.Frames.Count = 0, "Native search failure releases reset captures")
		FileAppend "PASS Windows hive prompt/alignment observation and reset capture cleanup (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		panel.Destroy(), foreign.Destroy()
		if graphics
			Gdip_DeleteGraphics(graphics)
		if needle
			Gdip_DisposeImage(needle)
		bitmaps := savedBitmaps
		Gdip_Shutdown(token)
	}
}

class NativeHiveObservation extends nm_HiveObservation {
	ValidIdentity := true
	OffsetDelay := 0
	Identity() => this.ValidIdentity && DllCall("IsWindow", "Ptr", this.Hwnd)
	Offset() {
		if this.OffsetDelay
			Sleep this.OffsetDelay
		return {valid: true, value: 0}
	}
}
