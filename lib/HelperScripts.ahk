#Include "%A_ScriptDir%\..\lib\ScriptProcess.ahk"
#Include "%A_ScriptDir%\..\lib\RobloxProcesses.ahk"

class nm_HelperScripts {
	static Names := ["Heartbeat", "Status", "background", "StatMonitor", "PlanterTimers", "reconnect-worker", "inline-worker"]
	static Close(root, runtimes, keepHeartbeat := 0) {
		seen := Map()
		for executable in runtimes {
			executable := nm_ScriptProcess.FullPath(executable)
			if seen.Has(StrLower(executable))
				continue
			seen[StrLower(executable)] := true
			for name in this.Names {
				instances := nm_ScriptProcess.Find(root "\submacros\" name ".ahk", executable)
				try {
					for instance in instances {
						if name = "Heartbeat" && instance.ScriptHwnd = keepHeartbeat
							continue
						instance.Shutdown()
					}
				} finally {
					for instance in instances
						instance.Release()
				}
			}
		}
	}
	static Window(root, name, executable) {
		instances := nm_ScriptProcess.Find(root "\submacros\" name ".ahk", executable)
		try return instances.Length ? instances[1].ScriptHwnd : 0
		finally {
			for instance in instances
				instance.Release()
		}
	}
}
