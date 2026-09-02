# PARKED IDEA: Stale-Stack Re-Engagement Mechanism

**Status: PARKED — not scheduled, not scoped, no implementation started.**
Explicitly deferred by Khalid to focus on other priorities first (Truss Crisis dual-topology sizing fix, 4f gap test). Revisit once those are resolved.

**Author:** Claude, written up from a live finding during ADR-092 Stage 5 analysis.
**Date:** 2026-07-14

---

## 1. The finding that motivated this

Stage 5 (dual-topology `fxmatrix_v2` Truss Crisis backtest) showed `MM_LONG` frozen at 4 layers for **over two days** (2022-09-23 17:36:18 through the peak-DD moment on 2022-09-26 04:15:16), with **zero fills** during that entire window, while the market fell roughly 1,700 pips away from its entries. `MM_SHORT`, meanwhile, was actively cycling on the other side. LONG's frozen stack contributed the large majority of the unrealized loss (−$524 of the −$556 combined) driving Stage 5's 4.87% equity drawdown — not because it was doing anything wrong mechanically, but because it had **no way to resume active trading** once the market moved decisively away from its price zone. It just sat there, unable to exit (no favorable move reached its layers) and unable to add (adds are anchored to the same stale zone).

## 2. Why existing live mechanisms don't solve this

Checked directly against `FXMatrix.mq5` source (see full investigation: Gemini initially recalled a "three-system" cooldown/re-anchoring design; verified against actual code that none of the three shipped mechanisms address this scenario):

- **ADR-046/048/060 cooldown drag** — only touches flat-state Layer-0 quotes, never a stack that's already deep and open.
- **ADR-078 exit-reset delay** — only fires on a LIFO exit event. LONG had zero exits during the freeze; this path never triggers. (Also off by default in production.)
- **ADR-079 dynamic re-anchor** — only fires at `add_next` placement when passivity is violated, and even then only preserves *distance* from the same stale entry price — it doesn't reset the anchor to reflect a genuinely new market regime. (Also off by default.)
- **ADR-057 kinetic gate** — governs add spacing/timing, still anchored to the same stale `deepest.entry_price`. At depth 4, it makes further adds *harder*, not easier.
- **"Finding 3"** (proposed in `findings_exit_reset_kinetic_anchoring.md`) — the closest conceptual match, proposing time-decay of a *resting, unfilled* `add_next` order. **Never implemented.** Even if it were, it only nudges an unfilled order — it doesn't address a stack with underwater layers and no exit path at all.

**Conclusion: this needs to be designed from scratch. Nothing in the current codebase, enabled or not, solves it.**

## 3. Framing, per Khalid

Not framed as "prevent staleness" — the only real fix for a stuck position is to trade through it, not sit passively. The actual proposal, in Khalid's words: keep trading, and specifically lean into the side that *can* still trade (per the parked cross-instance sizing idea — Mechanism 1, see Section 4), while separately giving the stuck side a way to re-engage in whatever price zone the market has actually settled into, rather than waiting indefinitely for a return to a level that may never come back.

## 4. Relationship to the parked cross-instance sizing idea

This is a distinct but related mechanism, worth developing together rather than in isolation, since they interact:

- **Mechanism 1 (already parked, `parked_idea_cross_instance_sizing.md`)**: use one instance's depth as a signal to size the *other* instance up — e.g., scale `MM_SHORT`'s lots when `MM_LONG` is stuck deep, leaning into the account's existing directional delta rather than fighting it.
- **Mechanism 2 (this document)**: give the *stuck* instance itself a way to resume active trading in a new price zone, rather than only ever compensating for its inactivity via the other side.

**These interact directly**: if Mechanism 2 successfully re-engages a stuck stack, the premise behind Mechanism 1 (this side is permanently stuck, therefore lean on the other) stops holding for that stack. Any future scoping of either should account for the other — they should likely be tested together, not evaluated independently and bolted together after the fact.

## 5. Open design questions (unresolved — needs real derivation, not a guessed constant)

1. **What defines "genuinely stuck," precisely?** Candidates, none yet chosen: time since last fill on that side; distance between current price and the stack's average entry, normalized by some volatility measure; realized volatility compressing back down after a shock (i.e., "the market has settled," not just "moved away"); some combination. This needs the same discipline that `WIDEN_RATIO`'s derivation lacked at first — a real, checkable basis, not a plausible-sounding number.
2. **What does "resume trading" mean mechanically, once triggered?** Two very different options with different risk profiles:
   - The stale stack stays open exactly as-is, while a *fresh*, independent stack starts at the current price — effectively two concurrent grids on the same side.
   - The existing stack's anchor points get re-based somehow, without opening a second parallel structure.

## 6. Next steps (not started)

- [ ] Revisit once current priorities (Truss Crisis dual-topology sizing fix, 4f gap test) are resolved.
- [ ] Decide the concrete trigger definition (Question 1) — likely needs some empirical grounding (e.g., checking what "time since last fill" or "distance from average entry" distributions actually look like across the historical windows already available), not just picked from intuition.
- [ ] Decide the mechanical resumption design (Question 2) before any implementation.
- [ ] Scope jointly with Mechanism 1 (cross-instance sizing) — likely needs the same `GridState` joint-simulation infrastructure already discussed for that idea, since both require tracking two instances' state together, not independently.
- [ ] Full DeepSeek Phase 1 / Gemini Phase 3 pass before any Cursor implementation — same discipline as everything else in this project, especially given this addresses a real, demonstrated failure mode (not a hypothetical), so the temptation to move fast should be resisted, not indulged.
