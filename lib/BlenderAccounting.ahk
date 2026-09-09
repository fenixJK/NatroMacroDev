nm_BlenderEligible(recipe) {
	return recipe.item != "" && recipe.item != "None"
		&& IsInteger(recipe.amount) && recipe.amount > 0 && recipe.amount <= 999
		&& (recipe.remaining = "Infinite" || (IsInteger(recipe.remaining) && recipe.remaining > 0))
}

nm_BlenderPlanCraft(recipes, executed, started) {
	if recipes.Length != 3 || !IsInteger(executed) || executed < 1 || executed > 3
		throw ValueError("Invalid Blender rotation")
	if !nm_BlenderEligible(recipes[executed]) || !IsNumber(started) || started <= 0
		throw ValueError("Invalid Blender craft")
	current := recipes[executed]
	remaining := current.remaining = "Infinite" ? "Infinite" : current.remaining - 1
	plan := Map("LastBlenderRot", executed, "TimerInterval", current.amount * 300,
		"BlenderIndex" executed, remaining, "BlenderCount" executed, 0,
		"BlenderRot", executed, "BlenderCheck", 1, "BlenderEnd", 0)
	finish := started + current.amount * 300
	Loop 3
		plan["BlenderTime" A_Index] := 0
	plan["BlenderTime" executed] := finish
	next := 0
	Loop 2 {
		slot := Mod(executed + A_Index - 1, 3) + 1
		if nm_BlenderEligible(recipes[slot]) {
			if !next
				next := slot
			finish += recipes[slot].amount * 300
			plan["BlenderTime" slot] := finish
		}
	}
	; A single remaining recipe may repeat; even an exhausted final recipe keeps
	; BlenderCheck on until its in-progress craft has been collected.
	if next
		plan["BlenderRot"] := next
	return plan
}

nm_BlenderReadRecipes() {
	global BlenderItem1, BlenderItem2, BlenderItem3, BlenderAmount1, BlenderAmount2, BlenderAmount3
		, BlenderIndex1, BlenderIndex2, BlenderIndex3
	recipes := []
	Loop 3
		recipes.Push({item: BlenderItem%A_Index%, amount: BlenderAmount%A_Index%, remaining: BlenderIndex%A_Index%})
	return recipes
}

nm_BlenderWriteSetting(key, value) {
	IniWrite value, "settings\nm_config.ini", "Blender", key
}

nm_BlenderApplyPlan(plan, writeSetting := 0) {
	global BlenderRot, LastBlenderRot, TimerInterval, BlenderCheck, BlenderEnd
		, BlenderIndex1, BlenderIndex2, BlenderIndex3, BlenderCount1, BlenderCount2, BlenderCount3
		, BlenderTime1, BlenderTime2, BlenderTime3, BlenderAmount1, BlenderAmount2, BlenderAmount3, MainGui
	if !(plan is Map) || plan.Count != 10
		throw ValueError("Invalid Blender recovery record")
	for required in ["LastBlenderRot", "BlenderRot", "TimerInterval", "BlenderCheck", "BlenderEnd", "BlenderTime1", "BlenderTime2", "BlenderTime3"]
		if !plan.Has(required)
			throw ValueError("Incomplete Blender recovery record")
	executed := plan["LastBlenderRot"]
	if !IsInteger(executed) || executed < 1 || executed > 3 || !plan.Has("BlenderIndex" executed) || !plan.Has("BlenderCount" executed)
		throw ValueError("Invalid executed Blender slot")
	if !IsInteger(plan["BlenderRot"]) || plan["BlenderRot"] < 1 || plan["BlenderRot"] > 3
		throw ValueError("Invalid next Blender slot")
	if plan["BlenderCheck"] != 1 || plan["BlenderEnd"] != 0 || plan["BlenderCount" executed] != 0
		throw ValueError("Invalid Blender craft state")
	for key, value in plan {
		if !RegExMatch(key, "^(LastBlenderRot|BlenderRot|TimerInterval|BlenderCheck|BlenderEnd|Blender(Index|Count|Time)[1-3])$")
			throw ValueError("Unknown Blender recovery key")
		if key = "BlenderIndex" executed {
			if value != "Infinite" && (!IsInteger(value) || value < 0)
				throw ValueError("Invalid Blender remaining count")
		} else if !IsNumber(value) || value < 0
			throw ValueError("Invalid Blender recovery value")
	}
	if !writeSetting
		writeSetting := nm_BlenderWriteSetting
	; Absolute values make replay idempotent, including the decremented counter.
	writeSetting.Call("PendingCommit", JSON.stringify(plan, 0))
	for key, value in plan
		writeSetting.Call(key, value)
	for key, value in plan
		%key% := value
	Loop 3
		try MainGui["BlenderData" A_Index].Text := "(" BlenderAmount%A_Index% ") [" (BlenderIndex%A_Index% = "Infinite" ? "∞" : BlenderIndex%A_Index%) "]"
	writeSetting.Call("PendingAttempt", "")
	writeSetting.Call("PendingCommit", "")
}

