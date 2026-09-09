# Updating and recovering

Stop the macro before choosing Update. The updater downloads an official release
ZIP into a separate staging folder beside the installation. It checks the expected
size and SHA-256 digest when the release provides one, rejects unsafe archive paths,
checks the package layout, copies selected user files, and parses the submacro
scripts with both installed AHK runtimes. A release with different AHK executables
requires a manual update until that runtime change has been reviewed.

The new installation receives a unique `NatroMacro-update-…` folder. The previous
installation stays in place as a rollback copy, including its original settings.
The former Delete Old option has been replaced with this recovery policy. Remove
an old copy manually only after verifying the new version works for your setup.

Settings are copied when selected. Unique custom paths and patterns are copied as
well. When a shipped path or pattern differs from the old file with the same name,
the new shipped file stays active; the old variant is saved under `update-backup`
in the new installation. Review those variants before restoring custom changes.
The updater reports their relative names. This avoids silently overwriting a
shipped fix with an older file while preserving your edits.

If an update fails, reopen `START.bat` in the previous installation. Detected
failures restore the existing NatroMacro login-startup entry if it was changed by
this update. An unrelated entry or a concurrent external change is left alone.
If the machine loses power or the updater is killed, the recovery record remains
at `.natro-update-…/transaction.json` beside the installations. It identifies both
folders and the startup entry before and after the transaction. Open the old
macro's Auto-Start Manager to restore its login entry if necessary. Keep that
record and the old installation until recovery is complete.

The updater waits for the old macro to finish normal exit cleanup before copying
settings. It detects a candidate that exits within five seconds, but successful
process startup does not prove a working GUI, valid gameplay observations, or a
compatible settings migration. Verify your usual configuration in the new version
before relying on it for a long run. Do not run both installations simultaneously.

A failed transaction retains its staging folder for diagnosis. After recovery,
that folder can be removed manually; a successful transaction removes the temporary
download and extracted staging data but keeps its small recovery record. Recovery
records contain local paths and the macro startup command; review them before
sharing them publicly.
