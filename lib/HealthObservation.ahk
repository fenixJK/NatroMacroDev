; The legacy combat consumers use an array of observed percentages. Observation
; failures throw, so they cannot be mistaken for a successfully read empty frame.
class nm_HealthBarReader {
	static Needles := []

	static Release() {
		for bitmap in this.Needles
			Gdip_DisposeImage(bitmap)
		this.Needles := []
	}

	static Initialize() {
		if this.Needles.Length = 2
			return
		this.Release()
		try {
			for color in [0xFF1FE744, 0xFF6B131A] {
				bitmap := Gdip_CreateBitmap(1, 4)
				if !bitmap
					throw Error("Could not allocate combat health template")
				this.Needles.Push(bitmap)
				graphics := Gdip_GraphicsFromImage(bitmap)
				if !graphics
					throw Error("Could not create combat health graphics")
				try status := Gdip_GraphicsClear(graphics, color)
				finally Gdip_DeleteGraphics(graphics)
				if status
					throw Error("Could not initialize combat health template")
			}
		} catch {
			this.Release()
			throw
		}
	}

	static Pixel(bitmap, x, y) {
		if DllCall("gdiplus\GdipBitmapGetPixel", "Ptr", bitmap, "Int", x, "Int", y, "UIntP", &color := 0)
			throw Error("Combat health pixel could not be read")
		return color
	}

	static Read(source) {
		if source <= 0
			throw Error("Combat health capture is unavailable")
		Gdip_GetImageDimensions(source, &width, &height)
		if width < 1 || height < 4
			throw Error("Combat health capture has invalid dimensions")
		this.Initialize()
		; Erase matches only from an owned copy, leaving the caller's capture intact.
		bitmap := Gdip_CloneBitmapArea(source, 0, 0, width, height)
		if !bitmap
			throw Error("Combat health capture could not be copied")
		graphics := brush := 0, bars := []
		try {
			graphics := Gdip_GraphicsFromImage(bitmap), brush := Gdip_BrushCreateSolid(0xFF000000)
			if !graphics || !brush
				throw Error("Could not allocate combat health scan resources")
			Loop 101 {
				found := false
				for needle in this.Needles {
					result := Gdip_ImageSearch(bitmap, needle, &position, , , , , , , 1)
					if result != 0 && result != 1
						throw Error("Combat health image search failed: " result)
					if result = 1 {
						found := true
						break
					}
				}
				if !found
					return bars
				if bars.Length >= 100
					throw Error("Combat health capture exceeds the detection limit")
				xy := StrSplit(position, ","), x := Integer(xy[1]), y := Integer(xy[2])
				; Every bar has independent counters and uses the actual image width,
				; including the right-half King Beetle capture and its final pixel.
				green := total := 0
				Loop width - x {
					color := this.Pixel(bitmap, x + A_Index - 1, y)
					if color != 0xFF1FE744 && color != 0xFF6B131A
						break
					green += color = 0xFF1FE744, total++
				}
				barHeight := 0
				Loop height - y {
					color := this.Pixel(bitmap, x, y + A_Index - 1)
					if color != 0xFF1FE744 && color != 0xFF6B131A
						break
					barHeight++
				}
				if !total || barHeight < 4
					throw Error("Combat health anchor could not be measured")
				if Gdip_FillRectangle(graphics, brush, x, y, total, barHeight)
					throw Error("Combat health match could not be masked")
				bars.Push(Round(green / total * 100, 2))
			}
		} finally {
			if brush
				Gdip_DeleteBrush(brush)
			if graphics
				Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
		}
	}
}

nm_HealthDetection(w := 0) {
	hwnd := GetRobloxHWND()
	if !ActivateRoblox(hwnd)
		throw Error("Combat health observation requires the Roblox window")
	return nm_ReadHealthWindow(hwnd, w)
}

; Explicit HWND boundary is also exercised against an owned Windows test GUI.
nm_ReadHealthWindow(hwnd, w := 0) {
	snapshot := nm_ClientSnapshot(hwnd)
	if !snapshot || !nm_WindowOwnsFocus(hwnd)
		throw Error("Combat health window is unavailable")
	left := w = 1 ? snapshot.width // 2 : 0
	capture := Gdip_BitmapFromScreen(snapshot.x + left "|" snapshot.y "|" snapshot.width - left "|" snapshot.height)
	if capture <= 0
		throw Error("Combat health capture failed")
	try {
		bars := nm_HealthBarReader.Read(capture)
		if !nm_WindowOwnsFocus(hwnd) || !nm_SameClient(snapshot, nm_ClientSnapshot(hwnd))
			throw Error("Combat health window changed during observation")
		return bars
	} finally Gdip_DisposeImage(capture)
}
