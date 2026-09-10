# Nectar and automatic planter scheduling

This work follows the user's request to improve nectar build-up and maintenance.
It changes Planters+ selection and Auto timing. Manual cycles remain separate.
Live Roblox verification is unavailable; this is code and Windows CI evidence.

## Prior work reviewed

The user's [upstream Planters branch](https://github.com/NatroTeam/NatroMacroDev/tree/Planters)
was read through `e1c639f81071d1beee7399c7996fe65063015769`, including all seven
commits ahead of upstream main at review time. The work adopts its useful ideas:
nectar × growth bonus scoring, comparison across eligible fields, relative
`PlanterBuffer`, fresh projections after placement, and
`AdaptivePlanterGatherInterrupt`. The existing setting names are retained so
values saved by that branch can be reused. This is a selective implementation;
the branch's older input, recovery and accounting code was not merged wholesale.

Important differences from that branch:

- A pending harvest retains its expected amount as it matures. It is credited
  as an event at collection time, not scaled down by the time remaining or
  treated as continuous nectar already received.
- Harvesting all same-nectar planters merely because the bar is full is removed.
  Changing gathering fields also does not force an early harvest.
- Fixed hours and Full Grown remain available. A new planter never inherits an
  older planter's almost-expired timer. Other slots are not silently retimed.
- Failed harvests retain their records and retry backoff from the recovery work.
  An unavailable highest-priority field does not block other usable candidates.
- The gather interrupt consults the harvest retry reservation, avoiding repeated
  interruptions while the failed harvest is still deferred.

