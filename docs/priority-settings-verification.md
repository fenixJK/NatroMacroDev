# Task-priority editing and persistence

The editor previously mutated its displayed array before attempting persistence,
and a drag could use an uninitialized output string. Discord's get command rendered
default task names instead of the saved permutation. Main rebuilt its task array
only at startup, so later edits did not reliably affect a running scheduler.

`nm_PrioritySettings` shares one permutation validator across reading, moving,
describing and saving an order. An order contains each digit 1 through 8 exactly
once. Moves preserve the relative order of the other seven tasks. Descriptions
use the actual saved task order. Invalid saved values fail validation; reads never
silently reset the file. An absent setting retains the existing default order.

The editor and Status serialize priority writes through an OS-owned file lock,
with a one-second cooperative acquisition deadline. The editor compares its last
saved order with the current file while holding the lock, rejecting a stale edit
instead of overwriting a newer remote change. IniWrite completes before the caller
publishes the returned candidate. Status can explicitly save a new valid order or
reset the default even when the existing order is malformed.

The editor's renderer no longer mutates task order. Drop/reset save first and then
update the displayed array; failures leave it unchanged and show a save error.
Drag preview uses explicit screen coordinates, yields between frames, supports
Escape, restores cursors in finally,
and has a fifteen-second monotonic deadline. Native input/UI interactions remain
separate from the programmatic save/reset tests described below.

Priority notifications target only verified main/Status script paths and bundled
runtime paths in the selected installation, with existing user/session checks and
retained process handles. Messages carry an invalidation rather than an order.
Main and Status reload their own validated file instead of trusting the payload.
Main also reads the saved order at the start of each full task cycle, so a missed
notification does not keep the old order indefinitely. An in-progress cycle keeps
its existing array; configured task interrupts retain their existing behavior.
Discord replies describe the saved order and state when it takes effect.

## Verification contract

Regression fixtures exercise every source/destination move for default and reverse
orders, correct descriptions, malformed permutations, missing-file defaults,
persistence, stale edits, a held native file lock, failed writes, lock release and
corrupt-file preservation. The native priority GUI probe checks the coordinate mode and calls the actual
save and reset functions before its repeated redraw/close checks.

Native process fixtures include a 32-bit main and 64-bit Status in a selected
installation, plus a personal script, a second installation, and a same-path
Status running under the wrong runtime. Posted-message queue barriers verify that
only the two intended workers receive one invalidation. The fixtures also check
that discovery handles are released. These are disposable local AHK processes;
they perform no Roblox input and send no Discord messages.

## Verified checkpoint

Code `3e70c501689ae3ff9282de8a168c4c74e38fb4e9` passed
[Windows run 34458814651](https://github.com/fenixJK/NatroMacroDev/actions/runs/34458814651).
Both AHK architectures passed 64 regression groups, native process and GUI suites,
nine production-script validations, four test-entry validations and seven emitted
worker validations. PowerShell 5.1 and 7 each passed eight file-channel checks,
43 attachment checks and 35 updater scenarios. No AHK warnings occurred; the
checkout action's Node runtime deprecation notice remains.

Earlier CI caught a test-local/global name collision and failure to notify hidden
script windows after discovery restored AHK's hidden-window setting. Notification
now uses the native window handle directly after rechecking its process ID. Library
includes were also made independent of the root stdin worker's script directory.
The final GUI probe checks the explicit screen-coordinate mode for dragging.

## Remaining limits

The lock serializes these priority writers; it is not a dedicated single writer
for all macro settings. IniWrite is not a crash-atomic, versioned file transaction,
and legacy versions or external editors do not participate in the lock. A stale
editor must reopen to refresh. Notifications are best effort and do not acknowledge
application by the scheduler. Identity matching is not a security boundary against
code running as the same user. Other settings still use legacy IPC.

The full main loop, physical drag/Escape behavior, Discord command dispatch and
live mid-run reorder with configured interrupts have not been exercised against
Roblox. CI validates their source and exercises shared logic/native fixtures;
it does not establish successful game tasks or complete F17/production recovery.
