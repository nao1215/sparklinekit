//// Draw sparklines: Unicode blocks for a terminal, and line or bar charts
//// as SVG text or PNG bytes.
////
//// ```gleam
//// import sparklinekit.{LineOptions}
////
//// pub fn main() {
////   sparklinekit.blocks([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
////   // -> "▁▂█▅▂▁▃"
////
////   let assert Ok(svg) =
////     sparklinekit.line_svg(
////       [1.0, 5.0, 3.0, 8.0, 4.0],
////       LineOptions(
////         ..sparklinekit.default_line_options,
////         theme: sparklinekit.ocean,
////         area: sparklinekit.GradientArea,
////       ),
////     )
////   svg
//// }
//// ```

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/string_tree.{type StringTree}
import sparklinekit/internal/color.{type Rgba}
import sparklinekit/internal/format
import sparklinekit/internal/png
import sparklinekit/internal/raster
import sparklinekit/internal/scale

// Themes ---------------------------------------------------------------------

/// The colours of a line or bar chart. Each colour is one of:
///
/// - `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`, with hex digits in either
///   case.
/// - `none`, which draws nothing.
/// - `currentColor`, the colour of the text around an inline SVG. PNG
///   output has no surrounding text and draws it black.
///
/// The keywords are matched without regard to case. The chart renderers
/// check all four colours before drawing, including one the chart does not
/// use, such as `negative` in a line chart, and return
/// `Error(InvalidColor(..))` for anything else, such as `"red"`, `"rgb(...)"`
/// or `""`. So SVG and PNG output always agree on what a colour means, and
/// no colour can add markup to the SVG.
///
pub type Theme {
  Theme(
    /// The line, or the bars at or above zero.
    foreground: String,
    /// The background rectangle. `"none"` draws no background.
    background: String,
    /// The area under a line. `None` uses the foreground at 22% opacity,
    /// so it draws no area when the foreground is `none`. A colour without
    /// its own transparency is drawn opaque under the line. Bar charts
    /// ignore it.
    area: Option(String),
    /// The bars below zero. Line charts ignore it.
    negative: String,
  )
}

/// The error the chart renderers return for a colour they do not accept.
/// `field` is the name of the `Theme` field, or `"spot_color"`, and `value`
/// is the colour as given. See `Theme` for the accepted colours.
///
pub type InvalidColor {
  InvalidColor(field: String, value: String)
}

/// The theme of the default options: the surrounding CSS colour
/// (`currentColor`), no background, and red (`#EF4444`) below zero.
///
pub const default_theme =
  Theme(
    foreground: "currentColor",
    background: "none",
    area: None,
    negative: "#EF4444",
  )

/// Blue on white, with grey below zero.
pub const ocean =
  Theme(
    foreground: "#2563EB",
    background: "#FFFFFF",
    area: Some("#2563EB33"),
    negative: "#94A3B8",
  )

/// Green on white, with red below zero.
pub const forest =
  Theme(
    foreground: "#10B981",
    background: "#FFFFFF",
    area: Some("#10B98133"),
    negative: "#EF4444",
  )

/// Orange on white, with violet below zero.
pub const sunset =
  Theme(
    foreground: "#F97316",
    background: "#FFFFFF",
    area: Some("#F9731633"),
    negative: "#7C3AED",
  )

/// Near-black on white, with grey below zero.
pub const mono =
  Theme(
    foreground: "#0F172A",
    background: "#FFFFFF",
    area: Some("#0F172A29"),
    negative: "#94A3B8",
  )

/// Cyan on near-black, with pink below zero.
pub const neon =
  Theme(
    foreground: "#22D3EE",
    background: "#020617",
    area: Some("#22D3EE33"),
    negative: "#F472B6",
  )

/// Violet on pale violet, with rose below zero.
pub const pastel =
  Theme(
    foreground: "#A78BFA",
    background: "#FAF5FF",
    area: Some("#A78BFA33"),
    negative: "#FB7185",
  )

/// Red on white, with grey below zero.
pub const crimson =
  Theme(
    foreground: "#DC2626",
    background: "#FFFFFF",
    area: Some("#DC262633"),
    negative: "#94A3B8",
  )

/// Slate grey on white, with amber below zero.
pub const slate =
  Theme(
    foreground: "#475569",
    background: "#FFFFFF",
    area: Some("#47556933"),
    negative: "#F59E0B",
  )

/// Amber on white, with red below zero.
pub const amber =
  Theme(
    foreground: "#F59E0B",
    background: "#FFFFFF",
    area: Some("#F59E0B33"),
    negative: "#DC2626",
  )

/// Off-white on navy, with rose below zero.
pub const midnight =
  Theme(
    foreground: "#F8FAFC",
    background: "#020617",
    area: Some("#F8FAFC29"),
    negative: "#FB7185",
  )

