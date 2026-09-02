This message has a line count at the bottom.

# DeepSeek Phase 1 Response -- Straddle Deadband Rebuild (ADR-123 candidate)

## Integrity gate
- line 1 check: PASS -- observed "This message has a line count at the bottom."
- line 50 check: PASS -- observed "## The proposed rebuild (ATTACK it)"
- last line check: PASS -- observed "Line count: 106"
- total lines check: PASS -- observed 106

Source baseline verified at c7791af: `ea/fxmatrix_v2_logic.mqh` (deadband),
`ea/fxmatrix_v2_engine.mqh` (Replace helpers, StraddleL0OnTick, handoff),
`ea/fxmatrix_v2_entry_ab.mqh` (straddle geometry), unified shell inputs.

---

## T-1 -- Leg symmetry / warp

**VERDICT:** NO-EXPLOIT

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_logic.mqh` :
`V2_L0RestingWithinDeadband` : per-leg skip is independent; each leg compares
`|new_price - resting_price|` against its own deadband only (lines 521-533).
Targets are recomputed each tick from current mid via
`V2_DumbStraddleBuyPrice` / `V2_DumbStraddleSellPrice` (`entry_ab.mqh:54-66`).

**MINIMAL REPRO / MECHANISM:**
1. Flat straddle; both legs placed at mid=1.25000, width=9 pips -> buy 1.24910,
   sell 1.25090. Default deadband ~0.95 pips (GBPUSD: `InpQuoteSpread=0.0004`,
   `InpL0DeadbandMult=1.0`, `V2_L0RequoteDeadband` -> ~0.000095).
2. Mid creeps +0.5 deadband/tick for 10 ticks: both targets rise equally; each
   leg's delta from resting stays below deadband -> both skip every tick (symmetric).
3. Mid jumps +2 pips in one tick: both deltas exceed deadband -> both
   `Long_ReplacePendingBuy` / `Short_ReplacePendingSell` re-quote once; error resets.
4. Asymmetric skip tick: buy missing (`resting_ticket=0`, deadband false -> place);
   sell within deadband -> sell skips. Instantaneous width error bounded by one
   deadband on the resting leg; on next tick(s) the resting leg re-quotes once
   its delta exceeds deadband. No mechanism accumulates error tick-over-tick beyond
   ~2*deadband instantaneous offset (each leg capped at one deadband from its
   ideal `mid +/- width` target).

**SEVERITY:** cosmetic (bounded geometry slack, not unbounded walk)

---

## T-2 -- Rejection retry interaction

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_engine.mqh` :
`Long_ReplacePendingBuy` : when deadband false, unconditional
`Long_CancelTicket` + `Long_PlaceBuyLimit`; returns false if place fails
(lines 442-454). Proposed rebuild drops `g_*_l0_cooldown_until` and
`V2_StraddleL0CooldownBlocks` (ADR-121/122) while keeping only marketability
skip in `V2_StraddleL0OnTick` (lines 122-127).

**MINIMAL REPRO / MECHANISM:**
1. Flat straddle; sell live @ 1.25090; buy `ticket=0` after failed place.
2. Live feed; buy target marketable (`buy_lvl < ask`) so marketability skip passes.
3. Each tick: buy path calls `Replace` -> `PlaceBuyLimit` -> broker reject
   (margin/invalid/expired session -- not marketability). `ticket_ref` stays 0;
   sell path deadband true -> skip. Good leg not churned.
4. Without cooldown: retry every tick until success -- broker/API spam bounded
   only by tick rate (potentially hundreds/min on fast feed). Current c7791af
   sets cooldown on failed Replace (lines 134-135); proposal explicitly removes it.

**SEVERITY:** fixable-within-design (retain failed-send cooldown alongside deadband;
does not require ref_mid machine)

---

## T-3 -- Deadband sizing vs straddle width

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_logic.mqh` :
`V2_L0RequoteDeadband` (lines 504-511) vs `ea/fxmatrix_v2_entry_ab.mqh` :
`V2_DumbStraddleBuyPrice` width = `InpDumbStraddlePips * point * 10`
(lines 54-58). Defaults: width 9 pips (`unified_gbpusd.mq5:50`), deadband ~0.95 pips
-- healthy ratio. No code enforces `width > deadband`.

**MINIMAL REPRO / MECHANISM:**
1. **Tiny deadband regime:** `InpL0DeadbandMult` -> 0 or `InpQuoteSpread` very small;
   deadband -> ~0.5 point. Any sub-point mid jitter makes
   `|new-resting| >= deadband` every tick -> cancel+place both legs -> churn returns
   (same failure mode as pre-deadband straddle bypass). Confirms G2 root if bypass removed
   without adequate deadband width.
2. **Width << deadband regime:** set `InpDumbStraddlePips=0.5` (~0.5 pip offset),
   `InpL0DeadbandMult=3` (~2.85 pip deadband). Intended straddle span ~1 pip; legs
   skip re-quote while mid drifts up to deadband -> resting pair frozen up to ~2*deadband
   (~5.7 pips) off current mid-anchored targets. Straddle geometry decoupled from mid
   for extended periods without cancel churn.

**SEVERITY:** fixable-within-design (input guard or preset constraint:
`InpDumbStraddlePips` must exceed deadband in pips; document mult/spread regimes)

---

## T-4 -- Removing the ENTRY_SIGNAL gate

**VERDICT:** NO-EXPLOIT

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_engine.mqh` :
`Long_ReplacePendingBuy` gate `InpEntryMode == ENTRY_SIGNAL &&` (lines 443-444);
signal L0 caller `Long_OnNewBar` only when `n==0 && InpEntryMode == ENTRY_SIGNAL`
(lines 558-579). Straddle caller `V2_StraddleL0OnTick` returns unless
`ENTRY_STRADDLE` (lines 96-97). Modes are mutually exclusive at call sites.

