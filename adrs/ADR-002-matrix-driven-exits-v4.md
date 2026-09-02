# ADR-002: Matrix-Driven Exits — Spatial Price Inversion (v4)

**Date:** 2026-06-08
**Status:** Accepted — Gemini Approved 2026-06-08
**Repo:** theonlykk/fxmatrix
**Depends on:** ADR-001 (Pod Architecture)
**Blocks:** MQL5 EA Implementation
**Supersedes:** ADR-002 v3 (2026-06-08)

---

## Changelog from v3

| Finding | Change |
|---------|--------|
| F1 — Exit anchor drift | Added `EU_mid_12bars_ago_at_entry` and `GB_mid_12bars_ago_at_entry` as immutable Layer struct fields. All exit inversions use entry-time anchor, not live 12-bar-ago prices. All six inversion cases parameterised with explicit anchor input. |
| F2 — Multiple exit tickets | Replaced single `exit_ticket` with `exit_tickets[]` dynamic array. All exit fill matching, carry recalculation, and freeze level checks iterate the full array. |
| F3 — Passivity check fallback | Replaced all passivity assertions with `IsPassive()` conditional checks. Skip-and-log on failure. No price override. |
| F6 — Exit limit nudging | Explicitly added to negative space: exit limits are NOT nudged intra-bar. |
| F7 — Freeze level on exits | Freeze level guardrail applied to exit `OrderModify()` calls with skip-and-retain behaviour. |
| F8 — MinFillThreshold | Next layer triggered only when filled_volume >= MinFillThreshold × lot_size (default 0.50). |
| F10 — Struct fragmentation | Canonical Layer struct consolidated. References LayerStruct.mqh. |
| M1 — NudgeThreshold | Computed per symbol as NudgePips × SYMBOL_POINT × 10. |
| M2 — FALLBACK_TIME_WINDOW | Set to 30 seconds. Moot once F2 fix eliminates most fallback cases. |
| M6 — EURGBP liquidity guard | Added Bid != 0 && Ask != 0 check before synthetic computation. |
| M7 — Exit log | OnTradeTransaction exit handler logs raw spread, adjusted spread, holding period, carry delta, gross P&L. |

---

## Objective

Define the spatial (price-space) mechanism by which the EA computes
exact limit order prices for both entry and exit, given a target
spread value. Formalise the six routing cases for the EUR/GBP/USD
pod. Incorporate all rulings through Round 4 DeepSeek audit.

---

## What This ADR Does

- Derives closed-form price inversions for all six instrument/direction
  combinations, parameterised with explicit historical anchor input
- Specifies immutable entry-time anchor fields in the Layer struct
- Defines matrix-derived exit targets via ExitFraction parameter
- Formalises the canonical Layer struct (see LayerStruct.mqh)
- Specifies ticket-based LIFO array management with exit_tickets[]
- Specifies IsPassive() conditional checks replacing all assertions
- Specifies freeze level guardrail for both entry and exit orders
- Specifies intra-bar limit price nudging for first entry only

## What This ADR Does NOT Do

- Carry adjustment (temporal drift) — ADR-003
- Volatility-scaled entry threshold — V2
- Multi-timeframe confluence — V2
- 4+ currency pod extension — V2
- MQL5 implementation code — Cursor prompts
- Cross-pod correlation management — V2
- ATR-based exit targets — replaced by matrix-derived exits
- Full mean reversion exits (T_exit = 0) — ExitFraction only
- Stack-position inventory pop — replaced by ticket-based removal
- Cancel-and-replace for nudging — replaced by OrderModify()
- Native SL/TP on entry orders — independent exit limits only
- Intra-bar nudging of exit limits — exit limits updated by ADR-003 only
- Price override when passivity check fails — skip-and-log only

---

## Governing Rulings (complete)

