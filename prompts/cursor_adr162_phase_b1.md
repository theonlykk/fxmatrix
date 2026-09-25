This message has a line count at the bottom

# CURSOR PROMPT -- ADR-162 PHASE B1: TRIGGER AT CAP, ROLL, GAP LOOP, B1-B4

Repo `D:\fxmatrix`, from `main` at `8f72d00` (or a docs-only descendant;
EA code == tested `9466b22`). Branch `adr162-phase-b1`. Record:
`docs/architecture/ADR-162-virtual-lattice.md` (read s2-s5 and s12 first).
Gemini rules on this prompt BEFORE you start; his rulings are pasted at the
bottom. Where a ruling changes a default below, follow the ruling. If a
ruling is ambiguous, STOP and report.

Phase B is split. B1 (this prompt): the input, the trigger at cap on the
live tick, the roll, the gap loop, and DeepSeek's carry list B1-B4. B2
(later): M1 catch-up and the ROLL_STRANDED WARN. Pipshed (separate prompt):
rolled fills out of scalp counts, ROLL_STRANDED on the amber tier. B1 is
not deployed without B2.

## AUDIT TRAIL (read in source at 8f72d00 by Claude)

| # | finding | where | status |
|---|---|---|---|
| A1 | The queue never re-prices a live exit: it cancels exits of ranks that are not allowed and places missing required ones. So the roll must modify the exit itself, and after one roll the next candidate has no live exit until the queue runs | engine 2410-2468 | verified |
| A2 | A gap therefore loops per level: roll, run the queue, test the next level. About 3 requests per level (modify, cancel, place), each layer at most once, so at most 3 x cap per side per episode (24 at cap 8) against the shared 2000/day budget (entry stop 1900, exits unaffected) | engine 2431-2466; config 11; api_counter 13 | verified |
| A3 | `Grind_ComputeAddTarget` is unclamped and, after Phase A, anchors on the effective extreme when the side holds a VL. It IS the next virtual level: the lattice is the add lattice | engine 1514-1550 | verified |
| A4 | Roll candidate = oldest UNROLLED layer (long: highest actual entry; short: lowest). Normally the highest rank with a live exit; after rolled fills and real re-adds it can be a middle rank with NO exit (branch S below) | derived from exitq 62-100 | verified |
| A5 | ADR s5 says modify to "level +/- exit". Every formula since Phase A adds accrued (and I6 the carry shift). Target = `Grind_ExitPrice(level) + accrued`, which equals `Grind_ExitQFormulaTarget` once the VL is set and any offset cleared; clamp passive; record the clamp difference as the queue does | exitq 243-255; recon 379; engine 2463-2467 | verified |
| A6 | Order of writes: modify FIRST, then store the VL (as ADR-155 stores the offset after its modify, engine 397-414). On failure nothing changes and I6 stays consistent | engine 397-414 | verified |
| A7 | A hand-ejected highest-rank layer is also the next roll candidate (ADR-155 validator: rank == depth-1). Its offset would carry into the rolled formula: the roll deletes the offset and the carry shift | pure 284-304; engine 412-413 | verified |
| A8 | ADR-157's retry storm fix: per-side backoff after MODIFY_FAILED. Reuse the pattern, DOUBLING per consecutive failure (GB5 amended): the daily API budget is ONE terminal-wide GV shared by the whole fleet (C31: 506 -> 1,906), so a side failing on every tick-driven retry must not be able to reach the 1900 entry stop | engine 518-526, 612-620; api_counter 11 | verified |
| A9 | B1: `Grind_VLHas` has no ticket-0 guard; the anchor loop calls it on every layer | carry 597-600; engine 1522-1527 | verified |
| A10 | B2: the prune deletes a VL whenever `PositionSelectByTicket` fails (also at OnInit, fxgrind.mq5 195). Decision: close path only; VL leaves the prune. Phase A test VL12 asserts the opposite and is FLIPPED here on purpose (see VL12 below) | carry 983-1013 (VL branch 997-999); tests_adr162 253-261 | verified |
| A11 | B3: no test seam in `Grind_ReconCollectBrokerTickets`, so "a restart through `Grind_ReconstructState`" is tested through the call it makes: `Grind_RebuildBookFromTickets(..., true)` | recon 1184-1225, 1267-1276 | verified |
| A12 | B4: `scalp_closed` already carries `ejected`; pipshed drops unknown keys (`SCALP_FIELDS`, archive_worker 85-89), so a new `rolled` key is harmless before pipshed reads it. Reusing `ejected=true` would break pipshed's `eject_mismatch` (ftmo_daily.py 233) | scalp_events 55-97; engine 2003-2027 | verified |
| A13 | Existing payload tests use `AssertContains` (S2, SN11), so a new key does not break them | tests 4229-4250, 5163-5176 | verified |
| A14 | Rolls are exit moves: the ADR-160 gate, ADR-158 breaker and API entry stop block ENTRIES only (`Grind_EntriesBlocked`, engine 864-868; T3b). The real re-add after a rolled fill is an entry and all three block it | engine 864-868; tests_adr152 311-320 | verified |
| A15 | Session window (Q2): a roll only moves an exit, so it runs outside ADR-161's window. Fleet C does not run the lattice | operator Q2 via previous chat | decided |
| A16 | With `InpVirtualLattice` ON, `InpAutoEject` must be OFF or OnInit refuses (ADR s7). Cycle 3 and Fleet B presets have auto eject ON, so neither takes the lattice by preset alone | ADR s7; fxgrind.mq5 25 | verified |
| A17 | OPERATOR (2026-09-25): no layer is ever rolled twice, by any path. "Roll here" is DEFERRED (backlog, after B has run live); keep the roll ONE function the trigger calls | previous chat, answer 2 | decided |

