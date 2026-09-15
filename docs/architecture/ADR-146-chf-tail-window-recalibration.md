# ADR-146: CHF Tail-Window Re-Calibration and the Width-Drawdown Relationship

## Status

Accepted -- 2026-09-14.

Supersedes the geometry cleared in ADR-144 for NZDCHF (width 7 / exit 5 and
width 7 / exit 7). Those presets remain in the repo and on the VPS; they are
NOT to be attached to a chart.

The Staff Architect ruled twice on 2026-09-14. The first memorandum (R1-R5)
cleared the NZDCHF 7/5 pilot on the premise that a 2015-style CHF shock is
uninsurable and therefore geometry-agnostic. Evidence obtained after that
memorandum refuted the premise, and the ruling was reversed. Both are
recorded: the superseded ruling in section 3, the reversal in section 4.

## Context

`nzdchf_holdout_2026_09_14` (27 cells, n=50, substeps=100) returned a clean
result on `holdout_stress_2020q1` and `holdout_chop_2026q2` -- 0% Gate A and
Gate B breach on every cell -- and disqualified ALL NINE cells on
`holdout_tail_2015q1`, the SNB EUR/CHF floor removal of 15 January 2015.

The locked geometry (width 7 / exit 5) breaches Gate A on 90% of seeds,
with mean daily equity drawdown 1104.7 against a 500 limit.

The pre-registered split lives in `WINDOW_ROLES` in
`scripts/run_width_exit_sweep.py` and was fixed before the run. Geometry was
locked before the holdout ran. Nothing has been reselected.

`holdout_tail_2015q1` carries the `WINDOW_META` label
"STRESS tail survival-only". It was designed to be survived, not scored.

## 3. SUPERSEDED RULING (first memorandum, 2026-09-14)

**R1. A survival-only tail-window breach is NOT blocking for a new pair.**
The SNB floor removal is an exogenous structural break; a touch-fill
Brownian-bridge simulator failing it at retail leverage is mechanically
accurate, not a simulator defect. ADR-125's 0% breach requirement applies to
ordinary and stress regimes. NZDCHF 7/5 passed both non-tail holdout windows
with 0% breach and is structurally sound. The pilot is cleared.

**R2. No action on live AUDCHF and CADCHF.** Accept and document. Do not
alter `max_layers`, lot size or live execution state.

**R3. The gate is not retrospective.** Ratification stands. Tail knowledge
informs position sizing and ring allocation; it does not withdraw live
instances.

**R4. No EURUSD 2015Q1 slice required.** The SNB event was a CHF-specific
dislocation. 2015Q1 slices do not exist for EURUSD, GBPUSD or EURGBP
(`--dry-run` reports all three MISSING).

**R5. Width 3 must NOT be selected.** Choosing it now because the holdout
favours it is overfitting to the holdout set. ARCHITECT.md s12 stands.
Width 7 holds.

## 4. RULING AS REVERSED -- THIS IS THE DECISION

**Tail survival is geometry-dependent, so failing a tail window without
having calibrated against one is grounds for RE-CALIBRATION, not
acceptance.** Section 5.2 refutes the "uninsurable" premise: width 3
survives on 60-74% of seeds where width 7 survives on 8-10%. A 100-sigma
force majeure would not vary by a factor of seven across cells of the same
grid.

**D1. The 7/5 and 7/7 NZDCHF pilot geometries are REJECTED.** Deploying the
most tail-exposed instance in the fleet (s5.4) into a book already
concentrated short CHF is not risk acceptance.

**D2. NZDCHF calibration is re-run with a CHF-shock window inside the
CALIBRATION set.** The optimiser must balance chop harvest against tail
survival. Whatever wins that penalised calibration goes to a fresh holdout.
ARCHITECT.md s12 is honoured: the holdout still evaluates and does not
select.

**D3. R2, R3 and R4 stand.** No action on live AUDCHF and CADCHF; the gate
is not retrospective; no EURUSD 2015Q1 slice. Note s5.3 on the last of
these: R4 is correct that the EVENT was CHF-specific, but the WIDTH effect
is not, and EURUSD runs width 7 live and untested.

**D4. R5 stands.** Width 3 must not be selected off holdout evidence. D2 is
the only legitimate route to a different geometry, because there the tail
window informs selection openly.

**D5. NEW PRECONDITION.** Before any newly calibrated NZDCHF goes live,
`InpCapLegBThresh` for CHF must be armed. That requires its own ADR and the
failing ALLOW test required by ARCHITECT.md s11 (see s7).

**D6. The wide-exit anomaly is accepted as an empirical property** of this
grid family pending explanation. The re-calibration explores exits 2/5/7/10
rather than 2/5/7, so the data can speak to it.

## Consequences

CHF crosses carry elevated gap risk against abrupt central bank action and
disorderly haven bids. That risk is accepted for the live AUD/CAD/CHF ring
(s5.1) and is to be priced into geometry selection for any new CHF pair
rather than discovered after deployment.

