/-
================================================================
Towers / YM / HeatTraceBound  (Task #156 — file 3a of 6,
antidiagonal envelope)

ANTIDIAGONAL ENVELOPE ONLY. Single brick:

  heat_trace_envelope : ∀ t > 0,
    K t ≤ ∑' k : ℕ, ((k : ℝ) + 1) * (8 * ((k : ℝ) + 1) ^ 3) ^ 2
                     * Real.exp (-(3/4) * t * (k : ℝ) ^ 2)

where K(t) := ∑' (m n : ℕ),
  (dim_SU3 m n : ℝ)² · Real.exp (-t · Casimir_SU3_explicit (m, n))
is the iterated Peter–Weyl spectral sum for the SU(3) heat kernel
at the identity. (The genuine identity
`K_t(1) = ∑_λ dim(λ)² · exp(-t · C₂(λ))` is classical analysis on
compact Lie groups; this is its formal stand-in.)

Inputs used (from sibling bricks):
  • `Towers.YM.WeylDim.dim_cubic_bound`
      `dim_SU3 m n ≤ 8 · (m + n + 1) ³`
  • `Towers.YM.Casimir.Casimir_SU3_explicit_real_ge_quadratic`
      `¾ · (m + n)² + 3 · (m + n) ≤ C₂(m, n)`
  • `Towers.YM.PeterWeyl.PeterWeyl_Summable_SU3` (β := t)
      summability of the LHS summand on ℕ × ℕ

Honest scope (locked).
  - NOT the Weyl-law headline `K(t) ≤ C · t^{-4}`. That closure
    needs the Gaussian moment integral `∫₀^∞ x⁷ · exp(-a · x²) dx
       = 3 / a⁴` (gamma-function change-of-variables), which mathlib
    v4.12.0 does not ship as a one-liner. That is the future file 3b.
  - Does NOT discharge Varadhan, the per-plaquette activity bound,
    KP, the cluster expansion, the area law, or any mass-gap statement.
  - YM tower stays Status: Open (docs/ROADMAP.md § 2).
  - Surface #2 stays OPEN; `kotecky_preiss_criterion` remains a
    `sorry` in `Towers/Attempts/ClusterExpansion.lean`.
  - mathlib v4.12.0 only. Axiom footprint = classical trio
    `{propext, Classical.choice, Quot.sound}`.
  - No sorry, no admit, no axiom, no unsafe, no implemented_by.

