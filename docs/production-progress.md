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

## Consistent statistic increments checkpoint

Code checkpoint: `f5e8b4ab765792890fe4576ae24957b4ce6cb187`.
[Windows run 34431028805](https://github.com/fenixJK/NatroMacroDev/actions/runs/34431028805)
passed **47 regression groups on each AHK architecture**, the existing native
Windows integration suites, seven production-script and four emitted-worker
validations per architecture, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The checkout Node runtime
deprecation notice remains.

The main increment helper previously always added one locally while forwarding
its requested amount to StatMonitor. Its unused planter/quest branches also named
nonexistent globals/keys instead of PlantersCollected and QuestsComplete. The
helper now validates and maps all six categories, applies the same amount to the
lifetime/session totals, persists them, updates memory and publishes the same
amount. Zero is a no-op; invalid names, negative/fractional/oversized amounts,
corrupt totals and signed-64-bit overflow are rejected before mutation.
StatMonitor independently validates incoming IDs/amounts and prevents overflow.
AHK critical state is restored after each helper/receiver operation.

Twenty-eight duplicated main-program accounting blocks and the shared quest
turn-in counter path now use the helper; the existing Vicious call uses its fixed
implementation. All original event triggers and one/two-count quantities remain.
Explicit lifetime/session resets are unchanged. This is shared counter accounting,
not proof that a route killed the inferred number of bugs or a planter harvested.

New regression coverage invokes the production helper for every category with
both explicit two and default one, checks canonical saved keys, validates saved
values before dispatch, and exercises the production receiver logic. It rejects
malformed/overflowing increments and induces a real first INI-write failure by
blocking the settings directory, verifying no memory update or publication. The
transport is a fixture; native cross-process message delivery is not claimed.
Existing quest outcome/retry tests also passed with the shared counter helper.

[Reporting verification](reporting-verification.md) describes remaining limits:
the two INI keys are not a crash-atomic pair, posted increments are not durable,
and monitor restart, missing messages, reset/rollover coordination, positive game
event receipts and a shared persistent state writer remain open. The full
production plan is still active. No live Roblox/Discord verification, performance
gain, release, deployment or merge is claimed.

## Serialized simple command replies checkpoint

Code checkpoint: `56ccf31b4e49af5cdea06d06ad52b195a1dd3eb6`.
[Windows run 34431356153](https://github.com/fenixJK/NatroMacroDev/actions/runs/34431356153)
passed **48 regression groups on each AHK architecture**, the existing native
Windows integration suites, seven production-script and four emitted-worker
validations per architecture, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The checkout Node runtime
deprecation notice remains.

SendEmbed previously concatenated raw description/content into JSON while some
callers pre-escaped paths and newlines and others passed unescaped errors or user
values. It now uses the existing raw-text serializer. All repository SendEmbed
call sites were checked; pre-escaped window/file/command strings were removed and
message newlines converted to AHK newlines, including separately assembled
priority-list text. Embedded regex patterns and INI paths retain their literal
backslashes. The helper preserves explicit channel and synchronous response
behavior, numeric color, bounded text and attachment references.

A shared reply-object builder serializes disabled parsed mentions, the message ID
and the boolean missing-message fallback. File/image reply references use this
builder. The setting-value reply now serializes its fields with Discord-sized,
Unicode-safe bounds and preserves the existing blank-value marker. Reply IDs are
checked as decimal strings no longer than 20 digits.

The new test group invokes production SendEmbed and the missing-file reply caller
with only HTTP transport replaced. It verifies quote/backslash/control-character
and Unicode round trips, actual versus literal newlines, channel and response
behavior, numeric color, reply metadata, setting fields, length bounds and invalid
IDs. Existing loopback multipart and queue tests passed. No real Discord request
or user message was sent.

[Reporting verification](reporting-verification.md) lists unfinished work. Larger
help/timer/planter/shrine/blender/memory-match payload builders, live honey edits,
command queue migration, global rate limits, durable outbox/recovery and live
end-to-end reporting remain open. Synchronous command replies still lack queue
retry/acknowledgement guarantees. F23 and the full production plan remain active;
no live verification, deployment, merge or production release is claimed.

## Serialized and complete command help checkpoint

Code checkpoint: `2b5e3604e323578c53b1021770111f736e4f1492`.
[Windows run 34431820405](https://github.com/fenixJK/NatroMacroDev/actions/runs/34431820405)
passed **49 regression groups on each AHK architecture**, the existing native
Windows integration suites, seven production-script and four emitted-worker
validations per architecture, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The checkout Node runtime
deprecation notice remains. Initial implementation run 34431719309 also passed;
the final run includes stronger per-setting completeness checks.

Useful, advanced, priority and settings help now build structured objects and
serialize them. Every existing alias is retained. Custom prefixes are inserted as
raw strings, including in the settings title; quotes/backslashes cannot corrupt
the help JSON. Numeric colors and boolean inline flags replace concatenated
values. Screenshot and debug descriptions now reflect the current capture default,
desktop permission and redacted support-report behavior.

Settings help no longer relies on a local-copy trimming loop or a ten-iteration
page ceiling. Eligible setting names are grouped under section headings, including
additional sections, then paginated without losing text. Each description fits
4096 UTF-16 units; splitting prefers newlines and preserves Unicode pairs on an
overlong line. Multi-page titles show position. All pages suppress parsed mentions,
and only the first references the originating command. Status sends each returned
payload through the existing synchronous API.

Regression tests cover every help alias, quoted/backslash prefixes, all twelve
entries in both command lists, the full eight-item priority explanation, additional
settings sections, and exclusion of settings without a setter regex. A synthetic
1,800-setting list exceeds ten pages; every eligible name must appear exactly once,
and concatenated descriptions must preserve all source text through the final
page. Another test splits a long Unicode line at the description limit without
truncation or surrogate damage. These tests generate/parse payloads, not live
Discord messages.

[Reporting verification](reporting-verification.md) retains the open limits:
timer/planter/shrine/blender/memory-match builders, live honey edits, synchronous
command delivery, rate-limit/outage recovery, durable outbox and full end-to-end
report verification remain work. F23 and the full production plan remain active.
No real Discord/Roblox verification, deployment, merge or release is claimed.

## Structured operational reports checkpoint

Code checkpoint: `9717bf8bd7af8af5a5a928e4dcab2d052d2e0b6a`.
[Windows run 34432410363](https://github.com/fenixJK/NatroMacroDev/actions/runs/34432410363)
passed **50 regression groups on each AHK architecture**, the existing native
Windows integration suites, seven production-script and four emitted-worker
validations per architecture, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The checkout Node runtime
deprecation notice remains. Initial report migration run 34432302092 also passed.

Planter, timer, blender, shrine and memory-match displays now use structured report
builders instead of concatenated JSON. The remaining live-honey payload was also
migrated, preserving its explicit replacement attachment list and synchronous
post/edit behavior. Names, prefixes, field values, colors, boolean inline flags
and reply metadata serialize through the shared contract. Several blender catalog
colors exceeded 24 bits; those now use the normal report color instead of sending
an invalid embed value. The underlying catalog palette itself is not recalibrated.

Report builders consume a supplied snapshot/timestamp and do not edit state.
Planter hold/smoking precedence, future growth, automatic-mode Ready, finite and
Infinite blender rotations, enabled timer groups and memory-game ignore masks are
covered. Invalid timestamps display Unknown. Monster respawn modifiers apply only
to mobs; a corrupt modifier cannot invalidate unrelated machine/event timers.
Shrine display now reads its rotation from the snapshot instead of an unrelated
variable and wraps over the main macro's two-slot model. Remote shrine ready/clear
commands reject slot three and no longer fall through to an unset report-body send.
Existing three-slot planter/blender commands retain their scope.

Attachments now use generated unique filenames and consecutive indexes, without
empty-slot gaps or duplicate filenames for repeated items. A shared bitmap is
attached once and reused by each corresponding embed. Catalog bitmaps remain
borrowed, and the native multipart encoder copies their data. Text-only reports
use ordinary JSON. This is encoding/resource ownership work, not a measured
performance improvement or an atomic settings snapshot.

Regression coverage invokes all five report builders, parses raw quote/backslash/
Unicode data, verifies sparse/repeated slots and matching attachment references,
checks times and rotation/masks, and runs the real Windows multipart encoder with
fixture GDI bitmaps. The source bitmap must remain usable afterward. Honey tests
verify serialization and replacement metadata. Only HTTP transport is replaced;
no Discord message or real game action is sent. Current bundled memory-match data
has 37 items (462 characters if all display names are joined); arbitrary future
field lengths remain bounded rather than fully paginated.

[Reporting verification](reporting-verification.md) records the remaining limits.
F23 still requires command/honey delivery migration, shared rate-limit coordination,
durable outbox/recovery, current-artwork/live rendering checks and full end-to-end
report verification. Positive game receipts, crash-consistent state and the rest
of the production plan remain active. No live verification, deployment, merge or
production release is claimed.

## Asynchronous live honey delivery checkpoint

Code checkpoint: `2bb6bad8af222753649ae5ea61a9acdd9040598d`.
[Windows run 34432989157](https://github.com/fenixJK/NatroMacroDev/actions/runs/34432989157)
passed **52 regression groups on each AHK architecture**, the existing native
Windows integration suites, seven production-script and four emitted-worker
validations per architecture, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The checkout Node runtime
deprecation notice remains.

Live honey posts and edits now share the Status outbox instead of synchronously
waiting for an HTTP response. The queue supports POST/PATCH, optional response
metadata, owner cancellation and per-job age limits while preserving existing
boolean completion callbacks. Its native adapter consumes a bounded-size JSON
message-ID result. Closed queues cannot accept new work, including from completion
callbacks. Server retry deadlines are returned on terminal outcomes so a newly
captured live frame cannot bypass a longer 429 delay after the old frame expires.

The live updater admits one frame at a time. Waiting skips further capture rather
than accumulating stale screenshots; the next eligible tick captures current data.
Successful creation establishes the ID for later PATCH requests. Endpoint/token,
enablement or active-period changes reset session identity and cancel prior work;
late results cannot set the new session's ID. Configuration is rechecked after
image preparation. Webhook message paths precede existing query parameters and
creation normalizes wait=true. Encoded bytes are queued after source bitmap cleanup.

A frame has a one-minute age limit when pumped and uses the shared request timeout
and bounded retry policy. Failed/expired frames back off at least a minute and
honor a longer server delay. Deleted edit targets may be recreated after backoff.
Permanent 4xx responses pause the current live session except retryable 408/429 and
missing edit targets. Successful creation without a usable ID also pauses and logs
the uncertainty, avoiding repeated creation for that successful-but-unidentified
result. A new active period or destination resets the session pause.

Tests exercise single-frame ownership, create/edit selection, message-ID receipt,
query routing, reconfiguration, late results, cancellation cleanup, missing IDs,
permanent failures, deleted targets and closed queues. A five-minute 429 fixture
verifies that one-minute frame expiry cannot shorten server backoff. The loopback
server independently requires POST/frame 1 and PATCH/frame 2, returns JSON IDs,
and the real WinHTTP adapter consumes those results. No Discord request is sent.

[Reporting verification](reporting-verification.md) records limits. Cancellation
is consumed when queued work is reached; it cannot undo external effects already
delivered. Native calls and queue scheduling are cooperative, and synchronous
command replies/bot polling can still delay other work. Lost POST responses can
produce duplicates during bounded retries, and restart loses the in-memory ID.
Durable receipts/outbox recovery, cross-helper rate coordination, remaining command
delivery migration, live capture/rendering and measured resource/performance effects
remain open. F23 and the full production plan remain active. No live verification,
merge, deployment or production release is claimed.

## Upload source preservation checkpoint

Code checkpoint: `559efb185efd5fdf82d23676bceb58a8ccaf665f`.
[Windows run 34433794345](https://github.com/fenixJK/NatroMacroDev/actions/runs/34433794345)
passed **53 regression groups on each AHK architecture**, the existing native
Windows integration suites, seven production-script and four emitted-worker
validations per architecture, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The checkout Node runtime
deprecation notice remains. The first run exposed test-only AHK syntax errors;
this checkpoint corrects those and passed the full suite.

File uploads no longer delete caller-owned files just because they are under
`A_Temp`. Successful sends, oversized-file rejection, encoding failures and
delivery failures preserve the source. Generated folder ZIPs have exclusively
created GUID directories, and cleanup removes only those owned directories. The
old predictable ZIP path is never overwritten or adopted for cleanup.

Folder paths now travel as ASCII JSON on stdin to a fixed encoded PowerShell
script. LiteralPath handles Unicode and shell metacharacters as data. Archive
creation has a cooperative 45-second deadline and sampled output-size checks;
the sender also checks final size. Cleanup stops an active worker before deleting
its files and retains them if worker termination cannot be confirmed. Archives
include the selected folder's root entry. Remote folder uploads remain disabled
under the existing single-file permission policy.

Tests run real PowerShell archive creation and multipart encoding with stubbed
HTTP delivery. They check source retention, size rejection, failure cleanup,
pre-existing ZIP preservation, literal Unicode/metacharacter paths and the ZIP
signature. Both AHK architectures use the system Windows PowerShell executable.
No Discord messages or game actions are sent.

[Reporting verification](reporting-verification.md) records limits. Upload delivery
and archive preparation remain synchronous; a hard parent crash can orphan the
WScript archive worker or its temporary files. Sampled checks are not hard time or
byte bounds, and archive contents are not an atomic filesystem snapshot. Kernel
worker ownership, command delivery migration, shared rate limits, durable outbox
recovery and the rest of the production plan remain active. No live verification,
merge, deployment or production release is claimed.

## Queued command replies checkpoint

Code checkpoint: `4d5d36875aeb6c3a7e47d5c2fcc20b4607b333ed`.
[Windows run 34434105801](https://github.com/fenixJK/NatroMacroDev/actions/runs/34434105801)
passed **54 regression groups on each AHK architecture**, the native Windows
integration suites, seven production-script and four emitted-worker validations
per architecture, **43 attachment checks** and **35 updater scenarios** on each
PowerShell version. No AHK warnings occurred. The checkout Node runtime deprecation
notice remains.

Ordinary Status command replies now use a command adapter over the existing
Status/live-honey outbox. Embeds, help pages, setting values, structured reports,
screenshots, individual-file uploads, attachment-completion replies and item-search
responses return queue acceptance without starting or waiting for HTTP. Endpoint
and token are captured at handoff. The base synchronous library API remains
available; only the pre-shutdown system-restart reply still uses it in Status.

File/image preparation copies payload bytes before handoff, preserving source
lifetime independence. Item-search screenshots release their bitmap even if
preparation or queue handoff throws. SendImage now returns the transport result.
Capacity/closed-queue rejection logs a failed handoff without replaying the command
action. Replies share FIFO order, capacity, bounded retries and failure logging
with other Status reports. Acceptance is not a delivery receipt, and a reply may
arrive after the action it describes.

Scripted tests exercise the actual command adapter for shared queue identity,
raw text/references, fractional 429 delay, captured destination/token, explicit
channels, help/settings/report paths, image/file lifetime and capacity/closed
rejection. The native WinHTTP fixture now submits its gated JSON request through
the production command adapter and releases the server only after caller/polling
progress. Existing multipart tests still confirm encoded image validity after
bitmap disposal. No real Discord command or game action is sent.

[Reporting verification](reporting-verification.md) records limits. Bot polling,
authorization lookups, restart notification, capture/encoding and command actions
can still delay the helper. A retrying earlier report can delay subsequent replies.
Per-job retry delays still need preservation across distinct jobs and shared rate
coordination across helpers. Abrupt exit can lose pending replies; lost responses
can cause duplicates on retry. Durable recovery, full asynchronous command
execution, live verification and the full production plan remain active. No merge,
deployment or production release is claimed.

## Shared queued-request cooldown checkpoint

Code checkpoint: `d0d623ae29376db809c71c4154c2e8181cf436c6`.
[Windows run 34434884867](https://github.com/fenixJK/NatroMacroDev/actions/runs/34434884867)
passed **56 regression groups on each AHK architecture**, native Windows suites
including new opposite-architecture cooldown sharing, seven production-script and
four emitted-worker validations per architecture, **43 attachment checks** and
**35 updater scenarios** on each PowerShell version. No AHK warnings occurred.
The checkout Node runtime deprecation notice remains.

Queued HTTP 429 delays now belong to a sending identity rather than to the failed
message. Expiry, cancellation or attempt exhaustion cannot make a subsequent
message bypass the retained server deadline. The response clock is read after
polling, fractional milliseconds round up, shorter deadlines cannot replace longer
ones, and pathological durations saturate rather than overflow. Live-honey result
callbacks continue receiving the effective retry deadline.

Native queues share monotonic deadlines through session-local Windows mappings
and nonblocking mutexes. Same-token bot requests share a conservative gate across
channels and helpers; unauthenticated requests share one gate. Kernel names contain
only an identity digest, and registry/entry counts are bounded at 128. Contention
prevents new requests and keeps failed publications pending for later pumps, even
after the queue empties. An abandoned mutex retains the observed deadline and adds
at least a minute of recovery backoff. Native slots outlive individual queues.

Scripted tests cover first-message removal followed by a new message, deadline
boundaries, response-processing time, identity separation, fractional rounding,
duration overflow and queue replacement. Native tests use the opposite AHK runtime
to read/extend a deadline, verify the extension after that child exits, terminate a
lock-owning child, retry pending publication and check handle cleanup. A loopback
server sends a 2.5-second Retry-After header with a shorter JSON delay and rejects
an early second message. The first message has already exhausted its attempts.
No Discord request or game action is sent.

[Reporting verification](reporting-verification.md) records the contract and
limits. This conservatively holds more routes than a bucket-aware scheduler.
Synchronous polling/authorization and restart notifications still bypass it.
Requests already started before a 429 publication cannot be recalled. Shared
memory lasts only while participating processes retain it; all-helper shutdown,
session changes and reboot do not preserve it, and interrupted publication remains
uncertain. Durable cooldowns/outbox recovery, proactive bucket headers, all-request
coordination, live verification and the full production plan remain active. No
merge, deployment or production release is claimed.

## Asynchronous bot polling and authorization checkpoint

Code checkpoint: `a336b89a482f4f941cd40b66b0cbcde2ab7ea7f1`.
[Windows run 34435871294](https://github.com/fenixJK/NatroMacroDev/actions/runs/34435871294)
passed **60 regression groups on each AHK architecture**, native Windows suites
including opposite-architecture cooldown sharing, seven production-script and four
emitted-worker validations per architecture, **43 attachment checks** and **35
updater scenarios** on each PowerShell version. No AHK warnings occurred. The
checkout Node runtime deprecation notice remains.

Status now polls messages and reads channel/member identity through a separate
bounded asynchronous GET queue. One read can be active alongside one outgoing
request, sharing the same observed bot-token cooldown. Reads use a ten-second
request deadline, twenty-second job age, three attempts and bounded usable response
text. Transient failure backoff remains recoverable and honors longer server
deadlines. Permanent channel/credential failures and repeated unusable data pause
the session with local diagnostics. Legacy synchronous library methods remain for
custom callers; Status no longer uses them for polling or role lookup.

Startup establishes a watermark without executing historical commands, and the
readiness announcement follows that response. Later pages validate identities and
structure before admission, order/deduplicate IDs exactly, ignore bot/webhook
messages, cap the command buffer at 100 and leave the cursor before an unadmitted
command. Large unavailable pages shrink toward one without losing the cursor.
Commands older than five minutes, more than a minute in the future or lacking a
valid UTC timestamp are skipped; received commands expire after a minute in the
buffer. This depends on the Windows clock being correct.

Role-based dispatch waits for a current channel/guild and matching member response.
Role evidence lasts five seconds, and dispatch rechecks the current token, channel,
prefix and allowlist. Configuration changes discard buffered work and invalidate
late responses. All API identities must be decimal strings, with exact comparison
for the requested channel/member. The existing local capability gate still precedes
actions, and HTTP callbacks never execute game actions. Explicit-user authorization
uses the existing local allowlist contract without a role request.

Tests cover startup replay, ordering/duplicates, exact string identities, invalid
pages, cursor/capacity, role expiry/mismatch, stale timestamps, adaptive pages,
configuration changes, late responses, disablement, outages, 429 and permanent
failures. A native loopback server requires GET with no body and the fixture token,
then supplies baseline/new messages and channel/member JSON. The controller must
produce a currently authorized command without executing it. Another native check
rejects oversized usable response text. No real Discord command or Roblox action
is sent.

[Reporting verification](reporting-verification.md) records limits. WinHTTP may
allocate a full response before the text-length check. Role revocation can remain
unseen within its short evidence window. Restart establishes a new watermark rather
than recovering pending commands, and game actions lack transactional receipts.
Live Discord permissions/content intent/backlog behavior, resource soaks, durable
action recovery, the synchronous pre-shutdown notification and the full production
plan remain active. No merge, deployment or production release is claimed.

## Startup ownership and explicit settings override checkpoint

Code checkpoint: `0c09bd55faa057da44f7c9db035f35036f5409a9`.
[Windows run 34448291521](https://github.com/fenixJK/NatroMacroDev/actions/runs/34448291521)
passed **61 regression groups on each AHK architecture**, the native Windows
suites including real startup settings dialogs, seven production-script and four
emitted-worker validations per architecture, **43 attachment checks** and **35
updater scenarios** on each PowerShell version. No AHK warnings occurred. The
checkout Node runtime deprecation notice remains.

Each scheduled start now owns its mode and session until rejection, cancellation
or the running loop ends. Duplicate requests cannot overwrite automatic/remote/
local intent. Rejected preflight restores Start controls once; cancelled timers
and late callbacks cannot start or release a newer session. Automatic and remote
starts retain the installation, settings, window/offset and input-message access
checks while avoiding modal prerequisite dialogs. Returning from the main loop
unexpectedly enters the fault path.

Closing the incorrect-settings warning no longer grants an override. Explicit
session Ignore changes memory only. Remembering the override requires a checkbox,
confirmation and a successful INI write before changing memory. Replaced dialogs
cannot apply old choices, including replacement during confirmation. Persistence
failure leaves the warning open. Existing persisted preferences remain honored.

Pause and the main background action callback require running session ownership;
background work also requires running MacroState. Running state publication now
follows initialization and required helper launch requests. A background helper
launch error propagates rather than disappearing. Stop cancels startup ownership,
publishes stopped state and exits with a diagnostic if Reload leaves the old
instance alive after its ten-second grace period.

Tests exercise all start modes, duplicate/reentrant starts, exceptions, real timer
cancellation, stale callbacks, loop return and cancellation without re-enabling
controls. Real temporary INI writes verify session-only and remembered overrides,
including a write failure. Native GUI fixtures click Close/Ignore and exercise
confirmation, replacement and failed-save paths on both architectures. Initial
CI exposed a callback-binding error and fixture variable-shadowing warnings;
both were corrected without relaxing checks. Run 34447782857 also had a 32-bit
attachment worker timeout; both architectures passed that unchanged worker check
in the following run and this checkpoint. Its intermittent timeout cause remains
unresolved, and no additional retry or relaxed deadline was added.

[Startup verification](startup-verification.md) records the contract and limits.
The full main GUI/game flow, forced reload failure, live input acceptance and
helper readiness are unverified. Existing settings XML substring checks and
missing-file acceptance remain. Helper initialization lacks a readiness handshake;
main-process background gating is not complete cross-process input ownership.
F18 and the full production plan remain active. No merge, deployment or production
release is claimed.

## File worker ownership and shared-memory transport checkpoint

Code checkpoint: `c86ef25de092d18c784ccd5cbce0a5dbe114a328`.
[Windows run 34449086921](https://github.com/fenixJK/NatroMacroDev/actions/runs/34449086921)
passed **61 regression groups on each AHK architecture**, native Windows suites
including file-worker descendant cleanup and owner-crash tests, seven production
and four emitted-worker validations per architecture, **eight file-channel
checks**, **43 attachment checks** and **35 updater scenarios** on each PowerShell
version. No AHK warnings occurred. The checkout Node runtime notice remains.

Attachment downloads and local ZIP preparation now use creation-time Windows job
ownership. File workers and their descendants cannot break away; abrupt owner
death closes the last job handle and terminates them without exit callbacks.
Reconnect launchers retain their separate breakaway policy, verified by the
existing application-survival tests. Normal cleanup terminates the entire file
job, checks active-process accounting and confirms the retained root process
handle is terminal before deleting owned temporary data. Failed confirmation
retains ownership and files.

Fixed PowerShell scripts receive UTF-16 JSON through a bounded 16 KiB mapping,
with a maximum of 8,000 request units. The existing reconnect limit remains
4,096. Only script/channel identifiers appear in command arguments; stdin/stdout
pipes and temporary request files are unnecessary. Workers validate version,
length and JSON and return a fixed numeric status/reason. Missing completion or
nonzero process exit cannot mean success. Attachment completion callbacks run
once after cleanup; callback errors no longer trigger a contradictory second
notification. Existing download quotas, URL restrictions and deadline rules,
archive source preservation and remote single-file-only permissions remain.

Actual download-worker launch and ZIP creation pass on both AHK architectures.
Native fixtures verify literal Unicode/quoted requests, action exceptions, silent
exit, repeated handle cleanup, normal descendant termination and abrupt owner
death. The crash fixture confirms workers are outside the harness's own outer
job before killing their immediate owner. PowerShell 5.1/7 protocol tests cover
valid/maximum requests, invalid version/length/JSON and known/unknown failure
reasons. Initial CI exposed a variable-shadowing warning and a real termination
race: a second TerminateProcess can be denied while the first termination is
still completing. Cleanup now waits for the retained handle instead of treating
that transient result as immediate failure. Checks were not relaxed.

[File worker verification](file-worker-verification.md),
[remote permissions](remote-permissions.md) and
[reporting verification](reporting-verification.md) record the final contracts.
The earlier intermittent WScript attachment timeout has no established root
cause; replacing its pipe transport is not proof that all timeouts are cured.
Crash-left directories, uncertain final publication/notification, durable receipt
recovery, hard bounds for native/filesystem calls, live Discord/game verification
and the full production plan remain open. No merge, deployment or production
release is claimed.

## Bounded watchdog recovery and process identity checkpoint

Code checkpoint: `0a223b221b2c5b98727bf983b2ca255ac2e3fd57`.
[Windows run 34450918133](https://github.com/fenixJK/NatroMacroDev/actions/runs/34450918133)
passed **62 regression groups on each AHK architecture**, native process/GUI
suites including watchdog identity and stronger file-worker descendant waits,
seven production-script and four emitted-worker validations per architecture,
**eight file-channel checks**, **43 attachment checks** and **35 updater scenarios**
on each PowerShell version. No AHK warnings occurred. The checkout Node runtime
notice remains.

Heartbeat's restart path still had a broad WMI Roblox process-kill query and an
unbounded retry loop. It now uses the verified player cleanup helper and exact
main-script identity: full script-window title, runtime image, user and session,
with short/long Windows path normalization and PID/title rechecks after opening
the process. Cleanup uses retained handles. Replacements retain CreateProcessW
handles and require their own PID's visible final main-GUI title before release.
Same-name scripts elsewhere and different-runtime decoys are excluded.

Recovery has at most three attempts, five minutes per attempt including cleanup,
and a rolling limit of three attempts per thirty minutes across successful-looking
replacements. Failed replacements are stopped before another launch; unconfirmed
cleanup aborts recovery. Exhaustion logs a local diagnostic, shows a bounded
message and exits the watchdog. Heartbeat timing now uses monotonic milliseconds,
preserving existing two-minute script and ten-minute window thresholds. Arming
from stopped establishes fresh baselines. Disappearing recipients mean missed
replies rather than an immediate watchdog fault; unexpected faults log and exit.

Controller tests verify attempt ordering, finite hung startup, failed launch,
rolling budget/expiry, production clock/sleeper and no relaunch after failed
cleanup. Native fixtures verify GUI ownership, exact path/runtime selection,
Windows short-path equivalence, decoy survival and closed creation handles.
Review and CI exposed logger initialization, a native Sleep binding, a
fixture-only missing helper and a Buffer naming error. Identity diagnostics
identified short-path notation as the discovery mismatch without weakening the
identity requirement.

The native suites also exposed a race in the prior file-worker checkpoint: zero
active job accounting could precede an observed descendant handle becoming
signaled. Cleanup now captures and verifies member handles before termination,
observes additional members while termination is pending, and waits on those
handles as well as the root. Retained member handles are bounded at 256; confirmed
exited members are released. The previous accounting-only completion evidence
was too weak for the stronger descendant-handle assertion.

Watchdog process counts returned to their starting values (196/196 on 64-bit,
213/213 on 32-bit) and released handles were directly invalid. Subsequent fixture
directory deletion increased process-wide counts to 378/390. The assertion now
measures the process lifecycle before separate filesystem cleanup; it does not
claim a complete resource soak or establish the cause/growth pattern of that
filesystem-related increase.

[Watchdog verification](watchdog-verification.md) and updated startup, reconnect,
file-worker and remote-permission docs record the contracts and limits. Full
Heartbeat/main restart, helper readiness, cross-instance IPC, main's separate
legacy CloseScripts ownership, live Roblox/Discord behavior, crash-state
reconciliation, resource soaks and the complete production plan remain open.
No merge, deployment or production release is claimed.

## Main helper cleanup and generated-worker ownership checkpoint

Code checkpoint: `b637951af5cc5120aa0b508995a81c0e2ca34d8a`.
[Windows run 34453130252](https://github.com/fenixJK/NatroMacroDev/actions/runs/34453130252)
passed all three jobs: **62 regression groups per AHK architecture**, native
process/GUI suites, **eight production-script and four emitted-worker validations**
per architecture, and **eight file-channel checks, 43 attachment checks and 35
updater scenarios** on each PowerShell version. No AHK warnings occurred. The
checkout Node runtime deprecation notice remains.

Main's broad bundled-runtime window cleanup is replaced with a fixed helper-name
allowlist under this installation, using verified script/runtime/user/session
identity and retained process handles. Its watchdog heartbeat exception requires
the matching verified window. Generated movement, Discord/bee/priority GUIs,
bitterberry/basic-egg tools and pattern validation now use owned supervisor jobs,
bounded shared-memory requests/results and explicit UTF-8 pipes. Descendants are
contained through parent crashes. Graceful cleanup runs exit handlers before a
bounded forced job stop. Movement has a parent key-release fallback. Failed
movement is surfaced before replacement; other completed worker errors are logged.

Native fixtures prove opposite-architecture Unicode/source-directory behavior,
parse-only validation, output overflow rejection, graceful and forced cleanup,
replacement, movement failure propagation, cancelled result polling, request/role
bounds, abrupt owner death and preservation of personal/other-installation scripts.
The existing stronger file-worker descendant checks continue to pass through the
extracted shared contained-job base. Review additionally guards startup cancellation
and prevents an unverified child handle from becoming a graceful-close target.

CI caught a working-directory regression introduced by the supervisor: Unicode
survived but stdin scripts resolved from submacros. Explicit root setup corrected
it. An earlier run, 34452874376, also reproduced the intermittent native attachment
timeout on 32-bit (approximately 61.8 seconds) with shared-memory transport. This
confirms that replacing WScript pipes did not eliminate every timeout. The cause
and cooperative-deadline overrun remain unresolved; later passes are not a fix.

[Helper ownership verification](helper-ownership-verification.md) records the
contracts and remaining limits. Old unowned stdin workers cannot safely be found
by runtime alone. Live movement/key release, whole start/stop/pause and watchdog
flows, helper readiness, cross-instance IPC, resource soaks, supervisor cost and
crash-state reconciliation remain open. No Windows/Roblox machine is currently
available; work continues through code fixes and CI. The full production plan
remains active. No merge, deployment or production release is claimed.

## Attachment startup deadline and lifecycle evidence checkpoint

Code checkpoint: `a351bdd48ee00f1661a6bc91db5fc97fb03cb18b`.
[Windows run 34453759775](https://github.com/fenixJK/NatroMacroDev/actions/runs/34453759775)
passed **62 regression groups on each AHK architecture**, native process/GUI
suites, eight production-script and four emitted-worker validations per
architecture, and eight file-channel checks, 43 attachment checks and 35 updater
scenarios on each PowerShell version. No AHK warnings occurred; the checkout Node
runtime deprecation notice remains.

The attachment deadline previously began after native worker creation. It now
includes receiving-directory preparation and creation time. The worker mapping
also carries four monotonic numeric milestones outside the maximum request area:
channel connection, parsed request, returned action and written result. Exceptions
retain the last reached stage. Existing result validation still requires process
completion; diagnostic stages cannot authorize a successful download.

Attachment lifecycle diagnostics record stage, native creation, worker CPU and
elapsed times, process-close time and receiving-directory cleanup time. They
exclude request URLs, query strings, message IDs, receiving paths and exception
bodies. Status writes failed/deadline/unconfirmed-cleanup events and slow cleanup
to its existing local error log. Normal successful completion remains quiet.
Diagnostic callback failure cannot change completion or cause a second reply.

Native tests verify exception, silent exit, stalled action, successful result,
milestone ordering and timing availability. The production URL-rejection fixture
verifies the full numeric diagnostic and startup budget. PowerShell 5.1/7 verify
stage publication across all eight existing mapping cases, including malformed
and maximum-length requests. Existing process ownership and crash checks pass.

The final run's 32-bit/64-bit workers connected at 10578/3360 ms and published
results at 12656/4657 ms. Their CPU times were 562/671 ms, native creation measured
0/0 ms at TickCount resolution, confirmed close 0/0 ms, and directory cleanup
1891/47 ms. These samples expose substantial pre-connection delay and a blocking
filesystem cleanup in successful runs. They do not establish the cause of the
earlier 61.8-second timeout or prove that it is fixed. Moving blocking cleanup out
of the owner, further startup evidence, native/OS deadline overruns, crash-file
reconciliation and live delivery remain open. The production goal remains active.

[File-worker verification](file-worker-verification.md) records the updated
contract and evidence. No merge, deployment or production release is claimed.

## Asynchronous receiving-directory cleanup checkpoint

Code checkpoint: `af1e8c4499a5959a3e7dda3e005653c4b73404d4`.
[Windows run 34454860093](https://github.com/fenixJK/NatroMacroDev/actions/runs/34454860093)
passed **62 regression groups on both AHK architectures**, native process/GUI
suites including receiving cleanup, **nine production-script, four test-entry
and four emitted-worker validations** per architecture, and **eight file-channel
checks, 43 attachment checks and 35 updater scenarios** per PowerShell version.
No AHK warnings occurred. The checkout Node runtime deprecation notice remains.

Status no longer performs receiving-directory deletion in its polling loop.
After confirmed download-worker termination it starts an owned AHK cleanup helper,
retains the active attachment slot and polls the result. Cleanup has a twenty-second
cooperative deadline. Timeout or launch failure adds a retained-temporary-data
message while preserving the actual download result. Ownership is released and
one completion sent only after helper termination is confirmed. Shutdown permits
five seconds of cleanup before stopping the helper and sends no completion reply.
Main may terminate Status sooner; shutdown cleanup is best effort.

The cleanup worker validates the absolute local receiving path, holds inspected
ancestor handles without delete sharing, rejects reparse points and removes only
the ordinary singly linked payload.partial and empty receiving directory through
their verified handles. It performs no recursive deletion or historical scan.
Unexpected contents, linked, read-only and locked files are retained. The published
attachment and inbox lock are outside this operation. Kernel ownership prevents
a cleanup process continuing after its owner crashes.

Controller tests cover pending cleanup, busy rejection, timeout, creation failure,
unchanged confirmed download success, callback isolation and exactly one reply.
Native fixtures verify empty/partial/missing folders, traversal rejection,
unexpected file retention, hardlinks, locked/read-only files and ancestor symlinks.
The real attachment fixture verifies cleanup and shutdown from a Unicode path.
CI caught reserved-name and File-class-shadowing mistakes in the new test fixture;
both were corrected. Test entry points are now syntax-checked before execution.

[Receiving cleanup verification](receiving-cleanup-verification.md) records the
contract and limits. Directory preparation, process creation/termination and
logging still involve native or filesystem calls; upload-archive cleanup remains
synchronous. This is no claim of measured overall performance improvement or a
fix for the intermittent PowerShell timeout. Crash-left file reconciliation,
durable completion receipts, live main/Status shutdown and Discord delivery,
concurrent hostile filesystem mutation and resource/performance soaks remain open.
The full production goal remains active. No merge, deployment or release is claimed.
