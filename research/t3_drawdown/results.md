This message has a line count at the bottom

# t3 AT 0.01 LOTS: COMMISSION, DRAWDOWN AND FTMO'S DAILY LOSS (24 Oct 2026; descriptive, no selection)

**Why (operator, 24 Oct ~18:40-18:42Z):** "Having a strategy that makes less than $100 a month isnt very impressive";
"we are seeing the expected results of running a short gamma strategy on a random walk ... squeezing the limited 'non
random walk' part of the mkt action out - but that is eaten away by commission". Measures fixed in chat before
computing (HANDOFF s90 continued 2).

## 1. ONE WORKED EXAMPLE

GBPUSD OPT (add 9), 1-20 Oct: 324 closes x $0.06 = $19.44 commission; +$2.66 before commission; net -$16.78.

## 2. INPUTS (the replay's own outputs; nothing re-run)

October: sweep9 (EURUSD, `out_sw9_d7`), sweep10 (five pairs), `sw11o_eurgbp` (EURGBP OPT 5) deals, events and run files,
each equal to its committed sha256 (sw9 / sw10 / sw11 manifests); the October ticks equal to the hashes in
`sweep_notes` (EURUSD `w2hw` `93816e45...`). Calm: sweep11's committed tables and `out_sw11w_*_summary.txt`.
Scripts: `t3dd.py` (day-end, committed curves), `intraday.py` (5-minute marks with `score9`'s accounting; every
committed cell reproduced to 0.1 pip), `fleet.py` (the twelve cells as one account), `calm_comm.py`.

## 3. RESULTS (USD at 0.01 lots; 12 cells as one account)

- **Both periods: about $91 a month** (sweep11's +$230.64 over about 11 weeks; in-sample adds).
- **Commission / gross: calm 38% ($133.80 of $348.85); October 84% ($88 of $105).** The tight OPT arms paid most of it:
  calm they kept +$130.49 net after $103.44; in October they lost before commission.
- **October balance against equity:** the closed balance rose to +$492.72 by 16 Oct while the stacks' open loss grew
  from -$196.51 (end of 1 Oct) to -$514.56 (16 Oct): equity peaked +$174.77 (13 Oct 07:45Z), low -$133.79 (16 Oct
  14:30Z), max peak-to-trough $308.57 (day-end marks: $216).
- **FTMO's daily loss (day-start balance - the day's lowest equity): $120 on day 1; over $300 on 11 of 20 days from
  8 Oct; $626.51 on the FTMO day ending 16 Oct 22:00Z.** At 0.01 lots, t3 replayed through October breaches the
  trial's $500 on 16 Oct and Instant's $300 from 8 Oct; Instant's trailing 10% reaches $641.92 of $1,000.
- **Scaling cannot fix it:** the limit is crossed at 1 x; $1,000 a month needs about 11 x.

## 4. READING

The scalps are the premium of a short-gamma book; the open stacks are its mark-to-market. FTMO measures each day
against the premium already banked, so the binding constraint is the inventory carried, not the day's move.

## 5. LIMITS

Every cell starts flat on 1 Oct (a burst day; E started flat 23 Oct); every pair on the EURUSD chart; in-sample adds;
FTMO's daily-loss rule as recorded in C164 and E's runbook (floating loss counts against the day-start balance), not
re-read on FTMO's site.

Line count: 46