| Decision | Ruling | Source |
|----------|--------|--------|
| Basis risk | Zero, analytically proven. S = −r_EG | Gemini |
| Entry threshold | Fixed 0.0008, V1 | Gemini |
| ADR-002 scope | Spatial only. Carry is ADR-003 | Gemini |
| Inversion coverage | Option A — all six cases, closed-form | Gemini |
| Bid/ask convention | Mid for signal, correct side for execution | Gemini |
| Historical anchor | EU_mid_12bars_ago_at_entry / GB_mid_12bars_ago_at_entry for exits | Gemini (R4) |
| FTMO account type | Hedging by default. Multi-ticket LIFO valid | Gemini |
| Exit tickets | exit_tickets[] dynamic array | Gemini (R4) |
| Passivity fallback | Option B — IsPassive() skip-and-log, no price override | Gemini (R4) |
| Exit limit nudging | NOT nudged intra-bar. ADR-003 carry recalc only | Gemini (R4) |
| Freeze level exits | Skip-and-retain on OrderModify() violation | Gemini (R4) |
| MinFillThreshold | 0.50 — 50% of lot_size before next layer triggered | Gemini (R4) |
| Exit target | Matrix-derived: T_exit = entry_spread_adjusted × (1 - ExitFraction) | Gemini |
| ExitFraction | Default 0.70 | Gemini |
| Cases 3–6 fixed leg | g_r_XX_signal from M5 close | Gemini |
| NudgeThreshold | 0.5 pips (NudgePips × SYMBOL_POINT × 10 per symbol) | Gemini |
| OrderModify() | Replaces cancel-and-replace throughout | Gemini |
| Partial fill trigger | First fill >= MinFillThreshold triggers next layer | Gemini (R4) |
| Struct canonical | LayerStruct.mqh — single source of truth | Gemini (R4) |
| Weekend gap | V2 deferral. Documented in negative space | Gemini (R4) |
| MTF confluence | V2 deferral | Gemini |

---

## Section 1 — Signal Layer (Mid-Price Convention)

Uses mid-price convention throughout. For historical bar data fetched via CopyClose(), the bar close price is used as a mid-price approximation. The error introduced is sub-pip and symmetric across both legs, cancelling in the log return difference S = r_GB - r_EU. On EURUSD/GBPUSD with typical spreads of 0.5-1 pip this is negligible relative to the 8-pip entry threshold. Formally approved by Gemini for V1. True mid via CopyBid/CopyAsk deferred to V2.

### 1.1 — Log return computation (on each new M5 bar)

```
r_EU = log(EURUSD_mid_now / EURUSD_mid_12bars_ago)
r_GB = log(GBPUSD_mid_now / GBPUSD_mid_12bars_ago)
```

Window: 12 M5 bars = 1 hour. StrengthWindow = 12.

Stored as global signal state on M5 bar close:
```
g_r_EU_signal            // fixed until next M5 bar
g_r_GB_signal            // fixed until next M5 bar
g_EU_mid_12bars_ago      // stored for entry inversion anchor
g_GB_mid_12bars_ago      // stored for entry inversion anchor
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
    g_entry_spread  = Spread
```

---

## Section 2 — Canonical Layer Struct

The canonical Layer struct is defined in LayerStruct.mqh.
ADR-002 and ADR-003 both reference it. It is the single source
of truth. Do not redefine it elsewhere.

