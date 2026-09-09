; Client geometry is a value snapshot, not a set of independently reused globals.
nm_ClientSnapshot(hwnd) {
	if !hwnd || !DllCall("IsWindow", "Ptr", hwnd) || !DllCall("IsWindowVisible", "Ptr", hwnd)
		return 0
	root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
	if DllCall("IsIconic", "Ptr", root ? root : hwnd)
		return 0
	try {
		WinGetClientPos &x, &y, &width, &height, "ahk_id " hwnd
		if width <= 0 || height <= 0
			return 0
		dpi := 96
		try dpi := DllCall("GetDpiForWindow", "Ptr", hwnd, "UInt")
		DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UIntP", &pid := 0)
		return {hwnd: hwnd, root: root, pid: pid, x: x, y: y, width: width, height: height,
			dpi: dpi, monitor: DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr"),
			style: WinGetStyle("ahk_id " hwnd), exstyle: WinGetExStyle("ahk_id " hwnd)}
	}
	return 0
}

nm_SameClient(first, second) {
	if !IsObject(first) || !IsObject(second)
		return false
	for key in ["hwnd", "root", "pid", "x", "y", "width", "height", "dpi", "monitor", "style", "exstyle"]
		if first.%key% != second.%key%
			return false
	return true
}

nm_WindowOwnsFocus(hwnd) {
	if !hwnd
		return false
	root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
	return DllCall("GetForegroundWindow", "Ptr") = (root ? root : hwnd)
}

nm_PublishClientSnapshot(snapshot) {
	global windowX, windowY, windowWidth, windowHeight
	if !IsObject(snapshot)
		return windowX := windowY := windowWidth := windowHeight := 0
	windowX := snapshot.x, windowY := snapshot.y
	windowWidth := snapshot.width, windowHeight := snapshot.height
	return 1
}

class nm_GeometryCache {
	__New(lifetime := 2000) => (this.Lifetime := lifetime, this.Clear())
	Clear() => (this.Snapshot := 0, this.Value := 0, this.Observed := 0)
	Put(snapshot, value, tick) => (this.Snapshot := snapshot.Clone(), this.Value := value, this.Observed := tick)
	Read(snapshot, tick, &value) {
		value := 0
		if !nm_SameClient(snapshot, this.Snapshot) || tick < this.Observed || tick - this.Observed >= this.Lifetime
			return false
		value := this.Value
		return true
	}
}
