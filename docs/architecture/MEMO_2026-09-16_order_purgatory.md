This message has a line count at the bottom

# DESIGN MEMO -- ORDER PURGATORY: EXIT QUEUE + COMMITMENT GUARD (REV 4)

| | |
|---|---|
| Status | **REV 4 DRAFT.** Supersedes rev 3. Proposed number: ADR-151 |
| Author | Claude (lead engineer), 2026-09-16 |
| Operator | Khalid. Concept and the exit-queue insight: an order that cannot fill until others fill first should not hold a slot |
| Evidence | `HANDOFF_2026-09-16.md` s1-2, `HANDOFF_2026-09-16b.md` (FOMC) |
| Red team | DeepSeek rev 1: `prompts/deepseek_order_purgatory_response.md` (`e83b52f`); rev 3: `prompts/deepseek_order_purgatory_rev3_response.md` (`9f67f0f`). Dispositions s7 |
| Source read | fxmatrix `9f67f0f`: `grind_engine.mqh`, `fxgrind.mq5`, `grind_recon.mqh`, `grind_quarantine.mqh`, `grind_carry.mqh`, `grind_pure.mqh` |
| Review path | **DeepSeek (focused on rev 4 changes)** -> Gemini ruling -> Cursor spec |

**Rev 3 -> rev 4:** rev 3 assumed the EA knows a held layer's exit price. It
does not: reconstruction leaves `exit_target = 0.0` without an exit order, and
the nightly carry pass only touches live exits. Rev 4 defines one exit-price
function used everywhere, ranks by entry price, makes rank K a hard invariant,
handles a hold-cancel racing a fill, and restores rev 2's commitment guard as
the enforcement that holds for any book shape.

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
    target(layer)  = carry-shifted theoretical price, or formula if carry is off
                     or the sign guard blocks

Used by: release (4.3), gap clamp (4.5), and reconstruction for layers
without an exit. **Reconstruction must populate `exit_target` for held layers
from this function instead of leaving 0.0** (grind_recon.mqh ~320, ~1015;
`Grind_AppendLayer` grind_engine.mqh ~558 today stores formula only).

When a held exit is released at price X, store the applied shift
`X - formula` with `Grind_CarryShiftSet` (grind_carry.mqh ~490), exactly as
the carry pass does after a modify. I6 then validates the live exit against
the same shift it always has.

### 4.2 Ranking -- by entry price

Per side, rank layers by **entry price**, nearest to market first. Longs
ladder downward, so the deepest layer (lowest entry) is nearest: **longs
ascending entry, shorts descending entry.** Ties: lower layer_index first.

Why entry, not target: entry never changes. Ranking by carry-shifted target
lets a nightly carry pass reorder ranks and churn cancels (DeepSeek rev 3
T-6). Entries are spaced by add_pips (6-14 pips); order by entry equals order
by formula exit. Carry only moves prices, never ranks.

### 4.3 Release, hold, and a hold racing a fill

  - **Release:** when a layer reaches rank <= K with no live exit and no
    filled-exit position, place its exit at `target(layer)` (clamped, 4.5)
    in the same event, and store the applied shift (4.1).
  - **Hold:** when a live exit falls beyond rank K+H, cancel it with
    `Grind_CancelPendingOrder`.
      - DONE: clear `exit_order_ticket`.
      - Not DONE and the order still exists: leave the tracker; retry next tick.
      - Not DONE and the order is gone: search positions for this magic with
        comment role EXT and this layer index. If found, set
        `exit_position_ticket` and queue CloseBy (the fill was missed). If not
        found, clear the tracker. (DeepSeek rev 3 T-4.)
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
    resting_ent  = pending orders whose comment parses with role ENT, any magic
    EXIT send:   allowed when free >= 1
    ENTRY send:  allowed when free - resting_ent >= 2 + InpSlotMargin
    at most one ENT send per instance per tick

Terminal-local, no server request. Every resting entry reserves the slot its
future exit will need; an entry fill plus its exit is net zero on
`free - resting_ent`. Release after netting frees 2 and uses 1. Hold frees 1.
So exits always find a slot, whatever the book shape, except in a race larger
than the margin. Blocked entries defer with zero sends; ENT 10040 defers.

### 4.8 Invariants

| Check today (grind_recon.mqh) | Rev 4 |
|---|---|
| I3 exit coverage for EVERY layer (~437, ~458) | Ranks 1..K only. **Rank K is hard** (DeepSeek rev 3 T-1). The release lag is one event; quarantine (3000 ms) absorbs it as it absorbs exit placement today |
| I1 exactly one exit for EVERY layer (~480-520) | Layers WITH an exit only |
| I6 exit price (~445, ~466) | Layers with an exit only; unchanged tolerance (4.5 makes relaxation unnecessary) |
| NEW soft I9 | Live exit beyond rank K+H: engine cancels, never halts |
| I4, I5, I7, I8 | Unchanged |

Ranks for invariants use the same entry-price order as the engine (4.2).
**Transition:** legacy books with every exit resting are legal (extra exits
beyond K+H) and trimmed by the engine; the guard blocks entries until free
recovers.

### 4.9 Carried forward (DeepSeek rev 1, accepted)

  - `Grind_RetryMissingExits` before L0 placement in `Grind_OnTickEngine`,
    and restricted to ranks <= K.
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

## 8. TESTS (outline)

  1. `target()` equals the carry pass's theoretical price for the same position.
  2. Reconstruction populates `exit_target` for held layers (never 0.0).
  3. Release stores applied shift; I6 passes on the next rebuild.
  4. Ranking by entry; tie by layer_index; a carry change never reorders.
  5. K nearest live; beyond K+H cancelled; K+1..K+H left as found.
  6. Front fill -> net -> release in the same event; I3 at rank K passes after
     quarantine window at worst.
  7. Hold cancel: DONE / not-DONE-live / gone-with-exit-position (CloseBy
     queued) / gone-without.
  8. Gap release: clamped passive vs target; shift within bound or exempt; I6 passes.
  9. Guard: entry blocked at `free - resting_ent < 2 + margin`; exit at
     `free == 1`; conservation over place/fill/exit/net/release/hold.
 10. Two-sided book near 200: no exit refused within margin.
 11. Legacy full-exit book on reinit: legal; trimmed; entries blocked until
     free recovers.
 12. Halt (both paths) cancels own ENT only.
 13. Suite baseline reported.

## 9. QUESTIONS FOR THE RULING

  1. K, H, `InpSlotMargin`: values; fleet-wide or per preset.
  2. Rank by entry (stable) vs by target (exact): accept entry?
  3. Halt contract: cancel own ENT on halt?
  4. P: accept majors 12 -> 8 as a follow-on ADR?
  5. Commitment guard capacity cost (~2 slots per running instance): accept?
  6. Gap-clamp shift vs `Grind_CarryShiftWithinBound`: exempt, or relax I6?

## 10. RISKS

  - Accrued carry larger than add spacing could make a held exit nearer to
    market than a live one; price would pass it and the release clamps
    passive. Rare; at or better than target.
  - Race beyond margin can still refuse an exit; rank-K I3 then quarantines
    and may halt, as today but far less often.
  - Residual halt race (4.9).

## 11. NOT IN SCOPE

The layer-cap change and its I7 migration; adding or retiring instances;
closing or resetting deep layers; a second account.

Line count: 275
