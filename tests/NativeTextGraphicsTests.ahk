TestNativeTextGraphics() {
	token := Gdip_Startup(), bitmap := graphics := brush := 0
	try {
		bitmap := Gdip_CreateBitmap(240, 100), graphics := Gdip_GraphicsFromImage(bitmap)
		Require(bitmap && graphics, "Native text fixture allocated")
		Gdip_GraphicsClear(graphics, 0xffffffff)
		blank := NativeTextPixels(bitmap)
		bounds := Gdip_TextToGraphics(graphics, "Measure 5", "x10 y10 s24", "Arial", 220, 80, 1)
		Require(StrSplit(bounds, "|").Length = 6, "Measure-only returns native bounds")
		Require(NativeTextPixelsEqual(blank, NativeTextPixels(bitmap)), "Measure-only leaves pixels untouched")
		for color in ["ff204060", "12345678", "00000000"] {
			Gdip_GraphicsClear(graphics, 0xffffffff)
			owned := Gdip_TextToGraphics(graphics, "Text 5", "x10 y10 s24 c" color, "Arial", 220, 80)
			colorPixels := NativeTextPixels(bitmap)
			Gdip_GraphicsClear(graphics, 0xffffffff)
			brush := Gdip_BrushCreateSolid(Integer("0x" color))
			borrowed := Gdip_TextToGraphics(graphics, "Text 5", "x10 y10 s24", "Arial", 220, 80, 0, brush)
			Require(owned = borrowed && NativeTextPixelsEqual(colorPixels, NativeTextPixels(bitmap)), "Explicit brush and ARGB colors render identically")
			Require(NativeTextPixelsEqual(blank, colorPixels) = (color = "00000000"), "Visible colors draw, transparent black does not")
			Require(Gdip_TextToGraphics(0, "Text", "", "Arial",,,, brush) = -2, "Missing graphics rejected without taking borrowed brush")
			Require(Gdip_DeleteBrush(brush) = 0, "Caller still owns supplied brush"), brush := 0
		}
		brush := Gdip_CreateLineBrushFromRect(0, 0, 240, 100, 0xffff0000, 0xff0000ff)
		Require(StrSplit(Gdip_TextToGraphics(graphics, "Gradient", "s24", "Arial", 220, 80, 0, brush), "|").Length = 6, "Borrowed gradient brush supported")
		Require(Gdip_DeleteBrush(brush) = 0, "Gradient brush remains caller-owned"), brush := 0
		Require(Gdip_TextToGraphics(graphics, "Text", "", "NatroMissingFont-725de38a") = -3, "Missing font fails without dependent allocations")
		CreateRectF(&rect, 0, 0, 240, 100)
		Require(Gdip_MeasureString(graphics, "Text", 0, 0, &rect) = 0, "Native measurement failure returns no fabricated rectangle")
		Loop 50 {
			for stage in ["", "font", "format", "brush", "measure", "draw", "throw"] {
				api := NativeTextOwnership(stage)
				result := Gdip_TextRenderer.Draw(graphics, "Text 5", "s24", "Arial", 220, 80, 0, 0, api)
				Require(stage = "" ? StrSplit(result, "|").Length = 6 : result < 0, "Native text fault outcome")
				Require(api.Alive.Count = 0 && !api.ReleaseFailures, "Every real GDI+ allocation receives a successful matching release")
			}
		}
		FileAppend "PASS Windows text pixels, explicit brush ownership and 350 GDI+ lifecycle cases (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		if brush
			Gdip_DeleteBrush(brush)
		if graphics
			Gdip_DeleteGraphics(graphics)
		if bitmap
			Gdip_DisposeImage(bitmap)
		Gdip_Shutdown(token)
	}
}

NativeTextPixels(bitmap) {
	Require(Gdip_LockBits(bitmap, 0, 0, 240, 100, &stride, &scan, &data, 1) = 0, "Lock fixture pixels")
	try {
		pixels := Buffer(240 * 100 * 4)
		Loop 100
			DllCall("RtlMoveMemory", "Ptr", pixels.Ptr + (A_Index-1)*960, "Ptr", scan + (A_Index-1)*stride, "UPtr", 960)
		return pixels
	} finally Gdip_UnlockBits(bitmap, &data)
}
NativeTextPixelsEqual(first, second) => DllCall("ntdll\RtlCompareMemory", "Ptr", first, "Ptr", second, "UPtr", first.Size, "UPtr") = first.Size

class NativeTextOwnership extends Gdip_TextApi {
	__New(stage) => (this.Stage := stage, this.Alive := Map(), this.ReleaseFailures := 0)
	Track(handle) {
		if handle
			this.Alive[handle] := true
		return handle
	}
	Family(name) => this.Track(super.Family(name))
	Font(family, size, style) => this.Stage = "font" ? 0 : this.Track(super.Font(family, size, style))
	Format(flags) => this.Stage = "format" ? 0 : this.Track(super.Format(flags))
	Brush(color) => this.Stage = "brush" ? 0 : this.Track(super.Brush(color))
	Measure(graphics, text, font, formatHandle, &rect) {
		if this.Stage = "throw"
			throw Error("Injected text measurement failure")
		return this.Stage = "measure" ? 0 : super.Measure(graphics, text, font, formatHandle, &rect)
	}
	Draw(graphics, text, font, formatHandle, brush, &rect) => this.Stage = "draw" ? 1 : super.Draw(graphics, text, font, formatHandle, brush, &rect)
	Released(handle, status) {
		if status = 0
			this.Alive.Delete(handle)
		else
			this.ReleaseFailures++
		return status
	}
	DeleteBrush(brush) => this.Released(brush, super.DeleteBrush(brush))
	DeleteFormat(formatHandle) => this.Released(formatHandle, super.DeleteFormat(formatHandle))
	DeleteFont(font) => this.Released(font, super.DeleteFont(font))
	DeleteFamily(family) => this.Released(family, super.DeleteFamily(family))
}