## WHAT B1 IS

Behind `InpVirtualLattice` (default false), on each tick, per side AT CAP
(depth >= InpMaxLayers; Q1: never for a gate-blocked add below cap):

    level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips))
    while ask <= level (long) / bid >= level (short):
        idx = oldest unrolled layer; none -> stop (every layer rolled once)
        candidate's exit already filled (CloseBy pending) -> stop
        roll idx to level (below); on MODIFY_FAILED -> backoff 60 s, stop
        level = next level (recomputed; the queue ran inside the roll)

Roll of layer idx to `level` (one function; source "auto"):

    formula = Grind_ExitPrice(level, exit_pips, _Point, dir) + Grind_CarryAccruedGet(pos)
    price   = formula; clamped = Grind_ExitQClampPassive(is_long, formula, price)
    Branch M (live exit order): modify it to price; on failure report
      ROLL_REFUSED and return MODIFY_FAILED with NOTHING stored. On success:
      VLSet(pos, level); EjectOffsetDelete(pos); exit_target = price;
      if(clamped || |price - formula| > 0.5 point) CarryRecordShift(pos,
      price - formula, true) else CarryShiftDelete(pos)   (as engine 2463-2467)
    Branch S (no exit order, no exit position): VLSet; EjectOffsetDelete;
      CarryShiftDelete; exit_target = formula (the queue places and records)
    Both: archive ROLL_ACCEPTED, then Grind_ExitQManageSide(side, ...).

## COMMIT 1 -- TESTS AGAINST STUBS

New file `ea/fxgrind_tests_adr162b.mqh`, included from `fxgrind_tests.mq5`
directly after `#include "fxgrind_tests_adr162.mqh"` (line 21); register
every test in `OnStart` directly after `Test_VL16_ParseL100();` (line 9290),
in the order below. Change `Test_VL12_PruneOrphanVL` as specified (the ONLY
existing test that changes). No other existing test changes.

Stubs and declarations, bodies TRIVIAL (no logic in the stub commit):

    // grind_pure.mqh, directly after Grind_AutoEjectWindowIntact (384-388)
    #define GRIND_ROLL_OK             0
    #define GRIND_ROLL_MODIFY_FAILED  1
    #define GRIND_ROLL_CLOSING        2
    #define GRIND_ROLL_ALREADY_ROLLED 3
    bool   Grind_ValidateLatticeInputs(const bool lattice, const bool auto_eject) { return true; }
    bool   Grind_LatticeLevelCrossed(const bool is_long, const double price,
                                     const double level) { return false; }
    double Grind_LatticeRollCost(const double entry, const double level,
                                 const double exit_pips, const double point,
                                 const bool is_long) { return 0.0; }
    // grind_config.mqh
    #define GRIND_VL_RETRY_BACKOFF_SEC     60
    #define GRIND_VL_RETRY_BACKOFF_MAX_SEC 1800
    // grind_engine.mqh, directly after Grind_AutoEjectOnTick (623-680)
    datetime g_grind_vl_backoff_long  = 0;
    datetime g_grind_vl_backoff_short = 0;
    int      g_grind_vl_fail_count_long  = 0;
    int      g_grind_vl_fail_count_short = 0;
    void   Grind_LatticeResetBackoff() { g_grind_vl_backoff_long = 0; g_grind_vl_backoff_short = 0;
                                         g_grind_vl_fail_count_long = 0; g_grind_vl_fail_count_short = 0; }
    int    Grind_LatticeCandidateIndex(const GrindSideState &side, const bool is_long) { return -1; }
    string Grind_LatticeRollDetail(const ulong ticket, const bool is_long, const int layer_index,
                                   const double entry, const double level, const double target,
                                   const double accrued, const bool clamped, const double cost,
                                   const int rolled, const bool was_ejected, const string source)
                                                                          { return ""; }
    int    Grind_LatticeRollLayer(GrindSideState &side, const bool is_long, const int idx,
                                  const ulong magic, const string slot, const double lots,
                                  const double exit_pips, const double level,
                                  const string source)                    { return -1; }
    int    Grind_LatticeTrySide(GrindSideState &side, const bool is_long, const ulong magic,
                                const string slot, const double lots, const double exit_pips,
                                const double add_pips, const int max_layers, const bool enabled,
                                const bool blocked, const datetime now)   { return 0; }
    void   Grind_LatticeOnTick(const ulong magic, const string slot, const double lots,
                               const bool enabled, const double exit_pips, const double add_pips,
                               const int max_layers, const bool blocked, const datetime now) { }
    // grind_scalp_events.mqh: add `const bool rolled = false` as the LAST
    // parameter of Grind_BuildScalpClosedPayload (55) and
    // Grind_QueueScalpClosedEvent (100); the queue passes it through. The
    // payload body does NOT change in this commit.

Test helpers in the new file (not tests; no assertions):

- `Adr162b_Reset()`: `Grind_TestEjectHarnessReset(); Grind_ArchiveTestReset();
  Grind_LatticeResetBackoff(); Adr151_TestResetAll();
  g_grind_order_test_send_ok = true;`
