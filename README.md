# sparklinekit

[![Package Version](https://img.shields.io/hexpm/v/sparklinekit)](https://hex.pm/packages/sparklinekit)
[![Downloads](https://img.shields.io/hexpm/dt/sparklinekit)](https://hex.pm/packages/sparklinekit)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/sparklinekit/)
[![CI](https://github.com/nao1215/sparklinekit/actions/workflows/ci.yml/badge.svg)](https://github.com/nao1215/sparklinekit/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/nao1215/sparklinekit)](LICENSE)

Sparkline generator for Gleam: small, axis-less, label-less inline
charts that show the shape of a data series at a glance. Outputs
Unicode block characters for terminal use and raw SVG strings for the
browser. Zero runtime dependencies, runs on both the Erlang and
JavaScript targets.

![Line sparkline example](docs/images/sparkline-line.png)

![Bar sparkline example](docs/images/sparkline-bar.png)

![Mixed positive/negative bar sparkline example](docs/images/sparkline-mixed-bar.png)

```sh
gleam add sparklinekit
```

## Hello, sparkline

The shortest path: render a value series to the terminal.

```gleam
import gleam/io
import sparklinekit/unicode

pub fn main() {
  io.println(unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]))
  // -> "▁▂█▅▂▁▃"
}
```

The eight Unicode block characters `▁▂▃▄▅▆▇█` partition the value
range into eight equal levels. `[]` renders as `""`. A single value,
or a series of equal values, renders as a flat line at the middle
level (`▄`).

## SVG line sparkline

```gleam
import sparklinekit/line

pub fn small_chart() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.to_string
}
```

Defaults give you a `200x40` viewBox, a `currentColor` stroke (so the
chart picks up the surrounding CSS colour), and a `1.5` stroke
width. Tune them with the builder before calling `to_string`:

```gleam
import sparklinekit/line

pub fn styled_chart() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_color("#378ADD")
  |> line.with_size(120, 30)
  |> line.with_stroke_width(2.0)
  |> line.to_string
}
```

The output is a self-contained `<svg>` element. It carries
`preserveAspectRatio="none"` so it scales cleanly inside any
container.

## SVG bar sparkline

```gleam
import sparklinekit/bar

pub fn revenue() -> String {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0])
  |> bar.with_color("#7F77DD")
  |> bar.with_size(160, 40)
  |> bar.to_string
}
```

Bars share a zero baseline. All-positive input collapses the baseline
onto the bottom of the box. Mixed positive/negative input splits the
bars: positives rise above the zero line, negatives fall below.

```gleam
import sparklinekit/bar

pub fn winloss() -> String {
  bar.new([3.0, -2.0, 5.0, -4.0, 6.0, -1.0])
  |> bar.with_color("#DD7755")
  |> bar.with_size(180, 50)
  |> bar.with_bar_gap(3.0)
  |> bar.to_string
}
```

## Lustre / HTML integration

`sparklinekit` does not depend on Lustre. Embed the SVG output via
any unsafe-HTML helper your view layer provides — the exact name has
changed across Lustre versions, so consult the Lustre docs for the
current API. The key idea is that `to_string` returns a complete SVG
element string which can be inlined as raw HTML.

```gleam
import lustre/element
import sparklinekit/line

pub fn metric_svg(values: List(Float)) -> String {
  line.new(values)
  |> line.with_color("#378ADD")
  |> line.with_size(120, 30)
  |> line.with_stroke_width(2.0)
  |> line.to_string
}

// Inline `metric_svg(values)` into a view via Lustre's
// `element.unsafe_raw_html` (or your version's equivalent).
```

## CLI integration

`unicode.render` is one line away from a status-bar chart in any
Gleam CLI:

```gleam
import gleam/io
import sparklinekit/unicode

pub fn print_latency(samples: List(Float)) -> Nil {
  io.println("latency  " <> unicode.render(samples))
  // latency  ▁▂▃▄▅▆▇█
}
```

The output is plain UTF-8 — no escape codes, no terminal-mode
assumptions — so it composes cleanly with any logging or table
output.

## Edge cases

- Empty input renders as `""` (Unicode) or a minimal `<svg>` with no
  polyline / rect children (SVG).
- A single value renders as a flat line at the middle level: `▄` for
  Unicode, and a midpoint horizontal segment for SVG.
- All-equal values render as a flat line at the middle level.
- Negative values are supported. Unicode and SVG line normalise
  against the observed `[min, max]` range. SVG bar uses a zero
  baseline so positives and negatives are visually separated.
- `with_color` accepts any CSS colour string. The value is
  attribute-escaped before being written into the SVG, so a hostile
  colour cannot break out of `stroke="..."` or `fill="..."`. The
  surrounding `<svg>` document is not a sanitiser — when embedding
  the output into arbitrary HTML, pass it through a sanitiser such
  as DOMPurify on that boundary.

## Targets

Both the Erlang and JavaScript targets are exercised in CI on every
push. Pure-Gleam internals mean no NIF / native binary is needed —
`sparklinekit` runs anywhere Gleam runs.

Full API reference: <https://hexdocs.pm/sparklinekit/>.

## Roadmap

`0.1.0` is the floor. Likely candidates for future minor releases,
ranked by how often they came up while shaping the API:

- Area fill under the line (`with_area_color`).
- Win/loss bars — two-colour positive/negative bar variant.
- Reference lines / thresholds (e.g. SLO target overlay).
- Optional smoothing (Catmull-Rom or bezier) for the line renderer.
- Custom Unicode character sets (dots, Braille) for terminals where
  the block characters render at odd heights.

PNG output is intentionally **out of scope** for this package. A
companion `sparklinekit_png` will ship that separately, the same way
`oaspec_httpc` / `oaspec_fetch` split out from `oaspec`. Keeping the
core dependency-free is the point.

## Scope and non-goals

- `sparklinekit` is a **renderer**, not a chart library. Axes,
  legends, tooltips, animation, and interactivity are out of scope.
- The caller owns data preparation. `sparklinekit` does not
  log-scale, percentile-clip, or otherwise normalise inputs —
  whatever you pass in is what gets rendered.
- NaN / infinity are out of scope. Callers must provide finite
  floats; behaviour is undefined otherwise.
- Inputs are `List(Float)`. `Int` overloads may be added in a future
  minor release; for now, callers convert via `int.to_float`.

## License

[MIT](LICENSE)
