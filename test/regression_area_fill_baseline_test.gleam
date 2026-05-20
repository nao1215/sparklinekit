//// Regression test for issue #6 — `line.with_area_fill(True)` must
//// anchor the area to the **zero baseline** rather than always
//// closing at the viewBox bottom edge.
////
//// Pre-fix behaviour: the area path closed at `y = height` for every
//// input, so a mixed-sign series like `[3, -2, 1, -4, 2]` was filled
//// all the way to the canvas floor and read visually as
//// "all-positive". The fix introduces three baseline rules — see
//// `area_baseline_y` in `src/sparklinekit/line.gleam` — and each
//// rule has a matching test below.

import gleam/string
import gleeunit/should
import sparklinekit/line

// --- Mixed-sign data must NOT close at the viewBox bottom.
//
// With `width=100`, `height=40` and the default stroke width of
// `2.0`, the padded drawing window is `top_y = 1.0`,
// `bottom_y = 39.0`. The viewBox bottom (`y = 40`) is the
// pre-fix close coordinate and the marker for the bug; the fix
// closes at the SVG y where data value `0.0` lives instead, which
// for `[3, -2, 1, -4, 2]` is `lo=-4`, `hi=3`, so
// `unit(0) = 4/7`, baseline = 39 - 4/7 * 38 ≈ 17.29 — nowhere near
// `y = 40`. We assert the absence of the pre-fix close string
// directly (matching the wording in the issue's DoD) and also
// confirm the path still closes with a `Z`.

pub fn area_fill_mixed_sign_uses_zero_baseline_test() {
  let svg =
    line.new([3.0, -2.0, 1.0, -4.0, 2.0])
    |> line.with_area_fill(True)
    |> line.with_size(100, 40)
    |> line.to_svg

  // The pre-fix path ended with this exact suffix. The fix must
  // close the area somewhere other than the canvas floor.
  svg
  |> string.contains("L 99.0 40.0 L 1.0 40.0 Z")
  |> should.be_false

  // The area path must still close (Z) — we're moving the
  // baseline, not removing it.
  svg
  |> string.contains("Z")
  |> should.be_true
}

// --- All-positive input keeps the legacy viewBox-bottom close so
// existing snapshots for monotone-positive series stay byte-identical.

pub fn area_fill_all_positive_keeps_bottom_baseline_test() {
  let svg =
    line.new([1.0, 2.0, 3.0, 4.0, 5.0])
    |> line.with_area_fill(True)
    |> line.with_size(100, 40)
    |> line.to_svg

  // The exact suffix from the pre-fix renderer — preserved for
  // all-non-negative data so existing visuals stay unchanged.
  svg
  |> string.contains("L 99.0 40.0 L 1.0 40.0 Z")
  |> should.be_true
}

// --- All-negative input mirrors the positive case: the fill grows
// upward to the viewBox top so a series that lives entirely below
// zero reads as "negative" the same way an all-positive series
// reads as "positive". The path therefore closes at `y = 0`.

pub fn area_fill_all_negative_uses_top_baseline_test() {
  let svg =
    line.new([-1.0, -2.0, -3.0, -4.0, -5.0])
    |> line.with_area_fill(True)
    |> line.with_size(100, 40)
    |> line.to_svg

  // Must close at the top edge, not the bottom.
  svg
  |> string.contains("L 99.0 0.0 L 1.0 0.0 Z")
  |> should.be_true

  // And must NOT close at the bottom — that would be the
  // pre-fix bug, just mirrored.
  svg
  |> string.contains("L 99.0 40.0 L 1.0 40.0 Z")
  |> should.be_false
}

// --- The mixed-sign baseline is the SVG y of data value 0.0. With
// `[3, -2, 1, -4, 2]`, `width=100`, `height=40`, default stroke
// (inset = 1.0), the padded window is `[top_y=1.0, bottom_y=39.0]`,
// `lo=-4.0`, `hi=3.0`, so `unit(0) = 4/7` and the baseline is
// `39 - 4/7 * 38 = 39 - 21.714... ≈ 17.286`. The exact string the
// `format.coord` helper emits is `17.29` (two-decimal rounding),
// shared by both the last-x and first-x close coordinates.

pub fn area_fill_mixed_sign_close_coordinate_test() {
  let svg =
    line.new([3.0, -2.0, 1.0, -4.0, 2.0])
    |> line.with_area_fill(True)
    |> line.with_size(100, 40)
    |> line.to_svg

  // Both close coordinates should sit at the same baseline y.
  svg
  |> string.contains("L 99.0 17.29 L 1.0 17.29 Z")
  |> should.be_true
}

// --- A single zero value crossed by a positive and a negative
// neighbour still produces a finite path that closes properly —
// regression guard against div-by-zero in the baseline math.

pub fn area_fill_mixed_sign_through_zero_still_closes_test() {
  let svg =
    line.new([1.0, 0.0, -1.0])
    |> line.with_area_fill(True)
    |> line.with_size(100, 40)
    |> line.to_svg

  svg
  |> string.contains("<path")
  |> should.be_true

  svg
  |> string.contains("Z")
  |> should.be_true

  // Mixed-sign series must not close at the canvas floor.
  svg
  |> string.contains("L 99.0 40.0 L 1.0 40.0 Z")
  |> should.be_false
}
