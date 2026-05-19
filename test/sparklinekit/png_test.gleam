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
