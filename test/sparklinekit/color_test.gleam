//// Colour validation. The chart renderers accept `#rgb`, `#rgba`,
//// `#rrggbb`, `#rrggbbaa`, `none` and `currentColor`, and return
//// `Error(InvalidColor(..))` for anything else before drawing, so SVG and
//// PNG output never disagree about what a colour means.

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import render
import sparklinekit.{type InvalidColor, InvalidColor}

const values = [1.0, 5.0, 3.0, -2.0]

fn line(theme: sparklinekit.Theme) -> sparklinekit.LineOptions {
  sparklinekit.LineOptions(
    ..sparklinekit.default_line_options,
    width: 30,
    height: 10,
    theme:,
    area: sparklinekit.GradientArea,
    spot_radius: 2.0,
  )
}

fn bar(theme: sparklinekit.Theme) -> sparklinekit.BarOptions {
  sparklinekit.BarOptions(
    ..sparklinekit.default_bar_options,
    width: 30,
    height: 10,
    theme:,
  )
}

// Every renderer returns the same result for the theme.
fn all_results(theme: sparklinekit.Theme) -> List(Result(Nil, InvalidColor)) {
  [
    sparklinekit.line_svg(values, line(theme)) |> drop,
    sparklinekit.line_png(values, line(theme)) |> drop,
    sparklinekit.bar_svg(values, bar(theme)) |> drop,
    sparklinekit.bar_png(values, bar(theme)) |> drop,
  ]
}

fn drop(result: Result(a, InvalidColor)) -> Result(Nil, InvalidColor) {
  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

const rejected = [
  "", " ", "red", "blue", "transparent", "#", "#12", "#12345", "#1234567",
  "#123456789", "#ggg", "#12345g", "rgb(0, 0, 0)", "hsl(0 0% 0%)", " #fff",
  "#fff ", "url(#x)", "currentColor;", "\"/><script>alert(1)</script>",
  "red\" onload=\"alert(1)", "#fff\" onload=\"alert(1)", "none\"", "inherit",
]

const accepted = [
  "#abc", "#ABC", "#abcd", "#aabbcc", "#AaBbCc", "#aabbccdd", "none", "NONE",
  "None", "currentColor", "currentcolor", "CURRENTCOLOR",
]

pub fn every_field_rejects_unsupported_colours_test() {
  use value <- list.each(rejected)
  let base = sparklinekit.ocean
  assert all_results(sparklinekit.Theme(..base, foreground: value))
    == list.repeat(Error(InvalidColor(field: "foreground", value:)), 4)
  assert all_results(sparklinekit.Theme(..base, background: value))
    == list.repeat(Error(InvalidColor(field: "background", value:)), 4)
  assert all_results(sparklinekit.Theme(..base, area: Some(value)))
    == list.repeat(Error(InvalidColor(field: "area", value:)), 4)
  assert all_results(sparklinekit.Theme(..base, negative: value))
    == list.repeat(Error(InvalidColor(field: "negative", value:)), 4)
}

pub fn every_field_accepts_supported_colours_test() {
  use value <- list.each(accepted)
  let base = sparklinekit.ocean
  let ok = list.repeat(Ok(Nil), 4)
  assert all_results(sparklinekit.Theme(..base, foreground: value)) == ok
  assert all_results(sparklinekit.Theme(..base, background: value)) == ok
  assert all_results(sparklinekit.Theme(..base, area: Some(value))) == ok
  assert all_results(sparklinekit.Theme(..base, negative: value)) == ok
}

pub fn spot_colour_is_validated_test() {
  use value <- list.each(rejected)
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      spot_radius: 2.0,
      spot_color: Some(value),
    )
  let error = Error(InvalidColor(field: "spot_color", value:))
  assert drop(sparklinekit.line_svg(values, options)) == error
  assert drop(sparklinekit.line_png(values, options)) == error
}

pub fn spot_colour_is_validated_without_a_dot_test() {
  // The colour is checked even when the radius draws no dot, so a typo
  // shows up before the radius is turned on.
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      spot_color: Some("red"),
    )
  assert drop(sparklinekit.line_svg(values, options))
    == Error(InvalidColor(field: "spot_color", value: "red"))
}

pub fn the_first_invalid_field_is_reported_test() {
  let theme =
    sparklinekit.Theme(
      foreground: "red",
      background: "white",
      area: Some("pink"),
      negative: "grey",
    )
  assert drop(sparklinekit.line_svg(values, line(theme)))
    == Error(InvalidColor(field: "foreground", value: "red"))
}

