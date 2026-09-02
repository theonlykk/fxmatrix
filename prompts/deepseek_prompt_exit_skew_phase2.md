# DeepSeek R1 Audit — Exit Skew Phase 2: Geometric Decay + Layer-Decaying Floor
# Role: Adversarial Quantitative Red Team
# Classification: Phase 1 Teardown — No implementation code

---

## YOUR ROLE AND MANDATORY CONSTRAINTS

You are DeepSeek R1, adversarial quantitative red team. Your mandate is
strictly constrained. Before beginning, read and internalise these
boundaries. Violating them will result in your output being rejected.

### What you MUST audit:
- Mathematical correctness of the geometric decay formula
- Floor calculation correctness and stability
- Interaction with carry recalculation
- Edge cases that could cause execution deadlock or degenerate targets
- SkewMode=2 branch isolation (does it affect SkewMode=0/1 behaviour)

### What you are FORBIDDEN from auditing:
- **The 12-bar anchor:** The exit target is always within the 12-bar
  lookback window by construction. The market visited fair value within
  the last 60 minutes. Do NOT model EV using zero-reversion strawman
  scenarios where the market "never reaches" the exit. This assumption
  is physically impossible given the anchor genesis.
- **The transaction cost floor:** `MinLayerExitPoints=30` (3 pips) is
  a hard mathematical lower bound derived from round-trip friction at
  FTMO ECN (~1 pip total). 3x coverage is the minimum viable edge. Do
  NOT challenge the existence or magnitude of this floor.
- **SkewStart=0.618:** Do not challenge this parameter choice.
- **The grid expansion formula:** Out of scope.
- **Alternative implementations:** Do not propose rewrites.
- **ATR or volatility assumptions:** Signal entry spreads are derived
  from currency score dislocations, not ATR. Do not conflate them.

### Execution mode scenario segregation (MANDATORY):
All scenarios must be segregated by execution mode:
- **MARKET_MAKER:** Entry spreads can be as low as BaseThreshold=4 bps
  (Scenarios A, B, C apply)
- **SNIPER:** Entry gate = SniperThreshold=14 bps minimum. Scenario A
  (6 bps) is physically impossible in SNIPER mode. Only Scenarios B
  and C apply to SNIPER.

Output format per audit point: PASS / WARNING / FATAL
Close with: CLEARED FOR GEMINI REVIEW or ABORT

---

## WHAT HAS ALREADY BEEN IMPLEMENTED (Phase 1 + 1.5)

`ComputeExitSpreadTarget()` in MathEngine.mqh is now the Single Source
of Truth for exit geometry (Phase 1.5 routing fix, commit 34c9888):

```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    return layer.entry_spread_adjusted * ComputeSkew(layer.layer_index);
}
```

`ComputeSkew()` currently has two modes with SkewMin upper-bound clamp:
```mql5
double ComputeSkew(int layer_idx) {
    if (SkewMode == 0) {
        return MathMin(SkewStart, 1.0);          // constant 0.618
    }
    else {
        return MathMax(MathMin(SkewStart - layer_idx * SkewStep, 1.0), SkewMin);
    }
}
```

Production instances run SkewMode=0, SkewStart=0.618. These are
unchanged by Phase 2.

---

## PROPOSED PHASE 2 CHANGES

### Change 1 — New inputs in Globals.mqh

```mql5
input double SkewFloor0         = 0.0012; // Floor_0 at Layer 0 (12 bps = 3*QuoteSpread)
input int    MinLayerExitPoints = 30;     // Hard minimum in broker points (3 pips on 5-digit)
```

### Change 2 — Add SkewMode=2 branch to ComputeSkew()

```mql5
double ComputeSkew(int layer_idx) {
    if (SkewMode == 0) {
        return MathMin(SkewStart, 1.0);
    }
    else if (SkewMode == 1) {
        return MathMax(MathMin(SkewStart - layer_idx * SkewStep, 1.0), SkewMin);
    }
    else {
        // SkewMode=2: geometric decay — raw fraction only, no floor here
        // Floor is applied in ComputeExitSpreadTarget()
        double phi = 0.6180339887;
        return MathPow(phi, layer_idx + 1);
    }
}
```

Note: `ComputeSkew()` returns the raw unconstrained fraction for
SkewMode=2. The floor is NOT applied here — it is applied in
`ComputeExitSpreadTarget()` which has access to the full Layer context.

### Change 3 — Update ComputeExitSpreadTarget() to apply floor for SkewMode=2

