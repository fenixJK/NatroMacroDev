#Include "RobloxInstallation.ahk"

class nm_SupportReport {
	static Build(includeIssues := false, context := 0) {
		local file
		version := "Unavailable"
		try {
			file := FileOpen("submacros\natro_macro.ahk", "r", "UTF-8")
			try {
				if RegExMatch(file.Read(16384), 'm)^VersionID := "([0-9.]+)"', &match)
					version := match[1]
			} finally file.Close()
		}
		app := nm_DetectRobloxType()
		cpu := "Unavailable", memory := Buffer(64, 0)
		try cpu := RegRead("HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0", "ProcessorNameString")
		NumPut("UInt", 64, memory)
		ram := DllCall("GlobalMemoryStatusEx", "Ptr", memory) ? Round(NumGet(memory, 8, "UInt64") / 1073741824, 1) " GB" : "Unavailable"
		report := "Natro support report`r`nGenerated: " FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss") " UTC`r`n"
		report .= "`r`nRuntime`r`nNatro version: " version "`r`nAHK: " A_AhkVersion " (" A_PtrSize * 8 "-bit)`r`nWindows: " A_OSVersion "`r`nCPU: " Trim(cpu) "`r`nRAM: " ram
		report .= "`r`nScreen: " A_ScreenWidth "x" A_ScreenHeight "`r`nDisplay scale: " Round(A_ScreenDPI * 100 / 96) "%`r`nRoblox installation: " app
		report .= "`r`n`r`nSetup observations`r`n"
		report .= A_ScreenDPI != 96 ? "Display scale differs from the supported 100% setup.`r`n" : "Display scale is 100%.`r`n"
		report .= A_ScreenHeight <= 600 || A_ScreenWidth <= 1300 ? "Screen resolution may be too small for existing routes.`r`n" : "Screen meets the existing resolution check.`r`n"
		if app = RobloxTypes.NotFound || app = RobloxTypes.Custom || app = RobloxTypes.UWP
			report .= "Roblox installation needs a local setup check.`r`n"
		if app = RobloxTypes.Bootstrapper
			report .= "Custom bootstrapper detected; check its settings.`r`n"
		if DllCall("GetSystemMetrics", "Int", 94) & 0x40 && DllCall("GetSystemMetrics", "Int", 95) >= 2
			report .= "Touchscreen is enabled; check the macro's supported input setup.`r`n"
		if context is Map {
			if context.Get("offsetFailed", 0) = 1
				report .= "The main macro reported a recent failed y-offset check.`r`n"
			if RegExMatch(latest := context.Get("latestVersion", ""), "^\d+(\.\d+){1,3}$") && version != "Unavailable" && VerCompare(version, latest) < 0
				report .= "A newer version was found by the main macro's existing update check.`r`n"
		}
		if InStr(EnvGet("SESSIONNAME"), "RDP") {
			minimize := "Unknown"
			try minimize := RegRead("HKLM\Software\Microsoft\Terminal Server Client", "RemoteDesktop_SuppressWhenMinimized")
			report .= minimize = 2 ? "Remote desktop minimize setting is configured.`r`n" : "Remote desktop minimize setting needs a local check.`r`n"
		}
		report .= "These are setup observations, not a live game verification.`r`n"
		report .= includeIssues ? "`r`nRecent issues (bounded, redacted excerpt)`r`n" this.RecentIssues() : "`r`nRecent issues: excluded.`r`n"
		return this.Redact(report)
	}
	static Secrets() {
		local file
		values := []
		for path in ["settings\nm_config.ini", "settings\BotAuth.ini"] {
			try {
				file := FileOpen(path, "r", "UTF-8")
				try data := file.Read(1048576)
				finally file.Close()
				Loop Parse data, "`n", "`r" {
					if RegExMatch(A_LoopField, "^\s*([^;\[=]+)=(.*)$", &match) && RegExMatch(match[1], "i)(token|webhook|server|password|secret|auth|discord.*id|channel.*id)") {
					value := Trim(match[2], " `t" Chr(34))
					if StrLen(value) >= 4
						values.Push(value)
					}
				}
			}
		}
		return values
	}
	static Redact(text, secrets := unset) {
		if !IsSet(secrets)
			secrets := this.Secrets()
		for value in secrets
			if value != ""
				text := StrReplace(text, value, "[redacted]", false)
		for name in ["USERPROFILE", "USERNAME", "COMPUTERNAME"]
			if StrLen(value := EnvGet(name)) >= 3
				text := StrReplace(text, value, "[local identity]", false)
		if StrLen(A_WorkingDir) > 3
			text := StrReplace(text, A_WorkingDir, "[macro directory]", false)
		; Drop whole credential-bearing lines, including partial/malformed values.
		text := RegExReplace(text, "im)^.*(?:token|webhook|password|secret|authorization|cookie|privateServerLinkCode|share\?code|BotAuth|discordUID|ChannelID)[^\r\n]*", "[credential-bearing line removed]")
		text := RegExReplace(text, "i)(?:https?|roblox)://[^\s<>" Chr(34) "]+", "[URL removed]")
		text := RegExReplace(text, "(?<!\d)\d{17,20}(?!\d)", "[identifier removed]")
		text := RegExReplace(text, "i)\b[A-Z]:[\\/][^\r\n]+", "[local path removed]")
		text := RegExReplace(text, "\\\\[^\r\n]+", "[network path removed]")
		return text
	}
	static RecentIssues(path := "settings\debug_log.txt") {
		local file
		try {
			file := FileOpen(path, "r", "UTF-8")
			try {
				start := Max(0, file.Length - 65536)
				file.Pos := start
				data := file.Read(65536)
				if start > 0
					data := InStr(data, "`n") ? SubStr(data, InStr(data, "`n") + 1) : ""
			} finally file.Close()
		} catch
			return "Recent log is unavailable.`r`n"
		lines := []
		Loop Parse this.Redact(data), "`n", "`r" {
			if RegExMatch(A_LoopField, "i)(error|warning|failed|removed)") {
				lines.Push(StrLen(A_LoopField) <= 1024 ? A_LoopField : "[oversized log line omitted]")
				if lines.Length > 10
					lines.RemoveAt(1)
			}
		}
		text := ""
		for line in lines
			text .= line "`r`n"
		return text = "" ? "No recent matching issues in the bounded excerpt.`r`n" : text
	}
}

