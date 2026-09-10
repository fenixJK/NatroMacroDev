; Production Planters+ adapter. Game input remains in the existing placement/harvest routines.
nm_AdaptivePlanterInterrupt() {
						interruptReason := "Planter Cycle"
						break
					}
					;Manual planter gather interrupt
					if ((fieldOverrideReason="Manual Planter") && (PlanterMode = 1) && (MPlanterGatherA)) {
						;update current field planter progress every 2 minutes during planter gather
						If ((nowUnix()-MPlanterGatherDetectionTime)>120) {
							nm_PlanterTimeUpdate(FieldName, 0)
							MPlanterGatherDetectionTime := nowUnix()
						}
						;interrupt if
						if (((nowUnix() >= PlanterHarvestTime1) && (eligible.Has(1))) || ((nowUnix() >= PlanterHarvestTime2) && (eligible.Has(2))) || ((nowUnix() >= PlanterHarvestTime3) && (eligible.Has(3)))) {
							interruptReason := "Planter Harvest"
							break
						}
					}
					if nm_BugrunInterrupt() {
						interruptReason := "Kill Bugs"
						break
					}
					if nm_BeesmasInterrupt() {
						interruptReason := "Beesmas Machine"
						break
					}
					if nm_MemoryMatchInterrupt() {
						interruptReason := "Memory Match"
						break
					}
				}
				Sleep 50
			}

			Click "Up"
			if interruptReason {
				bypass := (interruptReason ~= "i)Disconnect|You Died!|Night|Inactive Honey")
				if (!bypass && InStr(patterns[FieldPattern], ";@NoInterrupt"))
					KeyWait "F14", "T180 L"
				break
			}
			(FDCEnabled) && nm_fieldDriftCompensation()
		}
		nm_endWalk()
	} finally nm_TimeTracking.End("Gather")

	; set gather ended status
	gatherDuration := DurationFromSeconds(nm_TimeTracking.Elapsed("Gather"), "mm:ss")
	nm_setStatus("Gathering", "Ended`nTime " gatherDuration " - " (interruptReason ? (InStr(interruptReason, "Backpack exceeds") ? "Bag Limit" : interruptReason) : "Time Limit") " - Return: " FieldReturnType)


	nm_setShiftLock(0)
	if(bypass = 0){
		;rotate back
		if (FieldRotateDirection != "None") {
			direction:=(FieldRotateDirection = "left") ? "right" : "left"
			sendinput "{" Rot%direction% " " FieldRotateTimes "}"
		}
		;close quest log if necessary
		nm_OpenMenu()
		;check any planter progress
		nm_PlanterTimeUpdate(FieldName)
		;whirligig
		if (WhirligigKey!="None" && (nowUnix()-LastWhirligig)>180
		&& (!PFieldBoosted || (PFieldBoosted && GatherFieldBoosted))){
			WhirligigReturn()
		} else if(FieldReturnType="walk") { ;walk back
			nm_walkFrom(FieldName)
			DisconnectCheck()
			;Honey Wreath
			if BeesmasActive && ((interruptReason = "") || InStr(interruptReason, "Backpack exceeds"))
				nm_Wreath()
			nm_findHiveSlot()
		} ;reset back otherwise
	}
	nm_currentFieldDown()
	utc_min := FormatTime(A_NowUTC, "m")
	if(CurrentField="mountain top" && (utc_min>=0 && utc_min<15)) ;mondo dangerzone! skip over this field if possible
		nm_currentFieldDown()

	WhirligigReturn(){
		pBMScreen := Gdip_BitmapFromScreen(WindowX+WindowWidth*0.5-260 "|" WindowY+WindowHeight-101 "|" 75*7 "|" 66) ;hotbar
		if (Gdip_ImageSearch(pBMScreen,bitmaps["whirligigslot"], , , , , , 10, ,3) = 1) {
			Gdip_DisposeImage(pBMScreen)
			Send "{" WhirligigKey "}"
			sleep(2000) ; make sure the player is on the ground

			Send "{ " RotDown " 10}{ " RotUp " 7}{" ZoomIn " 10}"

			if !nm_SetHiveCameraDirection(1)
				nm_setStatus("Warning", "Unable to confirm hive!")
			
			LastWhirligig:=nowUnix()
			IniWrite LastWhirligig, "settings\nm_config.ini", "Boost", "LastWhirligig"
			nm_convert() ;convert all pollen, then reset if needed.
		} else {
			nm_setStatus("Warning", "No Whirligigs")
			Gdip_DisposeImage(pBMScreen)
		}
	}
}
nm_gather(pattern, index, patternsize:="M", reps:=1, facingcorner:=0){
	if !patterns.Has(pattern) {
		global FieldPattern
		nm_setStatus("Error", "Pattern '" pattern "' does not exist!`nChanged back to '" (FieldPattern := pattern := StandardFieldDefault[FieldName]["pattern"]) "'")
		IniWrite FieldDefault[FieldName]["pattern"] := pattern, "settings\field_config.ini", FieldName, "pattern"
	}

	size := (patternsize="XS") ? 0.25
		: (patternsize="S") ? 0.5
		: (patternsize="L") ? 1.5
		: (patternsize="XL") ? 2
		: 1 ; medium (default)

	DetectHiddenWindows 1
	if ((index = 1) || !nm_InlineScripts.Window("walk"))
		nm_createWalk(patterns[pattern], "pattern",
			(
			'
			size:=' size '
			reps:=' reps '
			facingcorner:=' facingcorner '

			FieldName:="' FieldName '"
			FieldPattern:="' FieldPattern '"
			FieldPatternSize:="' FieldPatternSize '"
			FieldPatternReps:=' FieldPatternReps '
			FieldPatternShift:=' FieldPatternShift '
			FieldPatternInvertFB:=' FieldPatternInvertFB '
			FieldPatternInvertLR:=' FieldPatternInvertLR '
			FieldUntilMins:=' FieldUntilMins '
			FieldUntilPack:=' FieldUntilPack '
			FieldReturnType:="' FieldReturnType '"
			FieldSprinklerLoc:="' FieldSprinklerLoc '"
			FieldSprinklerDist:=' FieldSprinklerDist '
			FieldRotateDirection:="' FieldRotateDirection '"
			FieldRotateTimes:=' FieldRotateTimes '
			FieldDriftCheck:=' FieldDriftCheck '
			nm_CameraRotation(Dir, count) {
				Static LR := 0, UD := 0, init := OnExit((*) => send("{" Rot%(LR > 0 ? "Left" : "Right")% " " Mod(Abs(LR), 8) "}{" Rot%(UD > 0 ? "Up" : "Down")% " " Abs(UD) "}"), -1)
				send "{" Rot%Dir% " " count "}"
				Switch Dir,0 {
					Case "Left": LR -= count
					Case "Right": LR += count
					Case "Up": UD -= count
					Case "Down": UD += count
				}
			}
			'
			)
		) ; create / replace cycled walk script for this gather session
	else
		Send "{F13}" ; start new cycle
	DetectHiddenWindows 0

	if (KeyWait("F14", "D T5 L") = 0) ; wait for pattern start
		nm_endWalk()
}
nm_KeyVars() {
	return
	(
	'
	FwdKey:="' FwdKey '"
	LeftKey:="' LeftKey '"
	BackKey:="' BackKey '"
	RightKey:="' RightKey '"
	RotLeft:="' RotLeft '"
	RotRight:="' RotRight '"
	RotUp:="' RotUp '"
	RotDown:="' RotDown '"
	ZoomIn:="' ZoomIn '"
	ZoomOut:="' ZoomOut '"
	SC_E:="' SC_E '"
	SC_R:="' SC_R '"
	SC_L:="' SC_L '"
	SC_Esc:="' SC_Esc '"
	SC_Enter:="' SC_Enter '"
	SC_LShift:="' SC_LShift '"
	SC_Space:="' SC_Space '"
	SC_1:="' SC_1 '"
	TCFBKey:="' TCFBKey '"
	AFCFBKey:="' AFCFBKey '"
	TCLRKey:="' TCLRKey '"
	AFCLRKey:="' AFCLRKey '"
	'
	)
}
nm_Walk(tiles, MoveKey1, MoveKey2:=0){ ; string form of the function which holds MoveKey1 (and optionally MoveKey2) down for 'tiles' tiles, not to be confused with the pure form in nm_createWalk below
	return
	(
	'Send "{' MoveKey1 ' down}' (MoveKey2 ? '{' MoveKey2 ' down}"' : '"') '
	Walk(' tiles ')
	Send "{' MoveKey1 ' up}' (MoveKey2 ? '{' MoveKey2 ' up}"' : '"')
	)
}
nm_createWalk(movement, name:="", vars:="") ; this function generates the 'walk' code and runs it for a given 'movement' (AHK code string), using movespeed correction if 'NewWalk' is enabled and legacy movement otherwise
{
	; F13 is used by 'natro_macro.ahk' to tell 'walk' to complete a cycle
	; F14 is held down by 'walk' to indicate that the cycle is in progress, then released when the cycle is finished
	; F16 can be used by any script to pause / unpause the walk script, when unpaused it will resume from where it left off

	DetectHiddenWindows 1 ; allow communication with walk script

	if nm_InlineScripts.Window("walk")
		nm_endWalk()

	script := nm_BuildWalkScript(movement, vars, NewWalk, MoveSpeedNum, GetYOffset(), nm_KeyVars(),
		LeftKey, RightKey, FwdKey, BackKey, SC_Space, SC_E)

	exec := nm_InlineScripts.Start("walk", script, exe_path64)

	if exec.ProcessID && WinWait("ahk_class AutoHotkey ahk_pid " exec.ProcessID, , 2) {
		DetectHiddenWindows 0
		currentWalk.pid := exec.ProcessID, currentWalk.name := name
		return 1
	}
	else {
		nm_InlineScripts.Close("walk")
		DetectHiddenWindows 0
		return 0
	}
}
nm_endWalk() ; stop the owned worker and release movement even after forced termination
{
	global currentWalk, LeftKey, RightKey, FwdKey, BackKey, SC_Space, SC_E
	nm_InlineScripts.Close("walk")
	currentWalk.pid := currentWalk.name := ""
	SendInput "{" LeftKey " up}{" RightKey " up}{" FwdKey " up}{" BackKey " up}{" SC_Space " up}{F14 up}{" SC_E " up}"
}
nm_loot(length, reps, direction, tokenlink:=0){ ; length in tiles instead of ms (old)
	global FwdKey, LeftKey, BackKey, RightKey, KeyDelay, bitmaps

	movement :=
	(
	'
	loop ' reps ' {
		' nm_Walk(length, FwdKey) '
		' nm_Walk(1.5, %direction%Key) '
		' nm_Walk(length, BackKey) '
		' nm_Walk(1.5, %direction%Key) '
	}
	'
	)

	nm_createWalk(movement)
	KeyWait "F14", "D T5 L"

	if (tokenlink = 0) ; wait for pattern finish
		KeyWait "F14", "T" length*reps " L"
	else ; wait for token link or pattern finish
	{
		GetRobloxClientPos()
		Sleep 1000 ; primary delay, only accept token links after this
		DllCall("GetSystemTimeAsFileTime","int64p",&s:=0)
		n := s, f := s+length*reps*10000000 ; timeout at length * reps
		while ((n < f) && GetKeyState("F14"))
		{
			pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth-400 "|" windowY+windowHeight-400 "|400|400")
			if (Gdip_ImageSearch(pBMScreen, bitmaps["tokenlink"], , , , , , 50, , 7) = 1)
			{
				Gdip_DisposeImage(pBMScreen)
				break
			}
			Gdip_DisposeImage(pBMScreen)
			Sleep 50
			DllCall("GetSystemTimeAsFileTime","int64p",&n)
		}
	}
	nm_endWalk()
}
#Include "%A_ScriptDir%\..\lib\Conversion.ahk"

