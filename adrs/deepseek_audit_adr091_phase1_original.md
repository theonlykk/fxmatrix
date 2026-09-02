# DeepSeek R1 Audit Report

## Internal Reasoning

We need to perform a Phase 1 DeepSeek teardown audit of ADR-091, focusing on statistical pathologies, mechanical flaws, and retail heuristics. The context is extensive: we have full codebase, documentation, and specific claims.

Key areas to examine:
- The derivation of WIDEN_RATIO = 1.304, its justification, and whether it's curve-fitted.
- The bifurcation between first-time adds and reloads, and the state variable last_exit_price.
- The reload_flat vs reload_anchor validation, especially the n=20 vs n=500 discrepancy and the MM_SHORT/june_blowup tail risk.
- The n=500 clean pass result: overfitting concerns, insufficient test severity.
- MHT issues with multiple constants tuned against same windows.
- Simulation fidelity gaps (GBPUSD only, missing live mechanisms).
- The identity proof for GBPUSD-only scope (score_B - score_C = r_BC) - not independently verified.
- PHI = 0.618 unresolved, and its interaction with spacing.
- PHI appears in skew formula and ad spacing; is it retail heuristic?
- The claim that "reload_flat can only help, never hurt" might be false due to path dependency in margin/exposure; the MM_SHORT/june_blowup result shows a real cost.
- The constant ADD_PIPS_CEILING = 1000.0: was it chosen to avoid truncation or to fit a target? Could there be a bias from previous ceiling of 100? 
- Check if the n=500 result is truly independent: same two windows used repeatedly across project history -> implicit overfitting.
- Are there any lookahead biases in simulation? The signal computation uses current close vs FV, but that's correct. Brownian bridge conditioning on future close is present but acceptable per SimEngine.md. However, for the purpose of validating spacing, the bridge paths might not generate enough extreme moves to test tail risk; 0 DD4% could be due to insufficient noise amplitude.

Also check for mechanical flaws:
- The last_exit_price state: could it be mis-set? The description says it's set after exit, and cleared after a reload. But what if multiple exits happen without a reload? That should be fine. However, if a reload fails (e.g., price never hits the flat 9-pip level), the last_exit_price remains set, and subsequent adds from the currently deepest layer would still use reload logic? Need to examine the code logic in sim. In grid_sim_v7_real_signal.py, the condition "if spacing_mode in ("reload_anchor", "reload_flat") and last_exit_price is not None" then use that path. But if last_exit_price is set and a first-time add occurs (i.e., no layers, then layer 0 entry from flat), does that incorrectly use reload logic? The sim code: only checks last_exit_price when layers exist. The entry from flat (when layers empty) does not use last_exit_price. So it's okay. However, if a partial exit leaves some layers, and then a first-time add (for deeper layer) occurs after a full pod exit? Actually after full pod exit, last_exit_price is set from the last exit? That would be a problem: after full pod exit, the next entry from flat is a fresh position, but last_exit_price is not None, so when a subsequent layer is added (after entry), it would incorrectly use reload logic instead of first-time widening. But the sim's code for entry from flat does not set last_exit_price, and after full pod exit, last_exit_price is set by the exit. Then when a new layer-0 is entered, layers become non-empty, and on the next add (layer 1) the code checks if last_exit_price is not None – it is, because it's still set from the previous pod! This is a bug: the last_exit_price state is not cleared when a new pod starts. It should be cleared when the first layer of a new pod is entered. The sim code does not clear last_exit_price upon first-layer entry. The description says "None during first-time builds and immediately after a successful reload", but the implementation may not enforce that. Let's check sim code:

In simulate_one_path:
- When a layer is added (from flat or via add), the code does:
  if spacing_mode in ("reload_anchor", "reload_flat"):
      last_exit_price = None   # only when a new layer is added via the add path (line ~167 in provided code?)
Let's locate: The provided code snippet in grid_sim_v7_real_signal.py lines for add:
  if hit:
    layers.append(...)
    if spacing_mode in ("reload_anchor", "reload_flat"):
        last_exit_price = None  # YES, cleared when a reload actually fires.
