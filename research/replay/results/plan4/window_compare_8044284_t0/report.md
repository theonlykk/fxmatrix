# Replay vs archive, harness 8044284_t0 (compare.py)

T0 touches on the ORDER price.

| fleet | T0 | T1 matched / touchable | T1 all | replay-only | T1 | unpriced segs (share) | T2 | T1 on deal price (reported) |
|---|---|---|---|---|---|---|---|---|
| B | 410 / 410 | 369 / 410 = 90.0% | 90.0% | 41 = 10.0% | FAIL | 61 (100.0%) | FAIL | 72.7% / 27.3% |
| C | 436 / 438 | 389 / 436 = 89.2% | 89.0% | 45 = 10.3% | FAIL | 71 (100.0%) | FAIL | 68.3% / 31.3% |
| D | 314 / 314 | 282 / 314 = 89.8% | 89.8% | 25 = 8.0% | FAIL | 81 (100.0%) | FAIL | 71.0% / 26.8% |

## T1 per segment (sync)

| fleet | seg | real | touch | matched | replay | replay-only | free run matched |
|---|---|---|---|---|---|---|---|
| B | 61 | 410 | 410 | 369 | 410 | 41 | 93 |
| C | 71 | 438 | 436 | 390 | 435 | 45 | 87 |
| D | 81 | 314 | 314 | 282 | 307 | 25 | 32 |

## T2 per side (free, priced segments)

| fleet | side | S real / rep | R real / rep | ROLL_ACCEPTED real / rep | rho real / rep | pass |
|---|---|---|---|---|---|---|
| B | L | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| B | S | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| C | L | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| C | S | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| D | L | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| D | S | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |

## T2 per segment and side (free; S / R / A / open pips, real vs rep)

| fleet | seg | side | real | rep |
|---|---|---|---|---|
| B | 61 | L | 86 / 17 / 18 / -63.4 | 88 / 18 / 19 / -73.0 |
| B | 61 | S | 86 / 15 / 17 / -371.6 | 87 / 16 / 18 / -479.2 |
| C | 71 | L | 88 / 20 / 20 / -70.0 | 80 / 21 / 21 / -81.6 |
| C | 71 | S | 90 / 19 / 24 / -364.3 | 105 / 19 / 24 / -351.2 |
| D | 81 | L | 80 / 6 / 6 / -69.1 | 71 / 9 / 9 / -71.5 |
| D | 81 | S | 55 / 14 / 17 / -351.6 | 54 / 13 / 17 / -340.0 |
