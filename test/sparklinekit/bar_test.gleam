import gleam/list
import gleam/string
import gleeunit/should
import render
import sparklinekit

pub fn empty_input_produces_svg_without_rects_test() {
  let svg = render.bar_svg([], sparklinekit.default_bar_options)
  svg
  |> string.contains("<svg")
  |> should.be_true

  svg
  |> string.contains("<rect")
  |> should.be_false
}

pub fn output_contains_one_rect_per_value_test() {
  let svg =
    render.bar_svg([1.0, 2.0, 3.0, 4.0, 5.0], sparklinekit.default_bar_options)
  rect_count(svg)
  |> should.equal(5)
}

pub fn default_dimensions_are_200_by_40_test() {
  let svg = render.bar_svg([1.0, 2.0, 3.0], sparklinekit.default_bar_options)
  svg
  |> string.contains("viewBox=\"0 0 200 40\"")
  |> should.be_true
}

pub fn size_is_reflected_in_viewbox_test() {
  let svg =
    render.bar_svg(
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
  let svg = render.bar_svg([1.0, 2.0], sparklinekit.default_bar_options)
  svg
  |> string.contains("fill=\"currentColor\"")
  |> should.be_true
}

pub fn color_sets_fill_attribute_test() {
  let svg =
    render.bar_svg(
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
  let svg = render.bar_svg([1.0, 2.0, 3.0], sparklinekit.default_bar_options)
  rect_count(svg)
  |> should.equal(3)

  // The tallest bar (value 3.0) reaches y=0.
  svg
  |> string.contains("y=\"0.0\"")
  |> should.be_true
}

pub fn mixed_values_split_around_zero_line_test() {
  let svg =
    render.bar_svg([3.0, -2.0, 5.0, -4.0], sparklinekit.default_bar_options)
  // We should see four rects, some above and some below the zero line.
  rect_count(svg)
  |> should.equal(4)
}

pub fn non_positive_size_is_clamped_to_one_test() {
  let svg =
    render.bar_svg(
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
  let svg = render.bar_svg([1.0, 2.0], sparklinekit.default_bar_options)
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
    render.bar_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(..sparklinekit.default_bar_options, gap: 4.0),
    )
  rect_count(svg)
  |> should.equal(3)
}

pub fn theme_paints_positive_bars_in_theme_color_test() {
  let svg =
    render.bar_svg(
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
    render.bar_svg(
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
    render.bar_svg(
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
    render.bar_svg(
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
  let svg = render.bar_svg([1.0, 2.0, 3.0], sparklinekit.default_bar_options)
  svg
  |> string.contains("rx=\"")
  |> should.be_false
}

pub fn background_color_renders_background_rect_test() {
  let svg =
    render.bar_svg(
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
    render.bar_svg(
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
    render.bar_svg(
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
    render.bar_svg(
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
    render.bar_svg(
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

// A constant negative series stood on the bottom edge like a positive one.
pub fn constant_negative_bars_hang_from_the_top_test() {
  let svg = render.bar_svg([-3.0, -3.0], sparklinekit.default_bar_options)
  assert string.contains(svg, "y=\"0.0\" width=\"99.0\" height=\"20.0\"")
  let positive = render.bar_svg([3.0, 3.0], sparklinekit.default_bar_options)
  assert string.contains(positive, "y=\"20.0\" width=\"99.0\" height=\"20.0\"")
}

// A corner radius larger than half the bar width is drawn as half the
// width, in SVG and in PNG.
pub fn corner_radius_is_at_most_half_the_bar_width_test() {
  let options =
    sparklinekit.BarOptions(
      ..sparklinekit.default_bar_options,
      width: 4,
      height: 20,
      gap: 0.0,
    )
  let large = sparklinekit.BarOptions(..options, corner_radius: 5.0)
  let half = sparklinekit.BarOptions(..options, corner_radius: 1.0)
  assert render.bar_svg([1.0, 3.0], large)
    == string.concat([
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4\" height=\"20\" viewBox=\"0 0 4 20\" preserveAspectRatio=\"none\">",
      "<rect x=\"0.0\" y=\"13.33\" width=\"2.0\" height=\"6.67\" fill=\"currentColor\" rx=\"1.0\"/>",
      "<rect x=\"2.0\" y=\"0.0\" width=\"2.0\" height=\"20.0\" fill=\"currentColor\" rx=\"1.0\"/>",
      "</svg>",
    ])
  assert render.bar_png([1.0, 3.0], large) == render.bar_png([1.0, 3.0], half)
}

pub fn constant_zero_bars_stand_on_the_bottom_test() {
  let svg =
    render.bar_svg(
      [0.0, 0.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 4,
        height: 20,
        gap: 0.0,
      ),
    )
  assert string.contains(
    svg,
    string.concat([
      "<rect x=\"0.0\" y=\"10.0\" width=\"2.0\" height=\"10.0\" fill=\"currentColor\"/>",
      "<rect x=\"2.0\" y=\"10.0\" width=\"2.0\" height=\"10.0\" fill=\"currentColor\"/>",
    ]),
  )
}

// A gap as wide as each bar's share of the width, or wider, is dropped.
pub fn gap_without_room_for_the_bars_is_dropped_test() {
  let options =
    sparklinekit.BarOptions(
      ..sparklinekit.default_bar_options,
      width: 4,
      height: 20,
    )
  let expected =
    render.bar_svg(
      [1.0, 2.0, 3.0, 4.0],
      sparklinekit.BarOptions(..options, gap: 0.0),
    )
  assert string.contains(expected, "width=\"1.0\" height=\"5.0\"")
  assert render.bar_svg(
      [1.0, 2.0, 3.0, 4.0],
      sparklinekit.BarOptions(..options, gap: 1.0),
    )
    == expected
  assert render.bar_svg(
      [1.0, 2.0, 3.0, 4.0],
      sparklinekit.BarOptions(..options, gap: 2.0),
    )
    == expected
}

// A value too small to see is drawn as a one-pixel bar next to zero, on
// its own side when it fits there, including when it fits exactly.
pub fn hairline_bars_at_the_edge_of_the_canvas_test() {
  let options =
    sparklinekit.BarOptions(
      ..sparklinekit.default_bar_options,
      height: 10,
      gap: 0.0,
    )
  // Zero is one pixel below the top: a zero bar fits above it.
  assert string.contains(
    render.bar_svg(
      [-9.0, 1.0, 0.0],
      sparklinekit.BarOptions(..options, width: 3),
    ),
    "<rect x=\"2.0\" y=\"0.0\" width=\"1.0\" height=\"1.0\" fill=\"currentColor\"/>",
  )
  // Zero is less than a pixel above the bottom: a small negative bar is
  // drawn above zero.
  assert string.contains(
    render.bar_svg([9.0, -0.01], sparklinekit.BarOptions(..options, width: 2)),
    "<rect x=\"1.0\" y=\"8.99\" width=\"1.0\" height=\"1.0\" fill=\"#EF4444\"/>",
  )
  // Zero is exactly a pixel above the bottom: it fits below.
  assert string.contains(
    render.bar_svg(
      [9.0, -1.0, -0.0001],
      sparklinekit.BarOptions(..options, width: 3),
    ),
    "<rect x=\"2.0\" y=\"9.0\" width=\"1.0\" height=\"1.0\" fill=\"#EF4444\"/>",
  )
}