- `Adr162b_SeedLong8()`: `Adr162b_Reset()`; `g_grind_order_test_active = true`;
  `Adr151_TestSeedSlotSeams(200, 100, 0)`; `Grind_ArchiveTestConfigureCommon()`;
  for i = 0..7 `Adr151_TestSetupLongLayer(g_grind_long, i, i,
  NormalizeDouble(1.21400 - 0.00100 * i, 5), 7001 + i, 0, 5.0)` (L0 1.21400
  ... L7 1.20700); then give L0 exit ticket 8001 and L7 exit ticket 8008 and
  `Grind_OrderTestUpsert` each at its `exit_target` (1.21450, 1.20750),
  SELL_LIMIT, comment `GrindCommentBuild("OPT","L",idx,"EXT")`.
- `Adr162b_SeedShort8()`: same shape on `g_grind_short`, set by hand (the
  Adr151 helper is long-only): S0 1.18600 ... S7 1.19300 (+0.00100 per i),
  tickets 7101+i, `exit_target = Grind_ExitQFormulaTarget(entry, 5.0,
  _Point, false, pos)`; S0 exit 8101 (1.18550), S7 exit 8108 (1.19250),
  BUY_LIMIT.
- `Adr162b_RefreshExit(side, is_long, arr_idx, order_ticket)`: recompute
  `exit_target` with `Grind_ExitQFormulaTarget` (so GVs set after the seed
  are reflected), set the layer's `exit_order_ticket`, upsert the order there.
- `Adr162b_ArchiveFind(code, nth)`: the nth archive queue entry
  (`Grind_ArchiveQueuePeek`, 0..`Grind_ArchiveQueueCount()`-1) containing
  `code`, or "". Assert on substrings only (the detail may be escaped).
- TRY(side, is_long, now) below means `Grind_LatticeTrySide(side, is_long,
  22260101UL, "OPT", 0.01, 5.0, 10.0, 8, true, false, now)`, now =
  `D'2026.09.28 10:00'` unless stated. Market: `Grind_MarketTestSeed(bid,
  ask, stops, 0)`. Every test ends with `Adr162b_Reset()`.

Prices: point 0.00001, 1 pip = 10 points, exit 5 pips, add 10 pips, cap 8
(the ADR s3 example at 1.2xxxx). Every expected value is derived by hand;
do not change one to match output.

