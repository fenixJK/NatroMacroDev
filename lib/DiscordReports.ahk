#Include "DiscordPayload.ahk"
#Include "DurationFromSeconds.ahk"

nm_DiscordHoneyPayload(description, color) {
	return JSON.stringify(Map("embeds", [Map("description", nm_DiscordTextLimit(description, 4096),
		"color", nm_DiscordReport.Color(color), "image", Map("url", "attachment://honey.png"))], "attachments", []), 0)
}

; Reports borrow catalog bitmaps. CreateFormData copies them before returning;
; the report never disposes shared catalog resources or edits macro state.
class nm_DiscordReport {
	__New(replyID) {
		this.Payload := nm_DiscordReplyObject(replyID), this.Payload["embeds"] := []
		this.Files := [], this.Icons := Map()
	}
	static Color(value) => IsInteger(value) && value >= 0 && value <= 0xffffff ? Integer(value) : 5066239
	static Field(name, value, inline := true) => Map("name", nm_DiscordTextLimit(String(name), 256),
		"value", nm_DiscordTextLimit(StrLen(String(value)) ? String(value) : "Unknown", 1024), "inline", inline ? JSON.true : JSON.false)
	Add(title, color := 5066239, fields := unset, description := "") {
		embed := Map("color", nm_DiscordReport.Color(color))
		if title
			embed["title"] := nm_DiscordTextLimit(title, 256)
		if IsSet(fields) && fields.Length
			embed["fields"] := fields
		if description
			embed["description"] := nm_DiscordTextLimit(description, 4096)
		this.Payload["embeds"].Push(embed)
		return embed
	}
	Icon(embed, label, bitmap) {
		if !this.Icons.Has(bitmap) {
			filename := "report-" this.Files.Length ".png"
			this.Icons[bitmap] := filename
			this.Files.Push(Map("name", "files[" this.Files.Length "]", "filename", filename,
				"content-type", "image/png", "pBitmap", bitmap))
		}
		embed["author"] := Map("name", nm_DiscordTextLimit(label, 256), "icon_url", "attachment://" this.Icons[bitmap])
	}
	Send(sender := 0) {
		if !sender
			sender := discord
		payload := JSON.stringify(this.Payload, 0)
		if !this.Files.Length
			return sender.SendMessageAPI(payload)
		parts := this.Files.Clone()
		parts.InsertAt(1, Map("name", "payload_json", "content-type", "application/json", "content", payload))
		sender.CreateFormData(&body, &kind, parts)
		return sender.SendMessageAPI(body, kind)
	}
	static Remaining(deadline, current, ready := "Ready", days := true) {
		if !IsNumber(deadline)
			return "Unknown"
		seconds := deadline - current
		if seconds <= 0
			return ready
		return DurationFromSeconds(seconds, (days && seconds >= 86400 ? "d'd' h" : "")
			(seconds >= 3600 ? "h'h' m" : "") (seconds >= 60 ? "m'm' s" : "") "s's'")
	}
}

nm_DiscordPlanterReport(vars, catalog, prefix, replyID, current) {
	r := nm_DiscordReport(replyID), f := ObjBindMethod(nm_DiscordReport, "Field")
	r.Add("Planters",, [f(prefix "planter harvest [``n``]", "Requests harvest of Slot ``n``, including held or unready planters"),
		f(prefix "planter add [``h:m:s``] [``n``]", "Adds time to the planter timer"),
		f(prefix "planter sub [``h:m:s``] [``n``]", "Subtracts time from the planter timer"),
		f(prefix "planter clear [``n``]", "Clears the stored planter record"),
		f(prefix "planter smoking [``n``]", "Sets a held manual planter to smoking"),
		f(prefix "planter screenshot [``n``]", "Takes a screenshot of the planter")],
		"The macro's stored planters are shown below. Use these commands to edit their timers:")
	Loop 3 {
		slot := A_Index, item := vars.Get("PlanterName" slot, "None")
		if !catalog.Has(item)
			continue
		data := catalog[item], ready := "Ready"
		if vars.Get("PlanterMode", 0) = 1
			ready := vars.Get("MPlanterSmoking" slot, 0) ? "Smoking" : vars.Get("MPlanterHold" slot, 0) ? "Holding" : "Ready"
		remaining := nm_DiscordReport.Remaining(vars.Get("PlanterHarvestTime" slot, ""), current, ready, false)
		embed := r.Add("Slot " slot, data.color, [f("Field Planted", vars.Get("PlanterField" slot, "Unknown")
			" (" StrUpper(SubStr(vars.Get("PlanterNectar" slot, ""), 1, 3)) ")"), f("Time Remaining", remaining),
			f("Glitter Used", vars.Get("PlanterGlitter" slot, 0) ? "Yes" : "No")])
		r.Icon(embed, data.name, data.bitmap)
	}
	return r
}

