# Plan 3 score, harness 8044284, cut 1791531120000

| fleet | T0 | T1 matched / touchable | replay-only | T0 | T1 |
|---|---|---|---|---|---|
| B | 69 / 69 | 69 / 69 = 100.0% | 0 = 0.0% | PASS | PASS |
| C | 72 / 72 | 72 / 72 = 100.0% | 0 = 0.0% | PASS | PASS |
| D | 59 / 59 | 59 / 59 = 100.0% | 0 = 0.0% | PASS | PASS |

| fleet | side | scoreable | S real / rep (tol) | R real / rep (tol) | A real / rep (tol) | OUT |
|---|---|---|---|---|---|---|
| B | L | yes | 10 / 10 (3.01) | 7 / 7 (2.00) | 5 / 5 (3.30) |  |
| B | S | yes | 15 / 14 (3.03) | 3 / 3 (2.00) | 3 / 3 (2.00) |  |
| C | L | no | 7 / 6 (3.24) | 8 / 8 (2.00) | 6 / 6 (3.13) |  |
| C | S | yes | 16 / 17 (3.57) | 5 / 5 (2.00) | 5 / 5 (2.00) |  |
| D | L | no | 8 / 8 (2.00) | 4 / 4 (2.00) | 4 / 4 (2.61) |  |
| D | S | yes | 14 / 14 (3.77) | 3 / 3 (2.00) | 3 / 3 (2.00) |  |

- Count mark: OUT sides none; beyond 2 x tol none.
- Bias mark: S errors [0, -1, 1, 0], one sign False, sum +0 of 55 real S: pass.
- Difference mark:
  - S S C-B live +1 replay +3 (limit 3.57): ok
  - S S D-B live -1 replay +0 (limit 3.77): ok
  - S R C-B live +2 replay +2 (limit 2.00): ok
  - S R D-B live +0 replay +0 (limit 2.00): ok

**Verdict: PASS** (T0 and T1 pass; counts / bias / difference / scoreable: PASS).