| test | setup | assertion (name: expected) | stub |
|---|---|---|---|
| LB1_ValidateInputs | none | "LB1 both on refused": `Grind_ValidateLatticeInputs(true,true)` false | FAIL |
| | | "LB1 lattice only": `(true,false)` true | PASS |
| | | "LB1 auto only": `(false,true)` true | PASS |
| | | "LB1 both off": `(false,false)` true | PASS |
| LB2_LevelCrossed | none | "LB2 long above": `(true,1.20640,1.20600)` false | PASS |
| | | "LB2 long at": `(true,1.20600,1.20600)` true | FAIL |
| | | "LB2 long through": `(true,1.20190,1.20600)` true | FAIL |
| | | "LB2 short below": `(false,1.19390,1.19400)` false | PASS |
| | | "LB2 short at": `(false,1.19400,1.19400)` true | FAIL |
| LB3_RollCost | none | "LB3 long": `(1.21400,1.20600,5.0,0.00001,true)` = 0.00750 | FAIL |
| | | "LB3 short": `(1.18600,1.19400,5.0,0.00001,false)` = 0.00750 | FAIL |
| | | "LB3 non-uniform": `(1.21350,1.20600,5.0,0.00001,true)` = 0.00700 | FAIL |
| LB4_Candidate | SeedLong8 | "LB4 oldest": `Grind_LatticeCandidateIndex(g_grind_long,true)` == 0 | FAIL |
| | `Grind_VLSet(7001,1.20600)` | "LB4 next unrolled": == 1 | FAIL |
| | VL on 7001+i = 1.20600 - 0.00100*i, i=0..7 | "LB4 all rolled": == -1 | PASS |
| | SeedShort8 | "LB4 short oldest": `(g_grind_short,false)` == 0 | FAIL |
| LB5_ThroughEntryNotExit | SeedLong8; market 1.20630/1.20640; TRY long | "LB5 no roll": rc == 0 | PASS |
| | | "LB5 no vl": `!Grind_VLHas(7001)` | PASS |
| | | "LB5 no modify": `g_grind_order_test_modify_calls == 0` | PASS |
| LB6_SingleRoll | SeedLong8; market 1.20590/1.20600; rc = TRY long | "LB6 one roll": rc == 1 | FAIL |
| | | "LB6 vl": `Grind_VLGet(7001)` = 1.20600 | FAIL |
| | | "LB6 exit price": `Grind_OrderGetPriceOpen(8001)` = 1.20650 | FAIL |
| | | "LB6 exit_target": L0 `exit_target` = 1.20650 | FAIL |
| | | "LB6 formula agrees": `Grind_ExitQFormulaTarget(1.21400,5.0,_Point,true,7001)` = price of 8001 | PASS |
| | | "LB6 I6 ok": `Grind_ReconExitMatchesEntry(1.21400, price of 8001, 5.0, _Point, true, 0.0, false, 7001)` true | PASS |
| | | "LB6 no shift": `!GlobalVariableCheck("GRIND_CARRY_SHIFT_7001")` | PASS |
| | | "LB6 old rank0 cancelled": L7 `exit_order_ticket` == 0 | FAIL |
| | | "LB6 new highest placed": L1 `exit_order_ticket` != 0 | FAIL |
| | | "LB6 calls": modify == 1 AND remove == 1 AND place == 1 | FAIL |
| | | "LB6 accepted archived": `Adr162b_ArchiveFind("ROLL_ACCEPTED",0)` contains "7001" | FAIL |
| | | "LB6 cost archived": same entry contains "0.00750" | FAIL |
| | | "LB6 source archived": same entry contains "auto" | FAIL |
| LB7_GapFiresEveryLevel | SeedLong8; market 1.20180/1.20190; rc = TRY long | "LB7 five rolls": rc == 5 | FAIL |
| | | "LB7 vl L0": `Grind_VLGet(7001)` = 1.20600 | FAIL |
| | | "LB7 vl L4": `Grind_VLGet(7005)` = 1.20200 | FAIL |
| | | "LB7 L5 unrolled": `!Grind_VLHas(7006)` | PASS |
| | | "LB7 two resting": `Adr151_TestCountRestingExits(g_grind_long) == 2` | PASS |
| | | "LB7 newest rolled rests": L4 exit != 0 AND its price = 1.20250 | FAIL |
| | | "LB7 oldest unrolled rests": L5 exit != 0 AND its price = 1.20950 | FAIL |
| | | "LB7 calls": modify == 5 AND remove == 5 AND place == 5 | FAIL |
| | | "LB7 in order": for k = 0..4 `ArchiveFind("ROLL_ACCEPTED",k)` contains `IntegerToString(7001+k)` (one AND) | FAIL |
| LB8_NoReroll | SeedLong8; VL on all 8 as in LB4; `Adr162b_RefreshExit` L0 (8001) and L7 (8008); market 1.19000/1.19010; TRY long | "LB8 no reroll": rc == 0 | PASS |
| | | "LB8 no modify": modify == 0 | PASS |
| | | "LB8 L0 level kept": `Grind_VLGet(7001)` = 1.20600 | PASS |
| LB9_BelowCap | SeedLong8; `ArrayResize(g_grind_long.layers, 7)`; L6 exit 8007 via RefreshExit; market 1.19000/1.19010; TRY long | "LB9 below cap no roll": rc == 0 | PASS |
| | | "LB9 no vl": `!Grind_VLHas(7001)` | PASS |
| LB10_EntryBlocksDoNotBlockRolls | as T3b: `Adr152_TestPrepareIsolation(); Grind_ApiCounterTestSeed(GRIND_DAILY_API_ENTRY_STOP);` THEN SeedLong8; market 1.20590/1.20600; TRY long; end with `Adr152_TestResetAll()` | "LB10 entries blocked": `Grind_EntriesBlocked()` true | PASS |
| | | "LB10 rolls anyway": rc == 1 | FAIL |
| | | "LB10 vl": `Grind_VLHas(7001)` | FAIL |
| LB11_BlockedAndOff | SeedLong8; market 1.20590/1.20600 | "LB11 blocked": TrySide with blocked=true == 0 | PASS |
| | | "LB11 switch off": TrySide with enabled=false == 0 | PASS |
| | | "LB11 inert": modify == 0 AND `!Grind_VLHas(7001)` | PASS |
| LB12_ClampRecordsShift | SeedLong8; market 1.20590/1.20600, stops 100 (min dist 0.00100); TRY long | "LB12 clamped price": price of 8001 = 1.20700 | FAIL |
| | | "LB12 shift": `Grind_CarryShiftGet(7001)` = 0.00050 | FAIL |
| | | "LB12 release marker": `GlobalVariableCheck(GRIND_CARRY_RELEASE_PREFIX + "7001")` | FAIL |
| | | "LB12 I6 ok": `Grind_ReconExitMatchesEntry(1.21400, 1.20700, 5.0, _Point, true, Grind_CarryShiftGet(7001), false, 7001)` true | FAIL |
| LB13_AccruedCarried | SeedLong8; `Grind_CarryAccruedSet(7001, 0.00010)`; RefreshExit L0; market 1.20590/1.20600; TRY long | "LB13 target": price of 8001 = 1.20660 | FAIL |
| | | "LB13 accrued kept": `Grind_CarryAccruedGet(7001)` = 0.00010 | PASS |
| | | "LB13 formula agrees": `Grind_ExitQFormulaTarget(1.21400,5.0,_Point,true,7001)` = 1.20660 | FAIL |
| LB14_EjectedCandidate | SeedLong8; `Grind_EjectOffsetSet(7001, 0.00200)`; `Grind_CarryShiftSet(7001, 0.00003)`; RefreshExit L0; market 1.20590/1.20600; TRY long | "LB14 target": price of 8001 = 1.20650 | FAIL |
| | | "LB14 offset gone": `!Grind_EjectIsEjected(7001)` | FAIL |
| | | "LB14 shift gone": `!GlobalVariableCheck("GRIND_CARRY_SHIFT_7001")` | FAIL |
| LB15_ModifyFailBackoff | SeedLong8; market 1.20590/1.20600; `g_grind_order_test_send_ok = false`; rc1 = TRY(now) | "LB15 first no roll": rc1 == 0 | PASS |
| | | "LB15 attempted once": modify == 1 | FAIL |
| | | "LB15 no vl": `!Grind_VLHas(7001)` | PASS |
| | | "LB15 exit unchanged": price of 8001 = 1.21450 | PASS |
| | | "LB15 refused archived": `ArchiveFind("ROLL_REFUSED",0)` contains "MODIFY_FAILED" | FAIL |
| | rc2 = TRY(now + 30) | "LB15 backoff holds": modify still == 1 | FAIL |
| | send_ok still false; TRY(now + 61) | "LB15 second attempt": modify == 2 | FAIL |
| | TRY(now + 180) (second wait is 120 s: until now + 181) | "LB15 doubled backoff holds": modify still == 2 | FAIL |
| | send_ok = true; rc3 = TRY(now + 181) | "LB15 retry after backoff": rc3 == 1 | FAIL |
| LB16_ShortSingleRoll | SeedShort8; market 1.19390/1.19400; TRY short | "LB16 below level": rc == 0 | PASS |
| | market 1.19400/1.19410; rc = TRY short | "LB16 one roll": rc == 1 | FAIL |
| | | "LB16 vl": `Grind_VLGet(7101)` = 1.19400 | FAIL |
| | | "LB16 exit price": price of 8101 = 1.19350 | FAIL |
| | | "LB16 old rank0 cancelled": S7 `exit_order_ticket` == 0 | FAIL |
| | | "LB16 new highest placed": S1 `exit_order_ticket` != 0 | FAIL |
| LB17_ClosingCandidate | SeedLong8; L0 `exit_order_ticket = 0`, `exit_position_ticket = 9999`; market 1.20590/1.20600; TRY long | "LB17 closing no roll": rc == 0 | PASS |
| | | "LB17 no vl anywhere": `!Grind_VLHas(7001) && !Grind_VLHas(7002)` | PASS |
| LB18_CandidateWithoutExit | SeedLong8; VL on 7001..7006 = 1.20600 ... 1.20100; overwrite arr 6 with `Adr151_TestSetupLongLayer(g_grind_long, 6, 8, 1.20000, 7009, 0, 5.0)` and arr 7 with `(.., 7, 9, 1.19900, 7010, 0, 5.0)`; RefreshExit arr 0 (8001) and arr 7 (8010); market 1.19790/1.19800; rc = TRY long | "LB18 one roll": rc == 1 | FAIL |
| | | "LB18 vl": `Grind_VLGet(7009)` = 1.19800 | FAIL |
| | | "LB18 no modify": modify == 0 | PASS |
| | | "LB18 exit placed": arr 6 exit != 0 AND its price = 1.19850 | FAIL |
| | | "LB18 old rank0 cancelled": arr 7 `exit_order_ticket` == 0 | FAIL |
| LB19_OnTickWiring | SeedLong8; market 1.20590/1.20600; `Grind_LatticeOnTick(22260101UL,"OPT",0.01,false,5.0,10.0,8,false,now)` | "LB19 off inert": `!Grind_VLHas(7001)` | PASS |
| | same with enabled = true | "LB19 on rolls long": `Grind_VLHas(7001)` | FAIL |
| LB20_VLHasTicketZero | `Grind_TestResetSideState()`; literal GV `"GRIND_VL_0"` = 1.0 | "LB20 ticket 0": `!Grind_VLHas(0)` | FAIL |
| | long arr 0: index 2, entry 1.10400, ticket 0; arr 1: index 1, entry 1.10300, ticket 5002 (Adr151 helper) | "LB20 anchor": `Grind_ComputeAddTarget(g_grind_long,true,10.0)` = 1.10300 | FAIL |
| LB21_PruneScope | `Grind_TestClearCarryState()`; order-test on; literal GV `"GRIND_EJECT_OFFSET_8889"` = 0.00100; `Grind_CarryPruneShiftGvs(22260101UL)` | "LB21 offset still pruned": GV gone | PASS |
| LB22_CommandRanksRolled | `Grind_TestEjectHarnessReset()`; order-test, send_ok; L0 1.10500 t1001 exit 2001, L1 1.10400 t1002 exit 2002, L2 1.10300 t1003 no exit; `Grind_VLSet(1001,1.10000)`; exits upserted at formula (2001 1.10030, 2002 1.10430); market 1.10100/1.10110; command GV = 1001, `Grind_EjectPollCommand(22260101UL,true,3.0,false)` | "LB22 rolled not deepest": == GRIND_EJECT_NOT_DEEPEST | PASS |
| | command GV = 1002, poll again | "LB22 oldest unrolled ejectable": == GRIND_EJECT_OK | PASS |
| LB23_AutoRanksRolled | E9 verbatim (tests 7493-7511) plus `Grind_VLSet(1001UL, 1.24800)` before the `Grind_AutoEjectTrySide` call | "LB23 rc": == GRIND_EJECT_OK | PASS |
| | | "LB23 picks by effective": price of 2002 = 1.24811 AND price of 2001 = 1.25030 | PASS |
| LB24_I6ShortRolled | `Grind_TestClearCarryState()`; `Grind_VLSet(1002,1.11000)` | "LB24 short rolled ok": `ReconExitMatchesEntry(1.10500,1.10970,3.0,0.00001,false,0.0,false,1002)` true | PASS |
| | | "LB24 short actual rejected": same with exit 1.10470 false | PASS |
| LB25_QueueShortRolled | VL7 pattern, short: market 1.11010/1.11012; S0 1.10500 t5401 VL 1.11000, S1 1.10600 t5402, S2 1.10700 t5403, S3 1.10800 t5404, no exits; `Grind_ExitQManageSide(g_grind_short,false,22260101UL,"OPT",0.01,3.0)` | "LB25 rolled S0 rests" | PASS |
| | | "LB25 oldest unrolled S1 rests" | PASS |
| | | "LB25 S3 bare" | PASS |
| | | "LB25 rolled exit price": S0 `exit_target` = 1.10970 | PASS |
| LB26_CarryBaseShortRolled | VL10 verbatim with the side flipped: short 1.10500 t1001 exit 2001; VL 1.11000; re-set the VL after PassBegin as VL10 does | "LB26 one work item" | PASS |
| | | "LB26 base": `g_grind_carry_exit_work_formula[0]` = 1.10970 | PASS |
| | | "LB26 shift base": `Grind_CarryWorkBase(0,3.0,0.00001)` = 1.10970 | PASS |
| LB27_SignGuardShort | `Grind_TestClearCarryState()`; `Grind_VLSet(1001,1.11000)` | "LB27 short rolled not blocked": `!Grind_CarrySignGuardAppliesAtShift(1001,1.10500,1.10970,false)` | PASS |
| | | "LB27 short ordinary blocked": `Grind_CarrySignGuardAppliesAtShift(1002,1.10500,1.10970,false)` | PASS |
| LB28_AnchorShort | `Grind_TestResetSideState()`; short arr 0 idx 0 1.10500 t5501, arr 1 idx 1 1.10600 t5502 | "LB28 unrolled": `Grind_ComputeAddTarget(g_grind_short,false,10.0)` = 1.10700 | PASS |
| | `Grind_VLSet(5501,1.11000)` | "LB28 rolled": = 1.11100 | PASS |
| LB29_CloseRolledFlag | VL13 verbatim (pos 99207, VL literal GV) plus `Grind_ArchiveTestConfigureCommon()` before `Grind_HandleSideDealFill` | "LB29 rolled true": `Grind_ScalpEventQueuePeek()` contains `"rolled":true` | FAIL |
| | | "LB29 ejected false": contains `"ejected":false` | PASS |
| | | "LB29 roll filled archived": `ArchiveFind("ROLL_FILLED",0)` contains "99207" | FAIL |
| | S2's twelve arguments, no 13th | "LB29 unrolled payload": `Grind_BuildScalpClosedPayload(...)` contains `"rolled":false` | FAIL |
| LB30_RestartRolledStartup | VL8's six tickets; `Grind_VLSet(1001,1.10000)`; `Grind_RebuildBookFromTickets(tickets,6,22260101UL,"OPT",3.0,12,0.00001,long_out,short_out,reason,true)` | "LB30 startup ok": true | PASS |
| | | "LB30 rolled target": `long_out` layer with position 1001 has `exit_target` = 1.10030 | PASS |
| | same minus ticket 2001 (5 tickets), `true` | "LB30 shortfall tolerated": true AND `g_grind_recon_exit_shortfall_long == 1` | PASS |
| | same 5 tickets, `false` | "LB30 strict fails": false | PASS |
| LB31_RollDetail | `Grind_LatticeRollDetail(7001UL,true,0,1.21400,1.20600,1.20650,0.0,false,0.00750,1,true,"auto")` | "LB31 ticket": contains `"ticket":7001` | FAIL |
| | | "LB31 side": contains `"side":"L"` | FAIL |
| | | "LB31 level": contains `"level":1.20600` | FAIL |
| | | "LB31 target": contains `"target":1.20650` | FAIL |
| | | "LB31 cost": contains `"cost":0.00750` | FAIL |
| | | "LB31 cost pips": contains `"cost_pips":75.0` | FAIL |
| | | "LB31 rolled": contains `"rolled":1` | FAIL |
| | | "LB31 was ejected": contains `"was_ejected":true` | FAIL |
| | | "LB31 source": contains `"source":"auto"` | FAIL |

