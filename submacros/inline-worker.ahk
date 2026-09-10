#Requires AutoHotkey v2.0.12
#SingleInstance Off
#NoTrayIcon
#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\InlineProtocol.ahk"
#Include "%A_ScriptDir%\..\lib\InlinePipe.ahk"

SetWorkingDir A_ScriptDir "\.."
channel := 0
try {
	if A_Args.Length != 1
		throw ValueError("Invalid generated-worker invocation")
	channel := nm_ProcessChannel(A_Args[1], nm_InlineProtocol.Bytes, nm_InlineProtocol.RequestChars)
	nm_InlinePipe.Run(channel.Read(), channel)
} catch {
	if channel
		NumPut("Int", 2, channel.View, 8)
	ExitApp 1
} finally {
	if channel
		channel.Close()
}
ExitApp 0
