---
name: omega + nonlinear ℕ goals
description: how to close a nonlinear ℕ inequality with omega by feeding it the one nonlinear fact.
---

# omega abstracts nonlinear ℕ subterms as nonneg atoms

`omega` is linear-only, but it abstracts each nonlinear subterm (`m^2`,
`m*n`, …) as a FRESH variable and, over ℕ, knows that variable is `≥ 0`.
So a goal like `4 ≤ m^2 + n^2 + m*n + 3*m + 3*n` is closeable by `omega`
*once you supply the single nonlinear bound it can't derive itself*, e.g.

```lean
have h1 : 1 ≤ m ^ 2 := Nat.one_le_pow 2 m (Nat.pos_of_ne_zero hm)
omega   -- now: m^2 atom ≥ 1 (h1), 3*m ≥ 3 (from hm: m≠0), rest ≥ 0 ⇒ ≥ 4
```

**Why it works:** the abstracted atom for `m^2` in `h1` is the *same*
syntactic atom as in the goal, so omega links them; everything else is
linear. **How to apply:** when a `ℕ` inequality is "linear except for a few
squares/products," prove the minimal `1 ≤ <that square>` (or product) facts
first, then let omega finish — no need for nlinarith and its ℕ quirks.
`Nat.one_le_pow (n m : ℕ) (h : 0 < m) : 1 ≤ m ^ n` (note arg order: exponent
first, base second).
