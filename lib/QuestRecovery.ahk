; Retry reservations are distinct from game progress, quest counts and the hourly
; repeatable-quest cooldowns. Persist before work so restart cannot erase a delay.
class nm_QuestRecovery {
	static Cache := Map(), Active := Map()
	static Clock := () => nowUnix()
	static Tick := () => DllCall("GetTickCount64", "UInt64")

	static Key(family, kind) {
		if !RegExMatch(family, "^(Honey|Polar|Riley|Bucko|Black|Brown)$") || (kind != "read" && kind != "visit")
			throw ValueError("Invalid quest recovery key")
		return family "." kind
	}
	static Delay(kind) => kind = "read" ? 30 : 300
	static Write(key, started, delay) {
		record := started "|" started + delay
		IniWrite record, "settings\nm_config.ini", "QuestRecovery", key
		this.Cache[key] := {record: record, until: this.Tick.Call() + delay * 1000}
	}
	static Remaining(family, kind) {
		key := this.Key(family, kind), delay := this.Delay(kind)
		record := IniRead("settings\nm_config.ini", "QuestRecovery", key, "")
		tick := this.Tick.Call()
		if this.Cache.Has(key) && this.Cache[key].record = record
			return Max(0, Ceil((this.Cache[key].until - tick) / 1000))
		if record = "" || record = "0|0" {
			this.Cache[key] := {record: record, until: tick}
			return 0
		}
		parts := StrSplit(record, "|"), current := this.Clock.Call()
		if parts.Length != 2 || !IsInteger(parts[1]) || !IsInteger(parts[2])
			|| parts[1] < 0 || parts[2] - parts[1] != delay || parts[1] > current {
			; Corruption or a backward wall clock gets one bounded reservation.
			this.Write(key, current, delay)
			return delay
		}
		remaining := Max(0, Min(delay, parts[2] - current))
		this.Cache[key] := {record: record, until: tick + remaining * 1000}
		return remaining
	}
	static Ready(family, kind) {
		key := this.Key(family, kind)
		return !this.Active.Has(key) && !this.Remaining(family, kind)
	}
	static Begin(family, kind) {
		previousCritical := A_IsCritical
		Critical "On"
		try {
			key := this.Key(family, kind)
			if !this.Ready(family, kind)
				return false
			this.Write(key, this.Clock.Call(), this.Delay(kind))
			this.Active[key] := true
			return true
		} finally Critical previousCritical
	}
	static Finish(family, kind, confirmed) {
		previousCritical := A_IsCritical
		Critical "On"
		try {
			key := this.Key(family, kind)
			if !this.Active.Has(key)
				return
			try this.Write(key, confirmed ? 0 : this.Clock.Call(), confirmed ? 0 : this.Delay(kind))
			finally this.Active.Delete(key)
		} finally Critical previousCritical
	}
}
