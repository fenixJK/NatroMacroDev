; Decisions shared by the live macro and the automation-free Windows tests.
; These functions perform no input, file, window, or network operations.

nm_BuildPriorityList(order) {
	if !(order ~= "^[1-8]{8}$")
		throw ValueError("Task priority must contain each number from 1 to 8 exactly once.")
	names := ["Night", "Mondo", "Planter", "Bugrun", "Collect", "QuestRotate", "Boost", "GoGather"]
	result := [], seen := Map()
	for digit in StrSplit(order) {
		if seen.Has(digit)
			throw ValueError("Task priority contains a duplicate number.")
		seen[digit] := true
		result.Push(names[Integer(digit)])
	}
	return result
}

nm_ParsePrivateServer(link) {
	link := Trim(link)
	if RegExMatch(link, "i)^https://(?:www\.)?roblox\.com/games/1537690962/[^?#]*\?(?:[^#]*&)?privateServerLinkCode=([a-z0-9]{32})(?:&[^#]*)?$", &match)
		return Map("type", "LinkCode", "code", match[1], "link", link)
	if RegExMatch(link, "i)^https://(?:www\.)?roblox\.com/share\?code=([a-z0-9]{32})&type=Server$", &match)
		return Map("type", "ShareCode", "code", match[1], "link", link)
	return 0
}

nm_SelectReconnectServer(privateSlots, attempt, allowPublic) {
	if (attempt < 1)
		throw ValueError("Reconnect attempt must be positive.")
	if !privateSlots.Length
		return allowPublic ? 0 : -1
	; Give each configured private server five attempts, skipping empty slots.
	index := (attempt - 1) // 5
	if (allowPublic && index >= privateSlots.Length)
		return 0
	return privateSlots[Mod(index, privateSlots.Length) + 1]
}

nm_BudgetAvailable(active, enabled, limited, used, limit) {
	if !active || !enabled
		return false
	if !IsNumber(used) || used < 0
		return false
	return !limited || (IsNumber(limit) && limit > 0 && used < limit)
}

nm_TimeBudgetAvailable(limited, started, current, hours) {
	return !limited || (IsNumber(hours) && hours > 0 && started > 0
		&& current >= started && current - started < hours * 3600)
}

nm_RemainingWaitMs(waitMs, startedMs, currentMs) {
	return Max(0, waitMs - Max(0, currentMs - startedMs))
}

nm_CommandAuthorized(allowed, userID, roles := 0) {
	; Blank configuration is unconfigured, never an implicit public controller.
	if !RegExMatch(allowed, "^&?\d{17,20}$") || !RegExMatch(userID, "^\d{17,20}$")
		return false
	if SubStr(allowed, 1, 1) != "&"
		return allowed = userID
	if !(roles is Array)
		return false
	for role in roles
		if role = SubStr(allowed, 2)
			return true
	return false
}
