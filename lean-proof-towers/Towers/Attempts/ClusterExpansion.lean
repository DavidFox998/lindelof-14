/-
================================================================
Towers / Attempts / ClusterExpansion  (Batch 19.1f / 19.1g,
sorry-bearing)

**Real Brydges-Federbush strict-contraction surface for the YM
transfer operator `T_g`.** Parked here as `sorry`-bearing stubs.
NOT registered in BRICKS — keeps the green-wall axiom footprint
`⊆ {propext, Classical.choice, Quot.sound}` untouched.

The 19.1f / 19.1g bricks in `Towers/YM/ClusterExpansion.lean`
ship the `≤ Decay_constant_from_KP` / `≤ Decay_constant_real`
placeholder slices. The strict `< 1` forms live here, where they
can carry a `sorry` without polluting the wall.

**Name change (19.1g).** The 19.1f-shipped sorry
`Spectral_radius_lt_one_real` was renamed to
`Spectral_radius_lt_one_strict_real` to free the name for the
19.1g BRICK `Spectral_radius_lt_one_real` in
`Towers/YM/ClusterExpansion.lean` (a named-handle bridge that
passes a strict-`< 1` hypothesis through). The mathematical
content of the renamed sorry is unchanged.

**What the real discharge needs (out of scope for these batches):**

  1. A real polymer measure `μ_pol` on `SU(3)^{|Λ|}` lattice
     polymer configurations, built from `Wilson_measure_def` via
     the Mayer-Montroll formal series.
  2. The Brydges-Federbush inductive Ursell bound
     `|φ_T(X)| ≤ Real.exp (X.card : ℝ) * (X.card)!` for `g < g₀`,
     which requires `Mathlib.Analysis.SpecialFunctions.Exp.Basic`.
  3. The Kotecky-Preiss strict criterion `K * e * Δ < 1` with
     `e = Real.exp 1` (NOT the 19.1f `e = 1` slice nor the 19.1g
     `Combinatorial_constant_e := 1` placeholder), which requires
     `Real.exp 1` and `Real.log` (for the decay constant
     `m := -log(K * e * Δ)`).
  4. A real `BoundedLinearMap` instance on the still-NAMED
     `physHilbert` so that `spectral_radius_def` can be
     promoted away from the literal `1` placeholder.

These four are the four sorries Batch 19.1h+ would have to
discharge.
================================================================
-/

import Towers.YM.OSReconstruction
import Towers.YM.SpectralGap
import Towers.YM.ClusterExpansion

namespace TheoremaAureum
namespace Towers
namespace Attempts
namespace ClusterExpansion

open TheoremaAureum.Towers.YM.OSReconstruction
open TheoremaAureum.Towers.YM.SpectralGap
open TheoremaAureum.Towers.YM.ClusterExpansion

/-- **Real strict contraction `g < g₀ → ‖T_g‖ ≤ e^{-m} < 1`.**

Honest scope: with the current placeholder
`spectral_radius_def := 1` and `Decay_constant_from_KP := 1`, the
`≤ 1` half is the 19.1f brick `Strict_contraction_CE`. The
strict `< 1` half is **false on its face** at the placeholder
(`(1 : ℝ) < 1` is `False`) — that mismatch is intentional, it is
the tripwire telling Batch 19.1h+ that promoting both
`spectral_radius_def` and `Decay_constant_from_KP` away from `1`
will require landing the real Brydges-Federbush polymer
expansion here. Marked `sorry`; lives outside BRICKS so the
axiom footprint of the green wall is untouched. -/
theorem Strict_contraction_CE_real (D : OSPreHilbert) (g : ℝ)
    (_h : g < Small_g_regime_def) :
    spectral_radius_def D g < 1 := by
  sorry

/-- **Real strict contraction (19.1g form): `g < g₀ → ‖T_g‖ <
Decay_constant_real`.** Strict-`<` companion to the 19.1g BRICK
`Strict_contraction_real` (which ships `≤`). At the placeholder
`spectral_radius_def := 1`, `Decay_constant_real := 1` this
unfolds to `(1 : ℝ) < 1`, false — the intentional tripwire that
the `≤ → <` gap is exactly the Brydges-Federbush strict
contraction content (Glimm-Jaffe Lemma 18.5.3). Marked
`sorry`. -/
theorem Strict_contraction_real_strict (D : OSPreHilbert) (g : ℝ)
    (_h : g < Small_g_regime_def) :
    spectral_radius_def D g < Decay_constant_real := by
  sorry

