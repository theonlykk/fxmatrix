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

## LIVE NOW (round 2 from 6 Oct 03:18-03:35Z; width / add / exit pips, "L / S" where the sides differ; cap 8 everywhere; deadband 2 and S = W + 1 on B, C, D)

| pair | A: cycle 3 (FTMO, frozen) | B: wine-test (anchor) | C: wine-c (ADD probe) | D: wine-d (EXIT probe) |
|---|---|---|---|---|
| GBPUSD | 5 / 10 / 10 | 2.5 / 9 / 10 | 2.5 / 8 / 10 | 2.5 / 9 / 9 |
| EURUSD | 7 / 8 / 10 | 2 / 7 / 10 | 2 / 6 / 10 | 2 / 7 / 11 |
| EURGBP | 3 / 4 / 5 | 1 / 3 / 5 | 1 / 2.5 L, 4 S / 5 | 1 / 3 / 6 L, 4 S |
| AUDCAD | retired 2 Oct | 1.5 / 6 / 10 | 1.5 / 5 / 10 | 1.5 / 6 / 9 |
| AUDCHF | 5 / 6 / 10 | 1 / 4 / 10 | 1 / 3 / 10 | 1 / 4 / 9 |
| CADCHF | 5 / 6 / 10 | 1 / 4 / 10 | 1 / 3 / 10 | 1 / 4 / 11 L, 9 S |
| NZDCHF | retired 2 Oct | 1 / 3 / 10 | 1 / 4 / 10 | 1 / 3 / 9 |
| NZDCAD (control) | 5 / 10 / 10 | 2 / 8 / 10 | 2 / 8 / 10 | 2 / 8 / 10 |
| AUDNZD | 7 / 10 / 10 | 2 / 8 / 10 | 2 / 7 / 10 | 2 / 8 / 9 |

The six IC twins retired 5 Oct (B 23:08Z, C 22:48Z, D 22:20Z). Round 1's
table (1 Oct ~06:50Z) is in the CSV's closed rows. pipshed's geometry
table (C129) shows the same from the heartbeats.

History: Fleet B ran A's geometry from 24 Sep ~02:50Z until the B1
reloads (27 Sep 23:05-23:51Z). C matched B from 28 Sep until the D1
reloads (1 Oct 06:45:12-06:49:39Z); D ran the anchor from its attach (1 Oct
05:10-05:19Z) until the D1 reloads (06:19:13-06:35:12Z). The first EXIT
change anywhere is D1 on D (the first live ADR-163 rebuild).

## NEXT EXPECTED ROWS

**Wed 7 Oct build (HANDOFF s64): NO rows.** The roll gate (`InpRollGateOpposite=0`) and the v2.2a API inputs are not geometry; the regenerated `_r2` presets carry them with the same width / add / exit / cap, so the round-2 rows stay open (their `preset_commit` stays `b438420`, the geometry loaded 6 Oct).
**6 Oct 03:18-03:35Z (HANDOFF s61): round 2's rows are open** (30: 27
instances, three split per side). Before: the six twins' rows closed 5 Oct. Planned then:
Tuesday 6 Oct's round-2 reload on B, C, D: a row for every instance
(27; per side where add or exit differ) from `ea/presets_{b,c,d}/*_r2.set`
(`5e7a412`; `646a387` before `git am`; loaded: `b438420`), with the tight widths (GBPUSD 2.5, EURUSD / NZDCAD / AUDNZD
2.0, AUDCAD 1.5, the rest 1.0); deadband 2 is a note, not a row. Cap 10,
the fixed widths and AUDUSD are deferred (memo 2026-10-05); the text
below is as written before that.

The D1 round's verdict (after Mon 5 Oct 22:00Z; fleet-d.md s6.5): an
anchor move on B, flips or repeats on C and D, each a row. The Monday
build (5 Oct after 22:00Z) retires the six IC twins (NZDCAD and AUDNZD
ALT on B, C and D): their rows closed at each removal time from the
log. Then cap 10 with the width fixed per pair (C99; compass-round s6)
in one reload per chart: a row for every instance, including the
AUDUSD scout's first rows on B, C and D (magic 22261001, baseline
2 / 6 / 10 at cap 10, presets `4694471`; compass-round s3). **The IC rings of
seven (AUDCAD and NZDCHF dropped) were WITHDRAWN 3 Oct: IC keeps the
nine pairs (C96; compass-round s3).** The 1 Oct `InpBreakerEnable=false` change on B, C, D
is not geometry and has no row (fleet-d.md s7). Nor does the 2 Oct 02:55-03:05Z `InpStrandedThreshPips` = width + 1 change on all 33 IC charts (empty-side L0 re-quote; deadband 4 kept; fleet-d.md s7): the L0 width itself is unchanged. **2 Oct: FTMO (A) retired GRIND_AUDNZD_ALT, GRIND_NZDCAD_ALT (15:14Z), GRIND_AUDCAD_OPT and GRIND_NZDCHF_OPT (~15:40Z); rows closed in the CSV; A runs seven (geometry-cycle3 A7). The table above marks them retired.**

Line count: 80
