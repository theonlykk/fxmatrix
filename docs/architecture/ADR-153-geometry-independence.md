# ADR-153: Geometry Independence -- Break add == 2 x width, Tie stranded to width

## Status

Proposed -- 2026-09-20, revised the same day after the DeepSeek audit,
which found a sign error in the fatal check and a wrong derivation of the
recentre threshold. Both corrected below. Gemini re-ruling and Cursor
implementation outstanding.

Supersedes the fixed relationship set by ADR-125 (`0bd0877`, 2026-09-06).

## Context

`fxgrind.mq5:119` calls `Grind_ValidateAddWidthRelationship`
(`grind_pure.mqh:40`), which requires `add_pips == GRIND_ADD_WIDTH_MULTIPLE
(2.0) x width_pips` to 1e-8 and returns `INIT_FAILED` otherwise. MT5 then
removes the EA from the chart.

ADR-125 gave two reasons: parity with
`scripts/grid_sim_v7_real_signal.py`, and protection against preset drift.
A third, geometric reason was never written down: with L0 legs at
`mid -/+ width`, `add = 2 x width` puts both legs and every add on one
uniform lattice.

**The rule now blocks the work it was meant to protect.** Geometry cycle 3
sets add spacing per pair from trade volume -- entries per day, measured
from 793 real layers over 10-18 Sep -- and six of eight pairs need an add
that is not twice their width.

**Changing width instead does not work.** Width is the distance from mid at
which L0 quotes, and that distance is the compensation for adverse
selection: quoting at mid -2 rather than mid -5 opens 3 pips worse against
mid with the exit still a fixed distance from entry. Halving width
alongside add would change the ladder spacing AND the price the instance is
willing to open at, so next week's result could not be attributed to
either. Cycle 3's design is one variable per arm.

**Second defect, found while ruling on the first.** `InpStrandedThreshPips`
equals the old `add` (= 2 x width) in every preset today. The cycle-3
proposal initially had it follow the new `add`. In
`Grind_TryRecenterOppositeL0` (`grind_engine.mqh:1482-1524`) the gate is
`|resting - mid| > stranded`, and a freshly placed L0 sits at exactly
`mid -/+ width`. So when `stranded < width` the gate is true at placement
and never goes false; the only remaining brake is the deadband check at
`:1520`, and the flat side's L0 follows mid in `InpDeadbandPips` steps.
Each step is an `OrderModify` against a 2,000/day API cap the fleet already
hit on 2026-09-17.

## Decision

**1. Remove the fixed multiple. Keep a range guard.**

`Grind_ValidateAddWidthRelationship` no longer tests equality. `OnInit`
fails only when the geometry is outside a sane band:

    width_pips  > 0
    add_pips    > 0
    0.5 <= add_pips / width_pips <= 4.0

The band keeps ADR-125's drift protection -- a typo of 40 instead of 4
still fails at startup -- without dictating the geometry.

**2. `InpStrandedThreshPips` follows WIDTH, not add, with a floor.**

    stranded = max(2 x width, width + deadband + 1)

`2 x width` is numerically what every preset holds today, so the ADR-124
rescue semantics are unchanged on every pair that already clears the
floor: the gate opens only once the quote has drifted a full extra
`width` beyond where it was placed. The floor exists because the EFFECTIVE
threshold is not `stranded` alone -- see the evidence section.

**3. New `OnInit` check, fatal.** The check REJECTS; the passing condition
is the floor from Decision 2:

    if(stranded_thresh_pips < MathMax(2.0 * width_pips,
                                      width_pips + deadband_pips + 1.0))
       return INIT_FAILED;

**Written as a rejection deliberately.** An earlier draft stated the
PASSING condition (`stranded > width + deadband`) under the heading
"check, fatal", which reads as the failing one. Implemented literally that
would have failed every preset with width 5 and admitted EURGBP -- exactly
backwards (DeepSeek finding 1).

It also enforces the whole floor rather than half of it: a check on
`width + deadband` alone would admit `width 6, stranded 10.5`, violating
the `2 x width` component (finding 4).

## Consequences

**The uniform lattice goes.** Under cycle 3, AUDCHF OPT quotes its L0 legs
10 pips apart (2 x width) while adding every 4. The two legs sit on
opposite sides of mid and never interact, and each side's own ladder stays
uniform, so the loss is aesthetic rather than mechanical. Gemini ruled the
lattice has no trading purpose that survives the attribution argument.

**The simulator diverges from the EA** on any arm where `add != 2 x width`.
That is acceptable under ARCHITECT s12, which already requires a geometry
parameter derived from simulated fills to be re-validated against real
fills before it governs live orders. The simulator has known cost-model
defects; the EA should not be constrained to keep it honest.

**Today's fleet passes the range check** (ratio exactly 2.0 everywhere).
Against the floor, all 18 presets checked, deadband 4.0 on every one:

| width | arms | `2 x width` | floor | current stranded | passes |
|---:|---|---:|---:|---:|---|
| 7 | eurusd, audnzd, nzdchf (detached) | 14 | 14 | 14 | yes |
| 5 | audcad, audchf, cadchf, gbpusd, nzdcad | 10 | 10 | 10 | yes |
| 3 | **eurgbp OPT and ALT** | 6 | **8** | **6** | **NO** |

EURGBP is the only preset this ADR forces a change on: stranded 6 -> 8.
**Both EURGBP presets must change in the same commit as the code**, or
those two instances will not start.

## Evidence: EURGBP already churns, measured