// Unicode --------------------------------------------------------------------

/// Draws `values` with the block characters `▁▂▃▄▅▆▇█`, one per value,
/// scaled between the smallest and largest value. Each block covers an
/// eighth of that range, and the largest value is drawn with `█`.
///
/// A single value, or a series where every value is the same, is drawn
/// with the middle block `▄`.
///
/// ## Examples
///
/// ```gleam
/// sparklinekit.blocks([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
/// // -> "▁▂█▅▂▁▃"
/// ```
///
/// ```gleam
/// sparklinekit.blocks([])
/// // -> ""
/// ```
///
pub fn blocks(values: List(Float)) -> String {
  let #(lo, hi) = scale.min_max(values)
  values
  |> list.map(fn(value) {
    case lo == hi {
      True -> block(3)
      False -> {
        let level = float.truncate(scale.unit(value, lo, hi) *. 8.0)
        block(int.clamp(level, min: 0, max: 7))
      }
    }
  })
  |> string.concat
}

fn block(level: Int) -> String {
  case level {
    0 -> "▁"
    1 -> "▂"
    2 -> "▃"
    3 -> "▄"
    4 -> "▅"
    5 -> "▆"
    6 -> "▇"
    _ -> "█"
  }
}

// Line charts ----------------------------------------------------------------

/// How the area under a line is filled. The colour is the theme's `area`.
pub type Area {
  NoArea
  /// One flat colour.
  SolidArea
  /// The area colour at the far edge of the area, the height of the largest
  /// value, fading to transparent at the baseline. The opacity depends on
  /// the height alone, so under a low point of the line the area is
  /// already faint. When the series has values on both sides of zero, the
  /// part above zero fades downwards from the largest value and the part
  /// below zero fades upwards from the smallest, both to transparent at the
  /// level of zero.
  GradientArea
}

/// Settings for `line_svg` and `line_png`. Start from
/// `default_line_options` and change the fields you need.
///
pub type LineOptions {
  LineOptions(
    /// Width of the SVG viewBox, and of the PNG in pixels. Values below 1
    /// are treated as 1.
    width: Int,
    /// Height of the SVG viewBox, and of the PNG in pixels. Values below 1
    /// are treated as 1.
    height: Int,
    /// Colours of the line, the background and the area.
    theme: Theme,
    /// Values of 0 or less are drawn 0.5 wide, values above 10,000 as
    /// 10,000.
    stroke_width: Float,
    /// How round the line is, from `0.0` (straight segments) to `0.5`.
    /// Values outside that range are clamped.
    smoothing: Float,
    /// The fill under the line. It reaches down to the bottom when every
    /// value is zero or more, up to the top when every value is zero or
    /// less, and to the level of zero otherwise.
    area: Area,
    /// Radius of a dot on the last value. `0.0` draws no dot, and values
    /// above 10,000 are clamped.
    spot_radius: Float,
    /// Colour of the dot, in the forms `Theme` accepts. `None` uses the
    /// theme's foreground.
    spot_color: Option(String),
  )
}

/// 240 by 60, the default theme, a 2.0 stroke, straight segments, no area
/// and no dot.
///
pub const default_line_options =
  LineOptions(
    width: 240,
    height: 60,
    theme: default_theme,
    stroke_width: 2.0,
    smoothing: 0.0,
    area: NoArea,
    spot_radius: 0.0,
    spot_color: None,
  )

const area_alpha: Float = 0.22

const max_stroke_width: Float = 1.0e4

const max_spot_radius: Float = 1.0e4

const bezier_samples_per_segment: Int = 16

/// Draws `values` as a line chart in a standalone `<svg>` element, scaled
/// between the smallest and largest value.
///
/// An empty series gives an `<svg>` with no line. A single value, or a
/// series where every value is the same, is drawn as a flat line at half
/// height. A colour that `Theme` does not accept, in the theme or in
/// `spot_color`, gives `Error(InvalidColor(..))`.
///
/// ## Examples
///
/// ```gleam
/// sparklinekit.line_svg([1.0, 5.0, 3.0], sparklinekit.default_line_options)
/// // -> Ok("<svg ...><path fill=\"none\" stroke=\"currentColor\" ... d=\"M 1.0 59.0 L 120.0 1.0 L 239.0 30.0\"/></svg>")
/// ```
///
/// ```gleam
/// sparklinekit.line_svg([], sparklinekit.default_line_options)
/// // -> Ok("<svg ...></svg>")
/// ```
///
pub fn line_svg(
  values: List(Float),
  options: LineOptions,
) -> Result(String, InvalidColor) {
  let options = sanitise_line(options)
  use palette <- result.try(check_theme(options.theme))
  use spot <- result.map(check_spot(options.spot_color, palette.foreground))
  let points = line_points(values, options)
  let #(defs, area_layer) = case options.area, palette.area, points {
    NoArea, _, _ | _, color.NoPaint, _ | _, _, [] -> #(
      string_tree.new(),
      string_tree.new(),
    )
    SolidArea, fill, _ -> #(
      string_tree.new(),
      area_path(paint_attributes(fill, "fill"), points, values, options),
    )
    GradientArea, fill, _ -> {
      let gradient = area_gradient(points, values, options)
      let id = gradient_id(fill, gradient, values, options)
      #(
        gradient_defs(id, fill, gradient),
        area_path(" fill=\"url(#" <> id <> ")\"", points, values, options),
      )
    }
  }
  svg_document(options.width, options.height, [
    defs,
    background_rect(options.width, options.height, palette.background),
    area_layer,
    stroke_path(points, palette.foreground, options),
    spot_circle(points, spot, options),
  ])
}

