TestResetRecovery() {
	for outcomes in [[1], [0, 0, 1]] {
		fixture := ResetRecoveryFixture(outcomes), recovery := fixture.Controller()
		AssertEqual(recovery.Run(ObjBindMethod(fixture, "Attempt"), ObjBindMethod(fixture, "Cleanup")), 1, "Only confirmed recovery returns success")
		AssertEqual(fixture.Calls, outcomes.Length, "No attempt follows confirmation")
		AssertEqual(fixture.Cleanups, fixture.Calls, "Every attempt releases movement before continuing")
	}
	fixture := ResetRecoveryFixture([0]), recovery := fixture.Controller()
	AssertResetExhausted(() => recovery.Run(ObjBindMethod(fixture, "Attempt"), ObjBindMethod(fixture, "Cleanup")), "Persistent misses end")
	AssertEqual(fixture.Calls, 5, "Persistent miss cannot reset indefinitely")
	AssertEqual(fixture.Cleanups, 5, "Final failed attempt also cleans up")
	fixture := ResetRecoveryFixture([-1]), recovery := fixture.Controller()
	AssertResetExhausted(() => recovery.Run(ObjBindMethod(fixture, "Attempt"), ObjBindMethod(fixture, "Cleanup")), "Unknown is not a retryable miss")
	AssertEqual(fixture.Calls, 1, "Unreadable observation cannot trigger another attempt")
	for outcome in [0, 1] {
		fixture := ResetRecoveryFixture([outcome]), fixture.Cost := 100, recovery := fixture.Controller(100)
		AssertResetExhausted(() => recovery.Run(ObjBindMethod(fixture, "Attempt"), ObjBindMethod(fixture, "Cleanup")), "Late callback cannot extend deadline or return success")
		AssertEqual(fixture.Calls, 1, "Deadline prevents another attempt")
		AssertEqual(fixture.Cleanups, 1, "Late callback cleanup")
	}
	fixture := ResetRecoveryFixture([0]), fixture.Cost := 40, recovery := fixture.Controller(100)
	AssertResetExhausted(() => recovery.Run(ObjBindMethod(fixture, "Attempt"), ObjBindMethod(fixture, "Cleanup")), "Attempts share one elapsed budget")
	AssertEqual(fixture.Calls, 3, "Retries do not receive a new deadline")
	fixture := ResetRecoveryFixture([1]), fixture.Cost := 50, fixture.CleanupCost := 50, recovery := fixture.Controller(100)
	AssertResetExhausted(() => recovery.Run(ObjBindMethod(fixture, "Attempt"), ObjBindMethod(fixture, "Cleanup")), "Cleanup time belongs to the same recovery budget")
	AssertEqual(fixture.Cleanups, 1, "Expired cleanup is not repeated")
	fixture := ResetRecoveryFixture([0]), recovery := fixture.Controller(100)
	AssertResetExhausted(() => recovery.Wait(1000), "Wait clips to remaining budget")
	AssertEqual(fixture.Tick, 100, "No excess wait time")
	fixture := ResetRecoveryFixture([0]), recovery := fixture.Controller(1000)
	Assert(!recovery.WaitFor(() => false, 50), "Missing worker state expires")
	AssertEqual(fixture.Tick, 50, "Worker wait observes its stage limit")
	Assert(recovery.WaitFor(() => fixture.Tick >= 75, 100), "Worker state arrives within stage budget")
	AssertEqual(fixture.Tick, 75, "Wait ends on transition")
	fixture := ResetRecoveryFixture([0]), fixture.Throws := true, recovery := fixture.Controller()
	AssertDeliveryError(() => recovery.Run(ObjBindMethod(fixture, "Attempt"), ObjBindMethod(fixture, "Cleanup")), "Unexpected attempt error propagates")
	AssertEqual(fixture.Cleanups, 1, "Exception stops movement")
	AssertThrows(() => nm_ResetRecovery(,, 0), "Zero deadline rejected")
	AssertThrows(() => nm_ResetRecovery(,,, 0), "Zero attempt cap rejected")
	AssertResetExhausted(() => nm_ResetImageSearch(0, 0), "Native invalid capture/needle is an error")
}

AssertResetExhausted(action, message) {
	try action.Call()
	catch nm_ResetExhausted
		return
	throw Error(message)
}

class ResetRecoveryFixture {
	__New(outcomes) {
		this.Outcomes := outcomes.Clone(), this.Last := 0, this.Tick := this.Calls := this.Cleanups := this.Cost := 0
		this.Throws := false, this.CleanupCost := 0
	}
	Controller(limitMs := 1000) => nm_ResetRecovery(() => this.Tick, (ms) => this.Tick += ms, limitMs)
	Attempt(recovery) {
		AssertEqual(this.Calls, this.Cleanups, "Previous attempt cleaned up before retry")
		this.Calls++, this.Tick += this.Cost
		if this.Throws
			throw Error("Injected reset failure")
		if this.Outcomes.Length
			this.Last := this.Outcomes.RemoveAt(1)
		return this.Last
	}
	Cleanup() {
		this.Cleanups++, this.Tick += this.CleanupCost
	}
}
