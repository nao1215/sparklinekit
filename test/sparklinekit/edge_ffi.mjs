// Floats that Gleam code on JavaScript can produce (`1.0e308 *. 10.0` is
// Infinity) but Gleam literals cannot write.

export function infinity() {
  return Infinity;
}

export function nan() {
  return NaN;
}
