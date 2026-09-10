TestTextGraphics() {
	for stage in ["", "family", "font", "format", "brush", "align", "render", "measure", "measure2", "draw"] {
		for raises in [false, true] {
			api := TextGraphicsFixture(stage, raises)
			result := Gdip_TextRenderer.Draw(99, "Text", "x10 y4 w100 h40 vCenter s20 Bold c12345678", "Arial", 200, 100, 0, 0, api)
			if stage = "" {
				bounds := StrSplit(result, "|")
				AssertEqual(bounds.Length, 6, "Successful text retains six measurement fields")
				AssertEqual(bounds[1] + 0, 10, "Text x position retained")
				AssertEqual(bounds[2] + 0, 19, "Text vertically centered")
			}
			else
				Assert(result < 0, "Native text failure returns an error: " stage)
			AssertEqual(api.Alive.Count, 0, "Partial text allocations released: " stage)
		}
	}
	api := TextGraphicsFixture()
	result := Gdip_TextRenderer.Draw(99, "Text", "x10p y20p w50p h40p s10p c00000000 NoWrap Right", "Arial", 200, 100, 1, 0, api)
	bounds := StrSplit(result, "|")
	AssertEqual(bounds[1] + 0, 20, "Percent x position retained")
	AssertEqual(bounds[2] + 0, 20, "Percent y position retained")
	AssertEqual(api.Color, 0, "Transparent black is a color, never a pointer")
	AssertEqual(api.Size, 10, "Percent font size uses supplied height")
	AssertEqual(api.Flags, 0x5000, "NoWrap flags retained")
	AssertEqual(api.Alignment, 2, "Right alignment retained")
	AssertEqual(api.Draws, 0, "Measure-only does not draw")
	api := TextGraphicsFixture()
	Gdip_TextRenderer.Draw(99, "Text", "c12345678", "Arial", 200, 100, 0, 0, api)
	AssertEqual(api.Color, 0x12345678, "Digit-only color interpreted as hexadecimal ARGB")
	for stage in ["", "font", "measure2", "draw"] {
		api := TextGraphicsFixture(stage)
		Gdip_TextRenderer.Draw(99, "Text", "vCenter", "Arial", 200, 100, 0, 808, api)
		AssertEqual(api.Brushes, 0, "Explicit borrowed brush avoids allocation and cloning")
		AssertEqual(api.Alive.Count, 0, "Owned objects released while borrowed brush remains external")
		if stage = ""
			AssertEqual(api.DrawBrush, 808, "Explicit brush passed unchanged")
	}
	for sample in [[0, "", -2], [99, "x10p", -1], [99, "c123456789", -6]] {
		api := TextGraphicsFixture()
		AssertEqual(Gdip_TextRenderer.Draw(sample[1], "Text", sample[2], "Arial",,,, 0, api), sample[3], "Invalid request rejected")
		AssertEqual(api.Calls, 0, "Invalid request allocates nothing")
	}
	for raises in [false, true] {
		api := TextGraphicsFixture("delete", raises)
		AssertEqual(Gdip_TextRenderer.Draw(99, "Text", "", "Arial",,,, 0, api), -7, "Failed cleanup cannot return measured success")
		AssertEqual(api.Alive.Count, 1, "All other releases attempted after brush release fails")
		Assert(api.Alive.Has(4), "Only the failed brush release remains in fixture ownership")
	}
}

class TextGraphicsFixture {
	__New(stage := "", raises := false) {
		this.Stage := stage, this.Raises := raises, this.Alive := Map(), this.Calls := 0
		this.Measures := this.Draws := this.Brushes := 0
	}
	Step(stage) {
		this.Calls++
		if stage = this.Stage {
			if this.Raises
				throw Error("Injected text failure")
			return false
		}
		return true
	}
	Allocate(stage, handle) {
		if !this.Step(stage)
			return 0
		this.Alive[handle] := true
		return handle
	}
	Family(name) => this.Allocate("family", 1)
	Font(family, size, style) {
		this.Size := size
		return this.Allocate("font", 2)
	}
	Format(flags) {
		this.Flags := flags
		return this.Allocate("format", 3)
	}
	Brush(color) {
		this.Color := color, this.Brushes++
		return this.Allocate("brush", 4)
	}
	Align(formatHandle, align) {
		this.Alignment := align
		return !this.Step("align")
	}
	Rendering(graphics, hint) => !this.Step("render")
	Measure(graphics, text, font, formatHandle, &rect) {
		this.Measures++
		return this.Step(this.Measures = 1 ? "measure" : "measure2") ? NumGet(rect, 0, "Float") "|" NumGet(rect, 4, "Float") "|30|10|4|1" : 0
	}
	Draw(graphics, text, font, formatHandle, brush, &rect) {
		this.Draws++, this.DrawBrush := brush
		return !this.Step("draw")
	}
	DeleteBrush(brush) {
		AssertEqual(brush, 4, "Borrowed brush must never be deleted")
		return this.Step("delete") ? this.Release(brush) : 1
	}
	DeleteFormat(formatHandle) => this.Release(formatHandle)
	DeleteFont(font) => this.Release(font)
	DeleteFamily(family) => this.Release(family)
	Release(handle) {
		this.Alive.Delete(handle)
		return 0
	}
}
