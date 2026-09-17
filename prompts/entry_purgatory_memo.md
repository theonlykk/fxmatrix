This message has a line count at the bottom

# ENTRY PURGATORY -- DESIGN MEMO (for DeepSeek teardown, then Gemini ruling)

Status: DRAFT. No code. Source read: fxmatrix `d139933`, EA at `c39fb84`
(`grind_exitq.mqh`, `grind_engine.mqh`, `grind_state.mqh`, `grind_config.mqh`).

## 1. THE DEFECT (measured live, 2026-09-17)

Entries are gated by `Grind_SlotEntryAllowed` (grind_exitq.mqh ~161):

    used + resting_ent <= limit - (2 + GRIND_SLOT_MARGIN)   // 194 at limit 200

`Grind_SlotUsed` = PositionsTotal() + OrdersTotal(); `Grind_SlotRestingEnt`
counts every fleet pending order whose comment role is not EXT. So each
resting entry consumes TWO units: the order itself, plus the exit it will
need. The lock (`Grind_SlotLockAcquire`) serialises the check but imposes no
ordering: whichever instance ticks first takes the room.

Measured this afternoon (counted by hand from status reads):

| Time | positions | orders | book | resting_ent | guard total |
|---|---|---|---|---|---|
| 14:27Z | 88 | 82 | 170 | 25 | 195 |
| 16:39Z | 90 | 82 | 172 | 24 | 196 |
| 17:00Z | 94 | 80 | 174 | ~24 | ~198 |

The book never exceeded 174 of 200. The guard was at or over 194 for most of
the afternoon. ~24 resting entries reserved ~48 units; most were adds 8-16
pips from mid (e.g. AUDCAD OPT L02 at 0.99367 with mid ~0.9950, EURUSD ALT
L08 at 1.14664 with mid ~1.1476). Meanwhile GBPUSD OPT's at-market foothold
add waited ~11 minutes and GBPUSD ALT's waited ~5, because far adds and short
L0s took the freed room first. Manual workaround was to detach an instance
and delete its entries.

## 2. PROPOSAL

Apply the ADR-151 visibility horizon to the ENTRY side: an entry rests at the
broker only when it is near enough to matter; otherwise it is held in memory
and placed when price approaches.

    place if   |target - mid| <= H          (entry horizon)
    cancel if  |target - mid| >  H + C      (hysteresis band)

- **Held entries have no broker order.** The target is recomputed from the
  anchor each tick, exactly as held exits are recomputed from entry price.
- **Scope:** adds on both sides. L0 is already re-quoted toward mid outside a
  deadband and is by construction near mid -- proposed unchanged, but see Q3.
- **Nothing else changes:** the exit queue (K=2, H=1), cap logic, halt
  cancellation, and the guard formula stay as they are. Fewer resting entries
  simply means a smaller `resting_ent` term.

Expected effect at today's book: resting entries fall from ~24 to roughly
8-12 fleet-wide, freeing ~24-32 guard units, which is the difference between
196 and ~170. At-market entries then place immediately.

## 3. WHY THIS MAY REMOVE THE NEED FOR AN EXPLICIT PRIORITY RULE

The starvation was not caused by too little room; it was caused by orders
that could not fill soon holding the room. A proximity gate removes those
requests entirely rather than ranking them. Residual contention (several
instances all near market at once) is rare and is exactly the case where
first-come is acceptable. A passive-roll foothold is by definition at market,
so it is naturally at the front.

## 4. NEW COSTS TO BOUND

1. **Request rate.** Placing and cancelling as price moves costs OrderSend
   calls, and we are already over FTMO's 2,000/day (2,320 at 17:07Z, s3 of
   17e). Hysteresis plus a minimum re-evaluation interval must cap
   place/cancel churn per side per hour; the spec must state the bound and
   the telemetry to verify it.
2. **Missed fills on a gap.** If price jumps past a held target, the add is
   marketable when placed. ADR-013 clamping already handles this (it is what
   made reattached ladders re-add at market), but frequency must be measured,
   not assumed.
3. **One more moving part between a fill and the next add.** Today the next
   add is already resting; with a horizon it may need placing first. Latency
   is one tick, but the spec must confirm the placement path runs on the fill
   tick (`g_grind_ent_sent_this_tick` allows one entry send per tick).

## 5. WHAT DOES NOT CHANGE

- Reconstruction: a held add has no order and no position, so there is
  nothing to rebuild -- simpler than held exits, which need a formula target.
  No GV state is required.
- Invariants: no invariant asserts the presence of an entry order.
  `Grind_ValidateAddLabelIndex` still runs at placement time.
- Halt: `Grind_CancelOwnEntryOrders` still cancels whatever is resting.

## 6. OPEN QUESTIONS FOR DEEPSEEK

Q1. Unit for H: absolute pips, a multiple of `add_pips`, or ATR-scaled?
    A multiple of add_pips self-scales across the fleet (EURGBP 6 vs EURUSD
    14), but then H must exceed one add step or the next add after a fill sits
    exactly on the boundary. Proposed default H = 1.5 x add_pips, C = 0.5 x
    add_pips. Defend or replace.
Q2. Per-side or per-instance horizon? Both sides can be far in a trend.
Q3. Is L0 in scope? It is near mid by design; including it adds no benefit
    and risks interfering with the deadband re-quote.
Q4. Minimum re-evaluation interval and the resulting worst-case request rate
    per instance per hour, given 16 instances and a 2,000/day ceiling.
Q5. Interaction with the cap: at cap there is no add at all, so the horizon
    is irrelevant. Confirm no interaction with `cap_blocked` telemetry.
Q6. Does the proximity gate fully replace a priority rule, or is an explicit
    tie-break still needed when several instances are within H at once?
Q7. Telemetry: `add_held` vs `add_pending` per side, held count fleet-wide,
    place/cancel counts per hour, and a guard-total field (pipshed currently
    shows none of these).
Q8. Failure mode to check: a held add whose anchor layer is closed manually
    or by passive-roll ejection -- does the recomputed target move correctly?

## 7. SEQUENCE

DeepSeek teardown of this memo -> Gemini ruling -> ADR-152 -> Cursor spec ->
tests -> deploy. Entry purgatory lands BEFORE the `EJECTED` state work, per
Gemini's 2026-09-17 direction: cut the dead weight from the add side first.

Line count: 119
