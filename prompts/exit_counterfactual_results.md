This message has a line count at the bottom

# EXIT_PIPS COUNTERFACTUAL -- RESULTS

Method: `prompts/exit_counterfactual_prereg.md`, locked at A2 (`718b732`),
amended A3 after parity only (`9823fb6`). Code:
`scripts/exit_counterfactual_replay.py`. Run 2026-09-20. All figures in
pips at 0.01 lot; "net" is after FTMO commission, "gross" before.

---

## 1. VERDICT

| group | net per day selects | net per position-day selects | holdout | recommendation |
|---|---|---|---|---|
| majors | nothing (curve below zero at every X) | nothing | live config beat X=3 and X=5 | **keep live values; do not tighten** |
| EURGBP | **X = 11** (acceptable set 9-14) | nothing (maximum at the X=3 boundary) | **X=11 ACCEPTED**, +100 pips, interval [+37, +153] | **widen, subject to the metric ruling** |
| crosses | X = 14 (set 13-15) | X = 6 (set 6-7) | X=14 rejected; X=6 passes but indistinguishable | **inconclusive; keep live values** |
| NZD | diagnostic only (A2) | diagnostic only | not tested | keep live values (A2) |

**The two co-primary metrics disagree for EURGBP and for crosses.** Per
day rewards wider exits; per position-day rewards tighter ones. The
regime stated before the curves (A3) is guard-BINDING, so the tie-breaker
does not apply and **the disagreement goes to Gemini.**

**What it means for geometry cycle 2** (which changed exits by hand):

- **EURGBP ALT 8 -> 6** goes AGAINST the per-day result (which says widen
  to about 11) and WITH the per-position-day result.
- **EURUSD OPT 7 -> 5 and ALT 10 -> 7** have no support: majors select
  nothing, and on the holdout the live configuration beat both X=3
  (significantly) and X=5 (not significantly).
- **Crosses ALT 10 -> 7** sits in the per-position-day region (6-7) and
  against the per-day region (13-15). Undecided until the metric ruling.

---

## 2. PARITY (s9, after A3)

- All 16 arms pass. Observed scalps filled by the replay: 610 of 612.
  99.7% of real exits land within one minute of the replay's fill minute.
- Classification by side and by pre/post ADR-151: 99.4% to 100%.
- Monotonicity invariant over X = 3 to 15: zero violations.
- USD per pip per 0.01 lot: GBPUSD, EURUSD 0.100 (exact); EURGBP 0.134;
  AUDCAD 0.0714; AUDCHF 0.122; CADCHF 0.122; NZDCAD 0.0717; AUDNZD 0.0574.
  Commission per scalp is therefore 0.45 pip (EURGBP) to 1.05 pip
  (AUDNZD).

---

## 3. CALIBRATION CURVES (entries on 10, 14, 16, 18 Sep; per day over 4)

Totals include every layer: fills at X, manual closes at their actual
price, open layers marked at the 18-Sep 23:54 close.

### majors

| X | fills | gross | comm | net | net/day | pos-days | net/pos-day |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 3 | 171 | -817 | 119 | -936 | -233.9 | 39.5 | -23.70 |
| 4 | 164 | -915 | 117 | -1033 | -258.1 | 51.4 | -20.11 |
| 5 | 161 | -954 | 117 | -1072 | -267.9 | 56.4 | -19.00 |
| 6 | 150 | -1374 | 117 | -1491 | -372.6 | 68.8 | -21.67 |
| 7 | 145 | -1728 | 116 | -1844 | -461.1 | 78.5 | -23.49 |
| 8 | 136 | -2151 | 114 | -2265 | -566.2 | 96.0 | -23.60 |
| 9 | 133 | -2097 | 113 | -2210 | -552.6 | 103.3 | -21.40 |
| 10 | 132 | -2051 | 113 | -2164 | -541.1 | 106.1 | -20.40 |
| 11 | 131 | -1932 | 113 | -2045 | -511.3 | 110.1 | -18.58 |
| 12 | 128 | -1913 | 112 | -2026 | -506.4 | 117.4 | -17.25 |
| 13 | 124 | -2125 | 111 | -2236 | -559.0 | 131.8 | -16.96 |
| 14 | 123 | -2080 | 111 | -2190 | -547.6 | 137.3 | -15.95 |
| 15 | 123 | -1957 | 111 | -2067 | -516.8 | 140.5 | -14.71 |

### EURGBP

