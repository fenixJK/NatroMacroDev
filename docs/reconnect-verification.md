# Reconnect recovery

Recovery now attempts one circuit of eligible servers, with five actual launches
per server. Empty or invalid slots are skipped. Public fallback is used only when
permitted by the existing policy; a completely empty private-server configuration
still means public-only operation. There are at most 25 launches with all four
private slots and public fallback enabled, or five in public-only mode.

A recovery has a 30-minute monotonic budget. Each attempt waits up to four minutes
for a window, three minutes for recognizable game/loading imagery, and three
minutes after loading first appears. Repeated unknown/loading frames do not reset
these deadlines. Two seconds separate failed attempts. The total budget may end
before every configured server receives all five attempts. A scheduled reconnect
delay precedes this budget. The existing local Stop command can still interrupt
recovery; elapsed pause time consumes the budget.

The existing loaded-game (`science`) template must match. Disappearance of the
loading template is inconclusive. Disconnect imagery takes precedence over loaded
imagery. During loading, all three searches share one owned frame of the focused
Roblox client, with focus and geometry checked again before accepting it. Failed
native searches throw rather than become successful observations. Routine
disconnect checks retain their smaller center-region capture. Current-game
template accuracy still requires live verification.

Hive claiming shares the overall deadline. Its sleeps and worker waits are
clipped, and it checks the budget before new walking work. Exiting the claim
routine releases the interaction key and stops its walk worker. Completion and
legacy timer adjustments occur only after the claim routine accepts a hive (or
an explicit connection-only check). Failed claims no longer repeatedly extend
planter/gingerbread times by the entire recovery duration. Elapsed compensation
uses monotonic time including the actual scheduled delay, and zero elapsed time
no longer becomes an invented five-minute adjustment. The existing claim
routine still infers acceptance from its prompt/input sequence; a positive
post-input hive receipt remains open. Related INI writes are not a crash-atomic
transaction.

Exhaustion records a local error and uses the main program's stop/exit cleanup;
it cannot return a normal success code to the interrupted activity. Restart is
explicit after checking the game and server configuration.

## Launch and process ownership

Browser/deeplink dispatch and player cleanup run in an owned AHK helper process.
Requests use a uniquely named, session-local shared-memory mapping with a bounded
JSON payload. Private server codes are not placed on the helper command line or
in temporary request files. Browser/deeplink targets are reconstructed from the
fixed Bee Swarm place and validated server code; arbitrary launch targets and
extra URL parameters are not forwarded.

Each helper is assigned to an unnamed Windows job as part of CreateProcessW,
using the JOB_LIST startup attribute. The job has kill-on-close enabled and its
handle is not inherited. If the parent is forcibly terminated, Windows closes
that handle and terminates the helper even though AHK exit callbacks never ran.
Assignment is part of process creation, so there is no unowned interval before a
later assignment call. This path requires Windows 10 / Server 2016 or newer; if
job setup or creation fails, the macro does not fall back to an unowned helper.

Silent breakaway lets applications launched by the helper leave its job. Thus
closing the helper's job does not kill an already launched browser/game. Helpers
created by another helper receive their own independently owned jobs.

The parent keeps the process handle returned by CreateProcessW. Each helper has
20 seconds, also subject to the remaining overall reconnect budget. On failure,
timeout or parent exit, the parent terminates the owned helper if needed and waits
up to two seconds for termination. Failure to confirm termination is fatal and
retains the owned handle for exit cleanup; it is not treated as an ordinary retry.
A failed launch/cleanup helper otherwise consumes a reconnect attempt. Requests,
process/thread handles and mapping views are released after completion.

Cleanup replaces broad WMI name/command-line matching with a process snapshot.
It selects only the exact `RobloxPlayerBeta.exe` basename, then verifies the image,
user SID and session using an opened process handle. It requests WM_CLOSE only on
that process's windows, allows a short grace period, and terminates remaining
verified players through those same handles. PID lookups do not select a different
process at termination time. Studio, installers, shared ApplicationFrameHost and
unrelated command lines containing Roblox are excluded. This is exact executable /
owner / session identification, not an Authenticode publisher check.

CloseRoblox no longer sends Esc/L/Enter to the foreground application. The existing
five-second post-close delay is retained. The main background action callback is
gated while reconnect or a nested player close owns the game, and ownership is
released on normal return or exception. This does not yet coordinate every helper
process, independent tool or external remote desktop command through one input
owner.

## Verification and limits

Clock-controlled tests exercise finite candidate ordering, private-only and
public-only policy, missing windows, unknown frames, disappearing loading images,
disconnects during loading, successful loading, late callbacks, stage/total
deadlines and native search result classification. Gate tests cover nested
ownership, release after errors and suppressed background callbacks.

Native process fixtures exercise shared-memory Unicode/quoted requests, repeated
handle cleanup, failed process creation, invalid production launch requests,
timeout and terminal-state confirmation, and the production close helper against an exact-name disposable
player and a Roblox-named Studio decoy. These fixtures contain no game and issue
no real browser/deeplink launch. Tests refuse to proceed if a real player is
already running. Further native fixtures forcibly terminate a parent while its
owned helper is alive and require the helper to become terminal without parent
cleanup. Disposable applications must survive both normal and forced launch-helper
cleanup; job-membership checks verify their breakaway. Other-user/session exclusions still require multi-session Windows
verification.

Browser/game processes intentionally survive helper completion. Timing out after
a successful external launch can leave its outcome unknown; terminating the
helper does not undo a browser tab, protocol dispatch or process already created.
Kernel job ownership covers abrupt parent termination; whole-system power loss
still cannot provide a durable receipt of an external launch. The parent still
depends on short native startup/poll/termination calls returning, and main-thread
scheduling can delay polling. This is not a hard real-time bound
on every OS operation. Positive hive receipts, full input coordination, live
browser/UAC/Roblox-update behavior and crash-atomic timer updates remain open.

Required live scenarios include browser/deeplink joins, Roblox updates, bad links,
all fallback combinations, disconnects in every stage, slow loading, an occupied
hive, pause/stop during loading or walking, and recovery exhaustion. No live game
scenario has been marked passed.

The Explorer-shell launcher retains the Lexikos public-domain ShellRun approach
credited in the original main program. The native lifecycle follows Microsoft's documentation for
[CreateProcessW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw),
[process handles](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-process_information)
and [image-name verification](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-queryfullprocessimagenamew).

Crash ownership uses Microsoft's documented
[creation-time job list](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute)
and [kill-on-close / breakaway job behavior](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
