This message has a line count at the bottom

# REPLAY CALIBRATION ON EURUSD (B / C / D), SECOND PRE-REGISTRATION: THE BROKER'S TIMING

| | |
|---|---|
| Status | **DRAFT for Gemini (10 Oct ~02:10Z); NOTHING RULED.** No harness change and no run on any data before Gemini's rulings and the operator's go. The constants in s3 are fixed BEFORE any run under this plan; a constant changed after a run is a new pre-registration, recorded as such |
| Origin | Operator 10 Oct ~01:53Z: a new pre-registration after the first one failed (`replay-calibration-eurusd.md` s12, Gemini GRC2-1: s8's "fail in M1-M3" branch governs; the misses left are mostly timing, M3) |
| Rules it keeps | Everything in the first plan that this file does not change (s4 here lists it): the question (s1 there), the window and segments (s2), seeding at an init (s3), the data (s4), the engine (c) (s5), T0 / T0b (passed; not re-run), T1 and T2 and their marks (s6), the miss categories (s7), not modelled (s9). Our trade history is the gold standard; no time-series analysis or price signal: the ticks only drive our rules; the timing constants are measured from OUR sends and fills, never from a replay result |
| Supersedes | The first plan's fill rule in part ("an order placed on a tick can fill from the next tick", s6 there): replaced by s3's broker and EA timing. Its placement-latency sensitivities (250 ms, 1 s) are re-stated in s6 here |

## 0. AUDIT TRAIL

Source at `main` EA code `5bb5fdb`; harness `replay-harness` code `90fbce4`
(core `ea/fxgrind_replay_core.mqh`). Measurements:
`research/replay/measure_timing.py` (rules in its header; 13 tests, mutants
16 of 16) on the calibration window (each fleet's run rows, 1 Oct to 8 Oct
22:00Z), results `research/replay/results/timing_20261008/timing.md`. Inputs:
send_logs `sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl`, archives
`archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl` (sha256 B `4b584882a288681f`,
C `c51dd5b5fec41502`, D `3866d5ff6324266f`), ticks w2 (`db2ea94173a4d0c8`).

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | A send's archive row is stamped AFTER `OrderSend` returns; `duration_ms` is that blocking call's own time. So a send starts at `ea_time_ms - duration_ms` | `ea/grind_api_counter.mqh` 190-206 (`Grind_OrderSendCounted`); `ea/grind_archive.mqh` 126-132, 262-269 | VERIFIED |
| K2 | The EA's clock and the broker's differ by an offset that drifts: a fill's log time minus its broker deal time, p10 / p50 / p90, B -1.42 / -0.92 / -0.16 s (max +9.8 s), C -0.63 / -0.37 / -0.13 s, D -2.10 / -0.82 / -0.08 s. No measure here crosses the two clocks: each is a duration, or lies within one clock | `timing.md` M0 | MEASURED |
| K3 | Send durations (ms; median, p10-p90), B / C / D: PENDING 286, 287, 288 (281-295); MODIFY 288, 288, 286 (280-304); CLOSE_BY 294, 295, 293 (286-304); REMOVE 43, 44, 42 (36-53). Over 1 s: 6 of 3,746 sends (B 3, C 1, D 2); the longest 5.8 s | `timing.md` M1, M1b | MEASURED |
| K4 | The broker's deal time follows the first touching tick by **lam**: median 263, 261, 261 ms; p10 256 on all three; p90 281, 277, 286 | `timing.md` M2 (T0's rule) | MEASURED |
| K5 | After an ENT fill the EA's first send starts 0-1 ms after the fill is logged: it acts in the trade event (`OnTradeTransaction` -> `Grind_OnTradeTransactionEngine`), not on a tick | `timing.md` M3; `ea/fxgrind.mq5` 496-500 | MEASURED; VERIFIED (handler) |
| K6 | After an EXT fill the close-by is sent on the FIRST TICK AFTER the fill: (close-by start - fill log) - (sends ahead) - (first tick after F - F) has median 5, 5, 4 ms (p75 12, 8, 7). `OnTick` calls `Grind_ProcessCloseByQueues` first | `timing.md` M4; `ea/fxgrind.mq5` 438-440 | MEASURED; VERIFIED |
| K7 | The close-by completes when its send returns: the broker's first OUT_BY minus (F + start - fill log + duration) has median -7, -9, -6 ms | `timing.md` M5 | MEASURED |
| K8 | The sends after a close-by go out back to back: gap median 1, 1, 0 ms (p75 1-2) | `timing.md` M6 | MEASURED |
| K9 | The L0 that follows a close-by goes out on the first tick after the close-by ends: residual median 9, 61, 10 ms (n 20, 26, 20); p75 0.4-0.6 s (a later tick) | `timing.md` M7 | MEASURED (thin) |
| K10 | MT5 does not queue a new `OnTick` while one is queued or running; the next `OnTick` reads the newest price | MQL5 book, "Expert Advisors main event: OnTick" | DOCUMENTED, not tested here |
| K11 | The harness today (90fbce4): a touch fills on the touching tick (`Rpl_FillsOnTick`, core 1441-1449: the order needs a placement time before the tick); the EA's deal handler runs in that tick; `Grind_ProcessCloseByQueues` runs in the same tick (1763) and the simulated close-by completes at once; placement times are stamped by `Rpl_ScanNewOrders` after the engine (1784), BEFORE `Rpl_ProcessCloseByDone` (1787) and the timer (CB_DONE defect) | core at `90fbce4` | VERIFIED |
| K12 | What the first plan's misses look like against K4-K9: the real L0 after a close-by goes out lam + the gap to the next tick + 294 ms + the gap to the tick after that after the touch (B 1 Oct 11:12: the replay's EXT on the touching tick 11:12:11.208, the real EXT deal 11:12:11.489, OUT_BY 11:12:12.497, L0 placed 11:12:13.026 by send_logs, the EA's clock, K2); the replay's on the touch. Six misses read by hand were each one of: the close-by, serial sends, the fill after a touch, or a placement difference carried forward | first plan s12 record | DATA |

