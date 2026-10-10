This message has a line count at the bottom

# REPLAY CALIBRATION ON EURUSD (B / C / D), THIRD PRE-REGISTRATION: FIT FOR COUNT-LEVEL USE

| | |
|---|---|
| Status | **RULED** (Gemini G3-1..6, 10 Oct ~17:53Z; checked by Claude, s10). The scorer (`score_plan3.py`, s6) is built and committed; nothing reads the holdout before Tue 13's export and hash |
| Origin | Plan 2 closed under its s8 (b) (`replay-calibration-eurusd-2.md` s18). Fable's consult (`replay-consult-fable.md` s9, its findings verified). Operator 10 Oct ~17:28Z: a plan 3 on Claude's proposals, holdout 9-13 Oct; ~17:37Z "proceed" on option 1 (score everything) |
| Rules it keeps | Plan 1 and plan 2 where this file does not change them: the window and segments, seeding at an init, the data, the engine, T0, the miss categories, the replay's purpose (plan 1 s8: ranges and stability, never optima), no price signal, the EA pinned |
| Supersedes | Plan 2's T2 (the per-segment UNPRICED rule and rho within 0.1) as the gate for the replay's purpose. T1 stays |
| Harness | **Frozen at `145f092`** (`replay-harness`; `timing = 1`, plan 2's base constants). No code change under this plan |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| P1 | At `145f092` T1 passes on B, C, D (96.0 / 95.5 / 97.3%; replay-only 2.8 / 3.6 / 2.4%) | `results/eurusd_20261008_145f092/report.md` | MEASURED |
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

Line count: 197
