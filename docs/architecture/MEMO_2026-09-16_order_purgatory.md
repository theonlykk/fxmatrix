This message has a line count at the bottom

# DESIGN MEMO -- ORDER PURGATORY: EXIT QUEUE, CAPACITY FORMULA, SLOT GUARD (REV 3)

| | |
|---|---|
| Status | **REV 3 DRAFT.** Supersedes rev 2 (never sent to Gemini). Proposed number: ADR-151 |
| Author | Claude (lead engineer), 2026-09-16 |
| Operator | Khalid. Concept and the exit-queue insight: an order that cannot fill until others fill first should not hold a slot |
| Evidence | `HANDOFF_2026-09-16.md` s1-2, `HANDOFF_2026-09-16b.md` (FOMC) |
| Prior red team | DeepSeek on rev 1: `prompts/deepseek_order_purgatory_response.md` (`e83b52f`). Rev 3 carries forward its accepted fixes (s7) |
| Source read | fxmatrix `e83b52f`: `grind_engine.mqh`, `fxgrind.mq5`, `grind_recon.mqh`, `grind_quarantine.mqh`, `grind_carry.mqh` |
| Review path | **DeepSeek (mandatory: changes invariants and order lifecycle)** -> Gemini ruling -> Cursor spec |

---

## 1. PROBLEM

The account allows **200 positions + pending orders combined**
(`ACCOUNT_LIMIT_ORDERS=200`; refusals occurred with ~113 orders resting, so on
this account it counts both). At 200 the terminal refuses the next order
locally (10040). Because a fill turns an order into a position, the refused
order is the exit placed after a fill. The layer goes I3_NAKED, quarantine
cannot outlast the limit, the instance halts. 2026-09-16: 14+ halt events,
untracked fills on halted instances, a request storm (822 -> 3,414 in 23
minutes), and every reinit into a full book re-halted.

Book at 21:47Z: 92 positions + 88 exit orders + 20 entry orders = 200.

## 2. THE INSIGHT

**Most resting exits cannot fill until other exits fill first.**

On a long ladder every exit is a SELL LIMIT above market. The deepest layer's
exit is nearest to price; L00's exit is furthest. Price must rise through the
nearer exits before it can reach the far ones. GBPUSD ALT at 21:47Z held 12
resting exits from 1.34011 to 1.35212; eleven of them could not fill before
the first did. Shorts mirror this.

Those far exits hold slots and do no work. **Keep only the K nearest exits per
side on the book; hold the rest in purgatory; release the next one as the
front one fills.** Positions cannot be held back -- an open position always
holds its slot. Only resting orders can wait.

## 3. CAPACITY FORMULA

Per instance, one side laddered to the cap P, the other flat (worst normal
case):

    positions P  +  live exits (K + H)  +  one L0 on the flat side   =   P + K + H + 1

(One layer below cap gives the same total: P-1 positions + K+H exits + 1 add +
1 L0.) H is the hysteresis band in s4.3. Two-sided ladders (EURGBP style) are
2P + 2(K + H).

Fleet, N pairs x 2 arms, all one-sided at cap at once (a USD move does this to
every USD pair):

    2N x (P + K + H + 1)  <=  200 - margin

| Fleet | P | K | H | Worst case | vs 190 (margin 10) |
|---|---|---|---|---|---|
| Today, 7 pairs, 14 instances | 8 | 3 | 1 | 182 | fits |
| Today, 7 pairs | 8 | 4 | 0 | 182 | fits |
| Today, 7 pairs | 12 (majors now) | 3 | 1 | 238 (majors) | no |
| 8 pairs (+NZDCHF) | 7 | 3 | 1 | 192 | marginal |
| 10 pairs (+NZDCHF, USDJPY) | 6 | 2 | 0 | 180 | fits |
| 10 pairs | 4 | 3 | 1 | 180 | fits |

**Conclusions:** the exit queue alone frees 35-49 slots on today's book, but
the formula only holds in the worst case if **P** comes down (majors 12 -> 8).
Adding pairs needs a lower P, a lower K, or a second account. P, K and N are
one decision; this memo proposes K and H and records the P implication. The
cap change itself is a separate ADR because lowering P trips I7 on reinit
(`HANDOFF_2026-09-16` s7 traps).

## 4. DESIGN

### 4.1 Which exits are live -- stateless, derived every tick

For each side, sort that instance's layers by exit target, nearest to market
first:

  - longs: ascending exit target (every resting long exit is above bid, so
    lowest = nearest)
  - shorts: descending exit target

