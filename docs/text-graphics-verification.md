# Text drawing resources and explicit brushes

`Gdip_TextToGraphics` now delegates to `Gdip_TextRenderer`. Font family, font,
string format and internally created brush allocations have a finally cleanup
path. Creation stops at the first failed dependency. A missing graphics pointer
fails before native allocation; alignment, rendering, measurement and drawing
results are checked. Every allocated resource gets its own release attempt even
when an earlier release reports failure or throws.

Successful calls retain the six-field measurement string and the existing layout,
alignment, style, percentage and measure-only options. Errors retain -1 through
-6 for missing percentage dimensions, graphics, family, font, format and brush;
-7 reports an operation/exception/cleanup failure. A completed draw whose cleanup
fails cannot return successful bounds. A cleanup call that persistently fails
can still leave its resource allocated until process exit.

`Gdip_MeasureString` now checks the native status before reading the output
rectangle. It returns zero on failure instead of formatting an uninitialized
buffer. Microsoft documents that successful
[MeasureString calls return Ok](https://learn.microsoft.com/en-us/windows/win32/api/gdiplusgraphics/nf-gdiplusgraphics-graphics-measurestring(constwchar_int_constfont_constrectf__conststringformat_rectf_int_int)).

## Brush calling convention

The `c` option always contains a hexadecimal ARGB color, up to eight digits.
Digit-only values are never passed to GDI+ as possible memory addresses, and
`c00000000` retains transparent black. The former heuristic attempted to clone
numeric colors as brush pointers. Microsoft's
[brush API](https://learn.microsoft.com/en-us/windows/win32/gdiplus/-gdiplus-brush-flat)
defines cloning as an operation on an existing brush object, not a pointer
validation API.

An existing brush is passed explicitly as the eighth argument:

```autohotkey
Gdip_TextToGraphics(graphics, "Text", "s24", "Arial", 220, 80, 0, brush)
```

The caller must supply a valid live GDI+ brush and retains ownership. The helper
does not clone or delete it. This supports solid and gradient brushes. Auto-Jelly
and StatMonitor's five dynamic report-label calls now use explicit ownership;
labels that do not share brushes use color options and let the helper own them.
External custom callers using the old `"c" brush` convention must migrate to the
eighth argument. Automatic interpretation of those decimal pointers is removed.

## Verification contract

Regression fixtures inject failed results and exceptions during family, font,
format and brush allocation, alignment, rendering, both measurement passes and
drawing. They assert that owned resources are released, borrowed brushes are
untouched, measurement-only calls do not draw, percentage/alignment behavior is
retained, and invalid requests allocate nothing. Failed brush deletion checks
that all other releases are still attempted and successful bounds are withheld.

Native tests compare pixels rendered with color options and explicit brushes,
including digit-only ARGB and transparent black. Measurement-only preserves a
blank bitmap. Solid/gradient brushes remain deletable by their owner, missing
fonts return failure, and an actual failed native measurement returns zero.
Another 350 cases per architecture track actual GDI+ creation and successful
matching deletion across normal drawing and injected later failures. These check
native release results and outstanding ownership rather than inferring GDI+
allocation lifetime from Windows' GDI handle count.

## Verified checkpoint

Code `1426fafd6ed4a2856335022175642d4052b1c06f` passed
[Windows run 34467862555](https://github.com/fenixJK/NatroMacroDev/actions/runs/34467862555).
Both architectures passed 69 regression groups, native pixel/brush checks and
all 350 tracked GDI+ lifecycle cases, plus the existing GUI/input/OCR/process
suites. Nine production scripts, four test entry points and seven emitted workers
validated per architecture. PowerShell 5.1 and 7 each passed eight file-channel
checks, 43 attachment checks and 35 updater scenarios. No AHK warnings occurred;
the checkout action's Node runtime deprecation notice remains.

The initial [run 34467673151](https://github.com/fenixJK/NatroMacroDev/actions/runs/34467673151)
stopped at a warning that a new fixture local named `first` shadowed the geometry
harness's global. Renaming that local fixed validation without disabling warnings
or changing assertions.

## Remaining scope

The ownership fixtures are bounded checks, not heap profiling or a long soak.
Native calls remain synchronous. A failed drawing operation may have changed
pixels before returning failure; the helper does not roll back a caller's bitmap.
Broader renderer failure propagation, whole hourly-report rendering, text-path
outline helpers, icon extraction and other GDI+ resource paths remain work.
No whole-program performance gain, live-game verification or release is claimed.
