class nm_StatCounters {
	static Definition(name) {
		static definitions := Map("BossKills", [1, "BossKills"], "ViciousKills", [2, "ViciousKills"],
			"BugKills", [3, "BugKills"], "Planters", [4, "PlantersCollected"],
			"QuestsDone", [5, "QuestsComplete"], "Disconnects", [6, "Disconnects"])
		if !definitions.Has(name)
			throw ValueError("Unknown statistic")
		return definitions[name]
	}
	static ValidAmount(amount) => IsInteger(amount) && amount >= 0 && amount <= 0x7fffffff
	static CanAdd(value, amount) => IsInteger(value) && value >= 0 && value <= 0x7fffffffffffffff - amount
	static Receive(counters, id, amount) {
		; Window messages are untrusted, and lParam has a 32-bit signed limit
		; on the supported 32-bit runtime. Reject invalid messages without
		; indexing outside the report's counter array or changing its values.
		if !IsInteger(id) || id < 1 || id > 6 || id > counters.Length || !this.ValidAmount(amount)
			return 0
		previousCritical := A_IsCritical
		Critical "On"
		try {
			if this.CanAdd(counters[id][2], amount)
				counters[id][2] += amount
		} finally Critical previousCritical
		return 0
	}
}
