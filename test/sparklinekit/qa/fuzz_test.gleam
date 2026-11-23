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
//// - SVG output is always well-formed (`<svg...>...</svg>`).
//// - A colour string is either one `Theme` accepts or rejected with
////   `InvalidColor`, so a malicious or careless colour string cannot break
////   out of the attribute value.

import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import render
import sparklinekit

// --- Colour-string fuzz ----------------------------------------------

// Strings built from characters that matter to colour parsing and to SVG
// markup. Each is either a colour `Theme` accepts, and then is written into
// the SVG only in its checked form, or it is rejected with the field and
// the value.
const alphabet = [
  "#", "a", "F", "0", "9", "g", "\"", "<", ">", "&", " ", "'", "=", "n", "o",
  "e", "(", ")", ";", "/",
]

pub fn colour_strings_are_accepted_or_rejected_test() {
  use seed <- list.each(list_range(1, 400))
  let value = fuzz_string(seed)
  let theme = sparklinekit.Theme(..sparklinekit.ocean, foreground: value)
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      theme:,
      spot_radius: 1.0,
    )
  case sparklinekit.line_svg([1.0, 2.0], options) {
    Ok(svg) -> {
      // Only hex colours and the two keywords get through.
      let lowered = string.lowercase(value)
      assert string.starts_with(value, "#")
        || lowered == "none"
        || lowered == "currentcolor"
      assert !string.contains(value, "\"")
      assert !string.contains(value, "<")
      assert string.ends_with(svg, "</svg>")
    }
    Error(error) -> {
      assert error == sparklinekit.InvalidColor(field: "foreground", value:)
    }
  }
}

fn fuzz_string(seed: Int) -> String {
  let length = modulo(seed * 7, 10)
  list_range(1, length)
  |> list.map(fn(i) {
    let index = modulo(seed * 31 + i * 17 + seed * i, list.length(alphabet))
    case list.drop(alphabet, index) {
      [c, ..] -> c
      [] -> ""
    }
  })
  |> string.concat
  |> fn(s) {
    // Every fourth string starts like a hex colour so some get through.
    case modulo(seed, 4) {
      0 -> "#" <> s
      _ -> s
    }
  }
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
  let svg = render.line_svg(xs, sparklinekit.default_line_options)
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
  let svg = render.bar_svg(xs, sparklinekit.default_bar_options)
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
