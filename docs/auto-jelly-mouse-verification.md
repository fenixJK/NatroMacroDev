# Auto-Jelly mouse event handling

Auto-Jelly's hover callback previously stayed active while the pointer remained
over a control, sleeping and checking the pointer repeatedly. It replaced all
system cursors with a hand and reset the user's cursor scheme afterward. Click
handlers indexed Auto-Jelly controls from the current pointer without first
checking the message's window. Closing waited indefinitely for button release
inside a message callback, and window move/close messages lacked explicit targets.

The mouse controller validates both message ownership and the currently focused,
visible GUI/control under the pointer. Foreign messages cannot use the bee under
the pointer as a target. Hover changes redraw once; a 50 ms timer checks leaving,
focus loss and the 2.4-second bee-tooltip delay. A stable hover does not redraw on
each tick. Idle or stopped tracking disables the timer. The title and close areas
clear the hover highlight and tooltip.

The hand cursor is set only in response to an owned client-area WM_SETCURSOR.
Foreign/non-client messages retain normal Windows handling. The controller loads
a shared hand cursor; it neither replaces system cursors nor resets the user's
cursor scheme. This uses the documented
[WM_SETCURSOR parent/client handling](https://learn.microsoft.com/en-us/windows/win32/menurc/wm-setcursor).

Close uses a captured press followed by a matching release on the same close
control. It never steals existing capture. Release elsewhere, focus loss, Escape,
capture transfer or the five-second deadline cancels that press. Only its own
capture is released; a new owner survives cancellation. An accepted close and title
drag post explicitly to this GUI. Close tracking follows the Windows
[capture ownership and release contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setcapture).
Roll and Help are deferred to timer callbacks so the click message returns before
game preflight or a modal dialog starts. Settings still use their validated,
INI-first toggle writer.

Closing the GUI cancels mouse tracking and clears the tooltip before destroying
the window and graphics resources. Cleanup is idempotent. The previous system-wide
cursor replacement helper and both mouse waiting loops have been removed.

## Verification contract

The generated Auto-Jelly GUI fixture uses real controls and native mouse capture.
It checks hover entry, delayed tooltip, title/focus exit, owned client cursor
handling, foreign/non-client rejection and foreign click isolation while the
pointer remains over a bee. The fixture calls Roll/Help handlers while timer
execution is held, proving the handlers return before their deferred actions.

Close checks cover capture acquisition, release outside the close control,
expiry, transfer to another fixture window, preservation of existing capture,
accepted release and repeated cleanup. A temporary WM_SYSCOMMAND observer counts
and intercepts the accepted close to keep the fixture alive. All input/windows
belong to disposable CI fixtures, and the existing settings preservation,
startup retry and repeated redraw/graphics cleanup checks still run afterward.

## Verified checkpoint

Code `3b6fa8c20bd45e35be626a73d879447b32494354` passed
[Windows run 34463583704](https://github.com/fenixJK/NatroMacroDev/actions/runs/34463583704).
Both AHK architectures passed **66 regression groups**, native GUI/input/process
suites, nine production-script validations, four test-entry validations and seven
emitted-worker validations. The generated bee GUI probe completed every mouse
assertion before its existing settings and graphics ownership checks. Actual
English OCR recognition and failure recovery also passed on both architectures.
PowerShell 5.1 and 7 each passed eight file-channel checks, 43 attachment checks
and 35 updater scenarios. There were no AHK warnings; the checkout action's Node
runtime deprecation notice remains. No thresholds or assertions were relaxed.

## Limits

The 50 ms interval is a cooperative scheduling request, not a hard responsiveness
guarantee. Drawing and INI writes still call synchronous native APIs. These checks
do not establish a CPU benchmark, physical held-button/drag behavior across every
display/DPI configuration, or live Roblox behavior. Auto-Jelly consumption limits,
mutation accuracy and positive roll receipts remain separate production work.
