This message has a line count at the bottom

# CURSOR SPEC -- ADR-164 MISSED-DEAL REPLAY + C77 (fxgrind EA)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat
in that workspace. Branch `adr164-deal-replay` from `origin/main`
`7a56f22` (EA code there == `6a1e9ad` == `2ff62f4`, suite 2220/2220 on
GBPUSD and EURUSD). Design: `docs/architecture/ADR-164-missed-deal-replay.md`
(ACCEPTED rev 3) -- read it in full first. Written by Claude from source
at `7a56f22`, 28 Sep ~22:30Z. Line numbers are that commit.

**Gemini: questions for you are in s9 (SQ1-SQ7). Everything else is for
Cursor. Cursor: do not start until the operator says Gemini has ruled;
the operator will paste any amendments above this line.**

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1-A11 | The ADR's audit trail (box 2 resync 28 Sep 16:27Z; two GBPUSD_OPTC fills with no `OnTradeTransaction`; both deals in local history after the resync (P1); `HistoryDealSelect` replaces the `HistorySelect` list (A10); C77) | ADR-164 | VERIFIED (see ADR) |
| S1 | `Grind_OnTradeTransactionEngine` (engine 3020-3045): archive on DEAL_ADD, return if halted, return if not DEAL_ADD, set add globals, call `Grind_HandleSideDealFill` long then short. Reordering to "return if not DEAL_ADD; archive; return if halted; ..." is behaviour-identical | engine 3031-3044 | VERIFIED in source |
| S2 | The test script includes `grind_engine.mqh`, not `fxgrind.mq5`: `OnInit`/`OnTimer`/`OnTick` wiring cannot be unit-tested. Keep the wiring to single calls; Claude reviews it by diff | `fxgrind_tests.mq5` 11-27 | VERIFIED |
| S3 | `Grind_ExitQFindExitDealPosition` has a separate branch when `g_grind_deal_test_active` (engine 3055-3074) that never touches the history list, so no existing test can see A10/C77 | engine 3047-3101 | VERIFIED |
| S4 | `fxgrind_tests_adr151.mqh` 16 and 20 forward-declare `Grind_ExitQHoldCancelLayer` and `Grind_HandleSideDealFill`. Their SIGNATURES MUST NOT CHANGE (a mismatched declaration is a second, bodiless function: 02_TRAPS 25 Sep B1) | adr151 test header | VERIFIED |
| S5 | pipshed `fill_logs` has `UNIQUE (instance_id, deal_ticket)` and the worker inserts `ON CONFLICT DO NOTHING`: a duplicate `fill_log` row is dropped downstream (belt and braces; the EA must still not send one) | pipshed `migrations/001_archive_phase1.sql`, `archive_worker.py` 736 | VERIFIED |
| S6 | Program globals survive a reason-5 (input change) reinit; `g_grind_processed_deals` is never reset outside tests. Replay state must be reset explicitly in `OnInit` | 02_TRAPS (C79 entry); `grind_state.mqh` 47-48 | VERIFIED (reset); reinit persistence INFERRED from MQL5 behaviour |
| S7 | The ENT branch of `Grind_HandleSideDealFill` appends a layer with no check that the position is already a layer (engine 2664-2670). An ENT deal that is handled twice (event plus replay, or recon plus a late event) would append a second layer | engine 2664-2690 | VERIFIED in source; the double delivery is what this change could introduce, so it is guarded (D3) |
| S8 | `Grind_QueueCloseBy` de-duplicates identical pairs (closeby 105-110); the close-by queue discards a task whose positions are gone and appear in history (closeby 188-198) | `grind_closeby.mqh` | VERIFIED |
| S9 | Other `HistorySelect` users (breaker engine 1482 and 1541, snapshot `grind_snapshot.mqh` 270) select then read by ticket in one function with no select inside the loop: unaffected | engine, snapshot | VERIFIED |
| S10 | `Grind_CheckBookInvariants` (recon 1253) rebuilds from the broker book (positions and orders), not from the engine's layers: after a replayed ENT the invariant passes once the exit ORDER is visible in the terminal | recon 1209-1278 | VERIFIED in source; order visibility right after `OrderSend` is broker timing (GQ4: re-check on the same tick; a quarantine may still start and release) |

## 1. WHAT TO BUILD (summary)

1. A deal-history SWEEP that finds deals of this EA (symbol and magic)
   that are in the terminal's local history but were never handled, and
   feeds them through the SAME code the `OnTradeTransaction` path uses.
   Runs every `OnTimer` call (1 s) and, throttled, on the tick path when
   the invariant fails, before the quarantine step (ADR D1, D5).
2. A SEEN set, separate from the processed list (D2); seeded at init with
   the deals already reflected by reconstruction (D3).
3. Idempotency guards in the handler (D3, S7).
4. Evidence: archive markers `DEAL_REPLAYED`, `DEAL_EVENT_AFTER_REPLAY`,
   `DEAL_EVENT_MISSED`, `CONNECTION_RESTORED` (D6), and `GRIND_REPLAY`
   journal lines.
