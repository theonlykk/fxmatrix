# Plan 3 score, harness 8044284_t0, cut 1792108800000

| fleet | T0 | T1 matched / touchable | replay-only | T0 | T1 |
|---|---|---|---|---|---|
| B | 114 / 114 | 99 / 114 = 86.8% | 19 = 16.7% | PASS | FAIL |
| C | 108 / 108 | 94 / 108 = 87.0% | 13 = 12.0% | PASS | FAIL |
| D | 127 / 127 | 114 / 127 = 89.8% | 10 = 7.9% | PASS | FAIL |

| fleet | side | scoreable | S real / rep (tol) | R real / rep (tol) | A real / rep (tol) | OUT |
|---|---|---|---|---|---|---|
| B | L | yes | 31 / 33 (3.01) | 0 / 0 (2.00) | 0 / 0 (3.30) |  |
| B | S | yes | 21 / 19 (3.03) | 4 / 5 (2.00) | 4 / 5 (2.00) |  |
| C | L | yes | 27 / 26 (3.24) | 0 / 0 (2.00) | 0 / 0 (3.13) |  |
| C | S | yes | 20 / 29 (3.57) | 6 / 6 (2.00) | 6 / 6 (2.00) | OUT |
| D | L | yes | 37 / 34 (2.00) | 0 / 0 (2.00) | 0 / 0 (2.61) | OUT |
| D | S | yes | 20 / 21 (3.77) | 5 / 5 (2.00) | 4 / 4 (2.00) |  |

- Count mark: OUT sides [('C', 'S'), ('D', 'L')]; beyond 2 x tol [('C', 'S', 'S')].
- Bias mark: S errors [2, -2, -1, 9, -3, 1], one sign False, sum +6 of 156 real S: pass.
- Difference mark:
  - L S C-B live -4 replay -7 (limit 3.24): ok
  - L S D-B live +6 replay +1 (limit 3.01): ok
  - L R C-B live +0 replay +0 (limit 2.00): ok
  - L R D-B live +0 replay +0 (limit 2.00): ok
  - S S C-B live -1 replay +10 (limit 3.57): ok
  - S S D-B live -1 replay +2 (limit 3.77): ok
  - S R C-B live +2 replay +1 (limit 2.00): ok
  - S R D-B live +1 replay +0 (limit 2.00): ok

**Verdict: FAIL** (T0 and T1 FAIL; counts / bias / difference / scoreable: FAIL).
