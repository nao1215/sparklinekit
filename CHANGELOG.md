# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
starting with `1.0.0`. Pre-1.0 releases may break API in minor versions.

## [Unreleased]

### Changed

- `bar_png` shades each pixel by the share of it a bar covers, as a browser draws the `bar_svg` output at 100% zoom. Before, it rounded every bar edge to the nearest pixel, and since an edge on a half pixel rounded up, a bar whose edges both fell on half pixels moved one column right of the SVG. Edges on half pixels, which the default 1.0 gap gives whenever the width divides evenly by the number of bars, are now drawn as two half shaded columns, and rounded corners are anti-aliased. Edges on whole pixels draw as before.
- `line_png` takes the height of the area in each column from the centre of the column instead of its left edge, and shades the first and last column by the share the area covers. Before, an area that started or ended on a half pixel, such as with a `spot_radius` of 3.5, began one column right of the SVG.
- `blocks` gives each of its eight blocks an equal eighth of the range. Before, a value took the nearest of eight evenly spaced levels, so `▁` and `█` each covered a fourteenth of the range and the six blocks between covered a seventh. A value can now draw one block lower or higher than before: in `[0.0, 7.0, 0.5]` the last value is now `▁` (was `▂`), and in `[0.0, 7.0, 6.2]` it is now `█` (was `▇`). The maximum is still `█`, and a constant series is still `▄`.

## [0.7.0] - 2026-11-23

### Breaking

`line_svg`, `line_png`, `bar_svg` and `bar_png` now check every colour before drawing and return a `Result`. Before, SVG output wrote any colour string as given while PNG output drew a colour it could not read black, transparent or as a tint of the line, so one theme could mean two different charts.

- The four chart renderers return `Result(String, InvalidColor)` or `Result(BitArray, InvalidColor)`. `blocks` is unchanged.
- A colour is `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `none` or `currentColor`, with the keywords in any case. Anything else in the theme or in `spot_color`, such as `"red"`, `"rgb(0, 0, 0)"` or `""`, gives `Error(InvalidColor(field:, value:))`, where `field` is `"foreground"`, `"background"`, `"area"`, `"negative"` or `"spot_color"`. All four theme colours are checked, including one the chart does not draw.
- An empty background or area colour is rejected. Use `"none"` for no background and `None` for the default area.
- `none` draws nothing in both formats, so a foreground of `none` draws no line, no dot, no default area and no bars at or above zero, and a negative of `none` draws no bars below zero.
- `currentColor` is drawn black in PNG output, which has no surrounding text colour, wherever it is used.
- Since every colour that reaches the SVG text has been checked, colours are no longer escaped.
- SVG output writes a colour with alpha (`#rgba`, `#rrggbbaa`, and the default area tint) as `#rrggbb` with a `fill-opacity`, `stroke-opacity` or `stop-opacity` attribute, because SVG 1.1 renderers do not read the alpha forms. Hex colours without alpha are still written as given.

Before:

```gleam
let svg = sparklinekit.line_svg(values, options)
```

After:

```gleam
case sparklinekit.line_svg(values, options) {
  Ok(svg) -> svg
  Error(sparklinekit.InvalidColor(field:, value:)) -> panic as { field <> ": " <> value }
}
```

### Fixed

- The gradient area of a series with values on both sides of zero faded from the top of the chart to the bottom in SVG, so the part below zero was faintest at the line and strongest at zero. Each side now fades towards zero, in SVG and PNG.
- PNG output shaded the gradient area per column, from the line down to the baseline, while SVG shades it by height over the whole area. PNG output now shades it by height too, so both formats draw the same opacity at the same height.
- A gradient area under a `currentColor` line, or with an area colour of `currentColor`, was drawn flat in SVG and as a black gradient in PNG. SVG output now draws it as a gradient of `currentColor` with `stop-opacity`.
- Values beyond 1e300 were clamped to 1e300 before scaling, so two different large values, such as `1.0e308` and `1.7e308`, were drawn as a constant series. They are now scaled without overflow up to the largest Float.
- On JavaScript, NaN compared as the largest value and was drawn at the top. NaN is now drawn as `0.0`, and Infinity as the largest Float, in every renderer.
- Each bar kept its gap on its right, so the chart had no margin on the left and a full gap on the right, and a reversed series was not drawn as its mirror image. Each bar is now centred in its share of the width, with half the gap at each edge.

### Documentation

- The 0.6.0 notes name a single package that had to follow that release. In general, any code that imports `sparklinekit/line`, `sparklinekit/bar`, `sparklinekit/theme` or `sparklinekit/unicode` has to be rewritten against the `sparklinekit` module when it moves to 0.6.0 or later, as the 0.6.0 Breaking section describes.
- README describes the accepted colours, and the README images are drawn again with the new gradient and bar layout.

## [0.6.0] - 2026-11-23

### Breaking

The public API is now the single module `sparklinekit`. The builders and the theme are plain records, so their setters and getters are removed.

