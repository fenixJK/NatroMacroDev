#Include "AutoJellySettings.ahk"

class nm_AutoJellyLimitReached extends Error {
}
class nm_AutoJellyRunBudget {
	__New(clicks, minutes, clock := unset) {
		limits := nm_AutoJellySettings.Limits(clicks, minutes)
		this.Maximum := limits.Clicks, this.Minutes := limits.Minutes, this.Used := 0
		this.Clock := IsSet(clock) ? clock : (() => DllCall("GetTickCount64", "UInt64"))
		this.Deadline := this.Clock.Call() + limits.Minutes * 60000
	}
	CheckTime() {
		if this.Clock.Call() >= this.Deadline
			throw nm_AutoJellyLimitReached("Time limit reached (" this.Minutes " minutes).`n" this.Used " click attempts used. Rolling stopped.")
	}
	CheckClick() {
		this.CheckTime()
		if this.Used >= this.Maximum
			throw nm_AutoJellyLimitReached("Click limit reached (" this.Maximum ").`nRolling stopped. Click attempts are not an item count.")
	}
	Reserve() {
		this.CheckClick()
		this.Used++ ; reserve before sending input; an uncertain attempt is never refunded
	}
}

class nm_AutoJellyLimitsDialog {
	static Window := 0, Parent := 0, Saved := 0
	static Open(parent, clicks, minutes, saved) {
		if this.Window {
			WinActivate "ahk_id " this.Window.Hwnd
			return
		}
		limits := nm_AutoJellySettings.Limits(clicks, minutes)
		this.Parent := parent, this.Saved := saved
		try {
			this.Window := panel := Gui("+Owner" parent.Hwnd, "Auto-Jelly run limits")
			panel.SetFont("s10", "Segoe UI")
			panel.AddText("xm w330", "Maximum click attempts (1–1,000,000)")
			panel.AddEdit("xm w330 vClicks Number", limits.Clicks)
			panel.AddText("xm w330", "Maximum elapsed minutes (1–1,440)")
			panel.AddEdit("xm w330 vMinutes Number", limits.Minutes)
			panel.AddText("xm w330", "Stops when either limit is reached.`nA click can consume multiple royal jellies; these limits do not measure items spent.")
			panel.AddText("xm w330 h42 cRed vError", "")
			panel.AddButton("xm w100 Default", "Save").OnEvent("Click", ObjBindMethod(this, "Save"))
			panel.AddButton("x+10 w100", "Cancel").OnEvent("Click", ObjBindMethod(this, "Close"))
			panel.OnEvent("Close", ObjBindMethod(this, "Close"))
			panel.OnEvent("Escape", ObjBindMethod(this, "Close"))
			parent.Opt("+Disabled")
			panel.Show()
		} catch as err {
			this.Close()
			throw err
		}
	}
	static Save(*) {
		if !this.Window
			return false
		try {
			limits := nm_AutoJellySettings.SaveLimits(this.Window["Clicks"].Value, this.Window["Minutes"].Value)
			this.Saved.Call(limits)
			this.Close()
			return true
		} catch as err {
			this.Window["Error"].Text := err.Message
			return false
		}
	}
	static Close(*) {
		panel := this.Window, parent := this.Parent
		this.Window := this.Parent := this.Saved := 0
		if panel
			panel.Destroy()
		if parent {
			try parent.Opt("-Disabled")
			try WinActivate "ahk_id " parent.Hwnd
		}
	}
}
