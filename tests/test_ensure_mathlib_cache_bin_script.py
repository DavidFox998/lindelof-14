"""Smoke tests for ``scripts/ensure-mathlib-cache-bin.sh`` (Task #213).

``lake exe cache get`` downloads the prebuilt mathlib oleans using the
``cache`` executable lake builds under
``lean-proof-towers/.lake/packages/mathlib/.lake/build/bin/cache``. During
Task #190 the ``towers-build`` workflow repeatedly failed because this binary
was left as a 0-byte (corrupt) file: lake treated the existing artifact as
up-to-date and never rebuilt it, so ``lake exe cache get`` could not download
the oleans and ``lake build`` silently fell back to compiling all of mathlib
from source — which exceeds the workflow wall-clock limit and never completes.

``ensure-mathlib-cache-bin.sh`` is the cheap, lake-free preflight
``check-towers.sh`` runs before ``lake exe cache get``: it asserts the cache
binary is non-empty and executable, and removes a corrupt artifact so the
subsequent ``cache get`` rebuilds a fresh exe instead of falling through to a
from-source compile. These tests drive the script against throwaway fixtures
via the ``MATHLIB_CACHE_BIN`` env override so no real lake / mathlib is needed.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "ensure-mathlib-cache-bin.sh"


pytestmark = [
    pytest.mark.skipif(
        not shutil.which("bash"),
        reason="ensure-mathlib-cache-bin.sh requires `bash` on PATH",
    ),
    pytest.mark.skipif(
        not SCRIPT_PATH.exists(),
        reason=f"script missing: {SCRIPT_PATH}",
    ),
]


def _run(cache_bin: Path) -> subprocess.CompletedProcess[str]:
    env = {**os.environ, "MATHLIB_CACHE_BIN": str(cache_bin)}
    return subprocess.run(
        ["bash", str(SCRIPT_PATH)],
        env=env,
        capture_output=True,
        text=True,
    )


def test_removes_empty_cache_binary(tmp_path):
    """A 0-byte cache exe is corrupt — the script must remove it and exit 0
    so lake rebuilds a fresh one on the next `lake exe cache get`."""
    cache_bin = tmp_path / "cache"
    cache_bin.touch()  # 0-byte file
    cache_bin.chmod(0o755)
    assert cache_bin.stat().st_size == 0

    result = _run(cache_bin)

    assert result.returncode == 0, (
        f"exited {result.returncode}; stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    assert not cache_bin.exists(), "corrupt (empty) cache exe was not removed"
    assert "RECOVERY" in result.stderr


def test_removes_non_executable_cache_binary(tmp_path):
    """A non-empty but non-executable cache exe is also unusable by
    `lake exe cache get`; the script must remove it and exit 0."""
    cache_bin = tmp_path / "cache"
    cache_bin.write_bytes(b"not really a binary")
    cache_bin.chmod(0o644)  # no execute bit

    result = _run(cache_bin)

    assert result.returncode == 0, (
        f"exited {result.returncode}; stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    assert not cache_bin.exists(), "corrupt (non-executable) cache exe was not removed"
    assert "RECOVERY" in result.stderr


def test_preserves_healthy_cache_binary(tmp_path):
    """A non-empty, executable cache exe is healthy and must be left
    untouched — the preflight must not disturb a warm cache."""
    cache_bin = tmp_path / "cache"
    cache_bin.write_bytes(b"#!/bin/sh\nexit 0\n")
    cache_bin.chmod(0o755)
    before = cache_bin.read_bytes()

    result = _run(cache_bin)

    assert result.returncode == 0, (
        f"exited {result.returncode}; stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    assert cache_bin.exists(), "healthy cache exe was wrongly removed"
    assert cache_bin.read_bytes() == before, "healthy cache exe was modified"
    assert "RECOVERY" not in result.stderr
    assert "ok" in result.stderr


def test_absent_cache_binary_is_ok(tmp_path):
    """No cache exe at all is fine — lake builds it on first `cache get`.
    The script must exit 0 and not create anything."""
    cache_bin = tmp_path / "cache"
    assert not cache_bin.exists()

    result = _run(cache_bin)

    assert result.returncode == 0, (
        f"exited {result.returncode}; stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    assert not cache_bin.exists(), "script should not create a cache exe"
    assert "absent" in result.stderr
