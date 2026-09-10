; Cooldowns belong to the sending identity, not to a particular queued message.
; Native queues share monotonic deadlines through Windows session-local mappings.
class nm_DeliveryCooldown {
	__New(shared := false) {
		this.Shared := shared, this.Entries := Map()
	}
	static Key(job) {
		if !job.HasOwnProp("rateKey")
			job.rateKey := nm_DeliveryCooldown.Hash(job.token ? "bot:" job.token : "anonymous")
		return job.rateKey
	}
	static Hash(value) {
		algorithm := 0, input := Buffer(StrPut(value, "UTF-8")), output := Buffer(32)
		StrPut(value, input, "UTF-8")
		if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "PtrP", &algorithm, "Str", "SHA256", "Ptr", 0, "UInt", 0, "Int")
			throw Error("Could not prepare delivery identity")
		try {
			if DllCall("bcrypt\BCryptHash", "Ptr", algorithm, "Ptr", 0, "UInt", 0, "Ptr", input, "UInt", input.Size - 1, "Ptr", output, "UInt", 32, "Int")
				throw Error("Could not hash delivery identity")
			key := ""
			Loop 32
				key .= Format("{:02x}", NumGet(output, A_Index - 1, "UChar"))
			return key
		} finally DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", algorithm, "UInt", 0)
	}
	Entry(job, current) {
		key := nm_DeliveryCooldown.Key(job)
		if !this.Entries.Has(key) {
			if this.Entries.Count >= 128 {
				for oldKey, entry in this.Entries.Clone()
					if !entry.pending && entry.deadline <= current
						this.Entries.Delete(oldKey)
			}
			if this.Entries.Count >= 128
				throw Error("Delivery cooldown capacity reached")
			this.Entries[key] := {key: key, deadline: 0, pending: 0}
		}
		return this.Entries[key]
	}
	Deadline(job, current) {
		entry := this.Entry(job, current)
		if this.Shared {
			try this.Sync(entry)
			catch
				return Max(entry.deadline, current + 100) ; coordination unavailable: do not send
		}
		return entry.deadline
	}
	Defer(job, current, seconds) {
		entry := this.Entry(job, current)
		seconds := IsNumber(seconds) && seconds > 0 ? seconds : 60
		; Saturate pathological durations rather than overflowing into an early send.
		deadline := seconds >= (0x1fffffffffffff - current) / 1000 ? 0x1fffffffffffff : current + Ceil(seconds * 1000)
		entry.deadline := Max(entry.deadline, deadline)
		if this.Shared {
			entry.pending := entry.deadline
			try this.Sync(entry)
		}
		return entry.deadline
	}
	Sync(entry) {
		entry.deadline := Max(entry.deadline, nm_SharedCooldownSlot.Get(entry.key).Advance(entry.pending))
		entry.pending := 0
	}
	Flush() {
		if this.Shared
			for , entry in this.Entries
				if entry.pending
					try this.Sync(entry)
	}
}

class nm_SharedCooldownSlot {
	static Slots := Map()
	static Get(key) {
		if !this.Slots.Has(key) {
			if this.Slots.Count >= 128 {
				current := DllCall("GetTickCount64", "UInt64")
				for oldKey, slot in this.Slots.Clone() {
					try {
						if current - slot.Touched >= 60000 && slot.Advance() <= current {
							slot.Close()
							this.Slots.Delete(oldKey)
						}
					}
				}
			}
			if this.Slots.Count >= 128
				throw Error("Shared delivery cooldown capacity reached")
			this.Slots[key] := nm_SharedCooldownSlot(key)
		}
		return this.Slots[key]
	}
	__New(key) {
		this.Mutex := this.Mapping := this.View := 0, this.Touched := 0
		if !RegExMatch(key, "^[a-f0-9]{64}$")
			throw ValueError("Invalid delivery identity")
		this.Name := "Local\NatroDiscordCooldown-v1-" key
		try {
			this.Mutex := DllCall("CreateMutexW", "Ptr", 0, "Int", false, "Str", this.Name "-lock", "Ptr")
			this.Mapping := DllCall("CreateFileMappingW", "Ptr", -1, "Ptr", 0, "UInt", 4, "UInt", 0, "UInt", 8, "Str", this.Name, "Ptr")
			if !this.Mutex || !this.Mapping
				throw Error("Could not open shared delivery cooldown")
			this.View := DllCall("MapViewOfFile", "Ptr", this.Mapping, "UInt", 6, "UInt", 0, "UInt", 0, "UPtr", 8, "Ptr")
			if !this.View
				throw Error("Could not map shared delivery cooldown")
		} catch as err {
			this.Close()
			throw err
		}
	}
	Advance(proposed := 0) {
		criticalBefore := A_IsCritical
		Critical "On"
		owned := false
		try {
			result := DllCall("WaitForSingleObject", "Ptr", this.Mutex, "UInt", 0, "UInt")
			if result != 0 && result != 0x80
				throw Error("Shared delivery cooldown is busy or unavailable")
			owned := true
			current := DllCall("GetTickCount64", "UInt64"), this.Touched := current
			deadline := Max(NumGet(this.View, "UInt64"), proposed)
			; A writer that died while holding the mutex may have left an uncertain
			; value. Retain it and impose at least a fresh minute of backoff.
			if result = 0x80
				deadline := Max(deadline, current + 60000)
			NumPut("UInt64", deadline, this.View)
			return deadline
		} finally {
			if owned
				DllCall("ReleaseMutex", "Ptr", this.Mutex)
			Critical criticalBefore
		}
	}
	Close() {
		if this.View
			DllCall("UnmapViewOfFile", "Ptr", this.View), this.View := 0
		for field in ["Mapping", "Mutex"]
			if this.%field%
				DllCall("CloseHandle", "Ptr", this.%field%), this.%field% := 0
	}
	__Delete() => this.Close()
}
