//// Formatting helpers shared by the SVG renderers. Private — anything
//// here may change between minor versions.

import gleam/float
import gleam/int

/// Largest absolute value `coord/1` will scale through. Anything
/// beyond is clamped to this cap before being multiplied by 100,
/// which keeps the intermediate value well inside the IEEE 754
/// double range (≈ 1.8e308) on both the Erlang and JavaScript
/// targets. Without the cap, adversarial inputs like
/// `with_stroke_width(1.0e308)` overflow `value *. 100.0` and
/// either raise `arithmetic_error` on Erlang or emit the string
/// `"Infinity"` into the SVG attribute on JavaScript.
const coord_clamp_magnitude: Float = 1.0e6

/// Format a coordinate (or any pixel-space float) for SVG output,
/// rounding to two decimal places. SVG renderers can't see sub-pixel
/// differences in a sparkline at any reasonable display size, so the
/// extra precision from `float.to_string` (which emits 14+ decimal
/// digits for some intermediate results) is wasted bytes that bloat
/// the output and clutter inspection.
///
/// Values outside `±coord_clamp_magnitude` are clamped to that
/// range so the renderer stays total for adversarial input.
pub fn coord(value: Float) -> String {
  let safe = clamp_coord(value)
  let scaled = safe *. 100.0
  let rounded = int.to_float(float.round(scaled)) /. 100.0
  float.to_string(rounded)
}

fn clamp_coord(value: Float) -> Float {
  case value >. coord_clamp_magnitude {
    True -> coord_clamp_magnitude
    False ->
      case value <. 0.0 -. coord_clamp_magnitude {
        True -> 0.0 -. coord_clamp_magnitude
        False -> value
      }
  }
}
