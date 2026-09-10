import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import simplifile
import sparklinekit

pub fn package_version_matches_gleam_toml_test() {
  // gleam.toml is what Hex publishes, so the constant must follow it.
  let assert Ok(toml) = simplifile.read("gleam.toml")
  Ok(sparklinekit.package_version())
  |> should.equal(toml_version(toml))
}

fn toml_version(toml: String) -> Result(String, Nil) {
  toml
  |> string.split("\n")
  |> list.find_map(fn(line) {
    case string.split_once(line, "version = \"") {
      Ok(#("", rest)) ->
        string.split_once(rest, "\"") |> result.map(fn(pair) { pair.0 })
      _ -> Error(Nil)
    }
  })
}
