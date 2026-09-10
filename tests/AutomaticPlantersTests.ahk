TestAutomaticPlanters() {
	global
	local oldNow := TestNow, result, calls, choice, key, expected, slot
	TestNectarMode := true
	try {
		NectarAdapterSetup()
		ba_PlaceNectarPlanters()
		AssertEqual(TestNectarCalls.Length, 3, "Production adapter fills three slots")
		AssertEqual(TestNectarReads, 3, "Each accepted placement gets a fresh nectar snapshot")
		Assert(PlanterName1 != PlanterName2 && PlanterName2 != PlanterName3 && PlanterName1 != PlanterName3, "Exclusive planter types remain unique")
		Assert(PlanterField1 != PlanterField2 && PlanterField2 != PlanterField3 && PlanterField1 != PlanterField3, "Occupied fields are not reused")
		Loop 3 {
			slot := A_Index
			AssertEqual(PlanterHarvestTime%slot%, TestNow + 7200, "Fixed timer starts when placement finishes")
			for key in ["Name", "Field", "Nectar", "HarvestTime", "EstPercent"]
				AssertEqual(IniRead("settings\nm_config.ini", "Planters", "Planter" key slot), Planter%key%%slot%, "INI agrees with runtime planter record")
		}
		NectarAdapterSetup()
		PlanterName1 := "PlasticPlanter", PlanterField1 := "Bamboo", PlanterNectar1 := "Comforting", PlanterHarvestTime1 := TestNow + 60, PlanterEstPercent1 := 10
		MaxAllowedPlanters := 2
		ba_PlaceNectarPlanters()
		AssertEqual(TestNectarCalls.Length, 1, "Existing planter counts against the configured maximum")
		AssertEqual(PlanterHarvestTime2, TestNow + 7200, "Nearly due existing planter cannot shorten a new planter")
		AssertEqual(PlanterHarvestTime1, TestNow + 60, "Placement does not retime another slot")
		for result in [0, 2, 3, 4] {
			NectarAdapterSetup(), TestNectarResult := result
			ba_PlaceNectarPlanters()
			Assert(TestNectarCalls.Length <= 10, "Every failure path is bounded")
			AssertEqual(PlanterName1, "None", "Failure does not create a placed record")
			AssertEqual(MaxAllowedPlanters, 3, "Failure preserves configured capacity")
			if result = 2 {
				calls := Map()
				for choice in TestNectarCalls {
					Assert(!calls.Has(choice.field), "Field-capacity rejection is not repeated in the same field")
					calls[choice.field] := true
				}
			}
		}
		NectarAdapterSetup(), MaxAllowedPlanters := 1, GatherFieldSipping := 1
		ba_PlaceNectarPlanters()
		AssertEqual(TestNectarCalls[1].field, "Bamboo", "Enabled sipping favors the gather field for a deficient nectar")
		NectarAdapterSetup(), MaxAllowedPlanters := 1, LastComfortingField := "Bamboo"
		ba_PlaceNectarPlanters()
		AssertEqual(TestNectarCalls[1].field, "Dandelion", "Rotate away from the last field when another usable field exists")
		NectarAdapterSetup(), MaxAllowedPlanters := 1, BambooFieldCheck := 0
		ba_PlaceNectarPlanters()
		Assert(TestNectarCalls[1].field != "Bamboo", "A disabled field cannot be selected")
		NectarAdapterSetup(), MaxAllowedPlanters := 0
		ba_PlaceNectarPlanters()
		AssertEqual(TestNectarCalls.Length, 0, "Zero configured slots prevent placement")
		NectarAdapterSetup(), TestNectarUnknown := true
		ba_PlaceNectarPlanters()
		AssertEqual(TestNectarCalls.Length, 0, "Unreadable nectar levels prevent placement")
		NectarAdapterSetup(), TestNectarMenu := false
		ba_PlaceNectarPlanters()
		AssertEqual(TestNectarReads, 0, "Unconfirmed closed menu prevents observation and input")
		NectarAdapterSetup()
		PlanterName1 := "PlasticPlanter", PlanterField1 := "Bamboo", PlanterHarvestTime1 := TestNow
		Assert(nm_AdaptivePlanterInterrupt(), "Due harvest can interrupt gathering")
		nm_PlanterRecovery.Defer("Harvest1", "PlasticPlanter:Bamboo", TestNow)
		Assert(!nm_AdaptivePlanterInterrupt(), "Retry backoff prevents repeated gathering interruptions")
		TestNow += 300
		Assert(nm_AdaptivePlanterInterrupt(), "Harvest becomes eligible when backoff expires")
		AdaptivePlanterGatherInterrupt := 0
		Assert(!nm_AdaptivePlanterInterrupt(), "User can disable the gather interruption")
		AdaptivePlanterGatherInterrupt := 1, PlanterMode := 1
		Assert(!nm_AdaptivePlanterInterrupt(), "Manual mode does not use the adaptive interrupt")
	} finally {
		TestNectarMode := false, TestNow := oldNow
		nm_PlanterRecovery.Clear("Placement")
		Loop 3
			nm_PlanterRecovery.Clear("Harvest" A_Index)
	}
}

