# PROPOSAL v3: Depth-Triggered L0 Spread Easing — Final, Post Both DeepSeek Audits

**Status: Ready for Gemini structural sign-off (Phase 3).**
**Supersedes:** v1 (initial draft) and v2 (post-first-DeepSeek-audit revision). This version resolves the two open design questions DeepSeek's second audit surfaced.

---

## 1. Mechanism — finalized

Applies only inside the flat-state (`n == 0`) branch. No change to Add/Reload/exit geometry at any depth.

```
if opposite_depth <= InpEaseDepthStart:          // e.g. 2
    effective_multiplier = InpSpreadMultiplier    // unchanged, current production value (0.5)
elif opposite_depth >= InpEaseDepthFull:          // e.g. 5
    effective_multiplier = InpSpreadMultiplierEased  // e.g. 0.0
else:
    frac = (opposite_depth - InpEaseDepthStart) / (InpEaseDepthFull - InpEaseDepthStart)
    effective_multiplier = InpSpreadMultiplier - frac * (InpSpreadMultiplier - InpSpreadMultiplierEased)

live_spread_price = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point
dynamic_hs = max(quote_spread + sigma * effective_multiplier, live_spread_price + InpPassivityBuffer)
```

`sigma` continues to be read live, every bar, exactly as it always has — **only the multiplier ramps, not the final spread value directly.** This is a deliberate, empirically-justified design choice (Section 2).

## 2. Design decision — multiplier-ramp, not fixed-value-ramp (resolved, with evidence)

Two candidate designs were considered:

