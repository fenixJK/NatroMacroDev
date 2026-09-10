#Include "MenuNavigation.ahk"

; Return 1 only for an observed requested tab state; uncertainty returns 0.
nm_OpenMenu(tab := "", refresh := 0, &outcome?) {
	static busy := false
	outcome := "busy"
	previousCritical := A_IsCritical
	Critical "On"
	try {
		if busy
			return 0
		busy := true
	} finally Critical previousCritical
	try {
		engine := nm_MenuNavigation(nm_MenuSurface())
		result := engine.Run(tab, refresh)
		outcome := engine.Outcome
		return result
	} finally busy := false
}