## 1. THE QUESTION

The first plan's question, unchanged: does a replay of our rules on IC's
ticks produce the deals B, C and D made? What is new: the simulated broker
and the EA's clock now follow the timing we measured in our own sends and
fills (s3), fixed before any run.

## 2. WHY A SECOND PLAN, NOT AN ATTEMPT

The first plan fixed the fill rule (instant at the touch) before any run
(GRC-5) and ruled the close-by latency a reported sensitivity (GO4-2).
Changing the broker model after seeing results is a new pre-registration,
not a fix: so this file. The holdout (9-13 Oct) has not been read by
anything (first plan s12, 10 Oct), so it can serve as this plan's holdout.
Fixes to the harness's own state remain outside the attempt count (GO4-3).

## 3. THE TIMING MODEL (FIXED BEFORE ANY RUN)

**Constants: the median of the three fleets' medians (K3, K4).**

| constant | value (ms) | from |
|---|---:|---|
| d_PENDING (a place) | 287 | 286, 287, 288 |
| d_MODIFY | 288 | 288, 288, 286 |
| d_CLOSE_BY | 294 | 294, 295, 293 |
| d_REMOVE | 43 | 43, 44, 42 |
| lam (deal after touch) | 261 | 263, 261, 261 |

**Rules.** All times are the broker's (the tick dump's server ms).

- **R1 the broker fills at the touch, the deal lands lam later.** A resting
  order whose price a tick reaches (the first plan's touch: ask <= price for
  a buy limit, bid >= price for a sell limit; prices on the symbol grid)
  is FILLED by that tick at its own price; the deal exists, and the EA is
  told, at touch + lam. From the touch the order cannot be modified or
  removed (a send to it in that interval fails, as a send to an order in
  execution); until touch + lam the EA still sees it resting. (The last
  two are CHOICES, not measured: GTM-1.)
- **R2 a send takes its duration, and the EA waits.** Every send the EA
  makes (place, modify, remove, close-by) takes its constant. Sends are
  serial: the next send starts when the previous returns. A placed or
  modified order rests at the broker (and can be touched) from its send's
  end; a removed order stops resting at its send's START (a later touch
  cannot fill it; a CHOICE, not measured: GTM-2); a close-by completes
  (its two OUT_BY deals exist, and the EA is told) at its send's end (K7).
- **R3 the EA's handlers run one at a time.** A deal the EA is told of
  (R1, R2) runs its trade-event handler as soon as the EA is free, at that
  deal's time or when the running handler returns (K5). `OnTick` runs for a
  tick that arrives while the EA is free. A tick that arrives while `OnTick`
  runs gets no `OnTick` of its own (K10); a tick that arrives while a
  trade-event handler runs queues ONE `OnTick`, which runs when the EA is
  free and reads the newest tick at that time. A handler that makes no send
  takes 0 ms.
