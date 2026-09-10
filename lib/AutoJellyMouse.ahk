; Window-message callbacks only update state. Hover/close tracking uses short ticks.
class nm_AutoJellyMouse {
	__New(gui, changed, bees) {
		this.Gui := gui, this.Changed := changed, this.Bees := bees
		this.Hover := "", this.Since := this.Pressed := this.CloseDeadline := 0
		this.Tip := this.Closed := false
		this.TickFn := ObjBindMethod(this, "Tick")
	}
	Owns(hwnd) => !this.Closed && hwnd && (hwnd = this.Gui.Hwnd || DllCall("IsChild", "Ptr", this.Gui.Hwnd, "Ptr", hwnd))
	Control(hwnd) {
		if this.Closed || !this.Owns(hwnd) || !WinActive("ahk_id " this.Gui.Hwnd) || !DllCall("IsWindowVisible", "Ptr", this.Gui.Hwnd)
			return 0
		MouseGetPos ,, &window, &control, 2
		if window != this.Gui.Hwnd || !control
			return 0
		try candidate := GuiCtrlFromHwnd(control)
		catch
			return 0
		return candidate && candidate.Gui.Hwnd = this.Gui.Hwnd ? candidate : 0
	}
	Move(hwnd) {
		if this.Closed
			return
		control := this.Control(hwnd)
		name := control && control.Name != "move" && control.Name != "close" ? control.Name : ""
		if name = this.Hover
			return
		this.Hover := name, this.Since := DllCall("GetTickCount64", "UInt64"), this.Tip := false
		ToolTip()
		this.Changed.Call(name)
		SetTimer this.TickFn, name || this.Pressed ? 50 : 0
	}
	Cursor(hwnd, hitTest) {
		if (hitTest & 0xffff) != 1
			return
		control := this.Control(hwnd)
		if !control || control.Name = "move" || control.Name = "close"
			return
		static hand := DllCall("LoadCursorW", "Ptr", 0, "Ptr", 32649, "Ptr")
		if hand {
			DllCall("SetCursor", "Ptr", hand)
			return 1
		}
	}
	BeginClose(hwnd) {
		control := this.Control(hwnd)
		if !control || control.Name != "close" || this.Pressed || DllCall("GetCapture", "Ptr")
			return
		DllCall("SetCapture", "Ptr", this.Gui.Hwnd)
		if DllCall("GetCapture", "Ptr") != this.Gui.Hwnd
			return
		this.Pressed := control.Hwnd, this.CloseDeadline := DllCall("GetTickCount64", "UInt64") + 5000
		SetTimer this.TickFn, 50
	}
	EndClose(hwnd) {
		if !this.Pressed
			return
		control := this.Control(hwnd)
		accept := control && control.Hwnd = this.Pressed && DllCall("GetCapture", "Ptr") = this.Gui.Hwnd
			&& DllCall("GetTickCount64", "UInt64") < this.CloseDeadline && !GetKeyState("Escape", "P")
		this.Release()
		if accept
			PostMessage 0x112, 0xF060, 0,, "ahk_id " this.Gui.Hwnd
	}
	Release() {
		owned := this.Pressed, this.Pressed := this.CloseDeadline := 0
		if owned && DllCall("GetCapture", "Ptr") = this.Gui.Hwnd
			DllCall("ReleaseCapture")
	}
	CaptureChanged(hwnd) {
		if !this.Closed && hwnd = this.Gui.Hwnd && DllCall("GetCapture", "Ptr") != hwnd
			this.Pressed := this.CloseDeadline := 0
	}
	Tick() {
		if this.Closed
			return
		if this.Pressed && (DllCall("GetTickCount64", "UInt64") >= this.CloseDeadline
			|| DllCall("GetCapture", "Ptr") != this.Gui.Hwnd || !WinActive("ahk_id " this.Gui.Hwnd) || GetKeyState("Escape", "P"))
			this.Release()
		this.Move(this.Gui.Hwnd)
		if this.Hover && !this.Tip && DllCall("GetTickCount64", "UInt64") - this.Since >= 2400 {
			for bee in this.Bees
				if bee = this.Hover {
					ToolTip(bee " Bee"), this.Tip := true
					break
				}
		}
		if !this.Hover && !this.Pressed
			SetTimer this.TickFn, 0
	}
	Stop(draw := true) {
		if this.Closed
			return
		SetTimer this.TickFn, 0
		this.Release()
		ToolTip()
		changed := this.Hover != "", this.Hover := "", this.Tip := false
		if changed && draw
			this.Changed.Call("")
	}
	Close() {
		if this.Closed
			return
		this.Stop(false), this.Closed := true, this.TickFn := 0
	}
}
