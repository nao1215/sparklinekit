//// Fuzz tests for sparklinekit.
////
//// sparklinekit does not have a byte-stream parser — every input is
//// typed. The realistic fuzz surface is therefore *user-supplied
//// strings* (colours, background colours) embedded in the SVG / PNG
//// output, and *unusual list shapes* (very long, very deep, mixed
//// sign, zero-heavy).
////
//// The contract being tested is:
////
//// - No public function panics on any well-typed input.
//// - SVG output is always well-formed (`<svg...>...</svg>`) regardless
////   of what colour string the caller passed.
//// - The renderer escapes XML-sensitive characters so a malicious or
////   careless colour string cannot break out of the attribute value.

import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/unicode

// --- Colour-string fuzz (line) ---------------------------------------

pub fn line_with_color_handles_empty_string_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("")
    |> line.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_with_color_handles_xml_special_chars_test() {
  let payloads = [
    "<script>",
    "\"><script>",
    "&amp;",
    "'>",
    "</svg>",
    "url(javascript:alert(1))",
    "<>&\"'",
  ]
  list.each(payloads, fn(payload) {
    let svg =
      line.new([1.0, 2.0, 3.0])
      |> line.with_color(payload)
      |> line.to_svg
    // The malicious payload must not appear unescaped inside the SVG.
    string.contains(svg, "<script>") |> should.be_false
    string.contains(svg, "</svg><script>") |> should.be_false
    // And the closing tag should still be the very last `</svg>`.
    string.ends_with(svg, "</svg>") |> should.be_true
  })
}

pub fn line_with_color_handles_very_long_string_test() {
  let long = string.repeat("a", 10_000)
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color(long)
    |> line.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_with_color_handles_embedded_quotes_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("red\" onload=\"alert(1)")
    |> line.to_svg
  // `onload` must not appear as a real attribute — it should be
  // escaped inside the colour attribute value.
  string.contains(svg, "stroke=\"red\" onload=") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_with_background_color_handles_xml_special_chars_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_background_color("<script>")
    |> line.to_svg
  string.contains(svg, "<script>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_with_area_color_handles_xml_special_chars_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_area_color("\"><foo")
    |> line.to_svg
  string.contains(svg, "<foo") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_with_spot_color_handles_xml_special_chars_test() {
  let svg =
    line.new([1.0, 2.0, 3.0])
    |> line.with_spot(3.0)
    |> line.with_spot_color("\"><evil>")
    |> line.to_svg
  string.contains(svg, "<evil>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

// --- Colour-string fuzz (bar) ----------------------------------------

pub fn bar_with_color_handles_xml_special_chars_test() {
  let payloads = ["<script>", "\"><foo", "&amp;", "'/>", "</svg>"]
  list.each(payloads, fn(payload) {
    let svg =
      bar.new([1.0, 2.0, 3.0])
      |> bar.with_color(payload)
      |> bar.to_svg
    string.contains(svg, "<script>") |> should.be_false
    string.contains(svg, "<foo") |> should.be_false
    string.ends_with(svg, "</svg>") |> should.be_true
  })
}

pub fn bar_with_negative_color_handles_xml_special_chars_test() {
  let svg =
    bar.new([1.0, -2.0, 3.0])
    |> bar.with_negative_color("\"><evil>")
    |> bar.to_svg
  string.contains(svg, "<evil>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn bar_with_background_color_handles_xml_special_chars_test() {
  let svg =
    bar.new([1.0, 2.0])
    |> bar.with_background_color("<script>")
    |> bar.to_svg
  string.contains(svg, "<script>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

// --- PNG with junk colours -------------------------------------------

pub fn line_to_png_handles_junk_colour_test() {
  // PNG parses the colour as hex; an unparseable colour should fall
  // back to the theme default rather than panic.
  let _png =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("not-a-hex")
    |> line.to_png
  Nil
}

pub fn line_to_png_handles_empty_colour_test() {
  let _png =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("")
    |> line.to_png
  Nil
}

pub fn line_to_png_handles_long_colour_test() {
  let long = string.repeat("z", 10_000)
  let _png =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color(long)
    |> line.to_png
  Nil
}

pub fn bar_to_png_handles_junk_colour_test() {
  let _png =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_color("rgb(garbage)")
    |> bar.with_negative_color("hsl(also-garbage)")
    |> bar.to_png
  Nil
}

// --- Large / pathological list shapes --------------------------------

pub fn unicode_handles_thousand_extreme_values_test() {
  let xs =
    list_range(1, 1000)
    |> list.map(fn(i) {
      case modulo(i, 4) {
        0 -> 1.0e30
        1 -> -1.0e30
        2 -> 0.0
        _ -> 1.0
      }
    })
  let out = unicode.render(xs)
  string.length(out) |> should.equal(1000)
}

pub fn line_handles_many_values_with_extreme_floats_test() {
  let xs =
    list_range(1, 200)
    |> list.map(fn(i) {
      case modulo(i, 3) {
        0 -> 1.0e20
        1 -> -1.0e20
        _ -> 0.0
      }
    })
  let svg = line.new(xs) |> line.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn bar_handles_many_values_with_extreme_floats_test() {
  let xs =
    list_range(1, 200)
    |> list.map(fn(i) {
      case modulo(i, 3) {
        0 -> 1.0e20
        1 -> -1.0e20
        _ -> 0.0
      }
    })
  let svg = bar.new(xs) |> bar.to_svg
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

// --- helpers ---------------------------------------------------------

fn list_range(lo: Int, hi: Int) -> List(Int) {
  case lo > hi {
    True -> []
    False -> do_list_range(hi, lo, [])
  }
}

fn do_list_range(current: Int, lo: Int, acc: List(Int)) -> List(Int) {
  case current < lo {
    True -> acc
    False -> do_list_range(current - 1, lo, [current, ..acc])
  }
}

fn modulo(value: Int, divisor: Int) -> Int {
  case int.modulo(value, divisor) {
    Ok(r) -> r
    Error(_) -> 0
  }
}