5. C77 (D6a): `Grind_ExitQFindExitDealPosition` reads each deal by ticket
   from the `HistorySelect` list; the special test branch goes; its
   caller's miss branch is UNCHANGED (Gemini GF-1).
6. A test seam that MODELS A10 (the list replacement), so the tests can
   fail the way the live terminal fails.

NO new input (operator + Gemini, GQ5). Always on.

## 2. FILES

| File | Change |
|---|---|
| `ea/grind_replay.mqh` | NEW. Everything in s3.2-s3.7 |
| `ea/grind_engine.mqh` | history seams (s3.1) after `Grind_DealGetDouble` (2557); `Grind_ProcessDeal` extracted from `Grind_OnTradeTransactionEngine` (s3.4); guards in `Grind_HandleSideDealFill` (s3.5); `Grind_ExitQFindExitDealPosition` (s3.8); `#include "grind_replay.mqh"` at the END, next to `grind_heartbeat_detail.mqh` (3313) |
| `ea/fxgrind.mq5` | three single-call edits (s3.9) |
| `ea/fxgrind_tests_adr164.mqh` | NEW. The tests in s5 |
| `ea/fxgrind_tests.mq5` | `#include "fxgrind_tests_adr164.mqh"` after `fxgrind_tests_rb.mqh` (27); call the new tests at the END of `OnStart`, before the summary |

MQL5 resolves functions defined later in the program: no forward
declarations are needed anywhere (02_TRAPS 25 Sep B1). Do not add any.

## 3. DESIGN DETAIL

### 3.1 History seams (engine, after 2557)

```
bool     g_grind_hist_test_active = false;   // model the history list (A10)
datetime g_grind_hist_test_now = 0;          // server time in the model
ulong    g_grind_hist_test_list[];            // the current "selected" list
int      g_grind_hist_test_list_count = 0;
ulong    g_grind_hist_test_select_fail_ticket = 0;  // Grind_DealSelect fails for this one

void     Grind_HistTestReset();               // clears the five above
datetime Grind_HistNow();                     // hist_test_active ? g_grind_hist_test_now : TimeCurrent()
bool     Grind_HistSelect(const datetime from, const datetime to);
int      Grind_HistDealsTotal();
ulong    Grind_HistDealTicket(const int index);
```

Behaviour:
- Live (neither test flag): `HistorySelect`, `HistoryDealsTotal`,
  `HistoryDealGetTicket`.
- `g_grind_hist_test_active`: `Grind_HistSelect` sets the list to the
  tickets of `g_grind_deal_test_records` whose `deal_time` is in
  [from, to], in record order, returns true. `Total`/`Ticket` read the
  list (`Ticket` out of range returns 0).
- `g_grind_deal_test_active` only (existing tests): `Grind_HistSelect`
  lists ALL records (no time filter, so today's ExitQ tests keep their
  meaning), returns true.
- Change the existing `Grind_DealSelect` and `Grind_DealGet*` (engine
  2490-2557): when `g_grind_hist_test_active` they come FIRST and model
  A10: `Grind_DealSelect(t)` returns false if `t` is not a record or
  `t == g_grind_hist_test_select_fail_ticket`; otherwise it REPLACES the
  list with `[t]` and returns true. `Grind_DealGet*(t, ...)` returns
  0 / "" / 0.0 when `t` is not in the current list, else the record's
  field (same field mapping as today). When only `g_grind_deal_test_active`
  is set, behaviour is exactly today's.
- `Grind_DealTestReset` also calls `Grind_HistTestReset`.

### 3.2 Replay state (`grind_replay.mqh`)

```
#define GRIND_REPLAY_MARGIN_S       120
#define GRIND_REPLAY_TO_AHEAD_S     3600
#define GRIND_REPLAY_TICK_MIN_MS    1000
#define GRIND_REPLAY_EVENT_WAIT_MS  60000

struct GrindReplaySeen
{
   ulong ticket;
   long  deal_time_msc;
   bool  replayed;         // handled by the sweep
   ulong replay_ms;        // GetTickCount64 at replay
   bool  event_seen;       // DEAL_ADD arrived after the replay
   bool  missed_reported;  // DEAL_EVENT_MISSED emitted
};
```
Globals: the array and count; `g_grind_replay_ready`,
`g_grind_replay_init_time`, `g_grind_replay_last_sweep_time`,
`g_grind_replay_last_tick_sweep_ms`, `g_grind_replay_connected`,
`g_grind_replay_down_since_ms`. Test seams: `g_grind_replay_test_connected_active`,
`g_grind_replay_test_connected`; `g_grind_replay_test_inv_active`, a
scripted `bool` results array with a `string` reason array, a read index
and `g_grind_replay_test_inv_calls`.

