TestGatherProfiles() {
	fields := ["Sunflower", "Rose"], patterns := ["Squares", "Lines", 'Quoted "pattern"']
	values := Map("Name", "Rose", "Pattern", "Lines", "DriftCheck", 1, "PatternInvertFB", 0, "PatternInvertLR", 1,
		"PatternReps", 9, "PatternShift", 1, "PatternSize", "XL", "ReturnType", "Reset", "RotateDirection", "Left",
		"RotateTimes", 4, "SprinklerDist", 10, "SprinklerLoc", "Upper Left", "UntilMins", 9999, "UntilPack", 100)
	encoded := nm_GatherProfiles.Export(values, fields, patterns)
	decoded := nm_GatherProfiles.Parse(encoded, fields, patterns)
	for key, value in values
		AssertEqual(decoded[key], value, "Gather profile round trip: " key)
	decoded := nm_GatherProfiles.Parse("{`n" '"Name":"rose", "PatternSize":"xl", "PatternShift":true, "UntilMins":"0010"' "`n}", fields, patterns)
	Assert(decoded["Name"] == "Rose" && decoded["PatternSize"] == "XL" && decoded["PatternShift"] = 1 && decoded["UntilMins"] = 10, "Legacy multiline, case variants, boolean flags and integer strings normalize")
	values["Pattern"] := 'Quoted "pattern"'
	AssertEqual(nm_GatherProfiles.Parse(nm_GatherProfiles.Export(values, fields, patterns), fields, patterns)["Pattern"], values["Pattern"], "JSON escaping preserves installed pattern names")
	for bad in ['{}', '[]', '{"Name":"Rose","oops":1}', '{"Name":"Rose","Name":"Sunflower"}', '{"Name":"Rose","name":"Sunflower"}',
		'{"schemaVersion":2,"Name":"Rose"}', '{"Name":"missing"}', '{"Pattern":"uninstalled"}', '{"Name":null}', '{"Name":["Rose"]}',
		'{"UntilPack":7}', '{"RotateTimes":0}', '{"PatternReps":10}', '{"UntilMins":10000}', '{"UntilMins":true}', '{"UntilPack":5.5}',
		'{"Name":"Rose",}', '{"Name":"Rose"} trailing', '{"Name":"Rose", /*comment*/ "Pattern":"Lines"}', '{"PatternSize":"XL' "`n" '"}']
		AssertThrows(() => nm_GatherProfiles.Parse(bad, fields, patterns), "Invalid complete profile is rejected: " bad)
	AssertThrows(() => nm_GatherProfiles.Parse(StrReplace(Format("{:17000}", "x"), " ", "x"), fields, patterns), "Import text is bounded")
	IniWrite "Sunflower", nm_GatherStore.Path, "Gather", "FieldName1"
	IniWrite "Squares", nm_GatherStore.Path, "Gather", "FieldPattern1"
	IniWrite "keep", nm_GatherStore.Path, "Gather", "UnrelatedGather"
	IniWrite 3, nm_GatherStore.Path, "Gather", "CurrentFieldNum"
	IniWrite "private-state", nm_GatherStore.Path, "OtherSection", "Keep"
	before := FileRead(nm_GatherStore.Path)
	try {
		patch := nm_GatherProfiles.Parse('{"Name":"Rose","PatternReps":0}', fields, patterns)
		nm_GatherStore.Commit(1, patch)
		throw Error("Invalid late property was accepted")
	} catch ValueError {
		AssertEqual(FileRead(nm_GatherStore.Path), before, "Late validation failure makes no persistent changes")
	}
	patch := nm_GatherProfiles.Parse('{"Name":"Rose","Pattern":"Lines","UntilPack":75}', fields, patterns)
	nm_GatherStore.Commit(1, patch)
	section := nm_GatherStore.ReadSection()
	Assert(section["FieldName1"] = "Rose" && section["FieldPattern1"] = "Lines" && section["FieldUntilPack1"] = 75, "Native section commit publishes the complete patch")
	AssertEqual(section["UnrelatedGather"], "keep", "Unspecified Gather state survives")
	AssertEqual(section["CurrentFieldNum"], 1, "Slot-one import selects slot one in the same section commit")
	AssertEqual(IniRead(nm_GatherStore.Path, "OtherSection", "Keep"), "private-state", "Other sections survive without whole-file replacement")
	before := FileRead(nm_GatherStore.Path)
	FileSetAttrib "+R", nm_GatherStore.Path
	try {
		AssertDeliveryError(() => nm_GatherStore.Commit(1, Map("Name", "Sunflower")), "Native write failure rejects import")
		AssertEqual(FileRead(nm_GatherStore.Path), before, "Rejected native write leaves existing settings intact")
	} finally FileSetAttrib "-R", nm_GatherStore.Path
	TestGatherStoreProcesses()
}

TestGatherStoreProcesses() {
	handle := nm_GatherStore.Acquire(), worker := 0
	try {
		worker := ComObject("WScript.Shell").Exec('"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptDir '\GatherStoreWorker.ahk" "' A_WorkingDir '" write')
		start := A_TickCount
		while !FileExist("gather-ready") && A_TickCount - start < 10000
			Sleep 10
		Assert(FileExist("gather-ready"), "Independent writer reached the shared lock")
		Assert(!FileExist("gather-done"), "Independent writer cannot bypass an import's lock")
		DllCall("CloseHandle", "Ptr", handle), handle := 0
		while worker.Status = 0 && A_TickCount - start < 10000
			Sleep 10
		Assert(worker.Status != 0 && worker.ExitCode = 0, "Independent writer finishes after release")
		AssertEqual(IniRead(nm_GatherStore.Path, "Gather", "Concurrent"), 99, "Independent update survives")
		FileDelete "gather-ready"
		worker := ComObject("WScript.Shell").Exec('"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptDir '\GatherStoreWorker.ahk" "' A_WorkingDir '" read')
		start := A_TickCount
		while !FileExist("gather-ready") && A_TickCount - start < 10000
			Sleep 10
		Assert(FileExist("gather-ready"), "Independent section reader started")
		Loop 100 {
			nm_GatherStore.Commit(1, Mod(A_Index, 2) ? Map("Name", "Sunflower", "Pattern", "Squares") : Map("Name", "Rose", "Pattern", "Lines"))
			Sleep 1
		}
		FileAppend "stop", "gather-stop"
		while worker.Status = 0 && A_TickCount - start < 10000
			Sleep 10
		Assert(worker.Status != 0 && worker.ExitCode = 0, "Independent reader never observes half of a committed field/pattern pair: " (worker.Status != 0 ? worker.StdOut.ReadAll() : "still running"))
	} finally {
		if handle
			DllCall("CloseHandle", "Ptr", handle)
		if worker && worker.Status = 0
			worker.Terminate()
	}
}
