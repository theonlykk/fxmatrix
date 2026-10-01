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
`fleet-d.md` s6.0 (E5-E7). The round's SCORING code (next, tests first)
will live here too.

Line count: 31
