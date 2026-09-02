This message has a line count at the bottom.

# DeepSeek Phase 1 — Round 3: Problem 3 Uniform Fill-Noise Tolerance (HALT_30)

## Round context

Third narrow audit on the same security control (HALT_30 / V2_SRE_HedgePriceIndicatesCrossPair) you reviewed in Rounds 1 and 2. Round 1: you found the grid-cancellation vector in the wide-interval rollover fix -> adopted point-estimate (ADR-107). Round 2: you found the compound rollover+spread vector AND a latent grid-boundary vector in ADR-107 itself -> adopted a grid-boundary guard (halt at 87pt) plus a zero-rollover gate on the spread allowance (ADR-108). Both shipped, locally committed.

Consequence of ADR-108: the spread-noise allowance is gated to zero-rollover (same-day) pairs ONLY. Overnight/long-hold pairs with genuine 2-7pt execution noise (normal fractional-pip slippage) get no allowance and fail closed. This blocks a fully-green Tier 1 regression gate (Cases 3/5 red). Availability issue, not security -- but we want it fixed properly, not by reintroducing a vector.

## The proposed fix (net simplification)

Instead of the special-case zero-rollover gate, lower the ADR-108 grid-boundary guard to also account for the spread allowance, then apply the allowance uniformly:

1. Guard threshold: from `G - base_tol - margin` (87pt) to `G - base_tol - max_spread_allowance - margin` (72pt, with G=90, base_tol=2, max_spread=15, margin=1).
2. Remove the zero-rollover gate; spread allowance applies to every pair passing the lowered guard.

The full spec follows below. Verified worst case: any pair reaching the check has max_shift < 72, so max_shift + base_tol + spread_allowance < 72+2+15 = 89 < 90 = one grid step. No pair receiving the allowance can reach an adjacent mispaired layer.

## The questions for this round

1. Is 89 < 90 the true worst case, or can max_spread_allowance exceed 15pt for any of EURGBP/GBPUSD/EURUSD, pushing the reach past 90?
2. Does SHORT direction (downward drift) create an asymmetry vs the LONG case computed here?
3. THE ONE I MOST WANT BROKEN: the safety argument assumes "guard did not fire" guarantees "actual drift < 72pt" -- which requires MaxPossibleRolloverShift to be a strict UPPER bound on actual drift. Is it? If it can ever UNDER-estimate actual drift (current swap rate lower than a historical rate in force during the hold; midnight-count undercount; any other path), then a high-actual-drift pair could pass the guard and receive the allowance while genuinely sitting near a grid boundary -- reopening the vector. If MaxPossibleRolloverShift is not a strict upper bound, this approach fails and must be reconsidered.

If safe: confirm, and confirm the max_spread_allowance ceiling that keeps the envelope < one grid step. If not: specify the construction precisely.

Out of scope: SRE overall design (audited v2-v8), ADR-107 rollover fix, the Tier 1 fixture. Focus only on whether uniform spread tolerance + lowered guard reopens the tamper envelope.

The full spec follows below.

--- SPEC ---

# Spec Draft — Problem 3: Uniform Fill-Noise Tolerance via Lowered Grid-Boundary Guard

For DeepSeek Phase 1 audit before implementation. Grounded in source at 21b2153 + ADR-107/108 (local). Same security-relevant function DeepSeek reviewed twice (V2_SRE_HedgePriceIndicatesCrossPair).

## Problem being fixed

ADR-108 gated the spread-noise allowance to zero-rollover (same-day) pairs ONLY, to avoid the compound vector (rollover_drift + spread reaching one grid step). Consequence: overnight/long-hold historical pairs with GENUINE execution noise (2-7pt, normal fractional-pip slippage) get no allowance and fail closed on the strict 2pt band. That is Cases 3/5's remaining Tier 1 reds -- an availability false-positive, not a security issue, but it blocks a fully-green regression gate. This spec makes the fill-noise tolerance apply uniformly to all pairs, safely.

