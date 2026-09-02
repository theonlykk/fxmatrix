# FXMatrix Phase 0 — DeepSeek R1 Red Team Audit
# Grid Geometry & Signal Inversion Verification

## ROLE

You are a ruthless quantitative auditor. Your job is to find mathematical errors,
sign errors, directional errors, and subtle biases in the FXMatrix EA grid geometry.
Assume every formula is wrong until proven correct. Do not write implementation code.
Do not suggest architectural changes. Only audit the math.

---

## WHAT FXMATRIX IS

FXMatrix is a native MQL5 EA implementing a 3-currency mean-reversion strategy on
EUR/GBP/USD. It decomposes EURUSD and GBPUSD log-returns into tri-currency scores
and trades the pair showing the greatest dislocation from its mean.

Signal decomposition:
```
r_EU = log(EURUSD_now / EU_h)      # EU_h = EURUSD mid 12 bars (1 hour) ago
r_GB = log(GBPUSD_now / GB_h)      # GB_h = GBPUSD mid 12 bars (1 hour) ago
usd  = -(r_EU + r_GB) / 3
eur  =   r_EU + usd
gbp  =   r_GB + usd
spread = scores[weakest] - scores[strongest]   # always <= 0 for valid signal
```

Signal fires when |spread| > BaseThreshold (0.0004 = 4bps).
6 routings: EURUSD BUY/SELL, GBPUSD BUY/SELL, EURGBP BUY/SELL.

---

## PHASE 0 GRID GEOMETRY (AUDIT TARGET)

The following formulas were implemented in Phase 0. Verify each one.

### Formula 1 — Exit spread target (HandleEntryFill in ExecutionEngine.mqh)

```
L.exit_spread_target = L.entry_spread_adjusted + GridBase * layer_exit_frac
```

Where:
- `entry_spread_adjusted` is always negative (it is a spread = weakest - strongest)
- `GridBase = 0.0008` (8bps, always positive)
- `layer_exit_frac = MathMax(ExitFraction - layer_idx * ExitFractionStep, ExitFractionMin)`
- `ExitFraction = 0.618`, `ExitFractionStep = 0.0`, `ExitFractionMin = 0.40`
- So `layer_exit_frac = 0.618` for all layers (graduation disabled)

**Questions:**
1. Is `exit_spread_target` always less negative than `entry_spread_adjusted`? 
   (i.e. does it correctly move toward zero — the direction of mean reversion?)
2. Is there any case where `exit_spread_target` could be MORE negative than
   `entry_spread_adjusted`? (This would mean we exit at a deeper dislocation —
   locking in a loss.)
3. Is there any case where `exit_spread_target` could be positive?
   (This would mean we exit past fair value — still profitable but geometrically wrong.)

### Formula 2 — add_next spread (ComputeNextLayerPrice in ExecutionEngine.mqh)

```
double entry_spread = g_inventory[next_layer_idx - 1].entry_spread_raw;
double add_next_spread = entry_spread - S - S * (1.0 - layer_exit_frac);
```

Where:
- `entry_spread` is always negative
- `S = GridBase = 0.0008` (always positive)
- `layer_exit_frac = 0.618`
- So: `add_next_spread = entry_spread - 0.0008 - 0.0008 * 0.382`
                       `= entry_spread - 0.0008 - 0.000306`
                       `= entry_spread - 0.001106`

**Questions:**
1. Is `add_next_spread` always more negative than `entry_spread`?
   (It must be — add_next fires at a deeper dislocation than entry.)
2. Verify the core invariant algebraically:
   `|add_next_spread - entry_spread| > |exit_spread_target - entry_spread|`
   i.e. `S + S*(1-skew) > S*skew`
   i.e. `1 + (1-skew) > skew`
   i.e. `2 - skew > skew`
   i.e. `skew < 1.0`
   Is this always satisfied for valid ExitFraction values (0 < ExitFraction < 1)?
3. Is there any edge case where the invariant fails?

### Formula 3 — CarryEngine exit spread target (ComputeExitSpreadTarget in MathEngine.mqh)

```
return layer.entry_spread_adjusted + GridBase * ExitFraction;
```

This is called daily at 17:00 by CarryEngine to update exit targets after carry
adjustment. Note: this uses `ExitFraction` directly (no graduation), whereas
`HandleEntryFill` uses `layer_exit_frac` (which equals `ExitFraction` when
`ExitFractionStep = 0.0`).

