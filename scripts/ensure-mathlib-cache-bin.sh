#!/usr/bin/env bash
# ensure-mathlib-cache-bin.sh — Detect and heal a corrupt mathlib `cache`
# executable before `lake exe cache get` runs (Task #213).
#
# Why this exists:
#
# `lake exe cache get` downloads the ~2 GB of prebuilt mathlib oleans using the
# `cache` executable that lake builds under
#   lean-proof-towers/.lake/packages/mathlib/.lake/build/bin/cache
# During Task #190 the `towers-build` workflow repeatedly failed because this
# binary was left as a 0-byte (corrupt) file. Lake's build system treats an
# existing output artifact as up-to-date, so it never rebuilt the exe; with no
# working `cache` binary `lake exe cache get` could not download the prebuilt
# oleans, and `lake build` then silently fell back to compiling ALL of mathlib
# from source — which exceeds the workflow wall-clock limit and never completes.
# Recovery required manually wiping + re-fetching mathlib.
#
# This script asserts the cache binary is non-empty and executable up front. If
# it finds a corrupt (empty or non-executable) artifact it REMOVES it, so the
# subsequent `lake exe cache get` in `check-towers.sh` rebuilds a fresh exe from
# source (only mathlib's `Cache` module compiles — seconds, NOT the whole
# library) and then downloads the oleans from the CDN. A missing binary is fine:
# lake builds it on the first `cache get`. A healthy binary is left untouched.
#
# This script never compiles or downloads anything itself — the rebuild and the
# CDN fetch stay in `check-towers.sh` via `lake exe cache get`. Its only job is
# the cheap, lake-free preflight + heal so we never silently fall through to a
# from-source mathlib compile because of a stale corrupt artifact.
#
# Exit codes:
#   0 — cache binary is healthy, absent, or was corrupt and successfully removed
#       (so lake will rebuild it on the next `lake exe cache get`).
#   1 — corrupt binary detected but could not be removed.
#
# The cache binary path is overridable via MATHLIB_CACHE_BIN so a smoke test can
# point the script at a throwaway fixture instead of the live vendored mathlib.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATHLIB_CACHE_BIN="${MATHLIB_CACHE_BIN:-$REPO_ROOT/lean-proof-towers/.lake/packages/mathlib/.lake/build/bin/cache}"

if [ ! -e "$MATHLIB_CACHE_BIN" ]; then
  echo "ensure-mathlib-cache-bin: cache exe absent ($MATHLIB_CACHE_BIN);" >&2
  echo "  lake will build it on \`lake exe cache get\`." >&2
  exit 0
fi

reason=""
if [ ! -s "$MATHLIB_CACHE_BIN" ]; then
  reason="empty (0 bytes)"
elif [ ! -x "$MATHLIB_CACHE_BIN" ]; then
  reason="present but not executable"
fi

if [ -n "$reason" ]; then
  echo "ensure-mathlib-cache-bin: RECOVERY: mathlib \`cache\` exe is corrupt — $reason." >&2
  echo "  Path: $MATHLIB_CACHE_BIN" >&2
  echo "  Removing it so \`lake exe cache get\` rebuilds a fresh exe from source" >&2
  echo "  (mathlib's \`Cache\` module only, seconds) and downloads the oleans," >&2
  echo "  instead of silently falling back to compiling all of mathlib." >&2
  if ! rm -f "$MATHLIB_CACHE_BIN"; then
    echo "ensure-mathlib-cache-bin: error: failed to remove corrupt cache exe at $MATHLIB_CACHE_BIN." >&2
    exit 1
  fi
  echo "ensure-mathlib-cache-bin: removed corrupt exe; rebuild happens on next \`lake exe cache get\`." >&2
  exit 0
fi

echo "ensure-mathlib-cache-bin: ok — cache exe is non-empty and executable." >&2
exit 0