Functions (names are binding; the tests call them):
```
void     Grind_ReplayReset();                 // everything above to zero/false, test seams off
bool     Grind_ReplayIsSeen(const ulong ticket);
bool     Grind_ReplayWasReplayed(const ulong ticket);
int      Grind_ReplaySeenCount();
void     Grind_ReplayMarkSeen(const ulong ticket, const long deal_time_msc);   // no duplicate entries
datetime Grind_ReplayWindowFrom(const datetime init_time, const datetime last_sweep_time,
                                const int margin_s);       // PURE: max(init_time, last_sweep_time - margin_s)
bool     Grind_ReplayTerminalConnected();     // seam, else TerminalInfoInteger(TERMINAL_CONNECTED) != 0
int      Grind_ReplayInit(const ulong magic, const ulong now_ms);   // returns seeded count
int      Grind_ReplaySweep(<P>, const string path, const ulong now_ms);   // returns replayed count
void     Grind_ReplayOnTimer(<P>, const ulong now_ms);
bool     Grind_ReplayCheckInvariants(<P>, const ulong now_ms);
bool     Grind_ReplayInvariantOk();           // seam, else Grind_CheckBookInvariants()
bool     Grind_ReplayConnectionStep(const bool connected, const ulong now_ms);   // true on restored edge
void     Grind_ReplayCheckMissed(const ulong now_ms);
void     Grind_ReplayPrune(const datetime from);
bool     Grind_ReplayNoteEvent(const ulong ticket);   // true if the ticket was replayed (sets event_seen)
void     Grind_ReplayMarkSeenIfOurs(const ulong ticket, const ulong magic);
```
`<P>` = exactly the parameter list of `Grind_OnTradeTransactionEngine`
after `trans`: `magic, slot, exit_pips, add_pips, deadband_pips,
max_layers, lots, exit_pips_short, add_pips_short` (same types, same
order, same defaults).

### 3.3 Init and seed (D3)

`Grind_ReplayInit(magic, now_ms)`: `Grind_ReplayReset()` (S6); init time
= `Grind_HistNow()`; last sweep time = init time; `g_grind_replay_connected`
= `Grind_ReplayTerminalConnected()`; then SEED:
`Grind_HistSelect(init - GRIND_REPLAY_MARGIN_S, init + GRIND_REPLAY_TO_AHEAD_S)`,
and for every ticket of `_Symbol` with a matching magic
(`Grind_MagicMatches`), `Grind_ReplayMarkSeen` (NOT replayed): those
deals are already reflected in the book `Grind_ReconstructState` built.
Read by ticket from the list; NO `Grind_DealSelect`. If the select
fails: `Grind_ArchiveMarker("WARN", "REPLAY_SEED_FAILED", "", 0, "{}")`
and carry on (the guards of s3.5 protect the book). Then ready = true;
`Print(Grind_LogTag(), "GRIND_REPLAY ready seeded=", n)`. Return n.

### 3.4 One deal, two paths

`Grind_ProcessDeal(const ulong deal_ticket, <P>)` in the engine: the
CURRENT body of `Grind_OnTradeTransactionEngine` for a DEAL_ADD,
unchanged in effect: `Grind_ArchiveRecordFill(deal, magic)`; return if
`g_grind_halted`; set `g_grind_engine_add_pips` and
`g_grind_engine_add_pips_short`; the two `Grind_HandleSideDealFill`
calls with the same arguments as today.

`Grind_OnTradeTransactionEngine` becomes (S1):
```
if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
if(Grind_ReplayNoteEvent(trans.deal)) {          // the sweep handled it already
   Grind_ArchiveMarker("INFO", "DEAL_EVENT_AFTER_REPLAY", "", trans.deal, "{}");
   return;                                         // no second archive row, no second handling
}
Grind_ReplayMarkSeenIfOurs(trans.deal, magic);   // marks only after a successful select (GQ2)
Grind_ProcessDeal(trans.deal, <P>);
```
`Grind_ReplayMarkSeenIfOurs`: if `Grind_DealSelect(t)` succeeds and the
symbol is `_Symbol` and the magic matches, `Grind_ReplayMarkSeen(t,
DEAL_TIME_MSC)`. If the select fails, nothing is marked and the sweep
picks the deal up later (GQ2).

### 3.5 Guards in `Grind_HandleSideDealFill` (D3, S7)

Signature unchanged (S4). Two early returns, nothing else changes:
- ENT branch, after `Grind_MarkDealProcessed` and BEFORE the pending-ticket
  clears and `Grind_AppendLayer`: if `Grind_FindLayerByPosition(side,
  position_id) >= 0`, print `WARN GRIND_REPLAY duplicate ENT ignored
  deal=... position=...` and return.
- EXT branch, after `layer_idx` is found: if
  `side.layers[layer_idx].exit_position_ticket == position_id` (non-zero),
  return before touching the layer, the close-by queue or the
  microstructure queue.

### 3.6 The sweep (D1, D4)

