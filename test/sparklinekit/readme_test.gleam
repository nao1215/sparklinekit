//// Runs the code blocks of README.md. Each `*_sample` function is a copy
//// of a README block, and each test checks what the README says about it.
//// `latency_sample` returns the line the README prints, and `save_chart`
//// writes under `build/` instead of the working directory.

import gleam/list
import gleam/string
import simplifile
import sparklinekit.{type InvalidColor, BarOptions, LineOptions, Theme}

pub fn latency_sample() -> String {
  let latency = [12.0, 14.0, 13.0, 40.0, 85.0, 33.0, 15.0, 12.0, 11.0, 13.0]
  "latency  " <> sparklinekit.blocks(latency)
}

pub fn latency_test() {
  assert latency_sample() == "latency  ▁▁▁▄█▃▁▁▁▁"
}

pub fn revenue_chart() -> Result(String, InvalidColor) {
  sparklinekit.line_svg(
    [1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0],
    LineOptions(
      ..sparklinekit.default_line_options,
      theme: sparklinekit.ocean,
      smoothing: 0.25,
      area: sparklinekit.GradientArea,
      spot_radius: 3.0,
    ),
  )
}

pub fn revenue_chart_test() {
  let assert Ok(svg) = revenue_chart()
  assert string.starts_with(svg, "<svg xmlns=\"http://www.w3.org/2000/svg\"")
  assert string.contains(svg, "stroke=\"#2563EB\"")
  assert string.contains(svg, "<linearGradient")
  assert string.contains(svg, " C ")
  assert string.contains(svg, "<circle")
}

pub fn win_loss_chart() -> Result(String, InvalidColor) {
  sparklinekit.bar_svg(
    [3.0, -2.0, 5.0, -4.0, 6.0, -1.0],
    BarOptions(
      ..sparklinekit.default_bar_options,
      theme: Theme(
        ..sparklinekit.default_theme,
        foreground: "#22A06B",
        negative: "#E5484D",
      ),
      gap: 3.0,
    ),
  )
}

pub fn win_loss_chart_test() {
  let assert Ok(svg) = win_loss_chart()
  assert string.split(svg, "fill=\"#22A06B\"") |> list.length == 4
  assert string.split(svg, "fill=\"#E5484D\"") |> list.length == 4
}

pub fn save_chart() {
  // The default theme's colours are all valid, so this cannot fail.
  let assert Ok(png) =
    sparklinekit.line_png(
      [1.0, 5.0, 3.0, 8.0, 4.0],
      sparklinekit.default_line_options,
    )
  simplifile.write_bits(to: "build/readme-chart.png", bits: png)
}

pub fn save_chart_test() {
  assert save_chart() == Ok(Nil)
  let assert Ok(<<0x89, "PNG":utf8, _:bytes>>) =
    simplifile.read_bits("build/readme-chart.png")
  let assert Ok(Nil) = simplifile.delete("build/readme-chart.png")
}

pub fn empty_series_test() {
  assert sparklinekit.blocks([]) == ""
  let assert Ok(svg) = sparklinekit.bar_svg([], sparklinekit.default_bar_options)
  assert !string.contains(svg, "<rect")
}

pub fn constant_series_test() {
  assert sparklinekit.blocks([5.0, 5.0, 5.0]) == "▄▄▄"
  let assert Ok(svg) =
    sparklinekit.bar_svg([5.0], sparklinekit.default_bar_options)
  assert string.contains(svg, "y=\"20.0\"")
  assert string.contains(svg, "height=\"20.0\"")
}
