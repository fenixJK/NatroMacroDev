/***********************************************************
* @description: Functions for automating the Roblox window
* @author SP
***********************************************************/

#Include "WindowGeometry.ahk"

; Updates global variables windowX, windowY, windowWidth, windowHeight
; Optionally takes a known window handle to skip GetRobloxHWND call
; Returns: 1 = usable visible client; 0 = absent, hidden, minimized or invalid
GetRobloxClientPos(hwnd?)
{
    global windowX, windowY, windowWidth, windowHeight
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()

    return nm_PublishClientSnapshot(nm_ClientSnapshot(hwnd))
}

; Returns: hWnd = successful; 0 = window not found
GetRobloxHWND()
{
	if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
		return hwnd
	else if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe"))
    {
        try
            hwnd := ControlGetHwnd("ApplicationFrameInputSinkWindow1")
        catch TargetError
		    hwnd := 0
        return hwnd
    }
	else
		return 0
}

; Finds the y-offset of GUI elements in the current Roblox window
; Image is specific to BSS but can be altered for use in other games
; Optionally takes a known window handle to skip GetRobloxHWND call
; Returns: offset (integer), defaults to 0 on fail (ByRef param fail is then set to 1, else 0)
GetYOffset(hwnd?, &fail?)
{
	static cache := nm_GeometryCache()
	fail := 1
	if !IsSet(hwnd)
		hwnd := GetRobloxHWND()
	snapshot := nm_ClientSnapshot(hwnd)
	if !snapshot || snapshot.width < 120 || snapshot.height < 100 {
		cache.Clear()
		return 0
	}
	if cache.Read(snapshot, DllCall("GetTickCount64", "UInt64"), &offset) {
		fail := 0
		return offset
	}
	cache.Clear()
	if !bitmaps.Has("toppollen") || !bitmaps.Has("toppollenfill") || !ActivateRoblox(hwnd)
		return 0
	Loop 20 {
		if !nm_SameClient(snapshot, nm_ClientSnapshot(hwnd)) || !nm_WindowOwnsFocus(hwnd)
			return 0
		capture := Gdip_BitmapFromScreen(snapshot.x + snapshot.width // 2 "|" snapshot.y "|60|100")
		if capture <= 0
			return 0
		try {
			if Gdip_ImageSearch(capture, bitmaps["toppollen"], &pos, , , , , 20) = 1 {
				xy := StrSplit(pos, ","), x := Integer(xy[1]), y := Integer(xy[2])
				if Gdip_ImageSearch(capture, bitmaps["toppollenfill"], , x, y, x + 41, y + 10, 20) = 0 {
					if !nm_SameClient(snapshot, nm_ClientSnapshot(hwnd)) || !nm_WindowOwnsFocus(hwnd)
						return 0
					offset := y - 14
					cache.Put(snapshot, offset, DllCall("GetTickCount64", "UInt64"))
					fail := 0
					return offset
				}
			}
		} finally Gdip_DisposeImage(capture)
		if A_Index < 20
			Sleep 50
	}
	return 0
}

; Returns: 1 = successful; 0 = TargetError
ActivateRoblox(hwnd?)
{
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()
    if !hwnd || !DllCall("IsWindow", "Ptr", hwnd)
        return 0
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    try WinActivate "ahk_id " (root ? root : hwnd)
    catch
        return 0
    return nm_WindowOwnsFocus(hwnd)
}