But for entry from flat (the Layer 0 fill), there is no such clearing. So after a pod fully exits, last_exit_price is set from that exit's closed layer entry price. Then on a new bar, entry from flat occurs, layers become non-empty, but last_exit_price remains the old value. Then later, when an add (layer 1) triggers, the code will see last_exit_price is not None and will use reload logic (flat 9-pip or anchor) instead of first-time widening. This is a mechanical flaw: the state variable persists across pods incorrectly.

This is a critical bug that invalidates the simulation results for the reload scenarios across pod boundaries. The sim should clear last_exit_price when a new entry from flat occurs.

Check: In the "if not layers:" block (entry from flat), there is no line setting last_exit_price = None. Indeed, the code only sets last_exit_price = None inside the add-hit block. This is a clear bug.

Additionally, in the reload path, the add_target uses last_exit_price as the anchor. If last_exit_price is stale from a previous pod, the add distance will be computed relative to an irrelevant price, potentially much further away or closer, skewing results.

Thus, the ADR-091 reload validation results may be tainted by this stale-state bug. The n=500 clean pass may not hold after correction. This is a fatal flaw.

Now also check the reload_anchor depth logic: depth_mult = WIDEN_RATIO ** (len(layers) // 3). This uses integer division, so at layers=0,1,2 depth_mult=1; 3,4,5 -> exponent 1; 6,7,8 -> exponent 2, etc. That's a discrete step function, which could cause sudden jumps in spacing. Not necessarily wrong but worth noting.

Other aspects:
- PHI=0.618 appears in ComputeSkew mode 2 and also as 0.618^(layer+1) in exit formula. This is indeed a retail heuristic (golden ratio) with no fundamental justification tied to market behavior. It persists.
- The add spacing formula in HandleEntryFill uses A_golden = E_n * 1.618, which is effectively PHI * (1+PHI?) Actually 1.618 is the golden ratio. So it's using retail heuristics. The proposed WIDEN_RATIO does not replace that; it replaces only the first-time add spacing, but the legacy path still uses golden ratio if toggle off. So the overall system still has retail heuristics.
- The derivation of 1.304 was initially to achieve 6000 pips cumulative over 20 layers, but that target was itself arbitrary (not tied to risk limits, volatility, or account size). It's a heuristic fitted to a heuristic. The corrected formula produces ~3500 pips cumulative, which still is arbitrary.
- The n=500 clean pass: only two windows, both used for iterative tuning. This is a classic overfitting pattern. The test design is insufficient to demonstrate out-of-sample robustness.
- The simulation uses a Brownian bridge which is known to be too smooth; the Parkinson-vol calibrated sigma may still underrepresent intra-bar extremes. The fact that no DD4% events occurred suggests the stress scenarios are not severe enough.
- MHT: Multiple constants (WIDEN_RATIO, ADD_PIPS_CEILING, PHI, GridBase, etc.) tuned against same data without correction. The pass/fail thresholds (3% and 4% drawdown) themselves were set arbitrarily? They are used as validation metrics, but they aren't independent; they were set before seeing results? Likely. But the fact that they are never triggered means the test is not discriminating.
- The ADR-091 document itself acknowledges these caveats but still proposes moving forward. The simulation-fidelity gaps (ADR-090 compression, ADR-078, Option B, cooldown drag, dynamic reanchor) are not modeled. These could change spacing geometry behavior significantly.
- The GBPUSD-only justification via identity score_B - score_C = r_BC: This is algebraically true for the zero-sum decomposition given the definitions. r_BC = ln(BC_now / FV_BC). score_B - score_C = r_BC - 0? Let's verify: from MathEngine, scores[2]=score_C = -(r_AC+r_BC)/3, score_B = r_BC + score_C. Then score_B - score_C = r_BC. So yes, the spread between BC and C scores equals the r_BC signal. That is correct algebraically. However, the cross instrument's spread score_A - score_B = r_AB. But the simulation only uses GBPUSD. The identity holds, but it doesn't justify that the grid behavior under GBPUSD-only is representative of the full triad. Because signal strength and spread dynamics differ across pairs. So it's an assumption.

Given these, I need to produce a Phase 1 audit report. I must evaluate each claim as sound, unsound, or unverifiable, and state if fatal flaw invalidates premise. The stale-state last_exit_price bug is fatal for the reload validation. Additionally, the overfitting and insufficient test severity mean the n=500 clean pass is not reliable evidence of robustness. The derive of WIDEN_RATIO is a retail heuristic curve-fit. The reload_flat decision is based on flawed simulation (stale state) and thus its validation is unsound.

I will write the audit explicitly flagging these.

## Final Report

## Phase 1 Red Team Audit — ADR-091 Grid Spacing Re-Architecture

### Override Rule: **FATAL FLAW FOUND — Premise Invalidated**

The combination of a **stale-state bug** in the `last_exit_price` simulation logic and **systemic overfitting / insufficient test severity** renders the primary validation evidence (n=500 clean pass, reload_flat optionality finding) unreliable. The derived `WIDEN_RATIO = 1.304` constant is a retroactively justified retail heuristic, not a principled parameter. The ADR’s stated premise — that the proposed geometry is safe and optimal for production — cannot be sustained on the evidence provided. **Abort pending architectural pivot.**

Detailed findings follow per the requested sections.

---

### 2a. `WIDEN_RATIO = 1.304` Constant — **UNSOUND**

- **Original derivation:** Target cumulative 6,000 pips over 20 layers with a=9 — an arbitrary target not tied to any external constraint (account size, risk limits, volatility profile, adverse-excursion distribution). This is **curve-fitting a heuristic to a heuristic**, not a principled derivation.
- **Actual cumulative under confirmed formula:** 3,498 pips, not 6,000. The claimed target was missed by ~42%. The explanation that the "implemented mechanism was never intended to match the pure-series target" retroactively redefines the design goal, making the original derivation misleading.
- **No independent justification:** No connection to empirical volatility, ATR, or historical adverse-excursion data from the actual instruments traded. The constant is chosen entirely from simulation convenience.
- **`ADD_PIPS_CEILING = 1000.0`:** Raised from 100.0 to prevent truncation of the new curve. The old ceiling (100.0) was discovered to have silently capped the curve at layer ~13 — a dangerous hidden assumption. The new ceiling (1000.0) is set well above the natural plateau (binding first at layer 20), which is a safe choice *per se*, but it was chosen *enabling* the chosen `WIDEN_RATIO` to reach the target cumulative, not from independent reasoning.

**Verdict:** Unsupported. A principled derivation would tie spacing to observable quantities (volatility, inventory risk, or stop-out levels) and would be validated out-of-sample. Here, a single number was picked to hit an arbitrary cumulative distance, then the formula was adjusted *post hoc* when the actual cumulative fell short.

---

### 2b. Bifurcation via `last_exit_price` — **MECHANICAL FLAW**

- **Stale-state bug (FATAL):** The simulation (`grid_sim_v7_real_signal.py`) clears `last_exit_price = None` **only** when a reload add fires. It does **not** clear `last_exit_price` when a new Layer 0 is entered from flat after a full pod exit. This means that after a complete pod closure, the next pod’s first add(s) will incorrectly use the reload path (flat 9-pip or depth-scaled) instead of the first-time widening curve.  
  **Consequence:** All simulation results for `reload_flat` and `reload_anchor` after a full pod recycle are corrupted. The validation tables in Section 5a are therefore **not trustworthy** for evaluating reload behavior across pod boundaries. The n=500 clean pass may be a false positive because the stale `last_exit_price` could cause unreasonably tight or wide spacing for reloads that should not exist.

- **Circular confirmation risk:** The state variable `last_exit_price` is set after any exit, and cleared after a successful reload. If an adverse sequence of fills/exits causes a reload to be attempted but never filled (price runs away), `last_exit_price` stays set. This could compound through multiple exit cycles without a successful reload, leading to persistent misclassification as reloads for first-time adds. The simulation does not stress-test this.

**Verdict:** Unsound. The stale-state bug alone invalidates the reload validation pipeline. Until corrected, any claim about reload behavior is unsubstantiated.

---

### 2c. `reload_flat` Optionality Finding — **UNSOUND (validation contaminated)**

- **Stale-state bug applies directly:** The n=500 rerun (Section 5a) that supposedly resolved the reload-mechanism mismatch is itself compromised because `last_exit_price` is not cleared on new pod entries. The `reload_flat` vs `reload_anchor` comparison for pods that start after a previous closure will be affected, potentially inflating the apparent benefit of `reload_flat`.
- **n=20 vs n=500 discrepancy:** The original small-sample test (n=20) materially understated the tail risk of `MM_SHORT`/`june_blowup` (-$0.71 → -$16.56). This is a **demonstrated statistical pathology**: a small-n estimate with post-hoc mechanistic storytelling that missed the true tail severity. This casts doubt on any other n=20-scale findings in the project history (including the earlier `reload_flat` discovery) that have not been re-verified at larger sample sizes.
- **Path dependency cost:** The "optimism can only help" argument is false: the -$16.56 tail cost in `MM_SHORT`/`june_blowup` shows that entering sooner (flat floor) into a still-adverse move can produce real, non-trivial losses relative to a depth-scaled anchor. Path dependency in exposure/margin terms is a genuine cost, not a theoretical footnote.
- **Aggregate vs. isolated risk:** Even if the net aggregate result remains favorable, the existence of a specific combination with a materially worse tail means a single rule applied everywhere is not adequate. A bifurcated treatment (different reload mode for `MM_SHORT` in adverse windows) would be more defensible.

**Verdict:** Unsound. The primary experimental evidence is tainted; the original claim of "matched or beat in 5 of 6 combinations, with one small exception" is not supported by the corrected simulation due to the stale-state bug.

---

### 2d. n=500 Validation Results — **UNVERIFIABLE (multiple fatal confounding factors)**

- **Overfitting to two windows:** The same two windows (`full_quarter`, `june_blowup`) have been the sole reference data across the entire project history. Every constant (`WIDEN_RATIO`, `ADD_PIPS_CEILING`, `PHI`, `GridBase`, etc.) has been tuned directly or indirectly against these windows. The n=500 result is therefore **ex-post validation on training data**, not out-of-sample evidence. The absence of any DD3% or DD4% breach suggests either:
  - The simulation’s noise model (Brownian bridge + Parkinson vol) generates paths that are **too tame** to stress the grid geometry, regardless of the formula. This is consistent with the known limitation of Brownian bridges being conditionally smooth (SimulationEngine.md caveat #1).
  - Or the test severity is insufficient: the drawdown thresholds (3%/4%) may never be hit under *any* plausible geometry within these windows because the windows themselves are not extreme enough. The "clean pass" is then a property of the test, not the formula.

- **MHT concern:** Multiple constants have been tuned against this same data over many sessions. The probability that a combination of values produces a clean pass by coincidence alone is unquantified but non-trivial. No correction (Bonferroni, FDR, holdout) has been applied.

- **Simulation fidelity gaps (Section 7):** ADR-090 compression, ADR-078 exit-reset, Option B tick-driven add_next, ADR-048 cooldown drag, ADR-079 dynamic reanchor — all absent from the Python sim. These mechanisms interact with spacing in non-trivial ways. A simulation that omits them cannot be considered a reliable proxy for live production behavior.

**Verdict:** Unverifiable. The result is statistically compromised by overfitting, insufficient test severity, and fidelity gaps. It cannot be used as evidence for production readiness.

---

### 2e. Other Unresolved Constants — **RETAIL HEURISTICS**

- **`GridExpBase = 1.5`** (Legacy): No derivation exists — it is a pure retail heuristic. The fact that `WIDEN_RATIO=1.304` is close to this number does not confer legitimacy.
- **`PHI = 0.618`** (Skew and exit formulas): The golden ratio conjugate has no fundamental connection to market-making spacing. Its persistence in the codebase (ComputeSkew, exit formula, plus its reciprocal 1.618 in HandleEntryFill’s `A_golden`) is a concentration of arbitrary retail heuristics. The proposed ADR-091 does not remove PHI from the exit side, and its interaction with the first-time-add path is not analyzed.
- **`MinLayerExitPoints = 30` (3 pips):** Justified only as a commission floor. This is a legitimate floor but the exit formula itself (0.618^(layer+1) decay) is a retail heuristic.

**Verdict:** The codebase contains multiple arbitrary constants with no empirical or theoretical justification. ADR-091 replaces one set of heuristics (GridExpBase) with another (WIDEN_RATIO, ADD_PIPS_CEILING) without addressing the structural reliance on heuristics.

---

### 2f. Simulation-Fidelity Caveats — **CRITICAL**

- **GBPUSD-only identity:** The claim that `score_B - score_C = r_BC` is algebraically correct given the zero-sum decomposition. However, this does **not** imply that the grid behavior under GBPUSD-only is representative of the full triad. The signal strength and spread dynamics of EURUSD, GBPUSD, and EURGBP differ; the cross-cancellation argument only justifies that the *raw signal* for GBPUSD is independent of EURUSD’s anchor, but it does **not** justify that the Monte Carlo path generation for GBPUSD alone captures the correlation and volatility interactions that affect spacing in a live triad.
- **ADR-048 cooldown drag (not simulated):** Affects Layer 0 resting about 33-36% of runtime. Could alter the probability of initial entry hits, changing the distribution of when grids build.
- **ADR-078 exit-reset delay + ADR-079 dynamic reanchor (not simulated):** Confirmed to produce large drift components that dominate spacing computations in live runs (see `findings_exit_reset_kinetic_anchoring.md`). These mechanisms can dramatically alter the effective spacing for reloads — precisely what is being validated. Not modeling them makes the simulation a **hollow shell** of the actual system.
- **Option B tick-driven add_next:** The live EA runs `add_next` placement every tick, not just on bar close as simulated. This changes the timing and frequency of add-next evaluations, potentially altering the likelihood of fills at deep levels.

**Verdict:** The simulation is an inadequate basis for a production architectural ruling. The live-only mechanisms that affect spacing (ADR-078, ADR-079, ADR-048, Option B cadence) are not abstractions — they are load-bearing components of the actual spacing geometry. A Python-only validation that ignores them cannot pass muster.

---

### Synthesis: Why ADR-091 Fails Phase 1

1. **Fatal mechanical bug:** The `last_exit_price` stale-state bug invalidates the reload validation pipeline. The n=500 results are corrupted and cannot support any conclusion about reload behavior.
2. **Statistical overfitting:** The "clean pass" is obtained on the same two windows used for iterative tuning, with a noise model that underestimates tail risk. It is not out-of-sample evidence.
3. **Simulation inadequacy:** Critical live mechanisms (ADR-078, ADR-079, ADR-048, Option B) are absent. A spacing geometry validated in a sandbox that omits the actual determinants of spacing in production is not a valid basis for a production decision.
4. **Retail heuristics replacing retail heuristics:** `WIDEN_RATIO` and `ADD_PIPS_CEILING` are fit to an arbitrary cumulative-pip target, itself not justified, and the underlying `PHI` constants remain. The ADR replaces one set of arbitrary numbers with another.
5. **Unsupported constant derivation:** The closing constant `1.304` was solved to hit a target that was then missed by 42%, then retroactively redefined as not applicable. This is not a principled engineering decision.

**Per the Override Rule of ARCHITECT.md:** This audit has uncovered a fatal flaw (stale-state bug) that invalidates the premise of the ADR. The n=500 validation is unreliable, and the simulation fails to model live-critical mechanisms. **ADR-091 should not be considered architecturally locked.** Further work should focus on (a) fixing the stale-state bug and re-running validation, (b) incorporating the missing live mechanisms into the simulation, (c) obtaining out-of-sample test windows, and (d) deriving spacing constants from observed volatility or adverse-excursion data rather than arbitrary cumulative-pip targets.

**No implementation code should be written for ADR-091 until Phase 2 (Claude blueprint) and Phase 3 (Gemini ruling) are revisited with corrected evidence.** The current ruling is vacated pending this pivot.