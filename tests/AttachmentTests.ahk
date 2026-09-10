class AttachmentWorkerFixture {
	Status := 0
	ExitCode := 0
	Stopped := 0
	__New(text := '{"ok":true}') => this.StdOut := {ReadAll: (*) => text}
	Terminate() => (this.Stopped++, this.Status := 1)
	Close() {
		if this.Status = 0
			this.Terminate()
	}
	Result() => JSON.parse(this.StdOut.ReadAll())
}

TestAttachmentWorker() {
	replies := [], worker := AttachmentWorkerFixture()
	notify := (message, ok, id) => replies.Push([message, ok, id])
	nm_AttachmentDownloads.Active := {worker: worker, directory: A_WorkingDir "\missing-receiving", id: "42", tick: DllCall("GetTickCount64", "UInt64"), stopping: false}
	try {
		nm_AttachmentDownloads.Pump(notify)
		AssertEqual(replies.Length, 0, "In-flight download does not block or report premature completion")
		AssertDeliveryError(() => nm_AttachmentDownloads.Start("https://cdn.discordapp.com/a", "43"), "Second download is rejected while the worker owns the inbox")
		worker.Status := 1
		nm_AttachmentDownloads.Pump(notify), nm_AttachmentDownloads.Pump(notify)
		Assert(replies.Length = 1 && replies[1][2] && replies[1][3] = "42", "Completed worker reports success exactly once to the original command")
		worker := AttachmentWorkerFixture()
		nm_AttachmentDownloads.Active := {worker: worker, directory: A_WorkingDir "\missing-receiving", id: "44", tick: DllCall("GetTickCount64", "UInt64") - 46000, stopping: false}
		nm_AttachmentDownloads.Pump(notify)
		AssertEqual(worker.Stopped, 1, "Watchdog terminates the existing worker instead of starting another")
		nm_AttachmentDownloads.Pump(notify)
		Assert(replies.Length = 2 && !replies[2][2], "Watchdog termination is not success")
		worker := AttachmentWorkerFixture("invalid output"), worker.Status := 1
		nm_AttachmentDownloads.Active := {worker: worker, directory: A_WorkingDir "\missing-receiving", id: "45", tick: 0, stopping: false}
		nm_AttachmentDownloads.Pump(notify)
		Assert(replies.Length = 3 && !replies[3][2] && !nm_AttachmentDownloads.Active, "Malformed worker result reports failure and releases ownership")
		worker := AttachmentWorkerFixture(), worker.Status := 1
		nm_AttachmentDownloads.Active := {worker: worker, directory: A_WorkingDir "\missing-receiving", id: "callback", tick: 0, stopping: false}
		callbackCalls := {count: 0}
		AssertDeliveryError(() => nm_AttachmentDownloads.Pump((*) => TestAttachmentNotifyFailure(callbackCalls)), "Notification failure propagates after cleanup")
		Assert(!nm_AttachmentDownloads.Active && callbackCalls.count = 1, "Notification failure cannot repeat a contradictory completion or retain the finished worker")
		; Exercise the actual production worker launch and mapping contract, including a
		; Unicode working directory. Its URL policy rejects loopback before networking.
		originalDirectory := A_WorkingDir
		DirCreate "worker-" Chr(233) "\submacros"
		DirCreate "worker-" Chr(233) "\lib"
		FileCopy A_ScriptDir "\..\submacros\attachment-download.ps1", "worker-" Chr(233) "\submacros\attachment-download.ps1"
		FileCopy A_ScriptDir "\..\lib\AttachmentDownload.ps1", "worker-" Chr(233) "\lib\AttachmentDownload.ps1"
		FileCopy A_ScriptDir "\..\lib\PowerShellJob.ps1", "worker-" Chr(233) "\lib\PowerShellJob.ps1"
		SetWorkingDir "worker-" Chr(233)
		try {
			nm_AttachmentDownloads.Start("http://127.0.0.1:1/not-allowed", "46")
			jobDirectory := nm_AttachmentDownloads.Active.directory
			start := DllCall("GetTickCount64", "UInt64")
			while nm_AttachmentDownloads.Active && DllCall("GetTickCount64", "UInt64") - start < 50000 {
				nm_AttachmentDownloads.Pump(notify)
				Sleep 20
			}
			if nm_AttachmentDownloads.Active
				FileAppend "Attachment fixture still active: PID=" nm_AttachmentDownloads.Active.worker.ProcessID " status=" nm_AttachmentDownloads.Active.worker.Status " stopping=" nm_AttachmentDownloads.Active.stopping "`n", "*"
			else if replies.Length >= 4
				FileAppend "Attachment fixture result after " (DllCall("GetTickCount64", "UInt64") - start) " ms: " replies[4][1] "`n", "*"
			Assert(!nm_AttachmentDownloads.Active && replies.Length = 4 && !replies[4][2], "Native worker launch completes without contacting an unapproved host")
			Assert(InStr(replies[4][1], "(url)"), "Native worker receives and parses shared-memory JSON")
			Assert(!DirExist(jobDirectory), "Completed worker cleans its owned receiving directory")
			FileDelete "submacros\attachment-download.ps1"
			FileAppend "param([string]$Channel); Start-Sleep -Seconds 30", "submacros\attachment-download.ps1"
			nm_AttachmentDownloads.Start("http://127.0.0.1:1/not-allowed", "47")
			jobDirectory := nm_AttachmentDownloads.Active.directory
			pid := nm_AttachmentDownloads.Active.worker.ProcessID
			FileAppend "partial", jobDirectory "\payload.partial"
			nm_AttachmentDownloads.Close()
			Assert(!ProcessExist(pid) && !nm_AttachmentDownloads.Active, "Shutdown terminates the owned native worker")
			Assert(!DirExist(jobDirectory), "Shutdown removes partial data only after the owned worker exits")
		} finally {
			nm_AttachmentDownloads.Close()
			SetWorkingDir originalDirectory
		}
	} finally nm_AttachmentDownloads.Active := 0
}

TestAttachmentNotifyFailure(calls) {
	calls.count++
	throw Error("Fixture notification failure")
}
