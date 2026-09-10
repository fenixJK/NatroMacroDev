#Include "%A_ScriptDir%\..\lib\JSON.ahk"

class nm_GuiScripts {
	static Keys(kind) {
		switch kind {
			case "discord": return ["discordMode", "discordCheck", "webhook", "bottoken", "MainChannelCheck", "MainChannelID", "ReportChannelCheck", "ReportChannelID", "ssCheck", "CriticalSSCheck", "AmuletSSCheck", "MachineSSCheck", "BalloonSSCheck", "ViciousSSCheck", "DeathSSCheck", "PlanterSSCheck", "HoneySSCheck", "criticalCheck", "discordUID", "discordUIDCommands", "CriticalErrorPingCheck", "DisconnectPingCheck", "GameFrozenPingCheck", "PhantomPingCheck", "UnexpectedDeathPingCheck", "EmergencyBalloonPingCheck", "HoneyUpdateSSCheck"]
			case "bee": return []
			case "priority": return ["priorityListNumeric"]
			default: throw ValueError("Unknown GUI worker")
		}
	}
	static Defaults(kind) {
		config := Map()
		for key in this.Keys(kind)
			config[key] := key = "priorityListNumeric" ? "12345678" : RegExMatch(key, "i)^(webhook|bottoken|.*ID.*)$") ? "" : 0
		return config
	}
	static Build(kind, config) {
		if !(config is Map)
			throw TypeError("GUI configuration must be a map")
		for key in this.Keys(kind)
			if !config.Has(key)
				throw ValueError("GUI configuration is incomplete")
		templates := Map("discord", "DiscordSettings", "bee", "AutoJelly", "priority", "PrioritySettings")
		return '#Include "%A_ScriptDir%\lib\JSON.ahk"`nconfig := JSON.parse(' this.Literal(JSON.stringify(config)) ')`n#Include "%A_ScriptDir%\lib\gui\' templates[kind] '.ahk"`n'
	}
	static Literal(value) {
		; Escape one AHK string layer. Config values remain JSON data.
		value := StrReplace(value, Chr(96), Chr(96) Chr(96))
		value := StrReplace(value, Chr(34), Chr(96) Chr(34))
		value := StrReplace(StrReplace(value, Chr(13), Chr(96) "r"), Chr(10), Chr(96) "n")
		return Chr(34) value Chr(34)
	}
}
