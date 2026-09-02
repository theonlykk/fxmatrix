ROLE: You are an adversarial quantitative auditor (Red Team Prime).
Your sole objective is to find fatal flaws in the proposed mathematical
and implementation changes below. Do not write implementation code.
Hunt for mathematical errors, numerical instability, logic failures,
and constraint violations only.

SYSTEM CONTEXT
--------------
FXMatrix is a native MQL5 Expert Advisor implementing always-on two-sided
market making across EUR/GBP/USD on an FTMO funded demo account. The EA
uses an LDAK (LD Adjusted Kinships) volatility gate adapted from Doug
Speed's statistical genetics framework to penalise lot size and dilate
grid spacing when correlated currency pods are simultaneously open during
macro shocks.

CURRENT LDAK IMPLEMENTATION (ADR-011)
--------------------------------------
The current implementation uses pairwise Pearson r approximation:

  For each open pod pair (EU/GU, EU/EG, GU/EG):
    S_eff = max(r_pair, 0) * max(V_ratio - 1.0, 0)
    w = 1 / (1 + S_eff^2)
    dilation = min(1 + S_eff^2, LDAK_Dilation_Max)

Where:
  r_pair   = signed Pearson r between the two instrument return series
  V_ratio  = sigma_24 / sigma_288 (fast vs slow M5 volatility window)
  sigma_24 = 24-bar M5 standard deviation of log returns
  sigma_288 = 288-bar M5 standard deviation of log returns

Global state:
  g_r_EU_GU, g_r_EU_EG, g_r_GU_EG  — pairwise Pearson r (signed)
  g_vratio_EU, g_vratio_GU, g_vratio_EG — per-instrument volatility ratios

The pairwise approximation double-counts cross-correlations. When all
three pods are simultaneously open, the EU/GU, EU/EG, and GU/EG terms
independently penalise the same underlying USD risk, overstating the
total penalty.

PROPOSED PHASE 2 — EXACT LDAK MATRIX UPGRADE
---------------------------------------------
Replace pairwise approximation with the theoretically exact inverse
weighting matrix D = inv(XX^T / m) from Doug Speed's original framework.

The mathematical derivation:

Step 1 — Build the 3x3 log return matrix X:
  X is a 3x3 matrix where rows are currencies (EUR, GBP, USD) and
  columns are... actually X is built from the currency return vectors.
  Specifically, define:
    r_EU = log(EURUSD_mid_now / EURUSD_mid_12bars_ago)  [EUR vs USD]
    r_GU = log(GBPUSD_mid_now / GBPUSD_mid_12bars_ago)  [GBP vs USD]
  From these, derive synthetic currency scores:
    score_USD = -(r_EU + r_GU) / 3
    score_EUR =  r_EU + score_USD
    score_GBP =  r_GU + score_USD

  These scores are already computed in RunSignalOnBarClose() as
  g_score_eur, g_score_gbp, g_score_usd.

Step 2 — Build the 3x3 correlation matrix C:
  C = XX^T / m
  where X is the (3 x N) matrix of currency score time series over
  the last N M5 bars, and m = N (number of observations).
  C[i][j] = correlation between currency i and currency j scores.
  Diagonal C[i][i] = 1.0 (self-correlation).

Step 3 — Invert C using closed-form 3x3 Cramer's rule:
  D = inv(C)
  Computed via cofactor matrix / determinant.
  det(C) = C[0][0]*(C[1][1]*C[2][2] - C[1][2]*C[2][1])
          - C[0][1]*(C[1][0]*C[2][2] - C[1][2]*C[2][0])
          + C[0][2]*(C[1][0]*C[2][1] - C[1][1]*C[2][0])

Step 4 — Extract per-instrument weights from D:
  The diagonal elements D[i][i] give the effective weight for
  currency i after accounting for all cross-correlations.
  w_EUR = 1 / D[0][0]
  w_GBP = 1 / D[1][1]
  w_USD = 1 / D[2][2]
  These weights replace the current pairwise S_eff^2 penalty.

Step 5 — Apply volatility gate (retained from ADR-011):
  The volatility gate V_ratio is retained unchanged. The exact matrix
  provides the correlation penalty; the volatility gate determines
  WHEN the penalty fires:
  S_eff_i = (1 - w_i) * max(V_ratio_i - 1.0, 0)
  lot_penalty_i = 1 / (1 + S_eff_i^2)
  dilation_i = min(1 + S_eff_i^2, LDAK_Dilation_Max)

