This message has a line count at the bottom

# Argon Delta Review: GBPCHF OPT Addition to Fleet C t2 Reload

- **Branch:** `review/argon-c-t2-gbpchf` (from `origin/main` `9d579a2`)
- **Checker output (`python research/opt_budget/check_c_t2.py`):** `EURUSD OPT t2: OK`, `AUDCAD OPT t2: OK`, `GBPCHF OPT t2: OK`, `C t2 presets: ALL OK`

## 1. `gbpchf_opt_c_t2.set` against `gbpchf_opt_c_t1.set`
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `ea/presets_c/gbpchf_opt_c_t1.set:1` `InpMagic=22261001`
  - `ea/presets_c/gbpchf_opt_c_t2.set:1` `InpMagic=22261001`
  - `ea/presets_c/gbpchf_opt_c_t2.set:3` `InpWidthPips=2.5`
  - `ea/presets_c/gbpchf_opt_c_t2.set:4` `InpAddPips=9.0`
  - `ea/presets_c/gbpchf_opt_c_t2.set:5` `InpExitPips=9.0`
  - `ea/presets_c/gbpchf_opt_c_t1.set:12` `InpMaxLayers=7`
  - `ea/presets_c/gbpchf_opt_c_t2.set:12` `InpMaxLayers=9`
  - `ea/presets_c/gbpchf_opt_c_t2.set:14` `InpStrandedThreshPips=3.5`
  - `ea/presets_c/gbpchf_opt_c_t2.set:15` `InpDeadbandPips=2.0`
  - `ea/presets_c/gbpchf_opt_c_t2.set:17` `InpEnableCommandedEject=true`
  - `ea/presets_c/gbpchf_opt_c_t2.set:18` `InpAutoEject=false`
  - `ea/presets_c/gbpchf_opt_c_t2.set:21` `InpVirtualLattice=true`
  - `ea/presets_c/gbpchf_opt_c_t2.set:22` `InpLatticeReroll=true`
  - `ea/presets_c/gbpchf_opt_c_t2.set:23` `InpRollGateOpposite=0`
  - `ea/presets_c/gbpchf_opt_c_t2.set:24` `InpBreakerEnable=false`
  - `ea/presets_c/gbpchf_opt_c_t2.set:35` `InpTelemetryInstance=GRIND_GBPCHF_OPTC`
  - `ea/presets_c/gbpchf_opt_c_t1.set:37` `InpConfigWarning=FLEET C two-arm t1 GBPCHF OPT -: cap 7, add = exit 9.0, width 2.5, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53071896, wine-c)`
  - `ea/presets_c/gbpchf_opt_c_t2.set:37` `InpConfigWarning=FLEET C two-arm t2 GBPCHF OPT -: cap 9, add = exit 9.0, width 2.5, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53071896, wine-c)`
  - `ea/presets_c/gbpchf_opt_c_t2.set:40` `TelemetryAPIKey=`
  - `scripts/ic_geometry_twoarm_c_t2.json:12` `          "pairs": {"EURUSD": {"OPT": 7}, "AUDCAD": {"OPT": 18}, "GBPCHF": {"OPT": 9}}}`
- **Analysis:** Across all 41 lines, only lines 12 (`InpMaxLayers`) and 37 (`InpConfigWarning`) differ; the other 39 lines are identical.

## 2. `eurusd_opt_c_t2.set` and `audcad_opt_c_t2.set` byte-identical to `HEAD~1`
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `ea/presets_c/eurusd_opt_c_t2.set:12` `InpMaxLayers=9`
  - `ea/presets_c/audcad_opt_c_t2.set:12` `InpMaxLayers=9`
- **Analysis:** `git diff HEAD~1 HEAD -- ea/presets_c/eurusd_opt_c_t2.set ea/presets_c/audcad_opt_c_t2.set` is empty; both files are byte-identical to `b058521`.

## 3. The checker (`research/opt_budget/check_c_t2.py`)
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `research/opt_budget/check_c_t2.py:21` `    "GBPCHF": {"InpMaxLayers": "9", "InpConfigWarning": WARN % ("GBPCHF", 9.0, 2.5)},`
  - `research/opt_budget/check_c_t2.py:34` `    if k1 != [x.partition("=")[0] for x in t2]:`
  - `research/opt_budget/check_c_t2.py:42` `            if v2 != want[k]:`
  - `research/opt_budget/check_c_t2.py:44` `        elif v1 != v2:`
  - `research/opt_budget/check_c_t2.py:45` `            faults.append("%s changed: %s -> %s" % (k, v1, v2))`
  - `research/opt_budget/check_c_t2.py:46` `    if seen != set(want):`
  - `research/opt_budget/check_c_t2.py:53` `    for pair in ("EURUSD", "AUDCAD", "GBPCHF"):`
- **Analysis:** `WANT["GBPCHF"]` checks `InpMaxLayers=9` and `WARN % ("GBPCHF", 9.0, 2.5)`. Any key-list/order mismatch (line 34), any wrong `want` value (line 42), any other key differing from `t1` (lines 44-45), or any missing `want` key (line 46) is caught.

