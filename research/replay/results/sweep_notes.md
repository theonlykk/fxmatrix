# Geometry sweeps on the frozen harness (C147), 10 Oct

**Status: EXPLORATORY.** Not a plan 3 mark; nothing here changes plan 3. Plan 3
fits the replay at the LIVE geometries only (add 6-7, exit 9-11, cap 8); every
other geometry here is indicative (plan 3 s5). One week, one EURUSD path,
pre-holdout ticks only (`w2`, sha256 `db2ea941...`).

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
