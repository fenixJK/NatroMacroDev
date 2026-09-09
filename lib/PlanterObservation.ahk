; Reads the existing green/remaining-bar signature from a supplied bitmap.
; Zero means unknown, not harvested, absent, or zero-percent growth.
class nm_PlanterProgressReader {
	static Needles := []

	static Release() {
		for bitmap in this.Needles
			Gdip_DisposeImage(bitmap)
		this.Needles := []
	}

	static Read(screen) {
		if !screen
			return 0
		if !this.Needles.Length {
			try {
				for spec in [[8, 0xff86d570], [2, 0xff86d570], [8, 0xff567848]] {
					bitmap := Gdip_CreateBitmap(1, spec[1])
					if !bitmap
						throw Error("Could not allocate planter detection bitmap")
					this.Needles.Push(bitmap)
					graphics := Gdip_GraphicsFromImage(bitmap)
					if !graphics
						throw Error("Could not initialize planter detection graphics")
					try result := Gdip_GraphicsClear(graphics, spec[2])
					finally Gdip_DeleteGraphics(graphics)
					if result != 0
						throw Error("Could not initialize planter detection colors")
				}
			} catch {
				this.Release()
				throw
			}
		}
		if Gdip_ImageSearch(screen, this.Needles[1], &start, , , , , , , 5) != 1
			return 0
		xy := StrSplit(start, ","), x := Integer(xy[1]), y := Integer(xy[2])
		if Gdip_ImageSearch(screen, this.Needles[2], &finish, x, y, , y+2, , , 8) != 1
			return 0
		if Gdip_ImageSearch(screen, this.Needles[3], &remaining, x, y, , y+8, , , 8) != 1
			return 0
		endX := Integer(StrSplit(finish, ",")[1]) + 1
		widthX := Integer(StrSplit(remaining, ",")[1]) + 1
		return (x < endX && endX < widthX) ? (endX-x)/(widthX-x) : 0
	}
}
