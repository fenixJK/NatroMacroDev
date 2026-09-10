#Include "%A_ScriptDir%\..\lib\ContainedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\InlineProtocol.ahk"

class nm_InlineWorker extends nm_ContainedProcessJob {
	__New(source, executable, validate := false) {
		this.Child := this.ChildPid := 0
		super.__New(Map("source", source, "executable", executable, "validate", !!validate), A_WorkingDir "\submacros\inline-worker.ahk")
		try {
			deadline := this.Started + 20000
			Loop {
				phase := NumGet(this.View, 8, "Int"), pid := NumGet(this.View, 12, "UInt")
				if pid && !this.ChildPid {
					this.ChildPid := pid
					this.Child := DllCall("OpenProcess", "UInt", 0x101000, "Int", false, "UInt", pid, "Ptr")
					if this.Child && (!DllCall("IsProcessInJob", "Ptr", this.Child, "Ptr", this.Job, "IntP", &owned := 0) || !owned)
						throw Error("Generated worker ownership could not be verified")
				}
				if phase = 3 || phase = 1
					break
				if phase = 2 || !this.Running() || DllCall("GetTickCount64", "UInt64") >= deadline
					throw Error("Generated worker did not receive its script")
				Sleep 20
			}
		} catch as err {
			this.Close()
			throw err
		}
	}
	ChannelBytes() => nm_InlineProtocol.Bytes
	RequestLimit() => nm_InlineProtocol.RequestChars
	ChildRunning() => this.Child && DllCall("WaitForSingleObject", "Ptr", this.Child, "UInt", 0) = 258
	ProcessID => this.ChildRunning() ? this.ChildPid : 0
	Window() {
		if !this.ChildRunning()
			return 0
		hiddenBefore := A_DetectHiddenWindows
		DetectHiddenWindows true
		try return WinExist("ahk_class AutoHotkey ahk_pid " this.ChildPid)
		finally DetectHiddenWindows hiddenBefore
	}
	Output(timeoutMs := 20000) {
		deadline := DllCall("GetTickCount64", "UInt64") + timeoutMs
		while this.Running() {
			if DllCall("GetTickCount64", "UInt64") >= deadline
				throw Error("Generated worker result timed out")
			Sleep 20
		}
		if !DllCall("GetExitCodeProcess", "Ptr", this.Process, "UIntP", &supervisorCode := 0) || supervisorCode != 0 || NumGet(this.View, 8, "Int") != 1
			throw Error("Generated worker failed without a result")
		ptr := this.View + nm_InlineProtocol.Response
		length := NumGet(ptr, 4, "UInt")
		if length > nm_InlineProtocol.OutputBytes || NumGet(ptr, 8, "UInt")
			throw Error("Generated worker output exceeded its limit")
		output := length ? StrGet(ptr + 16, length, "UTF-8") : ""
		if NumGet(ptr, 0, "UInt") && !output
			throw Error("Generated worker exited unsuccessfully")
		return output
	}
	Close(graceful := true) {
		if graceful && this.Child && this.ChildRunning() && (hwnd := this.Window()) {
			DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x10, "Ptr", 0, "Ptr", 0)
			deadline := DllCall("GetTickCount64", "UInt64") + 500
			while this.ChildRunning() && DllCall("GetTickCount64", "UInt64") < deadline
				Sleep 20
		}
		super.Close()
		if this.Child
			DllCall("CloseHandle", "Ptr", this.Child), this.Child := 0
	}
}

class nm_InlineScripts {
	static Workers := Map()
	static OnFailure := 0
	static Start(role, source, executable, validate := false) {
		if !RegExMatch(role, "^(walk|discord_gui|bee_gui|priority_gui|bitterberry|basic_egg|validate)$")
			throw ValueError("Invalid generated worker role")
		this.Reap()
		this.Close(role)
		worker := nm_InlineWorker(source, executable, validate)
		this.Workers[role] := worker
		return worker
	}
	static Validate(source, executable) {
		worker := this.Start("validate", source, executable, true)
		try return worker.Output()
		finally this.Close("validate")
	}
	static Window(role) => this.Workers.Has(role) ? this.Workers[role].Window() : 0
	static Close(role) {
		if this.Workers.Has(role) {
			this.Workers[role].Close()
			this.Workers.Delete(role)
		}
	}
	static CloseAll() {
		for role in this.Workers.Clone()
			this.Close(role)
	}
	static Reap() {
		for role, worker in this.Workers.Clone() {
			if role = "validate" || worker.Running()
				continue
			failure := 0
			try {
				output := worker.Output(0)
				if NumGet(worker.View + nm_InlineProtocol.Response, 0, "UInt")
					failure := Error(output ? output : "Generated worker failed")
			} catch as err {
				failure := err
			}
			this.Close(role)
			if failure {
				if IsObject(this.OnFailure)
					this.OnFailure.Call(failure, role)
				if role = "walk"
					throw failure
			}
		}
	}
}
