#Include "InventoryDrag.ahk"

class nm_InventoryPointer {
	static Gate := nm_PointerLease()
	static Cancellation := 0
	__New(surface) {
		static registered := false
		this.Surface := surface, this.Token := 0
		if !registered {
			InstallMouseHook()
			OnExit((*) => nm_InventoryPointer.Cancel(), -1)
			registered := true
		}
	}
	Begin() {
		previous := A_IsCritical
		Critical "On"
		try return !GetKeyState("LButton") && !GetKeyState("LButton", "P") && (this.Token := nm_InventoryPointer.Gate.Begin())
		finally Critical previous
	}
	Current(snapshot) => nm_InventoryPointer.Gate.Owns(this.Token) && !GetKeyState("LButton", "P") && this.Surface.Current(snapshot)
	Move(snapshot, x, y) {
		previous := A_IsCritical, previousMode := A_CoordModeMouse
		Critical "On"
		try {
			if !this.Current(snapshot) || x < 0 || y < 0 || x >= snapshot.width || y >= snapshot.height
				return false
			CoordMode "Mouse", "Screen"
			MouseMove snapshot.x + x, snapshot.y + y, 0
			return this.Current(snapshot)
		} finally {
			CoordMode "Mouse", previousMode
			Critical previous
		}
	}
	Down(snapshot) {
		previous := A_IsCritical
		Critical "On"
		try return this.Current(snapshot) && nm_InventoryPointer.Gate.Press(this.Token, (*) => SendEvent("{LButton down}"))
		finally Critical previous
	}
	Up() {
		previous := A_IsCritical
		Critical "On"
		try nm_InventoryPointer.Gate.Release(this.Token, (*) => SendEvent("{LButton up}"))
		finally Critical previous
	}
	static Cancel(*) {
		previous := A_IsCritical
		Critical "On"
		try {
			nm_InventoryPointer.Cancellation++
			nm_InventoryPointer.Gate.Cancel((*) => SendEvent("{LButton up}"))
		}
		finally Critical previous
	}
	Wait(milliseconds) => Sleep(milliseconds)
}
