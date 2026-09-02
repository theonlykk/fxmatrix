# ADR-002: Matrix-Driven Exits — Spatial Price Inversion (v2)

**Date:** 2026-06-08
**Status:** Proposed — Pending Gemini Final Approval
**Repo:** theonlykk/fxmatrix
**Depends on:** ADR-001 (Pod Architecture)
**Blocks:** ADR-003 (Carry Adjustment), MQL5 EA Implementation
**Supersedes:** ADR-002 v1 (2026-06-07) — full rewrite following DeepSeek Round 3 audit

---

## Changelog from v1

| Finding | Change |
|---------|--------|
| F1 — Verification targets wrong side | All verification conditions rewritten: sell limits check > Ask, buy limits check < Bid |
| F2 — Half-spread sign error (Cases 3–6) | Sign inverted: sell limits add half-spread, buy limits subtract half-spread |
| F3 — Freeze level anchor ambiguous | current_market_price explicitly defined as Ask (sell) / Bid (buy) |
| F4 — Cancel/replace race condition | Replaced with OrderModify() throughout |
| F5 — No partial fill handling | remaining_volume added to Layer struct, per-tranche exit limits |
| F6 — No passivity buffer Cases 1–2 | Half-spread buffer added to EURGBP synthetic cases |
| F7 — Fixed-leg notation ambiguous | Explicit g_r_XX_signal notation throughout Cases 3–6 |
| F8 — Ticket fallback missing | Symbol/direction/volume fallback added to OnTradeTransaction |
| New — ATR-fixed exit replaced | Matrix-derived exit target via ExitFraction parameter |
| New — Layer struct extended | Dual spread tracking, remaining_volume, entry_time added |
| New — Partial fill trigger | First fill triggers next layer placement |

---

## Objective

Define the spatial (price-space) mechanism by which the EA computes
exact limit order prices for both entry and exit, given a target
spread value. Formalise the six routing cases for the EUR/GBP/USD
pod. Incorporate all resolutions from DeepSeek Round 3 audit and
three additional architectural rulings from Gemini.

---

## What This ADR Does

- Derives closed-form price inversions for all six instrument/direction
  combinations in the EUR/GBP/USD pod
- Specifies the exact bid/ask convention for each USD leg input in
  every inversion case, with correct passivity verification
- Defines matrix-derived exit targets via ExitFraction parameter,
  replacing ATR-fixed exits entirely
- Formalises the Layer struct with dual spread tracking and
  partial fill bookkeeping
- Specifies ticket-based LIFO array management with partial fill
  handling and ticket fallback
- Specifies the freeze level guardrail with correct market side anchor
- Specifies intra-bar limit price nudging via OrderModify()

## What This ADR Does NOT Do

- Carry adjustment (temporal drift on multi-day positions) — ADR-003
- Volatility-scaled entry threshold — V2
- 4+ currency pod extension — V2
- MQL5 implementation code — blocked until this ADR is Gemini-approved
- Cross-pod correlation management — V2
- ATR-based layer spacing for exits — replaced by matrix-derived exits
- Full mean reversion exits (T_exit = 0) — ExitFraction ensures
  partial reversion only

---

## Governing Rulings

