# CONCEPT: V2.1 — Closed-Loop Spread Formula with Imbalance-Driven Easing

**Status: PARKED — a full, deliberate undertaking, not started. Explicitly bigger than an add-on to the existing formula; replaces its core philosophy.**

**Author:** Claude, written up from a live design discussion with Khalid.
**Date:** 2026-07-22

---

## 1. The core idea, in one sentence

Replace the current spread formula's dependence on a lagging, indirect volatility proxy (`sigma_fv_bc`) with a fixed, per-pair-derived baseline spread, and manage risk instead through a deliberate mechanism that makes it *easier for the currently under-exposed side of a pair to engage*, in proportion to confirmed lot-size imbalance between `MM_LONG` and `MM_SHORT`.

## 2. Motivation — why the current formula is unsatisfying

Raised directly by Khalid, following a full day of `SpreadMultiplier` investigation (see companion finding document) that closed with production's existing volatility-scaled formula confirmed correct as-is:

- `sigma_fv_bc` is a rearward-looking dispersion measure — a proxy for market uncertainty, not a direct measure of the system's own actual, known risk. It can lag a real move just starting, or overreact to noise that was never going to matter.
- This morning's separate diagnostic confirmed the volatility term **only ever affects flat-state L0 quoting** — once any layer is open, add/reload targets are already completely blind to live conditions, on a fixed mechanical schedule. This creates the exact asymmetry Khalid identified: an already-engaged instance keeps adding at a fixed clip during a real, elevated-volatility move, while the flat/under-exposed opposite side faces a compounding double headwind (price drifting away, plus the L0 quote itself pushed wider by the same volatility spike) — skewing risk toward the side already committed, at exactly the moment it matters most.
- Philosophically: "boring is best" argues for relying on deterministic, already-known, already-validated quantities over indirect statistical proxies wherever possible. The confirmed signal (log-return difference) and actual held risk (lot imbalance) are both things the system already knows for certain; volatility is an estimate about something it doesn't.

## 3. The three traditional risk levers, and why none of them work well for a stuck position

Explicitly considered and rejected, in favor of the fourth option below:

1. **Stop out / close the losing side** — realizes a loss that would very plausibly have mean-reverted; runs directly against the entire realized-vs-MTM philosophy this project has built its validation around.
2. **Reduce add lot size** — not granular enough to matter meaningfully at 0.01-lot increments.
3. **Widen the add distance** — this morning's `SpreadMultiplier` investigation (closed, documented separately) showed directly, via real-tick verification, that this either delays the same problem or simply reduces trading activity — it does not resolve the underlying imbalance, and in a genuine sustained trend it actively lost money (the single largest divergence measured in that whole investigation).

## 4. The fourth lever: ease the *other* side, don't touch the losing side

**Core insight, worth stating precisely:** none of the traditional levers touch the side of the pair that's actually correct. A lopsided lot imbalance (e.g., `MM_LONG` deep, `MM_SHORT` flat) is itself confirmation that a real, directional move has occurred — the imbalance *is* the signal. Making it easier for the under-exposed, currently-correct side to engage:

- **Reduces net portfolio risk** — new opposite-side exposure is a genuine, natural hedge against the existing drawdown, not just diversification.
- **Increases trading activity** — rather than throttling the losing side (less trading) or leaving it to dig in statically, it actively brings the winning side online.
- **Does not inherit the just-diagnosed `SpreadMultiplier` failure mode** — that mechanism failed because it *unconditionally* tightened quoting at all times, fighting real trends via mean-reversion adds on the *same*, already-committed side. This mechanism is conditional (only fires on confirmed imbalance) and trend-aligned (eases the side that would profit from the trend continuing), not trend-fighting.

This is a genuinely rare case where "reduce risk" and "increase trading" point the same direction rather than trading off against each other — normally opposed goals in this kind of system.

## 5. Proposed structure (not yet built)

**A. Fixed, per-pair baseline spread**, replacing the volatility-scaled term entirely — derived from each pair's own real historical mean `sigma_fv_bc` (not borrowed across pairs, same lesson as every prior pair-specific calibration this project has learned):
- GBPUSD: `4 + 0.5 × 8.11 ≈ 8.05 pips` (already-confirmed figure, close to "8bps")
- EURUSD: `4 + 0.5 × 6.08 ≈ 7.04 pips`
- EURGBP: `4 + 0.5 × 2.38 ≈ 5.19 pips`

These are rough estimates from already-known mean-sigma figures — the actual V2.1 work should derive these properly from the full historical distribution per pair, not just the mean-sigma shortcut.

**Deliberate trade being made, stated explicitly:** a fixed baseline means giving up *all* adaptive widening during genuine extreme stress, not just calm periods — worth naming plainly rather than treated as incidental. Partial supporting evidence already exists: today's `SpreadMultiplier=0.0` Python check (functionally similar — no volatility reaction) showed zero DD3/DD4 across every window including Truss Crisis, but this has not been confirmed at real-tick level for a fully volatility-blind configuration specifically.

