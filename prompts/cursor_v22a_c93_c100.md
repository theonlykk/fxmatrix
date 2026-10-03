This message has a line count at the bottom

# CURSOR PROMPT -- v2.2a: C93 RECON SCAN RACE + C100 API LIMITS AS INPUTS (fxgrind EA)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat in
that workspace. Branch `v22a-recon-api` from `origin/main` at the commit that
carries THIS file. Background: backlog C93 and C100
(`handoffs/Handover/08_BACKLOG.md`), 02_TRAPS "3 Oct afternoon (C93, C107)",
ADR-125 (the no-ticket policy, "Tickets deliberately excluded"), ADR-128
(quarantine). Written by Claude from source at `e63e8a8` (EA code ==
`2859be6`), 3 Oct. Line numbers are that code. **AMENDED 3 Oct ~17:45Z
after Gemini's review (s9): no API limit value or mismatch halts or
unloads anything (operator); K7 changed, K9-K11 and AL6-AL7 added; 61
assertions.** Gemini reviews this amended file once more (GV-7..GV-9)
before Cursor starts.

## 0. RESTATE AND STOP (do this first, then wait)

1. Run `git diff --stat 2859be6 HEAD -- ea/*.mq5 ea/*.mqh`. It must be
   EMPTY (the presets under `ea/presets_*` changed after `2859be6`; they are
   not in that pathspec). If not empty, STOP and report it.
2. Restate each change in s2 in ONE line each, quoting this prompt's words,
   and list every test name in s4 with its assertion count.
