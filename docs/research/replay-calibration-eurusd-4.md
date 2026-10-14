This message has a line count at the bottom

# REPLAY CALIBRATION ON EURUSD (B / C / D), FOURTH PRE-REGISTRATION: PLAN 3's QUESTION, A FIXED HARNESS, A NEW WINDOW

| | |
|---|---|
| Status | **REVIEWED** (Argon G5-1..6, 14 Oct ~04:20Z; every quote checked by Claude, s9); amended 14 Oct ~04:35Z (s82). Committed before **Thu 15 Oct 21:00Z (17:00 ET)**, when the window opens. **The operator agreed, blinding included, 14 Oct ~13:57Z** ("yes blinding side is fine"). Before: DRAFT (14 Oct ~04:10Z) |
| Origin | Plan 3 CLOSED, FAIL on T1 (`replay-calibration-eurusd-3.md` s7, note of 14 Oct ~03:10Z). Its misses were read (C152) and the fixes F1-F4 found (`replay-consult-plan4.md` s3, s8, s10). Operator 14 Oct ~03:12Z: "why not work a bit more on that?"; ~04:10Z "lets do a bit more work tonight" |
| Rules it keeps | Plan 3 entire, except where this file says otherwise: the question (s1), the marks, match rule and tolerances (plan 3 s3), what a result means (plan 3 s4), its known limits (plan 3 s5), seeding at an init, T0 on the order price, the scorer `score_plan3.py` unchanged |
| Changes from plan 3 | The harness (s2: `145f092` + F1-F4); the window (s3); the development check (s4) |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| Q1 | Plan 3 FAILED on T1 only: B 67 / 69 PASS, C 68 / 72 = 94.4%, D 56 / 59 = 94.9%; counts, bias and difference passed | `research/replay/results/plan3/holdout_score_145f092.md` | MEASURED |
| Q2 | The nine misses: five at the Mon 12 Oct open (the trade session and the stale-feed guard), three first shorts and one long entry (sync's handling of the close-by and the start-up reprice flags) | `replay-consult-plan4.md` s2, s3, s8, s10 | MEASURED / READ IN SOURCE |
| Q3 | IC EURUSD sessions: quotes Mon-Thu 00:00-23:59, Fri 00:00-23:57; trade Mon-Thu 00:01-23:59, Fri 00:01-23:57 | the terminal's Specification window, read by the operator 14 Oct ~03:52Z | MEASURED |
| Q4 | Calendar: US CPI Wed 14 Oct 08:30 ET; US retail sales, PPI and jobless claims Thu 15 Oct 08:30 ET; US industrial production Fri 16 Oct 09:15 ET and the euro-area CPI (final) Fri 16 Oct 05:00 ET (minor); no further major US release listed to 21 Oct; the next FOMC 28 Oct; German ZEW Tue 20 Oct (plan 3 P6) | fedratecalc.com October 2026 (reviewed 12 Sep); TD Economics upcoming releases 12-16 Oct; plan 3 P6 | CHECKED 14 Oct ~04:30Z |
| Q5 | B, C, D frozen on round 3 geometry, EA `5bb5fdb`; no reload planned (compass rounds stopped, 13 Oct) | HANDOFF s81 continued 4 | RULED (operator) |
| Q6 | `send_logs` keep 14 days. The `_2210` exports already hold every EURUSD send of B, C, D from 1 Oct to 13 Oct 22:13Z | `research/replay/inputs/eurusd_holdout_raw.sha256` | MEASURED |

## 1. THE QUESTION

Plan 3's, unchanged (plan 3 s1): is the replay fit for the COUNTS of scalps S, roll closes R and
roll acceptances A per pair and side, under a given geometry, in markets without a
scheduled-release burst, on EURUSD?

## 2. THE HARNESS

- **`145f092` plus F1-F4 only** (`replay-consult-plan4.md` s8, s10), built through the pipeline (a
  prompt, a review, Cursor, tests first, the operator's GUI compile, the suite):
  - **F1.** No broker fill and no accepted send outside the trade session (Q3, an input, not a
    constant); a send in the closed minute is refused as IC's 10018 `[Market closed]`. The closed
    spans are [23:59:00, 00:01:00) Mon-Thu nights and [Fri 23:57:00, Mon 00:01:00), reading the
    specification's "00:01-23:59" as MT5's [from, to) (not testable from the logs: no live send
    between 23:56 and 00:01 except the refused ones).
  - **F2.** Sync takes a layer out of the book at its real `OUT_BY`, never earlier (not at the
    `EXT` row, not at the replay's own close-by completion); each real `ROLL` row is applied after
    the `OUT_BY` it follows in the archive's sequence (the clock fix in `build_real.py`).
  - **F3.** Sync book resets do not set the start-up reprice flags.
  - **F4.** The stale-feed guard (`Grind_FeedStaleAfterTick`, 5,000 ms) works in the replay as live.
- **Frozen before any window file is read.** Its commit is recorded here by the ONE amendment this
  plan allows: "s2: harness = `<sha>`", committed before the window's export is opened. If the
  harness is not ready by the export, the export is taken and hashed only, and waits.
- No code change once the first window run starts.
- **Blind until the freeze (G5-2).** From the window's open (Fri 16 Oct 00:00 server) until s2's
  amendment is committed, nobody looks at any EURUSD fill, send, scalp, roll or journal line of B, C
  or D after the cut, on pipshed or on a box. Allowed: fleet-level status (live, alerts, equity,
  balance, carry pass summaries), the IC login lines (C150), other pairs, and the export's own
  checks (copy, size, sha256, first line, `TICKS|` lines; runbook lines 30-32).

## 3. THE WINDOW (FIXED NOW)

- **Scored: EURUSD deals from Fri 16 Oct 00:00 server (Thu 15 21:00Z; cut `1792108800000`) to Wed
  21 Oct 01:00 server (Tue 20 22:00Z; end `1792544400000`).** Fri, Mon and Tue plus one hour: about
  3.04 server days. It opens after Thursday's burst (Q4) and contains the Mon 19 Oct open (00:00
  quotes, 00:01 trade), the test of F1 and F4.
- **Segments:** as plan 3 s7: one a fleet from its last init (B 7 Oct 02:21:20Z, C 7 Oct
  02:12:36Z, D 9 Oct 04:24:14.290Z) to the end, unless an init happens before the end (it cuts a
  segment, plan 1 s2). Tags `eurusd_b / c / d`.
- **Tolerances:** plan 3 s3's table unchanged (`live_spread_n3.txt`, n = 3): the window is about
  3.04 server days, so n = 3 fits as pre-registered for plan 3. **Not** rebuilt with the holdout's
  days (an R2-5 proposal of round 2, rejected: it would change a mark after a failure).
- **The data:** Tue 20 Oct from 22:10Z (18:10 ET), by `docs/runbooks/plan3-holdout-export.md` with
  new names: `send_logs` and archives for B, C, D; one tick dump on wine-d from `2026.10.14 01:30`
  to `2026.10.21 01:30` server, joined to w2h at the 14 Oct 01:30 seam. Exported and hashed ONLY.
  Insurance (C150): a tick dump and a `send_logs` export after Friday's close (Sat 17 Oct),
  copied and hashed only.
- **The builder joins the sends (G5-6).** `send_logs` keep 14 days (Q6): the 20 Oct export starts
  about 6 Oct 22:10Z, after orders resting at B's and C's 7 Oct inits were placed
  (`orders_31.csv`, `orders_41.csv`). The window's inputs are built from the `_2210` sends joined
  with the new export (rows deduplicated by `send_logs.id`), and the window's end set to
  `1792544400000`: a change to `build_holdout.py` (or a copy for plan 4), tests first, committed
  before the export is opened.

## 4. THE DEVELOPMENT CHECK (BEFORE THE FREEZE; NOT EVIDENCE)

The fixed harness runs on the two windows already seen: the calibration (1-9 Oct, 29 segments) and
plan 3's holdout (9-14 Oct). Both are development data: they guide the fixes and prove nothing.

- **The gate (G5-3):** `score_plan3.py` passes every mark (T0, T1, C, B, D) on both: the
  calibration window with `live_spread_n6.txt` and no cut (as P5), and plan 3's holdout with
  `live_spread_n3.txt` and `--cut-ms 1791531120000`. The nine misses of plan 3 resolved or each
  explained. Reported in full.
- **The inputs are rebuilt first** for both windows (`real_*.csv` by the fixed `build_real.py`, new
  manifests), so F2's clock fix is what is tested.
- A failure here is fixed and re-run as often as needed, within F1-F4 only: these windows are
  already seen. If F1-F4 cannot pass it, the window is still exported and hashed, and this plan
  stops (any further fix is a new plan).
- The harness hash that passes it is the one recorded in s2.

## 5. WHAT A RESULT MEANS

Plan 3 s4, word for word: PASS = fit for count-level use on EURUSD in markets without a
scheduled-release burst (geometries bracketed by the live fleets; rankings confirmed live); FAIL =
not fit, the cause read and recorded, any next step a new plan; INCONCLUSIVE = recorded, a further
window needs a new pre-registration. The reading of plan 3 s7 holds: a T1 fail is FAIL whatever
the scoreable count. `score_plan3.py` (unchanged) prints INCONCLUSIVE ahead of a T0 / T1 FAIL
(lines 213-216): the verdict is read by this rule from the report's T0 / T1 table and its counts
verdict, not from its last line (G5-6).

## 6. KNOWN LIMITS, RECORDED BEFORE THE WINDOW

- **B and C's free runs carry nine days** of their own state before the cut (D's seven): more drift
  than plan 3's two. The counts mark may suffer for it; the cause would be read, not excused.
- **The segments run through Wed's CPI and Thu's retail sales before the cut:** the replay
  over-fills in bursts (plan 3 P3), so the books at the cut may differ more than in plan 3.
- **One feed** (plan 3 P7); **IC access** (C150); **power** as plan 3 s5 (three days).
- **The development windows have been seen** (s4), as plan 3's calibration was.

## 7. ORDER OF WORK

1. This file reviewed; the rulings checked in source; committed before Thu 15 Oct 21:00Z.
2. The F1-F4 prompt; review; Cursor; the suite; the development check (s4); the freeze (s2's
   amendment).
3. Sat 17 Oct: the insurance copies. Tue 20 Oct from 22:10Z: the export, hashed only.
4. As plan 3 s7: the inputs (manifest), T0, the twelve runs, `compare.py --t0-price order`,
   `score_plan3.py` with the new cut and the same tolerances; the verdict.

Negative space: no fleet action; no EA change; no mark, tolerance, match rule or window changed
after this file is committed; nothing reads the window's data before the freeze; F1-F4 only (any
other harness change is a new plan).