- **R4 what the EA sees.** In any handler the EA's market (bid, ask, time)
  is the newest tick at or before the moment the handler runs; its book is
  the broker's at that moment (R1, R2).
- **R5 the carry timer** runs as now (once a minute on the tick path, core
  1790), as a handler under R3.

What these rules give against K6-K9, by construction: the close-by on the
first tick after the deal (the queue is served first in `OnTick`), its
completion 294 ms later, the sends after it back to back, the L0 on the
next tick after that; an ENT fill's sends at the deal time.

**Not modelled** (reported where they bite): the send-duration outliers
(K3: 6 of 3,746 sends over 1 s, the longest 5.8 s); the drift between the EA's
clock and the broker's (K2: nothing here depends on it); the EA's 1 s
`OnTimer` (deal replay sweep, telemetry); a broker refusal (retcode) other
than R1's.

## 4. WHAT DOES NOT CHANGE

The 29 segments and their inputs (`research/replay/inputs/eurusd_20261008/`,
66 files); seeding at an init and the resting book adopted there; T1's
re-synchronisation (positions reset to the true book after every real deal,
with fixes 2, 3 and 5); `compare.py` and its marks: T1 >= 95% of
T0-touchable matched (side, role, layer, order price within 0.2 pip, time
within 60 s) and replay-only <= 5%, per fleet; T2 per fleet and side over
the priced segments (S, R, ROLL_ACCEPTED within 10% or 1, rho within 0.1),
failing when UNPRICED segments hold more than 20% of the fleet's real
deals; the miss categories M1-M13. T0 (1052 / 1052) and T0b stand.

## 5. THE HARNESS CHANGES (FOR ONE CURSOR PROMPT, AFTER GEMINI)

- **H1 the CB_DONE defect** (first plan s12, GRC2-4): an order placed at
  any stage of a tick gets that tick as its placement time
  (`Rpl_ScanNewOrders` after every stage that can place, CB_DONE and TIMER
  included). Harness state, not a rule (GO4-3). Run and reported on its own
  before H2.
- **H2 the timing model** (s3), behind ONE run input `timing` (0 = off,
  1 = s3) with the constants as run inputs too (s3's values as defaults,
  so a sensitivity run changes inputs, not code; GRC2-4 rejected a
  hard-coded delay). **With `timing = 0` the outputs must equal H1's byte
  for byte** (deals, events, orders; the run clock aside), proved in the
  suite and on the six runs.
- Tests first, against hand-derived timelines (one per rule R1-R4, and a
  close-by chain like K6-K9 end to end), then the core; the suite; the
  operator compiles; Cursor runs; Claude reads the commits line by line.

## 6. THE RUNS

**Deciding:** the six runs (B, C, D x sync, free) with `timing = 1` and
s3's constants; `compare.py` as now.

**Reported, never deciding** (the first plan's s6 sensitivities, restated;
GRC2-4: the latency on every place and modify):
- `timing = 0` after H1 (the instant broker; what H1 alone changes).
- Fill only 0.1 pip through (the first plan's s6), with `timing = 1`.
- +250 ms and +1 s on every place and modify (d_PENDING and d_MODIFY
  raised by that much), with `timing = 1`.
- All five constants at the median of the fleets' p10 (283, 284, 289, 38,
  256) and at the median of their p90 (294, 301, 302, 52, 281).

## 7. THE HOLDOUT (PRE-REGISTERED NOW)

- **Window:** EURUSD, the deals after **9 Oct 04:32Z** to **Tue 13 Oct
  22:00Z** (first plan s8 and the operator's ruling, 9 Oct ~22:40Z). D
  runs from its 9 Oct 04:24:14Z init; B and C run on from their 7 Oct inits
  (no synthetic init: the real EA did not restart), their ticks w2 + the
  holdout dump joined at w2's 01:30 server seam (checked for no gap and no
  overlap). If the holdout's config_events show an init on B or C (a
  restart, a compile), it cuts a segment there, as the first plan's s2.
- **Marks:** the same as s4, scored on the deals after 04:32Z only (GRC2-3
  (a)). Each fleet has one holdout segment, so T1 decides T2 there: if T1
  fails for a fleet, T2 fails for it (the 20% rule reduces to that; GRC2-3
  (b)). T2's free runs for B and C start from the 7 Oct true book and are
  scored after 04:32Z (their calibration part is segments 9 and 19, both
  priced at `90fbce4`, re-scored under this plan).
