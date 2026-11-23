import gleam/list
import gleam/string
import gleeunit/should
import sparklinekit

pub fn empty_input_produces_svg_without_rects_test() {
  let svg = sparklinekit.bar_svg([], sparklinekit.default_bar_options)
  svg
  |> string.contains("<svg")
  |> should.be_true

  svg
  |> string.contains("<rect")
  |> should.be_false
}

pub fn output_contains_one_rect_per_value_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0, 3.0, 4.0, 5.0],
      sparklinekit.default_bar_options,
    )
  rect_count(svg)
  |> should.equal(5)
}

pub fn default_dimensions_are_200_by_40_test() {
  let svg =
    sparklinekit.bar_svg([1.0, 2.0, 3.0], sparklinekit.default_bar_options)
  svg
  |> string.contains("viewBox=\"0 0 200 40\"")
  |> should.be_true
}

pub fn size_is_reflected_in_viewbox_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 160,
        height: 30,
      ),
    )
  svg
  |> string.contains("viewBox=\"0 0 160 30\"")
  |> should.be_true
}

pub fn default_fill_is_currentcolor_test() {
  let svg = sparklinekit.bar_svg([1.0, 2.0], sparklinekit.default_bar_options)
  svg
  |> string.contains("fill=\"currentColor\"")
  |> should.be_true
}

pub fn color_sets_fill_attribute_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "#7F77DD",
        ),
      ),
    )
  svg
  |> string.contains("fill=\"#7F77DD\"")
  |> should.be_true
}

pub fn all_positive_values_render_above_baseline_test() {
  // All bars start at the bottom (y=baseline=40) and extend upward,
  // so every rect has y < 40 once it has any height.
  let svg =
    sparklinekit.bar_svg([1.0, 2.0, 3.0], sparklinekit.default_bar_options)
  rect_count(svg)
  |> should.equal(3)

  // The tallest bar (value 3.0) reaches y=0.
  svg
  |> string.contains("y=\"0.0\"")
  |> should.be_true
}

pub fn mixed_values_split_around_zero_line_test() {
  let svg =
    sparklinekit.bar_svg(
      [3.0, -2.0, 5.0, -4.0],
      sparklinekit.default_bar_options,
    )
  // We should see four rects, some above and some below the zero line.
  rect_count(svg)
  |> should.equal(4)
}

pub fn quote_in_color_is_escaped_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
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

pub fn non_positive_size_is_clamped_to_one_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 0,
        height: 0,
      ),
    )
  svg
  |> string.contains("viewBox=\"0 0 1 1\"")
  |> should.be_true
}

pub fn output_opens_and_closes_svg_test() {
  let svg = sparklinekit.bar_svg([1.0, 2.0], sparklinekit.default_bar_options)
  string.starts_with(svg, "<svg")
  |> should.be_true

  string.ends_with(svg, "</svg>")
  |> should.be_true
}

pub fn bar_gap_is_accepted_test() {
  // Configuration should round-trip cleanly even though we don't
  // assert on the exact bar width (it depends on the gap-derived
  // step size).
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(..sparklinekit.default_bar_options, gap: 4.0),
    )
  rect_count(svg)
  |> should.equal(3)
}

pub fn theme_paints_positive_bars_in_theme_color_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.sunset,
      ),
    )
  svg
  |> string.contains("fill=\"#F97316\"")
  |> should.be_true
}

pub fn theme_paints_negative_bars_in_negative_slot_test() {
  let svg =
    sparklinekit.bar_svg(
      [3.0, -2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.forest,
      ),
    )
  svg
  |> string.contains("fill=\"#EF4444\"")
  |> should.be_true
}

pub fn negative_color_overrides_theme_negative_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, -2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(..sparklinekit.forest, negative: "#000000"),
      ),
    )
  svg
  |> string.contains("fill=\"#000000\"")
  |> should.be_true
}

pub fn corner_radius_emits_rx_attribute_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        corner_radius: 2.5,
      ),
    )
  svg
  |> string.contains("rx=\"")
  |> should.be_true
}

pub fn corner_radius_zero_omits_rx_attribute_test() {
  let svg =
    sparklinekit.bar_svg([1.0, 2.0, 3.0], sparklinekit.default_bar_options)
  svg
  |> string.contains("rx=\"")
  |> should.be_false
}

pub fn background_color_renders_background_rect_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          background: "#101010",
        ),
      ),
    )
  svg
  |> string.contains("fill=\"#101010\"")
  |> should.be_true
}

pub fn svg_includes_pixel_width_and_height_attributes_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 160,
        height: 30,
      ),
    )
  svg
  |> string.contains("width=\"160\"")
  |> should.be_true
  svg
  |> string.contains("height=\"30\"")
  |> should.be_true
}

pub fn bar_widths_round_to_two_decimals_test() {
  // Bar widths derived from `width / count` produced floats like
  // `30.333333333333336` which bloated the SVG with no visual gain.
  // The format helper now rounds output coordinates to two decimals.
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
      sparklinekit.default_bar_options,
    )
  svg
  |> string.contains("33333")
  |> should.be_false
}

pub fn single_value_renders_half_height_bar_test() {
  // `[v]` would otherwise fill the full canvas because both `lo` and
  // `hi` equal `v` and `effective_range` collapses to a single
  // baseline. The line and unicode renderers special-case the same
  // input to a midline / middle block — bar matches that intent by
  // emitting a half-height placeholder bar.
  let svg =
    sparklinekit.bar_svg(
      [7.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 100,
        height: 40,
      ),
    )
  svg
  |> string.contains("height=\"20.0\"")
  |> should.be_true
}

pub fn all_equal_positives_render_half_height_test() {
  // `[5.0, 5.0, 5.0]` used to fill the canvas; now matches the line
  // renderer's flat-midline behaviour by drawing half-height bars.
  let svg =
    sparklinekit.bar_svg(
      [5.0, 5.0, 5.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 150,
        height: 40,
      ),
    )
  svg
  |> string.contains("height=\"20.0\"")
  |> should.be_true
  // None of the bars should reach the top of the canvas (y=0).
  svg
  |> string.contains("y=\"0.0\"")
  |> should.be_false
}

fn rect_count(svg: String) -> Int {
  svg
  |> string.split("<rect")
  |> list.length
  |> fn(n) { n - 1 }
}
