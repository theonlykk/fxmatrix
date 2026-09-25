This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM C52: CARRY PASS USES THE CURRENT EXIT TICKET

You are auditing a DEFECT FIX before it merges and deploys mid-cycle to two
live fleets. It is tested: the test commit `ad6ea31` failed exactly the 3
predicted assertions on GBPUSD and EURUSD (1879/1882); the fix `6831436`
passes 1882/1882 on both. Find what tests cannot see. The attached files
carry NO line numbers: cite `file`, `function` and QUOTE the line (one line,
or part of one). A claim without a quote is discarded. Line numbers below
are ours, for orientation.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders, hedging account, 0.01 lots). Eleven instances per terminal
share global variables (GVs). Each side holds filled layers, each with one
exit; the exit queue (ADR-151, K=1, H=0) keeps only rank 0 and the highest
rank resting, releasing (placing) and cancelling exits as ranks change in
tick and trade events. I6 checks each resting exit against its formula
(entry, exit pips, accrued carry, eject offset, carry shift; 2-point
tolerance); I6 is quarantinable, and a quarantine that does not clear in 3 s
and 3 checks halts the instance. Nothing re-prices a live exit except the
nightly carry pass and a commanded eject.

**The carry pass** (`grind_carry.mqh`) runs in the 23:50-00:00 broker
window from `OnTimer`, 2 work items per 60 s step. `Grind_CarryExitPassBegin`
(~934) captures every layer (position ticket, exit ticket, entry, side).
For each item `Grind_CarryExitShiftLayer` (~1038) commits the accrued swap
GV and, if the layer has an exit order, moves it by the accrual (ticket-0
branch ~1086: accrual only).

**The defect (C52):** the step passed the CAPTURED exit ticket. A layer
held at capture and released by the queue before its item ran got its
accrual committed while its new exit (placed at yesterday's accrual) never
moved: I6 fails by one night's swap and the instance halts. A layer whose
exit was cancelled mid-pass failed its modify and lost that night's
accrual. **The fix (`6831436`):** `Grind_CarryCurrentExitTicket` (~985)
finds the layer in the LIVE book by position ticket; the step (~1164,
lookup ~1190-1197, call ~1202) passes the CURRENT exit ticket, and skips a
layer that is closing (`exit_position_ticket != 0`) or no longer in the
book (`skipped++`, nothing committed).

**Ruled -- do not re-open (Gemini CG1-CG6):** the fix site is the step
(an EA is single-threaded, so no tick or trade event interleaves inside a
timer step); closing or missing layers are skipped; a demoted layer
commits its accrual via the ticket-0 branch; deploy after the 22:00Z FTMO
roll; the dead retry arrays stay; the repair runbook below.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. `Grind_CarryCurrentExitTicket` returns the book's current
  `exit_order_ticket` and `closing` for the layer whose `position_ticket`
  matches, on the side given; false if absent.
- G2. `Grind_CarryExitPassStep` calls it per item and passes
  `current_exit` where it passed `g_grind_carry_exit_work_exit[idx]`.
- G3. Absent or closing: `g_grind_carry_exit_skipped++`, `processed++`,
  `continue`; nothing else runs for that item.
- G4. `Grind_CarryExitShiftLayer`, `Grind_CarryExitPassBegin`,
  `Grind_CarryWorkBase` and the event formats are unchanged by `6831436`.
- G5. The base the pass shifts from (`Grind_CarryWorkBase`) reads the
  eject offset and virtual level GVs at step time, not at capture.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Lookup.** Can the lookup return the wrong layer (a position
  ticket on the other side, a duplicate, a layer being rebuilt by
  reconstruction or quarantine) or miss a layer whose exit rests (so it is
  skipped and left unshifted while its accrual is due)?
- **T-2 Remaining captured state.** List every value the pass still uses
  from capture (entry, side, layer index, the stored formula, the order of
  items). Can any change mid-pass and matter? Is the stored
  `g_grind_carry_exit_work_formula` used for anything but events?
- **T-3 Release after processing.** A layer processed with ticket 0
  (accrual committed) and released later in the pass: is the new exit
  placed at the formula WITH the new accrual (queue ->
  `Grind_ExitQFormulaTarget`), so I6 holds?
- **T-4 Idempotence and restarts.** A restart (compile, reattach) during
  the window resets the pass; the gate is not marked done, so the pass
  starts again. Is the accrual computed absolutely (ledger + pending) so a
  second pass commits the same value, not a double? What does a restart
  mid-pass do to exits already shifted?
- **T-5 Halted or quarantined instance.** The carry step runs in `OnTimer`
  regardless of halt. Does the fix change what a halted instance's pass
  does (modifies exits of a book that invariants say is wrong)? Was that
  already so before the fix?
- **T-6 Counts and events.** The skip adds to `skipped`, which the pass
  summary and pipshed report (carry clamps C26 use `clamped`, not
  `skipped`). Any consumer that now misreads a closing layer as a sign-guard
  skip?
- **T-7 Cost.** The helper copies a side struct (with a dynamic array of up
  to 8 layers) per item. Any MQL5 semantics (deep copy, aliasing) that
  could make the copy stale or wrong?
- **T-8 Repair runbook (CG5).** If the race fires before deploy: delete
  the mispriced EXT order by hand, reattach only that chart;
  reconstruction's startup shortfall tolerance (ADR-156) accepts the
  missing required exit and `Grind_RetryMissingExits` (`fxgrind.mq5` ~192)
  re-places it at its formula. Does any invariant, recon step or other GV
  (release marker, carry shift) make that fail or place it wrong?
- **T-9 Tests.** Which new behaviour has no test that fails without it
  (short side; a layer missing from the book; a release AFTER processing)?
  Does any assertion pass vacuously?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G5), `T-1` ... `T-9` (verdict,
evidence with quotes, smallest fix if any), `PREMISE VERDICT` (does the
live-book lookup close RACE 1 and RACE 2 completely), `TEST GAPS`. No
preamble. If you assume a value (an MT5 behaviour, an order of events),
say ASSUMED and why.

Line count: 110
