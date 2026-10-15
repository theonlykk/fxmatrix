# Replay vs archive, harness 8044284_t0 (compare.py)

T0 touches on the ORDER price.

| fleet | T0 | T1 matched / touchable | T1 all | replay-only | T1 | unpriced segs (share) | T2 | T1 on deal price (reported) |
|---|---|---|---|---|---|---|---|---|
| B | 172 / 172 | 159 / 172 = 92.4% | 92.4% | 11 = 6.4% | FAIL | 31 (100.0%) | FAIL | 76.7% / 22.1% |
| C | 188 / 188 | 171 / 188 = 91.0% | 91.0% | 22 = 11.7% | FAIL | 41 (100.0%) | FAIL | 74.5% / 28.2% |
| D | 59 / 59 | 53 / 59 = 89.8% | 89.8% | 4 = 6.8% | FAIL | 51 (100.0%) | FAIL | 69.5% / 27.1% |

## T1 per segment (sync)

| fleet | seg | real | touch | matched | replay | replay-only | free run matched |
|---|---|---|---|---|---|---|---|
| B | 31 | 172 | 172 | 159 | 170 | 11 | 64 |
| C | 41 | 188 | 188 | 171 | 193 | 22 | 73 |
| D | 51 | 59 | 59 | 53 | 57 | 4 | 21 |

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
| B | 31 | L | 27 / 14 / 15 / -12.2 | 26 / 14 / 15 / -11.8 |
| B | 31 | S | 42 / 4 / 3 / -136.4 | 44 / 4 / 3 / -135.8 |
| C | 41 | L | 28 / 16 / 16 / -8.8 | 26 / 16 / 16 / -8.6 |
| C | 41 | S | 45 / 5 / 5 / -153.4 | 46 / 5 / 5 / -162.4 |
| D | 51 | L | 8 / 4 / 4 / -23.9 | 8 / 4 / 4 / -24.9 |
| D | 51 | S | 14 / 3 / 3 / -136.4 | 13 / 3 / 3 / -147.0 |
