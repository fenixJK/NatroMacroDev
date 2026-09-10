#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\GatherProfiles.ahk"
SetWorkingDir A_Args[1]
try {
	FileAppend "ready", "gather-ready"
	if A_Args[2] = "write" {
		nm_GatherStore.WriteKey("Concurrent", 99)
		FileAppend "done", "gather-done"
	} else {
		reads := 0
		while !FileExist("gather-stop") {
			section := nm_GatherStore.ReadSection()
			if !((section["FieldName1"] = "Sunflower" && section["FieldPattern1"] = "Squares") || (section["FieldName1"] = "Rose" && section["FieldPattern1"] = "Lines"))
				throw Error("Mixed field/pattern snapshot")
			reads++
			Sleep 1
		}
		if !reads
			throw Error("No concurrent section reads")
		FileAppend "PASS " reads " coherent section reads`n", "*"
	}
} catch as err {
	FileAppend err.Message "`n" err.Stack, "*"
	ExitApp 1
}
ExitApp 0
