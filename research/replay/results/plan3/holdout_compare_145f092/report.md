# Replay vs archive, harness 145f092 (compare.py)

T0 touches on the ORDER price.

| fleet | T0 | T1 matched / touchable | T1 all | replay-only | T1 | unpriced segs (share) | T2 | T1 on deal price (reported) |
|---|---|---|---|---|---|---|---|---|
| B | 172 / 172 | 166 / 172 = 96.5% | 96.5% | 3 = 1.7% | PASS | - (0.0%) | PASS | 94.8% / 3.5% |
| C | 188 / 188 | 178 / 188 = 94.7% | 94.7% | 6 = 3.2% | FAIL | 41 (100.0%) | FAIL | 94.1% / 3.7% |
| D | 59 / 59 | 56 / 59 = 94.9% | 94.9% | 2 = 3.4% | FAIL | 51 (100.0%) | FAIL | 94.9% / 3.4% |

## T1 per segment (sync)

| fleet | seg | real | touch | matched | replay | replay-only | free run matched |
|---|---|---|---|---|---|---|---|
| B | 31 | 172 | 172 | 166 | 169 | 3 | 147 |
| C | 41 | 188 | 188 | 178 | 184 | 6 | 91 |
| D | 51 | 59 | 59 | 56 | 58 | 2 | 58 |

## T2 per side (free, priced segments)

| fleet | side | S real / rep | R real / rep | ROLL_ACCEPTED real / rep | rho real / rep | pass |
|---|---|---|---|---|---|---|
| B | L | 27 / 27 ok | 14 / 14 ok | 15 / 15 ok | 0.51 / 0.51 ok | PASS |
| B | S | 42 / 41 ok | 4 / 4 ok | 3 / 3 ok | 1.18 / 1.15 ok | PASS |
| C | L | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| C | S | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| D | L | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |
| D | S | 0 / 0 ok | 0 / 0 ok | 0 / 0 ok | n/a / n/a ok | PASS |

## T2 per segment and side (free; S / R / A / open pips, real vs rep)

| fleet | seg | side | real | rep |
|---|---|---|---|---|
| B | 31 | L | 27 / 14 / 15 / -12.2 | 27 / 14 / 15 / -12.2 |
| B | 31 | S | 42 / 4 / 3 / -136.4 | 41 / 4 / 3 / -136.4 |
| C | 41 | L | 28 / 16 / 16 / -8.8 | 26 / 16 / 16 / -7.1 |
| C | 41 | S | 45 / 5 / 5 / -153.4 | 46 / 5 / 5 / -153.4 |
| D | 51 | L | 8 / 4 / 4 / -23.9 | 8 / 4 / 4 / -23.9 |
| D | 51 | S | 14 / 3 / 3 / -136.4 | 14 / 3 / 3 / -136.4 |
