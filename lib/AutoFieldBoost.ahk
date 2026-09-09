; Automatic field boosting. The main script owns UI/configuration; all item
; actions pass through the same live budget, time, and input-focus checks.

nm_CancelAFB(reason := "") {
	global AutoFieldBoostActive, AFBrollingDice, AFBuseGlitter, AFBuseBooster
	AutoFieldBoostActive := AFBrollingDice := AFBuseGlitter := AFBuseBooster := 0
	IniWrite 0, "settings\nm_config.ini", "Boost", "AutoFieldBoostActive"
	try AFBGui["AutoFieldBoostActive"].Value := 0
	try MainGui["AutoFieldBoostButton"].Text := "Auto Field Boost`n[OFF]"
	if reason
		nm_setStatus("Aborting", "Auto Field Boost: " reason)
}

nm_AFBReady() {
	if (!AutoFieldBoostActive || MacroState != 2)
		return false
	if !IsSet(serverStart)
		return false
	if !nm_TimeBudgetAvailable(AFBHoursLimitEnable, serverStart, nowUnix(), AFBHoursLimit) {
		nm_CancelAFB("Time limit reached")
		return false
	}
	return true
}

nm_DisableAFBItem(item) {
	global AFBDiceEnable, AFBGlitterEnable, AFBrollingDice, AFBuseGlitter
	if item = "Dice"
		AFBDiceEnable := AFBrollingDice := 0
	else if item = "Glitter"
		AFBGlitterEnable := AFBuseGlitter := 0
	else
		throw ValueError("Unknown automatic boost item")
	IniWrite 0, "settings\nm_config.ini", "Boost", "AFB" item "Enable"
	try AFBGui["AFB" item "Enable"].Value := 0
	if (!AFBDiceEnable && !AFBGlitterEnable && !AFBFieldEnable)
		nm_CancelAFB("Item budgets exhausted")
}

nm_AFBSendItem(item) {
	global AFBDiceEnable, AFBDiceLimitEnable, AFBDiceLimit, AFBdiceUsed, AFBDiceHotbar
		, AFBGlitterEnable, AFBGlitterLimitEnable, AFBGlitterLimit, AFBglitterUsed, AFBGlitterHotbar
	if (item != "Dice" && item != "Glitter")
		throw ValueError("Unknown automatic boost item")
	if !nm_AFBReady()
		return false
	hwnd := GetRobloxHWND()
	if !hwnd {
		nm_CancelAFB("Roblox window unavailable")
		return false
	}
	ActivateRoblox()
	previousCritical := A_IsCritical
	Critical
	try {
		; No timer/UI interrupt can change the budget between this check and input.
		if !nm_AFBReady() || !WinActive("ahk_id " hwnd)
			return false
		prefix := "AFB" item
		if !nm_BudgetAvailable(AutoFieldBoostActive, %prefix%Enable, %prefix%LimitEnable, %prefix%Used, %prefix%Limit) {
			nm_DisableAFBItem(item)
			return false
		}
		if !IsInteger(%prefix%Hotbar) || %prefix%Hotbar < 2 || %prefix%Hotbar > 7 {
			nm_CancelAFB("Select a valid hotbar slot (2-7)")
			return false
		}
		%prefix%Used += 1
		; Persist before sending: a failed write must never permit untracked use.
		IniWrite %prefix%Used, "settings\nm_config.ini", "Boost", prefix "Used"
		Send "{sc00" %prefix%Hotbar+1 "}"
		if %prefix%LimitEnable && %prefix%Used >= %prefix%Limit
			nm_DisableAFBItem(item)
		return true
	} finally
		Critical previousCritical
}

