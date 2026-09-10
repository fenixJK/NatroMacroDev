TestNativeInlineWorkers() {
	jobsBefore := nm_OwnedProcessJob.Jobs.Count
	otherRuntime := A_ScriptDir "\..\submacros\AutoHotkey" (A_PtrSize = 8 ? "32" : "64") ".exe"
	sentinel := A_Temp "\natro-inline-exit-" DllCall("GetCurrentProcessId") ".txt"
	worker := 0
	try {
		source := '#Requires AutoHotkey v2.0.12`n#SingleInstance Off`nFileAppend "Ω🐝|" A_ScriptDir, "*", "UTF-8-RAW"`n'
		Loop 2000
			source .= "; Large source sent as UTF-8 through owned pipes`n"
		worker := nm_InlineWorker(source, otherRuntime)
		actual := worker.Output(), expected := "Ω🐝|" A_WorkingDir
		if actual != expected {
			actualCodes := "", expectedCodes := ""
			Loop Parse actual
				actualCodes .= Format("{:X} ", Ord(A_LoopField))
			Loop Parse expected
				expectedCodes .= Format("{:X} ", Ord(A_LoopField))
			FileAppend "Inline actual codepoints: " actualCodes "`nExpected: " expectedCodes "`n", "*"
		}
		RequireProcess(actual == expected, "Opposite-architecture generated code preserves Unicode and root stdin include context")
		worker.Close(), worker := 0
		RequireProcess(nm_InlineScripts.Validate('#Requires AutoHotkey v2.0.12`nMsgBox "Must not execute"', otherRuntime) = "", "Production validation parses without executing source")
		RequireProcess(nm_InlineScripts.Validate("broken(`n", otherRuntime) != "", "Production validation returns parse errors")

		source := '#SingleInstance Off`nFileAppend Format("{:70000}", "x"), "*", "UTF-8-RAW"'
		worker := nm_InlineWorker(source, otherRuntime)
		try worker.Output()
		catch
			overflowRejected := true
		RequireProcess(IsSet(overflowRejected), "Output flood is bounded and rejected")
		worker.Close(), worker := 0

		source := '#SingleInstance Off`n#NoTrayIcon`nOnExit((*) => FileAppend("closed", "' sentinel '", "UTF-8-RAW"))`nSleep 60000'
		worker := nm_InlineScripts.Start("bitterberry", source, otherRuntime)
		WaitInlineWindow(worker)
		RequireProcess(worker.ProcessID && worker.Window(), "Generated worker exposes an owned child window")
		RequireProcess(DllCall("IsProcessInJob", "Ptr", worker.Child, "Ptr", worker.Job, "IntP", &owned := 0) && owned, "Generated child belongs to the supervisor's creation-time job")
		nm_InlineScripts.Close("bitterberry"), worker := 0
		RequireProcess(FileExist(sentinel) && FileRead(sentinel) = "closed", "Ordinary worker close runs its exit cleanup")

		worker := nm_InlineScripts.Start("basic_egg", '#SingleInstance Off`n#NoTrayIcon`nOnMessage(0x10, (*) => 0)`nSleep 60000', otherRuntime)
		WaitInlineWindow(worker)
		RequireProcess(DllCall("DuplicateHandle", "Ptr", -1, "Ptr", worker.Child, "Ptr", -1, "PtrP", &observed := 0, "UInt", 0, "Int", false, "UInt", 2), "Retain independent child observation")
		try {
			nm_InlineScripts.Close("basic_egg"), worker := 0
			RequireProcess(DllCall("WaitForSingleObject", "Ptr", observed, "UInt", 0) = 0, "Ignored close is followed by confirmed job termination")
		} finally DllCall("CloseHandle", "Ptr", observed)
		TestInlineOwnerCrash()
		TestInlineRegistry(otherRuntime)
	} finally {
		if worker
			worker.Close()
		nm_InlineScripts.CloseAll()
		if FileExist(sentinel)
			FileDelete sentinel
	}
	RequireProcess(nm_OwnedProcessJob.Jobs.Count = jobsBefore && nm_InlineScripts.Workers.Count = 0, "Generated worker registry and job ownership release")
	FileAppend "PASS Windows generated worker pipes and ownership (" A_PtrSize * 8 "-bit with opposite child)`n", "*"
}
WaitInlineWindow(worker) {
	deadline := DllCall("GetTickCount64", "UInt64") + 20000
	while !worker.Window() {
		RequireProcess(worker.Running() && DllCall("GetTickCount64", "UInt64") < deadline, "Generated child initializes its script window")
		Sleep 20
	}
	; The test sources register their close handlers in their auto-execute section.
	Sleep 100
}
TestInlineRegistry(executable) {
	source := '#SingleInstance Off`n#NoTrayIcon`nSleep 60000'
	first := nm_InlineScripts.Start("priority_gui", source, executable)
	WaitInlineWindow(first)
	RequireProcess(DllCall("DuplicateHandle", "Ptr", -1, "Ptr", first.Child, "Ptr", -1, "PtrP", &observed := 0, "UInt", 0, "Int", false, "UInt", 2), "Observe replaced role")
	try {
		replacement := nm_InlineScripts.Start("priority_gui", source, executable)
		RequireProcess(DllCall("WaitForSingleObject", "Ptr", observed, "UInt", 0) = 0 && replacement != first, "Replacement confirms previous role termination")
	} finally DllCall("CloseHandle", "Ptr", observed)
	nm_InlineScripts.Close("priority_gui")
	worker := nm_InlineScripts.Start("walk", '#SingleInstance Off`nExitApp 7', executable)
	deadline := DllCall("GetTickCount64", "UInt64") + 20000
	while worker.Running() {
		RequireProcess(DllCall("GetTickCount64", "UInt64") < deadline, "Failed movement worker exits")
		Sleep 20
	}
	try nm_InlineScripts.Start("walk", source, executable)
	catch
		failurePropagated := true
	RequireProcess(IsSet(failurePropagated) && !nm_InlineScripts.Workers.Has("walk"), "Failed movement is surfaced before replacement")
	try nm_InlineScripts.Start("unknown", source, executable)
	catch ValueError
		roleRejected := true
	RequireProcess(IsSet(roleRejected), "Unknown role rejected")
	try nm_InlineWorker(Format("{:1048577}", "x"), executable)
	catch ValueError
		sizeRejected := true
	RequireProcess(IsSet(sizeRejected), "Oversized source rejected before launch")
}
TestInlineOwnerCrash() {
	parent := 0, supervisorHandle := 0, generatedHandle := 0
	try {
		parent := nm_OwnedProcessJob(Map("mode", "inline_owner"), A_ScriptDir "\ProcessFixture.ahk")
		WaitProcessReady(parent)
		supervisorHandle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", NumGet(parent.View, 12, "Int"), "Ptr")
		generatedHandle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", NumGet(parent.View, 16, "Int"), "Ptr")
		for handle in [supervisorHandle, generatedHandle]
			RequireProcess(handle && DllCall("IsProcessInJob", "Ptr", handle, "Ptr", parent.Job, "IntP", &owned := 0) && !owned, "Inline processes are independent of harness ownership")
		DllCall("TerminateProcess", "Ptr", parent.Process, "UInt", 77)
		RequireProcess(DllCall("WaitForSingleObject", "Ptr", parent.Process, "UInt", 2000) = 0, "Inline owner crash is terminal")
		for handle in [supervisorHandle, generatedHandle]
			RequireProcess(DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 2000) = 0, "Owner crash terminates supervisor and generated child")
	} finally {
		for handle in [supervisorHandle, generatedHandle] {
			if handle {
				DllCall("TerminateProcess", "Ptr", handle, "UInt", 1)
				DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 2000)
				DllCall("CloseHandle", "Ptr", handle)
			}
		}
		if parent
			parent.Close()
	}
}
