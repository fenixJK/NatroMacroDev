# Quest observation and action verification

Quest completion now has explicit observed states: complete (`1`), incomplete (`0`)
and unknown (`-1`). A missing title, failed title-gap search, clipped objective set,
unrecognized objective or unreadable row cannot establish completion. The previous
inference from having no actionable objective has been removed. Action availability
and cooldowns do not make an incomplete quest complete.

Honey, Polar, Riley, Bucko, Black and Brown readers start unknown. The four named
quest tables require a current recognized title and visible expected rows. The new
observation helper captures the title and objective rows together, checks the title
again, requires row-border anchors and samples a small background patch per row.
The capture is rejected when client geometry/focus changes or its rectangle would
leave the visible client. Templates and the capture are released through `finally`.

Only `0x96D88D` is accepted as the completed background. The existing partial-progress
colors `0xF46C55` and `0x6EFF60` remain incomplete. Other colors, including borders,
title backgrounds, text and arbitrary overlays, remain unknown. Seven of nine
sampled pixels must support a row classification. An unknown row makes the aggregate
unknown even if other rows are positively complete or incomplete.

The completion color was measured from the 2560×1440 gameplay screenshot in
[upstream issue 971](https://github.com/NatroTeam/NatroMacro/issues/971), opened
April 4, 2025. The screenshot visibly labels completed rows as “Complete!”; their
dominant background is `0x96D88D`. The Brown Pine Tree row at rectangle
`(16,572)-(304,610)` and the blue-pollen row at `(16,722)-(304,758)` both use that
color. Incomplete/partial rows use the two colors already present in this codebase.
This is historical image evidence, not verification of the current game's UI on all
supported displays. The screenshot is not redistributed in the repository.

Brown's dynamic reader now contributes exactly one objective per physical row;
unrecognized text contributes an explicit unknown row. A list shorter than the
existing four-objective maximum requires a next-quest-title endpoint. That endpoint
and the recognized objective text are checked again in the same final capture.

Unknown results replace stale completion text in the GUI/settings and clear that
reader's pending gather, kill, feed and related actions. Honey does not clear another
quest's gather plan. Gather polling does not label unknown results as a completed
step. Rotation can proceed to other quest families when a quest cannot be read.

The six action handlers live in `lib/QuestActions.ahk`, shared with regression tests.
They visit quest givers only for explicit completion. The five existing counted quest
families increment their counters only after observing incomplete progress following
the visit; unreadable post-visit results do not increment counters. Black/Brown's
hourly timestamps also advance only after that observed transition. Honey now
re-reads after a visit before announcing that the next Honey Hunt started; its
existing exclusion from the quest completion counters is preserved.

## Evidence and remaining gates

[Windows run 34419566125](https://github.com/fenixJK/NatroMacroDev/actions/runs/34419566125)
verified code `6ee9de2f048e66134f61d7a004fdb86590cb83d0`: 32 regression groups on each
bundled architecture, native window/pointer checks, six script validations, four
emitted worker validations and 35 updater scenarios on each PowerShell version.
AHK warnings are failures; none occurred in the verified run.

Quest tests cover explicit colors, empty/missing/partial/unknown objective sets,
real GDI title/row matching, missing borders, clipped frames, dynamic endpoint
requirements, locked-bitmap errors, all six actual action consumers, unknown results
after visits, counters/cooldowns, and unknown GUI/state publication.

F20 remains open for these checks and improvements:

- Run every supported quest family against current recorded game screenshots and
  live complete/incomplete/unknown transitions, including font sizes and DPI changes.
  Synthetic GDI fixtures do not prove the bundled title images match current UI.
- Replace legacy initial scanning, fixed 150-pixel scroll assumptions and duplicated
  capture/input loops with observation-driven scrolling. These paths still have
  geometry, interruption, resource-cleanup and long-log limitations. A bad alignment
  now becomes unknown instead of successful completion, but may still prevent work.
- Establish explicit initial quest acquisition/reconciliation. A missing quest title
  no longer causes an assumed-complete visit, so a user without an active supported
  quest needs a positively justified acquisition path rather than that old fallback.
- Add bounded, persisted retry handling for unconfirmed turn-ins and unknown scans.
  With the false hourly-success timestamp removed, failed Black/Brown visits must
  receive their own retry delay without being recorded as completed quests.
- Verify game acceptance after interaction, delayed quest refresh and repeat quests
  with the same title. A complete-to-incomplete observation is stronger evidence but
  is not a transactional reward receipt or a unique game quest identifier.
- Reconcile dynamic Brown endpoints at the end of the log, unsupported objectives,
  duplicate/fuzzy title matches and future changes to the four-objective assumption.
- Finish planner separation so cooldown-only work, generic pollen objectives and
  multiple enabled quest families have explicit scheduling and retry reasons.

No live Roblox verification or complete quest-system rewrite is claimed.
