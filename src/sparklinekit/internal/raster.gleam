//// Tiny in-memory raster surface used by the PNG renderers.
////
//// Pixels are kept in a sparse `Dict(Int, Dict(Int, Rgba))` keyed by
//// `y -> x -> colour`; rendering operations blend onto whatever is
//// already there (or onto the background) using
//// [`color.over`](./color.html#over). The whole grid is materialised
//// only at the end via [`to_grid/1`](#to_grid), so per-pixel writes
//// stay cheap even on the Erlang target.
////
//// This module is intentionally private.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import sparklinekit/internal/color.{type Rgba}

/// A 2-D drawing surface backed by a sparse pixel map.
pub type Canvas {
  Canvas(
    width: Int,
    height: Int,
    background: Rgba,
    pixels: Dict(Int, Dict(Int, Rgba)),
  )
}

/// Create a new canvas of `width x height` filled with `background`.
pub fn new(width: Int, height: Int, background: Rgba) -> Canvas {
  Canvas(
    width: width,
    height: height,
    background: background,
    pixels: dict.new(),
  )
}

// Blends `colour` over the pixel at `(x, y)`. Writes outside the canvas
// are dropped.
fn put(canvas: Canvas, x: Int, y: Int, colour: Rgba) -> Canvas {
  case in_bounds(canvas, x, y) {
    False -> canvas
    True -> {
      let existing = current_at(canvas, x, y)
      let blended = color.over(colour, existing)
      let row = case dict.get(canvas.pixels, y) {
        Ok(r) -> r
        Error(_) -> dict.new()
      }
      let row = dict.insert(row, x, blended)
      Canvas(..canvas, pixels: dict.insert(canvas.pixels, y, row))
    }
  }
}

/// Fill a rectangle with corners rounded by `radius`, which is clamped to
/// half the smaller side, as SVG draws a `<rect>` with that `rx`. Each
/// pixel takes `colour` at the share of its area the shape covers, so an
/// edge between two pixels, such as one on a half pixel, shades both.
pub fn fill_rounded_rect(
  canvas: Canvas,
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  radius: Float,
  colour: Rgba,
) -> Canvas {
  let shape =
    Shape(
      left: x,
      top: y,
      right: x +. width,
      bottom: y +. height,
      radius: radius
        |> float.min(width /. 2.0)
        |> float.min(height /. 2.0)
        |> float.max(0.0),
    )
  let columns = covered_cells(shape.left, shape.right, canvas.width)
  use canvas, row <- list.fold(
    covered_cells(shape.top, shape.bottom, canvas.height),
    canvas,
  )
  use canvas, column <- list.fold(columns, canvas)
  let coverage = shape_coverage(shape, column, row)
  case coverage >. 0.0 {
    True -> put(canvas, column, row, color.with_alpha(colour, factor: coverage))
    False -> canvas
  }
}

/// The share of the pixel `[cell, cell + 1]` that `[from, to]` covers, in
/// one direction.
pub fn overlap(cell: Int, from: Float, to: Float) -> Float {
  let cell = int.to_float(cell)
  float.max(float.min(cell +. 1.0, to) -. float.max(cell, from), 0.0)
}

// The cells from `from` to `to` that are inside `0..size`.
fn covered_cells(from: Float, to: Float, size: Int) -> List(Int) {
  range(
    int.max(float.truncate(float.floor(from)), 0),
    int.min(float.truncate(float.ceiling(to)), size) - 1,
  )
}

type Shape {
  Shape(left: Float, top: Float, right: Float, bottom: Float, radius: Float)
}

// Pixels a rounded corner passes through are sampled on a grid of this
// many points a side; every other pixel is covered by a rectangle, whose
// share is exact.
const corner_samples = 16

fn shape_coverage(shape: Shape, column: Int, row: Int) -> Float {
  let Shape(left:, top:, right:, bottom:, radius:) = shape
  let x = int.to_float(column)
  let y = int.to_float(row)
  let in_corner =
    radius >. 0.0
    && { x <. left +. radius || x +. 1.0 >. right -. radius }
    && { y <. top +. radius || y +. 1.0 >. bottom -. radius }
  case in_corner {
    False -> overlap(column, left, right) *. overlap(row, top, bottom)
    True -> sampled_coverage(shape, x, y)
  }
}

