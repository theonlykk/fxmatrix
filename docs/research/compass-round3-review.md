This message has a line count at the bottom

# COMPASS ROUND 3 -- ROUND 2's VERDICT AND ROUND 3's TABLE (FOR GEMINI)

| | |
|---|---|
| Status | **DECIDED 8 Oct ~23:20Z** (Gemini GR3-1..GR3-5, Claude's check and the operator: s6). Drafted by Claude 8 Oct ~23:05Z. Reload Fri 9 Oct in session (four charts); round 3 = FTMO days Mon 12 + Tue 13; presets `_r3` from `scripts/ic_geometry_r3.json` |
| Sources | `docs/runbooks/compass-round.md` (s4 the loop, s4.1 structural changes, s4.5 next probes, s11 records); `docs/research/compass-equity-amendment.md` (s7 the cohort decides, s8 round 2 moved); `research/compass/equity_score.py` + `round2.json`; `scripts/ic_presets.py` + `scripts/ic_geometry_r2.json`; `handoffs/Handover/10_GEOMETRY_REGISTER.md` (LIVE NOW); `docs/research/compass-round2-review.md` (round 1's verdict, s1) |
| Asks | GR3-1..GR3-5 (s5). Attack the premises; say which fact is missing |

Gemini cannot open the repo: every fact below is quoted with its file,
and Claude re-checks anything Gemini asks about.

## 0. AUDIT TRAIL

| # | Fact used | Where | Status |
|---|---|---|---|
| K1 | Round 2 = 7 Oct 02:25Z (after the Wednesday build's last Load) to 8 Oct 22:00Z, two windows of one day each (the first 19.6 h); the cohort's end mark 8 Oct 22:30Z | `round2.json` windows, `equity_end`, `window_note` | VERIFIED |
| K2 | The COHORT's EQUITY decides (operator 7 Oct ~14:53Z / ~15:07Z): layers OPENED in the round: costs + closes + the mid mark at the end of those still open; plain equity and realised margins reported beside it | amendment s7; `equity_score.py` `cohort_side` | VERIFIED |
| K3 | Scored 8 Oct ~22:45Z on `study_2026-10-08_2235.jsonl` (21,575,654 bytes, sha256 `577b777bfb7d2270`) with the IC bid / ask dump of wine-c (`grind_bidask_dump.mq5`, 53071896, nine pairs, 2026.10.07 04:00 - 2026.10.09 01:42 server). The scorer flags "fills end 20:08Z, provisional": no fill on any instance after 20:08Z; the same hours on 7 Oct held 0 (19Z), 5 (20Z), 0 (21Z) fills; all 34 instances posted their carry pass 20:50-20:56Z; the three EURUSD archive exports at ~22:38Z also end at 20:07Z. Read as the evening lull, not missing data | scorer output (Downloads `equity_score_round2_2026-10-08_2235.txt`, sha256 `21b5eb97b0c5680d`) | VERIFIED |
| K4 | Threshold GC-1 = max($1.19, median of NZDCAD's six cohort gaps 0.65) = $1.19 a day. Gaps: long B-C 0.40, B-D 0.45, C-D 0.84; short 0.90, 0.02, 0.88 | scorer output | VERIFIED |
| K5 | WIN: margin > threshold; LOSE: < -threshold; else REPEAT. Under the cohort no ADD gate applies (the entry split IS the cohort; per layer-hour reported, not a gate: GQ7-2) | compass-round s4.4; amendment s7 | VERIFIED |
| K6 | **Operator 8 Oct ~22:52Z: no promotion; every round-2 WIN repeats as a probe** (the same ruling as round 2's GR2-1; round 1's three winners did not repeat in round 2: EURUSD L C add 6 -0.59, AUDCAD L D exit 9 -0.86, AUDNZD S C add 7 -0.01, all REPEAT) | this chat; s1 | RULED |
| K7 | Next probes: one pip from the anchor; a loser flips across the anchor; explore outward while the anchor keeps losing on one side; once both sides of a lever lose, refine inward in half pips | compass-round s4.5 | VERIFIED |
| K8 | A round never spans a structural change (code build, ADR-165 on / off, cap, WIDTH, pair set, twin retirement); a REPEAT pools its days over rounds only while the structure is unchanged; the pool restarts at every structural change (GC-2) | compass-round s4.1, s4.4 | VERIFIED |
| K9 | One width per pair on B, C and D = ceil to the half pip of (the largest add ANY fleet runs on the pair) / 4, the tightest the ADR-153 guard (0.5 <= add / width <= 4.0) allows; S = W + 1 | `scripts/ic_presets.py` 47, 377-390 (`tight_width`, `round_width`) | VERIFIED |
| K10 | Round 2's geometry (pips, width / add / exit, L / S where they differ; cap 8, deadband 2, S = W + 1; roll gate 0, re-roll on, lattice on): register LIVE NOW, reproduced in s2's "round 2" columns | `10_GEOMETRY_REGISTER.md`; `ic_geometry_r2.json` | VERIFIED |
| K11 | Round 1's losers (realised all-in, GC-1 $2.55, BEFORE the 5 Oct structural change): EURUSD L D exit 9 -10.77; AUDCHF L C VOID (a hand cut), AUDCHF L D exit 9 +1.17 REPEAT | round-2 review s1 | VERIFIED |

## 1. ROUND 2 VERDICT (cohort equity, $ per day; GC-1 $1.19)

Cohort equity per day of the anchor and each probe; the margin is probe
minus anchor (NZDCAD: the control, anchor on every fleet). Plain equity
and realised margins in brackets.

| pair | side | anchor B | C add | C margin | C verdict | D exit | D margin | D verdict |
|---|---|---:|---:|---:|---|---:|---:|---|
| GBPUSD | L | +6.16 | +6.35 | +0.19 | REPEAT (eq -2.52, real -4.63) | +6.74 | +0.58 | REPEAT (+0.48, +0.49) |
| GBPUSD | S | +0.70 | +2.47 | **+1.775** | **WIN** (-0.78, +1.87) | +2.46 | **+1.768** | **WIN** (+1.48, +0.65) |
| EURUSD | L | +7.76 | +7.17 | -0.59 | REPEAT (+2.74, +15.93) | +3.81 | **-3.95** | **LOSE** (+0.77, +10.93) |
| EURUSD | S | +2.13 | +1.35 | -0.78 | REPEAT (-1.57, +3.18) | +2.19 | +0.06 | REPEAT (-0.13, +0.31) |
| EURGBP | L | -0.71 | +0.49 | **+1.194** | **WIN** (-0.33, -13.80) | -1.40 | -0.69 | REPEAT (-1.18, -8.04) |
| EURGBP | S | -6.64 | -3.94 | **+2.71** | **WIN** (+4.37, +3.93) | -5.28 | **+1.36** | **WIN** (+0.81, -0.77) |
| AUDCAD | L | -0.66 | -0.00 | +0.66 | REPEAT (+2.29, -3.37) | -1.52 | -0.86 | REPEAT (+0.21, +0.16) |
| AUDCAD | S | +2.23 | +3.58 | **+1.35** | **WIN** (-0.26, +1.24) | +2.50 | +0.27 | REPEAT (+0.15, +0.14) |
| AUDCHF | L | +4.53 | -1.77 | **-6.30** | **LOSE** (-9.12, -5.02) | +2.01 | **-2.52** | **LOSE** (-3.94, -1.74) |
| AUDCHF | S | +4.69 | +6.09 | **+1.40** | **WIN** (+0.54, -8.65) | +4.22 | -0.47 | REPEAT (-0.71, -0.71) |
| CADCHF | L | +2.17 | +3.16 | +1.00 | REPEAT (+0.91, +1.71) | +2.13 | -0.03 | REPEAT (+0.01, -0.35) |
| CADCHF | S | +1.49 | +2.01 | +0.52 | REPEAT (+0.69, -1.91) | +2.12 | +0.63 | REPEAT (+1.00, +0.40) |
| NZDCHF | L | +0.68 | +0.26 | -0.42 | REPEAT (-0.26, -0.56) | +0.46 | -0.22 | REPEAT (-1.21, -0.23) |
| NZDCHF | S | +2.37 | +1.31 | -1.06 | REPEAT (-0.91, +1.24) | +2.63 | +0.26 | REPEAT (-0.05, -0.05) |
| NZDCAD | L | +0.74 | (control) | | | (control) | | |
| NZDCAD | S | +1.83 | (control) | | | (control) | | |
| AUDNZD | L | +0.40 | +0.93 | +0.52 | REPEAT (+0.62, +0.91) | +0.34 | -0.06 | REPEAT (-0.12, -0.15) |
| AUDNZD | S | +1.41 | +1.39 | -0.01 | REPEAT (+0.18, +0.14) | +1.31 | -0.10 | REPEAT (-0.22, -0.12) |

Two WINs sit on the line: GBPUSD S (C +1.7750 against D +1.7675, 0.75
cent apart) and EURGBP L C (+1.1942, 0.4 cent over $1.19). No unpriced
layer anywhere (every cohort layer had a mark). Under K6 none of the
WINs moves the anchor this round.

## 2. ROUND 3 TABLE (cap 8, deadband 2, S = W + 1; pips; L / S where the sides differ)

| pair | width | B anchor add | B anchor exit | C add (probe) | D exit (probe) | change from round 2 |
|---|---|---|---|---|---|---|
| GBPUSD | 2.5 | 9 | 10 | 8 | 9 | repeat (S: both WIN, repeat, K6) |
| EURUSD | 2.0 | 7 | 10 | 6 | **9** / 11 | L: D lost at 11, flips to 9 (GR3-2) |
| EURGBP | 1.0 | 3 | 5 | 2.5 / 4 | 6 / 4 | repeat (L C, S C, S D WIN, repeat) |
| AUDCAD | 1.5 | 6 | 10 | 5 | 9 | repeat (S C WIN, repeat) |
| AUDCHF | **1.5** | 4 | 10 | **5** / 3 | **11** / 9 | L: C lost at 3, flips to 5; D lost at 9, flips to 11. Width 1.0 -> 1.5 on B, C, D (K9: 5 / 4 = 1.25 -> 1.5); S = 2.5 (GR3-3) |
| CADCHF | 1.0 | 4 | 10 | 3 | 11 / 9 | repeat |
| NZDCHF | 1.0 | 3 | 10 | 4 | 9 | repeat |
| NZDCAD | 2.0 | 8 | 10 | (anchor) | (anchor) | control on every fleet |
| AUDNZD | 2.0 | 8 | 10 | 7 | 9 | repeat |

Round 2's columns for comparison (K10): EURUSD D exit 11 / 11; AUDCHF
width 1.0, C add 3 / 3, D exit 9 / 9; every other cell as above.

**Reloads (four charts):** B AUDCHF (width 1.0 -> 1.5, S 2.0 -> 2.5; add
and exit unchanged), C AUDCHF (width, L add 5), D AUDCHF (width, L exit
11), D EURUSD (L exit 9). The other 23 charts keep running untouched:
their geometry is round 2's, and a cohort needs no reload to start (K2:
it counts layers opened in the round). Presets: the four `_r3` files
generated by `scripts/ic_presets.py` from an `ic_geometry_r3.json`, each
read back (keys and order kept, magic and instance unchanged, key blank,
guard on every side, cap, deadband, S, gate 0); the 23 others are their
`_r2` files unchanged.

**Round 3's window (GR3-4, DECIDED, s6):** FTMO days Mon 12 + Tue 13 Oct
(Sun 11 22:00Z - Tue 13 22:00Z), two full days after Friday's reload
(compass-round s4.1's default); the cohort's end mark Tue 13 22:30Z;
scored Tuesday evening. (Drafted as Fri 9 + Mon 12, with Friday's part
counted as one day: superseded.)

## 3. WHAT IS STRUCTURAL THIS TIME

- Only AUDCHF's width (K8 lists width): it changes alike on B, C and D,
  so the three AUDCHF comparisons stay like for like, and every AUDCHF
  pool (S C's repeating WIN, S D's REPEAT) restarts at zero days (GC-2). No other pair's
  structure changes; their REPEATs pool round 2 and round 3 (GC-2).
- No code build, no cap, gate, re-roll or pair-set change. A (FTMO
  1514878887) stays static for its trial (to ~21 Oct).

## 4. NOT IN THIS DOCUMENT

Whether a WIN must always repeat once before promotion (round 2's GR2-1
left it OPEN; K6 decides only this round). Cap 10, AUDUSD and the
fixed-width rule stay deferred. The EURUSD replay calibration (its
holdout runs from round 3's reload to Tue 13 Oct 22:00Z with each
segment's own inputs: D's EURUSD reload is one more init there, not a
change to the replay).

## 5. FOR GEMINI

- **GR3-1. Repeating every WIN again (K6).** Round 1's three winners all
  fell back to REPEAT in round 2 under the new structure. Round 2's WINs
  were earned under the CURRENT structure. Does a second repeat buy
  information, or does it only delay a promotion the rule (K5) already
  allows? Name the fact that would decide it (e.g. how often a two-day
  cohort margin above GC-1 keeps its sign).
- **GR3-2. EURUSD long, exit: flip to 9 or refine to 10.5?** D lost at 11
  in round 2 (cohort -3.95); D also lost at 9 in round 1 (-10.77,
  realised, before the 5 Oct structural change: wide widths, no re-roll,
  K11). K7 says "once both sides of a lever lose, refine inward in half
  pips". The draft treats round 1's loss as void for this purpose (GC-2:
  evidence does not carry across a structural change) and flips to 9.
  Is that the right reading, or is 10.5 the probe?
- **GR3-3. AUDCHF's width to 1.5 (K9).** The flip of C's long add to 5
  forces the pair's width from 1.0 to 1.5 on all three fleets (the guard
  allows add / width up to 4.0). Every AUDCHF instance changes width at
  once, alike, which keeps the comparisons like for like but restarts
  AUDCHF's pools and moves the anchor's own numbers. The alternative is
  to keep width 1.0 and probe C's long add at 4.5 (the largest add 1.0
  allows is 4.0, the anchor's own; 4.5 needs 1.5 too), i.e. there is no
  flip that keeps width 1.0. Is a width change on the anchor acceptable
  inside the compass, or should AUDCHF long's C probe repeat at 3 (a
  LOSE repeating) instead?
- **GR3-4. The window:** Fri 9 (from the reload, about 13 h to the 20:57Z
  close) + Mon 12, scored Monday. Friday's thin, short day counted as one
  day. Any reason to start round 3 at Mon 12 00:00Z instead (one clean
  day plus Tue 13)?
- **GR3-5.** What fact is missing?

## 6. GEMINI'S RULINGS (8 OCT ~23:10Z), CLAUDE'S CHECK AND THE OUTCOME

Gemini read this file as an attachment; his answers pasted by the
operator; each premise checked here.

- **GR3-1 ACCEPTED (a second repeat), reason corrected.** His: a two-day
  WIN above GC-1 is indistinguishable from noise "as established in
  GR2-1". GR2-1's reason was the structural change, not noise (round-2
  review s6), and GC-1 already sits above the control's gaps. The fact he
  names (does a two-day margin above GC-1 keep its sign in the next
  round?) has one data point: round 1's three winners kept it 0 of 3 in
  round 2 (across a structural change). The operator's ruling (K6)
  stands; whether a WIN must ALWAYS repeat stays OPEN, now with that
  count to collect each round.
