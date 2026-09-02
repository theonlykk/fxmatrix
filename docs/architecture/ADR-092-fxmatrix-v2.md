# ADR-092: FXMatrix V2 — Simplified Dual-Topology EA, Replacing FXMatrix

**Status: DRAFT — PENDING PHASE 1 AUDIT. Not architecturally locked. Not implemented.**
Per `ARCHITECT.md`, this is a Phase 2 blueprint requiring a full DeepSeek Phase 1 pass and Gemini Phase 3 ruling before any Cursor implementation. This is a larger architectural event than ADR-091's constant swap — a new EA intended to fully replace the currently-deployed one — and gets the full pipeline, not an expedited path.

**Author:** Claude (Lead Engineer), drafted at Khalid's request.
**Date:** 2026-07-13

---

## 1. Background and motivation

This project's engineering history (documented across ADR-074 through ADR-091) added substantial complexity to the live EA over time — kinetic distance-based spacing, a multi-timeframe signal mechanism, `0.03`-lot sizing logic, LDAK cross-pair correlation gating, and several other live-only mechanisms (ADR-090 compression, ADR-078 exit-reset delay, Option B tick-driven `add_next`). **This complexity coincided with declining, unstable performance** — the original impetus for the entire ADR-091 audit cycle was diagnosing why the newer, more complex version was losing money while an earlier, simpler version had been more stable.

**Important epistemic caveat, flagged by DeepSeek's Phase 1 review of this ADR:** this history is correlational, not causal. No controlled test has ever compared the full-complexity EA against the simplified model under identical conditions — the evidence base (five historical windows, extensively validated in ADR-091) was generated entirely *without* the excluded mechanisms present. The inference "complexity coincided with decline, therefore removing complexity is safe" is a reasonable working hypothesis grounded in engineering judgment, not a proven causal claim. This should be stated plainly rather than implied as settled fact.

Independently, and for unrelated reasons (validating ADR-091's corrected grid-spacing geometry), a from-scratch Python simulation (`grid_sim_v7_real_signal.py`) was built and extensively stress-tested: single GBPUSD pair, no kinetic distance, no LDAK, no multi-timeframe logic, no tri-instrument coupling — flat 3-pip LIFO exits, flat-then-exponential add spacing (`WIDEN_RATIO=1.304`/`ADD_PIPS_CEILING=1000`, corrected via the full ADR-091 audit cycle), and the `reload_flat` reload mechanism (bug-fixed, DeepSeek-verified). This model was validated across five distinct historical windows, including the two most stressful available (Truss Crisis, Vaccine Rally), with a clean capital-preservation record (0 DD4 breaches across essentially every combination tested, one demonstrated and well-understood DD3 event).

**The proposal: build a new, minimal EA — `fxmatrix_v2` — that faithfully implements exactly this validated model, and use it to replace the current `FXMatrix.mq5` deployment entirely.** The simplicity is not a limitation to work around — it is the deliberate, evidence-backed design choice, consistent with the project's own history showing added complexity coincided with instability.

---

## 2. Scope: what V2 includes

- **Dual-topology, mirroring the validated `MM_LONG`/`MM_SHORT` structure**: two instances, one long-biased, one short-biased, each trading the full lifecycle independently. Distinct magic numbers from the retired EA (to be assigned).
- **Signal**: the existing, independently-verified term-structure/inversion formula (`ComputeTermStructure`, `InvertSpreadToPrice`) — this part of the live EA was never in question and needs no change.
- **ADR-013's gap-aware entry clamp** — retained. This was independently, numerically verified early in this project to produce strictly better (cheaper) entries, never worse ones, when the theoretical price crosses the current bid/offer. Low-risk, well-understood, worth keeping.
- **Grid spacing**: flat 9-pip floor for the first two adds, then `WIDEN_RATIO=1.304`-based exponential widening (running multiplicative state, matching the confirmed Python mechanism exactly), capped at `ADD_PIPS_CEILING=1000`.
- **Reload mechanism**: `reload_flat` — flat 9-pip floor, unconditional, anchored to the just-exited layer's own entry price, gated on a `last_exit_price` state variable that **must** be cleared on any new Layer-0 entry from flat (the exact bug DeepSeek's Phase 1 audit found and Cursor fixed in the Python reference — this needs its own dedicated unit test in the MQL5 port, not an assumption that porting "the same logic" automatically avoids the same class of bug).
- **Exit**: flat 3-pip LIFO, per-layer from that layer's own entry. (Noted for completeness: today's fidelity check confirmed the live EA's golden-ratio exit decay is already structurally inert under current settings — `BaseThreshold` caps effective spread below the 3-pip floor at every observed depth — so this is not a behavior change from what's already happening in practice, only a simplification of the formula on paper.)

