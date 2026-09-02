# DeepSeek Phase 1 Re-Audit — Depth-Triggered L0 Spread Easing, v2

**Role reminder: Red Team Prime. This is a re-audit of a revised proposal following your own Phase 1 findings on v1 — treat this adversarially, not as a formality. No implementation code.**

---

## What changed since your v1 audit, and why you're seeing this again

Your v1 report was correct on two points that materially changed the proposal:

1. **You flagged (finding 2i/2e) that the "passivity floor" was described as pre-existing but was never specified — buffer value, spread-retrieval mechanism, or whether it changes base behavior for non-eased quotes.** You were right: no such floor exists anywhere in production code today. It was a stated requirement attached to a different, never-built concept, not something this proposal was building on top of. It is now specified concretely (Section 1 below) as a mandatory, integral part of this change — not deferred, not optional.

2. **You were given a factually incorrect precedent (finding 3c): that `SpreadMultiplier=0.0` "was tested and found to cause worse P&L due to overtightening in all conditions, including calm ones."** This was wrong — an error in what you were given, not your reasoning. The actual real-tick sweep (attached: `finding_spreadmultiplier_zero_realtick_sweep.md`) found a genuine 2–2 split across four windows: SM=0 outperformed on sustained-trend/stress windows, SM=0.5 outperformed on calm/chop windows. Re-evaluate your finding 3c's concern about the eased multiplier "inheriting the overtightening failure mode" in light of the corrected record — does this change your risk assessment, or does the concern still stand for a different reason?

## The revised floor specification — audit this directly

```
live_spread_price = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point
dynamic_hs = max(quote_spread + sigma * effective_multiplier, live_spread_price + InpPassivityBuffer)
```

New input `InpPassivityBuffer`, provisional starting value 0.5 pip, explicitly marked as needing empirical calibration (same discipline as the depth thresholds).

**Specifically hunt for:**

1. **`SYMBOL_SPREAD` reliability** — is reading live broker spread via `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` robust, or are there known failure modes (stale value during a feed gap, zero/garbage value at certain broker states, etc.) that could make the floor silently ineffective exactly when it matters most (a genuine liquidity void)?
2. **Does this floor, as now specified, actually change base behavior for non-eased flat-state quotes** (i.e. when `opposite_depth < InpEaseDepthStart`, `effective_multiplier` is unchanged, but the floor still applies)? If so, is that acceptable, or does it require separate validation against current production behavior before being bundled into this change?
3. **Interaction between the floor and the easing at `effective_multiplier` values approaching 0`** — confirm the floor's own logic doesn't collapse to something degenerate (e.g. always-binding, making the easing mechanism cosmetic) or never-binding (making the floor cosmetic) under realistic spread/sigma value ranges. Use real historical spread data if useful, don't just reason abstractly.
4. **Is 0.5 pip a reasonable provisional buffer, or does it need bracketing** (e.g., is there an obvious reason it should be larger for EURGBP vs GBPUSD given typical spread differences)?

## Your original Phase 2 conditions — confirm these are adequately captured, not diluted

Your v1 report required: out-of-sample threshold validation per pair, fill-quality/adverse-drift testing (same methodology as the original SpreadMultiplier=0.125 investigation), explicit double-deep tail-risk measurement, and an `OnInit` misconfiguration guard for `InpEaseDepthFull <= InpEaseDepthStart`. Confirm these are still the right list given the floor is now fully specified, or add/remove anything warranted by the changes above.

## What NOT to do in this phase

Do not propose implementation code. Do not soften prior findings to be agreeable just because corrections were made elsewhere — if the floor specification itself introduces new problems, say so plainly, same standard as your v1 report.
