This message has a line count at the bottom

# AUDCAD WIDE RUNGS OUT OF SAMPLE -- DOES FABLE's ONE POSITIVE REGION HOLD IN 2018-2022? (PRE-REGISTRATION)

| | |
|---|---|
| Question | Fable's blind review found one region of the grid's design that leans positive on 2023-2026 FTMO bars: **AUDCAD, add 17 to 26 pips, exit = add or 2 x add, cap 7** (`reviews/fable_pass1/report_pass1.md` s1 item 5, s4.8, s5). It called it "a hypothesis worth testing out of sample, not a finding": one pair, one four-year regime, one cell of 612 at t 3.5. Does the same region make money on AUDCAD in **2018-2022**, data no one has looked at? |
| Why asked | The operator (11 Nov) agreed to Fable's two concrete tests instead of a pass 2; the fill convention is measured (`research/fills/results.md`); this is the other. |
| Status | **Pre-registered: committed, and reviewed by Argon, before any 2018-2022 bar is read.** The bars may be exported meanwhile; until then only their file's hash and header line are read. |
| Bearing | Not C162: the project is wound down (ruled 8 Nov) whatever this shows. A HOLDS can only inform which setting the one small live remainder on wine-c runs, and only after a swap check (s7). |

## 1. ONE WORKED EXAMPLE (the region, in sample)

On 2023-2026 FTMO bars, Fable's ladder in its most conservative variant (`cont` fills, `std` intra-bar order,
clean path; `out/04_ladder_cells_cont.csv`) gives AUDCAD, add 20, exit 40, cap 7, width 5, stranded 6: 1,524 closes,
**+884 USD** after commission at 0.01 lot, +19.2 USD a month, t 3.0, 4 of 4 years positive. The ten cells of the
region average about +15 USD a month in that variant. HOLDS (s6) asks for the same sign, with t at least 2, in
five years it never saw.

## 2. THE DATA

- **AUDCAD M1 bars, 2018-01-01 00:00 to 2023-01-01 00:00 server time**, by `scripts/grind_bar_dump.mq5`
  (`InpSymbols = "AUDCAD"`, `InpFrom = "2018.01.01 00:00"`, `InpTo = "2023.01.01 00:00"`) on the **desktop**
  terminal (no EAs, Max bars Unlimited; 02_TRAPS 2026-10-26: a live box's terminal caps `CopyRates`).
- **Feed:** FTMO-Demo, the in-sample feed and the venue of the live remainder, if its history reaches back to
  2020-01-01 or earlier; otherwise an IC Markets demo login on the same terminal. **At least 36 calendar months** are
  needed; with fewer from both, the result is NOT TESTABLE and nothing else is run.
- The file (`bars_<login>_AUDCAD.csv`, header line as in `bars_ftmo`) is hashed into `research/audcad_oos/MANIFEST.md`
  before it is opened for anything but its header.

## 3. THE ENGINE (Fable's, unchanged)

- `reviews/fable_pass1/core.py` (`ladder`) and `common.py` (`pseudo_ticks`, `blowout_mask`, `weekday_mask`,
  `month_id`, `tstat`, `USD`, `COMM`), imported unchanged by a thin runner `research/audcad_oos/run_oos.py`, which
  only points the loader at a given bar file and runs the ten cells below; no other code path.
- **The ten cells:** AUDCAD, cap 7, deadband 2, width a / 4, stranded a / 4 + 1 (Fable's scan and design cells),
  **add a in {17, 18, 20, 23, 26}, exit in {a, 2a}.**
- **Four variants:** fill model `cont` or `one` x intra-bar order `std` or `alt`, all on the clean path (blow-out
  bars frozen at the last normal mid). Mode "spread": the recorded bid / ask, then 0.06 USD commission per close
  (USD per pip 0.0714). Unit: the calendar month, the change in realised + open mark, as `summarise`.
- **The region:** each month, the mean of the ten cells' net USD; its mean over months and its t (mean / se across
  months).
- **Sensitivity:** every fill 0.2 pip worse (bid - 0.2 pip, ask + 0.2 pip on every pseudo-tick): the bar spread is
  the minute's minimum (understated by 0.06-0.17 pip, Fable s4.1) and live fills keep only part of the touching-tick
  improvement (`research/fills/results.md`).

## 4. SELF-CHECKS (reported BEFORE any 2018-2022 result is read)

a. **Control:** the runner on the 2023-2026 FTMO bars (`bars_ftmo`, hashes in its MANIFEST) reproduces Fable's
   `out/04_ladder_cells_cont.csv` and `_one.csv` for the AUDCAD `std` cells it has (scan cap7 at 17-26, design
   exit2a at 17-26): closes, rolls and net USD equal to the cent. If not, stop.
b. `reviews/fable_pass1/test_core.py` passes unchanged (its random-walk null among it).
c. The new file: first and last bar, bars per year, months covered, the share of blow-out bars, the median
   recorded spread in server hours 2-21; no result.
d. A random-walk null in the new period's own volatility: Fable's `01_null_calibration.py` method on a lattice walk
   cut into bars with the new file's median bar range; the region's gross in each variant on it, reported as the
   pipeline's own bias at that volatility (Fable s4.2: `std` reads low and `alt` high when bars are large).

## 5. WHAT IS MEASURED (all four variants, and the sensitivity)

Per cell and for the region: net USD in all and a month, t over months, years positive (2018-2022), closes, rolled
closes, maximum drawdown in pips; the region by year. In-sample values beside them (s4 a).

## 6. THE DECISION RULE (`cont-std` decides; fixed now)

**HOLDS** only if all four, on 2018-2022, `cont-std`:
1. The region's mean monthly net USD is above zero.
2. Its t over months is **2.0 or more**.
3. **At least 3 of the 5 years** have a positive region net.
4. **At least 7 of the 10 cells** have a positive net.

- The region's mean at or below zero: **FAILS**. Above zero but not all four: **INCONCLUSIVE**.
- A HOLDS that fails any of 1-4 under the 0.2 pip sensitivity is **FRAGILE**, treated as INCONCLUSIVE.
- The other three variants are reported beside it; they do not decide.
- **Consequence:** FAILS or INCONCLUSIVE: Fable's region is closed and the live remainder runs C's t2 as planned.
  HOLDS: a swap check (s7) comes next, then the operator decides whether the live remainder runs this setting.

## 7. KNOWN BIASES (stated now)

- **The region was chosen in sample** from 612 cells (Fable s4.8); this test exists to check that choice.
- **No swap.** Wide-rung layers are held for days to weeks; AUD and CAD rates differed in 2018-2022. Swap is a
  cost to a grid that holds both sides at different times; this test flatters the region by it.
- **Bars, not ticks:** Fable found `cont-std` nearest the tick truth in five pairs of six (s4.6); the other
  variants lean optimistic.
- **The recorded spread is a minimum**, and an IC feed (if used) is 0.4-0.8 pip narrower than FTMO's on the crosses
  in core hours (Fable s4.1): the sensitivity covers part of it.
- **One more period of one pair.** A HOLDS does not make AUDCAD's ranging a law; it makes it two regimes, not one.

## 8. ORDER OF WORK

1. This file, committed; Argon reviews it (a prompt on `main`); changes committed before step 3.
2. The operator exports the bars (s2); Claude hashes the file and reads its header only.
3. `run_oos.py` with the control (s4 a) and checks b-d, committed with their output, before any 2018-2022 result.
4. The result against s6 in `research/audcad_oos/results.md`.

Line count: 96
