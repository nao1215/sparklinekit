import gleam/option
import gleam/string
import gleeunit/should
import sparklinekit

pub fn empty_input_produces_svg_without_path_test() {
  let svg = sparklinekit.line_svg([], sparklinekit.default_line_options)
  svg
  |> string.contains("<svg")
  |> should.be_true

  svg
  |> string.contains("<path")
  |> should.be_false
}

pub fn default_dimensions_are_240_by_60_test() {
  let svg =
    sparklinekit.line_svg([1.0, 2.0, 3.0], sparklinekit.default_line_options)
  svg
  |> string.contains("viewBox=\"0 0 240 60\"")
  |> should.be_true
}

pub fn size_is_reflected_in_viewbox_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 100,
        height: 20,
      ),
    )
  svg
  |> string.contains("viewBox=\"0 0 100 20\"")
  |> should.be_true
}

pub fn default_stroke_is_currentcolor_test() {
  let svg =
    sparklinekit.line_svg([1.0, 2.0, 3.0], sparklinekit.default_line_options)
  svg
  |> string.contains("stroke=\"currentColor\"")
  |> should.be_true
}

pub fn color_sets_stroke_attribute_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "red",
        ),
      ),
    )
  svg
  |> string.contains("stroke=\"red\"")
  |> should.be_true
}

pub fn stroke_width_sets_stroke_width_attribute_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        stroke_width: 2.5,
      ),
    )
  svg
  |> string.contains("stroke-width=\"2.5\"")
  |> should.be_true
}

pub fn output_includes_path_element_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 3.0, 2.0, 5.0],
      sparklinekit.default_line_options,
    )
  svg
  |> string.contains("<path")
  |> should.be_true
}

pub fn output_uses_preserve_aspect_ratio_none_test() {
  let svg = sparklinekit.line_svg([1.0, 2.0], sparklinekit.default_line_options)
  svg
  |> string.contains("preserveAspectRatio=\"none\"")
  |> should.be_true
}

pub fn output_opens_and_closes_svg_test() {
  let svg =
    sparklinekit.line_svg([1.0, 2.0, 3.0], sparklinekit.default_line_options)
  string.starts_with(svg, "<svg")
  |> should.be_true

  string.ends_with(svg, "</svg>")
  |> should.be_true
}

pub fn single_value_draws_horizontal_segment_at_midpoint_test() {
  let svg = sparklinekit.line_svg([3.0], sparklinekit.default_line_options)
  // Default height=60 → midpoint y=30.0; the segment starts inside
  // the padded edge so we just check the midpoint coordinate.
  svg
  |> string.contains("30.0")
  |> should.be_true
}

pub fn all_equal_values_draw_at_midpoint_test() {
  let svg =
    sparklinekit.line_svg([5.0, 5.0, 5.0], sparklinekit.default_line_options)
  // All points share y=30.0 (midpoint of default height 60).
  svg
  |> string.contains("30.0")
  |> should.be_true
}

pub fn quote_in_color_is_escaped_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "\"><script>",
        ),
      ),
    )
  svg
  |> string.contains("<script>")
  |> should.be_false
}

pub fn area_explicit_color_is_escaped_when_gradient_off_test() {
  // The non-gradient area branch must escape the user-supplied fill
  // colour just like `stroke_svg` and `background_rect` do —
  // otherwise a colour string containing `"` or `<script>` lands in
  // the SVG unescaped.
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          area: option.Some("\"><script>"),
        ),
        area: sparklinekit.SolidArea,
      ),
    )
  svg
  |> string.contains("<script>")
  |> should.be_false
}

pub fn area_auto_color_is_escaped_when_stroke_is_non_hex_test() {
  // When the stroke colour is non-parseable as a hex (e.g. a CSS
  // keyword) and the gradient layer is disabled, the AreaAuto branch
  // falls back to echoing the raw stroke colour into the area fill.
  // That fallback must escape the value.
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "\"><script>",
        ),
        area: sparklinekit.SolidArea,
      ),
    )
  svg
  |> string.contains("<script>")
  |> should.be_false
}

pub fn non_positive_size_is_clamped_to_one_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 0,
        height: -10,
      ),
    )
  svg
  |> string.contains("viewBox=\"0 0 1 1\"")
  |> should.be_true
}

