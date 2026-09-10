; Recovery metadata lives separately from planter identity, growth and user limits.
; Reserving a retry delay before input also covers interruption/process failure.
class nm_PlanterRecovery {
	static Delay := 300

	static KeyValid(key) => RegExMatch(key, "^(Harvest[1-3]|Placement)$")

	static Ready(key, identity, current) {
		if !this.KeyValid(key)
			throw ValueError("Invalid planter recovery key")
		value := StrSplit(IniRead("settings\nm_config.ini", "PlanterRecovery", key, ""), "|")
		if value.Length != 2 || value[1] != identity || !IsNumber(value[2])
			return true
		; A clock change or edited/corrupt timestamp must not strand a slot forever.
		return current >= value[2] || value[2] - current > this.Delay
	}

	static Defer(key, identity, current) {
		if !this.KeyValid(key) || InStr(identity, "|")
			throw ValueError("Invalid planter recovery identity")
		IniWrite identity "|" current + this.Delay, "settings\nm_config.ini", "PlanterRecovery", key
	}

	static Clear(key) {
		if !this.KeyValid(key)
			throw ValueError("Invalid planter recovery key")
		IniWrite "", "settings\nm_config.ini", "PlanterRecovery", key
	}

	static Harvest(slot, name, field, action, attempts := 5) {
		key := "Harvest" slot, identity := name ":" field
		if !this.Ready(key, identity, nowUnix())
			return 0
		this.Defer(key, identity, nowUnix())
		Loop attempts {
			result := action.Call(slot)
			if result = 1 || result = 2 {
				this.Clear(key)
				return result
			}
			if result = 3
				break ; input may already have reached the game; do not repeat it
		}
		this.Defer(key, identity, nowUnix())
		nm_setStatus("Unconfirmed", name " in " field ". Record retained; retry in 5 minutes. Use Planter Timers to reconcile if needed.")
		return 0
	}

	static Placement(action) {
		if !this.Ready("Placement", "Planters", nowUnix())
			return 3 ; existing callers stop placement for this pass
		this.Defer("Placement", "Planters", nowUnix())
		result := action.Call()
		if result != 3
			this.Clear("Placement")
		return result
	}

	static PlacementFailed() {
		this.Defer("Placement", "Planters", nowUnix())
		nm_setStatus("Unconfirmed", "Planter placement paused for 5 minutes. Your configured planter limit is unchanged; check Planter Timers.")
	}
}

nm_PlanterInventoryConfirmsAbsent(name, position) {
	; Stacked consumables can be visible while another copy is planted. Unknown
	; types fail closed until their inventory semantics have been checked.
	static reusable := Map("PlasticPlanter", 1, "CandyPlanter", 1, "BlueClayPlanter", 1,
		"RedClayPlanter", 1, "TackyPlanter", 1, "PesticidePlanter", 1,
		"HeatTreatedPlanter", 1, "HydroponicPlanter", 1, "PetalPlanter", 1, "PlanterOfPlenty", 1)
	return reusable.Has(name) && position is Array && position.Length = 2
		&& IsNumber(position[1]) && IsNumber(position[2]) && position[1] > 0 && position[2] > 0
}
