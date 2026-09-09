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
