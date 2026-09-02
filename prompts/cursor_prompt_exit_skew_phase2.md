# Cursor Implementation Prompt — Exit Skew Phase 2
# Scope: Globals.mqh + MathEngine.mqh only
# Gemini cleared — no additional DeepSeek audit required
# This message has a line count at the bottom.

---

## MANDATORY FIRST STEP

Before making any edits, confirm the following anchor line numbers from
the CURRENT files on disk. Report each line number back before proceeding.
Do NOT begin editing until all anchors are confirmed.

**Globals.mqh — confirm line numbers of:**
1. `input double SkewStart` line
2. `input double SkewStep` line
3. `input double SkewMin` line
4. `input int    SkewMode` line (or `input double SkewMode` — confirm type)

**MathEngine.mqh — confirm line numbers of:**
5. `double ComputeSkew(int layer_idx) {`
6. `return MathMin(SkewStart, 1.0);` — SkewMode 0 branch
7. `return MathMax(MathMin(SkewStart - layer_idx * SkewStep, 1.0), SkewMin);` — SkewMode 1
8. `double ComputeExitSpreadTarget(const Layer &layer) {`
9. `return layer.entry_spread_adjusted * ComputeSkew(layer.layer_index);`

---

## CONTEXT

Phase 1 and Phase 1.5 are complete (commits bc5a2f1 and 34c9888).
`ComputeExitSpreadTarget()` is the Single Source of Truth for exit
geometry. `ComputeSkew()` returns a clean fraction. All paths route
through `ComputeExitSpreadTarget()`.

This prompt introduces `SkewMode=2`: geometric decay using the golden
ratio, with a layer-decaying floor and a 0.99 ceiling.

**Operational deployment (Gemini ruling — binding):**
- MM instance:     SkewMode=0 (unchanged, constant 0.618)
- SNIPER instance: SkewMode=2 (geometric decay)

SkewMode=0 and SkewMode=1 behaviour is UNCHANGED by this prompt.

---

## ARCHITECTURAL SPEC (Gemini-approved)

### SkewMode=2 geometry

Raw decay fraction per layer:
```
skew_n = phi^(layer_idx + 1)   where phi = 0.6180339887
```

Layer-decaying floor in ComputeExitSpreadTarget():
```
Floor_n = max(SkewFloor0 * phi^layer_idx, MinLayerExitPoints * _Point)
```

Floor is applied as a skew fraction:
```
floor_skew = floor_n / abs(entry_spread_adjusted)
effective_skew = max(raw_skew, floor_skew)
```

0.99 ceiling enforces exit < entry invariant:
```
effective_skew = min(effective_skew, 0.99)
```

Final exit target:
```
exit_target = entry_spread_adjusted * effective_skew
```

This guarantees: `entry_spread_adjusted < exit_target < 0` always.

---

## CHANGE 1 — Globals.mqh: add two new inputs

ADD the following two inputs immediately after the existing `SkewMin`
input line. Do not remove or modify any existing inputs.

```mql5
input double SkewFloor0         = 0.0012; // ADR-025 Ph2: Floor_0 at Layer 0 (12 bps = 3×QuoteSpread)
input int    MinLayerExitPoints = 30;     // ADR-025 Ph2: Hard minimum exit distance in broker points (30 pts = 3 pips)
```

---

## CHANGE 2 — MathEngine.mqh: add SkewMode=2 branch to ComputeSkew()

REPLACE the entire `ComputeSkew()` function:
```mql5
double ComputeSkew(int layer_idx) {
    // ADR-025 Phase 1.5: clamp skew to (0, 1.0] to guarantee
    // exit_target = entry_spread * skew is always closer to zero
    // than entry_spread. skew > 1 would invert the exit geometry.
    if (SkewMode == 0) {
        return MathMin(SkewStart, 1.0);
    }
    else {
        return MathMax(MathMin(SkewStart - layer_idx * SkewStep, 1.0), SkewMin);
    }
}
```
WITH:
```mql5
double ComputeSkew(int layer_idx) {
    if (SkewMode == 0) {
        // Constant fraction — MM production default
        return MathMin(SkewStart, 1.0);
    }
    else if (SkewMode == 1) {
        // Linear decrease per layer, floored at SkewMin
        return MathMax(MathMin(SkewStart - layer_idx * SkewStep, 1.0), SkewMin);
    }
    else {
        // ADR-025 Phase 2: geometric decay — raw fraction only
        // Floor and 0.99 ceiling applied in ComputeExitSpreadTarget()
        // phi = golden ratio conjugate = 0.618...
        double phi = 0.6180339887;
        return MathPow(phi, layer_idx + 1);
    }
}
```

Note: SkewMode=2 is the `else` branch — any value other than 0 or 1
activates geometric decay. This is intentional for forward compatibility.

---

## CHANGE 3 — MathEngine.mqh: update ComputeExitSpreadTarget() for SkewMode=2