fn sampled_coverage(shape: Shape, x: Float, y: Float) -> Float {
  let offsets =
    range(0, corner_samples - 1)
    |> list.map(fn(i) {
      { int.to_float(i) +. 0.5 } /. int.to_float(corner_samples)
    })
  let inside = {
    use count, dy <- list.fold(offsets, 0)
    use count, dx <- list.fold(offsets, count)
    case inside_shape(shape, x +. dx, y +. dy) {
      True -> count + 1
      False -> count
    }
  }
  int.to_float(inside) /. int.to_float(corner_samples * corner_samples)
}

fn inside_shape(shape: Shape, x: Float, y: Float) -> Bool {
  let Shape(left:, top:, right:, bottom:, radius:) = shape
  let dx = x -. float.clamp(x, min: left +. radius, max: right -. radius)
  let dy = y -. float.clamp(y, min: top +. radius, max: bottom -. radius)
  x >=. left
  && x <=. right
  && y >=. top
  && y <=. bottom
  && dx *. dx +. dy *. dy <=. radius *. radius
}

/// Draw an anti-aliased line from `(x0, y0)` to `(x1, y1)` using
/// Xiaolin Wu's algorithm, with `thickness` user units of stroke
/// width centred on the geometric line. `thickness <= 0` is treated
/// as a hairline (`thickness = 1.0`).
pub fn draw_line(
  canvas: Canvas,
  x0: Float,
  y0: Float,
  x1: Float,
  y1: Float,
  thickness: Float,
  colour: Rgba,
) -> Canvas {
  let actual_thickness = case thickness >. 0.0 {
    True -> thickness
    False -> 1.0
  }
  let dx = x1 -. x0
  let dy = y1 -. y0
  let steep = float.absolute_value(dy) >. float.absolute_value(dx)
  let #(x0_, y0_, x1_, y1_) = case steep {
    True -> #(y0, x0, y1, x1)
    False -> #(x0, y0, x1, y1)
  }
  let #(x0_, y0_, x1_, y1_) = case x0_ >. x1_ {
    True -> #(x1_, y1_, x0_, y0_)
    False -> #(x0_, y0_, x1_, y1_)
  }
  let new_dx = x1_ -. x0_
  let new_dy = y1_ -. y0_
  let gradient = case new_dx == 0.0 {
    True -> 1.0
    False -> new_dy /. new_dx
  }
  let start_x = float.round(x0_)
  let end_x = float.round(x1_)
  let half_thick = actual_thickness /. 2.0
  do_wu_line(
    canvas,
    start_x,
    end_x,
    int.to_float(start_x),
    y0_ +. gradient *. { int.to_float(start_x) -. x0_ },
    gradient,
    steep,
    half_thick,
    colour,
  )
}

/// Draw a filled disc of `radius` user units centred at `(cx, cy)`.
/// Pixels on the rim are anti-aliased by the fractional area they
/// cover so small spots look round rather than blocky.
pub fn fill_circle(
  canvas: Canvas,
  cx: Float,
  cy: Float,
  radius: Float,
  colour: Rgba,
) -> Canvas {
  case radius <=. 0.0 {
    True -> canvas
    False -> {
      let x0 = float.round(cx -. radius -. 1.0)
      let x1 = float.round(cx +. radius +. 1.0)
      let y0 = float.round(cy -. radius -. 1.0)
      let y1 = float.round(cy +. radius +. 1.0)
      let xs = range(x0, x1)
      range(y0, y1)
      |> list.fold(canvas, fn(c, y) {
        list.fold(xs, c, fn(c2, x) {
          plot_disc_pixel(c2, x, y, cx, cy, radius, colour)
        })
      })
    }
  }
}

fn plot_disc_pixel(
  canvas: Canvas,
  x: Int,
  y: Int,
  cx: Float,
  cy: Float,
  radius: Float,
  colour: Rgba,
) -> Canvas {
  let dx = int.to_float(x) +. 0.5 -. cx
  let dy = int.to_float(y) +. 0.5 -. cy
  let dist = float_sqrt(dx *. dx +. dy *. dy)
  let coverage = case dist <=. radius -. 0.5 {
    True -> 1.0
    False ->
      case dist >=. radius +. 0.5 {
        True -> 0.0
        False -> radius +. 0.5 -. dist
      }
  }
  case coverage >. 0.0 {
    False -> canvas
    True -> put(canvas, x, y, color.with_alpha(colour, factor: coverage))
  }
}

fn float_sqrt(value: Float) -> Float {
  case value <=. 0.0 {
    True -> 0.0
    False ->
      case float.square_root(value) {
        Ok(v) -> v
        Error(_) -> 0.0
      }
  }
}

