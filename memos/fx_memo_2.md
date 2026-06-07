Below is a clean, desk-style memo with concrete code blocks—minimal but precise, exactly mapping:
data → matrix → scores → signal → trade → sizing
I’ll show it for 3 currencies, then scale to 5, then generalize.

Currency Strength Mean Reversion — Implementation Memo (with Code)

1. Core Idea Recap
We observe FX returns and assume:
1     pair return ≈ base_strength − quote_strength
We solve:
1     A * s = r
A = currency incidence matrix
s = currency strengths
r = observed pair returns
Constraint:
1     sum(s) = 0

2. Case 1 — 3 Currencies (USD, EUR, GBP)
Step 1 — Inputs (returns over 1 hour)
1     import numpy as np
2     import pandas as pd
3     
4     r = pd.Series({
5         'EURUSD': 0.0020,
6         'GBPUSD': -0.0010
7     })

Step 2 — Build matrix
Currencies:
1     EUR, GBP, USD
System:
1     EUR − USD = r_EURUSD  
2     GBP − USD = r_GBPUSD
Matrix:
1     currencies = ['EUR', 'GBP', 'USD']
2     ccy_idx = {c:i for i,c in enumerate(currencies)}
3     
4     A = np.zeros((2,3))
5     A[0, ccy_idx['EUR']] = 1
6     A[0, ccy_idx['USD']] = -1
7     
8     A[1, ccy_idx['GBP']] = 1
9     A[1, ccy_idx['USD']] = -1

Step 3 — Solve with constraint
1     A_aug = np.vstack([A, np.ones(3)])
2     r_aug = np.append(r.values, 0)
3     
4     s, *_ = np.linalg.lstsq(A_aug, r_aug, rcond=None)
5     s = pd.Series(s, index=currencies)

Step 4 — Scores
Example result:
1     EUR: +0.0015  
2     GBP: -0.0005  
3     USD: -0.0010
Interpretation:
EUR strongest
GBP weakest

Step 5 — Trade Decision
1     strong = EUR  
2     weak   = GBP
Trade:
1     LONG GBP vs SHORT EUR
Execution:
1     trade = {
2         'GBPUSD': +1,
3         'EURUSD': -1
4     }

Step 6 — Initial Sizing
Base size:
1     base_size = 1.0
2     position = {k: v * base_size for k,v in trade.items()}

3. Case 2 — 5 Currencies (USD, EUR, GBP, JPY, CHF)
Now we use more pairs → better conditioning.

Step 1 — Returns
1     r = pd.Series({
2         'EURUSD': 0.0020,
3         'GBPUSD': -0.0010,
4         'USDJPY': 0.0015,
5         'EURJPY': 0.0030,
6         'GBPJPY': 0.0000,
7         'USDCHF': -0.0005,
8         'EURCHF': 0.0010
9     })

Step 2 — Build matrix (generic)
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

Step 3 — Solve
1     A_aug = np.vstack([A, np.ones(len(currencies))])
2     r_aug = np.append(r.values, 0)
3     
4     s, *_ = np.linalg.lstsq(A_aug, r_aug, rcond=None)
5     s = pd.Series(s, index=currencies)

Step 4 — Scores
Now you get:
1     EUR: strong across JPY, USD, CHF  
2     GBP: weak across system  
3     USD: neutral  
4     JPY/CHF: mixed
✅ Much more robust than 3-ccy case

Step 5 — Trade
1     strong = s.idxmax()
2     weak   = s.idxmin()
Example:
1     strong = EUR  
2     weak   = GBP

Step 6 — Execution mapping
Prefer direct cross if liquid:
1     GBP/EUR
Else:
1     trade = {
2         'GBPUSD': +1,
3         'EURUSD': -1
4     }

Step 7 — Initial Position Size (better)
Scale by signal strength:
1     spread = s[weak] - s[strong]
2     size = abs(spread)
Optional scaling:
1     size = min(size / 0.002, 1.0)   # normalize

4. General Case — N Currencies

Full pipeline in one block
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

Trade selection
1     s = compute_strength(r)
2     
3     strong = s.idxmax()
4     weak   = s.idxmin()
5     
6     spread = s[weak] - s[strong]

Entry rule
1     threshold = -0.001
2     
3     if spread < threshold:
4         direction = 'long'
5     else:
6         direction = None

Initial trade construction
1     if direction == 'long':
2         trade = {
3             f"{weak}USD": +1,
4             f"{strong}USD": -1
5         }

Initial size
1     base_size = 1.0
2     signal_strength = abs(spread)
3     
4     size = base_size * min(signal_strength / 0.002, 1.0)

5. Linking to Your Ladder
Once initial trade is placed:
You maintain:
1     inventory = [
2         {'entry': spread, 'size': size}
3     ]
Next levels:
1     delta = 0.025  # or vol-scaled
2     
3     next_entry = spread - delta
Exit for last layer:
1     exit = entry + gamma   # gamma shrink with depth

6. Key Structural Differences as You Scale

Feature       3 Currencies 5+ Currencies
Signal        noisy        stable
USD effect    dominant     diluted
Trade freq    high         lower
Edge quality  weak         stronger
Ladder stress high         lower

7. Final Practical Recommendation
Use 5–7 currencies to compute s
Still trade 1 spread (strong vs weak)
Size initial trade using:
Ladder:
taper size
skew exits

One-line summary
You are building:
A least-squares FX factor model → generating currency scores → selecting extreme spread → expressing it as a tradable cross → executing via passive laddered inventory.

If you want next step, I’ll give you:
a single-cell backtest loop that plugs this signal into your ladder + passive fills (no abstractions, deterministic).