import gleeunit/should
import sparklinekit/theme

pub fn ocean_theme_exposes_all_slots_test() {
  let t = theme.ocean()
  theme.foreground(t) |> should.equal("#2563EB")
  theme.background(t) |> should.equal("#FFFFFF")
}

pub fn forest_theme_uses_green_foreground_test() {
  theme.forest()
  |> theme.foreground
  |> should.equal("#10B981")
}

pub fn sunset_theme_uses_orange_foreground_test() {
  theme.sunset()
  |> theme.foreground
  |> should.equal("#F97316")
}

pub fn mono_theme_uses_dark_grey_foreground_test() {
  theme.mono()
  |> theme.foreground
  |> should.equal("#0F172A")
}

pub fn neon_theme_uses_dark_background_test() {
  theme.neon()
  |> theme.background
  |> should.equal("#020617")
}

pub fn pastel_theme_is_low_saturation_test() {
  theme.pastel()
  |> theme.foreground
  |> should.equal("#A78BFA")
}

pub fn crimson_theme_uses_red_foreground_test() {
  theme.crimson()
  |> theme.foreground
  |> should.equal("#DC2626")
}

pub fn slate_theme_uses_neutral_grey_foreground_test() {
  theme.slate()
  |> theme.foreground
  |> should.equal("#475569")
}

pub fn amber_theme_uses_golden_foreground_test() {
  theme.amber()
  |> theme.foreground
  |> should.equal("#F59E0B")
}

pub fn midnight_theme_uses_dark_background_test() {
  theme.midnight()
  |> theme.background
  |> should.equal("#020617")
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
