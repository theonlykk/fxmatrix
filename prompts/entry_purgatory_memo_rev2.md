This message has a line count at the bottom

# ENTRY PURGATORY -- DESIGN MEMO REV 2 (for Gemini ruling)

Rev 1 superseded. This rev incorporates the DeepSeek R1 teardown
(`prompts/deepseek_entry_purgatory_response.md`, committed `f3ebc31`) after
Claude verified its load-bearing claims against source. EA at `c39fb84`.
No code. Read: `grind_exitq.mqh`, `grind_engine.mqh`, `grind_pure.mqh`,
`grind_config.mqh`, `grind_api_counter.mqh`, `grind_recon.mqh`.

## 1. THE DEFECT (unchanged from rev 1, measured live 2026-09-17)

`Grind_SlotEntryAllowed` (grind_exitq.mqh ~161):
`used + resting_ent <= limit - (2 + GRIND_SLOT_MARGIN)`, i.e. 194 at limit 200.
`Grind_SlotUsed` counts positions + orders; `Grind_SlotRestingEnt` counts every
fleet pending order whose role is not EXT. **Each resting entry costs two units.**
Placement is serialised by `Grind_SlotLockAcquire` but unordered: first tick wins.

Live: book 170-174 of 200 all afternoon, resting entries 24-25, guard total
195-198. Most resting entries were adds 8-16 pips from mid. Two GBPUSD
at-market foothold adds waited 5 and 11 minutes behind them. At 18:30Z, nine
sides that should have had an entry had none.

## 2. CORRECTIONS TO REV 1 (verified in source)

C1. **Adds are not place-once.** `Grind_EnsureAddNext` (grind_engine.mqh
    ~772-777): with an add already pending, if the clamped target has left the
    deadband (`InpDeadbandPips = 4.0`) it calls `Grind_ModifyPendingPrice`.
    Adds already re-price as the anchor or clamp moves, and every modify is an
    OrderSend counted by `Grind_OrderSendCounted`. Churn is not new; purgatory
    changes its shape (place/cancel pairs instead of modifies).
C2. **The ADR-013 clamp never reaches the market.** `Grind_Adr013ClampBuy`
    (grind_pure.mqh:149-161) returns `min(theoretical, bid - min_dist)`, and
    `Grind_BuyLimitMarketable` (grind_pure.mqh:137) is misnamed -- it returns
    TRUE when the limit is PASSIVE (`buy_limit < ask`). A clamped add rests just
    below the bid and fills on the next downtick. Rev 1's "re-adds at market"
    was wrong, and today's fast foothold fills were falling-market fills, not
    market orders. This is the mechanism behind the gap finding (s4, T-4).
C3. **The next add is not placed on the fill tick.** `Grind_HandleSideDealFill`
    does not call `Grind_EnsureAddNext`; placement waits for the next
    `Grind_OnTickEngine`, gated by `g_grind_ent_sent_this_tick` and the lock.

## 3. PROPOSAL (rev 2)

P1. An add rests at the broker only while `|target - mid| <= H_place`.
P2. A resting add is cancelled once `|target - mid| > H_cancel` (H_cancel > H_place).
P3. A HELD add has no broker order; its target is recomputed from the anchor,
    exactly as held exits are recomputed from entry price.
P4. Scope: adds on both sides. L0 unchanged (near mid by construction).
P5. **WITHDRAWN** (rev 1 defaults H = 1.5A, C = 0.5A): not defensible on request
    budget. Replaced by A1.
P6. **REFUTED** (rev 1 claim that proximity removes the need for priority):
    see s4 and A2.

Four amendments, A1-A4, are now part of the proposal, not optional extras.

## 4. WHAT THE TEARDOWN FOUND (all claims re-verified in source)

| Threat | Verdict | Consequence for this memo |
|---|---|---|
| T-1 latency after fill | EXPLOIT | C3 above; fixed by A3 |
| T-2 churn / API budget | FATAL as proposed | fixed by A1 |
| T-3 boundary arithmetic | no exploit | use `GRIND_PRICE_EPS` in comparisons |
| T-4 gap behaviour | FATAL for gap events | policy decision, A4 |
| T-5 ADR-151 interaction | no exploit | no invariant assumes a resting add |
| T-6 fleet dynamics | EXPLOIT | fixed by A2 |
| T-7 anchor mutation | no exploit | label validation already cancels stale adds |
| T-8 premise | EXPLOIT (P6 false) | fixed by A2 |

**T-2 arithmetic (verified):** 16 instances x 2 sides = 32 candidate adds. With
EURGBP-style A = 6, H = 9, C = 3, a 3-pip oscillation gives place/cancel pairs;
one cycle per side per 10 minutes over 8 hours = 32 x 2 x 6 x 8 = 3,072
OrderSends/day, against a 2,000/day FTMO ceiling that the EA does not enforce
(`grind_api_counter.mqh`: limit defined, soft warn at 1,800, no hard stop).

