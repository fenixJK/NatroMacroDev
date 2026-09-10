# Remote command permissions

Discord commands still require the configured user or role. Empty authorization
and failed role lookup deny commands. Optional permissions are additional checks,
not an alternative to that identity check.

Open **Status > Permissions** locally. All seven optional permissions start off,
including on existing installations. Save applies to subsequent command dispatches
without restarting Status. The permission button remains enabled while the macro
runs. Cancel leaves the saved permissions unchanged. Revocation cannot undo an
already dispatched action.

| Local permission | Commands it enables |
| --- | --- |
| Desktop screenshots | `ss`/`screenshot` modes All, Window and Screen |
| Desktop control | `send`, `click`, `close`, `activate`, `minimise`/`minimize` |
| File uploads | `upload` of a single existing file |
| Receive attachments | `download` into `settings/remote-inbox` |
| System restart | `restart` |
| Diagnostics | `log`, `debug`/`debuglog` |
| Personal commands | Locally installed command names outside the built-in list |

Normal macro commands remain available to the authorized identity. The default
`ss` mode is Roblox. It requires a visible, focused Roblox client and checks client
geometry and focus again after capture; missing/hidden/unfocused Roblox and invalid
modes never fall back to a desktop screenshot. Re-selecting Roblox mode remains
available after desktop permission is revoked.

The mask is stored separately in `settings/remote_permissions.ini`, outside the
remote settings registry. Missing, unreadable or malformed values disable all
optional permissions. Generic remote `get` refuses permission/authentication,
token, webhook and private-server keys.

Remote downloads no longer accept a destination directory. They use a generated
filename inside a dedicated inbox, without opening or executing it. This avoids
using attachment receipt to replace macro scripts or permission settings. Remote
uploads reject directories and wildcard paths, so they cannot invoke the legacy
directory sender's shell archive command. The known main settings, permission and
bot-auth INI filenames are rejected too.

These are capability boundaries, not a sandbox or comprehensive secret detector.
Desktop input and locally installed personal commands can provide full computer
control. File uploads and diagnostics can expose private information; the filename
filter cannot identify every secret-bearing file or renamed copy. Personal command
source is trusted local code loaded by the existing extension mechanism. The new
gate restricts its command dispatch, not arbitrary code someone installs locally.

## Verification and remaining work

Regression coverage checks default denial, aliases, independent grants, immediate
revocation, malformed masks, private settings and single-file validation.
Windows integration opens the actual permission window, saves/reopens
and cancels changes, captures an owned active GUI with exact client dimensions,
and checks missing Roblox, invalid modes and revocation without desktop fallback.
Tests use temporary settings directories and do not contact Discord.

Live Discord role changes, permission UX at multiple DPI settings, Roblox captures,
occluding windows and command interactions remain unverified. Automated game and
report captures elsewhere in the program are separate from the direct screenshot
command and still require their own capture audit. Inbox path checks are not a filesystem sandbox
against locally created links or concurrent local filesystem changes.

## Attachment receiving

The Status helper starts one Windows PowerShell worker at a time and polls its
completion while continuing its ordinary loop. Further attachment commands get a
busy response. A URL is sent through shared memory as JSON, never evaluated as shell code
or placed on the process command line. The worker accepts HTTPS attachment URLs
on `cdn.discordapp.com` and `media.discordapp.net`, disables automatic redirects,
and does not send bot credentials or browser cookies. Other hosts require a code
change, not an implicit redirect or fallback.

Downloads stream in 64 KiB chunks into an exclusively created temporary file.
Limits are 25 MiB per attachment, 250 MiB total inbox data (including abandoned
partials), and 200 files. A shared inbox lock prevents two cooperating workers
from racing the quota checks. Existing files are never automatically deleted to
make space. The owner can inspect and clear the inbox locally when it is full.

