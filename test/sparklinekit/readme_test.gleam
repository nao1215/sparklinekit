//// Mirrors every code block in `README.md` so the published samples
//// keep compiling and producing reasonable output as the library
//// evolves. Each `*_sample` function reproduces a README block
//// verbatim; the matching `*_test` function exercises it and
//// asserts the output is non-empty / well-formed.

import gleam/bit_array
import gleam/io
import gleam/list
import gleam/string
import gleeunit/should

import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme
import sparklinekit/unicode

// --- Unicode samples ---------------------------------------------------

pub fn shape_sample() -> String {
  unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
}

pub fn shape_from_ints_sample() -> String {
  unicode.render_ints([1, 5, 22, 13, 5, 2, 7])
}

pub fn print_latency_sample(samples: List(Float)) -> Nil {
  io.println("latency  " <> unicode.render(samples))
}

pub fn unicode_shape_test() {
  shape_sample() |> should.equal("▁▂█▅▂▁▃")
}

pub fn unicode_shape_ints_matches_floats_test() {
  shape_from_ints_sample() |> should.equal(shape_sample())
}

pub fn print_latency_runs_test() {
  print_latency_sample([1.0, 2.0, 3.0]) |> should.equal(Nil)
}

// --- SVG line samples --------------------------------------------------

pub fn minimal_line_sample() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.to_svg
}

pub fn themed_line_sample() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_theme(theme.ocean())
  |> line.to_svg
}

pub fn smooth_line_sample() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0])
  |> line.with_theme(theme.ocean())
  |> line.with_smoothing(0.25)
  |> line.to_svg
}

pub fn area_line_sample() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0])
  |> line.with_theme(theme.ocean())
  |> line.with_smoothing(0.25)
  |> line.with_area_fill(True)
  |> line.with_spot(3.0)
  |> line.to_svg
}

pub fn raw_colour_line_sample() -> String {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_color("#378ADD")
  |> line.with_size(240, 60)
  |> line.with_stroke_width(2.0)
  |> line.to_svg
}

pub fn line_with_ints_sample() -> String {
  line.new_ints([1, 5, 3, 8, 4])
  |> line.with_theme(theme.forest())
  |> line.to_svg
}

pub fn minimal_line_renders_svg_test() {
  minimal_line_sample()
  |> svg_well_formed
  |> should.be_true
}

pub fn themed_line_uses_ocean_stroke_test() {
  themed_line_sample()
  |> string.contains("stroke=\"#2563EB\"")
  |> should.be_true
}

pub fn smooth_line_emits_cubic_bezier_test() {
  smooth_line_sample()
  |> string.contains(" C ")
  |> should.be_true
}

pub fn area_line_emits_gradient_and_spot_test() {
  let svg = area_line_sample()
  svg |> string.contains("<linearGradient") |> should.be_true
  svg |> string.contains("<circle") |> should.be_true
}

pub fn raw_colour_line_uses_explicit_stroke_test() {
  raw_colour_line_sample()
  |> string.contains("stroke=\"#378ADD\"")
  |> should.be_true
}

pub fn line_with_ints_renders_svg_test() {
  line_with_ints_sample()
  |> svg_well_formed
  |> should.be_true
}

// --- SVG bar samples ---------------------------------------------------

pub fn minimal_bar_sample() -> String {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0])
  |> bar.to_svg
}

pub fn rounded_bar_sample() -> String {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0])
  |> bar.with_theme(theme.sunset())
  |> bar.with_corner_radius(3.0)
  |> bar.with_bar_gap(4.0)
  |> bar.to_svg
}

pub fn win_loss_sample() -> String {
  bar.new([3.0, -2.0, 5.0, -4.0, 6.0, -1.0])
  |> bar.with_color("#22A06B")
  |> bar.with_negative_color("#E5484D")
  |> bar.with_bar_gap(3.0)
  |> bar.to_svg
}

pub fn themed_win_loss_sample() -> String {
  bar.new_ints([3, -2, 5, -4, 6, -1])
  |> bar.with_theme(theme.forest())
  |> bar.with_corner_radius(3.0)
  |> bar.to_svg
}

pub fn minimal_bar_renders_rects_test() {
  minimal_bar_sample()
  |> string.contains("<rect")
  |> should.be_true
}

