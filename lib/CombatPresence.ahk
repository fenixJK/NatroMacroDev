; Losing a health bar means the target cannot be tracked, never that it died.
; This clock only decides when to leave an unconfirmed fight.
class nm_CombatPresence {
	__New(limitMs, ignoreFull := false) {
		if !IsInteger(limitMs) || limitMs <= 0
			throw ValueError("Combat absence interval must be positive milliseconds")
		this.Limit := limitMs, this.IgnoreFull := ignoreFull
		this.MissingSince := this.LastTick := -1
	}
	Expired(bars, tick) {
		if !(bars is Array) || !IsInteger(tick) || tick < 0 || tick < this.LastTick
			throw Error("Invalid combat presence observation")
		present := false
		for health in bars {
			if !IsNumber(health) || health < 0 || health > 100
				throw Error("Invalid combat health value")
			if !this.IgnoreFull || health < 100
				present := true
		}
		this.LastTick := tick
		if present {
			this.MissingSince := -1
			return false
		}
		if this.MissingSince < 0
			this.MissingSince := tick
		return tick - this.MissingSince >= this.Limit
	}
}

; A long fight can outlast the persisted retry delay. Keep its in-process lease
; until its finally block runs so nested scheduler checks cannot re-enter it.
class nm_BossVisit {
	static Active := Map()
	static Ready(key) {
		if key != "LastCommando" && key != "LastMondoBuff"
			throw ValueError("Unsupported guarded boss visit")
		return !this.Active.Has(key) && nm_CollectionRecovery.Ready(key)
	}
	static Begin(key) {
		previousCritical := A_IsCritical
		Critical
		try {
			if !this.Ready(key) || !nm_CollectionRecovery.Begin(key)
				return false
			this.Active[key] := true
			return true
		} finally Critical previousCritical
	}
	static Finish(key, confirmed) {
		if !this.Active.Has(key)
			return
		try {
			if !confirmed
				nm_CollectionRecovery.Failed(key, key = "LastCommando" ? "defeat not verified" : "buff not verified")
		} finally this.Active.Delete(key)
	}
}