EURGBP runs width 3, stranded 6, deadband 4 -- so `2 x width` (6) does NOT
exceed `width + deadband` (7), and it has been below the bound since
deployment. The `--l0churn` view added to pipshed
(`scripts/archive_counts.py`, merged 2026-09-20 at `36a4ade`) counts
layer-0 ENT modifies per instance, recovering role and layer by joining
each modify to the placement that created its ticket:

| instance | modifies | share of its requests | window |
|---|---:|---:|---|
| GRIND_EURGBP_ALT | **139** | **48.3%** | 13-Sep 21:05 to 14-Sep 04:41 |
| GRIND_AUDNZD_ALT | 15 | 7.7% | spread over 4 days |
| GRIND_GBPUSD_OPT | 13 | 1.0% | spread over 8 days |
| every other instance | 2 to 12 | 0.2% to 5.3% | spread |
| GRIND_EURGBP_OPT | 2 | 0.2% | -- |

Read with care:

- **It is bursty.** All 139 landed inside 7h36m, about 18 per hour. Nearly
  half that instance's API usage over nine days came from one night.
- **Geometry permits it; the one-sided state triggers it.** EURGBP OPT has
  identical geometry and shows 2. The recentre only runs when one side
  holds layers and the other is flat.
- **Lower bound.** Only 560 of 2430 modifies matched a placement row --
  `send_logs` retains 14 days and older orders have no placement.

### What actually sets the re-quote threshold

Let `W` = width, `S` = stranded, `D` = deadband, and `d` = how far mid has
drifted since the L0 was placed. A long L0 rests at `mid0 - W`, so the
gate sees `|W + d|` while the deadband sees `|d|`. Both must pass, which
gives DIRECTION-DEPENDENT thresholds in terms of mid drift: `max(D, S - W)`
when mid moves AWAY from the resting quote, `S + W` when it moves toward
it. The binding one is `max(D, S - W)`:

| | W | S | D | drift that re-quotes |
|---|---:|---:|---:|---:|
| EURGBP today | 3 | 6 | 4 | **4.0** |
| every other arm today | 5 | 10 | 4 | 5.0 |
| EURGBP under the floor | 3 | 8 | 4 | 5.0 |
| cycle-3 EURGBP (W 2) under the floor | 2 | 7 | 4 | 5.0 |

**An earlier draft said the threshold was `width + deadband` -- 7 for
EURGBP against 10 elsewhere.** Wrong twice (DeepSeek findings 2 and 10):
it measured the resting order's distance from mid rather than the drift
that moves it, and `width + deadband` at width 5 is 9, not 10.

**So the floor buys less than first claimed:** EURGBP moves from
re-quoting on 4-pip drifts to 5, matching the fleet. What the floor
guarantees is that the GATE binds rather than the deadband -- `S >= W + D`
is exactly the condition for `S - W >= D` -- and that is the property
worth having, because the gate is a parameter we tune per pair and the
deadband is not.

**The 10x churn gap is therefore mostly NOT geometry.** A 4-pip threshold
against 5 cannot explain 139 modifies against 12. The dominant factor is
time spent one-sided with mid oscillating across the threshold: EURGBP ALT
was one-sided for the whole 7h36m window. The floor is right, but it will
not eliminate the churn.

## Prerequisites the audit uncovered

Two defects must be fixed as part of this work, not after it:

- **`Grind_TryRecenterOppositeL0` reads the resting price with the raw
  `OrderGetDouble`** (`grind_engine.mqh:1498`), while
  `Grind_OrderGetPriceOpen` (`:348`) exists to serve order-test records.
  In test mode the raw call returns 0.0, so the recentre computes a
  nonsense distance. **No recentre test can pass until this is switched**
  (finding 5).
- **`Grind_TestOnInitGeometryCheck` (`grind_pure.mqh:47`) never calls
  `Grind_ValidateAddWidthRelationship` and takes no `deadband`**, so
  neither new check is reachable from the pure test surface. It needs the
  extra parameter and the extra call (finding 8).

The `OnInit` error message still names the old equality and is rewritten
with it (finding 9).

**Checked and clear:** `GRIND_ADD_WIDTH_MULTIPLE` appears only in the
validator and that message; nothing in `grind_recon`, `grind_exitq`,
`grind_cap` or `grind_state` assumes `add == 2 x width` (finding 6).

## Testing

Tests first, and they must fail before the change:

- `add/width` ratio at 0.49, 0.5, 2.0, 4.0, 4.01 -- reject, accept, accept,
  accept, reject.
- `stranded` at `width + deadband` exactly (reject) and one point above
  (accept).
- The floor: width 2, deadband 4 -> the convention yields 7, not 4.
- A cycle-3 geometry (width 5, add 4, exit 10, stranded 10) starts clean.
- The range permits `add > exit` (e.g. width 1, add 4, exit 2), where a new
  layer's exit target sits BELOW the previous layer's entry. Test that the
  exit queue ranks and places correctly there, or narrow the range
  (finding 7).
- Every current preset still passes both checks.
- The ADR-124 recentre is unchanged when `stranded = 2 x width`: same
  modify count as today on a fixture where mid drifts.

## Review

DeepSeek is MANDATORY (ARCHITECT s2: grid geometry, and it changes when
orders are placed).

- Gemini ruled on the direction 2026-09-20: break the link, keep a range
  guard, tie stranded to width.
- **DeepSeek audited 2026-09-20** (`prompts/adr153_deepseek_response.md`,
  branch `review/adr153-deepseek` at `565fa95`), verdict "do not implement
  as written". All ten findings were checked against source: 1, 2, 3, 4,
  5, 8, 9 and 10 accepted and folded in above; 6 confirmed clear; 7 became
  a test requirement.
- **Outstanding:** Gemini's sign-off on the corrected arithmetic, then the
  Cursor spec.
