# DeepSeek Red Team Prime — Phase 1 Audit Request
## Subject: ADR-091 (Grid Spacing Re-Architecture) — Retroactive Audit

---

## 0. Process note (read first)

Per `ARCHITECT.md`, the mandatory sequence is:
**Phase 1 (DeepSeek teardown) → Phase 2 (Claude blueprint) → Phase 3 (Gemini ruling) → Phase 4 (Cursor implementation).**

**This sequence was not followed for ADR-091.** A ruling was reached and partially validated (Claude + Gemini + Khalid only) before any Phase 1 red-team pass occurred. This document is a retroactive attempt to close that gap. Per ARCHITECT.md's own terms, ADR-091 should not be treated as architecturally locked until this audit completes.

You are receiving full context below, not a summary, per ARCHITECT.md's explicit requirement ("Gemini cannot find poison pills in a problem it doesn't fully understand" — the same standard applies here).

**Your mandate, unchanged from ARCHITECT.md Phase 1:**
- Hunt for **statistical pathologies**: multiple hypothesis testing (MHT) flaws, selection bias, regime curve-fitting, look-ahead/leakage.
- Hunt for **mechanical flaws**: logic leaks, contradictory chains, circular confirmation.
- Hunt for **retail heuristics**: arbitrary constants, rigid thresholds, lack of relative normalization.
- Write **zero implementation code**.
- If you find a fatal flaw that invalidates the premise, say so explicitly — we abort pending pivot, per the Override Rule.

---

## 0.1 Critical fact, confirmed by Cursor: ADR-091 exists ONLY in the Python simulation — it has never been ported to production MQL5

**`WIDEN_RATIO=1.304` and `ADD_PIPS_CEILING=1000.0` exist only in `scripts/grid_sim_v7_real_signal.py` (and the v6 predecessor with the old values).** The live EA — `ea/Globals.mqh`, `ea/ExecutionEngine.mqh`, `ea/MathEngine.mqh` — still runs `GridExpBase = 1.500`, the same value this whole track of work was meant to replace. `ADR-090.md` itself notes the GridExpBase re-architecture is "tracked separately (pending)."

**Implication you should weigh directly:** every result in this document — the n=500 clean pass, the `reload_flat` optionality finding, the entire ADR-091 ruling — validates a construct that does not yet exist in the system actually trading real orders (FTMO demo `1513899460`, `MM_LONG`/`MM_SHORT`). This changes what "passing" means: it is not evidence the live EA is currently safe under this geometry, only that the *proposed* geometry looks safe *in simulation*, in a codebase that has not yet been asked to reconcile it against live-only mechanisms not modeled in Python at all — notably ADR-090's add-spacing compression, ADR-078's exit-reset re-arm logic (`exit_reset_pending`, `g_last_exit_reset_closing_add_next[]`), and Option B's tick-driven `add_next` path (see 2f). Please weigh this as a distinct question from whether the sim's internal math is sound: **is a Python-only construct, however clean its own validation, an adequate basis for a production architectural ruling, given how much live-only logic sits outside the simulated model?**

---

## 1. Background — what ADR-091 is and why it exists

The live EA runs two locked-direction market-making instances, `MM_LONG` (magic 20260700) and `MM_SHORT` (magic 20260800), both trading the full EUR/GBP/USD triad. Grid-spacing behavior for these instances was governed by a bounded-exponential formula with `GridExpBase = 1.5`. This constant's justification was never established — it predates the current audit trail and has been flagged internally (by Claude, not by you) as a legacy retail heuristic with no derivation behind it.

Separately, a Python Monte Carlo simulation track (`grid_sim_v6` → `grid_sim_v7_real_signal.py`) was built to stress-test spacing/reload mechanics against real GBPUSD M5 data (Brownian-bridge intrabar noise, Parkinson-volatility calibration). This work surfaced a specific proposal — replacing `GridExpBase=1.5` with `WIDEN_RATIO=1.304` — described below.

