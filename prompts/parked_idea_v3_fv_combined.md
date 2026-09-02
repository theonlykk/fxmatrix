# PARKED IDEA: V3 — Restore V1's Full FV_combined Signal on the V2 Foundation

**Status: PARKED — deliberately deferred. Not scheduled. V2 (native-only signal) continues as the active, sole priority.**

**Author:** Claude, written up from a live discussion with Khalid.
**Date:** 2026-07-19

---

## 1. The discovery that motivated this

While explaining why GBPUSD's signal is validated as self-sufficient (no EURUSD/EURGBP data needed), Claude repeatedly asserted this was true of V1's actual live signal. Khalid correctly pushed back, recalling that V1 genuinely required all three pairs' quotes to compute GBPUSD's tradeable price. Direct verification against V1 source confirmed **Khalid was right and Claude's claim was incomplete, not just imprecisely worded.**

V1's actual fair-value anchor (`FV_combined`) is a **confidence-weighted blend** of two independent estimates:
- `fv_native` — GBPUSD's own weighted 6/12/48-bar close average (the piece Claude had been describing as the whole story)
- `FV_synthetic_BC` — a triangulated estimate derived from EURUSD and EURGBP (`FV_native_AC / FV_native_AB`)

The blend weight (`w_bc`) is itself computed live, from how well the native and synthetic estimates have historically agreed with each other.

**V2 (the current live system, including the three-pair EUR/GBP deployment) only ever implemented `fv_native`.** This was never a deliberate simplification decision — the Python model V2 was built to faithfully port (`grid_sim_v7_real_signal.py`) was constructed specifically to test grid *geometry*, using the simple native calculation, because that's all that specific validation question needed. The omission of the blended signal was inherited silently, the same way the original EURGBP/EURUSD scope gap was — not weighed, not decided, just never in scope for what was being tested at the time.

## 2. Framing — explicitly agreed with Khalid, worth preserving verbatim in spirit

