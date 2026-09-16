This message has a line count at the bottom

# GEMINI -- STAFF ARCHITECT RULING REQUEST: ORDER PURGATORY (ADR-151 candidate, memo rev 5)

## YOUR ROLE
Staff architect. Rule on the questions in memo s9 and on any design conflict
you find. You rule; you do not implement. Write no code. Claude (lead engineer)
verifies every amendment against source and records it accepted or rejected
with reasons.

## THE SYSTEM (fixed frame)
fxgrind is a passive limit-order market maker on MT5. Fourteen EA instances
share ONE FTMO demo account (hedging), separated by magic number. It never
crosses the spread and never uses stop losses. Per side an instance holds a
ladder of layers; each layer is one position plus one exit limit at entry +/-
exit_pips, optionally shifted by accrued carry. L0 is placed once when a side
is flat (ADR-123); the flat side's L0 is re-centred only while the other side
holds layers (ADR-124). Adds are priced from the deepest layer. An exit fill
opens an opposite position that the EA nets with CloseBy. Invariants rebuild
the book from broker tickets every tick; a failure quarantines (3000 ms
minimum, 3 checks) or halts immediately if not quarantinable. A halted
instance stops trading. (ARCHITECT s1's sentence that L0 is re-quoted every
tick is stale.)

## HOW WE GOT HERE
2026-09-16: the account limit (200 positions + orders) refused exits after
fills; 14+ halts, untracked fills on halted instances, a request storm, and
reinits that re-halted. The operator named the fix "order purgatory" and
contributed the key insight: most resting exits cannot fill until nearer exits
fill first, so they should not hold slots.

Three DeepSeek R1 source-grounded teardowns: rev 1 (flat reserve + fleet
eviction) premise killed; rev 3 (exit queue) premise killed on implementation
gaps; rev 4 (exit queue + commitment guard) **premise survives**, eight local
findings, six fixed in rev 5. Claude verified every DeepSeek claim against
source; all dispositions are in memo s7. DeepSeek's rev 4 final report follows
the memo, verbatim.

## WHAT TO RULE ON
  R1. Is the exit queue plus commitment guard sound as a design, and does rev 5
      close DeepSeek's rev 4 findings?
  R2. Memo s9 questions 1-7.
  R3. Any disposition in memo s7 you believe is wrong.
  R4. Conflicts with ARCHITECT principles: fail closed; halt, don't repair;
      never cross the spread; the operator owns the book.
  R5. Is anything missing that must be decided before a Cursor spec is
      written?

## REQUIRED RESPONSE FORMAT
For R1, R3, R4, R5: RULING / REASONING / AMENDMENT (exact memo text to change,
or "none").
For each s9 question: RULING / REASONING / AMENDMENT.
Then: VERDICT -- APPROVED / APPROVED WITH AMENDMENTS / REJECTED.
Do not assert facts about current fleet state or source beyond what this
document gives you. If you need a fact you do not have, ask it as a question.

=====================================================================
MEMO REV 5 (verbatim)
=====================================================================


# DESIGN MEMO -- ORDER PURGATORY: EXIT QUEUE + COMMITMENT GUARD (REV 5)

| | |
|---|---|
| Status | **REV 5, for Gemini ruling.** Supersedes rev 4. Proposed number: ADR-151 |
| Author | Claude (lead engineer), 2026-09-16 |
| Operator | Khalid. Concept and the exit-queue insight: an order that cannot fill until others fill first should not hold a slot |
| Evidence | `HANDOFF_2026-09-16.md` s1-2, `HANDOFF_2026-09-16b.md` (FOMC) |
| Red team | DeepSeek rev 1: `prompts/deepseek_order_purgatory_response.md` (`e83b52f`); rev 3: `..._rev3_response.md` (`9f67f0f`); rev 4: `..._rev4_response.md` (`96af7b1`, premise survives). Dispositions s7 |
| Source read | fxmatrix `96af7b1` (EA unchanged since `9f67f0f`): `grind_engine.mqh`, `fxgrind.mq5`, `grind_recon.mqh`, `grind_quarantine.mqh`, `grind_carry.mqh`, `grind_pure.mqh` |
| Review path | Gemini ruling -> Claude verifies amendments -> Cursor spec -> **DeepSeek audit of the spec before any code** |

