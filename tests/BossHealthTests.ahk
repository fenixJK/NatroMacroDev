BossHealthSamples(value) => [[value], [value], [value], [value], [value]]

TestBossHealthEstimation() {
	AssertEqual(nm_BossHealthSession.Consensus([[90], [90.4], [89.6], [50], [20]]), 90, "Three agreeing observations reject two outliers")
	for frames in [[], [[90]], [[90], [90], [], [], []], [[20], [20], [90], [90], []],
		[[90, 89], [90, 89], [90, 89], [90], [90]], BossHealthSamples(100), BossHealthSamples(0),
		BossHealthSamples(-1), BossHealthSamples(101), BossHealthSamples("unreadable")]
		AssertEqual(nm_BossHealthSession.Consensus(frames), 0, "Missing, inconsistent or ambiguous observations have no estimate")
	AssertEqual(nm_BossHealthSession.Consensus([[100, 90], [100, 90], [100, 90], [], []]), 90, "Full planter-like bars do not override a unique damaged bar")
	session := nm_BossHealthSession()
	baseline := session.Plan(BossHealthSamples(90), 1000)
	Assert(baseline.baseline && baseline.rate = 0, "First observed health establishes baseline without inventing damage")
	session.Commit(baseline)
	AssertEqual(session.ObservedAt, 1000, "Baseline records its observation time")
	AssertEqual(session.Plan(BossHealthSamples(89), 61000), 0, "Small change retains baseline until measurable damage")
	AssertEqual(session.Plan([[], [], [], [], []], 61000), 0, "Unreadable frames retain baseline")
	AssertEqual(session.ObservedAt, 1000, "Rejected observation does not reset elapsed interval")
	plan := session.Plan(BossHealthSamples(80), 121000)
	AssertEqual(plan.rate, 5, "Ten percent damage over two minutes is five percent per minute")
	AssertEqual(plan.remainingSeconds, 960, "Remaining time is expressed in seconds")
	AssertEqual(plan.elapsedMs, 120000, "Elapsed interval matches last committed observation")
	session.Commit(plan)
	rejected := false
	try session.Commit(plan)
	catch Error
		rejected := true
	Assert(rejected && session.Revision = 2, "Same observation cannot commit twice")
	for tick in [121000, 120999, -1, "invalid"]
		AssertEqual(session.Plan(BossHealthSamples(70), tick), 0, "Nonpositive or invalid time difference cannot divide or reset")
	rebase := session.Plan(BossHealthSamples(95), 181000)
	Assert(rebase.baseline && rebase.rate = 0, "Rising health establishes a new baseline without a negative damage estimate")
	session.Commit(rebase)
	AssertEqual(session.Plan(BossHealthSamples(90), 241000).rate, 5, "Rate starts from rebased observed health")
	independent := nm_BossHealthSession()
	Assert(independent.Plan(BossHealthSamples(50), 241000).baseline, "New fight cannot inherit another fight's baseline")
	AssertEqual(nm_CombatDuration(125.4), "2m 5s", "Sub-hour interval uses seconds")
	AssertEqual(nm_CombatDuration(3660), "1h 1m 0s", "Long estimates format hours and minutes consistently")
	AssertEqual(nm_CombatDuration(3599.6), "1h 0m 0s", "Rounding carries into the next hour instead of displaying sixty seconds")
}

class BossHealthTestControl {
	__New() => (this.Text := "", this.Value := 0)
	Opt(*) => 0
}

