//// Internal colour helpers — hex parsing into 8-bit RGBA tuples and
//// the inverse `Rgba -> "#rrggbbaa"` conversion used by the PNG and
//// SVG renderers when they synthesise tints from a base colour.
////
//// This module is intentionally private. Anything here may change
//// between minor versions.

import gleam/float
import gleam/int
import gleam/result
import gleam/string

/// Opaque 8-bit-per-channel RGBA value.
///
/// The renderers carry colours around as strings (so callers can pass
/// any CSS colour into the SVG path) and only parse them to `Rgba`
/// when actually emitting raster pixels.
pub type Rgba {
  Rgba(r: Int, g: Int, b: Int, a: Int)
}

/// Solid black with no transparency — used as the fallback when a
/// colour string cannot be parsed.
pub const black: Rgba = Rgba(0, 0, 0, 255)

/// Fully transparent — used as the default PNG background.
pub const transparent: Rgba = Rgba(0, 0, 0, 0)

/// Parse a `#RGB`, `#RGBA`, `#RRGGBB`, or `#RRGGBBAA` string into an
/// `Rgba`. Returns `Error(Nil)` for any other shape, including named
/// colours like `currentColor` — the caller decides what to do with
/// that (usually: substitute a theme default).
pub fn parse_hex(value: String) -> Result(Rgba, Nil) {
  case string.starts_with(value, "#") {
    False -> Error(Nil)
    True -> {
      let body = string.drop_start(value, 1)
      case string.length(body) {
        3 -> short_hex(body, full_alpha: True)
        4 -> short_hex(body, full_alpha: False)
        6 -> long_hex(body, full_alpha: True)
        8 -> long_hex(body, full_alpha: False)
        _ -> Error(Nil)
      }
    }
  }
}

/// Parse `value` with `fallback` substituted when the parse fails.
pub fn parse_or(value: String, fallback fallback: Rgba) -> Rgba {
  case parse_hex(value) {
    Ok(rgba) -> rgba
    Error(_) -> fallback
  }
}

/// Render an `Rgba` as `#rrggbb` (alpha dropped) for use in SVG
/// attributes. Use [`to_hex_rgba`](#to_hex_rgba) when alpha matters.
pub fn to_hex_rgb(rgba: Rgba) -> String {
  let Rgba(r, g, b, _) = rgba
  "#" <> two_hex(r) <> two_hex(g) <> two_hex(b)
}

/// Render an `Rgba` as `#rrggbbaa`.
pub fn to_hex_rgba(rgba: Rgba) -> String {
  let Rgba(r, g, b, a) = rgba
  "#" <> two_hex(r) <> two_hex(g) <> two_hex(b) <> two_hex(a)
}

/// Multiply the alpha channel by `factor` (clamped to `[0.0, 1.0]`)
/// to produce a translucent variant of `rgba`.
pub fn with_alpha(rgba: Rgba, factor factor: Float) -> Rgba {
  let Rgba(r, g, b, a) = rgba
  let clamped = case factor {
    f if f <. 0.0 -> 0.0
    f if f >. 1.0 -> 1.0
    f -> f
  }
  let new_a = float.round(int.to_float(a) *. clamped)
  Rgba(r, g, b, new_a)
}

/// Alpha-blend `fg` over `bg` and return the resulting opaque
/// (`a = 255`) pixel.  Both inputs are 8-bit RGBA.
pub fn over(fg: Rgba, bg: Rgba) -> Rgba {
  let Rgba(fr, fg_, fb, fa) = fg
  let Rgba(br, bg_, bb, ba) = bg
  let fa_f = int.to_float(fa) /. 255.0
  let ba_f = int.to_float(ba) /. 255.0
  let out_a_f = fa_f +. ba_f *. { 1.0 -. fa_f }
  case out_a_f <=. 0.0 {
    True -> Rgba(0, 0, 0, 0)
    False ->
      Rgba(
        r: blend_channel(fr, br, fa_f, ba_f, out_a_f),
        g: blend_channel(fg_, bg_, fa_f, ba_f, out_a_f),
        b: blend_channel(fb, bb, fa_f, ba_f, out_a_f),
        a: clamp_byte(float.round(out_a_f *. 255.0)),
      )
  }
}

fn blend_channel(
  fg_channel: Int,
  bg_channel: Int,
  fg_alpha: Float,
  bg_alpha: Float,
  out_alpha: Float,
) -> Int {
  let fc = int.to_float(fg_channel)
  let bc = int.to_float(bg_channel)
  let blended =
    { fc *. fg_alpha +. bc *. bg_alpha *. { 1.0 -. fg_alpha } } /. out_alpha
  clamp_byte(float.round(blended))
}

fn short_hex(body: String, full_alpha full_alpha: Bool) -> Result(Rgba, Nil) {
  case string.to_graphemes(body), full_alpha {
    [r, g, b], True -> {
      use r_v <- result.try(parse_nibble(r))
      use g_v <- result.try(parse_nibble(g))
      use b_v <- result.try(parse_nibble(b))
      Ok(Rgba(expand(r_v), expand(g_v), expand(b_v), 255))
    }
    [r, g, b, a], False -> {
      use r_v <- result.try(parse_nibble(r))
      use g_v <- result.try(parse_nibble(g))
      use b_v <- result.try(parse_nibble(b))
      use a_v <- result.try(parse_nibble(a))
      Ok(Rgba(expand(r_v), expand(g_v), expand(b_v), expand(a_v)))
    }
    _, _ -> Error(Nil)
  }
}

fn long_hex(body: String, full_alpha full_alpha: Bool) -> Result(Rgba, Nil) {
  case full_alpha {
    True -> {
      use r <- result.try(parse_byte(string.slice(body, 0, 2)))
      use g <- result.try(parse_byte(string.slice(body, 2, 2)))
      use b <- result.try(parse_byte(string.slice(body, 4, 2)))
      Ok(Rgba(r, g, b, 255))
    }
    False -> {
      use r <- result.try(parse_byte(string.slice(body, 0, 2)))
      use g <- result.try(parse_byte(string.slice(body, 2, 2)))
      use b <- result.try(parse_byte(string.slice(body, 4, 2)))
      use a <- result.try(parse_byte(string.slice(body, 6, 2)))
      Ok(Rgba(r, g, b, a))
    }
  }
}

fn parse_byte(pair: String) -> Result(Int, Nil) {
  case string.to_graphemes(pair) {
    [hi, lo] -> {
      use hi_v <- result.try(parse_nibble(hi))
      use lo_v <- result.try(parse_nibble(lo))
      Ok(hi_v * 16 + lo_v)
    }
    _ -> Error(Nil)
  }
}

fn parse_nibble(grapheme: String) -> Result(Int, Nil) {
  case string.lowercase(grapheme) {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "a" -> Ok(10)
    "b" -> Ok(11)
    "c" -> Ok(12)
    "d" -> Ok(13)
    "e" -> Ok(14)
    "f" -> Ok(15)
    _ -> Error(Nil)
  }
}

fn expand(nibble: Int) -> Int {
  nibble * 16 + nibble
}

fn two_hex(value: Int) -> String {
  let s = int.to_base16(clamp_byte(value))
  case string.length(s) {
    1 -> "0" <> string.lowercase(s)
    _ -> string.lowercase(s)
  }
}

fn clamp_byte(value: Int) -> Int {
  case value {
    v if v < 0 -> 0
    v if v > 255 -> 255
    v -> v
  }
}
