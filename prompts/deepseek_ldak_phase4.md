# DeepSeek R1 Audit — Phase 4 LDAK Correlation Penalty Framework

## Mission

You are performing a pre-implementation adversarial audit of a proposed mathematical framework before any code is written. Do NOT write implementation code. Your only job is to identify statistical pathologies, mechanical flaws, and edge cases in the proposal below.

## System Context

FXMatrix is a native MQL5 Expert Advisor implementing a 3-currency EUR/GBP/USD mean-reversion strategy. It trades three instruments simultaneously: EURUSD, GBPUSD, EURGBP. Each instrument has independent inventory (layers of passive limit orders). The strategy decomposes EUR/GBP/USD into currency strength scores and enters when one currency is dislocated vs the others.

The problem: during correlated macro shocks (e.g. USD strength events), EURUSD and GBPUSD both trend simultaneously. The system currently layers both instruments independently, effectively double-counting the underlying USD risk factor.

## The LDAK Proposal

Adapted from statistical genetics (Linkage Disequilibrium Adjusted Kinships), the framework penalizes redundant correlated exposure.

### Weighting Function
w = 1 / (1 + r²)

Where r² is the rolling Pearson correlation between EURUSD and GBPUSD log returns.

Behaviour:
- r=0 (uncorrelated): w=1.0 — full weight, no penalty
- r=1 (perfectly correlated): w=0.5 — half weight, exposure halved

### Application 1: Dynamic Lot Sizing
Effective K_size = K_size × (1 / (1 + r²))

K_size is the existing Phase 3 lot size reduction aggressiveness parameter. The LDAK weight attenuates it further when pairs are correlated.

### Application 2: Grid Dilation
Next Interval_L = (Base Interval × LayerStressBase^L) × (1 + r²)

When r²→1, the grid interval doubles, forcing the market to travel further before the next layer is placed.

Note: applied linearly, NOT exponentially. A prior Phase 3 bug caused double-exponential expansion (LayerStressBase applied on top of GridExpBase). This proposal explicitly avoids that pattern.

### Data Architecture (Locked by Gemini)
- Single M5 CopyClose feed, 289 bars, ArraySetAsSeries=true
- Fast window: 12 M5 bars (1 hour) → r²_fast
- Slow window: 288 M5 bars (24 hours) → r²_slow
- Effective r²: max(r²_fast, r²_slow)
- Computed in RunSignalOnBarClose() on bar close only, cached as globals
- Pairwise matrix — 3 values, not scalar:
  * r²_EU_GU (EURUSD vs GBPUSD)
  * r²_EU_EG (EURUSD vs EURGBP)
  * r²_GU_EG (GBPUSD vs EURGBP)
- Per-instrument penalty: when firing add_next for instrument X, query max r² against all other currently open pods only

### Insertion Points
- Lot sizing: HandleEntryFill() in ExecutionEngine.mqh
- Grid dilation: ComputeGridInterval() in MathEngine.mqh
- Correlation computation: RunSignalOnBarClose() in MathEngine.mqh
- New function: PearsonR2(array1, array2, n) — pure math, no side effects

## Your Audit Tasks

### 1. Statistical Pathologies
- Is Pearson r² the correct correlation measure for this application, or does it have known failure modes on FX returns that would produce false signals?
- The fast window is 12 M5 bars (60 minutes). What is the minimum sample size for a statistically meaningful Pearson r²? Does N=12 produce dangerously wide confidence intervals?
- During low-volatility periods (Asian session range drift), will microstructure noise cause false positive r² spikes that unnecessarily throttle the grid? What is the expected false positive rate?
- Is rolling Pearson on price returns the right input, or should we use log returns, normalised returns, or a different statistic entirely (e.g. Spearman rank, rolling beta)?

### 2. Mathematical Flaws
- The weighting function w=1/(1+r²) distributes weight across the cluster. In the original LDAK genetics context, weights sum to 1.0 across the cluster. In this two-asset application, does the analogy hold correctly? Are there cases where the adaptation breaks down?
- Grid dilation applies (1+r²) as a multiplier. When r²=0, multiplier=1.0 (no effect). When r²=1, multiplier=2.0 (interval doubles). Is this range sufficient to prevent concurrent layering during a macro shock, or should the multiplier be parameterised?
- The proposal applies LDAK to K_size which already has a PnL stress multiplier from Phase 3. Is there a compounding interaction between the PnL stress (which fires when the pod is losing) and the LDAK penalty (which fires when correlation is high)? Could they compound in a way that makes the lot size collapse to near-zero prematurely?
- EURGBP is a cross rate derived from EURUSD/GBPUSD. Its correlation to both dollar legs is mathematically constrained. Is r²_EU_EG and r²_GU_EG meaningful for the pairwise matrix, or is EURGBP structurally decorrelated from the dollar legs by construction?

### 3. Mechanical Flaws
- The effective r² uses max(r²_fast, r²_slow). The maximum operator means the penalty activates on the first sign of correlation and releases only when BOTH windows clear. Could this create a "sticky" penalty that lingers after a shock has passed, unnecessarily throttling the grid during the recovery phase when mean reversion is most profitable?
- The penalty is applied at add_next placement time (HandleEntryFill). But the correlation is computed at bar close (RunSignalOnBarClose). During a fast-moving macro event, the correlation state cached at the previous bar close may be stale by the time add_next fires. What is the maximum staleness window and does it matter?
- The pairwise matrix queries r² against currently open pods only. If only EURUSD has open inventory and GBPUSD does not, the LDAK penalty for EURUSD's next layer queries r²_EU_GU against an inactive pod. Should the penalty apply regardless of whether the correlated instrument has open inventory, or only when both pods are simultaneously active?
- Is there a circular dependency risk? LDAK penalises lot sizes when r² is high. Smaller lots mean smaller PnL swings. Smaller PnL swings reduce the Phase 3 PnL stress multiplier. Does this interaction create feedback loops in the grid geometry?

### 4. Regime Failure Modes
- What happens during a flash crash (r² spikes to 1.0 for 3-5 bars then reverts)? Does the max operator cause the slow window to hold the penalty for 24 hours after the crash is over?
- What happens if EURUSD and GBPUSD are perfectly anticorrelated (r=-1, r²=1)? The LDAK formula treats perfect anticorrelation identically to perfect correlation. Is this correct for a mean-reversion strategy, or should anticorrelation be treated as a signal amplifier rather than a penalty?
- The April 7-8 tariff shock showed concurrent layering beginning at 01:35 Asian session, approximately 6 hours into the USD move. With a 12-bar M5 fast window, would the LDAK penalty have been active by 01:35? Work through the timeline explicitly.

## Output Format

For each issue found:
- FINDING: one-sentence description
- SEVERITY: CRITICAL (invalidates the premise) / HIGH (requires architectural change) / MEDIUM (requires parameter guard) / LOW (monitor in backtesting)
- RECOMMENDATION: what to change or add

End with a VERDICT: APPROVED / APPROVED WITH CONDITIONS / REJECT, and a summary of mandatory changes before implementation.