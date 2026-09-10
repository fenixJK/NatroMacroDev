; Shared native ImageSearch boundary. A failed observation throws; only a completed
; search can return the legacy [1, 0, 0] (not found) result.
class nm_ImageObservation {
	static Region(width, height, aim) {
		if width < 1 || height < 1
			return 0
		left := top := 0, right := width, bottom := height
		switch aim {
			case "full":
			case "high": bottom := height // 2
			case "low": top := height // 2
			case "left": right := width // 2
			case "right": left := width // 2
			case "highleft": right := width // 2, bottom := height // 2
			case "highright": left := width // 2, bottom := height // 2
			case "lowright": left := width // 2, top := height // 2
			case "center": left := width // 4, top := height // 4, right := left * 3, bottom := top * 3
			case "actionbar": left := width // 4, top := (height // 4) * 3, right := left * 3
			case "buff": bottom := Min(150, height)
			case "abovebuff": bottom := Min(30, height)
			case "quest": top := 150, right := Min(310, width), bottom := Min(height, Max(560, height - 100))
			case "questbrown": top := 150, right := Min(310, width), bottom := height // 2
			default: throw ValueError("Unknown image search region: " aim)
		}
		return left < right && top < bottom ? {left: left, top: top, right: right - 1, bottom: bottom - 1} : 0
	}

	static Find(fileName, variation, aim := "full", transparent := "none", surface := unset) {
		if !IsInteger(variation) || variation < 0 || variation > 255
			throw ValueError("Image search variation must be between 0 and 255")
		path := A_WorkingDir "\nm_image_assets\" fileName
		attributes := FileExist(path)
		if !attributes || InStr(attributes, "D")
			throw Error("Image search asset is unavailable: " fileName)
		if !IsSet(surface)
			surface := nm_ImageSearchSurface()
		snapshot := surface.Snapshot()
		if !snapshot || !surface.Current(snapshot)
			throw Error("Image search requires a current focused Roblox client")
		region := this.Region(snapshot.width, snapshot.height, aim)
		if !region
			throw Error("Image search region is outside the visible client: " aim)
		spec := "*" variation (transparent != "none" ? " *Trans" transparent : "") " " path
		result := surface.Search(snapshot, region, spec)
		if !surface.Current(snapshot)
			throw Error("Roblox window changed during image search")
		surface.Publish(snapshot)
		if result.found = 0
			return [1, 0, 0]
		if result.found != 1 || result.x < region.left || result.x > region.right
			|| result.y < region.top || result.y > region.bottom
			throw Error("Image search returned invalid coordinates")
		return [0, result.x, result.y]
	}
}

class nm_ImageSearchSurface {
	__New(hwnd := 0) => this.Hwnd := hwnd
	Snapshot() => nm_ClientSnapshot(this.Hwnd ? this.Hwnd : GetRobloxHWND())
	Current(snapshot) => nm_WindowOwnsFocus(snapshot.hwnd) && nm_SameClient(snapshot, nm_ClientSnapshot(snapshot.hwnd))
	Publish(snapshot) => nm_PublishClientSnapshot(snapshot)
	Search(snapshot, region, spec) {
		previousMode := A_CoordModePixel
		CoordMode "Pixel", "Screen"
		try {
			found := ImageSearch(&x, &y, snapshot.x + region.left, snapshot.y + region.top,
				snapshot.x + region.right, snapshot.y + region.bottom, spec)
			return {found: found, x: found ? x - snapshot.x : 0, y: found ? y - snapshot.y : 0}
		} finally CoordMode "Pixel", previousMode
	}
}