## 3. Scope: what V2 deliberately excludes

- **Kinetic distance-based add spacing** — deliberately excluded, not overlooked. Confirmed via today's fidelity check to dominate 63-97% of shallow-depth (layers 0-2) add decisions in the current live EA — a substantial, unvalidated mechanism this project has never simulated or stress-tested.
- **The multi-timeframe signal mechanism and associated `0.03`-lot sizing logic** — identified as the specific source of the instability that motivated this entire redesign.
- **LDAK** — deliberately deferred, not rejected. See Section 6.
- **ADR-090 compression, ADR-078 exit-reset delay, Option B tick-driven `add_next`, ADR-079 dynamic re-anchor** — none of these have ever been part of what's been validated; excluding them keeps V2's scope matched exactly to the evidence base, rather than reintroducing unvalidated complexity. **Note on ADR-078 specifically**: the defense against a "hyperactive flickering near threshold" critique rests on `reload_flat`'s 9-pip floor acting as an inherent anti-flickering buffer — this is a reasonable inductive argument from the geometry's structure, but has not been directly tested (no simulation has specifically probed threshold-flickering spread costs). Worth being explicit with DeepSeek that this is reasoning-based, not evidence-based, if challenged.

## 4. Prerequisites — required before Phase 1 audit / before any deployment

**4a. Joint dual-topology simulation (new Python engineering work, before MQL5 implementation).** Every existing n=500 result tests `MM_LONG` and `MM_SHORT` as independent, separately-run simulations — never both running concurrently, sharing account equity and margin, on the same historical path. V2's actual deployment runs both simultaneously. This requires the `GridState`-style joint-tracker refactor already scoped for the parked cross-instance-sizing idea (two parallel grid trackers on one shared price path), reused here for a more basic purpose: confirming combined equity drawdown and **combined margin/exposure** (a distinct risk from either instance's individual DD3/DD4) stay within safe bounds when both instances are deep at once — e.g., a whipsaw scenario. **Specifically: track peak concurrent free-margin utilization, checked against FTMO's actual minimum margin requirement** (per Gemini's review) — a margin call can occur before either instance's equity drawdown ever approaches the 4% DD4 threshold, if both instances are simultaneously deep. This should run against all five historical windows already available.

**4b. Real MT5 Strategy Tester validation, once V2 exists in MQL5, is the primary evidence — not Python.** Because V2 has no kinetic distance, no LDAK, and no tri-instrument coupling, a real MT5 backtest of V2 against the same five historical windows (all already extracted, per ADR-091 Section 5d) constitutes a genuinely clean fidelity check — the confounds that invalidated today's comparison (kinetic dominance, tri-instrument scope, LDAK activity) do not apply to V2 by construction. Python's role shifts to fast parameter iteration and design exploration; **V2's own real MT5 backtest results, once available, supersede Python as the authoritative validation.**

**4c. Spread modeling remains an open, uncontrolled variable.** Python assumes a fixed spread (`PAIR_SPREAD_PIPS`); real MT5 uses live bid/ask. This affects even a clean V2-vs-Python comparison and should be explicitly checked, not assumed resolved by V2's other simplifications.

**4d. FTMO account consistency/lot-disproportion rules — unverified.** Should be checked against FTMO's actual terms before any real deployment, independent of how sound the strategy is technically.