3. Then STOP. Do not edit anything until the operator replies "go".

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | `Grind_ReconCollectBrokerTickets` walks `PositionsTotal()-1 .. 0` (`PositionGetTicket(i)`, stores `POSITION_IDENTIFIER`), then `OrdersTotal()-1 .. 0` (`OrderGetTicket(i)`), filters symbol and magic, appends with `ArrayResize`. The lists are shared by every EA on the account: a removal below index i mid-walk shifts the rest down and the next index re-reads an entry already counted (DUPLICATE); a removal above i, or an insertion, can make the walk miss one (SKIP); a limit filling between the two walks is in neither | `ea/grind_recon.mqh` 1209-1247 | VERIFIED |
| A2 | C93: FTMO AUDNZD_OPT halted 1 Oct 15:24:33Z `AMBIGUOUS_ADD_LONG`. The VPS Journal shows ONE L08 buy limit (#555021571 @1.23351); the halt's ticket list holds it twice (same comment, same price). The only duplicate among 61 `INVARIANT_FAIL` rows in the archive | 08_BACKLOG C93; 02_TRAPS 3 Oct afternoon | VERIFIED (operator's Journal, 3 Oct) |
| A3 | The collector runs on EVERY tick when not halted: `OnTick` -> `Grind_ReplayCheckInvariants` -> `Grind_ReplayInvariantOk` -> `Grind_CheckBookInvariants` (1253-1278); and once at init in `Grind_ReconstructState` (1281-1330) | `fxgrind.mq5` 419-434; `grind_replay.mqh` 295-331; `grind_recon.mqh` 1253-1330 | VERIFIED |
| A4 | `AMBIGUOUS_L0_*` / `AMBIGUOUS_ADD_*` are NOT quarantinable: one failing check halts at once. `I2_*_EXIT_DUP`, `I3_*_NAKED`, `I4_*_ORPHAN_EXIT`, `I6_*` are (3 s and 3 checks, ADR-128), so a SKIP that clears on the next tick does not halt | `grind_quarantine.mqh` 33-45; `fxgrind.mq5` 425-433 | VERIFIED |
| A5 | `Grind_RebuildBookFromTickets` (1174) takes `const GrindReconTicket &tickets[]`; an ENT order on layer >= 1 sets `add_pending_ticket`, a second one fails `AMBIGUOUS_ADD_LONG` / `_SHORT` (1047-1060). A duplicate entry of the SAME ticket fails the same way (N3 uses two distinct tickets) | `grind_recon.mqh` 1030-1062; `Test_N1` / `Test_N3` (`fxgrind_tests.mq5` 3582-3641) | VERIFIED |
| A6 | `Grind_ReconFailureCapture` builds `g_grind_recon_failure_json` with `kind`, `comment`, `price`, `side_hint` per ticket (max `GRIND_RECON_FAILURE_MAX_EMIT` = 40), and NO ticket number. This is policy: ADR-125 "Tickets deliberately excluded" (the public status endpoint carries the heartbeat, which embeds this JSON as `recon_failure`), enforced by `Test_F4_NoTicketNumbersInJson` ("F4 no ticket key", "F4 heartbeat no ticket") | `grind_recon.mqh` 35, 657-711; `fxgrind_tests.mq5` 1879-1902 | VERIFIED |
| A7 | Backlog C93 fix item (3) said "put the ticket numbers into the recon-failure detail". That conflicts with A6. This prompt puts them in the LOCAL Experts log only (s2 V8-V9); the JSON, the heartbeat and the archive stay ticket-free (GV-1) | -- | DESIGN |
| A8 | `Grind_ReconFailureClear` (grind_recon_failure.mqh 10-13) empties the JSON; `Grind_RebuildBookFromTickets` calls it on success | `grind_recon_failure.mqh`; `grind_recon.mqh` ~1199 | VERIFIED |
| A9 | Test helpers: `Grind_TestAppendReconTicket(tickets, count, magic, ticket, kind, comment, price)` appends WITHOUT any check (1701-1715); `Grind_TestResetSideState()`; `Grind_TestSampleHeartbeatJson()` (1426); `GrindCommentBuild(slot, side, layer, role)` | `fxgrind_tests.mq5` | VERIFIED |
| A10 | API counter: `GRIND_DAILY_API_SOFT_WARN` 999000 (`grind_api_counter.mqh` 14), `GRIND_DAILY_API_ENTRY_STOP` 1000000 (`grind_config.mqh` 11), both raised by the 2 Oct hotfix from 1800 / 1900 ("effectively off, C100"). `Grind_ApiCounterSoftWarnActive` (121-124) compares the count with the soft define; `Grind_ApiCounterEntryStopped` (127-141) with the stop define and emits `WARN_API_ENTRY_STOP` once per day | `ea/grind_api_counter.mqh`; `ea/grind_config.mqh` | VERIFIED |
| A11 | Callers: soft warn gates the timer's `WARN_API_SOFT_LIMIT` (`fxgrind.mq5` 408) and the empty-side L0 re-centre (`grind_engine.mqh` 2957); entry stop feeds `Grind_EntriesBlocked` (`grind_engine.mqh` 1522) and the heartbeat's `entry_stopped` (`fxgrind.mq5` 108) | as listed | VERIFIED |
| A12 | The counter is ONE Global Variable per terminal (`GRIND_DAILY_API_COUNT`), shared by every fxgrind chart on it; the limits are per chart | `grind_api_counter.mqh` 11-12, `Grind_ApiCounterIncrement` | VERIFIED |
| A13 | Existing tests seed AT the defines: `fxgrind_tests.mq5` 8385, 8412; `fxgrind_tests_adr152.mqh` 287, 306, 318; `fxgrind_tests_adr162b.mqh` 259. They keep passing if the new globals DEFAULT to the defines | as listed | VERIFIED |
| A14 | `Grind_ApiCounterTestReset` (35-43) is the tests' reset; `Grind_ApiCounterTestSeed(count)` (46-51) | `grind_api_counter.mqh` | VERIFIED |
| A15 | `OnInit`: the ADR-165 FATAL at 215-218; `GRIND_REROLL enable=` print at 355; `LATTICE_CONFIG` marker at 364-367; `EventSetTimer(1)` at 368. Inputs: `InpEntryHorizonPips` at 40 | `ea/fxgrind.mq5` | VERIFIED |
| A16 | Suite today: 2447/2447 on GBPUSD and EURUSD at `2859be6` | HANDOFF s41 | VERIFIED (operator's runs, 3 Oct) |
| A17 | A FATAL in `OnInit` (`return INIT_FAILED`) UNLOADS the EA from its chart: the book sits at the broker unmanaged until a re-attach (1 Oct 06:24Z, wine-d) | 02_TRAPS 1 Oct D1 | VERIFIED |
| A18 | Operator ruling 3 Oct (on GV-5): "api limits are not a hard line. we should not be turning things off or halting anything ... a warning is sufficient". Also 2 Oct: "i do not want an api limit to stop trading" | HANDOFF s44 | RULING |

## 1. WHAT TO BUILD (summary)

**C93.** The collector stops reading one broker entry twice, and re-walks
when the lists changed under it: (a) an entry already collected (same
ticket AND same kind) is not appended again and is counted as a duplicate;
(b) `PositionsTotal()` and `OrdersTotal()` are read before and after each
walk; if either differs, the walk is repeated, at most 3 walks in all; the
last walk is used; (c) if a duplicate was dropped or more than one walk was
needed, a `RECON_SCAN_RACE` WARN marker and a `GRIND_RECON_SCAN` log line
record it; (d) on a recon failure the ticket numbers go to ONE local Experts
log line, `RECON_TICKETS`, in the same order as the JSON rows, printed only
when it differs from the last one printed. The failure JSON is unchanged.

**C100.** Two inputs replace the two constants: `InpApiEntryStop` (default
1000000) and `InpApiSoftWarn` (default 999000), held in globals that DEFAULT
to the defines; printed and archived at init. Invalid values (either
below 1, or soft above stop) do NOT fail init: the EA keeps the defines
and raises an `API_LIMITS_INVALID` WARN. Each chart publishes the limits
in force to two terminal Global Variables at init; a chart whose limits
differ from those already published raises an `API_LIMITS_MISMATCH` WARN
and then publishes its own (last init wins). Nothing halts, nothing is
unloaded, no trading path changes (A17, A18). With the defaults the EA
behaves exactly as today.

No change to the invariants, the quarantine, the rebuild logic, any reason
string, or any trading path.

## 2. CHANGES

| # | File | Change |
|---|---|---|
| V1 | `ea/grind_recon.mqh` | after `#define GRIND_RECON_FAILURE_MAX_EMIT 40` (35): `#define GRIND_RECON_SCAN_MAX_WALKS 3` |
| V2 | `ea/grind_recon.mqh` | immediately BEFORE `Grind_ReconCollectBrokerTickets` (1209): `int Grind_ReconAppendUnique(GrindReconTicket &tickets[], const int count, const ulong ticket, const ulong magic, const string comment, const double price, const int kind, int &dupes_io)`: for `i` in `0 .. count-1`, if `tickets[i].ticket == ticket && tickets[i].kind == kind` then `dupes_io++` and return `count` unchanged. Otherwise `ArrayResize(tickets, count + 1)`, set the five fields of `tickets[count]` (ticket, magic, comment, price, kind) and return `count + 1`. The key includes `kind` because a position's identifier is the ticket of the order that opened it (one number, two kinds) |
| V3 | `ea/grind_recon.mqh` | after V2: `bool Grind_ReconScanStable(const int positions_before, const int orders_before, const int positions_after, const int orders_after)` returns `positions_before == positions_after && orders_before == orders_after` |
| V4 | `ea/grind_recon.mqh` | after V3: `bool Grind_ReconScanRaced(const int dupes, const int walks)` returns `dupes > 0 \|\| walks > 1` |
| V5 | `ea/grind_recon.mqh` | after V4: `string Grind_ReconScanDetail(const int dupes, const int walks, const bool stable)` returns `StringFormat("{\"dupes\":%d,\"walks\":%d,\"stable\":%s}", dupes, walks, stable ? "true" : "false")` |
| V6 | `ea/grind_recon.mqh` | REWRITE `Grind_ReconCollectBrokerTickets` (1209-1247) as in s2.1 below. Same filters, same fields, same order (positions then orders, each walked from the top index down) |
| V7 | `ea/grind_recon_failure.mqh` | after `g_grind_recon_failure_json` (7): `string g_grind_recon_tickets_last_line = "";`. `Grind_ReconFailureClear` also sets it to `""` |
| V8 | `ea/grind_recon.mqh` | immediately BEFORE `Grind_ReconFailureCapture` (677): `string Grind_ReconTicketsLogLine(const string reason, const GrindReconTicket &tickets[], const int count)`: `string s = StringFormat("RECON_TICKETS reason=%s n=%d", reason, count);` then for `i` in `0 .. MathMin(count, GRIND_RECON_FAILURE_MAX_EMIT)-1`: `s += StringFormat(" %s:%I64u", tickets[i].kind == GRIND_RECON_TICKET_POSITION ? "P" : "O", tickets[i].ticket);` then if `count > GRIND_RECON_FAILURE_MAX_EMIT`: `s += StringFormat(" +%d more", count - GRIND_RECON_FAILURE_MAX_EMIT);` return `s` |
| V9 | `ea/grind_recon.mqh` | in `Grind_ReconFailureCapture`, AFTER `g_grind_recon_failure_json = json;` (709): `const string line = Grind_ReconTicketsLogLine(reason, tickets, ticket_count); if(line != g_grind_recon_tickets_last_line) { Print(Grind_LogTag(), line); g_grind_recon_tickets_last_line = line; }`. Nothing else in the function changes; the JSON stays ticket-free |
| K1 | `ea/grind_api_counter.mqh` | after the globals block (16-23): `int g_grind_api_entry_stop = GRIND_DAILY_API_ENTRY_STOP;` and `int g_grind_api_soft_warn = GRIND_DAILY_API_SOFT_WARN;` |
| K2 | `ea/grind_api_counter.mqh` | after `Grind_ApiCounterTestSeed` (51): `void Grind_ApiLimitsSet(const int entry_stop, const int soft_warn)` sets the two globals |
| K3 | `ea/grind_api_counter.mqh` | `Grind_ApiCounterTestReset` also restores both globals to the defines (first two lines of its body) |
| K4 | `ea/grind_api_counter.mqh` | `Grind_ApiCounterSoftWarnActive` compares with `g_grind_api_soft_warn`; `Grind_ApiCounterEntryStopped` compares with `g_grind_api_entry_stop`. The defines stay, unchanged, as the defaults |
| K5 | `ea/grind_pure.mqh` | after `Grind_LatticeRerollPaused` (431-437): `bool Grind_ValidateApiLimitInputs(const int entry_stop, const int soft_warn)` returns `entry_stop >= 1 && soft_warn >= 1 && soft_warn <= entry_stop` |
| K6 | `ea/fxgrind.mq5` | after `InpEntryHorizonPips` (40): `input int    InpApiEntryStop       = 1000000; // C100: no new entries at this daily request count (terminal-wide counter; same value on every chart of a terminal)` and `input int    InpApiSoftWarn        = 999000;  // C100: WARN_API_SOFT_LIMIT and no empty-side L0 re-centre at this count` |
| K7 | `ea/fxgrind.mq5` | `OnInit`, right after the ADR-165 FATAL block (215-218), at function level (not inside any block): `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);`. NO `return INIT_FAILED` and no FATAL print for these inputs (A17, A18) |
| K8 | `ea/fxgrind.mq5` | after the `GRIND_REROLL` print (355): `Print("GRIND_API_LIMITS entry_stop=", g_grind_api_entry_stop, " soft_warn=", g_grind_api_soft_warn);` (the GLOBALS, i.e. what is in force). After the `LATTICE_CONFIG` marker (367), before `EventSetTimer(1)`, in this order: (1) `if(!api_inputs_ok) { const string bad = StringFormat("{\"input_entry_stop\":%d,\"input_soft_warn\":%d,\"using_entry_stop\":%d,\"using_soft_warn\":%d}", InpApiEntryStop, InpApiSoftWarn, g_grind_api_entry_stop, g_grind_api_soft_warn); Grind_ArchiveMarker("WARN", "API_LIMITS_INVALID", "", 0, bad); Print("WARN API_LIMITS_INVALID ", bad); }` (2) `Grind_ArchiveMarker("INFO", "API_LIMITS_CONFIG", "", 0, StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}", g_grind_api_entry_stop, g_grind_api_soft_warn));` (3) `Grind_ApiLimitsPublishAndCheck();` (return value unused here) |
| K9 | `ea/grind_api_counter.mqh` | after `#define GRIND_DAILY_API_SOFT_WARN ...` (14): `#define GRIND_API_LIMIT_STOP_GV "GRIND_API_LIMIT_ENTRY_STOP"` and `#define GRIND_API_LIMIT_SOFT_GV "GRIND_API_LIMIT_SOFT_WARN"` (new terminal Global Variables; NOT the counter's) |
| K10 | `ea/grind_api_counter.mqh` | after K2: `bool Grind_ApiLimitsApplyInputs(const int entry_stop, const int soft_warn)`: `if(!Grind_ValidateApiLimitInputs(entry_stop, soft_warn)) { Grind_ApiLimitsSet(GRIND_DAILY_API_ENTRY_STOP, GRIND_DAILY_API_SOFT_WARN); return false; } Grind_ApiLimitsSet(entry_stop, soft_warn); return true;` |
| K11 | `ea/grind_api_counter.mqh` | after K10: `bool Grind_ApiLimitsPublishAndCheck()` as in s2.2 |
| T1 | `ea/fxgrind_tests_v22a.mqh` | NEW: the tests in s4 |
| T2 | `ea/fxgrind_tests.mq5` | `#include "fxgrind_tests_v22a.mqh"` after `fxgrind_tests_adr165.mqh` (29); call the s4 tests, in order, after `Test_RR16_LatchClearedThenRearmed();`, just before the `SUMMARY` print |

### 2.1 V6, the collector (exact shape)

    int Grind_ReconCollectBrokerTickets(GrindReconTicket &tickets[])
    {
       int count = 0;
       int dupes_total = 0;
       int walks = 0;
       bool stable = false;
       while(walks < GRIND_RECON_SCAN_MAX_WALKS && !stable) {
          walks++;
          count = 0;
          ArrayResize(tickets, 0);
          const int positions_before = PositionsTotal();
          const int orders_before = OrdersTotal();

          for(int i = PositionsTotal() - 1; i >= 0; i--) {
             // the ticket line and three filters exactly as today (1214-1220)
             count = Grind_ReconAppendUnique(tickets, count,
                        (ulong)PositionGetInteger(POSITION_IDENTIFIER),
                        g_grind_recon_magic,
                        PositionGetString(POSITION_COMMENT),
                        PositionGetDouble(POSITION_PRICE_OPEN),
                        GRIND_RECON_TICKET_POSITION, dupes_total);
          }
          for(int i = OrdersTotal() - 1; i >= 0; i--) {
             // the ticket line and three filters exactly as today (1232-1238)
             count = Grind_ReconAppendUnique(tickets, count, ticket,
                        g_grind_recon_magic,
                        OrderGetString(ORDER_COMMENT),
                        OrderGetDouble(ORDER_PRICE_OPEN),
                        GRIND_RECON_TICKET_ORDER, dupes_total);
          }
          stable = Grind_ReconScanStable(positions_before, orders_before,
                                         PositionsTotal(), OrdersTotal());
       }
       if(Grind_ReconScanRaced(dupes_total, walks)) {
          const string detail = Grind_ReconScanDetail(dupes_total, walks, stable);
          Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail);
          Print(Grind_LogTag(), "WARN GRIND_RECON_SCAN ", detail);
       }
       return count;
    }

`dupes_total` counts over all walks. After `GRIND_RECON_SCAN_MAX_WALKS`
unstable walks the LAST walk is returned (deduplicated) and the marker
says `"stable":false` (GV-3).

MQL5 resolves functions defined later in the program: no forward
declarations anywhere. Every existing call site compiles unchanged (no
existing signature changes).

### 2.2 K11, publish and check (exact shape)

    bool Grind_ApiLimitsPublishAndCheck()
    {
       bool mismatch = false;
       if(GlobalVariableCheck(GRIND_API_LIMIT_STOP_GV) &&
          GlobalVariableCheck(GRIND_API_LIMIT_SOFT_GV)) {
          const int pub_stop = (int)GlobalVariableGet(GRIND_API_LIMIT_STOP_GV);
          const int pub_soft = (int)GlobalVariableGet(GRIND_API_LIMIT_SOFT_GV);
          if(pub_stop != g_grind_api_entry_stop || pub_soft != g_grind_api_soft_warn) {
             mismatch = true;
             const string detail = StringFormat(
                "{\"entry_stop\":%d,\"soft_warn\":%d,\"published_entry_stop\":%d,\"published_soft_warn\":%d}",
                g_grind_api_entry_stop, g_grind_api_soft_warn, pub_stop, pub_soft);
             Grind_ArchiveMarker("WARN", "API_LIMITS_MISMATCH", "", 0, detail);
             Print("WARN API_LIMITS_MISMATCH ", detail);
          }
       }
       GlobalVariableSet(GRIND_API_LIMIT_STOP_GV, g_grind_api_entry_stop);
       GlobalVariableSet(GRIND_API_LIMIT_SOFT_GV, g_grind_api_soft_warn);
       return mismatch;
    }

Only one of the two variables present counts as nothing published (no
WARN; both are then written). It never halts, never blocks an entry and
never changes the limits in force (GV-7).

## 3. COMMITS

1. **Tests first, against stubs.** V1, V6, V7's global (NOT the reset line
   in `Grind_ReconFailureClear`), K1, K3, K4, K6, K7, K8, K9, T1, T2 as
   written.
   STUBS: V2 appends ALWAYS (no duplicate loop, `dupes_io` untouched; the
   five fields set as written); V3 `return true;`; V4 `return false;`; V5
   `return "";`; V8 `return "";`; K2 empty body; K5 `return true;`; K10
   `return true;` (no other line); K11 `return false;` (no other line). V9 NOT
   applied. With these stubs the EA behaves exactly as today (one walk,
   every entry appended, no marker, limits at the defines, no Global
   Variable written). Commit message: tests first, the predicted failures
   (s4: 33) and guards (28).
2. **Implementation:** the V2, V3, V4, V5, V8, K2, K5, K10, K11 bodies as written; V9;
   the V7 reset line. Nothing else.

Do not compile (the operator compiles and runs the suite in MetaEditor on
the desktop and reports the counts; do NOT report a suite figure yourself).

## 4. TESTS (`ea/fxgrind_tests_v22a.mqh`; tags: F = fails at commit 1, G = guard, passes at both)

Constants in the new file: `const ulong V22A_MAGIC = 22260101UL;`. Every
RS test that calls `Grind_RebuildBookFromTickets` ends with
`Grind_ReconFailureClear(); Grind_TestResetSideState();`. Every AL test
starts and ends with `Grind_ApiCounterTestReset();`.

**RS1 AppendUnique** (7). `GrindReconTicket t[]; int n = 0; int d = 0;`
then four appends with `Grind_ReconAppendUnique(t, n, ..., d)`, `n` taking
the return each time: A = (9001, V22A_MAGIC, `GrindCommentBuild("OPT","L",1,"ENT")`,
0.85774, ORDER); B = A again; C = (9001, V22A_MAGIC, `GrindCommentBuild("OPT","L",0,"ENT")`,
0.85900, POSITION); D = (9002, V22A_MAGIC, `GrindCommentBuild("OPT","S",1,"ENT")`,
0.85600, ORDER).
Implementation: n after A, B, C, D = 1, 1, 2, 3; d = 1; t[2] = O 9002.
Stub (always appends): 1, 2, 3, 4; d = 0; t[2] = P 9001.
a G n == 1 after A; b F n == 1 after B; c F n == 2 after C; d F n == 3
after D; e F d == 1; f F `t[2].ticket == 9002 && t[2].kind == GRIND_RECON_TICKET_ORDER`;
g G `t[0]` holds ticket 9001, magic V22A_MAGIC, comment A, price 0.85774,
kind ORDER (one AssertTrue on all five).

**RS2 the C93 replay** (4). The halt's list: the `Test_N1` order (9001,
`GrindCommentBuild("OPT","L",1,"ENT")`, 0.85774, ORDER) read twice.
`raw[]`: append it twice with `Grind_TestAppendReconTicket` (no check);
`Grind_RebuildBookFromTickets(raw, 2, V22A_MAGIC, "OPT", 3.0, 12, 0.00001, lo, so, reason)`:
a G returns false; b G `reason == "AMBIGUOUS_ADD_LONG"` (A5: the second
copy of the same ticket). Reset (clear, reset side state). `dd[]`: append
it twice with `Grind_ReconAppendUnique` (count from the return; a local
dupes int); rebuild with the returned count, same arguments, fresh
`lo2`/`so2`/`reason2`: c F returns true (stub: count 2, fails as in a); d F
`reason2 == ""` (stub: "AMBIGUOUS_ADD_LONG"). Implementation: count 1, the
`Test_N1` book, ok.

