This message has a line count at the bottom

# Argon Review: C165 -- Clamp-Hold on Resting Add Orders (`prompts/cursor_c165_clamp_hold.md`)

- **Target prompt:** `prompts/cursor_c165_clamp_hold.md` at `origin/main` (`89080c5`, EA files identical to `5bb5fdb`)
- **Reviewed against:** `ea/grind_engine.mqh`, `ea/grind_pure.mqh`, `ea/fxgrind_tests_rb.mqh`, `ea/fxgrind_tests.mq5`, `ea/grind_recon.mqh`, `ea/grind_exitq.mqh`, `ea/grind_carry.mqh`, `ea/fxgrind.mq5`, `ea/presets_e/eurgbp_opt_e_t3.set`
- **Overall Verdict:** **GO**

---

## Summary Table

| Item | Topic | Verdict |
|---|---|---|
| Q1 | A1-A4 and A7 against source; other callers of `Grind_ModifyPendingPrice` | `CONFIRMED` |
| Q2 | Held add inside widened spread vs freeze level, I-invariants, recon, ADR-152, `Grind_AddTargetNearMarket` | `NOT A DEFECT` |
| Q3 | Is the add's fill price still at or beyond `T` in every held case? | `CONFIRMED` |
| Q4 | Is a per-order modify rate limit still needed as a backstop, given s2's bound? | `NOT A DEFECT` |
| Q5 | The one-shot after start-up, CE8, and reloads that change `add` (`6 -> 18` and `18 -> 6`) | `CONFIRMED` |
| Q6 | Rolls and the virtual lattice (`Grind_ComputeAddTarget` 2250-2296) | `CONFIRMED` |
| Q7 | Every hand value in s5 and F / G classes | `CONFIRMED` |
| Q8 | Anything else that makes this unsafe for E (FTMO) or the IC fleets | `NOT A DEFECT` |

---

## Detailed Review (Q1-Q8)

### Q1. A1-A4 and A7 against source: is there any other caller of `Grind_ModifyPendingPrice` that can chase spread flicker the same way?

**Verdict:** `CONFIRMED`

**Evidence (A1-A4 in `ea/grind_engine.mqh`, `ea/grind_pure.mqh`, and `ea/presets_e/eurgbp_opt_e_t3.set`):**
- `ea/grind_engine.mqh:2543` `   double add_target = Grind_ComputeAddTarget(side, is_long, add_pips);`
- `ea/grind_engine.mqh:2547` `   const double bid = Grind_MarketBid();`
- `ea/grind_engine.mqh:2548` `   const double ask = Grind_MarketAsk();`
- `ea/grind_engine.mqh:2549` `   const long stops = Grind_MarketStopsLevel();`
- `ea/grind_engine.mqh:2550` `   double clamped = add_target;`
- `ea/grind_engine.mqh:2551` `   if(is_long)`
- `ea/grind_engine.mqh:2552` `      Grind_Adr013ClampBuy(add_target, bid, _Point, stops, clamped);`
- `ea/grind_engine.mqh:2553` `   else`
- `ea/grind_engine.mqh:2554` `      Grind_Adr013ClampSell(add_target, bid, ask, _Point, stops, clamped);`
- `ea/grind_pure.mqh:198` `bool Grind_Adr013ClampBuy(const double theoretical,`
- `ea/grind_pure.mqh:204` `   const double min_dist = MathMax(point, stops_level_points * point);`
- `ea/grind_pure.mqh:205` `   if(theoretical >= bid)`
- `ea/grind_pure.mqh:206` `      out_price = MathMin(theoretical, bid - min_dist);`
- `ea/grind_pure.mqh:207` `   else`
- `ea/grind_pure.mqh:208` `      out_price = theoretical;`
- `ea/grind_pure.mqh:209` `   return (MathAbs(out_price - theoretical) > point * 0.1);`
- `ea/grind_pure.mqh:213` `bool Grind_Adr013ClampSell(const double theoretical,`
- `ea/grind_pure.mqh:220` `   const double min_dist = MathMax(point, stops_level_points * point);`
- `ea/grind_pure.mqh:221` `   if(theoretical <= ask)`
- `ea/grind_pure.mqh:222` `      out_price = MathMax(theoretical, ask + min_dist);`
- `ea/grind_pure.mqh:223` `   else`
- `ea/grind_pure.mqh:224` `      out_price = theoretical;`
- `ea/grind_pure.mqh:225` `   return (MathAbs(out_price - theoretical) > point * 0.1);`
- `ea/grind_pure.mqh:158` `double Grind_DeadbandPrice(const double deadband_pips, const double point)`
- `ea/grind_pure.mqh:160` `   return deadband_pips * point * 10.0;`
- `ea/grind_pure.mqh:164` `bool Grind_PriceWithinDeadband(const double resting_price,`
- `ea/grind_pure.mqh:169` `   const double band = Grind_DeadbandPrice(deadband_pips, point);`
- `ea/grind_pure.mqh:170` `   return (MathAbs(target_price - resting_price) < band);`
- `ea/grind_engine.mqh:2561` `   const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;`
- `ea/grind_engine.mqh:2566` `   const double add_deadband = one_shot ? 0.05 : deadband_pips;`
- `ea/grind_engine.mqh:2568` `   if(side.add_pending_ticket != 0) {`
- `ea/grind_engine.mqh:2569` `      const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);`
- `ea/grind_engine.mqh:2570` `      if(Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point))`
- `ea/grind_engine.mqh:2571` `         return;`
- `ea/grind_engine.mqh:2572` `      Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);`
- `ea/grind_engine.mqh:2573` `      return;`
- `ea/presets_e/eurgbp_opt_e_t3.set:15` `InpDeadbandPips=2.0`