---

## 2. Specific claims and artifacts under audit

### 2a. The `WIDEN_RATIO = 1.304` constant

**How it was derived:** Gemini (Staff Architect) proposed the value to hit a target cumulative-pip bound at layer ~20. Gemini's own estimate for that cumulative distance was ~4,700 pips.

**A bug was found while verifying this**, worth surfacing to you directly: the actual computed cumulative distance under Gemini's proposed formula came out to only ~1,200 pips — traced to `ADD_PIPS_CEILING=100`, a safety cap left over from the old, faster `GridExpBase=1.5` curve, silently flatlining the new, slower curve at layer ~13. After raising the ceiling to 1000 (well above where the new curve naturally plateaus), the uncapped recompute came out to **~3,498 pips** — in the right neighborhood of Gemini's ~4,700 estimate, but not an exact match. This discrepancy was noted but not chased further before implementation.

**Follow-up, independently verified (not just asserted) since this document was first drafted:** Gemini subsequently stated `1.304` was originally solved to make the *pure, untruncated* series `a·(r^n−1)/(r−1)` hit exactly 6,000 pips over 20 layers with `a=9`. We checked this numerically: `a=9, r=1.304, n=1..20` (continuous exponent) sums to **~5,953 pips** — consistent with a 6,000-pip target.

**The actual implemented mechanism has since been confirmed directly against source (Cursor), and it does not match a simple closed-form indexing choice at all.** It's a running multiplicative state variable (`current_add_pips`, initialized at 9.0, multiplied by 1.304 and capped at 1000 after each fill once `len(layers) >= 3`), equivalent to $D_n = 9 \times 1.304^{(n-2)}$ for $n \geq 3$. Independently re-verified numerically: cumulative distance over the first 19 add-steps sums to **3,497.96 pips**, matching the previously-recorded "~3,498 pips" figure to two decimal places. Full derivation and worked per-layer table: see the attached `ADR-091-grid-spacing-geometry.md`, Sections 3a and 4b, which supersede the formula below.

**Formula as originally (incorrectly) stated in this document's first draft, kept here only to show the correction was needed:**
```
[SUPERSEDED — do not use] D_n = 9 × 1.304^(n-1), capped at ADD_PIPS_CEILING = 1000.0
[CONFIRMED against source] D_n = 9 × 1.304^(n-2), capped at ADD_PIPS_CEILING = 1000.0, for n >= 3
```
This was verified to reproduce Khalid's own worked example (buy at 118, then 109, then 100 — first two adds flat) exactly.

**Question for you:** Is `1.304` a principled constant, or is it curve-fit to a target (the ~6,000-pip pure-series bound) that was itself never independently justified — i.e., is this fitting a heuristic to another heuristic? What would a principled derivation of this spacing constant actually look like (e.g., tied to observed volatility, ATR, or historical adverse-excursion distributions), versus picking a number that produces a "nice" cumulative distance?

### 2b. The bifurcation: first-time adds vs. reloads

Gemini's ADR-091 ruling bifurcates spacing logic:
- **First-time adds** (trend defense): governed by the bounded-exponential `WIDEN_RATIO` curve above.
- **Reloads of previously-cleared slots** (chop harvesting): governed by a flat 9-pip floor, unconditionally, regardless of depth.

Notably, this bifurcation **already existed in the codebase** via a `last_exit_price` state variable (`None` during first-time builds and immediately after a successful reload, set only in the single window right after an exit) — no new code was required for this part; it was discovered, not built.

**Question for you:** Is gating "first-time vs. reload" purely on `last_exit_price` state sufficient, or does this create a circular-confirmation risk — e.g., could adverse sequences of fills/exits cause the system to misclassify a reload as a first-time add (or vice versa) under specific fill orderings you'd want us to stress-test explicitly?

### 2c. The `reload_flat` "optionality" finding

