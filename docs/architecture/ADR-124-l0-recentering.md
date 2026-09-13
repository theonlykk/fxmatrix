# ADR-124: Fill-Triggered L0 Re-Centering (Dual Gate)

## Status

Accepted -- 2026-09-13. Formalises the fill-triggered re-centering rule cited in
ADR-125 decision 7 as "re-centering -- reserved write-up." That omission allowed
the ADR-123 place-once regression to ship: `Grind_TryPlaceL0` re-quoted resting
L0 limits on mid noise, conflating ADR-123 (never re-quote when flat) with
ADR-124 (re-center only after a fill).

## Context

**Incident (FTMO hyperactivity warning, account 1514582088, 2026-09-13):**

- 1941 broker requests in ~47 minutes of the broker day.
- 8 of 12 instances FLAT; ZERO fills all session.
- Fleet STOPPED: algo off, all 12 EAs detached; resting orders left in place.

**Evidence (`send_logs`, ADR-131 archive):**

- EVERY send is action=MODIFY (no new placements on flat sides).
- GBPUSD L0 chasing mid: 1.35198 -> 1.35115 -> 1.35172 -> 1.35116 in ~50 s.

**Root cause:**

`Grind_TryPlaceL0` re-quoted a resting L0 whenever mid moved beyond the 4-pip
deadband. ADR-123 (Accepted 2026-08-28) ruled place-once-and-wait and explicitly
REJECTED per-order deadband on replace for the flat straddle path. The deadband
machinery from ADR-121/122 was wired into the wrong function: mid-chasing on a
flat side is NOISE, not INFORMATION.

**Architectural boundary (Gemini, verbatim):**

Re-quote on INFORMATION, never on NOISE.

- Both sides flat: mid fluctuation is pure NOISE. The market has not absorbed
  any liquidity, so there is no empirical reason to move our quotes. That is
  ADR-123.
- A layer fills: the market has revealed directional conviction and the book has
  materially changed. Re-centering the opposite, untraded side in response to
  that fill is INFORMATION-driven. That is ADR-124.

## Decision

L0 re-centering is permitted ONLY when BOTH gates hold:

1. **Gate 1 (Information):** the opposite side holds active layers, i.e. a fill
   has occurred on the other side. Enforced by call site in
   `Grind_OnTickEngine`: `Grind_TryRecenterOppositeL0` runs only when one side
   has depth > 0 and the opposite side has depth == 0.

2. **Gate 2 (Distance):** the untraded L0 has drifted beyond
   `InpStrandedThreshPips` from current mid. Enforced inside
   `Grind_TryRecenterOppositeL0` via `Grind_ShouldRecenter`.

**Explicit ban on mid-chasing:** when both sides are flat, a resting L0 is NEVER
modified, at any distance, for any reason. `Grind_TryPlaceL0` returns false when
its tracked L0 is still live on the book. Initial placement and gone-ticket
replacement (ADR-129) are unchanged.

Re-centering uses `OrderModify` (`TRADE_ACTION_MODIFY`) at mid +/- width
(Adr013-clamped, marketability-checked). The absolute-pip deadband
(`InpDeadbandPips`) applies only inside `Grind_TryRecenterOppositeL0` and
`Grind_EnsureAddNext` -- NOT in `Grind_TryPlaceL0`.

## Rejected alternatives

**Per-order deadband on L0 replace in `Grind_TryPlaceL0`:** rejected by ADR-123;
still re-quotes on noise, only throttles frequency. Caused the 2026-09-13
hyperactivity incident.

**Unconditional stranded re-center when flat:** would move resting quotes without
a fill signal; treats mid drift as information when it is noise.

**Lowering `InpStrandedThreshPips` to reduce drift:** R2 rejected -- isolate
variables; threshold is for fill-triggered path only.

## Implementation

| Change | Location | Summary |
|--------|----------|---------|
| 1 | `grind_engine.mqh` `Grind_TryPlaceL0` | Resting-order branch returns false (place-once). Remove unused `deadband_pips` parameter. |
| 2 | `grind_engine.mqh` `Grind_OnTickEngine` | Call sites unchanged except dropped deadband arg on `Grind_TryPlaceL0`. |
| 3 | `fxgrind_tests.mq5` | PO1-PO4: place-once guards + ADR-124 regression (PO4). |

`Grind_TryRecenterOppositeL0`, `Grind_EnsureAddNext`, `InpStrandedThreshPips`,
and all preset values are untouched.

## Verification

- MetaEditor compile: `fxgrind.mq5` -- 0 errors, 0 warnings.
- Unit suite: 910/910 (900 baseline + PO1-PO4).
  - **PO1/PO2:** flat side, resting L0, mid moves 5/50 pips -> no modify.
  - **PO3:** no resting ticket -> place once.
  - **PO4:** one-sided fill scenario -> `Grind_TryRecenterOppositeL0` modifies once.

## Consequences

Positive:

- MODIFY volume on flat sides goes to zero; the only L0 requests on a flat side
  are the initial place and (on the opposite side after a fill) fill-triggered
  re-centres via ADR-124.
- ADR-123 and ADR-124 are mechanically separated: place-once vs information-driven
  re-center.

Negative / bounded:

- A flat pair may rest far from mid indefinitely -- that is intended, not a
  defect. The straddle waits for a fill or manual flat.
- After a one-sided fill, the opposite L0 re-centres only when stranded distance
  exceeds `InpStrandedThreshPips`; until then it remains at its pre-fill price.

## References

- ADR-123: Dumb straddle place-once-and-wait (revert re-quote state machine).
- ADR-121 / ADR-122: superseded deadband and ref_mid machinery (must not apply
  to flat L0 placement).
- ADR-125 decision 7: conflated place-once, fill-triggered re-center, and
  absolute-pip deadband in one bullet; ADR-124 is the reserved write-up for the
  middle rule.
- ADR-129: filled-ticket vs gone-ticket branch in `Grind_TryPlaceL0` (unchanged).
- ADR-131: archive evidence for the 2026-09-13 hyperactivity incident.
