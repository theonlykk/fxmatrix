This message has a line count at the bottom

# CURSOR PROMPT -- C52: CARRY PASS USES THE CURRENT EXIT TICKET (DEFECT FIX)

Repo `D:\fxmatrix`, from `main` at `adf12b2` or a docs-only descendant
(EA code == tested `9466b22`). Branch `c52-carry-race`. Record: backlog
C52 (`handoffs/Handover/08_BACKLOG.md`), HANDOFF_2026-09-24 s11. Gemini
rules on this prompt BEFORE you start; his rulings are pasted at the
bottom. Where a ruling changes a default below, follow the ruling. If a
ruling is ambiguous, STOP and report.

This is a LIVE defect in cycle 3 (FTMO VPS) and Fleet B (Linux box), both
running carry ON. It lands mid-cycle as a defect fix. Keep it minimal.

## AUDIT TRAIL (read in source at main `adf12b2`, EA == `9466b22`, by Claude)

| # | finding | where | status |
|---|---|---|---|
| A1 | The nightly pass captures each layer's exit ticket when it begins: every layer with a position is appended, held layers with exit ticket 0 | carry 934-971 (append 950-966) | verified |
| A2 | The pass is timer-driven: 2 items per step (`GRIND_CARRY_PASS_CHUNK 2`, carry 32), one step per telemetry interval (60 s) from `OnTimer` (`fxgrind.mq5` 292), in the 23:50-00:00 broker window (carry 280-285). A pass over n layers takes about n/2 minutes | carry 32, 280, 1126-1141, 1143-1192 | verified |
| A3 | Queue releases and cancels run in tick and trade events (`Grind_ExitQManageSide` engine 2410-2468; `Grind_ExitQHoldCancelLayer` 2377-2408), which can fall between two timer steps | engine | verified |
| A4 | The step passes the CAPTURED ticket `g_grind_carry_exit_work_exit[idx]` to `Grind_CarryExitShiftLayer` | carry 1170-1171 | verified |
| A5 | RACE 1 (halts an instance): a layer held at capture and released before its item runs. Its item carries ticket 0, so the ticket-0 branch commits the new accrual and returns (carry 1065-1069) without moving the new exit, which the queue placed at the formula with YESTERDAY's accrual. I6 then fails by one night's swap (tolerance 2 points, recon 379-392); I6 is quarantinable (recon 709, 722) but nothing re-prices a live exit, so the instance halts after 3 s and 3 checks (`grind_quarantine.mqh` 13-14). A restart re-runs reconstruction, which fails on the same exit | carry 1065, recon 379, quarantine 13 | verified (halt sequence inferred end to end) |
| A6 | RACE 2 (loses a night's carry): a layer with an exit at capture that the queue cancels (demotes) before its item runs. The modify on the vanished order fails (`Grind_ModifyPendingPrice` -> `Grind_SelectOurOrder` false), `failed` counts it, and the accrual is NOT committed (carry 1098-1103), so that exit later releases one night short | carry 1098 | verified |
| A7 | RACE 3 (harmless today): an exit filled mid-pass (CloseBy pending) -> the modify fails on the vanished order. After the fix this layer is skipped explicitly | carry 1098 | verified |
| A8 | Everything else the pass uses is read LIVE at step time: the base from `Grind_CarryWorkBase` (entry is fixed; VL and offset GVs read now, carry 973-981), accrued, shift, sign guard, clamp | carry 973, 1017-1124 | verified |
| A9 | `g_grind_carry_exit_retry_*` is declared, reset and tested for zero, but never filled: no retry path exists | carry 57-59, 1184 | verified |
| A10 | Existing pass tests build their work list from the book through `Grind_CarryExitPassBegin` (CX12-CX15 tests 8007-8200; F2-1 to F2-5 adr151 1857-2070), so a lookup in the book returns the captured ticket for them: unchanged | tests | verified |
| A11 | Not seen live: VPS Experts logs 24-25 Sep show 112 fault lines, all I3 transients (C40), none near the carry window | HANDOFF s11 | evidence |

## WHAT THE FIX IS

In `Grind_CarryExitPassStep`, for each work item, look the layer up in the
LIVE book by its position ticket (`g_grind_long` or `g_grind_short`, by
the item's side) and use its CURRENT `exit_order_ticket`:

- found, `exit_position_ticket == 0`: call `Grind_CarryExitShiftLayer` with
  the current ticket (0 = held: commit accrual only; non-zero: modify it,
  whether it was released mid-pass or rested all along);
- found with `exit_position_ticket != 0` (exit filled, closing), or not
  found (the layer left the book): skip; `g_grind_carry_exit_skipped++`;
  commit nothing.

Nothing else changes: not `Grind_CarryExitShiftLayer`, not
`Grind_CarryExitPassBegin`, not the work arrays, not the summary format.

## COMMIT 1 -- TESTS AGAINST CURRENT CODE

New file `ea/fxgrind_tests_c52.mqh`, included from `fxgrind_tests.mq5`
directly after `#include "fxgrind_tests_adr162.mqh"` (line 21); register
the three tests in `OnStart` directly after `Test_VL16_ParseL100();` (line
9290). NO forward declarations in the new file (functions defined later in
the program resolve without them; a mistyped one broke the last compile).
No stub: the tests call existing functions only, so this commit compiles
against the unfixed code and the predicted rows FAIL.

Common setup (copy F2-5, adr151 2027-2070): `Grind_CarryTestReset();
Grind_ArchiveTestReset(); Grind_OrderTestReset(); Grind_TestResetSideState();`
`F2_TestClearPositionCarry(pos); F2_TestSeedCarryWindow(magic);`
`g_grind_order_test_active = true;` `Grind_CarryTestSetPosition(pos, -0.10,
0.01, D'2026.09.01 12:00'); Grind_PositionTestAdd(pos);` one long layer via
`Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.25000, pos, <ticket>)`
(exit 3 pips: formula 1.25030); `g_grind_carry_eligible_magic = magic;`
then `Grind_CarryExitPassBegin(_Symbol, magic, 3.0);` (the capture), then
the mid-pass event, then ONE `Grind_CarryExitPassStep(_Symbol, magic, 3.0,
g_grind_carry_test_server_time);`. End each test with F2-5's resets plus
`Grind_CarryGateReset(magic)`.

The exact accrued value depends on the symbol's live tick value, so the
tests assert the INVARIANT the race breaks (I6 via
`Grind_ReconExitMatchesEntry`) and state preconditions, rather than a
price. (F2-1 and F2-5 assert accruals the same way.)

| test | setup (after the capture) | assertion (name: expected) | now |
|---|---|---|---|
| CR1_ReleasedMidPass (magic 99993201, pos 99301, exit 99311) | layer captured with NO exit (ticket 0); then the queue's release is simulated: `g_grind_long.layers[0].exit_order_ticket = 99311` and `Grind_OrderTestUpsert(99311, magic, GrindCommentBuild("OPT","L",0,"EXT"), 1.25030, SELL_LIMIT)`; then one step | "CR1 accrued": `MathAbs(Grind_CarryAccruedGet(pos)) > 1e-12` | PASS |
| | | "CR1 accrued beyond I6 tolerance": `MathAbs(Grind_CarryAccruedGet(pos)) > 2.0 * 0.00001` | PASS |
| | | "CR1 exit moved": the order's price differs from 1.25030 by more than 1e-9 | FAIL |
| | | "CR1 I6 holds": `Grind_ReconExitMatchesEntry(1.25000, <order price>, 3.0, 0.00001, true, Grind_CarryShiftGet(pos), false, pos)` | FAIL |
| CR2_DemotedMidPass (magic 99993202, pos 99302, exit 99312) | layer captured WITH exit 99312 at 1.25030 (upserted before the capture); then the queue's demotion: `Grind_ExitQHoldCancelLayer(g_grind_long.layers[0], true, magic)`; then one step | "CR2 cancelled": `g_grind_long.layers[0].exit_order_ticket == 0` AND `!Grind_OrderTestFind(99312, rec)`, asserted BEFORE the step | PASS |
| | | "CR2 accrual committed": `MathAbs(Grind_CarryAccruedGet(pos)) > 1e-12` | FAIL |
| CR3_ClosingMidPass (magic 99993203, pos 99303, exit 99313) | layer captured WITH exit 99313 at 1.25030; then the fill: `Grind_OrderTestRemove(99313)`, `exit_order_ticket = 0`, `exit_position_ticket = 99323`; then one step | "CR3 closing not shifted": `MathAbs(Grind_CarryAccruedGet(pos)) <= 1e-12` | PASS |

Predicted (the operator runs both on GBPUSD and EURUSD; you do NOT run
them): baseline 1875. Commit 1 **1879/1882**, failing exactly "CR1 exit
moved", "CR1 I6 holds", "CR2 accrual committed". Commit 2 **1882/1882**.
The four PASS rows pass in both states BY DESIGN (preconditions; CR3
locks the new skip branch against committing); list them as such.

## COMMIT 2 -- THE FIX

1. `ea/grind_carry.mqh`, directly after `Grind_CarryWorkBase` (973-981):

       // C52: the pass must act on the layer's CURRENT exit, not the one
       // captured at PassBegin (the queue releases and cancels mid-pass).
       bool Grind_CarryCurrentExitTicket(const ulong position_ticket,
                                         const bool is_long,
                                         ulong &exit_ticket_out,
                                         bool &closing_out)

   Scan `g_grind_long.layers` (is_long) or `g_grind_short.layers` for
   `position_ticket`; if found set `exit_ticket_out` =
   `exit_order_ticket`, `closing_out` = (`exit_position_ticket != 0`) and
   return true; else set both to 0/false and return false.
2. `Grind_CarryExitPassStep` (1143-1192), inside the loop after `idx` and
   the cursor increment (1165-1166): call it with
   `g_grind_carry_exit_work_pos[idx]` and `g_grind_carry_exit_work_long[idx]`;
   if it returns false or `closing_out` is true:
   `g_grind_carry_exit_skipped++; processed++; continue;`. Otherwise pass
   `exit_ticket_out` where the call now passes
   `g_grind_carry_exit_work_exit[idx]` (1171). The array itself stays.

## NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run
  the suite (the operator compiles in the MetaEditor GUI; suite figures are
  pending), do not `git stash`, do not check out files from other commits,
  do not merge, no PR, no `git add .` or `-u`.
- PUSH THE BRANCH: `git push -u origin c52-carry-race` after each commit.
- Do not change `Grind_CarryExitShiftLayer`, `Grind_CarryExitPassBegin`,
  `Grind_CarryWorkBase`, the work arrays, the prune, the summary or any
  event format. Do not add the retry path (A9). Do not touch the queue.
- Do not change any existing test, expected value or registration.
- Nothing outside `ea/`. No presets, no docs, no pipshed. Do not touch the
  `adr162-phase-b1` branch.

## FAILURE MODES -- STOP AND REPORT

- A line cited above does not hold the code described (drift): STOP.
- Any existing test would need a change to compile or pass: STOP.
- A helper named above is missing or has another signature
  (`F2_TestSeedCarryWindow`, `F2_TestClearPositionCarry`,
  `Adr151_TestSetupLongLayer`, `Grind_CarryTestSetPosition`,
  `Grind_PositionTestAdd`, `Grind_OrderTestRemove`,
  `Grind_ExitQHoldCancelLayer`): STOP.
- You find another place where the pass uses a value captured at
  `PassBegin` that can change mid-pass: do not change it; report it.

## REPORT

Both commit hashes (pushed); `git diff --stat main..c52-carry-race`; each
test by name with its assertion names; the PASS-in-both list.

## FOR GEMINI -- RULE BEFORE CURSOR STARTS

Premises: VERIFIED = read in source by Claude; INFERRED = reasoned.

- **CG1. The fix site.** Look up the live book by position ticket in the
  pass step (VERIFIED: the book is what the queue edits; single-threaded
  EA, so no tick event can interleave inside one timer step). The
  alternatives were to block queue releases during the pass (touches
  every exit path, mid-cycle) or re-snapshot the whole list per step.
  Accept?
- **CG2. Closing or missing layer: skip, commit nothing,** count as
  skipped. Its position is about to close via CloseBy and the close path
  deletes the accrual GV anyway. Accept?
- **CG3. A layer demoted mid-pass commits its accrual like any held
  layer** (ticket 0 branch), so it releases later at the right price
  (F2-2 semantics). Accept?
- **CG4. Deployment (the operator's call, not Cursor's).** Every compile
  restarts every instance on that terminal. Proposed: deploy to the VPS
  and the Linux box after that day's 22:00Z FTMO roll and well before the
  next carry window, tagging `vps-<sha7>` first; this is a defect fix
  under cycle 3's pre-registration (A4). Any objection?
- **CG5. If the race fires before deploy (operator runbook, INFERRED):**
  the instance halts with one exit mispriced by a night's swap. Delete
  that EXT order by hand in the terminal, then reattach only that chart:
  reconstruction treats the missing required exit as a startup shortfall
  (ADR-156) and `Grind_RetryMissingExits` (`fxgrind.mq5` 192) places it at
  its formula with the current accrual. Sound, or do you see a safer
  repair?
- **CG6. Scope.** RACE 2 (a night's carry lost) is fixed by the same
  lookup; the dead retry arrays (A9) stay out. Accept?

## GEMINI RULINGS (2026-09-25) -- ALL SIX ACCEPTED, NO DEFAULT CHANGES

Build exactly as written above. Condensed; reasons checked in source by
Claude.

- **CG1 ACCEPTED** (live-book lookup in the step): one EA is
  single-threaded, so a tick or trade event cannot interleave inside a
  timer step; freezing the queue mid-cycle was rejected.
- **CG2 ACCEPTED** (closing or missing layer: skip, commit nothing); the
  close path deletes the GVs when the CloseBy completes.
- **CG3 ACCEPTED** (demoted layer commits its accrual via the ticket-0
  branch; the later release reads it through the formula).
- **CG4 ACCEPTED**, one reason corrected: the daily API count is a
  terminal GV that resets with the BROKER day (T3c), not at the 22:00Z
  roll; a restart clears only in-memory counters (BOOT s3). The timing
  stands: after the 22:00Z roll leaves about 23 hours before the next
  23:50-broker carry window.
- **CG5 SOUND** (runbook: delete the mispriced EXT by hand, reattach only
  that chart; ADR-156 treats it as a startup shortfall and
  `Grind_RetryMissingExits` re-places it at its formula).
- **CG6 ACCEPTED** (the dead retry arrays stay out).

Line count: 197
