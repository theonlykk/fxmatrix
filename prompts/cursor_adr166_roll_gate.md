This message has a line count at the bottom

# CURSOR PROMPT -- ADR-166 ROLL GATE: NO ROLL WHILE THE OPPOSITE SIDE HOLDS LAYERS (fxgrind EA)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat in
that workspace. Branch `adr166-roll-gate` from `origin/main` at the commit
that carries THIS file. `main` must already carry the v2.2a merge (branch
`v22a-recon-api`, tip `8a3ec0c`; the operator merges it before this prompt
is used). Read ADR-162 s1-s5, ADR-165 (`docs/architecture/ADR-165-continuous-reroll.md`)
s1-s5 and s9, and this prompt in full. Written by Claude from source at
`8a3ec0c` (EA code), 6 Oct ~17:30Z. Line numbers are that code.

This prompt is also the design record (ADR-166) until the merge. Gemini
reviewed it 6 Oct ~17:05Z (s9 questions; s10 his rulings, Claude's check
and the one change: RG14 added).

## 0. RESTATE AND STOP (do this first, then wait)

1. Run `git diff --stat 8a3ec0c HEAD -- ea/*.mq5 ea/*.mqh`. It must be
   EMPTY. If not, STOP and report it.
2. Restate each change in s3 in ONE line each, quoting this prompt's words,
   and list every test name in s5 with its assertion count and tags.
3. Then STOP. Do not edit anything until the operator replies "go".

## 1. WHY (operator, 6 Oct ~16:10Z)

"Having a non zero layer on the other side means we can give it more time
to get back into play. Rolling is a cost. If the market continues to move
against our 8 layers, then we make money on the single layer the other
way. As soon as we exit it, we can review rolling again."

The rule: a capped side does NOT roll (ADR-162 first roll) or re-roll
(ADR-165) while the OPPOSITE side holds more than N filled layers. N is a
new input; -1 (default) = off = today's behaviour exactly.

Premises, marked (Gemini: say which you would test differently):

| # | Premise | Kind |
|---|---|---|
| P1 | "Rolling is a cost" | OPERATOR'S JUDGEMENT. Measured (5 Oct export, IC B, C, D, 1-5 Oct, first rolls only): the 257 roll fills BOOKED -$721, but a roll cycle (sell at the rolled exit, buy back at the side's next entry) netted about +$37 against holding (median +3.3 pips a cycle). In equity this week rolling vs holding was close to a wash. This build exists to test the judgement live, scored on EQUITY (realised alone would favour the gate mechanically) |
| P2 | 250 of the 257 roll fills (97%) happened while the opposite side held >= 1 layer | MEASURED (same export); so at N = 0 rolls become rare, not occasional |
| P3 | In a continuation the opposite layer scalps OUT (its exit fills), the gate opens, and the capped side rolls on the next call, BEFORE the counter-side L0 re-fills (the gate counts filled layers, `ArraySize(side.layers)`, not resting entries) | DERIVED from source (A3, A7); it means the gate DEFERS rolls to counter-scalp moments rather than removing them. GR6-2 |
| P4 | Without a fix, the side's tick-history extreme keeps accumulating while gated; at release `Grind_LatticeTrySide` probes `min(market, extreme)` and rolls to levels the market touched DURING the deferral; the rolled exit then clamps passive at the market (C55 VC3) and fills on the next uptick: a market close at the worst point | VERIFIED in source (A4, A5) and by the existing test VC3 |

