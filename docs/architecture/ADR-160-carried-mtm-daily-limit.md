This message has a line count at the bottom

# ADR-160 -- CARRIED OPEN MTM AGAINST THE FTMO DAILY LIMIT (C28)

**Status:** ACCEPTED rev 1, 2026-09-23 (Gemini ruled G1-G5; R4 with
hysteresis; rulings and our verification in section 8; design in section
9). History: rev 0 `6e360ba`. Gates cycle 3. Operator
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

---

## 8. RULINGS (Gemini, 2026-09-23) AND OUR VERIFICATION

Gemini's reply carried no line-count footer. Verdicts adopted; where a
stated reason does not match this codebase, it is recorded so the rule is
not later defended on the wrong grounds.

- **G1: a rule is required** (R0 alone is not enough). Adopted. His reason
  holds: halving size shrinks the stacks but a persistent trend still
  builds past $250 on one arm.
- **G2: R4.** Adopted. R1 acts late and R2 only at the open; the limit is
  continuous.
- **G3: hysteresis, engage at 50%, clear at 40%.** Adopted. **His reason
  is overstated:** he assumes the gate cancels resting entries each time it
  engages, so flicker would churn place and cancel. In source it does not:
  all five entry sites only `return` when `Grind_EntriesBlocked()` is true
  (`grind_engine.mqh` ~1014, ~1240, ~1449, ~1553, ~1664); nothing
  cancels. Flicker could only cause one extra placement per side per
  clear. Hysteresis stays because it is free and makes the state read
  cleanly. His "600 calls a minute" figure does not appear anywhere in
  this project (the EA's own figure is a 1,800-a-day soft warning);
  treated as unverified.
- **G4: 50% / 40%.** Adopted. His point (a) is right and matters: resting
  entries are NOT cancelled, so each side can still gain at most the one
  layer already resting; the buffer absorbs it.
- **G5: report gated time.** Adopted as reporting. **His metric concern
  does not apply as stated:** the gate is ACCOUNT-WIDE (every instance
  evaluates the same account balance and equity), so all pairs are gated
  together, and s4 divides each pair's scalps by the FLEET MEDIAN on the
  same day, which cancels a common cause (that is what the median is
  for). No `scalps_per_ungated_hour` is needed. Gated seconds are still
  reported per day as context for s4 and the USD measures, through
  amendment A3.

## 9. DESIGN (R4 + hysteresis + reporting)

**D1 -- the gate.** Pure: `bool Grind_BreakerFloatGate(const bool
was_gated, const double floating, const double allowance)`: false if
`allowance <= 0`; if not gated, engage when `floating >= 0.5 x allowance`;
if gated, stay gated while `floating > 0.4 x allowance`.
`floating = balance - equity`. New global `g_grind_breaker_gated`,
updated every tick in `Grind_BreakerOnTick` beside the pre-midnight
line; reset at an FTMO day-key change is NOT required (the gate is not a
daily latch), but it is recomputed from scratch on the first tick after a
start.

**D2 -- the block.** `Grind_BreakerBlocksEntries()` becomes `enabled &&
(tripped || premidnight || gated)`. Entries only; exits, carry and
ejection unaffected; nothing is cancelled (as today's pre-midnight halt).
The pre-midnight halt stays as written: it is now redundant (the gate
engages whenever it would), but removing it would change ADR-158's tested
code and the D4 marker for no gain.

**D3 -- transitions archived once per account.** The instance holding the
MAE reporter lease (`g_grind_mae_is_reporter`) emits `INFO
BREAKER_GATE_ON` / `BREAKER_GATE_OFF` (detail: floating, allowance, day)
when its own gate flips. Other instances flip silently.

**D4 -- gated seconds.** In `OnTimer`'s telemetry-interval block, beside
`Grind_MaeOnTimer()`, the lease holder adds the elapsed interval (seconds
since its last addition, capped at twice `TelemetryIntervalSec`) to
persistent GV `GRIND_SNAPSHOT_GATED_S_<ftmo day key>` while
`g_grind_breaker_gated` is true. Not every second: that would flush the GV
file to disk every second for hours. Resolution is one telemetry interval,
enough for an hours figure. Dirty-flushed; the clean-up prefix
`GRIND_SNAPSHOT_` covers it. The lease can move; the count continues
because the GV is shared.

**D5 -- the snapshot.** `DAILY_SNAPSHOT` gains `"gated_seconds":<n>` from
`GRIND_SNAPSHOT_GATED_S_<ended day>` (0 if absent), after `history_ok`.
Pipshed: a nullable `gated_seconds` column (migration 003), a "Gated"
column on the daily card (hours, one decimal), and `s4_scalps.py` prints
gated hours per day beside the counts.

**D6 -- pre-registration.** Amendment A3 to `geometry-cycle3.md`: R4 is in
scope; s4 is read as before (the fleet median cancels an account-wide
gate); gated hours are reported per day.

**Tests (EA), tests first against stubs:** the pure gate (engage at
exactly 250 on a 500 allowance, not at 249.99; stay at 200.01; clear at
200.00; no allowance never gates); `Grind_BreakerBlocksEntries` with each
flag; the D4 accumulator on a test day key (increments only when gated
and when the reporter; GV cleaned up); the snapshot JSON carries
`gated_seconds`.

**Negative space:** no change to the breaker's 80% trip, its latch, D9
adoption, or the pre-midnight halt; no cancellation of resting entries;
no new inputs (the thresholds are constants, like ADR-158's).

---

## 10. IMPLEMENTATION RECORD (2026-09-23/24)

**Status: EA IMPLEMENTED** (merge `c22e9ff`, tested at `6c57830`: suite
1766/1766 on GBPUSD and EURUSD; EA compile 0/0 on desktop and VPS). Live
from cycle 3's start (~01:00Z 24 Sep, build `a01a5d4`). Pipshed D5 is
backlog C36 (the data is already stored in each snapshot's `detail`).

Spec `prompts/cursor_adr160_ea.md` (`46d9d96`, Gemini Q1 accepted). The
stub commit was behaviour-neutral and failed exactly the 16 predicted
assertions (1750/1766); the real branch passed 1766/1766. No fix-ups.

**DeepSeek R1 audit** (`prompts/deepseek_adr160_audit_response.md`),
verified in source:
- T-1 HOLDS (confirmed): both eject paths take `g_grind_halted ||
  g_grind_quarantined` as their block (`fxgrind.mq5:312-315`); the exit
  queue, carry and CloseBy code never consult the gate. The unwind stays
  open.
- T-2 HOLDS: at most one resting entry per side, so a side gains at most
  one layer while gated.
- T-3 REJECTED (stuck-ON gate after a no-basis day): the gate needs an
  allowance > 0, which needs the initial deposit known;
  `g_grind_breaker_initial_known` is set once (`grind_engine.mqh:888`) and
  never cleared in a session, so a no-basis day cannot follow a gated day;
  a restart starts the gate false. Even if it occurred, it blocks one tick.
- T-4, T-7 HOLD.
- T-5 / T-6 (gated-seconds and transition accuracy) ACCEPTED AS BOUNDED
  REPORTING ERROR: a reporter with the breaker off is excluded by C35's
  presets; a quiet reporter lags by its inter-tick gap (minutes); a lease
  handover may double-count one interval; transitions may duplicate or be
  missed on a lease change or restart. None affects whether entries are
  blocked; s4 does not depend on gated time (section 8, G5).

Line count: 265
