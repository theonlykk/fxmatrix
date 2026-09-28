This message has a line count at the bottom

# CURSOR SPEC -- ADR-164 MISSED-DEAL REPLAY + C77 (fxgrind EA)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat
in that workspace. Branch `adr164-deal-replay` from `origin/main` at the
commit that carries THIS revision (rev 2). First run
`git diff --stat 6a1e9ad HEAD -- ea/`: it must be EMPTY (EA code ==
`6a1e9ad` == `2ff62f4`, suite 2220/2220 on GBPUSD and EURUSD); if not,
STOP. Design: `docs/architecture/ADR-164-missed-deal-replay.md`
(ACCEPTED rev 3) -- read it in full first. Written by Claude from source
at `7a56f22`, 28 Sep ~22:30Z (rev 1); rev 2 ~22:40Z 28 Sep. The EA files
are identical at `f426383`; line numbers are that code.

**Rev 2 (after Gemini's SQ1-SQ7, s9a):** SQ5 amended by Gemini: the seed
runs BEFORE reconstruction (s3.3, s3.9), new test DR18. Claude's
corrections to the TESTS (not the design): every "(guard)" tag derived
against the commit-1 stubs (rev 1 tagged by intent); both test flags in
every DR test; DR9 reason, DR11 fixture, DR12 queue, EQH2 flag; fixtures
on the real probe values (A12, A13).

**Gemini has ruled (28 Sep, s9a): SQ1-SQ4, SQ6, SQ7 accepted; SQ5
amended as above. SQ8 is for Gemini on this revision (reply only if you
object). Everything else is for Cursor. Cursor: do not start until the
operator says so.**

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
| A12 | Probe P1's six `DEALPROBE` lines (box 2 Experts log `MQL5/Logs/20260928.log`, read 28 Sep ~22:23Z): EXT deal 1583980820 has order = position = 1968639465 (rev 1's 1968650001 was a placeholder); every IN deal has order = position; short L04 ENT deal 1583963156, position 1970132860, 1.32689, 19:25:35.360 server; long L01's close-by: OUT_BY 1583963945 (position 1969558575, 1.32696) and 1583963946 (position 1970144196, 1.32596), BOTH order 1970174608, comment `#1969558575 by #1970144196`; `time_msc` is server time (1790623639403 = 19:27:19.403) | box 2 Experts log | VERIFIED |
| A13 | Long L00's entry leg: position 1968628021 at 1.32686 (consistent: L01 entry 1.32596 + add 9). The EXT filled at 1.32785, one point inside entry + 10 pips (1.32786): the exit must have rested there (a carry shift, inside I6's 2 points) | `status_c` snapshot 16:55Z as read by the previous chat | INFERRED |
| S11 | `OnInit` sends no order before reconstruction: 141-252 validate inputs, claim the magic lock, configure telemetry and archive, reset quarantine (250), then `if(!Grind_ReconstructState())` (252) | `fxgrind.mq5` 141-252 | VERIFIED in source (SQ5 placement) |

## 1. WHAT TO BUILD (summary)

1. A deal-history SWEEP that finds deals of this EA (symbol and magic)
   that are in the terminal's local history but were never handled, and
   feeds them through the SAME code the `OnTradeTransaction` path uses.
   Runs every `OnTimer` call (1 s) and, throttled, on the tick path when
   the invariant fails, before the quarantine step (ADR D1, D5).
2. A SEEN set, separate from the processed list (D2); seeded at init,
   BEFORE reconstruction (SQ5), with the deals already in history (D3).
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
void     Grind_ReplayReset();                 // replay STATE to zero/false; test seams untouched
void     Grind_ReplayTestReset();             // Grind_ReplayReset() + every test seam off (tests only)
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

### 3.3 Init and seed (D3; SQ5: the seed runs BEFORE reconstruction)

`Grind_ReplayInit` runs in `OnInit` BEFORE `Grind_ReconstructState`
(s3.9; Gemini SQ5). Deals already in history when the seed runs are
marked seen, and the reconstruction that follows reads a book that
includes them. A deal that fills AFTER the seed (during reconstruction
or later) is NOT seen: its event or the sweep handles it, and if
reconstruction already built its layer or exit, the s3.5 guards absorb
it (DR18).

