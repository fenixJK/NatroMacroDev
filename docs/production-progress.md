# Production recovery progress

Scope: implement the recovery sequence in [the audit](../production-audit.md), preserving AHK and the existing path/pattern interface. The full objective remains open until its implementation and verification gates are met.

Baseline: `66648fd6a290d472dacc45e9407e4c0ca4fa744a`.

## Implementation batches

- In progress: contain reconnect, update, AFB, planter-state, remote-control, screenshot, and exception-handling failures (F01–F09), plus startup gating.
- Pending: feature correctness (Vicious Bee, Blender, nectar order, collections, conversion/pause, priorities, quests, resources, geometry, reporting; F10–F25 and the smaller follow-ups).
- In progress: automation-free AHK tests using the bundled 2.0.12 runtimes, Windows CI, and packaging/migration checks.
- Pending: measured optimization and incremental configuration/state/detection/action refactoring.
- Pending after stabilization: the audit's proposed diagnostic, recovery, budget, profile, recorded-image, route, scheduling, and release improvements.

## Verification gates

- Passed for checkpoint `548a617`: actual AHK tests on both bundled architectures; additional tests remain required as the remaining features change.
- Pending: failure-injection tests for updates, interrupted actions, consumable limits, and permissions.
- Pending: live Windows/Roblox scenario matrix from the audit (including routes, game images, UI timing, pause/stop, reconnect, and mixed overnight run).
- Pending: measured baseline and comparison for performance changes.

Local source/static checks are supporting evidence only. They do not certify live game behavior. No production release or merge has been made.

## First implementation checkpoint

Implemented; Windows parsing and the covered regression groups passed, with live validation still pending: F01 (remove unowned tab closure),
F03–F04 (live AFB flags, centralized cancellation and pre-input budgets), F07 (no
automatic desktop fallback), F09 (validated ordered reconnect candidates), F10
(Vicious Bee retry/timeout/threshold/config fixes), F12 (numeric nectar sort), F16
(monotonic reset timing), F17 (rebuild/validate task list), F18 (startup gating),
F19 (duplicate resets/ramp), F25 (24-hour countdown), and the autoclicker/FPS/DPI
utility fixes. F06 has explicit command authorization and secret-read filtering;
separate desktop/file/system capability controls remain pending. F08 now logs and
aborts failed threads; the main process stops after releasing input. Further action
boundaries, helper fault propagation, and diagnostic presentation remain pending.

The AFB runtime has moved into `lib/AutoFieldBoost.ahk`. Pure decisions are in
`lib/RuntimePolicy.ahk`; the new suite calls those production functions and the
actual AFB configuration/cancellation handlers. Item counters conservatively
reserve every input attempt before sending, including unconfirmed/rejected input.

Still to implement in the first batch: confirmed planter harvest/reconciliation.
The transactional updater is implemented in the next checkpoint below. No finding is considered live-verified yet.

## Verified checkpoint — 2026-09-09

