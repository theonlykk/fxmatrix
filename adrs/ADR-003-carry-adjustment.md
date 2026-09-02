# ADR-003: Carry Adjustment — Temporal Drift on Multi-Day Positions

**Date:** 2026-06-08
**Status:** Proposed — Pending Gemini Approval
**Repo:** theonlykk/fxmatrix
**Depends on:** ADR-001 (Pod Architecture), ADR-002 (Matrix-Driven Exits)
**Blocks:** MQL5 EA Implementation

---

## Objective

Define the temporal mechanism by which the EA adjusts open layer
exit targets to account for interest rate carry drift on positions
held overnight or across multiple days. ADR-002 establishes spatial
(price-space) exit targets at layer entry. ADR-003 defines how those
targets drift over time, keeping the exit level economically
equivalent to the original signal in carry-adjusted terms.

---

## What This ADR Does

- Defines the forward price formula for each currency pair in the pod
- Specifies the carry recalculation frequency and trigger
- Defines how entry_spread_adjusted is updated in the Layer struct
- Defines how exit_target is updated via OrderModify() following
  each carry recalculation
- Specifies which interest rates are used and how they are sourced
- Specifies same-day trade exemption (no carry adjustment needed)

## What This ADR Does NOT Do

- Modify entry_spread_raw — immutable by ADR-002 ruling
- Change the spatial inversion logic — owned by ADR-002
- Apply carry to layer spacing (add_next) — add_next is fixed at
  entry and not carry-adjusted
- Implement volatility-scaled carry — V2
- Handle swap roll for positions held over weekend — V2
- Apply carry to the signal layer (mid-price matrix) — signal uses
  spot prices only, carry is an exit adjustment only

---

## Governing Rulings

| Decision | Ruling | Source |
|----------|--------|--------|
| ADR-003 scope | Temporal drift only, layered on ADR-002 spatial targets | Gemini |
| entry_spread_raw | Immutable after fill | Gemini (ADR-002) |
| entry_spread_adjusted | Updated daily by carry recalculation | Gemini (ADR-002) |
| exit_target | Updated via OrderModify() after carry recalculation | Gemini (ADR-002) |
| Same-day trades | No carry adjustment needed | Handoff doc |
| Forward price formula | Spot × (1 + r_base × t) / (1 + r_quote × t) | Handoff doc |

---

## Section 1 — The Carry Problem

### 1.1 — Why raw entry spread becomes stale

At layer entry, the matrix spread is computed from spot prices:

```
Spread = r_GB - r_EU = log(GBPUSD_now / GBPUSD_1h_ago)
                     - log(EURUSD_now / EURUSD_1h_ago)
```

The entry_spread_raw (e.g. 8.0) corresponds to specific EURUSD
and GBPUSD spot prices at fill time. If those same prices are
plugged into the matrix one week later, the matrix still returns
a spread of 8.0 — because the prices are unchanged in the record.

But those prices are now stale. The fair value of each currency
pair has drifted due to interest rate differentials. A position
entered at a spread of 8.0 one week ago is not equivalent to a
new position entered at a spread of 8.0 today. The carry cost
of holding the position for one week must be reflected in the
effective entry spread and in the exit target.

### 1.2 — The correction

Take the recorded entry prices. Compute their forward equivalents
using the interest rate differential for the holding period. Feed
those forward prices into the matrix. The result is the
carry-adjusted entry spread — the true economic cost of the
position as of today.

```
Example:
  entry_spread_raw      = 8.0   (at fill, one week ago)
  forward-adjusted prices fed into matrix today
  entry_spread_adjusted = 7.9   (carry cost = 0.1 log-return units)
```

The EA then treats 7.9 as the effective entry spread for all
subsequent exit target calculations. The original 8.0 is retained
in entry_spread_raw for audit purposes and never modified.

---

## Section 2 — Forward Price Formula

### 2.1 — The formula

For any FX pair with base currency B and quote currency Q:

```
Forward(t) = Spot × (1 + r_B × t) / (1 + r_Q × t)
```

Where:
- Spot    = entry price of the pair at fill time
- r_B     = annualised overnight interest rate for base currency
- r_Q     = annualised overnight interest rate for quote currency
- t       = holding period in years (days_held / 365)

### 2.2 — Applied to the EUR/GBP/USD pod

For EURUSD (base = EUR, quote = USD):
```
EURUSD_fwd = EURUSD_entry × (1 + r_EUR × t) / (1 + r_USD × t)
```

For GBPUSD (base = GBP, quote = USD):
```
GBPUSD_fwd = GBPUSD_entry × (1 + r_GBP × t) / (1 + r_USD × t)
```

For EURGBP (base = EUR, quote = GBP) — used when execution
instrument is EURGBP directly:
```
EURGBP_fwd = EURGBP_entry × (1 + r_EUR × t) / (1 + r_GBP × t)
```

