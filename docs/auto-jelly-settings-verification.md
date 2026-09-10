# Auto-Jelly settings validation

Auto-Jelly previously treated every `key=value` line in mutations.ini as a dynamic
global assignment, regardless of section. Unknown keys could overwrite internal
variables, and malformed selection values could become truthy strings. Startup
then rewrote the complete file. Checkbox handlers also changed memory before
IniWrite succeeded, leaving the GUI and disk disagreeing after a failed save.

`nm_AutoJellySettings` now defines 48 allowed fields in their expected sections.
It constructs a complete validated map before the GUI publishes any settings.
Unknown keys and keys in unrelated sections are ignored. Names and sections are
case insensitive, and surrounding spaces/tabs are accepted. Selection values must
be 0 or 1; positions must be decimal integers between -32768 and 32767. Missing
selections default to disabled, and missing positions use the caller's center.
Duplicate known keys, missing/invalid values and malformed section headers fail
loading. Files and parsed text are bounded to 64 KiB/65536 characters respectively.

Startup does not rewrite mutations.ini or create a missing settings file. It
creates the settings directory for subsequent user saves. On load failure the
worker reports the error and exits with code 1, which the existing parent worker
reaper can report. Validation errors name only the fixed schema field, not the
supplied value. The original file remains available for correction. No game action
or GUI construction follows a rejected configuration.

Checkbox handlers compute and validate a new value, persist it under its canonical
section/key, and then publish it to the legacy GUI variable. An unsuccessful write
leaves that variable unchanged. Unknown/internal fields and position fields cannot
be used as checkbox toggles. Position persistence on normal close is unchanged.

## Verification scope

Regression fixtures cover defaults, section and case handling, valid selections,
unknown internal-looking keys, duplicates, missing/invalid values, numeric bounds,
size limits, file preservation, successful toggles and failed-write state retention.
The native generated-GUI fixture opens Auto-Jelly with unknown `resources` and `w`
keys plus a selection in the wrong section. It verifies valid choices, unaffected
internal resources and unchanged input file before exercising redraw and cleanup.
A second real worker receives an invalid known selection and must return the
expected field-only error, exit with code 1 and leave the rejected file unchanged.

## Verified checkpoint

Code `00aff7f975ed0299134397ce178216db3560b840` passed
[Windows run 34457713047](https://github.com/fenixJK/NatroMacroDev/actions/runs/34457713047).
Both AHK architectures passed 63 regression groups, the native process and GUI
suites, nine production-script validations, four test-entry validations and seven
emitted-worker validations. PowerShell 5.1 and 7 each passed eight file-channel
checks, 43 attachment checks and 35 updater scenarios. No AHK warnings occurred;
the checkout action's Node runtime deprecation notice remains. The first run
caught incorrect class-method binding in the new assertion callbacks; those
callbacks were fixed before this passing run.

## Remaining limits

This is validation and save-before-publication, not a crash-atomic settings store
or multiprocess transaction. Writes still use IniWrite. Missing settings retain the
previous default choices; user edits require reopening the window. Runtime failures
are handled by the existing error logger, and main's worker failure reporting is
separate from a dedicated settings-repair interface. These checks do not validate
Auto-Jelly's OCR result recognition, consumption budgets, in-game stop behavior,
monitor placement, or all COM/image lifetimes. No Windows/Roblox machine is
available for live testing.