The first **K** layers in that order MUST have a live exit. Layers ranked
K+1..K+H MAY have a live exit. Layers ranked beyond K+H MUST NOT.

The ordering depends only on broker positions and the exit price rule
(entry +/- exit_pips + carry shift), so it is recomputed from the broker book
every tick and after reinit. **No held-exit state lives only in memory.**

Carry shift: `Grind_CarryShiftGetForRecon` (grind_carry.mqh ~547) already
reads a validated per-position shift from persisted state, so a held exit's
target is recoverable after reinit.

### 4.2 Release and hold

  - **On a layer becoming nearest-K without a live exit** (front exit filled
    and netted, or a new deeper layer appended): place its exit in the same
    event handler that caused it. Exits are always allowed by the guard (s4.5).
  - **On a live exit falling beyond rank K+H** (a new deeper layer pushed it
    back): cancel it with `Grind_CancelPendingOrder` and **clear the layer's
    exit tracker only on a confirmed cancel or confirmed gone** -- the pattern
    `Grind_EnsureAddNext` already uses (DeepSeek rev 1 T-3).

### 4.2a Worked example -- one GBPUSD instance, long, K = 2, H = 0

Layers are numbered without gaps; an exit fill first opens an opposite
position, and slots are freed only when CloseBy nets the pair.

| Step | Positions | Exits live | Exits held | Entry live | Slots |
|---|---|---|---|---|---|
| 1. Today, every exit live, add blocked | L0 L1 L2 L3 | L0 L1 L2 L3 | -- | -- | 8 |
| 2. Queue applied | L0 L1 L2 L3 | L2 L3 | L0 L1 | L4 add | 7 |
| 3. L3 exit fills, nets | L0 L1 L2 | L2 | L0 L1 | L4 add | 5 |
| 4. L1 reaches rank 2, released | L0 L1 L2 | L1 L2 | L0 | L4 add | 6 |
| 5. L2 exit fills, nets | L0 L1 | L1 | L0 | L4 add | 4 |
| 6. L0 released; add corrected | L0 L1 | L0 L1 | -- | L2 add | 5 |

Notes:
  - Holding is a standing rule, not a reaction to a blocked entry: cancelling
    at the moment of need means cancelling while the account is refusing
    orders.
  - Held exits return at their original price (entry +/- exit_pips + carry
    shift). They are not re-priced.
  - Release is one exit at a time, as each reaches rank K.
  - Step 6's add correction is existing behaviour: `Grind_EnsureAddNext`
    cancels a resting add whose label no longer matches the next index and
    places the correct one.

### 4.3 Hysteresis H

Without H, a market oscillating around one level churns: an add fills (new
exit placed, K+1-th cancelled), the front exit fills (held exit re-placed),
repeat. With H = 1 an exit is cancelled only when it falls to rank K+2, and
re-placed only when it rises to rank K. Cost: H extra slots per side.

### 4.4 A released exit that price has already passed

If a held exit's target is already through the market when released (a gap
through several levels between ticks), placing it at target would be an
invalid or marketable limit. Rule: **clamp to the passive side** --
long exit at `max(target, bid + stops_level)`, short exit at
`min(target, ask - stops_level)` -- using the existing ADR-013 clamp pattern.
It never crosses the spread and exits at or better than target.
**Consequence:** I6 (`Grind_ReconExitMatchesEntry`, grind_recon.mqh ~340)
today tolerates a favourable price only for a FILLED exit. It must also
tolerate a favourable resting exit, or the clamp halts the instance.

### 4.5 Slot guard (what remains of rev 2's budget)

    free = ACCOUNT_LIMIT_ORDERS - PositionsTotal() - OrdersTotal()
    EXIT sends:  allowed when free >= 1
    ENTRY sends: allowed when free >= 2 + InpSlotMargin

Terminal-local, no server request. With the queue sized by s3 this guard
should rarely bind; it is the backstop for configuration drift and races.
A blocked entry is deferred with zero sends. An ENT 10040 defers instead of
retrying next tick.

### 4.6 Invariants -- the changes

| Check today (grind_recon.mqh) | Rev 3 |
|---|---|
| I3 `no_exit_coverage` for EVERY layer (~437, ~458) | Required only for ranks 1..J, J = max(1, K-1). Rank K is the release target; allowing one event for it avoids quarantine on every front fill |
| I1 `exit_count != 1` for EVERY layer (~480-520) | Layers WITH an exit: exactly one. Layers without an exit: skipped |
| I6 exit price (~445, ~466) | Only layers with an exit; favourable resting price tolerated (s4.4) |
| NEW I9 | A live exit beyond rank K+H: soft (engine cancels it), never halts |
| I4 orphan exit, I5, I7, I8 | Unchanged |

