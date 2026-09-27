This message has a line count at the bottom

# CURSOR PROMPT -- GRIND V2.0: ADD, EXIT AND WIDTH PER SIDE (CYCLE-4 NOTE S8.2, C47)

Repo `D:\fxmatrix`, from `main` at `d2cfd87` or a docs-only descendant
(EA code == `669da60`, suite 2114/2114 at `00e0e4e`). Branch
`grind-v2-per-side`. Record: `docs/architecture/cycle4-live-geometry-search.md`
s8.2 and s8.6; backlog C47. Gemini rules on this prompt BEFORE you
start; his rulings are pasted at the bottom. Where a ruling changes a
default below, follow the ruling. If a ruling is ambiguous, STOP and
report.

Nothing here deploys. Every new input defaults to "inherit" (-1), so an
existing preset runs EXACTLY today's behaviour: every short-side value
resolves to the value the long side uses today.

**OPERATOR DIRECTION (2026-09-26).** The next EA has four levers: add
and exit for the long side, add and exit for the short side (s8.2),
and is wanted for Sunday's session on a new IC Markets box. This is
v2.0: the levers only. NOT in v2.0: the rebuild at start (s8.6; a
reattach with a changed EXIT on a live book still halts on I6, as
today; v2.1 before the first round ends), per-layer exit tags (C46),
a new width rule (the ADR-153 guard applies per side, unchanged), any
pipshed change.

## AUDIT TRAIL (read in source at `d2cfd87`, EA == `669da60`, by Claude)

| # | finding | where | status |
|---|---|---|---|
| A1 | Nearly every function that prices an add or an exit already takes the side (`is_long` or a side struct) AND a scalar pips value. Only the DISPATCH sites pass one scalar to both sides. Inner functions need no change | grep of `add_pips`/`exit_pips`/`width_pips` over `grind_*.mqh` | verified |
| A2 | Dispatch sites (one scalar to both sides): `Grind_OnTickEngine` (width 2779-2780, 2790-2794; add 2767, 2769, 2800-2802), `Grind_ServiceDueAddFlags` (2300-2322), `Grind_OnTradeTransactionEngine` (2907-2911), `Grind_RetryMissingExits` (2746-2747), `Grind_LatticeOnTick` (1259-1262), `Grind_AutoEjectOnTick` (670-675), `Grind_EjectPollCommand` (514, side found inside) | `grind_engine.mqh` | verified |
| A3 | Add at fill (ADR-152, `InpFillTimePlace=true` in every preset) reads the global `g_grind_engine_add_pips` (engine 25), set at 2767 and 2907, used at 2650 inside `Grind_HandleSideDealFill` | engine | verified |
| A4 | I6 and reconstruction use ONE exit for both loops: `Grind_ReconCheckInvariants` (recon 461; long 522/526, short 552/556), `Grind_RebuildBookFromTicketsInner` (838; 1101, long 1127, short 1143), wrapper `Grind_RebuildBookFromTickets` (1155/1170); callers `Grind_CheckBookInvariants` 1239 (every tick) and `Grind_ReconstructState` 1270 (init, passes `true`) with the global `g_grind_recon_exit_pips` (recon 17; set at `fxgrind.mq5` 161). The broker-ticket collector has NO test seam (live `PositionsTotal`/`OrdersTotal`), so the two callers cannot be unit-tested | recon | verified |
| A5 | Carry pass (definitions at: `Grind_CarryExitPassBegin` 936, `Grind_CarryWorkBase` 975, `Grind_CarryOnTimerStep` 1146, `Grind_CarryExitPassStep` 1163). `PassBegin` builds long (955) and short (965) formulas with one exit; `WorkBase` picks dir from the work item. `OnTimerStep` calls `PassStep` at 1159. `PassStep` calls `PassBegin` at 1175, guarded by `if(Grind_CarryGateDue(magic, now) && !g_grind_carry_exit_pass_active)` at 1174 (the pass BEGINS from inside the step, once per night), then calls `WorkBase` at 1203 and passes `exit_pips` to `Grind_CarryExitShiftLayer` at 1207 | `grind_carry.mqh` | verified (line numbers corrected 2026-09-27 ~00:20Z) |
| A6 | Forward declarations in test headers with the CURRENT signatures: `Grind_CarryExitPassStep` (`fxgrind_tests_adr151.mqh` 29-32), `Grind_ReconCheckInvariants` (adr151 34-44), `Grind_OnTickEngine` (`fxgrind_tests_adr152.mqh` 55-63). A declaration whose signature differs from the definition is a SECOND, bodiless function (02_TRAPS 2026-09-25 B1). The engine is included before every test header (`fxgrind_tests.mq5` 13), so they are redundant: delete them | tests | verified |
| A7 | MQL5 default parameters after existing defaults work (C55 added `const double extreme = 0.0` as the last parameter of `Grind_LatticeTrySide`). Existing tests call the old arity and are unchanged | C55 | verified |
| A8 | Test seams used below exist with these names: `Adr151_TestSetupLongLayer`, `Adr151_TestSeedSlotSeams`, `Adr151_TestResetAll`, `Grind_TestInitLayerScratch`, `Grind_TestAppendDeal`, `Adr152_TestPrepareIsolation`, `Adr152_TestSeedSlotSeams`, `Adr152_TestResetAll`, `Grind_EngineConfigureAdr152`, `Adr162b_SeedShort8`, `Adr162b_Reset`, `C55_SeedShort8Carry`, `C55_AllRestingI6Short`, `C55_AllAccruedShort`, `C54_FinishCarryPass`, `Grind_TestEjectHarnessReset`, `Grind_TestEjectFixtureDepth2`, `Grind_OrderGetPriceOpen`, `Grind_VLHas`/`Grind_VLGet`, `Grind_EjectOffsetGet`/`Delete`, `Grind_EjectCommandName` | tests | verified |
| A9 | ADR-153 guard: add / width within [0.5, 4.0] (`grind_pure.mqh` 9-10, 41-52). Fleet B presets: width 3-7, add 4-10, exit 5-10 | pure; presets_b | verified |
| A10 | `config_events.inputs` stores the whole INIT/DEINIT JSON (pipshed `archive_worker.py` 692-696): new keys are archived with no pipshed change. Heartbeat extras are appended in `fxgrind.mq5` 80-104 | pipshed; EA | verified |