| Decision | Ruling | Source |
|----------|--------|--------|
| Basis risk | Zero, analytically proven. S = −r_EG | Gemini |
| Entry threshold | Fixed, 0.0008, V1 | Gemini |
| ADR-002 scope | Spatial only. Carry drift is ADR-003 | Gemini |
| Inversion coverage | Option A — all six cases explicit, closed-form | Gemini |
| Bid/ask convention | Option 1 — mid for signal, correct side for execution | Gemini |
| FTMO account type | Hedging by default. Multi-ticket LIFO valid | Gemini |
| Out-of-order fills | Pop by deal_ticket match, not stack position | Gemini/DeepSeek |
| Freeze level | Query SYMBOL_FREEZE_LEVEL, skip if too close | Gemini/DeepSeek |
| Intra-bar staleness | Signal on M5 close, OrderModify on tick | Gemini/DeepSeek |
| Partial fill trigger | First fill triggers next layer placement | Gemini |
| Exit target | Matrix-derived at T_exit = entry_spread_adjusted × (1 − ExitFraction) | Gemini |
| ExitFraction | Default 0.70, tunable parameter | Gemini |
| Layer struct | Dual spread tracking, remaining_volume, immutable entry_spread_raw | Gemini |
| Cases 3–6 fixed leg | Acceptable for V1. Anchor to g_r_XX_signal from M5 close | Gemini |
| NudgeThreshold | 0.5 pips confirmed | Gemini |
| Cancel/replace | Replaced by OrderModify() — atomic, no gap, no race | Gemini/DeepSeek |

---

## Section 1 — Signal Layer (Mid-Price Convention)

The signal layer uses mid-price throughout. Mid = (Bid + Ask) / 2.

Currency strength scores are relative rankings. A uniform mid-price
convention ensures the matrix decomposition is symmetric and free
of bid/ask bounce noise.

### 1.1 — Log return computation (on each new M5 bar)

```
r_EU = log(EURUSD_mid_now / EURUSD_mid_12bars_ago)
r_GB = log(GBPUSD_mid_now / GBPUSD_mid_12bars_ago)
```

Window: 12 M5 bars = 1 hour. StrengthWindow = 12 (input parameter).

Stored as global signal state on each M5 bar close:
```
g_r_EU_signal  // fixed until next M5 bar
g_r_GB_signal  // fixed until next M5 bar
```

### 1.2 — Matrix solution

```
USD = -(g_r_EU_signal + g_r_GB_signal) / 3
EUR =  g_r_EU_signal + USD
GBP =  g_r_GB_signal + USD
```

### 1.3 — Spread and entry condition

```
Rank currencies: S = strongest, W = weakest
Spread = score_W - score_S    // always negative by construction

if abs(Spread) > EntryThreshold (0.0008):
    g_signal_active = true
    g_entry_spread  = Spread  // stored for exit target computation
```

---

## Section 2 — Layer Struct

The Layer struct is the canonical unit of inventory. Every fill,
partial fill, exit, and carry adjustment operates on this struct.

```mql5
struct Layer {
    // --- Entry state (set on first partial fill, immutable thereafter) ---
    double   entry_price;           // actual fill price (first partial)
    double   entry_spread_raw;      // matrix spread at fill time — IMMUTABLE
    datetime entry_time;            // UTC fill timestamp (carry period anchor)

    // --- Carry-adjusted state (updated daily by ADR-003) ---
    double   entry_spread_adjusted; // carry-adjusted spread (starts = entry_spread_raw)
    double   entry_price_forward;   // forward-adjusted entry price (ADR-003)

    // --- Exit targets (spatial; exit_target updated by ADR-003 via OrderModify) ---
    double   exit_spread_target;    // T_exit = entry_spread_adjusted × (1 - ExitFraction)
    double   exit_target;           // instrument price corresponding to exit_spread_target

    // --- Layer mechanics ---
    double   add_next;              // instrument price for next layer entry limit
    double   lot_size;              // BaseLotSize for this layer
    double   remaining_volume;      // decrements on each partial fill; layer removed at 0

    // --- Order tracking ---
    ulong    entry_ticket;          // ticket of the filled entry order
    ulong    exit_ticket;           // ticket of the active exit limit order
};

Layer inventory[];   // dynamic array; logical LIFO stack
```

### Immutability rules

- `entry_spread_raw` — set once at first fill, never modified
- `entry_price` — set once at first fill, never modified
- `entry_time` — set once at first fill, never modified
- `entry_spread_adjusted` — set initially to entry_spread_raw;
   updated daily by ADR-003 carry recalculation only
