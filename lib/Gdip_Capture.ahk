; A borrowed display/window DC is released to its owner; only memory DCs are deleted.
class Gdip_ScreenCapture {
	static Read(screen := 0, raster := "") {
		try {
			hwnd := 0
			if screen = 0 {
				x := DllCall("GetSystemMetrics", "Int", 76), y := DllCall("GetSystemMetrics", "Int", 77)
				width := DllCall("GetSystemMetrics", "Int", 78), height := DllCall("GetSystemMetrics", "Int", 79)
			} else if SubStr(screen, 1, 5) = "hwnd:" {
				hwnd := SubStr(screen, 6)
				if !IsInteger(hwnd) || !DllCall("IsWindow", "Ptr", hwnd)
					return -2
				rect := Buffer(16)
				if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
					return -2
				width := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
				height := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int"), x := y := 0
			} else if IsInteger(screen) {
				monitor := GetMonitorInfo(screen)
				if !IsObject(monitor)
					return -1
				x := monitor.Left, y := monitor.Top, width := monitor.Right - x, height := monitor.Bottom - y
			} else {
				parts := StrSplit(screen, "|")
				if parts.Length != 4
					return -1
				x := parts[1], y := parts[2], width := parts[3], height := parts[4]
			}
			return this.Capture(x, y, width, height, hwnd, raster)
		} catch {
			return -1
		}
	}
	static Capture(x, y, width, height, hwnd := 0, raster := "", api := unset) {
		for value in [x, y, width, height]
			if !IsNumber(value) || value < -2147483648 || value > 2147483647
				return -1
		; Preserve the old native integer conversion for fractional crop coordinates.
		x := Integer(x), y := Integer(y), width := Integer(width), height := Integer(height)
		if width < 1 || height < 1
			return -1
		if raster != "" && (!IsNumber(raster) || raster < 0 || raster > 0xffffffff)
			return -1
		api := IsSet(api) ? api : Gdip_ScreenCaptureApi()
		source := memory := bitmap := previous := image := 0, clean := true
		try {
			if !(source := api.Acquire(hwnd))
				return 0 ; never fall back from a failed window DC to the desktop
			if !(memory := api.CreateDC(source))
				return 0
			if !(bitmap := api.CreateBitmap(width, height, memory))
				return 0
			previous := api.Select(memory, bitmap)
			if !previous || previous = -1 {
				previous := 0
				return 0
			}
			if !api.Copy(memory, source, x, y, width, height, raster)
				return 0
			image := api.Decode(bitmap)
		} catch {
			image := 0
		} finally {
			if memory && previous {
				restored := 0
				try restored := api.Select(memory, previous)
				if !restored || restored = -1 {
					clean := false
					; A failed restore leaves the DIB selected. Delete the memory DC
					; first so the owned DIB can subsequently be deleted safely.
					try {
						if api.DeleteDC(memory)
							memory := 0
					}
				}
			}
			if bitmap {
				try clean := api.DeleteBitmap(bitmap) && clean
				catch
					clean := false
			}
			if memory {
				try clean := api.DeleteDC(memory) && clean
				catch
					clean := false
			}
			if source {
				try clean := api.Release(source, hwnd) && clean
				catch
					clean := false
			}
			if !clean && image {
				try api.Dispose(image)
				image := 0
			}
		}
		return image
	}
}

class Gdip_ScreenCaptureApi {
	Acquire(hwnd) => hwnd ? DllCall("GetDCEx", "Ptr", hwnd, "Ptr", 0, "UInt", 3, "Ptr") : DllCall("GetDC", "Ptr", 0, "Ptr")
	CreateDC(source) => DllCall("gdi32\CreateCompatibleDC", "Ptr", source, "Ptr")
	CreateBitmap(width, height, memory) => CreateDIBSection(width, height, memory)
	Select(memory, bitmap) => DllCall("gdi32\SelectObject", "Ptr", memory, "Ptr", bitmap, "Ptr")
	Copy(memory, source, x, y, width, height, raster) => BitBlt(memory, 0, 0, width, height, source, x, y, raster)
	Decode(bitmap) => Gdip_CreateBitmapFromHBITMAP(bitmap)
	Release(source, hwnd) => DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", source)
	DeleteBitmap(bitmap) => DllCall("gdi32\DeleteObject", "Ptr", bitmap)
	DeleteDC(memory) => DllCall("gdi32\DeleteDC", "Ptr", memory)
	Dispose(image) => Gdip_DisposeImage(image)
}
