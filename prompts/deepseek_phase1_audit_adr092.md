# DeepSeek Phase 1 Audit Request — ADR-092: FXMatrix V2

**This is a genuine Phase 1 teardown, not a second pass.** ADR-092 is a new proposal — a new EA intended to fully replace the currently-deployed `FXMatrix.mq5` — and per `ARCHITECT.md` it requires its own full Phase 1 critique before any Phase 3 ruling, even though it inherits a substantial, already-audited evidence base from ADR-091.

You are receiving full context below, not a summary, per `ARCHITECT.md`'s standard.

**Your mandate, unchanged:** hunt for statistical pathologies (MHT, selection bias, regime curve-fitting, look-ahead bias), mechanical flaws (logic leaks, contradictory chains, circular confirmation), and retail heuristics (arbitrary constants, unjustified thresholds). Write zero implementation code. If you find a fatal flaw that invalidates the premise, invoke the Override Rule explicitly.

---

## 1. Background — why this ADR exists

This project's own engineering history (ADR-074 through ADR-091) added substantial complexity to the live EA over time: kinetic distance-based add spacing, a multi-timeframe signal mechanism with associated `0.03`-lot sizing logic, LDAK cross-pair correlation gating, and several other live-only mechanisms. **This complexity coincided with declining, unstable performance** — the impetus for this entire audit lineage was diagnosing why the newer, more complex version was losing money while an earlier, simpler design had been more stable.

Independently — for the unrelated purpose of validating ADR-091's corrected grid-spacing geometry — a from-scratch Python simulation (`grid_sim_v7_real_signal.py`) was built and extensively stress-tested: single GBPUSD pair, no kinetic distance, no LDAK, no multi-timeframe logic, no tri-instrument coupling. Flat 3-pip LIFO exits, flat-then-exponential add spacing (`WIDEN_RATIO=1.304`/`ADD_PIPS_CEILING=1000`, corrected via ADR-091's full audit cycle, DeepSeek Override Rule invoked and resolved), and the `reload_flat` reload mechanism (a genuine bug found and fixed during that same audit — `last_exit_price` not clearing on new-pod entry — independently verified by you). This model was validated across five distinct historical windows including the two most severe available (a 2022 GBP sovereign-crisis collapse, and a sustained multi-month uptrend), with a clean capital-preservation record: 0 DD4 breaches across nearly every combination tested, one demonstrated and mechanistically-understood DD3 event.

**ADR-092 proposes building a new, minimal EA (`fxmatrix_v2`) that faithfully implements exactly this validated model, replacing `FXMatrix.mq5` entirely.**

---

## 2. Specific claims and reasoning to audit

### 2a. The core inference: "the simpler model is the one with the strong evidence base, therefore build it"

