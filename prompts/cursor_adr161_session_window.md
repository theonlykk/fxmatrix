This message has a line count at the bottom

# CURSOR -- ADR-161 EA: ENTRY SESSION WINDOW (FLEET B PHASE 1), TESTS FIRST -- REV 0

**Status:** Gemini ruled 2026-09-24: G1-G5 all ACCEPTED, no changes
(16:55 close, tick-only retries, flat L0 cancelled, constants, merge to
`main` default OFF). Cursor: build exactly as written. Every site below
was checked by Claude in source; operator judgement is flagged as such.

## AUDIT TRAIL

| item | where | status |
|---|---|---|
| Base | fxmatrix `main` = `232ecf9` + two docs-only commits (linux.pipshed.com; this prompt); EA code = tested `6c57830`, suite 1766/1766 | verified by Claude |
| Rule | backlog C37; `docs/architecture/fleet-b.md` s2 Phase 1: new entries only 07:00-17:00 Toronto, outside it resting entries cancelled, exits/carry/ejection run | pre-registered |
| Entry block | `grind_engine.mqh`: `Grind_BreakerBlocksEntries` 840, `Grind_EntriesBlocked` 847 (API stop OR breaker) | verified |
| Entry sites | the only ENT placements, each behind `if(Grind_EntriesBlocked()) return`: `Grind_ApplyEntryHorizon` ~1037, `Grind_TryPlaceL0` ~1263, `Grind_SendNextAddEnt` ~1472, fill-time place ~1576, `Grind_EnsureAddNext` ~1687 | verified |
| Resume | `Grind_OnTickEngine` ~2060-2103 calls `Grind_TryPlaceL0` every tick while a side is flat and `Grind_EnsureAddNext` every tick while it has depth; so after a block clears, L0 and the next add are re-placed on the first tick. No due flag is needed | verified |
| Cancel path | `Grind_CancelOwnEntryOrders` 2367-2438 (fwd decl 750): cancels every role-ENT order of this magic and slot (L0 straddle AND adds), clears `l0_pending_ticket` / `add_pending_ticket`; has an order-test path | verified |
| Breaker | `Grind_BreakerOnTick` 944-~1017; its cancel is once per FTMO day (`g_grind_breaker_cancel_done`); NOT reused here | verified |
| Clock | `grind_pure.mqh`: `Grind_LastSundayMonthUtc` ~391, `Grind_PragueUtcOffset` 415, `Grind_FtmoSecondsIntoDay` 443 (the technique to copy). VPS and Linux box clocks are UTC | verified / operator |
| EA | `fxgrind.mq5`: inputs 14-42 (`InpBreakerEnable` 28), `EventSetTimer(1)` 252, `OnTimer` 269 (`Grind_ArchiveFlush(false)` 273), `OnTick` 294 (`Grind_BreakerOnTick` 317) | verified |
| Invariants | I1-I8: none requires a resting L0 or add (I8 = corrupt pending add; the cancel path clears it) | verified |
| Harness defect | the ORDER-TEST path of `Grind_CancelOwnEntryOrders` (~2371) walks `g_grind_order_test_records` FORWARDS while a successful cancel removes the record and shifts the array, so the record after a removed one is skipped (the live path walks backwards and is correct). Test-only; not fixed here (backlog). SW6 orders its book so no two own ENT records are adjacent | found by Claude in source |
| Tests | `ea/fxgrind_tests.mq5`: `Test_GT6_SnapshotGatedSeconds` ends 5484, registered 8683; prefix `SW` unused; SB2 shows `Grind_TryPlaceL0` places in the harness by default | verified |

## OPERATOR JUDGEMENT (flagged, not measured)

- **J1.** A FLAT instance's L0 straddle is cancelled too, so it quotes
  nothing outside the window. The operator's words: "outside those hours
  we can only keep exit orders alive - no add orders"; the restatement
  "no L0 and no adds" drew no objection but was not explicitly confirmed.
- **J2.** Close at **16:55** Toronto, not 17:00 (Claude's proposal, see
  G1). Pre-registration says 17:00; if adopted, fleet-b.md gets an
  amendment.

## DESIGN