**Claim under test:** because our own trading has zero causal effect on future price, being maximally optimistic about the next reload (flat 9-pip floor, no depth-scaling caution) should only ever help an already-open position, never hurt it, relative to the depth-scaled `reload_anchor` variant.

**Original test design:** head-to-head Monte Carlo, **n=20 seeds**, both historical windows (full_quarter, june_blowup), all three modes (MM_LONG/MM_SHORT/MM_BOTH), under the superseded `WIDEN_RATIO=1.5` geometry. `reload_flat` matched or beat `reload_anchor` in 5 of 6 combinations, even at the worst-case seed. The one exception (MM_SHORT/june_blowup) was traced at the individual-seed level: seed 16 showed a clean win for `reload_flat` (3 scalp cycles in 45 minutes vs. 1); seed 10 showed what was described as "a small, gradual cost (~$0.71 of $35 total)."

**This has since been rerun at n=500 under the corrected `WIDEN_RATIO=1.304` geometry — and the original small-sample characterization did not hold up.** 5 of 6 combinations reconfirmed the pattern. But `MM_SHORT`/`june_blowup`'s worst-case cost, at n=500, is **-$16.56** — not the ~$0.71 the n=20 sample suggested. **The n=20 estimate materially understated this combination's real tail risk.** Full detail: attached `ADR-091-grid-spacing-geometry.md`, Section 5b.

**This is now a concrete, demonstrated exhibit for your statistical-pathology mandate, not a hypothetical concern.** We are handing you a documented case where n=20 produced a misleadingly small tail-risk estimate that a 25x larger sample corrected. We think this is directly relevant to two things worth your explicit judgment:

**Questions for you:**
- Given this demonstrated failure of a small-n estimate, how much weight should be placed on *any other* n=20-scale (or smaller) findings elsewhere in this project's history that have not been re-verified at n=500 scale? Is there a principled sample-size floor below which a finding shouldn't be treated as evidence at all, versus treated as a hypothesis requiring confirmation?
- Was the original seed-16/seed-10 narrative (tracing a specific mechanistic story onto two hand-picked seeds) legitimate root-cause analysis, or does the now-revealed gap between $0.71 and $16.56 suggest it was post-hoc storytelling that happened to undersell the very risk it was describing?
- Does the "zero causal effect on future price" premise still license an "optimism can only help" conclusion, given the now-quantified tail cost in this combination — or does it show that path-dependency in exposure/margin terms (re-entering sooner into a still-adverse-moving segment) is a real, not merely theoretical, cost?
- The overall asymmetry (large upside in 5 of 6 combinations, one real tail cost in the 6th) still nets out favorably in aggregate — but is "favorable in aggregate, with a demonstrated worse-than-advertised tail in one specific combination" an adequate basis for adopting `reload_flat` as the default, or does the `MM_SHORT`/`june_blowup` result deserve isolated treatment (e.g., a different reload mode for that specific bias/window combination) rather than a single rule applied everywhere?

### 2d. n=500 validation results (both spacing modes, corrected 1.304 geometry)

**Original draft of this document included only a 6-row `reload_anchor`-only table.** That run did not actually test the `reload_flat` decision this ADR proposes (see the reload-mechanism mismatch, resolved in `ADR-091-grid-spacing-geometry.md` Section 4a). The validation has since been rerun to cover both spacing modes, seed-for-seed comparable:

```
Window        SpacingMode     Mode      Mean P&L    Worst     MaxLayers  DD3 count  DD3%   DD4 count  DD4%
full_quarter  reload_anchor   MM_LONG   $188.40     $94.02    6          0          0.00   0          0.00
full_quarter  reload_flat     MM_LONG   $189.49     $94.49    7          0          0.00   0          0.00
full_quarter  reload_anchor   MM_SHORT  $31.13      $-7.40    8          0          0.00   0          0.00
full_quarter  reload_flat     MM_SHORT  $32.23      $-6.69    8          0          0.00   0          0.00
full_quarter  reload_anchor   MM_BOTH   $261.72     $50.50    7          0          0.00   0          0.00
full_quarter  reload_flat     MM_BOTH   $262.55     $50.74    7          0          0.00   0          0.00
june_blowup   reload_anchor   MM_LONG   $14.48      $7.96     7          0          0.00   0          0.00
june_blowup   reload_flat     MM_LONG   $15.43      $6.78     7          0          0.00   0          0.00
june_blowup   reload_anchor   MM_SHORT  $12.33      $-12.80   6          0          0.00   0          0.00
june_blowup   reload_flat     MM_SHORT  $12.25      $-16.56   6          0          0.00   0          0.00
june_blowup   reload_anchor   MM_BOTH   $20.44      $2.49     7          0          0.00   0          0.00
june_blowup   reload_flat     MM_BOTH   $21.37      $4.37     7          0          0.00   0          0.00
```

**Zero DD4% breaches and zero DD3% incidents across all 12 combinations × 500 seeds = 6,000 total seed-runs.** Pass/fail thresholds (agreed with Gemini via "rule of three" reasoning): 0 breaches = clean pass (true rate bound ~0.6%), 1 = forensic review required, 2+ = hard fail. By this rule, all twelve combinations pass cleanly — including `reload_flat`, the mechanism this ADR actually proposes to adopt.