V2's native-only signal is a genuine accident, not a deliberate design choice — nobody set out to build a system that ignores V1's cross-pair confirmation mechanism. It has earned its place through real, validated results (ADR-091's five windows, a live week of real trading), not through being the intended design. **This means V3 (restoring the full blended signal) could produce better results, worse results, or results indistinguishable from V2 — genuinely unknown, not something to assume either way.** The right posture is neither "V2 is clearly incomplete and V3 must be better" nor "V2 works, therefore the blend must be unnecessary" — both are unproven.

## 3. Proposed scope, as discussed and confirmed correct

**V3 = a specific, named combination**, not a new engine built from scratch:

**Restore from V1** (the one genuinely missing piece):
- The full `FV_combined` blended signal (native + synthetic triangulation, confidence-weighted `w_bc`)

**Correctly excluded from V1, already validated this reasoning holds** (no change from V2):
- Kinetic distance-based spacing
- LDAK (continuous correlation-throttle mechanism)
- Multi-timeframe signal blending, `0.03`-lot sizing
- ADR-090 compression, ADR-078 exit-reset delay, Option B tick-driven adds

**Already built/restored in V2, carries forward unchanged:**
- Corrected grid geometry (`WIDEN_RATIO=1.304`, `ADD_PIPS_CEILING=1000`)
- Resting-limit + CloseBy exit mechanism (this is actually a *restoration* of V1's original design, not new)
- `reload_flat` reload-anchoring logic
- The GBP-exposure hard cap (a genuinely new mechanism, replacing LDAK's role with a different, simpler design — not itself part of the V1-vs-V2 question)
- Orphan-position guard, scalp telemetry (operational hardening, orthogonal to the signal question)

**Net effect: if this framing holds, V3's actual engineering gap is narrow** — restoring one specific signal component — not a broad rebuild. Most of what might have seemed like "V3 work" is either already done in V2 or already correctly excluded.

## 4. What adding FV_combined would actually change, and why it's not a small decision

Restoring the blend means GBPUSD (and EURUSD) would **no longer be mathematically self-sufficient** the way this entire project's validation has assumed since ADR-091. Every piece of evidence gathered so far — the five-window Monte Carlo validation, the Truss Crisis stress test, the live week of three-pair trading — was generated on native-only signals. Adding the blend isn't a small parameter tweak layered on top of validated work; it changes the actual tradeable price computation, meaning **GBPUSD's own signal would need re-validation, not just EURGBP's or EURUSD's.**

## 4a. Second, independent motivating observation (2026-07-21)

Separately from the mathematical-purity question in Section 1, Khalid observed that V2's live trade count is meaningfully lower than V1's historically was, and initially suspected this was due to a wider effective quote spread in V2 (recalling V1 used a tighter ~4bps spread vs. a possible ~8bps in V2).

**This was checked directly and ruled out as a factor.** V1 and V2 use the **identical** dynamic spread formula, identical constants, and identical volatility-scaling term (`dynamic_hs = QuoteSpread(0.0004) + sigma_fv × SpreadMultiplier(0.5)`) — confirmed via direct source comparison (`MathEngine.mqh` vs `fxmatrix_v2.mq5`) and matching real historical GBPUSD volatility data (both land at ~8.05 pip mean half-spread, ~16.1 pip full width). Khalid's "4 vs 8 bps" recollection was accurate but referred to two different measurements of the *same* formula (the base constant alone vs. the total effective spread once the volatility term is added) — not a real V1-vs-V2 discrepancy. No spread-related fix is needed or was made.

**However, the diagnostic explicitly flagged the signal path (native-only vs. `FV_combined` blend — the exact gap already described in this document) as one of the remaining, uneliminated candidate explanations for the lower trade count** — alongside the already-characterized Python-sim-vs-real-tick fill gap, and structural/architectural differences (six dual-instance EAs vs. V1's tri-pod layout). Spread is ruled out; signal path is not.

**This is a second, independent line of evidence pointing at the same open question** (Section 1) — one arrived at from a mathematical-purity angle (does GBPUSD's signal need the blend to be "correct"), the other from an empirical, trade-volume angle (does the blend produce a meaningfully different, possibly more active, signal). Worth answering both simultaneously when this is eventually investigated, not as two separate questions.

## 5. Proposed first step, cheap and non-committal — not yet started

Before any EA changes: directly measure the divergence between `fv_native` and `FV_combined` across the same five historical windows already used throughout this project (same residual-comparison methodology already proven for the AB-slot/EURGBP question). This answers, cheaply, whether the blend is likely to matter at all before committing real engineering time:
- If the two signals are nearly identical in practice (e.g., the confidence weight usually favors `fv_native` heavily anyway) — V3 may be a small, low-risk refinement, or not worth pursuing at all.
- If they diverge meaningfully, especially during stress windows — that's a real, structural finding worth taking seriously, and would explain a genuine difference between what V1 and V2 actually trade on.

## 6. Explicit decision: parked, not scheduled

**Khalid's stated reasoning, preserved directly:** does not want to interrupt or split focus from the current V2 effort (the three-pair EUR/GBP live deployment, the parameterization work). Wants V2 to be as solid and well-understood as possible first, so that if/when V3 work begins, it has a proven foundation and the maximum accumulated lessons learned behind it — consistent with how every other major addition this project has made has been sequenced (validate thoroughly, then build the next layer on top, not in parallel with an unproven one).

## 7. Next steps (not started)

- [ ] Continue V2 (three-pair EUR/GBP, native-only signal) as the sole active priority — this week's live run, the parameterization cutover, and any additional pairs (CADUSD, etc.) all proceed on the native-only architecture, unaffected by this.
- [ ] Whenever compute/attention is genuinely free (not before): run the cheap `fv_native` vs. `FV_combined` divergence check (Section 5) as a pure analysis task — no EA changes, no live risk.
- [ ] Only if that shows a meaningful divergence: scope a full V3 signal-path build, subject to the same full validation gauntlet (sweep, n=500 Monte Carlo, gap-slippage, live-tick verification) every other change in this project has gone through, before it goes anywhere near a live account.
- [ ] Full DeepSeek Phase 1 / Gemini Phase 3 pass before any V3 implementation, given it would change the core tradeable-price computation for GBPUSD and EURUSD, not just add a new pair.
