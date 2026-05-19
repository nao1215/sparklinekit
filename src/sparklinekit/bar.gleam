//// SVG and PNG bar sparklines.
////
//// ```gleam
//// import sparklinekit/bar
//// import sparklinekit/theme
////
//// pub fn revenue() -> String {
////   bar.new([3.0, 7.0, 2.0, 9.0, 5.0])
////   |> bar.with_theme(theme.sunset())
////   |> bar.with_corner_radius(2.0)
////   |> bar.to_svg
//// }
//// ```
////
//// Positive and negative values share a zero baseline: positives
//// rise above it, negatives fall below. `with_negative_color`
//// paints the falling bars in a contrasting colour so win/loss
//// charts read at a glance.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree
import sparklinekit/internal/color.{type Rgba}
import sparklinekit/internal/format
import sparklinekit/internal/png
import sparklinekit/internal/raster
import sparklinekit/internal/scale
import sparklinekit/theme.{type Theme}

const default_width: Int = 200

const default_height: Int = 40

const default_gap: Float = 1.0

const default_corner_radius: Float = 0.0

/// Minimum drawn height for a bar with a finite value. Zero-value
/// bars (and any bar that mathematically collapses to a height of
/// zero) are forced up to this hairline so the reader can see the
/// data point at the baseline instead of perceiving a missing entry.
const min_visible_height: Float = 1.0

/// Opaque builder for a bar sparkline.
pub opaque type Builder {
  Builder(
    values: List(Float),
    theme: Theme,
    color: String,
    background: String,
    negative_color: Option(String),
    width: Int,
    height: Int,
    gap: Float,
    corner_radius: Float,
  )
}

/// Start a new bar sparkline builder.
///
/// Defaults: 200x40 viewBox, `currentColor` fill, the default
/// theme's negative colour (`#EF4444`) for bars below the zero
/// baseline, 1.0px gap between bars, no rounded corners, no
/// background.
pub fn new(values: List(Float)) -> Builder {
  let base = theme.default()
  Builder(
    values: values,
    theme: base,
    color: theme.foreground(base),
    background: theme.background(base),
    negative_color: Some(theme.negative(base)),
    width: default_width,
    height: default_height,
    gap: default_gap,
    corner_radius: default_corner_radius,
  )
}

/// Start a builder from a list of `Int` values.
pub fn new_ints(values: List(Int)) -> Builder {
  new(list.map(values, int.to_float))
}

/// Replace the data series after construction.
pub fn with_values(builder: Builder, values: List(Float)) -> Builder {
  Builder(..builder, values: values)
}

/// Replace the data series with a list of `Int`s.
pub fn with_int_values(builder: Builder, values: List(Int)) -> Builder {
  Builder(..builder, values: list.map(values, int.to_float))
}

/// Apply every colour slot from `theme`. The theme's `negative`
/// colour is used for bars below the zero baseline; calling
/// [`with_negative_color`](#with_negative_color) afterwards overrides
/// just that slot.
pub fn with_theme(builder: Builder, theme: Theme) -> Builder {
  Builder(
    ..builder,
    theme: theme,
    color: theme.foreground(theme),
    background: theme.background(theme),
    negative_color: Some(theme.negative(theme)),
  )
}

/// Set the positive-bar fill colour (any CSS colour string).
pub fn with_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, color: color)
}

/// Set the background rectangle colour. `"none"` disables the
/// background.
pub fn with_background_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, background: color)
}

/// Use a separate colour for bars below the zero baseline.
pub fn with_negative_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, negative_color: Some(color))
}

/// Set the viewBox / pixel dimensions. Non-positive values are
/// normalised to `1`.
pub fn with_size(builder: Builder, width: Int, height: Int) -> Builder {
  Builder(
    ..builder,
    width: positive_or_one(width),
    height: positive_or_one(height),
  )
}

/// Set the gap between adjacent bars in user units. The per-bar
/// width is derived from the total width, bar count, and this gap.
/// Negative values are clamped to `0.0`.
pub fn with_bar_gap(builder: Builder, gap: Float) -> Builder {
  Builder(..builder, gap: non_negative_float(gap))
}

/// Set the corner radius in user units. The renderer clamps the
/// radius to half the smaller side of each individual bar so the
/// shape stays a rectangle / capsule rather than turning into a
/// circle.
pub fn with_corner_radius(builder: Builder, radius: Float) -> Builder {
  Builder(..builder, corner_radius: non_negative_float(radius))
}

