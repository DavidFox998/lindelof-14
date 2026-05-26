/-
================================================================
Towers / YM / Spectrum  (Batch 8 Track 3)

**From "`YMHamiltonian` non-zero" to "`YMHamiltonian` has a
gap-above-vacuum schema".** Five bricks named exactly per the
Batch 8 directive:

  1. `YMHamiltonian_image_nonzero` — `∃ A, YMHamiltonian A ≠ 0`.
     Witness `A = (fun _ => 1)`, closes via the existing Task #55
     `YMHamiltonian_one_eq_twelve` and `(12 : ℝ) ≠ 0`.
  2. `YMHamiltonian_image_bounded` — `∃ B, ∀ A, |YMHamiltonian A|
     ≤ B`. Witness `B = 12`, closes via the existing Task #61
     `YMHamiltonian_abs_le_twelve`.
  3. `YMHamiltonian_image_has_inf` —
     `BddBelow (Set.range YMHamiltonian) ∧
      (Set.range YMHamiltonian).Nonempty`. Both via Brick 1 / 2.
     Lets downstream callers name `sInf (Set.range YMHamiltonian)`
     without `Classical.choice` on an empty / unbounded set.
  4. `YMHamiltonian_vacuum_def` — pins the "vacuum connection"
     `vacuum_connection := fun _ : Fin 4 => (1 : SU(3))` to the
     numerical value `YMHamiltonian vacuum_connection = 12`. The
     vacuum is the only `SU3Connection` for which the schema
     gives a concrete numerical value.
  5. `YMHamiltonian_gap_above_vacuum_schema` — positivity
     projection of the new `MassGapV2 Δ` predicate, which
     measures the gap *above the vacuum value*
     (`|YMHamiltonian A − YMHamiltonian vacuum_connection|`)
     rather than the absolute value (the existing Task #68
     `MassGap` measures `|YMHamiltonian A|`, which is wrong
     physics — the gap is measured from the vacuum). The brick
     proves `MassGapV2 Δ → 0 < Δ`.

Plus supporting:

  * `vacuum_connection : SU3Connection` — the all-ones connection
    `fun _ : Fin 4 => (1 : Matrix.specialUnitaryGroup (Fin 3) ℂ)`.
    Honest stand-in for the OS-reconstructed YM vacuum; the
    smallest-trace-stand-in vacuum the current placeholder schema
    admits.
  * `MassGapV2 Δ : Prop` — gap-above-vacuum predicate
    `0 < Δ ∧ ∀ A ≠ vacuum_connection, Δ ≤ |YMHamiltonian A −
    YMHamiltonian vacuum_connection|`. Successor to the Task #68
    `MassGap` predicate.

### Honest scope