**MINIMAL REPRO / MECHANISM:**
1. `InpEntryMode=ENTRY_SIGNAL`, flat, new M5 bar: `Long_OnNewBar` calls
   `Long_ReplacePendingBuy` -> deadband already evaluated (gate + function redundant).
2. Remove `InpEntryMode == ENTRY_SIGNAL &&` from Replace: same call path, same
   deadband predicate -- zero behavior change (stat counter `g_long_stat_l0_deadband_skip`
   unchanged in effect).
3. `InpEntryMode=ENTRY_STRADDLE`: `Long_OnNewBar` L0 block skipped (line 559 false);
   only `V2_StraddleL0OnTick` calls Replace -- deadband newly applied (intended change).
4. `Long_EnsureAddNext` uses direct `Long_PlaceBuyLimit`, not Replace (lines 534-549) --
   no deadband interaction on adds/reloads.

**SEVERITY:** cosmetic (refactor simplifies gate; signal arm path isolated)

---

## T-5 -- flat -> filled grid handoff

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_engine.mqh` : `OnTick` order
`V2_StraddleL0OnTick` before `OnTradeTransaction` deal handling (lines 2087-2103);
flat gate `ArraySize(g_long_layers)==0` (line 102); fill clears ticket in
`Long_HandleDealFill` only after deal event (lines 730-731). Proposed rebuild
removes `V2_StraddleLegShouldAttempt` pre-gate and calls Replace every tick for
each flat side.

**MINIMAL REPRO / MECHANISM:**
1. Flat; buy L0 ticket T1 resting; `g_long_layers==0`.
2. Broker fills T1; position opening.
3. Same-bar `OnTick` runs before `OnTradeTransaction`: straddle still sees
   `long_flat=true`, `g_long_l0_ticket=T1`.
4. `V2_GetPendingOrderPrice(T1)`: pending gone -> -1 -> deadband false ->
   `Long_ReplacePendingBuy` -> `PlaceBuyLimit` places T2 while T1 fill not yet
   processed into `g_long_layers`.
5. Deal handler then appends layer from T1 fill; orphan pending T2 possible until
   BCC/audit catches duplicate entry pending. Current ADR-122 reduces but does not
   eliminate exposure via `LegShouldAttempt`; proposal increases tick-level Replace
   aggression on stale ticket after fill.

**SEVERITY:** fixable-within-design (handoff guard: skip Replace when ticket not
OrderSelect-live but HistoryOrderSelect shows terminal state filled/canceled, or
when broker position for magic exists while layers==0; not specific to deadband math)

---

## T-6 -- Feed recovery

**VERDICT:** NO-EXPLOIT

**LOAD-BEARING CLAIM:** `ea/fxmatrix_v2_engine.mqh` :
`V2_IsFeedStale` early-return suppresses all straddle action (lines 99-100);
`V2_L0RestingWithinDeadband` fires at most one Replace per leg when
`|new-resting| >= deadband` (logic.mqh:521-533). Staleness does not cancel resting
orders (ADR-122 design preserved in G6).

**MINIMAL REPRO / MECHANISM:**
1. Both legs resting; feed frozen 15s -> `V2_IsFeedStale` true -> straddle returns;
   orders untouched at old prices.
2. Feed resumes; mid jumped 5 pips (exceeds ~0.95 pip deadband on both legs).
3. First live tick: stale false; buy and sell each evaluate deadband false once ->
   at most one cancel+place per leg (two re-quotes total), then deadband suppresses
   further updates until next drift threshold.
4. No per-tick loop: unlike `ref_mid<=0` + `V2_DumbShouldRePlace` always-true churn
   (ADR-122 regression), deadband blocks subsequent ticks until next deadband breach.

**SEVERITY:** cosmetic (one-shot reconciliation burst on recovery is intended)

---

## PREMISE VERDICT

The proven per-order deadband pattern ports cleanly to the 2-leg straddle for the
two stated failure modes (churn and missing-leg persistence): G2 bypass removal
directly addresses the mechanical root, and `resting_ticket==0` always attempts
placement (logic.mqh:527-528). The straddle still needs artifacts the signal arm
did not require as first-class concerns: (a) a fill-in-flight / stale-ticket guard
at the flat->layer handoff (T-5), (b) optional failed-send backoff separate from
deadband (T-2), and (c) parameter regime enforcement so straddle width is not
smaller than deadband (T-3). It does NOT need `g_straddle_ref_mid`, goalpost,
`V2_DumbShouldRePlace`, or `V2_StraddleLegShouldAttempt` (G5 confirmed -- ref_mid
only consumed in `V2_StraddleL0OnTick`).

SELF-REVIEW OK

OVERRIDE CHECK: No finding kills the deadband-rebuild premise; T-2, T-3, and T-5
findings are fixable within the proposed design without restoring the ref_mid
state machine.

Line count: 197
