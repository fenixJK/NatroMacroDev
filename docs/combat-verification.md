# Combat observation verification

`lib/HealthObservation.ahk` replaces the shared health-bar scanner used by bug runs
and boss routines. Each bar has independent health/total-pixel counters. The
percentage includes the final pixel, so a one-green/one-red bar reports 50%, and a
healthy bar cannot inherit the preceding bar's damaged endpoint. Scans use actual
bitmap dimensions, including the narrower King Beetle image.

The reader masks detected bars in its own bitmap copy. Brushes, graphics and that
copy are released in `finally`, with graphics disposed before their backing bitmap.
Cached templates are released at main-process exit before GDI+ shutdown. The main
exit path now also releases the planter reader's cached templates.

The window wrapper requires a current focused Roblox client and checks the same
window geometry again after reading. Missing captures, allocation/search/pixel
failures, changed geometry and the detection limit throw an error. They do not
return a successful empty array. In production this reaches the existing failure
handler, which releases input, stops helpers, records the failure and exits. This
conservative behavior currently requires restarting after the problem is corrected;
a recoverable combat action boundary remains future work.

Automated fixtures exercise real GDI bitmaps: independent partial/full/zero-health
bars, a two-pixel edge case, untouched caller-owned images (including a locked
source), locked-template search errors, rebuilding cached resources, repeated scans
and the 100-bar limit. A separate Windows GUI fixture exercises actual full-client
and right-half screen capture and rejection of a hidden client. Synthetic
images do not establish that these colors uniquely identify current game enemies.

[Windows run 34420916584](https://github.com/fenixJK/NatroMacroDev/actions/runs/34420916584)
verified code `0c58935ede2bd3a8cc65cd9df70a2a506e3dec8f`: 35 regression groups on
each AHK architecture, native geometry/pointer/health capture, six script and four
emitted worker validations per architecture, and 35 updater scenarios on each
PowerShell version. No AHK warnings occurred.

`BossHealthEstimation.ahk` replaces the shared Snail/Commando estimator. Each fight
has a new observation session, and its first accepted sample establishes a fresh
baseline rather than treating saved/manual health as measured starting health.
Five captures are separated by 100 milliseconds. At least three must agree within
one percentage point of the median; frames with multiple damaged bars are ambiguous
and cannot vote. Full bars and zero-health bars do not identify a living target.

A measured rate requires at least 2.5 percentage points of damage and a positive
monotonic interval since the last committed observation. Failed/inconsistent reads
and smaller changes retain that baseline so elapsed time continues accumulating.
Rising health establishes a new baseline without claiming damage. Persistence comes
before the session advances; accepted health also updates the in-memory setting and
GUI. The function always returns an explicit accepted/rejected result, and exceptions
release its active-report guard. Repeated/stale session commits are rejected.

Snail and Commando fight limits and report scheduling now use GetTickCount64 rather
than wall-clock FILETIME. The rate uses the timestamp after the observation series.
The elapsed interval includes real time while paused because game health can still
change. This does not change the separate macro runtime accounting, which excludes
pause. Duration formatting uses seconds consistently, including minute/hour carries.

Remaining gates:


- Record current game examples for every boss/bug family, camera zoom and DPI.
  Planters and unrelated scene colors may still resemble a health bar. Clipped or
  obscured bars cannot establish the true enemy health percentage.
- Replace kill-success inference from elapsed loops or missing health bars with
  positively recognized game results and bounded recovery. A successfully read
  empty image only establishes that this detector found no bars in that image.
- Make every combat action release its inputs on interruption and recover from
  unknown observations without inventing kills or full cooldown timestamps.
- Verify Snail/Commando estimates against current game health changes, sustained
  damage, regeneration/reset, pause and delayed frames. Multi-frame agreement cannot
  establish enemy identity, and estimated time assumes a continuing damage rate.
  A recoverable unknown-action state and cross-process settings ownership remain open.
- Measure memory, GDI objects and capture/scan cost during long mixed runs. The
  repeated fixture test is a regression check, not an overnight soak or measured
  performance improvement.

No live Roblox scenario has been run for this checkpoint.