nm_setSprinkler(field, loc, dist){
	global FwdKey, LeftKey, BackKey, RightKey, SC_1, SC_Space, KeyDelay, SprinklerType, MoveSpeedNum

	if (SprinklerType = "None")
		return

	;field dimensions
	switch field, 0
	{
		case "sunflower":
		flen:=1250*dist/10
		fwid:=2000*dist/10

		case "dandelion":
		flen:=2500*dist/10
		fwid:=1000*dist/10

		case "mushroom":
		flen:=1250*dist/10
		fwid:=1750*dist/10

		case "blue flower":
		flen:=2750*dist/10
		fwid:=750*dist/10

		case "clover":
		flen:=2000*dist/10
		fwid:=1500*dist/10

		case "spider":
		flen:=2000*dist/10
		fwid:=2000*dist/10

		case "strawberry":
		flen:=1500*dist/10
		fwid:=2000*dist/10

		case "bamboo":
		flen:=3000*dist/10
		fwid:=1250*dist/10

		case "pineapple":
		flen:=1750*dist/10
		fwid:=3000*dist/10

		case "stump":
		flen:=1500*dist/10
		fwid:=1500*dist/10

		case "cactus","pumpkin":
		flen:=1500*dist/10
		fwid:=2500*dist/10

		case "pine tree":
		flen:=2500*dist/10
		fwid:=1750*dist/10

		case "rose":
		flen:=2500*dist/10
		fwid:=1500*dist/10

		case "mountain top":
		flen:=2250*dist/10
		fwid:=1500*dist/10

		case "pepper","coconut":
		flen:=1500*dist/10
		fwid:=2250*dist/10
	}

	MoveSpeedFactor:=round(18/MoveSpeedNum, 2)

	;move to start position
	if(InStr(loc, "Upper")){
		nm_Move(flen*MoveSpeedFactor, FwdKey)
	} else if(InStr(loc, "Lower")){
		nm_Move(flen*MoveSpeedFactor, BackKey)
	}
	if(InStr(loc, "Left")){
		nm_Move(fwid*MoveSpeedFactor, LeftKey)
	} else if(InStr(loc, "Right")){
		nm_Move(fwid*MoveSpeedFactor, RightKey)
	}
	if(loc="center")
		Sleep 1000
	;set sprinkler(s)
	if(SprinklerType="Supreme" || SprinklerType="Basic") {
		Send "{" SC_1 "}"
		return
	} else {
		nm_JumpSprinkler(1)
	}
	if(SprinklerType="Silver" || SprinklerType="Golden" || SprinklerType="Diamond") {
		if(InStr(loc, "Upper")){
			nm_Move(1000*MoveSpeedFactor, BackKey)
		} else {
			nm_Move(1000*MoveSpeedFactor, FwdKey)
		}
		DllCall("Sleep","UInt",500)
		nm_JumpSprinkler()
	}
	if(SprinklerType="Silver") {
		if(InStr(loc, "Upper")){
			nm_Move(1000*MoveSpeedFactor, FwdKey)
		} else {
			nm_Move(1000*MoveSpeedFactor, BackKey)
		}
	}
	if(SprinklerType="Golden" || SprinklerType="Diamond") {
		if(InStr(loc, "Left")){
			nm_Move(1000*MoveSpeedFactor, RightKey)
		} else {
			nm_Move(1000*MoveSpeedFactor, LeftKey)
		}
		DllCall("Sleep","UInt",500)
		nm_JumpSprinkler()
	}
	if(SprinklerType="Golden") {
		if(InStr(loc, "Upper")){
			if(InStr(loc, "Left")){
				nm_Move(1400*MoveSpeedFactor, FwdKey, LeftKey)
			} else {
				nm_Move(1400*MoveSpeedFactor, FwdKey, RightKey)
			}
		} else {
			if(InStr(loc, "Left")){
				nm_Move(1400*MoveSpeedFactor, BackKey, LeftKey)
			} else {
				nm_Move(1400*MoveSpeedFactor, BackKey, RightKey)
			}
		}
	}
	if(SprinklerType="Diamond") {
		if(InStr(loc, "Upper")){
			nm_Move(1000*MoveSpeedFactor, FwdKey)
		} else {
			nm_Move(1000*MoveSpeedFactor, BackKey)
		}
		DllCall("Sleep","UInt",500)
		nm_JumpSprinkler()
		if(InStr(loc, "Left")){
			nm_Move(1000*MoveSpeedFactor, LeftKey)
		} else {
			nm_Move(1000*MoveSpeedFactor, RightKey)
		}
	}
}
nm_JumpSprinkler(resetDelay := 0){
	static JumpDelay := 200
	if resetDelay
		JumpDelay := 200

	GetRobloxClientPos()
	success := 0
	Loop 3 {
		Send "{" SC_Space " down}"
		Sleep JumpDelay
		Send "{" SC_1 "}{" SC_Space " up}"
		Sleep 500
		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth-356 "|" windowY+windowHeight-326 "|340|300")
		if (Gdip_ImageSearch(pBMScreen, bitmaps["standing"], , , , , , 20) = 1) { ; jumped too high
			JumpDelay := Max(JumpDelay - 50, 100)
		} else if (Gdip_ImageSearch(pBMScreen, bitmaps["thisclose"], , , , , , 20) = 1) { ; not high enough
			JumpDelay := Min(JumpDelay + 50, 500)
		} else {
			success := 1
		}
		Gdip_DisposeImage(pBMScreen)
		Sleep 600 - JumpDelay
		if (success = 1)
			break
	}

	return success
}
nm_fieldDriftCompensation(){
	global FwdKey, LeftKey, BackKey, RightKey, DisableToolUse

	GetRobloxClientPos()
	winUp := Floor(windowHeight / 2.14), winDown := Floor(windowHeight / 1.88)
	winLeft := Floor(windowWidth / 2.14), winRight := Floor(windowWidth / 1.88)

	hmove := vmove := 0
	if ((nm_LocateSprinkler(&x, &y) = 1) && !(x >= winLeft && x <= winRight && y >= winUp && y <= winDown)) {
		if (!DisableToolUse)
			click "down"
		if ((x < winleft) && (hmove := LeftKey))
			sendinput "{" LeftKey " down}"
		else if ((x > winRight) && (hmove := RightKey))
			sendinput "{" RightKey " down}"
		if ((y < winUp) && (vmove := FwdKey))
			sendinput "{" FwdKey " down}"
		else if ((y > winDown) && (vmove := BackKey))
			sendinput "{" BackKey " down}"
		while (hmove || vmove) {
			if (((hmove = LeftKey) && (x >= winLeft)) || ((hmove = RightKey) && (x <= winRight))) {
				sendinput "{" hmove " up}"
				hmove := ""
			}
			if (((vmove = FwdKey) && (y >= winUp)) || ((vmove = BackKey) && (y <= winDown))) {
				sendinput "{" vmove " up}"
				vmove := ""
			}
			Sleep 20
			if ((A_Index >= 300)) {
				sendinput "{" LeftKey " up}{" RightKey " up}{" FwdKey " up}{" BackKey " up}"
				break
			}
			if (nm_LocateSprinkler(&x, &y) = 0) {
				sendinput "{" LeftKey " up}{" RightKey " up}{" FwdKey " up}{" BackKey " up}"
				Loop 25 {
					Sleep 20
					if (nm_LocateSprinkler(&x, &y) = 1) {
						sendinput (hmove ? "{" hmove " down} " : "") (vmove ? "{" vmove " down} " : "")
						continue 2
					}
				}
				break
			}
		}
		click "up"
	}
}
nm_LocateSprinkler(&X:="", &Y:=""){ ; find client coordinates of approximately closest saturator to player/center
	global bitmaps, sprinklerImages
	n := sprinklerImages.Length

	hwnd := GetRobloxHWND()
	offsetY := GetYOffset(hwnd)
	GetRobloxClientPos(hwnd)
	pBMScreen := Gdip_BitmapFromScreen(windowX "|" (windowY + offsetY + 75) "|" (hWidth := windowWidth) "|" (hHeight := windowHeight - offsetY - 75) "|")

	Gdip_LockBits(pBMScreen, 0, 0, hWidth, hHeight, &hStride, &hScan, &hBitmapData, 1)
	hWidth := NumGet(hBitmapData, 0, "UInt"), hHeight := NumGet(hBitmapData, 4, "UInt")

	local n1width, n1height, n1Stride, n1Scan, n1BitmapData
		, n1width, n1height, n2Stride, n2Scan, n2BitmapData
		, n1width, n1height, n3Stride, n3Scan, n3BitmapData
	for i,k in sprinklerImages
	{
		Gdip_GetImageDimensions(bitmaps[k], &n%i%Width, &n%i%Height)
		Gdip_LockBits(bitmaps[k], 0, 0, n%i%Width, n%i%Height, &n%i%Stride, &n%i%Scan, &n%i%BitmapData)
		n%i%Width := NumGet(n%i%BitmapData, 0, "UInt"), n%i%Height := NumGet(n%i%BitmapData, 4, "UInt")
	}

	d := 11 ; divisions (odd positive integer such that w,h > n%i%Width,n%i%Height for all i<=n)
	m := d//2 ; midpoint of d (along with m + 1), used frequently in calculations
	v := 50 ; variation
	w := hWidth//d, h := hHeight//d

	; to search from centre (approximately), we will split the rectangle like a pinwheel configuration and search outwards (notice SearchDirection)
	Loop m + 1
	{
		if (A_Index = 1)
		{
			; initial rectangle (center)
			d1 := m, d2 := m + 1
			OuterX1 := d1 * w, OuterX2 := d2 * w
			OuterY1 := d1 * h, OuterY2 := d2 * h
			Loop n
				if (Gdip_MultiLockedBitsSearch(hStride, hScan, hWidth, hHeight, n%A_Index%Stride, n%A_Index%Scan, n%A_Index%Width, n%A_Index%Height, &pos, OuterX1, OuterY1, OuterX2-n%A_Index%Width+1, OuterY2-n%A_Index%Height+1, v, 1, 1) > 0)
					break 2
		}
		else
		{
			; upper-right
			dx1 := m + 2 - A_Index, dx2 := m + A_Index
			OuterX1 := dx1 * w, OuterX2 := dx2 * w
			dy1 := m + 1 - A_Index, dy2 := m + 2 - A_Index
			OuterY1 := dy1 * h, OuterY2 := dy2 * h
			Loop n
				if (Gdip_MultiLockedBitsSearch(hStride, hScan, hWidth, hHeight, n%A_Index%Stride, n%A_Index%Scan, n%A_Index%Width, n%A_Index%Height, &pos, OuterX1, OuterY1, OuterX2-n%A_Index%Width+1, OuterY2-n%A_Index%Height+1, v, 2, 1) > 0)
					break 2

			; lower-right
			dx1 := m - 1 + A_Index, dx2 := m + A_Index
			OuterX1 := dx1 * w, OuterX2 := dx2 * w
			dy1 := m + 2 - A_Index, dy2 := m + A_Index
			OuterY1 := dy1 * h, OuterY2 := dy2 * h
			Loop n
				if (Gdip_MultiLockedBitsSearch(hStride, hScan, hWidth, hHeight, n%A_Index%Stride, n%A_Index%Scan, n%A_Index%Width, n%A_Index%Height, &pos, OuterX1, OuterY1, OuterX2-n%A_Index%Width+1, OuterY2-n%A_Index%Height+1, v, 5, 1) > 0)
					break 2

			; lower-left
			dx1 := m + 1 - A_Index, dx2 := m - 1 + A_Index
			OuterX1 := dx1 * w, OuterX2 := dx2 * w
			dy1 := m - 1 + A_Index, dy2 := m + A_Index
			OuterY1 := dy1 * h, OuterY2 := dy2 * h
			Loop n
				if (Gdip_MultiLockedBitsSearch(hStride, hScan, hWidth, hHeight, n%A_Index%Stride, n%A_Index%Scan, n%A_Index%Width, n%A_Index%Height, &pos, OuterX1, OuterY1, OuterX2-n%A_Index%Width+1, OuterY2-n%A_Index%Height+1, v, 4, 1) > 0)
					break 2

			; upper-left
			dx1 := m + 1 - A_Index, dx2 := m + 2 - A_Index
			OuterX1 := dx1 * w, OuterX2 := dx2 * w
			dy1 := m + 1 - A_Index, dy2 := m - 1 + A_Index
			OuterY1 := dy1 * h, OuterY2 := dy2 * h
			Loop n
				if (Gdip_MultiLockedBitsSearch(hStride, hScan, hWidth, hHeight, n%A_Index%Stride, n%A_Index%Scan, n%A_Index%Width, n%A_Index%Height, &pos, OuterX1, OuterY1, OuterX2-n%A_Index%Width+1, OuterY2-n%A_Index%Height+1, v, 7, 1) > 0)
					break 2
		}
	}

	Gdip_UnlockBits(pBMScreen,&hBitmapData)
	for i,k in sprinklerImages
		Gdip_UnlockBits(bitmaps[k],&n%i%BitmapData)
	Gdip_DisposeImage(pBMScreen)

	if pos
	{
		x := SubStr(pos, 1, InStr(pos, ",") - 1), y := 75 + SubStr(pos, InStr(pos, ",") + 1)
		return 1
	}
	else
	{
		x := "", y := ""
		return 0
	}
}
;move function //todo: deprecated! replace throughout script with nm_Walk
nm_Move(MoveTime, MoveKey1, MoveKey2:="None"){
	PrevKeyDelay:=A_KeyDelay
	SetKeyDelay 5
	Send "{" MoveKey1 " down}"
	if(MoveKey2!="None")
		Send "{" MoveKey2 " down}"
	DllCall("Sleep","UInt",MoveTime)
	Send "{" MoveKey1 " up}"
	if(MoveKey2!="None")
		Send "{" MoveKey2 " up}"
	SetKeyDelay PrevKeyDelay
}
CloseRoblox(recovery := 0)
{
	activity := nm_RecoveryActivity()
	try {
		closed := nm_OwnedProcessJob.Execute(Map("kind", "close"), recovery)
		; Preserve the existing post-close delay against duplicate-session errors.
		if closed {
			if recovery
				recovery.Wait(5000)
			else
				Sleep 5000
		}
	} finally activity.Close()
}
DisconnectCheck(testCheck := 0)
{
	global LastClock, LastGingerbread, HiveSlot, PrivServer, TotalDisconnects, SessionDisconnects, ReconnectMethod, PublicFallback, resetTime
		, PlanterName1, PlanterName2, PlanterName3, PlanterHarvestTime1, PlanterHarvestTime2, PlanterHarvestTime3
		, MacroState, ReconnectDelay
		, FallbackServer1, FallbackServer2, FallbackServer3, beesmasActive
	static ServerLabels := Map(0,"Public Server", 1,"Private Server", 2,"Fallback Server 1", 3,"Fallback Server 2", 4,"Fallback Server 3")

	; Unknown imagery is not a disconnect receipt. Missing processes, the
	; crash window and the existing disconnect template trigger recovery.
	observation := nm_ReconnectObservation.Read(true)
	if observation != "missing" && observation != "disconnected" && !WinExist("Roblox Crash")
		return 0

	activity := nm_RecoveryActivity()
	try {
	; Reconnection is runtime, but is not gathering or conversion.
	nm_TimeTracking.InterruptActions()
	; end any residual movement and set reconnect start time
	Click "Up"
	nm_endWalk()
	ReconnectStartedTick := DllCall("GetTickCount64", "UInt64")
	nm_updateAction("Reconnect")

	; wait for any requested delay time (e.g. from remote control or daily reconnect)
	if (ReconnectDelay) {
		nm_setStatus("Waiting", ReconnectDelay " seconds before Reconnect")
		Sleep 1000*ReconnectDelay
		ReconnectDelay := 0
	}
	else if (MacroState = 2) {
		nm_IncrementStat("Disconnects", 1)
		nm_setStatus("Disconnected", "Reconnecting")
	}

	; Parse before adding candidates: malformed entries must never be selected.
	PossibleServers := Map(0, Map("type", "None", "code", ""))
	privateSlots := [], hasPrivateLink := false
	for index, server in ["PrivServer", "FallbackServer1", "FallbackServer2", "FallbackServer3"] {
		if !Trim(%server%)
			continue
		hasPrivateLink := true
		if (candidate := nm_ParsePrivateServer(%server%)) {
			PossibleServers[index] := candidate
			privateSlots.Push(index)
		} else
			nm_setStatus("Error", ServerLabels[index] " link is invalid")
	}
	; An empty configuration means public-server use, not a failed private join.
	allowPublic := PublicFallback || !hasPrivateLink
	if (!privateSlots.Length && !allowPublic)
		throw Error("No valid private server is configured and public fallback is disabled.")

	; Five actual launches per eligible server, one circuit, with a 30-minute
	; cooperative deadline across launch, loading, retry and hive-claim work.
	recovery := nm_ReconnectSession(privateSlots, allowPublic)
	try Loop {
		server := recovery.Next(), i := recovery.Attempts
		Launch() {
			switch (ReconnectMethod = "Browser") ? 0 : Mod(i, 5) {
				case 1,2:
				;Close Roblox
				CloseRoblox(recovery)
				;Run Server Deeplink
				nm_setStatus("Attempting", ServerLabels[server])
				RunDeeplink(PossibleServers[server]["type"], PossibleServers[server]["code"])

				case 3,4:
				;Run Server Deeplink (without closing)
				nm_setStatus("Attempting", ServerLabels[server])
				RunDeeplink(PossibleServers[server]["type"], PossibleServers[server]["code"])

				default:
				if server {
					;Close Roblox
					CloseRoblox(recovery)
					;Run Server Link (legacy method w/ browser)
					nm_setStatus("Attempting", ServerLabels[server] " (Browser)")
					RunBrowser(PossibleServers[server]["type"], PossibleServers[server]["code"])
				} else {
					;Close Roblox
					(i = 1) && CloseRoblox(recovery)
					;Run Server Link (spam deeplink method)
					RunDeeplink()
				}
			}
		}
		success := recovery.Join(Launch, ObjBindMethod(nm_ReconnectObservation, "Read"))
		if !success {
			nm_setStatus("Retrying", "Reconnect " i "/" recovery.Maximum ": " recovery.LastFailure)
			recovery.Wait(2000)
			continue
		}
		; A failed claim must not publish success or repeatedly extend timers by
		; the entire recovery duration. Account once, after an accepted claim.
		recovery.Stage := "hive claim"
		if !testCheck && nm_claimHiveSlot(recovery) != 1 {
			recovery.LastFailure := "hive claim failed"
			recovery.Wait(2000)
			continue
		}
		recovery.Check()

		;Successful Reconnect
		if (success = 1)
		{
			; Browser tabs belong to the user; never close an untracked tab/window.
			ActivateRoblox()
			GetRobloxClientPos()
			MouseMove windowX + windowWidth//2, windowY + windowHeight//2
			duration := DurationFromSeconds(ReconnectDuration := Max(0, (DllCall("GetTickCount64", "UInt64") - ReconnectStartedTick) // 1000), "mm:ss")
			nm_setStatus("Completed", "Reconnect`nTime: " duration " - Attempts: " i)
			Sleep 500

			LastClock:=nowUnix()
			IniWrite LastClock, "settings\nm_config.ini", "Collect", "LastClock"
			if (beesmasActive)
			{
				LastGingerbread += ReconnectDuration
				IniWrite LastGingerbread, "settings\nm_config.ini", "Collect", "LastGingerbread"
			}
			Loop 3 {
				PlanterHarvestTime%A_Index% += PlanterName%A_Index% ? ReconnectDuration : 0
				IniWrite PlanterHarvestTime%A_Index%, "settings\nm_config.ini", "Planters", "PlanterHarvestTime" A_Index
			}

			if (server > 1) ; swap PrivServer and FallbackServer - original PrivServer probably has an issue
			{
				n := server - 1
				temp := PrivServer, PrivServer := FallbackServer%n%, FallbackServer%n% := temp
				MainGui["PrivServer"].Value := PrivServer
				MainGui["FallbackServer" n].Value := FallbackServer%n%
				IniWrite PrivServer, "settings\nm_config.ini", "Settings", "PrivServer"
				IniWrite FallbackServer%n%, "settings\nm_config.ini", "Settings", "FallbackServer" n
				PostSubmacroMessage("Status", 0x5553, 10, 6)
			}
			PostSubmacroMessage("Status", 0x5552, 221, (server = 0))

			return 1
		}

		RunDeeplink(type := "", code := "") {
			nm_OwnedProcessJob.Execute(Map("kind", "deeplink", "type", type, "code", code), recovery)
		}
		RunBrowser(type, code) {
			nm_OwnedProcessJob.Execute(Map("kind", "browser", "type", type, "code", code), recovery)
		}

	} catch nm_ReconnectExhausted as err {
		nm_Failures.Write(err, "Reconnect exhausted; restart after checking Roblox and server settings")
		nm_setStatus("Error", err.Message "`nReconnect stopped; check Roblox/server settings before restarting.")
		nm_FailClosed(err)
	}
	} finally activity.Close()
}

nm_claimHiveSlot(recovery := 0){
	global KeyDelay, FwdKey, RightKey, LeftKey, BackKey, ZoomOut, HiveSlot, HiveConfirmed, SC_E, SC_Esc, SC_R, SC_Enter, bitmaps
	GetBitmap() {
		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY "|400|125")
		try {
			loop 20 {
				CheckRecovery()
				for , bitmap in bitmaps["FriendJoin"] {
					if (Gdip_ImageSearch(pBMScreen, bitmap, , , , , , 6) = 1) {
						Gdip_DisposeImage(pBMScreen), pBMScreen := 0
						MouseMove windowX+windowWidth//2-3, windowY+24
						Click
						MouseMove windowX+350, windowY+offsetY+100
						WaitRecovery(500)
						pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY "|400|125")
					}
				}
			}
			return pBMScreen
		} catch as err {
			if pBMScreen
				Gdip_DisposeImage(pBMScreen)
			throw err
		}
	}

	CheckRecovery() {
		if recovery
			recovery.Check()
	}
	WaitRecovery(ms) {
		if recovery
			recovery.Wait(ms)
		else
			Sleep ms
	}
	WalkWait(seconds, down := false) {
		CheckRecovery()
		if recovery
			seconds := Min(seconds, Max(0.001, (recovery.Deadline - recovery.Clock.Call()) / 1000))
		KeyWait "F14", (down ? "D " : "") "T" seconds " L"
		CheckRecovery()
	}
	try {
		DetectHiveslots := 1
		Loop 5
		{
			CheckRecovery()
			ActivateRoblox()
			hwnd := GetRobloxHWND()
			offsetY := GetYOffset(hwnd)
			GetRobloxClientPos(hwnd)
			MouseMove windowX+350, windowY+offsetY+100

			;reset
			if (A_Index > 1)
			{
				resetTime:=nowUnix()
				PostSubmacroMessage("background", 0x5554, 1, resetTime)
				ActivateRoblox()
				PrevKeyDelay := A_KeyDelay
				SetKeyDelay 250+KeyDelay
				send "{" SC_Esc "}{" SC_R "}{" SC_Enter "}"
				SetKeyDelay PrevKeyDelay
				n := 0
				while ((n < 2) && (A_Index <= 80))
				{
					WaitRecovery(100)
					GetRobloxClientPos(hwnd)
					pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY "|" windowWidth "|50")
					n += (Gdip_ImageSearch(pBMScreen, bitmaps["emptyhealth"], , , , , , 10) = (n = 0))
					Gdip_DisposeImage(pBMScreen)
				}
				WaitRecovery(1000)
			}

			; detect unclaimed hive slots.
			if DetectHiveslots {
				preferred := (ClaimMethod = "Detect") ? 0 : HiveSlot
				if ClaimMethod = "Detect" {
					slots := nm_detectHiveSlots()
					for i, slot in slots {
						if (HiveSlot = slot.HiveSlot && slot.Claimed = "Empty") {
							preferred := HiveSlot
							break
						}
					}

					if (!preferred) {
						for i, slot in slots {
							if (slot.Claimed = "Empty") {
								preferred := slot.HiveSlot
								break
							}
						}
					}
				}
				if (preferred) {
					movement := nm_spawnMoveTo(slotMove[preferred])
					CheckRecovery()
					nm_createWalk(movement)
					WalkWait(5, true)
					WalkWait(20)
					nm_endWalk()
					WaitRecovery(500)
					pBMScreen := GetBitmap()
					if (Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) = 1) {
						Gdip_DisposeImage(pBMScreen)
						Send "{" SC_E " down}"
						WaitRecovery(100)
						Send "{" SC_E " up}"
						HiveConfirmed := 1
						HiveSlot := preferred
						MainGui["HiveSlot"].Text := HiveSlot
						IniWrite HiveSlot, "settings\nm_config.ini", "Settings", "HiveSlot"
						nm_setStatus("Claimed", "Hive Slot " HiveSlot)
						MouseMove windowX+350, windowY+offsetY+100
						return 1
					}
					Gdip_DisposeImage(pBMScreen)
				}
				DetectHiveslots := 0
				continue
			}

			; old system

			;go to slot 1
			WaitRecovery(500)
			GetRobloxClientPos(hwnd)
			MouseMove windowX+350, windowY+offsetY+100
			send "{" ZoomOut " 8}"

			movement :=
			(
			'Send "{' RightKey ' down}"
			Walk(4)
			Send "{' FwdKey ' down}"
			Walk(20)
			Send "{' RightKey ' up}{' FwdKey ' up}"'
			)
			CheckRecovery()
			nm_createWalk(movement)
			WalkWait(5, true)
			WalkWait(20)
			nm_endWalk()

			;check slots 1 to old HiveSlot
			slots := Map()
			movement := nm_Walk(9.2, LeftKey)
			Loop HiveSlot
			{
				if (A_Index > 1)
				{
					CheckRecovery()
					nm_createWalk(movement)
					WalkWait(5, true)
					WalkWait(20)
					nm_endWalk()
				}

				WaitRecovery(500)
				pBMScreen := GetBitmap()
				if (Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) = 1)
					slots[A_Index] := 1
				Gdip_DisposeImage(pBMScreen)
			}

			if (slots.Has(HiveSlot) && (slots[HiveSlot] = 1))
				break
			else
			{
				if ((slot := ObjMinIndex(slots)) > 0)
				{
					movement := nm_Walk((HiveSlot - slot) * 9.2, RightKey)
					CheckRecovery()
					nm_createWalk(movement)
					WalkWait(5, true)
					WalkWait(20)
					nm_endWalk()

					WaitRecovery(500)
					pBMScreen := GetBitmap()
					if (Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) = 1) {
						Gdip_DisposeImage(pBMScreen)
						HiveSlot := slot
						break
					}
					Gdip_DisposeImage(pBMScreen)
				}
				else {
					Loop (6 - HiveSlot)
					{
						CheckRecovery()
						nm_createWalk(movement)
						WalkWait(5, true)
						WalkWait(20)
						nm_endWalk()

						WaitRecovery(500)
						pBMScreen := GetBitmap()
						if (Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) = 1) {
							Gdip_DisposeImage(pBMScreen)
							HiveSlot += A_Index
							break 2
						}
						Gdip_DisposeImage(pBMScreen)
					}
				}
			}

			nm_setStatus("Failed", "Claim Hive Slot" ((A_Index > 1) ? (" (Attempt " A_Index ")") : ""))
			if (A_Index = 5)
				return 0
		}

		SendInput "{" SC_E " down}"
		WaitRecovery(100)
		SendInput "{" SC_E " up}"
		HiveConfirmed := 1
		;update hive slot
		MainGui["HiveSlot"].Text := HiveSlot
		IniWrite HiveSlot, "settings\nm_config.ini", "Settings", "HiveSlot"
		nm_setStatus("Claimed", "Hive Slot " HiveSlot)
		MouseMove windowX+350, windowY+offsetY+100

		return 1
	} finally {
		try Send "{" SC_E " up}"
		try nm_endWalk()
	}
}
nm_activeHoney(){
	global HiveBees, GameFrozenCounter
	if (hwnd := GetRobloxHWND()) {
		GetRobloxClientPos(hwnd)
		offsetY := GetYOffset(hwnd)
		x1 := windowX + windowWidth//2 - 90
		y1 := windowY + offsetY
		try
			result := PixelSearch(&bx2, &by2, x1, y1, x1+70, y1+34, 0xFFE280, 20)
		catch
			result := 0
		if (result = 1){
			GameFrozenCounter:=0
			return 1
		} else {
			if(HiveBees<25){
				x1 := windowX + windowWidth//2 + 210
				y1 := windowY + offsetY
				try
					result := PixelSearch(&bx2, &by2, x1, y1, x1+70, y1+34, 0xFFFFFF, 20)
				catch
					result := 0
				return result
			} else {
				return 0
			}
		}
	} else {
		return 0
	}
}
nm_searchForE(){
	global FwdKey, LeftKey, BackKey, RightKey, RotLeft, RotRight, bitmaps

	movement :=
	(
	'
	Loop 8
	{
		i := A_Index
		Loop 2
		{
			Send "{' FwdKey ' down}"
			Walk(3*i)
			Send "{' FwdKey ' up}{' RotRight ' 2}"
		}
	}
	'
	)
	nm_createWalk(movement)
	KeyWait "F14", "D T5 L"

	hwnd := GetRobloxHWND()
	offsetY := GetYOffset(hwnd)
	GetRobloxClientPos(hwnd)
	MouseMove windowX+350, windowY+offsetY+100
	success := 0
	DllCall("GetSystemTimeAsFileTime","int64p",&s:=0)
	n := s, f := s+90*10000000 ; 90 second timeout
	while (n < f && GetKeyState("F14"))
	{
		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY+36 "|200|120")
		if (Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , , , 2, , 6) = 1)
		{
			success := 1, Gdip_DisposeImage(pBMScreen)
			break
		}
		Gdip_DisposeImage(pBMScreen)
		DllCall("GetSystemTimeAsFileTime","int64p",&n)
	}
	nm_endWalk()

	if (success = 1) ; check that planter was not overrun, at the expense of a small delay
	{
		Loop 10
		{
			if (A_Index = 10)
			{
				success := 0
				break
			}
			Sleep 500
			pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY+36 "|200|120")
			if (Gdip_ImageSearch(pBMScreen, bitmaps["e_button"], , , , , , 2, , 6) = 1)
			{
				Gdip_DisposeImage(pBMScreen)
				break
			}
			else
			{
				movement := nm_Walk(1.5, BackKey)
				nm_createWalk(movement)
				KeyWait "F14", "D T5 L"
				KeyWait "F14", "T5 L"
				nm_endWalk()
			}
			Gdip_DisposeImage(pBMScreen)
		}
	}
	return success
}
nm_boostBypassCheck() => 0 ; always returns 0 for now: no field boost bypass implemented
nm_Night(){
	global CheckNight

	if CheckNight != 1
		return

	if !nm_confirmNight()
		return CheckNight := 0

	nm_NightMemoryMatch()
	nm_ViciousBee()
	CheckNight := 0
}