`Grind_ReplaySweep(<P>, path, now_ms)`:
1. Return 0 if not ready.
2. `now = Grind_HistNow()`; `from = Grind_ReplayWindowFrom(init, last_sweep, GRIND_REPLAY_MARGIN_S)`.
3. `Grind_HistSelect(from, now + GRIND_REPLAY_TO_AHEAD_S)`; on failure
   return 0 WITHOUT advancing the last sweep time.
4. PHASE 1, SNAPSHOT (A10): for i in 0..total-1: `t = Grind_HistDealTicket(i)`;
   skip 0; read symbol, magic, `DEAL_TIME_MSC` BY TICKET via
   `Grind_DealGet*` (NO `Grind_DealSelect` in this phase); keep it if it
   is `_Symbol`, the magic matches and `!Grind_ReplayIsSeen(t)`. Copy
   ticket and time into a local array.
5. Sort the copy ascending by (deal_time_msc, ticket).
6. PHASE 2, for each copied ticket in order:
   - `if(!Grind_DealSelect(t)) continue;` (GQ2: not marked; retried next sweep)
   - read entry type and comment (parse with `GrindCommentParse`; on
     failure role "", side "", layer -1)
   - `Grind_ProcessDeal(t, <P>)` (halted: archive only, D4, via
     `Grind_ProcessDeal`'s own halted return)
   - mark it seen AND replayed (`replay_ms = now_ms`)
   - `Grind_ArchiveMarker("INFO", "DEAL_REPLAYED", "", t, detail)` with
     detail exactly:
     `{"path":"<path>","entry":"<IN|OUT|OUT_BY|...>","role":"<role>","side":"<L|S|>","layer":<n>,"deal_time_msc":<msc>,"owned":<true|false>,"halted":<true|false>}`
     where entry uses `Grind_ArchiveEntryTypeLabel`, `owned` =
     `Grind_DealWasProcessed(t)` after processing, `halted` =
     `g_grind_halted`.
   - `Print(Grind_LogTag(), "WARN GRIND_REPLAY deal=", t, " path=", path, " role=", role, " side=", side, " layer=", layer)`
7. last sweep time = now; `Grind_ReplayPrune(from)`; return the count.

### 3.7 Timer, tick path, connection, missed, prune

`Grind_ReplayOnTimer(<P>, now_ms)`:
`Grind_ReplayConnectionStep(Grind_ReplayTerminalConnected(), now_ms)`;
`Grind_ReplaySweep(<P>, "timer", now_ms)`; `Grind_ReplayCheckMissed(now_ms)`.
(ADR D6's "force a sweep on the next timer call" needs no mechanism: the
sweep runs on every timer call.)

`Grind_ReplayCheckInvariants(<P>, now_ms)` (D5, GQ4):
```
bool ok = Grind_ReplayInvariantOk();
if(ok || !g_grind_replay_ready || g_grind_halted) return ok;
if(g_grind_replay_last_tick_sweep_ms != 0 &&
   now_ms - g_grind_replay_last_tick_sweep_ms < GRIND_REPLAY_TICK_MIN_MS) return ok;
g_grind_replay_last_tick_sweep_ms = now_ms;
if(Grind_ReplaySweep(<P>, "tick", now_ms) == 0) return ok;   // nothing replayed: no re-check
return Grind_ReplayInvariantOk();                             // same tick (GQ4)
```
`Grind_ReplayInvariantOk()`: with the test seam, return the next scripted
result, set `g_grind_invariant_reason` to the scripted reason, count the
call; else `return Grind_CheckBookInvariants();`.

`Grind_ReplayConnectionStep(connected, now_ms)`: if the previous state
was connected and now is not, `down_since = now_ms`, return false. If
the previous was not connected and now is:
`Grind_ArchiveMarker("INFO", "CONNECTION_RESTORED", "", 0, "{\"down_ms\":<now_ms - down_since>}")`,
`Print(... "INFO GRIND_REPLAY connection restored down_ms=" ...)`,
return true. Otherwise false. Always store the new state. (If the EA
started disconnected, `down_since` is 0: report `down_ms` as -1.)

`Grind_ReplayCheckMissed(now_ms)`: for each entry with replayed, not
event_seen, not missed_reported and `now_ms - replay_ms >=
GRIND_REPLAY_EVENT_WAIT_MS`: `Grind_ArchiveMarker("WARN",
"DEAL_EVENT_MISSED", "", ticket, "{\"deal_time_msc\":<msc>}")`, Print a
WARN line, set missed_reported. (This is the C76 detector: a normal
event arrives within milliseconds of a tick-path replay; a missed one
never arrives. SQ3.)

`Grind_ReplayPrune(from)`: remove entries with `deal_time_msc <
from * 1000` EXCEPT replayed entries still waiting (not event_seen and
not missed_reported).

### 3.8 C77 (D6a): `Grind_ExitQFindExitDealPosition`

Signature unchanged. Delete the `g_grind_deal_test_active` branch
(3055-3074). One path for live and tests:
```
position_out = 0;
const datetime now = Grind_HistNow();
if(!Grind_HistSelect(now - 30 * 86400, now + GRIND_REPLAY_TO_AHEAD_S)) return false;
const int total = Grind_HistDealsTotal();
for(int i = total - 1; i >= 0; i--) {
   const ulong t = Grind_HistDealTicket(i);
   if(t == 0) continue;
   // read ORDER, ENTRY, MAGIC, COMMENT, POSITION_ID by ticket via Grind_DealGet*;
   // NO Grind_DealSelect / HistoryDealSelect anywhere in this function (A10, C77)
   ... same filters and return as today ...
}
return false;
```
(`to` moves from `TimeCurrent()` to `now + 3600`: a deal stamped after
the last quote is no longer excluded. SQ6.) `Grind_ExitQHoldCancelLayer`
is NOT changed: the miss branch still zeroes the ticket and deletes the
shift (GF-1).

### 3.9 `fxgrind.mq5` (three single-call edits; not unit-testable, S2)

- `OnInit`: after the reconstruction block (after the closing brace at
  279), before `Grind_CarryPruneShiftGvs` (281):
  `Grind_ReplayInit(InpMagic, GetTickCount64());`
- `OnTimer`: FIRST statement:
  `Grind_ReplayOnTimer(InpMagic, InpSlot, g_geo_exit_long, g_geo_add_long, InpDeadbandPips, InpMaxLayers, InpLots, g_geo_exit_short, g_geo_add_short, GetTickCount64());`
- `OnTick` 409: `const bool ok = Grind_CheckBookInvariants();` becomes
  `const bool ok = Grind_ReplayCheckInvariants(<same arguments as OnTimer>, GetTickCount64());`
  Line 410 (`Grind_QuarantineStep`) and everything else unchanged.

## 4. COMMITS

1. **Tests and stubs** (`ADR-164 tests first: ...`). Adds
   `fxgrind_tests_adr164.mqh`, its include and calls; `grind_replay.mqh`
   with every s3.2 function as a STUB (returns false / 0 / no-op; the
   struct and globals real; `Grind_ReplayReset` and `Grind_HistTestReset`
   real because they only clear state); the s3.1 seam globals and the
   four seam functions as stubs (`Grind_HistNow` returns `TimeCurrent()`,
   `Grind_HistSelect` false, `Total` 0, `Ticket` 0); the include at the
   end of the engine. NO production behaviour change: nothing existing
   calls a stub. `fxgrind.mq5` untouched.
2. **Implementation** (`ADR-164: ...`). Everything else in s3.

Push the branch after each commit (`git push -u origin adr164-deal-replay`).
The operator compiles in MetaEditor and runs the suite on the DESKTOP
terminal after each commit (checkout, `desktop_sync.ps1`, GUI compile,
run). You do not compile and you do not run the suite (s7).

## 5. TESTS (`fxgrind_tests_adr164.mqh`)

Conventions: names `Test_DR<n>_<Name>` / `Test_EQH<n>_<Name>`;
assertion names start with the test id. **Every assertion that must PASS
at commit 1 (a guard) ends its name with ` (guard)`.** Every other new
assertion must FAIL at commit 1. Guard every array index a failing
assertion could make -1 (02_TRAPS, ADR-153 section, stub-check). Each test resets what it
uses at start AND end: `Grind_ReplayReset`, `Grind_DealTestReset`
(which resets the history seam after commit 2; call `Grind_HistTestReset`
explicitly too), `Grind_OrderTestReset`, `Grind_CloseByTestReset`,
`Grind_TestResetSideState`, `Grind_ArchiveTestReset`, and whatever else
the setup it copies uses. Set EVERY field of any layer you create (use
`Adr151_TestSetupLongLayer` for long layers; for short layers set all
six fields by hand). Expected values below are derived by hand; write
the derivation as a comment above each assertion.

Common fixture unless a test says otherwise:
- magic 22260101 (the `Grind_TestAppendDeal` default), slot "OPT",
  `<P>` = `22260101UL, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0` (as
  GV7/GV8: long exit 10, long add 10, deadband 4, max 8, lots 0.01,
  short exit 7, short add 6).
- ENT fixtures copy `Test_GV7_FillShortExitAndAdd` (`fxgrind_tests_gv.mqh`
  254) setup exactly (order seam, `Adr152_TestPrepareIsolation`,
  `Grind_EngineConfigureAdr152(true, 0)`, `Adr152_TestSeedSlotSeams(200, 100, 0)`,
  `g_grind_ent_sent_this_tick = false`), with
  `Grind_MarketTestSeed(1.32781, 1.32791, 0)`, and its teardown
  (`Adr152_TestResetAll`, restore `g_grind_engine_add_pips` and
  `g_grind_recon_exit_pips`).
- Archive: `Grind_ArchiveTestReset(); Grind_ArchiveTestConfigureCommon();`
  count rows with `Grind_ArchiveQueueCount`/`Grind_ArchiveQueuePeek`;
  a fill row contains `"type":"fill_log"`, a marker contains
  `"type":"ea_event"` and its code.
- History model: `g_grind_hist_test_active = true`;
  init time I = `D'2026.09.28 19:27:00'`; `g_grind_hist_test_now` =
  `D'2026.09.28 19:27:35'` unless stated; `Grind_ReplayInit(22260101UL, 1000)`
  BEFORE appending the records that must count as post-init (records
  present at init are seeded).
- Deals from probe P1 (ADR A9), times server:
  ENT_S = deal 1583979787, order 1970173871, position 1970173871,
  `GRIND|OPT|S|L00|ENT` (DR1) or `L05` (DR8), IN, 1.32781, 19:27:19.
  EXT_L = deal 1583980820, order 1968650001, position 1968639465,
  `GRIND|OPT|L|L00|EXT`, IN, 1.32785, 19:27:22; its layer: long L00,
  entry 1.32685, position 1968000001, exit order 1968650001, exit pips 10.
- Every exit order a fixture layer holds is ALSO upserted into the order
  seam with its comment and price (as FL1 does, `fxgrind_tests_adr151.mqh`
  1447-1455), so the handler sees a consistent book.
- DR9 and anything feeding `Grind_QuarantineStep` calls
  `Grind_QuarantineReset()` at start and end.

| Test | Setup | Assertions (expected by hand) |
|---|---|---|
| DR1_ReplayMissedEnt | empty book; ENT_S (L00) in history after init; no event | sweep ("timer") returns 1; short depth 1, its position 1970173871, layer 0; exit target 1.32711 (1.32781 - 7 pips); exit ORDER placed at 1.32711; short add pending at 1.32841 (1.32781 + 6 pips, as GV7); exactly 1 `fill_log` row; exactly 1 `DEAL_REPLAYED` with `"role":"ENT"`, `"side":"S"`, `"layer":0`, `"path":"timer"`, `"owned":true`; `Grind_ReplayWasReplayed` true |
| DR2_ReplayMissedExt | the long L00 layer; EXT_L in history; no event | sweep returns 1; layer exit_order_ticket 0, exit_position_ticket 1968639465; long close-by queue size 1 with (1968000001, 1968639465); 1 `fill_log`; 1 `DEAL_REPLAYED` `"role":"EXT"` `"side":"L"` |
| DR3_ReplayMissedOutBy | long L00 with exit_position 1968639465 (EXT already known); two OUT_BY deals at 19:27:25: 1583981001 position 1968000001 (profit 1.00, commission -0.04) and 1583981002 position 1968639465 (profit 0.00, commission -0.04), empty comments | sweep returns 2; long depth 0; `g_grind_scalp_count` +1 exactly; `g_grind_scalp_event_queue_count` +1 exactly; 2 `DEAL_REPLAYED`, the first `"owned":true`, the second `"owned":false` |
| DR4_EventThenSweep | ENT_S (L00) delivered by `Grind_OnTradeTransactionEngine` (DEAL_ADD) | `Grind_ReplayIsSeen` true; then sweep returns 0; depth 1 (guard); `fill_log` rows 1 (guard); no `DEAL_REPLAYED` (guard) |
| DR4b_SweepThenEvent | ENT_S swept first, then its DEAL_ADD event | one `DEAL_EVENT_AFTER_REPLAY`; depth 1 (guard); `fill_log` rows 1 |
| DR5_InitSeedAndWindow | records BEFORE init: ours at 19:26:10 (seeded) and 19:24:00 (outside seed and window); init; then ours at 19:27:19 | init returns 1 (only 19:26:10 seeded); sweep returns 1; the 19:27:19 deal replayed; the 19:26:10 and 19:24:00 deals not replayed (guard, both) |
| DR6_HaltedArchivesOnly | `g_grind_halted = true`; ENT_S in history | sweep returns 1; 1 `fill_log`; short depth 0 (guard); no order placed (guard); `DEAL_REPLAYED` with `"halted":true`, `"owned":false`; replayed true |
| DR7_OtherMagicOrSymbolIgnored | ENT_S; a copy with magic 22260102; a copy with symbol "XAUUSD" (edit the record after appending) | sweep returns 1; only ENT_S replayed; the two others not replayed and not seen (guard) |
| DR8_Resync0928TimeOrder | 28 Sep reproduction: short side holds L04 (position 1970170001, exit order 1970170002, entry 1.32711); long L00 as above; records appended EXT_L FIRST, then ENT_S (L05) | sweep returns 2; short depth 2 with a layer of position 1970173871, index 5, exit order non-zero; long L00 exit_position 1968639465 and close-by queued; the two `DEAL_REPLAYED` markers in DEAL-TIME order: ENT_S's before EXT_L's (queue index) |
| DR9_TickSweepBeforeQuarantine | ENT_S in history; invariant seam scripted [false "I3_SHORT_NAKED", true] | `Grind_ReplayCheckInvariants(<P>, 10000)` returns true; seam calls 2; then `Grind_QuarantineStep(ok, g_grind_invariant_reason, 10000)` returns `GRIND_INV_OK`; not quarantined; no `QUARANTINE_ENTER` marker; one `DEAL_REPLAYED` `"path":"tick"` |
| DR9b_TickThrottle | after DR9's call; a second unseen deal; scripted [false] at now_ms 10500 | returns false; seam calls 1; the second deal not replayed; at now_ms 11000 with scripted [false, true] it is replayed and returns true |
| DR9c_NothingToReplayNoRecheck | nothing unseen; scripted [false] at 20000 | returns false; seam calls exactly 1 |
| DR10_WindowFrom | pure | (I, I, 120) -> I; (10:00:00, 19:30:00, 120) -> 19:28:00; (19:29:30, 19:30:00, 120) -> 19:29:30 |
| DR11_ListReplacedMidSweep | three unseen deals of ours (long ENT L00, short ENT L00, EXT for an existing long layer), model on | sweep returns 3; all three replayed; long depth and short depth as derived; (this fails if phase 2 reads the list live: the handler's select replaces it after the first deal) |
| DR12_HandlerGuards | (a) long layer with position P; an ENT deal for position P via `Grind_HandleSideDealFill`; (b) a layer already holding exit position X; an EXT deal with position X | (a) depth unchanged, no order placed; (b) close-by queue unchanged, `g_grind_pending_exit_count` unchanged |
| DR13_EventMissedDetector | ENT_S swept at now_ms 1000 | `Grind_ReplayCheckMissed(60999)`: no `DEAL_EVENT_MISSED`; (61000): exactly one, WARN; (70000): still one. Second deal swept at 1000, its event at 2000: no `DEAL_EVENT_MISSED` for it at 70000 |
| DR14_ConnectionEdge | seam connected true at init | step(false, 5000) false; step(false, 6000) false; step(true, 9500) true and one `CONNECTION_RESTORED` with `"down_ms":4500`; step(true, 10000) false, still one marker |
| DR15_NotReady | `Grind_ReplayReset()` only (no init); ENT_S in history | sweep returns 0; nothing replayed (guard); `Grind_ReplayCheckInvariants` with scripted [false] returns false and makes no sweep (guard); after `Grind_ReplayInit` the sweep returns 1 |
| DR16_SeenOnlyAfterSelect | ENT_S; `g_grind_hist_test_select_fail_ticket` = its ticket | sweep returns 0; not seen, depth 0; clear the fail ticket; sweep returns 1; depth 1 |
| DR17_Prune | init; mark seen (not replayed) 19:27:19; replay ENT_S at now_ms 1000 (no event); now 19:37:00, last sweep 19:35:00 (from 19:33:00) | after a sweep: the plain seen entry is gone; the waiting replayed entry is kept (`Grind_ReplayWasReplayed` still true); seen count as derived |
| EQH1_FoundWhenNotNewest | `g_grind_deal_test_active` FALSE, `g_grind_hist_test_active` TRUE, `g_grind_order_test_active` TRUE; long L00 position 5001, exit order 6101 (NOT in the order seam, so cancel and select fail); position seam has 7101 (`Grind_PositionTestAdd`); history: deal 9801 (order 6101, `GRIND|OPT|L|L00|EXT`, IN, position 7101, now - 60 s) and a NEWER deal 9802 (order 6999, now - 30 s) | `Grind_ExitQHoldCancelLayer` returns true; exit_position_ticket 7101; exit_order_ticket 0; long close-by queue (5001, 7101). (At commit 1 the old code takes its live branch, finds nothing on the desktop terminal and zeroes: FAIL as predicted. A re-added select inside the loop also fails it.) |
| EQH2_MissZeroesThenLateExtAttaches | as EQH1 but no deal for order 6101; `Grind_CarryShiftSet(5001, 0.00010)` | returns true; exit_order_ticket 0 (guard); `Grind_CarryShiftGet(5001)` == 0.0 (guard); then DEAL_ADD of deal 9803 (order 6101, L L00 EXT, position 7101) via `Grind_OnTradeTransactionEngine`: exit_position 7101 and close-by (5001, 7101) queued (guard). This whole test pins GF-1 and passes in both states BY DESIGN |

Regression guards that must stay green (existing): T45, T46, T46b,
T46c, T57b, GV7, GV8, FL1, STALE-2, STALE-5, F2-6, CR2, CR3 and every
other test that calls `Grind_HandleSideDealFill`,
`Grind_OnTradeTransactionEngine` or `Grind_ExitQHoldCancelLayer`
(`git grep` them and list them in the report).

## 6. EXPECTED RESULTS (the operator checks these)

- Commit 1: 2220 old assertions PASS; every new assertion WITHOUT
  "(guard)" FAILS; every "(guard)" PASSES; no crash, no array-out-of-range.
  Report the exact counts: new total N, predicted fails F, guards G
  (F + G = N). The operator's run must show `2220 + G` passed and `F`
  failed, and every FAIL row's name must lack "(guard)".
- Commit 2: `2220 + N` / `2220 + N`.
- If any new non-guard assertion PASSES at commit 1, it is not testing
  the change: say so in the report, do not "fix" it silently.

## 7. NEGATIVE SPACE -- DO NOT

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not
  run the suite (the operator compiles in the MetaEditor GUI and runs it
  on the desktop, never on a terminal with live EAs).
- Do not `git stash`, do not check out files from other commits, do not
  merge, no PR, no `git add .` or `git add -u` (add files by name).
- Do not add an input. Do not touch `InpConfigWarning` or any preset.
- Do not change the signatures of `Grind_HandleSideDealFill`,
  `Grind_OnTradeTransactionEngine`, `Grind_ExitQHoldCancelLayer` or
  `Grind_ExitQFindExitDealPosition` (S4).
- Do not change `Grind_ExitQHoldCancelLayer` at all (GF-1).
- Do not change I3, `grind_quarantine.mqh`, its thresholds, reconstruction
  (`grind_recon.mqh`), the carry pass, the lattice, ejection, the close-by
  queue, or the processed list's behaviour (D7).
- Do not call `Grind_DealSelect`/`HistoryDealSelect` inside any loop over
  a `HistorySelect` list, anywhere.
- Do not add forward declarations (MQL5 resolves later definitions).
- Do not replay deals from before init; do not send any broker request
  from the sweep itself (the handlers it calls do what they do today).
- Do not skip deals no side owns (e.g. the exit-position OUT_BY leg):
  they are replayed, archived and marked `"owned":false`.
- Do not edit existing tests or their expected values. If one breaks,
  STOP (s8).
- No non-ASCII characters in any file (no em-dashes, no smart quotes).
- Do not touch pipshed, docs or `NEW_CHAT_PROMPT.md`.

## 8. FAILURE MODES -- STOP AND REPORT

- An existing test would need changing to pass: STOP, name it, say why.
- `Grind_ProcessDeal` cannot be extracted without changing what the
  event path does for any deal: STOP.
- The A10 model breaks an existing test that uses `g_grind_deal_test_active`
  alone: STOP (the model must be off unless `g_grind_hist_test_active`).
- A fixture needs a seam that does not exist: STOP and describe it; do
  not invent one in production code.
- You find a caller that selects history and reads across a call that
  could now run the sweep: STOP (S9 says none).
- Anything in this spec contradicts the source: STOP, quote both.

## 8a. REPORT (in the chat, not a file)

Branch, both commit hashes, `git diff --stat origin/main..HEAD`, the
line count of every new or changed file (the operator re-counts), N, F,
G, the table of every new assertion with PF/guard, the regression list
from s5, and every place you deviated from this spec with the reason.

## 9. QUESTIONS FOR GEMINI (Cursor: ignore; the operator pastes rulings above)

Claude's check of your answers will be against source, as before.
- **SQ1.** The event path returns early for a deal the sweep already
  replayed (`DEAL_EVENT_AFTER_REPLAY`, no archive row, no handler).
  Sound? The handler's processed list would also stop a second effect
  for owned deals; the early return also stops the second archive row
  and keeps the rule "each deal is handled once".
- **SQ2.** D5 will also replay a deal whose event is merely still in the
  queue (the C40 transient: a tick sees the naked position before the
  DEAL_ADD event runs). The sweep then handles it first; the event later
  hits SQ1. This should REDUCE `QUARANTINE_ENTER` noise (C74), at the
  cost of `DEAL_REPLAYED` markers that are not missed events. Accept?
- **SQ3.** `DEAL_EVENT_MISSED` (WARN, 60 s after a replay with no event)
  is not in the ADR: it separates a genuinely missed event (C76) from
  SQ2's early replays, so the fleet reports C76 itself. Accept, and is
  60 s right?
- **SQ4.** The two guards in `Grind_HandleSideDealFill` (s3.5) change the
  event path too: a second ENT for a position already a layer no longer
  appends a second layer. That can only matter on a double delivery,
  which today can only follow a recon-then-event race at init. Accept?
- **SQ5.** Seed at init (s3.3): deals in [init - 120 s, init + 1 h] are
  marked seen, not handled. Residual, as today: a deal that fills between
  `Grind_ReconstructState` and the seed AND whose event is also lost is
  never handled (a window of milliseconds at init). Accept, or seed
  BEFORE reconstruction (then the guards absorb a double delivery)?
- **SQ6.** `Grind_ExitQFindExitDealPosition`'s `to` changes from
  `TimeCurrent()` (last quote time) to `now + 1 h`. Any objection?
- **SQ7.** The test model of A10 (s3.1): `Grind_DealSelect` replaces the
  list with one deal; reads by ticket of a deal not in the list return 0.
  Faithful enough to the live terminal (P1: 26 -> 1)?

Line count: 499
