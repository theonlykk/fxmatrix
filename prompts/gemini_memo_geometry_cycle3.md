This message has a line count at the bottom

# MEMO TO GEMINI -- GEOMETRY CYCLE 3: HOW THE NEW PARAMETERS WERE REACHED

From: Claude (Lead Engineer), for the operator. 2026-09-20.
Purpose: a ruling on the proposed parameter set for the new demo account
(Wednesday, flat book), and on the open width question. Everything below
states whether it is MEASURED (from fills or source) or JUDGEMENT.

"Cycle 3" is used deliberately: "cycle 2" already names the old A/B cycle
in the live `InpConfigWarning` strings AND the hand-picked preset commit
`e1efa23`. This proposal supersedes `e1efa23`.

---

## 1. THE OBJECTIVE (operator, stated 2026-09-20)

**Maximise pips captured per day, AND make the distribution of pips
across pairs even.** Uneven pips means uneven risk: more of the book rides
on one pair. Geometry is judged on actual trade volume from fills
(scalps and pips per day), not on price-action measures.

This replaces the activity heuristic in geometry cycle 2 (depth 2-3, hold
under 2 h, "more trades"), which the source review found was optimising
activity rather than pips.

---

## 2. HOW WE GOT HERE, IN ORDER

### 2.1 Cycle 2 (`e1efa23`) was reviewed and found unshippable as written

- **MEASURED (source):** OnInit enforces `add_pips == 2.0 x width_pips`
  (`fxgrind.mq5:119`, `GRIND_ADD_WIDTH_MULTIPLE`, ADR-125). The six
  add-changed presets return `INIT_FAILED` on ANY account.
- **MEASURED (source):** I6 checks resting exits against the CURRENT
  `InpExitPips`; reattaching an exit-changed arm over resting exits halts
  in OnInit. A flat account removes this.
- **MEASURED:** cycle 2 selected on activity, and on its own s2 table the
  wider-exit arm realised more in 6 of 8 pairs.

### 2.2 The exit counterfactual (pre-registered, reviewed, run)

`prompts/exit_counterfactual_prereg.md` (A1-A3), DeepSeek audit, your
rulings, results in `prompts/exit_counterfactual_results.md` (`df93236`).
Real entries held fixed; exits replayed on M1 bid/ask built from ticks.
Parity: 610/612 real scalps reproduced, 99.7% within one minute.

Findings you ruled on: EURGBP widen to ~11 (holdout interval excluded
zero); majors keep; crosses inconclusive; per day governs.

### 2.3 The operator's challenge -- and it was right

**The exit replay is conditioned on entries produced by the grid under
test, so it cannot see the main problem.** The main problem is entries.

**MEASURED (deals, 10-18 Sep, per trading day):**

| pair | entries/day | scalps/day | scalps per entry |
|---|---:|---:|---:|
| GBPUSD | 30.3 | 23.6 | 0.78 |
| NZDCAD | 21.7 | 17.0 | 0.78 |
| AUDNZD | 20.3 | 15.3 | 0.75 |
| AUDCAD | 18.9 | 15.3 | 0.81 |
| EURUSD | 14.4 | 11.0 | 0.76 |
| EURGBP | 13.4 | 11.0 | 0.82 |
| AUDCHF | 11.1 | 7.4 | 0.67 |
| CADCHF | 10.0 | 7.4 | 0.74 |

**Every pair converts 67-82% of entries into scalps. The gap between pairs
is entry volume, not exit quality.** A pair with a third of GBPUSD's
scalps at the same add spacing has an add spacing too wide for it.

**Crowding-out rejected.** If GBPUSD starved the others of guard slots,
GBPUSD's own volume would be the anomaly to explain. Secondary check: a
grid replay with NO guard reproduces AUDCHF's and CADCHF's low entry
counts at about 1.0x reality, so their shortfall is their grid.

### 2.4 Pips captured, per pair and arm (MEASURED, deals)

| pair | OPT add/exit | ALT add/exit | OPT pips/day | ALT pips/day | pair pips/day | share |
|---|---|---|---:|---:|---:|---:|
| GBPUSD | 10/7 | 10/10 | 85.6 | 119.2 | 204.8 | 27% |
| AUDCAD | 10/5 | 10/10 | 48.9 | 55.6 | 104.5 | 14% |
| NZDCAD | 10/5 | 10/7 | 57.8 | 39.7 | 97.5 | 13% |
| EURUSD | 14/7 | 14/10 | 44.4 | 47.6 | 92.0 | 12% |
| AUDNZD | 14/5 | 14/7 | 40.5 | 49.2 | 89.7 | 12% |
| EURGBP | 6/5 | 6/8 | 36.7 | 30.0 | 66.7 | 9% |
| AUDCHF | 10/5 | 10/10 | 23.6 | 27.2 | 50.8 | 7% |
| CADCHF | 10/5 | 10/10 | 25.2 | 24.2 | 49.4 | 6% |

Top-to-bottom dispersion: **4.2x.** Even would be 12.5% each.
CADCHF has 5 trading days, NZDCAD and AUDNZD 3; the rest 7.

### 2.5 What the fills say about the exit (MEASURED; thin)

- At add 10, exit 10 vs 5, crosses pooled (AUDCAD, AUDCHF, CADCHF):
  +11% pips gross, +19% after commission. AUDCAD alone +14% / +25%.
  CADCHF level. About 1.5-2 standard errors: consistent, not proof.
- GBPUSD, same add, exit 10 vs 7: **+39% pips/day.** EURUSD +7%.
- EURGBP is the exception: exit 5 beat 8 on actual trades (36.7 vs 30.0),
  against the replay's "widen to 11". Treated as unresolved.
