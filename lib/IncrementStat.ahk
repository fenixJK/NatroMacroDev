#Include "StatCounters.ahk"

nm_IncrementStat(stat, amount := 1) {
	global TotalBossKills, SessionBossKills, TotalViciousKills, SessionViciousKills,
		TotalBugKills, SessionBugKills, TotalPlantersCollected, SessionPlantersCollected,
		TotalQuestsComplete, SessionQuestsComplete, TotalDisconnects, SessionDisconnects
	definition := nm_StatCounters.Definition(stat), key := definition[2]
	if !nm_StatCounters.ValidAmount(amount)
		throw ValueError("Statistic increment must be a nonnegative 32-bit integer")
	if amount = 0
		return 0
	previousCritical := A_IsCritical
	Critical "On"
	try {
		if !nm_StatCounters.CanAdd(Total%key%, amount) || !nm_StatCounters.CanAdd(Session%key%, amount)
			throw ValueError("Statistic total is invalid or would overflow")
		total := Total%key% + amount, session := Session%key% + amount
		; Do not publish an increment before persistence succeeds. These two
		; legacy INI keys are not a crash-atomic transaction; durable event
		; delivery and a shared state writer remain separate work.
		IniWrite total, "settings\nm_config.ini", "Status", "Total" key
		IniWrite session, "settings\nm_config.ini", "Status", "Session" key
		Total%key% := total, Session%key% := session
		PostSubmacroMessage("StatMonitor", 0x5555, definition[1], amount)
	} finally Critical previousCritical
	return amount
}
