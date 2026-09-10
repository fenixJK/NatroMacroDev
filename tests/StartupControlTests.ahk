TestStartupControl() {
	global IgnoreIncorrectRobloxSettings := 0
	nm_StartSession.Cancel()
	counts := {rejected: 0, unexpected: 0, ran: 0}
	rejected := () => counts.rejected++, unexpected := (err) => counts.unexpected++
	try {
		for mode in ["automatic", "remote", "local"] {
			request := nm_StartSession.Reserve(mode)
			Assert(request && request.Mode = mode, "Start attempt captures its own mode")
			Assert(!nm_StartSession.Reserve("local") && !nm_StartSession.Running(), "Scheduled request rejects duplicate start and cannot pause/run background actions")
			request.Execute(TestStartupReject.Bind(mode), rejected, unexpected)
			Assert(!nm_StartSession.Current, "Rejected startup releases ownership")
		}
		AssertEqual(counts.rejected, 3, "Every rejected attempt restores controls once")
		request := nm_StartSession.Reserve("local")
		AssertDeliveryError(() => request.Execute(TestStartupThrow, rejected, unexpected), "Unexpected preflight exception propagates")
		Assert(!nm_StartSession.Current && counts.rejected = 4, "Preflight exception releases ownership and restores controls")

		old := nm_StartSession.Reserve("remote")
		old.Timer := (*) => old.Execute((active) => counts.ran++, rejected, unexpected)
		SetTimer old.Timer, -20
		nm_StartSession.Cancel()
		request := nm_StartSession.Reserve("local")
		Assert(!old.Execute((active) => counts.ran++, rejected, unexpected), "Cancelled late callback cannot start another session")
		Sleep 60
		AssertEqual(counts.ran, 0, "Cancel removes the scheduled native timer")
		Assert(nm_StartSession.Current == request, "Late old request cannot release a newer owner")
		request.Execute(TestStartupRunning, rejected, unexpected)
		AssertEqual(counts.unexpected, 1, "Returning from a running loop invokes the stop/fault path")
		AssertEqual(counts.rejected, 4, "Unexpected running-loop return cannot unlock idle startup controls")

		request := nm_StartSession.Reserve("local")
		request.Execute((active) => nm_StartSession.Cancel(), rejected, unexpected)
		AssertEqual(counts.rejected, 4, "Stop cancellation cannot re-enable controls through startup finally")
		Assert(!nm_StartSession.Current, "Cancelled startup stays closed")

		IniWrite 0, "settings\nm_config.ini", "Settings", "IgnoreIncorrectRobloxSettings"
		nm_IgnoreStartupSettings(false)
		Assert(IgnoreIncorrectRobloxSettings = 1 && IniRead("settings\nm_config.ini", "Settings", "IgnoreIncorrectRobloxSettings") = 0,
			"Session override changes memory without silently remembering it")
		IgnoreIncorrectRobloxSettings := 0
		nm_IgnoreStartupSettings(true)
		Assert(IgnoreIncorrectRobloxSettings = 1 && IniRead("settings\nm_config.ini", "Settings", "IgnoreIncorrectRobloxSettings") = 1,
			"Remembered override persists before updating memory")
		IgnoreIncorrectRobloxSettings := 0
		FileMove "settings\nm_config.ini", "settings\startup-config-backup.ini"
		try {
			DirCreate "settings\nm_config.ini"
			AssertDeliveryError(() => nm_IgnoreStartupSettings(true), "Real override persistence failure propagates")
			AssertEqual(IgnoreIncorrectRobloxSettings, 0, "Failed remembered override cannot authorize the current session")
		} finally {
			DirDelete "settings\nm_config.ini"
			FileMove "settings\startup-config-backup.ini", "settings\nm_config.ini"
		}
	} finally nm_StartSession.Cancel()
}

TestStartupReject(mode, request) {
	AssertEqual(request.Mode, mode, "Scheduled mode survives until callback execution")
	AssertEqual(request.Phase, "starting", "Preflight owns starting phase")
	Assert(!nm_StartSession.Running() && !nm_StartSession.Reserve("remote"), "Starting phase rejects pause/background work and reentrant starts")
}
TestStartupThrow(*) {
	throw Error("Fixture preflight failure")
}
TestStartupRunning(request) {
	request.MarkRunning()
	Assert(nm_StartSession.Running() && !nm_StartSession.Reserve("local"), "Running phase remains exclusively owned")
}
