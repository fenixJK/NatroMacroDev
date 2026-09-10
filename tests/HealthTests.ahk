TestHealthObservation() {
	token := Gdip_Startup(), bitmap := Gdip_CreateBitmap(120, 70), graphics := Gdip_GraphicsFromImage(bitmap)
	green := Gdip_BrushCreateSolid(0xFF1FE744), red := Gdip_BrushCreateSolid(0xFF6B131A)
	try {
		Gdip_GraphicsClear(graphics, 0xFF000000)
		AssertEqual(nm_HealthBarReader.Read(bitmap).Length, 0, "Readable blank frame has no health bars")
		; Damaged then undamaged: the second bar must not inherit a red endpoint.
		Gdip_FillRectangle(graphics, green, 3, 3, 25, 4)
		Gdip_FillRectangle(graphics, red, 28, 3, 75, 4)
		Gdip_FillRectangle(graphics, green, 3, 13, 10, 4)
		Gdip_FillRectangle(graphics, red, 3, 23, 10, 4)
		Gdip_FillRectangle(graphics, green, 3, 33, 1, 4)
		Gdip_FillRectangle(graphics, red, 4, 33, 1, 4)
		bars := nm_HealthBarReader.Read(bitmap)
		AssertEqual(bars.Length, 4, "Every separate bar is returned exactly once")
		for expected in [0, 25, 50, 100] {
			matches := 0
			for value in bars
				if value = expected
					matches++
			AssertEqual(matches, 1, "Correct independent percentage: " expected)
		}
		AssertEqual(Gdip_GetPixel(bitmap, 3, 3), 0xFF1FE744, "Reader does not erase caller-owned bitmap")
		; A narrow capture ending inside a run must never use full-window bounds.
		narrow := Gdip_CloneBitmapArea(bitmap, 3, 33, 2, 4)
		try AssertEqual(nm_HealthBarReader.Read(narrow)[1], 50, "Both edge pixels belong in the denominator")
		finally Gdip_DisposeImage(narrow)
		AssertHealthReadFails(0, "Missing capture is not an empty successful frame")
		AssertEqual(Gdip_LockBits(bitmap, 0, 0, 120, 70, &stride, &scan, &locked), 0, "Lock caller-owned source")
		try AssertEqual(nm_HealthBarReader.Read(bitmap).Length, 4, "Owned clone can be read without changing the locked source")
		finally Gdip_UnlockBits(bitmap, &locked)
		; Image-search failure after a successful clone must also propagate.
		needle := nm_HealthBarReader.Needles[1]
		AssertEqual(Gdip_LockBits(needle, 0, 0, 1, 4, &stride, &scan, &locked), 0, "Lock cached template")
		try AssertHealthReadFails(bitmap, "Failed image search must not mean absent")
		finally Gdip_UnlockBits(needle, &locked)
		Loop 100
			AssertEqual(nm_HealthBarReader.Read(bitmap).Length, 4, "Repeated scans after errors remain usable")
		nm_HealthBarReader.Release()
		AssertEqual(nm_HealthBarReader.Needles.Length, 0, "Explicit release clears cached native pointers")
		AssertEqual(nm_HealthBarReader.Read(bitmap).Length, 4, "Reader rebuilds templates after release")
		crowded := Gdip_CreateBitmap(5, 606), cg := Gdip_GraphicsFromImage(crowded)
		try {
			Gdip_GraphicsClear(cg, 0xFF000000)
			Loop 101
				Gdip_FillRectangle(cg, green, 1, (A_Index - 1) * 6, 2, 4)
			AssertHealthReadFails(crowded, "Detection limit must not return a misleading partial list")
		} finally {
			Gdip_DeleteGraphics(cg), Gdip_DisposeImage(crowded)
		}
	} finally {
		nm_HealthBarReader.Release()
		Gdip_DeleteBrush(green), Gdip_DeleteBrush(red), Gdip_DeleteGraphics(graphics)
		Gdip_DisposeImage(bitmap), Gdip_Shutdown(token)
	}
}

AssertHealthReadFails(bitmap, message) {
	readFailed := false
	try nm_HealthBarReader.Read(bitmap)
	catch Error
		readFailed := true
	Assert(readFailed, message)
}
