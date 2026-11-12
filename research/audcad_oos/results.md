This message has a line count at the bottom

# AUDCAD WIDE RUNGS OUT OF SAMPLE -- THE RESULT (12 Nov 2026)

| | |
|---|---|
| Question | `PREREG.md`: does Fable's one positive region (AUDCAD, add 17-26, exit = add or 2 x add, cap 7; about +15 USD a month in sample, 2023-2026) make money in data it never saw? 2020-2022 decides (s2a); 2018-2019 is reported only. |
| Verdict | **FAILS** (s6, `cont-std`): the region loses **-16.04 USD a month** (se 16.47, t -0.97) over 36 months, and **0 of the 10 cells** made money. Every variant loses; the 0.2 pip sensitivity loses more. |
| Before it | Three Argon reviews (the first failed its quote check; the second and third, 134 / 136 and 116 / 116 quotes exact, SOUND); the control reproduced Fable's 20 in-sample cells to the cent; self-checks a-d committed on `main` before this run (`selfcheck_out.txt`), the runner's gate read them. |
| Units | USD at 0.01 lot, after 0.06 USD a close, no swap; the region = each month's mean of the ten cells. |

## 1. THE RULE (2020-2022, `cont-std`)

| rule | needed | got | |
|---|---|---|---|
| 1. region mean above zero | > 0 | **-16.04 USD a month** | FAIL |
| 2. t over months | >= 2.0 | -0.97 | fail |
| 3. years positive | 2 of 3 | 2 of 3 (2020 -624.6, 2021 +16.2, 2022 +30.9) | pass |
| 4. cells positive | 7 of 10 | **0 of 10** (-376 to -910 each) | fail |

Rule 1 fails, so the verdict is FAILS (s6); the sensitivity (-18.15, t -1.08) is not needed to decide it.

## 2. ALL VARIANTS, BOTH PERIODS (region USD a month, t; `oos_out.txt`)

| | 2020-2022 (decides) | 0.2 pip worse | 2018-2019 (reported only) | 0.2 pip worse |
|---|---|---|---|---|
| cont-std | **-16.04 (t -0.97)**, cells 0 / 10 | -18.15 (-1.08) | -8.50 (-0.82), cells 2 / 10 | -9.86 (-0.95) |
| cont-alt | -8.94 (-0.69), 0 / 10 | -11.14 (-0.83) | -3.24 (-0.31), 4 / 10 | -4.67 (-0.45) |
| one-std | -9.78 (-0.63), 0 / 10 | -11.86 (-0.75) | -7.38 (-0.71), 2 / 10 | -8.72 (-0.84) |
| one-alt | -5.48 (-0.41), 0 / 10 | -7.61 (-0.55) | -4.55 (-0.44), 3 / 10 | -5.92 (-0.58) |

In sample (2023-2026), the same ten cells in `cont-std`: about +15 USD a month (Fable; reproduced, s4 a).
2018-2019 is under the caveat of s2a (stored spreads 1.4-4.0 pips, half the bars frozen as blow-outs).

## 3. WHERE IT LOST (description only; the rule above decides)

- **March 2020 cost -547 of 2020's -625** (the region, `cont-std`): AUDCAD broke down in the COVID crash and then
  ran from about 0.86 to 0.98 by December. That is the trending market a capped grid cannot carry.
- **The other 35 months together: about -30 USD**, roughly zero, against +15 a month in sample. So the region had no
  edge in ordinary months either; the crash only made it negative.
- Argon's notes (third review): 2020 has more core-hour bars frozen as blow-outs (10%) than the other years, and
  2020-2021's narrower stored spreads make the 0.2 pip sensitivity a floor, not a margin. Neither could turn a
  -16 a month at t -0.97, with no cell positive, into a pass.

## 4. WHAT IT MEANS

- **Fable's region was a feature of 2023-2026,** as Fable warned it might be ("four years of one pair do not answer
  it", report s5). It does not
  hold in the three years before. Under s6: **Fable's region is closed, and the live remainder, if any, runs C's t2
  as planned** (the operator's call).
- Nothing here touches the C162 ruling (wind down, 8 Nov). With the fill convention measured
  (`research/fills/results.md`), both of Fable's concrete tests are done: neither found an edge.

## 5. FILES

`PREREG.md` (amended s93j and s2a), `MANIFEST.md` (the data's hash), `run_oos.py`, `test_run_oos.py` (7 / 7),
`selfcheck_out.txt`, `oos_out.txt` (this run), `oos_result.json` (every cell and variant; sha256 first 16
`78e7b79721e2b10b`). Reproduce: `python research/audcad_oos/run_oos.py --oos <the 2018-2022 bar file>`.

Line count: 60
