This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-164: MISSED-DEAL REPLAY (+ C77)

You are auditing a feature branch BEFORE it merges to `main`. It is
tested on GBPUSD and EURUSD: tests against stubs (`04e665c`) 2259/2350,
failing exactly the 91 predicted; tests fixed (`3a2d800`); the
implementation (`7ff1c97`) 2350/2350. Find what tests cannot see. The
attached files carry NO line numbers: cite `file`, `function` and QUOTE
the line (one line, or part of one). A claim without a quote is
discarded. The attached ADR (`ADR-164-missed-deal-replay.md`) gives the
incident and the rulings.

**The system:** an MQL5 passive limit-order FX market maker (no stops,
no market orders, hedging account, 0.01 lots, cap 8 layers per side),
eleven instances per terminal, one symbol and magic each. Every change
to the engine's book arrived through `OnTradeTransaction`
(`Grind_OnTradeTransactionEngine` -> `Grind_HandleSideDealFill`, once
per side). An ENT deal appends a layer and places its exit; an EXT deal
(the exit filling, entry IN) queues a close-by of the two positions; the
two OUT_BY deals of that close-by remove the layer and report the scalp.
The exit queue (ADR-151, K=1, H=0) keeps only rank 0 and the highest
rank resting. Invariant I3 (every required layer has exit coverage)
runs on every tick from the broker book; a failure quarantines, and
halts after 3 s and 3 checks.

**The incident (28 Sep, ADR s1):** the terminal lost the trade server
for ~5 s. Two fills in the gap reached the terminal only through the
resync: no `OnTradeTransaction` at all, but both deals present in the
terminal's local history afterwards (probe P1). A missed ENT halted on
I3; a missed EXT would stall a side silently. Also verified (ADR A10):
a successful `HistoryDealSelect` REPLACES the `HistorySelect` list with
that one deal (26 -> 1 on the live terminal).

**This branch:**
- `grind_replay.mqh` (new): a SEEN set; `Grind_ReplayInit` (called in
  `OnInit` BEFORE `Grind_ReconstructState`) resets state and seeds SEEN
  with our deals in [init - 120 s, init + 1 h]; `Grind_ReplaySweep`
  (every `OnTimer`, 1 s, first statement; and from the tick path when
  the invariant fails, at most once a second) selects history from
  max(init, last sweep - 120 s) to now + 1 h, COPIES the unseen tickets
  of this symbol and magic (reads by ticket, no select), sorts them by
  (time_msc, ticket), then for each: `Grind_DealSelect` (skip if it
  fails, not marked), `Grind_ProcessDeal`, mark seen and replayed,
  marker `DEAL_REPLAYED`. `Grind_ReplayCheckInvariants` replaces the
  tick's `Grind_CheckBookInvariants` call: on failure it sweeps and, if
  anything was replayed, re-checks on the same tick. Also
  `CONNECTION_RESTORED` (edge of `TERMINAL_CONNECTED`), and
  `DEAL_EVENT_MISSED` (a replayed deal whose event has not arrived 60 s
  later) and a prune of old SEEN entries.
- `grind_engine.mqh`: `Grind_ProcessDeal` = the old event body (archive
  the fill; return if halted; set the add globals; the two handler
  calls). The event path: return unless DEAL_ADD; if the sweep already
  replayed the deal, marker `DEAL_EVENT_AFTER_REPLAY` and return; mark
  it seen (only if it selects and is ours); `Grind_ProcessDeal`. Two
  guards in `Grind_HandleSideDealFill`: an ENT whose position is already
  a layer returns (after `Grind_MarkDealProcessed`); an EXT whose layer
  already holds that exit position returns. History seams
  (`Grind_Hist*`) and a test model of A10 active only when
  `g_grind_hist_test_active`.
- C77: `Grind_ExitQFindExitDealPosition` no longer calls
  `HistoryDealSelect` inside its loop; it reads by ticket, newest first,
  window now - 30 d to now + 1 h. Its caller
  `Grind_ExitQHoldCancelLayer` is unchanged.

