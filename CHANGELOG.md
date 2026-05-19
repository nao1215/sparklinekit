# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
starting with `1.0.0`. Pre-1.0 releases may break API in minor versions.

## Unreleased

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
