# Plan 3 score, harness 8044284, cut 1792108800000

| fleet | T0 | T1 matched / touchable | replay-only | T0 | T1 |
|---|---|---|---|---|---|
| B | 114 / 114 | 112 / 114 = 98.2% | 2 = 1.8% | PASS | PASS |
| C | 108 / 108 | 107 / 108 = 99.1% | 0 = 0.0% | PASS | PASS |
| D | 127 / 127 | 126 / 127 = 99.2% | 0 = 0.0% | PASS | PASS |

| fleet | side | scoreable | S real / rep (tol) | R real / rep (tol) | A real / rep (tol) | OUT |
|---|---|---|---|---|---|---|
| B | L | yes | 31 / 31 (3.01) | 0 / 0 (2.00) | 0 / 0 (3.30) |  |
| B | S | yes | 21 / 21 (3.03) | 4 / 4 (2.00) | 4 / 4 (2.00) |  |
| C | L | yes | 27 / 27 (3.24) | 0 / 0 (2.00) | 0 / 0 (3.13) |  |
| C | S | yes | 20 / 22 (3.57) | 6 / 6 (2.00) | 6 / 6 (2.00) |  |
| D | L | yes | 37 / 37 (2.00) | 0 / 0 (2.00) | 0 / 0 (2.61) |  |
| D | S | yes | 20 / 20 (3.77) | 5 / 5 (2.00) | 4 / 4 (2.00) |  |

- Count mark: OUT sides none; beyond 2 x tol none.
- Bias mark: S errors [0, 0, 0, 2, 0, 0], one sign False, sum +2 of 156 real S: pass.
- Difference mark:
  - L S C-B live -4 replay -4 (limit 3.24): ok
  - L S D-B live +6 replay +6 (limit 3.01): ok
  - L R C-B live +0 replay +0 (limit 2.00): ok
  - L R D-B live +0 replay +0 (limit 2.00): ok
  - S S C-B live -1 replay +1 (limit 3.57): ok
  - S S D-B live -1 replay -1 (limit 3.77): ok
  - S R C-B live +2 replay +2 (limit 2.00): ok
  - S R D-B live +1 replay +1 (limit 2.00): ok

**Verdict: PASS** (T0 and T1 pass; counts / bias / difference / scoreable: PASS).