**RS3 ScanStable** (5): a G `(5,10,5,10)` true; b F `(5,10,5,9)` false (an
order removed mid-walk: C93); c F `(5,10,6,10)` false; d F `(5,10,6,9)`
false (a limit filled between the two walks); e G `(0,0,0,0)` true.

**RS4 TicketsLogLine** (4). a F with t = [P 1001, O 9001] (any comment and
price), `Grind_ReconTicketsLogLine("I3_LONG_NAKED", t, 2)` ==
`"RECON_TICKETS reason=I3_LONG_NAKED n=2 P:1001 O:9001"`; b F empty list,
count 0, reason "X" == `"RECON_TICKETS reason=X n=0"`; the `Test_F6` list
(P 1001 then O 9000 .. O 9039, 41 entries; build it the same way): line L,
c F `StringFind(L, "O:9038 +1 more") >= 0` (40 emitted: P 1001 and O 9000
.. O 9038; one more); d G `StringFind(L, "O:9039") < 0` (stub "" also has
none).

**RS5 Capture logs locally, JSON stays ticket-free** (5). The `Test_F4`
fixture: one POSITION 87654321, V22A_MAGIC, `GrindCommentBuild("OPT","L",0,"ENT")`,
1.25000; rebuild with (3.0, 12, 0.00001) as F4 does. a G returns false
(I3_LONG_NAKED, as `Test_F3c` asserts on the same fixture); b F
`g_grind_recon_tickets_last_line == "RECON_TICKETS reason=I3_LONG_NAKED n=1 P:87654321"`
(stub and no V9: ""); c G `StringFind(g_grind_recon_failure_json, "87654321") < 0`;
d G `StringFind(Grind_TestSampleHeartbeatJson(), "87654321") < 0`; then
`Grind_ReconFailureClear();` e G `g_grind_recon_tickets_last_line == ""`.

