# Phase 1 Audit Request — Unified V2 Engine Design Specification

## Role reminder
Phase 1 Red Team submission per ARCHITECT.md. Mechanical/architectural
critique only — no implementation code. Gemini's ruling (2026-08-02)
directed abandoning the stale `_ref` branch and building a genuinely
unified, parameterized engine from current production as the sole
reference; the specification below is Cursor's first draft against
that mandate, produced as a Think-phase deliverable (spec only, no
code). This audit is the mandatory gate before any implementation.

## Background
Today's chronology audit found the prior `_ref` architecture was never
a real shared engine — three duplicate ~1,400-line files with only
compile-time macro scaffolding, frozen 10 commits behind production
and missing ADR-097 through ADR-103 entirely. Gemini ruled: abandon
`_ref` (now archived, not deleted), rebuild from current production,
standardize on production's real cap modules, and require the new
dispatch layer to natively encapsulate per-pair easing rather than
bolt it on. Full specification follows verbatim.

## Full specification (Cursor draft, verbatim)

### 0. Problem statement

Production consists of three ~1,600-line `.mq5` files that are structurally identical except for:

- Pair-specific `#define` constants (magic numbers, telemetry labels)
- Signal path (BC native vs AB triad)
- Spread-easing thresholds (ADR-097: 1/3, ADR-098: 1/4, ADR-099: 1/3)
- Cap module wiring (GBP-only, EUR-only, dual)
- EURUSD-only L0 deadband vol-scale

Every ADR since 2026-07-18 was applied three times (or inlined three times). The Phase 1 _ref branch did not solve this — it added macro/dispatch scaffolding but retained three full duplicates and fell 10 commits behind production.

Goal: One shared engine body + thin per-pair entry shells, with easing and cap differences encoded in a typed pair preset, not copy-pasted.

### 1. Target architecture (high level)

Three thin shells (fxmatrix_v2_gbpusd.mq5, _eurusd.mq5, _eurgbp.mq5, ~40-60 lines each) each define a compile-time V2_PAIR_PRESET struct and #include a shared fxmatrix_v2_engine.mqh, which holds the shared Long_/Short_ bodies plus OnInit/OnTick/OnTradeTransaction, using g_preset for all pair-specific behavior. The engine in turn uses logic.mqh, exits.mqh, telemetry.mqh, a NEW unified fxmatrix_v2_l0_signal.mqh (unified L0 dispatch with easing), and cap headers included per preset profile.

Three shells remain because MT5 attaches one EA binary per chart instance — magic numbers, default inputs, and compile-time cap includes differ per pair. Shells are deployment artifacts, not logic duplicates.

Production files during transition: existing fxmatrix_v2.mq5, fxmatrix_v2_eurusd.mq5, fxmatrix_v2_eurgbp.mq5 remain untouched until parity is proven; new shells get distinct names or replace production only after the parity gate.

### 2. Pair preset mechanism

Verdict: preserve the idea, not _ref's pair_config.mqh macro blocks — those don't work for current production because production embeds runtime `input` declarations (Strategy Tester/.set compatibility), encodes behavioral profiles (cap module set, signal slot, deadband flag) that macros express poorly, and ADR-097/098/099 locked different default easing thresholds per pair that must be overridable via input.

Recommended: a new fxmatrix_v2_pair_preset.mqh header defining a V2PairPreset struct (identity: symbol, telemetry instance names, EA name, magic numbers; signal: V2SignalSlot enum [BC_NATIVE/AB_TRIAD], leg symbols; L0 deadband flag and reference spread; easing defaults; V2CapProfile enum [GBP_ONLY/EUR_ONLY/DUAL_GBP_EUR]), with per-pair preset fragment files (fxmatrix_v2_preset_gbpusd.mqh, _eurusd.mqh, _eurgbp.mqh) carrying values copied verbatim from current production.

### 3. Unified L0 signal dispatch with native easing

Hard requirement: easing must be inside the dispatch layer. Production inlines eased half-spread in each file's Long_/Short_ComputeBidSignal — unified dispatch must lift production .mq5 inlined logic, NOT the pre-ADR V2_ComputeBcBid/V2_ComputeAbBidOffer helpers (fixed multiplier, no floor).

New header fxmatrix_v2_l0_signal.mqh defines a V2L0SignalContext struct (quote_spread, spread_multiplier, spread_multiplier_eased, ease_depth_start/full, passivity_buffer_pips, opposite_depth, quoting_side_flat, leg symbols, passivity_buffer_price) and entry points V2_L0ComputeBid(preset, ctx, out bid) / V2_L0ComputeOffer(preset, ctx, out offer).

BC path (GBPUSD, EURUSD): mirrors production inlined logic — native closes to FV/sigma, easing via V2_EffectiveSpreadMultiplier when quoting side flat, V2_L0DynamicHalfSpread with passivity floor, fv * exp(r +/- dynamic_hs).

