This message has a line count at the bottom

# GEOMETRY CYCLE 2 -- WHERE THE VALUES CAME FROM

Written 2026-09-20 in answer to the next session's question. The values were
merged at `e1efa23` with **no spec in the repo** -- the derivation happened in
chat and only the measurement survived. This memo is the missing record.

**It also states plainly what was NOT done. See s5.**

---

## 1. THE QUESTION BEING ANSWERED

Is any pair's `add_pips` or `exit_pips` wrong for what that pair actually
does?

**Not "what is optimal".** The instrument is our own fill history, so the
readings are conditioned on the real guard, the real spread and the grid we
are actually running. Each parameter has one direct reading:

- **`add_pips` reads from LADDER DEPTH.** Capping constantly means the step
  is too TIGHT -- inventory stacks faster than price mean-reverts. Never
  passing layer 1 means it is too WIDE to catch the moves that happen.
- **`exit_pips` reads from HOLD TIME.** Seconds means too SHORT, money left
  on the table. Hours means too WIDE -- inventory held, slot blocked.

**No ATR, no volatility model.** M5 volatility cannot be backtested
reliably, and a modelled proxy would stand in for something directly
observable. This replaced an earlier plan to normalise `add_pips` by
volatility -- Gemini's ruling on that is superseded (s4).

---

## 2. THE MEASUREMENT

`scripts/measure_geometry_depth_holdtime.py`, report
`prompts/geometry_depth_holdtime.md`, branch
`research/geometry-depth-holdtime`, merged.

2,716 deals, 2026-09-10 to 2026-09-18. Nine days, one regime, **fleet
guard-saturated throughout.**

**Structural finding worth keeping:** zero positions have ENT and EXT on the
same `position_id`. Under ADR-151 the exit limit fills as a NEW position and
CloseBy nets the pair, so hold time is paired via the CloseBy comment
(`#ent by #ext`). Any future deal-history work needs this.

| symbol | arm | add | exit | mean_depth | pct_at_cap | med_hold_min | scalps | net/scalp |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| GBPUSD | OPT | 10 | 7 | 3.68 | 22.0 | 117 | 84 | 0.65 |
| GBPUSD | ALT | 10 | 10 | 4.05 | 24.3 | 194 | 81 | 0.96 |
| EURUSD | OPT | 14 | 7 | 2.67 | 19.3 | 252 | 44 | 0.63 |
| EURUSD | ALT | 14 | 10 | 2.57 | 20.5 | 348 | 33 | 0.94 |
| EURGBP | OPT | 6 | 5 | 2.81 | 5.1 | 276 | 51 | 0.55 |
| EURGBP | ALT | 6 | 8 | 2.66 | 5.7 | **1703** | 26 | 0.87 |
| AUDCAD | OPT | 10 | 5 | 2.04 | 3.7 | 131 | 68 | 0.30 |
| AUDCAD | ALT | 10 | 10 | 1.86 | 3.9 | 614 | 39 | 0.65 |
| AUDCHF | OPT | 10 | 5 | 1.38 | 0.0 | 695 | 33 | 0.54 |
| AUDCHF | ALT | 10 | 10 | 1.67 | 0.0 | **3495** | 19 | 1.13 |
| CADCHF | OPT | 10 | 5 | 1.38 | 0.0 | 396 | 25 | 0.52 |
| CADCHF | ALT | 10 | 10 | 1.44 | 0.0 | **2115** | 12 | 1.10 |
| NZDCAD | OPT | 10 | 5 | 1.61 | 0.0 | 156 | 34 | 0.30 |
| NZDCAD | ALT | 10 | 7 | 0.92 | 0.0 | 320 | 17 | 0.44 |
| AUDNZD | OPT | 14 | 5 | **0.70** | 0.0 | 153 | 25 | 0.21 |
| AUDNZD | ALT | 14 | 7 | 1.00 | 0.0 | 142 | 21 | 0.34 |

### The L0-versus-adds split

`mean_depth` alone conflates two things. Separating entry fills from
subsequent adds, per symbol over the nine days:

