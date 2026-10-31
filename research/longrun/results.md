This message has a line count at the bottom

# FOUR YEARS OF THE t3 GRID ON MINUTE BARS -- DOES IT EARN? (31 Oct 2026; descriptive, not pre-registered)

| | |
|---|---|
| Answer | **No.** E's t3 set (six pairs, OPT and ALT, cap 7, 0.01 lots) run continuously on FTMO minute bars from 2 Jan 2023 to 23 Oct 2026: **OPT -$7,158, ALT +$800, together -$6,358** after commission (no swap). Three of four years lose. The scalps collected and the rolled losses paid back nearly cancel on every pair. |
| Why asked | The operator (31 Oct): "I feel that we are not really earning, we are just monetizing mtm winners - fearful that the gains will be given back. conversely, we are super relaxed about mtm losses and confident that they will turn into winners." |
| Status | Descriptive analysis, not pre-registered; the code and every output are committed (s7). **It corrects results given in chat earlier the same day** from a flawed fill rule (s2); none of those were committed. |
| Bearing | C162 (the project's go / no-go, 21 Oct): on this evidence the t3 geometry has no edge over four years. The live fleets' first weeks (D -$21, E -$4, C +$77 to 30 Oct) are consistent with it. A decision memo follows. |

## 1. ONE WORKED EXAMPLE (how the money goes round)

EURUSD OPT, add = exit = 7 pips, cap 7. Price ranges 1.1600 - 1.1630 for a day: the stack fills and exits over and over,
each close +7 pips ($0.70 less $0.06). Then price falls 60 pips and does not come back that week: the long side fills
to 7 layers, and at the cap each further 7 pips ROLLS the highest layer down (MECHANICS s3). When price finally bounces
7 pips, a rolled layer's exit fills: it closes at a loss of tens of pips (40 pips = -$4.00), realised. Thirty small wins pay
for one such roll. Over four years EURUSD OPT collected +$22,096 in scalps and paid -$23,314 in rolled closes.

## 2. METHOD, AND THE FLAW FOUND ON THE WAY

- **Engine:** `research/opt_budget/sim.py` (fxgrind's mechanics and the replay's timed broker, MECHANICS.md), run
  continuously over all weeks with at least 4,000 bars (holiday-short weeks skipped), from flat on 2 Jan 2023.
- **Data:** the Osler files (`research/cluster/PREREG.md` s3: FTMO M1 bars, hashes there). Each bar becomes four
  ticks 15 s apart (open; low and high in the bar's direction; close); ask = bid + the bar's spread.
- **Settings:** `ea/presets_e/*_e_t3.set`: OPT / ALT width, add = exit, stranded: GBPUSD 2.5 / 9 and 4 / 15, EURUSD
  2 / 7 and 6 / 23, EURGBP 1.5 / 5 and 6 / 23, AUDCAD 4.5 / 18 and 6.5 / 26, AUDCHF 3.5 / 14 and 5 / 20, CADCHF
  2.5 / 10 and 4.5 / 17; cap 7, deadband 2, lattice and re-roll on, roll gate 0. Commission $0.06 a close; USD per
  pip as `research/replay/sweep.py`. **No swap.**
- **The flaw (`--fill market`, sim.py as committed):** a touched limit deals at the market 261 ms later. On real
  ticks that is about the limit price; on bar ticks the touching tick IS the bar's high or low, often pips beyond
  the limit, so every entry and exit got a free improvement. Fill COUNTS were right (closes a day within ~10% of the
  tick replay on all 12 cells, both the calm weeks and October), the DOLLARS were not: +$33,162 over the four years.
  Afternoon results in chat built on it (a week-by-week view: "+$112 a week", "OPT best in volatile weeks", "154 of
  199 weeks positive", "rolling beats holding", ALT with a far L0) are **withdrawn**; not recomputed.
- **The fix (`--fill limit`):** a touched limit deals at its own price, never better (slightly conservative on gaps).
  **Check against the tick replay:** Aug - 23 Oct 2026 the limit-fill run gives **+$180**; the tick replay of the same
  set (sweep11, t3, about the same twelve weeks, IC's ticks) gave **+$231**. They agree; the market-fill run did not.

## 3. THE RESULT (`--fill limit`; USD at 0.01 lots, after commission, no swap)

| pair | OPT net | OPT scalps | OPT rolled | ALT net | ALT scalps | ALT rolled |
|---|---|---|---|---|---|---|
| EURUSD | -3,418 | +22,096 | -23,314 | +109 | +7,673 | -7,235 |
| GBPUSD | -2,491 | +25,408 | -25,937 | -830 | +16,042 | -16,074 |
| EURGBP | -733 | +11,225 | -10,782 | +565 | +2,629 | -1,859 |
| AUDCAD | +772 | +4,539 | -3,515 | +876 | +3,342 | -2,200 |
| AUDCHF | -796 | +5,744 | -6,262 | -104 | +4,119 | -4,068 |
| CADCHF | -493 | +6,494 | -6,577 | +185 | +3,892 | -3,543 |
| **total** | **-7,158** | | | **+800** | | |

(net = scalps + rolled + the open book at the end + commission; OPT commission -$6,064 in all, ALT -$1,380.)

- **By year (both arms):** 2023 -$2,232; 2024 -$3,113; 2025 -$1,887; 2026 to 23 Oct +$876.
- **Windows of the month-end equity:** negative in 27 of 45 single months (60%), 29 of 43 three-month windows (67%),
  27 of 34 twelve-month windows (79%); the worst twelve months -$4,599; peak to trough -$7,854.
- **The open book stays bounded:** -$751 at the end, between -$471 and -$1,163 at every month end. The cap and
  the rolls force losses into realised P&L; nothing piles up unseen.

## 4. THE OPERATOR's HYPOTHESIS, TESTED

- **Winners are taken fast, losers held long: TRUE.** Median holding time of winning against losing closes: EURUSD
  OPT 0.6 h against 13.6 h; GBPUSD OPT 0.7 against 17.8; AUDCAD OPT 8.8 against 165; ALT longer still (EURUSD 8.5
  against 190 h; EURGBP 45 against 790 h).
- **"Not really earning": TRUE.** Scalps and rolled losses nearly cancel pair by pair (s3); commission tips OPT clearly
  negative; ALT, which pays far less commission, ends near zero (+$800 over 46 months, about $17 a month for six
  pairs). This is what a grid earns on a random walk: zero before costs.
- **"Relaxed about losses because they turn into winners": NOT how the losses arrive.** They do not wait in the open
  book; they are realised through rolls, on the partial bounce after a move. The loss is real and paid, in fewer and
  larger pieces than the wins.

## 5. WHAT IT MEANS

- With Osler (`research/cluster/results.md`) and the magnet grid (`research/magnet/results.md`): three angles, one
  reading. On these pairs in 2023-26 price does not revert in a way a passive grid can harvest after costs.
- **DUP (ALT x 2):** doubles about $17 a month across six pairs, and doubles ALT's tail. Not worth building.
- **The live fleets** have no reason to expect better than this. E's trial and the IC demos remain useful evidence at no
  money risk, but the case for real capital at this geometry is not made.

## 6. LIMITS

Bars, not ticks (the limit-fill rule is conservative; the replay check in s2 agrees within ~$50 over twelve weeks);
one feed (FTMO demo); no swap (it would lower the totals: layers are held for days to months); one geometry (t3) and
cap; descriptive, not pre-registered: no decision rule was set in advance, and the conclusion rests on its size and
consistency (three losing years, 79% of twelve-month windows negative), not on a test.

## 7. FILES

`run_bars.py` (the run; `--fill market | limit`); `out_limit/cont_<PAIR>.json` (the result), `out_market/cont_<PAIR>.json`
(the flawed run, kept for the record); `MANIFEST.md` (sha256 of each).

Line count: 92
