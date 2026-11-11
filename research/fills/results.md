This message has a line count at the bottom

# DO LIVE LIMIT FILLS GET A BETTER PRICE THAN THE LIMIT? (11 Nov 2026; descriptive)

| | |
|---|---|
| Why | Fable's blind review (`reviews/fable_pass1/report_pass1.md` s4.6, s6.2 item 2) named the fill-price convention the largest unknown in every bar result: on ticks, "deal at the market of the touching tick" is worth 0.08 to 0.46 pip a fill over "deal at the limit", as much as the commission on the majors. It asked for it to be measured, not assumed. |
| Data | pipshed's exports of 11 Nov (`docs/runbooks/winddown-export.md` s5): `fill_logs` from the whole archive, `send_logs` of every instance (kept 14 days, so fills from 28 Oct 06:00Z). |
| Method | `measure_fills.py`: each ENT / EXT fill against the price its order was RESTING at when it filled (the last successful PENDING or MODIFY before the fill); `fill_logs.order_price_open` is the first price and 9.1% of orders were modified first. Output: `measure_fills_output.txt`. |
| Answer | **Partly.** On both brokers a touched limit is executed at the market just after the touch: on average better than the limit (+0.09 to +0.13 pip a fill), but about a sixth of fills are WORSE than the limit (up to 4 pips). That is between the two conventions Fable carried, nearer "at the limit". |

## 1. THE MEASUREMENT (9,849 fills, 28 Oct - 11 Nov 2026)

| | fills | mean pips (se) | at the limit | better | worse | worst |
|---|---|---|---|---|---|---|
| IC (B, C, D) entries | 4,456 | +0.112 (0.012) | 41.7% | 41.1% | 17.2% | -3.7 |
| IC exits | 4,442 | +0.129 (0.013) | 40.9% | 42.5% | 16.6% | -4.0 |
| FTMO (E) entries | 482 | +0.101 (0.010) | 41.7% | 46.7% | 11.6% | -0.5 |
| FTMO exits | 469 | +0.094 (0.011) | 43.7% | 40.7% | 15.6% | -0.4 |

By pair, against Fable's tick estimate under "deal at the market of the touching tick" (`reviews/fable_pass1/out/
10_fill_improvement.txt`, IC ticks Aug-Oct, live arms):

| pair | live, IC | live, FTMO | Fable's ticks (OPT arm) |
|---|---|---|---|
| EURUSD | +0.186 | +0.110 | +0.252 |
| GBPUSD | +0.176 | +0.130 | +0.312 |
| AUDCAD | +0.084 | | +0.266 |
| AUDCHF | +0.059 | | +0.143 |
| EURGBP | +0.043 | | +0.080 |
| CADCHF | +0.024 | | +0.079 |

## 2. WHAT IT MEANS

- Live fills keep roughly a third to three quarters of the touching-tick improvement, less on FTMO than on IC; per
  round trip about +0.2 to +0.4 pip on EURUSD and GBPUSD, against 0.6 pip of commission, and under +0.2 on the
  crosses.
- Fable's four-year bars put the small OPT arms at about -77, -69 and -25 USD a month even with the FULL market
  convention (report s4.6). With only part of it, they lose more. **The largest unknown resolves against the
  strategy; no conclusion of `research/longrun/` or `research/nocarry/` changes.**
- "Worse than the limit" by up to 4 pips is what a triggered pending order executed at the market in a fast move
  does; the replay's "deal at the market 261 ms later" (MECHANICS s4) models exactly this.
- Limits: two weeks; a different period from Fable's ticks; all rungs and roles pooled; fills whose order was
  placed before 28 Oct are not matched (376 IC, 73 FTMO).

Line count: 46
