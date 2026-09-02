# FXMatrix EA — Fable 5 Full Audit Brief
# Date: 2026-06-11
# Model: Claude Code (full repo loaded at d:\fxmatrix\ea\)
# Auditor role: Adversarial architect + lead engineer
# All 7 files in scope: FXMatrix.mq5, Globals.mqh,
#   LayerStruct.mqh, MathEngine.mqh, ExecutionEngine.mqh,
#   CarryEngine.mqh, StateEngine.mqh

---

## STANDING INSTRUCTION

Assume every formula is wrong until proven correct.
For each mathematical expression, derive the result
from first principles and verify it produces the
expected physical price or spread value.

Do not accept prior rulings as correct without
re-deriving them. Flag any case where the result
is surprising, even if it appears intentional.

This is a Red Team + Blue Team combined pass.
Identify bugs, architectural flaws, race conditions,
and state corruption risks. Then propose fixes.

---

## CONTEXT

FXMatrix is a 3-currency mean-reversion EA trading
EUR/GBP/USD on FTMO MT5 (hedging mode, $10k, 1:30).

Signal decomposition (always produces negative spread):
  r_EU = log(EURUSD_now / anchor_EU)
  r_GB = log(GBPUSD_now / anchor_GB)
  usd  = -(r_EU + r_GB) / 3
  eur  =   r_EU + usd
  gbp  =   r_GB + usd
  spread = scores[weakest] - scores[strongest] ≤ 0

Entry: passive limit at InvertSpreadToPrice(spread)
Exit: passive limit at entry_spread × (1 - ExitFraction)
Layer spacing: ComputeNextLayerPrice() differential

Current HEAD: 0bba98c
DIRECTION_BUY = 1, DIRECTION_SELL = -1

Recent patches (this session):
- Patch 4: MathAbs(T) sign fix for EURUSD/GBPUSD
- Patch 5: Pending entry invalidation on signal change
- Patch 5a: Remove _Symbol filter from CancelAllPendingEntries
- Patch 6: Value-based hysteresis rotation guard
- Patch 7: Entry price formula — use T directly not
           r_GB_fixed/r_EU_fixed cross-contamination

---

## TIER 1 — IMMEDIATE BLOCKERS

### 1. add_next=3.35863 on EURUSD

Run 47 log:
  Entry limit placed. ticket=100 symbol=EURUSD price=1.17932
  order triggered → filled at 1.17932
  Freeze level skip — symbol=EURUSD distance=-2.17932
  PlaceNextEntryLimit skipped — freeze level. add_next=3.35863

EURUSD current market ~1.179. add_next=3.35 is impossible.

Trace the exact computation path through:
1. HandleEntryFill() after EURUSD BUY Layer 0 fill
2. ComputeNextLayerPrice() call
3. InvertSpreadToPrice() with -next_threshold as T
4. What is g_EU_mid_12bars_ago at EURUSD fill time?

Key question: when the EA is running on EURGBP M5 chart
and a EURUSD signal fires, what values do
g_EU_mid_12bars_ago and g_GB_mid_12bars_ago hold?
Are they EURUSD/GBPUSD anchors or EURGBP-derived values?

Hypothesis: g_EU_mid_12bars_ago holds the correct
EURUSD anchor (~1.179) since RunSignalOnBarClose()
reads EURUSD and GBPUSD closes directly. But something
in the call chain may be using wrong anchors.

Show the full numerical derivation for:
- deal_price = 1.17932
- strongest=2, weakest=0 (EURUSD BUY)
- next_layer_idx=1 (after Layer 0 appended)
- ComputeLayerThreshold(0) = 0.0004
- ComputeLayerThreshold(1) = 0.0006
- Negated: T = -0.0006 passed to InvertSpreadToPrice
- Patch 7 formula: r_EU_target = T = -0.0006
- Expected: add_next ≈ 1.179 × MathExp(-0.0006) ≈ 1.1783

If expected, why does add_next = 3.35863?

### 2. -$35.80 Single Catastrophic Loss

Run 47 has one loss of -$35.80. With BaseLotSize=0.01
on EURUSD, a $35.80 loss implies a ~305 pip adverse
move or multiple layers all losing simultaneously.

Identify which code path could produce a loss of this
magnitude on a 0.01 lot position. Candidates:
- CloseBy failure leaving opposing positions open
- Circuit breaker firing and closing at market
- Multiple layers all hitting stop simultaneously
- Pod teardown at adverse price

### 3. Why Symbols=1 Despite All Patches

The MT5 backtest reports Symbols=1 despite EURUSD and
GBPUSD limits triggering (confirmed in logs). Is this
a reporting artefact or a genuine trading restriction?

---

## TIER 2 — ADVERSARIAL MATHEMATICAL AUDIT

### 4. InvertSpreadToPrice() — Full Verification

For each of the 6 routing cases, derive from first
principles what the physical price should be and
verify the formula produces it:

**EURGBP SELL (strongest=0, weakest=1):**
  T = gbp - eur = r_GB - r_EU (negative? positive?)
  Formula: EG_target = (anchor_EU/anchor_GB) × MathExp(-T)
  Verify: does this give current EURGBP mid?

**EURGBP BUY (strongest=1, weakest=0):**
  T = eur - gbp = r_EU - r_GB
  Formula: EG_target = (anchor_EU/anchor_GB) × MathExp(-T)
  Verify: does this give current EURGBP mid?
  Note: same formula for both BUY and SELL — is this correct?

