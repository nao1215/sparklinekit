import gleam/bit_array
import gleeunit/should
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme

const png_signature: BitArray = <<137, 80, 78, 71, 13, 10, 26, 10>>

pub fn line_png_starts_with_signature_test() {
  let bytes =
    line.new([1.0, 5.0, 3.0, 8.0, 4.0])
    |> line.with_theme(theme.ocean())
    |> line.to_png
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn bar_png_starts_with_signature_test() {
  let bytes =
    bar.new([3.0, 7.0, 2.0, 9.0])
    |> bar.with_theme(theme.sunset())
    |> bar.to_png
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn line_png_for_empty_input_still_returns_valid_signature_test() {
  let bytes =
    line.new([])
    |> line.with_size(40, 20)
    |> line.to_png
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn empty_input_png_has_the_configured_size_test() {
  let line_png =
    line.new([])
    |> line.with_size(40, 20)
    |> line.to_png
  let bar_png =
    bar.new([])
    |> bar.with_size(40, 20)
    |> bar.to_png
  ihdr_size(line_png) |> should.equal(Ok(#(40, 20)))
  ihdr_size(bar_png) |> should.equal(Ok(#(40, 20)))
}

pub fn empty_input_png_is_a_blank_canvas_test() {
  // Nothing is drawn for an empty series, so the line and bar
  // renderers produce the same canvas for the same size and background.
  let line_png =
    line.new([])
    |> line.with_size(12, 8)
    |> line.with_background_color("#ffffff")
    |> line.to_png
  let bar_png =
    bar.new([])
    |> bar.with_size(12, 8)
    |> bar.with_background_color("#ffffff")
    |> bar.to_png
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
    bar.new([5.0])
    |> bar.with_size(20, 20)
    |> bar.to_png
  case bit_array.slice(bytes, 0, 8) {
    Ok(head) -> head |> should.equal(png_signature)
    Error(_) -> should.fail()
  }
}

pub fn line_png_size_grows_with_canvas_test() {
  let small =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(10, 10)
    |> line.to_png
  let large =
    line.new([1.0, 2.0, 3.0])
    |> line.with_size(100, 100)
    |> line.to_png
  case bit_array.byte_size(large) > bit_array.byte_size(small) {
    True -> Nil
    False -> should.fail()
  }
}

pub fn bar_png_with_int_input_matches_float_input_test() {
  let int_bytes =
    bar.new_ints([1, 2, 3])
    |> bar.with_size(20, 20)
    |> bar.to_png
  let float_bytes =
    bar.new([1.0, 2.0, 3.0])
    |> bar.with_size(20, 20)
    |> bar.to_png
  int_bytes |> should.equal(float_bytes)
}
