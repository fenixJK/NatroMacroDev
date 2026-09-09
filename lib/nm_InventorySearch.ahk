#Include "InventorySearchEngine.ahk"
#Include "InventoryDrag.ahk"

; Coordinates remain client-relative for existing callers.
nm_InventorySearch(item, direction := "down", prescroll := 0, prescrolldir := "", scrolltoend := 1, max := 70, &outcome?) {
	engine := nm_InventorySearchEngine(nm_InventorySurface())
	point := engine.Search(item, direction, prescroll, prescrolldir, scrolltoend, max)
	outcome := engine.Outcome
	return point
}

; True means the drag input completed; it is not confirmation of item use.
nm_DragInventoryItem(point, targetX, targetY, destination := 0) {
	surface := nm_InventorySurface()
	return nm_InventoryDrag.Run(surface, nm_InventoryPointer(surface), point, targetX, targetY, destination)
}

class nm_InventoryPointer {
	static Gate := nm_PointerLease()
	__New(surface) {
		static registered := false
		this.Surface := surface, this.Token := 0
		if !registered {
			InstallMouseHook()
			OnExit(nm_InventoryPointer.Cancel, -1)
			registered := true
		}
	}
	Begin() {
		previous := A_IsCritical
		Critical "On"
		try return !GetKeyState("LButton", "P") && (this.Token := nm_InventoryPointer.Gate.Begin())
		finally Critical previous
	}
	Current(snapshot) => nm_InventoryPointer.Gate.Owns(this.Token) && !GetKeyState("LButton", "P") && this.Surface.Current(snapshot)
	Move(snapshot, x, y) {
		previous := A_IsCritical, previousMode := A_CoordModeMouse
		Critical "On"
		try {
			if !this.Current(snapshot) || x < 0 || y < 0 || x >= snapshot.width || y >= snapshot.height
				return false
			CoordMode "Mouse", "Screen"
			MouseMove snapshot.x + x, snapshot.y + y, 0
			return this.Current(snapshot)
		} finally {
			CoordMode "Mouse", previousMode
			Critical previous
		}
	}
	Down(snapshot) {
		previous := A_IsCritical
		Critical "On"
		try return this.Current(snapshot) && nm_InventoryPointer.Gate.Press(this.Token, (*) => SendEvent("{LButton down}"))
		finally Critical previous
	}
	Up() {
		previous := A_IsCritical
		Critical "On"
		try nm_InventoryPointer.Gate.Release(this.Token, (*) => SendEvent("{LButton up}"))
		finally Critical previous
	}
	static Cancel(*) {
		previous := A_IsCritical
		Critical "On"
		try nm_InventoryPointer.Gate.Cancel((*) => SendEvent("{LButton up}"))
		finally Critical previous
	}
	Wait(milliseconds) => Sleep(milliseconds)
}

class nm_InventorySurface {
	__New() => this.Hwnd := GetRobloxHWND()
	Open(item) {
		if !bitmaps.Has(item) || !bitmaps.Has("item") || !ActivateRoblox(this.Hwnd)
			return false
		nm_OpenMenu("itemmenu")
		return true
	}
	Snapshot() {
		if this.Hwnd != GetRobloxHWND() || !nm_WindowOwnsFocus(this.Hwnd)
			return 0
		before := nm_ClientSnapshot(this.Hwnd)
		offset := GetYOffset(this.Hwnd, &failed)
		after := nm_ClientSnapshot(this.Hwnd)
		if failed || !nm_SameClient(before, after)
			return 0
		after.offset := offset
		nm_PublishClientSnapshot(after)
		return after
	}
	Current(snapshot) {
		current := nm_ClientSnapshot(this.Hwnd)
		if this.Hwnd != GetRobloxHWND() || !nm_WindowOwnsFocus(this.Hwnd) || !nm_SameClient(snapshot, current)
			return false
		return nm_PublishClientSnapshot(current)
	}
	Capture(snapshot, height) {
		if height <= 0 || !this.Current(snapshot)
			return 0
		capture := Gdip_BitmapFromScreen(snapshot.x "|" snapshot.y + snapshot.offset + 150 "|306|" height)
		if capture > 0 && !this.Current(snapshot) {
			Gdip_DisposeImage(capture)
			return 0
		}
		return capture
	}
	Bottom(snapshot) {
		capture := this.Capture(snapshot, snapshot.height - snapshot.offset - 150)
		if capture <= 0
			return 0
		try return nm_InventoryFrameReader.Bottom(capture, bitmaps["item"])
		finally Gdip_DisposeImage(capture)
	}
	Observe(snapshot, height, item) {
		capture := this.Capture(snapshot, height)
		if capture <= 0
			return {state: "unknown"}
		try return nm_InventoryFrameReader.Item(capture, bitmaps["item"], bitmaps[item])
		finally Gdip_DisposeImage(capture)
	}
	Scroll(snapshot, direction) {
		if !this.Current(snapshot) || snapshot.offset + 200 >= snapshot.height
			return false
		previousMode := A_CoordModeMouse
		CoordMode "Mouse", "Screen"
		try {
			MouseMove snapshot.x + 30, snapshot.y + snapshot.offset + 200, 0
			if !this.Current(snapshot)
				return false
			SendInput "{Wheel" direction "}"
		} finally CoordMode "Mouse", previousMode
		Sleep 50
		return this.Current(snapshot)
	}
	Wait(milliseconds) => Sleep(milliseconds)
}
