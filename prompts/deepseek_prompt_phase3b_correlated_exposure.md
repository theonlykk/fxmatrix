# Phase 3.B — Correlated Exposure Limits: DeepSeek Red Team Audit

**Phase:** 1 (DeepSeek Teardown, Red Team Prime)
**Rule:** No implementation code in this phase. This document contains a
design proposal and open mathematical questions only — not MQL5 code,
not pseudocode intended for direct translation. Your job is to find the
statistical pathologies, mechanical flaws, and retail heuristics in the
proposal below, per ARCHITECT.md's Phase 1 mandate. If you find a fatal
flaw that invalidates the premise, invoke the Override Rule explicitly
and state it — do not soften it into a suggestion.

---

## 1. Architecture Context

FXMatrix V3 runs three independent MQL5 EA instances against the same
EUR/GBP/USD triad, segregated by magic number:

| Instance | Bias | Home chart |
|----------|------|------------|
| MM | BIAS_BOTH | EURGBP,M5 |
| SNIPER_LONG | BIAS_LONG_ONLY | GBPUSD,M5 |
| SNIPER_SHORT | BIAS_SHORT_ONLY | EURUSD,M5 |

Each instance internally trades all three legs of the triad (Generic
Triad Architecture) regardless of its home chart. Each instance
maintains its own inventory (`g_inventory_0/1/2`), its own drawdown
throttle (`ComputeLDAKLotSize`, ADR-042/061), and its own directional
gate (`DirectionalBias`, ADR-058/062). **Critically: the three
instances have zero runtime awareness of each other's positions.**
Each computes its own signal, sizing, and risk decisions in complete
isolation from the other two.

Existing risk controls, all scoped to a single instance/pod:

- **LDAK drawdown brake** (`ComputeLDAKLotSize`, ADR-042/061): refuses
  or clamps lot size based on that instance's own unrealized PnL vs its
  own balance.
- **Kinetic Gate** (ADR-057): widens/narrows grid-deepening distance
  based on that instance's own read of recent volatility.
- **DirectionalBias enforcement** (ADR-058/062): prevents a
  SNIPER instance from taking a position contrary to its configured
  bias, enforced at three points (signal-suppression, Phase-3 resume,
  and an execution-layer backstop in `PlaceEntryLimit`/
  `PlaceNextEntryLimit`).

None of these controls have any concept of net exposure *across* the
three instances. That is the gap Phase 3.B is meant to close.

---

## 2. The Problem — Live Evidence, Not Hypothetical

A live telemetry aggregation built this session (Pipshed dashboard,
`/api/telemetry/aggregate`) confirmed the following actually occurred,
not as a constructed test case:

- MM independently built a GBPUSD short position across 4 layers.
- SNIPER_SHORT independently built its own GBPUSD short position
  across 3 layers.
- Two of these entries — one from each instance — landed within 0.466
  seconds of each other at nearly identical prices, each instance
  reacting to the same underlying market move with zero knowledge of
  the other.
- Net result at time of observation: **-0.14 lots net short GBPUSD**,
  **-0.01 net short EURUSD**, **+0.04 net long EURGBP** — all computed
  post-hoc from telemetry, not gated in real time by anything.

Each instance's own risk math was individually correct. The aggregate
outcome — three independently-managed books stacking correlated
directional risk on the same underlying pair — was invisible to all
three of them and to any single-instance risk control.

---

## 3. Proposed Design (Claude draft — for adversarial review only, not locked)

### 3.1 Net exposure computation

For each of the three physical symbols (EURUSD, GBPUSD, EURGBP), sum
signed lot exposure across all three instances:

```
net_exposure[symbol] = Σ (instance.direction[symbol] × instance.lot_size[symbol])
  for instance in {MM, SNIPER_LONG, SNIPER_SHORT}
```

This part is already implemented and validated in the Pipshed telemetry
aggregation layer (Python, off-EA, informational only). **It is not
currently computed inside the EA itself**, and therefore cannot gate
anything in real time — any live risk control needs this computed
in MQL5, synchronously, before a new order is placed.

