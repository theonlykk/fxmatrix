# Plan 3 score, harness 145f092, cut none (all deals)

| fleet | T0 | T1 matched / touchable | replay-only | T0 | T1 |
|---|---|---|---|---|---|
| B | 321 / 323 | 308 / 321 = 96.0% | 9 = 2.8% | PASS | PASS |
| C | 359 / 359 | 343 / 359 = 95.5% | 12 = 3.3% | PASS | PASS |
| D | 367 / 370 | 357 / 367 = 97.3% | 9 = 2.4% | PASS | PASS |

| fleet | side | scoreable | S real / rep (tol) | R real / rep (tol) | A real / rep (tol) | OUT |
|---|---|---|---|---|---|---|
| B | L | yes | 35 / 39 (4.26) | 28 / 28 (2.00) | 33 / 33 (4.67) |  |
| B | S | yes | 81 / 83 (4.28) | 8 / 8 (2.00) | 8 / 8 (2.29) |  |
| C | L | yes | 43 / 47 (4.58) | 29 / 29 (2.33) | 40 / 40 (4.43) |  |
| C | S | yes | 85 / 88 (5.04) | 10 / 10 (2.56) | 10 / 10 (2.62) |  |
| D | L | yes | 59 / 63 (2.75) | 24 / 23 (2.19) | 24 / 24 (3.69) | OUT |
| D | S | yes | 81 / 81 (5.34) | 9 / 9 (2.00) | 9 / 8 (2.62) |  |

- Count mark: OUT sides [('D', 'L')]; beyond 2 x tol none.
- Bias mark: S errors [4, 2, 4, 3, 4, 0], one sign False, sum +17 of 384 real S: pass.
- Difference mark:
  - L S C-B live +8 replay +8 (limit 4.58): ok
  - L S D-B live +24 replay +24 (limit 4.26): ok
  - L R C-B live +1 replay +1 (limit 2.33): ok
  - L R D-B live -4 replay -5 (limit 2.19): ok
  - S S C-B live +4 replay +5 (limit 5.04): ok
  - S S D-B live +0 replay -2 (limit 5.34): ok
  - S R C-B live +2 replay +2 (limit 2.56): ok
  - S R D-B live +1 replay +1 (limit 2.00): ok

**Verdict: PASS** (T0 and T1 pass; counts / bias / difference / scoreable: PASS).
