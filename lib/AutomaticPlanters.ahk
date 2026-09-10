; Production Planters+ adapter. Game input remains in the existing placement/harvest routines.
nm_AdaptivePlanterInterrupt() {
	global PlanterMode, AdaptivePlanterGatherInterrupt
		, PlanterName1, PlanterName2, PlanterName3, PlanterField1, PlanterField2, PlanterField3
		, PlanterHarvestTime1, PlanterHarvestTime2, PlanterHarvestTime3
	if PlanterMode != 2 || AdaptivePlanterGatherInterrupt != 1
		return false
	current := nowUnix()
	Loop 3 {
		i := A_Index
		if PlanterName%i% != "None" && PlanterField%i% != "None" && PlanterHarvestTime%i% <= current
			&& nm_PlanterRecovery.Ready("Harvest" i, PlanterName%i% ":" PlanterField%i%, current)
			return true
	}
	return false
}

ba_PlaceNectarPlanters() {
	global
	local slots := [], count := 0, maximum := 0, i, name, slot, attempt, values, needs, pending, candidates, blockedFields := Map()
	local nectar, field, fieldKey, planter, preference, mode, decision, result, current, hasSipping, lastField, alternatives, needCandidates, candidate
	for name in planternames
		maximum += %name%Check ? 1 : 0
	maximum := Min(3, MaxAllowedPlanters, maximum)
	Loop 3 {
		if PlanterName%A_Index% = "None"
			slots.Push(A_Index)
		else
			count++
	}
	LostPlanters := ""
	for slot in slots {
		if count >= maximum || !nm_PlanterRecovery.Ready("Placement", "Planters", nowUnix())
			break
		Loop 10 {
			attempt := A_Index
			; Travel/harvesting can take minutes. Refresh observations and occupied
			; slots before each decision instead of crediting a stale sorted list.
			if !nm_OpenMenu()
				return
			try values := nm_ReadNectars()
			catch {
				nm_setStatus("Unconfirmed", "Cannot read nectar levels; planter placement deferred.")
				return
			}
			needs := [], pending := [], candidates := [], current := nowUnix()
			Loop 3 {
				i := A_Index
				if PlanterName%i% != "None" && PlanterNectar%i% != "None"
					pending.Push({nectar: PlanterNectar%i%, at: Max(300, PlanterHarvestTime%i% - current), amount: Max(0, PlanterEstPercent%i%)})
			}
			Loop 5 {
				i := A_Index, nectar := n%i%priority
				if nectar = "None"
					continue
				needs.Push({name: nectar, percent: values[nectar], target: n%i%minPercent, priority: i})
				total%SubStr(nectar, 1, 3)% := values[nectar]
				lastField := Last%nectar%Field, alternatives := false, needCandidates := []
				hasSipping := false
				if GatherFieldSipping && !GotoPlanterField && !HarvestFullGrown {
					for field in %nectar%Fields
						if field = CurrentField {
							fieldKey := StrReplace(field, " ")
							if %fieldKey%FieldCheck
								hasSipping := true
						}
				}
				for field in %nectar%Fields {
					fieldKey := StrReplace(field, " ")
					if !%fieldKey%FieldCheck || blockedFields.Has(field) || field = PlanterField1 || field = PlanterField2 || field = PlanterField3
						|| (hasSipping && field != CurrentField)
						continue
					for preference, planter in %fieldKey%Planters {
						name := planter[1]
						if !%name%Check || InStr(LostPlanters, name) || name = PlanterName1 || name = PlanterName2 || name = PlanterName3
							continue
						if field != lastField
							alternatives := true
						needCandidates.Push({nectar: nectar, field: field, planter: planter,
							preference: (field = lastField ? 100 : 0) + preference})
					}
				}
				; Preserve field rotation when another usable field exists. The
				; growth table assumes no degradation; repeatedly selecting its
				; nominally best field would violate that assumption.
				for candidate in needCandidates
					if !alternatives || candidate.field != lastField
						candidates.Push(candidate)
			}
			mode := HarvestFullGrown ? "full" : AutomaticHarvestInterval ? "auto" : "fixed"
			decision := nm_NectarPlanner.Choose(needs, candidates, pending, mode, HarvestInterval, PlanterBuffer)
			if !decision
				return
			nm_setStatus("Planning", decision.nectar " " Round(decision.percent) "% / target " decision.target "%: " decision.planter[1] " in " decision.field " for " Round(decision.seconds / 3600, 2) "h")
			result := nm_PlanterRecovery.Placement(ba_placePlanter.Bind(decision.field, decision.planter, slot, 0))
			switch result {
				case 1:
					ba_SavePlacedPlanter(decision.field, decision.planter, slot, decision.nectar, decision)
					count++
					break
				case 2:
					blockedFields[decision.field] := true
				case 3:
					nm_OpenMenu()
					return
				case 4:
					; Retry with a fresh route, subject to the same attempt cap.
				default:
					; Only inventory-confirmed missing types are excluded by the
					; placement adapter. Other failures keep their recovery limits.
			}
			if attempt = 10 {
				nm_PlanterRecovery.PlacementFailed()
				return
			}
		}
	}
	nm_OpenMenu()
}

ba_SavePlacedPlanter(fieldName, planter, planterNum, nectar, decision){
	global
	local key, seconds := decision.seconds
	; The chosen timer and estimate share exactly the same duration. Never pull
	; a new planter forward to another slot's deadline or update only the INI.
	nm_PlanterRecovery.Clear("Harvest" planterNum)
	PlanterName%planterNum% := planter[1]
	PlanterField%planterNum% := fieldName
	PlanterNectar%planterNum% := nectar
	PlanterHarvestTime%planterNum% := nowUnix() + seconds
	PlanterEstPercent%planterNum% := Round(decision.amount, 2)
	Last%nectar%Field := fieldName
	for key in ["Name", "Field", "Nectar", "HarvestTime", "EstPercent"]
		IniWrite Planter%key%%planterNum%, "settings\nm_config.ini", "Planters", "Planter" key planterNum
	IniWrite fieldName, "settings\nm_config.ini", "Planters", "Last" nectar "Field"
}
