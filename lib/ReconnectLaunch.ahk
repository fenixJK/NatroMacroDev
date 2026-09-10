; Canonical targets contain only a known scheme, place and validated server code.
class nm_ReconnectLaunch {
	static Target(kind, type, code) {
		if kind != "deeplink" && kind != "browser"
			throw ValueError("Invalid reconnect launch method")
		if type = "None" || type = "" {
			if kind != "deeplink" || code != ""
				throw ValueError("Invalid public-server launch")
			return "roblox://placeID=1537690962"
		}
		if !RegExMatch(code, "^[A-Za-z0-9]{32}$")
			throw ValueError("Invalid reconnect server code")
		switch type {
			case "LinkCode": return kind = "browser" ? "https://www.roblox.com/games/1537690962/?privateServerLinkCode=" code : "roblox://placeID=1537690962&linkcode=" code
			case "ShareCode": return kind = "browser" ? "https://www.roblox.com/share?code=" code "&type=Server" : "roblox://navigation/share_links?code=" code "&type=Server"
			default: throw ValueError("Invalid reconnect server type")
		}
	}
	static Run(request) {
		target := this.Target(request["kind"], request["type"], request["code"])
		if request["kind"] = "browser" {
			; Ask the user's Explorer shell to launch the URL, preserving ordinary
			; browser behavior when the macro is elevated. This COM path is isolated.
			try this.ShellRun(target)
			catch
				Run target
		} else
			Run target
	}
	static ShellRun(target) {
		shellWindows := ComObject("Shell.Application").Windows
		desktop := shellWindows.FindWindowSW(0, 0, 8, 0, 1)
		tlb := ComObjQuery(desktop, "{4C96BE40-915C-11CF-99D3-00AA004AE837}", "{000214E2-0000-0000-C000-000000000046}")
		ComCall(15, tlb, "ptr*", sv := ComValue(13, 0))
		NumPut("int64", 0x20400, "int64", 0x46000000000000C0, iid := Buffer(16))
		ComCall(15, sv, "uint", 0, "ptr", iid, "ptr*", sfvd := ComValue(9, 0))
		sfvd.Application.ShellExecute(target)
	}
}
