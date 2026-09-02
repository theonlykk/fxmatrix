# ADR-091: Grid Spacing Geometry Correction (WIDEN_RATIO / ADD_PIPS_CEILING)

**Status: GEOMETRY LOCKED (PHASE 3 CLEARED, SCOPED) — PRODUCTION PORT GATED**
Per `ARCHITECT.md`, this ADR underwent a DeepSeek Phase 1 pass (Override Rule invoked on a confirmed `last_exit_price` bug, since fixed and verified), a second DeepSeek Phase 1 pass on all subsequent new material (Override Rule vacated, no new fatal flaw), and a **scoped Gemini Phase 3 ruling**: **Sections 3-6 (the geometry decision itself — `WIDEN_RATIO=1.304`, `ADD_PIPS_CEILING=1000.0`, the `reload_flat`/`reload_anchor` bifurcation) are approved and locked.** The bifurcated realized/MTM/non-flat% KPI standard (Section 5d) is also formally adopted going forward.

**Items 7-9 (Section 8) do not gate this geometry ruling but strictly gate the Phase 4/5 MQL5 production port** — per Gemini's explicit ruling, no implementation may proceed against `ea/FXMatrix.mq5` until the simulation-fidelity gaps (Item 7), the joint 3-pair LDAK simulator (Item 8, reframed from the original cross-currency correlation question), and MT5 engine-fidelity validation (Item 9) are formally closed.

**One correction to the record, not a challenge to the ruling:** Gemini's rationale characterized the tighter geometry's cumulative-distance reduction (Section 5e) as a "compression on margin consumption" implying a safety improvement over the old formula. On inspection this likely overstates the case — tighter cumulative spacing at a given depth means the new geometry reaches that depth using a *smaller* adverse price move than the old geometry would need, which is arguably more aggressive capital deployment for a given move, not less. What has actually been verified is that the new geometry passes DD3/DD4 cleanly on its own merits across five historical windows — **not** that it is safer than the old `GridExpBase=1.5` in a head-to-head sense, since the old geometry has never been run through the same n=500 validation for direct comparison. This doesn't affect the lock (the new geometry's own empirical safety record stands independently), but the "safer than before" framing should not be treated as established.

**Author:** Claude (Lead Engineer / Blue Team), drafted at Khalid's request. Gemini (Staff Architect) to review and rule, per normal Phase 3 process — this document is the Phase 2 blueprint, not a Phase 3 ruling.

**Date:** 2026-07-11

---

## 1. Context

The live EA (`ea/Globals.mqh`, `ea/ExecutionEngine.mqh`) currently governs first-time grid-add spacing with `GridExpBase = 1.500`. This constant predates the current audit trail; no derivation for it has ever been established, and it has been informally flagged (by Claude, in earlier sessions) as a legacy retail-style heuristic — a "toxic" baseline in prior project language, not because of a specific proven failure, but because of the absence of any principled justification.

A parallel Python Monte Carlo simulation track (`scripts/grid_sim_v6_dynamic_spacing.py` → `scripts/grid_sim_v7_real_signal.py`) was built to stress-test grid spacing and reload mechanics against real GBPUSD M5 data, using a faithful port of the live signal mechanism (`ComputeTermStructure`, `InvertSpreadToPrice`, verified numerically against production formulas retrieved via Cursor). This work produced a proposed replacement: `WIDEN_RATIO = 1.304`, `ADD_PIPS_CEILING = 1000.0`.

**This document formalizes that proposal as a reviewable artifact. It does not itself change production code.**

---

## 2. Critical scope note: this has not been ported to production

**Confirmed via direct repo read (Cursor, 2026-07-11):** `WIDEN_RATIO` and `ADD_PIPS_CEILING` exist only in the Python simulation files. The live EA still runs `GridExpBase = 1.500` in `ea/Globals.mqh`, applied via `ComputeNextLayerPrice()` in `ea/ExecutionEngine.mqh`. `docs/architecture/ADR-090.md` — the prior, shipped ADR covering add-spacing compression — explicitly defers this re-architecture as "tracked separately (pending)."

This means every validation result in this document (Section 5) demonstrates that the *proposed* geometry behaves well *in simulation*. It is not evidence about current live-account risk, and it does not by itself justify a production change, because the simulation does not model several mechanisms that exist only in the live EA (Section 7). Whether the sim's fidelity is sufficient grounds for a production port is treated here as an open question for Phase 1/3, not a settled premise.

---

## 3. Decision (proposed, pending audit)

Replace the flat exponential spacing model with a **bifurcated** model:

**3a. First-time adds** (a layer being entered for the first time — no prior exit at that depth): governed by a bounded exponential curve, implemented as a **running multiplicative state variable** (`current_add_pips`), not a closed-form function evaluated fresh at each layer:

