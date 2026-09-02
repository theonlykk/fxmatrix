# Cursor Implementation Prompt — Exit Skew Phase 1
# Scope: MathEngine.mqh only — ComputeExitSpreadTarget() rewrite
# This message has a line count at the bottom.

---

## MANDATORY FIRST STEP

Before making any edits, confirm the following anchor line numbers from
the CURRENT file on disk. Report each line number back before proceeding.
Do NOT begin editing until all anchors are confirmed.

**MathEngine.mqh — confirm line numbers of:**
1. `double ComputeExitSpreadTarget(const Layer &layer) {`
2. `return layer.entry_spread_adjusted + GridBase * ComputeSkew(layer.layer_index);`
3. `double ComputeSkew(int layer_idx) {`
4. `return SkewStart;` — inside ComputeSkew SkewMode 0 branch
5. `return MathMax(SkewStart - layer_idx * SkewStep, SkewMin);` — SkewMode 1

---

## CONTEXT

This is Phase 1 of a two-phase exit skew refactor. Phase 1 fixes the
mathematical foundation only. Phase 2 (separate prompt, separate audit)
will introduce geometric decay.

The current `ComputeExitSpreadTarget()` uses an **additive** formula:
```
exit_target = entry_spread_adjusted + GridBase * ComputeSkew(layer_index)
```

This is mathematically wrong for the intended exit geometry. The skew
fraction is supposed to represent a proportion of the entry dislocation
that the EA targets for capture. The correct form is **multiplicative**:
```
exit_target = entry_spread_adjusted * ComputeSkew(layer_index)
```

`ComputeSkew()` is NOT changed in this prompt. It continues to return
`SkewStart = 0.618` for all layers (SkewMode=0, SkewStep=0 production
defaults). The only change is the formula in `ComputeExitSpreadTarget()`.

**Validation requirement:** With production defaults (SkewMode=0,
SkewStart=0.618, SkewStep=0), the new formula must produce:
```
exit_target = entry_spread_adjusted * 0.618
```
This is a constant 61.8% of the entry dislocation for all layers —
identical in intent to the V2 design, just correctly expressed as a
fraction of the spread rather than an additive grid offset.

---

## THE ONE CHANGE

### Replace ComputeExitSpreadTarget()

REPLACE:
```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    // V2 Phase 1: uses ComputeSkew(0) as safe approximation.
    // layer_index not yet in LayerStruct (Phase 2 addition).
    // When SkewStep=0 (default), ComputeSkew(0) == ComputeSkew(N)
    // for all N, so this is mathematically identical to Phase 0.
    // Phase 2 one-line patch: replace 0 with layer.layer_index.
    return layer.entry_spread_adjusted + GridBase * ComputeSkew(layer.layer_index);
}
```
WITH:
```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    // ADR-025 Phase 1: multiplicative exit spread target.
    // exit_target = entry_spread_adjusted * skew_fraction
    // where skew_fraction = ComputeSkew(layer_index).
    //
    // With production defaults (SkewMode=0, SkewStart=0.618):
    //   exit_target = entry_spread_adjusted * 0.618
    //
    // entry_spread_adjusted is negative (weakest - strongest < 0).
    // skew fraction is positive (0 < skew <= 1).
    // exit_target is therefore negative, closer to zero than entry_spread.
    // InvertSpreadToPrice() uses this to place the exit limit between
    // current price and fair value.
    //
    // Phase 2 (geometric decay): ComputeSkew() will be updated to
    // return 0.618^(layer_index+1) with a layer-decaying floor.
    // No changes needed here — the multiplicative form is already correct.
    return layer.entry_spread_adjusted * ComputeSkew(layer.layer_index);
}
```

---

## WHAT NOT TO TOUCH

- Do NOT modify ComputeSkew() — that is Phase 2 scope.
- Do NOT modify any other function in MathEngine.mqh.
- Do NOT modify any other file.
- Do NOT change SkewStart, SkewMode, SkewStep, SkewMin inputs.

---

## SELF-REVIEW CHECKLIST

Before responding, verify every item:

- [ ] Anchor line numbers confirmed before any edit
- [ ] ComputeExitSpreadTarget() replaced with multiplicative form
- [ ] Comment block updated to explain multiplicative geometry and
      Phase 2 path
- [ ] ComputeSkew() UNCHANGED
- [ ] No other functions modified
- [ ] No other files modified
- [ ] F7 compile produces ZERO errors and ZERO warnings

---

## REGRESSION VERIFICATION

After F7 passes, verify the mathematical behaviour manually:

With SkewMode=0, SkewStart=0.618, for a layer with
entry_spread_adjusted = -0.0010 (10 bps dislocation):

**Old formula:**
`-0.0010 + 0.0008 * 0.618 = -0.0010 + 0.000494 = -0.000506`
(exit at 5.06 bps from fair value)

**New formula:**
`-0.0010 * 0.618 = -0.000618`
(exit at 6.18 bps from fair value — 61.8% of the 10 bps entry spread)

These are DIFFERENT values. The new formula is the correct one.
The old formula was producing exits that were NOT a fixed fraction of
the entry spread — they were a fixed fraction of GridBase added to the
spread, which is neither geometrically nor economically meaningful.

Report both computed values in your response to confirm the change
is working correctly.

---

Line count: 144
