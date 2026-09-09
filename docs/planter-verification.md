# Planter recovery verification

Code and CI can verify retry policy, persistence and the bitmap reader. The
following game scenarios are still required before the planter changes are
release-ready. A Windows/Roblox test machine is not currently available.

Use a separate copy of the macro and record its commit, AHK architecture, Windows
version, Roblox client, resolution, display scaling, planter mode and field.
Keep a copy of `settings/nm_config.ini` before and after each scenario. Record
whether the game action happened separately from what the macro reported.

| Scenario | Required observation and result |
| --- | --- |
| Five failed auto-harvest attempts | Name, field, nectar, harvest time and configured maximum remain unchanged. A retry marker is written. No further harvest input occurs for five minutes; a retry is allowed at expiry. |
| Failed manual harvest | The same record preservation and retry delay apply; the manual cycle does not advance because of the failure. |
| Interrupted harvest | Stop or close during an attempt. After restarting, the recovery delay remains and the planter record still identifies the same planter. |
| Reconciled or replaced slot | A different planter/field in a slot must not inherit an unrelated delay. A newly placed planter clears the slot's old recovery marker. |
| Repeated placement failure | All automatic priority stages retain `MaxAllowedPlanters`. Placement resumes after the temporary delay. |
| Three-planter capacity message | Automatic and manual placement stop retrying during the delay. Existing records and the configured limit are retained. |
| Paper/Ticket inventory icon while planted | Inventory presence alone must not clear the field record or advance a manual cycle. |
| Reusable planter returned to inventory | Verify the inventory image differentiates an available reusable planter from an unavailable/planted one before accepting it as reconciliation evidence. |
| Early harvest with Yes/No dialog | Capture before E, the dialog, immediately after acceptance, and the settled scene. Identify a positive completion signal before changing records or collection counts. |
| Full-grown harvest without a dialog | Capture the same sequence. Find a completion signal that also works for stacked/consumable planters; absence of an E button or progress bar alone is insufficient. |
| Harvest cancellation/full-grown-only policy | Declining an early harvest preserves the record and updates its growth estimate only from valid observations. |
| Lag, disconnect, death, focus loss or resize during harvest | These must produce an unconfirmed outcome, preserve identity/counters/cycle, and allow later reconciliation. |
| Progress bar detection | Compare reported proportions with the game at several growth levels, camera angles and fields, including an obstructed/missing bar and unrelated green UI content. |

The harvest functions still need a shared post-action confirmation and state-commit
boundary. Their current success return values are not yet authoritative evidence
that a harvest happened. The retry wrapper only contains reported failures.
Synthetic bar tests establish behavior for controlled images, not recognition
accuracy in Roblox. Do not mark these scenarios passed from CI results alone.