```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    double raw_skew = ComputeSkew(layer.layer_index);

    if (SkewMode != 2) {
        // SkewMode 0/1: multiplicative, no floor (floor handled by SkewMin clamp)
        return layer.entry_spread_adjusted * raw_skew;
    }

    // SkewMode=2: apply layer-decaying floor
    // Floor_n = max(SkewFloor0 * phi^layer_idx, MinLayerExitPoints * _Point)
    // where _Point is fetched from the instrument's symbol
    string symbol = g_symbols[layer.instrument];
    double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double phi    = 0.6180339887;

    double floor_n = MathMax(
        SkewFloor0 * MathPow(phi, layer.layer_index),
        MinLayerExitPoints * point
    );

    // Convert floor to a skew fraction relative to entry spread
    double abs_entry = MathAbs(layer.entry_spread_adjusted);
    double floor_skew = (abs_entry > 1e-10) ? floor_n / abs_entry : raw_skew;

    // Apply floor: effective skew is max of raw decay and floor fraction
    double effective_skew = MathMax(raw_skew, floor_skew);

    // entry_spread_adjusted is negative; multiply by positive skew
    // Result is negative and closer to zero than entry_spread (exit toward fair value)
    return layer.entry_spread_adjusted * effective_skew;
}
```

---

## THREE-SCENARIO SIMULATION BRACKET

All scenarios use GridExpBase=1.5, GridInflection=2, GridBase=8 bps,
GridLinearStep=2 bps. Entry spreads are cumulative from Layer 0.

Grid intervals (bps): L0=8, L1=10, L2=12, L3=18, L4=27, L5=40.5
(exponential from Layer 2 onward, LDAK dilation applied for Scenario C)

**Scenario A — Low signal (MARKET_MAKER only)**
- Layer 0 entry spread: -6 bps
- No LDAK dilation
- SNIPER: N/A (below SniperThreshold=14 bps)

**Scenario B — Standard signal (MM + SNIPER)**
- Layer 0 entry spread: -10 bps
- Mild LDAK dilation (1.5x from Layer 2)
- SNIPER: eligible (above 14 bps threshold? Layer 0 at 10 bps is below
  threshold for SNIPER. SNIPER only enters when signal > 14 bps, so
  SNIPER Scenario B should use Layer 0 = 14 bps minimum)

**Scenario C — Stress / dislocation (MM + SNIPER)**
- Layer 0 entry spread: -20 bps
- Full LDAK dilation: 3.0x from Layer 2
- SNIPER: eligible

For each scenario compute per layer (0 through 5):
- Cumulative entry spread (bps)
- Raw decay: `0.618^(n+1) * |entry_spread_n|` (bps)
- Floor_n: `max(12 * 0.618^n, 30 * 0.00001 * 10000)` = `max(12 * 0.618^n, 3)` bps
- Effective exit target: `max(raw_decay, floor_n)` bps
- Whether effective target > broker freeze level (1 bps / 10 points)

---

## AUDIT POINTS

### AUDIT POINT 1 — SkewMode=2 branch isolation

Verify that adding the `SkewMode=2` branch to `ComputeSkew()` does not
alter the return values for `SkewMode=0` and `SkewMode=1` under any
input combination. The existing if/else chain must be provably unchanged.

Also verify that `ComputeExitSpreadTarget()` correctly routes SkewMode=0
and SkewMode=1 through the simple multiplicative path (no floor applied),
and only SkewMode=2 through the floor logic.

### AUDIT POINT 2 — Geometric decay series correctness

Verify `MathPow(0.6180339887, layer_idx + 1)` produces the correct
Fibonacci retracement fractions:
- Layer 0: 0.6180 (61.8%) ✓
- Layer 1: 0.3820 (38.2%) ✓
- Layer 2: 0.2361 (23.6%) ✓
- Layer 3: 0.1459 (14.6%) ✓
- Layer 4: 0.0902 (9.0%) ✓
- Layer 5: 0.0557 (5.6%) ✓

Verify double precision is sufficient for layer_idx up to MaxLayers=20.
At Layer 20: `0.618^21 ≈ 4.1e-5`. Is this above DBL_EPSILON for
realistic entry spreads?

### AUDIT POINT 3 — Layer-decaying floor correctness

For the floor formula:
```
Floor_n = max(SkewFloor0 * phi^layer_idx, MinLayerExitPoints * point)
```

Note: `phi^layer_idx` not `phi^(layer_idx+1)` — the floor decays one
power slower than the skew. This is intentional: at Layer 0, floor =
`max(SkewFloor0, MinPoints*point)` = `max(12 bps, 3 bps)` = 12 bps,
while raw skew produces `0.618 * entry_spread`. For the floor to be
non-binding at Layer 0 for Scenario C (20 bps entry), raw target must
exceed floor: `0.618 * 20 = 12.36 bps > 12 bps`. Verify this boundary.

For Scenario A (6 bps entry, Layer 0): raw = `0.618 * 6 = 3.71 bps`,
floor = 12 bps. Floor dominates. Effective exit = 12 bps. This means
Layer 0 exits at 12 bps regardless of signal magnitude when signal < ~20
bps. Is this acceptable for MARKET_MAKER? (Note: SNIPER never sees < 14
bps so this only affects MM.)

