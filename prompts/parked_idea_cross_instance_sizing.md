# PARKED IDEA: Cross-Instance Layer-Depth-Informed Sizing

**Status: PARKED — not scheduled, not scoped, no implementation started.**
This document exists so the idea isn't lost, not to propose a timeline. Revisit after the current ADR-B validation work concludes and the live topology (MM_LONG/MM_SHORT) has been running long enough to generate more than two historical windows of evidence.

**Author:** Khalid (concept), written up by Claude.
**Date:** 2026-07-11

---

## 1. The idea

`MM_LONG` and `MM_SHORT` are two independent, locked-direction instances trading the same GBPUSD triad. They are **not hedges of each other** — the proposal does not treat them as offsetting positions. Instead, the idea uses one instance's current layer depth as an **information signal** to adjust the other's position sizing.

**Intuition:** if `MM_LONG` is deep (e.g., 5+ layers), that's evidence the market has been trending against long positions for a while — the same conditions that have historically coincided with `MM_SHORT` cycling more favorably (faster fill/exit cycles, fewer layers). Rather than leaving `MM_SHORT`'s lot size static, scale it up as `MM_LONG`'s depth increases, and mirror the logic in the other direction. Include hysteresis so the sizing doesn't whipsaw on small depth fluctuations near a threshold.

**Grounding in existing evidence:** this isn't speculative — the June-blowup Monte Carlo work already found `MM_LONG` stuck in an unresolved position 83.6% of that window's runtime vs. `MM_SHORT`'s 38.4%, during a trend against long positions. That's consistent with (though not proof of) the mechanism this idea would try to exploit.

**Framing, per Khalid:** this is explicitly *not* about hedging or risk-offsetting between the two instances — it's using one instance's state as a signal to inform a sizing decision on the other. Worth keeping that framing precise in any future write-up, since "sizing up based on trend depth" can otherwise get conflated with directional trend-following, which is a different (and separately debatable) claim.

---

## 2. Sketch of a sizing rule

**Updated 2026-07-11 — superseded by delta-based framing (see 2.1). Kept for history.**

Kept deliberately low-dimensional rather than a per-layer lookup table, specifically to limit the number of free parameters available for a future search to overfit:

```
lot_multiplier(other_depth) =
    min(1 + k × max(0, other_depth − trigger_depth), max_multiplier)
```

Free parameters (illustrative, not yet chosen):
- `k` — sensitivity (how fast the multiplier climbs per extra layer of depth on the other instance)
- `trigger_depth` — depth at which scaling begins (e.g., start scaling only once the other instance is 5+ layers deep)
- `max_multiplier` — hard ceiling on how much size can scale up (a circuit breaker, same spirit as `ADD_PIPS_CEILING`)
- `hysteresis_band` — how much the other instance's depth must move, in either direction, before the multiplier is allowed to change again, to prevent size oscillating on small back-and-forth depth changes near a threshold

Mirrored symmetrically: `MM_LONG`'s size is informed by `MM_SHORT`'s depth, and vice versa.

### 2.1. Superior reframing: signed delta, not absolute depth (Gemini, 2026-07-11)