**RS6 race note helpers** (5): a F `Grind_ReconScanDetail(1, 2, true)` ==
`{"dupes":1,"walks":2,"stable":true}`; b F `Grind_ReconScanDetail(0, 3, false)`
== `{"dupes":0,"walks":3,"stable":false}`; c G `Grind_ReconScanRaced(0, 1)`
false (the quiet case: no marker); d F `Grind_ReconScanRaced(1, 1)` true; e
F `Grind_ReconScanRaced(0, 2)` true.

**AL1 ValidateApiLimitInputs** (6): a G `(1000000, 999000)` true (the
defaults); b G `(1900, 1800)` true (the pre-hotfix values); c G
`(1900, 1900)` true; d F `(1800, 1900)` false (soft above stop); e F
`(0, 0)` false; f F `(1900, 0)` false.

**AL2 entry stop at a set limit** (4): `Grind_ApiLimitsSet(1900, 1800);`
a F `g_grind_api_entry_stop == 1900`; `Grind_ApiCounterTestSeed(1899);` b G
`!Grind_ApiCounterEntryStopped()` (1899 < 1900; stub 1899 < 1000000);
`Grind_ApiCounterTestSeed(1900);` c F `Grind_ApiCounterEntryStopped()`
(stub: 1900 < 1000000, false); `Grind_ApiCounterTestSeed(1000000);` d G
`Grind_ApiCounterEntryStopped()` (both).

