#!/usr/bin/env python3
"""
Z_POLYMER_TEST — random 1D binary polymer configs via random.choice ONLY.

No external API calls. Each config is a binary string (0/1 monomers) built
purely with random.choice; recorded features: L (length), zero_run (longest
run of 0s), sym (stipulated label = 1), and decimal_value = int(bits, 2).
Seed is disclosed so the CSV is reproducible.

Output: Z_POLYMER_TEST.csv
"""
import os, csv, random

HERE = os.path.dirname(os.path.abspath(__file__))
SEED = 143
N_CONFIGS = 100
LENGTHS = [8, 16, 24, 32, 40]


def longest_zero_run(s: str) -> int:
    best = cur = 0
    for ch in s:
        cur = cur + 1 if ch == "0" else 0
        best = max(best, cur)
    return best


def main():
    random.seed(SEED)
    rows = []
    for i in range(N_CONFIGS):
        L = random.choice(LENGTHS)
        bits = "".join(random.choice("01") for _ in range(L))
        rows.append([f"poly{i}", bits, L, longest_zero_run(bits), 1, int(bits, 2)])
    out = os.path.join(HERE, "Z_POLYMER_TEST.csv")
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "bits", "L", "zero_run", "sym", "decimal_value"])
        w.writerows(rows)
    print(f"wrote {out}: {len(rows)} rows (seed={SEED})")


if __name__ == "__main__":
    main()