One 30-second monotonic deadline covers headers and body reads. This explicitly
handles the fact that HttpClient's normal timeout with ResponseHeadersRead only
covers headers; see [Microsoft's documentation](https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpcompletionoption).
Only HTTP 200, a completed stream and a matching Content-Length when provided
allow publication. The file is flushed and moved into its final name in the same
inbox without overwrite. The code checks received bytes even when the server
omits Content-Length. It does not buffer an entire response in memory.

Normal failures attempt to clean temporary data. The Status helper has a polled
45-second watchdog including startup. After confirming the worker has stopped,
it polls a contained receiving-cleanup helper for up to twenty seconds. Shutdown
gives cleanup a five-second grace period; main may terminate Status sooner. Cleanup
removes only the known partial file and empty receiving directory, preserving
unexpected contents and rejecting linked paths. Unconfirmed temporary cleanup is
reported without changing a confirmed successful download into a failed download.
See [receiving cleanup verification](receiving-cleanup-verification.md). Other blocking legacy Status operations can delay
the watchdog poll; the worker's network deadline is independent of those calls.
Forced whole-process termination, power loss or filesystem failures can leave an
abandoned receiving directory. Such data counts toward the quota and can be
removed locally. A crash after the final rename but before the completion reply
is uncertain: inspect the inbox before retrying. Receipt messages are not yet
durable across crashes or Discord delivery failure.

PowerShell 5.1 and 7 HTTP fixture checks cover binary bytes, fixed/chunked size
limits, rejected URLs and redirects, non-200/truncated responses, stalled headers
and bodies, quota limits, target collisions and concurrent inbox ownership. AHK
tests cover non-blocking worker polling, busy rejection, watchdog outcomes,
malformed results, native shared-memory launch and native shutdown cleanup. These tests
use loopback HTTP or reject the URL before any network request; live Discord
attachment receipt remains unverified. Local execution policy or unavailable
PowerShell can reject the worker and produce a download failure.

File workers now belong to a Windows job at process creation. Unlike reconnect
launchers, they cannot let child processes break away. Abrupt owner termination
therefore closes the last job handle and stops the worker and its descendants,
without relying on AHK exit callbacks. Normal cleanup terminates the job, checks
its active-process count and waits for the root and observed descendant handles to become
terminal before deleting temporary data. Failure to confirm termination retains
ownership and temporary files. The helper requires Windows 10 / Server 2016 or
newer, matching the existing reconnect ownership path.

The 16 KiB mapping accepts at most 8,000 UTF-16 request units and returns only a
fixed numeric status/reason. Request paths and URLs never become shell text or
temporary request files. A zero process exit without a valid completion record is
failure. Notification callback errors propagate after cleanup and cannot send a
second, contradictory completion. Native tests check cross-process Unicode data,
missing/failed results, normal descendant cleanup and hard owner termination;
PowerShell 5.1/7 checks cover protocol bounds and fixed failure reasons. See
[file worker verification](file-worker-verification.md).

## Support reports

The debug hotkey, tray entry **Preview Support Report**, and **Debug Options >
Support Report** open a local preview. Opening it leaves the clipboard unchanged.
**Copy report** copies the displayed text; **Save as text** saves that text to a
locally chosen file. Nothing is sent automatically. Recent issues start excluded
and require an explicit checkbox selection.

The shared builder includes runtime versions, CPU/RAM, screen dimensions/scaling,
registry-based Roblox installation detection, and basic setup observations.
Local previews also retain the main macro's available recent offset failure and
known newer-version observations. These are observations, not proof of a working
game setup. Registry inspection is read-only and hardware metadata no longer
requires a WMI query. Full installation paths and configuration dumps are omitted.

With the Diagnostics permission enabled, remote `debug`/`debuglog` queue the
default report as `natro-support.txt`. Remote `log` requests the same report with a
redacted recent-issue excerpt. It no longer uploads the raw debug log. Reports
are serialized and encoded in memory into an owned queue payload, with incidental
mentions disabled and the original reply ID retained. The old main-process
clipboard request/response handler is removed; remote reports neither read nor
write the clipboard. These explicit remote commands do not open a local preview.

Redaction replaces configured token/webhook/server/authentication and Discord ID
values, removes entire credential-bearing lines, strips URLs, long numeric IDs,
and drive/UNC paths, and masks the current user's profile/name and computer name.
Optional logs use a bounded tail, discard a partial first line, retain at most ten
matching issue lines, and omit oversized lines instead of truncating their
contents. Missing, unreadable or oversized redaction configuration excludes the
log excerpt. Missing log files produce an unavailable message instead of aborting
the report.

This is conservative filtering, not a guarantee that arbitrary free text contains
no private information. Renamed/old/encoded secrets absent from configuration,
unrecognized identifiers, and locally installed extensions still require review.
Filtering can also remove useful context; local preview provides the opportunity
to check what remains. FileRead remains a broader explicitly granted capability.
Raw local logs are not rewritten by this change. A support report is not yet a
comprehensive replay bundle with recovery journals, screenshots or route traces.

Windows regression coverage exercises the redactor, configuration/log failure
paths, bounded recent issues, native opt-in preview and exact clipboard copying,
and the actual encoded remote attachment. Actual Save dialog interaction, visual
layout at multiple DPI settings, live Discord receipt, and expanded diagnostic
coverage remain open. Command cancellation, other legacy hand-built JSON and
durable delivery remain part of the broader reporting recovery work.
