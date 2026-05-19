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
//// - The string builder API is idempotent — repeated `with_X` calls
////   keep only the last value.

import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme
import sparklinekit/unicode

const sample_values: List(Float) = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]

// --- Affine invariance (unicode) --------------------------------------

pub fn unicode_scaling_by_positive_constant_preserves_shape_test() {
  let baseline = unicode.render(sample_values)
  let scaled =
    sample_values
    |> list.map(fn(v) { v *. 3.7 })
    |> unicode.render
  scaled |> should.equal(baseline)
}

pub fn unicode_scaling_by_large_positive_constant_preserves_shape_test() {
  let baseline = unicode.render(sample_values)
  let scaled =
    sample_values
    |> list.map(fn(v) { v *. 1.0e6 })
    |> unicode.render
  scaled |> should.equal(baseline)
}

pub fn unicode_scaling_by_small_positive_constant_preserves_shape_test() {
  let baseline = unicode.render(sample_values)
  let scaled =
    sample_values
    |> list.map(fn(v) { v *. 1.0e-6 })
    |> unicode.render
  scaled |> should.equal(baseline)
}

pub fn unicode_offset_by_constant_preserves_shape_test() {
  let baseline = unicode.render(sample_values)
  let offset =
    sample_values
    |> list.map(fn(v) { v +. 100.0 })
    |> unicode.render
  offset |> should.equal(baseline)
}

pub fn unicode_negative_offset_preserves_shape_test() {
  let baseline = unicode.render(sample_values)
  let offset =
    sample_values
    |> list.map(fn(v) { v -. 1000.0 })
    |> unicode.render
  offset |> should.equal(baseline)
}

pub fn unicode_combined_affine_transform_preserves_shape_test() {
  let baseline = unicode.render(sample_values)
  let transformed =
    sample_values
    |> list.map(fn(v) { v *. 2.5 +. 17.0 })
    |> unicode.render
  transformed |> should.equal(baseline)
}

// --- Reverse symmetry -------------------------------------------------

pub fn unicode_reversed_input_reverses_output_test() {
  let forward = unicode.render(sample_values)
  let reversed =
    sample_values
    |> list.reverse
    |> unicode.render
  reversed
  |> string.reverse
  |> should.equal(forward)
}

pub fn unicode_reverse_is_involutive_test() {
  // Reversing twice should return to the original output.
  let baseline = unicode.render(sample_values)
  let twice =
    sample_values
    |> list.reverse
    |> list.reverse
    |> unicode.render
  twice |> should.equal(baseline)
}

// --- Length preservation ----------------------------------------------

pub fn unicode_length_equals_input_length_for_non_empty_test() {
  let xs = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
  let out = unicode.render(xs)
  string.length(out) |> should.equal(list.length(xs))
}

pub fn unicode_length_preserved_under_scaling_test() {
  let xs = [1.0, 2.0, 3.0, 4.0, 5.0]
  let baseline = string.length(unicode.render(xs))
  let scaled = string.length(unicode.render(list.map(xs, fn(v) { v *. 42.0 })))
  baseline |> should.equal(scaled)
}

// --- Block-vocabulary invariance --------------------------------------

pub fn unicode_output_uses_only_block_characters_test() {
  let xs = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0, 100.0, 0.5, -3.0, 99.9]
  let out = unicode.render(xs)
  let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  string.to_graphemes(out)
  |> list.each(fn(g) { list.contains(blocks, g) |> should.be_true })
}

// --- Builder idempotence (line) ---------------------------------------

pub fn line_with_color_last_wins_test() {
  let a =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("#111111")
    |> line.with_color("#222222")
    |> line.to_svg
  let b =
    line.new([1.0, 2.0, 3.0])
    |> line.with_color("#222222")
    |> line.to_svg
  a |> should.equal(b)
}

pub fn line_with_size_last_wins_test() {
  let a =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(100, 50)
    |> line.with_size(240, 60)
    |> line.to_svg
  let b =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(240, 60)
    |> line.to_svg
  a |> should.equal(b)
}

