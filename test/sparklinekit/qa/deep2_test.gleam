//// Round 2 deep QA — five more defects.

import gleam/option
import gleam/string
import gleeunit/should
import sparklinekit

// --- Bug 6: extreme `stroke_width` overflows `format.coord`.
//
// The stroke-width is written into the SVG as a literal coord via
// `format.coord(value)`, which does `value *. 100.0`. For
// `1.0e308` that overflows the IEEE 754 double range, producing
// `arithmetic_error` (Badarith) on Erlang and `Infinity` /
// `NaN` literals on JavaScript. The PNG side is worse — the
// raster's `plot_perpendicular` iterates `±half_thick` pixels per
// line position, so a huge stroke also hangs the renderer.

pub fn bug6_extreme_stroke_width_does_not_crash_svg_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        stroke_width: 1.0e308,
      ),
    )
  string.starts_with(svg, "<svg") |> should.be_true
  string.contains(svg, "Infinity") |> should.be_false
  string.contains(svg, "NaN") |> should.be_false
}

// --- Bug 7: extreme `spot_radius` — same root cause as Bug 6
// but in a separate option and a separate rendering element.

pub fn bug7_extreme_spot_radius_does_not_crash_svg_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        spot_radius: 1.0e308,
      ),
    )
  string.starts_with(svg, "<svg") |> should.be_true
  string.contains(svg, "Infinity") |> should.be_false
  string.contains(svg, "NaN") |> should.be_false
}

// --- Bug 8: hairline introduced by PR #3 escapes the canvas when
// the baseline sits on a canvas edge. For all-non-positive data
// the baseline is pinned to `y = 0` (top); a value-zero bar gets a
// hairline at `y = baseline - 1 = -1`. The hairline must always
// grow *into* the canvas, away from the nearer edge.

pub fn bug8_hairline_stays_inside_canvas_for_top_baseline_test() {
  let svg = sparklinekit.bar_svg([0.0, -5.0], sparklinekit.default_bar_options)
  // No rect y attribute may be negative.
  string.contains(svg, "y=\"-") |> should.be_false
}

// --- Bug 9: the theme's `area` accepts "any CSS colour string" per
// the docs, but when the value is not parseable as hex AND the
// default gradient is enabled, the renderer silently substitutes
// the stroke colour (or black for the default theme). The user's
// literal colour disappears from the output. Gradient mode must
// either honour the literal colour or skip the gradient entirely.

pub fn bug9_gradient_non_hex_area_color_uses_colour_literal_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          area: option.Some("rgb(255, 0, 0)"),
        ),
        area: sparklinekit.GradientArea,
      ),
    )
  string.contains(svg, "rgb(255, 0, 0)") |> should.be_true
  string.contains(svg, "stop-color=\"#00000038\"") |> should.be_false
}

// --- Bug 10: with the default theme — where `theme.foreground` is
// `currentColor` — turning on the area fill is documented as
// producing "a translucent tint from the stroke colour". The
// stroke does inherit the CSS context via `stroke="currentColor"`,
// but the area is filled with a hex gradient derived from
// `with_alpha(black, 0.22)` because `currentColor` cannot be
// parsed to RGB. The result is a black-tinted area sitting under a
// CSS-inheriting stroke — visually inconsistent. The area gradient
// must also inherit via `currentColor` (with `stop-opacity`) when
// the stroke colour is itself a CSS keyword that isn't a hex.

pub fn bug10_default_theme_area_fill_inherits_currentcolor_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        area: sparklinekit.GradientArea,
      ),
    )
  // Stroke must inherit CSS via currentColor.
  string.contains(svg, "stroke=\"currentColor\"") |> should.be_true
  // The area must NOT be a hardcoded black derivation —
  // `#00000038` is the black-with-0x38-alpha that the buggy path
  // produces.
  string.contains(svg, "stop-color=\"#00000038\"") |> should.be_false
  // The area must inherit currentColor too.
  string.contains(svg, "currentColor") |> should.be_true
}
