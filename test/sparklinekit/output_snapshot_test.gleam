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
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import render
import sparklinekit

const series = [3.0, 7.0, 1.0, 9.0, 4.0, 4.0, 8.0, 2.0]

const signed = [-4.0, 2.0, 5.0, -1.0, 0.0, 3.0, -6.0, 1.0]

fn plain_line() -> sparklinekit.LineOptions {
  sparklinekit.LineOptions(
    ..sparklinekit.default_line_options,
    width: 24,
    height: 8,
  )
}

fn styled_line() -> sparklinekit.LineOptions {
  sparklinekit.LineOptions(
    ..sparklinekit.default_line_options,
    width: 24,
    height: 8,
    theme: sparklinekit.ocean,
    stroke_width: 1.5,
    smoothing: 0.4,
    area: sparklinekit.GradientArea,
    spot_radius: 2.0,
  )
}

fn signed_line() -> sparklinekit.LineOptions {
  sparklinekit.LineOptions(
    ..sparklinekit.default_line_options,
    width: 24,
    height: 8,
    theme: sparklinekit.Theme(
      ..sparklinekit.default_theme,
      foreground: "#336699",
      background: "#fafafa",
    ),
    area: sparklinekit.GradientArea,
  )
}

// Big enough, with a thin line, for the area on both sides of zero to show:
// the SVG gradient and the PNG pixels fade towards zero from both ends.
fn mixed_line() -> sparklinekit.LineOptions {
  sparklinekit.LineOptions(
    ..sparklinekit.default_line_options,
    width: 48,
    height: 24,
    theme: sparklinekit.Theme(
      foreground: "#336699",
      background: "#ffffff",
      area: Some("#336699cc"),
      negative: "#000000",
    ),
    stroke_width: 1.0,
    area: sparklinekit.GradientArea,
  )
}

fn plain_bar() -> sparklinekit.BarOptions {
  sparklinekit.BarOptions(
    ..sparklinekit.default_bar_options,
    width: 24,
    height: 8,
    theme: sparklinekit.Theme(..sparklinekit.default_theme, negative: "#cc0000"),
  )
}

const signed_bar =
  sparklinekit.BarOptions(
    width: 24,
    height: 8,
    theme: sparklinekit.sunset,
    gap: 1.0,
    corner_radius: 1.0,
  )

pub fn line_svg_snapshots_test() -> Nil {
  render.line_svg(series, plain_line())
  |> birdie.snap(title: "line svg, plain")
  render.line_svg(series, styled_line())
  |> birdie.snap(title: "line svg, styled")
  render.line_svg(signed, signed_line())
  |> birdie.snap(title: "line svg, signed area")
  render.line_svg(signed, mixed_line())
  |> birdie.snap(title: "line svg, mixed gradient")
}

pub fn bar_svg_snapshots_test() -> Nil {
  render.bar_svg(series, plain_bar())
  |> birdie.snap(title: "bar svg, plain")
  render.bar_svg(signed, signed_bar)
  |> birdie.snap(title: "bar svg, signed rounded")
}

pub fn line_png_snapshots_test() -> Nil {
  render.line_png(series, plain_line())
  |> pixels
  |> birdie.snap(title: "line png, plain")
  render.line_png(series, styled_line())
  |> pixels
  |> birdie.snap(title: "line png, styled")
  render.line_png(signed, signed_line())
  |> pixels
  |> birdie.snap(title: "line png, signed area")
  render.line_png(signed, mixed_line())
  |> pixels
  |> birdie.snap(title: "line png, mixed gradient")
}

pub fn bar_png_snapshots_test() -> Nil {
  render.bar_png(series, plain_bar())
  |> pixels
  |> birdie.snap(title: "bar png, plain")
  render.bar_png(signed, signed_bar)
  |> pixels
  |> birdie.snap(title: "bar png, signed rounded")
}

// --- independent PNG reader ---------------------------------------------

pub fn pixels(png: BitArray) -> String {
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
