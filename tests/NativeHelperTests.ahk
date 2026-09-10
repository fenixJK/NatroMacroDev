TestNativeHelperCleanup() {
	directory := A_Temp "\natro-helper-" DllCall("GetCurrentProcessId"), processes := []
	root := directory "\selected", otherRoot := directory "\other"
	for folder in [root, otherRoot]
		DirCreate folder "\submacros"
	for name in ["Status", "Heartbeat", "personal"]
		FileCopy A_ScriptDir "\ScriptProcessFixture.ahk", root "\submacros\" name ".ahk"
	FileCopy A_ScriptDir "\ScriptProcessFixture.ahk", otherRoot "\submacros\Status.ahk"
	before := WatchdogFixtureHandleCount()
	try {
		for path in [root "\submacros\Status.ahk", root "\submacros\Heartbeat.ahk", root "\submacros\personal.ahk", otherRoot "\submacros\Status.ahk"]
			processes.Push(nm_ScriptProcess.Launch(path, A_AhkPath, [0], "Natro fixture"))
		deadline := DllCall("GetTickCount64", "UInt64") + 20000
		for process in processes {
			while !process.Ready() {
				RequireProcess(process.Running() && DllCall("GetTickCount64", "UInt64") < deadline, "Cleanup fixture becomes ready")
				Sleep 20
			}
		}
		heartbeat := nm_HelperScripts.Window(root, "Heartbeat", A_AhkPath)
		RequireProcess(heartbeat != 0, "Heartbeat is located by this installation's full path")
		nm_HelperScripts.Close(root, [A_AhkPath, A_AhkPath], heartbeat)
		RequireProcess(!processes[1].Running(), "Known helper is stopped even when it ignores graceful close")
		RequireProcess(processes[2].Running() && processes[3].Running() && processes[4].Running(), "Retained heartbeat, personal script, and another installation survive")
		nm_HelperScripts.Close(root, [A_AhkPath])
		RequireProcess(!processes[2].Running(), "Full cleanup stops the retained heartbeat")
		RequireProcess(processes[3].Running() && processes[4].Running(), "Full cleanup preserves unrelated same-runtime scripts")
	} finally {
		for process in processes {
			process.Close()
			process.Release()
		}
		try RequireProcess(WatchdogFixtureHandleCount() <= before + 2, "Helper discovery and cleanup release process handles")
		finally DirDelete directory, true
	}
	FileAppend "PASS Windows helper cleanup preserves unrelated scripts (" A_PtrSize * 8 "-bit)`n", "*"
}
