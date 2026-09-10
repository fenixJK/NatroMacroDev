TestDiscordHelp() {
	prefix := Chr(34) "\", config := Map("FixtureName", {section: "Gather", regex: ".*"})
	for topic in ["", "unknown", "a", "ad", "adv", "advance", "advanced", "ADVANCED", "priority", "s", "set"] {
		pages := nm_DiscordHelpPayloads(topic, prefix, config, "123")
		Assert(pages.Length >= 1, "Every help alias produces a reply")
		for page in pages {
			parsed := JSON.parse(page), embed := parsed["embeds"][1]
			AssertEqual(Type(embed), "Map", "Help embeds are objects, not enumeration indexes")
			AssertEqual(Type(embed["color"]), "Integer", "Help colors are numeric")
			AssertEqual(parsed["message_reference"]["message_id"], "123", "Single-page help retains the reply")
			if embed.Has("fields") {
				AssertEqual(embed["fields"].Length, 12, "All command help entries retained")
				for field in embed["fields"]
					Assert(InStr(field["name"], prefix) = 1, "Quoted/backslash prefix survives serialization")
			} else if topic = "s" || topic = "set"
				Assert(InStr(embed["title"], prefix "set") && InStr(embed["description"], "FixtureName"), "Settings help uses current prefix and lists settings")
			else
				Assert(InStr(embed["description"], prefix "set priorityListNumeric") && InStr(embed["description"], "8 - Go Gather"), "Priority help preserves examples and all eight tasks")
		}
	}
	settings := Map("NoRegex", {section: "Gather"})
	Loop 1800
		settings[Format("Setting{:04}_", A_Index) StrReplace(Format("{:30}", ""), " ", "x")] := {section: "NewSection", regex: ".*"}
	text := nm_DiscordSettingsText(settings)
	Assert(!InStr(text, "NoRegex"), "Only remotely settable settings are listed")
	Assert(InStr(text, "**__NewSection__**"), "Additional sections retain headings")
	pages := nm_DiscordHelpPayloads("set", prefix, settings, "123")
	Assert(pages.Length > 10, "Long settings lists are not limited to ten pages")
	reconstructed := ""
	for index, page in pages {
		parsed := JSON.parse(page), embed := parsed["embeds"][1]
		Assert(StrLen(embed["description"]) <= 4096 && StrLen(embed["title"]) <= 256, "Each page respects description/title bounds")
		Assert(InStr(embed["title"], "(" index "/" pages.Length ")"), "All pages show their position")
		AssertEqual(parsed.Has("message_reference"), index = 1, "Only first page references the command")
		AssertEqual(parsed["allowed_mentions"]["parse"].Length, 0, "Every page disables parsed mentions")
		reconstructed .= embed["description"]
	}
	AssertEqual(reconstructed, text, "Pagination preserves every setting, separator and final page")
	text := StrReplace(Format("{:4095}", ""), " ", "x") "🐝" StrReplace(Format("{:5000}", ""), " ", "y")
	pages := nm_DiscordHelpPages(text, "Unicode", 123, "123"), reconstructed := ""
	for page in pages {
		part := JSON.parse(page)["embeds"][1]["description"]
		lastCode := Ord(SubStr(part, -1)), firstCode := Ord(SubStr(part, 1, 1))
		Assert(!(lastCode >= 0xD800 && lastCode <= 0xDBFF) && !(firstCode >= 0xDC00 && firstCode <= 0xDFFF), "An overlong line cannot split a Unicode pair")
		reconstructed .= part
	}
	AssertEqual(reconstructed, text, "An overlong line is split without truncation")
}
