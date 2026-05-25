#!/bin/bash
set -e
pnpm install --frozen-lockfile
pnpm --filter db push

# Guard against silent Lean proof drift. Fails the merge if `lean-proof/**`
# changed in a way that breaks the axiom-debt check or leaves VERIFY.txt stale.
# When `lake` is unavailable the check prints a visible warning and exits 0
# so merges aren't blocked in environments without a Lean toolchain.
./scripts/check-lean-proof.sh

# Re-verify the Genesis-seal tamper-evidence guarantees on every merge.
# This fails the merge if anyone "fixes" check-genesis-seal.py,
# lean_bridge._guard, or kernel.probe() in a way that weakens the
# tamper detection covered by tests/test_morningstar.py.
echo ">> running tests/test_morningstar.py (Genesis-seal tamper-evidence)" >&2
python -m pytest tests/test_morningstar.py -q

./scripts/print-direction.sh >&2