**Evidence (A7 and all callers of `Grind_ModifyPendingPrice` across `ea/`):**
- `ea/grind_engine.mqh:1418` `bool Grind_ModifyPendingPrice(const ulong ticket,`
- `ea/grind_engine.mqh:400` `   if(!Grind_ModifyPendingPrice(exit_order_ticket, target, magic)) {`
- `ea/grind_engine.mqh:613` `      if(!Grind_AutoEjectTargetWorse(is_long, new_target, resting, min_dist))`
- `ea/grind_engine.mqh:1065` `      if(!Grind_ModifyPendingPrice(layer.exit_order_ticket, price, magic)) {`
- `ea/grind_engine.mqh:1505` `bool Grind_EntryHorizonActive()`
- `ea/grind_engine.mqh:1507` `   return (g_grind_engine_entry_horizon_pips > 0.0);`
- `ea/grind_engine.mqh:1890` `            Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);`
- `ea/grind_engine.mqh:1938` `            Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);`
- `ea/grind_engine.mqh:2336` `      Grind_Adr013ClampBuy(add_target, bid, _Point, stops, clamped);`
- `ea/grind_engine.mqh:2338` `      Grind_Adr013ClampSell(add_target, bid, ask, _Point, stops, clamped);`
- `ea/grind_engine.mqh:3045` `   const double dist_pips = Grind_StrandedDistMidPips(resting, current_mid, _Point);`
- `ea/grind_engine.mqh:3046` `   if(!Grind_ShouldRecenter(dist_pips, stranded_thresh_pips))`
- `ea/grind_engine.mqh:3047` `      return;`
- `ea/grind_engine.mqh:3058` `      Grind_Adr013ClampBuy(target, bid, _Point, stops, clamped);`
- `ea/grind_engine.mqh:3060` `      Grind_Adr013ClampSell(target, bid, ask, _Point, stops, clamped);`
- `ea/grind_engine.mqh:3067` `   if(Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))`
- `ea/grind_engine.mqh:3070` `   Grind_ModifyPendingPrice(opposite_side.l0_pending_ticket, clamped, magic);`
- `ea/grind_engine.mqh:3122` `         if(!Grind_ModifyPendingPrice(exit_ticket, price, magic))`
- `ea/grind_carry.mqh:1162` `   if(!Grind_ModifyPendingPrice(exit_order_ticket, new_exit, magic)) {`
- `ea/grind_pure.mqh:245` `   return MathAbs(resting_price - current_mid) / (point * 10.0);`
- `ea/grind_pure.mqh:251` `   return (dist_mid_pips > thresh_pips);`
- `ea/fxgrind.mq5:41` `input double InpEntryHorizonPips   = 0.0;   // D3 kill switch, 0 = off; preset opts in`
- `ea/presets_e/eurgbp_opt_e_t3.set:14` `InpStrandedThreshPips=2.5`
- `ea/presets_e/eurgbp_opt_e_t3.set:18` `InpAutoEject=false`
- `ea/presets_e/eurgbp_opt_e_t3.set:28` `InpEntryHorizonPips=0`

