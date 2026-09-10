TestAutoJellySafety() {
	AssertEqual(nm_AutoJellyObservation.Match(0), false, "Valid no-match remains false")
	AssertEqual(nm_AutoJellyObservation.Match(1), true, "Valid match remains true")
	for invalid in [-1001, -1004, -1005, 2]
		AutoJellyExpectFailure(ObjBindMethod(nm_AutoJellyObservation, "Match", invalid))
	bees := ["Brave", "Fuzzy"]
	SearchOne(key) => key = "-Brave" ? 1 : 0
	result := nm_AutoJellyObservation.Identify(SearchOne, bees)
	AssertEqual(result.bee, "Brave", "Bee identity is explicit")
	AssertEqual(result.gifted, false, "Ordinary bee is not gifted")
	AssertEqual(nm_AutoJellyObservation.Reason(result, ["Brave"], true, true), "selected", "Selected ordinary bee follows match path")
	AssertEqual(nm_AutoJellyObservation.Reason(result, ["Fuzzy"], true, true), "", "Known unselected bee may continue")
	BothVariants(key) => InStr(key, "Fuzzy") ? 1 : 0
	result := nm_AutoJellyObservation.Identify(BothVariants, bees)
	AssertEqual(result.gifted, true, "Gifted identity survives overlapping variants of same bee")
	AssertEqual(nm_AutoJellyObservation.Reason(result, [], true, true), "mythic", "Mythic stop does not depend on selected bees")
	AssertEqual(nm_AutoJellyObservation.Reason(result, [], false, true), "gifted", "Gifted stop does not depend on selected bees")
	None(key) => 0
	Ambiguous(key) => 1
	Failed(key) => key = "+Fuzzy" ? -1005 : SearchOne(key)
	for search in [None, Ambiguous, Failed]
		AutoJellyExpectFailure(ObjBindMethod(nm_AutoJellyObservation, "Identify", search, bees))
	AssertEqual(nm_AutoJellyObservation.EnglishLanguage("fr-FR`nen-GB`nen-US`n"), "en-GB", "English OCR is selected explicitly")
	AutoJellyExpectFailure(ObjBindMethod(nm_AutoJellyObservation, "EnglishLanguage", "fr-FR`nde-DE`n"))
}
AutoJellyExpectFailure(action) {
	try action.Call()
	catch Error
		return
	throw Error("Expected Auto-Jelly failure")
}
