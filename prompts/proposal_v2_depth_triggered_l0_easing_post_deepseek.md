# PROPOSAL v2: Depth-Triggered L0 Spread Easing — Revised Post-DeepSeek Phase 1 Audit

**Status: Revised per DeepSeek Phase 1 red-team findings. Ready for Gemini structural sign-off (Phase 3) before Cursor implementation (Phase 4).**

**Supersedes:** the v1 proposal sent to DeepSeek, which contained one factual error (corrected below) and one under-specified component (the passivity floor) now fully addressed.

---

## 1. Correction to v1 — the passivity floor does not currently exist anywhere in the codebase

v1 described the live-broker-spread floor as "unconditional and untouched," implying it already existed as a protection this proposal builds on top of. **That was wrong.** Checked directly against source: production's `dynamic_hs = quote_spread + sigma * SpreadMultiplier` has never included any such floor. The floor was a *requirement Gemini attached to the original, much larger V2.1 concept* (full replacement of the volatility term with a fixed per-pair baseline) — a mechanism that was never built. The requirement existed on paper; the code does not.

**Revised position: the floor is now a mandatory, integral part of this specific proposal, not a pre-existing protection.** DeepSeek's Phase 1 audit correctly caught this gap (their finding 2i/2e, "floor mechanism changes base behavior unconditionally" / "floor expression ambiguous") and recommended either fully specifying it or splitting it into a separate change. Given that this easing mechanism is specifically what makes the floor's absence acute — pushing the light side's quote toward bare `quote_spread` with zero volatility buffer, precisely during the depth-accumulation conditions that plausibly correlate with real stress — the floor ships **as part of this change**, not deferred.

**Floor specification, now concrete:**

```
live_spread_price = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point
dynamic_hs = max(quote_spread + sigma * effective_multiplier, live_spread_price + InpPassivityBuffer)
```

New input: `InpPassivityBuffer` (price units via pips, e.g. starting value 0.5 pip — **explicitly marked provisional**, needs empirical calibration same as the depth thresholds, not a final number).

## 2. Correction to v1 — the SpreadMultiplier precedent was miscited

v1's DeepSeek review (finding 3c) stated `SpreadMultiplier=0.0` "was tested and found to cause worse P&L due to overtightening in all conditions, including calm ones." **This is incorrect**, and the error originated in an incomplete prompt on my (Claude's) side — DeepSeek was never given the actual SM=0 sweep results, only the older, unrelated SM=0.125 finding.

**Corrected record** (full write-up: `finding_spreadmultiplier_zero_realtick_sweep.md`): a real-tick sweep of `SpreadMultiplier=0` across four windows found a genuine **2–2 split** — SM=0 outperformed on the two sustained-trend/stress windows (Truss Crisis, June Blowup), SM=0.5 outperformed on the two calm/chop windows (Vaccine Rally, Q1 2024 Chop). This is not a uniform failure — it's direct, empirical evidence of exactly the regime-dependence this proposal is built to exploit. It strengthens, rather than undermines, the case for a *conditional* rather than *global* multiplier change.

## 3. Mechanism (unchanged from v1, reproduced for completeness)

Applies only inside the flat-state (`n == 0`) branch. No change to Add/Reload/exit geometry.

```
if opposite_depth < InpEaseDepthStart:
    effective_multiplier = InpSpreadMultiplier
elif opposite_depth >= InpEaseDepthFull:
    effective_multiplier = InpSpreadMultiplierEased
else:
    frac = (opposite_depth - InpEaseDepthStart) / (InpEaseDepthFull - InpEaseDepthStart)
    effective_multiplier = InpSpreadMultiplier - frac * (InpSpreadMultiplier - InpSpreadMultiplierEased)

live_spread_price = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point
dynamic_hs = max(quote_spread + sigma * effective_multiplier, live_spread_price + InpPassivityBuffer)
```

**Guard, per DeepSeek 2c:** `OnInit` must reject/clamp configuration where `InpEaseDepthFull <= InpEaseDepthStart`.

## 4. Thresholds — explicitly marked provisional, per DeepSeek finding 1a

`InpEaseDepthStart=3`, `InpEaseDepthFull=6` are **discovery-sample values, not validated ones.** They were informed by, not independently confirmed against, the same 19-episode sample that motivated the proposal in the first place. DeepSeek is correct that this is calibration-to-discovery-sample, not confirmation. **These values must be re-examined against out-of-sample distribution data (ideally per-pair) before being treated as final** — this is now an explicit Phase 2 requirement, not a footnote.

## 5. Phase 2 verification requirements (folded in from DeepSeek's audit, mandatory before acceptance)

1. **Out-of-sample threshold validation**, per pair (GBPUSD, EURUSD, EURGBP) — do not assume layer-count significance is pair-agnostic just because lot size is fixed.
2. **Fill-quality / adverse-drift test for eased quotes specifically**, same methodology as the original SpreadMultiplier=0.125 real-tick investigation — confirm the conditional easing does not inherit the marginal-fill-contamination failure mode that value showed, even though the trigger condition differs.
3. **Tail-risk measurement for the "double-deep" scenario** — light side eases in, trend reverses, both sides now carry real depth. Must be explicitly measured (DD3/DD4-style, per the project's existing stress-testing convention), not assumed away by the mechanism's alpha-capture framing.
4. **Passivity buffer value itself needs empirical grounding** — not just structurally present, but calibrated against real historical spread distributions per pair, same discipline as every other threshold this project has set.

## 6. Non-goals (unchanged)

No change to Add/Reload/exit geometry. No ratio/log-ratio/lot-difference metric — direct layer count only. No claim of proven trading-outcome improvement yet — this proposal fixes a demonstrated formula gap and specifies a previously-unspecified safety floor; outcome verification is Phase 2, not this document.

## 7. DeepSeek Override Rule outcome

**No fatal flaw found.** Per DeepSeek's Phase 1 report: "The premise — sigma's blind spot to slow accumulations beyond 4 hours is real, and opposite side depth provides complementary information — is solid... Abort not required. Proceed to Phase 2 with mandatory conditions" (reproduced in Section 5 above). Cleared to proceed to Gemini structural sign-off.
