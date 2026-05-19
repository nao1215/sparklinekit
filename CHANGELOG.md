# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
starting with `1.0.0`. Pre-1.0 releases may break API in minor versions.

## Unreleased

### Added

- `line.with_smoothing(factor)` — turn the polyline into a cubic
  Bézier curve (the `0.0`–`0.5` factor matches the convention used
  by `react-sparklines`).
- `line.with_spot(radius)` / `line.with_spot_color` — drop an
  anti-aliased filled circle on the last data point as a "today"
  marker.
- `line.with_gradient_area(enabled)` — gradient area fills (top
  opaque, baseline transparent) are now the default; pass `False`
  to fall back to the older flat tint.
- Internal `raster.fill_circle` and `raster.fill_vertical_gradient`
  primitives drive the new spot and gradient features in PNG
  output.

### Changed

- Default line dimensions bumped from `200x40` to `240x60`, default
  stroke width from `1.5` to `2.0`, and the renderer now leaves a
  stroke-width-aware padding around the chart so a thick stroke at
  the topmost or bottommost data point no longer gets clipped at
  the canvas edge.
- The line renderer emits `<path>` (with `M`/`L`/`C` commands) in
  place of `<polyline>` so smooth and sharp variants share a single
  code path.

- `to_png` on both `sparklinekit/line` and `sparklinekit/bar`,
  returning a `BitArray` of 8-bit RGBA truecolor PNG bytes encoded
  in pure Gleam (no NIF, no `libpng`). Line strokes use Xiaolin Wu
  anti-aliasing; rounded bars carry their corner radius into the
  raster output.
- `sparklinekit/theme` — six bundled colour schemes (`ocean`,
  `forest`, `sunset`, `mono`, `neon`, `pastel`) plus
  `theme.default()`. Apply one with `line.with_theme` /
  `bar.with_theme` or override individual slots with
  `with_color`, `with_background_color`, `with_area_color`, and
  `with_negative_color`.
- `line.with_area_fill` / `line.with_area_color` — paint a tinted
  area under the line, derived from the stroke colour or set
  explicitly.
- `bar.with_corner_radius` and `bar.with_negative_color` —
  rounded bars and a distinct colour for bars below the zero
  baseline.
- `line.with_background_color` / `bar.with_background_color` —
  paint a solid background rectangle behind the chart (`"none"`
  disables it).
- `unicode.render_ints`, `line.new_ints`, `bar.new_ints`,
  `line.with_int_values`, `bar.with_int_values` — `List(Int)`
  variants so callers no longer need to convert with
  `list.map(_, int.to_float)`.
- `line.to_svg` / `bar.to_svg` as the preferred names for the SVG
  renderers; `to_string` is kept as a backwards-compatible alias.
- Internal modules `sparklinekit/internal/color`,
  `sparklinekit/internal/png`, and
  `sparklinekit/internal/raster` covering hex-colour parsing /
  blending, PNG encoding (CRC32 + Adler32 + DEFLATE store
  blocks), and the sparse canvas used by `to_png`.

### Changed

- README rewritten to lead with the elevator pitch and three
  inline samples; the Lustre, oaspec, scope, target, and roadmap
  sections are gone. Targets now sit in a single sentence at the
  end of the document.
- Sample images in `docs/images/` regenerated using the new
  themed renderer (`ocean` for the line chart, `sunset` for the
  positive bars, `forest` with the contrasting negative colour
  for the mixed bars).

## [0.1.0] - 2026-05-19

### Added

- Initial public release.
- `sparklinekit/unicode` — terminal sparklines built from the eight
  Unicode block characters `▁▂▃▄▅▆▇█`. Empty input renders as `""`;
  single-value and all-equal inputs render as a flat line at the
  middle level.
- `sparklinekit/line` — SVG line sparkline builder with `with_color`,
  `with_size`, and `with_stroke_width`. Defaults to a `200x40` viewBox,
  `currentColor` stroke, and `1.5` stroke width. Output carries
  `preserveAspectRatio="none"` so the chart scales to any container.
- `sparklinekit/bar` — SVG bar sparkline builder with `with_color`,
  `with_size`, and `with_bar_gap`. Positive and negative values share
  a zero baseline: positives rise above it, negatives fall below.
- Zero runtime dependencies beyond `gleam_stdlib`. Builds and tests
  pass on both Erlang and JavaScript targets.
- MIT licensed.