```mql5
// LayerStruct.mqh — canonical definition
struct Layer {
    // --- Entry state (immutable after first fill) ---
    double   entry_price;                  // fill price (first partial)
    double   entry_spread_raw;             // matrix spread at fill — IMMUTABLE
    datetime entry_time;                   // UTC fill timestamp
    double   EU_mid_12bars_ago_at_entry;   // exit inversion anchor — IMMUTABLE
    double   GB_mid_12bars_ago_at_entry;   // exit inversion anchor — IMMUTABLE
    double   r_EU_at_entry;                // fixed leg log return at entry — IMMUTABLE
    double   r_GB_at_entry;                // fixed leg log return at entry — IMMUTABLE
    int      strongest_at_entry;           // routing anchor — IMMUTABLE
    int      weakest_at_entry;             // routing anchor — IMMUTABLE

    // --- Carry recalculation inputs (immutable) ---
    double   entry_price_eurusd;           // EURUSD spot at fill
    double   entry_price_gbpusd;           // GBPUSD spot at fill
    double   entry_price_eurusd_1h;        // EURUSD 1h-prior at fill
    double   entry_price_gbpusd_1h;        // GBPUSD 1h-prior at fill
    int      instrument;                   // EURUSD=0, GBPUSD=1, EURGBP=2
    int      direction;                    // BUY=1, SELL=-1

    // --- Carry-adjusted state (updated daily by ADR-003) ---
    double   entry_spread_adjusted;        // starts = entry_spread_raw
    double   entry_price_forward;          // forward-adjusted entry price

    // --- Exit targets (updated by ADR-003 via OrderModify only) ---
    double   exit_spread_target;           // T_exit = entry_spread_adjusted × (1 - ExitFraction)
    double   exit_target;                  // instrument price at exit_spread_target

    // --- Layer mechanics ---
    double   add_next;                     // next entry limit price
    double   lot_size;                     // BaseLotSize
    double   remaining_volume;             // decrements on each partial fill

    // --- Order tracking ---
    ulong    entry_ticket;                 // filled entry order ticket
    ulong    exit_tickets[];              // dynamic array — one per partial fill tranche
};
```

### Immutability rules

- `entry_spread_raw` — set once at first fill, never modified
- `entry_price` — set once at first fill, never modified
- `entry_time` — set once at first fill, never modified
- `EU_mid_12bars_ago_at_entry` — set once at first fill, never modified
- `GB_mid_12bars_ago_at_entry` — set once at first fill, never modified
- `r_EU_at_entry` — set once at first fill, never modified
- `r_GB_at_entry` — set once at first fill, never modified
- `strongest_at_entry` — set once at first fill, never modified
- `weakest_at_entry` — set once at first fill, never modified
- `entry_price_eurusd`, `entry_price_gbpusd` — set once at first fill
- `entry_price_eurusd_1h`, `entry_price_gbpusd_1h` — set once at first fill
- `entry_spread_adjusted` — updated daily by ADR-003 only
- `exit_target` — updated by ADR-003 via OrderModify() only

---

## Section 3 — Exit Target Computation

### 3.1 — Matrix-derived exit

```
T_exit = entry_spread_adjusted × (1 - ExitFraction)
```

ExitFraction default: 0.70. Captures 70% of spread reversion,
leaves 30% for counterparty incentive and fill probability.

### 3.2 — Exit price inversion

Exit price computed by applying Section 5 inversion at T = T_exit,
using the entry-time historical anchor (Section 5 notation below).

### 3.3 — Per-tranche exit limits

Each partial fill generates its own exit limit for that volume
at the same exit_target price. Ticket appended to exit_tickets[].
All tranches share the same exit_target, differing only in volume.

### 3.4 — Layer removal

Layer removed from inventory[] only when remaining_volume
<= VOLUME_EPSILON (0.0001 lots). Until then, layer remains active.

---

## Section 4 — Partial Fill and Next Layer Trigger

### 4.1 — MinFillThreshold

Next layer entry limit is placed only when:
```
cumulative_filled_volume >= MinFillThreshold × layer.lot_size
```

```mql5
input double MinFillThreshold = 0.50;  // 50% of lot_size
```

Prevents ladder stacking on microscopic noise fills from
aggregated liquidity feeds.

### 4.2 — add_next computation (at first qualifying fill)

```
// Buy position (adverse = price falling):
add_next = entry_price - AddRatio × H4_ATR_pips

// Sell position (adverse = price rising):
add_next = entry_price + AddRatio × H4_ATR_pips
```

Price space only. H4 ATR in pips. Not matrix-derived.

### 4.3 — Partial fill sequence example

