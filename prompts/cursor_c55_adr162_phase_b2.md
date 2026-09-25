This message has a line count at the bottom

# CURSOR PROMPT -- C55: ADR-162 PHASE B2 (TICK CATCH-UP, ROLL_STRANDED, ROLL_CLOSING_STUCK, C54-AUDIT TESTS)

Repo `D:\fxmatrix`, from `main` at `36c1ac2` or a docs-only descendant
(EA code == tested `c7855da`, 2057/2057). Branch `adr162-phase-b2`.
Record: backlog C55 (`handoffs/Handover/08_BACKLOG.md`), ADR-162 s13-s14,
DeepSeek `prompts/deepseek_c54_audit_response.md` T-1 and T-3. Gemini
rules on this prompt BEFORE you start; his rulings are pasted at the
bottom. Where a ruling changes a default below, follow the ruling. If a
ruling is ambiguous, STOP and report.

Nothing here deploys. `InpVirtualLattice` stays default OFF; with it OFF
every new path below is unreachable (it all runs inside
`Grind_LatticeOnTick` after its `enabled` check).

**OPERATOR DECISION (2026-09-25), GD1 AND GD2 ACCEPTED.** B2 was to
catch up from M1 BARS (backlog C55, ADR s10 G4); it catches up from TICK
HISTORY instead and keeps a running extreme per side at cap. Operator,
in his words: "maybe we get a horrific exit - but tbh if we are 8 deep
and the market is gapping, i would rather we were active in these demos
than not." Gemini rules on the mechanics, not on that choice.

## AUDIT TRAIL (read in source at `main` `36c1ac2`, EA == `c7855da`, by Claude)