## 5. EVIDENCE OBTAINED AFTER THE RULING

### 5.1 The live CHF ring breaches the same window

`ring_tail_gate_2026_09_14`, AUDCHF and CADCHF, n=50, substeps=100, same
settings as the ADR-125 decision-12 confirmation sweep.

| instance | geometry | Gate A | Gate B | mean ddA | mean ddB |
|---|---|---|---|---|---|
| AUDCHF OPT | 5/5 | 62% | 62% | 818.0 | 1295.8 |
| AUDCHF ALT | 5/10 | 46% | 50% | 536.4 | 1140.9 |
| CADCHF OPT | 5/5 | 82% | 82% | 830.5 | 1287.5 |
| CADCHF ALT | 5/10 | 60% | 60% | 525.6 | 1018.7 |

All four live cells are gate-disqualified. This confirms R2's conditional
and materially strengthens R1: ruling the window blocking would require
withdrawing four live instances, not merely declining a seventh pair.

### 5.2 One premise of R1 is not supported by the data

The memorandum states: "you cannot survive a 30% gap with an 8-layer grid."

On the NZDCHF grid, survival varies by a factor of seven across cells of the
same grid, same window, same seeds, same cost model:

| width | Gate A breach | implied survival |
|---|---|---|
| 3 | 26-40% | 60-74% |
| 5 | 82-86% | 14-18% |
| 7 | 90-92% | 8-10% |

The majority of seeds survive at width 3. The event is therefore survivable
and geometry-dependent, not uninsurable.

**This does not overturn R1.** Accepting a 90% breach rate on a
once-in-eleven-years event is a legitimate risk-appetite decision and is the
Staff Architect's to make. But the ADR should record the decision actually
being taken -- that the width-7 corner is chosen for harvest with the
trade-off understood -- rather than that the breach carries no information.
The distinction matters for precedent: a future pair failing a tail window
must not be able to cite "uninsurable" without checking whether its own grid
had a surviving corner.

### 5.3 Width is the dominant risk axis, across three pairs

| pair | width 5 Gate A | width 7 Gate A |
|---|---|---|
| NZDCHF | 82-86% | 90-92% |
| AUDCHF | 46-62% | 92-94% |
| CADCHF | 60-82% | 74-92% |

Same direction, same magnitude, three pairs. The effect is a property of the
geometry family, not of NZDCHF.

A second effect: **wider exit is safer AND more productive.** AUDCHF 5/5
breaches at 62% with realised 9340.8; 5/10 breaches at 46% with realised
13056.2. CADCHF 5/5 at 82% and 8934.4; 5/10 at 60% and 12675.4. Better on
both axes, on both pairs. This was not predicted and is not explained.

**The mechanism is unknown.** Two theories have been proposed and refuted.
(a) Ladder span (Claude): wider add spacing gives less summed adverse
excursion, 3608 pip-lots at add 14 vs 3720 at add 10. Predicts the wrong
sign; the error has not been located; the argument is withdrawn, including
the `max_layers=8` conclusion that rested on it. (b) Turnover (previous
chat): narrow recycles through post-gap oscillation while wide fills once
and sits. Contradicted -- `mean_exits` does not collapse at width 7, every
cell saturates the cap, and `mean_l0_hold_min` is shorter at width 7.

R4 concludes no EURUSD slice is needed because the event was CHF-specific.
That is correct about the event. It is not evidence about width, and
**EURUSD runs width 7 live on both arms**. Untested is not the same as safe.

### 5.4 The proposed pilot would be the most tail-exposed instance in the fleet

| instance | Gate A breach |
|---|---|
| AUDCHF ALT 5/10 | 46% |
| CADCHF ALT 5/10 | 60% |
| AUDCHF OPT 5/5 | 62% |
| CADCHF OPT 5/5 | 82% |
| **NZDCHF OPT 7/5 (proposed)** | **90%** |
| **NZDCHF ALT 7/7 (proposed)** | **92%** |

NZDCHF at the locked geometry is not equivalent to the existing ring. It is
worse than all four live cells.

R5 forbids moving to width 3 on holdout evidence, and this ADR does not
propose it. The fact is recorded because R1 cleared 7/5 on the premise that
the tail window is uninformative, and the window is informative enough to
rank instances -- with the proposed one ranking last.

## 6. RESOLVED: QUESTION PUT BACK TO THE STAFF ARCHITECT

Does "accept and document" extend to deliberately adding the most
tail-exposed instance in the fleet, when the calibration that selected its
geometry contained no CHF dislocation (`q1_2024_chop`, `truss_crisis`,
`calib_chop_2020q3`, `calib_stress_2022q1` -- Truss is GBP, 2022Q1 is
commodity/Ukraine)?

Answered: **Option 3.** Recorded below as put, with the ruling appended.

