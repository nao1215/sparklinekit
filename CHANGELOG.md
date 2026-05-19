# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
starting with `1.0.0`. Pre-1.0 releases may break API in minor versions.

## [0.2.0] - 2026-05-20

Bug-hunt release. The public API surface is unchanged from 0.1.0;
every visible difference is a defect the v0.1.0 renderer silently
shipped. Two systematic QA rounds (PR #3, PR #4) added ten new
regression tests under `test/sparklinekit/qa/` covering each
defect and the property it now satisfies.

### Fixed

#### Behavioural defects

- `line.with_area_fill(False)` no longer destroys a prior
  `line.with_area_color(c)`. The toggle is now a pure
  enable / disable; the explicit colour survives across a
  disable / re-enable round-trip.
- `bar.new` (no explicit theme) now honours
  `theme.default().negative` (`#EF4444`) for negative-bar
  fill. Previously the default theme's negative slot was
  declared but never applied, leaving mixed-sign charts
  visually identical for positives and negatives unless
  `with_theme(...)` was called.
- Zero-value bars now render as a 1-pixel hairline at the
  baseline instead of collapsing to a `height="0.0"` rect.
  A reader can distinguish "value was zero here" from
  "value missing here". The hairline grows *into* the
  canvas, so it stays inside the viewBox even when the
  baseline pins to a canvas edge (all-positive or
  all-negative input).
- `line.with_area_color("rgb(255, 0, 0)")` (or any non-hex
  CSS colour string) no longer gets silently substituted by
  the stroke colour or by black when the default gradient is
  enabled. The renderer drops the gradient and emits a solid
  fill with the user's literal CSS colour.
- Default theme (`currentColor` stroke) plus
  `line.with_area_fill(True)` now produces an area that
  inherits the surrounding CSS colour via
  `fill="currentColor"` and `fill-opacity="0.22"`, instead
  of the previous hardcoded black gradient stops.

#### Totality on adversarial input

- `unicode.render`, `line.to_svg`, and `bar.to_svg` no longer
  raise `arithmetic_error` (Erlang) or emit `Infinity` /
  `NaN` coordinates (JavaScript) for extreme `List(Float)`
  input. `scale.unit` clamps to `±1.0e300` before subtraction
  so the intermediate `max - min` stays inside the IEEE 754
  double range; `bar.compute_layout` clamps each per-bar
  value the same way.
- `line.with_stroke_width(very_large)` is clamped to
  `≤ 1.0e4` at the setter, so the PNG raster's per-pixel
  perpendicular sweep cannot stall the renderer. The SVG
  side is additionally guarded by a `±1.0e6` clamp inside
  `format.coord` against any other adversarial coordinate.
- `line.with_spot(very_large)` is clamped to `[0.0, 1.0e4]`
  at the setter, so the disc fill's bounding-square iteration
  cannot stall the PNG path.

### Removed

- Deprecated `line.to_string` / `bar.to_string` aliases for
  `to_svg`. Both were introduced before the first public
  release; since v0.1.0 was the first version on Hex there
  is no prior caller to stay compatible with.

### Documentation

- `test/sparklinekit/qa/` — six modules (`property_test`,
  `fuzz_test`, `metamorphic_test`, `boundary_test`,
  `snapshot_test`, `differential_test`) plus the two
  round-by-round regression suites (`deep_test`,
  `deep2_test`) bring the QA harness to 219 tests on each
  target.

[0.2.0]: https://github.com/nao1215/sparklinekit/releases/tag/v0.2.0

## [0.1.0] - 2026-05-19

Initial public release. Pure Gleam, zero runtime dependencies
beyond `gleam_stdlib`, runs on both the Erlang and JavaScript
targets, MIT licensed.

### Added

#### Unicode renderer

- `sparklinekit/unicode` — terminal sparklines built from the eight
  Unicode block characters `▁▂▃▄▅▆▇█`. Empty input renders as `""`;
  single-value and all-equal inputs render as the middle block.
- `unicode.render` / `unicode.render_ints` for `List(Float)` and
  `List(Int)` inputs respectively.

#### SVG / PNG line renderer

- `sparklinekit/line` — opaque builder that renders to either SVG
  strings (`line.to_svg`) or 8-bit RGBA PNG byte arrays
  (`line.to_png`). PNG strokes use Xiaolin Wu anti-aliasing; SVG
  output carries `preserveAspectRatio="none"` so charts scale into
  any container.
- Constructors `line.new` and `line.new_ints`; in-place value
  replacement via `line.with_values` / `line.with_int_values`.
- Styling helpers: `line.with_color`, `line.with_background_color`,
  `line.with_size`, `line.with_stroke_width`, `line.with_theme`.
- `line.with_smoothing(factor)` — cubic Bézier smoothing
  (`0.0`–`0.5` factor, matching `react-sparklines`).
- `line.with_area_fill(enabled)` / `line.with_area_color(colour)` /
  `line.with_gradient_area(enabled)` — tinted area under the line,
  rendered as a top-to-baseline gradient by default.
- `line.with_spot(radius)` / `line.with_spot_color(colour)` —
  filled circle on the last data point as a "today" marker.
- Default viewBox of `240x60`, default stroke width `2.0`,
  stroke-width-aware padding so thick strokes are not clipped at
  the canvas edge.

#### SVG / PNG bar renderer

- `sparklinekit/bar` — opaque builder that renders to SVG
  (`bar.to_svg`) or PNG (`bar.to_png`). Rounded corners are
  preserved in the raster output.
- Constructors `bar.new` and `bar.new_ints`; in-place value
  replacement via `bar.with_values` / `bar.with_int_values`.
- Styling helpers: `bar.with_color`, `bar.with_background_color`,
  `bar.with_size`, `bar.with_bar_gap`, `bar.with_theme`.
- `bar.with_corner_radius(radius)` — radius is clamped to half the
  smaller side of each bar so the shape stays a rectangle or
  capsule rather than collapsing to a circle.
- `bar.with_negative_color(colour)` — distinct fill for bars below
  the zero baseline; positives and negatives share that baseline.

#### Themes

- `sparklinekit/theme` — ten bundled colour schemes covering the
  common dashboard styles: `ocean`, `forest`, `sunset`, `mono`,
  `neon`, `pastel`, `crimson`, `slate`, `amber`, `midnight`.
  Plus `theme.default()` which inherits the surrounding CSS
  `currentColor`.
- Each theme bundles four slots — `foreground`, `background`,
  `area`, `negative` — exposed via `theme.foreground/1`,
  `theme.background/1`, `theme.area/1`, `theme.negative/1`.
- Apply a theme with `line.with_theme` / `bar.with_theme`; chain
  `with_color` / `with_background_color` / `with_area_color` /
  `with_negative_color` to override individual slots.

#### Internals

- `sparklinekit/internal/color` — hex colour parsing for `#rgb`,
  `#rgba`, `#rrggbb`, `#rrggbbaa`, plus alpha blending and
  channel-wise compositing helpers.
- `sparklinekit/internal/png` — PNG encoder using CRC32 +
  Adler32 + DEFLATE "store" blocks. Pure Gleam, no FFI.
- `sparklinekit/internal/raster` — sparse canvas with `draw_line`
  (Wu anti-aliased), `fill_circle`, `fill_rounded_rect`, and
  `fill_vertical_gradient` primitives.

### Documentation

- README written around runnable samples, each pinned to a test
  in `test/sparklinekit/readme_test.gleam` so the published
  snippets cannot drift from the library.
- Sample images in `docs/images/` covering the SVG / PNG hero
  shots, every theme preview, and the edge-case visuals
  (single-value, all-equal, negative input).

[0.1.0]: https://github.com/nao1215/sparklinekit/releases/tag/v0.1.0