## AUDIT TRAIL (verified at `8a3ec0c`)

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | Inputs: `InpVirtualLattice` (34), `InpLatticeReroll` (35) | `ea/fxgrind.mq5` 34-35 | VERIFIED |
| A2 | `OnInit`: reroll FATAL 217-220; `Print("GRIND_REROLL enable=", ...)` 358; `LATTICE_CONFIG` detail `{"enable":%s,"reroll":%s}` 368-371; `OnTick` calls `Grind_LatticeOnTick(..., g_geo_exit_short, g_geo_add_short, InpLatticeReroll)` 457-460 | `ea/fxgrind.mq5` | VERIFIED |
| A3 | `Grind_SideDepth(side)` = `ArraySize(side.layers)`: filled layers only (resting entries are `l0_pending_ticket` / `add_pending_ticket`) | `ea/grind_engine.mqh` 1935-1938; `ea/grind_state.mqh` 17-30 | VERIFIED |
| A4 | `Grind_LatticeTrackOneSide`: below cap it resets that side's tracking, extreme, from_msc, stranded and closing latches (798-816); at cap it starts tracking from the newest layer's open time (max with now - `GRIND_VL_CATCHUP_MAX_SEC` 86400) and folds every tick since `from_msc` plus the live price into `g_grind_vl_extreme_*` | 794-888 | VERIFIED |
| A5 | `Grind_LatticeTrySide(side, is_long, magic, slot, lots, exit, add, max_layers, enabled, blocked, now, extreme = 0.0, reroll = false)`: returns 0 if disabled / blocked / in backoff (1208-1213); clears the stranded latch if an unrolled candidate exists (1215-1220); loops: level = `Grind_ComputeAddTarget`, probe = min(mkt, extreme) long / max short, crossed check, candidate, re-roll branch with pause and `Grind_LatticeMaybeStranded`, closing check, roll, backoff on modify failure; at the end resets the closing state unless it stopped on a closing layer (1308-1309); returns `rolled_count` | 1202-1311 | VERIFIED |
| A6 | `Grind_LatticeOnTick(magic, slot, lots, enabled, exit, add, max_layers, blocked, now, exit_short = 0, add_short = 0, reroll = false)`: `Grind_LatticeTrackExtremes`, then `TrySide` for each capped side with `g_grind_vl_extreme_long` / `_short` | 1314-1334 | VERIFIED |
| A7 | `Grind_LatticeMaybeStranded` emits `ROLL_STRANDED` (WARN, archive + telemetry) once per episode when the market is `GRIND_VL_STRANDED_STEPS` (2) add steps past the level; pipshed shows it amber | 1166-1199 | VERIFIED |
| A8 | `Grind_LatticeResetBackoff` (test reset only; no production caller) clears backoff, tracking, extremes, from_msc, stranded and closing latches | 896-917 | VERIFIED |
| A9 | Market time seam: `Grind_MarketTimeMsc()` returns `g_grind_market_test_time_msc` when `Grind_MarketTestSeedTimeMsc` was called; cleared only by `Grind_MarketTestReset` (NOT by `Adr162b_Reset` / `Adr151_TestResetAll`, `fxgrind_tests_adr151.mqh` 58-77) | `ea/grind_engine.mqh` 21-56 | VERIFIED |
| A10 | Pure helpers live in `ea/grind_pure.mqh`: `Grind_ValidateRerollInputs` 426-429, `Grind_LatticeRerollPaused` 431-437 | `ea/grind_pure.mqh` | VERIFIED |
| A11 | Test harness: `Adr162b_SeedLong8` (entries 1.21400 down to 1.20700, tickets 7001-7008, exits 8001 / 8008), `Adr162b_SeedShort8` (1.18600 up to 1.19300, 7101-7108, 8101 / 8108), `Adr162b_Reset`, `Adr162b_ArchiveFind`; `Adr165_Fixture` (all eight long rolled, VLs 1.20600 down to 1.19900, market 1.19000 / 1.19010), `ADR165_T0`; `C55_Reset`, `C55_OpenTimes`; `Grind_LatticeTestAddTick`; `Adr151_TestSetupLongLayer`; order-test counters `g_grind_order_test_modify_calls` etc. | `ea/fxgrind_tests_adr162b.mqh` 12-115; `fxgrind_tests_adr165.mqh` 7-33; `fxgrind_tests_c55.mqh` 8-33; `fxgrind_tests_adr151.mqh` 80-99 | VERIFIED |
| A12 | Expected values reused: LB6 (SeedLong8, market 1.20590 / 1.20600: one first roll, VL(7001) 1.20600, exit 1.20650, 1 modify / 1 remove / 1 place); RR4 (Adr165_Fixture, re-roll: VL(7001) 1.19800); VC3 (a 09:30 dip to ask 1.20590 with market 1.20700 rolls L0 at 10:00 and clamps its exit at the market) | adr162b 170-195; adr165 73-93; c55 126-138 | VERIFIED |
| A13 | Suite at `8a3ec0c`: 2525/2525 on GBPUSD and EURUSD | BOOT s6 | VERIFIED (operator's runs) |
| A14 | The log checker on the Linux boxes reads `GRIND_REROLL enable=` by pattern; a NEW line does not disturb it | `docs/runbooks/monday-night-2026-10-05.md` 39 | VERIFIED |

## 2. WHAT TO BUILD (summary)

New input `InpRollGateOpposite` (int, default -1 = off). When it is N >= 0
and the opposite side holds MORE than N filled layers, `Grind_LatticeTrySide`
returns 0 for the capped side WITHOUT rolling, re-rolling or raising
`ROLL_STRANDED`; it restarts that side's tick-history extreme at the current
market (P4), and records `ROLL_DEFERRED` (INFO) once per gated episode when
a roll was due. With the input at -1 the EA behaves exactly as `8a3ec0c`.
No new order type, no market order, no change to first-roll or re-roll
mechanics once the gate is open.

## 3. CHANGES

| # | File | Change |
|---|---|---|
| C1 | `ea/fxgrind.mq5` | after line 35: `input int    InpRollGateOpposite = -1; // ADR-166: roll / re-roll only while the opposite side holds <= N layers (-1 = off; requires lattice)` |
| C2 | `ea/grind_pure.mqh` | after `Grind_LatticeRerollPaused` (437): `bool Grind_ValidateRollGateInputs(const bool lattice, const int gate)` returns `gate == -1 \|\| (gate >= 0 && lattice)` |
| C3 | `ea/grind_pure.mqh` | after C2: `bool Grind_RollGateHolds(const int gate, const int opposite_depth)` returns `gate >= 0 && opposite_depth > gate` |
| C4 | `ea/grind_engine.mqh` | after line 706 (the closing latches): `bool g_grind_vl_deferred_noted_long = false;` and `bool g_grind_vl_deferred_noted_short = false;` |
| C5 | `ea/grind_engine.mqh` | in `Grind_LatticeTrackOneSide`'s below-cap reset (798-816): set `g_grind_vl_deferred_noted_long = false;` in the long block and `..._short = false;` in the short block. In `Grind_LatticeResetBackoff` (896-917): set both to false. Nothing else in either function changes |
| C6 | `ea/grind_engine.mqh` | after `Grind_LatticeMaybeStranded` (1199): `void Grind_LatticeRollGateRestartExtreme(const bool is_long)`: `const long t = Grind_MarketTimeMsc();` then for the side: `g_grind_vl_tracking_* = true; g_grind_vl_extreme_* = 0.0; g_grind_vl_from_msc_* = t + 1;` |
| C7 | `ea/grind_engine.mqh` | after C6: `void Grind_LatticeRollDeferredNote(const GrindSideState &side, const bool is_long, const double add_pips, const int max_layers, const int gate, const int opposite_depth)`: return if that side's `g_grind_vl_deferred_noted_*` is true, or `Grind_SideDepth(side) < max_layers`; `level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips))`; return if `level <= 0.0`; `mkt = is_long ? Grind_MarketAsk() : Grind_MarketBid()`; return unless `Grind_LatticeLevelCrossed(is_long, mkt, level)`; detail `{"side":"L"/"S","depth":<n>,"opposite_depth":<n>,"gate":<n>,"level":<5dp>,"market":<5dp>}` (doubles via `Grind_ArchiveJsonDouble(x, 5)`); `Grind_ArchiveMarker("INFO", "ROLL_DEFERRED", is_long ? "L" : "S", 0, detail); Print("INFO ROLL_DEFERRED ", detail);` set the latch true. NO `Grind_TelemetryEmit` |
| C8 | `ea/grind_engine.mqh` | `Grind_LatticeTrySide` gains two TRAILING parameters after `reroll`: `const int roll_gate = -1, const int opposite_depth = 0`. Insert immediately AFTER the backoff check (after 1213), BEFORE the stranded-latch clear (1215): `if(Grind_RollGateHolds(roll_gate, opposite_depth)) { Grind_LatticeRollGateRestartExtreme(is_long); Grind_LatticeRollDeferredNote(side, is_long, add_pips, max_layers, roll_gate, opposite_depth); return 0; }` and right after that block: `if(is_long) g_grind_vl_deferred_noted_long = false; else g_grind_vl_deferred_noted_short = false;`. The gated path touches nothing else (no closing-state reset, no stranded call, no backoff change) |
| C9 | `ea/grind_engine.mqh` | `Grind_LatticeOnTick` gains a TRAILING parameter `const int roll_gate = -1` after `reroll`; the long `TrySide` call passes `reroll, roll_gate, Grind_SideDepth(g_grind_short)`; the short call passes `reroll, roll_gate, Grind_SideDepth(g_grind_long)` |
| C10 | `ea/fxgrind.mq5` | `OnInit`, right after the reroll FATAL (220): `if(!Grind_ValidateRollGateInputs(InpVirtualLattice, InpRollGateOpposite)) { Print("FATAL: InpRollGateOpposite must be -1, or >= 0 with InpVirtualLattice=true (ADR-166)"); return INIT_FAILED; }`. After line 358: `Print("GRIND_ROLL_GATE opposite_max=", InpRollGateOpposite);` (its OWN line, A14). `LATTICE_CONFIG` detail becomes `{"enable":%s,"reroll":%s,"roll_gate":%d}`. In `OnTick` (457-460) pass `InpRollGateOpposite` as the new last argument |
| C11 | `ea/fxgrind_tests_adr166.mqh` | NEW: the tests in s5 |
| C12 | `ea/fxgrind_tests.mq5` | `#include "fxgrind_tests_adr166.mqh"` after `fxgrind_tests_v22a.mqh` (30); call the s5 tests, in order, after `Test_RN2_NoteThrottles();` (9446), before the summary |

MQL5 resolves functions defined later in the program: no forward
declarations. Every existing call site compiles unchanged (all new
parameters are trailing with defaults).

## 4. COMMITS

1. **Tests first, against stubs.** C1, C4, C10 as written; C2 STUB `return
   true;`; C3 STUB `return false;`; C5 as written; C6 and C7 STUBS (empty
   bodies); C8 and C9 add the parameters, the C8 block and the pass-through
   ONLY (with C3 stubbed the gate never holds, so behaviour is unchanged);
   C11, C12. Commit message: tests first, the predicted failures (31) and
   guards (24).
2. **Implementation:** C2, C3, C6, C7 as written. Nothing else.

Do not compile (the operator compiles and runs the suite in MetaEditor on the
desktop and reports the counts; do NOT report a suite figure yourself).

## 5. TESTS (`ea/fxgrind_tests_adr166.mqh`; F = fails at commit 1, G = guard, passes at both)

Helpers (in the new file):
- `ADR166_T0 = D'2026.09.28 10:00'`.
- `Adr166_OneShort()`: `ArrayResize(g_grind_short.layers, 1);` layer 0:
  entry 1.20800, layer_index 0, position_ticket 7101, exit_order_ticket 0,
  exit_position_ticket 0, exit_target
  `Grind_ExitQFormulaTarget(1.20800, 5.0, _Point, false, 7101UL)`.
- `Adr166_TryLong(now, reroll, gate, opp)` =
  `Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8, true, false, now, 0.0, reroll, gate, opp)`;
  `Adr166_TryShort` the same on `g_grind_short`, `false`.
- `Adr166_OnTick(now, reroll, gate)` =
  `Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, now, 5.0, 10.0, reroll, gate)`.
- "LB6 setup" = `Adr162b_SeedLong8(); Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);`
  (next level 1.20600, crossed; candidate 7001; one roll; exit 1.20650).
Every test ends with `Adr162b_Reset()` (RG13 with `C55_Reset()`); RG8
and RG13 first call `Grind_MarketTestReset()` (the market-time seam, A9,
is not cleared by `Adr162b_Reset`).

**RG1 ValidateRollGateInputs** (5): a G `(true,-1)` true; b G `(false,-1)`
true; c G `(true,0)` true; d F `(false,0)` false; e F `(true,-2)` false.

**RG2 RollGateHolds** (5): a G `(-1,8)` false; b F `(0,1)` true; c G
`(0,0)` false; d F `(2,3)` true; e G `(2,2)` false.

**RG3 first roll held** (6; LB6 setup; `Adr166_TryLong(ADR166_T0, false, 0, 1)`):
a F rc == 0; b F `Grind_VLHas(7001UL)` false; c F modify == 0; d F
`ROLL_DEFERRED` #0 != ""; e G `ROLL_STRANDED` #0 == ""; f F `ROLL_ACCEPTED`
#0 == "".

**RG4 gate open or off** (7; LB6 setup; `Adr166_TryLong(ADR166_T0, false, 0, 0)`):
a G rc == 1; b G `VLGet(7001)` == 1.20600; c G price(8001) == 1.20650; d G
`ROLL_DEFERRED` #0 == ""; e G modify == 1; f G `ROLL_ACCEPTED` #0 contains
`"auto"`; then `Adr162b_Reset();` LB6 setup, `Adr166_TryLong(ADR166_T0, false, -1, 5)`:
g G rc == 1.

**RG5 re-roll held** (4; `Adr165_Fixture()`; `Adr166_TryLong(ADR166_T0, true, 0, 1)`):
a F rc == 0; b F `VLGet(7001)` == 1.20600; c F `ROLL_DEFERRED` #0 != "";
d G `ROLL_STRANDED` #0 == "".

**RG6 threshold N = 2** (2): LB6 setup, `Adr166_TryLong(ADR166_T0, false, 2, 2)`:
a G rc == 1; `Adr162b_Reset();` LB6 setup, `Adr166_TryLong(ADR166_T0, false, 2, 3)`:
b F rc == 0.

**RG7 short mirror** (4): `Adr162b_SeedShort8(); Grind_MarketTestSeed(1.19400, 1.19410, 0, 0);`
(next level 1.19300 + 0.00100 = 1.19400, bid crosses; candidate 7101, the
lowest entry). `Adr166_TryShort(ADR166_T0, false, 0, 1)`: a F rc == 0; b F
`Grind_VLHas(7101UL)` false; then `Adr166_TryShort(ADR166_T0 + 1, false, 0, 0)`:
c G rc == 1; d G `VLGet(7101)` == 1.19400.

**RG8 extreme restarts while gated** (3): LB6 setup;
`Grind_MarketTestSeedTimeMsc(1790000000000);`
`g_grind_vl_extreme_long = 1.20190; g_grind_vl_tracking_long = false; g_grind_vl_from_msc_long = 1000;`
then `Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8, true, false, ADR166_T0, 1.20190, false, 0, 1)`:
a F `g_grind_vl_extreme_long` == 0.0; b F `g_grind_vl_tracking_long` true;
c F `g_grind_vl_from_msc_long == 1790000000001`.

**RG9 marker once per episode, re-armed** (5): LB6 setup. Call 1
`Adr166_TryLong(ADR166_T0, false, 0, 1)`: a F `ROLL_DEFERRED` #0 != "".
Call 2 `(ADR166_T0 + 1, false, 0, 1)`: b G `ROLL_DEFERRED` #1 == "". Call 3
`(ADR166_T0 + 2, false, 0, 0)`: c F rc == 1. Then
`Grind_MarketTestSeed(1.20490, 1.20500, 0, 0);` call 4 `(ADR166_T0 + 3, false, 0, 1)`
(next level now 1.20500, crossed): d F `ROLL_DEFERRED` #1 != "". e F
`ROLL_DEFERRED` #0 contains `"opposite_depth":1` AND `"gate":0`.

**RG10 no marker when no roll is due** (2): `Adr162b_SeedLong8(); Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);`
(level 1.20600 not crossed) `Adr166_TryLong(ADR166_T0, false, 0, 1)`: a G
rc == 0; b G `ROLL_DEFERRED` #0 == "".

**RG11 a gated side is not stranded** (2): `Adr165_Fixture();`
`Adr166_TryLong(ADR166_T0, false, 0, 1)` (re-roll OFF: today this side
strands, LB8): a F `ROLL_STRANDED` #0 == ""; b F
`g_grind_vl_stranded_warned_long` false.

**RG12 OnTick passes the opposite depth** (3): `Adr165_Fixture(); Adr166_OneShort();`
`Adr166_OnTick(ADR166_T0, true, 0)`: a F `VLGet(7001)` == 1.20600;
`Adr166_OnTick(ADR166_T0 + 1, true, -1)`: b G `VLGet(7001)` == 1.19800.
`Adr162b_Reset(); Adr162b_SeedShort8(); Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.18000, 7001UL, 0, 5.0); Grind_MarketTestSeed(1.19400, 1.19410, 0, 0);`
`Adr166_OnTick(ADR166_T0, false, 0)`: c F `Grind_VLHas(7101UL)` false.

**RG13 a dip during the deferral is not replayed at release** (3; the VC3
setup with a counter layer): `C55_Reset(); Adr162b_SeedLong8(); C55_OpenTimes(true, D'2026.09.28 09:00'); Adr166_OneShort();`
`Grind_MarketTestSeed(1.20690, 1.20700, 0, 0); Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);`
`Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:00' * 1000);`
`Adr166_OnTick(D'2026.09.28 10:00', false, 0)`: a F `Grind_VLHas(7001UL)`
false. Then `ArrayResize(g_grind_short.layers, 0); Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:01' * 1000);`
`Adr166_OnTick(D'2026.09.28 10:01', false, 0)`: b F `Grind_VLHas(7001UL)`
false (the 09:30 dip is not replayed). Then
`Grind_MarketTestSeed(1.20590, 1.20600, 0, 0); Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:02' * 1000);`
`Adr166_OnTick(D'2026.09.28 10:02', false, 0)`: c G `VLGet(7001)` == 1.20600.

Derivations: RG3-RG6, RG9, RG10 from LB6 / LB5 (A12): with the gate closed
or off the side behaves as LB6; with it holding nothing moves. RG5, RG11,
RG12 from RR4 / LB8 (re-roll on: 7001 to 1.19800; off: `ROLL_STRANDED`,
2-step level 1.19700 crossed by ask 1.19010). RG7: short next level =
highest entry 1.19300 + add 0.00100. RG13: at commit 1 the 10:00 call rolls
via the folded dip exactly as VC3 (so a, b fail); after the fix the gated
10:00 call restarts the extreme at 10:00:00.001, the 10:01 call folds no
tick (the dip is older) and the live ask 1.20700 does not cross 1.20600;
the 10:02 ask 1.20600 does.

**RG14 the gated path leaves closing state and backoff alone** (4; Gemini
GR6-7): LB6 setup, then `g_grind_vl_closing_ticket_long = 7001UL;
g_grind_vl_closing_since_long = ADR166_T0 - 30; g_grind_vl_closing_warned_long = false;
g_grind_vl_fail_count_long = 2;` then `Adr166_TryLong(ADR166_T0, false, 0, 1)`:
a F `g_grind_vl_closing_ticket_long == 7001UL`; b F
`g_grind_vl_closing_since_long == ADR166_T0 - 30`; c F
`g_grind_vl_fail_count_long == 2`; d G `ROLL_CLOSING_STUCK` #0 == "".
(At commit 1 the gate never holds: the call rolls 7001, zeroes the fail
count after the successful roll and resets the closing state at the end of
`TrySide`, A5; no `Grind_LatticeNoteClosing` call either way.)

Totals: **55 assertions; 31 F, 24 G.** At commit 1 the operator's suite
reads 2580 total, 2549 passing, exactly the 31 F failing; at commit 2
2580/2580. ANY other count, any G failing, or any existing test changing:
STOP and report (s7).

## 6. NEGATIVE SPACE

- With `InpRollGateOpposite = -1` nothing changes: first rolls, re-rolls,
  the pause, the throttle, `ROLL_STRANDED`, backoff, closing detection,
  the exit queue, I6, reconstruction, the carry pass, ejection.
- Do not change `Grind_LatticeCandidateIndex`, `Grind_LatticeRerollIndex`,
  `Grind_LatticeRollLayer`, `Grind_LatticeMaybeStranded`,
  `Grind_LatticeNoteClosing`, `Grind_LatticeTrackExtremes`, or any line of
  `Grind_LatticeTrackOneSide` / `Grind_LatticeResetBackoff` beyond C5.
- Do not count resting entries as layers; do not read the opposite side
  inside `TrySide` (it arrives as `opposite_depth`).
- No heartbeat change, no telemetry emit for `ROLL_DEFERRED`, no pipshed,
  no presets, no docs, nothing on FTMO (`aa6970a`).
- Do not change any existing test or its expected values (LB*, RR*, VC*,
  RS*, AL*, RN* included).
- Do not change any signature except by adding the TRAILING defaulted
  parameters in C8-C9.
- Do not compile, do not launch MetaTrader, do not run the suite, do not
  CLI compile. Do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no force-push, no `git add .` or `-u`
  (add each file by name).

## 7. FAILURE MODES: STOP AND REPORT

- Step 0's diff is not empty.
- A design line here conflicts with another (report both lines; do not
  choose).
- A helper named in s5 does not exist with the shape described.
- After commit 1 your re-derivation of any F/G differs (report which; do
  not change it).
- You need to change anything outside s3.

## 8. REPORT

Per commit: hash, files, `git diff --stat`; the 55 assertion names with
their tags; for commit 1 your own re-derivation of each F/G against the
stubs (agree / disagree with reason). No suite figure.

## 9. FOR GEMINI (on this prompt, before Cursor starts; attack the premises)

- **GR6-1 Release catch-up.** When the gate opens, the side rolls every
  level the CURRENT market has crossed in one call: first rolls are
  unthrottled (ADR-162, up to `max_layers` a call, e.g. LB7's five), re-rolls
  one per call (ADR-165 GR-3). After a long deferral that can be several
  modifies at once (about three requests each). Accept, or throttle every
  roll to one per call while the gate has held in the last N seconds?
- **GR6-2 What the gate counts (P3).** Filled layers only. In a
  continuation the counter layer scalps out, the gate opens and rolls fire
  before the counter L0 re-fills, so rolls are DEFERRED to counter-scalp
  moments, not removed. Counting the opposite side's RESTING L0 too would
  hold the gate almost permanently. Claude's lean: filled layers (the
  operator's words: "a non zero layer on the other side"); the round-3 data
  decides. Missing fact?
- **GR6-3 The extreme restart (P4, C6).** While gated, the side's extreme
  restarts at the current market every call, so a dip during the deferral
  is never replayed at release (VC3's catch-up exists for ticks missed
  between calls, not for a held period). Is restarting `from_msc` to
  market time + 1 ms right, or should the restart instead cap the extreme
  at the live price at release?
- **GR6-4 Signals.** `ROLL_DEFERRED` (INFO, archive only, once per gated
  episode, only when a roll is due); `ROLL_STRANDED` never fires while
  gated (a designed state must not light pipshed amber). Agree?
- **GR6-5 Both sides capped.** At 8/8 each side gates the other at N = 0:
  neither rolls until one side drops below cap (the inner layers keep
  scalping; only rolls stop). Acceptable, or should the gate apply only to
  the deeper side?
- **GR6-6 Scoring.** The gate is tested on ONE IC fleet against the anchor
  for one structural round, scored on EQUITY (realised + change in open
  MTM, the compulsory IC bid / ask marks), because realised alone rewards
  booking fewer roll losses whatever happens to equity (P1). Missing fact?
- **GR6-7** Any test you would add, or any F/G tag you derive differently?

## 10. GEMINI'S RULINGS (6 OCT ~17:05Z) AND CLAUDE'S CHECK

Gemini read this file as an attachment; his answers pasted by the operator;
each premise checked against `8a3ec0c` by Claude.
- **GR6-1 ACCEPTED (no throttle on first rolls at release).** His figure
  "a 3-request burst" understates it: first rolls go up to `max_layers` per
  call (LB7: five), about three requests each, so a long deferral can send
  up to ~24 at once on one side. The ruling stands; the burst is bounded by
  the gap over `add` and is visible in `ROLL_ACCEPTED`.
- **GR6-2 ACCEPTED (filled layers only).** His mechanism matches source: an
  empty side re-places its L0 at mid +/- width on the next call, so
  counting resting entries would re-gate at once.
- **GR6-3 ACCEPTED (restart `from_msc` to market time + 1 ms).**
- **GR6-4 ACCEPTED (`ROLL_DEFERRED` INFO; no `ROLL_STRANDED` while gated).**
- **GR6-5 ACCEPTED (8/8 holds both sides), reason corrected.** "Margin
  consumption is catastrophic" is not the binding constraint at 0.01 lots
  (slots are, guard 194), and a roll realises nothing when it is placed,
  only when its exit fills. The reason that stands: at 8/8 the inner layers
  keep scalping; only rolls stop.
- **GR6-6 ACCEPTED (equity scoring).** He names fleet C; the plan is
  wine-d (fleet D) at N = 0 on the anchor geometry (backlog C133).
- **GR6-7: RG14 ADDED.** His request mentions `Grind_LatticeResetBackoff`,
  which `TrySide` never calls (A8: a test reset only); the point that
  stands is that the gated path must leave the closing state and the
  backoff / fail count untouched (C8), now pinned by RG14. His F/G
  re-derivations for RG3, RG4, RG8, RG9, RG11, RG13 agree with s5.

Line count: 325