**Analysis:**
1. A1-A4 match the source line-for-line. In `Grind_EnsureAddNext` (`ea/grind_engine.mqh:2543-2573`), `clamped` is recomputed every tick via `Grind_Adr013ClampBuy` / `Grind_Adr013ClampSell`. While `add_target <= ask` (sell) or `add_target >= bid` (buy), `clamped` equals `MathMax(theoretical, ask + min_dist)` or `MathMin(theoretical, bid - min_dist)`, so every spread swing of `>= deadband_pips` (`2.0` pips) modifies the resting add out and the narrowing swing modifies it back.
2. Across the entire codebase there are 8 call sites of `Grind_ModifyPendingPrice`:
   - `ea/grind_engine.mqh:2572` (`Grind_EnsureAddNext`): the C165 site.
   - `ea/grind_engine.mqh:1890` and `1938` (`Grind_ApplyEntryHorizon`): would modify `side.add_pending_ticket` to `clamped` without `Grind_AddClampHold`, **but are dead in production** because `Grind_EntryHorizonActive()` requires `g_grind_engine_entry_horizon_pips > 0.0` (`InpEntryHorizonPips=0` in `ea/fxgrind.mq5:41` and every preset). If `InpEntryHorizonPips > 0` were ever enabled in a future preset, those two sites would also need `Grind_AddClampHold`.
   - `ea/grind_engine.mqh:3070` (`Grind_TryRecenterOppositeL0`): only runs when one side has open layers and the opposite side has depth 0, and is gated by `Grind_ShouldRecenter(dist_pips, stranded_thresh_pips)` (`dist_pips > stranded_thresh_pips`). Because `current_mid = (bid + ask) * 0.5` shifts by only half of a one-sided spread swing, normal 2-3.5 pip spread flickers cannot trip `dist_pips > stranded_thresh_pips` (`2.5` pips on EURGBP OPT, higher on wider pairs). Only an extreme one-sided spread swing where `|resting - current_mid| > stranded_thresh_pips` (e.g., `> 5.0` pips of one-sided ask/bid jump on EURGBP OPT when `resting` starts near `current_mid`) could pass line `3046`.
   - `ea/grind_engine.mqh:400` (`Grind_EjectAcceptLayer`): exit order only; operator one-shot command or `Grind_AutoEjectTrySide` (`InpAutoEject=false` in all presets, plus monotonic `Grind_AutoEjectTargetWorse` guard at line `613`).
   - `ea/grind_engine.mqh:1065` (`Grind_LatticeRollLayer`): exit order only; fires once per discrete lattice level (`Grind_VLSet`) when `depth >= max_layers`.
   - `ea/grind_engine.mqh:3122` (`Grind_RebuildExitsAtStartSide`): startup-only (`OnInit`).
   - `ea/grind_carry.mqh:1162` (`Grind_CarryExitShiftLayer`): once-per-day carry pass (23:50-23:59).

---

### Q2. A held add can sit inside the widened spread (`bid < resting <= ask` for a sell; `bid <= resting < ask` for a buy). Does anything in the EA assume a resting add is at least `min_dist` from the market?

**Verdict:** `NOT A DEFECT`

**Evidence:**
- `ea/grind_engine.mqh:96` `long Grind_MarketFreezeLevel()`
- `ea/grind_engine.mqh:100` `   return (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);`
- `ea/grind_engine.mqh:611` `                                                            Grind_MarketFreezeLevel());`
- `ea/grind_exitq.mqh:266` `   const long freeze = Grind_MarketFreezeLevel();`
- `ea/grind_engine.mqh:2290` `bool Grind_AddTargetNearMarket(const double target,`
- `ea/grind_engine.mqh:2294` `   return (MathAbs(target - mid) <= Grind_PipsToPrice(add_pips, _Point) + GRIND_PRICE_EPS);`
- `ea/grind_engine.mqh:2357` `   const bool near_market = Grind_AddTargetNearMarket(clamped, mid, add_pips);`
- `ea/grind_engine.mqh:2556` `   if(is_long && !Grind_BuyLimitMarketable(clamped, ask))`
- `ea/grind_engine.mqh:2557` `      return;`
- `ea/grind_engine.mqh:2558` `   if(!is_long && !Grind_SellLimitMarketable(clamped, bid))`
- `ea/grind_engine.mqh:2559` `      return;`
- `ea/grind_pure.mqh:186` `bool Grind_BuyLimitMarketable(const double buy_limit, const double ask)`
- `ea/grind_pure.mqh:188` `   return (buy_limit < ask);`
- `ea/grind_pure.mqh:192` `bool Grind_SellLimitMarketable(const double sell_limit, const double bid)`
- `ea/grind_pure.mqh:194` `   return (sell_limit > bid);`
- `ea/grind_recon.mqh:405` `bool Grind_ReconCheckPendingAddCorrupt(const GrindReconTicket &tickets[],`
- `ea/grind_recon.mqh:416` `      if(tickets[i].kind != GRIND_RECON_TICKET_ORDER) {`
- `ea/grind_recon.mqh:1055` `      if(c_role == "ENT" && tickets[i].kind == GRIND_RECON_TICKET_ORDER) {`
- `ea/grind_recon.mqh:1079` `               long_out.add_pending_ticket = tickets[i].ticket;`
- `ea/grind_recon.mqh:1086` `               short_out.add_pending_ticket = tickets[i].ticket;`
- `ea/grind_exitq.mqh:135` `int Grind_SlotRestingEnt()`
- `ea/grind_exitq.mqh:180` `   const long reserve = near_market ? 0 : (long)g_grind_slot_near_reserve;`