Code commit: `548a6178461d8e1d442b8dcb7a27d7f918e985b2`, pushed to
`fenixJK/NatroMacroDev`, branch `codex/production-recovery`.
[Windows run 34409151841](https://github.com/fenixJK/NatroMacroDev/actions/runs/34409151841)
completed successfully. All six submacro entry scripts passed `/Validate` on both
bundled architectures. Each architecture passed all 10 regression groups, with no
warnings in the final run. Earlier CI caught an invalid AHK switch `break` in the
new command-denial path; commit `370c64b` corrected it before the successful runs.

The checkpoint also fixes the snowflake double-disposal, the auto-jelly bitmap /
HBITMAP leak and duplicate brush disposal, zero honey formatting, and treating a
field-boost image-search error as a match. These changes parse on Windows; actual
GDI resource growth and generated auto-jelly execution still need dedicated tests.

GitHub's HTTPS OAuth credential lacks `workflow` scope. The existing authorized
SSH identity successfully pushed the workflow and code to the user's fork; use
`git@github.com:fenixJK/NatroMacroDev.git` for subsequent pushes without changing the
user's saved HTTPS remote. No PR, merge, or production release has been created.

Next: finish planter confirmation/reconciliation, then
continue the remaining feature/accounting/reporting fixes and expand the tests.
The full production objective remains active.


## Transactional updater checkpoint

Implemented F02 in `4c33fa0`, with CI shell configuration corrected in `a5880ae`.
[Windows run 34410312301](https://github.com/fenixJK/NatroMacroDev/actions/runs/34410312301)
passed 28 updater scenarios on Windows PowerShell 5.1 and PowerShell 7, plus all
11 AHK regression groups and parsing on both bundled architectures.

Updates now use structured JSON requests and a PowerShell transaction module.
Downloads are checked against release size and optional SHA-256; extraction rejects
unsafe paths, links and duplicates. Candidate layout, migration copies and AHK
syntax are checked before a unique installation directory is committed. The old
installation is preserved, startup changes are rolled back on detected failure,
and journals support recovery after process/machine interruption. Conflicting old
paths/patterns are backed up instead of silently replacing new shipped files.
The update window requires the macro to be stopped and explains retention/conflicts.
See [updating and recovering](updating.md) for behavior and limitations.

Verification covers actual AHK validation and an early-exit launch fixture, with
local fixture downloads and an in-memory startup registry. It does not certify
real release startup, game behavior, or runtime settings migration. Runtime changes
require manual installation until explicitly reviewed. UI layout and full release
upgrade/downgrade remain in the live Windows matrix. The checkout action also emits
a Node 20 deprecation warning; updating the pinned action remains a CI maintenance
follow-up.

Planter tracing confirms failed auto-harvest retries still clear records and
placement failures still lower the user's configured planter limit. Both auto and
manual harvest paths need shared confirmation/reconciliation. Fully grown planters
may harvest without a Yes/No dialog, so merely requiring a Yes click is insufficient.
These planter changes remain pending rather than claiming an incomplete fix.


Final updater code checkpoint: `36a7b0bd03e25f1e0ac3354c2156ecf6e6b50bd2`.
[Windows run 34410593964](https://github.com/fenixJK/NatroMacroDev/actions/runs/34410593964)
passed **35 update scenarios on each PowerShell version** and **11 regression
groups on each AHK architecture**. The expanded cases include duplicate/link ZIP
entries, nested/ambiguous package roots, concurrent updates, externally changed
startup entries, and failed startup restoration. The main update-window changes
also passed AHK parsing. Live upgrade/UI/game verification is still pending.


## Planter recovery containment

`ab02f85` replaces the destructive response to five failed auto-harvest attempts
with a persistent five-minute retry delay, preserving name, field, nectar and
harvest metadata. Manual harvest failures use the same recovery wrapper. The delay
is reserved before an action, so interruption also leaves a retry marker; successful
results clear it. New planter identities do not inherit another planter's delay.
All four automatic placement retry paths and the three-planter capacity rejection
now defer placement instead of lowering `MaxAllowedPlanters`. Paper, Ticket,
Festive and unknown stacked planter types cannot be cleared solely because an
inventory icon was found. A manual phantom-check miss now reports failure.

[Windows run 34411004501](https://github.com/fenixJK/NatroMacroDev/actions/runs/34411004501)
passed all 12 AHK regression groups on both architectures, including actual recovery
wrapper calls, persistent retry timing, interrupted actions, preserved records and
limits, and inventory-evidence policy. These tests use temporary INI files and
injected action callbacks, not game interactions.

The progress-bar reader is extracted into `lib/PlanterObservation.ahk`. It requires
successful image searches for every anchor, treats missing/failed observations as
unknown, bounds the computed fraction, and releases captures and cached needles.
Synthetic bitmap tests exercise known bar proportions, missing anchors, capture
failure, a real GDI bitmap-lock error, and reader resource rebuilding.

F05 remains open: both harvest implementations still need reliable post-action
confirmation (including full-grown harvests without a Yes/No prompt), then shared
state commits and reconciliation. Placement also still needs positive completion
verification. The new retry wrapper contains reported failures; it cannot correct
an action that incorrectly reports success. Synthetic bar tests do not certify
real game image accuracy or establish that a missing bar means a harvested planter.

The user confirmed no Windows/Roblox machine is currently available and asked to
continue code fixes and CI. Live verification remains a required, explicitly open
gate; it does not block independent implementation and automated regression work.


Verified planter containment/reader code checkpoint:
`3feae47f16d9d9f91877cada3fed083c729f7b36`.
[Windows run 34411278398](https://github.com/fenixJK/NatroMacroDev/actions/runs/34411278398)
passed all **13 AHK regression groups on each architecture**, including real GDI
synthetic-bar and locked-bitmap cases, and **35 updater scenarios on each PowerShell
version**. [Planter live-verification requirements](planter-verification.md) record
the missing game evidence and acceptance criteria. No live scenario is marked passed.
Next independent feature work: Blender acceptance/accounting, conversion/pause
intervals, and the remaining audit fixes while harvest confirmation evidence is
unavailable. The full recovery/refactoring/verification scope remains active.

## Blender accounting checkpoint

Code checkpoint: `a50fa4340c573d64ad776e2e7823c20b54072091`.
[Windows run 34412480755](https://github.com/fenixJK/NatroMacroDev/actions/runs/34412480755)
passed **14 AHK regression groups on each architecture** and **35 updater scenarios
on each PowerShell version**. All six main/helper scripts parsed successfully.

F11 accounting is implemented in `lib/BlenderAccounting.ahk`; the game routine is
extracted into `lib/Blender.ahk`. The executed slot is charged after a positive
running-craft observation, then rotation advances. `LastBlenderRot` updates in
memory and on disk. Accepted commits have a compact, replayable journal. Pending
input attempts support delayed confirmation in the same process. The final finite
batch remains scheduled for collection, failed searches no longer invent full craft
timers, and ingredient shortages preserve configured recipes with temporary backoff.
Dialog clicks verify window/focus/geometry ownership.

CI caught and helped correct an extraction boundary error (`00ba939`) and multiline
JSON being truncated by INI persistence (`e7c64c0`). The successful checkpoint uses
compact JSON and verifies interrupted-write replay without a second decrement.

[Blender verification requirements](blender-verification.md) distinguish tested
accounting from the remaining game gates: accepted quantity, exact image signals,
collection/cancellation transitions, interruption during input, and reconciliation
of unconfirmed attempts after process restart. These remain open; F11 is not yet
live-verified. The preparation path's stale observation after cancellation/End also
needs follow-up. No release or merge has been made.

Next independent correctness work: conversion/pause interval accounting, collection
success timestamps, quest uncertainty and reporting delivery. Preserve the full
remaining audit, refactoring, optimization, feature and verification scope.

Final Blender code checkpoint:
`43551c7365f81c60ca31ca97e9655f4febcd5da4`.
[Windows run 34412768292](https://github.com/fenixJK/NatroMacroDev/actions/runs/34412768292)
passed **14 AHK regression groups per architecture** and **35 updater scenarios per
PowerShell version**. This includes the final pre-input configuration checks:
the recipe snapshot is captured when its image is selected, rather than after a
possible configuration edit, and checked again before quantity/Confirm input.
The game acceptance and reconciliation limitations above remain open.

## Conversion and active-time accounting checkpoint

Code checkpoint: `ddc18328d02962775e3008b8dd03cb56448932d0`.
[Windows run 34413688123](https://github.com/fenixJK/NatroMacroDev/actions/runs/34413688123)
passed **16 AHK regression groups per architecture**, parsed all six submacros,
and passed **35 updater scenarios per PowerShell version**, without fixture warnings.

`lib/TimeTracking.ahk` now owns runtime, gather and conversion intervals. A monotonic
clock excludes pauses from action deadlines, drains each increment once into total
and session statistics, and closes actions before blocking reconnect recovery.
Pause, repeated stop, both statistics reset scopes, normal exit, early returns and
exception cleanup use the same ledger. Reconnection remains part of runtime.
`lib/Conversion.ahk` extracts the conversion routine and closes its interval in a
`finally` scope. A timeout with a nonempty backpack reports interruption instead of
"Backpack Emptied"; invalid readings also fail closed.

Tests exercise the production ledger, interrupted scopes, repeated transitions,
fractional intervals, wall-clock changes, and actual conversion timeout/AFB exit
paths without game input. This is in-process accounting, not crash-atomic storage:
an abrupt OS kill can lose unflushed time, and multiple INI writes are not a single
transaction. Live pause/stop callback behavior, backpack reading accuracy and
balloon completion signals remain verification gates. F14/F15 are implemented for
these accounting defects; game acceptance and broader state persistence remain open.

## Failed collection visits and gather interruptions

Code checkpoint: `7beb78904833272da2512adbbec3ab4a819b3c8c`.
[Windows run 34414440079](https://github.com/fenixJK/NatroMacroDev/actions/runs/34414440079)
passed **19 AHK regression groups per architecture**, parsed all six submacros,
and passed **35 updater scenarios per PowerShell version**. AHK fixtures emitted
no warnings. The workflow still reports a checkout action Node 20 deprecation;
upgrading that pinned action remains maintenance work.

Eighteen collection entry points now separate a failed visit from the legacy
interaction cooldown: Wealth Clock, seven dispensers, nine seasonal devices and
Memory Match. Missing prompts after both attempts preserve the previous timestamp
and defer for five minutes. Recovery metadata is persisted before travel and renewed
after reported failure. Seasonal/Memory Match gather interrupts, including the
Night Memory Match condition, honor the delay so a failed visit does not prevent
gathering throughout the backoff.

Five actual dispenser failure paths are exercised with controlled missing prompts;
tests also cover interrupted observation, disabled/excluded routes, persistence,
retry boundaries and actual seasonal/Memory Match interrupt functions.
[Collection verification requirements](collection-verification.md) distinguish
these checks from unverified post-input reward acceptance. The interaction path
still uses the existing E-prompt/input assumption. F13 remains partially open:
positive completion evidence, the separate booster failure path and remaining
collection families need follow-up. No live game behavior is marked passed.

The next correctness work includes quest uncertainty (F20), Discord delivery (F23),
geometry invalidation (F22) and the remaining action/state/resource defects in the
audit. The complete refactoring, optimization, feature and live-verification scope
remains active; this checkpoint is not a production-ready release.

## Automated Discord reporting checkpoint

Code checkpoint: `3430398e5e7e87701df4485d7c90804dd7a1ca09`.
[Windows run 34415787546](https://github.com/fenixJK/NatroMacroDev/actions/runs/34415787546)
passed **23 AHK regression groups per architecture**, parsed all six submacros,
and passed **35 updater scenarios per PowerShell version**, without AHK warnings.

Automated status/night/report sends use `lib/DeliveryQueue.ahk`: asynchronous
WinHTTP, owned encoded attachments, HTTP acknowledgement, bounded requests/queue/
attempts/age, rate-limit delay and network/server retries. Failed deliveries are
recorded locally. Raw automated text uses JSON serialization; shared JSON escaping
now covers vertical tab and other control characters. Hourly reports persist a PNG
before advancing their sample window and remove it only on acknowledged delivery.
Failed/unfinished hourly PNGs remain in `settings/pending-reports` for review.

Multipart preparation now checks stream operations, uses explicit CRLF framing,
fails on missing files/invalid images, and releases streams through `finally`.
Existing synchronous Discord calls have bounded waits and reject HTTP errors as
success. The live honey image path checks capture validity before encoding.

The suite exercises controlled delivery outcomes plus a loopback-only PowerShell
server through the real Windows HTTP client. It independently parses JSON, delays
responses, and validates multipart framing/PNG data after source bitmap disposal.
CI caught a filename concatenation parse error and a local variable shadowing the
AHK `Buffer` class during implementation; both were corrected before this checkpoint.

[Reporting verification requirements](reporting-verification.md) retain F23's open
work: legacy command builders/live edits, rate-limit coordination across paths and
helpers, destination-aware durable ordinary status queues, a recovery UI and live
Discord/rollover/resource-soak checks. Retries can duplicate a message if its HTTP
response was lost. Ordinary status screenshots are not persisted; pending hourly
PNGs are not automatically resent after restart. The complete recovery plan remains
active, including quests, geometry, state/resource handling, optimization and the
previously listed feature/live-verification gates.

## Window geometry and inventory search checkpoint

Code checkpoint: `491894406071c60b36cf382e3478b25baac855ae`.
[Windows run 34417131864](https://github.com/fenixJK/NatroMacroDev/actions/runs/34417131864)
passed **26 AHK regression groups per architecture**, the separate **native Windows
geometry integration fixture on both architectures**, all six script validations,
and **35 updater scenarios per PowerShell version**, without AHK warnings.

`lib/WindowGeometry.ahk` supplies coherent client snapshots including handle/root,
process, origin, size, DPI, monitor and styles. The offset cache expires and is
invalidated when its snapshot changes. Missing/minimized/hidden clients no longer
publish usable geometry, and missing HWND offset detection reports failure rather
than a cached successful zero. Activation targets the explicit window/root.

Inventory search now re-reads its visible boundary, owns/releases each capture,
checks window/focus stability through observation and scrolling, and includes the
top-bar offset in returned client coordinates. It stops after bounded unknown
observations and does not scroll after its last search. An optional outcome exposes
unknown versus missing; unknown results no longer add auto planters to the lost list.

Real GDI fixtures cover anchors, item coordinates and locked-bitmap errors. Native
Windows checks cover client origin/size, move/resize, explicit activation,
minimize/restore, hidden windows, cleared globals and missing-HWND offset failure.
CI also identified an unreachable-class warning from including the new inventory
classes after the main script's return. Moving the include into initialization
resolved it. The runner now captures timed-out validator dialog/output diagnostics.

[Geometry verification requirements](geometry-verification.md) preserve F22's open
gates: downstream drag/click ownership, callers ignoring failure flags, custom
capture/input paths, actual Roblox anchors, physical monitor/DPI transitions and
performance measurement. No live gameplay or complete coordinate-layer migration
is claimed. Quests, reporting recovery, other action/state/resource defects,
refactoring, optimizations, proposed features and the full live-verification plan
remain active.

## Generated workers and guarded inventory dragging checkpoint

Code checkpoint: `ee1405c5c28384e03fdeb5ad6ae4f9d973527d0c`.
[Windows run 34418392687](https://github.com/fenixJK/NatroMacroDev/actions/runs/34418392687)
passed **28 AHK regression groups per architecture**, **native Windows geometry and
pointer integration on both architectures**, all six script validations, four emitted
worker validations per architecture, and **35 updater scenarios per PowerShell
version**. AHK warnings now fail the runner; this checkpoint emitted none.

The preceding geometry libraries assumed entry scripts lived under `submacros`,
which excluded root/stdin workers. Their includes now resolve beside the libraries.
The two bee utility scripts and both walking modes use shared production builders
that CI evaluates and validates through their actual root/stdin launch layout.
The initial include correction was also independently verified by
[run 34417798898](https://github.com/fenixJK/NatroMacroDev/actions/runs/34417798898).

Inventory results carry their snapshot/item/boundary context while retaining their
two-coordinate array API. The drag controller freshly observes the same item at the
same coordinate and rejects changed geometry, missing/unknown observations, changed
inventory boundaries and invalid destinations. Glue dispenser travel completes before
the gumdrop search. Bitterberry/basic-egg utilities retain the selected bee slot's
window geometry and reject later geometry changes before dragging.

An owned pointer lease prevents overlapping guarded operations and invalidates
suspended work on pause/cancel. Cleanup releases the button on success, failure,
pause, stop and exit without allowing an old operation to release a newer owner's
button. Native checks verify synthetic versus physical button state, refusal to
take over an already-held button, timer cancellation, moved-window rejection and
button release. Fixtures also cover exceptions while a drag is held.

CI caught an unbound timer callback and warning-only name collisions during this
work; these were fixed. A subsequent run exposed the existing HTTP fixture's
sub-second COM-startup assumption. The test now holds the server response behind
an explicit file gate until the client proves that polling returned with its
original request still active. This preserves the asynchronous-delivery assertion
without treating shared-runner startup timing as application behavior.

[Geometry verification requirements](geometry-verification.md) retain per-process
ownership limits, unconverted menu/dialog/input paths, other generated-worker
coverage, actual Roblox acceptance, physical DPI transitions and live interruption
tests. Releasing input after invalidation can still produce a game drop; neither
cleanup nor completed input is recorded here as proof of item consumption. No
live-game verification, complete coordinate migration or performance improvement is
claimed. The full recovery plan remains active, including quests, remaining feature
correctness, reporting/state/resource work, refactoring, optimizations, proposed
features and the existing release/live-verification gates.
