# Reconnect recovery

Recovery now attempts one circuit of eligible servers, with five actual launches
per server. Empty or invalid slots are skipped. Public fallback is used only when
permitted by the existing policy; a completely empty private-server configuration
still means public-only operation. There are at most 25 launches with all four
private slots and public fallback enabled, or five in public-only mode.

A recovery has a 30-minute monotonic budget. Each attempt waits up to four minutes
for a window, three minutes for recognizable game/loading imagery, and three
minutes after loading first appears. Repeated unknown/loading frames do not reset
these deadlines. Two seconds separate failed attempts. The total budget may end
before every configured server receives all five attempts. A scheduled reconnect
delay precedes this budget. The existing local Stop command can still interrupt
recovery; elapsed pause time consumes the budget.

The existing loaded-game (`science`) template must match. Disappearance of the
loading template is inconclusive. Disconnect imagery takes precedence over loaded
imagery. All three searches share one owned frame of the focused Roblox client,
with focus and geometry checked again before accepting it. Failed native searches
throw rather than become successful observations. Current-game template accuracy
still requires live verification.

Hive claiming shares the overall deadline. Its sleeps and worker waits are
clipped, and it checks the budget before new walking work. Exiting the claim
routine releases the interaction key and stops its walk worker. Completion and
legacy timer adjustments occur only after the claim routine accepts a hive (or
an explicit connection-only check). Failed claims no longer repeatedly extend
planter/gingerbread times by the entire recovery duration. The existing claim
routine still infers acceptance from its prompt/input sequence; a positive
post-input hive receipt remains open. Related INI writes are not a crash-atomic
transaction.

Exhaustion records a local error and uses the main program's stop/exit cleanup;
it cannot return a normal success code to the interrupted activity. Restart is
explicit after checking the game and server configuration.

## Verification and limits

Clock-controlled tests exercise finite candidate ordering, private-only and
public-only policy, missing windows, unknown frames, disappearing loading images,
disconnects during loading, successful loading, late callbacks, stage/total
deadlines and native search result classification. They do not launch Roblox,
open a browser, enter private servers or execute live hive routes.

The deadline is cooperative. It cannot interrupt a Windows/COM call that never
returns; legacy browser launch, WMI process cleanup and other native calls still
need isolation/ownership work for a hard wall-clock guarantee. Hive image/input
focus across the whole route and a reliable positive claim receipt remain open.
Required live scenarios include browser/deeplink joins, Roblox updates, bad links,
all fallback combinations, disconnects in every stage, slow loading, an occupied
hive, pause/stop during loading or walking, and recovery exhaustion. No live game
scenario has been marked passed.
