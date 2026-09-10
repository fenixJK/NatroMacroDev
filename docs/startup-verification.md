# Startup, pause and stop verification

Start requests now reserve one session before scheduling their timer. Local,
remote and automatic requests retain their own mode through preflight and the
main loop. A second request cannot replace that mode or schedule another start.
Rejected preflight releases ownership and restores the Start controls. Cancelling
a scheduled request removes its timer, and a late callback cannot take ownership
from a newer session. Unexpected exceptions propagate to the existing fault
handler. Returning normally from the running main loop is also a fault.

All three modes rebuild and validate priorities, check the Roblox installation,
check the existing settings recommendations, require a window and detected GUI
offset, and perform the input-message access probe. Automatic mode still skips
optional informational warnings. Remote and automatic prerequisite failures use
status messages instead of modal dialogs. These modes no longer bypass the
window/offset/input checks simply because startup is unattended.

Closing the incorrect-settings warning does not authorize startup. Its explicit
Ignore button grants a session override; remembering it requires both the
checkbox and confirmation. The INI write must succeed before the in-memory
override changes. Replaced dialogs cannot invoke the current dialog's save
callback, including replacement while confirmation is open. A failed save leaves
the warning open. An existing stored override remains honored. After correcting
settings or choosing an override, the user starts again.

Pause accepts only a running session in running or paused MacroState. The main
process background callback also requires a running session and running
MacroState, in addition to the recovery activity gate. Startup publishes running
state only at the main-loop handoff, after session initialization and helper
launch requests. A required background helper launch exception is no longer
suppressed. This is launch-error handling, not a helper readiness handshake.

Stop cancels startup ownership first, releases existing input, stops time tracking
and publishes stopped state before Reload. If the old process survives the
ten-second reload grace period, it records a failure and exits instead of
returning to the interrupted loop. Fault and exit cleanup also cancel ownership.

## Automated evidence

`TestStartupControl` exercises mode retention, duplicate and reentrant requests,
preflight rejection and exceptions, cancellation of a real AHK timer, late old
callbacks, running-loop return and cancellation without re-enabling controls. It
also calls the production override function against a real temporary INI file,
checking session-only behavior, persistence and a real write failure caused by
a directory occupying the file path.

`TestNativeStartupDialogs` opens real owned Windows GUIs, clicks the Close and
Ignore controls, verifies confirmation acceptance/rejection, replaces warnings
before and during confirmation, and injects a save failure. These fixtures run
with both bundled AHK architectures. They contain no Roblox instance and send no
Discord messages or game input. Production scripts and emitted workers also
receive the existing validation checks.

## Remaining verification and limitations

- The complete main GUI startup path, local/remote/automatic start against Roblox,
  pause during input, Stop during preflight and forced Reload failure need native
  end-to-end verification. The controller and dialog fixtures do not execute the
  main macro's infinite loop.
- Successful PostMessage calls establish message access, not that Roblox acted
  on input. Menu opening, shift lock, offset detection, input freshness and
  geometry under real DPI/occlusion/UAC conditions still need game verification.
- Settings recommendations still use the existing XML substring matching. A
  missing settings file remains accepted; this does not prove the settings are
  correct. Semantic XML parsing and setup diagnostics remain open.
- Helper startup has no readiness acknowledgement. Main-process background
  gating does not coordinate every helper's captures and inputs, and helper
  initialization still has its existing state-publication race.
- Native calls and modal dialogs can delay cooperative cancellation. The Stop
  fallback only applies after execution reaches Reload and its grace period.
  Full fault cleanup, helper health and input ownership remain separate work.

F18 remains partially addressed. A passing fixture suite is not a production or
in-game verification claim.

Heartbeat automatic replacement now waits for the launched process's own final
main-GUI title and limits restart attempts. See
[watchdog verification](watchdog-verification.md). This does not close the separate
helper-readiness and live startup checks above.