| # | finding | where | status |
|---|---|---|---|
| A1 | B1 detects a crossed level only from the CURRENT ask (long) / bid (short) inside `Grind_LatticeTrySide`: a level traded through between two delivered ticks (EA busy, e.g. a 52 s blocking OrderSend seen in cycle 2) or while the EA was down is never rolled | engine 850 (`const double mkt = is_long ? Grind_MarketAsk() : Grind_MarketBid();`) | verified |
| A2 | M1 bars are BID bars, and `MqlRates.spread` is the bar's MINIMUM spread (MQL5 book, "Reading price, volume, spread, and time by bar index": the minimum spread is what quotes store). A rollover spread spike pushes the bid low down while the ask never reaches the level: bid low + a normal spread says "crossed" when a real buy limit would not have filled | MQL5 documentation | documented; not measured on either broker |
| A3 | `CopyTicksRange` returns the terminal's tick history with bid, ask and `time_msc`, including ticks never delivered to `OnTick` (MT5 delivers the latest tick only while an `OnTick` is running). Exact asks and bids: no spread assumption | MQL5 documentation | documented; NOT yet run on the Wine box |
| A4 | A side's newest position open time is available with a test seam: `Grind_CarryPositionOpenTime(ticket, magic, t)` (carry 226-240; seam `Grind_CarryTestSetOpenTime`, carry 168-181). At cap depth cannot grow, so the newest open fixes the start of the side's window with no GV; a restart re-derives it from the broker | carry 168-240 | verified |
| A5 | `Grind_LatticeResetBackoff` (engine 686-692) is called by the B1 test reset (`Adr162b_Reset`) and resets the lattice's in-memory state; B2's new state belongs in it | engine 681-692; tests_adr162b 12-19 | verified |
| A6 | Existing B1/C54 tests call `Grind_LatticeTrySide` directly (11 parameters): a new LAST parameter with a default keeps them unchanged. LB19 calls `Grind_LatticeOnTick` without open times, so B2's tracking is skipped there and it rolls from the live seam as today | tests_adr162b 104-115, 402-412 | verified |
| A7 | Stops in TrySide: `idx < 0` (every layer rolled, engine 854-856) and "closing" (`exit_position_ticket != 0`, 858-859; C54's `GRIND_ROLL_CLOSING`, 883-884) end the loop silently | engine 854-884 | verified |
| A8 | WARN pattern: `Grind_ArchiveMarker("WARN", code, key, ticket, detail)` + `Print`, latched (SESSION_CANCEL_STUCK, engine 1320); pipshed's banner shows WARN codes on its allow-list (`WARN_CRITICAL_ALLOW`, pipshed `ftmo_daily.py` 5-9): adding the two new codes there is C56 | engine 1300-1325; pipshed | verified |
| A9 | DeepSeek T-1 (C54): a filled exit whose deal event is lost leaves a stale exit ticket on an allowed rank; C54's guard makes the roll return CLOSING every tick with no report. T-3: short side, gap loop and clamped roll inside a carry pass, and the sign guard on the effective entry after a roll, are untested | `prompts/deepseek_c54_audit_response.md` | verified (ADR s14) |
| A10 | Market seam: `Grind_MarketTestSeed(bid, ask, stops, freeze)` and `Grind_MarketTimeMsc()` (engine 41-70); the clamp for a long exit is `>= ask + max(point, stops, freeze)` (`Grind_ExitQClampPassive`, exitq 258-271; carry 435-440) | engine, exitq, carry | verified |

## WHAT B2 IS

All of it runs only with `InpVirtualLattice=true`, inside
`Grind_LatticeOnTick`.

1. **Running extreme per side at cap (catch-up).** When a side is at cap,
   the lattice tracks the most extreme price the side's next level could
   have filled at since the side reached cap: the LOWEST ASK for a long
   side, the HIGHEST BID for a short side. It reads every tick from the
   terminal's tick history (`CopyTicksRange`), so ticks `OnTick` never
   saw count, and after a restart it re-reads from the side's newest
   position open (at most 24 h back). `TrySide` tests the next level
   against `min(ask, extreme)` (long) / `max(bid, extreme)` (short)
   instead of the current price alone. The extreme resets when the side
   drops below cap. A level traded through since cap therefore rolls even
   if the roll was held off at that moment (backoff, closing candidate,
   quarantine): ADR s1's rule taken literally (GD2).
2. **ROLL_STRANDED** (WARN, latched per side): every layer rolled and the
   LIVE market S = 2 add steps beyond the lowest effective level. Reset
   when the side has an unrolled layer again or drops below cap.
3. **ROLL_CLOSING_STUCK** (WARN, latched per side): the roll candidate
   stays "closing" (deal processed but CloseBy pending, or C54's
   unselectable exit) for 60 s continuously on the same position.
4. **Tests from the C54 audit (T-3):** short roll inside a carry pass; a
   gap loop inside a pass; a clamped roll then the pass; the sign guard
   on the effective entry after a roll.

## COMMIT 1 -- STUBS AND TESTS

**Stubs and seams (production files; compile, change no behaviour):**

`ea/grind_config.mqh`, after `GRIND_VL_RETRY_BACKOFF_MAX_SEC`:

    #define GRIND_VL_CATCHUP_MAX_SEC      86400
    #define GRIND_VL_STRANDED_STEPS       2
    #define GRIND_VL_CLOSING_WARN_SEC     60

`ea/grind_pure.mqh`, after `Grind_LatticeRollCost`: the pure function, as
a STUB returning `false` (commit 2 fills it):

    // C55: lowest ask (long) / highest bid (short) over ticks with
    // msc >= from_msc; ticks with a non-positive ask (long) or bid
    // (short) are ignored. Returns false if none qualifies.
    bool Grind_LatticeTickExtreme(const long &msc[], const double &bid[],
                                  const double &ask[], const int n,
                                  const long from_msc, const bool is_long,
                                  double &extreme_out)

`ea/grind_engine.mqh`, directly after the four `g_grind_vl_*` globals
(681-684):

    bool     g_grind_vl_tracking_long  = false;
    bool     g_grind_vl_tracking_short = false;
    double   g_grind_vl_extreme_long   = 0.0;
    double   g_grind_vl_extreme_short  = 0.0;
    long     g_grind_vl_from_msc_long  = 0;
    long     g_grind_vl_from_msc_short = 0;
    bool     g_grind_vl_stranded_warned_long  = false;
    bool     g_grind_vl_stranded_warned_short = false;
    ulong    g_grind_vl_closing_ticket_long   = 0;
    ulong    g_grind_vl_closing_ticket_short  = 0;
    datetime g_grind_vl_closing_since_long    = 0;
    datetime g_grind_vl_closing_since_short   = 0;
    bool     g_grind_vl_closing_warned_long   = false;
    bool     g_grind_vl_closing_warned_short  = false;
    // test seam: used whenever g_grind_order_test_active is true
    long     g_grind_vl_test_tick_msc[];
    double   g_grind_vl_test_tick_bid[];
    double   g_grind_vl_test_tick_ask[];
    bool     g_grind_vl_test_ticks_fail = false;

`Grind_LatticeResetBackoff` also resets every variable above to its
initial value (arrays to size 0). REAL in commit 1:
`void Grind_LatticeTestTicksReset()` (arrays to 0, fail flag false) and
`void Grind_LatticeTestAddTick(const datetime t, const double bid, const
double ask)` (appends msc = `(long)t * 1000`). STUBS in commit 1:
`int Grind_LatticeCopyTicks(const long from_msc, long &msc[], double
&bid[], double &ask[])` returning -1, and `void
Grind_LatticeTrackExtremes(const ulong magic, const int max_layers,
const datetime now)` doing nothing. Do NOT change `TrySide` or `OnTick`
in commit 1.

**Tests: new file `ea/fxgrind_tests_c55.mqh`**, included directly after
`#include "fxgrind_tests_c54.mqh"`; register every test below in
`OnStart` directly after `Test_LB39_RollMidPassBranchS();`, in table
order. NO forward declarations. Reuse the B1/C54 helpers unchanged
(`Adr162b_*`, `C54_SeedLong8Carry`, `C54_FinishCarryPass`,
`C54_I6Long`, `C54_AllRestingI6Long`, `C54_AllAccruedLong`,
`Adr151_TestSetupLongLayer`). New helpers in the file:

- `C55_Reset()`: `Adr162b_Reset(); Grind_CarryTestReset();
  Grind_CarryGateReset(22260101UL); Grind_LatticeTestTicksReset();`
- `C55_OpenTimes(const bool is_long, const datetime first)`: for every
  layer i of that side, `Grind_CarryTestSetOpenTime(pos_i, first + 60 *
  i)`.
- `C55_OnTick(const datetime now)`: `Grind_LatticeOnTick(22260101UL,
  "OPT", 0.01, true, 5.0, 10.0, 8, false, now);`
- `C55_SeedShort8Carry(bid, ask)`, `C55_I6Short(idx)`,
  `C55_AllRestingI6Short()`, `C55_AllAccruedShort()`: the short-side
  mirrors of C54's long helpers (`is_long` false in
  `Grind_ReconExitMatchesEntry`; the resting count must equal 2).