Layer 1 entry limit: 0.01 lots, buy EURGBP at 1.2800.
MinFillThreshold = 0.50 → trigger threshold = 0.005 lots.

```
Partial fill 1: 0.003 lots at 1.2800
  → cumulative = 0.003 < 0.005 threshold
  → place exit limit: 0.003 lots at exit_target
  → append ticket to exit_tickets[]
  → do NOT place Layer 2 yet
  → remaining_volume = 0.007

Partial fill 2: 0.003 lots at 1.2800
  → cumulative = 0.006 >= 0.005 threshold
  → place exit limit: 0.003 lots at exit_target
  → append ticket to exit_tickets[]
  → place Layer 2 entry limit at add_next
  → remaining_volume = 0.004

Partial fill 3: 0.004 lots at 1.2800
  → place exit limit: 0.004 lots at exit_target
  → append ticket to exit_tickets[]
  → Layer 2 already placed, no action
  → remaining_volume = 0.000 → layer complete
```

---

## Section 5 — The Six Inversion Cases

### Notation

```
// Signal layer (mid, fixed at M5 bar close):
g_r_EU_signal            // EURUSD log return
g_r_GB_signal            // GBPUSD log return
g_EU_mid_12bars_ago      // for entry inversion anchor
g_GB_mid_12bars_ago      // for entry inversion anchor

// Execution layer (live bid/ask, current tick):
EU_bid, EU_ask, EU_mid
GB_bid, GB_ask, GB_mid
EG_bid, EG_ask

// Anchor parameter — CRITICAL DISTINCTION:
// For ENTRY computations: anchor_EU = g_EU_mid_12bars_ago
//                         anchor_GB = g_GB_mid_12bars_ago
// For EXIT computations:  anchor_EU = layer.EU_mid_12bars_ago_at_entry
//                         anchor_GB = layer.GB_mid_12bars_ago_at_entry

T    // target spread value (signed, log-return units)
     // Entry: T = g_entry_spread (negative for sell signals)
     // Exit:  T = layer.exit_spread_target
```

### IsPassive() function

```mql5
bool IsPassive(double price, int direction, string symbol) {
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    if (direction == SELL) return price > ask;
    if (direction == BUY)  return price < bid;
    return false;
}
```

If IsPassive() returns false: log failure, return without placing
order. Re-evaluate on next M5 bar or tick.

### Master inversion formula

```
Spread = -r_EG = -(log(EG_t / EG_0))
Therefore: Spread = T implies EG_t = EG_0 × exp(-T)
```

EG_0 = historical anchor (entry or exit, per above notation).

### 5.1 — Case 1: S=EUR, W=GBP → Sell EURGBP

```
EG_history   = anchor_EU / anchor_GB       // mid, per anchor parameter
EG_target    = EG_history × exp(-T)

// Passivity buffer — live bid/ask
if EG_bid == 0 || EG_ask == 0: skip (M6 liquidity guard)
P_sell_limit = EG_target + (EG_ask - EG_bid) / 2

if !IsPassive(P_sell_limit, SELL, "EURGBP"):
    LogSkip("Case 1 passivity failure", P_sell_limit, T)
    return
```

### 5.2 — Case 2: S=GBP, W=EUR → Buy EURGBP

```
EG_history  = anchor_EU / anchor_GB
EG_target   = EG_history × exp(-T)

if EG_bid == 0 || EG_ask == 0: skip
P_buy_limit = EG_target - (EG_ask - EG_bid) / 2

if !IsPassive(P_buy_limit, BUY, "EURGBP"):
    LogSkip("Case 2 passivity failure", P_buy_limit, T)
    return
```

### 5.3 — Case 3: S=EUR, W=USD → Sell EURUSD

```
// Fixed leg: g_r_GB_signal (M5 close, not live)
r_EU_target   = g_r_GB_signal - T
EU_target_mid = anchor_EU × exp(r_EU_target)
P_sell_limit  = EU_target_mid + (EU_ask - EU_bid) / 2

if !IsPassive(P_sell_limit, SELL, "EURUSD"):
    LogSkip("Case 3 passivity failure", P_sell_limit, T)
    return
```

