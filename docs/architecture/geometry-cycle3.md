This message has a line count at the bottom

# GEOMETRY CYCLE 3 -- NINE PAIRS, ONE ARM, TRADE-VOLUME TARGETS

Decided 2026-09-20/21 by the operator, with Gemini consulted throughout.
Supersedes the 16-instance proposal in `prompts/gemini_memo_geometry_cycle3.md`
(and cycle 2, `e1efa23`). Runs on the NEW demo account from Wednesday
2026-09-23, flat book.

**This file is the pre-registration.** The metric, target band and change
rules in s4-s5 are fixed BEFORE the first fill. Changing them after
looking is an amendment and is recorded as one in s8.

---

## 1. OBJECTIVE

**Maximise pips captured per day, evenly across pairs.** Judged on TRADE
VOLUME from fills -- scalps and pips per day, per pair -- not on price
action or simulation. Operator, 2026-09-21: "backtesting is not useful. I
want to trust and leverage actual trades."

"Even" is per PAIR, not per currency. AUD, CAD, CHF and NZD each appear in
three pairs and so see more aggregate activity than USD, EUR and GBP
(two each); that is accepted. Correct toward two-thirds per pair only if
that block runs heavy.

---

## 2. THE FLEET

Nine instances, ONE arm each (the OPT magic and slot; ALT presets stay in
the repo, unattached). Cap 8 layers per side.

- the EUR/GBP/USD triangle: GBPUSD, EURUSD, EURGBP
- the complete AUD/CAD/CHF/NZD block (every pairing of the four): AUDCAD,
  AUDCHF, AUDNZD, CADCHF, NZDCAD, NZDCHF

NZDCHF is reinstated by ADR-154.

**Why nine, not sixteen.** Modelled from the 10-18 Sep fills with each
side's depth replayed and scaled for the new add spacing: 16 instances on
the tighter geometry would peak near **251** slots against a 200 limit and
a 194 guard; nine single-arm instances peak near **144**, median ~112.

**Why one arm.** The objective is cross-sectional, volume is a high-count
measurement that moves within a day or two, and the staggered schedule in
s5 gives each pair a same-week control. The paired arm was buying that
control; the stagger buys it across nine pairs instead of eight.

**Lots: 0.01 on every instance.** Gemini ruled evenness should be measured
in dollars, which would put some pairs on 0.02. Overridden: 0.01 is the
broker minimum, so an order cannot fill in pieces, and **the EA assumes
every entry fills in full** -- it reads the filled volume only to log it
(`grind_engine.mqh:1651`) and places each exit for `InpLots`. A partial
fill at 0.02 would leave an exit sized for volume that was never filled.
Partial-fill handling is a prerequisite for any lot above 0.01 (backlog).

---

## 3. STARTING GEOMETRY

add / exit / width / stranded in pips; deadband 4 on all; cap 8.

| pair | add | exit | width | stranded | basis |
|---|---:|---:|---:|---:|---|
| GBPUSD | 10 | 10 | 5 | 10 | benchmark; exit 10 beat 7 by 39% on fills. **Held fixed all cycle** |
| EURUSD | 8 | 10 | 7 | 14 | half GBPUSD's volume at add 14 |
| EURGBP | 4 | **5** | 3 | 8 | low volume even at add 6; exit 5 beat 8 on fills (36.7 vs 30.0 pips/day) |
| AUDCAD | 7 | 10 | 5 | 10 | two-thirds of GBPUSD's volume at add 10 |
| AUDCHF | 6 | 10 | 5 | 10 | half AUDCAD's volume |
| CADCHF | 6 | 10 | 5 | 10 | half AUDCAD's volume |
| NZDCAD | 10 | 10 | 5 | 10 | already at AUDCAD's volume |
| AUDNZD | 10 | 10 | 7 | 14 | add 14 too wide for its range |
| NZDCHF | 6 | 10 | 3 | 8 | no fills yet; width 3 per ADR-146's own survival data |

Exit 10 on eight pairs follows the fills: at add 10 the crosses pooled
beat exit 5 by +11% gross / +19% net, and GBPUSD's 10 beat 7 by 39%.
EURGBP is the exception its own fills showed.

Widths are unchanged from cycle 2 except NZDCHF. Stranded is the rescue
convention (`2 x width`, floored at `width + deadband + 1` for EURGBP and
NZDCHF) -- a preset choice since ADR-153, not a rule.

These are STARTING points: gentler than the earlier cycle-3 proposal on
the CHF pairs, because the mid-week dials exist.

---

## 4. PRE-REGISTERED METRIC

**Primary:** each pair's **scalps per day, divided by the fleet median
scalps per day** over the same days. Target band **0.7 to 1.3**.

