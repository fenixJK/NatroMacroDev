TestAutoJellyOcr() {
	fixture := OcrWaitFixture(), operation := OcrWaitOperation(fixture, [0, 0, 1])
	AssertEqual(nm_OcrAsync.Wait(operation, fixture.Budget()), "recognized", "Completed OCR result returned")
	AssertEqual(operation.Results, 1, "GetResults called once on completion")
	AssertEqual(operation.Closed, 1, "Completed operation released once")
	for state in [2, 3, 99] {
		fixture := OcrWaitFixture(), operation := OcrWaitOperation(fixture, [state])
		AutoJellyExpectFailure(() => nm_OcrAsync.Wait(operation, fixture.Budget()))
		AssertEqual(operation.Results, 0, "Failed or invalid state never retrieves a result")
		AssertEqual(operation.Closed, 1, "Failed operation released")
	}
	fixture := OcrWaitFixture(), operation := OcrWaitOperation(fixture, [0])
	AutoJellyExpectFailure(() => nm_OcrAsync.Wait(operation, fixture.Budget(35)))
	AssertEqual(fixture.Tick, 35, "Stalled operation reaches finite total budget")
	AssertEqual(operation.Results, 0, "Stalled operation cannot publish a result")
	AssertEqual(operation.Closed, 1, "Stalled operation is handed to cancellation/cleanup")
	fixture := OcrWaitFixture(), fixture.CancelAt := 20, operation := OcrWaitOperation(fixture, [0])
	try {
		nm_OcrAsync.Wait(operation, fixture.Budget())
		throw Error("Expected cancellation")
	} catch nm_AutoJellyCancelled {
		AssertEqual(fixture.Tick, 20, "Cancellation checked between native polls")
	}
	AssertEqual(operation.Closed, 1, "Cancelled operation released")
	for mode in ["status", "result", "late-result"] {
		fixture := OcrWaitFixture(), operation := OcrWaitOperation(fixture, [1]), operation.Mode := mode
		AutoJellyExpectFailure(() => nm_OcrAsync.Wait(operation, fixture.Budget(50)))
		AssertEqual(operation.Closed, 1, "Throwing/late result still releases operation")
	}
	fixture := OcrWaitFixture(), budget := fixture.Budget(35)
	first := OcrWaitOperation(fixture, [0, 0, 1]), second := OcrWaitOperation(fixture, [0, 0, 1])
	nm_OcrAsync.Wait(first, budget)
	AutoJellyExpectFailure(() => nm_OcrAsync.Wait(second, budget))
	AssertEqual(fixture.Tick, 35, "Decode and recognition share one budget, not a fresh timeout each")
	AssertEqual(second.Results, 0, "Later stage cannot exceed total OCR time")
}

class OcrWaitFixture {
	__New() => (this.Tick := 0, this.CancelAt := 1.0e20)
	Budget(timeout := 100) => nm_OcrBudget(ObjBindMethod(this, "Check"), timeout, (() => this.Tick), ((ms) => this.Tick += ms))
	Check() {
		if this.Tick >= this.CancelAt
			throw nm_AutoJellyCancelled("Fixture cancellation")
	}
}
class OcrWaitOperation {
	__New(fixture, states) {
		this.Fixture := fixture, this.States := states, this.Reads := this.Results := this.Closed := 0, this.Mode := ""
	}
	Status() {
		if this.Mode = "status"
			throw Error("Fixture status failure")
		return this.States[Min(++this.Reads, this.States.Length)]
	}
	Result() {
		this.Results++
		if this.Mode = "result"
			throw Error("Fixture GetResults failure")
		if this.Mode = "late-result"
			this.Fixture.Tick += 1000
		return "recognized"
	}
	Close() => this.Closed++
}
