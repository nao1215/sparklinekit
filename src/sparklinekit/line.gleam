//// SVG and PNG line sparklines.
////
//// ```gleam
//// import sparklinekit/line
//// import sparklinekit/theme
////
//// pub fn small_chart() -> String {
////   line.new([1.0, 5.0, 3.0, 8.0, 4.0])
////   |> line.with_theme(theme.ocean())
////   |> line.with_area_fill(True)
////   |> line.to_svg
//// }
//// ```
////
//// The same `Builder` value can be rendered to either SVG ([`to_svg`](#to_svg))
//// or PNG ([`to_png`](#to_png)). The SVG output is a self-contained
//// `<svg>` element string with `preserveAspectRatio="none"`; the PNG
//// output is a `BitArray` ready for `simplifile.write_bits` or
//// `bit_array.base64_encode`.

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleam/string_tree
import sparklinekit/internal/color.{type Rgba}
import sparklinekit/internal/png
import sparklinekit/internal/raster
import sparklinekit/internal/scale
import sparklinekit/theme.{type Theme}

const default_width: Int = 200

const default_height: Int = 40

const default_stroke_width: Float = 1.5

const default_area_alpha: Float = 0.18

/// What kind of area-fill — if any — should be painted under the
/// line. Kept private so the slot can grow without affecting
/// callers; toggle it via [`with_area_fill/2`](#with_area_fill) and
/// [`with_area_color/2`](#with_area_color).
type AreaFill {
  NoArea
  AreaAuto
  AreaExplicit(String)
}

/// Opaque builder for a line sparkline. Fields are deliberately
/// hidden so renderer-internal state (the theme reference, the area
/// mode, ...) can change between minor versions without breaking
/// callers.
pub opaque type Builder {
  Builder(
    values: List(Float),
    theme: Theme,
    color: String,
    background: String,
    width: Int,
    height: Int,
    stroke_width: Float,
    area: AreaFill,
  )
}

/// Start a new line sparkline builder from a list of floats.
///
/// Defaults: 200x40 viewBox, `currentColor` stroke (inherits the
/// surrounding CSS colour), 1.5 stroke width, no background fill,
/// no area fill.
pub fn new(values: List(Float)) -> Builder {
  let base = theme.default()
  Builder(
    values: values,
    theme: base,
    color: theme.foreground(base),
    background: theme.background(base),
    width: default_width,
    height: default_height,
    stroke_width: default_stroke_width,
    area: NoArea,
  )
}

/// Start a builder from a list of `Int` values. Equivalent to
/// `new(list.map(values, int.to_float))`, exposed so the call site
/// stays free of integer-to-float adapters.
pub fn new_ints(values: List(Int)) -> Builder {
  new(list.map(values, int.to_float))
}

/// Replace the data series after construction. Useful when the
/// chart's styling is shared between multiple data sets.
pub fn with_values(builder: Builder, values: List(Float)) -> Builder {
  Builder(..builder, values: values)
}

/// Replace the data series with a list of `Int`s.
pub fn with_int_values(builder: Builder, values: List(Int)) -> Builder {
  Builder(..builder, values: list.map(values, int.to_float))
}

/// Apply every colour slot from `theme`. Subsequent
/// `with_color` / `with_background_color` / `with_area_color` calls
/// override one slot at a time.
pub fn with_theme(builder: Builder, theme: Theme) -> Builder {
  Builder(
    ..builder,
    theme: theme,
    color: theme.foreground(theme),
    background: theme.background(theme),
  )
}

/// Set the stroke colour (any CSS colour string).
///
/// The value is attribute-escaped before being written into the SVG;
/// for PNG output it is parsed as `#rgb` / `#rgba` / `#rrggbb` /
/// `#rrggbbaa` and falls back to the active theme's foreground if
/// unparseable.
pub fn with_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, color: color)
}

/// Set the background rectangle colour. `"none"` disables the
/// background (the SVG omits the `<rect>` and the PNG canvas stays
/// transparent).
pub fn with_background_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, background: color)
}

