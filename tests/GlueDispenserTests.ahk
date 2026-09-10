TestGlueDispenser() {
	global TestNow := 3000000, LastTestStatus
	for stage in ["reset", "open", "travel", "find", "use", "close", "approach", "interact"] {
		GlueFixtureReset()
		surface := GlueVisitFixture(), surface.Results[stage] := [false, false]
		AssertEqual(nm_GlueDispenser.Run(surface), 0, "Rejected stage cannot commit: " stage)
		AssertEqual(IniRead("settings\nm_config.ini", "Collect", "LastGlueDis"), 123, "Rejected visit preserves cooldown")
		Assert(InStr(LastTestStatus, "Unconfirmed:") && InStr(LastTestStatus, "retry in 5 minutes"), "Early exits publish recovery")
		AssertEqual(surface.Count("stop"), 1, "Visit cleanup runs on rejection")
		expectedUses := stage = "use" || stage = "close" || stage = "approach" || stage = "interact" ? 1 : 0
		AssertEqual(surface.Count("use"), expectedUses, "No repeated or premature gumdrop input")
		AssertEqual(surface.Count("approach"), stage = "approach" || stage = "interact" ? 1 : 0, "No approach after failed close")
		AssertEqual(surface.Count("interact"), stage = "interact" ? 1 : 0, "Later actions require every precondition")
		AssertEqual(surface.Count("reset"), stage = "travel" || stage = "find" ? 2 : 1, "Only failures before item input retry")
		before := surface.Trace.Length
		AssertEqual(nm_GlueDispenser.Run(surface), 0, "Immediate scheduler revisit is deferred")
		AssertEqual(surface.Trace.Length, before, "Backoff performs no cleanup or game actions")
	}
	; Closing must also succeed before a second attempt after travel/search failure.
	for stage in ["travel", "find"] {
		GlueFixtureReset()
		surface := GlueVisitFixture(), surface.Results[stage] := [false], surface.Results["close"] := [false]
		AssertEqual(nm_GlueDispenser.Run(surface), 0, "Uncertain cleanup cannot start a new trip")
		AssertEqual(surface.Count("reset"), 1, "Failed recovery close ends the visit")
		AssertEqual(surface.Count("use"), 0, "No spending after uncertain recovery")
	}
	for retryStage in ["", "travel", "find"] {
		GlueFixtureReset()
		surface := GlueVisitFixture()
		if retryStage
			surface.Results[retryStage] := [false, true]
		AssertEqual(nm_GlueDispenser.Run(surface), TestNow, "Observed interaction returns persisted timestamp")
		AssertEqual(IniRead("settings\nm_config.ini", "Collect", "LastGlueDis"), TestNow, "Successful interaction persists cooldown")
		AssertEqual(nm_CollectionRecovery.Read("LastGlueDis")[3], TestNow, "Recovery records interaction")
		AssertEqual(surface.Count("use"), 1, "At most one gumdrop use even after a preparatory retry")
		AssertEqual(surface.Count("interact"), 1, "Only one dispenser interaction")
		AssertEqual(surface.Count("stop"), 1, "Successful visit also releases movement")
		Assert(InStr(LastTestStatus, "Interacted:") && !InStr(LastTestStatus, "Collected:"), "Interaction is not reported as reward proof")
	}
	for stage in ["reset", "open", "travel", "find", "use", "close", "approach", "interact", "stop"] {
		GlueFixtureReset()
		surface := GlueVisitFixture(), surface.ThrowStage := stage
		if stage = "stop"
			surface.Results["open"] := [false]
		AssertDeliveryError(() => nm_GlueDispenser.Run(surface), "Unexpected errors propagate: " stage)
		AssertEqual(surface.Count("stop"), 1, "Exceptions still attempt movement cleanup")
		Assert(!nm_CollectionRecovery.Ready("LastGlueDis"), "Interrupted visit retains backoff")
		AssertEqual(IniRead("settings\nm_config.ini", "Collect", "LastGlueDis"), 123, "Exception cannot publish interaction")
		Assert(InStr(LastTestStatus, "Unconfirmed:"), "Failure is reported even when movement cleanup throws")
	}
}

GlueFixtureReset() {
	try IniDelete "settings\nm_config.ini", "CollectionRecovery", "LastGlueDis"
	IniWrite 123, "settings\nm_config.ini", "Collect", "LastGlueDis"
}

class GlueVisitFixture {
	__New() {
		this.Trace := [], this.Results := Map(), this.ThrowStage := "", this.Item := {fixture: true}
	}
	Step(stage) {
		this.Trace.Push(stage)
		if this.ThrowStage = stage
			throw Error("Injected glue visit " stage)
		if this.Results.Has(stage) && this.Results[stage].Length
			return this.Results[stage].RemoveAt(1)
		return true
	}
	Count(stage) {
		total := 0
		for entry in this.Trace
			if entry = stage
				total++
		return total
	}
	Reset() => this.Step("reset")
	Menu(tab) => this.Step(tab ? "open" : "close")
	Travel(attempt) => this.Step("travel")
	Find() => this.Step("find") ? this.Item : 0
	Use(item) {
		Assert(item == this.Item, "Use receives the exact located item observation")
		return this.Step("use")
	}
	Approach() => this.Step("approach")
	Interact() => this.Step("interact")
	StopWalk() => this.Step("stop")
}
