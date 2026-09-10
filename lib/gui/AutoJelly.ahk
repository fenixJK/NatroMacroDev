/************************************************************************
 * @description Auto-Jelly is a macro for the game Bee Swarm Simulator on Roblox. It automatically rolls bees for mutations and stops when a bee with the desired mutation is found. It also has the ability to stop on mythic and gifted bees.
 * @file auto-jelly.ahk
 * @author ninju | .ninju.
 * @date 2024/07/24
 * @version 0.0.1
 ***********************************************************************/

#SingleInstance Force
#Requires AutoHotkey v2.0
#Warn VarUnset, Off
;=============INCLUDES=============
#Include %A_ScriptDir%\lib\Gdip_All.ahk
#include %A_ScriptDir%\lib\Roblox.ahk
#include %A_ScriptDir%\lib\Gdip_ImageSearch.ahk
#include %A_ScriptDir%\lib\ErrorHandling.ahk
;==================================
SendMode("Event")
CoordMode('Pixel', 'Screen')
CoordMode('Mouse', 'Screen')
;==================================
#Include "%A_ScriptDir%\lib\GuiGraphics.ahk"
#Include "%A_ScriptDir%\lib\AutoJellySafety.ahk"
#Include "%A_ScriptDir%\lib\AutoJellyOcr.ahk"
#Include "%A_ScriptDir%\lib\AutoJellyMouse.ahk"
#Include "%A_ScriptDir%\lib\AutoJellyLimits.ahk"
resources := nm_GuiGraphics()
OnExit((*) => (closefunction()), -1)
stopToggle(*) {
	global stopping := true
}
class __ArrEx extends Array {
	static __New() {
		Super.Prototype.includes := ObjBindMethod(this, 'includes')
	}
	static includes(arr, val) {
		for i, j in arr {
			if j = val
				return i
		}
		return 0
	}
}

if A_ScreenDPI !== 96
	throw Error("This macro requires a display-scale of 100%")
