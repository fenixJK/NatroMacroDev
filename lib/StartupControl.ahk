; A start request owns its mode from scheduling through the running loop.
class nm_StartSession {
	static Current := 0
	static Reserve(mode) {
		if mode != "local" && mode != "remote" && mode != "automatic"
			throw ValueError("Invalid startup mode")
		criticalBefore := A_IsCritical
		Critical "On"
		try {
			if this.Current
				return 0
			return this.Current := nm_StartSession(mode)
		} finally Critical criticalBefore
	}
	__New(mode) {
		this.Mode := mode, this.Phase := "scheduled", this.Timer := 0
	}
	Execute(action, rejected, unexpected) {
		if nm_StartSession.Current != this || this.Phase != "scheduled"
			return false
		this.Phase := "starting"
		try {
			action.Call(this)
			if this.Phase = "running"
				unexpected.Call(Error("The main macro loop returned unexpectedly"))
		} finally {
			if nm_StartSession.Current == this {
				wasRunning := this.Phase = "running"
				this.Close()
				if !wasRunning
					rejected.Call()
			}
		}
		return true
	}
	MarkRunning() {
		if nm_StartSession.Current != this || this.Phase != "starting"
			throw Error("Startup no longer owns the macro")
		this.Phase := "running"
	}
	Close() {
		if this.Timer
			SetTimer this.Timer, 0
		this.Timer := 0, this.Phase := "closed"
		if nm_StartSession.Current == this
			nm_StartSession.Current := 0
	}
	static Cancel() {
		if this.Current
			this.Current.Close()
	}
	static Running() => this.Current && this.Current.Phase = "running"
}

class nm_StartupSettingsDialog {
	static Window := 0
	static Show(recommendations, platform, owner, save, confirm := unset, failure := unset) {
		this.Close()
		this.Save := save
		this.Confirm := IsSet(confirm) ? confirm : (() => MsgBox("Ignore these Roblox settings for future sessions too?", "Remember override", 0x1034) = "Yes")
		this.Failure := IsSet(failure) ? failure : (() => MsgBox("Could not save the settings override. Correct the file permissions and try again.", "Settings not saved", 0x10))
		this.Window := panel := Gui("+AlwaysOnTop +Owner" owner, "Incorrect Roblox Settings Detected")
		panel.SetFont("s9", "Tahoma")
		panel.AddText("w420", "Detected Roblox installation: " platform)
		panel.AddText("w420", "Correct these settings before starting, or explicitly choose to ignore them:")
		text := ""
		for item in recommendations
			text .= (text ? "`n" : "") item
		panel.AddText("w420 cRed", text)
		panel.AddCheckbox("w420 vRemember", "Remember this override for future sessions")
		panel.AddButton("w150 vIgnoreButton", "Ignore for this session").OnEvent("Click", (*) => this.Accept(panel))
		panel.AddButton("x+10 w100 Default vCloseButton", "Close").OnEvent("Click", (*) => this.Close(panel))
		panel.OnEvent("Close", (*) => this.Close(panel))
		panel.Show("AutoSize Center")
		return panel
	}
	static Accept(panel) {
		if this.Window != panel
			return false
		remember := !!panel["Remember"].Value
		if remember && !this.Confirm.Call()
			return false
		if this.Window != panel
			return false
		try this.Save.Call(remember)
		catch {
			this.Failure.Call()
			return false
		}
		this.Close(panel)
		return true
	}
	static Close(panel := 0, *) {
		if this.Window && (!panel || this.Window == panel) {
			this.Window.Destroy()
			this.Window := 0
		}
	}
}

nm_IgnoreStartupSettings(remember) {
	global IgnoreIncorrectRobloxSettings
	if remember
		IniWrite 1, "settings\nm_config.ini", "Settings", "IgnoreIncorrectRobloxSettings"
	IgnoreIncorrectRobloxSettings := 1
}