**D1 -- clock (pure, `grind_pure.mqh`, after `Grind_FtmoSecondsIntoDay`).**
`#define GRIND_SESSION_OPEN_SEC 25200` (07:00),
`#define GRIND_SESSION_CLOSE_SEC 60900` (16:55),
`#define GRIND_SESSION_CANCEL_RETRY_SEC 10`,
`#define GRIND_SESSION_STUCK_WARN_SEC 300`.
- `datetime Grind_NthSundayMonthUtc(const int year, const int month, const
  int n, const int hour_utc)`: day 1 of the month at `hour_utc`:00:00,
  advance one day at a time until `day_of_week == 0`, then add
  `(n - 1) * 7 * 86400`.
- `int Grind_TorontoUtcOffset(const datetime gmt)`: `-4` if `gmt >=
  Grind_NthSundayMonthUtc(y, 3, 2, 7) && gmt < Grind_NthSundayMonthUtc(y,
  11, 1, 6)` (y = year of gmt), else `-5`. (02:00 EST = 07:00Z; 02:00 EDT
  = 06:00Z.)
- `bool Grind_SessionOpenAt(const datetime gmt)`: `local = gmt +
  offset * 3600`; false unless the LOCAL `day_of_week` is 1..5; true when
  the local seconds of day are `>= GRIND_SESSION_OPEN_SEC` and `<
  GRIND_SESSION_CLOSE_SEC`.

**D2 -- state and block (`grind_engine.mqh`, directly above
`Grind_EntriesBlocked`).** Globals: `bool g_grind_session_enabled = false;
bool g_grind_session_closed = false; datetime g_grind_session_closed_since
= 0; datetime g_grind_session_last_cancel = 0; bool
g_grind_session_stuck_warned = false;`
`bool Grind_SessionBlocksEntries()` returns `g_grind_session_enabled &&
g_grind_session_closed`. `Grind_EntriesBlocked()` becomes
`Grind_ApiCounterEntryStopped() || Grind_BreakerBlocksEntries() ||
Grind_SessionBlocksEntries()`. Independent of `InpBreakerEnable`.

**D3 -- count (`grind_engine.mqh`, directly after
`Grind_CancelOwnEntryOrders`, fwd decl beside line 750).**
`int Grind_OwnRestingEntryCount(const ulong magic, const string slot)`:
the same filters as `Grind_CancelOwnEntryOrders` (test path over
`g_grind_order_test_records`; live path over `OrdersTotal()` with
`_Symbol`, magic, parsed comment, role `ENT`, slot), returning the count.

**D4 -- step (`grind_engine.mqh`, after `Grind_BreakerOnTick`).**
`void Grind_SessionStep(const ulong magic, const string slot, const bool
enabled, const datetime gmt, const bool from_tick)`, in this order:
1. `g_grind_session_enabled = enabled;` if `!enabled`: `closed = false`,
   return (no marker, no cancel).
2. `was = closed; closed = !Grind_SessionOpenAt(gmt); key =
   Grind_FtmoDayKey(gmt); off = Grind_TorontoUtcOffset(gmt);`
3. If now open: if `was`, `Grind_ArchiveMarker("INFO", "SESSION_OPEN",
   key, 0, {"utc_offset":<off>})`. Return.
4. `resting = Grind_OwnRestingEntryCount(magic, slot)`.
5. If `!was` (transition, including the first step after a start):
   `closed_since = gmt; stuck_warned = false;` marker INFO
   `SESSION_CLOSE` detail `{"utc_offset":<off>,"resting_ent":<resting>}`;
   if `resting > 0`: `Grind_CancelOwnEntryOrders(magic, slot);
   last_cancel = gmt;`. Return.
6. If `resting > 0 && from_tick && gmt - last_cancel >=
   GRIND_SESSION_CANCEL_RETRY_SEC`: cancel again, `last_cancel = gmt`.
7. If `!stuck_warned && gmt - closed_since >= GRIND_SESSION_STUCK_WARN_SEC
   && Grind_OwnRestingEntryCount(magic, slot) > 0`: marker WARN
   `SESSION_CANCEL_STUCK` detail `{"resting_ent":<n>,"closed_s":<secs>}`,
   `Print` the same, `stuck_warned = true`.

Retries run only from ticks: a tick proves the market is open, so a
cancel that failed at the close (rollover break, Friday close) is not
retried into a closed market all weekend. The timer's role is the
transition, so a quiet pair still cancels at 16:55:00.

**D5 -- calls (`fxgrind.mq5`).**
- `input bool InpSessionEnable = false;   // ADR-161 entry window 07:00-16:55 Toronto (Fleet B)` directly after `InpBreakerEnable`.
- `OnTimer`, directly after `Grind_ArchiveFlush(false);`:
  `Grind_SessionStep(InpMagic, InpSlot, InpSessionEnable, TimeGMT(), false);`
