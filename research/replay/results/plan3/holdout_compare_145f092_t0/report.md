# Replay vs archive, harness 145f092_t0 (compare.py)

T0 touches on the ORDER price.

| fleet | T0 | T1 matched / touchable | T1 all | replay-only | T1 | unpriced segs (share) | T2 | T1 on deal price (reported) |
|---|---|---|---|---|---|---|---|---|
| B | 172 / 172 | 167 / 172 = 97.1% | 97.1% | 3 = 1.7% | PASS | - (0.0%) | PASS | 82.0% / 16.9% |
| C | 188 / 188 | 181 / 188 = 96.3% | 96.3% | 6 = 3.2% | PASS | - (0.0%) | PASS | 81.4% / 18.1% |
| D | 59 / 59 | 56 / 59 = 94.9% | 94.9% | 2 = 3.4% | FAIL | 51 (100.0%) | FAIL | 76.3% / 22.0% |

## T1 per segment (sync)

| fleet | seg | real | touch | matched | replay | replay-only | free run matched |
|---|---|---|---|---|---|---|---|
| B | 31 | 172 | 172 | 167 | 170 | 3 | 63 |
| C | 41 | 188 | 188 | 181 | 187 | 6 | 71 |
| D | 51 | 59 | 59 | 56 | 58 | 2 | 20 |

## T2 per side (free, priced segments)

| fleet | side | S real / rep | R real / rep | ROLL_ACCEPTED real / rep | rho real / rep | pass |
|---|---|---|---|---|---|---|
| B | L | 27 / 26 ok | 14 / 14 ok | 15 / 15 ok | 0.51 / 0.50 ok | PASS |
| B | S | 42 / 44 ok | 4 / 4 ok | 3 / 3 ok | 1.18 / 1.23 ok | PASS |
| C | L | 28 / 26 ok | 16 / 16 ok | 16 / 16 ok | 0.56 / 0.54 ok | PASS |
| C | S | 45 / 46 ok | 5 / 5 ok | 5 / 5 ok | 1.15 / 1.15 ok | PASS |
| D | L | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| D | S | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |

## T2 per segment and side (free; S / R / A / open pips, real vs rep)

| fleet | seg | side | real | rep |
|---|---|---|---|---|
| B | 31 | L | 27 / 14 / 15 / -12.2 | 26 / 14 / 15 / -11.8 |
| B | 31 | S | 42 / 4 / 3 / -136.4 | 44 / 4 / 3 / -135.8 |
| C | 41 | L | 28 / 16 / 16 / -8.8 | 26 / 16 / 16 / -8.6 |
| C | 41 | S | 45 / 5 / 5 / -153.4 | 46 / 5 / 5 / -162.4 |
| D | 51 | L | 8 / 4 / 4 / -23.9 | 8 / 4 / 4 / -24.9 |
| D | 51 | S | 14 / 3 / 3 / -136.4 | 13 / 3 / 3 / -147.0 |
