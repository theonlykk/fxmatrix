# DeepSeek Phase 1 — Second Pass: New Material Since Original Audit (ADR-091)

**This is a targeted second pass, not a fresh full audit.** Your original audit (attached in full below) invoked the Override Rule on a confirmed `last_exit_price` stale-state bug. That bug is fixed and you've already independently verified the fix (separate follow-up exchange, also summarized below). Since then, substantial new material has been added to ADR-091 that neither you nor Gemini have reviewed. Your original findings on `PHI=0.618`, the GBPUSD-only scope identity, and the general simulation-fidelity gaps (ADR-090/078/Option B) still stand and don't need re-litigating — this pass is specifically about what's new.

---

## 1. What's new since your original audit

1. **Post-fix full re-validation** (both spacing modes, both original windows, corrected `last_exit_price` handling) — you already reviewed this via the narrower follow-up exchange.
2. **Three genuine out-of-sample historical windows**, pulled via real MT5 Strategy Tester history sync (not the original two windows the geometry was tuned against): Truss Crisis (2022 GBP collapse, -693 pips), Vaccine Rally (2020-21 sustained uptrend, +907 pips), Q1 2024 Chop (-312 pips, intended as a low-movement control but not perfectly neutral). 9,000 additional seed-runs total.
3. **A confirmed structural finding**: layer depth never exceeds 9 across all five windows now tested (15,000 seed-runs total, original two plus three OOS), including the most extreme historical move available. Mechanism traced and confirmed against source: the 3-pip LIFO exit threshold is satisfied by ordinary intrabar noise far more often than the 9-34+ pip add threshold, causing the stack to recycle faster than it can compound depth — largely independent of trend direction or severity.
4. **A correction to the cross-currency correlation question you and Gemini discussed**: LDAK (Linkage Disequilibrium Adjusted Kinships, ADR-010/011) is confirmed live, always-on, and cross-pair aware (Pearson correlation + volatility-ratio stress score across all three pairs, driving continuous lot-throttle and peer-slot suppression) — purpose-built for exactly the "simultaneous USD-driven move" scenario. It is completely unmodeled in the single-pair Python simulation.
5. **A recurring measurement artifact, now documented across three separate combinations**: disfavored-side bias modes ending a historical window mid-position show negative or suppressed blended P&L that decomposes into genuinely positive realized (closed-trade) P&L masked by end-of-window mark-to-market on open stacks. Confirmed via targeted n=50 decomposition on each occurrence, not asserted.
6. **One new capital-preservation-relevant finding**: Truss Crisis/`MM_LONG` shows the first DD3 activity (5/500, 1.00%, both spacing modes) anywhere in this ADR's history — still 0/500 DD4, within the previously agreed "1 breach = forensic review, not hard fail" tier.

Full detail on all of the above is in the attached, updated `ADR-091-grid-spacing-geometry.md`, Sections 5d, 5e, and 7.

---

## 2. Specific questions for this pass

**On the OOS evidence and your original overfitting critique (2d in your original audit):**
- Does three additional historical windows (9,000 seed-runs, 0 DD4 breaches, one 1% DD3 event) adequately address your original concern that the geometry's "clean pass" might reflect insufficient test severity or overfitting to the same two windows — or is there a specific reason the new windows don't actually constitute independent evidence (e.g., were they selected in a way that could itself introduce bias)?
- This project still has no genuinely non-directional/flat control window — all five windows tested have some net directional lean. Does this residual gap materially weaken the OOS conclusion, or is directional-lean-with-clean-DD4-across-multiple-regimes sufficient?

**On the depth-cap finding (Section 5e):**
- Is the claim — that this architecture structurally cannot reach double-digit layer depth under any realistic historical condition — adequately supported by the evidence given (code-level confirmation of the exit/add threshold asymmetry, plus empirical confirmation across five windows including the most extreme one available), or does this require more rigorous statistical characterization (e.g., a formal probability argument, rather than an empirical "we tried five windows and it never happened") before being treated as an architectural property rather than an untested edge case?
- If the depth ceiling genuinely can't be reached, does that change your assessment of `WIDEN_RATIO=1.304`'s justification (Section 2a of your original audit) — i.e., if the geometry's divergence from the old `GridExpBase=1.5` only matters at depths this system structurally can't reach, is the specific value of `WIDEN_RATIO` now a moot architectural detail rather than a load-bearing risk parameter?

**On the LDAK correction (Section 7):**
- Does confirming LDAK is live, cross-pair-aware, and purpose-built for correlated moves adequately resolve the cross-currency correlation concern for the geometry question this ADR addresses (vertical depth capacity) — while correctly leaving the question of whether LDAK itself is *sufficient* under this new geometry as a separate, not-yet-tested question requiring a joint 3-pair simulator?

**On the recurring MTM artifact:**
- Is "genuinely positive realized P&L, masked by end-of-window MTM on a going-concern system" a sound characterization across all three instances now documented, or is there a subtlety being missed — e.g., could realized P&L itself be biased or overstated in some way not yet checked (survivorship within a single simulated path, or something else)?

**Bottom line question:** given all of the above, do you consider the Override Rule still warranted on any of this new material, or is ADR-091 (as now written) ready to proceed to a Phase 3 Gemini ruling?

---

## 3. Files provided

- `ADR-091-grid-spacing-geometry.md` — updated, full document, this pass's primary subject.
- Your own original Phase 1 audit report, in full, for reference/continuity.