**B. Imbalance-driven easing**, applied to *both* flat-state L0 quoting and every subsequent add/reload target on the under-exposed side (not scoped to L0 only) — corrected, symmetric form (both sides can be favored depending on which is under-exposed):

```
dynamic_hs_effective(side) = max(baseline − taper(imbalance), floor)
```

Where `taper()` scales from a full correction (an agreed starting point: 4bps) at a "concerned" imbalance level, linearly down to zero once the gap narrows to some smaller, agreed level — exact thresholds not yet set (see Section 6).

**Floor, corrected from an earlier mistaken assumption:** not tied to the 3-pip exit target (a different, unrelated quantity) — the real constraint is passivity: `dynamic_hs` must stay comfortably above half the real market spread for that pair, with genuine margin, derived from real historical spread data, not guessed.

## 6. Open question, explicitly flagged, needs real data before deciding

**What is the right metric for "imbalance"?** Raised directly by Khalid: the same *absolute* lot-size gap can represent very different situations depending on scale — e.g., 0.01 vs. 0.05 (one side nearly flat, a clean signature of one dominant move) versus 0.04 vs. 0.08 (both sides already substantially engaged, possibly genuine two-way chop rather than one clear trend) — both a 4-layer/0.04-lot absolute gap, but arguably not equally significant. A **ratio**-based view (5x vs. 2x in this example) would rank them oppositely from the absolute-difference view. Total combined exposure may also matter independently of either. **This should be settled by looking at the real historical distribution of lot-size differences across validated windows, not decided from intuition** — the natural first concrete analysis step for this whole project.

## 7. Explicit scope and status

**This is genuinely V2.1-scale work, not an addition to the existing V2 formula** — it replaces the core spread computation's underlying philosophy, not just adds a term on top of it. Given V2's own stated priority (let the current, already-validated system run and prove itself further before layering anything new on top — the same reasoning already applied to `FV_combined`/V3), this is parked at the same tier as those other large, deliberately-deferred questions, not scheduled.

## 9. Gemini review (2026-07-22) — one hard requirement added, one proposed formula critiqued

Gemini reviewed this concept and confirmed the core diagnosis and the "ease the under-exposed side" mechanism as sound. Two substantive additions from that review, both incorporated here:

**Hard requirement, added to Section 5's floor definition:** the passivity floor cannot be a static, historically-derived number alone — it must incorporate the **live, real-time broker spread** at the moment of quote placement: `dynamic_hs_effective = max(baseline − taper(imbalance), live_broker_spread + buffer)`. Rationale: a fixed baseline (no adaptive widening) combined with imbalance-driven tapering could, during a genuine liquidity void (e.g., an NFP print or surprise macro shock, where real spread can blow out to 25+ pips instantaneously), place a resting limit *inside* the real market spread — turning a passive market-making order into one that fills immediately at the worst possible price (adverse selection). This sharpens and makes concrete the risk already flagged in Section 5 ("deliberate trade being made... giving up all adaptive widening during genuine extreme stress") — this is now a hard, non-negotiable engineering requirement for V2.1, not just a caveat.

**Proposed formula for the imbalance metric (Section 6), and a specific flaw identified in it:** Gemini proposed `Imbalance = max(Lots_Long, Lots_Short) / (min(Lots_Long, Lots_Short) + ε)`, correctly noting absolute difference is scale-blind (Section 6's original concern). **This specific formula has its own real flaw, identified in review, not yet resolved:** a pure ratio blows up precisely at the smallest, least-confirmed imbalances — the very first layer filling on one side while the other is still genuinely flat produces a near-maximal ratio reading, despite being the most trivial, least-diagnostic case (one side's first fill will essentially always precede the other's by chance alone, in almost every cycle). This is the opposite of the desired sensitivity profile. **Any ratio-based metric needs either a minimum-engagement gate (don't evaluate until both sides have some minimum depth) or a different functional form that doesn't diverge near zero** — not resolved yet, and should be one of the candidate metrics tested against real historical distribution data (Section 8's first step), not adopted on paper-reasoning alone.

**Gemini's explicit recommendation, consistent with existing plan:** do not write any implementation code yet; keep parked while V2 runs live; when engineering resumes, begin with the historical Exposure-Ratio (and alternative metric candidates) distribution pull across the five validated windows.

## 10. Aside: this is, structurally, hedged/recovery grid trading

Worth naming directly: the dual opposing-grid structure (`MM_LONG`/`MM_SHORT` simultaneously) was never novel — this is a well-known pattern in retail/prop FX (sometimes "hedged grid" or "recovery trading"), and it has a well-earned poor reputation in that community, largely because most public implementations use crude, unaudited rebalancing logic (often literal martingale-style lot-doubling on the hedge side), with no genuine out-of-sample validation discipline. What this project's version aims to do differently — deriving thresholds from real historical distributions, full n=500 validation across genuine historical stress regimes, real-tick verification before trusting any result — is plausibly the actual differentiator from the failure-prone versions of the same underlying idea, not a claim that the core concept itself is new.

## 12. Empirical foundation, confirmed (2026-07-22) — and a reframing of what this mechanism actually is

