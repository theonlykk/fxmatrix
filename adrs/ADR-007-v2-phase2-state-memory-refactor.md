# ADR-007: V2 Phase 2 — State & Memory Refactor

**Date:** 2026-06-12  
**Status:** Accepted (Phase 2 complete — 2a through 2e)  
**Phase:** 2 — Per-Instrument State & Memory  
**Repo:** theonlykk/fxmatrix  

---

## Context

Phase 2 migrates FXMatrix from a single monolithic inventory to per-instrument
state, enabling layer-aware carry geometry and eventual multi-pod isolation.
The migration followed the **Shadow State pattern** (2a–2d): add new variables
alongside existing ones, route execution to the new arrays, then delete the
legacy globals in Phase 2e (The Guillotine).

Gemini Staff Architect Phase 2 ruling mandates this incremental approach to preserve
Run 52/54 baseline behaviour while building toward structural regime hedging.

---

## Architectural Intent — Structural Regime Hedge, Not Operational Capacity

The multi-pod architecture is built as a **Structural Regime Hedge** across isolated
currency blocs — not for operational capacity or parallel throughput.

Each pod is an independent 3-currency mean-reversion universe with its own matrix,
inventory, and circuit breaker. Pods are designed to decorrelate under different
macro stress regimes, not to run more trades simultaneously.

### Pod Macro Stories

**Pod 1 — EUR / GBP / USD (European G3)**  
The prototype pod. Susceptible to European political shocks and USD rate cycles.
EUR/GBP cross provides direct European dislocation capture; USD leg anchors to
Fed policy regime.

**Pod 2 — AUD / JPY / NZD (Asia-Pacific Carry)**  
Structurally uncorrelated to European stress. JPY safe-haven flows create mean-reversion
opportunities during European shocks while AUD/NZD carry dynamics operate on
independent Asia-Pacific macro drivers.

**Pod 3 — CAD / CHF / JPY (Commodity + Safe Haven)**  
Insulated from USD-specific rate shocks. CAD hedges commodity inflation exposure;
CHF/JPY provide stability during broad liquidations. Decorrelates when Pod 1 is
stressed by USD policy and Pod 2 by risk-off carry unwinds.

---

## Decision — Per-Instrument State (Complete)

### LayerStruct.mqh

Added `layer_index` as the first field in `Layer`:

```mql5
int layer_index;   // 0-based depth; -1 = uninitialised sentinel
```

- Initialised to `-1` in `InitLayer()` — deliberate sentinel forcing visible failure
  if `HandleEntryFill()` omits assignment
- Added to IMMUTABILITY CONTRACT — set once at first fill, never modified elsewhere
- Enables `ComputeSkew(layer.layer_index)` in carry path

### Globals.mqh — Per-Instrument State (Active)

| Variable | Purpose |
|---|---|
| `g_inventory_EURUSD[]` | EURUSD layer inventory |
| `g_inventory_GBPUSD[]` | GBPUSD layer inventory |
| `g_inventory_EURGBP[]` | EURGBP layer inventory |
| `g_pending_entry_EURUSD` | Pre-inventory entry limit ticket |
| `g_pending_entry_GBPUSD` | |
| `g_pending_entry_EURGBP` | |
| `g_add_next_EURUSD` | Defensive add_next limit ticket |
| `g_add_next_GBPUSD` | |
| `g_add_next_EURGBP` | |
| `g_closeby_queue[]` | Shared CloseBy retry queue |

**Deleted in Phase 2e (The Guillotine):** `g_inventory[]`, `g_pending_entry_ticket`,
`g_add_next_ticket`.

---

## Phase Roadmap

| Phase | Scope | Status |
|---|---|---|
| **2a** | Shadow state injection — declarations only | Complete |
| **2b** | Per-instrument `SaveInventoryState(int)`, `LoadInventoryState(int)`, `SaveAllInventoryState()` | Complete |
| **2c** | Execution logic migrates to per-instrument arrays; `layer_index` at fill | Complete |
| **2d** | Per-instrument `OnTick()` loop; nudge block; exit detection fix | Complete |
| **2e** | The Guillotine — delete monolithic globals and legacy no-arg state functions | Complete |

---

## Phase 2e Deletions

| File | Removed |
|---|---|
| `Globals.mqh` | `g_inventory[]`, `g_pending_entry_ticket`, `g_add_next_ticket`, shadow comment blocks |
| `StateEngine.mqh` | `GetStateFilename()` (no-arg), `SaveInventoryState()` (no-arg), `LoadInventoryState()` (no-arg) |
| `ExecutionEngine.mqh` | Order comment labels referencing `ArraySize(g_inventory)` |
| `FXMatrix.mq5` | `GetEntrySymbol()`, `GetEntryDirection()` |

**Retained:** `GetStateFilename(int)`, `SaveInventoryState(int)`, `LoadInventoryState(int)`,
`SaveAllInventoryState()`, `CheckForOrphans()` (updated to scan all three arrays).

**Collateral fix:** `CarryEngine.mqh` `RunCarryRecalculation()` migrated to per-instrument
arrays and `SaveAllInventoryState()` — required for clean compile after guillotine.

---

## Failure Modes

| Scenario | Behaviour |
|---|---|
| `layer_index = -1` in logs | `HandleEntryFill()` failed to set depth at fill — visible sentinel failure |
| Per-instrument arrays uninitialised | Prevented by explicit `ArrayResize(..., 0)` in `InitGlobals()` |
| Orphan position not in any inventory array | `CheckForOrphans()` halts pod |

---

## References

- Gemini Staff Architect ruling: Phase 2 Shadow State pattern
- ADR-006: V2 Phase 1 math engine parameterisation (`ComputeSkew()` carry approximation)
