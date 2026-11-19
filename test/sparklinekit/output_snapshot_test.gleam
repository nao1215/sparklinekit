//// Snapshot tests (birdie) of complete SVG and PNG output. The older
//// `qa/snapshot_test.gleam` pins only attributes; these pin every path
//// coordinate and every pixel, so a change to scaling, smoothing,
//// rasterisation, blending or colour parsing shows up as a reviewed
//// snapshot diff (`gleam run -m birdie`).
////
//// PNG output is decoded here by an independent reader: every chunk CRC-32
//// and the zlib Adler-32 are recomputed, the stored DEFLATE blocks are
//// unpacked and each scanline is printed as one row of `RRGGBBAA` pixels.

import birdie
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import sparklinekit/bar
import sparklinekit/line
import sparklinekit/theme

const series = [3.0, 7.0, 1.0, 9.0, 4.0, 4.0, 8.0, 2.0]

const signed = [-4.0, 2.0, 5.0, -1.0, 0.0, 3.0, -6.0, 1.0]

fn plain_line() -> line.Builder {
  line.new(series) |> line.with_size(24, 8)
}

fn styled_line() -> line.Builder {
  line.new(series)
  |> line.with_size(24, 8)
  |> line.with_theme(theme.ocean())
  |> line.with_smoothing(0.4)
  |> line.with_area_fill(True)
  |> line.with_gradient_area(True)
  |> line.with_spot(2.0)
  |> line.with_stroke_width(1.5)
}

fn signed_line() -> line.Builder {
  line.new(signed)
  |> line.with_size(24, 8)
  |> line.with_area_fill(True)
  |> line.with_color("#336699")
  |> line.with_background_color("#fafafa")
}

fn signed_bar() -> bar.Builder {
  bar.new(signed)
  |> bar.with_size(24, 8)
  |> bar.with_theme(theme.sunset())
  |> bar.with_bar_gap(1.0)
  |> bar.with_corner_radius(1.0)
}

fn plain_bar() -> bar.Builder {
  bar.new(series)
  |> bar.with_size(24, 8)
  |> bar.with_negative_color("#cc0000")
}

pub fn line_svg_snapshots_test() -> Nil {
  plain_line() |> line.to_svg |> birdie.snap(title: "line svg, plain")
  styled_line() |> line.to_svg |> birdie.snap(title: "line svg, styled")
  signed_line() |> line.to_svg |> birdie.snap(title: "line svg, signed area")
}

pub fn bar_svg_snapshots_test() -> Nil {
  plain_bar() |> bar.to_svg |> birdie.snap(title: "bar svg, plain")
  signed_bar() |> bar.to_svg |> birdie.snap(title: "bar svg, signed rounded")
}

pub fn line_png_snapshots_test() -> Nil {
  plain_line() |> line.to_png |> pixels |> birdie.snap(title: "line png, plain")
  styled_line()
  |> line.to_png
  |> pixels
  |> birdie.snap(title: "line png, styled")
  signed_line()
  |> line.to_png
  |> pixels
  |> birdie.snap(title: "line png, signed area")
}

pub fn bar_png_snapshots_test() -> Nil {
  plain_bar() |> bar.to_png |> pixels |> birdie.snap(title: "bar png, plain")
  signed_bar()
  |> bar.to_png
  |> pixels
  |> birdie.snap(title: "bar png, signed rounded")
}

// --- independent PNG reader ---------------------------------------------

