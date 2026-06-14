# ADR-011 — LDAK Volatility Gate

**Date:** 2026-06-14
**Status:** IMPLEMENTED
**Authors:** Claude (Lead Engineer), Gemini (Staff Architect)

## Context
ADR-010 LDAK penalty fired on 98.2% of bars because EU/GU structural
correlation is 0.80+ at all times. Pearson r is scale-invariant and cannot
distinguish a 3-pip ranging drift (r=0.80) from a 300-pip tariff shock
(r=0.83). The penalty was permanently on, killing P&L in normal conditions.

## Root Cause
The April 7-8 shock was a VOLATILITY shock, not a correlation shock.
The correlation barely changed. The volatility exploded.

## Fix: Volatility-Gated Stress Score
Replace raw r_eff with S_eff = r * max(V_ratio - 1.0, 0)
where V_ratio = sigma_24 / sigma_288

During normal ranging: V_ratio ≈ 1.0, S = 0, w = 1.0 (penalty off)
During macro shock: V_ratio >> 1.0, S spikes, w drops (penalty on)

## Mathematical Specification

### New globals (cached in RunSignalOnBarClose)
g_vratio_EU = sigma_24(EURUSD) / sigma_288(EURUSD)
g_vratio_GU = sigma_24(GBPUSD) / sigma_288(GBPUSD)
g_vratio_EG = sigma_24(EURGBP) / sigma_288(EURGBP)

### Linkage evaluation (per instrument, open pods only)
For each active linkage (other pod must have open inventory):
  v_eff = max(V_ratio of this instrument, V_ratio of linked instrument)
  S = max(r_pairwise, 0) * max(v_eff - 1.0, 0)
  S_eff = max(S_eff, S) across all active linkages

w = 1 / (1 + S_eff^2)
Grid dilation = min(1 + S_eff^2, LDAK_Dilation_Max)

### Key properties
- w = 1.0 when no other pods open (no linkage)
- w = 1.0 when V_ratio <= 1.0 (normal volatility)
- Penalty only fires when BOTH correlation is positive AND volatility is elevated
- Each linkage uses its own paired V_ratio, not a global max

## Decisions
- V_ratio computed over 24-bar (fast) vs 288-bar (slow) M5 windows
- 288-bar slow window requires extending CopyClose to 289 bars
- StdDev() helper function added to MathEngine.mqh
- Open-pod constraint strictly enforced per Gemini ruling
- g_r_* globals from ADR-010 retained unchanged

## Related
- ADR-010: Phase 4 LDAK correlation penalty (baseline implementation)
- ADR-009: Serial mode diagnostic (identified April 7-8 failure mode)
