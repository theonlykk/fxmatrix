# DeepSeek R1 Audit — ADR-024: FXMatrix V3 Generic Triad Architecture
# Role: Adversarial Quantitative Red Team
# Classification: Phase 1 Teardown — No implementation code

---

## YOUR ROLE

You are DeepSeek R1, the adversarial quantitative red team for the FXMatrix
EA project. Your job is to tear apart the proposed V3 mathematical
generalisation looking for fatal flaws. You are NOT here to be helpful. You
are here to find the poison pills.

Hunt for:
- Mathematical errors in the generalised score decomposition
- Edge cases where the generic formula diverges from the V2 EUR/GBP/USD result
- Circular confirmation or look-ahead in the inversion math
- Carry formula errors in the generic triad
- LDAK cross-correlation indexing failures
- Any condition where V3 with EUR/GBP/USD inputs does NOT reproduce V2
  pip-precision results

Output format per finding: PASS / WARNING / FATAL
Close with: CLEARED FOR GEMINI REVIEW or ABORT

---

## SYSTEM CONTEXT

FXMatrix is a native MQL5 Expert Advisor implementing always-on two-sided
passive market making across a 3-currency triad. V2 is hardcoded to
EUR/GBP/USD. V3 must generalise to any configurable triad (A/B/C) while
producing mathematically identical results when A=EUR, B=GBP, C=USD.

The mandatory validation gate: V3 with EUR/GBP/USD inputs must produce
pip-precision identical backtest results to V2. Any mathematical divergence
is a logic error, not a tuning difference.

---

## V2 CURRENT MATH (EXACT — do not assume, audit against this)

### Inputs
Two observable log-return signals, computed from bar closes:

```
r_EU = log(EURUSD_now / EURUSD_12bars_ago)   // EUR return vs USD
r_GB = log(GBPUSD_now / GBPUSD_12bars_ago)   // GBP return vs USD
```

USD is the implicit common denominator in both pairs.

### Score Decomposition (V2 exact code from MathEngine.mqh)

```
usd = -(r_EU + r_GB) / 3.0
eur =   r_EU + usd
gbp =   r_GB + usd
```

scores[0] = eur
scores[1] = gbp
scores[2] = usd

### What this math actually does

From r_EU = log(EUR/USD) and r_GB = log(GBP/USD):
  eur - usd = r_EU   →  eur = r_EU + usd
  gbp - usd = r_GB   →  gbp = r_GB + usd

We have 2 equations, 3 unknowns. The system is underdetermined by 1 degree
of freedom. V2 resolves this by imposing the constraint:

  eur + gbp + usd = 0   (zero-sum normalisation)

Substituting:
  (r_EU + usd) + (r_GB + usd) + usd = 0
  r_EU + r_GB + 3*usd = 0
  usd = -(r_EU + r_GB) / 3

This is the V2 constraint. It is NOT an economic truth — it is an
arbitrary normalisation that makes the system solvable. V3 must
either preserve this exact constraint or prove any alternative
produces mathematically identical scores when the same pairs are used.

---

## V3 PROPOSED GENERALISATION

### Generic triad: currencies A, B, C
### Observable pairs: AB, AC, BC (all three cross-rates observed)

V2 used only 2 pairs (AC and BC — i.e. EURUSD and GBPUSD where C=USD).
EURGBP (pair AB) was used only for LDAK and order execution, NOT for
signal computation. This is a critical V2 architectural fact.

### Proposed V3 signal inputs (two pairs, C as base)

For backwards compatibility with V2, V3 signal computation will use the
same two-pair approach:
```
r_AC = log(PairAC_now / PairAC_12bars_ago)   // A return vs C
r_BC = log(PairBC_now / PairBC_12bars_ago)   // B return vs C
```

### Proposed V3 score decomposition

Constraint preserved: score_A + score_B + score_C = 0

From:
  score_A - score_C = r_AC
  score_B - score_C = r_BC
  score_A + score_B + score_C = 0

Solving:
  score_C = -(r_AC + r_BC) / 3
  score_A =  r_AC + score_C
  score_B =  r_BC + score_C

### Validation claim

When A=EUR, B=GBP, C=USD:
  r_AC = r_EU,  r_BC = r_GB
  score_C = -(r_EU + r_GB) / 3 = usd   ✓
  score_A = r_EU + usd = eur            ✓
  score_B = r_GB + usd = gbp            ✓

V3 formula is algebraically identical to V2 under EUR/GBP/USD substitution.

---

## V3 PROPOSED INVERSION MATH

### V2 InvertSpreadToPrice — what it does

