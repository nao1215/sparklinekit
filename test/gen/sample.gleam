//// Standalone generator used to refresh the README example SVGs.
////
////   gleam run --module gen/sample
////
//// Writes three SVGs under `docs/images/` and prints a one-line summary
//// of the Unicode example to stdout. The renderer never touches the
//// network or runs at test time.

import gleam/int
import gleam/io
import simplifile
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/unicode

const line_data: List(Float) = [
  1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0, 11.0, 7.0, 13.0,
]

const bar_data: List(Float) = [3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0]

const mixed_bar_data: List(Float) = [3.0, -2.0, 5.0, -4.0, 6.0, -1.0]

const unicode_data: List(Float) = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]

pub fn main() -> Nil {
  let out_dir = "docs/images"
  let line_svg =
    line.new(line_data)
    |> line.with_color("#378ADD")
    |> line.with_size(240, 60)
    |> line.with_stroke_width(2.0)
    |> line.to_string
  let bar_svg =
    bar.new(bar_data)
    |> bar.with_color("#7F77DD")
    |> bar.with_size(240, 60)
    |> bar.with_bar_gap(3.0)
    |> bar.to_string
  let mixed_bar_svg =
    bar.new(mixed_bar_data)
    |> bar.with_color("#DD7755")
    |> bar.with_size(240, 60)
    |> bar.with_bar_gap(4.0)
    |> bar.to_string
  let assert Ok(Nil) =
    simplifile.write(out_dir <> "/sparkline-line.svg", line_svg)
  let assert Ok(Nil) =
    simplifile.write(out_dir <> "/sparkline-bar.svg", bar_svg)
  let assert Ok(Nil) =
    simplifile.write(out_dir <> "/sparkline-mixed-bar.svg", mixed_bar_svg)
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
