This message has a line count at the bottom

# GEOMETRY REGISTER -- EVERY WIDTH / ADD / EXIT / CAP WE TRY, BY PAIR AND DATE

Operator, 29 Sep: "keep track of all the add/exit pips we try out, the
date and the fx pair, so we can assess stability."

**The register is `docs/research/geometry_register.csv`** (one row per
instance per interval of constant geometry; opens in Excel or pandas).
This file holds the rules and a readable view of what is live now.

## RULES

- **Every change to width, add, exit or cap on any live instance gets a
  row, in the same docs patch that records the reload:** close the old
  row (`to_utc` = the reload time from the Experts log, UTC) and open a
  new one (`from_utc` = the same time). A reload that changes nothing
  else (a reattach, a key rotation, a compile) gets NO row.
- Times come from the log or the fleet doc's record, not from memory;
  an approximate time is written `approx` in `note`.
- `side` is `both` while long and short are equal. When per-side inputs
  (v2.0) differ, write one row per side (`long`, `short`).
- `preset_commit` = the commit whose preset was loaded. Never edit a
  closed row; correct it with a note.
- Stability is assessed by joining archive scalps (`scalp_history`:
  instance, close time) to these intervals: scalps per hour, pips and
  USD per geometry, per pair, across fleets and weeks. Cycle 2 (10-23
  Sep, FTMO 1514582088) is NOT in the register yet: its presets are in
  the git history of `ea/presets` (e.g. `e1efa23` 19 Sep), live times
  unverified; backfill only if needed.

## LIVE NOW (1 Oct ~06:50Z; width / add / exit pips, cap 8 everywhere)

| pair | A: cycle 3 (FTMO) | B: wine-test (anchor) | C: wine-c (ADD probe, D1) | D: wine-d (EXIT probe, D1) |
|---|---|---|---|---|
| GBPUSD | 5 / 10 / 10 | 5 / 9 / 10 | 5 / 8 / 10 | 5 / 9 / 9 |
| EURUSD | 7 / 8 / 10 | 7 / 7 / 10 | 7 / 6 / 10 | 7 / 7 / 9 |
| EURGBP | 3 / 4 / 5 | 3 / 3 / 5 | 3 / 4 / 5 (floor: +1) | 3 / 3 / 4 |
| AUDCAD | 5 / 7 / 10 | 5 / 6 / 10 | 5 / 5 / 10 | 5 / 6 / 9 |
| AUDCHF | 5 / 6 / 10 | 5 / 4 / 10 | 5 / 3 / 10 | 5 / 4 / 9 |
| CADCHF | 5 / 6 / 10 | 5 / 4 / 10 | 5 / 3 / 10 | 5 / 4 / 9 |
| NZDCHF | 3 / 6 / 10 | 3 / 3 / 10 | 3 / 4 / 10 (floor: +1) | 3 / 3 / 9 |
| NZDCAD (OPT) | 5 / 10 / 10 | 5 / 8 / 10 | 5 / 8 / 10 (anchor) | 5 / 8 / 10 (anchor) |
| NZDCAD (ALT dup) | 5 / 10 / 10 | 5 / 10 / 10 (control) | 5 / 7 / 10 (probe) | 5 / 8 / 9 (probe) |
| AUDNZD (OPT) | 7 / 10 / 10 | 7 / 8 / 10 | 7 / 8 / 10 (anchor) | 7 / 8 / 10 (anchor) |
| AUDNZD (ALT dup) | 7 / 10 / 10 | 7 / 10 / 10 (control) | 7 / 7 / 10 (probe) | 7 / 8 / 9 (probe) |

History: Fleet B ran A's geometry from 24 Sep ~02:50Z until the B1
reloads (27 Sep 23:05-23:51Z). C matched B from 28 Sep until the D1
reloads (1 Oct 06:45:12-06:49:39Z); D ran the anchor from its attach (1 Oct
05:10-05:19Z) until the D1 reloads (06:19:13-06:35:12Z). The first EXIT
change anywhere is D1 on D (the first live ADR-163 rebuild).

## NEXT EXPECTED ROWS

The D1 round's verdict (after Mon 5 Oct 22:00Z; fleet-d.md s6.5): an
anchor move on B, flips or repeats on C and D, each a row. Then the
rings of seven (C96: twins removed, a pair dropped per fleet: rows
closed) and cap 10 on the IC fleets (C99: a cap change, so a row for
every instance). The 1 Oct `InpBreakerEnable=false` change on B, C, D
is not geometry and has no row (fleet-d.md s7). Nor does the 2 Oct 02:55-03:05Z `InpStrandedThreshPips` = width + 1 change on all 33 IC charts (empty-side L0 re-quote; deadband 4 kept; fleet-d.md s7): the L0 width itself is unchanged.

Line count: 63
