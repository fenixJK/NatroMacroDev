; This gate covers main-process background actions while reconnect/close owns
; the game. Nesting (reconnect -> close) is allowed; every owner must release.
class nm_RecoveryActivity {
	static Depth := 0
	__New() {
		this.Open := true
		nm_RecoveryActivity.Depth++
	}
	Close() {
		if this.Open {
			this.Open := false
			nm_RecoveryActivity.Depth--
		}
	}
	static Allowed() => this.Depth = 0
	static RunBackground(action) {
		if this.Allowed()
			return action.Call()
	}
}
