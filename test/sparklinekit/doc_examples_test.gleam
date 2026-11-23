//// Checks the values claimed by the examples in the doc comments of
//// `src/sparklinekit.gleam`.

import gleam/bit_array
import gleam/string
import sparklinekit.{BarOptions, LineOptions}

pub fn blocks_examples_test() {
  assert sparklinekit.blocks([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]) == "▁▂█▅▂▁▃"
  assert sparklinekit.blocks([]) == ""
  assert sparklinekit.blocks([5.0, 5.0]) == "▄▄"
}

pub fn line_svg_examples_test() {
  let assert Ok(svg) =
    sparklinekit.line_svg([1.0, 5.0, 3.0], sparklinekit.default_line_options)
  assert string.contains(
    svg,
    "<path fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.0\"",
  )
  assert string.contains(svg, "d=\"M 1.0 59.0 L 120.0 1.0 L 239.0 30.0\"/>")
  assert sparklinekit.line_svg([], sparklinekit.default_line_options)
    == Ok(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"60\" viewBox=\"0 0 240 60\" preserveAspectRatio=\"none\"></svg>",
    )
}

pub fn module_example_test() {
  let assert Ok(svg) =
    sparklinekit.line_svg(
      [1.0, 5.0, 3.0, 8.0, 4.0],
      LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        area: sparklinekit.GradientArea,
      ),
    )
  assert string.contains(svg, "<linearGradient")
  assert string.contains(svg, "stroke=\"#2563EB\"")
}

pub fn bar_svg_example_test() {
  let assert Ok(svg) =
    sparklinekit.bar_svg(
      [3.0, -2.0, 5.0],
      BarOptions(..sparklinekit.default_bar_options, theme: sparklinekit.forest),
    )
  assert string.contains(svg, "fill=\"#10B981\"")
  assert string.contains(svg, "fill=\"#EF4444\"")
}

pub fn png_size_example_test() {
  // The docs say an image is about width * height * 4 bytes.
  let assert Ok(png) =
    sparklinekit.line_png([1.0, 5.0, 3.0], sparklinekit.default_line_options)
  let size = bit_array.byte_size(png)
  assert size > 240 * 60 * 4
  assert size < 240 * 60 * 4 + 1000
}