## WHAT V2.0 IS

1. **Six new inputs** in `fxgrind.mq5`, directly after `InpExitPips`:

       input double InpWidthPipsLong  = -1.0;  // v2: -1 = InpWidthPips
       input double InpWidthPipsShort = -1.0;  // v2: -1 = InpWidthPips
       input double InpAddPipsLong    = -1.0;  // v2: -1 = InpAddPips
       input double InpAddPipsShort   = -1.0;  // v2: -1 = InpAddPips
       input double InpExitPipsLong   = -1.0;  // v2: -1 = InpExitPips
       input double InpExitPipsShort  = -1.0;  // v2: -1 = InpExitPips

   Exactly -1 inherits the base input; a value > 0 overrides it; any
   other value (0, -2, -0.5) is FATAL at init (typo guard). The base
   inputs stay REQUIRED and validated as today. Each side's resolved
   (width, add, exit) passes `Grind_ValidateGeometryInputs` and
   `Grind_ValidateAddWidthRatio` separately.
2. **The long values travel where the scalar travels today; the short
   values travel in NEW LAST PARAMETERS with default 0.0**, resolved by
   one pure helper: `Grind_SidePips(is_long, long_or_both, short_value)`
   = `short_value` when `!is_long && short_value > 0.0`, else
   `long_or_both`. A caller that does not pass a short value (every
   existing test) gets today's behaviour.
3. Every site in A2-A5 uses its side's value: L0 width per side (and
   the opposite-L0 recentre), add per side (tick, due flag, at fill,
   lattice level and stranded threshold), exit per side (fill, queue,
   retry, I6 and reconstruction, carry pass, commanded and automatic
   eject, lattice roll and roll cost).
4. **Reporting:** legacy keys (`width_pips`, `add_pips`, `exit_pips` in
   the heartbeat, config dump and INIT/DEINIT archive fields) carry the
   LONG resolved values; six new keys `width_pips_long`, `width_pips_short`,
   `add_pips_long`, `add_pips_short`, `exit_pips_long`, `exit_pips_short`
   are added to the heartbeat and the INIT/DEINIT fields; one init line
   `GRIND_GEOMETRY long width=W add=A exit=X short width=W add=A exit=X`.
5. `#property version "2.00"`. File name, magic scheme, presets and
   `GRIND_EA_BUILD` unchanged.

## COMMIT 1 -- STUBS, SIGNATURES AND TESTS

**Production changes that compile and change NO behaviour:**

- `ea/grind_pure.mqh`, after `Grind_ValidateDeadband`: two functions as
  STUBS:

      double Grind_SidePips(const bool is_long, const double long_or_both,
                            const double short_value)
      { return long_or_both; }                       // STUB
      bool Grind_ResolveSideInput(const double base_value,
                                  const double override_value,
                                  double &out_value)
      { out_value = base_value; return true; }       // STUB

- `ea/grind_engine.mqh`: after line 25,
  `double g_grind_engine_add_pips_short = 0.0;`. New LAST parameters,
  IGNORED in commit 1:
  `Grind_OnTickEngine(..., const double lots, const double width_pips_short = 0.0, const double add_pips_short = 0.0)`;
  `Grind_ServiceDueAddFlags(..., const double lots, const double add_pips_short = 0.0)`;
  `Grind_OnTradeTransactionEngine(..., const double lots, const double exit_pips_short = 0.0, const double add_pips_short = 0.0)`;
  `Grind_LatticeOnTick(..., const datetime now, const double exit_pips_short = 0.0, const double add_pips_short = 0.0)`;
  `Grind_AutoEjectOnTick(..., const double k, const double exit_pips_short = 0.0)`;
  `Grind_EjectPollCommand(..., const bool engine_blocked, const double exit_pips_short = 0.0)`.
