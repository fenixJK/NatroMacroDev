TestNectarPlanner() {
	p := nm_NectarPlanner
	AssertEqual(p.BufferPercent("bad"), 10, "Invalid saved buffer falls back safely")
	AssertEqual(p.BufferPercent(25), 20, "Saved buffer is bounded")
	AssertEqual(p.BufferPercent(0), 0, "Zero reserve remains supported")
	forecast := p.Forecast(10, 50, [{at: 8640, amount: 40}], 8640)
	AssertEqual(forecast.value, 40, "Nectar decays before the pending harvest arrives")
	AssertEqual(forecast.area, (50 ** 3 - 40 ** 3) * 864 / 3, "Future nectar cannot cover the preceding shortage")
	forecast := p.Forecast(95, 90, [{at: 0, amount: 20}, {at: 8640, amount: 20}], 8640)
	AssertEqual(forecast.value, 100, "Every harvest clips at the cap")
	AssertEqual(forecast.waste, 25, "Overflow cannot be banked for later decay")
	AssertEqual(p.Forecast(100, 80, [], 8640).area, 0, "Reserve above target is not a shortage")
	AssertEqual(p.Forecast(0, 50, [], 8640).area, 50 ** 2 * 8640, "Empty bars never decay below zero")
	AssertEqual(p.Forecast(100, 80, [], 86400).area, 80 ** 3 * 864 / 3, "Crossing the target integrates only time below it")

	needs := [NectarNeed("A", 90, 80, 1), NectarNeed("B", 5, 80, 2)]
	candidates := [NectarCandidate("A", "Field A", "Pot A", 1.5), NectarCandidate("B", "Field B", "Pot B", 1.5)]
	choice := p.Choose(needs, candidates, [])
	AssertEqual(choice.nectar, "B", "A low lower-priority bar can win over a healthy first priority")
	Assert(choice.seconds <= 3600, "An almost-empty bar gets an early emergency batch")
	needs := [NectarNeed("A", 5, 80, 1), NectarNeed("B", 5, 80, 2)]
	AssertEqual(p.Choose(needs, candidates, []).nectar, "A", "Equal need keeps configured priority")
	AssertEqual(p.Choose(needs, candidates, [{nectar: "A", at: 300, amount: 90}]).nectar, "B", "Pending delivery redirects the next slot")
	AssertEqual(p.Choose(needs, [candidates[2]], []).nectar, "B", "Unavailable first priority cannot block a usable pair")
	Assert(!p.Choose(needs, [], []), "No allowed pair produces no action")

	candidates := [NectarCandidate("A", "Slow field", "Slow pot", 1), NectarCandidate("A", "Better field", "Better pot", 1.5)]
	AssertEqual(p.Choose([needs[1]], candidates, []).field, "Better field", "Compare yield across fields instead of fixing the field first")
	for mode in ["fixed", "full"] {
		choice := p.Choose([needs[1]], [candidates[1]], [{nectar: "A", at: 300, amount: 5}], mode, 2)
		AssertEqual(choice.seconds, mode = "fixed" ? 7200 : 28800, "An older slot cannot shorten a new planter's timer")
		AssertEqual(choice.amount, choice.seconds / 864, "Pending estimate uses the actual timer duration")
	}
	choice := p.Choose([needs[1]], [NectarCandidate("A", "Short field", "Short pot", 1, 1)], [], "fixed", 2)
	AssertEqual(choice.seconds, 3600, "Fixed interval stops at full growth")
	candidate := NectarCandidate("A", "Fast field", "Fast pot", 1.5), candidate.planter[3] := 2
	choice := p.Choose([needs[1]], [candidate], [], "fixed", 2)
	AssertEqual(choice.amount, 7200 * 3 / 864, "Growth and nectar bonuses both contribute to modeled yield")
	AssertThrows(() => p.Choose([NectarNeed("A", -1, 80, 1)], candidates, []), "Unknown observation cannot become empty nectar")
	AssertThrows(() => p.Choose(needs, candidates, [], "fixed", 0), "Zero interval rejected")
	AssertThrows(() => p.Forecast(101, 80, []), "Impossible percentage rejected")
}

NectarNeed(name, percentage, target, priority) => {name: name, percent: percentage, target: target, priority: priority}
NectarCandidate(nectar, field, name, bonus, hours := 8) => {nectar: nectar, field: field, planter: [name, bonus, 1, hours], preference: 1}

TestNectarObservation() {
	AssertDeliveryError(() => nm_NectarObservation.Read(0), "Failed capture is not zero nectar")
	token := Gdip_Startup(), bitmap := Gdip_CreateBitmap(861, 159)
	try {
		graphics := Gdip_GraphicsFromImage(bitmap)
		try Gdip_GraphicsClear(graphics, 0xff010203)
		finally Gdip_DeleteGraphics(graphics)
		index := 0
		for color, name in nm_NectarObservation.Colors {
			index++
			Loop index = 1 ? 38 : 19
				Gdip_SetPixel(bitmap, index * 100, 50 + A_Index, 0xff000000 | color)
		}
		values := nm_NectarObservation.Read(bitmap)
		AssertEqual(values["Comforting"], 100, "A full bar always initializes the percentage")
		AssertEqual(values["Motivating"], 50, "Half-height bar from the same frame")
		AssertEqual(values.Count, 5, "All nectar values share one capture")
		graphics := Gdip_GraphicsFromImage(bitmap)
		try Gdip_GraphicsClear(graphics, 0xff010203)
		finally Gdip_DeleteGraphics(graphics)
		values := nm_NectarObservation.Read(bitmap)
		AssertEqual(values["Comforting"], 0, "Legacy readable color absence remains zero")
	} finally {
		Gdip_DisposeImage(bitmap)
		Gdip_Shutdown(token)
	}
}

TestNectarSimulation() {
	; Deterministic capacity-feasible model: five equal targets, three slots,
	; 2x effective yield, eight-hour full growth, five minutes per collection.
	; This is a scheduler check, not evidence of Roblox throughput.
	values := [80, 80, 80, 80, 80], pending := [], visits := 0, lowest := 100
	Loop 864 { ; 72 hours in five-minute steps
		tick := A_Index
		Loop 5
			values[A_Index] := Max(0, values[A_Index] - 300 / 864)
		next := []
		for event in pending {
			event.at -= 300
			if event.at <= 0
				values[event.nectar] := Min(100, values[event.nectar] + event.amount)
			else
				next.Push(event)
		}
		pending := next
		while pending.Length < 3 {
			needs := [], candidates := []
			Loop 5 {
				i := A_Index
				needs.Push(NectarNeed(i, values[i], 70, i))
				candidates.Push(NectarCandidate(i, "Model field " i, "Model pot", 2))
			}
			choice := nm_NectarPlanner.Choose(needs, candidates, pending)
			pending.Push({nectar: choice.nectar, at: choice.seconds + 300, amount: choice.amount})
			visits++
		}
		if tick > 576
			for value in values
				lowest := Min(lowest, value)
	}
	Assert(lowest >= 70, "All five modeled bars remain above target in the final day")
	Assert(visits <= 110, "Maintenance does not depend on constant short-batch harvesting")
	FileAppend "Nectar model: 72h, final-day minimum=" Round(lowest, 2) "%, placements=" visits "`n", "*"
}
