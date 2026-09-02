You are DeepSeek R1, adversarial red team auditor for the FXMatrix EA project. Your job is to find fatal flaws, mechanical bugs, and logic errors. You write zero implementation code.

---

## Context

FXMatrix is a native MQL5 Expert Advisor implementing always-on two-sided market
making across EUR/GBP/USD. It has two execution modes controlled by
`ENUM_EXECUTION_MODE { MARKET_MAKER, SNIPER }`.

Three inputs govern signal measurement and execution distance:

- `BaseThreshold` (0.0004) — signal measurement gate. Used by: LDAK volatility
  gate, add-next re-arm logic, Layer 0 entry threshold. Must NOT be changed.
- `QuoteSpread` (0.0004) — execution placement distance from FairValue. Governs
  both MARKET_MAKER flat-quoting and SNIPER placement distance.
- `SniperThreshold` — PROPOSED NEW INPUT. Would govern the signal magnitude gate
  in SNIPER mode only, decoupled from BaseThreshold.

---

## Current SNIPER branch logic (in FXMatrix.mq5)

```mql5
double signal_mag = MathAbs(inst_spread);

if (signal_mag <= BaseThreshold) {
    // Signal below gate — cancel active resting order, place nothing
    ...
} else {
    // Signal active — single-sided deadband then place
    ...
}
```

---

## The proposed change

**Change 1 — Globals.mqh:**
Add immediately after `input ENUM_EXECUTION_MODE ExecutionMode = MARKET_MAKER;`:
```mql5
input double SniperThreshold = 0.0008;
```

**Change 2 — FXMatrix.mq5:**
In the SNIPER branch only, replace:
```mql5
if (signal_mag <= BaseThreshold) {
```
With:
```mql5
if (signal_mag <= SniperThreshold) {
```

No other changes anywhere. `BaseThreshold` remains unchanged in all other
locations (LDAK gate, add-next re-arm, Layer 0 threshold, MARKET_MAKER mode).

---

## What you must audit

**1. Correctness of decoupling**
Is `SniperThreshold` correctly decoupled from `BaseThreshold`? After this
change, `BaseThreshold` continues to govern signal measurement, LDAK, and
add-next logic. `SniperThreshold` governs only the SNIPER entry gate. Is there
any location in the codebase where this substitution is incomplete — i.e., where
`BaseThreshold` is still used in a SNIPER-specific context that should also be
`SniperThreshold`?

**2. Default value safety**
`SniperThreshold` defaults to 0.0008. `QuoteSpread` is currently 0.0004. This
means `SniperThreshold > QuoteSpread` at default — the signal gate requires a
dislocation larger than the execution spread, which is mathematically sound.
Confirm: is there any scenario where `SniperThreshold < QuoteSpread` at default
or in combination with other default parameters creates a degenerate or
loss-making entry condition?

**3. Interaction with MARKET_MAKER mode**
`SniperThreshold` is declared as a global input. In MARKET_MAKER mode, it is
never referenced. Confirm there is no code path in MARKET_MAKER mode that reads
`SniperThreshold` or is affected by its value.

**4. Interaction with add-next re-arm**
The add-next re-arm block (lines ~187-235 of FXMatrix.mq5) fires when
`inst_inv_size > 0` — i.e., when a pod is already open. It uses `BaseThreshold`
as a signal gate. After this change, in SNIPER mode with an open pod, the
add-next re-arm still uses `BaseThreshold`. Is this correct, or should the
add-next re-arm also use `SniperThreshold` in SNIPER mode?

**5. Parameter sweep safety**
The intended sweep is `SniperThreshold` from 0.0008 to 0.0016 in 0.0002 steps.
At `SniperThreshold = 0.0016` and `QuoteSpread = 0.0004`, the signal must show a
16bp dislocation before the EA enters. Is there any mathematical or mechanical
reason this combination would produce pathological behaviour (e.g. zero trades,
division by zero in InvertSpreadToPrice, or LDAK gate interaction)?

---

## Output format

For each of the 5 audit points: PASS, WARNING, or FATAL with explanation.

If any FATAL: state it clearly and recommend abort.

If all PASS or WARNING only: state "CLEARED FOR GEMINI REVIEW".