Proof outline.
  Bridge.   `dim_SU3 m n = Weyl_dim_SU3_explicit (m, n)`            [rfl]
  Step 2.   LHS summand `Summable` on ℕ × ℕ                         [PeterWeyl + congr]
  Step 3.   Pointwise bound `summand (m,n) ≤ G (m,n)` where
              `G (m,n) := (8(m+n+1)³)² · exp(-(3/4)·t·(m+n)²)`
              via squaring `dim_cubic_bound` and exp-monotonicity
              on `Casimir_SU3_explicit_real_ge_quadratic`.            [pow_le_pow_left + exp_le_exp]
  Step 4.   Single-index envelope `Summable (k ↦ (k+1) · F t k)`
              where `F t k := (8(k+1)³)² · exp(-(3/4)·t·k²)`,
              via `k² ≥ k` (k ∈ ℕ) ⇒ poly × Gaussian ≤ poly × geometric.
  Step 5.   `Summable G` on ℕ × ℕ via
              `sigmaAntidiagonalEquivProd.summable_iff` + sigma split
              (each antidiagonal is finite, the n-th has card (n+1)).
  Step 6.   K t = ∑' p : ℕ × ℕ, summand p                            [tsum_prod' reverse]
  Step 7.   ∑' p, G p = ∑' k, (k+1) · F t k                          [sigmaAntidiagonalEquivProd.tsum_eq + tsum_sigma' + Finset.sum_const + card_antidiagonal]
  Headline. Combine 2,3,4,5,6,7 via `tsum_le_tsum`.
================================================================
-/

import Towers.YM.Casimir
import Towers.YM.WeylDim
import Mathlib.Topology.Algebra.InfiniteSum.Ring
import Mathlib.Algebra.Order.Antidiag.Prod
import Mathlib.Data.Finset.NatAntidiagonal
import Mathlib.MeasureTheory.Integral.Gamma

namespace TheoremaAureum.Towers.YM.HeatTraceBound

open TheoremaAureum.Towers.YM.ClusterExpansion
  (Weyl_dim_SU3_explicit Casimir_SU3_explicit Casimir_SU3_explicit_nonneg)
open TheoremaAureum.Towers.YM.PeterWeyl (PeterWeyl_Summable_SU3)
open TheoremaAureum.Towers.YM.Casimir (Casimir_SU3_explicit_real_ge_quadratic)
open TheoremaAureum.Towers.YM.WeylDim (dim_SU3 dim_cubic_bound)
open Finset

/-! ### Definition of `K (t)` -/

/-- **Heat-trace placeholder `K (t)`** — iterated Peter–Weyl spectral
sum for the SU(3) heat kernel at the identity. Definitional only. -/
noncomputable def K (t : ℝ) : ℝ :=
  ∑' (m : ℕ) (n : ℕ),
    ((dim_SU3 m n : ℝ)) ^ 2 *
      Real.exp (-t * (Casimir_SU3_explicit (m, n) : ℝ))

/-! ### Helpers — summand, envelope `F`, antidiagonal envelope `G` -/

/-- The LHS summand as a function of a pair. -/
private noncomputable def summand (t : ℝ) (mn : ℕ × ℕ) : ℝ :=
  ((dim_SU3 mn.1 mn.2 : ℝ)) ^ 2 *
    Real.exp (-t * (Casimir_SU3_explicit (mn.1, mn.2) : ℝ))

private lemma summand_nonneg (t : ℝ) (mn : ℕ × ℕ) : 0 ≤ summand t mn :=
  mul_nonneg (sq_nonneg _) (Real.exp_pos _).le

/-- Per-antidiagonal envelope value at antidiagonal `k`:
  `F t k := (8 · (k+1)³)² · exp(-(3/4) · t · k²)`. -/
private noncomputable def F (t : ℝ) (k : ℕ) : ℝ :=
  (8 * ((k : ℝ) + 1) ^ 3) ^ 2 * Real.exp (-(3/4) * t * (k : ℝ) ^ 2)

private lemma F_nonneg (t : ℝ) (k : ℕ) : 0 ≤ F t k :=
  mul_nonneg (sq_nonneg _) (Real.exp_pos _).le

/-- Antidiagonal envelope on `ℕ × ℕ`: depends only on `m + n`. -/
private noncomputable def G (t : ℝ) (mn : ℕ × ℕ) : ℝ :=
  F t (mn.1 + mn.2)

private lemma G_nonneg (t : ℝ) (mn : ℕ × ℕ) : 0 ≤ G t mn := F_nonneg _ _

/-! ### Step 2 — LHS summand is Summable on `ℕ × ℕ` -/

private lemma summable_summand (t : ℝ) (ht : 0 < t) :
    Summable (summand t) := by
  have hpw := PeterWeyl_Summable_SU3 (β := t) ht
  refine hpw.congr (fun mn => ?_)
  -- PeterWeyl summand is
  --   (Weyl_dim_SU3_explicit mn : ℝ)^2 * Real.exp (-(t * (C₂ mn : ℝ)))
  -- Our `summand t mn` is
  --   (dim_SU3 mn.1 mn.2 : ℝ)^2 * Real.exp (-t * (C₂ (mn.1, mn.2) : ℝ))
  -- `(mn.1, mn.2) = mn` by Prod.eta; `dim_SU3 m n = Weyl_dim_SU3_explicit (m,n)` by rfl.
  show (Weyl_dim_SU3_explicit mn : ℝ) ^ 2 *
        Real.exp (-(t * (Casimir_SU3_explicit mn : ℝ))) = summand t mn
  unfold summand
  have hprod : (mn.1, mn.2) = mn := rfl
  rw [hprod]
  congr 1
  ring

/-! ### Step 3 — pointwise bound: `summand (m, n) ≤ G (m, n)` -/

private lemma summand_le_G (t : ℝ) (ht : 0 < t) (mn : ℕ × ℕ) :
    summand t mn ≤ G t mn := by
  -- dim_SU3 ≤ 8 · (m+n+1)³  ⇒  (dim_SU3)² ≤ (8 · (m+n+1)³)²
  -- 0 < t, ¾(m+n)² + 3(m+n) ≤ C₂  ⇒  exp(-t · C₂) ≤ exp(-(3/4) · t · (m+n)²)
  unfold summand G F
  have hdim_nonneg : (0 : ℝ) ≤ (dim_SU3 mn.1 mn.2 : ℝ) := Nat.cast_nonneg _
  have hdim_le : (dim_SU3 mn.1 mn.2 : ℝ) ≤ 8 * ((mn.1 : ℝ) + mn.2 + 1) ^ 3 := by
    have h := dim_cubic_bound mn.1 mn.2
    have hcast : (dim_SU3 mn.1 mn.2 : ℝ) ≤ (8 * (mn.1 + mn.2 + 1) ^ 3 : ℕ) := by
      exact_mod_cast h
    -- Now show the ℕ cast equals the ℝ expression.
    have hpush : ((8 * (mn.1 + mn.2 + 1) ^ 3 : ℕ) : ℝ)
                  = 8 * ((mn.1 : ℝ) + mn.2 + 1) ^ 3 := by push_cast; ring
    rw [hpush] at hcast
    exact hcast
  have hsq_le :
      (dim_SU3 mn.1 mn.2 : ℝ) ^ 2 ≤ (8 * ((mn.1 : ℝ) + mn.2 + 1) ^ 3) ^ 2 :=
    pow_le_pow_left hdim_nonneg hdim_le 2
  -- Real-valued quadratic Casimir bound (via the named brick on Weyl_label = (mn.1, mn.2)).
  have hcas := Casimir_SU3_explicit_real_ge_quadratic (mn.1, mn.2)
  -- hcas : (3/4) * ((mn.1 : ℝ) + mn.2)^2 + 3 * ((mn.1 : ℝ) + mn.2)
  --          ≤ (Casimir_SU3_explicit (mn.1, mn.2) : ℝ)
  have hexp_arg_le :
      -t * (Casimir_SU3_explicit (mn.1, mn.2) : ℝ)
        ≤ -(3/4) * t * ((mn.1 : ℝ) + mn.2) ^ 2 := by
    -- Equivalent to: (3/4) * t * (m+n)^2 ≤ t * Casimir.
    -- We have: (3/4)(m+n)^2 + 3(m+n) ≤ Casimir, so (3/4)(m+n)^2 ≤ Casimir
    -- (since 3(m+n) ≥ 0), and multiplying by t > 0 preserves.
    have _hmn_nonneg : (0 : ℝ) ≤ ((mn.1 : ℝ) + mn.2) := by positivity
    have hdrop : (3/4 : ℝ) * ((mn.1 : ℝ) + mn.2) ^ 2
                  ≤ (Casimir_SU3_explicit (mn.1, mn.2) : ℝ) := by
      have _h_extra : 0 ≤ 3 * ((mn.1 : ℝ) + mn.2) := by positivity
      linarith
    have hmul := mul_le_mul_of_nonneg_left hdrop ht.le
    linarith
  have hexp_le :
      Real.exp (-t * (Casimir_SU3_explicit (mn.1, mn.2) : ℝ))
        ≤ Real.exp (-(3/4) * t * ((mn.1 : ℝ) + mn.2) ^ 2) :=
    Real.exp_le_exp.mpr hexp_arg_le
  have hexp_nonneg :
      (0 : ℝ) ≤ Real.exp (-t * (Casimir_SU3_explicit (mn.1, mn.2) : ℝ)) :=
    (Real.exp_pos _).le
  have hpoly_sq_nonneg :
      (0 : ℝ) ≤ (8 * ((mn.1 : ℝ) + mn.2 + 1) ^ 3) ^ 2 := sq_nonneg _
  -- Show the antidiagonal F-shape with `(mn.1 + mn.2 : ℕ) : ℝ` equals
  -- `((mn.1 : ℝ) + mn.2)` etc. (push the cast).
  have _hk_cast : ((mn.1 + mn.2 : ℕ) : ℝ) = ((mn.1 : ℝ) + mn.2) := by push_cast; ring
  have _hk1_cast :
      ((mn.1 + mn.2 : ℕ) : ℝ) + 1 = ((mn.1 : ℝ) + mn.2 + 1) := by push_cast; ring
  -- Combine.
  calc
    (dim_SU3 mn.1 mn.2 : ℝ) ^ 2 *
          Real.exp (-t * (Casimir_SU3_explicit (mn.1, mn.2) : ℝ))
        ≤ (8 * ((mn.1 : ℝ) + mn.2 + 1) ^ 3) ^ 2 *
            Real.exp (-t * (Casimir_SU3_explicit (mn.1, mn.2) : ℝ)) :=
          mul_le_mul_of_nonneg_right hsq_le hexp_nonneg
    _ ≤ (8 * ((mn.1 : ℝ) + mn.2 + 1) ^ 3) ^ 2 *
            Real.exp (-(3/4) * t * ((mn.1 : ℝ) + mn.2) ^ 2) :=
          mul_le_mul_of_nonneg_left hexp_le hpoly_sq_nonneg
    _ = (8 * (((mn.1 + mn.2 : ℕ) : ℝ) + 1) ^ 3) ^ 2 *
            Real.exp (-(3/4) * t * ((mn.1 + mn.2 : ℕ) : ℝ) ^ 2) := by
          push_cast
          ring

/-! ### Step 4 — Summable `(k ↦ (k + 1) · F t k)` -/

/-- The single-index envelope `∑'_k (k+1) · F t k` is `Summable`.
Reduces poly × Gaussian ≤ poly × geometric via `k² ≥ k` on ℕ. -/
private lemma summable_card_mul_F (t : ℝ) (ht : 0 < t) :
    Summable (fun k : ℕ => ((k : ℝ) + 1) * F t k) := by
  set β : ℝ := (3 / 4) * t with hβ_def
  have hβ : 0 < β := by positivity
  -- Envelope: 8192 · (k^7 · exp(-β·k)) + 8192 · (k^0 · exp(-β·k))
  --   coming from (k+1)·F t k = 64 · (k+1)^7 · exp(-β·k²)
  --              ≤ 64 · (128·k^7 + 128) · exp(-β·k)   [(k+1)^7 ≤ 128(k^7+1), k² ≥ k]
  --              = 8192·k^7·exp(-β·k) + 8192·exp(-β·k).
  have hsum7 : Summable (fun k : ℕ =>
      (8192 : ℝ) * ((k : ℝ) ^ 7 * Real.exp (-β * (k : ℝ)))) :=
    (Real.summable_pow_mul_exp_neg_nat_mul 7 hβ).mul_left _
  have hsum0 : Summable (fun k : ℕ =>
      (8192 : ℝ) * ((k : ℝ) ^ 0 * Real.exp (-β * (k : ℝ)))) :=
    (Real.summable_pow_mul_exp_neg_nat_mul 0 hβ).mul_left _
  have hsum_env :
      Summable (fun k : ℕ =>
        (8192 : ℝ) * ((k : ℝ) ^ 7 * Real.exp (-β * (k : ℝ)))
          + (8192 : ℝ) * ((k : ℝ) ^ 0 * Real.exp (-β * (k : ℝ)))) :=
    hsum7.add hsum0
  refine Summable.of_nonneg_of_le ?_ ?_ hsum_env
  · intro k
    exact mul_nonneg (by positivity) (F_nonneg _ _)
  · intro k
    -- Bound (k+1) · F t k by the envelope.
    have hk_sq : ((k : ℝ)) ≤ ((k : ℝ)) ^ 2 := by
      rcases Nat.eq_zero_or_pos k with hk | hk
      · subst hk; simp
      · have hk1 : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk
        nlinarith
    have hβ_neg : -β ≤ 0 := neg_nonpos.mpr hβ.le
    have hexp_le :
        Real.exp (-(3 / 4) * t * (k : ℝ) ^ 2) ≤ Real.exp (-β * (k : ℝ)) := by
      apply Real.exp_le_exp.mpr
      have h1 : -β * ((k : ℝ)) ^ 2 ≤ -β * (k : ℝ) :=
        mul_le_mul_of_nonpos_left hk_sq hβ_neg
      have h2 : -(3 / 4) * t * (k : ℝ) ^ 2 = -β * ((k : ℝ)) ^ 2 := by
        rw [hβ_def]; ring
      linarith [h1, h2.le, h2.ge]
    have hexp_nonneg : (0 : ℝ) ≤ Real.exp (-(3 / 4) * t * (k : ℝ) ^ 2) :=
      (Real.exp_pos _).le
    have hexp_envelope_nonneg : (0 : ℝ) ≤ Real.exp (-β * (k : ℝ)) :=
      (Real.exp_pos _).le
    -- (k+1)^7 ≤ 128 · (k^7 + 1)
    have hpow_le : ((k : ℝ) + 1) ^ 7 ≤ 128 * ((k : ℝ) ^ 7 + 1) := by
      rcases Nat.eq_zero_or_pos k with hk | hk
      · subst hk; norm_num
      · have hk1 : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk
        have _hk_pos : (0 : ℝ) < (k : ℝ) := by exact_mod_cast hk
        -- (k+1) ≤ 2k for k ≥ 1, so (k+1)^7 ≤ (2k)^7 = 128·k^7 ≤ 128(k^7+1).
        have h2k : ((k : ℝ) + 1) ≤ 2 * (k : ℝ) := by linarith
        have h2k_nn : (0 : ℝ) ≤ (k : ℝ) + 1 := by linarith
        have hpow7 : ((k : ℝ) + 1) ^ 7 ≤ (2 * (k : ℝ)) ^ 7 :=
          pow_le_pow_left h2k_nn h2k 7
        have h2_pow : (2 * (k : ℝ)) ^ 7 = 128 * (k : ℝ) ^ 7 := by ring
        have _hk7_nn : (0 : ℝ) ≤ (k : ℝ) ^ 7 := by positivity
        nlinarith [hpow7, h2_pow]
    have _hpow_nonneg : (0 : ℝ) ≤ ((k : ℝ) + 1) ^ 7 := by positivity
    -- Now (k+1) · F t k = 64 · (k+1)^7 · exp(-(3/4)t·k²)
    have h_eq_64 :
        ((k : ℝ) + 1) * F t k = 64 * ((k : ℝ) + 1) ^ 7
                                  * Real.exp (-(3 / 4) * t * (k : ℝ) ^ 2) := by
      unfold F; ring
    rw [h_eq_64]
    -- Bound poly part: 64 · (k+1)^7 ≤ 64 · 128 · (k^7 + 1) = 8192 · k^7 + 8192
    have hpoly_le :
        64 * ((k : ℝ) + 1) ^ 7 ≤ 8192 * (k : ℝ) ^ 7 + 8192 := by
      have := mul_le_mul_of_nonneg_left hpow_le (by norm_num : (0 : ℝ) ≤ 64)
      linarith
    have hpoly_nonneg : (0 : ℝ) ≤ 64 * ((k : ℝ) + 1) ^ 7 := by positivity
    -- Combine: poly * exp ≤ poly * exp_env ≤ (8192k^7 + 8192) * exp_env
    calc 64 * ((k : ℝ) + 1) ^ 7 * Real.exp (-(3 / 4) * t * (k : ℝ) ^ 2)
          ≤ 64 * ((k : ℝ) + 1) ^ 7 * Real.exp (-β * (k : ℝ)) :=
            mul_le_mul_of_nonneg_left hexp_le hpoly_nonneg
      _ ≤ (8192 * (k : ℝ) ^ 7 + 8192) * Real.exp (-β * (k : ℝ)) :=
            mul_le_mul_of_nonneg_right hpoly_le hexp_envelope_nonneg
      _ = 8192 * ((k : ℝ) ^ 7 * Real.exp (-β * (k : ℝ)))
            + 8192 * ((k : ℝ) ^ 0 * Real.exp (-β * (k : ℝ))) := by ring

/-! ### Step 5 — `Summable G` on ℕ × ℕ via the antidiagonal equiv -/

private lemma G_const_on_antidiag (t : ℝ) (k : ℕ) (ij : ℕ × ℕ)
    (hij : ij ∈ antidiagonal k) :
    G t ij = F t k := by
  unfold G
  congr 1
  exact (Finset.mem_antidiagonal.mp hij)

/-- The antidiagonal-sigma sum collapses (each antidiagonal is finite and
G is constant on it). -/
private lemma sum_antidiag_G (t : ℝ) (k : ℕ) :
    ∑ ij ∈ antidiagonal k, G t ij = ((k : ℝ) + 1) * F t k := by
  rw [Finset.sum_congr rfl (fun ij hij => G_const_on_antidiag t k ij hij)]
  rw [Finset.sum_const, Finset.Nat.card_antidiagonal]
  simp [Nat.cast_add, Nat.cast_one, mul_comm]

private lemma summable_G (t : ℝ) (ht : 0 < t) : Summable (G t) := by
  -- Strategy: via sigmaAntidiagonalEquivProd, Summable G ↔ Summable F_sigma
  -- where F_sigma s := G (sigmaAntidiagonalEquivProd s) — depends only on s.1.
  rw [← Finset.sigmaAntidiagonalEquivProd.summable_iff]
  -- Goal: Summable (fun s : Σ n, antidiagonal n => G t (equiv s)).
  -- Build via Summable.sigma_factor (each fibre finite) +
  -- Summable on n via summable_card_mul_F.
  -- We use `summable_sigma_of_nonneg`-style: it suffices to show
  --   (a) ∀ n, Summable (c ↦ G t (equiv ⟨n, c⟩))   [trivial: finite]
  --   (b) Summable (n ↦ ∑' c, G t (equiv ⟨n, c⟩))
  refine (summable_sigma_of_nonneg ?_).mpr ⟨?_, ?_⟩
  · intro s; exact G_nonneg _ _
  · intro n
    exact (hasSum_fintype (fun c : antidiagonal n =>
      G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩))).summable
  · -- Congr to (n ↦ (n+1) · F t n), then use summable_card_mul_F.
    have hcong : (fun n : ℕ => ∑' c : antidiagonal n,
                    G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩))
                  = fun n : ℕ => ((n : ℝ) + 1) * F t n := by
      funext n
      rw [tsum_fintype]
      -- Each c : antidiagonal n is a subtype element; sigmaAntidiagonalEquivProd
      -- extracts the underlying pair. So G t (equiv ⟨n, c⟩) = G t c.1.
      have heq_pt : ∀ c : antidiagonal n,
          G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩) = G t c.val :=
        fun _ => rfl
      have : (∑ c : antidiagonal n,
                G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩))
              = ∑ ij ∈ antidiagonal n, G t ij := by
        rw [Finset.sum_congr rfl (fun c _ => heq_pt c)]
        exact Finset.sum_attach (antidiagonal n) (G t)
      rw [this]
      exact sum_antidiag_G t n
    have h_summable_inner :
        Summable fun n : ℕ => ∑' c : antidiagonal n,
                                G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩) := by
      rw [hcong]
      exact summable_card_mul_F t ht
    -- The goal involves `G t ∘ ⇑equiv ⟨x, y⟩`, which is defeq to
    -- `G t (equiv ⟨x, y⟩)`.
    exact h_summable_inner