Is this inference sound, or does it risk a subtle survivorship/selection bias? The five historical windows were themselves selected (per Gemini's recommendations during ADR-091) to specifically target gaps in prior testing — not randomly drawn. Does building an entire new production system on the back of this evidence base compound whatever selection effects already exist in ADR-091's validation, in a way that a mere parameter correction (ADR-091's actual scope) would not?

### 2b. LDAK deferral reasoning (Section 6) — a self-correction worth your specific scrutiny

An earlier draft of this document justified deferring LDAK to V2.1 partly by arguing that surviving the Truss Crisis window (single-pair GBPUSD) demonstrated the "vertical defense" was sufficient against correlation risk. **This was identified as an invalid inference before this document was finalized** — a single-pair simulation cannot test cross-pair correlation risk at all, and the Truss Crisis window itself was a GBP-idiosyncratic shock (a UK sovereign/fiscal crisis), not the dollar-driven, multi-pair-simultaneous event LDAK was originally built for (per ADR-010's own stated motivation). The corrected reasoning, now in the document: LDAK's target risk (simultaneous cross-pair accumulation) is *definitionally absent* from a single-pair-only deployment, so deferring it isn't leaving a known risk unaddressed — the risk itself cannot occur yet.

**Question for you:** is this corrected reasoning actually sound, or does it contain its own hidden assumption — e.g., does trading GBPUSD alone still carry *indirect* USD-driven correlation exposure worth worrying about even without a peer pair open (since GBPUSD itself is a USD cross), such that "no peer pair, no correlation risk" is too strong a claim?

### 2c. The exclusion list (Section 3) — is anything on it load-bearing?

Kinetic distance, the multi-timeframe/`0.03`-lot sizing logic, LDAK (addressed above), ADR-090 compression, ADR-078 exit-reset delay, Option B tick-driven `add_next`, and ADR-079 dynamic re-anchor are all excluded from V2's scope. **Flagged directly for your attention: the defense against excluding ADR-078** (that `reload_flat`'s 9-pip floor provides an inherent anti-flickering buffer, preventing the hyperactive re-entry/spread-cost problem exit-reset delay exists to solve) **is an inductive argument from the geometry's structure — it has never been directly tested.** No simulation has specifically probed threshold-flickering behavior or its spread cost. Is this defense adequate for Phase 1 purposes, or does it require empirical validation before this exclusion can be trusted?

### 2d. The ADR-013 clamp retention (Section 2, referenced in Section 7)

The gap-aware entry clamp is retained on the reasoning that it only tightens entries (never widens the grid) and was previously verified to produce cheaper, not worse, entries. This verification was originally performed against the *old* `GridExpBase=1.5` geometry, not the corrected `WIDEN_RATIO=1.304`. Gemini's read: the clamp operates at the entry-price level while `WIDEN_RATIO` governs subsequent add-spacing, making the two close to orthogonal, so re-verification isn't necessary. **Question for you:** is "close to orthogonal" actually established, or is this an assumption that should be empirically re-checked before Phase 3 clearance, given the clamp's interaction with the *first* layer entry could still meaningfully shift the anchor point for every subsequent `WIDEN_RATIO`-governed distance in the stack?

### 2e. Prerequisites (Section 4) — are these sufficient, or is something missing?

Four items are listed as required before Phase 3 clearance: (1) a joint dual-topology Python simulation, now including peak concurrent free-margin utilization tracking against FTMO's minimum requirement (added per Gemini's review); (2) real MT5 Strategy Tester validation of V2 itself as the primary evidence, superseding Python, once V2 exists in MQL5; (3) spread-modeling reconciliation (Python's fixed assumed spread vs. real MT5's live bid/ask); (4) FTMO account consistency/lot-disproportion rules, unverified against actual FTMO terms.

**Question for you:** does this list adequately cover what's needed before a new production EA replaces an existing one, or is there a category of risk — statistical, mechanical, or operational — not represented here at all?

### 2f. New MQL5 implementation risk

The `reload_flat`/`last_exit_price` bifurcation logic has never existed in any live MQL5 code before — it will be freshly implemented for V2, not ported from an existing, already-live mechanism. This is explicitly flagged in the document (Section 2) as needing its own dedicated unit-testing discipline, given that the exact class of bug this logic already produced once (in the Python reference) could easily be reintroduced fresh during MQL5 implementation. **Question for you:** beyond unit testing, is there a specific class of MQL5-specific failure mode (tick-driven execution timing, order-fill race conditions, broker-specific quirks) that a Python-to-MQL5 port of this exact logic should be pre-emptively guarded against?

---

## 3. Explicit deliverable requested

For each of 2a–2f: state plainly whether the claim is sound, unsound, or unverifiable given current evidence, and why. Invoke the Override Rule explicitly if you find anything that invalidates the premise of replacing `FXMatrix.mq5` with this design — do not soften a fatal finding into a minor caveat. Where something is merely unverified rather than wrong, say what evidence would be needed to verify it.

**Do not propose implementation code or alternative designs.** That is Phase 2 (Claude blueprint, already largely done in this draft) and Phase 3 (Gemini ruling) territory.

---

## 4. Files provided

| Label | Path |
|---|---|
| `ADR-092-fxmatrix-v2.md` | This document — primary subject of this audit |
| `ADR-091-grid-spacing-geometry.md` | The full, locked evidence base ADR-092 inherits — includes the five-window validation, the depth-cap finding, the LDAK mechanism description, and the DeepSeek/Gemini history this ADR builds on |
| `grid_sim_v7_real_signal.py` | The validated Python reference model ADR-092 proposes porting to MQL5 |
| `parked_idea_cross_instance_sizing.md` | Background on the `GridState` joint-tracker refactor referenced in Section 4a — not itself in scope for V2, but the technical approach V2's joint-topology simulation will reuse |