- `ea/grind_recon.mqh`: after line 17,
  `double g_grind_recon_exit_pips_short = 0.0;`. New LAST parameter
  `const double exit_pips_short = 0.0` (after `tolerate_exit_shortfall`),
  IGNORED, on `Grind_ReconCheckInvariants`,
  `Grind_RebuildBookFromTicketsInner`, `Grind_RebuildBookFromTickets`.
- `ea/grind_carry.mqh`: new LAST parameter `const double
  exit_pips_short = 0.0`, IGNORED, on `Grind_CarryOnTimerStep`,
  `Grind_CarryExitPassStep`, `Grind_CarryExitPassBegin`,
  `Grind_CarryWorkBase`.
- DELETE the three forward declarations in A6 (and nothing else in
  those two files).
- Do NOT touch `fxgrind.mq5` in commit 1.

**Tests: new file `ea/fxgrind_tests_gv.mqh`**, included directly after
`#include "fxgrind_tests_c55.mqh"`; register every test in `OnStart`
directly after `Test_LB43_SignGuardAfterRoll();`, in table order. NO
forward declarations. Magic `22260101UL`, point `0.00001`, `T0` =
`D'2026.09.28 10:00'`. Every test SAVES `g_grind_engine_add_pips`,
`g_grind_recon_exit_pips` at start and RESTORES them at the end, and
sets `g_grind_engine_add_pips_short` and `g_grind_recon_exit_pips_short`
to 0.0 at the end. Read any `layers[0]` field through `ArraySize(...) ==
1 ? <field> : 0.0` (an out-of-range read aborts the script; an
assertion inside an `if` passes by not running).

New helpers in the file:
- `GV_SeedShort8CarryPerSide(bid, ask)`: a copy of
  `C55_SeedShort8Carry` whose ONLY change is its last line:
  `Grind_CarryExitPassBegin(_Symbol, 22260101UL, 9.0, 5.0);`
- `GV_FinishCarryPassPerSide()`: a copy of `C54_FinishCarryPass` calling
  `Grind_CarryExitPassStep(_Symbol, 22260101UL, 9.0,
  g_grind_carry_test_server_time, 5.0)`.
- `GV_EjectFixtureShortDepth2()`: the short mirror of
  `Grind_TestEjectFixtureDepth2`: `g_grind_short` S0 entry 1.24800, pos
  1101, exit order 2101, exit_target 1.24730, index 0; S1 entry 1.24900,
  pos 1102, exit order 2102, exit_target 1.24830, index 1; orders
  2101 at 1.24730 and 2102 at 1.24830 (`ORDER_TYPE_BUY_LIMIT`, comments
  `OPT S 0 EXT`, `OPT S 1 EXT`); market 1.25000/1.25010, stops 0.
- A short layer "by hand" = set `entry_price`, `layer_index`,
  `position_ticket`, `exit_order_ticket`, `exit_position_ticket` = 0 and
  `exit_target` = `Grind_ExitQFormulaTarget(entry, <exit>, _Point,
  false, pos)` (`Adr151_TestSetupLongLayer` is long-only).

