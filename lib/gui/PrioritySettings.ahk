#NoTrayIcon
#SingleInstance Force
#MaxThreads 255
#Include "%A_ScriptDir%\lib"
#Include Gdip_All.ahk
#Include "%A_ScriptDir%\lib\GuiGraphics.ahk"
#Include "%A_ScriptDir%\lib\PrioritySettings.ahk"
resources := nm_GuiGraphics()
OnExit(ExitFunc)
DetectHiddenWindows 1

bitmaps := resources.Bitmaps
#Include "%A_ScriptDir%\nm_image_assets\webhook_gui\bitmaps.ahk"

;;config
defaultList := nm_BuildPriorityList("12345678")
try priorityState := nm_PrioritySettings.State(config["priorityListNumeric"])
catch as priorityError {
	FileAppend "Priority settings could not be loaded: " priorityError.Message, "*", "UTF-8-RAW"
	ExitApp 1
}
priorityList := priorityState.Tasks

priorityGui := Gui("-Caption +E0x80000 +E0x8000000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs -DPIScale")
priorityGui.OnEvent("Close", (*) => ExitApp()), priorityGui.OnEvent("Escape", (*) => ExitApp())
priorityGui.Show("NA")

for i in ["moveRegion", "close", "p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p9", "Reset", "ToolTip"]
	priorityGui.AddText("v" i)
