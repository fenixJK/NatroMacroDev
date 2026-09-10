#Include "%A_ScriptDir%\..\lib\PowerShellJob.ahk"
; One owned worker at a time. Polling never waits for response bodies.
class nm_AttachmentDownloads {
	static Active := 0
	static Start(url, messageId) {
		if this.Active
			throw Error("An attachment download is already running. Try again when it finishes.")
		if StrLen(url) > 4096
			throw ValueError("Attachment URL is too long")
		DirCreate "settings\remote-inbox"
		guid := Buffer(16), value := Buffer(78)
		if DllCall("ole32\CoCreateGuid", "Ptr", guid, "Int") != 0
			throw Error("Could not prepare an attachment download")
		DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", value, "Int", 39)
		key := StrLower(RegExReplace(StrGet(value), "[{}-]"))
		directory := A_WorkingDir "\settings\remote-inbox\.receiving-" key
		if !DllCall("CreateDirectoryW", "Str", directory, "Ptr", 0)
			throw Error("Could not create the attachment receiving directory")
		try {
			worker := nm_PowerShellJob(Map("url", url, "directory", directory), A_WorkingDir "\submacros\attachment-download.ps1")
			this.Active := {worker: worker, directory: directory, id: messageId, tick: DllCall("GetTickCount64", "UInt64"), stopping: false}
		} catch {
			this.Close()
			try DirDelete directory, true
			throw Error("Could not start the attachment download worker")
		}
	}
	static Pump(notify) {
		if !(job := this.Active)
			return
		if job.worker.Status = 0 {
			if !job.stopping && DllCall("GetTickCount64", "UInt64") - job.tick >= 45000 {
				job.worker.Terminate()
				job.stopping := true
			}
			return
		}
		this.Active := 0
		try {
			result := job.stopping ? Map("ok", false, "reason", "timeout") : job.worker.Result()
			ok := result.Has("ok") && result["ok"]
			message := ok ? "Attachment saved in settings/remote-inbox. Files are not opened automatically."
				: "Attachment download failed (" (result.Has("reason") ? result["reason"] : "worker") "). No completed file was reported."
			notify.Call(message, ok, job.id)
		} catch {
			notify.Call("Attachment worker failed. Check the inbox before retrying.", false, job.id)
		} finally {
			job.worker.Close()
			try DirDelete job.directory, true
		}
	}
	static Close(*) {
		if !(job := this.Active)
			return
		job.worker.Close()
		this.Active := 0
		try DirDelete job.directory, true
	}
}