nm_AutoFieldBoost(fieldName){
	global FieldBooster, AFBrollingDice, AFBuseGlitter, AFBuseBooster, serverStart, AutoFieldBoostActive
		, FieldLastBoosted, FieldLastBoostedBy, FieldBoostStacks, AutoFieldBoostRefresh, AFBHoursLimitEnable
		, AFBHoursLimit, AFBFieldEnable, AFBDiceEnable, AFBGlitterEnable, MainGui, AFBGui
		, LastBlueBoost, LastRedBoost, LastMountainBoost

	if !nm_AFBReady()
		return

	if(not AFBrollingDice && ((nowUnix()-FieldLastBoosted)>(AutoFieldBoostRefresh*60) || (nowUnix()-FieldLastBoosted)<0)){ ;refresh period exceeded
		;check for field boost stack reset
		if((nowUnix()-FieldLastBoosted)>=(15*60)){ ;longer than 15 mins since last boost buff
			IniWrite FieldBoostStacks:=0, "settings\nm_config.ini", "Boost", "FieldBoostStacks"
			IniWrite FieldLastBoostedBy:="None", "settings\nm_config.ini", "Boost", "FieldLastBoostedBy"
		}
		;free booster first
		if(AFBFieldEnable){
			;determine which booster applies
			if((booster := FieldBooster[StrLower(fieldName)].booster)!="none") {
				boosterTimer := Last%booster%Boost
				if (nowUnix() - boosterTimer > 2700){
					AFBuseBooster:=1
				}
			}
		}
		;dice next
		if(AFBDiceEnable && not AFBrollingDice && (FieldLastBoostedBy="none" || FieldLastBoostedBy="glitter" || FieldLastBoostedBy="bbooster" || FieldLastBoostedBy="rbooster" || FieldLastBoostedBy="mbooster"
			|| (FieldLastBoostedBy="dice" && not AFBGlitterEnable))) {
			AFBrollingDice:=1
			nm_setStatus(0, "Boosting Field: Dice")
		}
		;glitter next
		if(AFBGlitterEnable && not AFBrollingDice && (FieldLastBoostedBy="none" || FieldLastBoostedBy="dice" || FieldLastBoostedBy="bbooster" || FieldLastBoostedBy="rbooster" || FieldLastBoostedBy="mbooster")) {
			nm_setStatus(0, "Boosting Field: Glitter")
			AFBuseGlitter:=1
		}

	} else { ;refresh period NOT exceeded
		return
	}
}
nm_fieldBoostCheck(fieldName, variant:=0){

	GetRobloxClientPos(hwnd:=GetRobloxHWND())
	pBMScreen:=Gdip_BitmapFromScreen(windowX "|" windowY + GetYOffset(hwnd) + 36 "|" windowWidth "|" 38)
	loop Floor(windowWidth/38) ; flooring because you won't have half of an icon
	{
		ico:=(A_Index-1)*38
		if (Gdip_ImageSearch(pBMScreen, bitmaps["boost"][StrReplace(fieldName, " ") variant],,ico,,ico+38,,(variant=1 || variant=0) ? 35 : 50)) ; testing tighter variation
		{ ; check with original 30 not 35
			p:=PixelGetColor(ico+windowX, windowY+GetYOffset(hwnd)+73)
			if ((p & 0xFF0000 >= 0xa60000) && (p & 0xFF0000 <= 0xcf0000)) ; a6b2b8-blackBG|cfdbe1-whiteBG
			&& ((p & 0x00FF00 >= 0x00b200) && (p & 0x00FF00 <= 0x00db00))
			&& ((p & 0x0000FF >= 0x0000b8) && (p & 0x0000FF <= 0x0000e1))
				continue ; winds: keep searching, winds and booster may both have boosted the field
			else if ((p & 0xFF0000 >= 0xb80000) && (p & 0xFF0000 <= 0xe10000)) ; b8a43a-blackBG|e1cd63-whiteBG
				&& ((p & 0x00FF00 >= 0x00a400) && (p & 0x00FF00 <= 0x00cd00))
				&& ((p & 0x0000FF >= 0x00003a) && (p & 0x0000FF <= 0x000063))
				{
					Gdip_DisposeImage(pBMScreen)
					return 1 ; booster
				}
		}
	}
	Gdip_DisposeImage(pBMScreen)
	return 0

}
nm_fieldBoostBooster(){
	global CurrentField, FieldBooster, AFBuseBooster, FieldLastBoosted, FieldBoostStacks, FieldLastBoostedBy, FieldNextBoostedBy, AFBFieldEnable, AFBDiceEnable, AFBGlitterEnable, FieldBoostStacks
	if (!AFBuseBooster || !AFBFieldEnable || !nm_AFBReady())
		return
	AFBuseBooster:=0
	nm_setStatus(0, "Boosting Field: Booster")
	booster := FieldBooster[StrLower(CurrentField)].booster
	if(booster="blue") {
		boosterName:="bbooster"
		nm_toBooster("blue")
	}
	else if(booster="red") {
		boosterName:="rbooster"
		nm_toBooster("red")
	}
	else if(booster="mountain") {
		boosterName:="mbooster"
		nm_toBooster("mountain")
	}
	Sleep 5000
	;check if gathering field was boosted
	if(nm_fieldBoostCheck(CurrentField)) {
		nm_setStatus(0, "Field was Boosted: Booster")
		FieldLastBoosted:=nowUnix()
		FieldLastBoostedBy:=boosterName
		IniWrite FieldLastBoosted, "settings\nm_config.ini", "Boost", "FieldLastBoosted"
		IniWrite FieldLastBoostedBy, "settings\nm_config.ini", "Boost", "FieldLastBoostedBy"
		FieldBoostStacks:=FieldBoostStacks+FieldBooster[StrLower(CurrentField)].stacks
		IniWrite FieldBoostStacks, "settings\nm_config.ini", "Boost", "FieldBoostStacks"
		if(FieldBoostStacks>4)
			return
	}
	;determine next boost item
	;is it dice?
	if(AFBDiceEnable && (FieldLastBoostedBy="bbooster" || FieldLastBoostedBy="rbooster" || FieldLastBoostedBy="mbooster"|| FieldLastBoostedBy="glitter" || (FieldLastBoostedBy="dice" && not AFBGlitterEnable))) {
		FieldNextBoostedBy:="dice"
		IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
	}
	;is it glitter?
	else if(AFBGlitterEnable && (FieldLastBoostedBy="dice" || ((FieldLastBoostedBy="bbooster" || FieldLastBoostedBy="rbooster" || FieldLastBoostedBy="mbooster")|| not AFBDiceEnable) || (FieldLastBoostedBy="glitter" && not AFBDiceEnable))) {
		FieldNextBoostedBy:="glitter"
		IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
	}
	;is it booster?
	else if(AFBFieldEnable && not AFBDiceEnable && not AFBGlitterEnable) {
		FieldNextBoostedBy:=boosterName
		IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
	}
}
nm_fieldBoostDice(){
	global AFBrollingDice, AFBdiceUsed, AFBDiceLimit, AFBDiceLimitEnable, CurrentField, FieldBooster, boostTimer
		, FieldLastBoosted, FieldLastBoostedBy, FieldNextBoostedBy, FieldBoostStacks, AutoFieldBoostRefresh
		, AFBFieldEnable, AFBDiceEnable, AFBGlitterEnable, AFBDiceHotbar, MainGui, AFBGui
	if (!AFBrollingDice || !nm_AFBReady())
		return
	if(not nm_fieldBoostCheck(CurrentField)) {
		nm_AFBSendItem("Dice")
	} else {
		AFBrollingDice:=0
		nm_setStatus(0, "Field was Boosted: Dice")
		if(FieldLastBoostedBy!="dice" || FieldBoostStacks=0) {
			FieldBoostStacks:=FieldBoostStacks+1
			FieldLastBoostedBy:="dice"
			IniWrite FieldLastBoostedBy, "settings\nm_config.ini", "Boost", "FieldLastBoostedBy"
			IniWrite FieldBoostStacks, "settings\nm_config.ini", "Boost", "FieldBoostStacks"
		}
		FieldLastBoosted:=nowUnix()
		IniWrite FieldLastBoosted, "settings\nm_config.ini", "Boost", "FieldLastBoosted"
		;determine next boost item
		;is it booster?
		booster := FieldBooster[StrLower(CurrentField)].booster
		if(booster="blue") {
			boosterName:="bbooster"
			boostTimer := LastBlueBoost
		}
		else if(booster="red") {
			boosterName:="rbooster"
			boostTimer := LastRedBoost
		}
		else if(booster="mountain") {
			boosterName:="mbooster"
			boostTimer := LastMountainBoost
		}
		if(AFBFieldEnable && (nowUnix()-boostTimer)>(3600-AutoFieldBoostRefresh*60)) {
			FieldNextBoostedBy:=boosterName
			IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
		}
		;is it glitter?
		else if(AFBGlitterEnable) {
			FieldNextBoostedBy:="glitter"
			IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
		}
		;is it dice?
		else if(not AFBGlitterEnable) {
			FieldNextBoostedBy:="dice"
			IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
		}
	}
}
nm_fieldBoostGlitter(){
	global AFBuseGlitter, AFBglitterUsed, CurrentField, FieldBooster, boostTimer, FieldLastBoosted, FieldLastBoostedBy, FieldNextBoostedBy, FieldBoostStacks
		, AutoFieldBoostRefresh, AFBFieldEnable, AFBDiceEnable, AFBGlitterEnable, AFBdiceHotbar, AFBGlitterHotbar, AFBGlitterLimit, AFBGlitterLimitEnable
	if (!AFBuseGlitter || !nm_AFBReady())
		return
	; Reserve every attempt, even if the game rejects input or confirmation fails.
	; Clear pending work before yielding so another invocation cannot repeat it.
	AFBuseGlitter := 0
	if !nm_AFBSendItem("Glitter")
		return
	Sleep 2000
	if(nm_fieldBoostCheck(CurrentField)) {
		nm_setStatus(0, "Field was Boosted: Glitter")
		AFBuseGlitter:=0
		FieldLastBoosted:=nowUnix()
		FieldLastBoostedBy:="glitter"
		IniWrite FieldLastBoosted, "settings\nm_config.ini", "Boost", "FieldLastBoosted"
		IniWrite FieldLastBoostedBy, "settings\nm_config.ini", "Boost", "FieldLastBoostedBy"
		FieldBoostStacks:=FieldBoostStacks+1
		IniWrite FieldBoostStacks, "settings\nm_config.ini", "Boost", "FieldBoostStacks"
		;determine next boost item
		;is it booster?
		booster := FieldBooster[StrLower(CurrentField)].booster
		if(booster="blue") {
			boosterName:="bbooster"
			boostTimer := LastBlueBoost
		}
		else if(booster="red") {
			boosterName:="rbooster"
			boostTimer := LastRedBoost
		}
		else if(booster="mountain") {
			boosterName:="mbooster"
			boostTimer := LastMountainBoost
		}
		if(AFBFieldEnable && (nowUnix()-boostTimer)>(3600-AutoFieldBoostRefresh*60)) {
			FieldNextBoostedBy:=boosterName
			IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
		}
		;is it dice?
		else if(AFBDiceEnable) {
			FieldNextBoostedBy:="dice"
			IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
		}
		;is it glitter?
		else if(not AFBDiceEnable) {
			FieldNextBoostedBy:="glitter"
			IniWrite FieldNextBoostedBy, "settings\nm_config.ini", "Boost", "FieldNextBoostedBy"
		}

	} else {
		nm_CancelAFB("Glitter result could not be confirmed. Check the field and item before re-enabling AFB.")
	}
}

