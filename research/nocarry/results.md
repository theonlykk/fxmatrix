This message has a line count at the bottom

# NO CARRY -- THE RESULT (8 Nov 2026)

| | |
|---|---|
| Question | `PREREG.md`: does E's t3 grid earn over the four years if it is flat every night (DAY) or every weekend (WEEK)? |
| Verdict | **NO EDGE** (s6, DAY, the twelve instances together). Not close: DAY fails rules 1, 2 and 3 by wide margins, and the 0.5 pip sensitivity changes no label. |
| Self-checks | a, c, d, e all PASS (`selfcheck_out.txt`), committed in their own commit (the one before this file's) with every output hash (`MANIFEST.md`) **before any total was read**; b: 15 / 15 tests. |
| Units | USD at 0.01 lots, after $0.06 a close, no swap; 2 Jan 2023 to 23 Oct 2026, the six pairs, OPT and ALT each. |

## 1. THE RULE, ARM BY ARM (the twelve together)

| | CONT (carry) | **DAY (decides)** | WEEK | rule (DAY) |
|---|---|---|---|---|
| 1. Net | -$6,358 | **-$22,711** | -$13,488 | > 0: **FAIL** |
| 2. Years 2023 / 2024 / 2025 / 2026 | -2,232 / -3,113 / -1,887 / +876 | **-5,679 / -5,535 / -7,361 / -4,137** | -4,125 / -3,903 / -4,434 / -1,025 | 3 of 4 > 0: **FAIL (0 of 4)** |
| 3. Twelve-month windows negative | 27 of 34 | **34 of 34** | 34 of 34 | at most 16: **FAIL** |
| 4. FTMO days of $500 or worse | 1,181 of 1,191 | **3** | 69 | at most 4: pass |
| FTMO days of $400 or worse | 1,187 | 6 | 143 | |
| Single months / three-month windows negative | 27 of 45 / 29 of 43 | 43 of 45 / 43 of 43 | 35 of 45 / 38 of 43 | |
| Worst twelve months | -$4,599 | -$9,268 | -$6,211 | |
| Peak to trough (month-end equity) | -$7,886 | -$22,711 | -$13,568 | |
| **Label** | (control) | **NO EDGE** | NO EDGE | |

- **0.5 pip sensitivity** (each cut close 0.5 pip worse): DAY -$25,797, WEEK -$14,388; FTMO days at $500 or worse
  unchanged (3 and 69). Labels unchanged.
- **OPT and ALT apart** (reported, not deciding): DAY OPT -$16,548, ALT -$6,162; WEEK OPT -$10,817, ALT -$2,671. All
  four NO EDGE; every year negative in each. Under DAY **all twelve instances lose**; under CONT five of twelve made money.
- **CONT reproduces the longrun run:** byte-identical files (check a); the years, the windows and the worst twelve
  months match `research/longrun/results.md` s3. Peak to trough is -$7,886 here against -$7,854 there: same data,
  `summarise.py` takes the peak from the flat start (0 on 2 Jan 2023), `results.md` from the first month-end mark
  (-$33).

## 2. WHERE DAY's MONEY GOES

| the twelve | scalps | rolled | cut closes | open at end | commission | **net** | gross before commission |
|---|---|---|---|---|---|---|---|
| CONT | +113,204 | -111,366 | 0 | -751 | -7,445 | **-6,358** | +1,087 |
| WEEK | +125,938 | -69,846 | -60,746 | 0 | -8,834 | **-13,488** | -4,654 |
| DAY | +128,631 | -32,259 | -107,860 | 0 | -11,224 | **-22,711** | -11,487 |

- The scalps are real in every arm, and DAY earns the most of them (+$15k on CONT): each 01:00 restart places fresh
  L0s straddling the price.
- The losing layers cost more than the scalps however they leave: rolled (CONT), cut on Friday (WEEK), or cut every
  night (DAY). DAY turns $79k of CONT's roll losses into $108k of cut losses. A layer cut at 23:45 has no night to
  come back in; carried, part of it did. Before commission CONT is +$1,087 over four years and DAY -$11,487.
- **Per pair, DAY, OPT:** cut closes 4,072 (AUDCHF) to 7,668 (GBPUSD) over 989 nights, 4 to 8 a night; 79-90% of
  them losers; the median cut close -8.3 (EURGBP) to -18.7 pips (GBPUSD). ALT: 2,530 to 6,173 cut closes, 64-86%
  losers, median -4.2 (EURGBP) to -20.7 pips (GBPUSD). The median night's cuts, both
  instances: -$6 (AUDCAD) to -$31 (GBPUSD). Check e lists one week of them by hand (GBPUSD OPT, 19-23 Oct: 31 cut
  closes, 30 losers, -74.6 to +5.4 pips).

## 3. THE FTMO DAY (the operator's second question)

- **Carried, the grid cannot hold an FTMO account.** CONT's twelve instances carry -$471 to -$1,163 of open loss at
  every month end (`research/longrun/results.md` s3). FTMO measures the day from the day-start balance, so that
  floating loss is spent before the day's first tick: **1,181 of 1,191 FTMO days at $500 or worse.** This is E's
  death on 4 Nov ($380 of its $500 used before the day began) as the steady state, not bad luck. (E had run weeks,
  not years; the backtest's book is older and larger.)
- **Flat every night, the grid is FTMO-safe and loses steadily.** DAY: 3 days at $500 or worse in four years, all in
  the tariff week of April 2025 (3 Apr $660, 4 Apr $826, 10 Apr $658); next worst 5 Aug 2024 $490, 9 Apr 2025 $431,
  14 Nov 2023 $401. It pays for that safety at about **$23 a trading day** (-$22,711 over 989 nights).
- **Flat every weekend** (FTMO's actual Standard-account rule): 69 days at $500 or worse; worst 4 Apr 2025 $1,660.
  WEEK is neither safe nor profitable.

## 4. WHAT THIS DOES AND DOES NOT SAY

- It closes the door left open by the longrun run: **no carry rule rescues E's t3 set.** Carrying (CONT) is the least
  bad of the three and still loses; the losses do not come from the overnight hold, they come from the losing layers,
  and cutting them sooner makes them dearer.
- It is E's t3 presets only (the six pairs' widths, cap 7, deadband 2, lattice and re-roll on). It does not test
  other widths or exits; the longrun run's s4 already argues why any symmetric grid earns about zero before costs.
- **Biases (PREREG s7), and which way they lean:** no swap flatters CONT and WEEK, which carry, never DAY; bars, not
  ticks, flatter every fill alike; the cut at the 23:45 bar's open quote, with no latency, flatters DAY and WEEK (the
  0.5 pip sensitivity costs DAY another $3,086 and changes no label). None of them is near the size of DAY's loss.
- **Under PREREG s6, NO EDGE means the C162 memo says the project stops.** The memo is the next document, reviewed
  before any distribution.

## 5. FILES

- `PREREG.md` (the plan, amended after Argon); `test_nocarry.py`, `run_nocarry.py`, `selfcheck.py`, `summarise.py`.
- `out/<ARM>_<PAIR>.json` (30 runs); `selfcheck_out.txt`; `MANIFEST.md` (every input, code and output hash; the
  8.1 GB of per-tick arrays are not committed and rebuild from the bars).
- Reproduce: `python research/nocarry/run_nocarry.py <bars> <PAIR> --arm DAY [--worse 0.5] --out <dir>` per run,
  then `selfcheck.py <bars> <dir>`, then `summarise.py <dir>`.

Line count: 88
