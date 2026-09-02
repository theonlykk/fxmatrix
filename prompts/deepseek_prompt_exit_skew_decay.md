# DeepSeek R1 Audit — FXMatrix Exit Skew Geometric Decay
# Role: Adversarial Quantitative Red Team
# Classification: Phase 1 Teardown — No implementation code

---

## YOUR ROLE

You are DeepSeek R1, the adversarial quantitative red team for the FXMatrix
EA project. Your job is to tear apart the proposed geometric exit skew decay
looking for fatal flaws. You are NOT here to be helpful. You are here to
find the poison pills.

Hunt for:
- Mathematical edge cases where the decay formula produces invalid or
  degenerate exit targets
- Execution deadlocks from compressed exit limits
- Perverse LIFO incentive structures
- EV-negative carry accumulation scenarios
- Floor specification failures on non-standard pip instruments (JPY crosses)
- Any condition where the proposal makes the matrix worse, not better

Output format per audit point: PASS / WARNING / FATAL
Close with: CLEARED FOR GEMINI REVIEW or ABORT

---

## SYSTEM CONTEXT

FXMatrix is a native MQL5 Expert Advisor implementing always-on two-sided
passive market making across a 3-currency triad. The EA places passive limit
orders on mean-reversion signals derived from currency strength decomposition.
When price moves against the EA, layers are added at geometrically wider
intervals. Positions are unwound LIFO — deepest layer exits first.

The EA runs on FTMO funded demo accounts ($10,000, 1:30 leverage).
Current production parameters relevant to this audit:
- BaseLotSize = 0.01
- QuoteSpread = 0.0004 (4 bps)
- BaseThreshold = 0.0004 (4 bps)
- GridBase = 0.0008 (8 bps)
- GridMode = 2 (hybrid exponential)
- GridExpBase = 1.500
- GridInflection = 2 (exponential kicks in after layer 2)
- GridLinearStep = 0.0002
- SkewStart = 0.618 (current, constant across all layers)
- SkewMode = 0 (current, constant — no layer-dependent adjustment)
- LDAK_Dilation_Max = 3.0
- MaxLayers = 20
- MinFillThreshold = 0.500

---

## CURRENT EXIT TARGET ARCHITECTURE (V2 BASELINE)

### Grid expansion — how layers are spaced

The grid interval for layer n is computed in ComputeGridInterval():
```
For n < GridInflection (n=0,1):  linear spacing
  interval_n = GridBase + n * GridLinearStep

For n >= GridInflection (n=2,3,...):  exponential spacing
  interval_n = GridBase + (GridInflection * GridLinearStep)
               + GridBase * (GridExpBase^(n - GridInflection) - 1)
```

With current params (GridBase=0.0008, GridLinearStep=0.0002,
GridExpBase=1.5, GridInflection=2):
- Layer 0: interval = 0.0008 (8 bps from fair value)
- Layer 1: interval = 0.0010 (10 bps from fair value)
- Layer 2: interval = 0.0012 (12 bps, exp starts)
- Layer 3: interval = 0.0020 (20 bps)
- Layer 4: interval = 0.0032 (32 bps)
- Layer 5: interval = 0.0050 (50 bps)

LDAK dilation multiplies the interval by up to 3.0x in high-correlation
high-volatility regimes. So in the stress case, Layer 5 could be at
~150 bps from fair value.

### Current exit target (constant skew)

For a layer with entry_spread S (negative — spread = weakest - strongest):
```
exit_spread_target = S * SkewStart * CarryAdjustment
```

With SkewStart=0.618 and no carry, exit target = 0.618 * |S|.
This is constant across ALL layers.

### LIFO unwind sequence

Layer N (deepest) exits first. The exit limit is placed at:
```
exit_price = InvertSpreadToPrice(anchor_A, anchor_B,
                                  r_AC, r_BC,
                                  exit_spread_target,
                                  strongest, weakest,
                                  is_exit=true)
```

The exit spread target is stored per-layer at fill time and used to
compute the exit price on each bar close.

---

## PROPOSED CHANGE: GEOMETRIC EXIT SKEW DECAY

### The proposal

Replace the constant `SkewStart` fraction with a layer-depth-dependent
geometric decay using the golden ratio as the decay factor:

```
skew_n = 0.618^(n+1)

Layer 0: 0.618^1 = 0.6180  (61.8% of entry spread)
Layer 1: 0.618^2 = 0.3820  (38.2% of entry spread)
Layer 2: 0.618^3 = 0.2361  (23.6% of entry spread)
Layer 3: 0.618^4 = 0.1459  (14.6% of entry spread)
Layer 4: 0.618^5 = 0.0902  (9.0% of entry spread)
Layer 5: 0.618^6 = 0.0557  (5.6% of entry spread)
```

### Floor specification (Gemini-mandated, broker-agnostic)

```mql5
input int MinLayerExitPoints = 30;  // 3.0 pips as integer points

// At compute time:
double pip_floor = MinLayerExitPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
double exit_floor = MathMax(3.0 * QuoteSpread, pip_floor);
double skew_n = MathMax(0.618^(n+1), exit_floor / MathAbs(entry_spread));
```

The floor is applied as a fraction of the entry spread, not as an absolute
price distance, so it integrates cleanly into the existing spread-space
mathematics.

**JPY scaling note (Gemini catch):** Using `MinLayerExitPoints * _Point`
rather than a hardcoded raw double prevents catastrophic failure on JPY
crosses where `_Point = 0.001` not `0.00001`.

### Motivation

The current constant skew forces deeper layers to wait for the same
proportional reversion as shallow layers, despite being at larger absolute
dislocations. At Layer 3-4, the EA is carrying maximum exposure. The
geometric decay transitions the deep layer strategy from macro mean-reversion
holding to micro-scalping of local volatility, generating realised cash flow
when unrealised drawdown is highest.

---

## THREE-SCENARIO SIMULATION BRACKET

Gemini has mandated DeepSeek model the decay across these three scenarios,
all using GridExpBase=1.5, down to Layer 5+:

**Scenario A — Conservative (Low Volatility)**
- Initial entry spread (Layer 0): -6 bps (-0.0006)
- Grid expansion: 1.5x exponential from GridInflection=2
- No LDAK dilation (vratio ≈ 1.0)

**Scenario B — Base Case (Standard Volatility)**
- Initial entry spread (Layer 0): -10 bps (-0.0010)
- Grid expansion: 1.5x exponential from GridInflection=2
- Mild LDAK dilation (vratio ≈ 1.5, dilation ≈ 1.5x)

**Scenario C — Stress Case (Dislocation / LDAK Active)**
- Initial entry spread (Layer 0): -20 bps (-0.0020)
- Grid expansion: 1.5x exponential from GridInflection=2
- Full LDAK dilation (LDAK_Dilation_Max = 3.0)

For each scenario, compute:
1. The entry spread at each layer (entry_spread_n = entry_spread_0 scaled
   by grid expansion)
2. The raw decay target: `skew_n * entry_spread_n`
3. Whether the floor kicks in (raw target < floor)
4. The resulting exit target in bps and pips
5. Whether the exit target is above SYMBOL_TRADE_STOPS_LEVEL (assume
   10 points for FTMO broker)

---

## AUDIT POINTS

### AUDIT POINT 1 — Decay formula mathematical validity

Verify the `0.618^(n+1)` series converges correctly and produces the
claimed Fibonacci retracement levels at each layer. Confirm:
- Layer 0: 61.8% ✓
- Layer 1: 38.2% ✓
- Layer 2: 23.6% ✓
- Layer 3: 14.6% ✓
- Layer 4: 9.0% ✓
- Layer 5: 5.6% ✓

Are these values exact Fibonacci ratios or approximations? Does floating
point precision matter at these magnitudes in MQL5 double arithmetic?

### AUDIT POINT 2 — Floor transition point analysis

For each of the three scenarios, at which layer n does the floor first
activate? Compute explicitly:

```
raw_target_n = 0.618^(n+1) * |entry_spread_n|
floor = MathMax(3.0 * QuoteSpread, 30 * _Point)
       = MathMax(0.0012, 0.00030)
       = 0.0012 (12 bps) on 5-decimal pairs
```

Note: `QuoteSpread = 0.0004`, so `3.0 * QuoteSpread = 0.0012`.
`30 * _Point = 30 * 0.00001 = 0.00030` on standard 5-decimal pairs.
Therefore floor = 0.0012 (12 bps) dominates on standard pairs.

Is 12 bps an appropriate floor? At 12 bps exit target with 4 bps
QuoteSpread, the net capture is ~8 bps before commission. On 0.01 lot
EURGBP, 8 bps ≈ $0.07 gross. Is this positive EV after commission?

### AUDIT POINT 3 — SYMBOL_TRADE_STOPS_LEVEL deadlock check

