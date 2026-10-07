This message has a line count at the bottom

# research/compass -- compass rounds (cycle-4 note s8.4-8.5; fleet-d.md s6)

Read-only analysis of files; standard library only (Python 3.9+). Reuses
the ejection study's loaders and layer builder (`research/ejection_value`,
replay v1: imported, never changed).

## d1_evidence.py -- the numbers behind D1's directions

    python research/compass/d1_evidence.py --export <study_export.jsonl> --bars-ic <wine-c bidask dir>

Inputs as for the ejection study (its README): `--export-study --days 14`
and `grind_bidask_dump.mq5` on wine-c (IC; B shares the server).
1 Oct run: export `study_export_1001early.jsonl` (sha256
`dde95342e203335b`) and `bidask_ic_0930.tar.gz` (24 Sep 00:00 server ->
30 Sep 15:40Z). About 2 s.

- Part 1: closed net per instance side on A, B, C, 28 Sep 00:10Z ->
  30 Sep 22:00Z, by close time; B1's step vs the same-settings gap
  |B - C|; twins OPT - ALT. Cross-check: ledger scalps vs
  `scalp_history` (1 Oct: A 410/410, B 491/491, C 480/478).
- Part 2: first-order harvest of a ladder at the anchor add on IC's
  bid/ask, exit X-1 / X / X+1, per side, net of $0.07. No cap, depth or
  lattice.

No unit tests: a one-off evidence run whose numbers are quoted in
`fleet-d.md` s6.0 (E5-E7).


## compass_score.py -- scoring a round (backlog C91)

    python research/compass/compass_score.py --export <study_export.jsonl> [--export ...] --round research/compass/round1.json
    python -m unittest research/compass/test_compass.py -v

Rules: `fleet-d.md` s6.5 as amended by s6.8 (module docstring has them in
full). The round file (`round1.json`) holds the accounts, the windows
(FTMO days, 22:00Z to 22:00Z; days counted explicitly so weekends never
count), the threshold (pooled $1.19; AUDNZD long twin $1.40), the probe
table and each probe's reload time (= its register row; a GUARD test
checks it). A repeated probe is scored over ALL its rounds: give the next
round's file every window so far.

**Cuts (3 Oct, operator; Gemini GC-4 amended):** `interventions` lists
side-specific hand interventions (pair, side, fleet, at). Each comparison
(probe fleet vs its comparator's fleet) is scored only on the windows before
the first intervention on either fleet for that pair-side, if at least
`min_days_after_cut` (1.0) days remain, else VOID; the table's anchor column
stays the whole round. Fleet-wide changes made alike on all fleets are not
listed. Round 1: NZDCHF long B and C, AUDCHF long C (window 1, 2 Oct
02:26-03:52Z), so NZDCHF long (both) and AUDCHF long (C) are VOID.

**Reported, never deciding (3 Oct, runbook s1):** `--bidask <folder>`
(`grind_bidask_dump.mq5`; IC's from wine-c for the IC fleets) adds open MTM
per instance side: the peak (most negative, with its minute) and the value
carried at each window's end (the 22:00Z day-roll); longs at the bid close,
shorts at the ask close; USD per pip = median |closed profit| / pips of the
symbol's closed layers (gt_report.py's method). `disconnects.py <journal
logs>` lists each "connection to ... lost" until "authorized on" / "terminal
synchronized" (`<data>/logs/YYYYMMDD.log`, UTF-16), per terminal.

**Threshold, both reported (s49; compass-round s4.3, GC-1):** with a
`control` block in the round file (round 1: NZDCAD = B's anchor and C's and
D's primaries), the report adds `control_threshold`: the control pair's six
same-settings gaps (|per day x - per day y|, B-C, B-D, C-D, both sides; a gap
cut below `min_days_after_cut` is VOID and left out), GC-1 = max(threshold,
their median), and, when GC-1 is higher, the whole verdict table again under
it. For round 1 the operator chooses which table decides; from round 2 GC-1
does. Provisional run on the 2 Oct export (data to Fri 20:20Z, per-day
values halved): GC-1 2.41 (NZDCAD long gaps 4.58 / 8.77 / 4.19, short 0.00 /
0.63 / 0.63).

Run it after the round's last window closes (round 1: Mon 5 Oct after
22:00Z) on a fresh `--export-study --days 14`; it prints a warning and
no verdict is final while the export ends before the round does.

44 + 4 tests, hand-derived (9 for the control threshold, 3 Oct night: 8 failed as predicted at the tests-first commit, the guard passed; eleven mutations caught); (6 for open MTM in test_compass.py and 4 in test_disconnects.py, 3 Oct; 12 for the cuts, 3 Oct: 9 of the first 10 failed as predicted at the tests-first commit, then two more for mutation survivors); at the tests-first commit 16 errored as predicted
and the guard passed. Each rule broken once and caught by a named test
(strict margin, add-only gates, entry gate, per-hour gate, a comparator
that held nothing, twin vs primary, twin threshold, entry cutoff, hours
clipped, weekend closes, promotion by the larger margin, accounts
filter, side filter, per-day divisor). Cross-check: on 28-30 Sep it
reproduces `d1_evidence.py`'s ledger totals exactly (AUDCHF S B/C,
EURGBP L B, GBPUSD L A).

