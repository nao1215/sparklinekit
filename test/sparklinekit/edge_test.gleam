//// Boundary inputs on both targets: non-finite and extreme values, sizes
//// of 0, 1 and below, the block levels, and PNG files big enough to need
//// several zlib blocks.

import gleam/list
import gleam/string
import render
import sparklinekit
import sparklinekit/output_snapshot_test

const max_float = 1.7976931348623157e308

// Infinity and NaN can only be made on JavaScript, for example by
// `1.0e308 *. 10.0`. On Erlang these helpers return the value the
// renderers draw them as, so the tests below hold on both targets.
@external(javascript, "./edge_ffi.mjs", "infinity")
fn infinity() -> Float {
  max_float
}

@external(javascript, "./edge_ffi.mjs", "nan")
fn nan() -> Float {
  0.0
}

fn line_options() -> sparklinekit.LineOptions {
  sparklinekit.LineOptions(
    ..sparklinekit.default_line_options,
    width: 40,
    height: 12,
    theme: sparklinekit.ocean,
    area: sparklinekit.GradientArea,
    spot_radius: 1.5,
  )
}

fn bar_options() -> sparklinekit.BarOptions {
  sparklinekit.BarOptions(
    ..sparklinekit.default_bar_options,
    width: 40,
    height: 12,
    theme: sparklinekit.sunset,
  )
}

// Every output for `values`.
fn draw(values: List(Float)) -> #(String, String, BitArray, String, BitArray) {
  #(
    sparklinekit.blocks(values),
    render.line_svg(values, line_options()),
    render.line_png(values, line_options()),
    render.bar_svg(values, bar_options()),
    render.bar_png(values, bar_options()),
  )
}

pub fn infinity_is_drawn_as_the_largest_float_test() {
  let inf = infinity()
  assert draw([1.0, inf, 2.0]) == draw([1.0, max_float, 2.0])
  assert draw([1.0, 0.0 -. inf, 2.0]) == draw([1.0, 0.0 -. max_float, 2.0])
}

// NaN used to compare as the largest value on JavaScript, so it was drawn
// at the top.
pub fn nan_is_drawn_as_zero_test() {
  assert draw([1.0, nan(), 2.0]) == draw([1.0, 0.0, 2.0])
  assert draw([nan(), nan()]) == draw([0.0, 0.0])
}

// Values above 1e300 were clamped to 1e300 before scaling, so two
// different large values drew a flat line.
pub fn large_values_keep_their_order_test() {
  assert sparklinekit.blocks([1.0e308, 1.7e308]) == "▁█"
  assert sparklinekit.blocks([-1.7e308, -1.0e308, 0.0, 1.0e308, 1.7e308])
    == sparklinekit.blocks([-1.7, -1.0, 0.0, 1.0, 1.7])
  assert sparklinekit.blocks([0.0 -. max_float, max_float]) == "▁█"
  let svg =
    render.line_svg([1.0e308, 1.7e308], sparklinekit.default_line_options)
  assert string.contains(svg, "d=\"M 1.0 59.0 L 239.0 1.0\"")
  let small = render.bar_svg([1.0, 1.7], sparklinekit.default_bar_options)
  assert render.bar_svg([1.0e308, 1.7e308], sparklinekit.default_bar_options)
    == small
}

pub fn tiny_values_keep_their_order_test() {
  assert sparklinekit.blocks([1.0e-308, 2.0e-308, 1.5e-308]) == "▁█▅"
  assert sparklinekit.blocks([5.0e-324, 1.0e-323]) == "▁█"
}

pub fn sizes_below_one_are_drawn_as_one_test() {
  let values = [1.0, -3.0, 2.0]
  list.each([0, -1, -500], fn(size) {
    let line = sparklinekit.LineOptions(..line_options(), width: size)
    let one = sparklinekit.LineOptions(..line_options(), width: 1)
    assert render.line_svg(values, line) == render.line_svg(values, one)
    assert render.line_png(values, line) == render.line_png(values, one)
    let line = sparklinekit.LineOptions(..line_options(), height: size)
    let one = sparklinekit.LineOptions(..line_options(), height: 1)
    assert render.line_svg(values, line) == render.line_svg(values, one)
    assert render.line_png(values, line) == render.line_png(values, one)
    let bar =
      sparklinekit.BarOptions(..bar_options(), width: size, height: size)
    let one = sparklinekit.BarOptions(..bar_options(), width: 1, height: 1)
    assert render.bar_svg(values, bar) == render.bar_svg(values, one)
    assert render.bar_png(values, bar) == render.bar_png(values, one)
  })
}

pub fn one_pixel_images_decode_test() {
  let line = sparklinekit.LineOptions(..line_options(), width: 1, height: 1)
  let bar = sparklinekit.BarOptions(..bar_options(), width: 1, height: 1)
  list.each([[], [1.0], [1.0, -1.0], [3.0, 3.0]], fn(values) {
    assert string.length(
        output_snapshot_test.pixels(render.line_png(values, line)),
      )
      == 8
    assert string.length(
        output_snapshot_test.pixels(render.bar_png(values, bar)),
      )
      == 8
  })
}

// 300 by 120 pixels is 144,120 bytes of scanlines, which the encoder splits
// into three stored DEFLATE blocks. The reader checks every chunk CRC and
// the Adler-32 of the whole stream.
pub fn multi_block_png_decodes_test() {
  let options =
    sparklinekit.LineOptions(
      ..line_options(),
      width: 300,
      height: 120,
      theme: sparklinekit.neon,
    )
  let rows =
    render.line_png([1.0, 5.0, -3.0, 9.0, 2.0], options)
    |> output_snapshot_test.pixels
    |> string.split("\n")
  assert list.length(rows) == 120
}

// Each block covers an equal share of the range, rounded to the nearest
// level, so the lowest and highest levels cover half a share each.
pub fn block_levels_test() {
  assert sparklinekit.blocks([0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0])
    == "▁▂▃▄▅▆▇█"
  assert sparklinekit.blocks([7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0])
    == "█▇▆▅▄▃▂▁"
  assert sparklinekit.blocks([0.0, 1.0]) == "▁█"
  assert sparklinekit.blocks([0.0, 7.0, 0.49]) == "▁█▁"
  assert sparklinekit.blocks([0.0, 7.0, 0.5]) == "▁█▂"
  assert sparklinekit.blocks([0.0, 7.0, 6.49]) == "▁█▇"
  assert sparklinekit.blocks([0.0, 7.0, 6.5]) == "▁██"
  assert sparklinekit.blocks([-1.0]) == "▄"
  assert sparklinekit.blocks([0.0, 0.0]) == "▄▄"
}
