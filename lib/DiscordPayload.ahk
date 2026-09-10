; Raw strings enter here; JSON serialization owns escaping.
nm_DiscordEmbedPayload(message, color := 3223350, content := "", imageName := "", replyID := 0) {
	if !IsNumber(color) || color < 0 || color > 0xFFFFFF
		throw ValueError("Invalid Discord embed color")
	embed := Map("description", nm_DiscordTextLimit(message, 4096), "color", Integer(color))
	if imageName
		embed["image"] := Map("url", "attachment://" imageName)
	payload := nm_DiscordReplyObject(replyID)
	payload["content"] := nm_DiscordTextLimit(content, 2000), payload["embeds"] := [embed]
	return JSON.stringify(payload, 0)
}

nm_DiscordReplyObject(replyID := 0) {
	payload := Map()
	if replyID {
		if !RegExMatch(replyID, "^[0-9]{1,20}$")
			throw ValueError("Invalid Discord reply ID")
		payload["allowed_mentions"] := Map("parse", [])
		payload["message_reference"] := Map("message_id", String(replyID), "fail_if_not_exists", JSON.false)
	}
	return payload
}

nm_DiscordSettingPayload(name, value, replyID) {
	payload := nm_DiscordReplyObject(replyID)
	payload["embeds"] := [Map("color", 5066239, "fields", [Map("name", nm_DiscordTextLimit(name, 256),
		"value", nm_DiscordTextLimit(StrLen(value) ? value : "<blank>", 1024))])]
	return JSON.stringify(payload, 0)
}

nm_DiscordTextLimit(value, limit) {
	text := SubStr(value, 1, limit)
	if StrLen(value) > limit && Ord(SubStr(text, -1)) >= 0xD800 && Ord(SubStr(text, -1)) <= 0xDBFF
		text := SubStr(text, 1, -1)
	return text
}