**VL12 (existing test, deliberate spec change, NOT an expected value
adjusted to output).** B2 is decided as close-path-only (A10): a VL must not
be lost to the prune, and an orphan VL is keyed by a ticket that is never
reused, so it is never read; `grind_gv_clean` removes it at close-out. In
`Test_VL12_PruneOrphanVL` replace the one assertion
`AssertFalse("VL12 orphan pruned", ...)` with
`AssertTrue("VL12 orphan kept", GlobalVariableCheck("GRIND_VL_8888"))` and
delete the GV at the end of the test. Stub: FAIL (the prune still deletes).

| test | setup | assertion (name: expected) | stub |
|---|---|---|---|
| VL12_PruneOrphanVL (changed) | unchanged | "VL12 orphan kept" | FAIL* |

Predicted (the operator runs both on GBPUSD and EURUSD; you do NOT run
them): baseline 1875. Stub commit **1929/1998**, failing exactly the 68 FAIL
rows plus VL12 (69); real commit **1998/1998**. The 55 PASS rows pass in
both states BY DESIGN (inertness, preconditions, and B3's regression locks
on Phase A sites); list them in your report as such.

## COMMIT 2 -- IMPLEMENTATION

1. `grind_pure.mqh`: `Grind_ValidateLatticeInputs` = `!(lattice &&
   auto_eject)`. `Grind_LatticeLevelCrossed`: long `price <= level +
   GRIND_PRICE_EPS`; short `price >= level - GRIND_PRICE_EPS`.
   `Grind_LatticeRollCost`: long `entry - Grind_ExitPrice(level, exit_pips,
   point, 1)`; short `Grind_ExitPrice(level, exit_pips, point, -1) - entry`.
