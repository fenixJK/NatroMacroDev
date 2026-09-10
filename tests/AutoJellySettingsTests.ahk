TestAutoJellySettings() {
	defaults := nm_AutoJellySettings.Parse("", 123, 456)
	AssertEqual(defaults.Count, 50, "Complete fixed Auto-Jelly schema")
	AssertEqual(defaults["xPos"], 123, "Missing position uses caller center")
	for name, value in defaults
		if name != "xPos" && name != "yPos" && name != "RollClickLimit" && name != "RollMinuteLimit"
			AssertEqual(value, 0, "Missing selection starts disabled")
	AssertEqual(defaults["RollClickLimit"], 100, "Existing installations receive a finite click default")
	AssertEqual(defaults["RollMinuteLimit"], 10, "Existing installations receive a finite duration default")
	text := "; Existing settings`r`n[BeEs]`r`n bomber = 1`r`nselectAll=0`r`nresources=0`r`nw=1`r`n[mutations]`r`nAbility=1`r`n[extrasettings]`r`nmythicStop=1`r`n[GUI]`r`nxPos=-123`r`nyPos=456`r`n[unknown]`r`nBomber=0`r`nSelectAll=1`r`n"
	values := nm_AutoJellySettings.Parse(text)
	AssertEqual(values["Bomber"], 1, "Case and whitespace accepted in correct section")
	AssertEqual(values["selectAll"], 0, "Wrong section cannot change a selection")
	AssertEqual(values["Ability"], 1, "Mutation selection restored")
	AssertEqual(values["mythicStop"], 1, "Stop condition restored")
	AssertEqual(values["xPos"], -123, "Signed position restored")
	AssertEqual(values.Has("resources") || values.Has("w"), false, "Unknown keys cannot publish internal globals")
	for invalid in ["[bees]`nBomber=2", "[bees]`nBomber=word", "[bees]`nBomber=1.0", "[bees]`nBomber=", "[bees]`nBomber", "[bees]`nBomber=1`nbomber=0", "[bees]`nBomber=1`n[BEES]`nBomber=1", "[GUI]`nxPos=32768", "[GUI]`nyPos=-32769", "[GUI]`nxPos=1e2", "[bees"]
		AssertThrows(ObjBindMethod(nm_AutoJellySettings, "Parse", invalid), "Malformed known settings rejected before publication")
	AssertThrows(ObjBindMethod(nm_AutoJellySettings, "Parse", StrReplace(Format("{:65537}", ""), " ", "x")), "Oversized text rejected")
	path := "settings\auto-jelly-fixture.ini"
	try {
		AssertEqual(nm_AutoJellySettings.Load(123, 456, path)["yPos"], 456, "Absent file uses defaults without creation")
		AssertEqual(FileExist(path), "", "Loading missing settings does not write")
		FileAppend text, path, "UTF-8"
		AssertEqual(nm_AutoJellySettings.Load(0, 0, path)["Bomber"], 1, "Existing file restores validated selections")
		AssertEqual(FileRead(path), text, "Loading preserves original settings and unknown content")
		selected := 1
		selected := nm_AutoJellySettings.Toggle("Bomber", selected, path)
		AssertEqual(selected, 0, "Successful toggle publishes saved selection")
		AssertEqual(IniRead(path, "bees", "Bomber"), 0, "Successful toggle persisted")
		try selected := nm_AutoJellySettings.Toggle("Bomber", selected, "settings")
		AssertEqual(selected, 0, "Failed write leaves caller selection unchanged")
		AssertThrows(ObjBindMethod(nm_AutoJellySettings, "Toggle", "resources", 0, path), "Internal global is not writable")
		AssertThrows(ObjBindMethod(nm_AutoJellySettings, "Toggle", "xPos", 0, path), "Coordinates are not toggles")
		AssertThrows(ObjBindMethod(nm_AutoJellySettings, "Toggle", "RollClickLimit", 1, path), "Run limits cannot be toggled off")
		AssertThrows(ObjBindMethod(nm_AutoJellySettings, "Toggle", "Bomber", 2, path), "Invalid current selection cannot toggle")
		FileDelete path
		FileAppend "[bees]`nBomber=private-invalid-value", path
		try nm_AutoJellySettings.Load(0, 0, path)
		catch as err
			AssertEqual(InStr(err.Message, "private-invalid-value"), 0, "Errors identify field without echoing input")
		AssertEqual(FileRead(path), "[bees]`nBomber=private-invalid-value", "Rejected settings are not rewritten")
		FileAppend Format("{:65537}", ""), path
		AssertThrows(ObjBindMethod(nm_AutoJellySettings, "Load", 0, 0, path), "Oversized file rejected before full read")
	} finally {
		if FileExist(path)
			FileDelete path
	}
}
