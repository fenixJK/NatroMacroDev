class AttachmentWorkerFixture {
	Status := 0
	ExitCode := 0
	Stopped := 0
	__New(text := '{"ok":true}') => this.StdOut := {ReadAll: (*) => text}
	Terminate() => (this.Stopped++, this.Status := 1)
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
		; Exercise the actual production worker launch and stdin contract, including a
		; Unicode working directory. Its URL policy rejects loopback before networking.
		originalDirectory := A_WorkingDir
		DirCreate "worker-" Chr(233) "\submacros"
		DirCreate "worker-" Chr(233) "\lib"
		FileCopy A_ScriptDir "\..\submacros\attachment-download.ps1", "worker-" Chr(233) "\submacros\attachment-download.ps1"
		FileCopy A_ScriptDir "\..\lib\AttachmentDownload.ps1", "worker-" Chr(233) "\lib\AttachmentDownload.ps1"
		SetWorkingDir "worker-" Chr(233)
		try {
			nm_AttachmentDownloads.Start("http://127.0.0.1:1/not-allowed", "46")
			jobDirectory := nm_AttachmentDownloads.Active.directory
			start := DllCall("GetTickCount64", "UInt64")
			while nm_AttachmentDownloads.Active && DllCall("GetTickCount64", "UInt64") - start < 15000 {
				nm_AttachmentDownloads.Pump(notify)
				Sleep 20
			}
			Assert(!nm_AttachmentDownloads.Active && replies.Length = 4 && !replies[4][2], "Native worker launch completes without contacting an unapproved host")
			Assert(InStr(replies[4][1], "(url)"), "Native worker receives and parses stdin JSON")
			Assert(!DirExist(jobDirectory), "Completed worker cleans its owned receiving directory")
		} finally {
			nm_AttachmentDownloads.Close()
			SetWorkingDir originalDirectory
		}
	} finally nm_AttachmentDownloads.Active := 0
}
