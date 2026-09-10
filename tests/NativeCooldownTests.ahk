TestNativeCooldown() {
	beforeKeys := nm_SharedCooldownSlot.Slots.Clone(), child := 0
	DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &before := 0)
	try {
		token := "rate-fixture-" DllCall("GetCurrentProcessId") "-" A_TickCount
		job := {token: token}, gate := nm_DeliveryCooldown(true), current := DllCall("GetTickCount64", "UInt64")
		deadline := gate.Defer(job, current, 120)
		key := nm_DeliveryCooldown.Key(job), slot := nm_SharedCooldownSlot.Get(key)
		RequireProcess(!InStr(slot.Name, token) && StrLen(key) = 64, "Kernel object name contains only a digest of the credential")
		otherRuntime := A_ScriptDir "\..\submacros\AutoHotkey" (A_PtrSize = 8 ? "32" : "64") ".exe"
		child := nm_OwnedProcessJob(Map("mode", "extend", "token", token, "minimum", deadline), A_ScriptDir "\CooldownFixture.ahk", otherRuntime)
		RequireProcess(child.Wait() = 1, "Other AHK architecture reads the parent's shared cooldown")
		child.Close(), child := 0
		RequireProcess(gate.Deadline(job, current) >= current + 300000, "Parent observes child extension after child exit")
		newGate := nm_DeliveryCooldown(true)
		RequireProcess(newGate.Deadline({token: token}, current) >= current + 300000, "New coordinator retains the shared delay")

		heldJob := {token: token "-held"}
		RequireProcess(gate.Deadline(heldJob, current) = 0, "Contention fixture starts without a cooldown")
		child := nm_OwnedProcessJob(Map("mode", "hold", "token", heldJob.token), A_ScriptDir "\CooldownFixture.ahk", otherRuntime)
		WaitProcessReady(child)
		RequireProcess(gate.Deadline(heldJob, current) > current, "Busy mutex prevents an uncoordinated send")
		gate.Defer(heldJob, current, 3)
		RequireProcess(gate.Entry(heldJob, current).pending > 0, "Contended publication retains a local pending deadline")
		child.Close(), child := 0
		gate.Flush()
		RequireProcess(!gate.Entry(heldJob, current).pending, "Pending deadline publishes after lock owner terminates")
		RequireProcess(gate.Deadline(heldJob, current) >= current + 60000, "Abandoned mutex imposes conservative recovery backoff")
		FileAppend "PASS Windows shared Discord cooldown integration (" A_PtrSize * 8 "-bit with opposite-architecture worker)`n", "*"
	} finally {
		if child
			child.Close()
		for key, slot in nm_SharedCooldownSlot.Slots.Clone()
			if !beforeKeys.Has(key) {
				slot.Close()
				nm_SharedCooldownSlot.Slots.Delete(key)
			}
	}
	DllCall("GetProcessHandleCount", "Ptr", -1, "UIntP", &after := 0)
	RequireProcess(after <= before + 2, "Native cooldown fixture releases mappings, mutexes and worker handles")
}
