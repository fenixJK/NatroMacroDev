; Runs only in a contained helper. Never recursively deletes a directory.
class nm_ReceivingCleanupFiles {
	static Remove(directory) {
		if !(directory is String) || StrLen(directory) > 4096
			|| !RegExMatch(directory, "i)^[a-z]:\\.*\\settings\\remote-inbox\\\.receiving-[a-f0-9]{32}$")
			throw ValueError("Invalid receiving directory")
		parts := StrSplit(SubStr(directory, 4), "\")
		if parts.Length > 128
			throw ValueError("Receiving path is too deep")
		for part in parts
			if !part || part = "." || part = ".." || RegExMatch(part, '[<>:"/|?*]|[. ]$')
				throw ValueError("Invalid receiving path component")
		handles := [], partialHandle := 0
		try {
			path := SubStr(directory, 1, 3)
			handles.Push(this.Open(path, false, true))
			for index, part in parts {
				path := RTrim(path, "\") "\" part
				handle := this.Open(path, index = parts.Length, true)
				if !handle {
					; Missing components mean there is no owned receiving directory.
					return
				}
				handles.Push(handle)
			}
			partialHandle := this.Open(directory "\payload.partial", true, false)
			if partialHandle {
				this.Delete(partialHandle)
				DllCall("CloseHandle", "Ptr", partialHandle), partialHandle := 0
			}
			; Unknown files/subdirectories cause this to fail and remain intact.
			this.Delete(handles[handles.Length])
		} finally {
			if partialHandle
				DllCall("CloseHandle", "Ptr", partialHandle)
			while handles.Length
				DllCall("CloseHandle", "Ptr", handles.Pop())
		}
	}
	static Open(path, remove, directory) {
		; Hold every ancestor without delete sharing, so it cannot be renamed
		; under the worker. Inspect the opened object itself, without following
		; a final reparse point. Deletion uses this same verified handle.
		handle := DllCall("CreateFileW", "Str", path, "UInt", 0x80 | (remove ? 0x10000 : 0), "UInt", 3,
			"Ptr", 0, "UInt", 3, "UInt", 0x02200000, "Ptr", 0, "Ptr")
		if handle = -1 {
			if A_LastError = 2 || A_LastError = 3
				return 0
			throw Error("Receiving object could not be opened")
		}
		try {
			info := Buffer(52, 0)
			if !DllCall("GetFileInformationByHandle", "Ptr", handle, "Ptr", info)
				throw Error("Receiving object could not be verified")
			attributes := NumGet(info, 0, "UInt")
			if (attributes & 0x400) || !!(attributes & 0x10) != !!directory || (!directory && NumGet(info, 40, "UInt") != 1)
				throw Error("Linked or unexpected receiving object retained")
			return handle
		} catch as err {
			DllCall("CloseHandle", "Ptr", handle)
			throw err
		}
	}
	static Delete(handle) {
		disposition := Buffer(1, 1)
		if !DllCall("SetFileInformationByHandle", "Ptr", handle, "Int", 4, "Ptr", disposition, "UInt", disposition.Size)
			throw Error("Receiving object retained")
	}
}
