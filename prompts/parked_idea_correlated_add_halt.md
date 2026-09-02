# PARKED IDEA: Correlated-Pair Add-Halt (Greater-Depth Side)

**Status: PARKED — not scheduled, not scoped, no implementation started.** Requires the still-nonexistent joint 3-pair simulator (ADR-091 Item 8) before it could be tested at all. Explicitly a V2.1-or-later concept, not part of V2's initial single-pair scope.

**Author:** Khalid (concept), written up by Claude.
**Date:** 2026-07-14

---

## 1. The problem this addresses

When two correlated pairs (e.g., GBPUSD and EURUSD, both effectively short-USD bets) are adding in the same effective direction at the same time, the *real* risk of that add is doubled relative to a single uncorrelated pair's add — but lot size is fixed at 0.01 and cannot be reduced further to compensate. Two levers remain: widen the spacing required for future adds, or halt adds on one side entirely when the correlated condition is detected.

**This is explicitly not a revival of LDAK's existing, live mechanism.** LDAK today is a continuous lot-size throttle (`w = 1/(1+S_eff²)`) — this proposal is a different, new mechanism: a binary halt on new adds, gated on cross-pair correlation plus same-direction depth, applied to whichever side already carries more depth.

## 2. Why halt, not widen (resolved, with reasoning)

Widening the *spacing* only changes the threshold for the *next* future add — it does nothing about the specific add that's about to happen right now, which is the one actually carrying the doubled correlated risk. By the time wider spacing takes effect, the correlated-risk layer has already been taken; only the terms for subsequent layers changed. **Halting the add entirely prevents that specific doubled-risk layer from being taken in the first place** — it intervenes at the moment the risk appears, not one step removed from it.

This is also more consistent with the project's broader design philosophy: every mechanism kept in V2 (`WIDEN_RATIO`, exit/add spacing, `reload_flat`) works by adjusting distance, because lot size is fixed. Adding a *second* distance-based lever specifically for correlation would add complexity to the part of the system already carrying the most engineering weight. A binary halt is a simpler, more legible gate — closer to a threshold check than a new continuous formula — consistent with the "boring is better" principle this whole project has converged on.

## 3. Which side to halt (resolved: the side with greater depth)

When a correlated, same-direction add condition is detected, **halt further adds on whichever side (of the two correlated pairs/instances) already has the greater layer count** — not the shallower or newer one. Rationale: stop compounding further into the position that's already more extended and exposed, rather than penalizing the side that's earlier in its own cycle and has less already committed.

## 4. Open design questions — none yet resolved

1. **Correlation/direction detection mechanism.** Almost certainly reuses LDAK's existing `g_corr`/`g_vratio` computation (Pearson correlation + volatility-ratio stress score, already live and confirmed in `MathEngine.mqh`) — but redirected to gate an add decision rather than scale a lot size. Needs explicit design, not assumed to be a drop-in reuse.
2. **"Greater layers" — precise definition.** Raw layer count? Something normalized by each pair's own typical depth range? Not yet decided.
3. **What "halt" means precisely.** Block all further adds on that side until the correlated condition clears (decorrelates, or the other side's depth catches up)? Block only the single next add, then re-evaluate? Not yet decided.
4. **Scope of "correlated pairs."** Is this GBPUSD-vs-EURUSD specific, or does it need to reason symmetrically across the full EURUSD/GBPUSD/EURGBP triad? The existing LDAK mechanism is already triad-aware (Section 7 of ADR-091) — this proposal should likely reuse that same scope rather than being pair-specific, but needs explicit confirmation.

## 5. Prerequisites before this can be scoped further, let alone built

- **The joint 3-pair simulator** (ADR-091 Item 8, still not built) — this proposal is inherently cross-pair and cannot be tested in the current single-pair Python engine or the current single-pair V2 EA at all.
- **A full DeepSeek Phase 1 pass and Gemini Phase 3 ruling**, same discipline as every other addition in this project — this changes live trading behavior based on cross-pair state, a materially larger step than anything in V2's initial single-pair scope.
- Should likely be developed and evaluated **alongside** the other two parked mechanisms (cross-instance sizing, stale-stack re-engagement), since all three touch related questions about how depth/state in one part of the system should inform behavior elsewhere — evaluating them in isolation risks missing interactions between them, the same concern already flagged for the first two.

## 6. Next steps (not started)

- [ ] Revisit once V2.1/LDAK integration work begins (per Gemini's ruling, this is deferred until the 3-pair simulator exists).
- [ ] Resolve the four open questions in Section 4 with real design work, not assumption.
- [ ] Scope jointly with the other two parked mechanisms (cross-instance sizing, stale-stack re-engagement) rather than in isolation.
- [ ] Full DeepSeek Phase 1 / Gemini Phase 3 pass before any Cursor implementation.
