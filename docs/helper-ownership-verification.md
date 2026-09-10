# Main helper and generated-script ownership

Main cleanup selects the fixed helper names Heartbeat, Status, background,
StatMonitor, PlanterTimers, reconnect-worker, inline-worker and receiving-cleanup under this
installation's submacros directory. Discovery checks the full script-window
title, expected runtime image, current user and session, and retains process
handles. The heartbeat passed by the restarting watchdog is retained only when
its verified window matches. Unrelated scripts sharing the bundled runtime and
same-named scripts in other installations are excluded.

Generated movement, Discord settings, bee settings, priority settings,
bitterberry, basic egg and pattern validation scripts use an owned supervisor.
It starts each generated child inside its existing kernel job and sends UTF-8
source through explicitly inherited anonymous pipes. The parent uses shared
memory, with a limit of 1,048,576 UTF-16 units for the encoded JSON request and
64 KiB for combined UTF-8 stdout/stderr. The original stdin script and root
include context are preserved. Pipe writes and reads occur in the supervisor.

Source delivery and result retrieval have cooperative twenty-second deadlines.
Ordinary close gives the generated script 500 ms for its exit handlers, then
terminates the contained job and confirms observed process handles are terminal.
The parent also releases movement keys when ending a walk. A parent crash closes
the kernel job and terminates its supervisor and generated descendants. Worker
roles replace only their own previous instance. Completed worker failures are
logged; movement failures propagate to main's fail-closed handler.

Close keeps its short cleanup section uninterruptible by AHK callbacks so timer
reaping cannot free a mapping during another close. Startup and result polling
detect cancellation before reading shared memory. These are cooperative bounds;
native calls and OS stalls can exceed them. GUI initialization, game movement and
successful feature completion are separate from source delivery.

## Verification scope

Native tests cover both parent architectures with the opposite child runtime,
large Unicode source, stdin directory context, parse-only validation, output
overflow, graceful exit handlers, ignored close messages, role replacement,
movement failure propagation, role/request bounds and abrupt owner termination.
Disposable helper fixtures check retained heartbeat behavior and preservation of
personal scripts and another installation. Existing file-worker descendant and
crash tests exercise the shared contained-job cleanup base.

Code `b637951af5cc5120aa0b508995a81c0e2ca34d8a` passed
[Windows run 34453130252](https://github.com/fenixJK/NatroMacroDev/actions/runs/34453130252).
Both AHK architectures passed 62 regression groups, native process and GUI tests,
eight production-script validations and four emitted-worker validations. Both
PowerShell versions passed eight file-channel checks, 43 attachment checks and
35 updater scenarios. No AHK warnings occurred. No Windows/Roblox machine is
currently available for live testing.

The new native round-trip test initially caught the supervisor launching from
submacros instead of the repository root; explicit working-directory setup fixes
that regression without weakening the Unicode or include-context assertions.
An earlier run also reproduced an attachment timeout with the existing shared
memory transport (32-bit, approximately 61.8 seconds). Its cause is unresolved;
the subsequent passing runs do not establish that intermittent issue is fixed.

## Remaining limits

Older unowned stdin workers cannot safely be identified by runtime name alone;
the new cleanup deliberately has no broad process-kill fallback for them. Close
old versions before switching, or restart the Windows session if they remain.
Discovery is local process identity, not a security boundary against code running
as the same user. Cross-instance title-based IPC and helper readiness handshakes
still need work. Full start/stop/pause and watchdog restart flows, movement key
release in Roblox, resource soaks, and the additional supervisor's startup and
memory cost have not been measured in a live game. No performance improvement
or complete production recovery is claimed.
