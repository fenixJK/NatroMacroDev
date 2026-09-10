# Auto-Jelly run limits

Auto-Jelly now has finite, user-visible limits for click attempts and elapsed
minutes. The default is **100 attempts or 10 minutes**, stopping when either is
reached. Existing settings files receive these defaults in memory without being
rewritten on load. A Limits row in the main window opens a native editor with
inline validation, Save and Cancel. The two fields accept integers from 1 to
1,000,000 attempts and 1 to 1,440 minutes; zero does not disable protection.

These limits count macro click attempts, **not royal jellies spent**. One click
can trigger the game's own auto-jelly behavior and consume multiple items. The
editor explains this distinction. This is not an inventory budget or a receipt
proving the game accepted a roll.

The run snapshots validated limits after checking bee selections, before OCR
preflight. One monotonic deadline covers the rest of that run, including image
waits, OCR polling and time spent at match dialogs. Declining a match does not
restart the budget. The input surface checks time during normal input/capture
validation; OCR uses that same surface check. Exhaustion raises a normal run-stop
error and follows existing input release, OCR cleanup and GUI restoration.

The click cap is checked before pointer movement and again immediately before
mouse-down. An attempt is reserved before sending input and is never refunded
after an uncertain send. The final permitted click may still be observed while
time remains; exhausting the attempt count prevents another click rather than
discarding that last result. A new user-started run gets a fresh budget.

Both limit values are validated before a single INI section write. Only a
successful write publishes the new GUI values. Saves replace the dedicated
`limits` section and preserve other sections. That write is not a crash-atomic
or multiprocess transaction. These fields extend the configuration schema from
48 to 50 fields and cannot pass through the boolean toggle writer.

## Verification contract

Regression tests cover default migration, invalid/duplicate fields, finite upper
bounds, save/reload, unrelated settings preservation, validation before writing,
failed-write publication, exact attempt/time boundaries and a deadline crossing
the 32-bit tick boundary. Observing after the final reserved attempt remains valid
until the time deadline.

Native input fixtures send one budgeted click to a disposable button, reject a
second attempt, allow capture of the last result, and reject capture/wait after
the shared deadline. They check that no additional click or held mouse input
remains. The generated GUI fixture checks that the Limits row does not overlap
existing controls, invalid edits preserve the file/UI, saving updates both stored
and displayed values, reopening restores them, and Cancel discards edits and
re-enables the owner window. The sandbox settings are restored for the existing
GUI lifecycle checks afterward.

## Verified checkpoint

Code `ec98d3bf2a28fb038ad98fddc32e04ae773add9b` passed
[Windows run 34464663269](https://github.com/fenixJK/NatroMacroDev/actions/runs/34464663269).
Both AHK architectures passed **67 regression groups**, native GUI/input/process
suites, nine production-script validations, four test-entry validations and seven
emitted-worker validations. The generated GUI completed the limits-editor checks,
and the native input suite completed the attempt/time enforcement checks. Existing
mouse behavior and actual English OCR recognition/failure recovery also passed.
PowerShell 5.1 and 7 each passed eight file-channel checks, 43 attachment checks
and 35 updater scenarios. There were no AHK warnings; the checkout action's Node
runtime deprecation notice remains.

The first run caught an unassigned loop value in a test callback. Values are now
bound explicitly. Exhaustion tests also require the dedicated limit-reached
exception rather than accepting an unrelated failure. No thresholds were relaxed.

## Limits of this checkpoint

Elapsed-time enforcement is cooperative and uses the Windows monotonic clock.
It cannot interrupt a synchronous native call that stops returning or automatically
dismiss a user decision dialog. It stops further input when control returns; its
polling intervals are not hard real-time guarantees. The attempt cap does not
limit item consumption performed inside one game action.

No Windows/Roblox machine is available. Exact item accounting, positive roll
receipts, live mutation accuracy, animation freshness and real-game stop/resume
behavior remain unverified. These guards do not establish full production readiness.
