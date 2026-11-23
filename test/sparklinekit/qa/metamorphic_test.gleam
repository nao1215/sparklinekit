//// Metamorphic relations for sparklinekit.
////
//// These assert that *transformations of input* produce predictable
//// *transformations of output*. Sparklines are scale-invariant by
//// construction — every renderer normalises against the observed
//// `[min, max]` (except `bar`, which uses zero as a baseline), so:
////
//// - Scaling every value by a positive constant preserves the
////   Unicode shape (the relative bucket assignment is invariant under
////   affine transforms).
//// - Adding a constant offset preserves the shape.
//// - Reversing the input reverses the output.

import gleam/list
import gleam/string
import gleeunit/should
import render
import sparklinekit

const sample_values: List(Float) = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]

// --- Affine invariance (unicode) --------------------------------------

pub fn unicode_scaling_by_positive_constant_preserves_shape_test() {
  let baseline = sparklinekit.blocks(sample_values)
  let scaled =
    sample_values
    |> list.map(fn(v) { v *. 3.7 })
    |> sparklinekit.blocks
  scaled |> should.equal(baseline)
}

pub fn unicode_scaling_by_large_positive_constant_preserves_shape_test() {
  let baseline = sparklinekit.blocks(sample_values)
  let scaled =
    sample_values
    |> list.map(fn(v) { v *. 1.0e6 })
    |> sparklinekit.blocks
  scaled |> should.equal(baseline)
}

pub fn unicode_scaling_by_small_positive_constant_preserves_shape_test() {
  let baseline = sparklinekit.blocks(sample_values)
  let scaled =
    sample_values
    |> list.map(fn(v) { v *. 1.0e-6 })
    |> sparklinekit.blocks
  scaled |> should.equal(baseline)
}

pub fn unicode_offset_by_constant_preserves_shape_test() {
  let baseline = sparklinekit.blocks(sample_values)
  let offset =
    sample_values
    |> list.map(fn(v) { v +. 100.0 })
    |> sparklinekit.blocks
  offset |> should.equal(baseline)
}

pub fn unicode_negative_offset_preserves_shape_test() {
  let baseline = sparklinekit.blocks(sample_values)
  let offset =
    sample_values
    |> list.map(fn(v) { v -. 1000.0 })
    |> sparklinekit.blocks
  offset |> should.equal(baseline)
}

pub fn unicode_combined_affine_transform_preserves_shape_test() {
  let baseline = sparklinekit.blocks(sample_values)
  let transformed =
    sample_values
    |> list.map(fn(v) { v *. 2.5 +. 17.0 })
    |> sparklinekit.blocks
  transformed |> should.equal(baseline)
}

// --- Reverse symmetry -------------------------------------------------

pub fn unicode_reversed_input_reverses_output_test() {
  let forward = sparklinekit.blocks(sample_values)
  let reversed =
    sample_values
    |> list.reverse
    |> sparklinekit.blocks
  reversed
  |> string.reverse
  |> should.equal(forward)
}

pub fn unicode_reverse_is_involutive_test() {
  // Reversing twice should return to the original output.
  let baseline = sparklinekit.blocks(sample_values)
  let twice =
    sample_values
    |> list.reverse
    |> list.reverse
    |> sparklinekit.blocks
  twice |> should.equal(baseline)
}

// --- Length preservation ----------------------------------------------

pub fn unicode_length_equals_input_length_for_non_empty_test() {
  let xs = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
  let out = sparklinekit.blocks(xs)
  string.length(out) |> should.equal(list.length(xs))
}

pub fn unicode_length_preserved_under_scaling_test() {
  let xs = [1.0, 2.0, 3.0, 4.0, 5.0]
  let baseline = string.length(sparklinekit.blocks(xs))
  let scaled =
    string.length(sparklinekit.blocks(list.map(xs, fn(v) { v *. 42.0 })))
  baseline |> should.equal(scaled)
}

// --- Block-vocabulary invariance --------------------------------------

pub fn unicode_output_uses_only_block_characters_test() {
  let xs = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0, 100.0, 0.5, -3.0, 99.9]
  let out = sparklinekit.blocks(xs)
  let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  string.to_graphemes(out)
  |> list.each(fn(g) { list.contains(blocks, g) |> should.be_true })
}

// --- Stability (determinism) ------------------------------------------

pub fn unicode_render_is_deterministic_test() {
  let xs = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]
  let a = sparklinekit.blocks(xs)
  let b = sparklinekit.blocks(xs)
  let c = sparklinekit.blocks(xs)
  a |> should.equal(b)
  b |> should.equal(c)
}

pub fn line_to_svg_is_deterministic_test() {
  let make = fn() {
    render.line_svg(
      [1.0, 5.0, 3.0, 8.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        smoothing: 0.25,
        area: sparklinekit.GradientArea,
      ),
    )
  }
  make() |> should.equal(make())
}

pub fn bar_to_svg_is_deterministic_test() {
  let make = fn() {
    render.bar_svg(
      [3.0, -2.0, 5.0, -4.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.forest,
        corner_radius: 3.0,
      ),
    )
  }
  make() |> should.equal(make())
}