Note: the forward prices for EURUSD and GBPUSD are the primary
inputs. EURGBP_fwd can be derived from them:
```
EURGBP_fwd = EURUSD_fwd / GBPUSD_fwd
```

This is consistent with the synthetic cross identity used
throughout ADR-002.

### 2.3 — Interest rates used

The formula requires overnight (O/N) interest rates for EUR, GBP,
and USD. The appropriate benchmark rates are:

| Currency | Rate | Source |
|----------|------|--------|
| USD | SOFR (Secured Overnight Financing Rate) | NY Fed |
| EUR | €STR (Euro Short-Term Rate) | ECB |
| GBP | SONIA (Sterling Overnight Index Average) | Bank of England |

These are the standard overnight benchmark rates for each currency,
replacing the legacy LIBOR benchmarks.

### 2.4 — Rate sourcing for V1

For V1 (practice account, strategy tester validation), interest
rates are hardcoded as daily-updated input parameters. The EA
does not fetch rates dynamically.

```mql5
input double r_USD = 0.0533;  // SOFR annualised (update daily)
input double r_EUR = 0.0390;  // €STR annualised (update daily)
input double r_GBP = 0.0520;  // SONIA annualised (update daily)
```

Dynamic rate fetching (e.g. via HTTP request to a rate API) is
deferred to V2. For V1, the rates are accurate enough for
carry adjustment purposes given the strategy's holding period
assumptions.

### 2.5 — Holding period calculation

```
t = (current_date - entry_date) / 365.0
```

Using actual calendar days. entry_time is stored in the Layer
struct (UTC timestamp from fill). current_date is the broker
server date (not local clock — per ARCHITECT.md absolute time
constraint).

Same-day trades (t < 1/365): carry adjustment is zero. No
forward price recalculation performed. entry_spread_adjusted
remains equal to entry_spread_raw.

---

## Section 3 — Carry Recalculation

### 3.1 — Trigger: daily at a fixed time

Carry recalculation runs once per day at a fixed time. The
recommended trigger is 17:00 EST (NY close / FX day boundary).
This is the standard FX carry settlement time — overnight swap
rates are applied at this point by brokers.

```mql5
input string CarryRecalcTime = "17:00";  // broker server time
```

Implementation: compare current broker server time to
CarryRecalcTime in OnTick(). Fire recalculation once per day
when the time boundary is crossed.

### 3.2 — Recalculation sequence for each open layer

For each layer in inventory[]:

```
Step 1: Compute holding period
  t = (broker_server_date - layer.entry_time) / 365.0
  if t < 1/365: skip (same-day trade, no carry)

Step 2: Compute forward prices for the two USD legs
  EURUSD_fwd = layer.entry_price_eurusd × (1 + r_EUR × t)
                                         / (1 + r_USD × t)
  GBPUSD_fwd = layer.entry_price_gbpusd × (1 + r_GBP × t)
                                         / (1 + r_USD × t)

Step 3: Feed forward prices into the matrix
  r_EU_fwd = log(EURUSD_fwd / EURUSD_ref)
  r_GB_fwd = log(GBPUSD_fwd / GBPUSD_ref)
  // EURUSD_ref and GBPUSD_ref are the 1-hour-prior prices
  // at the time of original entry (stored in layer struct)

  USD_fwd = -(r_EU_fwd + r_GB_fwd) / 3
  EUR_fwd =  r_EU_fwd + USD_fwd
  GBP_fwd =  r_GB_fwd + USD_fwd

  new_spread = GBP_fwd - EUR_fwd

Step 4: Update entry_spread_adjusted
  layer.entry_spread_adjusted = new_spread
  // entry_spread_raw is never touched

Step 5: Recompute exit_spread_target
  layer.exit_spread_target = layer.entry_spread_adjusted
                             × (1 - ExitFraction)

Step 6: Recompute exit_target price
  Apply the relevant Section 5 inversion case from ADR-002
  at T = layer.exit_spread_target
  new_exit_price = invert(layer.exit_spread_target,
                          current_bid_ask,
                          layer.direction,
                          layer.instrument)

Step 7: Update exit limit order via OrderModify()
  if abs(new_exit_price - layer.exit_target) > NudgeThreshold:
    OrderModify(layer.exit_ticket, new_exit_price)
    layer.exit_target = new_exit_price
    // exit_ticket unchanged after modify
```

### 3.3 — Layer struct additions for ADR-003

The following fields are added to the Layer struct defined in
ADR-002 to support carry recalculation:

```mql5
struct Layer {
    // ... all ADR-002 fields ...

    // --- Carry recalculation inputs (set at entry, immutable) ---
    double   entry_price_eurusd;    // EURUSD spot at fill time
    double   entry_price_gbpusd;    // GBPUSD spot at fill time
    double   entry_price_eurusd_1h; // EURUSD 1h-prior at fill time
    double   entry_price_gbpusd_1h; // GBPUSD 1h-prior at fill time
    int      instrument;            // EURUSD=0, GBPUSD=1, EURGBP=2
    int      direction;             // BUY=1, SELL=-1
};
```

