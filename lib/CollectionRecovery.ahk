; A missed visit is not a successful collection. Keep recovery metadata separate
; from the legacy Collect cooldown keys. Interaction means the existing routine
; found its prompt and sent input; it does not prove that a reward was received.
class nm_CollectionRecovery {
	static Delay := 300

	static Read(key) {
		if !RegExMatch(key, "^Last[A-Za-z]+$")
			throw ValueError("Invalid collection recovery key")
		values := StrSplit(IniRead("settings\nm_config.ini", "CollectionRecovery", key, ""), "|")
		if values.Length != 3
			return [0, 0, 0]
		for value in values
			if !IsNumber(value) || value < 0
				return [0, 0, 0]
		return values
	}

	static Write(key, values) {
		IniWrite values[1] "|" values[2] "|" values[3], "settings\nm_config.ini", "CollectionRecovery", key
	}

	static Ready(key) {
		retryAfter := this.Read(key)[2], current := nowUnix()
		return retryAfter <= current || retryAfter - current > this.Delay
	}

	static Begin(key) {
		previousCritical := A_IsCritical
		Critical "On"
		try {
			values := this.Read(key), current := nowUnix()
			if values[2] > current && values[2] - current <= this.Delay
				return false
			; Reserve before travel/input, so interruption also leaves a retry delay.
			this.Write(key, [current, current + this.Delay, values[3]])
			return true
		} finally Critical previousCritical
	}

	static Failed(key) {
		values := this.Read(key)
		this.Write(key, [values[1], nowUnix() + this.Delay, values[3]])
		nm_setStatus("Unconfirmed", SubStr(key, 5) ": interaction not found; retry in 5 minutes.")
	}

	static Interacted(key) {
		values := this.Read(key), current := nowUnix()
		; Persist the cooldown before clearing recovery. An interrupted second write
		; can delay a retry, but cannot erase the recorded interaction cooldown.
		IniWrite current, "settings\nm_config.ini", "Collect", key
		this.Write(key, [values[1], 0, current])
		return current
	}
}
