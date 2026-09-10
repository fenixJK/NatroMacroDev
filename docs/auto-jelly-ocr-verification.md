# Auto-Jelly OCR waits and ownership

Auto-Jelly previously polled WinRT operations indefinitely, without checking its
stop flag or client geometry. Some OCR errors exited the entire settings process.
Several HSTRINGs, interface references and failure-path streams lacked cleanup.

The rolling run now owns one OCR engine and decoder factory. Preflight selects
English from the device's installed OCR recognizers, rather than intersecting
OCR support with the user's preferred UI-language list. This follows the Windows
[AvailableRecognizerLanguages contract](https://learn.microsoft.com/en-us/uwp/api/windows.media.ocr.ocrengine.availablerecognizerlanguages).
Engine creation failures throw into the existing run teardown before rolling.
Bee-only runs still do not initialize OCR.

Each mutation read gets one ten-second monotonic budget covering conversion,
decoding, software-bitmap creation and recognition. Polls yield for at most 10 ms
and check cancellation, focus and geometry through the same input surface used
for rolling. A completed result is checked again before it is returned. Failed,
cancelled or unknown operation states cannot return recognized text. A later stage
cannot reset the time budget. Errors return to the normal Auto-Jelly stop dialog
and teardown instead of calling ExitApp.

Every returned COM interface is immediately wrapped with AHK ownership. Returned
and created HSTRINGs are deleted, including on text-read failure. The HBITMAP is
borrowed during stream conversion and remains owned by the caller. The converter
checks HRESULTs, uses a stream that frees its HGLOBAL on release and rewinds it
before decoding. Software bitmaps and random-access streams receive best-effort
IClosable.Close calls before their wrappers release. Engine/factory references
are released before the run's matching RoUninitialize. Successful RoInitialize
calls, including S_FALSE, are balanced as required by
[Windows Runtime initialization](https://learn.microsoft.com/en-us/windows/win32/api/roapi/nf-roapi-roinitialize).

Async teardown requests cancellation only for a Started operation. It rechecks
status and calls IAsyncInfo.Close only after a terminal state is observed, since
[Close is invalid before completion](https://learn.microsoft.com/en-us/uwp/api/windows.foundation.iasyncinfo.close).
A provider that ignores Cancel is released without waiting indefinitely or
incorrectly calling Close. Cleanup errors do not replace the original run failure
or cancellation. This releases the macro's references; it does not claim that an
uncooperative provider has stopped its internal work.

## Verification contract

Deterministic fixtures cover completion, failed/cancelled/invalid states, a stalled
operation, cancellation between polls, throwing status/GetResults calls, results
arriving after the deadline, and a budget shared across stages.

Native COM-vtable fixtures exercise the production async adapter and count both
owned references, Cancel requests and Close calls. Cases include a provider that
remains Started, immediate cancellation, completed/error states and status, Cancel
or Close call failures. Repeat teardown must not release twice.

The Windows integration test requires an installed English recognizer and reads
generated text through the real HBITMAP-to-stream, decoder, software-bitmap and
OCR pipeline repeatedly. It also checks cancellation and subsequent reuse of the
same input/engine, rejection after actual decoding with an unsupported size limit,
subsequent recognition after that failure, and idempotent engine/apartment teardown.

## Verified checkpoint

Code `96feb88ca3c88bcd660cc9b4abf32b6475e7086b` passed
[Windows run 34462790854](https://github.com/fenixJK/NatroMacroDev/actions/runs/34462790854).
Both AHK architectures passed **66 regression groups**, native GUI/input/process
suites, nine production-script validations, four test-entry validations and seven
emitted-worker validations. Both runners reported `en-US` and completed actual
OCR recognition, decode rejection/reuse and the seven COM lifecycle cases.
PowerShell 5.1 and 7 each passed eight file-channel checks, 43 attachment checks
and 35 updater scenarios. There were no AHK warnings; the checkout action's Node
runtime deprecation notice remains.

The first validation run caught local names colliding with Buffer and a test
global; these were corrected. Constructor factory dispatch was also corrected
before native verification. No assertions or timeout thresholds were relaxed.

## Limits

The deadline bounds cooperative polling. It cannot preempt a synchronous Windows
call that stops returning, and polling intervals are scheduling requests rather
than hard real-time guarantees. Provider-level cancellation is cooperative. The
tests do not prove every native internal allocation is freed or establish a long
duration memory soak.

Generated English text is not an in-game mutation corpus. Mutation trigger
accuracy, nonempty but invalid OCR results, animation freshness and live display/
DPI behavior still need fixtures and game verification. Consumption budgets and
positive roll receipts remain open. No Windows/Roblox machine is available; this
work does not establish full Auto-Jelly or production readiness.
