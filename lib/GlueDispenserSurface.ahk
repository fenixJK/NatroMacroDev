class nm_GlueDispenserSurface {
	__New() => this.Cancellation := nm_InventoryPointer.Cancellation
	Current() => this.Cancellation = nm_InventoryPointer.Cancellation && this.Hwnd
		&& this.Hwnd = GetRobloxHWND() && nm_WindowOwnsFocus(this.Hwnd)
	Reset() {
		if this.Cancellation != nm_InventoryPointer.Cancellation
			return false
		nm_updateAction("Collect")
		nm_Reset()
		this.Hwnd := GetRobloxHWND()
		return this.Current()
	}
	Menu(tab) => this.Current() && nm_OpenMenu(tab) && this.Current()
	Travel(attempt) {
		global HiveConfirmed, paths
		if !this.Current()
			return false
		nm_setStatus("Traveling", "Glue Dispenser" (attempt > 1 ? " (Attempt 2)" : ""))
		try {
			HiveConfirmed := 0
			nm_setShiftLock(0)
			if !this.Current() || !nm_createPath(paths["gtc"]["gluedis"]) || !KeyWait("F14", "D T5 L")
				return false
			return KeyWait("F14", "T120 L") && this.Current()
		} finally this.StopWalk()
	}
	Find() => this.Current() ? nm_InventorySearch("gumdrops") : 0
	Use(item) => this.Current() && nm_DragInventoryItem(item, item.Context.snapshot.width // 2, item.Context.snapshot.height // 2)
	Approach() {
		global FwdKey
		Sleep 500
		if !this.Current()
			return false
		try {
			if !nm_createWalk(nm_Walk(6, FwdKey)) || !KeyWait("F14", "D T5 L")
				return false
			return KeyWait("F14", "T20 L") && this.Current()
		} finally this.StopWalk()
	}
	Interact() {
		global SC_E
		Sleep 500
		if !this.Current()
			return false
		; Reuse the guarded prompt/key surface; do not accept an E prompt over a dialog.
		prompt := nm_PlanterDialogSurface(SC_E, this.Hwnd), frame := prompt.Observe()
		if !frame.valid || frame.blocked || !frame.e || frame.yes || frame.no || !this.Current()
			return false
		if !prompt.Press(frame) || !this.Current()
			return false
		Sleep 1000
		return this.Current()
	}
	StopWalk() => nm_endWalk()
}
