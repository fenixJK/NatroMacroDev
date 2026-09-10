#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\RobloxProcesses.ahk"
#Include "%A_ScriptDir%\..\lib\ReconnectLaunch.ahk"

ProcessTests() {
	root := A_ScriptDir "\..", directory := A_Temp "\Natro ROBLOXCORPORATION Ω-" DllCall("GetCurrentProcessId")
	SetWorkingDir root
	DirCreate directory
	jobs := [], observed := 0
	try {
		code := "12345678901234567890123456789012"
		RequireProcess(nm_ReconnectLaunch.Target("deeplink", "LinkCode", code) = "roblox://placeID=1537690962&linkcode=" code, "Canonical deeplink")
		RequireProcess(nm_ReconnectLaunch.Target("browser", "ShareCode", code) = "https://www.roblox.com/share?code=" code "&type=Server", "Canonical browser share")
		RequireProcess(nm_ReconnectLaunch.Target("deeplink", "None", "") = "roblox://placeID=1537690962", "Public target is fixed")
		for bad in ["", 'abc" -new-window', "https://example.invalid/"] {
			try nm_ReconnectLaunch.Target("browser", "LinkCode", bad)
			catch ValueError
				continue
			throw Error("Invalid target code accepted")
		}
		RequireProcess(!nm_RobloxProcesses.IsPlayer("RobloxStudioBeta.exe") && !nm_RobloxProcesses.IsPlayer("RobloxPlayerBeta.exe.bak") && nm_RobloxProcesses.IsPlayer("ROBLOXPLAYERBETA.EXE"), "Exact executable classification")
		RequireProcess(nm_RobloxProcesses.SameUser(-1), "Native current-process owner comparison")
		existing := nm_RobloxProcesses.Find()
		for item in existing
			DllCall("CloseHandle", "Ptr", item.handle)
		RequireProcess(existing.Length = 0, "Native tests require no real Roblox player running")

		DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &before := 0)
		Loop 5 {
			job := nm_OwnedProcessJob(Map("mode", "echo", "text", 'Unicode Ω " & $(not-a-command)'), A_ScriptDir "\ProcessFixture.ahk")
			try RequireProcess(job.Wait() = 42, "Shared-memory request round trip")
			catch as fixtureError {
				DumpProcessJob(job)
				throw fixtureError
			} finally job.Close()
		}
		DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &after := 0)
		RequireProcess(after <= before + 2 && nm_OwnedProcessJob.Jobs.Count = 0, "Worker handles/mappings released across repeated completion")

		job := nm_OwnedProcessJob(Map("kind", "browser", "type", "LinkCode", "code", "invalid"))
		try {
			try job.Wait()
			catch nm_ProcessJobError
				failedAsExpected := true
			RequireProcess(IsSet(failedAsExpected) && NumGet(job.View, 8, "Int") = 2 && NumGet(job.View, 12, "Int") > 0, "Production worker rejects invalid targets without launching")
		} finally job.Close()

		job := nm_OwnedProcessJob(Map("mode", "idle"), A_ScriptDir "\ProcessFixture.ahk")
		jobs.Push(job)
		WaitProcessReady(job)
		RequireProcess(DllCall("DuplicateHandle", "Ptr", -1, "Ptr", job.Process, "Ptr", -1, "PtrP", &observed, "UInt", 0, "Int", false, "UInt", 2), "Keep independent observation handle")
		try job.Wait(0, 100)
		catch nm_ProcessJobError
			timedOut := true
		RequireProcess(IsSet(timedOut), "A real running helper exceeds the deadline")
		job.Close()
		RequireProcess(DllCall("WaitForSingleObject", "Ptr", observed, "UInt", 0) = 0, "Timed-out owned process is terminal before cleanup returns")
		DllCall("CloseHandle", "Ptr", observed), observed := 0

		for name in ["RobloxPlayerBeta.exe", "RobloxStudioBeta.exe"] {
			FileCopy A_AhkPath, directory "\" name
			job := nm_OwnedProcessJob(Map("mode", "idle"), A_ScriptDir "\ProcessFixture.ahk", directory "\" name)
			jobs.Push(job)
			WaitProcessReady(job)
			if name = "RobloxPlayerBeta.exe"
				player := job
			else
				decoy := job
		}
		selected := nm_RobloxProcesses.Find()
		for item in selected
			DllCall("CloseHandle", "Ptr", item.handle)
		RequireProcess(selected.Length = 1 && selected[1].pid = player.Pid, "Native snapshot selects the expected player before cleanup")
		RequireProcess(nm_OwnedProcessJob.Execute(Map("kind", "close")) = 1, "Production cleanup selects only the exact player")
		RequireProcess(!player.Running(), "Verified player process terminated")
		RequireProcess(decoy.Running(), "Studio/Roblox-named command-line decoy survives")
		RequireProcess(nm_OwnedProcessJob.Execute(Map("kind", "close")) = 0, "Repeated cleanup does not target unrelated survivors")
		FileAppend "PASS Windows owned-process and reconnect cleanup integration (" A_PtrSize * 8 "-bit)`n", "*"
	} finally {
		if observed
			DllCall("CloseHandle", "Ptr", observed)
		for job in jobs
			job.Close()
		DirDelete directory, true
	}
}
RequireProcess(condition, message) {
	if !condition
		throw Error(message)
}
WaitProcessReady(job) {
	deadline := DllCall("GetTickCount64", "UInt64") + 20000
	while NumGet(job.View, 8, "Int") != 3 {
		RequireProcess(job.Running() && DllCall("GetTickCount64", "UInt64") < deadline, "Fixture reached its running state")
		Sleep 20
	}
}
DumpProcessJob(job) {
	FileAppend "Worker fixture PID " job.Pid ", running " job.Running() ", channel state " NumGet(job.View, 8, "Int") ", value " NumGet(job.View, 12, "Int") "`n", "*"
	DetectHiddenWindows true
	for hwnd in WinGetList("ahk_pid " job.Pid) {
		FileAppend "Fixture window: " WinGetTitle("ahk_id " hwnd) "`n", "*"
		for control in WinGetControls("ahk_id " hwnd)
			try FileAppend control ": " ControlGetText(control, "ahk_id " hwnd) "`n", "*"
	}
}
try ProcessTests()
catch as processTestError {
	FileAppend "FAIL Windows process integration: " processTestError.Message "`n" processTestError.Stack "`n", "*"
	ExitApp 1
}
ExitApp 0