Step 6 — Implementation:
  Hardcoded 3x3 Cramer's rule inversion — no ALGLIB, no third-party
  libraries. Computed in RunSignalOnBarClose() on every M5 bar close.
  Window N = 288 bars (same as sigma_288 slow volatility window).
  Result stored in new globals:
    g_w_eur, g_w_gbp, g_w_usd  — exact LDAK weights per currency

AUDIT TARGETS
-------------
Hunt specifically for:

1. MATHEMATICAL CORRECTNESS — CORRELATION MATRIX CONSTRUCTION:
   The proposal derives currency scores from two observable log returns
   (r_EU, r_GU) via a 3-currency decomposition. The resulting score
   vector [score_EUR, score_GBP, score_USD] always sums to zero by
   construction (it is a zero-sum decomposition). Does building the
   correlation matrix C from a zero-sum constrained vector space
   introduce a mathematical degeneracy? Specifically: is the 3x3
   correlation matrix of zero-sum constrained scores guaranteed to be
   invertible, or will det(C) = 0 for structural mathematical reasons
   unrelated to market conditions?

2. NUMERICAL STABILITY — NEAR-SINGULAR MATRIX:
   The Cramer's rule inversion divides by det(C). In what market
   conditions would det(C) approach zero (near-singular), causing
   catastrophic numerical instability? Is there a structural reason
   (e.g., during low-volatility consolidation when all three currency
   scores move in lockstep) that could cause near-singularity on a
   routine basis rather than only during exceptional events?

3. WINDOW LENGTH — 288 BARS:
   The proposal uses a 288-bar window (same as sigma_288) to build
   the correlation matrix. At M5 frequency, 288 bars = 24 hours.
   Is 24 hours the appropriate window for estimating the currency
   correlation structure used in the LDAK penalty? Too short a window
   risks non-stationarity (regime-specific correlations). Too long
   risks missing structural shifts. Is there a principled argument
   for a different window length?

4. WEIGHT EXTRACTION — DIAGONAL OF INVERSE:
   The proposal extracts per-instrument weights as w_i = 1 / D[i][i]
   where D = inv(C). In the original LDAK framework, the exact weight
   for marker j is the j-th diagonal of D = inv(XX^T/m), which equals
   the partial regression coefficient controlling for all other markers.
   Is w_i = 1 / D[i][i] the correct extraction, or should the weight
   be D[i][i] directly (without the inversion)? These are not the same:
   the diagonal of the inverse is not the reciprocal of the diagonal
   of the original matrix.

5. VOLATILITY GATE INTEGRATION:
   The proposal retains the ADR-011 volatility gate:
   S_eff_i = (1 - w_i) * max(V_ratio_i - 1.0, 0)
   When w_i = 1.0 (no correlation penalty), S_eff_i = 0 regardless
   of V_ratio. When w_i < 1.0 (correlated), S_eff_i scales with
   V_ratio excess. Is this integration formula mathematically
   consistent with the original LDAK framework's intent? Specifically:
   does (1 - w_i) correctly represent the "redundancy fraction" that
   should be penalised during volatility spikes?

6. INSTRUMENT vs CURRENCY MAPPING:
   FXMatrix trades EURUSD, GBPUSD, EURGBP — three instruments.
   The LDAK matrix operates on three currencies: EUR, GBP, USD.
   The mapping is:
     EURUSD pod open → penalise EUR and USD weights
     GBPUSD pod open → penalise GBP and USD weights
     EURGBP pod open → penalise EUR and GBP weights
   The current pairwise implementation checks which pods are open and
   applies pairwise penalties. The exact matrix gives per-CURRENCY
   weights. How should the per-currency weights be translated back to
   per-INSTRUMENT penalties? Is it correct to use the weight of the
   WEAKER currency for each instrument (since that's the currency
   being bought/sold against fair value), or should it be the minimum
   of both currencies' weights, or the product?

7. COMPUTATIONAL COST:
   RunSignalOnBarClose() currently computes Pearson r over 288 bars
   for 3 pairs = ~3 x 288 multiplications. The exact matrix requires
   building a 3 x 288 score matrix and computing 9 correlation
   coefficients (3 x 288 multiplications each) plus a 3x3 inversion
   (constant time). Is the computational cost materially higher than
   the current implementation at M5 bar-close frequency? Any risk of
   OnTick() timeout?

8. ANY OTHER FATAL FLAW not listed above.

OUTPUT FORMAT
-------------
For each audit target: state whether it is a PASS, WARNING, or FATAL.
FATAL = implementation must not proceed without a fix.
WARNING = risk exists but does not block implementation.
PASS = no issue found.
For any FATAL or WARNING: state the exact fix required.
Write zero implementation code.
