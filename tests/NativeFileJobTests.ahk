TestNativeFileJobs() {
	initialJobs := nm_OwnedProcessJob.Jobs.Count
	DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &before := 0)
	for mode in ["echo", "failure", "silent"] {
		fileJob := nm_PowerShellJob(Map("mode", mode, "text", 'Unicode Ω " & $(not-a-command)'), A_ScriptDir "\PowerShellFixture.ps1")
		try {
			deadline := DllCall("GetTickCount64", "UInt64") + 20000
			while fileJob.Running() {
				RequireProcess(DllCall("GetTickCount64", "UInt64") < deadline, "Native file fixture completes")
				Sleep 20
			}
			result := fileJob.Result()
			RequireProcess(result["ok"] = (mode = "echo"), "Only a complete successful file result is accepted")
			if mode != "echo"
				RequireProcess(result["reason"] = "worker", "Failure and absent results expose only a fixed reason")
			diagnostic := fileJob.Diagnostics()
			RequireProcess(diagnostic["stage"] = (mode = "echo" ? "result-written" : "request-parsed"), "Diagnostics distinguish completed action from exception or premature exit")
			RequireProcess(diagnostic["milestonesMs"][1] >= 0 && diagnostic["milestonesMs"][2] >= diagnostic["milestonesMs"][1], "Worker progress uses the parent's monotonic clock")
			RequireProcess(diagnostic["startupMs"] >= 0 && diagnostic["cpuMs"] >= 0, "Worker creation and CPU timings are available")
		} finally fileJob.Close()
	}
	DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &after := 0)
	RequireProcess(after <= before + 2 && nm_OwnedProcessJob.Jobs.Count = initialJobs, "PowerShell completion releases native handles")

	; A real PowerShell descendant must stop before cleanup returns.
	fileJob := nm_PowerShellJob(Map("mode", "idle_child", "executable", A_AhkPath, "script", A_ScriptDir "\ProcessSurvivor.ahk"), A_ScriptDir "\PowerShellFixture.ps1")
	childHandle := 0
	try {
		WaitProcessReady(fileJob)
		RequireProcess(fileJob.Diagnostics()["stage"] = "request-parsed", "A stalled action retains its last confirmed stage")
		childHandle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", NumGet(fileJob.View, 12, "Int"), "Ptr")
		RequireProcess(childHandle && DllCall("IsProcessInJob", "Ptr", childHandle, "Ptr", fileJob.Job, "IntP", &owned := 0) && owned, "File worker descendants remain in its job")
		fileJob.Close()
		RequireProcess(DllCall("WaitForSingleObject", "Ptr", childHandle, "UInt", 0) = 0, "Cleanup confirms descendant termination before returning")
	} finally {
		fileJob.Close()
		if childHandle
			DllCall("CloseHandle", "Ptr", childHandle)
	}

	parent := 0, workerHandle := 0, descendantHandle := 0
	try {
		parent := nm_OwnedProcessJob(Map("mode", "file_owner"), A_ScriptDir "\ProcessFixture.ahk")
		WaitProcessReady(parent)
		workerHandle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", NumGet(parent.View, 12, "Int"), "Ptr")
		descendantHandle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", NumGet(parent.View, 16, "Int"), "Ptr")
		for handle in [workerHandle, descendantHandle] {
			RequireProcess(handle && DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 0) = 258, "File process alive before owner crash")
			RequireProcess(DllCall("IsProcessInJob", "Ptr", handle, "Ptr", parent.Job, "IntP", &outerOwned := 0) && !outerOwned, "Harness job does not accidentally own file descendants")
		}
		RequireProcess(DllCall("TerminateProcess", "Ptr", parent.Process, "UInt", 77), "Crash the file worker owner without exit callbacks")
		RequireProcess(DllCall("WaitForSingleObject", "Ptr", parent.Process, "UInt", 2000) = 0, "File worker owner is terminal")
		for handle in [workerHandle, descendantHandle]
			RequireProcess(DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 2000) = 0, "Kernel stops file worker and descendant after owner crash")
	} finally {
		for handle in [workerHandle, descendantHandle] {
			if handle {
				DllCall("TerminateProcess", "Ptr", handle, "UInt", 1)
				DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 2000)
				DllCall("CloseHandle", "Ptr", handle)
			}
		}
		if parent
			parent.Close()
	}
	RequireProcess(nm_OwnedProcessJob.Jobs.Count = initialJobs, "File crash fixtures release all owned jobs")
	FileAppend "PASS Windows file worker shared memory and crash ownership (" A_PtrSize * 8 "-bit)`n", "*"
}