The four entry price fields are the raw inputs needed to
reconstruct the matrix state at fill time and compute forward
equivalents. They are set once at entry and never modified.

### 3.4 — Interaction with ADR-002 intra-bar nudging

ADR-002 Section 8 specifies that exit limits are nudged via
OrderModify() on every tick when the computed price drifts more
than NudgeThreshold from the current pending order price.

ADR-003 carry recalculation also updates exit limits via
OrderModify() once per day.

These two mechanisms operate on the same exit_ticket. They must
not conflict:

- The daily carry recalculation updates exit_target in the Layer
  struct. This becomes the new baseline for the ADR-002 tick-level
  nudge.
- The tick-level nudge recomputes from live bid/ask using the
  current exit_spread_target (which reflects the carry-adjusted
  value after ADR-003 runs).
- No locking is required because MT5 is single-threaded in
  OnTick() and OnTimer(). The carry recalculation runs to
  completion before the next tick is processed.

Order of operations on carry recalculation day:
```
1. CarryRecalcTime boundary crossed in OnTick()
2. Run carry recalculation for all layers (Section 3.2)
3. Update layer.exit_target and layer.exit_spread_target
4. OrderModify() fires for each layer where delta > NudgeThreshold
5. Resume normal tick processing with updated baselines
```

---

## Section 4 — Same-Day Trade Exemption

Positions opened and closed within the same FX trading day
(before 17:00 EST) do not accrue overnight carry. No forward
price recalculation is performed.

```
if (current_date == entry_date):
    entry_spread_adjusted = entry_spread_raw  // no adjustment
    exit_target unchanged
```

The 17:00 EST carry recalculation trigger naturally handles this:
a same-day position that is still open at 17:00 will receive its
first carry adjustment at that point, covering the first overnight
period.

---

## Section 5 — Negative Space (Explicit Exclusions)

| Exclusion | Rationale |
|-----------|-----------|
| Modifying entry_spread_raw | Immutable by ADR-002 ruling |
| Carry adjustment on add_next | add_next is a price-space ATR offset fixed at entry |
| Carry adjustment on signal layer | Signal uses spot prices only |
| Dynamic rate fetching | V2 |
| Weekend swap roll | V2 — standard FX triple-swap on Wednesday partially mitigates |
| Volatility-scaled carry | V2 |
| Carry adjustment on entry limit orders | Only exit targets are carry-adjusted |
| Modifying entry_price or entry_time | Immutable after fill |

---

## Section 6 — Open Questions for Gemini

1. **EURUSD_ref and GBPUSD_ref in Step 3:** The carry-adjusted
   forward prices must be fed into the matrix as log returns
   relative to a reference price. The natural reference is the
   1-hour-prior price at the time of original entry
   (entry_price_eurusd_1h, entry_price_gbpusd_1h). Is this
   correct, or should the reference be today's 1-hour-prior price
   (i.e. recompute the log return window from today's prices)?

   Our position: use the original entry-time 1h-prior prices.
   This keeps the carry adjustment a pure temporal drift on the
   original signal — it does not blend in any new price information
   from today. The question being asked is: "what is the
   carry-adjusted equivalent of our original entry spread today?"
   not "what is a new signal computed from today's prices?"

2. **Rate update frequency:** Input parameters r_USD, r_EUR, r_GBP
   require manual daily updates in V1. Is this acceptable for
   practice account validation, or should we implement a simple
   file-read mechanism so rates can be updated without recompiling
   the EA?

3. **Carry recalculation on exit_ticket with multiple tranches:**
   A single layer may have multiple outstanding exit limit orders
   (one per partial fill tranche — ADR-002 Section 3.3). Each has
   its own exit_ticket. The carry recalculation updates
   layer.exit_target (a single price). Should all outstanding
   exit limit orders for a layer be modified to the new exit_target,
   or only the most recently placed one?

   Our position: modify all outstanding exit limit orders for the
   layer. They all share the same exit_spread_target; the carry
   recalculation shifts all of them by the same delta.

---

## Section 7 — Sequencing

1. ADR-001 — Accepted ✅
2. DeepSeek audit Round 1 (MQL5 architecture) — Complete ✅
3. DeepSeek audit Round 2 (execution layer) — Complete ✅
4. DeepSeek audit Round 3 (ADR-002 v1) — Complete ✅
5. ADR-002 v2 — Accepted ✅ Gemini approved 2026-06-08
6. **ADR-003 (this document)** — Pending Gemini approval
7. DeepSeek combined audit (ADR-002 v2 + ADR-003) — after Gemini lock
8. MQL5 EA implementation (Cursor) — blocked until audit complete
9. MT5 strategy tester validation on historical tick data
10. Practice account deployment (minimum lot size)
11. 4-week observation before any parameter changes
12. Live account deployment after practice validation
