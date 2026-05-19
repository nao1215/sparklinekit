//// Standalone generator used to refresh the README example assets.
////
////   gleam run --module gen/sample
////
//// Writes themed SVG and PNG copies of three sample charts under
//// `docs/images/` and prints a one-line summary of the Unicode
//// example to stdout. The renderer never touches the network or
//// runs at test time.

import gleam/int
import gleam/io
import simplifile
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme
import sparklinekit/unicode

const line_data: List(Float) = [
  1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0, 11.0, 7.0, 13.0,
]

const bar_data: List(Float) = [3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0]

const mixed_bar_data: List(Float) = [3.0, -2.0, 5.0, -4.0, 6.0, -1.0]

const unicode_data: List(Float) = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]

pub fn main() -> Nil {
  let out_dir = "docs/images"

  let line_builder =
    line.new(line_data)
    |> line.with_theme(theme.ocean())
    |> line.with_size(480, 120)
    |> line.with_stroke_width(2.8)
    |> line.with_smoothing(0.28)
    |> line.with_area_fill(True)
    |> line.with_spot(4.0)

  let bar_builder =
    bar.new(bar_data)
    |> bar.with_theme(theme.sunset())
    |> bar.with_size(480, 120)
    |> bar.with_bar_gap(6.0)
    |> bar.with_corner_radius(4.0)

  let mixed_bar_builder =
    bar.new(mixed_bar_data)
    |> bar.with_theme(theme.forest())
    |> bar.with_size(480, 120)
    |> bar.with_bar_gap(8.0)
    |> bar.with_corner_radius(4.0)

  let assert Ok(Nil) =
    simplifile.write(
      out_dir <> "/sparkline-line.svg",
      line.to_svg(line_builder),
    )
  let assert Ok(Nil) =
    simplifile.write(out_dir <> "/sparkline-bar.svg", bar.to_svg(bar_builder))
  let assert Ok(Nil) =
    simplifile.write(
      out_dir <> "/sparkline-mixed-bar.svg",
      bar.to_svg(mixed_bar_builder),
    )

  let assert Ok(Nil) =
    simplifile.write_bits(
      out_dir <> "/sparkline-line.png",
      line.to_png(line_builder),
    )
  let assert Ok(Nil) =
    simplifile.write_bits(
      out_dir <> "/sparkline-bar.png",
      bar.to_png(bar_builder),
    )
  let assert Ok(Nil) =
    simplifile.write_bits(
      out_dir <> "/sparkline-mixed-bar.png",
      bar.to_png(mixed_bar_builder),
    )

  io.println(
    "unicode: "
    <> unicode.render(unicode_data)
    <> " ("
    <> int.to_string(list_length(unicode_data))
    <> " values)",
  )
}

fn list_length(values: List(Float)) -> Int {
  do_length(values, 0)
}

fn do_length(values: List(Float), acc: Int) -> Int {
  case values {
    [] -> acc
    [_, ..rest] -> do_length(rest, acc + 1)
  }
}
