This message has a line count at the bottom

# CURSOR PROMPT -- ADR-165 CONTINUOUS RE-ROLL (fxgrind EA)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat in
that workspace. Branch `adr165-reroll` from `origin/main` at the commit that
carries THIS file. Design: `docs/architecture/ADR-165-continuous-reroll.md`
(Gemini-reviewed, s9; s4.2 refined by this commit, see GC-1) -- read it in
full first, then ADR-162 s1-s5 and s13-s15. Written by Claude from source at
`22b1e3d` (EA code == `0335f25`), 1 Oct ~17:30Z. Line numbers are that code.

## 0. RESTATE AND STOP (do this first, then wait)

1. Run `git diff --stat 0335f25 HEAD -- ea/*.mq5 ea/*.mqh`. It must be
   EMPTY. If not, STOP and report it.
2. Restate each change in s2 in ONE line each, quoting this prompt's words,
   and list every test name in s4 with its assertion count.
3. Then STOP. Do not edit anything until the operator replies "go".

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | `Grind_LatticeTrySide` loops up to `max_layers` times per call: at depth >= cap it computes the next level (`Grind_ComputeAddTarget`), checks it is crossed (ask for long, bid for short, plus the tick-history extreme), takes `Grind_LatticeCandidateIndex`; if that is < 0 it calls `Grind_LatticeMaybeStranded` and breaks (1200-1204); a candidate whose exit is filled stops the loop (`Grind_LatticeNoteClosing`, 1206-1210); a modify failure backs off and breaks (1214-1233) | `ea/grind_engine.mqh` 1163-1252 | VERIFIED |
| A2 | `Grind_LatticeCandidateIndex` returns the UNROLLED layer with the highest entry (long) / lowest (short), ties to the lower `layer_index`; rolled layers (VL GV present) are skipped | 919-944 | VERIFIED |
| A3 | `Grind_LatticeRollLayer` refuses a layer with a VL (`GRIND_ROLL_ALREADY_ROLLED`, 998-999) and a closing layer (1000-1009); prices `ExitPrice(level) + accrued` (1013-1014), clamps passive, modifies the resting exit (or only re-prices the target when none rests, 1037-1042), sets the VL, deletes the eject offset, records or deletes the clamp shift (1033-1036, 1040), reports `ROLL_ACCEPTED` via `Grind_LatticeRollDetail` (958-982), then runs `Grind_ExitQManageSide` | 985-1051 | VERIFIED |
| A4 | `Grind_LatticeOnTick(magic, slot, lots, enabled, exit, add, max_layers, blocked, now, exit_short = 0, add_short = 0)` calls `TrySide` per capped side; `fxgrind.mq5` 435-438 passes `TimeCurrent()` (SERVER time) as `now` | 1255-1276; `fxgrind.mq5` 435-438 | VERIFIED |
| A5 | `Grind_ValidateLatticeInputs` (pure) and its `OnInit` FATAL | `grind_pure.mqh` 419-424; `fxgrind.mq5` 210-213 | VERIFIED |
| A6 | `OnInit` prints `GRIND_LATTICE enable=` (349) and archives `LATTICE_CONFIG {"enable":...}` (358-360); the C63 log checker reads the FIRST `enable=` on the `GRIND_LATTICE` line, so the re-roll flag goes on its OWN line | `fxgrind.mq5` 349, 358-360; runbook `c63-commands.md` s1 | VERIFIED |
| A7 | Test harness: `Adr162b_SeedLong8` / `Adr162b_SeedShort8`, `Adr162b_RefreshExit`, `Adr162b_Reset`, `Adr162b_ArchiveFind`, `Grind_MarketTestSeed(bid, ask, stops, freeze)`, order-test counters `g_grind_order_test_modify_calls` / `_remove_calls` / `_place_calls`, `g_grind_order_test_send_ok`; LB8 is the all-rolled fixture this prompt reuses | `ea/fxgrind_tests_adr162b.mqh` 11-115, 315-327 | VERIFIED |
| A8 | Existing LB8 (`Test_LB8_NoReroll`) asserts no re-roll with today's call; it must keep passing unchanged (the new behaviour is behind a default-false parameter) | adr162b 315-327 | VERIFIED |
| A9 | Suite today: 2368/2368 on GBPUSD and EURUSD at `97a2cd1` (EA == `0335f25`) | BOOT s6 | VERIFIED (operator's runs) |

## 1. WHAT TO BUILD (summary)

With the new input `InpLatticeReroll` ON, a capped side whose every layer is
already rolled no longer strands: when the market crosses the next level,
the rolled layer with the highest effective entry (long; lowest for short)
is RE-ROLLED to that level. At most one re-roll per side per call; none
while the server clock is in 23:50-00:15. Default OFF: with it OFF the EA
behaves exactly as today. No market order, no new position, no change to
first rolls.

## 2. CHANGES

| # | File | Change |
|---|---|---|
| C1 | `ea/fxgrind.mq5` | `input bool InpLatticeReroll = false; // ADR-165 continuous re-roll (requires lattice)` on the line AFTER `InpVirtualLattice` (34) |
| C2 | `ea/grind_pure.mqh` | after `Grind_ValidateLatticeInputs` (424): `bool Grind_ValidateRerollInputs(const bool lattice, const bool reroll)` returns `!reroll || lattice` |
| C3 | `ea/grind_pure.mqh` | after C2: `bool Grind_LatticeRerollPaused(const datetime server_now)`: `MqlDateTime t; TimeToStruct(server_now, t); const int m = t.hour * 60 + t.min; return (m >= 23 * 60 + 50) || (m < 15);` (paused from 23:50:00, resumes at 00:15:00) |
| C4 | `ea/grind_engine.mqh` | after `Grind_LatticeCountRolled` (955): `int Grind_LatticeRerollIndex(const GrindSideState &side, const bool is_long)`: among layers with `position_ticket != 0` AND `Grind_VLHas(ticket)`, the one with the highest `Grind_VLGet` (long) / lowest (short); ties to the lower `layer_index`; none -> -1. Strict comparison for the value (a tie never replaces the incumbent unless its `layer_index` is lower) |
| C5 | `ea/grind_engine.mqh` | `Grind_LatticeRollDetail` gains two TRAILING parameters `const bool reroll = false, const double from_level = 0.0` and appends `,"reroll":%s,"from_level":%s` (bool via `Grind_ArchiveJsonBool`, level via `Grind_ArchiveJsonDouble(from_level, 5)`) after `"source"`, before the closing brace |
| C6 | `ea/grind_engine.mqh` | `Grind_LatticeRollLayer` gains a TRAILING parameter `const bool allow_reroll = false`. When true, the `Grind_VLHas(pos)` refusal (998-999) is skipped and the VL held BEFORE the roll is captured as `from_level` (`Grind_VLGet(pos)`); pass `allow_reroll` and `from_level` to `Grind_LatticeRollDetail`. Nothing else in the function changes |
| C7 | `ea/grind_engine.mqh` | `Grind_LatticeTrySide` gains a TRAILING parameter `const bool reroll = false` (after `extreme`). Inside, a local `int rerolls = 0;`. Replace the block at 1200-1204 with: `int idx = Grind_LatticeCandidateIndex(side, is_long); bool is_reroll = false; if(idx < 0) { if(reroll && rerolls >= 1) break; if(!reroll || Grind_LatticeRerollPaused(now)) { Grind_LatticeMaybeStranded(side, is_long, level, mkt, add_pips, max_layers, now); break; } idx = Grind_LatticeRerollIndex(side, is_long); if(idx < 0) { Grind_LatticeMaybeStranded(side, is_long, level, mkt, add_pips, max_layers, now); break; } is_reroll = true; }`. The existing closing check (1206-1210) then applies to `idx` unchanged. The roll call passes `is_reroll ? "reroll" : "auto"` as `source` and `is_reroll` as `allow_reroll`. After `rc == GRIND_ROLL_OK`: if `is_reroll`, `rerolls++` and clear that side's stranded flag (`g_grind_vl_stranded_warned_long/_short = false`). `rolled_count` counts re-rolls too. Everything else unchanged |
| C8 | `ea/grind_engine.mqh` | `Grind_LatticeOnTick` gains a TRAILING parameter `const bool reroll = false` (after `add_pips_short`) and passes it as the last argument of BOTH `TrySide` calls |
| C9 | `ea/fxgrind.mq5` | `OnInit`, right after the lattice FATAL (213): `if(!Grind_ValidateRerollInputs(InpVirtualLattice, InpLatticeReroll)) { Print("FATAL: InpLatticeReroll requires InpVirtualLattice=true (ADR-165 s4.1)"); return INIT_FAILED; }`. After line 349: `Print("GRIND_REROLL enable=", InpLatticeReroll);`. `LATTICE_CONFIG` detail becomes `{"enable":%s,"reroll":%s}`. In `OnTick` (435-438) pass `InpLatticeReroll` as the new last argument |
| C10 | `ea/fxgrind_tests_adr165.mqh` | NEW: the tests in s4 |
| C11 | `ea/fxgrind_tests.mq5` | `#include "fxgrind_tests_adr165.mqh"` after `fxgrind_tests_adr164.mqh` (28); call the s4 tests, in order, at the END of `OnStart`, just before the summary |

MQL5 resolves functions defined later in the program: no forward
declarations anywhere. Every existing call site compiles unchanged (all new
parameters are trailing with defaults).

## 3. COMMITS

1. **Tests first, against stubs.** C1 and C9 as written; C2 STUB `return
   true;`; C3 STUB `return false;`; C4 STUB `return -1;`; C5-C8 add the new
   parameters ONLY (signatures and the pass-through in C8 and C9), with NO
   behaviour change (C6 still refuses a VL; C7 still strands); C10, C11.
   Commit message: tests first, the predicted failures (s4: 39) and guards
   (27).
2. **Implementation:** C2-C8 as written. Nothing else.
Do not compile (the operator compiles and runs the suite in MetaEditor on the
desktop and reports the counts; do NOT report a suite figure yourself).

## 4. TESTS (`ea/fxgrind_tests_adr165.mqh`; tags: F = fails at commit 1, G = guard, passes at both)

Helpers (in the new file): `Adr165_Fixture()` = the LB8 setup exactly:
`Adr162b_SeedLong8(); for i in 0..7: Grind_VLSet(7001 + i, NormalizeDouble(1.20600 - 0.00100 * i, 5)); Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL); Adr162b_RefreshExit(g_grind_long, true, 7, 8008UL); Grind_MarketTestSeed(1.19000, 1.19010, 0, 0);`
`Adr165_TryLong(now, reroll)` = `Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8, true, false, now, 0.0, reroll)`; `Adr165_TryShort` the same on `g_grind_short`, `false`. `T0 = D'2026.09.28 10:00'`. Every test ends with `Adr162b_Reset()`.

Derivations (exit 5 pips, add 10 pips in the harness): the fixture's VLs
are 1.20600 (7001) down to 1.19900 (7008); the next level is lowest
effective - add = **1.19800**; ask 1.19010 crosses it; the re-roll candidate
is 7001 (VL 1.20600); its new exit = 1.19800 + 0.00050 = **1.19850**. Today
(stubs) the same call strands: `ROLL_STRANDED` (2-step level 1.19700 is
crossed), rc 0, no request.

**RR1 ValidateRerollInputs** (4): a G `(true,true)` true; b F `(false,true)`
false; c G `(true,false)` true; d G `(false,false)` true.

**RR2 RerollIndex** (4): a G `Adr162b_SeedLong8()` with no VLs -> -1;
b F `Adr165_Fixture()` -> 0 (7001); c F fixture then
`Grind_VLSet(7002UL, 1.20600)` (tie with 7001) -> 0 (lower `layer_index`);
d F `Adr162b_SeedShort8()` with `Grind_VLSet(7101 + i, NormalizeDouble(1.19400 + 0.00100 * i, 5))` -> 0 (7101, lowest).

**RR3 RerollPaused** (6): a G `D'2026.09.28 23:49:59'` false; b F
`D'2026.09.28 23:50:00'` true; c F `D'2026.09.29 00:00:00'` true; d F
`D'2026.09.29 00:14:59'` true; e G `D'2026.09.29 00:15:00'` false; f G `T0` false.

**RR4 single re-roll, long** (13; fixture, `Adr165_TryLong(T0, true)`):
a F rc == 1; b F `Grind_VLGet(7001UL)` == 1.19800; c F
`Grind_OrderGetPriceOpen(8001UL)` == 1.19850; d F `layers[0].exit_target`
== 1.19850; e F `Grind_ReconExitMatchesEntry(1.21400, 1.19850, 5.0, _Point,
true, 0.0, false, 7001UL)` true; f G `Grind_VLGet(7002UL)` == 1.20500;
g F `layers[7].exit_order_ticket == 0` (old rank 0 cancelled); h F
`layers[1].exit_order_ticket != 0` (new highest rank placed); i F modify ==
1 && remove == 1 && place == 1; j F `ROLL_ACCEPTED` #0 contains
`"reroll":true`; k F it contains `"from_level":1.20600`; l F it contains
`"source":"reroll"`; m F `Adr162b_ArchiveFind("ROLL_STRANDED", 0) == ""`.

**RR5 input OFF** (4; fixture, `Adr165_TryLong(T0, false)`): a G rc == 0;
b G modify == 0; c G `Grind_VLGet(7001UL)` == 1.20600; d G `ROLL_STRANDED`
#0 != "".

**RR6 throttle: one per call** (8; fixture; calls at `T0`, `T0 + 1`, `T0 + 2`,
all `true`): a F call 1 rc == 1; b G after call 1 `VLGet(7002)` == 1.20500;
c F call 2 rc == 1; d F `VLGet(7002)` == 1.19700; e F call 3 rc == 1; f F
`VLGet(7003)` == 1.19600; g F modify == 3; h F `ROLL_STRANDED` #0 == "".

**RR7 pause** (4): fixture, `Adr165_TryLong(D'2026.09.28 23:55', true)`: a G
rc == 0; b G `VLGet(7001)` == 1.20600; c G `ROLL_STRANDED` #0 != "";
`Adr162b_Reset(); Adr165_Fixture();` then `Adr165_TryLong(D'2026.09.29 00:16', true)`: d F rc == 1.

**RR8 short** (4): `Adr162b_SeedShort8()`; VLs 7101 + i = 1.19400 + 0.00100 i;
`Adr162b_RefreshExit(g_grind_short, false, 0, 8101UL)` and `(..., 7, 8108UL)`;
`Grind_MarketTestSeed(1.21000, 1.21010, 0, 0)`; `Adr165_TryShort(T0, true)`.
Next level = 1.20100 + 0.00100 = 1.20200 (bid 1.21000 crosses); candidate
7101; exit 1.20200 - 0.00050 = 1.20150. a F rc == 1; b F `VLGet(7101)` ==
1.20200; c F price(8101) == 1.20150; d G `VLGet(7102)` == 1.19500.

**RR9 accrual kept, shift not compounded** (3): fixture, then
`Grind_CarryAccruedSet(7001UL, 0.00010); Grind_CarryShiftSet(7001UL, 0.00003); Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);`
then `Adr165_TryLong(T0, true)`. a F price(8001) == 1.19860 (1.19800 +
0.00050 + 0.00010); b G `Grind_CarryAccruedGet(7001UL)` == 0.00010; c F
`GlobalVariableCheck(Grind_CarryShiftGvName(7001UL))` false.

**RR10 modify fails** (5): fixture, `g_grind_order_test_send_ok = false;`
`Adr165_TryLong(T0, true)`: a G rc == 0; b F modify == 1; c G `VLGet(7001)`
== 1.20600; d F `ROLL_REFUSED` #0 contains `MODIFY_FAILED`; e G price(8001)
== 1.20650 (unchanged). Restore `g_grind_order_test_send_ok = true` before
the reset.

**RR11 closing candidate stops (GC-1)** (5): fixture, then
`g_grind_long.layers[0].exit_order_ticket = 0; g_grind_long.layers[0].exit_position_ticket = 9999UL;`
`Adr165_TryLong(T0, true)`: a G rc == 0; b G `VLGet(7001)` == 1.20600 and
`VLGet(7002)` == 1.20500; c G modify == 0; d F `ROLL_STRANDED` #0 == "";
e F `g_grind_vl_closing_ticket_long == 7001UL`.

**RR12 OnTick wiring** (2): fixture;
`Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, T0, 5.0, 10.0, false)`:
a G `VLGet(7001)` == 1.20600; then the same call with last argument `true`:
b F `VLGet(7001)` == 1.19800.

**RR13 first rolls, then one re-roll** (4): the LB18 setup
(`Adr162b_SeedLong8()`; VLs 7001..7006 = 1.20600 down to 1.20100;
`Adr151_TestSetupLongLayer(g_grind_long, 6, 8, 1.20000, 7009UL, 0, 5.0)`;
`Adr151_TestSetupLongLayer(g_grind_long, 7, 9, 1.19900, 7010UL, 0, 5.0)`;
refresh exits 0 -> 8001UL and 7 -> 8010UL), `Grind_MarketTestSeed(1.19000, 1.19010, 0, 0)`,
`Adr165_TryLong(T0, true)`. First rolls: 7009 to 1.19800, 7010 to 1.19700;
then one re-roll: 7001 to 1.19600. a F rc == 3 (stubs: 2); b G `VLGet(7009)`
== 1.19800; c G `VLGet(7010)` == 1.19700; d F `VLGet(7001)` == 1.19600.

Totals: **66 assertions; 39 F, 27 G.** At commit 1 the operator's suite
reads 2434 total, 2395 passing, exactly the 39 F failing; at commit 2
2434/2434. ANY other count, any G failing, or any existing test changing:
STOP and report (s6).

## 5. NEGATIVE SPACE

- Do not change first-roll behaviour, `Grind_LatticeCandidateIndex`,
  `Grind_LatticeMaybeStranded`, the backoff, ADR-157 auto-eject, ADR-155
  commanded eject, the carry pass, reconstruction, I6 or the exit queue.
- Do not change any existing test or its expected values (LB8 included).
- Do not touch presets, pipshed, docs (other than none), or any file not in s2.
- Do not change any signature except by adding the TRAILING defaulted
  parameters in C5-C8; do not touch the functions forward-declared in
  `fxgrind_tests_adr151.mqh` (16, 20).
- Do not compile, do not launch MetaTrader, do not run the suite, do not
  CLI compile. Do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no force-push, no `git add .` or `-u`
  (add each file by name).

## 6. FAILURE MODES: STOP AND REPORT

- Step 0's diff is not empty.
- A design line here conflicts with another (report the two lines; do not
  choose).
- A helper named in s4 does not exist with the shape described.
- After commit 1 the F/G derivation looks wrong for any assertion when you
  re-derive it against your stubs (report which; do not change it).
- You need to change anything outside s2.

## 7. REPORT

Per commit: hash, files, `git diff --stat`; the 66 assertion names with
their tags; for commit 1 your own re-derivation of each F/G against the
stubs (agree / disagree with reason). No suite figure.

## 8. FOR GEMINI (on this prompt, before Cursor starts)

- **GC-1** ADR s4.2 said a closing layer is SKIPPED when choosing the
  re-roll candidate. This prompt instead STOPS on it (C7 reuses the
  existing closing check, as first rolls do, A1): if the furthest rolled
  layer's exit has filled, the side is about to drop below cap and needs
  no re-roll. The ADR's s4.2 is amended in this commit to match. Object?
- **GC-2** The throttle counts re-rolls only; first rolls stay unlimited
  per call (ADR-162). Agree?
- **GC-3** The pause reads `now` = `TimeCurrent()` (the server time of the
  last quote). In a dead market it lags; the worst case is a re-roll a few
  seconds into 23:50 or a pause a few seconds past 00:15. Acceptable?
- **GC-4** Any test you would add, or any F/G tag you derive differently?

Line count: 214
