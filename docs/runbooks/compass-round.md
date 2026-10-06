This message has a line count at the bottom

# COMPASS ROUND RUNBOOK + PAIR STATUS

| | |
|---|---|
| Status | **ACCEPTED 3 Oct ~05:30Z**: Claude's draft, Gemini's rulings GC-1..GC-7 (s10), the operator's decisions on GC-4, GC-6 and the control pair |
| Backlog | C104 (the routine), C96 (pairs), C99 (cap 10 + width), C91 (scoring code) |
| Sources | cycle-4 note s8.1-s8.15; `docs/architecture/fleet-d.md` s6.5, s6.8, s7; `research/compass/compass_score.py` + `round1.json`; HANDOFF s37-s39 |
| Replaces | the "ring note" planned for C96 |

## 1. PURPOSE AND OBJECTIVE

The compass tunes each pair's geometry (add and exit, per side) on live
IC demo books, one lever per probe fleet per round, and promotes winners
to the anchor; FTMO (real limits) runs anchors only.

- **Decides (operator 2 Oct, cycle-4 s8.15; confirmed 3 Oct):** realised
  all-in P&L per pair and side per day: scalps + rolls + ejections,
  profit + swap + commission from the ledger, by CLOSE time. A filled roll
  is a poor scalp and counts. Operator 3 Oct: "focus on realised pnl - if
  we can control realised pnl and find it is not enough, then we can act
  on that."
