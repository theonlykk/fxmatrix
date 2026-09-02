# Cursor Patch — ExecutionEngine.mqh (Per-Layer Spread Recomputation)
# Gemini Ruling: 2026-06-08
# Fix: Layer N+ must recompute entry_spread_raw at fill time using
#      Layer 0 anchors. Fixed legs and routing inherited. Carry
#      references captured live per tranche.

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## File to patch
`d:\fxmatrix\ea\ExecutionEngine.mqh`

## Do NOT modify any other file.

---

## The problem

The previous inheritance fix shared entry_spread_raw from Layer 0
to all layers. This means all layers have identical exit targets —
all pointing at the same price. Layer 4 (deepest entry) and Layer 0
(shallowest entry) collapse at the same level, breaking the LIFO
breathing geometry.

## The fix

Replace the state assignment fork in HandleEntryFill() with the
exact block specified by Gemini below. Three categories of fields:

1. Inherited from Layer 0: anchors, routing, fixed legs
2. Captured live per tranche: carry reference prices (_1h fields)
3. Recomputed live using Layer 0 anchors: entry_spread_raw

---

## Change — Replace the if/else block in HandleEntryFill()

Find this entire if/else block inside `if (layer_idx == -1)`:

### BEFORE:
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

### AFTER:
```mql5
        L.entry_price  = deal_price;
        L.entry_time   = deal_time;

        if (ArraySize(g_inventory) == 0) {
            // --- LAYER 0: Capture live global signal state ---
            // Canonical pod anchor. All subsequent layers inherit
            // anchors, routing and fixed legs from this layer.
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
            // --- LAYER 1+: Mixed inherited + live per-tranche state ---

            // 1. Inherit immutable pod anchors and routing from Layer 0
            L.EU_mid_12bars_ago_at_entry = g_inventory[0].EU_mid_12bars_ago_at_entry;
            L.GB_mid_12bars_ago_at_entry = g_inventory[0].GB_mid_12bars_ago_at_entry;
            L.strongest_at_entry         = g_inventory[0].strongest_at_entry;
            L.weakest_at_entry           = g_inventory[0].weakest_at_entry;

            // 2. Inherit fixed legs to preserve grid geometry
            //    Fixed legs are the structural reference frame for
            //    Cases 3-6 inversion. Must match Layer 0 to keep
            //    the grid geometrically parallel.
            L.r_EU_at_entry              = g_inventory[0].r_EU_at_entry;
            L.r_GB_at_entry              = g_inventory[0].r_GB_at_entry;

            // 3. Capture LIVE carry references per tranche
            //    Carry tracks duration of each specific tranche.
            //    Inheriting Layer 0's _1h prices would apply phantom
            //    temporal drift to a tranche that is zero seconds old.
            L.entry_price_eurusd_1h      = g_EU_mid_12bars_ago;
            L.entry_price_gbpusd_1h      = g_GB_mid_12bars_ago;

            // 4. Recompute spread LIVE using Layer 0 anchors
            //    Measures the exact dislocation depth at this tranche's
            //    fill time, in the pod's shared reference frame.
            //    eu_ask/eu_bid/gb_ask/gb_bid already fetched above
            //    for entry_price_eurusd/entry_price_gbpusd.
            double eu_mid_now = (eu_ask + eu_bid) / 2.0;
            double gb_mid_now = (gb_ask + gb_bid) / 2.0;

            double r_EU_now = MathLog(eu_mid_now
                              / L.EU_mid_12bars_ago_at_entry);
            double r_GB_now = MathLog(gb_mid_now
                              / L.GB_mid_12bars_ago_at_entry);
            double usd_now  = -(r_EU_now + r_GB_now) / 3.0;
            double eur_now  =   r_EU_now + usd_now;
            double gbp_now  =   r_GB_now + usd_now;

            // Dynamic spread using inherited routing — not hardcoded.
            // spread = score_weakest - score_strongest (always negative)
            // Correct for all 6 routing cases.
            double scores_now[3];
            scores_now[0] = eur_now;
            scores_now[1] = gbp_now;
            scores_now[2] = usd_now;

            L.entry_spread_raw      = scores_now[L.weakest_at_entry]
                                    - scores_now[L.strongest_at_entry];
            L.entry_spread_adjusted = L.entry_spread_raw;
        }
```

---

## Important notes for Cursor

1. The variables `eu_ask`, `eu_bid`, `gb_ask`, `gb_bid` are already
   fetched earlier in the `if (layer_idx == -1)` block for the
   carry reference prices (entry_price_eurusd, entry_price_gbpusd).
   Do NOT re-fetch them — use the existing variables.

2. `L.EU_mid_12bars_ago_at_entry` is set in step 1 before the
   spread recomputation in step 4 — so it is safe to use in the
   MathLog computation.

3. Do NOT change the Layer 0 branch — only the Layer 1+ branch
   changes.

---

## Negative Space

- Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
  CarryEngine.mqh, or FXMatrix.mq5
- Do NOT change HandleExitFill() or the CloseBy intercept
- Do NOT change PlaceExitLimit() or PlaceEntryLimit()
- This is a targeted change to the Layer 1+ assignment block
  inside HandleEntryFill() only

---

## Self-Review

Before submitting:
1. Confirm Layer 0 branch unchanged — reads all fields from live globals
2. Confirm Layer 1+ anchors (EU/GB_mid_12bars_ago_at_entry,
   strongest_at_entry, weakest_at_entry) inherited from g_inventory[0]
3. Confirm Layer 1+ fixed legs (r_EU_at_entry, r_GB_at_entry)
   inherited from g_inventory[0]
4. Confirm Layer 1+ carry references (_1h fields) read from
   g_EU_mid_12bars_ago / g_GB_mid_12bars_ago (live, not inherited)
5. Confirm Layer 1+ entry_spread_raw recomputed using Layer 0
   anchors and current eu_mid_now / gb_mid_now
6. Confirm eu_ask/eu_bid/gb_ask/gb_bid not re-fetched — reuse
   existing variables from earlier in the block
7. No other files modified

Line count: 121
