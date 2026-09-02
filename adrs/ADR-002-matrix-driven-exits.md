# ADR-002: Matrix-Driven Exits — Spatial Price Inversion

**Date:** 2026-06-07
**Status:** Accepted — Gemini Approved 2026-06-07
**Repo:** theonlykk/fxmatrix
**Depends on:** ADR-001 (Pod Architecture)
**Blocks:** ADR-003 (Carry Adjustment), MQL5 EA Implementation

---

## Objective

Define the spatial (price-space) mechanism by which the EA computes
exact limit order prices for both entry and exit, given a target
spread value T. Formalise the six routing cases for the EUR/GBP/USD
pod. Incorporate execution-layer findings from the DeepSeek audit
(Round 2) as approved by Gemini.

---

## What This ADR Does

- Derives closed-form price inversions for all six instrument/direction
  combinations in the EUR/GBP/USD pod
- Specifies the exact bid/ask convention for each USD leg input in
  every inversion case
- Formalises ticket-based LIFO array management
- Specifies the freeze level guardrail
- Specifies intra-bar limit price nudging via OnTick

## What This ADR Does NOT Do

- Carry adjustment (temporal drift on multi-day positions) — deferred
  to ADR-003
- Volatility-scaled entry threshold — deferred to V2
- 4+ currency pod extension — deferred to V2
- MQL5 implementation code — blocked until this ADR is Gemini-approved
- Cross-pod correlation management — deferred to V2

---

## Governing Rulings

All rulings received prior to drafting this ADR:

| Decision | Ruling | Source |
|----------|--------|--------|
| Basis risk | Zero, analytically proven. S = −r_EG | Gemini |
| Entry threshold | Fixed, 0.0008, V1. Volatility-scaling deferred to V2 | Gemini |
| ADR-002 scope | Spatial only. Carry drift is ADR-003 | Gemini |
| Inversion coverage | Option A — all six cases explicit, closed-form | Gemini |
| Bid/ask convention | Option 1 — mid for signal, correct side for execution | Gemini |
| FTMO account type | Hedging by default. LIFO multi-ticket design is valid | Gemini |
| Out-of-order fills | Pop by deal_ticket match, not stack position | Gemini (via DeepSeek) |
| Freeze level | Query SYMBOL_FREEZE_LEVEL, skip if too close | Gemini (via DeepSeek) |
| Intra-bar staleness | Signal on M5 close, limit price nudge on OnTick | Gemini (via DeepSeek) |

---

## Section 1 — Signal Layer (Mid-Price Convention)

The signal layer uses mid-price throughout. Mid = (Bid + Ask) / 2.

This ensures the matrix decomposition is symmetric and free of
bid/ask bounce noise. Currency strength scores are relative rankings;
a uniform price convention produces identical rankings regardless of
which side is used.

### 1.1 — Log return computation (on each new M5 bar)

```
r_EU = log(EURUSD_mid_now / EURUSD_mid_12bars_ago)
r_GB = log(GBPUSD_mid_now / GBPUSD_mid_12bars_ago)
```

Window: 12 M5 bars = 1 hour. StrengthWindow = 12 (input parameter).

### 1.2 — Matrix solution

```
USD = -(r_EU + r_GB) / 3
EUR = r_EU + USD
GBP = r_GB + USD
```

### 1.3 — Spread and entry condition

```
Rank currencies: S = strongest, W = weakest
Spread = score_W - score_S    // always negative by construction

if abs(Spread) > EntryThreshold (0.0008):
    signal = True
    direction: sell S/buy W (expressed as the direct cross)
```

---

## Section 2 — Execution Layer (Bid/Ask Convention)

Once the entry condition is met, the theoretical signal ends and
microstructural precision begins. The EA must place a passive limit
order — never cross the spread.

### 2.1 — Core principle

To place a passive limit order, the EA must compute the exact price
at which the execution instrument should rest so that:

1. The limit order sits on the correct side of the market (bid for
   buy limits, ask for sell limits)
2. The order is not inside the current spread (which would trigger
   immediate execution as a market order)
3. The price corresponds to a target spread value T in the matrix

