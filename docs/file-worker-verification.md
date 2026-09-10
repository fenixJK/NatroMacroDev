# Download and archive worker ownership

Attachment downloads and local folder ZIP preparation use `nm_PowerShellJob`.
This reuses the native CreateProcessW/JOB_LIST mechanism from reconnect helpers,
assigning the worker to its job atomically at creation. File jobs use
KILL_ON_JOB_CLOSE without either breakaway flag. Their child processes therefore
remain owned as well. Reconnect helpers retain their existing silent-breakaway
policy so launched browsers and Roblox can survive helper cleanup.

The parent retains a process handle and a noninherited job handle. Normal cleanup
terminates the job, polls its active-process count for up to two seconds, and
confirms the root process is terminal through its retained handle before releasing
resources and deleting owned temporary files. Termination already in progress
may reject a second TerminateProcess call; cleanup waits for the handle rather
than classifying that transient response as failure. Failure to confirm completion
retains the handles and files. PowerShell workers cannot continue after abrupt
owner termination closes the last job handle. This relies on the Windows job
contract, not on an exit callback or PID/name-based process lookup. See
[Microsoft's job-object documentation](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

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
