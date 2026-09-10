; Present=1, readable absence=0, unknown=-1. Never activate during observation.
class nm_HiveObservation {
	__New(hwnd := 0) {
		this.Hwnd := hwnd ? hwnd : GetRobloxHWND(), this.Anchor := 0
	}
	Identity() => this.Hwnd && this.Hwnd = GetRobloxHWND()
	Offset() {
		value := GetYOffset(this.Hwnd, &hiveOffsetFailed, false)
		return {valid: !hiveOffsetFailed, value: value}
	}
	Current(snapshot) => this.Identity() && nm_WindowOwnsFocus(this.Hwnd)
		&& nm_SameClient(snapshot, nm_ClientSnapshot(this.Hwnd))
		&& (!this.Anchor || nm_SameClient(this.Anchor, snapshot))
	Read(kind := "prompt") {
		global bitmaps
		if !this.Identity() || !(snapshot := nm_ClientSnapshot(this.Hwnd)) || !this.Current(snapshot)
			return -1
		this.Anchor := snapshot, tick := DllCall("GetTickCount64", "UInt64")
		if kind = "prompt" {
			offset := this.Offset()
			if !offset.valid || !bitmaps.Has("colhey") || bitmaps["colhey"] <= 0
				return -1
			x := snapshot.width // 2 - 150, y := offset.value + 40, width := 350, height := 60
		} else if kind = "alignment" {
			if !bitmaps.Has("hive") || !bitmaps["hive"].Count
				return -1
			x := 0, y := 3 * snapshot.height // 4, width := snapshot.width, height := snapshot.height // 4
		} else
			return -1
		if x < 0 || y < 0 || width <= 0 || height <= 0 || x + width > snapshot.width || y + height > snapshot.height || !this.Current(snapshot)
			return -1
		capture := Gdip_BitmapFromScreen(snapshot.x + x "|" snapshot.y + y "|" width "|" height)
		if capture <= 0
			return -1
		try {
			if kind = "prompt"
				result := Gdip_ImageSearch(capture, bitmaps["colhey"],,,,,, 5)
			else {
				result := 0, threshold := Max(1, snapshot.width ** 2 // 3200)
				for key, needle in bitmaps["hive"] {
					if needle <= 0
						return -1
					count := Gdip_ImageSearch(capture, needle,,,,,, 4,,, threshold)
					if count < 0
						return -1
					if count >= threshold {
						result := 1
						break
					}
				}
			}
			if (result != 0 && result != 1) || DllCall("GetTickCount64", "UInt64") - tick > 250 || !this.Current(snapshot)
				return -1
			nm_PublishClientSnapshot(snapshot)
			return result
		} finally Gdip_DisposeImage(capture)
	}
}