**AL3 soft warn at a set limit** (4): `Grind_ApiLimitsSet(1900, 1800);`
`Grind_ApiCounterTestSeed(1799);` a G `!Grind_ApiCounterSoftWarnActive()`;
`Grind_ApiCounterTestSeed(1800);` b F `Grind_ApiCounterSoftWarnActive()`;
c F `g_grind_api_soft_warn == 1800`; `Grind_ApiCounterTestSeed(999000);` d G
`Grind_ApiCounterSoftWarnActive()`.

**AL4 the test reset restores the defaults** (3): `Grind_ApiLimitsSet(1900, 1800); Grind_ApiCounterTestReset();`
a G `g_grind_api_entry_stop == GRIND_DAILY_API_ENTRY_STOP`; b G
`g_grind_api_soft_warn == GRIND_DAILY_API_SOFT_WARN`; `Grind_ApiCounterTestSeed(1900);`
c G `!Grind_ApiCounterEntryStopped()`.

**AL5 the defaults are today's values** (2): after the reset, a G
`g_grind_api_entry_stop == 1000000`; b G `g_grind_api_soft_warn == 999000`
(literals: a later edit of a define shows here).

**AL6 invalid inputs keep the defines, no halt** (6): `Grind_ApiCounterTestReset();`
a G `Grind_ApiLimitsApplyInputs(1900, 1800)` true (stub true); b F
`g_grind_api_entry_stop == 1900` (stub: K2 and K10 set nothing); c F
`g_grind_api_soft_warn == 1800`; then d F `Grind_ApiLimitsApplyInputs(1800, 1900)`
false (soft above stop; stub true); e G `g_grind_api_entry_stop == GRIND_DAILY_API_ENTRY_STOP && g_grind_api_soft_warn == GRIND_DAILY_API_SOFT_WARN`
(implementation restores the defines; stub never left them); f F
`Grind_ApiLimitsApplyInputs(0, 0)` false (stub true).

