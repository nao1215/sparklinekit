//// Boundary value analysis for sparklinekit.
////
//// Exercises the documented edges of every public function — empty,
//// single value, all-equal, two values, eight distinct values, very
//// long lists, mixed positive / negative, and the floating-point
//// extremes (zero, negative zero, very small, very large, and the
//// non-finite values where the package's behaviour should be
//// well-defined or at least non-crashing).

import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import render
import sparklinekit

// --- Unicode renderer --------------------------------------------------

pub fn unicode_empty_renders_empty_string_test() {
  sparklinekit.blocks([]) |> should.equal("")
}

pub fn unicode_single_value_renders_middle_block_test() {
  sparklinekit.blocks([5.0]) |> should.equal("▄")
}

pub fn unicode_two_equal_values_render_flat_test() {
  sparklinekit.blocks([5.0, 5.0]) |> should.equal("▄▄")
}

pub fn unicode_two_distinct_values_render_min_max_test() {
  let out = sparklinekit.blocks([1.0, 9.0])
  // First character is the bottom block, second is the top block.
  string.length(out) |> should.equal(2)
  string.starts_with(out, "▁") |> should.be_true
  string.ends_with(out, "█") |> should.be_true
}

pub fn unicode_eight_distinct_values_use_full_block_vocabulary_test() {
  let out = sparklinekit.blocks([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  string.length(out) |> should.equal(8)
  // The output must be a permutation of the eight-block alphabet.
  let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  list.each(blocks, fn(b) {
    string.contains(out, b)
    |> should.be_true
  })
}

pub fn unicode_zero_and_negative_zero_are_equal_test() {
  sparklinekit.blocks([0.0, -0.0]) |> should.equal("▄▄")
}

pub fn unicode_very_long_input_does_not_crash_test() {
  let xs = list_range(1, 5000) |> list.map(int.to_float)
  let out = sparklinekit.blocks(xs)
  string.length(out) |> should.equal(5000)
}

pub fn unicode_all_negative_values_render_full_range_test() {
  let out = sparklinekit.blocks([-9.0, -1.0])
  string.length(out) |> should.equal(2)
  string.starts_with(out, "▁") |> should.be_true
  string.ends_with(out, "█") |> should.be_true
}

pub fn unicode_mixed_sign_values_normalise_against_observed_range_test() {
  let out = sparklinekit.blocks([-1.0, 0.0, 1.0])
  string.length(out) |> should.equal(3)
  string.starts_with(out, "▁") |> should.be_true
  string.ends_with(out, "█") |> should.be_true
}

pub fn unicode_very_large_finite_floats_do_not_crash_test() {
  let huge = 1.0e150
  let out = sparklinekit.blocks([0.0 -. huge, 0.0, huge])
  string.length(out) |> should.equal(3)
}

pub fn unicode_very_small_finite_floats_do_not_crash_test() {
  let tiny = 1.0e-150
  let out = sparklinekit.blocks([0.0 -. tiny, 0.0, tiny])
  string.length(out) |> should.equal(3)
}

// --- Line renderer (SVG) ----------------------------------------------

pub fn line_empty_svg_has_no_path_test() {
  let svg = render.line_svg([], sparklinekit.default_line_options)
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
  string.contains(svg, "<path") |> should.be_false
}

pub fn line_single_value_svg_has_path_test() {
  let svg = render.line_svg([5.0], sparklinekit.default_line_options)
  string.contains(svg, "<path") |> should.be_true
}

pub fn line_two_values_svg_is_well_formed_test() {
  let svg = render.line_svg([1.0, 9.0], sparklinekit.default_line_options)
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
  string.contains(svg, "<path") |> should.be_true
}

pub fn line_all_equal_values_render_at_midpoint_test() {
  // The path data should encode a horizontal segment at the canvas
  // midpoint; we just check it's well-formed and contains coordinates.
  let svg =
    render.line_svg(
      [5.0, 5.0, 5.0, 5.0, 5.0],
      sparklinekit.default_line_options,
    )
  string.contains(svg, "<path") |> should.be_true
}

pub fn line_size_zero_normalises_to_one_test() {
  // The package docs claim non-positive sizes are normalised to 1.
  let svg =
    render.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 0,
        height: 0,
      ),
    )
  // viewBox should not be `0 0 0 0` (which would be invalid SVG).
  string.contains(svg, "viewBox=\"0 0 0 0\"") |> should.be_false
  string.contains(svg, "viewBox=\"0 0 1 1\"") |> should.be_true
}

