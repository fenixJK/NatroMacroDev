; Auto-Jelly owns one OCR engine per run. COM wrappers own every returned reference.
class nm_OcrBudget {
	__New(check, timeout := 10000, clock := unset, pause := unset) {
		if !IsInteger(timeout) || timeout < 1 || timeout > 60000
			throw ValueError("Invalid OCR time budget")
		this.CheckInput := check
		this.Clock := IsSet(clock) ? clock : (() => DllCall("GetTickCount64", "UInt64"))
		this.Pause := IsSet(pause) ? pause : ((ms) => Sleep(ms))
		this.Deadline := this.Clock.Call() + timeout
	}
	Check() {
		this.CheckInput.Call()
		if this.Clock.Call() >= this.Deadline
			throw Error("Mutation OCR timed out; rolling stopped")
	}
	Wait() => this.Pause.Call(Min(10, Max(1, this.Deadline - this.Clock.Call())))
}

class nm_OcrAsync {
	static Wait(operation, budget) {
		try {
			loop {
				budget.Check()
				status := operation.Status()
				if status = 1 {
					result := operation.Result()
					budget.Check() ; discard a result that became stale during GetResults
					return result
				}
				if status != 0
					throw Error("Mutation OCR operation failed (status " status ")")
				budget.Wait()
			}
		} finally {
			try operation.Close() ; teardown must not replace cancellation or the original error
		}
	}
}

class nm_OcrOperation {
	__New(operation) {
		this.Operation := operation, this.Info := 0
		this.Info := ComObjQuery(operation, "{00000036-0000-0000-C000-000000000046}")
	}
	Status() {
		ComCall(7, this.Info, "UIntP", &status := 0)
		return status
	}
	Result() => nm_OcrCom.Call(8, this.Operation)
	Close() {
		if !this.Info {
			this.Operation := 0
			return
		}
		try {
			status := this.Status()
			if status = 0 {
				ComCall(9, this.Info) ; Cancel is a request, not proof of completion.
				status := this.Status()
			}
			; IAsyncInfo.Close is invalid while the operation is still Started.
			if status >= 1 && status <= 3
				ComCall(10, this.Info)
		} finally this.Info := 0, this.Operation := 0
	}
	__Delete() {
		try this.Close()
	}
}

class nm_OcrApartment {
	__New() {
		this.Owned := false
		nm_OcrCom.Check(DllCall("Combase\RoInitialize", "UInt", 0, "Int"))
		this.Owned := true
	}
	Close() {
		if this.Owned {
			this.Owned := false
			DllCall("Combase\RoUninitialize")
		}
	}
	__Delete() => this.Close()
}

class nm_OcrString {
	__New(text) {
		this.Ptr := 0
		nm_OcrCom.Check(DllCall("Combase\WindowsCreateString", "WStr", text, "UInt", StrLen(text), "PtrP", &raw := 0, "Int"))
		this.Ptr := raw
	}
	__Delete() => DllCall("Combase\WindowsDeleteString", "Ptr", this.Ptr)
}

class nm_OcrCom {
	static Check(result) {
		if result < 0
			throw Error("Windows OCR call failed (" Format("0x{:08X}", result & 0xffffffff) ")")
	}
	static Guid(value) {
		guid := Buffer(16)
		this.Check(DllCall("Ole32\CLSIDFromString", "WStr", value, "Ptr", guid, "Int"))
		return guid
	}
	static Take(pointer) {
		if !pointer
			throw Error("Windows OCR returned an unavailable object")
		return ComValue(13, pointer, 1)
	}
	; These methods return exactly one interface reference. The wrapper releases it.
	static Call(index, object, args*) {
		output := Buffer(A_PtrSize, 0), args.Push("Ptr", output)
		try {
			ComCall(index, object, args*)
			return this.Take(NumGet(output, "Ptr"))
		} catch as err {
			if raw := NumGet(output, "Ptr")
				ObjRelease(raw)
			throw err
		}
	}
	static Factory(name, iid) {
		text := nm_OcrString(name), guid := this.Guid(iid), raw := 0
		try {
			this.Check(DllCall("Combase\RoGetActivationFactory", "Ptr", text, "Ptr", guid, "PtrP", &raw, "Int"))
			return this.Take(raw)
		} catch as err {
			if raw
				ObjRelease(raw)
			throw err
		}
	}
	static Text(index, object, args*) {
		output := Buffer(A_PtrSize, 0), args.Push("Ptr", output)
		try {
			ComCall(index, object, args*)
			buffer := DllCall("Combase\WindowsGetStringRawBuffer", "Ptr", NumGet(output, "Ptr"), "UIntP", &length := 0, "Ptr")
			if length > 65536
				throw Error("Mutation OCR text exceeds its limit")
			return length ? StrGet(buffer, length, "UTF-16") : ""
		} finally DllCall("Combase\WindowsDeleteString", "Ptr", NumGet(output, "Ptr"))
	}
	static Close(object) {
		if object {
			closable := ComObjQuery(object, "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}")
			ComCall(6, closable)
		}
	}
	static BitmapStream(hBitmap) {
		if !hBitmap
			throw Error("Missing mutation OCR bitmap")
		stream := picture := 0, raw := 0
		try {
			this.Check(DllCall("Ole32\CreateStreamOnHGlobal", "Ptr", 0, "Int", true, "PtrP", &raw, "Int"))
			stream := this.Take(raw), raw := 0
			desc := Buffer(8 + 2*A_PtrSize, 0)
			NumPut("UInt", desc.Size, "UInt", 1, "Ptr", hBitmap, desc)
			iid := this.Guid("{7BF80980-BF32-101A-8BBB-00AA00300CAB}")
			this.Check(DllCall("OleAut32\OleCreatePictureIndirect", "Ptr", desc, "Ptr", iid, "Int", false, "PtrP", &raw, "Int"))
			picture := this.Take(raw), raw := 0 ; caller retains ownership of the HBITMAP
			ComCall(15, picture, "Ptr", stream, "Int", true, "IntP", &size := 0)
			if size <= 0
				throw Error("Could not serialize the mutation OCR bitmap")
			ComCall(5, stream, "Int64", 0, "UInt", 0, "Ptr", 0) ; IStream.Seek to beginning
			iid := this.Guid("{905A0FE1-BC53-11DF-8C49-001E4FC686DA}")
			this.Check(DllCall("ShCore\CreateRandomAccessStreamOverStream", "Ptr", stream, "UInt", 0, "Ptr", iid, "PtrP", &raw, "Int"))
			result := this.Take(raw), raw := 0
			return result
		} finally {
			if raw
				ObjRelease(raw)
		}
	}
}