nm_BlenderRecoverCommit() {
	record := IniRead("settings\nm_config.ini", "Blender", "PendingCommit", "")
	if record != ""
		nm_BlenderApplyPlan(JSON.parse(record))
}

nm_BlenderCommitAccepted(executed, expected, confirmed, started, writeSetting := 0) {
	if confirmed != 1
		return 0
	previousCritical := A_IsCritical
	Critical
	try {
		recipes := nm_BlenderReadRecipes()
		current := recipes[executed]
		if current.item != expected.item || current.amount != expected.amount || current.remaining != expected.remaining
			return 0 ; an edit during the action must not charge a different recipe
		plan := nm_BlenderPlanCraft(recipes, executed, started)
		nm_BlenderApplyPlan(plan, writeSetting)
		return 1
	} finally Critical previousCritical
}

nm_BlenderRotation() {
	global BlenderRot, LastBlenderRot, BlenderCheck, BlenderTime1, BlenderTime2, BlenderTime3
	recipes := nm_BlenderReadRecipes()
	configured := false
	Loop 3 {
		eligible := nm_BlenderEligible(recipes[BlenderRot])
		configured := configured || eligible
		retryAfter := IniRead("settings\nm_config.ini", "Blender", "Unavailable" BlenderRot, 0)
		available := !IsNumber(retryAfter) || nowUnix() >= retryAfter || retryAfter - nowUnix() > 300
		if eligible && available {
			BlenderCheck := 1
			IniWrite BlenderCheck, "settings\nm_config.ini", "Blender", "BlenderCheck"
			return BlenderRot
		}
		BlenderRot := Mod(BlenderRot, 3) + 1
	}
	BlenderCheck := configured || BlenderTime%LastBlenderRot% > 0
	IniWrite BlenderCheck, "settings\nm_config.ini", "Blender", "BlenderCheck"
	return 0
}


nm_BlenderRememberAttempt(slot, expected, started) {
	if !nm_BlenderEligible(expected) || slot < 1 || slot > 3
		throw ValueError("Invalid Blender attempt")
	attempt := Map("slot", slot, "item", expected.item, "amount", expected.amount,
		"remaining", expected.remaining, "started", started, "pid", DllCall("GetCurrentProcessId"))
	nm_BlenderWriteSetting("PendingAttempt", JSON.stringify(attempt, 0))
	return attempt
}

nm_BlenderReadAttempt() {
	record := IniRead("settings\nm_config.ini", "Blender", "PendingAttempt", "")
	if !record
		return 0
	attempt := JSON.parse(record)
	if !(attempt is Map) || attempt.Count != 6
		throw ValueError("Invalid pending Blender attempt")
	for key in ["slot", "item", "amount", "remaining", "started", "pid"]
		if !attempt.Has(key)
			throw ValueError("Incomplete pending Blender attempt")
	if !IsInteger(attempt["slot"]) || attempt["slot"] < 1 || attempt["slot"] > 3 || !IsNumber(attempt["started"])
		throw ValueError("Invalid pending Blender attempt values")
	return attempt
}

nm_BlenderResolveAttempt(attempt, observedItem, running, finished, current) {
	if !attempt || (running != 1 && finished != 1) || running < 0 || finished < 0
		return 0
	if observedItem != attempt["item"] || attempt["pid"] != DllCall("GetCurrentProcessId")
		return 0
	expected := {item: attempt["item"], amount: attempt["amount"], remaining: attempt["remaining"]}
	if !nm_BlenderEligible(expected) || current < attempt["started"] || current - attempt["started"] > expected.amount * 300 + 3600
		return 0
	return nm_BlenderCommitAccepted(attempt["slot"], expected, 1, attempt["started"])
}

nm_BlenderRecipeUnchanged(slot, expected) {
	current := nm_BlenderReadRecipes()[slot]
	return current.item = expected.item && current.amount = expected.amount && current.remaining = expected.remaining
}
