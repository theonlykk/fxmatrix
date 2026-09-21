# ADR-153: Geometry Independence -- Break add == 2 x width, Free the Stranded Threshold, Budget the Recentre

## Status

Proposed -- 2026-09-20. Revision 3, same day.

- Rev 1 broke the `add == 2 x width` link and tied stranded to width.
- Rev 2 corrected a sign error and a wrong threshold derivation found by
  the DeepSeek audit.
- **Rev 3 (this) removes the stranded floor entirely** and adds an API
  budget gate to the recentre. The floor was a quoting preference dressed
  as a safety rule, and it blocked a legitimate design (live two-sided
  quoting). The real safety limit is the API budget, and the recentre --
  the one path that burned 139 requests in a night -- was the one path
  that budget did not cover.

Gemini approved rev 3; recentre gate at 1,800 per his ruling.
Implementation on feat/adr153-geometry-independence; DeepSeek audit of the
branch pending.

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

**2. `InpStrandedThreshPips` is a free design parameter.**

No floor, no fatal relationship to width or deadband. It and
`InpDeadbandPips` together set how closely the flat side's L0 follows mid
while the other side holds layers. Two coherent designs, both now
expressible as presets, per pair, changeable mid-week (neither enters a
reconstruction invariant):

| design | typical setting | behaviour |
|---|---|---|
| **rescue** (today) | `stranded = 2 x width` | place once; re-quote only when badly left behind |
| **live** | `stranded ~ width`, deadband chosen for cadence | flat side stays near mid; leans against inventory -- once short, stay ready to get long |

The re-quote threshold on mid drift is `max(D, S - W)` (see below), so the
live design's cadence -- and its API cost -- is set by the deadband.

**Why no floor.** An earlier revision required
`stranded >= max(2 x width, width + deadband + 1)`. `2 x width` was
inherited from the presets that existed when add was locked to twice
width; `width + deadband + 1` was derived to stop the deadband becoming the
control. Neither is a safety property. Both are preferences for the rescue
design, and as a fatal check they would have made the live design
impossible to run. Safety is handled by Decision 4.

**3. `OnInit` fatal checks are SANITY checks only.**

They exist to catch typos and nonsense, not to encode a quoting design.
`OnInit` returns `INIT_FAILED` if any of these hold:

    width_pips    <= 0
    add_pips      <= 0
    exit_pips     <= 0
    stranded_pips <= 0
    deadband_pips <  0
    add_pips / width_pips < 0.5  or  > 4.0

The add/width band is itself arbitrary; it exists to catch a 40 typed for
a 4 and blocks nothing currently planned. Write every check as a
REJECTION, as above -- an earlier draft stated a passing condition under
the heading "fatal check", which reads as its opposite (DeepSeek
finding 1).

**4. The recentre respects the API budget.**

`GRIND_DAILY_API_ENTRY_STOP` (1,900 requests/day, `grind_config.mqh:11`)
is checked in five places -- `Grind_TryPlaceL0`, `Grind_ApplyEntryHorizon`,
`Grind_SendNextAddEnt`, `Grind_TryPlaceAddAtFill`,
`Grind_EnsureAddNext` -- and **not** in `Grind_TryRecenterOppositeL0`.

So the one path measured burning 139 requests in a night is the one path
the budget guard does not cover. Worse: when re-quoting drives the counter
to 1,900, the stop blocks ENTRIES -- the requests that earn money -- while
the re-quotes carry on.

`Grind_TryRecenterOppositeL0` returns early when the entry stop is active,
exactly like the five paths above. **Recommended, not required for this
ADR:** a lower re-quote-specific threshold (e.g. stop recentring at the
1,800 soft-warn level) so re-quotes yield to entries before entries are
cut.

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

**Today's fleet passes every sanity check** (add/width ratio exactly 2.0
everywhere, all values positive). **No preset change is forced.** EURGBP's
stranded of 6 is a choice, not a violation -- measured below at a cost of
139 re-quotes in one night on one arm. Whether to change it is now a
preset decision.

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
| EURGBP at the old floor (S 8) | 3 | 8 | 4 | 5.0 |
| EURGBP, W 2, at the old floor (S 7) | 2 | 7 | 4 | 5.0 |
| live design, W 5, S 5, D 6 | 5 | 5 | 6 | 6.0 |

**An earlier draft said the threshold was `width + deadband` -- 7 for
EURGBP against 10 elsewhere.** Wrong twice (DeepSeek findings 2 and 10):
it measured the resting order's distance from mid rather than the drift
that moves it, and `width + deadband` at width 5 is 9, not 10.

**So a floor would buy little:** raising EURGBP to the old floor (8) moves
it from re-quoting on 4-pip drifts to 5, matching the fleet. That is a
preset choice, and the reason rev 3 drops the floor.

**The 10x churn gap is therefore mostly NOT geometry.** A 4-pip threshold
against 5 cannot explain 139 modifies against 12. The dominant factor is
time spent one-sided with mid oscillating across the threshold: EURGBP ALT
was one-sided for the whole 7h36m window. No geometry rule would have
prevented it; an API budget gate would have capped it. Hence Decision 4.

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
  the new sanity checks are not reachable from the pure test surface. It
  needs `stranded`, `exit` and `deadband` parameters and the extra call
  (finding 8).

The `OnInit` error message still names the old equality and is rewritten
with it (finding 9).

Decision 4 touches the same function as the test-mode fix above, so both
land in one change.

**Checked and clear:** `GRIND_ADD_WIDTH_MULTIPLE` appears only in the
validator and that message; nothing in `grind_recon`, `grind_exitq`,
`grind_cap` or `grind_state` assumes `add == 2 x width` (finding 6).

## Testing

Tests first, and they must fail before the change:

- `add/width` ratio at 0.49, 0.5, 2.0, 4.0, 4.01 -- reject, accept, accept,
  accept, reject.
- Each sanity check: zero or negative width, add, exit, stranded (reject);
  negative deadband (reject); deadband 0 (accept).
- `stranded = width` starts clean -- the live design must be expressible.
- **Recentre + API stop:** with the counter at the entry-stop level, a
  recentre that would otherwise fire does NOT send a modify. Must fail
  before the change.
- A cycle-3 geometry (width 5, add 4, exit 10, stranded 10) starts clean.
- The range permits `add > exit` (e.g. width 1, add 4, exit 2), where a new
  layer's exit target sits BELOW the previous layer's entry. Test that the
  exit queue ranks and places correctly there, or narrow the range
  (finding 7).
- Every current preset still passes every check.
- The ADR-124 recentre is unchanged when `stranded = 2 x width`: same
  modify count as today on a fixture where mid drifts. Requires the
  test-mode fix in Prerequisites first.

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
- **Rev 3** removes the stranded floor (a preference, not a safety rule)
  and gates the recentre on the API budget.
- **Outstanding:** Gemini's sign-off on rev 3, then the Cursor spec.