Dividing by the fleet median removes the week's common market regime --
a quiet day lowers every pair together and leaves the ratio unchanged.

**Secondary, reported, not used to trigger changes:** pips per day per
pair, and the top-to-bottom spread of pips per day (4.2x in the 10-18 Sep
window; aim below 2x).

**Source:** the deals, via the archive -- scalps are CloseBy pairs of an
ENT and an EXT on the same instance. Not the dashboard's running counters.

---

## 5. MID-CYCLE CHANGES -- THE RULES

**What may change mid-cycle:** `InpAddPips`, `InpWidthPips`,
`InpStrandedThreshPips`, `InpDeadbandPips`. None enters a reconstruction
invariant (I8 checks only that the pending add EXISTS; I7 checks depth
against the cap), so a reattach with new values reconstructs cleanly.
Invariants verified; the engine's re-pricing of a resting add after the
change is NOT yet traced -- **watch the first change closely.**

**What must NOT change mid-cycle:**
- `InpExitPips` -- I6 halts any instance whose resting exits differ from
  the new value, in any market.
- `InpMaxLayers` downward below current depth -- I7 halts.

**Groups, for the stagger:**

| group | pairs |
|---|---|
| fixed | GBPUSD -- never changed this cycle; the benchmark |
| A | EURGBP, AUDCHF, NZDCAD, NZDCHF |
| B | EURUSD, AUDCAD, CADCHF, AUDNZD |

**Schedule:**

1. Wednesday to Thursday close: no changes. Two full days of fills.
2. Friday before the London open: evaluate ALL pairs on Wed-Thu.
   **Group A** pairs outside the band change; group B does not.
3. The following Tuesday before the London open: evaluate on Fri-Mon.
   **Group B** pairs outside the band change; group A is the control.

**The change rule, per pair outside the band:**
- ratio below 0.7: tighten add by ONE step
- ratio above 1.3: widen add by ONE step
- one step = 2 pips on pairs with add >= 8, 1 pip below that
- never past the `0.5 <= add/width <= 4` guard; never below add 3
- width, stranded and deadband move only if the add change forces it

**One change per pair per evaluation.** No chasing within a window.

---

## 6. WHAT WOULD STOP THE CYCLE

- Guard at or above 194 for more than two hours running on two days.
- Any halt that is not understood within the day.
- A pair capped on one side for more than 48 hours with no exit fill.
- API counter over 1,800 before 18:00 broker on any day.

A stop means: no further changes until the cause is written down.

---

## 7. NOT IN SCOPE THIS CYCLE

- Exit distance tests (no second arm).
- Lots above 0.01 (partial fills).
- Carry (off).
- Passive ejection (not built).
- Live two-sided L0 quoting (`stranded ~ width`): possible since
  ADR-153, deferred to a later cycle so this one changes one thing at a
  time.

---

## 8. AMENDMENTS

**A1 (2026-09-22).** s5 says a reattach with new add/width "reconstructs
cleanly". Under F1 that became true only with ADR-156 (merged `3f72b9f`):
a required exit missing at the reattach is now placed, not a permanent
halt. Remaining caveat: do not reattach near rollover or session edges
(backlog C18). The geometry rules are unchanged.

**A2 (2026-09-23) -- STRUCTURE ADDED BEFORE THE FIRST FILL.** Operator
decision 2026-09-22: cycle 3 tests STRUCTURAL changes, not only geometry.
Written before any cycle-3 fill; it amends, it does not rewrite s1-s7.

1. **Code at the start:** `main` at `8df6ffa` or a later tested build --
   F1 barbell, ADR-156 (startup), ADR-155 + ADR-157 (ejection, manual and
   automatic), C25 (carry unblocked, state flushed), ADR-158 (daily-loss
   breaker).
2. **Configuration, all nine presets:** `InpEnableCarryPass=true`;
   `InpEnableCommandedEject=true`; `InpAutoEject=true` with
   `InpAutoEjectStableMinutes=5` and `InpAutoEjectSpreadMult=1.5`;
   `InpBreakerEnable=true`. Geometry (s3) unchanged.
3. **s7 superseded in part:** "Carry (off)" and "Passive ejection (not
   built)" no longer apply -- both are IN scope. The rest of s7 stands.
4. **Primary metric unchanged** (s4). **An ejected exit's fill is NOT a
   scalp**: it is an ENT/EXT close, so s4's source would count it. Scalp
   counts exclude any close whose layer carried a `GRIND_EJECT_OFFSET_`
   (the EA emits `EJECT_FILLED` for these). Ejections are counted
   separately.
