; Included only by the generated native GUI test worker, never by production.
nm_ProbePhase(phase) {
	FileAppend DllCall("GetTickCount64", "UInt64") " " phase "`n", "probe-phase.txt"
}
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

nm_ProbeBeeLimits() {
	global mgui, RollClickLimit, RollMinuteLimit
	before := FileRead("settings\mutations.ini"), previous := {Clicks: RollClickLimit, Minutes: RollMinuteLimit}
	criticalBefore := A_IsCritical
	Critical "Off"
	try {
		mgui["limits"].GetPos(&x, &y, &width, &height)
		mgui["roll"].GetPos(, &rollY)
		if x < 0 || y < 345 || width < 400 || y + height > rollY
			throw Error("Limits row overlaps existing controls")
		nm_AutoJellyEditLimits()
		panel := nm_AutoJellyLimitsDialog.Window
		if !panel || DllCall("IsWindowEnabled", "Ptr", mgui.Hwnd)
			throw Error("Limits editor must disable its owner until closed")
		panel["Clicks"].Value := "0"
		if nm_AutoJellyLimitsDialog.Save() || !InStr(panel["Error"].Text, "RollClickLimit")
			throw Error("Limits editor accepted zero clicks or did not explain rejection")
		if FileRead("settings\mutations.ini") != before || RollClickLimit != previous.Clicks
			throw Error("Invalid limit changed stored or displayed settings")
		nm_AutoJellyLimitsDialog.Close()
		if !DllCall("IsWindowEnabled", "Ptr", mgui.Hwnd)
			throw Error("Cancel did not restore the owner window")
		nm_AutoJellyEditLimits()
		panel := nm_AutoJellyLimitsDialog.Window
		panel["Clicks"].Value := "3", panel["Minutes"].Value := "2"
		if !nm_AutoJellyLimitsDialog.Save() || nm_AutoJellyLimitsDialog.Window
			throw Error("Valid limits did not save and close")
		stored := nm_AutoJellySettings.Load()
		if RollClickLimit != 3 || RollMinuteLimit != 2 || stored["RollClickLimit"] != 3 || stored["RollMinuteLimit"] != 2
			throw Error("Saved and displayed run limits differ")
		nm_AutoJellyEditLimits()
		panel := nm_AutoJellyLimitsDialog.Window
		if panel["Clicks"].Value != 3 || panel["Minutes"].Value != 2
			throw Error("Reopened limits editor lost saved values")
		panel["Clicks"].Value := "4"
		nm_AutoJellyLimitsDialog.Close()
		if nm_AutoJellySettings.Load()["RollClickLimit"] != 3
			throw Error("Cancel saved an uncommitted edit")
	} finally {
		nm_AutoJellyLimitsDialog.Close()
		FileDelete "settings\mutations.ini"
		FileAppend before, "settings\mutations.ini", "UTF-8"
		nm_AutoJellySaveLimits(previous)
		Critical criticalBefore
	}
}

