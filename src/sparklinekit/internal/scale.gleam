//// Internal numerical helpers shared by the renderers.
////
//// This module is intentionally not part of the public API. Anything
//// here may change between minor versions.

import gleam/float
import gleam/list

/// The largest finite Float.
const max_finite: Float = 1.7976931348623157e308

/// Above this magnitude the difference of two values can overflow, which
/// raises on Erlang and gives `Infinity` on JavaScript, so `unit` halves
/// its operands first. Halving is exact for numbers this large.
const halve_above: Float = 8.0e307

/// `value` as a finite Float. Only JavaScript can produce the other two
/// cases: NaN is read as `0.0`, and `Infinity` and `-Infinity` as the
/// largest finite Float of the same sign.
pub fn finite(value: Float) -> Float {
  case value <. 0.0 || value >=. 0.0 {
    False -> 0.0
    True -> float.clamp(value, min: 0.0 -. max_finite, max: max_finite)
  }
}

/// Return the `#(minimum, maximum)` of a list of floats, read with
/// `finite`, or `#(0.0, 0.0)` for the empty list.
pub fn min_max(values: List(Float)) -> #(Float, Float) {
  case values {
    [] -> #(0.0, 0.0)
    [head, ..rest] -> {
      let head = finite(head)
      list.fold(rest, #(head, head), fn(acc, value) {
        let value = finite(value)
        #(float.min(acc.0, value), float.max(acc.1, value))
      })
    }
  }
}

/// Where `value` lies between `min` (0.0) and `max` (1.0), with every
/// argument read with `finite`. A range with `max <= min` puts every value
/// at `0.5`, which is what draws a constant series as a flat line.
pub fn unit(value: Float, min: Float, max: Float) -> Float {
  let value = finite(value)
  let min = finite(min)
  let max = finite(max)
  case max >. min {
    False -> 0.5
    True -> {
      let large =
        float.absolute_value(value) >. halve_above
        || float.absolute_value(min) >. halve_above
        || float.absolute_value(max) >. halve_above
      case large {
        True -> { value /. 2.0 -. min /. 2.0 } /. { max /. 2.0 -. min /. 2.0 }
        False -> { value -. min } /. { max -. min }
      }
    }
  }
}
