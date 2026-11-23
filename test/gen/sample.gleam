//// Writes the README images under `docs/images/`:
////
////   gleam run --module gen/sample

import gleam/list
import gleam/option.{None}
import simplifile
import sparklinekit.{
  type BarOptions, type LineOptions, type Theme, BarOptions, LineOptions,
}

const out_dir = "docs/images"

pub fn main() -> Nil {
  let line =
    LineOptions(
      ..sparklinekit.default_line_options,
      width: 480,
      height: 120,
      theme: sparklinekit.ocean,
      stroke_width: 2.8,
      smoothing: 0.28,
      area: sparklinekit.GradientArea,
      spot_radius: 4.0,
    )
  let bar =
    BarOptions(
      width: 480,
      height: 120,
      theme: sparklinekit.amber,
      gap: 6.0,
      corner_radius: 4.0,
    )
  write_line(
    "sparkline-line",
    [1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0, 11.0, 7.0, 13.0],
    line,
  )
  write_bar("sparkline-bar", [3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0], bar)
  write_bar(
    "sparkline-mixed-bar",
    [3.0, -2.0, 5.0, -4.0, 6.0, -1.0],
    BarOptions(..bar, theme: sparklinekit.forest, gap: 8.0),
  )
  [
    #("ocean", sparklinekit.ocean),
    #("forest", sparklinekit.forest),
    #("sunset", sparklinekit.sunset),
    #("mono", sparklinekit.mono),
    #("neon", sparklinekit.neon),
    #("pastel", sparklinekit.pastel),
    #("crimson", sparklinekit.crimson),
    #("slate", sparklinekit.slate),
    #("amber", sparklinekit.amber),
    #("midnight", sparklinekit.midnight),
  ]
  |> list.each(fn(pair) { write_theme_preview(pair.0, pair.1) })
}

fn write_theme_preview(name: String, theme: Theme) -> Nil {
  write_line(
    "theme-" <> name,
    [1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0, 11.0, 7.0],
    LineOptions(
      width: 360,
      height: 90,
      theme:,
      stroke_width: 2.4,
      smoothing: 0.25,
      area: sparklinekit.GradientArea,
      spot_radius: 3.5,
      spot_color: None,
    ),
  )
}

fn write_line(name: String, values: List(Float), options: LineOptions) -> Nil {
  let path = out_dir <> "/" <> name
  let assert Ok(Nil) =
    simplifile.write(path <> ".svg", sparklinekit.line_svg(values, options))
  let assert Ok(Nil) =
    simplifile.write_bits(
      path <> ".png",
      sparklinekit.line_png(values, options),
    )
  Nil
}

fn write_bar(name: String, values: List(Float), options: BarOptions) -> Nil {
  let path = out_dir <> "/" <> name
  let assert Ok(Nil) =
    simplifile.write(path <> ".svg", sparklinekit.bar_svg(values, options))
  let assert Ok(Nil) =
    simplifile.write_bits(path <> ".png", sparklinekit.bar_png(values, options))
  Nil
}
