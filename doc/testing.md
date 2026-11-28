# Testing

`just ci` runs everything below except the nightly job and mutation testing. Tests run on the Erlang and JavaScript targets, on the Gleam floor (1.14.0, OTP 27, Node 22) and on the latest Gleam 1.x.

## Examples and unit tests

`test/sparklinekit/line_test.gleam`, `bar_test.gleam`, `png_test.gleam` and `unicode_test.gleam` check each renderer and option with fixed inputs, `color_test.gleam` checks which colours are accepted and that every renderer rejects the same ones, `readme_test.gleam` runs the README examples, and `doc_examples_test.gleam` checks the examples in the doc comments. Each fixed bug keeps its reproduction in `test/sparklinekit/qa/deep_test.gleam`, `deep2_test.gleam` or a `regression_*_test.gleam` file.

## Boundary values

`test/sparklinekit/qa/boundary_test.gleam` covers empty, single-value, all-equal, all-negative, mixed-sign and very large or very small series, and sizes, gaps, stroke widths and smoothing factors at and beyond their limits. `test/sparklinekit/edge_test.gleam` adds values up to the largest Float, Infinity and NaN (made through `edge_ffi.mjs` on JavaScript, the only target that can produce them), sizes of 0, 1 and below, the block level boundaries, and a PNG big enough to need several stored DEFLATE blocks.

## Generated properties

`test/sparklinekit/qa/property_test.gleam` walks a seeded corpus: the Unicode output has one block per value from the eight-block alphabet, SVG output is a well-formed `<svg>` element, PNG output starts with the PNG signature, and no renderer crashes on a finite input.

## Metamorphic relations

- `test/sparklinekit/qa/metamorphic_test.gleam` checks scaling, shifting and reversing a fixed set of series.
- `test/sparklinekit/metamon_metamorphic_test.gleam` checks the same kind of relations with metamon on random series, and on the SVG and PNG output byte for byte: scaling by a positive integer never changes a line or bar picture (with and without theme, area fill, smoothing and spot), shifting never changes a plain line, and values appended inside the observed range never redraw the Unicode blocks already drawn.
- `test/sparklinekit/mirror_metamorphic_test.gleam` checks mirrored inputs with metamon: reversing a series mirrors a line or bar chart left to right, negating it turns a line upside down and turns bars upside down with the two colours swapped, and each PNG bar has the colour of the SVG bar at its centre.

## Differential testing

`test/sparklinekit/qa/differential_test.gleam` compares the Unicode renderer with outputs from an independent Python implementation of the documented algorithm.

## Fuzzing and snapshots

`test/sparklinekit/qa/fuzz_test.gleam` builds colour strings from hex digits, keyword letters and XML-special characters and checks that each one is either an accepted colour or rejected with `InvalidColor`, so nothing else reaches the SVG. `test/sparklinekit/qa/snapshot_test.gleam` pins the attribute-level contract of canonical SVG and PNG output (viewBox, dimensions, theme colours, PNG header). `test/sparklinekit/output_snapshot_test.gleam` pins complete output with birdie: whole SVG documents for plain, styled and signed line and bar sparklines and for a gradient area on both sides of zero, and every pixel of the matching PNGs. PNG output is read back by an independent decoder in the test that recomputes each chunk CRC-32 and the zlib Adler-32 and unpacks the stored DEFLATE blocks into rows of `RRGGBBAA`. Review a changed snapshot with `gleam run -m birdie`; the accepted files live in `test/birdie_snapshots/`.

## Nightly runs

`.github/workflows/nightly-property.yml` runs the whole suite ten times with `METAMON_RUNS_MULTIPLIER=10`, each pass with a new seed. A failure report prints its seed, so the case can be replayed with `metamon.Config(..metamon.default_config(), seed: Some(seed))` and kept as a regression test.

## Coverage

`gleam run -m metamon/mutation -- coverage` (`just coverage`, after `gleam build --target erlang`) runs the tests on the Erlang target with every module under `src/` measured and writes `build/coverage/lcov.info`; `.github/workflows/coverage.yml` reports it with octocov on pull requests and main. On 2026-11-28 it reached 97.2% of lines (594 of 611).

## Mutation testing

`gleam run -m metamon/mutation` changes one operator, `!` or boolean literal in a module under `src/` at a time and runs `gleam test --target erlang` on each change. `.github/workflows/mutation.yml` mutates the modules a pull request or push changes and fails on a survivor that `doc/mutation/baseline.json` does not list; the weekly run mutates every module. `just mutation` runs it locally and `just mutation-record` records the baseline. The score is (killed + timed out) / (killed + timed out + lived).

The first run (2026-11-27) scored 77.7% with 69 survivors. Tests were then added for a zero stroke width, the inset on a canvas smaller than the dot, areas of series whose minimum or maximum is exactly zero, gradient areas above and below zero, a corner radius beyond half the bar width, constant zero bars, a gap that leaves no room for the bars, hairline bars at the edge of the canvas, partly covered pixels and untouched pixels over a transparent background, the edges next to a rounded corner and the rim of a dot off the pixel grid, and the score rose to 85.4%. The 45 survivors left change nothing on Erlang:

- Guards for a case the callers never produce (9): an area or a segment of zero size, a dot of radius zero, a stroke of zero thickness, and a value range whose ends are equal.
- Comparisons whose two sides give the same result at the boundary (13): a pixel exactly on the area baseline, on a dot rim, on a segment end or covered exactly 0 or 1, a zero value or a bar exactly one pixel high, the square root of zero, a fully transparent blend, and a line at exactly 45 degrees.
- Writes the image never shows (7): pixels outside the canvas, which the PNG never reads, and cells past the end of a shape, which have zero coverage.
- Corner sampling (5): no sample point lies exactly on an edge or on the rim of a corner.
- `internal/scale` (7): halving large values is exact in binary floating point, and the NaN check in `finite` cannot fail on Erlang.
- `internal/png` (2): a width or height of exactly 1 is kept as 1 by both branches.
- The right end of the box a dot is drawn in (1): the dot is always a whole number of pixels from the right edge, so the pixels it drops are never covered.
- An unused loop argument in the line rasteriser (1).

<!-- mutation:start -->
| Module | Killed | Lived | Timed out | Score |
|---|---:|---:|---:|---:|
| `sparklinekit` | 119 | 12 | 0 | 90.8% |
| `sparklinekit/internal/color` | 23 | 1 | 0 | 95.8% |
| `sparklinekit/internal/format` | 5 | 0 | 0 | 100.0% |
| `sparklinekit/internal/png` | 9 | 2 | 2 | 84.6% |
| `sparklinekit/internal/raster` | 94 | 22 | 0 | 81.0% |
| `sparklinekit/internal/scale` | 12 | 8 | 0 | 60.0% |
| all | 262 | 45 | 2 | 85.4% |
<!-- mutation:end -->