- `sparklinekit/unicode`, `sparklinekit/line`, `sparklinekit/bar` and `sparklinekit/theme` are removed and their contents move into `sparklinekit`.
- `unicode.render` is `sparklinekit.blocks`. `unicode.render_ints` is removed; pass `list.map(values, int.to_float)`.
- The opaque `line.Builder` and `bar.Builder` are replaced by the records `LineOptions` and `BarOptions` with the constants `default_line_options` and `default_bar_options`. `line.to_svg` and `line.to_png` are `line_svg(values, options)` and `line_png(values, options)`, and `bar.to_svg` and `bar.to_png` are `bar_svg` and `bar_png`. `new`, `new_ints`, `with_values`, `with_int_values` and every `with_*` setter are removed; set the record fields instead (`with_size` is `width` and `height`, `with_spot` is `spot_radius`, `with_bar_gap` is `gap`).
- `with_area_fill`, `with_area_color` and `with_gradient_area` are replaced by the `area` field, which is `NoArea`, `SolidArea` or `GradientArea`, and the theme's `area` colour.
- `with_color`, `with_background_color` and `with_negative_color` are replaced by the fields of the `theme`, for example `Theme(..sparklinekit.ocean, foreground: "#22A06B")`.
- `Theme` is a record with the fields `foreground`, `background`, `area` and `negative`, so the accessor functions are removed. `area` is an `Option(String)`; `None` uses the foreground at 22% opacity. The theme functions are constants: `theme.ocean()` is `sparklinekit.ocean`, and `theme.default()` is `sparklinekit.default_theme`.
- `sparklinekit.package_version` is removed.
- In PNG output, a foreground or negative colour that is not hex is drawn black. It used to fall back to the colour of the theme set before `with_color` or `with_negative_color`.
- Options out of range (sizes below 1, negative gaps and radii, smoothing outside 0 to 0.5, very large stroke widths and dots) are still clamped, now when the chart is drawn.

Before:

```gleam
import sparklinekit/line
import sparklinekit/theme

line.new([1.0, 5.0, 3.0, 8.0, 4.0])
|> line.with_theme(theme.ocean())
|> line.with_area_fill(True)
|> line.with_spot(3.0)
|> line.to_svg
```

After:

```gleam
import sparklinekit.{LineOptions}

sparklinekit.line_svg(
  [1.0, 5.0, 3.0, 8.0, 4.0],
  LineOptions(
    ..sparklinekit.default_line_options,
    theme: sparklinekit.ocean,
    area: sparklinekit.GradientArea,
    spot_radius: 3.0,
  ),
)
```

tenbagger uses `sparklinekit/line` and `sparklinekit/theme` and needs to follow this change when it updates.

### Fixed

- A solid area (`with_gradient_area(False)`) under a themed line used a tint of the line colour in SVG and the theme's area colour in PNG. Both now use the theme's area colour.
- The dot on the last value kept the colour of the theme it was set with, so after `with_color` it was not the colour of the line, as its documentation said. It now follows the line colour unless `spot_color` is set.
- The SVG area gradient under a line that never goes above zero, with at least one value below it, was opaque at the top edge and faded towards the line. It now fades away from the line, as PNG output did.
- The area under a single negative value reached down to the bottom, while two equal negative values filled up to the top. Both now fill up to the top.
- Bars for a constant negative series stood on the bottom edge. They now hang from the top.
- An empty area colour wrote `fill=""` into the SVG, which browsers draw black. It now uses the foreground at 22% opacity, as `None` does.
- An area colour of `"none"` drew no area in SVG but a tinted one in PNG. PNG output now draws no area either.

## [0.5.0] - 2026-11-19

### Changed

- GitHub Releases now attach the Hex package tarball, `checksums.txt`, a keyless cosign signature bundle for it and build provenance (`*.intoto.jsonl`). See "Verifying releases" in the README.

## [0.4.0] - 2026-09-10

### Changed

- The minimum Gleam version is now 1.14.0 (was 1.15.0). 1.14.0 builds and tests the package unchanged on both targets, and `gleam_stdlib` 1.0 already requires it. CI tests that floor alongside the latest Gleam 1.x.

### Fixed

- `sparklinekit.package_version()` returned `"0.1.0"` in 0.2.0 and 0.3.0; it now returns the published version. The test that was meant to catch this compared the constant with a hard-coded string; it now reads `gleam.toml`.

### Documentation

- `line.to_svg`, `line.to_png`, `bar.to_svg` and `bar.to_png` now state what an empty, single-value or all-equal series renders, as `unicode.render` and the README's edge-case section already did. Tests pin that an empty series gives a blank PNG of the configured size.

## [0.3.0] - 2026-05-21

### Fixed

- README: the three sparkline sample images (`sparkline-line.png`, `sparkline-bar.png`, `sparkline-mixed-bar.png`) now use absolute `raw.githubusercontent.com` URLs instead of the relative `docs/images/...` paths so they render both on GitHub and on the Hex package page (the relative paths cannot be resolved against the published package archive, which omits the `docs/images/` directory). (#7)
- `line.with_area_fill(True)` now anchors the area to the zero baseline: all-positive series fill to the viewBox bottom (legacy behaviour, unchanged), all-negative series fill upward to the viewBox top, and mixed-sign series fill toward the SVG y-coordinate that data value `0.0` maps to — so positive segments tint downward toward zero and negative segments tint upward toward zero. Previously the area always closed at the canvas floor, which made mixed-sign series read visually as all-positive. (#6)

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