2. `Grind_VLHas` (carry 597): `false` when `position_ticket == 0` (B1).
3. Prune (carry 997-999): delete the `GRIND_VL_` branch (B2). Nothing else
   in the prune changes. `scripts/grind_gv_clean.mq5` keeps `GRIND_VL_`.
4. `Grind_LatticeCandidateIndex`: over layers with `position_ticket != 0`
   and `!Grind_VLHas(position_ticket)`: long the highest `entry_price`,
   short the lowest; tie -> lower `layer_index`; none -> -1.
5. `Grind_LatticeRollDetail`: JSON object with keys in this order:
   `ticket`, `side` ("L"/"S"), `layer_index`, `entry`, `level`, `target`,
   `accrued`, `clamped`, `cost`, `cost_pips` (cost / (10 * _Point), 1 dp),
   `rolled`, `was_ejected`, `source`. Prices with
   `Grind_ArchiveJsonDouble(x, 5)`; `entry` is the ACTUAL entry (G1).
6. `Grind_LatticeRollLayer` exactly as "WHAT B1 IS" (branches M and S).
   Refuse `GRIND_ROLL_ALREADY_ROLLED` if the layer already holds a VL and
   `GRIND_ROLL_CLOSING` if `exit_position_ticket != 0` (defence in depth;
   the trigger never asks). `was_ejected` is read BEFORE the offset is
   deleted. `rolled` = layers on the side holding a VL after the roll.
   Reports via `Grind_EjectReport` (engine 912): `ROLL_ACCEPTED` with the
   detail; `ROLL_REFUSED` with `{"ticket":..,"reason":"MODIFY_FAILED",
   "level":..,"source":..}`. Then `Grind_ExitQManageSide(side, is_long,
   magic, slot, lots, exit_pips)` (branch M and S alike).
