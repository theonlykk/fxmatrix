# Plan 3 score, harness 8044284_t0, cut none (all deals)

| fleet | T0 | T1 matched / touchable | replay-only | T0 | T1 |
|---|---|---|---|---|---|
| B | 321 / 323 | 292 / 321 = 91.0% | 32 = 9.9% | PASS | FAIL |
| C | 359 / 359 | 314 / 359 = 87.5% | 53 = 14.8% | PASS | FAIL |
| D | 367 / 370 | 320 / 367 = 87.2% | 45 = 12.2% | PASS | FAIL |

| fleet | side | scoreable | S real / rep (tol) | R real / rep (tol) | A real / rep (tol) | OUT |
|---|---|---|---|---|---|---|
| B | L | yes | 35 / 40 (4.26) | 28 / 28 (2.00) | 33 / 33 (4.67) | OUT |
| B | S | yes | 81 / 84 (4.28) | 8 / 8 (2.00) | 8 / 7 (2.29) |  |
| C | L | yes | 43 / 46 (4.58) | 29 / 29 (2.33) | 40 / 40 (4.43) |  |
| C | S | yes | 85 / 87 (5.04) | 10 / 9 (2.56) | 10 / 11 (2.62) |  |
| D | L | yes | 59 / 61 (2.75) | 24 / 23 (2.19) | 24 / 24 (3.69) |  |
| D | S | yes | 81 / 79 (5.34) | 9 / 9 (2.00) | 9 / 9 (2.62) |  |

- Count mark: OUT sides [('B', 'L')]; beyond 2 x tol none.
- Bias mark: S errors [5, 3, 3, 2, 2, -2], one sign False, sum +13 of 384 real S: pass.
- Difference mark:
  - L S C-B live +8 replay +6 (limit 4.58): ok
  - L S D-B live +24 replay +21 (limit 4.26): ok
  - L R C-B live +1 replay +1 (limit 2.33): ok
  - L R D-B live -4 replay -5 (limit 2.19): ok
  - S S C-B live +4 replay +3 (limit 5.04): ok
  - S S D-B live +0 replay -5 (limit 5.34): ok
  - S R C-B live +2 replay +1 (limit 2.56): ok
  - S R D-B live +1 replay +1 (limit 2.00): ok

**Verdict: FAIL** (T0 and T1 FAIL; counts / bias / difference / scoreable: PASS).