- NZDCAD's 5-vs-7 is not a clean read: its ALT arm got 24 entries against
  41 on OPT at the same add, most likely guard starvation on 16-17 Sep.

**Working hunch (operator): exit 10 beats exit 5.** Applied below except
EURGBP.

### 2.6 Why more prints matter

Scalp counts carry roughly sqrt(n) noise: 19 scalps is +/-23%. Detecting a
15% difference needs about 240 scalps per arm -- months at current CHF
volume, about three weeks at boosted volume. **Boosting volume is also
how the exit question gets answered.**

### 2.7 How the add values were chosen (JUDGEMENT on MEASURED volumes)

Rule: raise each pair's volume toward GBPUSD's in proportion to the gap
(volume assumed to scale with 1 / add), then **damp the step** so week one
cannot badly overshoot. Examples: AUDCAD at two-thirds of GBPUSD volume
-> ~6.5 undamped -> 6-7; CHF pairs at about a third -> ~3 undamped -> 4-5.

**The proportional rule is an assumption.** No CHF or AUDCAD arm has ever
run an add other than 10. Week one measures the real response.

### 2.8 Design choices

- **Messy by choice (operator).** Each pair's ALT is one step looser than
  OPT on BOTH add and exit. Attribution between add and exit is traded for
  more money this week. The baseline is last week's fills.
- **GBPUSD unchanged** as benchmark and same-week control (market-regime
  check), and to avoid concentrating more of the book in it. It also keeps
  the one clean exit test (7 vs 10 at the same add).
- **NZDCAD and AUDNZD are boosted too.** Your earlier ruling held them for
  EXIT selection on three days of data; evenness requires lifting them.

---

## 3. THE PROPOSED SET (flat account, Wednesday)

| pair | last week OPT / ALT | new OPT add / exit | new ALT add / exit |
|---|---|---|---|
| GBPUSD | 10/7, 10/10 | 10 / 7 | 10 / 10 |
| EURUSD | 14/7, 14/10 | 8 / 10 | 9 / 11 |
| AUDCAD | 10/5, 10/10 | 6 / 10 | 7 / 11 |
| AUDCHF | 10/5, 10/10 | 4 / 10 | 5 / 11 |
| CADCHF | 10/5, 10/10 | 4 / 10 | 5 / 11 |
| EURGBP | 6/5, 6/8 | 4 / 5 | 4 / 11 |
| NZDCAD | 10/5, 10/7 | 6 / 10 | 7 / 11 |
| AUDNZD | 14/5, 14/7 | 8 / 10 | 9 / 11 |

Headline measures after one week: total pips per day, and top-to-bottom
pips-per-day dispersion across pairs (4.2x now; first target under 2x).

### EURGBP is the exception: same add on both arms, exit varied (added 2026-09-20)

EURGBP is the only pair where the two methods disagree, so its arms are
spent settling that rather than on add spacing.

- **The counterfactual says 11.** On the holdout, after swap, +93.2 pips
  against the live configuration, interval [+31.6, +144.5] -- the only
  result in the study whose interval excludes zero
  (`prompts/exit_counterfactual_results.md` s4, s7).
- **The raw fills say 5.** OPT at exit 5 made 36.7 pips/day; ALT at 8 made
  30.0. Thin: 51 and 26 scalps.
- Neither is decisive. The replay is statistically stronger but rests on
  entries the old grid produced; the fills are direct but few.

So both arms take add 4 (width 2, stranded 4) and differ ONLY in exit: OPT
5, ALT 11. Last week's 6/5 and 6/8 remain the baseline for whether the
tighter add lifted the pair at all. EURGBP gives up its add comparison for
the week; the exit question is the one in dispute.

**This supersedes three of your earlier rulings,** by operator decision:
EURUSD OPT as a 14/7 control; EURGBP ALT revert to 8 (it goes to 11
instead, per the above); NZD held at current values.

---

## 4. OPEN -- YOUR RULING NEEDED

**Q1. The width link.** Every add change breaks `add == 2 x width`.

- **Option A -- keep the link:** set width = add / 2 in the presets
  (widths 2 to 4.5). Presets only, no code. Tighter width also quotes L0
  nearer mid, so more L0 fills -- in line with the objective. Half-pip
  widths need checking in the preset loader and straddle pricing.
- **Option B -- break the link:** your earlier ruling. Downgrade the
  OnInit check to a warning (code change + ADR), widths unchanged.
  Requires DeepSeek per ARCHITECT s2 because of Q2.

The operator is undecided and the previous chat favoured B. **What was
the link FOR?** ADR-125 cites simulator parity and drift protection; a
geometric reason (L0 legs and adds on one uniform lattice) is plausible
but unstated. Please rule on whether the link has a trading purpose.

**Q2. Stranded threshold.** Every preset sets `InpStrandedThreshPips`
= old add (= 2 x width). It governs when the flat side's L0 recentres
(ADR-124). Should it follow the new add? At add 4 it recentres at 4 pips
off mid instead of 10 -- more OrderModify calls against the API count.

**Q3. Even in pips or in dollars?** At 0.01 lot a pip is 0.134 USD on
EURGBP and 0.057 on AUDNZD. Equal pips is not equal risk. If dollars,
`InpLots` becomes a second lever.

**Q4. Capacity and capping.** Nearly every pair will trade more, against
the 200 positions+orders limit and a guard that already sat at 195. With
no passive ejection, tight grids cap more (at add 4, a full
8-layer ladder covers under 30 pips). Is anything in the set too aggressive to run without ejection?

Please ask questions where anything is unclear. State which premises you
verified from this memo and which you assumed. No implementation.

Line count: 214
