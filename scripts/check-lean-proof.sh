#!/usr/bin/env bash
# check-lean-proof.sh — Guard against silent Lean proof drift.
#
# Re-runs `lean-proof/regenerate.sh`, which rebuilds the Lean proof and
# self-checks that `main_theorem`, `H2_WeilTransfer`, and
# `M9_WeilTransfer_All` still report "does not depend on any axioms".
# Exits non-zero if the proof itself has drifted (i.e. the axiom debt
# check inside regenerate.sh failed). VERIFY.txt is regenerated as a
# side-effect; we don't compare it against the committed copy because it
# embeds volatile metadata (date / host) that would cause spurious diffs.
#
# Intended triggers:
#   - registered `validation` command (`lean-proof`) for CI-style checks
#   - invoked from `scripts/post-merge.sh` so any merge that touches
#     `lean-proof/**` is verified before it can silently ship
#
# Behaviour when `lake` (Lean 4) is not installed:
#   - in strict mode (env `STRICT_LEAN_CHECK=1`, used by the `lean-proof`
#     validation workflow / CI gate) the script FAILS, so the proof can never
#     ship without being re-verified
#   - in non-strict mode (the default, used by the local post-merge hook) the
#     script prints a clearly visible warning to stderr and exits 0 so merges
#     aren't blocked in environments without a Lean toolchain. The warning
#     still surfaces in the post-merge log so the gap is visible.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

STRICT="${STRICT_LEAN_CHECK:-0}"

if ! command -v lake >/dev/null 2>&1; then
  if [ "$STRICT" = "1" ]; then
    cat >&2 <<'EOF'
error: `lake` (Lean 4) is not on PATH and STRICT_LEAN_CHECK=1.
       The dashboard's "axiom debt = []" claim cannot be re-verified
       without a Lean toolchain. Install Lean 4
       (https://leanprover.github.io/lean4/doc/setup.html) or activate
       elan in this environment, then re-run the check.
EOF
    exit 127
  fi
  cat >&2 <<'EOF'
warning: `lake` (Lean 4) is not on PATH; skipping Lean proof verification.
         Install Lean 4 (https://leanprover.github.io/lean4/doc/setup.html)
         or activate elan to enable the axiom-debt drift check.
         Set STRICT_LEAN_CHECK=1 to make this a hard failure instead of a
         warning (the `lean-proof` validation workflow does this).
         The dashboard's "axiom debt = []" claim cannot be re-verified
         from this environment until a toolchain is available.
EOF
  exit 0
fi

echo ">> running lean-proof/regenerate.sh" >&2
if ! ./lean-proof/regenerate.sh; then
  echo "error: lean-proof/regenerate.sh failed — Lean proof has drifted." >&2
  exit 1
fi

# regenerate.sh self-checks axiom debt and re-writes VERIFY.txt with the
# freshly verified output. We deliberately do NOT compare the regenerated
# VERIFY.txt against the committed copy as a whole — that file contains
# volatile metadata (Date verified, host) that would cause false drift
# failures on a different day or host. The axiom-debt check inside
# regenerate.sh is what actually catches a broken proof.

echo "ok: Lean proof verified; VERIFY.txt regenerated." >&2
"$REPO_ROOT/scripts/print-direction.sh" >&2
