#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
#Warn All, StdOut
noticePath := A_ScriptFullPath "." DllCall("GetCurrentProcessId")
OnMessage(0x5552, PriorityNotice)
OnMessage(0x5557, (*) => FileAppend("ready", noticePath ".barrier"))
fixture := Gui("-DPIScale", "Natro priority fixture")
fixture.Show("NA w100 h80")
PriorityNotice(wParam, lParam, *) {
	if wParam = 366
		FileAppend wParam "|" lParam "`n", noticePath ".notice"
}
