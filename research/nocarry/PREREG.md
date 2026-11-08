This message has a line count at the bottom

# NO CARRY -- DOES THE t3 GRID EARN IF IT IS FLAT EVERY NIGHT? (PRE-REGISTRATION, 7 Nov 2026)

| | |
|---|---|
| Question | Run E's t3 set over the same four years, but flat at every day's end (DAY) or every week's end (WEEK): is there an edge once nothing is carried? |
| Why asked | The operator (7 Nov): the last test before the C162 memo; "it will also mean we have information that relates to the ftmo account where you are not allowed to carry risk overnight". E died on 4 Nov with 76% of its $500 day used by the book it carried into the day. |
| Status | **Pre-registered: this file is committed, and reviewed by Argon, before any line of the runner exists or any result is read.** Amended 7 Nov after Argon's review (`reviews/argon_review_nocarry.md` on `review/argon-nocarry`: SOUND WITH CHANGES; 190 quotes exact). |
| Bearing | C162. The continuous run (`research/longrun/results.md`) found no edge: OPT -$7,158, ALT +$800 after commission. This test closes the one door left open. |

## 1. ONE WORKED EXAMPLE (what a cut costs)

GBPUSD OPT (add = exit = 9 pips). At 23:44 server the short side holds three layers sold at 1.34500, 1.34590 and
1.34680; the ask is 1.34620. At 23:45 DAY closes all three at the ask: -12.0, -3.0 and +6.0 pips, so -9.0 pips
= -$0.90 less 3 x $0.06 commission = **-$1.08**, realised. No orders rest overnight. At 01:00 server the instance
starts again from flat, as on a fresh attach. In the continuous run those three layers would have been carried, and
the -12 pip layer was free to come back, or to be rolled 9 pips at a time if price kept rising.

## 2. THE ARMS

- **CONT (the control):** the longrun run unchanged (`run_bars.py --fill limit`). It must reproduce
  `research/longrun/out_limit/cont_<PAIR>.json` exactly (s5, check a).
- **DAY (flat every night):** on every weekday, at the first tick at or after **23:45 server**, the instance is cut
  (s3); it trades again from flat at the first tick at or after **01:00 server**. It is also flat before 01:00 on
  the run's first day and on the first day after a skipped week. Server midnight is the brokers'
  rollover (17:00 New York); 01:00 server is FTMO's day start (midnight Prague) in all but the few weeks a year
  when Europe and New York change clocks apart. So each FTMO day starts flat, and no swap is ever paid.
- **WEEK (flat every weekend):** the same cut on each week's last trading day only (Friday, or Thursday when Friday
  is a holiday), restart at 01:00 server on the next week's first trading day. This is FTMO's actual
  rule on a Standard funded account: positions closed before any break over two hours (FTMO's FAQ, read 7 Nov;
  the evaluation and the Swing account have no such rule). Overnight holding is allowed.
- Everything else as the longrun run: the six pairs, E's t3 presets, cap 7, deadband 2, lattice and re-roll on,
  0.01 lots, $0.06 a close, USD per pip as `run_bars.py`, the bars split into four ticks, holiday-short weeks
  skipped, from flat on 2 Jan 2023 to 23 Oct 2026. If a day's ticks end before 23:45 (an early close), the cut is
  at that day's last tick.

## 3. THE CUT (the only new mechanics)

At the cut tick, after the deals and close-bys already due have run:
1. Every resting order is removed (L0s, adds, exits, rolled exits): nothing can fill until the restart.
2. A layer whose exit has already dealt closes at its exit price, as a normal close (scalp or rolled).
3. Every other open layer closes at the cut tick's quote: a long at the bid, a short at the ask. Each is a
   **cut close**, $0.06 commission like any close.
4. Pending events and the close-by queue are cleared; every order is marked removed; each side's `l0`, `add`,
   `extreme` and `track_from`, and the instance's `busy` and `ent_sent`, are reset as on a fresh `Instance`
   (`sim.py`); both sides are empty. Between the cut and the restart no ticks reach the instance. `closes`, `rolls`
   and `seq` carry on.
5. **Sensitivity run:** each cut close's exit is 0.5 pip worse (a long at bid - 0.5 pip, a short at ask + 0.5 pip);
   nothing else changes, as the instance is flat until the restart.

## 4. WHAT IS MEASURED (written before the runner exists)

- Per pair, arm and grid (OPT, ALT): scalps, rolled closes, **cut closes**, roll steps (`rolls`), open at the end
  (zero for DAY and WEEK), commission, net (= the sum of those rounded parts); the number of cut closes and how many
  lost; the median signed cut close in pips (`sorted(v)[len(v) // 2]`, as `run_bars.py`) and the median dollar
  result per cut night; month-end series as the longrun run.
