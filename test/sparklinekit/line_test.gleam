import gleam/string
import gleeunit/should
import sparklinekit/line
import sparklinekit/theme

pub fn empty_input_produces_svg_without_path_test() {
  let svg = line.new([]) |> line.to_svg
  svg
  |> string.contains("<svg")
  |> should.be_true

  svg
  |> string.contains("<path")
  |> should.be_false
}

pub fn default_dimensions_are_240_by_60_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_svg
  svg
  |> string.contains("viewBox=\"0 0 240 60\"")
  |> should.be_true
}

pub fn with_size_is_reflected_in_viewbox_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(100, 20)
    |> line.to_svg
  svg
  |> string.contains("viewBox=\"0 0 100 20\"")
  |> should.be_true
}

pub fn default_stroke_is_currentcolor_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_svg
  svg
  |> string.contains("stroke=\"currentColor\"")
  |> should.be_true
}

pub fn with_color_sets_stroke_attribute_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("red")
    |> line.to_svg
  svg
  |> string.contains("stroke=\"red\"")
  |> should.be_true
}

pub fn with_stroke_width_sets_stroke_width_attribute_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_stroke_width(2.5)
    |> line.to_svg
  svg
  |> string.contains("stroke-width=\"2.5\"")
  |> should.be_true
}

pub fn output_includes_path_element_test() {
  let svg = line.new([1.0, 3.0, 2.0, 5.0]) |> line.to_svg
  svg
  |> string.contains("<path")
  |> should.be_true
}

pub fn output_uses_preserve_aspect_ratio_none_test() {
  let svg = line.new([1.0, 2.0]) |> line.to_svg
  svg
  |> string.contains("preserveAspectRatio=\"none\"")
  |> should.be_true
}

pub fn output_opens_and_closes_svg_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_svg
  string.starts_with(svg, "<svg")
  |> should.be_true

  string.ends_with(svg, "</svg>")
  |> should.be_true
}

pub fn single_value_draws_horizontal_segment_at_midpoint_test() {
  let svg = line.new([3.0]) |> line.to_svg
  // Default height=60 → midpoint y=30.0; the segment starts inside
  // the padded edge so we just check the midpoint coordinate.
  svg
  |> string.contains("30.0")
  |> should.be_true
}

pub fn all_equal_values_draw_at_midpoint_test() {
  let svg = line.new([5.0, 5.0, 5.0]) |> line.to_svg
  // All points share y=30.0 (midpoint of default height 60).
  svg
  |> string.contains("30.0")
  |> should.be_true
}

pub fn quote_in_color_is_escaped_test() {
  let svg =
    line.new([1.0, 2.0])
    |> line.with_color("\"><script>")
    |> line.to_svg
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
    line.new([1.0, 2.0, 3.0])
    |> line.with_area_color("\"><script>")
    |> line.with_gradient_area(False)
    |> line.to_svg
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
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("\"><script>")
    |> line.with_area_fill(True)
    |> line.with_gradient_area(False)
    |> line.to_svg
  svg
  |> string.contains("<script>")
  |> should.be_false
}

pub fn non_positive_size_is_clamped_to_one_test() {
  let svg =
    line.new([1.0, 2.0])
    |> line.with_size(0, -10)
    |> line.to_svg
  svg
  |> string.contains("viewBox=\"0 0 1 1\"")
  |> should.be_true
}

pub fn new_ints_matches_new_with_floats_test() {
  let from_ints =
    line.new_ints([1, 5, 3, 8, 4])
    |> line.to_svg
  let from_floats =
    line.new([1.0, 5.0, 3.0, 8.0, 4.0])
    |> line.to_svg
  from_ints |> should.equal(from_floats)
}

pub fn deprecated_to_string_matches_to_svg_test() {
  let builder = line.new([1.0, 2.0, 3.0])
  // `line.to_string` is deprecated and produces a compile warning on
  // purpose — this test exists only to verify the alias keeps
  // forwarding to `to_svg` until it is removed.
  line.to_svg(builder) |> should.equal(line.to_string(builder))
}

pub fn with_theme_overrides_stroke_to_theme_foreground_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_theme(theme.ocean())
    |> line.to_svg
  svg
  |> string.contains("stroke=\"#1F6FEB\"")
  |> should.be_true
}

pub fn with_theme_paints_background_rectangle_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_theme(theme.ocean())
    |> line.to_svg
  svg
  |> string.contains("<rect")
  |> should.be_true
}

pub fn default_theme_omits_background_rectangle_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_svg
  svg
  |> string.contains("<rect")
  |> should.be_false
}

pub fn with_area_fill_adds_filled_path_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_theme(theme.ocean())
    |> line.with_area_fill(True)
    |> line.to_svg
  svg
  |> string.contains("<linearGradient")
  |> should.be_true
}

pub fn area_fill_off_by_default_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_svg
  svg
  |> string.contains("<linearGradient")
  |> should.be_false
}

pub fn with_area_color_uses_explicit_fill_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_area_color("#112233")
    |> line.with_gradient_area(False)
    |> line.to_svg
  svg
  |> string.contains("fill=\"#112233\"")
  |> should.be_true
}

pub fn with_smoothing_emits_cubic_bezier_test() {
  let svg =
    line.new([1.0, 2.0, 3.0, 4.0])
    |> line.with_smoothing(0.25)
    |> line.to_svg
  svg
  |> string.contains(" C ")
  |> should.be_true
}

pub fn no_smoothing_emits_linear_segments_test() {
  let svg = line.new([1.0, 2.0, 3.0, 4.0]) |> line.to_svg
  svg
  |> string.contains(" C ")
  |> should.be_false
}

pub fn with_spot_adds_end_circle_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_spot(3.0)
    |> line.to_svg
  svg
  |> string.contains("<circle")
  |> should.be_true
}

pub fn spot_off_by_default_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_svg
  svg
  |> string.contains("<circle")
  |> should.be_false
}

pub fn with_background_color_renders_rect_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_background_color("#FAFAFA")
    |> line.to_svg
  svg
  |> string.contains("fill=\"#FAFAFA\"")
  |> should.be_true
}

pub fn svg_includes_pixel_width_and_height_attributes_test() {
  // viewBox alone leaves the chart at the browser's intrinsic-default
  // size (often 300x150) when the SVG is embedded outside a
  // CSS-sized container. The pixel-width/height attributes mirror
  // the `with_size` request so standalone embeds size correctly.
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(120, 30)
    |> line.to_svg
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
    line.new(values)
    |> line.with_theme(theme.ocean())
    |> line.with_area_fill(True)
    |> line.to_svg
  let svg_sunset =
    line.new(values)
    |> line.with_theme(theme.sunset())
    |> line.with_area_fill(True)
    |> line.to_svg
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
    line.new([1.0, 2.0, 3.0, 8.0, 4.0])
    |> line.with_smoothing(0.25)
    |> line.with_size(360, 80)
    |> line.to_svg
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
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(1, 1)
    |> line.to_svg
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
    line.new(values)
    |> line.with_theme(theme.ocean())
    |> line.with_area_fill(True)
    |> line.to_svg
  let svg_b =
    line.new(values)
    |> line.with_theme(theme.ocean())
    |> line.with_area_fill(True)
    |> line.to_svg
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
