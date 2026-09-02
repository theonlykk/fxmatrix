# Cursor Implementation Prompt — Median Filter & StrengthWindow Fix
# Scope: MathEngine.mqh only
# Gemini cleared — no DeepSeek audit required
# This message has a line count at the bottom.

---

## MANDATORY FIRST STEP

Confirm these anchor line numbers from the CURRENT file on disk before
any edits. Do NOT begin until all confirmed.

**MathEngine.mqh:**
1. `bool RunSignalOnBarClose() {` — confirm line number
2. `if (CopyClose(g_symbols[SLOT_AC], PERIOD_M5, 0, 289, ac_closes) < 289)` — confirm line
3. `ArraySetAsSeries(ac_closes, true);` — confirm line
4. `double ac_now = ac_closes[0]  + ac_half;` — confirm line
5. `double ac_1h  = ac_closes[12] + ac_half;` — confirm line (the hardcoded 12)
6. `double bc_now = bc_closes[0]  + bc_half;` — confirm line
7. `double bc_1h  = bc_closes[12] + bc_half;` — confirm line (the hardcoded 12)
8. `g_r_signal[0] = MathLog(ac_now / ac_1h);` — confirm line
9. `g_r_signal[1] = MathLog(bc_now / bc_1h);` — confirm line

---

## CONTEXT

Two changes to `RunSignalOnBarClose()` in `MathEngine.mqh`:

**Fix 1 — Hardcoded anchor lookback (the smoking gun)**
`ac_closes[12]` and `bc_closes[12]` use a hardcoded 12-bar lookback for
the anchor price. The `StrengthWindow` input has no effect on the anchor
— changing `StrengthWindow` to 6 or 48 is currently a placebo. The
hardcoded 12 must become `StrengthWindow` so each instance of the EA
uses its configured lookback tier (6/12/48 bars).

**Fix 2 — Median filter for current price reference**
`ac_now = ac_closes[0] + ac_half` uses a single close — vulnerable to
toxic tick prints on the current live bar. Replace with `MathMedian()`
over the most recent `StrengthWindow` closes to smooth the current price
reference. The anchor (`ac_closes[StrengthWindow]`) remains a single
confirmed historical close — no smoothing needed there.

**No M5 gate needed** — `RunSignalOnBarClose()` is already called only
on new bars by the V3 OnTick logic. The `iTime` gate is redundant.

---

## CHANGE 1 — Add MathMedian() helper function

Add the following function immediately BEFORE `bool RunSignalOnBarClose() {`:

```mql5
//------------------------------------------------------------------
// MathMedian
// Returns the median of a double array.
// Used to protect the current price reference from toxic tick prints.
//------------------------------------------------------------------
double MathMedian(const double &arr[], int count) {
    if (count <= 0) return 0.0;
    double temp[];
    ArrayResize(temp, count);
    for (int i = 0; i < count; i++) temp[i] = arr[i];
    ArraySort(temp);
    if (count % 2 == 0)
        return (temp[count / 2 - 1] + temp[count / 2]) / 2.0;
    else
        return temp[count / 2];
}
```

Note: Takes explicit `count` parameter rather than `ArraySize()` to
support passing a slice of a larger array (the first `StrengthWindow`
elements of the `ac_closes[]` series array).

---

## CHANGE 2 — Fix hardcoded anchor + apply median to current price

In `RunSignalOnBarClose()`, REPLACE:
```mql5
    double ac_now = ac_closes[0]  + ac_half;  // bid close → mid
    double ac_1h  = ac_closes[12] + ac_half;  // bid close → mid
    double bc_now = bc_closes[0]  + bc_half;  // bid close → mid
    double bc_1h  = bc_closes[12] + bc_half;  // bid close → mid
```
WITH:
```mql5
    // Median-smooth the current price reference (closes[0..StrengthWindow-1])
    // to protect against toxic tick prints on the live bar.
    // The anchor (closes[StrengthWindow]) remains a single confirmed close —
    // no smoothing needed for a historical confirmed bar.
    double ac_now = MathMedian(ac_closes, StrengthWindow) + ac_half;
    double ac_1h  = ac_closes[StrengthWindow] + ac_half;  // dynamic anchor
    double bc_now = MathMedian(bc_closes, StrengthWindow) + ac_half;
    double bc_1h  = bc_closes[StrengthWindow] + ac_half;  // dynamic anchor
```

Wait — `bc_now` and `bc_1h` use `bc_half` not `ac_half`. Correct version:
```mql5
    double ac_now = MathMedian(ac_closes, StrengthWindow) + ac_half;
    double ac_1h  = ac_closes[StrengthWindow]             + ac_half;
    double bc_now = MathMedian(bc_closes, StrengthWindow) + bc_half;
    double bc_1h  = bc_closes[StrengthWindow]             + bc_half;
```

---

## CHANGE 3 — Expand CopyClose buffer to accommodate StrengthWindow + 1

The current `CopyClose` calls request 289 bars (enough for 12-bar anchor
+ LDAK 24-bar correlation). With `StrengthWindow` up to 48, the anchor
is at `closes[48]`, so we need at least 49 bars minimum. 289 is already
sufficient — but add a runtime guard to confirm:

In `RunSignalOnBarClose()`, find the CopyClose call for SLOT_AC:
```mql5
    if (CopyClose(g_symbols[SLOT_AC], PERIOD_M5, 0, 289, ac_closes) < 289) {
```

REPLACE the minimum count check (the `< 289` part):
```mql5
    int min_bars = MathMax(289, StrengthWindow + 25);
    if (CopyClose(g_symbols[SLOT_AC], PERIOD_M5, 0, min_bars, ac_closes) < min_bars) {
```

Apply the same pattern to the SLOT_BC CopyClose call.

Also update the LDAK ab_closes CopyClose if it has the same hardcoded
289 — apply the same `min_bars` guard (reuse the variable).

---

## WHAT NOT TO TOUCH

- Do NOT modify the LDAK correlation block
- Do NOT modify `g_anchor[]` assignments — they correctly use `ac_1h`
  and `bc_1h` which are now computed from `ac_closes[StrengthWindow]`
- Do NOT modify `g_r_signal[]` assignments — they use `ac_now`/`bc_now`
  which are now median-smoothed
- Do NOT modify `g_scores[]` computation
- Do NOT modify any other function in MathEngine.mqh
- Do NOT modify any other file

---

## SELF-REVIEW CHECKLIST

- [ ] Anchors confirmed before any edit
- [ ] `MathMedian()` helper added before `RunSignalOnBarClose()`
- [ ] `MathMedian()` takes explicit `count` parameter
- [ ] `ac_now` uses `MathMedian(ac_closes, StrengthWindow)` + ac_half
- [ ] `ac_1h` uses `ac_closes[StrengthWindow]` (not hardcoded 12)
- [ ] `bc_now` uses `MathMedian(bc_closes, StrengthWindow)` + bc_half
- [ ] `bc_1h` uses `bc_closes[StrengthWindow]` (not hardcoded 12)
- [ ] CopyClose buffer guard uses `MathMax(289, StrengthWindow + 25)`
- [ ] `g_anchor[0]` still assigned from `ac_1h` (now dynamic)
- [ ] `g_anchor[1]` still assigned from `bc_1h` (now dynamic)
- [ ] LDAK correlation block UNCHANGED
- [ ] No other files modified
- [ ] F7 compile produces ZERO errors and ZERO warnings

---

Line count: 165
