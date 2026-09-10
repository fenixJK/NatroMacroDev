; One recovery has a finite launch count and a monotonic elapsed-time budget.
; Checks are cooperative: an in-flight Windows/COM call cannot be preempted here.
class nm_ReconnectExhausted extends Error {
}
class nm_ReconnectSession {
	__New(privateSlots, allowPublic, clock := unset, sleeper := unset, limitMs := 1800000) {
		this.Clock := IsSet(clock) ? clock : () => DllCall("GetTickCount64", "UInt64")
		this.Sleeper := IsSet(sleeper) ? sleeper : (ms) => Sleep(ms)
		this.Started := this.Clock.Call(), this.Deadline := this.Started + limitMs
		this.PrivateSlots := privateSlots.Clone(), this.AllowPublic := allowPublic
		this.Attempts := 0, this.Maximum := 5 * (privateSlots.Length + !!allowPublic)
		this.Stage := "starting", this.LastFailure := "No eligible server"
	}
	Check() {
		if this.Clock.Call() >= this.Deadline
			throw nm_ReconnectExhausted("Reconnect time limit reached during " this.Stage ". Last result: " this.LastFailure)
	}
	Next() {
		this.Check()
		if this.Attempts >= this.Maximum
			throw nm_ReconnectExhausted("Reconnect exhausted " this.Attempts " launches. Last result: " this.LastFailure)
		this.Attempts++
		this.Stage := "launch"
		return nm_SelectReconnectServer(this.PrivateSlots, this.Attempts, this.AllowPublic)
	}
	Wait(ms) {
		this.Check()
		this.Sleeper.Call(Max(0, Min(ms, this.Deadline - this.Clock.Call())))
		this.Check()
	}
	ElapsedSeconds() => Max(0, (this.Clock.Call() - this.Started) // 1000)
	Join(launch, observe) {
		this.Check()
		launch.Call()
		this.Check()
		this.Stage := "window", stageDeadline := this.Clock.Call() + 240000
		Loop {
			this.Check()
			if this.Clock.Call() >= stageDeadline {
				this.LastFailure := this.Stage " timeout"
				return false
			}
			observation := observe.Call()
			this.Check()
			; A late callback cannot turn an expired stage into success.
			if this.Clock.Call() >= stageDeadline {
				this.LastFailure := this.Stage " timeout"
				return false
			}
			if observation = "disconnected" || (observation = "missing" && this.Stage != "window") {
				this.LastFailure := "disconnected during join"
				return false
			}
			if observation = "loaded"
				return true
			if observation != "missing" && this.Stage = "window"
				this.Stage := "game", stageDeadline := this.Clock.Call() + 180000
			if observation = "loading" && this.Stage = "game"
				this.Stage := "loading", stageDeadline := this.Clock.Call() + 180000
			if observation != "missing" && observation != "unknown" && observation != "loading"
				throw ValueError("Invalid reconnect observation")
			this.Wait(Min(1000, stageDeadline - this.Clock.Call()))
		}
	}
}

; Search all signals in one owned frame. A missing loading image is inconclusive.
class nm_ReconnectObservation {
	static Classify(disconnected, loading, loaded) {
		for result in [disconnected, loading, loaded]
			if result != 0 && result != 1
				throw Error("Reconnect image observation failed")
		return disconnected ? "disconnected" : loaded ? "loaded" : loading ? "loading" : "unknown"
	}
	static Read() {
		global bitmaps
		hwnd := GetRobloxHWND()
		if !hwnd
			return "missing"
		if !ActivateRoblox(hwnd) || !(snapshot := nm_ClientSnapshot(hwnd)) || snapshot.height <= 30
			return "unknown"
		capture := Gdip_BitmapFromScreen(snapshot.x "|" snapshot.y + 30 "|" snapshot.width "|" snapshot.height - 30)
		if !capture
			throw Error("Reconnect frame capture failed")
		try {
			result := this.Classify(Gdip_ImageSearch(capture, bitmaps["disconnected"], , , , , , 2),
				Gdip_ImageSearch(capture, bitmaps["loading"], , , , , 150, 4),
				Gdip_ImageSearch(capture, bitmaps["science"], , , , , 150, 2))
			if !nm_WindowOwnsFocus(hwnd) || !nm_SameClient(snapshot, nm_ClientSnapshot(hwnd))
				return "unknown"
			return result
		} finally Gdip_DisposeImage(capture)
	}
}