`Grind_ReplayInit(magic, now_ms)`: `Grind_ReplayReset()` (S6); init time
= `Grind_HistNow()`; last sweep time = init time; `g_grind_replay_connected`
= `Grind_ReplayTerminalConnected()`; then SEED:
`Grind_HistSelect(init - GRIND_REPLAY_MARGIN_S, init + GRIND_REPLAY_TO_AHEAD_S)`,
and for every ticket of `_Symbol` with a matching magic
(`Grind_MagicMatches`), `Grind_ReplayMarkSeen` (NOT replayed): those
deals are in history before reconstruction reads the book (SQ5).
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

With the seed before reconstruction (SQ5) these guards are on the
NORMAL init path, not only a rare race: reconstruction may already hold
the layer (or the exit position) of a deal that filled after the seed.
The ENT guard returns after `Grind_MarkDealProcessed`, so such a deal
reports `"owned":true` in its `DEAL_REPLAYED` marker (ours, already in
the book; SQ8).

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

- `OnInit` (SQ5): after `Grind_QuarantineReset();` (250) and BEFORE
  `if(!Grind_ReconstructState())` (252):
  `Grind_ReplayInit(InpMagic, GetTickCount64());`
  It runs whether reconstruction then succeeds or halts (a halted
  instance sweeps archive-only, D4). NOT after the reconstruction block
  (rev 1's placement).
- `OnTimer`: FIRST statement:
  `Grind_ReplayOnTimer(InpMagic, InpSlot, g_geo_exit_long, g_geo_add_long, InpDeadbandPips, InpMaxLayers, InpLots, g_geo_exit_short, g_geo_add_short, GetTickCount64());`
- `OnTick` 409: `const bool ok = Grind_CheckBookInvariants();` becomes
  `const bool ok = Grind_ReplayCheckInvariants(<same arguments as OnTimer>, GetTickCount64());`
  Line 410 (`Grind_QuarantineStep`) and everything else unchanged.

## 4. COMMITS

1. **Tests and stubs** (`ADR-164 tests first: ...`). Adds
   `fxgrind_tests_adr164.mqh`, its include and calls; `grind_replay.mqh`
   with every s3.2 function as a STUB (returns false / 0 / no-op; the
   struct and globals real; `Grind_ReplayReset`, `Grind_ReplayTestReset` and
   `Grind_HistTestReset` real because they only clear state); the s3.1 seam globals and the
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
assertion names start with the test id. Guard every array index a
failing assertion could make -1 (02_TRAPS, ADR-153 section, stub-check).
Each test resets what it uses at start AND end: `Grind_ReplayTestReset`
(rev 2: `Grind_ReplayInit` calls `Grind_ReplayReset`, which must NOT
clear a seam the test set before init, e.g. DR14's connected state),
`Grind_DealTestReset` (which resets the history seam after commit 2;
call `Grind_HistTestReset` explicitly too), `Grind_OrderTestReset`,
`Grind_CloseByTestReset`, `Grind_TestResetSideState`,
`Grind_ArchiveTestReset`, and whatever else the setup it copies uses.
Set EVERY field of any layer you create (use `Adr151_TestSetupLongLayer`
for long layers, passing `exit_pips` 10.0 EXPLICITLY -- its default is
3.0; for short layers set all six fields by hand). Expected values below
are derived by hand; write the derivation as a comment above each
assertion.

**Guards (rev 2).** An assertion that PASSES against the commit-1 stubs
is a guard and its name ends with ` (guard)`; every other new assertion
must FAIL at commit 1. Derive each one from the stubs, not from intent:
at commit 1 every s3.2 function returns false / 0 / no-op
(`Grind_ReplayIsSeen` false, `Grind_ReplayWasReplayed` false,
`Grind_ReplaySeenCount` 0, `Grind_ReplaySweep` 0, `Grind_ReplayInit` 0,
`Grind_ReplayWindowFrom` 0, `Grind_ReplayCheckInvariants` false without
calling the invariant seam, `Grind_ReplayConnectionStep` false,
`Grind_ReplayNoteEvent` false), and the event path, the handler and
`Grind_ExitQHoldCancelLayer` behave exactly as on `main`. The tags in the
table are derived that way; if your derivation differs for any
assertion, say so in the report (s8a), do not re-tag silently. Every
test keeps at least one untagged assertion, except EQH2 (by design).

**Test flags (rev 2).** Every DR test sets BOTH
`g_grind_deal_test_active = true` and `g_grind_hist_test_active = true`
(the ENT setup copied from GV7 already sets the first). Without the
first, `Grind_DealSelect` at commit 1 is the live `HistoryDealSelect`
and a handler call fails for the wrong reason. EQH1 and EQH2 are the
exceptions, as their rows say.

Common fixture unless a test says otherwise:
- magic 22260101 (the `Grind_TestAppendDeal` default), slot "OPT",
  `<P>` = `22260101UL, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0` (as
  GV7/GV8: long exit 10, long add 10, deadband 4, max 8, lots 0.01,
  short exit 7, short add 6). These are GV7's values, not Fleet C's
  GBPUSD geometry (exit 10, add 9 both sides); the tickets and prices
  below are the live ones, the geometry is the suite's.
- ENT fixtures copy `Test_GV7_FillShortExitAndAdd` (`fxgrind_tests_gv.mqh`
  254) setup exactly (order seam, `Adr152_TestPrepareIsolation`,
  `Grind_EngineConfigureAdr152(true, 0)`, `Adr152_TestSeedSlotSeams(200, 100, 0)`,
  `g_grind_ent_sent_this_tick = false`, `g_grind_deal_test_active = true`),
  with `Grind_MarketTestSeed(1.32781, 1.32791, 0)`, and its teardown
  (`Adr152_TestResetAll`, restore `g_grind_engine_add_pips` and
  `g_grind_recon_exit_pips`).
- Archive: `Grind_ArchiveTestReset(); Grind_ArchiveTestConfigureCommon();`
  count rows with `Grind_ArchiveQueueCount`/`Grind_ArchiveQueuePeek`;
  a fill row contains `"type":"fill_log"`, a marker contains
  `"type":"ea_event"` and its code.
- History model: both flags (above); init time I = `D'2026.09.28 19:27:00'`:
  set `g_grind_hist_test_now` = I, call `Grind_ReplayInit`, THEN set it to
  `D'2026.09.28 19:27:35'` unless stated (init takes its time from
  `Grind_HistNow()`, s3.3; an init at 19:27:35 would put every fixture
  deal before init). Set test seams (connected state, invariant script)
  before or after init: `Grind_ReplayReset` leaves them alone;
  `Grind_ReplayInit(22260101UL, 1000)` BEFORE appending the records that
  must count as post-init (records present at init are seeded).
- Deals from probe P1 (ADR A9, this spec A12/A13), times server
  (`Grind_TestAppendDeal`'s `deal_time`; the seam's `DEAL_TIME_MSC` is
  that times 1000):
  - ENT_S = deal 1583979787, order = position 1970173871,
    `GRIND|OPT|S|L00|ENT` (DR1 and most tests) or `L05` (DR8), IN,
    1.32781, 19:27:19.
  - EXT_L = deal 1583980820, order = position 1968639465,
    `GRIND|OPT|L|L00|EXT`, IN, 1.32785, 19:27:22.
  - LAYER_L00 (EXT_L's layer): long, `layer_index` 0, entry 1.32686,
    position 1968628021, exit order 1968639465, exit pips 10 (so
    `exit_target` 1.32786); the exit order upserted into the order seam
    as a SELL_LIMIT at 1.32786 with comment `GRIND|OPT|L|L00|EXT` (as FL1
    does, `fxgrind_tests_adr151.mqh` 1447-1455). Live it rested at
    1.32785 (A13); nothing in these tests reads the order's price.
  - OUT_BY deals (the shape in A12): both deals of a close-by carry the
    SAME order ticket (the close-by order) and the comment
    `#<entry position> by #<exit position>`, which does not parse as a
    GRIND comment (the sweep's marker then has role "", side "",
    layer -1).
- Every exit order a fixture layer holds is ALSO upserted into the order
  seam with its comment and price, so the handler sees a consistent book.
- DR9 and anything feeding `Grind_QuarantineStep` calls
  `Grind_QuarantineReset()` at start and end.
- "No order sent" = `g_grind_order_test_place_calls`,
  `g_grind_order_test_modify_calls` and `g_grind_order_test_remove_calls`
  all unchanged across the call (a record count would miss a
  cancel-then-place).

| Test | Setup | Assertions (expected by hand; "(g)" = the name ends with " (guard)") |
|---|---|---|
| DR1_ReplayMissedEnt | empty book; ENT_S (L00) in history after init; no event | sweep ("timer") returns 1; short depth 1, its position 1970173871, layer 0; exit target 1.32711 (1.32781 - 7 pips); exit ORDER placed at 1.32711; short add pending at 1.32841 (1.32781 + 6 pips, as GV7); exactly 1 `fill_log` row; exactly 1 `DEAL_REPLAYED` with `"role":"ENT"`, `"side":"S"`, `"layer":0`, `"path":"timer"`, `"owned":true`; `Grind_ReplayWasReplayed` true |
| DR2_ReplayMissedExt | LAYER_L00; EXT_L in history; no event | sweep returns 1; layer exit_order_ticket 0, exit_position_ticket 1968639465; long close-by queue size 1 with (1968628021, 1968639465); 1 `fill_log`; 1 `DEAL_REPLAYED` `"role":"EXT"` `"side":"L"` |
| DR3_ReplayMissedOutBy | LAYER_L00 with exit_order_ticket 0 and exit_position_ticket 1968639465 (EXT already known; its order removed from the seam); two OUT_BY deals at 19:27:25, both order 1970190001, comment `#1968628021 by #1968639465`: 1583981001 position 1968628021, price 1.32785, profit 0.99 ((1.32785 - 1.32686) x 0.01 lot x 100,000), commission -0.04; and 1583981002 position 1968639465, price 1.32686, profit 0.00, commission -0.04 | sweep returns 2; long depth 0; `g_grind_scalp_count` +1 exactly; `g_grind_scalp_event_queue_count` +1 exactly; 2 `DEAL_REPLAYED` in ticket order, the first `"owned":true`, the second `"owned":false`, both `"role":""`, `"layer":-1` |
| DR4_EventThenSweep | ENT_S (L00) delivered by `Grind_OnTradeTransactionEngine` (DEAL_ADD) | `Grind_ReplayIsSeen` true; then sweep returns 0 (g); depth 1 (g); `fill_log` rows 1 (g); no `DEAL_REPLAYED` (g) |
| DR4b_SweepThenEvent | ENT_S swept first, then its DEAL_ADD event | the sweep returns 1; exactly one `DEAL_EVENT_AFTER_REPLAY`; depth 1 (g); `fill_log` rows 1 (g) |
| DR5_InitSeedAndWindow | records BEFORE init: ours at 19:26:10 (seeded) and 19:24:00 (outside seed and window); init; then ours at 19:27:19 | init returns 1 (only 19:26:10 seeded); sweep returns 1; the 19:27:19 deal replayed; the 19:26:10 and 19:24:00 deals not replayed (g, both) |
| DR6_HaltedArchivesOnly | `g_grind_halted = true`; ENT_S in history | sweep returns 1; 1 `fill_log`; short depth 0 (g); no order sent (g); `DEAL_REPLAYED` with `"halted":true`, `"owned":false`; replayed true |
| DR7_OtherMagicOrSymbolIgnored | ENT_S; a copy with magic 22260102; a copy with symbol "XAUUSD" (edit the record after appending; new deal tickets) | sweep returns 1; ENT_S replayed; the two others not replayed and not seen (g) |
| DR8_Resync0928TimeOrder | 28 Sep reproduction: short L04 (position 1970132860, entry 1.32689, `layer_index` 4, exit order 1970140001 upserted as a BUY_LIMIT at 1.32619 = 1.32689 - 7 pips; that exit ticket is invented, P1 does not show it); LAYER_L00; records appended EXT_L FIRST, then ENT_S (L05) | sweep returns 2; short depth 2 with a layer of position 1970173871, index 5, exit order non-zero; LAYER_L00 exit_position 1968639465 and close-by (1968628021, 1968639465) queued; the two `DEAL_REPLAYED` markers in DEAL-TIME order: ENT_S's before EXT_L's (queue index) |
| DR9_TickSweepBeforeQuarantine | ENT_S in history; `g_grind_invariant_reason = "I3_SHORT_NAKED"` BEFORE the call (the tick's state; at commit 1 the stub sets nothing, and an empty reason would HALT, not quarantine, quarantine 69-70); invariant seam scripted [false "I3_SHORT_NAKED", true ""] | `Grind_ReplayCheckInvariants(<P>, 10000)` returns true; seam calls 2; then `Grind_QuarantineStep(ok, g_grind_invariant_reason, 10000)` returns `GRIND_INV_OK`; not quarantined; no `QUARANTINE_ENTER` marker; one `DEAL_REPLAYED` `"path":"tick"` |
| DR9b_TickThrottle | DR9's setup and call repeated in this test; then a second unseen deal (EXT_L with LAYER_L00); scripted [false "I3_SHORT_NAKED"] at now_ms 10500 | returns false (g); seam calls 1 for this call (a delta of `g_grind_replay_test_inv_calls`); EXT_L not replayed (g); at now_ms 11000 with scripted [false "I3_SHORT_NAKED", true ""]: EXT_L replayed and returns true |
| DR9c_NothingToReplayNoRecheck | init; nothing unseen; scripted [false "I3_SHORT_NAKED"] at 20000 | returns false (g); seam calls exactly 1; `g_grind_replay_last_tick_sweep_ms` == 20000 |
| DR10_WindowFrom | pure | (I, I, 120) -> I; (10:00:00, 19:30:00, 120) -> 19:28:00; (19:29:30, 19:30:00, 120) -> 19:29:30 |
| DR11_ListReplacedMidSweep | LAYER_L00; three unseen deals of ours after init: long ENT L01 (deal 1583990101, order = position 1970190101, `GRIND|OPT|L|L01|ENT`, IN, 1.32586, 19:27:20), ENT_S (L00, 19:27:19), EXT_L (19:27:22) | sweep returns 3; all three replayed; long depth 2 (L00, L01); short depth 1; LAYER_L00 exit_position 1968639465; close-by (1968628021, 1968639465) queued. (This fails if phase 2 reads the list live: the handler's select replaces it after the first deal) |
| DR12_HandlerGuards | both flags; (a) LAYER_L00; an ENT deal 1583990102 for ITS position (order = position 1968628021, `GRIND|OPT|L|L00|ENT`, 1.32686) via `Grind_HandleSideDealFill(g_grind_long, true, ...)`; (b) LAYER_L00 with exit_order_ticket 0 and exit_position_ticket 1968639465, long close-by queue EMPTY at start (`Grind_QueueCloseBy` drops a duplicate pair, closeby 105-108, so a pre-queued pair would pass either way); EXT_L via the handler | (a) long depth 1; no order sent (at commit 1 the handler appends a second layer with the same index and entry, both rank 0, so `Grind_ExitQManageSide` places an exit for it and `Grind_TryPlaceAddAtFill` places an add: two place calls; set `g_grind_engine_add_pips` = 10.0 for this direct handler call and restore it); (b) long close-by queue size 0; `g_grind_pending_exit_count` unchanged |
| DR13_EventMissedDetector | LAYER_L00; ENT_S and EXT_L swept at now_ms 1000; EXT_L's DEAL_ADD at now_ms 2000 (the event path) | `Grind_ReplayCheckMissed(60999)`: no `DEAL_EVENT_MISSED` (g); (61000): exactly one, WARN, for ENT_S; (70000): still exactly one; none for EXT_L at 70000 (g) |
| DR14_ConnectionEdge | seam connected true at init | step(false, 5000) false (g); step(false, 6000) false (g); step(true, 9500) true; exactly one `CONNECTION_RESTORED` with `"down_ms":4500`; step(true, 10000) false (g); still exactly one marker |
| DR15_NotReady | `Grind_ReplayReset()` only (no init); ENT_S in history | sweep returns 0 (g); nothing replayed (g); `Grind_ReplayCheckInvariants` with scripted [false "I3_SHORT_NAKED"] returns false (g) and the seam was called exactly once (no sweep, no re-check); then `Grind_ReplayInit` (which SEEDS ENT_S: it is in history at init), then LAYER_L00 and EXT_L appended after init: the sweep returns 1 (EXT_L) |
| DR16_SeenOnlyAfterSelect | ENT_S; `g_grind_hist_test_select_fail_ticket` = its ticket | sweep returns 0 (g); not seen (g); depth 0 (g); clear the fail ticket; sweep returns 1; depth 1 |
| DR17_Prune | init; `Grind_ReplayMarkSeen(1583980820, <19:27:22 in msc>)` (plain seen, not replayed); ENT_S replayed by a sweep at now_ms 1000 (no event); then `g_grind_hist_test_now` 19:37:00 and `g_grind_replay_last_sweep_time` 19:35:00 (from 19:33:00) | after a sweep (its return value is NOT asserted): the plain seen entry is gone (g); the waiting replayed entry is kept (`Grind_ReplayWasReplayed(1583979787)` true); `Grind_ReplaySeenCount()` == 1 |
| DR18_SeedBeforeReconGuardAbsorbs (NEW, SQ5) | init at I; THEN LAYER_L00 set up as reconstruction would have built it, and its ENT deal appended AFTER init (filled after the seed): deal 1583970001, order = position 1968628021, `GRIND|OPT|L|L00|ENT`, IN, 1.32686, 19:27:05 | sweep returns 1; long depth 1 (g); LAYER_L00 exit order still 1968639465 (g); no order sent (g); exactly 1 `fill_log`; exactly 1 `DEAL_REPLAYED` `"role":"ENT"`, `"side":"L"`, `"owned":true` |
| EQH1_FoundWhenNotNewest | `g_grind_deal_test_active` FALSE, `g_grind_hist_test_active` TRUE, `g_grind_order_test_active` TRUE; long L00 position 5001, exit order 6101 (NOT in the order seam, so cancel and select fail); position seam has 7101 (`Grind_PositionTestAdd`); history: deal 9801 (order 6101, `GRIND|OPT|L|L00|EXT`, IN, position 7101, now - 60 s) and a NEWER deal 9802 (order 6999, now - 30 s). Order and position differ ON PURPOSE here (live they are equal, A12): it proves the function returns `DEAL_POSITION_ID`, not the order | `Grind_ExitQHoldCancelLayer` returns true (g: both branches return true); exit_position_ticket 7101; exit_order_ticket 0 (g: the old miss branch zeroes it); long close-by queue (5001, 7101). (At commit 1 the old code takes its live branch, finds nothing on the desktop terminal and zeroes. A re-added select inside the loop also fails it) |
| EQH2_MissZeroesThenLateExtAttaches | as EQH1 but no deal for order 6101; `Grind_CarryShiftSet(5001, 0.00010)` | returns true (g); exit_order_ticket 0 (g); `Grind_CarryShiftGet(5001)` == 0.0 (g); THEN set `g_grind_deal_test_active = true` (rev 2: at commit 1, with only the hist flag, `Grind_DealSelect` is the live `HistoryDealSelect` and deal 9803 does not exist on the desktop), append deal 9803 (order 6101, `GRIND|OPT|L|L00|EXT`, IN, position 7101, now - 10 s) and deliver its DEAL_ADD via `Grind_OnTradeTransactionEngine`: exit_position 7101 (g) and close-by (5001, 7101) queued (g). This whole test pins GF-1 and passes in both states BY DESIGN |

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
- Do not place `Grind_ReplayInit` after reconstruction (SQ5: before it).
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
- `git diff --stat 6a1e9ad HEAD -- ea/` is not empty at the base: STOP.

## 8a. REPORT (in the chat, not a file)

Branch, both commit hashes, `git diff --stat origin/main..HEAD`, the
line count of every new or changed file (the operator re-counts), N, F,
G, the table of every new assertion with PF/guard, the regression list
from s5, and every place you deviated from this spec with the reason.

## 9. QUESTIONS FOR GEMINI (Cursor: ignore; rulings and Claude's check in s9a)

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
- **SQ8 (rev 2; reply only if you object).** (a) Under your SQ5 ruling
  an ENT that filled after the seed and that reconstruction already
  built is absorbed by the s3.5 guard AFTER `Grind_MarkDealProcessed`, so
  its `DEAL_REPLAYED` says `"owned":true` ("ours, already in the book";
  DR18). Acceptable, or should the marker carry a separate
  `"absorbed":true`? (b) s9a corrects OUR premise in SQ2: the C40
  transient is not a lagging event. Does your SQ2 ruling stand?

## 9a. GEMINI'S RULINGS (28 Sep ~22:25Z) AND CLAUDE'S CHECK

The operator sent this file alone, no covering message (the file was
byte-identical to `f426383`'s copy, SHA-256 prefix `d9a1b0dac1e7bb39`).
Again praise and no questions (BOOT s1), so each ruling was checked in
source.
- **SQ1 ACCEPTED.** Checked: the early return sits before
  `Grind_ProcessDeal`, so neither the archive row nor the handler runs a
  second time; the S1 reorder is behaviour-identical. Test DR4b.
- **SQ2 ACCEPTED; our premise corrected.** The SQ2 text called a lagging
  `DEAL_ADD` "the C40 transient". It is not: C40 (backlog) is F1's
  cancel-then-place gap when an exit moves (~200 ms uncovered). No deal
  is involved there, so the sweep replays nothing, D5 does no re-check,
  and that quarantine enters exactly as today. SQ2's gain applies only
  to a new position visible before its event runs (plausible, not
  measured). His "mathematically eliminates" also overstates: after a
  tick-path replay the exit ORDER must be visible on the same tick
  (S10); a quarantine may still start and release. The conclusion
  stands; C74 is NOT closed by this change.
- **SQ3 ACCEPTED (60 s).** A synced deal has no event at all (C76), so
  60 s separates the cases. Residual: an EA restart inside the 60 s
  resets replay state and drops the pending check (a missed report,
  never a false one). Accepted.
- **SQ4 ACCEPTED.** Checked: `Grind_FindLayerByPosition` also matches
  `exit_position_ticket` (engine 2099-2108). An ENT's position id is its
  own order ticket (A12: order = position on every IN deal), never an
  exit position, so the wider match cannot hide a real ENT. With SQ5 the
  guards are on the normal init path (s3.5, DR18).
- **SQ5 AMENDED: seed BEFORE reconstruction** (his ruling, adopted).
  His reasoning is right: seeded after, a deal that fills after
  reconstruction read the book is marked seen and, if its event is also
  lost, never handled. Checked in source (S11): `OnInit` sends no order
  before `Grind_ReconstructState`, so the seed at 251 changes nothing
  reconstruction reads. Remaining residual (inferred, not measured): a
  deal already in HISTORY at the seed but not yet in the positions list
  when reconstruction reads it would be seen and not built; its event
  still arrives (the event path ignores SEEN), so it is lost only if the
  event is lost too. A sync delivers history and the book together.
  s3.3, s3.5, s3.9, s7 and DR18 carry the change.
- **SQ6 ACCEPTED.**
- **SQ7 ACCEPTED.** His "would crash the live terminal" is wrong: live,
  a read of a deal outside the selected list fails and returns 0 (MQL5
  docs; not probed: P1 measured the list replacement, 26 -> 1, not the
  per-ticket read). The model's 0 is that behaviour and is the stricter
  choice.
- **Claude's corrections to the TESTS (repo mechanics, not design):**
  C1 the rev-1 "(guard)" tags were written by intent (confirmed by the
  previous chat); about twenty untagged assertions passed against the
  stubs (e.g. DR4 "sweep returns 0", DR14's false steps, EQH1 "returns
  true") and EQH2's DEAL_ADD step FAILED at commit 1 (only the hist flag
  set: the live `HistoryDealSelect`). Every tag is now derived against
  the stubs (s5 "Guards"). C2 both test flags in every DR test. C3 DR9
  sets the reason before the call (an empty reason halts, quarantine
  69-70). C4 DR12 (b) starts with an empty close-by queue (duplicate
  pairs are dropped). C5 DR11 had two long L00 layers. C6 fixtures on
  the real P1 values (A12, A13), including the OUT_BY shape. C7 the base
  commit is the one carrying this revision.
  C8 (from an independent re-derivation of every tag against the stubs
  and the design): init takes its time from `Grind_HistNow()`, so the
  fixture pins the model clock to I around init; `Grind_ReplayReset`
  no longer turns test seams off (init calls it; new
  `Grind_ReplayTestReset` for tests); DR15's post-init sweep needed a
  post-init deal (ENT_S is seeded); "no order sent" counts place,
  modify and remove calls; DR12 (a)'s commit-1 failure is two place
  calls (exit and add), derived.

Line count: 652
