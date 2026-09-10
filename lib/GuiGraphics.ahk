; One owner for a layered GUI's DIB, DC, GDI+ graphics and decoded assets.
class nm_LayeredSurface {
	__New(width, height) {
		this.Bitmap := this.DC := this.Previous := this.Graphics := 0
		if !IsInteger(width) || !IsInteger(height) || width < 1 || height < 1 || width > 8192 || height > 8192
			throw ValueError("Invalid GUI surface dimensions")
		try {
			if !(this.Bitmap := CreateDIBSection(width, height)) || !(this.DC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr"))
				throw Error("Could not allocate GUI surface")
			previous := DllCall("SelectObject", "Ptr", this.DC, "Ptr", this.Bitmap, "Ptr")
			if !previous || previous = -1
				throw Error("Could not select GUI surface")
			this.Previous := previous
			if !(this.Graphics := Gdip_GraphicsFromHDC(this.DC))
				throw Error("Could not create GUI graphics")
		} catch as err {
			this.Close()
			throw err
		}
	}
	Close() {
		if this.Graphics {
			if Gdip_DeleteGraphics(this.Graphics)
				throw Error("Could not release GUI graphics")
			this.Graphics := 0
		}
		if this.DC && this.Previous {
			previous := DllCall("SelectObject", "Ptr", this.DC, "Ptr", this.Previous, "Ptr")
			if !previous || previous = -1
				throw Error("Could not restore GUI bitmap selection")
			this.Previous := 0
		}
		if this.Bitmap {
			if !DllCall("DeleteObject", "Ptr", this.Bitmap)
				throw Error("Could not release GUI bitmap")
			this.Bitmap := 0
		}
		if this.DC {
			if !DllCall("DeleteDC", "Ptr", this.DC)
				throw Error("Could not release GUI device context")
			this.DC := 0
		}
	}
}

class nm_GuiGraphics {
	__New() {
		this.Surface := 0, this.Bitmaps := Map()
		this.Bitmaps.CaseSense := 0
		if !(this.Token := Gdip_Startup())
			throw Error("Could not start GUI graphics")
	}
	CreateSurface(width, height) {
		if this.Surface
			this.Surface.Close()
		return this.Surface := nm_LayeredSurface(width, height)
	}
	Close() {
		if this.Surface {
			this.Surface.Close()
			this.Surface := 0
		}
		seen := Map(), failed := false
		for key, bitmap in this.Bitmaps.Clone() {
			if !bitmap {
				this.Bitmaps.Delete(key)
				continue
			}
			if !seen.Has(bitmap)
				seen[bitmap] := Gdip_DisposeImage(bitmap) = 0
			if seen[bitmap]
				this.Bitmaps.Delete(key)
			else
				failed := true
		}
		if failed
			throw Error("Could not release GUI image assets")
		if this.Token
			Gdip_Shutdown(this.Token), this.Token := 0
	}
}
