# Replay vs archive, harness 8044284 (compare.py)

T0 touches on the ORDER price.

| fleet | T0 | T1 matched / touchable | T1 all | replay-only | T1 | unpriced segs (share) | T2 | T1 on deal price (reported) |
|---|---|---|---|---|---|---|---|---|
| B | 410 / 410 | 406 / 410 = 99.0% | 99.0% | 2 = 0.5% | PASS | - (0.0%) | PASS | 96.8% / 2.7% |
| C | 436 / 438 | 426 / 436 = 97.7% | 97.3% | 5 = 1.1% | PASS | - (0.0%) | PASS | 96.3% / 2.5% |
| D | 314 / 314 | 310 / 314 = 98.7% | 98.7% | 2 = 0.6% | PASS | - (0.0%) | FAIL | 97.5% / 1.9% |

## T1 per segment (sync)

| fleet | seg | real | touch | matched | replay | replay-only | free run matched |
|---|---|---|---|---|---|---|---|
| B | 61 | 410 | 410 | 406 | 408 | 2 | 282 |
| C | 71 | 438 | 436 | 426 | 431 | 5 | 284 |
| D | 81 | 314 | 314 | 310 | 312 | 2 | 287 |

## T2 per side (free, priced segments)

| fleet | side | S real / rep | R real / rep | ROLL_ACCEPTED real / rep | rho real / rep | pass |
|---|---|---|---|---|---|---|
| B | L | 86 / 87 ok | 17 / 18 ok | 18 / 19 ok | 1.00 / 0.97 ok | PASS |
| B | S | 86 / 87 ok | 15 / 15 ok | 17 / 17 ok | 0.78 / 0.79 ok | PASS |
| C | L | 88 / 84 ok | 20 / 21 ok | 20 / 21 ok | 1.03 / 0.96 ok | PASS |
| C | S | 90 / 95 ok | 19 / 19 ok | 24 / 24 ok | 0.79 / 0.83 ok | PASS |
| D | L | 80 / 79 ok | 6 / 7 ok | 6 / 7 ok | 1.85 / 1.63 X | FAIL |
| D | S | 55 / 55 ok | 14 / 14 ok | 17 / 17 ok | 0.62 / 0.62 ok | PASS |

## T2 per segment and side (free; S / R / A / open pips, real vs rep)

| fleet | seg | side | real | rep |
|---|---|---|---|---|
| B | 61 | L | 86 / 17 / 18 / -63.4 | 87 / 18 / 19 / -63.4 |
| B | 61 | S | 86 / 15 / 17 / -371.6 | 87 / 15 / 17 / -376.3 |
| C | 71 | L | 88 / 20 / 20 / -70.0 | 84 / 21 / 21 / -70.0 |
| C | 71 | S | 90 / 19 / 24 / -364.3 | 95 / 19 / 24 / -364.3 |
| D | 81 | L | 80 / 6 / 6 / -69.1 | 79 / 7 / 7 / -69.1 |
| D | 81 | S | 55 / 14 / 17 / -351.6 | 55 / 14 / 17 / -351.6 |
