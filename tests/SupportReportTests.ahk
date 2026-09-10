TestSupportReport() {
	local file
	; Use fake secrets, including regex metacharacters and unlabeled occurrences.
	IniWrite "opaque+value.[abc]", "settings\nm_config.ini", "Status", "bottoken"
	IniWrite "123456789012345678", "settings\nm_config.ini", "Status", "MainChannelID"
	IniWrite "private-example", "settings\nm_config.ini", "Settings", "PrivServer"
	text := nm_SupportReport.Redact("Failed opaque+value.[abc] while sending.`nWarning 123456789012345678`nError private-example")
	for secret in ["opaque+value.[abc]", "123456789012345678", "private-example"]
		Assert(!InStr(text, secret), "Configured secrets disappear even without a key label")
	for line in ["Error botToken=unfinished", "Warning Authorization: Bot abc", "Failed webhook https://discord.com/api/webhooks/123/abc", "Error privateServerLinkCode=secret", "Error cookie: abc", "Error Password = hidden"]
		AssertEqual(nm_SupportReport.Redact(line, []), "[credential-bearing line removed]", "Credential-bearing lines are removed in full")
	text := nm_SupportReport.Redact("Error https://cdn.discordapp.com/a?x=signed`nWarning roblox://placeId=1`nFailed 987654321012345678`nError C:\private folder\person\file.txt`nError \\server\private\file", [])
	for secret in ["signed", "placeId", "987654321012345678", "person", "server"]
		Assert(!InStr(text, secret), "URLs, IDs and local paths are removed")
	Assert(InStr(nm_SupportReport.Redact("Error: image search failed with code 42", []), "code 42"), "Useful non-sensitive failure context remains")
	Assert(InStr(nm_SupportReport.RecentIssues("missing-log.txt"), "unavailable"), "Missing logs do not abort diagnostics")
	file := FileOpen("support-test-log.txt", "w", "UTF-8")
	try {
		file.Write("Error OLD_SECRET " StrReplace(Format("{:70000}", "x"), " ", "x") "`n")
		Loop 14
			file.Write("Error numbered " A_Index "`n")
		file.Write("ordinary status`nError opaque+value.[abc]`n")
	} finally file.Close()
	issues := nm_SupportReport.RecentIssues("support-test-log.txt")
	Assert(!InStr(issues, "OLD_SECRET") && !InStr(issues, "numbered 1`r"), "A bounded tail drops the partial first line and older matching issues")
	Assert(InStr(issues, "numbered 14") && !InStr(issues, "opaque+value.[abc]"), "Newest useful issues survive redaction")
	Assert(!InStr(issues, "ordinary status"), "Non-issue status chatter is excluded")
	FileMove "settings\nm_config.ini", "settings\support-config-backup.ini"
	try {
		Assert(InStr(nm_SupportReport.RecentIssues("support-test-log.txt"), "redaction configuration"), "Missing main config excludes logs instead of exporting with incomplete redaction")
		DirCreate "settings\nm_config.ini"
		Assert(InStr(nm_SupportReport.RecentIssues("support-test-log.txt"), "redaction configuration"), "Unreadable main config excludes logs")
	} finally {
		if DirExist("settings\nm_config.ini")
			DirDelete "settings\nm_config.ini"
		FileMove "settings\support-config-backup.ini", "settings\nm_config.ini"
	}
	DirCreate "submacros"
	FileAppend 'VersionID := "1.2.3"', "submacros\natro_macro.ahk", "UTF-8"
	FileCopy "support-test-log.txt", "settings\debug_log.txt", 1
	report := nm_SupportReport.Build()
	Assert(InStr(report, "Natro version: 1.2.3") && InStr(report, "AHK:"), "Report contains version and runtime information")
	Assert(!InStr(report, "numbered") && InStr(report, "Recent issues: excluded"), "Default report excludes log contents")
	Assert(InStr(nm_SupportReport.Build(true), "numbered 14"), "Explicit recent-issue request includes sanitized excerpt")
	Assert(!InStr(report, A_WorkingDir), "Report does not reveal the installation path")
	report := nm_SupportReport.Build(false, Map("offsetFailed", 1, "latestVersion", "2.0.0"))
	Assert(InStr(report, "recent failed y-offset") && InStr(report, "newer version"), "Local report retains main-process offset and update observations")
	; Exercise native preview behavior. Opening/closing must not touch the clipboard.
	clipboard := ClipboardAll()
	try {
		A_Clipboard := "clipboard sentinel"
		nm_SupportPreview.Open()
		panel := nm_SupportPreview.Window
		Assert(!panel["Issues"].Value && !InStr(panel["Report"].Value, "numbered"), "Native preview starts without logs")
		AssertEqual(A_Clipboard, "clipboard sentinel", "Opening preview does not copy or send")
		panel["Issues"].Value := 1
		nm_SupportPreview.Refresh(panel)
		Assert(InStr(panel["Report"].Value, "numbered 14"), "Native opt-in updates preview")
		nm_SupportPreview.Copy(panel)
		AssertEqual(A_Clipboard, panel["Report"].Value, "Copy publishes exactly the displayed redacted text")
		nm_SupportPreview.Close(panel)
		Assert(!nm_SupportPreview.Window, "Closing preview releases window")
	} finally {
		if nm_SupportPreview.Window
			nm_SupportPreview.Close(nm_SupportPreview.Window)
		A_Clipboard := clipboard
	}
	fixture := TestDeliveryFixture([{status: 200, retryAfter: 0}])
	discord.Outbox := fixture.queue
	clipboard := A_Clipboard
	try {
		Assert(nm_SendSupportReport("123456789012345678", true), "Remote diagnostic builds an owned queued text attachment")
		AssertEqual(A_Clipboard, clipboard, "Remote diagnostics never use the clipboard")
		Assert(fixture.queue.Items.Length = 1 && nm_DeliveryPayloadSize(fixture.queue.Items[1].data) > 200, "Encoded support report is handed to the delivery queue")
		bytes := fixture.queue.Items[1].data
		body := StrGet(NumGet(ComObjValue(bytes), 8 + A_PtrSize, "Ptr"), nm_DeliveryPayloadSize(bytes), "UTF-8")
		Assert(RegExMatch(body, 's)name="payload_json"\r\nContent-Type: application/json\r\n\r\n(.*?)\r\n--', &match), "Remote attachment contains a JSON metadata part")
		metadata := JSON.parse(match[1])
		AssertEqual(metadata["message_reference"]["message_id"], "123456789012345678", "Reply ID is serialized as text")
		Assert(metadata["allowed_mentions"]["parse"].Length = 0, "Support metadata disables incidental mentions")
		Assert(InStr(body, 'filename="natro-support.txt"') && InStr(body, "numbered 14"), "Queued multipart contains the actual report")
		Assert(!InStr(body, "opaque+value.[abc]") && !InStr(body, "OLD_SECRET"), "Encoded attachment contains no fixture secrets or discarded old data")
	} finally discord.Outbox := 0
}