NectarAdapterSetup() {
	global
	local i
	TestNow := 10000, TestNectarCalls := [], TestNectarReads := 0, TestNectarResult := 1, TestNectarUnknown := false, TestNectarMenu := true
	planternames := ["PlasticPlanter", "CandyPlanter", "TicketPlanter"]
	PlasticPlanterCheck := CandyPlanterCheck := TicketPlanterCheck := 1
	ComfortingFields := ["Bamboo", "Dandelion"], MotivatingFields := ["Rose", "Spider"]
	BambooFieldCheck := DandelionFieldCheck := RoseFieldCheck := SpiderFieldCheck := 1
	BambooPlanters := DandelionPlanters := RosePlanters := SpiderPlanters := [["PlasticPlanter", 1, 1, 2], ["CandyPlanter", 1, 1, 4], ["TicketPlanter", 2, 1, 2]]
	LastComfortingField := LastMotivatingField := "None"
	CurrentField := "Bamboo", GotoPlanterField := GatherFieldSipping := HarvestFullGrown := AutomaticHarvestInterval := 0
	HarvestInterval := 2, PlanterBuffer := 10, MaxAllowedPlanters := 3, PlanterMode := 2, AdaptivePlanterGatherInterrupt := 1
	n1priority := "Comforting", n2priority := "Motivating", n3priority := n4priority := n5priority := "None"
	n1minPercent := n2minPercent := 70
	PlanterName1 := PlanterName2 := PlanterName3 := "None"
	PlanterField1 := PlanterField2 := PlanterField3 := "None"
	PlanterHarvestTime1 := PlanterHarvestTime2 := PlanterHarvestTime3 := 2147483647
	Loop 3 {
		i := A_Index
		PlanterName%i% := PlanterField%i% := PlanterNectar%i% := "None"
		PlanterHarvestTime%i% := 2147483647, PlanterEstPercent%i% := 0
		nm_PlanterRecovery.Clear("Harvest" i)
	}
	nm_PlanterRecovery.Clear("Placement")
}

nm_ReadNectars() {
	global TestNectarMode, TestNectarReads, TestNectarUnknown
	if !IsSet(TestNectarMode) || !TestNectarMode
		return UnexpectedObservation()
	TestNectarReads++
	if TestNectarUnknown
		throw Error("Injected unreadable nectar frame")
	return Map("Comforting", 60, "Motivating", 60)
}
nm_OpenMenu(*) {
	global TestNectarMode, TestNectarMenu
	return IsSet(TestNectarMode) && TestNectarMode ? TestNectarMenu : UnexpectedObservation()
}
ba_placePlanter(field, planter, slot, atField) {
	global TestNectarMode, TestNectarCalls, TestNectarResult
	if !IsSet(TestNectarMode) || !TestNectarMode
		return UnexpectedObservation()
	TestNectarCalls.Push({field: field, planter: planter[1], slot: slot})
	return TestNectarResult
}
