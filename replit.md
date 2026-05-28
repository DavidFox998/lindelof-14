# Morning Star Project · Theorema Aureum 143 (Volume I)

Publisher: **Morning Star Project (independent research)**
License: **All rights reserved (license pending review)**

Volume I: **Theorema Aureum 143 — Certificate Ledger**, plus the
MorningStar-Lab CLI surface for probing L-functions against a
Genesis-sealed append-only ledger.

For the version history and full design notes of v1.0 → v1.9 Stage 2A-Prime
(seven-layer surface, Three Guns CLI, sign-change sieve, etc.) see
`docs/CHANGELOG.md`. For a 3-command reproducibility recipe see
`docs/REPRODUCE.md`. For the full architecture write-up see
`docs/MorningStar_Architecture.pdf`.

## Single source of truth — before you edit anything

`scripts/print-direction.sh` and `data/THEOREMA_AUREUM_143.manifest.txt`
are the canonical "who/what/where" surface. They print the project
name, publisher, license, sealed-ledger path, Genesis seal, and
public-alias symlink. If anything in this README ever drifts from
those, the script and the manifest win — fix this file, not them.

**Rule: additive only — never edit sealed files.** That means
`data/hits.txt` (preamble lines 1–9 are Genesis-sealed),
`data/THEOREMA_AUREUM_143.manifest.txt`, `scripts/print-direction.sh`,
and the Lean spine in `lean-proof/` are not surfaces for casual edits.
Append new probes through `kernel.probe()` / the Three-Guns CLI; do
not hand-edit the ledger.

## Volume I — what this repo actually ships

**Theorema Aureum 143: A Formal Spine and Computational Ledger for RH.**

Three real, defensible deliverables:

1. **The Ledger** — `data/hits.txt`, a 20,964-line append-only DAG of
   L-function probes with a Genesis-sealed preamble (SHA
   `eecbcd9a…875f`). Tamper-evident, reproducible from a fresh
   checkout (`docs/REPRODUCE.md`). Publishable computational data.
2. **The Spine** — Lean 4 deductive chain
   `H1_ArakelovPositivity → H2_WeilTransfer → main_theorem` in
   `lean-proof/`, with `#print axioms TheoremaAureum.main_theorem`
   returning `[]`. That is a real formal theorem: *given* the
   Prop-level stubs declared in `Certificates.lean`, the spine closes
   without new axioms. It is **not** a formal proof of RH itself.
3. **The Infrastructure** — append-only ledger discipline, per-line
   SHA chain, Genesis-seal verifier, drift guard (`post-merge.sh` +
   `lean-proof` CI), and a single-source-of-truth banner
   (`scripts/print-direction.sh`). Real software, real reproducibility.

For the longer-term research direction — RH, Yang-Mills, Navier-Stokes,
the 280-curve cohort, Bost-Connes — see `docs/ROADMAP.md`. Those are
**Open**; this repo does not claim to have proved them.

## Run & operate

- `pnpm --filter @workspace/api-server run dev` — API server
- `pnpm run typecheck` — full typecheck
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regen API hooks + Zod from OpenAPI
- `pnpm --filter @workspace/db run push` — push DB schema (dev only)
- `python lab.py` — open the MorningStar-Lab REPL
- `python lab.py -c "zeta_sniper(1)"` — one-shot probe
- `bash scripts/validate-morningstar.sh` — full kernel→bridge→lake harness
- `bash scripts/print-direction.sh` — print the canonical "you are here" banner

## Environment

