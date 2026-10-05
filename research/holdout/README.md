# research/holdout -- the C125 holdout verdict (V) and T3 (money)

`docs/research/holdout-verdict-criteria.md` s2 (T3a, T3b, T3c) and s5.
Read-only; standard library; reuses `research/compass/compass_score.py`
(`load`, `side_metrics`) and `research/ftmo_pass/ftmo_days.py`
(`load_bars`, `usd_per_quote`, `quote_at`) unchanged.

    python -m unittest test_holdout_verdict test_holdout_t3   # V1-V6, H1-H5, hand-derived
    python holdout_verdict.py --history history_1514731800.csv --bars bidask_ftmo_2026-10-09 [--week2]
    python holdout_t3.py --export archive_2026-10-09.jsonl \
        --bars bidask_ftmo_2026-10-09 --bars-ic bidask_ic_1009

`holdout_verdict.py` decides (FTMO's daily equity, day-bootstrap; reuses
`research/ftmo_pass/ftmo_days.py` unchanged); `holdout_t3.py` is reported.
Run ONCE, after the Friday 9 Oct close (the criteria s6: nothing of the
window is computed before). Use the ARCHIVE export (`--export-archive`),
not the 14-day study export: a layer opened more than 14 days before the
window needs its open price for the marks. The window and marks are
fixed in the module (`WINDOW`, `MARKS`). T1, T2 and T4 come from
`research/markout/markout.py` unchanged.
