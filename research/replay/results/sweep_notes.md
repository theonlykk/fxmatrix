# Geometry sweeps on the frozen harness (C147), 10-11 Oct

**Status: EXPLORATORY.** Not a plan 3 mark; nothing here changes plan 3. Plan 3
fits the replay at the LIVE geometries only (add 6-7, exit 9-11, cap 8); every
other geometry here is indicative (plan 3 s5). sweep1 and sweep2: one week,
one EURUSD path (`w2`, sha256 `db2ea941...`); sweeps 3-5 state their own data
below. Pre-holdout ticks only, in every sweep (nothing after 9 Oct 01:30 server).

**How it works:** no harness code changes. `sweep.py build` writes a
`run_<tag>.csv` (one row per geometry and window; empty seed and orders files
= flat start, as segment 20 of `run_eurusd_d.csv`; the other inputs as the
live rows since 7 Oct: width 2, stranded 3, deadband 2, re-roll on, gate 0).
The operator copies it into `D:\mt5-replay\MQL5\Files\replay` and runs
`tools\replay_run.ps1 -Mode Run -Tag <tag> -Label <tag>_free -Timing 1 -Sens base`
from the `replay-harness` checkout. `sweep.py score` reads the FREE events and
end book. Speed: about 3 s per day of ticks per geometry, plus about 15 s to
start the terminal. `sweep1` took 39 s and `sweep2` 395 s. Delete the
`*_timing.csv` afterwards (285 MB for `sweep1`).

**Metrics (pips at 0.01 lots, $0.10 a pip):**
- realised = the sum of SCALP_CLOSED exit - entry;
- open = the book at the window end, marked at the last tick (long at bid,
  short at ask);
- gross = realised + open;
- commission = 0.7 pip per close ($3.5 / lot / side);
- net = gross - commission;
- rho by counts (closed only, and with open losses as rolls in waiting, C141).

## sweep1: 5 / 5 / 8 and 7 / 10 / 8, flat at 01:00 and closed at 23:45 each day

| | net | gross | commission |
|---|---|---|---|
| 5 / 5 / 8 | -723 | -392 | 331 |
| 7 / 10 / 8 | -287 | -159 | 128 |

Both make money on 2 and 8 Oct and lose on 1, 5 and 7 Oct. Closing the book
every night books six open losses (9-11 layers each day), so rho with the open
book (0.78 / 0.80) is biased LOW. This run's "trending week" reading was
withdrawn after sweep2.

## sweep2: one flat start 1 Oct 04:00 server, the book carried to 8 Oct 23:45

- **Before commission, every geometry is near zero:** -319 to +94 pips over the
  week. By counts rho is 0.80-1.05 with the open book (1.0 on a random walk).
  The week is close to a random walk at these scales; e = 5 is lowest at add 6
  and add 7 (0.82, 0.80).
- **Commission decides the ranking:** net -643 (5 / 5 / 8) to -45 (7 / 10 / 10).
  The ranking is monotone in e at every add (e 10 > 7 > 5) and in add at
  e = 10. On a random walk, gross scalp pips per week ~ sigma^2 / D whatever e
  is, while closes ~ 1 / e. A larger e pays the per-close cost on fewer closes.
- **Roll closes cost more than D - e:** -40 a close at 5 / 5 / 8 (D - e = 35)
  and -50 at 7 / 10 / 8 (46), because of re-rolls (-80 / -110 closes) and the
  carry accrued on the exit. So the PIP break-even is above the formula's k*.
- **Cap:** N 10 vs 8 vs 6 at 7 / 10 nets -45 / -60 / -154. The 8 vs 10
  difference is inside one week's noise. The end-of-week open book alone varies
  89-300 pips between geometries.

**Not yet measured:** drawdown or equity swing per geometry (bigger D holds
more inventory); more weeks (the tick dump probe, C147 route); a shuffled
control.

## The staircase toy (`staircase/`, not the EA)

`stair.py` is a two-sided lattice on a made-up staircase (down L, up B,
repeated). It uses fixed levels, rolls the highest layer at market at the cap,
and charges 0.7 pip a close. Over six staircases (`rule_out.txt`), the best
depth N x a EQUALS the bounce B every time. The best exit is 0.55-0.70 B and
the finest add wins. When the drift per step equals the bounce, nothing works
(+82). With add >= 3 or >= 7 (`minadd_out.txt`) depth still equals the bounce
(5 / 15 / 4; 10 / 20 / 2). At add 7, 3 layers net +178 and 8 layers -358.
The toy is too regular (add 10 lines up with its lows), so read its
DIRECTION only: depth near the swing size, fewer layers for a bigger add.

## sweep3: nine pairs (input files only; harness 145f092)

**Fixed BEFORE any result was read:**
- **Grid:** add 2.5 / 5 / 7.5 / 10 x exit 2.5 / 5 / 7.5 / 10 x layers 6 / 8 / 10
  (48 a pair).
- **Pairs:** EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, NZDCHF, NZDCAD,
  AUDNZD.
