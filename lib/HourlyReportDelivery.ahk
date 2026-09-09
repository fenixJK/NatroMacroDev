; Persist the rendered report before advancing the hourly sample window. PNGs
; remain available after exhausted delivery or helper/process termination.
nm_QueueHourlyReport(pBitmap) {
	static sequence := 0
	directory := A_WorkingDir "\settings\pending-reports"
	DirCreate directory
	count := bytes := 0
	Loop Files directory "\*.png" {
		count++, bytes += A_LoopFileSize
	}
	if count >= 72 || bytes >= 256 * 1024 * 1024
		throw Error("Pending hourly report storage is full; resolve files in settings\pending-reports")
	sequence++
	path := directory "\" FormatTime(A_NowUTC, "yyyyMMdd-HHmmss") "-" DllCall("GetCurrentProcessId") "-" A_TickCount "-" sequence ".png"
	if (result := Gdip_SaveBitmapToFile(pBitmap, path)) != 0
		throw Error("Could not preserve hourly report (GDI " result ")")
	if bytes + FileGetSize(path) > 256 * 1024 * 1024 {
		FileDelete path
		throw Error("Pending hourly report byte limit reached; sample window retained")
	}
	FileAppend "Awaiting Discord delivery. This report is retained until HTTP success.`n", path ".txt", "UTF-8"

	mode := IniRead("settings\nm_config.ini", "Status", "discordMode", 0)
	if mode = 0 {
		endpoint := IniRead("settings\nm_config.ini", "Status", "webhook", "")
		endpoint .= (InStr(endpoint, "?") ? "&" : "?") "wait=true"
		token := ""
	} else {
		channel := IniRead("settings\nm_config.ini", "Status", "ReportChannelID", "")
		if StrLen(channel) < 17
			channel := IniRead("settings\nm_config.ini", "Status", "MainChannelID", "")
		endpoint := discord.baseURL "channels/" channel "/messages"
		token := IniRead("settings\nm_config.ini", "Status", "bottoken", "")
	}
	payload := JSON.stringify(Map("embeds", [Map("title", "**[" A_Hour ":" A_Min ":00] Hourly Report**",
		"color", 14052794, "image", Map("url", "attachment://file.png"))]), 0)
	discord.CreateFormData(&data, &contentType, [Map("name", "payload_json", "content-type", "application/json", "content", payload),
		Map("name", "files[0]", "filename", "file.png", "content-type", "image/png", "file", path)])
	return discord.DeliveryQueue().Enqueue(data, contentType, endpoint, token,
		"Hourly report retained at " path, nm_HourlyReportDelivered.Bind(path))
}

nm_HourlyReportDelivered(path, delivered) {
	if delivered {
		try {
			FileDelete path
			FileDelete path ".txt"
		}
	} else {
		try FileAppend "Delivery was not confirmed. The PNG is retained for review/manual resend.`n", path ".txt", "UTF-8"
	}
}
