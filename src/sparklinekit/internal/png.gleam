//// Pure-Gleam PNG encoder. Emits 8-bit RGBA truecolor (PNG colour
//// type 6) with an uncompressed-DEFLATE payload — the same approach
//// `qrkit/render/png` uses, generalised from 1-bit indexed colour to
//// 32-bit-per-pixel RGBA so we can carry the configurable colour
//// schemes the sparkline renderers expose.
////
//// This module is intentionally private. Anything here may change
//// between minor versions.

import gleam/bit_array
import gleam/int
import gleam/list
import sparklinekit/internal/color.{type Rgba, Rgba}

const png_signature = [137, 80, 78, 71, 13, 10, 26, 10]

const crc32_polynomial = 0xEDB88320

const adler32_modulus = 65_521

/// Encode a 2-D pixel grid (row-major, each row of length `width`,
/// `height` rows) into PNG byte data.
///
/// Pixels are written verbatim; alpha is preserved. The caller owns
/// the background — if you want a transparent canvas you fill the
/// grid with `color.transparent`; if you want an opaque background
/// you blend it before calling here.
pub fn encode(
  pixels: List(List(Rgba)),
  width width: Int,
  height height: Int,
) -> BitArray {
  let actual_width = case width < 1 {
    True -> 1
    False -> width
  }
  let actual_height = case height < 1 {
    True -> 1
    False -> height
  }
  let scanlines = build_scanlines(pixels)
  let ihdr =
    list.append(
      u32_bytes(actual_width),
      list.append(u32_bytes(actual_height), [8, 6, 0, 0, 0]),
    )
  let idat = zlib_store(scanlines)

  list.append(
    png_signature,
    list.append(
      chunk(type_bytes: [73, 72, 68, 82], data_bytes: ihdr),
      list.append(
        chunk(type_bytes: [73, 68, 65, 84], data_bytes: idat),
        chunk(type_bytes: [73, 69, 78, 68], data_bytes: []),
      ),
    ),
  )
  |> byte_list_to_bit_array
}

fn build_scanlines(rows: List(List(Rgba))) -> List(Int) {
  do_build_scanlines(rows, [])
}

fn do_build_scanlines(rows: List(List(Rgba)), acc: List(Int)) -> List(Int) {
  case rows {
    [] -> list.reverse(acc)
    [row, ..rest] -> do_build_scanlines(rest, prepend_row(row, [0, ..acc]))
  }
}

fn prepend_row(row: List(Rgba), acc: List(Int)) -> List(Int) {
  case row {
    [] -> acc
    [Rgba(r, g, b, a), ..rest] -> prepend_row(rest, [a, b, g, r, ..acc])
  }
}

fn zlib_store(data: List(Int)) -> List(Int) {
  let checksum = adler32(data)
  list.append([120, 1], deflate_store_blocks(data))
  |> list.append(u32_bytes(checksum))
}

fn deflate_store_blocks(data: List(Int)) -> List(Int) {
  do_deflate_store_blocks(data, [])
}

fn do_deflate_store_blocks(data: List(Int), acc: List(Int)) -> List(Int) {
  case data {
    [] ->
      case acc {
        [] -> [1, 0, 0, 255, 255]
        _ -> list.reverse(acc)
      }
    _ -> {
      let #(chunk_bytes, rest) = take_bytes(data, 65_535, [])
      let final_flag = case rest {
        [] -> 1
        _ -> 0
      }
      let length = list.length(chunk_bytes)
      let complement = 65_535 - length
      let header = [
        final_flag,
        low_byte(length),
        high_byte(length),
        low_byte(complement),
        high_byte(complement),
      ]
      do_deflate_store_blocks(
        rest,
        prepend_reversed(list.append(header, chunk_bytes), acc),
      )
    }
  }
}

fn take_bytes(
  values: List(Int),
  count: Int,
  acc: List(Int),
) -> #(List(Int), List(Int)) {
  case values, count {
    rest, 0 -> #(list.reverse(acc), rest)
    [value, ..rest], _ -> take_bytes(rest, count - 1, [value, ..acc])
    [], _ -> #(list.reverse(acc), [])
  }
}

fn chunk(
  type_bytes type_bytes: List(Int),
  data_bytes data_bytes: List(Int),
) -> List(Int) {
  let crc = crc32(list.append(type_bytes, data_bytes))
  list.append(
    u32_bytes(list.length(data_bytes)),
    list.append(type_bytes, list.append(data_bytes, u32_bytes(crc))),
  )
}

fn crc32(bytes: List(Int)) -> Int {
  do_crc32(bytes, 0xFFFF_FFFF)
  |> int.bitwise_exclusive_or(0xFFFF_FFFF)
}

fn do_crc32(bytes: List(Int), crc: Int) -> Int {
  case bytes {
    [] -> crc
    [byte, ..rest] ->
      do_crc32(rest, crc32_byte(int.bitwise_exclusive_or(crc, byte), 8))
  }
}

fn crc32_byte(crc: Int, remaining: Int) -> Int {
  case remaining <= 0 {
    True -> crc
    False -> {
      let next = case int.bitwise_and(crc, 1) == 1 {
        True ->
          int.bitwise_exclusive_or(
            int.bitwise_shift_right(crc, 1),
            crc32_polynomial,
          )
        False -> int.bitwise_shift_right(crc, 1)
      }
      crc32_byte(next, remaining - 1)
    }
  }
}

fn adler32(bytes: List(Int)) -> Int {
  do_adler32(bytes, 1, 0)
}

fn do_adler32(bytes: List(Int), s1: Int, s2: Int) -> Int {
  case bytes {
    [] -> s2 * 65_536 + s1
    [byte, ..rest] -> {
      let next_s1 = { s1 + byte } % adler32_modulus
      let next_s2 = { s2 + next_s1 } % adler32_modulus
      do_adler32(rest, next_s1, next_s2)
    }
  }
}

fn byte_list_to_bit_array(bytes: List(Int)) -> BitArray {
  bytes
  |> list.map(fn(byte) { <<byte>> })
  |> bit_array.concat
}

fn prepend_reversed(values: List(a), acc: List(a)) -> List(a) {
  case values {
    [] -> acc
    [value, ..rest] -> prepend_reversed(rest, [value, ..acc])
  }
}

fn u32_bytes(value: Int) -> List(Int) {
  [
    int.bitwise_and(int.bitwise_shift_right(value, 24), 0xFF),
    int.bitwise_and(int.bitwise_shift_right(value, 16), 0xFF),
    int.bitwise_and(int.bitwise_shift_right(value, 8), 0xFF),
    int.bitwise_and(value, 0xFF),
  ]
}

fn low_byte(value: Int) -> Int {
  int.bitwise_and(value, 0xFF)
}

fn high_byte(value: Int) -> Int {
  int.bitwise_and(int.bitwise_shift_right(value, 8), 0xFF)
}