nm_DiscordTimerReport(vars, catalog, prefix, replyID, current) {
	r := nm_DiscordReport(replyID), f := ObjBindMethod(nm_DiscordReport, "Field")
	r.Add("Timers",, [f(prefix "timer reset [``var``]", "Resets the timer to its cooldown"),
		f(prefix "timer add [``h:m:s``] [``var``]", "Adds time to the timer"),
		f(prefix "timer sub [``h:m:s``] [``var``]", "Subtracts time from the timer")], "The macro's ongoing timers are shown below.")
	for group in ["Mobs", "Machines", "Beesmas"] {
		fields := [], data := catalog.%group%
		for , timer in data.values {
			if group != "Mobs" && vars.Get(timer.varname "Check", 0) != 1
				continue
			last := vars.Get("Last" timer.varname, ""), respawn := vars.Get("MonsterRespawnTime", 0)
			deadline := IsNumber(last) && (group != "Mobs" || IsNumber(respawn)) ? last + timer.cooldown * (group = "Mobs" ? 1 - respawn * 0.01 : 1) : ""
			fields.Push(f(timer.name, nm_DiscordReport.Remaining(deadline, current, group = "Mobs" ? "Alive" : "Ready")))
		}
		if fields.Length {
			embed := r.Add("", data.color, fields)
			r.Icon(embed, group, data.bitmap)
		}
	}
	return r
}

nm_DiscordBlenderReport(vars, catalog, replyID, current) {
	r := nm_DiscordReport(replyID), f := ObjBindMethod(nm_DiscordReport, "Field")
	r.Add("Blender",,, "The macro's configured recipe rotation is shown below.")
	Loop 3 {
		slot := A_Index, item := vars.Get("BlenderItem" slot, "None"), count := vars.Get("BlenderIndex" slot, 0)
		if !catalog.Has(item) || !(count = "Infinite" || IsNumber(count) && count > 0)
			continue
		data := catalog[item]
		embed := r.Add("Slot " slot, data.color, [f("Item Amount", vars.Get("BlenderAmount" slot, "Unknown")),
			f("Times to loop", count), f("Time Left", nm_DiscordReport.Remaining(vars.Get("BlenderTime" slot, ""), current,, false))])
		r.Icon(embed, data.name, data.bitmap)
	}
	return r
}

nm_DiscordShrineReport(vars, replyID, current) {
	r := nm_DiscordReport(replyID), f := ObjBindMethod(nm_DiscordReport, "Field"), rotation := vars.Get("ShrineRot", 0)
	valid := rotation = 1 || rotation = 2
	r.Add("Wind Shrine",, [f("Current Donation", valid ? vars.Get("ShrineItem" rotation, "Unknown") : "Unknown"),
		f("Next Donation", valid ? vars.Get("ShrineItem" (Mod(rotation, 2) + 1), "Unknown") : "Unknown"),
		f("Time Until Next Donation", IsNumber(last := vars.Get("LastShrine", "")) ? nm_DiscordReport.Remaining(last + 3600, current) : "Unknown")])
	return r
}

nm_DiscordMemoryReport(vars, games, items, prefix, replyID, current) {
	r := nm_DiscordReport(replyID), f := ObjBindMethod(nm_DiscordReport, "Field")
	r.Add("Memory Match",, [f(prefix "mm enable [``game``]", "Enables the selected game"),
		f(prefix "mm disable [``game``]", "Disables the selected game"),
		f(prefix "mm ignore [``item``] (``game``)", "Toggles ignored items; omit game to apply to all games")],
		"Enabled games are shown below. Use ``" prefix "timers`` to change their timers.")
	for game in ["Normal", "Mega", "Night", "Extreme", "Winter"] {
		if vars.Get(game "MemoryMatchCheck", 0) != 1
			continue
		bit := games[game].bit, ignored := ""
		for item, data in items
			if vars.Get(item "MatchIgnore", 0) & bit
				ignored .= (ignored ? ", " : "") data.name
		last := vars.Get("Last" game "MemoryMatch", "")
		r.Add(game " Memory Match",, [f("Time Left", IsNumber(last) ? nm_DiscordReport.Remaining(last + games[game].cooldown, current) : "Unknown", false),
			f("Ignored Items", ignored ? ignored : "None", false)])
	}
	return r
}
