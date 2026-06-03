/-
  BesselI_Z_Test.lean — mathlib-free, computable companion to the Bessel-I
  Z-protocol harness (experiments/bessel-z/).

  HONEST SCOPE
  ------------
  * `tool = true`  [T=1]: tool-assisted. We compute I_n(x) by its DETERMINISTIC
    convergent Float power series (the in-kernel "tool"):
        I_n(x) = Σ_{k≥0} (x/2)^(2k+n) / (k! · (k+n)!).
    Truncated at 64 terms; accurate to ~Float precision for the harness x-range.
  * `tool = false` [T=0]: "LLM generates directly". A Lean kernel cannot call an
    LLM. We do NOT fabricate a value — the real T=0 measurement lives in
    `BesselI_methodA_raw.json` / `BesselI_Z_MEASURE.csv` (genuine LLM calls).
    Here we honestly return `NaN` (0/0) and print a note.

  No theorem, no law, no claim is asserted. mathlib OFF (Lean core only);
  no `sorry` / `axiom` / `decide`-claim.
-/

namespace BesselZ

/-- Factorial as a `Float` (structural recursion). -/
def factF : Nat → Float
  | 0       => 1.0
  | (k + 1) => Float.ofNat (k + 1) * factF k

/-- `b ^ m` for `Float` base, `Nat` exponent (structural recursion). -/
def powF (b : Float) : Nat → Float
  | 0       => 1.0
  | (k + 1) => b * powF b k

/-- Truncated power series for I_n(x): Σ_{k=0}^{terms-1} (x/2)^(2k+n)/(k!(k+n)!). -/
def besselSeries (n : Nat) (x : Float) (terms : Nat) : Float :=
  let h := x / 2.0
  (List.range terms).foldl
    (fun acc k => acc + powF h (2 * k + n) / (factF k * factF (k + n))) 0.0

/-- The Bessel-I Z protocol on one (n, x).
    `tool = true`  ⟹ deterministic Float series for I_n(x).
    `tool = false` ⟹ LLM-direct (T=0): not evaluable in-kernel ⟹ NaN + note. -/
def besselI_Z (n : Nat) (x : Float) (tool : Bool) : IO Float := do
  if tool then
    pure (besselSeries n x 64)
  else
    IO.eprintln
      s!"[besselI_Z] n={n} x={x} tool=false (LLM-direct, T=0): not evaluable in-kernel; \
real measurement in experiments/bessel-z/BesselI_Z_MEASURE.csv. Returning NaN."
    pure (0.0 / 0.0)

-- Claude: run T=0  (LLM-direct) — returns NaN in-kernel (see CSV for real data)
#eval besselI_Z 1 2.0 false

-- Claude: run T=1  (tool-assisted) — deterministic series ≈ 1.5906368546
#eval besselI_Z 1 2.0 true

-- A few more tool-assisted sanity evals against mpmath truth:
--   I_0(1.0) ≈ 1.2660658778, I_2(3.0) ≈ 2.2452124329, I_5(10.0) ≈ 777.1882852572
#eval besselI_Z 0 1.0 true
#eval besselI_Z 2 3.0 true
#eval besselI_Z 5 10.0 true

end BesselZ