/// Toggle the area fill under the line. When enabled without
/// [`with_area_color`](#with_area_color) the renderer derives a
/// translucent tint from the stroke colour.
pub fn with_area_fill(builder: Builder, enabled: Bool) -> Builder {
  case enabled, builder.area {
    True, NoArea -> Builder(..builder, area: AreaAuto)
    True, _ -> builder
    False, _ -> Builder(..builder, area: NoArea)
  }
}

/// Explicitly set the area-fill colour. Implicitly enables the area
/// fill — pass `with_area_fill(False)` afterwards to remove it.
pub fn with_area_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, area: AreaExplicit(color))
}

/// Set the viewBox / pixel dimensions.
///
/// Non-positive values are normalised to `1` so the SVG / PNG stays
/// valid.
pub fn with_size(builder: Builder, width: Int, height: Int) -> Builder {
  Builder(
    ..builder,
    width: positive_or_one(width),
    height: positive_or_one(height),
  )
}

/// Set the stroke width in user units. Non-positive values fall
/// back to a hairline (`0.5`).
pub fn with_stroke_width(builder: Builder, stroke_width: Float) -> Builder {
  Builder(..builder, stroke_width: positive_float_or(stroke_width, 0.5))
}

/// Render the builder to a self-contained `<svg>` element string.
pub fn to_svg(builder: Builder) -> String {
  let Builder(values, _, color, background, width, height, stroke_width, area) =
    builder
  let area_layer = area_svg(values, width, height, color, stroke_width, area)
  let line_layer = polyline_body(values, width, height, color, stroke_width)
  let bg_layer = background_rect(width, height, background)
  string_tree.new()
  |> string_tree.append(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 ",
  )
  |> string_tree.append(int.to_string(width))
  |> string_tree.append(" ")
  |> string_tree.append(int.to_string(height))
  |> string_tree.append("\" preserveAspectRatio=\"none\">")
  |> string_tree.append_tree(bg_layer)
  |> string_tree.append_tree(area_layer)
  |> string_tree.append_tree(line_layer)
  |> string_tree.append("</svg>")
  |> string_tree.to_string
}

/// Backwards-compatible alias for [`to_svg`](#to_svg).
pub fn to_string(builder: Builder) -> String {
  to_svg(builder)
}

