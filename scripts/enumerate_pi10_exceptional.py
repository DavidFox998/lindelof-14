#!/usr/bin/env python3
"""Enumerate the exceptional primes of alpha = pi/10 up to a bound (default 10^4000).

A prime p is *exceptional* for alpha0 = 299 + pi/10 iff  ||p*alpha0|| < 1/p,
where ||x|| is the distance from x to the nearest integer. Because 299*p is an
integer this reduces to  ||p*(pi/10)|| < 1/p.

Why this search is complete and free of false positives
-------------------------------------------------------
By Legendre's theorem, any q with ||q*alpha|| < 1/(2q) must be the denominator
of a convergent of alpha. Moreover EVERY convergent denominator q_n of alpha is
exceptional, because  ||q_n*alpha|| < 1/q_{n+1} < 1/q_n. The only other
exceptional denominators are certain upper semiconvergents. So instead of
guessing random integers (which produces mostly false positives), we enumerate
the convergents and semiconvergents of pi/10 *exactly* with integer continued
fractions, test each against the exact integer inequality  q*||q*alpha|| < 1,
and run a BPSW primality test (sympy.isprime) only on the (few) survivors.

pi is computed to D decimal digits with exact integer Chudnovsky arithmetic.
The continued fraction is reliable while convergent denominators stay below
~10^(D/2); D is chosen well above 2*log10(BOUND), so every candidate <= BOUND
lies inside the trustworthy region.

Usage
-----
  python3 scripts/enumerate_pi10_exceptional.py [BOUND_EXP]
        Single-shot full run (p <= 10^BOUND_EXP, default 4000). Needs enough
        wall time to BPSW every survivor (~10 min for 10^4000 on 4 cores).

Resumable mode (for time-limited shells; each pass checkpoints and exits):
  python3 scripts/enumerate_pi10_exceptional.py --collect BOUND_EXP
  python3 scripts/enumerate_pi10_exceptional.py --primality [BUDGET_SECONDS]
  python3 scripts/enumerate_pi10_exceptional.py --finalize
"""
import sys
import os
import json
import time
import math

# Residues nn can reach ~10^(D+1) (~8300 digits); lift CPython's str<->int cap.
sys.set_int_max_str_digits(1_000_000)

WORK = "data/_pi10_work.json"        # collected survivors + metadata
PART = "data/_pi10_partial.json"     # primality results checkpoint (index -> 0/1)
OUT = "data/pi10_exceptional_primes.txt"


def chudnovsky_pi_scaled(D):
    """Return floor(pi * 10**D) as an exact integer via the Chudnovsky series."""
    P = 10 ** D
    terms = D // 14 + 12  # ~14.18 correct digits per term
    S = 0
    f6 = f3 = f1 = 1
    c = 1
    cstep = 640320 ** 3
    for k in range(terms):
        if k > 0:
            f1 *= k
            f3 *= (3 * k - 2) * (3 * k - 1) * (3 * k)
            f6 *= (6 * k - 5) * (6 * k - 4) * (6 * k - 3) * (6 * k - 2) * (6 * k - 1) * (6 * k)
            c *= cstep
        num = ((-1) ** k) * f6 * (13591409 + 545140134 * k) * P
        den = f3 * (f1 ** 3) * c
        S += num // den
    return 426880 * math.isqrt(10005 * P * P) * P // S  # ~= pi * 10**D


def norm_str(nn, D):
    """Format nn / 10**(D+1) (= ||p*alpha||) as a short decimal string."""
    s = str(nn)
    exp = len(s) - (D + 2)  # nn / 10**(D+1); nn ~ M*10**(len-1) => exponent len-(D+2)
    mant = (s + "000000")[:6]
    return f"{mant[0]}.{mant[1:6]}e{exp}"


_SMALL_PRIMES = None


def _trial_divide_survivor(q):
    """True if q has no factor among the small primes (i.e. needs a full test)."""
    for sp in _SMALL_PRIMES:
        if sp * sp > q:
            return True
        if q % sp == 0:
            return q == sp
    return True


def _bpsw(q):
    """Module-level BPSW primality test (picklable for multiprocessing)."""
    from sympy import isprime
    return isprime(q)


