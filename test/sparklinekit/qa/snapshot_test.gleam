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
import sparklinekit

const png_signature: BitArray = <<137, 80, 78, 71, 13, 10, 26, 10>>

// --- Canonical SVG line contract --------------------------------------

pub fn snapshot_minimal_line_attributes_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 5.0, 3.0, 8.0, 4.0],
      sparklinekit.default_line_options,
    )
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
    sparklinekit.line_svg(
      [1.0, 5.0, 3.0, 8.0, 4.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
      ),
    )
  string.contains(svg, "stroke=\"#2563EB\"") |> should.be_true
  string.contains(svg, "fill=\"#FFFFFF\"") |> should.be_true
}

pub fn snapshot_area_line_emits_linear_gradient_test() {
  let svg =
    sparklinekit.line_svg(
      [1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        smoothing: 0.25,
        area: sparklinekit.GradientArea,
        spot_radius: 3.0,
      ),
    )
  string.contains(svg, "<defs>") |> should.be_true
  string.contains(svg, "<linearGradient") |> should.be_true
  string.contains(svg, "<circle") |> should.be_true
  // Bézier control points must appear in path data.
  string.contains(svg, " C ") |> should.be_true
}

// --- Canonical SVG bar contract --------------------------------------

pub fn snapshot_minimal_bar_attributes_test() {
  let svg =
    sparklinekit.bar_svg(
      [3.0, 7.0, 2.0, 9.0, 5.0],
      sparklinekit.default_bar_options,
    )
  string.contains(svg, "viewBox=\"0 0 200 40\"") |> should.be_true
  string.contains(svg, "width=\"200\"") |> should.be_true
  string.contains(svg, "height=\"40\"") |> should.be_true
  string.contains(svg, "<rect") |> should.be_true
}

pub fn snapshot_rounded_amber_bar_attributes_test() {
  let svg =
    sparklinekit.bar_svg(
      [3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.amber,
        gap: 4.0,
        corner_radius: 3.0,
      ),
    )
  string.contains(svg, "fill=\"#F59E0B\"") |> should.be_true
  string.contains(svg, "rx=\"3.0\"") |> should.be_true
}

pub fn snapshot_win_loss_bar_uses_negative_color_test() {
  let svg =
    sparklinekit.bar_svg(
      [3.0, -2.0, 5.0, -4.0, 6.0, -1.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "#22A06B",
          negative: "#E5484D",
        ),
      ),
    )
  string.contains(svg, "fill=\"#22A06B\"") |> should.be_true
  string.contains(svg, "fill=\"#E5484D\"") |> should.be_true
}

// --- PNG contract -----------------------------------------------------

pub fn snapshot_line_png_signature_test() {
  let png =
    sparklinekit.line_png(
      [1.0, 5.0, 3.0, 8.0, 4.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 240,
        height: 60,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          foreground: "#378ADD",
        ),
      ),
    )
  case bit_array.slice(png, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn snapshot_bar_png_signature_test() {
  let png =
    sparklinekit.bar_png(
      [3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.amber,
      ),
    )
  case bit_array.slice(png, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

// --- Stability (same input → same output, always) --------------------

pub fn snapshot_line_stability_test() {
  let make = fn() {
    sparklinekit.line_svg(
      [1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
        smoothing: 0.25,
        area: sparklinekit.GradientArea,
        spot_radius: 3.0,
      ),
    )
  }
  let a = make()
  let b = make()
  let c = make()
  a |> should.equal(b)
  b |> should.equal(c)
}

pub fn snapshot_bar_stability_test() {
  let make = fn() {
    sparklinekit.bar_svg(
      [3.0, -2.0, 5.0, -4.0, 6.0, -1.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.forest,
        corner_radius: 3.0,
      ),
    )
  }
  let a = make()
  let b = make()
  let c = make()
  a |> should.equal(b)
  b |> should.equal(c)
}

pub fn snapshot_png_stability_test() {
  let make = fn() {
    sparklinekit.line_png(
      [1.0, 5.0, 3.0, 8.0, 4.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
      ),
    )
  }
  make() |> should.equal(make())
}