/// Draws the same chart as `line_svg` as 8-bit RGBA PNG bytes, with an
/// anti-aliased line. The image is not compressed, so it is about
/// `width * height * 4` bytes. A colour that `Theme` does not accept gives
/// `Error(InvalidColor(..))`.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(png) =
///   sparklinekit.line_png([1.0, 5.0, 3.0], sparklinekit.default_line_options)
/// simplifile.write_bits(to: "chart.png", bits: png)
/// ```
///
pub fn line_png(
  values: List(Float),
  options: LineOptions,
) -> Result(BitArray, InvalidColor) {
  let options = sanitise_line(options)
  use palette <- result.try(check_theme(options.theme))
  use spot <- result.map(check_spot(options.spot_color, palette.foreground))
  let points = line_points(values, options)
  let path = sampled_path(points, options.smoothing)
  let canvas =
    raster.new(
      options.width,
      options.height,
      color.paint_rgba(palette.background),
    )
  let canvas = case options.area, palette.area, points {
    NoArea, _, _ | _, color.NoPaint, _ | _, _, [] -> canvas
    area, fill, _ ->
      fill_area(
        canvas,
        path,
        int.to_float(options.height),
        area_gradient(points, values, options),
        color.paint_rgba(fill),
        area == GradientArea,
      )
  }
  let canvas = case palette.foreground {
    color.NoPaint -> canvas
    foreground ->
      draw_stroke(
        canvas,
        path,
        options.stroke_width,
        color.paint_rgba(foreground),
      )
  }
  let canvas = case options.spot_radius >. 0.0, list.last(points), spot {
    _, _, color.NoPaint -> canvas
    True, Ok(#(x, y)), spot ->
      raster.fill_circle(
        canvas,
        x,
        y,
        options.spot_radius,
        color.paint_rgba(spot),
      )
    _, _, _ -> canvas
  }
  png.encode(
    raster.to_grid(canvas),
    width: options.width,
    height: options.height,
  )
}

fn sanitise_line(options: LineOptions) -> LineOptions {
  let stroke_width = case options.stroke_width >. 0.0 {
    True -> float.min(options.stroke_width, max_stroke_width)
    False -> 0.5
  }
  LineOptions(
    ..options,
    width: int.max(options.width, 1),
    height: int.max(options.height, 1),
    stroke_width:,
    smoothing: float.clamp(options.smoothing, min: 0.0, max: 0.5),
    spot_radius: float.clamp(
      options.spot_radius,
      min: 0.0,
      max: max_spot_radius,
    ),
  )
}

fn check_spot(
  spot_color: Option(String),
  foreground: color.Paint,
) -> Result(color.Paint, InvalidColor) {
  case spot_color {
    None -> Ok(foreground)
    Some(value) -> check_colour("spot_color", value)
  }
}

// The y range the line is drawn in, inset so the stroke and the dot stay
// inside the canvas: #(top, bottom, middle).
fn y_window(options: LineOptions) -> #(Float, Float, Float) {
  let width = int.to_float(options.width)
  let height = int.to_float(options.height)
  let inset =
    float.max(options.stroke_width /. 2.0, options.spot_radius +. 1.0)
    |> float.max(1.0)
    |> float.min(width /. 2.0)
    |> float.min(height /. 2.0)
  let top = inset
  let bottom = float.max(height -. inset, top)
  #(top, bottom, { top +. bottom } /. 2.0)
}