/// Render the builder to a self-contained `<svg>` element string.
pub fn to_svg(builder: Builder) -> String {
  let Builder(
    values,
    _theme,
    color,
    background,
    negative_color,
    width,
    height,
    gap,
    radius,
  ) = builder
  let negative_color = case negative_color {
    Some(c) -> c
    None -> color
  }
  let bg_layer = background_rect(width, height, background)
  let bars =
    rect_body(values, width, height, color, negative_color, gap, radius)
  string_tree.new()
  |> string_tree.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"")
  |> string_tree.append(int.to_string(width))
  |> string_tree.append("\" height=\"")
  |> string_tree.append(int.to_string(height))
  |> string_tree.append("\" viewBox=\"0 0 ")
  |> string_tree.append(int.to_string(width))
  |> string_tree.append(" ")
  |> string_tree.append(int.to_string(height))
  |> string_tree.append("\" preserveAspectRatio=\"none\">")
  |> string_tree.append_tree(bg_layer)
  |> string_tree.append_tree(bars)
  |> string_tree.append("</svg>")
  |> string_tree.to_string
}

/// Render the builder to PNG bytes (8-bit RGBA truecolor). The
/// viewBox dimensions double as the pixel size.
///
/// The PNG IDAT payload is written using DEFLATE's uncompressed
/// "store" blocks (no Huffman coding) so the encoder stays pure
/// Gleam with zero FFI. As a result the output is roughly
/// `width * height * 4` bytes regardless of how uniform the image
/// is — for visual size context, prefer SVG.
pub fn to_png(builder: Builder) -> BitArray {
  let Builder(
    values,
    theme,
    color,
    background,
    negative_color,
    width,
    height,
    gap,
    radius,
  ) = builder
  let fg = parse_string_colour(color, theme.foreground(theme))
  let neg = case negative_color {
    Some(c) -> parse_string_colour(c, theme.negative(theme))
    None -> fg
  }
  let bg = case background {
    "none" -> color.transparent
    other -> parse_string_colour_or(other, color.transparent)
  }
  let canvas = raster.new(width, height, bg)
  let canvas = paint_bars(canvas, values, width, height, fg, neg, gap, radius)
  png.encode(raster.to_grid(canvas), width: width, height: height)
}

fn background_rect(
  width: Int,
  height: Int,
  background: String,
) -> string_tree.StringTree {
  case background == "none" || background == "" {
    True -> string_tree.new()
    False ->
      string_tree.new()
      |> string_tree.append("<rect x=\"0\" y=\"0\" width=\"")
      |> string_tree.append(int.to_string(width))
      |> string_tree.append("\" height=\"")
      |> string_tree.append(int.to_string(height))
      |> string_tree.append("\" fill=\"")
      |> string_tree.append(escape_attribute(background))
      |> string_tree.append("\"/>")
  }
}

fn rect_body(
  values: List(Float),
  width: Int,
  height: Int,
  color: String,
  negative_color: String,
  gap: Float,
  radius: Float,
) -> string_tree.StringTree {
  case values {
    [] -> string_tree.new()
    _ -> {
      let layout = compute_layout(values, width, height, gap)
      let pos_fill = escape_attribute(color)
      let neg_fill = escape_attribute(negative_color)
      list.fold(layout.rects, string_tree.new(), fn(tree, rect) {
        let fill = case rect.value <. 0.0 {
          True -> neg_fill
          False -> pos_fill
        }
        string_tree.append(tree, render_rect_svg(rect, fill, radius))
      })
    }
  }
}

fn render_rect_svg(rect: Rect, fill: String, radius: Float) -> String {
  let r =
    radius
    |> float.min(rect.width /. 2.0)
    |> float.min(rect.height /. 2.0)
    |> float.max(0.0)
  let radius_attr = case r >. 0.0 {
    False -> ""
    True -> " rx=\"" <> format.coord(r) <> "\""
  }
  "<rect x=\""
  <> format.coord(rect.x)
  <> "\" y=\""
  <> format.coord(rect.y)
  <> "\" width=\""
  <> format.coord(rect.width)
  <> "\" height=\""
  <> format.coord(rect.height)
  <> "\" fill=\""
  <> fill
  <> "\""
  <> radius_attr
  <> "/>"
}

type Rect {
  Rect(x: Float, y: Float, width: Float, height: Float, value: Float)
}

type Layout {
  Layout(rects: List(Rect))
}

