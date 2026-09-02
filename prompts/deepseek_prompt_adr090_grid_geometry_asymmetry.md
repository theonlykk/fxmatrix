# DeepSeek Red Team Prompt — Grid Geometry Asymmetry & ADR-090

## Your role (per ARCHITECT.md)

You are DeepSeek R1, Red Team Prime. Your mandate: adversarial,
statistically rigorous critique. No implementation code. Hunt
specifically for:
- **Statistical pathologies**: multiple hypothesis testing, selection
  bias, regime curve-fitting, look-ahead bias.
- **Mechanical flaws**: logic leaks, contradictory chains, circular
  confirmation.
- **Retail heuristics**: arbitrary constants, rigid thresholds, lack
  of relative normalization.

This prompt covers three linked findings and one shipped ADR. If you
find a fatal flaw invalidating the premise, say so explicitly and we
abort/revise rather than proceed. Full source files and prior ADRs are
attached alongside this prompt (see FILES_TO_AUDIT / DOCS_TO_INCLUDE)
— read them, don't take our summary below as ground truth on its own.

---

## Finding 1 — Exit/add-spacing structural asymmetry

**Claim:** exit distance is functionally pinned near a fixed floor
regardless of layer depth; add-spacing grows exponentially. The two
are structurally decoupled in a way that produces a specific failure
mode.

**Mechanism:** `ComputeExitPriceDeterministic()` uses
`E_n = effective_spread * PHI^(layer_index+1)` where `PHI≈0.618`. Since
`PHI<1`, this term *shrinks* with depth, so the `MinLayerExitPoints`
floor (30 points = 3 pips) binds at nearly every layer regardless of
depth. Meanwhile `ComputeGridInterval()` under production settings
(`DebugEnableGridMode=true`, `GridMode=2`) grows linearly through
layer 2, then compounds exponentially at `GridExpBase=1.5` per layer
from layer 3 onward.

**Cumulative distance required to reach a given layer** (production
config, computed from the formula, not simulated):

| Layer | Cumulative pips required |
|---|---|
| 2 | 30 |
| 5 | 116 |
| 8 | 404 |
| 10 | 917 |
| 14 | 4,665 |
| 19 (the 20th layer) | 35,463 |

**External grounding:** GBPUSD's actual range over the relevant ~25
years is approximately $2.1100 (Nov 2007 peak) to $1.0327 (Sept 2022
all-time low) — roughly 10,770 pips, total, across the Global
Financial Crisis, Brexit, and the 2022 mini-budget crisis combined.
Layer 19 requires a single uninterrupted move more than 3x this entire
historical range. Layer 14 alone requires 43% of it.

**Red-team this:**
- Is the GBPUSD historical-range grounding actually the right
  comparison, or does it improperly conflate "this specific pair's
  historical range" with "the theoretical bound on what's possible"?
  A regime change (different vol regime, different rate environment)
  could in principle produce ranges outside prior history — how much
  should that qualify the "layer 19 is fictional" claim?
- Is `PHI=0.618` in the exit formula and `GridExpBase=1.5` in the add
  formula independently justified, or are they retail-heuristic
  "golden ratio" choices with no derivation beyond "this number is
  aesthetically/numerologically appealing"? We do not have a
  first-principles derivation for either constant. Flag this
  explicitly if it's load-bearing for anything downstream.

---

## Finding 2 — Add-spacing compression (shipped as ADR-090)

**Mechanism:** New toggle-gated compression applied to the *final*
combined add-distance (`A_n`) in `ComputeNextLayerPrice()`:
`A_n_final = max(MinAddDistancePoints_in_price, A_n_original * AddSpacingMultiplier)`.
Does not alter `ComputeGridInterval()` or `ComputeKineticDistance()`
internals — wraps their combined output only.

**Empirical results** — 2-week backtest, 2026.05.18–06.01, three
instances (`MM_LONG` locked-long, `MM_SHORT` locked-short, `BIAS_BOTH`
unlocked), sensitivity sweep at four points:

| Instance | 3pip baseline | 6pip exit floor | 0.75x add-compress | 0.5x add-compress | 0.33x add-compress |
|---|---|---|---|---|---|
| `MM_LONG` P&L | $30.50 | $49.33 (1 stuck) | $35.07 | $53.69 | $69.83 |
| `MM_SHORT` P&L | $24.24 | $33.26 (1 stuck) | $28.90 | $31.55 | $40.96 |
| `BIAS_BOTH` P&L | $50.66 | $48.10 (1 stuck) | $55.09 | $55.56 | $59.22 |

**Widening the exit floor (6pip) was tested first and produced a null/
negative result**: stuck-position count roughly tripled (1→3 of 9
instance×symbol combinations) despite realized win rate barely moving
(98%→96-99%). We attribute this to survivorship bias in the win-rate
statistic — it only measures trades that closed, and is blind to
positions that failed to resolve at all within the window. **This
6-pip result was abandoned**; add-compression (tightening, not
widening) was tested instead based on a different hypothesis (more
layers per unit of adverse movement = more chances to hit the still-
fixed exit target).

**Compression benefit is monotonic across all three multipliers
tested (0.75x/0.5x/0.33x), with no plateau or reversal** — 0.33x beats
0.5x beats 0.75x on every single instance. Win rates stayed in a tight
97.4-98.9% band throughout (i.e., the improvement is coming from more/
larger realized resolutions, not from trading away win rate). No
compression level introduced any new stuck position beyond one
pre-existing case (`MM_SHORT`/GBPUSD, present at every floor and every
compression level tested, unchanged).