## 8. FOR THE REVIEWER (attack the premises; say which fact is missing)

- **G5-1.** The window opens Fri 16 Oct 00:00 server, after Thursday's burst (Q4). Right, or should
  Friday's minor releases also be left out?
- **G5-2.** The harness frozen by one amendment after the window opens but before its data is read
  (s2). Sound, given plan 3 froze before its window closed?
- **G5-3.** The development check (s4): are its expectations the right gate for the freeze?
- **G5-4.** Nine days of free-run drift for B and C before the cut (s6): a reason to score B and C
  differently, or only a known limit?
- **G5-5.** Plan 3's tolerances at n = 3 for about 3.04 server days (s3): right?
- **G5-6.** What fact is missing?

## 9. THE REVIEW (Argon, round 3, ~04:20Z 14 Oct) AND CLAUDE'S CHECK

Every quote and line number in the review was checked against the files at `0a17239`: all exact.

- **G5-1, accepted:** open after Thursday's 08:30 ET burst; Friday's minor releases stay in.
- **G5-2, accepted with its condition:** blind until the freeze (s2).
- **G5-3, accepted:** the development gate is `score_plan3.py`'s full verdict on both windows, not
  "moves within tolerance" (P5 has D L OUT and B L 0.26 inside its tolerance, so a shift of 1 could
  fail the count mark while "within tolerance"); the inputs rebuilt first (s4).
- **G5-4, accepted:** B, C and D scored alike; the drift is a known limit (s6).
- **G5-5, accepted:** n = 3 for 3.04 server days (each tolerance 0.99x the exact figure).
- **G5-6, accepted, three facts:** the sends join (s3); the scorer's verdict line (s5); F1's
  closed-span boundaries (s2).
- No question from the reviewer to us; none of its points was a premise we supplied wrongly.

Line count: 152
