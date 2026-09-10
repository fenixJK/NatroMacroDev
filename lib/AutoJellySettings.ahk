; Only this schema may publish values into Auto-Jelly's legacy GUI globals.
class nm_AutoJellySettings {
	static Path := "settings\mutations.ini"
	static Schema() {
		sections := Map(), fields := Map()
		sections.CaseSense := false
		sections["mutations"] := "Mutations Ability Gather Convert Energy Movespeed Crit Instant Attack"
		sections["bees"] := "Bomber Brave Bumble Cool Hasty Looker Rad Rascal Stubborn Bubble Bucko Commander Demo Exhausted Fire Frosty Honey Rage Riley Shocked Baby Carpenter Demon Diamond Lion Music Ninja Shy Buoyant Fuzzy Precise Spicy Tadpole Vector selectAll"
		sections["GUI"] := "xPos yPos"
		sections["extrasettings"] := "mythicStop giftedStop"
		sections["limits"] := "RollClickLimit RollMinuteLimit"
		fields.CaseSense := false
		for section, names in sections
			for name in StrSplit(names, " ")
				fields[name] := {name: name, section: section}
		return fields
	}
	static Parse(text, centerX := 0, centerY := 0) {
		if StrLen(text) > 65536
			throw ValueError("Auto-Jelly settings exceed the text limit")
		fields := this.Schema(), values := Map(), seen := Map(), section := ""
		values.CaseSense := seen.CaseSense := false
		for name in fields
			values[name] := name = "xPos" ? centerX : name = "yPos" ? centerY : name = "RollClickLimit" ? 100 : name = "RollMinuteLimit" ? 10 : 0
		Loop Parse text, "`n", "`r" {
			line := Trim(A_LoopField, " `t`r")
			if !line || SubStr(line, 1, 1) = ";"
				continue
			if SubStr(line, 1, 1) = "[" {
				if !RegExMatch(line, "^\[([^\[\]]+)\]$", &match)
					throw ValueError("Malformed Auto-Jelly settings section")
				section := Trim(match[1], " `t")
				continue
			}
			equal := InStr(line, "="), name := Trim(equal ? SubStr(line, 1, equal - 1) : line, " `t")
			if !fields.Has(name) || fields[name].section != section
				continue
			field := fields[name]
			if !equal || seen.Has(name)
				throw ValueError("Missing value or duplicate Auto-Jelly setting: " field.name)
			seen[name] := true
			values[field.name] := this.Validate(field, Trim(SubStr(line, equal + 1), " `t"))
		}
		return values
	}
	static Validate(field, value) {
		if field.section = "GUI" {
			if RegExMatch(value, "^-?\d{1,5}$") && value >= -32768 && value <= 32767
				return Integer(value)
		} else if field.section = "limits" {
			maximum := field.name = "RollClickLimit" ? 1000000 : 1440
			if RegExMatch(value, "^\d{1,7}$") && value >= 1 && value <= maximum
				return Integer(value)
		} else if value == "0" || value == "1"
			return Integer(value)
		throw ValueError("Invalid Auto-Jelly setting: " field.name)
	}
	static Load(centerX := 0, centerY := 0, path := "") {
		if !path
			path := this.Path
		if !FileExist(path)
			return this.Parse("", centerX, centerY)
		input := FileOpen(path, "r")
		try {
			if input.Length > 65536
				throw ValueError("Auto-Jelly settings exceed the 64 KiB file limit")
			return this.Parse(input.Read(65537), centerX, centerY)
		} finally input.Close()
	}
	static Toggle(name, current, path := "") {
		if !path
			path := this.Path
		fields := this.Schema()
		if !fields.Has(name) || fields[name].section = "GUI" || fields[name].section = "limits"
			throw ValueError("Unknown Auto-Jelly selection")
		field := fields[name], next := 1 - this.Validate(field, current)
		; Caller publishes next only after this write succeeds.
		IniWrite next, path, field.section, field.name
		return next
	}
	static Limits(clicks, minutes) {
		fields := this.Schema()
		return {Clicks: this.Validate(fields["RollClickLimit"], clicks), Minutes: this.Validate(fields["RollMinuteLimit"], minutes)}
	}
	static SaveLimits(clicks, minutes, path := "") {
		limits := this.Limits(clicks, minutes)
		; Publish both validated fields with one section write; caller updates UI afterward.
		IniWrite "RollClickLimit=" limits.Clicks "`nRollMinuteLimit=" limits.Minutes, path ? path : this.Path, "limits"
		return limits
	}
}