- `exit_target` — set at entry; updated by ADR-003 via OrderModify only
- All other fields — managed by execution logic as defined below

### Audit value of entry_spread_raw

entry_spread_raw is retained for internal audit, backtest
reconciliation, and P&L attribution. If a position bleeds, the raw
historical signal value allows diagnosis of whether the matrix was
wrong at entry or whether carry drift (ADR-003) distorted the exit.
It is not modified under any circumstances after the initial fill.

---

## Section 3 — Exit Target Computation

### 3.1 — Matrix-derived exit (replaces ATR-fixed exit)

Exit targets are no longer defined as a fixed ATR multiple. They are
defined as the instrument price at which the matrix spread has
partially reverted to T_exit:

```
T_exit = entry_spread_adjusted × (1 - ExitFraction)
```

Where ExitFraction is a tunable input parameter:

```mql5
input double ExitFraction = 0.70;  // capture 70% of spread reversion
                                    // leave 30% for counterparty incentive
```

ExitFraction = 0.70 means: exit when 70% of the spread dislocation
has resolved. The remaining 30% is deliberately left on the table.
This increases exit fill probability and avoids competing at the
asymptote of full mean reversion.

### 3.2 — Exit price inversion

The exit price is computed by applying the same inversion formulas
in Section 5 (the six routing cases) at T = T_exit. This preserves
the mathematical link between signal and P&L: spread resolution
maps 1:1 to realised profit (S = −r_EG, proven analytically).

### 3.3 — Exit target per partial fill tranche

Each partial fill on a layer generates its own exit limit order for
the filled volume at the same exit_target price. Multiple exit limit
orders can be outstanding against a single layer simultaneously.
All partial exit limits share the same exit_target price — they
differ only in volume.

### 3.4 — Layer removal

A layer is removed from inventory[] only when remaining_volume
reaches zero (all partial fills have exited). Until then, the layer
remains active with its exit_ticket tracking the most recently
placed exit limit.

---

## Section 4 — Partial Fill and Next Layer Trigger

### 4.1 — First fill triggers next layer

The entry limit for Layer N+1 is placed at add_next immediately
upon the first partial fill of Layer N, regardless of whether Layer
N's remaining_volume has reached zero.

Rationale: in a fast adverse market, waiting for full fill before
placing the next rung of the ladder risks missing the add_next level
entirely as price continues moving. The ladder must be established
where it needs to be, not after the fill completes.

### 4.2 — add_next computation

add_next is computed at the moment of first fill on Layer N:

```
// For a sell position (price moving up adversely):
add_next = entry_price + AddRatio × H4_ATR_pips

// For a buy position (price moving down adversely):
add_next = entry_price - AddRatio × H4_ATR_pips
```

Note: add_next remains in price space (H4 ATR in pips) per the
ADR-001 ruling (DeepSeek Round 1 Q6/Q8). ATR is used only for
layer spacing. Exit targets are matrix-derived (Section 3).

### 4.3 — Partial fill sequence example

Layer 1 entry limit at 1.2800 for 0.01 lots (buy EURGBP):

```
Partial fill 1: 0.004 lots at 1.2800
  → place exit limit: 0.004 lots at exit_target
  → place Layer 2 entry limit at add_next (1.2785)
  → Layer 1: remaining_volume = 0.006

Partial fill 2: 0.006 lots at 1.2800
  → place exit limit: 0.006 lots at exit_target
  → Layer 2 entry limit already resting at 1.2785
  → Layer 1: remaining_volume = 0.000 → layer complete
```

---

## Section 5 — The Six Inversion Cases

### Notation

