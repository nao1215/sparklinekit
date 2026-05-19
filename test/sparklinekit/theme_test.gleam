import gleeunit/should
import sparklinekit/theme

pub fn ocean_theme_exposes_all_slots_test() {
  let t = theme.ocean()
  theme.foreground(t) |> should.equal("#1F6FEB")
  theme.background(t) |> should.equal("#F0F6FF")
}

pub fn forest_theme_uses_green_foreground_test() {
  theme.forest()
  |> theme.foreground
  |> should.equal("#22A06B")
}

pub fn sunset_theme_uses_orange_foreground_test() {
  theme.sunset()
  |> theme.foreground
  |> should.equal("#F76808")
}

pub fn mono_theme_uses_dark_grey_foreground_test() {
  theme.mono()
  |> theme.foreground
  |> should.equal("#1F2937")
}

pub fn neon_theme_uses_dark_background_test() {
  theme.neon()
  |> theme.background
  |> should.equal("#0F172A")
}

pub fn pastel_theme_is_low_saturation_test() {
  theme.pastel()
  |> theme.foreground
  |> should.equal("#A78BFA")
}

pub fn default_theme_falls_back_to_currentcolor_test() {
  theme.default()
  |> theme.foreground
  |> should.equal("currentColor")
}

pub fn default_background_disables_rectangle_test() {
  theme.default()
  |> theme.background
  |> should.equal("none")
}

pub fn negative_slot_is_distinct_from_foreground_test() {
  let t = theme.forest()
  let fg = theme.foreground(t)
  let neg = theme.negative(t)
  case fg == neg {
    True -> should.fail()
    False -> Nil
  }
}