- Required: `DATABASE_URL` (Postgres)
- Required (auto-set by Replit): `DEFAULT_OBJECT_STORAGE_BUCKET_ID`, `PUBLIC_OBJECT_SEARCH_PATHS`, `PRIVATE_OBJECT_DIR`
- Optional: `LEAN_REBUILD_TOKEN` — shared rebuild token. Unset ⇒ rebuild endpoint returns 503. Callers send `Authorization: Bearer <token>`. Only one rebuild at a time (others 409). Referees may opt-in attribution via `X-Referee-Name` (`[A-Za-z0-9 _.-]{1,64}`).
- Optional: `LEAN_REBUILD_TOKENS` — comma-separated named tokens (`alice:tokA,bob:tokB`) for real per-referee attribution. Named tokens take precedence over the shared one; a matched named token wins over any `X-Referee-Name` header. At least one of the two must be set to enable rebuilds.
- Optional: `MORNINGSTAR_ALERT_WEBHOOK_URL` — POST-JSON sink fired by `kernel._fire_ledger_alert` when `_verify_checkpoint` raises mid-workflow (truncation or in-place rewrite) and by `scripts/check-ledger-integrity.py` on a hard FATAL. Best-effort; delivery failure logs to stderr but never masks the underlying `LedgerIntegrityError`. Unset means no alert (silent no-op). Task #63. Task #144: the api-server's watchdog (`checkWatchdog`, task #113) also rides this same sink when the auto-integrity check stalls (`failure_mode: "monitor_stalled"`) and again when ticks resume (`failure_mode: "recovered"`, `previous_failure_mode: "monitor_stalled"`). The webhook JSON now carries an explicit `subject` field — `"[MorningStar] Ledger MONITOR STALLED — push alerts may be silent: <workflow>"` for a stall, `"[MorningStar] Ledger monitor RECOVERED: <workflow>"` for the all-clear, and `"[MorningStar] Ledger integrity alert: <workflow>"` for the legacy tamper case — so Slack / PagerDuty routing can split watchdog signals from real tamper alerts without re-deriving from `failure_mode`.
- Optional: `MORNINGSTAR_ALERT_EMAIL_TO` + `MORNINGSTAR_ALERT_SMTP_HOST` (+ optional `MORNINGSTAR_ALERT_SMTP_PORT` default 25, `MORNINGSTAR_ALERT_EMAIL_FROM`, `MORNINGSTAR_ALERT_SMTP_USER`, `MORNINGSTAR_ALERT_SMTP_PASSWORD`) — plaintext SMTP sink for the same alert. Set alongside or instead of the webhook. Task #144: the Subject header mirrors the webhook `subject` field — distinct lines for `monitor_stalled` / `monitor_recovered` / tamper — and the body for watchdog signals carries `stall_age_seconds` / `stall_threshold_seconds` / `monitor_interval_seconds` / `last_tick_at` instead of the tamper `expected_size` / `actual_size` / `expected_sha` columns, with a "do NOT restore hits.txt — investigate the api-server process" pointer in place of the tamper-recovery doc link.
- Optional: `MORNINGSTAR_ALERT_TIMEOUT_SECONDS` — per-transport delivery timeout in seconds for the webhook and SMTP alert paths (default 5). Bad / non-positive values fall back to the default. Task #82.
- Optional: `MORNINGSTAR_ALERTS_MAX_BYTES` — byte cap before `data/ledger-alerts.jsonl` is rotated to `ledger-alerts.jsonl.1` (with `.1 → .2`, etc.). Default `5242880` (5 MB). Bad / non-positive values fall back to the default. Task #105.
- Optional: `MORNINGSTAR_ALERTS_MAX_ROTATIONS` — how many rotated copies (`.1`, `.2`, …) to keep before the oldest is deleted. Default `3`. The dashboard endpoint `/api/lean/ledger-alerts` only reads the live file; rotated copies are archival.
- Optional: `LEDGER_SIDECAR_SECRET` — inline 64-char hex (32 bytes) HMAC secret for the `data/hits.txt.lastok` sidecar. When set, the secret is held in memory only and no keyfile is written to disk — the recommended deploy posture, since it removes the "attacker who can read the data dir can forge MACs" failure mode entirely. Malformed values are ignored with a warning and the server falls through to the on-disk keyfile.
- Optional: `LEDGER_SIDECAR_SECRET_PATH` — relocate the on-disk HMAC keyfile out of the data dir onto a tighter-ACL mount (e.g. a secrets volume). Defaults to `${lastOkPath}.key` (i.e. `data/hits.txt.lastok.key`). Ignored when `LEDGER_SIDECAR_SECRET` is set. On startup the server stats the keyfile; if it is group- or world-readable, a loud `WARN` is logged with the exact octal mode and remediation steps (`chmod 600`, relocate, or switch to env-only). Loose mode is a warning, not a hard fail — the server still boots. Task #109.
- Optional: `LEDGER_SIDECAR_SECRET_STRICT_MODE` — when truthy (`1`, `true`, `yes`, `on`, case-insensitive), promotes the Task #109 loose-keyfile WARN to a hard startup failure (`SidecarSecretLooseModeError`). The API server refuses to boot until the operator either `chmod 600`s the keyfile, relocates it via `LEDGER_SIDECAR_SECRET_PATH` to a tighter-ACL mount, or supplies `LEDGER_SIDECAR_SECRET` inline (env-only, no on-disk fallback). Defaults to off (lenient warn — backward compatible). Recommended for hardened production deploys where a loose-mode keyfile shipping into production would otherwise be lost in log noise. Task #123. The runtime posture is surfaced on the Ledger Integrity dashboard card as a small "Strict keyfile mode: ON / OFF" badge (`sidecarSecretStrictMode` on `GET /api/ledger/integrity`), sourced from the same env parser used at boot so the badge cannot drift from the actual posture. Task #137.
- Optional: `LEDGER_CHECKPOINT_STALE_THRESHOLD_SECONDS` — age in seconds beyond which `data/hits.txt.checkpoint` (the committed known-good prefix) is flagged as stale on `/api/ledger/integrity` (`checkpointStale: true`). Default `2592000` (30 days). Distinct from `LEDGER_STALE_THRESHOLD_SECONDS` (which flags the verifier loop, not the sidecar). The dashboard surfaces the two warnings separately so operators don't confuse "nobody has verified the ledger lately" with "the sealed prefix is far behind the live file and tamper coverage is shrinking". Task #96.
- Optional: `MORNINGSTAR_WORKFLOW_NAME` — friendly tag (`zeta-burst-101-10000`, `zeta-sieve-14159-100000`, …) included in the alert payload so the operator can tell which long-running probe halted. Falls back to `argv[0]` / hostname.

