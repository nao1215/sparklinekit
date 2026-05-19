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

/// Classic vivid blue on white — a sensible default for product
/// dashboards. Foreground is Tailwind `blue-600`.
pub fn ocean() -> Theme {
  Theme(
    foreground: "#2563EB",
    background: "#FFFFFF",
    area: "#2563EB33",
    negative: "#94A3B8",
  )
}

/// Emerald green paired with a red negative — the canonical
/// "finance up / down" palette.
pub fn forest() -> Theme {
  Theme(
    foreground: "#10B981",
    background: "#FFFFFF",
    area: "#10B98133",
    negative: "#EF4444",
  )
}

/// Warm orange — good for attention or "trending" indicators.
pub fn sunset() -> Theme {
  Theme(
    foreground: "#F97316",
    background: "#FFFFFF",
    area: "#F9731633",
    negative: "#7C3AED",
  )
}

/// Near-black on pure white — print-friendly and embeds cleanly in
/// monochrome dashboards.
pub fn mono() -> Theme {
  Theme(
    foreground: "#0F172A",
    background: "#FFFFFF",
    area: "#0F172A29",
    negative: "#94A3B8",
  )
}

/// High-contrast cyan on near-black — designed for dark UIs.
pub fn neon() -> Theme {
  Theme(
    foreground: "#22D3EE",
    background: "#020617",
    area: "#22D3EE33",
    negative: "#F472B6",
  )
}

/// Soft violet on a paper-white canvas — low-key, design-focused.
pub fn pastel() -> Theme {
  Theme(
    foreground: "#A78BFA",
    background: "#FAF5FF",
    area: "#A78BFA33",
    negative: "#FB7185",
  )
}

/// Saturated red on white — useful for losses, alerts, or
/// "attention required" KPIs.
pub fn crimson() -> Theme {
  Theme(
    foreground: "#DC2626",
    background: "#FFFFFF",
    area: "#DC262633",
    negative: "#94A3B8",
  )
}

/// Neutral slate grey on white — corporate, low-saturation, works
/// alongside any brand colour without competing with it.
pub fn slate() -> Theme {
  Theme(
    foreground: "#475569",
    background: "#FFFFFF",
    area: "#47556933",
    negative: "#F59E0B",
  )
}

/// Golden amber on white — popular for finance and "warning"
/// indicators where red would be too strong.
pub fn amber() -> Theme {
  Theme(
    foreground: "#F59E0B",
    background: "#FFFFFF",
    area: "#F59E0B33",
    negative: "#DC2626",
  )
}

/// Off-white foreground on deep navy — a dark-mode companion to
/// `mono()`, for embedding into dark dashboards.
pub fn midnight() -> Theme {
  Theme(
    foreground: "#F8FAFC",
    background: "#020617",
    area: "#F8FAFC29",
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
    negative: "#EF4444",
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
