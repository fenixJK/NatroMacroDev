#Include "InventoryPointer.ahk"

class nm_MenuNavigation {
	static Tabs := Map("itemmenu", 30, "questlog", 85, "beemenu", 140, "badgelist", 195, "settingsmenu", 250, "shopmenu", 305)
	__New(surface) => this.Surface := surface
	Run(target := "", refresh := 0, timeout := 5000) {
		this.Outcome := "unknown", surface := this.Surface
		if (target != "" && !nm_MenuNavigation.Tabs.Has(target)) || (refresh != 0 && refresh != 1) || timeout <= 0 {
			this.Outcome := "invalid"
			return 0
		}
		; The existing refresh flag requests closing any open tab.
		if refresh
			target := ""
		deadline := surface.Clock() + timeout, clicked := false, previousTab := ""
		try {
			if !surface.Prepare(deadline)
				return 0
			Loop {
				if surface.Clock() >= deadline {
					this.Outcome := "timeout"
					return 0
				}
				frame := surface.Observe()
				if !frame.valid || !surface.Fresh(frame)
					return 0
				if surface.Clock() >= deadline {
					this.Outcome := "timeout"
					return 0
				}
				if frame.tab = target {
					this.Outcome := target ? "opened" : "closed"
					return 1
				}
				if !clicked {
					previousTab := frame.tab, clicked := true
					if !surface.Click(frame, target ? target : frame.tab)
						return 0
				} else if frame.tab != previousTab && frame.tab != ""
					return 0 ; unexpected tab change is not permission to click again
				surface.Wait(Min(100, Max(0, deadline - surface.Clock())))
			}
		} catch {
			this.Outcome := "unknown"
			return 0
		} finally surface.Close()
	}
}

class nm_MenuFrameReader {
	static Read(find) {
		active := ""
		for tab in nm_MenuNavigation.Tabs {
			match := find.Call(tab)
			if match != 0 && match != 1
				return {valid: false}
			if match {
				if active
					return {valid: false}
				active := tab
			}
		}
		return {valid: true, tab: active}
	}
}

class nm_MenuSurface {
	__New(hwnd := 0) {
		this.Hwnd := hwnd ? hwnd : GetRobloxHWND(), this.Anchor := 0, this.Deadline := 0
		this.Cancellation := nm_InventoryPointer.Cancellation
		this.Pointer := nm_InventoryPointer(this)
	}
	Clock() => DllCall("GetTickCount64", "UInt64")
	Wait(ms) => Sleep(ms)
	Identity() => this.Hwnd && this.Hwnd = GetRobloxHWND()
	Offset() {
		value := GetYOffset(this.Hwnd, &failed, false)
		return {valid: !failed, value: value}
	}
	Prepare(deadline) {
		global bitmaps
		this.Deadline := deadline
		for tab in nm_MenuNavigation.Tabs
			if !bitmaps.Has(tab) || bitmaps[tab] <= 0
				return false
		if !this.Identity() || !ActivateRoblox(this.Hwnd) || !(snapshot := nm_ClientSnapshot(this.Hwnd))
			return false
		offset := this.Offset()
		if !offset.valid || !nm_SameClient(snapshot, nm_ClientSnapshot(this.Hwnd))
			return false
		this.Anchor := snapshot, this.YOffset := offset.value
		return snapshot.width > 350 && offset.value + 72 >= 0 && offset.value + 152 <= snapshot.height && this.Current(snapshot)
	}
	Current(snapshot) => this.Cancellation = nm_InventoryPointer.Cancellation && this.Clock() < this.Deadline && this.Identity() && nm_WindowOwnsFocus(this.Hwnd)
		&& nm_SameClient(this.Anchor, snapshot) && nm_SameClient(snapshot, nm_ClientSnapshot(this.Hwnd))
	Fresh(frame) => frame.valid && this.Clock() >= frame.tick && this.Clock() - frame.tick <= 250 && this.Current(frame.snapshot)
	Observe() {
		global bitmaps
		if !this.Current(this.Anchor)
			return {valid: false}
		tick := this.Clock(), snapshot := this.Anchor
		capture := Gdip_BitmapFromScreen(snapshot.x "|" snapshot.y + this.YOffset + 72 "|350|80")
		if capture <= 0
			return {valid: false}
		try {
			frame := nm_MenuFrameReader.Read((tab) => Gdip_ImageSearch(capture, bitmaps[tab],,,,,, 2))
			frame.tick := tick, frame.snapshot := snapshot
			frame.valid := this.Fresh(frame)
			return frame
		} finally Gdip_DisposeImage(capture)
	}
	Click(frame, tab) {
		if !nm_MenuNavigation.Tabs.Has(tab) || !this.Fresh(frame) || !this.Pointer.Begin()
			return false
		try {
			if !this.Pointer.Move(frame.snapshot, nm_MenuNavigation.Tabs[tab], this.YOffset + 120)
				|| !this.Fresh(frame) || !this.Pointer.Down(frame.snapshot)
				return false
		} finally this.Pointer.Up()
		; Park outside the tab so hover colors cannot masquerade as selection.
		if !this.Fresh(frame) || !this.Pointer.Begin()
			return false
		try return this.Pointer.Move(frame.snapshot, 350, this.YOffset + 100) && this.Fresh(frame)
		finally this.Pointer.Up()
	}
	Close() => this.Pointer.Up()
}
