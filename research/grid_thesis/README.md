This message has a line count at the bottom

# research/grid_thesis -- grid-thesis measurements and backlog analyses

What: `docs/research/grid-thesis.md` s11 (M1-M7) and backlog C4, C10, C26,
C49, from the pipshed study export and the bid/ask dumps. Read-only
analysis of files; standard library only (Python 3.9+). Reuses the
ejection study's loaders and layer builder (`research/ejection_value`,
replay v1: imported, never changed).

## Run

    python research/grid_thesis/gt_report.py --export <study_export.jsonl> --bars-a <FTMO dump dir> --bars-ic <IC dump dir>
    python -m unittest research/grid_thesis/test_gt.py -v

Inputs are the ejection study's (its README): `--export-study --days 14`
and `grind_bidask_dump.mq5` from 24 Sep on the desktop FTMO terminal (A)
and on wine-c (IC; fleet B is priced from wine-c's dump, same server).
The surrogate and offset draws are seeded (`--seed`, default 20260930):
the same files give the same output. 30 Sep evening: 12 s.

## What each section is

| section | what | caveat |
|---|---|---|
| C10 | swap booked on closed positions + accrued on the open book (latest CARRY_SNAPSHOT), per day | tonight's pending not included |
| C4 | scalps and ejections by side, swap per side | `gross_pnl` already includes swap |
| C26 | carry-pass counts per night (eligible, shifted, clamped, failed) | a failure's cause needs `send_logs` (C60, C87) |
| M1 | deepest layer per side episode (flat to flat) | episodes open at the window end included |
| M2 | scalps per ejection; worst 4-hour run of ejection losses | |
| M3 | closed net per layer-day held | one week |
| M4 | deep episodes (depth >= 6): closed net vs peak open loss | open MTM on M1 bid/ask, pip value from the ledger |
| M7 | peak open loss by deepest layer; adverse move from L0 vs room to cap | |
| C49 | deep adds by time since the previous fill on the side | outcome of the layer, not of the side |
| M5 | zigzag legs per trading day at 5/10/20 pips; longest leg without a 10-pip retrace | FTMO prices |
| M6 | cycles per level on the real path vs 60-minute-block surrogates; busiest-level share in deep episodes vs chance | low power on one week |

Line count: 38
