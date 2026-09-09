# Automated Discord reporting

Status updates, night announcements, forwarded report JSON and hourly reports now
use an asynchronous queue. The queue owns encoded message/attachment bytes; callers
can release the source bitmap after preparation. A status entry leaves its input
buffer only after the outbox accepts it (or its destination is disabled).

The queue holds at most 100 encoded reports and 32 MiB per helper, with one active
request, five attempts per report, a 20-second request deadline and a one-hour
retention limit. Network failures, HTTP 408/5xx and HTTP 429 are retryable. Other
non-2xx responses stop automatic retries. Exponential backoff does not shorten
Discord's requested `retry_after`/`Retry-After` delay. A report can expire while
waiting for a longer server delay; expiry does not send it early.

HTTP success is the acknowledgement boundary. Webhook requests use `wait=true`,
which asks Discord to confirm persistence. See the official
[webhook contract](https://docs.discord.com/developers/resources/webhook) and
[rate-limit guidance](https://docs.discord.com/developers/topics/rate-limits).
The Windows adapter polls with `WaitForResponse(0)` and aborts expired requests;
Microsoft documents that a timed-out wait alone does not abort a request in
[WaitForResponse](https://learn.microsoft.com/en-us/windows/win32/winhttp/iwinhttprequest-waitforresponse).

Automated embed text uses JSON serialization, including quotes, backslashes and
control characters. Description/content lengths are bounded without splitting a
UTF-16 surrogate pair. Night announcement names/URLs are serialized too. Attachment
encoding uses explicit CRLF boundaries and checked stream operations, and releases
input/output streams on success and failure. Missing files or invalid images fail
preparation instead of silently producing an incomplete attachment.

## Retention and recovery

Hourly reports are saved in `settings/pending-reports` before the sample window is
advanced. Successful delivery removes the pending PNG and its note. Failure or
helper shutdown leaves the PNG for manual review/resend. Pending storage is limited
to 72 PNGs and 256 MiB; reaching the limit prevents a new report handoff instead of
silently deleting older reports. Pending images are not automatically resent after
restart. A recovery interface and destination-aware durable outbox remain work.

Other exhausted/expired reports and queue overflow are recorded through the existing
bounded local failure logger in `settings/errors`. Log entries include the status
label and, for JSON-only requests, payload text. Endpoint URLs and Authorization
headers are excluded; the logger also redacts known webhook/private-server patterns.
Ordinary status screenshots are not retained on disk. Status input is capped at
1,000 entries, with overflow text recorded locally.

The outbox itself is in memory. Normal exit records unconfirmed items locally;
abrupt process termination can lose ordinary queued statuses/images. A lost HTTP
response can also cause a duplicate on retry: this is not exactly-once delivery.
Each helper currently has its own queue, and legacy bot polling/command replies and
live honey message edits still use synchronous requests with bounded waits. Global
rate-limit coordination across those paths remains open.

## Verification scope

The Windows suite executes the production queue against controlled responses for
fractional rate-limit delays, 5xx/network recovery, live-request polling, timeout
abort, permanent errors, retry/age limits, count/byte limits and shutdown.
Production hourly report preparation runs against real GDI bitmaps and temporary
files to verify acknowledgement cleanup and failure retention.

A loopback-only PowerShell HTTP fixture exercises the actual WinHTTP adapter. It
delays JSON responses to verify nonblocking polling and independently parses JSON.
It also validates multipart CRLF framing, JSON and the PNG part after the source
bitmap has been disposed. No test contacts Discord or uses real credentials.

Still required for F23 and the broader production plan:

- Migrate legacy command payload builders/escaped `SendEmbed` call sites and live
  honey edits to the raw-text serializer and common delivery contract.
- Coordinate rate limits and dispatch across helpers, commands and bot polling;
  persist ordinary queued reports with explicit destination identity and recovery.
- Add user-visible pending/failed report management and controlled resend; verify
  configuration changes and normal/abrupt restart while a request is in flight.
- Exercise end-to-end hourly rollover, graph/sample correctness, real Discord
  permissions/limits, long outages and realistic attachment sizes. Current tests
  cover encoding/delivery/persistence, not the full statistics renderer or OCR.
- Run a Windows resource soak for repeated screenshots, failed encoding and reports.

No live Discord or Roblox verification is claimed by this checkpoint.
