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
