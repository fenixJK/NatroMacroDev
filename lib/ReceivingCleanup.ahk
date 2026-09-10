#Include "%A_ScriptDir%\..\lib\ContainedProcessJob.ahk"

class nm_ReceivingCleanup extends nm_ContainedProcessJob {
	__New(directory) => super.__New(Map("directory", directory), A_ScriptDir "\..\submacros\receiving-cleanup.ahk")
	Status => this.Running() ? 0 : 1
	Result() {
		if this.Running()
			throw Error("Receiving cleanup has not completed")
		return DllCall("GetExitCodeProcess", "Ptr", this.Process, "UIntP", &code := 0) && code = 0
			&& NumGet(this.View, 8, "Int") = 1 && NumGet(this.View, 12, "Int") = 0
	}
}