def enumerate_candidates(bound_exp, D=None):
    """Exact enumeration of every exceptional denominator <= 10**bound_exp.

    Returns dict with D, cf_head, survivors [(q, nn)] (after trial division)
    and brute_small (the exceptional primes <= 10^6, for cross-validation).
    """
    global _SMALL_PRIMES
    if D is None:
        D = 2 * bound_exp + 300
    from sympy import primerange

    _SMALL_PRIMES = list(primerange(2, 10000))
    Aa = chudnovsky_pi_scaled(D)      # ~= pi * 10**D
    Ba = 10 ** (D + 1)                # so alpha = pi/10 = Aa / Ba
    assert abs((Aa * 10 ** 8) // Ba - 31415926) <= 2, "pi/10 sanity check failed"
    BOUND = 10 ** bound_exp

    # Continued fraction of Aa/Ba with convergent + semiconvergent enumeration.
    # e_k = q_k*Aa - p_k*Ba is the signed residue; |e_k|/Ba = ||q_k*alpha||.
    num, den = Aa, Ba
    a0 = num // den
    num, den = den, num - a0 * den
    q_pp, q_p = 0, 1                  # q_{-1}, q_0
    p_pp, p_p = 1, a0                 # p_{-1}, p_0
    e_pp, e_p = -Ba, Aa              # e_{-1}, e_0
    cf_head = [a0]
    cand = {}                        # q -> nn (= ||q*alpha|| * Ba), exceptional only
    min_margin = None                # min |Ba - q*nn| over all in-range candidates

    while den != 0:
        a = num // den
        num, den = den, num - a * den
        if len(cf_head) < 12:
            cf_head.append(a)
        assert a < 10 ** 8, f"unexpectedly huge partial quotient {a}; precision/logic issue"
        m = 1
        while m <= a:
            qc = m * q_p + q_pp
            if qc > BOUND:
                break
            s = m * e_p + e_pp
            rr = s % Ba
            nn = rr if rr < Ba - rr else Ba - rr
            if qc >= 2:
                # distance of the test value q*||q*alpha|| from the threshold 1,
                # scaled by Ba; certifies the rational test can't flip vs true pi/10.
                margin = abs(Ba - qc * nn)
                if min_margin is None or margin < min_margin:
                    min_margin = margin
                if qc * nn < Ba:
                    cand[qc] = nn
            m += 1
        q_k = a * q_p + q_pp
        e_k = a * e_p + e_pp
        p_k = a * p_p + p_pp
        q_pp, q_p = q_p, q_k
        p_pp, p_p = p_p, p_k
        e_pp, e_p = e_p, e_k
        if q_p > BOUND:
            break

    items = sorted(cand.items())
    survivors = [(q, nn) for q, nn in items if _trial_divide_survivor(q)]

    brute = set()
    for p in primerange(2, 10 ** 6 + 1):
        r = (p * Aa) % Ba
        nn = r if r < Ba - r else Ba - r
        if p * nn < Ba:
            brute.add(p)

    # Decision certificate: |true t - rational t| < q^2/Ba, so the rational test
    # matches true pi/10 whenever |Ba - q*nn| > q^2. Using q_max^2 as a uniform
    # conservative threshold certifies every decision for all p <= 10^bound_exp.
    threshold = 10 ** (2 * bound_exp)
    assert min_margin is not None and min_margin > threshold, (
        f"precision too low: boundary margin {min_margin} <= q_max^2 = {threshold}; "
        f"increase D"
    )

    return {
        "bound_exp": bound_exp,
        "D": D,
        "cf_head": cf_head,
        "survivors": survivors,
        "brute_small": sorted(brute),
        "min_margin": min_margin,
    }


def _validate(found, brute_small):
    sieve_small = set(q for q, _ in found if q <= 10 ** 6)
    assert set(brute_small) == sieve_small == {2, 3, 19, 191}, (
        f"validation mismatch: brute={sorted(brute_small)} sieve={sorted(sieve_small)}"
    )


def write_output(found, cf_head, D, bound_exp, min_margin):
    margin_digits = len(str(min_margin))
    header = [
        "# Exceptional primes of alpha = pi/10   (equivalently alpha0 = 299 + pi/10)",
        "# Condition:  ||p * pi/10|| < 1/p     ( ||x|| = distance to nearest integer )",
        f"# Bound:      p <= 10^{bound_exp}",
        "# Method:     exact CF convergents + upper-semiconvergents of pi/10;",
        "#             integer exceptional test; primality by trial division + sympy BPSW.",
        f"# pi:         {D} decimal digits (integer Chudnovsky); |pi/10 - Aa/Ba| < 10^-{D + 1}.",
        f"# CF(pi/10):  {cf_head} ...",
        "# Completeness: by Legendre/best-approximation theory every q with",
        "#             ||q*alpha|| < 1/q is a convergent or upper-semiconvergent of",
        "#             pi/10; all of these <= bound are enumerated and tested exactly.",
        "# Decision certificate: for every candidate |Ba - q*nn| > q^2, while the",
        f"#             pi-truncation perturbs the test value by < q^2/Ba; min margin",
        f"#             ~ 10^{margin_digits - 1} >> threshold 10^{2 * bound_exp}, so the",
        "#             rational test provably agrees with true pi/10 over the whole range.",
        "# Primality:  BPSW (sympy.isprime) -- no known counterexample, but NOT a formal",
        "#             primality certificate for the large (3000+ digit) entries.",
        f"# Count:      {len(found)}",
        "#",
        "# idx  digits   ||p*pi/10||     prime",
    ]
    body = [
        f"{i:>3}  {len(str(q)):>5}   {norm_str(nn, D):>12}   {q}"
        for i, (q, nn) in enumerate(found, 1)
    ]
    with open(OUT, "w") as fh:
        fh.write("\n".join(header + body) + "\n")

    print(f"count={len(found)}  bound=10^{bound_exp}  pi_digits={D}")
    print(f"CF(pi/10) head: {cf_head}")
    for i, (q, nn) in enumerate(found, 1):
        d = len(str(q))
        disp = str(q) if d <= 40 else f"{str(q)[:24]}...{str(q)[-8:]}"
        print(f"  #{i:>2}  {d:>4} digits   ||p*alpha||={norm_str(nn, D)}   {disp}")
    print("self-check p<=10^6 == {2,3,19,191}: OK")
    print(f"written: {OUT}")


def run(bound_exp):
    """Single-shot full run (collect + parallel BPSW + finalize)."""
    info = enumerate_candidates(bound_exp)
    qs = [q for q, _ in info["survivors"]]
    try:
        from multiprocessing import Pool
        with Pool() as pool:
            flags = pool.map(_bpsw, qs, chunksize=8)
    except Exception:
        flags = [_bpsw(q) for q in qs]
    found = sorted((q, nn) for (q, nn), f in zip(info["survivors"], flags) if f)
    _validate(found, info["brute_small"])
    write_output(found, info["cf_head"], info["D"], bound_exp, info["min_margin"])


def cmd_collect(bound_exp):
    info = enumerate_candidates(bound_exp)
    payload = {
        "bound_exp": bound_exp,
        "D": info["D"],
        "cf_head": info["cf_head"],
        "brute_small": info["brute_small"],
        "min_margin": str(info["min_margin"]),
        "survivors": [[str(q), str(nn)] for q, nn in info["survivors"]],
    }
    with open(WORK, "w") as fh:
        json.dump(payload, fh)
    if os.path.exists(PART):
        os.remove(PART)
    print(f"[collect] bound=10^{bound_exp} D={info['D']} "
          f"survivors={len(info['survivors'])} cf_head={info['cf_head']}")


def cmd_primality(budget=95.0):
    with open(WORK) as fh:
        w = json.load(fh)
    surv = w["survivors"]
    N = len(surv)
    done = {}
    if os.path.exists(PART):
        with open(PART) as fh:
            done = json.load(fh)

    todo = [i for i in range(N) if str(i) not in done]
    from multiprocessing import Pool
    pool = Pool()
    t0 = time.time()
    processed = 0
    BATCH = 16
    i = 0
    while i < len(todo) and time.time() - t0 < budget:
        batch = todo[i:i + BATCH]
        qs = [int(surv[j][0]) for j in batch]
        flags = pool.map(_bpsw, qs, chunksize=4)
        for j, f in zip(batch, flags):
            done[str(j)] = 1 if f else 0
        with open(PART, "w") as fh:
            json.dump(done, fh)
        i += len(batch)
        processed += len(batch)
    pool.close()
    pool.join()
    remaining = N - len(done)
    print(f"[primality] processed={processed} done={len(done)}/{N} "
          f"remaining={remaining} elapsed={time.time() - t0:.0f}s")
    return remaining


def cmd_finalize():
    with open(WORK) as fh:
        w = json.load(fh)
    with open(PART) as fh:
        done = json.load(fh)
    surv = w["survivors"]
    missing = [i for i in range(len(surv)) if str(i) not in done]
    assert not missing, f"{len(missing)} survivors not yet tested; run --primality again"
    found = sorted(
        (int(surv[i][0]), int(surv[i][1]))
        for i in range(len(surv)) if done[str(i)] == 1
    )
    _validate(found, w["brute_small"])
    write_output(found, w["cf_head"], w["D"], w["bound_exp"], int(w["min_margin"]))


def main():
    args = sys.argv[1:]
    if args and args[0] == "--collect":
        cmd_collect(int(args[1]))
    elif args and args[0] == "--primality":
        cmd_primality(float(args[1]) if len(args) > 1 else 95.0)
    elif args and args[0] == "--finalize":
        cmd_finalize()
    else:
        run(int(args[0]) if args else 4000)


if __name__ == "__main__":
    main()
