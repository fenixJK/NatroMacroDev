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

- Pending: actual AHK tests on both bundled architectures.
- Pending: failure-injection tests for updates, interrupted actions, consumable limits, and permissions.
- Pending: live Windows/Roblox scenario matrix from the audit (including routes, game images, UI timing, pause/stop, reconnect, and mixed overnight run).
- Pending: measured baseline and comparison for performance changes.

Local source/static checks are supporting evidence only. They do not certify live game behavior. No production release or merge has been made.

## First implementation checkpoint

Implemented, awaiting Windows CI and live validation: F01 (remove unowned tab closure),
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

Still to implement in the first batch: transactional updater and confirmed planter
harvest/reconciliation. No finding is considered live-verified yet.
