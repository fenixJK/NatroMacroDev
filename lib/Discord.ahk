/********************************************
* @Author SP
* @Description Class to interact with Discord
*********************************************/


#Include "%A_ScriptDir%\..\lib\DeliveryQueue.ahk"
#Include "%A_ScriptDir%\..\lib\DiscordPayload.ahk"
#Include "%A_ScriptDir%\..\lib\FailureLog.ahk"

class discord
{
	static baseURL := "https://discord.com/api/v10/"
	static Outbox := 0

	static DeliveryQueue() {
		if !this.Outbox {
			this.Outbox := nm_DeliveryQueue(,, ObjBindMethod(this, "DeliveryFailed"))
			SetTimer ObjBindMethod(this.Outbox, "Pump"), 100
			OnExit ObjBindMethod(this, "CloseDelivery")
		}
		return this.Outbox
	}

	static CloseDelivery(*) {
		if this.Outbox
			this.Outbox.Close()
	}

	static DeliveryFailed(job, reason) {
		; Payload/label only: never persist the endpoint or Authorization header.
		; Existing logger redacts known credentials and bounds local history.
		detail := reason "`n" job.label
		if Type(job.data) = "String"
			detail .= "`n" job.data
		nm_Failures.Write(Error(detail), "Discord delivery", A_WorkingDir "\settings\errors")
	}

	static QueueMessage(postdata, contentType := "application/json", channel := "", url := "", label := "Report", completed := unset) {
		global webhook, bottoken, discordMode, MainChannelCheck, MainChannelID
		token := ""
		if !url {
			if discordMode = 0
				url := webhook (InStr(webhook, "?") ? "&" : "?") "wait=true"
			else {
				if !channel && MainChannelCheck
					channel := MainChannelID
				if !channel
					return true ; destination disabled: intentionally handled without sending
				url := this.baseURL "channels/" channel "/messages", token := bottoken
			}
		} else
			url .= (InStr(url, "?") ? "&" : "?") "wait=true"
		return this.DeliveryQueue().Enqueue(postdata, contentType, url, token, label, completed?)
	}

	static QueueEmbed(message, color := 3223350, content := "", pBitmap := 0, channel := "") {
		payload := nm_DiscordEmbedPayload(message, color, content, pBitmap > 0 ? "ss.png" : "")
		if pBitmap > 0
			this.CreateFormData(&data, &contentType, [Map("name", "payload_json", "content-type", "application/json", "content", payload),
				Map("name", "files[0]", "filename", "ss.png", "content-type", "image/png", "pBitmap", pBitmap)])
		else
			data := payload, contentType := "application/json"
		return this.QueueMessage(data, contentType, channel, , message)
	}

	static SendEmbed(message, color:=3223350, content:="", pBitmap:=0, channel:="", replyID:=0)
	{
		payload_json :=
		(
		'
		{
			"content": "' content '",
			"embeds": [{
				"description": "' message '",
				"color": "' color '"
				' (pBitmap ? (',"image": {"url": "attachment://ss.png"}') : '') '
			}]
			' (replyID ? (',"allowed_mentions": {"parse": []}, "message_reference": {"message_id": "' replyID '", "fail_if_not_exists": false}') : '') '
		}
		'
		)

		if pBitmap
			this.CreateFormData(&postdata, &contentType, [Map("name","payload_json","content-type","application/json","content",payload_json), Map("name","files[0]","filename","ss.png","content-type","image/png","pBitmap",pBitmap)])
		else
			postdata := payload_json, contentType := "application/json"

		return this.SendMessageAPI(postdata, contentType, channel)
	}