### Brute-force lockout

Per-IP limiter on `/api/lean/verify/rebuild`: 5 bad-token attempts / 15
min ⇒ 15 min lockout (`failuresByIp` in
`artifacts/api-server/src/routes/lean.ts`). Same limiter applies to
`/api/lean/lockouts` and `/api/lean/lockouts/clear` — admin endpoints
don't bypass it.

Dashboard surface: the **Lean 4 Verification** card has a "Brute-force
lockouts" panel (`panel-lean-lockouts`) once a referee token is set,
polling `/api/lean/lockouts` every 15s. Active lockouts shown in red,
pre-lockout failing IPs in amber, each with a Clear button.
In-memory only — resets on server restart, no email/webhook out of
the box.

## Stack

- pnpm workspaces, Node 24, TypeScript 5.9
- API: Express 5, PostgreSQL + Drizzle ORM, Zod (`zod/v4`), Orval codegen
- Frontend: React + Vite, Tailwind, shadcn/ui, wouter, TanStack Query
- File storage: Replit Object Storage (presigned PUT)
- Kernel: Python 3, mpmath (arbitrary precision), Lean 4 (`leanprover/lean4:v4.12.0`) + mathlib v4.12.0

## Where things live

- `scripts/print-direction.sh` — single source of truth for project name, publisher, license, paths
- `data/THEOREMA_AUREUM_143.manifest.txt` — public manifest (unsealed, regeneratable) that mirrors the above
- `data/hits.txt` — **canonical** Genesis-sealed append-only probe ledger (preamble lines 1–9 sealed against SHA `eecbcd9a…875f`)
- `data/theorema-aureum-143-hits.txt` — public symlink alias for `data/hits.txt` (byte-identical; do not treat as a separate file)
- `data/CASUALTY_LOG.md`, `data/M13_CERT.txt` — incident log + M13 certificate header
- `lib/api-spec/openapi.yaml` — API contract (source of truth)
- `lib/db/src/schema/certificates.ts` — Drizzle schema
- `artifacts/api-server/src/routes/{certificates,storage,lean}.ts` — routes
- `artifacts/theorema-certs/src/` — React frontend (dashboard, certificate list/detail, walkthrough, Miegakure 600-cell viewer)
- `kernel.py`, `lab.py`, `lean_bridge.py` — MorningStar-Lab CLI surface
- `lean-proof/` — Lean 4 project (axiom debt = [], drift-guarded)
- `scripts/check-genesis-seal.py`, `scripts/check-lean-proof.sh`, `scripts/validate-morningstar.sh`, `scripts/post-merge.sh`
- `tests/test_kernel.py`, `tests/test_morningstar.py`
- `docs/MorningStar_Architecture.{tex,pdf}`, `docs/SiteMap.md`, `docs/ProofIndex.md`, `docs/CHANGELOG.md`, `docs/REPRODUCE.md`, `docs/ROADMAP.md`

