; Included only by the generated native GUI test worker, never by production.
nm_ProbeBeeAssets() {
	global bitmaps, beeArr
	for bee in beeArr {
		for prefix in ["-", "+"] {
			capture := Gdip_CreateBitmap(320, 140), graphics := 0
			try {
				graphics := Gdip_GraphicsFromImage(capture)
				if !capture || !graphics || Gdip_DrawImage(graphics, bitmaps[prefix bee], 0, 0)
					throw Error("Could not build bee template fixture")
				Gdip_DeleteGraphics(graphics), graphics := 0
				result := nm_AutoJellyObservation.Identify((key) => Gdip_ImageSearch(capture, bitmaps[key]), beeArr)
				if result.bee != bee || result.gifted != (prefix = "+")
					throw Error("Bee template fixture returned wrong identity: " prefix bee)
			} finally {
				if graphics
					Gdip_DeleteGraphics(graphics)
				if capture
					Gdip_DisposeImage(capture)
			}
		}
	}
}
nm_ProbeBeePreflight() {
	global
	local saved := Map(), bee, dismissed := 0, index
	local criticalBefore := A_IsCritical, sendBefore := A_SendLevel
	for bee in beeArr
		saved[bee] := %bee%, %bee% := 0
	saved["SelectAll"] := SelectAll, SelectAll := 0
	DismissDialog() {
		local hwnd, button
		FileAppend "timer`n", "probe-phase.txt"
		for hwnd in WinGetList("ahk_class #32770 ahk_pid " DllCall("GetCurrentProcessId"))
			if WinGetTitle("ahk_id " hwnd) = "Auto-Jelly stopped" {
				FileAppend "dismiss`n", "probe-phase.txt"
				SetTimer DismissDialog, 0
				dismissed++
				if !InStr(WinGetText("ahk_id " hwnd), "Select at least one bee") {
					FileAppend "unexpected dialog: " WinGetText("ahk_id " hwnd) "`n", "probe-phase.txt"
					ExitApp 1
				}
				button := DllCall("GetDlgItem", "Ptr", hwnd, "Int", 1, "Ptr")
				FileAppend "button=" button "`n", "probe-phase.txt"
				DllCall("PostMessageW", "Ptr", button, "UInt", 0xF5, "UPtr", 0, "Ptr", 0)
			}
	}
	Critical "Off"
	try {
		; Positive control: this synthetic Escape can trigger the real hook.
		FileAppend "positive-control`n", "probe-phase.txt"
		SendLevel 1
		stopping := false
		Hotkey "~*esc", stopToggle, "On"
		SendEvent "{Escape}"
		Sleep 100
		if !stopping
			throw Error("Escape hook positive control failed")
		Hotkey "~*esc", stopToggle, "Off"
		FileAppend "positive-passed`n", "probe-phase.txt"
		Loop 2 {
			FileAppend "start " A_Index "`n", "probe-phase.txt"
			SetTimer DismissDialog, 50
			blc_start()
			FileAppend "returned " A_Index "`n", "probe-phase.txt"
			if dismissed != A_Index || !DllCall("IsWindowVisible", "Ptr", mgui.Hwnd)
				throw Error("Rejected Auto-Jelly startup did not restore its GUI or allow retry")
			stopping := false
			SendEvent "{Escape}"
			Sleep 100
			if stopping
				throw Error("Rejected Auto-Jelly startup left its Escape hook enabled")
		}
	} finally {
		SetTimer DismissDialog, 0
		try Hotkey "~*esc", stopToggle, "Off"
		stopping := false
		for bee in saved
			%bee% := saved[bee]
		SendLevel sendBefore
		Critical criticalBefore
	}
}
