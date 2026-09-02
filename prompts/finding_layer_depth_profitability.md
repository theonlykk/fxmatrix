# FINDING: Layer Depth Is Not Uniformly Profitable — Damage Concentrates in Genuine Trends, on the Disfavored Side

**Status: CLOSED — full n=500 validation complete. Directly informs V2.1's imbalance-easing mechanism (see companion concept document).**

**Author:** Claude, written up from a live hypothesis test with Khalid.
**Date:** 2026-07-22

---

## 1. The hypothesis

Khalid's original observation: reaching real depth (L2+) requires a genuine, developing trend — enough participants caught offside that momentum/trend-following capital enters — a fundamentally different market condition than a shallow, first-layer scalp. Hypothesis: L0/first-add layers should show a structurally higher per-trade edge than deeper layers, because deep layers are disproportionately opened during exactly the kind of sustained move a mean-reversion exit target is least suited to.

## 2. Method

Built dedicated tooling (`scripts/run_layer_depth_analysis.py`) tagging every simulated layer by the depth at which it opened, tracking whether it resolved at its own individual exit target versus getting "buried" (a deeper layer opening before it closed). Full n=500 Monte Carlo, all five validated historical windows, both spacing modes (`reload_anchor`, `reload_flat`), all three bias modes (MM_LONG, MM_SHORT, MM_BOTH) — 30 cells total, GBPUSD, production geometry.

## 3. Result — confirmed, with important nuance

**24 of 30 cells show L0-1 more profitable than L2+** (aggregate mean +$0.137 vs. −$0.145 per layer). But the pattern is not uniform "shallow always wins" — it is specifically concentrated in trending/stress conditions:

- **10 of 30 cells** show the clean "damage concentrates at depth" signature (L0-1 positive, L2+ negative) — every one of these occurs on the side caught wrong-footed by a real, known directional move for that window (MM_SHORT during Truss Crisis and June Blowup — both confirmed GBP-adverse events; MM_LONG/MM_BOTH during Vaccine Rally and Q1 2024 Chop).
- **2 further cells** (Vaccine Rally/MM_SHORT) show both depths negative, with L2+ roughly 3x worse — the disfavored side losing from its very first layer, with depth compounding an already-bad starting position.
- **The 6 exceptions where L2+ matches or beats L0-1** occur exclusively in calm/choppy conditions (`full_quarter` — both spacing modes, MM_SHORT; `q1_2024_chop`/MM_SHORT) — reaching depth in a genuinely range-bound market does not carry the same adverse-selection risk, since it isn't driven by the same capitulation/momentum dynamic.

**Mechanism directly confirmed via resolution-time data:** L2+ layers take **2.4x longer** to resolve on average than L0-1 (82.2 bars vs. 33.8), with extreme tails in stress windows (June Blowup: ~220-264 bars at L2+ vs. ~123 at L0-1). L2+ also shows a **62% higher rate of genuine sustained adverse continuation** within the first hour after opening (38.1% vs. 23.6%). This is a direct, measured confirmation of the original hypothesis's mechanism — not correlation, but a quantified signature of real trend entanglement versus quick mean reversion.

## 4. What this does not support

**Not evidence for exiting or avoiding depth.** Reacting to this by closing positions early at L2+ would convert temporary, on-paper drawdown into permanently realized losses — precisely the mark-to-market-vs-realized distinction this project's validation has always depended on, and would forfeit the recovery mechanism (`reload_flat`) that makes this a market-making system rather than a stop-loss strategy. The finding characterizes depth's *statistical* risk/reward profile; it is not a signal to abandon positions once there.

## 5. Reframing, per Khalid — not "big moves that revert," but "the market relocating to a new range"

Rather than viewing a sustained move as a large deviation that will eventually correct back, a more accurate model (matching this data) is that markets spend most of their time in small, contained trading ranges, punctuated occasionally by a genuine relocation to a new range. Under this view, one side reaching real depth (confirmed, per this analysis, to require genuine capitulation/momentum dynamics, not noise) is **direct, real-time evidence that such a relocation is underway** — not merely a risk to be managed on the losing side, but **a real, working signal that the currently-unengaged opposite side should act on directly and promptly**, not treat with the same cautious, incremental entry logic used during ordinary, range-bound conditions.

## 6. Direct connection to V2.1

This dataset is the empirical foundation for V2.1's imbalance-driven easing mechanism (see companion concept document). Specifically: Vaccine Rally/MM_SHORT (both depths negative, L2+ ~3x worse) is the concrete target scenario the mechanism is designed to intervene in — not by protecting the losing side, but by actively easing the currently-correct opposite side's engagement the moment a real, confirmed imbalance signal appears.

## 7. Artifacts

`scripts/run_layer_depth_analysis.py`, `temp/layer_depth_analysis_n500_report.json` (Surface, n=500, ~5.2hr runtime, all 30 cells) — uncommitted pending review.
