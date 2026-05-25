#!/usr/bin/env bash
# print-direction.sh — single source of truth for "you are here".
#
# Every build / validation / harness script ends with a call to this so a
# user / referee / future-us never has to ask "what's this called, where
# does it live, what URL do I open". Naming and structure are locked in
# this one place.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Resolve preview URL if running inside a Replit dev container; fall back
# to a clearly-labelled placeholder otherwise.
PREVIEW_URL="${REPLIT_DOMAINS:-${REPLIT_DEV_DOMAIN:-not-set}}"
if [ "$PREVIEW_URL" != "not-set" ]; then
  # REPLIT_DOMAINS may be comma-separated; take the first.
  PREVIEW_URL="https://${PREVIEW_URL%%,*}/"
fi

# Genesis seal — printed for verification, not recomputed.
SEAL="eecbcd9a540aa7a2c90edd23827c73e4d1bb5af641d352f70a5de849b21f875f"

cat <<EOF

================================================================
  Morning Star Project · Theorema Aureum 143 (Volume I)
  Publisher: Morning Star Project (independent research)
  License:   All rights reserved (license pending review)
================================================================

  Dashboard          ${PREVIEW_URL}
  Manifest           data/THEOREMA_AUREUM_143.manifest.txt
  Reproduce (3 cmd)  docs/REPRODUCE.md
  Architecture PDF   docs/MorningStar_Architecture.pdf
  Sitemap            docs/SiteMap.md
  Changelog          docs/CHANGELOG.md
  Casualty log       data/CASUALTY_LOG.md

  Sealed ledger      data/hits.txt
  Public alias       data/theorema-aureum-143-hits.txt  (symlink)
  Genesis seal       ${SEAL}
  Verify seal        python3 scripts/check-genesis-seal.py
  Lean axioms        lean-proof/VERIFY.txt  (axiom debt = [])

================================================================
EOF
