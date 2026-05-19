//// SVG bar sparklines.
////
//// ```gleam
//// import sparklinekit/bar
////
//// pub fn revenue() -> String {
////   bar.new([3.0, 7.0, 2.0, 9.0, 5.0])
////   |> bar.with_color("#7F77DD")
////   |> bar.with_size(160, 40)
////   |> bar.to_string
//// }
//// ```
////
//// Positive and negative values share a zero baseline: positives
//// rise above it, negatives fall below. All-positive input collapses
//// the baseline onto the bottom of the box.

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleam/string_tree
import sparklinekit/internal/scale

const default_width: Int = 200

const default_height: Int = 40

const default_color: String = "currentColor"

const default_gap: Float = 1.0

/// Opaque builder for a bar sparkline.
pub opaque type Builder {
  Builder(
    values: List(Float),
    color: String,
    width: Int,
    height: Int,
    gap: Float,
  )
}

/// Start a new bar sparkline builder.
///
/// Defaults: 200x40 viewBox, `currentColor` fill, 1.0px gap between bars.
pub fn new(values: List(Float)) -> Builder {
  Builder(
    values: values,
    color: default_color,
    width: default_width,
    height: default_height,
    gap: default_gap,
  )
}

/// Set the bar fill colour (any CSS colour string).
pub fn with_color(builder: Builder, color: String) -> Builder {
  Builder(..builder, color: color)
}

/// Set the viewBox dimensions in pixels.
///
/// Non-positive values are normalised to `1`.
pub fn with_size(builder: Builder, width: Int, height: Int) -> Builder {
  Builder(
    ..builder,
    width: positive_or_one(width),
    height: positive_or_one(height),
  )
}

/// Set the gap between adjacent bars in user units. The per-bar width
/// is derived from the total width, bar count, and this gap.
///
/// Negative values are clamped to `0.0`.
pub fn with_bar_gap(builder: Builder, gap: Float) -> Builder {
  Builder(..builder, gap: non_negative_float(gap))
}

/// Render the builder to an SVG element string.
pub fn to_string(builder: Builder) -> String {
  let Builder(values, color, width, height, gap) = builder
  let body = rect_body(values, width, height, color, gap)
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

fn rect_body(
  values: List(Float),
  width: Int,
  height: Int,
  color: String,
  gap: Float,
) -> string_tree.StringTree {
  case values {
    [] -> string_tree.new()
    _ -> {
      let count = list.length(values)
      let width_f = int.to_float(width)
      let height_f = int.to_float(height)
      let step = width_f /. int.to_float(count)
      let bar_w = case step -. gap >. 0.0 {
        True -> step -. gap
        False -> step
      }
      let #(lo, hi) = scale.min_max(values)
      let #(y_min, y_max) = effective_range(lo, hi)
      let span = y_max -. y_min
      let baseline_y = baseline_y(height_f, y_min, span)
      let fill = escape_attribute(color)
      let #(parts, _) =
        list.fold(values, #([], 0), fn(acc, value) {
          let #(rects, i) = acc
          let x = int.to_float(i) *. step
          let rect =
            render_rect(
              x,
              bar_w,
              value,
              y_min,
              span,
              baseline_y,
              height_f,
              fill,
            )
          #([rect, ..rects], i + 1)
        })
      parts
      |> list.reverse
      |> list.fold(string_tree.new(), fn(tree, piece) {
        string_tree.append(tree, piece)
      })
    }
  }
}

fn render_rect(
  x: Float,
  bar_w: Float,
  value: Float,
  y_min: Float,
  span: Float,
  baseline_y: Float,
  height_f: Float,
  fill: String,
) -> String {
  let y_value = y_coord(value, y_min, span, height_f)
  let #(rect_y, rect_h) = case value >=. 0.0 {
    True -> #(y_value, baseline_y -. y_value)
    False -> #(baseline_y, y_value -. baseline_y)
  }
  let safe_h = case rect_h >. 0.0 {
    True -> rect_h
    False -> 0.0
  }
  "<rect x=\""
  <> float.to_string(x)
  <> "\" y=\""
  <> float.to_string(rect_y)
  <> "\" width=\""
  <> float.to_string(bar_w)
  <> "\" height=\""
  <> float.to_string(safe_h)
  <> "\" fill=\""
  <> fill
  <> "\"/>"
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