**4e. Account lifecycle management.** Whatever account V2 is deployed to needs an explicit plan to avoid the kind of silent, unnoticed expiry that occurred during this project's own fidelity-check work.

**4f. Gap-scenario stress test for `ADD_PIPS_CEILING` (DeepSeek Phase 1 finding — also feeds back into ADR-091).** ADR-091's depth-cap finding (max depth never exceeds 9, across five windows) rests on a Brownian-bridge intrabar noise model layered on historical *bar* data. If that model cannot generate genuinely severe overnight/weekend gap events — as distinct from smooth intrabar movement within already-recorded bars — then "the ceiling never binds" may be an artifact of insufficient gap severity in the simulation, not a true property of real market behavior. **Required before Phase 3:** inject a synthetic severe gap (e.g., 500+ pips overnight) into the simulation and confirm whether `ADD_PIPS_CEILING` binds and whether DD3/DD4 still pass under that condition. This should be added to ADR-091's own open items as well, since it questions an already-locked claim.

**4g. ADR-078 exclusion — concrete flickering test, not just inductive reasoning (DeepSeek Phase 1 finding).** DeepSeek identified a specific, sharper mechanism than originally flagged: a *constant* 9-pip `reload_flat` floor could plausibly be **worse** for flickering than a depth-scaled reload, since it never becomes harder to re-trigger as cycling continues — unlike the original ADR-078 exit-reset delay, which existed specifically to prevent this pattern. **Required before Phase 3:** instrument exit→reload cycle frequency on a genuinely choppy historical window (Q1 2024 Chop is the best available candidate), with and without the 9-pip floor, and confirm cycle counts and cumulative spread cost stay low (DeepSeek's suggested bar: fewer than ~1 excess cycle per day). Cheap to run; should not be skipped on the strength of inductive reasoning alone.

**4h. ADR-013 clamp — re-verify under corrected geometry via direct A/B simulation, not orthogonality reasoning alone (DeepSeek Phase 1 finding).** Run the existing Python sim with and without the ADR-013 clamp, under the corrected `WIDEN_RATIO=1.304` geometry, across all five historical windows. Compare DD3/DD4 counts and mean P&L. If differences are negligible, the clamp's retention is confirmed safe; if not, the interaction needs further scoping. (Note: DeepSeek's estimate that the clamp shifts entries "1-5 pips" does not match this project's own earlier verification — actual broker stops level is 0, and `MIN_DIST=0.00001` already accounts for the effective floor via `MathMax` logic — so the true shift magnitude is almost certainly much smaller. This doesn't change the recommendation to run the A/B test; it just means the concern should be tested empirically rather than assumed large from an outside estimate.)

## 4i. Operational MQL5 implementation guardrails (DeepSeek Phase 1 finding, Section 2f)

Beyond unit testing (Section 2), the fresh MQL5 implementation of `reload_flat`/`last_exit_price` must explicitly guard against:

- **State must be per-instance, never a shared global.** `current_add_pips` and `last_exit_price` must be stored per magic number (e.g., in an instance-specific struct/array), not as shared global variables — a shared global would cause direct cross-instance corruption between `MM_LONG`/`MM_SHORT`-equivalent V2 instances.
- **Order-fill timing must be explicit, not assumed instantaneous.** `last_exit_price` must be set only after a fill is fully confirmed via `OnTradeTransaction()`, not optimistically before confirmation — the Python sim's sequential, time-stepped model has no equivalent to MT5's asynchronous fill confirmation.
- **Partial fills must be handled explicitly.** The Python sim assumes fills at the exact limit price; MT5 pending orders can partially fill. `last_exit_price` and layer volume must reflect actual filled state, not order state.
- **Quoting frequency (tick vs. bar-close) must be explicitly specified, not left implicit.** The draft excludes Option B's tick-driven `add_next`, but doesn't state whether V2's entry/reload quoting itself re-evaluates every tick or only at bar close — this affects whether the ADR-013 clamp could "chase" price with excessive cancel/resubmit cycles. Must be decided and documented before implementation, not discovered during it.
- **Broker minimum stop distance — already confirmed safe for this broker/symbol earlier in this project** (stops level 0, `MIN_DIST=0.00001` correctly accounts for the effective floor), but worth a quick reconfirmation now that the account has changed (`1513973831`), since this is a broker/symbol-level constant unlikely but not guaranteed to be account-invariant.

