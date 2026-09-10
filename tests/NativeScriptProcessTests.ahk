TestNativeScriptProcesses() {
	directory := A_Temp "\natro-watchdog-" DllCall("GetCurrentProcessId"), processes := []
	DirCreate directory "\selected"
	DirCreate directory "\decoy"
	for folder in ["selected", "decoy"]
		FileCopy A_ScriptDir "\ScriptProcessFixture.ahk", directory "\" folder "\natro_macro.ahk"
	FileCopy A_AhkPath, directory "\other-runtime.exe"
	DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &before := 0)
	try {
		selectedScript := directory "\selected\natro_macro.ahk"
		selected := nm_ScriptProcess.Launch(selectedScript, A_AhkPath, [1], "Natro fixture"), processes.Push(selected)
		decoy := nm_ScriptProcess.Launch(directory "\decoy\natro_macro.ahk", A_AhkPath, [0], "Natro fixture"), processes.Push(decoy)
		otherRuntime := nm_ScriptProcess.Launch(selectedScript, directory "\other-runtime.exe", [0], "Natro fixture"), processes.Push(otherRuntime)
		deadline := DllCall("GetTickCount64", "UInt64") + 20000
		while !decoy.Ready() || !otherRuntime.Ready() {
			RequireProcess(DllCall("GetTickCount64", "UInt64") < deadline, "Decoy fixture GUIs initialize")
			Sleep 20
		}
		RequireProcess(!selected.Ready(), "Another process's matching GUI cannot satisfy startup readiness")
		captured := nm_ScriptProcess.Find(selectedScript, A_AhkPath)
		if captured.Length != 1 || captured[1].Pid != selected.Pid {
			FileAppend "Script discovery count=" captured.Length " expected=" selectedScript " runtime=" A_AhkPath " version=" A_AhkVersion "`n", "*"
			DetectHiddenWindows true
			for process in processes {
				imagePath := Buffer(65536), imageSize := 32768
				DllCall("QueryFullProcessImageNameW", "Ptr", process.Handle, "UInt", 0, "Ptr", imagePath, "UIntP", &imageSize)
				for hwnd in WinGetList("ahk_class AutoHotkey ahk_pid " process.Pid)
					FileAppend "Fixture PID=" process.Pid " title=" WinGetTitle("ahk_id " hwnd) " runtime=" StrGet(imagePath) "`n", "*"
			}
		}
		try RequireProcess(captured.Length = 1 && captured[1].Pid = selected.Pid, "Discovery requires exact script path and runtime image")
		finally {
			for item in captured
				item.Release()
		}
		nm_ScriptProcess.Stop(selectedScript, A_AhkPath)
		RequireProcess(!selected.Running(), "Watchdog cleanup terminates the verified script through its retained handle")
		RequireProcess(decoy.Running() && otherRuntime.Running(), "Same-name script and different-runtime decoys survive cleanup")
		RequireProcess(decoy.Ready(), "Matching owned GUI is a ready application")
		try nm_ScriptProcess.Launch(selectedScript, directory "\missing.exe")
		catch
			launchRejected := true
		RequireProcess(IsSet(launchRejected), "Native launch failure propagates")
	} finally {
		for process in processes {
			process.Close()
			process.Release()
		}
		DirDelete directory, true
	}
	DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &after := 0)
	RequireProcess(after <= before + 2, "Watchdog process handles released after discovery and failed launch")
	FileAppend "PASS Windows watchdog script identity and readiness (" A_PtrSize * 8 "-bit)`n", "*"
}