**Ruled -- do not re-open:** replay through the handler, not a runtime
reconstruction (GQ1); SEEN separate from the processed list and marked
only after a successful select (GQ2); sweep before the quarantine step,
same-tick re-check (GQ4, SQ2); NO input, always on (GQ5, operator);
120 s margin and 1 s cadence (GQ6); the C77 miss branch keeps zeroing
the exit ticket and deleting the shift (GF-1); the event path returns
early for a deal already replayed (SQ1); `DEAL_EVENT_MISSED` at 60 s
(SQ3); the two handler guards (SQ4); seed BEFORE reconstruction (SQ5);
`to` = now + 1 h (SQ6); an ENT absorbed by the guard reports
`"owned":true` (SQ8). The `OnInit`/`OnTimer`/`OnTick` wiring has no
unit test (read, not tested). `DEAL_REPLAYED` markers from the timer on
healthy days (the timer running before a fill's queued event) are
EXPECTED; `DEAL_EVENT_MISSED` is the fault signal.

**Deployment:** Thursday 1 Oct on two IC demo fleets (11 instances each)
with the ADR-162 lattice switched on the same day; not on the FTMO fleet
yet.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. `Grind_ReplayInit` runs before `Grind_ReconstructState` in
  `OnInit`, and `Grind_ReplayOnTimer` is the first statement of `OnTimer`.
- G2. No `Grind_DealSelect` or `HistoryDealSelect` is called inside a
  loop over a `HistorySelect` list (seed, sweep phase 1,
  `Grind_ExitQFindExitDealPosition`).
- G3. `Grind_ProcessDeal` does exactly what the old DEAL_ADD event path
  did, in the same order.
- G4. With both test flags off, every `Grind_Hist*` and `Grind_Deal*`
  function calls the MQL5 history function directly.
- G5. `Grind_ExitQHoldCancelLayer` is unchanged.
- G6. The sweep sends no broker request itself; every request comes from
  the handlers it calls.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 A deal handled twice.** Any path where one deal has a second
  effect on the book, the archive (`fill_log`) or the scalp report:
  event then sweep, sweep then event, seed and reconstruction overlap,
  a timer sweep and a tick sweep in the same second, a parameter
  reinit (reason 5: program globals survive; `Grind_ReplayInit` resets),
  an OUT_BY whose layer is already gone.
- **T-2 A deal never handled.** Any path where a deal of ours in history
  is never handled: seen but not processed (the event path marks seen
  BEFORE `Grind_ProcessDeal`: can the select succeed there and the
  handler's select then fail?), a deal time older than the window's
  `from` (server time vs `TimeCurrent()` jumps, a deal stamped before a
  long disconnect, init while disconnected), a prune followed by the
  deal re-entering the window, a `HistorySelect` that keeps failing.
- **T-3 Timer and tick replays vs the event path.** The handler was only
  ever called from `OnTradeTransaction`; now also from `OnTimer` and
  mid-`OnTick`. Any state it reads that differs there:
  `g_grind_ent_sent_this_tick`, ADR-152 fill-time add placement, the
  entry gate and breaker, the API counters, `g_grind_quarantined`, the
  close-by queue processed at the start of `OnTick`. Does an early
  replay of a deal whose event is merely queued behave exactly as the
  event would have?
- **T-4 The guards.** `Grind_FindLayerByPosition` also matches
  `exit_position_ticket`. Can the ENT guard or the EXT guard swallow a
  legitimate first delivery? Does marking processed before the ENT
  guard returns affect anything that reads the processed list?
- **T-5 Tick path.** `Grind_CheckBookInvariants` may run twice per tick:
  side effects (reason, detail, `g_grind_last_invariant_ok`)? The 1 s
  throttle, a replay while quarantined, and the quarantine step's check
  count and release after a same-tick re-check.
- **T-6 C77.** Every read in `Grind_ExitQFindExitDealPosition` is by
  ticket after `HistorySelect`: valid live? Cost of a 30-day window on
  the paths that call it; newest-first order vs the old test order.
- **T-7 Cost and bursts.** One `HistorySelect` per second per instance
  (11 per terminal), the window after a long disconnect,
  the O(n^2) sort, the SEEN array's growth, and a resync that replays
  many deals in ONE sweep: how many order requests can one timer call
  send, and does anything that normally paces entries per tick not
  apply?
- **T-8 Telemetry.** False or missing `DEAL_EVENT_MISSED` (restart
  within 60 s, an event later than 60 s, a deal no side owns),
  `CONNECTION_RESTORED` when started disconnected, the volume of
  `DEAL_REPLAYED` rows on a busy healthy day.
- **T-9 Tests.** Which behaviour has no test that fails without it? Any
  assertion in `fxgrind_tests_adr164.mqh` that passes vacuously (inside
  an `if`, on leftover state, on a fixture that never reaches the code)?
  Is the A10 model faithful enough that a select inside a loop would
  fail a test?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G6), `T-1` ... `T-9`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` and deploy Thursday on the two
IC fleets), `TEST GAPS`. No preamble. If you assume a value (an MT5
behaviour, an order of events), say ASSUMED and why.

Line count: 157
