; These are interaction outcomes, not harvest receipts. In particular,
; accepted/no_dialog do not establish that nectar or loot was received.
class nm_PlanterDialog {
	static Run(surface, fullOnly, timeout := 8000) {
		started := surface.Clock(), chosen := "", promptAbsent := false
		before := surface.Observe()
		if !before.valid || before.blocked || !before.e || before.yes || before.no || !surface.Press(before)
			return "unconfirmed"
		Loop {
			if surface.Clock() - started >= timeout
				return !chosen && promptAbsent ? "no_dialog" : "unconfirmed"
			frame := surface.Observe()
			if !frame.valid || frame.blocked
				return "unconfirmed"
			if surface.Clock() - started >= timeout
				return "unconfirmed"
			if frame.yes && frame.no {
				if !chosen {
					chosen := fullOnly ? "no" : "yes"
					if !surface.Click(frame, chosen)
						return "unconfirmed"
				}
			} else if frame.yes || frame.no {
				; A partially recognized dialog is not a missing dialog.
				return "unconfirmed"
			} else if chosen
				return chosen = "no" ? "declined" : "accepted"
			else
				promptAbsent := !frame.e
			surface.Wait(100)
		}
	}
}

class nm_PlanterDialogSurface {
	static HeldKey := ""
	static Registered := false
	__New(key, hwnd := 0) {
		this.Key := key, this.Hwnd := hwnd ? hwnd : GetRobloxHWND()
		if !nm_PlanterDialogSurface.Registered {
			OnExit(ObjBindMethod(nm_PlanterDialogSurface, "Release"), -1)
			nm_PlanterDialogSurface.Registered := true
		}
	}
	static Release(*) {
		local key := this.HeldKey
		this.HeldKey := ""
		if key
			SendEvent "{" key " up}"
	}
	Clock() => DllCall("GetTickCount64", "UInt64")
	Wait(ms) => Sleep(ms)
	Current(frame, fresh := true) => frame.valid && (!fresh || this.Clock() - frame.tick <= 250) && nm_WindowOwnsFocus(this.Hwnd)
		&& nm_SameClient(frame.snapshot, nm_ClientSnapshot(this.Hwnd))
	Observe() {
		global bitmaps
		local offsetFailed
		if !this.Hwnd || !nm_WindowOwnsFocus(this.Hwnd) || !(snapshot := nm_ClientSnapshot(this.Hwnd))
			return {valid: false}
		if !this.HasOwnProp("Offset") {
			offset := GetYOffset(this.Hwnd, &offsetFailed, false)
			if offsetFailed
				return {valid: false}
			this.Offset := offset
			this.AnchorSnapshot := snapshot
		}
		offset := this.Offset
		if !nm_SameClient(this.AnchorSnapshot, snapshot) || !nm_WindowOwnsFocus(this.Hwnd)
			|| snapshot.width < 500 || snapshot.height < 400 || !nm_SameClient(snapshot, nm_ClientSnapshot(this.Hwnd))
			return {valid: false}
		tick := this.Clock(), capture := Gdip_BitmapFromScreen(snapshot.x "|" snapshot.y "|" snapshot.width "|" snapshot.height)
		if capture <= 0
			return {valid: false}
		try {
			Find(key, x1, y1, x2, y2) {
				if x1 < 0 || y1 < 0 || x2 > snapshot.width || y2 > snapshot.height || x1 >= x2 || y1 >= y2
					throw Error("Planter dialog region is outside the client")
				result := Gdip_ImageSearch(capture, bitmaps[key], &pos, x1, y1, x2, y2, 2)
				if result != 0 && result != 1
					throw Error("Planter dialog observation failed")
				if !result
					return 0
				xy := StrSplit(pos, ",")
				return {x: Integer(xy[1]) + Gdip_GetImageWidth(bitmaps[key]) // 2,
					y: Integer(xy[2]) + Gdip_GetImageHeight(bitmaps[key]) // 2}
			}
			frame := {valid: true, tick: tick, snapshot: snapshot,
				e: !!Find("e_button", snapshot.width // 2 - 200, offset + 36, snapshot.width // 2, offset + 156),
				yes: Find("yes", snapshot.width // 2 - 250, snapshot.height // 2 - 52, snapshot.width // 2 + 250, snapshot.height // 2 + 98),
				no: Find("no", snapshot.width // 2 - 250, snapshot.height // 2 - 52, snapshot.width // 2 + 250, snapshot.height // 2 + 98),
				blocked: !!Find("disconnected", 0, 0, snapshot.width, snapshot.height) || !!Find("emptyhealth", 0, 0, snapshot.width, 50)}
			frame.valid := this.Current(frame)
			return frame
		} finally Gdip_DisposeImage(capture)
	}
	Press(frame) {
		previousCritical := A_IsCritical, owns := false
		Critical "On"
		try {
			if nm_PlanterDialogSurface.HeldKey || !this.Current(frame) || GetKeyState(this.Key, "P")
				return false
			nm_PlanterDialogSurface.HeldKey := this.Key, owns := true
			SendEvent "{" this.Key " down}"
			Critical previousCritical
			Sleep 100
			return this.Current(frame, false)
		} finally {
			if owns
				nm_PlanterDialogSurface.Release()
			Critical previousCritical
		}
	}
	Click(frame, choice) {
		previousCritical := A_IsCritical, previousMode := A_CoordModeMouse
		Critical "On"
		try {
			point := frame.%choice%
			if !this.Current(frame) || !point || point.x < 0 || point.y < 0 || point.x >= frame.snapshot.width || point.y >= frame.snapshot.height
				return false
			CoordMode "Mouse", "Screen"
			MouseMove frame.snapshot.x + point.x, frame.snapshot.y + point.y, 0
			if !this.Current(frame)
				return false
			Click
			return this.Current(frame, false)
		} finally {
			CoordMode "Mouse", previousMode
			Critical previousCritical
		}
	}
}