1. **Proceed at 7/5 as ruled.** Record s5.4 as an accepted, quantified
   exposure. Consistent with R1, R2 and R5.
2. **Reject NZDCHF and add a non-CHF pair instead.** AUDNZD is under
   calibration re-run (`audnzd_calib_2026_09_14`); its prior calibration
   predates the carry model and has no `mean_carry_usd` field. This avoids
   a third CHF cross without any reselection.
3. **Re-run NZDCHF calibration with a CHF-shock window in the CALIBRATION
   set**, and let a fresh holdout evaluate whatever that selects. This is
   the only legitimate route to a different geometry; it is not reselection
   because the tail window would be informing selection openly rather than
   being read off the holdout. **<- RULED. See D2.**

### 6.1 What Option 3 costs, and why it is not a free win

The dataset begins 2015-01-02 09:00 (`scripts/slice_ring_windows.py`) and
the de-peg was 2015-01-15. There is no earlier CHF shock in the data because
there is no earlier data. The same bars therefore cannot both select and
evaluate.

Implementation: a second window key `calib_tail_2015q1` with calibration
role, mapped through `_LEGACY_WINDOW_FILE_SUFFIX` to the existing
`*_holdout_tail_2015q1.csv` slice. No CSV is re-cut. `holdout_tail_2015q1`
is unchanged and retains its holdout role.

**Operator discipline, not enforced in code: the two keys must never appear
in the same sweep.** A run that selects on `calib_tail_2015q1` must exclude
`holdout_tail_2015q1` from its holdout set, or the same bars sit on both
sides. This is deliberately not guarded in code because a guard would
silently change the behaviour of existing runs.

**The consequence must not be glossed:** for NZDCHF, tail survival becomes a
SELECTION CONSTRAINT and stops being an EVALUATED PROPERTY. The re-calibrated
geometry will be tail-aware by construction, and the fresh holdout will test
generalisation on chop and stress only. We will not have an out-of-sample
tail test for this pair. The standing remedy is to source pre-2015 data and
cut the September 2011 SNB floor introduction as an independent CHF shock;
that is a substantially larger piece of work and is not undertaken here.

### 6.2 Recorded objection: the two-step argument

The operator raised, and it is recorded rather than dismissed: the specific
2015 mechanism requires the SNB to reinstate a floor AND then abandon it --
two unlikely steps -- so treating it as a live risk may be fighting the last
war.

The window is retained for three reasons. A CHF gap does not require a peg:
an abrupt SNB intervention or a disorderly haven bid in a European crisis
reaches the same place. The decision is asymmetric -- including the window
costs some chop harvest, excluding it produced a locked geometry at 90% Gate
A. And relevance was being reassessed only after the window returned an
unwelcome result, which is how a holdout protocol stops meaning anything.

Also recorded: because our data starts thirteen days before the de-peg, we
have almost no observations of the floor regime ITSELF. If a floor or band
were ever reinstated, CHF crosses would enter a pinned, arbitraged, thin-
harvest regime that the simulator has never seen. Every CHF number this
project holds is post-float.

### 6.3 Recorded: CHF crosses are the best harvesters measured

Lest the risk framing above distort the record -- AUDCHF ranked FIRST and
NZDCHF SECOND of ten pairs on the carry-corrected calibration sweep
(NZDCHF 2687.9). On the tail window itself AUDCHF 5/10 returned the highest
realised figure in that table (13056.2). The shape is high harvest WITH high
tail risk -- compensated risk to be sized deliberately -- not a pair that
earns nothing and then breaks.

## 7. PRECONDITION (D5): CHF CONCENTRATION AND THE INERT CAP

NZDCHF would make CHF three of seven pairs -- six of fourteen instances,
all short the franc in the same direction. The per-pair tail numbers above
do not model three correlated pairs breaching simultaneously, so the
aggregate exposure exceeds any single cell.

R3 names the correct mitigation: "informs position sizing and ring
allocation (e.g., capping total CHF exposure)". **That cap exists and is
switched off.** `GRIND_CAP_ALL_MAGICS` correctly enumerates all twelve live
magics following ADR-143, but every preset carries
`InpCapLegAThresh=0.0` and `InpCapLegBThresh=0.0`, so
`Grind_CapThresholdEnabled()` returns false and `Grind_CapAllowsEntry`
returns true before the array is read.

Arming a CHF leg-B threshold requires its own ADR and a failing ALLOW test
per ARCHITECT.md s11. Per D5 it IS now a precondition: no re-calibrated
NZDCHF goes live until it is armed.

## 8. PROCESS NOTE

`HANDOFF_2026-09-13` carried the open item: "Score HOLDOUT windows for
NZDCHF before adding to fleet (calibration-only numbers insufficient per
ARCHITECT)." That instruction was followed and returned an unwelcome answer.
It also surfaced, as a side effect, that the AUD/CAD/CHF ring went live on
calibration-only numbers and had never been tail-scored.

The protocol worked. Record that, not only the result.
