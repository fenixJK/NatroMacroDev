TestNativeAutoJellyOcr() {
	; Real COM vtables check Cancel/Close ordering and reference ownership,
	; including a provider that ignores cancellation and remains Started.
	for mode in ["pending", "cancelled", "completed", "error", "status-error", "cancel-error", "close-error"] {
		provider := OcrNativeAsyncFixture(mode), operation := 0
		try {
			operation := nm_OcrOperation(ComValue(13, provider.Operation.Ptr, 1))
			Require(provider.References = 2, "Async adapter owns operation and queried IAsyncInfo")
			try operation.Close()
			Require(provider.References = 0, "Async cleanup releases both native interface references")
			Require(provider.Cancels = (mode = "pending" || mode = "cancelled" || mode = "cancel-error"), "Cancellation requested only for Started")
			Require(provider.Closes = (mode = "cancelled" || mode = "completed" || mode = "error" || mode = "close-error"), "Close is never called on a still-pending operation")
			operation.Close()
			Require(provider.References = 0, "Repeated async cleanup cannot release twice")
		} finally {
			if operation
				try operation.Close()
			provider.Dispose()
		}
	}
	token := Gdip_Startup(), capture := graphics := hBitmap := reader := 0
	try {
		languages := nm_AutoJellyOcr.Languages()
		FileAppend "Native OCR languages: " StrReplace(languages, "`n", ",") "`n", "*"
		language := nm_AutoJellyObservation.EnglishLanguage(languages)
		reader := nm_AutoJellyOcr(language)
		capture := Gdip_CreateBitmap(400, 100), graphics := Gdip_GraphicsFromImage(capture)
		Require(capture && graphics, "Create OCR text fixture")
		Gdip_GraphicsClear(graphics, 0xffffffff)
		Gdip_TextToGraphics(graphics, "ENERGY 5", "x10 y10 s40 cff000000", "Arial", 400, 100)
		Gdip_DeleteGraphics(graphics), graphics := 0
		hBitmap := Gdip_CreateHBITMAPFromBitmap(capture)
		Require(hBitmap, "Create native OCR input")
		Loop 5 {
			text := reader.ReadBitmap(hBitmap, (*) => true)
			Require(InStr(text, "ENERGY") && InStr(text, "5"), "Actual English recognition returns the fixture text")
		}
		maximum := reader.MaxDimension, rejected := false
		reader.MaxDimension := 1
		try reader.ReadBitmap(hBitmap, (*) => true)
		catch as err {
			rejected := InStr(err.Message, "dimensions are unsupported")
		} finally reader.MaxDimension := maximum
		Require(rejected, "Actual decoder rejects unsupported dimensions before recognition")
		Require(InStr(reader.ReadBitmap(hBitmap, (*) => true), "ENERGY"), "OCR can retry after decode-stage failure")
		; Reject before decoding, then prove the same engine/input remain usable.
		StopOcr() => nm_NativeOcrCancel()
		try {
			reader.ReadBitmap(hBitmap, StopOcr)
			throw Error("Expected native OCR cancellation")
		} catch nm_AutoJellyCancelled {
		}
		Require(InStr(reader.ReadBitmap(hBitmap, (*) => true), "ENERGY"), "OCR engine can be reused after cancellation")
		reader.Close(), reader.Close()
		Require(!reader.Engine && !reader.DecoderFactory && !reader.Apartment, "OCR engine and apartment ownership cleared")
		FileAppend "PASS Windows Auto-Jelly OCR recognition, COM lifecycle and cancellation (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		if reader
			reader.Close()
		if hBitmap
			DllCall("DeleteObject", "Ptr", hBitmap)
		if graphics
			Gdip_DeleteGraphics(graphics)
		if capture
			Gdip_DisposeImage(capture)
		Gdip_Shutdown(token)
	}
}
nm_NativeOcrCancel() {
	throw nm_AutoJellyCancelled("Fixture OCR cancellation")
}

class OcrNativeAsyncFixture {
	__New(mode) {
		this.Mode := mode, this.References := 1, this.Cancels := this.Closes := 0
		this.CurrentStatus := mode = "completed" || mode = "close-error" ? 1 : mode = "error" ? 3 : 0
		this.Callbacks := [], this.OperationTable := Buffer(9*A_PtrSize, 0), this.InfoTable := Buffer(11*A_PtrSize, 0)
		this.Operation := Buffer(A_PtrSize), this.Info := Buffer(A_PtrSize)
		NumPut("Ptr", this.OperationTable.Ptr, this.Operation)
		NumPut("Ptr", this.InfoTable.Ptr, this.Info)
		for table in [this.OperationTable, this.InfoTable] {
			this.Bind(table, 0, "Query", 3)
			this.Bind(table, 1, "AddRef", 1)
			this.Bind(table, 2, "Release", 1)
		}
		this.Bind(this.InfoTable, 7, "Status", 2)
		this.Bind(this.InfoTable, 9, "Cancel", 1)
		this.Bind(this.InfoTable, 10, "Close", 1)
	}
	Bind(table, index, method, count) {
		callback := CallbackCreate(ObjBindMethod(this, method), , count)
		this.Callbacks.Push(callback)
		NumPut("Ptr", callback, table, index*A_PtrSize)
	}
	Query(self, iid, output) {
		; The production adapter only requests IAsyncInfo in this fixture.
		NumPut("Ptr", this.Info.Ptr, output)
		this.References++
		return 0
	}
	AddRef(self) => ++this.References
	Release(self) => --this.References
	Status(self, output) {
		if this.Mode = "status-error"
			return 0x80004005
		NumPut("UInt", this.CurrentStatus, output)
		return 0
	}
	Cancel(self) {
		this.Cancels++
		if this.Mode = "cancel-error"
			return 0x80004005
		if this.Mode = "cancelled"
			this.CurrentStatus := 2
		return 0
	}
	Close(self) {
		this.Closes++
		return this.Mode = "close-error" ? 0x80004005 : 0
	}
	Dispose() {
		for callback in this.Callbacks
			CallbackFree(callback)
		this.Callbacks := []
	}
}