```
EU_bid  = EURUSD Bid (live, current tick)
EU_ask  = EURUSD Ask (live, current tick)
EU_mid  = (EU_bid + EU_ask) / 2

GB_bid  = GBPUSD Bid (live, current tick)
GB_ask  = GBPUSD Ask (live, current tick)
GB_mid  = (GB_bid + GB_ask) / 2

EG_bid  = EURGBP Bid (live, current tick)
EG_ask  = EURGBP Ask (live, current tick)

g_r_EU_signal = log return of EURUSD fixed at last M5 bar close
g_r_GB_signal = log return of GBPUSD fixed at last M5 bar close

T       = target spread value (signed, dimensionless log-return units)
          For entry: T = g_entry_spread (negative, signal side)
          For exit:  T = T_exit = entry_spread_adjusted × (1 - ExitFraction)
```

### Master inversion formula

From the analytical proof (Gemini, 2026-06-07):

```
Spread = r_GB - r_EU = -r_EG
Therefore: Spread = T implies r_EG = -T
log(EG_t / EG_0) = -T
EG_t = EG_0 × exp(-T)
```

Where EG_0 is the current synthetic EURGBP mid = EU_mid / GB_mid.

### 5.1 — Case 1: S=EUR, W=GBP → Sell EURGBP

**Signal:** EUR strongest, GBP weakest. EURGBP overpriced.
**Action:** Passive sell limit — rests above current Ask.

```
EG_synthetic = EU_bid / GB_ask      // conservative: weakens synthetic
P_sell_limit = EG_synthetic × exp(-T) + (EG_ask - EG_bid) / 2

// Passivity verification (must pass before OrderSend):
assert P_sell_limit > EG_ask
```

### 5.2 — Case 2: S=GBP, W=EUR → Buy EURGBP

**Signal:** GBP strongest, EUR weakest. EURGBP underpriced.
**Action:** Passive buy limit — rests below current Bid.

```
EG_synthetic = EU_ask / GB_bid      // conservative: strengthens synthetic
P_buy_limit  = EG_synthetic × exp(-T) - (EG_ask - EG_bid) / 2

// Passivity verification:
assert P_buy_limit < EG_bid
```

### 5.3 — Case 3: S=EUR, W=USD → Sell EURUSD

**Signal:** EUR strongest, USD weakest. EURUSD overpriced.
**Action:** Passive sell limit — rests above current Ask.

Fixed leg: g_r_GB_signal (GBPUSD log return from last M5 close —
NOT recomputed from live tick prices).

```
r_EU_target   = g_r_GB_signal - T
EU_target_mid = EU_mid_12bars_ago × exp(r_EU_target)
P_sell_limit  = EU_target_mid + (EU_ask - EU_bid) / 2

// Passivity verification:
assert P_sell_limit > EU_ask
```

### 5.4 — Case 4: S=USD, W=EUR → Buy EURUSD

**Signal:** USD strongest, EUR weakest. EURUSD underpriced.
**Action:** Passive buy limit — rests below current Bid.

Fixed leg: g_r_GB_signal.

```
r_EU_target   = g_r_GB_signal - T
EU_target_mid = EU_mid_12bars_ago × exp(r_EU_target)
P_buy_limit   = EU_target_mid - (EU_ask - EU_bid) / 2

// Passivity verification:
assert P_buy_limit < EU_bid
```

### 5.5 — Case 5: S=GBP, W=USD → Sell GBPUSD

**Signal:** GBP strongest, USD weakest. GBPUSD overpriced.
**Action:** Passive sell limit — rests above current Ask.

Fixed leg: g_r_EU_signal.

```
r_GB_target   = g_r_EU_signal + T
GB_target_mid = GB_mid_12bars_ago × exp(r_GB_target)
P_sell_limit  = GB_target_mid + (GB_ask - GB_bid) / 2

// Passivity verification:
assert P_sell_limit > GB_ask
```

### 5.6 — Case 6: S=USD, W=GBP → Buy GBPUSD

**Signal:** USD strongest, GBP weakest. GBPUSD underpriced.
**Action:** Passive buy limit — rests below current Bid.

