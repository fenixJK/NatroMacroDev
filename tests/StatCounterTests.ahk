TestStatCounters() {
	global TotalBossKills, SessionBossKills, TotalViciousKills, SessionViciousKills,
		TotalBugKills, SessionBugKills, TotalPlantersCollected, SessionPlantersCollected,
		TotalQuestsComplete, SessionQuestsComplete, TotalDisconnects, SessionDisconnects,
		TestStatsMode, TestStatsMessages, TestStatsRows
	TestStatsMode := true, TestStatsMessages := []
	TestStatsRows := [["Boss", 0], ["Vicious", 0], ["Bugs", 0], ["Planters", 0], ["Quests", 0], ["Disconnects", 0]]
	try {
		for name in ["BossKills", "ViciousKills", "BugKills", "Planters", "QuestsDone", "Disconnects"] {
			definition := nm_StatCounters.Definition(name), key := definition[2], id := definition[1]
			Total%key% := 100, Session%key% := 10
			AssertEqual(nm_IncrementStat(name, 2), 2, name " returns the actual increment")
			AssertEqual(Total%key%, 102, name " total uses the requested amount")
			AssertEqual(Session%key%, 12, name " session uses the requested amount")
			AssertEqual(IniRead("settings\nm_config.ini", "Status", "Total" key), 102, name " total saved under canonical key")
			AssertEqual(IniRead("settings\nm_config.ini", "Status", "Session" key), 12, name " session saved under canonical key")
			AssertEqual(TestStatsRows[id][2], 2, name " monitor receives the same amount")
			nm_IncrementStat(name)
			AssertEqual(Total%key%, 103, name " default amount is one")
			AssertEqual(TestStatsRows[id][2], 3, name " monitor receives default amount")
		}
		AssertEqual(IniRead("settings\nm_config.ini", "Status", "TotalPlanters", "missing"), "missing", "No obsolete planter key is created")
		AssertEqual(IniRead("settings\nm_config.ini", "Status", "TotalQuestsDone", "missing"), "missing", "No obsolete quest key is created")
		before := FileRead("settings\nm_config.ini"), sent := TestStatsMessages.Length
		AssertEqual(nm_IncrementStat("BugKills", 0), 0, "Zero is a no-op")
		for amount in [-1, 1.5, "invalid", 0x80000000]
			AssertThrows(nm_IncrementStat.Bind("BugKills", amount), "Invalid amount rejected before any side effect")
		AssertThrows(nm_IncrementStat.Bind("Unknown", 2), "Unknown statistic rejected before any side effect")
		AssertEqual(FileRead("settings\nm_config.ini"), before, "Invalid/zero increments do not write config")
		AssertEqual(TestStatsMessages.Length, sent, "Invalid/zero increments do not post messages")
		TotalBugKills := 0x7fffffffffffffff
		AssertThrows(nm_IncrementStat.Bind("BugKills"), "Lifetime total cannot wrap")
		TotalBugKills := 103, SessionBugKills := -1
		AssertThrows(nm_IncrementStat.Bind("BugKills"), "Corrupt session value cannot be silently advanced")
		SessionBugKills := 13
		TestStatsRows[3][2] := 0x7fffffffffffffff
		nm_StatCounters.Receive(TestStatsRows, 3, 1)
		AssertEqual(TestStatsRows[3][2], 0x7fffffffffffffff, "Monitor counter cannot wrap")
		TestStatsRows[3][2] := 3
		for invalid in [[0, 1], [7, 1], [-1, 1], [1.5, 1], [3, -1], [3, 0x80000000], [3, 0xffffffff], [3, 1.5]]
			nm_StatCounters.Receive(TestStatsRows, invalid[1], invalid[2])
		AssertEqual(TestStatsRows[3][2], 3, "Malformed messages leave monitor values unchanged")

		; Exercise the production persistence path, not an injected writer.
		DirMove "settings", "stats-settings-backup"
		try {
			FileAppend "fixture blocks settings directory", "settings"
			writeFailed := false
			try nm_IncrementStat("BugKills", 2)
			catch OSError
				writeFailed := true
			Assert(writeFailed, "A real INI write failure is propagated")
			AssertEqual(TotalBugKills, 103, "Failed first write does not change memory")
			AssertEqual(SessionBugKills, 13, "Failed first write does not change session memory")
			AssertEqual(TestStatsMessages.Length, sent, "Failed persistence cannot publish an increment")
		} finally {
			FileDelete "settings"
			DirMove "stats-settings-backup", "settings"
		}
	} finally TestStatsMode := false
}

TestStatPost(target, message, id, amount) {
	global TestStatsMessages, TestStatsRows
	Assert(target = "StatMonitor" && message = 0x5555, "Increment uses the existing monitor protocol")
	key := ["BossKills", "ViciousKills", "BugKills", "PlantersCollected", "QuestsComplete", "Disconnects"][id]
	AssertEqual(IniRead("settings\nm_config.ini", "Status", "Total" key), 100 + TestStatsRows[id][2] + amount,
		"Total persistence happens before dispatch")
	AssertEqual(IniRead("settings\nm_config.ini", "Status", "Session" key), 10 + TestStatsRows[id][2] + amount,
		"Session persistence happens before dispatch")
	TestStatsMessages.Push([id, amount])
	return nm_StatCounters.Receive(TestStatsRows, id, amount)
}
