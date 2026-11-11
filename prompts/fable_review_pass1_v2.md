This message has a line count at the bottom

# AN INDEPENDENT LOOK AT A PASSIVE FX GRID -- PASS 1 (BLIND)

**First, please: your analysis is worth far more to me if you have not seen my own conclusions.** Do not open any
memory file or search or read past chats in this conversation. If some background about me or this project is
shown to you automatically, disregard anything in it about how the strategy has performed or what I concluded.
At the top of your report, say whether you read any memory file or past chat, and which.

I run a small algorithmic trading project and would like an independent view of it from someone who has not seen
our own analysis. This is the first of two passes. In this one you see only the code, a description of its
mechanics, and the market data. You do NOT see our results or conclusions; that is deliberate. In a second pass,
later, I will show you those and ask you to attack them. Please do not go looking for them now (s2).

## 1. WHAT THE SYSTEM IS (neutral description)

- An MT5 Expert Advisor ("fxgrind") that trades spot FX with **passive limit orders only**: it never crosses the
  spread on entry and uses no stop losses. Each instance runs one currency pair and one parameter set ("arm"; two
  arms per pair, called OPT and ALT, differ only in their numbers).
- Per side (long and short independently): a first limit order rests `width` pips from the mid; on a fill, further
  "add" limits rest every `add` pips deeper, up to `cap` layers (7); each layer has an exit limit `exit` pips
  (here exit = add) beyond its entry. At the cap no new layer opens; each further `add` pips that price travels,
  one layer (long side: the highest-entry layer not yet moved) has its exit moved to `exit` pips beyond that new
  level (a "roll"; the "lattice"), so it closes on a bounce of one `exit`, at a loss when it was entered higher.
  While one side holds layers and the other is flat, the flat side's first order re-centres when it is more than
  `stranded` pips from the mid.
  The full mechanics, with file and line references into the EA, are in `MECHANICS.md` (s3).
- Costs: $0.06 commission per close per 0.01 lot; the spread as in the data. Size 0.01 lot per layer. USD value
  of one pip at 0.01 lot per pair: the `USD` table in `run_bars.py`.
- The parameters run live on six pairs (AUDCAD, AUDCHF, CADCHF, EURGBP, EURUSD, GBPUSD): the `GEO` table in
  `run_bars.py`, `(width, add, stranded)` for OPT then ALT, exit = add, cap 7, deadband 2.

## 2. WHAT YOU MAY READ, AND WHAT NOT (please keep to this in pass 1)

Read-only, on my PC (I will grant access to `D:\fxmatrix` and `D:\fxmatrix-exports`):

| what | where |
|---|---|
| The EA (MQL5) | `D:\fxmatrix\ea\fxgrind.mq5` and `D:\fxmatrix\ea\grind_*.mqh` only |
| The mechanics, with file:line references | `D:\fxmatrix\research\opt_budget\MECHANICS.md` |
| A Python model of the EA, and its tests | `D:\fxmatrix\research\opt_budget\sim.py`, `test_sim.py` |
| Bar loader, parameter and cost tables | `D:\fxmatrix\research\longrun\run_bars.py` (the code; not the folder's other files) |
| The tick dump script (file format) | `D:\fxmatrix\scripts\grind_tick_dump.mq5` |
| **Bars:** FTMO M1 bid OHLC + spread + tick volume, six pairs, 2 Jan 2023 - 23 Oct 2026, server time (header line 1 gives server minus GMT) | `D:\fxmatrix-exports\bars_ftmo\bars_1514878887_<PAIR>.csv` |
| **Ticks:** IC Markets raw bid/ask (time_msc, bid, ask, flags; server time), these six pairs and a few others; `__h8w` an eight-week window dumped 11 Oct 2026, `_oct` October dumped 22 Oct, other EURUSD windows (read each file's first and last times) | `D:\fxmatrix-exports\ticks_ic\ticks_53077984_<PAIR>_<window>.csv` |

**Not in pass 1:** anything else in `D:\fxmatrix` (in particular `handoffs\`, `docs\`, `reviews\`, `prompts\`,
any `results*.md`, `PREREG*.md`, `*_output*`, `out_*` folders, `research\*\` other than the files above); any other
folder in `D:\fxmatrix-exports`; the project's GitHub repositories; the telemetry site (pipshed); and **memory or
past chats about this project**, if you have them. If a file you open turns out to contain results or conclusions,
stop reading it and say so in your report.

**Write** only into a new folder `D:\fxmatrix-exports\fable_review\` (your notes, code, outputs, report). Do not
modify anything else, run MetaTrader, or touch any broker account.

## 3. THE QUESTIONS

**A. Before you look at any data** (write this first, as `A_expectations.md`, with the time you wrote it):
from the code and `MECHANICS.md` alone, what is this strategy economically? What would you expect it to earn
after costs on these pairs at these parameters, and why? What would have to be true of the price path for it to
make money?

**B. Then test it.** Derive, from the mechanics, the measurable property (or properties) of the price path that
the strategy needs in order to be profitable after costs, at the scales it actually trades (its widths, adds and
exits, and a plausible range around them, say adds of 3 to 30 pips). **Before running anything**, write the
tests, the scales, and what result would count as "present" or "absent", as `B_plan.md`. Then run them on the
bars (all six pairs, the whole period) and, at the smallest scales and with real spreads, on the ticks. Report
effect sizes with honest uncertainty (e.g. by week or month, not by tick), per pair and scale, and anything
notable by hour of day or by period. Conclude: does the data have what the strategy needs, anywhere, strongly
enough to pay its costs? Could ANY parameter set of this design plausibly work on these pairs, and if so where?

**C. Free comment:** anything about the approach (design, research method, what was or was not measured) you
would do differently, and anything in the code that looks wrong.

## 4. HOW TO REPORT

- `D:\fxmatrix-exports\fable_review\report_pass1.md`: A (as written before the data), the B plan, the results,
  your conclusion, C. Plain text tables; every number traceable to a script in the same folder that reproduces it.
- Say plainly what you could not do or check, and where an answer rests on an assumption.
- Keep the report's first line exactly `This message has a line count at the bottom` and its last line
  `Line count: N` (N = the file's total lines, both included). ASCII only.

Thank you. A straight answer is worth more to me than an encouraging one.

Line count: 85
