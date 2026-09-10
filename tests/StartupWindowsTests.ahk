TestNativeStartupDialogs(owner) {
	saved := [], failures := [], recommendations := ["- Set Graphics Quality to LOWEST", "- Turn OFF Inverted Camera"]
	save := (remember) => saved.Push(remember)
	try {
		originalPanel := nm_StartupSettingsDialog.Show(recommendations, "Fixture Roblox", owner.Hwnd, save)
		Require(WinExist("ahk_id " originalPanel.Hwnd), "Settings warning opens a real owned GUI")
		replacementPanel := nm_StartupSettingsDialog.Show(recommendations, "Fixture Roblox", owner.Hwnd, save)
		Require(!nm_StartupSettingsDialog.Accept(originalPanel), "A superseded dialog cannot save through a newer dialog's callbacks")
		ClickStartupButton(replacementPanel["CloseButton"], () => !nm_StartupSettingsDialog.Window)
		Require(saved.Length = 0, "Closing the warning does not silently ignore settings")

		panel := nm_StartupSettingsDialog.Show(recommendations, "Fixture Roblox", owner.Hwnd, save)
		ClickStartupButton(panel["IgnoreButton"], () => !nm_StartupSettingsDialog.Window)
		Require(saved.Length = 1 && !saved[1], "Explicit session override reaches the save callback without persistence")

		panel := nm_StartupSettingsDialog.Show(recommendations, "Fixture Roblox", owner.Hwnd, save, () => false)
		panel["Remember"].Value := 1
		Require(!nm_StartupSettingsDialog.Accept(panel) && saved.Length = 1, "Declined remembered override cannot save or close the dialog")
		nm_StartupSettingsDialog.Close()
		panel := nm_StartupSettingsDialog.Show(recommendations, "Fixture Roblox", owner.Hwnd, save, () => true)
		panel["Remember"].Value := 1
		ClickStartupButton(panel["IgnoreButton"], () => !nm_StartupSettingsDialog.Window)
		Require(saved.Length = 2 && saved[2], "Confirmed remembered override reaches persistence callback")

		panel := nm_StartupSettingsDialog.Show(recommendations, "Fixture Roblox", owner.Hwnd, save,
			() => nm_StartupSettingsDialog.Show(recommendations, "New warning", owner.Hwnd, save))
		panel["Remember"].Value := 1
		Require(!nm_StartupSettingsDialog.Accept(panel) && nm_StartupSettingsDialog.Window != panel && saved.Length = 2,
			"A warning replaced during confirmation cannot apply the old override")
		nm_StartupSettingsDialog.Close()

		panel := nm_StartupSettingsDialog.Show(recommendations, "Fixture Roblox", owner.Hwnd, StartupSaveFailure, () => true, () => failures.Push(1))
		panel["Remember"].Value := 1
		Require(!nm_StartupSettingsDialog.Accept(panel) && nm_StartupSettingsDialog.Window == panel, "Save failure leaves warning open without authorizing startup")
		Require(failures.Length = 1 && saved.Length = 2, "Failed save reports the problem once")
		FileAppend "PASS Windows startup settings dialog integration (" A_PtrSize * 8 "-bit)`n", "*"
	} finally nm_StartupSettingsDialog.Close()
}

ClickStartupButton(control, done) {
	ControlClick control
	deadline := A_TickCount + 2000
	while !done.Call() && A_TickCount < deadline
		Sleep 10
	Require(done.Call(), "Native button click completes its settings dialog action")
}
StartupSaveFailure(*) {
	throw Error("Fixture persistence failure")
}
