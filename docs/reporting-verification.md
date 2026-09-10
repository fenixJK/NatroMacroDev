# Automated Discord reporting

Status updates, night announcements, forwarded report JSON, hourly reports and
ordinary Status command replies now use an asynchronous queue. The queue owns encoded message/attachment bytes; callers
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

Automated and simple command embed text uses JSON serialization, including quotes, backslashes and
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
Each helper currently has its own queue. Bot polling, authorization lookups and the
pre-shutdown restart reply still use synchronous requests with bounded waits.
Ordinary command replies and live honey use the Status helper's existing queue. Global
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

- Migrate synchronous bot polling/authorization and coordinate the pre-shutdown
  reply with process exit. Ordinary replies, including structured timer, planter,
  shrine, blender and memory-match displays, now use the common queue.
- Coordinate rate limits and dispatch across helpers, commands and bot polling;
  persist ordinary queued reports with explicit destination identity and recovery.
- Add user-visible pending/failed report management and controlled resend; verify
  configuration changes and normal/abrupt restart while a request is in flight.
- Exercise end-to-end hourly rollover, graph/sample correctness, real Discord
  permissions/limits, long outages and realistic attachment sizes. Current tests
  cover encoding/delivery/persistence, not the full statistics renderer or OCR.
- Run a Windows resource soak for repeated screenshots, failed encoding and reports.

No live Discord or Roblox verification is claimed by this checkpoint.

## Command reply encoding

`SendEmbed` now accepts raw text and uses the same serializer as queued automated
embeds. Its callers use AHK newlines rather than pre-escaped JSON text; window
titles, filenames, error messages, command options and settings are not escaped
twice. Literal backslash-n in user text remains literal, while actual line breaks
remain line breaks. Colors serialize as numbers, descriptions/content retain the
existing length bounds, and attachment references are preserved.

Replies serialize their message reference and disabled parsed mentions through a
shared object builder. Missing-reference fallback remains a JSON boolean. File
and image replies use the same reference builder, and setting-value fields use
bounded, Unicode-safe serialized names/values with `<blank>` for an empty value.
Reply IDs must be decimal strings of at most 20 digits. These encoding changes
preserve the base library's synchronous delivery and response value. Status now
uses the queued command adapter described below; queue acceptance is not an HTTP
acknowledgement.

Windows regression tests invoke the actual `SendEmbed` and missing-file caller
with only HTTP transport replaced. They check quotes, backslashes, actual and
literal newlines, control characters, Unicode, explicit channel, reply metadata,
setting fields and invalid IDs. Existing multipart/loopback tests still cover the
shared encoder and queued transport. Live Discord behavior and delivery
coordination remain open.

Useful, advanced, priority and settings help now build objects and serialize them.
All aliases use the current prefix, including prefixes with quotes/backslashes.
The useful-command screenshot description reflects the Roblox default and desktop
permission; debug help describes the redacted report. Settings lists retain their
section headings, include only entries with a supported setter, and paginate
without a ten-page ceiling or truncating settings. Pages split at newlines where
possible and preserve Unicode pairs when a single line exceeds the description
limit. Page titles show position, the first page replies to the command, and all
pages disable parsed mentions. Regression tests cover more than ten pages and
verify every eligible setting appears exactly once, including the last page.
Status submits each page through the command queue. The encoding tests alone do
not prove multi-page delivery through a Discord outage or rate limit; queue capacity
can reject later pages, recording those failed handoffs locally.

Planter, timer, blender, shrine and memory-match displays now use shared report
builders. They accept one supplied settings snapshot and timestamp without writing
state. Dynamic names, fields and prefixes are serialized; numeric catalog colors
outside the valid 24-bit range use the normal report color. Missing/invalid timer
values display Unknown rather than silently becoming Ready. Monster respawn
modifiers apply only to mobs. Planter hold/smoking states apply only in manual mode,
after the recorded growth timer expires. Shrine reports read the current rotation
from the supplied snapshot and wrap across its two slots. Remote shrine ready/clear
commands now reject a nonexistent third slot; they no longer fall through into an
unset report-body send after their simple reply.

