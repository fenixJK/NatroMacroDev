class ReconnectFixture {
	__New(sequence := unset, step := 0) {
		this.Tick := 0, this.Reads := 0, this.Launches := 0, this.Step := step
		this.Sequence := IsSet(sequence) ? sequence : ["missing"]
	}
	Clock() => this.Tick
	Wait(ms) => this.Tick += ms
	Launch() => this.Launches++
	Read() {
		this.Tick += this.Step, this.Reads++
		return this.Sequence[Min(this.Reads, this.Sequence.Length)]
	}
	Session(slots := unset, public := false, limit := 1800000) => nm_ReconnectSession(IsSet(slots) ? slots : [1], public,
		ObjBindMethod(this, "Clock"), ObjBindMethod(this, "Wait"), limit)
	Join(session) => session.Join(ObjBindMethod(this, "Launch"), ObjBindMethod(this, "Read"))
}
AssertReconnectExhausted(action, message) {
	try action.Call()
	catch nm_ReconnectExhausted
		return
	throw Error(message)
}
TestReconnectSession() {
	fixture := ReconnectFixture(), session := fixture.Session([1,4], true)
	Loop 15
		AssertEqual(session.Next(), A_Index <= 5 ? 1 : A_Index <= 10 ? 4 : 0, "Each eligible server gets five actual launches")
	AssertReconnectExhausted(ObjBindMethod(session, "Next"), "One server circuit must terminate")
	fixture := ReconnectFixture(), session := fixture.Session([4])
	Loop 5
		AssertEqual(session.Next(), 4, "Private-only retries never select public")
	AssertReconnectExhausted(ObjBindMethod(session, "Next"), "Private-only exhaustion stops")
	fixture := ReconnectFixture(), session := fixture.Session([], false)
	AssertReconnectExhausted(ObjBindMethod(session, "Next"), "No eligible server cannot launch")
	fixture := ReconnectFixture(), session := fixture.Session([], true)
	AssertEqual(session.Next(), 0, "Empty configuration supports public-only join")
	Assert(!fixture.Join(session), "Missing window times out")
	AssertEqual(fixture.Tick, 240000, "Missing window is bounded by elapsed four minutes")

	fixture := ReconnectFixture(["unknown"]), session := fixture.Session()
	session.Next()
	Assert(!fixture.Join(session) && fixture.Tick = 180000, "Unrecognized game frame times out after three minutes")
	fixture := ReconnectFixture(["loading", "unknown"]), session := fixture.Session()
	session.Next()
	Assert(!fixture.Join(session), "Disappearing loading image is not success")
	AssertEqual(fixture.Tick, 180000, "Repeated unknown frames cannot renew loading deadline")
	fixture := ReconnectFixture(["missing", "loading", "loaded"]), session := fixture.Session()
	session.Next()
	Assert(fixture.Join(session), "Positive loaded frame completes join")
	AssertEqual(fixture.Launches, 1, "Observations do not issue extra launches")
	fixture := ReconnectFixture(["loading", "disconnected"]), session := fixture.Session()
	session.Next()
	Assert(!fixture.Join(session) && fixture.Tick = 1000, "Disconnect consumes the current attempt immediately")
	fixture := ReconnectFixture(["loading", "missing"]), session := fixture.Session()
	session.Next()
	Assert(!fixture.Join(session), "Window disappearing during load consumes attempt")
	fixture := ReconnectFixture(["loaded"], 240000), session := fixture.Session()
	session.Next()
	Assert(!fixture.Join(session), "Late success cannot bypass a stage deadline")
	fixture := ReconnectFixture(["loaded"], 5000), session := fixture.Session([1], false, 5000)
	session.Next()
	AssertReconnectExhausted(() => fixture.Join(session), "Late callback cannot bypass total deadline")
	fixture := ReconnectFixture(), session := fixture.Session([1], false, 2500)
	AssertReconnectExhausted(() => session.Wait(10000), "Wait ends at aggregate deadline")
	AssertEqual(fixture.Tick, 2500, "Wait is clipped to the remaining budget")
	fixture := ReconnectFixture(), session := fixture.Session()
	fixture.Tick := 1800000, session.Stage := "hive claim"
	AssertReconnectExhausted(ObjBindMethod(session, "Check"), "Hive work shares the same total deadline")
	AssertEqual(nm_ReconnectObservation.Classify(0,0,0), "unknown", "No match is unknown")
	AssertEqual(nm_ReconnectObservation.Classify(1,1,1), "disconnected", "Disconnect takes precedence over other signals")
	AssertEqual(nm_ReconnectObservation.Classify(0,1,1), "loaded", "Positive loaded signal accepted")
	AssertDeliveryError(() => nm_ReconnectObservation.Classify(-1,0,1), "Native search error cannot become success")
}