**Core variable changed from `other_instance_depth` to `delta = MM_LONG_depth − MM_SHORT_depth`** (signed — the sign determines which instance gets scaled up; `abs(delta)` determines the magnitude of scaling. Gemini's original formula used `abs()` only, which loses the directional information needed to know *which* side to scale — this must be signed in any actual implementation.)

**Why this is a genuine improvement, not just a reframing:**
- **Whipsaw circuit breaker.** If a choppy, non-directional market drags both instances deep simultaneously (e.g. `MM_LONG`=6, `MM_SHORT`=5), the old absolute-depth rule would scale *both* up at once — accelerating margin consumption in a regime with no real directional edge. Under delta (`6−5=1`), the multiplier correctly stays near baseline, since the small divergence signals chop, not trend.
- **Partial self-regulation on reversals.** If `MM_LONG` is at 8 and `MM_SHORT` is at 0 (delta=8, `MM_SHORT` maximally scaled), and the market then reverses and drags `MM_SHORT` into its own widening (layers 1, 2, 3...), delta shrinks (8→7→6...) and *each new layer `MM_SHORT` adds* gets progressively less scaling. This is a real improvement over the old design, where new layers during a reversal would keep compounding at max multiplier.

**Caveat, not yet solved — thermostat protects against compounding, not the initial hit.** The self-regulation above only affects the sizing of *new* layers added after delta starts shrinking. It cannot retroactively resize the layer that was already open, at full multiplier, at the moment the reversal began — that layer was sized when delta was at its widest, and takes the initial adverse move at full size before the thermostat has anything to taper. The mechanism bounds how much *worse* a reversal gets as it progresses; it does not eliminate the risk of one maximally-sized layer catching the initial snap. Model this explicitly (seed-level tracing) before treating the delta reframing as a full solve to the reversal-risk concern in Section 6.

**Caveat on margin contention — genuinely improved, not solved.** The delta framing eliminates the worst *correlated* failure mode (both sides deep and both scaled at once, in a whipsaw). It does not reduce margin usage in the design's actual core use case — one side deep, the other scaled up — since that's elevated margin usage on both instances simultaneously by construction, not a bug to be designed away. The margin stress-test recommendation (Section 6) still stands.

---

## 3. Can this be solved in closed form?

No. This is not a problem with a clean analytical solution — the "optimal" parameters depend on the joint, path-dependent distribution of how the two instances' layer depths co-evolve under different market regimes. This is a stochastic/empirical optimization problem, not an algebraic one.

### 3.1. Establishing the delta threshold empirically — cheaper than it looks

Gemini's proposed approach (extract the empirical distribution of `abs(delta)` — 50th/90th/95th/99th percentiles across both historical windows — and set the trigger just outside the "noise ceiling" rather than guessing) is the right instinct: guessing a threshold without the baseline distribution is exactly how these mechanisms get over-tuned.

**Important scoping correction: this does *not* require the full `GridState` joint-tracker refactor (Section 4).** `MM_LONG` and `MM_SHORT` are already run as separate `simulate_one_path()` calls, but — confirmed by Cursor — they share the *same seed* per `(window, seed)` pair, meaning they already trace the *identical* underlying Brownian-bridge price path; they're just not compared live, in-call. The joint-tracker refactor is only required once the sizing decision needs to feed back into the simulation itself (i.e., `MM_SHORT`'s actual behavior changing in response to `MM_LONG`'s depth, mid-simulation). To simply *measure the baseline delta distribution under today's existing, uncoupled dynamics*, all that's needed is:
1. Lightweight instrumentation: log layer-count per bar within the existing separate `MM_LONG`/`MM_SHORT` simulation calls (currently only final/aggregate stats are captured).
2. A small post-hoc script joining the two per-bar depth arrays on `(window, seed, bar_index)` to reconstruct the delta time series, then computing percentiles across both windows.

This is a much smaller ask than the full dual-tracker feature, doesn't touch production, and can be done independently of — and much sooner than — any decision to actually build the coupled feedback-loop feature.

**Overfitting note, unchanged from Section 6:** whatever threshold gets chosen from this extraction is still calibrated against the same two historical windows carrying most of ADR-B's other tuned constants. More principled than guessing, but not a fix for the underlying MHT concern.

### 3.2. Full parameter search (once building the coupled feature)

The existing Monte Carlo harness is the right tool for the eventual sizing-parameter search, but treated as a constrained search, not a derivation:
1. Coarse search (small n, e.g. 10–20 seeds) across a grid of `(delta_trigger, max_multiplier, hysteresis_band)` to find promising regions.
2. Narrow to a small number of candidates.
3. Full n=500 confirmatory run on the finalists, with DD3/DD4 == 0 as a hard constraint (not just a comparison metric) and a risk-adjusted objective (e.g., a Calmar-style ratio) rather than raw mean P&L, so the search isn't rewarded for taking on more tail risk in exchange for more average return.

---

## 4. Structural prerequisite (answered by Cursor, 2026-07-11)

**Confirmed: this structure does not currently exist, and the mental model behind the idea needs a small correction.**

`MM_BOTH` is **not** two concurrent long/short sub-positions on a shared path. It's a **single grid** that races bid vs. offer entry quotes when flat — whichever fills first locks the entire grid's direction for that episode (long wins ties). All position state (`layers`, `current_add_pips`, `last_exit_price`, equity/DD tracking) is a single scalar/list per simulation call. `MM_LONG`, `MM_SHORT`, and `MM_BOTH` today are three **independently-run** `simulate_one_path()` calls, compared only after the fact — there is no cross-read of one side's depth by the other, anywhere in the current codebase.

**What would be needed to build the joint-tracking structure this idea requires:**
- The outer skeleton (one bar loop, one Brownian-bridge price path per bar, shared substep iteration) is already well-suited to running two parallel grid trackers on identical prices — no change needed there.
- The inner position logic would need real restructuring, not a parameter tweak:
  1. Duplicate all per-grid state (two of: `layers`, `current_add_pips`, `last_exit_price`, plus likely separate telemetry).
  2. Rewrite flat-entry gating from a single global `if not layers:` check to a per-side check, since one side may be mid-stack while the other is flat.
  3. Define fill/exit/add precedence for the same tick/bar when both sides are active concurrently (today's "long wins ties" rule only governs *initial* entry in `MM_BOTH`, not two live concurrent grids).
  4. Aggregate combined P&L/drawdown across both stacks.
  5. Add the actual cross-read sizing hook (one side's layer count informing the other's lot size) — genuinely new logic; nothing like it exists today.

**Cursor's rough sizing:** a minimal version (extract a `GridState` dataclass, instantiate two, loop both per substep on the shared path) is "moderate" effort — contained to the inner loop, but touches most of it. Full parity with the live EA's actual slot/cross-pair semantics would be larger, since the EA's slot model is a different axis entirely from v7's single-pair single-stack design.

**Implication for this idea:** it's a real, scoped, buildable feature — not blocked by anything structural — but it's meaningfully more than "add a sizing formula." Before committing effort, worth deciding (per Section 6) whether this is the same work as the already-parked Phase 3.B Correlated Exposure Limits, since building it twice under two different names would be wasteful.

---

## 5. Live implementation sketch (MT5 side, for later)

Cross-instance state can be shared via **MT5 terminal Global Variables** (`GlobalVariableSet()` / `GlobalVariableGet()`) rather than a text file:
- Atomic reads/writes — no risk of one instance reading a half-written value mid-update, unlike file I/O.
- No per-tick disk I/O.
- Persist across EA restarts (terminal-managed), so a restarted instance isn't blind to the other's last-known state.
- Suggested naming: `FXMatrix_GBPUSD_MM_LONG_LayerCount`, `FXMatrix_GBPUSD_MM_SHORT_LayerCount`, updated on every layer add/exit (bar-close cadence), not every tick.
- **Staleness handling needed regardless of file vs. global-variable choice:** pair each depth value with a last-update timestamp, and have the reading instance fall back to baseline lot size if the other instance's last update is older than some threshold (e.g., 2–3 bar-closes) — protects against sizing decisions based on a frozen value if the other instance has crashed or stalled.

---

## 6. Risks and open questions to carry into any future DeepSeek/Gemini pass

- **Overfitting compounds an existing concern.** ADR-B already has `WIDEN_RATIO`, `ADD_PIPS_CEILING`, and the DD thresholds tuned against the same two historical windows (`full_quarter`, `june_blowup`). Adding 3–4 more free parameters, searched against those same two windows, meaningfully increases the degrees of freedom fit to a small, fixed amount of historical data. Before trusting any "optimal" result here: either get a genuine third/fourth historical window with different regime characteristics, or bias hard toward the conservative end of the searched space rather than whatever scores best in-sample.
- **Trend-persistence assumption, once removed.** Even framed as "using one instance's state as an information signal" rather than hedging, sizing up the instance likely to benefit from a continuing trend is still a bet that the trend continues rather than mean-reverts. Khalid's view is that this concern is less serious than an outright hedge-breaking concern, since the two instances were never hedges to begin with — noted here for completeness, not as an unresolved objection blocking the idea.
- **Overlap with parked project work — resolved by Gemini's review: keep separate.** Phase 3.B Correlated Exposure Limits is defensive (suppressing volume to prevent risk aggregation); this idea is offensive (using distress on one side as an alpha signal to amplify volume on the other). Sequence this idea *after* Phase 3.B, not merged into it.
- **Sizing-rule parameterization — Gemini recommends a binary step function** (`if other_depth >= trigger_depth: size = trend_multiplier; else: size = base_multiplier`) over the original continuous slope (`k × max(0, depth − trigger)`), specifically because a continuous slope is a curve-fitting magnet that would map to the exact peak depths of the two available historical windows and fail out-of-sample. This reduces free parameters but changes the risk shape — see below.
- **Compounding reversal risk (Khalid/Claude exchange, refines Gemini's "V-Bottom Reversal Trap"):** the naive worst-case estimate of "a couple of slightly-bigger layers" undersells the actual mechanism for two reasons:
  1. **The step-function design (above) removes gradualism.** Under a binary step, the first fill after the trigger crosses is immediately at full `trend_multiplier`, not incrementally larger. "Slightly bigger" describes the continuous-slope version, not the step-function version Gemini itself recommended — these are materially different risk shapes and the choice should be made deliberately, not have the reassuring framing of one carried over to the other.
  2. **The 300-second bar-close signal delay bounds how fast the multiplier engages, not how many fills accumulate at the elevated size.** The favored instance (e.g. `MM_SHORT` during a sustained down-move) stays shallow and cycles fast *while the trend continues* — its own depth only builds on an adverse excursion against it, i.e. a retracement or the eventual reversal. The multiplier is most fully engaged (because the other instance is deepest) exactly when the trend is most extended — which is also when a sharp reversal is most likely. If that reversal is severe enough to trigger the favored instance's own widening logic, the size multiplier and the widening-exponential curve compound simultaneously from the first widened layer of that episode, not just a couple of flat-sized adds.
  3. **The existing n=500 "clean pass" validation was run at uniform 1x lot sizing.** DD3/DD4 are dollar-drawdown-based, which scales directly with lot size at a given adverse price move. Whether scaled-up layers "stand up alone" at 2–3x size hasn't actually been tested — it's an assumption carried over from base-size validation, not a checked fact.
  - **Net effect:** the honest worst case is closer to Gemini's original V-bottom framing than to a small, bounded worst case — this should be modeled explicitly (seed-level tracing, same method used for the `reload_flat`/`reload_anchor` seed 16/10 analysis) rather than estimated informally, whenever this idea is actually scoped.
- **Two unresolved design questions to pin down before scoping:**
  1. Binary step function vs. continuous slope — pick one, since they imply different worst-case shapes (see above).
  2. Does the multiplier apply only to newly-added layers going forward, or retroactively resize already-open layers too? Not yet specified; materially affects total exposure at any given moment.
- **Margin contention (Gemini):** the eventual DeepSeek Phase 1 audit must include a stress test of simultaneous max-depth (on the informing instance) and max-multiplier (on the sized-up instance) margin drain — gross margin consumption rises non-linearly under that joint condition, not just additively.
- **Governance:** if this moves forward, it should go through the same pipeline discipline as ADR-B — a real DeepSeek Phase 1 pass (this has real MHT/overfitting exposure, now sharpened by the compounding-reversal mechanism above) and a Gemini Phase 3 ruling — before any Cursor implementation, not built directly.

---

## 7. Next steps (not started)

- [x] Get Cursor's answer on Section 4 (joint-tracking structural prerequisite) — **answered: does not exist, moderate effort to build**
- [x] Decide relationship to Phase 3.B Correlated Exposure Limits — **resolved: keep separate, sequence after Phase 3.B (Gemini)**
- [x] Sizing-rule input variable — **resolved: signed delta (`MM_LONG_depth − MM_SHORT_depth`), not absolute depth (Gemini, refined 2.1)**
- [ ] Decide: binary step function vs. continuous slope for the delta-based sizing rule (Section 6 caveats still apply either way)
- [ ] Decide: does the multiplier apply to new layers only, or retroactively resize open ones (unaffected by the delta reframing — still open)
- [ ] **Cheap, decoupled from the rest:** add per-bar layer-count logging to existing `MM_LONG`/`MM_SHORT` runs and extract the empirical delta-percentile distribution (Section 3.1) — does not require the full refactor, doesn't touch production, can be done independently of any decision to build the coupled feature
- [ ] If proceeding with the coupled feature: scope the `GridState` dataclass refactor described in Section 4
- [ ] If proceeding: design the coarse-to-fine parameter search described in Section 3.2, including explicit seed-level tracing of the compounding-reversal scenario (Section 6) — the delta reframing reduces but does not eliminate this risk
- [ ] Before any live implementation: settle on Global Variables vs. file-based cross-instance communication (Section 5 currently recommends Global Variables)
