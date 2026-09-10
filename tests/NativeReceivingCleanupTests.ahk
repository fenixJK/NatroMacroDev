TestNativeReceivingCleanup() {
	root := A_Temp "\natro-receiving-" DllCall("GetCurrentProcessId")
	inbox := root "\settings\remote-inbox"
	DirCreate inbox
	try {
		for case in ["empty", "partial", "unexpected", "hardlink", "readonly", "locked"] {
			directory := inbox "\.receiving-" Format("{:032x}", A_Index)
			DirCreate directory
			file := directory "\payload.partial", held := 0
			if case != "empty" && case != "hardlink"
				FileAppend "partial", file
			if case = "unexpected"
				FileAppend "keep", directory "\personal.txt"
			if case = "hardlink" {
				FileAppend "keep", root "\original.txt"
				RequireProcess(DllCall("CreateHardLinkW", "Str", file, "Str", root "\original.txt", "Ptr", 0), "Create disposable hardlink fixture")
			}
			if case = "readonly"
				FileSetAttrib "+R", file
			if case = "locked"
				held := FileOpen(file, "r-wd")
			try {
				ok := RunReceivingCleanup(directory)
				RequireProcess(ok = (case = "empty" || case = "partial"), "Cleanup result matches owned-file policy: " case)
				if ok
					RequireProcess(!DirExist(directory), "Successful receiving cleanup removes the empty folder")
				else
					RequireProcess(DirExist(directory), "Rejected receiving cleanup retains the folder")
				if case = "unexpected"
					RequireProcess(FileRead(directory "\personal.txt") = "keep", "Unknown contents are preserved")
				if case = "hardlink"
					RequireProcess(FileRead(root "\original.txt") = "keep" && FileExist(file), "Hardlinked content is preserved")
			} finally {
				if held
					held.Close()
				if case = "readonly"
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
