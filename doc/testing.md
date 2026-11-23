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

`.github/workflows/nightly-property.yml` runs the whole suite ten times with `METAMON_RUNS_MULTIPLIER=10`, each pass with a new seed. A failure report prints its seed, so the case can be replayed with `metamon.with_seed` and kept as a regression test.

## Mutation testing

There is no mutation testing tool for Gleam, so `gleam_mutate.py` (from the mutation-testing lab in nao1215/debimate, with integer comparison and arithmetic operators added) is run by hand on a copy of the project. It rewrites one operator or boolean result at a time (`==`/`!=`, `<`/`<=`, `>`/`>=`, `+`/`-`, `&&`/`||`, `-> True`/`-> False`, a dropped `!`, float comparisons and `-.`) and runs `gleam test` on the Erlang target. The score is killed / (killed + lived).

| Date | Files | Killed | Lived | Score |
|---|---|---:|---:|---:|
| 2026-11-19 | every module under `src/`, with the metamon relations | 32 | 166 | 16.2% |
| 2026-11-19 | the same, plus the full-output snapshots | 110 | 88 | 55.6% |

The first run showed that no test looked at path coordinates or pixels: the attribute-level snapshots and the shape relations pass for almost any change to scaling or rasterisation. `test/sparklinekit/output_snapshot_test.gleam` pins whole SVG documents and every PNG pixel. The remaining survivors, grouped:

- `internal/raster` (40): anti-aliasing and disc arithmetic whose effect stays below one 8-bit colour step at the snapshot sizes, or outside the 24x8 canvases.
- `line` (17) and `bar` (15): clamps of out-of-range options (smoothing, spot radius, sizes, gaps) and the baseline and hairline checks at exactly zero, which no snapshot input reaches.
- `internal/color` (5), `internal/scale` (5), `internal/png` (3), `internal/format` (2): clamps at exactly 0 or 255, the store-block split of images larger than 64 KiB and coordinate clamping of non-finite values.
- `unicode` (1): the upper clamp of the block index, which rounding never exceeds.
