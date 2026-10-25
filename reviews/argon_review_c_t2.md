This message has a line count at the bottom

# Argon Review: `docs/runbooks/twoarm-reload-c-t2.md` (Fleet C OPT t2 Reload)

- **Branch:** `review/argon-c-t2`
- **Base commit (`origin/main`):** `339923f34880234dac9eaa06afc6c7c4043a7287`
- **Files read (at `origin/main`):**
  - `prompts/argon_review_c_t2.md` (lines 1-93)
  - `docs/runbooks/twoarm-reload-c-t2.md` (lines 1-121)
  - `ea/presets_c/eurusd_opt_c_t2.set` (lines 1-41)
  - `ea/presets_c/eurusd_opt_c_t1.set` (lines 1-41)
  - `ea/presets_c/audcad_opt_c_t2.set` (lines 1-41)
  - `ea/presets_c/audcad_opt_c_t1.set` (lines 1-41)
  - `ea/presets_e/audcad_opt_e_t3.set` (lines 1-41)
  - `scripts/ic_geometry_twoarm_c_t2.json` (lines 1-14)
  - `research/opt_budget/check_c_t2.py` (lines 1-60)
  - `ea/fxgrind.mq5` (lines 1-521)
  - `ea/grind_config.mqh` (lines 1-95)
  - `ea/grind_recon.mqh` (lines 1-1437)
  - `ea/grind_carry.mqh` (lines 1-1370)
  - `ea/grind_exitq.mqh` (lines 1-279)
  - `ea/grind_engine.mqh` (lines 1-3630)
  - `ea/grind_pure.mqh` (lines 1-691)
  - `ea/grind_replay.mqh` (lines 1-438)
  - `ea/grind_state.mqh` (lines 1-55)
  - `ea/grind_archive.mqh` (lines 1-704)
  - `ea/grind_telemetry.mqh` (lines 1-281)
  - `ea/grind_closeby.mqh` (lines 1-250)
  - `ea/grind_cap.mqh` (lines 1-333)
  - `ea/grind_quarantine.mqh` (lines 1-103)
  - `ea/grind_heartbeat_detail.mqh` (lines 1-685)
  - `scripts/build_logcheck.awk` (lines 1-40)
  - `docs/runbooks/twoarm-build-c.md` (lines 1-244)
  - `docs/runbooks/cap10-reload.md` (lines 1-278)
  - `handoffs/Handover/01_BOOT.md` (lines 1-225)
  - `handoffs/Handover/02_TRAPS.md` (lines 1400-1600, 2700-3064)
  - `handoffs/Handover/10_GEOMETRY_REGISTER.md` (lines 1-82)
  - `handoffs/Handover/NEW_CHAT_PROMPT.md` (lines 1-139)
  - `docs/architecture/fleet-c.md` (lines 1-229)
  - `handoffs/HANDOFF_2026-09-24.md` (lines 2800-2835, 7800-8428)
- **External / ungranted sources:** `pipshed` repository source files and the live Railway Postgres `config_events` database table: not read (outside `D:\fxmatrix`).
- **`python research/opt_budget/check_c_t2.py` output:**
  ```
  EURUSD OPT t2: OK
  AUDCAD OPT t2: OK
  C t2 presets: ALL OK
  ```

---

## 1. Check of K1-K7 (`docs/runbooks/twoarm-reload-c-t2.md` s0.1)

### K1 -- Raising `InpMaxLayers` cannot trip I7
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:31` `| K1 | Raising `InpMaxLayers` cannot trip I7: it fails only when a side holds MORE layers than the cap | `grind_recon.mqh` 489-495 | VERIFIED |`
  - `ea/grind_recon.mqh:489` `   if(long_count > max_layers) {`
  - `ea/grind_recon.mqh:490` `      return Grind_InvariantFail(reason_out, "I7_LONG_DEPTH",`
  - `ea/grind_recon.mqh:491` `                                 Grind_InvariantDetailI7(true, long_count, max_layers));`
  - `ea/grind_recon.mqh:492` `   }`
  - `ea/grind_recon.mqh:493` `   if(short_count > max_layers) {`
  - `ea/grind_recon.mqh:494` `      return Grind_InvariantFail(reason_out, "I7_SHORT_DEPTH",`
  - `ea/grind_recon.mqh:495` `                                 Grind_InvariantDetailI7(false, short_count, max_layers));`
  - `ea/grind_recon.mqh:496` `   }`
- **Analysis:** `Grind_ReconCheckInvariants` fails `I7_LONG_DEPTH` or `I7_SHORT_DEPTH` only when `long_count > max_layers` or `short_count > max_layers`. Under cap 7 each side holds at most 7 layers, so raising `InpMaxLayers` from 7 to 9 cannot fail I7.

### K2 -- The lattice acts only at depth >= cap; a side at 7 under cap 9 stops rolling and adds again
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:32` `| K2 | The lattice acts only at depth >= cap: a side at 7 under cap 9 stops rolling and adds again | `grind_engine.mqh` 1401-1415 (the call), 1303-1304 (the loop breaks below cap) | VERIFIED |`
  - `ea/grind_engine.mqh:1401` `   if(blocked)`
  - `ea/grind_engine.mqh:1402` `      return;`
  - `ea/grind_engine.mqh:1403` ``
  - `ea/grind_engine.mqh:1404` `   if(Grind_SideDepth(g_grind_long) >= max_layers)`
  - `ea/grind_engine.mqh:1405` `      Grind_LatticeTrySide(g_grind_long, true, magic, slot, lots, exit_pips, add_pips, max_layers,`
  - `ea/grind_engine.mqh:1406` `                           enabled, blocked, now, g_grind_vl_extreme_long, reroll, roll_gate,`
  - `ea/grind_engine.mqh:1407` `                           Grind_SideDepth(g_grind_short));`
  - `ea/grind_engine.mqh:1408` `   if(Grind_SideDepth(g_grind_short) >= max_layers) {`
  - `ea/grind_engine.mqh:1409` `      const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);`
  - `ea/grind_engine.mqh:1410` `      const double add_s = Grind_SidePips(false, add_pips, add_pips_short);`
  - `ea/grind_engine.mqh:1411` `      Grind_LatticeTrySide(g_grind_short, false, magic, slot, lots, exit_s, add_s,`
  - `ea/grind_engine.mqh:1412` `                           max_layers, enabled, blocked, now, g_grind_vl_extreme_short, reroll,`
  - `ea/grind_engine.mqh:1413` `                           roll_gate, Grind_SideDepth(g_grind_long));`
  - `ea/grind_engine.mqh:1414` `   }`
  - `ea/grind_engine.mqh:1415` `}`
  - `ea/grind_engine.mqh:1303` `      if(Grind_SideDepth(side) < max_layers)`
  - `ea/grind_engine.mqh:1304` `         break;`
  - `ea/grind_pure.mqh:229` `bool Grind_CanPlaceEntryLayer(const int current_layers, const int max_layers)`
  - `ea/grind_pure.mqh:230` `{`
  - `ea/grind_pure.mqh:231` `   return (current_layers < max_layers);`
  - `ea/grind_pure.mqh:232` `}`
  - `ea/grind_engine.mqh:2525` `   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers)) {`
- **Analysis:** Both the outer caller (`Grind_LatticeStep`) and the inner loop (`Grind_LatticeTrySide`) require `Grind_SideDepth >= max_layers`. At depth 7 under cap 9 (`7 < 9`), rolling stops and `Grind_CanPlaceEntryLayer(7, 9)` returns `true`, so `Grind_EnsureAddNext` places the 8th layer (`L07` when layers `0..6` are held).

