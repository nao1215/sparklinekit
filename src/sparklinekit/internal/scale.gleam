//// Internal numerical helpers shared by the renderers.
////
//// This module is intentionally not part of the public API. Anything
//// here may change between minor versions.

import gleam/float
import gleam/list

/// Return the `#(minimum, maximum)` of a non-empty list of floats.
///
/// Returns `#(0.0, 0.0)` for the empty list — callers must guard
/// against that case before deciding what to render.
pub fn min_max(values: List(Float)) -> #(Float, Float) {
  case values {
    [] -> #(0.0, 0.0)
    [head, ..rest] ->
      list.fold(rest, #(head, head), fn(acc, value) {
        let #(lo, hi) = acc
        let new_lo = case value <. lo {
          True -> value
          False -> lo
        }
        let new_hi = case value >. hi {
          True -> value
          False -> hi
        }
        #(new_lo, new_hi)
      })
  }
}

/// Normalise `value` against the inclusive `[min, max]` range to the
/// unit interval `[0.0, 1.0]`.
///
/// Degenerate ranges (`min == max`) collapse every value to `0.5`,
/// the middle of the unit interval. This is what produces the
/// horizontal "flat line" rendering for all-equal inputs.
pub fn unit(value: Float, min: Float, max: Float) -> Float {
  let span = max -. min
  case span <=. 0.0 {
    True -> 0.5
    False -> { value -. min } /. span
  }
}

/// Round a float to the nearest integer using IEEE 754 round-half-away
/// from zero (the same behaviour as Erlang's `:erlang.round/1`).
///
/// `gleam/float.round` already does this on both targets; this wrapper
/// exists to keep call sites self-documenting.
pub fn round_to_int(value: Float) -> Int {
  float.round(value)
}

/// Clamp `value` into `[lo, hi]`.
pub fn clamp_int(value: Int, lo: Int, hi: Int) -> Int {
  case value < lo {
    True -> lo
    False ->
      case value > hi {
        True -> hi
        False -> value
      }
  }
}
