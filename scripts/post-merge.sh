#!/bin/bash
set -e

# Diff helper. Returns 0 (true) if HEAD~1..HEAD touched any of the given
# paths, 1 (false) if not. Fails open (returns 0) when HEAD~1 is
# unreachable so the conservative path runs.
_touched() {
  if ! git rev-parse --verify --quiet HEAD~1 >/dev/null; then
    return 0
  fi
  if git diff --quiet HEAD~1 HEAD -- "$@"; then
    return 1
  fi
  return 0
}

# pnpm install — only when the dependency surface actually changed.
# Saves ~5s on the skip path. `--frozen-lockfile` would re-resolve and
# write the store on every merge otherwise, even though the resolved
# graph is identical.
if _touched pnpm-lock.yaml pnpm-workspace.yaml package.json '**/package.json'; then
  echo ">> running pnpm install --frozen-lockfile (dependency surface changed)" >&2
  pnpm install --frozen-lockfile
else
  echo ">> skipped pnpm install (no lockfile / package.json diff)" >&2
fi

# Drizzle schema push — only when the DB schema surface actually changed.
# Saves ~3s on the skip path. `db push` connects to Postgres, diffs the
# schema, and is a no-op when nothing changed — but the connect itself
# costs real time.
if _touched lib/db/src/schema lib/db/drizzle.config.ts; then
  echo ">> running pnpm --filter db push (schema surface changed)" >&2
  pnpm --filter db push
else
  echo ">> skipped pnpm --filter db push (no schema diff)" >&2
fi

# Rehydrate `.lake/packages/<pkg>/.git/` for every vendored Lake
# dependency from its committed tar under `lean-proof-towers/lake-deps/`.
# The outer repo cannot carry nested `.git/` directories, so they vanish
# on every merge and have to be restored here before any Lake operation
# can run safely. Task #76 (follow-up to Task #66).
./scripts/restore-lake-git.sh

# Re-establish the mathlib `v4.12.0` git tag that lake resolves `inputRev`
# against. restore-lake-git.sh rebuilds the vendored `.git/` at the
# manifest-pinned rev, but the *tag* is NOT carried in the restore tar, so it
# vanishes on every merge. Without it, the next `lake env` / `lake update`
# re-resolves `inputRev: v4.12.0` from the mathlib remote, re-clones, and
# wipes the olean cache (the recurring pin-wipe documented in replit.md).
# Recreate it idempotently at the pinned rev (== current HEAD after restore).
# Non-fatal: a missing mathlib checkout must never block the merge.
_MATHLIB_DIR="lean-proof-towers/.lake/packages/mathlib"
if [ -d "$_MATHLIB_DIR/.git" ]; then
  _MATHLIB_REV="$(git -C "$_MATHLIB_DIR" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$_MATHLIB_REV" ]; then
    if git -C "$_MATHLIB_DIR" tag -f v4.12.0 "$_MATHLIB_REV" >/dev/null 2>&1; then
      echo ">> re-established mathlib tag v4.12.0 -> ${_MATHLIB_REV}" >&2
    else
      echo ">> WARN: could not recreate mathlib tag v4.12.0 (non-fatal)" >&2
    fi
  fi
fi

# Guard against silent Lean proof drift. Fails the merge if `lean-proof/**`
# changed in a way that breaks the axiom-debt check or leaves VERIFY.txt stale.
# When `lake` is unavailable the check prints a visible warning and exits 0
# so merges aren't blocked in environments without a Lean toolchain.
./scripts/check-lean-proof.sh

# Tamper-surface gate (Task: post-merge 20s budget).
# -------------------------------------------------------------
# The two heavy guards below — Genesis-seal tamper-evidence (pytest,
# ~11s) and the at-rest ledger integrity check (~2s, task #53) — are
# only meaningful if the merge actually touched a file that could
# weaken tamper detection. For merges that did NOT touch the tamper
# surface (the vast majority — Lean towers, docs, frontend, etc.) we
# skip them inline and fire scripts/deep-audit.sh in the background
# instead, so the guard still runs but not on the 20s critical path.
#
# Tamper surface (any of these in the merge diff ⇒ run inline):
#   - kernel.py
#   - lean_bridge.py
#   - scripts/check-genesis-seal.py
#   - scripts/check-ledger-integrity.py
#   - data/hits.txt
#   - tests/test_morningstar.py
#
# If HEAD~1 isn't reachable (shallow clone / first commit / detached),
# we fail safe and run the heavy guards inline rather than skip.
TAMPER_PATHS=(
  kernel.py
  lean_bridge.py
  scripts/check-genesis-seal.py
  scripts/check-ledger-integrity.py
  data/hits.txt
  tests/test_morningstar.py
)
TAMPER_TOUCHED=1
if git rev-parse --verify --quiet HEAD~1 >/dev/null; then
  if git diff --quiet HEAD~1 HEAD -- "${TAMPER_PATHS[@]}"; then
    TAMPER_TOUCHED=0
  fi
