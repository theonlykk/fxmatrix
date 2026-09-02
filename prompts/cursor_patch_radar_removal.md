# Cursor Patch — Radar Removal
# Date: 2026-06-11
# Source: Fable 5 audit (adrs/FABLE5_AUDIT_20260611.md, F14)
# Pre-verified: zero call sites for GetBestRadarTarget() and zero
#   uses of RadarTarget outside the function itself (grep across ea/).

## SCOPE

Local files only:
- d:\fxmatrix\ea\MathEngine.mqh
- d:\fxmatrix\ea\LayerStruct.mqh

Do NOT touch any other file. Do NOT use git add -A.

## EDIT 1 — ea/MathEngine.mqh

Delete the entire function `GetBestRadarTarget(double threshold)`
(currently lines 267-318, from the line
`RadarTarget GetBestRadarTarget(double threshold) {`
through its closing `}` immediately before `#endif // MATH_ENGINE_MQH`).

## EDIT 2 — ea/LayerStruct.mqh

Delete the `RadarTarget` struct and its comment header (currently
lines 67-75):

```
// Radar targeting — identifies single best routing case per bar close
struct RadarTarget {
    string symbol;       // "EURUSD", "GBPUSD", or "EURGBP"
    int    direction;    // DIRECTION_BUY or DIRECTION_SELL
    double dislocation;  // absolute spread magnitude
    bool   is_active;    // true if dislocation >= EntryThreshold
    int    strongest_idx; // mean-reversion strongest currency index
    int    weakest_idx;   // mean-reversion weakest currency index
};
```

## VERIFICATION

1. Grep `RadarTarget` and `GetBestRadarTarget` across ea/ — must
   return zero matches.
2. Compile FXMatrix.mq5 in MetaEditor — zero errors. The known
   `#property strict` warning is acceptable.
3. No behavioural change expected: the code was unreachable.

## COMMIT MESSAGE

chore: Patch — remove dead radar code (GetBestRadarTarget, RadarTarget struct) per DeepSeek abandonment ruling