- **GR3-2 ACCEPTED (flip to 9), premise corrected.** Round 1 was not an
  "Ejection regime": IC ran auto-eject OFF and the lattice ON from the
  C63 loads (1 Oct). The differences were re-roll off, widths 3-7 and
  deadband 4 (round-2 review K8). GC-2 holds either way: 9 is untested
  under the current structure.
- **GR3-3 ACCEPTED** (AUDCHF width 1.5 on B, C, D; AUDCHF's pools
  restart). His mechanism (the counter-side L0 sits at 1.5 from mid, S =
  2.5) is right; the re-quote step is the deadband (2), unchanged.
- **GR3-4 ACCEPTED (operator ~23:20Z): Mon 12 + Tue 13.** His premise
  (Friday afternoons are "mechanically toxic" to the grid) is not
  measured here (as GRC-6), and a shared divisor does not bias a
  margin. What stands: compass-round s4.1's default is two FULL FTMO days
  after the last reload; Friday's part was a carry-over from round 2's
  one-off ruling. The reload stays Fri 9 in session; the cohort counts
  only layers opened from Sun 11 22:00Z.
- **GR3-5 ANSWERED, measured.** His question: was EURGBP's double WIN on
  C a trend favouring whichever fleet "deployed margin faster"? EURGBP
  over the round (IC bid / ask, 7 Oct 05:25 - 9 Oct 01:30 server): net
  -4.3 pips in a 39.6-pip range (Wed -5.9, Thu +5.0): no one-way move.
  C did not build faster: cohort layers long C 12 vs anchor 12, short C 11
  vs anchor 14. Repeating the probe (GR3-1) tests the rest.
- **Built:** `scripts/ic_geometry_r3.json` (round 2's table with the
  three cells changed); `scripts/ic_presets.py --stage round --write`: 27
  `_r3` files, 0 errors; against `_r2` only the four reload charts differ
  in any input (B AUDCHF width 1.5 / S 2.5; C AUDCHF width 1.5, add 5 / 3;
  D AUDCHF width 1.5, exit 11 / 9; D EURUSD exit 9 / 11); the other 23
  differ only in `InpConfigWarning` (the round number) and are NOT
  reloaded. `round3.json` is written after the reload (its probe reload
  times).

Line count: 188