**Analysis:**
1. **Freeze level:** `Grind_MarketFreezeLevel()` is only called by exit (`EXT`) paths (`Grind_AutoEjectTrySide`, `Grind_ExitQClampPassive`, `Grind_EjectTargetPrice`, `Grind_CarryExitShiftLayer`, `Grind_CarryEmitSnapshot`). Moreover, while a held add sits inside the widened spread (`resting <= ask` for sell or `resting >= bid` for buy), `clamped >= ask + min_dist > resting` (sell) or `clamped <= bid - min_dist < resting` (buy), so `Grind_AddClampHold` returns `true` and **no modify or delete is sent to the broker** while the order is near the market. When `Grind_AddClampHold` later returns `false` and `Grind_PriceWithinDeadband` allows a modify toward `T`, `clamped` is at least `add_deadband` (`2.0` pips) closer to `T` than `resting`, which means `ask + min_dist <= clamped <= resting - add_deadband` (sell) or `bid - min_dist >= clamped >= resting + add_deadband` (buy) -- i.e., `resting` is already at least `min_dist + add_deadband` away from the market.
2. **Recon and I-invariants (`ea/grind_recon.mqh`):** `Grind_RebuildBookFromTicketsInner` (`1055-1089`) adopts a resting `ENT` order with `c_layer > 0` into `add_pending_ticket` without inspecting `tickets[i].price`. `Grind_ReconCheckPendingAddCorrupt` (I8, `405-425`) checks only that `add_pending_ticket` exists in `tickets[]` with `kind == GRIND_RECON_TICKET_ORDER`. `Grind_ReconCheckInvariants` (I1/I3/I5/I6/I7, `469-631`) checks positions and `EXT` orders only. If a held add fills when the market touches `resting`, `Grind_HandleSideDealFill` records the actual fill `deal_price` as `entry_price` and places the exit from that `entry_price`.
3. **ADR-152 slot guard and `Grind_AddTargetNearMarket`:** `Grind_SlotRestingEnt()` (`ea/grind_exitq.mqh:135-162`) counts resting non-`EXT` orders without inspecting price, and `Grind_AddTargetNearMarket` (`ea/grind_engine.mqh:2290-2295`) is only called at `ea/grind_engine.mqh:2357` inside `Grind_SendNextAddEnt` (first placement when `side.add_pending_ticket == 0`).
4. **Marketability guard (`ea/grind_engine.mqh:2556-2559`):** Tests `clamped` (which is always `<= bid - min_dist < ask` for buy and `>= ask + min_dist > bid` for sell), not `resting`.

---

### Q3. Is the add's fill price still at or beyond `T` in every held case, or is there a case where holding makes the add fill at a worse price than `T`?

**Verdict:** `CONFIRMED`

**Evidence:**
- `prompts/cursor_c165_clamp_hold.md:66` `bool Grind_AddClampHold(const bool is_long,`
- `prompts/cursor_c165_clamp_hold.md:72` `   const double eps = point * 0.1;`
- `prompts/cursor_c165_clamp_hold.md:73` `   if(MathAbs(clamped - theoretical) <= eps)`
- `prompts/cursor_c165_clamp_hold.md:74` `      return false;`
- `prompts/cursor_c165_clamp_hold.md:75` `   if(is_long)`
- `prompts/cursor_c165_clamp_hold.md:76` `      return (resting <= theoretical + eps) && (clamped < resting - eps);`
- `prompts/cursor_c165_clamp_hold.md:77` `   return (resting >= theoretical - eps) && (clamped > resting + eps);`

**Analysis:**
- `Grind_AddClampHold` returns `true` only when `resting <= theoretical + eps` (`is_long == true`, `ORDER_TYPE_BUY_LIMIT`) or `resting >= theoretical - eps` (`is_long == false`, `ORDER_TYPE_SELL_LIMIT`), where `eps = point * 0.1` (`1e-6` on 5-digit symbols, strictly less than half a point so exact on tick-normalized prices).
- Consequently, every held buy limit has `resting <= T` and can only fill at `deal_price <= resting <= T` (at or below `T`, i.e., at or better than `T` for a long). Every held sell limit has `resting >= T` and can only fill at `deal_price >= resting >= T` (at or above `T`, i.e., at or better than `T` for a short).
- Whenever `resting` is worse than `T` (`resting > T + eps` for long or `resting < T - eps` for short), `Grind_AddClampHold` returns `false` and does not hold the order.

---

### Q4. Is a per-order modify rate limit still needed as a backstop, given s2's bound?

**Verdict:** `NOT A DEFECT`

**Evidence:**
- `prompts/cursor_c165_clamp_hold.md:54` `Bound: with the add's index unchanged and the clamp active, the resting price only moves toward T,`
- `prompts/cursor_c165_clamp_hold.md:55` `by at least the deadband each time: at most ceil(|resting - T| / deadband) modifies, and none from`
- `prompts/cursor_c165_clamp_hold.md:86` `   if(side.add_pending_ticket != 0) {`
- `prompts/cursor_c165_clamp_hold.md:87` `      const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);`
- `prompts/cursor_c165_clamp_hold.md:88` `      if(Grind_AddClampHold(is_long, add_target, clamped, resting, _Point))`
- `prompts/cursor_c165_clamp_hold.md:89` `         return;`
- `prompts/cursor_c165_clamp_hold.md:90` `      if(Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point))`
- `prompts/cursor_c165_clamp_hold.md:91` `         return;`
- `prompts/cursor_c165_clamp_hold.md:92` `      Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);`
- `prompts/cursor_c165_clamp_hold.md:93` `      return;`

