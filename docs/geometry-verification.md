# Window and inventory geometry

The shared client snapshot records HWND, root window, process, origin, client size,
DPI, monitor and window styles. Missing, hidden and minimized windows do not expose
usable capture geometry. Publishing a failed snapshot clears the legacy coordinate
globals. Explicit activation targets the requested HWND/root instead of an arbitrary
window whose title contains "Roblox", and can restore a minimized target.

Top-bar offsets are cached only against a matching snapshot and expire after two
seconds. Failed observations are not cached as successful zero offsets. Every
capture is released through `finally`; geometry/focus changes during observation
invalidate the result. The existing offset API still returns zero on failure and
sets its optional failure output. Call sites that ignore this output still require
review; this change does not make every coordinate consumer fail closed.

Inventory search re-reads its bottom boundary for every search. It captures against
a fixed snapshot and stops when that snapshot/focus becomes invalid. Every wheel
input checks ownership again, uses screen coordinates explicitly, then restores the
caller's mouse coordinate mode. Returned positions remain client-relative and now
include the observed top-bar offset. There is no extra scroll after the last search.
Capture and anchor errors are unknown observations; they do not become item matches.

The optional inventory outcome distinguishes `found`, `missing` (the permitted
readable search range was exhausted) and `unknown`. Unknown geometry/observation
does not add an automatic planter to the lost-planter list. This is not proof that
an item is absent from the entire inventory, nor proof of successful placement.

Search results also carry their observation context without changing the two-element
coordinate array. The shared drag controller re-reads the inventory boundary and
the same item at the same coordinate before pressing. It rejects unknown/missing
observations, changed window geometry/focus and out-of-client destinations. Input
completion is separate from confirmation that the game consumed an item.

Glue dispenser travel now ends before searching for gumdrops. The bitterberry and
basic-egg utilities retain the window snapshot used to select their destination bee
slot, reject changed geometry, and wait for the selection click to be released.
These three paths use an owned pointer operation with a distinct cancellation token.
Pause, stop, normal exit and failure cleanup release owned input; a suspended old
operation cannot release a newer operation's button. The native adapter installs
the mouse hook to distinguish physical input from its own synthetic button press.
It checks focus/geometry again for each move/press and restores mouse coordinate
mode and critical-thread state after each short input operation.

Ownership is currently per process, not coordinated across helpers or unrelated
input routines. Geometry checks and OS input cannot form one atomic operation with
external window changes. Bee dialog clicks/typing after the drag and other inventory
consumers still need migration and positive game confirmation. A release after
invalidation can still be interpreted by the game as a drop; it must not be recorded
as confirmed consumption or placement merely because cleanup completed.

Generated bee utility and walking sources now live in shared production builders.
CI evaluates those builders, then parses the two utilities and both walking modes
through root-working-directory stdin, matching their production launch mechanism.
Geometry/inventory library includes resolve beside their containing libraries,
rather than assuming every entry script is in `submacros`. This validation covers
emitted syntax/includes; it does not execute game automation or cover every other
generated worker in the main program.

## Verification scope and remaining gates

The regression fixtures cover cache identity/lifetime changes, offset-inclusive
positions, fresh inventory boundaries, interrupted scrolling, missing versus unknown
observations, bounded retries, small clients and real GDI anchor/item searches,
including a locked-bitmap error. A separate Windows fixture exercises real client
geometry, movement/resizing, explicit activation, minimization/restoration, hiding,
cleared globals and the missing-window offset failure flag. Results must be checked
in the recorded CI checkpoint; this document alone does not establish a pass.

Remaining F22 work and live checks:

- Revalidate item positions at every downstream drag/click, and convert remaining
  direct-input routines to the common window ownership/coordinate layer. Search
  completion cannot make a later input atomic with a moving window.
- Update consumers that ignore failed client/offset detection, including shared menu
  opening, gather/FDC, Blender and other custom capture/input paths.
- Verify actual Roblox top-bar and inventory anchors, red vignette recovery, item
  selection and scroll direction on current game UI assets.
- Exercise DPI changes and movement between differently scaled physical monitors,
  maximize/fullscreen transitions, multiple Roblox instances and child windows.
- Test geometry/focus changes during menu opening and after search but before
  consumable input; no wrong-window input or incorrect item use is acceptable.
- Measure capture/detection cost and CPU use before broadening caches or changing
  polling cadence. The fixtures do not establish a performance improvement.

Live Roblox verification remains unavailable and open. The larger recovery plan
and planter acceptance/reconciliation gates remain active.

## Menu navigation follow-up

Shared menu opening now uses an anchored foreground client, fresh frame checks,
a single guarded click and observed success/failure. It publishes verified client
geometry for legacy callers and shares cancellation/pointer ownership with
inventory drags. Inventory searches stop before reading or scrolling when the
menu cannot be confirmed. [Menu navigation verification](menu-navigation-verification.md)
records native input/geometry tests and the remaining occlusion, close-caller and
downstream gameplay limitations.
