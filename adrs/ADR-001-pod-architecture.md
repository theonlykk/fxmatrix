
markdown# ADR-001: FX Currency Strength Pod — 3-Currency Prototype

**Date:** 2026-06-07  
**Status:** Accepted  
**Repo:** theonlykk/fxmatrix  

---

## Objective

Build a systematic FX mean-reversion strategy that:
- Decomposes FX pair returns into latent currency strength scores
- Identifies relative mispricing between the strongest and weakest currency
- Executes via passive limit orders at pre-calculated price levels
- Manages risk via a laddered inventory with LIFO unwind
- Returns to exactly flat when all layers exit

---

## The Pod Concept

A pod is a self-contained 3-currency trading universe. It runs its 
own matrix, manages its own inventory, and has its own circuit 
breaker. It is independent of all other pods.

For the prototype, one pod: **EUR, GBP, USD.**

Three instruments available within the pod:
- EURUSD
- GBPUSD  
- EURGBP

---

## The Math

### Step 1 — Observed returns

At each M5 bar, compute rolling 1-hour log returns for all pairs 
in the pod. 1 hour = 12 M5 bars.
r_EURUSD = log(EURUSD_now / EURUSD_1h_ago)
r_GBPUSD = log(GBPUSD_now / GBPUSD_1h_ago)

### Step 2 — Solve the 3-currency system

We assume pair returns decompose into currency strengths:
EUR - USD = r_EURUSD
GBP - USD = r_GBPUSD
EUR + GBP + USD = 0  (sum-to-zero constraint)

Analytical solution (no matrix library required):
USD = -(r_EURUSD + r_GBPUSD) / 3
EUR = r_EURUSD + USD
GBP = r_GBPUSD + USD

### Step 3 — Rank and select instrument

Sort currencies by score. Strongest = S, Weakest = W.
Spread = s_W - s_S  (always negative by construction)

Select the direct cross between S and W as the execution instrument.
All 3 direct crosses exist and are liquid for EUR/GBP/USD:
S=EUR, W=GBP → sell EURGBP
S=EUR, W=USD → sell EURUSD
S=GBP, W=USD → sell GBPUSD
S=GBP, W=EUR → buy EURGBP
S=USD, W=EUR → buy EURUSD
S=USD, W=GBP → buy GBPUSD

### Step 4 — Entry condition
if abs(spread) > entry_threshold:
signal = True

`entry_threshold` is a tunable parameter, expressed in log-return 
units. Typical starting value: 0.0008 (approximately 8 pips on 
EURUSD).

---

## Pre-Positioning — The Key Architectural Insight

The strategy does not react to price reaching a level. It 
calculates in advance what price level corresponds to a target 
spread value, then places passive limit orders at that level 
before the market arrives.

### The inversion (3-currency case)

For any target spread value T, and given current prices, we can 
solve analytically for the price of the execution instrument that 
would produce that spread.

Example: S=EUR, W=GBP, instrument=EURGBP.

EURGBP ≈ EURUSD / GBPUSD

The spread s_GBP - s_EUR depends on r_EURUSD and r_GBPUSD. Given 
a fixed r_EURUSD (EURUSD price is known), we can solve for the 
r_GBPUSD that produces target spread T, then convert to a GBPUSD 
price, then divide into EURUSD to get target EURGBP price.

This gives us the exact EURGBP price to place the limit order 
before the market gets there.

---

## Execution Framework

### Instrument selection
Always the direct cross between strongest and weakest currency.
Only instruments in the pod's liquid pair set are eligible.

### Entry
Passive limit order placed at the pre-calculated price level.
No market orders. Strategy provides liquidity, never takes it.

### Layer spacing
Add 1 unit every X pips of adverse move.
X = ATR_multiplier × ATR(timeframe)

ATR is computed on a higher timeframe (H4 or D1) to avoid M5 noise.
ATR_multiplier is a tunable parameter.

Suggested starting values:
ATR timeframe: H4
Add ratio:  0.75 × H4_ATR  (adverse move to add next layer)
Exit ratio: 0.25 × H4_ATR  (favourable move to exit each layer)

Example with H4 ATR = 20 pips:
Layer 1: entry at market implied level
add Layer 2 at entry - 15 pips
exit at entry + 5 pips
Layer 2: entry at Layer 1 entry - 15 pips
add Layer 3 at Layer 2 entry - 15 pips
exit at Layer 2 entry + 5 pips
...and so on

