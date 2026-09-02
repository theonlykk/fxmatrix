# Cursor Patch — MathEngine.mqh (Exit Direction Fix)
# Gemini Ruling: 2026-06-08
# Root cause: InvertSpreadToPrice() always computes entry-side direction.
#             Exit computations need direction flipped and correct
#             half-spread offset applied.

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## File to patch
`d:\fxmatrix\ea\MathEngine.mqh`

## Do NOT modify any other file.

---

## Change 1 — Update InvertSpreadToPrice() signature

Add `bool is_exit` as the final parameter:

### BEFORE:
```mql5
double InvertSpreadToPrice(
    double anchor_EU,
    double anchor_GB,
    double r_EU_fixed,
    double r_GB_fixed,
    double T,
    int    strongest,
    int    weakest
)
```

### AFTER:
```mql5
double InvertSpreadToPrice(
    double anchor_EU,
    double anchor_GB,
    double r_EU_fixed,
    double r_GB_fixed,
    double T,
    int    strongest,
    int    weakest,
    bool   is_exit
)
```

---

## Change 2 — Remove hardcoded half-spread offsets from all six cases

In each of the six routing cases, the current code applies the
half-spread offset inside the case block. Remove those offsets.
Each case should compute only `target_mid` and assign it to `price`.
The offset will be applied once after the direction flip (Change 3).

### For Cases 1 & 2 (EURGBP):

BEFORE (Case 1):
```mql5
double EG_history = anchor_EU / anchor_GB;
double EG_target  = EG_history * MathExp(-T);
price = EG_target + eg_half_spread;
```

AFTER (Case 1):
```mql5
double EG_history = anchor_EU / anchor_GB;
double EG_target  = EG_history * MathExp(-T);
price = EG_target;   // half-spread applied below after direction flip
```

BEFORE (Case 2):
```mql5
double EG_history = anchor_EU / anchor_GB;
double EG_target  = EG_history * MathExp(-T);
price = EG_target - eg_half_spread;
```

AFTER (Case 2):
```mql5
double EG_history = anchor_EU / anchor_GB;
double EG_target  = EG_history * MathExp(-T);
price = EG_target;   // half-spread applied below after direction flip
```

### For Cases 3 & 4 (EURUSD):

BEFORE (Case 3):
```mql5
double r_EU_target    = r_GB_fixed - T;
double EU_target_mid  = anchor_EU * MathExp(r_EU_target);
price = EU_target_mid + eu_half_spread;
```

AFTER (Case 3):
```mql5
double r_EU_target    = r_GB_fixed - T;
double EU_target_mid  = anchor_EU * MathExp(r_EU_target);
price = EU_target_mid;  // half-spread applied below after direction flip
```

BEFORE (Case 4):
```mql5
double r_EU_target    = r_GB_fixed - T;
double EU_target_mid  = anchor_EU * MathExp(r_EU_target);
price = EU_target_mid - eu_half_spread;
```

AFTER (Case 4):
```mql5
double r_EU_target    = r_GB_fixed - T;
double EU_target_mid  = anchor_EU * MathExp(r_EU_target);
price = EU_target_mid;  // half-spread applied below after direction flip
```

### For Cases 5 & 6 (GBPUSD):

BEFORE (Case 5):
```mql5
double r_GB_target    = r_EU_fixed + T;
double GB_target_mid  = anchor_GB * MathExp(r_GB_target);
price = GB_target_mid + gb_half_spread;
```

AFTER (Case 5):
```mql5
double r_GB_target    = r_EU_fixed + T;
double GB_target_mid  = anchor_GB * MathExp(r_GB_target);
price = GB_target_mid;  // half-spread applied below after direction flip
```

BEFORE (Case 6):
```mql5
double r_GB_target    = r_EU_fixed + T;
double GB_target_mid  = anchor_GB * MathExp(r_GB_target);
price = GB_target_mid - gb_half_spread;
```

