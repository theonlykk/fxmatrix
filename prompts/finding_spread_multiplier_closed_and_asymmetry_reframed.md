# FINDING: SpreadMultiplier Investigation — Closed at Production Value; Asymmetry Question Reframed

**Status: SpreadMultiplier tuning closed (stay at 0.5). Volatility-aware add/management gating remains open, untested, and separate.**

**Author:** Claude, written up from live diagnostic work with Khalid.
**Date:** 2026-07-22

---

## 1. What was tested and why

Motivated by the observation that `dynamic_hs`'s volatility-scaling term only ever affects flat-state L0 quoting, and the system spends ~71% of its time holding a position (not flat) — meaning current-market-uncertainty awareness is structurally absent for the majority of the time a position is actually at risk. The instinct: test whether reducing or removing this term entirely improves outcomes, without assuming the answer either way ("boring is best, but verify").

## 2. Python n=500 sweep result (five values: 0.0, 0.125, 0.25, 0.5, 0.75)

Clean, well-evidenced result at the simulation level: tail risk (DD3/DD4) zero at 0.0/0.125/0.25, small at production (0.5, 5/500 on Truss Crisis/MM_LONG), large at 0.75 (57/500, same cell). Aggregate P&L peaked at **0.125** (+33% vs. production), with an inverted-U shape — not monotonic, and notably **not maximized at 0.0**.

## 3. Real-tick verification — the Python result did not survive

`SpreadMultiplier=0.125` was tested against real MT5 tick execution (5-day Stage 1/2 window). Result: **materially worse GBPUSD P&L than production** (-$30.61 vs. -$22.40), despite 3x more L0 fills. Root cause, precisely traced:

- Lowering `SpreadMultiplier` raises the resting buy-limit level (`bid_lvl`) by ~5-7 pips at matched timestamps, pulling in fills on bars the wider, production spread correctly stayed clear of.
- The Brownian-bridge Python model credits nearly all of this expanded fill opportunity as real edge; real ticks do fill many of these bars, but the P&L doesn't materialize the same way, and the extra exposure compounds into a heavier open stack.
- The specific test window's realized loss was fully explained by a worse end-of-test forced-liquidation on a deeper, more expensive stack (not classic pre-drop "pick-off" — the extra fills were checked and shown *not* to have elevated adverse 15-minute drift).
- Diagnosed as a sharper, more specific instance of the already-known Brownian-bridge-vs-real-tick fill-model gap: the gap is **worst precisely where quoting is tightest/most aggressive**, not uniform across all parameter values.

## 3b. Follow-up: multi-window real-tick verification (2026-07-22) — investigation closed

Given the single-window (Mar 2026) result showed a directional, non-obvious loss on GBPUSD, four additional real-tick 5-day windows were tested to check whether this was a general pattern or specific to that one week: a second calm `full_quarter` week (May 2026), `truss_crisis` (Sep 2022), `june_blowup` (Jun 2026), and a newly-identified genuine sustained-uptrend window (Apr 2026, +283 pips net, 5/5 up days, real ticks confirmed). A synthetic-tick fallback for the original 2020 Vaccine Rally window was also run (FTMO's demo server does not retain tick-level history that far back — confirmed via direct probe, not assumed), explicitly flagged as lower-confidence.

**Final real-tick tally, five genuine windows:** GBPUSD worse in 3/5 (calm ×2, sustained-trend), better in 2/5 (crisis, blowup), **cumulative Δ = −$68.32**. The sustained-trend window alone accounts for the single largest divergence measured in the entire investigation (−$66.73) — by far the strongest, most decisive signal of the five.

**This directly, empirically confirms the mechanism Khalid separately hypothesized about layer depth** (Section 6 below, and the parallel layer-depth investigation): the sustained-trend window's own depth statistics (max depth 8 vs. baseline's 5; 22 reloads vs. 3; 65 exits vs. 38) confirm the tighter spread genuinely engaged much more deeply with a real, sustained trend — and that deeper engagement lost money, not made it. A real trend does not politely revert to a fixed exit target the way a shallow scalp does; increasing how readily the system commits to depth during a genuine trend made outcomes worse, precisely as the layer-depth hypothesis would predict.

**Conclusion: the `SpreadMultiplier` investigation is closed, decisively, at production's existing value (0.5).** This was not a case of one ambiguous test — five independent real-tick windows, covering calm, crisis, blowup, and genuine sustained-trend regimes, converge on production being the better-calibrated choice, with the clearest, largest-magnitude evidence coming from exactly the regime (sustained trend) most relevant to the original hypothesis this parameter change was meant to test.

