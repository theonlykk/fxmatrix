This message has a line count at the bottom

# COMPASS ROUND 2 -- ROUND 1's VERDICT AND ROUND 2's TABLE (FOR GEMINI)

| | |
|---|---|
| Status | **DECIDED 6 Oct ~01:40Z** (Gemini GR2-1..GR2-6, Claude's check and the operator: s6). Drafted by Claude, 6 Oct ~01:30Z. Gemini reviews the verdict table and the probe table before any reload (compass-round s4.7). The reload is Tue 6 Oct in session; round 2 = FTMO days Wed 7 + Thu 8 |
| Sources | `docs/runbooks/compass-round.md` (s4 the loop, s5 cuts, s6 width, s9 open, s11 records); `docs/architecture/MEMO_2026-10-05_width_depth_counter_side.md` (this week: cap 8, tight widths, deadband 2); `research/compass/compass_score.py` + `round1.json`; `scripts/ic_presets.py` + `scripts/ic_geometry_r2.json` (main `dd71202`); HANDOFF s58 |
| Asks | GR2-1..GR2-6 (s5). Attack the premises; say which fact is missing |

Gemini cannot open the repo: every fact below is quoted with its file
and lines, and Claude re-checks anything Gemini asks about.

## 0. AUDIT TRAIL

| # | Fact used | Where | Status |
|---|---|---|---|
| K1 | Round 1 = FTMO days Fri 2 Oct + Mon 5 Oct (22:00Z-22:00Z); B anchor, C add probe (one pip from the anchor, per side), D exit probe; AUDNZD and NZDCAD probed by same-account twins (ALT) on C and D | `round1.json`; compass-round s2 | VERIFIED |
| K2 | Scored 5 Oct ~22:12Z on a study export whose data run to 22:05Z (final, not provisional); realised all-in P&L (scalps + rolls + ejections, profit + swap + commission) per day by close time decides | compass-round s1, s4.2; scorer output | VERIFIED |
| K3 | Threshold GC-1 = max($1.19, median of the control pair NZDCAD's six same-settings gaps) = $2.55. Gaps per day: long B-C 5.18, B-D 9.32, C-D 4.14; short 0.63, 0.96, 0.33. The fixed $1.19 was also reported; the operator chose GC-1 for round 1 (5 Oct ~22:15Z) | scorer output; compass-round s4.3 | VERIFIED |
| K4 | WIN: margin > threshold; LOSE: < -threshold; else REPEAT. ADD probes need two gates (entry-time split, per layer-hour) before WIN. Both levers win: the larger margin is promoted | compass-round s4.4 | VERIFIED |
| K5 | Next probes: one pip from the anchor on the side the evidence points to; a loser flips across the anchor; explore outward while the anchor keeps losing on one side; once both sides of a lever lose, refine inward in half pips (floor OPEN, s9) | compass-round s4.5 | VERIFIED |
| K6 | Hand interventions cut a comparison (scored before the cut if >= 1 day remains, else VOID): NZDCHF long B and C, AUDCHF long C (2 Oct, window 1) | compass-round s5; `round1.json` interventions | VERIFIED |
| K7 | Disconnects (three boxes' journals, 1, 2, 4, 5 Oct): none inside either window (1 Oct 02:33Z; 4 Oct 00:35Z and 19:04-19:05Z, a Sunday) | `disconnects.py` output | VERIFIED |
| K8 | Between the rounds, structural and alike on B, C, D (5 Oct 22:20-23:21Z): the twins retired; code `main` (`2859be6`); ADR-165 re-roll ON. Tuesday's reload adds, alike on B, C, D: the tightest widths the ADR-153 guard allows, S = W + 1, deadband 2 (from 4); cap stays 8. Any structural change restarts the pools (GC-2) | HANDOFF s58; memo s3; compass-round s4.1, s4.4 | VERIFIED |
| K9 | The EA accepts any add > 0 per side and guards add / width per side to [0.5, 4.0] (a typo guard): `fxgrind.mq5` 152-159 (side resolve), 187-191 and 198-202 (per-side guard); `grind_pure.mqh` 9-10, 41-52 | source at `dd71202` | VERIFIED |
| K10 | Generator rule (new, 5 Oct): a C add probe marked `"half": true` must sit exactly 0.5 pip from the anchor and at or above 2.5, add probes only; unmarked probes keep the one-pip and add-3 rules (`scripts/ic_presets.py` 41-42, 170-209; tests H1-H5, six mutations caught) | `6656097`, `e14fd5d` | VERIFIED |
| K11 | IC spreads (wine-c, every minute, 24-30 Sep): median 0.1-0.5 pips on the nine pairs; spread > 2 x width in 0.00% of minutes outside the 21Z hour | cap10-reload K17 | MEASURED |
| K12 | The first night of re-roll (5 Oct 22:40-23:21Z): every re-roll was on a fully rolled side; two far rolled levels on EURUSD long C walked a 9-level gap to the market (9 re-rolls); re-rolled exits filled within the hour and realised the old layers' losses (C's card: rolls 9, -618 pips, -$65.37) | archive `ROLL_ACCEPTED` / `ROLL_FILLED`; HANDOFF s58 | MEASURED |

## 1. ROUND 1 VERDICT (GC-1 $2.55; $ per day, realised all-in)

| pair | side | anchor B | C add | C margin | C verdict | D exit | D margin | D verdict | promote |
|---|---|---|---|---|---|---|---|---|---|
| GBPUSD | L | 12.27 | 12.74 | +0.48 | REPEAT | 12.17 | -0.10 | REPEAT | - |
| GBPUSD | S | 11.10 | 9.70 | -1.40 | REPEAT | 12.43 | +1.33 | REPEAT | - |
| EURUSD | L | -5.15 | -0.95 | +4.20 | WIN | -15.91 | -10.77 | LOSE | C |
| EURUSD | S | 17.21 | 17.10 | -0.10 | REPEAT | 13.59 | -3.61 | LOSE | - |
| EURGBP | L | -3.73 | -10.05 | -6.32 | LOSE | -8.11 | -4.38 | LOSE | - |
| EURGBP | S | 8.69 | 6.38 | -2.30 | REPEAT | 8.80 | +0.11 | REPEAT | - |
| AUDCAD | L | 1.55 | 2.97 | +1.42 | REPEAT | 5.51 | +3.96 | WIN | D |
| AUDCAD | S | -3.50 | -1.98 | +1.52 | REPEAT | -3.48 | +0.01 | REPEAT | - |
| AUDCHF | L | -5.36 | VOID | | VOID | -4.19 | +1.17 | REPEAT | - |
| AUDCHF | S | 3.63 | 6.06 | +2.42 | REPEAT | 5.85 | +2.21 | REPEAT | - |
| CADCHF | L | -0.81 | 1.32 | +2.14 | REPEAT | -5.53 | -4.71 | LOSE | - |
| CADCHF | S | 7.09 | 5.68 | -1.41 | REPEAT | 6.25 | -0.84 | REPEAT | - |
| NZDCHF | L | -3.38 | VOID | | VOID | 3.46 | | VOID | - |
| NZDCHF | S | 4.56 | 4.96 | +0.41 | REPEAT | 6.94 | +2.38 | REPEAT | - |
| NZDCAD | L | -5.60 | -2.75 | -2.32 | REPEAT | 3.03 | -0.69 | REPEAT | control |
| NZDCAD | S | 2.43 | 1.43 | -1.64 | REPEAT | 2.98 | -0.41 | REPEAT | control |
| AUDNZD | L | 4.56 | 4.30 | -0.27 | REPEAT | 4.51 | -0.09 | REPEAT | - |
| AUDNZD | S | -4.48 | 0.92 | +5.47 | WIN | 0.08 | +0.53 | REPEAT | C |

NZDCAD and AUDNZD margins are twin minus its own fleet's primary on the
anchor (`round1.json`; AUDNZD long's twin threshold $1.40). Detail per
instance and side (scalps, rolls, ejections, layer-hours, open layers,
depth at the reload) is in the scorer output; quoted on request.

Under the fixed $1.19 five more would have moved: AUDCHF S (C), CADCHF L
(C), NZDCHF S (D), AUDCAD S (C), GBPUSD S (D); EURGBP S C and CADCHF S C
would have lost. Each of those margins is inside the control pair's own
same-settings spread.

## 2. ROUND 2 TABLE (cap 8, deadband 2, S = W + 1; pips; L / S)

| pair | width | B anchor add | B anchor exit | C add (probe) | D exit (probe) | change from round 1 |
|---|---|---|---|---|---|---|
| GBPUSD | 2.5 | 9 / 9 | 10 / 10 | 8 / 8 | 9 / 9 | repeat |
| EURUSD | 2.0 | **6** / 7 | 10 / 10 | **5** / 6 | **11 / 11** | L add 6 promoted; C one pip further; D flips both sides (SUPERSEDED by s6: no promotion) |
| EURGBP | 1.0 | 3 / 3 | 5 / 5 | **2.5** / 4 | **6** / 4 | L: C lost at 4, flip 2 is below the add-3 floor: half a pip, 2.5 (operator 6 Oct ~00:00Z); D flips |
| AUDCAD | 1.5 | 6 / 6 | **9** / 10 | 5 / 5 | **8** / 9 | L exit 9 promoted; D one pip further (SUPERSEDED by s6: no promotion) |
| AUDCHF | 1.0 | 4 / 4 | 10 / 10 | 3 / 3 | 9 / 9 | repeat (L C was VOID) |
| CADCHF | 1.0 | 4 / 4 | 10 / 10 | 3 / 3 | **11** / 9 | L: D flips |
| NZDCHF | 1.0 | 3 / 3 | 10 / 10 | 4 / 4 | 9 / 9 | repeat (L VOID) |
| NZDCAD | 2.0 | 8 / 8 | 10 / 10 | (anchor) | (anchor) | control on every fleet |
| AUDNZD | 2.0 | 8 / **7** | 10 / 10 | 7 / **6** | 9 / 9 | S add 7 promoted; C one pip further; probes move from the retired twins to the primaries (SUPERSEDED by s6: no promotion) |

Width = ceil to the half pip of the largest add any fleet runs on the
pair / 4 (memo s3.2), one width per pair on B, C and D. A C probe uses the
anchor's exit; a D probe uses the anchor's add. 27 presets generated and
validated (keys and order kept, magic and instance unchanged, key blank,
guard on every side, cap, deadband, S): 0 errors.

## 3. WHAT CHANGES FOR ROUND 2 BESIDES THE PROBES (alike on B, C, D)

- Re-roll ON (K8, K12): a capped, fully rolled side keeps moving its
  furthest exit to the next level; old layers realise when the market
  bounces by about an exit. Realised P&L (the decider) now includes those
  realisations on whichever fleet's side happens to re-roll.
- Widths 1.0-2.5 (from 3-7) and deadband 2 (from 4): the counter-side
  entry sits closer and re-quotes after 2 pips of drift (memo s2).
- Twins gone: one instance per pair; AUDNZD's probes on the primaries.
- All of the above is structural: pools restart (GC-2); round 1's REPEATs
  start again at zero days.

## 4. NOT IN THIS DOCUMENT

FTMO (A) is frozen for the holdout (window 5 Oct 22:00Z - 9 Oct 21:00Z):
no promotion to A this week. Cap 10, the fixed-width rule and the AUDUSD
scout are deferred (memo s3.1). The width-guard change and C127 come as
their own document later.

## 5. FOR GEMINI

- **GR2-1. Promotion on one round.** Three promotions on two FTMO days
  each (EURUSD L add 6, AUDCAD L exit 9, AUDNZD S add 7), all above GC-1.
  The rule promotes on a WIN (K4). Is two days enough given K3's long-side
  noise (control gaps up to $9.32 a day), or should a WIN repeat once
  before promotion? Name the fact that would decide it.
- **GR2-2. Realised-only scoring against unequal inventory.** EURUSD long
  D lost -10.77 with 13 rolls and 1 layer open at the end; B (the
  comparator) had 11 rolls and 6 open. Part of D's loss is B's loss not
  yet realised. compass-round s1 accepts this (deferred cost pools over
  rounds; open risk at promotion), but with re-roll ON realisation now
  depends on which side re-rolls first (K12). Does this change the
  scoring premise, or only the reading of single-round margins?
- **GR2-3. Winners probe one pip further** (EURUSD L add 5, AUDCAD L exit
  8, AUDNZD S add 6) by K5 ("on the side the evidence points to"). Or
  should the old anchor value be the comparator first (the new anchor
  against its own past, on C or D)?
- **GR2-4. The half-pip probe** (EURGBP L C add 2.5; K9, K10, K11).
  Facts: the EA takes it (ratio 2.5 at width 1.0); a roll costs cap x add
  - exit = 8 x 2.5 - 5 = 15 pips (20 at add 3); eight layers span 20
  pips; EURGBP's median IC spread is under half a pip. Missing facts or a
  reason this probe is uninformative?
- **GR2-5. Flips to wider exits** (EURUSD L and S 11, CADCHF L 11, EURGBP
  L 6) after the tighter exit lost. With re-roll ON, a wider exit also
  realises a re-rolled layer later. Any reason a flip should wait until
  the re-roll effect is measured?
- **GR2-6. One reload carrying width, deadband and the probes** (K8).
  Width and deadband change alike on every fleet and pair, so each
  comparison stays like for like; the anchor's own numbers move. Any
  confound the table does not control?

## 6. GEMINI'S RULINGS (6 OCT ~01:25Z), CLAUDE'S CHECK AND THE OUTCOME

Gemini read this file as an attachment; his answers pasted by the
operator; each premise checked here; the operator decided one question
at a time (6 Oct ~01:31Z-01:38Z).

- **GR2-1 ACCEPTED (operator), reason corrected.** His: a two-day WIN is
  noise beside the $9.32 control gap. That gap is the worst of six, all
  long-side (short 0.33-0.96); GC-1 already takes the median. The reason
  that stands: round 1's wins were earned before the structural change
  (re-roll, widths, deadband; GC-2), so each WIN repeats once under the
  new structure before promotion. Operator: "let's see the results of
  these changes and verify that they are implemented correctly before
  optimizing". **Round 2: no promotion; the winners repeat as probes
  (EURUSD L C add 6, AUDCAD L D exit 9, AUDNZD S C add 7); the anchor keeps
  round 1's values.** Nine `_r2` presets regenerated (B, C, D of EURUSD,
  AUDCAD, AUDNZD); 27 files, 0 errors. Whether a WIN must always repeat is
  OPEN (decide at round 2's scoring).
- **GR2-2 REJECTED as a rule change, adopted as a report.** His mechanism
  is backwards: re-roll moves the exit to about an exit from the market,
  so losses realise sooner (K12: within the hour), not "infinitely
  deferred"; and IC never ejects (auto-eject off), so "Cap 8 Ejection" is
  not IC's premise. The concern that stands (who realises first) is the
  one s5 raised. Operator: "showing mtm is useful, but decisions are based
  on realized". **From round 2 every score reports open MTM (the IC
  bid / ask dump is a compulsory scoring step); realised decides.**
- **GR2-3 agreed** (winners probe one pip further); moot this round.
- **GR2-4 REJECTED; 2.5 stands.** His premise (the 2.5 add on a 1.0 width
  makes the counter-side L0 churn) is wrong: the width is 1.0 on every
  fleet whatever C long probes (the pair's largest add is C short's 4),
  and the empty side re-quotes on the deadband (2 pips), identical on B,
  C, D. The ladder spans 20 pips against the anchor's 24; a re-roll costs
  15 pips against 19. His missing fact (fill slippage of tight limits) is
  measurable from the fill logs and will be reported.
- **GR2-5 REJECTED.** B runs exit 10 with re-roll ON in the same round on
  the same ticks: the baseline he asks for is measured simultaneously.
  The flips stand.
- **GR2-6 REJECTED (operator: choice A, probes as planned).** His premise
  (the $2.55 threshold carries over) is wrong: GC-1 re-estimates from the
  round's own control gaps (compass-round s4.3). The structural change is
  alike on B, C, D, so comparisons stay like for like; a baseline round
  would spend this week's only full probe round. The request footprint at
  deadband 2 is watched (`api_count`; IC's budget unmeasured, C78).

Line count: 179