### 3.2 USD-denominated delta conversion — OPEN QUESTION, two candidate approaches

The original design intent (per prior session notes) was a **USD
delta** limit, not a raw lot-count limit — the idea being that risk
should be measured in a common currency, not in symbol-agnostic lot
units. This is where the design is least settled and most in need of
adversarial scrutiny.

**Candidate A — naive per-symbol lot cap, no currency conversion:**
Simply cap `|net_exposure[symbol]|` per symbol independently, with no
attempt to express exposure in a common USD-equivalent unit. Simple,
but arguably doesn't achieve the stated goal — a 0.10 lot EURGBP
position and a 0.10 lot GBPUSD position do not carry equivalent USD
risk, and this approach treats them as if they did.

**Candidate B — true USD-delta via triangulated decomposition:**
EURUSD and GBPUSD each have a direct, unambiguous USD leg:

```
usd_delta(EURUSD position) = -direction × lot_size × contract_size × price_EURUSD   (long EUR = short USD)
usd_delta(GBPUSD position) = -direction × lot_size × contract_size × price_GBPUSD   (long GBP = short USD)
```

EURGBP has **no direct USD leg** and requires triangulation. A
candidate decomposition treats a EURGBP position as economically
equivalent to a simultaneous EURUSD position and an offsetting GBPUSD
position (since EURGBP ≈ EURUSD / GBPUSD):

```
usd_delta(EURGBP position) ≈ 
    +direction × lot_size × contract_size × price_EURUSD     (implied long/short EUR leg)
  + (-direction) × lot_size × contract_size × price_GBPUSD    (implied opposite GBP leg)
```

**This decomposition is asserted here, not proven.** It is exactly the
kind of cross-pair conversion where sign errors are easy to introduce
and hard to notice, since a wrong sign produces a plausible-looking
number rather than an obviously broken one. DeepSeek should verify
this independently rather than accept it, including checking:

- Whether `contract_size` should be constant across all three pairs or
  needs per-symbol adjustment (lot sizing conventions can differ).
- Whether using current live price vs. entry price for the conversion
  introduces any timing/staleness distortion.
- Whether summing `usd_delta(EURUSD) + usd_delta(GBPUSD) +
  usd_delta(EURGBP)` produces genuine double-counting of the same
  underlying EUR/GBP risk, given EURGBP's decomposition already
  reuses the other two pairs' price levels.

### 3.3 Gating mechanism

Two distinct behaviors, not one binary switch:

1. **Heat-reducing trades always proceed at full size**, regardless of
   which instance initiates them. A trade is heat-reducing if it moves
   `net_exposure[symbol]` (or `usd_delta`, depending on which measure
   is adopted per 3.2) toward zero, regardless of instance identity —
   this is a deliberate departure from a static "SNIPER_SHORT always
   privileged" rule, since the actual privileged side should be
   whichever direction currently reduces net heat, dynamically.
2. **Heat-adding trades scale down continuously** as the relevant
   exposure measure approaches a configured limit, reaching zero size
   at the limit itself (recovering a hard cutoff as the limiting case,
   rather than a discontinuous jump from full size to blocked).

The continuous-dampening choice was made specifically to avoid two
failure modes: (a) a binary gate fully disabling a directionally-biased
instance (SNIPER_SHORT, say) for extended periods purely because
another instance's independent activity happened to fill first, and
(b) allowing directional risk to compound without limit right up until
a hard wall, encouraging exactly the kind of "chase the trend harder as
it extends" behavior that motivated this design in the first place.

---

## 4. Known Risk Areas — Explicit Targets for Adversarial Attack

