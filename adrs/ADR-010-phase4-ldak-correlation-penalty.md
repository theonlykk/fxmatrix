# ADR-010 — Phase 4 LDAK Correlation Penalty

**Date:** 2026-06-14
**Status:** IMPLEMENTED
**Authors:** Claude (Lead Engineer), Gemini (Staff Architect)

## Context
During the April 7-8 tariff shock, EURUSD and GBPUSD accumulated layers
simultaneously, double-counting underlying USD risk. LDAK (Linkage
Disequilibrium Adjusted Kinships) framework adapted from statistical
genetics penalizes redundant correlated exposure dynamically.

## Mathematical Specification

### Correlation computation
- Single M5 CopyClose feed, 25 bars (24 returns), ArraySetAsSeries=true
- Three native fetches: EURUSD, GBPUSD, EURGBP
- Pearson r (signed) computed on log returns, 24-bar window
- Stored as globals: g_r_EU_GU, g_r_EU_EG, g_r_GU_EG
- Computed in RunSignalOnBarClose() on bar close only

### Weight function (per instrument at add_next time)
r_eff = max Pearson r against OTHER currently open pods only
If no other pods open: w = 1.0 (no penalty)
w = 1 / (1 + max(r_eff, 0)^2)

### Lot sizing
Final_Lot_Size = BaseLotSize * Phase3_Stress_Multiplier * w
Applied AFTER all Phase 3 stress calculations. Do NOT modify K_size.

### Grid dilation
dilation = min(1 + max(r_eff, 0)^2, LDAK_Dilation_Max)
Next_Interval = base_interval * layer_stress * pnl_stress * dilation

## Decisions
- Anticorrelation not penalized: max(r, 0)^2 not r^2
- Single 24-bar window (no dual-window): decays naturally 2h after shock
- EURGBP fetched natively (host chart symbol): no synthetic derivation
- Staleness (5 min lag): acceptable for mean-reversion timeframe, deferred
- w=1.0 guard when no other pods open: explicit default

## New Parameters
- LDAK_Dilation_Max (default 3.0): caps grid dilation during extreme shocks

## Related
- ADR-008: Phase 3 drawdown-responsive market making
- ADR-009: Serial mode diagnostic (identified April 7-8 failure mode)