- **(A) Ramp the multiplier** (adopted): sigma keeps being read live throughout; only its weighting in the formula shrinks as depth increases from `InpEaseDepthStart` to `InpEaseDepthFull`.
- **(B) Ramp a fixed target spread value** (e.g., hard-anchor the ramp's start to a constant like "8 pips" regardless of live sigma at that moment): rejected.

**Why (B) was rejected, with direct evidence:** checked sigma's actual value at the exact moment each of the 19 previously-identified real historical depth-accumulation episodes crossed into the proposed ramp zone (opposite side reaching depth 3, just past the `InpEaseDepthStart=2` boundary). Result: **in only 8 of 19 cases (42%) was sigma high enough that the live formula's own baseline value already matched or exceeded a fixed 8-pip anchor.** In the remaining 11 (58%), the live baseline sat below 8 pips (range: 4.75–7.61 pips). Under design (B), every one of those 11 cases would have produced a real, upward spread discontinuity — the quote getting *wider*, not easier, at the exact moment depth crosses the threshold, working directly against the mechanism's purpose.

**Design (A) has no such failure mode by construction** — since only the multiplier ramps and sigma continues to be read live and continuously, `dynamic_hs` transitions smoothly regardless of what value sigma happens to hold at any given depth. At `InpEaseDepthFull`, the multiplier reaches zero and `dynamic_hs` collapses to `quote_spread` (or the floor, whichever is higher) — a clean, well-defined, discontinuity-free endpoint.

## 3. Floor — bar-cadence, documented limitation (resolved)

DeepSeek's second audit (Finding F1) correctly identified that the floor, and the L0 quote itself, are only re-evaluated once per M5 bar (`Long_/Short_OnNewBar`) — the same cadence every other mechanism in this EA already operates on (deadband, add/reload, exit management). A spread spike that fully reverts within a single 5-minute window would not be caught.

**Resolution: accept bar-cadence as the honest, documented limit of this floor. Do not pursue a tick-level rebuild as part of this change.**

Reasoning:
- A tick-reactive requoting architecture would be a genuinely new pattern with no precedent anywhere in this codebase — a materially larger, separately-risky undertaking than the mechanism itself, working against reasonable deployment timelines for uncertain additional benefit.
- The one real, already-documented live macro-volatility episode this project has on record (GBPUSD spread reaching ~34 pips during a genuine multi-event confluence) was a sustained, multi-hour event — precisely the class of risk a bar-cadence floor **does** catch, just with up to one bar's delay at onset, not zero protection.
- Shipping with no floor at all (DeepSeek's fallback suggestion) would discard real protection against the one concrete risk already observed, in order to guard against a narrower, not-yet-observed risk (a spike reverting within 5 minutes).

**Explicit documentation requirement for implementation:** code comments and the eventual ADR must state plainly that this floor protects against sustained liquidity voids, not instantaneous single-bar spikes — not framed as complete real-time protection.

## 4. Floor specification, incorporating DeepSeek's remaining findings

- **Buffer:** `InpPassivityBuffer`, expressed in pips, converted via the project's existing pip-to-price helper (not a raw hard-coded price constant) — addresses DeepSeek F3's unit-consistency concern. Provisional starting value 0.5 pip, explicitly marked as needing per-pair empirical calibration against historical spread distributions before being treated as final.
- **Zero/garbage spread guard (DeepSeek F4), fully specified — no hard-coded pair-specific constant, per Gemini's follow-up:** maintain a runtime static `g_last_valid_spread_price` (sentinel: unset). On every read where `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > 0`, update this stored value. If the read returns 0 or an implausible value, do **not** overwrite it — use the stored value instead. **Cold-start fallback (before any valid reading has ever occurred): `InpQuoteSpread`** — an already-existing, already per-instance-configurable input, not a newly-invented literal. This design requires no new per-pair constant at all, since the primary fallback is that pair's own most recently observed real spread, and the last-resort fallback reuses an input that already exists and is already differentiable per pair's own configuration. **Before implementation, confirm (do not assume) whether `InpQuoteSpread` is currently genuinely differentiated across the three production `.set` configurations, or defaults identically to `0.0004` everywhere today** — either is acceptable as a cold-start anchor, but the actual current state should be known, not presumed.
- **`OnInit` guard (DeepSeek F5):** reject configuration and return `INIT_FAILED` if `InpEaseDepthFull <= InpEaseDepthStart`, or if either threshold is negative — explicit failure, not silent clamping.

## 5. Explicitly parked, not bundled into this proposal

**Khalid's separate preference for `InpSpreadMultiplier = 0.25` (vs. current production 0.5) in the *unchanged* (depth ≤ `InpEaseDepthStart`) zone is explicitly excluded from this proposal.** This would change baseline behavior for every flat-state quote, not just the depth-eased scenario, and would directly re-open a question this project already closed with real-tick evidence — the original SpreadMultiplier investigation specifically confirmed 0.5 as the best real-world value, with 0.125 showing decisive, measured degradation on the same pair. Any change to the baseline multiplier value needs its own dedicated real-tick investigation, independent of this depth-easing mechanism, not a change bundled in alongside it.

## 6. Phase 2 verification requirements (consolidated from both DeepSeek audits)

1. Out-of-sample threshold validation, per pair — `InpEaseDepthStart`/`InpEaseDepthFull` are discovery-sample values (from the same 19 episodes that motivated the proposal), not yet independently confirmed.
2. Fill-quality / adverse-drift test for eased quotes specifically, same methodology as the original SpreadMultiplier=0.125 real-tick investigation.
3. Explicit "double-deep" tail-risk measurement (DD3/DD4-style) — light side eases in, trend reverses, both sides carry real depth simultaneously.
4. Isolated floor-alone impact simulation (no easing active) across all validated windows, to quantify any fill-rate/P&L effect on non-eased quotes before accepting the floor as bundled into this change.
5. Explicit test that easing does not fire spuriously on false/noise-driven imbalances in calm/chop windows (the same windows where the global SM=0 sweep underperformed) — confirming the conditional mechanism doesn't inherit that regime's weakness.

## 7. Non-goals (unchanged)

No change to Add/Reload/exit geometry at any depth. No ratio/log-ratio/lot-difference metric — direct layer count only (confirmed safe given fixed `InpLotSize=0.01` across all layers and pairs). No claim of proven trading-outcome improvement yet — Phase 2 verification remains required before any real-tick or live consideration.

## 8. DeepSeek Override Rule status

**No fatal flaw found across either audit.** Both the original mechanism and the floor addition were cleared to proceed with mandatory conditions (Section 6), not aborted.