**T-6 arithmetic (verified):** holding today's 24 far adds drops `used` by 24 to
~150 with `resting_ent` 0. A fleet-wide move makes all 24 eligible at once; each
admitted add costs 2 units, so ~22 place before the 194 ceiling returns and the
last ones are starved again -- now at the moment they are near market, which is
worse than today.

**T-4 mechanism (verified):** with a held add at 1.1000 and mid 1.1050, a gap to
1.0950 leaves nothing resting; on the next tick the clamp places a buy limit at
~1.0949, BELOW the new bid. The resting order would have filled inside the gap.
Because the system never crosses the spread, the fill cannot be chased. Holding
an add therefore forfeits gap fills, by construction.

## 5. AMENDMENTS

**A1. Churn control (replaces P5).**
- `H_place = 2 x add_pips`, `H_cancel = 4 x add_pips` (hysteresis = 2A, not 0.5A).
- **Per-side daily transition budget**, e.g. `InpEntryHorizonMaxTransitions = 20`
  place/cancel transitions per side per broker day, reset with the API counter.
  Worst case 32 x 2 x 20 = 1,280 sends/day, inside the ceiling with headroom.
- When the budget is exhausted the add **stays resting** (fail toward today's
  behaviour, which is known-safe), and telemetry flags it.
- Independent of purgatory: add a **hard entry stop at 1,900 requests/day**.
  Exits and cancels-to-safety are never blocked; only new entries stop. This is
  the FTMO-compliance fix the fleet needs anyway (17d s3).

**A2. Priority (replaces P6).** A reserved band inside the guard, enforced
locally so no cross-instance messaging is needed:
- An entry whose target is **within one add step of mid** may use the full
  ceiling (194).
- Any other entry may only place while `used + resting_ent <= 194 - Q`, with
  `Q = 8` (four near-market entries' worth).
- Effect: far adds can never consume the last slots; near adds and passive-roll
  footholds always find room. Rank-by-distance across instances would be better
  but needs a GV-published distance table; the reserved band gets most of the
  benefit for one comparison.

**A3. Same-tick placement after a fill.** `Grind_HandleSideDealFill` must request
the next add for that side on the fill tick (or set a flag that lets
`Grind_EnsureAddNext` bypass `g_grind_ent_sent_this_tick` once, for the side
that just filled). Without this, purgatory adds a tick of latency to exactly the
case that matters. This is an explicit change to "nothing else changes".

**A4. Gap policy (decision required).** Options, in preference order:
1. **Accept missed gap fills, with a floor:** any add within one add step of mid
   ALWAYS rests, so only adds >= 1 step away can be missed, and instrument
   `add_gap_missed` (price traded through a held target without an order).
   Measure for two weeks before tuning H further.
2. Place-on-approach with a wider floor (e.g. 2 steps always resting), trading
   guard units back for gap coverage.
3. Reject purgatory for symbols whose gap frequency proves material.

Option 1 is proposed. It bounds the loss to far adds only, which are precisely
the ones whose fills we are least confident in.

## 6. WHAT DOES NOT CHANGE

- Reconstruction: a held add has no order and no ticket, so nothing to rebuild;
  `Grind_ReconCheckPendingAddCorrupt` treats `add_pending_ticket == 0` as valid.
- Invariants: none asserts the presence of an entry order.
- `Grind_ValidateAddLabelIndex` still runs at placement time; stale-label adds
  are still cancelled (T-7).
- Halt still cancels own entries (`Grind_CancelOwnEntryOrders`).
- The exit queue (K=2, H=1) and the guard formula itself are untouched.

## 7. QUESTIONS FOR GEMINI

Q1. A4: do we accept missed gap fills with the one-step floor (option 1), or is
    gap coverage load-bearing enough to reject purgatory on some symbols?
Q2. A2: is the reserved band (Q = 8) an acceptable first cut, or does this need
    true cross-instance ranking before it ships?
Q3. A1: is a per-side transition budget the right shape, or should the fleet
    share one budget published through a GV?
Q4. A3 is a change to the fill path, which is the most safety-critical code in
    the engine. Ship it with purgatory, or as its own ADR first?
Q5. Sequencing: entry purgatory before the passive-roll `EJECTED` work (your
    2026-09-17 direction), or does the shared guard arithmetic argue for one
    combined ADR?
Q6. Telemetry to make this auditable: `add_held` vs `add_pending` per side,
    fleet held count, transitions used per side per day, `add_gap_missed`,
    guard total. None of these exist today.

## 8. SEQUENCE

Gemini ruling on this rev -> ADR-152 -> Cursor spec -> tests -> deploy.
Entry purgatory lands before the passive-roll `EJECTED` state work unless Q5
says otherwise.

Line count: 163
