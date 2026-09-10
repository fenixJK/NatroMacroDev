#Include "%A_ScriptDir%\..\lib\PowerShellJob.ahk"
; One owned worker at a time. Polling never waits for response bodies.
class nm_AttachmentDownloads {
	static Active := 0
	static OnDiagnostic := 0
	static Start(url, messageId) {
		if this.Active
			throw Error("An attachment download is already running. Try again when it finishes.")
		if StrLen(url) > 4096
			throw ValueError("Attachment URL is too long")
		started := DllCall("GetTickCount64", "UInt64")
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
			this.Active := {worker: worker, directory: directory, id: messageId, tick: started, stopping: false}
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
				this.Emit(this.Snapshot(job, "deadline"))
				job.worker.Terminate()
				job.stopping := true
			}
			return
		}
		try {
			result := job.stopping ? Map("ok", false, "reason", "timeout") : job.worker.Result()
			ok := result.Has("ok") && result["ok"]
			message := ok ? "Attachment saved in settings/remote-inbox. Files are not opened automatically."
				: "Attachment download failed (" (result.Has("reason") ? result["reason"] : "worker") "). No completed file was reported."
		} catch {
			message := "Attachment worker failed. Check the inbox before retrying.", ok := false
		}
		; Retain ownership if termination cannot be confirmed. Callback failure
		; must not trigger a second, contradictory completion notification.
		diagnostic := this.Snapshot(job, "completed"), cleanupStarted := DllCall("GetTickCount64", "UInt64")
		try job.worker.Close()
		catch as err {
			diagnostic["event"] := "cleanup-unconfirmed"
			this.Emit(diagnostic)
			throw err
		}
		diagnostic["closeMs"] := DllCall("GetTickCount64", "UInt64") - cleanupStarted
		this.Active := 0
		cleanupStarted := DllCall("GetTickCount64", "UInt64")
		try DirDelete job.directory, true
		diagnostic["directoryCleanupMs"] := DllCall("GetTickCount64", "UInt64") - cleanupStarted
		diagnostic["ok"] := !!ok
		this.Emit(diagnostic)
		notify.Call(message, ok, job.id)
	}
	static Snapshot(job, event) {
		try diagnostic := job.worker.Diagnostics()
		catch
			diagnostic := Map("stage", "unavailable")
		diagnostic["event"] := event
		diagnostic["ownerElapsedMs"] := DllCall("GetTickCount64", "UInt64") - job.tick
		return diagnostic
	}
	static Emit(diagnostic) {
		if IsObject(this.OnDiagnostic)
			try this.OnDiagnostic.Call(diagnostic)
	}
	static Close(*) {
		if !(job := this.Active)
			return
		job.worker.Close()
		this.Active := 0
		try DirDelete job.directory, true
	}
}