Reports reuse one attachment for a shared catalog bitmap and generate unique
filenames with consecutive file indexes, independent of empty slots or repeated
item names. The shared multipart encoder copies the borrowed images; the report
does not dispose catalog bitmaps. Reports without icons use a JSON body. Live honey
updates serialize their image/color and explicit empty attachment list; their
asynchronous post/edit behavior is described below.

Regression tests cover sparse/repeated planter slots, hold/smoking/ready timing,
blender Infinite/exhausted slots and invalid colors, shrine rotation, enabled timer
groups and mob modifiers, missing timer values, memory-match ignore masks, raw
quoted/Unicode values, attachment references and live-honey payload metadata.
The real Windows multipart encoder runs on fixture GDI bitmaps, whose continued
validity is checked afterward. HTTP transport is replaced; live game accuracy,
current artwork, Discord rendering and delivery remain unverified. Structured
field text is bounded to platform-sized fields; this is not arbitrary-size report
pagination or an atomic cross-process settings snapshot.

## Live honey delivery

Live honey creation and edits now use the same outbox as Status reports. The queue
supports POST/PATCH and an optional result callback while preserving existing
boolean completion callbacks. The HTTP adapter extracts a decimal message ID from
JSON response text up to 65,536 characters before the updater may edit it; larger
bodies do not provide an ID. One frame may be queued or
in flight; subsequent ticks skip capture rather than retaining more images. When
that request finishes, a later tick captures current data. Encoded image bytes
belong to the queue after preparation, and the source bitmap is released.

Each active period/destination has its own identity. Disablement, inactive honey
status, or a changed endpoint/token marks old work cancelled and clears the ID.
Old callbacks cannot adopt an ID for the new session. Cancelled work is consumed
by the queue when reached and active requests are aborted when cancellation is
pumped; an external request already delivered cannot be undone. Destination and
enablement are checked again after image preparation before submission. Webhook
query parameters remain after the message path, and creation requests wait=true.

Live frames have a one-minute age limit, checked when pumped, and use the existing
twenty-second request timeout/five-attempt policy. Expiry/exhaustion imposes a
one-minute fresh-frame backoff and retains any longer server retry deadline.
Deleted edit targets clear the ID and may be recreated after backoff. Permanent
4xx failures pause the session (except retryable 408/429 and a missing edit target).
A successful create without a usable ID also pauses the session and records the
uncertainty instead of repeatedly creating messages. A new active period or
destination resets that session pause. Closed queues reject further frames.

Scripted tests cover single-frame ownership, create/edit transitions, destination
changes, late receipts, cancellation, missing IDs, permanent errors, deleted
messages, closed queues and a five-minute server retry delay across frame expiry.
A loopback fixture independently checks actual POST/PATCH methods and frame bodies
and returns a message ID consumed by the native WinHTTP adapter. It does not contact
Discord. Legacy queue, report and attachment tests remain in the full suite.

This remains an in-memory delivery protocol. A lost POST response may create a
duplicate during bounded retries, and restart loses the message ID. Cancellation
does not revoke an already delivered request. Native calls and delayed queue pumps
make timing cooperative, and synchronous bot polling/authorization, shutdown
notification and command actions can still delay work.
Cross-helper rate coordination, durable receipts/recovery, live Discord behavior,
game capture accuracy and measured resource/performance effects remain open.

## Upload source ownership

`SendFile` preserves caller-owned source files on success, rejection and preparation
or delivery failure, including files under the Windows temp directory. Location
alone no longer marks a source as disposable. Folder uploads create an exclusively
owned GUID directory and remove only that directory after use. They cannot replace
or delete an unrelated ZIP at the old predictable temp filename.

The local folder archive helper runs a fixed encoded PowerShell script and passes
source/destination paths as ASCII JSON on stdin. `Compress-Archive -LiteralPath`
handles brackets, apostrophes, Unicode and PowerShell metacharacters as path data.
It archives the folder, including its root entry. The helper observes a cooperative
45-second deadline and polls output size while running; the sender checks the final
10 MiB limit. Polling does not enforce a hard byte or time bound. Normal cleanup
terminates a running worker before removing its owned files, retaining the directory
if the worker cannot be confirmed stopped. Ordinary exit also attempts cleanup.

