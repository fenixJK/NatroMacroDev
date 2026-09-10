#Include "%A_ScriptDir%\..\lib\PowerShellJob.ahk"
; Only directories created by this object are disposable. Source paths are data
; sent through shared memory, never interpolated into PowerShell command text.
class nm_UploadArchive {
	static Active := Map()
	static Registered := false
	__New(source) {
		this.Directory := "", this.Worker := 0
		fullPath := Buffer(65536)
		length := DllCall("GetFullPathNameW", "Str", source, "UInt", 32768, "Ptr", fullPath, "Ptr", 0, "UInt")
		if !length || length >= 32768
			throw Error("Could not resolve upload archive source")
		source := StrGet(fullPath)
		if !nm_UploadArchive.Registered {
			OnExit(ObjBindMethod(nm_UploadArchive, "CloseAll"))
			nm_UploadArchive.Registered := true
		}
		guid := Buffer(16), value := Buffer(78)
		if DllCall("ole32\CoCreateGuid", "Ptr", guid, "Int") != 0
			throw Error("Could not reserve an upload archive")
		DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", value, "Int", 39)
		key := RegExReplace(StrGet(value), "[{}-]")
		directory := A_Temp "\natro-upload-" key
		if !DllCall("CreateDirectoryW", "Str", directory, "Ptr", 0)
			throw Error("Could not create an upload archive directory")
		this.Directory := directory, this.Path := directory "\upload.zip"
		nm_UploadArchive.Active[directory] := this
		try {
			started := DllCall("GetTickCount64", "UInt64")
			this.Worker := nm_PowerShellJob(Map("source", source, "destination", this.Path), A_WorkingDir "\submacros\upload-archive.ps1")
			while this.Worker.Status = 0 {
				if DllCall("GetTickCount64", "UInt64") - started >= 45000
					throw Error("Upload archive timed out")
				if FileExist(this.Path) && FileGetSize(this.Path) > 10485760
					throw Error("Upload archive exceeds size limit")
				Sleep 20
			}
			if !this.Worker.Result()["ok"] || !FileExist(this.Path)
				throw Error("Could not create upload archive")
		} catch as err {
			this.Close()
			throw err
		}
	}
	Close(*) {
		if this.Worker {
			this.Worker.Close()
			this.Worker := 0
		}
		if this.Directory {
			if DirExist(this.Directory)
				DirDelete this.Directory, true
			nm_UploadArchive.Active.Delete(this.Directory)
			this.Directory := ""
		}
	}
	static CloseAll(*) {
		for , archive in this.Active.Clone()
			try archive.Close()
	}
}