| symbol | width | add | L0 fills | adds | L0/day | **adds/L0** |
|---|---:|---:|---:|---:|---:|---:|
| EURGBP | 3 | 6 | 19 | 75 | 2.1 | **3.95** |
| CADCHF | 5 | 10 | 12 | 38 | 1.3 | 3.17 |
| GBPUSD | 5 | 10 | 58 | 154 | 6.4 | 2.66 |
| AUDCAD | 5 | 10 | 38 | 94 | 4.2 | 2.47 |
| NZDCAD | 5 | 10 | 19 | 46 | 2.1 | 2.42 |
| AUDCHF | 5 | 10 | 26 | 52 | 2.9 | 2.00 |
| EURUSD | 7 | 14 | 34 | 67 | 3.8 | 1.97 |
| AUDNZD | 7 | 14 | 27 | 34 | 3.0 | **1.26** |

**`adds/L0` tracks `add_pips` almost monotonically.** That is the whole basis
of the change.

**AUDNZD is not short of ENTRIES** -- 3.0 L0 fills/day, mid-table. It is
short of ADDS. **The step is too wide; the quote is not.**

**Independent corroboration:** the ejection stability study
(`prompts/ejection_stability_window.md`) found AUDNZD's `pct_c1` at
`range_mult = 1.0` is 95% -- its typical M5 range is NARROWER than its own
14-pip step -- versus 65% for GBPUSD. Two different measurements, same
conclusion.

---

## 3. HOW THE VALUES WERE CHOSEN

Targets: mean depth 2-3, cap under 10%, median hold under ~2 h, more trades.

| pair | was OPT | was ALT | new OPT | new ALT | reasoning |
|---|---|---|---|---|---|
| AUDNZD | 14/5 | 14/7 | **7/5** | **10/7** | depth 0.70/1.00, `adds/L0` 1.26. Halve the step; A/B 7 vs 10 |
| NZDCAD | 10/5 | 10/7 | **7/5** | 10/7 | depth 1.61/0.92, never caps. ALT unchanged = control |
| AUDCHF | 10/5 | 10/10 | **7/5** | **10/7** | depth 1.4; ALT holds 58 h |
| CADCHF | 10/5 | 10/10 | **7/5** | **10/7** | depth 1.4; ALT holds 35 h |
| AUDCAD | 10/5 | 10/10 | 10/5 | **10/7** | depth ~2 is fine; only the 10 h hold is wrong |
| EURGBP | 6/5 | 6/8 | 6/5 | **6/6** | best ladder in the fleet; only the 28 h hold |
| EURUSD | 14/7 | 14/10 | **14/5** | **14/7** | depth fine, 4-6 h holds too slow |
| GBPUSD | 10/7 | 10/10 | 10/7 | **14/10** | only pair that caps; ALT widens to test |

**Controls, zero diff:** `audcad_opt`, `eurgbp_opt`, `gbpusd_opt`,
`nzdcad_alt` (the last already sat at the proposed 10/7).

**12 files change, one line each** -- 6 change `InpAddPips` only, 6 change
`InpExitPips` only, none change both.

### `InpWidthPips` deliberately unchanged on all 16

Width is the L0 straddle half-width (`mid -/+ width`), currently exactly half
`add_pips` on every pair. Tightening `add_pips` breaks the ratio. **Leave it
broken.** **[CORRECTED -- s6.1: the EA refuses to start when the ratio is
broken.]**

The data says width is not the constraint: **EURGBP quotes the narrowest
market (3) and gets the FEWEST L0 fills/day (2.1)**; CADCHF quotes 5 and gets
1.3. L0 fill rate tracks the pair's own activity, not how tight we quote.
Changing it would add a second uncontrolled variable.

---

## 4. WHAT GEMINI RULED

Two rulings, and the second supersedes the first.

**Earlier (s2k of `exitq-barbell-notes.md`):** `add_pips` must become a
function of volatility; geometry before ejection; pin nothing.

**Later, on the fill-based approach:** *"It completely replaces it. A
market-maker does not trade volatility; it trades the crossing of its limit
nodes... We do not need a model; we have the receipts. Drop the ATR
normalisation."* Also: saturation bias is **one-way and therefore safe** -- it
strictly understates depth, so a pair that caps despite starvation is
catastrophically tight, and a pair that never passes layer 1 never requested
capacity. And: run the live A/B rather than a simulator.

**On the values themselves:** *"Ship them exactly as written."* Slashing the
10-pip exits on the quiet crosses called the most critical move; GBPUSD ALT
widening approved because *"you cannot test a ceiling expansion on a pair
that never leaves the floor."*

