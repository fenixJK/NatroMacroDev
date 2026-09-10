# Glue Dispenser workflow verification

The main Glue Dispenser entry retains its enabled setting and 22-hour interaction
cooldown. Its shared workflow reserves the existing five-minute recovery delay
before any game action. Only an observed prompt followed by guarded key input
can publish an interaction timestamp. This still does not establish reward delivery.

## Changes

Every stage now gates the next: reset return/window readiness, inventory opening,
travel completion, gumdrop lookup, drag, inventory closure, dispenser approach,
and prompt interaction. Failed menu closure ends the visit before another route
or input action. A preparatory travel or lookup failure can retry once, after a
confirmed menu close. Once gumdrop input has been attempted, the visit never
automatically retries it, including when the drag itself returns uncertainty.

Failure leaves the existing `Collect/LastGlueDis` cooldown unchanged and reports
the stage through `CollectionRecovery.Failed`. Movement cleanup and failure
publication run through nested finally blocks, including early returns and
exceptions. Unexpected errors still propagate to the existing failure handler.
An immediate scheduler revisit during the recovery delay performs no game action
or movement cleanup. A successful interaction retains the existing full cooldown,
but the status now says `Interacted` and explicitly leaves the reward unverified.

The native adapter preserves the Glue route and six-tile dispenser approach.
Both require successful worker creation, observed F14 start within five seconds,
and F14 release within their existing 120/20-second completion limits. Movement
cleanup runs when waits fail. The adapter checks the current Roblox identity,
foreground window and cancellation generation at stage boundaries. It reuses
the inventory observation/drag lease and the planter dialog surface's guarded E
press: a fresh prompt is required, partial/full yes/no dialogs and detected
disconnect/death blockers reject input, and an owned key press is released in a
finally path. The existing one-second processing delay after E remains.

## Regression contract

The production workflow runs against a deterministic action adapter while using
the real temporary INI recovery store. Cases cover:

- Rejection at each stage, with exact counts for resets, gumdrop attempts,
  approach and interaction. Failed closure cannot trigger the next action.
- Failed cleanup closure after preparatory travel/search: no second trip.
- Successful first attempts and successful preparatory retries: one gumdrop
  attempt, one dispenser interaction, persisted timestamp and cleanup.
- Exceptions at each stage and movement cleanup: preserved prior cooldown,
  published failure and retained retry delay; unexpected errors propagate.
- Immediate scheduler revisits: no actions or cleanup during backoff.

These fixtures exercise the production workflow and recovery persistence. They do
not execute the native Glue route. The shared native menu, inventory drag and
planter prompt/key boundaries have separate Windows fixtures.

## Related callers

Startup now requires confirmed menu closure before resetting session statistics,
starting runtime accounting or launching the running session. Failure returns
through the existing startup-controller cleanup and reports the menu outcome.
The redundant unguarded close before opening Bee List is removed; directly
selecting the bee tab already switches from another selected tab.

## Verified checkpoint

Code checkpoint: `cf07eb39f943468a9f81152eb9c04d249eda6120`.
[Windows run 34471108548](https://github.com/fenixJK/NatroMacroDev/actions/runs/34471108548)
passed **72 regression groups on both AHK v2.0.12 architectures**, including
`TestGlueDispenser`, and all existing native suites. The shared menu, planter
input and inventory pointer checks passed on both architectures. CI also validated
**nine production scripts, four test entrypoints and seven emitted workers** per
architecture. Windows PowerShell 5.1 and PowerShell 7 each passed **eight file
channel checks, 43 attachment checks and 35 updater scenarios**. No AHK warnings
occurred; the checkout action's Node runtime deprecation notice remains.

## Remaining scope

F14 signals a worker cycle, not arrival at the expected game location. The worker
can still move between stage-boundary focus checks, and the existing reset routine
has its own unresolved recovery/hive-confirmation behavior. There is no hard
whole-visit deadline or cross-process input lock in this checkpoint. A generic E
prompt does not identify Glue Dispenser uniquely. Gummy Lair arrival, gumdrop
consumption, prompt rejection and reward/cooldown receipts need recorded images
and live verification before this feature can be called production-verified.

The full startup GUI path and its later helpers are also not exercised by this
workflow fixture. Reset, gathering, Mondo and final cleanup menu callers remain
separate work. No Windows/Roblox machine is available; the full production goal
remains active.
