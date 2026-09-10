# Download and archive worker ownership

Attachment downloads and local folder ZIP preparation use `nm_PowerShellJob`.
This reuses the native CreateProcessW/JOB_LIST mechanism from reconnect helpers,
assigning the worker to its job atomically at creation. File jobs use
KILL_ON_JOB_CLOSE without either breakaway flag. Their child processes therefore
remain owned as well. Reconnect helpers retain their existing silent-breakaway
policy so launched browsers and Roblox can survive helper cleanup.

The parent retains a process handle and a noninherited job handle. Normal cleanup
captures handles to current job members, terminates the job, polls its
active-process count for up to two seconds, and waits on the observed descendants'
handles as well as the root process handle before releasing
resources and deleting owned temporary files. Termination already in progress
may reject a second TerminateProcess call; cleanup waits for the handle rather
than classifying that transient response as failure. Failure to confirm completion
retains the handles and files. PowerShell workers cannot continue after abrupt
owner termination closes the last job handle. This relies on the Windows job
contract, not on an exit callback or PID/name-based process lookup. See
[Microsoft's job-object documentation](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

Member capture verifies job membership after opening each handle, observes newly
listed members while termination is pending, and retains at most 256 handles.
Confirmed exited members are released before reusing slots. Exceeding the bound
or failing to observe a member is a cleanup error. Job accounting reaching zero
alone does not establish that every observed process handle is already signaled;
a later native run exposed that distinction and motivated the additional waits.
Processes already absent from the job before capture do not have retained
observation handles. The no-active-members check and observed-handle waits are
separate evidence, not a historical inventory of every descendant ever created.

Only the fixed PowerShell script path and a random channel name appear on the
command line. A 16 KiB named mapping holds a versioned header and at most 8,000
UTF-16 request units. The existing reconnect request limit remains 4,096. The
PowerShell reader validates version/length, reads exactly the requested bytes,
parses JSON and returns a numeric completion/reason in the header. The parent
accepts completion only after the process exits successfully and the header
contains a valid result. Missing or malformed completion is failure. No request
data or exception text is returned on stdout, and no stdin pipe is needed.
The mapping uses Windows session-local naming and default process security;
it is not a sandbox against other code running as the same user.

Attachment host, redirect, size, quota, deadline and publication rules are
unchanged. Completion is delivered once after worker cleanup; notification
callback failure cannot trigger a contradictory second message. ZIP creation
retains LiteralPath handling, caller source preservation, owned temporary
directories and its existing cooperative timeout/size checks. No remote folder
upload permission is added.

## Verification

Code `c86ef25de092d18c784ccd5cbce0a5dbe114a328` passed
[Windows run 34449086921](https://github.com/fenixJK/NatroMacroDev/actions/runs/34449086921):
61 regression groups on each AHK architecture, native process/GUI suites, seven
production-script and four emitted-worker validations per architecture, and eight
file-channel checks, 43 attachment checks and 35 updater scenarios on each
PowerShell version. No AHK warnings occurred.

- Existing AHK attachment tests exercise actual production PowerShell launch,
  a Unicode working directory, URL rejection before networking, busy rejection,
  watchdog behavior, native cancellation and temporary directory cleanup.
  A failing notification callback is invoked once after ownership is released.
- Existing archive tests run actual ZIP creation for Unicode and shell
  metacharacters, verify the ZIP signature and source preservation, and check
  owned-file cleanup after creation, encoding or delivery failure.
- Native process fixtures use the shared transport for literal Unicode/quoted
  data, exception and absent-result cases, and repeated handle cleanup. A real
  PowerShell worker launches an AHK child; normal Close must stop that descendant
  before returning. Another fixture kills the AHK owner directly, bypassing its
  exit callbacks, and requires both PowerShell and descendant process handles to
  become terminal. The harness verifies those processes are outside its outer
  job, so passing cannot result from accidental harness ownership.
- Eight mapping-protocol cases run under both Windows PowerShell 5.1 and
  PowerShell 7: successful Unicode requests, action exceptions, known/unknown
  reasons, invalid version/length/JSON, and the maximum accepted request size.
  The native AHK suite launches the system Windows PowerShell executable with
  both AHK architectures. Existing reconnect/application-survival tests protect
  the separate breakaway behavior.

These tests contain no Roblox instance or Discord request. They do not prove live
attachment delivery or a complete production soak.

## Attachment deadline and lifecycle diagnostics

The attachment owner's 45-second budget starts before directory preparation and
native worker creation. It previously started after creation, allowing startup
time outside that budget. This remains a cooperative deadline: a blocked native
call cannot be interrupted by the polling code.

The file-worker mapping reserves bytes 16032–16051, beyond the maximum request,
for a numeric progress stage and four Windows TickCount milestones. Stages are
not-connected, connected, request-parsed, action-returned and result-written.
Exceptions retain their last completed stage while the existing result header
reports failure. These markers are diagnostics, not a substitute for confirmed
process exit and the existing result checks. Tick differences handle 32-bit wrap.

Attachment diagnostics include creation time, milestone times, total elapsed
time, worker CPU time, confirmed process-close time and receiving-directory
cleanup time. They contain fixed event/stage names and numbers, without request
URLs, signed query strings, message IDs, receiving paths or exception bodies.
Status records failures, deadline events, unconfirmed cleanup and cleanup over
one second in its existing local error log. Successful ordinary completions do
not produce a lifecycle log. Diagnostic callback failures cannot change download
completion or send a second notification.

The production attachment library is loaded inside the mapped action, so its
loading and URL checks occur after the request-parsed milestone. The prior
61.8-second timeout had no such markers; its cause remains unresolved. An initial
instrumented passing run observed 32-bit/64-bit channel connection at 5750/3016 ms,
native creation at 16/16 ms, and directory cleanup at 734/31 ms. These two samples
show where those successful runs spent time; they neither explain the earlier
failure nor establish a performance baseline or improvement.

Native tests check successful, thrown, silent-exit and stalled-action stages,
monotonic milestone ordering, creation/CPU/cleanup timings, and diagnostic callback
failure isolation. The eight PowerShell mapping cases additionally verify stage
and milestone publication through malformed and maximum-size requests.

Code `a351bdd48ee00f1661a6bc91db5fc97fb03cb18b` passed
[Windows run 34453759775](https://github.com/fenixJK/NatroMacroDev/actions/runs/34453759775):
62 regression groups per AHK architecture, native process/GUI suites, eight
production-script and four emitted-worker validations per architecture, plus
eight file-channel checks, 43 attachment checks and 35 updater scenarios on each
PowerShell version. The final 32-bit/64-bit samples connected at 10578/3360 ms,
returned results at 12656/4657 ms, and took 1891/47 ms for directory cleanup.
Worker CPU usage was 562/671 ms. These are observed samples, not a cause established
for the prior timeout. The later [receiving cleanup change](receiving-cleanup-verification.md)
moves that receiving-directory deletion into a contained worker. Directory
preparation, logging and upload-archive cleanup still include owner-side file I/O.

## Remaining limits

The earlier intermittent WScript attachment timeout has no established root
cause. This removes that pipe transport; it does not prove every timeout is cured.
PowerShell startup, antivirus scans, filesystem stalls and scheduling can still
delay work. Deadlines remain cooperative in the owner, with an independent
network deadline inside the download worker. Job termination and handle waits
cannot impose a hard upper bound on all kernel or filesystem behavior.

Crash and power loss can leave receiving/ZIP directories behind. These are not
automatically deleted or reconciled. A crash after final download publication but
before notification remains uncertain. Mapping state and notifications are not
durable. Local files can change during archiving, and source paths are not a
filesystem snapshot or reparse-point sandbox. Windows 10 / Server 2016 or newer
and available Windows PowerShell are required; there is no unowned-worker fallback.

## Startup delay recurrence during reset verification

The 32-bit first attempt of
[run 34534199478](https://github.com/fenixJK/NatroMacroDev/actions/runs/34534199478)
again failed the native URL-rejection fixture because worker lifetime reached
45 seconds before completion was accepted. Native process creation took 15 ms;
channel connection, parsed request, returned action and written result were
observed at 34562, 40359, 44437 and 44953 ms. Final diagnostics showed 859 ms CPU,
45046 ms owner elapsed, confirmed process cleanup and 47 ms directory cleanup.

The result was correctly reported as timeout, but the fixture expected the worker
to finish and return its URL rejection. This is an unresolved startup/lifecycle
latency failure. A single failed-job rerun was requested with the existing deadline
and assertion unchanged. These timings do not identify the cause, and a passing
retry must not be used to claim the intermittent failure is repaired.

The requested 32-bit rerun passed, returning its expected URL rejection after
36297 ms. The original successful 64-bit job took 9797 ms. The final CI run is green,
but the startup latency and its cause remain unresolved.
