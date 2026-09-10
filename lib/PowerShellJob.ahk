#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"

; Fixed worker script and random channel name are the only command arguments.
; Unlike reconnect launchers, file workers and their children cannot break away.
class nm_PowerShellJob extends nm_OwnedProcessJob {
	__New(request, script) => super.__New(request, script, A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe")
	RequestLimit() => 8000
	LimitFlags() => 0x2000
	Command(executable, script) => '"' executable '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' script '" -Channel "' this.Name '"'
	Status => this.Running() ? 0 : 1
	ProcessID => this.Pid
	Result() {
		if this.Running()
			throw Error("File worker has not completed")
		if !DllCall("GetExitCodeProcess", "Ptr", this.Process, "UIntP", &code := 0) || code != 0
			return Map("ok", false, "reason", "worker")
		state := NumGet(this.View, 8, "Int"), reason := NumGet(this.View, 12, "Int")
		if state = 1 && reason = 0
			return Map("ok", true)
		reasons := ["worker", "url", "storage", "quota", "network", "http", "size", "timeout"]
		return Map("ok", false, "reason", state = 2 && reason >= 0 && reason < reasons.Length ? reasons[reason + 1] : "worker")
	}
	Terminate() {
		if !DllCall("TerminateJobObject", "Ptr", this.Job, "UInt", 1)
			throw Error("Could not stop file worker job")
	}
	Close() {
		if this.Job {
			this.Terminate()
			deadline := DllCall("GetTickCount64", "UInt64") + 2000
			accounting := Buffer(48, 0)
			Loop {
				if !DllCall("QueryInformationJobObject", "Ptr", this.Job, "Int", 1, "Ptr", accounting, "UInt", accounting.Size, "Ptr", 0)
					throw Error("Could not observe file worker cleanup")
				if NumGet(accounting, 40, "UInt") = 0
					break
				if DllCall("GetTickCount64", "UInt64") >= deadline
					throw Error("File worker job has not stopped; temporary files retained")
				Sleep 20
			}
		}
		; The base class confirms termination using the retained process handle.
		super.Close()
	}
}