| test | setup and calls | assertion (name: expected) | commit 1 |
|---|---|---|---|
| GV1_SidePips | pure | "GV1 long takes long": `Grind_SidePips(true, 10.0, 7.0)` = 10.0 | PASS |
| | | "GV1 short takes short": `(false, 10.0, 7.0)` = 7.0 | FAIL |
| | | "GV1 short unset inherits": `(false, 10.0, 0.0)` = 10.0 | PASS |
| | | "GV1 short negative inherits": `(false, 10.0, -1.0)` = 10.0 | PASS |
| GV2_ResolveSideInput | pure, base 10.0 | "GV2 inherit ok": override -1.0 returns true | PASS |
| | | "GV2 inherit value": out = 10.0 | PASS |
| | | "GV2 override ok": override 7.0 returns true | PASS |
| | | "GV2 override value": out = 7.0 | FAIL |
| | | "GV2 zero refused": override 0.0 returns false | FAIL |
| | | "GV2 negative refused": override -2.0 returns false | FAIL |
| | | "GV2 minus half refused": override -0.5 returns false | FAIL |
| GV3_RetryMissingExitsPerSide | `Grind_OrderTestReset(); Grind_TestResetSideState(); Grind_CarryTestReset(); g_grind_order_test_active = true; Adr151_TestSeedSlotSeams(200, 100, 0); Grind_MarketTestSeed(1.20000, 1.20010, 0, 0);` long: `Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.20000, 5001UL, 0, 10.0)`; short by hand: entry 1.20000, pos 5101, exit order 0, exit 7.0; `g_grind_recon_exit_pips = 10.0; g_grind_recon_exit_pips_short = 7.0; Grind_RetryMissingExits(22260101UL, "OPT", 0.01);` | "GV3 long exit placed": long `exit_order_ticket != 0` | PASS |
| | | "GV3 long exit price": its order price = 1.20100 (1e-9) | PASS |
| | | "GV3 short exit placed": short `exit_order_ticket != 0` | PASS |
| | | "GV3 short exit price": its order price = 1.19930 (1e-9) | FAIL |
| GV4_I6PerSide | scratch long `Grind_TestInitLayerScratch(l[0], 0, 1.20000, 5001UL)`, `has_exit_order = true`, `exit_order_ticket = 6001`, `exit_target = 1.20100`; short `(s[0], 0, 1.20000, 5101UL)`, `has_exit_order = true`, `exit_order_ticket = 6101`, `exit_target = 1.19930`; ranks {0} and {0}; point 0.00001, max 8. (a) exit 10.0, old arity | "GV4 symmetric 10 rejects short": false | PASS |
| | | "GV4 reason short": reason = `I6_SHORT_EXIT` | PASS |
| | (b) exit 10.0, `false`, 7.0 | "GV4 per-side accepts": true | FAIL |
| | (c) exit 7.0, old arity | "GV4 symmetric 7 rejects long": false | PASS |
| | | "GV4 reason long": reason = `I6_LONG_EXIT` | PASS |
| | (d) exit 10.0, `false`, 12.0 | "GV4 wrong short rejects": false | PASS |
| | | "GV4 reason wrong short": reason = `I6_SHORT_EXIT` | PASS |
| GV5_RebuildPerSide | four tickets (as `Test_T19_ThreeLongLayersRebuild`): 1001 POSITION `OPT L 0 ENT` 1.20000; 2001 ORDER `OPT L 0 EXT` 1.20100; 1101 POSITION `OPT S 0 ENT` 1.20000; 2101 ORDER `OPT S 0 EXT` 1.19930. (a) `Grind_RebuildBookFromTickets(t, 4, magic, "OPT", 10.0, 8, point, L, S, reason)` | "GV5 symmetric rejects": false | PASS |
| | | "GV5 reason": `I6_SHORT_EXIT` | PASS |
| | (b) fresh L, S; same call plus `false, 7.0` | "GV5 per-side ok": true | FAIL |
| | | "GV5 short depth": `ArraySize(S.layers) == 1` | FAIL |
| | | "GV5 short exit target": 1.19930 (1e-10) | FAIL |
| | (c) tickets 1001, 2001, 1101 only (no short EXT); fresh L, S; call with `true, 7.0` | "GV5c ok": true | PASS |
| | | "GV5c short formula target": `S.layers[0].exit_target` = 1.19930 (1e-10) | FAIL |
| GV7_FillShortExitAndAdd | as `Test_T4b` isolation: `Grind_OrderTestReset(); Grind_DealTestReset(); Grind_TestResetSideState(); g_grind_order_test_active = true; Adr152_TestPrepareIsolation(); Grind_EngineConfigureAdr152(true, 0); Adr152_TestSeedSlotSeams(200, 100, 0); Grind_MarketTestSeed(1.20000, 1.20010, 0); g_grind_ent_sent_this_tick = false; g_grind_deal_test_active = true; Grind_TestAppendDeal(9701, GrindCommentBuild("OPT", "S", 0, "ENT"), DEAL_ENTRY_IN, 6701, 5101, 0.0, 0.0, 0.0, 1.20000);` `MqlTradeTransaction tr; ZeroMemory(tr); tr.type = TRADE_TRANSACTION_DEAL_ADD; tr.deal = 9701;` `Grind_OnTradeTransactionEngine(tr, magic, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);` | "GV7 short layer appended": `ArraySize(g_grind_short.layers) == 1` | PASS |
| | | "GV7 short exit target": 1.19930 (1e-9) | FAIL |
| | | "GV7 short exit order price": price of its `exit_order_ticket` = 1.19930 (1e-9) | FAIL |
| | | "GV7 short add stored": `g_grind_engine_add_pips_short` = 6.0 | FAIL |
| | | "GV7 short add placed": `g_grind_short.add_pending_ticket != 0` | PASS |
| | | "GV7 short add at fill price": its price = 1.20060 (1e-9) | FAIL |
| GV8_FillLongControl | GV7's setup with deal 9702, `OPT L 0 ENT`, order 6702, pos 5001, price 1.20000; same call (long 10/10, short 7/6) | "GV8 long exit target": 1.20100 (1e-9) | PASS |
| | | "GV8 long add at fill price": price of `g_grind_long.add_pending_ticket` = 1.19900 (1e-9) | PASS |
| GV9_L0WidthPerSide | flat book; `Grind_OrderTestReset(); Grind_TestResetSideState(); g_grind_order_test_active = true; Adr152_TestPrepareIsolation(); Grind_EngineConfigureAdr152(true, 0); Adr152_TestSeedSlotSeams(200, 100, 0); Grind_MarketTestSeed(1.20000, 1.20010, 0);` then TWICE `Grind_OnTickEngine(magic, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0);` (one ENT per tick) | "GV9 long L0 price": price of `g_grind_long.l0_pending_ticket` = 1.19955 (1e-9) | PASS |
| | | "GV9 short L0 placed": `g_grind_short.l0_pending_ticket != 0` | PASS |
| | | "GV9 short L0 price": its price = 1.20035 (1e-9) | FAIL |
| GV10_AddNextPerSide | GV9's setup; short by hand: entry 1.20000, pos 5101, exit order 6101 at 1.19930 (upsert `OPT S 0 EXT`, BUY_LIMIT; exit 7.0); `g_grind_recon_exit_pips = 10.0; g_grind_recon_exit_pips_short = 7.0;` then TWICE `Grind_OnTickEngine(magic, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 5.0, 6.0);` | "GV10 short add placed": `g_grind_short.add_pending_ticket != 0` | PASS |
| | | "GV10 short add price": its price = 1.20060 (1e-9) | FAIL |
| GV11_LatticeShortPerSide | `Adr162b_SeedShort8(); Grind_MarketTestSeed(1.19400, 1.19410, 0, 0); Grind_LatticeOnTick(magic, "OPT", 0.01, true, 9.0, 3.0, 8, false, T0, 5.0, 10.0);` (long values 9/3 are decoys; no long layers) | "GV11 S0 rolled at short level": `Grind_VLHas(7101) && VLGet(7101)` = 1.19400 (1e-9) | FAIL |
| | | "GV11 one level only": `!Grind_VLHas(7102)` | FAIL |
| | | "GV11 rolled exit at short exit": price of 8101 = 1.19350 (1e-9) | FAIL |
| GV12_CarryPerSide | (a) `Grind_CarryTestReset(); Grind_TestResetSideState();` long layer entry 1.20000 pos 7201; short by hand entry 1.20000 pos 7301 (exit 7.0); `Grind_CarryExitPassBegin(_Symbol, magic, 10.0, 7.0);` | "GV12 two work items": `g_grind_carry_exit_work_count == 2` | PASS |
| | | "GV12 long base": `Grind_CarryWorkBase(0, 10.0, 0.00001, 7.0)` = 1.20100 (1e-9) | PASS |
| | | "GV12 short base": `Grind_CarryWorkBase(1, 10.0, 0.00001, 7.0)` = 1.19930 (1e-9) | FAIL |
| | | "GV12 short base old arity": `Grind_CarryWorkBase(1, 10.0, 0.00001)` = 1.19900 (1e-9) | PASS |
| | (b) `Grind_CarryTestReset(); GV_SeedShort8CarryPerSide(1.19400, 1.19410); GV_FinishCarryPassPerSide();` | "GV12b all resting I6 at 5": `C55_AllRestingI6Short()` | FAIL |
| | | "GV12b all accrued": `C55_AllAccruedShort()` | PASS |
| GV13_EjectShortPerSide | `Grind_TestEjectHarnessReset(); GV_EjectFixtureShortDepth2(); GlobalVariableSet(Grind_EjectCommandName(magic), (double)1101UL); rc = Grind_EjectPollCommand(magic, true, 3.0, false, 7.0);` end with `Grind_EjectOffsetDelete(1101UL)` | "GV13 ok": `rc == GRIND_EJECT_OK` | PASS |
| | | "GV13 order price": price of 2101 = 1.24999 (1e-9) | PASS |
| | | "GV13 offset": `Grind_EjectOffsetGet(1101UL)` = 0.00269 (1e-9) | FAIL |

