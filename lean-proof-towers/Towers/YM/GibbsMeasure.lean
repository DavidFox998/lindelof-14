/-
================================================================
Towers / YM / GibbsMeasure (Batch 168.3 / TRI PARALLEL #8, file 3 of 3)

**Definition module.** Introduces the carrier of the Wilson Gibbs
measure on a finite lattice, parametric in the coupling `β`:

  * `haarMeasure` — a stand-in measure on `GaugeConfig d L`
    (honest pivot, see drift §1 below — **NOT** the genuine Haar
    measure on SU(2)).
  * `partitionFn d L β` — the partition function
    `Z := ∫ exp(−S_W[U]) dU`.
  * `gibbsMeasure d L β` — the Gibbs measure
    `dμ := Z⁻¹ exp(−S_W) dU`.

Builds on `Towers.YM.WilsonAction` (Batch 168.2).

## Honest scope (locked)
* This file declares **definitions only** plus one trivial
  sanity theorem (`partitionFn_zero_beta_eq_one : partitionFn d L
  0 = 1`) for brick registration. It says nothing about the
  existence of the genuine Wilson Gibbs measure, reflection
  positivity, OS axioms, the thermodynamic limit, or any Yang-
  Mills statement.
* Does **NOT** prove existence or RP. Surface #1 stays OPEN. The
  stand-in `haarMeasure := Measure.dirac (constant-1 config)`
  is a **placeholder** carrier so the partition-function and
  Gibbs-measure expressions typecheck on mathlib v4.12.0;
  replacing it with the genuine Haar product measure on `(SU(2))
  ^Links` is the next-wall task and will *intentionally* break
  `partitionFn_zero_beta_eq_one` (because Haar on `SU(2)` is
  normalised to total measure 1, but the Dirac mass at 1 also
  has total measure 1, so the brick might survive — see tripwire
  below).

## Drift from snippet
* (1) **Haar pivot.** Snippet wrote
  `haarMeasure := Measure.pi fun _ => HaarMeasure.haarMeasure G`,
  but
    - `HaarMeasure.haarMeasure` does **NOT** exist as a name in
      mathlib v4.12.0. The actual lemma is
      `MeasureTheory.Measure.haarMeasure : PositiveCompacts G →
      Measure G`, which requires `G` to carry the full Haar
      machinery: `[TopologicalGroup G]`, `[LocallyCompactSpace G]`,
      `[T2Space G]`, `[MeasurableSpace G]`, `[BorelSpace G]`, and
      a `PositiveCompacts G` witness.
    - `Matrix.SpecialUnitaryGroup (Fin 2) ℂ` is a `Submonoid`
      in v4.12.0 and does NOT carry any of these instances out
      of the box (the topological-group / locally-compact /
      BorelSpace coercion through the matrix carrier requires a
      separate API that v4.12.0 does not export).
    - `Measure.pi` itself requires `[Fintype (Link d L)]` plus
      `[∀ i, SigmaFinite (μ i)]`, which would chain back into
      the Haar instances above.

  Honest pivot: take `haarMeasure d L := Measure.dirac
  (constant-`1` configuration)`. This is the simplest manifestly-
  inhabited measure on `GaugeConfig d L`, gives a meaningful
  (though trivial) partition function, and lets the Gibbs-
  measure expression typecheck. The genuine SU(2) Haar product
  measure is a downstream task that depends on landing the full
  topological-group / locally-compact / BorelSpace instance
  chain on `Matrix.SpecialUnitaryGroup` — a separate batch.

  Snippet's `Mathlib.MeasureTheory.Measure.Haar` import is
  replaced with `Mathlib.MeasureTheory.Measure.Dirac` (the
  module that provides `Measure.dirac`).

* (2) `partitionFn` and `gibbsMeasure` snippets used `∫ U, …
  ∂haarMeasure d L` and `(partitionFn d L β)⁻¹ • …
  .withDensity …` — kept verbatim; with the Dirac pivot the
  integral collapses to a point evaluation, but the **shape**
  of the formula is the standard Wilson-Gibbs shape and is
  the right contract for downstream callers.

* (3) `gibbsMeasure` requires `[MeasurableSpace (GaugeConfig d
  L)]` to discharge `.withDensity`. `GaugeConfig d L` is a
  function type `Link d L → G`; mathlib v4.12.0 supplies a
  `MeasurableSpace` on function spaces through
  `MeasurableSpace.pi`, which needs `[MeasurableSpace G]` —
  which is `MeasurableSpace.const` (the discrete σ-algebra) by
  default through the `Subtype` instance chain when measurable-
  ness on `G`'s carrier is not asserted. Pivot: equip
  `GaugeConfig d L` with `MeasurableSpace ⊤` (the discrete
  σ-algebra) via a local `instance` declaration. This is honest
  (the Dirac measure is supported on a single point, so any
  σ-algebra suffices) and keeps the brick wiring clean.

## Tripwire (intentional)
Replacing the Dirac stand-in with a genuine SU(2) Haar product
measure will *re-prove* `partitionFn_zero_beta_eq_one` under the
real Haar normalisation. If a future batch lands a real Haar
product on `(SU(2))^Links` whose total mass is **not** `1`, the
brick will break — that is the tripwire that signals a non-
probability Haar measure has landed (or that the action does
not vanish at `β = 0`).

## Axiom footprint
Should depend only on the classical trio
`{propext, Classical.choice, Quot.sound}` — the brick reduces by
`β = 0` to `∫ exp 0 ∂(dirac _) = ∫ 1 ∂(dirac _) = 1` via
`integral_dirac` + `Real.exp_zero`.
================================================================
-/

import Towers.YM.WilsonAction
import Mathlib.MeasureTheory.Measure.Dirac
import Mathlib.MeasureTheory.Integral.Bochner

namespace TheoremaAureum.Towers.YM.LatticeGauge

open Real MeasureTheory

/-- Discrete σ-algebra on `G = SU(2)` — the simplest measurable
    structure that makes the Dirac stand-in below well-formed.
    Honest stand-in pending the real `BorelSpace G` instance. -/
instance : MeasurableSpace G := ⊤

/-- Discrete σ-algebra on `GaugeConfig d L` (function type into
    `G`); inherited from the `MeasurableSpace G` instance above
    via `MeasurableSpace.pi`. -/
instance (d L : ℕ) : MeasurableSpace (GaugeConfig d L) :=
  inferInstanceAs (MeasurableSpace (Link d L → G))

/-- **Haar stand-in** on `GaugeConfig d L`: the Dirac mass at the
    constant-`1` configuration. **NOT** the real SU(2) Haar
    product measure — that requires a topological-group /
    locally-compact / BorelSpace instance chain on
    `Matrix.SpecialUnitaryGroup` which mathlib v4.12.0 does not
    export. See drift §1. -/
noncomputable def haarMeasure (d L : ℕ) : Measure (GaugeConfig d L) :=
  Measure.dirac (fun _ => (1 : G))

/-- **Partition function** `Z[β] := ∫ exp(−S_W[U]) dU` of the
    Wilson Gibbs measure. With the Dirac stand-in for `haarMeasure`,
    this collapses to a point evaluation at the constant-`1`
    configuration. Shape preserved for downstream callers. -/
noncomputable def partitionFn (d L : ℕ) [NeZero L] (β : ℝ) : ℝ :=
  ∫ U, rexp (- wilsonAction (d := d) (L := L) β U) ∂haarMeasure d L

/-- **Wilson Gibbs measure** `dμ := Z⁻¹ exp(−S_W) dU`. Defined on
    `GaugeConfig d L` via `withDensity`, then rescaled by the
    partition-function inverse. With the Dirac stand-in this
    measure is the same Dirac mass (rescaled); shape preserved
    for downstream callers. -/
noncomputable def gibbsMeasure (d L : ℕ) [NeZero L] (β : ℝ) :
    Measure (GaugeConfig d L) :=
  (partitionFn d L β)⁻¹ •
    (haarMeasure d L).withDensity
      (fun U => ENNReal.ofReal (rexp (- wilsonAction (d := d) (L := L) β U)))

/-- **Brick (`partitionFn_zero_beta_eq_one`).** At zero coupling
    the partition function reduces to `1`: the integrand
    `exp(−0·…)` is the constant `1`, and the Dirac mass at the
    constant-`1` configuration has total measure `1`. Sanity
    brick — does NOT prove anything about real Yang-Mills. -/
theorem partitionFn_zero_beta_eq_one (d L : ℕ) [NeZero L] :
    partitionFn d L 0 = 1 := by
  unfold partitionFn haarMeasure
  simp [wilsonAction_zero_beta, Real.exp_zero, integral_dirac]

end TheoremaAureum.Towers.YM.LatticeGauge
