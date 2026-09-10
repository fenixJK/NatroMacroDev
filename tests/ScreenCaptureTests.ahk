TestScreenCapture() {
	for stage in ["", "acquire", "dc", "bitmap", "select", "copy", "decode", "restore"] {
		for raises in [false, true] {
			api := ScreenCaptureFixture(stage, raises)
			result := Gdip_ScreenCapture.Capture(-10, 20, 30, 40, 99, "", api)
			AssertEqual(result, stage = "" ? 501 : 0, "Only a successful transfer and cleanup returns an image: " stage)
			if result
				api.Dispose(result)
			AssertEqual(api.Alive.Count, 0, "All temporary resources released after " stage)
			AssertEqual(api.AcquiredWindow, 99, "Requested window is retained even when acquisition fails")
			if stage != "acquire"
				AssertEqual(api.ReleasedWindow, 99, "Window DC released to the same HWND")
		}
	}
	api := ScreenCaptureFixture()
	result := Gdip_ScreenCapture.Capture(-1.5, "2.9", 10.8, "11.7", 0, 0x42, api)
	AssertEqual(result, 501, "Fractional coordinates retain native truncation behavior")
	AssertEqual(api.Rectangle, "-1|2|10|11", "Only validated integer coordinates reach native copy")
	AssertEqual(api.Raster, 0x42, "Explicit raster operation is forwarded")
	AssertEqual(api.ReleasedWindow, 0, "Desktop DC released to the desktop owner")
	api.Dispose(result)
	for rectangle in [[0, 0, 0, 10], [0, 0, 10, -1], ["x", 0, 10, 10], [2147483648, 0, 10, 10]] {
		api := ScreenCaptureFixture()
		AssertEqual(Gdip_ScreenCapture.Capture(rectangle[1], rectangle[2], rectangle[3], rectangle[4], 0, "", api), -1, "Invalid rectangle rejected")
		AssertEqual(api.Calls.Length, 0, "Invalid rectangle allocates no native resources")
	}
	for malformed in ["1|2|3", "1|2|3|4|5", "1|2||4", "1|2|0|4", "abc"]
		AssertEqual(Gdip_BitmapFromScreen(malformed), -1, "Malformed screen request returns its documented error")
	AssertEqual(Gdip_BitmapFromScreen("hwnd:0"), -2, "Missing window never falls back to desktop")
}

class ScreenCaptureFixture {
	__New(stage := "", raises := false) {
		this.Stage := stage, this.Raises := raises, this.Alive := Map(), this.Calls := []
		this.Selected := 0, this.AcquiredWindow := this.ReleasedWindow := -1
	}
	Step(stage) {
		this.Calls.Push(stage)
		if stage = this.Stage {
			if this.Raises
				throw Error("Injected capture failure")
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
	Acquire(hwnd) {
		this.AcquiredWindow := hwnd
		return this.Allocate("acquire", 101)
	}
	CreateDC(source) => this.Allocate("dc", 201)
	CreateBitmap(width, height, memory) => this.Allocate("bitmap", 301)
	Select(memory, bitmap) {
		if !this.Step(bitmap = 301 ? "select" : "restore")
			return 0
		previous := this.Selected ? this.Selected : 401, this.Selected := bitmap
		return previous
	}
	Copy(memory, source, x, y, width, height, raster) {
		this.Rectangle := x "|" y "|" width "|" height, this.Raster := raster
		return this.Step("copy")
	}
	Decode(bitmap) => this.Allocate("decode", 501)
	DeleteDC(memory) {
		AssertEqual(memory, 201, "Only the owned memory DC may be deleted")
		this.Alive.Delete(memory), this.Selected := 0
		return true
	}
	DeleteBitmap(bitmap) {
		Assert(this.Selected != bitmap, "DIB must be deselected before deletion")
		this.Alive.Delete(bitmap)
		return true
	}
	Release(source, hwnd) {
		this.ReleasedWindow := hwnd, this.Alive.Delete(source)
		return true
	}
	Dispose(image) => this.Alive.Delete(image)
}
