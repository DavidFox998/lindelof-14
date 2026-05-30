# Morning Star Project · Theorema Aureum 143 (Volume I)

**Full history → `docs/CHANGELOG.md`** (per-batch wall-jump tables, tactic
notes, proof sketches, drift footnotes, env vars, stack, where-things-live,
gotchas). `replit.md` is the live-ops doc; the CHANGELOG is the version
history. Roadmap → `docs/ROADMAP.md`.

## Current status — 2026-05-30

- **NS Tower 540 — honest weak→strong chain, Phases 1–6 COMPLETE, FROZEN at the
  Clay boundary (Status: Open).** NONE are bricks / in BRICKS / lakefile roots;
  all classical-trio, no `sorryAx` EXCEPT one isolated documented `sorry`
  `leray_proj_ker_eq_grad` in `Leray.lean` (not a brick, not in the weak→strong
  chain). Fourier-side model on `Hdiv_free (s+2)`, `ν = 1`; files P1
  `FunctionSpaces` · P2 `Leray`+`Stokes` · P3 `Energy` · P4 `GalerkinApprox`+
  `Compactness` · P5 `WeakSolution` · P6 `Regularity`. Full per-phase detail →
  `docs/CHANGELOG.md` + `docs/ROADMAP.md`. The two Clay surfaces stay OPEN:
  - **Surface #1 — global regularity: OPEN.** `global_smooth_exists : Prop` is
    the single NAMED Clay surface behind `weak_implies_strong` (unproved
    hypothesis, NOT `by sorry`; `#print axioms` = classical trio).
  - **Surface #2 — weak existence: OPEN (modeled).** `weak_solution_exists` is
    an HONEST COMBINATOR over the MODELED `WeakNS` surrogate (linear weak form;
    nonlinear `(u·∇)u` DROPPED) — NOT a literal Leray–Hopf existence theorem.
  FROZEN milestone `NS-540-phase6-clay-boundary` @ checkpoint
  `c5f29fb4390e5dda83ffdbfcae5dea2333cf5c12`. HONEST: these build spaces,
  name/bound operators, and assemble combinators from NAMED inputs; they prove
  NO NS existence/uniqueness/regularity. NS stays `Status: Open`; YM untouched.

- **Wall:** BRICKS array in `scripts/check-towers.sh` (`${#BRICKS[@]}`) is the
  source of truth for the count, not this file.
