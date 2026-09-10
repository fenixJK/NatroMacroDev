#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
; Disposable stand-in for a browser/game that should survive its launch helper.
OnMessage(0x10, (*) => 0)
Sleep 60000
ExitApp 0
