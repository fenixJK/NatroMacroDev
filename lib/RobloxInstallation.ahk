; Shared registry-based installation detection; no game input.
nm_GetRobloxUWPPath()
{
	try {
		loop Reg, "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages", "K" {
			if InStr(StrLower(A_LoopRegName),"robloxcorporation") {
				exePath := "C:\Program Files\WindowsApps\" A_LoopRegName "\Windows10Universal.exe"
				if FileExist(exePath)
					return exePath
				exePath := "C:\XboxGames\Roblox\Content\RobloxPlayerBeta.exe"
				if FileExist(exePath)
					return exePath
			}
		}
	}
}
nm_GetRobloxWebPath() => RegRead("HKCR\roblox\shell\open\command")

RobloxTypes := {
	UWP: "UWP Version",
	Bootstrapper: "Bootstrapper (Web)",
	Web: "Web Version",
	Custom: "Custom/Unknown (Web)",
	NotFound: "Not found"
}

nm_DetectRobloxType()
{
	robloxpath := defaultapp := ""

	try robloxpath := nm_GetRobloxWebPath()
	if robloxpath {
		switch {
			case robloxpath ~= "i)[a-z]+strap":
				return RobloxTypes.Bootstrapper
			case InStr(robloxpath, "RobloxPlayerBeta"):
				return RobloxTypes.Web
			case robloxpath:
				return RobloxTypes.Custom
		}
	}

	if nm_GetRobloxUWPPath()
		return RobloxTypes.UWP

	return RobloxTypes.NotFound
}
