//// Deep, adversarial QA — one test per defect this round surfaced.
////
//// Each test is the reproducer for a confirmed bug fixed in the
//// matching commit. The tests fail against the pre-fix source and
//// pass against the fixed source.

import gleam/string
import gleeunit/should
import sparklinekit

// --- Bug 2: the default options ignored the negative-bar colour of
// `default_theme`, so negatives were drawn in the same colour as
// positives.

pub fn bug2_bar_default_theme_negative_colour_is_used_test() {
  let svg =
    sparklinekit.bar_svg([3.0, -2.0, 5.0], sparklinekit.default_bar_options)
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
  let out = sparklinekit.blocks([neg_huge, 0.0, huge])
  string.length(out) |> should.equal(3)
}

// --- Bug 4: zero-value bars render as `height="0.0"` rects, which
// are invisible in both SVG (browsers paint no pixels) and PNG (the
// rasterizer short-circuits zero-height rects). A reader cannot
// distinguish "value was zero here" from "value missing here". The
// fix forces a minimum 1-px hairline at the baseline so a value
// of exactly zero is still drawn.

pub fn bug4_bar_zero_value_renders_nonzero_height_test() {
  let svg = sparklinekit.bar_svg([0.0, 5.0], sparklinekit.default_bar_options)
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
  let svg =
    sparklinekit.line_svg(
      [neg_huge, 0.0, huge],
      sparklinekit.default_line_options,
    )
  string.contains(svg, "NaN") |> should.be_false
  string.contains(svg, "Infinity") |> should.be_false
  string.contains(svg, "inf") |> should.be_false
}
