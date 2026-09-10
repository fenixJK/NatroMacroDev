TestNativeScreenCapture() {
	panel := Gui("-Caption -DPIScale", "Screen capture fixture"), token := Gdip_Startup(), image := 0
	try {
		panel.BackColor := "204060"
		panel.Show("x60 y70 w128 h96")
		Require(ActivateRoblox(panel.Hwnd), "Capture fixture owns foreground")
		Sleep 50
		WinGetClientPos &x, &y,,, "ahk_id " panel.Hwnd
		; Warm both display/window DC paths before checking resource accumulation.
		for request in [x "|" y "|128|96", "hwnd:" panel.Hwnd] {
			image := Gdip_BitmapFromScreen(request)
			Require(image > 0 && Gdip_GetImageWidth(image) = 128 && Gdip_GetImageHeight(image) = 96, "Native capture has expected dimensions")
			Require((Gdip_GetPixel(image, 64, 48) & 0xffffff) = 0x204060, "Native capture contains the fixture pixels")
			Gdip_DisposeImage(image), image := 0
		}
		before := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")
		Loop 100 {
			for request in [x "|" y "|128|96", "hwnd:" panel.Hwnd] {
				image := Gdip_BitmapFromScreen(request)
				Require(image > 0, "Repeated native capture succeeds")
				Gdip_DisposeImage(image), image := 0
			}
			for stage in ["copy", "throw", "decode"]
				Require(Gdip_ScreenCapture.Capture(0, 0, 128, 96, panel.Hwnd, "", NativeCaptureFailure(stage)) = 0, "Native resources released after injected capture failure")
		}
		DllCall("GdiFlush")
		after := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")
		Require(after <= before + 2, "Repeated successful and failed captures do not accumulate GDI objects")
		image := Gdip_BitmapFromScreen(x "|" y "|128|96", 0x42)
		Require(image > 0 && (Gdip_GetPixel(image, 64, 48) & 0xffffff) = 0, "Explicit BLACKNESS raster operation is preserved")
		Gdip_DisposeImage(image), image := 0
		FileAppend "PASS Windows screen/window capture pixels and ownership (" A_PtrSize * 8 "-bit); GDI " before " -> " after "`n", "*"
	} finally {
		if image > 0
			Gdip_DisposeImage(image)
		panel.Destroy()
		Gdip_Shutdown(token)
	}
}
class NativeCaptureFailure extends Gdip_ScreenCaptureApi {
	__New(stage) => this.Stage := stage
	Copy(memory, source, x, y, width, height, raster) {
		if this.Stage = "throw"
			throw Error("Injected native capture failure")
		return this.Stage = "copy" ? 0 : super.Copy(memory, source, x, y, width, height, raster)
	}
	Decode(bitmap) => 0
}
