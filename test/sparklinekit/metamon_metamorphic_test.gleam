//// Metamorphic relations checked with metamon on random series.
////
//// A sparkline only shows the shape of a series, so transformations that
//// keep the shape must keep the output:
////
//// - Unicode: multiplying by a positive integer and adding an integer
////   never changes the blocks; reversing the series reverses them; values
////   appended inside the observed range never change the blocks already
////   drawn.
//// - SVG and PNG, line and bar: multiplying every value by a positive
////   integer never changes the picture (scaling keeps the zero baseline
////   where it is, so the signed area fill and bars are covered too).
////
//// Inputs are small integers so that scaled values stay exact in floating
//// point and every relation must hold bit for bit.

import gleam/int
import gleam/list
import gleam/string
import metamon
import metamon/generator.{type Generator}
import metamon/generator/range
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme
import sparklinekit/unicode

fn series_gen() -> Generator(List(Int)) {
  generator.list_of(
    generator.int(range.constant(-50, 50)),
    range.constant(0, 24),
  )
}

fn factor_gen() -> Generator(Int) {
  generator.int(range.constant(1, 1000))
}

fn affine(values: List(Int), scale: Int, shift: Int) -> List(Int) {
  list.map(values, fn(v) { v * scale + shift })
}

pub fn unicode_ignores_positive_scale_and_shift_test() -> Nil {
  metamon.forall(
    generator.tuple3(
      series_gen(),
      factor_gen(),
      generator.int(range.constant(-10_000, 10_000)),
    ),
    fn(input) {
      let #(values, scale, shift) = input
      unicode.render_ints(affine(values, scale, shift))
      == unicode.render_ints(values)
    },
  )
}

pub fn unicode_reversing_the_series_reverses_the_blocks_test() -> Nil {
  metamon.forall(series_gen(), fn(values) {
    unicode.render_ints(list.reverse(values))
    == string.reverse(unicode.render_ints(values))
  })
}

pub fn unicode_values_inside_the_range_do_not_redraw_the_prefix_test() -> Nil {
  metamon.forall(
    generator.tuple2(
      series_gen(),
      generator.list_of(
        generator.int(range.constant(0, 100)),
        range.constant(1, 8),
      ),
    ),
    prefix_is_kept,
  )
}

fn line_outputs(values: List(Int), styled: Bool) -> #(String, BitArray) {
  let builder = case styled {
    False -> line.new_ints(values)
    True ->
      line.new_ints(values)
      |> line.with_theme(theme.ocean())
      |> line.with_area_fill(True)
      |> line.with_smoothing(0.3)
      |> line.with_spot(2.0)
  }
  let builder = line.with_size(builder, 60, 16)
  #(line.to_svg(builder), line.to_png(builder))
}

fn bar_outputs(values: List(Int)) -> #(String, BitArray) {
  let builder =
    bar.new_ints(values)
    |> bar.with_theme(theme.sunset())
    |> bar.with_size(60, 16)
  #(bar.to_svg(builder), bar.to_png(builder))
}

pub fn line_ignores_positive_scale_test() -> Nil {
  metamon.forall(
    generator.tuple3(series_gen(), factor_gen(), generator.bool()),
    fn(input) {
      let #(values, scale, styled) = input
      line_outputs(affine(values, scale, 0), styled)
      == line_outputs(values, styled)
    },
  )
}

pub fn bar_ignores_positive_scale_test() -> Nil {
  metamon.forall(generator.tuple2(series_gen(), factor_gen()), fn(input) {
    let #(values, scale) = input
    bar_outputs(affine(values, scale, 0)) == bar_outputs(values)
  })
}

pub fn plain_line_ignores_shift_test() -> Nil {
  // Without the area fill nothing is anchored to zero, so moving the
  // whole series up or down keeps the line where it is.
  metamon.forall(
    generator.tuple2(
      series_gen(),
      generator.int(range.constant(-10_000, 10_000)),
    ),
    fn(input) {
      let #(values, shift) = input
      line_outputs(affine(values, 1, shift), False)
      == line_outputs(values, False)
    },
  )
}

fn prefix_is_kept(input: #(List(Int), List(Int))) -> Bool {
  let #(values, percents) = input
  case list.reduce(values, int.min), list.reduce(values, int.max) {
    Ok(lo), Ok(hi) -> {
      // Points inside [lo, hi].
      let inside = list.map(percents, fn(p) { lo + { hi - lo } * p / 100 })
      let before = unicode.render_ints(values)
      string.starts_with(
        unicode.render_ints(list.append(values, inside)),
        before,
      )
    }
    _, _ -> True
  }
}