### 2.2 — Price relationship

For the EUR/GBP/USD pod:

```
EURGBP_synthetic = EURUSD / GBPUSD
```

This is the exact cross-rate relationship used to invert. All six
cases derive from this identity.

### 2.3 — Target spread definition

The entry target spread is EntryThreshold (0.0008) on the side of
the signal. For layer N, the entry target is:

```
T_entry_N = -(EntryThreshold + (N-1) * AddRatio * H4_ATR_logspace)
```

Where H4_ATR_logspace is the H4 ATR expressed as a log-return
(ATR_pips / current_price). This keeps T in the same dimensionless
log-return units as the spread.

The exit target for layer N is:

```
T_exit_N = T_entry_N + ExitRatio * H4_ATR_logspace
```

Both T_entry and T_exit are computed once at layer entry and fixed.
They are spatial targets, not updated dynamically (carry adjustment
is ADR-003).

---

## Section 3 — The Six Inversion Cases

### Notation

```
EU_bid  = EURUSD Bid
EU_ask  = EURUSD Ask
EU_mid  = (EU_bid + EU_ask) / 2

GB_bid  = GBPUSD Bid
GB_ask  = GBPUSD Ask
GB_mid  = (GB_bid + GB_ask) / 2

EG_bid  = EURGBP Bid
EG_ask  = EURGBP Ask

T       = target spread value (signed, dimensionless log-return units)
```

The inversion derives the target price P of the execution instrument
such that, if the execution instrument were at P (with USD legs at
their current values), the matrix spread would equal T.

### 3.1 — Derivation of the general inversion formula

From the matrix solution:

```
Spread = GBP - EUR = r_GB - r_EU
       = log(GB_t/GB_0) - log(EU_t/EU_0)
       = log((GB_t * EU_0) / (GB_0 * EU_t))
       = -log(EURGBP_t / EURGBP_0)
       = -r_EG
```

Therefore: `Spread = T` implies `r_EG = -T`

```
log(EG_t / EG_0) = -T
EG_t = EG_0 * exp(-T)
```

Where EG_0 is the current synthetic EURGBP mid = EU_mid / GB_mid.

This is the master inversion formula. All six cases apply it with
the correct bid/ask inputs for the execution instrument direction.

### 3.2 — Case 1: S=EUR, W=GBP → Sell EURGBP

**Signal:** EUR strongest, GBP weakest. EURGBP is overpriced.
**Action:** Sell EURGBP with a passive sell limit (offer into the market).
**Passive sell limit:** order rests at the Ask. Fill occurs when
bid rises to meet it. EA places at EG_ask level.

**Bid/ask logic:**
- To sell EURGBP passively, the limit rests above current market.
- The synthetic reference uses EU_bid and GB_ask (conservative:
  weakens the synthetic, ensuring the limit is not inside the spread).

```
EG_synthetic = EU_bid / GB_ask        // conservative synthetic mid
P_sell_limit = EG_synthetic * exp(-T) // T is negative (signal side)
```

Place passive sell limit at P_sell_limit.
Verify: P_sell_limit > EG_bid (order is above market, truly passive).

### 3.3 — Case 2: S=GBP, W=EUR → Buy EURGBP

**Signal:** GBP strongest, EUR weakest. EURGBP is underpriced.
**Action:** Buy EURGBP with a passive buy limit (bid into the market).
**Passive buy limit:** order rests at the Bid. Fill occurs when
ask falls to meet it.

**Bid/ask logic:**
- To buy EURGBP passively, the limit rests below current market.
- The synthetic reference uses EU_ask and GB_bid (conservative:
  strengthens the synthetic, ensuring the limit is not inside the spread).

```
EG_synthetic = EU_ask / GB_bid        // conservative synthetic mid
P_buy_limit  = EG_synthetic * exp(-T) // T is positive (signal side)
```

Place passive buy limit at P_buy_limit.
Verify: P_buy_limit < EG_ask (order is below market, truly passive).

### 3.4 — Case 3: S=EUR, W=USD → Sell EURUSD