Start every test with `C55_Reset();` and end with `C55_Reset();`.
"Seed L" = `Adr162b_SeedLong8(); C55_OpenTimes(true, D'2026.09.28
09:00');` (L0-L7 = 7001-7008 open 09:00-09:07; newest 09:07). "Seed S" =
`Adr162b_SeedShort8(); C55_OpenTimes(false, D'2026.09.28 09:00');`.
"Tick(t, b, a)" = `Grind_LatticeTestAddTick(t, b, a)`. Times are on
`D'2026.09.28'` unless given. `T0` = `D'2026.09.28 10:00'`.

| test | setup and calls | assertion (name: expected) | commit 1 |
|---|---|---|---|
| VC1_TickExtremeLong | msc {1000, 2000, 3000}, bid {1.20000, 1.19980, 1.19900}, ask {1.20010, 1.19990, 0.0}; `Grind_LatticeTickExtreme(..., 3, 1500, true, x)` | "VC1 found": true | FAIL |
| | | "VC1 min ask": x = 1.19990 (1e-9; the 0.0 ask is ignored) | FAIL |
| | same arrays, from 2500 | "VC1 nothing in range": false | PASS |
| VC2_TickExtremeShort | same arrays, from 0, `is_long` false | "VC2 found": true | FAIL |
| | | "VC2 max bid": x = 1.20000 (1e-9) | FAIL |
| VC3_MissedDipRolls | Seed L; market 1.20690/1.20700; Tick(09:30, 1.20580, 1.20590); `C55_OnTick(T0)` | "VC3 rolled L0": `Grind_VLGet(7001)` = 1.20600 (1e-9) | FAIL |
| | | "VC3 one level only": `!Grind_VLHas(7002)` | PASS |
| | | "VC3 exit clamped passive": price of 8001 in [1.20700, 1.20720] | FAIL |
| VC4_DipBeforeNewestOpen | Seed L; market 1.20690/1.20700; Tick(09:05, 1.20580, 1.20590); `C55_OnTick(T0)` | "VC4 no roll": `!Grind_VLHas(7001)` | PASS |
| VC5_BidDipIsNotAskDip | Seed L; market 1.20690/1.20700; Tick(09:30, 1.20580, 1.20610); `C55_OnTick(T0)` | "VC5 no roll": `!Grind_VLHas(7001)` | PASS |
| VC6_ShortMissedSpike | Seed S; market 1.19290/1.19300; Tick(09:30, 1.19410, 1.19420); `C55_OnTick(T0)` | "VC6 rolled S0": `Grind_VLGet(7101)` = 1.19400 (1e-9) | FAIL |
| VC7_GapFromHistory | Seed L; market 1.20690/1.20700; Tick(09:30, 1.20580, 1.20590); Tick(09:31, 1.20480, 1.20490); `C55_OnTick(T0)` | "VC7 L0 rolled": VL 7001 = 1.20600 | FAIL |
| | | "VC7 L1 rolled": VL 7002 = 1.20500 | FAIL |
| | | "VC7 L2 not rolled": `!Grind_VLHas(7003)` | PASS |
| VC8_ExtremeAcrossTicks | Seed L; market 1.20690/1.20700; Tick(09:30, 1.20640, 1.20650); `C55_OnTick(09:35)`; then Tick(09:40, 1.20585, 1.20595); `C55_OnTick(09:45)` | "VC8 no roll yet": after the first call, `!Grind_VLHas(7001)` | PASS |
| | | "VC8 extreme tracked": after the first call, `g_grind_vl_extreme_long` = 1.20650 (1e-9) | FAIL |
| | | "VC8 rolled on the later tick": after the second call, VL 7001 = 1.20600 | FAIL |
| VC9_CopyFailureRetries | Seed L; market 1.20690/1.20700; Tick(09:30, 1.20580, 1.20590); `g_grind_vl_test_ticks_fail = true`; `C55_OnTick(T0)`; then `= false`; `C55_OnTick(T0 + 1)` | "VC9 no roll while unavailable": after the first call, `!Grind_VLHas(7001)` | PASS |
| | | "VC9 rolled after retry": after the second call, VL 7001 = 1.20600 | FAIL |
| VC10_LookbackCap | (A) `Adr162b_SeedLong8(); C55_OpenTimes(true, D'2026.09.26 09:00');` market 1.20690/1.20700; Tick(`D'2026.09.27 09:30'`, 1.20580, 1.20590); `C55_OnTick(T0)` | "VC10 older than 24 h ignored": `!Grind_VLHas(7001)` | PASS |
| | (B) `C55_Reset()`, same seed and open times; Tick(`D'2026.09.27 11:00'`, 1.20580, 1.20590); `C55_OnTick(T0)` | "VC10 inside 24 h rolls": VL 7001 = 1.20600 | FAIL |
| VC11_BelowCapResets | Seed L; market 1.20690/1.20700; Tick(09:30, 1.20640, 1.20650); `C55_OnTick(09:35)` | "VC11 tracked at cap": extreme = 1.20650 (1e-9) | FAIL |
| | `ArrayResize(g_grind_long.layers, 7)`; `C55_OnTick(09:36)` | "VC11 reset below cap": `!g_grind_vl_tracking_long && g_grind_vl_extreme_long == 0.0` | PASS |
| | `Adr151_TestSetupLongLayer(g_grind_long, 7, 7, 1.20700, 7009UL, 0, 5.0); Grind_CarryTestSetOpenTime(7009UL, 09:50)`; Tick(09:45, 1.20580, 1.20590); `C55_OnTick(09:55)` | "VC11 dip before re-cap ignored": `!Grind_VLHas(7001)` | PASS |
| VC12_BackoffKeepsExtreme | Seed L; market 1.20690/1.20700; Tick(09:30, 1.20580, 1.20590); `g_grind_order_test_send_ok = false`; `C55_OnTick(T0)`; then `= true`; `C55_OnTick(T0 + 61)` | "VC12 first attempt failed": after the first call, `g_grind_order_test_modify_calls == 1 && !Grind_VLHas(7001)` | FAIL |
| | | "VC12 rolled after backoff": after the second call, VL 7001 = 1.20600 | FAIL |
| VS1_StrandedWarnOnce | `Adr162b_SeedLong8()`; `Grind_VLSet(7001 + i, 1.20600 - 0.00100 i)` for i = 0..7 (normalised); `Adr162b_RefreshExit` on long 0 (8001) and 7 (8008) (as LB8); market 1.19780/1.19790; `Adr162b_TryLong(T0)` | "VS1 one step no warn": `Adr162b_ArchiveFind("ROLL_STRANDED", 0) == ""` | PASS |
| | market 1.19690/1.19700; `Adr162b_TryLong(T0 + 1)` | "VS1 two steps warn": `Adr162b_ArchiveFind("ROLL_STRANDED", 0) != ""` | FAIL |
| | | "VS1 latch set": `g_grind_vl_stranded_warned_long` | FAIL |
| | `Adr162b_TryLong(T0 + 2)` | "VS1 warned once": `Adr162b_ArchiveFind("ROLL_STRANDED", 1) == ""` | PASS |
| | `ArrayResize(g_grind_long.layers, 7)`; `C55_OnTick(T0 + 3)` | "VS1 latch reset below cap": `!g_grind_vl_stranded_warned_long` | PASS |
| VS2_StrandedShort | `Adr162b_SeedShort8()`; `Grind_VLSet(7101 + i, 1.19400 + 0.00100 i)` for i = 0..7; `Adr162b_RefreshExit` on short 0 (8101) and 7 (8108); market 1.20300/1.20310; `Adr162b_TryShort(T0)` | "VS2 short warn": `Adr162b_ArchiveFind("ROLL_STRANDED", 0) != ""` | FAIL |
| VCS1_ClosingStuckWarn | `Adr162b_SeedLong8()`; `layers[0].exit_order_ticket = 0; layers[0].exit_position_ticket = 9999UL` (as LB17); market 1.20590/1.20600; `Adr162b_TryLong(T0)` | "VCS1 none at 0 s": `Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0) == ""` | PASS |
| | `Adr162b_TryLong(T0 + 59)` | "VCS1 none at 59 s": same | PASS |
| | `Adr162b_TryLong(T0 + 60)` | "VCS1 warn at 60 s": `ArchiveFind(..., 0) != ""` | FAIL |
| | `Adr162b_TryLong(T0 + 120)` | "VCS1 once": `ArchiveFind(..., 1) == ""` | PASS |
| | `layers[0].exit_position_ticket = 0; layers[0].exit_order_ticket = 8001UL;` `rc = Adr162b_TryLong(T0 + 121)` | "VCS1 rolls when clear": `rc == 1` | PASS |
| VCS2_OrderGoneStuckWarn | `Adr162b_SeedLong8()`; `Grind_OrderTestRemove(8001UL)`; market 1.20590/1.20600; `Adr162b_TryLong(T0)`; `Adr162b_TryLong(T0 + 60)` | "VCS2 warn at 60 s": `Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0) != ""` | FAIL |
| LB40_ShortRollThenPass | `C55_SeedShort8Carry(1.19400, 1.19410)` (PassBegin inside, as C54's long helper); `rc = Adr162b_TryShort(T0)`; finish the pass | "LB40 rolled before first step": `rc == 1 && g_grind_carry_exit_work_cursor == 0` | PASS |
| | | "LB40 pass completed" (as LB37) | PASS |
| | | "LB40 S0 off bare level": `MathAbs(<price of 8101> - 1.19350) > 2.0 * _Point` | PASS |
| | | "LB40 S0 I6": `C55_I6Short(0)` | PASS |
| | | "LB40 all resting I6": `C55_AllRestingI6Short()` | PASS |
| | | "LB40 all accrued": `C55_AllAccruedShort()` | PASS |
| LB41_GapLoopDuringPass | `C54_SeedLong8Carry(1.20180, 1.20190)`; `rc = Adr162b_TryLong(T0)`; finish | "LB41 five rolls mid-pass": `rc == 5 && g_grind_carry_exit_pass_active`, asserted before finishing | PASS |
| | | "LB41 pass completed" | PASS |
| | | "LB41 all resting I6": `C54_AllRestingI6Long()` | PASS |
| | | "LB41 all accrued": `C54_AllAccruedLong()` | PASS |
| LB42_ClampedCatchupRollThenPass | `C54_SeedLong8Carry(1.20690, 1.20700)` (positions open `D'2026.09.01 12:00'`: the window is T0 - 24 h); Tick(09:30, 1.20580, 1.20590); `C55_OnTick(T0)`; then finish the pass | "LB42 rolled via catch-up": VL 7001 = 1.20600, asserted right after `C55_OnTick` | FAIL |
| | | "LB42 shift recorded": `GlobalVariableCheck(Grind_CarryShiftGvName(7001UL))`, asserted right after `C55_OnTick` | FAIL |
| | | "LB42 pass completed" | PASS |
| | | "LB42 L0 I6": `C54_I6Long(0)` after the pass | PASS |
| | | "LB42 all accrued": `C54_AllAccruedLong()` | PASS |
| LB43_SignGuardAfterRoll | `C54_SeedLong8Carry(1.20590, 1.20600)`; then `Grind_CarryTestSetPosition(7001UL, 1.00, 0.01, D'2026.09.01 12:00')` (a credit of about 10 pips); `rc = Adr162b_TryLong(T0)` (rolls L0 to 1.20600, exit 1.20650); finish | "LB43 sign guard skipped": `Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0)` contains `"skipped":1` | PASS |
| | | "LB43 accrual not committed": `MathAbs(Grind_CarryAccruedGet(7001UL)) <= 1e-12` | PASS |
| | | "LB43 exit at rolled price": price of 8001 = 1.20650 (1e-9) | PASS |
| | | "LB43 L0 I6": `C54_I6Long(0)` | PASS |

**Hand derivations.** Long levels (SeedLong8, add 10): the first
virtual level is 1.20600, then 1.20500, 1.20400 (LB6, LB7); a long level
fires when the ASK is at or below it. VC3: extreme ask 1.20590 <=
1.20600 (one roll), > 1.20500 (stops); the rolled exit 1.20650 is below
the live ask 1.20700, so the passive clamp moves it to ask + 1 point
(stops 0 in the seam) = 1.20701, inside [1.20700, 1.20720]. VC5: the bid
dips to 1.20580 but the ask stays 1.20610 > 1.20600: no roll. VC6: short
levels (SeedShort8) start at 1.19400 (LB16); a short level fires when
the BID is at or above it; bid 1.19410 >= 1.19400. VC7: 1.20490 <=
1.20600 and <= 1.20500, > 1.20400: two rolls. VC4 and VC11: the window
starts 1 s after the newest open (09:07:01; after the re-add, 09:50:01),
so 09:05 and 09:45 are outside. VC10: newest open 26 Sep 09:07, T0 - 24 h
= 27 Sep 10:00 is the later bound; 27 Sep 09:30 is outside, 11:00
inside. VS1: all eight rolled, lowest effective 1.19900; the next level
is 1.19800 (LB8); S = 2 steps beyond the lowest effective level is
1.19700; ask 1.19790 crosses the level but not 1.19700 (no WARN); ask
1.19700 does. VS2 mirrors it: highest effective 1.20100, level 1.20200,
threshold 1.20300, bid 1.20300. LB43: a credit moves a long exit DOWN
(towards the entry); about 10 pips less the pending cost (under 1 pip
on GBPUSD and EURUSD) puts the theoretical exit near 1.20560, below the
EFFECTIVE entry 1.20600, so the sign guard (GA2) skips it: no modify, no
commit; the other resting exit (L1, a cost) shifts normally; skipped =
1.

**Predicted** (the operator runs both on GBPUSD and EURUSD; you do NOT
run them): baseline 2057. Commit 1 adds **57** assertions (VC 26, VS 6,
VCS 6, LB40-LB43 19): **2091/2114**, failing EXACTLY the 23 rows marked
FAIL above. Commit 2 **2114/2114**. Report your own mechanical count of
new `Assert*` calls and any difference.

PASS in both states BY DESIGN (list them in the report): the "no roll"
rows (VC3 one level, VC4, VC5, VC7 L2, VC8 no roll yet, VC9 first, VC10
A, VC11 reset and re-cap), the no-WARN rows of VS1 and VCS1, "VCS1 rolls
when clear", LB40, LB41, LB42's last three and LB43: they lock B1 and
existing carry behaviour, or the negative side of a new rule.

## COMMIT 2 -- THE IMPLEMENTATION

1. `Grind_LatticeTickExtreme` (pure): loop i < n; skip `msc[i] <
   from_msc`; long: skip `ask[i] <= 0`, keep the minimum ask; short:
   skip `bid[i] <= 0`, keep the maximum bid. Return whether any tick
   qualified.
2. `Grind_LatticeCopyTicks(from_msc, msc[], bid[], ask[])`: if
   `g_grind_order_test_active`: return -1 when
   `g_grind_vl_test_ticks_fail`, else copy the seam ticks with msc >=
   from_msc and return their count. Live: `MqlTick t[]; const int n =
   CopyTicksRange(_Symbol, t, COPY_TICKS_INFO, (ulong)from_msc,
   (ulong)Grind_MarketTimeMsc());` return -1 if `n < 0`, else fill the
   three arrays from `t[i].time_msc`, `t[i].bid`, `t[i].ask` and return
   n.
3. `Grind_LatticeTrackExtremes(magic, max_layers, now)`, per side:
   - depth < max_layers: tracking false, extreme 0, from 0, stranded
     latch false, closing ticket/since/warned reset; next side.
   - not tracking: newest = the latest `Grind_CarryPositionOpenTime` of
     the side's layers (any lookup fails: skip this side this tick,
     stay not tracking); `from = MathMax((long)(newest + 1) * 1000,
     (long)(now - GRIND_VL_CATCHUP_MAX_SEC) * 1000)`; tracking true;
     extreme 0.
   - `n = Grind_LatticeCopyTicks(from, ...)`; n < 0: leave everything
     as it is (retry next tick).
   - otherwise fold into the extreme: `Grind_LatticeTickExtreme(...,
     from, is_long, x)` if found, and the live ask (long) / bid (short)
     from the market seam if > 0 (extreme 0 means unset: take the
     value; else min for long, max for short). If n > 0, `from =
     msc[n - 1] + 1`.