Fixed leg: g_r_EU_signal.

```
r_GB_target   = g_r_EU_signal + T
GB_target_mid = GB_mid_12bars_ago × exp(r_GB_target)
P_buy_limit   = GB_target_mid - (GB_ask - GB_bid) / 2

// Passivity verification:
assert P_buy_limit < GB_bid
```

---

## Section 6 — Ticket-Based LIFO Array Management

### 6.1 — Ruling

Pop by deal_ticket match, not stack position. Out-of-order fills
(e.g. gap through multiple exit levels) must not corrupt inventory.

### 6.2 — Layer struct fields used

```
entry_ticket  // matched on DEAL_ENTRY_IN fills
exit_ticket   // matched on DEAL_ENTRY_OUT fills
```

### 6.3 — OnTradeTransaction handler

```
OnTradeTransaction(trans, request, result):

  if trans.type != TRADE_TRANSACTION_DEAL_ADD: return

  deal = HistoryDealGet(trans.deal)

  if deal.entry == DEAL_ENTRY_IN:
    // Entry fill (partial or full)
    find layer where layer.entry_ticket == deal.order
    if not found: goto fallback (Section 6.5)

    layer.remaining_volume -= deal.volume
    place exit limit for deal.volume lots at layer.exit_target
    store new exit_ticket in layer (most recent exit limit)

    if this is the FIRST fill on this layer (was remaining_volume == lot_size):
      place next entry limit at layer.add_next
        (if inventory size < MaxLayers)

  if deal.entry == DEAL_ENTRY_OUT:
    // Exit fill (partial or full)
    find layer where layer.exit_ticket == deal.order
    if not found: goto fallback (Section 6.5)

    layer.remaining_volume -= deal.volume
    if layer.remaining_volume == 0:
      remove layer from inventory[] by index
      shift remaining elements to fill gap
      log layer exit (spread_raw, spread_adjusted, exit_spread_target,
                      entry_time, exit_time, realised_pnl)
```

### 6.4 — Floating point equality for remaining_volume

Do not compare remaining_volume == 0 with exact float equality.
Use: remaining_volume < VOLUME_EPSILON (e.g. 0.0001 lots).

### 6.5 — Ticket fallback

If deal_ticket is not found in any layer's entry_ticket or
exit_ticket:

```
1. Attempt match by: symbol == deal.symbol
                  && direction consistent with deal.type
                  && abs(deal.volume - layer.lot_size) < VOLUME_EPSILON
                  && abs(deal.time - layer.entry_time) < FALLBACK_TIME_WINDOW
2. If matched: process as normal, log warning
3. If not matched: log error, halt pod, raise alarm
   Do not attempt to guess. State corruption is worse than a halted pod.
```

---

## Section 7 — Freeze Level Guardrail

### 7.1 — Ruling

Query SYMBOL_FREEZE_LEVEL before every order placement. Skip if
computed limit price is too close to market.

### 7.2 — Correct market side anchor

```
freeze_level_points = SymbolInfoInteger(_Symbol, SYMBOL_FREEZE_LEVEL)
freeze_price        = freeze_level_points × SymbolInfoDouble(_Symbol, SYMBOL_POINT)

// For sell limits: measure distance from Ask
// For buy limits:  measure distance from Bid
if order_direction == SELL:
    distance = P_sell_limit - current_Ask
else:
    distance = current_Bid - P_buy_limit

if distance <= freeze_price:
    log "order skipped — within freeze level"
    return  // re-evaluate on next tick or M5 bar
```

### 7.3 — Error taxonomy (Gemini clarification)

A limit order price violation returns TRADE_RETCODE_INVALID_PRICE
(10015), not TRADE_RETCODE_INVALID_STOPS (10016).

INVALID_STOPS (10016) is for SL/TP violations only. This EA uses
independent limit orders for exits — no native SL/TP attached to
entry orders. INVALID_STOPS is not relevant to this design.