**AL7 publish and check** (6). Start: `Grind_ApiCounterTestReset();` then
delete `GRIND_API_LIMIT_STOP_GV` and `GRIND_API_LIMIT_SOFT_GV` if present.
`Grind_ApiLimitsSet(1900, 1800);` a G `Grind_ApiLimitsPublishAndCheck()`
false (nothing published; stub false); b F `GlobalVariableCheck(GRIND_API_LIMIT_STOP_GV) && (int)GlobalVariableGet(GRIND_API_LIMIT_STOP_GV) == 1900`
(stub writes nothing); c F the same for `GRIND_API_LIMIT_SOFT_GV` == 1800;
`Grind_ApiLimitsSet(2000, 1800);` d F `Grind_ApiLimitsPublishAndCheck()`
true (published 1900 differs; stub false); e F `(int)GlobalVariableGet(GRIND_API_LIMIT_STOP_GV) == 2000`
(last init wins; stub: no variable, read 0); f G
`Grind_ApiLimitsPublishAndCheck()` false (now equal; stub false). End:
delete both variables, `Grind_ApiCounterTestReset();`.

Totals: **61 assertions; 33 F, 28 G** (RS1 7 = 5F 2G; RS2 4 = 2F 2G; RS3 5
= 3F 2G; RS4 4 = 3F 1G; RS5 5 = 1F 4G; RS6 5 = 4F 1G; AL1 6 = 3F 3G; AL2 4
= 2F 2G; AL3 4 = 2F 2G; AL4 3 = 3G; AL5 2 = 2G; AL6 6 = 4F 2G; AL7 6 = 4F
2G). At commit 1 the operator's suite reads 2508 total, 2475 passing,
exactly the 33 F failing; at commit 2 2508/2508. ANY other count, any G failing, or any existing test
changing: STOP and report (s6).