**s2k's text was never updated to say it is superseded.** It should be.

---

## 5. WHAT WAS NOT DONE -- READ THIS BEFORE DEPLOYING

**No spec was written.** The derivation lived in chat. Only
`prompts/geometry_depth_holdtime.md` (the measurement) and
`prompts/geometry_cycle2_response.md` (Cursor's edit record) reached the
repo. **This memo is the retrofit.**

**DeepSeek was not consulted.** ARCHITECT s2 makes it mandatory for grid
spacing. It was skipped.

**No pre-registered calibration/holdout split.** ARCHITECT s12 requires one.
There is none.

**EURUSD changes BOTH arms**, so that pair has no control and its result will
not be attributable. A genuine design flaw, not a considered trade-off.

**One regime, nine days, guard-saturated.** Gemini ruled the saturation bias
one-way, but the sample is still small and single-regime.

**And the deploy is currently blocked.** `fxgrind.mq5:149` sets
`g_grind_recon_exit_pips = InpExitPips`, and I6 checks each resting exit
against it at 2-point tolerance. **The six arms whose `exit_pips` changes all
hold resting exits priced to the OLD value, so reattaching any of them halts
in OnInit** -- EURUSD OPT and ALT, EURGBP ALT, AUDCAD ALT, AUDCHF ALT,
CADCHF ALT. No staging plan was discussed. **The Sunday plan in
`NEW_CHAT_PROMPT.md` s5 does not account for this and must be reworked.**

The six `add_pips`-only arms do not have this problem -- `add_pips` does not
enter I6. **[CORRECTED -- s6.1: true of I6, but those six fail OnInit
outright on the add/width ratio, even on a flat account.]**

---

## 6. ADDENDUM, 2026-09-20 -- REVIEW AGAINST SOURCE

### 6.1 The six add_pips presets cannot start. Blocks Wednesday.

`fxgrind.mq5:119` calls `Grind_ValidateAddWidthRelationship`
(`grind_pure.mqh:40`): `add_pips` must equal `GRIND_ADD_WIDTH_MULTIPLE`
(2.0) x `width_pips` to 1e-8, or OnInit prints FATAL and returns
`INIT_FAILED`. MT5 then removes the EA from the chart.

| preset | width | new add | required add |
|---|---:|---:|---:|
| audchf_opt | 5 | 7 | 10 |
| cadchf_opt | 5 | 7 | 10 |
| nzdcad_opt | 5 | 7 | 10 |
| audnzd_opt | 7 | 7 | 14 |
| audnzd_alt | 7 | 10 | 14 |
| gbpusd_alt | 5 | 14 | 10 |

This fails on ANY account, flat or not. It is independent of the I6
reattach hazard in s5, which a flat account avoids.

**Where the rule came from:** ADR-125 (`0bd0877`, 2026-09-06). Add spacing
was fixed at 2 x width "matching `scripts/grid_sim_v7_real_signal.py`", and
a preset that drifts from it fails at init by design. Stated reasons are
simulator parity and drift protection. A likely geometric reason is not
stated: with L0s at `mid -/+ width`, `add = 2 x width` puts both straddle
legs and every add on one uniform lattice. **Not verified -- ask before
relying on it.**

**Two ways out, pulling in opposite directions:**

- **Change width to match** (3.5, 3.5, 3.5, 3.5, 5, 7). Keeps the rule, but
  every add-changed arm now changes TWO things, including the L0 quote --
  the confound s3 set out to avoid.
- **Relax the rule.** A code change with its own ADR, and the simulator
  loses parity with the EA on those arms.

**Needs a Gemini ruling before any add_pips change deploys.** The six
exit_pips changes are unaffected and can deploy on a flat account.

### 6.2 The criterion was activity. It should be net pips.

s3's targets -- depth 2-3, cap under 10%, hold under ~2 h, more trades --
measure activity. The objective is **net pips**: two scalps of 5 pips beat
four of 2. On the s2 table itself (scalps x net/scalp, realised only):

| pair | OPT realised | ALT realised | wider exit was |
|---|---:|---:|---|
| GBPUSD | 54.6 | 77.8 | ALT, better |
| EURUSD | 27.7 | 31.0 | ALT, better |
| EURGBP | 28.1 | 22.6 | ALT, worse |
| AUDCAD | 20.4 | 25.4 | ALT, better |
| AUDCHF | 17.8 | 21.5 | ALT, better |
| CADCHF | 13.0 | 13.2 | ALT, level |
| NZDCAD | 10.2 | 7.5 | ALT, worse |
| AUDNZD | 5.2 | 7.1 | ALT, better |

The wider exit realised more in six of eight pairs, yet cycle 2 tightens
five ALT exits toward values their OPT arm already ran and realised less.

**Not conclusive:** realised scalp P&L only, nine days, one regime, guard
saturated, and the MTM of held inventory is excluded -- which is exactly
the term that favours tighter exits. The counter-argument (long holds tie
up slots on a saturated guard) is real but has to be PRICED, not assumed.
s7 is how.

---

## 7. PROPOSED METHOD -- MAXIMISING NET PIPS FROM THE FILLS WE HAVE

### 7.1 The objective

Per pair and parameter value:

    net pips = realised (exit - entry, signed)
             - commission (from the deal records, converted to pips)
             + swap (from the deal records)
             + MTM of layers still open at window end

The last term is not optional. Without it a wider exit looks free: the
layers that never reach it simply vanish from the sum.

Report **net pips per day** and **net pips per slot-day** (slot-days =
summed hold time of every layer and its resting exit). When the guard
binds, a slot freed early earns elsewhere, so per-slot is the right
measure. When it does not bind, per-day is. **Which one decides depends on
the fleet size chosen for the new account** -- the two decisions are
coupled.

### 7.2 exit_pips -- counterfactual on the real entries

Changing `exit_pips` does not change WHERE a layer entered, only when it
leaves. So keep every real entry (real time, real price, real guard
conditions) and replay only the exit, on real prices:

1. For every filled layer in the window, take the M1 path from its entry.
2. For each candidate X from 3 to 15 pips: did the path reach the exit?
   A long exits when BID >= entry + X; a short when ASK <= entry - X, so
   the spread counts against shorts. Record the fill time, or mark the
   layer to market at window end.
3. Per pair, plot net pips per day and per slot-day against X.

**Parity check first.** At each arm's ACTUAL exit_pips, the replay must
reproduce that arm's observed scalps and hold times. If it does not, the
method is wrong and nothing downstream stands. Two arms per pair give two
independent checks.

**Known bias:** entries are held fixed. A different exit closes layers
sooner or later, which changes later adds, L0 re-entries and guard
capacity. First-order only. **Choose from a flat region of the curve, not
its peak.**

### 7.3 add_pips -- cannot be done this way

Changing `add_pips` changes which entries EXIST, so there is nothing real
to hold fixed. It needs a full path replay -- the simulator -- and the
simulator has known divergences (cost model, L0 re-quote, single-sided, no
guard). **Only use it after it reproduces the live window at current
geometry**, the same parity test as 7.2. Until then add_pips changes run
only as a live A/B, which 6.1 blocks anyway.

### 7.4 Discipline (ARCHITECT s12)

- **Pre-register the split before looking:** calibrate on alternate days,
  confirm on the rest. If the holdout degrades materially, reject -- do
  not re-tune.
- **Fewer free parameters than data can bear.** Nine days per pair is
  thin; consider one exit value per pair GROUP (majors, EURGBP, the
  AUD/CAD/CHF crosses, NZD) rather than sixteen.
- **Include days after 18-Sep** as they accrue.
- **DeepSeek on the method before it runs**, with this memo and the
  script attached.

### 7.5 Inputs needed

- The deals archive (have it; the CloseBy pairing in s2 still applies).
- M1 bid AND ask for the 8 pairs across the window. The path-study M5 data
  ends 07-Sep to 11-Sep and does not cover it. A history exporter exists
  as a branch (`feature/history-exporter`) -- not checked.
- Commission per deal, from the deal records rather than assumed.

---

## 8. WHAT THIS MEANS FOR WEDNESDAY

- **exit_pips changes:** can deploy on the flat account, but 6.2 says they
  may be pointed the wrong way. Either run 7.2 first, or deploy them
  explicitly as an A/B knowing that.
- **add_pips changes:** cannot deploy as written (6.1). Keep the old
  values, or get the width ruling first.
- **EURUSD:** leave one arm at its old values so the pair has a control.

Line count: 342
