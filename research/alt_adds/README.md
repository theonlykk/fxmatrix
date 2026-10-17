# research/alt_adds -- ALT's adds from our own fills (docs/research/fleet-d-two-arm-ring-2026-10-16.md s5, s8)

Read-only analysis of files; standard library only (Python 3.9+).

    python research/alt_adds/alt_excursions.py --exit-pips <L0's exit> --opt-add <OPT's add> [--since-utc-ms MS] <archive export .jsonl> [...]
    python research/alt_adds/test_alt_excursions.py
    python research/alt_adds/solve_exit_eq_add.py <archive export .jsonl> [...]   # ALT add when exit = add (results s6)

Input: `archive_counts.py --export-archive --instance GRIND_<PAIR>_<SLOT>` (one instance per file; a
UTF-8 BOM is tolerated). Market samples: fill_logs IN deals and ROLL_ACCEPTED levels, never OUT_BY (its
price is the other position's entry). For a side opened at each hourly anchor, the excursion is how far
the market went against it before L0's exit filled (the side empty again); anchors never recovered by
the end are censored at their running excursion. A side rolls when its excursion passes its stack,
(cap - 1) x add; ALT's add at cap 7 is the stack covering a share of anchors / 6.

First run 17 Oct ~01:10Z on fleet D's six kept pairs: `results_2026-10-17.md`, inputs in
`inputs.sha256` (the exports are not in git). Hindsight at grid resolution, one fleet, about 16 days.

Tests: hand values (a short's 35-pip excursion, a censored long, the exit not reached, hourly anchors,
nearest-rank quantiles, the loader ignoring OUT_BY). Mutations caught: keeping OUT_BY fails one test,
dropping censoring fails two.