**Hand derivations** (point 0.00001, one pip 0.00010). Long exit =
entry + exit, short exit = entry - exit: 1.20000 + 10 = 1.20100; 1.20000
- 7 = 1.19930; with 10 on the short side 1.19900 (the wrong answer every
FAIL row sees at commit 1). Add: long = deepest - add, short = deepest +
add: short 1.20000 + 6 = 1.20060 (1.20100 at commit 1); long 1.20000 - 10
= 1.19900. L0 (GV9): mid 1.20005; long 1.20005 - 5 = 1.19955; short
1.20005 + 3 = 1.20035 (1.20055 at commit 1); neither clamps (buy below
bid, sell above ask). GV4/GV5: I6 tolerance is 2 points; 7 vs 10 pips
differ by 30 points. GV11: `Adr162b_SeedShort8` holds S0-S7 at
1.18600-1.19300 with exits at 5 (LB16, LB40); the short level is the
deepest entry + add = 1.19300 + 10 = 1.19400; bid 1.19400 fires it; the
next level 1.19500 does not; the rolled exit is level - exit = 1.19400 -
5 = 1.19350, below the bid (passive, no clamp). At commit 1 the decoy add
3 puts the level at 1.19330 and further levels at 1.19360 and 1.19390
also fire: every GV11 row fails. GV12b: the seed's exits are at 5; the
pass must re-price them from 5 (short), not 9 (long decoy); at commit 1
it re-prices to 9 and `C55_AllRestingI6Short` (at 5) fails. GV13: the
short eject target is bid - 1 point = 1.24999 (Z4); raw = entry - exit
= 1.24800 - 7 = 1.24730; offset = 1.24999 - 1.24730 = +0.00269 (with 3:
1.24770, +0.00229). S0 (1101, lowest short entry) is the highest exit
rank, so the command is valid (mirror of Z6 accepting L0).

