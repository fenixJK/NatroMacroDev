# Auto-Jelly input and observation guards

The rolling loop previously treated negative image-search errors as matches,
continued after GUI-offset detection failed, reactivated Roblox on every click,
and reused coordinates across window changes. Early returns could leave its
Escape hotkey enabled. Screenshot/effect cleanup depended on which branch ran.

The run now has one finally path that releases owned mouse input, disables the
Escape hook, restores the GUI and clears its running guard. A second start cannot
reset an active run's cancellation flag. Preflight requires selected bees, and
mutation filtering additionally requires a selected mutation and an available
English OCR language. Bee-only runs do not initialize OCR. The unused per-run
activation-factory probe was removed. The chosen language is passed to OCR rather
than being ignored. Offset failure stops before rolling.

The input surface retains the client HWND and the geometry used for offset
observation. Before input and capture it verifies focus and matching current
geometry. Click and capture regions must fit inside that client. Mouse input is
released in finally, and the caller's mouse coordinate mode is restored. The
800 ms result wait checks cancellation and geometry every 25 ms. The loop does
not reactivate Roblox after an unrelated focus change. A user declining the
macro's own match dialog explicitly resumes the same client; geometry is checked
again before the next click.

Bee identification separates native search errors, valid no-match and matches.
A missing or ambiguous bee result stops rolling. Multiple variants of the same
bee can identify it as gifted; different identified bees are ambiguous. Mythic,
gifted and selected-bee decisions use the resulting identity. Bee captures and
mutation captures/effects/HBITMAPs have finally-based cleanup. Empty mutation OCR
text stops rolling instead of prompting another click.

## Verification contract

Regression fixtures cover search error handling, missing/ambiguous identities,
ordinary/gifted/mythic selection and English language selection. Native input
fixtures check one real click, mouse-up and coordinate restoration, expected
capture dimensions, and rejection after cancellation, focus loss, movement or
an out-of-bounds offset. A timer cancels the real wait; a native invalid-bitmap
search must fail explicitly.

The generated Auto-Jelly GUI probe renders each of its 68 bundled bee templates
into a disposable capture and checks identification against the entire template
set. This checks template distinction and ordinary/gifted identity, not real-game
screenshots. It also rejects a no-bee startup twice through the actual run function,
dismisses the expected native dialogs, and checks GUI restoration/retry. A positive
Escape-hook control precedes checks that Escape no longer invokes the stop handler
after each rejection. All windows/input belong to disposable Windows CI fixtures.

## Verified checkpoint

Code `33fa34d5a4c7efb2a5c714f87731f2b365dfb07a` passed
[Windows run 34461512517](https://github.com/fenixJK/NatroMacroDev/actions/runs/34461512517).
Both AHK architectures passed **65 regression groups**, native GUI/input/process
suites, nine production-script validations, four test-entry validations and seven
emitted-worker validations. The native GUI checks include the 68-template corpus
and both startup-rejection attempts. PowerShell 5.1 and 7 each passed eight
file-channel checks, 43 attachment checks and 35 updater scenarios.

The server measured the guarded Discord retry at **2.570507 seconds (32-bit)**
and **2.5659045 seconds (64-bit)**, exceeding its unchanged 2.5-second minimum.
Cross-architecture cooldown publication and abandoned-mutex recovery also passed.
There were no AHK warnings; the checkout action's Node runtime deprecation notice
remains. No live game or production release is established by these checks.

## Remaining scope

The legacy WinRT OCR helper has been replaced by a scoped engine and bounded
polling; [OCR verification](auto-jelly-ocr-verification.md) records its later
checkpoint and native failure/recognition tests. Synchronous native calls still
cannot be preempted by the polling deadline. Click-attempt and elapsed-time limits
have since been added; [run-limit verification](auto-jelly-limits-verification.md)
records that checkpoint. There is no exact royal-jelly inventory budget, and an individual click may cause
the game's own auto-jelly setting to consume multiple items. The first click still
relies on the user's prepared game dialog; this is not visual confirmation of its
button or a receipt proving that exactly one roll occurred. Missing results stop
after the attempted click rather than retrying it.

Mutation trigger accuracy, nonempty but invalid OCR text, animation/stale-result
handling, overlay/occlusion detection, live GUI offsets and in-game stop/resume
behavior remain unverified. Hover and close waiting loops have since been replaced
with window-scoped tracking; [mouse verification](auto-jelly-mouse-verification.md)
records that checkpoint and its physical-input/display limits. Full-run error cleanup after actual game
operations has not been exercised in Roblox. There is no Windows/Roblox machine available;
CI evidence does not establish full Auto-Jelly or production readiness.

## Additional CI finding

The existing 64-bit TestLocalCooldown assertion failed intermittently during this
work. Added fixture diagnostics then measured **2.4972408 seconds** against a
required 2.5 seconds in run 34460904251. The shared retry deadline used a rounded
GetTickCount64 response timestamp without allowing for its coarse timer steps.
Native shared coordinators now add 32 ms to their published deadlines; deterministic
tests cover response phases across 10, 15.625 and 16 ms timer steps and saturation
including the allowance. The server's 2.5-second threshold remains unchanged.
See [reporting verification](reporting-verification.md#shared-queued-request-cooldowns)
for the timing contract and limitations.