/-! ### Step 6 — `K t = ∑' p : ℕ × ℕ, summand t p` -/

private lemma K_eq_tsum_prod (t : ℝ) (ht : 0 < t) :
    K t = ∑' p : ℕ × ℕ, summand t p := by
  unfold K
  -- ∑' m, ∑' n, f m n = ∑' p, f p.1 p.2  via tsum_prod' (reverse direction).
  have h_summable := summable_summand t ht
  -- tsum_prod' :  ∑' p, f p = ∑' (b) (c), f (b, c)   under summability.
  -- Apply with f := summand t; need also `∀ b, Summable (c ↦ summand t (b, c))`.
  have h_factor : ∀ m : ℕ, Summable (fun n : ℕ => summand t (m, n)) :=
    fun m => h_summable.prod_factor m
  have h_tsum_prod : ∑' p : ℕ × ℕ, summand t p
                      = ∑' (m : ℕ) (n : ℕ), summand t (m, n) :=
    tsum_prod' h_summable h_factor
  -- Now identify the RHS of h_tsum_prod with the unfolded K t.
  -- summand t (m, n) = (dim_SU3 m n : ℝ)^2 * Real.exp (-t * (C₂ (m, n) : ℝ)).
  -- That's exactly the inner term of K.
  rw [h_tsum_prod]
  rfl