**Predicted** (the operator runs both on GBPUSD and EURUSD; you do NOT
run them): baseline 2114. Commit 1 adds **54** assertions (GV1 4, GV2
7, GV3 4, GV4 7, GV5 7, GV7 6, GV8 2, GV9 3, GV10 2, GV11 3, GV12 6,
GV13 3): **2145/2168**, failing EXACTLY the 23 rows marked FAIL.
Commit 2 **2168/2168**. Report your own mechanical count of new
`Assert*` calls and any difference.

PASS in both states BY DESIGN (list them in the report): GV1 rows 1, 3,
4; GV2 rows 1-3; the "placed" controls in GV3, GV7, GV9, GV10; GV4 (a),
(c), (d); GV5 (a) and "GV5c ok"; GV8 (the long side is untouched by a
short value); "GV12 two work items", "GV12 long base", "GV12 short base
old arity", "GV12b all accrued"; "GV13 ok" and "GV13 order price".

## COMMIT 2 -- THE IMPLEMENTATION

1. `Grind_SidePips`: `return (!is_long && short_value > 0.0) ?
   short_value : long_or_both;`. `Grind_ResolveSideInput`: if
   `MathAbs(override_value + 1.0) <= 1e-9` then `out_value = base_value`,
   true; else if `override_value > 0.0` then `out_value =
   override_value`, true; else `out_value = 0.0`, false.
2. Engine. `Grind_OnTickEngine`: `const double width_s =
   Grind_SidePips(false, width_pips, width_pips_short); const double
   add_s = Grind_SidePips(false, add_pips, add_pips_short);` then 2767
   also sets `g_grind_engine_add_pips_short = add_s`; 2769 passes `add_s`
   as the new last argument; 2780 `sell_target` uses `width_s`; 2791 (the
   SHORT L0 recentre) uses `width_s`; 2794 (the LONG one) keeps
   `width_pips`; 2802 uses `add_s`. `Grind_ServiceDueAddFlags`: `add_s`
   the same way; 2318 and 2322 use it. `Grind_OnTradeTransactionEngine`:
   2907 also sets `g_grind_engine_add_pips_short = Grind_SidePips(false,
   add_pips, add_pips_short)`; 2911 passes `Grind_SidePips(false,
   exit_pips, exit_pips_short)`. `Grind_HandleSideDealFill` 2650 (NO
   signature change): `is_long ? g_grind_engine_add_pips :
   Grind_SidePips(false, g_grind_engine_add_pips,
   g_grind_engine_add_pips_short)`. `Grind_RetryMissingExits` 2747:
   `Grind_SidePips(false, g_grind_recon_exit_pips,
   g_grind_recon_exit_pips_short)`. `Grind_LatticeOnTick` 1262: short
   exit and add through `Grind_SidePips(false, ...)`.
   `Grind_AutoEjectOnTick` 675: short exit likewise.
   `Grind_EjectPollCommand` 514: `Grind_SidePips(is_long, exit_pips,
   exit_pips_short)`.
3. Recon. `Grind_ReconCheckInvariants`: `const double exit_s =
   Grind_SidePips(false, exit_pips, exit_pips_short);` used at 552 and
   556 only. `Grind_RebuildBookFromTicketsInner`: pass
   `tolerate_exit_shortfall, exit_pips_short` at 1101; 1143 uses `exit_s`
   (same helper). Wrapper 1170 passes `exit_pips_short` through.
   `Grind_CheckBookInvariants` 1239: add `false,
   g_grind_recon_exit_pips_short`; `Grind_ReconstructState` 1270: `true,
   g_grind_recon_exit_pips_short` (1270 already passes `true`).
4. Carry. `Grind_CarryOnTimerStep` (defined 1146) passes
   `exit_pips_short` to `Grind_CarryExitPassStep` in its call at 1159.
   Inside `Grind_CarryExitPassStep` (defined 1163): the guarded
   `Grind_CarryExitPassBegin(symbol, magic, exit_pips)` call at 1175
   (guard at 1174) gets `exit_pips_short` as its new last argument; the
   `Grind_CarryWorkBase(idx, exit_pips, ...)` call at 1203 gets it too; 1207 passes
   `Grind_SidePips(g_grind_carry_exit_work_long[idx], exit_pips,
   exit_pips_short)`. `PassBegin` 965 uses `Grind_SidePips(false,
   exit_pips, exit_pips_short)`. `Grind_CarryWorkBase`:
   `Grind_SidePips(dir > 0, exit_pips, exit_pips_short)`.