- `OnTick`, directly before `Grind_BreakerOnTick(...)`:
  `Grind_SessionStep(InpMagic, InpSlot, InpSessionEnable, TimeGMT(), true);`
- `OnInit`, directly before `EventSetTimer(1);`: the same call with
  `false`, then `Print("GRIND_SESSION enable=", InpSessionEnable,
  " toronto_utc_offset=", Grind_TorontoUtcOffset(TimeGMT()), " open_now=",
  Grind_SessionOpenAt(TimeGMT()));` (the operator reads this line on the
  box to confirm the clock).

## SETUP

1. `git fetch origin && git checkout main && git pull --ff-only`; report
   `git log --oneline -1`.
2. `git checkout -b adr161-session`; `git branch --show-current` before
   EVERY commit.

## TESTS (commit 1) -- `ea/fxgrind_tests.mq5`, defined after GT6 (ends 5484), registered directly after `Test_GT6_SnapshotGatedSeconds();` (8683)

Use `AssertTrue`/`AssertFalse`/`AssertContains` and EXACTLY these names.
Every SW test sets `g_grind_session_enabled = false`,
`g_grind_session_closed = false`, `g_grind_session_closed_since = 0`,
`g_grind_session_last_cancel = 0`, `g_grind_session_stuck_warned = false`
at start and end. SW4-SW9 also: `Grind_OrderTestReset();
Grind_TestResetSideState();` at start and end; `g_grind_order_test_active
= true`; `g_grind_cap_thresh_a = 0.0; g_grind_cap_thresh_b = 0.0;` (as
SB2); save `g_grind_breaker_enabled`, set it false, restore at end.
SW6-SW9 also: `Grind_ArchiveTestReset(); Grind_TelemetryTestReset();
Grind_ArchiveTestConfigureCommon();` at start, the first two at end.
Magic `22260101UL`, slot `"OPT"`. Times are MQL5 literals `D'...'`
(UTC). Expected values were derived independently with Python
`zoneinfo` (America/Toronto).