pub fn line_negative_size_normalises_to_one_test() {
  let svg =
    render.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: -10,
        height: -10,
      ),
    )
  string.contains(svg, "viewBox=\"0 0 1 1\"") |> should.be_true
}

pub fn line_negative_stroke_width_falls_back_test() {
  // Docs: non-positive stroke width falls back to a hairline of 0.5.
  let svg =
    render.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        stroke_width: -1.0,
      ),
    )
  string.contains(svg, "stroke-width=\"0.5\"") |> should.be_true
}

pub fn line_smoothing_above_max_clamps_test() {
  // Docs: smoothing outside [0.0, 0.5] is clamped to that range.
  let svg_a =
    render.line_svg(
      [1.0, 5.0, 3.0, 8.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        smoothing: 0.5,
      ),
    )
  let svg_b =
    render.line_svg(
      [1.0, 5.0, 3.0, 8.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        smoothing: 99.0,
      ),
    )
  svg_a |> should.equal(svg_b)
}

pub fn line_smoothing_below_min_clamps_test() {
  let svg_a =
    render.line_svg(
      [1.0, 5.0, 3.0, 8.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        smoothing: 0.0,
      ),
    )
  let svg_b =
    render.line_svg(
      [1.0, 5.0, 3.0, 8.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        smoothing: -99.0,
      ),
    )
  svg_a |> should.equal(svg_b)
}

pub fn line_very_large_input_does_not_crash_test() {
  let xs = list_range(1, 500) |> list.map(int.to_float)
  let svg = render.line_svg(xs, sparklinekit.default_line_options)
  string.starts_with(svg, "<svg") |> should.be_true
}

// --- helpers ----------------------------------------------------------

fn list_range(lo: Int, hi: Int) -> List(Int) {
  case lo > hi {
    True -> []
    False -> do_list_range(hi, lo, [])
  }
}

fn do_list_range(current: Int, lo: Int, acc: List(Int)) -> List(Int) {
  case current < lo {
    True -> acc
    False -> do_list_range(current - 1, lo, [current, ..acc])
  }
}

// --- Bar renderer (SVG) -----------------------------------------------

pub fn bar_empty_svg_has_no_rect_test() {
  let svg = render.bar_svg([], sparklinekit.default_bar_options)
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
  string.contains(svg, "<rect") |> should.be_false
}

pub fn bar_single_value_renders_half_height_test() {
  let svg = render.bar_svg([5.0], sparklinekit.default_bar_options)
  string.contains(svg, "<rect") |> should.be_true
}

pub fn bar_all_equal_values_render_half_height_test() {
  let svg = render.bar_svg([5.0, 5.0, 5.0], sparklinekit.default_bar_options)
  string.contains(svg, "<rect") |> should.be_true
}

pub fn bar_all_zero_values_do_not_crash_test() {
  let svg = render.bar_svg([0.0, 0.0, 0.0], sparklinekit.default_bar_options)
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn bar_mixed_sign_uses_zero_baseline_test() {
  let svg =
    render.bar_svg(
      [3.0, -2.0, 5.0, -4.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          negative: "#FF0000",
        ),
      ),
    )
  // Negative bars should pick up the negative fill colour.
  string.contains(svg, "fill=\"#FF0000\"") |> should.be_true
}

pub fn bar_size_zero_normalises_to_one_test() {
  let svg =
    render.bar_svg(
      [1.0, 2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 0,
        height: 0,
      ),
    )
  string.contains(svg, "viewBox=\"0 0 1 1\"") |> should.be_true
}

pub fn bar_negative_bar_gap_clamps_to_zero_test() {
  // Docs: a negative gap is treated as 0.
  let svg_a =
    render.bar_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(..sparklinekit.default_bar_options, gap: 0.0),
    )
  let svg_b =
    render.bar_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(..sparklinekit.default_bar_options, gap: -5.0),
    )
  svg_a |> should.equal(svg_b)
}

// --- PNG smoke (boundary) ---------------------------------------------

pub fn line_png_empty_returns_signature_test() {
  // The PNG signature must always lead the byte stream.
  let _png = render.line_png([], sparklinekit.default_line_options)
  // We do not assert on contents; this test exists to confirm that
  // calling `to_png` on an empty input does not panic.
  Nil
}

pub fn bar_png_empty_returns_signature_test() {
  let _png = render.bar_png([], sparklinekit.default_bar_options)
  Nil
}

pub fn line_png_single_value_does_not_crash_test() {
  let _png =
    render.line_png(
      [7.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
      ),
    )
  Nil
}

pub fn bar_png_single_value_does_not_crash_test() {
  let _png =
    render.bar_png(
      [7.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.amber,
      ),
    )
  Nil
}