5. `fxgrind.mq5`: `#property version "2.00"`; the six inputs (above);
   file-scope globals `g_geo_width_long`, `g_geo_width_short`,
   `g_geo_add_long`, `g_geo_add_short`, `g_geo_exit_long`,
   `g_geo_exit_short`. At the TOP of `OnInit`, before the existing
   checks: resolve each with `Grind_ResolveSideInput` (FATAL
   `"FATAL: <input name> must be -1 (inherit) or > 0"`, INIT_FAILED);
   then the existing geometry and ratio checks run on the BASE inputs
   (unchanged) AND on each side's resolved triple (FATAL messages name
   the side). `g_grind_recon_exit_pips = g_geo_exit_long;
   g_grind_recon_exit_pips_short = g_geo_exit_short;`. Every engine call
   in `OnTick`, `OnTimer` and `OnTradeTransaction` passes the long values
   in today's slots and the short values in the new last parameters.
   Heartbeat 70-72, config dump 207-209 and archive fields 236 and 249:
   the long values; append the six keys to the heartbeat's
   `StringFormat` (`%.4f` each) and to the INIT and DEINIT fields via a
   new `Grind_ArchiveGeometryFields(wl, al, el, ws, as, es)` in
   `grind_archive.mqh` (appended with `","` as the DEINIT extra fields
   are); `Print` the `GRIND_GEOMETRY` line directly after
   `GRIND_LATTICE`.

## NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run
  the suite (the operator compiles in the MetaEditor GUI; suite figures
  are pending), do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no `git add .` or `-u`.
- PUSH THE BRANCH after each commit: `git push -u origin grind-v2-per-side`.
- Do not change the signature of any function other than the thirteen
  named above (only new LAST parameters with defaults). Do not change
  any inner pricing function (`Grind_ExitPrice`, `Grind_AddTargetPrice`,
  `Grind_ExitQFormulaTarget`, `Grind_ComputeAddTarget`,
  `Grind_SendNextAddEnt`, `Grind_EnsureAddNext`, `Grind_LatticeTrySide`,
  `Grind_LatticeRollLayer`, `Grind_ExitQManageSide`,
  `Grind_EjectAcceptLayer`, `Grind_HandleSideDealFill`).
- Do not make `Grind_ExitPrice` or any pure function read a global.
- Deadband, stranded threshold, cap, lots, lattice switch: unchanged and
  symmetric.
- No existing test, expected value, helper or registration changes,
  EXCEPT deleting the three forward declarations of A6.
- No preset, no docs, nothing outside `ea/`, no pipshed.
- Do not use `static` on file-scope functions (MQL5 rejects it).

## FAILURE MODES -- STOP AND REPORT

- A line cited above does not hold the code described (drift): STOP.
- A helper in A8 is missing or has another signature: STOP.
- A CONTROL row (the "placed" rows, GV8, "GV13 ok", "GV12 two work
  items") would fail: the setup does not reach the code, which is a
  setup problem, not a code problem. STOP; do not guess a new setup.
- Any existing test would need a change to compile or pass (other than
  the A6 deletions): STOP.
- You believe a row predicted PASS would fail, or FAIL would pass: do not
  change code or expected values to match; write it as specified and
  report why.
- A site that passes one scalar to both sides exists that this prompt
  does not list: STOP and name it (file, line).

## REPORT

Both commit hashes (pushed); `git diff --stat main..grind-v2-per-side`;
each new test with its assertion names; your count of new assertions;
the PASS-in-both list; every site you changed, as file:line.

## UNTESTED BY CONSTRUCTION (checked at the deploy instead)

- `Grind_CheckBookInvariants` (every tick) and `Grind_ReconstructState`
  (init) pass the short exit from a global (A4: no broker seam). If
  either were wrong, the FIRST short layer with an exit at its own
  distance would halt on `I6_SHORT_EXIT` within a tick: loud, fail
  closed. Deploy watch: the first fill on each side, no I6 -- at the
  FIRST preset whose short values differ from its long ones (with
  every value inherited the wrappers cannot be wrong).
- `Grind_AutoEjectOnTick` (675): unreachable while the lattice is on
  (`InpVirtualLattice=true` requires `InpAutoEject=false`).
- `fxgrind.mq5` wiring: checked by the `GRIND_GEOMETRY` line, the
  CONFIG dump and the heartbeat keys at attach, BEFORE OK where the
  dialog shows the inputs.

## FOR GEMINI -- RULE BEFORE CURSOR STARTS

Verified in source by Claude unless marked. Answer each; say what you
would change. Please reason from THIS codebase (the audit trail cites
lines); where a question rests on an operator choice, it says so.

- **GV-Q1. One EA with per-side overrides that inherit by default**,
  rather than a new EA file. An existing preset gives today's
  behaviour bit for bit (every short value resolves to the long one);
  a v2 preset sets the six keys. Same file, magics and deploy scripts.
  Accept?
- **GV-Q2. Short values as new LAST parameters with default 0.0** on
  thirteen dispatch-level functions, resolved by one pure helper;
  inner pricing functions unchanged; existing tests untouched except
  three redundant forward declarations deleted (A6). The alternative
  (four explicit parameters everywhere) touches every inner function
  and hundreds of test calls. Accept?
- **GV-Q3. The ADR-153 add/width guard applies per side, unchanged**
  (ratio 0.5-4.0). The operator's "very tight L0" (s8.2: width rule
  OPEN) is therefore NOT enabled by v2.0: add 5 on width 1 is refused
  at init. Operator's choice pending; accept as the fail-closed default?