4. `Grind_LatticeOnTick`: replace `if(!enabled || blocked) return;` with
   `if(!enabled) return; Grind_LatticeTrackExtremes(magic, max_layers,
   now); if(blocked) return;` and pass `g_grind_vl_extreme_long` /
   `_short` as the new last argument of the two `TrySide` calls.
5. `Grind_LatticeTrySide`: add a last parameter `const double extreme =
   0.0`.
   - After the backoff check: if the side has a candidate
     (`Grind_LatticeCandidateIndex(side, is_long) >= 0`), clear the
     side's stranded latch.
   - In the loop, keep `mkt` as the live price and test the level with
     `probe = extreme > 0.0 ? (is_long ? MathMin(mkt, extreme) :
     MathMax(mkt, extreme)) : mkt`.
   - `idx < 0`: if `Grind_LatticeLevelCrossed(is_long, mkt,
     Grind_Normalize(Grind_AddTargetPrice(level, (GRIND_VL_STRANDED_STEPS
     - 1) * add_pips, _Point, is_long ? 1 : -1)))` (the LIVE market, not
     the extreme) and the latch is clear: emit ROLL_STRANDED, set the
     latch; then break as today.
   - "Closing" (the `exit_position_ticket != 0` break, and `rc ==
     GRIND_ROLL_CLOSING`): note it -- if the side's closing ticket !=
     this position ticket: ticket = it, since = now, warned = false;
     else if `!warned && now - since >= GRIND_VL_CLOSING_WARN_SEC`: emit
     ROLL_CLOSING_STUCK, warned = true. Then break as today.
   - When the loop ends WITHOUT a closing stop, reset the side's closing
     ticket, since and warned.