pub fn theme_overrides_stroke_to_theme_foreground_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
      ),
    )
  svg
  |> string.contains("stroke=\"#2563EB\"")
  |> should.be_true
}

pub fn theme_paints_background_rectangle_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
      ),
    )
  svg
  |> string.contains("<rect")
  |> should.be_true
}

pub fn default_theme_omits_background_rectangle_test() {
  let svg =
    sparklinekit.line_svg([1.0, 2.0, 3.0], sparklinekit.default_line_options)
  svg
  |> string.contains("<rect")
  |> should.be_false
}

pub fn area_fill_adds_filled_path_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        area: sparklinekit.GradientArea,
      ),
    )
  svg
  |> string.contains("<linearGradient")
  |> should.be_true
}

pub fn area_fill_off_by_default_test() {
  let svg =
    sparklinekit.line_svg([1.0, 2.0, 3.0], sparklinekit.default_line_options)
  svg
  |> string.contains("<linearGradient")
  |> should.be_false
}

pub fn area_color_uses_explicit_fill_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          area: option.Some("#112233"),
        ),
        area: sparklinekit.SolidArea,
      ),
    )
  svg
  |> string.contains("fill=\"#112233\"")
  |> should.be_true
}

pub fn smoothing_emits_cubic_bezier_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0, 4.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        smoothing: 0.25,
      ),
    )
  svg
  |> string.contains(" C ")
  |> should.be_true
}

pub fn no_smoothing_emits_linear_segments_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0, 4.0],
      sparklinekit.default_line_options,
    )
  svg
  |> string.contains(" C ")
  |> should.be_false
}

pub fn spot_adds_end_circle_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        spot_radius: 3.0,
      ),
    )
  svg
  |> string.contains("<circle")
  |> should.be_true
}

pub fn spot_off_by_default_test() {
  let svg =
    sparklinekit.line_svg([1.0, 2.0, 3.0], sparklinekit.default_line_options)
  svg
  |> string.contains("<circle")
  |> should.be_false
}

pub fn background_color_renders_rect_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          background: "#FAFAFA",
        ),
      ),
    )
  svg
  |> string.contains("fill=\"#FAFAFA\"")
  |> should.be_true
}

pub fn svg_includes_pixel_width_and_height_attributes_test() {
  // viewBox alone leaves the chart at the browser's intrinsic-default
  // size (often 300x150) when the SVG is embedded outside a
  // CSS-sized container. The pixel-width/height attributes mirror
  // the requested size so standalone embeds size correctly.
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 120,
        height: 30,
      ),
    )
  svg
  |> string.contains("width=\"120\"")
  |> should.be_true
  svg
  |> string.contains("height=\"30\"")
  |> should.be_true
}

pub fn gradient_ids_differ_when_themes_differ_test() {
  // Two charts with identical dimensions, value count, and value list
  // but different themes must get different gradient ids — otherwise
  // a browser inlining multiple sparklines into the same HTML page
  // reuses the first gradient definition for every subsequent chart
  // and the themes silently collapse to whichever was rendered first.
  let values = [1.0, 2.0, 3.0]
  let svg_ocean =
    sparklinekit.line_svg(
      values,
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        area: sparklinekit.GradientArea,
      ),
    )
  let svg_sunset =
    sparklinekit.line_svg(
      values,
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.sunset,
        area: sparklinekit.GradientArea,
      ),
    )
  extract_gradient_id(svg_ocean)
  |> should.not_equal(extract_gradient_id(svg_sunset))
}

pub fn path_coordinates_round_to_two_decimals_test() {
  // Intermediate bezier control points used to be serialised by
  // `float.to_string`, which can emit 14+ decimal digits for values
  // like `74.41176470588235`. The format helper now rounds path
  // coordinates to two decimals — far below SVG sub-pixel precision
  // but enough to keep the output readable and ~30% smaller.
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0, 8.0, 4.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 360,
        height: 80,
        smoothing: 0.25,
      ),
    )
  // A 14-digit fractional expansion should not survive the round.
  svg
  |> string.contains("76470588235")
  |> should.be_false
}