nm_ProbeBeeMouse() {
	global mgui, mouseUI, hovercontrol
	criticalBefore := A_IsCritical, foreign := Gui("-DPIScale", "Foreign mouse fixture"), closes := 0
	foreignControl := foreign.AddText("w100 h40", "Foreign")
	MouseGetPos &oldX, &oldY
	OnClose(w, l, message, hwnd) {
		if hwnd = mgui.Hwnd && (w & 0xfff0) = 0xF060 {
			closes++
			return 0
		}
	}
	Place(control) {
		control.GetPos(&x, &y, &width, &height)
		WinGetClientPos &originX, &originY,,, "ahk_id " mgui.Hwnd
		MouseMove originX + x + width//2, originY + y + height//2, 0
	}
	Check(value, message) {
		if !value
			throw Error(message)
	}
	Critical "Off"
	try {
		nm_ProbePhase("mouse focus")
		foreign.Show("x650 y30 w140 h70"), mgui.Move(30, 30)
		WinActivate "ahk_id " mgui.Hwnd
		WinWaitActive "ahk_id " mgui.Hwnd,, 2
		nm_ProbePhase("mouse hover")
		Place(mgui["Bomber"])
		WM_MOUSEMOVE(0, 0, 0x200, mgui.Hwnd)
		Check(mouseUI.Hover = "Bomber" && hovercontrol = "Bomber", "Owned hover is drawn and message returns")
		mouseUI.Since := DllCall("GetTickCount64", "UInt64") - 2401
		mouseUI.Tick()
		Check(mouseUI.Tip, "Bee tooltip appears after hover delay")
		Check(mouseUI.Cursor(mgui.Hwnd, 1) = 1, "Owned client cursor is handled")
		Check(!mouseUI.Cursor(foreign.Hwnd, 1) && !mouseUI.Cursor(mgui.Hwnd, 2), "Foreign and non-client cursors are left to Windows")
		before := FileRead("settings\mutations.ini")
		WM_LBUTTONDOWN(1, 0, 0x201, foreignControl.Hwnd)
		Check(FileRead("settings\mutations.ini") = before, "Foreign message cannot toggle the bee under the pointer")
		Place(mgui["move"]), mouseUI.Tick()
		Check(!mouseUI.Hover && !mouseUI.Tip, "Moving onto title clears highlight and tooltip")
		Place(mgui["Bomber"]), mouseUI.Move(mgui.Hwnd)
		WinActivate "ahk_id " foreign.Hwnd
		WinWaitActive "ahk_id " foreign.Hwnd,, 2
		nm_ProbePhase("mouse foreign focus")
		mouseUI.Tick()
		WM_MOUSEMOVE(0, 0, 0x200, foreignControl.Hwnd)
		Check(!mouseUI.Hover, "Focus loss and foreign messages clear hover without indexing foreign controls")
		WinActivate "ahk_id " mgui.Hwnd
		WinWaitActive "ahk_id " mgui.Hwnd,, 2
		nm_ProbePhase("mouse deferred actions")
		; Prevent the deferred action from running: the message handler must return
		; before it starts OCR/game preflight or opens the help modal.
		Critical "On"
		Place(mgui["roll"]), WM_LBUTTONDOWN(1, 0, 0x201, mgui.Hwnd)
		SetTimer blc_start, 0
		Place(mgui["help"]), WM_LBUTTONDOWN(1, 0, 0x201, mgui.Hwnd)
		SetTimer nm_AutoJellyHelp, 0
		nm_ProbePhase("mouse close capture")
		OnMessage(0x112, OnClose)
		Place(mgui["close"]), mouseUI.BeginClose(mgui.Hwnd)
		Check(mouseUI.Pressed && DllCall("GetCapture", "Ptr") = mgui.Hwnd, "Close press owns capture without waiting")
		Place(mgui["move"]), mouseUI.EndClose(mgui.Hwnd)
		Check(!mouseUI.Pressed && !DllCall("GetCapture", "Ptr"), "Release outside close cancels and releases capture")
		Place(mgui["close"]), mouseUI.BeginClose(mgui.Hwnd)
		mouseUI.CloseDeadline := 0, mouseUI.Tick()
		Check(!mouseUI.Pressed && !DllCall("GetCapture", "Ptr"), "Abandoned close press expires")
		mouseUI.BeginClose(mgui.Hwnd)
		DllCall("SetCapture", "Ptr", foreign.Hwnd)
		mouseUI.CaptureChanged(mgui.Hwnd), mouseUI.Release()
		Check(!mouseUI.Pressed && DllCall("GetCapture", "Ptr") = foreign.Hwnd, "Capture transfer cancels close without releasing the new owner")
		mouseUI.BeginClose(mgui.Hwnd)
		Check(!mouseUI.Pressed && DllCall("GetCapture", "Ptr") = foreign.Hwnd, "Existing capture is never stolen")
		DllCall("ReleaseCapture")
		mouseUI.BeginClose(mgui.Hwnd), mouseUI.EndClose(mgui.Hwnd)
		Critical "Off"
		Sleep 100
		nm_ProbePhase("mouse close delivered")
		Check(closes = 1, "Only release on close posts one command to this GUI")
		mouseUI.Stop(), mouseUI.Stop()
		Check(!mouseUI.Hover && !mouseUI.Pressed && !mouseUI.Tip, "Mouse teardown is idempotent")
	} finally {
		SetTimer blc_start, 0
		SetTimer nm_AutoJellyHelp, 0
		OnMessage(0x112, OnClose, 0)
		mouseUI.Stop()
		if DllCall("GetCapture", "Ptr") = foreign.Hwnd
			DllCall("ReleaseCapture")
		foreign.Destroy()
		MouseMove oldX, oldY, 0
		Critical criticalBefore
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
		local hwnd, button, control
		FileAppend "timer`n", "probe-phase.txt"
		for hwnd in WinGetList("ahk_class #32770 ahk_pid " DllCall("GetCurrentProcessId"))
			if WinGetTitle("ahk_id " hwnd) = "Auto-Jelly stopped" {
				FileAppend "dismiss`n", "probe-phase.txt"
				if !InStr(WinGetText("ahk_id " hwnd), "Select at least one bee") {
					FileAppend "unexpected dialog: " WinGetText("ahk_id " hwnd) "`n", "probe-phase.txt"
					ExitApp 1
				}
				button := 0
				for control in WinGetControlsHwnd("ahk_id " hwnd) {
					FileAppend "control=" WinGetClass("ahk_id " control) ":" ControlGetText(control) "`n", "probe-phase.txt"
					if StrReplace(ControlGetText(control), "&") = "OK"
						button := control
				}
				if !button
					return
				SetTimer DismissDialog, 0
				dismissed++
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