fn line_points(
  values: List(Float),
  options: LineOptions,
) -> List(#(Float, Float)) {
  let #(top, bottom, middle) = y_window(options)
  let left = top
  let usable_width = float.max(int.to_float(options.width) -. 2.0 *. left, 0.0)
  case values {
    [] -> []
    [_] -> [#(left, middle), #(left +. usable_width, middle)]
    _ -> {
      let #(lo, hi) = scale.min_max(values)
      let step = usable_width /. int.to_float(list.length(values) - 1)
      list.index_map(values, fn(value, i) {
        #(left +. int.to_float(i) *. step, y_for(value, lo, hi, top, bottom))
      })
    }
  }
}

fn y_for(
  value: Float,
  lo: Float,
  hi: Float,
  top: Float,
  bottom: Float,
) -> Float {
  case lo == hi {
    True -> { top +. bottom } /. 2.0
    False -> bottom -. scale.unit(value, lo, hi) *. { bottom -. top }
  }
}

// The y the area closes at: the bottom for series that never go below
// zero, the top for series that never go above it, and the y of zero for
// series with both signs.
fn area_baseline(values: List(Float), options: LineOptions) -> Float {
  let height = int.to_float(options.height)
  let #(lo, hi) = scale.min_max(values)
  case lo >=. 0.0, hi <=. 0.0 {
    True, _ -> height
    _, True -> 0.0
    _, _ -> {
      let #(top, bottom, _) = y_window(options)
      y_for(0.0, lo, hi, top, bottom)
    }
  }
}

// The vertical extent of the area, which is where SVG puts a gradient
// with the default `objectBoundingBox` units, and the y of its baseline.
// SVG and PNG shade the area from these alone, so both draw the same
// opacity at the same height.
type AreaGradient {
  AreaGradient(top: Float, bottom: Float, baseline: Float)
}

fn area_gradient(
  points: List(#(Float, Float)),
  values: List(Float),
  options: LineOptions,
) -> AreaGradient {
  let baseline = area_baseline(values, options)
  let ys = list.map(points, fn(point) { point.1 })
  AreaGradient(
    top: list.fold(ys, baseline, float.min),
    bottom: list.fold(ys, baseline, float.max),
    baseline:,
  )
}

// Where zero lies in the area, from 0.0 at its top to 1.0 at its bottom.
fn zero_offset(gradient: AreaGradient) -> Float {
  let AreaGradient(top:, bottom:, baseline:) = gradient
  case bottom -. top >. 0.0 {
    True -> float.clamp({ baseline -. top } /. { bottom -. top }, 0.0, 1.0)
    False -> 1.0
  }
}

// The opacity of the gradient at height `y`: 1.0 at the far edge of the
// area on either side of the baseline, 0.0 at the baseline.
fn gradient_factor(gradient: AreaGradient, y: Float) -> Float {
  let AreaGradient(top:, bottom:, baseline:) = gradient
  let #(distance, extent) = case y <. baseline {
    True -> #(baseline -. y, baseline -. top)
    False -> #(y -. baseline, bottom -. baseline)
  }
  case extent >. 0.0 {
    True -> float.clamp(distance /. extent, 0.0, 1.0)
    False -> 0.0
  }
}

// The id includes the size, the value count, the colour and the level of
// zero, so several charts inlined into one page do not share a gradient by
// accident.
fn gradient_id(
  fill: color.Paint,
  gradient: AreaGradient,
  values: List(Float),
  options: LineOptions,
) -> String {
  "sparklinekit-area-"
  <> int.to_string(options.width)
  <> "x"
  <> int.to_string(options.height)
  <> "-"
  <> int.to_string(list.length(values))
  <> "-"
  <> paint_token(fill)
  <> case zero_offset(gradient) {
    z if z >=. 1.0 -> ""
    z if z <=. 0.0 -> "-up"
    z -> "-z" <> float.to_string(z *. 100.0)
  }
}

fn paint_token(paint: color.Paint) -> String {
  case paint {
    color.Hex(rgba:, ..) -> string.replace(color.to_hex_rgba(rgba), "#", "")
    color.CurrentColor(opacity:) ->
      "current" <> int.to_string(float.round(opacity *. 100.0))
    color.NoPaint -> "none"
  }
}

// An area below the line fades downwards to the baseline, an area above
// it fades upwards, and an area on both sides of zero fades towards zero
// from both ends.
fn gradient_defs(
  id: String,
  fill: color.Paint,
  gradient: AreaGradient,
) -> StringTree {
  let #(direction, stops) = case zero_offset(gradient) {
    z if z >=. 1.0 -> #("x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"", [
      gradient_stop("0%", fill, True),
      gradient_stop("100%", fill, False),
    ])
    z if z <=. 0.0 -> #("x1=\"0\" y1=\"1\" x2=\"0\" y2=\"0\"", [
      gradient_stop("0%", fill, True),
      gradient_stop("100%", fill, False),
    ])
    z -> #("x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"", [
      gradient_stop("0%", fill, True),
      gradient_stop(float.to_string(z *. 100.0) <> "%", fill, False),
      gradient_stop("100%", fill, True),
    ])
  }
  string_tree.from_strings([
    "<defs><linearGradient id=\"",
    id,
    "\" ",
    direction,
    ">",
    ..stops
  ])
  |> string_tree.append("</linearGradient></defs>")
}

