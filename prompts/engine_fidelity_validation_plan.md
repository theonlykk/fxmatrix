# Simulation Engine Fidelity Validation — Python Sim vs. Real MT5 Tester

**Status: QUEUED — not started. Waiting on the three current n=500 OOS runs (Truss Crisis, Vaccine Rally, Q1 2024 Chop) to finish first.**

**Date:** 2026-07-12

---

## 1. The problem this addresses

Every n=500 result this project has ever produced — the original two windows (`full_quarter`, `june_blowup`), the ADR-091 corrected-geometry validation, and the three new OOS windows currently running — rests on trusting that `grid_sim_v7_real_signal.py`'s internal mechanics (fill logic, exit triggering, spread handling, P&L accumulation, drawdown tracking) faithfully reproduce what a real MT5 backtest would compute. **This has never actually been tested end-to-end, at any point in this project's history.**

What *has* been verified against real MQL5 so far:
- The signal formula itself (`ComputeTermStructure`, `InvertSpreadToPrice`, score decomposition) — verified numerically to 5 decimal places against production code retrieved via Cursor.
- The ADR-013 gap-aware entry clamp — same treatment, verified.
- **One single day** of Layer-0 entry timing (the reanchor-off reference backtest) — confirmed the "bar-close only, does not tick-react" claim for that one day. This explicitly checked timing/price only — never P&L, drawdown, or layer-depth progression, and was never repeated.

What has **not** been verified, ever:
- Whether the simulation's fill logic, exit triggering, P&L accounting, or drawdown tracking match a real MT5 Strategy Tester run, for any period, under any formula.

This is a real gap, independent of and more fundamental than the ADR-091 geometry work — if the simulation engine itself has a systematic bias (in how it fills, exits, or handles spread relative to real MT5), every DD3/DD4 threshold, every mean P&L figure, every "clean pass" this project has produced could be silently off in ways none of the existing bug-hunting (the `last_exit_price` fix, the `ADD_PIPS_CEILING` fix) would have caught, since all of that scrutiny has been internal to the Python code, or checked against DeepSeek's reasoning — never against real ground truth.

---

## 2. Why this can't wait for the MQL5 port (Stage 4/5), but also isn't blocked by it

The new ADR-091 geometry (`WIDEN_RATIO=1.304`, `reload_flat`/`reload_anchor`) doesn't exist in MQL5 at all — there's no live equivalent to backtest and compare against yet. That comparison is correctly sequenced as Stage 5 in the project roadmap, after the actual Cursor port (Stage 4).

**But the *old*, currently-live formula (`GridExpBase=1.5`, and whatever the live reload/exit behavior actually is) exists in both places right now** — real MQL5 in `ea/ExecutionEngine.mqh`/`ea/MathEngine.mqh`, and (with the right config) as the "pre-ADR-091" baseline in `grid_sim_v7_real_signal.py` / `grid_sim_v6_dynamic_spacing.py`. This means the **simulation engine's fidelity can be tested today**, entirely independent of whether the new geometry has been ported — and doing so validates the tool underlying every result so far, not just the new geometry.

---

## 3. Proposed test design

1. **Pick one historical window** already used elsewhere in this project (e.g. `full_quarter` or `june_blowup`) so results are directly comparable to existing evidence.
2. **Run a real MT5 Strategy Tester backtest** over that window with the *current live* EA configuration (`GridExpBase=1.5`, live reload/exit logic, no ADR-091 changes) — same method already proven to work for pulling historical data (headless `/config:` Tester run).
3. **Configure the Python sim to match the old formula** — confirm `grid_sim_v6_dynamic_spacing.py` (or `grid_sim_v7_real_signal.py` with `WIDEN_RATIO=1.5`, `ADD_PIPS_CEILING=100`) can actually reproduce the pre-ADR-091 behavior; this needs checking, not assuming, since v7 has evolved substantially since v6 was last the reference.
4. **Compare directly, same window, same starting conditions:**
   - Total entry count and exit count
   - Realized P&L (not blended MTM — per the KPI redefinition Gemini already ruled on)
   - Max layers reached
   - Peak drawdown (DD3/DD4-equivalent, or raw peak intrabar drawdown if the live EA doesn't track the same metric)
5. **Assess the gap.** Some divergence is expected and fine (real MT5 has execution nuances — slippage modeling, tick-level fill precision — the Python sim's Brownian-bridge substep approach only approximates). The question is whether the *magnitude and direction* of any P&L/drawdown discrepancy is small and explainable, or large and systematic — the latter would mean every prior n=500 result needs re-examining for bias, not just noted as a caveat.

---

## 4. Open questions to resolve before running this

- Does `grid_sim_v6_dynamic_spacing.py` or a reconfigured `v7` actually reproduce the *current* live formula precisely, or has live MQL5 (`ExecutionEngine.mqh`) drifted since v6 was last treated as the reference? Needs a direct check, not an assumption.
- Does the live EA even expose/log the same P&L and drawdown figures needed for a clean comparison (realized vs. unrealized split, in particular) — or does this comparison itself require some new logging on the MQL5 side first?
- What single historical window is most useful to start with — `full_quarter`/`june_blowup` (maximizes comparability to existing results) vs. one of the new OOS windows (maximizes stress on the comparison, given they're more extreme)? Leaning toward starting with an existing window for comparability, then extending to Truss Crisis once the basic method is validated.

---

## 5. Draft Cursor request (not yet sent — queued)

To be sent once the three current n=500 OOS runs complete and this plan is reviewed:

> READ-ONLY DIAGNOSTIC REQUEST, then a small implementation step if the above checks out.
>
> Purpose: validate the Python simulation engine's fidelity against a real MT5 Strategy Tester run, independent of the ADR-091 geometry work, using the current *live* formula (`GridExpBase=1.5`) as the common reference point that exists in both places today.
>
> 1. Confirm whether `grid_sim_v6_dynamic_spacing.py` or a reconfigured `grid_sim_v7_real_signal.py` (`WIDEN_RATIO=1.5`, `ADD_PIPS_CEILING=100`) currently reproduces the live EA's actual add-spacing and reload behavior, or whether live MQL5 has diverged since v6 was last a faithful reference.
> 2. Run a real MT5 Strategy Tester backtest over `full_quarter` (or `june_blowup`) with the current live EA config, verbose logging on, and report: total entries, total exits, realized P&L, max layers reached, peak drawdown.
> 3. Run the Python sim over the identical window/config, report the same metrics.
> 4. Report the deltas directly, with no editorializing about whether they're "acceptable" — just the raw comparison, so Khalid and Claude can jointly assess materiality.

---

## 6. Why this matters for the current roadmap

This doesn't block the three OOS runs in progress, and doesn't block folding LDAK/OOS results into ADR-091. But it should happen **before** ADR-091 goes back to DeepSeek/Gemini for final closure — it underwrites confidence in literally every piece of simulation evidence in this project, not just the new geometry, and it's the kind of foundational check that's cheap to do now and expensive to discover was missing later.
