#Include "%A_ScriptDir%\..\lib\ContainedProcessJob.ahk"

; Fixed worker script and random channel name are the only command arguments.
; Unlike reconnect launchers, file workers and their children cannot break away.
class nm_PowerShellJob extends nm_ContainedProcessJob {
	__New(request, script) {
		super.__New(request, script, A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe")
		this.StartupMs := DllCall("GetTickCount64", "UInt64") - this.Started
	}
	RequestLimit() => 8000
	Command(executable, script) => '"' executable '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' script '" -Channel "' this.Name '"'
	Status => this.Running() ? 0 : 1
	ProcessID => this.Pid
	Diagnostics() {
		stages := ["not-connected", "connected", "request-parsed", "action-returned", "result-written"]
		phase := this.View ? NumGet(this.View, 16032, "UInt") : 0
		result := Map("stage", phase <= 4 ? stages[phase + 1] : "invalid", "elapsedMs", DllCall("GetTickCount64", "UInt64") - this.Started,
			"startupMs", this.StartupMs, "state", this.View ? NumGet(this.View, 8, "Int") : -1)
		milestones := []
		Loop 4
			milestones.Push(this.View && A_Index <= phase ? (NumGet(this.View, 16032 + A_Index * 4, "UInt") - (this.Started & 0xFFFFFFFF)) & 0xFFFFFFFF : -1)
		result["milestonesMs"] := milestones
		times := Buffer(32, 0)
		if this.Process && DllCall("GetProcessTimes", "Ptr", this.Process, "Ptr", times, "Ptr", times.Ptr + 8, "Ptr", times.Ptr + 16, "Ptr", times.Ptr + 24)
			result["cpuMs"] := (NumGet(times, 16, "UInt64") + NumGet(times, 24, "UInt64")) // 10000
		return result
	}
	Result() {
		if this.Running()
			throw Error("File worker has not completed")
		if !DllCall("GetExitCodeProcess", "Ptr", this.Process, "UIntP", &code := 0) || code != 0
			return Map("ok", false, "reason", "worker")
		resultState := NumGet(this.View, 8, "Int"), reason := NumGet(this.View, 12, "Int")
		if resultState = 1 && reason = 0
			return Map("ok", true)
		reasons := ["worker", "url", "storage", "quota", "network", "http", "size", "timeout"]
		return Map("ok", false, "reason", resultState = 2 && reason >= 0 && reason < reasons.Length ? reasons[reason + 1] : "worker")
	}
}
