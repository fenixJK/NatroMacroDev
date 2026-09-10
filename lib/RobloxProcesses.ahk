; Only the exact player executable in this user's interactive session is eligible.
; Keep the process handle from verification through termination to avoid PID reuse.
class nm_RobloxProcesses {
	static IsPlayer(name) => StrLower(name) = "robloxplayerbeta.exe"
	static User(handle) {
		if !DllCall("advapi32\OpenProcessToken", "Ptr", handle, "UInt", 8, "PtrP", &token := 0)
			throw OSError()
		try {
			DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", 1, "Ptr", 0, "UInt", 0, "UIntP", &size := 0)
			if size < A_PtrSize || size > 65536
				throw Error("Invalid process owner information")
			data := Buffer(size)
			if !DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", 1, "Ptr", data, "UInt", size, "UIntP", &size)
				throw OSError()
			return data
		} finally DllCall("CloseHandle", "Ptr", token)
	}
	static Session(handle) {
		if !DllCall("advapi32\OpenProcessToken", "Ptr", handle, "UInt", 8, "PtrP", &token := 0)
			throw OSError()
		try {
			if !DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", 12, "UIntP", &session := 0, "UInt", 4, "UIntP", &size := 0)
				throw OSError()
			return session
		} finally DllCall("CloseHandle", "Ptr", token)
	}
	static SameUser(handle) {
		first := this.User(-1), second := this.User(handle)
		return DllCall("advapi32\EqualSid", "Ptr", NumGet(first, 0, "Ptr"), "Ptr", NumGet(second, 0, "Ptr"))
	}
	static OpenPlayer(pid) {
		if !DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId"), "UIntP", &ownSession := 0)
			throw OSError()
		if !DllCall("ProcessIdToSessionId", "UInt", pid, "UIntP", &session := 0) || session != ownSession
			return 0
		handle := DllCall("OpenProcess", "UInt", 0x101001, "Int", false, "UInt", pid, "Ptr")
		if !handle {
			if A_LastError = 87 ; process exited between snapshot and open
				return 0
			throw OSError()
		}
		try {
			if DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 0) = 0 {
				DllCall("CloseHandle", "Ptr", handle)
				return 0
			}
			path := Buffer(65536), size := 32768
			if !DllCall("QueryFullProcessImageNameW", "Ptr", handle, "UInt", 0, "Ptr", path, "UIntP", &size)
				throw OSError()
			SplitPath StrGet(path), &name
			if !this.IsPlayer(name) || this.Session(handle) != this.Session(-1) || !this.SameUser(handle) {
				DllCall("CloseHandle", "Ptr", handle)
				return 0
			}
			return handle
		} catch as err {
			DllCall("CloseHandle", "Ptr", handle)
			throw err
		}
	}
	static Find() {
		result := [], snapshot := DllCall("CreateToolhelp32Snapshot", "UInt", 2, "UInt", 0, "Ptr")
		if snapshot = -1
			throw OSError()
		try {
			entry := Buffer(A_PtrSize = 8 ? 568 : 556, 0)
			NumPut("UInt", entry.Size, entry)
			available := DllCall("Process32FirstW", "Ptr", snapshot, "Ptr", entry)
			while available {
				pid := NumGet(entry, 8, "UInt"), name := StrGet(entry.Ptr + (A_PtrSize = 8 ? 44 : 36))
				if this.IsPlayer(name) && (handle := this.OpenPlayer(pid))
					result.Push({pid: pid, handle: handle})
				available := DllCall("Process32NextW", "Ptr", snapshot, "Ptr", entry)
			}
			if A_LastError != 18
				throw OSError()
			return result
		} catch as err {
			for item in result
				DllCall("CloseHandle", "Ptr", item.handle)
			throw err
		} finally DllCall("CloseHandle", "Ptr", snapshot)
	}
	static ClosePlayers() {
		players := this.Find()
		try {
			DetectHiddenWindows true
			for item in players
				for hwnd in WinGetList("ahk_pid " item.pid)
					DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x10, "Ptr", 0, "Ptr", 0)
			if players.Length
				Sleep 1000
			for item in players {
				if DllCall("WaitForSingleObject", "Ptr", item.handle, "UInt", 0) = 258 {
					if !DllCall("TerminateProcess", "Ptr", item.handle, "UInt", 0)
						&& DllCall("WaitForSingleObject", "Ptr", item.handle, "UInt", 0) != 0
						throw OSError()
					if DllCall("WaitForSingleObject", "Ptr", item.handle, "UInt", 2000) != 0
						throw Error("Player process did not stop")
				}
			}
			return players.Length
		} finally {
			for item in players
				DllCall("CloseHandle", "Ptr", item.handle)
		}
	}
}
