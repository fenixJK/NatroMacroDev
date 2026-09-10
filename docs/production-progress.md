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

## Quest completion evidence checkpoint

Code checkpoint: `6ee9de2f048e66134f61d7a004fdb86590cb83d0`.
[Windows run 34419566125](https://github.com/fenixJK/NatroMacroDev/actions/runs/34419566125)
passed **32 AHK regression groups on each architecture**, native geometry/pointer
integration, all six script validations, four emitted worker validations per
architecture, and **35 updater scenarios per PowerShell version**, without AHK
warnings.

All six quest families now distinguish complete, incomplete and unknown. The new
`QuestObservation` module re-captures the title and rows together and requires an
explicit completed background, rather than accepting arbitrary non-border colors.
The background was measured from a historical screenshot attached to an upstream
bug report; its provenance and limitations are recorded in
[quest verification](quest-verification.md).

Readers reject failed title/gap recognition and incomplete visible row sets, reset
stale names, and stop inferring completion from having no next action. Brown's
variable objective list keeps one entry per row, marks unmatched text unknown, and
requires a fresh endpoint when fewer than four objectives are recognized. Unknown
results replace stale completed text and clear pending quest actions; gather polling
no longer treats unknown as a completed step.

`QuestActions.ahk` contains the real six action consumers exercised by the tests.
Visits require explicit completion. The five previously counted quest families
require newly observed incomplete progress after visiting before incrementing
counters; Black/Brown cooldown timestamps use the same condition. Honey re-reads
before announcing a new quest. Its existing counter behavior is unchanged.

During CI, an overly broad test-setup edit affected older fixture initialization;
that edit was corrected, and isolated quest fixtures received the explicit global
declarations required by AHK. The final recorded run passes the older regression
suite and all new quest tests.

F20 remains open for live/recorded game images, long-log scrolling and initial quest
acquisition, bounded persisted retries for unknown/unconfirmed visits, planner
separation, remaining native resource/input paths, dynamic end-of-log reconciliation
and positive game acceptance. In particular, removing false hourly-success records
requires a separate retry delay for failed Black/Brown visits. These remaining
requirements are not hidden by the new green CI result. The full recovery plan,
other feature/state/reporting fixes, optimizations, proposed features and release
verification gates remain active.


## Persisted quest retry checkpoint

Code checkpoint: `134c5b0db95672a22ae4107bb0ccc0810ffc90a1`.
[Windows run 34420145053](https://github.com/fenixJK/NatroMacroDev/actions/runs/34420145053)
passed **34 regression groups on each AHK architecture**, native geometry/pointer
checks, six script validations, four emitted worker validations per architecture,
and **35 updater scenarios on each PowerShell version**, without AHK warnings.

Each quest family now reserves a persisted delay before reading (30 seconds) or
traveling for a turn-in (five minutes). Confirmed results clear the relevant delay;
unknown results and interrupted attempts retain it. Read and visit reservations are
independent, active work cannot overlap its own reservation, and in-process timing
uses a monotonic clock. Invalid records and backward clock changes receive a bounded
repair delay. All six turn-in consumers share the reservation/confirmation helper.
Black quest rotation permits other families while its visit is deferred.

Tests cover reservations before work, expiry, restart, clock changes, malformed
records, independent families, all six consumers, travel exceptions and actual INI
write failure before travel. The remaining quest observation, acquisition, planner,
game acceptance and live interruption gates are documented in
[quest verification](quest-verification.md). Full production recovery remains active.


## Combat health reader checkpoint

Code checkpoint: `0c58935ede2bd3a8cc65cd9df70a2a506e3dec8f`.
[Windows run 34420916584](https://github.com/fenixJK/NatroMacroDev/actions/runs/34420916584)
passed **35 regression groups on each AHK architecture**, native geometry/pointer
and health-capture integration, six script validations, four emitted worker
validations per architecture, and **35 updater scenarios on each PowerShell
version**. No AHK warnings occurred; the existing checkout action's Node deprecation
notice remains a separate CI maintenance item.

The shared combat reader now measures every bar independently, includes the final
pixel in its percentage denominator and uses the actual bitmap dimensions for
King Beetle's half-window scan. It masks matches in an owned copy, releases graphics
before their bitmap through `finally`, and releases cached templates before main
GDI+ shutdown. Planter reader templates now also have main-process exit cleanup.

The capture wrapper requires a focused current client and rejects geometry changes
after observation. Missing captures and actual native search/read errors throw into
the existing input-release/failure handler rather than becoming empty health lists.
The old kill-success heuristics are unchanged and remain an open correctness issue.

CI exposed two fixture assumptions: numeric map keys distinguished rounded float
percentages from integers, and GDI+ permits cloning a locked source image. The tests
now compare numeric values directly, verify reading the owned clone leaves the
source intact, and lock a search template to exercise a real native search error.
Additional tests cover 100 repeated reads after errors, cache release/rebuild, the
detection cap and actual full/right-half capture of an owned Windows GUI.

[Combat verification](combat-verification.md) keeps current game imagery, clipped or
occluded bars, positive kill confirmation, recoverable combat action boundaries,
health/time estimation and measured long-run resource/performance checks open.
No live game verification or performance gain is claimed. The full production plan
remains active, including the other feature, state, reporting, optimization, proposed
feature and release gates already recorded above.


## Boss health/time estimation checkpoint

Code checkpoint: `88600d65d4dc461195dc797b0b15a04ba017bca2`.
[Windows run 34421671246](https://github.com/fenixJK/NatroMacroDev/actions/runs/34421671246)
passed **37 regression groups on each AHK architecture**, native geometry/pointer/
health capture, six script validations, four emitted worker validations per
architecture, and **35 updater scenarios on each PowerShell version**. No AHK
warnings occurred. The checkout action's separate Node deprecation notice remains.

Snail and Commando now use independent per-fight observation sessions. Five captures
are separated by 100 milliseconds; at least three must agree within one percentage
point of the median, and multiple damaged bars make a frame ambiguous. A new fight
first establishes a fresh observed baseline rather than treating persisted or manual
health as a measured starting point. Damage estimates require a positive monotonic
interval and at least 2.5 percentage points of decrease. Unknown, inconsistent or
small changes do not advance the baseline. Rising health establishes a new baseline.

A five-second limit rejects interrupted/stale capture series. Failed persistence
leaves the baseline and published health unchanged. Successful publication updates
the INI, memory and GUI, and the report function returns explicit acceptance.
Fight limits and report scheduling use monotonic milliseconds; reports consistently
format seconds, minutes and hours. The real elapsed damage interval includes pause
time because game health may continue changing; macro runtime accounting is separate.

Commando startup now shares the existing maximum-health fallback used for levels
absent from the bundled table, avoiding direct lookup failure for selectable levels
20–25. Editing its level also updates the shared in-memory level. The table/fallback
values are preserved, not certified against current game data.

New tests exercise both actual reporting consumers with controlled frame series,
independent/new/rebased sessions, ambiguous and inconsistent observations, elapsed
intervals, rate/remaining-time calculations, stale commits, duration carries,
settings/UI value publication, unsupported families, overlapping reports, long
interruptions, native INI write failure and capture exceptions. GUI publication uses
control fixtures; this does not replace live settings-window interaction.

[Combat verification](combat-verification.md) retains current game identity/health
evidence, live damage and pause scenarios, kill confirmation, recoverable action
boundaries and long-run resource/performance measurements. Other feature, reporting,
state, optimization, proposed-feature and release gates remain open. The full
production objective remains active.


## Shared image search and boss outcome checkpoint

Code checkpoint: `d7681996d285f05207322a1291170c910a6b1c4b`.
[Windows run 34422652220](https://github.com/fenixJK/NatroMacroDev/actions/runs/34422652220)
passed **39 regression groups on each AHK architecture**, native shared image
search, health capture, geometry and pointer checks, six script validations, four
emitted worker validations per architecture, and **35 updater scenarios on each
PowerShell version**. No AHK warnings occurred. The separate checkout Node notice
remains a CI maintenance item.

The shared image helper now uses a fresh focused client snapshot, bounded inclusive
search regions and a restored pixel coordinate mode. It checks geometry again after
searching and publishes verified window globals for existing coordinate consumers.
Missing assets, invalid regions and native errors throw through normal failure
cleanup instead of abruptly killing the process. Native GUI tests cover full/right
region matches, client-relative coordinates, published geometry, no match, corrupt
image decoding and coordinate-mode restoration. Other tests cover small/odd client
sizes, invalid coordinates, changed focus/geometry and pre-search rejection. CI
caught a wrongly bound test callback; the fixture was corrected before passing.

Commando and Mondo no longer turn repeated missing health bars into defeat. A
monotonic absence interval ends an unconfirmed search, with one final check of the
existing defeat image. Reacquiring health resets the absence interval. Commando
failure does not advance LastCommando, and LastMondoBuff advances only after its
buff template is detected. Both reserve a separate five-minute retry before work
and renew it on failed/interrupted visits. An in-process lease prevents nested
visits even when a fight outlasts the persisted delay.

The absence/retry/lease policies are covered by controlled tests; the actual main
consumers passed Windows validation and source review. Live boss actions, current
notification/template accuracy, unique/fresh receipts and counter transactionality
remain unverified. Ordinary Spider/Ladybug/Rhino/Mantis/Werewolf/Scorpion code still
has inferred success and fixed kill counts, which need per-field confirmation and
recovery. Downstream input calls still need their own freshness guards; validating
a search does not validate a later click.

[Combat verification](combat-verification.md) records these limits. The full
production objective remains active, including all other feature, state, reporting,
optimization, proposed-feature and release/live-verification gates.

## Remote capability checkpoint

Code checkpoint: `13338ee4d69bd31521d9ba346f11493cb85f40dc`.
[Windows run 34423609802](https://github.com/fenixJK/NatroMacroDev/actions/runs/34423609802)
passed **40 regression groups on each AHK architecture**, native permission-window
and screenshot checks, the existing geometry/pointer/image/health integrations,
six script validations and four emitted-worker validations per architecture,
and **35 updater scenarios on each PowerShell version**. No AHK warnings occurred.
CI caught and prompted corrections to an oversized switch case and a checkbox
expression before the passing checkpoint. The checkout Node deprecation notice
remains a separate CI maintenance item.

Status > Permissions now provides seven independent, disabled-by-default optional
capabilities, separate from the existing user/role authorization requirement.
Ordinary macro commands remain available to authorized controllers. Desktop
capture/control, file upload/receipt, system restart, diagnostics and personal
commands require explicit local grants. Permissions live outside the remotely
editable settings registry and are read again for each new dispatch. The local
permission button remains usable while the macro runs.

Direct screenshots default to focused Roblox client capture, with no desktop
fallback. A revoked desktop permission also blocks a previously selected desktop
mode. Remote attachment receipt uses generated names in a dedicated inbox instead
of arbitrary destination directories. Single-file uploads reject folders,
wildcards and the known credential/permission INI filenames. Generic configuration
lookup also rejects authentication and permission keys.

Native Windows tests open/save/reopen/cancel the actual permission window, capture
an owned client with exact dimensions, reject missing Roblox and invalid modes,
and verify immediate local revocation. Regression tests exercise aliases,
independent grants, malformed persisted masks, private settings and file paths.
No test contacts Discord or confirms Roblox gameplay.

[Remote permissions](remote-permissions.md) records the capability contract and
remaining limits: local personal code and desktop input are powerful grants;
uploads/logs are not comprehensively redacted; attachment downloading still needs
response/time/size bounds and partial-file recovery. Live identity changes,
multiple-DPI UI/capture behavior, redacted support preview, command serialization
and reliable delivery remain open. All other feature, state, optimization,
proposed-feature and release gates stay in scope. The full production objective
remains active; the user has no live Windows/Roblox machine and authorized code
fixes and CI to continue.

## Bounded attachment receiving checkpoint

Code checkpoint: `3e043a3fc0260b9a3c59aa27b0359f43c17209cd`.
[Windows run 34424402811](https://github.com/fenixJK/NatroMacroDev/actions/runs/34424402811)
passed **41 regression groups on each AHK architecture**, native GUI/image/health/
pointer checks, six script and four emitted-worker validations per architecture,
**43 attachment checks on each PowerShell version**, and **35 updater scenarios
on each PowerShell version**. No AHK warnings occurred. CI caught an incorrect
test helper that expected ValueError for the busy-worker Error; the test was
corrected without changing the busy rejection behavior. The checkout Node notice
remains open.

Remote attachment downloads no longer block the Status loop while reading a
response. One owned Windows PowerShell worker receives JSON through stdin and
streams into an exclusively created temporary file. It accepts only the named
Discord CDN hosts over HTTPS, refuses redirects and non-200 responses, and sends
neither bot credentials nor browser cookies. A 30-second monotonic deadline
covers headers and body reads. Actual bytes are bounded regardless of the presence
of Content-Length; an advertised length must also match the completed stream.

Limits are 25 MiB per attachment, 250 MiB of inbox data and 200 files. An exclusive
inbox lock serializes cooperating workers' quota checks. Successful files are
flushed and moved to a unique final filename without overwrite; ordinary failures
remove partial files. Status polls completion, rejects a second active download,
and uses a polled 45-second watchdog. Normal helper shutdown terminates the owned
worker before removing its receiving directory.

The HTTP fixtures verify binary byte preservation, rejected URLs/redirects,
non-200 and truncated responses, fixed/chunked size limits, stalled headers/body,
quotas, target collisions, partial cleanup and concurrent inbox ownership on
PowerShell 5.1 and 7. AHK tests exercise pending/completed/malformed worker results,
busy rejection, watchdog failure, actual production-worker stdin launch from a
Unicode working directory, and native child termination/partial cleanup. Tests
use temporary data and loopback HTTP; they do not send Discord messages.

[Remote permissions](remote-permissions.md) documents remaining uncertainty after
forced process termination/power loss or a crash between file publication and
the completion reply. Abandoned partials count toward quota; automatic crash
reconciliation and durable receipt messages remain open. Other legacy blocking
Status operations can delay the outer watchdog. Live Discord receipt, redacted
support preview, broader command/report delivery, remaining game features,
optimizations, proposed features and release verification remain in scope. The
full production objective remains active.

## Redacted support report checkpoint

Code checkpoint: `65d1903366cea76329afbcaf7d42892b445de042`.
[Windows run 34425348962](https://github.com/fenixJK/NatroMacroDev/actions/runs/34425348962)
passed **42 regression groups on each AHK architecture**, native GUI/image/health/
pointer checks, six script and four emitted-worker validations per architecture,
**43 attachment checks** and **35 updater scenarios** on each PowerShell version.
No AHK warnings occurred. CI first caught local/global name shadowing, which was
corrected with explicit local scope.

An intervening run passed the support-report group but exceeded the attachment
fixture's former 15-second native-startup observation. That test now observes the
same worker through its existing 45-second production watchdog and records its
outcome; it does not restart a still-running worker. The aggregate suite deadline
is 90 seconds to accommodate this plus other tests; individual script validation
remains 60 seconds. The final native workers completed URL rejection normally
after about 5.1 seconds (64-bit) and 10.0 seconds (32-bit). This does not establish
the cause of the earlier delay or change production timeout policy.

The debug hotkey, tray and Debug Options now open a local support-report preview.
Opening it does not touch the clipboard. Recent log excerpts start excluded;
users can opt in, review the text, copy the displayed report or choose a local
text-file destination. The Debug Options window was enlarged so its report button
fits inside the client area. Shared registry-based Roblox installation detection
was extracted without changing its detection rules.

The report keeps runtime/hardware and setup observations, including arbitrary
display scaling, registry-based Roblox type, RDP/touchscreen checks and the main
process's available recent offset/newer-version observations. Full installation
paths and raw configuration dumps are omitted. Hardware inspection uses registry
and native memory reads rather than WMI.

Known configured credentials and IDs are replaced, credential-bearing lines are
removed, and URLs, drive/UNC paths and local identities are filtered. Optional
recent issues use a bounded tail, discard an incomplete first line and retain at
most ten matching lines. Oversized lines are omitted whole. Missing/unreadable/
oversized redaction configuration excludes log excerpts; missing logs produce an
unavailable result instead of aborting the report.

Remote debug commands now build a text attachment directly and never read or
write the system clipboard. The obsolete clipboard IPC handler was removed.
Remote log sends a redacted recent-issue report rather than the raw log file.
These commands still require Diagnostics permission and explicit identity
authorization. JSON metadata disables incidental mentions and preserves the reply
ID; multipart encoding owns the prepared text before queue handoff.

Tests cover configured/unlabeled secrets, credential lines, IDs/URLs/paths,
missing/unreadable config and missing logs, bounded recent-issue selection,
retained useful context, native preview opt-in and exact clipboard copy, and the
actual encoded attachment's metadata and redacted text. No test sends a Discord
message. [Remote permissions](remote-permissions.md) records the filtering limits,
Save dialog/multiple-DPI/live-Discord checks and broader diagnostics still open.
Arbitrary free text is not guaranteed anonymous; local review remains useful.
The full recovery objective stays active, including remaining game features,
state/recovery/reporting work, measured optimization, proposed features and
production release/live-verification gates.

## Gather profile validation and persistence checkpoint

Code checkpoint: `aaa098917df9382cf601eff4ead4b6d6babac97f`.
[Windows run 34426812328](https://github.com/fenixJK/NatroMacroDev/actions/runs/34426812328)
passed **43 regression groups on each AHK architecture**, native geometry checks,
six script and four emitted-worker validations per architecture, **43 attachment
checks** and **35 updater scenarios** on each PowerShell version. No AHK warnings
occurred. The existing checkout action's Node runtime deprecation notice remains.

Gather copy/paste now uses a shared parser and typed validation for all fifteen
profile settings. New copies include schema version 1; legacy partial profiles,
integer strings and multiline JSON remain supported. Invalid or duplicate keys,
unsupported versions, unavailable fields/patterns and invalid bounds are rejected
before persistence. Imported field changes retain explicitly supplied pattern
settings instead of invoking field defaults. Native spinners, globals and the
current-field display are refreshed after saving.

Pasting requires a stopped macro. The main process holds its event handlers while
committing the complete Gather section through the Windows profile API. Status
Gather writes cooperate through an OS-owned lock, protecting the section merge
from concurrent remote writes. Unspecified keys and other sections are preserved.
Delayed numeric notifications reload persisted values, and redundant name
notifications do not reset an imported profile. This does not provide a power-loss
transaction, coherent multi-key reads for legacy readers, or protection from
uncoordinated external file editors.

Tests exercise parser failures and compatibility, real INI write failures, an
independent writer blocked by the shared lock, an independent section reader
during repeated commits, and the production copy/paste handlers with native
controls. Only the surrounding tab-enable routine is substituted. CI exposed an
incorrect UTF-16 encoding offset, test fixture scope/declaration errors and an
ambiguous main-script if/try/else, all corrected before accepting this checkpoint.

[Gather profile documentation](gather-profiles.md) records the persistence and UI
publication limits. Full application layout, rapid live remote-edit interactions,
custom-pattern execution and process/power-loss recovery remain unverified.
The user confirmed that no Windows/Roblox machine is currently available and
authorized continued code fixes and CI. Live game verification remains a release
gate; remaining recovery work and the full production objective stay active.

## Bounded reconnect stages and completion accounting checkpoint

Code checkpoint: `154d692761c8a8c81a004dd1d98d7237eebfeb81`.
[Windows run 34427573717](https://github.com/fenixJK/NatroMacroDev/actions/runs/34427573717)
passed **44 regression groups on each AHK architecture**, native geometry checks,
six script and four emitted-worker validations per architecture, **43 attachment
checks** and **35 updater scenarios** on each PowerShell version. No AHK warnings
occurred. The existing checkout action's Node runtime deprecation notice remains.

The reconnect controller now makes one circuit of eligible server candidates,
with five actual launches per candidate and a 30-minute monotonic budget after
any requested scheduled delay. Private-only policy remains private-only. A window
has four minutes to appear, recognizable game/loading imagery has three minutes,
and loading has three minutes to complete. Unknown frames cannot renew a stage;
starting another launch cannot renew the recovery budget. Failed attempts wait
two seconds before another launch. Exhaustion records the reason and invokes the
existing main stop/exit cleanup instead of returning success to an interrupted
action or cycling servers indefinitely.

Loaded-game success requires the existing science template, with disconnect
imagery taking precedence. Loading-image disappearance is now unknown. Searches
share a single owned frame during loading, with focus/geometry checks before
acceptance and unconditional frame disposal; invalid native search results and
nonpositive capture handles are rejected. Routine disconnect checks retain the
smaller center capture instead of adding full-frame searches to every check.
These changes do not establish that existing templates match today's game.

Hive claiming shares the cooperative deadline through its sleeps, walk waits
and checks before movement. Cleanup releases the interaction key and ends the
walk worker. A failed claim no longer publishes reconnect completion or repeatedly
extends planter/gingerbread times by the full recovery duration. Legacy timer
adjustments happen after the claim routine accepts a hive (or a connection-only
check); elapsed compensation uses actual monotonic time including scheduled delay.
Zero elapsed time no longer invents a five-minute adjustment. This retains the
legacy timer model; the game-side offline/online growth model is not verified.

Clock-controlled tests execute the production stage controller with missing,
unknown, loading, loaded and disconnected observations. They cover candidate
exhaustion, private/public-only ordering, late observation and launch callbacks,
clipped waits, and repeated slow launches sharing exactly one aggregate deadline.
Native search-result classification rejects errors and conflicting disconnect /
loaded evidence favors disconnect. Main and helper validation covers integration
syntax; full main-process orchestration, actual browser/deeplink launching,
process ownership, live input and timer effects are not exercised by these tests.

[Reconnect verification](reconnect-verification.md) records the remaining gates.
This is a cooperative deadline, not a hard preemption guarantee for blocking
Windows/COM calls. Browser launch/WMI cleanup isolation, positive post-input hive
receipts, broader background/input coordination, and crash-atomic timer updates
remain open. Live Windows/Roblox scenarios remain unverified. The full production
objective remains active, including remaining features, state/reporting work,
measured optimizations, proposed additions and release verification.

## Owned reconnect helpers and process cleanup checkpoint

Code checkpoint: `eaede17d4fc62df28b7cc92fc18ef8a2330be870`.
[Windows run 34428722978](https://github.com/fenixJK/NatroMacroDev/actions/runs/34428722978)
passed **45 regression groups on each AHK architecture**, native geometry and
owned-process integrations, seven script and four emitted-worker validations per
architecture, **43 attachment checks** and **35 updater scenarios** on each
PowerShell version. No AHK warnings occurred. The existing checkout action's Node
runtime deprecation notice remains. Production script validation now precedes
runtime tests so helper syntax errors are surfaced before starting fixtures.

Browser/deeplink launches and player cleanup now run in an owned AHK helper. The
parent creates the helper directly through CreateProcessW, keeps the returned
process handle, and passes bounded JSON through a uniquely named shared-memory
mapping. Requests do not put private codes in command-line arguments or temporary
request files. The worker constructs canonical Bee Swarm URLs/protocol targets
from validated types and codes; unrelated extra URL parameters are not forwarded.
The Explorer-shell browser path retains the existing de-elevation approach and
uses ordinary Run as its exception fallback.

Each helper has a 20-second deadline, also checked against the reconnect budget.
Timeout/normal exit cleanup terminates only the owned helper when needed and waits
up to two seconds for a terminal state before releasing its process and mapping
handles. Failure to establish termination is fatal rather than an ordinary retry,
and the retained job is available to exit cleanup. Spawned browser/game processes
intentionally survive helper completion; a timeout cannot undo an external launch
already dispatched. The outer reconnect controller consumes helper failures as
failed attempts and retains its finite attempt/time limits.

CloseRoblox no longer sends foreground Esc/L/Enter or uses WMI substring matching.
A native process snapshot selects the exact RobloxPlayerBeta.exe basename. Image,
user SID and session are checked through an opened process handle before requesting
WM_CLOSE for that process's windows and terminating remaining verified players.
The same handles remain owned through termination. Studio, installers, shared UWP
hosts and command lines merely containing Roblox are excluded. The five-second
post-close delay is retained. This identification does not verify an Authenticode
publisher and does not add support for the unsupported UWP client.

A nested main-process ownership gate now covers reconnect and CloseRoblox.
Background actions are suppressed while recovery owns the game, and normal/error
cleanup releases the gate. Gate tests exercise suppression, nested release and
failure cleanup. Native process tests exercise Unicode/quoted shared requests,
repeated handle cleanup, invalid production requests, a real timeout followed by
confirmed process termination, exact player selection and the production cleanup
worker leaving a Roblox-named Studio decoy alive. Fixtures refuse to run if an
existing player is present. They do not launch the real game or a browser.

CI first exposed an unavailable 64-bit InterlockedExchange export: the request
fixture reached completion but remained in an error dialog. Completion now uses
the process-exit signal before consuming shared-memory results. A separate native
fixture working-directory error was corrected, and invalid-request coverage now
requires a worker-authored rejection instead of accepting a generic startup
failure. Both fixes were verified in the final run above; timeouts were not raised.

[Reconnect verification](reconnect-verification.md) records the remaining limits.
Hard parent crashes can bypass exit cleanup; OS-enforced job ownership and crash
cancellation remain open. Native startup/poll/termination calls and main-thread
scheduling still prevent a hard real-time guarantee. Other-user/session testing,
live browser/UAC/update behavior, full cross-process input ownership, positive
hive receipts, timer crash consistency and the rest of the production plan remain
active. No live Roblox scenario, deployment or production release is claimed.

## Kernel-enforced reconnect helper ownership checkpoint

Code checkpoint: `d846e09890536644af6db3cad9ad1bb8668a50c5`.
[Windows run 34429327670](https://github.com/fenixJK/NatroMacroDev/actions/runs/34429327670)
passed **45 regression groups on each AHK architecture**, native geometry,
owned-process and crash/application-survival integrations, seven script and four
emitted-worker validations per architecture, **43 attachment checks** and **35
updater scenarios** on each PowerShell version. No AHK warnings occurred. The
existing checkout action's Node runtime deprecation notice remains.

Reconnect helpers are now placed in an unnamed Windows job through the JOB_LIST
startup attribute in the same CreateProcessW call that starts them. Kill-on-close
is enabled and the job handle is not inherited. A parent hard crash therefore
closes its only job handle and Windows terminates the helper without relying on
AHK exit callbacks. There is no separate launch/assign interval in which the
helper could escape ownership if the parent dies.

Silent breakaway preserves applications launched by the helper: closing its job
must not kill an already launched browser/game. A helper that creates another
owned helper gives it an independent job. Normal cleanup still waits on the exact
process handle, closes the job and mapping handles, and destroys the startup
attribute list on both successful and failed creation. Job setup/creation failures
do not fall back to an unowned process. This startup path requires Windows 10 /
Server 2016 or newer; the exercised CI host remains Windows Server 2022.

Native fixtures keep a nested helper alive, verify process/job membership, kill
its owner directly with TerminateProcess (bypassing OnExit), and require the
nested helper to terminate while the harness still holds the outer job. Other
fixtures launch a disposable application, verify it is outside the helper job,
and require it to survive normal and forced helper cleanup. Failed executable
creation is repeated with process-handle counts checked afterward. Tests also
check that crash-fixture cleanup leaves surrounding jobs unchanged. The earlier
shared-memory, timeout, player selection and decoy-survival coverage remains.

[Reconnect verification](reconnect-verification.md) documents the current limits
and primary Windows API references. This closes the previously recorded ordinary
parent-hard-crash ownership gap for these helpers. It does not undo external
launches already dispatched, provide durable launch receipts across power loss,
or impose hard real-time bounds on every native API or delayed main-thread poll.
Live browser/UAC/update behavior, full input coordination, other-user/session
exclusions, positive hive receipts, crash-consistent timers and the remaining
production plan stay active. No live Roblox scenario or release is claimed.

## Shared planter dialog interaction checkpoint

Code checkpoint: `a42bda05bb85c7ce794d9ea0a41ff18960d5d036`.
[Windows run 34430667656](https://github.com/fenixJK/NatroMacroDev/actions/runs/34430667656)
passed **46 regression groups on each AHK architecture**, native Windows input,
geometry and process integrations, seven production script and four emitted-worker
validations per architecture, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The existing checkout Node
runtime deprecation notice remains.

Automatic and manual harvests now share the same dialog interaction controller.
It presses E once, waits for delayed prompts, and clicks a recognized Yes/No pair
at most once. Partial or stuck dialogs, blocked observations, stale input frames,
focus loss and geometry changes return unconfirmed before the legacy state-clear
branch. The recovery wrapper stops further attempts after that outcome and retains
its persistent five-minute delay. A reappeared E prompt invalidates an earlier
absence; the final wait is followed by another observation, without authorizing
new input after the deadline. Existing full-grown-only and Harvest Now choices
remain represented. The automatic Harvest Now flag is cleared in memory as well
as INI when the legacy continuation path consumes it.

The native surface releases its synthetic key on ordinary cleanup/exit, restores
mouse coordinate mode and thread critical state, and checks focus/geometry after
input. The configured key delay no longer falsely expires an already authorized
press. Offset lookup does not activate Roblox and is reused only within the same
client geometry for the interaction. Tests exercise real Windows button delivery,
stale-frame refusal, delayed key input and focus changes while a key is held.
Scripted tests cover delayed, stuck, partial and late dialogs, prompt reappearance,
initial expiry and uncertain input stopping repeat harvest attempts.

The first CI run rejected a local/global variable-shadowing warning. It was fixed;
the native fixture also explicitly restores its original window focus before
subsequent pointer checks. Run 34430567023 passed the initial fixes, and the final
run above includes the additional deadline observations and regression cases.

**F05 remains open.** Accepted/no-dialog are interaction outcomes, not positive
harvest receipts, and the legacy branches still clear records and count harvests.
[Planter verification](planter-verification.md) records this limit explicitly.
Positive completion evidence for full-grown/stacked planters, crash-consistent
state/counter updates, live inventory reconciliation, hard-kill key release and
full input coordination remain unfinished. The polling limit is cooperative and
no capture-performance improvement is claimed. The full production plan remains
active; no live Roblox scenario, merge, release or deployment is claimed.
