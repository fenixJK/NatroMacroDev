; A retained handle identifies a main-script instance through cleanup. Discovery
; requires its exact script title, runtime image, current user and session.
class nm_ScriptProcess {
	__New(handle, pid, title := "Natro Macro", scriptHwnd := 0) {
		this.Handle := handle, this.Pid := pid, this.Title := title
		this.ScriptHwnd := scriptHwnd
	}
	Running() {
		result := DllCall("WaitForSingleObject", "Ptr", this.Handle, "UInt", 0, "UInt")
		if result != 0 && result != 258
			throw Error("Could not observe macro process")
		return result = 258
	}
	Ready() {
		if !this.Running()
			return 0
		hiddenBefore := A_DetectHiddenWindows
		DetectHiddenWindows false
		try {
			for hwnd in WinGetList("ahk_class AutoHotkeyGUI ahk_pid " this.Pid)
				if WinGetTitle("ahk_id " hwnd) == this.Title
					return hwnd
		} finally DetectHiddenWindows hiddenBefore
		return 0
	}
	Close() {
		if this.Running() {
			DllCall("TerminateProcess", "Ptr", this.Handle, "UInt", 1)
			if DllCall("WaitForSingleObject", "Ptr", this.Handle, "UInt", 2000) != 0
				throw Error("Macro process did not stop; automatic recovery aborted")
		}
	}
	Release() {
		if this.Handle
			DllCall("CloseHandle", "Ptr", this.Handle), this.Handle := 0
	}
	Shutdown() {
		if this.Running() && this.ScriptHwnd {
			hiddenBefore := A_DetectHiddenWindows
			DetectHiddenWindows true
			try {
				if WinGetPID("ahk_id " this.ScriptHwnd) = this.Pid
					DllCall("PostMessageW", "Ptr", this.ScriptHwnd, "UInt", 0x10, "Ptr", 0, "Ptr", 0)
			} finally DetectHiddenWindows hiddenBefore
			deadline := DllCall("GetTickCount64", "UInt64") + 500
			while this.Running() && DllCall("GetTickCount64", "UInt64") < deadline
				Sleep 20
		}
		this.Close()
	}
	static Launch(script, executable, args := [], title := "Natro Macro") {
		command := '"' executable '" /ErrorStdOut=UTF-8 "' script '"'
		for arg in args {
			if !RegExMatch(arg, "^\d+$")
				throw ValueError("Invalid macro restart argument")
			command .= ' "' arg '"'
		}
		mutable := Buffer((StrLen(command) + 1) * 2)
		StrPut(command, mutable, "UTF-16")
		startup := Buffer(A_PtrSize = 8 ? 104 : 68, 0), info := Buffer(A_PtrSize * 2 + 8, 0)
		NumPut("UInt", startup.Size, startup)
		if !DllCall("CreateProcessW", "Str", executable, "Ptr", mutable, "Ptr", 0, "Ptr", 0, "Int", false,
			"UInt", 0, "Ptr", 0, "Str", A_WorkingDir, "Ptr", startup, "Ptr", info)
			throw Error("Could not launch replacement macro")
		DllCall("CloseHandle", "Ptr", NumGet(info, A_PtrSize, "Ptr"))
		return nm_ScriptProcess(NumGet(info, 0, "Ptr"), NumGet(info, A_PtrSize * 2, "UInt"), title)
	}
	static Find(script, executable) {
		script := this.FullPath(script), executable := this.FullPath(executable)
		found := [], hiddenBefore := A_DetectHiddenWindows
		DetectHiddenWindows true
		try {
			for hwnd in WinGetList("ahk_class AutoHotkey") {
				if StrCompare(WinGetTitle("ahk_id " hwnd), script " - AutoHotkey v" A_AhkVersion, false) != 0
					continue
				pid := WinGetPID("ahk_id " hwnd)
				handle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", pid, "Ptr")
				if !handle {
					if !WinExist("ahk_id " hwnd)
						continue
					throw Error("Could not open macro process for verified cleanup")
				}
				try {
					path := Buffer(65536), size := 32768
					if !DllCall("QueryFullProcessImageNameW", "Ptr", handle, "UInt", 0, "Ptr", path, "UIntP", &size)
						throw Error("Could not verify macro runtime")
					if StrCompare(this.FullPath(StrGet(path)), executable, false) != 0
						|| !nm_RobloxProcesses.SameUser(handle) || nm_RobloxProcesses.Session(handle) != nm_RobloxProcesses.Session(-1)
						|| !WinExist("ahk_id " hwnd) || WinGetPID("ahk_id " hwnd) != pid
						|| StrCompare(WinGetTitle("ahk_id " hwnd), script " - AutoHotkey v" A_AhkVersion, false) != 0
						continue
					found.Push(nm_ScriptProcess(handle, pid, "Natro Macro", hwnd)), handle := 0
				} finally {
					if handle
						DllCall("CloseHandle", "Ptr", handle)
				}
			}
			return found
		} catch as err {
			for instance in found
				instance.Release()
			throw err
		} finally DetectHiddenWindows hiddenBefore
	}
	static FullPath(path) {
		pathBuffer := Buffer(65536)
		length := DllCall("GetFullPathNameW", "Str", path, "UInt", 32768, "Ptr", pathBuffer, "Ptr", 0, "UInt")
		if !length || length >= 32768
			throw Error("Could not resolve script identity")
		longPath := Buffer(65536)
		longLength := DllCall("GetLongPathNameW", "Ptr", pathBuffer, "Ptr", longPath, "UInt", 32768, "UInt")
		if longLength && longLength < 32768
			return StrGet(longPath)
		return StrGet(pathBuffer)
	}
	static Stop(script, executable) {
		instances := this.Find(script, executable)
		try {
			for instance in instances
				instance.Close()
		} finally {
			for instance in instances
				instance.Release()
		}
	}
}
