#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\RobloxProcesses.ahk"
#Include "%A_ScriptDir%\..\lib\ReconnectLaunch.ahk"

channel := 0, outcome := 1
try {
	if A_Args.Length != 1
		throw ValueError("Invalid worker invocation")
	channel := nm_ProcessChannel(A_Args[1])
	request := channel.Read()
	if !(request is Map) || !request.Has("kind")
		throw ValueError("Invalid worker request")
	if request["kind"] = "close"
		count := nm_RobloxProcesses.ClosePlayers()
	else
		nm_ReconnectLaunch.Run(request), count := 0
	channel.Complete(count), outcome := 0
} catch as workerError {
	if channel
		channel.Complete(workerError.Line, false)
} finally {
	if channel
		channel.Close()
}
ExitApp outcome
