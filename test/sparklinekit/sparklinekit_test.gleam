import gleeunit/should
import sparklinekit

pub fn package_version_is_a_semver_string_test() {
  sparklinekit.package_version()
  |> should.equal("0.1.0")
}