## equity_score.py -- a round decided on EQUITY (from round 2)

    python research/compass/equity_score.py --export <archive export.jsonl> --round research/compass/round2.json --bidask <IC bid/ask folder>
    python -m unittest research/compass/test_equity_score.py -v

Operator 7 Oct ~14:53Z (`docs/research/compass-equity-amendment.md`): under
re-roll the timing of a realised loss is set by each fleet's inherited book,
so from round 2 a probe is decided on the equity of its COHORT (Gemini GQ7-3,
~15:07Z): the layers opened inside the round, their costs and closes plus the
mid mark at the round's end (`equity_end` in the round file; round 2: Thu 8
Oct 22:30Z, the round moved to start at the 7 Oct build). Plain equity (all layers, start and end marks) and realised
(`compass_score.py`) are printed beside it, with cohort equity per layer-hour.
GC-1 from the control's cohort gaps; no add-probe gates; UNPRICED when a marked
layer has no open price (use `--export-archive`). 23 tests, hand-derived (E1-E13
plain equity, then C1-C9 and E14 for the cohort, each set failing at its
tests-first commit; E12 the guard that compass_score is unchanged); fifteen
mutations caught on the cohort code. Run mutation rounds with
PYTHONDONTWRITEBYTECODE=1 and `python -B` (traps 7 Oct: a stale .pyc).

## fill_slippage.py -- fill slippage of entry limits (backlog C132)

    python research/compass/fill_slippage.py --export <study_export.jsonl> --round research/compass/round2.json [--baseline research/compass/round1.json] [--fleets BCD] [--below -5]
    python -m unittest research/compass/test_fill_slippage.py -v

Gemini GR2-4's missing fact (compass-round2-review s6), REPORTED at a round's
scoring, never deciding. Per pair, side and fleet, entry fills (fill_logs ENT /
IN) inside the round's windows: n, mean and median `slippage_pips`, share worse
than the limit, share worse than half a pip, the worst; a fleet total; every
fill worse than `--below` listed with its deal and order tickets. The number
is the EA's own (`grind_archive.mqh` 425-434, test AR12): POSITIVE = better
than the limit. Fill time = `deal_time_broker_msc` - 3 h (server GMT+3 until
1 Nov). A (FTMO) is left out unless `--fleets` names it (holdout, criteria s6).
10 tests, hand-derived (SL1-SL8 failed at the tests-first commit as
predicted; SL9-SL10 added for the two survivors of a fifteen-mutation round;
then all fifteen caught).

Round 1's windows on `study_2026-10-05_14d.jsonl`: median 0.0 on B, C, D;
mean +0.12 / +0.15 / -0.01; 17-23% of fills worse than the limit, 1-2% by
more than half a pip. Three fills worse than 5 pips, all at a liquidity
moment: AUDNZD L D -14.1 and EURUSD S B -6.7 at 12:30:09Z Fri 2 Oct (US
payrolls), AUDNZD L D -36.6 at 21:01:00Z Mon 5 Oct (IC's rollover hour).

Line count: 128
