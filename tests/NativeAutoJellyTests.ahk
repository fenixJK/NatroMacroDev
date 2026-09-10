TestNativeAutoJellySafety() {
	panel := Gui("-DPIScale", "Auto-Jelly input fixture"), other := Gui("-DPIScale", "Auto-Jelly focus fixture")
	cancelled := false, clicks := 0, token := Gdip_Startup(), bitmap := 0
	try {
		button := panel.AddButton("x380 y490 w80 h40", "Roll fixture")
		button.OnEvent("Click", (*) => clicks++)
		panel.Show("x20 y30 w800 h700"), other.Show("NA x850 y50 w100 h100")
		Require(ActivateRoblox(panel.Hwnd), "Auto-Jelly fixture owns focus")
		surface := nm_AutoJellySurface(panel.Hwnd, 0, (*) => cancelled)
		beforeMode := A_CoordModeMouse
		surface.Click()
		Sleep 50
		Require(clicks = 1 && !GetKeyState("LButton") && A_CoordModeMouse = beforeMode, "One native roll click releases input and restores coordinate mode")
		bitmap := surface.Capture("bee")
		Require(Gdip_GetImageWidth(bitmap) = 320 && Gdip_GetImageHeight(bitmap) = 140, "Bee capture is bounded to expected client region")
		Gdip_DisposeImage(bitmap), bitmap := 0
		bitmap := surface.Capture("mutation")
		Require(Gdip_GetImageWidth(bitmap) = 210 && Gdip_GetImageHeight(bitmap) = 90, "Mutation capture is bounded to expected client region")
		Gdip_DisposeImage(bitmap), bitmap := 0
		cancelled := true
		AutoJellyNativeFailure(ObjBindMethod(surface, "Click"))
		cancelled := false
		ActivateRoblox(other.Hwnd)
		AutoJellyNativeFailure(ObjBindMethod(surface, "Click"))
		AutoJellyNativeFailure(ObjBindMethod(surface, "Capture", "bee"))
		ActivateRoblox(panel.Hwnd)
		panel.Move(80, 90)
		AutoJellyNativeFailure(ObjBindMethod(surface, "Click"))
		Require(clicks = 1 && !GetKeyState("LButton"), "Cancelled, unfocused and moved clients receive no additional click")
		surface := nm_AutoJellySurface(panel.Hwnd, 1000, (*) => false)
		AutoJellyNativeFailure(ObjBindMethod(surface, "Click"))
		surface := nm_AutoJellySurface(panel.Hwnd, 0, (*) => cancelled)
		CancelWait() => (cancelled := true)
		SetTimer CancelWait, -25
		AutoJellyNativeFailure(ObjBindMethod(surface, "Wait", 800))
		Require(cancelled && clicks = 1, "Cancellation interrupts wait before any subsequent action")
		AutoJellyNativeFailure((*) => nm_AutoJellyObservation.Match(Gdip_ImageSearch(0, 0)))
		cancelled := false, tick := 1000, budget := nm_AutoJellyRunBudget(1, 1, (*) => tick)
		surface := nm_AutoJellySurface(panel.Hwnd, 0, (*) => cancelled,, budget)
		surface.Click()
		Sleep 50
		Require(clicks = 2 && budget.Used = 1, "Native click consumes one reserved attempt")
		AutoJellyNativeFailure(ObjBindMethod(surface, "Click"))
		Require(clicks = 2 && !GetKeyState("LButton"), "Exhausted click budget blocks extra native input")
		bitmap := surface.Capture("bee")
		Require(bitmap > 0, "Final allowed click still permits result observation")
		Gdip_DisposeImage(bitmap), bitmap := 0
		tick := 61000
		AutoJellyNativeFailure(ObjBindMethod(surface, "Capture", "bee"))
		AutoJellyNativeFailure(ObjBindMethod(surface, "Wait", 800))
		Require(clicks = 2 && !GetKeyState("LButton"), "Expired time budget stops capture/wait without another click")
	} finally {
		nm_AutoJellySurface.Release()
		if bitmap
			Gdip_DisposeImage(bitmap)
		Gdip_Shutdown(token)
		panel.Destroy(), other.Destroy()
	}
	FileAppend "PASS Windows Auto-Jelly input, capture and cancellation guards (" A_PtrSize * 8 "-bit)`n", "*"
}
AutoJellyNativeFailure(action) {
	try action.Call()
	catch Error
		return
	throw Error("Expected native Auto-Jelly guard to reject operation")
}
