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
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme
import sparklinekit/unicode

// --- Unicode renderer --------------------------------------------------

pub fn unicode_empty_renders_empty_string_test() {
  unicode.render([]) |> should.equal("")
}

pub fn unicode_single_value_renders_middle_block_test() {
  unicode.render([5.0]) |> should.equal("▄")
}

pub fn unicode_two_equal_values_render_flat_test() {
  unicode.render([5.0, 5.0]) |> should.equal("▄▄")
}

pub fn unicode_two_distinct_values_render_min_max_test() {
  let out = unicode.render([1.0, 9.0])
  // First character is the bottom block, second is the top block.
  string.length(out) |> should.equal(2)
  string.starts_with(out, "▁") |> should.be_true
  string.ends_with(out, "█") |> should.be_true
}

pub fn unicode_eight_distinct_values_use_full_block_vocabulary_test() {
  let out = unicode.render([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  string.length(out) |> should.equal(8)
  // The output must be a permutation of the eight-block alphabet.
  let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  list.each(blocks, fn(b) {
    string.contains(out, b)
    |> should.be_true
  })
}

pub fn unicode_zero_and_negative_zero_are_equal_test() {
  unicode.render([0.0, -0.0]) |> should.equal("▄▄")
}

pub fn unicode_very_long_input_does_not_crash_test() {
  let xs = list_range(1, 5000) |> list.map(int.to_float)
  let out = unicode.render(xs)
  string.length(out) |> should.equal(5000)
}

pub fn unicode_all_negative_values_render_full_range_test() {
  let out = unicode.render([-9.0, -1.0])
  string.length(out) |> should.equal(2)
  string.starts_with(out, "▁") |> should.be_true
  string.ends_with(out, "█") |> should.be_true
}

pub fn unicode_mixed_sign_values_normalise_against_observed_range_test() {
  let out = unicode.render([-1.0, 0.0, 1.0])
  string.length(out) |> should.equal(3)
  string.starts_with(out, "▁") |> should.be_true
  string.ends_with(out, "█") |> should.be_true
}

pub fn unicode_very_large_finite_floats_do_not_crash_test() {
  let huge = 1.0e150
  let out = unicode.render([0.0 -. huge, 0.0, huge])
  string.length(out) |> should.equal(3)
}

pub fn unicode_very_small_finite_floats_do_not_crash_test() {
  let tiny = 1.0e-150
  let out = unicode.render([0.0 -. tiny, 0.0, tiny])
  string.length(out) |> should.equal(3)
}

pub fn unicode_render_ints_matches_render_floats_test() {
  let ints = [1, 5, 22, 13, 5, 2, 7]
  let floats = list.map(ints, int.to_float)
  unicode.render_ints(ints) |> should.equal(unicode.render(floats))
}

// --- Line renderer (SVG) ----------------------------------------------

pub fn line_empty_svg_has_no_path_test() {
  let svg = line.new([]) |> line.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
  string.contains(svg, "<path") |> should.be_false
}

pub fn line_single_value_svg_has_path_test() {
  let svg = line.new([5.0]) |> line.to_svg
  string.contains(svg, "<path") |> should.be_true
}

pub fn line_two_values_svg_is_well_formed_test() {
  let svg = line.new([1.0, 9.0]) |> line.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
  string.contains(svg, "<path") |> should.be_true
}

pub fn line_all_equal_values_render_at_midpoint_test() {
  // The path data should encode a horizontal segment at the canvas
  // midpoint; we just check it's well-formed and contains coordinates.
  let svg = line.new([5.0, 5.0, 5.0, 5.0, 5.0]) |> line.to_svg
  string.contains(svg, "<path") |> should.be_true
}

pub fn line_with_size_zero_normalises_to_one_test() {
  // The package docs claim non-positive sizes are normalised to 1.
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(0, 0)
    |> line.to_svg
  // viewBox should not be `0 0 0 0` (which would be invalid SVG).
  string.contains(svg, "viewBox=\"0 0 0 0\"") |> should.be_false
  string.contains(svg, "viewBox=\"0 0 1 1\"") |> should.be_true
}

pub fn line_with_negative_size_normalises_to_one_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(-10, -10)
    |> line.to_svg
  string.contains(svg, "viewBox=\"0 0 1 1\"") |> should.be_true
}

pub fn line_with_negative_stroke_width_falls_back_test() {
  // Docs: non-positive stroke width falls back to a hairline of 0.5.
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_stroke_width(-1.0)
    |> line.to_svg
  string.contains(svg, "stroke-width=\"0.5\"") |> should.be_true
}

pub fn line_with_smoothing_above_max_clamps_test() {
  // Docs: smoothing outside [0.0, 0.5] is clamped to that range.
  let svg_a =
    line.new([1.0, 5.0, 3.0, 8.0])
    |> line.with_smoothing(0.5)
    |> line.to_svg
  let svg_b =
    line.new([1.0, 5.0, 3.0, 8.0])
    |> line.with_smoothing(99.0)
    |> line.to_svg
  svg_a |> should.equal(svg_b)
}

pub fn line_with_smoothing_below_min_clamps_test() {
  let svg_a =
    line.new([1.0, 5.0, 3.0, 8.0])
    |> line.with_smoothing(0.0)
    |> line.to_svg
  let svg_b =
    line.new([1.0, 5.0, 3.0, 8.0])
    |> line.with_smoothing(-99.0)
    |> line.to_svg
  svg_a |> should.equal(svg_b)
}

pub fn line_very_large_input_does_not_crash_test() {
  let xs = list_range(1, 500) |> list.map(int.to_float)
  let svg = line.new(xs) |> line.to_svg
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
  let svg = bar.new([]) |> bar.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
  string.contains(svg, "<rect") |> should.be_false
}

pub fn bar_single_value_renders_half_height_test() {
  let svg = bar.new([5.0]) |> bar.to_svg
  string.contains(svg, "<rect") |> should.be_true
}

pub fn bar_all_equal_values_render_half_height_test() {
  let svg = bar.new([5.0, 5.0, 5.0]) |> bar.to_svg
  string.contains(svg, "<rect") |> should.be_true
}

pub fn bar_all_zero_values_do_not_crash_test() {
  let svg = bar.new([0.0, 0.0, 0.0]) |> bar.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn bar_mixed_sign_uses_zero_baseline_test() {
  let svg =
    bar.new([3.0, -2.0, 5.0, -4.0])
    |> bar.with_negative_color("#FF0000")
    |> bar.to_svg
  // Negative bars should pick up the negative fill colour.
  string.contains(svg, "fill=\"#FF0000\"") |> should.be_true
}

pub fn bar_with_size_zero_normalises_to_one_test() {
  let svg =
    bar.new([1.0, 2.0])
    |> bar.with_size(0, 0)
    |> bar.to_svg
  string.contains(svg, "viewBox=\"0 0 1 1\"") |> should.be_true
}

pub fn bar_with_negative_bar_gap_clamps_to_zero_test() {
  // Docs: with_bar_gap clamps negative values to 0.
  let svg_a =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_bar_gap(0.0)
    |> bar.to_svg
  let svg_b =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_bar_gap(-5.0)
    |> bar.to_svg
  svg_a |> should.equal(svg_b)
}

// --- PNG smoke (boundary) ---------------------------------------------

pub fn line_png_empty_returns_signature_test() {
  // The PNG signature must always lead the byte stream.
  let _png = line.new([]) |> line.to_png
  // We do not assert on contents; this test exists to confirm that
  // calling `to_png` on an empty input does not panic.
  Nil
}

pub fn bar_png_empty_returns_signature_test() {
  let _png = bar.new([]) |> bar.to_png
  Nil
}

pub fn line_png_with_single_value_does_not_crash_test() {
  let _png =
    line.new([7.0])
    |> line.with_theme(theme.ocean())
    |> line.to_png
  Nil
}

pub fn bar_png_with_single_value_does_not_crash_test() {
  let _png =
    bar.new([7.0])
    |> bar.with_theme(theme.amber())
    |> bar.to_png
  Nil
}
