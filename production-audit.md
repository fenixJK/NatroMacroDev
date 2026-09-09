# Natro Macro production recovery audit

Reviewed 2026-09-09. Repository: NatroTeam/NatroMacroDev. Baseline: `66648fd6a290d472dacc45e9407e4c0ca4fa744a`; main script identifies itself as version 1.1.2. This describes the local development checkout, not a verified deployed release.

## Assessment

**Keep AHK and repair the existing program.** There is substantial useful functionality here: configurable gathering, movement correction, extensible paths and patterns, several quest systems, automatic and manual planters, boosts, bosses, recovery helpers, and reporting. A rewrite would have to rediscover a lot of that game-specific knowledge.

The largest problem is inconsistent state management. Several routines record success after an attempt, advance persistent state before confirming an outcome, or return without cleaning up. Other problems come from duplicated implementations and settings that disagree between the GUI, globals, INI files, and helper processes. Those issues explain how a macro can appear to run while missing work, repeating work, or reporting misleading results.

My release recommendation is to resolve the high-priority findings below and complete Windows regression testing before calling this baseline production-ready. That is a code-review judgment, not a claim that every listed failure occurs in every installation.

### Scope and limits

- Reviewed the main program's lifecycle and major feature implementations, configuration/UI handlers, worker-script generation, and supporting recovery, status, timer, image-search, inventory, movement, and Roblox-window code.
- The main file has 23,029 lines. The checkout has 12 pattern scripts and 91 path scripts. Their loading and execution were reviewed; each physical route and bitmap still requires validation against the live game.
- Findings below are supported by static control flow or data handling. Their frequency, game-visible effects, timing, and hardware sensitivity remain to be tested on Windows.
- No AHK runtime, Roblox session, Windows integration test, or performance benchmark was run on this Mac. This is not a certification that all other behavior works.
- Source links are pinned to the reviewed commit so teammates can follow them after files change. Only this report was added; application behavior was not changed.

Priority: **P1** = address before a broad release because it can affect unrelated applications, user data, consumables, access control, or core reliability. **P2** = functional correctness or significant reliability issue. **P3** = smaller utility/diagnostic issue. Priorities consider the trigger conditions, not just worst-case outcomes.

## Feature coverage and direction

| Area | Existing capability | Assessment / next improvement |
|---|---|---|
| Gathering | Three field slots, defaults, patterns, rotations, size/repetitions, backpack/time limits, return modes, quest/planter/boost overrides | Preserve it. Make the selected field and interruption reason visible; separate selection from travel and gathering execution. |
| Movement | Walk/cannon routes, movement-speed correction, generated movement workers, camera handling | Preserve the extension format. Add explicit worker completion/failure results and checkpoints at route destinations. |
| Sprinklers / drift compensation | Multiple sprinkler types and image-based position correction | Test window geometry and offsets systematically. Distinguish a missing sprinkler from an invalid capture. |
| Conversion | Backpack, balloon policies, consumable support, interruption handling | Fix accounting and cleanup on every exit. Confirm empty/refreshed outcomes separately from timeouts. |
| Reconnect / hive | Browser and deeplink methods, private/fallback servers, scheduled reconnect, hive detection and claiming | High priority: browser cleanup and fallback selection have concrete defects. Introduce bounded recovery stages. |
| Collect / Beesmas | Dispensers, passes, Wealth Clock, seasonal machines and collection routes | Consolidate common attempt/verify/retry behavior. A failed visit must not create a full successful-collection cooldown. |
| Bug runs / bosses | Regular enemies, King Beetle, Tunnel Bear, Coconut Crab, Stump Snail, Commando, Mondo modes | Route duplication and unreliable completion evidence need attention. Test each boss independently before combining with interruption-heavy runs. |
| Night / Vicious Bee | Night detection, field search, battle patterns, kill reporting, daily-bonus policy | Several definite logic defects are present. Treat this as a dedicated repair batch. |
| Quests | Polar, Riley, Bucko, Black, Brown, Honey-related work and gathering overrides | Preserve the data. Separate recognition from planning; unknown progress must remain unknown. |
| Planters | Nectar priorities, automatic selection, manual cycles, harvest policies, glitter, hold/smoking options, timers and manual corrections | High priority: state can be cleared after failed harvest confirmation. Reconcile observed and stored planter state. |
| Boosts / hotbar | Boost chasing, automatic dice/glitter/booster use, field extensions, timed hotbar items | Fix live limits, shutdown, and resource ownership before expanding spending features. |
| Blender / shrine | Recipe/donation rotations, finite/infinite counts, timers | Blender decrements the wrong slot. Both should commit rotation/timing only after verified acceptance. |
| Memory Match | Multiple machines, solver and reward preferences | Validate delayed card reveals, unexpected screens, and cooldown handling. No claim that current card images still match the game. |
| Stickers | Printer, stack modes, skin/voucher choices and cooldowns | Add explicit item/quantity/acceptance checks and regression cases for unavailable or already-used items. |
| Discord / statistics | Webhook/bot modes, remote control, screenshots, status logs, hourly reports and buff/honey detection | Useful features, but permissions, capture boundaries, serialization, delivery, and accounting need fixes. |
| Setup / utilities | Hotkeys, startup manager, debug reports, FPS settings, autoclicker, bee-list export, auto-jelly/basic-egg/bitterberry tools, calculator links | Keep secondary to core stabilization. Consumption tools need hard budgets and reliable stop/cleanup behavior. |

