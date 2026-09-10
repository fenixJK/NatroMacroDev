nm_ReadNectars() {
	hwnd := GetRobloxHWND(), snapshot := nm_ClientSnapshot(hwnd)
	if !snapshot || !nm_WindowOwnsFocus(hwnd)
		throw Error("Roblox must be visible to read nectar levels")
	offset := GetYOffset(hwnd, &offsetFailed, false), y := offset + 30
	if offsetFailed || y < 0 || snapshot.width < 861 || y + 159 > snapshot.height
		throw Error("Nectar bars are outside the readable client area")
	started := DllCall("GetTickCount64", "UInt64")
	bitmap := Gdip_BitmapFromScreen(snapshot.x "|" snapshot.y + y "|861|159")
	if bitmap <= 0
		throw Error("Cannot capture nectar levels")
	try values := nm_NectarObservation.Read(bitmap)
	finally Gdip_DisposeImage(bitmap)
	if GetRobloxHWND() != hwnd || !nm_WindowOwnsFocus(hwnd) || !nm_SameClient(snapshot, nm_ClientSnapshot(hwnd))
		|| DllCall("GetTickCount64", "UInt64") - started > 1000
		throw Error("Nectar observation became stale")
	return values
}
