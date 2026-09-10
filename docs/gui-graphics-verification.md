# Generated settings GUI graphics ownership

The Discord settings, task priority and Auto-Jelly windows now have separate
source templates under `lib/gui`. Main builds a short entry script through
`nm_GuiScripts`, which passes configuration as JSON inside an escaped AHK string.
Quotes, backticks, newlines and Unicode in settings therefore remain data when the
child script is parsed. The existing owned inline-worker roles launch the scripts.

`nm_GuiGraphics` owns one GDI+ startup token, a decoded asset map and a drawing
surface. `nm_LayeredSurface` owns the GDI+ Graphics, memory DC, selected DIB and
previous bitmap selection. Close deletes Graphics first, restores the previous
bitmap, deletes the DIB and deletes the DC. Successful releases clear their owner
fields; failures throw and retain outstanding resources. Asset aliases are
released once per pointer, before GDI+ shutdown. Repeated close is supported.

Each window registers its exit handler before asset loading and destroys its GUI
before releasing graphics. Discord's exit handler no longer calls the unrelated
planter-progress reader. Auto-Jelly retains its existing position persistence and
cursor restoration. Hard process termination can bypass these exit handlers;
this change addresses normal startup/close ownership, with kernel process cleanup
still providing the final boundary for forced termination.

## Verification contract

Windows CI validates seven emitted scripts, adding these three GUI entry points
to the four existing walk/consumable scripts. Native tests create and close 100
surfaces, assert successful release and cleared ownership, and require the process
GDI count to stay within one object of its warmed baseline. A shared bitmap alias
checks duplicate-release prevention and repeated owner close.

Native child probes open each real generated GUI, redraw it 50 times and require
GDI counts to stay within two objects of the initial rendered window. They call
the actual close handler twice and check that the owner has released its surface,
asset map and startup token. A dummy Discord value checks exact preservation of
Unicode, quotes, backticks and a newline. The probes use a temporary working
directory and perform no Roblox input or remote API calls.

An initial test incorrectly required `GetObjectType` to return zero immediately
after deletion. Windows CI showed successful deletion calls followed by nonzero
queries. Microsoft documents that cached GDI handles can remain queryable,
including through `GetObject`; those queries do not establish live ownership.
The test now checks release results, cleared ownership and repeated resource
counts instead. See [Microsoft's resource leak investigation](https://learn.microsoft.com/en-us/archive/msdn-magazine/2001/march/resource-leaks-detecting-locating-and-repairing-your-leaky-gdi-code).

## Verified checkpoint

Code `ca48cec25707e7a174988c3bb2d3a2f211e8bc58` passed
[Windows run 34457096449](https://github.com/fenixJK/NatroMacroDev/actions/runs/34457096449).
Both AHK architectures passed 62 regression groups, the native process and GUI
suites, nine production-script validations, four test-entry validations and seven
emitted-worker validations. The surface GDI count was 32 before and 33 after all
100 cycles on each architecture, within the one-object bound; this is not a claim
of zero total resource growth. All three generated GUI probes passed on both
architectures. PowerShell 5.1 and 7 each passed eight file-channel checks,
43 attachment checks and 35 updater scenarios. There were no AHK warnings; the
checkout action's Node runtime deprecation notice remains.

## Remaining scope

These are bounded native lifecycle checks, not a long-duration soak, pixel-level
visual comparison or confirmation of every settings interaction. The priority
probe runs while its introductory message is displayed; it does not exercise
reordering or cross-process persistence. Existing malformed Auto-Jelly INI input,
semantic priority validation, additional OCR/COM resource lifetimes, game actions,
consumable budgets, full main start/stop and live display/DPI behavior remain open.
No Windows/Roblox machine is currently available. No measured whole-program
performance improvement or production release is claimed.

## Auto-Jelly configuration follow-up

Malformed INI loading is now covered by a fixed schema and bounded reader.
Startup no longer rewrites the file, unknown keys cannot overwrite resource
ownership, and rejected known values exit before GUI construction. The native
GUI suite now checks both retained unknown keys and rejected selections. See
[Auto-Jelly settings verification](auto-jelly-settings-verification.md) for
Windows run 34457713047 and remaining persistence/game limits.

## Priority editor follow-up

The priority probe now exercises the actual save/reset functions and verifies
the drag coordinate mode before its redraw and cleanup checks. Saved order uses
a shared validated store, and the renderer no longer mutates the array before
persistence succeeds. [Priority settings verification](priority-settings-verification.md)
records Windows run 34458814651 and the remaining physical-input/live-game scope.

## Auto-Jelly rolling follow-up

The rolling loop now releases its temporary captures, mutation effects and
HBITMAPs in finally paths. Startup rejection restores the GUI, clears the running
guard and disables Escape, with two native rejection/retry checks. The GUI probe
also exercises all 68 bundled bee templates against the complete search set.
[Auto-Jelly run verification](auto-jelly-run-verification.md) records input and
observation guards and the remaining WinRT OCR, consumption and live-game limits.

## Auto-Jelly OCR ownership follow-up

The run now owns its OCR engine/factories, deletes created and returned HSTRINGs,
wraps each returned COM reference and closes its temporary streams/bitmaps on
unwinding. Async polling has one shared deadline and input/cancellation checks.
[OCR verification](auto-jelly-ocr-verification.md) records native COM cleanup
fault tests, actual English recognition and the remaining native-call/game limits.
