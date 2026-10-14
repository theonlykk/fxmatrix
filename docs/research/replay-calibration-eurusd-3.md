This message has a line count at the bottom

# REPLAY CALIBRATION ON EURUSD (B / C / D), THIRD PRE-REGISTRATION: FIT FOR COUNT-LEVEL USE

| | |
|---|---|
| Status | **CLOSED: FAIL** (14 Oct ~03:10Z, s82): T1 fails on C (94.4%) and D (94.9%); the count, bias and difference marks pass (s7, note of 14 Oct ~03:10Z). Before: **RULED** (Gemini G3-1..6, 10 Oct ~17:53Z; checked by Claude, s10). The scorer (`score_plan3.py`, s6) is built and committed; nothing reads the holdout before Tue 13's export and hash |
| Origin | Plan 2 closed under its s8 (b) (`replay-calibration-eurusd-2.md` s18). Fable's consult (`replay-consult-fable.md` s9, its findings verified). Operator 10 Oct ~17:28Z: a plan 3 on Claude's proposals, holdout 9-13 Oct; ~17:37Z "proceed" on option 1 (score everything) |
| Rules it keeps | Plan 1 and plan 2 where this file does not change them: the window and segments, seeding at an init, the data, the engine, T0, the miss categories, the replay's purpose (plan 1 s8: ranges and stability, never optima), no price signal, the EA pinned |
| Supersedes | Plan 2's T2 (the per-segment UNPRICED rule and rho within 0.1) as the gate for the replay's purpose. T1 stays |
| Harness | **Frozen at `145f092`** (`replay-harness`; `timing = 1`, plan 2's base constants). No code change under this plan |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| P1 | At `145f092` T1 passes on B, C, D (96.0 / 95.5 / 97.3%; replay-only 2.8 / 3.6 / 2.4%). **Corrected 12 Oct (s80; a slip, no mark touched): C's replay-only is 12 of 359 = 3.3% at `145f092` (`report.md`, `results/plan3/score_calibration_145f092.md`, plan 2 s18); 3.6% was `868bcc3`'s figure** | `results/eurusd_20261008_145f092/report.md` | MEASURED |
| P2 | Free-run totals over ALL 29 segments: S real 384, replay 401 (+4.4%); R 108 / 107; roll acceptances A 124 / 123. The 2 Oct payrolls segments (B 3, C 13, D 23) carry +20 of S; the other 26 net -3 | `report.md` (T2 per segment and side); consult s9 | MEASURED |
| P3 | The payrolls minute (2 Oct 15:30:00-15:30:19 server): live sends took 1.2-5.8 s (normally ~0.29) and modifies were REFUSED (10029 frozen on C and D; 10013 on B, C, D; 10015 on D). The replay models neither (plan 2 s3 "not modelled") | `results/plan3/burst_sends.py` / `.txt` (send logs, 9 Oct export) | MEASURED |
| P4 | The live day-to-day spread of S, R and A per fleet and side over 1, 2, 5, 6, 7, 8 Oct, and the tolerances of s3 | `research/replay/live_spread.py` (+ tests); `results/plan3/live_spread_n3.txt`, `_n6.txt` | MEASURED |
| P5 | The calibration window scored under s3's count, bias and difference marks (6-day tolerances): one side out (D long S +4 against 2.75); no one-sign bias (D short S 0); the live differences reproduced. **Seen data: a check that the marks are not built to fail, not evidence** | `results/plan3/p5_calibration_score.py` / `.txt`; s5 | COMPUTED |
| P6 | Calendar: no scheduled major US release 9-13 Oct (payrolls were 2 Oct; CPI 14 Oct 08:30 ET); the German ZEW 20 Oct. 12 Oct is US Columbus Day (from knowledge) | fedratecalc.com October 2026; Guggenheim 2026 US calendar; zew.de PM9529 | CHECKED 10 Oct |
| P7 | The three fleets trade one feed (plan 1 s4.1) and share misses (6 of B's 23 miss rows recur on C within 10 ms): they are not three independent tests | consult s9 | VERIFIED |

## 1. THE QUESTION

Is the replay fit for its purpose: the COUNTS of scalps S, roll closes R and
roll acceptances A per pair and side, under a given geometry, in markets
without a scheduled-release burst, on EURUSD? Deal-for-deal fidelity is not
the purpose (plan 1 s8); T1 stays as the proof that the rules reproduce.

## 2. WHAT CHANGES FROM PLAN 2

- The gate for the purpose is the free run's COUNTS per fleet and side over
  ALL deals, nothing excluded, with tolerances from the LIVE day-to-day
  spread of each count (P4); plus a bias mark and a fleet-difference mark.
- Dropped: the per-segment UNPRICED rule (it hid the burst bias, P2, and
  punished small segments) and rho as a mark (rho is 0.08-0.11 on some
  sides; it is reported, never scored).
- No harness change: the runs of s7 use `145f092` as built for fix 7.

## 3. THE MARKS (FIXED NOW)

**Scored window (as plan 2 s7):** EURUSD deals after **9 Oct 04:32Z** to
**Tue 13 Oct 22:00Z**. D runs from its 9 Oct 04:24:14Z init; B and C run on
from their 7 Oct inits (no synthetic init; GTM-6's limitation stands). An
init inside the window cuts a segment there, as plan 1 s2.

- **T0:** a touching tick on the ORDER price for >= 95% of real deals, per
  fleet; below it STOP (back to Gemini).
- **T1 (SYNC):** per fleet, pooled over the window: >= 95% of touchable real
  deals matched (plan 2 s4's match rule) and replay-only <= 5%.
- **C (counts, FREE):** per fleet and side, the replay's S, R and A over the
  window against the real counts: |replay - real| <= tol (table below). A
  side is OUT if any of its three counts is outside its tol. **FAIL if two
  or more of the six sides are OUT, or any count is beyond 2 x tol.**
- **B (bias):** **FAIL if** the signed S error (replay - real) has the same
  sign on all six sides AND its sum is more than 5% of the real S total.
- **D (difference):** for S and R per side, the live differences C - B and
  D - B. **FAIL if** a live difference is larger than the larger tol of the
  two fleets and the replay's difference has the opposite sign or is zero.
- **INCONCLUSIVE:** a side with fewer than 10 real S in the window is not
  scoreable (left out of C, B and D); fewer than four scoreable sides: the
  verdict is "not falsified, not confirmed".

**Tolerances** (`live_spread.py`, n = 3 holdout days: tol = max(2, sd x
sqrt(3) / 3), sd the sample sd of the six live daily counts of P4):

| fleet | side | S sd / tol | R sd / tol | A sd / tol |
|---|---|---|---|---|
| B | L | 5.22 / 3.01 | 1.21 / 2.00 | 5.72 / 3.30 |
| B | S | 5.24 / 3.03 | 2.42 / 2.00 | 2.80 / 2.00 |
| C | L | 5.61 / 3.24 | 2.86 / 2.00 | 5.43 / 3.13 |
| C | S | 6.18 / 3.57 | 3.14 / 2.00 | 3.20 / 2.00 |
| D | L | 3.37 / 2.00 | 2.68 / 2.00 | 4.52 / 2.61 |
| D | S | 6.53 / 3.77 | 2.07 / 2.00 | 3.21 / 2.00 |

The fraction (one third) and the floor (2) are Claude's proposal after
Fable's (consult s9 F1), accepted by the operator (~17:28Z); they were set
before P5 was computed. They are sized against the decisions the replay
serves: the live fleets differ by +8 to +24 S a week on a side (P2's
window), far beyond these tolerances.

## 4. WHAT A RESULT MEANS

- **PASS** (T0, T1, C, B, D): the replay is fit for COUNT-LEVEL use on
  EURUSD in markets without a scheduled-release burst: ranges and
  stability of S, R and A for geometries BRACKETED by the live fleets'
  geometries, with any ranking confirmed by a live round (consult F5). Not
  for tick-level use, not for bursts, not for another pair (each pair needs
  its own T0, T1 and count check on its own history first).
- **FAIL:** not fit. The cause is read (which side, which count, which
  days), recorded, and any next step is a new plan.
- **INCONCLUSIVE:** recorded as such; a further window needs a new
  pre-registration before it is read.

## 5. KNOWN LIMITS, RECORDED BEFORE THE HOLDOUT

- **Bursts:** the replay over-fills when the broker slows and refuses (P3);
  the payrolls segments over-scalp by +20 S in the calibration window. This
  plan's scope excludes such markets by its claim (s4), not by excluding
  data: the holdout is scored whole.
- **One feed:** B, C and D are one tick stream (P7); the three fleets are
  one test with three geometries, not three tests.
- **B and C's free runs** carry their free state from 7 Oct into the window
  (GTM-6); D is the clean fleet.
- **The live spread** (P4) mixes geometry changes across rounds (upper bound
  on day-to-day noise), and 1 Oct is a partial day on D (it starts 05:19Z).
- **The calibration window under these marks (P5, seen):** S errors B L +4
  (tol 4.26 at n = 6), B S +2, C L +4, C S +3, D L +4 (tol 2.75: OUT), D S
  0; R and A all within 1; one side OUT, no one-sign bias, differences
  reproduced (long S C - B +8 / +8, D - B +24 / +24; short +4 / +5, 0 / -2).
  This is not evidence for the plan: the window has been seen.
- **The holdout's power** (consult F4): it can falsify a gross failure, not
  confirm fit; R per side over three days is likely single figures.
- **Calendar (P6):** no scheduled major release in the window. An
  unscheduled event is scored like any other day.

## 6. THE SCORING (built and committed BEFORE any holdout data is read)

`research/replay/score_plan3.py`, tests first (hand-derived, a test per
mark, the inconclusive rule and the 2 x tol rule), reading `compare.py`'s
per-segment free and sync counts. **Its first committed output is the
calibration window (6-day tolerances), which must reproduce P5 exactly**;
then it is frozen with the tolerance table of s3.

## 7. THE HOLDOUT (as plan 2 s7)

- **Tue 13 Oct after 22:00Z:** send_logs 9-13 Oct, the archives, one tick dump
  on wine-d from `2026.10.09 01:30` server to `2026.10.14 01:00` or later:
  exported and hashed ONLY.
- Then, in order, each step committed before the next: the holdout inputs
  (the existing builders, with a manifest of hashes); T0 (>= 95% or STOP);
  the runs (B, C, D x SYNC, FREE; `timing = 1`, base; harness `145f092`;
  the `timing = 0` runs reported, never deciding); `compare.py
  --t0-price order`; `score_plan3.py`; the verdict.
- No code change once the first holdout run starts.
- **Note (12 Oct, s80; operator ~01:39Z):** "read by nothing" means nothing
  of the REPLAY: no replay run, `compare.py`, T0, scorer or script on the
  holdout's ticks, sends or archives. Round 3's scoring (Tue 13 ~22:35Z,
  `equity_score.py` on live EURUSD deals and bid / ask of 12-13 Oct) and
  the daily fleet status reads look at LIVE results only and do not spoil
  the holdout: the harness, marks, tolerances, window and scorer are
  frozen and none may change after them. Not put to Gemini. The command
  list for Tue 13: `docs/runbooks/plan3-holdout-export.md`.
- **Note (12 Oct ~03:40Z, s80; operator ~03:00Z):** an experiment build of
  ADR-167 is specified on a SEPARATE branch, `replay-adr167`
  (`prompts/cursor_adr167_replay.md`). This plan's harness is unchanged:
  `145f092` on `replay-harness` (`efada62`). `D:\mt5-replay` holds one
  compiled copy, so the FIRST step of the holdout's runs is the restore:
  `git checkout replay-harness`, `replay_run.ps1 -Mode Copy`, the
  operator's GUI compile, the suite at 461 / 461. No mark, tolerance,
  window or code of this plan changes.
- **Note (13 Oct ~23:10Z, s81): the holdout EXPORTED AND HASHED ONLY**
  (`research/replay/inputs/eurusd_holdout_raw.sha256`): sends and archives
  for B, C, D (`_2026-10-13_2210`, exported 22:13Z) and the EURUSD ticks
  (`ticks_53077984_EURUSD_hold.csv`, 9 Oct 01:30 to 14 Oct 01:30 server,
  174,299 ticks, clean). An earlier export of the same six (~21:45Z) is
  recorded as superseded. Nothing has read them. Round 3's scoring used a
  separate study export and wine-c's bid / ask, not these files.
- **Note (14 Oct ~02:20Z, s81): s7's first step, THE HOLDOUT INPUTS**
  (`research/replay/build_holdout.py`, tests first; manifest
  `research/replay/inputs/eurusd_holdout.sha256`, set `eurusd_holdout`).
  The seven raw files hash equal to their manifest. One segment a fleet
  (no init in the window): B 31 from its 7 Oct 02:21:20Z init, C 41 from
  02:12:36Z, D 51 from 9 Oct 04:24:14.290Z, all to 14 Oct 01:00 server;
  tags eurusd_b / c / d as before. No breaker or API-limit code in any
  window: intervals empty. No cap warning. Checks: seed_31 / orders_31 and
  seed_41 / orders_41 equal the calibration's seed_9 / orders_9 and
  seed_19 / orders_19 byte for byte; B's and C's real deals up to 9 Oct
  01:00 server equal the calibration's (214 and 239 rows); swaps.csv's
  1-9 Oct rows equal the calibration's. Ticks: w2 and hold joined at
  9 Oct 01:30 server (`build_holdout.py join`: headers meet, no tick on
  the wrong side, 44.9 s from the last w2 tick to the first hold tick),
  `ticks_53077984_EURUSD_w2h.csv`, 651,120 ticks, sha256 `fe37e42a...0392`, 22,397,330 bytes
  (in the manifest's comments; not in git). Next: T0.
- **Note (14 Oct ~02:35Z, s81): s7's T0 PASSES** (`research/replay/results/plan3/holdout_t0.py`,
  output `holdout_t0.txt`; the same lines as `score_plan3.fleet`'s T0, no run read): a
  touching tick on the order price for every real deal after the cut, B 69 / 69, C 72 / 72,
  D 59 / 59 (whole windows 172 / 172, 188 / 188, 59 / 59). Next: the runs (B, C, D x SYNC,
  FREE, timing 1 base, then timing 0; harness `145f092`).
- **Note (14 Oct ~03:10Z, s82): s7's RUNS, COMPARE AND SCORE. THE VERDICT: FAIL (s4).**
  Twelve runs on `D:\mt5-replay` (harness `145f092`, `replay-harness` `efada62`; inputs set
  `eurusd_holdout` from `6734ee5`, `-Mode Inputs` 16 / 16; ticks w2h `fe37e42a...0392`; swaps
  `dbd8ee4a...`): B, C, D x SYNC, FREE at timing 1 (base, deciding) and timing 0 (reported);
  all exit 0, gaps 0, aborted 0; outputs and logs in `research/replay/runs_holdout/` (manifest).
  `compare.py --t0-price order` (`results/plan3/holdout_compare_145f092`, `_t0`; its T1 / T2
  columns are plan 1-2's whole-window marks, reported only). `score_plan3.py --cut-ms
  1791531120000 --tol results/plan3/live_spread_n3.txt` (`results/plan3/holdout_score_145f092.md`,
  `_t0.md`). Nothing changed in any code, mark, tolerance or window.
  - **T0:** B 69 / 69, C 72 / 72, D 59 / 59: pass.
  - **T1 (sync, after the cut):** B 67 / 69 = 97.1% PASS; **C 68 / 72 = 94.4% FAIL; D 56 / 59 =
    94.9% FAIL** (replay-only 2.9 / 4.2 / 3.4%).
  - **C (counts, free):** four sides scoreable (B L, B S, C S, D S; C L and D L have under 10 real
    S); S real / replay 10 / 10, 15 / 14, 16 / 17, 14 / 14; R and A equal on every side; no side
    OUT, no count beyond 2 x tol. **B (bias):** S errors 0, -1, +1, 0, sum 0 of 55: pass. **D
    (difference):** C - B and D - B reproduced: pass.
  - **Timing 0 (reported only):** the same T1 figures; every count within 1.
  - **The verdict is FAIL.** The reading used (s81 and s82, not put to Gemini; the operator's call
    if raised): the INCONCLUSIVE rule concerns the count marks only; a T1 fail is FAIL whatever
    the scoreable count. It did not bind here: four sides were scoreable.
  - **The cause, read (s4).** Nine real deals missed after the cut.
    - **Five are one moment, the Monday 12 Oct open.** Friday's last ask 1.12019; Monday's first
      quote 00:00:00.188 server, ask 1.11903 (11.6 pips lower). The replay fills the buy-side
      orders resting above it (B long L7 1.11909, B short exit L5 1.11917, C long L8 1.11911, C
      short exit L2 1.11921, D short exit L5 1.11907) on that first quote, at 00:00:00.449, at the
      order price. IC filled them at 00:01:00.640-00:01:00.700, at 1.11903, after the 00:01:00
      quotes: 60.2 s apart, outside the 60 s window, so each is a MISS and a replay-only deal.
      Inferred, not checked: IC does not trigger pending orders on the 00:00 quote. The
      calibration window had no fill at the 5 Oct open, so it never met the case.
    - **Three are the first short (L0)** filled at another time or price than live: C 13:02
      server (no replay L0 within hours; 10.3 pips away), C 17:23 (replay 17:20, 1.8 pips), D 14:18
      (replay 14:15, 0.3 pip).
    - **One is not read:** D long L7 entry, Tue 13 16:57 server at 1.11895; no replay deal near it.
    - Without the open, C would be 70 / 72 and D 57 / 59 (both pass): hindsight, recorded; it
      changes nothing.
  - Per s4: the replay is not shown fit for count-level use by this plan. Any next step is a new
    plan (backlog C152); the operator's call.

## 8. ORDER OF WORK

1. This file to Gemini; his rulings checked in source (s10).
2. `score_plan3.py` (tests first) and its calibration-window output = P5.
3. Tue 13 after 22:00Z: export and hash only (round 3 scored ~22:35Z, apart).
4. s7's steps; the verdict to the operator.

Negative space: no fleet action; no EA or harness change; no tolerance,
mark or window changed after any holdout file is read; nothing reads the
holdout's data before step 2 is committed.

## 9. FOR GEMINI (attack the premises; say which fact is missing)

- **G3-1.** The gate (s3 C): free-run S, R and A per fleet and side over
  all deals; tol = max(2, sd x sqrt(n) / 3) from the live daily spread;
  FAIL on two OUT sides or one count beyond 2 x tol. Is this a measurement
  or a fit, given P5 was computed after the fraction and floor were chosen
  but on a seen window?
- **G3-2.** Scope by claim, not by exclusion (s4, s5): the holdout is scored
  whole, and a PASS licenses use only in markets without a scheduled-release
  burst. Is that coherent, or must the burst be modelled first?
- **G3-3.** The bias (B) and difference (D) marks: the right forms, and the
  right thresholds (5%; the larger tol of the two fleets)?
- **G3-4.** The inconclusive rule (fewer than 10 real S on a side; fewer
  than four scoreable sides). Right, given three days?
- **G3-5.** One feed (P7): three fleets as one test. Does any mark double
  count because of it?
- **G3-6.** What fact is missing?

## 10. GEMINI'S RULINGS (G3-1..6, 10 Oct ~17:53Z) AND CLAUDE'S CHECK

**No mark, tolerance or window changes.**

- **G3-1: ACCEPTED (a measurement for the holdout), one premise
  corrected.** He says the sd baseline is "a fit of the seen data". The sd
  is the spread of LIVE daily counts only (`live_spread.py` reads the
  archives and the real deals, never a replay output); what was seen
  before the fraction and floor were set is live trading, not the
  replay's error. P5 (the replay against live) came after. The holdout
  stays the test.
- **G3-2: ACCEPTED** (scope by claim is coherent for count-level use).
- **G3-3: ACCEPTED, one premise corrected.** He reads the larger tol of two
  fleets as allowing for "independent execution noise". The fleets share
  one feed (P7), so their noise is not independent; the larger tol is the
  conservative choice either way.
- **G3-4: ACCEPTED.**
- **G3-5: ACCEPTED:** two OUT sides from one feed are one systemic failure
  seen from two geometries, which is what the mark is meant to catch.
- **G3-6: ANSWERED in source; no change.** A "day" in P4 is a SERVER
  calendar day (UTC+3: `close_time_broker[:10]` for S and R, the server-ms
  date for A, `live_spread.py` 44, 54), which runs rollover to rollover.
  The scored window (9 Oct 07:32 server to 14 Oct 01:00 server) is 0.68 of
  Friday + Monday + Tuesday + 1 h = **2.73 server days**. Using n = 3 makes
  each tolerance sqrt(3 / 2.73) = 1.05x the exact figure (where the floor
  of 2 does not bind). Recorded; n = 3 stands as pre-registered.
- **His sign-off has no questions for us** (BOOT s1's tell); every ruling
  above was checked against the code or the plan.

Line count: 278
