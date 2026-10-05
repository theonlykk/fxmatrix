# research/ftmo_pass -- FTMO 2-Step pass probability (C124)

`docs/research/ftmo-pass-probability.md`. Read-only on the files; standard
library only (Python 3.9+).

    python -m unittest test_ftmo_pass          # 13 tests, hand-derived values
    python c124_run.py <Downloads folder>       # the day table and every number in the doc

Inputs in the folder: `history_<login>.csv` for 1514731800, 53066709,
53071896, 53077984 (`scripts/grind_history_dump.mq5`) and
`bidask_ftmo_2026-10-02/` (`grind_bidask_dump.mq5` on the desktop FTMO
terminal). First run 5 Oct ~17:40Z (seed 1; ~80 s).

- `ftmo_days.py`: per FTMO day (22:00Z-22:00Z) realised P&L, open MTM at
  the start and end, and the intraday low of equity minus the day-start
  balance (the daily-loss test).
- `ftmo_sim.py`: block bootstrap of those days through the Challenge
  (+1,000), the Verification (+500) and a funded account; drift and
  tail-day sensitivities; EV per attempt with and without a fee refund.
- `c124_run.py`: the evidence run (no tests, like `research/compass/d1_evidence.py`;
  it only calls the tested functions).
