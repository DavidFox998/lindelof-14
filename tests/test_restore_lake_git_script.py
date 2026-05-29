"""Smoke test for the wiped-worktree heal path of
``scripts/restore-lake-git.sh`` (Task #192).

Task #172 patched the script to rehydrate a Lake package's working
tree when ``.git/`` is intact at the manifest-pinned rev but the
tracked files themselves have been deleted (the failure mode that bit
the ``towers-build`` workflow three times: ``lake build`` silently
wipes the worktree under ``.lake/packages/mathlib/`` between builds,
leaving ``.git/`` behind). The fix lives in the
``if [ "$cur" = "$rev" ]`` branch: it counts ``^ D `` deletions via
``git status --porcelain`` and, when any are present, runs
``git checkout -- .`` to repopulate the worktree from the vendored
objects.

There was no automated test that this heal path actually fires — a
future refactor of the script could silently drop the deletion check
and we'd only discover it the next time ``towers-build`` failed. This
module builds a throwaway fixture that mimics the wiped state (a
package directory with ``.git/`` at the pinned rev and *no*
working-tree files), runs the real script against it, and asserts the
tracked files come back and the script exits 0.

To keep the smoke test fast and self-contained it drives a single
small vendored package (``Cli``, ~120 KB tar) through the
``RESTORE_LAKE_PACKAGES_DIR`` / ``RESTORE_LAKE_TARS_DIR`` /
``RESTORE_LAKE_PKGS`` env-var overrides rather than the full ~20 MB
8-package set.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "restore-lake-git.sh"

# A small vendored package used as the fixture source. Its committed
# tar carries only `.git/`; the rev must match the entry in the
# script's PKGS array (and `lean-proof-towers/lake-manifest.json`).
FIXTURE_PKG = "Cli"
FIXTURE_URL = "https://github.com/leanprover/lean4-cli"
FIXTURE_REV = "2cf1030dc2ae6b3632c84a09350b675ef3e347d0"
SOURCE_TAR = REPO_ROOT / "lean-proof-towers" / "lake-deps" / f"{FIXTURE_PKG}.git.tar"


pytestmark = [
    pytest.mark.skipif(
        not shutil.which("git") or not shutil.which("tar"),
        reason="restore-lake-git.sh requires `git` and `tar` on PATH",
    ),
    pytest.mark.skipif(
        not SOURCE_TAR.exists(),
        reason=f"fixture source tar missing: {SOURCE_TAR}",
    ),
]


def _git(pkg_dir: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(pkg_dir), *args],
        check=True,
        capture_output=True,
        text=True,
    )


def _build_wiped_fixture(tmp_path: Path) -> tuple[Path, Path, Path]:
    """Create a throwaway lake layout whose single package mimics the
    wiped state: ``.git/`` present at the pinned rev, every tracked
    working-tree file deleted.

    Returns ``(packages_dir, tars_dir, pkg_dir)``.
    """

    packages_dir = tmp_path / "packages"
    tars_dir = tmp_path / "lake-deps"
    pkg_dir = packages_dir / FIXTURE_PKG
    pkg_dir.mkdir(parents=True)
    tars_dir.mkdir(parents=True)

    # The heal path re-extracts only if `.git/` is gone, so the fixture
    # also needs the tar available at the overridden TARS_DIR for the
    # script's other branches; copy it across.
    shutil.copy2(SOURCE_TAR, tars_dir / f"{FIXTURE_PKG}.git.tar")

    # Lay down a real `.git/` at the pinned rev from the vendored tar,
    # then populate the worktree exactly as Lake would.
    subprocess.run(
        ["tar", "-xf", str(SOURCE_TAR), "-C", str(pkg_dir)],
        check=True,
        capture_output=True,
        text=True,
    )
    assert (pkg_dir / ".git").is_dir(), "tar did not yield a .git/ directory"
    _git(pkg_dir, "checkout", "-f", FIXTURE_REV)
    assert _git(pkg_dir, "rev-parse", "HEAD").stdout.strip() == FIXTURE_REV

    # Simulate the `lake build` wipe: remove every worktree entry except
    # `.git/`, leaving the repo metadata intact at the pinned rev.
    for entry in pkg_dir.iterdir():
        if entry.name == ".git":
            continue
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry)
        else:
            entry.unlink()

    return packages_dir, tars_dir, pkg_dir


def _run_script(packages_dir: Path, tars_dir: Path) -> subprocess.CompletedProcess[str]:
    env = {
        # Inherit PATH etc. from the parent process.
        **dict(__import__("os").environ),
        "RESTORE_LAKE_PACKAGES_DIR": str(packages_dir),
        "RESTORE_LAKE_TARS_DIR": str(tars_dir),
        "RESTORE_LAKE_PKGS": f"{FIXTURE_PKG}|{FIXTURE_URL}|{FIXTURE_REV}",
    }
    return subprocess.run(
        ["bash", str(SCRIPT_PATH)],
        env=env,
        capture_output=True,
        text=True,
    )


def test_heal_path_restores_wiped_worktree(tmp_path):
    packages_dir, tars_dir, pkg_dir = _build_wiped_fixture(tmp_path)

    # Sanity: the fixture really is in the wiped state the heal path
    # targets — `.git/` intact at the pinned rev, tracked files gone,
    # `git status` reporting `^ D ` deletions. Without this guard the
    # test could pass against an already-restored tree and never
    # exercise the `git checkout -- .` branch at all.
    porcelain = _git(pkg_dir, "status", "--porcelain").stdout.splitlines()
    deletions = [ln for ln in porcelain if ln.startswith(" D ")]
    assert deletions, (
        "fixture is not in the wiped state; no `^ D ` deletions to heal: "
        f"{porcelain!r}"
    )
    worktree_before = [p.name for p in pkg_dir.iterdir() if p.name != ".git"]
    assert worktree_before == [], (
        f"fixture worktree should be empty before heal, found: {worktree_before!r}"
    )

    result = _run_script(packages_dir, tars_dir)

    assert result.returncode == 0, (
        f"restore-lake-git.sh exited {result.returncode}; "
        f"stdout={result.stdout!r} stderr={result.stderr!r}"
    )

    # Every tracked file must be back on disk and the tree clean.
    after_porcelain = _git(pkg_dir, "status", "--porcelain").stdout.strip()
    assert after_porcelain == "", (
        f"worktree still dirty after heal: {after_porcelain!r}"
    )
    worktree_after = sorted(p.name for p in pkg_dir.iterdir() if p.name != ".git")
    assert worktree_after, "heal path did not repopulate any worktree files"
    # HEAD must remain pinned — the heal must not move the checkout.
    assert _git(pkg_dir, "rev-parse", "HEAD").stdout.strip() == FIXTURE_REV


def test_heal_path_is_idempotent_on_intact_worktree(tmp_path):
    """A second run against an already-healed tree must stay green and
    exit 0 — the script is the prerequisite for every Lake op and runs
    on every ``check-towers.sh`` invocation, so it must be a no-op when
    nothing is wrong."""

    packages_dir, tars_dir, pkg_dir = _build_wiped_fixture(tmp_path)

    first = _run_script(packages_dir, tars_dir)
    assert first.returncode == 0, (
        f"first run failed: stdout={first.stdout!r} stderr={first.stderr!r}"
    )

    second = _run_script(packages_dir, tars_dir)
    assert second.returncode == 0, (
        f"idempotent re-run failed: stdout={second.stdout!r} stderr={second.stderr!r}"
    )
    assert _git(pkg_dir, "status", "--porcelain").stdout.strip() == ""
