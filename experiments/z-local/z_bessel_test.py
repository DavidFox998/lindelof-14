#!/usr/bin/env python3
"""
Z_BESSEL_TEST — modified Bessel I_n(x) via mpmath.besseli ONLY.

No external API calls. Pure deterministic tool computation at 30-dp, then
reported at 15 significant digits + IEEE double. sym is a STIPULATED label
(not a derived fact): n in {0,1} -> 1, else 2.

Output: Z_BESSEL_TEST.csv
"""
import os, csv
from mpmath import mp, besseli, mpf, nstr
mp.dps = 30  # well beyond 15 significant digits

HERE = os.path.dirname(os.path.abspath(__file__))
ORDERS = [0, 1, 2, 3, 4, 5]
XS = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 10.0]


def sym_of(n: int) -> int:
    return 1 if n in (0, 1) else 2


def main():
    rows = []
    for n in ORDERS:
        for x in XS:
            v = besseli(n, mpf(repr(x)))          # I_n(x) via mpmath.besseli only
            rows.append([n, x, sym_of(n), nstr(v, 15), float(v)])
    out = os.path.join(HERE, "Z_BESSEL_TEST.csv")
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["n", "x", "sym", "besseli_15dp", "besseli_float64"])
        w.writerows(rows)
    print(f"wrote {out}: {len(rows)} rows "
          f"({len(ORDERS)} orders x {len(XS)} x-values)")


if __name__ == "__main__":
    main()
