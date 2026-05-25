"""Layer 4 (Transport) — MorningStar-Lab kernel.

probe(h, N, re_s, im_s) -> dict.

Backend: mpmath (pure-Python arbitrary-precision). What we can actually
compute honestly:

- h == 1, N == 1: Riemann zeta ζ(s). Tag MPMATH_ZETA.
- h == 1, N > 1: principal Dirichlet character χ₀ mod N. We strip the
  Euler factors at primes p|N from ζ(s):
      L(s, χ₀) = ζ(s) · ∏_{p|N} (1 - p^{-s}).
  Tag MPMATH_DIRICHLET_TRIVIAL.
- h >= 2: class-group / modular L-functions are out of scope for the
  mpmath backend. The line is tagged NEEDS_SAGE and L_nonvanish is left
  as a stub (True) — the tag is the contract that says "do not trust
  this number".

Failure modes (overflow, mpmath exception, timeout-by-exception) also
fall back to NEEDS_SAGE with a reason field; the ledger never silently
lies about a backend result.

Append-only invariant: before any write, this module shells out to
scripts/check-genesis-seal.py and refuses to proceed if the Genesis
preamble of data/hits.txt has been altered.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import mpmath

REPO_ROOT = Path(__file__).resolve().parent
HITS = REPO_ROOT / "data" / "hits.txt"
SEAL_CHECK = REPO_ROOT / "scripts" / "check-genesis-seal.py"

BACKEND = "mpmath"
BACKEND_VERSION = mpmath.__version__
NONVANISH_TOL = mpmath.mpf("1e-10")


def _verify_seal() -> None:
    """Run check-genesis-seal.py; raise if it fails."""
    result = subprocess.run(
        [sys.executable, str(SEAL_CHECK)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Genesis seal verification failed (exit {result.returncode}):\n"
            f"{result.stderr.strip() or result.stdout.strip()}"
        )


def _append_line(line: str) -> None:
    """Append exactly one line + newline to hits.txt and fsync."""
    HITS.parent.mkdir(parents=True, exist_ok=True)
    with HITS.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
        f.flush()
        os.fsync(f.fileno())


def _prime_divisors(n: int) -> list[int]:
    """Distinct prime divisors of |n|, n != 0. Trial division is fine
    for the modest N used by the lab."""
    n = abs(int(n))
    if n <= 1:
        return []
    primes: list[int] = []
    d = 2
    while d * d <= n:
        if n % d == 0:
            primes.append(d)
            while n % d == 0:
                n //= d
        d += 1 if d == 2 else 2
    if n > 1:
        primes.append(n)
    return primes


def _evaluate(h: int, N: int, re_s: float, im_s: float) -> dict[str, Any]:
    """Return the backend result dict, with keys:
        tag: str           — MPMATH_ZETA | MPMATH_DIRICHLET_TRIVIAL | NEEDS_SAGE
        backend: str       — "mpmath" or "none"
        L_real, L_imag: str (or None for NEEDS_SAGE)
        L_abs: str (or None)
        L_nonvanish: bool
        reason: str (only present when tag == NEEDS_SAGE)
    """
    s = mpmath.mpc(re_s, im_s)

    if h == 1 and N == 1:
        try:
            with mpmath.workdps(50):
                val = mpmath.zeta(s)
                absval = abs(val)
            return {
                "tag": "MPMATH_ZETA",
                "backend": BACKEND,
                "L_real": mpmath.nstr(val.real, 20),
                "L_imag": mpmath.nstr(val.imag, 20),
                "L_abs": mpmath.nstr(absval, 20),
                "L_nonvanish": bool(absval > NONVANISH_TOL),
            }
        except Exception as e:  # noqa: BLE001
            return {
                "tag": "NEEDS_SAGE",
                "backend": "none",
                "L_real": None,
                "L_imag": None,
                "L_abs": None,
                "L_nonvanish": True,
                "reason": f"mpmath_zeta_failed:{type(e).__name__}",
            }

    if h == 1 and N > 1:
        try:
            with mpmath.workdps(50):
                val = mpmath.zeta(s)
                for p in _prime_divisors(N):
                    val = val * (mpmath.mpc(1) - mpmath.power(p, -s))
                absval = abs(val)
            return {
                "tag": "MPMATH_DIRICHLET_TRIVIAL",
                "backend": BACKEND,
                "L_real": mpmath.nstr(val.real, 20),
                "L_imag": mpmath.nstr(val.imag, 20),
                "L_abs": mpmath.nstr(absval, 20),
                "L_nonvanish": bool(absval > NONVANISH_TOL),
            }
        except Exception as e:  # noqa: BLE001
            return {
                "tag": "NEEDS_SAGE",
                "backend": "none",
                "L_real": None,
                "L_imag": None,
                "L_abs": None,
                "L_nonvanish": True,
                "reason": f"mpmath_dirichlet_trivial_failed:{type(e).__name__}",
            }

    return {
        "tag": "NEEDS_SAGE",
        "backend": "none",
        "L_real": None,
        "L_imag": None,
        "L_abs": None,
        "L_nonvanish": True,
        "reason": "h>=2_out_of_scope_for_mpmath_backend",
    }


def probe(h: int, N: int, re_s: float, im_s: float) -> dict[str, Any]:
    """Run a single 4D probe and append exactly one ledger line.

    Returns a dict with keys: h, N, L_nonvanish, RH_ok, tag, backend,
    L_real, L_imag, L_abs, sha, ledger_line. The `reason` key is only
    present when the backend was not able to evaluate (tag NEEDS_SAGE).
    """
    _verify_seal()

    ts = time.time_ns()
    inputs = {"h": int(h), "N": int(N), "re_s": float(re_s), "im_s": float(im_s)}

    ev = _evaluate(inputs["h"], inputs["N"], inputs["re_s"], inputs["im_s"])

    output = {
        "h": inputs["h"],
        "N": inputs["N"],
        "L_nonvanish": ev["L_nonvanish"],
        "RH_ok": inputs["re_s"] == 0.5,
        "tag": ev["tag"],
        "backend": ev["backend"],
        "L_real": ev["L_real"],
        "L_imag": ev["L_imag"],
        "L_abs": ev["L_abs"],
    }
    if "reason" in ev:
        output["reason"] = ev["reason"]

    digest_payload = {"ts": ts, "in": inputs, "out": output, "tag": ev["tag"]}
    body = json.dumps(digest_payload, sort_keys=True, separators=(",", ":"))
    sha = hashlib.sha256(body.encode("utf-8")).hexdigest()

    L_abs_field = ev["L_abs"] if ev["L_abs"] is not None else "NA"
    reason_field = f" reason={ev['reason']}" if "reason" in ev else ""
    ledger_line = (
        f"probe ts={ts} h={inputs['h']} N={inputs['N']} "
        f"re={inputs['re_s']} im={inputs['im_s']} "
        f"L_nonvanish={output['L_nonvanish']} RH_ok={output['RH_ok']} "
        f"{ev['tag']} L_abs={L_abs_field}{reason_field} sha={sha}"
    )
    _append_line(ledger_line)

    return {**output, "sha": sha, "ledger_line": ledger_line}


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("usage: kernel.py h N re_s im_s", file=sys.stderr)
        sys.exit(2)
    out = probe(int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]))
    print(json.dumps(out, sort_keys=True))