## Architecture (one-liners)

- Certificates in PostgreSQL; SHA hashes, parent SHAs (JSON string), Lean theorem names are first-class columns.
- PDF upload = presigned-URL PUT to GCS, then PATCH `pdfObjectPath`.
- Master manifest SHA (M7) is hardcoded in the summary endpoint.
- Ledger preamble (lines 1–9 of `data/hits.txt`) is sealed; SHA-256 must match `eecbcd9a…875f` before any append.
- Lean `main_theorem` axiom debt = [] is re-verified on every merge by `scripts/post-merge.sh` and in CI by the `lean-proof` workflow (`STRICT_LEAN_CHECK=1`).

## Tests / validations

- `kernel-numerics` workflow — `pytest tests/test_kernel.py` (mpmath backend numerics + Three-Guns invariants + sieve dry-run)
- `morningstar-tamper` workflow — `pytest tests/test_morningstar.py` (Genesis-seal tamper-evidence; also invoked from `post-merge.sh`)
- `lean-proof` workflow — strict-mode `check-lean-proof.sh`; fails closed if `lake` missing

## Honest-scope guards

- `hit_437` / `hit_1094` are tautologies (`True := trivial`). Their *names* reference the OpenCV cube counts; their *statements* claim nothing about number theory.
- `probe()` and friends never call SageMath. Out-of-scope inputs are recorded with `NEEDS_SAGE` and a `reason=` field, never silently stubbed.
- `elliptic_stub` writes a SHA-stamped intent line tagged `ELLIPTIC_STUB`; the returned dict has no `L_*` keys. `test_kernel.py` pins this.
- `zeta_sieve` is a parallelised sign-change sieve, **not** the Odlyzko-Schönhage 1991 FFT. The docstring says so.
### YM / NS Lean schema — Path B Tower Bricks (current state)

All bricks below pass `scripts/check-towers.sh` with axiom footprint
= `{propext, Classical.choice, Quot.sound}` (mathlib's classical
trio — no research-grade axioms). All schemas are honest stand-ins
for the Clay surfaces; **YM and NS towers stay `Status: Open` in
`docs/ROADMAP.md`**. The schemas are NOT the YM action / Wilson
plaquette / `F_μν` / mass-gap, NOT the Sobolev H¹ norm / Leray–Hopf
solution. For per-batch prose and tactic notes see
`docs/CHANGELOG.md`.

