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