Reports inspected include [#966](https://github.com/NatroTeam/NatroMacro/issues/966)
(fixed two-hour planters harvested after minutes) and
[#1492](https://github.com/NatroTeam/NatroMacro/issues/1492)
(full-grown estimates for PoP/Petal and glitter). Removing timer synchronization
and forced sipping harvests addresses concrete early-harvest paths relevant to
#966. The growth table and glitter mechanics in #1492 have not been recalibrated.
Neither report is declared resolved without reproducing the game behavior.

## Decision model

`lib/NectarPlanner.ahk` is independent of the game and filesystem. Each decision:

1. Projects decay at one percentage point per 864 seconds, clips at zero, applies
   pending harvests in chronological order, and clips each harvest at 100%.
2. Ranks shortages projected two hours ahead, relative to the configured minimum,
   with modest priority weights. This prevents a distant efficiency gain from
   overriding a near-empty nectar bar.
3. Within a shortage rank, compares the reduction in squared shortfall over a
   24-hour horizon per occupied slot duration. A 30-minute amortization penalty
   discourages repeated trips; it is a tuning constant, not measured travel time.
4. Uses each table row's nectar bonus × growth bonus for modeled yield, matching
   the adaptive branch, and the row's full-growth duration as an upper bound.
5. For Auto, compares 2/4/6/8-hour batches and full growth where allowed by the
   current nectar's time to zero. Near-empty bars get short emergency batches;
   a minimum 30-minute batch avoids immediately planting and harvesting again.
   Short-lived planters can still finish sooner than the regular two-hour batch.
6. Uses the configured fixed interval (capped at full growth) or full-growth time
   unchanged when those modes are selected.

This is a greedy decision per free slot, not a globally optimal multi-day solver.
All allowed, unused planter types and fields are compared. An alternate usable
field is preferred over the last field for that nectar to retain field rotation;
this does not measure degradation or guarantee that a field has recovered.
Sipping can constrain a deficient nectar to the enabled gathering field. It does
not override disabled fields, exclusive planter types, or the three-slot limit.
Every successful placement changes the next candidate set and pending deliveries.

## Production integration and controls

`lib/AutomaticPlanters.ahk` contains the production selection, persistence and
interrupt adapter. It refreshes nectar observations after travel/placement and
caps a placement pass at ten attempts per empty slot. Field-capacity rejections
exclude that field for the pass. Inventory-confirmed missing types remain excluded;
other failures retain the recovery mechanism. No failure reduces Max Planters.

The Planters+ tab has a **Nectar settings...** button while stopped:

- **Reserve:** 0–20% of each minimum, default 10. A 70% minimum with a 10% reserve
  gives a 77% planning target. This is an upper reserve, not permission to dip
  below the user's minimum.
- **Interrupt gathering when a planter is due:** enabled by default for a new
  configuration; an existing saved 0 remains off. Boost protection is honored.
  It requests the normal gather exit and does not bypass pattern cleanup or the
  rest of the main scheduler. Therefore it does not promise immediate collection.

Existing planted records keep their timers until collected or explicitly edited.
New selections and timers take effect when a slot is replanted. Auto must be
selected to get adaptive harvest timing; fixed/full modes still get the improved
nectar and field/type selection.

The planner reports the selected nectar level, minimum, field, planter and planned
hours through the existing status mechanism. It does not claim a harvest receipt.

## Nectar observation

`NectarObservation` reads all five legacy colors and their 38-pixel bar heights
from one locked bitmap. Full bars always produce a defined value. The production
surface validates client bounds and foreground identity, disposes the capture,
and rejects changed geometry/focus or an observation older than one second.
Capture failure is not converted to an empty nectar bar.

The detector still interprets absent colors in a readable frame as zero. It is
not an OCR or occlusion-proof detector, and current game scaling/color/template
accuracy needs a recorded-image or live-game check. The fixed scan region requires
an 861-pixel-wide client and sufficient height. No speedup measurement is claimed.

## Validation

Final code: `df5cbec142e56b94cb06082944af2ea87f7c5c5c`.
[Windows CI 34541907259](https://github.com/fenixJK/NatroMacroDev/actions/runs/34541907259)
passed on its first attempt: 77 regression groups, zero failures on both bundled
AHK 2.0.12 architectures; all existing native Windows suites and generated-worker
validation also passed. Updater, attachment and file-channel suites passed on
Windows PowerShell 5.1 and PowerShell 7. There were no AHK warnings; the workflow's
existing checkout Node runtime deprecation notice remains.

Both architectures produced identical model results:

| Scenario | Lowest of all five bars during final day | Placements |
|---|---:|---:|
| 72 hours, starting at 80% | 80.90% | 94 |
| 168 hours, starting empty | 85.42% | 202 |

An earlier regression caught healthy-nectar efficiency outranking a near-empty
bar; shortage ranking and emergency timing were corrected before this checkpoint.
The final run includes those regressions and the production adapter fixture.
The new settings panel and actual game bar images still need live visual review.

The tests include exact decay/event/overflow calculations, urgent versus healthy
nectar choice, pending-delivery allocation, field/planter yield comparison,
fixed/full timing, growth-bonus contribution, invalid observations/settings, and
synthetic GDI+ full/half/absent nectar bars.

The real production adapter runs against controlled observation/input callbacks
and a temporary INI: three-slot allocation, unique types/fields, fresh reads,
saved/runtime timer consistency, failed/unknown/capacity paths, disabled fields,
field rotation, sipping constraints, zero capacity, due gathering interruption,
manual-mode exclusion, and retry-backoff behavior are exercised.

Two deterministic simulations exercise the same AHK planner with five
70% targets, three available slots, equal 2× yield, eight-hour full-growth capacity,
and five minutes of collection delay: 72 hours starting at 80%, and seven days
starting empty. They check all five bars stay above 70% in the final day and that
maintenance does not depend on continuous short harvesting.
Their interchangeable model slots do not represent a player's actual inventory or
field exclusivity; those constraints are checked separately by the adapter tests.
These are regression scenarios, not proof that every inventory can maintain five
nectars or a performance comparison with either older planner.

## Remaining limitations

The game can deliver different growth/yield due to degradation, sipping, glitter,
server delay, changed mechanics, and downtime. No actual growth measurement is
fed back into Auto yield estimates yet. Insufficient planter throughput cannot
maintain arbitrarily high targets across all five nectars. Actual early harvests,
loot/nectar receipt, uncertainty reconciliation and restart/offline timing still
need work. Existing placement/harvest success signals are retained and are not
positive proof of nectar received. Related INI fields are not crash-atomic.

The complete production recovery goal remains open; this change is not a release
or a statement of live readiness.
