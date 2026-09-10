TestNativeMenus() {
	global bitmaps
	savedBitmaps := bitmaps, bitmaps := Map(), colors := Map("itemmenu", 0x406080, "questlog", 0x804060,
		"beemenu", 0x608040, "badgelist", 0x2080c0, "settingsmenu", 0xc02080, "shopmenu", 0x80c020)
	token := Gdip_Startup(), panel := Gui("-Caption -DPIScale", "Menu fixture"), foreign := Gui("-DPIScale", "Foreign menu fixture")
	activeTab := "", clicks := 0, respond := true, modeBefore := A_CoordModeMouse
	OnRelease(w, l, message, hwnd) {
		if hwnd != panel.Hwnd || ((l >> 16) & 0xffff) != 120
			return
		for tab, x in nm_MenuNavigation.Tabs {
			if Abs((l & 0xffff) - x) > 2
				continue
			clicks++
			if respond {
				activeTab := activeTab = tab ? "" : tab
				panel.BackColor := activeTab ? Format("{:06X}", colors[activeTab]) : "152637"
				WinRedraw "ahk_id " panel.Hwnd
			}
			break
		}
	}
	try {
		for tab, color in colors {
			bitmap := Gdip_CreateBitmap(3, 3), painter := Gdip_GraphicsFromImage(bitmap)
			try Gdip_GraphicsClear(painter, 0xff000000 | color)
			finally Gdip_DeleteGraphics(painter)
			bitmaps[tab] := bitmap
		}
		panel.BackColor := "152637", panel.Show("x60 y70 w420 h300")
		foreign.Show("NA x550 y70 w100 h100")
		OnMessage(0x202, OnRelease)
		CoordMode "Mouse", "Client"
		for tab in nm_MenuNavigation.Tabs {
			countBefore := clicks
			Require(nm_MenuNavigation(NativeMenuSurface(panel.Hwnd)).Run(tab), "Native menu open verified after click")
			Require(activeTab = tab && clicks = countBefore + 1, "Exactly one native click opens requested tab")
			Require(nm_MenuNavigation(NativeMenuSurface(panel.Hwnd)).Run(tab) && clicks = countBefore + 1, "Already selected tab is not toggled")
			Require(nm_MenuNavigation(NativeMenuSurface(panel.Hwnd)).Run() && activeTab = "" && clicks = countBefore + 2, "Native menu close verified after click")
			Require(A_CoordModeMouse = "Client" && !GetKeyState("LButton") && !nm_InventoryPointer.Gate.Active, "Menu restores coordinate mode and pointer ownership")
		}
		respond := false, countBefore := clicks
		Require(!nm_MenuNavigation(NativeMenuSurface(panel.Hwnd)).Run("itemmenu", 0, 500), "Unresponsive native menu does not claim success")
		Require(clicks = countBefore + 1, "Unresponsive native menu receives only one click")
		for change in ["move", "focus", "cancel", "identity", "stale"] {
			surface := NativeMenuSurface(panel.Hwnd)
			Require(surface.Prepare(surface.Clock() + 5000), "Prepare native menu frame")
			frame := surface.Observe(), countBefore := clicks
			Require(frame.valid, "Owned menu fixture capture is readable")
			switch change {
				case "move": panel.Move(80, 70)
				case "focus": Require(ActivateRoblox(foreign.Hwnd), "Foreign fixture owns focus")
				case "cancel": nm_InventoryPointer.Cancel()
				case "identity": surface.ValidIdentity := false
				case "stale": frame.tick -= 251
			}
			Require(!surface.Click(frame, "itemmenu") && clicks = countBefore, "Changed " change " rejects native input")
			surface.Close(), panel.Move(60, 70)
		}
		FileAppend "PASS Windows menu capture, single clicks, cancellation and window guards (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		OnMessage(0x202, OnRelease, 0)
		nm_InventoryPointer.Cancel()
		CoordMode "Mouse", modeBefore
		panel.Destroy(), foreign.Destroy()
		for tab, bitmap in bitmaps
			Gdip_DisposeImage(bitmap)
		bitmaps := savedBitmaps
		Gdip_Shutdown(token)
	}
}
class NativeMenuSurface extends nm_MenuSurface {
	ValidIdentity := true
	Identity() => this.ValidIdentity && DllCall("IsWindow", "Ptr", this.Hwnd)
	Offset() => {valid: true, value: 0}
}