**Questions for you, specifically because this result is unusually clean:**
- Only **two historical windows** are used (`full_quarter`, `june_blowup`), both of which have been the reference data for this entire project across many months of iteration. Is repeatedly validating new formula changes against the same two windows a form of **implicit overfitting to those specific windows** — i.e., could the "n=500 passes cleanly" result simply reflect that the formula (and everything upstream of it) has been iteratively shaped, across many sessions, to behave well on exactly this data, rather than genuine robustness to unseen regimes?
- Is a **perfectly clean 0/3000** result more likely to indicate genuine robustness, or **insufficient test severity** (e.g., a Monte Carlo noise model — Brownian bridge intrabar, Parkinson-vol calibrated — that doesn't generate tail scenarios severe enough to ever trip DD4%)? What test would you propose to distinguish these two explanations?
- Is there an MHT concern in how many constants/thresholds have been tuned (`WIDEN_RATIO`, `ADD_PIPS_CEILING`, the DD3/DD4 thresholds themselves, `PHI=0.618` — see 2e) against this same pair of windows over the project's history, such that "passing" is close to guaranteed by construction rather than by genuine out-of-sample validity?

### 2e. Other unresolved constants (carried forward, still open)

- **`GridExpBase = 1.5`** — the constant `WIDEN_RATIO` is superseding. Was this legacy value ever justified beyond being a default retail-style heuristic? If not, does that cast doubt on treating "close in value to the old default" as any kind of sanity check for the new constant?
- **`PHI = 0.618`** — flagged as unjustified in earlier project history; still open, still unresolved. Please treat this as in-scope for this audit if it interacts with any of the spacing/reload logic above.

### 2f. Simulation-fidelity caveats relevant to your overfitting assessment

- The simulation is **GBPUSD-only**, justified by an algebraic identity: `score_B - score_C = r_BC`, meaning (per the internal derivation) EURUSD's cross term cancels out of GBPUSD's own bid/offer computation. This has **not been independently checked by you** — worth confirming the identity actually holds under the live signal formula (`FV_combined = 0.50×close[6] + 0.30×close[12] + 0.20×close[48]`) rather than taking the algebra on faith, especially since it's the sole justification for not testing `BIAS_BOTH` at full 3-pair scope.
- **ADR-048 cooldown drag** (a live mechanism affecting Layer-0 resting orders roughly 33–36% of runtime, confirmed via three independent logs) is **not simulated in v7 at all**. This means ~a third of real runtime behavior is absent from the model being validated above.
- **ADR-079 dynamic re-anchor** — confirmed scoped to the `add_next` path only, not Layer-0 bar-close quoting. Recent backtest logs used to establish prior ground truth ran with this **enabled**; a fresh clean reference test ran with it **disabled** (matching source default). These two reference conditions are not the same, and it's not yet established which one the live account is actually running under.

---

## 3. Explicit deliverable requested

For each of sections 2a–2f: state plainly whether you consider the claim **sound, unsound, or unverifiable with the evidence given**, and why. Where you find a fatal flaw invalidating the ADR-091 premise, invoke the Override Rule explicitly and say so — do not soften it into a "minor caveat." Where a constant is unjustified, say what evidence (not what code) would be needed to justify it.

**Do not propose replacement formulas or constants.** That is Phase 2 (Claude blueprint) and Phase 3 (Gemini ruling) territory. Your role here is teardown only.

---

## 4. Files provided for full context

All paths below confirmed to exist by Cursor (repo read, not asserted), except `ADR-091-grid-spacing-geometry.md`, which is newly drafted (this session) and needs to be saved to the repo before this audit is run — see note below.

**Primary document:**
| Label | Path | Note |
|---|---|---|
| `ADR-091-grid-spacing-geometry.md` | *(save to, e.g., `d:\fxmatrix\docs\architecture\ADR-091-grid-spacing-geometry.md` before running the audit — path not yet finalized)* | **This is now the authoritative, Gemini-reviewed specification of the ADR-091 ruling** — supersedes this document's own Section 2 narrative wherever the two differ. Drafted by Claude, reviewed and cleared by Gemini for Phase 1 handoff. Contains the confirmed exponent formula, the resolved reload-mechanism mismatch, the full 12-row n=500 table, and the n=20-vs-n=500 tail-risk finding in full. |

**Core (ADR-091 sim under audit):**
| Label | Path |
|---|---|
| `MathEngine.mqh` | `d:\fxmatrix\ea\MathEngine.mqh` — signal/inversion math (`InvertSpreadToPrice`, `RunSignalOnBarClose`); does **not** contain the ADR-013 clamp |
| `ExecutionEngine.mqh` | `d:\fxmatrix\ea\ExecutionEngine.mqh` — live `PlaceEntryLimit()` / `PlaceNextEntryLimit()` ADR-013 clamp; live `ComputeNextLayerPrice()` (still `GridExpBase=1.5`) |
| `grid_sim_v7_real_signal.py` | `d:\fxmatrix\scripts\grid_sim_v7_real_signal.py` — `WIDEN_RATIO=1.304`, `ADD_PIPS_CEILING=1000.0`, `last_exit_price` bifurcation gate, `reload_anchor`/`reload_flat` branches (lines 216–229 for first-time-add path, lines 207–210 for `reload_anchor`), `adr013_clamp()` mirror (~lines 69–80) |
| `run_v7_n500_validation.py` | `d:\fxmatrix\scripts\run_v7_n500_validation.py` — modified to loop over both spacing modes; produced the n=500 results in section 2d |
| `ARCHITECT.md` | `d:\fxmatrix\docs\architecture\ARCHITECT.md` — governance rules referenced in section 0 |
| `ADR-090.md` | `d:\fxmatrix\docs\architecture\ADR-090.md` — prior (live, shipped) add-spacing compression ADR; explicitly notes GridExpBase re-architecture is "tracked separately (pending)" |
| `SimulationEngine.md` | `d:\fxmatrix\adrs\SimulationEngine.md` |
| `findings_exit_reset_kinetic_anchoring.md` | `d:\fxmatrix\docs\architecture\findings_exit_reset_kinetic_anchoring.md` — kinetic distance, reanchor drift, cooldown/"trading superstition" findings |

**Added on Cursor's recommendation — high priority, directly on ADR-091 scope:**
| Label | Path | Why it matters here |
|---|---|---|
| `deepseek_phase1_audit_adrb.md` | `d:\fxmatrix\prompts\deepseek_phase1_audit_adrb.md` | This document itself — the audit request framing. `ADR-091-grid-spacing-geometry.md` (above) is now the authoritative spec; this document poses the questions. |
| `grid_sim_v6_dynamic_spacing.py` | `d:\fxmatrix\scripts\grid_sim_v6_dynamic_spacing.py` | Pre-ADR-091 baseline (`WIDEN_RATIO=1.5`, `ADD_PIPS_CEILING=100`) — needed for genuine before/after comparison |
| `Globals.mqh` | `d:\fxmatrix\ea\Globals.mqh` | **Live `GridExpBase=1.500`** — the production value ADR-091 has not yet replaced; also holds ADR-090 compression inputs |
| `FXMatrix.mq5` | `d:\fxmatrix\ea\FXMatrix.mq5` | Live reload/re-arm logic (`exit_reset_pending`, `g_last_exit_reset_closing_add_next[]`, Option B tick-driven `add_next` loop) — the real-world mechanism the Python bifurcation is meant to eventually stand in for, and does not currently match code-path-for-code-path |

**Added on Cursor's recommendation — medium priority (evidence/process context):**
- `scripts/compare_reload_anchor_vs_flat.py`, `scripts/trace_divergence_only.py`, `scripts/find_worst_seed.py` — the actual n=20 seed-16/seed-10 evidence cited in section 2c; include if you want DeepSeek checking the raw traces rather than our narrative of them
- `docs/architecture/ADR-078.md` — live exit-reset reload re-arm
- `docs/architecture/ADR-080.md` — live unified add-spacing (`ComputeNextLayerPrice` path)
- `adrs/ADR-013-gap-aware-entry-clamp.md` — formal ADR-013 doc (different folder: `adrs/`, not `docs/architecture/`)

**Note on ADR-091's formal status:** as of this document's original draft, no formal ADR document existed in the repo for this ruling — only chat rulings. **This has since changed**: `ADR-091-grid-spacing-geometry.md` (listed first, above) is a complete, Gemini-reviewed specification, cleared for this Phase 1 handoff. Numbering: originally drafted as "ADR-B" (informal placeholder); renumbered to `091` — the next sequential number after the highest existing shipped ADR (`ADR-090`) — rather than backfilling the unexplained `088`/`089` gap in the existing sequence, to avoid any ambiguity about why those numbers are missing. Still needs to be saved to an actual repo path (suggested: `docs/architecture/ADR-091-grid-spacing-geometry.md`) and added to `DOCS_TO_INCLUDE` before running the audit script.

---

## 5. Open threads this audit should inform

- **Gemini's deferred question**: assuming n=500 passes cleanly (it has, for both spacing modes), should final ADR-091 specs be drafted immediately, or is a cross-currency correlation test required for `BIAS_BOTH` first? No test design exists yet for the latter — if you consider the GBPUSD-only justification (2f) shaky, that bears directly on this decision.
- ~~Whether the `reload_anchor` vs. `reload_flat` comparison must be rerun under `WIDEN_RATIO=1.304`~~ — **done; see 2c and 2d.** The comparison held up in aggregate but revealed a materially understated tail risk in one combination. This is now itself something for you to weigh, not an open procedural gap.
- **Whether ADR-091 can be considered architecturally locked** once this audit completes, or whether your findings require a further Claude blueprint revision and a second Gemini ruling pass before Cursor implementation proceeds.
- **Production porting plan** — not modeled here at all. Even a clean Phase 1 pass on the simulated geometry doesn't address how this reconciles with ADR-090, ADR-078, and Option B's tick-driven `add_next` once/if this is ever ported to `ea/`. See `ADR-091-grid-spacing-geometry.md` Section 7–8 for the full list of unmodeled live-only mechanisms.
