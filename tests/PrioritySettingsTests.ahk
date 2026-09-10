TestPrioritySettings() {
	AssertEqual(nm_PrioritySettings.Describe(87654321), "1 - GoGather`n2 - Boost`n3 - QuestRotate`n4 - Collect`n5 - Bugrun`n6 - Planter`n7 - Mondo`n8 - Night", "Descriptions follow actual order")
	for order in [12345678, 87654321]
		Loop 8 {
			from := A_Index
			Loop 8 {
				destination := A_Index, moved := nm_PrioritySettings.Move(order, from, destination)
				AssertEqual(moved.Tasks[destination], nm_BuildPriorityList(order)[from], "Moved task occupies requested slot")
				AssertEqual(moved.Tasks.Length, 8, "Move retains complete permutation")
				remainingBefore := "", remainingAfter := ""
				for index, digit in StrSplit(order)
					if index != from
						remainingBefore .= digit
				for index, digit in StrSplit(moved.Order)
					if index != destination
						remainingAfter .= digit
				AssertEqual(remainingAfter, remainingBefore, "Move preserves relative order of other tasks")
			}
		}
	for bad in ["11111111", "1234567", "123456789", "01234567", "abcdefgh", Map()]
		AssertThrows(ObjBindMethod(nm_PrioritySettings, "State", bad), "All priority entry points validate full permutation")
	AssertThrows(ObjBindMethod(nm_PrioritySettings, "Move", 12345678, 0, 8), "Invalid row cannot move")
	originalPath := nm_PrioritySettings.Path
	nm_PrioritySettings.Path := "settings\priority-fixture.ini"
	try {
		AssertEqual(nm_PrioritySettings.Read().Order, 12345678, "Missing order defaults without writing")
		AssertEqual(FileExist(nm_PrioritySettings.Path), "", "Read is side-effect free")
		savedPriority := nm_PrioritySettings.Commit(87654321, 12345678)
		AssertEqual(savedPriority.Order, 87654321, "Successful save returns candidate")
		AssertEqual(nm_PrioritySettings.Read().Order, savedPriority.Order, "Saved order round trips")
		nm_PrioritySettings.Commit(21345678)
		PriorityExpectFailure(ObjBindMethod(nm_PrioritySettings, "Commit", 12345678, savedPriority.Order))
		AssertEqual(savedPriority.Order, 87654321, "Failed stale save does not publish candidate")
		AssertEqual(nm_PrioritySettings.Read().Order, 21345678, "Stale editor cannot overwrite newer saved order")
		nm_PrioritySettings.Commit(12345678, 21345678)
		AssertThrows(ObjBindMethod(nm_PrioritySettings, "Commit", 11111111), "Invalid write rejected")
		AssertEqual(nm_PrioritySettings.Read().Order, 12345678, "Invalid write preserves disk")
		handle := DllCall("CreateFileW", "Str", A_WorkingDir "\settings\.priority.lock", "UInt", 0xC0000000, "UInt", 0, "Ptr", 0, "UInt", 4, "UInt", 0x04000080, "Ptr", 0, "Ptr")
		Assert(handle != -1, "Hold real settings lock")
		try PriorityExpectFailure(ObjBindMethod(nm_PrioritySettings, "Commit", 87654321))
		finally DllCall("CloseHandle", "Ptr", handle)
		AssertEqual(nm_PrioritySettings.Read().Order, 12345678, "Busy save leaves disk unchanged")
		nm_PrioritySettings.Path := "settings"
		PriorityExpectFailure(ObjBindMethod(nm_PrioritySettings, "Commit", 87654321))
		nm_PrioritySettings.Path := "settings\priority-fixture.ini"
		AssertEqual(nm_PrioritySettings.Commit(87654321).Order, 87654321, "Write failure releases lock for next save")
		IniWrite 11111111, nm_PrioritySettings.Path, "Settings", "PriorityListNumeric"
		AssertThrows(ObjBindMethod(nm_PrioritySettings, "Read"), "Corrupt saved order is rejected")
		AssertEqual(IniRead(nm_PrioritySettings.Path, "Settings", "PriorityListNumeric"), 11111111, "Read never silently resets user settings")
	} finally {
		nm_PrioritySettings.Path := originalPath
		if FileExist("settings\priority-fixture.ini")
			FileDelete "settings\priority-fixture.ini"
	}
}
PriorityExpectFailure(action) {
	try action.Call()
	catch Error
		return
	throw Error("Expected priority persistence failure")
}