- **Reported, never deciding:** total P&L (realised + change in open);
  **peak open MTM, and open MTM carried across the 22:00Z day-roll**
  (GC-6); rolls accepted and filled; unfilled rolled layers and their open
  MTM at the round's end; stuck episodes; hand and auto ejects; **broker
  disconnects per fleet (count, duration)** (GC-6's missing fact); the
  entry-time split; layer-hours; depth at the reload; requests per fleet
  (C106). A long disconnect inside a window flags that fleet's round for
  review. The MTM and disconnect reports are built before round 2 is
  scored (C104).
- **Deferred roll cost** is handled by pooling repeated probes over
  rounds (s4); open-position risk is judged at promotion (s8).

## 2. FLEETS AND ROLES

| Fleet | Box | Role |
|---|---|---|
| B | wine-test (IC 53066709) | ANCHOR: the best settings so far |
| C | wine-c (IC 53071896) | ADD probe: one pip from the anchor's add, per side |
| D | wine-d (IC 53077984) | EXIT probe: one pip from the anchor's exit, per side |
| A | FTMO VPS (1514731800) | live, anchors only, own frozen-cycle rules |

Roles stay with the fleet. B, C and D run the SAME pairs, the same cap,
width, lattice and code, so each side is compared across fleets on the
same ticks. From round 2: **one instance per pair** (the AUDNZD and NZDCAD
twins retire at the Monday build; "twins decide" was used once, round 1).

**Control pair: NZDCAD** (operator 3 Oct, "as long as it doesnt cause
issues with slot/api limits"): on the anchor on B, C and D every round,
never probed. It is one of the nine instances, so it costs no extra slot
or request. Its same-settings gaps (B-C, B-D, C-D, both sides) measure the
round's noise (s4.3). It held the anchor on all three fleets in round 1
too, so its record is continuous.

## 3. PAIRS

- **IC: the nine pairs stay** (operator 3 Oct: more compass data points):
  GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, NZDCHF, NZDCAD, AUDNZD.
  The 1 Oct plan (each IC fleet a seven-pair ring) is withdrawn.
- **FTMO: the seven** cut on 2 Oct (FTMO's request warning): EURUSD,
  GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCAD, AUDNZD.
- **Slots at cap 10** (~18 per instance, guard 194): 9 instances ~162; 10
  ~180; 11 ~198 (over). So at cap 10: the nine pairs, or ONE scouting pair
  added, or scouts REPLACING AUDCAD / NZDCHF (the week's weakest droppable
  pairing; NZDCHF also the dearest by spread vs range). **Decided 3 Oct
  ~19:40Z (operator, on Claude's suggestion; "the more data we gather the
  better"): ONE scout, AUDUSD, ADDED at the cap-10 reload: ten
  instances per IC fleet (~180 of 194).**
- **Scouting candidates** (AUDUSD chosen 3 Oct): the single ring's two new
  crosses (EURCAD, GBPCHF; MEMO_2026-10-03 s8) or a cheap major (AUDUSD,
  USDCAD: spread vs hourly range 0.04-0.06 against 0.10-0.19 for our
  crosses, FTMO 20 Sep - 2 Oct). **A scout's first round is a baseline**
  (GC-3): the same derived geometry on B, C and D, no probe; its gaps join
  the noise sample.
- **AUDUSD, why:** the cheapest candidate by spread vs hourly range
  (0.038), so it tests the cheap-major question most directly; every
  candidate puts a fourth leg on one of AUD / CAD / CHF / NZD (the
  EUR / USD / GBP triangle is complete), AUDUSD on AUD (GBPCHF ruled
  out: CHF capped three pairs on 1 Oct; USDCAD the alternative). Added
  in the cap-10 reload so the pools restart once. Needs: presets B, C, D
  with a new magic, a baseline geometry from the spread / range data
  (Gemini, with the reload plan), a pipshed change (tests first) adding
  it to the three fleets' lists, register rows. No EA change: the only
  fleet-magic table in the EA is the disabled currency cap's (C32).
- **AUDUSD baseline geometry (Claude, 3 Oct; for Gemini with the reload
  plan):** width 2 / add 6 / exit 10, cap 10, `InpStrandedThreshPips` 3
  (W + 1), deadband 4, magic 22261001, ids `GRIND_AUDUSD_OPT{B,C,D}`,
  the same on B, C and D (presets `ea/presets_{b,c,d}/audusd_opt_*_c10.set`,
  key blank). Add: the nine anchors' add / median hourly range is 0.57-0.80
  (median 0.70); AUDUSD's hourly range is 8.0 pips (FTMO 20 Sep - 2 Oct,
  excl. 20-21Z), so 5.6, rounded to 6 (half pips are OPEN, s9; AUDCAD,
  range 9.4, runs add 6). Exit 10 as on every pair but EURGBP (exit /
  hourly range 1.25, inside the anchors' 0.81-1.89). Width by s6: (6 + 2) /
  4 = 2.0. Guard: add / width 3.0 (2.5-3.5 for the later one-pip add
  probes). Roll cost at cap 10: 10 x 6 - 10 = 50 pips per roll; ten
  layers span 60 pips against a 39-pip median day.
- **pipshed C121 ready (3 Oct, not pushed):** `GRIND_AUDUSD_OPT{B,C,D}` in
  the B, C, D lists (pages and strips), a "scouts" ring shown only on
  fleets that have it (FTMO's page unchanged). Built on C119: in
  Downloads as `pipshed_c121_audusd_APPLY_AFTER_C119_AT_CAP10_RELOAD.patch`
  (tests commit then fix; tree `ac81ba6d` after C119's `e3b23a94`; go by
  the trees, the hashes change at `git am`). Deploy only once the three
  AUDUSD charts are attached (else the strip reads PARTIAL 9/10).
- **Later structural step (not this cycle):** a single seven-currency
  ring per account (360 exist; candidates in MEMO_2026-10-03 s8).

## 4. THE LOOP (one round)

1. **Round window:** two full FTMO days (22:00Z-22:00Z) after the LAST
   reload of the round; weekend days do not count. **A round never spans
   a structural change** (code build, ADR-165 on/off, cap, width, pair
   set, twin retirement): the next round starts after the last such
   change and its watch.
2. **Score** after the second day's 22:00Z: fresh study export
   (`archive_counts.py --export-study --days 14`), then
   `compass_score.py --export <file> --round roundN.json --bidask <IC
   folder>`. It flags data that ends before the round ends (provisional,
   not a verdict). Inputs, after the round's last 22:00Z:
   - the study export (`D:\pipshed`, `railway ssh ... --export-study
     --days 14` into Downloads);
   - IC bid/ask for the round's pairs: `grind_bidask_dump.mq5` on wine-c,
     `InpFrom` = the round's first window start in SERVER time (UTC + 3:
     22:00Z -> 01:00), copied to Downloads by scp;
   - the journals of wine-test, wine-c and wine-d for the round's dates
     (`<install>/logs/YYYYMMDD.log`, scp), then
     `python research/compass/disconnects.py <files>` per box.
3. **Threshold** (GC-1): max($1.19, the pooled median of this round's
   same-settings gaps: the control pair's six gaps (two sides x three fleet pairs) and any
   scout baseline). It can only rise above $1.19. **Round 1 (s49):**
   `round1.json` fixes $1.19 (AUDNZD long twin $1.40) and the scorer
   does not compute the control gaps; GC-1 was accepted after round 1
   began. At round 1's scoring BOTH are computed and reported (the fixed
   $1.19 and max($1.19, NZDCAD's six gaps, NZDCAD_OPT B, C and D, all
   three on the anchor in round 1)), and the operator chooses which one
   decides round 1. From round 2 GC-1 decides. **Round 1 decided by
   GC-1 = $2.55 (operator 5 Oct ~22:15Z; s11).** `compass_score.py` prints
   both (the round file's `control` block; a second table under GC-1).
4. **Verdict per pair and side** (fleet-d s6.5 as amended by Gemini s6.8):
   - margin = probe per day - comparator per day;
   - margin > threshold: WIN; < -threshold: LOSE; else REPEAT (the same
     probe again);
   - ADD probes need two gates before WIN: the entry-time split must not
     lose by more than the threshold (GD1-4) and closed net per layer-hour
     must be no worse (GD1-5); else REPEAT_GATE;
   - both C and D win on a side: the larger margin is promoted; the other
     lever probes again around the new anchor;
   - **a REPEAT pools the probe's days over rounds only while the
     structure is unchanged; the pool restarts at every structural change**
     (GC-2);
   - **cuts** (s5): a comparison touched by a hand intervention is scored
     before the cut, or VOID.
5. **Next probes** (cycle-4 s8.4): one pip from the anchor, on the side
   the evidence points to; a loser flips across the anchor; explore
   outward while the anchor keeps losing on one side; once both sides of
   a lever lose, refine inward in half pips (floor OPEN, s9).
6. **Write** `roundN+1.json` and presets: B gets promoted anchors, C and D
   the new probes (`ea/presets_{b,c,d}/*_pN.set`), each read back (input
   count, key blank, per-side -1, add / width guard ratio in range).
   Width follows s6.
7. **Gemini** reviews the round's verdict table and probe table before
   any reload (the method once: this document; per round: the tables and
   any deviation from it).
8. **Reload in session:** spreads under every width; never 20:50-21:00Z
   or within 30 minutes of a tier-1 release; wine-d first, GBPUSD pilot;
   per chart pass = `deinit=5`, `geo=` and `rebuild=` as expected, POST
   ok; STOP on FATAL, CRITICAL, `INVARIANT_FAIL`, `RECON_FAIL`,
   `REBUILD_EXIT_*`, a wrong `geo=`/`rebuild=`, or no POST ok. Read the
   magic before Load on any chart that shares a title (1 Oct incident).
9. **Record:** register rows (close old, open new at the reload time from
   the log); a round section in the compass record (times, pass lines,
   interventions, verdicts).

## 5. CHANGES INSIDE A ROUND

Only when forced (safety, broker, a defect).
- **Fleet-wide changes made alike on B, C and D** (2 Oct: breaker and gate
  off; `InpStrandedThreshPips` = width + 1; the API stop raised): recorded
  with their times in the round's amendments; they cut nothing.
- **A side-specific hand intervention** (a hand eject, a manual close, a
  reload of one chart) on one fleet's pair-side **cuts** every comparison
  involving that fleet on that pair-side (GC-4 as amended by the operator:
  "throwing away all the data seems excessive ... we could also salvage
  data up to the hand eject if there was enough of it"): scored on the
  windows before the first such intervention if at least one FTMO day
  remains, else VOID. Listed in `roundN.json` `interventions` (pair, side,
  fleet, time); `compass_score.py` applies it (29 tests).
- Round 1: NZDCHF long B 02:26:15Z and C 02:29:27Z, AUDCHF long C
  03:51:45Z (2 Oct, window 1): NZDCHF long (C and D comparisons) and
  AUDCHF long (C) are VOID; D vs B on AUDCHF long stands.

## 6. WIDTH (not a lever; fixed per pair)

Width is part of the anchor, the same on B, C and D (operator 2 Oct: as
low as possible). **Fixed per pair** (GC-7: tying it to the round's
largest add would move the anchor's own geometry whenever C probes wider):
set once at the cap-10 reload as (anchor add + 2) / 4 rounded UP to the
half pip, which leaves room for two one-pip add steps inside the ADR-153
guard (add / width <= 4). It changes only when an add would break the
guard, and that change is structural (s4.1). A near-zero counter-side
width and a re-derived guard are v2.2 (C103).

**This week (memo 2026-10-05, cap 8):** the tightest width the guard
allows instead, ceil to the half pip of the round's largest add (any
fleet) / 4, one width per pair on B, C and D, re-derived each round
(`ic_presets.py --stage round`). The cap-10 rule above returns with cap
10.

## 7. CALENDAR (as planned)

1. Round 1 (twins included, cap 8): Fri 2 + Mon 5 Oct; score Mon after
   22:00Z (cuts as s5).
2. Monday build (structural): C105 merge, ADR-165 ON on B, C, D; twins
   retire.
3. Next session (structural): cap 10 + the fixed widths in ONE reload per
   chart (preset-only; `docs/runbooks/cap10-reload.md`, drafted s50); an hour's watch on the slot guard and requests;
   the AUDUSD scout added in the same reload (s3; baseline round).
   **(5 Oct, memo: replaced this week by cap 8, tight widths, deadband 2
   and round 2's probes in ONE reload Tue 6 Oct; round 2 = Wed 7 + Thu 8;
   round 3 reload Fri 9, its days Mon 12 + Tue 13. Cap 10 and AUDUSD
   deferred.)**
4. Round 2's probe reloads (NZDCAD stays on the anchor everywhere), then
   its two days.

## 8. PROMOTION TO FTMO

An anchor held for N rounds (N OPEN) moves to A, inside A's frozen-cycle
rules (A may change ADD only until cycle 3 ends), if its **worst intraday
drawdown, closed + open (peak MTM), including what it carries across the
22:00Z day-roll** (GC-5), fits FTMO's daily limit ($500 on 10k). A keeps
being compared with its lab anchor (broker drift).

## 9. OPEN

N for promotion; the half-pip floor and adds below 3 (5 Oct: one
half-pip add probe allowed, EURGBP long C 2.5, `"half": true`, floor
2.5; to Gemini with round 2's tables); the smallest exit
worth its commission; whether `InpStrandedThreshPips` ever becomes a
lever.

## 10. GEMINI'S RULINGS (3 OCT) AND THE OUTCOME

| | Gemini | Outcome |
|---|---|---|
| GC-1 | threshold max($1.19, re-estimate) | ACCEPTED; re-estimated from the control pair (s2) and scout baselines |
| GC-2 | restart the pool at structural changes | ACCEPTED |
| GC-3 | a scout's first round is a baseline | ACCEPTED |
| GC-4 | void a pair-side after any manual intervention | AMENDED by the operator: cut, salvage at least one day, else VOID; fleet-wide uniform changes cut nothing (his premise holds for hand ejects minutes apart, not for one-input changes on every chart) |
| GC-5 | promotion on closed + open (peak MTM) drawdown | ACCEPTED |
| GC-6 | peak open MTM as a REPEAT_GATE for add probes | REJECTED by the operator (realised P&L decides; open risk at promotion, GC-5); MTM REPORTED. His missing fact (broker disconnects) ACCEPTED as reported |
| GC-7 | fix width per pair | ACCEPTED, with headroom (s6) |

## 11. ROUND RECORDS

**Round 1** (FTMO days Fri 2 + Mon 5 Oct; scored 5 Oct ~22:12Z on
`study_2026-10-05_14d.jsonl`, data to 22:05Z, final). Threshold: GC-1
$2.55 (NZDCAD gaps L 5.18 / 9.32 / 4.14, S 0.63 / 0.96 / 0.33; the fixed
$1.19 also reported). Promoted: EURUSD L add 6 (C +4.20), AUDCAD L exit 9
(D +3.96), AUDNZD S add 7 (C twin +5.47). LOSE: EURUSD L D -10.77, EURUSD
S D -3.61, EURGBP L C -6.32 and D -4.38, CADCHF L D -4.71. VOID: NZDCHF L
(C, D), AUDCHF L C. The rest REPEAT. Disconnects inside the windows: none.
Interventions: the three of `round1.json`. Then the Monday build
(structural). Round 2's table: `scripts/ic_geometry_r2.json` (`646a387`);
HANDOFF s58.

**Round 2** (FTMO days Wed 7 + Thu 8; reload Tue 6 Oct). Gemini GR2-1..GR2-6
and the operator (6 Oct ~01:31Z-01:38Z; `docs/research/compass-round2-review.md`
s6): **no promotion this round** (a WIN repeats once under the new structure
before promotion; the winners repeat as probes); probes as planned (no
baseline round); EURGBP L C add 2.5 stands; the flips stand; **open MTM
reported at every scoring from round 2 (the IC bid / ask dump compulsory),
realised decides**. **Reloaded 6 Oct 03:18-03:35Z** (D 03:18-03:22, C
03:25-03:28, B 03:32-03:35; BAD 0; HANDOFF s61); round file
`research/compass/round2.json`; windows 6 Oct 22:00Z - 8 Oct 22:00Z.

Line count: 277