Given (strongest, weakest) currency indices and a target spread T,
it computes the physical FX price at which that spread would be observed,
anchored to prices 12 bars ago.

V2 has 6 hardcoded routing branches. Each branch:
1. Identifies the instrument (EURUSD, GBPUSD, or EURGBP)
2. Computes a price using the relevant anchor

Exact V2 branches (from MathEngine.mqh):

```
strongest=0(EUR), weakest=1(GBP) → EURGBP SELL
  EG_history = anchor_EU / anchor_GB
  price = EG_history * exp(-T)

strongest=1(GBP), weakest=0(EUR) → EURGBP BUY
  EG_history = anchor_EU / anchor_GB
  price = EG_history * exp(T)

strongest=0(EUR), weakest=2(USD) → EURUSD SELL
  price = anchor_EU * exp(-T)

strongest=2(USD), weakest=0(EUR) → EURUSD BUY
  price = anchor_EU * exp(T)

strongest=1(GBP), weakest=2(USD) → GBPUSD SELL
  price = anchor_GB * exp(-T)

strongest=2(USD), weakest=1(GBP) → GBPUSD BUY
  price = anchor_GB * exp(T)
```

Note: T is the spread magnitude (scores[weakest] - scores[strongest]),
which is always negative (weakest < strongest by definition of the signal).
So exp(-T) > 1 and exp(T) < 1 for SELL signals, and vice versa for BUY.

### V3 Generic Inversion

Given slots [0,1,2] for currencies [A,B,C] and pairs [AB, AC, BC]:

The instrument traded is determined by (strongest, weakest) pair:
- (A,B) or (B,A) → pair AB
- (A,C) or (C,A) → pair AC
- (B,C) or (C,B) → pair BC

The anchor prices used for inversion:
- Pair AB: anchor_A / anchor_B  (cross derived from the two base-C anchors)
- Pair AC: anchor_A             (direct)
- Pair BC: anchor_B             (direct)

Where anchor_A = PairAC_12bars_ago_mid, anchor_B = PairBC_12bars_ago_mid

Generic inversion formula:

```
If instrument = pair AB (A vs B):
  base_price = anchor_A / anchor_B
  if SELL (A strongest, B weakest): price = base_price * exp(-T)
  if BUY  (B strongest, A weakest): price = base_price * exp(T)

If instrument = pair AC (A vs C):
  base_price = anchor_A
  if SELL (A strongest, C weakest): price = anchor_A * exp(-T)
  if BUY  (C strongest, A weakest): price = anchor_A * exp(T)

If instrument = pair BC (B vs C):
  base_price = anchor_B
  if SELL (B strongest, C weakest): price = anchor_B * exp(-T)
  if BUY  (C strongest, B weakest): price = anchor_B * exp(T)
```

### Validation claim — inversion

When A=EUR, B=GBP, C=USD, anchor_A=anchor_EU, anchor_B=anchor_GB:

- Pair AB = EURGBP: base = anchor_EU/anchor_GB = EG_history ✓
- Pair AC = EURUSD: base = anchor_EU ✓
- Pair BC = GBPUSD: base = anchor_GB ✓

All six V2 branches map directly to the generic formula. ✓

---

## V3 PROPOSED CARRY GENERALISATION

### V2 carry formula (CarryEngine.mqh exact)

```
EURUSD_fwd = entry_price_eurusd * (1 + r_EUR * t) / (1 + r_USD * t)
GBPUSD_fwd = entry_price_gbpusd * (1 + r_GBP * t) / (1 + r_USD * t)
```

Then scores recomputed from fwd prices using same decomposition:
```
r_EU_fwd = log(EURUSD_fwd / ref_eu)
r_GB_fwd = log(GBPUSD_fwd / ref_gb)
usd_fwd  = -(r_EU_fwd + r_GB_fwd) / 3
eur_fwd  =   r_EU_fwd + usd_fwd
gbp_fwd  =   r_GB_fwd + usd_fwd
new_spread = scores_fwd[weakest] - scores_fwd[strongest]
```

### V3 generic carry

```
PairAC_fwd = entry_price_AC * (1 + RateA * t) / (1 + RateC * t)
PairBC_fwd = entry_price_BC * (1 + RateB * t) / (1 + RateC * t)

r_AC_fwd = log(PairAC_fwd / ref_AC)
r_BC_fwd = log(PairBC_fwd / ref_BC)
score_C_fwd = -(r_AC_fwd + r_BC_fwd) / 3
score_A_fwd =   r_AC_fwd + score_C_fwd
score_B_fwd =   r_BC_fwd + score_C_fwd
new_spread = scores_fwd[weakest] - scores_fwd[strongest]
```