**Analysis:**
- With `required_index` and `T = add_target` fixed, any resting add at or beyond `T` (`resting >= T` for short, `resting <= T` for long) can never move away from `T` when the clamp is active (`Grind_AddClampHold` returns `true`) and can never move past `T` (`clamped >= T` for short by `Grind_Adr013ClampSell`, `clamped <= T` for long by `Grind_Adr013ClampBuy`).
- Even if the clamp deactivates (`clamped == T`) while `|resting - T| < deadband` (so deadband suppresses the final `< 2.0`-pip step) and then the spread widens again (`clamped > resting > T` for short), `resting >= T - eps` still holds, so `Grind_AddClampHold` returns `true` and blocks moving back out.
- Therefore `|resting - T|` is strictly non-increasing and decreases by at least `add_deadband` on every modify, bounding total modifies for a given add index and `T` to at most `ceil(|resting_0 - T| / deadband_pips)` (plus at most 1 if the startup `0.05`-pip one-shot steps toward `T`). A per-order modify rate limit is unnecessary for `Grind_EnsureAddNext`.

---

### Q5. The one-shot after start-up: does CE8 match how `g_grind_start_add_reprice_*` is set and cleared, and is there any reload case where holding on the first tick after a preset change is wrong?

**Verdict:** `CONFIRMED`

**Evidence:**
- `ea/fxgrind.mq5:291` `         g_grind_start_add_reprice_long = true;`
- `ea/fxgrind.mq5:292` `         g_grind_start_add_reprice_short = true;`
- `ea/grind_engine.mqh:2561` `   const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;`
- `ea/grind_engine.mqh:2562` `   if(is_long)`
- `ea/grind_engine.mqh:2563` `      g_grind_start_add_reprice_long = false;`
- `ea/grind_engine.mqh:2564` `   else`
- `ea/grind_engine.mqh:2565` `      g_grind_start_add_reprice_short = false;`
- `ea/grind_engine.mqh:2566` `   const double add_deadband = one_shot ? 0.05 : deadband_pips;`
- `ea/fxgrind_tests_rb.mqh:354` `void Test_RB12_AddOneShot()`
- `ea/fxgrind_tests_rb.mqh:366` `   Grind_MarketTestSeed(1.20000, 1.20010, 0);`
- `ea/fxgrind_tests_rb.mqh:382` `   g_grind_start_add_reprice_short = true;`
- `ea/fxgrind_tests_rb.mqh:385` `   Grind_EnsureAddNext(g_grind_short, false, RB_MAGIC, "OPT", 5.0, 4.0, 8, 0.01);`
- `ea/fxgrind_tests_rb.mqh:387` `   AssertNear("RB12 moved once", Grind_OrderGetPriceOpen(6201UL), 1.20050, 1e-9);`
- `ea/fxgrind_tests_rb.mqh:388` `   AssertTrue("RB12 flag cleared", !g_grind_start_add_reprice_short);`

**Analysis:**
1. **CE8 vs `OnInit` and `Test_RB12_AddOneShot`:** In `ea/fxgrind.mq5:291-292`, `OnInit` sets `g_grind_start_add_reprice_long = true` and `g_grind_start_add_reprice_short = true` after startup recon. In `Grind_EnsureAddNext` (`ea/grind_engine.mqh:2561-2566`), the flag is consumed and cleared *before* the `if(side.add_pending_ticket != 0)` block. CE8 seeds `g_grind_start_add_reprice_short = true` and verifies both that `Grind_AddClampHold` prevents the `0.05`-pip one-shot from pushing `resting = 0.83975` out to `0.83980` and that `!g_grind_start_add_reprice_short` is cleared. Meanwhile, existing `Test_RB12_AddOneShot` (`ea/fxgrind_tests_rb.mqh:354-394`) has `L0 = 1.20000`, `add_pips = 5.0` (`T = 1.20050`), `ask = 1.20010` (`clamped = 1.20050`, clamp inactive), and `resting = 1.20040 < T`, so `Grind_AddClampHold` returns `false` and `RB12` continues to pass unchanged.
2. **Preset reload widening `add` (`6 -> 18`, e.g., AUDCAD OPT 25 Oct):**
   - Short: `T_old = anchor + 6 pips`, `T_new = anchor + 18 pips = T_old + 12 pips`. An order resting at `T_old` (or anywhere `< T_new`) has `resting < T_new - eps`. `Grind_AddClampHold` returns `false` on the first tick after reload (whether or not the clamp is active at `T_new`), and the order is immediately modified out to `clamped >= T_new`.
   - Long: symmetric (`T_new = T_old - 12 pips`, `resting > T_new + eps`, `Grind_AddClampHold` returns `false`).
3. **Preset reload tightening `add` (`18 -> 6`):**
   - Short: `T_old = anchor + 18 pips`, `T_new = anchor + 6 pips = T_old - 12 pips`, so `resting = T_old` is 12 pips beyond `T_new`.
   - If `ask + min_dist < resting` on the first tick after reload, then `clamped = max(T_new, ask + min_dist) < resting`, so `clamped > resting + eps` is `false`, `Grind_AddClampHold` returns `false`, and the `0.05`-pip one-shot immediately pulls `resting` in toward `T_new`.
   - Only if the market at the moment of reload is even further beyond `T_old` (`ask + min_dist > resting = T_old > T_new`) does `Grind_AddClampHold` return `true`, holding the order at `T_old` instead of pushing it even further away from `T_new`. And once the market later recedes toward `T_new`, the 12-pip distance from `T_old` to `T_new` far exceeds the normal `2.0`-pip deadband, so normal ticks pull the order in to `T_new` without needing the `0.05`-pip one-shot.

