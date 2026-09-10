#Include "%A_ScriptDir%\..\lib\PowerShellJob.ahk"
#Include "%A_ScriptDir%\..\lib\ReceivingCleanup.ahk"
; One owned worker at a time. Polling never waits for response bodies.
class nm_AttachmentDownloads {
	static Active := 0
	static OnDiagnostic := 0
	static CleanupFactory := nm_ReceivingCleanup
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
		job := {worker: 0, directory: directory, id: messageId, tick: started, stopping: false, ok: false, message: "Attachment download was interrupted."}
		this.Active := job
		try {
			worker := nm_PowerShellJob(Map("url", url, "directory", directory), A_WorkingDir "\submacros\attachment-download.ps1")
			if this.Active != job {
				worker.Close()
				throw Error("Attachment startup was cancelled")
			}
			job.worker := worker
		} catch {
			if this.Active = job
				this.Close()
			throw Error("Could not start the attachment download worker")
		}
	}
	static Pump(notify) {
		if !(job := this.Active)
			return
		if job.HasOwnProp("closing") && job.closing
			return
		if job.HasOwnProp("cleanupStarted") {
			this.PumpCleanup(job, notify)
			return
		}
		if !job.worker
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
		job.worker := 0
		job.ok := ok, job.message := message, job.diagnostic := diagnostic
		this.BeginCleanup(job)
		this.PumpCleanup(job, notify)
	}
	static BeginCleanup(job) {
		job.cleanupStarted := DllCall("GetTickCount64", "UInt64"), job.cleanup := 0
		job.cleanupLaunching := true
		try job.cleanup := this.CleanupFactory.Call(job.directory)
		catch
			job.cleanup := 0
		finally job.cleanupLaunching := false
		if this.Active != job && job.cleanup {
			job.cleanup.Close()
			job.cleanup := 0
		}
	}
	static PumpCleanup(job, notify) {
		if job.HasOwnProp("cleanupLaunching") && job.cleanupLaunching
			return
		cleaned := false
		if job.cleanup {
			if job.cleanup.Status = 0 {
				if DllCall("GetTickCount64", "UInt64") - job.cleanupStarted < 20000
					return
			} else {
				try cleaned := !!job.cleanup.Result()
			}
			; On deadline, Close terminates only the owned cleanup helper.
			job.cleanup.Close()
			job.cleanup := 0
		}
		this.Finish(job, notify, cleaned)
	}
	static Finish(job, notify, cleaned) {
		if this.Active != job
			return
		this.Active := 0
		diagnostic := job.HasOwnProp("diagnostic") ? job.diagnostic : this.Snapshot(job, "interrupted")
		diagnostic["directoryCleanupMs"] := DllCall("GetTickCount64", "UInt64") - job.cleanupStarted
		diagnostic["cleanupOk"] := !!cleaned
		diagnostic["ok"] := !!job.ok
		if !diagnostic.Has("closeMs")
			diagnostic["closeMs"] := 0
		if !cleaned {
			diagnostic["event"] := "temporary-retained"
			job.message .= " Temporary cleanup was not confirmed; files may remain in the inbox."
		}
		this.Emit(diagnostic)
		if IsObject(notify)
			notify.Call(job.message, job.ok, job.id)
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
		job.closing := true
		if job.worker {
			job.worker.Close()
			job.worker := 0
		}
		if !job.HasOwnProp("cleanupStarted")
			this.BeginCleanup(job)
		deadline := DllCall("GetTickCount64", "UInt64") + 5000
		while job.cleanup && job.cleanup.Status = 0 && DllCall("GetTickCount64", "UInt64") < deadline
			Sleep 20
		; Reuse the ordinary completion path, but never notify from shutdown.
		if job.cleanup && job.cleanup.Status = 0 {
			job.cleanup.Close()
			job.cleanup := 0
		}
		if !job.HasOwnProp("ok")
			job.ok := false, job.message := "Attachment download was interrupted."
		this.PumpCleanup(job, 0)
	}
}