- **Data:** exported on Tue 13 after the 22:00Z close (send_logs 9-13 Oct
  before their 14-day retention, the archives, one tick dump on wine-d from
  `2026.10.09 01:30` server to `2026.10.14 01:00` or later), hashed, and
  read by NOTHING (no replay, `compare.py`, T0 or script) until s8's
  calibration result is in and the harness is frozen. T0 on the holdout
  ticks then runs first, with the first plan's mark (>= 95% touched; below
  it, STOP and back to Gemini).
- **No code change** once the first holdout run starts; the harness commit
  and the constants are recorded before it.

## 8. WHAT A RESULT MEANS

- **Calibration pass** (T1 and T2 on all three fleets, with `timing = 1`):
  the harness is frozen and the holdout runs (s7). Only a holdout pass
  makes the replay "calibrated on EURUSD" (first plan s8: sweeps on EURUSD
  allowed; another pair needs its own T0-T2 first).
- **A fail in M4-M10 (a rule):** cause first; at most three attempts on
  this window, then back to Gemini (the first plan's s8 count, starting at
  0 here). No constant of s3 changes in an attempt.
- **A fail in M1-M3 again:** the timing that matters is beyond a
  deterministic model of our sends; a tick-level replay is not trusted, and
  T2 decides count-level use (as the first plan).
- **The sensitivities** show how much the verdict leans on s3's constants:
  a verdict that flips between p10 and p90 is recorded as fragile, never
  re-decided.

## 9. ORDER OF WORK

1. This file to Gemini; his rulings checked in source (s11).
2. One Cursor prompt (RESTATE AND STOP; tests first; H1 then H2), through
   Gemini; built; Claude's line-by-line read; the operator compiles; the
   suite; the runs of s6; `compare.py`, `classify_misses.py`,
   `read_orders.py` on them.
3. Tue 13 after 22:00Z: the holdout's data exported and hashed only (s7).
4. s8's result; the holdout if it passes.

Negative space: no fleet action and no chart edit; no EA file changes (the
pin: `ea/fxgrind.mq5` and the engine as `5bb5fdb`); no constant changed
after a run; no tick statistic of price; nothing reads the holdout's data
before s7 allows it; no mark adjusted to a result.

## 10. FOR GEMINI (attack the premises; say which fact is missing)

- **GTM-1.** R1: the broker's deal time follows the first touching tick by
  a near-constant 261 ms (p10 256, K4). We read that as "filled at the
  touch, told 261 ms later". The other reading: "filled at touch + lam
  against the price then" (an order whose touch reverses within 261 ms
  would not fill). T0 found the last tick at or before the deal AT the
  limit in 861 of 867 deals, and a touch is a tick at the limit. Which
  reading does the evidence support, and does R1 need the other as a
  sensitivity? R1's two choices (no modify or remove after the touch; the
  EA sees the order resting until touch + lam) are not measured: right?
- **GTM-2.** R2: an order rests from its send's END, and a removed order
  stops resting at its send's START. The broker may act anywhere inside the
  send (it is a round trip; K7 shows a close-by's OUT_BY ~7 ms before its
  send returns). Are the end (place, modify) and the start (remove) the
  right fixed choices?
- **GTM-3.** R3: MT5 does not queue `OnTick` while one runs (K10). Is the
  rule for a tick arriving while a trade-event handler runs (one queued
  `OnTick`) right for MT5, and does it matter for K9's later ticks (p75
  0.4-0.6 s)?
- **GTM-4.** s3's constants are medians of THIS window's sends, used to
  replay THIS window. They are measured from the EA's own send timing, never
  from a replay outcome, and the holdout is unseen. Is that a measurement
  or a fit? What would make it a fit?
- **GTM-5.** s5 H2: `timing = 0` must equal H1 byte for byte. Is that the
  right proof that the model is the only change, or is a second proof
  needed (e.g. a hand-derived timeline per rule)?
- **GTM-6.** s7: the holdout as pre-registered (one segment per fleet, T1
  decides T2 there, B and C free from 7 Oct). You ruled (GRC2-3 (c)) that a
  7 Oct start contaminates T2 with pre-holdout drift; the operator ruled out
  a synthetic init. Is scoring only the deals after 04:32Z, with the 7 Oct
  part already priced in the calibration (segments 9 and 19), enough? If
  not, what form, fixed now?
- **GTM-7.** s8: the attempt count starts at 0 under this plan. Right?
- **GTM-8.** What fact is missing?

## 11. RULINGS AND RECORD

(empty)

Line count: 247
