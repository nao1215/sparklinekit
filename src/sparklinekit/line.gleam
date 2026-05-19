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
import sparklinekit/internal/format
import sparklinekit/internal/png
import sparklinekit/internal/raster
import sparklinekit/internal/scale
import sparklinekit/theme.{type Theme}

const default_width: Int = 240

const default_height: Int = 60

const default_stroke_width: Float = 2.0

const default_area_alpha: Float = 0.22

const default_smoothing: Float = 0.0

const default_spot_radius: Float = 0.0

const bezier_samples_per_segment: Int = 16

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
    smoothing: Float,
    spot_radius: Float,
    spot_color: String,
    gradient_area: Bool,
  )
}

/// Start a new line sparkline builder from a list of floats.
///
/// Defaults: 240x60 viewBox, `currentColor` stroke (inherits the
/// surrounding CSS colour), 2.0 stroke width, no background fill,
/// no area fill, no smoothing, no end-point spot.
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
    smoothing: default_smoothing,
    spot_radius: default_spot_radius,
    spot_color: theme.foreground(base),
    gradient_area: True,
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
    spot_color: theme.foreground(theme),
  )
}

/// Smooth the polyline into a cubic Bézier curve. `factor` controls
/// how round the corners get — `0.0` keeps sharp polylines, `0.25`
/// matches the default in `react-sparklines`, and `0.5` is the
/// roundest reasonable setting. Values outside `[0.0, 0.5]` are
/// clamped to that range.
pub fn with_smoothing(builder: Builder, factor: Float) -> Builder {
  let clamped = case factor {
    f if f <. 0.0 -> 0.0
    f if f >. 0.5 -> 0.5
    f -> f
  }
  Builder(..builder, smoothing: clamped)
}

/// Draw a filled circle at the last data point. `radius` of `0.0`
/// turns the spot off (the default).
pub fn with_spot(builder: Builder, radius: Float) -> Builder {
  Builder(..builder, spot_radius: non_negative_float(radius))
}

/// Override the colour used for the spot. Defaults to the stroke
/// colour (or, if a theme is active, the theme's foreground).
pub fn with_spot_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, spot_color: color)
}

/// Toggle the vertical gradient applied to the area fill. When
/// enabled (the default) the fill fades from the area colour at the
/// top to transparent at the baseline; when disabled the fill is a
/// solid tint.
pub fn with_gradient_area(builder: Builder, enabled: Bool) -> Builder {
  Builder(..builder, gradient_area: enabled)
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
///
/// The `<svg>` carries `width`, `height`, and `viewBox` attributes so
/// the chart sizes itself correctly both when embedded inside a
/// CSS-sized container and when displayed standalone.
pub fn to_svg(builder: Builder) -> String {
  let points = pixel_points(builder)
  let defs_layer = gradient_defs_svg(builder, points)
  let bg_layer =
    background_rect(builder.width, builder.height, builder.background)
  let area_layer = area_svg(builder, points)
  let line_layer = stroke_svg(builder, points)
  let spot_layer = spot_svg(builder, points)
  string_tree.new()
  |> string_tree.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"")
  |> string_tree.append(int.to_string(builder.width))
  |> string_tree.append("\" height=\"")
  |> string_tree.append(int.to_string(builder.height))
  |> string_tree.append("\" viewBox=\"0 0 ")
  |> string_tree.append(int.to_string(builder.width))
  |> string_tree.append(" ")
  |> string_tree.append(int.to_string(builder.height))
  |> string_tree.append("\" preserveAspectRatio=\"none\">")
  |> string_tree.append_tree(defs_layer)
  |> string_tree.append_tree(bg_layer)
  |> string_tree.append_tree(area_layer)
  |> string_tree.append_tree(line_layer)
  |> string_tree.append_tree(spot_layer)
  |> string_tree.append("</svg>")
  |> string_tree.to_string
}

/// Deprecated alias for [`to_svg`](#to_svg). Will be removed in a
/// future release.
@deprecated("Use line.to_svg/1 instead")
pub fn to_string(builder: Builder) -> String {
  to_svg(builder)
}