/-! ### Step 7 — `∑' p, G t p = ∑' k, (k+1) · F t k` -/

set_option maxHeartbeats 800000 in
private lemma tsum_G_eq (t : ℝ) (ht : 0 < t) :
    ∑' p : ℕ × ℕ, G t p = ∑' k : ℕ, ((k : ℝ) + 1) * F t k := by
  have h_G_summable := summable_G t ht
  -- via sigmaAntidiagonalEquivProd: ∑' p, G p = ∑' s : Σ n, antidiag n, G (equiv s).
  rw [← (Finset.sigmaAntidiagonalEquivProd.tsum_eq (G t))]
  -- Now split the sigma sum via tsum_sigma'.
  have h_sigma_summable :
      Summable (fun s : Σ n : ℕ, antidiagonal n =>
                  G t (Finset.sigmaAntidiagonalEquivProd s)) :=
    Finset.sigmaAntidiagonalEquivProd.summable_iff.mpr h_G_summable
  have h_inner_summable :
      ∀ n : ℕ, Summable (fun c : antidiagonal n =>
                  G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩)) :=
    fun n => (hasSum_fintype _).summable
  rw [tsum_sigma' h_inner_summable h_sigma_summable]
  -- Inner tsum is over a finite type → finite sum, then collapses.
  apply tsum_congr
  intro n
  rw [tsum_fintype]
  have heq_pt : ∀ c : antidiagonal n,
      G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩) = G t c.val :=
    fun _ => rfl
  have hattach : (∑ c : antidiagonal n,
                    G t (Finset.sigmaAntidiagonalEquivProd ⟨n, c⟩))
                  = ∑ ij ∈ antidiagonal n, G t ij := by
    rw [Finset.sum_congr rfl (fun c _ => heq_pt c)]
    exact Finset.sum_attach (antidiagonal n) (G t)
  rw [hattach]
  exact sum_antidiag_G t n

