This message has a line count at the bottom

# ADR-160 -- CARRIED OPEN MTM AGAINST THE FTMO DAILY LIMIT (C28)

**Status:** DRAFT rev 0, 2026-09-23, for Gemini. Gates cycle 3. Operator
stance: demo mode -- ship a clear rule, learn from the demo, adjust; no
arbitrary barriers (fixed pip depths, long waits).

**Gemini:** your questions are in section 6 (G1-G5). Every number below
comes from the cycle-2 deal dump (4,317 deals; it reconciles to FTMO
MetriX to the cent) and the EA's own `GRIND_MAE_*` day records; section 7
gives the method. Reason from these numbers and the cited code.

---

## 1. THE PROBLEM

FTMO's daily limit is measured from the BALANCE at the FTMO day start, and
equity includes open MTM (ADR-158 s1). The strategy carries offside
inventory and waits for the range to return. So yesterday's open losses
are charged to today's $500 from the first second.

Cycle 2 ended on this. On 23 Sep the day opened with about -$330 of open
MTM, so two-thirds of the budget was spent before a single trade; FTMO
liquidated at 13:51Z at -$505.34. On 17 Sep the EA recorded an equity
low of -$421 against the day's anchor (84% of the limit).

## 2. CYCLE 2, DAY BY DAY (FTMO days, 22:00Z start)

| day | open MTM at start | worst open MTM | hours at or below -$250 | EA-recorded day low vs anchor |
|---|---:|---:|---:|---:|
| 14 Sep | -34 | -112 | 0.0 | -79 |
| 15 Sep | -98 | -126 | 0.0 | -126 |
| 16 Sep | -107 | -371 | 3.5 (from 18:31Z) | -293 |
| 17 Sep | -371 | -412 | 5.5 (from the open) | -421 |
| 18 Sep | -189 | -259 | 0.8 | -231 |
| 21 Sep | -187 | -240 | 0.0 | -254 |
| 22 Sep | -221 | -370 | 15.0 (from 03:02Z) | -281 |
| 23 Sep | -330 | -504 | 24.0 (from the open) | -505 (breach) |

From 17 Sep on, the book never opened a day with less than about $187 of
its $500 already spent.

## 3. WHAT EXISTS TODAY (ADR-158, merged)

- **Breaker:** trips at 80% (-$400 against the anchor), blocks new entries
  and cancels resting entries for the rest of the FTMO day. Every instance
  now adopts a peer's trip on its next tick (ADR-158 rev 2).
- **Pre-midnight halt:** from 23:00 Prague, while floating loss (balance
  minus equity) >= 50% of the allowance ($250), no new entries
  (`Grind_BreakerPreMidnightHalt`, not latched).
- Exits, the carry pass and ejection are never blocked by either.

On 23 Sep the breaker at 80% would have tripped at about 09:17Z; blocking
entries from then saves only about $19 (day about -$486, $14 inside the
limit at the moment FTMO acted). **The breaker helps a day that goes bad;
it cannot rescue a day that STARTS bad.**

## 4. CANDIDATES

- **R0 -- no new rule.** Rely on cycle 3's single arm (OPT and ALT held
  near-identical stacks, so every move was paid twice; one arm roughly
  halves carried MTM) and on ADR-159's daily `carried` column to watch it.
- **R1 -- lower the breaker trip from 80% to 60%.** One constant. In cycle
  2 it trips at the open on 17 and 23 Sep, and on no other day.
- **R2 -- an opening gate:** at the FTMO roll, if carried MTM is at or
  beyond a set share of the allowance, block new entries for that whole
  day. Acts on the same two days as R1, at the open only.
- **R3 -- pre-midnight trimming** (ADR-158 s4, deferred): close carried
  losers before midnight to restore tomorrow's headroom. Crosses the spread
  and abandons the recovery the strategy is built on. Listed for
  completeness; not proposed.
- **R4 -- the pre-midnight halt, all day.** No new entries while floating
  loss >= 50% of the allowance, at any hour, not latched. It is
  `Grind_BreakerPreMidnightHalt` with the 23:00 condition removed: the
  same code, the same threshold ADR-158 already chose, and the same
  gate (`Grind_EntriesBlocked`).

## 5. THE COUNTERFACTUAL THAT DECIDES IT (R4)

Across cycle 2, R4 would have blocked **315 entries** (14-23 Sep, each
checked against open MTM one second before it was placed; on 10-11 Sep
open MTM never came near the line):
- those entries later produced **+$123.73** from scalps,
- and **-$214.33** when FTMO liquidated the ones still open,
- net **-$102.33**. So blocking them leaves the cycle about **$102 better
  off**.
- On 23 Sep every entry fell inside the gate (floating loss was at or
  beyond $250 all day), which is the no-entries case: the day ends at
  about **-$425, $75 inside the limit**. Less stacking on 22 Sep would
  also have lowered 23 Sep's opening MTM (not modelled).

R1 and R2 act only on 17 and 23 Sep, and only once the budget is mostly
spent. R4 acts on the CAUSE, which is the stack growing while inventory is
already deep, and it acts on the days that fed the breach (16 and 22 Sep)
as well.

**Claude's recommendation: R4.** It is a clear rule tied to FTMO's own
number, not a pip depth. It reuses tested code, blocks entries only
(exits and carry keep working, so the stack can still unwind), and it
clears by itself when price recovers.

## 6. QUESTIONS FOR GEMINI

- **G1.** Is a rule needed for cycle 3 at all, given that the single arm
  roughly halves carried MTM (R0)? The operator's stance favours learning
  from the demo, but cycle 2 shows the limit binds on carried losses, not
  on the day's trading.
- **G2.** R4 versus R1 or R2: agree that R4 addresses the cause while R1
  and R2 address the symptom? Any failure mode of R4 we have missed (for
  example the gate flickering on and off near $250 and churning entry
  orders; see G3)?
- **G3.** Hysteresis: should R4 clear at the same 50% line, or lower
  (say 40%), so entries do not repeatedly place and cancel around the
  threshold? Every place and cancel counts against the API budget.
- **G4.** Threshold: keep ADR-158's 50% (the pre-midnight halt's number),
  or tune it? In cycle 2, 50% gated about 49 hours, on 5 of the 8 days in
  section 2.
- **G5.** The pre-registration: a gate that blocks entries lowers scalps
  on gated days, which feeds the s4 metric (scalps per day relative to the
  fleet median). Should gated hours be reported per day (ADR-159's row
  already flags `breaker_tripped` and `premidnight_seen`) and the metric
  be read with them, via amendment A3?

## 7. METHOD AND CAVEATS

- Open MTM is marked at the last deal price on each pair, converted to USD
  with factors measured from 23 Sep's closing deals. It lags fast moves;
  the EA's `GRIND_MAE_*` day lows agree within a few dollars on most days
  (for example -289 vs -293 on 16 Sep, -287 vs -281 on 22 Sep).
- The counterfactual is first-order. It removes the blocked entries and
  their CloseBy partners, and does not model how the book would have
  evolved without them (fewer slots used, different later fills).
- "Hours at or below -$250" counts time between successive deals, so it
  is approximate.
- Sources: `docs/FULL_TRIAL_RECORD_1514582088.md`; the deal dump
  `data/local/deals_dump_20260923_1741.csv` (not committed).

Line count: 139
