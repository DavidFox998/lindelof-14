"""Integration tests for ``scripts/fetch-mathlib-oleans.sh`` (Task #213).

``lake build Towers`` compiles the Towers library on top of mathlib. If the
mathlib oleans are missing — or only PARTIALLY present — it compiles the
missing mathlib modules from source, which exceeds the ``towers-build``
workflow wall-clock limit and never completes. The only supported way to
populate the oleans is ``lake exe cache get``.

``fetch-mathlib-oleans.sh`` guards ``lake build`` so a from-source fallback
can only ever be reached when ``cache get`` itself fails. It:

* never skips the download on a heuristic — it always runs ``lake exe cache
  get`` (idempotent + hash-based), so a partial/incomplete cache no longer
  slips through the way the old sentinel-file probe in ``check-towers.sh``
  allowed; the olean count is only a post-fetch sanity floor;
* heals a corrupt ``cache`` exe via ``ensure-mathlib-cache-bin.sh``;
* exits non-zero with a clear message when ``cache get`` fails;
* asserts both the cache exe AND the oleans are populated after a fetch.

These tests drive the script's control flow with a mocked ``lake`` (the
``LAKE`` env override) and throwaway fixtures (``MATHLIB_BUILD_LIB`` /
``MATHLIB_CACHE_BIN`` / ``MATHLIB_OLEAN_MIN``) so no real lake / mathlib /
network is needed.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "fetch-mathlib-oleans.sh"
PREFLIGHT_PATH = REPO_ROOT / "scripts" / "ensure-mathlib-cache-bin.sh"

# Small threshold so fixtures stay tiny: > THRESHOLD oleans == "complete".
THRESHOLD = 2


pytestmark = [
    pytest.mark.skipif(
        not shutil.which("bash"),
        reason="fetch-mathlib-oleans.sh requires `bash` on PATH",
    ),
    pytest.mark.skipif(
        not SCRIPT_PATH.exists(),
        reason=f"script missing: {SCRIPT_PATH}",
    ),
    pytest.mark.skipif(
        not PREFLIGHT_PATH.exists(),
        reason=f"preflight script missing: {PREFLIGHT_PATH}",
    ),
]


def _lib_dir(tmp_path: Path) -> Path:
    return tmp_path / "build" / "lib"


def _mathlib_dir(tmp_path: Path) -> Path:
    return _lib_dir(tmp_path) / "Mathlib"


def _make_oleans(tmp_path: Path, n: int) -> None:
    d = _mathlib_dir(tmp_path)
    d.mkdir(parents=True, exist_ok=True)
    for i in range(n):
        (d / f"Mod{i}.olean").write_bytes(b"olean")


def _make_healthy_cache_bin(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"#!/bin/sh\nexit 0\n")
    path.chmod(0o755)


def _write_mock_lake(
    path: Path,
    *,
    exit_code: int,
    oleans_to_create: int,
    rebuild_cache_bin: bool,
) -> Path:
    """Write a fake `lake` that emulates `lake exe cache get`.

    On invocation it (optionally) rebuilds the cache exe and creates
    `oleans_to_create` oleans under $MATHLIB_BUILD_LIB/Mathlib, then exits
    with `exit_code`. It records its argv to `<path>.calls` so a test can
    assert whether (and how) it was invoked.
    """
    rebuild = "1" if rebuild_cache_bin else "0"
    path.write_text(
        "#!/usr/bin/env bash\n"
        f'echo "$@" >> "{path}.calls"\n'
        f"if [ \"{rebuild}\" = \"1\" ]; then\n"
        '  mkdir -p "$(dirname "$MATHLIB_CACHE_BIN")"\n'
        '  printf \'#!/bin/sh\\nexit 0\\n\' > "$MATHLIB_CACHE_BIN"\n'
        '  chmod +x "$MATHLIB_CACHE_BIN"\n'
        "fi\n"
        f"n={oleans_to_create}\n"
        '  mkdir -p "$MATHLIB_BUILD_LIB/Mathlib"\n'
        'i=0\n'
        'while [ "$i" -lt "$n" ]; do\n'
        '  printf olean > "$MATHLIB_BUILD_LIB/Mathlib/Fetched$i.olean"\n'
        '  i=$((i + 1))\n'
        "done\n"
        f"exit {exit_code}\n"
    )
    path.chmod(0o755)
    return path


def _run(
    tmp_path: Path,
    *,
    lake: str,
    cache_bin: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    if cache_bin is None:
        cache_bin = tmp_path / "build" / "bin" / "cache"
    env = {
        **os.environ,
        "TOWERS_DIR": str(tmp_path),
        "MATHLIB_BUILD_LIB": str(_lib_dir(tmp_path)),
        "MATHLIB_CACHE_BIN": str(cache_bin),
        "MATHLIB_OLEAN_MIN": str(THRESHOLD),
        "LAKE": lake,
    }
    return subprocess.run(
        ["bash", str(SCRIPT_PATH)],
        env=env,
        capture_output=True,
        text=True,
    )


def test_warm_complete_cache_still_runs_cache_get(tmp_path):
    """Even a COMPLETE-looking cache must NOT be skipped on a heuristic:
    `lake exe cache get` is the authoritative (idempotent, hash-based)
    completeness check, so it is always invoked. It is a fast no-op when the
    cache is genuinely complete."""
    _make_oleans(tmp_path, THRESHOLD + 1)
    mock = _write_mock_lake(
        tmp_path / "lake",
        exit_code=0,
        oleans_to_create=0,  # no-op top-up; cache already complete
        rebuild_cache_bin=True,
    )

    result = _run(tmp_path, lake=str(mock))

    assert result.returncode == 0, (
        f"exited {result.returncode}; stderr={result.stderr!r}"
    )
    calls = Path(f"{mock}.calls")
    assert calls.exists(), "cache get was wrongly skipped on a heuristic"
    assert "exe cache get" in calls.read_text()
    assert "ready" in result.stderr


def test_partial_cache_triggers_download(tmp_path):
    """A PARTIAL cache (oleans below the floor) must run `cache get` to
    complete it rather than be treated as ready."""
    _make_oleans(tmp_path, 1)  # below THRESHOLD
    mock = _write_mock_lake(
        tmp_path / "lake",
        exit_code=0,
        oleans_to_create=THRESHOLD + 2,
        rebuild_cache_bin=True,
    )

    result = _run(tmp_path, lake=str(mock))

    assert result.returncode == 0, (
        f"exited {result.returncode}; stderr={result.stderr!r}"
    )
    calls = Path(f"{mock}.calls")
    assert calls.exists(), "cache get was not run for a partial cache"
    assert "exe cache get" in calls.read_text()
    assert "ready" in result.stderr


def test_cold_cache_fetch_success(tmp_path):
    """A cold cache (no oleans) runs `cache get`; on success (oleans populated
    + healthy cache exe) the script exits 0."""
    mock = _write_mock_lake(
        tmp_path / "lake",
        exit_code=0,
        oleans_to_create=THRESHOLD + 5,
        rebuild_cache_bin=True,
    )

    result = _run(tmp_path, lake=str(mock))

    assert result.returncode == 0, (
        f"exited {result.returncode}; stderr={result.stderr!r}"
    )
    assert "ready" in result.stderr


def test_cache_get_failure_exits_nonzero(tmp_path):
    """When `cache get` itself fails (unreachable CDN / broken toolchain) the
    script exits non-zero — it must NOT swallow the error and let the caller
    proceed into a from-source compile."""
    mock = _write_mock_lake(
        tmp_path / "lake",
        exit_code=1,
        oleans_to_create=0,
        rebuild_cache_bin=False,
    )

    result = _run(tmp_path, lake=str(mock))

    assert result.returncode != 0, "cache get failure must abort"
    assert "cache get` failed" in result.stderr
    assert "from-source" in result.stderr


def test_corrupt_cache_bin_is_healed_before_fetch(tmp_path):
    """A 0-byte cache exe must be removed by the preflight before `cache get`,
    which then rebuilds it; the script exits 0."""
    cache_bin = tmp_path / "build" / "bin" / "cache"
    cache_bin.parent.mkdir(parents=True, exist_ok=True)
    cache_bin.touch()  # corrupt: 0 bytes
    cache_bin.chmod(0o755)

    mock = _write_mock_lake(
        tmp_path / "lake",
        exit_code=0,
        oleans_to_create=THRESHOLD + 3,
        rebuild_cache_bin=True,
    )

    result = _run(tmp_path, lake=str(mock), cache_bin=cache_bin)

    assert result.returncode == 0, (
        f"exited {result.returncode}; stderr={result.stderr!r}"
    )
    assert "RECOVERY" in result.stderr, "preflight did not heal the corrupt exe"
    assert cache_bin.exists() and cache_bin.stat().st_size > 0
    assert "ready" in result.stderr


def test_empty_oleans_after_fetch_exits_nonzero(tmp_path):
    """If `cache get` reports success but does NOT populate oleans, the
    post-fetch assertion must fail loudly instead of allowing a source build."""
    mock = _write_mock_lake(
        tmp_path / "lake",
        exit_code=0,
        oleans_to_create=0,  # success exit but no oleans
        rebuild_cache_bin=True,
    )

    result = _run(tmp_path, lake=str(mock))

    assert result.returncode != 0, "empty olean set after fetch must abort"
    assert "did not populate" in result.stderr


def test_corrupt_cache_bin_after_fetch_exits_nonzero(tmp_path):
    """If the cache exe is still corrupt after `cache get` (rebuild itself
    failed), the post-fetch health assertion must abort."""
    mock = _write_mock_lake(
        tmp_path / "lake",
        exit_code=0,
        oleans_to_create=THRESHOLD + 3,
        rebuild_cache_bin=False,  # never (re)creates a healthy exe
    )

    result = _run(tmp_path, lake=str(mock))

    assert result.returncode != 0, "corrupt cache exe after fetch must abort"
    assert "still corrupt" in result.stderr
