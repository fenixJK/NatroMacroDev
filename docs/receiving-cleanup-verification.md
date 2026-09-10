# Attachment receiving-directory cleanup

Status no longer runs recursive directory deletion after an attachment worker
finishes. It confirms that worker has stopped, launches a contained AHK cleanup
helper, and polls its process state in the existing Status loop. The active
attachment retains ownership until cleanup finishes or its twenty-second
cooperative deadline expires. A second attachment cannot replace it meanwhile.

Cleanup timeout or launch failure retains the confirmed download result and adds
a message that temporary files may remain. The helper is stopped and its process
termination confirmed before ownership is released and a single reply is sent.
Unconfirmed process termination leaves ownership in place and propagates the
error. Diagnostic callback failures cannot change the result or repeat a reply.

Shutdown stops the download worker, then permits up to five seconds for the
cleanup helper before terminating it. It sends no completion reply. This is best
effort: main's helper shutdown policy can terminate Status sooner, and an owner
crash kills the cleanup helper through its job. Either can leave temporary files.
There is no detached process that keeps deleting after its owner exits.

## Deletion scope

The helper accepts only an absolute local drive path ending in
`settings/remote-inbox/.receiving-` followed by a 32-character hexadecimal key.
Traversal components, ambiguous trailing dots/spaces, invalid characters and
excessively deep paths are rejected. Requests still use the bounded private
mapping, not command-line interpolation.

It opens and inspects each ancestor without delete sharing and with
OPEN_REPARSE_POINT, retaining the handles through the operation. Reparse points
are rejected. It can delete only the regular, singly linked `payload.partial`
file and then the empty receiving directory. Deletion uses the same verified
handles through
[SetFileInformationByHandle](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-setfileinformationbyhandle)
and
[FILE_DISPOSITION_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_disposition_info).

There is no recursive traversal. Unexpected files/subdirectories, hardlinks,
locked files, read-only files and linked ancestors are retained. A missing
receiving directory is already clean. The published attachment and inbox lock
are outside the deletion scope. Normal cleanup does not delete other receiving
directories or scan historical leftovers.

## Verification scope

Controller tests cover pending cleanup without premature notification, busy
rejection, timeout, cleanup launch failure, notification failure and unchanged
download success when temporary cleanup fails. The production attachment fixture
launches the real worker and cleanup helper from a Unicode path and verifies
confirmed removal and shutdown behavior.

Native tests cover empty and partial-file cleanup, missing targets, unexpected
contents, hardlinks, read-only and locked files, path traversal and ancestor
symlinks. The tests inspect retained contents and rejected targets. Existing
contained-job tests cover descendant termination and owner crashes. CI now
validates the four test entry points before running them, as well as production
and emitted scripts.

Code `af1e8c4499a5959a3e7dda3e005653c4b73404d4` passed
[Windows run 34454860093](https://github.com/fenixJK/NatroMacroDev/actions/runs/34454860093).
Both AHK architectures passed 62 regression groups, the native process/GUI suites,
nine production-script validations, four test-entry validations and four emitted
worker validations. PowerShell 5.1 and 7 each passed eight file-channel checks,
43 attachment checks and 35 updater scenarios. No AHK warnings occurred.

The first native fixture revisions used a reserved variable name and shadowed
the built-in File class; CI rejected both before native tests could execute.
Those fixture issues were corrected without weakening the deletion checks.
The fixtures use disposable local files and do not run Roblox or contact Discord.

## Remaining limits

This removes the receiving-folder deletion call from Status's normal polling
path. It does not make every owner operation asynchronous: directory preparation,
process creation/termination calls, diagnostic logging and other legacy file
operations still have native or filesystem costs. Cooperative deadlines cannot
bound every OS stall. Upload-archive cleanup is separate and remains synchronous.

Old, crash-left, linked or unexpected receiving contents require later
reconciliation; they are not silently removed. Cleanup results and completion
notifications are not durable. A crash after attachment publication can still
leave an uncertain delivery outcome. Full main/Status shutdown, live Discord
delivery, malicious concurrent filesystem mutation and performance/resource soaks
remain outside the verified scope. This is no claim that the earlier intermittent
PowerShell timeout has been fixed.