pub fn line_with_stroke_width_last_wins_test() {
  let a =
    line.new([1.0, 2.0, 3.0])
    |> line.with_stroke_width(1.0)
    |> line.with_stroke_width(3.0)
    |> line.to_svg
  let b =
    line.new([1.0, 2.0, 3.0])
    |> line.with_stroke_width(3.0)
    |> line.to_svg
  a |> should.equal(b)
}

pub fn line_with_smoothing_last_wins_test() {
  let a =
    line.new([1.0, 5.0, 3.0, 8.0])
    |> line.with_smoothing(0.1)
    |> line.with_smoothing(0.4)
    |> line.to_svg
  let b =
    line.new([1.0, 5.0, 3.0, 8.0])
    |> line.with_smoothing(0.4)
    |> line.to_svg
  a |> should.equal(b)
}

// --- Builder idempotence (bar) ----------------------------------------

pub fn bar_with_color_last_wins_test() {
  let a =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_color("#111111")
    |> bar.with_color("#222222")
    |> bar.to_svg
  let b =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_color("#222222")
    |> bar.to_svg
  a |> should.equal(b)
}

pub fn bar_with_corner_radius_last_wins_test() {
  let a =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_corner_radius(1.0)
    |> bar.with_corner_radius(5.0)
    |> bar.to_svg
  let b =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_corner_radius(5.0)
    |> bar.to_svg
  a |> should.equal(b)
}

// --- Theme last-wins --------------------------------------------------

pub fn line_with_theme_last_wins_test() {
  let a =
    line.new([1.0, 2.0, 3.0])
    |> line.with_theme(theme.ocean())
    |> line.with_theme(theme.forest())
    |> line.to_svg
  let b =
    line.new([1.0, 2.0, 3.0])
    |> line.with_theme(theme.forest())
    |> line.to_svg
  a |> should.equal(b)
}

pub fn bar_with_theme_last_wins_test() {
  let a =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_theme(theme.crimson())
    |> bar.with_theme(theme.midnight())
    |> bar.to_svg
  let b =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_theme(theme.midnight())
    |> bar.to_svg
  a |> should.equal(b)
}

// --- Stability (determinism) ------------------------------------------

pub fn unicode_render_is_deterministic_test() {
  let xs = [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]
  let a = unicode.render(xs)
  let b = unicode.render(xs)
  let c = unicode.render(xs)
  a |> should.equal(b)
  b |> should.equal(c)
}

pub fn line_to_svg_is_deterministic_test() {
  let make = fn() {
    line.new([1.0, 5.0, 3.0, 8.0])
    |> line.with_theme(theme.ocean())
    |> line.with_smoothing(0.25)
    |> line.with_area_fill(True)
    |> line.to_svg
  }
  make() |> should.equal(make())
}

pub fn bar_to_svg_is_deterministic_test() {
  let make = fn() {
    bar.new([3.0, -2.0, 5.0, -4.0])
    |> bar.with_theme(theme.forest())
    |> bar.with_corner_radius(3.0)
    |> bar.to_svg
  }
  make() |> should.equal(make())
}

// --- Int / Float equivalence ------------------------------------------

pub fn unicode_render_ints_matches_render_floats_test() {
  let ints = [1, 5, 22, 13, 5, 2, 7]
  let floats = list.map(ints, int.to_float)
  unicode.render_ints(ints) |> should.equal(unicode.render(floats))
}

pub fn line_new_ints_matches_new_test() {
  let ints = [1, 5, 3, 8, 4]
  let floats = list.map(ints, int.to_float)
  let a = line.new_ints(ints) |> line.to_svg
  let b = line.new(floats) |> line.to_svg
  a |> should.equal(b)
}

pub fn bar_new_ints_matches_new_test() {
  let ints = [3, -2, 5, -4, 6, -1]
  let floats = list.map(ints, int.to_float)
  let a = bar.new_ints(ints) |> bar.to_svg
  let b = bar.new(floats) |> bar.to_svg
  a |> should.equal(b)
}
