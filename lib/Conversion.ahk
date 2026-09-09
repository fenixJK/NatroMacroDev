nm_convert(){
	global AFBrollingDice, AFBuseGlitter, AFBuseBooster, CurrentField, HiveConfirmed, EnzymesKey, LastEnzymes
		, ConvertStartTime, TotalConvertTime, SessionConvertTime
		, BackpackPercent, BackpackPercentFiltered
		, PFieldBoosted, GatherFieldBoosted, GatherFieldBoostedStart, LastGlitter, GlitterKey
		, GameFrozenCounter, LastConvertBalloon, ConvertBalloon, ConvertMins, HiveBees, ConvertGatherFlag

	if (nm_NightInterrupt() || nm_MondoInterrupt())
		return

	hwnd := GetRobloxHWND()
	offsetY := GetYOffset(hwnd)
	GetRobloxClientPos(hwnd)
	pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY+36 "|400|120")
	if ((HiveConfirmed = 0) || (state = "Converting") || (Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , , , 2, , 6) != 1)) {
		Gdip_DisposeImage(pBMScreen)
		return
	}
	if (Gdip_ImageSearch(pBMScreen, bitmaps["makehoney"], , , , , , 2, , 2) = 1) {
		SendInput "{" SC_E " down}"
		Sleep 100
		SendInput "{" SC_E " up}"
	}
	Gdip_DisposeImage(pBMScreen)
	return nm_TimeTracking.Run("Convert", nm_ConvertAtHive.Bind(hwnd, offsetY))
}

