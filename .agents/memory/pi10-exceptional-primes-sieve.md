---
name: pi/10 exceptional-primes sieve (Diophantine)
description: How to rigorously enumerate ALL exceptional primes of alpha=pi/10 (||p*pi/10||<1/p) without false positives, and the honest result.
---

# Exceptional primes of alpha = pi/10  (||p*pi/10|| < 1/p)

Task surface separate from the Lean tower: enumerate every prime p with
`||p*(pi/10)|| < 1/p` up to a bound (equivalently alpha0 = 299 + pi/10, since
299*p is integral). Tool: `scripts/enumerate_pi10_exceptional.py`.

**The key mathematical move (don't brute-force / don't guess):**
- Every CONVERGENT denominator q_n of alpha is automatically exceptional
  (`||q_n*alpha|| < 1/q_{n+1} < 1/q_n`). By Legendre / best-approximation
  theory, any q with `||q*alpha|| < 1/q` is a convergent OR an upper
  semiconvergent. So enumerate the exact integer continued fraction of pi/10
  and test convergents + semiconvergents `q = m*q_p + q_pp` (m=1..a_k) only —
  NOT random integers. This is why naive "guess and test" reports are riddled
  with false positives.
- Do everything in exact integers: pi via integer Chudnovsky to D≈2*bound+300
  digits, alpha = Aa/Ba (Aa=floor(pi*10^D), Ba=10^(D+1)); residue
  e_k = q_k*Aa - p_k*Ba; `nn = min(rr, Ba-rr)` = Ba*||q*alpha||; test
  `q*nn < Ba`. Primality: trial-divide then BPSW (sympy.isprime).
- **Decision certificate** (makes completeness rigorous, not just "probably"):
  the pi-truncation perturbs the scaled test value by < q^2/Ba, so a decision
  can only flip if `|Ba - q*nn| <= q^2`. Track the min of `|Ba - q*nn|` over ALL
  candidates and assert it exceeds q_max^2 = 10^(2*bound). At bound 10^4000 the
  min margin was ~10^8295 vs threshold 10^8000 — huge, so the rational test
  provably equals the true pi/10 test over the whole range.

**Honest result:** up to 10^4000 there are exactly **20** exceptional primes:
2, 3, 19, 191, then 16 larger ones (13 → 3548 digits). Cross-validated: the
sieve's results <=10^6 equal the independent brute force {2,3,19,191}.
A circulated "v1.6" report claiming 14 was WRONG — only 3 of its 14 were
exceptional; the rest were composite truncations, and it omitted 2, 19, 191.

**Honesty caveat to always state:** BPSW has no known counterexample but is NOT
a formal primality proof for the 3000+ digit entries (ECPP/Primo certs would be
needed for that, impractical here).
