#Include "DeliveryQueue.ahk"
#Include "RuntimePolicy.ahk"
#Include "FailureLog.ahk"

; One bounded asynchronous GET at a time. Commands remain local until their
; current identity/role check is ready; no game action runs in a callback.
class nm_BotInbox {
	__New(commands, queue := unset, clock := unset, log := unset, baseURL := "https://discord.com/api/v10/") {
		this.Commands := commands, this.Queue := IsSet(queue) ? queue : nm_DeliveryQueue()
		this.Clock := IsSet(clock) ? clock : (() => DllCall("GetTickCount64", "UInt64"))
		this.Log := IsSet(log) ? log : ((message) => nm_Failures.Write(Error(message), "Discord commands"))
		this.BaseURL := baseURL, this.Config := 0, this.Owner := 0, this.Pending := false
		this.Closed := false, this.Busy := false, this.Blocked := false
		this.Next := 0, this.Cursor := "", this.Guild := "", this.Failures := 0, this.Invalid := 0, this.PageLimit := 100
		this.CommandAge := 60000, this.RoleAge := 5000
		this.Queue.Limit := 1, this.Queue.MaxAge := 20000, this.Queue.Timeout := 10000, this.Queue.MaxAttempts := 3
	}
	static ID(value) => Type(value) = "String" && RegExMatch(value, "^[0-9]{17,20}$")
	static SameID(a, b) => nm_BotInbox.ID(a) && nm_BotInbox.ID(b) && StrCompare(a, b, true) = 0
	static Same(a, b) {
		if !IsObject(a) || !IsObject(b)
			return !IsObject(a) && !IsObject(b)
		for name in ["token", "channel", "prefix", "allowed"]
			if !(a.%name% == b.%name%)
				return false
		return true
	}
	Configure(config) {
		if IsObject(config) && (!config.token || !nm_BotInbox.ID(config.channel) || !config.prefix)
			config := 0
		if this.Closed || nm_BotInbox.Same(this.Config, config)
			return
		if this.Owner
			this.Queue.Cancel(this.Owner)
		this.Config := IsObject(config) ? config.Clone() : 0, this.Owner := {}
		this.Commands.Length := 0, this.Cursor := "", this.Guild := "", this.Pending := false
		this.Next := 0, this.Failures := 0, this.Invalid := 0, this.Blocked := false, this.PageLimit := 100
	}
	Ready(command) {
		if !IsObject(this.Config) || this.Blocked
			return false
		if !command.HasOwnProp("owner") || command.owner != this.Owner
			return true ; dispatch rejects foreign/unowned commands instead of stalling
		if SubStr(this.Config.allowed, 1, 1) != "&"
			return true
		return command.HasOwnProp("authAt") && this.Clock.Call() - command.authAt <= this.RoleAge
	}
	Authorized(command, config) {
		if !nm_BotInbox.Same(this.Config, config) || !command.HasOwnProp("owner") || command.owner != this.Owner
			return false
		if this.Clock.Call() - command.received >= this.CommandAge || !this.Ready(command)
			return false
		return nm_CommandAuthorized(config.allowed, command.user_id,
			SubStr(config.allowed, 1, 1) = "&" && command.HasOwnProp("roles") ? command.roles : 0)
	}
	Pump() {
		if this.Busy || this.Closed
			return
		this.Busy := true
		try {
			this.Queue.Pump()
			if !IsObject(this.Config) || this.Blocked || this.Pending
				return
			current := this.Clock.Call()
			while this.Commands.Length && current - this.Commands[1].received >= this.CommandAge {
				this.Commands.RemoveAt(1)
				this.Log.Call("Queued command expired before dispatch")
			}
			if this.Commands.Length && this.Ready(this.Commands[1])
				return
			if current < this.Next
				return
			if this.Commands.Length {
				command := this.Commands[1]
				if this.Guild
					this.Read("member", "guilds/" this.Guild "/members/" command.user_id, command)
				else
					this.Read("channel", "channels/" this.Config.channel, command)
			} else
				this.Read("messages", "channels/" this.Config.channel "/messages" (this.Cursor = "" ? "?limit=1" : "?after=" this.Cursor "&limit=" this.PageLimit))
		} finally this.Busy := false
	}
	Read(kind, path, command := 0) {
		owner := this.Owner
		this.Pending := this.Queue.Enqueue("", "application/json", this.BaseURL path, this.Config.token, "Discord command read",,
			{method: "GET", owner: owner, responseLimit: 1048576, result: ObjBindMethod(this, "Completed", owner, kind, command)})
		if !this.Pending
			this.Next := this.Clock.Call() + 1000
	}
	Completed(owner, kind, command, ok, response) {
		if this.Closed || owner != this.Owner
			return
		this.Pending := false
		if !ok {
			this.Failed(kind, command, response.status, response.retryAt)
			return
		}
		try {
			if kind = "messages" && this.Cursor != "" && this.PageLimit > 1 && response.HasOwnProp("bodyValid") && !response.bodyValid {
				this.PageLimit := Max(1, this.PageLimit // 2), this.Next := this.Clock.Call() + 1000
				this.Log.Call("Discord message page unavailable; retrying a smaller page")
				return
			}
			if !response.HasOwnProp("bodyValid") || !response.bodyValid
				throw Error("Missing or oversized response")
			body := JSON.parse(response.text)
			switch kind {
				case "messages": this.Messages(body)
				case "channel":
					if !(body is Map) || !nm_BotInbox.SameID(body.Get("id", ""), this.Config.channel) || !nm_BotInbox.ID(body.Get("guild_id", ""))
						throw Error("Invalid channel identity")
					this.Guild := body["guild_id"]
				case "member":
					if !(body is Map) || !(body.Get("user", 0) is Map) || !nm_BotInbox.SameID(body["user"].Get("id", ""), command.user_id)
						throw Error("Invalid member identity")
					roles := body.Get("roles", 0)
					if !(roles is Array) || roles.Length > 512
						throw Error("Invalid member roles")
					for role in roles
						if !nm_BotInbox.ID(role)
							throw Error("Invalid role identity")
					command.roles := roles, command.authAt := this.Clock.Call()
			}
			this.Failures := 0, this.Invalid := 0, this.Next := this.Clock.Call() + (kind = "messages" ? 1000 : 0)
		} catch {
			this.Failed(kind, command, 0, 0, true)
		}
	}
	Failed(kind, command, status, retryAt, invalid := false) {
		this.Failures++
		this.Invalid := invalid ? this.Invalid + 1 : 0
		this.Next := Max(this.Clock.Call() + Min(60000, 1000 * 2 ** Min(this.Failures, 6)), retryAt)
		this.Log.Call("Discord " kind " request failed" (status ? " (HTTP " status ")" : " or returned unusable data"))
		if kind != "messages" && command
			command.roles := [], command.authAt := this.Clock.Call()
		if status = 401 || status = 403 || (kind != "member" && status = 404) || this.Invalid >= 5 {
			this.Blocked := true, this.Commands.Length := 0
			this.Log.Call("Discord command polling paused; reconfigure or restart the helper to retry")
		}
	}
	static CompareID(a, b) => StrLen(a) != StrLen(b) ? StrLen(a) - StrLen(b) : StrCompare(a, b, true)
	static Fresh(stamp) {
		if Type(stamp) != "String" || !RegExMatch(stamp, "^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|\+00:00)$", &parts)
			return false
		try {
			age := DateDiff(A_NowUTC, parts[1] parts[2] parts[3] parts[4] parts[5] parts[6], "Seconds")
			return age >= -60 && age <= 300
		} catch
			return false
	}
	Messages(body) {
		if !(body is Array) || body.Length > 100 || (this.Cursor = "" && body.Length > 1)
			throw Error("Invalid message page")
		ordered := [], seen := Map()
		for message in body {
			if !(message is Map) || !nm_BotInbox.ID(message.Get("id", "")) || !nm_BotInbox.SameID(message.Get("channel_id", ""), this.Config.channel)
				throw Error("Invalid message identity")
			id := message["id"]
			if seen.Has(id)
				continue
			seen[id] := true
			author := message.Get("author", 0), content := message.Get("content", ""), attachments := message.Get("attachments", [])
			if !(author is Map) || !nm_BotInbox.ID(author.Get("id", "")) || Type(content) != "String" || StrLen(content) > 10000 || !(attachments is Array)
				throw Error("Invalid message data")
			url := ""
			if attachments.Length {
				if !(attachments[1] is Map) || Type(attachments[1].Get("url", 0)) != "String" || StrLen(attachments[1]["url"]) > 4096
					throw Error("Invalid message attachment")
				url := attachments[1]["url"]
			}
			entry := {id: id, content: Trim(content), user_id: author["id"], url: url, owner: this.Owner, received: this.Clock.Call(),
				eligible: !author.Get("bot", false) && !message.Has("webhook_id") && (message.Get("type", 0) = 0 || message.Get("type", 0) = 19)}
			entry.fresh := nm_BotInbox.Fresh(message.Get("timestamp", ""))
			position := 1
			while position <= ordered.Length && nm_BotInbox.CompareID(ordered[position].id, id) < 0
				position++
			ordered.InsertAt(position, entry)
		}
		; First read establishes a watermark; historical commands are not replayed.
		if this.Cursor = "" {
			this.Cursor := ordered.Length ? ordered[ordered.Length].id : "0"
			return
		}
		for entry in ordered {
			if nm_BotInbox.CompareID(entry.id, this.Cursor) <= 0
				continue
			if entry.eligible && SubStr(entry.content, 1, StrLen(this.Config.prefix)) = this.Config.prefix {
				if !entry.fresh {
					this.Log.Call("Ignored command with an old, future or invalid timestamp")
					this.Cursor := entry.id
					continue
				}
				if this.Commands.Length >= 100
					break ; leave the cursor before the first unadmitted command
				this.Commands.Push(entry)
			}
			this.Cursor := entry.id
		}
	}
	Close() {
		this.Closed := true, this.Owner := 0, this.Commands.Length := 0
		this.Queue.Close()
	}
}
