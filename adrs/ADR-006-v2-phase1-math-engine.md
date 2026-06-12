# ADR-006: V2 Phase 1 — Math Engine Parameterisation

**Date:** 2026-06-12  
**Status:** Accepted  
**Phase:** 1  
**Repo:** theonlykk/fxmatrix  

---

## Context

Phase 0 established the Run 52 canonical baseline (+$205, PF 7.08, Sharpe 5.48, Max DD 0.32%)
using fixed `GridBase=0.0008` and `ExitFraction=0.618`. Phase 1 parameterises the math engine
for V2 without changing behaviour at default settings. Run 54 must reproduce Run 52 exactly.

DeepSeek audit clearance confirmed the refactor scope. Gemini Staff Architect issued the V2
Phase 1 ruling governing parameter names, function boundaries, and carry-path approximation.

---

## Decision — Parameter Rename and Function Extraction

### ExitFraction → Skew

| Old (Phase 0) | New (Phase 1) |
|---|---|
| `ExitFraction` | `SkewStart` |
| `ExitFractionStep` | `SkewStep` |
| `ExitFractionMin` | `SkewMin` |

New `SkewMode` input: `0` = constant (`SkewStart`), `1` = linear decrease floored at `SkewMin`.

### Grid Interval Parameterisation

| Input | Purpose |
|---|---|
| `GridMode` | `0` constant, `1` linear, `2` hybrid |
| `GridBase` | Base interval S (8 bps default) |
| `GridLinearStep` | Per-layer linear increment |
| `GridInflection` | Layer where hybrid switches to exponential |
| `GridExpBase` | Exponential multiplier (hybrid mode, must be > 1.0) |

### New Functions (`MathEngine.mqh`)

**`ComputeGridInterval(layer_idx)`** — returns S for a given layer:
- Mode 0: `GridBase`
- Mode 1: `GridBase + layer_idx * GridLinearStep`
- Mode 2: linear to `GridInflection`, then `S_at_inflection * GridExpBase^(layer_idx - GridInflection)`

**`ComputeSkew(layer_idx)`** — returns capture fraction:
- Mode 0: `SkewStart`
- Mode 1: `max(SkewStart - layer_idx * SkewStep, SkewMin)`

### Geometry Formulas (Unchanged at Default Settings)

```
exit_spread_target = entry_spread_adjusted + S * skew
add_next_spread    = entry_spread - S - S * (1.0 - skew)
```

Where `S = ComputeGridInterval(layer_idx)` and `skew = ComputeSkew(layer_idx)`.

Bid/offer invariant `|add_next - entry| > |exit - entry|` holds for all `skew < 1`.

---

## Carry Path Approximation (Gemini Option B)

`ComputeExitSpreadTarget()` uses `ComputeSkew(0)` as a safe approximation because
`layer_index` is not yet in `LayerStruct` (deferred to Phase 2).

```mql5
return layer.entry_spread_adjusted + GridBase * ComputeSkew(0);
```

When `SkewStep=0` (default), `ComputeSkew(0) == ComputeSkew(N)` for all N — mathematically
identical to Phase 0. Phase 2 one-line patch: replace `0` with `layer.layer_index`.

`GridBase` is used directly (not `ComputeGridInterval(0)`) in the carry path — equivalent
when `GridMode=0`.

---

## Run 54 Validation Settings

```
GridMode          = 0
GridBase          = 0.0008
GridLinearStep    = 0.0002
GridInflection    = 2
GridExpBase       = 1.500
SkewMode          = 0
SkewStart         = 0.618
SkewStep          = 0.000
SkewMin           = 0.050
BaseLotSize       = 0.02
RotationThreshold = 0.0002
```

Victory condition: metrics match Run 52 within rounding (P&L ≈ +$205, PF ≈ 7.08,
Sharpe ≈ 5.48, Max DD ≈ 0.32%, Trades ≈ 357).

---

## Scope

| File | Change |
|---|---|
| `Globals.mqh` | Skew/grid inputs; `InitGlobals()` validation |
| `MathEngine.mqh` | `ComputeGridInterval()`, `ComputeSkew()`, `ComputeExitSpreadTarget()` |
| `ExecutionEngine.mqh` | `ComputeNextLayerPrice()`, `HandleEntryFill()` exit geometry |

### Explicitly Untouched

`FXMatrix.mq5`, `StateEngine.mqh`, `LayerStruct.mqh`, `CarryEngine.mqh`,
`ComputeExitPrice()`, `InvertSpreadToPrice()`, `g_add_next_ticket`, OnTick inventory guard.

### Deferred to Phase 2

- `layer_index` field in `LayerStruct`
- Carry path layer-aware skew via `ComputeSkew(layer.layer_index)`

---

## References

- Gemini Staff Architect ruling: V2 Phase 1 parameterisation
- DeepSeek audit clearance: Phase 1 refactor scope
- ADR-005: Phase 0 GridBase interim fix (superseded for parameter names)
