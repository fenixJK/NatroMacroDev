; Same legacy nectar colors/38-pixel scale, read together from one owned frame.
; Missing colors still mean zero; this is not an OCR/occlusion-proof detector.
class nm_NectarObservation {
	static Colors := Map(0x7E9EB3, "Comforting", 0x937DB3, "Motivating", 0xB398A7, "Satisfying", 0x78B375, "Refreshing", 0xB35951, "Invigorating")

	static Read(bitmap) {
		if bitmap <= 0 || Gdip_GetImageWidth(bitmap) != 861 || Gdip_GetImageHeight(bitmap) != 159
			throw Error("Invalid nectar observation frame")
		if Gdip_LockBits(bitmap, 0, 0, 861, 159, &stride, &scan, &data, 1) != 0
			throw Error("Cannot read nectar observation pixels")
		try {
			values := Map(), found := Map()
			for color, name in this.Colors
				values[name] := 0
			Loop 121 {
				y := A_Index - 1
				Loop 861 {
					x := A_Index - 1, color := NumGet(scan + y * stride + x * 4, "UInt") & 0xFFFFFF
					if !this.Colors.Has(color) || found.Has(color)
						continue
					found[color] := true, pixels := 0
					Loop 38 {
						if (NumGet(scan + (y + A_Index - 1) * stride + x * 4, "UInt") & 0xFFFFFF) != color
							break
						pixels++
					}
					values[this.Colors[color]] := Min(100, Round(pixels / 38 * 100, 2))
				}
			}
			return values
		} finally Gdip_UnlockBits(bitmap, &data)
	}
}
