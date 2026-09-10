#Include "%A_ScriptDir%\..\lib\ContainedProcessJob.ahk"

; Fixed worker script and random channel name are the only command arguments.
; Unlike reconnect launchers, file workers and their children cannot break away.
class nm_PowerShellJob extends nm_ContainedProcessJob {
	__New(request, script) => super.__New(request, script, A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe")
	RequestLimit() => 8000
	Command(executable, script) => '"' executable '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' script '" -Channel "' this.Name '"'
	Status => this.Running() ? 0 : 1
	ProcessID => this.Pid
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
