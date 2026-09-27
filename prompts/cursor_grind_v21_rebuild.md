This message has a line count at the bottom

# CURSOR PROMPT -- GRIND V2.1: REBUILD AT START (ADR-163, BACKLOG C69)

Workspace `D:\fxmatrix` (NOT pipshed). From `main` at `b5f31ad` or a
docs-only descendant (EA code == `907b1c7`, suite 2168/2168). Branch
`grind-v21-rebuild`. Record: `docs/architecture/ADR-163-rebuild-at-start.md`
(read s4, s9, s10), backlog C69, DeepSeek `a19261d` T-7. Gemini rules on
this prompt BEFORE you start; his rulings are pasted at the bottom. Where
a ruling changes a default below, follow the ruling. If a ruling is
ambiguous, STOP and report.

Nothing here deploys. What changes at an ordinary restart: nothing,
except that a resting add clamped at placement may be modified once
(item 5 below). What changes when a side's EXIT input differs
from the exit its book was last priced for: its resting exits are
repriced at init instead of halting on I6.

## AUDIT TRAIL (read in source at `main` `b5f31ad`, by Claude)

Definition lines and call lines are given separately.

| # | finding | where | status |
|---|---|---|---|
| A1 | I6 at init and every tick: `Grind_ReconCheckInvariants` (defined `grind_recon.mqh` 462; last parameter `exit_pips_short` at 473). Long I6 test at 524 (`if(!Grind_ReconExitMatchesEntry(`), its failure return at 529; short test at 554, failure return at 559. `long_exit_filled` / `short_exit_filled` select the `*_FILL_ADVERSE` reason | recon | verified |
| A2 | Callers: `Grind_RebuildBookFromTicketsInner` (defined 842; last parameter 854) calls it at 1106-1109; wrapper `Grind_RebuildBookFromTickets` (defined 1162; last parameter 1173) calls the inner one at 1174-1182; `Grind_CheckBookInvariants` (defined 1237) calls the wrapper at 1245-1253 (every tick, strict); `Grind_ReconstructState` (defined 1265) calls it at 1276-1288 with `tolerate_exit_shortfall` = `true` | recon | verified |
| A3 | `OnInit` (`fxgrind.mq5`): `Grind_ReconstructState()` at 252; on success `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots)` at 267 (inside the else-branch that ends at 268); `Grind_CarryPruneShiftGvs(InpMagic)` at 270; `Print("GRIND_GEOMETRY ...` at 337 | EA | verified |
| A4 | The placement rule to copy: `Grind_ExitQManageSide` (defined `grind_engine.mqh` 3032) places at `Grind_ExitQFormulaTarget` (exitq 241: `ExitPrice(eff, exit) + accrued + eject offset`), clamps with `Grind_ExitQClampPassive` (exitq 258), then `if(clamped || MathAbs(price - formula) > _Point * 0.5)` records `Grind_CarryRecordShift(pos, price - formula, true)`, else `Grind_CarryShiftDelete(pos)` (engine ~3083-3087) | engine, exitq | verified |
| A5 | Helpers: `Grind_ModifyPendingPrice(ticket, price, magic)` (engine 1277) returns false on failure; `Grind_OrderGetPriceOpen` (engine 349); `Grind_EjectIsEjected` (carry 576: offset GV != 0); `Grind_EjectOffsetSet` (carry 562); `Grind_VLHas` (carry 597); `Grind_EffectiveEntry` (carry 619: the VL when set); `Grind_CarryAccruedGet` (carry 670); `Grind_CarryShiftGetForRecon` (carry 747; returns the raw shift when a release marker exists or the layer is ejected); `Grind_GvMarkDirty` (carry 489; flushed within 1 s, C25) | carry, engine | verified |
| A6 | Include order: `grind_recon.mqh` includes `grind_exitq.mqh` at 31, which includes `grind_carry.mqh` (exitq 10); so carry functions are visible to `Grind_ReconstructState` (recon 1265). New GV helpers go in `grind_carry.mqh` | includes | verified |
| A7 | Resting add: `Grind_EnsureAddNext` (defined engine 2342). After the marketable checks (last one at 2417) the resting-add block starts at 2420; its deadband test is at 2422 (`if(Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))`); the placement call for a side with no resting add is at 2434. `Grind_PriceWithinDeadband` (pure 140) is a strict `<` on `Grind_DeadbandPrice(pips)` | engine, pure | verified |
| A8 | The suite deletes carry GVs by prefix in `Grind_TestClearCarryState` (`fxgrind_tests.mq5` 2447: `GRIND_CARRY_SHIFT_`, `GRIND_CARRY_ACCRUED_`, release, `GRIND_EJECT_`, `GRIND_VL_`). A new prefix is NOT covered: tests delete their own labels | tests | verified |
| A9 | Test seams: order records (`Grind_OrderTestUpsert`, modify updates the record's price, `g_grind_order_test_modify_calls`, `g_grind_order_test_send_ok`), market (`Grind_MarketTestSeed(bid, ask, stops, freeze)`), `Grind_TestInitLayerScratch`, `Adr151_TestSetupLongLayer`, `Adr151_TestSeedSlotSeams`, `Adr152_TestPrepareIsolation`, `Adr152_TestSeedSlotSeams`, `Adr152_TestResetAll`, `Grind_EngineConfigureAdr152`, `Grind_TestResetSideState`, `Grind_CarryTestReset`, `Adr151_TestResetAll` | tests | verified |
| A10 | DeepSeek `a19261d` T-7: `Grind_ServiceDueAddFlags` (short add of the ADR-152 due path, live in every preset) and `Grind_TryRecenterOppositeL0` (short L0 width) have no test; both read correctly in source | DeepSeek | verified |

## WHAT V2.1 IS

1. **Exit labels.** One GV per instance and side,
   `GRIND_GEO_EXIT_<magic>_L` / `_S`: the exit (pips) that side's book was
   last priced for. It GATES the rebuild; it never prices (operator,
   ADR-163 s10). Absent label = strict init, as today.
2. **Tolerant recon at init, per side, only when the label differs.**
   `Grind_ReconstructState` sets `g_grind_rebuild_long` /
   `g_grind_rebuild_short` = "label present and different from that
   side's current exit", then passes them to the rebuild. For a flagged
   side, an I6 PRICE mismatch on a RESTING exit order does not fail (the
   layer is repriced in item 3); a FILLED exit (`*_exit_filled`) stays
   strict; the other side stays strict; `Grind_CheckBookInvariants`
   (every tick) never tolerates.
3. **`Grind_RebuildExitsAtStart(magic)`**, called in `OnInit` right after
   `Grind_RetryMissingExits` (267). For each flagged side, each layer with
   a resting exit order and no exit position:
   - EJECTED (`Grind_EjectIsEjected(pos)` and not `Grind_VLHas(pos)`):
     keep the order; `offset = resting - (Grind_ExitPrice(
     Grind_EffectiveEntry(entry, pos), side exit, _Point, dir) +
     Grind_CarryAccruedGet(pos) + Grind_CarryShiftGetForRecon(pos))`;
     `Grind_EjectOffsetSet(pos, offset)`; `exit_target = resting`. No
     broker call (operator R3).
   - otherwise: `target = Grind_ExitQFormulaTarget(entry, side exit,
     _Point, is_long, pos)`; `price = target`; `clamped =
     Grind_ExitQClampPassive(is_long, target, price)`; if
     `MathAbs(resting - price) > 0.5 * _Point`: `Grind_ModifyPendingPrice`;
     on FAILURE return false at once (no further layers). Then (modified
     or not) `exit_target = price` and the shift exactly as A4 (record
     with release marker if clamped or off-formula, else delete).
   - Held layers (no order) and closing layers (exit position) are
     skipped: the queue prices a held exit from the current exit when it
     is released.
   - Markers: `Grind_ArchiveMarker("INFO", "EXIT_REBUILT", side letter,
     pos, {"side","old","new","clamped","ejected_kept"})` per layer
     touched; `Grind_ArchiveMarker("INFO", "REBUILD_SUMMARY", side, 0,
     {"side","repriced","ejected_kept","clamped"})` per flagged side.
   Returns true when every flagged side is done (true at once when no
   side is flagged).
4. **`OnInit` wiring.** If the rebuild returns false: halt in place
   (`g_grind_halted = true; g_grind_halt_reason = "REBUILD_EXIT_FAILED";`
   `Grind_TelemetryCritical(g_grind_telemetry_instance,
   "REBUILD_EXIT_FAILED", "")`; `Grind_CancelOwnEntryOrders(InpMagic,
   InpSlot)`; `Print("CRITICAL: REBUILD_EXIT_FAILED -- halted in place")`);
   labels NOT written. If true: `Grind_GeoExitWriteLabels(InpMagic,
   g_geo_exit_long, g_geo_exit_short)` and set the two one-shot add flags
   (item 5). When `Grind_ReconstructState` fails, neither happens.
   Always print, after `GRIND_GEOMETRY`: `GRIND_REBUILD long=<true|false>
   short=<true|false>` (the flags of item 2).
5. **One-shot resting add (operator R2).** Globals
   `g_grind_start_add_reprice_long` / `_short`, set true by item 4. In
   `Grind_EnsureAddNext`, directly after the last marketable check
   (2417) and before 2420: read the side's flag into `one_shot`, then
   clear it; at 2422 use `one_shot ? 0.05 : deadband_pips` (0.05 pip =
   half a point: an unchanged add is not modified). A flag is cleared only
   when execution reaches that point (early returns keep it).
6. **NOT in v2.1:** a one-shot for a resting L0 (see GR-S1); a ledger
   read of carry at start (ADR-163 D6); `REBUILD_WITHOUT_CHANGE` (dropped,
   ADR-163 s9).

## COMMIT 1 -- STUBS AND TESTS

**Production changes that compile and change NO behaviour:**

- `ea/grind_carry.mqh`, after `Grind_VLSet` (605): REAL
  `string Grind_GeoExitGvName(const ulong magic, const bool is_long)`
  returning `"GRIND_GEO_EXIT_" + IntegerToString((long)magic) + (is_long ?
  "_L" : "_S")`; STUBS: `bool Grind_GeoExitGet(const ulong magic, const
  bool is_long, double &out)` (out = 0.0, return false); `void
  Grind_GeoExitSet(const ulong magic, const bool is_long, const double
  exit_pips)` (empty); `bool Grind_GeoExitChanged(const ulong magic, const
  bool is_long, const double current_exit)` (return false); `void
  Grind_GeoExitWriteLabels(const ulong magic, const double exit_long,
  const double exit_short)` (empty).
- `ea/grind_recon.mqh`: after line 18, `bool g_grind_rebuild_long =
  false;` and `bool g_grind_rebuild_short = false;`. New LAST parameters
  `const bool tolerate_exit_price_long = false, const bool
  tolerate_exit_price_short = false` (after `exit_pips_short`), IGNORED,
  on `Grind_ReconCheckInvariants`, `Grind_RebuildBookFromTicketsInner`,
  `Grind_RebuildBookFromTickets`.
- `ea/grind_engine.mqh`: after line 26, `bool
  g_grind_start_add_reprice_long = false;` and `bool
  g_grind_start_add_reprice_short = false;`. STUB `bool
  Grind_RebuildExitsAtStart(const ulong magic) { return true; }` directly
  before `Grind_RetryMissingExits` (defined 2759).
- Do NOT touch `fxgrind.mq5`, `Grind_EnsureAddNext` or
  `Grind_ReconstructState` in commit 1.

**Tests: new file `ea/fxgrind_tests_rb.mqh`**, included directly after
`#include "fxgrind_tests_gv.mqh"`; register every test in `OnStart`
directly after `Test_GV13_EjectShortPerSide();`, in table order. NO
forward declarations. Magic `22260101UL` (`RB_MAGIC`), point 0.00001.

Helpers in the file:
- `RB_Reset()`: `Adr151_TestResetAll(); Grind_OrderTestReset();
  Grind_TestResetSideState(); Grind_CarryTestReset();
  Grind_MarketTestReset(); GlobalVariableDel(Grind_GeoExitGvName(RB_MAGIC,
  true)); GlobalVariableDel(Grind_GeoExitGvName(RB_MAGIC, false));
  g_grind_rebuild_long = false; g_grind_rebuild_short = false;
  g_grind_start_add_reprice_long = false; g_grind_start_add_reprice_short
  = false; g_grind_recon_exit_pips_short = 0.0;` Every test starts and
  ends with `RB_Reset()` and saves/restores `g_grind_recon_exit_pips` and
  `g_grind_engine_add_pips` as the GV tests do.
- `RB_Layer(GrindSideState &side, int i, int index, double entry, ulong
  pos, ulong ext, double ext_price, bool is_long)`: sets every field of
  `side.layers[i]` (ArrayResize first; `exit_position_ticket` 0;
  `exit_target` = `ext_price` when `ext != 0`, else 0.0) and, when `ext !=
  0`, upserts order `ext` (magic `RB_MAGIC`, comment
  `GrindCommentBuild("OPT", is_long ? "L" : "S", index, "EXT")`, price
  `ext_price`, `ORDER_TYPE_SELL_LIMIT` for long, `BUY_LIMIT` for short).
- "Book L3" = `g_grind_order_test_active = true;` market 1.20000/1.20010
  (stops 0, freeze 0); long L0 entry 1.20500 pos 7001 ext 8001 at 1.20600;
  L1 entry 1.20400 pos 7002 no ext (held); L2 entry 1.20300 pos 7003 ext
  8003 at 1.20400 (exits at the OLD exit 10).
- "Book S3" = the short mirror: market 1.20000/1.20010; S0 entry 1.19500
  pos 7101 ext 8101 at 1.19400; S1 1.19600 pos 7102 held; S2 1.19700 pos
  7103 ext 8103 at 1.19600.
- `RB_I6(entry, ticket_price, exit, is_long, pos)` =
  `Grind_ReconExitMatchesEntry(entry, ticket_price, exit, 0.00001,
  is_long, Grind_CarryShiftGetForRecon(pos), false, pos)`.

| test | setup and calls | assertion (name: expected) | commit 1 |
|---|---|---|---|
| RB1_LongRebuild | Book L3; `g_grind_recon_exit_pips = 7.0; g_grind_rebuild_long = true;` `ok = Grind_RebuildExitsAtStart(RB_MAGIC)` | "RB1 ok": ok | PASS |
| | | "RB1 L0 price": price of 8001 = 1.20570 | FAIL |
| | | "RB1 L2 price": price of 8003 = 1.20370 | FAIL |
| | | "RB1 two modifies": `g_grind_order_test_modify_calls == 2` | FAIL |
| | | "RB1 L0 target": `layers[0].exit_target` = 1.20570 | FAIL |
| | | "RB1 held untouched": `layers[1].exit_order_ticket == 0` | PASS |
| | | "RB1 I6 at 7": `RB_I6(1.20500, price of 8001, 7.0, true, 7001)` | FAIL |
| | call the rebuild again | "RB1 second run no modify": modify calls still 2 | FAIL |
| RB2_ShortRebuild | Book S3; `g_grind_recon_exit_pips = 10.0; g_grind_recon_exit_pips_short = 7.0; g_grind_rebuild_short = true;` rebuild | "RB2 S0 price": 8101 = 1.19430 | FAIL |
| | | "RB2 S2 price": 8103 = 1.19630 | FAIL |
| | | "RB2 two modifies": modify calls == 2 | FAIL |
| | | "RB2 I6 at 7": `RB_I6(1.19500, price of 8101, 7.0, false, 7101)` | FAIL |
| RB3_EjectedKeepsPrice | market 1.20000/1.20010; long L0 entry 1.20500 pos 7001 ext 8001 at 1.20011, `Grind_EjectOffsetSet(7001, -0.00589)`; L1 entry 1.20400 pos 7002 ext 8002 at 1.20500; exit 7, long flagged; rebuild | "RB3 ok": ok | PASS |
| | | "RB3 eject order kept": 8001 = 1.20011 | PASS |
| | | "RB3 offset re-derived": `Grind_EjectOffsetGet(7001)` = -0.00559 | FAIL |
| | | "RB3 L1 price": 8002 = 1.20470 | FAIL |
| | | "RB3 one modify": modify calls == 1 | FAIL |
| | | "RB3 I6 at 7": `RB_I6(1.20500, 1.20011, 7.0, true, 7001)` | FAIL |
| RB4_RolledFromVL | market 1.19500/1.19510; L0 entry 1.20500 pos 7001 ext 8001 at 1.20000, `Grind_VLSet(7001, 1.19900)`; L1 entry 1.20400 pos 7002 ext 8002 at 1.20500; exit 7, long flagged; rebuild | "RB4 rolled price": 8001 = 1.19970 | FAIL |
| | | "RB4 L1 price": 8002 = 1.20470 | FAIL |
| | | "RB4 I6 at 7": `RB_I6(1.20500, price of 8001, 7.0, true, 7001)` | FAIL |
| RB5_AccruedKept | market 1.20000/1.20010; one long layer entry 1.20500 pos 7001 ext 8001 at 1.20612; `Grind_CarryAccruedSet(7001, 0.00012)`; exit 7, long flagged; rebuild | "RB5 price": 8001 = 1.20582 | FAIL |
| | | "RB5 accrued unchanged": `Grind_CarryAccruedGet(7001)` = 0.00012 | PASS |
| RB6_ClampRecordsShift | market 1.20060/1.20070; one long layer entry 1.20000 pos 7001 ext 8001 at 1.20100; exit 5, long flagged; rebuild | "RB6 clamped price": 8001 = 1.20071 | FAIL |
| | | "RB6 shift": `Grind_CarryShiftGet(7001)` = 0.00021 | FAIL |
| | | "RB6 release marker": `GlobalVariableCheck(Grind_CarryReleaseGvNameLocal(7001))` | FAIL |
| | | "RB6 I6 at 5": `RB_I6(1.20000, 1.20071, 5.0, true, 7001)` | FAIL |
| RB7_UnflaggedNoop | Book L3; exit 7; flags false; rebuild | "RB7 no modify": modify calls == 0 | PASS |
| RB8_FailClosed | Book L3; exit 7, long flagged; `g_grind_order_test_send_ok = false`; `ok = rebuild` | "RB8 fails closed": `!ok` | FAIL |
| | | "RB8 L0 untouched": 8001 = 1.20600 | PASS |
| | `g_grind_order_test_send_ok = true`; rebuild again | "RB8 retry moves L0": 8001 = 1.20570 | FAIL |
| RB10_ReconTolerance | scratch long `(0, 1.20000, 7001)`, `has_exit_order = true`, `exit_order_ticket = 8001`, `exit_target = 1.20100`; empty short; ranks {0}; exit 7.0, point 0.00001, max 8. (a) `Grind_ReconCheckInvariants(l, 1, lr, s, 0, sr, 7.0, point, 8, reason)` | "RB10 strict fails": false | PASS |
| | | "RB10 strict reason": `I6_LONG_EXIT` | PASS |
| | (b) same plus `false, 0.0, true, false` | "RB10 long tolerant ok": true | FAIL |
| | (c) same plus `false, 0.0, false, true` | "RB10 short flag keeps long strict": false | PASS |
| | | "RB10 short flag reason": `I6_LONG_EXIT` | PASS |
| | (d) `has_exit_order = false; has_exit_position = true; exit_target = 1.20060;` plus `false, 0.0, true, false` | "RB10 filled adverse strict": false | PASS |
| | | "RB10 filled reason": `I6_LONG_EXIT_FILL_ADVERSE` | PASS |
| RB11_Labels | labels deleted | "RB11 absent unchanged": `!Grind_GeoExitChanged(RB_MAGIC, true, 7.0)` | PASS |
| | `Grind_GeoExitSet(RB_MAGIC, true, 10.0)` | "RB11 differs changed": `Grind_GeoExitChanged(RB_MAGIC, true, 7.0)` | FAIL |
| | | "RB11 equal unchanged": `!Grind_GeoExitChanged(RB_MAGIC, true, 10.0)` | PASS |
| | | "RB11 short independent": `!Grind_GeoExitChanged(RB_MAGIC, false, 7.0)` | PASS |
| | `Grind_GeoExitWriteLabels(RB_MAGIC, 7.0, 5.0)` | "RB11 long written": `Grind_GeoExitGet(RB_MAGIC, true, x) && x == 7.0` (1e-9) | FAIL |
| | | "RB11 short written": same for short, 5.0 | FAIL |
| RB12_AddOneShot | isolation as GV10 (`Grind_OrderTestReset(); Grind_TestResetSideState(); g_grind_order_test_active = true; Adr152_TestPrepareIsolation(); Grind_EngineConfigureAdr152(true, 0); Adr152_TestSeedSlotSeams(200, 100, 0); Grind_MarketTestSeed(1.20000, 1.20010, 0);`); short layer entry 1.20000 pos 5101 ext 6101 at 1.19930; `g_grind_short.add_pending_ticket = 6201`, upsert 6201 `OPT S 1 ENT` SELL_LIMIT 1.20060; `g_grind_start_add_reprice_short = true;` `Grind_EnsureAddNext(g_grind_short, false, RB_MAGIC, "OPT", 5.0, 4.0, 8, 0.01)` | "RB12 moved once": price of 6201 = 1.20050 | FAIL |
| | | "RB12 flag cleared": `!g_grind_start_add_reprice_short` | FAIL |
| | then `Grind_EnsureAddNext(..., 5.1, 4.0, 8, 0.01)` | "RB12 deadband back": modify calls == 1 | FAIL |
| GV14_DueAddShort | isolation as RB12; short layer entry 1.20000 pos 5101 ext 6101 at 1.19930; `g_grind_recon_exit_pips = 10.0; g_grind_recon_exit_pips_short = 7.0; g_grind_add_due_short = true;` `Grind_OnTickEngine(RB_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 5.0, 6.0)` | "GV14 due add price": price of `g_grind_short.add_pending_ticket` = 1.20060 | PASS |
| | | "GV14 due cleared": `!g_grind_add_due_short` | PASS |
| GV15_RecenterShortWidth | isolation as RB12; long layer entry 1.20000 pos 5001 ext 6001 at 1.20100 (SELL_LIMIT `OPT L 0 EXT`); short flat, `g_grind_short.l0_pending_ticket = 6301`, upsert 6301 `OPT S 0 ENT` SELL_LIMIT 1.20300; `g_grind_recon_exit_pips = 10.0;` `Grind_OnTickEngine(RB_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0)` | "GV15 short L0 recentred": price of 6301 = 1.20035 | PASS |

**Hand derivations** (pip 0.00010). Long exit = eff + exit, short = eff -
exit. RB1: 1.20500 + 7 = 1.20570, 1.20300 + 7 = 1.20370 (both above ask
1.20010: no clamp); L1 held. The second run finds both at target (half
point) and modifies nothing. RB2: 1.19500 - 7 = 1.19430, 1.19700 - 7 =
1.19630 (below bid 1.20000). RB3: raw at 7 = 1.20570; offset = 1.20011 -
1.20570 = -0.00559 (accrued 0, shift 0); I6 expects 1.20570 - 0.00559 =
1.20011; L1 1.20400 + 7 = 1.20470; one modify (L1 only). RB4: eff =
VL 1.19900; 1.19900 + 7 = 1.19970 (above ask 1.19510). RB5: 1.20570 +
0.00012 = 1.20582. RB6: target 1.20050 <= ask 1.20070 + 1 point: clamped
to 1.20071 (`Grind_CarryClampLongExit`, min distance = point with stops
0); shift = 1.20071 - 1.20050 = 0.00021 with a release marker, so
`Grind_CarryShiftGetForRecon` returns it. RB8: the first modify fails
and the function returns at once; nothing moved. RB10 (d): expected
1.20070; a FILLED long exit at 1.20060 is adverse (diff < 0). RB12:
short add = deepest 1.20000 + 5 = 1.20050; resting 1.20060 is 1 pip away,
inside the 4-pip deadband, so only the one-shot band (0.05 pip) moves
it; then add 5.1 gives 1.20051, inside the deadband again. GV14: the due
path places the short add at 1.20000 + 6 = 1.20060. GV15: mid 1.20005;
the resting short L0 at 1.20300 is 29.5 pips from mid (> stranded 10);
recentred to mid + 3 = 1.20035.

**Predicted** (the operator runs both on GBPUSD and EURUSD; you do NOT
run them): baseline 2168. Commit 1 adds **50** assertions (RB1 8, RB2 4,
RB3 6, RB4 3, RB5 2, RB6 4, RB7 1, RB8 3, RB10 7, RB11 6, RB12 3, GV14 2,
GV15 1): **2187/2218**, failing EXACTLY the 31 rows marked FAIL. Commit 2
**2218/2218**. Report your own mechanical count of new `Assert*` calls.

PASS in both states BY DESIGN (list them in the report): the "ok" rows
of RB1 and RB3, "RB1 held untouched", "RB3 eject order kept", "RB5
accrued unchanged", RB7, "RB8 L0 untouched", RB10 (a), (c), (d), RB11
"absent", "equal" and "short independent", and GV14 and GV15 (they lock
v2.0's routing, DeepSeek `a19261d` T-7; they do not test v2.1).

## COMMIT 2 -- THE IMPLEMENTATION

1. Labels (carry): `Grind_GeoExitGet` = `GlobalVariableCheck` then
   `GlobalVariableGet`; `Grind_GeoExitSet` = `GlobalVariableSet` then
   `Grind_GvMarkDirty()`; `Grind_GeoExitChanged` = a label exists AND
   `MathAbs(label - current_exit) > 1e-6`; `Grind_GeoExitWriteLabels` =
   set both.
2. Recon: in `Grind_ReconCheckInvariants`, inside the long I6 failure
   branch (after 524, before the return at 529): `if(tolerate_exit_price_long
   && !long_exit_filled) continue;` and the same for short (554/559) with
   `tolerate_exit_price_short` and `short_exit_filled`. Pass both flags
   through the inner call (1106-1109) and the wrapper (1174-1182).
   `Grind_ReconstructState`: before its rebuild call, `g_grind_rebuild_long
   = Grind_GeoExitChanged(g_grind_recon_magic, true, g_grind_recon_exit_pips);
   g_grind_rebuild_short = Grind_GeoExitChanged(g_grind_recon_magic, false,
   Grind_SidePips(false, g_grind_recon_exit_pips,
   g_grind_recon_exit_pips_short));` and pass them as the two new last
   arguments at 1288. `Grind_CheckBookInvariants` (1245-1253): unchanged.
3. Engine: `Grind_RebuildExitsAtStart` as "WHAT V2.1 IS" item 3; side
   exits `g_grind_recon_exit_pips` and `Grind_SidePips(false,
   g_grind_recon_exit_pips, g_grind_recon_exit_pips_short)`; `dir` = 1
   long, -1 short. `Grind_EnsureAddNext`: item 5.
4. `fxgrind.mq5`: item 4, inside the success branch directly after the
   `Grind_RetryMissingExits` call at 267; the `GRIND_REBUILD` print
   directly after the `GRIND_GEOMETRY` print (337). ASCII in new strings.

## NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run
  the suite (the operator compiles in the MetaEditor GUI; suite figures
  are pending), do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no `git add .` or `-u`.
- PUSH THE BRANCH after each commit: `git push -u origin grind-v21-rebuild`.
- `Grind_CheckBookInvariants` stays strict: no new argument at 1245-1253.
- Do not change `Grind_ExitQManageSide`, `Grind_ExitQFormulaTarget`,
  `Grind_ModifyPendingPrice`, the carry pass, the lattice, the eject
  functions, `Grind_TryPlaceL0` or `Grind_TryRecenterOppositeL0`.
- No retry loop in the rebuild; one attempt per layer.
- No existing test, expected value, helper or registration changes.
- Nothing outside `ea/`. No presets, docs or pipshed. No `static` on
  file-scope functions.

## FAILURE MODES -- STOP AND REPORT

- A cited line does not hold the code described (drift): STOP.
- A helper in A5 or A9 is missing or has another signature: STOP.
- A control row predicted PASS fails (the setup does not reach the code):
  STOP; do not invent a setup.
- Any existing test would need a change: STOP.
- You believe a row predicted PASS would fail, or FAIL would pass: write
  it as specified and report why; never adjust an expected value.

## REPORT

Both commit hashes (pushed); `git diff --stat main..grind-v21-rebuild`;
each new test with its assertion names; your count of new assertions;
the PASS-in-both list; every site changed, as file:line.

## FOR GEMINI -- RULE BEFORE CURSOR STARTS

ADR-163 is ruled (GR-Q1..Q7). These are the spec's own choices and one
deviation. Reason from this codebase; the audit trail cites lines.

- **GR-S1. DEVIATION: no one-shot for a resting L0** (GR-Q7 accepted
  one). An add's target depends only on the deepest entry and the add,
  so an unchanged add is not modified. An L0's target depends on the
  CURRENT MID: a one-shot would move every flat side's resting L0 to the
  current mid on EVERY restart, width changed or not (ADR-123 place-once
  would be broken at each reattach). Width is not a compass lever yet
  (cycle-4 s8.2, rule open); a changed width reaches the next L0 placed.
  Accept, or require an L0 width label?
- **GR-S2.** The add one-shot at a restart with an UNCHANGED add can still
  modify once when the resting add was clamped at placement (its
  unclamped target now differs): at most one request per side per
  restart. Accept?
- **GR-S3.** A resting exit already at the new target (half a point) is
  not modified, but its shift state is set exactly as A4 (record or
  delete). Accept?
- **GR-S4.** Labels are written for BOTH sides after every clean init
  (an absent label is created with the current exit) and never after a
  halt. Accept?
- **GR-S5.** The rebuild runs after `Grind_RetryMissingExits`, so a
  missing required exit on a flagged side is placed at the NEW formula
  first and then found at target. Any ordering hazard with ADR-156's
  startup shortfall?
- **GR-S6.** GV14 and GV15 test v2.0 code and pass in both states by
  design. Accept as regression locks?

After Gemini, Cursor, and the operator's two suite states: DeepSeek
audits the branch (a separate runner prompt), then the merge `--no-ff`.


## GEMINI RULINGS (2026-09-27 ~01:15Z) -- ALL SIX ACCEPTED, NO CHANGES TO THE BUILD

Build exactly as written above. Condensed; his reasons checked by Claude.

- **GR-S1 ACCEPTED.** No L0 one-shot: it would snap every flat side's L0
  to the mid at each restart and break ADR-123 place-once. No width label.
- **GR-S2 ACCEPTED.** At most one modify per side per restart for a
  resting add clamped at placement.
- **GR-S3 ACCEPTED.** Shift state set exactly as A4 even when no modify
  is needed.
- **GR-S4 ACCEPTED.** CORRECTION (Claude): after a halt the operator does
  not have to repair orders by hand. The label is unchanged, so the next
  init is tolerant again and finishes the rebuild; exits already moved
  match and are not modified twice (ADR-163 s9).
- **GR-S5 ACCEPTED.** `Grind_RetryMissingExits` places a missing exit at
  the new formula (the recon globals are set from the resolved inputs
  before it runs); the rebuild then finds it at target.
- **GR-S6 ACCEPTED.** GV14 and GV15 are regression locks on v2.0.

Line count: 354
