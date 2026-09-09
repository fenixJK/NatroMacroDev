# Windows verification

Run from PowerShell 7 on Windows:

```powershell
./tests/run-windows.ps1
```

The runner verifies hashes of the bundled AHK 2.0.12 executables, loads all six
submacro scripts using `/Validate`, and runs the regression suite on both
architectures. It enforces a 60-second timeout per process and propagates failures.

The suite executes the production policy functions and AFB limit/cancellation
handlers. Configuration writes use a disposable temporary directory. Game
observation/travel stubs throw if reached; no Roblox session or Discord access is
needed. Tests cover invalid priorities, repeated private-server failure, backup
gaps, exhausted and changed limits, immediate GUI-to-runtime updates, cancellation,
the exact hour boundary, paused/disabled AFB, authorization, wait units, and local
exception logging/redaction.

These tests do not prove real key delivery, image accuracy, route correctness,
worker-script generation, or overnight stability. The full live scenario matrix
is in `production-audit.md`; those gates remain open in
`docs/production-progress.md`.

The updater suite also runs in both Windows PowerShell 5.1 (the production updater
runtime) and PowerShell 7:

```powershell
./tests/UpdateTests.ps1
```

It builds disposable ZIP/install fixtures with the actual bundled AHK executables.
Download and startup-registry dependencies are replaced with local fixtures; AHK
syntax validation uses real Windows processes. Failure cases cover incomplete or
corrupt downloads, unsafe archive paths, missing files, changed runtimes, invalid
migrated scripts, locked settings, interruption around each transaction stage,
existing destinations, startup-write failure, and launch failure. Success cases
check retained old settings, custom paths, conflict backups, copy options, startup
arguments, and unrelated/missing startup entries. An actual immediately exiting
AHK fixture also checks the launch-failure boundary.

The suite does not certify a release's gameplay or settings migration after startup.
The five-second process-survival check is an early failure detector, not a health
certificate. See `docs/updating.md` for rollback and conflict handling.


Planter recovery tests call the production retry wrapper with controlled action
results and temporary INI files. They cover retry limits/delays, interrupted action
reservations, changed planter identities, preservation of records and configured
capacity, and exclusion of stacked consumables from inventory-only reconciliation.
Planter observation tests run real GDI image search against synthetic progress bars,
including missing anchors and locked-bitmap failures. They exercise the reader and
resource cleanup; real-world harvest evidence and UI timing still require live tests.
