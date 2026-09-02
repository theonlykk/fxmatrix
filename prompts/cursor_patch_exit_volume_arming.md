# Cursor Patch — ExecutionEngine.mqh (Exit Volume Arming Fix)

One targeted fix required in `d:\fxmatrix\ea\ExecutionEngine.mqh`.

## The Problem

The current implementation arms `remaining_exit_volume = lot_size`
inside the `if (layer_idx == -1)` block — i.e. only on the first
partial fill when the new Layer is created. But a layer may receive
multiple partial entry fills across multiple OnTradeTransaction()
calls. The `layer_idx == -1` block only fires once (first fill).
Subsequent entry fills route to the existing layer via
`layer_idx != -1`. If the final entry fill that drives
`remaining_entry_volume` to zero arrives on a subsequent call,
the exit volume arming never fires, leaving `remaining_exit_volume`
at 0.0 permanently. All exit fills will then decrement from 0.0
into negative territory and trigger immediate layer removal.

## The Fix

Remove the exit volume arming from inside the `if (layer_idx == -1)`
block. Add it after the `remaining_entry_volume` decrement, outside
both the new-layer and existing-layer blocks, so it runs on EVERY
entry fill:

### Remove this block from inside `if (layer_idx == -1)`:

```mql5
        // When entry fully filled, arm exit volume counter
        if (g_inventory[layer_idx].remaining_entry_volume <= VOLUME_EPSILON)
            g_inventory[layer_idx].remaining_exit_volume =
                g_inventory[layer_idx].lot_size;
```

### Add this block immediately after the `remaining_entry_volume`
decrement line (outside both the new-layer and existing-layer blocks):

```mql5
    // Arm exit volume counter when entry is fully filled.
    // Runs on every entry fill — not just the first.
    // Double-arm guard: only fires once when crossing zero.
    if (g_inventory[layer_idx].remaining_entry_volume <= VOLUME_EPSILON &&
        g_inventory[layer_idx].remaining_exit_volume  == 0.0) {
        g_inventory[layer_idx].remaining_exit_volume =
            g_inventory[layer_idx].lot_size;
        Print("INFO: Entry complete — exit volume armed. Layer ",
              layer_idx);
    }
```

## Negative Space

Do NOT change anything else in `ExecutionEngine.mqh`.
Do NOT modify LayerStruct.mqh, Globals.mqh, or MathEngine.mqh.
This is a targeted block relocation only.

## Self-Review

Confirm:
1. Exit volume arming block is NO LONGER inside `if (layer_idx == -1)`
2. Exit volume arming block IS present after `remaining_entry_volume`
   decrement, outside both conditional blocks
3. Double-arm guard (`remaining_exit_volume == 0.0`) is present
4. No other changes made to the file

Line count: 57
