//// Formatting helpers shared by the SVG renderers. Private — anything
//// here may change between minor versions.

import gleam/float
import gleam/int

/// Format a coordinate (or any pixel-space float) for SVG output,
/// rounding to two decimal places. SVG renderers can't see sub-pixel
/// differences in a sparkline at any reasonable display size, so the
/// extra precision from `float.to_string` (which emits 14+ decimal
/// digits for some intermediate results) is wasted bytes that bloat
/// the output and clutter inspection.
pub fn coord(value: Float) -> String {
  let scaled = value *. 100.0
  let rounded = int.to_float(float.round(scaled)) /. 100.0
  float.to_string(rounded)
}
