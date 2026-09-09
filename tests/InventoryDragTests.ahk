TestPointerLease() {
	gate := nm_PointerLease(), events := []
	first := gate.Begin()
	Assert(!gate.Begin(), "An active pointer operation rejects a second owner")
	Assert(gate.Press(first, (*) => events.Push("down")), "Owner presses once")
	Assert(!gate.Press(first, (*) => events.Push("duplicate")), "Duplicate down denied")
	gate.Cancel((*) => events.Push("up"))
	Assert(!gate.Owns(first) && !gate.Held, "Pause/cancel invalidates suspended owner and releases held input")
	second := gate.Begin()
	Assert(second != first, "Cancellation cannot revive an old token")
	gate.Press(second, (*) => events.Push("down"))
	gate.Release(first, (*) => events.Push("wrong up"))
	Assert(gate.Owns(second) && gate.Held, "Old finally cannot release a newer drag")
	gate.Release(second, (*) => events.Push("up"))
	gate.Cancel((*) => events.Push("duplicate up"))
	AssertEqual(events.Length, 4, "Exactly one release per acquired press")
	third := gate.Begin()
	try gate.Press(third, (*) => FailPointerPress())
	catch Error
		gate.Cancel((*) => events.Push("exception up"))
	Assert(!gate.Held && !gate.Active && events.Length = 5, "Throwing native press remains releasable")
}
FailPointerPress() {
	throw Error("Injected press failure")
}

class TestDragPointer {
	__New(surface) {
		this.Surface := surface, this.Gate := nm_PointerLease(), this.Token := 0
		this.Events := [], this.Waits := 0, this.CancelOnWait := 0, this.ChangeOnWait := 0
		this.ThrowOnTarget := false, this.UserHolding := false
	}
	Begin() => !this.UserHolding && (this.Token := this.Gate.Begin())
	Current(snapshot) => this.Gate.Owns(this.Token) && !this.UserHolding && this.Surface.Current(snapshot)
	Move(snapshot, x, y) {
		if !this.Current(snapshot)
			return false
		if this.ThrowOnTarget && this.Gate.Held
			throw Error("Injected target-move failure")
		this.Events.Push("move")
		return true
	}
	Down(snapshot) => this.Current(snapshot) && this.Gate.Press(this.Token, (*) => this.Events.Push("down"))
	Up() => this.Gate.Release(this.Token, (*) => this.Events.Push("up"))
	Wait(milliseconds) {
		this.Waits++
		if this.Waits = this.CancelOnWait
			this.Gate.Cancel((*) => this.Events.Push("up"))
		if this.Waits = this.ChangeOnWait
			this.Surface.Valid := false
	}
}

TestDragFixture() {
	surface := TestInventorySurface([{state: "found", y: 50}, {state: "found", y: 50}])
	surface.Client := {hwnd: 1, root: 1, pid: 2, x: 100, y: 100, width: 800, height: 600, dpi: 96, monitor: 1, style: 0, exstyle: 0, offset: 36}
	point := nm_InventorySearchEngine(surface).Search("gumdrops")
	return {surface: surface, pointer: TestDragPointer(surface), point: point}
}

TestInventoryDrag() {
	f := TestDragFixture()
	AssertEqual(f.point.Length, 2, "Search result retains two-coordinate API")
	Assert(nm_InventoryDrag.Run(f.surface, f.pointer, f.point, 400, 300), "Fresh unchanged item permits drag")
	AssertEqual(f.surface.Reads, 2, "Item is re-observed immediately before drag")
	AssertEqual(f.pointer.Events.Length, 4, "One source move, down, target move and up")
	Assert(!f.pointer.Gate.Active && !f.pointer.Gate.Held, "Successful drag releases its lease and button")
	for scenario in ["missing", "unknown", "moved", "boundary", "geometry", "physical"] {
		f := TestDragFixture()
		switch scenario {
			case "missing", "unknown": f.surface.observations[1] := {state: scenario}
			case "moved": f.surface.observations[1].y++
			case "boundary": f.surface.Height++
			case "geometry": f.surface.Valid := false
			case "physical": f.pointer.UserHolding := true
		}
		Assert(!nm_InventoryDrag.Run(f.surface, f.pointer, f.point, 400, 300), scenario " rejects stale/unavailable input")
		AssertEqual(f.pointer.Events.Length, 0, scenario " does not move or press")
	}
	for property in ["hwnd", "root", "pid", "x", "y", "width", "height", "dpi", "monitor", "style", "exstyle"] {
		f := TestDragFixture(), destination := f.point.Context.snapshot.Clone(), destination.%property%++
		Assert(!nm_InventoryDrag.Run(f.surface, f.pointer, f.point, 400, 300, destination), "Selected slot rejects changed " property)
		AssertEqual(f.pointer.Events.Length, 0, "Changed slot geometry causes no pointer input")
	}
	for target in [[-1, 300], [400, -1], [800, 300], [400, 600]] {
		f := TestDragFixture()
		Assert(!nm_InventoryDrag.Run(f.surface, f.pointer, f.point, target*), "Out-of-client target rejected")
	}
	for boundary in [1, 2] {
		for interruption in ["CancelOnWait", "ChangeOnWait"] {
			f := TestDragFixture(), f.pointer.%interruption% := boundary
			Assert(!nm_InventoryDrag.Run(f.surface, f.pointer, f.point, 400, 300), interruption " interrupts held drag")
			AssertEqual(f.pointer.Events.Length, boundary + 2, "No moves after invalidation; release still occurs")
			AssertEqual(f.pointer.Events[-1], "up", "Interrupted drag ends in release")
			Assert(!f.pointer.Gate.Held, "No held button after interruption")
		}
	}
	f := TestDragFixture(), f.pointer.ThrowOnTarget := true, threw := false
	try nm_InventoryDrag.Run(f.surface, f.pointer, f.point, 400, 300)
	catch Error
		threw := true
	Assert(threw && !f.pointer.Gate.Held && f.pointer.Events[-1] = "up", "Exception unwinds held input")
	f := TestDragFixture()
	Assert(!nm_InventoryDrag.Run(f.surface, f.pointer, [30, 276], 400, 300), "Unverified legacy point is not draggable")
}