**Rev 4 -> rev 5:** DeepSeek's third round found the premise sound and eight
local issues. Rev 5 applies its six fixes: release shifts are exempt from the
carry bound (4.1), ranking promotes a held exit whose target has overtaken a
live one (4.2), a missed exit fill is resolved from deal history (4.3), exit
retries recompute and clamp (4.3), entry sends take an atomic fleet lock
(4.7), and excess exits are trimmed in OnInit and during quarantine (4.8).

---

## 1. PROBLEM

The account allows **200 positions + pending orders combined**
(`ACCOUNT_LIMIT_ORDERS=200`; refusals occurred with ~113 orders resting). At
200 the exit placed after a fill is refused (10040), the layer goes I3_NAKED,
quarantine cannot outlast the limit, the instance halts. 2026-09-16: 14+ halt
events, untracked fills on halted instances, a request storm (822 -> 3,414 in
23 minutes), every reinit into a full book re-halted.

Book at 21:47Z: 92 positions + 88 exit orders + 20 entry orders = 200.

## 2. THE INSIGHT

**Most resting exits cannot fill until other exits fill first.** On a long
ladder every exit is a SELL LIMIT above market; the deepest layer's exit is
nearest, L00's furthest. GBPUSD ALT at 21:47Z held 12 exits from 1.34011 to
1.35212; eleven could not fill before the first. Shorts mirror this.

Keep only the K nearest exits per side on the book; hold the rest; release
the next as the front one fills and nets. Positions always hold their slot;
only resting orders can wait.

## 3. CAPACITY -- SIZING GUIDANCE, NOT ENFORCEMENT

Per instance, one side laddered to cap P, the other flat: **P + K + H + 1**.
Two-sided at cap: **2P + 2(K + H)**. Fleet of N pairs x 2 arms, all one-sided:
`2N x (P + K + H + 1) <= 200 - margin`.

| Fleet | P | K | H | One-sided worst | vs 190 |
|---|---|---|---|---|---|
| 7 pairs, 14 instances | 8 | 3 | 1 | 182 | fits |
| 7 pairs | 12 (majors now) | 3 | 1 | 238 | no |
| 8 pairs (+NZDCHF) | 7 | 3 | 1 | 192 | marginal |
| 10 pairs (+NZDCHF, USDJPY) | 6 | 2 | 0 | 180 | fits |

This table chooses P, K and N. **It is not a guarantee:** two-sided ladders,
legacy books and races can exceed it (DeepSeek rev 3 T-9). The guarantee is
the commitment guard (s4.7). Lowering P is a separate ADR (I7 on reinit).

## 4. DESIGN

### 4.1 One exit-price function

    formula(layer) = Grind_ExitPrice(entry, exit_pips, point, dir)        // grind_pure.mqh ~91
    carry(layer)   = accrued carry pips from the POSITION's swap ledger,
                     computed as Grind_CarryExitShiftLayer does today
                     (grind_carry.mqh ~800: ledger + pending -> Grind_CarryShiftedExitPrice,
                      sign guard applied)
    target(layer)  = carry-shifted theoretical price, or formula if carry is off,
                     data is unavailable, or the sign guard blocks

Used by: release, retry, gap clamp (4.3, 4.5) and reconstruction for layers
without an exit. **Reconstruction must populate `exit_target` for held layers
from this function instead of leaving 0.0** (grind_recon.mqh ~320, ~1015;
`Grind_AppendLayer` grind_engine.mqh ~558 today stores formula only).

When an exit is released or retried at price X, store the applied shift
`X - formula` with `Grind_CarryShiftSet` (grind_carry.mqh ~490), as the carry
pass does after a modify, **and set a release marker for that position**.
`Grind_CarryShiftGetValidated` (~522) must skip the
`Grind_CarryShiftWithinBound` check (~502: (nights+7) x nightly max x 2 pips)
when the marker is present, because a gap clamp can legitimately exceed it.
Marker and shift are deleted together wherever the shift is deleted today.
Without this, a deleted shift makes plain `I6_LONG_EXIT` fire, and I6_*_EXIT is
not quarantinable (grind_quarantine.mqh ~33): an immediate halt
(DeepSeek rev 4 T-2). I6 itself stays strict.

### 4.2 Ranking -- by entry, with target promotion

Base order per side, nearest to market first: **longs ascending entry, shorts
descending entry; ties by lower layer_index.** Entries never move, so carry
cannot churn the base order.

