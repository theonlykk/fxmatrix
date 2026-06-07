Good — I’ll keep this tight and structured, like a proper desk memo.

1. Strategy Memo — Currency Strength Ladder / Inventory Mean Reversion
Objective
Exploit short-term cross-currency mispricing by:
decomposing FX pairs into currency strength scores
trading spread between strongest and weakest currency
managing positions via layered inventory + passive unwind

Instruments
Universe: USD, EUR, GBP
Tradable pairs:
EURUSD
GBPUSD
Synthetic cross:
GBP vs EUR = GBPUSD − EURUSD

Signal Construction
Every 5-minute bar (M5), compute rolling 1-hour returns:
1     r_EURUSD = log(P_t / P_t-12)
2     r_GBPUSD = log(P_t / P_t-12)
Solve system:
1     EUR − USD = r_EURUSD
2     GBP − USD = r_GBPUSD
3     EUR + GBP + USD = 0
→ produces:
1     s_EUR, s_GBP, s_USD
Define:
1     spread = s_weak − s_strong

Trade Idea
At any decision time:
Identify:
strongest currency (S)
weakest currency (W)
Trade:
1     LONG W vs SHORT S
Example:
1     EUR strongest, GBP weakest
2     → Long GBP vs EUR
3     
4     Execution:
5     + GBPUSD
6     - EURUSD

Entry Logic
Triggered when spread deviates:
1     |spread| > threshold
Example:
1     spread = -1.0  → enter long (expect reversion)

Execution Style
Orders are passive (resting limits)
No urgency — strategy relies on being hit during overshoot

Position Structure — Ladder
Base entry
1     Layer 1: buy at 1.00
Adverse move → add
1     Layer 2: add at 0.975
2     Layer 3: add at 0.95
3     Layer 4: add at 0.925
4     ...
5     (max depth capped)
Spacing:
1     Δ_i increasing with depth (optional)

Core Mechanic — LIFO Unwind
Each layer exits independently.
Rule:
Always unwind exactly the amount of the most recent entry
Example:
1     Entry stack:
2     [1.00, 0.975, 0.95]
3     
4     If spread moves to 0.975:
5     → exit 0.95 layer only
Then:
1     Remaining stack:
2     [1.00, 0.975]
3     
4     Next exit:
5     0.975 → 1.00
Then:
1     Remaining:
2     [1.00]
3     
4     Final exit:
5     1.00 → 1.25

Exit Targets (Skewed)
Not symmetric.
Define:
1     entry spacing = Δ_i
2     exit spacing  = Γ_i
Where:
1     Γ_i decreases with depth
Example:

Layer Entry Exit
1     1.00  1.25
2     0.975 1.00
3     0.95  0.975
4     0.925 0.96
5     0.90  0.93
Interpretation:
shallow trades → expect full reversion
deep trades → accept partial bounce

Position Sizing
Constraint:
Exit size = last entry size (always)
New entries:
1     size_i = base * f(depth)
Where:
1     f(depth) decreasing
Example:
1     [1.0, 1.0, 0.75, 0.5, 0.25]

Inventory Principle
If all layers are eventually unwound:
1     → Net position = 0
2     → Realized PnL > 0
PnL is crystallized incrementally via LIFO exits.

Strategy Interpretation
This is:
Cross-sectional FX mean reversion with inventory-based execution
More precisely:
factor model (currency strength)
relative value trade (spread)
market making behaviour (passive fills)
inventory compression (layered exits)

Failure Mode
Primary risk:
1     Monotonic trend with no retracement
→ no fills on exits
→ inventory accumulates
Mitigation:
cap layers
taper size
shrink exit targets
optionally block adds in high ADX

2. What a Backtest Looks Like
This is NOT a normal “signal → immediate fill → exit” backtest.
You must simulate:
path-dependent limit order book behavior

Core Components
1. Data
M5 candles:
1     datetime, open, high, low, close
For:
EURUSD
GBPUSD

2. Derived Series
At each bar:
1     compute spread_t
(as above)

3. Order Book Simulation (critical)
You maintain:
1     pending_orders:
2         entries (limits below current spread)
3         exits (limits above current spread)

4. Fill Logic (per candle)
Using candle range:
If LONG spread:
Entry fills
1     if low <= entry_price → fill
Exit fills
1     if high >= exit_price → fill

5. State Tracking
Maintain:
1     inventory_stack = [
2         {price, size, exit_target}
3     ]

6. Backtest Loop
At each M5 bar:
Step 1 — compute spread

Step 2 — check fills
iterate through pending orders
apply high/low logic

Step 3 — update inventory
if entry filled → push new layer
if exit filled → pop last layer

Step 4 — place new orders
If:
1     inventory empty:
2         check entry condition → place first order
If:
1     inventory not empty:
2         place:
3             next entry level (if depth < max)
4             exit for last layer

7. PnL Calculation
Each unwind:
1     PnL += size * (exit_price − entry_price)
Total PnL = sum over all closed layers

8. Important Backtest Features
Must include:
limit order fills via OHLC
stacked inventory
LIFO unwind
asymmetric exits
size tapering

Nice to add later:
spread volatility scaling
ADX gating
slippage / bid-ask
fill priority (high/low ordering ambiguity)

9. One subtle but important detail
When both entry and exit are inside same candle:
1     high > exit AND low < entry
You must choose:
conservative (worse fill)
optimistic (best fill)
This matters materially.

Final takeaway
You are NOT backtesting a strategy.
You are backtesting:
an execution framework + inventory process driven by a signal
That’s why:
path matters
order placement matters
sizing matters more than signal

If you want next step:
I’ll give you one single Jupyter cell that implements exactly this loop using your spread series — no abstraction, no classes, fully deterministic.