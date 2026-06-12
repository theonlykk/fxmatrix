# ADR-005: Phase 0 Interim Grid Interval Fix (Run 51 Baseline Restore)

**Date:** 2026-06-12  
**Status:** Accepted (Interim)  
**Phase:** 0  
**Repo:** theonlykk/fxmatrix  

---

## Context

Run 50 regressed vs Run 49 after Patch 12 introduced asymmetrical grid spacing that used `entry_spread_raw` as the grid interval S. `entry_spread_raw` is the total signal dislocation at fill time (typically 50–600 bps), not the intended grid spacing (~8 bps). This placed `add_next` levels 80–150 pips from entry, which never triggered.

The same magnitude error affected `exit_spread_target` in `HandleEntryFill()`, which was computed as `entry_spread_adjusted * (1.0 - layer_exit_frac)` — again scaling off raw signal magnitude rather than a fixed grid interval.

---

## Decision (Gemini Phase 0 Directive)

Restore Run 51 baseline behaviour by introducing a fixed grid interval input `GridBase` and using it as S for **both** exit and add_next geometry.

### Grid Interval

```
S = GridBase   (default 0.0008 = 8 bps)
```

`entry_spread_raw` remains the ledger record of signal magnitude at fill. It is **not** the grid interval.

### Exit Geometry

```
exit_spread_target = entry_spread_adjusted + GridBase * layer_exit_frac
```

`entry_spread_adjusted` is negative; adding a positive `GridBase * layer_exit_frac` moves toward zero (correct exit direction). `ComputeExitPrice()` in `MathEngine.mqh` is unchanged — it inverts `exit_spread_target` as before.

### Add-Next Geometry

```
add_next_spread = entry_spread - S - S * (1.0 - layer_exit_frac)
```

Where `entry_spread` is retrieved from `g_inventory[next_layer_idx - 1].entry_spread_raw` (the layer just filled).

### Bid/Offer Invariant (Preserved)

```
|add_next - entry| > |exit - entry|   always
```

Both legs use the same S = `GridBase`, preserving the asymmetrical spacing invariant from ADR-004 without coupling spacing to signal magnitude.

### ExitFraction Default

`ExitFraction` default updated from 0.70 to 0.618 (Fibonacci golden ratio) per Phase 0 directive.

---

## Scope

| File | Change |
|---|---|
| `Globals.mqh` | Add `GridBase` input; update `ExitFraction` default |
| `ExecutionEngine.mqh` | Fix `ComputeNextLayerPrice()` and `exit_spread_target` in `HandleEntryFill()` |

### Explicitly Untouched

`FXMatrix.mq5`, `StateEngine.mqh`, `LayerStruct.mqh`, `MathEngine.mqh`, `CarryEngine.mqh`, `g_add_next_ticket`, `CancelAllPendingEntries()`, OnTick inventory guard.

---

## Interim Status — Pending V2

This is a **Phase 0 interim fix**, not the final grid architecture. V2 will introduce full parameterised grid spacing (linear / exponential / hybrid). `GridBase` is a single scalar placeholder until that work lands.

---

## Failure Modes

| Scenario | Behaviour |
|---|---|
| `GridBase <= 0` | `ComputeNextLayerPrice()` returns -1.0; sentinel guard skips layering |
| `InvertSpreadToPrice()` sentinel | Existing `HandleEntryFill()` guard sets `add_next = 0.0` |
| `exit_spread_target` exceeds zero (carry edge case) | `ComputeExitPrice()` sentinel; marketable reversion handler fires (unchanged) |

---

## References

- Gemini Staff Architect ruling: Phase 0 directive (Run 51 baseline restore)
- ADR-004: bid/offer invariant + asymmetrical grid spacing (superseded for interval S only)