class nm_SupportPreview {
	static Window := 0
	static Open(context := 0) {
		if this.Window {
			this.Window.Show()
			return
		}
		panel := Gui(, "Support report preview")
		panel.ReportContext := context
		panel.SetFont("s10", "Segoe UI")
		panel.AddText("w700", "Known credentials and local identifiers are removed. Review the text before sharing. Nothing is sent automatically.")
		panel.AddCheckbox("w700 vIssues", "Include redacted recent issues").OnEvent("Click", (*) => this.Refresh(panel))
		panel.AddEdit("w700 r22 ReadOnly -Wrap vReport", nm_SupportReport.Build(false, context))
		panel.AddButton("w130", "Copy report").OnEvent("Click", (*) => this.Copy(panel))
		panel.AddButton("x+12 w130", "Save as text").OnEvent("Click", (*) => this.Save(panel))
		panel.AddButton("x+12 w130", "Close").OnEvent("Click", (*) => this.Close(panel))
		panel.AddText("xm w700 vResult", "")
		panel.OnEvent("Close", (*) => this.Close(panel))
		panel.OnEvent("Escape", (*) => this.Close(panel))
		this.Window := panel
		panel.Show()
	}
	static Refresh(panel) => panel["Report"].Value := nm_SupportReport.Build(!!panel["Issues"].Value, panel.ReportContext)
	static Copy(panel) {
		A_Clipboard := panel["Report"].Value
		panel["Result"].Text := "Copied the displayed report."
	}
	static Save(panel) {
		local file
		if !(path := FileSelect("S16", "natro-support.txt", "Save the displayed report", "Text (*.txt)"))
			return
		try {
			file := FileOpen(path, "w", "UTF-8")
			try file.Write(panel["Report"].Value)
			finally file.Close()
			panel["Result"].Text := "Saved the displayed report."
		} catch
			panel["Result"].Text := "Could not save the report. Choose a writable location."
	}
	static Close(panel) {
		panel.Destroy()
		this.Window := 0
	}
}

nm_SendSupportReport(replyID, includeIssues := false) {
	payload := JSON.stringify(Map("content", "Redacted support report. Review before sharing further.", "allowed_mentions", Map("parse", []),
		"message_reference", Map("message_id", String(replyID), "fail_if_not_exists", JSON.false)))
	discord.CreateFormData(&data, &kind, [Map("name", "payload_json", "content-type", "application/json", "content", payload),
		Map("name", "files[0]", "filename", "natro-support.txt", "content-type", "text/plain; charset=utf-8", "content", nm_SupportReport.Build(includeIssues))])
	return discord.QueueMessage(data, kind,,, "Redacted support report")
}
