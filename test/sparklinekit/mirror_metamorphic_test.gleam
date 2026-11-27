//// Metamorphic relations between mirrored inputs and outputs, checked
//// with metamon on random series:
////
//// - Reversing the series mirrors a line chart and a bar chart left to
////   right.
//// - Negating the series turns a line chart upside down, and turns a bar
////   chart upside down with the positive and negative colours swapped.
//// - A PNG bar chart has the colour of each SVG bar at the centre of the
////   bar, and each pixel is covered by the same share of the SVG bars as
////   a browser draws at 100% zoom.
////
//// SVG coordinates are written with two decimals, so mirrored coordinates
//// are compared to within 0.02.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string
import metamon
import metamon/generator.{type Generator}
import metamon/generator/range
import render
import sparklinekit
import sparklinekit/output_snapshot_test

const width = 61

const height = 17

fn series_gen() -> Generator(List(Int)) {
  generator.list_of(
    generator.int(range.constant(-50, 50)),
    range.constant(1, 20),
  )
}

fn nonzero_series_gen() -> Generator(List(Int)) {
  generator.list_of(generator.int(range.constant(1, 50)), range.constant(1, 20))
  |> generator.map(fn(values) {
    list.index_map(values, fn(v, i) {
      case i % 3 {
        0 -> 0 - v
        _ -> v
      }
    })
  })
}

fn floats(values: List(Int)) -> List(Float) {
  list.map(values, int.to_float)
}

fn line_options(smoothing: Float) -> sparklinekit.LineOptions {
  sparklinekit.LineOptions(
    ..sparklinekit.default_line_options,
    width:,
    height:,
    theme: sparklinekit.ocean,
    smoothing:,
  )
}

fn bar_options(gap: Float) -> sparklinekit.BarOptions {
  sparklinekit.BarOptions(
    ..sparklinekit.default_bar_options,
    width:,
    height:,
    theme: sparklinekit.Theme(
      foreground: "#112233",
      background: "none",
      area: None,
      negative: "#aa0000",
    ),
    gap:,
  )
}

