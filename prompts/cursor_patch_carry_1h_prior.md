# Cursor Patch — ExecutionEngine.mqh (Option A Carry Reference Fix)
# Gemini Ruling: Option A APPROVED — Layer 1+ inherits Layer 0 carry baseline
# Patch: entry_price_eurusd_1h / entry_price_gbpusd_1h in Layer 1+ branch

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## File to patch
`d:\fxmatrix\ea\ExecutionEngine.mqh`

## Do NOT modify any other file.

---

## Background

Gemini (Staff Architect) has ruled Option A for carry reference
baseline in Layer 1+. The current code captures live globals
g_EU_mid_12bars_ago and g_GB_mid_12bars_ago at each layer's fill
time. This introduces a different temporal reference frame per layer,
decoupling later layers from the pod's shared spatial baseline and
warping the exit target geometry.

Option A: all layers inherit L.EU_mid_12bars_ago_at_entry and
L.GB_mid_12bars_ago_at_entry from Layer 0. All carry drift is
measured against the exact same zero-point that generated the pod.
The slight carry overstatement for later layers is an accepted V1
approximation — it guarantees the LIFO grid remains strictly parallel.

---

## Change 1 — Fix Layer 1+ carry reference + update comment

Find this exact block in HandleEntryFill(), inside the Layer 1+ else
branch:

### BEFORE:
```mql5
            // 3. Capture LIVE carry references per tranche
            //    Carry tracks duration of each specific tranche.
            //    Inheriting Layer 0's _1h prices would apply phantom
            //    temporal drift to a tranche that is zero seconds old.
            L.entry_price_eurusd_1h      = g_EU_mid_12bars_ago;
            L.entry_price_gbpusd_1h      = g_GB_mid_12bars_ago;
```

### AFTER:
```mql5
            // 3. Inherit carry references from Layer 0 (Option A — Gemini ruling)
            //    All layers in the pod share the same carry baseline:
            //    the 1h-prior price at the time of the original pod signal.
            //    This keeps the RunCarryRecalculation() reference frame
            //    identical across all tranches, preserving parallel grid
            //    geometry. Slight carry overstatement for later layers is
            //    an accepted V1 approximation.
            L.entry_price_eurusd_1h      = L.EU_mid_12bars_ago_at_entry;
            L.entry_price_gbpusd_1h      = L.GB_mid_12bars_ago_at_entry;
```

---

## Negative Space

- Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
  CarryEngine.mqh, or FXMatrix.mq5
- Do NOT touch the Layer 0 branch — entry_price_eurusd_1h for
  Layer 0 is already set correctly from g_EU_mid_12bars_ago at
  signal time
- Do NOT touch L.EU_mid_12bars_ago_at_entry or
  L.GB_mid_12bars_ago_at_entry assignments — those are already
  inherited from Layer 0 in earlier steps and are correct
- Do NOT modify HandleExitFill(), CarryEngine, or the CloseBy
  intercept
- This is one targeted replacement in HandleEntryFill() only
- Do NOT change the surrounding Step 2 or Step 4 comment blocks

---

## Self-Review

Before submitting:
1. Confirm L.entry_price_eurusd_1h uses L.EU_mid_12bars_ago_at_entry
   not g_EU_mid_12bars_ago
2. Confirm L.entry_price_gbpusd_1h uses L.GB_mid_12bars_ago_at_entry
   not g_GB_mid_12bars_ago
3. Confirm the Step 3 comment block is updated to reflect Option A
   rationale — old comment referencing "phantom temporal drift"
   must be replaced
4. Confirm Layer 0 branch is untouched
5. Confirm no other files modified
6. Confirm surrounding Step 2 and Step 4 blocks are untouched

Line count: 74