/// Render the builder to PNG bytes (8-bit RGBA truecolor).
///
/// `with_size` doubles as the pixel size for PNG — a 240x60 builder
/// produces a 240x60 image. The canvas starts at the background
/// colour (transparent when `background == "none"`) and the stroke
/// is drawn with Xiaolin Wu anti-aliasing.
///
/// The PNG IDAT payload is written using DEFLATE's uncompressed
/// "store" blocks (no Huffman coding) so the encoder stays pure
/// Gleam with zero FFI. As a result the output is roughly
/// `width * height * 4` bytes regardless of how uniform the image
/// is — for visual size context, prefer SVG.
pub fn to_png(builder: Builder) -> BitArray {
  let fg = parse_string_colour(builder.color, theme.foreground(builder.theme))
  let bg = case builder.background {
    "none" -> color.transparent
    other -> parse_string_colour_or(other, color.transparent)
  }
  let area_colour = resolve_area_colour(builder.area, fg, builder.theme)
  let points = pixel_points(builder)
  let stroke_path = stroke_path_points(builder, points)
  let canvas = raster.new(builder.width, builder.height, bg)
  let canvas = case area_colour {
    Error(_) -> canvas
    Ok(c) ->
      draw_area_png(
        canvas,
        stroke_path,
        builder.height,
        c,
        builder.gradient_area,
      )
  }
  let canvas = draw_stroke_png(canvas, stroke_path, builder.stroke_width, fg)
  let canvas = draw_spot_png(canvas, points, builder, fg)
  png.encode(
    raster.to_grid(canvas),
    width: builder.width,
    height: builder.height,
  )
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

/// Compute the gradient `<linearGradient>` id for a builder.
///
/// The id includes the resolved top colour (as an 8-digit hex) so two
/// charts that share dimensions and value count but use different
/// themes get distinct ids — without this, browsers inlining multiple
/// SVGs into the same page would reuse the first gradient definition
/// for every subsequent chart.
fn gradient_id(builder: Builder) -> String {
  let top = gradient_top_colour(builder)
  let top_suffix =
    color.to_hex_rgba(top)
    |> string.replace("#", "")
  "sparklinekit-area-"
  <> int.to_string(builder.width)
  <> "x"
  <> int.to_string(builder.height)
  <> "-"
  <> int.to_string(list.length(builder.values))
  <> "-"
  <> top_suffix
}

fn gradient_top_colour(builder: Builder) -> Rgba {
  let fg = parse_string_colour(builder.color, theme.foreground(builder.theme))
  case builder.area {
    AreaExplicit(c) -> parse_string_colour_or(c, fg)
    AreaAuto ->
      case color.parse_hex(theme.area(builder.theme)) {
        Ok(c) -> c
        Error(_) -> color.with_alpha(fg, factor: default_area_alpha)
      }
    NoArea -> fg
  }
}

fn gradient_defs_svg(
  builder: Builder,
  points: List(#(Float, Float)),
) -> string_tree.StringTree {
  case builder.area, builder.gradient_area, points {
    NoArea, _, _ -> string_tree.new()
    _, False, _ -> string_tree.new()
    _, _, [] -> string_tree.new()
    _, _, [_] -> string_tree.new()
    _, True, _ -> {
      let top = gradient_top_colour(builder)
      let bottom = color.with_alpha(top, factor: 0.0)
      let top_attr = color.to_hex_rgba(top)
      let bottom_attr = color.to_hex_rgba(bottom)
      string_tree.new()
      |> string_tree.append("<defs><linearGradient id=\"")
      |> string_tree.append(gradient_id(builder))
      |> string_tree.append("\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">")
      |> string_tree.append("<stop offset=\"0%\" stop-color=\"")
      |> string_tree.append(top_attr)
      |> string_tree.append("\"/>")
      |> string_tree.append("<stop offset=\"100%\" stop-color=\"")
      |> string_tree.append(bottom_attr)
      |> string_tree.append("\"/>")
      |> string_tree.append("</linearGradient></defs>")
    }
  }
}

fn area_svg(
  builder: Builder,
  points: List(#(Float, Float)),
) -> string_tree.StringTree {
  case builder.area, points {
    NoArea, _ -> string_tree.new()
    _, [] -> string_tree.new()
    _, [_] -> string_tree.new()
    mode, _ -> {
      // The gradient URL is internally generated and contains no
      // attacker-controlled characters, but the raw colour-string
      // branches below echo a user-supplied value back into an SVG
      // attribute and must be escaped to match the behaviour of
      // `stroke_svg` and `background_rect`.
      let fill_attr = case builder.gradient_area {
        True -> "url(#" <> gradient_id(builder) <> ")"
        False ->
          case mode {
            AreaExplicit(c) -> escape_attribute(c)
            AreaAuto -> escape_attribute(auto_area_color(builder.color))
            NoArea -> escape_attribute(builder.color)
          }
      }
      let d = path_data(points, builder.smoothing)
      let bottom = int.to_float(builder.height)
      let last_x = case last_point(points) {
        Ok(#(x, _)) -> x
        Error(_) -> int.to_float(builder.width)
      }
      let first_x = case points {
        [#(x, _), ..] -> x
        _ -> 0.0
      }
      let close =
        " L "
        <> format.coord(last_x)
        <> " "
        <> format.coord(bottom)
        <> " L "
        <> format.coord(first_x)
        <> " "
        <> format.coord(bottom)
        <> " Z"
      string_tree.new()
      |> string_tree.append("<path fill=\"")
      |> string_tree.append(fill_attr)
      |> string_tree.append("\" stroke=\"none\" d=\"")
      |> string_tree.append(d)
      |> string_tree.append(close)
      |> string_tree.append("\"/>")
    }
  }
}

fn stroke_svg(
  builder: Builder,
  points: List(#(Float, Float)),
) -> string_tree.StringTree {
  case points {
    [] -> string_tree.new()
    _ -> {
      let d = path_data(points, builder.smoothing)
      string_tree.new()
      |> string_tree.append("<path fill=\"none\" stroke=\"")
      |> string_tree.append(escape_attribute(builder.color))
      |> string_tree.append("\" stroke-width=\"")
      |> string_tree.append(format.coord(builder.stroke_width))
      |> string_tree.append(
        "\" stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"",
      )
      |> string_tree.append(d)
      |> string_tree.append("\"/>")
    }
  }
}

fn spot_svg(
  builder: Builder,
  points: List(#(Float, Float)),
) -> string_tree.StringTree {
  case builder.spot_radius >. 0.0, last_point(points) {
    True, Ok(#(x, y)) ->
      string_tree.new()
      |> string_tree.append("<circle cx=\"")
      |> string_tree.append(format.coord(x))
      |> string_tree.append("\" cy=\"")
      |> string_tree.append(format.coord(y))
      |> string_tree.append("\" r=\"")
      |> string_tree.append(format.coord(builder.spot_radius))
      |> string_tree.append("\" fill=\"")
      |> string_tree.append(escape_attribute(builder.spot_color))
      |> string_tree.append("\"/>")
    _, _ -> string_tree.new()
  }
}

fn last_point(points: List(#(Float, Float))) -> Result(#(Float, Float), Nil) {
  case list.reverse(points) {
    [head, ..] -> Ok(head)
    [] -> Error(Nil)
  }
}

fn path_data(points: List(#(Float, Float)), smoothing: Float) -> String {
  case points {
    [] -> ""
    [#(x, y)] -> "M " <> format.coord(x) <> " " <> format.coord(y)
    [#(x, y), ..rest] -> {
      let head = "M " <> format.coord(x) <> " " <> format.coord(y)
      case smoothing <=. 0.0 {
        True -> head <> linear_segments(rest)
        False -> head <> bezier_segments(#(x, y), rest, smoothing)
      }
    }
  }
}

fn linear_segments(points: List(#(Float, Float))) -> String {
  list.fold(points, "", fn(acc, p) {
    let #(x, y) = p
    acc <> " L " <> format.coord(x) <> " " <> format.coord(y)
  })
}

fn bezier_segments(
  start: #(Float, Float),
  rest: List(#(Float, Float)),
  factor: Float,
) -> String {
  let #(_, out) =
    list.fold(rest, #(start, ""), fn(state, p) {
      let #(prev, acc) = state
      let #(x0, y0) = prev
      let #(x, y) = p
      let dx = { x -. x0 } *. factor
      let c1x = x0 +. dx
      let c1y = y0
      let c2x = x -. dx
      let c2y = y
      let segment =
        " C "
        <> format.coord(c1x)
        <> " "
        <> format.coord(c1y)
        <> ", "
        <> format.coord(c2x)
        <> " "
        <> format.coord(c2y)
        <> ", "
        <> format.coord(x)
        <> " "
        <> format.coord(y)
      #(p, acc <> segment)
    })
  out
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

fn pixel_points(builder: Builder) -> List(#(Float, Float)) {
  let width_f = int.to_float(builder.width)
  let height_f = int.to_float(builder.height)
  // Cap the requested inset to half the smaller side so the drawing
  // never extends outside the viewBox on a tiny canvas. Without this
  // clamp a `with_size(1, 1)` chart was producing coordinates like
  // `M 1.0 2.0` that fell outside the `0 0 1 1` viewBox.
  let raw_inset =
    float.max(builder.stroke_width /. 2.0, builder.spot_radius +. 1.0)
    |> float.max(1.0)
  let max_inset = float.min(width_f /. 2.0, height_f /. 2.0)
  let inset = float.min(raw_inset, max_inset)
  let pad_x = inset
  let pad_top = inset
  let pad_bottom = inset
  // Clamp the drawable width to what actually fits inside the
  // canvas; without this, a tiny `with_size(1, 1)` could produce
  // path coordinates extending past the right edge of the viewBox.
  let usable_w = float.max(width_f -. 2.0 *. pad_x, 0.0)
  let top_y = pad_top
  let bottom_y = float.max(height_f -. pad_bottom, top_y)
  let mid = { top_y +. bottom_y } /. 2.0
  case builder.values {
    [] -> []
    [_] -> [#(pad_x, mid), #(pad_x +. usable_w, mid)]
    values -> {
      let #(lo, hi) = scale.min_max(values)
      let count = list.length(values)
      let step = case count > 1 {
        True -> usable_w /. int.to_float(count - 1)
        False -> 0.0
      }
      let #(out, _) =
        list.fold(values, #([], 0), fn(acc, value) {
          let #(pts, i) = acc
          let x = pad_x +. int.to_float(i) *. step
          let y = y_for_padded(value, lo, hi, top_y, bottom_y, mid)
          #([#(x, y), ..pts], i + 1)
        })
      list.reverse(out)
    }
  }
}

fn y_for_padded(
  value: Float,
  lo: Float,
  hi: Float,
  top: Float,
  bottom: Float,
  mid: Float,
) -> Float {
  case lo == hi {
    True -> mid
    False -> {
      let n = scale.unit(value, lo, hi)
      bottom -. n *. { bottom -. top }
    }
  }
}

fn stroke_path_points(
  builder: Builder,
  anchors: List(#(Float, Float)),
) -> List(#(Float, Float)) {
  case builder.smoothing <=. 0.0, anchors {
    _, [] -> []
    _, [_] -> anchors
    True, _ -> anchors
    False, [head, ..rest] -> [
      head,
      ..sample_bezier(head, rest, builder.smoothing)
    ]
  }
}

fn sample_bezier(
  start: #(Float, Float),
  rest: List(#(Float, Float)),
  factor: Float,
) -> List(#(Float, Float)) {
  let #(_, samples) =
    list.fold(rest, #(start, []), fn(state, p) {
      let #(prev, acc) = state
      let #(x0, y0) = prev
      let #(x1, y1) = p
      let dx = { x1 -. x0 } *. factor
      let c1 = #(x0 +. dx, y0)
      let c2 = #(x1 -. dx, y1)
      let segment =
        bezier_subdivide(prev, c1, c2, p, bezier_samples_per_segment)
      #(p, list.append(acc, segment))
    })
  samples
}

fn bezier_subdivide(
  p0: #(Float, Float),
  p1: #(Float, Float),
  p2: #(Float, Float),
  p3: #(Float, Float),
  steps: Int,
) -> List(#(Float, Float)) {
  let actual_steps = case steps < 1 {
    True -> 1
    False -> steps
  }
  do_bezier_subdivide(p0, p1, p2, p3, 1, actual_steps, [])
}

fn do_bezier_subdivide(
  p0: #(Float, Float),
  p1: #(Float, Float),
  p2: #(Float, Float),
  p3: #(Float, Float),
  step: Int,
  total: Int,
  acc: List(#(Float, Float)),
) -> List(#(Float, Float)) {
  case step > total {
    True -> list.reverse(acc)
    False -> {
      let t = int.to_float(step) /. int.to_float(total)
      let point = cubic_at(p0, p1, p2, p3, t)
      do_bezier_subdivide(p0, p1, p2, p3, step + 1, total, [point, ..acc])
    }
  }
}

fn cubic_at(
  p0: #(Float, Float),
  p1: #(Float, Float),
  p2: #(Float, Float),
  p3: #(Float, Float),
  t: Float,
) -> #(Float, Float) {
  let one_minus = 1.0 -. t
  let b0 = one_minus *. one_minus *. one_minus
  let b1 = 3.0 *. one_minus *. one_minus *. t
  let b2 = 3.0 *. one_minus *. t *. t
  let b3 = t *. t *. t
  let #(x0, y0) = p0
  let #(x1, y1) = p1
  let #(x2, y2) = p2
  let #(x3, y3) = p3
  #(
    b0 *. x0 +. b1 *. x1 +. b2 *. x2 +. b3 *. x3,
    b0 *. y0 +. b1 *. y1 +. b2 *. y2 +. b3 *. y3,
  )
}

fn draw_area_png(
  canvas: raster.Canvas,
  path_points: List(#(Float, Float)),
  height: Int,
  fill: Rgba,
  gradient: Bool,
) -> raster.Canvas {
  case path_points {
    [] -> canvas
    [_] -> canvas
    _ -> {
      let height_f = int.to_float(height)
      list.window_by_2(path_points)
      |> list.fold(canvas, fn(c, pair) {
        fill_segment_columns(c, pair, height_f, fill, gradient)
      })
    }
  }
}

fn fill_segment_columns(
  canvas: raster.Canvas,
  segment: #(#(Float, Float), #(Float, Float)),
  height_f: Float,
  fill: Rgba,
  gradient: Bool,
) -> raster.Canvas {
  let #(#(x0, y0), #(x1, y1)) = segment
  case x1 -. x0 <=. 0.0 {
    True -> canvas
    False -> {
      let columns = int_range(float.round(x0), float.round(x1) - 1)
      list.fold(columns, canvas, fn(c, col) {
        fill_area_column(c, col, x0, y0, x1, y1, height_f, fill, gradient)
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
  gradient: Bool,
) -> raster.Canvas {
  let cf = int.to_float(col)
  let span = x1 -. x0
  let t = case span == 0.0 {
    True -> 0.0
    False -> { cf -. x0 } /. span
  }
  let top = y0 +. { y1 -. y0 } *. t
  let top_clamped = clamp_float(top, 0.0, height_f)
  case gradient {
    False ->
      raster.fill_rect(
        canvas,
        cf,
        top_clamped,
        1.0,
        height_f -. top_clamped,
        fill,
      )
    True ->
      raster.fill_vertical_gradient(
        canvas,
        cf,
        top_clamped,
        cf +. 1.0,
        height_f,
        fill,
        color.with_alpha(fill, factor: 0.0),
      )
  }
}

fn clamp_float(value: Float, lo: Float, hi: Float) -> Float {
  case value <. lo, value >. hi {
    True, _ -> lo
    _, True -> hi
    _, _ -> value
  }
}

fn draw_stroke_png(
  canvas: raster.Canvas,
  path_points: List(#(Float, Float)),
  stroke_width: Float,
  colour: Rgba,
) -> raster.Canvas {
  case path_points {
    [] -> canvas
    [#(x, y)] ->
      raster.draw_line(
        canvas,
        x -. stroke_width,
        y,
        x +. stroke_width,
        y,
        stroke_width,
        colour,
      )
    _ ->
      list.window_by_2(path_points)
      |> list.fold(canvas, fn(c, pair) {
        let #(#(x0, y0), #(x1, y1)) = pair
        raster.draw_line(c, x0, y0, x1, y1, stroke_width, colour)
      })
  }
}

fn draw_spot_png(
  canvas: raster.Canvas,
  anchors: List(#(Float, Float)),
  builder: Builder,
  fg: Rgba,
) -> raster.Canvas {
  case builder.spot_radius >. 0.0, last_point(anchors) {
    True, Ok(#(x, y)) -> {
      let spot_colour = parse_string_colour_or(builder.spot_color, fg)
      raster.fill_circle(canvas, x, y, builder.spot_radius, spot_colour)
    }
    _, _ -> canvas
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

fn non_negative_float(value: Float) -> Float {
  case value <. 0.0 {
    True -> 0.0
    False -> value
  }
}
