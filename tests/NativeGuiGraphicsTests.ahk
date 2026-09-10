TestNativeGuiGraphics() {
	owner := nm_GuiGraphics()
	try {
		owner.CreateSurface(32, 32).Close()
		before := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")
		Loop 100 {
			surface := owner.CreateSurface(96, 64)
			dib := surface.Bitmap, dc := surface.DC
			Require(DllCall("GetObjectW", "Ptr", dib, "Int", 0, "Ptr", 0) > 0 && DllCall("GetCurrentObject", "Ptr", dc, "UInt", 7, "Ptr"), "Live surface supports native object queries")
			Gdip_GraphicsClear(surface.Graphics, 0xFF445566)
			surface.Close(), surface.Close()
			DllCall("GdiFlush")
			if DllCall("GetObjectType", "Ptr", dib) || DllCall("GetObjectType", "Ptr", dc)
				FileAppend "Surface release types: bitmap=" DllCall("GetObjectType", "Ptr", dib) " dc=" DllCall("GetObjectType", "Ptr", dc) " handles=" dib "," dc " objectBytes=" DllCall("GetObjectW", "Ptr", dib, "Int", 0, "Ptr", 0) " selected=" DllCall("GetCurrentObject", "Ptr", dc, "UInt", 7, "Ptr") " gdiBefore=" before " gdiAfter=" DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt") "`n", "*"
			Require(!DllCall("GetObjectType", "Ptr", dib) && !DllCall("GetObjectType", "Ptr", dc), "Closed surface releases its actual native objects")
		}
		after := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")
		Require(after <= before + 1, "Repeated GUI surface allocation does not accumulate GDI objects")
		asset := Gdip_CreateBitmap(4, 4)
		owner.Bitmaps["first"] := asset, owner.Bitmaps["alias"] := asset
		owner.Close(), owner.Close()
		Require(!owner.Token && !owner.Surface && owner.Bitmaps.Count = 0, "GUI assets, aliases, surface and startup token release idempotently")
	} finally owner.Close()
	TestNativeGeneratedGuis()
	FileAppend "PASS Windows GUI graphics ownership and generated redraws (" A_PtrSize * 8 "-bit)`n", "*"
}

TestNativeGeneratedGuis() {
	workingBefore := A_WorkingDir
	SetWorkingDir A_ScriptDir "\.."
	directory := A_Temp "\natro-gui-" DllCall("GetCurrentProcessId")
	DirCreate directory
	try {
		for kind in ["discord", "priority", "bee"] {
			config := nm_GuiScripts.Defaults(kind)
			if kind = "discord"
				config["webhook"] := 'Unicode Ω "quoted" `` data`nsecond line'
			render := kind = "discord" ? "nm_WebhookGUI" : kind = "priority" ? "nm_priorityGui" : "DrawGUI"
			close := kind = "bee" ? "closeFunction" : "ExitFunc"
			source := "SetWorkingDir " nm_GuiScripts.Literal(directory) "`nSetTimer nm_ProbeGui, -50`n"
				. nm_GuiScripts.Build(kind, config) "`n"
				. 'nm_ProbeGui() {`n'
				. ' global guiReady, resources, config`n'
				. ' if !IsSet(guiReady) || !guiReady {`n SetTimer nm_ProbeGui, -50`n return`n }`n'
				. ' Critical "On"`n try {`n'
				. ' before := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")`n'
				. ' Loop 50`n ' render '()`n'
				. ' after := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")`n'
				. ' if after > before + 2`n throw Error("GDI objects grew during GUI redraw")`n'
				. ' dib := resources.Surface.Bitmap, dc := resources.Surface.DC`n'
				. close '()`n' close '()`n'
				. ' DllCall("GdiFlush")`n'
				. ' if resources.Token || resources.Surface || resources.Bitmaps.Count || DllCall("GetObjectType", "Ptr", dib) || DllCall("GetObjectType", "Ptr", dc)`n throw Error("GUI cleanup left owned graphics resources")`n'
				. ' FileAppend "PASS ' kind ' redraw and close" (config.Has("webhook") ? "|" config["webhook"] : ""), "*", "UTF-8-RAW"`n'
				. ' } catch as err {`n FileAppend "FAIL GUI probe: " err.Message, "*", "UTF-8-RAW"`n ExitApp 1`n }`n ExitApp 0`n}`n'
			worker := nm_InlineWorker(source, A_AhkPath)
			try {
				output := worker.Output()
				Require(output = "PASS " kind " redraw and close" (config.Has("webhook") ? "|" config["webhook"] : ""), "Generated GUI native lifecycle: " output)
			} finally worker.Close()
		}
	} finally {
		SetWorkingDir workingBefore
		DirDelete directory, true
	}
}
