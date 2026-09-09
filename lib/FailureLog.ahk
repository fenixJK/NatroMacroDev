; A separate file per process avoids contention between the macro and helpers.
class nm_Failures {
	static OnFailure := 0
	static Handling := false

	static Redact(text) {
		text := RegExReplace(text, "i)https://(?:canary\.|ptb\.)?(?:discord|discordapp)\.com/api/webhooks/[^\s" Chr(34) "]+", "[webhook redacted]")
		text := RegExReplace(text, "i)(privateServerLinkCode=|share\?code=)[a-z0-9]+", "$1[redacted]")
		text := RegExReplace(text, "i)(Authorization[ :=]+Bot\s+)[^\s" Chr(34) "]+", "$1[redacted]")
		return text
	}

	static Write(err, context := "", directory := "") {
		if !directory {
			root := FileExist(A_ScriptDir "\submacros\natro_macro.ahk") ? A_ScriptDir : A_ScriptDir "\.."
			directory := root "\settings\errors"
		}
		try {
			DirCreate directory
			name := RegExReplace(A_ScriptName, "[^a-zA-Z0-9_.-]", "_")
			path := directory "\" name "-" DllCall("GetCurrentProcessId") ".log"
			if FileExist(path) && FileGetSize(path) > 1048576
				FileMove path, path ".previous", 1
			entry := FormatTime(A_NowUTC, "yyyy-MM-ddTHH:mm:ssZ") " | " context "`n"
			for property in ["Message", "File", "Line", "What", "Extra", "Stack"]
				if HasProp(err, property)
					entry .= property ": " err.%property% "`n"
			FileAppend this.Redact(entry) "`n", path, "UTF-8"
			return path
		}
		return ""
	}

	static Handle(err, mode) {
		global HideErrors
		if this.Handling
			return 1
		this.Handling := true
		try {
			this.Write(err, "Unhandled exception (" mode ")")
			if IsObject(this.OnFailure)
				try this.OnFailure.Call(err)
		} finally
			this.Handling := false
		; Abort the failing thread. Never resume past an invalid operation.
		return HideErrors ? 1 : 0
	}
}