**4.1 — Data integrity precondition (highest priority).** A confirmed,
live, unfixed race condition exists in the codebase (ADR-014 opposing-
quote substitution): under a specific timing race, the broker can end
up holding both a BUY and a SELL position on the same symbol within a
single instance, while that instance's internal inventory struct still
records a single uniform `.direction` value across all its layers (the
newer, race-affected fill inherits the wrong direction label rather
than reflecting its own actual fill). **Every net-exposure and USD-
delta calculation in this design reads directly from that struct.** If
this race has ever fired in a way that's gone undetected, Phase 3.B's
gating decisions would be computed from data that silently
misrepresents actual broker-side exposure — a real position could be
invisible to the gate, or a phantom exposure could suppress a trade
that shouldn't be suppressed. This needs to be resolved or at minimum
independently bounded (e.g. an explicit consistency check between
struct-derived exposure and broker-reported net position per symbol)
**before**, not alongside, Phase 3.B's gating logic goes live.

**4.2 — Retail heuristic risk: threshold justification.** Whatever
numeric limit is chosen for `net_exposure` or `usd_delta` — has not yet
been proposed with any justification tied to account size, margin
requirements, FTMO's own daily/absolute drawdown limits (2%/3% soft,
3.5%/4.5% hard tiers already implemented via ADR-055), or historical
realized volatility of the actual pairs traded. A limit picked as a
round number with no derivation is precisely the "arbitrary constant"
class of flaw this phase exists to catch.

**4.3 — Circular confirmation / inter-pod dependency risk.** Once one
instance's entries are throttled based on what the *other two*
instances are currently holding, the three instances are no longer
truly independent — a state change in one instance's inventory now
feeds into another instance's sizing decision on the next tick. Does
this introduce any oscillatory or self-reinforcing pattern? E.g., could
suppression on Instance A cause Instance B to fill more, which further
suppresses Instance A, in a way that produces systematically different
(and unintended) capital allocation across the three pods over time
compared to their fully-independent baseline behavior?

**4.4 — Interaction with existing LDAK drawdown throttle (ADR-061).**
`ComputeLDAKLotSize()` already reduces lot size based on that
instance's own drawdown and cross-pair correlation (`S_eff`/`w`).
Phase 3.B's continuous dampening (3.3) would be a **second**,
independent lot-size reduction layered on top, computed from a
different signal (cross-instance exposure rather than single-instance
drawdown). Does compounding two independent multiplicative throttles
produce a lot size that's still sensibly calibrated, or could the two
reductions combine in a way that either (a) is so aggressive the grid
effectively stops deepening under moderate conditions (recall: this
session already found and fixed one case of the grid silently failing
to deepen, ADR-061 — a second, unrelated mechanism producing the same
symptom would be a serious regression risk), or (b) rounds to the same
`MinLot` floor regardless of actual severity, making the second
throttle's precision illusory?

**4.5 — Statistical pathology check (per standard Phase 1 mandate).**
Confirm explicitly whether anything in this design has any exposure to
look-ahead bias, target leakage, or multiple-hypothesis-testing
concerns. This is an execution-layer risk control, not a backtested
signal, so these may not apply — but confirm rather than assume, since
the exposure-limit *design itself* was not backtested against
historical data before being proposed here, and if any historical
analysis is later used to justify the threshold in 4.2, that analysis
would need its own scrutiny at that time.

---

## 5. What DeepSeek Must Produce

Per ARCHITECT.md Phase 1: no implementation code, no MQL5, no Python.
Output should be:

1. A direct verdict on whether section 3.2's USD-delta decomposition
   (Candidate B) is mathematically sound as stated, including explicit
   identification of any sign error, double-counting, or missing term.
2. A recommendation between Candidate A and Candidate B (3.2), or a
   third alternative, with the reasoning made explicit — not just an
   assertion of which is "better."
3. A direct answer on whether section 4.1 (the ADR-014 race
   precondition) constitutes a fatal flaw requiring the Override Rule,
   or whether it can be safely bounded/mitigated well enough to proceed
   with Phase 3.B design work in parallel.
4. Explicit findings — confirmed present, confirmed absent, or
   uncertain — for each of sections 4.2 through 4.5.
5. Any additional statistical, mechanical, or heuristic flaw not
   already named above that a rigorous adversarial read surfaces.

If a fatal flaw is found under the Override Rule, state the specific
premise that must be abandoned or reworked, and what pivot (if any)
would resolve it — do not simply flag it and stop.
