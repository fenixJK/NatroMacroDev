#Include "FailureLog.ahk"
HideErrors := IniRead((FileExist(A_ScriptDir "\submacros\natro_macro.ahk") ? A_ScriptDir : A_ScriptDir "\..") "\settings\nm_config.ini", "Settings", "HideErrors", 1)
OnError ObjBindMethod(nm_Failures, "Handle")
