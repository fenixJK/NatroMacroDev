; Dispenser collection routines extracted from natro_macro.ahk.
nm_HoneyDis(){
	global HoneyDisCheck, LastHoneyDis
	if (HoneyDisCheck && (nowUnix()-LastHoneyDis)>3600) { ;1 hour
		if !nm_CollectionRecovery.Begin("LastHoneyDis")
			return
		collected := false
		Loop 2 {
			hwnd := GetRobloxHWND()
			offsetY := GetYOffset(hwnd)
			GetRobloxClientPos(hwnd)
			nm_updateAction("Collect")

			nm_Reset()
			nm_setStatus("Traveling", "Honey Dispenser" ((A_Index > 1) ? " (Attempt 2)" : ""))

			nm_gotoCollect("honeydis")

			searchRet := nm_imgSearch("e_button.png",30,"high")
			If (searchRet[1] = 0) {
				sendinput "{" SC_E " down}"
				Sleep 100
				sendinput "{" SC_E " up}"
				Sleep 500
				LastHoneyDis := nm_CollectionRecovery.Interacted("LastHoneyDis")
				collected := true
				nm_setStatus("Collected", "Honey Dispenser")
				break
			}
		}
		if !collected
			nm_CollectionRecovery.Failed("LastHoneyDis")
	}
}
nm_TreatDis(){
	global TreatDisCheck, LastTreatDis
	if (TreatDisCheck && (nowUnix()-LastTreatDis)>3600) { ;1 hour
		if !nm_CollectionRecovery.Begin("LastTreatDis")
			return
		collected := false
		Loop 2 {
			hwnd := GetRobloxHWND()
			offsetY := GetYOffset(hwnd)
			GetRobloxClientPos(hwnd)
			nm_updateAction("Collect")

			nm_Reset()
			nm_setStatus("Traveling", "Treat Dispenser" ((A_Index > 1) ? " (Attempt 2)" : ""))

			nm_gotoCollect("treatdis")

			searchRet := nm_imgSearch("e_button.png",30,"high")
			If (searchRet[1] = 0) {
				sendinput "{" SC_E " down}"
				Sleep 100
				sendinput "{" SC_E " up}"
				Sleep 500
				LastTreatDis := nm_CollectionRecovery.Interacted("LastTreatDis")
				collected := true
				nm_setStatus("Collected", "Treat Dispenser")
				break
			}
		}
		if !collected
			nm_CollectionRecovery.Failed("LastTreatDis")
	}
}
nm_BlueberryDis(){
	global BlueberryDisCheck, LastBlueberryDis
	if (BlueberryDisCheck && (nowUnix()-LastBlueberryDis)>14400) { ;4 hours
		if !nm_CollectionRecovery.Begin("LastBlueberryDis")
			return
		collected := false
		Loop 2 {
			hwnd := GetRobloxHWND()
			offsetY := GetYOffset(hwnd)
			GetRobloxClientPos(hwnd)
			nm_updateAction("Collect")

			nm_Reset()
			nm_setStatus("Traveling", "Blueberry Dispenser" ((A_Index > 1) ? " (Attempt 2)" : ""))

			nm_gotoCollect("blueberrydis")

			searchRet := nm_imgSearch("e_button.png",30,"high")
			If (searchRet[1] = 0) {
				sendinput "{" SC_E " down}"
				Sleep 100
				sendinput "{" SC_E " up}"
				sleep 500
				LastBlueberryDis := nm_CollectionRecovery.Interacted("LastBlueberryDis")
				collected := true
				nm_setStatus("Collected", "Blueberry Dispenser")
				break
			}
		}
		if !collected
			nm_CollectionRecovery.Failed("LastBlueberryDis")
	}
}
nm_StrawberryDis(){
	global StrawberryDisCheck, LastStrawberryDis
	if (StrawberryDisCheck && (nowUnix()-LastStrawberryDis)>14400) { ;4 hours
		if !nm_CollectionRecovery.Begin("LastStrawberryDis")
			return
		collected := false
		Loop 2 {
			hwnd := GetRobloxHWND()
			offsetY := GetYOffset(hwnd)
			GetRobloxClientPos(hwnd)
			nm_updateAction("Collect")

			nm_Reset()
			nm_setStatus("Traveling", "Strawberry Dispenser" ((A_Index > 1) ? " (Attempt 2)" : ""))

			nm_gotoCollect("strawberrydis")

			searchRet := nm_imgSearch("e_button.png",30,"high")
			If (searchRet[1] = 0) {
				sendinput "{" SC_E " down}"
				Sleep 100
				sendinput "{" SC_E " up}"
				sleep 500
				LastStrawberryDis := nm_CollectionRecovery.Interacted("LastStrawberryDis")
				collected := true
				nm_setStatus("Collected", "Strawberry Dispenser")
				break
			}
		}
		if !collected
			nm_CollectionRecovery.Failed("LastStrawberryDis")
	}
}
nm_CoconutDis(){
	global CoconutDisCheck, LastCoconutDis, CoconutBoosterCheck, BoostChaserCheck
	if (CoconutDisCheck && (nowUnix()-LastCoconutDis)>14400 && !(CoconutBoosterCheck && BoostChaserCheck)) { ;4 hours
		if !nm_CollectionRecovery.Begin("LastCoconutDis")
			return
		collected := false
		Loop 2 {
			hwnd := GetRobloxHWND()
			offsetY := GetYOffset(hwnd)
			GetRobloxClientPos(hwnd)
			nm_updateAction("Collect")

			nm_Reset()
			nm_setStatus("Traveling", "Coconut Dispenser" ((A_Index > 1) ? " (Attempt 2)" : ""))

			nm_gotoCollect("coconutdis")

			searchRet := nm_imgSearch("e_button.png",30,"high")
			If (searchRet[1] = 0) {
				sendinput "{" SC_E " down}"
				Sleep 100
				sendinput "{" SC_E " up}"
				sleep 500
				LastCoconutDis := nm_CollectionRecovery.Interacted("LastCoconutDis")
				collected := true
				nm_setStatus("Collected", "Coconut Dispenser")
				break
			}
		}
		if !collected
			nm_CollectionRecovery.Failed("LastCoconutDis")
	}
}
