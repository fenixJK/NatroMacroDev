# Shared screen capture ownership and failure handling

`Gdip_BitmapFromScreen` delegates to `Gdip_ScreenCapture`. The helper retains
virtual-desktop, monitor, explicit rectangle and `hwnd:` requests. It validates
rectangle shape and numeric bounds before allocation, truncates fractional crop
coordinates as the previous native calls did, and preserves explicit raster
operations. Invalid rectangles return -1, invalid window requests return -2,
and failed resource acquisition or capture returns zero.

A window source DC belongs to its requested HWND. Capture releases that borrowed
DC with `ReleaseDC(hwnd, source)` and deletes only the compatible memory DC it
created. Failed window DC acquisition returns failure without falling back to
desktop capture. Allocation, bitmap selection and pixel-copy results are checked
before decoding or publishing an image.

Cleanup restores the previous bitmap selection, deletes the owned DIB and memory
DC, and releases the source DC in a finally path. If restoring the selection
fails, it attempts to delete the memory DC first so the DIB is no longer selected.
A cleanup failure invalidates a decoded image rather than returning success.
Persistent native cleanup failures can still leave resources until process exit;
this is not a guarantee that an arbitrary failing Windows cleanup call succeeds.

Microsoft requires borrowed display DCs to be released using
[ReleaseDC](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-releasedc),
and explicitly prohibits passing a GetDC result to
[DeleteDC](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-deletedc).
[BitBlt](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-bitblt)
returns zero on failure. The previous helper ignored that result and could return
a decoded bitmap despite a failed transfer.

## Verification contract

Regression fixtures inject false returns and exceptions at acquisition, memory
DC creation, DIB allocation, selection, copy, decode and selection restoration.
They check that only complete success returns an image, no fixture-owned resource
remains, the source is released to the original HWND, and borrowed DCs are never
deleted. Invalid requests allocate nothing. Fractional coordinates and explicit
BLACKNESS raster forwarding are covered.

The Windows fixture checks actual screen and window pixels and dimensions. After
warming both paths, it performs 200 successful captures and 300 injected failures
after real Windows resource acquisition, then requires GDI object counts to stay
within two objects of the baseline. Failure injection covers copy rejection,
copy exceptions and decode rejection. It also verifies native BLACKNESS output.
These injections exercise real resource teardown, not a claim that Windows
itself produced each injected failure.

## GUI fixture timeout investigation

The first capture run, [34466182909](https://github.com/fenixJK/NatroMacroDev/actions/runs/34466182909),
passed 68 regression groups on both architectures and native capture on 32-bit
Windows (GDI 34 to 34). The 64-bit job timed out in the existing generated
Auto-Jelly GUI probe before reaching native capture.

Stage timing added in `63f375d1d97e97da01d1d39bb18d68dded4ee856` exposed the cause in
[run 34466398934](https://github.com/fenixJK/NatroMacroDev/actions/runs/34466398934):
exhaustive template comparisons used 17,672 ms on 32-bit and 17,454 ms on 64-bit,
leaving insufficient time for preflight, mouse, limits and redraw checks within
one 20-second worker. Both jobs reached later GUI stages before timing out.

The fixture now runs template inputs in two disjoint batches, each still searching
the complete bee asset set, and runs interactive GUI checks in a separate worker.
It verifies the expected input count in each batch and logs stage timestamps.
All 68 template variants, existing interaction assertions and each worker's
20-second timeout are retained. Production worker timeouts are unchanged.

The first split run, [34466614181](https://github.com/fenixJK/NatroMacroDev/actions/runs/34466614181),
finished both asset batches but correctly failed the unchanged read-only settings
assertion: the preceding worker's normal close had saved its GUI position into
the shared test INI. Each independent worker now starts with a fresh copy of the
original fixture. This resets test data before startup, without relaxing the
byte-for-byte startup preservation assertion or changing production persistence.

## Verified checkpoint

Code `97a801dad5f942445b385cd00653a5c80b9db57f` passed
[Windows run 34466765646](https://github.com/fenixJK/NatroMacroDev/actions/runs/34466765646).
Both architectures passed 68 regression groups, native GUI/input/OCR/process
suites, nine production-script, four test-entry and seven emitted-worker
validations. Screen/window capture GDI counts stayed at 34 before and 34 after
the repeated success/failure loop on both architectures. Native dimensions,
fixture colors and BLACKNESS checks passed.

Each asset batch verified 34 templates against the complete search set. Measured
asset phases took 6,407/6,359 ms on 32-bit and 9,110/6,157 ms on 64-bit; interactive
preflight through the start of redraw took 2,109/2,000 ms respectively. These are
fixture phase durations, not whole-worker timings or production benchmarks.
Read-only startup, GUI interaction, repeated redraw and close assertions passed.

PowerShell 5.1 and 7 each passed eight file-channel checks, 43 attachment checks
and 35 updater scenarios. No AHK warnings occurred. The checkout action's Node
runtime deprecation notice remains.

## Remaining scope

Successful BitBlt does not prove that a game is visible, unobscured or displaying
fresh content. Higher-level geometry, focus and observation checks remain
necessary. This helper does not interpret a valid black image as an API failure.
The fixture is a bounded GDI handle check, not a GDI+ heap measurement or long
soak. Synchronous native calls have no hard timeout.

The separate PrintWindow helper, text/font allocations, icon extraction and
other GDI+ paths retain their own ownership contracts and need separate review.
No Windows/Roblox machine is available for live gameplay verification. No
whole-program performance gain or production release is claimed.
