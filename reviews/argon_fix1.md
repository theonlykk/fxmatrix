# Argon review: s6 Q1-Q4 of prompts/cursor_plan4_f1f4_fix1.md

Fetch: `git fetch origin`. origin/main read: `a360c282b94f974ecda816e99c227b21560d2b80`.

SHAs read: `a360c28` (this prompt), `7d8fa13` (core + tests), `efada62` (engine, `grind_pure.mqh`, `grind_exitq.mqh`, `grind_config.mqh`, `grind_carry.mqh`).

Verdict words: **WRONG** / **MATCHES** / **YES** / **NO** / **MISSING**.

Quote rule: `<commit>:<path>:<line>` then the exact line. Lines that themselves contain backticks are given as a one-line fenced block so the text is not truncated.

---

## Q1

**One wrong: RT76's "ZERO order rows at or after `1791331140000`".** B-8, B-9, B-10, B-11, RT75 and RT77 match the code.

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:144`
```
- **Q1.** Check each hand value of B-8 .. B-11 and RT75-RT77 against the code at `7d8fa13` and
```

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:145`
```
  `efada62` (engine). Any wrong?
```

### B-8. MATCHES

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:59`
```
- **B-8. RT67, timing 0.** The two open ticks assert `seam_cnt == 1 && ord_cnt == 1` (the long
```

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:60` `  L0 only, A1) and keep the L0 price 1.09981 (mid 1.10001 - 2 pips). The closed ticks unchanged.`

One entry per engine call, long first:

`efada62:ea/grind_exitq.mqh:19` `bool g_grind_ent_sent_this_tick = false;`

`efada62:ea/grind_engine.mqh:3196` `   g_grind_ent_sent_this_tick = false;`

`efada62:ea/grind_engine.mqh:3219` `   if(Grind_SideDepth(g_grind_long) == 0 && Grind_BuyLimitMarketable(buy_target, ask))`

`efada62:ea/grind_engine.mqh:3220` `      Grind_TryPlaceL0(g_grind_long, true, buy_target, magic, slot, max_layers, lots);`

`efada62:ea/grind_engine.mqh:3221` `   if(Grind_SideDepth(g_grind_short) == 0 && Grind_SellLimitMarketable(sell_target, bid))`

`efada62:ea/grind_engine.mqh:3222` `      Grind_TryPlaceL0(g_grind_short, false, sell_target, magic, slot, max_layers, lots);`

`efada62:ea/grind_engine.mqh:2074` `   if(g_grind_ent_sent_this_tick)`

`efada62:ea/grind_engine.mqh:2075` `      return false;`

`efada62:ea/grind_engine.mqh:2099` `      g_grind_ent_sent_this_tick = true;`

Width 2, pip = 10 points:

`7d8fa13:ea/fxgrind_replay_core.mqh:1687` `   cfg.width_l = 2.0;`

`efada62:ea/grind_pure.mqh:106` `double Grind_PipsToPrice(const double pips, const double point)`

`efada62:ea/grind_pure.mqh:108` `   return pips * point * 10.0;`

`efada62:ea/grind_pure.mqh:118` `double Grind_MidPrice(const double bid, const double ask)`

`efada62:ea/grind_pure.mqh:120` `   return (bid + ask) * 0.5;`

`efada62:ea/grind_pure.mqh:128` `   return mid - Grind_PipsToPrice(width_pips, point);`

RT67 helper: bid 1.10000, ask 1.10002 → mid 1.10001 − 2 pips = 1.09981. Current test still expects two orders:

`7d8fa13:ea/fxgrind_replay_tests.mq5:2696` `   ticks[0].bid = 1.10000;`

`7d8fa13:ea/fxgrind_replay_tests.mq5:2697` `   ticks[0].ask = 1.10002;`

`7d8fa13:ea/fxgrind_replay_tests.mq5:2715`
```
   AssertTrue("RT67 23:58:59 open places 2", seam_cnt == 2 && ord_cnt == 2);
```

`7d8fa13:ea/fxgrind_replay_tests.mq5:2716`
```
   AssertNear("RT67 23:58:59 L0 price", l0_px, 1.09981, 1e-6);
```

Closed ticks use `[from, to)` on the minute:

`7d8fa13:ea/fxgrind_replay_core.mqh:272` `         && m >= g_rpl_sessions[i].from_min`

`7d8fa13:ea/fxgrind_replay_core.mqh:273` `         && m < g_rpl_sessions[i].to_min)`

### B-9. MATCHES

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:61`
```
- **B-9. RT68.** "ungated places 2 L0s" becomes "ungated places 1 L0": `Rpl_OrderLogCount() == 1`.
```

`7d8fa13:ea/fxgrind_replay_tests.mq5:2788`
```
   AssertTrue("RT68 ungated places 2 L0s", Rpl_OrderLogCount() == 2);
```

Same A1: one PLACE. Count 1 is right.

### B-10. MATCHES

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:62`
```
- **B-10. RT72.** The EXT deal price is 1.10452 (A3: the deal at T+261 takes the newest tick at
```

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:63` `  or before it, T+100, ask 1.10452). Keep 1e-6.`

`7d8fa13:ea/fxgrind_replay_core.mqh:439` `      g_rpl_tm_lam = 261;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1064` `   if(Rpl_TmNewestTickAtOrBefore(deal_time, tk)) {`

`7d8fa13:ea/fxgrind_replay_core.mqh:1065` `      if(rec.type == ORDER_TYPE_BUY_LIMIT)`

`7d8fa13:ea/fxgrind_replay_core.mqh:1066` `         fill_price = g_rpl_tm_limit_price ? rec.price : tk.ask;`

`7d8fa13:ea/fxgrind_replay_tests.mq5:3001`
```
   Rpl_SeedOrder("S", 0, "EXT", 1.10400, 7211UL, ORDER_TYPE_BUY_LIMIT);
```

`7d8fa13:ea/fxgrind_replay_tests.mq5:3010` `   ticks[1].time_msc = T + 100;`

`7d8fa13:ea/fxgrind_replay_tests.mq5:3012` `   ticks[1].ask = 1.10452;`

`7d8fa13:ea/fxgrind_replay_tests.mq5:3037`
```
   AssertTrue("RT72 in-flight EXT deal completes at T0+261", ext_in == 1 && ext_ms == T + 261);
```

`7d8fa13:ea/fxgrind_replay_tests.mq5:3038`
```
   AssertNear("RT72 EXT deal price", ext_px, 1.10400, 1e-6);
```

Deal time T+261; newest tick at or before it is T+100; buy-limit fill at that ask 1.10452. `limit_price` is false in `"base"`:

`7d8fa13:ea/fxgrind_replay_core.mqh:433` `   g_rpl_tm_limit_price = false;`

### B-11. MATCHES

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:67` `  Hand values: tick 0 (bid 1.09900, ask 1.09902): the add target is L1 1.09930 - 7 pips =`

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:68`
```
  1.09860, below the bid, not clamped: ONE `PLACE` of L L2 ENT at T0, price 1.09860 (the
```

`7d8fa13:ea/fxgrind_replay_core.mqh:1689` `   cfg.add_l = 7.0;`

`efada62:ea/grind_engine.mqh:2035` `int Grind_FindDeepestLayerArrayIndex(const GrindSideState &side)`

`efada62:ea/grind_engine.mqh:2042` `      if(side.layers[i].layer_index > side.layers[best].layer_index)`

`efada62:ea/grind_pure.mqh:154` `   return anchor_entry - (double)direction * Grind_PipsToPrice(add_pips, point);`

L1 index 1 is deeper than L0; 1.09930 − 0.00070 = 1.09860. Bid 1.09900: theoretical < bid, no clamp:

`efada62:ea/grind_pure.mqh:204` `   const double min_dist = MathMax(point, stops_level_points * point);`

`efada62:ea/grind_pure.mqh:205` `   if(theoretical >= bid)`

`efada62:ea/grind_pure.mqh:207` `   else`

`efada62:ea/grind_pure.mqh:208` `      out_price = theoretical;`

Timed market seed uses stops 0:

`7d8fa13:ea/fxgrind_replay_core.mqh:772` `   Grind_MarketTestSeed(tk.bid, tk.ask, 0, 0);`

Short L0 seeded, so it is not sent (place-once) and the long add can go at tick 0:

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:65`
```
  the run, `Rpl_SeedOrder("S", 0, "ENT", 1.10051, 6412UL, ORDER_TYPE_SELL_LIMIT);` (the short L0
```

`7d8fa13:ea/fxgrind_replay_core.mqh:1953` `      if(ArraySize(side.layers) == 0)`

`7d8fa13:ea/fxgrind_replay_core.mqh:1954` `         side.l0_pending_ticket = ticket;`

`efada62:ea/grind_engine.mqh:2062` `   if(side.l0_pending_ticket != 0) {`

`efada62:ea/grind_engine.mqh:2070` `         return false;`

Mid 1.09901 + 15 pips = 1.10051. Recenter 15.0 / 19.0 pips vs 50: no move.

`7d8fa13:ea/fxgrind_replay_core.mqh:1688` `   cfg.width_s = 15.0;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1694` `   cfg.stranded = 50.0;`

`efada62:ea/grind_pure.mqh:245` `   return MathAbs(resting_price - current_mid) / (point * 10.0);`

`efada62:ea/grind_pure.mqh:251` `   return (dist_mid_pips > thresh_pips);`

Tick 1: target 1.09860, bid 1.09860 → theoretical >= bid → `bid - point` = 1.09859 (0.1 pip = 1 point on 5-digit). Deadband is strict `<`:

`efada62:ea/grind_pure.mqh:170` `   return (MathAbs(target_price - resting_price) < band);`

0.00001 < 0.00020 (2.0 pips) → no MODIFY. 0.00001 < 0.000005 (0.05) is false → MODIFY without F3.

One-shot is consumed on the tick-0 EnsureAddNext, and F3 already omitted the re-arm on reset:

`efada62:ea/grind_engine.mqh:2561`
```
   const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;
```

`efada62:ea/grind_engine.mqh:2563` `      g_grind_start_add_reprice_long = false;`

`efada62:ea/grind_engine.mqh:2566` `   const double add_deadband = one_shot ? 0.05 : deadband_pips;`

`7d8fa13:ea/fxgrind_replay_core.mqh:2797` `   g_grind_long.l0_pending_ticket = keep_l0;`

`7d8fa13:ea/fxgrind_replay_core.mqh:2798` `   g_grind_long.add_pending_ticket = keep_add;`

No `g_grind_start_add_reprice_long =` in `Rpl_SyncResetToTrueBook` at `7d8fa13` (2734-2801).

ROLL writes VL onto the true-book row, not the L1 entry, so the add anchor stays L1 1.09930:

`7d8fa13:ea/fxgrind_replay_core.mqh:2855`
```
      } else if(rd.kind == "ROLL") {
```

`7d8fa13:ea/fxgrind_replay_core.mqh:2858` `               g_rpl_true_book[i].vl = rd.level;`

### RT75. MATCHES

Times: 2026-10-06 23:58:59.900 = `1791331139900`; 23:59:00.000 = `1791331140000`; 2026-10-07 00:01:00.000 = `1791331260000`. Place 287 ms → send_end 23:59:00.187. Gate is stage start:

`7d8fa13:ea/fxgrind_replay_core.mqh:435` `      g_rpl_tm_d_place = 287;`

`7d8fa13:ea/fxgrind_replay_core.mqh:989` `   const long stage_start = cursor;`

`7d8fa13:ea/fxgrind_replay_core.mqh:996` `   Rpl_SessionSendGateBegin(stage_start, gate_snap);`

`7d8fa13:ea/fxgrind_replay_core.mqh:858` `   Rpl_OrderLogAppendRowAt(send_start, stage, action, ticket, otype, comment, price, old_price);`

`7d8fa13:ea/fxgrind_replay_core.mqh:281` `   snap.gated = !Rpl_SessionIsOpen(time_ms);`

23:58:59.900 → minute 58, OPEN (`m < 1439`). 23:59:00.000 → minute 59, CLOSED. Same L0 price as B-8. Helper restores seams via `Rpl_SessionSendGateEnd`.

### RT76. WRONG (one expected)

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:96`
```
  price 1.11903 (t1's ask, A3); ZERO order rows at or after `1791331140000` (the exit at
```

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:97`
```
  1.12003, any add or recenter: all refused); both seams' `send_ok` true afterwards.
```

These match: t1+261 = `1791331140000`; t1+287 = `1791331140026`; mid 1.11875 + 15 pips = 1.12025; fill 1.11903; exit 1.11903 + 10 pips = 1.12003.

The ZERO is wrong if the test counts every `g_rpl_orders` row. The DEAL handler removes the filled limit then diffs it as FILL and stamps the row at the **handler cursor**, `1791331140026`:

`7d8fa13:ea/fxgrind_replay_core.mqh:1039` `   const long start = MathMax(ev.start_ms, g_rpl_tm_free_ms);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1045` `   const long deal_time = ev.start_ms;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1088` `   Grind_OrderTestRemove(ticket);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1098` `   Rpl_TmDiffStageSends("DEAL", cursor, sends, false, cb_empty, 0, cb_empty, 0);`

`7d8fa13:ea/fxgrind_replay_core.mqh:947` `      bool is_fill = Rpl_OrderLogDealFillAt(cursor, snap.ticket);`

`7d8fa13:ea/fxgrind_replay_core.mqh:948` `      if(!is_fill && stage == "DEAL")`

`7d8fa13:ea/fxgrind_replay_core.mqh:949` `         is_fill = Rpl_OrderLogDealFillForOrder(snap.ticket);`

`7d8fa13:ea/fxgrind_replay_core.mqh:950` `      pending_actions[pending_n] = is_fill ? "FILL" : "REMOVE";`

`7d8fa13:ea/fxgrind_replay_core.mqh:959` `      if(pending_actions[p] == "FILL") {`

`7d8fa13:ea/fxgrind_replay_core.mqh:960` `         Rpl_OrderLogAppendRowAt(cursor, stage, "FILL", pending_tickets[p], pending_types[p], pending_comments[p],`

`7d8fa13:ea/fxgrind_replay_core.mqh:1568` `bool Rpl_OrderLogDealFillForOrder(const ulong order_ticket)`

`7d8fa13:ea/fxgrind_replay_core.mqh:1571` `      if(g_rpl_deals[i].order == order_ticket && g_rpl_deals[i].entry_type == DEAL_ENTRY_IN)`

`FillAt` needs `time_ms == cursor`; the IN deal is written at `deal_time` = `1791331140000`, not 0026, so `FillForOrder` fires and the FILL row is at 0026.

The parenthetical (exit / add / recenter refused) is right: those are PlaceLimit under the CLOSED gate and do not become PLACE/MODIFY/REMOVE. A test that asserts `time_ms >= 1791331140000` on **all** order-log rows will fail on the FILL.

Prompt s5:

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:136` `- A hand value here disagrees with the code as you read it: quote both, do not pick one.`

### RT77. MATCHES (out_by implied)

`Rpl_SyncCompletionGateMs` is not in `7d8fa13`. The numbers match B-12 and `Rpl_SessionIsOpen` if the argument is `1791331098000` (23:58:18.000) and the IC table is loaded:

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:106`
```
- **B-12.** `long Rpl_SyncCompletionGateMs(const long out_by_ms)`: timed, `MathMax(out_by_ms,
```

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:107`
```
  g_rpl_tm_free_ms)`; timing 0, `out_by_ms`. (Tests commit: a stub returning `out_by_ms`.)
```

`7d8fa13:ea/fxgrind_replay_tests.mq5:2599`
```
   Rpl_AddTestSession(1, "00:01", "23:59");
```

`7d8fa13:ea/fxgrind_replay_tests.mq5:2600`
```
   Rpl_AddTestSession(2, "00:01", "23:59");
```

23:58 OPEN (`m=1438 < 1439`); 23:59:00 CLOSED (`m=1439 < 1439` is false). `MathMax(1791331098000, 1791331140000)=1791331140000`; `MathMax(1791331098000, 1791331000000)=1791331098000`.

---

## Q2

**Exits send at tick 0. They do not move or block the long add.** Recenter, stray-L0, `Grind_ServiceDueAddFlags` and the lattice do not send, move or block it at tick 0 or tick 1.

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:146`
```
- **Q2.** RT64 redesigned: does anything else at tick 0 or tick 1 send, move or block the long
```

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:147`
```
  add (exits, the stray-L0 reconcile, a recenter, `Grind_ServiceDueAddFlags`, the lattice)?
```

Engine order: exits, due-adds, stray, L0s, recenter, then EnsureAddNext:

`efada62:ea/grind_engine.mqh:3203` `   Grind_RetryMissingExits(magic, slot, lots);`

`efada62:ea/grind_engine.mqh:3204` `   Grind_ServiceDueAddFlags(magic, slot, add_pips, deadband_pips, max_layers, lots, add_s);`

`efada62:ea/grind_engine.mqh:3206` `   Grind_ReconcileStrayL0(g_grind_long, true, magic);`

`efada62:ea/grind_engine.mqh:3234` `   if(Grind_SideDepth(g_grind_long) > 0 || g_grind_long.add_pending_ticket != 0)`

`efada62:ea/grind_engine.mqh:3235` `      Grind_EnsureAddNext(g_grind_long, true, magic, slot, add_pips, deadband_pips, max_layers, lots);`

**Exits.** Depth 2, K=1: both ranks required. Two EXT PLACE at tick 0. `g_grind_ent_sent_this_tick` is only set on an entry send, so they do not block the add.

`efada62:ea/grind_config.mqh:7` `#define GRIND_EXITQ_K                 1`

`efada62:ea/grind_exitq.mqh:47` `   if(rank < Grind_ExitQK())`

`efada62:ea/grind_exitq.mqh:48` `      return true;`

`efada62:ea/grind_exitq.mqh:49` `   return (rank == depth - 1);`

`efada62:ea/grind_engine.mqh:3480` `      if(!Grind_ExitQRequired(ranks[i], n))`

`efada62:ea/grind_engine.mqh:3500` `      const ulong ticket = Grind_PlaceLimit(otype, price, lots, magic, comment);`

At tick 1 those exits already have `exit_order_ticket != 0` and are skipped.

**Stray L0.** Long: depth 2, `l0_pending_ticket` is 0 (seeded as positions). Short: depth 0, returns before it could cancel the seeded short L0.

`efada62:ea/grind_engine.mqh:2108` `   if(Grind_SideDepth(side) == 0)`

`efada62:ea/grind_engine.mqh:2109` `      return;`

`efada62:ea/grind_engine.mqh:2110` `   if(side.l0_pending_ticket == 0)`

`efada62:ea/grind_engine.mqh:2111` `      return;`

**Recenter.** Long depth > 0 and short depth == 0 → recenter the **short** L0, not the long add. Dist 15.0 then 19.0, threshold 50: no.

`efada62:ea/grind_engine.mqh:3224` `   if(Grind_SideDepth(g_grind_long) > 0 && Grind_SideDepth(g_grind_short) == 0)`

`efada62:ea/grind_engine.mqh:3225` `      Grind_TryRecenterOppositeL0(g_grind_short, false, mid, magic, slot,`

**Due-add flags.** Fresh `Rpl_ResetAll` / `Grind_Adr152ResetDueFlags`; both due flags false. No send.

**Lattice.** `cfg.lattice` is true, cap 8, long depth 2: TrySide only at cap.

`7d8fa13:ea/fxgrind_replay_core.mqh:1693` `   cfg.cap = 8;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1696` `   cfg.lattice = true;`

`efada62:ea/grind_engine.mqh:1404` `   if(Grind_SideDepth(g_grind_long) >= max_layers)`

The B-11 asserts (one L L2 ENT PLACE at T0, `mod_n==0`, price 1.09860) still hold with the extra EXT rows.

---

## Q3

**Yes: t1 ONTICK, then the DEAL event during t2's `Rpl_TmRunEventsUpTo`, then t2 ONTICK.** Every **send** the EA tries after `1791331140000` is refused. The DEAL FILL row is not a send; it is still an order-log row (Q1).

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:148`
```
- **Q3.** RT76: does the t1 ONTICK, the DEAL event at t2 and the t2 ONTICK run in that order, and
```

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:149`
```
  is every order row the EA tries after `1791331140000` refused?
```

Timed tick:

`7d8fa13:ea/fxgrind_replay_core.mqh:3048` `   Rpl_TmRunEventsUpTo(t);`

`7d8fa13:ea/fxgrind_replay_core.mqh:3060` `   Rpl_TmBrokerStep(t, tick.bid, tick.ask);`

`7d8fa13:ea/fxgrind_replay_core.mqh:3061` `   Rpl_TmEaStepAtTick(t, seg_first_tick);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1184` `   while(g_rpl_tm_pend_count > 0 && g_rpl_tm_pend[0].start_ms <= t_limit) {`

At t1 (OPEN) broker enqueues DEAL at t1+261, then ONTICK runs (free_ms = from_ms = t1). DEAL start_ms `1791331140000` is **after** t1, so it is not drained at t1.

`7d8fa13:ea/fxgrind_replay_core.mqh:1219` `   if(!Rpl_SessionIsOpen(t))`

`7d8fa13:ea/fxgrind_replay_core.mqh:1220` `      return;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1234` `      Rpl_TmEnqueueDealEvent(t + g_rpl_tm_lam, ticket, rec);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1241` `   if(g_rpl_tm_free_ms <= t) {`

`7d8fa13:ea/fxgrind_replay_core.mqh:1242` `      Rpl_TmRunOntickHandler(t, false, seg_first_tick);`

At t2, `RunEventsUpTo(t2)` runs the DEAL (`start_ms <= t2`) **before** t2's broker step and ONTICK. t2 is CLOSED, so broker does not touch. After t1's PLACE, `g_rpl_tm_free_ms` is `1791331140026`, so DEAL `start = 0026` CLOSED.

No TIMER in the window: `from_ms+60000 = 1791331199739` is not `< to_ms = 1791331171000`.

`7d8fa13:ea/fxgrind_replay_core.mqh:1266` `   g_rpl_tm_next_timer_ms = cfg.from_ms + 60000;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1267` `   while(g_rpl_tm_next_timer_ms < cfg.to_ms) {`

DEAL then t2 ENGINE both gate CLOSED (`Rpl_SessionSendGateBegin` sets send_ok false). `Grind_ProcessDeal` still tries the exit and the add; PlaceLimit fails, so no PLACE/MODIFY/REMOVE. GateEnd restores both seams.

`efada62:ea/grind_engine.mqh:2972` `      Grind_AppendLayer(side, deal_price, position_id, c_layer, exit_pips, is_long);`

`efada62:ea/grind_engine.mqh:2973` `      Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);`

`efada62:ea/grind_engine.mqh:2978` `      Grind_TryPlaceAddAtFill(side, is_long, magic, slot, fill_add,`

`7d8fa13:ea/fxgrind_replay_core.mqh:288` `   g_grind_order_test_send_ok = false;`

`7d8fa13:ea/fxgrind_replay_core.mqh:290` `   g_grind_closeby_test_send_ok = false;`

---

## Q4

**MISSING:** RT77 never names the `out_by_ms` it passes, and `Rpl_ResetAll` does not clear `g_rpl_tm_on`.

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:150` `- **Q4.** What fact is missing?`

`a360c28:prompts/cursor_plan4_f1f4_fix1.md:99`
```
  table: `g_rpl_tm_on = false`: returns `1791331098000` (23:58:18.000) for that out_by. `g_rpl_tm_on =
```

The only way the timing-0 case returns `1791331098000` is if that is the argument (B-12: timing 0 returns `out_by_ms`). The prompt never writes `out_by_ms = 1791331098000`.

`7d8fa13:ea/fxgrind_replay_core.mqh:1450` `void Rpl_ResetAll()`

`7d8fa13:ea/fxgrind_replay_core.mqh:1510` `   ArrayResize(g_rpl_sessions, 0);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1511` `   g_rpl_sessions_count = 0;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1526` `   g_rpl_tm_free_ms = 0;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1537` `}`

Sessions and `g_rpl_tm_free_ms` are cleared. `g_rpl_tm_on` is not. It is only flipped by `Rpl_SetTiming`:

`7d8fa13:ea/fxgrind_replay_core.mqh:338` `bool   g_rpl_tm_on = false;`

`7d8fa13:ea/fxgrind_replay_core.mqh:498` `   if(timing == 0) {`

`7d8fa13:ea/fxgrind_replay_core.mqh:501` `      g_rpl_tm_on = false;`

`7d8fa13:ea/fxgrind_replay_core.mqh:509` `   g_rpl_tm_on = true;`

RT75 says reset timing to 0 after. RT77 only says `Rpl_ResetAll()` after. The last RT77 case leaves `g_rpl_tm_on` true. If any later test in the same `OnStart` runs without `Rpl_SetTiming(0, "base")`, it is timed.

Related (already in Q1): a DEAL FILL is an order-log row at the handler cursor, which the RT76 ZERO does not mention.

---

## Files opened

- `a360c28:prompts/cursor_plan4_f1f4_fix1.md` 1-152
- `7d8fa13:ea/fxgrind_replay_core.mqh` 114-123, 231-302, 338-448, 496-511, 686-733, 736-775, 848-878, 880-1033, 1036-1201, 1217-1270, 1450-1575, 1679-1704, 1907-1986, 2448-2525, 2706-2868, 2948-3112
- `7d8fa13:ea/fxgrind_replay_tests.mq5` 50-63, 2493-2528, 2597-2788, 2990-3041
- `efada62:ea/grind_engine.mqh` 2021-2046, 2049-2133, 2250-2287, 2432-2583, 2857-3022, 3026-3071, 3170-3238, 3451-3511, 1391-1415
- `efada62:ea/grind_pure.mqh` 106-226, 241-252
- `efada62:ea/grind_exitq.mqh` 19, 35-50
- `efada62:ea/grind_config.mqh` 7-8
- `efada62:ea/grind_carry.mqh` 597-665
