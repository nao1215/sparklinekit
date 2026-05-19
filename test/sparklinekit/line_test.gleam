import gleam/string
import gleeunit/should
import sparklinekit/line
import sparklinekit/theme

pub fn empty_input_produces_svg_without_polyline_test() {
  let svg = line.new([]) |> line.to_string
  svg
  |> string.contains("<svg")
  |> should.be_true

  svg
  |> string.contains("<polyline")
  |> should.be_false
}

pub fn default_dimensions_are_200_by_40_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_string
  svg
  |> string.contains("viewBox=\"0 0 200 40\"")
  |> should.be_true
}

pub fn with_size_is_reflected_in_viewbox_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(100, 20)
    |> line.to_string
  svg
  |> string.contains("viewBox=\"0 0 100 20\"")
  |> should.be_true
}

pub fn default_stroke_is_currentcolor_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_string
  svg
  |> string.contains("stroke=\"currentColor\"")
  |> should.be_true
}

pub fn with_color_sets_stroke_attribute_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("red")
    |> line.to_string
  svg
  |> string.contains("stroke=\"red\"")
  |> should.be_true
}

pub fn with_stroke_width_sets_stroke_width_attribute_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_stroke_width(2.5)
    |> line.to_string
  svg
  |> string.contains("stroke-width=\"2.5\"")
  |> should.be_true
}

pub fn output_includes_polyline_element_test() {
  let svg = line.new([1.0, 3.0, 2.0, 5.0]) |> line.to_string
  svg
  |> string.contains("<polyline")
  |> should.be_true
}

pub fn output_uses_preserve_aspect_ratio_none_test() {
  let svg = line.new([1.0, 2.0]) |> line.to_string
  svg
  |> string.contains("preserveAspectRatio=\"none\"")
  |> should.be_true
}

pub fn output_opens_and_closes_svg_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_string
  string.starts_with(svg, "<svg")
  |> should.be_true

  string.ends_with(svg, "</svg>")
  |> should.be_true
}

pub fn single_value_draws_horizontal_segment_at_midpoint_test() {
  let svg = line.new([3.0]) |> line.to_string
  // height=40 → midpoint y=20.0
  svg
  |> string.contains("0.0,20.0")
  |> should.be_true

  svg
  |> string.contains("200.0,20.0")
  |> should.be_true
}

pub fn all_equal_values_draw_at_midpoint_test() {
  let svg = line.new([5.0, 5.0, 5.0]) |> line.to_string
  // All points share y=20.0 (midpoint of default height 40).
  svg
  |> string.contains(",20.0")
  |> should.be_true
}

pub fn quote_in_color_is_escaped_test() {
  let svg =
    line.new([1.0, 2.0])
    |> line.with_color("\"><script>")
    |> line.to_string
  svg
  |> string.contains("<script>")
  |> should.be_false
}

pub fn non_positive_size_is_clamped_to_one_test() {
  let svg =
    line.new([1.0, 2.0])
    |> line.with_size(0, -10)
    |> line.to_string
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

pub fn to_svg_is_alias_for_to_string_test() {
  let builder = line.new([1.0, 2.0, 3.0])
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

pub fn with_area_fill_adds_polygon_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_theme(theme.ocean())
    |> line.with_area_fill(True)
    |> line.to_svg
  svg
  |> string.contains("<polygon")
  |> should.be_true
}

pub fn area_fill_off_by_default_test() {
  let svg = line.new([1.0, 2.0, 3.0]) |> line.to_svg
  svg
  |> string.contains("<polygon")
  |> should.be_false
}

pub fn with_area_color_uses_explicit_fill_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_area_color("#112233")
    |> line.to_svg
  svg
  |> string.contains("fill=\"#112233\"")
  |> should.be_true
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