- **Run:** one flat start 1 Oct 04:00 server, the book carried to 8 Oct 23:45.
  Width = the pair's live B width, stranded = width + 1.
- **Carry pass OFF** (no per-pair swaps). EURUSD adds two carry-ON controls.
- **Timing 0** (instant fills). Timing 1 writes GBs of timing.csv a pair.
- **Commission** = $0.06 a close (measured 0.03 a fill) / the pair's USD per
  pip at 0.01 lots (HANDOFF 2026-09-20).
- **Reading rule:** a setting counts only if it AND its neighbours net
  positive; a pair "has an edge" only if gross is positive over most of its
  surface; one week is a first look.
- **Mechanics:** the harness refuses any chart but EURUSD (safety check
  SAFE_S2). The other pairs' ticks run ON the EURUSD chart through the run
  file's `ticks_file`; pips come from the prices (valid), dollars from the
  per-pair pip value.
- **Ticks:** `grind_tick_dump` on wine-d, 11 Oct 01:44-01:48Z, 1 Oct 04:00 to
  9 Oct 01:30 server, all clean, hashed both ends (`inputs/sweep3.sha256`
  lists the run files; the tick hashes are in HANDOFF s79 continued 10).

**Controls (EURUSD):**
- **Carry off barely matters:** 5 / 5 / 8 nets -772 (off) vs -774 (on).
- **Timing 0 is PESSIMISTIC against timing 1:** 7 / 10 / 8 carry on nets -298
  at t0 vs -60 in sweep2 at t1 (commission 0.6 vs 0.7 aside), mostly more roll
  closes. Compare settings and pairs within sweep3; do not compare its
  absolute levels with sweep1-2 or with live.

**First two pairs (net pips, 10 layers; full tables in
`sweep3/report_<pair>.md`):**
- **EURUSD:** negative everywhere but the extreme corner (add 10, exit 7.5-10:
  +31 / +196), whose neighbours are negative. It fails the rule.
- **GBPUSD:** a broad positive plateau. Most cells with add >= 7.5 or
  exit >= 7.5 are positive at 6, 8 and 10 layers. 10 / 10 / 10 nets +1,085
  with 139 scalps and ZERO rolls (GBPUSD stayed inside 100 pips all week).
  This agrees with the live first look (GBPUSD the one pair above k* on B
  and D).

**Why two correlated pairs differ (`sweep3/pair_moves.py`):**
- Hourly-return correlation 0.87; similar numbers of 10-pip swings (134 vs
  160).
- Net moves differ: EURUSD -122, GBPUSD -41. EURUSD = EURGBP x GBPUSD, and
  EURGBP slid 66 pips smoothly (23 ten-pip swings).
- Correlation measures moving together hour by hour, not whether a small
  persistent difference adds up. In the lattice formula the penalty is
  (net move)^2: 122^2 is about 9 x 41^2.
- One week: next week the legs may swap.

**Prediction for EURGBP, recorded 11 Oct ~03:23Z BEFORE its result was read
(operator asked):**
- small adds clearly negative (shallow ladder vs a 66-pip slide);
- big adds with 10 layers near zero, possibly slightly positive at exit 5
  (deep enough to avoid rolls; it pays the end-of-week open loss);
- exit 10 weak everywhere (only 23 ten-pip swings);
- no broad plateau; around EURUSD, a little better for its cheap commission
  (0.45 pip).

**All nine pairs (11 Oct ~04:55Z; `sweep3/summary.md` from `summary.py`):**

| pair | net > 0 (of 48) | gross > 0 | pass neighbours rule | best (net pips, $ at 0.01 lots) | median net |
|---|---|---|---|---|---|
| GBPUSD | 33 | 44 | 21 | 10 / 10 / 10 +1,085 ($109) | +303 |
| NZDCHF | 40 | 48 | 26 | 2.5 / 7.5 / 10 +137 ($16) | +45 |
| NZDCAD | 28 | 40 | 15 | 5 / 7.5 / 10 +316 ($23) | +98 |
| AUDCHF | 20 | 25 | 6 | 7.5 / 10 / 10 +276 ($34) | -57 |
| CADCHF | 8 | 12 | 1 | 2.5 / 7.5 / 6 +109 ($13) | -125 |
| AUDCAD | 3 | 13 | 0 | 2.5 / 10 / 6 +42 ($3) | -186 |
| AUDNZD | 3 | 18 | 0 | 5 / 10 / 8 +38 ($2) | -201 |
| EURUSD | 2 | 2 | 0 | 10 / 10 / 10 +196 ($20) | -596 |
| EURGBP | 0 | 0 | 0 | 2.5 / 10 / 8 -45 (-$6) | -152 |

- **By the rule fixed before the run:** GBPUSD, NZDCHF and NZDCAD show an
  edge on this week (gross positive over most of the surface, many settings
  pass the neighbours rule). AUDCHF is borderline; the other five show none.
  One week only.
