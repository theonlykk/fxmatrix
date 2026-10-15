# Plan 3 score, harness 8044284_t0, cut 1791531120000

| fleet | T0 | T1 matched / touchable | replay-only | T0 | T1 |
|---|---|---|---|---|---|
| B | 69 / 69 | 62 / 69 = 89.9% | 2 = 2.9% | PASS | FAIL |
| C | 72 / 72 | 64 / 72 = 88.9% | 8 = 11.1% | PASS | FAIL |
| D | 59 / 59 | 53 / 59 = 89.8% | 4 = 6.8% | PASS | FAIL |

| fleet | side | scoreable | S real / rep (tol) | R real / rep (tol) | A real / rep (tol) | OUT |
|---|---|---|---|---|---|---|
| B | L | yes | 10 / 10 (3.01) | 7 / 7 (2.00) | 5 / 5 (3.30) |  |
| B | S | yes | 15 / 14 (3.03) | 3 / 3 (2.00) | 3 / 3 (2.00) |  |
| C | L | no | 7 / 6 (3.24) | 8 / 8 (2.00) | 6 / 6 (3.13) |  |
| C | S | yes | 16 / 16 (3.57) | 5 / 5 (2.00) | 5 / 5 (2.00) |  |
| D | L | no | 8 / 8 (2.00) | 4 / 4 (2.00) | 4 / 4 (2.61) |  |
| D | S | yes | 14 / 13 (3.77) | 3 / 3 (2.00) | 3 / 3 (2.00) |  |

- Count mark: OUT sides none; beyond 2 x tol none.
- Bias mark: S errors [0, -1, 0, -1], one sign False, sum -2 of 55 real S: pass.
- Difference mark:
  - S S C-B live +1 replay +2 (limit 3.57): ok
  - S S D-B live -1 replay -1 (limit 3.77): ok
  - S R C-B live +2 replay +2 (limit 2.00): ok
  - S R D-B live +0 replay +0 (limit 2.00): ok

**Verdict: FAIL** (T0 and T1 FAIL; counts / bias / difference / scoreable: PASS).