traySetIcon(A_ScriptDir "\nm_image_assets\birb.ico")
#Include "%A_ScriptDir%\lib\AutoJellySettings.ahk"
getConfig() {
	global
	local settings, name, value
	settings := nm_AutoJellySettings.Load(A_ScreenWidth//2-w//2, A_ScreenHeight//2-h//2)
	DirCreate "settings"
	for name, value in settings
		%name% := value
}
;===Dimensions===
w:=500,h:=437
;===Bee Array===
beeArr := ["Bomber", "Brave", "Bumble", "Cool", "Hasty", "Looker", "Rad", "Rascal", "Stubborn", "Bubble", "Bucko", "Commander", "Demo", "Exhausted", "Fire", "Frosty", "Honey", "Rage", "Riley", "Shocked", "Baby", "Carpenter", "Demon", "Diamond", "Lion", "Music", "Ninja", "Shy", "Buoyant", "Fuzzy", "Precise", "Spicy", "Tadpole", "Vector"]
mutationsArr := [
	{name:"Ability", triggers:["rate", "abil", "ity"], full:"AbilityRate"},
	{name:"Gather", triggers:["gath", "herAm"], full:"GatherAmount"},
	{name:"Convert", triggers:["convert", "vertAm"], full:"ConvertAmount"},
	{name:"Instant", triggers:["inst", "antConv"], full:"InstantConversion"},
	{name:"Crit", triggers:["crit", "chance"], full:"CriticalChance"},
	{name:"Attack", triggers:["attack", "att", "ack"], full:"Attack"},
	{name:"Energy", triggers:["energy", "rgy"], full:"Energy"},
	{name:"Movespeed", triggers:["movespeed", "speed", "move"], full:"MoveSpeed"},
]
extrasettings:=[
	{name:"mythicStop", text: "Stop on mythics"},
	{name:"giftedStop", text: "Stop on gifteds"}
]
try getConfig()
catch as settingsError {
	FileAppend "Auto-Jelly settings could not be loaded: " settingsError.Message, "*", "UTF-8-RAW"
	ExitApp 1
}
bitmaps := resources.Bitmaps
#Include "%A_ScriptDir%\nm_image_assets\mutator\bitmaps.ahk"
#Include "%A_ScriptDir%\nm_image_assets\mutatorgui\bitmaps.ahk"
#Include "%A_ScriptDir%\nm_image_assets\offset\bitmaps.ahk"
startGui() {
	global
	local i,j,y,x,surface
	(mgui := Gui("+E" (0x00080000) " +OwnDialogs -Caption -DPIScale", "Auto-Jelly")).OnEvent("Close", ExitApp)
	mgui.Show()
	for i, j in [
		{name:"move", options:"x0 y0 w" w " h36"},
		{name:"selectall", options:"x" w-330 " y220 w40 h18"},
		{name:"mutations", options:"x" w-170 " y220 w40 h18"},
		{name:"close", options:"x" w-40 " y5 w28 h28"},
		{name:"limits", options:"x10 y" h-80 " w" w-20 " h30"},
		{name:"roll", options:"x10 y" h-42 " w" w-56 " h30"},
		{name:"help", options:"x" w-40 " y" h-42 " w28 h28"}
	]
		mgui.AddText("v" j.name " " j.options)
	for i, j in beeArr {
		y := (A_Index-1)//8*1
		mgui.AddText("v" j " x" 10+mod(A_Index-1,8)*60 " y" 50+y*40 " w45 h36")
	}
	for i, j in mutationsArr {
		y := (A_Index-1)//4*1
		mgui.AddText("v" j.name " x" 10+mod(A_Index-1,4)*120 " y" 260+y*25 " w40 h18")
	}
	for i, j in extrasettings {
		x := 10 + (w-12)/extrasettings.length * (i-1), y:=325
		mgui.AddText("v" j.name " x" x " y" y " w40 h18")
	}
	surface := resources.CreateSurface(w, h)
	hDC := surface.DC, G := surface.Graphics
	Gdip_SetSmoothingMode(G, 4)
	Gdip_SetInterpolationMode(G, 7)
	update := UpdateLayeredWindow.Bind(mgui.hwnd, hDC)
	update(xpos < 0 ? 0 : xpos > A_ScreenWidth ? 0 : xpos, ypos < 0 ? 0 : ypos > A_ScreenHeight ? 0 : ypos, w, h)
	hovercontrol := ""
	DrawGUI()
}
startGUI()
mouseUI := nm_AutoJellyMouse(mgui, nm_AutoJellyHover, beeArr)
OnMessage(0x202, (w, l, m, hwnd) => mouseUI.EndClose(hwnd))
OnMessage(0x215, (w, l, m, hwnd) => mouseUI.CaptureChanged(hwnd))
OnMessage(0x20, (w, l, m, hwnd) => mouseUI.Owns(hwnd) ? mouseUI.Cursor(w, l) : "")
OnMessage(0x201, WM_LBUTTONDOWN)
OnMessage(0x200, WM_MOUSEMOVE)
guiReady := true
DrawGUI() {
	Gdip_GraphicsClear(G)
	Gdip_FillRoundedRectanglePath(G, brush := Gdip_BrushCreateSolid(0xFF131416), 2, 2, w-4, h-4, 20), Gdip_DeleteBrush(brush)
	region := Gdip_GetClipRegion(G)
	Gdip_SetClipRect(G, 2, 21, w-2, 30, 4)
	Gdip_FillRoundedRectanglePath(G, brush := Gdip_BrushCreateSolid("0xFFFEC6DF"), 2, 2, w-4, 40, 20)
	Gdip_SetClipRegion(G, region)
	Gdip_FillRectangle(G, brush, 2, 20, w-4, 14)
	Gdip_DeleteBrush(brush), Gdip_DeleteRegion(region)
	Gdip_TextToGraphics(G, "Auto-Jelly", "s20 x20 y5 w460 Near vCenter cff131416", "Comic Sans MS", 460, 30)
	Gdip_DrawImage(G, bitmaps["close"], w-40, 5, 28, 28)
	for i, j in beeArr {
		;bitmaps are w45 h36
		y := (A_Index-1)//8
		bm := hovercontrol = j && (%j% || SelectAll) ? j "bghover" : %j% || SelectAll ? j "bg" : hovercontrol = j ? j "hover" : j
		Gdip_DrawImage(G, bitmaps[bm], 10+mod(A_Index-1,8)*60, 50+y*40, 45, 36)
	}
	;===Switches===
	Gdip_FillRoundedRectanglePath(G, brush := Gdip_BrushCreateSolid("0xFF" . 13*2 . 14*2 . 16*2), w-330, 220, 40, 18, 9), Gdip_DeleteBrush(brush)
	Gdip_FillEllipse(G, brush:=Gdip_BrushCreateSolid("0xFFFEC6DF"), selectAll ? w-310 : w-332, 218, 22, 22)
	Gdip_TextToGraphics(G, "Select All Bees", "s14 x" w-284 " y220 Near vCenter", "Comic Sans MS",, 20, 0, brush), Gdip_DeleteBrush(brush)
	if !SelectAll {
		Gdip_FillEllipse(G, brush:=Gdip_BrushCreateSolid("0xFF" . 13*2 . 14*2 . 16*2), w-330, 220, 18, 18), Gdip_DeleteBrush(brush)
		Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFFCC0000", 2), [[w-325, 225], [w-317, 233]])
		Gdip_DrawLines(G, Pen								  , [[w-325, 233], [w-317, 225]]), Gdip_DeletePen(Pen)
	}
	else
		Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFF006600", 2), [[w-303, 229], [w-300, 232], [w-295, 225]]), Gdip_DeletePen(Pen)
	Gdip_FillRoundedRectanglePath(G, brush := Gdip_BrushCreateSolid("0xFF" . 13*2 . 14*2 . 16*2), w-170, 220, 40, 18, 9), Gdip_DeleteBrush(brush)
	Gdip_FillEllipse(G, brush:=Gdip_BrushCreateSolid("0xFFFEC6DF"), mutations ? w-150 : w-172, 218, 22, 22)
	Gdip_TextToGraphics(G, "Mutations", "s14 x" w-124 " y220 Near vCenter", "Comic Sans MS",, 20, 0, brush), Gdip_DeleteBrush(brush)
	if !mutations {
		Gdip_FillEllipse(G, brush:= Gdip_BrushCreateSolid("0xFF" . 13*2 . 14*2 . 16*2), w-170, 220, 18, 18), Gdip_DeleteBrush(brush)
		Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFFCC0000", 2), [[w-165, 225], [w-157, 233]])
		Gdip_DrawLines(G, Pen								  , [[w-165, 233], [w-157, 225]]), Gdip_DeletePen(Pen)
	}
	else
		Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFF006600", 2), [[w-143, 229], [w-140, 232], [w-135, 225]]), Gdip_DeletePen(Pen)
	For i, j in mutationsArr {
		y := (A_Index-1)//4
		Gdip_FillRoundedRectanglePath(G, brush := Gdip_BrushCreateSolid("0xFF" . 13*2 . 14*2 . 16*2), 10+mod(A_Index-1,4)*120, 260+y*25, 40, 18, 9), Gdip_DeleteBrush(brush)
		Gdip_FillEllipse(G, brush:=Gdip_BrushCreateSolid("0xFFFEC6DF"), (%j.name% ? 3.2 : 1) * 8+mod(A_Index-1,4)*120, 258+y*25, 22, 22), Gdip_DeleteBrush(brush)
		Gdip_TextToGraphics(G, j.name, "s13 x" 56+mod(A_Index-1,4)*120 " y" 260+y*25 " vCenter cfffec6df", "Comic Sans MS", 100, 20)
		if !%j.name% {
			Gdip_FillEllipse(G, brush:=Gdip_BrushCreateSolid("0xFF262832"), x:=10+mod(A_Index-1,4)*120, yp:=258+y*25+2, 18, 18), Gdip_DeleteBrush(brush)
			Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFFCC0000", 2), [[x+5, yp+5 ], [x+13, yp+13]])
			Gdip_DrawLines(G, Pen								  , [[x+5, yp+13], [x+13, yp+5 ]]), Gdip_DeletePen(Pen)
		}
		else
			Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFF006600", 2), [[x:=32.6+mod(A_Index-1,4)*120, yp:=269+y*25], [x+3, yp+3], [x+8, yp-4]]), Gdip_DeletePen(Pen)
	}
	if !mutations
		Gdip_FillRectangle(G, brush:=Gdip_BrushCreateSolid("0x70131416"), 9, 255, w-18, 52), Gdip_DeleteBrush(brush)
	Gdip_DrawLine(G, Pen:=Gdip_CreatePen("0xFFFEC6DF", 2), 10, 315, w-12, 315), Gdip_DeletePen(Pen)
	;two more switches for "stop on mythic" and "stop on gifted"
	for i, j in extrasettings {
		x := 10 + (tw:=(w-12)/extrasettings.length) * (i-1), y:=325
		Gdip_FillRoundedRectanglePath(G, brush:=Gdip_BrushCreateSolid("0xFF262832"), x, y, 40, 18, 9), Gdip_DeleteBrush(brush)
		Gdip_FillEllipse(G, brush:=Gdip_BrushCreateSolid("0xFFFEC6DF"), %j.name% ? x+18 : x-2, y-2, 22, 22)
		Gdip_TextToGraphics(G, j.text, "s14 x" x+46 " y" y " vCenter", "Comic Sans MS", tw,20, 0, brush), Gdip_DeleteBrush(brush)
		if !%j.name% {
			Gdip_FillEllipse(G, brush:=Gdip_BrushCreateSolid("0xFF262832"), x, y, 18, 18), Gdip_deleteBrush(brush)
			Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFFCC0000", 2), [[x+5, y+5 ], [x+13, y+13]])
			Gdip_DrawLines(G, Pen								  , [[x+5, y+13], [x+13, y+5 ]]), Gdip_DeletePen(Pen)
		}
		else
			Gdip_DrawLines(G, Pen:=Gdip_CreatePen("0xFF006600", 2), [[x+25, y+9], [x+28, y+12], [x+33, y+5]]), Gdip_DeletePen(Pen)
	}
	Gdip_TextToGraphics(G, "Limits: " RollClickLimit " clicks / " RollMinuteLimit " min - Edit", "x10 y" h-78 " Center vCenter s13 cfffec6df", "Comic Sans MS", w-20, 26)
	if hovercontrol = "limits"
		Gdip_FillRoundedRectanglePath(G, brush:=Gdip_BrushCreateSolid("0x30FEC6DF"), 10, h-80, w-20, 30, 10), Gdip_DeleteBrush(brush)
	if hovercontrol = "roll"
		Gdip_FillRoundedRectanglePath(G, brush:=Gdip_BrushCreateSolid("0x30FEC6DF"), 10, h-42, w-56, 30, 10), Gdip_DeleteBrush(brush)
	if hovercontrol = "help"
		Gdip_FillRoundedRectanglePath(G, brush:=Gdip_BrushCreateSolid("0x30FEC6DF"), w-40, h-42, 30, 30, 10), Gdip_DeleteBrush(brush)
	Gdip_TextToGraphics(G, "Roll!", "x10 y" h-40 " Center vCenter s15 cfffec6df","Comic Sans MS",w-56, 28)
	Gdip_TextToGraphics(G, "?", "x" w-39 " y" h-40 " Center vCenter s15 cfffec6df","Comic Sans MS",30, 28)
	Gdip_DrawRoundedRectanglePath(G, pen:=Gdip_CreatePen("0xFFFEC6DF", 4), 10, h-42, w-56, 30, 10)
	Gdip_DrawRoundedRectanglePath(G, pen, w-40, h-42, 30, 30, 10), Gdip_DeletePen(pen)
	update()
}
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
	global hovercontrol, mutations, Bomber, Brave, Bumble, Cool, Hasty, Looker, Rad, Rascal
	, Stubborn, Bubble, Bucko, Commander, Demo, Exhausted, Fire, Frosty, Honey, Rage
	, Riley, Shocked, Baby, Carpenter, Demon, Diamond, Lion, Music, Ninja, Shy, Buoyant
	, Fuzzy, Precise, Spicy, Tadpole, Vector, SelectAll, Ability, Gather, Convert, Energy
	, Movespeed, Crit, Instant, Attack, mythicStop, giftedStop
	control := mouseUI.Control(hwnd)
	if !control
		return
	ctrl := control.Hwnd
	switch control.Name, 0 {
		case "move":
			PostMessage 0x00A1, 2, 0,, "ahk_id " mgui.Hwnd
		case "close":
			mouseUI.BeginClose(hwnd)
		case "limits":
			mouseUI.Stop()
			SetTimer nm_AutoJellyEditLimits, -1
		case "roll":
			mouseUI.Stop()
			SetTimer blc_start, -1
		case "help":
			mouseUI.Stop()
			SetTimer nm_AutoJellyHelp, -1
		case "selectAll":
			%mgui[ctrl].name% := nm_AutoJellySettings.Toggle(mgui[ctrl].name, %mgui[ctrl].name%)
		case "Bomber", "Brave", "Bumble", "Cool", "Hasty", "Looker", "Rad", "Rascal", "Stubborn", "Bubble", "Bucko", "Commander", "Demo", "Exhausted", "Fire", "Frosty", "Honey", "Rage", "Riley":
			if !selectAll
				%mgui[ctrl].name% := nm_AutoJellySettings.Toggle(mgui[ctrl].name, %mgui[ctrl].name%)
		case "Shocked", "Baby", "Carpenter", "Demon", "Diamond", "Lion", "Music", "Ninja", "Shy", "Buoyant", "Fuzzy", "Precise", "Spicy", "Tadpole", "Vector":
			if !selectAll
				%mgui[ctrl].name% := nm_AutoJellySettings.Toggle(mgui[ctrl].name, %mgui[ctrl].name%)
		case "giftedStop", "mythicStop":
			%mgui[ctrl].name% := nm_AutoJellySettings.Toggle(mgui[ctrl].name, %mgui[ctrl].name%)
		case "mutations":
			%mgui[ctrl].name% := nm_AutoJellySettings.Toggle(mgui[ctrl].name, %mgui[ctrl].name%)
		default:
			if mutations
				%mgui[ctrl].name% := nm_AutoJellySettings.Toggle(mgui[ctrl].name, %mgui[ctrl].name%)
	}
	DrawGUI()
}
WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
	if mouseUI.Owns(hwnd)
		mouseUI.Move(hwnd)
}
nm_AutoJellyHover(name) {
	global hovercontrol := name
	DrawGUI()
}
nm_AutoJellyHelp() {
	Msgbox("This feature allows you to roll royal jellies until you obtain your specified bees and/or mutations!`n`nTo use:`n- Select the bees and mutations you want`n- Make sure your in-game Auto-Jelly settings are right`n- Put a neonberry on the bee you want to change (if trying `n  to obtain a mutated bee) `n- Use one royal jelly on the bee and click Yes`n- Click on Roll.`n`nRun limits:`n- Click Limits to set maximum clicks and elapsed minutes`n- Either limit stops the run; clicks are not an item count`n`nTo stop: `n- Press the escape key`n`nAdditional options:`n- Stop on Gifteds stops on any gifted bee, `n  ignoring the mutation and your bee selection`n- Stop on Mythics stops on any mythic bee, `n  ignoring the mutation and your bee selection", "Auto-Jelly Help", "0x40040")
}
nm_AutoJellyEditLimits() {
	nm_AutoJellyLimitsDialog.Open(mgui, RollClickLimit, RollMinuteLimit, nm_AutoJellySaveLimits)
}
nm_AutoJellySaveLimits(limits) {
	global RollClickLimit := limits.Clicks, RollMinuteLimit := limits.Minutes
	DrawGUI()
}
blc_start() {
	global stopping
	static running := false
	if running
		return
	running := true, stopping := false, reader := 0
	try {
		Hotkey "~*esc", stopToggle, "On"
		selectedBees := [], selectedMutations := []
		for bee in beeArr
			if %bee% || SelectAll
				selectedBees.Push(bee)
		if !selectedBees.Length
			throw Error("Select at least one bee before starting Auto-Jelly")
		budget := nm_AutoJellyRunBudget(RollClickLimit, RollMinuteLimit)
		if mutations {
			for mutation in mutationsArr
				if %mutation.name%
					selectedMutations.Push(mutation)
			if !selectedMutations.Length
				throw Error("Select at least one mutation or turn off mutation filtering")
			ocrLanguage := nm_AutoJellyObservation.EnglishLanguage(nm_AutoJellyOcr.Languages())
			reader := nm_AutoJellyOcr(ocrLanguage)
		}
		if stopping
			return
		if !KeyWait("LButton", "T2")
			throw Error("Release the mouse button before starting Auto-Jelly")
		if !(hwndRoblox := GetRobloxHWND())
			throw Error("Open Bee Swarm Simulator before starting Auto-Jelly")
		mgui.Hide()
		if !ActivateRoblox(hwndRoblox) || !(anchor := nm_ClientSnapshot(hwndRoblox))
			throw Error("Could not activate the Roblox client")
		yOffset := GetYOffset(hwndRoblox, &offsetFailed, false)
		if offsetFailed
			throw Error("Could not detect the in-game GUI offset. Check graphics settings, language and window visibility.")
		surface := nm_AutoJellySurface(hwndRoblox, yOffset, (*) => stopping, anchor, budget)
		while !stopping {
			surface.Click()
			surface.Wait(800)
			pBitmap := surface.Capture("bee")
			try result := nm_AutoJellyObservation.Identify((key) => Gdip_ImageSearch(pBitmap, bitmaps[key]), beeArr)
			finally Gdip_DisposeImage(pBitmap)
			surface.Check()
			reason := nm_AutoJellyObservation.Reason(result, selectedBees, mythicStop, giftedStop)
			if reason = "mythic" || reason = "gifted" {
				MsgBox "Found a " reason " bee!", "Auto-Jelly", 0x40040
				break
			}
			if reason != "selected"
				continue
			if mutations {
				pBitmap := surface.Capture("mutation"), pEffect := hBitmap := 0
				try {
					pEffect := Gdip_CreateEffect(5, -60, 30)
					if !IsInteger(pEffect) || !pEffect {
						pEffect := 0
						throw Error("Could not create mutation image effect")
					}
					if Gdip_BitmapApplyEffect(pBitmap, pEffect)
						throw Error("Could not prepare the mutation image")
					if !(hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap))
						throw Error("Could not prepare the OCR bitmap")
					text := RegExReplace(reader.ReadBitmap(hBitmap, ObjBindMethod(surface, "Check")), "i)([\r\n\s]|mutation)*")
				} finally {
					if hBitmap
						DllCall("DeleteObject", "Ptr", hBitmap)
					if pEffect
						Gdip_DisposeEffect(pEffect)
					Gdip_DisposeImage(pBitmap)
				}
				surface.Check()
				if !text
					throw Error("Mutation text could not be read; rolling stopped")
				found := false
				for mutation in selectedMutations
					for trigger in mutation.triggers
						if InStr(text, trigger)
							found := true
				if !found
					continue
			}
			if MsgBox("Found a match!`nDo you want to keep this?", "Auto-Jelly", 0x40044) = "Yes"
				break
			; A user declining our own modal explicitly resumes this run. Reacquire
			; that same client, then reject geometry changes before any next click.
			if stopping
				break
			if !ActivateRoblox(hwndRoblox)
				throw Error("Could not resume the Roblox client")
			surface.Check()
		}
	} catch nm_AutoJellyCancelled {
		; Escape is an ordinary stop, not an error dialog.
	} catch as err {
		MsgBox err.Message, "Auto-Jelly stopped", 0x40030
	} finally {
		nm_AutoJellySurface.Release()
		try Hotkey "~*esc", stopToggle, "Off"
		if reader
			try reader.Close()
		try mgui.Show()
		running := false
	}
}
closeFunction(*) {
	global xPos, yPos, stopping
	stopping := true
	nm_AutoJellySurface.Release()
	nm_AutoJellyLimitsDialog.Close()
	try {
		mgui.getPos(&xp, &yp)
		if !(xp < 0) && !(xp > A_ScreenWidth) && !(yp < 0) && !(yp > A_ScreenHeight)
			xPos := xp, yPos := yp
		IniWrite(xpos, ".\settings\mutations.ini", "GUI", "xpos")
		IniWrite(ypos, ".\settings\mutations.ini", "GUI", "ypos")
	}
	if IsSet(mouseUI)
		mouseUI.Close()
	if IsSet(mgui)
		try mgui.Destroy()
	try resources.Close()
}
