#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\DeliveryCooldown.ahk"
channel := nm_ProcessChannel(A_Args[1]), request := channel.Read()
gate := nm_DeliveryCooldown(true), job := {token: request["token"]}
current := DllCall("GetTickCount64", "UInt64")
if request["mode"] = "extend" {
	if gate.Deadline(job, current) < request["minimum"]
		ExitApp 1
	gate.Defer(job, current, 300)
	channel.Complete(1)
	channel.Close()
	ExitApp 0
}
if request["mode"] = "hold" {
	slot := nm_SharedCooldownSlot.Get(nm_DeliveryCooldown.Key(job))
	if DllCall("WaitForSingleObject", "Ptr", slot.Mutex, "UInt", 0, "UInt") != 0
		ExitApp 1
	NumPut("Int", 3, channel.View, 8)
	; The harness kills this process while it owns the mutex.
	Loop
		Sleep 100
}
ExitApp 1
