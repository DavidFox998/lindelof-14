# CLAY-GRADE REPAIR OF 13 WITNESS-COLLAPSE BRICKS

**Date:** 2026-06-03
**Author:** D. Fox (ORCID 0009-0008-1290-6105)
**Scope:** `lean-proof-towers/Towers/YM/` — OS namespace (`TheoremaAureum.Towers.YM.OS`)
**Mathlib:** v4.12.0 (pinned)
**Cardinal rule:** honesty-locked — no fabrication/overstatement; no
`sorry`/`sorryAx`/`admit`/research-axiom proof-terms; axiom footprint = the
classical trio `{propext, Classical.choice, Quot.sound}`.

---

## 1. Directive

For each of 13 bricks whose "proof" was discharged only by a **degenerate
witness** (constant-zero correlator, the zero CLM, a reflexive definitional
re-wrap, etc. — a *witness collapse*), attempt a **non-vacuous** proof: a real
transfer / spectral object with a genuine `T_real > 0` lower bound. If — and
only if — the non-vacuous proof is **unreachable** under Clay rules in mathlib
v4.12.0, convert the vacuous lemma/theorem into a **named open `Prop`** that
states the proposition (without proving it) and **de-register** the brick from
`scripts/check-towers.sh`.

## 2. Outcome (honest)

**All 13 were judged unreachable; all 13 were converted to named open `Prop`s
and de-registered. ZERO non-vacuous proofs were achieved.**

Each former brick "proved" its target only because both the antecedent and the
consequent were instantiated at a **degenerate witness**:

- correlator / clustering function `≡ 0` (so `|f| ≤ exp` holds with the
  hypothesis unused);
- mass-gap operator `T := 0` on `H := ℂ` (so `⟪x, Tx⟫.re = 0 ≥ (1-m)·‖x‖²`
  collapses to `0 ≥ negative`);
- `integrated_tail L m := rexp(-m·L)` so a "tail bound" is the reflexive
  `rexp(-m·L) ≤ rexp(-m·L)`;
- `transferGapBound` unfolds to the same inequality, making a "tail ⇒ transfer"
  step a pure definitional re-wrap.

In every case the genuine Yang–Mills surface — a **real** correlator that
clusters, a **real** Wilson transfer operator with a strictly positive spectral
gap `T_real > 0` — requires SU(3) character theory / a real heat-kernel
transfer operator that is **absent from mathlib v4.12.0**. No `T_real > 0` is
constructible; the collapse is therefore not a bug to patch but a hard wall.

### What the converted `_OPEN` defs are (and are NOT)

Each `def <name>_OPEN : Prop := <fully-closed ∀/∃ statement>` **names the
as-written proposition** for the record. **It is honest about being weak:** as
written, with the degenerate witnesses still available, each `_OPEN`
proposition is itself **trivially satisfiable**. The conversion therefore does
**NOT** assert the genuine surface; it removes a vacuous *theorem* (which the
brick gate would otherwise advertise as a landed result) and replaces it with a
*named, unproven proposition* carrying a CLAY OPEN honesty header. `T_real`
lower bound recorded for all 13: **none**.

**No claim is made of:** YM mass gap, `μ > 0`, Surface #1 closed, "removes the
Attempts sorry", or any real spectral-gap / clustering result. Surface #1 stays
OPEN.

## 3. Method & verification

- **In-place conversion** (no physical file move): the vacuous
  `theorem`/`lemma` proof-term was replaced by `def <name>_OPEN : Prop := …`;
  all supporting `def`s (`clusters`, `hasMassGapLowerBound`, `HasMassGap`,
  `transferGapBound`, `hasExponentialClustering`, `integrated_tail`) and all
  imports were **preserved** so downstream references do not break.
- **De-registration:** the 13 brick entries in `scripts/check-towers.sh` were
  replaced by `# CLAY_OPEN 2026-06-03: …` comment lines (one per former brick,
  each pointing here). The `TransferOperator` / `ShiftOperator` /
  `NontrivialGap` entries were left intact.
- **Verification was by direct-lean, NOT lake.** The vendored mathlib
  `v4.12.0` tag is unresolved, so any `lake env` invocation would re-fetch from
  remote and wipe the oleans (a known destructive trap in this repo). Each file
  was instead compiled with a hand-built `LEAN_PATH` over the existing oleans
  (`.lake/build/lib` + each `.lake/packages/*/.lake/build/lib`) and a direct
  `lean <file>` invocation. Axioms were checked by appending
  `#print axioms TheoremaAureum.Towers.YM.OS.<name>_OPEN` to a `/tmp` copy.
- **Result: all 13 compile EXIT 0; all 13 print exactly
  `[propext, Classical.choice, Quot.sound]`** — the locked classical trio. No
  `sorry`, no `sorryAx`, no research-grade axiom.

## 4. The 13 modules

