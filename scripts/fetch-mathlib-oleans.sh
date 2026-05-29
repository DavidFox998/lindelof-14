#!/usr/bin/env bash
# fetch-mathlib-oleans.sh — Guarantee the prebuilt mathlib oleans are on disk
# before `lake build Towers`, WITHOUT ever silently falling back to compiling
# mathlib from source (Task #213 + lead-wall hardening).
#
# Why this exists:
#
# `lake build Towers` compiles the Towers library on top of mathlib. If the
# mathlib oleans are missing (or only partially present) it compiles the missing
# mathlib modules FROM SOURCE — which exceeds the towers-build workflow
# wall-clock limit and never completes. The only supported way to populate the
# oleans is `lake exe cache get`, which downloads them from the Lean community
# CDN using the `cache` exe under
#   .lake/packages/mathlib/.lake/build/bin/cache
#
# Two failure modes drove this script:
#   1. A corrupt (0-byte / non-executable) `cache` exe — lake treats it as
#      up-to-date and never rebuilds it, so `cache get` cannot download oleans.
#      Healed by the `ensure-mathlib-cache-bin.sh` preflight.
#   2. A *partial* olean set passing the old "warm cache" skip heuristic in
#      `check-towers.sh` (which only checked a handful of sentinel `.olean`
#      files). The skip then avoided `cache get` and `lake build` quietly
#      compiled the rest from source even though the CDN was perfectly
#      reachable. Healed here by REMOVING the skip entirely: any olean-count
#      gate is heuristic and cannot tell a complete cache apart from a
#      large-but-interrupted one, so this script always runs `cache get` and
#      lets it be the authoritative completeness check.
#
# Guarantee: this script always (a) heals a corrupt cache exe, then (b) runs
# `lake exe cache get` (idempotent + hash-based: a fast no-op on a complete
# cache, a top-up of only the missing oleans otherwise) and asserts the oleans
# are actually populated afterwards. A from-source fallback can only be reached
# when `cache get` itself fails (genuinely unreachable CDN / broken toolchain),
# in which case the script exits non-zero with a clear message rather than
# letting the caller proceed into a multi-hour source compile.
#
# Overridable via env (so a smoke test can drive it without real lake/mathlib):
#   TOWERS_DIR          — package root (default: <repo>/lean-proof-towers)
#   MATHLIB_BUILD_LIB   — mathlib olean lib dir (default: under TOWERS_DIR)
#   MATHLIB_CACHE_BIN   — mathlib cache exe path (default: under TOWERS_DIR)
#   MATHLIB_OLEAN_MIN   — post-fetch sanity FLOOR (default: 1000). A complete
#                         mathlib v4.12.0 build has thousands of `.olean` files,
#                         so after a successful `cache get` the count must exceed
#                         this floor; otherwise the fetch did not populate the
#                         library and we abort rather than let `lake build` fall
#                         back to a from-source compile. (It is NOT used as a
#                         skip gate — see below.)
#   LAKE                — lake invocation (default: `lake`); injectable for tests.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOWERS_DIR="${TOWERS_DIR:-$REPO_ROOT/lean-proof-towers}"
MATHLIB_BUILD_LIB="${MATHLIB_BUILD_LIB:-$TOWERS_DIR/.lake/packages/mathlib/.lake/build/lib}"
MATHLIB_CACHE_BIN="${MATHLIB_CACHE_BIN:-$TOWERS_DIR/.lake/packages/mathlib/.lake/build/bin/cache}"
MATHLIB_OLEAN_MIN="${MATHLIB_OLEAN_MIN:-1000}"
LAKE="${LAKE:-lake}"

count_oleans() {
  if [ -d "$MATHLIB_BUILD_LIB/Mathlib" ]; then
    find "$MATHLIB_BUILD_LIB/Mathlib" -name '*.olean' -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
}

oleans_before="$(count_oleans)"
echo ">> mathlib oleans on disk before fetch: $oleans_before" >&2

# We deliberately do NOT skip `lake exe cache get` based on an olean count. Any
# count-based "warm cache" gate is only a heuristic and cannot tell a COMPLETE
# cache apart from a large-but-interrupted one, so skipping could let
# `lake build Towers` compile the missing mathlib modules from source even when
# the CDN is reachable — exactly the failure this guard exists to prevent.
# `lake exe cache get` is itself idempotent and hash-based: on a complete cache
# it is a fast no-op, and on a partial cache it downloads only the missing
# oleans, so it is the authoritative completeness check. (The olean count is
# used only as a post-fetch sanity floor below.)

# Heal a corrupt cache exe so `cache get` can rebuild + run it.
echo ">> ensure-mathlib-cache-bin.sh (heal corrupt mathlib cache exe)" >&2
MATHLIB_CACHE_BIN="$MATHLIB_CACHE_BIN" "$REPO_ROOT/scripts/ensure-mathlib-cache-bin.sh"

echo ">> lake exe cache get (fetch prebuilt mathlib oleans)" >&2
if ! ( cd "$TOWERS_DIR" && $LAKE exe cache get ); then
  echo "error: \`lake exe cache get\` failed after a healthy cache-exe preflight." >&2
  echo "       This is the genuinely-unreachable-CDN (or broken local toolchain)" >&2
  echo "       path — NOT a corrupt cache binary. Refusing to fall back to a" >&2
  echo "       from-source mathlib compile (it exceeds the towers-build workflow" >&2
  echo "       wall-clock limit and never completes). Re-run once connectivity is" >&2
  echo "       restored, or recover mathlib manually." >&2
  exit 1
fi

# Post-fetch assertions: BOTH the cache exe must be healthy AND the oleans must
# now actually be populated. Otherwise a later `lake build Towers` would still
# compile mathlib from source — fail loudly here instead.
if [ ! -s "$MATHLIB_CACHE_BIN" ] || [ ! -x "$MATHLIB_CACHE_BIN" ]; then
  echo "error: mathlib \`cache\` exe still corrupt after \`lake exe cache get\`" >&2
  echo "       ($MATHLIB_CACHE_BIN). Aborting before a from-source mathlib compile." >&2
  exit 1
fi

oleans_after="$(count_oleans)"
if [ "$oleans_after" -le "$MATHLIB_OLEAN_MIN" ]; then
  echo "error: after \`lake exe cache get\` only $oleans_after mathlib oleans are on" >&2
  echo "       disk (<= $MATHLIB_OLEAN_MIN threshold). The fetch did not populate the" >&2
  echo "       library; aborting before \`lake build\` falls back to a from-source" >&2
  echo "       compile." >&2
  exit 1
fi

echo ">> mathlib cache ready ($oleans_after oleans on disk)." >&2
