//// sparklinekit — sparkline generator for Gleam.
////
//// Renderers live in dedicated modules:
////
//// - [`sparklinekit/unicode`](./sparklinekit/unicode.html) for terminal
////   output using the Unicode block characters `▁▂▃▄▅▆▇█`.
//// - [`sparklinekit/line`](./sparklinekit/line.html) for SVG polyline
////   sparklines.
//// - [`sparklinekit/bar`](./sparklinekit/bar.html) for SVG bar sparklines.
////
//// ```gleam
//// import sparklinekit/bar
//// import sparklinekit/line
//// import sparklinekit/unicode
////
//// pub fn examples() -> #(String, String, String) {
////   let u = unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
////   let l =
////     line.new([1.0, 5.0, 3.0, 8.0, 4.0])
////     |> line.with_color("#378ADD")
////     |> line.to_string
////   let b =
////     bar.new([3.0, 7.0, 2.0, 9.0, 5.0])
////     |> bar.with_color("#7F77DD")
////     |> bar.to_string
////   #(u, l, b)
//// }
//// ```

/// The package version, kept in sync with `gleam.toml`.
///
/// Releases that bump `gleam.toml` without bumping this constant (or vice
/// versa) are caught by `package_version_test`.
pub fn package_version() -> String {
  "0.1.0"
}
