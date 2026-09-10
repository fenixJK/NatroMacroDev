class WatchdogProcessFixture {
	__New(events, ready := false, alive := true, failClose := false) {
		this.Events := events, this.IsReady := ready, this.Alive := alive, this.FailClose := failClose
	}
	Running() => this.Alive
	Ready() => this.IsReady ? 123 : 0
	Close() {
		this.Events.Push("close")
		if this.FailClose
			throw Error("Fixture cannot confirm termination")
		this.Alive := false
	}
	Release() => this.Events.Push("release")
}
TestWatchdogRecovery() {
	clock := {now: 0}, events := []
	watch := nm_WatchdogRecovery(() => clock.now, (ms) => clock.now += ms)
	closeMain := () => events.Push("main"), closePlayers := () => events.Push("players")
	AssertEqual(watch.Run(closeMain, closePlayers, () => WatchdogProcessFixture(events, true)), 123, "Ready replacement returns its own GUI")
	AssertEqual(JoinArray(events, ","), "main,players,release", "Ready macro survives handle release after ordered cleanup")
	Loop 2
		watch.Run(closeMain, closePlayers, () => WatchdogProcessFixture(events, true))
	AssertDeliveryError(() => watch.Run(closeMain, closePlayers, () => WatchdogProcessFixture(events, true)), "Healthy-looking replacements still consume rolling crash-loop budget")
	clock.now := 1800000
	AssertEqual(watch.Run(closeMain, closePlayers, () => WatchdogProcessFixture(events, true)), 123, "Rolling budget expires at its monotonic boundary")
	AssertEqual(watch.Launches.Length, 1, "Expired attempts do not accumulate")

	events := [], clock.now := 0
	watch := nm_WatchdogRecovery(() => clock.now, (ms) => clock.now += ms)
	AssertDeliveryError(() => watch.Run(closeMain, closePlayers, () => WatchdogProcessFixture(events)), "Hung startup exhausts three finite attempts")
	AssertEqual(clock.now, 900000, "Three hung attempts each consume at most five minutes of fixture time")
	AssertEqual(JoinArray(events, ","), "main,players,close,release,main,players,close,release,main,players,close,release", "Every failed replacement is stopped before the next launch")
	AssertEqual(watch.Launches.Length, 3, "Failure attempts consume rolling budget")

	events := [], clock.now := 0
	watch := nm_WatchdogRecovery(() => clock.now, (ms) => clock.now += ms)
	AssertDeliveryError(() => watch.Run(closeMain, closePlayers, () => WatchdogProcessFixture(events, false, false, true)), "Unconfirmed failed-process cleanup aborts recovery")
	AssertEqual(watch.Launches.Length, 1, "Cannot launch another macro after cleanup failure")
	AssertEqual(JoinArray(events, ","), "main,players,close", "Failed cleanup retains its process handle")

	events := [], clock.now := 0
	watch := nm_WatchdogRecovery(() => clock.now, (ms) => clock.now += ms)
	AssertDeliveryError(() => watch.Run(WatchdogFixtureThrow, closePlayers, () => WatchdogProcessFixture(events, true)), "Unverified main cleanup aborts recovery before player cleanup or launch")
	AssertEqual(events.Length, 0, "No further actions follow unsafe cleanup")
	watch := nm_WatchdogRecovery(() => clock.now, (ms) => clock.now += ms)
	AssertDeliveryError(() => watch.Run(closeMain, closePlayers, WatchdogFixtureThrow), "Failed process creation is bounded")
	AssertEqual(watch.Launches.Length, 3, "Launch failures consume all three attempts")
}
WatchdogFixtureThrow(*) {
	throw Error("Fixture watchdog failure")
}
