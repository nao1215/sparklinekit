//// The chart renderers unwrapped, for tests whose colours are known to be
//// valid. A test that checks colour validation calls `sparklinekit`
//// directly.

import sparklinekit

pub fn line_svg(values: List(Float), options: sparklinekit.LineOptions) -> String {
  let assert Ok(svg) = sparklinekit.line_svg(values, options)
  svg
}

pub fn line_png(
  values: List(Float),
  options: sparklinekit.LineOptions,
) -> BitArray {
  let assert Ok(png) = sparklinekit.line_png(values, options)
  png
}

pub fn bar_svg(values: List(Float), options: sparklinekit.BarOptions) -> String {
  let assert Ok(svg) = sparklinekit.bar_svg(values, options)
  svg
}

pub fn bar_png(values: List(Float), options: sparklinekit.BarOptions) -> BitArray {
  let assert Ok(png) = sparklinekit.bar_png(values, options)
  png
}
