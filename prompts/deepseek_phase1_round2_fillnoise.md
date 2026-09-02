This message has a line count at the bottom.

# DeepSeek Phase 1 — Targeted Audit: Problem 2 Spread-Derived Fill-Noise Term (HALT_30 Compound Vector)

## Round context

Second narrow single-question audit on the same security control (HALT_30) you reviewed in Round 1. Round 1 you found the grid-cancellation vector in the original wide-interval rollover fix; we adopted your rollover-shifted point-estimate correction (ADR-107, shipped). Tier 1 real-data testing then surfaced a SECOND false-positive class: genuine correct EA fills deviate from the exact model by 2-7 points even on 0-midnight (zero-rollover) pairs -- pure execution noise (spread/slippage/requote deadband). This audit is about the fix for that, and specifically whether that fix reopens your Round 1 vector by a compound path.

Gemini (Staff Architect) has already identified the compound attack and mandated this full audit rather than trusting a "spread is small" argument. The Lead Engineer's initial reasoning -- that spread (0-9pt) cannot reach the 90pt grid step so is safe -- was WRONG and is explicitly flagged below as the trap to pressure-test, because it evaluates spread in isolation rather than as part of the cumulative tolerance envelope.

## The proposed fix (Option B, fixed nominal spread)

The full spec follows below this memo. In brief: add a fixed per-instrument nominal-spread constant as a noise allowance to the HALT_30 tolerance --

    consistent = |hedge_open_price - expected_adj| <= ExitPriceTolerance(point)*4.0 + noise_allowance

where noise_allowance is a compile-time constant per symbol (NOT live/historical market data -- unavailable to the reconstruction engine, and attacker-influenceable if sourced live). Sourcing alternatives (current spread; derive-from-resting-order) were both rejected -- see spec.

## The central security question (stated explicitly, not left to find)

HALT_30's tolerance envelope is now the SUM of two terms: the shipped ADR-107 rollover correction AND this new spread allowance. Neither reaches the 90pt grid step alone. But rollover_drift CAN grow large on long holds, and spread only needs to bridge the remainder:

    expected_adj    = naive_target + rollover_drift
    acceptable_band = expected_adj +/- spread_allowance

If a hold accrues rollover_drift ~= 82pt, expected_adj sits 8pt from the adjacent layer target (90pt away). An 8pt spread_allowance then puts the band's upper bound at exactly naive_target + 90 -- and a genuinely mis-paired adjacent layer passes HALT_30. Verified arithmetic: rollover(82) + spread(8) = 90 = one grid step. The spread term recreates the exact Round 1 masking zone, now distributed across two variables instead of one.

## The questions for this round

