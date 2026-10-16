# research/roll_recovery -- rolled closes and recovery (docs/research/roll-geometry-notes-2026-10-15.md s7)

Read-only analysis of files; standard library only (Python 3.9+).

    python research/roll_recovery/rolled_recovery.py <archive export .jsonl> [...]
    python research/roll_recovery/test_rolled_recovery.py

Input: `archive_counts.py --export-archive --instance GRIND_<PAIR>_<SLOT>` (one instance per file;
a UTF-8 BOM from `Set-Content -Encoding utf8` is tolerated). For each rolled close
(`scalp_history.rolled`) it asks whether the instance's own MARKET fills (fill_logs IN / OUT, never
OUT_BY) later came back through the layer's ORIGINAL entry, and how many hours that took; plus scalps
against rolled closes per UTC day.

First run 16 Oct ~16:50Z on fleet B's GBPUSD and EURGBP: `results_2026-10-16.md`, inputs in
`inputs.sha256` (the exports are not in git). Hindsight about realised losses, not the P&L of a hold
policy: the note's s7 caveats apply.

Tests: hand values, including the trap of the first draft (an OUT_BY row's price is the other
position's entry; counting it as the market read every rolled close as recovered). A mutation that
keeps OUT_BY fails two of the four.