**Promotion:** a layer beyond rank K whose `target` is nearer to market than
the target of the furthest live rank-<=K exit by more than
`InpRankDeadbandPips` is treated as rank <= K; the displaced layer takes its
rank and falls under the hold rule (with H). This covers carry large enough
to invert two targets (DeepSeek rev 4 T-3) without reordering on small
nightly shifts.

One function computes the effective set; the engine and the invariants both
call it, from broker positions every tick. No ranking state lives only in
memory.

### 4.3 Release, hold, and a hold racing a fill

  - **Release:** when a layer enters the effective rank <= K set with no live
    exit and no filled-exit position, place its exit at `target(layer)`
    (clamped, 4.5) in the same event, and store the applied shift and marker
    (4.1).
  - **Retry:** `Grind_RetryMissingExits` (grind_engine.mqh ~1009) recomputes
    `target(layer)` and applies the 4.5 clamp before every attempt, and only
    for ranks <= K. It never re-sends a stale stored price (DeepSeek rev 4
    T-6).
  - **Hold:** when a live exit falls beyond rank K+H, cancel it with
    `Grind_CancelPendingOrder`.
      - DONE: clear `exit_order_ticket`.
      - Not DONE and the order still exists: leave the tracker; retry next tick.
      - Not DONE and the order is gone: look up the fill in deal history by
        order ticket (`DEAL_ORDER` == the exit order ticket) and take its
        `DEAL_POSITION_ID`. If that position is selectable, belongs to this
        magic, and is OPPOSITE in direction to the layer's position, set
        `exit_position_ticket` and queue CloseBy. Otherwise (no deal: the
        order was cancelled elsewhere) clear the tracker. No comment search
        (DeepSeek rev 3 T-4, rev 4 T-5).
  - Release waits for netting: a filled exit counts as coverage
    (`Grind_ReconLayerHasExitCoverage`, grind_recon.mqh ~364) until CloseBy
    removes the layer, so ranks shift only after netting.

### 4.3a Worked example -- one GBPUSD instance, long, K = 2, H = 0

| Step | Positions | Exits live | Exits held | Entry live | Slots |
|---|---|---|---|---|---|
| 1. Today, every exit live, add blocked | L0 L1 L2 L3 | L0 L1 L2 L3 | -- | -- | 8 |
| 2. Queue applied | L0 L1 L2 L3 | L2 L3 | L0 L1 | L4 add | 7 |
| 3. L3 exit fills, nets | L0 L1 L2 | L2 | L0 L1 | L4 add | 5 |
| 4. L1 reaches rank 2, released | L0 L1 L2 | L1 L2 | L0 | L4 add | 6 |
| 5. L2 exit fills, nets | L0 L1 | L1 | L0 | L4 add | 4 |
| 6. L0 released; add corrected | L0 L1 | L0 L1 | -- | L2 add | 5 |

Holding is a standing rule, not a reaction to a blocked entry. Held exits
return at `target(layer)`, never re-priced otherwise. Release is one exit at a
time. Step 6's add correction is existing `Grind_EnsureAddNext` behaviour.

### 4.4 Hysteresis H

An exit is cancelled only beyond rank K+H and released only at rank <= K.
H = 1 absorbs a market oscillating around one level. Cost: H slots per side.

### 4.5 A released exit that price has already passed

Clamp passive against **`target(layer)`** with the existing carry clamps
(`Grind_CarryClampLongExit` / `Grind_CarryClampShortExit`, grind_carry.mqh
~439/~457): long at `ask + min_passive_distance` when target is at or below
it, short at `bid - min_passive_distance`. The placed price is at or better
than target, and the stored applied shift (4.1) makes I6 expect it
(DeepSeek rev 3 T-5).

