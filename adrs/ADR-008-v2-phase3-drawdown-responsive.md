# ADR-008: V2 Phase 3 — Drawdown-Responsive Market Making Engine

**Date:** 2026-06-12  
**Status:** Accepted  
**Phase:** 3 — Drawdown-Responsive Market Making  
**Repo:** theonlykk/fxmatrix  

---

## Context

Phase 3 implements the drawdown-responsive market making framework. Three levers
work together to prevent rapid layer accumulation while keeping the EA always
active as a liquidity provider:

1. **Dual stress multiplier** — widens grid spacing as layers deepen (leading)
   and as pod P&L bleeds (lagging)
2. **Dynamic lot size reduction** — scales down capital deployed as pod P&L
   bleeds toward the circuit breaker
3. **Sleep interval** — mandatory wait between layer adds to prevent rapid
   sequential fills during microstructure cascades
4. **Gap-aware re-arm pricing** — passive-only pricing when re-arming add_next
   after sleep, capturing gap moves without crossing the spread

Gemini Staff Architect Phase 3 ruling mandates passive-only gap handling (Q4/Q5),
per-instrument sleep/re-arm (Option A deafness preserved), and stress multiplier
isolation from exit geometry.

---

## Decision — Four Levers

### 1. Dual Stress Multiplier (`MathEngine.mqh`)

`ComputeGridInterval(int layer_idx, int instrument = -1)` extended with:

| Component | Formula | Role |
|---|---|---|
| `layer_stress` | `LayerStressBase ^ layer_idx` | Leading — widens immediately on depth |
| `pnl_stress` | `1 + K_spread * (|pod_pnl| / (balance * MaxPodDrawdown))` | Lagging — amplifies as pod bleeds |

**Return:** `base_interval * layer_stress * pnl_stress`

- `instrument = -1` (default): `pnl_stress = 1.0` — backward compatible for exit geometry
- `instrument >= 0`: full dual stress applied on add_next path via `ComputeNextLayerPrice()`
- **Exit geometry unchanged:** `HandleEntryFill()` exit target still calls
  `ComputeGridInterval(layer_idx)` without instrument (per Gemini ruling)

**Inputs:** `LayerStressBase = 1.500`, `K_spread = 1.000`

### 2. Dynamic Lot Sizing (`ExecutionEngine.mqh`)

On new layer creation (Path A):

```
size_mult = max(1 - K_size * (|pod_pnl| / (balance * MaxPodDrawdown)), 0)
lot_size  = max(BaseLotSize * size_mult, SYMBOL_VOLUME_MIN)
```

**Input:** `K_size = 0.500`

### 3. Sleep Interval + Re-arm

**Sleep gate (`HandleEntryFill`):** Before `PlaceNextEntryLimit()`, checks
`TimeCurrent() - g_last_layer_time_X >= MinLayerIntervalSeconds`. If sleep
active, add_next is skipped; OnTick re-arm handles recovery.

**Re-arm (`FXMatrix.mq5` OnTick):** Before Option A deafness `continue`, when
`inst_inv_size > 0 && inst_add_next == 0` and sleep expired:
- Reads deepest layer
- Calls `ComputeNextLayerPrice()` for fresh computed price
- Places via `PlaceNextEntryLimit(deepest, inst_symbol, computed)` with price override

**Globals:** `g_last_layer_time_EURUSD/GBPUSD/EURGBP`  
**Input:** `MinLayerIntervalSeconds = 300` (1 M5 bar)

### 4. Gap-Aware Passive Pricing (`PlaceNextEntryLimit`)

Universal gap handling on all add_next placements:

| Direction | Rule |
|---|---|
| BUY limit | `price = min(computed, current_bid)` |
| SELL limit | `price = max(computed, current_ask)` |

Optional `price_override` parameter allows re-arm to pass fresh computed price
without mutating layer struct. Existing passivity/freeze checks remain as final guard.

---

## Files Changed

| File | Change |
|---|---|
| `Globals.mqh` | Phase 3 inputs + `g_last_layer_time_X` globals |
| `MathEngine.mqh` | Forward decl `GetPodUnrealizedPnL()`, dual stress `ComputeGridInterval()` |
| `ExecutionEngine.mqh` | Gap-aware `PlaceNextEntryLimit()`, sleep gate, dynamic lot sizing |
| `FXMatrix.mq5` | Per-instrument add_next re-arm block in OnTick loop |

### Explicitly Untouched

- `StateEngine.mqh`, `CarryEngine.mqh`, `LayerStruct.mqh`
- `ComputeSkew()`, `ComputeExitSpreadTarget()` — exit geometry unchanged
- `CheckCircuitBreakers()`, `ClosePodPositions()`, `HandleExitFill()`

---

## Failure Modes

| Scenario | Behaviour |
|---|---|
| `GetPodUnrealizedPnL()` cannot select position | Returns partial sum; missing layer skipped |
| `balance <= 0` or `MaxPodDrawdown <= 0` | Stress multiplier skipped; `pnl_stress = 1.0` |
| `ComputeNextLayerPrice()` returns sentinel | Re-arm skips; guard `if (computed > 0.0)` |
| Sleep active after fill | add_next deferred; OnTick re-arm fires when interval elapses |
| Gap moves market through computed level | MathMin/MathMax joins top of book passively |

---

## References

- Gemini Staff Architect Phase 3 ruling (Q4/Q5 gap-aware passive pricing)
- ADR-007: V2 Phase 2 per-instrument state (foundation for per-pod P&L isolation)
- ADR-006: V2 Phase 1 `ComputeGridInterval()` / `ComputeSkew()` parameterisation
