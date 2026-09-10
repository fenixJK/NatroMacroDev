#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"

; Kernel ownership contains the helper and descendants, including parent crashes.
class nm_ContainedProcessJob extends nm_OwnedProcessJob {
	LimitFlags() => 0x2000
	Terminate() {
		this.CaptureMembers()
		if !DllCall("TerminateJobObject", "Ptr", this.Job, "UInt", 1)
			throw Error("Could not stop contained worker job")
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
			throw Error("Could not capture contained worker job members")
		count := NumGet(list, 4, "UInt")
		if count > 256 || NumGet(list, 0, "UInt") > count
			throw Error("Too many contained worker job members")
		Loop count {
			pid := NumGet(list, 8 + (A_Index - 1) * A_PtrSize, "UPtr")
			if this.Members.Has(pid)
				continue
			if this.Members.Count >= 256
				throw Error("Too many observed contained worker descendants")
			handle := DllCall("OpenProcess", "UInt", 0x101000, "Int", false, "UInt", pid, "Ptr")
			if !handle {
				if A_LastError = 87
					continue
				throw Error("Could not observe contained worker descendant")
			}
			try {
				if !DllCall("IsProcessInJob", "Ptr", handle, "Ptr", this.Job, "IntP", &owned := 0)
					throw Error("Could not verify contained worker descendant")
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
					throw Error("Could not observe contained worker cleanup")
				if NumGet(accounting, 40, "UInt") = 0
					break
				this.CaptureMembers()
				if DllCall("GetTickCount64", "UInt64") >= deadline
					throw Error("Contained worker job has not stopped; temporary files retained")
				Sleep 20
			}
			for , handle in this.Members {
				remaining := Max(0, deadline - DllCall("GetTickCount64", "UInt64"))
				if DllCall("WaitForSingleObject", "Ptr", handle, "UInt", remaining) != 0
					throw Error("Contained worker descendant has not terminated; temporary files retained")
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