**Open point:** `Grind_CarryShiftGetValidated` (~522) deletes a stored shift
that fails `Grind_CarryShiftWithinBound` (nightly maximum x nights held). A
large gap clamp could store a shift beyond that bound; the shift would be
deleted and I6 would then see a favourable resting exit and fail. Either the
bound exempts release clamps, or I6 tolerates a favourable RESTING exit
(rev 3's relaxation). Put to DeepSeek and the ruling.

### 4.6 Carry pass

Unchanged for live exits. Held layers need nothing nightly: their carry is
read from the position's swap ledger at release (4.1). The pass continues to
skip layers without an exit order (grind_carry.mqh ~752), which is now
correct by design. (DeepSeek rev 3 T-7.)

### 4.7 Commitment guard -- the enforcement

    free         = ACCOUNT_LIMIT_ORDERS - PositionsTotal() - OrdersTotal()
    resting_ent  = pending orders whose magic is in the fxgrind magic set and
                   whose comment does NOT parse as role EXT
                   (an unparseable fleet order counts as an entry: conservative)
    EXIT send:   allowed when free >= 1
    ENTRY send:  allowed when free - resting_ent >= 2 + InpSlotMargin,
                 evaluated and sent INSIDE a fleet-wide lock

**Lock:** acquire `GRIND_SLOT_LOCK` exactly as `Grind_CapTryAcquireLock`
(grind_cap.mqh ~88) acquires the exposure-cap lock: `GlobalVariableTemp` to
bootstrap (a temporary GV clears on terminal restart), then
`GlobalVariableSetOnCondition` compare-and-set with bounded 1 ms retries.
Inside: recompute `free` and `resting_ent`, send at most one ENT, release.
**On CAS timeout the entry defers (fail closed).** The cap lock has no
staleness timestamp; a holder that dies inside the lock would block entries
fleet-wide until terminal restart. Exits never take the lock.

Every resting entry reserves the slot its future exit will need: an entry
fill plus its exit is net zero on `free - resting_ent`; release after netting
frees 2 and uses 1; a hold frees 1. With entries serialised, the race
DeepSeek rev 4 T-7 constructed (14 simultaneous sends overshooting by 28) is
removed; the margin covers only exit timing. Blocked entries defer with zero
sends; ENT 10040 defers.

### 4.8 Invariants

| Check today (grind_recon.mqh) | Rev 4 |
|---|---|
| I3 exit coverage for EVERY layer (~437, ~458) | Effective ranks 1..K only. **Rank K is hard** (DeepSeek rev 3 T-1). The release lag is one event; quarantine (3000 ms) absorbs it as it absorbs exit placement today |
| I1 exactly one exit for EVERY layer (~480-520) | Layers WITH an exit only |
| I6 exit price (~445, ~466) | Layers with an exit only; unchanged tolerance (4.5 makes relaxation unnecessary) |
| NEW soft I9 | Live exit beyond rank K+H: engine cancels, never halts |
| I4, I5, I7, I8 | Unchanged |

Ranks for invariants use the same effective-set function as the engine (4.2).
**Trim before protect (DeepSeek rev 4 T-8).** Legacy books with every exit
resting are legal (extra exits beyond K+H), but trimming must not wait for the
engine:

  1. `OnInit`, immediately after `Grind_ReconstructState`: cancel live exits
     beyond rank K+H (confirmed-cancel rules, 4.3).
  2. The quarantined branch of `OnTick` (fxgrind.mq5 ~246) runs the same trim
     (cancels only) BEFORE `Grind_RetryMissingExits`.
  3. In `Grind_OnTickEngine`, trim precedes release and retry.

A cancel never needs a free slot, so a naked rank-K layer on a full book gets
the slot its own instance just freed.

### 4.9 Carried forward (DeepSeek rev 1, accepted)

  - `Grind_RetryMissingExits` before L0 placement in `Grind_OnTickEngine`,
    restricted to ranks <= K, recomputing and clamping (4.3).
  - On either halt path, cancel own resting ENT (never EXT). Residual race:
    an entry can fill between halt and cancel; halted instances ignore fills
    (`Grind_OnTradeTransactionEngine` ~1161); that position needs a manual
    close.
  - No fleet flag, no cross-instance eviction.

### 4.10 Halted instances

Queue unmanaged while halted. Live exits keep working; held exits stay held;
the reinitialised engine releases as ranks require. Parking unchanged.

## 5. REQUEST COST

About one extra cancel per add fill beyond K+H, and the release place a scalp
would have needed anyway. No per-tick sends while blocked. Operator-accepted.

## 6. WHAT DOES NOT CHANGE

Geometry, add targets, exit distance rule, ADR-123/124, ADR-149 exposure cap,
exit placement on an ENT fill for a layer ranked <= K, reconstruction's
broker-ticket basis, carry pass behaviour for live exits.

## 7. DEEPSEEK FINDINGS -- DISPOSITION

| Round / # | Finding | Disposition |
|---|---|---|
| R1 T-1 | Flat reserve exhausted by races | Replaced by commitment guard 4.7 |
| R1 T-2 | Limit semantics | Settled by evidence (combined) |
| R1 T-3 | Tracker cleared on failed cancel | Applied in 4.3 |
| R1 T-4, T-7 | Fleet flag needs peer ticks | Dropped |
| R1 T-5 | Halted ignore fills | Residual stated 4.9 |
| R1 T-9 | Recentre modify storm | Rejected (deadband) |
| R1 G7 | I8 cannot catch stale tracker | Accepted; not relied on |
| R3 T-1 | Rank-K miss hides indefinitely | **Accepted.** Rank K hard (4.8) |
| R3 T-2, T-8 | Held layers have exit_target 0.0; no carry in AppendLayer | **Accepted, verified** (grind_recon.mqh ~320, ~1015; grind_engine.mqh ~558). Fixed by 4.1 |
| R3 T-3 | Release timing | Agreed, no exploit |
| R3 T-4 | Hold cancel racing a fill strands tracker | **Accepted.** Confirmed-gone handling 4.3 |
| R3 T-5 | Clamp on raw target vs shifted I6 | **Accepted.** Clamp against target + stored shift (4.5) |
| R3 T-6 | Carry reorders ranks; no tie-break | **Accepted.** Rank by entry, tie by index (4.2) |
| R3 T-7 | Carry pass skips held exits | **Accepted, verified** (grind_carry.mqh ~752). Carry read at release from ledger (4.6) |
| R3 T-9 | Formula not a worst case | **Accepted.** Formula demoted to sizing; guard enforces (s3, 4.7) |
| R3 override | Not fixable without new state | **Rejected as to state:** no new persistent state; the ledger and shift GV already exist |
| R4 T-1, T-4 | Target parity; recon for held layers | Agreed, no exploit |
| R4 T-2 | Clamp shift deleted by bound -> I6 immediate halt | **Accepted, verified** (grind_carry.mqh ~502, grind_quarantine.mqh ~33). Release marker exempts bound (4.1) |
| R4 T-3 | Entry order vs carry-shifted targets strands ladder | **Accepted** (rare). Target promotion with deadband (4.2) |
| R4 T-5 | Confirmed-gone search can pick the other side's EXT | **Accepted.** Deal-history lookup by order ticket, direction check (4.3) |
| R4 T-6 | Retry uses stale unclamped target | **Accepted, verified** (`Grind_RetryMissingExits` ~1009). Recompute and clamp (4.3) |
| R4 T-7 | Guard race exceeds margin; unparsed ENT uncounted | **Accepted.** Fleet lock (pattern grind_cap.mqh ~95); conservative count (4.7) |
| R4 T-8 | Deploy on full book halts before trim | **Accepted.** Trim in OnInit and quarantine branch (4.8) |

## 8. TESTS (outline)

  1. `target()` equals the carry pass's theoretical price for the same position;
     falls back to formula when data is unavailable or the sign guard blocks.
  2. Reconstruction populates `exit_target` for held layers (never 0.0).
  3. Release stores applied shift and marker; a shift beyond
     `Grind_CarryShiftWithinBound` survives validation; I6 passes strict.
  4. Base ranking by entry, tie by index; a small carry change never reorders;
     an inversion beyond `InpRankDeadbandPips` promotes the held layer.
  5. K nearest live; beyond K+H cancelled; K+1..K+H left as found.
  6. Front fill -> net -> release in the same event; rank-K I3 passes within
     the quarantine window at worst.
  7. Retry after a gap recomputes and clamps; never sends the stale price.
  8. Hold cancel: DONE / not-DONE-live / gone-with-deal (opposite direction
     only; CloseBy queued) / gone-without-deal / deal on the other side
     ignored.
  9. Guard under lock: two instances contending send exactly one ENT at the
     boundary; CAS timeout defers the entry; unparseable fleet order counted
     as ENT.
 10. Conservation over place / fill / exit / net / release / hold / halt-cancel.
 11. Two-sided book near 200: no exit refused within margin.
 12. Full legacy book at deploy with an ENT filling before the first engine
     tick: OnInit trim frees a slot; exit placed; no halt.
 13. Quarantine branch trims before retry.
 14. Halt (both paths) cancels own ENT only.
 15. Suite baseline reported.

## 9. QUESTIONS FOR THE RULING

  1. K, H, `InpSlotMargin`, `InpRankDeadbandPips`: values; fleet-wide or per
     preset.
  2. Release marker exempting the carry bound (4.1) vs relaxing I6 for a
     favourable resting exit: Claude recommends the marker (I6 stays strict).
  3. Fleet lock for entry sends (4.7): acceptable, and does it need staleness
     recovery the cap lock lacks?
  4. Halt contract: cancel own ENT on halt (4.9)?
  5. Trim in OnInit and during quarantine (4.8): acceptable as the only order
     actions outside the engine?
  6. P: accept majors 12 -> 8 as a follow-on ADR?
  7. Commitment guard capacity cost (~2 slots per running instance): accept?

## 10. RISKS

  - Race beyond margin on exit timing alone can still refuse an exit; rank-K
    I3 quarantines and may halt, as today but far less often.
  - Lock holder dies inside the lock (no staleness recovery in the cap-lock
    pattern): entries fleet-wide defer until terminal restart; exits
    unaffected. Fail closed, but a harvest outage.
  - Residual halt race (4.9).
  - Deal history not yet available when a hold cancel fails: treated as no
    deal on that tick; retried next tick before clearing.

## 11. NOT IN SCOPE

The layer-cap change and its I7 migration; adding or retiring instances;
closing or resetting deep layers; a second account.


=====================================================================
DEEPSEEK R1 FINAL REPORT ON REV 4 (verbatim from prompts/deepseek_order_purgatory_rev4_response.md; non-ASCII punctuation normalised)
=====================================================================

## Final Report

## T-1 TARGET PARITY
- **VERDICT:** NO-EXPLOIT
- **LOAD-BEARING CLAIM:** `grind_recon.mqh : Grind_ReconCheckInvariants / Grind_ReconExitMatchesEntry` -- I6 computes `expected = formula + Grind_CarryShiftGetForRecon(position_id)`. Release stores `X - formula` via `Grind_CarryShiftSet`, so `expected = X` unless G4 deletes the shift.
- **MINIMAL REPRO / MECHANISM:** Ledger changes between release and rebuild do not affect I6 because I6 does not recompute carry from the ledger; it uses the stored shift GV. Sign-guard flips at release only affect `target()`, which if blocked yields `formula` and stores shift `0`. Therefore parity holds for all cases except validated-shift deletion, which is T-2.
- **SEVERITY:** cosmetic
- **IF FIXABLE:** N/A

## T-2 SHIFT BOUND
- **VERDICT:** EXPLOIT-FOUND
- **LOAD-BEARING CLAIM:** `grind_carry.mqh : Grind_CarryShiftGetValidated` deletes a stored shift failing `Grind_CarryShiftWithinBound`; `grind_recon.mqh : Grind_ReconCheckInvariants` then uses shift 0 in I6; `grind_quarantine.mqh : Grind_IsQuarantinableReason` does not include plain `I6_LONG_EXIT` / `I6_SHORT_EXIT`.
- **MINIMAL REPRO / MECHANISM:** Long layer entry 1.1000, exit_pips 50, formula 1.1050. Market gaps to 1.2000. Layer held beyond K+H. Front exits fill and net until layer reaches rank <= K. Release computes `target = 1.1050`, clamps long to `ask + min_dist = 1.2000 + min`. Store shift ~950 pips. `Grind_CarryShiftWithinBound`: open_time recent, nightly_max ~1-2 pips, max_price `(0+7)*nightly*2` ~14-28 pips. 950 > max. Next rebuild: `Grind_CarryShiftGetValidated` deletes and returns 0. I6 expects 1.1050, sees 1.2000+min, diff > 2 points, exit resting. `I6_LONG_EXIT` is not quarantinable -> immediate halt.
- **SEVERITY:** fixable-within-design
- **IF FIXABLE:** Exempt release shifts from `Grind_CarryShiftWithinBound` (separate GV namespace or marker), or relax I6 to tolerate a favourable RESTING exit (rev 3's relaxation).

## T-3 RANK BY ENTRY
- **VERDICT:** DESIGN-UNSAFE
- **LOAD-BEARING CLAIM:** memo 4.2 ranks by entry; memo 4.1 `target()` includes carry shift. `grind_carry.mqh : Grind_CarryShiftedExitPrice` can move a target by more than add spacing.
- **MINIMAL REPRO / MECHANISM:** Long K=1. L1 entry 1.0900 (rank 1 live), L0 entry 1.1000 (rank 2 held). L1 has adverse carry moving its target up to 1.1050; L0 has favourable carry moving its target down to 1.0850. Market 1.0900. L1 live exit is far above; L0 held target is below market. Price falls to 1.0850, passing L0's target, but L0 is held so no fill. L1 never fills, so L0 never releases. Ladder stuck. Memo s10 only notes the held exit is passed and release clamps; it does not note the live exit can be unreachable and the held exit never releases.
- **SEVERITY:** fixable-within-design
- **IF FIXABLE:** Rank by `target()` with a carry-shift deadband / stable tie-break to avoid churn, or allow a held exit to be released early when its target becomes more passive than the current rank-K live exit.

## T-4 RECON FOR HELD LAYERS
- **VERDICT:** NO-EXPLOIT
- **LOAD-BEARING CLAIM:** `grind_recon.mqh : Grind_ReconstructState` runs after magic lock in `fxgrind.mq5 : OnInit`; `grind_carry.mqh : Grind_CarryPositionSwapVolume` uses `PositionSelectByTicket` and `POSITION_SWAP`; memo 4.1 says `target()` falls back to `formula` if carry is off or sign guard blocks.
- **MINIMAL REPRO / MECHANISM:** Reconstruction has magic, slot, exit_pips, point, and selectable positions. Position swap is available via `PositionSelectByTicket`. If swap/tick_value/tick_size/volume is missing, `target()` falls back to `formula`. Sign guard blocks also yield `formula`. No path returns 0.0 for a held layer.
- **SEVERITY:** cosmetic
- **IF FIXABLE:** N/A

## T-5 HOLD CANCEL (C4)
- **VERDICT:** EXPLOIT-FOUND
- **LOAD-BEARING CLAIM:** memo 4.3 hold-cancel confirmed-gone searches positions for this magic and layer index; `grind_closeby.mqh : Grind_ProcessCloseByQueue` halts on `GRIND_CLOSEBY_EXHAUSTED` if both legs remain selectable; `grind_engine.mqh : Grind_HandleSideDealFill` also queues CloseBy for the correct EXT.
- **MINIMAL REPRO / MECHANISM:** Hold cancel for long layer 2 fails (order filled). Search by magic+layer_index omits side. Finds short layer 2 EXT position (BUY). Sets long layer `exit_position_ticket` to short position. Queues CloseBy(long ENT BUY, short EXT BUY). Broker rejects same-direction CloseBy. After 10 retries both still selectable -> `GRIND_CLOSEBY_EXHAUSTED` halt. Or comment truncation makes parse fail, search clears tracker, EXT position remains; next tick `Grind_RetryMissingExits` places a new exit -> `I2_LONG_EXIT_DUP` quarantine and possible halt.
- **SEVERITY:** fixable-within-design
- **IF FIXABLE:** On confirmed-gone, resolve the filled EXT position by querying history for the deal with the failed order ticket (`DEAL_ORDER`) to obtain `position_id`, instead of comment search. If comment search is kept, filter by side and slot.

## T-6 RANK-K HARD (C7)
- **VERDICT:** EXPLOIT-FOUND
- **LOAD-BEARING CLAIM:** `fxgrind.mq5 : OnTick` quarantine branch calls only `Grind_RetryMissingExits` and returns; `grind_engine.mqh : Grind_RetryMissingExits` calls `Grind_TryPlaceExitForLayer` with stored `layer.exit_target`; C1 populates at reinit but does not re-clamp on market move.
- **MINIMAL REPRO / MECHANISM:** K=1, L0 live, L1 held. L0 exit fills, CloseBy nets, L0 removed. Next OnTick: I3 sees L1 rank 1 no exit -> quarantine. OnTick enters quarantine, calls `Grind_RetryMissingExits`. L1 `exit_target` is stale (e.g., 1.1050 for long). Market gapped to 1.1100. Sell limit at 1.1050 is below ask -> invalid price, place fails. Next ticks repeat. After 3 checks / 3000 ms -> halt. `OnTimer` does no trading.
- **SEVERITY:** fixable-within-design
- **IF FIXABLE:** Make `Grind_RetryMissingExits` recompute `target(layer)` and apply the 4.5 clamp before placing, identical to the `Grind_OnTickEngine` release path.

## T-7 COMMITMENT GUARD (C8)
- **VERDICT:** EXPLOIT-FOUND
- **LOAD-BEARING CLAIM:** memo 4.7 guard is terminal-local and non-atomic; `resting_ent` counts only parsed ENT comments of any magic; one ENT send per instance per tick.
- **MINIMAL REPRO / MECHANISM:** 14 instances evaluate guard concurrently. `free - resting_ENT = 2 + margin` (e.g., 8 for margin 6). Each instance sees condition true and sends one ENT. 14 sends consume 28 from `free - resting_ENT`, overcommitting by 20. Broker accepts until the 200 limit; exits may be refused or blocked. Also unparsed ENT comments (truncation) are not counted in `resting_ent`, so their reserved slots are invisible.
- **SEVERITY:** fixable-within-design
- **IF FIXABLE:** Increase `InpSlotMargin` to at least `2*N + safety` (e.g., 28+ for 14 instances), implement a terminal-wide critical section around ENT send (GlobalVariable lock), and count all pending orders with magic in the fxgrind namespace regardless of parse.

## T-8 TRANSITION
- **VERDICT:** EXPLOIT-FOUND
- **LOAD-BEARING CLAIM:** `fxgrind.mq5 : OnTick` runs invariant check and quarantine branch before `Grind_OnTickEngine`; `grind_engine.mqh : Grind_OnTickEngine` contains hold-cancel trim; memo 4.7 blocks EXIT send when `free < 1`.
- **MINIMAL REPRO / MECHANISM:** Initial book `free = 0`, 20 ENT resting. An existing ENT fills before the first `Grind_OnTickEngine` trim. `Grind_HandleSideDealFill` tries to place exit; `free = 0` so exit send is blocked/fails. Layer naked. First OnTick: I3 fails (if rank <= K) -> quarantine. Quarantine branch skips `Grind_OnTickEngine`, so no trim. `Grind_RetryMissingExits` cannot place exit because `free = 0`. 3 checks / 3000 ms -> halt.
- **SEVERITY:** fixable-within-design
- **IF FIXABLE:** Perform excess-exit trim (cancel beyond K+H) in `OnInit` after `Grind_ReconstructState`, or allow `Grind_OnTickEngine` trim during quarantine, or prioritise cancels before invariant check. The guard must permit exit placement when cancelling an excess exit can free a slot.

## GIVENS CHECK
G1-G8 are accurate against `9f67f0f`; no source counterexample found.  
- G1: `Grind_ReconEnsureLayer` sets `exit_target = 0.0`; rebuild copies EXT order/position price.  
- G2: `Grind_AppendLayer` stores formula only.  
- G3: `Grind_CarryExitShiftLayer` ledger + pending + sign guard + clamp + `Grind_CarryShiftSet(applied = new_exit - formula)`.  
- G4: `Grind_CarryShiftGetValidated` deletes out-of-bound shifts; `Grind_CarryShiftGetForRecon` calls it.  
- G5: `Grind_CarryExitPassBegin` skips layers with `exit_order_ticket == 0`.  
- G6: `Grind_ReconExitMatchesEntry` favourable only when filled.  
- G7: `Grind_CancelPendingOrder` requires `TRADE_RETCODE_DONE`; `Grind_HandleSideDealFill` queues CloseBy on EXT fill; halted instances skip.  
- G8: I3 quarantinable; I5/I7 not.

## REV 3 FIXES CHECK
- **R3 T-1:** Does not fully hold -- rank K hard, but release path in quarantine can fail on stale unclamped `exit_target` (T-6).
- **R3 T-2/T-8:** Holds for 0.0 -- C1 populates held `exit_target`; no 0.0 path found (T-4), but stored target can become stale (T-6).
- **R3 T-4:** Partially holds -- C4 handles confirmed-gone, but search can mis-identify EXT position if not side-filtered (T-5).
- **R3 T-5:** Fails -- C5 stores release shift; G4 deletes it if over bound, then I6 halts (T-2).
- **R3 T-6:** Holds for rank stability -- entry ranking never reorders; but fill-ordering mismatch remains (T-3).
- **R3 T-7:** Holds -- carry pass unchanged for live exits; held carry read at release.
- **R3 T-9:** Fails under fleet race -- commitment guard non-atomic and ignores unparsed ENT (T-7).

## PREMISE VERDICT
The premise survives. No finding requires abandoning the exit-queue + commitment-guard design. Required fixes are: exempt release shifts or relax I6 (T-2), rank on target with deadband or early release (T-3), robust history lookup for hold-cancel (T-5), clamp in `Grind_RetryMissingExits` (T-6), strengthen guard margin/lock and count all ENT (T-7), trim before invariant or during quarantine (T-8). All are within design.

OVERRIDE CHECK: No finding kills the premise; all identified failure modes are fixable within the design by the stated minimal changes.

=====================================================================
END. Respond in the required format.

Line count: 487
