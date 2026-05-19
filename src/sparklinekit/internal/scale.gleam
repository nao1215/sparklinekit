//// Internal numerical helpers shared by the renderers.
////
//// This module is intentionally not part of the public API. Anything
//// here may change between minor versions.

import gleam/float
import gleam/list

/// Maximum float magnitude the renderer keeps. Inputs above this in
/// absolute value get clamped to this cap before any subtraction so
/// that intermediate values like `max - min` stay well inside the
/// IEEE 754 double range (≈ 1.8e308). Without the cap the Erlang
/// target raises `arithmetic_error` and the JavaScript target
/// silently produces `Infinity` / `NaN` coordinates in SVG output.
///
/// The cap is high enough that no realistic dashboard input is
/// affected, and low enough that `safe_value - (-safe_value)` is
/// still finite.
const safe_finite_magnitude: Float = 1.0e300

/// Clamp `value` into `[-safe_finite_magnitude, safe_finite_magnitude]`.
///
/// This is the renderer's overflow guard for adversarial input — see
/// the constant docs above.
pub fn clamp_finite(value: Float) -> Float {
  case value >. safe_finite_magnitude {
    True -> safe_finite_magnitude
    False ->
      case value <. 0.0 -. safe_finite_magnitude {
        True -> 0.0 -. safe_finite_magnitude
        False -> value
      }
  }
}

/// Return the `#(minimum, maximum)` of a non-empty list of floats.
///
/// Returns `#(0.0, 0.0)` for the empty list — callers must guard
/// against that case before deciding what to render. Values outside
/// the safe finite range are clamped before the comparison so that
/// downstream `max - min` arithmetic cannot overflow.
pub fn min_max(values: List(Float)) -> #(Float, Float) {
  case values {
    [] -> #(0.0, 0.0)
    [head, ..rest] -> {
      let safe_head = clamp_finite(head)
      list.fold(rest, #(safe_head, safe_head), fn(acc, value) {
        let safe_value = clamp_finite(value)
        let #(lo, hi) = acc
        let new_lo = case safe_value <. lo {
          True -> safe_value
          False -> lo
        }
        let new_hi = case safe_value >. hi {
          True -> safe_value
          False -> hi
        }
        #(new_lo, new_hi)
      })
    }
  }
}

/// Normalise `value` against the inclusive `[min, max]` range to the
/// unit interval `[0.0, 1.0]`.
///
/// Degenerate ranges (`min == max`) collapse every value to `0.5`,
/// the middle of the unit interval. This is what produces the
/// horizontal "flat line" rendering for all-equal inputs. `value`
/// is clamped to the safe finite range before subtraction so the
/// numerator cannot overflow either.
pub fn unit(value: Float, min: Float, max: Float) -> Float {
  let safe_value = clamp_finite(value)
  let safe_min = clamp_finite(min)
  let safe_max = clamp_finite(max)
  let span = safe_max -. safe_min
  case span <=. 0.0 {
    True -> 0.5
    False -> { safe_value -. safe_min } /. span
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