| test | assertions (expected) |
|---|---|
| `Test_SW1_NthSunday` | `SW1 mar 2026` (2026,3,2,7) == `D'2026.03.08 07:00:00'`; `SW1 nov 2026` (2026,11,1,6) == `D'2026.11.01 06:00:00'`; `SW1 mar 2027` (2027,3,2,7) == `D'2027.03.14 07:00:00'`; `SW1 nov 2027` (2027,11,1,6) == `D'2027.11.07 06:00:00'` |
| `Test_SW2_TorontoOffset` | `SW2 2026 spring before` 2026.03.08 06:59:59 -5; `SW2 2026 spring at` 07:00:00 -4; `SW2 2026 fall before` 2026.11.01 05:59:59 -4; `SW2 2026 fall at` 06:00:00 -5; `SW2 2027 spring before` 2027.03.14 06:59:59 -5; `SW2 2027 spring at` 07:00:00 -4; `SW2 2027 fall before` 2027.11.07 05:59:59 -4; `SW2 2027 fall at` 06:00:00 -5; `SW2 summer` 2026.09.24 12:00:00 -4; `SW2 winter` 2026.12.15 12:00:00 -5 |
| `Test_SW3_SessionOpenAt` | open (true): `SW3 thu 07:00 open` 2026.09.24 11:00:00; `SW3 thu 16:54:59 open` 20:54:59; `SW3 tue winter 07:00 open` 2026.12.15 12:00:00; `SW3 tue winter 16:54:59 open` 21:54:59; `SW3 mon 07:00 open` 2026.09.28 11:00:00; `SW3 fri 16:54:59 open` 2026.09.25 20:54:59; `SW3 mon after fall-back 07:00 open` 2026.11.02 12:00:00. Closed (false): `SW3 thu 06:59:59 closed` 2026.09.24 10:59:59; `SW3 thu 16:55 closed` 20:55:00; `SW3 tue winter 06:59:59 closed` 2026.12.15 11:59:59; `SW3 tue winter 16:55 closed` 21:55:00; `SW3 sat closed` 2026.09.26 15:00:00; `SW3 sun closed` 2026.09.27 15:00:00; `SW3 mon after fall-back 06:00 closed` 2026.11.02 11:00:00 |
| `Test_SW4_Blocks` | enabled+closed: `SW4 closed blocks` `Grind_SessionBlocksEntries()` true; `SW4 entries blocked` `Grind_EntriesBlocked()` true; enabled+open: `SW4 open no block` false; disabled+closed: `SW4 disabled no block` false |
| `Test_SW5_L0Blocked` | SB2's setup (`g_grind_short.l0_pending_ticket = 5001`, not in the book), enabled+closed: `SW5 closed r` `Grind_TryPlaceL0(...)` false; `SW5 closed no place` place_calls == 0. Reset, same setup, enabled+open: `SW5 open r` true; `SW5 open place` place_calls == 1 |
| `Test_SW6_CloseCancels` | book via `Grind_OrderTestUpsert`, IN THIS ORDER (see the harness row of the audit trail): 7001 own `GrindCommentBuild("OPT","L",0,"ENT")`; 7003 own `("OPT","L",1,"EXT")`; 7002 own `("OPT","S",2,"ENT")`; 7004 magic `22260301` `("OPT","L",0,"ENT")`. `g_grind_long.l0_pending_ticket = 7001; g_grind_short.add_pending_ticket = 7002;`. Step(enabled, 2026.09.24 12:00:00, false): `SW6 open no cancel` remove_calls == 0; `SW6 open count` `Grind_OwnRestingEntryCount(magic,"OPT")` == 2. Step(enabled, 2026.09.24 21:00:00, false): `SW6 closed flag` closed true; `SW6 closed removes` remove_calls == 2; `SW6 own ent gone` `g_grind_order_test_count` == 2; `SW6 l0 cleared` long l0 ticket == 0; `SW6 add cleared` short add ticket == 0; `SW6 exit kept` 7003 found; `SW6 foreign kept` 7004 found |
| `Test_SW7_Retry` | 7001 own ENT only; `g_grind_order_test_send_ok = false`; t0 = 2026.09.24 21:00:00. Step(t0, timer): `SW7 transition attempt` remove_calls == 1. Step(t0+20, timer): `SW7 timer no retry` == 1. Step(t0+25, tick): `SW7 tick retry` == 2. Step(t0+30, tick): `SW7 throttled` == 2. `send_ok = true`; Step(t0+35, tick): `SW7 retry succeeds` == 3; `SW7 none left` `g_grind_order_test_count` == 0. Step(t0+60, tick): `SW7 no call when none` == 3 |
| `Test_SW8_StuckWarn` | 7001 own ENT; `send_ok = false`; base = queue count; t0 as SW7. Step(t0, timer); Step(t0+299, timer): `SW8 no warn yet` count == base + 1. Step(t0+300, timer): `SW8 warn` == base + 2; `SW8 warn code` `Grind_ArchiveQueuePeek(base + 1)` contains `SESSION_CANCEL_STUCK`. Step(t0+400, timer): `SW8 warn once` == base + 2 |
| `Test_SW9_Transitions` | empty book; base = queue count. Step(enabled, 2026.09.24 12:00:00, timer): `SW9 initial open silent` == base. Step(21:00:00): `SW9 close count` == base + 1; `SW9 close code` peek(base) contains `SESSION_CLOSE`. Step(21:00:30): `SW9 no repeat` == base + 1. Step(2026.09.25 12:00:00): `SW9 open count` == base + 2; `SW9 open code` peek(base + 1) contains `SESSION_OPEN`. mid = count; Step(DISABLED, 2026.09.25 21:00:00): `SW9 disabled silent` == mid; `SW9 disabled clears flag` closed false |

**Commit 1** `ADR-161 EA tests and stubs (SW1-SW9)`. Stubs: the four
defines, the five globals, and every NEW function with a do-nothing body
(`return 0`, `return false`, empty). NOTHING existing changes:
`Grind_EntriesBlocked`, `OnInit`, `OnTimer`, `OnTick` and the inputs are
untouched; `Grind_SessionStep` is not called anywhere but the tests.

**Commit 2** `ADR-161 EA: entry session window 07:00-16:55 Toronto, default OFF`.