The collector itself (V6) reads the live broker lists and is not
unit-tested; its parts are (V2-V5). Review it against s2.1 line by line.

## 5. NEGATIVE SPACE

- Do not change `Grind_RebuildBookFromTickets` or its inner function, any
  invariant, any reason string, `Grind_IsQuarantinableReason` (AMBIGUOUS
  stays a halt, GV-4), the quarantine, `Grind_ReconstructState` or
  `Grind_CheckBookInvariants` (they call the collector unchanged).
- Do not add a ticket number to `g_grind_recon_failure_json`, the
  heartbeat, any archive marker or any telemetry (A6; `Test_F4` must pass
  unchanged).
- Do not touch the other list walks that share the race but only count or
  report (`Grind_OwnRestingEntryCount`, `Grind_SlotUsed`,
  `Grind_SlotRestingEnt`, `Grind_CapComputeOwnLegExposure`, the heartbeat
  book and detail, the snapshot, P&L). Noted for the backlog, not v2.2a.
- Do not change `GRIND_DAILY_API_SOFT_WARN`, `GRIND_DAILY_API_ENTRY_STOP`,
  `GRIND_DAILY_API_LIMIT`, the counter's Global Variables, its daily reset
  or `Grind_OrderSendCounted`. Do not touch `fxmatrix_v2_*` (the old EA).
  The two NEW variables of K9 are the only Global Variables this prompt
  adds.
- No `return INIT_FAILED`, FATAL, halt, quarantine, `ExpertRemove` or
  entry block for any API limit value or mismatch (A17, A18): the only
  reactions are the two WARN markers and their Print lines.
