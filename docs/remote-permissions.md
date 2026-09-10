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
busy response. A URL is sent through stdin as JSON, never evaluated as shell code
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

Normal failures clean temporary data. The Status helper also has a polled
45-second watchdog and stops its owned worker on normal shutdown, then removes
that job's receiving directory. Other blocking legacy Status operations can delay
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
malformed output, native stdin launch and native shutdown cleanup. These tests
use loopback HTTP or reject the URL before any network request; live Discord
attachment receipt remains unverified. Local execution policy or unavailable
PowerShell can reject the worker and produce a download failure.

A local preview of a redacted support export remains planned. Existing logs and
debug output are explicitly gated, but are not yet a verified redacted support
bundle. Command serialization, cancellation, legacy hand-built JSON and durable
delivery remain part of the broader reporting recovery work.