Where ref_AC = layer.entry_price_AC_1h, ref_BC = layer.entry_price_BC_1h
(the 12-bar-ago anchors stored at Layer 0 entry time).

### Validation claim — carry

When A=EUR, B=GBP, C=USD:
  PairAC_fwd = EURUSD_fwd ✓
  PairBC_fwd = GBPUSD_fwd ✓
  Score decomposition identical ✓

---

## V3 PROPOSED LDAK GENERALISATION

### V2 LDAK — what it does

Computes pairwise Pearson correlations between the 3 instruments'
log-return series (24 bars). Three correlation scalars:
  g_r_EU_GU = PearsonR(EURUSD returns, GBPUSD returns)
  g_r_EU_EG = PearsonR(EURUSD returns, EURGBP returns)
  g_r_GU_EG = PearsonR(GBPUSD returns, EURGBP returns)

Computes volatility ratios per instrument:
  g_vratio_EU = sigma_24(EURUSD) / sigma_288(EURUSD)
  g_vratio_GU = sigma_24(GBPUSD) / sigma_288(GBPUSD)
  g_vratio_EG = sigma_24(EURGBP) / sigma_288(EURGBP)

Grid dilation in ComputeGridInterval() for instrument slot k:
  For each OTHER instrument j with open inventory:
    v_eff = max(vratio[k], vratio[j])
    S     = max(corr[k,j], 0) * max(v_eff - 1, 0)
    S_eff = max(S_eff, S)
  dilation = min(1 + S_eff^2, LDAK_Dilation_Max)

The cross-instrument correlation matrix is 3x3 symmetric with zero
diagonal. Only 3 unique values needed: corr[0,1], corr[0,2], corr[1,2].

### V3 generic LDAK

```
g_corr[3]    // g_corr[0]=corr(pair0,pair1), g_corr[1]=corr(pair0,pair2),
              // g_corr[2]=corr(pair1,pair2)
g_vratio[3]  // g_vratio[k] = sigma_24(pair_k) / sigma_288(pair_k)
```

Correlation index mapping:
  corr(slot 0, slot 1) = g_corr[0]
  corr(slot 0, slot 2) = g_corr[1]
  corr(slot 1, slot 2) = g_corr[2]

For instrument slot k, grid dilation:
```
S_eff = 0
for j in {0,1,2} where j != k and inventory[j].size > 0:
    corr_idx = correlation_index(k, j)   // see mapping above
    v_eff = max(g_vratio[k], g_vratio[j])
    S = max(g_corr[corr_idx], 0) * max(v_eff - 1, 0)
    S_eff = max(S_eff, S)
dilation = min(1 + S_eff^2, LDAK_Dilation_Max)
```

Correlation index lookup:
```
corr_index(k, j):
    if   (k==0 && j==1) || (k==1 && j==0): return 0
    elif (k==0 && j==2) || (k==2 && j==0): return 1
    elif (k==1 && j==2) || (k==2 && j==1): return 2
```

### Validation claim — LDAK

When slots 0=EURUSD, 1=GBPUSD, 2=EURGBP:
  g_corr[0] = g_r_EU_GU ✓
  g_corr[1] = g_r_EU_EG ✓
  g_corr[2] = g_r_GU_EG ✓
  g_vratio[0] = g_vratio_EU ✓
  g_vratio[1] = g_vratio_GU ✓
  g_vratio[2] = g_vratio_EG ✓

---

## WHAT YOU MUST AUDIT

### AUDIT POINT 1 — Score decomposition zero-sum constraint
Is `score_A + score_B + score_C = 0` a valid normalisation for any
arbitrary currency triad, or does it introduce bias when the triad
is not USD-anchored? Does the zero-sum constraint hold economically for
triads like AUD/NZD/JPY? Are there conditions (e.g. carry differentials,
crisis regimes) where imposing zero-sum on non-USD pairs produces
systematically wrong signal direction?

### AUDIT POINT 2 — Two-pair vs three-pair signal
V2 and V3 (as proposed) use only 2 observable pairs (AC and BC) for
signal computation, deriving the AB cross synthetically. V3 has access
to the actual AB pair price. Is there a mathematical reason to INCLUDE
the observed AB price in the signal computation rather than treating it
as purely synthetic? What bias does the two-pair approach introduce when
the observed AB cross diverges from the synthetic cross (anchor_A/anchor_B)?

### AUDIT POINT 3 — Inversion sign convention
In the SELL branch for pair AB:
  `price = (anchor_A / anchor_B) * exp(-T)`