---

### Q6. Rolls and the virtual lattice (`Grind_ComputeAddTarget` 2250-2296): can `T` move so a held add is now worse than the new `T`? If it does, does C2 move it (CE4's path), and is there any oscillation between the two branches?

**Verdict:** `CONFIRMED`

**Evidence:**
- `ea/grind_engine.mqh:1303` `      if(Grind_SideDepth(side) < max_layers)`
- `ea/grind_engine.mqh:2250` `double Grind_ComputeAddTarget(const GrindSideState &side,`
- `ea/grind_engine.mqh:2268` `      const int depth_idx = Grind_FindDeepestLayerArrayIndex(side);`
- `ea/grind_engine.mqh:2271` `      anchor = side.layers[depth_idx].entry_price;`
- `ea/grind_engine.mqh:2273` `      anchor = Grind_EffectiveEntry(side.layers[0].entry_price, side.layers[0].position_ticket);`
- `ea/grind_engine.mqh:2277` `         if(is_long) {`
- `ea/grind_engine.mqh:2278` `            if(eff < anchor)`
- `ea/grind_engine.mqh:2279` `               anchor = eff;`
- `ea/grind_engine.mqh:2280` `         } else {`
- `ea/grind_engine.mqh:2281` `            if(eff > anchor)`
- `ea/grind_engine.mqh:2282` `               anchor = eff;`
- `ea/grind_engine.mqh:2286` `   return Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1);`
- `ea/grind_engine.mqh:2504` `         const bool label_ok = GrindCommentParse(resting_comment, c_slot, c_side,`
- `ea/grind_engine.mqh:2505` `                                                 parsed_layer, c_role)`
- `ea/grind_engine.mqh:2506` `                               && parsed_layer == required_index;`
- `ea/grind_engine.mqh:2525` `   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers)) {`

**Analysis:**
1. **How `T` can move in `Grind_ComputeAddTarget`:**
   - Under `g_grind_virtual_lattice == true` (`ea/grind_engine.mqh:2272-2285`), `anchor` is `min(eff)` across layers for long and `max(eff)` across layers for short, so `T = Grind_AddTargetPrice(anchor, add_pips, _Point, dir)` moves monotonically outward (higher for short, lower for long) whenever a roll shifts `eff` beyond the current extreme.
   - Note that at a fixed `max_layers`, `Grind_LatticeTrySide` (`ea/grind_engine.mqh:1303`) only rolls when `Grind_SideDepth(side) >= max_layers`, where `Grind_CanPlaceEntryLayer(n, max_layers)` (`ea/grind_engine.mqh:2525`) is `false` and no add order rests. When a layer later exits (`n` drops from `max_layers` to `max_layers - 1`), any pre-existing add order is either absent (`add_pending_ticket == 0`) or has a stale `parsed_layer != required_index` (`ea/grind_engine.mqh:2504-2510`) and is cancelled and replaced. However, `T` *can* move outward past an existing `resting` with `required_index` unchanged if `InpAddPips` is widened on reload or if `InpMaxLayers` is raised on reload while a rolled book has a resting add.
2. **Does C2 move it via CE4's path?**
   - Yes. Whenever `T` moves outward past `resting` (`resting < T_new - eps` for short, `resting > T_new + eps` for long), the first conjunct of `Grind_AddClampHold` (`resting >= theoretical - eps` for short; `resting <= theoretical + eps` for long) evaluates to `false`.
   - C2 then falls through to `Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point)` and `Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic)` (the exact path tested by `CE4`).
3. **Is any oscillation possible between the two branches?**
   - No. By `Grind_Adr013ClampSell` (`ea/grind_pure.mqh:221-224`), `clamped >= T_new` always holds for short (`clamped <= T_new` for long by `Grind_Adr013ClampBuy`, `ea/grind_pure.mqh:205-208`).
   - Thus, a single modify to `resting' = clamped` places the order at `resting' >= T_new` (short) or `resting' <= T_new` (long), i.e., inside the at-or-beyond-`T_new` region. Since every subsequent tick for that `T_new` also produces `clamped >= T_new` (short) or `clamped <= T_new` (long), `resting` can never re-enter the worse-than-`T_new` region while `T_new` is unchanged. One-way transition into the held region; zero oscillation.

---

### Q7. Every hand value in s5: check the arithmetic and the F / G classes.

**Verdict:** `CONFIRMED`

