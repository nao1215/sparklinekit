import gleam/bit_array
import gleeunit/should
import sparklinekit

const png_signature: BitArray = <<137, 80, 78, 71, 13, 10, 26, 10>>

pub fn line_png_starts_signature_test() {
  let bytes =
    sparklinekit.line_png(
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
    sparklinekit.bar_png(
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
    sparklinekit.line_png(
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
    sparklinekit.line_png(
      [],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 40,
        height: 20,
      ),
    )
  let bar_png =
    sparklinekit.bar_png(
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
    sparklinekit.line_png(
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
    sparklinekit.bar_png(
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
    sparklinekit.bar_png(
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
    sparklinekit.line_png(
      [1.0, 2.0, 3.0],
      sparklinekit.LineOptions(
        ..sparklinekit.default_line_options,
        width: 10,
        height: 10,
      ),
    )
  let large =
    sparklinekit.line_png(
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
