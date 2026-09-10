; Pure planner. Percent units follow the existing 24-hour nectar model (864 s/point).
; Modeled yield uses nectar bonus times growth bonus from the existing table.
; Degradation, sipping and live game changes still require observation/calibration.
class nm_NectarPlanner {
	static SecondsPerPercent := 864
	static Horizon := 86400
	static VisitSeconds := 1800 ; amortization penalty to discourage frequent trips; not measured travel

	static BufferPercent(value) => IsInteger(value) ? Max(0, Min(20, value)) : 10

	static ValidatePercent(value) {
		if !IsNumber(value) || value < 0 || value > 100
			throw ValueError("Unknown or invalid nectar percentage")
		return value + 0
	}

	; Integrate squared shortage below target, accounting for decay to zero within a span.
	static Span(value, target, seconds) {
		value := this.ValidatePercent(value)
		seconds := Max(0, seconds)
		start := Max(0, (value - target) * this.SecondsPerPercent)
		finish := Min(seconds, value * this.SecondsPerPercent)
		area := 0
		if finish > start
			area := (Max(0, target - value + finish / this.SecondsPerPercent) ** 3 - Max(0, target - value) ** 3) * this.SecondsPerPercent / 3
		area += target ** 2 * Max(0, seconds - Max(start, finish))
		return {value: Max(0, value - seconds / this.SecondsPerPercent), area: area}
	}

	static Forecast(percentage, target, events, horizon := 86400) {
		value := this.ValidatePercent(percentage), target := this.ValidatePercent(target)
		ordered := [], area := 0, time := 0, waste := 0
		for event in events {
			if !IsNumber(event.at) || !IsNumber(event.amount) || event.amount < 0
				throw ValueError("Invalid pending nectar harvest")
			copy := {at: Max(0, event.at), amount: event.amount}, index := 1
			while index <= ordered.Length && ordered[index].at <= copy.at
				index++
			ordered.InsertAt(index, copy)
		}
		for event in ordered {
			if event.at > horizon
				break
			span := this.Span(value, target, event.at - time)
			area += span.area, value := span.value, time := event.at
			waste += Max(0, value + event.amount - 100)
			value := Min(100, value + event.amount)
		}
		span := this.Span(value, target, horizon - time)
		return {value: span.value, area: area + span.area, waste: waste}
	}

	; Each candidate is an allowed, unoccupied field/type pair. Recompute after
	; every placement so pending deliveries and exclusive planter types matter.
	static Choose(needs, candidates, pending, mode := "auto", fixedHours := 2, reserve := 10) {
		if mode != "auto" && mode != "full" && mode != "fixed"
			throw ValueError("Invalid nectar harvest mode")
		if mode = "fixed" && (!IsNumber(fixedHours) || fixedHours <= 0)
			throw ValueError("Invalid fixed harvest interval")
		best := 0
		for need in needs {
			percentage := this.ValidatePercent(need.percent)
			; Relative buffer retains the Planters branch setting semantics.
			target := Min(100, this.ValidatePercent(need.target) * (1 + this.BufferPercent(reserve) / 100))
			events := []
			for event in pending
				if event.nectar = need.name
					events.Push({at: event.at, amount: event.amount})
			baseline := this.Forecast(percentage, target, events, this.Horizon)
			for candidate in candidates {
				if candidate.nectar != need.name
					continue
				full := Floor(candidate.planter[4] * 3600), bonus := candidate.planter[2] * candidate.planter[3]
				if full <= 0 || !IsNumber(bonus) || bonus <= 0
					continue
				intervals := mode = "auto" ? [7200, 14400, 21600, 28800, full]
					: [mode = "full" ? full : Min(full, Floor(fixedHours * 3600))]
				; Short emergency batches only when the observed bar is near empty.
				if mode = "auto" && percentage <= 10
					intervals.Push(1800, 3600)
				seen := Map()
				for seconds in intervals {
					if seconds <= 0 || seconds > full || seen.Has(seconds)
						continue
					seen[seconds] := true
					amount := seconds * bonus / this.SecondsPerPercent
					trial := events.Clone(), trial.Push({at: seconds, amount: amount})
					forecast := this.Forecast(percentage, target, trial, this.Horizon)
					; Reward useful replenishment per occupied slot-hour. Modest priority
					; weights preserve preference without permanently starving later needs.
					score := Max(0, baseline.area - forecast.area) * (1 + (6 - need.priority) / 10)
						/ (seconds + this.VisitSeconds)
					if !best || score > best.score + 0.000001
						|| (Abs(score - best.score) <= 0.000001 && candidate.preference < best.preference) {
						best := {nectar: need.name, field: candidate.field, planter: candidate.planter,
							seconds: seconds, amount: amount, score: score, preference: candidate.preference,
							percent: percentage, target: need.target}
					}
				}
			}
		}
		return best
	}
}