pub fn tiny_canvas_keeps_coordinates_inside_viewbox_test() {
  // A 1×1 viewBox used to receive coordinates up to (2.0, 2.0)
  // because the inset padding was never clamped to the canvas size.
  // The fix caps the inset to half the smaller side so all emitted
  // path coordinates stay inside [0, max].
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 1,
        height: 1,
      ),
    )
  svg
  |> string.contains(" 2.0")
  |> should.be_false
}

pub fn gradient_ids_match_when_charts_are_identical_test() {
  // Two charts with the same dimensions and theme produce identical
  // gradients — sharing a single `<defs>` entry across both is the
  // correct outcome, so the ids should match.
  let values = [1.0, 2.0, 3.0]
  let svg_a =
    sparklinekit.line_svg(
      values,
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        area: sparklinekit.GradientArea,
      ),
    )
  let svg_b =
    sparklinekit.line_svg(
      values,
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        area: sparklinekit.GradientArea,
      ),
    )
  extract_gradient_id(svg_a)
  |> should.equal(extract_gradient_id(svg_b))
}

fn extract_gradient_id(svg: String) -> String {
  case string.split_once(svg, "linearGradient id=\"") {
    Ok(#(_, after)) ->
      case string.split_once(after, "\"") {
        Ok(#(id, _)) -> id
        Error(_) -> ""
      }
    Error(_) -> ""
  }
}

// A solid area used a tint of the line colour (`#2563eb38`) in SVG while
// PNG used the theme's area colour (`#2563EB33`).
pub fn solid_area_uses_theme_area_colour_test() {
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      theme: sparklinekit.ocean,
      area: sparklinekit.SolidArea,
    )
  let svg = sparklinekit.line_svg([1.0, 5.0, 3.0], options)
  assert string.contains(svg, "<path fill=\"#2563EB33\" stroke=\"none\"")
}

// The dot kept the colour of the theme it was set with, so a dot on a
// red line stayed `currentColor` or theme blue.
pub fn spot_follows_the_line_colour_test() {
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      theme: sparklinekit.Theme(..sparklinekit.ocean, foreground: "#ff0000"),
      spot_radius: 2.0,
    )
  let svg = sparklinekit.line_svg([1.0, 5.0, 3.0], options)
  assert string.contains(svg, "r=\"2.0\" fill=\"#ff0000\"")
}

pub fn spot_color_overrides_the_line_colour_test() {
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      spot_radius: 2.0,
      spot_color: option.Some("#00ff00"),
    )
  let svg = sparklinekit.line_svg([1.0, 5.0, 3.0], options)
  assert string.contains(svg, "r=\"2.0\" fill=\"#00ff00\"")
}

// The SVG gradient was opaque at the top even when the area lay above the
// line, so it faded towards the line instead of away from it.
pub fn gradient_fades_away_from_a_negative_line_test() {
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      theme: sparklinekit.ocean,
      area: sparklinekit.GradientArea,
    )
  let below = sparklinekit.line_svg([-1.0, -5.0, -3.0], options)
  assert string.contains(below, "x1=\"0\" y1=\"1\" x2=\"0\" y2=\"0\"")
  assert string.contains(below, "-up\"")
  let above = sparklinekit.line_svg([1.0, 5.0, 3.0], options)
  assert string.contains(above, "x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"")
}

// A single negative value closed the area at the bottom, while two equal
// negative values closed it at the top.
pub fn single_negative_value_fills_up_to_the_top_test() {
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      area: sparklinekit.SolidArea,
    )
  let one = sparklinekit.line_svg([-5.0], options)
  let two = sparklinekit.line_svg([-5.0, -5.0], options)
  assert string.contains(one, "L 239.0 0.0 L 1.0 0.0 Z")
  assert one == two
}

// `Some("")` wrote `fill=""` into the SVG, which browsers draw black.
pub fn empty_area_colour_uses_the_foreground_tint_test() {
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      theme: sparklinekit.Theme(..sparklinekit.ocean, area: option.Some("")),
      area: sparklinekit.SolidArea,
    )
  let svg = sparklinekit.line_svg([1.0, 5.0, 3.0], options)
  assert string.contains(svg, "<path fill=\"#2563eb38\" stroke=\"none\"")
}
