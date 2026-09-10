; A fresh per-fight baseline is established from observations, never inferred from
; a saved/manual health value. Samples estimate damage; they do not prove a kill.
class nm_BossHealthSession {
	__New() => (this.Health := 0, this.ObservedAt := 0, this.Revision := 0, this.Busy := false)

	static Consensus(frames) {
		if !(frames is Array) || frames.Length != 5
			return 0
		values := []
		for frame in frames {
			if !(frame is Array)
				continue
			candidates := [], invalid := false
			for value in frame {
				if !IsNumber(value) || value < 0 || value > 100 {
					invalid := true
					break
				}
				; Full bars can be planters. Zero is not evidence of a living target.
				if value > 0 && value < 100
					candidates.Push(value)
			}
			if invalid || candidates.Length != 1
				continue
			value := candidates[1], index := 1
			while index <= values.Length && values[index] < value
				index++
			values.InsertAt(index, value)
		}
		if values.Length < 3
			return 0
		median := values[values.Length // 2 + 1], total := count := 0
		for value in values {
			if Abs(value - median) <= 1
				total += value, count++
		}
		return count >= 3 ? Round(total / count, 2) : 0
	}

	Plan(frames, tick) {
		if !IsNumber(tick) || tick < 0 || (this.Revision && tick <= this.ObservedAt)
			return 0
		health := nm_BossHealthSession.Consensus(frames)
		if !health
			return 0
		; An increase can mean a new target/reset. Establish a new baseline without
		; reporting a negative damage rate or inventing elapsed time across fights.
		baseline := !this.Revision || health > this.Health + 1
		if !baseline && this.Health - health < 2.5
			return 0
		elapsed := baseline ? 0 : tick - this.ObservedAt
		rate := baseline ? 0 : (this.Health - health) * 60000 / elapsed
		return {owner: this, revision: this.Revision, previous: this.Health, health: health,
			tick: tick, elapsedMs: elapsed, rate: rate, baseline: baseline,
			remainingSeconds: baseline ? 0 : health * 60 / rate}
	}

	Commit(plan) {
		if plan.owner != this || plan.revision != this.Revision
			throw Error("Stale boss health observation cannot reset the interval")
		this.Health := plan.health, this.ObservedAt := plan.tick, this.Revision++
	}
}

class nm_BossHealthReporting {
	static Read := nm_HealthDetection
	static Tick := () => DllCall("GetTickCount64", "UInt64")
	static Wait := Sleep

	static Update(bossName, session) {
		if bossName != "Snail" && bossName != "Chick"
			throw ValueError("Unsupported boss health estimate")
		if session.Busy
			return false
		session.Busy := true
		try {
			frames := []
			Loop 5 {
				frames.Push(this.Read.Call())
				if A_Index < 5
					this.Wait.Call(100)
			}
			plan := session.Plan(frames, this.Tick.Call())
			if !plan
				return false
			previousCritical := A_IsCritical
			Critical
			try {
				; Publish persists first. An INI failure leaves the session baseline
				; unchanged and propagates through the existing failure handler.
				nm_PublishBossHealth(bossName, plan.health)
				session.Commit(plan)
			} finally Critical previousCritical
			if plan.baseline
				nm_setStatus("Observed", bossName " health: " plan.health "%`nFresh baseline; waiting for measured damage.")
			else
				nm_setStatus("Detected", "Health`nBoss: " bossName
					"`nPrevious health: " plan.previous "%`nCurrent health: " plan.health "%"
					"`nDamage: " Format("{:.4f}", plan.rate) "% per minute"
					"`nEstimated time remaining: " nm_CombatDuration(plan.remainingSeconds)
					"`nObservation interval: " nm_CombatDuration(plan.elapsedMs / 1000))
			return true
		} finally session.Busy := false
	}
}

nm_KillTimeEstimation(bossName, session) => nm_BossHealthReporting.Update(bossName, session)

nm_CombatDuration(seconds) {
	seconds := Max(0, Round(seconds)), hours := seconds // 3600
	minutes := Mod(seconds // 60, 60), seconds := Mod(seconds, 60)
	return (hours ? hours "h " : "") minutes "m " seconds "s"
}

nm_PublishBossHealth(bossName, health) {
	global InputSnailHealth, InputChickHealth, MainGui, CommandoChickHealth, ChickLevel
	IniWrite health, "settings\nm_config.ini", "Collect", "Input" bossName "Health"
	Input%bossName%Health := health
	MainGui[bossName "HealthText"].Text := Format("{:.2f}", health) "%"
	MainGui[bossName "HealthText"].Opt("+c" Format("0x{1:02x}{2:02x}{3:02x}", Round(Min(3 * (100 - health), 150)), Round(Min(3 * health, 150)), 0) " +Redraw")
	maximum := bossName = "Snail" ? 30000000 : nm_CommandoMaximumHealth(ChickLevel)
	MainGui[bossName "HealthEdit"].Value := Round(maximum * health / 100)
}

; Preserve the existing ten-million fallback for supported levels beyond the
; bundled table. Startup and later health publishing must use the same rule.
nm_CommandoMaximumHealth(level) {
	global CommandoChickHealth
	return CommandoChickHealth.Has(level) ? CommandoChickHealth[level] : 10000000
}