| # | File | Former brick | Named open `Prop` | SHA-256 (file) | EXIT | Axioms |
|---|---|---|---|---|---|---|
| 1 | `ClusteringCore.lean` | `clusters_zero` | `clusters_zero_OPEN.{u}` | `f3ceecd3…a1fb` | 0 | trio |
| 2 | `MassGapStandin.lean` | `massGap_standin_example` | `massGap_standin_example_OPEN` | `ffa6f582…ee5d` | 0 | trio |
| 3 | `SpectralGapCore.lean` | `hasMassGap_zero` | `hasMassGap_zero_OPEN` | `fca1de2b…ee69e89` | 0 | trio |
| 4 | `TransferOperatorBound.lean` | `transfer_gap_zero` | `transfer_gap_zero_OPEN` | `ff0bb488…295c` | 0 | trio |
| 5 | `TwoPointDecay.lean` | `clustering_zero_from_transfer` | `clustering_zero_from_transfer_OPEN` | `516b8fb7…4575` | 0 | trio |
| 6 | `MassGapFromDecay.lean` | `mass_gap_from_clustering_zero` | `mass_gap_from_clustering_zero_OPEN` | `b5acbbc0…aa3b` | 0 | trio |
| 7 | `IntegratedTailReal.lean` | `integrated_tail_le_exp` | `integrated_tail_le_exp_OPEN` | `223a0dac…8ca2` | 0 | trio |
| 8 | `TransferGapReal.lean` | `transfer_gap_real` | `transfer_gap_real_OPEN` | `bd30cd0f…4ebe` | 0 | trio |
| 9 | `MassGapReal.lean` | `mass_gap_from_transfer` | `mass_gap_from_transfer_OPEN` | `30f0b1b3…1fb0` | 0 | trio |
| 10 | `ClusteringImpliesGap.lean` | `clustering_implies_gap` | `clustering_implies_gap_OPEN` | `acc57309…1626` | 0 | trio |
| 11 | `TransferImpliesClustering.lean` | `transfer_implies_clustering` | `transfer_implies_clustering_OPEN` | `3e502bac…7301` | 0 | trio |
| 12 | `TailImpliesTransfer.lean` | `tail_implies_transfer` | `tail_implies_transfer_OPEN` | `e0d3ba5d…bd50` | 0 | trio |
| 13 | `GapToDecay.lean` | `gap_to_decay` | `gap_to_decay_OPEN.{u}` | `ff4b8f5d…5dbe` | 0 | trio |

`trio = {propext, Classical.choice, Quot.sound}`. Two defs
(`clusters_zero_OPEN`, `gap_to_decay_OPEN`) carry an explicit universe
parameter `.{u}` because their `∀ {α/H : Type u}` quantifier introduces a
universe that must be bound on a `: Prop` declaration (a bare `Type*` there
fails to elaborate — the universe does not occur in the `Prop` type).

## 5. Deviations from the literal directive

1. **lake → direct-lean verification.** `lake`/`lake env` are destructive while
   the `v4.12.0` tag is unresolved (see §3). Verification used the documented
   direct-lean bypass over the intact oleans.
2. **No physical file move / no rename of the module.** Conversion is
   **in-place** to preserve imports and the supporting `def`s. Only the vacuous
   proof-term became an `_OPEN` `Prop`.
3. **`def` keyword, not `theorem`.** A named open proposition is a `Prop`-valued
   `def`, matching this repo's existing `*_Surface : Prop` open-surface pattern;
   it is **not** a `theorem … := by sorry` (which would print `sorryAx` and fail
   the lock).
4. **Literal grep gate is not the honesty signal.** The strings `axiom` /
   `sorry` appear in every CLAY OPEN docstring, so a naive grep is meaningless;
   the real gate is **proof-term + `#print axioms`** (EXIT 0, trio only), which
   all 13 pass.
5. **`"axioms": []` in the manifest = zero *research* axioms.** Each `_OPEN`
   `Prop` references mathlib (`Measure`, `inner`, `Real.exp`) which pulls the
   classical trio, so the literal printed footprint is the trio, **not** the
   empty list. Per this repo's manifest convention ("axioms=0" ⇔ "classical-trio
   only"), the manifest records `"axioms": []` meaning *no axiom beyond the
   locked trio*, with explicit `"classical_trio"`, `"sorry": 0`,
   `"sorryAx": 0` fields. Honesty overrides the literal `[]`.
6. **The `_OPEN` propositions are disclosed as trivially-true as written**
   (§2). The conversion is logical hygiene (remove a vacuous landed *theorem*);
   it does **not** manufacture or assert the genuine surface.

## 6. Invariants held

- Axiom footprint = classical trio on all 13; no new research-grade axiom.
- `sorry` / `sorryAx` / `admit` proof-terms: **0**.
- Mathlib v4.12.0 only; no `lake update` / `lake env` run (oleans intact).
- YM Surface #1 stays **OPEN**; no mass-gap / `μ > 0` / Surface-#1-closed claim.
- NS tower untouched (still frozen).

See `provenance/clay_repair.diff` for the full unified diff and
`CLAY_STATUS.md` / `BUILD_MANIFEST_v2.7.json` for the machine-readable status.