- **GV-Q4. No rebuild at start in v2.0.** The first deployment is a
  FLAT account, so nothing needs rebuilding; a reattach with a changed
  EXIT on a live book halts on I6 exactly as today (fail closed); an
  ADD change is safe (geometry-cycle3 A6). v2.1 (rebuild, s8.6) is due
  before the first two-day round ends. Accept the split?
- **GV-Q5. Legacy keys carry the LONG values** (heartbeat, config dump,
  archive), plus six explicit keys. Pipshed reads the legacy keys today
  and stores the whole INIT JSON (A10). Accept, or should legacy keys
  be null when the sides differ?
- **GV-Q6. The inherit sentinel is exactly -1**; 0 and other negatives
  are FATAL, as a typo guard. Accept?
- **GV-Q7. The lattice takes its side's add and exit** for the level,
  the roll target and cost, and the stranded threshold (all inside
  `Grind_LatticeTrySide`, fed per side by `Grind_LatticeOnTick`).
  Anything in the lattice that must stay symmetric?
- **GV-Q8. Two call sites are untested by construction** (A4: the I6
  wrappers have no broker seam). The failure mode is an immediate
  I6 halt on the first short fill, which the deploy watch covers.
  Accept, or require a seam first?

After Gemini, Cursor, and the operator's two suite states: DeepSeek
audits the branch (a separate runner prompt; this code places orders),
then the merge `--no-ff`. Presets (Fleet B anchor and the new box) are a
separate patch from Claude.

## GEMINI RULINGS (2026-09-27 ~00:10Z) -- ALL EIGHT ACCEPTED, NO CHANGES TO THE BUILD

Build exactly as written above. Condensed; his reasons checked by Claude.

- **GV-Q1 ACCEPTED.** One EA; -1 inherits, so an existing preset runs
  today's logic.
- **GV-Q2 ACCEPTED.** New last parameters at the thirteen dispatch
  functions; inner pricing functions untouched.
- **GV-Q3 ACCEPTED.** The ADR-153 guard applies per side. A tighter L0
  (add above 4 x width) needs an explicit operator request and its own
  change.
- **GV-Q4 ACCEPTED.** The rebuild at start is v2.1 (draft ADR-163).
- **GV-Q5 ACCEPTED.** Legacy keys carry the long values; six new keys.
  (His "the dashboard would crash on null" is his inference, not
  checked; it does not change the build.)
- **GV-Q6 ACCEPTED.** Exactly -1 inherits; 0 and other negatives FATAL.
- **GV-Q7.** Nothing in the lattice stays symmetric: level, roll target,
  roll cost and stranded threshold all take the side's add and exit, as
  specified (commit 2 item 2, 1262).
- **GV-Q8 ACCEPTED**, with a CORRECTION (Claude): the deploy watch only
  tests the two untested wrappers once a preset sets DIFFERENT short
  values; with every value inherited they cannot be wrong. The watch
  moves to the first asymmetric preset (edited above, "UNTESTED BY
  CONSTRUCTION").

He asked no questions and signed off; every premise he used was checked
against the audit trail above (A2, A4, A6, A9).

**Gemini's second note (~00:20Z), checked.** He called commit 2 item 4
a critical error: "`Grind_CarryExitPassStep` ... cannot call the
initializer `Grind_CarryExitPassBegin`" and "line 1175 is almost
certainly `Grind_CarryExitShiftLayer`". WRONG PREMISE: line 1175 IS the
guarded `PassBegin` call inside the step (`grind_carry.mqh` 1174-1175 at
`dd4761e`); `ShiftLayer` is called at 1200. The item was correct and is
unchanged in substance. REAL ERROR he did find by accident: A5 gave the
wrong DEFINITION lines (`PassStep` "1148" is 1163; `OnTimerStep` "1165" is
1146), which could have made you STOP for drift. A5 and item 4 now give
each definition line and the call line separately.

Line count: 443
