"""Tests that pin the Genesis-seal tamper-evidence guarantees.

These tests assert that:
  * `scripts/check-genesis-seal.py` exits non-zero on byte flips, line
    swaps, and pre-marker insertions in `data/hits.txt`.
  * The unmodified `data/hits.txt` still passes the seal check.
  * `lean_bridge._guard` refuses any rendered Lean text containing
    `axiom `, `sorry`, or `admit ` (defence-in-depth against template
    tampering), and `_genesis_integers` never lifts a non-numeric line
    like `axiom foo` into a generated lemma.
  * `kernel.probe()` aborts (RuntimeError) before any line is appended
    when the Genesis preamble of `data/hits.txt` is tampered.

Run from the repo root: `pytest tests/test_morningstar.py -q`.
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
HITS = REPO_ROOT / "data" / "hits.txt"
SCRIPT = REPO_ROOT / "scripts" / "check-genesis-seal.py"
SEAL_MARKER = "--- GENESIS SEAL ---"


# ---------- helpers ----------

def _run_seal_check() -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT)],
        capture_output=True,
        text=True,
    )


@pytest.fixture
def hits_backup():
    """Back up data/hits.txt and restore it no matter what the test does.

    Tests that need to mutate the real hits.txt in-place (because the
    seal-check script and kernel.probe both read from the hard-coded
    path) request this fixture and write their tampered bytes in the
    test body. Restore is guaranteed via finally even if the test
    crashes between tampering and assertion.
    """
    original = HITS.read_bytes()
    try:
        yield original
    finally:
        HITS.write_bytes(original)


def _atomic_write_bytes(path: Path, data: bytes) -> None:
    """Replace `path`'s contents atomically via a sibling tempfile + os.replace.

    `Path.write_text` / `Path.write_bytes` open in 'w'/'wb' mode, which
    truncates the file to zero bytes BEFORE the new content is written.
    Any concurrent reader (e.g. the live `zeta-burst` workflow calling
    `kernel._verify_seal`) that opens the file inside that window sees
    an empty file with no Genesis-seal marker — see
    `docs/CHANGELOG.md` task #52. `os.replace` is POSIX-atomic on the
    same filesystem, so concurrent readers see either the old bytes
    or the new bytes, never a torn intermediate state.
    """
    tmp = path.with_name(path.name + ".tamper.tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def _tamper_and_run(original: bytes, mutate) -> subprocess.CompletedProcess[str]:
    """Apply `mutate` to the file's text, run the seal check, restore.

    Restore happens before returning so callers don't have to worry
    about ordering — the file is back to pristine state on return.
    The fixture also restores as a second line of defence.
    """
    try:
        text = original.decode("utf-8")
        _atomic_write_bytes(HITS, mutate(text).encode("utf-8"))
        return _run_seal_check()
    finally:
        _atomic_write_bytes(HITS, original)


# ---------- check-genesis-seal.py: positive control ----------

def test_unmodified_hits_passes_seal():
    r = _run_seal_check()
    assert r.returncode == 0, (
        f"seal check failed on pristine hits.txt:\n"
        f"stdout={r.stdout!r}\nstderr={r.stderr!r}"
    )
    assert "Genesis seal verified" in r.stdout


# ---------- check-genesis-seal.py: tamper detection ----------

def test_flip_byte_in_line3_fails(hits_backup):
    def mutate(text: str) -> str:
        lines = text.split("\n")
        # Line 3 (1-indexed) is part of the immutable comment header.
        # Flip one letter to change exactly one byte of the preamble.
        assert lines[2].startswith("#"), "line 3 should be a comment in the preamble"
        lines[2] = lines[2].replace("a", "A", 1)
        return "\n".join(lines)

    r = _tamper_and_run(hits_backup, mutate)
    assert r.returncode != 0, "seal check must reject a one-byte flip in line 3"
    assert "Genesis seal mismatch" in (r.stderr + r.stdout)


def test_swap_genesis_lines_fails(hits_backup):
    def mutate(text: str) -> str:
        lines = text.split("\n")
        # Lines 5 and 6 (1-indexed) are the "437" and "1094" Genesis lines.
        assert lines[4] == "437" and lines[5] == "1094", (
            f"expected 437/1094 at lines 5/6, got {lines[4]!r}/{lines[5]!r}"
        )
        lines[4], lines[5] = lines[5], lines[4]
        return "\n".join(lines)

    r = _tamper_and_run(hits_backup, mutate)
    assert r.returncode != 0, "seal check must reject swapped Genesis lines"
    assert "Genesis seal mismatch" in (r.stderr + r.stdout)


def test_insert_line_before_marker_fails(hits_backup):
    def mutate(text: str) -> str:
        assert SEAL_MARKER in text
        return text.replace(SEAL_MARKER, f"INJECTED=evil\n{SEAL_MARKER}", 1)

    r = _tamper_and_run(hits_backup, mutate)
    assert r.returncode != 0, "seal check must reject a line inserted before the marker"
    assert "Genesis seal mismatch" in (r.stderr + r.stdout)


# ---------- lean_bridge guard ----------

def test_lean_bridge_guard_rejects_axiom():
    import lean_bridge
    with pytest.raises(SystemExit) as ei:
        lean_bridge._guard("theorem foo : True := trivial\naxiom bar : True\n")
    assert "axiom " in str(ei.value)


def test_lean_bridge_guard_rejects_sorry():
    import lean_bridge
    with pytest.raises(SystemExit) as ei:
        lean_bridge._guard("theorem foo : True := sorry\n")
    assert "sorry" in str(ei.value)


def test_lean_bridge_guard_rejects_admit():
    import lean_bridge
    with pytest.raises(SystemExit) as ei:
        lean_bridge._guard("theorem foo : True := by admit \n")
    assert "admit " in str(ei.value)


def test_lean_bridge_guard_allows_comment_mentioning_axiom():
    """The header literally says 'Axiom debt is []' — that must not trip the guard."""
    import lean_bridge
    # _render uses the real HEADER which contains the word "Axiom".
    rendered = lean_bridge._render([437, 1094])
    lean_bridge._guard(rendered)  # must not raise


def test_lean_bridge_skips_non_numeric_genesis_lines(tmp_path, monkeypatch):
    """Even if hits.txt is tampered to contain 'axiom foo' as a Genesis
    line, the bridge must not lift it into the generated Lean. This is
    the first line of defence; `_guard` is the second."""
    import lean_bridge
    fake = tmp_path / "hits.txt"
    fake.write_text(
        "axiom foo\n"
        "437\n"
        "1094\n"
        f"{SEAL_MARKER}\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(lean_bridge, "HITS", fake)
    nums = lean_bridge._genesis_integers()
    assert nums == [437, 1094]
    rendered = lean_bridge._render(nums)
    assert "axiom foo" not in rendered
    lean_bridge._guard(rendered)  # must not raise


# ---------- regression: concurrent tamper must not break a live probe loop ----------


def test_verify_seal_survives_concurrent_atomic_rewriter(hits_backup):
    """Task #52 regression: while the morningstar-tamper test fixture is
    rewriting `data/hits.txt` in a loop, a concurrent `kernel._verify_seal`
    call (the inner loop of `zeta_burst`) must NOT raise.

    Before the fix:
      - the fixture used `Path.write_text`, which truncates the file
        before writing — readers saw an empty file with no Genesis
        marker, so `_verify_seal` raised
        `'--- GENESIS SEAL ---' is not in list`.
      - any kernel.probe / zeta_burst running alongside
        morningstar-tamper failed immediately, even though the on-disk
        seal was intact.

    After the fix:
      - the fixture writes via `_atomic_write_bytes` (sibling tempfile
        + os.replace), so readers see either the old or the new bytes.
      - `_verify_seal` also retries a few times to absorb any other
        transient mid-write reader (defence in depth).
    """
    import kernel

    original = hits_backup
    # Mutation preserves the marker — the seal still verifies on the
    # tampered bytes' content for the *file existence* test; what we
    # care about is that the kernel never sees a truncated read.
    tampered = original  # identity mutation is enough: this isolates
    # the race itself (atomic vs truncate-then-write) from any
    # hash-mismatch noise.

    stop = threading.Event()
    errors: list[BaseException] = []

    def rewriter() -> None:
        try:
            while not stop.is_set():
                _atomic_write_bytes(HITS, tampered)
                _atomic_write_bytes(HITS, original)
        except BaseException as e:  # noqa: BLE001
            errors.append(e)

    t = threading.Thread(target=rewriter, daemon=True)
    t.start()
    try:
        deadline = time.monotonic() + 1.0
        iterations = 0
        while time.monotonic() < deadline:
            kernel._verify_seal()
            iterations += 1
        assert iterations > 50, (
            f"sanity: expected many _verify_seal cycles in 1s, got {iterations}"
        )
    finally:
        stop.set()
        t.join(timeout=2.0)
    assert not errors, f"rewriter thread crashed: {errors}"


# ---------- kernel.probe must abort on tampered Genesis ----------

def test_probe_refuses_to_append_when_seal_fails(hits_backup):
    """kernel.probe() runs the seal check before any append. A tampered
    Genesis must raise RuntimeError *before* hits.txt grows by even one
    byte."""
    import kernel

    text = hits_backup.decode("utf-8")
    lines = text.split("\n")
    assert lines[2].startswith("#")
    lines[2] = lines[2].replace("a", "Q", 1)
    tampered = "\n".join(lines).encode("utf-8")
    HITS.write_bytes(tampered)

    size_before = HITS.stat().st_size

    with pytest.raises(RuntimeError, match="Genesis seal verification failed"):
        kernel.probe(1, 1, 0.5, 0.0)

    size_after = HITS.stat().st_size
    assert size_after == size_before, (
        "probe must not append to hits.txt when the Genesis seal fails; "
        f"size grew from {size_before} to {size_after}"
    )
