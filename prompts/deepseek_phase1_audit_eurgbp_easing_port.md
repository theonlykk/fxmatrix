# Phase 1 Audit Request — EURGBP Depth-Triggered Easing Port

## Role reminder
This is a Phase 1 Red Team submission per ARCHITECT.md. Mechanical and
mathematical audit only — no implementation code in the response. This
is not an open-ended design critique; the direction has already had a
first pass from the Staff Architect. The ask here is to hunt for
mechanical flaws, hidden call-site assumptions, and edge cases in a
specific proposed code change.

## Background
EURGBP currently has no depth-triggered easing. GBPUSD (locked at 1/3,
ADR-097) and EURUSD (locked at 1/4, ADR-098) both ramp
`InpSpreadMultiplier` via a shared helper, `V2_EffectiveSpreadMultiplier`,
wrapped in `V2_L0DynamicHalfSpread` (which adds a passivity floor —
`MathMax` against live spread + buffer — introduced alongside the ramp
in ADR-097).

EURGBP's signal path is structurally different from both: it routes
through a dual-sigma AB-slot formula rather than the single-sigma
BC-slot path GBPUSD/EURUSD share:

```
dynamic_hs = quote_spread + MathMax(sig_ac, sig_bc) * spread_multiplier
bid_theoretical   = ratio * MathExp(inst_spread - dynamic_hs)
offer_theoretical = ratio * MathExp(inst_spread + dynamic_hs)
```

## Proposed change
`MathMax(sig_ac, sig_bc)` already plays the same role `sigma` plays in
the BC-slot formula — it is the volatility term the ramp multiplies.
The proposed substitution does not touch the two-leg structure at all:

```
effective_multiplier = InpSpreadMultiplier
if (quoting side flat):
   effective_multiplier = V2_EffectiveSpreadMultiplier(
      opposite_depth,
      InpEaseDepthStart,
      InpEaseDepthFull,
      InpSpreadMultiplier,
      InpSpreadMultiplierEased)
dynamic_hs = quote_spread + MathMax(sig_ac, sig_bc) * effective_multiplier
```

`V2_EffectiveSpreadMultiplier` is the identical function already
committed for GBPUSD/EURUSD (linear ramp, explicit double cast per the
integer-division fix from the original ADR-097 audit). `opposite_depth`
is `ArraySize` of the opposite side's own position layers — this is
unaffected by the AC/BC leg structure, since depth tracks EURGBP's own
book, not the legs used to derive fair value.

**Deliberately out of scope for this pass:** the passivity floor
(`V2_L0DynamicHalfSpread`'s `MathMax` against live spread + buffer).
EURGBP's current formula has no such floor. Adding both the ramp and a
new floor simultaneously would bundle two independent changes into one
feature — audit the ramp addition alone; the floor is a separate,
later decision if data suggests EURGBP needs one.

## Explicit questions for Red Team critique

1. **Sigma-swap interaction.** `sig_ac` and `sig_bc` can presumably swap
   which one is larger from bar to bar. Does combining that with a
   ramping `effective_multiplier` (which itself depends on
   `opposite_depth`, a separate and independent state variable) risk
   producing quote discontinuity or flicker that wouldn't occur in the
   single-sigma pairs, where only one term is being scaled?

2. **Floor omission risk.** Does the absence of a passivity floor
   create a live-spread-collapse risk that the ramp specifically makes
   worse (e.g. does easing toward `InpSpreadMultiplierEased=0.0` at
   full opposite depth, with no floor, ever let `dynamic_hs` collapse
   to something unsafe given `MathMax(sig_ac, sig_bc)` behavior
   specifically) — or is this a pre-existing risk in EURGBP's formula
   independent of this change?

3. **Ease-depth boundary edge cases.** At `opposite_depth` exactly equal
   to `InpEaseDepthStart` or `InpEaseDepthFull`, is there anything
   specific to the dual-sigma path (versus the already-verified
   single-sigma pairs) that could behave differently?

4. **Hidden call-site assumptions.** Does anything else in
   `fxmatrix_v2_eurgbp.mq5` reference `sig_ac`, `sig_bc`, or the
   pre-ramp `spread_multiplier` directly, in a way this substitution
   would silently miss or leave inconsistent (e.g. telemetry, DIAG
   logging, or a second call site that wasn't part of the proposed
   snippet above)?

5. **Integer-division and cast check.** Confirm the exact same
   integer-division trap that was originally caught in ADR-097 cannot
   recur here — this is reusing the same helper function, but confirm
   nothing about EURGBP's call site reintroduces an untyped division.

## What Red Team must NOT do
Do not write implementation code. Do not propose calibration values
(no threshold numbers) — that is a separate step after this design is
approved and implemented. Flag anything that should block this from
proceeding to a formal Cursor implementation prompt.
