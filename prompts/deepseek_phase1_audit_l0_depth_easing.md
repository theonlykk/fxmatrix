# DeepSeek Phase 1 Audit — Depth-Triggered L0 Spread Easing Proposal

**Role reminder: Red Team Prime. Adversarial, statistically rigorous critique only. No implementation code in this phase — if you find yourself writing MQL5 or Python implementation, stop; that is not this phase's job.**

---

## What you're reviewing

A proposed modification to FXMatrix V2's flat-state (L0) spread formula, motivated by a demonstrated structural gap in the *existing, already-live* volatility term — not a new idea layered on for its own sake.

## Background — confirmed facts, not hypothesis

Production's current flat-state spread formula:

```
dynamic_hs = quote_spread + sigma * SpreadMultiplier
```

`sigma` (`V2_FvSigmaFromCloses()`, in `fxmatrix_v2_signal.mqh`) is **not** a rolling volatility measure. Confirmed directly from source: it is the population standard deviation of exactly **three price anchors** — the M5 closes 30 minutes, 1 hour, and 4 hours before the reference bar — around their own mean. It has zero memory of anything that happened more than 4 hours ago.

This was tested directly against real historical data: 19 episodes were identified (across three real-tick windows — Truss Crisis, Q1 2024 Chop, Full Quarter) where one side of the grid (`MM_LONG` or `MM_SHORT`) built substantial layer depth (3+ layers) via a genuine, sustained move. Sigma's actual trajectory was computed at each point through every episode using the real formula on real CSV data.

**Result:** in the two longest episodes (37 days and 21 days of continuous depth accumulation), sigma started elevated (reacting to the initial move) then compressed to 3–8 pips for nearly the entire remaining duration — near or below the window's own typical baseline — despite substantial, real, ongoing depth building the whole time. The formula cannot see a slow, grinding accumulation once it's more than 4 hours old, by construction.

**Implication:** the flat-state L0 quote on the *opposite* (light) side of the book receives no additional caution during exactly the scenario where real, sustained directional risk is accumulating on the other side — because sigma, structurally, cannot detect it past the 4-hour window.

## Proposed mechanism

Applies **only** inside the existing flat-state branch (`n == 0`, i.e. only when this side has zero open layers) — no change to Add, Reload, or exit geometry at any depth.

Before computing `dynamic_hs` for a flat side, read the **opposite side's current layer count** (already tracked in-memory, e.g. `ArraySize(g_short_layers)` from within the long side's own code path — no new state, no Global Variable, no cross-instance dependency).

```
if opposite_depth < InpEaseDepthStart:
    effective_multiplier = InpSpreadMultiplier                    # unchanged, current behavior
elif opposite_depth >= InpEaseDepthFull:
    effective_multiplier = InpSpreadMultiplierEased                # e.g. 0.0
else:
    frac = (opposite_depth - InpEaseDepthStart) / (InpEaseDepthFull - InpEaseDepthStart)
    effective_multiplier = InpSpreadMultiplier - frac * (InpSpreadMultiplier - InpSpreadMultiplierEased)

dynamic_hs = max(quote_spread + sigma * effective_multiplier, live_broker_spread + buffer)
```

Three new inputs proposed: `InpEaseDepthStart` (e.g. 3), `InpEaseDepthFull` (e.g. 6), `InpSpreadMultiplierEased` (e.g. 0.0). Linear interpolation between the two thresholds, not a hard step — deliberately chosen to avoid a discontinuous flicker as depth crosses back and forth near a single boundary during normal trading.

**The live-broker-spread passivity floor is unconditional and untouched** — this was a hard requirement from the original concept review (guards against a resting quote landing inside real market spread during a genuine liquidity void, e.g. an NFP print). No easing level overrides it.

## Explicit non-goals

- Does not touch Add/Reload/exit geometry at any depth.
- Does not use any ratio, log-ratio, or lot-difference metric. Two prior outcome-based tests on those framings (duration-to-resolution and maximum adverse excursion for individual light-side entries; combined-book profit across "heavy episodes") were both run against real historical data this week and came back null or confounded. This proposal deliberately does not rest on either of those results — it rests only on the sigma-blind-spot finding described above, and layer count is the only input.
- Does not yet claim proven improvement in trading outcomes. This is a fix to a demonstrated formula gap; outcome verification (backtest, real-tick check) is the next phase, not this one.

## Explicitly requested: hunt for these categories

1. **Statistical pathologies** — is there any circular-reasoning risk in using the same 19-episode sample that motivated this design as if it were independent confirmation? (It should not be treated as such — flag explicitly if the proposal or any future justification conflates "this fixes a demonstrated gap" with "this improves outcomes," since only the former has been shown.)
2. **Mechanical flaws** — interaction with the existing GBP cross-exposure cap (different mechanism, should be independent — confirm, don't assume); interaction with the existing L0 requote deadband (same code path, `Long_/Short_ReplacePendingBuy/Sell` — confirm no conflict); edge cases in the linear interpolation (e.g. misconfigured `InpEaseDepthFull <= InpEaseDepthStart`).
3. **Retail heuristics** — is `InpEaseDepthFull` a genuinely pair-agnostic constant given fixed lot size across GBPUSD/EURUSD/EURGBP, or does it need pair-specific calibration? Is the linear ramp itself justified, or is that an arbitrary choice needing its own scrutiny?
4. **The override rule applies as always** — if you find a fatal flaw invalidating the premise, state it explicitly and we abort pending architectural pivot, per standing process.

## What NOT to do in this phase

- Do not propose implementation code.
- Do not evaluate whether this "will make money" — that is outside this phase's scope; Gemini and the standard verification pipeline handle that after your teardown.
- Do not soften findings to be agreeable — this phase exists specifically because the proposal has not yet been defended by anyone.