### K3 -- With rolled layers (virtual levels), the add target anchors on the lowest effective entry
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:33` `| K3 | With rolled layers, the add target anchors on the lowest effective entry (the VL) | `grind_engine.mqh` 2250-2288 | VERIFIED |`
  - `ea/grind_engine.mqh:2250` `double Grind_ComputeAddTarget(const GrindSideState &side,`
  - `ea/grind_engine.mqh:2251` `                              const bool is_long,`
  - `ea/grind_engine.mqh:2252` `                              const double add_pips)`
  - `ea/grind_engine.mqh:2253` `{`
  - `ea/grind_engine.mqh:2254` `   const int n = Grind_SideDepth(side);`
  - `ea/grind_engine.mqh:2255` `   if(n <= 0)`
  - `ea/grind_engine.mqh:2256` `      return 0.0;`
  - `ea/grind_engine.mqh:2257` ``
  - `ea/grind_engine.mqh:2258` `   bool any_vl = false;`
  - `ea/grind_engine.mqh:2259` `   for(int i = 0; i < n; i++) {`
  - `ea/grind_engine.mqh:2260` `      if(Grind_VLHas(side.layers[i].position_ticket)) {`
  - `ea/grind_engine.mqh:2261` `         any_vl = true;`
  - `ea/grind_engine.mqh:2262` `         break;`
  - `ea/grind_engine.mqh:2263` `      }`
  - `ea/grind_engine.mqh:2264` `   }`
  - `ea/grind_engine.mqh:2265` ``
  - `ea/grind_engine.mqh:2266` `   double anchor = 0.0;`
  - `ea/grind_engine.mqh:2267` `   if(!any_vl) {`
  - `ea/grind_engine.mqh:2268` `      const int depth_idx = Grind_FindDeepestLayerArrayIndex(side);`
  - `ea/grind_engine.mqh:2269` `      if(depth_idx < 0)`
  - `ea/grind_engine.mqh:2270` `         return 0.0;`
  - `ea/grind_engine.mqh:2271` `      anchor = side.layers[depth_idx].entry_price;`
  - `ea/grind_engine.mqh:2272` `   } else {`
  - `ea/grind_engine.mqh:2273` `      anchor = Grind_EffectiveEntry(side.layers[0].entry_price, side.layers[0].position_ticket);`
  - `ea/grind_engine.mqh:2274` `      for(int i = 1; i < n; i++) {`
  - `ea/grind_engine.mqh:2275` `         const double eff = Grind_EffectiveEntry(side.layers[i].entry_price,`
  - `ea/grind_engine.mqh:2276` `                                                 side.layers[i].position_ticket);`
  - `ea/grind_engine.mqh:2277` `         if(is_long) {`
  - `ea/grind_engine.mqh:2278` `            if(eff < anchor)`
  - `ea/grind_engine.mqh:2279` `               anchor = eff;`
  - `ea/grind_engine.mqh:2280` `         } else {`
  - `ea/grind_engine.mqh:2281` `            if(eff > anchor)`
  - `ea/grind_engine.mqh:2282` `               anchor = eff;`
  - `ea/grind_engine.mqh:2283` `         }`
  - `ea/grind_engine.mqh:2284` `      }`
  - `ea/grind_engine.mqh:2285` `   }`
  - `ea/grind_engine.mqh:2286` `   return Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1);`
  - `ea/grind_engine.mqh:2287` `}`
  - `ea/grind_engine.mqh:2288` ``
- **Analysis:** Whenever any open layer on the side has a `GRIND_VL_<ticket>` GlobalVariable (`any_vl == true`), `Grind_ComputeAddTarget` sets `anchor` to the minimum `Grind_EffectiveEntry` across open layers on a long side (or maximum on a short side) and steps by `add_pips` via `Grind_AddTargetPrice`.

### K4 -- A changed exit is rebuilt at start-up from `GRIND_GEO_EXIT_<magic>_L/_S`, clamped passive where needed
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:34` `| K4 | A changed exit is rebuilt at start-up from the stored exit label (`GRIND_GEO_EXIT_<magic>_L/_S`), clamped passive where needed | `grind_carry.mqh` 614; `grind_engine.mqh` 3074-3169 | VERIFIED |`
  - `ea/grind_carry.mqh:614` `   return "GRIND_GEO_EXIT_" + IntegerToString((long)magic) + (is_long ? "_L" : "_S");`
  - `ea/grind_carry.mqh:635` `bool Grind_GeoExitChanged(const ulong magic, const bool is_long, const double current_exit)`
  - `ea/grind_carry.mqh:636` `{`
  - `ea/grind_carry.mqh:637` `   double label = 0.0;`
  - `ea/grind_carry.mqh:638` `   if(!Grind_GeoExitGet(magic, is_long, label))`
  - `ea/grind_carry.mqh:639` `      return false;`
  - `ea/grind_carry.mqh:640` `   return (MathAbs(label - current_exit) > 1e-6);`
  - `ea/grind_carry.mqh:641` `}`
  - `ea/grind_recon.mqh:1404` `   g_grind_rebuild_long = Grind_GeoExitChanged(g_grind_recon_magic, true, g_grind_recon_exit_pips);`
  - `ea/grind_recon.mqh:1405` `   g_grind_rebuild_short = Grind_GeoExitChanged(g_grind_recon_magic, false,`
  - `ea/grind_recon.mqh:1406` `                                                Grind_SidePips(false, g_grind_recon_exit_pips,`
  - `ea/grind_recon.mqh:1407` `                                                               g_grind_recon_exit_pips_short));`
  - `ea/grind_recon.mqh:1408` ``
  - `ea/grind_engine.mqh:3074` `bool Grind_RebuildExitsAtStartSide(GrindSideState &side,`
  - `ea/grind_engine.mqh:3075` `                                   const bool is_long,`
  - `ea/grind_engine.mqh:3076` `                                   const ulong magic,`
  - `ea/grind_engine.mqh:3116` `      const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);`
  - `ea/grind_engine.mqh:3117` `      double price = formula;`
  - `ea/grind_engine.mqh:3118` `      const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);`
  - `ea/grind_engine.mqh:3119` `      const double old_price = resting;`
  - `ea/grind_engine.mqh:3120` ``
  - `ea/grind_engine.mqh:3121` `      if(MathAbs(resting - price) > _Point * 0.5) {`
  - `ea/grind_engine.mqh:3122` `         if(!Grind_ModifyPendingPrice(exit_ticket, price, magic))`
  - `ea/grind_engine.mqh:3162` `                                           g_grind_recon_exit_pips_short);`
  - `ea/grind_engine.mqh:3163` `      if(!Grind_RebuildExitsAtStartSide(g_grind_short, false, magic, exit_s))`
  - `ea/grind_engine.mqh:3164` `         return false;`
  - `ea/grind_engine.mqh:3165` `   }`
  - `ea/grind_engine.mqh:3166` `   return true;`
  - `ea/grind_engine.mqh:3167` `}`
  - `ea/grind_engine.mqh:3168` ``
  - `ea/fxgrind.mq5:289` `      } else {`
  - `ea/fxgrind.mq5:290` `         Grind_GeoExitWriteLabels(InpMagic, g_geo_exit_long, g_geo_exit_short);`
- **Analysis:** On AUDCAD (`InpMagic=22260401`), `GRIND_GEO_EXIT_22260401_L` and `_S` hold `6.0`, so `Grind_GeoExitChanged` returns `true` for `18.0`, `Grind_RebuildExitsAtStart` logs `rebuild=true/true`, modifies each non-ejected resting exit order to `Grind_ExitQFormulaTarget(entry, 18.0, _Point, is_long, pos)` clamped passive via `Grind_ExitQClampPassive`, and `Grind_GeoExitWriteLabels` writes `18.0` to both labels. On EURUSD (`InpMagic=22260201`), `exit_pips` stays `7.0`, so `Grind_GeoExitChanged` returns `false` and `rebuild=false/false` leaves exits untouched.

### K5 -- After an exit rebuild the one-shot add re-price moves the resting add to the new distance
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:35` `| K5 | After an exit rebuild the one-shot add re-price moves the resting add to the new distance | `fxgrind.mq5` 289-292; `grind_engine.mqh` 2561-2575 | VERIFIED |`
  - `ea/fxgrind.mq5:289` `      } else {`
  - `ea/fxgrind.mq5:290` `         Grind_GeoExitWriteLabels(InpMagic, g_geo_exit_long, g_geo_exit_short);`
  - `ea/fxgrind.mq5:291` `         g_grind_start_add_reprice_long = true;`
  - `ea/fxgrind.mq5:292` `         g_grind_start_add_reprice_short = true;`
  - `ea/grind_engine.mqh:2561` `   const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;`
  - `ea/grind_engine.mqh:2562` `   if(is_long)`
  - `ea/grind_engine.mqh:2563` `      g_grind_start_add_reprice_long = false;`
  - `ea/grind_engine.mqh:2564` `   else`
  - `ea/grind_engine.mqh:2565` `      g_grind_start_add_reprice_short = false;`
  - `ea/grind_engine.mqh:2566` `   const double add_deadband = one_shot ? 0.05 : deadband_pips;`
  - `ea/grind_engine.mqh:2567` ``
  - `ea/grind_engine.mqh:2568` `   if(side.add_pending_ticket != 0) {`
  - `ea/grind_engine.mqh:2569` `      const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);`
  - `ea/grind_engine.mqh:2570` `      if(Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point))`
  - `ea/grind_engine.mqh:2571` `         return;`
  - `ea/grind_engine.mqh:2572` `      Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);`
  - `ea/grind_engine.mqh:2573` `      return;`
  - `ea/grind_engine.mqh:2574` `   }`
  - `ea/grind_engine.mqh:2575` ``
- **Analysis:** `OnInit` sets `g_grind_start_add_reprice_long = true` and `g_grind_start_add_reprice_short = true` whenever `Grind_ReconstructState()` and `Grind_RebuildExitsAtStart(InpMagic)` succeed. On the first tick, `Grind_EnsureAddNext` uses `add_deadband = 0.05` pips instead of `deadband_pips` (`2.0`) and modifies AUDCAD's resting add from 6 pips to 18 pips beyond the anchor (while EURUSD's resting add sits within `0.05` pips of its unchanged 7-pip target and returns without modifying).

### K6 -- C's six charts load the Experts copy, built 21 Oct 16:21:21 (`ea_build`, C88 closed)
- **Verdict:** **CONFIRMED** (in `handoffs/HANDOFF_2026-09-24.md`; live Railway Postgres `config_events` archive table itself: **NOT READ**)
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:36` `| K6 | C's six charts load the Experts copy, built 21 Oct 16:21:21 (`ea_build`, C88 closed) | HANDOFF s89 continued 2 | VERIFIED (archive) |`
  - `handoffs/HANDOFF_2026-09-24.md:8095` `  - **C's `ea_build` (C88 CLOSED):** all six `fxgrind 2026.10.21 16:21:21`. `ea_build` is `__DATETIME__`, the compile's`
  - `handoffs/HANDOFF_2026-09-24.md:8096` `    START (`fxgrind.mq5` 56); the docs' 16:21:37 is the `.ex5` write time (E: 04:36:25 against 04:36:40, the same gap).`
  - `docs/runbooks/twoarm-build-c.md:104` `Their Global Variables stay in the terminal (harmless; cleaned later as the twins', monday-build s7).`
  - `docs/runbooks/twoarm-build-c.md:105` ``
  - `docs/runbooks/twoarm-build-c.md:106` `**After the seven** (FROM = the minute before the first Remove; expected seven lines, the seven symbols, each`
- **Analysis:** The handoff record confirms all six charts on wine-c reported `ea_build` = `fxgrind 2026.10.21 16:21:21` after the 21 Oct attach from `Experts\fxmatrix\fxgrind` (the live Postgres database itself is outside `D:\fxmatrix` and not read). No EA code changes are part of t2, so no compile is needed.

