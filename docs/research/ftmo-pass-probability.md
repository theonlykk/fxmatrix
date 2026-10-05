This message has a line count at the bottom

# FTMO PASS PROBABILITY -- WHAT ARE THE ODDS OF A PAYOUT? (C124)

| | |
|---|---|
| Status | **FIRST RUN, exploratory** (Claude, 5 Oct ~17:40Z). Not a ruling. Re-run with the 5-9 Oct days after the holdout (C125) |
| Origin | Operator, 5 Oct ~03:50Z: "we have to pay $100 upfront, bear vps costs and have to make $800 before we ever see any payout. i can see the odds of that being slim"; the targets corrected to $1,000 then $500 (5 Oct ~17:30Z: the $500 / $300 figures came from FTMO's demo account) |
| Code | `research/ftmo_pass/` (`ftmo_days.py`, `ftmo_sim.py`, `c124_run.py`, tests; README). Standard library; read-only on the files |
| Data | Deal histories `history_<login>.csv` (`grind_history_dump.mq5`, dumped 3-4 Oct) of FTMO 1514731800 (A), IC 53066709 (B), 53071896 (C), 53077984 (D); FTMO minute bid / ask `bidask_ftmo_2026-10-02/` (20 Sep - 2 Oct close) |

## 1. THE RULES USED

From ftmo.com/en/trading-objectives (2-Step, read 5 Oct ~17:30Z) and
the operator:
- Capital $10,000. **Challenge target +$1,000** ("10% for the FTMO
  Challenge"), **Verification +$500** ("5% for the Verification"), each
  from a fresh $10,000; at least 4 trading days per phase; no time limit
  stated (runs are cut at 250 trading days per phase, counted as not
  passed).
- **Daily loss $500 from the BALANCE at 00:00 CE(S)T** = 22:00Z ("the
  account balance recorded at 00:00 CE(S)T of the current day"): open
  loss carried over midnight counts against the new day at once.
- **Max loss: equity above $9,000** (static).
- Operator: fee $100; 90% of profit paid out; VPS $20 a month. Fee
  refund on the first payout: not on the page, so run both ways.
- Funded account (model): the same limits; a payout every 21 trading
  days of 90% of the profit above $10,000, then back to $10,000; ends at
  a breach or after 250 trading days.

## 2. METHOD

1. **Days** (`ftmo_days.build_days`): positions rebuilt from the deals;
   per FTMO day (22:00Z-22:00Z): realised P&L r (profit + swap +
   commission by deal time), open MTM at the start m0 and end m1 (longs
   at the minute bid, shorts at the ask, quote currency to USD at the
   minute's mid), and low = the minute minimum of equity minus the
   day-start balance (the daily test, carried loss included). Weekend
   days with no quote drop out. "ring7" keeps the positions opened by
   the seven ring pairs' OPT magics (A's ring since 2 Oct).
2. **Check:** the last day's m1 against each dump's own header
   (equity - balance): A -77.25 vs -80.12, B -236.66 vs -244.43, C
   -251.73 vs -257.95, D -165.69 vs -171.75. Ours is $3-8 less negative
   on each: swap accrued on open positions is not in the MTM (and IC is
   marked on FTMO's prices).
3. **Simulation** (`ftmo_sim`): a simulated day replays one real day:
   equity moves by r + m1 - m0; the daily test uses that day's own low
   (so its carried loss counts); the max-loss test uses the simulated
   equity plus the day's dip. Days are drawn in blocks of 2 consecutive
   days, never across sources. Drift sensitivity shifts every day's P&L;
   a "tail day" (s3.3) replaces a day with probability p.
4. **Tests:** 13, every value derived by hand (a round trip and its
   intraday low, a short on a CAD cross, the magic filter, a carried
   position, a closed-market day, the 4-day rule, the daily limit on the
   intraday low, max loss, gambler's ruin at zero drift 11/21 and 11/16,
   blocks, an attempt with payouts, the summary and EV, the tail day).
   At the stubs: 13 of 13 fail; then 13/13. Fourteen rules broken once
   each and caught (marks swapped, no currency inversion, the closing
   deal's magic, a realised-only low, no commission, weekends kept, the
   daily test on the close, max loss without the dip, no 4-day rule, no
   split, no refund, blocks wrapping, phase 2 skipped, the tail inverted).

## 3. RESULTS

### 3.1 The days (seven ring pairs; full table in the run output)

23 days with the seven pairs (A 8, B 8, C 5, D 2; 24 Sep - 2 Oct, a
Sunday-open sliver counted as a day): **mean change in equity +$5.03 a
day, sd $50.00, se $10.43; worst daily low -$226.93** (A, Thu 1 Oct, the
CHF trend). With all eleven instances A's worst low was -$306.23 the
same day. **No day in the sample came near the $500 limit.**

### 3.2 Scenarios (20,000 attempts each, seed 1)

| scenario | P(Challenge) | P(both) | median days to pass | EV / attempt | EV, fee refunded |
|---|---|---|---|---|---|
| A, all instances (8 days) | 0.999 | 0.999 | 110 | +$2,315 | +$2,415 |
| A, ring7 (8 days) | 0.967 | 0.965 | 186 | +$1,048 | +$1,145 |
| A+B+C+D ring7 (23 days) | 0.791 | 0.758 | 230 | +$380 | +$456 |
| the same, drift -$10 a day | 0.001 | 0.000 | - | -$269 | -$269 |
| the same, drift +$10 a day | 1.000 | 1.000 | 97 | +$2,772 | +$2,872 |
| the same + one 23-Sep day in the pool | 0.045 | 0.010 | 152 | -$139 | -$139 |

### 3.3 The two numbers that decide it (ring7 pool; 5,000 attempts each)

Drift set by shifting every day; a tail day = cycle 2's 23 Sep (open MTM
-$332 carried in, liquidated at -$505.34 against the day-start balance,
`docs/FULL_TRIAL_RECORD_1514582088.md`), with probability p a day.
Cells: P(both phases) / median trading days to pass / EV per attempt
(no refund).

| drift a day | no tail | 1 in 250 days | 1 in 100 | 1 in 50 |
|---|---|---|---|---|
| $0 | 0.05 / 291 / -$336 | 0.02 / 286 / -$250 | 0.00 / 230 / -$185 | 0.00 / 264 / -$148 |
| +$5 | 0.75 / 231 / +$375 | 0.31 / 214 / -$67 | 0.09 / 186 / -$157 | 0.01 / 156 / -$146 |
| +$10 | 1.00 / 139 / +$1,683 | 0.56 / 133 / +$469 | 0.24 / 126 / -$8 | 0.07 / 114 / -$125 |
| +$15 | 1.00 / 96 / +$2,765 | 0.68 / 94 / +$1,072 | 0.37 / 91 / +$221 | 0.16 / 87 / -$72 |
| +$20 | 1.00 / 74 / +$3,825 | 0.74 / 72 / +$1,686 | 0.47 / 71 / +$499 | 0.24 / 69 / +$13 |

At zero drift most runs are still open after 250 trading days (with a
$50 daily sd, reaching +$1,000 by chance takes about (1000 / 50)^2 = 400
days), so "slim" there means "not within a year", not a breach.

## 4. WHAT IT SAYS

1. **The answer rests on two numbers the sample cannot pin down:** the
   drift (+$5 a day, se $10: not distinguishable from zero) and how
   often a day like 23 Sep comes (none in these 23 days; one in cycle
   2's ten trading days, 10-23 Sep, at sixteen instances). Across +/- $10 of drift the pass rate goes from 0 to 1.
2. **Passing is slow:** at +$10 a day, about 130 trading days (six
   months) for both phases. Over that time a tail day once a year takes
   the pass rate from about 1.0 to 0.56; once in 100 days to 0.24, and
   the attempt's value to about zero.
3. **The tail is the carried book:** 23 Sep was 84% loss carried in at
   midnight (`FULL_TRIAL_RECORD`: -$424 of -$505.34 from positions
   carried in). The ADR-158 breaker (80%, $400)
   blocks entries and cancels resting entries but closes nothing (ADR-158
   s5), so it cannot stop a carried book from going through $500 in a
   trend. Lowering what is open at 22:00Z is the lever on the tail;
   drift is the lever on time. (Proposal, not ruled.)
4. **The fee refund barely matters** (+$5 to +$100 per attempt); the VPS
   cost matters more because passing takes months.
5. **What the operator's arithmetic was right about:** with no edge the
   odds are poor. With an edge of about $10-15 a day AND a tail no more
   often than once a year, an attempt is worth roughly +$470 to +$1,070
   (more with the eleven-instance days, which are not the seven-pair
   book FTMO now runs).

## 5. CAVEATS

- 23 days, one regime, two weeks; the IC days ran IC's geometry, the
  lattice and no breaker, scored here under FTMO's rules.
- Marks at minute closes: the true intraday low is a little lower.
- Swap accrued on open positions is not in the MTM ($3-8 on these books).
- Blocks of two days; carried state across a block boundary is the
  historical one, not the simulated one.
- The funded phase replays the same days; payout every 21 trading days
  is a model, not FTMO's schedule.
- One tail shape (23 Sep); other tails (a Sunday gap, an SNB day) differ.

## 6. NEXT

1. Re-run with the 5-9 Oct days after the holdout (C125 measures the
   drift on unseen days).
2. A tail-frequency estimate from more history: cycle 2's daily rows
   (MetriX) and the IC fleets' days as they accumulate.
3. If FTMO continues: what is open at 22:00Z per day (the carried MTM)
   as a watched number; a question for Gemini with the holdout result.

Line count: 150
