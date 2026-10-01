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

Run it after the round's last window closes (round 1: Mon 5 Oct after
22:00Z) on a fresh `--export-study --days 14`; it prints a warning and
no verdict is final while the export ends before the round does.

17 tests, hand-derived; at the tests-first commit 16 errored as predicted
and the guard passed. Each rule broken once and caught by a named test
(strict margin, add-only gates, entry gate, per-hour gate, a comparator
that held nothing, twin vs primary, twin threshold, entry cutoff, hours
clipped, weekend closes, promotion by the larger margin, accounts
filter, side filter, per-day divisor). Cross-check: on 28-30 Sep it
reproduces `d1_evidence.py`'s ledger totals exactly (AUDCHF S B/C,
EURGBP L B, GBPUSD L A).

Line count: 57
