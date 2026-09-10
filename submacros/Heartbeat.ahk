/*
Natro Macro (https://github.com/NatroTeam/NatroMacro)
Copyright © Natro Team (https://github.com/NatroTeam)

This file is part of Natro Macro. Our source code will always be open and available.

Natro Macro is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Natro Macro is distributed in the hope that it will be useful. This does not give you the right to steal sections from our code, distribute it under your own name, then slander the macro.

You should have received a copy of the license along with Natro Macro. If not, please redownload from an official source.
*/

#NoTrayIcon
#SingleInstance Force
#MaxThreads 255

#Include "%A_ScriptDir%\..\lib\JSON.ahk"
#Include "%A_ScriptDir%\..\lib\OwnedProcessJob.ahk"
#Include "%A_ScriptDir%\..\lib\RobloxProcesses.ahk"
#Include "%A_ScriptDir%\..\lib\ScriptProcess.ahk"
#Include "%A_ScriptDir%\..\lib\WatchdogRecovery.ahk"
#Include "%A_ScriptDir%\..\lib\FailureLog.ahk"

HideErrors := 1
OnError((err, mode) => (nm_Failures.Write(err, "Watchdog unhandled failure"), ExitApp(1)))
SetWorkingDir A_ScriptDir "\.."
OnMessage(0x5552, nm_SetGlobalInt)
OnMessage(0x5556, nm_SetHeartbeat)

LastRobloxWindow := LastStatusHeartbeat := LastMainHeartbeat := LastBackgroundHeartbeat := DllCall("GetTickCount64", "UInt64")
MacroState := 0
watchdog := nm_WatchdogRecovery()
mainScript := A_ScriptDir "\natro_macro.ahk"

Loop
{
	time := DllCall("GetTickCount64", "UInt64")
	DetectHiddenWindows 0
	if (WinExist("Roblox ahk_exe RobloxPlayerBeta.exe") || WinExist("Roblox ahk_exe ApplicationFrameHost.exe"))
		LastRobloxWindow := time
	DetectHiddenWindows 1
	; request heartbeat
	if WinExist(mainScript " - AutoHotkey v" A_AhkVersion " ahk_class AutoHotkey")
		PostMessage 0x5556
	if WinExist(A_ScriptDir "\Status.ahk - AutoHotkey v" A_AhkVersion " ahk_class AutoHotkey")
		PostMessage 0x5556
	if WinExist(A_ScriptDir "\background.ahk - AutoHotkey v" A_AhkVersion " ahk_class AutoHotkey")
		PostMessage 0x5556
	; check for timeouts
	if (((MacroState = 2) && (((time - LastMainHeartbeat > 120000) && (reason := "Macro Unresponsive Timeout!"))
		|| ((time - LastBackgroundHeartbeat > 120000) && (reason := "Background Script Timeout!"))
		|| ((time - LastStatusHeartbeat > 120000) && (reason := "Status Script Timeout!"))
		|| ((time - LastRobloxWindow > 600000) && (reason := "No Roblox Window Timeout!"))))

		|| ((MacroState = 1) && (((time - LastMainHeartbeat > 120000) && (reason := "Macro Unresponsive Timeout!"))
		|| ((time - LastStatusHeartbeat > 120000) && (reason := "Status Script Timeout!"))))) {
		Prev_MacroState := MacroState, MacroState := 0
		try {
			restartedHwnd := watchdog.Run(
				() => nm_ScriptProcess.Stop(mainScript, A_AhkPath),
				() => nm_OwnedProcessJob.Execute(Map("kind", "close")),
				() => nm_ScriptProcess.Launch(mainScript, A_AhkPath, [Prev_MacroState = 2 ? 1 : 0, A_ScriptHwnd]))
			nm_Failures.Write(Error(reason), "Watchdog replaced macro; UI ready")
			try Send_WM_COPYDATA("Error: " reason "`nMacro UI restarted. Startup checks still apply.", "ahk_class AutoHotkey ahk_pid " WinGetPID("ahk_id " restartedHwnd))
			LastRobloxWindow := LastStatusHeartbeat := LastMainHeartbeat := LastBackgroundHeartbeat := DllCall("GetTickCount64", "UInt64")
		} catch as recoveryError {
			nm_Failures.Write(recoveryError, "Watchdog automatic recovery stopped")
			MsgBox "Automatic recovery stopped. Check settings/errors and restart Natro after correcting the problem.", "Natro recovery stopped", "0x10 T60"
			ExitApp 1
		}
	}
	else
	{
		if MacroState != 2 {
			LastBackgroundHeartbeat := time
			LastRobloxWindow := time
		}
	}
	Sleep 5000
}

Send_WM_COPYDATA(StringToSend, TargetScriptTitle, wParam:=0)
{
    CopyDataStruct := Buffer(3*A_PtrSize)
    SizeInBytes := (StrLen(StringToSend) + 1) * 2
    NumPut("Ptr", SizeInBytes
		, "Ptr", StrPtr(StringToSend)
		, CopyDataStruct, A_PtrSize)

	try
		s := SendMessage(0x004A, wParam, CopyDataStruct,, TargetScriptTitle)
	catch
		return -1
	else
		return s
}

nm_SetHeartbeat(wParam, *)
{
	global
	Critical
	static arr := ["Main", "Background", "Status"]
	if IsInteger(wParam) && wParam >= 1 && wParam <= 3
		script := arr[wParam], Last%script%Heartbeat := DllCall("GetTickCount64", "UInt64")
}

nm_SetGlobalInt(wParam, lParam, *)
{
	global
	Critical
	local var
	; enumeration
	static arr := Map(23, "MacroState")

	if wParam != 23 || (lParam != 0 && lParam != 1 && lParam != 2)
		return 0
	if MacroState = 0 && lParam != 0
		LastRobloxWindow := LastStatusHeartbeat := LastMainHeartbeat := LastBackgroundHeartbeat := DllCall("GetTickCount64", "UInt64")
	var := arr[wParam], %var% := lParam
	return 0
}
