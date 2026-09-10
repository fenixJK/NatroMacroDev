# Upstream report tracking

Initial targeted review: 2026-09-10. The development repository
`NatroTeam/NatroMacroDev` disables issues; public reports are in
`NatroTeam/NatroMacro`. This table is an initial subset, not a completed backlog
audit. Similar symptoms do not establish a shared root cause or a resolved report.

| Report | Evidence read | Relationship to recovery work | Still needed |
|---|---|---|---|
| [1606: repeated resetting at hive](https://github.com/NatroTeam/NatroMacro/issues/1606) | v1.1.2 report body; no comments | Reset attempt/deadline bounds and fresh hive observation | Reproduce boost-to-hive transition and verify actual camera/template behavior |
| [1502: hive, inventory and cannon failures](https://github.com/NatroTeam/NatroMacro/issues/1502) | Report body and author's follow-up | Reconnect, menu/inventory and reset changes address relevant boundaries | Reproduce slot 6 and investigate shared detection/input cause; linked expired video was not reviewed |
| [1607: particular planters skipped](https://github.com/NatroTeam/NatroMacro/issues/1607) | v1.1.2 report body, pesticide/red clay versus tacky/blue clay | Guarded inventory search and preserved uncertain planter records | Record actual inventory images and distinguish asset mismatch, scroll behavior and placement outcome |
| [1571: gumdrops missed after planter scrolling](https://github.com/NatroTeam/NatroMacro/issues/1571) | Report body and described planter-to-dispenser sequence | Fresh inventory search and guarded Glue workflow | Reproduce starting near inventory bottom and verify the gumdrop is actually located/used |
| [1599: sprinkler inventory detection](https://github.com/NatroTeam/NatroMacro/issues/1599) | Title; body is empty | Relevant to inventory detection | Usable reproduction or recorded image evidence |
| [971: Bucko quest repeatedly returns to hive](https://github.com/NatroTeam/NatroMacro/issues/971) | Report body; historical quest screenshot previously measured | Quest completion/unknown classification | Verify current UI and quest planning; screenshot evidence does not prove report resolution |
| [966: inconsistent Planters+ timers](https://github.com/NatroTeam/NatroMacro/issues/966) | Report body: two-hour setting sometimes harvested after minutes; field-change behavior | Nectar scheduler removes inherited near-due timers and forced sipping/overfill harvests | Reproduce fixed-hour timing and gathering-field changes in the game |
| [1492: incorrect default planter time](https://github.com/NatroTeam/NatroMacro/issues/1492) | Report body: PoP Coconut/Stump and Petal Sunflower; glitter/full growth | Relevant to the adaptive growth/yield model; existing table has not been recalibrated | Actual field/growth/glitter observations and revised estimates |

No upstream report in this table is marked resolved. Subsequent work should extend
the table with open/closed reports and proposed fixes, check whether upstream has
already changed the relevant code, and map each claimed resolution to a concrete
reproduction and verification result.
