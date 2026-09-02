# Cursor Patch — ExecutionEngine.mqh (Layer 0 Inheritance Fix)
# Gemini Ruling: 2026-06-08
# Root cause: Layer N+ fills read live g_XX globals which may have
#             rotated since Layer 0 filled. Layer N must inherit
#             immutable pod state from Layer 0, not live globals.

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## File to patch
`d:\fxmatrix\ea\ExecutionEngine.mqh`

## Do NOT modify any other file.

---

## The bug

In HandleEntryFill(), when a new Layer is created (layer_idx == -1),
the immutable anchor and routing fields are always read from live
globals (g_strongest, g_weakest, g_EU_mid_12bars_ago etc.).

For Layer 0 this is correct — it captures the signal that triggered
the pod.

For Layer 1, 2, 3, 4 this is wrong — the globals may have been
overwritten by new M5 bar computations in the hours or days between
when the entry limit was PLACED and when it FILLS. This causes
Layers 1+ to use wrong routing and wrong anchors, producing exit
prices in the wrong instrument range (~1.15 EURUSD for GBPUSD orders).

## The fix

Fork the immutable field assignment based on whether inventory is
empty (Layer 0) or populated (Layer N+). Layer N+ inherits from
g_inventory[0] — the canonical pod anchor.

---

## Change — Replace immutable field assignment in HandleEntryFill()

Find this block inside the `if (layer_idx == -1)` section:

### BEFORE:
```mql5
        L.entry_price                = deal_price;
        L.entry_spread_raw           = g_entry_spread;
        L.entry_spread_adjusted      = g_entry_spread;  // starts = raw
        L.entry_time                 = deal_time;
        L.EU_mid_12bars_ago_at_entry = g_EU_mid_12bars_ago;
        L.GB_mid_12bars_ago_at_entry = g_GB_mid_12bars_ago;
        L.r_EU_at_entry              = g_r_EU_signal;
        L.r_GB_at_entry              = g_r_GB_signal;
        L.strongest_at_entry         = g_strongest;
        L.weakest_at_entry           = g_weakest;
```

### AFTER:
```mql5
        L.entry_price  = deal_price;
        L.entry_time   = deal_time;

        if (ArraySize(g_inventory) == 0) {
            // --- LAYER 0: Capture live global signal state ---
            // This is the canonical pod anchor. All subsequent
            // layers will inherit from this layer.
            L.EU_mid_12bars_ago_at_entry = g_EU_mid_12bars_ago;
            L.GB_mid_12bars_ago_at_entry = g_GB_mid_12bars_ago;
            L.r_EU_at_entry              = g_r_EU_signal;
            L.r_GB_at_entry              = g_r_GB_signal;
            L.strongest_at_entry         = g_strongest;
            L.weakest_at_entry           = g_weakest;
            L.entry_price_eurusd_1h      = g_EU_mid_12bars_ago;
            L.entry_price_gbpusd_1h      = g_GB_mid_12bars_ago;
            L.entry_spread_raw           = g_entry_spread;
            L.entry_spread_adjusted      = g_entry_spread;
        } else {
            // --- LAYER 1+: Inherit immutable pod state from Layer 0 ---
            // g_XX globals may have rotated since Layer 0 filled.
            // All layers in a pod must share the same anchors and
            // routing as Layer 0 to compute correct exit prices.
            L.EU_mid_12bars_ago_at_entry = g_inventory[0].EU_mid_12bars_ago_at_entry;
            L.GB_mid_12bars_ago_at_entry = g_inventory[0].GB_mid_12bars_ago_at_entry;
            L.r_EU_at_entry              = g_inventory[0].r_EU_at_entry;
            L.r_GB_at_entry              = g_inventory[0].r_GB_at_entry;
            L.strongest_at_entry         = g_inventory[0].strongest_at_entry;
            L.weakest_at_entry           = g_inventory[0].weakest_at_entry;
            L.entry_price_eurusd_1h      = g_inventory[0].entry_price_eurusd_1h;
            L.entry_price_gbpusd_1h      = g_inventory[0].entry_price_gbpusd_1h;
            L.entry_spread_raw           = g_inventory[0].entry_spread_raw;
            L.entry_spread_adjusted      = g_inventory[0].entry_spread_adjusted;
        }
```

## Important: live spot prices still fetched for carry inputs

The `entry_price_eurusd` and `entry_price_gbpusd` fields (the actual
spot prices at fill time, used for carry forward price calculation)
must continue to use live SYMBOL_ASK/SYMBOL_BID mid-prices for each
layer fill. Do NOT inherit these from Layer 0 — each layer filled at
a different time and its carry calculation needs its own spot prices.

Confirm the existing code that fetches live eu_ask/eu_bid/gb_ask/gb_bid
and sets L.entry_price_eurusd and L.entry_price_gbpusd is OUTSIDE
the if/else block and remains unchanged.

---

## Negative Space

- Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
  CarryEngine.mqh, or FXMatrix.mq5
- Do NOT change the CloseBy intercept logic
- Do NOT change HandleExitFill()
- Do NOT change PlaceExitLimit() or PlaceEntryLimit()
- This is a targeted change to the immutable field assignment
  block inside HandleEntryFill() only

---

## Self-Review

Before submitting:
1. Confirm Layer 0 (ArraySize(g_inventory) == 0) reads from
   live g_XX globals for all anchor/routing fields
2. Confirm Layer 1+ (ArraySize(g_inventory) > 0) inherits
   all anchor/routing fields from g_inventory[0]
3. Confirm entry_price_eurusd and entry_price_gbpusd still
   use live spot prices for ALL layers (not inherited)
4. Confirm entry_price, entry_time still set before the if/else
5. No other changes to the file

Line count: 105
