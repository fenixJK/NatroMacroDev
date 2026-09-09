; Own one pointer operation per process. Cancellation invalidates suspended work,
; and an old operation cannot release a newer operation's mouse button.
class nm_PointerLease {
	__New() => (this.Sequence := 0, this.Active := 0, this.Held := false)
	Begin() {
		if this.Active
			return 0
		return this.Active := ++this.Sequence
	}
	Owns(token) => token && token = this.Active
	Press(token, press) {
		if !this.Owns(token) || this.Held
			return false
		this.Held := true ; cleanup remains possible if sending throws
		press.Call()
		return true
	}
	Release(token, release) {
		if !this.Owns(token)
			return
		held := this.Held, this.Held := false, this.Active := 0
		if held
			release.Call()
	}
	Cancel(release) => this.Release(this.Active, release)
}

class nm_InventoryDrag {
	static Run(surface, pointer, point, targetX, targetY, destination := 0) {
		if !IsObject(point) || !point.HasOwnProp("Context") || point.Length != 2
			return false
		context := point.Context, snapshot := context.snapshot
		if destination && !nm_SameClient(snapshot, destination)
			return false
		if targetX < 0 || targetY < 0 || targetX >= snapshot.width || targetY >= snapshot.height
			return false
		if !pointer.Begin()
			return false
		try {
			if !pointer.Current(snapshot) || !surface.Current(snapshot)
				return false
			; A stable HWND is insufficient: scrolling can move a different item
			; under the old coordinate without changing the window at all.
			if surface.Bottom(snapshot) != context.height
				return false
			observation := surface.Observe(snapshot, context.height, context.item)
			if observation.state != "found" || point[1] != 30 || point[2] != observation.y + snapshot.offset + 190
				return false
			if !pointer.Move(snapshot, point[1], point[2]) || !pointer.Down(snapshot)
				return false
			pointer.Wait(100)
			if !pointer.Move(snapshot, targetX, targetY)
				return false
			pointer.Wait(100)
			return pointer.Current(snapshot)
		} finally pointer.Up()
	}
}