REPLACE the entire `ComputeExitSpreadTarget()` function:
```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    // ADR-025 Phase 1: multiplicative exit spread target.
    // exit_target = entry_spread_adjusted * skew_fraction
    // where skew_fraction = ComputeSkew(layer_index).
    //
    // With production defaults (SkewMode=0, SkewStart=0.618):
    //   exit_target = entry_spread_adjusted * 0.618
    //
    // entry_spread_adjusted is negative (weakest - strongest < 0).
    // skew fraction is positive (0 < skew <= 1).
    // exit_target is therefore negative, closer to zero than entry_spread.
    // InvertSpreadToPrice() uses this to place the exit limit between
    // current price and fair value.
    //
    // Phase 2 (geometric decay): ComputeSkew() will be updated to
    // return 0.618^(layer_index+1) with a layer-decaying floor.
    // No changes needed here — the multiplicative form is already correct.
    return layer.entry_spread_adjusted * ComputeSkew(layer.layer_index);
}
```
WITH:
```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    // ADR-025 Phase 2: multiplicative exit spread target with
    // optional layer-decaying floor for SkewMode=2.
    //
    // entry_spread_adjusted is always negative (weakest - strongest < 0).
    // Invariant enforced: entry_spread_adjusted < exit_target < 0
    //   i.e., exit is always closer to zero (fair value) than entry.

    double raw_skew = ComputeSkew(layer.layer_index);

    if (SkewMode != 2) {
        // SkewMode 0/1: simple multiplicative — floor handled by SkewMin clamp
        return layer.entry_spread_adjusted * raw_skew;
    }

    // SkewMode=2: apply layer-decaying floor and 0.99 ceiling
    // Floor_n = max(SkewFloor0 * phi^layer_idx, MinLayerExitPoints * _Point)
    // phi^layer_idx decays the floor in lockstep with the skew geometry
    double phi     = 0.6180339887;
    string symbol  = g_symbols[layer.instrument];
    double pt      = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double floor_n = MathMax(
        SkewFloor0 * MathPow(phi, layer.layer_index),
        MinLayerExitPoints * pt
    );

    // Convert floor to a skew fraction relative to entry spread magnitude
    double abs_entry   = MathAbs(layer.entry_spread_adjusted);
    double floor_skew  = (abs_entry > 1e-10) ? floor_n / abs_entry : raw_skew;

    // Effective skew: max of raw decay and floor fraction
    // Cap at 0.99 to guarantee exit strictly closer to zero than entry
    // (prevents exit being placed beyond entry when floor > abs_entry)
    double effective_skew = MathMin(MathMax(raw_skew, floor_skew), 0.99);

    // entry_spread_adjusted is negative; result is negative and
    // closer to zero than entry_spread_adjusted (invariant satisfied)
    return layer.entry_spread_adjusted * effective_skew;
}
```

---

## WHAT NOT TO TOUCH

- Do NOT modify any other function in MathEngine.mqh
- Do NOT modify ExecutionEngine.mqh, CarryEngine.mqh, StateEngine.mqh,
  FXMatrix.mq5, TelemetryEngine.mqh, LayerStruct.mqh
- Do NOT remove or modify existing Globals.mqh inputs
- Do NOT change SkewStart, SkewStep, SkewMin, SkewMode defaults

---

## SELF-REVIEW CHECKLIST

Before responding, verify every item:

- [ ] Anchor line numbers confirmed before any edit
- [ ] Globals.mqh: SkewFloor0 and MinLayerExitPoints added after SkewMin
- [ ] Globals.mqh: no existing inputs removed or modified
- [ ] ComputeSkew(): SkewMode=0 branch UNCHANGED
- [ ] ComputeSkew(): SkewMode=1 branch UNCHANGED (now explicit else if)
- [ ] ComputeSkew(): SkewMode=2 (else) returns MathPow(phi, layer_idx+1)
- [ ] ComputeExitSpreadTarget(): SkewMode!=2 path returns simple multiply
- [ ] ComputeExitSpreadTarget(): SkewMode=2 path computes floor_n using
      SkewFloor0 * phi^layer_index and MinLayerExitPoints * point
- [ ] ComputeExitSpreadTarget(): effective_skew clamped with MathMin(..., 0.99)
- [ ] ComputeExitSpreadTarget(): uses g_symbols[layer.instrument] for symbol
- [ ] No other files modified
- [ ] F7 compile produces ZERO errors and ZERO warnings

---

## REGRESSION VERIFICATION

After F7, verify the mathematical chain for three cases:

**Case 1 — SkewMode=0 unchanged (MM production)**
entry_spread_adjusted = -0.0010, SkewMode=0, SkewStart=0.618:
- ComputeSkew(0) → MathMin(0.618, 1.0) → 0.618
- ComputeExitSpreadTarget: SkewMode!=2 → -0.0010 * 0.618 = **-0.000618** ✓

**Case 2 — SkewMode=2, deep layer, floor inactive**
entry_spread_adjusted = -0.0020 (20 bps), layer_index=0, SkewMode=2:
- raw_skew = 0.618^1 = 0.618
- floor_n = max(0.0012 * 1.0, 30 * 0.00001) = max(0.0012, 0.0003) = 0.0012
- floor_skew = 0.0012 / 0.0020 = 0.60
- effective_skew = min(max(0.618, 0.60), 0.99) = min(0.618, 0.99) = **0.618**
- exit_target = -0.0020 * 0.618 = **-0.001236** (raw decay active) ✓

**Case 3 — SkewMode=2, shallow entry, floor active, 0.99 cap**
entry_spread_adjusted = -0.0006 (6 bps), layer_index=0, SkewMode=2:
- raw_skew = 0.618^1 = 0.618
- floor_n = max(0.0012, 0.0003) = 0.0012
- floor_skew = 0.0012 / 0.0006 = 2.00
- effective_skew = min(max(0.618, 2.00), 0.99) = min(2.00, 0.99) = **0.99**
- exit_target = -0.0006 * 0.99 = **-0.000594** (scratch trade, invariant preserved) ✓

Report all three computed values in your response.

---

Line count: 263
