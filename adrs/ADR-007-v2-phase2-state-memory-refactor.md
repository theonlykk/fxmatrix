# ADR-007: V2 Phase 2 — State & Memory Refactor (Shadow State)

**Date:** 2026-06-12  
**Status:** Accepted (Phase 2a)  
**Phase:** 2a — Shadow State Injection  
**Repo:** theonlykk/fxmatrix  

---

## Context

Phase 2 migrates FXMatrix from a single monolithic inventory to per-instrument
shadow state, enabling layer-aware carry geometry and eventual multi-pod isolation.
Phase 2a follows the **Shadow State pattern**: add new variables alongside existing
ones without deleting or modifying anything currently in use. Execution logic is
completely untouched until Phase 2c.

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

## Decision — Phase 2a Shadow State Additions

### LayerStruct.mqh

Added `layer_index` as the first field in `Layer`:

```mql5
int layer_index;   // 0-based depth; -1 = uninitialised sentinel
```

- Initialised to `-1` in `InitLayer()` — deliberate sentinel forcing visible failure
  if `HandleEntryFill()` omits assignment (Phase 2b)
- Added to IMMUTABILITY CONTRACT — set once at first fill, never modified elsewhere
- Enables `ComputeSkew(layer.layer_index)` in carry path (Phase 2b one-line patch)

### Globals.mqh — Per-Instrument Shadow State

| Shadow Variable | Replaces (Phase 2c+) | Guillotine (Phase 2e) |
|---|---|---|
| `g_inventory_EURUSD[]` | `g_inventory[]` | Delete monolithic |
| `g_inventory_GBPUSD[]` | | |
| `g_inventory_EURGBP[]` | | |
| `g_pending_entry_EURUSD` | `g_pending_entry_ticket` | Delete monolithic |
| `g_pending_entry_GBPUSD` | | |
| `g_pending_entry_EURGBP` | | |
| `g_add_next_EURUSD` | `g_add_next_ticket` | Delete monolithic |
| `g_add_next_GBPUSD` | | |
| `g_add_next_EURGBP` | | |

All shadow arrays explicitly initialised to size 0 in `InitGlobals()`.

**Existing globals preserved unchanged** — `g_inventory[]`, `g_pending_entry_ticket`,
`g_add_next_ticket` remain active until Phase 2e (The Guillotine).

---

## Phase Roadmap

| Phase | Scope |
|---|---|
| **2a** (this patch) | Shadow state injection — declarations only |
| 2b | `layer_index` assignment in `HandleEntryFill()`; carry path `ComputeSkew()` fix |
| 2c | Execution logic migrates to per-instrument shadow state |
| 2d | State persistence for per-instrument arrays |
| 2e | The Guillotine — delete monolithic globals |

---

## Failure Modes

| Scenario | Behaviour |
|---|---|
| `layer_index = -1` in logs | `HandleEntryFill()` failed to set depth at fill — visible sentinel failure |
| Shadow arrays uninitialised | Prevented by explicit `ArrayResize(..., 0)` in `InitGlobals()` |
| Premature shadow state use | No execution logic references shadow variables until Phase 2c — inert |

---

## Scope (Phase 2a Only)

| File | Change |
|---|---|
| `LayerStruct.mqh` | `layer_index` field, `InitLayer()` init, immutability contract |
| `Globals.mqh` | Per-instrument shadow globals, `InitGlobals()` array init |

### Explicitly Untouched

`FXMatrix.mqh`, `StateEngine.mqh`, `MathEngine.mqh`, `CarryEngine.mqh`,
`ExecutionEngine.mqh` — no changes in Phase 2a.

---

## References

- Gemini Staff Architect ruling: Phase 2 Shadow State pattern
- ADR-006: V2 Phase 1 math engine parameterisation (`ComputeSkew()` carry approximation)