/// Render the builder to PNG bytes (8-bit RGBA truecolor).
///
/// `with_size` doubles as the pixel size for PNG — a 240x60 builder
/// produces a 240x60 image. The canvas starts at the background
/// colour (transparent when `background == "none"`) and the stroke
/// is drawn with Xiaolin Wu anti-aliasing.
pub fn to_png(builder: Builder) -> BitArray {
  let Builder(
    values,
    theme,
    color,
    background,
    width,
    height,
    stroke_width,
    area,
  ) = builder
  let fg = parse_string_colour(color, theme.foreground(theme))
  let bg = case background {
    "none" -> color.transparent
    other -> parse_string_colour_or(other, color.transparent)
  }
  let area_colour = resolve_area_colour(area, fg, theme)
  let canvas = raster.new(width, height, bg)
  let canvas = case area_colour {
    Error(_) -> canvas
    Ok(c) -> draw_area(canvas, values, width, height, c)
  }
  let canvas = draw_stroke(canvas, values, width, height, stroke_width, fg)
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

fn area_svg(
  values: List(Float),
  width: Int,
  height: Int,
  stroke_color: String,
  stroke_width: Float,
  area: AreaFill,
) -> string_tree.StringTree {
  case area, values {
    NoArea, _ -> string_tree.new()
    _, [] -> string_tree.new()
    _, [_] -> string_tree.new()
    mode, _ -> {
      let fill_colour = case mode {
        AreaExplicit(c) -> c
        AreaAuto -> auto_area_color(stroke_color)
        NoArea -> stroke_color
      }
      let points = points_string(values, width, height)
      let bottom_right =
        coordinate_pair(int.to_float(width), int.to_float(height))
      let bottom_left = coordinate_pair(0.0, int.to_float(height))
      let polygon_points = points <> " " <> bottom_right <> " " <> bottom_left
      let _ = stroke_width
      string_tree.new()
      |> string_tree.append("<polygon fill=\"")
      |> string_tree.append(escape_attribute(fill_colour))
      |> string_tree.append("\" stroke=\"none\" points=\"")
      |> string_tree.append(polygon_points)
      |> string_tree.append("\"/>")
    }
  }
}

fn polyline_body(
  values: List(Float),
  width: Int,
  height: Int,
  color: String,
  stroke_width: Float,
) -> string_tree.StringTree {
  case values {
    [] -> string_tree.new()
    _ -> {
      let points = points_string(values, width, height)
      string_tree.new()
      |> string_tree.append("<polyline fill=\"none\" stroke=\"")
      |> string_tree.append(escape_attribute(color))
      |> string_tree.append("\" stroke-width=\"")
      |> string_tree.append(float.to_string(stroke_width))
      |> string_tree.append(
        "\" stroke-linecap=\"round\" stroke-linejoin=\"round\" points=\"",
      )
      |> string_tree.append(points)
      |> string_tree.append("\"/>")
    }
  }
}

fn points_string(values: List(Float), width: Int, height: Int) -> String {
  let height_f = int.to_float(height)
  let width_f = int.to_float(width)
  let mid = height_f /. 2.0
  case values {
    [] -> ""
    [_] -> coordinate_pair(0.0, mid) <> " " <> coordinate_pair(width_f, mid)
    _ -> multi_points_string(values, width_f, height_f, mid)
  }
}

fn multi_points_string(
  values: List(Float),
  width_f: Float,
  height_f: Float,
  mid: Float,
) -> String {
  let #(lo, hi) = scale.min_max(values)
  let count = list.length(values)
  let step = case count > 1 {
    True -> width_f /. int.to_float(count - 1)
    False -> 0.0
  }
  let #(parts, _) =
    list.fold(values, #([], 0), fn(acc, value) {
      let #(strs, i) = acc
      let x = int.to_float(i) *. step
      let y = y_for(value, lo, hi, height_f, mid)
      #([coordinate_pair(x, y), ..strs], i + 1)
    })
  parts
  |> list.reverse
  |> string.join(" ")
}

fn y_for(
  value: Float,
  lo: Float,
  hi: Float,
  height_f: Float,
  mid: Float,
) -> Float {
  case lo == hi {
    True -> mid
    False -> {
      let n = scale.unit(value, lo, hi)
      height_f -. n *. height_f
    }
  }
}

fn coordinate_pair(x: Float, y: Float) -> String {
  float.to_string(x) <> "," <> float.to_string(y)
}

fn positive_or_one(value: Int) -> Int {
  case value < 1 {
    True -> 1
    False -> value
  }
}

fn positive_float_or(value: Float, default: Float) -> Float {
  case value >. 0.0 {
    True -> value
    False -> default
  }
}

