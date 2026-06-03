import json, os
from mpmath import mp, besseli, mpf, nstr
mp.dps = 30  # well beyond 15 significant digits
ORDERS = [0, 1, 2, 3, 4, 5]
XS = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 10.0]
def sym_of(n: int) -> int:
    # honesty note: this is the USER'S stipulated label, not a derived fact:
    # n in {0,1} -> Sym=1 (critical); n>=2 -> Sym=2.
    return 1 if n in (0, 1) else 2
cases = []
for n in ORDERS:
    for x in XS:
        v = besseli(n, mpf(repr(x)))             # I_n(x) at 30-dp
        tv15 = nstr(v, 15)                        # 15 significant digits (string)
        cases.append({
            "n": n,
            "x": x,
            "sym": sym_of(n),
            "true_value": float(v),               # IEEE double (~16 sig)
            "true_value_15dp": tv15,              # 15-significant-digit decimal
        })
out = os.path.join(os.path.dirname(__file__), "BesselI_TEST_SET.json")
with open(out, "w") as f:
    json.dump(cases, f, indent=2)
print(f"wrote {len(cases)} cases -> {out}")
print("grid:", len(ORDERS), "orders x", len(XS), "x-values =", len(ORDERS)*len(XS))
