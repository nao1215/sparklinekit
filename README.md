# sparklinekit

[![Package Version](https://img.shields.io/hexpm/v/sparklinekit)](https://hex.pm/packages/sparklinekit)
[![Downloads](https://img.shields.io/hexpm/dt/sparklinekit)](https://hex.pm/packages/sparklinekit)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/sparklinekit/)
[![CI](https://github.com/nao1215/sparklinekit/actions/workflows/ci.yml/badge.svg)](https://github.com/nao1215/sparklinekit/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/nao1215/sparklinekit)](LICENSE)

Sparkline generator for Gleam: small, axis-less, label-less inline
charts that show the shape of a data series at a glance. Outputs
Unicode block characters for terminals, SVG strings for the browser,
and PNG byte arrays for everything else. Pure Gleam, zero runtime
dependencies, runs on both the Erlang and JavaScript targets.

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

`unicode.render_ints` accepts `List(Int)` directly, and the SVG and
PNG builders below have matching `new_ints` constructors so callers
do not need to convert `Int -> Float` themselves.

## SVG line sparkline

```gleam
import sparklinekit/line

pub fn small_chart() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.to_svg
}
```

Defaults give you a `200x40` viewBox, a `currentColor` stroke (so the
chart picks up the surrounding CSS colour), and a `1.5` stroke
width. Tune the builder before calling `to_svg`:

```gleam
import sparklinekit/line
import sparklinekit/theme

pub fn styled_chart() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_theme(theme.ocean())
  |> line.with_size(240, 60)
  |> line.with_stroke_width(2.0)
  |> line.with_smoothing(0.25)
  |> line.with_area_fill(True)
  |> line.with_spot(3.0)
  |> line.to_svg
}
```

`with_theme` applies a named colour scheme (`ocean`, `forest`,
`sunset`, `mono`, `neon`, `pastel`); `with_color` /
`with_background_color` / `with_area_color` override individual
slots. `with_smoothing(factor)` turns the polyline into a cubic
Bézier curve (`0.0` keeps sharp corners, `0.25` matches the default
in `react-sparklines`, `0.5` is the roundest reasonable setting).
`with_area_fill(True)` shades the area below the line; the fill
fades to transparent by default — call `with_gradient_area(False)`
for a flat tint. `with_spot(radius)` drops a filled circle on the
last data point (handy as a "today" marker); `with_spot_color`
overrides its colour.

## SVG bar sparkline

```gleam
import sparklinekit/bar
import sparklinekit/theme

pub fn revenue() -> String {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0])
  |> bar.with_theme(theme.sunset())
  |> bar.with_size(160, 40)
  |> bar.with_corner_radius(2.0)
  |> bar.to_svg
}
```

Bars share a zero baseline. All-positive input collapses the
baseline onto the bottom of the box. Mixed positive/negative input
splits the bars, and `with_negative_color` paints the falling bars
in a contrasting colour:

```gleam
import sparklinekit/bar

pub fn winloss() -> String {
  bar.new([3.0, -2.0, 5.0, -4.0, 6.0, -1.0])
  |> bar.with_color("#22A06B")
  |> bar.with_negative_color("#E5484D")
  |> bar.with_size(180, 50)
  |> bar.with_bar_gap(3.0)
  |> bar.to_svg
}
```

## PNG output

`to_png` returns the same chart as raw PNG bytes (`BitArray`) for
saving to disk, embedding in markdown, or attaching to a Slack
message. The renderer is pure Gleam — no NIF, no `libpng`:

```gleam
import sparklinekit/line
import simplifile

pub fn save_chart() {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_color("#378ADD")
  |> line.with_size(240, 60)
  |> line.with_stroke_width(2.0)
  |> line.to_png
  |> simplifile.write_bits("chart.png", _)
}
```

The PNG encoder writes 8-bit RGBA truecolor with an uncompressed
DEFLATE payload, so the output is wider than a `pngcrush` result but
never requires anti-virus to fight with anti-aliasing of a missing
zlib NIF.

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

- Empty input renders as `""` (Unicode), a minimal `<svg>` with no
  child elements (SVG), or a 1x1 transparent pixel (PNG).
- A single value renders as a flat line at the middle level: `▄` for
  Unicode, a midpoint horizontal segment for SVG line, a full-width
  centred bar for SVG bar, and the matching pixels for PNG.
- All-equal values render as a flat line at the middle level.
- Negative values are supported. Unicode and line renderers
  normalise against the observed `[min, max]` range. Bar uses a zero
  baseline so positives and negatives are visually separated.
- `with_color` accepts any CSS colour string. The value is
  attribute-escaped before being written into the SVG so a hostile
  colour cannot break out of `stroke="..."` / `fill="..."`. For PNG
  the parser accepts `#RGB`, `#RGBA`, `#RRGGBB`, and `#RRGGBBAA`
  hexadecimal; unparseable inputs fall back to the theme default.
- The surrounding `<svg>` document is not a sanitiser — when
  embedding the output into arbitrary HTML, pass it through a
  sanitiser such as DOMPurify on that boundary.

## Scope and non-goals

- `sparklinekit` is a **renderer**, not a chart library. Axes,
  legends, tooltips, animation, and interactivity are out of scope.
- The caller owns data preparation. `sparklinekit` does not
  log-scale, percentile-clip, or otherwise normalise inputs —
  whatever you pass in is what gets rendered.
- NaN / infinity are out of scope. Callers must provide finite
  numeric values; behaviour is undefined otherwise.

Both the Erlang and JavaScript targets are exercised in CI on every
push. Full API reference: <https://hexdocs.pm/sparklinekit/>.

## License

[MIT](LICENSE)
