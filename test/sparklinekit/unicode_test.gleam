import gleeunit/should
import sparklinekit/unicode

pub fn empty_input_renders_empty_string_test() {
  unicode.render([])
  |> should.equal("")
}

pub fn single_value_renders_middle_block_test() {
  unicode.render([5.0])
  |> should.equal("▄")
}

pub fn all_equal_values_render_middle_blocks_test() {
  unicode.render([3.0, 3.0, 3.0])
  |> should.equal("▄▄▄")
}

pub fn evenly_spaced_values_cover_all_eight_levels_test() {
  unicode.render([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  |> should.equal("▁▂▃▄▅▆▇█")
}

pub fn three_values_round_to_low_mid_high_test() {
  unicode.render([100.0, 200.0, 300.0])
  |> should.equal("▁▅█")
}

pub fn negative_values_normalise_against_observed_range_test() {
  unicode.render([-100.0, 0.0, 100.0])
  |> should.equal("▁▅█")
}

pub fn render_ints_matches_render_floats_test() {
  unicode.render_ints([1, 5, 22, 13, 5, 2, 7])
  |> should.equal(unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0]))
}

pub fn wikipedia_example_test() {
  // The Wikipedia article on sparklines uses [1, 5, 22, 13, 5, 2, 7]
  // as its illustrative payload; the package description leads with it,
  // so it's a useful smoke check that the example actually round-trips.
  unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
  |> should.equal("▁▂█▅▂▁▃")
}
