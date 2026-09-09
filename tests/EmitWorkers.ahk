#Requires AutoHotkey v2.0.12
#SingleInstance Off
#Warn All, StdOut
#Include "..\lib\WorkerScripts.ahk"

; Only build source text. Worker startup, game input and GUIs never execute here.
destination := A_Args[1]
DirCreate destination
workers := Map("bitterberry", nm_BuildBitterberryFeederScript(), "basicegg", nm_BuildBasicEggHatcherScript())
keys := 'LeftKey := "a", RightKey := "d", FwdKey := "w", BackKey := "s", SC_E := "e"'
for enabled in [0, 1]
	workers["walk-" enabled] := nm_BuildWalkScript('nm_Walk(1, FwdKey)', "", enabled, 28, 36, keys, "a", "d", "w", "s", "Space", "e")
for name, source in workers
	FileAppend source, destination "\" name ".ahk", "UTF-8-RAW"
FileAppend "PASS emitted four production workers`n", "*"
