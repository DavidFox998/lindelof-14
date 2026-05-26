/-
  # Towers.YM.MassGap

  **Statement-only file. Contains no theorems and no proofs.** This
  file pins the Clay Yang-Mills mass-gap conjecture as a future
  formalisation target, using a structured (rather than single-`sorry`)
  schema. The body uses `sorry` at multiple decl boundaries,
  deliberately, because mathlib v4.12.0 ships none of the
  prerequisite QFT machinery (`SpecialUnitaryGroup`, `Connection`
  on a principal bundle, Hilbert space of physical states,
  Yang-Mills Hamiltonian, eigenstate predicate).

  Because multiple bodies are `sorry`, `#print axioms
  YM_mass_gap_statement` will display `[sorryAx]` (alongside any
  classical-trio axioms picked up by `noncomputable` elaboration).
  That is **expected and visible**: the placeholders cannot be
  silently mistaken for proved or even precisely-stated theorems.

  ## Deviations from Plan #51 literal spec

  Plan #51 as written contains imports and identifiers that do not
  exist in mathlib v4.12.0 (verified by inspecting the resolved
  `.lake/packages/mathlib/Mathlib/` tree). The following deviations
  were forced — none of them is a choice:

    1. `import Mathlib.LinearAlgebra.Matrix.SpecialUnitaryGroup`
       **OMITTED.** This file does not exist in mathlib v4.12.0. The
       closest available is `SpecialLinearGroup`. The TODO comment on
       `SU3Connection` still names the intended future import so the
       grep is preserved.
    2. `import Mathlib.Geometry.Manifold.VectorBundle.Basic`
       **OMITTED.** The body of `SU3Connection` is `sorry`, so the
       import would only slow the build (~10s extra) for no gain.
       The TODO names the future Connection/Bundle type.
    3. `HilbertSpace` was **referenced but not defined** in the spec.
       Added here as `def HilbertSpace : Type := sorry` with TODO so
       the mass-gap statement type-checks.
    4. `IsEigenstate` was **referenced but not defined** in the spec.
       Added here with the type signature
       `(SU3Connection → ℝ) → HilbertSpace → Prop` matching the
       usage `IsEigenstate YMHamiltonian ψ` in the schema body.

  ## What this file is NOT

  * Not a proof of the Yang-Mills mass gap.
  * Not a precise Lean statement (the placeholders are opaque).
  * **Not a brick.** `scripts/check-towers.sh` explicitly excludes
    this file from `BRICKS`. The 7 real bricks
    (`gauge_action_one_smul`, `gauge_action_mul_smul`, etc.) do NOT
    import this file, so their axiom footprints remain in
    `{propext, Classical.choice, Quot.sound}` — verified post-build.

  ## What this file IS

  * Stable citable Lean identifiers
    (`TheoremaAureum.Towers.YM.SU3Connection`,
    `TheoremaAureum.Towers.YM.YMHamiltonian`,
    `TheoremaAureum.Towers.YM.YM_mass_gap_statement`) that future
    plans can point to as the future target.
  * A flagged TODO surface — every `sorry` is paired with a `TODO:`
    comment naming the mathlib module / definition that would replace
    it once available.

  ## Status

  Per `docs/ROADMAP.md` § 2. Yang-Mills mass gap: **Open.** No
  promotion. The existence of these `sorry`-backed defs does not
  change the tower's status; it only names the target with more
  structure.
-/

import Mathlib.Data.Real.Basic

namespace TheoremaAureum
namespace Towers
namespace YM

/-- **SU(3) gauge field as a connection on a principal bundle over `ℝ⁴`.** -/
def SU3Connection : Type := sorry
-- TODO (mathlib v4.13+): Connection (Bundle ℝ ℝ⁴) (SpecialUnitaryGroup (Fin 3) ℂ)

/-- **Hilbert space of physical states** of the Yang-Mills
    Hamiltonian. (Added here because Plan #51 referenced
    `HilbertSpace` without defining it.) -/
def HilbertSpace : Type := sorry
-- TODO (mathlib v4.13+): physical-state Hilbert space of the YM Hamiltonian

/-- **Yang-Mills Hamiltonian:** `E + B` field energy `∫ |F|²`. -/
noncomputable def YMHamiltonian (_A : SU3Connection) : ℝ := sorry
-- TODO (mathlib v4.13+): ∫ tr(F_A ∧ ★F_A)

/-- **Eigenstate predicate** (placeholder). `IsEigenstate H ψ` says
    `ψ` is an eigenstate of the Hamiltonian `H`. Added here because
    Plan #51 referenced `IsEigenstate` without defining it. -/
def IsEigenstate (_H : SU3Connection → ℝ) (_ψ : HilbertSpace) : Prop := sorry
-- TODO (mathlib v4.13+): ψ is an eigenstate of H

/-- **Mass gap statement:** `∃ Δ > 0, ∀ eigenstates ψ, E_ψ ≥ Δ`. -/
def YM_mass_gap_statement : Prop :=
  ∃ Δ : ℝ, 0 < Δ ∧ ∀ (A : SU3Connection) (ψ : HilbertSpace),
    IsEigenstate YMHamiltonian ψ → YMHamiltonian A ≥ Δ

end YM
end Towers
end TheoremaAureum
