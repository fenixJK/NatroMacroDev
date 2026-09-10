; Requests live in a private named mapping, never in shell text or temporary files.
; A kernel job owns each helper from process creation, including parent crashes.
; Children launched by a helper deliberately break away and survive its cleanup.
class nm_ProcessJobError extends Error {
}
class nm_OwnedProcessJob {
	static Jobs := Map()
	static Initialized := false
	static Bytes := 16384
	__New(request, script := "", executable := "") {
		this.Process := this.Mapping := this.View := this.Job := 0
		attributesReady := false
		this.Started := DllCall("GetTickCount64", "UInt64")
		if !nm_OwnedProcessJob.Initialized {
			OnExit(ObjBindMethod(nm_OwnedProcessJob, "CloseAll"))
			nm_OwnedProcessJob.Initialized := true
		}
		encoded := JSON.stringify(request)
		if StrLen(encoded) > this.RequestLimit()
			throw ValueError("Process request is too large")
		try {
			guid := Buffer(16), text := Buffer(78)
			if DllCall("ole32\CoCreateGuid", "Ptr", guid, "Int")
				throw OSError()
			DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", text, "Int", 39)
			this.Name := "Local\NatroReconnect-" RegExReplace(StrGet(text), "[{}-]")
			this.Mapping := DllCall("CreateFileMappingW", "Ptr", -1, "Ptr", 0, "UInt", 4, "UInt", 0, "UInt", nm_OwnedProcessJob.Bytes, "Str", this.Name, "Ptr")
			if !this.Mapping || A_LastError = 183
				throw Error("Could not create a unique process channel")
			this.View := DllCall("MapViewOfFile", "Ptr", this.Mapping, "UInt", 0xF001F, "UInt", 0, "UInt", 0, "UPtr", nm_OwnedProcessJob.Bytes, "Ptr")
			if !this.View
				throw OSError()
			NumPut("UInt", 1, "UInt", StrLen(encoded), "Int", 0, "Int", 0, this.View)
			StrPut(encoded, this.View + 16, StrLen(encoded) + 1, "UTF-16")
			if !script
				script := A_WorkingDir "\submacros\reconnect-worker.ahk"
			if !executable
				executable := A_AhkPath
			command := this.Command(executable, script)
			mutableCommand := Buffer((StrLen(command) + 1) * 2)
			StrPut(command, mutableCommand, "UTF-16")
			this.Job := DllCall("CreateJobObjectW", "Ptr", 0, "Ptr", 0, "Ptr")
			if !this.Job
				throw OSError()
			limits := Buffer(A_PtrSize = 8 ? 144 : 112, 0)
			; KILL_ON_JOB_CLOSE | SILENT_BREAKAWAY_OK. The helper stays owned;
			; browser/game processes it creates are not killed with the helper.
			NumPut("UInt", this.LimitFlags(), limits, 16)
			if !DllCall("SetInformationJobObject", "Ptr", this.Job, "Int", 9, "Ptr", limits, "UInt", limits.Size)
				throw OSError()
			DllCall("InitializeProcThreadAttributeList", "Ptr", 0, "UInt", 1, "UInt", 0, "UPtrP", &attributeBytes := 0)
			if !attributeBytes || attributeBytes > 65536
				throw Error("Invalid process attribute allocation")
			attributes := Buffer(attributeBytes)
			if !DllCall("InitializeProcThreadAttributeList", "Ptr", attributes, "UInt", 1, "UInt", 0, "UPtrP", &attributeBytes)
				throw OSError()
			attributesReady := true, jobList := Buffer(A_PtrSize)
			NumPut("Ptr", this.Job, jobList)
			; JOB_LIST assigns ownership atomically with CreateProcessW. There is
			; no interval where a started or suspended helper is outside the job.
			if !DllCall("UpdateProcThreadAttribute", "Ptr", attributes, "UInt", 0, "UPtr", 0x2000D,
				"Ptr", jobList, "UPtr", jobList.Size, "Ptr", 0, "Ptr", 0)
				throw OSError()
			startup := Buffer(A_PtrSize = 8 ? 112 : 72, 0), info := Buffer(A_PtrSize * 2 + 8, 0)
			NumPut("UInt", startup.Size, startup), NumPut("UInt", 1, startup, A_PtrSize = 8 ? 60 : 44)
			NumPut("Ptr", attributes.Ptr, startup, A_PtrSize = 8 ? 104 : 68)
			if !DllCall("CreateProcessW", "Str", executable, "Ptr", mutableCommand, "Ptr", 0, "Ptr", 0, "Int", false,
				"UInt", 0x08080000, "Ptr", 0, "Str", A_WorkingDir, "Ptr", startup, "Ptr", info)
				throw OSError()
			this.Process := NumGet(info, 0, "Ptr"), this.Pid := NumGet(info, A_PtrSize * 2, "UInt")
			DllCall("CloseHandle", "Ptr", NumGet(info, A_PtrSize, "Ptr"))
			nm_OwnedProcessJob.Jobs[this.Pid] := this
		} catch {
			this.Close()
			throw nm_ProcessJobError("Could not start an owned process helper (Windows 10 or newer is required)")
		} finally {
			if attributesReady
				DllCall("DeleteProcThreadAttributeList", "Ptr", attributes)
		}
	}
	RequestLimit() => 4096
	LimitFlags() => 0x3000
	Command(executable, script) => '"' executable '" /ErrorStdOut=UTF-8 "' script '" "' this.Name '"'
	Running() {
		status := DllCall("WaitForSingleObject", "Ptr", this.Process, "UInt", 0, "UInt")
		if status != 0 && status != 258
			throw nm_ProcessJobError("Could not observe process helper")
		return status = 258
	}
	Wait(recovery := 0, limitMs := 20000) {
		deadline := this.Started + limitMs
		Loop {
			if recovery
				recovery.Check()
			if DllCall("GetTickCount64", "UInt64") >= deadline
				throw nm_ProcessJobError("Reconnect helper timed out; launch outcome may be unknown")
			if !this.Running()
				break
			Sleep 20
		}
		if !DllCall("GetExitCodeProcess", "Ptr", this.Process, "UIntP", &code := 0) || code != 0
			|| NumGet(this.View, 8, "Int") != 1
			throw nm_ProcessJobError("Reconnect helper failed (worker line " NumGet(this.View, 12, "Int") ")")
		return NumGet(this.View, 12, "Int")
	}
	Close() {
		if this.Process {
			; TerminateProcess is asynchronous. Keep using this handle, not a PID
			; lookup, and wait for its terminal state before releasing resources.
			if this.Running() {
				; Another termination request may already be in flight. Its handle
				; can remain unsignaled briefly while TerminateProcess is denied.
				DllCall("TerminateProcess", "Ptr", this.Process, "UInt", 1)
				if DllCall("WaitForSingleObject", "Ptr", this.Process, "UInt", 2000) != 0
					throw Error("Owned process helper has not terminated")
			}
			DllCall("CloseHandle", "Ptr", this.Process), this.Process := 0
			if nm_OwnedProcessJob.Jobs.Has(this.Pid)
				nm_OwnedProcessJob.Jobs.Delete(this.Pid)
		}
		if this.Job
			DllCall("CloseHandle", "Ptr", this.Job), this.Job := 0
		if this.View
			DllCall("UnmapViewOfFile", "Ptr", this.View), this.View := 0
		if this.Mapping
			DllCall("CloseHandle", "Ptr", this.Mapping), this.Mapping := 0
	}
	static Execute(request, recovery := 0) {
		job := nm_OwnedProcessJob(request)
		try return job.Wait(recovery)
		finally job.Close()
	}
	static CloseAll(*) {
		for pid, job in this.Jobs.Clone()
			job.Close()
	}
}