fn compute_layout(
  values: List(Float),
  width: Int,
  height: Int,
  gap: Float,
) -> Layout {
  // Clamp every value to the safe finite range so the per-value
  // subtractions in `y_coord` cannot overflow on adversarial input.
  // `scale.min_max` does its own clamping internally, but the
  // per-bar `value - y_min` further down has no such guard.
  let values = list.map(values, scale.clamp_finite)
  let width_f = int.to_float(width)
  let height_f = int.to_float(height)
  let count = list.length(values)
  let step = width_f /. int.to_float(count)
  let bar_w = case step -. gap >. 0.0 {
    True -> step -. gap
    False -> step
  }
  let #(lo, hi) = scale.min_max(values)
  let #(y_min, y_max) = effective_range(lo, hi)
  let span = y_max -. y_min
  // Degenerate case: every value is the same (or there is only one).
  // The natural normalised height would be the full canvas, which
  // looks like a solid block rather than a sparkline and is
  // inconsistent with how `line` and `unicode` render the same input
  // (a flat midline / middle block). Use half-height bars rising
  // from the bottom so the chart still says "constant value" without
  // turning into a giant rectangle.
  //
  // Note: `effective_range` extends the visible range to include zero
  // for all-positive or all-negative input, so `span > 0` is possible
  // even when every input value is identical. The check below uses
  // the *raw* lo == hi comparison to catch that.
  case lo == hi || span <=. 0.0 {
    True -> {
      let half = height_f /. 2.0
      let #(rects, _) =
        list.fold(values, #([], 0), fn(acc, value) {
          let #(rs, i) = acc
          let x = int.to_float(i) *. step
          #(
            [
              Rect(x: x, y: half, width: bar_w, height: half, value: value),
              ..rs
            ],
            i + 1,
          )
        })
      Layout(rects: list.reverse(rects))
    }
    False -> {
      let baseline_y = baseline_y(height_f, y_min, span)
      let #(rects, _) =
        list.fold(values, #([], 0), fn(acc, value) {
          let #(rs, i) = acc
          let x = int.to_float(i) *. step
          let y_value = y_coord(value, y_min, span, height_f)
          let #(safe_y, safe_h) = rect_dimensions(value, y_value, baseline_y)
          #(
            [
              Rect(x: x, y: safe_y, width: bar_w, height: safe_h, value: value),
              ..rs
            ],
            i + 1,
          )
        })
      Layout(rects: list.reverse(rects))
    }
  }
}

/// Resolve the SVG/PNG rect dimensions for a single bar in a
/// non-degenerate (mixed-sign or simple positive) layout. Falls back
/// to a 1-pixel hairline anchored at the baseline when the raw rect
/// height would be zero, so a value of exactly zero still leaves a
/// visible mark.
fn rect_dimensions(
  value: Float,
  y_value: Float,
  baseline_y: Float,
) -> #(Float, Float) {
  let #(rect_y, rect_h) = case value >=. 0.0 {
    True -> #(y_value, baseline_y -. y_value)
    False -> #(baseline_y, y_value -. baseline_y)
  }
  case rect_h >. min_visible_height {
    True -> #(rect_y, rect_h)
    False -> hairline_at_baseline(value, baseline_y)
  }
}

fn hairline_at_baseline(value: Float, baseline_y: Float) -> #(Float, Float) {
  case value >=. 0.0 {
    True -> #(baseline_y -. min_visible_height, min_visible_height)
    False -> #(baseline_y, min_visible_height)
  }
}

fn paint_bars(
  canvas: raster.Canvas,
  values: List(Float),
  width: Int,
  height: Int,
  fg: Rgba,
  neg: Rgba,
  gap: Float,
  radius: Float,
) -> raster.Canvas {
  let layout = compute_layout(values, width, height, gap)
  list.fold(layout.rects, canvas, fn(c, rect) {
    let colour = case rect.value <. 0.0 {
      True -> neg
      False -> fg
    }
    case rect.height <=. 0.0 {
      True -> c
      False ->
        raster.fill_rounded_rect(
          c,
          rect.x,
          rect.y,
          rect.width,
          rect.height,
          radius,
          colour,
        )
    }
  })
}

fn effective_range(lo: Float, hi: Float) -> #(Float, Float) {
  case lo >=. 0.0, hi <=. 0.0 {
    True, _ -> #(0.0, hi)
    _, True -> #(lo, 0.0)
    _, _ -> #(lo, hi)
  }
}

fn baseline_y(height_f: Float, y_min: Float, span: Float) -> Float {
  case span <=. 0.0 {
    True -> height_f
    False -> height_f -. { 0.0 -. y_min } /. span *. height_f
  }
}

fn y_coord(value: Float, y_min: Float, span: Float, height_f: Float) -> Float {
  case span <=. 0.0 {
    True -> height_f
    False -> height_f -. { value -. y_min } /. span *. height_f
  }
}

fn positive_or_one(value: Int) -> Int {
  case value < 1 {
    True -> 1
    False -> value
  }
}

fn non_negative_float(value: Float) -> Float {
  case value <. 0.0 {
    True -> 0.0
    False -> value
  }
}

fn escape_attribute(value: String) -> String {
  value
  |> string.replace("&", "&amp;")
  |> string.replace("\"", "&quot;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}

fn parse_string_colour(value: String, theme_fallback: String) -> Rgba {
  case color.parse_hex(value) {
    Ok(rgba) -> rgba
    Error(_) -> color.parse_or(theme_fallback, fallback: color.black)
  }
}

fn parse_string_colour_or(value: String, fallback: Rgba) -> Rgba {
  case color.parse_hex(value) {
    Ok(rgba) -> rgba
    Error(_) -> fallback
  }
}