Compute the floor activation crossover: at what Layer 0 entry spread
magnitude does the raw decay exactly equal the floor at Layer 0?
`raw = floor` → `0.618 * S = 12 bps` → `S = 19.4 bps`

So for MM entry spreads below 19.4 bps, Layer 0 floor dominates. For
spreads above 19.4 bps, raw decay is active. Report whether this is
a concern.

### AUDIT POINT 4 — Sign and magnitude invariants

For SkewMode=2, verify that `ComputeExitSpreadTarget()` always returns
a value satisfying:
```
entry_spread_adjusted < exit_target < 0
```

Given:
- `entry_spread_adjusted` < 0 (always negative)
- `effective_skew` > 0 (raw decay is positive, floor is positive)
- Result = `entry_spread_adjusted * effective_skew`
- Since effective_skew ≤ 1 always? Wait — can `floor_skew > 1`?

`floor_skew = floor_n / abs_entry`. If `floor_n > abs_entry`, then
`floor_skew > 1`, and `effective_skew > 1`, giving exit_target more
negative than entry_spread. This can happen when:
- Entry spread is very small (e.g., 3 bps) and floor_n = 12 bps
- Then floor_skew = 12/3 = 4.0, exit_target = -0.0003 * 4.0 = -0.0012

Is this a problem? In this case, exit_target = -12 bps which is actually
the floor price — the EA would need 12 bps of reversion to exit. That
is larger than the entry spread (3 bps), meaning the EA entered at 3 bps
dislocation but now needs 12 bps to exit — it can never profit. This is
a structural EV problem for very shallow entries in MARKET_MAKER mode.

Verify: does this pathological case occur in production? With
BaseThreshold=4 bps and QuoteSpread=4 bps, what is the minimum realistic
entry spread for MARKET_MAKER? If minimum MM entry is ~4-8 bps and
floor is 12 bps, does this affect all MM entries below 19.4 bps?

### AUDIT POINT 5 — Carry recalculation interaction

After carry recalculation, `RunCarryRecalculation()` updates
`layer.entry_spread_adjusted` and then calls `ComputeExitSpreadTarget(L)`.

For SkewMode=2, `ComputeExitSpreadTarget()` uses both
`layer.entry_spread_adjusted` AND `layer.layer_index`. Verify:

1. After carry widens the spread (more negative entry_spread_adjusted),
   does the multiplicative formula correctly widen the exit target
   proportionally?
2. After carry, if entry_spread_adjusted approaches zero (carry nearly
   offsets dislocation), does the `abs_entry > 1e-10` guard prevent
   division by zero in the floor_skew computation?
3. Can carry make entry_spread_adjusted positive? If so, what does
   `entry_spread_adjusted * effective_skew` produce? Is a positive
   exit_target handled correctly by `InvertSpreadToPrice()`?

### AUDIT POINT 6 — SkewMode=2 with SkewMode=0/1 in parallel instances

The EA runs two instances simultaneously (MM and SNIPER). Each instance
sets `SkewMode` independently via input parameters. If MM runs
`SkewMode=0` and SNIPER runs `SkewMode=2`, do they share any global
state that could cause interference?

Verify: `SkewFloor0` and `MinLayerExitPoints` are declared as `input`
in Globals.mqh. In MQL5, `input` parameters are per-instance — each
EA instance has its own copy. Confirm there is no global (non-input)
variable shared between instances that would be written by
`ComputeExitSpreadTarget()` in SkewMode=2 but read by the other instance.

### AUDIT POINT 7 — Simulation table verification

Using the three-scenario bracket, produce the complete layer-by-layer
table for Scenario B (10 bps entry, mild LDAK) and Scenario C (20 bps
entry, full LDAK dilation 3.0x), showing:

| Layer | Entry spread (bps) | Raw decay (bps) | Floor_n (bps) | Effective exit (bps) | Above freeze? |
|-------|--------------------|-----------------|---------------|---------------------|---------------|

For Scenario A (MARKET_MAKER only, 6 bps entry), show just Layer 0-3
and note that SNIPER does not apply.

Confirm that no effective exit target falls below 1 bps (broker freeze
level) at any layer for any scenario.

---

## SELF-CONSISTENCY CHECK

Before concluding, verify:

1. The floor decays as `SkewFloor0 * phi^n` — at Layer 5, floor =
   `12 * 0.618^5 = 12 * 0.0902 = 1.08 bps`. The hard minimum
   `MinLayerExitPoints * point = 3 bps` catches this. So effective
   hard floor is 3 bps from Layer 4 onward. Confirm.

2. For Scenario C at Layer 5 (342.5 bps cumulative entry spread):
   raw decay = `0.0557 * 342.5 = 19.1 bps`. Floor = 3 bps.
   Effective = 19.1 bps. Well above freeze. Confirm.

3. The SkewMode=2 branch in ComputeSkew() has NO side effects — it
   only reads `layer_idx` and returns a double. Confirm.

---

Line count: 333