**Evidence:**
- `prompts/cursor_c165_clamp_hold.md:48` `While the clamp is ACTIVE (the clamped price differs from the theoretical target by more than 0.1 point)`
- `prompts/cursor_c165_clamp_hold.md:49` `and the resting add is AT OR BEYOND its target (sell: resting >= target; buy: resting <= target; both`
- `prompts/cursor_c165_clamp_hold.md:50` `within 0.1 point), do not move it FARTHER from the target (sell: to a higher price; buy: to a lower`
- `ea/fxgrind_tests.mq5:31` `#include "fxgrind_tests_adr166.mqh"`
- `ea/fxgrind_tests.mq5:9464` `   Test_RG17_ShortRestartWhileGated();`
- `ea/fxgrind_tests.mq5:9465` `   Print("SUMMARY: ", g_tests_passed, "/", g_tests_run, " passed");`

**Arithmetic and F/G Verification:**

1. **Section 1 trace (`prompts/cursor_c165_clamp_hold.md:36-43`):**
   - `L0 = 0.87324`, `add = 5.0` pips (`0.00050`), `point = 0.00001`, `stops = 0` (`min_dist = 0.00001`), `deadband = 2.0` pips (`0.00020`), `T = 0.87324 + 0.00050 = 0.87374`.
   - Tick 1 (`0.87360 / 0.87374`): `T <= ask` (`0.87374 <= 0.87374`), `clamped = 0.87374 + 0.00001 = 0.87375`. Places `#1` at `0.87375`.
   - Tick 2 (`0.87360 / 0.87409`, 4.9-pip spread): `clamped = 0.87410`. `|0.87410 - 0.87375| = 0.00035 >= 0.00020`. Current EA modifies to `0.87410`; C165 holds at `0.87375` (`resting = 0.87375 >= 0.87374 - 1e-6` and `0.87410 > 0.87375 + 1e-6`).
   - Tick 3 (`0.87360 / 0.87374`, 1.4-pip spread): `clamped = 0.87375`. Current EA modifies `0.87410 -> 0.87375`; C165 is already at `0.87375` (`|0.87375 - 0.87375| = 0 < 0.00020`, no modify).

2. **Pure tests `CH1`-`CH8` (`point = 0.00001`, `eps = 1e-6`):**
   - `CH1`: `is_long=false, T=0.83974, clamped=0.84010, resting=0.83975`. `|clamped - T| = 0.00036 > 1e-6`; `resting >= T - 1e-6` (`0.83975 >= 0.839739`); `clamped > resting + 1e-6` (`0.84010 > 0.839751`) -> `true`. Stub returns `false` -> class **F**.
   - `CH2`: `is_long=false, T=0.83974, clamped=0.83975, resting=0.84010`. `clamped > resting + 1e-6` (`0.83975 > 0.840101`) is `false` -> `false`. Stub returns `false` -> class **G**.
   - `CH3`: `is_long=false, T=0.83974, clamped=0.83974, resting=0.84010`. `|clamped - T| = 0 <= 1e-6` -> `false`. Stub returns `false` -> class **G**.
   - `CH4`: `is_long=false, T=0.84050, clamped=0.84060, resting=0.83975`. `resting >= T - 1e-6` (`0.83975 >= 0.840499`) is `false` -> `false`. Stub returns `false` -> class **G**.
   - `CH5`: `is_long=false, T=0.83974, clamped=0.84010, resting=0.83974`. `resting >= T - 1e-6` (`0.83974 >= 0.839739`) is `true`; `clamped > resting + 1e-6` is `true` -> `true`. Stub returns `false` -> class **F**.
   - `CH6`: `is_long=true, T=1.08000, clamped=1.07960, resting=1.07999`. `|clamped - T| = 0.00040 > 1e-6`; `resting <= T + 1e-6` (`1.07999 <= 1.080001`); `clamped < resting - 1e-6` (`1.07960 < 1.079989`) -> `true`. Stub returns `false` -> class **F**.
   - `CH7`: `is_long=true, T=1.08000, clamped=1.07999, resting=1.07960`. `clamped < resting - 1e-6` (`1.07999 < 1.079599`) is `false` -> `false`. Stub returns `false` -> class **G**.
   - `CH8`: `is_long=true, T=1.07900, clamped=1.07890, resting=1.07999`. `resting <= T + 1e-6` (`1.07999 <= 1.079001`) is `false` -> `false`. Stub returns `false` -> class **G**.