## High-priority findings

### F01 — P1: Reconnect cleanup can close an unrelated application or document

**Evidence:** `CloseBrowserTabs()` enumerates ordinary visible windows, excludes Roblox/AutoHotkey and certain window styles, then activates the first remaining window and sends Ctrl+W. It never verifies that the window is a browser or that its active tab was opened by Natro. [main:17853](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L17853); invocation during retries: [main:17679](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L17679).

**Trigger / effect:** Browser reconnect runs while an editor, document, or unrelated browser tab is the first eligible window. Cleanup can close that content or interrupt the macro with a save prompt.

**Fix:** Remove blind Ctrl+W cleanup. If cleanup is retained, identify and close only the resource created for that reconnect attempt; a browser process check alone does not establish tab ownership.

**Verify:** Reconnect with an unsaved document and unrelated browser tabs open. They must remain untouched on both success and failure.

### F02 — P1: Update failure can be followed by deletion of the old installation

**Evidence:** Download, extraction, and migration print success without checking their outcomes. When the user selects deletion of the old version, the batch script reaches `rd /s /q` without establishing that the replacement installation and copied settings are usable. [update:25](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/update.bat#L25), [update:45](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/update.bat#L45), [update:68](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/update.bat#L68).

**Trigger / effect:** A failed/truncated download, bad archive, extraction failure, or failed settings copy, **with “delete old version” selected**, can remove the working installation and settings. Deletion is conditional, not the default behavior asserted by this finding.

**Fix:** Stage the release in a new directory, validate its expected files, check extraction/migration results, retain a backup, and switch the active installation only after validation. Treat cleanup as a later step. Select the intended release asset explicitly and distinguish user-modified patterns from shipped patterns during migration.

**Verify:** Inject download/extraction/copy failures. The old installation must remain usable, with its settings intact, and the updater must report failure accurately.

### F03 — P1: Auto Field Boost limit switches do not update the live limit flags

**Evidence:** The dice, glitter, and hours handlers update a GUI control and write an INI value, but never assign the corresponding `AFBDiceLimitEnable`, `AFBGlitterLimitEnable`, or `AFBHoursLimitEnable` variable. Runtime routines read those variables. [main:6220](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L6220), [main:13661](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L13661), [main:13784](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L13784), [main:13848](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L13848).

**Trigger / effect:** Change a limit from “None” to “Limit” and run without reloading. The UI and disk say limited, while runtime can still use the old unlimited policy. Changing the value of the limit does not repair the missing enable-flag assignment.

**Fix:** Update a single live configuration value, persist it, then render the control from that value. Apply this consistently to all three limits.

**Verify:** Toggle each limit both directions without restarting. Test zero, one, already-exhausted, and partially-used budgets.

### F04 — P1: AFB shutdown and consumable checks are incomplete

**Evidence:** The hour cap turns off `AutoFieldBoostActive` without clearing pending dice/glitter/booster flags. The background dice dispatcher checks the pending flag but not the master enable. Dice and glitter limits are checked after sending input; glitter use is counted only after successful boost detection. [main:13661](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L13661), [main:22340](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22340), [main:13776](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L13776), [main:13836](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L13836).

There is also a scope defect: the dice/glitter functions assign `AutoFieldBoostActive := 0` without declaring it global, so that assignment is local while the GUI and INI show OFF. The [AHK v2 scope rules](https://raw.githubusercontent.com/AutoHotkey/AutoHotkeyDocs/v2/docs/Functions.htm) confirm this interpretation.

**Effect:** Pending actions can survive deactivation; an exhausted budget can still permit an initial input; missed glitter confirmation leaves use uncounted and pending. Actual extra items consumed depends on the game's acceptance/cooldown behavior, but the macro does not enforce its own intended boundary.

**Fix:** Use one cancellation routine for master disable and limits. Guard immediately before each input with active state, target/window validity, remaining budget, and cooldown. Track uncertain attempts separately from confirmed consumption, and stop/reconcile when detection fails.

**Verify:** Turn AFB off or reach the hour cap during a pending roll; miss a glitter result; start with zero remaining. No further item input should occur after cancellation or exhaustion.

### F05 — P1: Failed planter confirmation can erase a planter that is still planted

**Evidence:** Automatic and manual harvest paths search briefly for Yes/No prompts. If the relevant prompt is not found, execution still falls through to clearing the slot and incrementing harvest totals; manual mode also advances the cycle. [main:21588](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L21588), [main:21626](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L21626), [main:22228](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22228), [main:22266](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22266). Separately, five failed automatic harvest attempts explicitly clear the planter record. [main:20772](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L20772).

**Trigger / effect:** A late frame, missed prompt, blocked interaction, or route failure can leave the planter in the world but remove it from Natro's records. Subsequent placement decisions then use false availability and nectar estimates.

**Fix:** Return an explicit outcome such as harvested / deferred / not-found / uncertain. Clear and advance only after confirmed harvest. Preserve uncertain records and use the existing timer/editor capabilities to support reconciliation.

**Verify:** Delay the prompt, hide it, fail travel, and disconnect after pressing E. Stored planter state must survive uncertainty; harvest statistics must only count a confirmed harvest.

### F06 — P1: Bot commands allow everyone in the command channel when the allowlist is blank

**Evidence:** `UserHasPermission()` returns true when `discordUIDCommands` is empty. The command handler includes file access and desktop-control operations, not just macro status. [status:824](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L824), [status:1907](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L1907), [status:1970](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L1970), [status:2105](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L2105).

**Scope:** This applies when Discord bot/command mode is configured and the relevant channel is accessible. It does not mean webhook-only users automatically expose remote control or that arbitrary internet users can reach it.

**Effect:** A channel participant may gain broader control than the owner expects. The generic config-read/file features also warrant secret filtering; an allowed controller should not automatically receive bot credentials through diagnostic output.

**Fix:** Require an explicit authorized user or role before commands work. Separate ordinary macro controls from file/desktop/system operations, and redact credentials from configuration responses and support exports.

**Verify:** Empty allowlist, unauthorized user, authorized user, role membership success/failure, and secret-reading attempts. Authorization failure must not fall through to execution.

### F07 — P1: Automatic status screenshots can fall back to the desktop

**Evidence:** If a status event qualifies for a screenshot and Roblox's window width is unavailable, capture falls back to `Gdip_BitmapFromScreen(0)` and is sent through Discord. [status:714](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L714), [status:728](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L728).

**Trigger / effect:** With the relevant screenshot settings enabled, a crash/disconnect or missing window can send desktop content instead of a game screenshot.

**Fix:** Automatic game-status screenshots should capture a verified game rectangle or report “game window unavailable.” Keep any deliberately requested full-desktop remote screenshot as a separate explicit operation.

**Verify:** Trigger a qualifying status event with Roblox closed. No desktop pixels should be uploaded.

### F08 — P1: Continuable errors are suppressed without preserving the failure

**Evidence:** Error hiding defaults to enabled. The handler returns `-1` for continuable errors and does not log the exception. [errors:1](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/lib/ErrorHandling.ahk#L1). The debug report even labels disabled error hiding as a problem. [main:10459](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L10459). The [AHK OnError documentation](https://raw.githubusercontent.com/AutoHotkey/AutoHotkeyDocs/v2/docs/lib/OnError.htm) explains continuation behavior.

**Effect:** A failure can leave variables/state incomplete and allow subsequent actions to continue, while the useful root cause is lost. This handler does not suppress every possible error; the issue is specifically its treatment of continuable failures.

**Fix:** Preserve file, line, message, stack, current action, and recovery outcome in a bounded local log. Let the responsible action decide whether to retry, abort, or stop; avoid blanket continuation after invalid state. Existing status logging is useful but does not replace exception logging.

**Verify:** Induce a failed image load, missing config value, and invalid window operation. Each must produce a useful local record and a defined recovery outcome.

## Functional and reliability findings

### F09 — P2: “No public fallback” can still select the public server

The candidate map always contains key `0` for public. The fallback expression calls `ObjMinIndex()`, which just returns the first enumerated key. With the integer-key ordering in AHK v2, that is `0`; it then falls through to public even when `PublicFallback = 0`. This occurs when the current private candidate is missing or the attempt number exceeds the private-candidate range. [main:1902](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L1902), [main:17655](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L17655).

The ordering is supported by the [AHK Map implementation](https://github.com/AutoHotkey/AutoHotkey/blob/v2.0/source/script_object.cpp#L2250), including its numeric-key lookup/insertion logic. Selection should not depend on incidental map enumeration anyway.

Build an ordered list containing only validated private candidates; append public only if permitted. Also omit malformed private links rather than retaining a map missing `type`/`code`. Test one private server, gaps among backups, malformed settings, and more than 20 failed outer attempts.

### F10 — P2: Vicious Bee retry, timeout, and field-selection logic are broken

- `SearchforVB()` increments `inactiveHoney`, then resets it to zero whenever it is below five. Starting at zero, repeated failures never reach the intended fifth-failure branch. [main:18457](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L18457).
- The overall timeout calls `VBEnd()` with a string, but that function accesses `.result` and `.reason`. [main:18348](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L18348), [main:18403](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L18403).
- `data.bees >= HiveBees` skips a field when the hive has exactly the required number of bees. For example, a 35-bee hive skips the entry requiring 35. [main:18343](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L18343).
- `static VBData` captures enable settings on its first call. Changes made while paused or by remote configuration will not update those copied values until the process is reloaded. [main:18282](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L18282).

Use consistent result objects, count consecutive failures until a genuine recovery resets them, use `requiredBees > HiveBees` for exclusion, and read enable flags at execution time. Exercise exact thresholds, repeated inactive-honey failures, timeout, death, successful kill, and a changed field selection in the same process.

### F11 — P2: Blender rotation decrements the next recipe's count

After scheduling the current recipe, the code advances `BlenderRot` and calls the rotation selector, then decrements the counter at the new slot. [main:11875](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L11875). With two finite slots each set to one, starting slot 1 can exhaust slot 2's counter before slot 2 is crafted, while leaving slot 1's counter unchanged.

Keep the executed slot separately; confirm crafting, decrement that slot, and only then select the next recipe. Timers and rotation are currently persisted before the final Confirm click, which needs the same success check. Test finite/finite, finite/infinite, a single active slot, and rejected crafting.

### F12 — P2: Nectar priority sorting is alphabetical instead of numeric

Stage 2 builds percentage-prefixed records and calls `Sort(sortstring, "D;")`. That sorts as text: `100,...` can precede `80,...`, contrary to the stated lowest-to-highest policy. [main:20959](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L20959). The [Sort documentation](https://raw.githubusercontent.com/AutoHotkey/AutoHotkeyDocs/v2/docs/lib/Sort.htm) specifies numeric mode with `N`.

Use numeric sorting with a defined tie-breaker, preferably over structured candidate records. Test percentages spanning digit boundaries, fractions, ties, and projected nectar above 100.

### F13 — P2: Collection failures create full cooldowns

Several collection routines set their last-used timestamp after the retry loop regardless of whether interaction was detected. The Coconut Dispenser is a clear four-hour example. [main:12262](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L12262). The same pattern appears in other dispensers and seasonal routines; Memory Match also commits a cooldown on a failed attempt path. [main:12796](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L12796).

This avoids immediate repeated failures but represents failure as a successful collection. Separate `lastAttempt`, `lastSuccess`, and `retryAfter`. Use a short bounded backoff after failure; only assign the real cooldown after accepted interaction or observed in-game cooldown. Test two failed visits followed by a successful one.

### F14 — P2: Conversion exits leave accounting unfinished

`ConvertStartTime` is set before conversion. AFB, reconnect, inactive honey, and boost interruption paths return before elapsed time is recorded and the timer is cleared. [main:17135](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L17135), [main:17255](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L17255). Later statistics can include unrelated time, or a later conversion can overwrite the unfinished start time.

Put accounting and cleanup in a shared exit/finally path, using an explicit active conversion interval. Also distinguish timeout from successful backpack emptying: the five-minute loop can terminate with a nonempty backpack and still announce “Backpack Emptied.” [main:17139](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L17139).

Verify every interruption in both backpack and balloon phases, plus a full timeout with a nonempty bag.

### F15 — P2: Pause followed by stop double-counts runtime

Pausing adds elapsed runtime and gathering time to totals but leaves the associated start timestamps live. Stop accepts both running and paused `MacroState` values and adds elapsed time from those timestamps again. Resume also sets `GatherStartTime` regardless of which phase was paused. [main:22664](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22664), [main:22720](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22720), [main:22746](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22746).

Use one phase-accounting function that closes an interval exactly once and resumes only the phase that was active. Include conversion and paused time explicitly. A timeline test—run 60 seconds, pause 30, stop—must report 60 active seconds, not re-add the first interval or count the pause.

### F16 — P2: Reset waiting mixes seconds and milliseconds

Callers pass delays such as 20,000 milliseconds, but the remainder subtracts `nowUnix() - resetTime`, which is seconds, before dividing by 1,000. [main:11217](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L11217). If a reset has already taken 10 seconds of a requested 20-second minimum, the current calculation waits about another 19 seconds instead of 10.

Use a monotonic deadline with one unit for operation timing; keep UTC timestamps for persistent cooldowns. Test reset work that takes less than, equal to, and longer than the requested minimum.

### F17 — P2: Startup appends a second copy of the priority list

The priority array is built during initialization and appended to again on Start without being cleared. [main:2061](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L2061), [main:22377](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22377). The main loop executes every entry. [main:10566](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L10566). Thus one nominal cycle contains two copies of the schedule; repeated starts that fail preflight can append more. This does not necessarily double every collection, because many actions have their own cooldown guards, but it does duplicate dispatch and complicate priority behavior.

Rebuild the list from a validated permutation at a single point. Reject missing/duplicate priority entries; the remote regex currently permits eight repeated digits. [status:648](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L648). Verify ordinary startup, failed startup/retry, edited order, and invalid imported configuration.

### F18 — P2: Incorrect-settings startup handling unlocks controls but continues

When `nm_MsgBoxIncorrectRobloxSettings()` reports a problem, Start re-enables the Start button/hotkey and unlocks tabs, but does not return. Execution continues into startup with editable controls. [main:22396](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22396). The settings dialog's close handler also references misspelled `AFBGIncSettingsGuiui`. [main:2316](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L2316).

Have validation return an explicit outcome and keep normal startup stopped until it passes or a deliberate override is selected. Fix the dialog reference. Test invalid Roblox settings, closing the dialog, correcting settings, and starting once afterward.

### F19 — P2: Duplicate movement/reset calls add work and can break positioning

Manual planter screenshot and harvest paths contain nested `nm_Reset(nm_Reset(...))`, which executes two resets and passes the inner return value to the outer call. [main:21832](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L21832), [main:22137](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L22137).

Tunnel Bear executes `nm_gotoRamp()` before selecting a travel method, then calls the same function again in the Walk branch. AHK function names are case-insensitive; the capitalization difference does not make it a different function. [main:15178](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L15178). This repeats relative movement from a changed position.

Remove duplicate calls after establishing the intended route start position. Verify planter reset count and Tunnel Bear travel for both movement methods and several hive slots.

### F20 — P2: Unknown quest progress can be treated as complete

Quest readers initialize completion optimistically and recognize incomplete bars through a small set of pixel colors. Unknown rows do not reliably invalidate overall completion; later checks can infer completion simply because no actionable objective was produced. Black and Brown show this directly. [main:19625](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L19625), [main:19791](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L19791), [main:19837](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L19837), [main:20088](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L20088). Similar handling exists in the other quest readers.

An unreadable/partially scrolled quest can therefore produce completion/turn-in behavior rather than a recognition retry. Keep complete, incomplete, and unknown as separate states. Require a recognized quest/objective set and positive completion evidence. Test partial scrolling, delayed frames, changed colors, missing title matches, and every supported quest family.

### F21 — P2: Image-resource ownership has concrete defects

The snowflake hotbar path disposes `pBMArea` after reading the buff, then disposes it again when the buff is at its cap or indeterminate and execution falls through. [main:18680](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L18680). That passes an already-disposed native pointer back to GDI+; whether it crashes in a particular run needs Windows testing.

The auto-jelly mutation path creates a bitmap and HBITMAP without freeing those two resources after OCR, including repeated no-match iterations. [main:9531](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L9531). The OCR helper releases its stream, but that does not release the caller's original bitmap/HBITMAP. There is also a duplicate brush deletion in that utility's drawing routine. [main:9334](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L9334).

Adopt one owner and one cleanup path for each native resource. Exercise snowflake-at-cap, indeterminate detection, repeated mutation scans, and repeated GUI redraws while monitoring GDI objects and process memory.

### F22 — P2: Window geometry caches become stale after resizing

Inventory search caches its usable height only when the Roblox HWND changes. Resizing an existing window keeps that handle but changes the visible inventory region. Later captures reuse the old height. [inventory:3](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/lib/nm_InventorySearch.ahk#L3), [inventory:10](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/lib/nm_InventorySearch.ahk#L10), [inventory:52](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/lib/nm_InventorySearch.ahk#L52). Top-bar offset detection similarly caches by HWND. [roblox:44](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/lib/Roblox.ahk#L44).

Key cached geometry by handle, client size, and relevant display/UI state; invalidate on changes and failed detection. Use a common coordinate conversion layer. Test resize/maximize, monitor changes, and game UI layout changes without restarting the macro.

### F23 — P2: Discord payload construction and delivery are unreliable

Status text is escaped for backslashes/newlines but not double quotes, then inserted into manually assembled JSON. Ordinary quoted text can make the payload invalid. [status:711](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L711), [discord:11](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/lib/Discord.ahk#L11). The status queue removes an entry before calling send. [status:732](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/Status.ahk#L732). The hourly reporter also clears its sample buffers after sending without treating an HTTP error response as a retained report. [stats:1499](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/StatMonitor.ahk#L1499), [stats:1539](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/StatMonitor.ahk#L1539).

Build payload objects and use the existing JSON library consistently. Check response status, handle rate limits and transient errors with bounded retries, and retain failed reports locally. Avoid blocking all command/status processing behind a slow network request. Verify quotes, newlines, backslashes, HTTP 429/500, offline operation, and recovery.

### F24 — P2: Honey reporting selects the largest qualifying OCR value, not the strongest reading

Honey detection performs 25 × 2 OCR variants, then chooses the largest numeric candidate seen more than twice. A repeated high-valued misread can beat a much more frequent correct value. [stats:697](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/StatMonitor.ahk#L697), [stats:718](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/StatMonitor.ahk#L718).

Use agreement/confidence and plausible change bounds, not maximum value, to select a reading. Preserve uncertainty rather than turning it into a spike. Distinguish net honey balance from gross honey earned when spending occurs. Test recorded samples with extra digits, ambiguous glyphs, unchanged balance, and purchases.

### F25 — P2: The reconnect countdown uses a 12-hour clock in 24-hour arithmetic

PlanterTimers reads UTC hour with `"hh"` and combines it with hours modulo 24. [timers:302](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/PlanterTimers.ahk#L302). Afternoon/midnight values can produce the wrong next-reconnect countdown, particularly for intervals that do not mask a 12-hour difference. This finding concerns the displayed countdown; it does not by itself establish that the background reconnect scheduler fires at the wrong time.

Use `"HH"` or a shared next-occurrence calculation. Verify midnight, noon, 13:00–23:00 UTC, before/after the scheduled minute, and each allowed interval.

## Smaller defects and follow-up checks

| Priority | Item | Evidence / action |
|---|---|---|
| P3 | Autoclicker count enablement is reversed on mode change | Constructor disables count for infinite mode, but the change handler enables it for that mode. [main:8712](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L8712). Test switching both directions. |
| P3 | FPS utility uses the wrong UWP control prefix when applying | Controls are created as `UWP...`, but the writer uses `FPS...` for the non-Web branch. It also compares rather than assigns the cached FPS after writing. [main:10518](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L10518). Repair if retained; normal startup already rejects UWP, so prioritize supported Web Roblox. |
| P3 | Debug report has an incomplete DPI lookup | A fixed map covers selected scale values; another valid Windows scale can throw while building the diagnostic report. [main:10385](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L10385). Format arbitrary DPI values and show unsupported macro configurations without breaking diagnostics. |
| P2 follow-up | Honey number formatting needs a zero case | `FormatNumber()` calls `log(abs(n))` before testing magnitude. [stats:1569](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/StatMonitor.ahk#L1569). Add explicit zero handling and verify unchanged-session output. |
| P2 follow-up | Negative image-search errors are sometimes treated as a match | For example, Vicious Bee checks use raw truthiness. [main:18533](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L18533). Standardize wrappers so match / no match / capture or search error cannot be confused. |
| P2 follow-up | Automatic placement failures mutate the user's maximum planter setting | Search the placement-stage failure branches for `MaxAllowedPlanters`. Separate temporary unavailable capacity from the configured maximum; expose recovery rather than silently degrading capacity. [main:20935](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L20935). |
| P2 follow-up | Multi-process config writes lack one coherent state owner | Main, Status, and PlanterTimers update related values independently. The timer display itself repeatedly writes blender counts. [timers:250](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/PlanterTimers.ahk#L250). Introduce a single writer for action state and versioned snapshots for readers. |
| P3 | Configuration import can partially apply before reporting errors | Gather paste writes each accepted property while validating later properties. [main:4935](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/submacros/natro_macro.ahk#L4935). Parse and validate the entire proposed import, then apply atomically. |

“Follow-up” entries are code-backed concerns needing a focused runtime/ownership check before turning them into separate release-blocking tickets. They are not counted as additional fully reproduced failures.

## Optimization work worth doing

Performance changes should follow correctness fixes. There is no measured basis yet to promise a percentage improvement or to say AHK execution speed is the bottleneck.

1. **Reduce lost productive time first.** Fix duplicate resets/travel, false cooldowns, retry loops, and unnecessary interruptions. Measure time spent gathering, converting, traveling, recovering, and waiting separately. These are likely more valuable than making individual arithmetic expressions faster.
2. **Reuse captures within a detection pass.** Several features independently capture overlapping regions. Give detectors a shared frame/region when they need the same instant, and refresh only when the game can have changed. Never reuse a stale screenshot across an interaction that needs confirmation.
3. **Make polling rates explicit.** Some search loops continuously capture and search until a deadline. Use a suitable polling interval and bounded attempts; slower-changing menus and cooldowns do not need movement-loop cadence. Instrument capture count, detector time, and CPU use before tuning.
4. **Reduce OCR work when confidence is already sufficient.** Honey detection currently tries 50 variants per sample. Start with a calibrated subset and fall back to more attempts only when agreement is poor. Validate accuracy against saved images before reducing work.
5. **Replace INI polling with snapshots/change notifications.** PlanterTimers reads dozens of keys every second and writes derived blender counts. Load configuration once, update on messages, refresh the display from memory, and persist only meaningful state changes. Preserve crash recovery with explicit checkpoints.
6. **Keep network work from stalling status/control.** Use a bounded delivery queue with timeouts, backoff, and local retention. Separate report construction from sending so a failed upload does not stop useful monitoring.
7. **Measure worker startup before changing the movement architecture.** Each generated movement process has overhead, but isolation is useful. If measurements justify it, introduce a reusable worker with acknowledged commands and cancellation. Preserve custom path compatibility during the transition.
8. **Fix native-resource lifetime before using memory-trimming calls as an optimization.** Track GDI object counts, process handles, private memory, and growth over long runs. Low displayed working-set size alone is not evidence of lower resource cost.

## Architecture improvements that fit AHK

Split the main script incrementally by responsibility, keeping existing entry points compatible while moving one subsystem at a time:

- **Configuration:** one schema for defaults, validation, UI, remote settings, and migrations; typed values and atomic import.
- **Runtime state:** active phase, action identifier, cancellation state, timing intervals, and confirmed progress.
- **Game observation:** window geometry, screenshots, image detection, OCR, and confidence/error results.
- **Actions:** travel, interact, verify, retry/recover, commit outcome. A shared result contract replaces ambiguous `0`/`1`/empty/string returns.
- **Scheduling:** choose eligible work from cooldowns, user priorities, current location, and interruption cost. Keep policy separate from the routines that press keys.
- **Persistence and reporting:** a single owner writes action state; helpers receive updates. Reports observe events instead of reconstructing truth from unrelated global variables.
- **UI and utilities:** controls render configuration/state and request changes; they do not independently implement business rules.

Start with configuration, action results, and timing cleanup because they address the repeated defects. Simply splitting a 23,000-line file without changing these responsibilities would mostly relocate the problems.

## Features I would add or extend

### Highest value

**Explain the next action.** A compact panel showing “gathering Pine Tree; 3 minutes left; next planter harvest in 12 minutes; skipped Glue Dispenser because last attempt failed.” The program already tracks status and priorities; expose the decision and retry state clearly.

**Recover a run from uncertain state.** Extend the existing planter timer/editor and reconnect tools with reconciliation: “this planter may still exist,” “craft acceptance unknown,” “hive claim not confirmed.” Resume only after the relevant state is established. A process being alive is different from the macro making progress.

**Unified consumable budgets.** Share per-session and per-action limits across AFB, shrine, stickers, auto-jelly, and other consumable tools. Show remaining budget and the stop condition before running. Budget checks belong before every item action, with a defined response to an uncertain result.

**A support bundle that explains failures.** Extend the current debug log/report with redacted configuration, version, current action, recent exceptions, action outcomes, and optional game-only screenshots. Make it local first, with a clear preview before sharing. Exclude bot tokens, webhooks, private-server codes, and unrelated desktop content.

**A stronger setup check.** Build on existing Roblox configuration validation: detect window dimensions, scaling, expected UI anchors, hotbar assignments, movement calibration, and writable settings. Give actionable failures and remember what passed.

### After stabilization

**Named profiles with complete import/export.** Extend the existing field defaults and gather clipboard exchange to whole configurations: questing, nectar maintenance, boosted gathering, and resource-saving sessions. Validate an import as a unit and explain differences before applying it.

**Recorded-image regression tools.** Save representative game regions and run the real detection functions against them on Windows. A developer should be able to see why a quest row, planter prompt, or buff was classified a certain way without replaying a multi-hour session.

**A route test dashboard.** Extend the existing path/pattern tester with destination checks, duration, retries, screenshots, and results by hive slot/movement mode. This makes maintaining the 91 paths manageable across contributors.

**Scheduling that considers travel cost.** Once success/cooldown data is trustworthy, group nearby eligible tasks and protect short-lived boosts from low-value interruptions. Keep manual priorities available and make decisions explainable.

**Release channels and rollback.** A stable channel, opt-in testing channel, compatibility notes for game/bitmap changes, and retained previous installation would make regressions much easier to recover from.

I would defer adding more bosses, quest types, or automatic spending features until existing actions can reliably establish success, failure, and cancellation. New content should then use those shared mechanisms.

## Recovery sequence and release gates

### Batch 1 — Contain the highest-impact failures

Fix F01–F08, private-server fallback, and startup gating. Add focused exception records and explicit failure results in the changed paths. Preserve user settings and custom paths/patterns. Gate: failed reconnect/update/harvest cannot affect unrelated content, lose stored state, or continue item use beyond the configured policy.

### Batch 2 — Restore feature correctness

Fix Vicious Bee, Blender, nectar sorting, collection cooldowns, duplicate calls, conversion/pause accounting, and native-resource cleanup. Gate: deterministic tests cover the decisions and state transitions; Windows scenarios cover actual input and detection.

### Batch 3 — Establish a repeatable Windows verification loop

The only workflow in this checkout is a PR-to-Discord notification workflow; there is no automated runtime/regression pipeline. [workflow:1](https://github.com/NatroTeam/NatroMacroDev/blob/66648fd6a290d472dacc45e9407e4c0ca4fa744a/.github/workflows/pr_to_discord_ninju.yml#L1). Add a pinned AHK runtime and an automation-disabled test entry point so pure logic can be tested without starting the macro. Validate generated worker scripts as well as ordinary includes. Pin third-party CI actions to reviewed revisions.

Use Windows CI for pure AHK tests, packaging/migration checks, and saved-image detection tests where supported. Use a Windows machine running Roblox for movement, input focus, real UI, and long-session tests. Keeping AHK does not prevent automated logic testing; it does mean live game validation needs Windows.

### Batch 4 — Refactor and measure

Extract the shared configuration/state/detection/action pieces one at a time. Keep public function names and the custom path/pattern contract stable during the migration. Record baseline timings, retry counts, resource use, and productive-time ratios; accept performance changes only when they preserve correctness and improve those measurements.

### Minimum Windows scenario matrix

| Scenario | Required result |
|---|---|
| Fresh settings and migrated settings | Valid defaults; explicit rejection of invalid values; old data recoverable. |
| Gather → convert → gather, each return mode | Correct destination, released inputs, nonoverlapping time accounting. |
| Pause/resume/stop during travel, gather, convert, boss, and item use | No stuck inputs, duplicate accounting, or consumable actions after cancellation. |
| Missing window, disconnect, crash, bad private link, exhausted fallbacks | Bounded retries; correct server policy; no unrelated window closure or desktop capture. |
| Delayed/absent interaction prompts | No false success, full cooldown, rotation advance, or erased planter. |
| AFB at zero/one/exhausted limits and hour cap | Hard limits applied immediately, including changes in the same process. |
| Every planter mode and finite/infinite crafting rotation | Confirmed operations match stored state and counters. |
| Every quest reader with complete/incomplete/unknown rows | Unknown results cause retry/reconciliation, never assumed completion. |
| Every boss/route at relevant hive slots and bee thresholds | Arrival and outcome independently confirmed; timeout and death recover cleanly. |
| Window resizing and supported display configurations | Coordinates recomputed; invalid captures fail explicitly. |
| Discord unavailable/rate-limited and unauthorized commands | Local monitoring continues; delivery recovers; unauthorized commands do nothing. |
| Several-hour mixed run, followed by an overnight candidate run | No progressive memory/GDI growth, lost planter records, unexplained retry loops, or inaccurate totals. |

## What still needs live validation

The current match quality of every bitmap, actual route endpoints, game-specific cooldown assumptions, boss health detection, Memory Match animations/rewards, sticker/shrine menus, OCR accuracy, and movement timing at different FPS cannot be established by static inspection. These are the next verification targets, not claims that each is broken.

The practical objective is a macro that can explain what it attempted, establish what actually happened, and recover without inventing success. This codebase already contains enough capability to build that in AHK.