6. The two WARNs: `Grind_ArchiveMarker("WARN", <code>, is_long ? "L" :
   "S", <ticket>, detail); Grind_TelemetryEmit(g_grind_telemetry_instance,
   <code>, detail); Print("WARN ", <code>, " ", detail);` with detail
   ROLL_STRANDED `{"side":"L","depth":8,"rolled":8,"lowest_effective":
   1.19900,"market":1.19700,"steps":2}` (ticket 0) and ROLL_CLOSING_STUCK
   `{"side":"L","ticket":7001,"stuck_s":60}` (ticket = the position).
   Numbers through `Grind_ArchiveJsonDouble(x, 5)`.

## NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run
  the suite (the operator compiles in the MetaEditor GUI; suite figures
  are pending), do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no `git add .` or `-u`.
- PUSH THE BRANCH after each commit: `git push -u origin adr162-phase-b2`.
- Do not change `Grind_LatticeRollLayer`, the backoff arithmetic, the
  candidate rule, `grind_carry.mqh`, the queue, reconstruction, any
  input, any preset, or any existing test, expected value, helper or
  registration.
- No GV for any new state (all in memory; a restart re-derives it).
- Nothing outside `ea/`. No docs, no pipshed (C56 adds the two WARN codes
  to the banner's allow-list).

## FAILURE MODES -- STOP AND REPORT

- A line cited above does not hold the code described (drift): STOP.
- A helper named above is missing or has another signature
  (`Grind_CarryPositionOpenTime`, `Grind_CarryTestSetOpenTime`,
  `Grind_AddTargetPrice`, `Grind_MarketTimeMsc`, `Grind_MarketTestSeed`,
  `C54_SeedLong8Carry`, `Adr162b_*`, `Grind_ArchiveJsonDouble`): STOP.
- Any existing test would need a change to compile or pass: STOP.
- `CopyTicksRange` or `COPY_TICKS_INFO` does not compile as written:
  STOP; do not substitute another call.
- You believe a row predicted PASS would fail, or FAIL would pass: do not
  change code or expected values to match; write it as specified and
  report why.

## REPORT

Both commit hashes (pushed); `git diff --stat main..adr162-phase-b2`;
each new test with its assertion names; your count of new assertions;
the PASS-in-both list.

## FOR GEMINI -- RULE BEFORE CURSOR STARTS

Verified in source by Claude unless marked. Answer each; say what you
would change.

- **GD1. Tick history instead of M1 bars (reverses ADR s10 G4 / backlog
  C55).** Bars are bid-based and carry only the bar's MINIMUM spread
  (A2), so "bid low + spread" cannot tell a real ask dip from a rollover
  spread spike: it would roll a long side in the rollover minutes when no
  buy limit at the level could have filled. `CopyTicksRange` gives the
  exact ask and bid of every tick, including ticks `OnTick` never saw
  (A3, documented, not yet run on Wine). Cost: a few ticks per call at
  cap in steady state; up to 24 h of ticks once after a restart. Accept?
- **GD2. A running extreme since cap, not only the ticks the EA missed.**
  The level is tested against the most extreme ask/bid since the side
  reached cap, so a level traded through while a roll was held off
  (backoff after a failed modify, a closing candidate, a quarantine)
  rolls afterwards even if the market has come back. The rolled exit is
  then clamped passive at the market (VC3, LB42) and may fill soon,
  realising the fixed roll cost. That is ADR s1's rule ("fires the
  moment the market trades through its entry"; V-shaped recoveries not
  designed against). The alternative (only ticks after the last
  evaluation, so a held-off crossing is forgotten) is B1's behaviour.
  The operator chose the extreme (decision above); rule on whether the
  mechanics implement it safely.
