; Only directories created by this object are disposable. Source paths are data
; sent through stdin, never interpolated into PowerShell command text.
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
			; Fixed UTF-16 encoded script, with only ASCII JSON on stdin. LiteralPath
			; preserves brackets, apostrophes, Unicode and PowerShell metacharacters.
			script := "$ErrorActionPreference='Stop'; try { $r=[Console]::In.ReadToEnd() | ConvertFrom-Json; Compress-Archive -LiteralPath $r.source -DestinationPath $r.destination -CompressionLevel Fastest; exit 0 } catch { exit 1 }"
			chars := 0
			if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", StrPtr(script), "UInt", StrLen(script) * 2, "UInt", 0x40000001, "Ptr", 0, "UIntP", &chars)
				throw Error("Could not prepare upload archive worker")
			encoded := Buffer(chars * 2)
			if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", StrPtr(script), "UInt", StrLen(script) * 2, "UInt", 0x40000001, "Ptr", encoded, "UIntP", &chars)
				throw Error("Could not prepare upload archive worker")
			started := DllCall("GetTickCount64", "UInt64")
			this.Worker := ComObject("WScript.Shell").Exec('"' A_WinDir '\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' StrGet(encoded))
			payload := "", jsonText := JSON.stringify(Map("source", source, "destination", this.Path))
			Loop StrLen(jsonText) {
				unit := NumGet(StrPtr(jsonText), (A_Index - 1) * 2, "UShort")
				payload .= unit > 127 ? Format("\u{:04x}", unit) : Chr(unit)
			}
			this.Worker.StdIn.Write(payload), this.Worker.StdIn.Close()
			while this.Worker.Status = 0 {
				if DllCall("GetTickCount64", "UInt64") - started >= 45000
					throw Error("Upload archive timed out")
				if FileExist(this.Path) && FileGetSize(this.Path) > 10485760
					throw Error("Upload archive exceeds size limit")
				Sleep 20
			}
			if this.Worker.ExitCode != 0 || !FileExist(this.Path)
				throw Error("Could not create upload archive")
		} catch as err {
			this.Close()
			throw err
		}
	}
	Close(*) {
		if this.Worker && this.Worker.Status = 0 {
			this.Worker.Terminate()
			ProcessWaitClose this.Worker.ProcessID, 2
			if this.Worker.Status = 0
				throw Error("Upload archive worker has not stopped; temporary files retained")
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