- **By FTMO day** (key `(t - 3,600,000) // 86,400,000` on server milliseconds: 01:00 to 01:00 server), **the twelve
  instances together** (E's account; this decides), and the six OPT and the six ALT apart (reported): the day's
  change in balance, and **the day's loss as FTMO counts it**: the balance at the day's start less the lowest
  equity in the day, equity = realised + open, **taken after every 15 s tick** (after its deals, fills or cut), a
  pair with no tick that minute holding its last value. (The five-minute marks would miss every bar's high and low;
  they are kept for check a and the month-end series only.) The count of days at **$500 or worse** and at $400 or
  worse (cents rounded); the worst ten days with dates. For CONT the carried book counts against the day, as for E.
- By calendar year (the change in year-end equity, realised + open after commission, from zero on 2 Jan 2023); the
  share of windows negative over the 46 month-end marks, `E[i] - E[i-k] < 0` as `results.md` s3 (45 single months,
  43 three-month, **34 twelve-month**); peak to trough of the month-end equity.
- **Sensitivity:** s3 step 5, through all four rules of s6 (the bars' spread field may understate the spread near
  the rollover).

## 5. SELF-CHECKS (run and reported BEFORE any result is read)

a. CONT reproduces the six `out_limit` files byte for byte (hashes in `research/longrun/MANIFEST.md`).
b. Unit tests on a synthetic tick stub, committed first and failing against a stub runner: the cut closes every
   layer at the right side of the quote; no order fills between cut and restart; a dealt exit at the cut is a
   normal close; the restart places a fresh L0 on the long side at its first tick and on the short side at the next
   (`sim.py` sends one entry a tick); every reset of s3 step 4; the FTMO-day loss of a hand-worked two-day example,
   with a low between two five-minute marks.
c. DAY and WEEK: zero layers and zero resting orders right after every cut (early closes included), at every
   five-minute mark in [23:45, 01:00) server taken after that night's cut, and no layer opened or closed strictly
   between a cut and its restart.
d. The accounting closes per instance: net = scalps + rolled + cut + open + commission as rounded, and within $0.02
   of the unrounded total.
e. One week by hand: the data's last week (**19-23 Oct 2026**), GBPUSD OPT: every cut close listed with its entry
   (time and price from that day's run), its exit and dollars checked against the 23:45 bar's open bid or ask.

## 6. THE DECISION RULE (DAY decides; fixed now)

**EDGE WITHOUT CARRY** only if DAY passes all four, the twelve instances together, after commission:
1. Net over the whole period above zero.
2. At least three of the four calendar years (2023, 2024, 2025, 2026 to 23 Oct) above zero.
3. Fewer than half of the twelve-month windows negative: **at most 16 of the 34** (s4).
4. **At most four FTMO days of $500 or worse** over the period (about one a year).

- Passes 1-3 but not 4: **EDGE, NOT FTMO-SAFE.** Fails any of 1-3: **NO EDGE**, and the C162 memo says the
  project stops.
- A pass that fails under the 0.5 pip sensitivity is reported **FRAGILE**, which the memo treats as NO EDGE.
- WEEK is judged by the same four rules and reported beside DAY; it does not decide. OPT and ALT are reported
  apart; the rule is on the twelve together, because that is the account E ran.

## 7. KNOWN BIASES (stated now, so they cannot be argued after)

- **Bars are not ticks:** limits fill at their own price; a cut closes at the 23:45 bar's open quote, with none of
  the seconds a live close of a dozen instances takes (the 0.5 pip sensitivity covers part of it).
- **No swap anywhere:** this flatters CONT and WEEK, which carry; DAY never pays swap, so the comparison is
  conservative against DAY.
- The bars' spread field may be the bar's lowest spread: the sensitivity covers the cut; it also flatters every
  fill, in all three arms alike.
- The FTMO day at 01:00 server is out by an hour for a few weeks a year (s2).
- A restart at 01:00 places fresh L0s straddling the price, so DAY trades the open of every day: if the first
  hour is costly, DAY pays it; that is the arm as an operator would run it.
- **Holiday weeks:** a week under 4,000 bars is skipped (`run_bars.py`), so CONT carries its book across it while
  DAY and WEEK are flat; a cut at an early close's last tick reads the day's end from the bar file, standing in for
  a known holiday calendar.
- **No rollover pause:** `sim.py` does not pause re-rolls in 23:50-00:15 server as the EA does
  (`Grind_LatticeRerollPaused`); this touches CONT and WEEK, which trade the rollover, not DAY.

## 8. ORDER OF WORK

1. This file, committed; Argon reviews it (a prompt on `main`); changes, if any, committed before step 2.
2. The tests (s5 b) in their own commit, failing against a stub.
3. The runner `research/nocarry/run_nocarry.py`, importing `sim.py` and `run_bars.py`'s loader unchanged; the cut
   lives in the runner, not in `sim.py`.
4. Self-checks a-e, committed with their output.
5. The result, read against s6, in `research/nocarry/results.md`; then the C162 memo, reviewed before any
   distribution.

Line count: 128