What this file claims:

  * Genuine `∃` / `∀` statements about the image of the Task #51 /
    Task #55 / Task #61 placeholder `YMHamiltonian : SU3Connection
    → ℝ`. They are real facts about a real `ℝ`-valued function on
    `Fin 4 → Matrix.specialUnitaryGroup (Fin 3) ℂ`.
  * `vacuum_connection` is the literal all-ones SU(3) connection.
  * `YMHamiltonian_vacuum_def` is the literal identity
    `YMHamiltonian (fun _ => 1) = 12`, packaged under a named
    "vacuum" handle.
  * `YMHamiltonian_gap_above_vacuum_schema` is the positivity
    projection of `MassGapV2`. The unconditional claim
    `∃ Δ > 0, MassGapV2 Δ` is **NOT** proved in this file (and
    would require either a non-trivial lower bound on
    `|YMHamiltonian A − 12|` away from the vacuum or a refined
    `YMHamiltonian` def — neither is in scope for this batch).

What this file does NOT claim:

  * Existence of a Yang-Mills mass gap;
  * Any spectral theorem on the YM physical-state Hilbert space;
  * `vacuum_connection` is the physical YM vacuum (it isn't — the
    OS-reconstructed physical vacuum is in a different Hilbert
    space entirely);
  * Any Clay-style result.

YM tower status unchanged: **Open** (`docs/ROADMAP.md` § 2).

### Zero shared imports

This file imports only `Towers.YM.MassGap` (which carries the
existing `SU3Connection`, `YMHamiltonian`, `YMHamiltonian_one_eq_twelve`,
`YMHamiltonian_abs_le_twelve` foundation). It does NOT import
`Towers.Spectral.OperatorV2` or `Towers.NS.EnergyV2` — the other
two Batch 8 tracks are independent and run in parallel.
================================================================
-/

import Towers.YM.MassGap

namespace TheoremaAureum
namespace Towers
namespace YM
namespace Spectrum

open TheoremaAureum.Towers.YM

/-! ### Supporting defs -/

/-- **`vacuum_connection`** — the all-ones SU(3) connection
`fun _ : Fin 4 => (1 : Matrix.specialUnitaryGroup (Fin 3) ℂ)`.
Honest stand-in for the OS-reconstructed YM vacuum; the only
`SU3Connection` on which the placeholder schema gives a concrete
numerical value (`= 12` via Task #55's
`YMHamiltonian_one_eq_twelve`). -/
def vacuum_connection : SU3Connection :=
  fun _ : Fin 4 => (1 : Matrix.specialUnitaryGroup (Fin 3) ℂ)

/-- **`MassGapV2 Δ`** — gap-above-vacuum predicate. Successor to
the Task #68 `MassGap`, which measured `|YMHamiltonian A|`
(wrong physics — the gap is measured from the vacuum). Here the
gap is the absolute difference from the vacuum value:

  `0 < Δ ∧ ∀ A ≠ vacuum_connection,
     Δ ≤ |YMHamiltonian A − YMHamiltonian vacuum_connection|`. -/
def MassGapV2 (Δ : ℝ) : Prop :=
  0 < Δ ∧ ∀ A : SU3Connection, A ≠ vacuum_connection →
    Δ ≤ |YMHamiltonian A - YMHamiltonian vacuum_connection|

/-! ### Bricks (5) — exact names per Batch 8 directive -/

/-- **Brick 1 (`YMHamiltonian_image_nonzero`).**
`∃ A, YMHamiltonian A ≠ 0`. The all-ones SU(3) connection
evaluates to `12` via Task #55's `YMHamiltonian_one_eq_twelve`,
and `(12 : ℝ) ≠ 0`. First time the schema is shown to have
non-zero image. -/
theorem YMHamiltonian_image_nonzero :
    ∃ A : SU3Connection, YMHamiltonian A ≠ 0 := by
  refine ⟨fun _ : Fin 4 => (1 : Matrix.specialUnitaryGroup (Fin 3) ℂ), ?_⟩
  rw [YMHamiltonian_one_eq_twelve]
  norm_num

/-- **Brick 2 (`YMHamiltonian_image_bounded`).**
`∃ B, ∀ A, |YMHamiltonian A| ≤ B`. Promotes the per-`A` Task #61
bound `YMHamiltonian_abs_le_twelve` to an `∃` over `A`, naming
`B = 12` as a uniform witness. The image of `YMHamiltonian` is
a bounded subset of `[-12, 12]`. -/
theorem YMHamiltonian_image_bounded :
    ∃ B : ℝ, ∀ A : SU3Connection, |YMHamiltonian A| ≤ B :=
  ⟨12, YMHamiltonian_abs_le_twelve⟩

/-- **Brick 3 (`YMHamiltonian_image_has_inf`).**
`BddBelow (Set.range YMHamiltonian) ∧
 (Set.range YMHamiltonian).Nonempty`. The lower bound is `-12`
via `abs_le.mp` on `YMHamiltonian_abs_le_twelve`; the non-empty
witness is the all-ones connection at value `12`. Lets downstream
callers name `sInf (Set.range YMHamiltonian)` without
`Classical.choice` on an empty / unbounded set. -/
theorem YMHamiltonian_image_has_inf :
    BddBelow (Set.range YMHamiltonian) ∧
      (Set.range YMHamiltonian).Nonempty := by
  refine ⟨⟨-12, ?_⟩, ?_⟩
  · rintro y ⟨A, rfl⟩
    have h := YMHamiltonian_abs_le_twelve A
    exact (abs_le.mp h).1
  · refine ⟨12, ?_⟩
    exact ⟨fun _ : Fin 4 => (1 : Matrix.specialUnitaryGroup (Fin 3) ℂ),
           YMHamiltonian_one_eq_twelve⟩

/-- **Brick 4 (`YMHamiltonian_vacuum_def`).** Pins the numerical
value of the placeholder Hamiltonian at the named vacuum:
`YMHamiltonian vacuum_connection = 12`. Closes by direct
rewrite against Task #55's `YMHamiltonian_one_eq_twelve` — the
def of `vacuum_connection` is `fun _ => 1`, so the two sides are
literally the same expression.

Honest scope: `vacuum_connection` is NOT the OS-reconstructed YM
vacuum (a different Hilbert space). It is the smallest-trace
SU(3) stand-in vacuum the current placeholder schema admits. -/
theorem YMHamiltonian_vacuum_def :
    YMHamiltonian vacuum_connection = 12 :=
  YMHamiltonian_one_eq_twelve

/-- **Brick 5 (`YMHamiltonian_gap_above_vacuum_schema`).**
Positivity projection of the new `MassGapV2` predicate:
`MassGapV2 Δ → 0 < Δ`. Together with `MassGapV2`'s definition,
this brick pins the *shape* of "gap above the vacuum" without
claiming any particular `Δ` has a witness.

Honest scope: this is a `And.left` projection — the unconditional
claim `∃ Δ > 0, MassGapV2 Δ` is **NOT** proved in this file and
would require either a non-trivial lower bound on
`|YMHamiltonian A − 12|` away from the vacuum, or a refined
`YMHamiltonian` def. Neither is in scope for this batch. YM
tower status unchanged: **Open**. -/
theorem YMHamiltonian_gap_above_vacuum_schema
    {Δ : ℝ} (h : MassGapV2 Δ) : 0 < Δ := h.1

end Spectrum
end YM
end Towers
end TheoremaAureum