T is scores[weakest] - scores[strongest], which is negative by definition
(weakest score < strongest score). So -T > 0 and exp(-T) > 1.
For a SELL, we expect the price to be ABOVE fair value (we sell above mid).
Does exp(-T) > 1 correctly push the price above the anchor cross-rate?
Verify the sign convention is consistent across all 6 routing branches.

### AUDIT POINT 4 — Synthetic cross anchor derivation
The V3 pair AB anchor is derived as `anchor_A / anchor_B =
PairAC_12bars_ago / PairBC_12bars_ago`. This is a synthetic cross
construction. Is this arithmetically exact, or does it introduce rounding
error compared to using the directly observed PairAB_12bars_ago price?
For the V3 validation gate, does this matter?

### AUDIT POINT 5 — Carry formula interest rate convention
V2 uses simple interest: `(1 + r * t)`. Is simple interest the correct
convention for FX forward pricing at the sub-1-year horizons this EA
operates at, or should it be continuous compounding `exp(r * t)`? Does
the choice of convention affect the V3 validation gate (it must match V2
exactly, so the convention used must be IDENTICAL in both)?

### AUDIT POINT 6 — LDAK correlation index mapping
The proposed correlation_index(k,j) lookup is a hardcoded 6-branch
symmetric function. Verify that for all 6 permutations of (k,j) with
k≠j and k,j ∈ {0,1,2}, the function returns a valid index in {0,1,2}
and that it is symmetric (corr_index(k,j) == corr_index(j,k)).
Enumerate all 6 cases explicitly.

### AUDIT POINT 7 — LDAK lot size penalty duplication
The LDAK penalty is applied in TWO places in V2: once in
`ComputeGridInterval()` (grid dilation) and once in `HandleEntryFill()`
(lot size weight `w = 1/(1 + S_eff^2)`). These use the SAME S_eff
calculation but apply it differently. In V3 with generic slot indexing,
is there a risk that the corr_index() lookup produces different S_eff
values in the two locations due to the per-instrument conditional
structure? Verify the S_eff calculation is invariant between the two call
sites when generalised to slots.

### AUDIT POINT 8 — Three-pair signal generalisation for non-USD triads
The proposed V3 signal uses only PairAC and PairBC (C as the base
currency). For EUR/GBP/USD this means EURUSD and GBPUSD (both USD-quoted),
which is exact. For a triad like AUD/NZD/JPY with C=JPY, the pairs would
be AUDJPY and NZDJPY. Is there a meaningful difference in signal quality
or mathematical validity when C is JPY vs USD? Is there a degenerate case
where the choice of C as denominator breaks the zero-sum constraint or
produces undefined behaviour (e.g., if PairAC_12bars_ago = 0)?

### AUDIT POINT 9 — V3 validation gate achievability
The validation gate requires "pip-precision identical backtest results."
Given that V3 with EUR/GBP/USD inputs uses `anchor_A/anchor_B` as a
synthetic EURGBP anchor (instead of V2's directly observed EURGBP price
stored in `anchor_EU/anchor_GB`), is pip-precision identity actually
achievable? Or does the synthetic cross introduce unavoidable floating
point divergence that will fail the gate even if the math is correct?
State explicitly whether the gate should be "pip-precision" or "within
broker tick size."

---

## FILES AUDITED

The following V2 source files were reviewed to produce this audit prompt:
- Globals.mqh
- LayerStruct.mqh
- MathEngine.mqh (RunSignalOnBarClose, InvertSpreadToPrice,
  ComputeGridInterval, ComputeExitSpreadTarget)
- CarryEngine.mqh (RunCarryRecalculation)
- ExecutionEngine.mqh (HandleEntryFill, ComputeNextLayerPrice, LDAK block)
- FXMatrix.mq5 (OnTick signal loop)

---

## ARCHITECT RULINGS ALREADY IN PLACE (do not re-litigate)

- Gemini has approved V3 architecture and T2 telemetry approach
- Nuke & Pave is mandated for V3 deploy (no JSON migration shim)
- DeepSeek audits the math BEFORE Gemini sees the formula
- Validation gate is pip-precision EUR/GBP/USD backtest match
- ADR-025 (Phase 3 telemetry) is deferred until ADR-024 is complete

---

## OUTPUT FORMAT

For each audit point 1-9:
  Label: AUDIT POINT N
  Finding: PASS / WARNING / FATAL
  Reasoning: [your adversarial analysis]
  If WARNING or FATAL: Required fix before implementation proceeds

Close with overall verdict:
  CLEARED FOR GEMINI REVIEW
  or
  ABORT — [reason]