- **GD3. Window start and look-back.** The side's window starts 1 s after
  its newest position open (seconds resolution, so ticks in the fill's
  own second are excluded: never earlier) and never more than 24 h back.
  Accept both?
- **GD4. ROLL_STRANDED.** S = 2 steps beyond the lowest effective level,
  tested on the LIVE market (not the extreme: stranded is a present
  state), one WARN per episode, reset when the side has an unrolled layer
  or drops below cap. Accept, or a different S?
- **GD5. ROLL_CLOSING_STUCK** after 60 s on the same candidate, both
  closing paths (DeepSeek T-1, C54), latched. Accept?
- **GD6. A tick-history failure** (`CopyTicksRange` < 0) retries silently
  every tick; the lattice meanwhile works from the live price as B1
  does. Accept, or a WARN after some minutes of failures?

After Gemini, Cursor, and the operator's two suite states: DeepSeek
audits the branch (a separate runner prompt), then the merge `--no-ff`.
C56 (pipshed) follows; deploy only after both, on Fleet B by preset.

## GEMINI RULINGS (2026-09-25) -- ALL SIX ACCEPTED, NO CHANGES TO THE BUILD

Build exactly as written above. Condensed; reasons checked by Claude.

- **GD1 ACCEPTED.** Tick history: bid bars with the bar's minimum spread
  would roll a long side on a rollover spread spike.
- **GD2 ACCEPTED** (the mechanics of the operator's choice). CORRECTION
  (Claude): the layer left behind is the OLDEST unrolled layer (the roll
  candidate), not the deepest.
- **GD3 ACCEPTED.** Window from 1 s after the newest open; 24 h cap.
- **GD4 ACCEPTED.** S = 2, live market, latched. CORRECTION (Claude): 2
  steps is 8 to 20 pips across the fleet (add 4 to 10), not "20 pips";
  and ROLL_STRANDED asks the operator to investigate (it may be a fault,
  not a trend: ADR s13), it does not declare the grid abandoned.
- **GD5 ACCEPTED.** 60 s, both closing paths, latched. (CloseBy can take
  seconds, not only milliseconds; 60 s still separates stuck from slow.)
- **GD6 ACCEPTED, silent retry.** NOTE (Claude): his reasoning assumes
  the failure is transient; on the Wine box it is unverified (A3), and a
  PERMANENT failure there would silently leave B2's catch-up off. This
  does not change the build: it becomes a DEPLOY PRECONDITION -- before
  the lattice is enabled on Fleet B, confirm `CopyTicksRange` returns
  ticks on the box (read-only check, specified with the deploy).

Line count: 406