- Do not touch presets (the defaults equal today's hotfix values), pipshed,
  docs, or any file not in s2. Do not change any existing test or its
  expected values.
- Do not compile, do not launch MetaTrader, do not run the suite, do not
  CLI compile. Do not `git stash`, do not check out files from other
  commits, do not merge, no PR, no force-push, no `git add .` or `-u`
  (add each file by name).

## 6. FAILURE MODES: STOP AND REPORT

- Step 0's diff is not empty.
- A design line here conflicts with another (report the two lines; do not
  choose).
- A helper or line named in s2 or s4 does not exist with the shape
  described.
- After commit 1 the F/G derivation looks wrong for any assertion when you
  re-derive it against your stubs (report which; do not change it).
- You need to change anything outside s2.

## 7. REPORT

Per commit: hash, files, `git diff --stat`; the 61 assertion names with
their tags; for commit 1 your own re-derivation of each F/G against the
stubs (agree / disagree with reason). No suite figure.

## 8. FOR GEMINI (on this prompt, before Cursor starts)

- **GV-1 Tickets in the local log only.** Backlog C93 asked for ticket
  numbers in the recon-failure detail. That JSON rides the heartbeat to the
  public status endpoint, which ADR-125 keeps free of broker identifiers
  (`Test_F4`). This prompt prints them in one Experts log line
  (`RECON_TICKETS`, same order as the JSON rows, printed on change only).
  The log was where C93 was solved (the Journal). Object?
- **GV-2 Count check, not a set check.** A walk is "stable" when both
  totals match before and after. A same-count swap during one walk (one
  order placed and another removed by other EAs within microseconds) is not
  seen. Deduplication still removes any duplicate it causes; only a SKIP in
  that window remains, and a skip of an exit or a position gives a
  quarantinable I3 / I4 that clears on the next tick (A4). Comparing two
  consecutive walks' ticket sets would double the walk cost on every tick.
  Acceptable?
- **GV-3 Three unstable walks.** The last walk is used, deduplicated, and
  `RECON_SCAN_RACE` says `"stable":false`. The alternative is "no verdict
  this tick" (the check returns the previous result). That hides a real
  failure for a tick, and at init there is no previous result. Which?
- **GV-4 AMBIGUOUS stays a halt.** With the false duplicate removed at the
  source, a second distinct add or L0 order is real and should halt at
  once, as today. Agree, or quarantine it too?
- **GV-5 Limits per chart, counter per terminal.** `InpApiSoftWarn <=
  InpApiEntryStop` is enforced at init. Charts on one terminal share one
  counter, so mismatched presets would stop charts at different counts.
  Runbook rule (same values on every chart; the `GRIND_API_LIMITS` line and
  `API_LIMITS_CONFIG` marker show each chart's values), or enforce in code
  (publish to a Global Variable, FATAL on mismatch)?
- **GV-6** Any test you would add, or any F/G tag you derive differently?

**Second pass (the amendments of s9):**
- **GV-7 Mismatch is a WARN, last init wins.** K11 compares this chart's
  limits with the two published variables, WARNs on a difference, then
  overwrites them. The read-compare-write is not atomic: two charts
  initialising in the same instant (a compile re-inits every chart) can
  miss or duplicate a WARN; changing the limits fleet-wide WARNs on the
  first charts reloaded until all match. Nothing trades differently
  because of K11. Acceptable for a warning, or name a concrete failure.
- **GV-8 Invalid inputs fall back to the defines with a WARN, not a
  FATAL.** This departs from ADR-153's sanity-FATAL pattern; the
  fallback (1000000 / 999000) is today's behaviour, so a typo leaves the
  chart trading as now instead of unloaded with its book unmanaged
  (A17). Any reason the fallback itself is unsafe?
- **GV-9** Re-derive AL6 and AL7's F/G tags against the stubs of s3.

## 9. GEMINI'S FIRST REVIEW (3 OCT ~17:40Z) AND CLAUDE'S CHECK

- **GV-1 ACCEPTED** (tickets in the local log only).
- **GV-2 ACCEPTED.** His "massive computational penalty" for a set check
  overstates it (at most 200 tickets); the ruling stands on the
  quarantine absorbing a one-tick skip (A4).
- **GV-3 ACCEPTED** (use the last walk, `"stable":false`).
- **GV-4 ACCEPTED** (AMBIGUOUS stays an immediate halt). His "double
  leverage for 3 seconds" is not the mechanism (a halt cancels entries;
  the reason to halt is a real second order for one layer).
- **GV-5 REJECTED as ruled; AMENDED by the operator.** Gemini: publish
  the limits to Global Variables at the first chart's init and FATAL any
  later chart whose inputs differ. A FATAL at init unloads the EA and
  leaves its book unmanaged (A17), and a fleet-wide change would need
  the variables deleted by hand and every chart reloaded; his "fracturing
  the fleet's geometric structure" does not apply (the limits touch no
  geometry, and at the defaults no chart reaches them). Operator (A18):
  "a warning is sufficient". Built as K9-K11 (publish, compare, WARN,
  never halt); and by the same ruling K7's FATAL on invalid inputs
  became a fallback to the defines with a WARN (K7, K8, K10).
- **GV-6:** he re-derived RS1-RS3 only. Claude re-derived all 49 of the
  first pass and the 12 new ones (AL6, AL7) against the stubs of s3:
  33 F, 28 G, as tagged.

Line count: 432
