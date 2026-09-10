; A watchdog can replace the macro at most three times in a rolling half hour.
; Each attempt has five minutes, including cleanup and UI initialization.
class nm_WatchdogRecovery {
	__New(clock := unset, sleeper := unset) {
		this.Clock := IsSet(clock) ? clock : (() => DllCall("GetTickCount64", "UInt64"))
		this.Sleep := IsSet(sleeper) ? sleeper : ((ms) => Sleep(ms))
		this.Launches := []
	}
	Reserve() {
		now := this.Clock.Call()
		while this.Launches.Length && now - this.Launches[1] >= 1800000
			this.Launches.RemoveAt(1)
		if this.Launches.Length >= 3
			throw Error("Automatic recovery limit reached: three attempts in thirty minutes")
		this.Launches.Push(now)
	}
	Run(closeMain, closePlayers, launch) {
		Loop 3 {
			this.Reserve()
			deadline := this.Clock.Call() + 300000
			; Unconfirmed cleanup is fatal: do not launch another macro on top.
			closeMain.Call()
			closePlayers.Call()
			if this.Clock.Call() >= deadline
				throw Error("Automatic recovery cleanup exceeded its deadline")
			pending := 0, readyHwnd := 0
			try {
				pending := launch.Call()
				while pending.Running() && this.Clock.Call() < deadline {
					if readyHwnd := pending.Ready()
						break
					this.Sleep.Call(Max(1, Min(100, deadline - this.Clock.Call())))
				}
			} catch {
				readyHwnd := 0
			}
			if pending {
				; Release leaves a ready application alive. Failed attempts are
				; terminated through their creation handle before any next launch.
				if !readyHwnd || this.Clock.Call() >= deadline {
					pending.Close()
					readyHwnd := 0
				}
				pending.Release()
			}
			if readyHwnd
				return readyHwnd
		}
		throw Error("Automatic recovery failed after three attempts")
	}
}
