# Phase 1 Audit Request — Rollover Exit-Modify Retry & Missed-Day Catch-Up

## Role reminder
This is a Phase 1 Red Team submission per ARCHITECT.md. Mechanical and
mathematical audit only — no implementation code in the response. Two
independent gaps in the existing rollover mechanism, plus one trivial
fix, are proposed together since they touch the same function.

## Background — confirmed current behavior, not assumption
`V2_RunDailyRolloverReconciliation()` (identical across GBPUSD, EURUSD,
EURGBP via shared `fxmatrix_v2_carry.mqh`) reprices resting **exit**
limit orders only, once per calendar day, on the first tick where
`dt.hour == 0`. Confirmed via direct code trace:

- **Entries are correctly out of scope** — the file header states
  "resting exit limits only," and this is sound: L0 refreshes every M5
  bar regardless of rollover, so it can't go stale; carry only applies
  to positions actually held overnight, which by definition means
  exits, not entries. Not a gap. Not part of this audit.

- **Two real gaps, confirmed by code trace, not inferred:**

  **Gap 1 — no retry within the day.** The daily gate
  (`V2_RolloverTryConsumeDailyGate`) consumes the day exactly once, on
  the first `hour==0` tick observed. If `V2_ModifyExitLimitPrice`'s
  `TRADE_ACTION_MODIFY` fails (stops level, freeze distance, requote,
  any transient reject), the function returns false, the internal
  `exit_target` is correctly left unchanged (no internal/broker
  mismatch — that part is safe), but **no further attempt happens that
  day.** The stale broker price persists until the next successful
  midnight attempt or the position closes.

  **Gap 2 — no catch-up for a fully missed day.** If the EA is offline
  at the exact moment `hour==0` occurs (e.g. a VPS redeploy, terminal
  restart, or any outage spanning that tick), the gate's
  `last_rollover_day_of_year` never gets consumed for that day, and
  there is no mechanism to detect "more than one day has elapsed since
  the last successful rollover" and catch up. The next successful
  rollover only ever applies a single day's shift.

  **Trivial, separate, low-risk:** the modify-failure warning is
  currently gated behind `InpVerboseLog`. Proposing this print
  unconditionally regardless of that flag, since a failed reprice is
  an operational fact worth always knowing about, not a debug-only
  detail. Flagging this alongside the main design questions since it
  touches the same code, but it is not architecturally interesting on
  its own.

## Explicit unknowns — check these directly, do not assume
1. **Call-site and frequency.** `V2_RunDailyRolloverReconciliation()`'s
   actual call site (OnTick? OnNewBar? something else?) was not
   confirmed in the discovery that produced this proposal. Find it and
   state the real invocation frequency — this directly determines how
   finely a same-day retry could be scheduled (e.g. can it realistically
   retry every few minutes via OnTick, or only once per M5 bar via
   OnNewBar?).
2. **Swap rate stability.** Does `SYMBOL_SWAP_LONG`/`SYMBOL_SWAP_SHORT`
   (or however the swap rate is read) return the CURRENT rate at the
   time of the call, or could it differ from what the rate actually was
   on a day that was missed? If a catch-up mechanism applies "N missed
   days × current rate," and the actual historical rate changed during
   that gap (brokers do change swap rates), the catch-up shift would be
   wrong for some of those days. Confirm whether this is a real risk or
   a non-issue given how this specific broker/symbol's swap typically
   behaves.

## Proposed designs — critique both, don't assume either is correct

**Design A — bounded same-day retry.** On modify failure, retry at
a fixed interval (e.g. every N minutes) for the remainder of the
calendar day, up to some maximum attempt count, then give up silently
logged as "rollover failed for the day" rather than retrying forever.
Question: what interval and cap avoid both (a) hammering the broker
with retries during a genuine multi-hour stops-level/freeze condition,
and (b) giving up too early on a transient single-tick reject that
would have succeeded a minute later?

**Design B — missed-day catch-up.** On the next successful rollover
attempt, compute `days_elapsed = current_day_of_year -
last_rollover_day_of_year` (handling year rollover correctly). If
`days_elapsed > 1`, apply `shift × days_elapsed` instead of a single
day's shift, then set `last_rollover_day_of_year` to the current day.
Question: is multiplying by a flat `days_elapsed` sound given the
Swap Rate Stability unknown above, or does attempting to reconstruct
what happened on each individual missed day (if even possible) matter
enough to require a different approach — e.g. capping the catch-up
multiplier at some maximum to avoid a large, possibly-wrong one-time
jump if the gap is unusually large (a multi-day VPS outage, say)?

## What Red Team must NOT do
Do not write implementation code. Do not propose specific numeric
constants (retry interval, max attempts, catch-up cap) as a final
answer — reasoned bounds and the tradeoffs behind them are the goal,
not a number to copy-paste. Flag anything that should block this from
proceeding to a Staff Architect ruling and eventual Cursor
implementation.
