import gleam/bit_array
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should
import render
import sparklinekit
import sparklinekit/output_snapshot_test

const png_signature: BitArray = <<137, 80, 78, 71, 13, 10, 26, 10>>

pub fn line_png_starts_signature_test() {
  let bytes =
    render.line_png(
      [1.0, 5.0, 3.0, 8.0, 4.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        theme: sparklinekit.ocean,
      ),
    )
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn bar_png_starts_signature_test() {
  let bytes =
    render.bar_png(
      [3.0, 7.0, 2.0, 9.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        theme: sparklinekit.sunset,
      ),
    )
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn line_png_for_empty_input_still_returns_valid_signature_test() {
  let bytes =
    render.line_png(
      [],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 40,
        height: 20,
      ),
    )
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn empty_input_png_has_the_configured_size_test() {
  let line_png =
    render.line_png(
      [],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 40,
        height: 20,
      ),
    )
  let bar_png =
    render.bar_png(
      [],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 40,
        height: 20,
      ),
    )
  ihdr_size(line_png) |> should.equal(Ok(#(40, 20)))
  ihdr_size(bar_png) |> should.equal(Ok(#(40, 20)))
}

pub fn empty_input_png_is_a_blank_canvas_test() {
  // Nothing is drawn for an empty series, so the line and bar
  // renderers produce the same canvas for the same size and background.
  let line_png =
    render.line_png(
      [],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 12,
        height: 8,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          background: "#ffffff",
        ),
      ),
    )
  let bar_png =
    render.bar_png(
      [],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 12,
        height: 8,
        theme: sparklinekit.Theme(
          ..sparklinekit.default_theme,
          background: "#ffffff",
        ),
      ),
    )
  line_png |> should.equal(bar_png)
}

fn ihdr_size(png: BitArray) -> Result(#(Int, Int), Nil) {
  // Signature (8 bytes), IHDR length (4), "IHDR" (4), width (4), height (4).
  case png {
    <<_:bytes-size(16), width:size(32), height:size(32), _:bits>> ->
      Ok(#(width, height))
    _ -> Error(Nil)
  }
}

pub fn bar_png_for_single_value_still_returns_valid_signature_test() {
  let bytes =
    render.bar_png(
      [5.0],
      sparklinekit.BarOptions(
        ..sparklinekit.default_bar_options,
        width: 20,
        height: 20,
      ),
    )
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn line_png_size_grows_canvas_test() {
  let small =
    render.line_png(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 10,
        height: 10,
      ),
    )
  let large =
    render.line_png(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 100,
        height: 100,
      ),
    )
  case bit_array.byte_size(large) > bit_array.byte_size(small) {
    True -> Nil
    False -> should.fail()
  }
}

// `Some("none")` drew no area in SVG but a tinted one in PNG.
pub fn area_none_draws_no_area_in_png_test() {
  let options =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      theme: sparklinekit.Theme(..sparklinekit.ocean, area: option.Some("none")),
      area: sparklinekit.SolidArea,
    )
  let plain = sparklinekit.LineOptions(..options, area: sparklinekit.NoArea)
  assert render.line_png([1.0, 5.0, 3.0], options)
    == render.line_png([1.0, 5.0, 3.0], plain)
}

// Transparent red, so a pixel that a shape writes at zero coverage shows
// up as a changed background.
const see_through_theme =
  sparklinekit.Theme(
    foreground: "#112233",
    background: "#ff000000",
    area: option.None,
    negative: "#aa0000",
  )

fn pixel_list(png: BitArray) -> List(String) {
  output_snapshot_test.pixels(png)
  |> string.split("\n")
  |> list.flat_map(string.split(_, " "))
}

// Over a transparent background a partly covered pixel keeps the colour
// of the shape and only takes less alpha, and a pixel no shape covers
// keeps the background, even inside the box a shape is drawn in.
pub fn shapes_over_a_transparent_background_keep_their_colour_test() {
  let rounded_bar =
    render.bar_png(
      [5.0],
      sparklinekit.BarOptions(
        width: 8,
        height: 16,
        gap: 0.0,
        corner_radius: 4.0,
        theme: see_through_theme,
      ),
    )
  let line =
    sparklinekit.LineOptions(
      ..sparklinekit.default_line_options,
      width: 6,
      height: 6,
      theme: see_through_theme,
    )
  let diagonal = render.line_png([0.0, 1.0], line)
  let with_spot =
    render.line_png(
      [1.0, 3.0, 2.0],
      sparklinekit.LineOptions(..line, width: 12, height: 8, spot_radius: 2.0),
    )
  let other =
    [rounded_bar, diagonal, with_spot]
    |> list.flat_map(pixel_list)
    |> list.filter(fn(pixel) {
      pixel != "FF000000" && !string.starts_with(pixel, "112233")
    })
  assert other == []
  // The corner pixel lies wholly outside the rounded corner.
  assert list.first(pixel_list(rounded_bar)) == Ok("FF000000")
}

// The pixels where a rounded corner meets the straight top edge are
// covered by the exact share of the edge: two thirds of the row, 0xAA.
pub fn straight_edge_next_to_a_rounded_corner_test() {
  let rows =
    render.bar_png(
      [1.0, 3.0],
      sparklinekit.BarOptions(
        width: 8,
        height: 20,
        gap: 0.0,
        corner_radius: 1.0,
        theme: see_through_theme,
      ),
    )
    |> output_snapshot_test.pixels
    |> string.split("\n")
  assert list.drop(rows, 13) |> list.first
    == Ok(
      "11223376 112233AA 112233AA 11223376 112233FF 112233FF 112233FF 112233FF",
    )
}

// The dot at the end of the line keeps its rim on every side when its
// centre is not on a whole pixel: here the rim row below the centre.
pub fn spot_keeps_its_rim_off_the_pixel_grid_test() {
  let png =
    render.line_png(
      [0.0, 1.0, 0.7],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 8,
        height: 10,
        spot_radius: 2.0,
        theme: sparklinekit.Theme(..see_through_theme, foreground: "none"),
        spot_color: option.Some("#112233"),
      ),
    )
  let rows = output_snapshot_test.pixels(png) |> string.split("\n")
  assert list.drop(rows, 2) |> list.take(5)
    == [
      "FF000000 FF000000 FF000000 1122333B 112233BA 112233BA 1122333B FF000000",
      "FF000000 FF000000 FF000000 112233D7 112233FF 112233FF 112233D7 FF000000",
      "FF000000 FF000000 FF000000 112233F7 112233FF 112233FF 112233F7 FF000000",
      "FF000000 FF000000 FF000000 11223383 112233FF 112233FF 11223383 FF000000",
      "FF000000 FF000000 FF000000 FF000000 11223325 11223325 FF000000 FF000000",
    ]
}

// Below and above a rounded corner the left edge of a bar is covered by
// the exact share of the pixel, here 0.7 of each pixel of the first
// column, from the row where the corner ends to the row where the next
// one starts.
pub fn edge_between_two_rounded_corners_test() {
  let column =
    render.bar_png(
      [2.0, 1.0],
      sparklinekit.BarOptions(
        width: 20,
        height: 10,
        gap: 0.6,
        corner_radius: 1.0,
        theme: see_through_theme,
      ),
    )
    |> output_snapshot_test.pixels
    |> string.split("\n")
    |> list.map(fn(row) { string.split(row, " ") |> list.first })
  assert list.drop(column, 1) |> list.take(8) == list.repeat(Ok("112233B3"), 8)
}
