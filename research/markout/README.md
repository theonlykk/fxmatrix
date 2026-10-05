# research/markout -- markouts and variance ratios (docs/research/markout-variance-study.md)

Read-only analysis of files; standard library only (Python 3.9+). Reuses the
ejection study's loaders (`research/ejection_value`, imported, never changed).

    python research/markout/cal.py                      # random-walk baselines (40 seeded paths)
    python research/markout/vr.py <bidask folder>        # VR(q) and Z(h) per pair
    python research/markout/markout.py <bidask folder> <archive export .jsonl>

Inputs: `grind_bidask_dump.mq5` minute bars (FTMO desktop terminal; IC on
wine-c) and `archive_counts.py --export-archive`. First run 5 Oct ~03:20Z on
`bidask_ftmo_2026-10-02` and `archive_2026-10-02.jsonl` (results in the study s4).

No unit tests: an exploratory evidence run whose numbers are quoted in the
study (the convention of `research/compass/d1_evidence.py`); `cal.py` is the
calibration the measures are read against. Re-run unchanged on the 1-7 Oct
holdout before any conclusion (study s6).
