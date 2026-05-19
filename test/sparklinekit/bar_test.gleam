import gleam/list
import gleam/string
import gleeunit/should
import sparklinekit/bar
import sparklinekit/theme

pub fn empty_input_produces_svg_without_rects_test() {
  let svg = bar.new([]) |> bar.to_string
  svg
  |> string.contains("<svg")
  |> should.be_true

  svg
  |> string.contains("<rect")
  |> should.be_false
}

pub fn output_contains_one_rect_per_value_test() {
  let svg = bar.new([1.0, 2.0, 3.0, 4.0, 5.0]) |> bar.to_string
  rect_count(svg)
  |> should.equal(5)
}

pub fn default_dimensions_are_200_by_40_test() {
  let svg = bar.new([1.0, 2.0, 3.0]) |> bar.to_string
  svg
  |> string.contains("viewBox=\"0 0 200 40\"")
  |> should.be_true
}

pub fn with_size_is_reflected_in_viewbox_test() {
  let svg =
    bar.new([1.0, 2.0])
    |> bar.with_size(160, 30)
    |> bar.to_string
  svg
  |> string.contains("viewBox=\"0 0 160 30\"")
  |> should.be_true
}

pub fn default_fill_is_currentcolor_test() {
  let svg = bar.new([1.0, 2.0]) |> bar.to_string
  svg
  |> string.contains("fill=\"currentColor\"")
  |> should.be_true
}

pub fn with_color_sets_fill_attribute_test() {
  let svg =
    bar.new([1.0, 2.0])
    |> bar.with_color("#7F77DD")
    |> bar.to_string
  svg
  |> string.contains("fill=\"#7F77DD\"")
  |> should.be_true
}

pub fn all_positive_values_render_above_baseline_test() {
  // All bars start at the bottom (y=baseline=40) and extend upward,
  // so every rect has y < 40 once it has any height.
  let svg = bar.new([1.0, 2.0, 3.0]) |> bar.to_string
  rect_count(svg)
  |> should.equal(3)

  // The tallest bar (value 3.0) reaches y=0.
  svg
  |> string.contains("y=\"0.0\"")
  |> should.be_true
}

pub fn mixed_values_split_around_zero_line_test() {
  let svg = bar.new([3.0, -2.0, 5.0, -4.0]) |> bar.to_string
  // We should see four rects, some above and some below the zero line.
  rect_count(svg)
  |> should.equal(4)
}

pub fn quote_in_color_is_escaped_test() {
  let svg =
    bar.new([1.0, 2.0])
    |> bar.with_color("\"><script>")
    |> bar.to_string
  svg
  |> string.contains("<script>")
  |> should.be_false
}

pub fn non_positive_size_is_clamped_to_one_test() {
  let svg =
    bar.new([1.0, 2.0])
    |> bar.with_size(0, 0)
    |> bar.to_string
  svg
  |> string.contains("viewBox=\"0 0 1 1\"")
  |> should.be_true
}

pub fn output_opens_and_closes_svg_test() {
  let svg = bar.new([1.0, 2.0]) |> bar.to_string
  string.starts_with(svg, "<svg")
  |> should.be_true

  string.ends_with(svg, "</svg>")
  |> should.be_true
}

pub fn with_bar_gap_is_accepted_test() {
  // Configuration should round-trip cleanly even though we don't
  // assert on the exact bar width (it depends on the gap-derived
  // step size).
  let svg =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_bar_gap(4.0)
    |> bar.to_string
  rect_count(svg)
  |> should.equal(3)
}

pub fn new_ints_matches_new_with_floats_test() {
  let from_ints = bar.new_ints([1, 5, 3, 8]) |> bar.to_svg
  let from_floats = bar.new([1.0, 5.0, 3.0, 8.0]) |> bar.to_svg
  from_ints |> should.equal(from_floats)
}

pub fn to_svg_is_alias_for_to_string_test() {
  let builder = bar.new([1.0, 2.0, 3.0])
  bar.to_svg(builder) |> should.equal(bar.to_string(builder))
}

pub fn with_theme_paints_positive_bars_in_theme_color_test() {
  let svg =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_theme(theme.sunset())
    |> bar.to_svg
  svg
  |> string.contains("fill=\"#F76808\"")
  |> should.be_true
}

pub fn with_theme_paints_negative_bars_in_negative_slot_test() {
  let svg =
    bar.new([3.0, -2.0])
    |> bar.with_theme(theme.forest())
    |> bar.to_svg
  svg
  |> string.contains("fill=\"#E5484D\"")
  |> should.be_true
}

pub fn with_negative_color_overrides_theme_negative_test() {
  let svg =
    bar.new([1.0, -2.0])
    |> bar.with_theme(theme.forest())
    |> bar.with_negative_color("#000000")
    |> bar.to_svg
  svg
  |> string.contains("fill=\"#000000\"")
  |> should.be_true
}

pub fn with_corner_radius_emits_rx_attribute_test() {
  let svg =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_corner_radius(2.5)
    |> bar.to_svg
  svg
  |> string.contains("rx=\"")
  |> should.be_true
}

pub fn corner_radius_zero_omits_rx_attribute_test() {
  let svg = bar.new([1.0, 2.0, 3.0]) |> bar.to_svg
  svg
  |> string.contains("rx=\"")
  |> should.be_false
}

pub fn with_background_color_renders_background_rect_test() {
  let svg =
    bar.new([1.0, 2.0])
    |> bar.with_background_color("#101010")
    |> bar.to_svg
  svg
  |> string.contains("fill=\"#101010\"")
  |> should.be_true
}

fn rect_count(svg: String) -> Int {
  svg
  |> string.split("<rect")
  |> list.length
  |> fn(n) { n - 1 }
}