class nm_AutoJellyOcr {
	static EngineFactory() => nm_OcrCom.Factory("Windows.Media.Ocr.OcrEngine", "{5BFFA85A-3384-3540-9940-699120D428A8}")
	static Languages() {
		apartment := nm_OcrApartment(), factory := languages := language := 0
		try {
			factory := this.EngineFactory(), languages := nm_OcrCom.Call(7, factory)
			ComCall(7, languages, "UIntP", &count := 0)
			if count > 256
				throw Error("Windows OCR returned too many languages")
			text := ""
			Loop count {
				language := nm_OcrCom.Call(6, languages, "UInt", A_Index - 1)
				text .= nm_OcrCom.Text(6, language) "`n"
			}
			return text
		} finally {
			language := languages := factory := 0
			apartment.Close()
		}
	}
	__New(language) {
		this.Engine := this.DecoderFactory := this.Apartment := 0
		try {
			this.Apartment := nm_OcrApartment()
			factory := this.EngineFactory()
			ComCall(6, factory, "UIntP", &maximum := 0)
			this.MaxDimension := maximum
			languageFactory := nm_OcrCom.Factory("Windows.Globalization.Language", "{9B0252AC-0C27-44F8-B792-9793FB66C63E}")
			tag := nm_OcrString(language), value := nm_OcrCom.Call(6, languageFactory, "Ptr", tag)
			this.Engine := nm_OcrCom.Call(9, factory, "Ptr", value)
			this.DecoderFactory := nm_OcrCom.Factory("Windows.Graphics.Imaging.BitmapDecoder", "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}")
		} catch as err {
			factory := languageFactory := value := tag := 0
			this.Close()
			throw err
		}
	}
	ReadBitmap(hBitmap, check, timeout := 10000) {
		budget := nm_OcrBudget(check, timeout), stream := bitmap := frame := frameSoftware := decoder := result := 0
		try {
			budget.Check()
			stream := nm_OcrCom.BitmapStream(hBitmap)
			decoder := nm_OcrAsync.Wait(nm_OcrOperation(nm_OcrCom.Call(14, this.DecoderFactory, "Ptr", stream)), budget)
			frame := ComObjQuery(decoder, "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")
			ComCall(12, frame, "UIntP", &width := 0)
			ComCall(13, frame, "UIntP", &height := 0)
			if !width || !height || width > this.MaxDimension || height > this.MaxDimension
				throw Error("Mutation OCR image dimensions are unsupported")
			budget.Check()
			frameSoftware := ComObjQuery(decoder, "{FE287C9A-420C-4963-87AD-691436E08383}")
			bitmap := nm_OcrAsync.Wait(nm_OcrOperation(nm_OcrCom.Call(6, frameSoftware)), budget)
			result := nm_OcrAsync.Wait(nm_OcrOperation(nm_OcrCom.Call(6, this.Engine, "Ptr", bitmap)), budget)
			text := nm_OcrCom.Text(8, result) ; OcrResult.Text owns one returned HSTRING
			budget.Check()
			return text
		} finally {
			result := frameSoftware := frame := decoder := 0
			try nm_OcrCom.Close(bitmap)
			try nm_OcrCom.Close(stream)
			bitmap := stream := 0
		}
	}
	Close() {
		this.Engine := this.DecoderFactory := 0
		if this.Apartment {
			this.Apartment.Close()
			this.Apartment := 0
		}
	}
	__Delete() => this.Close()
}
