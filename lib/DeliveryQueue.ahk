; One asynchronous request at a time. Payloads own their encoded bytes, never a
; borrowed bitmap pointer. A successful enqueue transfers ownership to this queue.
class nm_DeliveryQueue {
	__New(factory := unset, clock := unset, failure := unset) {
		this.Factory := IsSet(factory) ? factory : nm_HttpDelivery
		this.Clock := IsSet(clock) ? clock : (() => DllCall("GetTickCount64", "UInt64"))
		this.Failure := IsSet(failure) ? failure : ((job, reason) => 0)
		this.Items := [], this.Bytes := 0, this.Busy := false
		this.Limit := 100, this.ByteLimit := 32 * 1024 * 1024
		this.Timeout := 20000, this.MaxAttempts := 5, this.MaxAge := 3600000
	}

	Enqueue(data, contentType, url, token := "", label := "Report", completed := unset) {
		bytes := nm_DeliveryPayloadSize(data)
		job := {data: data, contentType: contentType, url: url, token: token,
			label: label, bytes: bytes, attempts: 0, created: this.Clock.Call(),
			next: 0, request: 0, started: 0, completed: IsSet(completed) ? completed : 0}
		if this.Items.Length >= this.Limit || bytes > this.ByteLimit - this.Bytes {
			this.Failure.Call(job, "Queue capacity reached; report was not queued")
			return false
		}
		this.Items.Push(job), this.Bytes += bytes
		return true
	}

	Pump() {
		if this.Busy || !this.Items.Length
			return
		this.Busy := true
		try {
			job := this.Items[1], current := this.Clock.Call()
			if current - job.created >= this.MaxAge {
				this.Finish(job, false, "Delivery expired after one hour")
				return
			}
			if !job.request {
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
			if !IsObject(response) {
				if current - job.started >= this.Timeout
					this.Retry(job, current, 0, "Network request timed out; delivery is uncertain")
				return
			}
			if response.status >= 200 && response.status < 300
				this.Finish(job, true)
			else if response.status = 429 || response.status = 408 || response.status >= 500
				this.Retry(job, current, response.status = 429 ? response.retryAfter : 0, "HTTP " response.status)
			else
				this.Finish(job, false, "HTTP " response.status "; automatic retry stopped")
		} finally this.Busy := false
	}

	Retry(job, current, retryAfter, reason) {
		this.Abort(job)
		if job.attempts >= this.MaxAttempts {
			this.Finish(job, false, reason "; attempt limit reached")
			return
		}
		; Never shorten a server-requested delay. Age expiry bounds retention even
		; when Discord asks us to wait longer than the remaining queue lifetime.
		delay := Max(1000 * 2 ** job.attempts, IsNumber(retryAfter) ? retryAfter * 1000 : 0)
		job.next := current + delay
	}

	Abort(job) {
		if job.request
			try job.request.Abort()
		job.request := 0
	}

	Finish(job, delivered, reason := "") {
		this.Abort(job)
		; Record failure before removing the only in-memory copy.
		if !delivered
			this.Failure.Call(job, reason)
		this.Items.RemoveAt(1), this.Bytes -= job.bytes
		if job.completed
			job.completed.Call(delivered)
	}

	Close() {
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
		wr.Open("POST", job.url, true)
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
		return {status: this.Request.Status, retryAfter: delay}
	}

	Abort() => this.Request.Abort()
}