Windows tests invoke actual archive creation and multipart preparation, replacing
only HTTP delivery. They verify source preservation, oversized-file rejection,
encoding/delivery failures, a pre-existing legacy ZIP collision, a literal path
with Unicode/metacharacters, a ZIP signature, and cleanup after success and failure.
Archive creation uses the system Windows PowerShell executable on both AHK
architectures; no Discord request is sent.

Remote upload permissions still permit individual files only. This helper retains
the library's existing local folder capability. Base-library delivery and archive
preparation remain synchronous; Status hands encoded file bytes to the command
queue. Abrupt parent termination can orphan the WScript archive worker
or its temporary files; kernel-owned worker migration remains work. Archive source
contents are not a filesystem snapshot, and this is not a reparse-point sandbox.

## Command reply delivery

Status uses `nm_DiscordCommandReply` for ordinary replies: embeds, help pages,
setting values, structured reports, screenshots, individual-file uploads, attachment
completion messages and item-search responses. The adapter reuses the base payload
builders and the same outbox as Status/live honey. It returns queue acceptance
without creating a request or waiting for a response. It snapshots endpoint and
token at handoff; later configuration changes do not reroute queued replies.
JSON references and disabled parsed mentions retain their existing behavior.

File and image preparation finishes before queue handoff, so encoded bytes survive
source bitmap disposal, file changes and archive cleanup. The item-search screenshot
also releases its bitmap if encoding or handoff throws. `SendImage` now returns its
transport result, allowing queued callers to observe acceptance. Full or closed
queues reject and log the handoff; Status does not retry the underlying command
action when its reply cannot be queued. Acceptance does not mean delivery, and a
delayed reply may describe an action performed earlier.

The existing queue supplies bounded capacity, retries, timeout, age expiry and
failure logging. Native HTTP tests submit through the production command adapter,
hold the server response behind a gate and release it only after polling returns.
Scripted tests check shared queue identity, reply references, fractional 429 delay,
destination/token snapshots, help/settings/report handoffs, source lifetime,
capacity rejection and closed queues. No Discord command or game action is sent.

The system-restart notification intentionally retains its bounded synchronous
attempt before shutdown. General library callers retain the old synchronous API.
Bot polling/member lookups, capture/encoding, local archive preparation and command
actions can still block helper progress. Pending replies share the queue's FIFO
ordering with other reports, so an earlier retry delay can hold later replies.
This is not full asynchronous command execution or durable delivery: abrupt exit
can lose queued replies, and retries after a lost response can duplicate messages.
Cross-helper/global rate coordination, preserving server delays across distinct
jobs, shutdown/restart recovery and live verification remain work.

## Counter consistency

The main macro uses one increment helper for boss kills, Vicious kills, normal
bugs, planters, quests and disconnects. An increment of two now adds two to both
the lifetime and session values and sends two to StatMonitor. The helper maps the
planter and quest categories to the existing `PlantersCollected` and
`QuestsComplete` INI keys. It validates the category, amount and current totals
before writing; zero does nothing. Negative, fractional, oversized or overflowing
increments are rejected. StatMonitor independently rejects invalid message IDs
and amounts instead of indexing outside its six counters or wrapping a total.

The helper writes the lifetime and session keys before updating memory and posting
the monitor message. The regression suite invokes this production helper for all
six categories, checks saved values at the dispatch boundary, and passes the
message values to the production receiver logic. It also exercises a real first
INI-write failure and verifies that it cannot update memory or publish an
increment. This fixture replaces message transport; it does not prove native
cross-process delivery or hourly rollover behavior.

The two INI writes are **not one crash-atomic transaction**. Failure after the first
write can leave a partial saved pair, and a process crash or absent monitor can
lose a posted increment. Durable receipts, a shared state writer, reset/rollover
coordination and restart reconciliation remain work. These changes preserve the
existing event triggers and quantities, including inferred bug kills and the
legacy planter completion branches; consistent counters do not establish that
those game events actually happened.
