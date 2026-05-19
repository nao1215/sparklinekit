//// Named colour schemes for the SVG and PNG renderers.
////
//// ```gleam
//// import sparklinekit/line
//// import sparklinekit/theme
////
//// pub fn ocean_chart() -> String {
////   line.new([1.0, 5.0, 3.0, 8.0, 4.0])
////   |> line.with_theme(theme.ocean())
////   |> line.with_area_fill(True)
////   |> line.to_svg
//// }
//// ```
////
//// Each theme is a small bundle of four CSS colour strings:
////
//// - `foreground` — the stroke or main fill colour.
//// - `background` — the colour for the chart's background rectangle.
//// - `area`       — the fill colour used under the line when
////   `with_area_fill(True)` is set.
//// - `negative`   — the colour used for negative bars in `bar`
////   charts; line charts ignore it.
////
//// Pass a theme to `line.with_theme` / `bar.with_theme` to set all
//// four slots at once. The individual `with_color`,
//// `with_background_color`, `with_area_color`, and
//// `with_negative_color` helpers override one slot at a time and can
//// be chained after `with_theme` to tweak it.

/// Opaque colour scheme. Use the named constructors below
/// (`ocean()`, `forest()`, ...) and the accessor functions
/// (`foreground/1`, `background/1`, ...) — the constructor is private
/// so the set of slots can grow without breaking callers.
pub opaque type Theme {
  Theme(foreground: String, background: String, area: String, negative: String)
}

/// Cool blue tones on a soft sky-tinted canvas. The default theme
/// applied by the README sample generator.
pub fn ocean() -> Theme {
  Theme(
    foreground: "#1F6FEB",
    background: "#F0F6FF",
    area: "#1F6FEB33",
    negative: "#94A3B8",
  )
}

/// Green / sage palette suitable for finance "up" charts.
pub fn forest() -> Theme {
  Theme(
    foreground: "#22A06B",
    background: "#F2FBF5",
    area: "#22A06B2E",
    negative: "#E5484D",
  )
}

/// Warm orange and coral, useful for "attention" or alert
/// dashboards.
pub fn sunset() -> Theme {
  Theme(
    foreground: "#F76808",
    background: "#FFF7ED",
    area: "#F7680833",
    negative: "#7E22CE",
  )
}

/// Grayscale palette — prints cleanly and embeds well in monochrome
/// dashboards.
pub fn mono() -> Theme {
  Theme(
    foreground: "#1F2937",
    background: "#F9FAFB",
    area: "#1F293726",
    negative: "#9CA3AF",
  )
}

/// High-contrast neon palette for dark backgrounds.
pub fn neon() -> Theme {
  Theme(
    foreground: "#22D3EE",
    background: "#0F172A",
    area: "#22D3EE33",
    negative: "#F472B6",
  )
}

/// Soft pastel palette, low-saturation foreground over a paper-white
/// canvas.
pub fn pastel() -> Theme {
  Theme(
    foreground: "#A78BFA",
    background: "#FAF5FF",
    area: "#A78BFA33",
    negative: "#FB7185",
  )
}

/// Default theme used when no `with_theme` call is made: CSS
/// `currentColor` for the foreground, no background fill, an
/// auto-derived area tint, and a fallback negative bar colour.
pub fn default() -> Theme {
  Theme(
    foreground: "currentColor",
    background: "none",
    area: "currentColor",
    negative: "#E5484D",
  )
}

/// The chart's main stroke / fill colour.
pub fn foreground(theme: Theme) -> String {
  theme.foreground
}

/// Background rectangle colour. The string `"none"` disables the
/// background rectangle entirely (the renderer omits it from the
/// SVG / leaves PNG pixels transparent).
pub fn background(theme: Theme) -> String {
  theme.background
}

/// Area-fill colour used under the line in `line` charts when
/// `with_area_fill(True)` is set.
pub fn area(theme: Theme) -> String {
  theme.area
}

/// Colour applied to negative bars in `bar` charts. Ignored by
/// `line` charts.
pub fn negative(theme: Theme) -> String {
  theme.negative
}
