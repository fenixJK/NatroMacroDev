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
revocation, malformed masks, private settings, single-file validation and generated
inbox paths. Windows integration opens the actual permission window, saves/reopens
and cancels changes, captures an owned active GUI with exact client dimensions,
and checks missing Roblox, invalid modes and revocation without desktop fallback.
Tests use temporary settings directories and do not contact Discord.

Live Discord role changes, permission UX at multiple DPI settings, Roblox captures,
occluding windows and command interactions remain unverified. Automated game and
report captures elsewhere in the program are separate from the direct screenshot
command and still require their own capture audit. Attachment downloading retains
the legacy blocking downloader: response/time/size bounds, partial-file cleanup
and quota handling remain open. Inbox path checks are not a filesystem sandbox
against locally created links or concurrent local filesystem changes.

A local preview of a redacted support export remains planned. Existing logs and
debug output are explicitly gated, but are not yet a verified redacted support
bundle. Command serialization, cancellation, legacy hand-built JSON and durable
delivery remain part of the broader reporting recovery work.