**Signal:** EUR strongest, USD weakest. EURUSD is overpriced.
**Action:** Sell EURUSD with a passive sell limit.

**Bid/ask logic:**
- Selling EURUSD: instrument is the EUR leg directly.
- No synthetic cross needed. Use current EURUSD as anchor.
- Spread = r_GB - r_EU. Fixing r_GB (GBPUSD is known), solve for
  r_EU that produces target spread T.

```
r_EU_target = r_GB_current - T
// r_GB_current = log(GB_mid_now / GB_mid_12bars_ago)  [signal-layer value]

EU_target_mid = EU_mid_12bars_ago * exp(r_EU_target)
P_sell_limit  = EU_target_mid     // place sell limit here
```

Conservative adjustment: subtract half-spread to ensure passivity.
```
P_sell_limit = EU_target_mid - (EU_ask - EU_bid) / 2
```

Verify: P_sell_limit > EU_bid.

### 3.5 — Case 4: S=USD, W=EUR → Buy EURUSD

**Signal:** USD strongest, EUR weakest. EURUSD is underpriced.
**Action:** Buy EURUSD with a passive buy limit.

```
r_EU_target  = r_GB_current - T   // T is positive
EU_target_mid = EU_mid_12bars_ago * exp(r_EU_target)
P_buy_limit   = EU_target_mid + (EU_ask - EU_bid) / 2
```

Verify: P_buy_limit < EU_ask.

### 3.6 — Case 5: S=GBP, W=USD → Sell GBPUSD

**Signal:** GBP strongest, USD weakest. GBPUSD is overpriced.
**Action:** Sell GBPUSD with a passive sell limit.

```
r_GB_target  = r_EU_current + T   // T is negative; r_EU fixed
GB_target_mid = GB_mid_12bars_ago * exp(r_GB_target)
P_sell_limit  = GB_target_mid - (GB_ask - GB_bid) / 2
```

Verify: P_sell_limit > GB_bid.

### 3.7 — Case 6: S=USD, W=GBP → Buy GBPUSD

**Signal:** USD strongest, GBP weakest. GBPUSD is underpriced.
**Action:** Buy GBPUSD with a passive buy limit.

```
r_GB_target  = r_EU_current + T   // T is positive
GB_target_mid = GB_mid_12bars_ago * exp(r_GB_target)
P_buy_limit   = GB_target_mid + (GB_ask - GB_bid) / 2
```

Verify: P_buy_limit < GB_ask.

---

## Section 4 — LIFO Ticket-Based Array Management

### 4.1 — Ruling

DeepSeek Finding 1.1 (confirmed by Gemini): exit fills are NOT
guaranteed to arrive in LIFO order. If price gaps through multiple
exit limit levels simultaneously, MT5's price-time priority engine
may fill an older layer's exit before a newer layer's exit. Stack-
position popping will corrupt the inventory array in this scenario.

### 4.2 — Required implementation

Each Layer struct stores both the entry ticket and the exit ticket:

```mql5
struct Layer {
    double   entry_price;
    double   exit_target;
    double   add_next;
    double   lot_size;
    ulong    entry_ticket;   // ticket of the filled entry order
    ulong    exit_ticket;    // ticket of the placed exit limit order
};

Layer inventory[];           // dynamic array, acts as logical LIFO stack
```

### 4.3 — OnTradeTransaction fill handler

```
OnTradeTransaction(trans, request, result):

    if trans.type == TRADE_TRANSACTION_DEAL_ADD:

        deal = HistoryDealGet(trans.deal)

        if deal.entry == DEAL_ENTRY_IN:
            // Entry fill: find matching entry_ticket in inventory
            // Add new Layer to inventory[] with this entry_ticket
            // Place exit limit order at computed exit_target
            // Store exit_ticket in this Layer
            // Place next entry limit order at add_next level
            //   (if inventory size < MaxLayers)

        if deal.entry == DEAL_ENTRY_OUT:
            // Exit fill: find matching exit_ticket in inventory[]
            // Remove THAT specific layer by index — NOT inventory.pop()
            // Shift remaining array elements to fill the gap
            // Log which layer exited (for audit trail)
```

### 4.4 — Why this matters

