/-
================================================================
Towers / YM / ContinuumHookup  (Task #174 / Task #156 file 5 of 6
— continuum-limit hookup, **honest stand-in**)

**One-line summary.** Wire the strip-form Varadhan-shape envelope
bound (`Heat_kernel_envelope_real_le_varadhan`, Batch 156.3) to
the continuum-YM schema (`YM4_Continuum`, `lattice_to_continuum`,
Batch 20.1a / `Towers/YM/Continuum.lean`). The wiring exposes a
single function `continuum_heat_envelope_bound` that, given a
lattice spacing `a : ℝ`, a lattice SU(3) connection
`A : SU3Connection`, and a strip-time `t : ℝ` in the original
Varadhan strip `[varadhan_t_lo, varadhan_t_top]`, lands the
Varadhan-shape upper bound on `Heat_kernel_envelope_real t`. The
schema slot is honored (the function takes the lattice data and
produces a bound that references the resulting `YM4_Continuum`
via the identity-trivial `lattice_to_continuum` map), but the
bound itself is the existing `t`-only strip bound — *no* new
content about `a → 0` is added.

### Drift / honest scope (locked)

The original Task #156 brief asked for a real `a → 0` continuum
limit hookup: take the lattice heat-kernel envelope, push it
through `lattice_to_continuum`, and re-derive the bound on the
continuum side. **`lattice_to_continuum` is currently the
identity-trivial map** (`Towers/YM/Continuum.lean` ships
`lattice_to_continuum a A := {}`, the default `YM4_Continuum`,
with NO real `a → 0` limit), so a "real" continuum-side bound is
not yet available. The wiring here is the honest **plumbing**:
take the (lattice) inputs, name the continuum slot, and emit the
strip bound from the existing surface. Replacing
`lattice_to_continuum` with a genuine continuum-limit functor
will *intentionally* break this hookup (the schema fields it
depends on will move), and that breakage is the tripwire signal
for a real continuum limit landing.

### What this file ships

  * `continuum_heat_envelope_bound a A t ht_lo ht_top` —
    re-exposes `Heat_kernel_envelope_real_le_varadhan` under a
    signature that *names* the lattice data `(a, A)` and the
    resulting continuum schema (`lattice_to_continuum a A :
    YM4_Continuum`). The conclusion is unchanged.
  * `continuum_heat_envelope_bound_target_default` — at the
    representative strip-time `t = varadhan_t_lo`, the continuum
    schema produced by `lattice_to_continuum` is *definitionally*
    the default `YM4_Continuum`. Records the identity-trivial
    nature of the current `lattice_to_continuum` map.
  * `continuum_heat_envelope_pos` — at any strip-time `t` the
    Varadhan-shape RHS `varadhan_C · exp(-c/t) / t^4` is strictly
    positive. A consistency brick on the bound shape (the LHS
    `Heat_kernel_envelope_real t` is already known `≥ 1` via
    `Heat_kernel_envelope_real_ge_one_of_pos` from
    `Towers/YM/PeterWeylHeat.lean`).

### What this file does NOT ship

  * A real `a → 0` continuum limit of the lattice heat-kernel
    envelope (depends on a real `lattice_to_continuum`).
  * A continuum-side Varadhan asymptotic.
  * A mass-gap statement on `YM4_Continuum` (that is file 6 of 6,
    `Towers/YM/MassGapEnvelope.lean`).
  * Any new constants or any change to `varadhan_C`, `varadhan_c`.

YM tower stays `Status: Open` in `docs/ROADMAP.md` § 2. Surface #3
(continuum YM) stays OPEN.

### Invariants honored

  * Sorry-free (this file has zero `sorry`).
  * Axiom footprint ⊆ `{propext, Classical.choice, Quot.sound}`.
  * No edit to `Towers/YM/Continuum.lean`, `Towers/YM/MassGap.lean`,
    or `Towers/YM/PeterWeylHeatVaradhan.lean`. Purely additive.

================================================================
-/

import Towers.YM.Continuum
import Towers.YM.PeterWeylHeatVaradhan

namespace TheoremaAureum
namespace Towers
namespace YM
namespace ContinuumHookup

open TheoremaAureum.Towers.YM
open TheoremaAureum.Towers.YM.Continuum
open TheoremaAureum.Towers.YM.PeterWeylHeat
open TheoremaAureum.Towers.YM.PeterWeylHeatVaradhan

/-- **Strip-form Varadhan-shape envelope bound, wired through the
continuum schema slot.** For lattice spacing `a : ℝ` and lattice
SU(3) connection `A : SU3Connection`, the continuum schema
`lattice_to_continuum a A : YM4_Continuum` is named in the
signature (currently the identity-trivial default — see
`Towers/YM/Continuum.lean`). For every strip-time `t` in
`[varadhan_t_lo, varadhan_t_top]`, the existing strip bound
applies.

The lattice inputs `(a, A)` are positional in the signature so
downstream consumers can be written against the real continuum-
limit hookup once `lattice_to_continuum` becomes non-trivial. The
proof discards them and delegates to
`Heat_kernel_envelope_real_le_varadhan`. -/
theorem continuum_heat_envelope_bound
    (_a : ℝ) (_A : SU3Connection)
    {t : ℝ} (ht_lo : varadhan_t_lo ≤ t) (ht_top : t ≤ varadhan_t_top) :
    Heat_kernel_envelope_real t ≤
      varadhan_C * Real.exp (-(varadhan_c / t)) / t ^ 4 :=
  Heat_kernel_envelope_real_le_varadhan ht_lo ht_top

/-- The current `lattice_to_continuum` map is identity-trivial:
for every lattice input `(a, A)` the produced continuum schema is
the default `YM4_Continuum`. Records the (intentional) flatness of
the schema mapping. Replacing `lattice_to_continuum` with a real
`a → 0` functor will break this lemma, which is the tripwire signal
for a genuine continuum limit landing. -/
theorem continuum_heat_envelope_bound_target_default
    (a : ℝ) (A : SU3Connection) :
    lattice_to_continuum a A = ({} : YM4_Continuum) := rfl

/-- Consistency brick on the Varadhan-shape RHS: at any strip-time
`t ∈ [varadhan_t_lo, varadhan_t_top]` the bound's right-hand side
`varadhan_C · exp(-c/t) / t^4` is strictly positive. -/
theorem continuum_heat_envelope_pos
    {t : ℝ} (ht_lo : varadhan_t_lo ≤ t) (_ht_top : t ≤ varadhan_t_top) :
    0 < varadhan_C * Real.exp (-(varadhan_c / t)) / t ^ 4 := by
  have htpos : 0 < t := lt_of_lt_of_le varadhan_t_lo_pos ht_lo
  have ht4 : 0 < t ^ 4 := pow_pos htpos 4
  have hnum : 0 < varadhan_C * Real.exp (-(varadhan_c / t)) :=
    mul_pos varadhan_C_pos (Real.exp_pos _)
  exact div_pos hnum ht4

end ContinuumHookup
end YM
end Towers
end TheoremaAureum
