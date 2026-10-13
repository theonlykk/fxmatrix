# sweep7 (pre-registered; one flat start, eight weeks carried; pips at 0.01 lots after commission; timing 0, carry off, cap 8; reported, never deciding)

Self-checks passed: every rebuilt book equals the harness's end book; closes and realised equal SCALP_CLOSED.

## Q1: carried eight weeks (live) against flat every Monday (sweep4, live, 8-week sum)

| pair | carried net | sweep4 weekly sum | carried - weekly | open at end (n) | worst floating (at) |
|---|---|---|---|---|---|
| EURUSD | -301 | -39 | -262 | -387 (13) | -901 (2026-09-22 11:33) |
| GBPUSD | -271 | +521 | -792 | -679 (13) | -1291 (2026-09-23 13:45) |
| EURGBP | +121 | +252 | -130 | -96 (9) | -415 (2026-08-20 00:01) |
| AUDCAD | -664 | -570 | -94 | -312 (12) | -1026 (2026-08-27 10:05) |
| AUDCHF | -748 | -691 | -57 | -72 (11) | -866 (2026-09-03 00:59) |
| CADCHF | +125 | -11 | +136 | -118 (11) | -594 (2026-08-17 00:05) |
| NZDCHF | +75 | +83 | -8 | -83 (10) | -449 (2026-08-20 00:27) |
| NZDCAD | -256 | +124 | -379 | -780 (13) | -1152 (2026-09-08 10:54) |
| AUDNZD | -2353 | -2541 | +188 | -654 (15) | -1430 (2026-09-02 12:01) |

## Q2: width 0.2 against the live width (both carried eight weeks)

| pair | net live / 0.2 | S live / 0.2 | R live / 0.2 | A live / 0.2 | requests a day live / 0.2 | worst floating live / 0.2 |
|---|---|---|---|---|---|---|
| EURUSD | -301 / -199 | 335 / 353 | 57 / 54 | 75 / 74 | 68 / 68 | -901 / -956 |
| GBPUSD | -271 / -127 | 459 / 465 | 61 / 57 | 80 / 76 | 116 / 114 | -1291 / -1714 |
| EURGBP | +121 / +318 | 317 / 336 | 62 / 56 | 65 / 59 | 107 / 103 | -415 / -388 |
| AUDCAD | -664 / -282 | 389 / 369 | 84 / 79 | 104 / 93 | 96 / 87 | -1026 / -819 |
| AUDCHF | -748 / -846 | 209 / 201 | 64 / 61 | 107 / 106 | 74 / 71 | -866 / -841 |
| CADCHF | +125 / +146 | 189 / 198 | 56 / 49 | 75 / 71 | 56 / 57 | -594 / -706 |
| NZDCHF | +75 / -18 | 194 / 176 | 90 / 85 | 106 / 102 | 73 / 67 | -449 / -474 |
| NZDCAD | -256 / -418 | 308 / 300 | 49 / 49 | 59 / 58 | 95 / 89 | -1152 / -1013 |
| AUDNZD | -2353 / -2330 | 377 / 395 | 80 / 83 | 103 / 104 | 167 / 168 | -1430 / -1252 |

## The pairs' floating summed in dollars, minute by minute (A's gate and breaker NOT modelled)

| setting | pairs | worst (at, server) | minutes below -$250 | minutes below -$400 | net at the end ($) |
|---|---|---|---|---|---|
| live | nine | -497 (2026-09-02 16:08) | 40977 | 2399 | -309 |
| live | A's seven | -445 (2026-09-02 16:08) | 25218 | 528 | -270 |
| live_w0.2 | nine | -509 (2026-09-03 00:05) | 41844 | 4047 | -262 |
| live_w0.2 | A's seven | -440 (2026-09-03 00:01) | 30682 | 260 | -239 |
