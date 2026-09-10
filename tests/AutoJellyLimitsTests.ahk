TestAutoJellyLimits() {
	for invalid in [0, -1, "", "1.5", "1e3", 1000001] {
		AssertThrows(() => nm_AutoJellySettings.Limits(invalid, 10), "Invalid click limit rejected")
		AssertThrows(() => nm_AutoJellySettings.Parse("[limits]`nRollClickLimit=" invalid), "Invalid stored click limit rejected")
	}
	for invalid in [0, -1, "", "1.5", "1e3", 1441]
		AssertThrows(() => nm_AutoJellySettings.Limits(100, invalid), "Invalid duration rejected")
	limits := nm_AutoJellySettings.Limits(1000000, 1440)
	AssertEqual(limits.Clicks, 1000000, "Finite upper click bound accepted")
	AssertEqual(limits.Minutes, 1440, "Finite upper time bound accepted")
	AssertThrows(() => nm_AutoJellySettings.Parse("[limits]`nRollClickLimit=1`nrollclicklimit=2"), "Duplicate limit rejected")
	path := "settings\auto-jelly-limit-fixture.ini"
	try {
		FileAppend "[bees]`nBomber=1", path
		saved := nm_AutoJellySettings.SaveLimits(25, 2, path)
		AssertEqual(saved.Clicks, 25, "Successful limit write returns validated values")
		loaded := nm_AutoJellySettings.Load(0, 0, path)
		AssertEqual(loaded["RollClickLimit"], 25, "Click limit reloads")
		AssertEqual(loaded["RollMinuteLimit"], 2, "Time limit reloads")
		AssertEqual(loaded["Bomber"], 1, "Limit save preserves bee settings")
		before := FileRead(path)
		AssertThrows(() => nm_AutoJellySettings.SaveLimits(99, 0, path), "Both values validated before writing")
		AssertEqual(FileRead(path), before, "Invalid second field leaves prior limits intact")
		try saved := nm_AutoJellySettings.SaveLimits(99, 2, "settings")
		AssertEqual(saved.Clicks, 25, "Failed write cannot publish a new limit")
	} finally {
		if FileExist(path)
			FileDelete path
	}
	tick := 1000, budget := nm_AutoJellyRunBudget(2, 1, (*) => tick)
	budget.Reserve(), budget.Reserve()
	AssertEqual(budget.Used, 2, "Each reserved attempt consumes one slot")
	budget.CheckTime() ; the final allowed result can still be observed
	AssertThrows(ObjBindMethod(budget, "Reserve"), "Attempt beyond the cap cannot be reserved")
	AssertEqual(budget.Used, 2, "Rejected extra attempt does not alter usage")
	tick := 60999, budget.CheckTime()
	tick := 61000
	AssertThrows(ObjBindMethod(budget, "CheckTime"), "Duration expires at the boundary")
	AssertEqual(budget.Used, 2, "Expired budget cannot refund an uncertain attempt")
	tick := 0xffffffff, budget := nm_AutoJellyRunBudget(1, 1, (*) => tick)
	tick += 60000
	AssertThrows(ObjBindMethod(budget, "Reserve"), "Duration remains finite across a 32-bit tick boundary")
}
