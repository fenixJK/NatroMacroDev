; Raw help data; JSON serialization owns escaping and reply metadata.
#Include "DiscordPayload.ahk"

nm_DiscordSettingsText(settings) {
	sections := Map()
	for section in ["Boost", "Collect", "Gather", "Planters", "Quests", "Settings", "Status", "Blender", "Shrine"]
		sections[section] := "**__" section "__**"
	for name, definition in settings {
		if !HasProp(definition, "regex")
			continue
		section := definition.section
		if !sections.Has(section)
			sections[section] := "**__" section "__**"
		sections[section] .= "`n" name
	}
	text := ""
	for , sectionText in sections
		text .= (text ? "`n`n" : "") sectionText
	return text
}

nm_DiscordHelpPages(text, title, color, replyID) {
	chunks := [], remaining := text
	Loop {
		chunk := nm_DiscordTextLimit(remaining, 4096)
		if StrLen(remaining) > StrLen(chunk) && (boundary := InStr(chunk, "`n",, -1))
			chunk := SubStr(chunk, 1, boundary)
		chunks.Push(chunk)
		remaining := SubStr(remaining, StrLen(chunk) + 1)
		if !remaining
			break
	}
	pages := []
	for pageNumber, chunk in chunks {
		payload := nm_DiscordReplyObject(pageNumber = 1 ? replyID : 0)
		payload["allowed_mentions"] := Map("parse", [])
		payload["embeds"] := [Map("title", nm_DiscordTextLimit(title, 220)
			(chunks.Length > 1 ? " (" pageNumber "/" chunks.Length ")" : ""), "color", color, "description", chunk)]
		pages.Push(JSON.stringify(payload, 0))
	}
	return pages
}

nm_DiscordHelpPayloads(topic, prefix, settings, replyID) {
	switch StrLower(topic) {
		case "s", "set":
			return nm_DiscordHelpPages(nm_DiscordSettingsText(settings), "List of Settings for ``" prefix "set``", 5066239, replyID)
		case "priority":
			return nm_DiscordHelpPages("To change the priority list, use the following command:`n```````n" prefix "set priorityListNumeric [numbers|default]`n```````nEach digit represents its slot in the default priority list.`nFor example:`n```````n" prefix "set priorityListNumeric 12345678`n```````n`n**Default Priority List**``````ansi`n1 - Night`n2 - Mondo`n3 - Planter`n4 - Bugrun`n5 - Collect`n6 - Quest Rotate`n7 - Boost`n8 - Go Gather``````", "Priority List", 2829617, replyID)
		case "a", "ad", "adv", "advance", "advanced":
			title := "Advanced Commands", color := 7569663
			rows := [
				["" prefix "set [setting] [value]", "Sets a setting to ``value`` (use ``" prefix "help set`` for a list)"],
				["" prefix "get [setting]", "Gets the current value of a setting in the macro"],
				["" prefix "send [keys]", "Uses AHK's ``Send`` command (see docs)"],
				["" prefix "upload [filepath]", "Uploads a specific file from ``filepath``"],
				["" prefix "download [attach a file]", "Saves the attached file in settings/remote-inbox (FileReceive permission)"],
				["" prefix "click [options]", "Uses AHK's ``Click`` command (see docs)"],
				["" prefix "activate [window]", "Uses ``WinActivate`` to activate a window"],
				["" prefix "minimize [window]", "Uses ``WinMinimize`` to minimize a window"],
				["" prefix "shiftlock [on/off]", "Enables/disables Shift Lock switch in-game"],
				["" prefix "restart", "Restarts your computer"],
				["" prefix "finditem [item]", "Finds an item in your inventory and sends a screenshot"],
				["" prefix "debug", "Sends a redacted support report (Diagnostics permission)"]]
		default:
			title := "Useful Commands", color := 5066239
			rows := [
				["" prefix "help", "Display a list of useful commands"],
				["" prefix "screenshot", "Captures the selected screenshot mode (Roblox by default); desktop modes require DesktopCapture permission"],
				["" prefix "stop", "Stop and reload Natro Macro (``F3``)"],
				["" prefix "pause", "Pause/unpause Natro Macro (``F2``)"],
				["" prefix "start", "Start Natro Macro (``F1``)"],
				["" prefix "close [window]", "Closes a specific window, e.g. ``" prefix "close Roblox``"],
				["" prefix "rejoin (delay)", "Closes Roblox and rejoins after an optional ``delay``"],
				["" prefix "keep or " prefix "replace", "Keeps/replaces an amulet if prompt is on screen"],
				["" prefix "log", "Sends redacted recent issues (Diagnostics permission)"],
				["" prefix "planters", "Displays information about placed planters"],
				["" prefix "timers", "Displays information about macro timers"],
				["" prefix "prefix [prefix]", "Sets the command prefix, e.g. ``" prefix "prefix +``"]]
	}
	fields := []
	for row in rows
		fields.Push(Map("name", row[1], "value", row[2], "inline", JSON.true))
	payload := nm_DiscordReplyObject(replyID)
	payload["embeds"] := [Map("title", title, "color", color, "fields", fields)]
	return [JSON.stringify(payload, 0)]
}