### K7 -- The 200-order commitment guard and per-side bound (`cap + 3`)
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:37` `| K7 | Guard, by a bound: an entry needs `PositionsTotal() + OrdersTotal()` plus the fleet's non-EXT orders (counted again) `<= limit - (2 + 4 + reserve)`, reserve 8 when not near the market (C's presets `InpSlotNearReserve=8`): 194 near, 186 far on a 200 limit. Per side at most cap + 3 (cap - 1 layers, two exits, the resting add counted twice; at cap: cap + 2), so per instance 2 x (cap + 3): C after t2 = 2 x 24 + 4 x 20 = **128** with every side of all six full at once | `grind_exitq.mqh` 115-182; `grind_config.mqh` 9-10; `fxgrind.mq5` 40 | VERIFIED (bound; plus 1 per close-by in flight) |`
  - `ea/grind_config.mqh:7` `#define GRIND_EXITQ_K                 1`
  - `ea/grind_config.mqh:8` `#define GRIND_EXITQ_H                 0`
  - `ea/grind_config.mqh:9` `#define GRIND_SLOT_MARGIN             4`
  - `ea/grind_config.mqh:10` `#define GRIND_SLOT_NEAR_RESERVE       8     // Q, guard units reserved`
  - `ea/fxgrind.mq5:40` `input int    InpSlotNearReserve    = 0;       // preset opts in; Q = GRIND_SLOT_NEAR_RESERVE`
  - `ea/presets_c/eurusd_opt_c_t2.set:20` `InpAutoEjectSpreadMult=1.5`
  - `ea/presets_c/audcad_opt_c_t2.set:20` `InpAutoEjectSpreadMult=1.5`
  - `ea/grind_exitq.mqh:30` ``
  - `ea/grind_exitq.mqh:35` `int Grind_ExitQK()`
  - `ea/grind_exitq.mqh:36` `{`
  - `ea/grind_exitq.mqh:37` `   if(g_grind_exitq_test_k >= 0)`
  - `ea/grind_exitq.mqh:38` `      return g_grind_exitq_test_k;`
  - `ea/grind_exitq.mqh:115` `long Grind_SlotAccountLimit()`
  - `ea/grind_exitq.mqh:118` `      return g_grind_slot_test_limit;`
  - `ea/grind_exitq.mqh:129` `   if(Grind_OrderTestActive())`
  - `ea/grind_exitq.mqh:131` `   return PositionsTotal() + OrdersTotal();`
  - `ea/grind_exitq.mqh:141` ``
  - `ea/grind_exitq.mqh:148` `      const long magic = OrderGetInteger(ORDER_MAGIC);`
  - `ea/grind_exitq.mqh:157` `            continue;`
  - `ea/grind_exitq.mqh:158` `      }`
  - `ea/grind_exitq.mqh:163` ``
  - `ea/grind_exitq.mqh:174` `                            const int used,`
  - `ea/grind_exitq.mqh:175` `                            const int resting_ent,`
  - `ea/grind_exitq.mqh:176` `                            const bool near_market)`
  - `ea/grind_engine.mqh:2125` `   if(Grind_SelectOurPosition(side.l0_pending_ticket, magic))`
  - `ea/grind_engine.mqh:2316` `   if(side.add_pending_ticket != 0) {`
  - `ea/grind_engine.mqh:3474` `   for(int i = 0; i < n; i++) {`
  - `ea/grind_engine.mqh:3475` `      if(!Grind_ExitQAllowed(ranks[i], n) && side.layers[i].exit_order_ticket != 0)`
  - `ea/grind_engine.mqh:3476` `         Grind_ExitQHoldCancelLayer(side.layers[i], is_long, magic);`
