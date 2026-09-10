TestNativePriorityNotifications() {
	directory := A_Temp "\natro-priority-" DllCall("GetCurrentProcessId"), processes := []
	root := directory "\selected", otherRoot := directory "\other"
	DirCreate root "\submacros"
	DirCreate otherRoot "\submacros"
	before := WatchdogFixtureHandleCount()
	try {
		for bits in [32, 64]
			FileCopy A_ScriptDir "\..\submacros\AutoHotkey" bits ".exe", root "\submacros\AutoHotkey" bits ".exe"
		for name in ["natro_macro", "Status", "personal"]
			FileCopy A_ScriptDir "\PriorityNotifyFixture.ahk", root "\submacros\" name ".ahk"
		FileCopy A_ScriptDir "\PriorityNotifyFixture.ahk", otherRoot "\submacros\Status.ahk"
		fixtures := [[root "\submacros\natro_macro.ahk", root "\submacros\AutoHotkey32.exe"],
			[root "\submacros\Status.ahk", root "\submacros\AutoHotkey64.exe"],
			[root "\submacros\personal.ahk", root "\submacros\AutoHotkey32.exe"],
			[otherRoot "\submacros\Status.ahk", root "\submacros\AutoHotkey64.exe"],
			[root "\submacros\Status.ahk", A_AhkPath]]
		for spec in fixtures
			processes.Push(nm_ScriptProcess.Launch(spec[1], spec[2], [], "Natro priority fixture"))
		deadline := DllCall("GetTickCount64", "UInt64") + 20000
		for process in processes
			while !process.Ready() {
				RequireProcess(process.Running() && DllCall("GetTickCount64", "UInt64") < deadline, "Priority fixture becomes ready")
				Sleep 20
			}
		nm_PrioritySettings.Notify(root)
		for process in processes
			PostMessage 0x5557, 0, 0,, "ahk_id " process.Ready()
		for index, process in processes {
			path := fixtures[index][1] "." process.Pid
			while !FileExist(path ".barrier") {
				RequireProcess(process.Running() && DllCall("GetTickCount64", "UInt64") < deadline, "Notification queue reaches barrier")
				Sleep 20
			}
			if index <= 2
				RequireProcess(FileExist(path ".notice") && FileRead(path ".notice") = "366|0`n", "Exact installation and runtime receives one invalidation: fixture " index ", received " (FileExist(path ".notice") ? FileRead(path ".notice") : "<missing>"))
			else
				RequireProcess(!FileExist(path ".notice"), "Personal script, other installation and wrong runtime receive no priority notice")
		}
	} finally {
		for process in processes {
			process.Close()
			process.Release()
		}
		try RequireProcess(WatchdogFixtureHandleCount() <= before + 2, "Priority notification releases discovery handles")
		finally DirDelete directory, true
	}
	FileAppend "PASS Windows priority notifications target exact installation and runtimes (" A_PtrSize * 8 "-bit)`n", "*"
}