// The numbers of the `d` attribute of the stroke, as #(x, y) pairs.
fn stroke_points(svg: String) -> List(#(Float, Float)) {
  let assert Ok(#(_, after)) = string.split_once(svg, "<path fill=\"none\"")
  let assert Ok(#(_, after)) = string.split_once(after, " d=\"")
  let assert Ok(#(d, _)) = string.split_once(after, "\"")
  d
  |> string.replace(",", " ")
  |> string.split(" ")
  |> list.filter_map(parse_number)
  |> pairs
}

fn pairs(numbers: List(Float)) -> List(#(Float, Float)) {
  case numbers {
    [x, y, ..rest] -> [#(x, y), ..pairs(rest)]
    _ -> []
  }
}

fn parse_number(text: String) -> Result(Float, Nil) {
  case float.parse(text) {
    Ok(value) -> Ok(value)
    Error(_) -> int.parse(text) |> result_to_float
  }
}

fn result_to_float(result: Result(Int, Nil)) -> Result(Float, Nil) {
  case result {
    Ok(value) -> Ok(int.to_float(value))
    Error(_) -> Error(Nil)
  }
}

type Bar {
  Bar(x: Float, y: Float, width: Float, height: Float, fill: String)
}

fn bars(svg: String) -> List(Bar) {
  string.split(svg, "<rect x=\"")
  |> list.drop(1)
  |> list.map(fn(rect) {
    let assert [x, y, w, h, ..] =
      string.split(rect, "\"")
      |> list.index_fold([], fn(acc, part, i) {
        case i % 2 {
          0 ->
            case parse_number(part) {
              Ok(value) -> [value, ..acc]
              Error(_) -> acc
            }
          _ -> acc
        }
      })
      |> list.reverse
    let assert Ok(#(_, after)) = string.split_once(rect, "fill=\"")
    let assert Ok(#(fill, _)) = string.split_once(after, "\"")
    Bar(x:, y:, width: w, height: h, fill:)
  })
}

fn close(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. 0.02
}

fn same_points(a: List(#(Float, Float)), b: List(#(Float, Float))) -> Bool {
  list.length(a) == list.length(b)
  && list.all(list.zip(a, b), fn(pair) {
    close(pair.0.0, pair.1.0) && close(pair.0.1, pair.1.1)
  })
}

fn same_bars(a: List(Bar), b: List(Bar)) -> Bool {
  list.length(a) == list.length(b)
  && list.all(list.zip(a, b), fn(pair) {
    let #(p, q) = pair
    close(p.x, q.x)
    && close(p.y, q.y)
    && close(p.width, q.width)
    && close(p.height, q.height)
    && p.fill == q.fill
  })
}

pub fn reversing_mirrors_the_line_test() -> Nil {
  metamon.forall(generator.tuple2(series_gen(), generator.bool()), fn(input) {
    let #(values, smooth) = input
    let options =
      line_options(case smooth {
        True -> 0.3
        False -> 0.0
      })
    let forward = stroke_points(render.line_svg(floats(values), options))
    let backward =
      stroke_points(render.line_svg(floats(list.reverse(values)), options))
    let mirrored =
      forward
      |> list.map(fn(p) { #(int.to_float(width) -. p.0, p.1) })
      |> list.reverse
    same_points(backward, mirrored)
  })
}

pub fn negating_turns_the_line_upside_down_test() -> Nil {
  metamon.forall(series_gen(), fn(values) {
    let options = line_options(0.0)
    let up = stroke_points(render.line_svg(floats(values), options))
    let down =
      stroke_points(render.line_svg(
        floats(list.map(values, fn(v) { 0 - v })),
        options,
      ))
    same_points(
      down,
      list.map(up, fn(p) { #(p.0, int.to_float(height) -. p.1) }),
    )
  })
}

// Bars kept their gap on the right, so the first bar touched the left
// edge and the last one stopped a gap short of the right edge.
pub fn reversing_mirrors_the_bars_test() -> Nil {
  metamon.forall(
    generator.tuple2(series_gen(), generator.int(range.constant(0, 4))),
    fn(input) {
      let #(values, gap) = input
      let options = bar_options(int.to_float(gap))
      let forward = bars(render.bar_svg(floats(values), options))
      let backward = bars(render.bar_svg(floats(list.reverse(values)), options))
      let mirrored =
        forward
        |> list.map(fn(bar) {
          Bar(..bar, x: int.to_float(width) -. bar.x -. bar.width)
        })
        |> list.reverse
      same_bars(backward, mirrored)
    },
  )
}

pub fn negating_turns_the_bars_upside_down_test() -> Nil {
  metamon.forall(nonzero_series_gen(), fn(values) {
    let options = bar_options(1.0)
    let up = bars(render.bar_svg(floats(values), options))
    let down =
      bars(render.bar_svg(floats(list.map(values, fn(v) { 0 - v })), options))
    let flipped =
      list.map(up, fn(bar) {
        Bar(
          ..bar,
          y: int.to_float(height) -. bar.y -. bar.height,
          fill: case bar.fill {
            "#112233" -> "#aa0000"
            _ -> "#112233"
          },
        )
      })
    same_bars(down, flipped)
  })
}

pub fn png_bars_have_the_svg_colour_at_their_centre_test() -> Nil {
  metamon.forall(series_gen(), fn(values) {
    let options = bar_options(1.0)
    let svg_bars = bars(render.bar_svg(floats(values), options))
    let rows =
      render.bar_png(floats(values), options)
      |> output_snapshot_test.pixels
      |> string.split("\n")
      |> list.map(string.split(_, " "))
    list.all(svg_bars, fn(bar) {
      let x = float.truncate(bar.x +. bar.width /. 2.0)
      let y = float.truncate(bar.y +. bar.height /. 2.0)
      let pixel = rows |> list.drop(y) |> list.first |> pixel_at(x)
      bar.width <. 2.0
      || bar.height <. 2.0
      || pixel == string.uppercase(string.drop_start(bar.fill, 1)) <> "FF"
    })
  })
}

fn pixel_at(row: Result(List(String), Nil), x: Int) -> String {
  case row {
    Ok(row) ->
      case list.drop(row, x) {
        [pixel, ..] -> pixel
        [] -> ""
      }
    Error(_) -> ""
  }
}

fn coverage_options(width: Int, gap: Float) -> sparklinekit.BarOptions {
  sparklinekit.BarOptions(..bar_options(gap), width:)
}

// The share of the pixel `[cell, cell + 1]` that `[from, to]` covers.
fn overlap(cell: Int, from: Float, to: Float) -> Float {
  let cell = int.to_float(cell)
  float.max(float.min(cell +. 1.0, to) -. float.max(cell, from), 0.0)
}

// The alpha byte of every pixel, row by row.
fn png_alphas(png: BitArray) -> List(List(Int)) {
  output_snapshot_test.pixels(png)
  |> string.split("\n")
  |> list.map(fn(row) {
    string.split(row, " ")
    |> list.map(fn(pixel) {
      case int.base_parse(string.drop_start(pixel, 6), 16) {
        Ok(alpha) -> alpha
        Error(_) -> -1
      }
    })
  })
}

// The alpha byte a browser gives each pixel for these SVG bars drawn over
// nothing: the area of the pixel the bars cover.
fn svg_alphas(svg_bars: List(Bar), width: Int) -> List(List(Int)) {
  use row <- list.map(int_range(0, height))
  use column <- list.map(int_range(0, width))
  let covered =
    list.fold(svg_bars, 0.0, fn(sum, bar) {
      sum
      +. overlap(column, bar.x, bar.x +. bar.width)
      *. overlap(row, bar.y, bar.y +. bar.height)
    })
  float.round(float.min(covered, 1.0) *. 255.0)
}

fn int_range(from: Int, to: Int) -> List(Int) {
  int.range(from:, to:, with: [], run: fn(acc, value) { [value, ..acc] })
  |> list.reverse
}

fn same_alphas(png: List(List(Int)), svg: List(List(Int))) -> Bool {
  list.length(png) == list.length(svg)
  && list.all(list.zip(png, svg), fn(rows) {
    list.length(rows.0) == list.length(rows.1)
    && list.all(list.zip(rows.0, rows.1), fn(pair) {
      // The SVG coordinates are rounded to two decimals, so an edge read
      // back from them can be up to 0.01 pixel off in each direction.
      int.absolute_value(pair.0 - pair.1) <= 6
    })
  })
}

// Bars are at least a pixel apart, so no pixel is shared by two bars, and
// each share of the width is a whole number of pixels or a fraction of
// one, so bar edges fall on whole pixels, half pixels and elsewhere.
pub fn png_bars_cover_the_pixels_the_svg_bars_cover_test() -> Nil {
  metamon.forall(
    generator.tuple4(
      series_gen(),
      generator.int(range.constant(4, 8)),
      generator.int(range.constant(0, 19)),
      generator.int(range.constant(1, 3)),
    ),
    fn(input) {
      let #(values, share, extra, gap) = input
      let width = list.length(values) * share + extra
      let options = coverage_options(width, int.to_float(gap))
      let svg = bars(render.bar_svg(floats(values), options))
      same_alphas(
        png_alphas(render.bar_png(floats(values), options)),
        svg_alphas(svg, width),
      )
    },
  )
}

// Two 19-pixel bars in a 40-pixel chart with a gap of 1 have every edge on
// a half pixel: 0.5 to 19.5 and 20.5 to 39.5.
pub fn png_bar_edges_on_half_pixels_test() {
  let assert [row, ..] =
    render.bar_png([5.0, 5.0], coverage_options(40, 1.0))
    |> png_alphas
    |> list.drop(height - 1)
  let half = 128
  let bar = [half, ..list.repeat(255, 18)]
  assert row == list.flatten([bar, [half], bar, [half]])
}
