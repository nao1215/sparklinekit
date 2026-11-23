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
////   sparklinekit.line_svg(
////     [1.0, 5.0, 3.0, 8.0, 4.0],
////     LineOptions(
////       ..sparklinekit.default_line_options,
////       theme: sparklinekit.ocean,
////       area: sparklinekit.GradientArea,
////     ),
////   )
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

/// The colours of a line or bar chart. SVG output takes any CSS colour.
/// PNG output reads only `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`. Any
/// other foreground or negative colour is drawn black, any other background
/// is left transparent, and any other area colour is replaced by the
/// foreground at 22% opacity.
///
pub type Theme {
  Theme(
    /// The line, or the bars at or above zero.
    foreground: String,
    /// The background rectangle. `"none"` or `""` draws no background.
    background: String,
    /// The area under a line. `None` or `Some("")` uses the foreground at 22%
    /// opacity, and `Some("none")` draws no area. SVG output draws any other
    /// colour as given, so a colour without its own transparency is drawn
    /// opaque under the line.
    area: Option(String),
    /// The bars below zero. Line charts ignore it.
    negative: String,
  )
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
/// scaled between the smallest and largest value.
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
        let level = float.round(scale.unit(value, lo, hi) *. 7.0)
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
  /// The area colour at the line, fading to transparent at the baseline.
  /// In SVG, an area colour that is not hex is drawn flat, and a series
  /// with values on both sides of zero fades from the top down.
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
    /// Colour of the dot. `None`, or a colour PNG output cannot read, uses
    /// the theme's foreground.
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
/// height.
///
/// ## Examples
///
/// ```gleam
/// sparklinekit.line_svg([1.0, 5.0, 3.0], sparklinekit.default_line_options)
/// // -> "<svg ...><path fill=\"none\" stroke=\"currentColor\" ... d=\"M 1.0 59.0 L 120.0 1.0 L 239.0 30.0\"/></svg>"
/// ```
///
/// ```gleam
/// sparklinekit.line_svg([], sparklinekit.default_line_options)
/// // -> "<svg ...></svg>"
/// ```
///
pub fn line_svg(values: List(Float), options: LineOptions) -> String {
  let options = sanitise_line(options)
  let points = line_points(values, options)
  let fill = case options.area, points {
    NoArea, _ | _, [] | _, [_] -> Error(Nil)
    area, _ -> Ok(svg_area_fill(area, options.theme, values, options))
  }
  let defs = case fill {
    Ok(GradientFill(id:, top:, upward:)) -> gradient_defs(id, top, upward)
    _ -> string_tree.new()
  }
  let area_layer = case fill {
    Ok(fill) -> area_path(fill, points, values, options)
    Error(_) -> string_tree.new()
  }
  svg_document(options.width, options.height, [
    defs,
    background_rect(options.width, options.height, options.theme.background),
    area_layer,
    stroke_path(points, options),
    spot_circle(points, options),
  ])
}

/// Draws the same chart as `line_svg` as 8-bit RGBA PNG bytes, with an
/// anti-aliased line. The image is not compressed, so it is about
/// `width * height * 4` bytes.
///
/// ## Examples
///
/// ```gleam
/// let png = sparklinekit.line_png([1.0, 5.0, 3.0], sparklinekit.default_line_options)
/// simplifile.write_bits(to: "chart.png", bits: png)
/// ```
///
pub fn line_png(values: List(Float), options: LineOptions) -> BitArray {
  let options = sanitise_line(options)
  let theme = options.theme
  let foreground = color.parse_or(theme.foreground, fallback: color.black)
  let points = line_points(values, options)
  let path = sampled_path(points, options.smoothing)
  let canvas = raster.new(options.width, options.height, background_rgba(theme))
  let canvas = case options.area, area_colour(theme) {
    NoArea, _ | _, Some("none") -> canvas
    area, _ ->
      fill_area(
        canvas,
        path,
        int.to_float(options.height),
        area_baseline(values, options),
        png_area_colour(theme, foreground),
        area == GradientArea,
      )
  }
  let canvas = draw_stroke(canvas, path, options.stroke_width, foreground)
  let canvas = case options.spot_radius >. 0.0, list.last(points) {
    True, Ok(#(x, y)) -> {
      let spot =
        option.unwrap(options.spot_color, theme.foreground)
        |> color.parse_or(fallback: foreground)
      raster.fill_circle(canvas, x, y, options.spot_radius, spot)
    }
    _, _ -> canvas
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

type SvgAreaFill {
  // `upward` is set when the area lies above the line, so the gradient
  // runs from the bottom up.
  GradientFill(id: String, top: Rgba, upward: Bool)
  FlatFill(color: String)
  // A CSS colour that cannot carry its own alpha, such as `currentColor`.
  TranslucentFill(color: String)
}

fn svg_area_fill(
  area: Area,
  theme: Theme,
  values: List(Float),
  options: LineOptions,
) -> SvgAreaFill {
  let area_colour = area_colour(theme)
  let hex = case area_colour {
    Some(c) -> color.parse_hex(c)
    None ->
      color.parse_hex(theme.foreground)
      |> result.map(color.with_alpha(_, factor: area_alpha))
  }
  let #(lo, hi) = scale.min_max(values)
  let upward = lo <. 0.0 && hi <=. 0.0
  case area, hex, area_colour {
    GradientArea, Ok(top), _ ->
      GradientFill(id: gradient_id(top, upward, values, options), top:, upward:)
    _, _, Some(c) -> FlatFill(c)
    _, Ok(tint), None -> FlatFill(color.to_hex_rgba(tint))
    _, Error(_), None -> TranslucentFill(theme.foreground)
  }
}

// The id includes the size, the value count and the colour, so several
// charts inlined into one page do not share a gradient by accident.
fn gradient_id(
  top: Rgba,
  upward: Bool,
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
  <> string.replace(color.to_hex_rgba(top), "#", "")
  <> case upward {
    True -> "-up"
    False -> ""
  }
}

// An empty area colour means the same as none, as it does for the
// background.
fn area_colour(theme: Theme) -> Option(String) {
  case theme.area {
    Some("") -> None
    other -> other
  }
}

fn gradient_defs(id: String, top: Rgba, upward: Bool) -> StringTree {
  let direction = case upward {
    True -> "\" x1=\"0\" y1=\"1\" x2=\"0\" y2=\"0\">"
    False -> "\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">"
  }
  string_tree.from_strings([
    "<defs><linearGradient id=\"",
    id,
    direction,
    "<stop offset=\"0%\" stop-color=\"",
    color.to_hex_rgba(top),
    "\"/>",
    "<stop offset=\"100%\" stop-color=\"",
    color.to_hex_rgba(color.with_alpha(top, factor: 0.0)),
    "\"/>",
    "</linearGradient></defs>",
  ])
}

fn area_path(
  fill: SvgAreaFill,
  points: List(#(Float, Float)),
  values: List(Float),
  options: LineOptions,
) -> StringTree {
  let #(fill, opacity) = case fill {
    GradientFill(id:, ..) -> #("url(#" <> id <> ")", "")
    FlatFill(c) -> #(escape_attribute(c), "")
    TranslucentFill(c) -> #(
      escape_attribute(c),
      " fill-opacity=\"" <> float.to_string(area_alpha) <> "\"",
    )
  }
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
    "<path fill=\"",
    fill,
    "\"",
    opacity,
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
  options: LineOptions,
) -> StringTree {
  case points {
    [] -> string_tree.new()
    _ ->
      string_tree.from_strings([
        "<path fill=\"none\" stroke=\"",
        escape_attribute(options.theme.foreground),
        "\" stroke-width=\"",
        format.coord(options.stroke_width),
        "\" stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"",
        path_data(points, options.smoothing),
        "\"/>",
      ])
  }
}

fn spot_circle(
  points: List(#(Float, Float)),
  options: LineOptions,
) -> StringTree {
  case options.spot_radius >. 0.0, list.last(points) {
    True, Ok(#(x, y)) ->
      string_tree.from_strings([
        "<circle cx=\"",
        format.coord(x),
        "\" cy=\"",
        format.coord(y),
        "\" r=\"",
        format.coord(options.spot_radius),
        "\" fill=\"",
        escape_attribute(option.unwrap(
          options.spot_color,
          options.theme.foreground,
        )),
        "\"/>",
      ])
    _, _ -> string_tree.new()
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

fn png_area_colour(theme: Theme, foreground: Rgba) -> Rgba {
  let tint = color.with_alpha(foreground, factor: area_alpha)
  case area_colour(theme) {
    Some(c) -> color.parse_or(c, fallback: tint)
    None -> tint
  }
}

fn fill_area(
  canvas: raster.Canvas,
  path: List(#(Float, Float)),
  height: Float,
  baseline: Float,
  fill: Rgba,
  gradient: Bool,
) -> raster.Canvas {
  let baseline = float.clamp(baseline, min: 0.0, max: height)
  let transparent = color.with_alpha(fill, factor: 0.0)
  use canvas, #(#(x0, y0), #(x1, y1)) <- list.fold(
    list.window_by_2(path),
    canvas,
  )
  use canvas, column <- list.fold(
    raster.range(float.round(x0), float.round(x1) - 1),
    canvas,
  )
  let x = int.to_float(column)
  let line_y =
    { y0 +. { y1 -. y0 } *. { x -. x0 } /. { x1 -. x0 } }
    |> float.clamp(min: 0.0, max: height)
  // The gradient is strongest at the line, whichever side of the baseline
  // the line is on.
  let #(top, bottom, top_colour, bottom_colour) = case line_y <=. baseline {
    True -> #(line_y, baseline, fill, transparent)
    False -> #(baseline, line_y, transparent, fill)
  }
  case bottom -. top >. 0.0, gradient {
    False, _ -> canvas
    True, False -> raster.fill_rect(canvas, x, top, 1.0, bottom -. top, fill)
    True, True ->
      raster.fill_vertical_gradient(
        canvas,
        x,
        top,
        x +. 1.0,
        bottom,
        top_colour,
        bottom_colour,
      )
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
    /// Space between bars. Negative values are treated as 0. When the gap
    /// is wider than a bar's share of the width, bars are drawn with no
    /// gap.
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
///
/// ## Examples
///
/// ```gleam
/// sparklinekit.bar_svg(
///   [3.0, -2.0, 5.0],
///   BarOptions(..sparklinekit.default_bar_options, theme: sparklinekit.forest),
/// )
/// ```
///
pub fn bar_svg(values: List(Float), options: BarOptions) -> String {
  let options = sanitise_bar(options)
  let theme = options.theme
  let positive = escape_attribute(theme.foreground)
  let negative = escape_attribute(theme.negative)
  let bars =
    bar_rects(values, options)
    |> list.map(fn(rect) {
      let radius =
        options.corner_radius
        |> float.min(rect.width /. 2.0)
        |> float.min(rect.height /. 2.0)
      let radius = case radius >. 0.0 {
        True -> " rx=\"" <> format.coord(radius) <> "\""
        False -> ""
      }
      let fill = case rect.value <. 0.0 {
        True -> negative
        False -> positive
      }
      string_tree.from_strings([
        "<rect x=\"",
        format.coord(rect.x),
        "\" y=\"",
        format.coord(rect.y),
        "\" width=\"",
        format.coord(rect.width),
        "\" height=\"",
        format.coord(rect.height),
        "\" fill=\"",
        fill,
        "\"",
        radius,
        "/>",
      ])
    })
  svg_document(options.width, options.height, [
    background_rect(options.width, options.height, theme.background),
    ..bars
  ])
}

/// Draws the same chart as `bar_svg` as 8-bit RGBA PNG bytes. The image is
/// not compressed, so it is about `width * height * 4` bytes.
///
pub fn bar_png(values: List(Float), options: BarOptions) -> BitArray {
  let options = sanitise_bar(options)
  let theme = options.theme
  let positive = color.parse_or(theme.foreground, fallback: color.black)
  let negative = color.parse_or(theme.negative, fallback: color.black)
  let canvas =
    list.fold(
      bar_rects(values, options),
      raster.new(options.width, options.height, background_rgba(theme)),
      fn(canvas, rect) {
        let colour = case rect.value <. 0.0 {
          True -> negative
          False -> positive
        }
        raster.fill_rounded_rect(
          canvas,
          rect.x,
          rect.y,
          rect.width,
          rect.height,
          options.corner_radius,
          colour,
        )
      },
    )
  png.encode(
    raster.to_grid(canvas),
    width: options.width,
    height: options.height,
  )
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
  // Clamped so `value - y_min` below cannot overflow.
  let values = list.map(values, scale.clamp_finite)
  let height = int.to_float(options.height)
  let step = int.to_float(options.width) /. int.to_float(list.length(values))
  let bar_width = case step -. options.gap >. 0.0 {
    True -> step -. options.gap
    False -> step
  }
  let #(lo, hi) = scale.min_max(values)
  // The visible range always includes zero, so bars grow from zero.
  let y_min = float.min(lo, 0.0)
  let span = float.max(hi, 0.0) -. y_min
  use value, i <- list.index_map(values)
  let x = int.to_float(i) *. step
  case lo == hi || span <=. 0.0 {
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
      let zero_y = height -. { 0.0 -. y_min } /. span *. height
      let value_y = height -. { value -. y_min } /. span *. height
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

fn background_rect(width: Int, height: Int, background: String) -> StringTree {
  case background {
    "none" | "" -> string_tree.new()
    _ ->
      string_tree.from_strings([
        "<rect x=\"0\" y=\"0\" width=\"",
        int.to_string(width),
        "\" height=\"",
        int.to_string(height),
        "\" fill=\"",
        escape_attribute(background),
        "\"/>",
      ])
  }
}

fn background_rgba(theme: Theme) -> Rgba {
  color.parse_or(theme.background, fallback: color.transparent)
}

fn escape_attribute(value: String) -> String {
  value
  |> string.replace("&", "&amp;")
  |> string.replace("\"", "&quot;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}