## 4. Runbook edits (`docs/runbooks/twoarm-reload-c-t2.md`)
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:19` `| GBPCHF OPT (22261001) | cap 7 -> 9 | L2.5/9/9 S2.5/9/9 | false/false (exit unchanged) |`
  - `docs/runbooks/twoarm-reload-c-t2.md:43` `- **GBPCHF OPT:** short **7 at cap** (L00-L06, 1.09772 ... 1.10315), none rolled (exit = entry - 9); long 1 (L01`
  - `docs/runbooks/twoarm-reload-c-t2.md:45` `  9: **the next short at 1.10405** (1.10315 + 9). **s5's rollback is closed (7 > 6): flatten only.** Observed, not`
  - `docs/runbooks/twoarm-reload-c-t2.md:59` `| K7 | Guard, by a bound: an entry needs `PositionsTotal() + OrdersTotal()` plus the fleet's non-EXT orders (counted again) `<= limit - (2 + 4 + reserve)`, reserve 8 when not near the market (C's presets `InpSlotNearReserve=8`): 194 near, 186 far on a 200 limit. Per side at most cap + 3 (cap - 1 layers, two exits, the resting add counted twice; at cap: cap + 2), so per instance 2 x (cap + 3): C after t2 = 3 x 24 + 3 x 20 = **132** with every side of all six full at once | `grind_exitq.mqh` 115-182; `grind_config.mqh` 9-10; `fxgrind.mq5` 40 | VERIFIED (bound; plus 1 per close-by in flight) |`
  - `docs/runbooks/twoarm-reload-c-t2.md:65` `  `ls ea/presets_c/*_t2.set | wc -l` = 3. **`f8d65e41f089`, 3** (computed 25 Oct ~21:35Z; before GBPCHF: `7ecd5b582851`, 2). `python research/opt_budget/check_c_t2.py`:`
  - `docs/runbooks/twoarm-reload-c-t2.md:75` `**2.3 Fingerprint and checker** (expected `f8d65e41f089`, then 3, then `C t2 presets: ALL OK`):`
  - `docs/runbooks/twoarm-reload-c-t2.md:80` `expected 3 lines `SAME_EXCEPT_KEY key_len=43`; then `ls -la` of the three `_t1` files (the rollback)).`
  - `docs/runbooks/twoarm-reload-c-t2.md:84` `## 3. RELOAD EURUSD OPT, THEN AUDCAD OPT, THEN GBPCHF OPT (VNC; one chart at a time; EURUSD is the pilot)`
  - `docs/runbooks/twoarm-reload-c-t2.md:91` `   `<pair>_opt_c_t2.set` -> read back BEFORE OK: `InpMagic` (22260201 / 22260401 / 22261001), `InpTelemetryInstance``
  - `docs/runbooks/twoarm-reload-c-t2.md:92` `   (`GRIND_<PAIR>_OPTC`), width, add, exit (s0), the six per-side rows `-1.0`, **cap 9**, stranded (3.0 / 5.5 / 3.5),`
  - `docs/runbooks/twoarm-reload-c-t2.md:99` `4. Trade tab for that symbol: EURUSD and GBPCHF: nothing moves but the short add returning (GBPCHF 1.10405, s0.2).`
  - `docs/runbooks/twoarm-reload-c-t2.md:105` `   changed. No fill is waited for. Then AUDCAD OPT from step 1; then GBPCHF OPT from step 1 (no watch needed between`
  - `docs/runbooks/twoarm-reload-c-t2.md:116` `Remove, then Attach with `<pair>_opt_c_t1.set` (staged 21 Oct). **AUDCAD's and GBPCHF's shorts hold 7 now (s0.2): for`
  - `docs/runbooks/twoarm-reload-c-t2.md:117` `them the rollback is a flatten.** **Roll back only when BOTH sides hold 6 layers or`
- **Analysis:** All edits are verified: s0's `L2.5/9/9 S2.5/9/9` and `rebuild=false/false`; K7's bound `3 x 24 + 3 x 20 = 132 <= 186`; the LF SHA-256 fingerprint `f8d65e41f089` and file count `3`; s2.4's 3 staged lines and 3 `_t1` rollback files; s3's order (EURUSD -> AUDCAD -> GBPCHF), magic `22261001`, stranded `3.5`, and step 4's short add at `1.10315 + 0.00090 = 1.10405`; and s5's flatten-only rollback at depth 7.

## 5. GBPCHF state in s0.2 (short 7 at cap, held from rolling by gate 0) vs EURUSD (K1-K5)
- **Verdict:** **NOT A DEFECT**
- **Quotes:**
  - `ea/grind_pure.mqh:444` `bool Grind_RollGateHolds(const int gate, const int opposite_depth)`
  - `ea/grind_pure.mqh:446` `   return gate >= 0 && opposite_depth > gate;`
  - `ea/grind_engine.mqh:1278` `   if(Grind_RollGateHolds(roll_gate, opposite_depth)) {`
  - `ea/grind_engine.mqh:1279` `      Grind_LatticeRollGateRestartExtreme(is_long);`
  - `ea/grind_engine.mqh:1280` `      Grind_LatticeRollDeferredNote(side, is_long, add_pips, max_layers, roll_gate, opposite_depth);`
  - `ea/grind_engine.mqh:1281` `      return 0;`
  - `ea/grind_engine.mqh:1408` `   if(Grind_SideDepth(g_grind_short) >= max_layers) {`
  - `ea/grind_engine.mqh:2268` `      const int depth_idx = Grind_FindDeepestLayerArrayIndex(side);`
  - `ea/grind_engine.mqh:2271` `      anchor = side.layers[depth_idx].entry_price;`
  - `ea/grind_engine.mqh:2286` `   return Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1);`
  - `ea/grind_engine.mqh:2582` `   Grind_SendNextAddEnt(side, is_long, magic, slot, add_pips, max_layers, lots, false);`
- **Analysis:** With `roll_gate = 0` and long holding `opposite_depth = 1`, `Grind_RollGateHolds(0, 1)` returned `true` (`1 > 0`), so `Grind_LatticeTrySide` only restarted tick-extreme tracking, logged `ROLL_DEFERRED` once, and returned `0` without writing any `GRIND_VL_<ticket>`. After Remove-then-Attach with `InpMaxLayers=9`, `Grind_SideDepth(g_grind_short) = 7 < 9`, so `Grind_LatticeOnTick` does not call `Grind_LatticeTrySide` (line 1408). Because no layer rolled (`!any_vl`), K1-K5 apply identically to EURUSD's unrolled case, with the only operational difference (already reflected in s0.2, s3 step 4, and s5) that GBPCHF short was at cap 7 with `add_pending_ticket == 0` so `Grind_EnsureAddNext` places a new `GRIND|OPT|S|L07|ENT` at `1.10405` (line 2582) rather than adopting an existing resting add, and s5's rollback is already closed (`7 > 6`).

## 6. s0.2's "observed" note (GBPCHF long's resting add `L02` at 1.10081, 15 pips below 1.10231)
- **Verdict:** **NOT A DEFECT**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:46` `  changed by t2: the long's resting add `L02` at 1.10081 is 15 pips below its target (1.10321 - 9 = 1.10231); to`
  - `docs/runbooks/twoarm-reload-c-t2.md:47` `  look at after the reload (a t1 behaviour).`
  - `ea/grind_recon.mqh:1079` `               long_out.add_pending_ticket = tickets[i].ticket;`
  - `ea/fxgrind.mq5:291` `         g_grind_start_add_reprice_long = true;`
  - `ea/grind_engine.mqh:2273` `      anchor = Grind_EffectiveEntry(side.layers[0].entry_price, side.layers[0].position_ticket);`
  - `ea/grind_engine.mqh:2543` `   double add_target = Grind_ComputeAddTarget(side, is_long, add_pips);`
  - `ea/grind_engine.mqh:2552` `      Grind_Adr013ClampBuy(add_target, bid, _Point, stops, clamped);`
  - `ea/grind_engine.mqh:2561` `   const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;`
  - `ea/grind_engine.mqh:2566` `   const double add_deadband = one_shot ? 0.05 : deadband_pips;`
  - `ea/grind_engine.mqh:2570` `      if(Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point))`
  - `ea/grind_engine.mqh:2572` `      Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);`
  - `ea/grind_engine.mqh:3235` `      Grind_EnsureAddNext(g_grind_long, true, magic, slot, add_pips, deadband_pips, max_layers, lots);`
- **Analysis:** At `OnInit`, `Grind_ReconstructState` adopts `L02` into `long_out.add_pending_ticket` (line 1079) and `OnInit` sets `g_grind_start_add_reprice_long = true` (line 291). On every non-stale tick (`Grind_OnTickEngine` line 3235), `Grind_EnsureAddNext` computes `clamped` from `Grind_ComputeAddTarget(side, true, 9.0)` and `Grind_Adr013ClampBuy` (lines 2543, 2552) and modifies `add_pending_ticket` whenever `|clamped - resting| >= add_deadband` (`2.0` pips normally, `0.05` pips on the first tick after `OnInit`, lines 2561-2572). Because `15` pips (`|1.10231 - 1.10081|`) already exceeds `2.0` pips on the running t1 EA:
  1. **If `clamped` is `1.10081`** (because `L01` carries a persistent terminal GlobalVariable `GRIND_VL_<ticket> = 1.10171` read by `Grind_EffectiveEntry` at line 2273, giving `1.10171 - 9 pips = 1.10081`), **the reload LEAVES `L02` at `1.10081`** because `GRIND_VL_<ticket>` persists across Remove/Attach and `InpAddPips=9.0` is unchanged.
  2. **If `clamped` is `1.10231`** (and `L02` was clamped to `1.10081` during an open-gap bid spike before the next non-stale tick ran), **`Grind_EnsureAddNext` MOVES `L02` to `1.10231`** via `Grind_ModifyPendingPrice` (line 2572). Neither case harms the chart.

**GO**

Line count: 108