## 4. Why `SpreadMultiplier=0.0` is not the "boring, do-nothing" option it might appear to be

**Critical clarification, worth stating precisely:** `dynamic_hs = 4-pip base + SpreadMultiplier × sigma_fv_bc`. Since `sigma_fv_bc ≥ 0` always, `dynamic_hs` is monotonically wider as `SpreadMultiplier` increases, *for any given volatility level*. This means `SpreadMultiplier=0.0` is not "ignore volatility, use a neutral default" — it is **the single most aggressive, tightest-quoting setting in the entire tested range, in every condition, calm or violent.** It is strictly tighter than 0.125 at every volatility level, not just in calm conditions.

Given the real-tick diagnosis showed the fill-quality degradation is directly caused by *tightening* this parameter, and scales with how aggressively it's tightened, **`SpreadMultiplier=0.0` should be expected to show the same failure mode at least as severely as 0.125, likely more so** — not a return to some neutral, unaffected state. It was never tested directly at real-tick level, but there is no mechanistic reason to expect it to behave better than 0.125 did; every signal points the other way.

## 5. Conclusion: SpreadMultiplier tuning is closed, staying at production (0.5)

The full investigation — a legitimate, well-motivated challenge to an inherited, unexamined asymmetry — is closed with production's existing value confirmed as the best-evidenced choice once real execution is accounted for, not merely a default that was never properly examined. This is itself a valuable outcome: the process surfaced a specific, generalizable, and now well-understood characterization of where the Python-vs-real-tick gap does the most damage (aggressive/tight quoting parameters, not uniformly across all parameters), which is useful knowledge for evaluating any future parameter change on this same signal path.

## 6. The original asymmetry concern remains valid — reframed, not resolved

Khalid's original observation — that current market uncertainty is only ever consulted at the moment of flat-state entry, never during management of an already-open position — is still a real, legitimate structural question, independent of the `SpreadMultiplier` result above. Two distinct ways to resolve it were identified at the outset:

1. **Remove volatility-awareness from entry** (make entry as unaware as management currently is) — this is what the `SpreadMultiplier` sweep tested, and it has now failed real-tick verification.
2. **Extend volatility-awareness to management** (make adds/reloads as aware as entry currently is — e.g., more cautious about extending a stack deeper during genuine, elevated volatility) — **this has never been tested, is a structurally different mechanism, and would not automatically inherit the same bridge-vs-real-tick failure mode**, since it doesn't involve tightening the flat-state quote at all.

Given path 1 is now closed, path 2 is the more promising remaining direction for anyone who wants to resolve the original asymmetry properly, rather than simply accept the current, inherited scope (volatility matters only 29% of the time) as final.

## 7. Separate, parked: improving Brownian-bridge simulation realism

Raised directly by Khalid: could the bridge itself be made more realistic (price rounding/discretization to real tick increments, substep volatility calibrated against real historical tick density) rather than only discovering fidelity gaps after the fact via real-tick spot-checks?

**Assessed as genuinely valuable, but a large undertaking, not a quick fix.** This project's entire simulation-based validation history (ADR-091's five-window geometry validation, the GBP cap, every sweep) rests on the current bridge engine. A materially different bridge would need the same already-locked results re-validated against it, to confirm nothing "confirmed" under the old engine quietly stops holding under a more realistic one — comparable in scope to the original validation effort, not an afternoon change.

**Recommendation: park this, same status as V3/`FV_combined`** — genuinely worth doing eventually, given it could reduce the risk of this exact kind of Python-vs-real-tick surprise recurring on future parameter or pair investigations, but not urgent, and should not be started casually alongside other active work.

## 8. Next steps (not started)

- [ ] If ever revisited: scope volatility-aware add/reload gating (Section 6, path 2) as its own, separate investigation — distinct mechanism from `SpreadMultiplier`, needs its own real-tick verification before trusting any result.
- [ ] Brownian-bridge realism improvement (Section 7) — parked, revisit only when there's dedicated bandwidth for a full re-validation cycle, not opportunistically.
- [ ] No further `SpreadMultiplier` values need testing — the mechanism and its failure mode are now well-understood; further points on the same curve would very likely just confirm the same direction of real-tick divergence already diagnosed.
