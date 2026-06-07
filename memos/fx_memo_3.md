Below is a single, self-contained desk memo that ties everything together:
concept
math
code (3 → 5 → N currencies)
signal → trade → sizing
ladder execution
backtest design
No fragmentation.

Memo: FX Currency Strength Mean Reversion with Laddered Inventory Execution

1. Objective
Construct a systematic FX strategy that:
Extracts currency-level strength from observed FX returns
Identifies relative mispricing (strong vs weak)
Trades via a single cross spread
Manages risk using a passive, laddered inventory + LIFO unwind

2. Core Model
We assume:
1     r_pair ≈ s_base − s_quote
where:
r_pair = observed return over window (e.g. 1 hour, 12 M5 bars)
s = latent currency strengths
We solve:
1     A * s = r
with constraint:
1     sum(s) = 0

3. Implementation — 3 Currency Case (USD, EUR, GBP)

3.1 Input (1h returns from M5)
1     import numpy as np
2     import pandas as pd
3     
4     r = pd.Series({
5         'EURUSD': 0.0020,
6         'GBPUSD': -0.0010
7     })

3.2 Build matrix
1     currencies = ['EUR', 'GBP', 'USD']
2     ccy_idx = {c:i for i,c in enumerate(currencies)}
3     
4     A = np.zeros((2,3))
5     A[0, ccy_idx['EUR']] = 1
6     A[0, ccy_idx['USD']] = -1
7     
8     A[1, ccy_idx['GBP']] = 1
9     A[1, ccy_idx['USD']] = -1

3.3 Solve
1     A_aug = np.vstack([A, np.ones(3)])
2     r_aug = np.append(r.values, 0)
3     
4     s, *_ = np.linalg.lstsq(A_aug, r_aug, rcond=None)
5     s = pd.Series(s, index=currencies)

3.4 Interpretation
Example output:
1     EUR: +0.0015  
2     GBP: -0.0005  
3     USD: -0.0010
So:
1     strong = EUR  
2     weak   = GBP

3.5 Trade
We want:
1     LONG GBP / SHORT EUR
Execution:
1     trade = {
2         'GBPUSD': +1,
3         'EURUSD': -1
4     }

3.6 Initial Sizing
1     spread = s[weak] - s[strong]
2     
3     base_size = 1.0
4     size = base_size * min(abs(spread) / 0.002, 1.0)

4. 5 Currency Case (USD, EUR, GBP, JPY, CHF)

4.1 Input
1     r = pd.Series({
2         'EURUSD': 0.0020,
3         'GBPUSD': -0.0010,
4         'USDJPY': 0.0015,
5         'EURJPY': 0.0030,
6         'GBPJPY': 0.0000,
7         'USDCHF': -0.0005,
8         'EURCHF': 0.0010
9     })

4.2 Generic matrix builder
1     def split_pair(p):
2         return p[:3], p[3:]
3     
4     currencies = sorted(set([c for p in r.index for c in [p[:3], p[3:]]]))
5     ccy_idx = {c:i for i,c in enumerate(currencies)}
6     
7     A = np.zeros((len(r), len(currencies)))
8     
9     for i, p in enumerate(r.index):
10         b, q = split_pair(p)
11         A[i, ccy_idx[b]] = 1
12         A[i, ccy_idx[q]] = -1

4.3 Solve
1     A_aug = np.vstack([A, np.ones(len(currencies))])
2     r_aug = np.append(r.values, 0)
3     
4     s, *_ = np.linalg.lstsq(A_aug, r_aug, rcond=None)
5     s = pd.Series(s, index=currencies)

4.4 Outcome
Now:
strength is cross-validated across multiple pairs
USD effect diluted
more stable ranking
Trade selection:
1     strong = s.idxmax()
2     weak   = s.idxmin()

4.5 Execution
Same as before:
1     trade = {
2         f"{weak}USD": +1,
3         f"{strong}USD": -1
4     }
✅ signal improved
✅ execution unchanged

5. General Case (N currencies)

5.1 Strength function
1     def compute_strength(r):
2         currencies = sorted(set([c for p in r.index for c in [p[:3], p[3:]]]))
3         ccy_idx = {c:i for i,c in enumerate(currencies)}
4     
5         A = np.zeros((len(r), len(currencies)))
6         for i, p in enumerate(r.index):
7             b, q = p[:3], p[3:]
8             A[i, ccy_idx[b]] = 1
9             A[i, ccy_idx[q]] = -1
10     
11         A_aug = np.vstack([A, np.ones(len(currencies))])
12         r_aug = np.append(r.values, 0)
13     
14         s, *_ = np.linalg.lstsq(A_aug, r_aug, rcond=None)
15         return pd.Series(s, index=currencies)

5.2 Trade pipeline
1     s = compute_strength(r)
2     
3     strong = s.idxmax()
4     weak   = s.idxmin()
5     
6     spread = s[weak] - s[strong]

5.3 Entry condition
1     if spread < -0.001:
2         direction = 'long'

5.4 Initial trade
1     trade = {
2         f"{weak}USD": +1,
3         f"{strong}USD": -1
4     }

5.5 Size
1     size = base_size * min(abs(spread) / 0.002, 1.0)

6. Ladder Execution Framework

6.1 State
1     inventory = [
2         {entry_price, size, exit_target}
3     ]

6.2 Entry ladder
Example:
1     Layer 1: 1.000
2     Layer 2: 0.975
3     Layer 3: 0.950
4     Layer 4: 0.925

6.3 Exit (LIFO)
Always:
exit last entry first
Example:
1     entries: [1.00, 0.975, 0.95]
2     
3     spread moves to 0.975
4     → exit 0.95 only

6.4 Skewed exits
Define:
1     entry spacing = Δ_i
2     exit spacing  = Γ_i
with:
1     Γ_i decreasing with depth
Example:

Layer Entry Exit
1     1.00  1.25
2     0.975 1.00
3     0.95  0.975
4     0.925 0.96

6.5 Size tapering
1     sizes = [1.0, 1.0, 0.75, 0.5, 0.25]
Rules:
exit size = last entry size
new adds = decreasing size

7. Backtest Design

7.1 Data
M5 OHLC for each pair
compute rolling 1h returns

7.2 Per-bar loop
For each M5 candle:

Step 1 — compute spread
1     s = compute_strength(r_t)
2     spread = s[min] - s[max]

Step 2 — simulate fills
For LONG spread:
1     if low <= entry_price  → entry filled
2     if high >= exit_price → exit filled

Step 3 — update inventory
entry → push layer
exit → pop last layer

Step 4 — place passive orders
1     if flat:
2         place first entry
3     
4     if in position:
5         place:
6             next entry level
7             exit for last layer

7.3 PnL calculation
Each unwind:
1     PnL += size * (exit − entry)

8. Key Structural Insight
This strategy combines:
Signal layer
cross-sectional FX factor model
relative value selection
Execution layer
passive fill capture
path-dependent inventory
LIFO risk reduction

9. Final Summary
You are building:
A least-squares currency strength model → producing scores → selecting strongest vs weakest → executing via a single FX spread → managing exposure through a passive, skewed, laddered inventory system that monetizes retracements.

If you want next step: I can give you a single-cell backtest (exactly this logic, no abstraction) that you can drop into your notebook.