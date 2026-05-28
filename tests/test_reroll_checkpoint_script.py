"""Pin the stdout contract of ``scripts/reroll-checkpoint.py``.

Task #160 covers the SSE plumbing between
``POST /api/ledger/checkpoint/reroll/stream`` and the dashboard's
live-log panel by feeding *synthetic* ``STEP:`` / ``PROGRESS:`` / ``OK:``
lines through a mocked spawn. That harness never touches the real
script, so a rename like ``STEP: hashing prefix`` → ``[hash] prefix``,
a dropped trailing newline, or a reshaped final summary would let
``panel-reroll-live-log`` silently revert to "Waiting for output…"
while every existing test stayed green.

This module invokes the real script against a sandboxed copy of the
ledger and pins:

* the happy path emits at least one ``STEP: ``-prefixed line *before*
  the final summary, exits ``0``, and the last stdout line matches
  ``OK: checkpoint re-rolled (before=<int>, after=<int>) …``;
* the refuse path (existing checkpoint disagrees with the live file)
  exits ``2`` with a ``REFUSE:`` line on stderr and leaves the
  checkpoint untouched.

Task #177.
"""

from __future__ import annotations

import hashlib
import importlib.util
import re
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "reroll-checkpoint.py"

if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def _load_reroll_module():
    """Import ``scripts/reroll-checkpoint.py`` as a module so we can call
    its ``main()`` in-process and capture ``flush=True`` stdout via
    ``capsys``. The script is hyphenated, so ``importlib.util`` is the
    least-magical loader."""

    spec = importlib.util.spec_from_file_location(
        "reroll_checkpoint_under_test", SCRIPT_PATH
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _sandbox_kernel(monkeypatch, tmp_path, *, valid_checkpoint: bool):
    """Point ``kernel.HITS`` / ``kernel.CHECKPOINT`` at a throwaway dir
    so the test never rewrites the real ``data/hits.txt.checkpoint``.

    With ``valid_checkpoint=True`` the sidecar matches the live bytes
    and ``_verify_checkpoint`` passes (happy path). With ``False`` the
    sidecar records a bogus SHA so ``_verify_checkpoint`` raises and
    the script must take the REFUSE branch."""

    import kernel

    hits = tmp_path / "hits.txt"
    payload = b"sandbox-hits-line-1\nsandbox-hits-line-2\nsandbox-hits-line-3\n"
    hits.write_bytes(payload)

    checkpoint = tmp_path / "hits.txt.checkpoint"
    if valid_checkpoint:
        sha = hashlib.sha256(payload).hexdigest()
        checkpoint.write_text(f"{len(payload)} {sha}\n", encoding="utf-8")
    else:
        # Same size as the live file but a SHA that cannot match —
        # `_verify_checkpoint` raises `LedgerIntegrityError` and the
        # script must exit 2 without touching the sidecar.
        checkpoint.write_text(f"{len(payload)} {'0' * 64}\n", encoding="utf-8")

    monkeypatch.setattr(kernel, "HITS", hits)
    monkeypatch.setattr(kernel, "CHECKPOINT", checkpoint)
    return hits, checkpoint


_OK_LINE_RE = re.compile(
    r"^OK: checkpoint re-rolled \(before=\d+, after=\d+\)(?: checkpoint=.+)?$"
)


def test_reroll_script_happy_path_emits_step_then_ok(monkeypatch, tmp_path, capsys):
    hits, checkpoint = _sandbox_kernel(monkeypatch, tmp_path, valid_checkpoint=True)
    module = _load_reroll_module()

    rc = module.main()
    captured = capsys.readouterr()

    assert rc == 0, (
        f"expected exit 0 on happy path, got {rc}; "
        f"stdout={captured.out!r} stderr={captured.err!r}"
    )

    lines = [ln for ln in captured.out.splitlines() if ln]
    assert lines, f"expected progress output, got nothing; stderr={captured.err!r}"

    # At least one `STEP: ` line must appear strictly before the final
    # summary — that is what keeps the dashboard's live-log panel out
    # of "Waiting for output…" while the SHA-256 pass runs.
    assert any(ln.startswith("STEP: ") for ln in lines[:-1]), (
        "no `STEP: ` line before the final summary; the dashboard's "
        f"live-log panel would stay blank. stdout={captured.out!r}"
    )

    # The final line is the OK summary in the exact shape the
    # non-stream endpoint parses verbatim.
    assert _OK_LINE_RE.match(lines[-1]), (
        f"final stdout line does not match the OK contract: {lines[-1]!r}"
    )

    # And the sidecar was actually rewritten to match the live file.
    expected_sha = hashlib.sha256(hits.read_bytes()).hexdigest()
    size_str, sha_str = checkpoint.read_text(encoding="utf-8").split()
    assert int(size_str) == hits.stat().st_size
    assert sha_str.lower() == expected_sha


def test_reroll_script_refuses_when_existing_checkpoint_fails(
    monkeypatch, tmp_path, capsys
):
    _, checkpoint = _sandbox_kernel(monkeypatch, tmp_path, valid_checkpoint=False)
    before_bytes = checkpoint.read_bytes()
    module = _load_reroll_module()

    rc = module.main()
    captured = capsys.readouterr()

    assert rc == 2, (
        f"expected exit 2 on refuse path, got {rc}; "
        f"stdout={captured.out!r} stderr={captured.err!r}"
    )
    assert "REFUSE:" in captured.err, (
        f"expected a REFUSE line on stderr; stderr={captured.err!r}"
    )
    # The script must never overwrite a checkpoint that already fails
    # verification — that is the whole point of the refuse branch.
    assert checkpoint.read_bytes() == before_bytes, (
        "refuse-path must leave the existing checkpoint untouched"
    )
