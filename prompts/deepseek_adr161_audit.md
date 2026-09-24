This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-161 (ENTRY SESSION WINDOW, CANCELS ORDERS)

You are auditing an IMPLEMENTATION before it merges. It is tested (suite
1830/1830 on GBPUSD and EURUSD; the stub commit `68eeb83` failed exactly
the 42 predicted assertions). Find what tests cannot see.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders). Eleven instances (one per magic; two pairs run a second
instance with slot `ALT`) on one account share terminal global variables.
Each side of an instance holds at most one resting L0 entry (the
straddle, when flat) or one resting add (when it has depth), plus one
exit per filled layer. Entries have role `ENT` in the order comment,
exits `EXT` (`grind_comment.mqh`).

**ADR-161** (branch `adr161-session`, head `238bb66`; the design is the
attached Cursor prompt, rulings in its Status line) adds a default-OFF
input `InpSessionEnable`. When ON: new entries only 07:00-16:55 Toronto
time, Monday-Friday (local); outside the window this instance's resting
entries (L0 AND adds) are cancelled; exits, the carry pass, CloseBy and
ejection keep running. It will run only on a second fleet (IC Markets
demo, Linux/Wine box, clock UTC). **Do not re-open the design** (16:55,
tick-only retries, flat L0 cancelled, constants, merge OFF: all ruled).
Attack the implementation.

## GIVENS -- verify each, cite the line

- G1. `Grind_TorontoUtcOffset` (`grind_pure.mqh:479`) returns -4 from the
  2nd Sunday of March 07:00Z up to (not including) the 1st Sunday of
  November 06:00Z, else -5, via `Grind_NthSundayMonthUtc` (`:456`).
- G2. `Grind_SessionOpenAt` (`grind_pure.mqh:491`) uses the LOCAL
  weekday (1..5) and local seconds of day in [25200, 60900).
- G3. `Grind_EntriesBlocked` (`grind_engine.mqh:859`) ORs
  `Grind_SessionBlocksEntries` (`:854`, enabled AND closed) with the API
  stop and the breaker; the session block does not depend on
  `InpBreakerEnable`.
- G4. Every pending ENT order is placed by `Grind_PlaceLimit` from
  `Grind_TryPlaceL0` (`:1355`) or `Grind_SendNextAddEnt` (`:1617`), and
  every path to those passes an `if(Grind_EntriesBlocked()) return` at
  `:1109`, `:1335`, `:1544`, `:1648` or `:1759`. The other two
  `Grind_PlaceLimit` calls (`:1410`, `:2425`) place EXT orders.
- G5. `Grind_SessionStep` (`grind_engine.mqh:1033-1089`) is called from
  `OnInit` (`fxgrind.mq5:253`, timer flag), `OnTimer` every second
  (`:279`) and `OnTick` (`:323`, tick flag) BEFORE the breaker and
  before the halted/quarantined returns. On the transition to closed it
  archives `SESSION_CLOSE` and calls `Grind_CancelOwnEntryOrders`
  (`:2439`) if own entries rest; while closed it retries only on ticks,
  at most every 10 s; after 300 s with entries still resting it archives
  `SESSION_CANCEL_STUCK` once. `Grind_OwnRestingEntryCount` (`:2513`)
  applies the same filters as the cancel.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Unwind stays open.** Confirm nothing in exits, the exit queue,
  carry, CloseBy (`grind_closeby.mqh:170`, `:233` also cancel entries),
  manual or automatic ejection consults `Grind_SessionBlocksEntries` or
  `Grind_EntriesBlocked`, and that the session code can never cancel or
  modify an EXT order.
- **T-2 Leakage outside the window.** Find ANY way an entry rests or is
  placed while closed: a placement between 16:55:00 and the next step
  (fill-time placement in `OnTradeTransaction` before any step runs); a
  path that places ENT without `Grind_EntriesBlocked`; state re-armed by
  `Grind_OnTickEngine` or reconstruction. Bound the worst case in orders
  and seconds.
- **T-3 Cancel completeness.** An ENT order the filters miss is never
  cancelled and never counted, so no WARN either: a comment the broker
  truncates or rewrites, a different slot or symbol, a magic mismatch.
  Can a live instance own an ENT order that `GrindCommentParse` rejects?
- **T-4 Clock.** Wrong offset or window on any date: DST edges, a month
  starting on Sunday, year boundaries, `datetime` arithmetic with a
  negative offset, `TimeGMT()` under Wine or with a wrong terminal
  timezone. What would the operator see if the offset were wrong?
- **T-5 Restart and reinit.** A compile, reattach or chart change while
  closed: does the first step archive `SESSION_CLOSE` and cancel what
  rests? Do the globals reset on every reinit reason? Any duplicate or
  missing markers that would mislead a reader of the archive?
- **T-6 Retry and budget.** Bound the cancel calls per instance per day,
  including a failing cancel at the close and the weekend (no ticks).
  Can the retry loop or the WARN starve or flood anything (API counter
  entry stop, archive queue)?
- **T-7 Interactions.** With the breaker's own cancel latch, the ADR-160
  gate, a halted or quarantined instance, the API entry stop and the
  07:00 re-placement (the tick path re-places L0 and adds once the block
  clears): any ordering that double-cancels, leaves a stale
  `l0_pending_ticket` / `add_pending_ticket`, or trips an invariant?
- **T-8 Default OFF is inert.** With `InpSessionEnable = false`, show the
  new code changes nothing in behaviour or order traffic (it will be on
  `main` under the live cycle-3 fleet's future builds).

## RULES

- Cite `file:line` for every claim; otherwise mark it INFERRED.
- For each BREAKS / NEEDS-FIX give the SMALLEST fix. No redesign.
- Stay inside ADR-161's implementation and the code it touches.

## OUTPUT FORMAT (exact headings)

```
GIVENS CHECK     -- G1..G5: CONFIRMED / WRONG (with line)
T-1 .. T-8       -- verdict, evidence, smallest fix
PREMISE VERDICT  -- safe to merge? one paragraph
TEST GAPS        -- tests missing, with expected values
```

Line count: 106
