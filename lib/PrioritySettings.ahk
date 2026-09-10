#Include "%A_ScriptDir%\..\lib\RuntimePolicy.ahk"
#Include "%A_ScriptDir%\..\lib\ScriptProcess.ahk"
#Include "%A_ScriptDir%\..\lib\RobloxProcesses.ahk"

class nm_PrioritySettings {
	static Path := "settings\nm_config.ini"
	static State(order) {
		tasks := nm_BuildPriorityList(order)
		return {Order: Integer(order), Tasks: tasks}
	}
	static Read() => this.State(IniRead(this.Path, "Settings", "PriorityListNumeric", "12345678"))
	static Move(order, from, destination) {
		this.State(order)
		if !IsInteger(from) || !IsInteger(destination) || from < 1 || from > 8 || destination < 1 || destination > 8
			throw ValueError("Invalid priority move")
		digits := StrSplit(order), result := ""
		digits.InsertAt(destination, digits.RemoveAt(from))
		for digit in digits
			result .= digit
		return this.State(result)
	}
	static Describe(order) {
		text := ""
		for index, task in this.State(order).Tasks
			text .= (index = 1 ? "" : "`n") index " - " task
		return text
	}
	static Commit(order, expected?) {
		candidate := this.State(order)
		if IsSet(expected)
			expected := this.State(expected).Order
		start := DllCall("GetTickCount64", "UInt64")
		Loop {
			handle := DllCall("CreateFileW", "Str", A_WorkingDir "\settings\.priority.lock", "UInt", 0xC0000000, "UInt", 0, "Ptr", 0, "UInt", 4, "UInt", 0x04000080, "Ptr", 0, "Ptr")
			if handle != -1
				break
			if A_LastError != 32 || DllCall("GetTickCount64", "UInt64") - start >= 1000
				throw Error("Priority settings are busy or not writable; try again")
			Sleep 10
		}
		try {
			if IsSet(expected) && this.Read().Order != expected
				throw Error("Priority changed since this window opened. Reopen the window and try again.")
			IniWrite candidate.Order, this.Path, "Settings", "PriorityListNumeric"
			return candidate
		} finally DllCall("CloseHandle", "Ptr", handle)
	}
	static Notify(root := "") {
		if !root
			root := A_WorkingDir
		; Notifications contain no authoritative setting value. Receivers read their
		; own installation's validated file; the scheduler also reads each cycle.
		for name in ["natro_macro", "Status"]
			for bits in [32, 64] {
				try instances := nm_ScriptProcess.Find(root "\submacros\" name ".ahk", root "\submacros\AutoHotkey" bits ".exe")
				catch Error
					continue
				try {
					for instance in instances
						if instance.Running()
							try PostMessage 0x5552, 366, 0,, "ahk_id " instance.ScriptHwnd
				} finally {
					for instance in instances
						instance.Release()
				}
			}
	}
}