priorityGui["Reset"].enabled := false
w:=250, h:=priorityList.Length * 34 + 87
surface := resources.CreateSurface(w, h)
hdc := surface.DC, G := surface.Graphics
Gdip_SetSmoothingMode(G, 2)
Gdip_SetInterpolationMode(G, 2)
UpdateLayeredWindow(priorityGui.hwnd, hdc, A_ScreenWidth//2-w//2,A_ScreenHeight//2-h//2, w, h)

;colors:
backgroundColor := "0xff131416"
textColor := "0xffffffff"
itemsColor := "0xff323942"
accentColors := [
	"0xFFF24646", "0xFFF34F4F", "0xFFF45858", "0xFFF56161", 
	"0xFFF66A6A", "0xFFF77373", "0xFFF87C7C", "0xFFF98585", 
	"0xFFFA8E8E", "0xFFFB9797", "0xFFF9B5B5"
]

nm_priorityGui()
guiReady := true
Msgbox("Warning:`n`nThis option will change the ORDER in which the macro attempts each task, but not necessarily the AMOUNT OF TIME spent on each task.`n`nIf you have enabled any Gather Interrupts, or options requiring interrupts, those will also override the order you specify here. For example:`n- if you enable Vicious Bee or Night Memory Match, it will interrupt gather to attempt these every night time even if you place these lower on the priority list.`n- if you enable Gather Interrupt for Quests or Bug Kills, it will interrupt gather to do these tasks every time they come off cool-down, even if you place them lower on the priority list.`n`nGenerally, the DEFAULT ORDER is recommended in most cases.","Priority list",0x40040)

priorityGui["moveRegion"].move(0, 0, w-42, 30)
priorityGui["close"].move(w-42, 4, 28, 28)
for i,v in priorityList
	priorityGui["p" i].move(15, i*34+3, w-30, 30)
priorityGui["Reset"].move(15, h-50, w-62, 30)
priorityGui["ToolTip"].move(w-45, h-50, 30, 30)
nm_priorityGui(movingItem?, mouseY?, drop?) {
	global priorityList
	local v,i
	;;Title Bar
	Gdip_GraphicsClear(G)
	Gdip_FillRoundedRectanglePath(G, pBrush := Gdip_CreateLineBrushFromRect(0, 0, w, h, 0x00000000, 0x78000000), 14, 6, w-16, h-16, 12), Gdip_DeleteBrush(pBrush)
	pBrush := Gdip_BrushCreateSolid(accentColors[1]), Gdip_FillRoundedRectanglePath(G, pBrush, 8, 0, w-16, 30, 12), Gdip_FillRectangle(G, pBrush, 8, 13, w-16, 20), Gdip_DeleteBrush(pBrush)
	Gdip_DrawImage(G, bitmaps["close"], w-42, 4)
	Gdip_TextToGraphics(G, "Priority List", "x23 y8 s17 cffffffff Bold","Arial", w-16, 30)

	;;Background
	Gdip_FillRectangle(G, pBrush := Gdip_BrushCreateSolid(backgroundColor), 8, 32, w-16, h-80), Gdip_FillRoundedRectanglePath(G, pBrush, 8, h-100, w-16, 84, 12),Gdip_DeleteBrush(pBrush)

	;;Check for update in priority list
	if IsSet(movingItem) && !IsSet(drop) {
		index := ((mouseY > priorityList.Length * 34+3) ? priorityList.Length*34+3 : mouseY < 44 ? 44 : mouseY) // 34
		Gdip_DrawLine(G , pPen:=Gdip_CreatePen(accentColors[1], 2), 15, (index*34+3), w-15,  (index*34+3)), Gdip_DeletePen(pPen)
	}

	lower := 0
	;;Priority List
	for i, v in priorityList {
		if IsSet(movingItem) && movingItem = v && !IsSet(drop) {
			lower := 1
			continue
		}
		groupx := 15, groupy := ((i-=lower)*34)+3, groupw := w-30, grouph := 30
		Gdip_FillRoundedRectangle(G, pBrush := Gdip_BrushCreateSolid(itemsColor), groupx, groupy, groupw, grouph, 8), Gdip_DeleteBrush(pBrush)
		Gdip_TextToGraphics(G, v, "x" groupx+8 " y" groupY + 7 " s15 cffffffff Bolder","Arial")
		Gdip_DrawLine(G, pPen := Gdip_CreatePen(accentColors[i+1], 3), groupw-20, groupy + 10, groupw-5, groupy + 10)
		Gdip_DrawLine(G, pPen, groupw-20, groupy + 15, groupw-5, groupy + 15)
		Gdip_DrawLine(G, pPen, groupw-20, groupy + 20, groupw-5, groupy + 20), Gdip_DeletePen(pPen)
	}
	if IsSet(movingItem) && !IsSet(drop) {
		groupy := (mouseY > priorityList.Length * 34+3) ? priorityList.Length * 34+3 : mouseY < 44 ? 44 : mouseY 
		Gdip_FillRoundedRectangle(G, pBrush := Gdip_BrushCreateSolid("0x99323942"), groupx, groupy, groupw, grouph, 8), Gdip_DeleteBrush(pBrush)
		Gdip_TextToGraphics(G, movingItem, "x" groupx+8 " y" groupY + 7 " s15 c99ffffff Bolder","Arial")
		Gdip_DrawLine(G, pPen := Gdip_CreatePen(accentColors[10], 3), groupw-20, groupy + 10, groupw-5, groupy + 10)
		Gdip_DrawLine(G, pPen, groupw-20, groupy + 15, groupw-5, groupy + 15)
		Gdip_DrawLine(G, pPen, groupw-20, groupy + 20, groupw-5, groupy + 20), Gdip_DeletePen(pPen)
	}
	Gdip_FillRoundedRectangle(G, pBrush := Gdip_BrushCreateSolid(accentColors[5]), 15, h-50, w-62, 30, 8)
	Gdip_FillRoundedRectangle(G, pBrush, w-45, h-50, 30, 30, 8), Gdip_DeleteBrush(pBrush)
	if (default := (priorityList[1] == defaultList[1] && priorityList[2] == defaultList[2] && priorityList[3] == defaultList[3] && priorityList[4] == defaultList[4] && priorityList[5] == defaultList[5] && priorityList[6] == defaultList[6] && priorityList[7] == defaultList[7] && priorityList[8] == defaultList[8]))
		Gdip_FillRoundedRectangle(G, pBrush := Gdip_BrushCreateSolid("0x50000000"), 17, h-48, w-66, 26, 8), Gdip_DeleteBrush(pBrush), priorityGui["Reset"].enabled := false
	else
		priorityGui["Reset"].enabled := true
	Gdip_TextToGraphics(G, "Reset", "x15 y" h-43 " s15 c" (default ? "FFCCCCCC" : "FFFFFFFF") " Bold Center","Arial", w-62)
	Gdip_TextToGraphics(G, "?", "x" w-45 " y" h-43 " s15 cFFFFFFFF Bold Center","Arial", 30)
	UpdateLayeredWindow(priorityGui.hwnd, hdc)
	OnMessage(0x201, WM_LBUTTONDOWN)
}
ObjHasValue(obj,value) {
	for q,o in obj
		if o = value
			return q
	return false
}

WM_LBUTTONDOWN(*) {
	global priorityList
	MouseGetPos ,,,&hCtrl,2
	if !hCtrl
		return
	switch priorityGui[hCtrl].name, 0 {
		case "moveRegion":
			PostMessage(0xA1, 2)
		case "close":
			ExitApp()
		case "Reset":
			nm_SavePriority(12345678)
		case "ToolTip":
			Msgbox("Priority List`r`n`r`nDrag and drop to reorder the priority list.`r`nPress Reset to reset the priority list back to default.`n`nNote:`n - The priority list will not override interrupts, e.g., for bug kills or vicious bee.`n - In one loop each task will be completed.`n - The DEFAULT priority is usually optimal for most players.","Priority List",0x40040)
		default:
			if !RegExMatch(priorityGui[hCtrl].name, "^p([1-8])$", &row)
				return
			MouseGetPos(,&y)
			priorityGui.GetPos(,&wy)
			index := Integer(row[1]), offset := y - wy-(index*34+3)
			y := index*34+3
			started := DllCall("GetTickCount64", "UInt64"), cancelled := false
			ReplaceSystemCursors("IDC_HAND")
			try {
				While GetKeyState("LButton", "P") {
					if DllCall("GetTickCount64", "UInt64") - started >= 15000 || GetKeyState("Escape", "P") {
						cancelled := true
						break
					}
					MouseGetPos(,&y)
					y-=offset + wy
					nm_priorityGui(priorityList[index], y)
					Sleep 15
				}
			} finally ReplaceSystemCursors()
			if !cancelled {
				destination := Max(1, Min(8, y // 34))
				nm_SavePriority(nm_PrioritySettings.Move(priorityState.Order, index, destination).Order)
			} else
				nm_priorityGui()
	}
}
ReplaceSystemCursors(IDC := "")
{
	static IMAGE_CURSOR := 2, SPI_SETCURSORS := 0x57
		, SysCursors := Map(  "IDC_APPSTARTING", 32650
							, "IDC_ARROW"      , 32512
							, "IDC_CROSS"      , 32515
							, "IDC_HAND"       , 32649
							, "IDC_HELP"       , 32651
							, "IDC_IBEAM"      , 32513
							, "IDC_NO"         , 32648
							, "IDC_SIZEALL"    , 32646
							, "IDC_SIZENESW"   , 32643
							, "IDC_SIZENWSE"   , 32642
							, "IDC_SIZEWE"     , 32644
							, "IDC_SIZENS"     , 32645
							, "IDC_UPARROW"    , 32516
							, "IDC_WAIT"       , 32514 )
	if !IDC
		DllCall("SystemParametersInfo", "UInt", SPI_SETCURSORS, "UInt", 0, "UInt", 0, "UInt", 0)
	else
	{
		hCursor := DllCall("LoadCursor", "Ptr", 0, "UInt", SysCursors[IDC], "Ptr")
		for k, v in SysCursors
		{
			hCopy := DllCall("CopyImage", "Ptr", hCursor, "UInt", IMAGE_CURSOR, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
			DllCall("SetSystemCursor", "Ptr", hCopy, "UInt", v)
		}
	}
}
nm_SavePriority(order) {
	global priorityState, priorityList
	try next := nm_PrioritySettings.Commit(order, priorityState.Order)
	catch as err {
		nm_priorityGui()
		MsgBox err.Message, "Could not save priority", 0x40010
		return false
	}
	priorityState := next, priorityList := next.Tasks
	nm_priorityGui()
	nm_PrioritySettings.Notify()
	return true
}

ExitFunc(*)
{
	if IsSet(PriorityGui)
		try PriorityGui.Destroy()
	try resources.Close()
	finally ReplaceSystemCursors()
}