/-! ### Headline brick — antidiagonal envelope -/

/-- **Antidiagonal envelope for the SU(3) heat-trace placeholder.**
For every `t > 0`,
`K t ≤ ∑'_k (k+1) · (8(k+1)³)² · exp(-(3/4)·t·k²)`. -/
theorem heat_trace_envelope : ∀ t : ℝ, 0 < t →
    K t ≤ ∑' k : ℕ, ((k : ℝ) + 1) * (8 * ((k : ℝ) + 1) ^ 3) ^ 2
                      * Real.exp (-(3/4) * t * (k : ℝ) ^ 2) := by
  intro t ht
  have h_K := K_eq_tsum_prod t ht
  have h_summand_summable := summable_summand t ht
  have h_G_summable := summable_G t ht
  have h_pointwise : ∀ p : ℕ × ℕ, summand t p ≤ G t p := fun p => summand_le_G t ht p
  have h_tsum_le :
      ∑' p : ℕ × ℕ, summand t p ≤ ∑' p : ℕ × ℕ, G t p :=
    tsum_le_tsum h_pointwise h_summand_summable h_G_summable
  have h_G_collapse : ∑' p : ℕ × ℕ, G t p = ∑' k : ℕ, ((k : ℝ) + 1) * F t k :=
    tsum_G_eq t ht
  -- Combine: K t = ∑' p, summand ≤ ∑' p, G = ∑' k, (k+1)·F t k.
  rw [h_K]
  calc ∑' p : ℕ × ℕ, summand t p ≤ ∑' p : ℕ × ℕ, G t p := h_tsum_le
    _ = ∑' k : ℕ, ((k : ℝ) + 1) * F t k := h_G_collapse
    _ = ∑' k : ℕ, ((k : ℝ) + 1) * (8 * ((k : ℝ) + 1) ^ 3) ^ 2
                    * Real.exp (-(3/4) * t * (k : ℝ) ^ 2) := by
        apply tsum_congr
        intro k
        unfold F
        ring