- **Analysis of the per-side bound:**
  1. Because `GRIND_EXITQ_K = 1` and `GRIND_EXITQ_H = 0`, `Grind_ExitQAllowed(rank, depth)` allows resting `EXT` orders only on `rank == 0` and `rank == depth - 1`, and `Grind_ExitQManageSide` cancels any resting `exit_order_ticket` on middle ranks before placing new exits. Thus a side holds at most **2 resting `EXT` orders** (`0` at `d = 0`, `1` at `d = 1`, `2` at `d >= 2`).
  2. For `ENT` orders: at `d = 0`, a side holds at most 1 `l0_pending_ticket` (`Grind_ReconcileStrayL0` cancels any stray L0 when `d > 0`). At `1 <= d <= cap - 1`, a side holds at most 1 `add_pending_ticket`. At `d = cap`, `Grind_CanPlaceEntryLayer(cap, cap)` is `false`, so no add order rests. Thus a side holds at most **3 resting orders** (`2` `EXT` + `1` `ENT` at `2 <= d <= cap - 1`).
  3. In guard units (`Grind_SlotUsed() + Grind_SlotRestingEnt()`):
     - `d = 0`: `0` positions + `1` L0 order (counted twice) = `2` units.
     - `d = 1`: `1` position + `1` `EXT` order + `1` add order (counted twice) = `4` units.
     - `2 <= d <= cap - 1`: `d` positions + `2` `EXT` orders + `1` add order (counted twice) = `d + 4` units, peaking at `d = cap - 1` with `(cap - 1) + 4 = cap + 3` units (`12` at cap 9; `10` at cap 7).
     - `d = cap`: `cap` positions + `2` `EXT` orders + `0` `ENT` orders = `cap + 2` units (`11` at cap 9; `9` at cap 7).
  4. Thus `cap + 3` per side (`24` an instance at cap 9, `20` an instance at cap 7, `2 x 24 + 4 x 20 = 128 <= 186` across C's six instances, plus 1 per close-by in flight) is confirmed.

---

## 2. Answers to Questions Q1-Q5 (`docs/runbooks/twoarm-reload-c-t2.md` s8)

### Q1 -- Cap raise 7 -> 9 with rolled layers (VLs), re-roll state, or extreme tracking
- **Verdict:** **NOT A DEFECT**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:110` `1. K1-K5: is any path at a CAP RAISE with rolled layers (VLs) not covered, e.g. a re-roll state or the lattice's`
  - `docs/runbooks/twoarm-reload-c-t2.md:111` `   extreme tracking at a side that was at cap 7 and is now below cap 9?`
  - `ea/grind_engine.mqh:801` `   if(depth < max_layers) {`
  - `ea/grind_engine.mqh:804` `         g_grind_vl_extreme_long = 0.0;`
  - `ea/grind_engine.mqh:805` `         g_grind_vl_from_msc_long = 0;`
  - `ea/grind_engine.mqh:806` `         g_grind_vl_stranded_warned_long = false;`
  - `ea/grind_engine.mqh:807` `         g_grind_vl_closing_ticket_long = 0;`
  - `ea/grind_engine.mqh:808` `         g_grind_vl_closing_since_long = 0;`
  - `ea/grind_engine.mqh:825` `      if(!g_grind_vl_tracking_long) {`
  - `ea/grind_engine.mqh:836` `               newest = ot;`
  - `ea/grind_engine.mqh:933` `      if(Grind_VLHas(ticket))`
  - `ea/grind_engine.mqh:934` `         continue;`
  - `ea/grind_engine.mqh:1317` `      int idx = Grind_LatticeCandidateIndex(side, is_long);`
  - `ea/grind_engine.mqh:1319` `      if(idx < 0) {`
  - `ea/grind_engine.mqh:1320` `         if(reroll && rerolls >= 1)`
  - `ea/grind_engine.mqh:1321` `            break;`
  - `ea/grind_engine.mqh:1324` `            break;`
  - `ea/grind_engine.mqh:2551` `   if(is_long)`
  - `ea/grind_engine.mqh:2553` `   else`
  - `ea/grind_engine.mqh:3468` `      layer_indices[i] = side.layers[i].layer_index;`
  - `ea/grind_engine.mqh:3471` `   int ranks[];`
- **Analysis:** Every path at a cap raise with rolled layers is covered:
  1. When `depth < max_layers` (`<= 7 < 9`), `Grind_LatticeTrackOneSide` resets `g_grind_vl_tracking_* = false`, `g_grind_vl_extreme_* = 0.0`, `g_grind_vl_from_msc_* = 0`, `g_grind_vl_stranded_warned_* = false`, and `g_grind_vl_backoff_* = 0` (and Remove-then-Attach also re-initializes all in-memory globals on attach).
  2. Existing `GRIND_VL_<ticket>` GlobalVariables on layers `0..6` persist in MT5, so `Grind_ComputeAddTarget` anchors `L07` one `add_pips` beyond the lowest (long) or highest (short) `Grind_EffectiveEntry` (and if the market had already moved beyond that level while re-roll was paused at rollover, `Grind_EnsureAddNext` clamps `L07` passive via `Grind_Adr013ClampBuy` / `Grind_Adr013ClampSell`).
  3. When `L07` and `L08` later fill and `depth` reaches 9, `Grind_LatticeTrackOneSide` seeds `g_grind_vl_from_msc_*` from `newest` (the `POSITION_TIME` of `L08`), so old ticks from the earlier cap-7 episode are not replayed.
  4. At depth 9, `Grind_LatticeCandidateIndex` rolls unrolled layers (`L07`, `L08`, where `!Grind_VLHas(ticket)`) before falling back to `Grind_LatticeRerollIndex`, and `Grind_ExitQRanks` orders all layers by `Grind_EffectiveEntry`.

### Q2 -- AUDCAD exit 6 -> 18 (exits moved 12 pips AWAY) and `Grind_CarryShiftDelete`
- **Verdict:** **NOT A DEFECT**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:112` `2. AUDCAD's exit change moves every exit 12 pips AWAY: is anything in the rebuild (clamps, carry shift records)`
  - `docs/runbooks/twoarm-reload-c-t2.md:113` `   built for exits moving closer only?`
  - `ea/grind_engine.mqh:3088` `      if(exit_ticket == 0 || side.layers[i].exit_position_ticket != 0)`
  - `ea/grind_engine.mqh:3089` `         continue;`
  - `ea/grind_engine.mqh:3100` `      if(Grind_EjectIsEjected(pos) && !Grind_VLHas(pos)) {`
  - `ea/grind_engine.mqh:3109` `         const string detail = StringFormat(`
  - `ea/grind_engine.mqh:3116` `      const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);`
  - `ea/grind_engine.mqh:3117` `      double price = formula;`
  - `ea/grind_engine.mqh:3118` `      const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);`
  - `ea/grind_engine.mqh:3119` `      const double old_price = resting;`
  - `ea/grind_engine.mqh:3120` ``
  - `ea/grind_engine.mqh:3121` `      if(MathAbs(resting - price) > _Point * 0.5) {`
  - `ea/grind_engine.mqh:3122` `         if(!Grind_ModifyPendingPrice(exit_ticket, price, magic))`
  - `ea/grind_engine.mqh:3123` `            return false;`
  - `ea/grind_engine.mqh:3124` `         repriced++;`
  - `ea/grind_engine.mqh:3125` `      }`
  - `ea/grind_engine.mqh:3126` ``
  - `ea/grind_engine.mqh:3127` `      side.layers[i].exit_target = price;`
  - `ea/grind_engine.mqh:3128` ``
  - `ea/grind_engine.mqh:3129` `      if(clamped || MathAbs(price - formula) > _Point * 0.5)`
  - `ea/grind_engine.mqh:3130` `         Grind_CarryRecordShift(pos, price - formula, true);`
  - `ea/grind_engine.mqh:3131` `      else`
  - `ea/grind_engine.mqh:3132` `         Grind_CarryShiftDelete(pos);`
  - `ea/grind_engine.mqh:3133` ``
  - `ea/grind_exitq.mqh:247` `   const double accrued = (position_ticket > 0)`
  - `ea/grind_exitq.mqh:251` `                               ? Grind_EjectOffsetGet(position_ticket)`
  - `ea/grind_exitq.mqh:252` `                               : 0.0;`
  - `ea/grind_exitq.mqh:253` `   const double eff = Grind_EffectiveEntry(entry, position_ticket);`
  - `ea/grind_exitq.mqh:254` `   return Grind_ExitPrice(eff, exit_pips, point, is_long ? 1 : -1) + accrued + eject_offset;`
  - `ea/grind_carry.mqh:526` `void Grind_CarryShiftDelete(const ulong position_ticket)`
  - `ea/grind_carry.mqh:527` `{`
  - `ea/grind_carry.mqh:528` `   GlobalVariableDel(Grind_CarryShiftGvName(position_ticket));`
  - `ea/grind_carry.mqh:529` `   GlobalVariableDel(Grind_CarryReleaseGvNameLocal(position_ticket));`
  - `ea/grind_carry.mqh:530` `   Grind_GvMarkDirty();`
  - `ea/grind_carry.mqh:531` `}`
  - `ea/grind_recon.mqh:1170` `         long_out.layers[n].exit_target =`
  - `ea/grind_recon.mqh:1171` `            Grind_ExitQFormulaTarget(long_scratch[j].entry_price, exit_pips, point, true,`
  - `ea/grind_recon.mqh:1172` `                                     long_scratch[j].position_id);`
  - `ea/grind_recon.mqh:1186` `         short_out.layers[n].exit_target =`
  - `ea/grind_recon.mqh:1187` `            Grind_ExitQFormulaTarget(short_scratch[j].entry_price, exit_s, point, false,`
  - `ea/grind_recon.mqh:1188` `                                     short_scratch[j].position_id);`
  - `ea/grind_engine.mqh:3490` `      const double formula = Grind_ExitQFormulaTarget(side.layers[i].entry_price,`
  - `ea/grind_engine.mqh:3491` `                                                      exit_pips, _Point, is_long,`
  - `ea/grind_engine.mqh:3492` `                                                      side.layers[i].position_ticket);`
  - `ea/grind_engine.mqh:3493` `      double price = formula;`
  - `ea/grind_engine.mqh:3494` `      const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);`
  - `ea/grind_recon.mqh:387` `   const double expected = Grind_ExitPrice(eff, exit_pips, point, dir) + accrued + eject_offset + shift;`
- **Analysis:**
  1. **Resting exits (rank 0 and rank `depth - 1`):** Increasing `exit_pips` from 6.0 to 18.0 moves a long `SELL_LIMIT` +12 pips higher (further above `ask`) and a short `BUY_LIMIT` -12 pips lower (further below `bid`). `Grind_ExitQClampPassive` returns `false` (`price == formula`), and `Grind_ModifyPendingPrice` moves both resting exits to the 18-pip `formula`. (If a layer was passive-ejected and unrolled, `Grind_RebuildExitsAtStartSide` keeps its resting exit price and updates `GRIND_EJECT_OFFSET_<pos>` to `resting - raw` so I6 still holds.)
  2. **Held middle exits (ADR-151, `exit_order_ticket == 0`):** `Grind_RebuildBookFromTicketsInner` initializes their `exit_target` to `Grind_ExitQFormulaTarget(..., 18.0, ...)`, `Grind_RebuildExitsAtStartSide` skips them (`exit_ticket == 0`), and `Grind_ExitQManageSide` later places them at the 18-pip `formula` when promoted to `rank == 0` or `rank == depth - 1`.
  3. **ExitQ's rank-0 and furthest-exit rule:** `Grind_ExitQRanks` depends only on `Grind_EffectiveEntry` and `layer_index`, never on `exit_pips`.
  4. **`Grind_CarryShiftDelete(pos)` in `Grind_RebuildExitsAtStartSide` (line 3132 quoted above):** Nothing needed by recon or a later carry pass is lost. `Grind_CarryShiftDelete` deletes only `GRIND_CARRY_SHIFT_<pos>` and `GRIND_CARRY_RELEASE_<pos>` (the clamp residual `exit_target - formula`), while preserving `GRIND_CARRY_ACCRUED_<pos>`, which holds the accumulated swap carry and is already included in `formula` by `Grind_ExitQFormulaTarget`. Deleting `GRIND_CARRY_SHIFT_<pos>` when the rebuilt order rests unclamped at `price == formula` is required so `Grind_ReconExitMatchesEntry` sees `shift == 0.0` on the next tick.

### Q3 -- Remove-then-Attach vs F7 + Load when the chart already runs the Experts copy
- **Verdict:** **NOT A DEFECT**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:114` `3. Is Remove-then-Attach still the right path when the chart already runs the Experts copy (K6), or is F7 + Load now`
  - `docs/runbooks/twoarm-reload-c-t2.md:115` `   equivalent?`
  - `docs/runbooks/twoarm-reload-c-t2.md:66` `1. Right-click the chart -> Expert Advisors -> Remove. Gate: the Experts log shows `fxgrind deinit reason=1` for`
  - `docs/runbooks/twoarm-reload-c-t2.md:67` `   that symbol and the EA icon is gone.`
  - `docs/runbooks/twoarm-reload-c-t2.md:73` `3. The checker (twoarm-build-c s4 step 4's two commands, FROM as above). Expected one row: `deinit=1`
  - `docs/runbooks/twoarm-reload-c-t2.md:74` `   replay=ready(N) lattice=true reroll=true gate=0 api=1000000/999000`, `geo=` and `rebuild=` as s0, BAD 0, a POST`
  - `docs/runbooks/twoarm-reload-c-t2.md:75` `   ok, `telemetry dropped since FROM: 0`. The single `WARN STARTUP_EXIT_SHORTFALL long=1 short=0` (or 0 / 1) is`
  - `scripts/build_logcheck.awk:15` `  if ($0 ~ /fxgrind deinit reason=/) { match($0, /reason=[0-9]+/); dr[src] = substr($0, RSTART + 7, RLENGTH - 7); dq[src]++; next }`
  - `scripts/build_logcheck.awk:35` `  for (s in post) printf " %s=%d", s, post[s]`
- **Analysis:** Agree with Claude's view: keep Remove-then-Attach. Although F7 + Load (`reason=5`) would also re-init the Experts `.ex5`, Remove-then-Attach cleanly unloads all MQL5 global state, matches `twoarm-build-c` s4, and logs `fxgrind deinit reason=1` (`deinit=1`) as checked in s3 steps 1 and 3.

### Q4 -- Pipshed / archive requirements (`C129` geometry table, `vs_anchor`) and `Grind_CarryShiftDelete(pos)`
- **Verdict:** **NOT A DEFECT**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:116` `4. Is anything missing that a reload with a new cap needs on pipshed or the archive (the geometry table, `vs_anchor`)?`
  - `ea/fxgrind.mq5:77` `                                            g_grind_halt_reason,`
  - `ea/fxgrind.mq5:78` `                                            g_grind_recon_ok,`
  - `ea/fxgrind.mq5:102` `      "\"add_held_target_long\":%s,\"add_held_target_short\":%s,"`
  - `ea/fxgrind.mq5:103` `      "\"entry_transitions_used_long\":%d,\"entry_transitions_used_short\":%d,"`
  - `ea/fxgrind.mq5:104` `      "\"add_gap_missed_long\":%d,\"add_gap_missed_short\":%d,"`
  - `ea/fxgrind.mq5:105` `      "\"exit_clamped_promotions_long\":%d,\"exit_clamped_promotions_short\":%d,"`
  - `ea/fxgrind.mq5:345` `      "INIT", 0, _Symbol, InpSlot, GRIND_EA_BUILD,`
  - `ea/fxgrind.mq5:346` `      (long)AccountInfoInteger(ACCOUNT_LOGIN),`
  - `ea/fxgrind.mq5:347` `      g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,`
  - `ea/grind_archive.mqh:512` `          ",\"width_pips\":" + Grind_ArchiveJsonDouble(width_pips, 4) +`
  - `ea/grind_archive.mqh:513` `          ",\"add_pips\":" + Grind_ArchiveJsonDouble(add_pips, 4) +`
  - `ea/grind_archive.mqh:514` `          ",\"exit_pips\":" + Grind_ArchiveJsonDouble(exit_pips, 4) +`
  - `ea/grind_archive.mqh:515` `          ",\"max_layers\":" + IntegerToString(max_layers) +`
  - `handoffs/HANDOFF_2026-09-24.md:2809` `  gap and quote tables: per pair and fleet `W<width> A<add> X<exit>`
  - `handoffs/HANDOFF_2026-09-24.md:2810` `  c<cap>`, long/short only where the sides differ, from each heartbeat's`
  - `handoffs/HANDOFF_2026-09-24.md:2811` `  per-side keys (`fxgrind.mq5` 103-105; FTMO's `aa6970a` sends only the`
  - `handoffs/HANDOFF_2026-09-24.md:2812` `  base values, shown for both sides); a part that differs from fleet B`
  - `handoffs/HANDOFF_2026-09-24.md:2813` `  (the anchor) in amber. S and the deadband are not in the heartbeat.`
  - `docs/runbooks/twoarm-reload-c-t2.md:79` `5. pipshed `linuxc`: the instance LIVE, its geometry row cap 9 (AUDCAD 18 / 18).`
- **Analysis:**
  1. **Pipshed and archive:** Neither instance ID changes (`GRIND_EURUSD_OPTC`, `GRIND_AUDCAD_OPTC`). `OnInit` emits an `INIT` `config_event` carrying `width_pips`, `add_pips`, `exit_pips`, and `max_layers`, and every heartbeat sends those fields plus the per-side geometry fields, which pipshed's C129 geometry table reads dynamically and compares against the anchor (`pipshed` repository source itself is not read).
  2. **`Grind_CarryShiftDelete(pos)`:** As shown in Q2 above, `GRIND_CARRY_ACCRUED_<pos>` is preserved and folded into `formula` by `Grind_ExitQFormulaTarget`; only `GRIND_CARRY_SHIFT_<pos>` and `GRIND_CARRY_RELEASE_<pos>` are deleted when unclamped, which recon requires and a later carry pass does not read.

### Q5 -- Rollback to `_t1` moves AUDCAD's exits 12 pips CLOSER (18 -> 6)
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:117` `5. s5's AUDCAD rollback (exits 12 pips closer): does the clamp put a passed exit on the profit side for both sides,`
  - `docs/runbooks/twoarm-reload-c-t2.md:118` `   is the carry shift it records (3130) right for a later carry pass, and can any passed exit close at a loss, trip an`
  - `docs/runbooks/twoarm-reload-c-t2.md:119` `   invariant (I6 on an EXT order's price) or quarantine?`
  - `ea/grind_exitq.mqh:258` `bool Grind_ExitQClampPassive(const bool is_long,`
  - `ea/grind_exitq.mqh:259` `                             const double target,`
  - `ea/grind_exitq.mqh:260` `                             double &price_out)`
  - `ea/grind_exitq.mqh:261` `{`
  - `ea/grind_exitq.mqh:262` `   const double bid = Grind_MarketBid();`
  - `ea/grind_exitq.mqh:263` `   const double ask = Grind_MarketAsk();`
  - `ea/grind_exitq.mqh:264` `   const double point = _Point;`
  - `ea/grind_exitq.mqh:265` `   const long stops = Grind_MarketStopsLevel();`
  - `ea/grind_exitq.mqh:266` `   const long freeze = Grind_MarketFreezeLevel();`
  - `ea/grind_exitq.mqh:267` ``
  - `ea/grind_exitq.mqh:268` `   if(is_long)`
  - `ea/grind_exitq.mqh:269` `      return Grind_CarryClampLongExit(target, bid, ask, point, stops, freeze, price_out);`
  - `ea/grind_exitq.mqh:270` `   return Grind_CarryClampShortExit(target, bid, ask, point, stops, freeze, price_out);`
  - `ea/grind_exitq.mqh:271` `}`
  - `ea/grind_carry.mqh:435` `double Grind_CarryMinPassiveDistance(const double point,`
  - `ea/grind_carry.mqh:439` `   return MathMax(point, MathMax(stops_level * point, freeze_level * point));`
  - `ea/grind_carry.mqh:443` `bool Grind_CarryClampLongExit(const double theoretical,`
  - `ea/grind_carry.mqh:453` `   if(theoretical <= ask + min_dist - 1e-12) {`
  - `ea/grind_carry.mqh:454` `      out_price = ask + min_dist;`
  - `ea/grind_carry.mqh:455` `      return true;`
  - `ea/grind_carry.mqh:461` `bool Grind_CarryClampShortExit(const double theoretical,`
  - `ea/grind_carry.mqh:471` `   if(theoretical >= bid - min_dist + 1e-12) {`
  - `ea/grind_carry.mqh:472` `      out_price = bid - min_dist;`
  - `ea/grind_carry.mqh:473` `      return true;`
  - `ea/grind_carry.mqh:534` `void Grind_CarryRecordShift(const ulong position_ticket,`
  - `ea/grind_carry.mqh:541` `   else`
  - `ea/grind_carry.mqh:542` `      GlobalVariableDel(Grind_CarryReleaseGvNameLocal(position_ticket));`
  - `ea/grind_carry.mqh:756` `   const string release_gv = Grind_CarryReleaseGvNameLocal(position_ticket);`
  - `ea/grind_carry.mqh:757` `   if(GlobalVariableCheck(release_gv))`
  - `ea/grind_carry.mqh:758` `      return Grind_CarryShiftGet(position_ticket);`
  - `ea/grind_carry.mqh:1022` `                                               g_grind_carry_exit_work_pos[idx]),`
  - `ea/grind_carry.mqh:1124` `   const double theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction,`
  - `ea/grind_carry.mqh:1125` `                                                        accrued_pips, pip_size);`
  - `ea/grind_carry.mqh:1171` `   const double intended = formula_exit + accrued_price;`
  - `ea/grind_carry.mqh:1173` `   Grind_CarryRecordShift(position_ticket, applied_shift, clamped_out);`
  - `ea/grind_engine.mqh:3088` `      if(exit_ticket == 0 || side.layers[i].exit_position_ticket != 0)`
  - `ea/grind_engine.mqh:3089` `         continue;`
  - `ea/grind_engine.mqh:3116` `      const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);`
  - `ea/grind_engine.mqh:3117` `      double price = formula;`
  - `ea/grind_engine.mqh:3118` `      const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);`
  - `ea/grind_engine.mqh:3119` `      const double old_price = resting;`
  - `ea/grind_engine.mqh:3120` ``
  - `ea/grind_engine.mqh:3121` `      if(MathAbs(resting - price) > _Point * 0.5) {`
  - `ea/grind_engine.mqh:3122` `         if(!Grind_ModifyPendingPrice(exit_ticket, price, magic))`
  - `ea/grind_engine.mqh:3123` `            return false;`
  - `ea/grind_engine.mqh:3124` `         repriced++;`
  - `ea/grind_engine.mqh:3125` `      }`
  - `ea/grind_engine.mqh:3126` ``
  - `ea/grind_engine.mqh:3127` `      side.layers[i].exit_target = price;`
  - `ea/grind_engine.mqh:3128` ``
  - `ea/grind_engine.mqh:3129` `      if(clamped || MathAbs(price - formula) > _Point * 0.5)`
  - `ea/grind_engine.mqh:3130` `         Grind_CarryRecordShift(pos, price - formula, true);`
  - `ea/grind_engine.mqh:3131` `      else`
  - `ea/grind_engine.mqh:3132` `         Grind_CarryShiftDelete(pos);`
  - `ea/grind_engine.mqh:3133` ``
  - `ea/grind_recon.mqh:387` `   const double expected = Grind_ExitPrice(eff, exit_pips, point, dir) + accrued + eject_offset + shift;`
  - `ea/grind_recon.mqh:388` `   const double diff = exit_target - expected;`
  - `ea/grind_recon.mqh:389` `   if(exit_is_filled) {`
  - `ea/grind_recon.mqh:390` `      if(is_long && diff >= 0.0)`
  - `ea/grind_recon.mqh:391` `         return true;`
  - `ea/grind_recon.mqh:392` `      if(!is_long && diff <= 0.0)`
  - `ea/grind_recon.mqh:393` `         return true;`
  - `ea/grind_recon.mqh:394` `   }`
  - `ea/grind_recon.mqh:395` `   return (MathAbs(diff) <= 2.0 * point + GRIND_PRICE_EPS);`
  - `ea/grind_recon.mqh:529` `      if(!Grind_ReconLayerHasExitCoverage(long_layers[i]))`
  - `ea/grind_recon.mqh:530` `         continue;`
  - `ea/grind_recon.mqh:561` `      if(!Grind_ReconLayerHasExitCoverage(short_layers[i]))`
  - `ea/grind_recon.mqh:562` `         continue;`
  - `ea/grind_engine.mqh:3490` `      const double formula = Grind_ExitQFormulaTarget(side.layers[i].entry_price,`
  - `ea/grind_engine.mqh:3491` `                                                      exit_pips, _Point, is_long,`
  - `ea/grind_engine.mqh:3492` `                                                      side.layers[i].position_ticket);`
  - `ea/grind_engine.mqh:3493` `      double price = formula;`
  - `ea/grind_engine.mqh:3494` `      const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);`
  - `ea/grind_engine.mqh:3505` `      if(clamped || MathAbs(price - formula) > _Point * 0.5) {`
  - `ea/grind_engine.mqh:3506` `         Grind_CarryRecordShift(side.layers[i].position_ticket, price - formula, true);`
- **Analysis:**
  1. **Where a passed resting exit rests and when it fills:**
     - **Long (`SELL_LIMIT`):** When the market has already risen past the new 6-pip `formula` (`formula <= ask + min_dist - 1e-12`), `Grind_CarryClampLongExit` clamps `price` to `ask + min_dist` (passive **above** the market, where `min_dist = MathMax(point, MathMax(stops_dist, freeze_dist))`). Because a `SELL_LIMIT` fills on `bid`, it fills on the next small rise when `bid` climbs by `spread + min_dist` to reach `ask + min_dist`.
     - **Short (`BUY_LIMIT`):** When the market has already fallen past the new 6-pip `formula` (`formula >= bid - min_dist + 1e-12`), `Grind_CarryClampShortExit` clamps `price` to `bid - min_dist` (passive **below** the market). Because a `BUY_LIMIT` fills on `ask`, it fills on the next small dip when `ask` falls by `spread + min_dist` to reach `bid - min_dist`.
  2. **Can a passed exit close at a loss?**
     - For any **unrolled** layer (`!Grind_VLHas(pos)`, so `eff == entry_price`), `formula = entry_price +/- 6.0 pips + accrued` is on the profit side of `entry_price`, and a market that has passed `formula` sits even further in profit (`ask + min_dist > formula > entry_price` for long; `bid - min_dist < formula < entry_price` for short). Thus an unrolled passed exit **never** closes at a loss; it closes in profit (`> 6 pips`). (Only if a layer was already rolled under `_t2` so its virtual level `eff` sits below/above `entry_price` does `eff +/- 6.0 pips` sit below/above the original `entry_price`, and even then clamping places the exit at a better price than `eff +/- 6.0 pips`, realising a smaller roll loss than the rolled target.)
  3. **Held middle exits (skipped at `3088`, placed later at `3494`), I6 / quarantine, and later carry passes:**
     - Held middle exits (`exit_order_ticket == 0`) are skipped by `Grind_RebuildExitsAtStartSide` and by I6 while held (`Grind_ReconLayerHasExitCoverage` is `false`). When later promoted to `rank == 0` or `rank == depth - 1`, `Grind_ExitQManageSide` runs the identical `Grind_ExitQClampPassive` + `Grind_CarryRecordShift(..., price - formula, true)` sequence.
     - On both startup rebuild and ExitQ promotion, `Grind_CarryRecordShift(pos, price - formula, true)` writes `GRIND_CARRY_SHIFT_<pos> = price - formula` and `GRIND_CARRY_RELEASE_<pos> = 1.0`. Because `GRIND_CARRY_RELEASE_<pos>` is set, `Grind_CarryShiftGetValidated` returns the full `shift = price - formula` without bound-deletion, and `Grind_ReconExitMatchesEntry` sees `expected == formula + (price - formula) == price == exit_target` (`diff == 0.0`), passing I6 both while resting and upon fill (`diff >= 0.0` long / `diff <= 0.0` short). Neither I6 nor quarantine is tripped.
     - A later carry pass (`Grind_CarryExitShiftLayer`) never reads `GRIND_CARRY_SHIFT_<pos>` as an input: it recomputes `work.formula_exit` from `Grind_EffectiveEntry` and `accrued_pips` from `POSITION_SWAP` + `pending_pips`, clamps `theoretical` against current `bid`/`ask`, and overwrites `GRIND_CARRY_SHIFT_<pos>` with the new `applied_shift`.

---

## 3. Also Check Items 5-8 (`prompts/argon_review_c_t2.md` s4)

### Item 5 -- The two `_t2` presets against their `_t1` twins and `check_c_t2.py`
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `ea/presets_c/eurusd_opt_c_t1.set:1` `InpMagic=22260201`
  - `ea/presets_c/eurusd_opt_c_t1.set:12` `InpMaxLayers=7`
  - `ea/presets_c/eurusd_opt_c_t1.set:35` `InpTelemetryInstance=GRIND_EURUSD_OPTC`
  - `ea/presets_c/eurusd_opt_c_t1.set:37` `InpConfigWarning=FLEET C two-arm t1 EURUSD OPT -: cap 7, add = exit 7.0, width 2.0, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53071896, wine-c)`
  - `ea/presets_c/eurusd_opt_c_t1.set:40` `TelemetryAPIKey=`
  - `ea/presets_c/eurusd_opt_c_t2.set:1` `InpMagic=22260201`
  - `ea/presets_c/eurusd_opt_c_t2.set:12` `InpMaxLayers=9`
  - `ea/presets_c/eurusd_opt_c_t2.set:35` `InpTelemetryInstance=GRIND_EURUSD_OPTC`
  - `ea/presets_c/eurusd_opt_c_t2.set:37` `InpConfigWarning=FLEET C two-arm t2 EURUSD OPT -: cap 9, add = exit 7.0, width 2.0, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53071896, wine-c)`
  - `ea/presets_c/eurusd_opt_c_t2.set:40` `TelemetryAPIKey=`
  - `ea/presets_c/audcad_opt_c_t1.set:1` `InpMagic=22260401`
  - `ea/presets_c/audcad_opt_c_t1.set:3` `InpWidthPips=1.5`
  - `ea/presets_c/audcad_opt_c_t1.set:4` `InpAddPips=6.0`
  - `ea/presets_c/audcad_opt_c_t1.set:5` `InpExitPips=6.0`
  - `ea/presets_c/audcad_opt_c_t1.set:6` `InpWidthPipsLong=-1.0`
  - `ea/presets_c/audcad_opt_c_t1.set:7` `InpWidthPipsShort=-1.0`
  - `ea/presets_c/audcad_opt_c_t1.set:8` `InpAddPipsLong=-1.0`
  - `ea/presets_c/audcad_opt_c_t1.set:9` `InpAddPipsShort=-1.0`
  - `ea/presets_c/audcad_opt_c_t1.set:10` `InpExitPipsLong=-1.0`
  - `ea/presets_c/audcad_opt_c_t1.set:11` `InpExitPipsShort=-1.0`
  - `ea/presets_c/audcad_opt_c_t1.set:12` `InpMaxLayers=7`
  - `ea/presets_c/audcad_opt_c_t1.set:14` `InpStrandedThreshPips=2.5`
  - `ea/presets_c/audcad_opt_c_t1.set:35` `InpTelemetryInstance=GRIND_AUDCAD_OPTC`
  - `ea/presets_c/audcad_opt_c_t1.set:37` `InpConfigWarning=FLEET C two-arm t1 AUDCAD OPT -: cap 7, add = exit 6.0, width 1.5, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53071896, wine-c)`
  - `ea/presets_c/audcad_opt_c_t1.set:40` `TelemetryAPIKey=`
  - `ea/presets_c/audcad_opt_c_t2.set:1` `InpMagic=22260401`
  - `ea/presets_c/audcad_opt_c_t2.set:3` `InpWidthPips=4.5`
  - `ea/presets_c/audcad_opt_c_t2.set:4` `InpAddPips=18.0`
  - `ea/presets_c/audcad_opt_c_t2.set:5` `InpExitPips=18.0`
  - `ea/presets_c/audcad_opt_c_t2.set:6` `InpWidthPipsLong=-1.0`
  - `ea/presets_c/audcad_opt_c_t2.set:7` `InpWidthPipsShort=-1.0`
  - `ea/presets_c/audcad_opt_c_t2.set:8` `InpAddPipsLong=-1.0`
  - `ea/presets_c/audcad_opt_c_t2.set:9` `InpAddPipsShort=-1.0`
  - `ea/presets_c/audcad_opt_c_t2.set:10` `InpExitPipsLong=-1.0`
  - `ea/presets_c/audcad_opt_c_t2.set:11` `InpExitPipsShort=-1.0`
  - `ea/presets_c/audcad_opt_c_t2.set:12` `InpMaxLayers=9`
  - `ea/presets_c/audcad_opt_c_t2.set:14` `InpStrandedThreshPips=5.5`
  - `ea/presets_c/audcad_opt_c_t2.set:35` `InpTelemetryInstance=GRIND_AUDCAD_OPTC`
  - `ea/presets_c/audcad_opt_c_t2.set:37` `InpConfigWarning=FLEET C two-arm t2 AUDCAD OPT -: cap 9, add = exit 18.0, width 4.5, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53071896, wine-c)`
  - `ea/presets_c/audcad_opt_c_t2.set:40` `TelemetryAPIKey=`
  - `ea/presets_e/audcad_opt_e_t3.set:3` `InpWidthPips=4.5`
  - `ea/presets_e/audcad_opt_e_t3.set:4` `InpAddPips=18.0`
  - `ea/presets_e/audcad_opt_e_t3.set:5` `InpExitPips=18.0`
  - `ea/presets_e/audcad_opt_e_t3.set:12` `InpMaxLayers=7`
  - `ea/presets_e/audcad_opt_e_t3.set:14` `InpStrandedThreshPips=5.5`
  - `ea/presets_e/audcad_opt_e_t3.set:35` `InpTelemetryInstance=GRIND_AUDCAD_OPTE`
  - `ea/presets_e/audcad_opt_e_t3.set:37` `InpConfigWarning=FLEET E two-arm t3 AUDCAD OPT sw11: cap 7, add = exit 18.0, width 4.5, deadband 2.0; lattice + reroll on, roll gate 0 (FTMO demo, new account, new Linux server)`
- **Analysis:** Across all 41 lines, `eurusd_opt_c_t2.set` differs from `eurusd_opt_c_t1.set` only in `InpMaxLayers` (`7` -> `9`) and `InpConfigWarning`. `audcad_opt_c_t2.set` differs from `audcad_opt_c_t1.set` only in `InpWidthPips` (`1.5` -> `4.5`), `InpAddPips` (`6.0` -> `18.0`), `InpExitPips` (`6.0` -> `18.0`), `InpMaxLayers` (`7` -> `9`), `InpStrandedThreshPips` (`2.5` -> `5.5`), and `InpConfigWarning`, and matches `audcad_opt_e_t3.set` on every line except `InpMaxLayers`, `InpTelemetryInstance`, and `InpConfigWarning`. `python research/opt_budget/check_c_t2.py` printed `EURUSD OPT t2: OK`, `AUDCAD OPT t2: OK`, `C t2 presets: ALL OK`.

### Item 6 -- Runbook s3 step 2's read-back list against the preset files
- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:68` `2. Drag **Navigator -> Expert Advisors -> fxmatrix -> fxgrind** (the Experts copy) onto the chart -> Inputs -> Load`
  - `docs/runbooks/twoarm-reload-c-t2.md:69` `   `<pair>_opt_c_t2.set` -> read back BEFORE OK: `InpMagic` (22260201 / 22260401), `InpTelemetryInstance``
  - `docs/runbooks/twoarm-reload-c-t2.md:70` `   (`GRIND_<PAIR>_OPTC`), width, add, exit (s0), the six per-side rows `-1.0`, **cap 9**, stranded (3.0 / 5.5),`
  - `docs/runbooks/twoarm-reload-c-t2.md:71` `   deadband 2.0, lattice and re-roll true, roll gate 0, auto-eject and breaker false, the warning (`FLEET C two-arm t2`
  - `docs/runbooks/twoarm-reload-c-t2.md:72` `   <PAIR> OPT -: cap 9 ...`), the key row not blank. Common: Algo Trading allowed. OK; note the UTC time.`
  - `ea/presets_c/eurusd_opt_c_t2.set:1` `InpMagic=22260201`
  - `ea/presets_c/eurusd_opt_c_t2.set:3` `InpWidthPips=2.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:4` `InpAddPips=7.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:5` `InpExitPips=7.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:6` `InpWidthPipsLong=-1.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:7` `InpWidthPipsShort=-1.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:8` `InpAddPipsLong=-1.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:9` `InpAddPipsShort=-1.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:10` `InpExitPipsLong=-1.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:11` `InpExitPipsShort=-1.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:12` `InpMaxLayers=9`
  - `ea/presets_c/eurusd_opt_c_t2.set:14` `InpStrandedThreshPips=3.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:15` `InpDeadbandPips=2.0`
  - `ea/presets_c/eurusd_opt_c_t2.set:18` `InpAutoEject=false`
  - `ea/presets_c/eurusd_opt_c_t2.set:21` `InpVirtualLattice=true`
  - `ea/presets_c/eurusd_opt_c_t2.set:22` `InpLatticeReroll=true`
  - `ea/presets_c/eurusd_opt_c_t2.set:23` `InpRollGateOpposite=0`
  - `ea/presets_c/eurusd_opt_c_t2.set:24` `InpBreakerEnable=false`
  - `ea/presets_c/eurusd_opt_c_t2.set:35` `InpTelemetryInstance=GRIND_EURUSD_OPTC`
  - `ea/presets_c/eurusd_opt_c_t2.set:37` `InpConfigWarning=FLEET C two-arm t2 EURUSD OPT -: cap 9, add = exit 7.0, width 2.0, deadband 2.0; lattice + reroll on, roll gate 0 (IC Markets demo 53071896, wine-c)`
  - `ea/presets_c/eurusd_opt_c_t2.set:40` `TelemetryAPIKey=`
- **Analysis:** Every input and value in s3 step 2's read-back list matches `eurusd_opt_c_t2.set` and `audcad_opt_c_t2.set` and s0.

### Item 7 -- Runbook s5 (rollback), three parts: (a), (b), (c)
- **Verdict:**
  - **7(a) Cap 9 -> 7 I7 check and depth condition:** **DEFECT** (I7 itself fails at 8 or 9 layers as stated, but s5's rule "roll back only when both sides hold 7 or fewer" leaves a depth-7 side's resting `|L07|ENT` / `|L08|ENT` order active under cap 7, which the cap-7 EA neither cancels nor reprices and which halts the chart on `I7_*_DEPTH` when it fills)
  - **7(b) Stored virtual level (`GRIND_VL_<ticket>`) and exit label (`GRIND_GEO_EXIT_<magic>_L/_S`) on rollback from 18 to 6:** **CONFIRMED** (no check compares a stored VL against `add_pips`, and `Grind_GeoExitChanged` triggers the startup exit rebuild and label overwrite without halting or quarantining)
  - **7(c) Runbook s5 worked example (`0.9800` long, exit `0.9818`, `bid = 0.9810`, `t1` target `0.9806`):** **CONFIRMED**
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:91` `Remove, then Attach with `<pair>_opt_c_t1.set` (staged 21 Oct). **Cap 9 -> 7 trips I7 on a side holding 8 or 9`
  - `docs/runbooks/twoarm-reload-c-t2.md:92` `layers (K1): roll back only when both sides hold 7 or fewer** (Trade tab), or flatten the chart first (twoarm-build-c`
  - `docs/runbooks/twoarm-reload-c-t2.md:93` `s3 steps 1-4, keep the chart). Flattening is the alternative to I7 only.`
  - `docs/runbooks/twoarm-reload-c-t2.md:94` ``
  - `docs/runbooks/twoarm-reload-c-t2.md:95` `**AUDCAD's rollback moves every exit 12 pips CLOSER (18 -> 6), unlike the reload.** A resting exit whose t1 target the`
  - `docs/runbooks/twoarm-reload-c-t2.md:96` `market has already passed is rebuilt clamped passive (`grind_engine.mqh` 3118, the offset kept as a carry shift at`
  - `docs/runbooks/twoarm-reload-c-t2.md:97` `3130; for a long, the clamp is ask + the minimum distance, `grind_carry.mqh` 453-455), so it rests on the PROFIT side`
  - `docs/runbooks/twoarm-reload-c-t2.md:98` `and fills as soon as the bid reaches it; a held middle exit (skipped by the rebuild, 3088) is placed by ExitQ the same`
  - `docs/runbooks/twoarm-reload-c-t2.md:99` `way when its rank comes (3494). Expect a burst of closes in profit on the rollback, not a loss (Argon Q5 checks this).`
  - `docs/runbooks/twoarm-reload-c-t2.md:100` `Example (long): a layer at 0.9800 with its exit at 0.9818 and the bid at 0.9810; at t1 its target is 0.9806, passed,`
  - `docs/runbooks/twoarm-reload-c-t2.md:101` `so the exit goes to ask + the minimum distance and closes the layer about 10 pips up on the next small rise.`
  - `docs/runbooks/twoarm-build-c.md:118` `**The cap rule (D's s4, I7):** attach only when BOTH sides hold 6 layers or fewer, counted in the **Trade`
  - `docs/runbooks/twoarm-build-c.md:119` `tab** (positions on that symbol with comment `GRIND|OPT|L|` and `GRIND|OPT|S|`) immediately before the`
  - `docs/runbooks/twoarm-build-c.md:120` `Remove; pipshed lags up to 60 s. A side at 7 rests its `|L07|ENT` under cap 8, which the cap-7 EA neither`
  - `docs/runbooks/twoarm-build-c.md:121` `cancels nor re-uses (`grind_engine.mqh` 2492-2528): if it fills, the side holds 8 and halts on I7. A side at 7`
  - `docs/runbooks/twoarm-build-c.md:122` `or 8: wait, or flatten the chart (s3 steps 1-4, KEEP the chart) and attach it empty.`
  - `ea/grind_recon.mqh:1083` `                  offending_comment_out = tickets[i].comment;`
  - `ea/grind_recon.mqh:1087` `            }`
  - `ea/grind_engine.mqh:2492` `   const int n = Grind_SideDepth(side);`
  - `ea/grind_engine.mqh:2493` `   const int required_index = Grind_SideNextIndex(side);`
  - `ea/grind_engine.mqh:2494` ``
  - `ea/grind_engine.mqh:2495` `   if(side.add_pending_ticket != 0) {`
  - `ea/grind_engine.mqh:2496` `      if(!Grind_SelectOurOrder(side.add_pending_ticket, magic)) {`
  - `ea/grind_engine.mqh:2497` `         if(Grind_SelectOurPosition(side.add_pending_ticket, magic))`
  - `ea/grind_engine.mqh:2498` `            return;`
  - `ea/grind_engine.mqh:2499` `         side.add_pending_ticket = 0;`
  - `ea/grind_engine.mqh:2500` `      } else {`
  - `ea/grind_engine.mqh:2501` `         const string resting_comment = Grind_OrderGetComment(side.add_pending_ticket);`
  - `ea/grind_engine.mqh:2502` `         string c_slot, c_side, c_role;`
  - `ea/grind_engine.mqh:2503` `         int parsed_layer = -1;`
  - `ea/grind_engine.mqh:2504` `         const bool label_ok = GrindCommentParse(resting_comment, c_slot, c_side,`
  - `ea/grind_engine.mqh:2505` `                                                 parsed_layer, c_role)`
  - `ea/grind_engine.mqh:2506` `                               && parsed_layer == required_index;`
  - `ea/grind_engine.mqh:2507` `         if(!label_ok) {`
  - `ea/grind_engine.mqh:2508` `            Grind_Adr152ClearDueForSide(is_long);`
  - `ea/grind_engine.mqh:2509` `            if(g_grind_recon_verbose) {`
  - `ea/grind_engine.mqh:2510` `               string label_txt = "UNPARSEABLE";`
  - `ea/grind_engine.mqh:2511` `               if(GrindCommentParse(resting_comment, c_slot, c_side, parsed_layer, c_role))`
  - `ea/grind_engine.mqh:2512` `                  label_txt = StringFormat("L%02d", parsed_layer);`
  - `ea/grind_engine.mqh:2513` `               Print(Grind_LogTag(), "INFO: grind reconcile remove stale add ticket=",`
  - `ea/grind_engine.mqh:2514` `                     side.add_pending_ticket,`
  - `ea/grind_engine.mqh:2515` `                     " label=", label_txt,`
  - `ea/grind_engine.mqh:2516` `                     " depth=", required_index);`
  - `ea/grind_engine.mqh:2517` `            }`
  - `ea/grind_engine.mqh:2518` `            if(Grind_CancelPendingOrder(side.add_pending_ticket, magic))`
  - `ea/grind_engine.mqh:2519` `               side.add_pending_ticket = 0;`
  - `ea/grind_engine.mqh:2520` `            return;`
  - `ea/grind_engine.mqh:2521` `         }`
  - `ea/grind_engine.mqh:2522` `      }`
  - `ea/grind_engine.mqh:2523` `   }`
  - `ea/grind_engine.mqh:2524` ``
  - `ea/grind_engine.mqh:2525` `   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers)) {`
  - `ea/grind_engine.mqh:2526` `      Grind_Adr152ClearDueForSide(is_long);`
  - `ea/grind_engine.mqh:2527` `      return;`
  - `ea/grind_engine.mqh:2528` `   }`
  - `ea/grind_carry.mqh:591` `   if(!GlobalVariableCheck(name))`
  - `ea/grind_carry.mqh:595` ``
  - `ea/grind_carry.mqh:596` `//+------------------------------------------------------------------+`
  - `ea/grind_carry.mqh:597` `bool Grind_VLHas(const ulong position_ticket)`
  - `ea/grind_carry.mqh:606` `{`
  - `ea/grind_carry.mqh:608` `   Grind_GvMarkDirty();`
  - `ea/grind_recon.mqh:537` `         if(tolerate_exit_price_long && !long_exit_filled)`
  - `ea/grind_recon.mqh:538` `            continue;`
  - `ea/grind_recon.mqh:569` `         if(tolerate_exit_price_short && !short_exit_filled)`
  - `ea/grind_recon.mqh:570` `            continue;`
  - `ea/grind_recon.mqh:1404` `   g_grind_rebuild_long = Grind_GeoExitChanged(g_grind_recon_magic, true, g_grind_recon_exit_pips);`
  - `ea/grind_recon.mqh:1405` `   g_grind_rebuild_short = Grind_GeoExitChanged(g_grind_recon_magic, false,`
  - `ea/grind_recon.mqh:1420` `                                                g_grind_rebuild_long,`
  - `ea/grind_recon.mqh:1421` `                                                g_grind_rebuild_short);`
- **Analysis:**
  - **7(a) (DEFECT):** `Grind_ReconCheckInvariants` checks `long_count > max_layers` and `short_count > max_layers`, so "Cap 9 -> 7 trips I7 on a side holding 8 or 9 layers" is true at `OnInit`. However, under cap 9 (`_t2`), a side holding **7 layers** (`n = 7 < 9`, e.g. `L00..L06` with `required_index = 7`) places and rests its 8th entry order `|L07|ENT` (or `|L08|ENT` if `L07` is already held and an earlier layer closed). `OnDeinit` does not cancel orders. When `_t1` (`InpMaxLayers=7`) is attached while that side holds 7 layers, `Grind_RebuildBookFromTicketsInner` adopts that order as `add_pending_ticket`, and `Grind_EnsureAddNext` sees `parsed_layer == required_index` (`label_ok = true`) and then returns at `!Grind_CanPlaceEntryLayer(7, 7)` (`7 < 7` is false) before cancelling or repricing the order. When that stranded `|L07|ENT` (or `|L08|ENT`) fills, the side reaches 8 layers and halts on `I7_LONG_DEPTH` / `I7_SHORT_DEPTH`.
  - **Smallest change to `docs/runbooks/twoarm-reload-c-t2.md` (lines 91-93) that fixes 7(a):**
    ```markdown
    Remove, then Attach with `<pair>_opt_c_t1.set` (staged 21 Oct). **Cap 9 -> 7 trips I7 on a side holding 8 or 9
    layers (K1), and a side at 7 under cap 9 rests `|L07|ENT` (or `|L08|ENT`), which the cap-7 EA neither cancels nor
    reprices (`grind_engine.mqh` 2492-2528): roll back only when both sides hold 6 or fewer** (Trade tab; if a side is at
    7, delete its resting `|L07|ENT` / `|L08|ENT` between Remove and Attach, and confirm none rests after attach), or
    flatten the chart first (twoarm-build-c s3 steps 1-4, keep the chart). Flattening is the alternative to I7 only.
    ```
  - **7(b) (CONFIRMED):** `Grind_VLGet` and `Grind_EffectiveEntry` read `GRIND_VL_<ticket>` without comparing it to `add_pips`, and no invariant in `Grind_ReconCheckInvariants` checks layer or VL spacing against `add_pips`. For `GRIND_GEO_EXIT_22260401_L/_S` (`18.0` -> `6.0`), `Grind_ReconstructState` sets `g_grind_rebuild_long = true` and `g_grind_rebuild_short = true`, which sets `tolerate_exit_price_long = true` and `tolerate_exit_price_short = true` so I6 skips resting exits during `OnInit` reconstruction; `Grind_RebuildExitsAtStart` then moves each resting exit to `Grind_ExitQFormulaTarget(entry, 6.0, _Point, is_long, pos)` (which computes `eff +/- 6.0 pips + accrued + eject_off` from the stored VL `eff`) and `Grind_GeoExitWriteLabels` writes `6.0`. Neither the stored VL nor the stored exit label trips an invariant or quarantine.
  - **7(c) (CONFIRMED):** As traced in Q5, for a long at `0.9800` with old exit `0.9818` and `bid = 0.9810`, the `_t1` formula target `0.9806` satisfies `0.9806 <= ask + min_dist - 1e-12`, so `Grind_CarryClampLongExit` places the `SELL_LIMIT` at `ask + min_dist`, `Grind_CarryRecordShift` records `price - formula` with `clamped = true` so I6 passes, and the layer closes ~10 pips in profit on the next small rise when `bid` reaches `ask + min_dist`.

### Item 8 -- Anything else in the runbook that would hurt a live chart
- **Verdict:** **NOT A DEFECT** (apart from the s5 rollback depth-7 defect in Item 7(a) above).
- **Quotes:**
  - `docs/runbooks/twoarm-reload-c-t2.md:22` `**One worked example (AUDCAD OPT long, prices):** layers at 0.9800 and 0.9794 (6 apart), exits resting at 0.9806 and`
  - `docs/runbooks/twoarm-reload-c-t2.md:23` `0.9800, the next add at 0.9788. After the reload the start-up rebuilds the exits to 0.9818 and 0.9812 (entry + 18) and`
  - `docs/runbooks/twoarm-reload-c-t2.md:24` `moves the next add to 0.9776 (deepest - 18). Nothing fills at once: the exits move AWAY from the market (1 Oct's`
  - `docs/runbooks/twoarm-reload-c-t2.md:25` `rebuild moved them closer).`
  - `docs/runbooks/twoarm-reload-c-t2.md:53` `**2.3 Fingerprint and checker** (expected `7ecd5b582851`, then 2, then `C t2 presets: ALL OK`):`
  - `docs/runbooks/twoarm-reload-c-t2.md:54` ``
  - `docs/runbooks/twoarm-reload-c-t2.md:55` `    (cd /home/khalid/fxmatrix-repo && for f in ea/presets_c/*_t2.set; do sha256sum $f | cut -c1-64; done | sha256sum | cut -c1-12; ls ea/presets_c/*_t2.set | wc -l; python3 research/opt_budget/check_c_t2.py | tail -1)`
  - `docs/runbooks/twoarm-reload-c-t2.md:56` ``
  - `docs/runbooks/twoarm-reload-c-t2.md:57` `**2.4 Stage with the key** (twoarm-build-c s2.4's command with `*_t1.set` replaced by `*_t2.set` in BOTH loops;`
  - `docs/runbooks/twoarm-reload-c-t2.md:58` `expected 2 lines `SAME_EXCEPT_KEY key_len=43`).`
  - `docs/runbooks/twoarm-reload-c-t2.md:59` ``
  - `docs/runbooks/twoarm-reload-c-t2.md:60` `No compile: no EA code changes; the charts keep the Experts `.ex5` of 21 Oct (K6).`
  - `docs/runbooks/twoarm-reload-c-t2.md:80` `6. **After the pilot only (EURUSD; PROPOSED, the operator to confirm): watch about 5 minutes before AUDCAD:** no new`
  - `docs/runbooks/twoarm-reload-c-t2.md:81` `   `WARN` or halt in the Experts log for EURUSD, its heartbeat posting on pipshed, nothing on C's other five charts`
  - `docs/runbooks/twoarm-reload-c-t2.md:82` `   changed. No fill is waited for. Then AUDCAD OPT from step 1.`
- **Analysis:** The worked example in s0, the staging and key-injection steps in s2.3-s2.4, the pilot-first Remove-then-Attach sequence and 5-minute pilot watch in s3, and the post-attach checks in s3-s4 are all accurate and safe for the live charts.

---

**GO WITH CHANGES** (1 change: in `docs/runbooks/twoarm-reload-c-t2.md` s5 lines 91-93, change the cap-cut rollback condition from "7 or fewer" to "6 or fewer" layers in the Trade tab -- or delete a depth-7 side's resting `|L07|ENT` / `|L08|ENT` order between Remove and Attach and confirm none rests after attach -- because `Grind_EnsureAddNext` keeps a matching `|L07|ENT` / `|L08|ENT` at depth 7 under cap 7, which would fill to 8 layers and halt on `I7_*_DEPTH`).
Line count: 678
