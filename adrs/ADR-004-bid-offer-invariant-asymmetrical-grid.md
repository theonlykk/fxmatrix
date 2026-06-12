# ADR-004: Bid/Offer Invariant + Asymmetrical Grid Spacing

**Date:** 2026-06-12  
**Status:** Accepted  
**Patch:** 12  
**Repo:** theonlykk/fxmatrix  

---

## Context

Patch 12 implements two architectural changes ratified by Gemini (Staff Architect) across two separate ruling sessions. Both changes tighten the separation between pre-inventory signal management and in-pod defensive layering, and replace symmetric threshold-step spacing with an asymmetrical spread-based formula.

---

## Decision 1 — Separate `g_add_next_ticket` Global (Gemini Session 1)

### Problem

`PlaceNextEntryLimit()` previously wrote to `g_pending_entry_ticket`, conflating two semantically distinct pending orders:

| Ticket global | Purpose | Active when |
|---|---|---|
| `g_pending_entry_ticket` | Pre-inventory entry limit (plain-matrix signal) | `ArraySize(g_inventory) == 0` |
| `g_add_next_ticket` | Defensive add_next limit (next layer) | `ArraySize(g_inventory) > 0` |

When `CancelAllPendingEntries()` ran on pod teardown or pre-entry cleanup, it could cancel the protected add_next order because both ticket types shared one global.

### Ruling (Gemini Session 1)

- Introduce `g_add_next_ticket` as a dedicated global in `Globals.mqh`.
- `PlaceNextEntryLimit()` is the **only** write site for `g_add_next_ticket`.
- `g_pending_entry_ticket` must never be written in `PlaceNextEntryLimit()`.
- `CancelAllPendingEntries()` skips `g_add_next_ticket` with `continue` (not `break`).
- `g_add_next_ticket` is cleared when the pod goes fully flat in `HandleExitFill()`, before `CancelAllPendingEntries()`.
- `SaveInventoryState()` / `LoadInventoryState()` persist and restore `add_next_ticket` alongside `pending_entry_ticket`.

### Bid/Offer Invariant

At all times while inventory is open:

```
|add_next - entry| > |exit - entry|
```

The add_next limit must sit further from the entry price than the exit target. Separating ticket globals ensures teardown logic cannot accidentally cancel the defensive add_next order while still cleaning up orphaned pre-entry limits.

---

## Decision 2 — Asymmetrical Grid Spacing (Gemini Session 2)

### Problem

`ComputeNextLayerPrice()` used a differential threshold-step approach (`BaseThreshold + n * ThresholdStep`). This produced symmetric spacing relative to threshold bands, not relative to the actual signal magnitude at fill time. Spacing was decoupled from the layer's realised dislocation (`entry_spread_raw`).

### Ruling (Gemini Session 2)

Replace threshold-step differential spacing with Khalid's asymmetrical formula, locking spacing to the layer's actual entry spread:

```
S = |entry_spread_raw|                              (always positive)
exit     = entry + S * ExitFraction                 (closer to entry)
add_next = entry - S - S * (1 - ExitFraction)       (further from entry)
```

Where `ExitFraction` is layer-adjusted via `ExitFractionStep` and floored at `ExitFractionMin`.

Properties:

- `S` is derived from the filling layer's `entry_spread_raw`, not global `ThresholdStep`.
- `add_next_spread` is computed in spread space, then inverted to a broker price via `InvertSpreadToPrice()`.
- Exit geometry is unchanged — `ComputeExitPrice()` via `exit_spread_target` in `HandleEntryFill()` is not modified.
- Sentinel `-1.0` on zero `entry_spread_raw` or failed inversion; existing `HandleEntryFill()` guard skips `PlaceNextEntryLimit()`.

### Bid/Offer Invariant (reaffirmed)

The formula guarantees `|add_next - entry| > |exit - entry|` in spread space because the add_next offset subtracts `S + S*(1-ExitFraction)` while the exit offset adds only `S * ExitFraction`, with `ExitFraction < 1`.

---

## Decision 3 — Signal Rotation Deaf While Pod Open (Gemini Session 1, Option A)

### Problem

Signal rotation and plain-matrix entry logic ran on every new bar regardless of inventory state. A pod with open layers could rotate or place new pre-inventory limits while defensive layering was active.

### Ruling (Gemini Session 1, Option A)

Wrap both the rotation block (`g_pending_entry_ticket > 0`) and the plain-matrix entry block (`g_signal_active && g_pending_entry_ticket == 0`) inside:

```mql5
if (ArraySize(g_inventory) == 0) { ... }
```

`RunSignalOnBarClose()` continues on every bar for analytics. Only execution-side rotation and new entry placement are suppressed while the pod is open. The nudge block is unaffected.

---

## Files Changed

| File | Changes |
|---|---|
| `Globals.mqh` | Add `g_add_next_ticket` |
| `ExecutionEngine.mqh` | `PlaceNextEntryLimit()` ticket write; `HandleExitFill()` clear; `ComputeNextLayerPrice()` formula + signature |
| `FXMatrix.mq5` | `CancelAllPendingEntries()` skip guard; `OnTick()` inventory guard |
| `StateEngine.mqh` | Persist/restore `add_next_ticket` |

## Files Explicitly Untouched

`LayerStruct.mqh`, `MathEngine.mqh`, `CarryEngine.mqh`, `PlaceEntryLimit()`, `CancelAllPending()` (circuit breaker), nudge block, `CheckForOrphans()`, exit_spread_target computation.

---

## Failure Modes

| Scenario | Behaviour |
|---|---|
| `PlaceNextEntryLimit()` OrderSend fails | Early return 0; `g_add_next_ticket` stays 0 |
| `ComputeNextLayerPrice()` returns -1.0 | `add_next = 0.0`; `PlaceNextEntryLimit()` skipped |
| `entry_spread_raw == 0` at fill | `S <= 0` guard returns -1.0; handled by sentinel guard |

---

## References

- Gemini Staff Architect ruling session 1: separate `g_add_next_ticket`, Option A signal deafness
- Gemini Staff Architect ruling session 2: Khalid's asymmetrical spacing formula and bid/offer invariant
