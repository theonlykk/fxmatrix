This message has a line count at the bottom

# research/ejection_value -- the ejection value study (C16 revived)

Design and Gemini rulings: `docs/research/ejection-value-study.md`.
Read-only analysis of files; standard library only (Python 3.9+).

## Inputs

- Export (desktop `D:\pipshed`), one or more files; overlaps de-duplicate:

      railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-study --days 14 | Set-Content -Encoding utf8 "$HOME\Downloads\study_export_<date>.jsonl"

  Use `--days 14`: the depth timeline and the replay need every ENT fill
  since the fleet started (24 Sep for A and B, 28 Sep for C). `fill_logs`
  are never deleted (the old "14-day retention" note was wrong); `ea_events`
  go after 90 days. Rows of other accounts are dropped by session
  (`ev_data.filter_by_account`): cycle 2 used fleet A's instance ids.
  Layers opened before the window and never closed in it are invisible;
  the report estimates them from cap anchors and prints the estimate.
- Bars: `scripts/grind_bar_dump.mq5` output, `bars_<login>_<SYM>.csv`, in
  any folder given with `--bars` (FTMO: the desktop terminal; IC: box 2,
  which shares `ICMarketsSC-Demo` with box 1; Fleet B's account is aliased
  to box 2's bars by default).

## Run

Bars for the replay must start before the fleets did: run the bar dump
with `InpFrom = 2026.09.24 00:00`.

    python research/ejection_value/ev_report.py --export <file>... --bars <dir> [--bars <dir>] [--horizons 24,48]
    python research/ejection_value/ev_caps.py --export <file>... --bars <dir> [--bars <dir>] [--caps 5,6,7,8,9,10] [--depth-at 2026-09-30T01:40]
    python -m unittest research/ejection_value/test_ejection_value.py -v
    python -m unittest research/ejection_value/test_replay.py -v

## Files

| file | what |
|---|---|
| `ev_data.py` | export and bar loaders; server time -> UTC; drops the forming last bar |
| `ev_book.py` | layers from the ledger (close-by pairs, all-in net), depth timelines, cap anchors, Q1 hours at cap and scalp rates |
| `ev_episodes.py` | ejections, carry-shifted exit, hit / MAE / mark (M1 bid + bar spread), chains, freed-slot F, V |
| `ev_controls.py` | GQ5-F controls: cross-fleet (B vs C), twins (`_ALT`), F per held-cap hour |
| `ev_report.py` | the report |
| `ev_replay.py` | study s9: per-side ladder replay on M1 bars (the EA's rules, simplified as listed in its docstring), ledger money, reconciliation rule, fleet day metrics, slots |
| `ev_caps.py` | study s9 runner: reconcile at the actual cap, then caps 5-10 (frontier per instance and fleet), depth at named times |
| `test_replay.py` | 16 synthetic tests (hand-derived); 13 deliberate code breaks each fail a named test |
| `test_ejection_value.py` | 19 synthetic tests, expected values by hand; each of 8 deliberate code breaks fails its named test, and each resync-fallback branch removed fails its test |

## Decisions in the code (see the module docstrings)

- F is decided by DEPTH, not layer index: auto-eject takes the exit ranked
  depth-1 (the most underwater layer, usually L0; `grind_engine.mqh`
  559-585), so "index >= the ejected index" (GQ1 as ruled) counts layers
  that exist in both worlds. A layer is freed-slot when it was added while
  the held world was still at cap.
- `V_doc` = sum(E - H) + F_closed (study s2); `V_strict` adds the mark of
  freed-slot layers still open at the chain end.
- Night multiplier: Wed 3, Sat/Sun 0, else 1 (INFERRED; C61 is open).
- Episodes whose horizon runs past the bars are `no_data`, never scored.

Line count: 62
