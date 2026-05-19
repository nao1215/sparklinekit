//// Differential tests for sparklinekit's unicode renderer.
////
//// The expected outputs below were produced by an independent Python
//// 3 reference implementation that follows the same documented
//// algorithm (eight blocks `▁▂▃▄▅▆▇█`, normalise against observed
//// `[min, max]`, round to nearest of 8 buckets, middle block `▄` for
//// empty / single / all-equal). The script lives in the QA
//// session's `logs/` directory and was captured at test-fixture
//// authoring time:
////
//// ```
//// blocks = '▁▂▃▄▅▆▇█'; middle = blocks[3]
//// for v in xs: idx = round((v - lo) / (hi - lo) * 7); out.append(blocks[idx])
//// ```
////
//// If sparklinekit ever disagrees with the reference on any of these
//// inputs, *either* the package has a bug *or* the reference does —
//// either way the divergence is worth investigating before shipping.

import gleam/list
import gleeunit/should
import sparklinekit/unicode

pub fn diff_readme_canonical_test() {
  unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
  |> should.equal("▁▂█▅▂▁▃")
}

pub fn diff_evenly_spaced_uses_full_alphabet_test() {
  unicode.render([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
  |> should.equal("▁▂▃▄▅▆▇█")
}

pub fn diff_all_zero_flat_line_test() {
  unicode.render([0.0, 0.0, 0.0])
  |> should.equal("▄▄▄")
}

pub fn diff_mixed_sign_three_values_test() {
  unicode.render([-5.0, 0.0, 5.0])
  |> should.equal("▁▅█")
}

pub fn diff_two_values_full_range_test() {
  unicode.render([1.0, 9.0])
  |> should.equal("▁█")
}

pub fn diff_non_uniform_distribution_test() {
  unicode.render([100.0, 200.0, 50.0, 175.0, 125.0])
  |> should.equal("▃█▁▇▅")
}

pub fn diff_all_negative_values_test() {
  unicode.render([0.0 -. 10.0, 0.0 -. 20.0, 0.0 -. 5.0, 0.0 -. 15.0])
  |> should.equal("▆▁█▃")
}

pub fn diff_half_integer_distribution_test() {
  unicode.render([0.5, 1.5, 2.5, 3.5, 4.5, 5.5])
  |> should.equal("▁▂▄▅▇█")
}

// --- Integer entry point matches float reference ---------------------

pub fn diff_render_ints_matches_reference_test() {
  let cases = [
    #([1, 5, 22, 13, 5, 2, 7], "▁▂█▅▂▁▃"),
    #([1, 2, 3, 4, 5, 6, 7, 8], "▁▂▃▄▅▆▇█"),
    #([0, 0, 0], "▄▄▄"),
    #([-5, 0, 5], "▁▅█"),
    #([1, 9], "▁█"),
    #([100, 200, 50, 175, 125], "▃█▁▇▅"),
  ]
  list.each(cases, fn(pair) {
    let #(ints, expected) = pair
    unicode.render_ints(ints) |> should.equal(expected)
  })
}