nm_ConvertAtHive(hwnd, offsetY) {
	global AFBrollingDice, AFBuseGlitter, AFBuseBooster, CurrentField, HiveConfirmed, EnzymesKey, LastEnzymes
		, ConvertStartTime, TotalConvertTime, SessionConvertTime
		, BackpackPercent, BackpackPercentFiltered
		, PFieldBoosted, GatherFieldBoosted, GatherFieldBoostedStart, LastGlitter, GlitterKey
		, GameFrozenCounter, LastConvertBalloon, ConvertBalloon, ConvertMins, HiveBees, ConvertGatherFlag
	if !IsNumber(BackpackPercentFiltered) || BackpackPercentFiltered < 0 || BackpackPercentFiltered > 100 {
		nm_setStatus("Interrupted", "Backpack observation unavailable")
		return 0
	}
	inactiveHoney:=0
	ballooncomplete:=0
	;empty pack
	if (BackpackPercentFiltered > 0) {
		nm_setStatus("Converting", "Backpack")
		while (((BackpackConvertTime := nm_TimeTracking.Elapsed("Convert"))<300) && (BackpackPercentFiltered>0)) { ;5 mins
			Sleep 1000
			nm_AutoFieldBoost(currentField)
			if(AFBuseGlitter || AFBuseBooster) {
				nm_setStatus("Interrupted", "AFB")
				return
			}
			if (disconnectcheck()) {
				return
			}
			if (PFieldBoosted && (nowUnix()-GatherFieldBoostedStart)>780 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {
				nm_setStatus("Interrupted", "Field Boosted")
				return
			}
			inactiveHoney := (nm_activeHoney() = 0) ? inactiveHoney + 1 : 0
			if (BackpackConvertTime>60 && inactiveHoney>30) {
				nm_setStatus("Interrupted", "Inactive Honey")
				GameFrozenCounter++
				return
			}
			GetRobloxClientPos(hwnd)
			pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY+36 "|" windowWidth//2+200 "|" windowHeight-offsetY-36)
			if (Gdip_ImageSearch(pBMScreen, bitmaps["makehoney"], , , , 400, 120, 2, , 2) = 1) {
				SendInput "{" SC_E " down}"
				Sleep 100
				SendInput "{" SC_E " up}"
			}
			if ((Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , 400, 120, 2, , 6) = 0)
				|| ((Gdip_ImageSearch(pBMScreen, bitmaps["hiveballoon"], , windowWidth//2, windowHeight-offsetY-36-400, , , 40, , 3) = 1) && (ballooncomplete:=1))) {
				Gdip_DisposeImage(pBMScreen)
				break
			}
			Gdip_DisposeImage(pBMScreen)
		}
		duration := DurationFromSeconds(nm_TimeTracking.Elapsed("Convert"), "mm:ss")
		if !nm_BackpackConversionComplete(BackpackPercentFiltered) {
			nm_setStatus("Interrupted", (BackpackConvertTime >= 300 ? "Backpack conversion timed out" : "Backpack conversion unconfirmed") "`nTime: " duration)
			return 0
		}
		nm_setStatus("Converting", "Backpack Emptied`nTime: " duration)
	}
	;empty balloon
	if((ConvertBalloon="always") || (ConvertBalloon="Every" && (nowUnix() - LastConvertBalloon)>(ConvertMins*60)) || (ConvertBalloon="Gather" && (ConvertGatherFlag=1 || (nowUnix() - LastConvertBalloon)>2700))) {
		ConvertGatherFlag := 0
		;balloon check
		strikes:=0
		while ((strikes <= 5) && (A_Index <= 50)) {
			GetRobloxClientPos(hwnd)
			pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY+36 "|" windowWidth//2+200 "|" windowHeight-offsetY-36)
			if ((ballooncomplete = 1) || (Gdip_ImageSearch(pBMScreen, bitmaps["hiveballoon"], , windowWidth//2, windowHeight-offsetY-36-400, , , 40, , 3) = 1)) {
				Gdip_DisposeImage(pBMScreen)
				nm_setStatus("Converting", "Balloon Refreshed")
				IniWrite LastConvertBalloon:=nowUnix(), "settings\nm_config.ini", "Settings", "LastConvertBalloon"
				PostSubmacroMessage("background", 0x5554, 6, LastConvertBalloon)
				strikes := 10
				break
			}
			if (Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , 400, 120, 2, , 6) != 1)
				strikes++
			Gdip_DisposeImage(pBMScreen)
			Sleep 100
		}
		if (strikes <= 5) {
			BalloonStartTime := nm_TimeTracking.Elapsed("Convert")
			inactiveHoney:=0
			nm_setStatus("Converting", "Balloon")
			while((BalloonConvertTime := nm_TimeTracking.Elapsed("Convert")-BalloonStartTime)<600) { ;10 mins
				nm_AutoFieldBoost(currentField)
				if(AFBuseGlitter || AFBuseBooster) {
					nm_setStatus("Interrupted", "AFB")
					return
				}
				inactiveHoney := (nm_activeHoney() = 0) ? inactiveHoney + 1 : 0
				if(((EnzymesKey!="none") && (!PFieldBoosted || (PFieldBoosted && GatherFieldBoosted))) && (nowUnix()-LastEnzymes)>600 && (inactiveHoney = 0)) {
					Send "{" EnzymesKey "}"
					LastEnzymes:=nowUnix()
					IniWrite LastEnzymes, "settings\nm_config.ini", "Boost", "LastEnzymes"
				}
				if (BalloonConvertTime>60 && inactiveHoney>30) {
					nm_setStatus("Interrupted", "Inactive Honey")
					GameFrozenCounter++
					return
				}
				if (disconnectcheck()) {
					return
				}
				if ((PFieldBoosted = 1) && (nowUnix()-GatherFieldBoostedStart)>780 && (nowUnix()-GatherFieldBoostedStart)<900 && (nowUnix()-LastGlitter)>900 && GlitterKey!="none") {
					nm_setStatus("Interrupted", "Field Boosted")
					return
				}
				GetRobloxClientPos(hwnd)
				if (Mod(A_Index, 30) = 0) {
					MouseMove windowX+windowWidth-30, windowY+offsetY+16
					click
				}
				pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY+36 "|" windowWidth//2+200 "|" windowHeight-offsetY-36)
				if (Gdip_ImageSearch(pBMScreen, bitmaps["makehoney"], , , , 400, 120, 2, , 2) = 1) {
					SendInput "{" SC_E " down}"
					Sleep 100
					SendInput "{" SC_E " up}"
				}
				if ((Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , 400, 120, 2, , 6) = 0)
					|| (Gdip_ImageSearch(pBMScreen, bitmaps["hiveballoon"], , windowWidth//2, windowHeight-offsetY-36-400, , , 40, , 3) = 1)) {
					Gdip_DisposeImage(pBMScreen)
					ballooncomplete:=1
					break
				}
				Gdip_DisposeImage(pBMScreen)
				Sleep 1000
			}
			if(ballooncomplete){
				duration := DurationFromSeconds(BalloonConvertTime, "mm:ss")
				nm_setStatus("Converting", "Balloon Refreshed`nTime: " duration)
				IniWrite LastConvertBalloon:=nowUnix(), "settings\nm_config.ini", "Settings", "LastConvertBalloon"
				PostSubmacroMessage("background", 0x5554, 6, LastConvertBalloon)
			}
		}
	}
}