TestBossHealthReporting() {
	global MainGui, InputSnailHealth, InputChickHealth, CommandoChickHealth, ChickLevel, LastTestStatus
	InputSnailHealth := InputChickHealth := 100
	CommandoChickHealth := Map(7, 1000000), ChickLevel := 7
	AssertEqual(nm_CommandoMaximumHealth(7), 1000000, "Configured level uses the bundled health table")
	for level in [20, 21, 25]
		AssertEqual(nm_CommandoMaximumHealth(level), 10000000, "Supported level beyond the table uses consistent startup fallback")
	for name in ["Snail", "Chick"] {
		MainGui[name "HealthText"] := BossHealthTestControl()
		MainGui[name "HealthEdit"] := BossHealthTestControl()
	}
	originalRead := nm_BossHealthReporting.Read, originalTick := nm_BossHealthReporting.Tick, originalWait := nm_BossHealthReporting.Wait
	try {
		nm_BossHealthReporting.Wait := (*) => 0
		for name in ["Snail", "Chick"] {
			session := nm_BossHealthSession(), sampleTick := 1000
			nm_BossHealthReporting.Tick := () => sampleTick
			frameQueue := BossHealthSamples(90)
			nm_BossHealthReporting.Read := () => frameQueue.RemoveAt(1)
			Assert(nm_KillTimeEstimation(name, session), name " returns explicit baseline acceptance")
			Assert(InStr(LastTestStatus, "Fresh baseline"), name " does not report invented damage on first observation")
			AssertEqual(IniRead("settings\nm_config.ini", "Collect", "Input" name "Health"), 90, name " baseline persisted")
			AssertEqual(Input%name%Health, 90, name " in-memory health agrees with persistence")
			AssertEqual(MainGui[name "HealthText"].Text, "90.00%", name " displayed health agrees with observation")
			AssertEqual(MainGui[name "HealthEdit"].Value, name = "Snail" ? 27000000 : 900000, name " absolute health display refreshed")
			frameQueue := [[], [], [], [], []], sampleTick := 61000
			Assert(!nm_KillTimeEstimation(name, session), name " unknown observations return explicit false")
			AssertEqual(session.ObservedAt, 1000, name " failed report preserves damage interval")
			frameQueue := BossHealthSamples(80), sampleTick := 121000
			Assert(nm_KillTimeEstimation(name, session), name " measured report accepted")
			Assert(InStr(LastTestStatus, "Damage: 5.0000%") && InStr(LastTestStatus, "16m 0s") && InStr(LastTestStatus, "Observation interval: 2m 0s"), name " report has consistent rate and duration units")
			AssertEqual(session.ObservedAt, 121000, name " accepted report advances interval")
			AssertEqual(Input%name%Health, 80, name " accepted report updates memory")
			session.Busy := true
			Assert(!nm_KillTimeEstimation(name, session), name " overlapping report does not scan or commit")
			session.Busy := false
		}
		AssertThrows(nm_KillTimeEstimation.Bind("unknown", nm_BossHealthSession()), "Unsupported family rejected before capture")
		; A real failed settings write must not advance the baseline or UI.
		session := nm_BossHealthSession(), sampleTick := 2000
		frameQueue := BossHealthSamples(70)
		storedHealth := InputSnailHealth
		FileMove "settings\nm_config.ini", "settings\boss-fixture-config.ini"
		try {
			DirCreate "settings\nm_config.ini"
			writeRejected := false
			try nm_KillTimeEstimation("Snail", session)
			catch Error
				writeRejected := true
			Assert(writeRejected && !session.Revision && !session.Busy, "INI failure preserves fresh baseline and releases active report")
			AssertEqual(InputSnailHealth, storedHealth, "INI failure does not publish uncommitted health")
		} finally {
			DirDelete "settings\nm_config.ini"
			FileMove "settings\boss-fixture-config.ini", "settings\nm_config.ini"
		}
		frameQueue := BossHealthSamples(70)
		Assert(nm_KillTimeEstimation("Snail", session), "Report can be retried after a failed write")
		nm_BossHealthReporting.Read := BossHealthThrow
		observationRejected := false
		try nm_KillTimeEstimation("Snail", session)
		catch Error
			observationRejected := true
		Assert(observationRejected && !session.Busy && session.Revision = 1, "Capture exception releases report and preserves committed baseline")
	} finally {
		nm_BossHealthReporting.Read := originalRead, nm_BossHealthReporting.Tick := originalTick, nm_BossHealthReporting.Wait := originalWait
	}
}

BossHealthThrow() {
	throw Error("Interrupted combat observation")
}
