//// sparklinekit — sparkline generator for Gleam.
////
//// Renderers live in dedicated modules:
////
//// - [`sparklinekit/unicode`](./sparklinekit/unicode.html) for
////   terminal output using the eight Unicode block characters
////   `▁▂▃▄▅▆▇█`.
//// - [`sparklinekit/line`](./sparklinekit/line.html) for SVG and PNG
////   line sparklines (`to_svg` / `to_png`).
//// - [`sparklinekit/bar`](./sparklinekit/bar.html) for SVG and PNG
////   bar sparklines (`to_svg` / `to_png`).
//// - [`sparklinekit/theme`](./sparklinekit/theme.html) for the
////   bundled colour schemes (`ocean`, `forest`, `sunset`, `mono`,
////   `neon`, `pastel`).
////
//// ```gleam
//// import sparklinekit/bar
//// import sparklinekit/line
//// import sparklinekit/theme
//// import sparklinekit/unicode
////
//// pub fn examples() -> #(String, String, String, BitArray) {
////   let u = unicode.render_ints([1, 5, 22, 13, 5, 2, 7])
////   let l =
////     line.new_ints([1, 5, 3, 8, 4])
////     |> line.with_theme(theme.ocean())
////     |> line.with_area_fill(True)
////     |> line.to_svg
////   let b =
////     bar.new_ints([3, 7, 2, 9, 5])
////     |> bar.with_theme(theme.sunset())
////     |> bar.with_corner_radius(2.0)
////     |> bar.to_svg
////   let p =
////     line.new_ints([1, 5, 3, 8, 4])
////     |> line.with_theme(theme.ocean())
////     |> line.with_area_fill(True)
////     |> line.to_png
////   #(u, l, b, p)
//// }
//// ```

/// The package version, kept in sync with `gleam.toml`.
///
/// Releases that bump `gleam.toml` without bumping this constant (or
/// vice versa) are caught by `package_version_test`.
pub fn package_version() -> String {
  "0.1.0"
}