pub fn rounded_bar_emits_corner_radius_test() {
  rounded_bar_sample()
  |> string.contains("rx=\"")
  |> should.be_true
}

pub fn win_loss_paints_positive_and_negative_colors_test() {
  let svg = win_loss_sample()
  svg |> string.contains("fill=\"#22A06B\"") |> should.be_true
  svg |> string.contains("fill=\"#E5484D\"") |> should.be_true
}

pub fn themed_win_loss_uses_theme_negative_colour_test() {
  themed_win_loss_sample()
  |> string.contains("fill=\"#EF4444\"")
  |> should.be_true
}

// --- PNG samples -------------------------------------------------------

pub fn line_png_sample() -> BitArray {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.with_color("#378ADD")
  |> line.with_size(240, 60)
  |> line.with_smoothing(0.25)
  |> line.with_area_fill(True)
  |> line.to_png
}

pub fn bar_png_sample() -> BitArray {
  bar.new([3.0, 7.0, 2.0, 9.0, 5.0, 11.0, 6.0])
  |> bar.with_theme(theme.sunset())
  |> bar.with_corner_radius(3.0)
  |> bar.to_png
}

/// Defined to mirror the README block; the test below only verifies
/// the function compiles and is callable — actually writing to disk
/// is left for the caller.
pub fn save_to_disk_sample(path: String) {
  line.new([1.0, 5.0, 3.0, 8.0, 4.0])
  |> line.to_png
  |> save_bits(path, _)
}

fn save_bits(path: String, bits: BitArray) -> #(String, BitArray) {
  // Stand-in for `simplifile.write_bits(to: path, bits: _)`. We
  // avoid touching the filesystem in tests but exercise the same
  // argument order so the README snippet stays type-checked.
  #(path, bits)
}

pub fn line_png_starts_with_signature_test() {
  let bytes = line_png_sample()
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature())
    Error(_) -> should.fail()
  }
}

pub fn bar_png_starts_with_signature_test() {
  let bytes = bar_png_sample()
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature())
    Error(_) -> should.fail()
  }
}

pub fn save_to_disk_passes_path_and_bytes_test() {
  let #(path, bits) = save_to_disk_sample("chart.png")
  path |> should.equal("chart.png")
  case bit_array.slice(bits, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature())
    Error(_) -> should.fail()
  }
}

// --- Theme gallery sample ---------------------------------------------

pub fn theme_gallery_sample() -> List(String) {
  let values = [1.0, 5.0, 3.0, 8.0, 4.0, 9.0, 6.0]
  let render = fn(t) {
    line.new(values)
    |> line.with_theme(t)
    |> line.with_area_fill(True)
    |> line.to_svg
  }
  [
    render(theme.ocean()),
    render(theme.forest()),
    render(theme.sunset()),
    render(theme.mono()),
    render(theme.neon()),
    render(theme.pastel()),
  ]
}

pub fn theme_gallery_renders_six_svgs_test() {
  theme_gallery_sample()
  |> list.length
  |> should.equal(6)

  theme_gallery_sample()
  |> list.all(svg_well_formed)
  |> should.be_true
}

// --- Edge case samples -------------------------------------------------

pub fn empty_unicode_sample() -> String {
  unicode.render([])
}

pub fn empty_line_svg_sample() -> String {
  line.new([])
  |> line.to_svg
}

pub fn empty_bar_svg_sample() -> String {
  bar.new([])
  |> bar.to_svg
}

pub fn empty_unicode_returns_empty_string_test() {
  empty_unicode_sample() |> should.equal("")
}

pub fn empty_line_svg_has_no_path_test() {
  let svg = empty_line_svg_sample()
  svg |> svg_well_formed |> should.be_true
  svg |> string.contains("<path") |> should.be_false
}

pub fn empty_bar_svg_has_no_rect_test() {
  let svg = empty_bar_svg_sample()
  svg |> svg_well_formed |> should.be_true
  svg |> string.contains("<rect") |> should.be_false
}

// --- helpers -----------------------------------------------------------

fn svg_well_formed(svg: String) -> Bool {
  string.starts_with(svg, "<svg") && string.ends_with(svg, "</svg>")
}

fn png_signature() -> BitArray {
  <<137, 80, 78, 71, 13, 10, 26, 10>>
}