AFTER (Case 6):
```mql5
double r_GB_target    = r_EU_fixed + T;
double GB_target_mid  = anchor_GB * MathExp(r_GB_target);
price = GB_target_mid;  // half-spread applied below after direction flip
```

---

## Change 3 — Add direction flip and unified half-spread offset

After the six case routing block (after the final `else` that prints
the error and returns -1.0), add this block immediately before the
IsPassive() check:

```mql5
    // Flip direction for exit orders — entry direction is always
    // the opposite of the exit direction.
    // e.g. Sell EURUSD entry → Buy EURUSD exit
    if (is_exit) {
        direction = (direction == DIRECTION_BUY)
                    ? DIRECTION_SELL : DIRECTION_BUY;
    }

    // Apply half-spread offset based on FINAL direction
    // Sell limit: push above Ask (+half_spread)
    // Buy limit:  push below Bid (-half_spread)
    double half_spread = 0.0;
    if      (symbol == "EURGBP") half_spread = eg_half_spread;
    else if (symbol == "EURUSD") half_spread = eu_half_spread;
    else                         half_spread = gb_half_spread;

    if (direction == DIRECTION_SELL)
        price = price + half_spread;
    else
        price = price - half_spread;
```

---

## Change 4 — Update ComputeEntryPrice() caller

### BEFORE:
```mql5
double ComputeEntryPrice() {
    return InvertSpreadToPrice(
        g_EU_mid_12bars_ago,
        g_GB_mid_12bars_ago,
        g_r_EU_signal,
        g_r_GB_signal,
        g_entry_spread,
        g_strongest,
        g_weakest
    );
}
```

### AFTER:
```mql5
double ComputeEntryPrice() {
    return InvertSpreadToPrice(
        g_EU_mid_12bars_ago,
        g_GB_mid_12bars_ago,
        g_r_EU_signal,
        g_r_GB_signal,
        g_entry_spread,
        g_strongest,
        g_weakest,
        false              // is_exit = false for entry
    );
}
```

---

## Change 5 — Update ComputeExitPrice() caller

### BEFORE:
```mql5
double ComputeExitPrice(const Layer &layer) {
    return InvertSpreadToPrice(
        layer.EU_mid_12bars_ago_at_entry,
        layer.GB_mid_12bars_ago_at_entry,
        layer.r_EU_at_entry,
        layer.r_GB_at_entry,
        layer.exit_spread_target,
        layer.strongest_at_entry,
        layer.weakest_at_entry
    );
}
```

### AFTER:
```mql5
double ComputeExitPrice(const Layer &layer) {
    return InvertSpreadToPrice(
        layer.EU_mid_12bars_ago_at_entry,
        layer.GB_mid_12bars_ago_at_entry,
        layer.r_EU_at_entry,
        layer.r_GB_at_entry,
        layer.exit_spread_target,
        layer.strongest_at_entry,
        layer.weakest_at_entry,
        true               // is_exit = true for exit
    );
}
```

---

## Negative Space

- Do NOT change T values or signs anywhere
- Do NOT modify LayerStruct.mqh, Globals.mqh, ExecutionEngine.mqh,
  CarryEngine.mqh, or FXMatrix.mq5
- Do NOT change the IsPassive() function
- Do NOT change IsClearOfFreezeLevel()
- Do NOT change RunSignalOnBarClose()
- This is a targeted five-change patch to MathEngine.mqh only

---

## Self-Review

Before submitting:
1. Confirm InvertSpreadToPrice() has 8 parameters including is_exit
2. Confirm all six cases compute target_mid only — no half-spread
   inside the case blocks
3. Confirm direction flip fires when is_exit == true
4. Confirm unified half-spread offset applied after direction flip
   based on final direction
5. Confirm ComputeEntryPrice() passes false
6. Confirm ComputeExitPrice() passes true
7. No other changes to the file

Line count: 196