- **EURGBP prediction check:**
  - "No plateau, negative overall": RIGHT (0 of 48 positive).
  - "Small adds worst": RIGHT (down to -404).
  - "Big adds with 10 layers near zero, maybe positive at exit 5": HALF
    (-60 to -90, none positive).
  - "Exit 10 weak": WRONG (usually the least bad).
  - It was far milder than EURUSD (median -152 vs -596).
- **Net move does not explain the ranking** (`pair_moves.txt`, all nine):
  NZDCHF -46 and NZDCAD -51 were positive; AUDCAD +14 was negative. See the
  operator's point below.

**Operator, 11 Oct ~05:04Z: the start-to-end move is NOT a sole reliable
determinant of whether the grid makes money.** All nine pairs agree
(`sweep3/pair_moves.txt`). NZDCHF fell 46 pips and was positive in all 48
settings before commission; AUDCAD moved +14 and was mostly negative. The
clean-lattice formula's (net move)^2 term holds only with no cap. With a cap,
each roll pays for part of an excursion as it happens, so an excursion beyond
the ladder's depth costs money even if price later comes back. What also
counts: how far price wandered (NZDCHF and NZDCAD within 72-73 pips; EURUSD
176) against the depth, the chop inside that range, and each pair's
commission in pips.

## sweep4: eight earlier weeks (pre-registered 11 Oct ~15:10Z, before any run)

**Data:** one `grind_tick_dump` on wine-d (11 Oct from ~15:01Z, nine pairs,
3 Aug 00:00 to 1 Oct 04:00 server, tag `_h8w`; preset `tickdump_h8w.set`,
with InpSymbols and InpTo typed in after the preset load failed to set them).
One file a pair; the harness takes each week from it by the segment window.

**Runs (`run_sw4_<pair>.csv`, 112 segments a pair):**
- **Weeks:** Mon 3 Aug ... Mon 21 Sep (8). Each week has its own flat start
  (Mon 00:00 to Fri 23:45 server).
- **14 settings:** add 5 / 7.5 / 10 x exit 5 / 7.5 / 10 at 10 layers;
  7.5 / 7.5 and 10 / 10 at 6 and 8 layers; the pair's LIVE B geometry at cap
  8 as the control.
- **Otherwise as sweep3:** carry off, timing 0, the pair's live width,
  stranded = width + 1, commission $0.06 / pip value.
- **Why these settings:** sweep3's 1-8 Oct positives were at add / exit >= 7.5
  and 10 layers. These 8 weeks are OUT of sample for that choice and for the
  pair ranking.

**Questions and marks (fixed now):**
- **Q1, is a pair persistently positive?** For each pair-week, take the
  MEDIAN net of the 13 grid settings. A pair is persistently positive if its
  median is > 0 in at least 6 of 8 weeks, persistently negative if < 0 in at
  least 6 of 8, otherwise mixed.
