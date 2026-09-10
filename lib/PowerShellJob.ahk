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
		resultState := NumGet(this.View, 8, "Int"), reason := NumGet(this.View, 12, "Int")
		if resultState = 1 && reason = 0
			return Map("ok", true)
		reasons := ["worker", "url", "storage", "quota", "network", "http", "size", "timeout"]
		return Map("ok", false, "reason", resultState = 2 && reason >= 0 && reason < reasons.Length ? reasons[reason + 1] : "worker")
	}
	Terminate() {
		this.CaptureMembers()
		if !DllCall("TerminateJobObject", "Ptr", this.Job, "UInt", 1)
			throw Error("Could not stop file worker job")
	}
	CaptureMembers() {
		if !this.HasOwnProp("Members")
			this.Members := Map()
		for pid, handle in this.Members.Clone() {
			if DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 0) = 0 {
				DllCall("CloseHandle", "Ptr", handle)
				this.Members.Delete(pid)
			}
		}
		; Hold handles to observed members before termination. Accounting can
		; reach zero before an exiting descendant's process handle is signaled.
		list := Buffer(8 + 256 * A_PtrSize, 0)
		if !DllCall("QueryInformationJobObject", "Ptr", this.Job, "Int", 3, "Ptr", list, "UInt", list.Size, "Ptr", 0)
			throw Error("Could not capture file worker job members")
		count := NumGet(list, 4, "UInt")
		if count > 256 || NumGet(list, 0, "UInt") > count
			throw Error("Too many file worker job members")
		Loop count {
			pid := NumGet(list, 8 + (A_Index - 1) * A_PtrSize, "UPtr")
			if this.Members.Has(pid)
				continue
			if this.Members.Count >= 256
				throw Error("Too many observed file worker descendants")
			handle := DllCall("OpenProcess", "UInt", 0x101000, "Int", false, "UInt", pid, "Ptr")
			if !handle {
				if A_LastError = 87
					continue
				throw Error("Could not observe file worker descendant")
			}
			try {
				if !DllCall("IsProcessInJob", "Ptr", handle, "Ptr", this.Job, "IntP", &owned := 0)
					throw Error("Could not verify file worker descendant")
				if owned
					this.Members[pid] := handle, handle := 0
			} finally {
				if handle
					DllCall("CloseHandle", "Ptr", handle)
			}
		}
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
				this.CaptureMembers()
				if DllCall("GetTickCount64", "UInt64") >= deadline
					throw Error("File worker job has not stopped; temporary files retained")
				Sleep 20
			}
			for , handle in this.Members {
				remaining := Max(0, deadline - DllCall("GetTickCount64", "UInt64"))
				if DllCall("WaitForSingleObject", "Ptr", handle, "UInt", remaining) != 0
					throw Error("File worker descendant has not terminated; temporary files retained")
			}
		}
		; The base class confirms termination using the retained process handle.
		super.Close()
		if this.HasOwnProp("Members") {
			for , handle in this.Members
				DllCall("CloseHandle", "Ptr", handle)
			this.Members.Clear()
		}
	}
}
