nm_Blender(){
	global BlenderCheck, BlenderRot, LastBlenderRot, BlenderEnd, TimerInterval
	, BlenderIndex1, BlenderIndex2, BlenderIndex3
	, BlenderItem1, BlenderItem2, BlenderItem3
	, BlenderTime1, BlenderTime2, BlenderTime3
	, BlenderAmount1, BlenderAmount2, BlenderAmount3
	, BlenderCount1, BlenderCount2, BlenderCount3

	nm_BlenderRecoverCommit()
	nextRecipe := nm_BlenderRotation()
	if !nextRecipe && BlenderTime%LastBlenderRot% <= 0
		return
	TimeForBlender := BlenderTime%LastBlenderRot% - TimerInterval ; due to BlenderTime being calcuted with TimerInterval integrated to fix that we simply subtract it before

	if (BlenderCheck && (nowUnix() - TimeForBlender) > TimerInterval) {
		retryAfter := IniRead("settings\nm_config.ini", "Blender", "RetryAfter", 0)
		if !BlenderEnd && IsNumber(retryAfter) && nowUnix() < retryAfter && retryAfter - nowUnix() <= 300
			return
		IniWrite nowUnix() + 300, "settings\nm_config.ini", "Blender", "RetryAfter"
		committed := false
		Loop 2 {
			hwnd := GetRobloxHWND()
			offsetY := GetYOffset(hwnd)
			GetRobloxClientPos(hwnd)
			nm_updateAction("Collect")

			z := A_Index ;Set variable for fail safe
			nm_Reset()
			nm_setStatus("Traveling", "Blender" ((A_Index > 1) ? " (Attempt 2)" : ""))
			nm_gotoCollect("Blender")
			hwnd := GetRobloxHWND()
			if !hwnd
				return
			GetRobloxClientPos(hwnd)
			context := {hwnd: hwnd, x: windowX, y: windowY, width: windowWidth, height: windowHeight}

			searchRet := nm_imgSearch("e_button.png", 30, "high")
			If (searchRet[1] = 0) {
				if !nm_BlenderSameWindow(hwnd, context.x, context.y, context.width, context.height)
					return
				sendinput "{" SC_E " down}"
				Sleep 100
				sendinput "{" SC_E " up}"
				Sleep 500

				SearchX := windowX+windowWidth//2 - 275, SearchY := windowY+Floor(0.48*windowHeight) - 220, BlenderSS := Gdip_BitmapFromScreen(SearchX "|" SearchY "|550|400")

				nm_BlenderObservePending(BlenderSS)
				if (Gdip_ImageSearch(BlenderSS, bitmaps["CancelCraft"], , , , , , 2, , 7) > 0) {
					nm_BlenderClick(context, windowX+windowWidth//2 + 230, windowY+Floor(0.48*windowHeight) + 130)
				}

				if (!BlenderEnd && Gdip_ImageSearch(BlenderSS, bitmaps["EndCraftR"], , , , , , 3, , 6) > 0)
				{
					nm_setStatus("Confirmed", "Blender is already in use")
					Gdip_DisposeImage(BlenderSS)
					nm_BlenderClick(context, context.x+context.width//2-250, context.y+Floor(0.48*context.height)-200)
					break
				} else if (BlenderEnd && Gdip_ImageSearch(BlenderSS, bitmaps["EndCraftR"], , , , , , 3, , 6) > 0) {
					IniWrite 0, "settings\nm_config.ini", "Blender", "BlenderEnd"
					BlenderEnd := 0
					nm_BlenderClick(context, windowX+windowWidth//2 - 120, windowY+Floor(0.48*windowHeight) + 120)
				}

				if (Gdip_ImageSearch(BlenderSS, bitmaps["EndCraftG"], , , , , , 4, , 6) > 0) {
					nm_BlenderClick(context, windowX+WindowWidth//2 - 120, windowY+Floor(0.48*windowHeight) + 120)
					if nm_BlenderWaitForCollection(hwnd, windowX, windowY, windowWidth, windowHeight, BlenderItem%LastBlenderRot%) {
						BlenderTime%LastBlenderRot% := 0
						BlenderCount%LastBlenderRot% := BlenderAmount%LastBlenderRot%
						IniWrite 0, "settings\nm_config.ini", "Blender", "BlenderTime" LastBlenderRot
						IniWrite BlenderCount%LastBlenderRot%, "settings\nm_config.ini", "Blender", "BlenderCount" LastBlenderRot
						nm_setStatus("Collected", "Blender")
					} else {
						Gdip_DisposeImage(BlenderSS)
						nm_setStatus("Unconfirmed", "Blender collection; timer retained for recovery")
						return
					}
				}
				gdip_disposeimage(BlenderSS)
				Sleep 800
				if !nm_BlenderRotation() {
					nm_BlenderClick(context, windowX+windowWidth//2 - 250, windowY+Floor(0.48*windowHeight) - 200)
					return
				}
				loop
				{
					BlenderSS := Gdip_BitmapFromScreen(SearchX "|" SearchY "|170|245")

					executedSlot := BlenderRot
					expectedRecipe := nm_BlenderReadRecipes()[executedSlot]
					Blender := expectedRecipe.item
					BlenderIMG := Blender "B"

					if (Gdip_ImageSearch(BlenderSS, bitmaps[BlenderIMG], , , , , , 2, , 4) > 0)
					{
						gdip_disposeimage(BlenderSS)  ; Dispose of the bitmap
						Sleep 200
						BlenderSS := Gdip_BitmapFromScreen(SearchX "|" SearchY "|553|400")
						if (Gdip_ImageSearch(BlenderSS, bitmaps["NoItems"], , , , , , 2) > 0) {
							Gdip_DisposeImage(BlenderSS)
							IniWrite nowUnix() + 300, "settings\nm_config.ini", "Blender", "Unavailable" BlenderRot
							nm_setStatus("Waiting", "Blender ingredients unavailable for " Blender "; recipe retained")
							BlenderRot := Mod(BlenderRot, 3) + 1
							if !nm_BlenderRotation() {
								nm_BlenderClick(context, context.x+context.width//2-250, context.y+Floor(0.48*context.height)-200)
								return
							}
							break
						}
						gdip_disposeimage(BlenderSS)
						if !nm_BlenderRecipeUnchanged(executedSlot, expectedRecipe)
							return
						nm_BlenderClick(context, windowX+windowWidth//2, windowY+Floor(0.48*windowHeight) + 130)
						Sleep 150
						MouseMove windowX+windowWidth//2 - 60, windowY+Floor(0.48*windowHeight) + 140 ;Add more of x item
						Sleep 150
						While (A_Index < expectedRecipe.amount) {
							if !nm_BlenderSameWindow(hwnd, context.x, context.y, context.width, context.height)
								throw Error("Roblox focus or geometry changed while selecting a Blender quantity")
							Click
							Sleep 30
						}
						Sleep 200
						if !nm_BlenderRecipeUnchanged(executedSlot, expectedRecipe)
							return
						attemptStarted := nowUnix()
						nm_BlenderRememberAttempt(executedSlot, expectedRecipe, attemptStarted)
						nm_BlenderClick(context, windowX+windowWidth//2 + 70, windowY+Floor(0.48*windowHeight) + 130)
						confirmed := nm_BlenderWaitForCraft(hwnd, windowX, windowY, windowWidth, windowHeight)
						if nm_BlenderCommitAccepted(executedSlot, expectedRecipe, confirmed, attemptStarted) {
							committed := true
							IniWrite 0, "settings\nm_config.ini", "Blender", "RetryAfter"
							nm_setStatus("Crafting", "Blender: " expectedRecipe.item " (slot " executedSlot ")")
						} else {
							nm_setStatus("Unconfirmed", "Blender craft not recorded. Counts and timers retained; retry in 5 minutes.")
						}
						if nm_BlenderSameWindow(hwnd, context.x, context.y, context.width, context.height)
							nm_BlenderClick(context, context.x+context.width//2-250, context.y+Floor(0.48*context.height)-200)
						break 2
					} else {
						Sleep 50
						nm_BlenderClick(context, windowX+windowWidth//2 + 230, windowY+Floor(0.48*windowHeight) + 110)
						Sleep 100
						if (A_Index = 60) {
							if (z = 2) {
								nm_setStatus("Failed", "Blender")
								nm_BlenderClick(context, windowX+windowWidth//2 - 250, windowY+Floor(0.48*windowHeight) - 200)

							}
							break
						}
					}
				}
			}
		}
		if !committed
			IniWrite nowUnix() + 300, "settings\nm_config.ini", "Blender", "RetryAfter"
		IniWrite TimerInterval, "settings\nm_config.ini", "Blender", "TimerInterval"
		IniWrite BlenderRot, "settings\nm_config.ini", "Blender", "BlenderRot"
		IniWrite BlenderIndex%BlenderRot%, "settings\nm_config.ini", "Blender", "BlenderIndex" BlenderRot
	}
}
nm_BlenderSameWindow(hwnd, x, y, width, height) {
	global windowX, windowY, windowWidth, windowHeight
	if GetRobloxHWND() != hwnd || !WinActive("ahk_id " hwnd)
		return false
	GetRobloxClientPos(hwnd)
	return windowX = x && windowY = y && windowWidth = width && windowHeight = height
}

nm_BlenderWaitForCraft(hwnd, x, y, width, height) {
	global bitmaps
	Loop 25 {
		Sleep 200
		if !nm_BlenderSameWindow(hwnd, x, y, width, height)
			return 0
		bitmap := Gdip_BitmapFromScreen(x + width//2 - 275 "|" y + Floor(0.48*height) - 220 "|550|400")
		if !bitmap
			return 0
		try result := Gdip_ImageSearch(bitmap, bitmaps["EndCraftR"], , , , , , 3, , 6)
		finally Gdip_DisposeImage(bitmap)
		if result = 1
			return 1
		if result < 0
			return 0
	}
	return 0
}

nm_BlenderWaitForCollection(hwnd, x, y, width, height, item) {
	global bitmaps
	if !bitmaps.Has(item "B")
		return 0
	Loop 25 {
		Sleep 200
		if !nm_BlenderSameWindow(hwnd, x, y, width, height)
			return 0
		bitmap := Gdip_BitmapFromScreen(x + width//2 - 275 "|" y + Floor(0.48*height) - 220 "|550|400")
		if !bitmap
			return 0
		try {
			running := Gdip_ImageSearch(bitmap, bitmaps["EndCraftR"], , , , , , 3, , 6)
			finished := Gdip_ImageSearch(bitmap, bitmaps["EndCraftG"], , , , , , 4, , 6)
			recipe := Gdip_ImageSearch(bitmap, bitmaps[item "B"], , , , , , 2, , 4)
		} finally Gdip_DisposeImage(bitmap)
		if running < 0 || finished < 0 || recipe < 0
			return 0
		if running = 0 && finished = 0 && recipe = 1
			return 1
	}
	return 0
}

nm_BlenderClick(context, x, y) {
	if !nm_BlenderSameWindow(context.hwnd, context.x, context.y, context.width, context.height)
		throw Error("Roblox focus or geometry changed before a Blender click")
	MouseMove x, y
	Sleep 150
	if !nm_BlenderSameWindow(context.hwnd, context.x, context.y, context.width, context.height)
		throw Error("Roblox focus or geometry changed during a Blender click")
	Click
}

nm_BlenderObservePending(bitmap) {
	global bitmaps
	attempt := nm_BlenderReadAttempt()
	if !attempt || !bitmap || !bitmaps.Has(attempt["item"] "B")
		return 0
	running := Gdip_ImageSearch(bitmap, bitmaps["EndCraftR"], , , , , , 3, , 6)
	finished := Gdip_ImageSearch(bitmap, bitmaps["EndCraftG"], , , , , , 4, , 6)
	if running < 0 || finished < 0 || (running != 1 && finished != 1)
		return 0
	if Gdip_ImageSearch(bitmap, bitmaps[attempt["item"] "B"], , , , , , 2, , 4) != 1
		return 0
	return nm_BlenderResolveAttempt(attempt, attempt["item"], running, finished, nowUnix())
}