nm_confirmNight()
{
	isNight := 0
	nm_Reset(0, 0, 0)
	nm_setStatus("Confirming", "Night")
	ActivateRoblox()
	GetRobloxClientPos()

	Send "{" RotUp " 10}"

	loop 7
		Send("{" ZoomOut "}"), Sleep(25)

	pBMArea := Gdip_BitmapFromScreen(windowX+300 "|" windowY+windowHeight//2+50 "|" windowWidth-600 "|" windowHeight//2-50) ; searches bottom middle of the screen with offset

	for key, bitmap in bitmaps["confirm_night"] 
		if Gdip_ImageSearch(pBMArea, bitmap) = 1
			isNight := 1

	Gdip_DisposeImage(pBMArea)
	Send "{" RotDown " 4}"

	if isNight
		nm_SetStatus("Confirmed", "Night")
	else 
		nm_SetStatus("Aborting", "Not night")

	return isNight
}

nm_NightMemoryMatch(){
	; night (general) + no amulet + nightmm ready + night confirmed (last b/c reset)
	if (!nm_NightInterrupt() || nm_AmuletPrompt() || !(NightMemoryMatchCheck && (nowUnix()-LastNightMemoryMatch)>28800 && nm_CollectionRecovery.Ready("LastNightMemoryMatch")))
			return
	nm_MemoryMatch("Night")
}
nm_NightInterrupt() => CheckNight=1 && ((NightMemoryMatchCheck && (nowUnix()-LastNightMemoryMatch)>28800 && nm_CollectionRecovery.Ready("LastNightMemoryMatch")) || !(StingerCheck=0 || (StingerDailyBonusCheck=1 && (VBStart-VBLastKilled)<79200)))
nm_ViciousBee(){
	if nm_locateVB() = 0
		VBEnd({ result: VBResults.notfound, reason: "All fields checked" })
}
/**
 * Check each enabled field for vicious
 * @returns {x < 0} if not enabled
 * @returns {x = 0} if all fields checked
 * @returns {x = 1} if success
 */
nm_locateVB(){ 
	global VBfieldStart, VBStart := nowUnix(), fieldsChecked := 0, attackingVB := 0, VBInactiveHoney := 0
	; don't run if disabled or only daily bonus
	if (StingerCheck=0) || (StingerDailyBonusCheck=1 && (VBStart-VBLastKilled)<79200) {
		return -1 
	}

	VBData := [
		{ field: "Pepper", enabled: StingerPepperCheck
		, bees: 35
		, reps: 1
		, lrdist: 20
		, fbdist: 7
		, initRight: 10
		, initFwd: 7 },

		{ field: "MountainTop", enabled: StingerMountainTopCheck
		, bees: 25
		, reps: 2
		, lrdist: 17
		, fbdist: 5.5
		, initRight: 8.5
		, initFwd: 10.5 },

		{ field: "Rose", enabled: StingerRoseCheck
		, bees: 15
		, reps: 2
		, lrdist: 13
		, fbdist: 6
		, initRight: 6.5
		, initFwd: 12 },

		{ field: "Cactus", enabled: StingerCactusCheck
		, bees: 15
		, reps: 1
		, lrdist: 26
		, fbdist: 5.5
		, initRight: 13
		, initFwd: 3.7 },

		{ field: "Spider", enabled: StingerSpiderCheck
		, bees: 5
		, reps: 2
		, lrdist: 21
		, fbdist: 5.7
		, initRight: 10.5
		, initFwd: 9.5 },

		{ field: "Clover", enabled: StingerCloverCheck
		, bees: 0
		, reps: 2
		, lrdist: 22
		, fbdist: 5.7
		, initRight: 11
		, initFwd: 10 }
	]

	for data in VBData { ; if no fields enabled, return
		if data.enabled
			break
		if A_Index = VBData.Length
			return -2
	}

	
	nm_setStatus("Starting", "Vicious Bee Cycle")
	nm_updateAction("Stingers")

	for data in VBData
	{
		if !data.enabled || data.bees > HiveBees
			continue
		; This is built into the game
		if (nowUnix() - VBStart) > 300
			return VBEnd({result: VBResults.failed, reason: VBReasons.timeout})

		fieldsChecked++
		global VBfieldStart := nowUnix()
		
		fieldloop:
		while (A_Index < 4) || attackingVB ; keep going to field if attacking vb, max 3 loops otherwise
		{
			nm_Reset(0, 2000, 0)
			nm_setStatus("Traveling", "Vicious Bee (" data.field ")" ((A_Index > 1) ? " — Attempt " A_Index : ""))
			nm_gotoField(data.field)
			
			if attackingVB {
				switch (vic := nm_killVB(data.field)).result {
					case VBResults.success, VBResults.failed: ; death message or timeout
						return VBEnd(vic)
					case VBResults.retry: ; return to field
						continue fieldloop
				}
			}
			nm_setStatus("Searching", "Vicious Bee (" data.field ")")

			if !DisableToolUse
				Click "Down"

			patterns := [
				nm_Walk(data.initRight, RightKey) "`n" nm_Walk(data.initFwd, FwdKey),
				nm_Walk(data.lrdist, LeftKey) "`n" nm_Walk(data.fbdist, BackKey) "`n" nm_Walk(data.lrdist, RightKey) "`n" nm_Walk(data.fbdist, BackKey),
				nm_Walk(data.lrdist, LeftKey)
			]

			Loop 3 { ; 1 alignment, 2 search
				i := A_Index
				Loop (i = 2 ? data.reps : 1) { ; only repeat for search pattern
					switch (vic := SearchforVB(patterns[i], data.field)).result {
						case VBResults.success, VBResults.failed, VBResults.dead: ; end loop
							return VBEnd(vic)
						case VBResults.retry: ; return to field
							continue fieldloop
					}
				}
			}

			; nothing found, no issues
			Click "Up"
			break fieldloop
		}
	}
	; vb not found
	return 0
}
/**
 * End cycle and send status message using vic Obj
 */
VBEnd(vic){
	global VBLastKilled
	Click "Up"

	nm_setStatus("Completed"
	, "Vicious Bee — " vic.result  " — " vic.reason
	. "`nTime: " DurationFromSeconds(nowUnix() - VBStart, "mm:ss") 
	. "`nFields Checked: " fieldsChecked)

	if vic.result = VBResults.success {
		nm_IncrementStat("ViciousKills")

		IniWrite((VBLastKilled:=nowUnix()), "settings\nm_config.ini", "Collect", "VBLastKilled")
		return 1
	}
}
/** 
 * Create a movement with vicious bee detection. Used in both find and attack VB
 * @returns {{result: found/dead/retry/0, reason?: youDied/inactivehoney}}
 */
WalkwithVBCheck(movement, search:=true){
    local inactiveHoney := 0
    nm_OpenChat() ; just to ensure that chat is open 😭
    start := nowUnix()
    nm_createWalk(movement)
    KeyWait "F14", "D T5 L"
    while (GetKeyState("F14") && nowUnix()-start <= 20) ;20sec timeout
    {
        vic := nm_VBCheck()
		switch {
			case vic.result:
				if (!search && vic.result = VBResults.found) ; we dont care if VB is detected during atk phase
					continue

				nm_endWalk()
				return vic
			case !nm_activeHoney():
				if (inactiveHoney++ >= 10) { ; just increase inactive honey counter, break on 10
					nm_endWalk()
					return {result: VBResults.retry, reason: VBReasons.inactivehoney}
            	}
			case youDied: ; retry field
				nm_endWalk()
            	return {result: VBResults.retry, reason: VBReasons.youDied}
		}
    }
    nm_endWalk()
    return { result: 0 }
}
/**
 * Search for vicious bee
 *  @returns {{result: found | dead | retry | 0 , reason?: otherplayer | inactivehoney | youDied}}
 *  @returns {{result: success | failed | retry , reason?: killed | timeout}} VB found
 */
SearchforVB(movement, field){
	global VBInactiveHoney
	vic := WalkwithVBCheck(movement)
	if (vic.result != VBResults.retry || vic.reason != VBReasons.inactivehoney)
		VBInactiveHoney := 0
	switch vic.result {
		case VBResults.found: ; VB found bitmap found
			return nm_killVB(field)
		case VBResults.dead: ; VB dead bitmap found BEFORE VB found bitmap
			nm_setStatus("Detected", "Vicious Bee - Killed")
			vic.reason := VBReasons.otherPlayer
		case VBResults.retry: ; retry field: inactive honey/died
			if (vic.reason = VBReasons.inactivehoney) {
				if (++VBInactiveHoney < 5) {
					nm_setStatus("Warning", "Vicious Bee — Inactive Honey — Retrying")
				} else {
					; Consecutive failures exhausted this search; continue the cycle.
					vic.result := 0
				}
			}
	}

	return vic
}
/**
 * Kill vicious bee using battle pattern
 * @returns {{result: retry | success | failed}}
 */
nm_killVB(field) {
	global state:="Attacking", attackingVB := 1
	nm_setStatus("Attacking", "Vicious Bee (" field ")")

	battlepattern :=
	(
		nm_Walk(4, FwdKey) "
		Sleep 1000
		" nm_Walk(4, RightKey) "
		Sleep 1000
		" nm_Walk(4, BackKey) "
		Sleep 1000
		" nm_Walk(4, LeftKey)
	)

	while nowUnix()-VBfieldStart <= 300 { ; 5 minute timeout
		switch (vic := WalkwithVBCheck(battlepattern, false)).result {
			case VBResults.retry:
				nm_setStatus("Retrying", "Vicious Bee (" field ")")
				return vic
			case VBResults.dead:
				nm_setStatus("Killed", "Vicious Bee (" field ")")
				attackingVB := 0
				return {result: VBResults.success, reason: VBReasons.killed}
		}
	}
	nm_setStatus("Aborting", "Vicious Bee - Timeout")
	attackingVB := 0
	return {result: VBResults.failed, reason: VBReasons.timeout}
}
/**
 * Vicious bee detection using chat
 * @returns {{result: found/dead/0}}
 */
nm_VBCheck() {
	static LastRan := 0
	GetRobloxClientPos()
	offsetY := GetYOffset()
	if (nowUnix()-LastRan>=40) { ; chat translucent after 3 seconds, text dissapears after 40 seconds
		if !GetKeyState("F14")
			nm_OpenChat()
		else
			MouseMove(windowX + windowWidth - 22, windowY + offsetY + 60), MouseMove(windowX+350, windowY+offsetY+100)
		sleep 50
		LastRan := nowUnix()
	}

	pBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth - 8 - (windowWidth>=1195 ? 475 : windowWidth/2.5) "|" windowY+offsetY+40 "|" (windowWidth>=1195 ? 475 : windowWidth/2.5) "|" (windowHeight>=1156 ? 334 : windowHeight/3.464))
    
	for , bitmap in bitmaps["viciousbee"]["dead"] {
        if (Gdip_ImageSearch(pBMScreen, bitmap,,,,,, 5) = 1) {
            Gdip_DisposeImage(pBMScreen)
            return { result: VBResults.dead }
        }
    }
    for , bitmap in bitmaps["viciousbee"]["found"] {
        if (Gdip_ImageSearch(pBMScreen, bitmap,,,,,, 5) = 1) {
            Gdip_DisposeImage(pBMScreen)
            return { result: VBResults.found }
        }
    }
    Gdip_DisposeImage(pBMScreen)
    return { result: 0 }
}
;//todo: make it work if someone has chat disabled
; open roblox chat
nm_OpenChat(msg:="") {
    PrevKeyDelay := A_KeyDelay
    SetKeyDelay 50
	Send "{" SC_Slash "}" msg "`n"
    SetKeyDelay PrevKeyDelay
}
nm_hotbar(boost:=0){
	global state, fieldOverrideReason, GatherStartTime, ActiveHotkeys, bitmaps
		, HotbarMax2, HotbarMax3, HotbarMax4, HotbarMax5, HotbarMax6, HotbarMax7
		, LastHotkey2, LastHotkey3, LastHotkey4, LastHotkey5, LastHotkey6, LastHotkey7
		, beesmasActive, QuestBoostCheck
	;whileNames:=["Always", "Attacking", "Gathering", "At Hive"]
	;ActiveHotkeys.push([val, slot, HBSecs, LastHotkey%slot%])
	for key, val in ActiveHotkeys {
		;ActiveLen:=ActiveHotkeys.Length
		;temp1:=ActiveHotkeys[1][1]
		;temp2:=ActiveHotkeys[key][2]
		;temp3:=ActiveHotkeys[key][3]
		;temp4:=ActiveHotkeys[key][4]
		;always
		if(ActiveHotkeys[key][1]="Always" && (nowUnix()-ActiveHotkeys[key][4])>ActiveHotkeys[key][3]) {
			HotkeyNum:=ActiveHotkeys[key][2]
			send "{sc00" HotkeyNum+1 "}"
			LastHotkeyN:=nowUnix()
			IniWrite LastHotkeyN, "settings\nm_config.ini", "Boost", "LastHotkey" HotkeyNum
			ActiveHotkeys[key][4]:=LastHotkeyN
			break
		}
		;attacking
		else if(state="Attacking" && ActiveHotkeys[key][1]="Attacking" && (nowUnix()-ActiveHotkeys[key][4])>ActiveHotkeys[key][3]) {
			HotkeyNum:=ActiveHotkeys[key][2]
			send "{sc00" HotkeyNum+1 "}"
			LastHotkeyN:=nowUnix()
			IniWrite LastHotkeyN, "settings\nm_config.ini", "Boost", "LastHotkey" HotkeyNum
			ActiveHotkeys[key][4]:=LastHotkeyN
			break
		}
		;gathering
		else if(state="Gathering" && (fieldOverrideReason!="Quest" || (QuestBoostCheck = 1 && fieldOverrideReason="Quest")) && ActiveHotkeys[key][1]="Gathering" && (nowUnix()-ActiveHotkeys[key][4])>ActiveHotkeys[key][3]) {
			HotkeyNum:=ActiveHotkeys[key][2]
			send "{sc00" HotkeyNum+1 "}"
			LastHotkeyN:=nowUnix()
			IniWrite LastHotkeyN, "settings\nm_config.ini", "Boost", "LastHotkey" HotkeyNum
			ActiveHotkeys[key][4]:=LastHotkeyN
			break
		}
		;GatherStart
		else if(state="Gathering" && (fieldOverrideReason="None" || fieldOverrideReason="Boost" || (QuestBoostCheck = 1 && fieldOverrideReason="Quest")) && (nm_TimeTracking.Active("Gather") && nm_TimeTracking.Elapsed("Gather")<10) && ActiveHotkeys[key][1]="GatherStart" && (nowUnix()-ActiveHotkeys[key][4])>ActiveHotkeys[key][3]) {
			HotkeyNum:=ActiveHotkeys[key][2]
			send "{sc00" HotkeyNum+1 "}"
			LastHotkeyN:=nowUnix()
			IniWrite LastHotkeyN, "settings\nm_config.ini", "Boost", "LastHotkey" HotkeyNum
			if(ActiveHotkeys[key][3]<=10) {
				ActiveHotkeys[key][4]:=LastHotkeyN+10
			} else {
				ActiveHotkeys[key][4]:=LastHotkeyN
			}
			break
		}
		;at hive
		else if(state="Converting" && ActiveHotkeys[key][1]="At Hive" && (nowUnix()-ActiveHotkeys[key][4])>ActiveHotkeys[key][3]) {
			HotkeyNum:=ActiveHotkeys[key][2]
			send "{sc00" HotkeyNum+1 "}"
			LastHotkeyN:=nowUnix()
			IniWrite LastHotkeyN, "settings\nm_config.ini", "Boost", "LastHotkey" HotkeyNum
			ActiveHotkeys[key][4]:=LastHotkeyN
			break
		}
		;snowflake
		else if(beesmasActive && (ActiveHotkeys[key][1]="Snowflake") && (nowUnix()-ActiveHotkeys[key][4])>ActiveHotkeys[key][3]) {
			GetRobloxClientPos()
			offsetY := GetYOffset()
			;check that roblox window exists
			if (windowWidth > 0) {
				pBMArea := Gdip_BitmapFromScreen(windowX "|" windowY+offsetY+30 "|" windowWidth "|50")
				;check that: science buff visible and e button not visible (buffs not obscured)
				if ((Gdip_ImageSearch(pBMArea, bitmaps["science"]) = 1) && (Gdip_ImageSearch(pBMArea, bitmaps["e_button"]) = 0)) {
					if (Gdip_ImageSearch(pBMArea, bitmaps["snowflake_identifier"], &pos, , 20, , , , , 7) = 1) {
						;detect current snowflake buff amount
						x := SubStr(pos, 1, InStr(pos, ",")-1)

						(digits := Map()).Default := ""
						Loop 10
						{
							n := 10-A_Index
							if ((n = 1) || (n = 3))
								continue
							Gdip_ImageSearch(pBMArea, bitmaps["buffdigit" n], &list, x-32, 15, x-8, 50, 1, , 5, 5, , "`n")
							Loop Parse list, "`n"
								if (A_Index & 1)
									digits[Integer(A_LoopField)] := n
						}
						for m,n in [1,3]
						{
							Gdip_ImageSearch(pBMArea, bitmaps["buffdigit" n], &list, x-32, 15, x-8, 50, 1, , 5, 5, , "`n")
							Loop Parse list, "`n"
							{
								if (A_Index & 1)
								{
									if (((n = 1) && (digits[A_LoopField - 5] = 4)) || ((n = 3) && (digits[A_LoopField - 1] = 8)))
										continue
									digits[Integer(A_LoopField)] := n
								}
							}
						}
						num := ""
						for m,n in digits
							num .= n
					}
					else
						num := 0

					HotkeyNum:=ActiveHotkeys[key][2]
					;use snowflake if detected snowflake buff is below user selected maximum (num = "" implies 100% or indeterminate)
					if ((num != "") && (num < HotbarMax%HotkeyNum%)) {
						send "{sc00" HotkeyNum+1 "}"
						LastHotkeyN:=nowUnix()
						IniWrite LastHotkeyN, "settings\nm_config.ini", "Boost", "LastHotkey" HotkeyNum
						ActiveHotkeys[key][4]:=LastHotkeyN
						Gdip_DisposeImage(pBMArea)
						break
					}
				}
				Gdip_DisposeImage(pBMArea)
			}
		}
	}
}

