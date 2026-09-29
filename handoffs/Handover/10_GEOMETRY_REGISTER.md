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

## LIVE NOW (29 Sep; width / add / exit pips, cap 8 everywhere)

| pair | A: cycle 3 (FTMO) since 24 Sep | B: box 1 (IC) | C: box 2 (IC) since 28 Sep |
|---|---|---|---|
| GBPUSD | 5 / 10 / 10 | 5 / 9 / 10 (B1, from 27 Sep 23:05Z) | 5 / 9 / 10 |
| EURUSD | 7 / 8 / 10 | 7 / 7 / 10 (B1) | 7 / 7 / 10 |
| EURGBP | 3 / 4 / 5 | 3 / 3 / 5 (B1) | 3 / 3 / 5 |
| AUDCAD | 5 / 7 / 10 | 5 / 6 / 10 (B1) | 5 / 6 / 10 |
| AUDCHF | 5 / 6 / 10 | 5 / 4 / 10 (B1) | 5 / 4 / 10 |
| CADCHF | 5 / 6 / 10 | 5 / 4 / 10 (B1) | 5 / 4 / 10 |
| NZDCHF | 3 / 6 / 10 | 3 / 3 / 10 (B1) | 3 / 3 / 10 |
| NZDCAD (OPT) | 5 / 10 / 10 | 5 / 8 / 10 (B1) | 5 / 8 / 10 |
| NZDCAD (ALT dup) | 5 / 10 / 10 | 5 / 10 / 10 (control) | 5 / 10 / 10 |
| AUDNZD (OPT) | 7 / 10 / 10 | 7 / 8 / 10 (B1) | 7 / 8 / 10 |
| AUDNZD (ALT dup) | 7 / 10 / 10 | 7 / 10 / 10 (control) | 7 / 10 / 10 |

Fleet B ran A's geometry from 24 Sep ~02:50Z until the B1 reloads
(27 Sep 23:05-23:51Z); the two ALT duplicates never changed (same-account
controls). So far only ADD has been varied; every exit is still the
cycle-3 value.

## NEXT EXPECTED ROWS

C63 (Thursday) changes no geometry: code and lattice only, so no rows.
The first new rows come with the compass rounds (cycle-4 note s8.4-8.5)
and box 3 (Fleet D).

Line count: 59
