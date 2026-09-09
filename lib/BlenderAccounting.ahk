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
	writeSetting.Call("PendingCommit", JSON.stringify(plan))
	for key, value in plan
		writeSetting.Call(key, value)
	for key, value in plan
		%key% := value
	Loop 3
		try MainGui["BlenderData" A_Index].Text := "(" BlenderAmount%A_Index% ") [" (BlenderIndex%A_Index% = "Infinite" ? "∞" : BlenderIndex%A_Index%) "]"
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
					MouseMove windowX+windowWidth//2 - 250, windowY+Floor(0.48*windowHeight) - 200
					Sleep 150
					Click
					return
				}
				loop
				{
					BlenderSS := Gdip_BitmapFromScreen(SearchX "|" SearchY "|170|245")

					Blender := %("BlenderItem" BlenderRot)%
					BlenderIMG := Blender "B"

					if (Gdip_ImageSearch(BlenderSS, bitmaps[BlenderIMG], , , , , , 2, , 4) > 0)
					{
						gdip_disposeimage(BlenderSS)  ; Dispose of the bitmap
						Sleep 200
						BlenderSS := Gdip_BitmapFromScreen(SearchX "|" SearchY "|553|400")
						if (Gdip_ImageSearch(BlenderSS, bitmaps["NoItems"], , , , , , 2) > 0) {
							BlenderItem%BlenderRot% := "None", BlenderAmount%BlenderRot% := 0, BlenderIndex%BlenderRot% := 1, BlenderTime%BlenderRot% := 0

							IniWrite "None", "settings\nm_config.ini", "Blender", "BlenderItem" BlenderRot
							IniWrite 0, "settings\nm_config.ini", "Blender", "BlenderAmount" BlenderRot
							IniWrite 1, "settings\nm_config.ini", "Blender", "BlenderIndex" BlenderRot
							IniWrite 0, "settings\nm_config.ini", "Blender", "BlenderTime" BlenderRot

							MainGui["BlenderAdd" BlenderRot].Text := ((BlenderItem%BlenderRot% = "None" || BlenderItem%BlenderRot% = "") ? "Add" : "Clear")
							MainGui["BlenderData" BlenderRot].Text := "(" BlenderAmount%BlenderRot% ") [" ((BlenderIndex%BlenderRot% = "Infinite") ? "∞" : BlenderIndex%BlenderRot%) "]"

							MainGui["BlenderItem" BlenderRot "Picture"].Value := ""
							gdip_disposeimage(BlenderSS)
							nm_BlenderRotation()
							if !(BlenderCheck)
								break 2
							break
						}
						gdip_disposeimage(BlenderSS)
						executedSlot := BlenderRot
						expectedRecipe := nm_BlenderReadRecipes()[executedSlot]
						MouseMove windowX+windowWidth//2, windowY+Floor(0.48*windowHeight) + 130 ;Open item menu
						Sleep 150
						click
						Sleep 150
						MouseMove windowX+windowWidth//2 - 60, windowY+Floor(0.48*windowHeight) + 140 ;Add more of x item
						Sleep 150
						While (A_Index < expectedRecipe.amount) {
							Click
							Sleep 30
						}
						Sleep 200
						MouseMove windowX+windowWidth//2 + 70, windowY+Floor(0.48*windowHeight) + 130 ; Confirm craft
						Sleep 150
						Click
						confirmed := nm_BlenderWaitForCraft(hwnd, windowX, windowY, windowWidth, windowHeight)
						if nm_BlenderCommitAccepted(executedSlot, expectedRecipe, confirmed, nowUnix()) {
							IniWrite 0, "settings\nm_config.ini", "Blender", "RetryAfter"
							nm_setStatus("Crafting", "Blender: " expectedRecipe.item " (slot " executedSlot ")")
						} else {
							nm_setStatus("Unconfirmed", "Blender craft not recorded. Counts and timers retained; retry in 5 minutes.")
						}
						MouseMove windowX+windowWidth//2 - 250, windowY+Floor(0.48*windowHeight) - 200 ;Close GUI
						Sleep 150
						Click
						break 2
					} else {
						Sleep 50
						MouseMove windowX+windowWidth//2 + 230, windowY+Floor(0.48*windowHeight) + 110 ;not found go next item
						Sleep 150
						Click
						Sleep 100
						if (A_Index = 60) {
							if (z = 2) {
								nm_setStatus("Failed", "Blender")
								MouseMove windowX+windowWidth//2 - 250, windowY+Floor(0.48*windowHeight) - 200 ;Close GUI
								Sleep 150
								Click

							}
							break
						}
					}
				}
			}
		}
		IniWrite TimerInterval, "settings\nm_config.ini", "Blender", "TimerInterval"
		IniWrite BlenderRot, "settings\nm_config.ini", "Blender", "BlenderRot"
		IniWrite BlenderIndex%BlenderRot%, "settings\nm_config.ini", "Blender", "BlenderIndex" BlenderRot
	}
}
nm_BlenderRotation() {
	global BlenderRot, LastBlenderRot, BlenderCheck, BlenderTime1, BlenderTime2, BlenderTime3
	recipes := nm_BlenderReadRecipes()
	Loop 3 {
		if nm_BlenderEligible(recipes[BlenderRot]) {
			BlenderCheck := 1
			IniWrite BlenderCheck, "settings\nm_config.ini", "Blender", "BlenderCheck"
			return BlenderRot
		}
		BlenderRot := Mod(BlenderRot, 3) + 1
	}
	BlenderCheck := BlenderTime%LastBlenderRot% > 0
	IniWrite BlenderCheck, "settings\nm_config.ini", "Blender", "BlenderCheck"
	return 0
}

