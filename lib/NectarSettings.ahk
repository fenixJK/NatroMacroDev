nm_NectarSettings(*) {
	global MainGui, MacroState, PlanterBuffer, AdaptivePlanterGatherInterrupt
	if MacroState != 0
		return
	panel := Gui("+Owner" MainGui.Hwnd, "Nectar planning")
	panel.SetFont("s10", "Segoe UI")
	panel.Add("Text", "w390", "Reserve above each nectar minimum (%)")
	panel.Add("Edit", "w70 vReserve Number", nm_NectarPlanner.BufferPercent(PlanterBuffer))
	panel.Add("UpDown", "Range0-20", nm_NectarPlanner.BufferPercent(PlanterBuffer))
	panel.Add("Text", "w390", "A 10% reserve with a 70% minimum targets 77%. Auto starts replenishing before the minimum is reached.")
	panel.Add("CheckBox", "w390 vInterrupt Checked" (AdaptivePlanterGatherInterrupt = 1), "Interrupt gathering when a planter is due")
	panel.Add("Text", "w390", "Boost protection and failed-harvest retry delays still apply. Fixed intervals and Full Grown keep their selected timing.")
	panel.Add("Button", "w90 Default", "Save").OnEvent("Click", (*) => nm_SaveNectarSettings(panel))
	panel.Add("Button", "x+10 w90", "Cancel").OnEvent("Click", (*) => panel.Destroy())
	panel.OnEvent("Close", (*) => panel.Destroy())
	panel.OnEvent("Escape", (*) => panel.Destroy())
	panel.Show()
}

nm_SaveNectarSettings(panel) {
	global MacroState, PlanterBuffer, AdaptivePlanterGatherInterrupt
	wasCritical := A_IsCritical
	Critical
	try {
		if MacroState != 0
			throw Error("Stop the macro before saving nectar settings.")
		buffer := panel["Reserve"].Value, interrupt := panel["Interrupt"].Value
		if !IsInteger(buffer) || buffer < 0 || buffer > 20
			throw ValueError("Reserve must be a whole number from 0 to 20.")
		IniWrite buffer, "settings\nm_config.ini", "Planters", "PlanterBuffer"
		PlanterBuffer := buffer + 0
		IniWrite interrupt, "settings\nm_config.ini", "Planters", "AdaptivePlanterGatherInterrupt"
		AdaptivePlanterGatherInterrupt := interrupt
		panel.Destroy()
	} catch as err
		MsgBox err.Message, "Nectar settings", 0x1030
	finally Critical wasCritical
}
