/-
================================================================
Towers / YM / WilsonAction (Batch 168.2 / TRI PARALLEL #8, file 2 of 3)

**Definition module.** Introduces the SU(2) Wilson plaquette
action `S_W` on a finite periodic lattice, parametric in the
coupling `β`. Builds on the carrier types from
`Towers.YM.LatticeGauge` (Batch 168.1).

## Honest scope (locked)
* This file declares the **plaquette product** and the **Wilson
  action functional** plus one trivial sanity theorem
  (`wilsonAction_zero_beta : wilsonAction d L 0 U = 0`) for brick
  registration. It says nothing about gauge invariance,
  Osterwalder–Schrader axioms, reflection positivity, mass gap, or
  any continuum limit.
* Does **NOT** prove any Yang-Mills statement. Surface #1 stays
  OPEN.
* SU(2) plaquettes here are *independent* of the SU(3) Wilson
  infrastructure in `Towers.YM.Wilson` / `Towers.YM.PlaquetteAction`.

## Drift from snippet
* (1) Snippet defined `plaquette … : G` returning the SU(2)
  subtype, but on mathlib v4.12.0 `G = Matrix.SpecialUnitaryGroup
  (Fin 2) ℂ` is a `Submonoid (Matrix.unitaryGroup (Fin 2) ℂ)` —
  it has multiplication but **NO `Inv` / `Group` instance**, so
  `U⁻¹` does not typecheck on `G` directly. Honest pivot (same
  pattern as existing `Towers.YM.Wilson.plaquetteMat` and
  `Towers.YM.PlaquetteAction.wilsonPlaquette`): compute the
  plaquette at the **matrix level** via the `.1` coercion
  `G → Matrix (Fin 2) (Fin 2) ℂ`, and use `star` instead of `⁻¹`
  (for unitary `U`, `U⁻¹ = star U`). Plaquette therefore returns
  `Matrix (Fin 2) (Fin 2) ℂ`, not `G`.
* (2) Snippet's `x + Pi.single μ 1` requires `(1 : Fin L)`, which
  in turn requires `[NeZero L]` (otherwise `Fin 0` is empty and
  has no `1`). Honest pivot: add `[NeZero L]` typeclass argument
  to `plaquette` and `wilsonAction`. This matches the existing
  `Towers.YM.PlaquetteAction.latticeShift` pattern, which carries
  `[NeZero n]` for the same reason.
* (3) Snippet used `(plaquette … h).trace.re`, but post-pivot the
  plaquette is already a `Matrix`, so `.trace.re` becomes
  `Matrix.trace (plaquette … h) |>.re`. Same value, different
  parse path.
* (4) The `if h : μ ≠ ν then … else 0` term uses dependent-if;
  this requires the proposition `μ ≠ ν` to be `Decidable`, which
  `Fin d` has via `instDecidableEq`. No extra import needed.

## Axiom footprint
Should depend only on the classical trio
`{propext, Classical.choice, Quot.sound}` — the brick reduces by
`β = 0` to `0 * ∑ … = 0`, discharged by `simp` / `mul_zero`.
================================================================
-/

import Towers.YM.LatticeGauge
import Mathlib.Analysis.Complex.Basic
import Mathlib.LinearAlgebra.Matrix.Trace
import Mathlib.Data.Fintype.BigOperators

namespace TheoremaAureum.Towers.YM.LatticeGauge

open Matrix
open scoped BigOperators

/-- The periodic unit-vector shift `x ↦ x + ê_μ` on a
    `Lattice d L` site. Uses `Pi.single` to add `1 : Fin L` to
    the `μ`-th coordinate (requires `[NeZero L]` so `1 : Fin L`
    exists and `Fin L`'s `+` is modular-mod-`L`). -/
def latticeShift {d L : ℕ} [NeZero L]
    (x : Lattice d L) (μ : Fin d) : Lattice d L :=
  x + Pi.single μ 1

/-- **Plaquette matrix** at site `x` in plane `(μ, ν)`:

      `P_{μν}(x) := U_μ(x) · U_ν(x+ê_μ) · star U_μ(x+ê_ν)
                                       · star U_ν(x)`.

    Returns a `Matrix (Fin 2) (Fin 2) ℂ` (not a re-wrapped `G`).
    `star` plays the role of `⁻¹` at the matrix level — for any
    unitary `U`, `star U = U⁻¹`. -/
noncomputable def plaquette {d L : ℕ} [NeZero L]
    (U : GaugeConfig d L) (x : Lattice d L) (μ ν : Fin d) :
    Matrix (Fin 2) (Fin 2) ℂ :=
  (U (x, μ)).1 * (U (latticeShift x μ, ν)).1
    * star (U (latticeShift x ν, μ)).1 * star (U (x, ν)).1

/-- **Wilson plaquette action** at coupling `β`:

      `S_W[U] := β · ∑_{x, μ, ν, μ≠ν}
                      (1 − (1/2) · Re tr P_{μν}(x))`.

    Ordered-pair sum over `(μ, ν)` with `μ ≠ ν` (the dependent
    `if h : μ ≠ ν` provides the inequality witness to the inner
    expression). The `1/2 = 1/|G|` prefactor matches the standard
    SU(2) Wilson convention. -/
noncomputable def wilsonAction {d L : ℕ} [NeZero L]
    (β : ℝ) (U : GaugeConfig d L) : ℝ :=
  β * ∑ x : Lattice d L, ∑ μ : Fin d, ∑ ν : Fin d,
    if h : μ ≠ ν then
      1 - (1/2) * (Matrix.trace (plaquette U x μ ν)).re
    else 0

/-- **Brick (`wilsonAction_zero_beta`).** At zero coupling, the
    Wilson action vanishes identically (the overall `β` factor
    multiplies the inner sum to zero, regardless of `U`). Sanity
    brick — does NOT prove anything about real Yang-Mills
    dynamics. -/
theorem wilsonAction_zero_beta {d L : ℕ} [NeZero L]
    (U : GaugeConfig d L) : wilsonAction (d := d) (L := L) 0 U = 0 := by
  unfold wilsonAction
  simp

end TheoremaAureum.Towers.YM.LatticeGauge