class nm_ProcessChannel {
	__New(name) {
		this.Mapping := this.View := 0
		if !RegExMatch(name, "^Local\\NatroReconnect-[A-Fa-f0-9]{32}$")
			throw ValueError("Invalid process channel")
		this.Mapping := DllCall("OpenFileMappingW", "UInt", 0xF001F, "Int", false, "Str", name, "Ptr")
		if !this.Mapping
			throw OSError()
		this.View := DllCall("MapViewOfFile", "Ptr", this.Mapping, "UInt", 0xF001F, "UInt", 0, "UInt", 0, "UPtr", nm_OwnedProcessJob.Bytes, "Ptr")
		if !this.View {
			this.Close()
			throw OSError()
		}
	}
	Read() {
		length := NumGet(this.View, 4, "UInt")
		if NumGet(this.View, 0, "UInt") != 1 || length > 4096 || length < 2
			throw ValueError("Invalid process request")
		return JSON.parse(StrGet(this.View + 16, length, "UTF-16"))
	}
	Complete(value := 0, ok := true) {
		NumPut("Int", value, this.View, 12)
		; Parent consumes this result only after the process handle is signaled.
		NumPut("Int", ok ? 1 : 2, this.View, 8)
	}
	Close() {
		if this.View
			DllCall("UnmapViewOfFile", "Ptr", this.View), this.View := 0
		if this.Mapping
			DllCall("CloseHandle", "Ptr", this.Mapping), this.Mapping := 0
	}
}