3. **Engine tests `CE1`-`CE9` (Set-up S: short L0 at `0.83924`, `add=5.0`, `T=0.83974`, `deadband=2.0`, `stops=0`; Set-up L: long L0 at `1.08050`, `add=5.0`, `T=1.08000`, `deadband=2.0`, `stops=0`):**
   - `CE1` (S, `#6301` at `0.83975`, feed `0.83960 / 0.84009`): `clamped = 0.84010`, `Hold = true`. C2: `0` modifies, price `0.83975`. Stub: `|0.84010 - 0.83975| = 0.00035 >= 0.00020` -> `1` modify to `0.84010`. Both assertions fail at commit 1 -> class **F**.
   - `CE2` (S, `#6301` at `0.84010`, feed `0.83960 / 0.83974`): `clamped = 0.83975`, `Hold = false`, `|0.83975 - 0.84010| = 0.00035 >= 0.00020`. Both C2 and stub: `1` modify to `0.83975` -> class **G**.
   - `CE3` (S, `#6301` at `0.84010`, feed `0.83940 / 0.83955`): `T = 0.83974 > ask = 0.83955`, so `clamped = 0.83974`, `Hold = false`, `|0.83974 - 0.84010| = 0.00036 >= 0.00020`. Both C2 and stub: `1` modify to `0.83974` -> class **G**.
   - `CE4` (S, `#6301` at `0.83975`, feed `0.83960 / 0.84009`, `add_pips = 10.0`): `T = 0.83924 + 0.00100 = 0.84024 > ask = 0.84009`, so `clamped = 0.84024`, `Hold = false` (both because `clamped == T` and `resting < T`), `|0.84024 - 0.83975| = 0.00049 >= 0.00020`. Both C2 and stub: `1` modify to `0.84024` -> class **G**.
   - `CE5` (S, `#6301` at `0.83975`, 50 pairs of `[0.83960 / 0.84009 then 0.83960 / 0.83974]` = 100 calls):
     - C2: `0` modifies across all 100 calls, final price `0.83975`.
     - Stub: every odd call modifies `0.83975 -> 0.84010` and every even call modifies `0.84010 -> 0.83975`, producing `100` modifies in 100 calls and ending call 100 (an even/narrow tick) at `0.83975`.
     - Note for Cursor's commit 1 message (`N F / M G`): test `CE5` is class **F**; at the individual `Assert*` level inside `CE5`, the modify-count assertion (`0` vs `100`) is **F** while the post-tick-100 price assertion (`0.83975`) is **G** because the 100th tick is the narrow tick of pair 50.
   - `CE6` (S, `#6301` at `0.83975`, feed `0.83960 / 0.84009`, `stops = 50` -> `min_dist = 0.00050`): `clamped = 0.84009 + 0.00050 = 0.84059`, `Hold = true`. C2: `0` modifies, price `0.83975`. Stub: `1` modify to `0.84059`. Both assertions fail at commit 1 -> class **F**.
   - `CE7` (S, `#6301` at `0.83975`, feed `0.83960 / 0.83988`): `clamped = 0.83989`, `Hold = true`, `|0.83989 - 0.83975| = 0.00014 < 0.00020`. Both C2 and stub: `0` modifies, price `0.83975` -> class **G**.
   - `CE8` (S, `#6301` at `0.83975`, `g_grind_start_add_reprice_short = true`, feed `0.83960 / 0.83979`): `clamped = 0.83980`, `add_deadband = 0.05` pips (`0.000005`), `Hold = true`. C2: `0` modifies, price `0.83975`, flag cleared (`false`). Stub: `|0.83980 - 0.83975| = 0.00005 >= 0.000005` -> `1` modify to `0.83980`, flag cleared (`false`). Matches s5's annotation `F (flag assertion G)`.
   - `CE9` (L, `#6302` at `1.07999`, feed `1.07961 / 1.08010`): `clamped = 1.07961 - 0.00001 = 1.07960`, `Hold = true`. C2: `0` modifies, price `1.07999`. Stub: `|1.07960 - 1.07999| = 0.00039 >= 0.00020` -> `1` modify to `1.07960`. Both assertions fail at commit 1 -> class **F**.
   - **Total F / G count summary for commit 1:**
     - By test (17 tests: `CH1`-`CH8`, `CE1`-`CE9`): **8 F / 9 G** (`CH1, CH5, CH6, CE1, CE5, CE6, CE8, CE9` = 8 F; `CH2, CH3, CH4, CH7, CH8, CE2, CE3, CE4, CE7` = 9 G).
     - By assertion (27 assertions: 8 in `CH1`-`CH8` + 19 in `CE1`-`CE9`): **12 F / 15 G** (`CH1, CH5, CH6` [3] + `CE1` [2] + `CE5` modify count [1] + `CE6` [2] + `CE8` modify count & price [2] + `CE9` [2] = 12 F; `CH2, CH3, CH4, CH7, CH8` [5] + `CE2` [2] + `CE3` [2] + `CE4` [2] + `CE5` final price [1] + `CE7` [2] + `CE8` flag cleared [1] = 15 G).

---

### Q8. Anything else that makes this unsafe for E (FTMO) or the IC fleets.

**Verdict:** `NOT A DEFECT`

**Analysis:**
- The change is 14 lines in `ea/grind_pure.mqh` (`Grind_AddClampHold`) and a 2-line guard in `Grind_EnsureAddNext` (`ea/grind_engine.mqh`), with no new inputs, no state persisted in globals or GVs, and no changes to first placement (`Grind_SendNextAddEnt`), exit placement/management (`Grind_ExitQManageSide`), carry, or recon.
- For both E (FTMO, `stops_level = 0`, daily 2,000-command ceiling) and the IC fleets (nonzero `stops_level` on some symbols, handled identically via `clamped` as tested in `CE6`), `Grind_AddClampHold` strictly eliminates outward spread-chasing modifies on resting add orders while preserving inward repricing toward `T` and outward repricing when `T` itself moves further from the anchor.

---

## Overall Verdict

**GO**

Line count: 320
