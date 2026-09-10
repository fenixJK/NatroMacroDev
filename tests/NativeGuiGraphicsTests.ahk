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
			; Deleted GDI handles may remain queryable in Windows caches. Check release
			; return values (Close throws on failure), ownership and repeated resource counts.
			Require(!surface.Bitmap && !surface.DC && !surface.Previous && !surface.Graphics, "Closed surface relinquishes all successfully released native objects")
		}
		after := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")
		FileAppend "GUI surface GDI count after 100 cycles: " before " -> " after "`n", "*"
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
	DirCreate directory "\settings"
	iniFixture := "[bees]`nBomber=1`nresources=0`nw=1`n[extrasettings]`nmythicStop=1`n[unknown]`nselectAll=1`n"
	FileAppend iniFixture, directory "\settings\mutations.ini", "UTF-8"
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
				. ' global guiReady, resources, config, Bomber, mythicStop, selectAll, priorityState`n'
				. ' if !IsSet(guiReady) || !guiReady {`n SetTimer nm_ProbeGui, -50`n return`n }`n'
				. ' Critical "On"`n try {`n'
				. (kind = "bee" ? " nm_ProbeBeeAssets()`n nm_ProbeBeePreflight()`n nm_ProbeBeeMouse()`n nm_ProbeBeeLimits()`n" : "")
				. (kind = "priority" ? ' if A_CoordModeMouse != "Screen"`n throw Error("Priority drag uses screen coordinates")`n if !nm_SavePriority(87654321) || priorityState.Order != 87654321 || nm_PrioritySettings.Read().Order != 87654321`n throw Error("Priority editor failed to save and publish order")`n if !nm_SavePriority(12345678) || priorityState.Order != 12345678`n throw Error("Priority editor failed to reset")`n' : "")
				. (kind = "bee" ? ' if Bomber != 1 || mythicStop != 1 || selectAll != 0 || FileRead("settings\mutations.ini") != ' nm_GuiScripts.Literal(iniFixture) '`n throw Error("Auto-Jelly settings validation or read-only startup failed")`n' : "")
				. ' before := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")`n'
				. ' Loop 50`n ' render '()`n'
				. ' after := DllCall("GetGuiResources", "Ptr", -1, "UInt", 0, "UInt")`n'
				. ' if after > before + 2`n throw Error("GDI objects grew during GUI redraw")`n'
				. close '()`n' close '()`n'
				. ' DllCall("GdiFlush")`n'
				. ' if resources.Token || resources.Surface || resources.Bitmaps.Count`n throw Error("GUI cleanup left owned graphics resources")`n'
				. ' FileAppend "PASS ' kind ' redraw and close" (config.Has("webhook") ? "|" config["webhook"] : ""), "*", "UTF-8-RAW"`n'
				. ' } catch as err {`n FileAppend "FAIL GUI probe: " err.Message, "*", "UTF-8-RAW"`n ExitApp 1`n }`n ExitApp 0`n}`n'
			if kind = "bee"
				source .= '#Include "%A_ScriptDir%\tests\AutoJellyGuiProbe.ahk"`n'

			worker := nm_InlineWorker(source, A_AhkPath)
			try {
				try output := worker.Output()
				catch as err {
					if FileExist(directory "\probe-phase.txt")
						FileAppend "GUI probe phases: " SubStr(FileRead(directory "\probe-phase.txt"), 1, 3000) "`n", "*"
					throw err
				}
				Require(output = "PASS " kind " redraw and close" (config.Has("webhook") ? "|" config["webhook"] : ""), "Generated GUI native lifecycle: " output)
			} finally worker.Close()
		}
		; Invalid known settings terminate before GUI creation or game input.
		FileDelete directory "\settings\mutations.ini"
		FileAppend "[bees]`nBomber=2", directory "\settings\mutations.ini", "UTF-8"
		worker := nm_InlineWorker("SetWorkingDir " nm_GuiScripts.Literal(directory) "`n" nm_GuiScripts.Build("bee", nm_GuiScripts.Defaults("bee")), A_AhkPath)
		try {
			Require(worker.Output() = "Auto-Jelly settings could not be loaded: Invalid Auto-Jelly setting: Bomber", "Invalid Auto-Jelly settings fail with a bounded field-only error")
			Require(NumGet(worker.View + nm_InlineProtocol.Response, 0, "UInt") = 1, "Invalid settings exit unsuccessfully for parent failure reporting")
			Require(FileRead(directory "\settings\mutations.ini") = "[bees]`nBomber=2", "Failed GUI startup preserves rejected settings")
		} finally worker.Close()

	} finally {
		SetWorkingDir workingBefore
		DirDelete directory, true
	}
}
