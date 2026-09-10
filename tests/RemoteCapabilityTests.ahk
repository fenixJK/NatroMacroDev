RemoteTestParams(name, subcommand := "", value := "") => [name, subcommand, value]

TestRemoteCapabilities() {
	AssertEqual(nm_RemoteCapabilities.Read(), 0, "Existing installations have no optional remote capabilities")
	for name in ["help", "stop", "reload", "pause", "unpause", "start", "rejoin", "keep", "replace", "planters", "timers", "prefix", "set", "get", "shiftlock", "shrine", "blender", "mm", "finditem"]
		AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams(name)), "", "Authorized ordinary command remains available: " name)
	cases := Map("send", "DesktopControl", "CLICK", "DesktopControl", "close", "DesktopControl", "activate", "DesktopControl", "minimise", "DesktopControl", "minimize", "DesktopControl", "upload", "FileRead", "download", "FileReceive", "restart", "System", "log", "Diagnostics", "DEBUG", "Diagnostics", "debuglog", "Diagnostics", "personal-command", "CustomCommands")
	for name, capability in cases
		AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams(name)), capability, "Broader command disabled by default: " name)
	AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams("ss")), "", "Default screenshot is Roblox only")
	AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams("screenshot", "mode", "Roblox"), "All"), "", "Controller can restore Roblox screenshot mode without desktop capability")
	for mode in ["All", "Window", "Screen", "invalid"] {
		AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams("SS", "mode", mode)), "DesktopCapture", "Desktop mode change requires capability")
		AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams("ss"), mode), "DesktopCapture", "Stored screenshot mode cannot bypass revocation")
		AssertEqual(nm_RemoteCapture(mode), 0, "Disabled desktop capture returns before native capture")
	}
	for capability, flag in nm_RemoteCapabilities.Flags {
		nm_RemoteCapabilities.Save(flag)
		AssertEqual(nm_RemoteCapabilities.Read(), flag, "Local permission persists")
		for name, required in cases
			AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams(name)), required = capability ? "" : required, "One grant does not enable unrelated commands")
	}
	nm_RemoteCapabilities.Save(127)
	for name in cases
		AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams(name)), "", "Explicitly enabled capability permits command")
	nm_RemoteCapabilities.Save(0)
	AssertEqual(nm_RemoteCapabilities.Denied(RemoteTestParams("send")), "DesktopControl", "Revocation is read at the next dispatch")
	for corrupt in ["bad", -1, 128, 1.5] {
		IniWrite corrupt, nm_RemoteCapabilities.Path, "Permissions", "Mask"
		AssertEqual(nm_RemoteCapabilities.Read(), 0, "Malformed permissions fail closed")
	}
	for key in ["webhook", "bottoken", "BotAuth", "PrivServer", "FallbackServer", "discordUIDCommands", "remote_permissions"]
		Assert(nm_RemoteCapabilities.PrivateSetting(key), "Private config lookup is blocked: " key)
	Assert(!nm_RemoteCapabilities.PrivateSetting("MoveSpeed"), "Ordinary config remains readable")
	FileAppend "report", "settings\upload-fixture.txt"
	AssertEqual(nm_RemoteUploadPath("settings\upload-fixture.txt"), "settings\upload-fixture.txt", "Individual file upload stays available")
	AssertThrows(nm_RemoteUploadPath.Bind("settings"), "Folder cannot reach shell archive path")
	AssertThrows(nm_RemoteUploadPath.Bind("settings\nm_config.ini"), "Raw main settings cannot be uploaded")
	nm_RemoteCapabilities.Save(0)
}
