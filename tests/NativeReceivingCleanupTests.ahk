TestNativeReceivingCleanup() {
	root := A_Temp "\natro-receiving-" DllCall("GetCurrentProcessId")
	inbox := root "\settings\remote-inbox"
	DirCreate inbox
	try {
		for index, scenario in ["empty", "partial", "unexpected", "hardlink", "readonly", "locked"] {
			directory := inbox "\.receiving-" Format("{:032x}", index)
			DirCreate directory
			file := directory "\payload.partial", held := 0
			if scenario != "empty" && scenario != "hardlink"
				FileAppend "partial", file
			if scenario = "unexpected"
				FileAppend "keep", directory "\personal.txt"
			if scenario = "hardlink" {
				FileAppend "keep", root "\original.txt"
				RequireProcess(DllCall("CreateHardLinkW", "Str", file, "Str", root "\original.txt", "Ptr", 0), "Create disposable hardlink fixture")
			}
			if scenario = "readonly"
				FileSetAttrib "+R", file
			if scenario = "locked"
				held := FileOpen(file, "r-wd")
			try {
				ok := RunReceivingCleanup(directory)
				RequireProcess(ok = (scenario = "empty" || scenario = "partial"), "Cleanup result matches owned-file policy: " scenario)
				if ok
					RequireProcess(!DirExist(directory), "Successful receiving cleanup removes the empty folder")
				else
					RequireProcess(DirExist(directory), "Rejected receiving cleanup retains the folder")
				if scenario = "unexpected"
					RequireProcess(FileRead(directory "\personal.txt") = "keep", "Unknown contents are preserved")
				if scenario = "hardlink"
					RequireProcess(FileRead(root "\original.txt") = "keep" && FileExist(file), "Hardlinked content is preserved")
			} finally {
				if held
					held.Close()
				if scenario = "readonly"
					FileSetAttrib "-R", file
			}
		}
		RequireProcess(!RunReceivingCleanup(root), "Ordinary folders cannot be cleanup targets")
		RequireProcess(!RunReceivingCleanup(inbox "\..\remote-inbox\.receiving-" Format("{:032x}", 1)), "Traversal components are rejected")
		RequireProcess(RunReceivingCleanup(inbox "\.receiving-" Format("{:032x}", 99)), "Missing receiving folder is already clean")
		; Ancestor links must not redirect cleanup into another directory.
		target := root "\target", linked := root "\linked"
		DirCreate target "\settings\remote-inbox\.receiving-" Format("{:032x}", 88)
		FileAppend "keep", target "\settings\remote-inbox\.receiving-" Format("{:032x}", 88) "\payload.partial"
		RequireProcess(DllCall("CreateSymbolicLinkW", "Str", linked, "Str", target, "UInt", 3, "UChar"), "Create disposable directory symlink fixture")
		try {
			RequireProcess(!RunReceivingCleanup(linked "\settings\remote-inbox\.receiving-" Format("{:032x}", 88)), "Linked ancestor is rejected")
			RequireProcess(FileRead(target "\settings\remote-inbox\.receiving-" Format("{:032x}", 88) "\payload.partial") = "keep", "Linked target is untouched")
		} finally DllCall("RemoveDirectoryW", "Str", linked)
	} finally DirDelete root, true
	FileAppend "PASS Windows receiving cleanup identity and retention (" A_PtrSize * 8 "-bit)`n", "*"
}
RunReceivingCleanup(directory) {
	worker := nm_ReceivingCleanup(directory)
	try {
		deadline := DllCall("GetTickCount64", "UInt64") + 20000
		while worker.Status = 0 {
			RequireProcess(DllCall("GetTickCount64", "UInt64") < deadline, "Native receiving cleanup completes")
			Sleep 20
		}
		return worker.Result()
	} finally worker.Close()
}