1. Construct the worst realistic case: what is the maximum plausible rollover_drift on a long hold for these instruments (EURGBP/GBPUSD/EURUSD, their real swap rates, Wednesday 3x multiplier, plausible max hold), and does max_rollover_drift + nominal_spread_allowance reach or exceed one 90pt grid step?
2. If it does: what constraint makes it safe? Candidates to evaluate (not prescribe): (a) a hard cap on rollover_allowance + spread_allowance COMBINED, well below one grid step; (b) apply the spread allowance ONLY to 0-midnight pairs where rollover_drift=0 so no compounding is possible (flag if this overlaps Problem 3's separately-tracked territory); (c) something else.
3. Does Option B's fixed constant reduce the attack surface vs a variable/live spread, or is the compound vector present regardless of sourcing because it is the SUM that matters, not the individual term's variability?

If a safe bounded constraint exists, specify it precisely. If NO bounded spread allowance can coexist safely with the shipped rollover term near grid boundaries, say so -- that is a valid finding that sends us to a different approach entirely (e.g. abandoning the additive-tolerance model for execution noise).

Out of scope: Problem 3 (long-hold rollover overshoot, tracked separately), SRE overall design (audited v2->v8), the shipped rollover fix itself (ADR-107). Focus only on whether the spread allowance, combined with the already-present rollover term, reopens the tamper envelope.

The full spec follows below.

--- SPEC ---

# Spec Draft (v2) — Problem 2: Fixed Nominal-Spread Fill-Noise Term (HALT_30)

For DeepSeek Phase 1 adversarial audit before implementation. Grounded in source read at 21b2153. Supersedes v1 — Option C cut (tautological + data-absent for settled historicals, per Gemini ruling), Option A deprioritized, Option B centered.

## Problem being fixed (scope: Problem 2 ONLY)

HALT_30 compares a historical hedge fill against a rollover-corrected expected exit (`naive ± exit_pips + MaxPossibleRolloverShift`, ADR-107) with a tight `point*2` tolerance. Tier 1 real-data testing proved genuine, correct EA fills deviate from the exact model by 2-7 points even on 0-midnight (zero-rollover) pairs -- pure execution noise (spread capture, slippage, requote deadband). 10 of 11 remaining Cases 2/3/5 failures are this class. The tight band flags them as tampering.

Explicitly OUT of scope: Problem 3 (long-hold MaxPossibleRolloverShift over-prediction, the 29pt Case 5 outlier) -- tracked separately per Path 1 ruling, NOT addressed here.

## Sourcing decision (settled per Gemini ruling)

Spread is not available to the reconstruction engine -- no spread field in any input struct, and MT5 does not expose historical per-tick spread read-only. Three sourcing options were evaluated:

- Option A (current SYMBOL_SPREAD proxy): REJECTED as primary -- market-variable and attacker-influenceable in volatility; a spike widens the band.
- Option C (derive from resting-order price): REJECTED (Gemini) -- tautological (`|actual - expected| <= |actual - expected|` passes any slippage including 500pt), AND the resting order does not exist in history for settled CloseBy pairs, so the data is absent for exactly the trades being fixed.
- Option B (fixed per-instrument nominal-spread constant in the pair preset): SELECTED -- deterministic, immune to malicious spread-widening, no live fetch during OnInit, fails closed.

## Proposed formula (Option B)

```
noise_allowance = InpNominalSpreadPoints[symbol] * point   // fixed preset constant, per instrument
consistent = |hedge_open_price - expected_adj|
           <= V2_SRE_ExitPriceTolerance(point)*4.0 + noise_allowance
```
The existing tight band PLUS a small, fixed, physically-grounded allowance -- not a replacement of the tight band with a wide one. `noise_allowance` is a compile-time constant per symbol (e.g. EURGBP ~15pt / 1.5pip nominal), NOT derived from live or historical market state.

## THE CENTRAL SECURITY QUESTION — the compound grid-cancellation vector

This is the specific attack DeepSeek must evaluate, stated explicitly rather than left for the model to find:

HALT_30's tolerance envelope is now the SUM of two terms: the rollover correction (ADR-107, already shipped) AND this new spread allowance. Neither term alone reaches the 90-point minimum grid step. But the shipped rollover term CAN grow large on long holds -- and spread only needs to bridge the remainder:

```
expected_adj    = naive_target + rollover_drift
acceptable_band = expected_adj ± spread_allowance
```
If a position is held long enough that rollover_drift reaches ~82 points, expected_adj sits just 8 points from the adjacent layer's target (90pt away). A spread_allowance of 8 points then makes the band's upper bound EXACTLY naive_target + 90 -- and a genuinely mis-paired adjacent layer passes HALT_30 cleanly.

This is verified arithmetic, not hypothetical: rollover(82) + spread(8) = 90 = one grid step. Introducing the spread term recreates the EXACT masking zone from Round 1, now distributed across two variables (rollover + spread) instead of one (rollover interval).

## The questions for DeepSeek

1. Does the fixed Option-B spread allowance, COMBINED with the shipped ADR-107 rollover term, reopen the grid-cancellation vector via the compound path above? Construct the worst realistic case: what is the maximum plausible rollover_drift on a long hold for these instruments, and does `max_rollover_drift + nominal_spread_allowance` reach or exceed one grid step?
2. If it does: what constraint makes it safe? Candidates to evaluate, not prescribe -- (a) a hard cap on `rollover_allowance + spread_allowance` combined, well below one grid step; (b) applying the spread allowance ONLY to 0-midnight pairs (where rollover_drift = 0, so no compounding is possible), halting long-hold pairs by a different route (which overlaps Problem 3's territory -- flag if so); (c) something else.
3. Does Option B's fixed constant meaningfully reduce the attack surface vs Option A's variable spread, or is the compound vector present regardless of sourcing because it's the SUM that matters, not the individual term's variability?

If a safe constraint exists, specify it precisely. If no bounded spread allowance can coexist safely with the shipped rollover term near grid boundaries, say so -- that is a valid finding and would send us back to a different approach entirely.

Out of scope: Problem 3 (long-hold overshoot), SRE overall design (audited v2->v8), the rollover fix itself (ADR-107, shipped). Focus only on whether adding the spread allowance -- in combination with the already-present rollover term -- reopens the tamper envelope.

## Sequencing (per Gemini, unchanged)

DeepSeek audit → on clear (with whatever constraint it specifies) → Cursor implements Option B + any DeepSeek-mandated cap → re-run Tier 1 (Cases 2/3/5 short-hold pairs reach V2_SRE_OK; Case 5 long-hold outlier remains documented Problem-3 halt) → ADR → Tuesday Tier 2.