| X | fills | gross | comm | net | net/day | pos-days | net/pos-day |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 3 | 46 | 115 | 21 | 93 | 23.4 | 17.1 | 5.47 |
| 4 | 45 | 159 | 21 | 137 | 34.3 | 20.1 | 6.85 |
| 5 | 45 | 204 | 21 | 182 | 45.6 | 31.4 | 5.81 |
| 6 | 42 | 186 | 21 | 165 | 41.3 | 39.5 | 4.18 |
| 7 | 38 | 158 | 20 | 139 | 34.6 | 57.5 | 2.41 |
| 8 | 38 | 196 | 20 | 177 | 44.1 | 67.1 | 2.63 |
| 9 | 37 | 211 | 19 | 191 | 47.8 | 79.5 | 2.40 |
| 10 | 37 | 248 | 19 | 228 | 57.1 | 80.0 | 2.85 |
| 11 | 35 | 219 | 19 | 200 | 50.0 | 85.5 | 2.34 |
| 12 | 34 | 231 | 19 | 212 | 52.9 | 90.9 | 2.33 |
| 13 | 31 | 211 | 18 | 193 | 48.2 | 99.4 | 1.94 |
| 14 | 30 | 210 | 18 | 192 | 47.9 | 123.4 | 1.55 |
| 15 | 27 | 159 | 17 | 142 | 35.5 | 133.4 | 1.06 |

### crosses

| X | fills | gross | comm | net | net/day | pos-days | net/pos-day |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 3 | 142 | 155 | 108 | 47 | 11.8 | 50.8 | 0.93 |
| 4 | 139 | 279 | 107 | 172 | 42.9 | 56.8 | 3.02 |
| 5 | 134 | 341 | 107 | 235 | 58.6 | 67.3 | 3.49 |
| 6 | 133 | 465 | 106 | 359 | 89.6 | 74.0 | 4.85 |
| 7 | 129 | 569 | 105 | 464 | 116.1 | 81.0 | 5.73 |
| 8 | 121 | 409 | 102 | 306 | 76.5 | 116.7 | 2.62 |
| 9 | 119 | 500 | 102 | 398 | 99.5 | 120.0 | 3.32 |
| 10 | 115 | 544 | 101 | 443 | 110.9 | 136.4 | 3.25 |
| 11 | 110 | 478 | 99 | 379 | 94.6 | 150.9 | 2.51 |
| 12 | 110 | 588 | 99 | 489 | 122.1 | 152.4 | 3.21 |
| 13 | 109 | 669 | 99 | 570 | 142.5 | 155.9 | 3.65 |
| 14 | 107 | 710 | 98 | 612 | 152.9 | 161.0 | 3.80 |
| 15 | 102 | 517 | 96 | 421 | 105.2 | 186.4 | 2.26 |

### NZD

| X | fills | gross | comm | net | net/day | pos-days | net/pos-day |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 3 | 66 | 46 | 71 | -25 | -6.2 | 14.0 | -1.78 |
| 4 | 64 | 93 | 71 | 22 | 5.6 | 15.1 | 1.47 |
| 5 | 61 | 128 | 69 | 59 | 14.7 | 16.6 | 3.55 |
| 6 | 61 | 189 | 69 | 120 | 30.0 | 18.1 | 6.60 |
| 7 | 59 | 248 | 69 | 179 | 44.8 | 20.2 | 8.90 |
| 8 | 58 | 295 | 69 | 227 | 56.7 | 22.4 | 10.15 |
| 9 | 55 | 242 | 67 | 175 | 43.7 | 25.4 | 6.90 |
| 10 | 54 | 219 | 66 | 152 | 38.0 | 28.1 | 5.41 |
| 11 | 54 | 273 | 66 | 206 | 51.5 | 28.4 | 7.27 |
| 12 | 48 | 132 | 64 | 68 | 17.1 | 34.6 | 1.98 |
| 13 | 47 | 158 | 63 | 94 | 23.5 | 36.0 | 2.61 |
| 14 | 45 | 186 | 63 | 123 | 30.8 | 36.9 | 3.33 |
| 15 | 45 | 231 | 63 | 168 | 42.0 | 38.2 | 4.40 |

**Why majors are negative at every X.** The majors calibration days include
16-Sep, FOMC night, when GBPUSD and EURUSD built deep ladders that were
still underwater at the window end or were closed manually. Those layers
never reach any X from 3 to 15, so they contribute the same large negative
amount at every X. The pre-registered rule ("at least 90% of the maximum")
cannot be applied to a curve whose maximum is negative, so it selects
nothing -- see s6.

---

## 4. HOLDOUT (entries on 11, 15, 17 Sep; like-for-like, s10)

The same holdout layers replayed at X* and at each layer's own live X.
Bootstrap: 2,000 resamples of layers, seed 20260920, 5th-95th percentile
of the difference.

| group | X* (from) | n | net at X* | net at live | difference | interval | result |
|---|---|---:|---:|---:|---:|---|---|
| EURGBP | 11 (per day) | 44 | 117 | 17 | +100 | [+37, +153] | **ACCEPT** |
| crosses | 14 (per day) | 90 | -96 | -84 | -12 | [-220, +174] | reject, indistinguishable |
| crosses | 6 (per pos-day) | 90 | 26 | -84 | +110 | [-16, +266] | accept, indistinguishable |
| majors | 3 (info) | 109 | 131 | 477 | -346 | [-543, -85] | live significantly better |
| majors | 5 (info) | 109 | 345 | 477 | -132 | [-331, +140] | live better, indistinguishable |

EURGBP's is the only result whose interval excludes zero.

