# Cursor Patch — ExecutionEngine.mqh (Instrument/Direction + Layer 0 Spread Fix)
# DeepSeek Audit Finding: Critical + High priority fixes
# Fix: L.instrument, L.direction, L.entry_spread_raw, L.entry_spread_adjusted
#      all reading live globals — must read from layer-local fields

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## File to patch
`d:\fxmatrix\ea\ExecutionEngine.mqh`

## Do NOT modify any other file.

---

## Background

In HandleEntryFill(), after the if/else block that sets anchor and
routing fields, L.instrument and L.direction are assigned from live
globals g_strongest and g_weakest. These globals are updated on every
M5 bar close. By the time a pending entry limit fills (hours or days
later), g_strongest and g_weakest may have rotated to a different
signal, causing the layer to be assigned the wrong instrument and
direction — and therefore computing exit prices for the wrong
instrument.

Additionally, for Layer 0, L.entry_spread_raw and
L.entry_spread_adjusted are assigned from g_entry_spread (signal-time
spread) instead of being recomputed at fill time like Layer 1+ does.

---

## Change 1 — Fix L.instrument assignment

Find this block (appears once, after the if/else anchor block):

### BEFORE:
```mql5
        if ((g_strongest == 0 && g_weakest == 1) ||
            (g_strongest == 1 && g_weakest == 0))
            L.instrument = INSTRUMENT_EURGBP;
        else if ((g_strongest == 0 && g_weakest == 2) ||
                 (g_strongest == 2 && g_weakest == 0))
            L.instrument = INSTRUMENT_EURUSD;
        else
            L.instrument = INSTRUMENT_GBPUSD;
```

### AFTER:
```mql5
        // Instrument derived from immutable layer routing fields
        // NOT from live globals which may have rotated since signal
        if ((L.strongest_at_entry == 0 && L.weakest_at_entry == 1) ||
            (L.strongest_at_entry == 1 && L.weakest_at_entry == 0))
            L.instrument = INSTRUMENT_EURGBP;
        else if ((L.strongest_at_entry == 0 && L.weakest_at_entry == 2) ||
                 (L.strongest_at_entry == 2 && L.weakest_at_entry == 0))
            L.instrument = INSTRUMENT_EURUSD;
        else
            L.instrument = INSTRUMENT_GBPUSD;
```

---

## Change 2 — Fix L.direction assignment

Find this block immediately after the instrument block:

### BEFORE:
```mql5
        if ((g_strongest == 0 && g_weakest == 1) ||
            (g_strongest == 0 && g_weakest == 2) ||
            (g_strongest == 1 && g_weakest == 2))
            L.direction = DIRECTION_SELL;
        else
            L.direction = DIRECTION_BUY;
```

### AFTER:
```mql5
        // Direction derived from immutable layer routing fields
        // NOT from live globals which may have rotated since signal
        if ((L.strongest_at_entry == 0 && L.weakest_at_entry == 1) ||
            (L.strongest_at_entry == 0 && L.weakest_at_entry == 2) ||
            (L.strongest_at_entry == 1 && L.weakest_at_entry == 2))
            L.direction = DIRECTION_SELL;
        else
            L.direction = DIRECTION_BUY;
```

---

## Change 3 — Fix Layer 0 entry_spread_raw and entry_spread_adjusted

Find this block inside `if (ArraySize(g_inventory) == 0)`:

### BEFORE:
```mql5
            L.entry_spread_raw           = g_entry_spread;
            L.entry_spread_adjusted      = g_entry_spread;
```

### AFTER:
```mql5
            // Recompute spread at fill time using entry-time anchors
            // and live mid prices — same logic as Layer 1+ already uses.
            // g_entry_spread is signal-time spread and may be stale.
            {
                double eu_mid_l0 = (eu_ask + eu_bid) / 2.0;
                double gb_mid_l0 = (gb_ask + gb_bid) / 2.0;
                double r_EU_l0   = MathLog(eu_mid_l0
                                   / L.EU_mid_12bars_ago_at_entry);
                double r_GB_l0   = MathLog(gb_mid_l0
                                   / L.GB_mid_12bars_ago_at_entry);
                double usd_l0    = -(r_EU_l0 + r_GB_l0) / 3.0;
                double eur_l0    =   r_EU_l0 + usd_l0;
                double gbp_l0    =   r_GB_l0 + usd_l0;
                double scores_l0[3];
                scores_l0[0] = eur_l0;
                scores_l0[1] = gbp_l0;
                scores_l0[2] = usd_l0;
                L.entry_spread_raw      = scores_l0[L.weakest_at_entry]
                                        - scores_l0[L.strongest_at_entry];
                L.entry_spread_adjusted = L.entry_spread_raw;
            }
```

Note: `eu_ask`, `eu_bid`, `gb_ask`, `gb_bid` are already fetched
earlier in the function before the if/else block. Do NOT re-fetch.
`L.EU_mid_12bars_ago_at_entry` and `L.weakest_at_entry` are already
set earlier in the Layer 0 branch — use them directly.

---

## Negative Space

- Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
  CarryEngine.mqh, or FXMatrix.mq5
- Do NOT change the Layer 1+ branch of the if/else block —
  those fixes are already applied and correct
- Do NOT change entry_price_eurusd_1h or entry_price_gbpusd_1h
  in either branch — those are addressed in a separate patch
- Do NOT change HandleExitFill() or the CloseBy intercept
- These are three targeted replacements in HandleEntryFill() only

---

## Self-Review

Before submitting:
1. Confirm L.instrument uses L.strongest_at_entry/L.weakest_at_entry
   not g_strongest/g_weakest
2. Confirm L.direction uses L.strongest_at_entry/L.weakest_at_entry
   not g_strongest/g_weakest
3. Confirm Layer 0 entry_spread_raw recomputed using live mid prices
   and L.EU_mid_12bars_ago_at_entry / L.GB_mid_12bars_ago_at_entry
4. Confirm scores_l0[L.weakest_at_entry] - scores_l0[L.strongest_at_entry]
   used for spread (dynamic routing, not hardcoded)
5. Confirm eu_ask/eu_bid/gb_ask/gb_bid not re-fetched
6. Confirm Layer 1+ branch unchanged
7. No other files modified

Line count: 112
