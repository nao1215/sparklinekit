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
import render
import sparklinekit

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
      sparklinekit.blocks(list.map(affine(values, scale, shift), int.to_float))
      == sparklinekit.blocks(list.map(values, int.to_float))
    },
  )
}

pub fn unicode_reversing_the_series_reverses_the_blocks_test() -> Nil {
  metamon.forall(series_gen(), fn(values) {
    sparklinekit.blocks(list.map(list.reverse(values), int.to_float))
    == string.reverse(sparklinekit.blocks(list.map(values, int.to_float)))
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
  let values = list.map(values, int.to_float)
  let options = case styled {
    False -> sparklinekit.default_line_options
    True ->
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        smoothing: 0.3,
        area: sparklinekit.GradientArea,
        spot_radius: 2.0,
      )
  }
  let options = sparklinekit.LineOptions(..options, width: 60, height: 16)
  #(
    render.line_svg(values, options),
    render.line_png(values, options),
  )
}

fn bar_outputs(values: List(Int)) -> #(String, BitArray) {
  let values = list.map(values, int.to_float)
  let options =
    sparklinekit.BarOptions(
      ..sparklinekit.default_bar_options,
      width: 60,
      height: 16,
      theme: sparklinekit.sunset,
    )
  #(
    render.bar_svg(values, options),
    render.bar_png(values, options),
  )
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
      let before = sparklinekit.blocks(list.map(values, int.to_float))
      string.starts_with(
        sparklinekit.blocks(list.map(list.append(values, inside), int.to_float)),
        before,
      )
    }
    _, _ -> True
  }
}