MQL5 brokers enforce a minimum distance between pending order price and
current market price (`SYMBOL_TRADE_STOPS_LEVEL`). If the exit limit is
placed closer than this distance, the OrderSend returns retcode=10016
(Invalid Stops) and the exit never places.

For each scenario at the floor-activation layer:
- What is the exit limit price distance in points?
- Does it exceed a typical FTMO stop level (assume 10 points minimum)?
- At what layer depth does the compressed exit target risk hitting the
  stop level freeze zone?

### AUDIT POINT 4 — JPY cross scaling validation

The floor uses `MinLayerExitPoints * SymbolInfoDouble(symbol, SYMBOL_POINT)`.

For a JPY cross (e.g. AUDJPY where `_Point = 0.001`):
- `30 * 0.001 = 0.030` (3 pips in JPY terms) ✓
- `3.0 * QuoteSpread = 3.0 * 0.0004 = 0.0012` — but 0.0012 on a JPY
  cross is only 0.12 pips, far below viable.

Does the `MathMax(3.0 * QuoteSpread, pip_floor)` expression correctly
select the JPY pip floor? Or does QuoteSpread need to also be expressed
in symbol-native points for the comparison to be valid?

Specifically: should QuoteSpread be stored in points
(`QuoteSpread / _Point`) rather than raw price delta for the floor
comparison to work correctly across all triads?

### AUDIT POINT 5 — LIFO interaction and carry EV model

The LIFO sequence exits Layer N first. With geometric decay:
- Layer 0 requires 61.8% reversion to exit
- Layer N requires floor% reversion to exit

Model the following 30-day structural dislocation scenario for Scenario C:
- Layer 0 entered at -20 bps
- Layers 1-4 added at geometrically wider intervals
- Market oscillates ±5 bps around Layer 3 price for 30 days (no macro
  reversion to Layer 0 entry price)

Questions:
1. How many times does the geometric decay allow Layers 3-4 to cycle
   (enter/exit) during the 30-day oscillation?
2. What is the approximate realised PnL from the deep layer cycling?
3. What is the approximate swap cost on Layer 0 over 30 days at current
   ESTR/SOFR/SONIA rates?
4. Does the realised PnL from deep layer cycling exceed the swap cost
   of the stranded Layer 0? If not, at what oscillation frequency does
   it break even?
5. Is there a degenerate case where the floor is so tight that Layer N
   triggers on every bar close, creating excessive API calls and
   potential FTMO hyperactivity flag?

### AUDIT POINT 6 — Interaction with carry recalculation

The carry engine (`RunCarryRecalculation()`) periodically adjusts the
`exit_spread_target` stored in each Layer based on interest rate
differentials. The carry adjustment modifies the exit target in-place.

With geometric decay, the exit target for Layer N is already compressed
to near-floor levels. If carry recalculation further compresses or
expands this target, can it push the exit below the floor or above the
Layer 0 target?

Specifically:
- Can carry push a floor-level Layer N exit target BELOW the floor?
  (i.e., carry adjustment applied after floor clamping, bypassing floor)
- Can carry push a deep layer exit target ABOVE the Layer 0 exit target,
  inverting the intended decay order?

### AUDIT POINT 7 — MaxLayers interaction

With MaxLayers=20 and decay `0.618^(n+1)`:
- Layer 19: `0.618^20 = 0.618^20`

Compute `0.618^20`. If this is below machine epsilon for the entry spread
magnitudes in Scenario A, the decay produces a numerically zero exit
target before the floor activates. Verify the floor catches this and
does not produce a zero or negative exit target at extreme layer depths.

---

## WHAT YOU MUST NOT AUDIT

- Do not re-audit ADR-024 V3 architecture — that is complete and validated
- Do not propose implementation code
- Do not audit the grid expansion formula itself — only its interaction
  with the proposed exit decay
- Do not re-litigate the LIFO unwind order — that is an architectural
  constant

---

## OUTPUT FORMAT

For each audit point 1-7:
  Label: AUDIT POINT N
  Finding: PASS / WARNING / FATAL
  Reasoning: [adversarial analysis with explicit numerical examples]
  If WARNING or FATAL: Required fix before implementation proceeds

Include the three-scenario simulation table showing layer-by-layer
decay targets, floor activation points, and pip distances.

Close with overall verdict:
  CLEARED FOR GEMINI REVIEW
  or
  ABORT — [reason]
