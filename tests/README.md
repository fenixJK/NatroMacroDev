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
