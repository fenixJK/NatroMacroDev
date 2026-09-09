; Raw strings enter here; JSON serialization owns escaping.
nm_DiscordEmbedPayload(message, color := 3223350, content := "", imageName := "") {
	if !IsNumber(color) || color < 0 || color > 0xFFFFFF
		throw ValueError("Invalid Discord embed color")
	embed := Map("description", nm_DiscordTextLimit(message, 4096), "color", Integer(color))
	if imageName
		embed["image"] := Map("url", "attachment://" imageName)
	return JSON.stringify(Map("content", nm_DiscordTextLimit(content, 2000), "embeds", [embed]), 0)
}

nm_DiscordTextLimit(value, limit) {
	text := SubStr(value, 1, limit)
	if StrLen(value) > limit && Ord(SubStr(text, -1)) >= 0xD800 && Ord(SubStr(text, -1)) <= 0xDBFF
		text := SubStr(text, 1, -1)
	return text
}