fn escape_attribute(value: String) -> String {
  value
  |> string.replace("&", "&amp;")
  |> string.replace("\"", "&quot;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}

fn auto_area_color(stroke_color: String) -> String {
  case color.parse_hex(stroke_color) {
    Ok(rgba) ->
      color.to_hex_rgba(color.with_alpha(rgba, factor: default_area_alpha))
    Error(_) -> stroke_color
  }
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

fn resolve_area_colour(
  area: AreaFill,
  stroke_fg: Rgba,
  theme: Theme,
) -> Result(Rgba, Nil) {
  case area {
    NoArea -> Error(Nil)
    AreaAuto -> {
      case color.parse_hex(theme.area(theme)) {
        Ok(c) -> Ok(c)
        Error(_) -> Ok(color.with_alpha(stroke_fg, factor: default_area_alpha))
      }
    }
    AreaExplicit(c) ->
      case color.parse_hex(c) {
        Ok(rgba) -> Ok(rgba)
        Error(_) -> Ok(color.with_alpha(stroke_fg, factor: default_area_alpha))
      }
  }
}

fn draw_area(
  canvas: raster.Canvas,
  values: List(Float),
  width: Int,
  height: Int,
  fill: Rgba,
) -> raster.Canvas {
  let points = pixel_points(values, width, height)
  case points {
    [] -> canvas
    [_] -> canvas
    _ -> {
      let height_f = int.to_float(height)
      list.window_by_2(points)
      |> list.fold(canvas, fn(c, pair) {
        fill_segment_columns(c, pair, height_f, fill)
      })
    }
  }
}

fn fill_segment_columns(
  canvas: raster.Canvas,
  segment: #(#(Float, Float), #(Float, Float)),
  height_f: Float,
  fill: Rgba,
) -> raster.Canvas {
  let #(#(x0, y0), #(x1, y1)) = segment
  case x1 -. x0 <=. 0.0 {
    True -> canvas
    False -> {
      let columns = int_range(float.round(x0), float.round(x1) - 1)
      list.fold(columns, canvas, fn(c, col) {
        fill_area_column(c, col, x0, y0, x1, y1, height_f, fill)
      })
    }
  }
}

fn fill_area_column(
  canvas: raster.Canvas,
  col: Int,
  x0: Float,
  y0: Float,
  x1: Float,
  y1: Float,
  height_f: Float,
  fill: Rgba,
) -> raster.Canvas {
  let cf = int.to_float(col)
  let t = case x1 -. x0 == 0.0 {
    True -> 0.0
    False -> { cf -. x0 } /. { x1 -. x0 }
  }
  let top = y0 +. { y1 -. y0 } *. t
  let top_clamped = clamp_float(top, 0.0, height_f)
  raster.fill_rect(canvas, cf, top_clamped, 1.0, height_f -. top_clamped, fill)
}

fn clamp_float(value: Float, lo: Float, hi: Float) -> Float {
  case value <. lo, value >. hi {
    True, _ -> lo
    _, True -> hi
    _, _ -> value
  }
}

fn draw_stroke(
  canvas: raster.Canvas,
  values: List(Float),
  width: Int,
  height: Int,
  stroke_width: Float,
  colour: Rgba,
) -> raster.Canvas {
  let points = pixel_points(values, width, height)
  case points {
    [] -> canvas
    [#(_, y)] -> {
      let _ = height
      raster.draw_line(
        canvas,
        0.0,
        y,
        int.to_float(width),
        y,
        stroke_width,
        colour,
      )
    }
    _ ->
      list.window_by_2(points)
      |> list.fold(canvas, fn(c, pair) {
        let #(#(x0, y0), #(x1, y1)) = pair
        raster.draw_line(c, x0, y0, x1, y1, stroke_width, colour)
      })
  }
}

fn int_range(lo: Int, hi: Int) -> List(Int) {
  case lo > hi {
    True -> []
    False -> do_int_range(hi, lo, [])
  }
}

fn do_int_range(current: Int, lo: Int, acc: List(Int)) -> List(Int) {
  case current < lo {
    True -> acc
    False -> do_int_range(current - 1, lo, [current, ..acc])
  }
}

fn pixel_points(
  values: List(Float),
  width: Int,
  height: Int,
) -> List(#(Float, Float)) {
  let width_f = int.to_float(width)
  let height_f = int.to_float(height)
  let mid = height_f /. 2.0
  case values {
    [] -> []
    [_] -> [#(0.0, mid), #(width_f -. 1.0, mid)]
    _ -> {
      let #(lo, hi) = scale.min_max(values)
      let count = list.length(values)
      let step = case count > 1 {
        True -> { width_f -. 1.0 } /. int.to_float(count - 1)
        False -> 0.0
      }
      let #(out, _) =
        list.fold(values, #([], 0), fn(acc, value) {
          let #(pts, i) = acc
          let x = int.to_float(i) *. step
          let y = y_for(value, lo, hi, height_f -. 1.0, mid)
          #([#(x, y), ..pts], i + 1)
        })
      list.reverse(out)
    }
  }
}
