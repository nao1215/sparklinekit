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

/// Blend a single pixel `colour` over whatever is currently at
/// `(x, y)`. Out-of-bounds writes are silently dropped.
pub fn put(canvas: Canvas, x: Int, y: Int, colour: Rgba) -> Canvas {
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

/// Fill an axis-aligned rectangle. `width` and `height` may be
/// fractional; the function rounds to integer pixel edges using the
/// standard `floor(x)..ceil(x+width)` convention so adjacent
/// rectangles tile without gaps.
pub fn fill_rect(
  canvas: Canvas,
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  colour: Rgba,
) -> Canvas {
  let x0 = float.round(x)
  let y0 = float.round(y)
  let x1 = float.round(x +. width)
  let y1 = float.round(y +. height)
  fill_rect_int(canvas, x0, y0, x1, y1, colour)
}

/// Fill a rounded-corner rectangle with `radius` user units of
/// corner radius. The radius is clamped to half the smaller side.
pub fn fill_rounded_rect(
  canvas: Canvas,
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  radius: Float,
  colour: Rgba,
) -> Canvas {
  let x0 = float.round(x)
  let y0 = float.round(y)
  let x1 = float.round(x +. width)
  let y1 = float.round(y +. height)
  let w = x1 - x0
  let h = y1 - y0
  let r =
    radius
    |> float.min(int.to_float(w) /. 2.0)
    |> float.min(int.to_float(h) /. 2.0)
    |> float.max(0.0)
  let r_int = float.round(r)
  case r_int <= 0 {
    True -> fill_rect_int(canvas, x0, y0, x1, y1, colour)
    False -> rounded_rect_rows(canvas, x0, y0, x1, y1, r_int, colour)
  }
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

/// Fill the rectangle `(x0, y0) -> (x1, y1)` with a vertical gradient
/// that linearly interpolates from `top_colour` to `bottom_colour`
/// across each row.
pub fn fill_vertical_gradient(
  canvas: Canvas,
  x0: Float,
  y0: Float,
  x1: Float,
  y1: Float,
  top_colour: Rgba,
  bottom_colour: Rgba,
) -> Canvas {
  let xa = float.round(float.min(x0, x1))
  let xb = float.round(float.max(x0, x1))
  let ya = float.round(float.min(y0, y1))
  let yb = float.round(float.max(y0, y1))
  case xa >= xb || ya >= yb {
    True -> canvas
    False -> {
      let xs = range(xa, xb - 1)
      let span_f = int.to_float(yb - ya)
      range(ya, yb - 1)
      |> list.fold(canvas, fn(c, y) {
        let t = case span_f <=. 0.0 {
          True -> 0.0
          False -> int.to_float(y - ya) /. span_f
        }
        let row_colour = interpolate(top_colour, bottom_colour, t)
        list.fold(xs, c, fn(c2, x) { put(c2, x, y, row_colour) })
      })
    }
  }
}

fn interpolate(a: Rgba, b: Rgba, t: Float) -> Rgba {
  let t_ = case t {
    v if v <. 0.0 -> 0.0
    v if v >. 1.0 -> 1.0
    v -> v
  }
  let mix = fn(a_ch: Int, b_ch: Int) -> Int {
    let af = int.to_float(a_ch)
    let bf = int.to_float(b_ch)
    case float.round(af +. { bf -. af } *. t_) {
      v if v < 0 -> 0
      v if v > 255 -> 255
      v -> v
    }
  }
  let color.Rgba(ar, ag, ab, aa) = a
  let color.Rgba(br, bg, bb, ba) = b
  color.Rgba(r: mix(ar, br), g: mix(ag, bg), b: mix(ab, bb), a: mix(aa, ba))
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

fn range(lo: Int, hi: Int) -> List(Int) {
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

fn fill_rect_int(
  canvas: Canvas,
  x0: Int,
  y0: Int,
  x1: Int,
  y1: Int,
  colour: Rgba,
) -> Canvas {
  let x_lo = max_int(0, min_int(x0, x1))
  let x_hi = min_int(canvas.width, max_int(x0, x1))
  let y_lo = max_int(0, min_int(y0, y1))
  let y_hi = min_int(canvas.height, max_int(y0, y1))
  case x_hi <= x_lo || y_hi <= y_lo {
    True -> canvas
    False -> {
      let xs = range(x_lo, x_hi - 1)
      range(y_lo, y_hi - 1)
      |> list.fold(canvas, fn(c, y) {
        list.fold(xs, c, fn(c2, x) { put(c2, x, y, colour) })
      })
    }
  }
}

fn rounded_rect_rows(
  canvas: Canvas,
  x0: Int,
  y0: Int,
  x1: Int,
  y1: Int,
  r: Int,
  colour: Rgba,
) -> Canvas {
  let w = x1 - x0
  let h = y1 - y0
  case w <= 0 || h <= 0 {
    True -> canvas
    False -> {
      range(0, h - 1)
      |> list.fold(canvas, fn(c, dy) {
        let inset = row_inset(dy, h, r)
        let row_x0 = x0 + inset
        let row_x1 = x1 - inset
        case row_x1 > row_x0 {
          True -> fill_rect_int(c, row_x0, y0 + dy, row_x1, y0 + dy + 1, colour)
          False -> c
        }
      })
    }
  }
}

fn row_inset(dy: Int, height: Int, radius: Int) -> Int {
  let top_zone = dy < radius
  let bottom_zone = dy >= height - radius
  case top_zone, bottom_zone {
    False, False -> 0
    _, _ -> {
      let local_y = case top_zone {
        True -> radius - 1 - dy
        False -> dy - { height - radius }
      }
      let r_sq = radius * radius
      let local_y_sq = local_y * local_y
      let max_x_sq = r_sq - local_y_sq
      let dx = isqrt(max_x_sq)
      radius - dx
    }
  }
}

fn isqrt(value: Int) -> Int {
  case value <= 0 {
    True -> 0
    False -> isqrt_loop(value, value)
  }
}

fn isqrt_loop(value: Int, guess: Int) -> Int {
  let next = { guess + value / guess } / 2
  case next >= guess {
    True -> guess
    False -> isqrt_loop(value, next)
  }
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

fn min_int(a: Int, b: Int) -> Int {
  case a < b {
    True -> a
    False -> b
  }
}

fn max_int(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}
