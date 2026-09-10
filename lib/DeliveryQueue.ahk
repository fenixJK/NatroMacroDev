; One asynchronous request at a time. Payloads own their encoded bytes, never a
; borrowed bitmap pointer. A successful enqueue transfers ownership to this queue.
#Include "DeliveryCooldown.ahk"
class nm_DeliveryQueue {
	__New(factory := unset, clock := unset, failure := unset, cooldown := unset) {
		this.Factory := IsSet(factory) ? factory : nm_HttpDelivery
		this.Clock := IsSet(clock) ? clock : (() => DllCall("GetTickCount64", "UInt64"))
		this.Failure := IsSet(failure) ? failure : ((job, reason) => 0)
		this.Cooldown := IsSet(cooldown) ? cooldown : nm_DeliveryCooldown(!IsSet(factory) && !IsSet(clock))
		this.Items := [], this.Bytes := 0, this.Busy := false, this.Closed := false
		this.Limit := 100, this.ByteLimit := 32 * 1024 * 1024
		this.Timeout := 20000, this.MaxAttempts := 5, this.MaxAge := 3600000
	}

	Enqueue(data, contentType, url, token := "", label := "Report", completed := unset, options := unset) {
		options := IsSet(options) ? options : {}
		method := options.HasOwnProp("method") ? options.method : "POST"
		if method != "POST" && method != "PATCH"
			throw ValueError("Unsupported queued HTTP method")
		bytes := nm_DeliveryPayloadSize(data)
		job := {data: data, contentType: contentType, url: url, token: token,
			label: label, bytes: bytes, attempts: 0, created: this.Clock.Call(),
			next: 0, request: 0, started: 0, completed: IsSet(completed) ? completed : 0, method: method,
			result: options.HasOwnProp("result") ? options.result : 0, owner: options.HasOwnProp("owner") ? options.owner : 0,
			maxAge: options.HasOwnProp("maxAge") ? options.maxAge : this.MaxAge, cancelled: false}
		if this.Closed || this.Items.Length >= this.Limit || bytes > this.ByteLimit - this.Bytes {
			this.Failure.Call(job, "Queue capacity reached; report was not queued")
			return false
		}
		this.Items.Push(job), this.Bytes += bytes
		return true
	}

	Cancel(owner) {
		for job in this.Items
			if job.owner == owner
				job.cancelled := true
	}

	Pump() {
		if this.Busy
			return
		this.Busy := true
		try {
			this.Cooldown.Flush()
			if !this.Items.Length
				return
			job := this.Items[1], current := this.Clock.Call()
			if job.cancelled {
				this.Finish(job, false, "Cancelled")
				return
			}
			if current - job.created >= Min(this.MaxAge, job.maxAge) {
				this.Finish(job, false, "Delivery expired before confirmation")
				return
			}
			if !job.request {
				try job.next := Max(job.next, this.Cooldown.Deadline(job, current))
				catch {
					this.Retry(job, current, 0, "Rate-limit coordination unavailable")
					return
				}
				if current < job.next
					return
				job.attempts++, job.started := current
				try job.request := this.Factory.Call(job)
				catch {
					this.Retry(job, current, 0, "Network request could not start")
					return
				}
			}
			try response := job.request.Poll()
			catch {
				this.Retry(job, current, 0, "Network request failed")
				return
			}
			current := this.Clock.Call() ; response handling may have consumed time
			if !IsObject(response) {
				if current - job.started >= this.Timeout
					this.Retry(job, current, 0, "Network request timed out; delivery is uncertain")
				return
			}
			if response.status = 429
				job.next := Max(job.next, this.Cooldown.Defer(job, current, response.retryAfter))
			if job.cancelled
				this.Finish(job, false, "Cancelled")
			else if response.status >= 200 && response.status < 300
				this.Finish(job, true,, response)
			else if response.status = 429 || response.status = 408 || response.status >= 500
				this.Retry(job, current, response.status = 429 ? response.retryAfter : 0, "HTTP " response.status)
			else
				this.Finish(job, false, "HTTP " response.status "; automatic retry stopped", response)
		} finally this.Busy := false
	}

	Retry(job, current, retryAfter, reason) {
		this.Abort(job)
		delay := Max(1000 * 2 ** job.attempts, IsNumber(retryAfter) ? retryAfter * 1000 : 0)
		job.next := Max(job.next, current + delay)
		if job.attempts >= this.MaxAttempts {
			this.Finish(job, false, reason "; attempt limit reached")
			return
		}
		; Never shorten a server-requested delay. Age expiry bounds retention even
		; when Discord asks us to wait longer than the remaining queue lifetime.
	}

	Abort(job) {
		if job.request
			try job.request.Abort()
		job.request := 0
	}

	Finish(job, delivered, reason := "", response := 0) {
		this.Abort(job)
		; Record failure before removing the only in-memory copy.
		if !delivered && reason != "Cancelled"
			this.Failure.Call(job, reason)
		this.Items.RemoveAt(1), this.Bytes -= job.bytes
		if job.completed
			job.completed.Call(delivered)
		if job.result {
			if !IsObject(response)
				response := {status: 0, id: ""}
			response.retryAt := job.next
			job.result.Call(delivered, response)
		}
	}

	Close() {
		this.Closed := true
		while this.Items.Length
			this.Finish(this.Items[1], false, "Helper stopped before delivery was confirmed")
	}
}

nm_DeliveryPayloadSize(data) {
	if Type(data) = "String"
		return StrPut(data, "UTF-8") - 1
	if Type(data) != "ComObjArray"
		throw TypeError("Delivery payload must be text or encoded bytes")
	return data.MaxIndex() - data.MinIndex() + 1
}

class nm_HttpDelivery {
	__New(job) {
		this.Request := wr := ComObject("WinHttp.WinHttpRequest.5.1")
		wr.Option[9] := 2720
		wr.Option[6] := false ; do not forward a bot credential through redirects
		wr.SetTimeouts(5000, 5000, 10000, 10000)
		this.WantResult := job.result
		wr.Open(job.method, job.url, true)
		wr.SetRequestHeader("Content-Type", job.contentType)
		if job.token {
			wr.SetRequestHeader("User-Agent", "DiscordBot (AHK, " A_AhkVersion ")")
			wr.SetRequestHeader("Authorization", "Bot " job.token)
		}
		wr.Send(job.data)
	}

	Poll() {
		if !this.Request.WaitForResponse(0)
			return 0
		delay := 0
		if this.Request.Status = 429 {
			try {
				body := JSON.parse(this.Request.ResponseText)
				if body.Has("retry_after") && IsNumber(body["retry_after"])
					delay := Max(0, body["retry_after"])
			}
			try {
				header := this.Request.GetResponseHeader("Retry-After")
				if IsNumber(header)
					delay := Max(delay, header)
			}
			if !delay
				delay := 60
		}
		messageID := ""
		if this.WantResult && this.Request.Status >= 200 && this.Request.Status < 300 {
			try {
				text := this.Request.ResponseText
				if StrLen(text) <= 65536 {
					body := JSON.parse(text)
					if body is Map && body.Has("id") && Type(body["id"]) = "String" && RegExMatch(body["id"], "^[0-9]{1,20}$")
						messageID := body["id"]
				}
			}
		}
		return {status: this.Request.Status, retryAfter: delay, id: messageID}
	}

	Abort() => this.Request.Abort()
}
