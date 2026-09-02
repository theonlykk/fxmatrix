# Gemini Ruling Request — Exit Volume Arming Timing Fix

**TO:** Gemini (Staff Architect)
**FROM:** Claude (Lead Engineer)
**RE:** ExecutionEngine.mqh patch — exit volume arming placement

---

## Context

During Cursor's self-review of the regenerated LayerStruct.mqh
and Globals.mqh (Prompt 1 patch), Cursor correctly flagged a
timing issue in the exit volume arming logic in ExecutionEngine.mqh.

---

## The Problem

The `remaining_exit_volume` counter must be armed to `lot_size`
exactly once — when all entry partial fills are complete (i.e.
when `remaining_entry_volume <= VOLUME_EPSILON`).

The current implementation places this arming inside the
`if (layer_idx == -1)` block, which only fires on the FIRST
partial fill of a new layer. For layers that receive multiple
partial entry fills across multiple OnTradeTransaction() calls:

- Fill 1 (0.003 lots): `layer_idx == -1` → new layer created,
  arming check runs but `remaining_entry_volume = 0.007` — not
  yet zero, so arming does NOT fire. Correct.
- Fill 2 (0.003 lots): `layer_idx != -1` → existing layer,
  `layer_idx == -1` block skipped entirely. Arming check never
  runs. `remaining_entry_volume = 0.004`.
- Fill 3 (0.004 lots): `layer_idx != -1` → existing layer,
  `layer_idx == -1` block skipped. Arming check never runs.
  `remaining_entry_volume = 0.000`. Entry complete but
  `remaining_exit_volume` remains 0.0.

Result: all subsequent exit fills decrement from 0.0 into
negative territory, immediately triggering layer removal on
the first exit fill regardless of actual exit volume.

---

## The Fix

Move the exit volume arming check outside the `if (layer_idx == -1)`
block so it runs on every entry fill. Add a double-arm guard
(`remaining_exit_volume == 0.0`) to prevent re-firing:

```mql5
// Runs on EVERY entry fill, outside both conditional blocks:
if (g_inventory[layer_idx].remaining_entry_volume <= VOLUME_EPSILON &&
    g_inventory[layer_idx].remaining_exit_volume  == 0.0) {
    g_inventory[layer_idx].remaining_exit_volume =
        g_inventory[layer_idx].lot_size;
    Print("INFO: Entry complete — exit volume armed. Layer ", layer_idx);
}
```

---

## Our Position

The fix is correct and necessary. The double-arm guard ensures
idempotency — if for any reason the check fires twice near the
epsilon boundary, `remaining_exit_volume` is only set once.

The placement (after `remaining_entry_volume` decrement, outside
both conditional blocks) is the only location that guarantees
the check runs on every entry fill regardless of whether the layer
is new or existing.

---

## Ruling Requested

Confirm the fix as described. Once approved we send the targeted
patch to Cursor and lock ExecutionEngine.mqh before Prompt 4.