fn pixels(png: BitArray) -> String {
  let assert <<0x89, "PNG":utf8, 0x0D, 0x0A, 0x1A, 0x0A, rest:bytes>> = png
  let chunks = read_chunks(rest, [])
  let assert [#("IHDR", ihdr), ..] = chunks
  let assert <<width:32, height:32, 8, 6, 0, 0, 0>> = ihdr
  let assert Ok(#("IEND", <<>>)) = list.last(chunks)
  let idat =
    chunks
    |> list.filter_map(fn(c) {
      case c.0 {
        "IDAT" -> Ok(c.1)
        _ -> Error(Nil)
      }
    })
    |> bit_array.concat
  let raw = inflate_stored(idat)
  bit_array.byte_size(raw) |> should.equal(height * { 1 + width * 4 })
  rows(raw, width, [])
  |> string.join("\n")
}

fn read_chunks(
  bytes: BitArray,
  acc: List(#(String, BitArray)),
) -> List(#(String, BitArray)) {
  case bytes {
    <<>> -> list.reverse(acc)
    _ -> {
      let assert <<len:32, kind:bytes-size(4), rest:bytes>> = bytes
      let assert <<data:bytes-size(len), crc:32, after:bytes>> = rest
      crc32(bit_array.append(kind, data)) |> should.equal(crc)
      let assert Ok(name) = bit_array.to_string(kind)
      read_chunks(after, [#(name, data), ..acc])
    }
  }
}

fn inflate_stored(zlib: BitArray) -> BitArray {
  let assert <<0x78, flags, body:bytes>> = zlib
  { 0x78 * 256 + flags } % 31 |> should.equal(0)
  let size = bit_array.byte_size(body)
  let assert Ok(blocks) = bit_array.slice(body, 0, size - 4)
  let assert Ok(<<adler:32>>) = bit_array.slice(body, size - 4, 4)
  let data = stored_blocks(blocks, [])
  adler32(data) |> should.equal(adler)
  data
}

fn stored_blocks(bytes: BitArray, acc: List(BitArray)) -> BitArray {
  let assert <<header, len:16-little, nlen:16-little, rest:bytes>> = bytes
  int.bitwise_exclusive_or(len, nlen) |> should.equal(0xFFFF)
  let assert <<data:bytes-size(len), after:bytes>> = rest
  let acc = [data, ..acc]
  case int.bitwise_and(header, 1) {
    1 -> {
      after |> should.equal(<<>>)
      bit_array.concat(list.reverse(acc))
    }
    _ -> stored_blocks(after, acc)
  }
}

fn rows(raw: BitArray, width: Int, acc: List(String)) -> List(String) {
  case raw {
    <<>> -> list.reverse(acc)
    _ -> {
      // Every scanline uses filter type 0 (None).
      let assert <<0, rest:bytes>> = raw
      let assert <<row:bytes-size(width * 4), after:bytes>> = rest
      rows(after, width, [row_text(row, []), ..acc])
    }
  }
}

fn row_text(row: BitArray, acc: List(String)) -> String {
  case row {
    <<pixel:bytes-size(4), rest:bytes>> ->
      row_text(rest, [bit_array.base16_encode(pixel), ..acc])
    _ -> acc |> list.reverse |> string.join(" ")
  }
}

fn crc32(bytes: BitArray) -> Int {
  int.bitwise_exclusive_or(crc_loop(bytes, 0xFFFFFFFF), 0xFFFFFFFF)
}

fn crc_loop(bytes: BitArray, crc: Int) -> Int {
  case bytes {
    <<b, rest:bytes>> ->
      crc_loop(rest, crc_bits(int.bitwise_exclusive_or(crc, b), 8))
    _ -> crc
  }
}

fn crc_bits(crc: Int, n: Int) -> Int {
  case n {
    0 -> crc
    _ ->
      case int.bitwise_and(crc, 1) {
        1 ->
          crc_bits(
            int.bitwise_exclusive_or(
              int.bitwise_shift_right(crc, 1),
              0xEDB88320,
            ),
            n - 1,
          )
        _ -> crc_bits(int.bitwise_shift_right(crc, 1), n - 1)
      }
  }
}

fn adler32(bytes: BitArray) -> Int {
  adler_loop(bytes, 1, 0)
}

fn adler_loop(bytes: BitArray, a: Int, b: Int) -> Int {
  case bytes {
    <<x, rest:bytes>> -> {
      let a = { a + x } % 65_521
      adler_loop(rest, a, { b + a } % 65_521)
    }
    _ -> b * 65_536 + a
  }
}
