# Blender recovery verification

Blender accounting is separated from game interaction. A recipe count is charged
only after the running-craft image is detected. The executed slot stays separate
from the next selected slot, and its estimated finish time uses the recorded start
time. The final finite batch remains scheduled until it is collected.

The macro records an input attempt before Confirm. A delayed running/finished
observation can reconcile that attempt only in the same macro process, for the
same visible recipe, within the expected time window, and while its configuration
still matches. Failed or unrelated observations do not charge the recipe.

An accepted accounting update is written as compact JSON in `PendingCommit` before
its individual INI fields change. Those fields contain absolute values so replay
can finish an interrupted update without decrementing again. This protects against
interrupted writes; it does not make concurrent reads/writes by all helper processes
atomic. General state-writer consolidation remains part of the recovery plan.

Unavailable ingredients preserve the recipe and its repeat count, and defer that
slot for five minutes. Other eligible recipes can still be selected. Failed recipe
searches no longer fabricate a full-duration craft timer. Rejected/unconfirmed
starts leave the existing counters and timers unchanged and receive a short retry
delay. Clicks verify the same Roblox window, focus and geometry.

## Automated evidence

`TestBlenderAccounting` exercises the production planner, commit and rotation code,
using temporary INI files and fake GUI text controls. Coverage includes finite/finite,
finite/infinite, single active recipe, rejected crafting, invalid quantities,
configuration edits during an attempt, interruption partway through persistence,
idempotent replay, delayed running/finished confirmation, final-batch collection
scheduling and temporary ingredient shortages. Both bundled AHK architectures run
this suite. Main/helper scripts are also parsed by their actual Windows runtimes.

## Live gates still open

A Windows/Roblox machine is not currently available. The following require actual
game evidence; CI callback values do not prove these observations:

- Confirm that `EndCraftR` represents an accepted new craft and cannot be confused
  with the confirmation overlay or a previous craft underneath it.
- Verify the requested quantity is accepted in full, including insufficient
  ingredients, rapid increment clicks and high latency. Timers still estimate from
  the requested quantity rather than an independently read quantity.
- Verify the completed-craft collection transition: both end buttons disappear and
  the recipe card is visible again. Check whether collection changes the selected
  recipe card; recognition must accommodate actual game behavior.
- Exercise the existing explicit End/Ready action, cancellation overlay, collection
  of a final finite batch, and starting the next recipe.
- Interrupt at each input/observation boundary, change focus or resize, and verify
  that no click lands outside Roblox and no unconfirmed action changes accounting.
- Restart after an unconfirmed input. The saved attempt is retained, but a new
  process cannot assume it belongs to a currently visible craft. A supported user
  reconciliation flow for this case remains to be completed; inspect the actual
  game and saved recipe counts rather than treating that input as confirmed.

The existing preparation path still needs fresh observations after closing a
cancellation overlay or requesting End. Live confirmation fixtures and an explicit
reconciliation UI remain required before declaring Blender production-verified.
