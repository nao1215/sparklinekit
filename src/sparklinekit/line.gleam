//// SVG line sparklines.
////
//// ```gleam
//// import sparklinekit/line
////
//// pub fn small_chart() -> String {
////   line.new([1.0, 5.0, 3.0, 8.0, 4.0])
////   |> line.with_color("#378ADD")
////   |> line.with_size(120, 30)
////   |> line.with_stroke_width(2.0)
////   |> line.to_string
//// }
//// ```
////
//// The output is a raw `<svg>` element string. It carries
//// `preserveAspectRatio="none"` so it scales cleanly inside any
//// container. The default stroke is `currentColor` so the line picks
//// up the surrounding CSS colour when embedded in HTML or a Lustre
//// view.

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleam/string_tree
import sparklinekit/internal/scale

const default_width: Int = 200

const default_height: Int = 40

const default_color: String = "currentColor"

const default_stroke_width: Float = 1.5

/// Opaque builder for a line sparkline.
pub opaque type Builder {
  Builder(
    values: List(Float),
    color: String,
    width: Int,
    height: Int,
    stroke_width: Float,
  )
}

/// Start a new line sparkline builder from a list of values.
///
/// Defaults: 200x40 viewBox, `currentColor` stroke, 1.5 stroke width.
pub fn new(values: List(Float)) -> Builder {
  Builder(
    values: values,
    color: default_color,
    width: default_width,
    height: default_height,
    stroke_width: default_stroke_width,
  )
}

/// Set the stroke colour (any CSS colour string).
///
/// The value is written into the `stroke` attribute as-is after
/// quote-escaping. Callers embedding user-controlled colour values
/// should validate them upstream.
pub fn with_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, color: color)
}

/// Set the viewBox dimensions in pixels.
///
/// Non-positive values are normalised to `1` to keep the SVG valid.
pub fn with_size(builder: Builder, width: Int, height: Int) -> Builder {
  Builder(
    ..builder,
    width: positive_or_one(width),
    height: positive_or_one(height),
  )
}

/// Set the stroke width in user units.
///
/// Non-positive values are normalised to a hairline `0.5` to keep
/// the polyline visible.
pub fn with_stroke_width(builder: Builder, stroke_width: Float) -> Builder {
  Builder(..builder, stroke_width: positive_float_or(stroke_width, 0.5))
}

/// Render the builder to an SVG element string.
pub fn to_string(builder: Builder) -> String {
  let Builder(values, color, width, height, stroke_width) = builder
  let body = polyline_body(values, width, height, color, stroke_width)
  string_tree.new()
  |> string_tree.append(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 ",
  )
  |> string_tree.append(int.to_string(width))
  |> string_tree.append(" ")
  |> string_tree.append(int.to_string(height))
  |> string_tree.append("\" preserveAspectRatio=\"none\">")
  |> string_tree.append_tree(body)
  |> string_tree.append("</svg>")
  |> string_tree.to_string
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
    [_] ->
      // Single value: draw a horizontal segment across the full width
      // at the midpoint so the user actually sees a line.
      coordinate_pair(0.0, mid) <> " " <> coordinate_pair(width_f, mid)
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