fn gradient_stop(offset: String, fill: color.Paint, solid: Bool) -> String {
  let #(colour, opacity) = color.svg_colour(fill)
  let opacity = case solid, opacity <. 1.0 {
    False, _ -> " stop-opacity=\"0\""
    True, True -> " stop-opacity=\"" <> format.opacity(opacity) <> "\""
    True, False -> ""
  }
  "<stop offset=\""
  <> offset
  <> "\" stop-color=\""
  <> colour
  <> "\""
  <> opacity
  <> "/>"
}

fn area_path(
  fill: String,
  points: List(#(Float, Float)),
  values: List(Float),
  options: LineOptions,
) -> StringTree {
  let baseline = format.coord(area_baseline(values, options))
  let first_x = case points {
    [#(x, _), ..] -> x
    [] -> 0.0
  }
  let last_x = case list.last(points) {
    Ok(#(x, _)) -> x
    Error(_) -> int.to_float(options.width)
  }
  string_tree.from_strings([
    "<path",
    fill,
    " stroke=\"none\" d=\"",
    path_data(points, options.smoothing),
    " L ",
    format.coord(last_x),
    " ",
    baseline,
    " L ",
    format.coord(first_x),
    " ",
    baseline,
    " Z\"/>",
  ])
}

fn stroke_path(
  points: List(#(Float, Float)),
  foreground: color.Paint,
  options: LineOptions,
) -> StringTree {
  case points, foreground {
    [], _ | _, color.NoPaint -> string_tree.new()
    _, _ ->
      string_tree.from_strings([
        "<path fill=\"none\"",
        paint_attributes(foreground, "stroke"),
        " stroke-width=\"",
        format.coord(options.stroke_width),
        "\" stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"",
        path_data(points, options.smoothing),
        "\"/>",
      ])
  }
}

fn spot_circle(
  points: List(#(Float, Float)),
  spot: color.Paint,
  options: LineOptions,
) -> StringTree {
  case options.spot_radius >. 0.0, list.last(points), spot {
    _, _, color.NoPaint -> string_tree.new()
    True, Ok(#(x, y)), _ ->
      string_tree.from_strings([
        "<circle cx=\"",
        format.coord(x),
        "\" cy=\"",
        format.coord(y),
        "\" r=\"",
        format.coord(options.spot_radius),
        "\"",
        paint_attributes(spot, "fill"),
        "/>",
      ])
    _, _, _ -> string_tree.new()
  }
}

fn path_data(points: List(#(Float, Float)), smoothing: Float) -> String {
  case points {
    [] -> ""
    [first, ..] ->
      list.window_by_2(points)
      |> list.map(fn(pair) { path_segment(pair.0, pair.1, smoothing) })
      |> list.prepend("M " <> point_text(first))
      |> string.concat
  }
}

fn path_segment(
  from: #(Float, Float),
  to: #(Float, Float),
  smoothing: Float,
) -> String {
  case smoothing >. 0.0 {
    False -> " L " <> point_text(to)
    True -> {
      let #(c1, c2) = control_points(from, to, smoothing)
      " C "
      <> point_text(c1)
      <> ", "
      <> point_text(c2)
      <> ", "
      <> point_text(to)
    }
  }
}

fn point_text(point: #(Float, Float)) -> String {
  format.coord(point.0) <> " " <> format.coord(point.1)
}

// The two control points of the cubic Bézier from `from` to `to`: each
// keeps its end's y and moves `factor` of the way along x.
fn control_points(
  from: #(Float, Float),
  to: #(Float, Float),
  factor: Float,
) -> #(#(Float, Float), #(Float, Float)) {
  let dx = { to.0 -. from.0 } *. factor
  #(#(from.0 +. dx, from.1), #(to.0 -. dx, to.1))
}

// The points the PNG line goes through: the data points themselves, or 16
// points per segment along the same curve the SVG draws.
fn sampled_path(
  points: List(#(Float, Float)),
  smoothing: Float,
) -> List(#(Float, Float)) {
  case smoothing >. 0.0, points {
    True, [first, _, ..] -> [
      first,
      ..list.flat_map(list.window_by_2(points), fn(pair) {
        let #(from, to) = pair
        let #(c1, c2) = control_points(from, to, smoothing)
        list.map(raster.range(1, bezier_samples_per_segment), fn(step) {
          let t = int.to_float(step) /. int.to_float(bezier_samples_per_segment)
          cubic_at(from, c1, c2, to, t)
        })
      })
    ]
    _, _ -> points
  }
}

fn cubic_at(
  p0: #(Float, Float),
  p1: #(Float, Float),
  p2: #(Float, Float),
  p3: #(Float, Float),
  t: Float,
) -> #(Float, Float) {
  let u = 1.0 -. t
  let b0 = u *. u *. u
  let b1 = 3.0 *. u *. u *. t
  let b2 = 3.0 *. u *. t *. t
  let b3 = t *. t *. t
  #(
    b0 *. p0.0 +. b1 *. p1.0 +. b2 *. p2.0 +. b3 *. p3.0,
    b0 *. p0.1 +. b1 *. p1.1 +. b2 *. p2.1 +. b3 *. p3.1,
  )
}

fn fill_area(
  canvas: raster.Canvas,
  path: List(#(Float, Float)),
  height: Float,
  gradient: AreaGradient,
  fill: Rgba,
  shaded: Bool,
) -> raster.Canvas {
  let baseline = float.clamp(gradient.baseline, min: 0.0, max: height)
  let colour_at = case shaded {
    True -> fn(y) {
      color.with_alpha(fill, factor: gradient_factor(gradient, y))
    }
    False -> fn(_) { fill }
  }
  case path, list.last(path) {
    [#(first_x, _), ..], Ok(#(last_x, _)) -> {
      let columns =
        raster.range(
          int.max(float.truncate(float.floor(first_x)), 0),
          float.truncate(float.ceiling(last_x)) - 1,
        )
      fill_area_columns(
        canvas,
        list.window_by_2(path),
        columns,
        first_x,
        last_x,
        fn(canvas, column, line_y) {
          // A column the area only partly covers, at either end, is
          // shaded by the share it covers.
          let coverage = raster.overlap(column, first_x, last_x)
          let line_y = float.clamp(line_y, min: 0.0, max: height)
          raster.fill_column(canvas, column, line_y, baseline, fn(y) {
            color.with_alpha(colour_at(y), factor: coverage)
          })
        },
      )
    }
    _, _ -> canvas
  }
}

// Calls `fill` with each column and the height of the path at the centre
// of the column, or at the nearer end of the path for a column the path
// does not reach the centre of. Both lists are in increasing x.
fn fill_area_columns(
  canvas: raster.Canvas,
  segments: List(#(#(Float, Float), #(Float, Float))),
  columns: List(Int),
  first_x: Float,
  last_x: Float,
  fill: fn(raster.Canvas, Int, Float) -> raster.Canvas,
) -> raster.Canvas {
  case columns, segments {
    [], _ | _, [] -> canvas
    [column, ..rest], [#(#(x0, y0), #(x1, y1)), ..later] -> {
      let x =
        float.clamp(int.to_float(column) +. 0.5, min: first_x, max: last_x)
      case x >. x1 && later != [] {
        True -> fill_area_columns(canvas, later, columns, first_x, last_x, fill)
        False ->
          fill(canvas, column, y_on_segment(#(x0, y0), #(x1, y1), x))
          |> fill_area_columns(segments, rest, first_x, last_x, fill)
      }
    }
  }
}

fn y_on_segment(from: #(Float, Float), to: #(Float, Float), x: Float) -> Float {
  let #(x0, y0) = from
  let #(x1, y1) = to
  case x1 -. x0 >. 0.0 {
    True -> y0 +. { y1 -. y0 } *. { x -. x0 } /. { x1 -. x0 }
    False -> y1
  }
}

fn draw_stroke(
  canvas: raster.Canvas,
  path: List(#(Float, Float)),
  width: Float,
  colour: Rgba,
) -> raster.Canvas {
  use canvas, #(#(x0, y0), #(x1, y1)) <- list.fold(
    list.window_by_2(path),
    canvas,
  )
  raster.draw_line(canvas, x0, y0, x1, y1, width, colour)
}

// Bar charts -----------------------------------------------------------------

/// Settings for `bar_svg` and `bar_png`. Start from `default_bar_options`
/// and change the fields you need.
///
pub type BarOptions {
  BarOptions(
    /// Width of the SVG viewBox, and of the PNG in pixels. Values below 1
    /// are treated as 1.
    width: Int,
    /// Height of the SVG viewBox, and of the PNG in pixels. Values below 1
    /// are treated as 1.
    height: Int,
    /// Colours of the bars and the background.
    theme: Theme,
    /// Space between neighbouring bars. Each bar is centred in an equal
    /// share of the width, so half the gap is left at each edge. Negative
    /// values are treated as 0, and a gap as wide as a share or wider is
    /// dropped.
    gap: Float,
    /// Corner radius of each bar, at most half its width or height.
    /// Negative values are treated as 0.
    corner_radius: Float,
  )
}

/// 200 by 40, the default theme, a 1.0 gap and square corners.
pub const default_bar_options =
  BarOptions(
    width: 200,
    height: 40,
    theme: default_theme,
    gap: 1.0,
    corner_radius: 0.0,
  )

// Bars whose height rounds to zero, such as bars for the value 0, are
// drawn this tall so they are still visible.
const min_bar_height: Float = 1.0

/// Draws `values` as a bar chart in a standalone `<svg>` element. Bars
/// grow up from zero for values above it and down for values below it,
/// in the theme's `negative` colour.
///
/// An empty series gives an `<svg>` with no bars. A single value, or a
/// series where every value is the same, is drawn as half-height bars,
/// standing on the bottom edge or hanging from the top for negative values.
/// A colour that `Theme` does not accept gives `Error(InvalidColor(..))`.
///
/// ## Examples
///
/// ```gleam
/// sparklinekit.bar_svg(
///   [3.0, -2.0, 5.0],
///   BarOptions(..sparklinekit.default_bar_options, theme: sparklinekit.forest),
/// )
/// // -> Ok("<svg ...><rect ... fill=\"#10B981\"/>...</svg>")
/// ```
///
pub fn bar_svg(
  values: List(Float),
  options: BarOptions,
) -> Result(String, InvalidColor) {
  let options = sanitise_bar(options)
  use palette <- result.map(check_theme(options.theme))
  let bars =
    bar_rects(values, options)
    |> list.filter_map(fn(rect) {
      let radius =
        options.corner_radius
        |> float.min(rect.width /. 2.0)
        |> float.min(rect.height /. 2.0)
      let radius = case radius >. 0.0 {
        True -> " rx=\"" <> format.coord(radius) <> "\""
        False -> ""
      }
      case bar_paint(rect, palette) {
        color.NoPaint -> Error(Nil)
        fill ->
          Ok(
            string_tree.from_strings([
              "<rect x=\"",
              format.coord(rect.x),
              "\" y=\"",
              format.coord(rect.y),
              "\" width=\"",
              format.coord(rect.width),
              "\" height=\"",
              format.coord(rect.height),
              "\"",
              paint_attributes(fill, "fill"),
              radius,
              "/>",
            ]),
          )
      }
    })
  svg_document(options.width, options.height, [
    background_rect(options.width, options.height, palette.background),
    ..bars
  ])
}

/// Draws the same chart as `bar_svg` as 8-bit RGBA PNG bytes. A pixel that
/// a bar only partly covers, such as one under an edge on a half pixel, is
/// shaded by the share it covers, as a browser draws the SVG at 100% zoom.
/// The image is not compressed, so it is about `width * height * 4` bytes.
/// A colour that `Theme` does not accept gives `Error(InvalidColor(..))`.
///
pub fn bar_png(
  values: List(Float),
  options: BarOptions,
) -> Result(BitArray, InvalidColor) {
  let options = sanitise_bar(options)
  use palette <- result.map(check_theme(options.theme))
  let canvas =
    list.fold(
      bar_rects(values, options),
      raster.new(
        options.width,
        options.height,
        color.paint_rgba(palette.background),
      ),
      fn(canvas, rect) {
        case bar_paint(rect, palette) {
          color.NoPaint -> canvas
          fill ->
            raster.fill_rounded_rect(
              canvas,
              rect.x,
              rect.y,
              rect.width,
              rect.height,
              options.corner_radius,
              color.paint_rgba(fill),
            )
        }
      },
    )
  png.encode(
    raster.to_grid(canvas),
    width: options.width,
    height: options.height,
  )
}

fn bar_paint(rect: Rect, palette: Palette) -> color.Paint {
  case rect.value <. 0.0 {
    True -> palette.negative
    False -> palette.foreground
  }
}

fn sanitise_bar(options: BarOptions) -> BarOptions {
  BarOptions(
    ..options,
    width: int.max(options.width, 1),
    height: int.max(options.height, 1),
    gap: float.max(options.gap, 0.0),
    corner_radius: float.max(options.corner_radius, 0.0),
  )
}

type Rect {
  Rect(x: Float, y: Float, width: Float, height: Float, value: Float)
}

fn bar_rects(values: List(Float), options: BarOptions) -> List(Rect) {
  let values = list.map(values, scale.finite)
  let height = int.to_float(options.height)
  let #(step, bar_width, margin) = bar_layout(list.length(values), options)
  let #(lo, hi) = scale.min_max(values)
  // The visible range always includes zero, so bars grow from zero.
  let y_min = float.min(lo, 0.0)
  let y_max = float.max(hi, 0.0)
  use value, i <- list.index_map(values)
  let x = int.to_float(i) *. step +. margin
  case lo == hi || y_max <=. y_min {
    // A constant series fills half the height instead of all of it, so it
    // does not look like the maximum of some wider range. Negative bars
    // hang from the top.
    True ->
      Rect(
        x:,
        y: case value <. 0.0 {
          True -> 0.0
          False -> height /. 2.0
        },
        width: bar_width,
        height: height /. 2.0,
        value:,
      )
    False -> {
      let zero_y = height -. scale.unit(0.0, y_min, y_max) *. height
      let value_y = height -. scale.unit(value, y_min, y_max) *. height
      let #(y, bar_height) = case value >=. 0.0 {
        True -> #(value_y, zero_y -. value_y)
        False -> #(zero_y, value_y -. zero_y)
      }
      case bar_height >. min_bar_height {
        True -> Rect(x:, y:, width: bar_width, height: bar_height, value:)
        False -> {
          let #(y, bar_height) = hairline(value, zero_y, height)
          Rect(x:, y:, width: bar_width, height: bar_height, value:)
        }
      }
    }
  }
}

// The width of each bar and its left edge in its share of the width. Each
// bar is centred in its share, so the chart has the same margin on both
// sides and mirrors exactly when the series is reversed. A gap that leaves
// no room for the bars is dropped.
fn bar_layout(count: Int, options: BarOptions) -> #(Float, Float, Float) {
  let step = int.to_float(options.width) /. int.to_float(int.max(count, 1))
  case step -. options.gap >. 0.0 {
    True -> #(step, step -. options.gap, options.gap /. 2.0)
    False -> #(step, step, 0.0)
  }
}

// A bar of `min_bar_height` at zero, above it for values of zero or more
// and below it for negative values, unless that would leave the canvas.
fn hairline(value: Float, zero_y: Float, height: Float) -> #(Float, Float) {
  let above_fits = zero_y >=. min_bar_height
  let below_fits = height -. zero_y >=. min_bar_height
  case value >=. 0.0, above_fits, below_fits {
    True, True, _ | False, _, False -> #(
      zero_y -. min_bar_height,
      min_bar_height,
    )
    True, False, _ | False, _, True -> #(zero_y, min_bar_height)
  }
}

// SVG and PNG helpers --------------------------------------------------------

fn svg_document(width: Int, height: Int, layers: List(StringTree)) -> String {
  let width = int.to_string(width)
  let height = int.to_string(height)
  string_tree.from_strings([
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"",
    width,
    "\" height=\"",
    height,
    "\" viewBox=\"0 0 ",
    width,
    " ",
    height,
    "\" preserveAspectRatio=\"none\">",
  ])
  |> string_tree.append_tree(string_tree.concat(layers))
  |> string_tree.append("</svg>")
  |> string_tree.to_string
}

fn background_rect(
  width: Int,
  height: Int,
  background: color.Paint,
) -> StringTree {
  case background {
    color.NoPaint -> string_tree.new()
    _ ->
      string_tree.from_strings([
        "<rect x=\"0\" y=\"0\" width=\"",
        int.to_string(width),
        "\" height=\"",
        int.to_string(height),
        "\"",
        paint_attributes(background, "fill"),
        "/>",
      ])
  }
}

// ` fill="..."` or ` stroke="..."`, and an opacity attribute when the
// paint is translucent. Every paint has been checked, so none of them
// needs escaping.
fn paint_attributes(paint: color.Paint, attribute: String) -> String {
  let #(colour, opacity) = color.svg_colour(paint)
  " "
  <> attribute
  <> "=\""
  <> colour
  <> "\""
  <> case opacity <. 1.0 {
    True -> " " <> attribute <> "-opacity=\"" <> format.opacity(opacity) <> "\""
    False -> ""
  }
}

// Colours ---------------------------------------------------------------------

// The theme's colours, checked.
type Palette {
  Palette(
    foreground: color.Paint,
    background: color.Paint,
    area: color.Paint,
    negative: color.Paint,
  )
}

fn check_theme(theme: Theme) -> Result(Palette, InvalidColor) {
  use foreground <- result.try(check_colour("foreground", theme.foreground))
  use background <- result.try(check_colour("background", theme.background))
  use area <- result.try(case theme.area {
    None -> Ok(color.fade(foreground, factor: area_alpha))
    Some(value) -> check_colour("area", value)
  })
  use negative <- result.map(check_colour("negative", theme.negative))
  Palette(foreground:, background:, area:, negative:)
}

fn check_colour(
  field: String,
  value: String,
) -> Result(color.Paint, InvalidColor) {
  color.parse_paint(value)
  |> result.replace_error(InvalidColor(field:, value:))
}
