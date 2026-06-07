Spread = s_weak - s_strong (e.g. s_GBP - s_EUR)

Entry when |spread| > entry_threshold

**Execution:** Direct cross (EURGBP). Single instrument, not two 
USD legs. Passive limit orders only — strategy provides liquidity.

**Inventory:** Laddered with LIFO unwind.
- Add 1 unit every X pips adverse move
- X = k × rolling_std(spread, 24 bars)
- Uniform sizing per layer — no tapering
- Max layers = hard cap (e.g. 5)
- Exit: LIFO — most recent layer exits first
- Exit targets: asymmetric — shallow layers target full reversion,
  deep layers accept partial bounce

**Risk control:** Max layers is the only position size control.
Global circuit breaker: if account equity drops 5% from peak,
close all positions immediately.

## Proposed EA Architecture (Gemini approved)

```mql5
// Inputs
input int    StrengthWindow  = 12;    // M5 bars for 1h return
input double EntryThreshold  = 0.001; // spread deviation to enter
input double LayerSpacingK   = 1.0;  // multiplier on spread_std
input int    MaxLayers       = 5;    // hard cap
input double BaseLotSize     = 0.01; // uniform per layer
input double DrawdownLimit   = 0.05; // 5% from peak equity

// State
struct Layer {
    double entry_spread;  // spread at entry
    double entry_price;   // EURGBP price at entry
    double exit_target;   // spread target for exit
    double lot_size;      // always BaseLotSize
    int    ticket;        // MT5 order ticket
};

Layer inventory[];  // LIFO stack
double peak_equity; // for circuit breaker

// Hooks
void OnTick() {
    // Fast path only:
    // 1. Check circuit breaker
    // 2. Check if any exit limit orders filled
    // 3. On fill: pop LIFO stack, place next exit
}

void OnBar() {  // fires on new M5 bar
    // Signal computation:
    // 1. Fetch last StrengthWindow M5 closes for EURUSD, GBPUSD
    // 2. Compute r_EURUSD, r_GBPUSD (log returns)
    // 3. Solve 3-currency system analytically
    // 4. Compute spread = s_weak - s_strong
    // 5. Compute rolling_std of spread (24 bars)
    // 6. Update layer_spacing = LayerSpacingK × spread_std
    // 7. If flat: place first entry limit if |spread| > threshold
    // 8. If in position: update pending entry level
}

void OnTradeTransaction() {
    // Reconcile inventory on any order event
    // Detect fills, cancellations
}
```

## Architectural Questions for DeepSeek

**Q1 — MQL5 OnBar equivalent:**
MQL5 has no native OnBar() event. The standard pattern is to 
detect a new bar inside OnTick() by comparing the current bar 
open time to the last processed bar time. Is this the correct 
pattern, or is there a better approach for M5 bar detection in 
MQL5?

**Q2 — Log return computation in MQL5:**
We need rolling 1h log returns: log(close_t / close_t-12) for 
each pair. MQL5 has CopyClose() to fetch historical closes. 
Is there any precision or timing issue with using CopyClose() 
for this computation on M5 bars?

**Q3 — Limit order management:**
For each inventory layer we place two limit orders: one entry 
(below current spread for long) and one exit (above current 
spread). In MQL5, limit orders are placed via OrderSend() with 
ORDER_TYPE_BUY_LIMIT or ORDER_TYPE_SELL_LIMIT. When the spread 
moves and we need to update the next entry level, should we 
modify the existing pending order (OrderModify) or cancel and 
replace? What are the failure modes of each approach?

**Q4 — LIFO stack in MQL5:**
The inventory is a LIFO stack of Layer structs. MQL5 supports 
dynamic arrays. Is there any issue with using a dynamic struct 
array as a LIFO stack in MQL5? Specifically around ArrayResize() 
and memory management during high-frequency OnTick() calls?

**Q5 — The same-candle problem:**
If during a single M5 bar the price moves through both the entry 
limit AND the exit target of the previous layer, both orders could 
fill in the same bar. MQL5 processes these sequentially via 
OnTradeTransaction(). What is the correct way to handle this 
race condition in the inventory state machine?

**Q6 — EURGBP spread computation:**
The spread we trade (s_GBP - s_EUR) is derived from EURUSD and 
GBPUSD returns. The actual instrument we trade is EURGBP. When 
placing limit orders on EURGBP, we need to convert the spread 
deviation into an EURGBP price level. Is the relationship 
between our spread signal and EURGBP price sufficiently linear 
for this conversion, or does the cross-rate introduce 
non-linearities that require a different approach?

**Q7 — Circuit breaker implementation:**
The 5% drawdown circuit breaker must close ALL open positions 
immediately regardless of limit order state. In MQL5 this means 
closing market orders AND cancelling all pending limits. What 
is the correct sequence to avoid partial fills or orphaned 
orders during emergency flatten?

**Q8 — Single most dangerous assumption:**
What is the single most dangerous assumption in this architecture 
that could cause systematic failure in live trading on FTMO?

Be specific. Point to exact MQL5 patterns where relevant.
No implementation code. Architecture only.