### 5.4 — Case 4: S=USD, W=EUR → Buy EURUSD

```
r_EU_target  = g_r_GB_signal - T
EU_target_mid = anchor_EU × exp(r_EU_target)
P_buy_limit   = EU_target_mid - (EU_ask - EU_bid) / 2

if !IsPassive(P_buy_limit, BUY, "EURUSD"):
    LogSkip("Case 4 passivity failure", P_buy_limit, T)
    return
```

### 5.5 — Case 5: S=GBP, W=USD → Sell GBPUSD

```
r_GB_target   = g_r_EU_signal + T
GB_target_mid = anchor_GB × exp(r_GB_target)
P_sell_limit  = GB_target_mid + (GB_ask - GB_bid) / 2

if !IsPassive(P_sell_limit, SELL, "GBPUSD"):
    LogSkip("Case 5 passivity failure", P_sell_limit, T)
    return
```

### 5.6 — Case 6: S=USD, W=GBP → Buy GBPUSD

```
r_GB_target   = g_r_EU_signal + T
GB_target_mid = anchor_GB × exp(r_GB_target)
P_buy_limit   = GB_target_mid - (GB_ask - GB_bid) / 2

if !IsPassive(P_buy_limit, BUY, "GBPUSD"):
    LogSkip("Case 6 passivity failure", P_buy_limit, T)
    return
```

---

## Section 6 — Ticket-Based LIFO Array Management

### 6.1 — OnTradeTransaction handler

```
OnTradeTransaction(trans, request, result):

  if trans.type != TRADE_TRANSACTION_DEAL_ADD: return
  deal = HistoryDealGet(trans.deal)

  if deal.entry == DEAL_ENTRY_IN:
    // Entry fill
    find layer where layer.entry_ticket == deal.order
    if not found: goto fallback (Section 6.3)

    layer.remaining_volume -= deal.volume
    cumulative_filled = layer.lot_size - layer.remaining_volume

    // Place exit limit for this tranche
    place exit limit for deal.volume lots at layer.exit_target
    append new ticket to layer.exit_tickets[]

    // Trigger next layer if threshold met
    if cumulative_filled >= MinFillThreshold × layer.lot_size
       AND next layer not yet triggered
       AND ArraySize(inventory) < MaxLayers:
        place next entry limit at layer.add_next

  if deal.entry == DEAL_ENTRY_OUT:
    // Exit fill
    for each layer in inventory[]:
        for i = 0 to ArraySize(layer.exit_tickets)-1:
            if layer.exit_tickets[i] == deal.order:
                layer.remaining_volume -= deal.volume
                ArrayRemove(layer.exit_tickets, i, 1)
                if layer.remaining_volume <= VOLUME_EPSILON:
                    log exit (Section 6.2)
                    ArrayRemove(inventory, layer_index, 1)
                return
    // Not found in any layer — goto fallback
    goto fallback (Section 6.3)
```

### 6.2 — Exit log fields (M7)

On layer removal, log:
- entry_spread_raw
- entry_spread_adjusted
- exit_spread_target
- entry_time, exit_time
- holding_period_days
- carry_delta (entry_spread_raw - entry_spread_adjusted)
- gross_pnl (account currency)
- instrument, direction

### 6.3 — Ticket fallback

```
1. Match by: symbol == deal.symbol
          && direction consistent with deal.type
          && abs(deal.volume - layer.lot_size) < VOLUME_EPSILON
          && abs(deal.time - layer.entry_time) < 30 seconds
2. If matched: process normally, log WARNING
3. If not matched: log ERROR, halt pod, raise alarm
```

---

## Section 7 — Freeze Level Guardrail

Applies to BOTH entry OrderSend() and exit OrderModify() calls.