/// Fills column `x` from `from` to `to` (in either order), rounded to whole
/// pixels. Each pixel takes `colour_at` of the y of its centre.
pub fn fill_column(
  canvas: Canvas,
  x: Int,
  from: Float,
  to: Float,
  colour_at: fn(Float) -> Rgba,
) -> Canvas {
  let top = float.round(float.min(from, to))
  let bottom = float.round(float.max(from, to))
  use canvas, y <- list.fold(range(top, bottom - 1), canvas)
  put(canvas, x, y, colour_at(int.to_float(y) +. 0.5))
}

/// Materialise the canvas into a row-major `List(List(Rgba))` ready
/// for [`png.encode`](./png.html#encode). Cells that were never
/// written take the canvas background colour.
pub fn to_grid(canvas: Canvas) -> List(List(Rgba)) {
  let xs = range(0, canvas.width - 1)
  range(0, canvas.height - 1)
  |> list.map(fn(y) {
    case dict.get(canvas.pixels, y) {
      Error(_) -> list.map(xs, fn(_) { canvas.background })
      Ok(row) ->
        list.map(xs, fn(x) {
          case dict.get(row, x) {
            Ok(c) -> c
            Error(_) -> canvas.background
          }
        })
    }
  })
}

/// Returns the integers from `lo` to `hi`, both included, or `[]` when
/// `lo > hi`.
pub fn range(lo: Int, hi: Int) -> List(Int) {
  case lo > hi {
    True -> []
    False -> do_range(hi, lo, [])
  }
}

fn do_range(current: Int, lo: Int, acc: List(Int)) -> List(Int) {
  case current < lo {
    True -> acc
    False -> do_range(current - 1, lo, [current, ..acc])
  }
}

fn current_at(canvas: Canvas, x: Int, y: Int) -> Rgba {
  case dict.get(canvas.pixels, y) {
    Error(_) -> canvas.background
    Ok(row) ->
      case dict.get(row, x) {
        Ok(c) -> c
        Error(_) -> canvas.background
      }
  }
}

fn in_bounds(canvas: Canvas, x: Int, y: Int) -> Bool {
  x >= 0 && x < canvas.width && y >= 0 && y < canvas.height
}

fn do_wu_line(
  canvas: Canvas,
  major: Int,
  end_major: Int,
  raw_major: Float,
  minor_centre: Float,
  gradient: Float,
  steep: Bool,
  half_thick: Float,
  colour: Rgba,
) -> Canvas {
  case major > end_major {
    True -> canvas
    False -> {
      let updated =
        plot_perpendicular(
          canvas,
          major,
          minor_centre,
          steep,
          half_thick,
          colour,
        )
      do_wu_line(
        updated,
        major + 1,
        end_major,
        raw_major +. 1.0,
        minor_centre +. gradient,
        gradient,
        steep,
        half_thick,
        colour,
      )
    }
  }
}

fn plot_perpendicular(
  canvas: Canvas,
  major: Int,
  minor_centre: Float,
  steep: Bool,
  half_thick: Float,
  colour: Rgba,
) -> Canvas {
  let minor_lo = float.floor(minor_centre -. half_thick)
  let minor_hi = float.ceiling(minor_centre +. half_thick)
  let lo_i = float.round(minor_lo)
  let hi_i = float.round(minor_hi)
  range(lo_i, hi_i)
  |> list.fold(canvas, fn(c, minor) {
    let coverage = pixel_coverage(int.to_float(minor), minor_centre, half_thick)
    case coverage >. 0.0 {
      False -> c
      True -> {
        let tinted = color.with_alpha(colour, factor: coverage)
        let #(px, py) = case steep {
          True -> #(minor, major)
          False -> #(major, minor)
        }
        put(c, px, py, tinted)
      }
    }
  })
}

fn pixel_coverage(
  pixel_centre: Float,
  line_centre: Float,
  half_thick: Float,
) -> Float {
  let pixel_lo = pixel_centre -. 0.5
  let pixel_hi = pixel_centre +. 0.5
  let band_lo = line_centre -. half_thick
  let band_hi = line_centre +. half_thick
  let overlap_lo = float.max(pixel_lo, band_lo)
  let overlap_hi = float.min(pixel_hi, band_hi)
  let overlap = overlap_hi -. overlap_lo
  case overlap <=. 0.0 {
    True -> 0.0
    False ->
      case overlap >=. 1.0 {
        True -> 1.0
        False -> overlap
      }
  }
}
