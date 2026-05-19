//// Unicode-block sparklines for terminal output.
////
//// ```gleam
//// import sparklinekit/unicode
////
//// pub fn shape() -> String {
////   unicode.render([1.0, 5.0, 22.0, 13.0, 5.0, 2.0, 7.0])
////   // -> "▁▂█▅▂▁▃"
//// }
//// ```
////
//// The eight block characters `▁▂▃▄▅▆▇█` partition the value range
//// into eight equal levels. Empty input returns `""`. A single value,
//// or a series where every value is the same, renders as a flat line
//// at the middle level (`▄`).

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import sparklinekit/internal/scale

const blocks: String = "▁▂▃▄▅▆▇█"

const block_count: Int = 8

const middle_index: Int = 3

/// Render `values` as a string of Unicode block characters.
///
/// - `[]` produces `""`.
/// - `[v]` produces a single middle-level block (`▄`).
/// - All-equal inputs produce a string of middle-level blocks.
/// - Otherwise each value is mapped into one of eight levels by
///   normalising against the observed minimum and maximum.
pub fn render(values: List(Float)) -> String {
  case values {
    [] -> ""
    [_] -> middle_block()
    _ -> {
      let #(lo, hi) = scale.min_max(values)
      case lo == hi {
        True ->
          values
          |> list.map(fn(_) { middle_block() })
          |> string.concat
        False ->
          values
          |> list.map(fn(value) { block_for(value, lo, hi) })
          |> string.concat
      }
    }
  }
}

fn middle_block() -> String {
  string.slice(blocks, middle_index, 1)
}

fn block_for(value: Float, lo: Float, hi: Float) -> String {
  let normalized = scale.unit(value, lo, hi)
  let raw =
    normalized *. int.to_float(block_count - 1)
    |> float.round
  let index = scale.clamp_int(raw, 0, block_count - 1)
  string.slice(blocks, index, 1)
}