;quest functions //todo: pending rewrite: lots of code duplication and inefficiencies!
nm_QuestRotate(){
	global QuestGatherField, RotateQuest, BlackQuestCheck, BlackQuestComplete, LastBlackQuest, BrownQuestCheck, BuckoQuestCheck, BuckoQuestComplete, RileyQuestCheck, RileyQuestComplete, HoneyQuestCheck, PolarQuestCheck, GatherFieldBoostedStart, LastGlitter, MondoBuffCheck, PMondoGuid, LastGuid, MondoAction, LastMondoBuff, bitmaps

	if ((BlackQuestCheck=0) && (BrownQuestCheck=0) && (BuckoQuestCheck=0) && (RileyQuestCheck=0) && (HoneyQuestCheck=0) && (PolarQuestCheck=0))
		return
	if (nm_NightInterrupt() || nm_MondoInterrupt() || nm_GatherBoostInterrupt())
		return

	;polar bear quest
	nm_PolarQuest()

	if (QuestGatherField = "None") {
		;black bear quest first
		nm_BlackQuest()

		;black bear quest is complete but not yet time to turn in, move onto next quest
		if(BlackQuestCheck=0 || BlackQuestComplete = -1 || (BlackQuestComplete = 1 && ((nowUnix()-LastBlackQuest)<3600 || !nm_QuestRecovery.Ready("Black", "visit")))) {
			;bucko quest
			nm_BuckoQuest()
			if(BuckoQuestCheck=0 || BuckoQuestComplete != 0 || QuestGatherField = "None") {
				nm_RileyQuest()
			}
		}
	}

	if (QuestGatherField = "None") {
		;all previous quests did not set a QuestGatherField, so check brown bear quest
		nm_BrownQuest()
	}

	;honey bee quest
	nm_HoneyQuest()
}
nm_HoneyQuestProg(){
	global HoneyStart
	global HoneyQuestCheck
	global HoneyQuestProgress
	global HoneyQuestComplete:=-1
	global QuestBarSize
	global QuestBarGapSize
	global QuestBarInset
	global state, bitmaps
	if(!HoneyQuestCheck)
		return
	if !nm_QuestRecovery.Begin("Honey", "read") {
		nm_PublishUnknownQuest("Honey")
		return
	}
	try {
		nm_setShiftLock(0)
		if !nm_OpenMenu("questlog")
			return 0

		hwnd := GetRobloxHWND()
		offsetY := GetYOffset(hwnd, &offsetFailed)
		if offsetFailed || !GetRobloxClientPos(hwnd)
			return
		;search for honey quest
		Loop 70
		{
			Qfound:=nm_imgSearch("honeyhunt.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			ActivateRoblox()
			switch A_Index
			{
				case 1:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				Loop 50 ; scroll all the way up
				{
					MouseMove windowX+30, windowY+offsetY+200, 5
					sendinput "{WheelUp}"
					Sleep 50
				}
				pBMLog := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")

				default:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				sendinput "{WheelDown}"
				Sleep 500 ; wait for scroll to finish
				pBMScreen := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")
				if (Gdip_ImageSearch(pBMScreen, pBMLog, , , , , , 50) = 1) { ; end of quest log
					Gdip_DisposeImage(pBMLog), Gdip_DisposeImage(pBMScreen)
					break
				}
				Gdip_DisposeImage(pBMLog), pBMLog := Gdip_CloneBitmap(pBMScreen), Gdip_DisposeImage(pBMScreen)
			}
		}
		Sleep 500

		if(Qfound[1]=0){
			;locate exact bottom of quest title bar coordinates
			;titlebar = 30 pixels high
			;quest objective bar spacing = 10 pixels
			;quest objective bar height = 40 pixels
			GetRobloxClientPos(hwnd)
			MouseMove windowX+350, windowY+offsetY+100
			xi := windowX
			yi := windowY+Qfound[3]
			ww := windowX+306
			wh := windowY+windowHeight
			fileName:="questbargap.png"
			if DirExist(A_WorkingDir "\nm_image_assets")
			{
				try result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*5 " A_WorkingDir "\nm_image_assets\" fileName)
				catch {
					nm_setStatus("Error", "Image file " filename " was not found in:`n" A_WorkingDir "\nm_image_assets\" fileName)
					Sleep 5000
					ProcessClose DllCall("GetCurrentProcessId")
				}
			} else {
				MsgBox "Folder location cannot be found:`n" A_WorkingDir "\nm_image_assets\"
			}
			HoneyStart:=(result = 1) ? [0, FoundX-windowX, FoundY-windowY] : [1, 0, 0]
			if HoneyStart[1] != 0
				return
			rowStates := nm_ReadQuestRows(hwnd, HoneyStart[3], 1, "honeyhunt")
			HoneyQuestComplete := nm_QuestObservation.Aggregate(rowStates, 1)
			;Update Honey quest progress in GUI
			honeyProgress:=""
			;also set next steps
			rowState := rowStates[1]
			if(rowState = 0) {
				completeness:="Incomplete"
			}
			; Only the explicit completed background is completion evidence.
			else if(rowState = 1) {
				completeness:="Complete"
			} else {
				completeness:="Unknown"
			}
			honeyProgress:=("Honey Tokens: " . completeness)
			IniWrite honeyProgress, "settings\nm_config.ini", "Quests", "HoneyQuestProgress"
			MainGui["HoneyQuestProgress"].Text := StrReplace(honeyProgress, "|", "`n")
		}
	} finally {
		nm_QuestRecovery.Finish("Honey", "read", HoneyQuestComplete = 0 || HoneyQuestComplete = 1)
		if HoneyQuestComplete = -1
			nm_PublishUnknownQuest("Honey")
	}
}
nm_PolarQuestProg(){
	global PolarQuestCheck
	global PolarBear
	global PolarQuest
	global PolarStart
	global PolarQuestProgress
	global QuestGatherField:="None"
	global QuestGatherFieldSlot:=0
	global PolarQuestComplete:=-1
	global QuestLadybugs
	global QuestRhinoBeetles
	global QuestSpider
	global QuestMantis
	global QuestScorpions
	global QuestWerewolf
	global QuestBarSize
	global QuestBarGapSize
	global QuestBarInset
	global state, bitmaps
	if(!PolarQuestCheck)
		return
	if !nm_QuestRecovery.Begin("Polar", "read") {
		nm_PublishUnknownQuest("Polar")
		return
	}
	try {
		PolarQuest := ""
		QuestLadybugs := 0
		QuestRhinoBeetles := 0
		QuestSpider := 0
		QuestMantis := 0
		QuestScorpions := 0
		QuestWerewolf := 0
		nm_setShiftLock(0)
		if !nm_OpenMenu("questlog")
			return 0

		hwnd := GetRobloxHWND()
		offsetY := GetYOffset(hwnd, &offsetFailed)
		if offsetFailed || !GetRobloxClientPos(hwnd)
			return
		;search for polar quest
		Loop 70
		{
			Qfound:=nm_imgSearch("polar_bear.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("polar_bear2.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("polar_bear3.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			ActivateRoblox()
			switch A_Index
			{
				case 1:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				Loop 50 ; scroll all the way up
				{
					MouseMove windowX+30, windowY+offsetY+200, 5
					sendinput "{WheelUp}"
					Sleep 50
				}
				pBMLog := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")

				default:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				sendinput "{WheelDown}"
				Sleep 500 ; wait for scroll to finish
				pBMScreen := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")
				if (Gdip_ImageSearch(pBMScreen, pBMLog, , , , , , 50) = 1) { ; end of quest log
					Gdip_DisposeImage(pBMLog), Gdip_DisposeImage(pBMScreen)
					break
				}
				Gdip_DisposeImage(pBMLog), pBMLog := Gdip_CloneBitmap(pBMScreen), Gdip_DisposeImage(pBMScreen)
			}
		}
		Sleep 500

		if(Qfound[1]=0){
			;locate exact bottom of quest title bar coordinates
			;titlebar = 30 pixels high
			;quest objective bar spacing = 10 pixels
			;quest objective bar height = 40 pixels
			GetRobloxClientPos(hwnd)
			MouseMove windowX+350, windowY+offsetY+100
			xi := windowX
			yi := windowY+Qfound[3]
			ww := windowX+306
			wh := windowY+windowHeight
			fileName:="questbargap.png"
			if DirExist(A_WorkingDir "\nm_image_assets")
			{
				try result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*5 " A_WorkingDir "\nm_image_assets\" fileName)
				catch {
					nm_setStatus("Error", "Image file " filename " was not found in:`n" A_WorkingDir "\nm_image_assets\" fileName)
					Sleep 5000
					ProcessClose DllCall("GetCurrentProcessId")
				}
			} else {
				MsgBox "Folder location cannot be found:`n" A_WorkingDir "\nm_image_assets\"
			}
			PolarStart:=(result = 1) ? [0, FoundX-windowX, FoundY-windowY] : [1, 0, 0]
			if PolarStart[1] != 0
				return
			;determine Quest name
			xi := windowX
			yi := windowY+PolarStart[3]-30
			ww := windowX+306
			wh := windowY+PolarStart[3]
			recognized := false, fullyVisible := false
			for key, value in PolarBear {
				filename:=(key . ".png")
				try
					result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*10 nm_image_assets\" fileName)
				catch
					result := 0
				if(result = 1) {
					PolarQuest:=key, recognized := true
					questSteps:=PolarBear[key].Length
					;make sure full quest is visible
					loop 5 {
						found:=0
						NextY:=windowY+PolarStart[3]
						loop questSteps {
							try
								result := ImageSearch(&FoundX, &FoundY, windowX+QuestBarInset, NextY, windowX+QuestBarInset+300, NextY+QuestBarGapSize, "*5 nm_image_assets\questbargap.png")
							catch
								result := 0
							if(result = 1) {
								NextY:=NextY+QuestBarSize
								found:=found+1
							} else {
								break
							}
						}
						if(found<questSteps) {
							MouseMove windowX+30, windowY+offsetY+225
							Sleep 50
							Send "{WheelDown 1}"
							Sleep 50
							PolarStart[3]-=150
							Sleep 500
						} else {
							fullyVisible := true
							break 2
						}
					}
					break
				}
			}
			if !recognized || !fullyVisible
				return
			rowStates := nm_ReadQuestRows(hwnd, PolarStart[3], PolarBear[PolarQuest].Length, PolarQuest)
			PolarQuestComplete := nm_QuestObservation.Aggregate(rowStates, PolarBear[PolarQuest].Length)
			;Update Polar quest progress in GUI
			;also set next steps
			QuestGatherField:="None"
			QuestGatherFieldSlot:=0
			newLine:="|"
			polarProgress:=""
			num:=PolarBear[PolarQuest].Length
			loop num {
				action:=PolarBear[PolarQuest][A_Index][2]
				where:=PolarBear[PolarQuest][A_Index][3]
				rowState := rowStates[PolarBear[PolarQuest][A_Index][1]]
				if(rowState = 0) {
					completeness:="Incomplete"
					if(action="kill"){
						Quest%where%:=1
					}
					else if (action="collect" && QuestGatherField="none") {
						QuestGatherField:=where
						QuestGatherFieldSlot:=PolarBear[PolarQuest][A_Index][1]
					}
				}
				; Only the explicit completed background is completion evidence.
				else if(rowState = 1) {
					completeness:="Complete"
					if(action="kill"){
						Quest%where%:=0
					}
				} else {
					completeness:="Unknown"
				}
				if(A_Index=1)
					polarProgress:=(PolarQuest . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
				else
					polarProgress:=(polarProgress . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
			}
			IniWrite polarProgress, "settings\nm_config.ini", "Quests", "PolarQuestProgress"
			MainGui["PolarQuestProgress"].Text := StrReplace(polarProgress, "|", "`n")
		}
	} finally {
		nm_QuestRecovery.Finish("Polar", "read", PolarQuestComplete = 0 || PolarQuestComplete = 1)
		if PolarQuestComplete = -1
			nm_PublishUnknownQuest("Polar")
	}
}

nm_RileyQuestProg(){
	global RileyQuestCheck, RileyBee, RileyQuest, RileyStart, HiveBees, FieldName1, LastAntPass, LastRedBoost, RileyLadybugs, RileyScorpions, RileyAll
	global QuestGatherField:="None"
	global QuestGatherFieldSlot:=0
	global RileyQuestComplete:=-1
	global RileyQuestProgress
	global QuestAnt:=0
	global QuestRedBoost:=0
	global QuestFeed:="None"
	global QuestBarSize
	global QuestBarGapSize
	global QuestBarInset
	global state
	global LastBugrunLadybugs, MonsterRespawnTime, LastBugrunScorpions, bitmaps
	if(!RileyQuestCheck)
		return
	if !nm_QuestRecovery.Begin("Riley", "read") {
		nm_PublishUnknownQuest("Riley")
		return
	}
	try {
		RileyQuest := ""
		RileyLadybugs := 0
		RileyScorpions := 0
		RileyAll := 0
		nm_setShiftLock(0)
		if !nm_OpenMenu("questlog")
			return 0

		hwnd := GetRobloxHWND()
		offsetY := GetYOffset(hwnd, &offsetFailed)
		if offsetFailed || !GetRobloxClientPos(hwnd)
			return
		;search for riley quest
		Loop 70
		{
			Qfound:=nm_imgSearch("riley.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("riley2.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			ActivateRoblox()
			switch A_Index
			{
				case 1:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				Loop 50 ; scroll all the way up
				{
					MouseMove windowX+30, windowY+offsetY+200, 5
					sendinput "{WheelUp}"
					Sleep 50
				}
				pBMLog := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")

				default:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				sendinput "{WheelDown}"
				Sleep 500 ; wait for scroll to finish
				pBMScreen := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")
				if (Gdip_ImageSearch(pBMScreen, pBMLog, , , , , , 50) = 1) { ; end of quest log
					Gdip_DisposeImage(pBMLog), Gdip_DisposeImage(pBMScreen)
					break
				}
				Gdip_DisposeImage(pBMLog), pBMLog := Gdip_CloneBitmap(pBMScreen), Gdip_DisposeImage(pBMScreen)
			}
		}
		Sleep 500

		if(Qfound[1]=0){
			;locate exact bottom of quest title bar coordinates
			;titlebar = 30 pixels high
			;quest objective bar spacing = 10 pixels
			;quest objective bar height = 40 pixels
			GetRobloxClientPos(hwnd)
			MouseMove windowX+350, windowY+offsetY+100
			xi := windowX
			yi := windowY+Qfound[3]
			ww := windowX+306
			wh := windowY+windowHeight
			fileName:="questbargap.png"
			if DirExist(A_WorkingDir "\nm_image_assets")
			{
				try result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*5 " A_WorkingDir "\nm_image_assets\" fileName)
				catch {
					nm_setStatus("Error", "Image file " filename " was not found in:`n" A_WorkingDir "\nm_image_assets\" fileName)
					Sleep 5000
					ProcessClose DllCall("GetCurrentProcessId")
				}
			} else {
				MsgBox "Folder location cannot be found:`n" A_WorkingDir "\nm_image_assets\"
			}
			RileyStart:=(result = 1) ? [0, FoundX-windowX, FoundY-windowY] : [1, 0, 0]
			if RileyStart[1] != 0
				return
			;determine Quest name
			xi := windowX
			yi := windowY+RileyStart[3]-30
			ww := windowX+306
			wh := windowY+RileyStart[3]
			recognized := false, fullyVisible := false
			for key, value in RileyBee {
				filename:=(key . ".png")
				try
					result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*100 nm_image_assets\" fileName)
				catch
					result := 0
				if(result = 1) {
					RileyQuest:=key, recognized := true
					questSteps:=RileyBee[key].Length
					;make sure full quest is visible
					loop 5 {
						found:=0
						NextY:=windowY+RileyStart[3]
						loop questSteps {
							try
								result := ImageSearch(&FoundX, &FoundY, windowX+QuestBarInset, NextY, windowX+QuestBarInset+300, NextY+QuestBarGapSize, "*5 nm_image_assets\questbargap.png")
							catch
								result := 0
							if(result = 1) {
								NextY:=NextY+QuestBarSize
								found:=found+1
							} else {
								break
							}
						}
						if(found<questSteps) {
							MouseMove windowX+30, windowY+offsetY+225
							Sleep 50
							Send "{WheelDown 1}"
							Sleep 50
							RileyStart[3]-=150
							Sleep 500
						} else {
							fullyVisible := true
							break 2
						}
					}
					break
				}
			}
			if !recognized || !fullyVisible
				return
			rowStates := nm_ReadQuestRows(hwnd, RileyStart[3], RileyBee[RileyQuest].Length, RileyQuest)
			RileyQuestComplete := nm_QuestObservation.Aggregate(rowStates, RileyBee[RileyQuest].Length)
			;Update Riley quest progress in GUI
			;also set next steps
			QuestGatherField:="None"
			QuestGatherFieldSlot:=0
			QuestRedAnyField:=0
			RileyLadybugs:=0
			RileyScorpions:=0
			RileyAll:=0
			newLine:="|"
			rileyProgress:=""
			num:=RileyBee[RileyQuest].Length
			loop num {
				action:=RileyBee[RileyQuest][A_Index][2]
				where:=RileyBee[RileyQuest][A_Index][3]
				rowState := rowStates[RileyBee[RileyQuest][A_Index][1]]
				if(rowState = 0) {
					completeness:="Incomplete"
					if(action="kill"){
						Riley%where%:=1
					}
					else if (action="collect" && QuestGatherField="none") {
						;red, blue, white, any
						if(where="red"){
							if(HiveBees>=35){
								where:="Pepper"
							} else if(HiveBees>=15){
								where:="Rose"
							} else if (HiveBees>=5) {
								where:="Strawberry"
							} else {
								where:="Mushroom"
							}
						} else if (where="blue") {
							if(HiveBees>=15){
								where:="Pine Tree"
							} else if (HiveBees>=5) {
								where:="Bamboo"
							} else {
								where:="Blue Flower"
							}
						} else if (where="white") {
							if (HiveBees>=10) {
								where:="Pineapple"
							} else if (HiveBees>=5) {
								where:="Spider"
							} else {
								where:="Sunflower"
							}
						} else if (where="any") {
							;where:=FieldName1
							where:="None"
							QuestRedAnyField:=1
						}
						QuestGatherField:=where
						QuestGatherFieldSlot:=RileyBee[RileyQuest][A_Index][1]
					}
					else if(action="get"){ ;Ant, RedBoost
						if(where="ant") {
							QuestAnt:=1
						}
						else if(where="RedBoost"){
							QuestRedBoost:=1
						}
					}
					else if(action="feed"){ ;Strawberries
						QuestFeed:=where
					}
				}
				; Only the explicit completed background is completion evidence.
				else if(rowState = 1) {
					completeness:="Complete"
				} else {
					completeness:="Unknown"
				}
				if(A_Index=1)
					rileyProgress:=(RileyQuest . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
				else
					rileyProgress:=(rileyProgress . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
			}
			IniWrite rileyProgress, "settings\nm_config.ini", "Quests", "RileyQuestProgress"
			MainGui["RileyQuestProgress"].Text := StrReplace(rileyProgress, "|", "`n")
		}
	} finally {
		nm_QuestRecovery.Finish("Riley", "read", RileyQuestComplete = 0 || RileyQuestComplete = 1)
		if RileyQuestComplete = -1
			nm_PublishUnknownQuest("Riley")
	}
}

nm_BuckoQuestProg(){
	global BuckoQuestCheck, BuckoBee, BuckoQuest, BuckoStart, HiveBees, FieldName1, LastAntPass, LastBlueBoost, BuckoRhinoBeetles, BuckoMantis
	global QuestGatherField:="None"
	global QuestGatherFieldSlot:=0
	global BuckoQuestComplete:=-1
	global BuckoQuestProgress
	global QuestAnt:=0
	global QuestBlueBoost:=0
	global QuestFeed:="None"
	global QuestBarSize
	global QuestBarGapSize
	global QuestBarInset
	global state
	global MonsterRespawnTime, LastBugrunRhinoBeetles, LastBugrunMantis, bitmaps
	if(!BuckoQuestCheck)
		return
	if !nm_QuestRecovery.Begin("Bucko", "read") {
		nm_PublishUnknownQuest("Bucko")
		return
	}
	try {
		BuckoQuest := ""
		BuckoRhinoBeetles := 0
		BuckoMantis := 0
		nm_setShiftLock(0)
		if !nm_OpenMenu("questlog")
			return 0

		hwnd := GetRobloxHWND()
		offsetY := GetYOffset(hwnd, &offsetFailed)
		if offsetFailed || !GetRobloxClientPos(hwnd)
			return
		;search for bucko quest
		Loop 70
		{
			Qfound:=nm_imgSearch("bucko.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("bucko2.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			ActivateRoblox()
			switch A_Index
			{
				case 1:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				Loop 50 ; scroll all the way up
				{
					MouseMove windowX+30, windowY+offsetY+200, 5
					sendinput "{WheelUp}"
					Sleep 50
				}
				pBMLog := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")

				default:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				sendinput "{WheelDown}"
				Sleep 500 ; wait for scroll to finish
				pBMScreen := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")
				if (Gdip_ImageSearch(pBMScreen, pBMLog, , , , , , 50) = 1) { ; end of quest log
					Gdip_DisposeImage(pBMLog), Gdip_DisposeImage(pBMScreen)
					break
				}
				Gdip_DisposeImage(pBMLog), pBMLog := Gdip_CloneBitmap(pBMScreen), Gdip_DisposeImage(pBMScreen)
			}
		}
		Sleep 500

		if(Qfound[1]=0){
			;locate exact bottom of quest title bar coordinates
			;titlebar = 30 pixels high
			;quest objective bar spacing = 10 pixels
			;quest objective bar height = 40 pixels
			GetRobloxClientPos(hwnd)
			MouseMove windowX+350, windowY+offsetY+100
			xi := windowX
			yi := windowY+Qfound[3]
			ww := windowX+306
			wh := windowY+windowHeight
			fileName:="questbargap.png"
			if DirExist(A_WorkingDir "\nm_image_assets")
			{
				try result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*5 " A_WorkingDir "\nm_image_assets\" fileName)
				catch {
					nm_setStatus("Error", "Image file " filename " was not found in:`n" A_WorkingDir "\nm_image_assets\" fileName)
					Sleep 5000
					ProcessClose DllCall("GetCurrentProcessId")
				}
			} else {
				MsgBox "Folder location cannot be found:`n" A_WorkingDir "\nm_image_assets\"
			}
			BuckoStart:=(result = 1) ? [0, FoundX-windowX, FoundY-windowY] : [1, 0, 0]
			if BuckoStart[1] != 0
				return
			;determine Quest name
			xi := windowX
			yi := windowY+BuckoStart[3]-30
			ww := windowX+306
			wh := windowY+BuckoStart[3]
			recognized := false, fullyVisible := false
			for key, value in BuckoBee {
				filename:=(key . ".png")
				try
					result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*100 nm_image_assets\" fileName)
				catch
					result := 0
				if(result = 1) {
					BuckoQuest:=key, recognized := true
					questSteps:=BuckoBee[key].Length
					;make sure full quest is visible
					loop 5 {
						found:=0
						NextY:=windowY+BuckoStart[3]
						loop questSteps {
							try
								result := ImageSearch(&FoundX, &FoundY, windowX+QuestBarInset, NextY, windowX+QuestBarInset+300, NextY+QuestBarGapSize, "*5 nm_image_assets\questbargap.png")
							catch
								result := 0
							if(result = 1) {
								NextY:=NextY+QuestBarSize
								found:=found+1
							} else {
								break
							}
						}
						if(found<questSteps) {
							MouseMove windowX+30, windowY+offsetY+225
							Sleep 50
							Send "{WheelDown 1}"
							Sleep 50
							BuckoStart[3]-=150
							Sleep 500
						} else {
							fullyVisible := true
							break 2
						}
					}
					break
				}
			}
			if !recognized || !fullyVisible
				return
			rowStates := nm_ReadQuestRows(hwnd, BuckoStart[3], BuckoBee[BuckoQuest].Length, BuckoQuest)
			BuckoQuestComplete := nm_QuestObservation.Aggregate(rowStates, BuckoBee[BuckoQuest].Length)
			;Update Bucko quest progress in GUI
			;also set next steps
			BuckoRhinoBeetles:=0
			BuckoMantis:=0
			QuestGatherField:="None"
			QuestGatherFieldSlot:=0
			QuestBlueAnyField:=0
			QuestAnt:=0
			newLine:="|"
			buckoProgress:=""
			num:=BuckoBee[BuckoQuest].Length
			loop num {
				action:=BuckoBee[BuckoQuest][A_Index][2]
				where:=BuckoBee[BuckoQuest][A_Index][3]
				rowState := rowStates[BuckoBee[BuckoQuest][A_Index][1]]
				if(rowState = 0) {
					completeness:="Incomplete"
					if(action="kill"){
						Bucko%where%:=1
					}
					else if (action="collect" && QuestGatherField="none") {
						;red, blue, white, any
						if(where="red"){
							if(HiveBees>=35){
								where:="Pepper"
							} else if(HiveBees>=15){
								where:="Rose"
							} else if (HiveBees>=5) {
								where:="Strawberry"
							} else {
								where:="Mushroom"
							}
						} else if (where="blue") {
							if(HiveBees>=15){
								where:="Pine Tree"
							} else if (HiveBees>=5) {
								where:="Bamboo"
							} else {
								where:="Blue Flower"
							}
						} else if (where="white") {
							if (HiveBees>=10) {
								where:="Pineapple"
							} else if (HiveBees>=5) {
								where:="Spider"
							} else {
								where:="Sunflower"
							}
						} else if (where="any") {
							;where:=FieldName1
							where:="None"
							QuestBlueAnyField:=1
						}
						QuestGatherField:=where
						QuestGatherFieldSlot:=BuckoBee[BuckoQuest][A_Index][1]
					}
					else if(action="get"){ ;Ant, BlueBoost
						if(where="ant") {
							QuestAnt:=1
						}
						else if(where="BlueBoost"){
							QuestBlueBoost:=1
						}
					}
					else if(action="feed"){ ;Blueberries
						QuestFeed:=where
					}
				}
				; Only the explicit completed background is completion evidence.
				else if(rowState = 1) {
					completeness:="Complete"
				} else {
					completeness:="Unknown"
				}
				if(A_Index=1)
					buckoProgress:=(BuckoQuest . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
				else
					buckoProgress:=(buckoProgress . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
			}
			IniWrite buckoProgress, "settings\nm_config.ini", "Quests", "BuckoQuestProgress"
			MainGui["BuckoQuestProgress"].Text := StrReplace(buckoProgress, "|", "`n")
		}
	} finally {
		nm_QuestRecovery.Finish("Bucko", "read", BuckoQuestComplete = 0 || BuckoQuestComplete = 1)
		if BuckoQuestComplete = -1
			nm_PublishUnknownQuest("Bucko")
	}
}

nm_BlackQuestProg(){
	global BlackQuestCheck, BlackBear, BlackQuest, BlackStart, HiveBees, FieldName1
	global QuestGatherField:="None"
	global QuestGatherFieldSlot:=0
	global BlackQuestComplete:=-1
	global BlackQuestProgress
	global QuestBarSize
	global QuestBarGapSize
	global QuestBarInset
	global state, bitmaps
	if(!BlackQuestCheck)
		return
	if !nm_QuestRecovery.Begin("Black", "read") {
		nm_PublishUnknownQuest("Black")
		return
	}
	try {
		BlackQuest := ""
		nm_setShiftLock(0)
		if !nm_OpenMenu("questlog")
			return 0

		hwnd := GetRobloxHWND()
		offsetY := GetYOffset(hwnd, &offsetFailed)
		if offsetFailed || !GetRobloxClientPos(hwnd)
			return
		;search for black quest
		Loop 70
		{
			Qfound:=nm_imgSearch("black_bear.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("black_bear2.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("black_bear3.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("black_bear4.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("black_bear5.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			Qfound:=nm_imgSearch("black_bear6.png",50,"quest")
			if (Qfound[1]=0) {
				if (A_Index > 1)
					Gdip_DisposeImage(pBMLog)
				break
			}

			ActivateRoblox()
			switch A_Index
			{
				case 1:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				Loop 50 ; scroll all the way up
				{
					MouseMove windowX+30, windowY+offsetY+200, 5
					sendinput "{WheelUp}"
					Sleep 50
				}
				pBMLog := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")

				default:
				GetRobloxClientPos(hwnd)
				MouseMove windowX+30, windowY+offsetY+200, 5
				sendinput "{WheelDown}"
				Sleep 500 ; wait for scroll to finish
				pBMScreen := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")
				if (Gdip_ImageSearch(pBMScreen, pBMLog, , , , , , 50) = 1) { ; end of quest log
					Gdip_DisposeImage(pBMLog), Gdip_DisposeImage(pBMScreen)
					break
				}
				Gdip_DisposeImage(pBMLog), pBMLog := Gdip_CloneBitmap(pBMScreen), Gdip_DisposeImage(pBMScreen)
			}
		}
		Sleep 500

		if(Qfound[1]=0){
			;locate exact bottom of quest title bar coordinates
			;titlebar = 30 pixels high
			;quest objective bar spacing = 10 pixels
			;quest objective bar height = 40 pixels
			GetRobloxClientPos(hwnd)
			MouseMove windowX+350, windowY+offsetY+100
			xi := windowX
			yi := windowY+Qfound[3]
			ww := windowX+306
			wh := windowY+windowHeight
			fileName:="questbargap.png"
			if DirExist(A_WorkingDir "\nm_image_assets")
			{
				try result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*5 " A_WorkingDir "\nm_image_assets\" fileName)
				catch {
					nm_setStatus("Error", "Image file " filename " was not found in:`n" A_WorkingDir "\nm_image_assets\" fileName)
					Sleep 5000
					ProcessClose DllCall("GetCurrentProcessId")
				}
			} else {
				MsgBox "Folder location cannot be found:`n" A_WorkingDir "\nm_image_assets\"
			}
			BlackStart:=(result = 1) ? [0, FoundX-windowX, FoundY-windowY] : [1, 0, 0]
			if BlackStart[1] != 0
				return
			;determine Quest name
			xi := windowX
			yi := windowY+BlackStart[3]-30
			ww := windowX+306
			wh := windowY+BlackStart[3]
			recognized := false, fullyVisible := false
			for key, value in BlackBear {
				filename:=(key . ".png")
				try
					result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*100 nm_image_assets\" fileName)
				catch
					result := 0
				if(result = 1) {
					BlackQuest:=key, recognized := true
					questSteps:=BlackBear[key].Length
					;make sure full quest is visible
					loop 5 {
						found:=0
						NextY:=windowY+BlackStart[3]
						loop questSteps {
							try
								result := ImageSearch(&FoundX, &FoundY, windowX+QuestBarInset, NextY, windowX+QuestBarInset+300, NextY+QuestBarGapSize, "*5 nm_image_assets\questbargap.png")
							catch
								result := 0
							if(result = 1) {
								NextY:=NextY+QuestBarSize
								found:=found+1
							} else {
								break
							}
						}
						if(found<questSteps) {
							MouseMove windowX+30, windowY+offsetY+225
							Sleep 50
							Send "{WheelDown 1}"
							Sleep 50
							BlackStart[3]-=150
							Sleep 500
						} else {
							fullyVisible := true
							break 2
						}
					}
					Break
				}
			}
			if !recognized || !fullyVisible
				return
			rowStates := nm_ReadQuestRows(hwnd, BlackStart[3], BlackBear[BlackQuest].Length, BlackQuest)
			BlackQuestComplete := nm_QuestObservation.Aggregate(rowStates, BlackBear[BlackQuest].Length)
			;Update Black quest progress in GUI
			;also set next steps
			QuestGatherField:="None"
			QuestGatherFieldSlot:=0
			QuestBlackAnyField:=0
			newLine:="|"
			blackProgress:=""
			num:=BlackBear[BlackQuest].Length
			loop num {
				action:=BlackBear[BlackQuest][A_Index][2]
				where:=BlackBear[BlackQuest][A_Index][3]
				rowState := rowStates[BlackBear[BlackQuest][A_Index][1]]
				if(rowState = 0) {
					completeness:="Incomplete"
					;red, blue, white, any
					if(where="red"){
						if(HiveBees>=35){
							where:="Pepper"
						} else if(HiveBees>=15){
							where:="Rose"
						} else if (HiveBees>=5) {
							where:="Strawberry"
						} else {
							where:="Mushroom"
						}
					} else if (where="blue") {
						if(HiveBees>=15){
							where:="Pine Tree"
						} else if (HiveBees>=5) {
							where:="Bamboo"
						} else {
							where:="Blue Flower"
						}
					} else if (where="white") {
						if (HiveBees>=10) {
							where:="Pineapple"
						} else if (HiveBees>=5) {
							where:="Spider"
						} else {
							where:="Sunflower"
						}
					} else if (where="any") {
						;where:=FieldName1
						where:="None"
						QuestBlackAnyField:=1
					}
					if(QuestGatherField="None") {
						QuestGatherField:=where
						QuestGatherFieldSlot:=BlackBear[BlackQuest][A_Index][1]
					}
				}
				; Only the explicit completed background is completion evidence.
				else if(rowState = 1) {
					completeness:="Complete"
					if(action="kill"){
						Quest%where%:=0
					}
				} else {
					completeness:="Unknown"
				}
				if(A_Index=1)
					blackProgress:=(BlackQuest . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
				else
					blackProgress:=(blackProgress . newline . action . " " . (where = "None" ? "Any" : where) . ": " . completeness)
			}
			IniWrite blackProgress, "settings\nm_config.ini", "Quests", "BlackQuestProgress"
			MainGui["BlackQuestProgress"].Text := StrReplace(blackProgress, "|", "`n")
		}
	} finally {
		nm_QuestRecovery.Finish("Black", "read", BlackQuestComplete = 0 || BlackQuestComplete = 1)
		if BlackQuestComplete = -1
			nm_PublishUnknownQuest("Black")
	}
}

nm_BrownQuestProg(){
	global BrownQuestCheck, BrownQuest, BrownStart, HiveBees, FieldName1
	global QuestGatherField:="None"
	global QuestGatherFieldSlot:=0
	global BrownQuestComplete:=-1
	global BrownQuestProgress
	global QuestBarSize
	global QuestBarGapSize
	global QuestBarInset
	global state, bitmaps
	if(!BrownQuestCheck)
		return
	if !nm_QuestRecovery.Begin("Brown", "read") {
		nm_PublishUnknownQuest("Brown")
		return
	}
	try {
		BrownQuest := ""
		nm_setShiftLock(0)
		if !nm_OpenMenu("questlog")
			return 0

		hwnd := GetRobloxHWND()
		offsetY := GetYOffset(hwnd, &offsetFailed)
		if offsetFailed || !GetRobloxClientPos(hwnd)
			return
		;2 scrolls
		Loop 3 {
			;search for brown quest
			; if possible, move quest to top half of screen, to ensure quest tasks not cut off
			aim := ["questbrown", "quest"]
			loop aim.Length
			{
				i := A_Index
				Loop 70
				{
					n := A_Index
					loop 5
					{
						Qfound:=nm_imgSearch("brown_bear" A_Index ".png",50,aim[i])
						if (Qfound[1]=0) {
							if (n > 1)
								Gdip_DisposeImage(pBMLog)
							break 3
						}
					}

					ActivateRoblox()
					switch A_Index
					{
						case 1:
						GetRobloxClientPos(hwnd)
						MouseMove windowX+30, windowY+offsetY+200, 5
						Loop 50 ; scroll all the way up
						{
							MouseMove windowX+30, windowY+offsetY+200, 5
							sendinput "{WheelUp}"
							Sleep 50
						}
						pBMLog := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")

						default:
						GetRobloxClientPos(hwnd)
						MouseMove windowX+30, windowY+offsetY+200, 5
						sendinput "{WheelDown}"
						Sleep 500 ; wait for scroll to finish
						pBMScreen := Gdip_BitmapFromScreen(windowX+30 "|" windowY+offsetY+180 "|30|400")
						if (Gdip_ImageSearch(pBMScreen, pBMLog, , , , , , 50) = 1) { ; end of quest log
							Gdip_DisposeImage(pBMLog), Gdip_DisposeImage(pBMScreen)
							if i = 2
								break 2
							else
								continue 2 ; if not detected in top half, search rest
						}
						Gdip_DisposeImage(pBMLog), pBMLog := Gdip_CloneBitmap(pBMScreen), Gdip_DisposeImage(pBMScreen)
					}
				}
			}
			Sleep 500

			if(Qfound[1]=0){
				;locate exact bottom of quest title bar coordinates
				;titlebar = 30 pixels high
				;quest objective bar spacing = 10 pixels
				;quest objective bar height = 40 pixels
				GetRobloxClientPos(hwnd)
				MouseMove windowX+350, windowY+offsetY+100
				xi := windowX
				yi := windowY+Qfound[3]
				ww := windowX+306
				wh := windowY+windowHeight
				fileName:="questbargap.png"
				if DirExist(A_WorkingDir "\nm_image_assets\")
				{
					try result := ImageSearch(&FoundX, &FoundY, xi, yi, ww, wh, "*5 " A_WorkingDir "\nm_image_assets\" fileName)
					catch {
						nm_setStatus("Error", "Image file " filename " was not found in:`n" A_WorkingDir "\nm_image_assets\" fileName)
						Sleep 5000
						ProcessClose DllCall("GetCurrentProcessId")
					}
				} else {
					MsgBox "Folder location cannot be found:`n" A_WorkingDir "\nm_image_assets\"
				}
				BrownStart:=(result = 1) ? [0, FoundX-windowX, FoundY-windowY] : [1, 0, 0]
				if BrownStart[1] != 0
					return
				;determine Quest objecives
				static objectiveList := Map("dandelion","Dand", "sunflower","Sunf", "mushroom","Mush", "blueflower","Bluf", "clover","Clove"
					, "strawberry","Straw", "spider","Spide", "bamboo","Bamb", "pineapple","Pinap", "stump","Stump"
					, "cactus","Cact", "pumpkin","Pump", "pinetree","Pine"
					, "rose","Rose", "mountaintop","Mount", "pepper","Pepp", "coconut","Coco"
					, "redpollen","Red", "bluepollen","Blue", "whitepollen","White")
				objectives := [], endpointConfirmed := false

				GetRobloxClientPos(hwnd)
				while ((objectives.Length < 4) && (A_Index <= 5)) { ; maximum 4 objectives
					priorCount := objectives.Length
					objectivePos := objectives.Length * QuestBarSize, objectiveSize := 0
					pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY+BrownStart[3]+QuestBarGapSize+objectivePos "|304|" QuestBarSize-QuestBarGapSize)

					if (Gdip_ImageSearch(pBMScreen, bitmaps["questbarinset"], , , , 6, , 5) = 1) {
						for size in [16,15,14,18,17] { ; in approximate order of probability
							if (Gdip_ImageSearch(pBMScreen, bitmaps["s" size "collect"], , 6, , , , 30) = 1) {
								objectiveSize := size
								break
							}
						}

						if (objectiveSize = 0)
							objectives.Push("unknown")
						else {
							for k in objectiveList {
								for v in objectives ; if objective already exists, cannot be duplicated
									if (k = v)
										continue 2
								if (bitmaps.Has("s" objectiveSize k) && (Gdip_ImageSearch(pBMScreen, bitmaps["s" objectiveSize k], , 6, , , , 30) = 1)) {
									objectives.Push(k)
									break
								}
							}
						}
					} else {
						;//todo: replace this with proper questlog endpoint detection (similar to inventory) to determine if quest is cut off or not, instead of next quest title (which may not exist)
						if ((Gdip_ImageSearch(pBMScreen, bitmaps["questbartitle"], , , , 6, , 5) = 1) || (Gdip_ImageSearch(pBMScreen, bitmaps["questbartitlebeesmas"], , , , 6, , 5) = 1)) {
							Gdip_DisposeImage(pBMScreen)
							endpointConfirmed := true
							break ; end of quest reached confirmed, since there is a quest below
						}

						;//todo: detect if scrollbar is already at end before scrolling, or how much has scrolled instead of fixed 150. every quest needs this, should be in rewrite
						Gdip_DisposeImage(pBMScreen)
						; scroll, but only if the questgiver name is in the lower part of the screen
						if (yi > (wh - (windowHeight//2))) {
							MouseMove windowX+30, windowY+offsetY+200, 5
							Sleep 50
							sendinput "{WheelDown 1}" ; to allow for tasks not on screen, if applicable
							Sleep 500 ; wait for scroll to finish
						}
						continue 2
					}

					if objectives.Length = priorCount
						objectives.Push("unknown")
					Gdip_DisposeImage(pBMScreen)
				}
				break
			} else {
				return
			}
		}

		if !IsSet(objectives) || !objectives.Length || (!endpointConfirmed && objectives.Length < 4)
			return
		rowStates := nm_ReadQuestRows(hwnd, BrownStart[3], objectives.Length, "Brown", objectives)
		BrownQuestComplete := nm_QuestObservation.Aggregate(rowStates, objectives.Length)
		;Update Brown quest progress in GUI
		;also set next steps
		QuestGatherField:="None"
		QuestGatherFieldSlot:=0
		QuestGatherObjective:=""
		newLine:="|"
		brownProgress:=""
		BrownQuest:=(objectives.Length = 1) ? "Solo" : ""
		for i,obj in objectives {
			action:="Collect"
			; decide field (where)
			;//todo: make this into a function for use in other quest functions
			switch obj {
				case "redpollen":
				if(HiveBees>=35){
					where:="Pepper"
				} else if(HiveBees>=15){
					where:="Rose"
				} else if (HiveBees>=5) {
					where:="Strawberry"
				} else {
					where:="Mushroom"
				}

				case "bluepollen":
				if(HiveBees>=15){
					where:="Pine Tree"
				} else if (HiveBees>=5) {
					where:="Bamboo"
				} else {
					where:="Blue Flower"
				}

				case "whitepollen":
				if (HiveBees>=10) {
					where:="Pineapple"
				} else if (HiveBees>=5) {
					where:="Spider"
				} else {
					where:="Sunflower"
				}

				case "blueflower":
				where:="Blue Flower"

				case "pinetree":
				where:="Pine Tree"

				case "mountaintop":
				where:="Mountain Top"

				default:
				where:=StrTitle(obj) ; title case, capitalise first letter
			}

			rowState := rowStates[i]
			if(rowState = 0) {
				completeness:="Incomplete"
				if(QuestGatherField="None" || InStr(QuestGatherObjective, "pollen")) { ; override colour pollen if there is an incomplete field objective
					QuestGatherField:=where
					QuestGatherFieldSlot:=i
					QuestGatherObjective:=obj
				}
			}
			; Only the explicit completed background is completion evidence.
			else if(rowState = 1) {
				completeness:="Complete"
			} else {
				completeness:="Unknown"
			}
			BrownQuest .= "-" . ((obj = "unknown") ? "Unknown" : objectiveList[obj])
			brownProgress .= newline . action . " " . where . ": " . completeness
		}
		brownProgress := (BrownQuest := LTrim(BrownQuest, "-")) . brownProgress

		IniWrite brownProgress, "settings\nm_config.ini", "Quests", "BrownQuestProgress"
		MainGui["BrownQuestProgress"].Text := StrReplace(brownProgress, "|", "`n")
	} finally {
		nm_QuestRecovery.Finish("Brown", "read", BrownQuestComplete = 0 || BrownQuestComplete = 1)
		if BrownQuestComplete = -1
			nm_PublishUnknownQuest("Brown")
	}
}

nm_Feed(food){
	global bitmaps
	nm_setShiftLock(0)
	nm_Reset(0,0,0,1)
	nm_setStatus("Feeding", food)
	;feed
	nm_InventorySearch(food)
	hwnd := GetRobloxHWND()
	offsetY := GetYOffset(hwnd)
	Loop 10
	{
		GetRobloxClientPos(hwnd)
		pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY+offsetY+150 "|" (54*windowWidth)//100-50 "|" Max(480, windowHeight-offsetY-150))

		if (A_Index = 1)
		{
			; wait for red vignette effect to disappear
			Loop 40
			{
				if (Gdip_ImageSearch(pBMScreen, bitmaps["item"], , , , 6, , 2) = 1)
					break
				else
				{
					if (A_Index = 40)
					{
						Gdip_DisposeImage(pBMScreen)
						nm_setStatus("Missing", food)
						return 0
					}
					else
					{
						Sleep 50
						Gdip_DisposeImage(pBMScreen)
						pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY+offsetY+150 "|" (54*windowWidth)//100-50 "|" Max(480, windowHeight-offsetY-150))
					}
				}
			}
		}

		if ((Gdip_ImageSearch(pBMScreen, bitmaps[food], &pos, , , 306, , 10, , 5) != 1) || (Gdip_ImageSearch(pBMScreen, bitmaps["feed"], , (54*windowWidth)//100-300, , , , 2, , 2) = 1)) {
			Gdip_DisposeImage(pBMScreen)
			break
		}
		Gdip_DisposeImage(pBMScreen)

		MouseClickDrag "Left", windowX+30, windowY+SubStr(pos, InStr(pos, ",")+1)+190, windowX+windowWidth//2, windowY+41*windowHeight//100-10*(A_Index-1), 5
		Sleep 500
	}
	Loop 20 {
		Sleep 100
		pBMScreen := Gdip_BitmapFromScreen(windowX+(54*windowWidth)//100-300 "|" windowY+offsetY+(46*windowHeight)//100-59 "|250|100")
		if (Gdip_ImageSearch(pBMScreen, bitmaps["feed"], &pos, , , , , 2, , 2) = 1) {
			Gdip_DisposeImage(pBMScreen)
			MouseMove windowX+(54*windowWidth)//100-300+SubStr(pos, 1, InStr(pos, ",")-1)+140, windowY+offsetY+(46*windowHeight)//100-59+SubStr(pos, InStr(pos, ",")+1)+5 ; Number
			Sleep 100
			Click
			Sleep 100
			Send "{Text}100"
			Sleep 1000
			MouseMove windowX+(54*windowWidth)//100-300+SubStr(pos, 1, InStr(pos, ",")-1), windowY+offsetY+(46*windowHeight)//100-59+SubStr(pos, InStr(pos, ",")+1) ; Feed
			Sleep 100
			Click
			nm_setStatus("Completed", "Feed " food)
			break
		} else {
			Gdip_DisposeImage(pBMScreen)
			if (A_Index = 20) {
				MouseMove windowX+(54*windowWidth)//100-300+SubStr(pos, 1, InStr(pos, ",")-1), windowY+offsetY+(46*windowHeight)//100-59+SubStr(pos, InStr(pos, ",")+1)+64 ; Cancel
				Sleep 100
				Click
				nm_setStatus("Failed", "Feed " food)
			}
		}
	}
	MouseMove windowX+350, windowY+offsetY+100
	;close inventory
	nm_OpenMenu()
}
nm_bugDeathCheck(){
	global objective, TotalBugKills, SessionBugKills, LastBugrunLadybugs, LastBugrunRhinoBeetles, LastBugrunSpider, LastBugrunMantis, LastBugrunScorpions, LastBugrunWerewolf, BugDeathCheckLockout, BugrunLadybugsCheck, BugrunRhinoBeetlesCheck, BugrunMantisCheck, BugrunWerewolfCheck
	if(BugDeathCheckLockout && (nowUnix() - BugDeathCheckLockout)>20)
		BugDeathCheckLockout:=0
	if(BugDeathCheckLockout)
		return
	;ladybugs
	if(InStr(objective,"strawberry") || InStr(objective,"mushroom") || InStr(objective,"clover")) {
		searchRet := nm_imgSearch("ladybug.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunLadybugs:=nowUnix()
			IniWrite LastBugrunLadybugs, "settings\nm_config.ini", "Collect", "LastBugrunLadybugs"
			nm_IncrementStat("BugKills", 1)
		}
	}
	;rhino beetles
	else if(InStr(objective,"blue flower") || InStr(objective,"bamboo")) {
		searchRet := nm_imgSearch("rhino.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunRhinoBeetles:=nowUnix()
			IniWrite LastBugrunRhinoBeetles, "settings\nm_config.ini", "Collect", "LastBugrunRhinoBeetles"
			if(InStr(objective,"bamboo")) {
				nm_IncrementStat("BugKills", 2)
			} else {
				nm_IncrementStat("BugKills", 1)
			}
		}
	}
	;spider
	else if(InStr(objective,"spider")) {
		searchRet := nm_imgSearch("spider.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunSpider:=nowUnix()
			IniWrite LastBugrunSpider, "settings\nm_config.ini", "Collect", "LastBugrunSpider"
			nm_IncrementStat("BugKills", 1)
		}
	}
	;mantis/rhino beetle
	else if(InStr(objective,"pineapple")) {
		searchRet := nm_imgSearch("mantis.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunMantis:=nowUnix()
			IniWrite LastBugrunMantis, "settings\nm_config.ini", "Collect", "LastBugrunMantis"
			nm_IncrementStat("BugKills", 1)
		}
		searchRet := nm_imgSearch("rhino.png",30,"lowright")
		If (searchRet[1] = 0) {
			if(!BugrunMantisCheck)
				BugDeathCheckLockout:=nowUnix()
			LastBugrunRhinoBeetles:=nowUnix()
			IniWrite LastBugrunRhinoBeetles, "settings\nm_config.ini", "Collect", "LastBugrunRhinoBeetles"
			nm_IncrementStat("BugKills", 1)
		}
	}
	;mantis/werewolf
	else if(InStr(objective,"pine tree")) {
		searchRet := nm_imgSearch("mantis.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunMantis:=nowUnix()
			IniWrite LastBugrunMantis, "settings\nm_config.ini", "Collect", "LastBugrunMantis"
			nm_IncrementStat("BugKills", 2)
		}
		searchRet := nm_imgSearch("werewolf.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunWerewolf:=nowUnix()
			IniWrite LastBugrunWerewolf, "settings\nm_config.ini", "Collect", "LastBugrunWerewolf"
			nm_IncrementStat("BugKills", 1)
		}
	}
	;werewolf
	else if(InStr(objective,"pumpkin") || InStr(objective,"cactus")) {
		searchRet := nm_imgSearch("werewolf.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunWerewolf:=nowUnix()
			IniWrite LastBugrunWerewolf, "settings\nm_config.ini", "Collect", "LastBugrunWerewolf"
			nm_IncrementStat("BugKills", 1)
		}
	}
	;scorpions
	else if(InStr(objective,"rose")) {
		searchRet := nm_imgSearch("scorpion.png",30,"lowright")
		If (searchRet[1] = 0) {
			BugDeathCheckLockout:=nowUnix()
			LastBugrunScorpions:=nowUnix()
			IniWrite LastBugrunScorpions, "settings\nm_config.ini", "Collect", "LastBugrunScorpions"
			nm_IncrementStat("BugKills", 1)
		}
	}
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PATH FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
nm_createPath(path) => nm_createWalk(path, , nm_PathVars())
nm_PathVars(){
	return
	(
	'
	HiveSlot:=' HiveSlot '
	MoveMethod:="' MoveMethod '"
	HiveBees:=' HiveBees '
	KeyDelay:=' KeyDelay '

	CoordMode "Mouse", "Screen"
	CoordMode "Pixel", "Screen"

	nm_gotoRamp() {
		nm_Walk(5, FwdKey)
		nm_Walk(9.2*HiveSlot-4, RightKey)
	}

	nm_gotoCannon() {
		static pBMCannon := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAABsAAAAMAQMAAACpyVQ1AAAABlBMVEUAAAD3//lCqWtQAAAAAXRSTlMAQObYZgAAAEdJREFUeAEBPADD/wDAAGBgAMAAYGAA/gBgYAD+AGBgAMAAYGAAwABgYADAAGBgAMAAYGAAwABgYADAAGBgAMAAYGAAwABgYDdgEn1l8cC/AAAAAElFTkSuQmCC")

		hwnd := GetRobloxHWND()
		GetRobloxClientPos(hwnd)
		SendEvent "{Click " windowX+350 " " windowY+offsetY+100 " 0}"

		success := 0
		Loop 10
		{
			Send "{" SC_Space " down}{" RightKey " down}"
			Sleep 100
			Send "{" SC_Space " up}"
			nm_Walk(2, RightKey)
			nm_Walk(1.5, FwdKey, RightKey)
			Send "{" RightKey " down}"

			DllCall("GetSystemTimeAsFileTime","int64p",&s:=0)
			n := s, f := s+100000000
			while (n < f)
			{
				pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY "|400|125")
				if (Gdip_ImageSearch(pBMScreen, pBMCannon, , , , , , 2, , 2) = 1)
				{
					success := 1, Gdip_DisposeImage(pBMScreen)
					break
				}
				Gdip_DisposeImage(pBMScreen)
				DllCall("GetSystemTimeAsFileTime","int64p",&n)
			}
			Send "{" RightKey " up}"

			if (success = 1) ; check that cannon was not overrun, at the expense of a small delay
			{
				Loop 10
				{
					if (A_Index = 10)
					{
						success := 0
						break
					}
					Sleep 500
					pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY "|400|125")
					if (Gdip_ImageSearch(pBMScreen, pBMCannon, , , , , , 2, , 2) = 1)
					{
						Gdip_DisposeImage(pBMScreen)
						break 2
					}
					else
						nm_Walk(1.5, LeftKey)
					Gdip_DisposeImage(pBMScreen)
				}
			}

			if (success = 0)
			{
				nm_Reset()
				nm_gotoRamp()
			}
		}
		if (success = 0)
			ExitApp
	}

	nm_Reset()
	{
		static hivedown := 0
		static pBMR := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACgAAAAGCAAAAACUM4P3AAAAAnRSTlMAAHaTzTgAAAAXdEVYdFNvZnR3YXJlAFBob3RvRGVtb24gOS4wzRzYMQAAAyZpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0n77u/JyBpZD0nVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkJz8+Cjx4OnhtcG1ldGEgeG1sbnM6eD0nYWRvYmU6bnM6bWV0YS8nIHg6eG1wdGs9J0ltYWdlOjpFeGlmVG9vbCAxMi40NCc+CjxyZGY6UkRGIHhtbG5zOnJkZj0naHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyc+CgogPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9JycKICB4bWxuczpleGlmPSdodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyc+CiAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjQwPC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICA8ZXhpZjpQaXhlbFlEaW1lbnNpb24+NjwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiA8L3JkZjpEZXNjcmlwdGlvbj4KCiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0nJwogIHhtbG5zOnRpZmY9J2h0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvJz4KICA8dGlmZjpJbWFnZUxlbmd0aD42PC90aWZmOkltYWdlTGVuZ3RoPgogIDx0aWZmOkltYWdlV2lkdGg+NDA8L3RpZmY6SW1hZ2VXaWR0aD4KICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgPHRpZmY6WFJlc29sdXRpb24+OTYvMTwvdGlmZjpYUmVzb2x1dGlvbj4KICA8dGlmZjpZUmVzb2x1dGlvbj45Ni8xPC90aWZmOllSZXNvbHV0aW9uPgogPC9yZGY6RGVzY3JpcHRpb24+CjwvcmRmOlJERj4KPC94OnhtcG1ldGE+Cjw/eHBhY2tldCBlbmQ9J3InPz77yGiWAAAAI0lEQVR42mNUYyAOMDJggOUMDAyRmAqXMxAHmBiobjWxngEAj7gC+wwAe1AAAAAASUVORK5CYII=")

		(bitmaps:=Map()).CaseSense := 0
		#include "%A_ScriptDir%\nm_image_assets\reset\bitmaps.ahk"

		success := 0
		hwnd := GetRobloxHWND()
		GetRobloxClientPos(hwnd)
		SendEvent "{Click " windowX+350 " " windowY+offsetY+100 " 0}"

		Loop 10
		{
			DetectHiddenWindows 1
			if WinExist("background.ahk ahk_class AutoHotkey") {
				PostMessage 0x5554, 1, DateDiff(A_NowUTC, "19700101000000", "Seconds")
			}
			DetectHiddenWindows 0
			ActivateRoblox()
			GetRobloxClientPos(hwnd)
			SetKeyDelay 250+KeyDelay
			SendEvent "{" SC_Esc "}{" SC_R "}{" SC_Enter "}"
			SetKeyDelay 100+KeyDelay

			n := 0
			while ((n < 2) && (A_Index <= 80))
			{
				Sleep 100
				pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY "|" windowWidth "|50")
				n += (Gdip_ImageSearch(pBMScreen, pBMR, , , , , , 10) = (n = 0))
				Gdip_DisposeImage(pBMScreen)
			}
			Sleep 1000

			if hivedown
				Send "{" RotDown "}"
			region := windowX "|" windowY+3*windowHeight//4 "|" windowWidth "|" windowHeight//4
			sconf := windowWidth**2//3200
			Loop 4 {
				sleep 250
				pBMScreen := Gdip_BitmapFromScreen(region), s := 0
				for i, k in bitmaps["hive"] {
					s := Max(s, Gdip_ImageSearch(pBMScreen, k, , , , , , 4, , , sconf))
					if (s >= sconf) {						
						Gdip_DisposeImage(pBMScreen)
						success := 1
						Send "{" RotRight " 4}"
						if hivedown
							Send "{" RotUp "}"
						SendEvent "{" ZoomOut " 5}"
						break 3
					}
				}
				Gdip_DisposeImage(pBMScreen)
				Send "{" RotRight " 4}"
				if (A_Index = 2)
				{
					if hivedown := !hivedown
						Send "{" RotDown "}"
					else
						Send "{" RotUp "}"
				}
			}
		}
		for k,v in bitmaps["hive"]
			Gdip_DisposeImage(v)
		if (success = 0)
			ExitApp
	}
	'
	)
}
nm_gotoField(location){
	global HiveConfirmed:=0
	path := paths["gtf"][StrReplace(location, " ")]

	nm_setShiftLock(0)

	nm_createPath(path)
	KeyWait "F14", "D T5 L"
	KeyWait "F14", "T120 L"
	nm_endWalk()
}
nm_walkFrom(field){
	path := paths["wf"][StrReplace(field, " ")]

	nm_setShiftLock(0)

	nm_createPath(path)
	KeyWait "F14", "D T5 L"
	nm_setStatus("Traveling", "Hive")
	KeyWait "F14", "T120 L"
	nm_endWalk()
}
nm_gotoPlanter(location, waitEnd := 1){
	global HiveConfirmed:=0
	path := paths["gtp"][StrReplace(location, " ")]

	nm_setShiftLock(0)

	nm_createPath(path)
	KeyWait "F14", "D T5 L"
	if WaitEnd
	{
		KeyWait "F14", "T120 L"
		nm_endWalk()
	}
}
nm_gotoCollect(location, waitEnd := 1){
	global HiveConfirmed:=0
	path := paths["gtc"][StrReplace(location, " ")]

	nm_setShiftLock(0)

	nm_createPath(path)
	KeyWait "F14", "D T5 L"
	if waitEnd
	{
		KeyWait "F14", "T120 L"
		nm_endWalk()
	}
}
nm_gotoBooster(booster){
	global HiveConfirmed:=0
	path := paths["gtb"][booster]

	nm_setShiftLock(0)

	nm_createPath(path)
	KeyWait "F14", "D T5 L"
	KeyWait "F14", "T120 L"
	nm_endWalk()
}
nm_gotoQuestgiver(giver){
	path := paths["gtq"][giver]
	nm_setShiftLock(0)
	success:=0
	Loop 2
	{
		nm_Reset()

		global HiveConfirmed := 0

		nm_setStatus("Traveling", "Questgiver: " giver)

		nm_createPath(path)
		KeyWait "F14", "D T5 L"
		KeyWait "F14", "T120 L"
		nm_endWalk()

		Loop 2
		{
			Sleep 500
			searchRet := nm_imgSearch("e_button.png",30,"high")
			If (searchRet[1] = 0) {
				success:=1
				SendInput "{" SC_E " down}"
				Sleep 100
				SendInput "{" SC_E " up}"
				Sleep 2000
				hwnd := GetRobloxHWND()
				offsetY := GetYOffset(hwnd)
				Loop 500
				{
					GetRobloxClientPos(hwnd)
					pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-50 "|" windowY+2*windowHeight//3 "|100|" windowHeight//3)
					if (Gdip_ImageSearch(pBMScreen, bitmaps["dialog"], &pos, , , , , 10, , 3) != 1) {
						Gdip_DisposeImage(pBMScreen)
						break
					}
					Gdip_DisposeImage(pBMScreen)
					MouseMove windowX+windowWidth//2, windowY+2*windowHeight//3+SubStr(pos, InStr(pos, ",")+1)-15
					Click
					Sleep 150
				}
				MouseMove windowX+350, windowY+offsetY+100
			}
		}

		global QuestGatherField:="None"
		if(success)
			return
	}
}
ba_planter(){
	global planternames
	global nectarnames
	global CurrentField
	global PlanterName1
	global PlanterName2
	global PlanterName3
	global PlanterField1
	global PlanterField2
	global PlanterField3
	global PlanterHarvestTime1
	global PlanterHarvestTime2
	global PlanterHarvestTime3
	global PlanterNectar1
	global PlanterNectar2
	global PlanterNectar3
	global PlanterEstPercent1
	global PlanterEstPercent2
	global PlanterEstPercent3
	global ComfortingFields, MotivatingFields, SatisfyingFields, RefreshingFields, InvigoratingFields
	global LastComfortingField, LastMotivatingField, LastSatisfyingField, LastRefreshingField, LastInvigoratingField
	global MaxAllowedPlanters
	global GotoPlanterField
	global GatherFieldSipping
	global LostPlanters
	global GatherFieldBoostedStart, LastGlitter
	global PlanterMode
	global HarvestInterval
	global HarvestFullGrown
	global n1priority
	global n2priority
	global n3priority
	global n4priority
	global n5priority
	global n1minPercent
	global n2minPercent
	global n3minPercent
	global n4minPercent
	global n5minPercent
	global PlasticPlanterCheck
	global CandyPlanterCheck
	global BlueClayPlanterCheck
	global RedClayPlanterCheck
	global TackyPlanterCheck
	global PesticidePlanterCheck
	global HeatTreatedPlanterCheck
	global HydroponicPlanterCheck
	global PetalPlanterCheck
	global PaperPlanterCheck
	global TicketPlanterCheck
	global PlanterOfPlentyCheck
	global BambooFieldCheck
	global BlueFlowerFieldCheck
	global CactusFieldCheck
	global CloverFieldCheck
	global CoconutFieldCheck
	global DandelionFieldCheck
	global MountainTopFieldCheck
	global MushroomFieldCheck
	global PepperFieldCheck
	global PineTreeFieldCheck
	global PineappleFieldCheck
	global PumpkinFieldCheck
	global RoseFieldCheck
	global SpiderFieldCheck
	global StrawberryFieldCheck
	global StumpFieldCheck
	global SunflowerFieldCheck
	global PlanterSS1, PlanterSS2, PlanterSS3
	global MPlanterHold1, MPlanterHold2, MPlanterHold3
	global MPlanterSmoking1, MPlanterSmoking2, MPlanterSmoking3
	Loop 3 {
		;reset manual planter disable auto harvest variables to 0
		if (PlanterMode = 2) {
			MPlanterHold%A_Index% := 0
			IniWrite MPlanterHold%A_Index%, "settings\nm_config.ini", "Planters", "MPlanterHold" A_Index
			MPlanterSmoking%A_Index% := 0
			IniWrite MPlanterSmoking%A_Index%, "settings\nm_config.ini", "Planters", "MPlanterSmoking" A_Index
		}
	}
	;skip over planters in this critical timeframe if AFB is active.  It helps avoid the loss of 4x field boost.
	global AFBrollingDice, AFBuseGlitter, AFBuseBooster, AutoFieldBoostActive, FieldLastBoosted, FieldLastBoostedBy, FieldBoostStacks, AutoFieldBoostRefresh, AFBFieldEnable, AFBDiceEnable, AFBGlitterEnable
	if(AutoFieldBoostActive && (FieldLastBoostedBy="dice") && (nowUnix()-FieldLastBoosted)>360 && (nowUnix()-FieldLastBoosted)<900) {
		return
	}
	if (PlanterMode != 2)
		return
	if (nm_NightInterrupt() || nm_MondoInterrupt() || nm_GatherBoostInterrupt())
		return

	; if enabled, take any/all planter screenshots before further planter actions
	If (PlanterSS1 || PlanterSS2 || PlanterSS3)
		nm_planterSS()

	; Collect only due planters. A full nectar bar or a gathering-field change
	; is not a reason to force-harvest every planter producing that nectar.
	Loop 3 {
		i := A_Index
		if PlanterName%i% != "None" && PlanterField%i% != "None" && PlanterHarvestTime%i% <= nowUnix()
			nm_PlanterRecovery.Harvest(i, PlanterName%i%, PlanterField%i%, ba_harvestPlanter)
	}
	ba_PlaceNectarPlanters()
}

nm_AdaptivePlanterInterrupt() {
	global PlanterMode, AdaptivePlanterGatherInterrupt
		, PlanterName1, PlanterName2, PlanterName3, PlanterField1, PlanterField2, PlanterField3
		, PlanterHarvestTime1, PlanterHarvestTime2, PlanterHarvestTime3
	if PlanterMode != 2 || AdaptivePlanterGatherInterrupt != 1
		return false
	current := nowUnix()
	Loop 3 {
		i := A_Index
		if PlanterName%i% != "None" && PlanterField%i% != "None" && PlanterHarvestTime%i% <= current
			&& nm_PlanterRecovery.Ready("Harvest" i, PlanterName%i% ":" PlanterField%i%, current)
			return true
	}
	return false
}

ba_PlaceNectarPlanters() {
	global
	local slots := [], count := 0, maximum := 0, i, name, slot, attempt, values, needs, pending, candidates, blockedFields := Map()
	local nectar, field, fieldKey, planter, preference, mode, decision, result, current, hasSipping, lastField, alternatives, needCandidates, candidate
	for name in planternames
		maximum += %name%Check ? 1 : 0
	maximum := Min(3, MaxAllowedPlanters, maximum)
	Loop 3 {
		if PlanterName%A_Index% = "None"
			slots.Push(A_Index)
		else
			count++
	}
	LostPlanters := ""
	for slot in slots {
		if count >= maximum || !nm_PlanterRecovery.Ready("Placement", "Planters", nowUnix())
			break
		Loop 10 {
			attempt := A_Index
			; Travel/harvesting can take minutes. Refresh observations and occupied
			; slots before each decision instead of crediting a stale sorted list.
			if !nm_OpenMenu()
				return
			try values := nm_ReadNectars()
			catch {
				nm_setStatus("Unconfirmed", "Cannot read nectar levels; planter placement deferred.")
				return
			}
			needs := [], pending := [], candidates := [], current := nowUnix()
			Loop 3 {
				i := A_Index
				if PlanterName%i% != "None" && PlanterNectar%i% != "None"
					pending.Push({nectar: PlanterNectar%i%, at: Max(300, PlanterHarvestTime%i% - current), amount: Max(0, PlanterEstPercent%i%)})
			}
			Loop 5 {
				i := A_Index, nectar := n%i%priority
				if nectar = "None"
					continue
				needs.Push({name: nectar, percent: values[nectar], target: n%i%minPercent, priority: i})
				total%SubStr(nectar, 1, 3)% := values[nectar]
				lastField := Last%nectar%Field, alternatives := false, needCandidates := []
				hasSipping := false
				if GatherFieldSipping && !GotoPlanterField && !HarvestFullGrown {
					for field in %nectar%Fields
						if field = CurrentField {
							fieldKey := StrReplace(field, " ")
							if %fieldKey%FieldCheck
								hasSipping := true
						}
				}
				for field in %nectar%Fields {
					fieldKey := StrReplace(field, " ")
					if !%fieldKey%FieldCheck || blockedFields.Has(field) || field = PlanterField1 || field = PlanterField2 || field = PlanterField3
						|| (hasSipping && field != CurrentField)
						continue
					for preference, planter in %fieldKey%Planters {
						name := planter[1]
						if !%name%Check || InStr(LostPlanters, name) || name = PlanterName1 || name = PlanterName2 || name = PlanterName3
							continue
						if field != lastField
							alternatives := true
						needCandidates.Push({nectar: nectar, field: field, planter: planter,
							preference: (field = lastField ? 100 : 0) + preference})
					}
				}
				; Preserve field rotation when another usable field exists. The
				; growth table assumes no degradation; repeatedly selecting its
				; nominally best field would violate that assumption.
				for candidate in needCandidates
					if !alternatives || candidate.field != lastField
						candidates.Push(candidate)
			}
			mode := HarvestFullGrown ? "full" : AutomaticHarvestInterval ? "auto" : "fixed"
			decision := nm_NectarPlanner.Choose(needs, candidates, pending, mode, HarvestInterval, PlanterBuffer)
			if !decision
				return
			nm_setStatus("Planning", decision.nectar " " Round(decision.percent) "% / target " decision.target "%: " decision.planter[1] " in " decision.field " for " Round(decision.seconds / 3600, 2) "h")
			result := nm_PlanterRecovery.Placement(ba_placePlanter.Bind(decision.field, decision.planter, slot, 0))
			switch result {
				case 1:
					ba_SavePlacedPlanter(decision.field, decision.planter, slot, decision.nectar, decision)
					count++
					break
				case 2:
					blockedFields[decision.field] := true
				case 3:
					nm_OpenMenu()
					return
				case 4:
					; Retry with a fresh route, subject to the same attempt cap.
				default:
					; Only inventory-confirmed missing types are excluded by the
					; placement adapter. Other failures keep their recovery limits.
			}
			if attempt = 10 {
				nm_PlanterRecovery.PlacementFailed()
				return
			}
		}
	}
	nm_OpenMenu()
}

ba_SavePlacedPlanter(fieldName, planter, planterNum, nectar, decision){
	global
	local key, seconds := decision.seconds
	; The chosen timer and estimate share exactly the same duration. Never pull
	; a new planter forward to another slot's deadline or update only the INI.
	nm_PlanterRecovery.Clear("Harvest" planterNum)
	PlanterName%planterNum% := planter[1]
	PlanterField%planterNum% := fieldName
	PlanterNectar%planterNum% := nectar
	PlanterHarvestTime%planterNum% := nowUnix() + seconds
	PlanterEstPercent%planterNum% := Round(decision.amount, 2)
	Last%nectar%Field := fieldName
	for key in ["Name", "Field", "Nectar", "HarvestTime", "EstPercent"]
		IniWrite Planter%key%%planterNum%, "settings\nm_config.ini", "Planters", "Planter" key planterNum
	IniWrite fieldName, "settings\nm_config.ini", "Planters", "Last" nectar "Field"
}