AB path (EURGBP): mirrors ADR-099 production — dual-leg FV/sigma, MathMax(sig_ac, sig_bc), same easing/floor, ratio * exp(inst_spread +/- dynamic_hs). Leg overrides via InpLegAC/InpLegBC preserved.

Known difficulty (Cursor's own flag): unification risk is highest here — must extract from production .mq5 bodies, not signal.mqh stubs alone.

### 4. Cap module selection

GBPUSD -> V2_CAP_GBP_ONLY -> gbp_cap.mqh. EURUSD -> V2_CAP_EUR_ONLY -> eur_cap.mqh. EURGBP -> V2_CAP_DUAL_GBP_EUR -> gbp_cap + eur_cap + eurgbp_dual_cap. Engine uses Engine_CapBlocksNewAdd()/Engine_CapSyncInstance() switching on g_preset.cap_profile. No cross_exposure_cap.mqh. ADR-103 preserved: orphan-aware cap publish via V2_ShouldPublishCapSyncOnInit, no trigger GV reset. Each shell includes only the cap headers its profile needs.

### 5. Shared engine body

fxmatrix_v2_engine.mqh holds a single copy of: globals, Long_/Short_ bodies, OnInit/OnTick/OnTradeTransaction, rollover reconciliation + retry (ADR-101), halt gate (ADR-102), telemetry, API counter. Pair-specific behavior flows through g_preset plus shell input declarations. Estimated ~1,500 lines engine + ~50 lines x 3 shells, versus ~1,500 x 3 today.

### 6. Equivalence / parity verification plan

Gate: no production replacement until parity on all three pairs.
1. Unit tests extended for V2_L0Compute* (BC + AB, ramp, floor, swap-independence matrix).
2. Side-by-side Strategy Tester, production vs unified shell, Model=4, identical .set, canonical windows (truss_crisis, full_quarter, EURGBP + june_blowup). Match target: exits, P&L, V2_STATS counts, max layers, peak net lots — exact.
3. DIAG diff: l0_ease/l0_lag bar-for-bar on a sample window.
4. Edge cases: orphan halt (ADR-102), cap publish skip (ADR-103), EURGBP dual-cap block logging.
Rollout: new shell names first, parity pass, DeepSeek critique, Gemini, ADR, cutover.

### 7. Production surprises (for DeepSeek)
1. Signal is inlined in production, not helper-called.
2. EURUSD vol-scale deadband is orthogonal to signal dispatch (L0 replace path).
3. EURGBP leg symbol runtime overrides remain.
4. Three .ex5 binaries still required for VPS.
5. logic.mqh/exits.mqh stay production — no _r1 fork.

### 8-9. Out of scope / open questions (Cursor's own)
Out of scope: native sigma, parameter changes, VPS changes, production filename swap before parity.
Open for DeepSeek: context struct sufficiency, shared half-spread helper, cap include strategy, deterministic parity tolerance, include-guard risks.


## Additional questions from Claude, on top of Cursor's own open questions above

1. **Preset-vs-input override resolution order.** The spec says easing
   defaults are "overridable by shell inputs" without defining the
   actual resolution mechanism between a preset's compile-time default
   and a chart's live `input` value. This is exactly the class of
   defect ARCHITECT.md's Silent Error Test exists to catch — an
   incorrect assumption here would compile cleanly, pass existing
   tests, and silently apply the wrong threshold on one specific pair,
   invisible until live. Specify precisely how this resolution works
   and what happens if a shell's input value and the preset default
   disagree.

2. **Does unification survive EURGBP's genuine differences, or just
   relocate the branching?** EURGBP needs a second signal path, a
   third cap module, and its own easing thresholds. Does the shared
   engine body end up containing `if (pair == EURGBP)`-style
   conditionals scattered through it — which would just be duplication
   in a different shape — or does the preset/dispatch design in
   sections 2-4 genuinely eliminate that? Trace through concretely
   using the actual production code, not the spec's own description of
   itself.

3. **Is "exact" match the right parity bar?** Section 6 requires exits,
   P&L, stats counts, max layers, and peak net lots to match
   production exactly. Refactored code computing the same math through
   a different call structure can produce small floating-point
   differences that aren't real behavioral bugs. Should the parity
   gate define an explicit numerical tolerance instead of bit-for-bit
   equality, and if so, what's a defensible tolerance given the
   underlying price/pip precision in this codebase?

4. **ADR-102 and ADR-103 need to be traced, not referenced.** Both
   required genuine subtlety to get right originally — ADR-102's
   per-side halt gating sequencing, ADR-103's cap-publish ordering
   relative to Long_OnInit/Short_OnInit and the orphan scan. Section 5
   lists these as included in the shared engine as bullet points;
   confirm from the actual current production source that the full
   sequencing and per-side logic of both is preserved in the proposed
   engine structure, not just their existence as named features.

No implementation code in your response. Flag anything above that
should block this specification from proceeding further, and any
assumption in it that doesn't hold once checked against real
production source.