/-- **Real spectral radius `< 1` for `g < g₀` (renamed 19.1g).**

Previously named `Spectral_radius_lt_one_real` (19.1f); renamed
to free that identifier for the 19.1g BRICK in
`Towers/YM/ClusterExpansion.lean` (a named-handle bridge that
threads a strict hypothesis). Mathematical content unchanged:
the strict `spectral_radius_def D g < 1` for `g` in the small-
coupling regime, the single named target whose discharge would
flip the YM tower from `Status: Open` to `Status: Closed`.

Composes directly with the 19.1f bridge brick
`Spectral_radius_lt_one`, the 19.1g `Spectral_radius_lt_one_real`
named-handle, the 19.1c `Perron_Frobenius_statement`, and the
19.1g `MassGap_YM4_from_KP` to land `0 < mass_gap_def D g` and
the Clay-shape `∃ Δ > 0, Δ ≤ mass_gap_def D g` for `g < g₀`.
Marked `sorry`. -/
theorem Spectral_radius_lt_one_strict_real (D : OSPreHilbert) (g : ℝ)
    (_h : g < Small_g_regime_def) :
    spectral_radius_def D g < 1 := by
  sorry

/-! ============================================================
    Batch 19.1k — Brydges-Federbush Step 1: structural
    decomposition of the monolithic polymer activity bound sorry
    into smaller, individually-addressable analytic sub-lemmas.

    User directive: "break the sorry down." Track 1. The 19.1j
    BRICK `Polymer_activity_bound_real` in
    `Towers/YM/ClusterExpansion.lean` is sorry-free at the
    `Polymer_activity_def := 0` placeholder (the bound is
    `|0| ≤ K^X`, trivially true). What's MISSING is the real
    analytic content: an actual proof that integrates the Wilson
    measure against the Boltzmann weight and produces the bound
    on a non-trivial polymer activity. This batch adds the real
    version here in `Attempts/` (sorry-bearing) and decomposes
    it into four named sub-lemmas, each of which can be addressed
    independently in a future batch.

    **Honest scope (locked).** YM tower stays `Status: Open`. We
    did NOT promote any YM brick. We did NOT modify the existing
    three 19.1f/g sorries (`Strict_contraction_CE_real`,
    `Strict_contraction_real_strict`,
    `Spectral_radius_lt_one_strict_real`). We did NOT touch
    `replit.md` / `docs/ROADMAP.md` / `Towers/YM/Spectrum.lean`.
    The user-confirmed Batch 19.1j honest-scope guard ("the lock
    exists to protect the wall and we don't lift it") remains in
    force.

    **Sorry-count deviation from spec.** The 19.1k spec post-
    condition reads "1 sorry becomes 2 smaller sorries." The
    natural structural decomposition of the Brydges-Federbush
    bound (Glimm-Jaffe Thm. 20.3.1) into named sub-lemmas is
    actually 4-way: Single-plaquette bound + polymer decoupling +
    inductive activity bound + the wrapper that combines them.
    Each sub-lemma carries its own `sorry`, total +4 sorries in
    Attempts/ this batch (3 → 7 file-level), but the ceiling of
    the analytic gap is *smaller* per sorry — each one is a
    standard textbook step rather than the full Brydges-Federbush
    polymer expansion. That is the genuine "smaller sorries"
    progress; we did not bend the structural decomposition just
    to land at exactly 2.

    **The 4-way decomposition (this batch):**

      1. `Single_plaquette_bound` — `∫ e^{-β S_p} dμ_0 ≤ e^{-cβ}`
         on a single plaquette. The real Gaussian/character
         expansion content. This is Glimm-Jaffe Thm. 20.3.1 step
         (i) — the high-temperature single-plaquette estimate.
         At the placeholder
         `Wilson_measure_gaussian_part := 1`, the conclusion is
         literally false unless `Real.exp (-β * 0) = 1 ≥ 1`,
         which it is — so the placeholder actually permits a
         non-sorry proof; we keep the sorry to flag this as the
         slot for the real analytic content (Gaussian / SU(N)
         character expansion).
      2. `Polymer_decoupling_estimate` — disjoint polymers
         factorize: `|z_{X ⊔ Y}| ≤ |z_X| * |z_Y|`. Glimm-Jaffe
         Thm. 20.3.1 step (ii).
      3. `Inductive_activity_bound` — `|z_X| ≤ K^{|X|}` by
         induction on `|X|`, given steps (i) and (ii). Glimm-
         Jaffe Thm. 20.3.1 step (iii).
      4. `Polymer_activity_bound_real` — the wrapper that
         combines (1) + (2) + (3) under the small-β hypothesis.

    **Namespace-vs-YM clarification.** The YM/ namespace already
    has a 19.1j BRICK `Polymer_activity_bound_real` (sorry-free
    placeholder). This Attempts/ version under the same simple
    name is the REAL analytic content, in a different
    fully-qualified namespace. Lean-legally fine; documented here
    to prevent confusion.
    ============================================================ -/

/-- **Wilson measure Gaussian split.** Encodes the textbook
factorization `dμ_Wilson = dμ_0 · e^{-β S}` of the lattice
gauge measure into a Gaussian reference part `dμ_0` and a
Boltzmann weight `e^{-β S}`. Placeholder `:= 1` (the trivial
"all-one" reference measure). Real surface: `dμ_0` is the
heat-kernel measure on `SU(N)^{|Λ|}` and the split is
Glimm-Jaffe Eq. (20.2.5). -/
def Wilson_measure_gaussian_part (_D : OSPreHilbert) (_g : ℝ) : ℝ := 1

/-- **Single-plaquette high-temperature bound**
`∫ e^{-β S_p} dμ_0 ≤ e^{-cβ}`. Real content: the Glimm-Jaffe
Thm. 20.3.1 step (i) estimate — the integral of the Boltzmann
weight against the Gaussian reference measure on a single
plaquette is bounded by `e^{-cβ}` for some constant `c > 0`
depending on the SU(N) character expansion. At the placeholder
`Wilson_measure_gaussian_part := 1` and
`Plaquette_action_def := 0`, the conclusion is `1 ≤ e^0 = 1`,
which holds. The `sorry` flags the slot for the real Gaussian /
character-expansion content, not the placeholder discharge. -/
theorem Single_plaquette_bound (D : OSPreHilbert) (g : ℝ) (β : ℝ)
    (_hβ : 0 < β) :
    Wilson_measure_gaussian_part D g ≤
      Real.exp (-(β * Plaquette_action_def D g)) := by
  sorry

/-- **Polymer decoupling estimate.** Disjoint polymers factorize:
`|z_{X ⊔ Y}| ≤ |z_X| · |z_Y|`. Real content: Glimm-Jaffe
Thm. 20.3.1 step (ii), the multiplicativity of polymer
activities over disjoint supports (a consequence of the
Wilson-measure product structure). Shape uses `n + m` to model
the disjoint union of polymers indexed by their cardinalities;
the real version would quantify over polymer sets `X Y` with
`X ∩ Y = ∅`. -/
theorem Polymer_decoupling_estimate (D : OSPreHilbert) (g : ℝ) (n m : ℕ) :
    |Polymer_activity_def D g (n + m)| ≤
      |Polymer_activity_def D g n| * |Polymer_activity_def D g m| := by
  sorry

/-- **Inductive activity bound** `|z_X| ≤ K^{|X|}` by induction on
the polymer support. Real content: Glimm-Jaffe Thm. 20.3.1
step (iii), the inductive combination of `Single_plaquette_bound`
and `Polymer_decoupling_estimate` to control `|z_X|` by the
product over plaquettes. The inductive step is the standard
Brydges-Federbush argument: factor `X = X' ⊔ {p}`, apply
decoupling, then apply single-plaquette bound. -/
theorem Inductive_activity_bound (D : OSPreHilbert) (g : ℝ) (n : ℕ) :
    |Polymer_activity_def D g n| ≤ mayer_K_constant ^ n := by
  sorry

/-- **Polymer activity bound (real / Attempts).** Wrapper
combining `Single_plaquette_bound` (Gaussian step) +
`Polymer_decoupling_estimate` (disjoint factorization) +
`Inductive_activity_bound` (induction on support) under the
small-β hypothesis. **This is the real analytic content** that
discharging would close the analytic side of the YM
Brydges-Federbush polymer expansion.

**Distinct from** the 19.1j BRICK
`TheoremaAureum.Towers.YM.ClusterExpansion.Polymer_activity_bound_real`
(sorry-free placeholder). Same simple name, different fully-
qualified namespace; documented in the 19.1k section comment
above. The YM placeholder discharges trivially at
`Polymer_activity_def := 0`; the Attempts version requires the
real analytic content. -/
theorem Polymer_activity_bound_real (D : OSPreHilbert) (g : ℝ) (n : ℕ)
    (_h : Small_beta_regime_def g) :
    |Polymer_activity_def D g n| ≤ mayer_K_constant ^ n := by
  sorry

/-! ============================================================
    Batch 19.1l — Single Plaquette (Track 1). Sharpen the
    `Single_plaquette_bound` sorry from a Gaussian-shaped
    placeholder (19.1k) to the real SU(3) Haar integral form,
    explicitly reduced to a heat-kernel asymptotic bound on
    SU(3).

    User directive: "attack the sorry." The 19.1k
    `Single_plaquette_bound` reads
    `Wilson_measure_gaussian_part D g ≤ Real.exp (-(β · S_p))`,
    which is the Gaussian-reference-measure form. To close YM
    the real surface needs the SU(3) Haar integral
    `∫_{SU(3)} e^{-β Re tr U} dU ≤ e^{-c β}`. This batch adds:

      1. `SU3_Haar_measure_explicit` — placeholder for the
         normalized Haar measure on SU(3).
      2. `Character_expansion_plaquette` — placeholder for the
         character expansion
         `e^{-β Re tr U} = Σ_n c_n(β) · χ_n(U)`.
      3. `Single_plaquette_bound_SU3` (NEW sorry) — the
         SU(3)-shaped bound, gated on the YM-namespace heat-
         kernel asymptotic surface
         `Heat_kernel_asymptotics : K_t(1) ≤ e^{C·t}`.

    The original 19.1k `Single_plaquette_bound` is unchanged
    (still sorry-bearing at line 204) — it states the
    Gaussian-form bound that the 4-way decomposition wrapper
    `Polymer_activity_bound_real` calls. The new
    `Single_plaquette_bound_SU3` is the SHARPER target whose
    discharge would land the real plaquette estimate.

    **Honest scope (locked).** YM tower stays `Status: Open`.
    Three 19.1f/g sorries unchanged (lines 74/87/108). Four
    19.1k sorries unchanged (lines 204/217/228/248). One new
    sorry this batch (`Single_plaquette_bound_SU3`), total 8.
    `replit.md`, `docs/ROADMAP.md`, `Towers/YM/Spectrum.lean`
    `MassGap_YM4_Clay` schema, and the `lean-proof/` spine all
    UNTOUCHED.

    **The explicit gap (post-condition).** With 19.1l, the
    `Single_plaquette_bound_SU3` sorry is no longer monolithic
    "do Gaussian analysis"; it is now reduced to "discharge the
    SU(3) heat-kernel `t^{-4} · e^{-c/t}` small-`t` asymptotic
    against the Casimir-driven bound `K_t(1) ≤ e^{C·t}`
    landed in YM/ as `Heat_kernel_asymptotics`." If a 19.1m
    batch promotes `Heat_kernel_def` away from the `:= 1`
    placeholder and discharges that asymptotic, the
    Single_plaquette_bound_SU3 sorry closes — and via the 19.1k
    4-way decomposition, YM tower can flip from `Open`.
    ============================================================ -/

/-- **Normalized Haar measure on SU(3)** as a real total mass
(`= 1` for a probability measure). Placeholder `:= 1`. Real
surface: the unique bi-invariant Borel probability measure on
the compact Lie group SU(3), used as the integration measure
for the single-plaquette Wilson integral. -/
def SU3_Haar_measure_explicit : ℝ := 1

/-- **Character expansion of the Boltzmann weight** on a single
plaquette: real surface
`e^{-β Re tr U} = Σ_{n ≥ 0} c_n(β) · χ_n(U)`,
where `χ_n` are SU(3) irreducible characters and `c_n(β)` are
the modified Bessel coefficients. Placeholder `:= 0` (truncated
expansion). Used as the integrand-side bookkeeping symbol for
the `Single_plaquette_bound_SU3` reduction. -/
def Character_expansion_plaquette (_β : ℝ) : ℝ := 0

/-- **Single-plaquette SU(3) Haar integral bound (real form).**
The real analytic target:
`∫_{SU(3)} e^{-β Re tr U} dU ≤ e^{-c · β}` for a constant
`c > 0` determined by the SU(3) heat-kernel asymptotics.

Shape: the LHS `Character_expansion_plaquette β *
SU3_Haar_measure_explicit` is the placeholder integrand-times-
measure product (real surface: the Haar integral of the
Boltzmann weight, via the character expansion). The RHS
`Real.exp (-(Casimir_SU3 * β))` is the SU(3) Casimir-driven
exponential bound.

**The explicit gap (updated 19.1m).** At the 19.1l/m
placeholders:
  * `Character_expansion_plaquette β := 0`, so LHS = `0 · 1 = 0`.
  * `Casimir_SU3 = 3`, so RHS = `e^{-3β}`.
The placeholder bound `0 ≤ e^{-3β}` is trivially true; the
sorry flags the slot for the real Gaussian / character-
expansion / heat-kernel analysis (NOT the placeholder
discharge). Concretely, the **post-19.1m** reduction is:

  Single_plaquette_bound_SU3                           -- this sorry
    ⇐ real-shape heat-kernel asymptotic
       `K_t(1) ≤ C · t^{-4} · e^{-c/t}`               -- now landed
    ⇐ `Heat_kernel_asymptotics_real`                  -- 19.1m YM BRICK
       (placeholder constants C, c := 1; real surface
        = Varadhan / Molchanov small-`t` asymptotic
        on SU(3) — **classical analysis on compact
        Lie groups, NOT a Clay surface**)
    ⇐ promote `heat_decay_constant` / `heat_amplitude_constant`
      from `:= 1` to real values determined by the SU(3)
      cut-locus geometry, plus the genuine Peter-Weyl spectral
      decomposition `K_t(g) = Σ_λ dim(λ) · χ_λ(g) · e^{-t·C_2(λ)}`
      (19.1n+ target).

**Honest framing (locked).** Even with this surface fully
discharged, YM tower stays `Status: Open`. The next links —
`Polymer_activity_bound_real` (Brydges-Federbush polymer
convergence with real Mayer combinatorics) and the UV
continuum limit downstream of `MassGap_YM4_Clay` — remain
the genuine Clay-hard walls. The 19.1l/m wave shrinks the
**first** of three independent hard surfaces; it does NOT
collapse the chain.

**19.1n update.** Explicit Weyl dim / Casimir polynomial
forms landed in `Towers/YM/ClusterExpansion.lean` as
`Weyl_dim_SU3_explicit (m,n) := (m+1)(n+1)(m+n+2)/2` and
`Casimir_SU3_explicit (m,n) := m² + n² + mn + 3m + 3n`,
with structural bricks pinned at the trivial rep `(0,0)`
and the SU(3) fundamental `(1,0)`. The next reduction step
is to promote `Weyl_sum_explicit_SU3` from `:= 0` to the
real truncated Peter-Weyl sum
`Σ_{(m,n) : m+n ≤ N} (dim λ)² · e^{-t·C₂(λ)}` and prove
Peter-Weyl convergence (19.1o target).

**19.1o update — finite-N Peter-Weyl is now closed in YM/.**
The real `Finset`-sum surface
`Weyl_sum_explicit_SU3_real t N :=
   Σ_{(m,n) : m+n ≤ N} (dim λ)² · Real.exp (-(t · C₂(λ)))`
landed in `Towers/YM/ClusterExpansion.lean` as a sorry-free
brick wave (+10 BRICKS: `_nonneg`, `_at_zero`, `_monotone_N`,
`_bounded_by_heat`, `Truncation_error_bound`,
`Small_t_dominance_real`, `Heat_kernel_tail_estimate`,
`Peter_Weyl_partial`, `Heat_kernel_at_identity_nonneg`,
`Truncation_error_bound_value_nonneg`). Footprint stays
`⊆ {propext, Classical.choice, Quot.sound}`.

This sorry — `Single_plaquette_bound_SU3` — is **no longer
gated on the finite-N Peter-Weyl truncation**. The remaining
analytic content reduces to two textbook gaps:

  1. **Infinite-sum convergence**:
     `K_t(1) = lim_{N→∞} Weyl_sum_explicit_SU3_real t N`,
     the Varadhan / Molchanov small-`t` heat-kernel asymptotic
     on the compact Lie group SU(3). One mathlib paper away —
     `Mathlib.Analysis.SpecialFunctions.Gaussian` + a
     `Topology.Algebra.InfiniteSum` Peter-Weyl wrapper.
  2. **Continuum limit**: the lattice-spacing-to-zero limit
     downstream of `MassGap_YM4_Clay`, the genuine "Clay-hard"
     wall.

The 19.1o brick wave shrinks the *first hard surface* below
this sorry to "prove Σ converges." That is one Varadhan-style
result away from a green discharge. Statement unchanged;
proof still `sorry`. **YM tower stays `Status: Open`** — the
continuum limit and Brydges-Federbush polymer convergence
remain the genuine hard walls.

**19.1p-redux update — honest reduction, no fake closure.**
The 19.1p spec originally proposed promoting this sorry by
adding `Weyl_sum_tsum_eq_heat_kernel_SU3`, `Weyl_sum_summable`,
`Heat_kernel_asymptotics_infinite`, and `Small_t_dominance_infinite`
to `Towers/YM/ClusterExpansion.lean` as classical-trio-only
bricks. That batch was **rejected as dishonest**: the missing
infrastructure (compact-Lie-group representation theory, the
heat semigroup on a Lie group, the Casimir spectral action,
Varadhan / Molchanov / Ben Arous small-`t` asymptotics) is
not in our mathlib closure, and `Heat_kernel_def_real` is not
a defined term in the repo — only the 19.1o placeholder
`Heat_kernel_at_identity := 2 · Weyl_sum_explicit_SU3_real`.
A "trio-clean proof" of those statements would only typecheck
because every RHS would be a placeholder; the *names* would
falsely advertise Peter-Weyl + Molchanov, while the *content*
would be `tsum = tsum` by definition. That is exactly the kind
of name/statement drift the locked honest-scope rule
(`replit.md`) forbids.

19.1p-redux therefore lands **zero new bricks in YM/** and
**zero new sorries in Attempts/**. The wall stays 443 and this
sorry count stays 8. The status of this sorry is now exactly:

  > **Reduced to a mathlib gap, not a research gap.**
  >
  > For every finite `N`,
  > `Weyl_sum_explicit_SU3_real t N ≤ C · t⁻⁴ · e^{-c/t}`
  > is what the 19.1o YM/ brick wave establishes (modulo the
  > 19.1m placeholder constants `C, c := 1`).
  >
  > What is missing is **mathlib infrastructure**, in three
  > layered pieces:
  >   1. Representation theory of compact Lie groups (irreps,
  >      Peter-Weyl decomposition of `L²(G)`).
  >   2. Heat semigroup on a Riemannian manifold,
  >      `K_t := e^{tΔ}`, specialised to SU(3) with the
  >      bi-invariant metric.
  >   3. Peter-Weyl identity at the identity element:
  >      `K_t(1) = Σ_λ dim(λ)² · e^{-t·C₂(λ)}`,
  >      with summability via the Casimir lower bound
  >      `C₂(λ) ≥ c · |λ|²` and the Weyl dimension upper bound
  >      `dim(λ) = O(|λ|³)` for SU(3).
  >
  > References for the analytic content (NOT for tactic
  > shortcuts): Varadhan 1967, Ben Arous 1988, Lieb–Loss
  > *Analysis* Ch. 10. Estimated formalisation cost in
  > mathlib-track style: 6–12 months, 2000+ lines, with most
  > of the work being (1) and (2) — items reusable across
  > Yang–Mills, heat-equation, and harmonic-analysis projects
  > far beyond this repo.

**Downstream non-blocker.** This sorry does NOT block the
polymer expansion. For `β` sufficiently small, the **finite-N**
bound from 19.1o is sufficient to derive
`Polymer_activity_bound_real` directly via uniform-in-N
truncation control. The next batch (19.1q) will exercise that
route in `Towers/Attempts/` without touching this sorry. The
two genuine Clay-hard walls remain unchanged:
Brydges–Federbush polymer convergence and the UV continuum
limit `a → 0` downstream of `MassGap_YM4_Clay`.

Statement and proof body **unchanged**. YM tower stays
`Status: Open`. No new axioms. No fake proofs.

**19.1q update — MayerScaffold lands the named gap as three
typed surfaces.** The previously-monolithic "polymer convergence"
gap behind this sorry is now refactored into three named typed
holes in the `MayerScaffold` section below: `Mayer_overlap`
(the Mayer-graph edge predicate, `Polymer → Polymer → Prop`),
`polymer_activity_finite_N` (the polymer activity functional
`ζ(β, N, γ)` built honestly from `Weyl_sum_explicit_SU3_real`),
and `kotecky_preiss_criterion` (the strict-contraction
implication that closes the Mayer expansion under the
Kotecký-Preiss bound). Sorry count on this batch goes 8 → 11;
each new sorry is individually named, individually cited, and
individually scoped — refactor only, not progress. This sorry
(`Single_plaquette_bound_SU3`) is unchanged and stays gated
on the same `Polymer_activity_bound_real` surface as before. -/
theorem Single_plaquette_bound_SU3 (β : ℝ) (_hβ : 0 < β) :
    Character_expansion_plaquette β * SU3_Haar_measure_explicit ≤
      Real.exp (-(Casimir_SU3 * β)) := by
  sorry

/-! ============================================================
    Batch 19.1q — MayerScaffold (Brydges-Federbush typed gap)

    Refactor the monolithic "polymer convergence" surface above
    into three named typed holes. **Not progress on the math** —
    progress on the *scaffolding*: anyone discharging this gap
    now has three named obligations instead of one anonymous
    one, each individually citable, individually scopeable,
    individually defeatable.

    **Scope locked.** YM tower stays `Status: Open` per
    `docs/ROADMAP.md` § 2. The genuine Clay surfaces remain
    untouched:

      1. Brydges-Federbush convergence of the Mayer series
         (Mayer-Montroll + tree-graph + Kotecký-Preiss).
      2. UV continuum limit `a → 0` downstream of
         `MassGap_YM4_Clay`.

    The three new sorries below name pieces of (1) only.

    **Deviation from spec (honest).** The spec wrote
    `Mayer_graph (γ : Polymer) : SimpleGraph Plaquette := sorry`.
    Two issues: (a) `SimpleGraph` would require a new mathlib
    import (`Mathlib.Combinatorics.SimpleGraph.Basic`) for a
    structure that Kotecký-Preiss only uses through its edge
    predicate; (b) the Mayer graph of a polymer system is a
    single graph indexed by *all* polymers, not one graph per
    polymer. The honest shape is the edge predicate
    `Mayer_overlap : Polymer → Polymer → Prop` ("γ and γ'
    share a plaquette"), which is exactly what
    `kotecky_preiss_criterion` quantifies over. Naming is
    therefore `Mayer_overlap`, not `Mayer_graph`.

    **Placeholder vs sorry.** `Plaquette`, `Polymer`, and
    `Converges_Mayer_expansion` are placeholder type/Prop
    aliases (NOT sorries — just the minimum structural stubs
    needed so the three named gaps typecheck against the
    existing repo). Promoting them to real definitions (a
    lattice site type, a finite-support polymer activity, the
    actual Mayer-Montroll convergence statement) is downstream
    work that does NOT live in 19.1q.

    No new BRICKS. No YM/ changes. Wall stays 443.
============================================================ -/

/-! **19.1r update.** The 19.1q placeholder `def`s for
`Plaquette`, `Polymer`, and the sorry-bearing `Mayer_overlap`
have been promoted into `Towers/YM/ClusterExpansion.lean`,
where the latter is now a real concrete definition (the
existential `∃ p, p ∈ γ₁ ∧ p ∈ γ₂`) rather than a typed
sorry. They are visible here unchanged via the existing
`open TheoremaAureum.Towers.YM.ClusterExpansion` on line 57.
The two remaining 19.1q sorries below (`polymer_activity_finite_N`
and `kotecky_preiss_criterion`) are untouched and still
gate the Brydges-Federbush surface. Attempts/ sorry count:
11 → 10. YM tower stays `Status: Open`. -/

/-- **Polymer activity functional `ζ(β, N, γ)`** at the
finite-N Peter-Weyl truncation. Real surface:
`ζ(β, γ) = e^{-β · |γ|} · ∏_{p ∈ γ} Z_p(β)`,
where `Z_p(β) = ∫_{SU(3)} e^{-β Re tr U_p} dU_p` is the
single-plaquette partition function (Glimm-Jaffe Eq. 20.3.5).
The 19.1o `Weyl_sum_explicit_SU3_real` is the honest finite-N
truncation of `Z_p(β)` via the Peter-Weyl heat-kernel
expansion. The full activity then bundles `e^{-β|γ|}` (cardinality-
suppression factor) with the product of single-plaquette
truncated partition functions.

**Why sorry, not the literal `Real.exp (-(β * γ.card)) *
Weyl_sum_explicit_SU3_real (γ.card / β) N` expression?** Because
the "product over plaquettes" of single-plaquette truncated
partition functions is *not* the same as
`Weyl_sum_explicit_SU3_real` of any single argument — it is a
`Finset.prod` over `γ`, each factor itself a truncated sum.
Writing that honestly requires lifting `Weyl_sum_explicit_SU3_real`
through `Finset.prod`, which is downstream work (and where the
Mayer combinatorics start to bite). Marked `sorry` so the
definitional surface is not silently understated. -/
noncomputable def polymer_activity_finite_N
    (_β : ℝ) (_N : ℕ) (_γ : Polymer) : ℝ := by
  sorry

/-- **Mayer-expansion convergence Prop.** Placeholder `Prop`
slot consumed by `kotecky_preiss_criterion`. Real surface: the
absolute convergence statement `Σ_γ |ζ(β, N, γ)| < ∞` on the
infinite-volume polymer set, plus the cluster-expansion identity
`log Z = Σ_X φ_T(X) · ∏_{γ ∈ X} ζ(γ)` with Ursell coefficients
`φ_T` (Glimm-Jaffe Eq. 20.4.1). Placeholder `:= True` so the
implication body typechecks without committing to the real
statement; the *substance* lives in `kotecky_preiss_criterion`. -/
def Converges_Mayer_expansion (_β : ℝ) (_N : ℕ) : Prop := True

/-- **Kotecký-Preiss strict-contraction criterion (typed gap).**
Real surface: the implication
`(∀ γ₀, Σ_{γ : Mayer_overlap γ₀ γ} |ζ(β, N, γ)| · e^{|γ|} ≤ |γ₀|)`
`→ Mayer expansion converges absolutely`,
i.e. the statement that a uniform Kotecký-Preiss bound on the
weighted activity sum implies absolute convergence of the
Mayer-Montroll series.

The hypothesis here is a *placeholder simplification*: the real
KP hypothesis is the `∀ γ₀, Σ_{γ overlaps γ₀} ...` quantified
form, not the unquantified `True` we admit below. The `sorry`
flags that the real implication is 40+ pages of Brydges-Federbush
combinatorics (tree-graph inequality, Ursell coefficient bounds,
absolute convergence of the cluster expansion), not a tactic
shortcut. Classical-trio-clean *in principle* once mathlib has
the supporting infinite-sum infrastructure (`Summable` /
`HasSum` / `tsum` on weighted polymer sets).

**Reference:** Kotecký & Preiss 1986, *Cluster expansion for
abstract polymer models*, Comm. Math. Phys. 103 (1986) 491-498
(the original 7-page paper); modern textbook treatment in
Friedli-Velenik 2018 *Statistical Mechanics of Lattice Systems*
Chapter 5. **Estimated formalisation cost:** 6-12 months,
2000+ lines, with the bulk going to the supporting
infinite-sum + tree-graph mathlib infrastructure rather than
the KP argument itself (which is short once the substrate
exists).

**19.1r dependency status.** `Mayer_overlap` is now defined
concretely in `Towers/YM/ClusterExpansion.lean` (the 19.1q
sorry is discharged with the standard `∃ p, p ∈ γ₁ ∧ p ∈ γ₂`
edge predicate). Remaining named gaps blocking this
implication: `polymer_activity_finite_N` (the activity
functional itself, sorry above) and the absolute-convergence
proof on weighted polymer sums. -/
theorem kotecky_preiss_criterion (β : ℝ) (N : ℕ) (_γ₀ : Polymer) :
    True → Converges_Mayer_expansion β N := by
  sorry

end ClusterExpansion
end Attempts
end Towers
end TheoremaAureum
