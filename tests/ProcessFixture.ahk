#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\PowerShellJob.ahk"
channel := nm_ProcessChannel(A_Args[1])
request := channel.Read()
if request["mode"] = "echo" {
	channel.Complete(request["text"] == 'Unicode Ω " & $(not-a-command)' ? 42 : -1)
	channel.Close()
	ExitApp 0
}

if request["mode"] = "owner" || request["mode"] = "file_owner" {
	; This fixture becomes a macro-like owner of a second helper. The harness
	; kills this process directly, bypassing all AHK OnExit callbacks.
	child := request["mode"] = "owner" ? nm_OwnedProcessJob(Map("mode", "idle"), A_ScriptFullPath)
		: nm_PowerShellJob(Map("mode", "idle_child", "executable", A_AhkPath, "script", A_ScriptDir "\ProcessSurvivor.ahk"), A_ScriptDir "\PowerShellFixture.ps1")
	deadline := DllCall("GetTickCount64", "UInt64") + 20000
	while NumGet(child.View, 8, "Int") != 3 {
		if !child.Running() || DllCall("GetTickCount64", "UInt64") >= deadline
			ExitApp 1
		Sleep 20
	}
	NumPut("Int", child.Pid, channel.View, 12)
	if request["mode"] = "file_owner"
		NumPut("Int", NumGet(child.View, 12, "Int"), channel.View, 16)
}
if request["mode"] = "spawn" || request["mode"] = "spawn_idle" {
	Run '"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptDir '\ProcessSurvivor.ahk"', , , &survivorPid
	if request["mode"] = "spawn" {
		channel.Complete(survivorPid)
		channel.Close()
		ExitApp 0
	}
	NumPut("Int", survivorPid, channel.View, 12)
}
; Keep a real process alive and refuse graceful WM_CLOSE for termination checks.
OnMessage(0x10, (*) => 0)
NumPut("Int", 3, channel.View, 8)
Sleep 60000
channel.Close()
ExitApp 0