Cursor must handle TRADE_RETCODE_INVALID_PRICE (10015) in the order
placement error handler.

---

## Section 8 — Intra-Bar Limit Price Nudging

### 8.1 — Ruling

Signal computation: M5 bar close only (g_r_EU_signal, g_r_GB_signal).
Limit price update: OrderModify() on every tick when delta > NudgeThreshold.

OrderModify() is atomic. It does not cancel the order, does not
create a gap window, and does not introduce a race condition between
cancel and fill. Cancel-and-replace is explicitly abandoned.

### 8.2 — Global signal state (set on each M5 bar close)

```mql5
double   g_r_EU_signal;       // fixed log return, EURUSD
double   g_r_GB_signal;       // fixed log return, GBPUSD
int      g_strongest;         // EUR=0, GBP=1, USD=2
int      g_weakest;           // EUR=0, GBP=1, USD=2
bool     g_signal_active;     // true if abs(spread) > EntryThreshold
double   g_entry_spread;      // spread value at signal trigger
```

### 8.3 — OnTick logic

```
OnTick():

  // Step 1: Check for new M5 bar
  if new M5 bar detected:
    run full signal computation (Section 1)
    update all g_XX_signal globals
    if g_signal_active and inventory empty:
      compute first entry limit price via Section 5
      place entry limit order (after freeze level check)

  // Step 2: Nudge existing pending entry limit (if no inventory yet)
  if g_signal_active and inventory empty and pending_entry_order exists:
    recompute limit price using live bid/ask + fixed g_r_XX_signal
    delta = abs(recomputed_price - current_pending_price)
    if delta > NudgeThreshold (0.5 pips in points):
      OrderModify(pending_order_ticket, recomputed_price)
      // ticket unchanged after modify — no struct update needed

  // Step 3: Circuit breakers
  check per-pod drawdown
  check global equity drawdown
```

### 8.4 — Design note: subsequent layer entry limits are not nudged

Entry limits for Layer 2, 3... are placed at fixed add_next prices
derived from the prior layer's fill price plus ATR offset. These
are price-space targets, not matrix-recalculated. They are not
nudged between M5 bars. Only the first entry limit (pre-inventory)
is nudged via the matrix inversion.

---

## Section 9 — Negative Space (Explicit Exclusions)

| Exclusion | Rationale |
|-----------|-----------|
| Forward price adjustment for carry | ADR-003 |
| Volatility-scaled entry threshold | V2 |
| Dynamic ATR blending across timeframes | V2 |
| 4+ currency pod extension | V2 |
| Cross-pod correlation management | V2 |
| Market orders for entry or exit | Design constraint: passive only |
| OnTick signal recomputation | Signal is M5-bar only |
| ATR-fixed exit targets | Replaced by matrix-derived ExitFraction |
| Full mean reversion exits (T_exit = 0) | Partial reversion only |
| Stack-position-based inventory pop | Replaced by ticket-based removal |
| Cancel-and-replace for nudging | Replaced by OrderModify() |
| Native SL/TP on entry orders | Independent exit limit orders only |
| Modifying entry_spread_raw after fill | Immutable by ruling |

---

## Section 10 — Sequencing

1. ADR-001 — Accepted ✅
2. DeepSeek audit Round 1 (MQL5 architecture) — Complete ✅
3. DeepSeek audit Round 2 (execution layer) — Complete ✅
4. DeepSeek audit Round 3 (ADR-002 v1) — Complete ✅
5. **ADR-002 v2 (this document)** — Pending Gemini final approval
6. ADR-003 — Carry adjustment — Blocked until ADR-002 approved
7. MQL5 EA implementation (Cursor) — Blocked until ADR-003 approved
8. MT5 strategy tester validation on historical tick data
9. Practice account deployment (minimum lot size)
10. 4-week observation before any parameter changes
11. Live account deployment after practice validation
