; Millisecond intervals use monotonic time. Wall-clock timestamps remain only as
; compatibility markers; accounting and action deadlines do not depend on them.
class nm_ActivityClock {
	__New() {
		this.Phases := Map()
		for name in ["Runtime", "Gather", "Convert"]
			this.Phases[name] := {open: false, running: false, last: 0, elapsed: 0, pending: 0}
	}
	Begin(name, tick) {
		phase := this.Phases[name]
		if phase.open
			return false
		phase.open := phase.running := true
		phase.last := tick, phase.elapsed := 0
		return true
	}
	Update(name, tick) {
		phase := this.Phases[name]
		if phase.running {
			delta := Max(0, tick - phase.last)
			phase.last := Max(tick, phase.last)
			phase.elapsed += delta, phase.pending += delta
		}
	}
	End(name, tick) {
		this.Update(name, tick)
		this.Phases[name].open := this.Phases[name].running := false
	}
	Pause(tick) {
		for name, phase in this.Phases {
			this.Update(name, tick)
			phase.running := false
		}
	}
	Resume(tick) {
		for name, phase in this.Phases {
			if phase.open && !phase.running
				phase.last := tick, phase.running := true
		}
	}
	Stop(tick) {
		for name in this.Phases
			this.End(name, tick)
	}
	Drain(name, tick) {
		this.Update(name, tick)
		phase := this.Phases[name], value := phase.pending / 1000
		phase.pending := 0
		return value
	}
	Delta(name, tick) {
		phase := this.Phases[name]
		return (phase.pending + (phase.running ? Max(0, tick - phase.last) : 0)) / 1000
	}
	Elapsed(name, tick) {
		phase := this.Phases[name]
		return (phase.elapsed + (phase.running ? Max(0, tick - phase.last) : 0)) / 1000
	}
}

class nm_TimeTracking {
	static Clock := nm_ActivityClock()
	static TickSource := 0
	static Tick() => this.TickSource ? this.TickSource.Call() : DllCall("GetTickCount64", "UInt64")
	static Active(name) => this.Clock.Phases[name].running
	static Elapsed(name) => this.Clock.Elapsed(name, this.Tick())
	static Delta(name) => this.Clock.Delta(name, this.Tick())

	static Begin(name) {
		global MacroStartTime, GatherStartTime, ConvertStartTime
		previous := A_IsCritical
		Critical
		try {
			if !this.Clock.Begin(name, this.Tick())
				return false
			switch name {
				case "Runtime": MacroStartTime := nowUnix()
				case "Gather": GatherStartTime := nowUnix()
				case "Convert": ConvertStartTime := nowUnix()
			}
			return true
		} finally Critical previous
	}

	static Run(name, action) {
		if !this.Begin(name)
			throw Error("Overlapping " name " interval")
		try return action.Call()
		finally this.End(name)
	}

	static End(name) => this.Transition("End", name)
	static Pause() => this.Transition("Pause")
	static Resume() => this.Transition("Resume")
	static Stop() => this.Transition("Stop")

	static Transition(operation, name := "") {
		global MacroStartTime, GatherStartTime, ConvertStartTime
		previous := A_IsCritical
		Critical
		try {
			tick := this.Tick()
			if operation = "End"
				this.Clock.End(name, tick)
			else
				this.Clock.%operation%(tick)
			this.Flush(tick)
			for phase, marker in Map("Runtime", "MacroStartTime", "Gather", "GatherStartTime", "Convert", "ConvertStartTime") {
				if !this.Active(phase)
					%marker% := 0
				else if !%marker%
					%marker% := nowUnix()
			}
		} finally Critical previous
	}

	static Flush(tick := unset) {
		global TotalRuntime, SessionRuntime, TotalGatherTime, SessionGatherTime, TotalConvertTime, SessionConvertTime
		previous := A_IsCritical
		Critical
		try {
			if !IsSet(tick)
				tick := this.Tick()
			for phase, suffix in Map("Runtime", "Runtime", "Gather", "GatherTime", "Convert", "ConvertTime") {
				delta := this.Clock.Drain(phase, tick)
				total := "Total" suffix, session := "Session" suffix
				%total% += delta, %session% += delta
				IniWrite %total%, "settings\nm_config.ini", "Status", total
				IniWrite %session%, "settings\nm_config.ini", "Status", session
			}
		} finally Critical previous
	}
}
