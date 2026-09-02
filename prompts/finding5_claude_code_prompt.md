This message has a line count at the bottom.

# Finding 5 Root Cause Investigation — add_next Post-Placement Modification

## Background

FXMatrix V3 (MQL5 market-making EA, EUR/GBP/USD triad). An existing
finding (`docs/architecture/findings_exit_reset_kinetic_anchoring.md`,
Finding 5) documents that `add_next` resting limit orders (EA_MAGIC+1,
the next-layer entry orders) are being modified post-placement via a
real `OrderModify` call — something a prior anchor investigation had
explicitly ruled out ("No OrderModify on EA_MAGIC+1 tickets anywhere").
Root cause is currently UNCONFIRMED. This is investigation only.

Five confirmed instances, all from a June 2026 backtest, all within a
few minutes of midnight (broker/simulated time):

| Ticket | Instrument | Placed (sim time) | Modified (sim time) | Modified price |
|--------|-----------|--------------------|-----------------------|-----------------|
| 167 | GBPUSD | 2026-06-15 22:56:52 | 2026-06-16 00:05:00 | 1.33978 |
| 364 | EURUSD | 2026-06-17 22:46:44 | 2026-06-18 00:06:01 | 1.14642 |
| 365 | GBPUSD | 2026-06-17 22:46:44 | 2026-06-18 00:06:01 | 1.32580 |
| 371 | EURUSD | 2026-06-18 13:15:01 | 2026-06-19 00:05:00 | 1.14305 |
| 379 | GBPUSD | 2026-06-18 22:41:10 | 2026-06-19 00:05:00 | 1.31721 |

Note tickets 364 and 365 (different instruments) modify at the exact
same simulated timestamp — possible sign of one shared routine
touching multiple instruments at once, rather than per-instrument
independent logic.

Already ruled out: ADR-046 cooldown drag (`RunSpreadCooldownReconciliation`)
explicitly skips any instrument with `inst_inv_size > 0`; the original
two instances (364, 371) had non-zero open inventory throughout, which
argues against cooldown drag being responsible. Not yet re-verified for
167/365/379 — worth doing if the data supports it.

Leading (unconfirmed) hypothesis: tied to daily rollover
(`SaveGlobalState` logs `last_rollover_day_of_year`, `daily_start_balance`,
`daily_start_date` — confirmed present in the log near these events, but
not yet confirmed as causally responsible).

## Task

### Part 1 — Read the log context dump

Read `D:\fxmatrix\logs\finding5_output\ticket_context_dump.txt`. This
file contains raw log line windows (±12 lines) around every mention of
each of the 5 tickets above, within one specific backtest run.

For each ticket, there are TWO windows: one around its PLACEMENT event
(already reviewed, confirmed unremarkable — normal `SaveInventoryState`/
grid-layer logic, no need to re-report this one) and one around its
MODIFICATION event (marked `>>>` in the file, at the simulated
timestamps in the table above). Focus entirely on the MODIFICATION
windows.

For each of the 5 modification windows, report:

1. The full raw content of every line in the window, verbatim — do not
   summarize, paraphrase, or omit lines.
2. Any `inst_inv_size` value for that instrument logged nearby (search
   a wider window in the same file if the immediate ±12 lines don't
   contain one).
3. Any line whose Source column (the 3rd tab-separated field) is
   something other than the ordinary values you'd expect (e.g.
   `FXMatrix (EURGBP,M5)`, `Trade`, `Network`, `Terminal`) — flag these
   explicitly, they are the most likely place a distinct routine would
   leave a fingerprint.

### Part 2 — Search the codebase directly

Search `d:\fxmatrix\ea\*.mqh` and `*.mq5` for every call site that
could modify a resting EA_MAGIC+1 (add_next) order's price — this
includes `OrderModify`, `OrderSend` with a modify-type action, or any
custom wrapper function that ultimately does this. For each candidate
found, report:

- File and line number
- Enclosing function name
- Whether it's conditioned on anything resembling daily rollover,
  `day_of_year`, midnight, date-change detection, or similar
- Whether it appears to target EA_MAGIC+1 specifically, or all magic
  numbers / all resting orders generically

### Part 3 — Cross-reference

Does any code call site from Part 2 plausibly explain what Part 1
found in the log? State your confidence level explicitly (e.g.
"confirmed", "plausible but unverified", "no match found") and show
the specific evidence connecting them — do not assert a match without
pointing to the exact code and exact log line that support it. If no
code call site is found at all that could explain this, say so
directly rather than speculating.

## Negative Space — Do Not Do

- Do not modify any file
- Do not write any new code
- Do not attempt to fix anything — this is investigation and reporting
  only, no implementation
- Do not touch anything outside the log file and the `ea/` directory
  read-only search

## Report Format

Structure your response as: Part 1 (five modification windows, raw
content each), Part 2 (code search results, or "no candidates found"),
Part 3 (cross-reference verdict with confidence level and evidence).

Line Count
This prompt is 111 lines.