nm_AFBDiceLimitEnable(*){
	global
	AFBDiceLimitEnableSel := AFBGui["AFBDiceLimitEnableSel"].Text
	AFBDiceLimitEnable := (AFBDiceLimitEnableSel = "Limit")
	AFBGui["AFBDiceLimit"].Enabled := AFBDiceLimitEnable
	IniWrite AFBDiceLimitEnable, "settings\nm_config.ini", "Boost", "AFBDiceLimitEnable"
}
nm_AFBGlitterLimitEnable(*){
	global
	AFBGlitterLimitEnableSel := AFBGui["AFBGlitterLimitEnableSel"].Text
	AFBGlitterLimitEnable := (AFBGlitterLimitEnableSel = "Limit")
	AFBGui["AFBGlitterLimit"].Enabled := AFBGlitterLimitEnable
	IniWrite AFBGlitterLimitEnable, "settings\nm_config.ini", "Boost", "AFBGlitterLimitEnable"
}
nm_AFBHoursLimitEnable(*){
	global
	AFBHoursLimitEnableSel := AFBGui["AFBHoursLimitEnableSel"].Text
	AFBHoursLimitEnable := (AFBHoursLimitEnableSel = "Limit")
	AFBGui["AFBHoursLimit"].Enabled := AFBHoursLimitEnable
	IniWrite AFBHoursLimitEnable, "settings\nm_config.ini", "Boost", "AFBHoursLimitEnable"
}
