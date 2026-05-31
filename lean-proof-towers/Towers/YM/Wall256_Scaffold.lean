/-
Wall256_Scaffold — HONEST CONDITIONAL strong-coupling LATTICE reduction for the
SU(3) truncated polymer activity, packaged over its THREE open inputs.

This file does NOT prove a mass gap, a spectral gap, or convergence of any real
cluster expansion. It is a pure REDUCTION: it threads the three open inputs of the
strong-coupling lattice analysis (Osterwalder–Seiler 1978) through the genuine,
already-landed comparison-test summability and `ρ^d = exp(-Δ·d)` algebra of
`Wall256_Note`, to the requested abstract two-point decay shape. The entire
mathematical content lives in the three explicit HYPOTHESES; nothing here is
`axiom` and nothing is `by sorry`.

Honest scope (locked invariants)
--------------------------------
* LATTICE SU(3), strong-coupling reduction only. NOT the Clay continuum problem,
  NOT a continuum gap, NOT SU(2). YM stays `Status: Open`. Makes NO `μ > 0`,
  NO mass-gap, NO Surface-#1 claim; discharges NO `sorry`/surface.
* `corr`/`sep` are ABSTRACT (an arbitrary `corr sep : E → E → ℝ`); NO real
  Wilson-loop correlator or lattice metric is constructed.

The THREE open inputs (each a HYPOTHESIS, never proved here)
-----------------------------------------------------------
1. `hw1 : w1 < 1/7` — the SU(3) single-site Haar weight strict bound. Honestly,
   `w1` stands for `∫_{SU(3)} exp(-β·actL) d(haar)` (the `actL` of
   `Towers.YM.Transfer`); the strict bound `< 1/7` for `β > 0.85` is a genuine
   Haar/character-expansion estimate that mathlib v4.12.0 cannot evaluate. It is
   carried here as a real-number hypothesis on an abstract `w1`, NOT proved.
   (Note: the STRICT `< 1/7` — not `= 1/7` — is essential; equality gives
   `I = log 7`, at which `∑ₙ 7ⁿ·(1/7)ⁿ = ∑ₙ 1` diverges. The boundary `β = 0.85`
   is EXCLUDED.)
2. `hOS : w1 < 1/7 → TruncatedActivityBound a` — Osterwalder–Seiler 1978 Thm 2.1:
   the single-site smallness propagates, via the Ursell/cluster (truncated)
   expansion, to a per-size connected-polymer activity bound with rate
   `I > log 7`. The cluster expansion is ABSENT from mathlib v4.12.0, so this
   implication is a HYPOTHESIS.
3. `h_bridge : Summable (∑ₙ N n · a n) → (0 < ρ ∧ ρ < 1 ∧ geometric clustering)`
   — Brydges–Federbush: KP summability turns into geometric two-point clustering
   with spectral radius `ρ < 1`. Standard textbook cluster-expansion theory but
   ABSENT from mathlib v4.12.0; a HYPOTHESIS, not `by sorry`.

What IS machine-checked here
----------------------------
The reduction `(1) ⟹ TruncatedActivityBound ⟹ KP-summable ⟹ (3) ⟹ decay`,
reusing the GENUINE `Wall256Note.kp_summable_of_truncatedActivity` comparison test
(`∑ N n · a n ≤ ∑ N n · exp(-I)ⁿ`, `Summable.of_nonneg_of_le`) and the genuine
`Wall256.mass_gap_pos_of_spectral_gap` `ρ^d = exp(-Δ·d)` algebra.

Axiom footprint: classical trio `{propext, Classical.choice, Quot.sound}` only;
no `sorry`, no `axiom`.
-/

import Towers.YM.Wall256_Note

namespace TheoremaAureum.Towers.YM.Wall256Scaffold

open Real
open TheoremaAureum.Towers.YM
open TheoremaAureum.Towers.YM.Wall256Note

/-- **HONEST CONDITIONAL strong-coupling LATTICE reduction (SU(3)).** From the
THREE open inputs of the strong-coupling lattice analysis:
  * `hw1 : w1 < 1/7` — the open SU(3) single-site Haar weight strict bound;
  * `hOS : w1 < 1/7 → TruncatedActivityBound a` — the open Osterwalder–Seiler
    Ursell/cluster step (single-site smallness ⟹ truncated connected-polymer
    activity rate `I > log 7`); and
  * `h_bridge` — the open Brydges–Federbush KP-summability ⟹ geometric
    clustering step,
together with any polymer entropy count `N n ≤ 7ⁿ`, the abstract two-point decay
shape `∃ Δ > 0, ∀ x y, |corr x y| ≤ C·exp(-Δ·sep x y)` follows. Proves NO gap:
the entire content is the three open hypotheses; this only threads them through the
genuine `kp_summable_of_truncatedActivity` summability and the genuine
`ρ^d = exp(-Δ·d)` algebra of `Wall256.mass_gap_pos_of_spectral_gap`. `corr`/`sep`
are ABSTRACT. LATTICE only; NOT Clay; NOT a mass-gap claim; YM stays Open. -/
theorem strong_coupling_decay_of_open_inputs
    {E : Type*} (corr sep : E → E → ℝ) (C ρ w1 : ℝ)
    {N a : ℕ → ℝ} (hN0 : ∀ n, 0 ≤ N n) (hN : ∀ n, N n ≤ (7 : ℝ) ^ n)
    (hw1 : w1 < 1 / 7)
    (hOS : w1 < 1 / 7 → TruncatedActivityBound a)
    (h_bridge : Summable (fun n : ℕ => N n * a n) →
        0 < ρ ∧ ρ < 1 ∧ ∀ x y, |corr x y| ≤ C * ρ ^ (sep x y)) :
    ∃ Δ : ℝ, 0 < Δ ∧ ∀ x y, |corr x y| ≤ C * Real.exp (-Δ * sep x y) :=
  su2_gap_of_truncatedActivity corr sep C ρ hN0 hN (hOS hw1) h_bridge

end TheoremaAureum.Towers.YM.Wall256Scaffold