**Transition:** today's books carry every exit. Under rev 3 the extra exits
are simply ranks beyond K+H: legal, and trimmed by the engine over the first
ticks. Reinit needs no migration.

### 4.7 Carried forward from rev 2 (DeepSeek-accepted)

  - Move `Grind_RetryMissingExits` before L0 placement in
    `Grind_OnTickEngine` (T-6: no adverse interaction).
  - On either halt path, cancel own resting ENT orders (never EXT). Residual
    race stated: an entry can fill between halt and cancel; halted instances
    ignore fills (`Grind_OnTradeTransactionEngine` ~1161) so that position
    needs a manual close (T-5).
  - Rev 1's fleet flag and cross-instance eviction: **dropped** (T-4, T-7).

### 4.8 Halted instances

A halted instance does not manage its queue. Live exits keep working; held
exits stay held; when a live exit fills and is netted on reinit, the next
exit is released by the reinitialised engine. Parking (delete ENT, close
naked) is unchanged.

## 5. REQUEST COST

Each new deepest layer beyond K+H costs one extra cancel (the exit pushed
back). Each scalp that releases a held exit costs one place that would
otherwise have happened at fill time anyway. Net: roughly one extra cancel
per add fill. Operator-accepted; small against a refusal storm.

## 6. WHAT DOES NOT CHANGE

Geometry, targets, exit distance rule, ADR-123/124, the ADR-149 exposure cap,
exit placement on an ENT fill for a layer ranked within K, reconstruction's
broker-ticket basis.

## 7. PRIOR DEEPSEEK FINDINGS -- STATUS UNDER REV 3

| # | Rev 1 finding | Rev 3 |
|---|---|---|
| T-1 | Flat reserve exhausted by races | Mechanism replaced. Capacity now bounded by s3; guard s4.5 as backstop |
| T-2 | Limit semantics / non-atomic counts | Semantics settled by evidence; guard reads are backstop only |
| T-3 | Tracker cleared on failed cancel | Applied to BOTH entry eviction and exit hold (s4.2) |
| T-4, T-7 | Fleet flag depends on peer ticks | Dropped |
| T-5 | Halted instances ignore fills | Residual stated (s4.7) |
| T-9 | Recentre modify storm | Rejected as stated (deadband); unchanged |
| G7 | I8 cannot catch a stale tracker | Accepted; not relied on |

## 8. TESTS (outline)

  1. Ranking: longs ascending, shorts descending, carry shift applied.
  2. K nearest get exits; ranks beyond K+H get none; K+1..K+H left as found.
  3. Front exit fill -> netted -> next held exit placed in the same event.
  4. New deepest layer -> its exit placed; rank K+H+1 exit cancelled.
  5. Cancel non-DONE with order live: tracker NOT cleared; no duplicate on
     release (would be I2).
  6. Hysteresis: add/exit/add/exit at one level produces no cancel churn with
     H = 1.
  7. Gap release: target through market -> clamped passive price; I6 passes.
  8. Invariants: missing exit at rank <= J fails I3; at rank K passes one
     event; beyond K+H never fails.
  9. Reinit on a legacy full-exit book: passes; engine trims to K+H.
 10. Reinit on a held book: ranks recomputed; releases correct.
 11. Guard: entry deferred at `free < 2 + margin`; exit placed at `free == 1`.
 12. Halt (both paths) cancels own ENT only.
 13. Suite baseline reported.

## 9. QUESTIONS FOR THE RULING

  1. K and H values; one fleet-wide input or per-preset.
  2. J = max(1, K-1) for I3: sound, or must rank K be hard?
  3. Passive clamp on gap release (s4.4) and the I6 relaxation.
  4. P: accept that the formula needs majors 12 -> 8 (separate ADR)?
  5. Two-sided ladders: separate cap for EURGBP-type pairs, or accept the
     rarer worst case?
  6. Halt contract: cancel own ENT on halt?

## 10. RISKS

  - Invariant relaxation could hide a genuinely lost far exit. Mitigated: far
    exits are re-placed deterministically when they reach rank K; a lost NEAR
    exit still fails I3 at rank <= J.
  - A gap through more than K+H levels releases several clamped exits at once;
    they fill near the same price. Acceptable: at or better than target.
  - Worst-case capacity depends on P, which this ADR does not change.

## 11. NOT IN SCOPE

The layer-cap change and its I7 migration; retiring or adding instances;
closing or resetting deep layers; a second account.

Line count: 263
