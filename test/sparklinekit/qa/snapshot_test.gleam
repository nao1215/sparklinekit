//// Snapshot tests for sparklinekit.
////
//// Pin the attribute-level contract of canonical SVG and PNG outputs
//// so a silent behavioural drift would force the snapshot to be
//// updated and reviewed. The snapshots are intentionally
//// *attribute-level* rather than byte-exact — the coordinate-level
//// path data is allowed to evolve as long as the surrounding contract
//// (viewBox, dimensions, theme colours, PNG signature) does not.

import gleam/bit_array
import gleam/string
import gleeunit/should
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme

const png_signature: BitArray = <<137, 80, 78, 71, 13, 10, 26, 10>>

// --- Canonical SVG line contract --------------------------------------

pub fn snapshot_minimal_line_attributes_test() {
  let svg = line.new([1.0, 5.0, 3.0, 8.0, 4.0]) |> line.to_svg
  // Frame contract.
  string.contains(svg, "xmlns=\"http://www.w3.org/2000/svg\"")
  |> should.be_true
  string.contains(svg, "viewBox=\"0 0 240 60\"") |> should.be_true
  string.contains(svg, "width=\"240\"") |> should.be_true
  string.contains(svg, "height=\"60\"") |> should.be_true
  string.contains(svg, "preserveAspectRatio=\"none\"") |> should.be_true
  // Stroke contract.
  string.contains(svg, "<path") |> should.be_true
  string.contains(svg, "stroke=\"currentColor\"") |> should.be_true
  string.contains(svg, "stroke-width=\"2.0\"") |> should.be_true
  string.contains(svg, "stroke-linecap=\"round\"") |> should.be_true
  string.contains(svg, "stroke-linejoin=\"round\"") |> should.be_true
}

pub fn snapshot_themed_ocean_line_attributes_test() {
  let svg =
    line.new([1.0, 5.0, 3.0, 8.0, 4.0])
    |> line.with_theme(theme.ocean())
    |> line.to_svg
  string.contains(svg, "stroke=\"#2563EB\"") |> should.be_true
  string.contains(svg, "fill=\"#FFFFFF\"") |> should.be_true
}

pub fn snapshot_area_line_emits_linear_gradient_test() {
  let svg =
    line.new([1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0])
    |> line.with_theme(theme.ocean())
    |> line.with_smoothing(0.25)
    |> line.with_area_fill(True)
    |> line.with_spot(3.0)
    |> line.to_svg
  string.contains(svg, "<defs>") |> should.be_true
  string.contains(svg, "<linearGradient") |> should.be_true
  string.contains(svg, "<circle") |> should.be_true
  // Bézier control points must appear in path data.
  string.contains(svg, " C ") |> should.be_true
}

// --- Canonical SVG bar contract --------------------------------------

pub fn snapshot_minimal_bar_attributes_test() {
  let svg = bar.new([3.0, 7.0, 2.0, 9.0, 5.0]) |> bar.to_svg
  string.contains(svg, "viewBox=\"0 0 200 40\"") |> should.be_true
  string.contains(svg, "width=\"200\"") |> should.be_true
  string.contains(svg, "height=\"40\"") |> should.be_true
  string.contains(svg, "<rect") |> should.be_true
}

pub fn snapshot_rounded_amber_bar_attributes_test() {
  let svg =
    bar.new([3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0])
    |> bar.with_theme(theme.amber())
    |> bar.with_corner_radius(3.0)
    |> bar.with_bar_gap(4.0)
    |> bar.to_svg
  string.contains(svg, "fill=\"#F59E0B\"") |> should.be_true
  string.contains(svg, "rx=\"3.0\"") |> should.be_true
}

pub fn snapshot_win_loss_bar_uses_negative_color_test() {
  let svg =
    bar.new([3.0, -2.0, 5.0, -4.0, 6.0, -1.0])
    |> bar.with_color("#22A06B")
    |> bar.with_negative_color("#E5484D")
    |> bar.to_svg
  string.contains(svg, "fill=\"#22A06B\"") |> should.be_true
  string.contains(svg, "fill=\"#E5484D\"") |> should.be_true
}

// --- PNG contract -----------------------------------------------------

pub fn snapshot_line_png_signature_test() {
  let png =
    line.new([1.0, 5.0, 3.0, 8.0, 4.0])
    |> line.with_color("#378ADD")
    |> line.with_size(240, 60)
    |> line.to_png
  case bit_array.slice(png, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn snapshot_bar_png_signature_test() {
  let png =
    bar.new([3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0])
    |> bar.with_theme(theme.amber())
    |> bar.to_png
  case bit_array.slice(png, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

// --- Stability (same input → same output, always) --------------------

pub fn snapshot_line_stability_test() {
  let make = fn() {
    line.new([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
    |> line.with_theme(theme.ocean())
    |> line.with_smoothing(0.25)
    |> line.with_area_fill(True)
    |> line.with_spot(3.0)
    |> line.to_svg
  }
  let a = make()
  let b = make()
  let c = make()
  a |> should.equal(b)
  b |> should.equal(c)
}

pub fn snapshot_bar_stability_test() {
  let make = fn() {
    bar.new([3.0, -2.0, 5.0, -4.0, 6.0, -1.0])
    |> bar.with_theme(theme.forest())
    |> bar.with_corner_radius(3.0)
    |> bar.to_svg
  }
  let a = make()
  let b = make()
  let c = make()
  a |> should.equal(b)
  b |> should.equal(c)
}

pub fn snapshot_png_stability_test() {
  let make = fn() {
    line.new([1.0, 5.0, 3.0, 8.0, 4.0])
    |> line.with_theme(theme.ocean())
    |> line.to_png
  }
  make() |> should.equal(make())
}