Available horizon (window end minus entry): calibration mean 3.1 days,
holdout 2.5 days.

---

## 5. SENSITIVITIES

| case | majors | EURGBP (per day) | crosses (per day / per pos-day) |
|---|---|---|---|
| primary | none | 11 | 14 / 6 |
| S2 manual rule B | none | 11 | 14 / 6 |
| S4 entries before ADR-151 | none | 10 | 14 / 6 |
| S5 window ends 17-Sep | none | 11 | 14 / 6 |

**EURGBP's selection is stable at 10-11 across every sensitivity.** Per
arm (diagnostic), both EURGBP arms earn more at wider X over the full
window: OPT 130 pips at X=5 vs 222 at X=11; ALT 80 at X=8 vs 95 at X=11.

- **S1** (include the entry minute) was rejected by parity (A3c).
- **S3** (swap) is now RUN -- see s8.

---

## 6. LIMITATIONS -- READ BEFORE ACTING

- **The selection rule has a flaw the pre-registration did not foresee.**
  "At least 90% of the maximum" is applied to TOTALS, which include a large
  component that is the same at every X (layers that never reach any
  tested X). That component shifts the curve up or down without changing
  its shape, and so changes how wide the 90% band is -- and for majors it
  makes the rule inapplicable. Not changed after seeing results; reported
  here. A future pre-registration should select on the difference from a
  reference X.
- **Curves are noisy.** Crosses swing from 116 pips/day at X=7 to 77 at
  X=8 and back to 153 at X=14: a handful of layers crossing thresholds.
  Four calibration days cannot resolve that.
- **Entries were held fixed** (toward WIDER), and the account was
  guard-saturated throughout, which is why per position-day matters.
- **One regime, seven trading days.**

---

## 7. S3 -- SWAP, RUN 2026-09-20 21:00Z

**Input:** the pipshed carry table, per night in pips at `mult` 1, read
2026-09-20 20:50 once the week started. Per night: AUDCAD +0.202 / -0.941,
AUDCHF +0.224 / -0.999, AUDNZD +0.165 / -0.931, CADCHF +0.081 / -0.624,
EURGBP -0.642 / 0.000, EURUSD -1.106 / +0.059, GBPUSD -0.678 / -0.376,
NZDCAD -0.069 / -0.355 (long / short).

**Method:** charge each counterfactual hold for every broker midnight it
crosses, weekday midnights only, with Wednesday's charged triple.

**Assumptions, stated:** the rates are TODAY's and are applied to the
10-18 Sep window; rates move. Which midnight carries the triple is a
convention -- repeating it on Thursday's changes nothing (EURGBP still
selects 11, band 10-12).

**Result: the selections barely move.**

| group | select on net | select on net + swap | swap over the calibration curve |
|---|---|---|---|
| majors | nothing (curve below zero) | nothing | -43 to -120 pips |
| EURGBP | **11** (set 9-14) | **11** (set 10-12) | -13 to -63 pips |
| crosses | 14 (set 13-15) | 13 (set 13-14) | -18 to -108 pips |

**Holdout, on net after swap, like for like:**

| group | X* | net at X* | net at live | difference | interval | result |
|---|---|---:|---:|---:|---|---|
| EURGBP | 11 | 82.0 | -11.2 | **+93.2** | [+31.6, +144.5] | **ACCEPT** |
| crosses | 13 | -198.3 | -137.6 | -60.7 | [-264, +134] | reject |
| crosses | 14 | -176.2 | -137.6 | -38.6 | [-252, +158] | reject |

**EURGBP survives the swap check.** Its short side pays nothing per night
and its long side -0.642, so the longer holds a wider exit implies cost
about 44 pips over the calibration window against a roughly 100-pip gain,
and the holdout interval still excludes zero.

**What swap does change is the cost of holding inventory generally.** At
the live geometry the current book pays about 47 pips (~4.4 USD) a night,
about 9% of gross realised, and roughly triple that on Wednesdays. The
worst rates sit exactly where layers are held longest: short AUD at ~0.94
to 1.00 a night, EURUSD long at 1.106. Cycle 3's tighter grids hold more
layers, so that cost rises with them -- it is not in the pips-per-day
figures on which cycle 3 was chosen.

## 8. WHAT GOES TO GEMINI

1. **The metric disagreement.** Under a binding guard, which governs --
   per day (EURGBP widen to ~11; crosses wider) or per position-day
   (tighter everywhere)? This decides EURGBP and crosses.
2. **EURGBP ALT 8 -> 6** in the cycle-2 presets contradicts the only
   statistically clear result here. Revert it for Wednesday?
3. **EURUSD 7/10 -> 5/7** has no support. Revert both arms for Wednesday?
   (Gemini already ruled OPT back to 14/7 as a control.)
4. The selection-rule flaw (s6): accept it as a stated limitation, or
   re-run with a difference-from-reference rule as a new, separately
   pre-registered study once the new account has a week of data.
5. EURGBP now clears the swap check (s7). Ship 11 on one arm, keeping the
   other at 8 as a control, or hold it until the new account?

Line count: 256
