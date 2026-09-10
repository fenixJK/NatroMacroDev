; One live frame per updater may be queued/in flight. Waiting skips capture;
; a later tick captures current data instead of accumulating stale images.
class nm_LiveHoneyDelivery {
	__New(queue, clock := unset) {
		this.Queue := queue, this.Clock := IsSet(clock) ? clock : (() => DllCall("GetTickCount64", "UInt64"))
		this.Destination := 0, this.Owner := {}, this.ID := "", this.InFlight := false, this.Next := 0, this.Blocked := false
	}
	Configure(destination) {
		if this.SameDestination(destination)
			return
		this.Queue.Cancel(this.Owner)
		this.Owner := {}, this.Destination := destination, this.ID := "", this.InFlight := false, this.Next := 0, this.Blocked := false
	}
	SameDestination(destination) {
		if !destination || !this.Destination
			return !destination && !this.Destination
		return destination.url == this.Destination.url && destination.token == this.Destination.token
			&& destination.webhook = this.Destination.webhook
	}
	Ready() => this.Destination && !this.InFlight && !this.Blocked && !this.Queue.Closed && this.Clock.Call() >= this.Next
	Submit(data, kind) {
		if !this.Ready()
			return false
		owner := this.Owner, creating := !this.ID, route := nm_LiveHoneyRoute(this.Destination, this.ID)
		this.InFlight := true
		accepted := false
		try accepted := this.Queue.Enqueue(data, kind, route, this.Destination.token, "Live honey",,
			{method: creating ? "POST" : "PATCH", owner: owner, maxAge: 60000,
				result: (ok, response) => this.Completed(owner, creating, ok, response)})
		finally {
			if !accepted {
				this.InFlight := false
				this.Next := this.Clock.Call() + 60000
			}
		}
		return accepted
	}
	Completed(owner, creating, ok, response) {
		if owner != this.Owner
			return ; disabled/reconfigured sessions cannot adopt an old message ID
		this.InFlight := false
		if ok && (!creating || IsObject(response) && response.HasOwnProp("id") && RegExMatch(response.id, "^[0-9]{1,20}$")) {
			if creating
				this.ID := response.id
			this.Next := 0
		} else {
			; A missing edit target can be recreated from a new frame after backoff.
			if !creating && IsObject(response) && response.status = 404
				this.ID := ""
			this.Next := Max(this.Clock.Call() + 60000, IsObject(response) && response.HasOwnProp("retryAt") ? response.retryAt : 0)
			if ok && creating || IsObject(response) && response.status >= 400 && response.status < 500 && response.status != 408 && response.status != 429 && !(response.status = 404 && !creating)
				this.Blocked := true
			if ok && creating
				nm_Failures.Write(Error("Live honey create succeeded without a usable message ID. Updates paused until the feature or destination is reset."), "Discord delivery")
		}
	}
}

nm_LiveHoneyDestination() {
	global discordMode, webhook, bottoken, MainChannelCheck, MainChannelID
	if discordMode = 0
		return webhook ? {url: webhook, token: "", webhook: true} : 0
	return MainChannelCheck && MainChannelID ? {url: discord.baseURL "channels/" MainChannelID "/messages", token: bottoken, webhook: false} : 0
}

nm_LiveHoneyRoute(destination, id := "") {
	parts := StrSplit(destination.url, "?",, 2), path := parts[1], query := parts.Length > 1 ? parts[2] : ""
	if id {
		if !RegExMatch(id, "^[0-9]{1,20}$")
			throw ValueError("Invalid live message ID")
		path .= (destination.webhook ? "/messages/" : "/") id
	} else if destination.webhook
	{
		query := Trim(RegExReplace(RegExReplace(query, "i)(^|&)wait=[^&]*", "$1"), "&{2,}", "&"), "&")
		query .= (query ? "&" : "") "wait=true"
	}
	return path (query ? "?" query : "")
}