**ADR-090 locked in 0.5x, not the empirically stronger 0.33x**, as a
deliberate conservative choice given `GridExpBase` remains unbounded
(a separate, not-yet-implemented fix). This was an architectural
judgment call, not a backtest-maximizing one.

**Red-team this:**
- **This is one 2-week window.** Every multiplier was tested on
  *identical* market data (2026.05.18–06.01). A monotonic improvement
  across three points on one path is consistent with either (a) a
  real structural improvement, or (b) curve-fitting three free
  parameters to one specific historical sequence. We have not tested
  this compression mechanism on any other window. How much should this
  concern you, and what would you need to see to be satisfied it's not
  regime-specific?
- Multiple hypothesis testing: we tested exit-floor widening (failed),
  then add-spacing compression at three separate multipliers (all
  "succeeded" to varying degrees). Does testing multiple interventions
  sequentially until one works raise a selection-bias concern here,
  even though the failed one (6pip) was reported rather than hidden?
- `MinAddDistancePoints=90` (9 pips) — is this independently justified,
  or chosen because it "felt right" as roughly 3x the exit floor? We
  do not have a derivation for why 9 specifically, as opposed to 6 or
  12.

---

## Finding 3 — Account-level hedge validation (Phase 1 topology)

**Claim under test:** does `MM_LONG`/`MM_SHORT` (dual locked-direction
instances) actually deliver its core promised benefit — that when one
instance is stuck in an adverse trend, the other instance's
simultaneous profit offsets it at the *account* level, even though
neither instance individually avoids the failure mode?

**Episode tested:** `MM_SHORT`'s GBPUSD position, 2026.05.18–05.26,
reaching layer 5 (add-compression run, 0.5x). This is the one
persistent stuck case referenced in Finding 2.

**We give you our full methodology trail, including two errors we
caught and corrected, rather than only the final number** — this
process is itself something to audit, not just the endpoint:

1. First estimate: summed adverse distance across all 24 `add_next`
   log events for this position, including repeated re-touches of the
   same layer index (the position oscillated layers 2↔3 multiple times
   before deepening). Result: **$219**. **Wrong** — double/triple-
   counted layers that were the same underlying position touched
   multiple times, not 24 distinct open positions.
2. Corrected to use only the 6 *distinct* layers actually open
   simultaneously at the single worst moment (2026.05.25 18:15:24).
   Result: **$67.79** for `MM_SHORT`/GBPUSD alone. This part we believe
   is sound.
3. Compared against `MM_LONG`'s *realized-only* GBPUSD gains to that
   same moment ($30.05): implied a "$37.74 shortfall". **Wrong framing**
   — ignored `MM_LONG`'s own concurrently-open unrealized positions and
   the other two symbols (EURUSD, EURGBP) entirely on both instances.
4. First full-account attempt: summed unrealized P&L across both
   instances, all three symbols, using `abs()` distance for every open
   layer. Result: **-$67.73 (0.68% drawdown)**. **Wrong** — `abs()`
   treats every open layer as a loss regardless of direction; since
   `MM_LONG` is all-BUY and `MM_SHORT` is all-SELL, the same price move
   helps one and hurts the other, and summing both as losses
   double-penalizes the account.
5. **Corrected, properly-signed calculation** (BUY: current−entry;
   SELL: entry−current; one shared current-price proxy per symbol
   rather than a different one per instance): **net account equity
   change at the peak moment = +$14.69 (+0.15%)**. This is the number
   we currently trust.

**Per-symbol breakdown at the peak moment** (both instances combined):
GBPUSD net -$43.84 (the hedge did NOT fully offset on this pair
specifically), EURUSD net -$3.39 (near-cancellation), plus $73.36
already realized across both instances by that point → net +$14.69
overall. **The portfolio-level hedge worked because of diversification
across three symbols, not because any single pair's hedge was clean.**

**Red-team this:**
- **This is a single episode, single window, single currency triad
  (EUR/GBP/USD).** Does one existence proof of the hedge working
  constitute meaningful validation of the mechanism, or is this
  exactly the kind of single-path result that should not be
  generalized without testing across genuinely distinct macro regimes?
- The "current price proxy" methodology uses the nearest prior
  `add_next` event's anchor price as a stand-in for live tick price at
  the peak moment, for each symbol. How much error could this
  introduce, and is it symmetric (equally likely to overstate or
  understate the true unrealized figure) or does it have a systematic
  bias in one direction?
- We found and corrected two real errors in our own methodology before
  arriving at +$14.69. Should this shake confidence in the final
  number, or does the correction process itself (catching abs() vs
  signed P&L, catching double-counted layers) increase confidence that
  remaining errors are less likely? Argue this both ways.
- EURGBP showed small losses on *both* instances simultaneously at the
  peak moment (-$5.15 and -$6.29) — not investigated further. Is this
  plausibly explainable as noise from choppy/non-trending price action
  (both directions' entries slightly underwater at one snapshot), or
  does simultaneous same-direction loss on opposite-direction positions
  indicate a modeling error we haven't caught?

---

## What we are NOT asking you to do

Do not propose implementation code for any fix. Do not model the
`GridExpBase` bounding fix (ADR-B) — that is separate, future work with
its own gather/design phase. Do not re-derive the exit/add formulas
from scratch — audit the ones presented. Your output should be
critique, not a redesign.