	static SendFile(filepath, replyID:=0)
	{
		static MimeTypes := Map("PNG", "image/png"
			, "JPEG", "image/jpeg"
			, "JPG", "image/jpeg"
			, "BMP", "image/bmp"
			, "GIF", "image/gif"
			, "WEBP", "image/webp"
			, "TXT", "text/plain"
			, "INI", "text/plain")

		if (attr := FileExist(filepath))
		{
			SplitPath filepath := RTrim(filepath, "\/"), &filename:=""
			if (filename && InStr(attr, "D"))
			{
				; attempt to zip folder to temp
				try
				{
					RunWait 'powershell.exe -WindowStyle Hidden -Command Compress-Archive -Path "' filepath '\*" -DestinationPath "$env:TEMP\' filename '.zip" -CompressionLevel Fastest -Force', , "Hide"
					if !FileExist(filepath := A_Temp "\" filename ".zip")
						throw
				}
				catch
				{
					this.SendEmbed('The folder ``' StrReplace(StrReplace(filepath, "\", "\\"), '"', '\"') '`` could not be zipped!`nThis function is only supported on Windows 10 or higher.', 16711731, , , , replyID)
					return -3
				}
			}
			size := FileGetSize(filepath)
			if (size > 10485760)
			{
				this.SendEmbed('``' StrReplace(StrReplace(filepath, "\", "\\"), '"', '\"') '`` is above the Discord file size limit of 10MiB!', 16711731, , , , replyID)
				return -1
			}
		}
		else
		{
			this.SendEmbed('``' StrReplace(StrReplace(filepath, "\", "\\"), '"', '\"') '`` does not exist or could not be read!', 16711731, , , , replyID)
			return -2
		}

		SplitPath filepath, &filename, , &ext
		ext := StrUpper(ext)
		params := []
		(replyID > 0) && params.Push(Map("name","payload_json","content-type","application/json","content",'{"allowed_mentions": {"parse": []}, "message_reference": {"message_id": "' replyID '", "fail_if_not_exists": false}}'))
		params.Push(Map("name","files[0]","filename",filename,"content-type",MimeTypes.Has(ext) ? MimeTypes[ext] : "application/octet-stream","file",filepath))
		this.CreateFormData(&postdata, &contentType, params)
		this.SendMessageAPI(postdata, contentType)

		; delete any temp file created
		if (SubStr(filepath, 1, StrLen(A_Temp)) = A_Temp)
			try FileDelete filepath
	}

	static SendImage(pBitmap, imgname:="image.png", replyID:=0)
	{
		params := []
		(replyID > 0) && params.Push(Map("name","payload_json","content-type","application/json","content",'{"allowed_mentions": {"parse": []}, "message_reference": {"message_id": "' replyID '", "fail_if_not_exists": false}}'))
		params.Push(Map("name","files[0]","filename",imgname,"content-type","image/png","pBitmap",pBitmap))
		this.CreateFormData(&postdata, &contentType, params)
		this.SendMessageAPI(postdata, contentType)
	}

	static SendMessageAPI(postdata, contentType:="application/json", channel:="", url:="")
	{
		global webhook, bottoken, discordMode, MainChannelCheck, MainChannelID

		if (!channel && (discordMode = 1))
		{
			if (MainChannelCheck = 1)
				channel := MainChannelID
			else
				return -2
		}

		if !url
			url := (discordMode = 0) ? (webhook "?wait=true") : (this.BaseURL "/channels/" channel "/messages")

		try
		{
			wr := ComObject("WinHttp.WinHttpRequest.5.1")
			wr.Option[9] := 2720
			wr.SetTimeouts(5000, 5000, 10000, 10000)
			wr.Open("POST", url, 1)
			if (discordMode = 1)
			{
				wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
				wr.SetRequestHeader("Authorization", "Bot " bottoken)
			}
			wr.SetRequestHeader("Content-Type", contentType)
			wr.SetTimeouts(5000, 5000, 10000, 10000)
			wr.Send(postdata)
			return this.AwaitResponse(wr)
		}
	}

	static GetCommands(channel)
	{
		global discordMode, commandPrefix

		if (discordMode = 0)
			return -1

		Loop (n := (messages := this.GetRecentMessages(channel)).Length)
		{
			i := n - A_Index + 1
			(SubStr(content := Trim(messages[i]["content"]), 1, StrLen(commandPrefix)) = commandPrefix) && command_buffer.Push({content:content, id:messages[i]["id"], url:messages[i]["attachments"].Has(1) ? messages[i]["attachments"][1]["url"] : "", user_id: messages[i]["author"]["id"]})
		}
	}

	static GetChannel(channelid)
	{
		global discordMode
		if (discordMode == 0)
			return -1

		wr := ComObject("WinHttp.WinHttpRequest.5.1")
		wr.Option[9] := 2720
			wr.SetTimeouts(5000, 5000, 10000, 10000)
		wr.Open("GET", Discord.baseURL . "channels/" channelid, true)
		wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
		wr.SetRequestHeader("Authorization", "Bot " . bottoken)
		wr.Send()
		return this.AwaitResponse(wr)
	}

	static GetMember(guild_id, user_id)
	{
		global discordMode
		if (discordMode == 0)
			return -1

		wr := ComObject("WinHttp.WinHttpRequest.5.1")
		wr.Option[9] := 2720
			wr.SetTimeouts(5000, 5000, 10000, 10000)
		wr.Open("GET", Discord.baseURL . "guilds/" . guild_id . "/members/" . user_id, true)
		wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
		wr.SetRequestHeader("Authorization", "Bot " . bottoken)
		wr.Send()
		return this.AwaitResponse(wr)
	}


	static GetRecentMessages(channel)
	{
		global discordMode
		static lastmsg := Map()

		if (discordMode = 0)
			return -1

		try
			(messages := JSON.parse(this.GetMessageAPI(lastmsg.Has(channel) ? ("?after=" lastmsg[channel]) : "?limit=1", channel))).Length
		catch
			return []

		if (messages.Has(1))
			lastmsg[channel] := messages[1]["id"]

		return messages
	}

	static GetMessageAPI(params:="", channel:="")
	{
		global bottoken, discordMode, MainChannelCheck, MainChannelID

		if (discordMode = 0)
			return -1

		if !channel
		{
			if (MainChannelCheck = 1)
				channel := MainChannelID
			else
				return -2
		}

		try
		{
			wr := ComObject("WinHttp.WinHttpRequest.5.1")
			wr.Option[9] := 2720
			wr.SetTimeouts(5000, 5000, 10000, 10000)
			wr.Open("GET", this.BaseURL "/channels/" channel "/messages" params, 1)
			wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
			wr.SetRequestHeader("Authorization", "Bot " bottoken)
			wr.SetRequestHeader("Content-Type", "application/json")
			wr.Send()
			return this.AwaitResponse(wr)
		}
	}

	static EditMessageAPI(id, postdata, contentType:="application/json", channel:="")
	{
		if (!channel && (discordMode = 1))
		{
			if (MainChannelCheck = 1)
				channel := MainChannelID
			else
				return -2
		}

		url := (discordMode = 0) ? (webhook "/messages/" id) : (this.BaseURL "/channels/" channel "/messages/" id)

		try
		{
			wr := ComObject("WinHttp.WinHttpRequest.5.1")
			wr.Option[9] := 2720
			wr.SetTimeouts(5000, 5000, 10000, 10000)
			wr.Open("PATCH", url, 1)
			if (discordMode = 1)
			{
				wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
				wr.SetRequestHeader("Authorization", "Bot " bottoken)
			}
			wr.SetRequestHeader("Content-Type", contentType)
			wr.SetTimeouts(5000, 5000, 10000, 10000)
			wr.Send(postdata)
			return this.AwaitResponse(wr)
		}
	}

	static AwaitResponse(wr) {
		if !wr.WaitForResponse(20) {
			wr.Abort()
			return ""
		}
		if wr.Status < 200 || wr.Status >= 300 {
			nm_Failures.Write(Error("HTTP " wr.Status), "Discord synchronous request")
			return ""
		}
		return wr.ResponseText
	}

	static CreateFormData(&retData, &contentType, fields) {
		boundary := "natro-" DllCall("GetCurrentProcessId") "-" A_TickCount "-" Random(100000, 999999)
		if DllCall("ole32\CreateStreamOnHGlobal", "Ptr", 0, "Int", true, "PtrP", &stream := 0, "Int") != 0
			throw Error("Could not allocate attachment stream")
		try {
			for field in fields {
				name := this.FormName(field["name"])
				header := "--" boundary "`r`nContent-Disposition: form-data; name=" Chr(34) name Chr(34)
				if field.Has("filename")
					header .= "; filename=" Chr(34) this.FormName(field["filename"]) Chr(34)
				header .= "`r`nContent-Type: " this.FormName(field["content-type"]) "`r`n`r`n"
				this.WriteFormText(stream, header)
				if field.Has("content")
					this.WriteFormText(stream, field["content"])
				if field.Has("pBitmap") || field.Has("file") {
					input := 0
					try {
						if field.Has("pBitmap") {
							if field["pBitmap"] <= 0 || (input := Gdip_SaveBitmapToStream(field["pBitmap"])) <= 0 {
								input := 0
								throw Error("Could not encode attachment image")
							}
						} else if DllCall("shlwapi\SHCreateStreamOnFileEx", "WStr", field["file"], "UInt", 0,
							"UInt", 0x80, "Int", false, "Ptr", 0, "PtrP", &input, "Int") != 0
							throw Error("Could not read attachment file")
						if DllCall("shlwapi\IStream_Size", "Ptr", input, "UInt64P", &size := 0, "Int") != 0
							throw Error("Could not measure attachment")
						if field.Has("pBitmap") && size = 0
							throw Error("Image encoding returned no data")
						if size > 32 * 1024 * 1024
							throw Error("Attachment exceeds queue byte limit")
						if DllCall("shlwapi\IStream_Reset", "Ptr", input, "Int") != 0
							|| DllCall("shlwapi\IStream_Copy", "Ptr", input, "Ptr", stream, "UInt", size, "Int") != 0
							throw Error("Could not copy attachment")
					} finally {
						if input
							ObjRelease(input)
					}
				}
				this.WriteFormText(stream, "`r`n")
			}
			this.WriteFormText(stream, "--" boundary "--`r`n")
			if DllCall("shlwapi\IStream_Size", "Ptr", stream, "UInt64P", &size := 0, "Int") != 0 || size > 32 * 1024 * 1024
				throw Error("Encoded report exceeds queue byte limit")
			retData := ComObjArray(0x11, size)
			dataPointer := NumGet(ComObjValue(retData), 8 + A_PtrSize, "Ptr")
			if DllCall("shlwapi\IStream_Reset", "Ptr", stream, "Int") != 0
				|| DllCall("shlwapi\IStream_Read", "Ptr", stream, "Ptr", dataPointer, "UInt", size, "Int") != 0
				throw Error("Could not prepare encoded report")
			contentType := "multipart/form-data; boundary=" boundary
		} finally ObjRelease(stream)
	}

	static FormName(value) => StrReplace(StrReplace(StrReplace(value, "`r"), "`n"), Chr(34), "_")

	static WriteFormText(stream, value) {
		encodedText := Buffer(StrPut(value, "UTF-8"))
		StrPut(value, encodedText, "UTF-8")
		if DllCall("shlwapi\IStream_Write", "Ptr", stream, "Ptr", encodedText, "UInt", encodedText.Size - 1, "Int") != 0
			throw Error("Could not encode report text")
	}
}
