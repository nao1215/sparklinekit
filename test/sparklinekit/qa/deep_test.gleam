//// Deep, adversarial QA — one test per defect this round surfaced.
////
//// Each test is the reproducer for a confirmed bug fixed in the
//// matching commit. The tests fail against the pre-fix source and
//// pass against the fixed source.

import gleam/string
import gleeunit/should
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/unicode

// --- Bug 1: `with_area_fill(False)` permanently discards a prior
// `with_area_color`. Disabling the area fill and re-enabling it
// should restore the explicit colour, not silently fall back to the
// auto-tint derived from the stroke.

pub fn bug1_area_fill_toggle_preserves_explicit_colour_test() {
  let a =
    line.new([1.0, 2.0, 3.0])
    |> line.with_area_color("#123456")
    |> line.to_svg
  let b =
    line.new([1.0, 2.0, 3.0])
    |> line.with_area_color("#123456")
    |> line.with_area_fill(False)
    |> line.with_area_fill(True)
    |> line.to_svg
  a |> should.equal(b)
}

// --- Bug 2: `bar.new` (no explicit theme) ignores the negative-bar
// colour declared by `theme.default()`. Mixed-sign input produces
// negatives in the *same* colour as positives, hiding the sign
// distinction. The default theme exposes `negative: "#EF4444"` —
// it should be honoured, just like `with_theme(...)` does.

pub fn bug2_bar_default_theme_negative_colour_is_used_test() {
  let svg = bar.new([3.0, -2.0, 5.0]) |> bar.to_svg
  string.contains(svg, "fill=\"#EF4444\"")
  |> should.be_true
}

// --- Bug 3: extreme but well-typed float input causes the Erlang
// target to raise `arithmetic_error` (Badarith) inside
// `scale.unit`'s subtraction. The package accepts `List(Float)` and
// must be total for any pair of finite floats — clamping the input
// to a safe range before computing `max - min` keeps the renderer
// working on both targets.

pub fn bug3_unicode_extreme_float_range_does_not_crash_test() {
  let huge = 1.0e308
  let neg_huge = 0.0 -. 1.0e308
  let out = unicode.render([neg_huge, 0.0, huge])
  string.length(out) |> should.equal(3)
}

// --- Bug 4: zero-value bars render as `height="0.0"` rects, which
// are invisible in both SVG (browsers paint no pixels) and PNG (the
// rasterizer short-circuits zero-height rects). A reader cannot
// distinguish "value was zero here" from "value missing here". The
// fix forces a minimum 1-px hairline at the baseline so a value
// of exactly zero is still drawn.

pub fn bug4_bar_zero_value_renders_with_nonzero_height_test() {
  let svg = bar.new([0.0, 5.0]) |> bar.to_svg
  string.contains(svg, "height=\"0.0\"")
  |> should.be_false
}

// --- Bug 5: even when Bug 3 stops crashing on Erlang, the JS target
// silently produces SVG output containing the strings `NaN` or
// `Infinity` for the same extreme-float input. SVG with non-finite
// coordinates is invalid and renders as nothing. The clamp in
// `scale.unit` must keep all downstream coordinates finite on both
// targets.

pub fn bug5_line_extreme_float_svg_has_no_non_finite_coordinates_test() {
  let huge = 1.0e308
  let neg_huge = 0.0 -. 1.0e308
  let svg = line.new([neg_huge, 0.0, huge]) |> line.to_svg
  string.contains(svg, "NaN") |> should.be_false
  string.contains(svg, "Infinity") |> should.be_false
  string.contains(svg, "inf") |> should.be_false
}
