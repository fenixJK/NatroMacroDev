#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\ReceivingCleanupFiles.ahk"
channel := 0
try {
	if A_Args.Length != 1
		throw ValueError("Invalid cleanup invocation")
	channel := nm_ProcessChannel(A_Args[1])
	request := channel.Read()
	if !(request is Map) || !request.Has("directory")
		throw ValueError("Invalid cleanup request")
	nm_ReceivingCleanupFiles.Remove(request["directory"])
	channel.Complete()
} catch {
	if channel
		channel.Complete(1, false)
} finally {
	if channel
		channel.Close()
}
ExitApp 0
