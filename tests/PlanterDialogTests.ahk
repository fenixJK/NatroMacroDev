class PlanterDialogFixture {
	__New(frames, press := true, click := true) {
		this.Frames := frames, this.Tick := 0, this.Reads := 0, this.Presses := 0, this.Clicks := []
		this.PressResult := press, this.ClickResult := click
	}
	Clock() => this.Tick
	Wait(ms) => this.Tick += ms
	Observe() => this.Frames[Min(++this.Reads, this.Frames.Length)]
	Press(frame) => (this.Presses++, this.PressResult)
	Click(frame, choice) => (this.Clicks.Push(choice), this.ClickResult)
}
DialogFrame(e := false, yes := false, no := false, blocked := false) => {valid: true, e: e, yes: yes, no: no, blocked: blocked}
TestPlanterDialog() {
	ready := DialogFrame(true), clear := DialogFrame(), dialog := DialogFrame(false, true, true)
	fixture := PlanterDialogFixture([ready, clear, clear, dialog, clear])
	AssertEqual(nm_PlanterDialog.Run(fixture, true), "declined", "Delayed dialog respects full-grown-only policy")
	Assert(fixture.Clicks.Length = 1 && fixture.Clicks[1] = "no", "Decline is clicked once")
	fixture := PlanterDialogFixture([ready, dialog, dialog, dialog, clear])
	AssertEqual(nm_PlanterDialog.Run(fixture, false), "accepted", "Accepted dialog must disappear")
	Assert(fixture.Presses = 1 && fixture.Clicks.Length = 1 && fixture.Clicks[1] = "yes", "Lag cannot repeat E or Yes")
	fixture := PlanterDialogFixture([ready, dialog])
	AssertEqual(nm_PlanterDialog.Run(fixture, false, 500), "unconfirmed", "Stuck dialog does not proceed to state clearing")
	AssertEqual(fixture.Clicks.Length, 1, "Stuck dialog is not clicked repeatedly")
	fixture := PlanterDialogFixture([ready, {valid: false}])
	AssertEqual(nm_PlanterDialog.Run(fixture, false), "unconfirmed", "Lost focus/geometry preserves state")
	fixture := PlanterDialogFixture([ready, DialogFrame(false, false, false, true)])
	AssertEqual(nm_PlanterDialog.Run(fixture, false), "unconfirmed", "Disconnect/death blocks continuation")
	fixture := PlanterDialogFixture([ready, DialogFrame(false, true, false)])
	AssertEqual(nm_PlanterDialog.Run(fixture, false), "unconfirmed", "Partial dialog recognition is not absence")
	fixture := PlanterDialogFixture([ready, dialog], true, false)
	AssertEqual(nm_PlanterDialog.Run(fixture, false), "unconfirmed", "Failed current-frame click preserves state")
	fixture := PlanterDialogFixture([dialog])
	AssertEqual(nm_PlanterDialog.Run(fixture, false), "unconfirmed", "Existing unrelated dialog prevents E input")
	AssertEqual(fixture.Presses, 0, "No E input over an existing dialog")
	fixture := PlanterDialogFixture([ready, clear])
	AssertEqual(nm_PlanterDialog.Run(fixture, false, 500), "no_dialog", "No-dialog path is explicitly distinct from confirmation")
	fixture := PlanterDialogFixture([ready])
	AssertEqual(nm_PlanterDialog.Run(fixture, false, 500), "unconfirmed", "Unchanged E prompt is not a completed interaction")

	nm_PlanterRecovery.Clear("Harvest3")
	calls := 0
	Uncertain(slot) => (calls++, 3)
	AssertEqual(nm_PlanterRecovery.Harvest(3, "PlasticPlanter", "Rose", Uncertain), 0, "Uncertain input is reported as unconfirmed")
	AssertEqual(calls, 1, "Uncertain input cannot trigger four more harvest attempts")
	Assert(!nm_PlanterRecovery.Ready("Harvest3", "PlasticPlanter:Rose", nowUnix()), "Uncertainty retains persistent recovery delay")
}