pub fn every_named_theme_is_valid_test() {
  use theme <- list.each([
    sparklinekit.default_theme, sparklinekit.ocean, sparklinekit.forest,
    sparklinekit.sunset, sparklinekit.mono, sparklinekit.neon,
    sparklinekit.pastel, sparklinekit.crimson, sparklinekit.slate,
    sparklinekit.amber, sparklinekit.midnight,
  ])
  assert all_results(theme) == list.repeat(Ok(Nil), 4)
  assert drop(sparklinekit.line_svg([], line(theme))) == Ok(Nil)
}

pub fn an_empty_series_still_checks_the_colours_test() {
  let theme = sparklinekit.Theme(..sparklinekit.ocean, foreground: "red")
  assert drop(sparklinekit.line_svg([], line(theme)))
    == Error(InvalidColor(field: "foreground", value: "red"))
  assert drop(sparklinekit.bar_png([], bar(theme)))
    == Error(InvalidColor(field: "foreground", value: "red"))
}

// Keywords are written in their canonical spelling.
pub fn keywords_are_written_canonically_test() {
  let theme =
    sparklinekit.Theme(
      foreground: "CURRENTCOLOR",
      background: "NONE",
      area: None,
      negative: "#EF4444",
    )
  let svg = render.line_svg(values, line(theme))
  assert string.contains(svg, "stroke=\"currentColor\"")
  assert !string.contains(svg, "CURRENTCOLOR")
  assert !string.contains(svg, "<rect")
}

// A colour of `none` draws nothing, in SVG and PNG alike.
pub fn none_draws_nothing_in_both_formats_test() {
  let blank_line =
    line(sparklinekit.Theme(
      foreground: "none",
      background: "none",
      area: None,
      negative: "none",
    ))
  let blank_bar =
    bar(sparklinekit.Theme(
      foreground: "none",
      background: "none",
      area: None,
      negative: "none",
    ))
  let empty_line =
    render.line_png(
      [],
      sparklinekit.LineOptions(..blank_line, spot_radius: 0.0),
    )
  assert render.line_png(values, blank_line) == empty_line
  assert render.bar_png(values, blank_bar) == render.bar_png([], blank_bar)
  let svg = render.line_svg(values, blank_line)
  assert !string.contains(svg, "<path")
  assert !string.contains(svg, "<circle")
  let svg = render.bar_svg(values, blank_bar)
  assert !string.contains(svg, "<rect")
}

// Under a `currentColor` line, the gradient area fades in SVG as it does
// in PNG. It used to be drawn flat in SVG.
pub fn current_colour_gradient_fades_in_svg_test() {
  let svg = render.line_svg(values, line(sparklinekit.default_theme))
  assert string.contains(
    svg,
    "<stop offset=\"0%\" stop-color=\"currentColor\" stop-opacity=\"0.22\"/>",
  )
  assert string.contains(svg, "stop-color=\"currentColor\" stop-opacity=\"0\"")
}

pub fn current_colour_is_black_in_png_test() {
  let current =
    sparklinekit.Theme(..sparklinekit.default_theme, foreground: "currentColor")
  let black =
    sparklinekit.Theme(..sparklinekit.default_theme, foreground: "#000")
  assert render.line_png(values, line(current))
    == render.line_png(values, line(black))
  assert render.bar_png(values, bar(current))
    == render.bar_png(values, bar(black))
}

pub fn explicit_current_colour_area_matches_in_both_formats_test() {
  let current =
    sparklinekit.Theme(..sparklinekit.ocean, area: Some("currentColor"))
  let black = sparklinekit.Theme(..sparklinekit.ocean, area: Some("#000000"))
  assert render.line_png(values, line(current))
    == render.line_png(values, line(black))
  let svg = render.line_svg(values, line(current))
  assert string.contains(
    svg,
    "<stop offset=\"0%\" stop-color=\"currentColor\" stop-opacity=\"1.0\"/>",
  )
}

// Nothing the caller passes can end the attribute it is written into.
pub fn no_colour_can_inject_markup_test() {
  use value <- list.each(rejected)
  let theme = sparklinekit.Theme(..sparklinekit.ocean, foreground: value)
  assert sparklinekit.line_svg(values, line(theme))
    == Error(InvalidColor(field: "foreground", value:))
}
