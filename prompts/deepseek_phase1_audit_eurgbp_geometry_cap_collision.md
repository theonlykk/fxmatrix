# Phase 1 Audit Request — EURGBP Derived Geometry: Cap Collision & Spread-Friction Risk

## Role reminder
This is a Phase 1 Red Team submission per ARCHITECT.md. Mechanical and
mathematical audit only — no implementation code in the response. The
Staff Architect has already reviewed the finding and directed two
specific stress-tests before any implementation is considered. This
submission is scoped to exactly those two questions, not a general
re-review of the geometry finding itself.

## Background — confirmed, not in dispute
`pair_validation_pipeline.py`'s n=500 dual-geometry Monte Carlo found
that EURGBP's production `AddPipsFloor=9.0` — a GBPUSD-anchor value,
copied across all three pairs rather than derived per-pair — is far
wider than warranted by EURGBP's own measured volatility
(`vol_ratio=0.294` vs GBPUSD). Sweep-derived `AddPipsFloor=2.3` shows
+46.1% average uplift in mean realised P&L across all five canonical
windows (including `june_blowup`, a genuine out-of-sample holdout),
DD3/DD4 clean throughout. Confirmed mechanism: `$/scalp` is identical
(0.237) between production and derived geometry in every window — the
uplift is entirely from higher scalp volume (derived max layer depth
8-10 vs production's 4-7), not larger individual scalps.

This is NOT yet approved for implementation. Two specific risks must
be modeled first.

## Terminology disambiguation — two unrelated "floors," do not conflate
1. **`AddPipsFloor`** — the grid geometry constant under discussion in
   this audit. Controls the minimum pip spacing between add/reload
   layers (grid density). This is what pair_validation_pipeline.py's
   sweep derives per-pair. Currently 9.0 in production for all three
   pairs; sweep proposes 2.3 for EURGBP specifically.
2. **`InpPassivityBuffer` / `V2_L0DynamicHalfSpread`'s floor** — a
   completely separate mechanism from ADR-097/098/099 (the depth-
   triggered easing feature), which prevents the L0 entry quote from
   sitting inside a widened live spread. Unrelated to grid spacing.
   Question 2 below is about whether tighter `AddPipsFloor` spacing
   interacts with this floor in any way — confirm they are genuinely
   independent, do not assume so.

## Question 1 — Cross-instance cap collision (Gemini's primary directive)

Both the GBP cap (`fxmatrix_v2_gbp_cap.mqh`, production threshold 12)
and the EUR cap (`fxmatrix_v2_eur_cap.mqh`, production threshold 10)
gate EURGBP's widening adds. Both thresholds were calibrated (see
ADR-100 for the EUR cap's derivation) against EURGBP's CURRENT
production geometry — the EUR cap's threshold=10 specifically was set
with ~25% headroom above an observed maximum of ~8 layer-units under
the EXISTING wider grid.

**The concern:** if `AddPipsFloor` is compressed to 2.3, EURGBP's
natural layer depth shifts to 8-10 as ROUTINE behavior (confirmed by
the validation data itself — `max_layers` 8-10 across normal
backtested conditions, not a stress tail). This is at or above the
already-calibrated EUR cap threshold of 10. Two failure modes to
model explicitly:

a. **Stale calibration.** Does adopting the derived geometry
   invalidate the EUR cap's threshold=10 calibration outright, since
   that calibration's input data (observed exposure under the OLD,
   wider geometry) would no longer describe reality under the NEW
   geometry? If EURGBP's own normal operation now regularly approaches
   or exceeds 10 layer-units, the cap would begin firing as a routine
   throughput limiter rather than a rare tail-risk circuit breaker —
   a fundamentally different operational character than what was
   designed.

b. **Parasitic consumption.** Because EURGBP is the sole dual-cap
   participant (GBP cap shared with GBPUSD, EUR cap shared with
   EURUSD), does EURGBP's now-routinely-deeper stacking risk
   consuming shared cap headroom in a way that blocks GBPUSD's or
   EURUSD's OWN widening adds more often than either pair's own
   individual calibration ever accounted for? Trace the actual gate
   logic in `V2_AnyCapBlocksNewAdd()` and `V2_GbpNetExposure()` /
   `V2_EurNetExposure()` to determine whether this is a real
   mechanical risk or a theoretical one given realistic layer-depth
   distributions.

Do not propose a new threshold value — the question is whether the
EXISTING calibrated thresholds (12, 10) remain valid assumptions if
this geometry ships, and if not, what would need to be re-derived
before it could.

## Question 2 — Spread-to-grid friction (Gemini's second directive)

At `AddPipsFloor=2.3`, the distance between grid layers approaches
EURGBP's raw broker spread. Model:

a. What is EURGBP's typical/observed spread in pips (from the same
   validation data or production telemetry, if available), and how
   close is 2.3 pips of layer spacing to that spread in relative
   terms? Quantify "close," don't just assert it.

b. Confirm explicitly whether `AddPipsFloor` (grid spacing) and the
   `InpPassivityBuffer`/`V2_L0DynamicHalfSpread` floor (a genuinely
   different mechanism, see disambiguation above) interact in any way
   — e.g. does a tighter grid change how often the L0 entry quote's
   passivity floor actually binds, or are these mechanically
   independent as they appear to be from the code?

c. During a genuine spread-widening event (news, thin liquidity), does
   a 2.3-pip grid risk having add/reload layers priced so close
   together that normal bid/ask noise or slippage could turn the
   confirmed 0.237 $/scalp edge negative on a meaningful fraction of
   fills? This is a slippage/execution-cost question, not a signal-
   quality one — the validation data used ideal/zero-latency
   execution assumptions (per the Strategy Tester settings used all
   session), which would not capture this risk at all. State plainly
   whether the existing n=500 validation can speak to this risk (it
   likely cannot, given its execution assumptions) or whether this
   requires a separate, dedicated check.

## What Red Team must NOT do
Do not write implementation code. Do not propose a specific
implementation of geometry, cap threshold, or any other change — this
audit's job is to determine whether Questions 1 and 2 represent real
blocking risks, theoretical-but-manageable ones, or non-issues, and
what (if anything) would need to be independently re-verified before
this geometry could proceed to implementation. Flag anything that
should block this from a Staff Architect ruling.