else
  echo ">> post-merge: HEAD~1 unreachable; running heavy guards inline (fail-safe)" >&2
fi

if [ $TAMPER_TOUCHED -eq 1 ]; then
  # Re-verify the Genesis-seal tamper-evidence guarantees on every merge.
  # This fails the merge if anyone "fixes" check-genesis-seal.py,
  # lean_bridge._guard, or kernel.probe() in a way that weakens the
  # tamper detection covered by tests/test_morningstar.py.
  echo ">> running tests/test_morningstar.py (Genesis-seal tamper-evidence)" >&2
  python -m pytest tests/test_morningstar.py -q

  # At-rest integrity guard against silent truncation / in-place rewrite of
  # the probe ledger. The Genesis seal only covers the 9-line preamble; this
  # catches a stray truncating-write (mode 'w', Path.write_text, or a
  # shell-redirect overwrite) that preserves the preamble but wipes the
  # body. Task #53.
  echo ">> running scripts/check-ledger-integrity.py (at-rest ledger guard)" >&2
  python scripts/check-ledger-integrity.py
else
  echo ">> skipped (no tamper-surface diff); deep-audit started in background" >&2
  nohup bash scripts/deep-audit.sh >/dev/null 2>&1 &
fi

# Re-run the theorema-certs dashboard Playwright suite (sidecar
# tamper banner, Acknowledge button, strict-mode badge, …). Task #149:
# previously these only ran by hand. In strict mode a missing browser
# or a chromium launch failure is a HARD FAIL — same blocking semantics
# as `lean-proof`. The script is lenient by default for fresh clones
# without browsers; STRICT_E2E_CHECK=1 here promotes that to a merge
# gate.
#
# Dashboard-surface gate (mirrors the tamper-surface gate above —
# post-merge.sh has a configurable timeout and the full Playwright
# suite is far too slow to run on every merge). Inline-strict only
# when the merge actually touched a file the suite covers:
#   - artifacts/theorema-certs/**  (the SPA + the suite itself)
#   - artifacts/api-server/**      (the routes the SPA renders)
#   - lib/api-spec/**              (the contract the routes implement)
#   - scripts/check-theorema-certs-e2e.sh  (the harness itself)
# Otherwise the `theorema-certs-e2e` validation workflow (registered
# in .replit by Task #149) remains the on-demand merge gate and this
# step is skipped silently — same posture as the tamper-surface gate.
DASHBOARD_PATHS=(
  artifacts/theorema-certs
  artifacts/api-server
  lib/api-spec
  scripts/check-theorema-certs-e2e.sh
)
DASHBOARD_TOUCHED=1
if git rev-parse --verify --quiet HEAD~1 >/dev/null; then
  if git diff --quiet HEAD~1 HEAD -- "${DASHBOARD_PATHS[@]}"; then
    DASHBOARD_TOUCHED=0
  fi
else
  echo ">> post-merge: HEAD~1 unreachable; running e2e inline (fail-safe)" >&2
fi

if [ $DASHBOARD_TOUCHED -eq 1 ]; then
  # The full strict Playwright suite is ~4m wall — it cannot fit the
  # post-merge timeout budget, and workflow reconciliation restarts the
  # heavy `towers-build` (5224-module `lake build`) concurrently with the
  # merge, which starves Playwright and makes the suite flake en masse
  # (uniform 5s "element not found" timeouts across unrelated specs even
  # though the live dashboard is healthy). Running it inline therefore
  # both times out the merge AND produces false failures.
  #
  # So fire it in the BACKGROUND — same off-critical-path posture as the
  # `deep-audit.sh` tamper guard above. The authoritative *blocking* gate
  # is the registered `theorema-certs-e2e` validation workflow (run by the
  # task agent before merge and on demand in the main env), not this
  # post-merge re-run. Output lands in /tmp/post-merge-e2e.log for audit.
  echo ">> dashboard surface changed; firing strict e2e in background (off post-merge critical path); theorema-certs-e2e validation workflow is the blocking gate; log: /tmp/post-merge-e2e.log" >&2
  nohup bash -c 'STRICT_E2E_CHECK=1 ./scripts/check-theorema-certs-e2e.sh' >/tmp/post-merge-e2e.log 2>&1 &
else
  echo ">> skipped e2e (no dashboard-surface diff); theorema-certs-e2e validation workflow remains the on-demand gate" >&2
fi

./scripts/print-direction.sh >&2