## The mechanism that makes it safe

ADR-108 already added a grid-boundary guard: halt if max_shift >= G - base_tol - margin (87pt on a 90pt grid). The zero-rollover gate was a SECOND, separate defense against the compound vector. Insight: if the guard threshold is lowered to also account for the spread allowance, the compound vector becomes structurally impossible for any pair that reaches the tolerance check -- making the zero-rollover gate redundant and removable.

## The change (net simplification)

Two coupled edits to V2_SRE_HedgePriceIndicatesCrossPair:
1. Lower the grid-boundary guard threshold from `G - base_tol - margin` to `G - base_tol - max_spread_allowance - margin`.
   With G=90, base_tol=2, max_spread_allowance=15, margin=1: guard fires at max_shift >= 72pt (was 87pt).
2. Remove the zero-rollover gate. The spread allowance now applies to ALL pairs that pass the (lowered) guard:
   `noise_allowance = InpNominalSpreadPoints[symbol] * point`  (no longer conditioned on rollover_units==0)

## Why this is safe (verified arithmetic)

Any pair that reaches the tolerance check has max_shift < 72pt (else the guard already halted it). Worst-case reach toward the nearest wrong layer (k=1, at 90pt):
    max_shift + base_tol + spread_allowance  <  72 + 2 + 15  =  89  <  90
So no pair receiving the spread allowance can reach an adjacent mispaired layer. The compound vector DeepSeek found in Round 2 is structurally eliminated for the entire checked population, not just the zero-rollover subset. Deeper layers (k=2 at 180pt) trivially safe. Zero-rollover pairs (max_shift=0 < 72) still get the allowance, so ADR-108's Problem 2 fix is preserved.

## Cost (accepted, fail-closed)

Pairs with max_shift in [72, 87) that previously passed now halt. These are ~6-day+ holds (drift accruing 72-87pt). They fail closed -- safe conservatism on aged, long-stuck historical pairs, exactly the population where a human should verify before the engine assumes reconstruction. Consistent with the fail-closed posture Gemini has affirmed throughout.

## The question for DeepSeek

Does lowering the guard to `G - base_tol - max_spread_allowance - margin` and applying the spread allowance uniformly reopen ANY cross-pairing / grid-cancellation vector -- via k=1, deeper layers, negative-direction drift, or an interaction with the ADR-107 rollover term or ADR-108 guard I have not considered?

Specifically pressure-test:
1. Is `72 + 2 + 15 = 89 < 90` the true worst case, or can max_spread_allowance exceed 15pt for any instrument in the set (EURGBP/GBPUSD/EURUSD), which would push the reach past 90?
2. Does the SHORT direction (drift downward) create an asymmetry where the reach toward a lower adjacent layer behaves differently than the LONG case computed here?
3. Is there any pair whose max_shift is computed as < 72 but whose ACTUAL drift exceeds it (i.e. is MaxPossibleRolloverShift a true upper bound, such that "guard didn't fire" genuinely guarantees "actual drift < 72")? If MaxPossibleRolloverShift can UNDER-estimate, the guard could let a high-actual-drift pair through.

Question 3 is the one I am least sure of and would most want broken. If MaxPossibleRolloverShift is not a strict upper bound on actual drift, this whole approach needs reconsideration.

If safe: confirm, and confirm the max_spread_allowance value that keeps the envelope below one grid step. If not: specify the construction.

Out of scope: SRE overall design (audited v2-v8), ADR-107 rollover fix, the Tier 1 fixture itself. Focus only on whether uniform spread tolerance + lowered guard reopens the tamper envelope.

## Sequencing

DeepSeek audit -> Gemini ruling -> Cursor implements (net: -1 gate, +1 lowered threshold constant) -> re-run Tier 1: Cases 3/5's overnight fill-noise pairs should now reach V2_SRE_OK, Case 5's genuine 29pt outlier should STILL halt (>72pt guard), tamper test STILL halts -> full green Tier 1 -> ADR-109.