```
freeze_level_pts = SymbolInfoInteger(symbol, SYMBOL_FREEZE_LEVEL)
freeze_price     = freeze_level_pts × SymbolInfoDouble(symbol, SYMBOL_POINT)

// Direction-aware distance:
if direction == SELL: distance = computed_price - Ask
if direction == BUY:  distance = Bid - computed_price

if distance <= freeze_price:
    // Entry: skip placement, log, re-evaluate next bar/tick
    // Exit:  skip modification, RETAIN existing limit, log
    return
```

Error taxonomy: freeze level violations return
TRADE_RETCODE_INVALID_PRICE (10015), not INVALID_STOPS (10016).
INVALID_STOPS is for SL/TP violations only — not applicable here.

---

## Section 8 — Intra-Bar Limit Price Nudging (Entry Only)

### 8.1 — Scope

Nudging applies ONLY to the first entry limit (pre-inventory).
Exit limits and subsequent layer entry limits are NOT nudged.

Exit limits are fixed spatial targets anchored to entry-time
prices. Nudging them with live prices would reintroduce anchor
contamination (resolved by F1 fix). Exit limit updates are
exclusively via ADR-003 daily carry recalculation.

### 8.2 — Global signal state

```mql5
double   g_r_EU_signal;
double   g_r_GB_signal;
double   g_EU_mid_12bars_ago;
double   g_GB_mid_12bars_ago;
int      g_strongest;
int      g_weakest;
bool     g_signal_active;
double   g_entry_spread;
double   g_NudgeThreshold;   // NudgePips × SYMBOL_POINT × 10
```

### 8.3 — OnTick logic

```
OnTick():

  // Step 1: New M5 bar detection
  if new M5 bar:
    run full signal computation (Section 1)
    update all g_XX globals
    if g_signal_active and inventory empty:
      compute entry limit via Section 5 (entry anchor)
      apply freeze level check
      apply IsPassive() check
      place entry limit

  // Step 2: Nudge first entry limit (pre-inventory only)
  if g_signal_active and inventory empty and pending entry order:
    recompute limit price using live bid/ask + g_XX_signal (fixed)
    delta = abs(recomputed - current_pending_price)
    if delta > g_NudgeThreshold:
      apply freeze level check
      apply IsPassive() check
      OrderModify(pending_ticket, recomputed_price)

  // Step 3: Circuit breakers
  check per-pod drawdown (MAX_POD_DRAWDOWN)
  check global equity drawdown (5% from peak)
```

---

## Section 9 — Negative Space (Explicit Exclusions)

| Exclusion | Rationale |
|-----------|-----------|
| Carry adjustment | ADR-003 |
| Volatility-scaled threshold | V2 |
| Multi-timeframe confluence | V2 |
| 4+ currency pod | V2 |
| Cross-pod correlation | V2 |
| Market orders | Passive-only design |
| OnTick signal recomputation | M5-bar only |
| ATR-fixed exits | Replaced by ExitFraction |
| Full mean reversion exits | ExitFraction only |
| Stack-position inventory pop | Ticket-based removal |
| Cancel-and-replace | OrderModify() only |
| Native SL/TP on entries | Independent exit limits only |
| Intra-bar exit limit nudging | ADR-003 carry recalc only |
| Price override on passivity failure | Skip-and-log only |
| Weekend gap handling | V2 |
| Dynamic rate fetching | V2 |

---

## Section 10 — Sequencing

1. ADR-001 — Accepted ✅
2. DeepSeek audits R1–R4 — Complete ✅
3. ADR-002 v1–v3 — Superseded ✅
4. **ADR-002 v4 (this document)** — Accepted ✅ Gemini approved 2026-06-08
5. ADR-003 v2 — Pending Gemini approval (parallel)
6. Cursor Prompt 1: LayerStruct.mqh
7. Cursor Prompt 2: Signal + Inversion
8. Cursor Prompt 3: Execution Engine
9. Cursor Prompt 4: Carry + Orchestration
10. MT5 strategy tester validation
11. Practice account deployment
12. Live deployment