## 5. Decommissioning the retired EA

"Replace" means: `FXMatrix.mq5` and its associated `MM_LONG`(20260700)/`MM_SHORT`(20260800) instances are removed from any live/demo deployment once V2 is validated and cut over. **`ea/FXMatrix.mq5`, `Globals.mqh`, `ExecutionEngine.mqh`, and ADR-074 through ADR-091 remain in the repository as historical record — not deleted, not archived out of reach.** No ambiguity: V2 is a full replacement operationally, not a deletion of prior work or its documentation.

## 6. LDAK — explicitly deferred to V2.1, not rejected

LDAK's mechanism (Pearson correlation + volatility-ratio stress score) is inherently cross-pair — it cannot function without visibility into peer pairs (EURUSD, EURGBP), which a single-pair V2 does not have. This makes LDAK's inclusion a genuine prerequisite on the still-unbuilt joint 3-pair simulator (ADR-091 Item 8), not an independent feature that can be bolted on separately.

**Decision: V2 launches single-pair first. LDAK becomes V2.1**, scoped and validated once the 3-pair simulator exists.

**Justification (corrected during Gemini's review — the original draft's reasoning was too strong and has been replaced):** this is not because Truss Crisis or any single-pair stress test demonstrates that cross-pair correlation risk is "handled" — a single-pair GBPUSD simulation, however severe, cannot test cross-pair correlated risk at all, since there is no peer pair present to correlate against. Truss Crisis specifically was a GBP-idiosyncratic shock (a UK gilt/fiscal crisis), not a dollar-driven move affecting multiple pairs simultaneously — it is not evidence about LDAK's target risk (a simultaneous USD-driven shock hitting EURUSD and GBPUSD together, per LDAK's original ADR-010 motivation) one way or the other. **The actual justification is simpler and doesn't require that inference: V2 is single-pair by scope, and the risk LDAK exists to address (simultaneous cross-pair accumulation) is definitionally absent when only one pair is trading.** There is no unaddressed risk being deferred past — the risk itself cannot materialize until the eventual multi-pair deployment, at which point LDAK (or its validated equivalent) becomes a genuine prerequisite, not an optional enhancement.

## 7. Open questions for Phase 1 (DeepSeek) / Phase 3 (Gemini)

1. Does the joint dual-topology simulation (Section 4a) reveal any combined-exposure or combined-drawdown risk not visible in the independent per-instance validation?
2. Is retaining the ADR-013 clamp genuinely risk-free in V2's simplified context, or does its interaction with the corrected geometry need independent re-verification (it was originally verified against the *old* `GridExpBase=1.5` geometry)?
3. Is there anything else in the excluded-features list (Section 3) that, on reflection, constitutes a load-bearing safety mechanism rather than avoidable complexity? (LDAK already addressed in Section 6; this question is about the others — kinetic distance, ADR-090, ADR-078, etc.)
4. Same MHT/overfitting caveats as ADR-091 apply here by inheritance — does DeepSeek see any additional statistical concern specific to *simplifying* a system, as opposed to correcting one parameter within it?

---

## 8. Negative space

- Does not modify or remove `ea/FXMatrix.mq5` or any existing ADR documentation.
- Does not include LDAK, kinetic distance, or any of the excluded mechanisms in Section 3 — V2.1 or later work, not this ADR.
- Does not authorize any Cursor implementation. Full DeepSeek Phase 1 and Gemini Phase 3 review required first, per `ARCHITECT.md`.
- Does not resolve the four prerequisites in Section 4 — those must be addressed as part of reaching Phase 3 clearance, not deferred past it.