5. **Secondary, reported, never triggers** -- per FTMO day (00:00 CE(S)T):
   - equity change, realised (balance change), inventory P&L (change in
     equity - balance), swap charged;
   - ejections per pair: count, realised USD, `auto` vs `command`;
   - carry-pass clamps per pass (backlog C26);
   - breaker trips and pre-midnight halts;
   - everything in USD beside pips (C22) -- with **no USD target**.
6. **Mid-cycle dials:** `W` and `k` may change mid-cycle by reattach
   (exit and cap stay frozen, s5); each change is recorded here with its
   time. The carry and ejection switches are the structure under test:
   turning either OFF mid-cycle is a STOP (s6), not a dial.
7. **Stop conditions added to s6:** any halt involving an ejected layer or
   a carry-shifted exit (I3/I6); any API retry storm (counter rising
   without order changes). A breaker trip is RECORDED, not a stop -- it is
   the breaker working.
8. **Before the first fill** (readiness gate, `docs/runbooks/cycle3-start.md`):
   C24 daily snapshot and C19 CRITICAL events in pipshed (ADR-159, which
   also implements the scalp exclusion in point 4); A5 account identity;
   `TimeGMT()` on the VPS checked against real UTC (ADR-158 computes the
   FTMO day from it).

**A3 (2026-09-23) -- ELEVEN INSTANCES AND THE FLOATING-LOSS GATE, BEFORE
THE FIRST FILL.** Written after cycle 2 ended on FTMO's daily limit
(`docs/FULL_TRIAL_RECORD_1514582088.md`) and before any cycle-3 fill; it
amends, it does not rewrite s1-s7 or A1-A2.

1. **Code at the start:** `main` at `c22e9ff` or a later tested build. It
   adds ADR-159 (daily snapshot, CRITICAL banner, ejections archived, the
   breaker latch read every tick, NZDCHF in the fleet table) and ADR-160
   (the all-day floating-loss entry gate).
2. **Fleet: eleven instances** (operator decision, backlog C30; pairs
   chosen by Claude). The nine of s2, plus DUPLICATES of **AUDNZD** and
   **NZDCAD**: the same geometry as their OPT instance, on the pair's ALT
   magic and instance id (`22260902` / `GRIND_AUDNZD_ALT`, `22260802` /
   `GRIND_NZDCAD_ALT`), presets `audnzd_dup.set` and `nzdcad_dup.set`.
   **Why:** equal 0.01 lots give unequal dollars per pip; measured from
   cycle-2 closes, AUDNZD is $0.057 and NZDCAD $0.071 per pip against
   $0.100 for the USD pairs, so doubling them raises the book's dollar
   weight where it is cheapest. NZDCAD rather than AUDCAD because AUD was
   cycle 2's second-largest exposure (25 layers net long); in the two
   duplicates NZD sits on opposite sides and partly offsets. 0.02 lots
   stay out (s2: partial fills).
3. **s4 unchanged.** Each pair is measured on its OPT instance; the fleet
   median is over the nine OPT instances. The duplicates are reported and
   are NOT in the median (`scripts/s4_scalps.py` in pipshed already takes
   the median over `_OPT` instances only).
4. **The floating-loss gate (ADR-160 R4) is in scope:** no new entries
   while floating loss is at least 50% of the daily allowance, clearing at
   40%; exits, carry and ejection unaffected. It is ACCOUNT-WIDE, so every
   pair is gated together and the fleet median cancels it; s4 is read as
   before. Gated time is reported per FTMO day (`gated_seconds` in the
   daily snapshot). A gate episode is RECORDED, not a stop -- like a
   breaker trip (A2 point 7).
5. **Slot budget, not re-modelled:** s2's model put nine instances near a
   144-slot peak; two more cheap-pair instances scale that to roughly the
   mid-170s against the 194 guard. Watch `guard_total` in the daily row.
6. **Configuration** of all eleven presets as A2 point 2, with
   `InpBreakerEnable=true` written explicitly in every file (backlog C35).

**A4 (2026-09-24, before the first s5 evaluation) -- CYCLE 3 FROZEN.**
Operator: mid-cycle geometry tweaks are made only on the Linux fleet.
1. Cycle 3's geometry and configuration are frozen for the whole cycle;
   the s5 dial schedule no longer applies to cycle 3. Defect fixes only.
2. The s5 rule (band 0.7-1.3, one step, groups A/B, GBPUSD fixed) is
   applied to **Fleet B** instead (`fleet-b.md` s2): group A evaluated
   before the London open on Mon 28 Sep on FTMO days 24 (partial) and 25
   Sep, group B the following Wednesday. Cycle 3 is the untouched control.
3. Why: one clean baseline for the whole cycle, no restarts on the FTMO
   account, and the first mid-cycle add change (s5: re-pricing of the
   resting add not yet traced) tried where nobody liquidates.
4. s4 is still computed and reported for cycle 3.

Line count: 270
