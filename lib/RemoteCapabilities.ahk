; Permissions are local settings, independent of the remotely editable settings
; registry. Re-read at dispatch so revocation does not require a helper restart.
class nm_RemoteCapabilities {
	static Flags := Map("DesktopCapture", 1, "DesktopControl", 2, "FileRead", 4,
		"FileReceive", 8, "System", 16, "Diagnostics", 32, "CustomCommands", 64)
	static Path := "settings\remote_permissions.ini"
	static Read() {
		try value := IniRead(this.Path, "Permissions", "Mask", 0)
		catch
			return 0
		return IsInteger(value) && value >= 0 && value <= 127 ? Integer(value) : 0
	}
	static Save(mask) {
		if !IsInteger(mask) || mask < 0 || mask > 127
			throw ValueError("Invalid remote permission selection")
		IniWrite mask, this.Path, "Permissions", "Mask"
	}
	static Required(params, screenshotMode := "Roblox") {
		name := StrLower(params[1]), subcommand := StrLower(params[2])
		switch name {
			case "send", "click", "close", "activate", "minimise", "minimize": return "DesktopControl"
			case "upload": return "FileRead"
			case "download": return "FileReceive"
			case "restart": return "System"
			case "log", "debug", "debuglog": return "Diagnostics"
			case "ss", "screenshot":
				mode := subcommand = "mode" ? params[3] : screenshotMode
				return StrLower(mode) = "roblox" ? "" : "DesktopCapture"
			case "", "help", "stop", "reload", "pause", "unpause", "start", "rejoin", "keep", "replace",
				"planter", "planters", "timers", "timer", "time", "prefix", "set", "get": return ""
			case "shiftlock", "shrine", "blender", "mm", "memorymatch", "finditem": return ""
			default: return "CustomCommands"
		}
	}
	static Denied(params, screenshotMode := "Roblox") {
		capability := this.Required(params, screenshotMode)
		return capability != "" && !(this.Read() & this.Flags[capability]) ? capability : ""
	}
	static PrivateSetting(name) => RegExMatch(name, "i)(token|webhook|privserver|fallbackserver|password|secret|botauth|discorduidcommands|permission)")
}

class nm_RemotePermissionsWindow {
	static Window := 0
	static Open(*) {
		if this.Window {
			this.Window.Show()
			return
		}
		this.Window := this.Build()
		this.Window.Show("w560")
	}
	static Build() {
		panel := Gui(, "Remote command permissions")
		panel.SetFont("s10", "Segoe UI")
		panel.AddText("w520", "These permissions apply only to the user or role authorized in Discord Settings. Ordinary macro commands remain available. Changes apply to subsequent commands immediately.")
		mask := nm_RemoteCapabilities.Read()
		labels := Map("DesktopCapture", "Desktop screenshots: all monitors, screen, or active window",
			"DesktopControl", "Desktop control: keys, clicks, and control of other windows",
			"FileRead", "File uploads: send individual local files to Discord",
			"FileReceive", "Receive attachments into settings\remote-inbox only",
			"System", "System restart command",
			"Diagnostics", "Send logs and diagnostic reports",
			"CustomCommands", "Run locally installed personal commands")
		for key, flag in nm_RemoteCapabilities.Flags
			panel.AddCheckbox("w520 v" key " Checked" (!!(mask & flag)), labels[key])
		panel.AddText("w520", "Desktop control and personal commands can provide full control of this computer. File uploads and diagnostics can disclose private information. Received attachments are saved only; they are not opened or executed.")
		panel.AddText("w520", "All optional permissions start disabled. Revoking a permission prevents new commands; it cannot undo an action already in progress.")
		panel.AddButton("w130 Default", "Save permissions").OnEvent("Click", (*) => this.Save(panel))
		panel.AddButton("x+12 w130", "Cancel").OnEvent("Click", (*) => this.Close(panel))
		panel.OnEvent("Close", (*) => this.Close(panel))
		panel.OnEvent("Escape", (*) => this.Close(panel))
		return panel
	}
	static Save(panel) {
		mask := 0
		for key, flag in nm_RemoteCapabilities.Flags
			if panel[key].Value
				mask |= flag
		nm_RemoteCapabilities.Save(mask)
		this.Close(panel)
	}
	static Close(panel) {
		panel.Destroy()
		this.Window := 0
	}
}

; Uploading directories used the legacy sender's shell archive command. Remote
; uploads now accept only a single existing file and never execute that path.
nm_RemoteUploadPath(path) {
	attributes := FileExist(path)
	if !attributes || InStr(attributes, "D") || RegExMatch(path, "[*?]")
		throw ValueError("Select one existing file; remote folder uploads are disabled")
	SplitPath path, &name
	if RegExMatch(name, "i)^(nm_config|remote_permissions|BotAuth)\.ini$")
		throw ValueError("This macro settings file cannot be uploaded by a remote command")
	return path
}

nm_RemoteCapture(mode := "Roblox") {
	mode := StrLower(mode)
	if mode != "roblox" && !(nm_RemoteCapabilities.Read() & nm_RemoteCapabilities.Flags["DesktopCapture"])
		return 0
	if mode = "all"
		return Gdip_BitmapFromScreen()
	if mode = "screen"
		return Gdip_BitmapFromScreen(1)
	if mode != "roblox" && mode != "window"
		return 0
	hwnd := mode = "roblox" ? GetRobloxHWND() : WinExist("A")
	snapshot := nm_ClientSnapshot(hwnd)
	if !snapshot || !nm_WindowOwnsFocus(hwnd)
		return 0
	bitmap := Gdip_BitmapFromScreen(snapshot.x "|" snapshot.y "|" snapshot.width "|" snapshot.height)
	if bitmap <= 0
		return 0
	if !nm_WindowOwnsFocus(hwnd) || !nm_SameClient(snapshot, nm_ClientSnapshot(hwnd)) {
		Gdip_DisposeImage(bitmap)
		return 0
	}
	return bitmap
}
