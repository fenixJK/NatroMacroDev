#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
if !A_Args.Length || A_Args[1] = 0 {
	panel := Gui(, "Natro fixture")
	panel.AddText(, "Disposable watchdog process fixture")
	panel.Show()
}
OnMessage(0x10, (*) => 0)
Sleep 60000
ExitApp 0
