# Cursor Patch — MathEngine.mqh (StrengthWindow fix)

One targeted fix required in `d:\fxmatrix\ea\MathEngine.mqh`.

In `RunSignalOnBarClose()`, replace all hardcoded references to
`13` (bars to fetch) and `12` (index of the 1-hour-ago bar) with
the `StrengthWindow` input parameter from `Globals.mqh`.

## Specific changes

### CopyClose calls — replace hardcoded bar count:

```mql5
// BEFORE:
if (CopyClose("EURUSD", PERIOD_M5, 0, 13, eu_closes) < 13)
if (CopyClose("GBPUSD", PERIOD_M5, 0, 13, gb_closes) < 13)

// AFTER:
if (CopyClose("EURUSD", PERIOD_M5, 0, StrengthWindow+1, eu_closes) < StrengthWindow+1)
if (CopyClose("GBPUSD", PERIOD_M5, 0, StrengthWindow+1, gb_closes) < StrengthWindow+1)
```

### Array index — replace hardcoded lookback index:

```mql5
// BEFORE:
double eu_1h = eu_closes[12];
double gb_1h = gb_closes[12];

// AFTER:
double eu_1h = eu_closes[StrengthWindow];
double gb_1h = gb_closes[StrengthWindow];
```

## Why

`StrengthWindow` is an input parameter in `Globals.mqh` (default 12).
Hardcoding `13` and `12` means changes to `StrengthWindow` in the
MT5 EA Properties dialog are silently ignored by the signal
computation. The fix makes the lookback window fully parameterised.

## Negative space

Do NOT change anything else in `MathEngine.mqh`. No other logic,
no new functions, no struct changes. This is a targeted two-variable
substitution only.

## Self-review

Confirm:
1. Both `CopyClose` calls use `StrengthWindow+1`
2. Both array index references use `StrengthWindow`
3. No other changes made to the file

Line count: 47
