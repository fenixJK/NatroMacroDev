# Gather profile copy and paste

Gather profiles retain the existing flat JSON property names. New copies add
`schemaVersion: 1`; older profiles without this property remain supported.
Multiline JSON is accepted. Field and pattern names must match available choices;
enumerated values are normalized to their displayed spelling. Numeric strings
used by older profiles remain accepted when they contain a valid integer.
JSON booleans are accepted only for boolean flags.

The parser rejects unsupported versions, nested values, unknown/duplicate
properties, missing patterns, invalid fields and out-of-range values before any
state changes. Empty profiles, comments, trailing commas/text and excessively
large input are rejected. Partial profiles are supported: unspecified settings
remain unchanged. `None` is not an importable field; use the existing field
selection control to disable optional slots.

Pasting requires a stopped macro. After validation, the main process briefly
prevents its own event handlers from interrupting the commit, acquires the shared
Gather settings lock, reads the current Gather section and applies the patch.
It writes that section with one Windows profile API call. Other Gather keys and
other INI sections are retained. Status's remote Gather writes use the same lock,
preventing them from being lost between the section read and write. The lock is
an OS-owned file handle and is released on process termination.

[Microsoft documents section writes as atomic with respect to profile-file access](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-writeprivateprofilesectiona).
This is not a power-loss transaction guarantee or a replacement for the planned
single-writer/versioned-state architecture. Uncoordinated external editors can
still race a read-modify-write. Multiple separate legacy key reads are not a
coherent section snapshot. Existing comments inside the Gather section may be
reassociated or removed by the profile API; configuration values are retained.

Successful persistence precedes publication to globals and GUI controls. Pattern
size and backpack-percentage spinners are updated with their labels. Importing a
field does not invoke its default-setting handler, so explicit imported pattern
choices survive. Importing slot one also selects it in the same section write;
changing the currently selected slot updates its field display. Delayed remote
numeric notifications read current persisted Gather values, and a redundant field
name notification cannot reset an already imported profile to defaults.

Validation and persistence failures are reported locally. A subsequent unexpected
GUI publication failure can leave the saved profile newer than the visible UI;
the message directs the user to restart and reload the saved settings. Raw process
termination/power-loss recovery and complete helper-state synchronization remain
part of broader state work. Imports do not modify field-default presets, download
patterns, execute arbitrary clipboard code or change other feature configuration.

## Verification

Regression coverage includes full/partial legacy profiles, multiline and escaped
JSON, canonical values, invalid late properties, duplicate names, unsupported
schema versions, limits, real INI write failure and preservation of unrelated
settings. An independent Windows writer checks lock exclusion. An independent
section reader checks that repeated commits never expose half of a field/pattern
pair. Production copy/paste handlers are exercised with native dropdowns,
checkboxes, text/edit controls and spinners; the surrounding tab-enable routine
is a fixture. Full application layout, rapid live remote-edit/import interactions,
installed custom-pattern execution and crash/power-loss scenarios remain open.