**Expected (the operator compiles and runs; do not):** 64 new
assertions. Stub `SUMMARY: 1783/1830`, failing exactly these 47:
`SW1 mar 2026`, `SW1 nov 2026`, `SW1 mar 2027`, `SW1 nov 2027`;
all ten SW2 assertions; `SW3 thu 07:00 open`, `SW3 thu 16:54:59 open`,
`SW3 tue winter 07:00 open`, `SW3 tue winter 16:54:59 open`, `SW3 mon
07:00 open`, `SW3 fri 16:54:59 open`, `SW3 mon after fall-back 07:00
open`; `SW4 closed blocks`, `SW4 entries blocked`; `SW5 closed r`, `SW5
closed no place`; `SW6 open count`, `SW6 closed flag`, `SW6 closed
removes`, `SW6 own ent gone`, `SW6 l0 cleared`, `SW6 add cleared`; all
seven SW7 assertions; all four SW8 assertions; `SW9 close count`, `SW9
close code`, `SW9 no repeat`, `SW9 open count`, `SW9 open code`.
The other 17 pass against the stub BY DESIGN (controls: the seven SW3
closed cases, `SW4 open no block`, `SW4 disabled no block`, `SW5 open r`,
`SW5 open place`, `SW6 open no cancel`, `SW6 exit kept`, `SW6 foreign
kept`, `SW9 initial open silent`, `SW9 disabled silent`, `SW9 disabled
clears flag`). Real: `SUMMARY: 1830/1830`. List any other assertion that
passes against the stub.

## NEGATIVE SPACE

- No change to the breaker (80% trip, latch, `g_grind_breaker_cancel_done`,
  D9 adoption), the pre-midnight halt, the ADR-160 gate, any entry site
  body, the exit queue, carry, ejection, CloseBy or any invariant.
- Do not reuse the breaker's cancel latch or its globals. Exits (EXT) are
  never cancelled by this code.
- One new input only. No heartbeat, snapshot, telemetry-contract, config
  dump or `Grind_ArchiveConfigFields` change. No preset (cycle 3 or
  `presets_b`), pipshed, runbook, handoff or docs change.
- Do NOT deploy, CLI compile, launch MetaTrader or run the suite. No
  `git stash`, no checking out files from other commits, no `git add .`
  or `-u`, no merge, PR or amend. ASCII only.
- Never change an existing assertion or expected value.
- Do not change the order-test loop of `Grind_CancelOwnEntryOrders`
  (the harness defect in the audit trail); report it, do not fix it.

## FAILURE MODES -- STOP AND REPORT

- Any audit-trail site is not where stated, or a sixth ENT placement
  site exists that does not pass through `Grind_EntriesBlocked`.
- `Grind_ArchiveMarker`, `Grind_FtmoDayKey` or `Grind_ArchiveQueuePeek`
  is not visible where needed.
- An expected value in the table disagrees with your reading of the
  rule: report it; do not change it.

## FOR GEMINI (rule on each; say what you checked)

- **G1 (J2).** Close at 16:55 rather than 17:00 Toronto. 17:00 Toronto is
  the FX rollover; many MT5 brokers pause trading around it and close on
  Friday a few minutes before it (IC Markets' session table is NOT yet
  checked). A cancel sent at 17:00:00 may be rejected as market closed;
  on a Friday the entries would then rest over the weekend and can fill
  on the Sunday gap, which breaks Phase 1's rule. Accept 16:55, or keep
  17:00 and rely on D4's retries (which cannot help on Friday)?
- **G2.** C37 said "cancel once per closure". D4 instead cancels at the
  transition, retries only on ticks every 10 s while own entries remain,
  and warns once after 5 min. Accept?
- **G3 (J1).** A flat instance quotes nothing outside the window; at
  07:00 the tick path re-places L0 at the current mid (audit trail:
  Resume). Any failure mode we have missed in cancelling a flat
  instance's straddle or a deep side's add every evening?
- **G4.** Local Mon-Fri only; no holiday calendar; windows fixed by
  constants with one default-OFF input (as ADR-158/160 used constants).
  Accept?
- **G5.** Placement on `main` (operator decision pending): merged with
  the input OFF, a later cycle-3 VPS build would carry this code inert
  (the doctrine in BOOT s4); the alternative is a branch deployed only on
  the Linux box. Any technical reason to prefer the branch?

## FINAL REPORT (fixed format)

```
BRANCH: <git branch --show-current>
BASE:   <sha>
COMMIT1: <sha from git log>  files: <list>
COMMIT2: <sha from git log>  files: <list>
PUSHED: <git ls-remote origin adr161-session>
DIFF:   <git diff --stat origin/main..adr161-session>
STUB-PASSING NEW ASSERTIONS: <list, expected: the 17 controls>
DEVIATIONS: <none, or each one with reason>
```

Line count: 237
