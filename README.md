# sparklinekit

[![Package Version](https://img.shields.io/hexpm/v/sparklinekit)](https://hex.pm/packages/sparklinekit)
[![Downloads](https://img.shields.io/hexpm/dt/sparklinekit)](https://hex.pm/packages/sparklinekit)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/sparklinekit/)
[![CI](https://github.com/nao1215/sparklinekit/actions/workflows/ci.yml/badge.svg)](https://github.com/nao1215/sparklinekit/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/nao1215/sparklinekit)](LICENSE)

Sparkline generator for Gleam. Unicode block characters for the
terminal, SVG strings for the browser, PNG byte arrays for
everything else. Pure Gleam, zero runtime dependencies, runs on
both the Erlang and JavaScript targets.

![Line sparkline example](docs/images/sparkline-line.png)

![Bar sparkline example](docs/images/sparkline-bar.png)

![Mixed positive/negative bar sparkline example](docs/images/sparkline-mixed-bar.png)

## Install

```sh
gleam add sparklinekit
```

## Unicode block sparkline

```gleam
import sparklinekit/unicode

pub fn shape() -> String {
  unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
  // -> "▁▂█▅▂▁▃"
}
```

```gleam
import sparklinekit/unicode

pub fn shape_from_ints() -> String {
  unicode.render_ints([1, 5, 22, 13, 5, 2, 7])
  // -> "▁▂█▅▂▁▃"
}
```

```gleam
import gleam/io
import sparklinekit/unicode

pub fn print_latency(samples: List(Float)) -> Nil {
  io.println("latency  " <> unicode.render(samples))
}
```

## SVG line

```gleam
import sparklinekit/line

pub fn minimal_line() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.to_svg
}
```

```gleam
import sparklinekit/line
import sparklinekit/theme

pub fn themed_line() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_theme(theme.ocean())
  |> line.to_svg
}
```

```gleam
import sparklinekit/line
import sparklinekit/theme

pub fn smooth_line() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0])
  |> line.with_theme(theme.ocean())
  |> line.with_smoothing(0.25)
  |> line.to_svg
}
```

```gleam
import sparklinekit/line
import sparklinekit/theme

pub fn area_line() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0])
  |> line.with_theme(theme.ocean())
  |> line.with_smoothing(0.25)
  |> line.with_area_fill(True)
  |> line.with_spot(3.0)
  |> line.to_svg
}
```

```gleam
import sparklinekit/line

pub fn raw_colour_line() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_color("#378ADD")
  |> line.with_size(240, 60)
  |> line.with_stroke_width(2.0)
  |> line.to_svg
}
```

```gleam
import sparklinekit/line
import sparklinekit/theme

pub fn line_with_ints() -> String {
  line.new_ints([1, 5, 3, 8, 4])
  |> line.with_theme(theme.forest())
  |> line.to_svg
}
```

## SVG bar

```gleam
import sparklinekit/bar

pub fn minimal_bar() -> String {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0])
  |> bar.to_svg
}
```

```gleam
import sparklinekit/bar
import sparklinekit/theme

pub fn rounded_bar() -> String {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0])
  |> bar.with_theme(theme.sunset())
  |> bar.with_corner_radius(3.0)
  |> bar.with_bar_gap(4.0)
  |> bar.to_svg
}
```

```gleam
import sparklinekit/bar

pub fn win_loss() -> String {
  bar.new([3.0, -2.0, 5.0, -4.0, 6.0, -1.0])
  |> bar.with_color("#22A06B")
  |> bar.with_negative_color("#E5484D")
  |> bar.with_bar_gap(3.0)
  |> bar.to_svg
}
```

```gleam
import sparklinekit/bar
import sparklinekit/theme

pub fn themed_win_loss() -> String {
  bar.new_ints([3, -2, 5, -4, 6, -1])
  |> bar.with_theme(theme.forest())
  |> bar.with_corner_radius(3.0)
  |> bar.to_svg
}
```

## PNG output

```gleam
import sparklinekit/line

pub fn line_png() -> BitArray {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_color("#378ADD")
  |> line.with_size(240, 60)
  |> line.with_smoothing(0.25)
  |> line.with_area_fill(True)
  |> line.to_png
}
```

```gleam
import sparklinekit/bar
import sparklinekit/theme

pub fn bar_png() -> BitArray {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0])
  |> bar.with_theme(theme.sunset())
  |> bar.with_corner_radius(3.0)
  |> bar.to_png
}
```

```gleam
import simplifile
import sparklinekit/line

pub fn save_to_disk() {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.to_png
  |> simplifile.write_bits(to: "chart.png", bits: _)
}
```

## Themes

```gleam
import sparklinekit/line
import sparklinekit/theme

pub fn theme_gallery() -> List(String) {
  let values = [1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0]
  let render = fn(t) {
    line.new(values)
    |> line.with_theme(t)
    |> line.with_area_fill(True)
    |> line.to_svg
  }
  [
    render(theme.ocean()),
    render(theme.forest()),
    render(theme.sunset()),
    render(theme.mono()),
    render(theme.neon()),
    render(theme.pastel()),
  ]
}
```

## Edge cases

- `[]` renders as `""` (Unicode), an empty `<svg>` (SVG), or a
  blank-canvas PNG.
- A single value renders as a flat segment at the midpoint.
- All-equal values render as a flat segment at the midpoint.
- Negative values are supported. Line and Unicode renderers
  normalise against the observed `[min, max]`; bar uses a zero
  baseline.
- `with_color` accepts any CSS colour string. SVG attributes are
  escaped; PNG accepts `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa` and
  falls back to the theme default otherwise.
- The surrounding `<svg>` is not a sanitiser. Pass the output
  through DOMPurify (or equivalent) when embedding into arbitrary
  HTML.

Both the Erlang and JavaScript targets are exercised in CI on every
push. Full API reference at <https://hexdocs.pm/sparklinekit/>.

## License

[MIT](LICENSE)