```
current_add_pips initialized to 9.0 (ADD_PIPS_FLOOR)
For each add: use current_add_pips as the distance if len(layers) >= 3, else use flat 9.0
After each fill where len(layers) >= 3 (post-append): current_add_pips = min(1000.0, current_add_pips × 1.304)
```

**Confirmed against source by Cursor** (`scripts/grid_sim_v7_real_signal.py`, lines 216–219 and 228–229): this closed-form equivalent is
$$D_n = \min(1000.0,\ 9.0 \times 1.304^{(n-2)}) \quad \text{for } n \geq 3$$
$$D_n = 9.0 \quad \text{for } n = 1, 2$$
where `n` is the add index (1 = first add after Layer 0). The multiply fires when the 3rd layer *fills* (before the 3rd add is placed), so the first widened step (n=3) already reflects one multiply (11.736 pips), not zero.

**3b. Reloads of a previously-cleared slot** (gated on a `last_exit_price` state variable — `None` during first-time builds and immediately after a successful reload, set only in the single window right after an exit): the Gemini ruling this ADR documents specifies this should be governed by a **flat 9-pip floor, unconditionally, regardless of depth** (`reload_flat`).

**This does not match what has actually been validated. Flagged prominently — see Section 4a.**

The bifurcation gate itself (`last_exit_price`) required no new logic — it already existed in the codebase and already produced this gating behavior; it was discovered during this work, not built for it. What governs behavior *once* that gate fires is the open problem below.

---

## 4. Corrections and open problems surfaced by direct source verification (Cursor, 2026-07-11)

### 4a. CRITICAL — the validated evidence does not test the proposed reload decision

Cursor's source read surfaced a second, separate reload mechanism in the same file, gated on `spacing_mode == "reload_anchor"`:

```
depth_mult = WIDEN_RATIO ** (len(layers) // 3)
reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR * depth_mult)
```