**Questions:**
1. Are these two formulas consistent when `ExitFractionStep = 0.0`?
2. If `ExitFractionStep > 0.0` (graduation enabled in future), will the carry
   recalc path produce a different exit target than the fill-time path for layers
   beyond Layer 0? Is this a latent bug?
3. After carry adjustment, `entry_spread_adjusted` changes. Does the formula
   correctly recompute the exit target relative to the NEW adjusted spread,
   or relative to the original entry spread?

### Formula 4 — Anchor computation (MathEngine.mqh)

```
g_EU_mid_12bars_ago = CopyClose bid + live half-spread correction
```

The signal uses prices from 12 bars (1 hour) ago as anchors for log-return
computation. These anchors are used both for signal generation AND for
InvertSpreadToPrice() to compute entry/exit/add_next prices.

**Questions:**
1. Are the anchors genuinely from 12 bars ago at signal computation time,
   or is there an off-by-one that uses the current bar's close?
2. When InvertSpreadToPrice() is called at FILL TIME (inside HandleEntryFill),
   does it use the anchors from the moment of the fill, or from the most recent
   bar close? Could these be stale if the fill happens mid-bar?
3. Is there any mechanism by which future price information could leak into
   the anchor computation?

### Formula 5 — InvertSpreadToPrice directionality

The signal spread is always negative. InvertSpreadToPrice() takes a target
spread T and returns a physical broker price. The locked formulas are:

```
EURUSD BUY  (strongest=USD=2, weakest=EUR=0): anchor_EU * MathExp(T)
EURUSD SELL (strongest=EUR=0, weakest=USD=2): anchor_EU * MathExp(-T)
GBPUSD BUY  (strongest=USD=2, weakest=GBP=1): anchor_GB * MathExp(T)
GBPUSD SELL (strongest=GBP=1, weakest=USD=2): anchor_GB * MathExp(-T)
EURGBP BUY  (strongest=GBP=1, weakest=EUR=0): EG_hist * MathExp(T)
EURGBP SELL (strongest=EUR=0, weakest=GBP=1): EG_hist * MathExp(-T)
```

Where T is always negative for valid signals.

**Questions:**
1. For a EURUSD BUY: T is negative, so MathExp(T) < 1, so price = anchor_EU * MathExp(T)
   < anchor_EU. Is this correct? (BUY limit should be BELOW current market.)
2. For a EURUSD SELL: T is negative, -T is positive, so MathExp(-T) > 1, so price
   = anchor_EU * MathExp(-T) > anchor_EU. Is this correct? (SELL limit should be
   ABOVE current market.)
3. For add_next on a EURUSD BUY: add_next_spread is MORE negative than entry_spread.
   So T_add_next < T_entry < 0. Therefore MathExp(T_add_next) < MathExp(T_entry).
   So add_next_price < entry_price. Is this correct? (add_next BUY limit should be
   BELOW entry price.)
4. For add_next on a EURUSD SELL: add_next_spread is MORE negative than entry_spread.
   T_add_next is more negative, so -T_add_next is more positive, so
   MathExp(-T_add_next) > MathExp(-T_entry). So add_next_price > entry_price.
   Is this correct? (add_next SELL limit should be ABOVE entry price — deeper
   dislocation means higher price for a SELL.)
5. Verify the same directional logic for EURGBP BUY and EURGBP SELL.

---

## WHAT TO LOOK FOR

1. **Sign errors** — any formula where adding/subtracting produces movement in
   the wrong direction
2. **Off-by-one in anchor computation** — bar index errors that could introduce
   look-ahead
3. **Formula inconsistency between fill path and carry path** — particularly
   dangerous because it would cause exit targets to drift silently over time
4. **Invariant violations** — any case where add_next fires before exit
5. **Edge cases** — very small entry_spread_raw, ExitFraction near 0 or 1,
   GridBase set to an extreme value

---

## WHAT NOT TO DO

- Do not suggest architectural changes
- Do not comment on the Highlander Rule or multi-pod architecture
- Do not write MQL5 code
- Do not audit files not shown here
- Do not hallucinate function signatures — work only from what is shown above

---

## OUTPUT FORMAT

For each formula, state:
1. PASS or FAIL
2. The algebraic proof or counterexample
3. If FAIL: the exact condition under which it fails and the direction of the error

Be concise. Flag only genuine mathematical issues, not stylistic concerns.