7. `Grind_LatticeTrySide`: return 0 if `!enabled || blocked`, or `now <`
   the side's backoff. Loop at most `max_layers` times: stop if depth <
   `max_layers`; `level = Grind_Normalize(Grind_ComputeAddTarget(...))`,
   stop if `level <= 0`; price = ask (long) / bid (short) from
   `Grind_MarketAsk/Bid`; stop if not crossed; idx = candidate, stop if -1;
   stop if its `exit_position_ticket != 0`; roll with source "auto"; on
   `GRIND_ROLL_MODIFY_FAILED`: increment the side's fail count n, set the
   side's backoff to `now + MathMin(GRIND_VL_RETRY_BACKOFF_SEC * 2^(n-1),
   GRIND_VL_RETRY_BACKOFF_MAX_SEC)` (60, 120, 240 ... 1800 s) and stop; on
   `GRIND_ROLL_OK` set n = 0, count and continue.
   Return the count.
8. `Grind_LatticeOnTick`: return if `!enabled || blocked`; TrySide long
   then short, each only when that side's depth >= `max_layers`.
9. `fxgrind.mq5`: `input bool InpVirtualLattice = false; // ADR-162
   virtual lattice past cap` after line 27. In OnInit directly after the
   `InpMagic == 0` block (136-139): if `!Grind_ValidateLatticeInputs(
   InpVirtualLattice, InpAutoEject)` Print `FATAL: InpVirtualLattice
   requires InpAutoEject=false (ADR-162 s7)` and return INIT_FAILED. After
   the GRIND_SESSION Print (254-256): `Print("GRIND_LATTICE enable=",
   InpVirtualLattice)` and `Grind_ArchiveMarker("INFO", "LATTICE_CONFIG",
   "", 0, "{\"enable\":true|false}")`. In OnTick directly after
   `Grind_AutoEjectOnTick(...)` (320-322): `Grind_LatticeOnTick(InpMagic,
   InpSlot, InpLots, InpVirtualLattice, InpExitPips, InpAddPips,
   InpMaxLayers, g_grind_halted || g_grind_quarantined, TimeCurrent());`
10. B4, `grind_scalp_events.mqh`: payload gains `"rolled":%s` directly
    after `"ejected":%s` (line 80), from the new parameter. Close path
    (engine 2003): `const bool was_rolled = Grind_VLHas(closed_position);`
    beside `was_ejected`, passed to the queue; if `was_rolled`,
    `Grind_EjectReport("ROLL_FILLED", closed_position,
    {"ticket":..,"level":<Grind_VLGet before delete>})` after the
    EJECT_FILLED block. Deletions at 2023-2026 unchanged.

## NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run
  the suite (the operator compiles in the MetaEditor GUI; suite figures are
  pending), do not `git stash`, do not check out files from other commits,
  do not merge, no PR, no `git add .` or `-u`.
- PUSH THE BRANCH: `git push -u origin adr162-phase-b1` after each commit.
  A local-only branch cannot be verified.
- No existing test, expected value or registration changes EXCEPT VL12 as
  specified.
- No M1 catch-up, no bars, no `CopyRates`, no ROLL_STRANDED, no roll
  command, no script, no "roll here" (B2 / deferred).
- Never roll a layer that holds a VL. Never re-roll. Never roll below cap.
- Do not route rolls through `Grind_EntriesBlocked`, the breaker, the
  gate, the API entry stop or the session window (A14, A15).
- Do not change ADR-155 or ADR-157 logic, `Grind_ExitQManageSide`,
  `Grind_ComputeAddTarget`, or any exit-price formula.
- Do not store the VL before the modify succeeds (branch M).
- Do not add the input to `Grind_ConfigDumpString` or
  `Grind_ArchiveConfigFields` (their tests pin their fields).
- Nothing outside `ea/`. No presets, no docs (Claude writes the ADR,
  backlog and handoff), no pipshed.

## FAILURE MODES -- STOP AND REPORT

- A line cited above does not hold the code described (drift): STOP.
- Any existing test other than VL12 would need a change to compile or
  pass: STOP.
- A helper named above does not exist or has another signature
  (`Adr151_TestSetupLongLayer`, `Grind_ArchiveTestConfigureCommon`,
  `Grind_TestEjectFixtureDepth2`, `Adr152_TestPrepareIsolation`): STOP.
- In order-test mode the queue does not place or cancel as LB6 predicts:
  STOP; do not reshape the test around it.
- LB10's precondition ("entries blocked") is false after the seed: STOP.
- You find another place that reasons about grid levels (a price compared
  with an entry to decide an order) not listed here or in ADR-162 s12: do
  not change it; report file and line.
- A stub body needs logic to compile: STOP.

## REPORT

Both commit hashes (pushed); `git diff --stat main..adr162-phase-b1`; each
test by name with its assertion names; the PASS-in-both list; any unlisted
site.

## FOR GEMINI -- RULE BEFORE CURSOR STARTS

Premises: VERIFIED = read in source by Claude; OPERATOR = his decision.

- **GB1. Write order.** Modify first, VL after success (A6). A crash in
  the <= 1 s between a successful modify and the GV flush leaves the exit
  at the rolled price with no VL: I6 then fails on that layer and the
  instance quarantines (fail closed, operator repairs). The alternative,
  VL first with rollback, has the same window the other way round.
  Accept modify-first?
- **GB2. B2 = close path only** (A10), flipping VL12 deliberately. The
  offset and carry GVs keep the same prune premise; left alone here
  (backlog note). Accept?
- **GB3. Rolling a hand-ejected layer** deletes its offset and carry shift
  (A7); the lattice exit supersedes the eject. Accept, or should the
  trigger wait while the candidate is ejected (which stalls the lattice)?
- **GB4. B4 flag.** New `rolled` key (pipshed reads it later) rather than
  reusing `ejected=true`, which would count every rolled fill in
  `eject_mismatch` (A12). Accept?
- **GB5. Backoff** (SUPERSEDED by the amendment below; kept as asked) 60 s fixed per side after MODIFY_FAILED, no retry cap;
  retries are tick-driven, so none while the market is closed (A8). Worst
  case while failing: 60 requests per hour per side. Accept, or cap it?
- **GB6. Candidate** = oldest unrolled by ACTUAL entry, even when it is a
  middle rank without an exit (branch S: VL, then the queue places); a
  candidate whose exit has filled blocks the side for that tick rather
  than passing the roll to the next layer (A4). Accept?
- **GB7. The virtual level is `Grind_ComputeAddTarget`** (A3), i.e. the
  real add's anchor, including Phase A's index path for an unrolled book
  (GA1). Accept?
- **GB8. Tick path only in B1.** A crossing between ticks is caught on the
  next tick while price is still beyond; a round trip between ticks is
  missed until B2's catch-up. B1 is not deployed without B2. Accept?
- **GB9. Session window** (OPERATOR Q2, inferred from ADR-161): rolls run
  outside the window; Fleet C does not run the lattice. Accept?

## GEMINI RULINGS (2026-09-25) -- ALL NINE ACCEPTED; GB5 AMENDED BY CLAUDE

Condensed; every reason checked in source by Claude. Build as written
above, which already includes the GB5 amendment.

- **GB1 ACCEPTED** (modify first, VL after success).
- **GB2 ACCEPTED** (close path only; VL12 flipped). His reason is wrong:
  a lost VL does NOT move the order or cause an "offside fill"; the
  queue never re-prices a live exit (A1), so the order stays at the
  rolled price and I6 quarantines. The conclusion stands on that.
- **GB3 ACCEPTED** (the roll deletes offset and carry shift; accrued is
  kept, so the new target is not "pure").
- **GB4 ACCEPTED** (new `rolled` key).
- **GB5 ACCEPTED ON A WRONG PREMISE, AMENDED.** He reasoned that 1,440
  failed retries a day per side "sits safely underneath the 2,000/day
  limit". The limit is one terminal-wide count shared by all eleven
  instances (`GRIND_DAILY_API_COUNT`, no magic suffix; C31: 506 -> 1,906
  on 23 Sep), and at 1900 the entry stop halts entries on EVERY instance
  for the rest of the day. Amendment: the backoff doubles per consecutive
  failure on a side (60, 120 ... capped at 1800 s), reset on success;
  worst case about 50 attempts per side per day. LB15 gains two rows.
- **GB6 ACCEPTED.** The reason is not "funding spread": the oldest
  unrolled layer is the most underwater one and holds the live highest-
  rank exit the barbell needs.
- **GB7 ACCEPTED.**
- **GB8 ACCEPTED**: B1 is not deployed without B2 (already stated).
- **GB9 ACCEPTED.** ADR-161's window is not about weekend gaps; the
  outcome stands because a roll only moves an exit.

**GB10 (FOR GEMINI, the only open question).** Rule on the GB5 amendment
as specified in step 7 and LB15: doubling from 60 s, capped at 1800 s,
reset on the next successful roll, per side, in memory (a restart resets
it, which costs at most one early retry). Accept, or specify otherwise.
Please answer from the facts above: the daily count is shared by the
fleet, and exits are never blocked by the entry stop.

**GB10 RULING (2026-09-25): ACCEPTED.** Gemini withdrew his GB5
arithmetic ("factually incorrect for this architecture") and accepted the
doubling backoff, in memory, per side, as specified. Checked by Claude: his
"a single failing side ... would instantly trigger the 1900 entry stop"
overstates it (1,440 alone is below 1900; it takes the fleet's normal
traffic on top, as on 23 Sep), and the cap bounds one side, not the fleet
("mathematically guarantees" is too strong). Neither changes the ruling.
No default changes: build exactly as written above.

Line count: 479
