class nm_ResetExhausted extends Error {
}

; One character/hive recovery shares its budget across all attempts and waits.
; Blocking native calls and legacy helpers remain cooperative boundaries.
class nm_ResetRecovery {
	__New(clock := unset, sleeper := unset, limitMs := 180000, maximum := 5) {
		if !IsInteger(limitMs) || limitMs <= 0 || !IsInteger(maximum) || maximum <= 0
			throw ValueError("Invalid reset recovery limits")
		this.Clock := IsSet(clock) ? clock : () => DllCall("GetTickCount64", "UInt64")
		this.Sleeper := IsSet(sleeper) ? sleeper : (ms) => Sleep(ms)
		this.Deadline := this.Clock.Call() + limitMs, this.Maximum := maximum
		this.Attempts := 0, this.Stage := "starting", this.Frames := Map()
	}
	Check(stage := "") {
		if stage
			this.Stage := stage
		if this.Clock.Call() >= this.Deadline
			throw nm_ResetExhausted("Hive recovery time limit reached during " this.Stage)
	}
	Run(attempt, cleanup) {
		Loop this.Maximum {
			this.Check("attempt"), this.Attempts++
			try {
				result := attempt.Call(this)
				this.Check()
				if result = 1
					return 1
				if result != 0
					throw nm_ResetExhausted("Hive recovery observation was unknown during " this.Stage)
			} finally {
				try cleanup.Call()
				finally this.Close()
			}
		}
		throw nm_ResetExhausted("Hive recovery exhausted " this.Attempts " attempts during " this.Stage)
	}
	Wait(ms) {
		this.Check()
		this.Sleeper.Call(Max(0, Min(ms, this.Deadline - this.Clock.Call())))
		this.Check()
	}
	WaitFor(predicate, timeoutMs) {
		this.Check(), deadline := Min(this.Deadline, this.Clock.Call() + timeoutMs)
		Loop {
			this.Check()
			if this.Clock.Call() >= deadline
				return false
			matched := predicate.Call()
			this.Check()
			if this.Clock.Call() >= deadline
				return false
			if matched
				return true
			this.Wait(Min(25, deadline - this.Clock.Call()))
		}
	}
	Capture(region) {
		this.Check("screen capture")
		bitmap := Gdip_BitmapFromScreen(region)
		if bitmap <= 0
			throw nm_ResetExhausted("Hive recovery screen capture failed")
		this.Frames[bitmap] := true
		this.Check()
		return bitmap
	}
	Release(bitmap) {
		if this.Frames.Has(bitmap) {
			this.Frames.Delete(bitmap)
			Gdip_DisposeImage(bitmap)
		}
	}
	Close() {
		for bitmap in this.Frames
			Gdip_DisposeImage(bitmap)
		this.Frames.Clear()
	}
}

nm_ResetImageSearch(bitmap, needle, &output := "", x1 := 0, y1 := 0, x2 := 0, y2 := 0, variation := 0, trans := "", direction := 1, instances := 1) {
	result := Gdip_ImageSearch(bitmap, needle, &output, x1, y1, x2, y2, variation, trans, direction, instances)
	if result < 0
		throw nm_ResetExhausted("Hive recovery image search failed")
	return result
}
