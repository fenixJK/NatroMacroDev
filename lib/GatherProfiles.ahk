class nm_GatherProfiles {
	static Numbers := Map("DriftCheck", [0,1], "PatternInvertFB", [0,1], "PatternInvertLR", [0,1], "PatternReps", [1,9],
		"PatternShift", [0,1], "RotateTimes", [1,4], "SprinklerDist", [1,10], "UntilMins", [0,9999], "UntilPack", [5,100])
	static Choices := Map("PatternSize", ["XS","S","M","L","XL"], "ReturnType", ["Walk","Reset"],
		"RotateDirection", ["None","Left","Right"], "SprinklerLoc", ["Center","Upper Left","Upper","Upper Right","Right","Lower Right","Lower","Lower Left","Left"])
	static Keys := ["Name","Pattern","DriftCheck","PatternInvertFB","PatternInvertLR","PatternReps","PatternShift","PatternSize","ReturnType","RotateDirection","RotateTimes","SprinklerDist","SprinklerLoc","UntilMins","UntilPack"]
	static Parse(text, fields, patterns) {
		if StrLen(text) > 16384
			throw ValueError("Gather profile exceeds the 16 KiB text limit")
		text := Trim(text, " `t`r`n")
		if SubStr(text, 1, 1) != "{"
			throw ValueError("Paste a JSON gather profile object")
		quoted := '"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"'
		token := quoted '|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null'
		position := 2, result := Map(), seen := Map()
		seen.CaseSense := false
		Loop {
			if !RegExMatch(text, '\G\s*(' quoted ')\s*:\s*(' token ')\s*([,}])', &part, position)
				throw ValueError("Malformed gather profile or unsupported nested value")
			pair := JSON.parse("{" part[1] ":" part[2] "}", true)
			for key, value in pair {
				if seen.Has(key)
					throw ValueError("Duplicate gather profile property: " key)
				seen[key] := true
				if key = "schemaVersion" {
					if Type(value) != "Integer" || value != 1
						throw ValueError("Unsupported gather profile version")
				} else {
					canonical := this.Choice(key, this.Keys, "property")
					if part[2] = "true" || part[2] = "false" {
						if !this.Numbers.Has(canonical) || this.Numbers[canonical][2] != 1
							throw ValueError("Boolean is not valid for " canonical)
						value := part[2] = "true" ? 1 : 0
					}
					result[canonical] := this.Validate(canonical, value, fields, patterns)
				}
			}
			position += part.Len(0)
			if part[3] = "}" {
				if position <= StrLen(text) || !result.Count
					throw ValueError("Gather profile has trailing text or no settings")
				return result
			}
		}
	}
	static Choice(value, choices, label) {
		if Type(value) = "String"
			for choice in choices
				if value = choice
					return choice
		throw ValueError("Unknown or unavailable gather " label)
	}
	static Validate(key, value, fields, patterns) {
		if key = "Name"
			return this.Choice(value, fields, "field")
		if key = "Pattern"
			return this.Choice(value, patterns, "pattern (check installed patterns)")
		if this.Choices.Has(key)
			return this.Choice(value, this.Choices[key], key)
		if this.Numbers.Has(key) {
			bounds := this.Numbers[key]
			if !IsObject(value) && IsInteger(value) && value >= bounds[1] && value <= bounds[2] && (key != "UntilPack" || Mod(value, 5) = 0)
				return Integer(value)
		}
		throw ValueError("Invalid gather value for " key)
	}
	static Export(values, fields, patterns) {
		result := Map("schemaVersion", 1)
		for key in this.Keys
			result[key] := this.Validate(key, values[key], fields, patterns)
		return JSON.stringify(result, 0)
	}
}

; Main imports hold Critical while this short section transaction runs. Status
; writes use the same OS-owned lock. A crash closes the lock handle automatically.
class nm_GatherStore {
	static Path := "settings\nm_config.ini"
	static Acquire() {
		start := DllCall("GetTickCount64", "UInt64")
		Loop {
			handle := DllCall("CreateFileW", "Str", A_WorkingDir "\settings\.gather-config.lock", "UInt", 0xC0000000, "UInt", 0, "Ptr", 0, "UInt", 4, "UInt", 0x04000080, "Ptr", 0, "Ptr")
			if handle != -1
				return handle
			if A_LastError != 32 || DllCall("GetTickCount64", "UInt64") - start >= 1000
				throw Error("Gather settings are busy or not writable; try again")
			Sleep 10
		}
	}
	static WriteKey(key, value) {
		handle := this.Acquire()
		try IniWrite value, this.Path, "Gather", key
		finally DllCall("CloseHandle", "Ptr", handle)
	}
	static ReadSection() {
		buffer := Buffer(131072, 0)
		length := DllCall("GetPrivateProfileSectionW", "Str", "Gather", "Ptr", buffer, "UInt", 65536, "Str", A_WorkingDir "\" this.Path, "UInt")
		if length >= 65534
			throw Error("Gather settings section exceeds the read limit")
		if !length
			throw Error("Gather settings section is missing or unreadable")
		section := Map(), position := 0
		section.CaseSense := false
		while position < length {
			line := StrGet(buffer.Ptr + position * 2), position += StrLen(line) + 1
			if !(equal := InStr(line, "="))
				throw Error("Malformed existing Gather settings")
			key := SubStr(line, 1, equal - 1)
			if section.Has(key)
				throw Error("Duplicate existing Gather settings")
			section[key] := SubStr(line, equal + 1)
		}
		return section
	}
	static Commit(slot, patch) {
		if !IsInteger(slot) || slot < 1 || slot > 3
			throw ValueError("Invalid gather slot")
		handle := this.Acquire()
		try {
			section := this.ReadSection()
			for key, value in patch
				section["Field" key slot] := value
			if slot = 1
				section["CurrentFieldNum"] := 1
			size := 1
			for key, value in section
				size += StrLen(key) + StrLen(value) + 2
			if size > 65535
				throw Error("Gather settings section exceeds the write limit")
			buffer := Buffer(size * 2, 0), offset := 0
			for key, value in section
				offset += StrPut(key "=" value, buffer.Ptr + offset * 2, "UTF-16")
			if !DllCall("WritePrivateProfileSectionW", "Str", "Gather", "Ptr", buffer, "Str", A_WorkingDir "\" this.Path)
				throw Error("Gather settings could not be saved")
		} finally DllCall("CloseHandle", "Ptr", handle)
	}
}