The add and exit ratios can be parameterised as arrays, one per 
layer depth, allowing the ratios to vary by layer:
LayerRatios[5][2] = {
{0.25, 0.75},   // Layer 1
{0.30, 0.70},   // Layer 2
{0.35, 0.65},   // Layer 3
{0.40, 0.60},   // Layer 4
{0.50, 0.50},   // Layer 5
}

Similarly ATR can be a blended array across timeframes:
ATRConfig[N][2] = {multiplier, timeframe}
effective_ATR = weighted average of (multiplier × ATR(timeframe))

### Sizing
Uniform per layer. No tapering. 1 unit = BaseLotSize.
Risk control is max_layers cap, not size reduction.

### LIFO unwind
Most recent layer exits first.
Each layer's exit target is fixed at entry when the layer is added.
Exit orders are passive limits placed immediately on layer entry.

### Return to flat
When all layers exit, pod inventory = 0.
No residual position. Clean lifecycle.

---

## Risk Controls

### Per-pod circuit breaker
If unrealised loss on this pod exceeds MAX_POD_DRAWDOWN:
- Cancel all pending entry orders
- Close all open positions at market
- Halt pod until manually re-enabled

### Global circuit breaker
If total account equity drops 5% from peak:
- Cancel ALL pending orders across ALL pods
- Close ALL positions at market immediately
- Halt all pods

### Maximum layers
Hard cap at MAX_LAYERS (suggested: 5).
No new entries beyond this depth regardless of signal strength.

---

## EA Architecture (MQL5)

### Inputs
```mql5
input int    StrengthWindow    = 12;      // M5 bars = 1 hour
input double EntryThreshold    = 0.0008;  // log-return units
input int    MaxLayers         = 5;
input double BaseLotSize       = 0.01;
input double AddRatio          = 0.75;    // × H4 ATR
input double ExitRatio         = 0.25;    // × H4 ATR
input double MaxPodDrawdown    = 0.02;    // 2% per pod
input double GlobalDrawdown    = 0.05;    // 5% global
```

### State
```mql5
struct Layer {
    double entry_price;
    double exit_target;
    double add_next;
    double lot_size;
    int    ticket;
};

Layer    inventory[];   // LIFO stack
double   peak_equity;
bool     halted;
datetime last_bar_time;
```

### Execution hooks
OnTick():

detect new M5 bar (time comparison)
if new bar: run signal computation, update limit prices
check circuit breakers
check for fill events (fast path)

OnTradeTransaction():

on fill: update inventory stack
on entry fill: place exit limit + next entry limit
on exit fill: pop LIFO stack


### Signal computation (on each new M5 bar)

CopyClose EURUSD and GBPUSD, last 13 bars
Compute r_EU = log(close[0] / close[12])
Compute r_GB = log(close[0] / close[12])
Solve: USD = -(r_EU + r_GB) / 3
EUR = r_EU + USD
GBP = r_GB + USD
Rank currencies
If abs(spread) > threshold AND inventory empty:
compute entry price via inversion
place first limit order
If inventory not empty:
update pending entry level if spread has shifted


---

## What This Is Not

- Not a candlestick pattern strategy
- Not a trend-following strategy
- Not a news-driven strategy
- Not dependent on any external data source beyond M5 OHLC
- Not connected to Railway, PostgreSQL, or the CandleLab pipeline

---

## Failure Mode

Primary risk: monotonic trend in the execution instrument with 
no retracement. All layers fill, no exits fire, inventory hits 
MAX_LAYERS cap, pod circuit breaker triggers, positions closed 
at a loss.

Mitigation:
- Conservative MAX_LAYERS cap
- ATR-scaled layer spacing (wider spacing in high-vol regime)
- Per-pod circuit breaker independent of global circuit breaker
- Start on practice account at minimum lot size

---

## Sequencing

1. This ADR — approved
2. DeepSeek audit of EA architecture
3. Gemini ruling on any architectural changes
4. MQL5 EA implementation (Cursor or manual)
5. MT5 strategy tester validation on historical tick data
6. Practice account deployment (minimum lot size)
7. 4-week observation before any parameter changes
8. Live account deployment only after practice validation

---

## Open Questions (deferred to V2)

- Optimal pod currency selection for 4+ currency extension
- Cross-pod correlation monitoring
- Dynamic ATR blending across timeframes
- Basket execution for G10 scale