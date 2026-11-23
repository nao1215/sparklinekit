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
import gleam/option
import gleam/string
import gleeunit/should
import sparklinekit

// --- Colour-string fuzz (line) ---------------------------------------

pub fn line_color_handles_empty_string_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(..sparklinekit.default_theme, foreground: ""),
      ),
    )
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_color_handles_xml_special_chars_test() {
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
      sparklinekit.line_svg(
        [1.0, 2.0, 3.0],
        sparklinekit.LineOptions(
          ..sparklinekit.default_line_options,
          theme: sparklinekit.Theme(
            ..sparklinekit.default_theme,
            foreground: payload,
          ),
        ),
      )
    // The malicious payload must not appear unescaped inside the SVG.
    string.contains(svg, "<script>") |> should.be_false
    string.contains(svg, "</svg><script>") |> should.be_false
    // And the closing tag should still be the very last `</svg>`.
    string.ends_with(svg, "</svg>") |> should.be_true
  })
}

pub fn line_color_handles_very_long_string_test() {
  let long = string.repeat("a", 10_000)
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: long,
        ),
      ),
    )
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_color_handles_embedded_quotes_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "red\" onload=\"alert(1)",
        ),
      ),
    )
  // `onload` must not appear as a real attribute — it should be
  // escaped inside the colour attribute value.
  string.contains(svg, "stroke=\"red\" onload=") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_background_color_handles_xml_special_chars_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          background: "<script>",
        ),
      ),
    )
  string.contains(svg, "<script>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_area_color_handles_xml_special_chars_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          area: option.Some("\"><foo"),
        ),
        area: sparklinekit.GradientArea,
      ),
    )
  string.contains(svg, "<foo") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn line_spot_color_handles_xml_special_chars_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        spot_radius: 3.0,
        spot_color: option.Some("\"><evil>"),
      ),
    )
  string.contains(svg, "<evil>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

// --- Colour-string fuzz (bar) ----------------------------------------

pub fn bar_color_handles_xml_special_chars_test() {
  let payloads = ["<script>", "\"><foo", "&amp;", "'/>", "</svg>"]
  list.each(payloads, fn(payload) {
    let svg =
      sparklinekit.bar_svg(
        [1.0, 2.0, 3.0],
        sparklinekit.BarOptions(
          ..sparklinekit.default_bar_options,
          theme: sparklinekit.Theme(
            ..sparklinekit.default_theme,
            foreground: payload,
          ),
        ),
      )
    string.contains(svg, "<script>") |> should.be_false
    string.contains(svg, "<foo") |> should.be_false
    string.ends_with(svg, "</svg>") |> should.be_true
  })
}

pub fn bar_negative_color_handles_xml_special_chars_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, -2.0, 3.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          negative: "\"><evil>",
        ),
      ),
    )
  string.contains(svg, "<evil>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn bar_background_color_handles_xml_special_chars_test() {
  let svg =
    sparklinekit.bar_svg(
      [1.0, 2.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          background: "<script>",
        ),
      ),
    )
  string.contains(svg, "<script>") |> should.be_false
  string.ends_with(svg, "</svg>") |> should.be_true
}

// --- PNG with junk colours -------------------------------------------

pub fn line_to_png_handles_junk_colour_test() {
  // PNG parses the colour as hex; an unparseable colour should fall
  // back to the theme default rather than panic.
  let _png =
    sparklinekit.line_png(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "not-a-hex",
        ),
      ),
    )
  Nil
}

pub fn line_to_png_handles_empty_colour_test() {
  let _png =
    sparklinekit.line_png(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(..sparklinekit.default_theme, foreground: ""),
      ),
    )
  Nil
}

pub fn line_to_png_handles_long_colour_test() {
  let long = string.repeat("z", 10_000)
  let _png =
    sparklinekit.line_png(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: long,
        ),
      ),
    )
  Nil
}

pub fn bar_to_png_handles_junk_colour_test() {
  let _png =
    sparklinekit.bar_png(
      [1.0, 2.0, 3.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "rgb(garbage)",
          negative: "hsl(also-garbage)",
        ),
      ),
    )
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
  let out = sparklinekit.blocks(xs)
  string.length(out) |> should.equal(1000)
}

pub fn line_handles_many_values_extreme_floats_test() {
  let xs =
    list_range(1, 200)
    |> list.map(fn(i) {
      case modulo(i, 3) {
        0 -> 1.0e20
        1 -> -1.0e20
        _ -> 0.0
      }
    })
  let svg = sparklinekit.line_svg(xs, sparklinekit.default_line_options)
  string.starts_with(svg, "<svg") |> should.be_true
  string.ends_with(svg, "</svg>") |> should.be_true
}

pub fn bar_handles_many_values_extreme_floats_test() {
  let xs =
    list_range(1, 200)
    |> list.map(fn(i) {
      case modulo(i, 3) {
        0 -> 1.0e20
        1 -> -1.0e20
        _ -> 0.0
      }
    })
  let svg = sparklinekit.bar_svg(xs, sparklinekit.default_bar_options)
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
