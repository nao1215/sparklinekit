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

const single_value_data: List(Float) = [5.0]

const negative_line_data: List(Float) = [3.0, -2.0, 5.0, -4.0, 6.0, -1.0]

const theme_preview_data: List(Float) = [
  1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0, 11.0, 7.0,
]

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

  let edge_single_line_builder =
    line.new(single_value_data)
    |> line.with_theme(theme.ocean())
    |> line.with_size(480, 120)
    |> line.with_stroke_width(2.8)
    |> line.with_spot(4.0)

  let edge_single_bar_builder =
    bar.new(single_value_data)
    |> bar.with_theme(theme.sunset())
    |> bar.with_size(480, 120)
    |> bar.with_bar_gap(0.0)
    |> bar.with_corner_radius(4.0)

  let edge_negative_line_builder =
    line.new(negative_line_data)
    |> line.with_theme(theme.ocean())
    |> line.with_size(480, 120)
    |> line.with_stroke_width(2.8)
    |> line.with_smoothing(0.2)
    |> line.with_area_fill(True)
    |> line.with_spot(4.0)

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
    simplifile.write(
      out_dir <> "/edge-line-single.svg",
      line.to_svg(edge_single_line_builder),
    )
  let assert Ok(Nil) =
    simplifile.write(
      out_dir <> "/edge-bar-single.svg",
      bar.to_svg(edge_single_bar_builder),
    )
  let assert Ok(Nil) =
    simplifile.write(
      out_dir <> "/edge-line-negative.svg",
      line.to_svg(edge_negative_line_builder),
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
  let assert Ok(Nil) =
    simplifile.write_bits(
      out_dir <> "/edge-line-single.png",
      line.to_png(edge_single_line_builder),
    )
  let assert Ok(Nil) =
    simplifile.write_bits(
      out_dir <> "/edge-bar-single.png",
      bar.to_png(edge_single_bar_builder),
    )
  let assert Ok(Nil) =
    simplifile.write_bits(
      out_dir <> "/edge-line-negative.png",
      line.to_png(edge_negative_line_builder),
    )

  write_theme_preview(out_dir, "ocean", theme.ocean())
  write_theme_preview(out_dir, "forest", theme.forest())
  write_theme_preview(out_dir, "sunset", theme.sunset())
  write_theme_preview(out_dir, "mono", theme.mono())
  write_theme_preview(out_dir, "neon", theme.neon())
  write_theme_preview(out_dir, "pastel", theme.pastel())

  io.println(
    "unicode: "
    <> unicode.render(unicode_data)
    <> " ("
    <> int.to_string(list_length(unicode_data))
    <> " values)",
  )
  io.println(
    "unicode (single value): "
    <> unicode.render(single_value_data),
  )
}

fn write_theme_preview(
  out_dir: String,
  name: String,
  scheme: theme.Theme,
) -> Nil {
  let builder =
    line.new(theme_preview_data)
    |> line.with_theme(scheme)
    |> line.with_size(360, 90)
    |> line.with_stroke_width(2.4)
    |> line.with_smoothing(0.25)
    |> line.with_area_fill(True)
    |> line.with_spot(3.5)
  let assert Ok(Nil) =
    simplifile.write(
      out_dir <> "/theme-" <> name <> ".svg",
      line.to_svg(builder),
    )
  let assert Ok(Nil) =
    simplifile.write_bits(
      out_dir <> "/theme-" <> name <> ".png",
      line.to_png(builder),
    )
  Nil
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