**EURUSD SELL (strongest=0, weakest=2) [Patch 7]:**
  T = usd - eur = -r_EU (positive, since EUR strong)
  Formula: r_EU_target = -T → price = anchor_EU × MathExp(-T)
  Verify: = anchor_EU × MathExp(r_EU) = current EURUSD ✓?

**EURUSD BUY (strongest=2, weakest=0) [Patch 7]:**
  T = eur - usd = r_EU (negative, since EUR weak)
  Formula: r_EU_target = T → price = anchor_EU × MathExp(T)
  Verify: = anchor_EU × MathExp(r_EU) = current EURUSD ✓?

**GBPUSD SELL (strongest=1, weakest=2) [Patch 7]:**
  T = usd - gbp = -r_GB (positive, since GBP strong)
  Formula: r_GB_target = -T → price = anchor_GB × MathExp(-T)
  Verify: = anchor_GB × MathExp(r_GB) = current GBPUSD ✓?

**GBPUSD BUY (strongest=2, weakest=1) [Patch 7]:**
  T = gbp - usd = r_GB (negative, since GBP weak)
  Formula: r_GB_target = T → price = anchor_GB × MathExp(T)
  Verify: = anchor_GB × MathExp(r_GB) = current GBPUSD ✓?

For each case: if the formula gives current market mid,
then after subtracting half-spread for BUY (or adding
for SELL), the limit should be passive. Verify.

### 5. Exit Price Computation

ComputeExitPrice() passes exit_spread_target as T with
is_exit=true. The exit flips direction. Verify that for
a EURUSD BUY layer:
- Entry: price ≈ current EURUSD mid (passive BUY below bid)
- Exit:  price ≈ anchor × MathExp(exit_spread_target)
         where exit_spread_target = entry_spread × (1-0.70)
         = entry_spread × 0.30 (smaller magnitude negative)
- Exit price should be HIGHER than entry price (mean
  reversion — price rises as spread reverts)
- Exit is a SELL limit — should be above ask

Verify the exit price formula produces a price above
entry for EURUSD BUY, and that IsPassive passes.

### 6. CarryEngine Sign Convention

After the carry fix (scores_fwd[weakest] - scores_fwd[strongest]),
verify the carry-adjusted exit target is correct for
each instrument. Does the carry adjustment move the
exit target in the right direction for multi-day holds?

### 7. Hysteresis State Override Safety (Patch 6)

When hysteresis rejects a rotation, Patch 6 overrides:
  g_strongest = pending_strongest;
  g_weakest   = pending_weakest;
  g_entry_spread = scores[pending_weakest] - scores[pending_strongest];
  g_signal_active = (MathAbs(g_entry_spread) > BaseThreshold);

Risks:
- Does overriding g_strongest/g_weakest corrupt CarryEngine?
  CarryEngine uses g_inventory[i].strongest_at_entry not globals.
  Should be safe — verify.
- Does the override persist across ticks or only for one bar?
  It's set in the new_bar block, but globals persist until
  next bar close. The nudge block runs every tick using
  these globals. Is the nudge computing the right price
  for the locked routing?
- Could two consecutive bar closes with different rejections
  create an inconsistent state?

### 8. HandleEntryFill Reverse Derivation

After Patch 7, the physical fill price on EURUSD is
approximately current market mid. The reverse derivation
in HandleEntryFill() maps (symbol, direction) → 
(strongest_at_entry, weakest_at_entry). Verify this
mapping is still correct and consistent with Patch 7.

### 9. Race Conditions in CloseBy Queue

ProcessCloseByQueue() checks both positions exist then
attempts CloseBy. Between the check and the send, a
position could close. What happens if ticket1 closes
between PositionSelectByTicket checks? Is the error
handled or does it halt the EA?

### 10. Radar Removal

GetBestRadarTarget() in MathEngine.mqh is preserved
but unused (per handoff). Confirm it is safe to remove
entirely. Check all call sites — confirm zero references
in FXMatrix.mq5. Generate the Cursor patch to remove it.

---

## TIER 3 — STRATEGIC

### 11. Multi-Pod Architecture

Is the current architecture extensible to multiple
independent 3-currency pods (e.g. EUR/JPY/USD,
GBP/JPY/USD)? What would need to change?

### 12. Risk Sizing

Given Run 39 baseline (+$122 over 3 months, EURGBP only,
BaseLotSize=0.01), what BaseLotSize targets $500 profit
while staying within FTMO limits:
- Max daily DD: 5% ($500)
- Max total DD: 10% ($1000)
- Profit target: $500

If 3 symbols trade, how does that change the sizing?

### 13. Batch ADR Generation

Generate ADRs for all major decisions made since the
last ADR batch. Key decisions to document:
- Physical ledger ground truth
- Highlander Rule
- CloseBy as approved exit mechanism
- Escalating threshold (linear, not exponential)
- Passivity sign convention (MathAbs → T directly)
- Value-based hysteresis
- Pending entry invalidation
- CancelAllPendingEntries symbol filter removal
- Carry spread sign (scores_fwd[weakest-strongest])
- MaxLayers=20
- No delays as canonical test mode

---

## CONSTRAINTS (NEVER VIOLATE)

- No scipy/QuantLib/ta-lib
- No startup DDL
- No git add -A
- PowerShell: use ; not && for chaining
- Cursor edits LOCAL files only
- Gemini rules architecture
- DeepSeek audits code math
- exit_symbol always from L.instrument
- Passivity guard must never be removed
- All exits route through CloseBy
- Physical ledger is ground truth
- EA_MAGIC on all OrderSend calls
- ExitFractionMin must be > 0.0
- ThresholdMultiplier must be > 1.0 (if used)
- No delays = canonical test mode