/-! ### Batch 156.3b — Gaussian moment and polynomial heat-trace bound -/

/-- **Gaussian seventh moment.**  `∫₀^∞ x^7 · exp(-a · x²) dx = 3/a^4`
for every `a > 0`. Direct application of mathlib's
`integral_rpow_mul_exp_neg_mul_rpow` with `p = 2, q = 7`, evaluating
`Γ(4) = 6` via iterated `Real.Gamma_add_one`. -/
lemma gaussian_moment_7 (a : ℝ) (ha : 0 < a) :
    ∫ x in Set.Ioi (0:ℝ), x^7 * Real.exp (-a * x^2) = 3 / a^4 := by
  -- Rewrite nat-powers on x as rpows (valid since x > 0).
  have h_eq : Set.EqOn (fun x : ℝ => x^7 * Real.exp (-a * x^2))
                       (fun x : ℝ => x^(7:ℝ) * Real.exp (-a * x^(2:ℝ)))
                       (Set.Ioi (0:ℝ)) := by
    intro x _
    have h7 : (x : ℝ)^(7:ℝ) = x^(7:ℕ) := by
      have hcast : ((7:ℕ):ℝ) = (7:ℝ) := by norm_num
      rw [← hcast, Real.rpow_natCast]
    have h2 : (x : ℝ)^(2:ℝ) = x^(2:ℕ) := by
      have hcast : ((2:ℕ):ℝ) = (2:ℝ) := by norm_num
      rw [← hcast, Real.rpow_natCast]
    simp only [h7, h2]
  rw [MeasureTheory.setIntegral_congr measurableSet_Ioi h_eq]
  rw [integral_rpow_mul_exp_neg_mul_rpow (by norm_num : (0:ℝ) < 2)
        (by norm_num : (-1:ℝ) < 7) ha]
  -- Now: a^(-(7+1)/2) * (1/2) * Γ((7+1)/2) = a^(-4) * (1/2) * Γ(4).
  have hexp_arg : (-(7 + 1) / 2 : ℝ) = -4 := by norm_num
  have hΓ_arg : ((7 + 1) / 2 : ℝ) = 4 := by norm_num
  rw [hexp_arg, hΓ_arg]
  -- Γ(4) = 6.
  have hΓ4 : Real.Gamma 4 = 6 := by
    have e1 : (4 : ℝ) = 3 + 1 := by norm_num
    rw [e1, Real.Gamma_add_one (by norm_num : (3:ℝ) ≠ 0)]
    have e2 : (3 : ℝ) = 2 + 1 := by norm_num
    rw [e2, Real.Gamma_add_one (by norm_num : (2:ℝ) ≠ 0)]
    have e3 : (2 : ℝ) = 1 + 1 := by norm_num
    rw [e3, Real.Gamma_add_one (by norm_num : (1:ℝ) ≠ 0), Real.Gamma_one]
    ring
  rw [hΓ4]
  -- a^(-4 : ℝ) = (a^4)⁻¹.
  have ha4 : a^(-4 : ℝ) = (a^(4:ℕ))⁻¹ := by
    have hcast : ((4:ℕ):ℝ) = (4:ℝ) := by norm_num
    rw [show (-4:ℝ) = -((4:ℕ):ℝ) from by rw [hcast],
        Real.rpow_neg ha.le, Real.rpow_natCast]
  rw [ha4]
  have ha4_ne : a^(4:ℕ) ≠ 0 := pow_ne_zero _ ha.ne'
  field_simp
  ring

end TheoremaAureum.Towers.YM.HeatTraceBound
