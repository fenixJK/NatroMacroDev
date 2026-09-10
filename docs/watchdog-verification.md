# Watchdog restart recovery

Heartbeat no longer uses a WMI query matching Roblox names or command-line
substrings during recovery. Player cleanup goes through the existing owned
reconnect helper, which selects the exact player executable, current user and
session and retains process handles through termination. Studio and unrelated
Roblox-named command lines are excluded by that policy.

Main-script cleanup requires an exact AutoHotkey script-window title for this
installation, the expected runtime image path, and the current user/session.
Relative and available Windows short paths are expanded before comparison, on
both the expected path and queried runtime image. The window PID and title are rechecked
after opening the process; cleanup then uses the retained handle. A same-named
script in another directory or the selected script running under a different
runtime is not selected. This identifies the expected local program, not its
publisher or a security boundary against code running as the same user.

Replacement launches use CreateProcessW and retain its returned process handle.
The command contains the fixed main-script/runtime paths, a numeric automatic
start flag and the watchdog window handle. A replacement is ready only when its
own PID has a visible GUI with the exact final title `Natro Macro`. Another
instance's GUI or an early splash screen cannot satisfy this condition. This
proves UI initialization, not successful game startup, helper readiness or a
healthy macro loop. Automatic startup still runs its separate prerequisite checks.

## Bounds and failure behavior

Each recovery permits up to three attempts. The watchdog also retains a rolling
limit of three attempts in thirty minutes across successful-looking replacements,
so a repeatedly failing macro cannot restart forever. Each attempt has a
five-minute monotonic budget covering cleanup, launch and UI initialization.
Launch failure, process exit and unready startup consume attempts. Failed launched
processes are stopped through their creation handles before the next attempt.
Ready applications survive handle release.

Failure to confirm either old-main cleanup, player cleanup or failed-replacement
termination aborts recovery; another macro is not launched on top. Exhaustion or
unexpected recovery failure writes a local error, displays a message with a
sixty-second timeout, and exits the watchdog. Correcting the problem and restarting
Natro manually starts a new watchdog/budget. A successful replacement produces a
UI-ready diagnostic and a status message that startup checks still apply.

The heartbeat timestamps use GetTickCount64 instead of wall time. Existing
thresholds remain two minutes for required script replies and ten minutes without
a Roblox window while running. Paused mode monitors main and Status. Stopped-to-
active transitions establish fresh baselines, and inactive background/window
baselines use actual monotonic time rather than accumulating assumed five-second
intervals. Heartbeat requests use this installation's script paths; invalid
heartbeat/state enum values are ignored.

## Automated verification

Code `0a223b221b2c5b98727bf983b2ca255ac2e3fd57` passed
[Windows run 34450918133](https://github.com/fenixJK/NatroMacroDev/actions/runs/34450918133):
62 regression groups per AHK architecture, native process and GUI suites, seven
production-script and four emitted-worker validations per architecture, and eight
file-channel checks, 43 attachment checks and 35 updater scenarios on each
PowerShell version. No AHK warnings occurred.

Controller tests cover the native default clock/sleeper, ordered cleanup, a ready
replacement, the rolling crash-loop limit and its expiration, three hung startup
attempts, failed creation and unconfirmed cleanup without further launches.
Scripted time verifies the five-minute attempt boundaries without waiting fifteen
real minutes.

Native Windows tests launch disposable AHK processes and retain their creation
handles. They verify that another process's matching GUI cannot signal readiness,
that discovery selects only the expected script/runtime, and that cleanup leaves
same-name and different-runtime decoys alive, including Windows short/long path
equivalence. Failed native creation and handle
cleanup are exercised. Existing native reconnect/player tests verify the shared
player-selection helper. No Roblox instance is launched and no real user process
is terminated by these fixtures.

Released creation handles are checked directly with GetHandleInformation. Process
handle counts returned from 196 to 196 on the 64-bit runner and 213 to 213 on the
32-bit runner after launch/discovery/termination/release. Recursive deletion of
the fixture directory afterward raised the process-wide counts to 378 and 390,
respectively. The assertion covers process ownership before that separate
filesystem operation. This does not establish whether the filesystem-related
increase is retained initialization or repeated growth; resource soaks remain open.

## Remaining work

The complete Heartbeat-to-main restart flow, real hangs, game reconnection, helper
initialization and automatic startup after replacement still need live Windows
verification. Source validation plus isolated native fixtures do not prove that
whole sequence. Main's cleanup now uses the fixed helper identity policy and
owned generated workers described in [helper ownership](helper-ownership-verification.md).
Older unowned stdin remnants cannot safely be selected by runtime alone. Several helper
responses still use legacy title-based IPC; cross-instance IPC and readiness
acknowledgements remain open.

Heartbeat replies prove message handling, not forward progress. The watchdog
itself has no independent supervisor. Its retry budget is in memory and resets
when that process restarts. A watchdog crash during replacement does not kill the
new main application. Hard termination can leave partially committed game or INI
state; this change adds no transaction or receipt reconciliation. Native calls,
UAC, system suspension and filesystem stalls can exceed cooperative deadlines.
The existing generic ApplicationFrameHost window observation remains a weak
presence signal, although it is no longer a process-cleanup target.
