nm_CopyGatherSettings(GuiCtrl, *){
	global
	local slot := SubStr(GuiCtrl.Name, -1), values := Map(), key, err
	try {
		for key in nm_GatherProfiles.Keys
			values[key] := Field%key%%slot%
		A_Clipboard := nm_GatherProfiles.Export(values, fieldnamelist, patternlist)
	} catch as err
		MsgBox err.Message, "Could not copy gather profile", 0x1030
}
nm_PasteGatherSettings(GuiCtrl, *){
	global
	local slot := SubStr(GuiCtrl.Name, -1), patch, key, value, ctrl, err, wasCritical := A_IsCritical
	if MacroState != 0 {
		MsgBox "Stop the macro before importing a gather profile.", "Stop before importing", 0x1040
		return
	}
	try patch := nm_GatherProfiles.Parse(A_Clipboard, fieldnamelist, patternlist)
	catch as err {
		MsgBox err.Message "`nNo settings were imported.", "Invalid gather profile", 0x1030
		return
	}
	Critical
	try {
		; Resolve every control before persistence; missing controls cannot cause a
		; half-applied import. Commit precedes publication of the new in-memory state.
		if MacroState != 0
			throw Error("The macro started before the import could be applied")
		for key in patch
			ctrl := MainGui["Field" key slot]
		if patch.Has("PatternSize")
			ctrl := MainGui["FieldPatternSize" slot "UpDown"]
		if patch.Has("UntilPack")
			ctrl := MainGui["FieldUntilPack" slot "UpDown"]
		nm_GatherStore.Commit(slot, patch)
		for key, value in patch {
			Field%key%%slot% := value
			ctrl := MainGui["Field" key slot]
			if ctrl.Type = "DDL" || ctrl.Type = "Text"
				ctrl.Text := value
			else
				ctrl.Value := value
		}
		if patch.Has("PatternSize")
			MainGui["FieldPatternSize" slot "UpDown"].Value := FieldPatternSizeArr[patch["PatternSize"]]
		if patch.Has("UntilPack")
			MainGui["FieldUntilPack" slot "UpDown"].Value := patch["UntilPack"] // 5
		if slot = 1
			CurrentFieldNum := 1
		if CurrentFieldNum = slot
			MainGui["CurrentField"].Text := CurrentField := FieldName%slot%
		nm_TabGatherUnLock()
	} catch as err
		MsgBox err.Message "`nIf saving succeeded, restart the macro to reload the saved profile.", "Gather import failed", 0x1030
	finally Critical wasCritical
}