This is **depth-scaled** (exponential in layer-group, via integer division by 3) — the opposite of the flat, depth-independent behavior `reload_flat` (and this ADR's Section 3b decision) calls for.

**Per the original session handoff, `run_v7_n500_validation.py` — the script that produced Section 5a's "clean pass" results — ran with `spacing_mode="reload_anchor"`, not `reload_flat`.** This means: **the n=500 validation evidence in this document does not test the reload behavior this ADR proposes to adopt.** It validates the first-time-add geometry (Section 3a, now confirmed) combined with the *older*, depth-scaled reload mechanism — not the flat-floor reload decision in Section 3b.

This is a load-bearing gap, not a documentation nit. Two ways to resolve it, and this ADR takes no position on which:
- **(i)** Re-run the n=500 validation with `spacing_mode="reload_flat"` before treating Section 3b's decision as evidenced at all, or
- **(ii)** Revise Section 3b to reflect that `reload_anchor`'s depth-scaled reload is what's actually being proposed/evidenced, and treat the `reload_flat` optionality argument (Section 5b) as a separate, not-yet-adopted alternative.

Left unresolved, DeepSeek would be auditing a decision (flat reload) using evidence for a different mechanism (depth-scaled reload) — the two must be reconciled before this ADR can be considered internally consistent, independent of whether either mechanism is architecturally sound.

### 4b. First-time-add exponent — resolved

The exponent-indexing question originally posed in this section (two candidate conventions, both hedged as unconfirmed) is now settled by direct source read: neither original candidate was correct. The actual mechanism is the running multiplicative state variable in Section 3a, equivalent to $D_n = 9 \times 1.304^{(n-2)}$ for $n \geq 3$. Independently re-verified numerically (Claude): cumulative distance over the first 19 add-steps (20 layers total, including Layer 0) sums to **3,497.96 pips** — matching the previously-recorded "~3,498 pips" figure to two decimal places. This part of the geometry is now confirmed, not assumed.

Worked table (first-time-add path only; reload path is separate — see 4a):

| n | D_n (pips) | Cumulative (pips) |
|---|---:|---:|
| 1 | 9.000 | 9.00 |
| 2 | 9.000 | 18.00 |
| 3 | 11.736 | 29.74 |
| 4 | 15.304 | 45.04 |
| 5 | 19.956 | 65.00 |
| 6 | 26.023 | 91.02 |
| 7 | 33.934 | 124.95 |
| 8 | 44.249 | 169.20 |
| 9 | 57.701 | 226.90 |
| 10 | 75.243 | 302.15 |
| 11 | 98.116 | 400.26 |
| 12 | 127.944 | 528.21 |
| 13 | 166.838 | 695.04 |
| 14 | 217.557 | 912.60 |
| 15 | 283.695 | 1,196.30 |
| 16 | 369.938 | 1,566.23 |
| 17 | 482.399 | 2,048.63 |
| 18 | 629.048 | 2,677.68 |
| 19 | 820.279 | 3,497.96 |
| 20 | 1,000.000 (ceiling binds) | 4,497.96 |

Note the `ADD_PIPS_CEILING=1000` binds for the first time at n=20, not earlier — the "silently flatlining at layer ~13" bug described in Section 1's history refers to the *old* `ADD_PIPS_CEILING=100` value, not the corrected 1000 used here.

Gemini's earlier point about the ~6,000-pip pure-series target remains worth noting for context but is now secondary: the actual implemented mechanism was never a pure 20-term series in the first place — it's a state machine with a 2-layer flat floor and a per-fill multiply, which was always going to undershoot a pure closed-form target regardless of indexing convention.

---

## 5. Validation evidence

### 5a. n=500 Monte Carlo — FINAL, post-bug-fix results (corrected geometry + corrected `last_exit_price` state handling)

**This supersedes the earlier n=500 table in this section, which was generated under code later confirmed by DeepSeek's Phase 1 audit to contain a stale-state defect.** DeepSeek identified (and Cursor independently confirmed against source, then measured empirically at ~9–16% of pod restarts) that `last_exit_price` was never cleared on a new Layer-0 entry after a full pod exit, causing a meaningful fraction of new pods' first adds to incorrectly anchor to the *previous* pod's stale exit price instead of using first-time widening. A one-line fix was applied (`last_exit_price = None` added to the flat-entry block), verified by two new unit tests, and the full n=500 matrix was rerun on the corrected code:

```
Window        SpacingMode     Mode      Mean P&L    Worst      MaxLayers  DD3 count  DD3%   DD4 count  DD4%
full_quarter  reload_anchor   MM_LONG   $179.70     $103.46    7          0          0.00   0          0.00
full_quarter  reload_flat     MM_LONG   $180.53     $103.70    7          0          0.00   0          0.00
full_quarter  reload_anchor   MM_SHORT  $31.23      $5.84      7          0          0.00   0          0.00
full_quarter  reload_flat     MM_SHORT  $32.21      $7.49      7          0          0.00   0          0.00
full_quarter  reload_anchor   MM_BOTH   $285.05     $80.24     7          0          0.00   0          0.00
full_quarter  reload_flat     MM_BOTH   $286.27     $85.67     7          0          0.00   0          0.00
june_blowup   reload_anchor   MM_LONG   $16.24      $7.39      7          0          0.00   0          0.00
june_blowup   reload_flat     MM_LONG   $17.87      $8.97      7          0          0.00   0          0.00
june_blowup   reload_anchor   MM_SHORT  $-2.98      $-17.79    6          0          0.00   0          0.00
june_blowup   reload_flat     MM_SHORT  $-3.97      $-19.16    6          0          0.00   0          0.00
june_blowup   reload_anchor   MM_BOTH   $23.14      $11.87     7          0          0.00   0          0.00
june_blowup   reload_flat     MM_BOTH   $24.75      $14.00     7          0          0.00   0          0.00
```

**Zero DD4% breaches and zero DD3% incidents across all 12 combinations × 500 seeds = 6,000 total seed-runs — capital-preservation thresholds still pass cleanly under the corrected code.**

**Critical finding, not a footnote: the bug fix changed the picture materially, and one specific combination is now mean-negative.** Comparing corrected results against the pre-fix table directly (both were run under identical geometry, differing only in the `last_exit_price` fix):

| Combination | Mean P&L, pre-fix | Mean P&L, post-fix | Worst, pre-fix | Worst, post-fix |
|---|---:|---:|---:|---:|
| full_quarter / MM_LONG (both modes) | ~$188–189 | ~$180 | ~$94 | ~$103–104 (better) |
| full_quarter / MM_SHORT (both modes) | ~$31–32 | ~$31–32 (flat) | **-$6.69 to -$7.40** | **+$5.84 to +$7.49 (sign flip, improved)** |
| full_quarter / MM_BOTH (both modes) | ~$262 | ~$285–286 | ~$50 | ~$80–86 (notably better) |
| june_blowup / MM_LONG (both modes) | ~$14–15 | ~$16–18 | ~$7–8 | ~$7–9 (roughly flat) |
| **june_blowup / MM_SHORT (both modes)** | **+$12.25 to +$12.33** | **-$2.98 to -$3.97 (MEAN SIGN FLIP)** | -$12.80 to -$16.56 | **-$17.79 to -$19.16 (worse)** |
| june_blowup / MM_BOTH (both modes) | ~$20–21 | ~$23–25 | ~$2–4 | ~$12–14 (better) |

**10 of 12 combinations improved or held roughly flat after the fix** — the bug had, by accident of stale-anchor placement, mostly been helping (worst-case improved notably in several combinations, e.g. `full_quarter`/`MM_BOTH`'s worst case rose ~$30–35). **But `june_blowup`/`MM_SHORT` — both spacing modes — moved the other way on both metrics simultaneously**, and its mean P&L crossed from positive to negative. This directly validates DeepSeek's Override Rule invocation: the bug was not cosmetic, it was large enough to flip the sign of a real result. **The original "MM_SHORT is profitable during the June trend" finding was, at least in part, an artifact of the confirmed bug's stale-anchor spacing** — the honest, corrected result for this specific combination is a small net loss on average, not a profit, while every other window/mode combination held up or improved.

This does not breach DD3/DD4 anywhere — it is a mean-profitability finding, not a capital-preservation one — but a strategy component that is mean-negative in a specific, real historical regime, even within safety bounds, is a genuine design question that needs to be carried forward, not smoothed over by the fact that the aggregate/other combinations look fine.

**This result has not yet been reviewed by DeepSeek or Gemini.** Both reviewed only the pre-fix evidence. This is new material information — not just "the same conclusion with a bug fixed" — and should go back to both before any Phase 3 ruling.

**This result is unusually clean on DD3/DD4 and should not be read as unqualified confirmation of robustness** — see Section 6 for why.

### 5b. `reload_flat` vs. `reload_anchor` optionality finding — reconfirmed post-fix, original n=500-vs-n=20 framing superseded

**Note on interpretation history:** an earlier version of this section compared the (pre-bug-fix) n=500 results against the original n=20 finding and concluded the n=20 estimate had understated tail risk in `MM_SHORT`/`june_blowup`. That comparison is now superseded — the pre-fix n=500 numbers it relied on are themselves confirmed to have been affected by the `last_exit_price` defect (Section 5c). The comparison below uses only the corrected, post-fix n=500 results.

**`reload_flat` vs. `reload_anchor`, post-fix:** the two spacing modes remain very close to each other across all 12 combinations (see Section 5a table) — differences between them are consistently small (generally under $2 in mean P&L, a few dollars in worst-case), in both directions. The original optionality argument (flat reload as harmless-or-better optimism) is not contradicted by the corrected data, but the more consequential finding at this point is the `june_blowup`/`MM_SHORT` mean-sign-flip (Section 5a), which affects both spacing modes equally and is therefore not a `reload_flat`-specific problem — it is a property of the `MM_SHORT` bias mode under `june_blowup`-like conditions generally, independent of which reload mechanism is used.

### 5c. Confirmed defect and fix history (DeepSeek Phase 1 finding)

DeepSeek's Phase 1 audit invoked `ARCHITECT.md`'s Override Rule, identifying a stale-state bug: `last_exit_price` was cleared only on a successful reload-add fill, never on a new Layer-0 entry from flat after a full pod exit. Cursor independently confirmed this against source (no reset path existed) and measured its practical trigger rate empirically — **~9–16% of pod restarts** across both windows and all three bias modes — not a rare edge case.

**Fix applied:** one line added to the flat-entry block, `last_exit_price = None`, at the point a new Layer-0 fill occurs. Two unit tests added and passing. Confirmed by self-review to touch nothing else (the two pre-existing assignment points — set on exit, cleared on successful reload — are unchanged).

**A related, distinct scenario was separately investigated and characterized, not fixed, since it was found not to require a fix:** DeepSeek also flagged a "circular confirmation risk" — a reload attempted but never filled, with the stack still non-empty, potentially compounding across cycles. Empirical trace (Cursor, seeds 0–9): this "supersession" scenario occurs in **~4.2% of reload-arming exits** (distinct from, and much less frequent than, the primary ~9–16% pod-restart bug). Critically, it was found to reflect *intended* design behavior (the most recent exit becomes the reload anchor, consistent with "reload the most recently cleared slot") rather than a defect — the abandoned reload target is rarely close to firing when superseded (median 31 pips away), and the "material spacing difference" this produces on overwrite is the same already-intended gap between flat reload spacing and first-time widening, not a new distortion. **No fix was applied for this scenario; it is documented here as characterized, accepted behavior**, not an open item.

**DeepSeek verified its own fix** on request: confirmed the applied fix "correctly and fully closes" the primary defect (Q1), and confirmed the supersession scenario is a "lower-priority, non-fatal concern" not requiring further action before this rerun (Q2) — consistent with Cursor's independent empirical characterization above.

### 5d. Out-of-sample validation — Truss Crisis, Vaccine Rally, Q1 2024 Chop

**Directly addresses DeepSeek's original overfitting critique (Section 6): every constant in this ADR had, until now, only ever been validated against the same two historical windows.** Three genuine OOS windows were pulled via real MT5 Strategy Tester history sync (a standalone `DataExporterEA.mq5`, `Model=4`/real-tick generation, verified against the actual historical events — see method notes below) and run through the identical n=500 matrix (both spacing modes × three bias modes), corrected `WIDEN_RATIO=1.304`/`ADD_PIPS_CEILING=1000.0` geometry, same code as Section 5a.

**Window selection, per Gemini's recommendation, each targeting a specific gap the original two windows didn't cover:**
- **Truss Crisis** (2022-08-01 to 2022-10-31, 18,780 bars): the deepest historical GBPUSD stress event available — net **-693 pips**, crash low **1.03993 on 2022-09-26**, matching the real documented mini-budget collapse. Targets: does the geometry survive genuine tail risk / does `ADD_PIPS_CEILING` ever bind at extreme depth.
- **Vaccine Rally** (2020-10-15 to 2021-03-12, 30,115 bars): net **+907 pips**, a genuine sustained uptrend — the first test of `MM_LONG` as the *favored* side and `MM_SHORT` as *disfavored*, a gap neither original window covered (both were net-down).
- **Q1 2024 Chop** (2023-12-15 to 2024-04-12, 24,007 bars): intended as a low-net-movement control; actual net move was **-312 pips** — smaller than the other two but not perfectly neutral. **This project still has no genuinely flat/non-directional reference window** — worth noting as a residual gap, not treating this as a true chop control.

**Results (n=500 each, both spacing modes, all three bias modes):**

```
Window        SpacingMode     Mode      Mean P&L    Worst      MaxLayers  DD3 count  DD3%   DD4 count  DD4%
truss_crisis  reload_anchor   MM_LONG   $593.19     $250.34    8          5          1.00   0          0.00
truss_crisis  reload_flat     MM_LONG   $594.79     $251.29    9          5          1.00   0          0.00
truss_crisis  reload_anchor   MM_SHORT  $1026.12    $864.12    8          0          0.00   0          0.00
truss_crisis  reload_flat     MM_SHORT  $1016.46    $852.47    8          0          0.00   0          0.00
truss_crisis  reload_anchor   MM_BOTH   $1314.82    $595.51    9          0          0.00   0          0.00
truss_crisis  reload_flat     MM_BOTH   $1317.70    $596.22    9          0          0.00   0          0.00

vaccine_rally reload_anchor   MM_LONG   $687.14     $507.06    9          0          0.00   0          0.00
vaccine_rally reload_flat     MM_LONG   $688.79     $510.76    9          0          0.00   0          0.00
vaccine_rally reload_anchor   MM_SHORT  $-257.37    $-354.53   6          0          0.00   0          0.00
vaccine_rally reload_flat     MM_SHORT  $-252.16    $-358.71   6          0          0.00   0          0.00
vaccine_rally reload_anchor   MM_BOTH   $18.94      $-311.34   9          0          0.00   0          0.00
vaccine_rally reload_flat     MM_BOTH   $23.22      $-376.17   9          0          0.00   0          0.00

q1_2024_chop  reload_anchor   MM_LONG   $30.69      $-78.61    8          0          0.00   0          0.00
q1_2024_chop  reload_flat     MM_LONG   $29.47      $-84.40    8          0          0.00   0          0.00
q1_2024_chop  reload_anchor   MM_SHORT  $112.81     $89.92     8          0          0.00   0          0.00
q1_2024_chop  reload_flat     MM_SHORT  $113.80     $91.10     8          0          0.00   0          0.00
q1_2024_chop  reload_anchor   MM_BOTH   $133.70     $-34.30    8          0          0.00   0          0.00
q1_2024_chop  reload_flat     MM_BOTH   $127.16     $-59.94    8          0          0.00   0          0.00
```

**Aggregate across all three OOS windows (18 combinations × 500 seeds = 9,000 seed-runs): 10/9,000 DD3 breaches (0.11%), 0/9,000 DD4 breaches.** All 18 combinations pass the agreed DD4 threshold cleanly.

**Genuine new finding — Truss Crisis/`MM_LONG` is the first combination in this ADR's entire history to show any DD3 activity at all: 5/500 (1.00%) for both spacing modes.** This surfaced only at full n=500 scale — the n=20 smoke test on the same window showed 0/0 across every combination, the same pattern as the earlier n=20-vs-n=500 discrepancy on `june_blowup`/`MM_SHORT` (Section 5b history). Mechanism (confirmed via layer-depth trace, not just inferred): `MM_LONG` on this window stays shallow (2-3 layers) but one pod **never fully resets, holding open from Aug 26 through window end** — the DD3 events reflect a stuck, adverse-marked position accumulating drawdown over weeks, not deep-layer martingale accumulation. Different mechanism than what `WIDEN_RATIO` was built to guard against; same metric correctly catching it. Still a clean DD4 pass (0/500) — within the agreed "1 breach = forensic review, not hard fail" tier, and this review is that forensic accounting.

**Depth cap holds at full scale, confirming the n=20 structural finding was not a small-sample artifact:** global max layers across all 9,000 OOS seed-runs is **9** — never double digits, even on the most extreme historical window available. See Section 5e for the confirmed mechanism.

**MTM reporting artifact recurs on two more combinations — now a documented, general pattern, not a one-off.** `vaccine_rally`/`MM_SHORT` (both modes) and `vaccine_rally`/`MM_BOTH` (both modes) show negative or near-zero blended means; targeted n=50 decomposition (same method as the original `june_blowup`/`MM_SHORT` breakdown) confirms this is the same artifact:

| Combination | Mean total (blended) | Mean realized | Mean unrealized (MTM) | Non-flat at window end |
|---|---:|---:|---:|---:|
| `vaccine_rally`/`MM_SHORT` (both modes) | -$252 to -$261 | **+$112 to +$119** | -$374 | 100% |
| `vaccine_rally`/`MM_BOTH` (both modes) | -$15 to -$21 | **+$277 to +$283** | -$298 | 98% |
| `q1_2024_chop`/`MM_LONG` (both modes, for comparison — mean stays positive here) | +$29 to +$31 | +$122 to +$124 | -$91 to -$95 | 100% |

Every disfavored-side combination checked (`june_blowup`/`MM_SHORT`, `vaccine_rally`/`MM_SHORT`, `vaccine_rally`/`MM_BOTH`) shows genuinely positive realized (closed-trade) P&L masked by a consistent end-of-window mark-to-market drag on stacks still open when the historical window happens to end (typically 3-4 layers). This is not evidence of negative closed-trade edge in any of these cases — it is the going-concern nature of the system meeting an arbitrary data-window cutoff, exactly as diagnosed and ruled on by Gemini for the original `june_blowup` case (Section 5c history). **The validation runners (`run_v7_n500_validation.py`, `run_v7_n500_oos_validation.py`) have since been updated to report realized P&L, unrealized MTM, and non-flat % as explicit columns alongside the legacy blended figure**, implementing Gemini's KPI ruling directly rather than requiring manual reconstruction after every run that shows a misleading blended mean.

**Method note on OOS data provenance:** the live MT5 terminal/API only exposes a recent rolling window (~March 2026 onward) — a genuine feed-architecture split from Strategy Tester's deeper historical archive, not a caching issue. OOS data was extracted via a standalone `DataExporterEA.mq5` running *inside* a Tester backtest (which has proven access to deep history), calling `CopyRates()` from `OnDeinit()` and exporting to CSV — `FXMatrix.mq5` and all production files untouched. All three extractions confirmed `Model=4`/"every tick based on real ticks" generation (except Vaccine Rally, where real-tick archives don't extend to 2020-2021 — confirmed fallback to synthetic tick generation for fill-simulation purposes only; the exported M5 OHLC bars themselves come from the native M5 history series via `CopyRates`, unaffected by this fallback).

### 5e. Structural finding: layer depth is capped well below the geometry's design ceiling, on any tested historical window

**This ADR's central open question — does the corrected geometry protect the account at extreme depth — turns out to be very difficult to test empirically, for a structural reason independent of which historical window is chosen.**

Across all five historical windows now tested (`full_quarter`, `june_blowup`, and the three OOS windows), maximum observed layer depth never exceeds **9**, even on Truss Crisis — the most extreme GBPUSD move available. `ADD_PIPS_CEILING=1000` has never bound in any validation run; per the worked table (Section 4b), the ceiling only matters from roughly layer 20 onward.

**Mechanism, confirmed against source (not inferred):** the LIFO exit target is **3 pips** (`EXIT_PIPS`), checked per-layer from that layer's own entry — while the next add requires **9-34+ pips** adverse continuation from the deepest layer's entry (growing with depth per the `WIDEN_RATIO` curve), or the reload-mode-specific distance from the last exit. Cross-referenced against actual Truss Crisis shock-window volatility: ~93% of 5-minute bars span at least 3 pips of range, versus ~55% spanning at least 9 pips. A small favorable retracement satisfying the exit is structurally far more probable, per unit time, than a large adverse continuation satisfying the next add — so the stack recycles via shallow LIFO exits faster than it can compound via adds, largely independent of which direction the market is actually moving or how severe the underlying move is.

Layer-depth tracing on Truss Crisis confirmed this operates differently, but similarly, on both sides: `MM_SHORT` (favored, riding the collapse) sustains 5-7 layers through the shock via continuous partial LIFO peeling (~350 full pod cycles over 3 months, ~50% of runtime flat); `MM_LONG` (disfavored, fighting the collapse) stays even shallower (2-3 layers) — one pod persists without either fully resetting or building deep, consistent with the Truss/`MM_LONG` DD3 finding above.

**Implication for this ADR: the corrected geometry's behavior at the depths it was specifically designed to protect against (`ADD_PIPS_CEILING` binding, layer 13+) remains validated-in-principle but effectively untested-in-practice** — not because testing has been insufficient, but because the system's own recycling behavior appears to structurally prevent reaching that regime under any realistic historical market condition tested so far. This should be documented as a genuine architectural property, not treated as a testing gap to keep chasing with ever-more-extreme historical windows — the evidence increasingly suggests no realistic GBPUSD window would behave differently.

**Important corollary, surfaced by DeepSeek's second Phase 1 pass: the depth cap does not mean `WIDEN_RATIO`'s specific value is inconsequential.** The correction from `1.5` to `1.304` produces a materially different spacing curve well within the depths this system actually reaches — not just at the theoretical layer-13+ region the original derivation targeted. Using the identical formula structure for both (flat floor for the first two adds, then running multiplicative widening from the third — confirmed as the shared structure both constants use, since the `1.5→1.304` change was implemented as "a simple constant swap, preserving the existing verified structure exactly"), cumulative distance at depth 8 (the maximum observed anywhere in this ADR's validation):

| | Cumulative distance at depth 8 |
|---|---:|
| New geometry (`WIDEN_RATIO=1.304`) | **169.20 pips** |
| Old geometry (`GridExpBase=1.5`), same structure | **298.55 pips** |

(DeepSeek's own second-pass reasoning initially cited 443.32 pips for the old geometry — independently re-verified here and found to reflect an inconsistent reconstruction that applied the flat-floor exception to only the first add rather than the first two; 298.55 pips is the corrected, apples-to-apples figure.) The corrected value is still a substantial ~43% tighter cumulative spread at the deepest depth actually observed — meaning `WIDEN_RATIO`'s correction matters throughout the depth range this system operates in, not only in a theoretical extreme-depth regime that turns out to be unreachable. The original derivation (targeting a 6,000-pip pure-series bound) remains unprincipled, but this is independent evidence the corrected value has real, materially different practical consequences at observed depths — not just at a ceiling that never binds.

---

## 6. Statistical caveats on the n=500 result

- **Partially addressed by Section 5d.** The original concern — every constant tuned against the same two windows — is meaningfully mitigated by the three new OOS windows (Truss Crisis, Vaccine Rally, Q1 2024 Chop), none of which were available or used during any of `WIDEN_RATIO`/`ADD_PIPS_CEILING`'s development. The geometry passes DD4 cleanly across all five windows now tested (9,000 additional OOS seed-runs, 0 DD4 breaches). This is real, if incomplete, out-of-sample evidence — not a full resolution of the underlying MHT concern (see below), but a genuine strengthening of it.
- **Residual gap:** this project still lacks a genuinely non-directional/flat control window — all five windows tested so far (including the "chop" candidate) have some net directional lean. Whether the geometry behaves differently under true non-trending conditions remains untested.
- A perfectly clean 0-DD4-breach result across 15,000 total seed-runs (original + OOS) could still indicate either genuine robustness or a noise model (Brownian-bridge / Parkinson-vol-calibrated) that doesn't generate tail scenarios severe enough to trip a 4% drawdown regardless of formula — Section 5d's Truss Crisis DD3 finding (5/500, `MM_LONG`) is the first crack in an otherwise perfectly clean record, worth weighing as partial evidence the test *can* discriminate, not just pass by construction.
- Multiple constants and thresholds (`WIDEN_RATIO`, `ADD_PIPS_CEILING`, the DD3/DD4 pass thresholds themselves, and the still-unresolved `PHI=0.618`) were originally all tuned against the same pair of windows. Whether this constitutes a residual multiple-hypothesis-testing concern even with OOS confirmation — i.e., whether the corrected constants happen to generalize well by luck rather than genuine principle — remains an open question for a second DeepSeek pass.

---

## 7. Simulation-fidelity gaps (mechanisms not modeled in the Python sim, but present in the live EA)

- **ADR-090 add-spacing compression** — shipped, live, not modeled in `grid_sim_v7_real_signal.py`.
- **ADR-078 exit-reset re-arm** (`exit_reset_pending`, `g_last_exit_reset_closing_add_next[]`) — live reload/re-arm mechanism in `ea/FXMatrix.mq5`; conceptually related to but not the same code path as this ADR's `last_exit_price` bifurcation gate.
- **Option B `add_next`** — tick-driven in the live EA (runs every tick unless `DebugAddNextBarCloseOnly=true`, currently `false`), whereas the Python sim's reload/add logic is bar-close-oriented throughout.
- **LDAK (Linkage Disequilibrium Adjusted Kinships) — cross-pair correlation/volatility gating, confirmed live and active, but entirely unmodeled in the single-pair Python sim.** Introduced ADR-010/011, purpose-built for exactly the scenario behind Gemini's deferred cross-currency correlation question: a simultaneous USD-driven move hitting EURUSD and GBPUSD together. Mechanism (confirmed against source): pairwise Pearson correlation + volatility-ratio stress score (`S_eff`) computed every bar close across all three pairs, driving a continuous lot-size throttle (`w = 1/(1+S_eff²)`) and binary peer-slot suppression — both **always-on in the live EA, no debug flag gating them**. A related grid-spacing dilation path exists but is disabled by default (`DebugEnableLDAKDilation=false`). ADR-087 explicitly preserved LDAK's correlation penalty; ADR-090 doesn't touch it. **This means the actual, tested, currently-live answer to "what happens when EURUSD/GBPUSD move together" is LDAK's lot-throttle and slot-suppression — not something this ADR needs to invent** — but since `grid_sim_v7_real_signal.py` is single-pair (GBPUSD only), none of LDAK's cross-pair logic is represented in any validation result in this document. The correct resolution to Gemini's deferred question (Section 8, Item 6) is very likely a joint 3-pair simulator incorporating LDAK's real formula, not a new spacing/regime mechanism — LDAK already exists and is trusted; it just hasn't been tested under the geometry this ADR proposes.
- **ADR-048 cooldown drag** — confirmed via three independent logs to affect Layer-0 resting orders roughly 33–36% of live runtime. Not simulated in v7 at all. (Related to, but distinct from, LDAK above — cooldown drag concerns Layer-0 quote freezing, not cross-pair lot-sizing.)
- **ADR-079 dynamic re-anchor** — confirmed scoped to `add_next` only (not Layer-0 bar-close quoting). Source default is `false`; recent backtest `.set` profiles have run with it `true`. Not modeled as a variable in the Python sim.
- **GBPUSD-only scope** — justified via the algebraic identity `score_B − score_C = r_BC` (EURUSD's cross term cancels out of GBPUSD's own signal). This identity has not been independently re-derived or checked against the live `FV_combined` formula as part of this ADR; it is inherited from earlier sessions.

None of these gaps individually invalidate the spacing-geometry proposal in Section 3, but collectively they mean **this ADR's validation evidence describes a simulated subsystem, not the live EA's actual behavior**, and porting this geometry to production would need to be reconciled against all five mechanisms above, not just dropped in as a constant swap.

---

## 8. Open items — required before this ADR can move past Phase 1

1. ~~`june_blowup`/`MM_SHORT` mean-negative post-fix~~ — **Resolved/reframed.** Confirmed as the same MTM reporting artifact documented across three windows now (Section 5d) — genuinely positive realized P&L in every case, masked by end-of-window mark-to-market on a going-concern system. Not a design flaw; the reporting metric has been fixed going forward.
2. ~~Reload-mechanism mismatch~~ — **Resolved.** See Section 5a.
3. ~~Exponent-indexing convention~~ — **Resolved.** See Section 4b.
4. ~~`reload_flat` vs. `reload_anchor` optionality comparison under 1.304~~ — **Resolved.** See Section 5b.
5. ~~DeepSeek Phase 1 stale-state bug~~ — **Resolved, fix verified.** See Section 5c.
6. ~~Out-of-sample testing (overfitting to two windows)~~ — **Substantially addressed.** Three genuine OOS windows tested, 9,000 additional seed-runs, 0 DD4 breaches. See Section 5d. Residual gap: no genuinely non-directional control window exists yet (noted in Section 6).
7. **Design and run (or explicitly decline) Gemini's deferred cross-currency correlation test for `BIAS_BOTH`.** Now much better scoped: LDAK (Section 7) is the live, tested, always-on mechanism that already addresses correlated cross-pair moves — the actual gap is that it's unmodeled in the single-pair Python sim, not that no mitigation exists. Building a joint 3-pair simulator incorporating LDAK's real formula is the concrete next step, not an open-ended research question.
8. **Define a concrete porting plan** reconciling this geometry against ADR-090, ADR-078, ADR-048/LDAK, and Option B's tick-driven add_next — not assumed away as out of scope.
9. **Simulation engine fidelity has never been validated against a real MT5 Strategy Tester run, independent of this ADR's geometry.** Every n=500 result in this project's history — both original windows and all three OOS windows — rests on trusting `grid_sim_v7_real_signal.py`'s fill/exit/P&L mechanics without ever having directly compared them against real MT5 output, even using the old live formula as a common reference point that exists in both places today. Queued as its own workstream (`engine_fidelity_validation_plan.md`) — should happen before final Phase 3 closure, since it underwrites confidence in all evidence in this document, not just the new geometry.
10. **A second, full DeepSeek Phase 1 pass is warranted** covering all new material since the first audit: the post-fix evidence, the three OOS windows, the depth-cap structural finding (Section 5e), and the LDAK clarification. The original audit's conclusions on `PHI=0.618` and simulation-fidelity gaps likely still hold, but none of Section 5d/5e/7's updates have been reviewed by either DeepSeek or Gemini yet.

---

## 9. Negative space — what this ADR explicitly does NOT do

- Does **not** modify any file under `ea/` — production MQL5 is untouched.
- Does **not** constitute a Gemini ruling on the finalized document — Gemini reviewed the pre-rerun draft and ruled on the reload-mechanism question (Section 5a); a final pass on the completed evidence is still advisable before DeepSeek, but Items 1–3 are no longer open questions requiring a ruling, just confirmation the resolution was recorded correctly.
- Does **not** resolve Items 4–5 (Section 8) — cross-currency correlation test and the ADR-090/078/Option-B porting plan remain genuinely open.
- Does **not** authorize Cursor to implement anything in production. No implementation should proceed until Phase 1 (DeepSeek) and a subsequent Phase 3 (Gemini) ruling on this document specifically are complete.