- **Q2, does sweep3's top three hold?** GBPUSD, NZDCHF and NZDCAD each in the
  top half (top 4 of 9 by that week's median) in at least 5 of 8 weeks.
- **Q3, is any setting robust?** It is positive (net) in at least 6 of 8 weeks
  on at least 5 of 9 pairs.
- **Q4, does the control beat the grid?** The live geometry's weekly net
  against the grid median, per pair (reported, not marked).
- **INCONCLUSIVE** is the expected and acceptable outcome (operator): no pair
  persistently positive, the top three not holding, no robust setting.

**sweep4 RESULT (11 Oct ~18:00Z; `sweep4/marks.md` from `sweep4/analyse.py`,
tests first; the weekly nets in `sweep4/weekly_<pair>.csv`):**
- **Q1:**
  - EURGBP is PERSISTENTLY POSITIVE: the grid median was > 0 in 7 of 8 weeks,
    but small (+12 to +52 pips a week, $2-7 at 0.01 lots). On 1-8 Oct it was
    0 of 48 positive.
  - AUDNZD is PERSISTENTLY NEGATIVE: 0 of 8 weeks, -32 to -826 a week.
  - The other seven are MIXED (3-5 of 8).
- **Q2:** GBPUSD HOLDS (top half 5 of 8, the bare minimum); NZDCHF HOLDS
  (6 of 8); NZDCAD does NOT (4 of 8).
- **Q3:** NO robust setting. The best grid setting is positive in >= 6 of 8
  weeks on 3 of 9 pairs.
- **Q4 (reported):** the live geometry is not consistently better or worse
  than the grid median (better on 5 pairs, worse on 4, by 8-week sums).
- **Reading:**
  - The pair matters more than the setting. No setting generalises; two
    pairs behave consistently (one good, one bad), and the rest swing week
    to week.
  - EURUSD and GBPUSD have the SAME sign in all 8 weeks (+ + - - + + - -):
    the dollar leg decides whether both chop or trend in a given week.
  - EURGBP's small steady gain in Aug-Sep turned into its 1-8 Oct loss when
    it started to slide: persistence holds until it does not.
  - Mostly inconclusive, as the operator expected, with two informative
    exceptions (EURGBP, AUDNZD).

## sweep5: start FLAT every day, close at market every evening (pre-registered 11 Oct ~19:30Z, before any run)

The operator asked whether there is an edge in starting flat each day. sweep1
said no on EURUSD (one week, two settings).
- **Data:** the h8w ticks (sweep4), 40 trading days, 3 Aug - 25 Sep.
- **Each day** is its own flat start: 01:00 to 23:45 server, the book marked
  at market at 23:45.
- **Settings:** a5e5n10, a7.5e7.5n6, a7.5e7.5n10, a10e10n6 and a10e10n10 (all
  in sweep4's grid, so the comparison is direct), plus the pair's live B
  geometry. Timing 0, carry off, the pair's width, commission per pair as in
  sweep3 / sweep4.

**Marks (fixed now):**
- **D1, is daily-flat profitable on its own?** Per pair, the median over the
  5 grid settings of the 40-day total net. Report how many pairs are positive.
- **D2, does flattening every evening beat carrying the week?** Per pair,
  compare, for each (setting, week), the sum of the week's daily nets with
  sweep4's carried-week net (5 settings x 8 weeks = 40 comparisons).
  - Daily-flat is BETTER for a pair if it wins >= 26 of 40, WORSE if it wins
    <= 14, otherwise NO DIFFERENCE.
  - Verdict: the counts of pairs in each class. Daily-flat "beats carrying"
    if >= 5 of 9 pairs are BETTER and <= 1 is WORSE.
- **Reported:** the spread (standard deviation) of weekly totals, daily-flat
  against carried, per pair.

**sweep5 RESULT (11 Oct ~21:55Z; `sweep5/marks.md` from `sweep5/analyse.py`,
tests first; the daily nets in `sweep5/daily_<pair>.csv`):**
- **D1:** 0 of 9 pairs are positive over 40 days. The grid-median totals run
  from -79 (GBPUSD) to -2,119 (AUDNZD); the live geometry is negative on all
  nine.
- **D2:**
  - BETTER 2 (AUDCHF 31 of 40, AUDNZD 30), NO DIFFERENCE 1 (EURUSD 17),
    WORSE 6.
  - Daily-flat does NOT beat carrying the week. Even EURGBP and NZDCHF (both
    3 of 40) and GBPUSD (13) do better carried.
- **Reported:** flattening makes weekly totals STEADIER on 8 of 9 pairs (the
  weekly standard deviation is lower; EURGBP is the exception), but lower on
  average.
- **Reading:**
  - More than half the days win on EURUSD and GBPUSD (27 of 40), yet the
    totals lose. Many small winning days and fewer, larger losing days is a
    short-gamma profile.
  - Closing at market every evening turns the losers into realised losses
    before an overnight bounce can scalp them back. That helps only on the
    pairs that kept trending (AUDNZD, AUDCHF).
  - "The first day of an EA is always great" holds on most days, but not on
    the total. sweep1's EURUSD verdict holds across all nine pairs and eight
    weeks.

## sweep6: ADR-167's light-side add on the eight weeks (pre-registered 12 Oct ~05:15Z, before any run)

The operator (12 Oct ~03:00Z): "I want to see the harness results if we implement the layer
equalizing logic on the data we download. we have 8 weeks of data, let's see if it made a
difference."

**Build:** the replay experiment build of ADR-167 (branch `replay-adr167`, tip `ed5d052`;
`prompts/cursor_adr167_replay.md`): suite 493 / 493 (the operator's GUI compile); with no
table the twelve calibration runs equal `145f092`'s byte for byte (deals, orders, book;
events and summaries with `ea_time_ms` and `run_ms` masked; Claude's check). The table goes
in the run file's optional 24th column `light_add`. NOT plan 3's harness.

**Data and runs (as sweep4):** the h8w ticks, 8 weeks (Mon 3 Aug ... Mon 21 Sep), each week
its own flat start (Mon 00:00 to Fri 23:45 server); timing 0, carry off; each pair's live B
width, stranded = width + 1; commission $0.06 a close / the pair's pip value.
- **Settings (cap 8 only; the operator, 12 Oct: the cap stays 8):** the pair's live B
  geometry, a7.5e7.5n8 and a10e10n8 (all three in sweep4's grid).
- **Tables (ADR-167 3.3):** off; step `1;1;1;0.5`; linear
  `0.93;0.86;0.79;0.71;0.64;0.57;0.5`; dead zone + linear `1;1;0.9;0.8;0.7;0.6;0.5`.
- 3 settings x 4 tables x 8 weeks = 96 segments a pair (`inputs/sweep6/`, manifest
  `inputs/sweep6.sha256`; `sweep.py` `sw6_<pair>`, tests first).

**Marks (fixed now; `results/sweep6/analyse.py`, tests first, written before any run):**
- **C0, the control:** every off row must equal sweep4's weekly net for the same setting
  and week (`results/sweep4/weekly_<pair>.csv`). Any mismatch: STOP, no mark is read.
- **E1, per pair and table:** the weekly MEDIAN over the 3 settings of the paired
  difference net(table) - net(off). BETTER if > 0 in >= 6 of 8 weeks, WORSE if < 0 in
  >= 6 of 8, otherwise NO DIFFERENCE.
- **E2, per table:** HELPS if >= 5 of 9 pairs are BETTER and <= 1 WORSE; HURTS if >= 5
  WORSE and <= 1 BETTER; otherwise NO VERDICT.
- **Reported, never deciding:** the 8-week sum of the median difference; the standard
  deviation of weekly nets and the worst week, table against off; S and R totals.
- NO VERDICT is an expected and acceptable outcome.

**Claude's prediction, written before any run:** NO VERDICT for all three tables; the
weekly standard deviation lower with a table on most pairs and the worst week less bad
(the rule shrinks the net position: insurance, not edge); the step table the largest effect
either way; EURGBP and NZDCHF (add 3) the smallest differences.

**Limits:** one flat start a week (the book is never deeper than a week's moves); timing
0; carry off; geometries other than the live ones are indicative (plan 3 s5); the harness
runs every pair on the EURUSD chart (prices valid, dollars from the pip value).

**sweep6 RESULT (12 Oct ~19:10Z; `sweep6/marks.md` from `sweep6/analyse.py`; the weekly
nets in `sweep6/weekly_<pair>.csv`):**
- **Runs:** the operator's loop on `replay-adr167` (`ed5d052`), 12 Oct, nine pairs, 435-1,057
  s each, every `DONE` exit 0. AUDNZD's ticks came across zipped (159 MB timed out three
  times); sha256 starts `414dcaf1`, as recorded at the dump.
- **C0 PASSED:** all 216 off rows equal sweep4's weekly nets on all nine pairs. The
  comparison is valid.
- **E1:**
  - step: 7 NO DIFFERENCE, 2 WORSE (AUDCAD, NZDCAD), 0 BETTER;
  - linear: 7 NO DIFFERENCE, 2 WORSE (AUDCAD, CADCHF), 0 BETTER;
  - dead zone + linear: 8 NO DIFFERENCE, 1 WORSE (AUDCAD), 0 BETTER.
- **E2: NO VERDICT for all three tables.** No pair is better in 6 of 8 weeks with any table.
- **Reported:**
  - The 8-week sums of the median difference, summed over the nine pairs (pips, mixed
    pip values): step -679, linear -699, dead zone -540. AUDCAD carries the most (-248 to
    -411). EURUSD is the only pair positive in all three (+37 / +85 / +68), in 4 of 8 weeks
    each.
  - Scalps up 10-14% with a table, roll closes up 9-15%: the light side builds faster and
    rolls more; the extra scalps do not pay for the extra rolls.
  - The weekly standard deviation is lower with a table on 6 (step), 5 (linear) and 7
    (dead zone) of 9 pairs; the worst week is worse with a table on most pairs.
- **Claude's prediction against the result:** NO VERDICT for all three: RIGHT. A lower weekly
  sd on most pairs: RIGHT (5-7 of 9). A less bad worst week: WRONG (worse on most pairs).
  The step table the largest effect: WRONG (linear on AUDCAD). EURGBP and NZDCHF the smallest
  differences: HALF (EURGBP yes, NZDCHF no).
- **Reading:** in the replay, on these eight weeks, the equaliser does not make money and
  leans slightly against, mostly on AUDCAD. It steadies the weekly result a little on most
  pairs but does not soften the worst week. Limits as above (timing 0, carry off, weekly flat
  starts); not a plan 3 result.

## sweep7: ONE flat start, the book carried for eight weeks; live width and width 0.2 (pre-registered 12 Oct ~22:30Z, before any run)

The operator (12 Oct ~21:57Z): "i wouldn't mind seeing the results if we ran uniterrupted over
the 8 weeks - ie did not return to flat at the end of the week. can we do that with the current
ftmo build - and maybe your 0.2 width?" (The name sweep7 is reused: the earlier sweep7 idea, a
slower light side, was dropped by the operator ~21:55Z.)

**Build:** the replay build already compiled on `D:\mt5-replay` (`replay-adr167` `ed5d052`) with
NO table: it runs as `145f092` (R3's twelve byte-equal runs; sweep6 C0, 216 rows = sweep4). The
engine is the live EA's code (`5bb5fdb`). Input files only; no code change.

**Data and runs:** the h8w ticks (sweep4). Per pair ONE segment from **Mon 3 Aug 00:00 to Fri 25 Sep
23:45 server**, starting flat, the book carried through every weekend. Two settings:
- `live`: the pair's live B geometry exactly as sweep4's `live` row (add, exit, width; stranded =
  width + 1; cap 8; lattice, re-roll, gate 0, deadband 2; carry off; timing 0);
- `live_w0.2`: the same with width 0.2 on both sides, stranded 1.2, deadband 2 unchanged.
`sweep.py` `sw7_<pair>` (tests first, in their own commit: 4 failing, then the code; four mutants caught);
`inputs/sweep7/` (two rows a pair), manifest `inputs/sweep7.sha256`.

**Reported (never deciding; `results/sweep7/analyse.py`, tests first in their own commit, written before any run):**
- per pair and setting: S, R, A, realised, commission, the open book at the end, total net;
  requests (non-SEED place / modify / remove in the orders log, plus one close-by a close), per day
  over 40 days; the worst floating loss and the worst equity over the eight weeks, with the time;
- **Q1:** `live` carried eight weeks against the sum of sweep4's eight weekly `live` nets (flat every
  Monday);
- **Q2:** `live_w0.2` against `live`;
- the floating summed in dollars minute by minute (nine pairs, and A's seven), worst and minutes
  below -$250 / -$400.
- **Self-checks first (any failure: STOP, nothing reported):** each book rebuilt from the fill log
  equals the harness's end book; closes and realised equal SCALP_CLOSED (0.1 pip a close).

**Claude's predictions, written before any run:**
- Q1: no consistent sign: carried better on 4-5 pairs, worse on 4-5; the carried book's worst
  floating far deeper than any single week's (AUDNZD below -800 pips).
- Q2: S up and roll acceptances A down by a third or more on at least 7 of 9 pairs (the first
  order fills almost at once, so the book seldom sits at 8/0 under gate 0); R down; requests a day
  within +/-25% of `live` (more fills, the same re-quote rule); net with no consistent sign; the
  worst floating deeper on most pairs.
- Nine pairs summed: below -$250 for more than 10% of the minutes in `live`.

**Limits:** carry off (no swap history for Aug-Sep; a book held for weeks pays or earns swap that
is not counted); timing 0; A's float gate ($250) and breaker ($400) are NOT in the harness (the
summed path only shows where they would have cut in; the breaker works on a day's equity, not
floating); the width is SHARED with the flat start's two orders, so 0.2 also starts each flat book
tighter (C103's design narrows only the empty side's first order while the other side holds
layers); AUDCHF at B's width 1.5 (A's 1.0), as sweep4; every pair on the EURUSD chart (prices
valid, dollars from the pip value); one path.

**Runs (the operator, from `D:\fxmatrix`; about 3 s per day of ticks per setting: ~4-8 min a pair):**

    git checkout replay-adr167
    foreach ($p in 'eurusd','gbpusd','eurgbp','audcad','audchf','cadchf','nzdchf','nzdcad','audnzd') { powershell -ExecutionPolicy Bypass -File tools\replay_run.ps1 -Mode Run -Tag "sw7_$p" -Label "sw7_${p}_free" -Timing 0 -Sens base -SwapsSha dc7da509b35e6846f12f03692bf973632847ab3f2ad7dc865a93d91309f95b6c }
    git checkout main

**sweep7 RESULT (13 Oct ~01:40Z; `sweep7/marks.md` and `sweep7/summary.csv` from `sweep7/analyse.py`):**
- **Runs:** the operator's loop on `replay-adr167` (`ed5d052`, no table), 13 Oct ~00:24-01:02Z,
  nine pairs, 158-339 s each, every `DONE` exit 0. Ticks staged one file a call (all nine at full
  size; AUDNZD's sha256 starts `414dcaf1`, as at the dump).
- **A change to `analyse.py` AFTER the run, BEFORE any reported measure was computed:** the
  pre-registered self-check STOPPED on all 18 segments (`pop index out of range`). Cause, read in
  source: a fill's `layer_index` is the layer's NUMBER (a new layer is numbered max + 1 on its side,
  `Grind_SideNextIndex`, engine 2021-2032), not its position; the rebuild now keys each side's book
  by number (two tests first, both failing on the old rule; three new mutants caught). No measure,
  window or setting changed. Seen before the fix: the harness's own summary lines (S, R, A per
  segment). With the fix all 18 self-checks pass.
- **Q1, carried eight weeks against flat every Monday (live geometry):** carried is WORSE on 7 of 9
  pairs (GBPUSD -792 pips, NZDCAD -379, EURUSD -262, EURGBP -130, AUDCAD -94, AUDCHF -57, NZDCHF -8)
  and better on 2 (AUDNZD +188, CADCHF +136). In dollars at 0.01 lots, nine pairs: carried -$309,
  flat every Monday -$172. Carried, every pair has about twice the roll closes (R 49-90 against
  25-65) and fewer scalps on 8 of 9: a deep book keeps rolling, where a Monday start has runway on
  both sides. The carried books end with 9-15 layers open (-72 to -780 pips at the last mark).
- **Q2, width 0.2 against the live width (both carried):** nine pairs -$261 against -$309 (0.2
  better on 6 pairs, worse on 3: AUDCHF, NZDCHF, NZDCAD); requests a day within 10% on every pair;
  roll acceptances A almost unchanged (-1 to -11); R lower on 7. Worst floating deeper on 4, shallower
  on 5.
- **The nine pairs' floating summed, minute by minute:** worst -$497 (2 Sep 16:08 server) live,
  -$509 at 0.2; below -$250 for 71% of the 57,520 trading minutes (live; 73% at 0.2), below -$400 for
  4% (7%). A's seven: worst -$445, below -$250 for 44% of the minutes (53% at 0.2). A's float gate
  ($250 floating) would have held entries for much of that time: live A would not have traded these
  paths as the replay did.
- **Claude's predictions against the result:** Q1 "no consistent sign": WRONG (carried worse on 7 of
  9). AUDNZD the deepest floating, below -800: RIGHT (-1,430). Q2 "A down by a third or more on 7 of
  9": WRONG (A almost unchanged on all nine). R down: RIGHT (7 of 9). Requests within 25%: RIGHT.
  Net with no consistent sign: HALF (0.2 better on 6 of 9, small amounts). Worst floating deeper on
  most: WRONG (4 of 9). Nine pairs below -$250 more than 10% of the time: RIGHT (71%).
- **Reading (inferred, not measured):** with gate 0 the near-zero first short does not stop the
  rolls: in a fall it fills, scalps 10 pips lower and leaves, the book is back at 8/0 and the roll
  comes; the moderator still works. Width 0.2 changes little on this path, and costs no requests.
- **Limits:** one path; carry off (books held for weeks pay swap not counted here); timing 0; A's
  gate and breaker not modelled; the weekly-flat side's Friday marks pay no closing commission
  (about 0.7 pip a layer, roughly 50 pips a pair over eight weeks: small next to GBPUSD's -792);
  the carried result depends on where the run stops (a mark at 25 Sep 23:45, not a close).

**Correction (13 Oct ~02:40Z):** the rho tables in the sweep reports (`sweep.report`, from
`compare.rho`) count roll CLOSES; every sweep here ran with re-roll on, so they read too high.
Count roll STEPS: `docs/research/grid-edge-assessment-2026-10-12.md` s7; sweep7's by steps in
`sweep7/extras.md` (3). Backlog C151.

## sweep8: OPT against ALT out of sample (pre-registered 21 Oct ~18:15Z, before any run; HANDOFF s87 continued 2)

**The operator (21 Oct ~18:08Z):** could the replay show what A would have done with the ALT arm, and would
it have made money? Claude: not for A (FTMO's feed and seven pairs are outside plan 4's scope), and not on the
last two weeks: ALT's adds were FITTED on D's fills of 1-16 Oct (`research/alt_adds/results_2026-10-17.md`), so
that window flatters ALT. **The question asked instead (operator: "lets do your shorter question"; no Argon):**
on IC's EURUSD, over weeks ALT's fit never saw, does ALT produce more net pips than OPT at the live t1
geometries, and does it make money?

**Build:** the plan 4 harness `8044284` (`replay-plan4`; validated for count-level use on EURUSD at timing 1,
plan 4 s10), already on `D:\mt5-replay`. Input files only. `sweep.py` `sw8_<pair>` (tests first in their own
commit: 7 failing, 2 guards passing in both states; then the code; three mutants caught); `inputs/sweep8/`
(six run files and the sessions file), manifest `inputs/sweep8.sha256`.

**Data:** the h8w ticks (sweep4: wine-d, 11 Oct; 3 Aug 00:00 to 1 Oct 04:00 server; sha256 starts EURUSD
`10e95fec`, GBPUSD `d3c8c37a`, EURGBP `1de6ee93`, AUDCAD `a3791e0b`, AUDCHF `69b567b2`, CADCHF `6ff77bfa`).
Seen before by sweeps 3-7 (OPT-like geometries only); never by ALT's fit.

**Settings per pair, from the presets (a test checks each against `ea/presets_d` and `ea/presets_e`):**
`opt_t1` (D's OPT), `alt_q95` (D's and C's ALT), `alt_q90` (E's ALT); add = exit, cap 7, stranded = width + 1,
deadband 2, lattice and re-roll on, roll gate 0, carry OFF (no swap history for Aug-Sep), the sessions file
`sessions_eurusd_ic.csv` (24th column; F1). EURUSD 2 / 7, 7 / 27, 6 / 23; GBPUSD 2.5 / 9, 7.5 / 30, 6 / 24; EURGBP
1 / 3, 5 / 19, 4 / 16; AUDCAD 1.5 / 6, 7 / 27, 7 / 27 (q90 = q95 on AUDCAD: a free determinism check); AUDCHF 1 / 4,
5.5 / 22, 5.5 / 21; CADCHF 1 / 4, 3 / 12, 2.5 / 9 (width / add = exit).

**Segments per pair (27):** each setting x (eight weekly flat starts, Mon 00:00 to Fri 23:45 server, Mon 3 Aug
... Mon 21 Sep) + one carried window (flat at Mon 3 Aug 00:00, carried to Fri 25 Sep 23:45). Timing 1, Sens base,
FREE (no sync).

**Measures (from `sweep.py score`, unchanged; pips at 0.01 lots):** per segment S (scalps), R (roll closes), A
(roll acceptances = roll steps), realised, commission (0.06 USD a close / the pair's pip value), the open book at
the end marked at the last tick, **net = realised - commission + open**. Scalps per roll STEP = S / A (not S / R:
re-roll inflates R, C151).

**Decision rules, EURUSD (deciding), from the eight weekly nets only:**
- **Q1, ALT against OPT:** `alt_q95` BETTER if its eight-week sum exceeds `opt_t1`'s AND it is ahead in 6 or more
  of the 8 weeks; OPT BETTER if the mirror; else NO DIFFERENCE SHOWN. The same rule reported for `alt_q90`.
- **Q2, does ALT make money:** YES if `alt_q95`'s sum > 0 AND 6 or more weeks > 0; NO if its sum < 0 AND 6 or more
  weeks < 0; else NOT SHOWN. Reported for `alt_q90` and `opt_t1` too.
- Eight weeks decide little (6 of 8 is a one-sided sign-test p of about 0.14): a BETTER or YES is a lean, to be
  confirmed by ALT's live weeks, not a ruling.

**Reported, never deciding:** the carried window per setting (net, open book at the end); OPT + ALT summed per
week (D's arrangement); S / A per setting; the other five pairs under the same rules (indicative: outside plan
4's scope). **Not reported as a result:** dollars for A or E (FTMO's feed).

**Self-checks first (any failure: STOP, nothing scored):** each run `exit=0`; its log's `RPL|RUN|` and `RPL|TIMING|` lines read against
the label (sync off, timing 1; as plan 4's runs, HANDOFF s86 continued 9), `RPL|SESSIONS|sessions_eurusd_ic.csv|5`,
`RPL|TICKS_LOADED|ticks_53077984_<PAIR>__h8w.csv`, gaps 0, aborted 0; the run files
equal `inputs/sweep8.sha256`; AUDCAD's `alt_q95` and `alt_q90` segments identical.

**Claude's predictions, written before any run:** (1) EURUSD gross (before commission) near zero for all three
settings over the eight weeks (sweep2 and sweep4: a near random walk at these scales); (2) commission decides the
sum, so `alt_q95` > `opt_t1` summed (ALT closes about a quarter as often), but ahead in only 4-5 weeks: **Q1 NO
DIFFERENCE SHOWN**; (3) **Q2 NOT SHOWN** for ALT (3-5 weeks positive), NO or NOT SHOWN for OPT; (4) S / A within
+/-30% between OPT and ALT (both near N - 1 = 6 on a random walk at add = exit, cap 7); (5) ALT's open book at a
week's end larger in pips than OPT's in most weeks.

**Limits:** carry off (ALT holds layers longer: swap under-counted against ALT); P&L is not a plan 4 mark (plan
4 validated counts; D long's whole-segment rho was off, 1.85 / 1.63); ALT at 23-30 pips is outside plan 4's
tested geometries (a guide); IC's feed only; every pair on the EURUSD chart (prices valid, dollars from the pip
value); weekly flat starts (live D carries its book); one path per week.

**Runs (the operator, from `D:\fxmatrix` detached at `8044284`, the run files in `D:\mt5-replay\MQL5\Files\replay`;
swaps.csv is the window set's, `581dab22...4c2a`, unused with carry off):**

    git checkout --detach 8044284
    foreach ($p in 'eurusd','gbpusd','eurgbp','audcad','audchf','cadchf') { powershell -ExecutionPolicy Bypass -File tools\replay_run.ps1 -Mode Run -Tag "sw8_$p" -Label "sw8_${p}_free" -Timing 1 -Sens base -SwapsSha 581dab2282484cefd90c56f2d8a7844d11e4070115677e9bac6820c980064c2a }
    git checkout main

**AMENDMENT (21 Oct ~19:20Z, the operator's choice (a); written after the EURUSD run's log was read and BEFORE any
net was computed):** the self-check STOPPED on `gaps=1` in six of EURUSD's 27 segments (the week of 21 Sep and the
carried window, every setting): one hole in the h8w ticks, `RPL|GAP|1790210065409|581` = no tick from Thu 24 Sep
00:34:25 to 00:44:06 server (Wed 23 Sep 21:34-21:44Z); the harness reports a weekday gap over 60 s outside 00:00-00:15
server and does not abort or alter the simulation (`fxgrind_replay_core.mqh` 2899-2915 at `8044284`). The same data
sweeps 4-7 used. **Disclosed: the log's `SEG_DONE` lines print each segment's counts (scalps, roll closes, roll
acceptances); Claude read them before this amendment; no net was computed.** The operator: "it seems harsh to reject 8
weeks of data due to a 10min gap". **Amended rules:** the gap is accepted and reported; week 8 and the carried window
are flagged. Q1 and Q2 are decided as pre-registered on the eight weeks AND, by the same rules, on the seven clean
weeks (3 Aug - 18 Sep) with 5 of 7 in place of 6 of 8; **if the two answers differ, the answer is NOT SHOWN.** The other
pairs' gaps, if any, are reported the same way. Prediction (4), S / A within +/-30%, is recorded FAILED (undefined):
the counts show A = 0 in every weekly ALT segment.