- **YM wall series (Wall251b–Wall263, Wall262a, S4Numerics, WilsonPositivitySU2,
  EntropyBound, RiemannianGeometry) — all bricks, in BRICKS; full prose →
  `docs/CHANGELOG.md`.** Every entry is `sorry`-free, `#print axioms` = classical
  trio (verified live, raw `lean` v4.12.0, EXIT=0), and HONEST: each proves NO YM
  result, discharges NO open surface, makes NO mass-gap / μ>0 / Surface-#1 claim,
  and does NOT touch `kotecky_preiss_criterion`. One-line index (newest first):
  - **Wall262a_RatioModel** — standalone numeric MODEL of Theoria's R-series
    (invented H4 weights; `R(exp(−0.88)) ≤ 1743/2000`; `1743=3·7·83`,
    `2000=2⁴·5³`); Theoria's "λ_max(2I−M_H4)=φ" FALSE (=2cos(π/30)). Standalone
    leaf, OUT of the YM graph; does NOT discharge `Wall262.hR`.
  - **Wall263_CoxeterSpectral** — axiom-free REFUTATION of "λ_max(2I−M_H4)=φ"
    (`φ` is the label-5 EDGE WEIGHT, not a spectral value; true radius
    `2cos(π/30)≈1.989`). Conditional `defect_bound_H4` over NAMED OPEN hyps.
  - **Wall262_ConnectiveRatio** — conditional connective-ratio defect → SU(2)
    polymer-rate win (`R := μ_Z4/φ`; NAMED OPEN `hR`/`h_defect`/`h_rate`).
  - **Wall261_H4Defect** — conditional H4/120-cell defect improvement
    (`C = 1+φ = φ² ≈ 2.618`; NAMED OPEN `h_graph`).
  - **Wall260_ClayReduction** — pointwise defect-form Clay reduction
    (`C=6` combinatorics, `h_defect` analysis; NAMED OPEN).
  - **Wall259_DependenceBound** — dependence-defect reduction
    (`polymerRate := I_E − Defect`; NAMED OPEN `h_defect`/`h_rate`).
  - **Wall258_DependenceDefect** — inter-polymer dependence-defect combinator
    (ℤ⁴ link incidence `2(d−1)=6`; raised threshold `log(7·C)`).
  - **Wall257_RateLowerBound** — MODELED single-site rate (cgf `t²`) clearing
    `log 7`; Gap Lemma: single-site clearing ≠ polymer clearing.
  - **Wall256_RateFunction** — conditional large-deviation rate criterion
    (`log 7 < I ⟺ ∑ₙ 7ⁿe^{−In}` converges; NAMED OPEN `h_rate`).
  - **Wall255_JensenObstruction** — mean-energy NO-GO (Jensen ⟹ the MEAN can
    never give KP smallness; the open problem is the RATE, not the mean).
  - **Wall257_StrongCoupling** — conditional strong-coupling activity bound;
    PROVES the uniform energy floor is FALSE (the vacuum breaks it).
  - **Wall256_MassGapConditional** — conditional mass-gap apex shape from TWO
    NAMED OPEN surfaces (`ρ<1`, KP clustering); proves NO mass gap.
  - **Wall254_OS_Positivity** — conditional OS2 from the genuine Gram-PSD heart
    + NAMED OPEN GNS surface `hGNS`.
  - **Wall255_KP_Entropy** — conditional "beat the 7ⁿ entropy" (needs `q<1/7`,
    NAMED OPEN; Wall252's `<1/2` is not enough).
  - **Wall253_KP_Cluster** — conditional KP cluster expansion (genuine geometric
    layer; entropy DROPPED; NAMED OPEN `hKP`).
  - **Wall252_KP** — MODELED single-term KP smallness majorant `<1/2`.
  - **WilsonPositivitySU2 / Wall251b_H4** — SU(2) Wilson POINTWISE positivity
    (unitarity-only; NOT OS reflection positivity, NOT a mass gap).
  - **S4Numerics** — four standalone TRUE arithmetic facts (group-theoretically
    empty; no H4 Coxeter group constructed).
  - **EntropyBound (YM 249→250)** — conditional polymer entropy bound
    `#{size-n connected polymers} ≤ 7ⁿ` via NAMED OPEN `h_entropy`.
  - **RiemannianGeometry** — SU(3) chordal distance is a genuine metric (the
    CHORDAL metric, NOT the Killing-form geodesic distance).
- **Axiom debt:** `[]` on `TheoremaAureum.main_theorem` (also `[]` on
  `H2_WeilTransfer`, `M9_WeilTransfer_All`). Every landed brick is
  classical-trio-only.
- **Mathlib:** v4.12.0 only.
- **YM Surface #1: OPEN.** No `m > 0` claim while the `sorry` stands.
- **Wall 574 `[YM1]`** (`Towers/YM/MassGap574.lean`) elaborates against the
  real Step-4/5 `H` / `spectrum_bound` and carries `(hpos : 0 < wilsonAction U)`,
  but still carries a `sorry`; INVARIANT-LOCKED, NOT in BRICKS, not a lakefile
  root. The companion `YM_mass_gap_nontrivial` discharges `hpos` for
  non-trivial `U` and is `sorry`-free, but `H = wilsonAction U • 𝟙` is the
  scalar shadow, NOT the real Wilson transfer operator — so no mass-gap claim.
- **Registered YM walls** (tagged files, lake-gated `[YM1-*]`, NOT in BRICKS):
  571-B `[YM1-LB-Core]` (`lattice_positivity`, axioms `[]`), 572 `[YM1-LB-Real]`
  (`hamiltonian_pos`), 573 `[YM1-GR]` (`gap_reduction`), 575 `[YM1-SB]`
  (`spectrum_bound` + `spectrum_bound_H_iff`). All classical trio.
- **Deferred:** 24 OS/KP modules unregistered (Task #208); `.lean` files kept
  on disk, await Wall 570+/574 with the real SU(3) `H`.
- **Infra:** mathlib cache self-heal landed (`scripts/fetch-mathlib-oleans.sh`:
  authoritative `lake exe cache get`, no from-source fallback).
- **YM Transfer / polymer / positivity / measure scaffolding (NONE bricks, none
  in BRICKS; all classical-trio, verified live; full detail →
  `docs/CHANGELOG.md`).** Real SU(3) Haar stack (`SU3Instances.lean`: `haarSU3`,
  product `haarN`, probability instances); the real integral transfer operator
  `T_L` with the genuine sub-Markov contraction `‖T_L‖ ≤ 1` (`Transfer.lean` —
  explicitly NOT strict / decay / spectral-gap; `S_min := inf_{U≠1} wilsonAction
  U = 0`); Wilson positivity (`WilsonPositivity.lean`: `wilsonAction_nonneg`,
  `wilsonAction_eq_zero_iff` = all-plaquettes-trivial, NOT `U = 1`); and the
  cluster-expansion `polymerActivity` (nonneg, antitone, empty `= 1`, DCT
  reduction `polymerActivity_tendsto_zero_of_null`). Every lemma is
  necessary-not-sufficient: pointwise positivity / single-polymer `β→∞` decay is
  NOT the mass gap. The OPPOSITE spectral lower bound stays OPEN in the
  disclaimed `sorry` `Transfer.kotecky_preiss_criterion` (downstream of one
  unproved cluster-entropy / Peierls counting bound
  `#{γ : |γ|=n, energy<ε} ≤ Cⁿ·ε^{α·n}`), distinct from the invariant-locked
  `Towers/Attempts/ClusterExpansion.lean` `sorry`. NO `m>0` / μ>0 / mass-gap /
  Surface-#1 claim; Surface #1 stays OPEN.

## Locked invariants (every batch must hold these)

- Axiom footprint = classical trio `{propext, Classical.choice, Quot.sound}`;
  no new research-grade axioms.
- Mathlib v4.12.0 only; no `sorry` / `admit` / `sorryAx` in any landed brick.
- YM and NS towers stay `Status: Open` in `docs/ROADMAP.md`; Surface #1 and
  Surface #2 stay OPEN. "Surface #1 CLOSED" / "μ > 0" / "removes the Attempts
  sorry" / "Mass Gap proven" claims are REFUSED — every YM Measure-surface
  brick is trivially or vacuously true under the Dirac haar stand-in
  (`T_OS = 0` / `T_real = 0`), NOT under any real Wilson transfer operator.
- `kotecky_preiss_criterion` remains a `sorry` in
  `Towers/Attempts/ClusterExpansion.lean` (invariant-locked).
- **NS FREEZE.** `Towers/NS/*` is FROZEN at the Clay boundary (milestone
  `NS-540-phase6-clay-boundary`). NO further commits to `Towers/NS/` without an
  explicit unfreeze order from the user. Surface #1 (`global_smooth_exists`) and
  Surface #2 (modeled `weak_solution_exists`) stay OPEN; "NS solved" /
  "regularity proven" / "weak solutions exist (literally)" claims are REFUSED.
- **Infra (in progress).** Disabling the `towers-build` auto-run and permanently
  locking the mathlib `v4.12.0` pin is tracked as a background Project Task
  (#294); until it lands, every boot/merge can still wipe the pin and require
  the manual recovery in "Operational gotchas".

## Operational gotchas

- **Git-tag creation is restricted for the main agent.** `git tag` (and other
  git writes) are blocked with "Destructive git operations are not allowed in
  the main agent" — they must go through a background Project Task. This repo's
  working convention is therefore to track milestones as **prose + SHA** in
  `replit.md` / `docs/ROADMAP.md` / `docs/CHANGELOG.md` (e.g. "YM frozen at
  `c8f6a7ed`", "milestone `NS-540-phase2b-stokes` @ checkpoint `f4becd5`"),
  NOT as literal git refs. Replit checkpoints already capture the merged state.
- **Do NOT run `towers-build` / `lake update` casually.** Both re-clone the
  vendored mathlib checkout and wipe its oleans, requiring a `lake-recovery`
  (`lake exe cache get`) pass. Verify bricks via direct `lake env lean <file>`
  + `#print axioms` — **but `lake env` is ALSO destructive when the
  `v4.12.0` tag is missing.** `lake env` re-resolves `inputRev: v4.12.0` from
  the mathlib git; if the tag does not resolve it fetches from remote and wipes
  the oleans, exactly like `lake update` (confirmed 2026-05-30). So BEFORE any
  `lake env lean`, assert `git -C lean-proof-towers/.lake/packages/mathlib
  rev-parse v4.12.0` succeeds. Recovery if wiped: `scripts/restore-lake-git.sh`
  (run it TWICE — first run restores `.git` at the pinned rev, second run
  rehydrates the empty worktree via its `git checkout -- .` heal), then recreate
  the tag (`git -C lean-proof-towers/.lake/packages/mathlib tag -f v4.12.0
  809c3fb3b5c8f5d7dace56e200b426187516535a`), then run
  `scripts/fetch-mathlib-oleans.sh` to re-download the oleans.
- The destructive mathlib re-clone is triggered when the restore-tar's vendored
  mathlib `.git` lacks the `v4.12.0` tag (lake fetches from remote to resolve
  `inputRev: v4.12.0`). Fix: recreate the tag locally after any
  `restore-lake-git.sh` worktree rebuild —
  `git -C .lake/packages/mathlib tag v4.12.0 <HEAD>` (manifest `rev` already =
  HEAD). It is NOT persisted in the restore tar.

## User preferences

- Ship clean: no `sorryAx`, no `sorry` / `admit` in any landed/registered brick.
- Be honest about scope — never overstate a placeholder/stand-in as a real
  result (no false "mass gap proven" / "Surface #1 closed" claims).

## theorema-certs dashboard

Web artifact (`artifacts/theorema-certs`) — the certificate-ledger dashboard.
Has e2e Playwright specs under `tests/e2e/`. Run a spec with:
`PLAYWRIGHT_MANAGED_WEB_SERVER=1 pnpm --filter @workspace/theorema-certs exec playwright test <name>`.