The layer-depth profitability hypothesis (raised alongside this concept, tested independently) has been fully validated at n=500 across all five windows (see companion finding document, `finding_layer_depth_profitability.md`). Confirmed: damage concentrates specifically at depth (L2+), specifically on the side caught wrong-footed by a genuine, sustained trend — never in calm/range-bound conditions. Directly confirmed via measured mechanism: L2+ layers take 2.4x longer to resolve and show a 62% higher rate of genuine sustained adverse continuation than L0-1. The single most relevant cell — Vaccine Rally/MM_SHORT, both depths negative, L2+ ~3x worse — is the concrete target scenario this mechanism is designed to address.

**Important reframing, per Khalid, worth carrying forward as the primary lens for this mechanism rather than a secondary benefit:** rather than modeling a sustained move as a large deviation that will eventually revert, the more accurate picture (consistent with the confirmed data above) is that markets spend most of their time in small, contained trading ranges, punctuated occasionally by a genuine relocation to a new range. Under this view, one side (e.g., `MM_LONG`) reaching real, confirmed depth is not merely "something risky happening that the other side should be protected from" — it is **direct, live evidence that a real regime relocation is underway**, and the correct response to a real, working signal is **prompt, decisive engagement on the other side, not the same cautious, incremental entry logic used during ordinary range-bound conditions.**

This reframes the mechanism's core purpose: it is not primarily a risk-reduction technique that happens to also increase trading (as originally framed in Section 4) — it is primarily **an alpha-capture mechanism responding to a genuine, confirmed directional signal**, which happens to also reduce net portfolio risk as a direct consequence of correctly acting on that signal. This distinction matters for how aggressively the taper function (Section 5B) should ease entry once triggered: the goal is not merely "reduce excessive caution," but "respond promptly and meaningfully to a signal now confirmed, empirically, to carry real, sustained predictive power."

## 14. Clarification on volatility's role — not elimination, but not sole reliance either (2026-07-23)

A real, severe live episode (2026-07-23: GBPUSD σ_fv_bc reaching ~18 pips, roughly 2.6x its validated median, driven by a genuine, unusual confluence of macro events — an ECB policy decision, Middle East escalation, and UK CPI all landing the same day) prompted a direct re-examination of this concept's original framing, and a useful clarification worth recording precisely.

**Volatility is confirmed, directly, to be real and correctly-functioning information — not a nebulous or flawed signal.** The live episode's `dynamic_hs` widening was checked against the actual formula and found to be an exact, correct mechanical response to genuinely elevated, sustained, real market uncertainty (not a bug, not deadband interference, not stale quoting) — the system behaved exactly as designed and validated.

**But this week's `SpreadMultiplier` investigation (see companion finding document) already showed, with real-tick evidence, that relying on volatility *alone*, as the sole determinant of flat-state quote width, produces worse real outcomes when its influence is reduced — the marginal-fill contamination mechanism identified in that investigation.** The correct synthesis of both findings is: **volatility should not be eliminated as a signal, and it should not be relied upon alone.** It correctly captures genuine market-wide uncertainty, but has no way to distinguish "be broadly cautious about opening new exposure" from "a specific, already-confirmed directional signal exists and should be acted upon promptly" — those call for different responses, and volatility alone cannot tell them apart.

**This reframes V2.1's actual value proposition, worth stating precisely so this document doesn't drift toward "remove volatility" when eventually picked up:** the goal is not a volatility-free system — it is a system where volatility's legitimate signal is *combined with* a second, deterministic signal (confirmed inventory imbalance) that volatility structurally cannot provide on its own. Section 5's fixed-baseline proposal should be revisited with this in mind: the eventual design may retain some volatility-awareness in the base spread (since today's episode confirms real value in that alone) while adding imbalance-driven easing as the mechanism that specifically captures what volatility cannot — genuine directional confirmation, not just generalized uncertainty.

## 15. Next steps (updated)

- [ ] **First concrete step:** analyze the real, historical distribution of `|lots_MM_LONG − lots_MM_SHORT|` **and multiple candidate imbalance metrics** (raw ratio, gated ratio with a minimum-engagement threshold, log-ratio, absolute difference) across all five validated windows — test which metric actually best distinguishes genuine, developed one-sided moves from early/trivial/coincidental imbalance, rather than adopting any single formula (including Gemini's proposed pure ratio, which has a known flaw near zero-denominator) on paper-reasoning alone.
- [ ] Derive proper, full-distribution (not mean-sigma-shortcut) fixed baseline spreads per pair.
- [ ] Derive the real passivity floor per pair from historical spread data (same discipline as every other floor derived this week).
- [ ] Design and calibrate the taper function (starting correction magnitude, thresholds) once the imbalance-distribution analysis is in hand.
- [ ] Full n=500 Python Monte Carlo validation across all five windows, same rigor as every other parameter this project has tested, before any real-tick verification.
- [ ] Real-tick verification, same standard as every other change — with particular attention to whether the fixed baseline (no adaptive widening at all) holds up during genuine extreme/gap conditions, not just the calm-vs-trend distinction already tested for `SpreadMultiplier`.
- [ ] Full DeepSeek/Gemini review given this replaces the core, already-locked signal/spread computation for all three live pairs.
