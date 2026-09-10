# Menu state verification and guarded input

`nm_OpenMenu` returns 1 only after observing the requested selected-tab state,
and 0 on uncertainty. Its optional third output parameter reports `opened`,
`closed`, `unknown`, `timeout`, `invalid` or `busy`. The existing `refresh=1`
behavior remains close-only. There is no remembered open-tab cache.

`nm_MenuNavigation` uses one five-second cooperative deadline including
preparation, observation and waiting. It sends at most one tab click per call,
then observes the result without repeatedly toggling an uncertain UI. An already
selected target requires no input. Selecting another tab clicks that target;
closing clicks the currently observed selected tab. Unknown images, multiple
selected-tab matches, unexpected transitions or invalid geometry stop the attempt.
A click alone does not establish success.

`nm_MenuSurface` activates the exact initial window once, resolves its HUD offset,
and anchors client position, dimensions, identity, DPI, monitor and styles.
Subsequent captures and input require the same foreground client. Frames expire
after 250 ms; checks occur after capture and before input. The helper updates
legacy window-coordinate globals only from a verified current snapshot. It does
not reacquire focus after another window takes it.

Pointer movement and button input share the existing inventory pointer lease.
Physical/logical held-button checks precede ownership, every owned press has a
finally release, and mouse coordinate mode is restored. The pointer parks outside
the observed tab row after the click to avoid hover effects. Cancellation now has
a generation counter, so a stop during preparation or observation waiting also
invalidates the menu attempt even when no button is currently held. The public
wrapper rejects reentrant calls with an atomic busy guard.

The six menu templates now have one shared source used by the main program and
both inventory consumable workers. The menu class is included before main's
startup return so its initialization runs. Inventory searches propagate menu
failure as unknown before reading or scrolling; twelve previously unchecked
named-menu calls in main now return before their dependent workflow proceeds.
The existing checked item-menu caller also benefits from explicit success/failure.
Quest guards remain inside their existing finally recovery/publication paths.

## Verification contract

Regression cases cover already-open/closed states, switching, close-only refresh,
delayed transitions, unknown/ambiguous/search-error observations, rejected input,
exceptions, invalid tabs, stale state and deadlines. They require no repeated
toggle and cleanup on success or failure. Inventory failure remains unknown and
performs no search or scroll. All six actual bundled menu templates are rendered
and checked individually against the complete template set.

A native GUI fixture uses six distinct synthetic colors for deterministic
selected-tab states. Real screen capture and mouse messages exercise opening,
already-selected behavior and closing all six tabs, plus an unresponsive menu
that receives exactly one click. It verifies coordinate restoration, released
button/lease ownership, published client geometry, and rejected clicks after
movement, focus loss, cancellation, identity invalidation and frame expiry.
The fixture overrides game identity and HUD-offset detection; actual menu assets
are covered separately by the regression renderer, not by a live game session.

## Integration corrections

The first [run 34468885868](https://github.com/fenixJK/NatroMacroDev/actions/runs/34468885868)
found that main's old menu include was below its startup return. The new class
needs initialization, so the include moved into the startup dependency block.
Verified snapshot publication was also retained for legacy coordinate consumers.
The next [run 34469143762](https://github.com/fenixJK/NatroMacroDev/actions/runs/34469143762)
caught a menu-offset local that shared the regression harness's global `failed`
name; the local was renamed, preserving the warning gate.

[Run 34469334463](https://github.com/fenixJK/NatroMacroDev/actions/runs/34469334463)
passed the actual template comparisons but rejected a simulated successful click.
The fixture had used `Array.Push` as a boolean success value. Its recording and
configured return value are now separate. The engine retains a bounded internal
exception cause for diagnostics; the public outcome remains `unknown` on errors.
Once transition tests proceeded, [run 34469655022](https://github.com/fenixJK/NatroMacroDev/actions/runs/34469655022)
exposed an unbound loop variable in the search-error fixture callback. The callback
now binds its observation map explicitly. No behavioral assertion or deadline
was removed to address these fixture errors.

## Verified checkpoint

Code checkpoint: `e50b08b3538c242498e5f6594e875372b3729352`.
[Windows run 34469827181](https://github.com/fenixJK/NatroMacroDev/actions/runs/34469827181)
completed successfully on AHK v2.0.12, both 32-bit and 64-bit. Each architecture
passed **71 regression groups**, the native menu capture, single-click,
cancellation and window-guard checks, and the existing native suites. Validation
covered **nine production scripts, four test entrypoints and seven emitted
workers** per architecture. The screen-capture GDI count remained **34 to 34**;
the **350 text graphics lifecycle cases** also passed on each architecture.

Windows PowerShell 5.1 and PowerShell 7 each passed **eight file-channel checks,
43 attachment checks and 35 updater scenarios**. No AHK warnings occurred. The
checkout action's Node runtime deprecation notice remains.

## Remaining scope

This establishes observed selected-header state, not proof that all menu contents
have loaded. A readable frame with no matching selected header is treated as
closed; arbitrary occlusion, overlays and game UI redesigns can defeat that
inference. There is no new universal modal/blocker detector. The HUD-offset cache
still has its existing lifetime, and native calls cannot be forcibly timed out.

Close-only callers that ignore failure and later workflow actions still need
their own propagation/freshness review. This checkpoint does not verify quest
scrolling, exports, item use, planter placement or collection receipts end to end.
No Windows/Roblox machine is currently available. The production goal remains
active; no release or measured whole-program performance gain is claimed.

## Dependent workflow follow-up

Startup now gates session initialization on confirmed closure, Bee List selects
its tab directly, and Glue Dispenser checks every menu result before continuing
or retrying. [Glue Dispenser verification](glue-dispenser-verification.md) records
the workflow, recovery and spending-attempt limits. Remaining reset, gathering,
Mondo and final cleanup callers have not been declared verified by these changes.