In the normal case (no gaps), exits fire in LIFO order by geometry:
the most recently added layer has an exit target closest to current
price and therefore fills first. Ticket-based removal produces
identical results to stack-position popping in this case.

In the gap case, ticket-based removal correctly handles out-of-order
fills without corrupting the inventory. Stack-position popping would
delete the wrong layer, leaving a phantom position with no exit order.

---

## Section 5 — Freeze Level Guardrail

### 5.1 — Ruling

DeepSeek Finding 2.2 (confirmed by Gemini): many FTMO-compatible
brokers enforce a freeze level — a minimum distance from current
price below which a pending limit order cannot be placed. An
analytically computed limit price that falls within this zone will
be rejected with TRADE_RETCODE_INVALID_STOPS.

### 5.2 — Required implementation

Before placing any limit order (entry or exit):

```
freeze_level  = SymbolInfoInteger(_Symbol, SYMBOL_FREEZE_LEVEL)
                // returned in points; convert to price
freeze_price  = freeze_level * SymbolInfoDouble(_Symbol, SYMBOL_POINT)

distance      = abs(computed_limit_price - current_market_price)

if distance <= freeze_price:
    // Skip order placement this bar
    // Log: "order skipped — within freeze level"
    // Re-evaluate on next M5 bar or next OnTick nudge
    return
```

### 5.3 — Design note

Skipping a marginal entry (one where the computed price is within
the freeze zone) is preferable to a rejected order. A signal that
close to market is likely noise around the entry threshold anyway.
The signal will either widen on the next bar (and place cleanly)
or decay below threshold (and correctly produce no trade).

---

## Section 6 — Intra-Bar Limit Price Nudging

### 6.1 — Ruling

DeepSeek Finding 2.3 (confirmed by Gemini): the EA computes the
matrix signal only on M5 bar close. Between bars, EURUSD and GBPUSD
can move 5-10 pips, making the pre-positioned limit price stale
relative to the target spread. The strategy then provides liquidity
at a price that no longer reflects the mispricing signal.

Gemini resolution: separate signal computation from limit price
update. Signal (matrix, spread, ranking) runs on M5 close only.
Limit price (the inversion result) updates on every tick using
the current USD leg prices and the fixed signal scores from the
last M5 bar.

### 6.2 — Required implementation

State persisted between ticks (set on M5 bar close):

```
// Set on each new M5 bar close:
double g_r_EU_signal;     // log return from signal computation
double g_r_GB_signal;     // log return from signal computation
int    g_strongest;       // EUR=0, GBP=1, USD=2
int    g_weakest;         // EUR=0, GBP=1, USD=2
bool   g_signal_active;   // true if abs(spread) > threshold
```

OnTick logic (runs every tick when signal is active):

```
OnTick():
    // 1. Check for new M5 bar → if yes, run full signal computation
    //    update g_r_EU_signal, g_r_GB_signal, g_strongest, g_weakest

    // 2. If g_signal_active and no open inventory:
    //    Use current EU_bid/EU_ask/GB_bid/GB_ask (live)
    //    Use g_r_EU_signal, g_r_GB_signal (fixed from last bar)
    //    Recompute limit price via the relevant inversion case
    //    If computed price differs from current pending order price
    //      by more than 0.5 pips: cancel and replace the limit order

    // 3. Check freeze level before any order placement

    // 4. Check circuit breakers (per-pod and global)
```

### 6.3 — Design note

The 0.5-pip re-placement threshold prevents excessive order
modifications on every tick (which can trigger broker throttling)
while keeping the limit price current. This threshold is a tunable
parameter: NudgeThreshold (default: 0.5 pips, expressed in points).

The signal scores (g_r_EU_signal, g_r_GB_signal) are intentionally
fixed between M5 bars. The ranking and spread magnitude are M5-bar
decisions. Only the execution price nudges tick-by-tick to maintain
passivity.

---

## Section 7 — Exit Target Computation Summary

For each layer N at the moment of entry fill:

```
// Entry price: the price at which the limit order filled (from deal)
entry_price = deal.price

// H4 ATR in price space (pips), converted to log-return space:
h4_atr_log  = H4_ATR_pips / entry_price

// Layer-specific ratios from LayerRatios[N]:
add_ratio_N  = LayerRatios[N][0]
exit_ratio_N = LayerRatios[N][1]

// Exit target (spatial, fixed at entry, not updated until ADR-003):
exit_target = entry_price + exit_ratio_N * H4_ATR_pips * direction
//   direction = +1 for buy positions (exit above entry)
//             = -1 for sell positions (exit below entry)

// Next entry level (where Layer N+1 limit will be placed):
add_next = entry_price - add_ratio_N * H4_ATR_pips * direction
//   adverse direction: opposite of exit direction
```

Both exit_target and add_next are in price space (pips), not
log-return space. This is the ADR-001 fix from DeepSeek Round 1
Q6/Q8: layer spacing uses H4 price-space ATR, not spread std dev.

---

## Section 8 — Negative Space (Explicit Exclusions)

The following are explicitly out of scope for this ADR and must
not be implemented by Cursor when executing against this spec:

| Exclusion | Rationale |
|-----------|-----------|
| Forward price adjustment for carry | ADR-003 |
| Volatility-scaled entry threshold | V2 |
| Dynamic ATR blending across timeframes | V2 |
| 4+ currency pod extension | V2 |
| Cross-pod correlation management | V2 |
| Any market orders for entry | Design constraint: passive only |
| OnTick signal recomputation | Signal is M5-bar only; only limit price nudges on tick |
| Modifying exit_target after placement | Spatial targets are fixed; carry drift is ADR-003 |
| Stack-position-based inventory pop | Replaced by ticket-based removal (Finding 1.1) |

---

## Section 9 — Gemini Rulings (Post-Submission)

**Gemini approval received: 2026-06-07. ADR-002 is locked.**

1. **Cases 3-6 inversion precision — RESOLVED.**
   The fixed-leg approximation (anchoring g_r_GB_signal or
   g_r_EU_signal to the M5 bar close) is acceptable for V1.
   Rationale: fixing the anchor leg provides stability to the limit
   order. Using tick-level recalculation of the fixed leg would
   expose the execution leg to high-frequency tick noise, causing
   the limit price to flutter erratically. The M5 anchor correctly
   reflects the macroeconomic dislocation that triggered the signal.

2. **NudgeThreshold 0.5 pips — CONFIRMED.**
   A tighter threshold (e.g. 0.1 pips) risks TRADE_RETCODE_TOO_MANY_REQUESTS
   from broker throttling. 0.5 pips ensures modification only on
   meaningful price shifts.

3. **MT5 error taxonomy correction (Gemini addition).**
   Section 5.2 refers to TRADE_RETCODE_INVALID_STOPS as the error
   triggered by freeze level violations. This is incorrect.
   - TRADE_RETCODE_INVALID_PRICE (10015): triggered when a pending
     limit order price is invalid relative to current market (e.g.
     buy limit placed above Ask, or inside the spread). This is the
     error that fires on freeze level violations.
   - TRADE_RETCODE_INVALID_STOPS (10016): triggered when SL/TP
     values attached to an order are inside SYMBOL_TRADE_STOPS_LEVEL
     or placed on the mathematically wrong side of the entry price.
   Since this EA uses independent limit orders for entry and exit
   (no native SL/TP attached to entry orders), INVALID_STOPS is not
   relevant here. Cursor must handle TRADE_RETCODE_INVALID_PRICE
   (10015) in the order placement error handler. The freeze level
   check logic in Section 5.2 is correct as written.

---

## Sequencing

1. ADR-001 — Accepted ✅
2. DeepSeek execution audit (Round 2) — Complete ✅
3. **ADR-002 (this document)** — Accepted ✅ Gemini approved 2026-06-07
4. ADR-003 — Carry adjustment — **NEXT**
5. MQL5 EA implementation (Cursor) — Blocked until ADR-003 approved
6. MT5 strategy tester validation on historical tick data
7. Practice account deployment (minimum lot size)
8. 4-week observation before any parameter changes
9. Live account deployment after practice validation