**Current wall: 488 BRICKS** (script-reported by `scripts/check-towers.sh`).
Last verified build: `towers-build` workflow, 2026-05-28 (Batch 163 /
TRI PARALLEL #3) — 488 brick(s) passed the axiom-footprint check.

| Date | Task / Batch | Δ Wall | Headline (full prose in `docs/CHANGELOG.md`) |
|---|---|---|---|
| 2026-05-26 | #51 / #55 / #56 — Path B 1–6 | 19 → 81 | YM / NS schemas, Gell-Mann basis, gauge-field stand-in |
| 2026-05-26 | #56 — Path B 7 (3 tracks) | 81 → 96 | Geometry / NS.Energy / Spectral.Operator |
| 2026-05-27 | #154 / Batch 19.1p-redux-a | 452 → 456 | `Towers/YM/PeterWeyl.lean` (SU(3) Peter-Weyl Summability) |
| 2026-05-27 | #155 / Batch 19.1p-redux-b | 456 → 460 | `Towers/YM/PeterWeylHeat.lean` (truncated PW ≤ heat-kernel envelope) |
| 2026-05-27 | Batch 20.1a / Plan #156 | 460 → 464 | `Towers/YM/Continuum.lean` + parked `Attempts/Clay.lean` (no new theorems) |
| 2026-05-27 | Batch 20.2a / Task #156 file 1 of 6 | 464 → 465 | `Towers/YM/Casimir.lean` — `Casimir_SU3_explicit_real_ge_quadratic` (Varadhan scaffolding) |
| 2026-05-27 | Batch 156.2 / Task #156 file 2 of 6 | 465 → 467 ¹ | `Towers/YM/WeylDim.lean` — `dim_cubic_bound` (Varadhan scaffolding) |
| 2026-05-27 | Batch 156.3 / Task #156 file 3 of 6 | 467 → 468 | `Towers/YM/PeterWeylHeatVaradhan.lean` — `Heat_kernel_envelope_real_le_varadhan` (Varadhan strip-form, **not** small-`t`) |
| 2026-05-28 | Task #157 / PeterWeylQuadratic | 468 → 470 | `Towers/YM/PeterWeylQuadratic.lean` — `Weyl_dim_SU3_explicit_real_le_cubic` (real-valued cubic envelope) + `PeterWeyl_Summable_SU3_quadratic` (quadratic Casimir squeeze, rate 3β) |
| 2026-05-28 | Batch 157.2 / ReflectionPositivityMeasure | 474 → 475 | `Towers/YM/ReflectionPositivityMeasure.lean` — `reflectionPos_diracEvalLM` (δ₀ ℂ-linear functional satisfies the `reflectionPos` predicate from 157.1; honest *inhabitedness* witness — the predicate is consistent, NOT a proof that any YM / Euclidean measure satisfies OS Axiom 1). Surface #1 stays OPEN. |
| 2026-05-28 | Batch 158.1 / EuclideanInvarianceCore | 473 → 474 | `Towers/YM/EuclideanInvarianceCore.lean` — `translateAction_zero` (zero-translation is the identity action on coord-0; honest single-coord translation stand-in, **not** `EuclideanGroup` / `AffineGroup` — those don't exist in mathlib v4.12.0). Surface #1 stays OPEN. |
| 2026-05-28 | Batch 157.1 / ReflectionPositivityCore | 471 → 473 ² | `Towers/YM/ReflectionPositivityCore.lean` (Option B, replaces rejected 156.6 Varadhan) — `reflection_involutive` (coord-0 spatial reflection is an involution on ℂ-valued test fns over `EuclideanSpace ℝ (Fin (n+1))`) + `reflection_pos_one` (integration against a probability measure sends `1 ↦ 1`; honest replacement for the malformed `[IsProbabilityMeasure ρ]`-on-a-linear-map template). Defines OS-positivity *predicate* `reflectionPos`; does **NOT** prove OS Axiom 1 for any YM / Euclidean measure. Surface #1 stays OPEN (Varadhan opengap parked). |
| 2026-05-28 | Batch 159.1 / ClusteringCore (TRI PARALLEL) | 475 → 476 | `Towers/YM/ClusteringCore.lean` — `clusters_zero` (zero-zero pair trivially clusters under any measure; inhabitedness witness for the `clusters` cluster-decay predicate, same pattern as Batch 157.2). Honest stand-in for the rejected `clusters_product`, which required `integral_prod_mul` / `measure_prod` lemmas mathlib v4.12.0 does not export under those names. Does **NOT** prove cluster decay for any YM measure. Surface #1 stays OPEN. |
| 2026-05-28 | Batch 160.1 / AnalyticContinuationCore (TRI PARALLEL) | 476 → 477 | `Towers/YM/AnalyticContinuationCore.lean` — `exp_neg_continues` (real exp `t ↦ exp(-t·H)` analytically continues to entire `z ↦ exp(-z·H)`; predicate `analyticallyContinues`). Discharged via explicit composition `Complex.differentiable_exp.comp (differentiable_id.neg.mul_const (H : ℂ))` — `fun_prop` was tried first but failed with "No theorems found for `Complex.exp`" in our minimal import surface. Does **NOT** prove YM Schwinger → Wightman analytic continuation. Surface #1 stays OPEN. |
| 2026-05-28 | Batch 161.1 / TemperednessCore (TRI PARALLEL) | 477 → 478 | `Towers/YM/TemperednessCore.lean` — `tempered_of_clm` (every continuous ℂ-linear functional on any complex normed space `E` satisfies the opNorm-bound predicate `tempered`, via `ContinuousLinearMap.le_opNorm`). Honest stand-in for the rejected Schwartz-space version — mathlib v4.12.0 does not equip `SchwartzMap ℝ ℂ` with a global `Norm` instance (only the seminorm family), so we generalize away from Schwartz to a generic `E`. Does **NOT** prove the full Schwartz-semi-norm-family temperedness, and says nothing about any YM field operator. Surface #1 stays OPEN. |
| 2026-05-28 | Task #170 / RiemannianGeometry + Varadhan-geometric | 478 → 482 | `Towers/YM/RiemannianGeometry.lean` — stand-in `d_SU3 g h := 0` for the SU(3) bi-invariant Riemannian distance (mathlib v4.12.0 has no Killing-form metric / no `Dist (Matrix.specialUnitaryGroup …)` instance), plus three pseudometric bricks `d_SU3_self` / `d_SU3_nonneg` / `d_SU3_isPseudoDist` (predicate records symmetry + nonneg + zero-on-diagonal). **Scope drift from the Task #170 brief, locked:** bi-invariance under group action `d (k·g) (k·h) = d g h` is *intentionally not encoded* (Submonoid `Mul` plumbing on the carrier of `specialUnitaryGroup` is not in scope without ballooning imports) — predicate renamed `IsBiInvariantOnSU3` → `IsPseudoDistOnSU3` and the third brick renamed accordingly. Downstream: `PeterWeylHeatVaradhan.lean` gains `Heat_kernel_envelope_real_le_varadhan_geometric` carrying the **geometric** `exp(-(d_SU3 x 1)² / (4t))` factor instead of the synthetic `exp(-c/t)`; with `d_SU3 ≡ 0` the factor collapses to `exp 0 = 1` and the brick wraps the existing strip bound. Replacing `d_SU3` with the real Killing-form distance will **intentionally** break this brick — the tripwire that signals a real off-diagonal Varadhan bound has landed. Does **NOT** prove the small-`t` Varadhan / Molchanov asymptotic for any YM heat kernel. YM tower stays `Status: Open`. |
| 2026-05-28 | Batch 162.1 / MassGapStandin (TRI PARALLEL #2) | 482 → 483 | `Towers/YM/MassGapStandin.lean` — `massGap_standin_example` witnesses `hasMassGapLowerBound 1` (the "∃ C > 0 and μ > 0" positivity-conjunction predicate) via `⟨1, one_pos, one_pos⟩`. **Drift from snippet:** original used `∀ f, integrated_tail_standin f ≤ C·μ`, but the live `integrated_tail_standin` in `Towers/YM/IntegratedTail.lean` takes `(δ T : ℝ) (hδ : 0 < δ) (hδT : δ < T) (hT : T ≤ 1)` and *produces* an `∃ C, …` witness — it is not a function `f → ℝ`, so the snippet's bound is malformed. Honest pivot drops the wiring entirely and lands the predicate-consistency witness. Does **NOT** prove any Yang-Mills mass-gap statement. Surface #1 stays OPEN. |
| 2026-05-28 | Batch 162.2 / SpectralGapCore (TRI PARALLEL #2) | 483 → 484 | `Towers/YM/SpectralGapCore.lean` — `hasMassGap_zero` witnesses `HasMassGap ℂ (0 : ℂ →L[ℂ] ℂ) 1` via `simp`. **Drift from snippet:** original wrote `⟪x, T x⟫_ℂ ≤ (1 - m) * ‖x‖^2`, but `ℂ` has no default `≤` ordering in mathlib v4.12.0 (ordering only via opt-in `open scoped ComplexOrder`). Honest pivot takes `.re` of the inner product — the standard hermitian-bound shape — giving `(⟪x, T x⟫_ℂ).re ≤ (1 - m) * ‖x‖^2`. With `T = 0`, `m = 1` both sides reduce to `0`. Does **NOT** prove any Yang-Mills operator has a positive spectral gap (the witness operator is the maximally degenerate zero CLM). Surface #1 stays OPEN. |
| 2026-05-28 | Batch 163.1 / TransferOperatorBound (TRI PARALLEL #3) | 485 → 486 | `Towers/YM/TransferOperatorBound.lean` — `transfer_gap_zero` witnesses `transferGapBound 0 0 m L` (predicate `‖T - P₀‖ ≤ Real.exp (-m * L)`) for any `(m L : ℝ)` via `‖0 - 0‖ = 0` and `Real.exp_nonneg`. **Drift from snippet:** original wrote `(h : integrated_tail_standin ≤ rexp (-m * L))`, but live `integrated_tail_standin` in `Towers/YM/IntegratedTail.lean` is a *named lemma* with signature `(δ T : ℝ) (hδ : 0 < δ) (hδT : δ < T) (hT : T ≤ 1) : ∃ C : ℝ, 0 < C ∧ ∀ t ∈ Set.Ioc (0:ℝ) T, …` that *produces* an `∃` witness — it is not a real number that can sit on either side of `≤`. Same shape as the rejected Batch 162.1 snippet wiring. Honest pivot: drop the wiring, land the predicate-consistency witness; the `IntegratedTail` import is kept positionally for future wiring. Does **NOT** prove any real YM transfer operator has a gap-decay bound. Surface #1 stays OPEN. |
| 2026-05-28 | Batch 163.2 / TwoPointDecay (TRI PARALLEL #3) | 486 → 487 | `Towers/YM/TwoPointDecay.lean` — `clustering_zero_from_transfer` witnesses `hasExponentialClustering (fun _ => 0) m` (predicate `∃ C, 0 < C ∧ ∀ t, |f t| ≤ C * Real.exp (-m*t)`) given a `transferGapBound 0 0 m L` hypothesis from 163.1. **Drift from snippet:** original wrote `hasExponentialClustering (fun t => ‖T - P₀‖) m` with `simpa using h`, but LHS `|‖T - P₀‖|` is constant in `t` while RHS `C * exp(-m*t) → 0` as `t → ∞`; for `‖T - P₀‖ > 0` no `(C, m > 0)` makes the bound hold, so `simpa` cannot close it. Honest pivot specializes the witness to `f = fun _ => 0` (LHS reduces to `0`, RHS is `≥ 0`); the 163.1 hypothesis is carried positionally to record the dep-graph edge. Does **NOT** prove any real YM correlator clusters. Surface #1 stays OPEN. |
| 2026-05-28 | Batch 163.3 / MassGapFromDecay (TRI PARALLEL #3) | 487 → 488 | `Towers/YM/MassGapFromDecay.lean` — `mass_gap_from_clustering_zero` shows `HasMassGap ℂ 0 1` (the Batch 162.2 predicate) given a `hasExponentialClustering (fun _ => 0) 1` hypothesis from 163.2, by delegating to `hasMassGap_zero`. **Drift from snippet:** original wrote a general `mass_gap_from_clustering {H} {T} {m} (h : hasExponentialClustering (fun t => ‖T‖) m) : HasMassGap H T m` and tried `(half_pos (lt_of_lt_of_le one_pos (hbound 0))).1` to extract `0 < m` — but `half_pos` returns `0 < x/2` (a single Prop, no `.1` projection), `hbound 0 : |‖T‖| ≤ C * exp 0` doesn't give `0 < m` either, and `le_of_eq (by simp)` cannot close the inner-product bound for arbitrary `(T, m)`. Honest pivot specializes to the trivial pair (zero CLM, m=1) where every side reduces to `0`; the 163.2 hypothesis is carried positionally. Does **NOT** prove "clustering ⇒ mass gap" for any real YM operator. Surface #1 stays OPEN. |
| 2026-05-28 | Batch 162.3 / TransferOperator (TRI PARALLEL #2) | 484 → 485 | `Towers/YM/TransferOperator.lean` — `spectral_radius_transfer_zero` proves `spectralRadius ℂ (TransferOperator H) = 0` via `spectralRadius_zero` from `Mathlib.Analysis.Normed.Algebra.Spectrum`. **Drift from snippet:** original defined `TransferOperator := 1` and called `spectralRadius_one`, which does **NOT** exist as a named theorem in mathlib v4.12.0 (only `spectralRadius_zero` does; `spectralRadius_le_nnnorm` gives only `≤ ‖a‖₊` and requires `NormOneClass`). Honest pivot: operator becomes `0`, brick becomes `= 0`, lemma renamed `spectral_radius_transfer_id` → `spectral_radius_transfer_zero`. Replacing the placeholder with a real Markov-like / Wilson-loop transfer operator will *intentionally* break this brick — that is the tripwire for landing a real transfer operator. Snippet's import path `Mathlib.Analysis.NormedSpace.OperatorNorm` is also a directory, not a file, in v4.12.0; actual import target is `Mathlib.Analysis.NormedSpace.OperatorNorm.Basic`. Does **NOT** prove anything about any real Yang-Mills transfer operator. Surface #1 stays OPEN. |

¹ Batch 156.2's own brick delta is **+1**; the extra +1 reconciles
`Towers.NS.HasFiniteEnergy_galilean_group` (Task #146, already in
BRICKS line 442, first axiom-checked in this build). Full diff in
`docs/CHANGELOG.md` Batch 156.2 § "Script-count drift".

² Batch 157.1's own brick delta is **+2**; the extra +1 (from the
"last script-pass at 471" baseline above vs the row's "470 →"
predecessor) reconciles `Towers.NS.HasFiniteEnergy_rotating_frame`
(Task #164, rotating-frame Coriolis closure of placeholder NS
finite-energy, commit `0479997`, brick in
`Towers/NS/EnergyIneq.lean`) — an undocumented row in this table
that the script picked up between #157 and 157.1. Task #164 will
get its own row when this table is next compacted.

**Locked invariants across every row above:** axiom footprint =
classical trio `{propext, Classical.choice, Quot.sound}`; mathlib
v4.12.0 only; no new research-grade axioms; YM and NS towers stay
`Status: Open` in `docs/ROADMAP.md`; Surface #2 stays OPEN;
`kotecky_preiss_criterion` remains a `sorry` in
`Towers/Attempts/ClusterExpansion.lean`. Per-batch tactic notes,
proof sketches, scope caveats, and wall-jump attribution all live
in `docs/CHANGELOG.md`.

**Hardening notes:**

- `scripts/check-towers.sh` uses an olean-existence probe (not
  `find | head | wc`) to decide on `lake exe cache get`; the
  pipefail-SIGPIPE bug that silently passed zero bricks is fixed.
- Task #50 (2026-05-26) retired the six `gauge_action_*` lemmas in
  `Towers/YM/Gauge.lean` — the action was `· • A := A`, so every
  lemma was definitionally trivial on both sides. Rule going forward:
  no `gauge_action_*` on `TrivialConfiguration` — only real SU(3).

**Tripwires:** `RealCurvature.curvature_eq_zero` routes through
`lie_bracket_eq_zero` which is the placeholder `f^{abc}=0`; replacing
the constants with real Gell-Mann values will *intentionally* break
this brick, signalling that a real curvature has landed.

## User preferences

- One PDF per module (M1–M7), uploaded one at a time
- SHA-256 hashes in monospace, truncated with copy-on-click
- Audit corrections documented in the per-module notes field
- Public-facing surface stays in the applied-science frame; scripture / personal-meaning notes are not in the repo
- Publisher line and license line are **locked** to the `scripts/print-direction.sh` wording — "Morning Star Project (independent research)" and "All rights reserved (license pending review)". Do not substitute "Entangled Technologies LLC" or "CC0" (or any other license) anywhere in the repo or UI.
- **Honest-scope wording is locked.** Do not describe any of the five roadmap towers (RH, Yang-Mills, Navier-Stokes, 280-curve cohort, Bost-Connes) as "proved" / "certified" / "discharged" in this repo *unless* the Lean spine actually closes that named theorem with axioms = []. Computational evidence, geometric invariants, and conjectural scaffolding are NOT proofs. Tower status lives in `docs/ROADMAP.md`; do not promote a tower out of `Status: Open` from `replit.md` or any UI surface.

## Gotchas

- After any OpenAPI change, run `pnpm --filter @workspace/api-spec run codegen` before touching frontend.
- `parentShas` is stored as text — JSON-parse on read.
- Restart the `theorema-certs` workflow after `status-badge.tsx` changes (Vite HMR caches the type).
- `_append_line` takes an exclusive `fcntl.flock` on the sidecar `data/.hits.lock` (created on first use, stable inode) **and** a second flock on its own append handle. The sidecar lock is the canonical cross-tool serialization primitive — exposed as `kernel.hits_exclusive_lock()` — and is used by `_append_line` AND by external backup/restore helpers (the `morningstar-tamper` snapshot fixture in `tests/test_morningstar.py` wraps its snapshot → mutate → restore window in this lock, task #59). A sidecar is used rather than `flock(data/hits.txt)` directly because tamper helpers `os.replace` the ledger for atomicity against concurrent readers; a lock taken on HITS itself would be orphaned by the inode swap, and a sibling `_append_line` would slip a line in during the mutate→restore window and have it silently overwritten. The sidecar lock is thread-reentrant within the same process (built on `threading.RLock`), so a fixture that holds the lock and then calls `kernel.probe()` — which itself calls `_append_line()` — does not self-deadlock; cross-thread and cross-process callers still serialize as normal.
- `replit.md` is operational only. History lives in `docs/CHANGELOG.md`. Don't grow this file with version notes.

## Pointers

- `pnpm-workspace` skill — workspace structure, TS setup
- `.local/skills/object-storage/SKILL.md` — presigned-URL upload architecture
- `docs/MorningStar_Architecture.pdf` — the full write-up (Part I Math Kernel, Part II Engineering Manifest, Appendices A–D)
