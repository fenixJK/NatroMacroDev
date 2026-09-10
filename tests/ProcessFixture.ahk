#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
channel := nm_ProcessChannel(A_Args[1])
request := channel.Read()
if request["mode"] = "echo" {
	channel.Complete(request["text"] == 'Unicode Ω " & $(not-a-command)' ? 42 : -1)
	channel.Close()
	ExitApp 0
}
; Keep a real process alive and refuse graceful WM_CLOSE for termination checks.
OnMessage(0x10, (*) => 0)
NumPut("Int", 3, channel.View, 8)
Sleep 60000
channel.Close()
ExitApp 0
