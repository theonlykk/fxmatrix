# Replay vs archive, harness 8044284 (compare.py)

T0 touches on the ORDER price.

| fleet | T0 | T1 matched / touchable | T1 all | replay-only | T1 | unpriced segs (share) | T2 | T1 on deal price (reported) |
|---|---|---|---|---|---|---|---|---|
| B | 172 / 172 | 172 / 172 = 100.0% | 100.0% | 0 = 0.0% | PASS | - (0.0%) | PASS | 98.3% / 1.7% |
| C | 188 / 188 | 184 / 188 = 97.9% | 97.9% | 4 = 2.1% | PASS | - (0.0%) | PASS | 97.9% / 2.1% |
| D | 59 / 59 | 59 / 59 = 100.0% | 100.0% | 0 = 0.0% | PASS | - (0.0%) | PASS | 100.0% / 0.0% |

## T1 per segment (sync)

| fleet | seg | real | touch | matched | replay | replay-only | free run matched |
|---|---|---|---|---|---|---|---|
| B | 31 | 172 | 172 | 172 | 172 | 0 | 148 |
| C | 41 | 188 | 188 | 184 | 188 | 4 | 91 |
| D | 51 | 59 | 59 | 59 | 59 | 0 | 59 |

## T2 per side (free, priced segments)

| fleet | side | S real / rep | R real / rep | ROLL_ACCEPTED real / rep | rho real / rep | pass |
|---|---|---|---|---|---|---|
| B | L | 27 / 27 ok | 14 / 14 ok | 15 / 15 ok | 0.51 / 0.51 ok | PASS |
| B | S | 42 / 41 ok | 4 / 4 ok | 3 / 3 ok | 1.18 / 1.15 ok | PASS |
| C | L | 28 / 26 ok | 16 / 16 ok | 16 / 16 ok | 0.56 / 0.54 ok | PASS |
| C | S | 45 / 46 ok | 5 / 5 ok | 5 / 5 ok | 1.15 / 1.18 ok | PASS |
| D | L | 8 / 8 ok | 4 / 4 ok | 4 / 4 ok | 0.43 / 0.43 ok | PASS |
| D | S | 14 / 14 ok | 3 / 3 ok | 3 / 3 ok | 0.55 / 0.55 ok | PASS |

## T2 per segment and side (free; S / R / A / open pips, real vs rep)

| fleet | seg | side | real | rep |
|---|---|---|---|---|
| B | 31 | L | 27 / 14 / 15 / -12.2 | 27 / 14 / 15 / -12.2 |
| B | 31 | S | 42 / 4 / 3 / -136.4 | 41 / 4 / 3 / -136.4 |
| C | 41 | L | 28 / 16 / 16 / -8.8 | 26 / 16 / 16 / -7.1 |
| C | 41 | S | 45 / 5 / 5 / -153.4 | 46 / 5 / 5 / -153.4 |
| D | 51 | L | 8 / 4 / 4 / -23.9 | 8 / 4 / 4 / -23.9 |
| D | 51 | S | 14 / 3 / 3 / -136.4 | 14 / 3 / 3 / -136.4 |
