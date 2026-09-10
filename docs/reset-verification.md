# Character reset and hive recovery

The previous `while (!HiveConfirmed)` loop could keep resetting and reopen Roblox
every tenth iteration indefinitely. Character/hive recovery now permits at most
five attempts within one three-minute monotonic budget. Attempts, waits and cleanup
share that budget. Expiry, unreadable observations and exhausted attempts throw a
specific error rather than returning to callers that assume reset succeeded. The
main process's existing failure handler records the error and stops its work.

The budget starts after the existing preliminary disconnect/frozen-game checks
and high-priority task interrupts, when hive recovery is actually required. It
does not include subsequent conversion or requested post-reset waiting. Blocking
Windows calls, reconnect and legacy helpers cannot be forcibly preempted; the
deadline is checked when control returns. This is not a three-minute wall-clock
guarantee for every call to `nm_Reset`.

Before a non-forced reset, a fresh hive prompt plus successful camera alignment
can establish readiness without sending another character reset. Explicit forced
reset keeps its previous intent. The existing `HiveConfirmed` fast path remains;
this checkpoint does not replace all other writers of that global flag.

## Observation and cleanup

The shared hive reader distinguishes present, readable absence and unknown.
Prompt and camera-alignment reads anchor window identity, client geometry and
focus, validate capture bounds/assets, reject native image-search errors and
expire frames after 250 ms. Observation never reacquires focus. Camera scanning
uses fresh client geometry for each frame, retains the existing shipped templates
and match-count threshold, and returns explicit failure after its two rotations.
Unknown alignment now stops the Whirligig caller too, rather than allowing it to
continue converting from an unreadable observation.

Reset menu closure and HUD offset must be confirmed before continuing. Captures
created by the extracted attempt are registered for cleanup, native search errors
cannot become misses, and each attempt stops its walk worker before another
attempt starts. Spawn-to-hive movement must start and finish within its wait
limits. The shared deadline bounds these waits and the legacy reset preparation
loops. Key delay and key duration are restored even on failure. The existing
initial frozen-game restart remains; the repeating tenth-attempt restart is gone.

## Verification contract

Controller tests cover first/late success, persistent misses, unknown results,
exceptions, attempt exhaustion, one aggregate deadline, late callbacks, cleanup
time, clipped waits and missing/arriving worker state. Each retry asserts that the
previous attempt cleaned up. A real invalid native image search must throw.

The native fixture captures owned Windows GUIs with synthetic template colors.
It checks prompt matches, the alignment match-count threshold, readable absence,
missing assets, changed geometry, lost focus, invalidated identity, stale frames,
and capture cleanup after a native search failure. It overrides Roblox identity
and HUD offset. It does not execute the full reset routine or game camera input.

## Verified checkpoint and CI observation

Code checkpoint: `74703e501909d856718bf147e832b3c220de6c40`.
[Run 34534199478](https://github.com/fenixJK/NatroMacroDev/actions/runs/34534199478)
finished successfully after the failed 32-bit job was rerun once. Both AHK v2.0.12
architectures passed **73 regression groups**, the native hive fixture and existing
native suites, plus **nine production-script, four test-entry and seven emitted
worker validations**. PowerShell 5.1 and 7 each passed **eight file-channel checks,
43 attachment checks and 35 updater scenarios**. No AHK warnings occurred; the
checkout Node runtime deprecation notice remains.

The initial [run 34534001206](https://github.com/fenixJK/NatroMacroDev/actions/runs/34534001206)
passed 73 groups and the native hive fixture on both architectures. A subsequent
change includes cleanup time in the aggregate deadline, with a regression case.
The first attempt of [run 34534199478](https://github.com/fenixJK/NatroMacroDev/actions/runs/34534199478)
passed the reset group on both architectures and the complete 64-bit suite, but
the 32-bit run failed its existing attachment-worker URL-rejection assertion after
the worker exceeded its 45-second lifetime. This recurs after the previously
recorded attachment startup delay. One failed-job rerun was requested without
changing assertions or time limits; passing a retry would not prove that this
intermittent delay is fixed. On the successful rerun, the 32-bit attachment fixture
returned the expected URL rejection after 36297 ms; the original successful 64-bit
job took 9797 ms. The slow startup remains an explicit open issue.

## Upstream reports and remaining work

[Issue 1606](https://github.com/NatroTeam/NatroMacro/issues/1606) describes repeated
resets despite already being at the hive. [Issue 1502](https://github.com/NatroTeam/NatroMacro/issues/1502)
describes combined hive, inventory and cannon failures. These reports guide the
scope; neither has been reproduced or declared resolved by this checkpoint.

Live template accuracy, camera orientation, spawn detection and all six hive
routes remain unverified. Legacy modal cleanup still contains direct input,
some helpers can reacquire focus, and raw spawn/health detection requires further
review. Physical cancellation/pause and nested high-priority tasks need full
application tests. A broader shared input owner and fresh positive hive evidence
for every writer of `HiveConfirmed` remain work. No Windows/Roblox machine is
available. The full production goal remains active.
