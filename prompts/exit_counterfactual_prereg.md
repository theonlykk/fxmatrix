This message has a line count at the bottom

# EXIT_PIPS COUNTERFACTUAL -- PRE-REGISTRATION

Written 2026-09-20, BEFORE any counterfactual result exists. The replay is
run only after this file is committed and reviewed (DeepSeek, then Gemini).
Any rule changed after results are seen is recorded in s11 as an amendment,
with the reason. Method source:
`docs/architecture/geometry-cycle2-derivation.md` s7.2, approved by Gemini
2026-09-20.

---

## 1. THE QUESTION

For each pair, how do net pips depend on `exit_pips`, holding every real
entry fixed?

Not asked here: `add_pips` (changing it changes which entries exist; see
the derivation memo s7.3), width, or cap.

## 2. DATA, FROZEN

| input | identity | checked |
|---|---|---|
| Deals | `deals_dump_20260918_2354.csv`, sha256 prefix `a061f28a7d959ad7`, 2,716 deals | 612 scalps per arm reproduce the memo table exactly; 105 open = live book |
| Prices | `m1_bidask/*_m1_bidask.csv` from `scripts/export_m1_bidask.mq5` at `02191e0` | 0 violations, two identical export passes |
| Window | entries 2026-09-10 to 2026-09-18, broker time (UTC+3); path to 2026-09-18 23:54 | seven trading days |

## 3. UNIT: THE LAYER

A layer is one `IN` deal whose comment matches `GRIND|<slot>|<side>|L<nn>|ENT`.
793 layers. Pair from `symbol`, arm from `slot`, side from `side`, entry
time and price from the deal. Lot 0.01 on every layer.

Observed outcome, used for parity only: `scalp` (612, netted by CloseBy
against an `EXT` position), `manual` (76, closed by an `OUT` deal with
reason 0), `open` (105).

## 4. THE FILL RULE

For candidate X (pips), the exit target is `entry + X` for a long and
`entry - X` for a short.

Every exit is a resting limit order and fills passively at its own price.
Nothing in the replay crosses the spread.

- **Long** (exit = sell limit) fills in the first M1 minute where
  `bid_high >= target`.
- **Short** (exit = buy limit) fills in the first M1 minute where
  `ask_low <= target`. A buy limit can only be matched by the ask; testing
  it against the bid would count fills that could not have happened.
- **Fill price = the target.** No penetration, no slippage.
- **Entry minute, reported as a BRACKET on every curve:**
  - **lower leg (primary):** the first eligible minute is the one AFTER
    the entry minute;
  - **upper leg (S1):** include the entry minute. This is an OPTIMISTIC
    BOUND, not an estimate: the bar's high or low may predate the entry.

  Measured on the observed scalps: **9 of 612** exits filled in the same
  minute as their entry, so the bracket is expected to be narrow. Selection
  (s10) uses the lower leg and reports whether the upper leg selects the
  same X.
- Fill time for hold-time purposes = the MIDPOINT of the fill minute
  (start + 30 s). Holds are quantised to one minute; stated in the output.
- **A minute with no row had no ticks**, so no price traded and no limit
  could fill. Missing minutes need no back-fill.

**Fill-at-target is measured, not assumed.** On the 612 observed scalps,
realised pips minus the arm's live X: median 0.0, IQR 0.0 to +0.1, mean
+0.08. Outliers (-3.3 to +4.7) are clamped or modified exits.

## 5. MANUAL CLOSES

- **Primary (rule A):** if the layer was closed manually at time T and the
  counterfactual exit does not fill before T, the layer closes at T at the
  actual manual price. Operator actions are held fixed, like entries.
- **Sensitivity S2 (rule B):** ignore manual closes; the layer runs to its
  exit or to window end.

Identification, verified on the deals: every manual `OUT` deal carries the
ENT layer's own `position_id`, so its time and price are read directly --
no CloseBy pairing is involved. The 7 manual CloseBys (14 deals, reason 0)
each net an ENT against a filled EXT; those layers are observed `scalp`.

## 6. LAYERS STILL OPEN AT WINDOW END

Marked to market at the 2026-09-18 23:54 bar close: a long at `bid_close`,
a short at `ask_close`. Included in every total. **Never dropped** -- a
wider exit must pay for the layers that never reach it.

**Sensitivity S5:** end the window at 2026-09-17 23:54 instead (entries
and path both truncated there), so the dependence on one terminal moment
is visible.

## 7. COSTS

- **Commission is an FTMO account charge, not a property of the
  strategy.** Every figure is therefore reported both GROSS (no
  commission) and NET. If the selected X differs between the two, that
  difference is reported as the dependence of the choice on this broker's
  fee schedule.
- **Commission, by deal type, measured from the deals** (every value
  observed, no exceptions):

  | deal | commission per 0.01 lot |
  |---|---:|
  | ENT `IN` (entry limit fill) | 0.03 USD |
  | EXT `IN` (exit limit fill, opens the opposite position) | 0.03 USD |
  | manual `OUT` | 0.03 USD |
  | `OUT_BY` (CloseBy, either leg) | 0.00 |

  So per layer: scalp 0.06, manual close 0.06, open at window end 0.03.
  Each is charged exactly once.
- **To pips:** USD-quoted pairs (GBPUSD, EURUSD) use exactly 0.10 USD per
  pip per 0.01 lot. Other pairs use the median of price P&L per pip over
  that pair's observed scalps, where price P&L is the `profit` field of the
  CloseBy deals (commission and swap are separate fields). Thin for
  CADCHF ALT (12 scalps) and NZDCAD ALT (17); reported per pair.
- **Swap: excluded from the primary.** **Sensitivity S3:** swap rate per
  pair, side and WEEKDAY, inferred from swap booked on closed layers, with
  the Wednesday rollover charged separately as the triple night. Applied
  to each counterfactual hold. Its magnitude is reported whether or not it
  changes the answer.

## 8. OBJECTIVE AND OUTPUT

Per pair, per X in {3, 4, ..., 15}, per arm and pooled across arms:

- realised pips, MTM pips, **gross pips** (their sum), commission pips,
  **net pips** (gross minus commission)
- **CO-PRIMARY:** net pips per trading day, AND net pips per
  position-day. Position-days = sum over layers of hold time (entry to
  fill, manual close or window end). Each open position occupies one
  account slot, so this is account-slot occupancy -- "slot" here means the
  200-order account limit, NOT the OPT/ALT arm. When the two co-primary
  metrics select different X, that disagreement is itself reported as the
  finding and goes to Gemini with both curves.
  **Tie-breaker (A2):** if the account the result is for is expected to
  run WITHOUT guard saturation, net pips per day overrules net pips per
  position-day. The expected regime is stated in the results document
  BEFORE the curves are read, from the fleet size chosen for the new
  account.
- fill count and median hold
- the distribution of available horizon (window end minus entry time) for
  calibration and holdout layers separately

Pooling is valid for the exit replay because each layer is replayed
independently of its arm. Per-arm figures are reported as a check that the
two arms agree.

## 9. PARITY -- MUST PASS BEFORE ANY RESULT IS USED

At each arm's ACTUAL live exit_pips (table below), compare the replay with
what happened, per arm:

- **Classification:** of layers observed as `scalp`, the share the replay
  also fills: **at least 95%.** Of layers observed `open`, the share the
  replay also leaves open: **at least 95%.** Report the confusion matrix.
- **Fill count** within max(5%, 2 scalps) of observed.
- **Median hold** within max(10%, 15 minutes) of observed.
- The confusion matrix is also reported split by SIDE and by period
  (entries before and after ADR-151, 2026-09-17 05:16 broker), so a
  clustered error cannot hide in the aggregate.

**Monotonicity invariant, for EVERY X, not only the live ones.** Under the
fill rule, a layer that fills at X also fills at every X' < X, no later.
So for every layer, fill time must be non-decreasing in X, and per pair
fill count must be non-increasing in X. Any violation is a replay bug:
STOP. This extends parity from the two live points to the whole curve.

| pair | OPT X | ALT X |
|---|---:|---:|
| GBPUSD | 7 | 10 |
| EURUSD | 7 | 10 |
| EURGBP | 5 | 8 |
| AUDCAD | 5 | 10 |
| AUDCHF | 5 | 10 |
| CADCHF | 5 | 10 |
| NZDCAD | 5 | 7 |
| AUDNZD | 5 | 7 |

**If any arm fails: STOP.** Diagnose and report. Do not tune the fill rule
until parity passes, and record any change as an amendment in s11.

## 10. SELECTION AND HOLDOUT

**Split by ENTRY date**, alternate trading days:

- calibration: 10, 14, 16, 18 Sep (505 layers)
- holdout: 11, 15, 17 Sep (288 layers)

Layers keep their full price path whichever day they entered.

**Selection is per GROUP, not per pair** -- seven days cannot support
sixteen free choices. Groups, from the derivation memo s7.4:

| group | pairs | layers | entry days |
|---|---|---:|---|
| majors | GBPUSD, EURUSD | 313 | all 7 |
| EURGBP | EURGBP | 94 | all 7 |
| crosses | AUDCAD, AUDCHF, CADCHF | 260 | CADCHF from 14 Sep |
| NZD | NZDCAD, AUDNZD | 126 | 16 to 18 Sep ONLY |

Per-pair curves are reported as diagnostics only.

**The NZD group is EXCLUDED from selection and from the holdout test
(A2).** Its pairs started trading on 16-Sep, so it has three entry days,
one of them (17-Sep) its only holdout day, and most of its entries fall
after ADR-151 went live. It is still replayed and its curves are reported
as diagnostics. NZDCAD and AUDNZD keep their current exit_pips until they
have at least one further full week of data.

**Selection, per group, on calibration only:**

1. Smooth the pooled curve with a 3-point running median over X (ends use
   2 points).
2. The acceptable set is every X whose smoothed value is at least 90% of
   the smoothed maximum.
3. If the set is ONE contiguous run, choose its middle (round down).
4. If it is not contiguous, or if the maximum sits at X = 3 or X = 15, do
   NOT select: report the shape and that the optimum may lie outside the
   tested range.

Run separately on NET per day, NET per position-day, and GROSS per day;
report all three selections. Applies to majors, EURGBP and crosses only.

**Holdout test, per group, like for like:** replay the SAME holdout
layers twice -- once at X*, and once with each layer at its own arm's live
X (the configuration actually running during the window). Accept X* only
if holdout net pips at X* is at least equal to the live configuration's.
Otherwise keep the current values. **No tolerance band (A2).**

**Reported, not decisive:** resample the group's holdout layers with
replacement 2,000 times (seed 20260920) and report the 5th and 95th
percentiles of (net at X*) minus (net at live configuration). If the
interval straddles zero, the result is labelled as not distinguishable
from the live configuration, whichever way the binary rule fell. This
shows when one trade decided the outcome without loosening the rule.

**False acceptance is not small.** Four groups, about 30 to 130 holdout
layers each, a one-sided test: a pass is weak evidence and is reported as
such.

**Acceptance does not ship anything.** It produces a recommendation, which
goes to Gemini with the curves attached.

## 11. AMENDMENTS

**A1, 2026-09-20, NO results seen.** After the DeepSeek review
(`prompts/exit_counterfactual_prereg_deepseek_response.md`, branch
`review/exit-prereg-deepseek` at `f81acff`), each finding checked against
the deals and price files:

| finding | disposition |
|---|---|
| A1 entry-minute exclusion favours wide | Accepted: bracket (s4). Measured size: 9 of 612 real exits |
| A2 S1 is an optimistic bound | Accepted (s4) |
| A3 start-of-minute hold | Accepted: minute midpoint (s4) |
| B1 missing minutes could hide a touch | Rejected: a missing minute has no ticks, so nothing traded |
| B2 parity tests one point, curve is used | Accepted: monotonicity invariant, split confusion matrix (s9) |
| B3 penetration provenance | Resolved: measured on this window, median 0.0 (s4) |
| B4 profit field and thin samples | Checked: `profit` is price P&L; exact 0.10 for USD pairs (s7) |
| B5 triple swap | Accepted for S3 (s7) |
| C1 slot-days overstates occupancy | Rejected: each position IS one account slot; the review read "slot" as the OPT/ALT arm. Renamed position-days (s8) |
| C2 arm mapping | Verified: magic suffix 01 = OPT on 828 deals, 02 = ALT on 582, no exceptions |
| C3 manual price needs CloseBy pairing | Rejected: manual `OUT` deals carry the ENT `position_id` (s5) |
| C4 commission map | Accepted: explicit table (s7) |
| C5 holdout baseline ambiguous | Accepted: like-for-like replay of the same layers (s10) |
| D1 per-day is the wrong primary under saturation | Accepted: co-primary (s8) |
| D2 direction of the fixed-entries bias | Accepted (s12) |
| D3 over-parameterised | Accepted: four groups (s10) |
| D4 middle value undefined | Accepted: smoothing, contiguity, boundary rule (s10) |
| D5 holdout baseline contaminated | Rejected: the live values were the pre-cycle-2 settings in force DURING the window, not chosen from it. The cycle-2 values were chosen from this data and are not the baseline |
| D7 one terminal moment | Accepted: S5 (s6) |
| D8 horizon differs by split | Accepted: reported (s8) |
| D9 false acceptance | Accepted: stated (s10) |
| D10 noisy max | Accepted: 3-point median (s10) |

Not raised by the review, added here: the NZD group's three-day history
(s10).

**A2, 2026-09-20, NO results seen.** Gemini ruling on A1:

- All five rejections stand.
- Co-primary kept, with a tie-breaker: net pips per day overrules
  position-days when the target account is expected to run without guard
  saturation (s8).
- NZD group excluded from selection and holdout; diagnostic only (s10).
- Holdout bar: Gemini asked whether to allow a 95% tolerance. Decided NO
  (operator delegated the call to Claude): a calibration gain is exactly
  what overfitting produces, a band re-admits it, and a false rejection
  costs one more week of the live configuration. The outlier concern is
  answered by the bootstrap interval, which is reported but does not
  decide (s10).

**The method is locked at A2.** The replay runs after this amendment is
committed.

## 12. KNOWN BIASES -- STATED IN ADVANCE

- **Entries fixed.** A different exit closes layers sooner or later, which
  would have changed later adds, L0 re-entries and guard capacity. First
  order only.
- **Held exits.** From 17-Sep 05:16 broker (ADR-151 live) only the nearest
  exit rested; deeper exits could not fill while held. The replay assumes
  every exit rests. **Sensitivity S4:** repeat with entries before that
  time only.
- **Clamped and carry-shifted exits** existed live; the replay prices every
  exit at the raw formula. Parity will show if this matters.
- **One regime, seven trading days, guard saturated throughout.**
- **Direction of each known bias:**
  - entry-minute exclusion: toward WIDER (small; s4 bracket measures it)
  - entries held fixed: toward WIDER. A tighter exit frees slots sooner;
    under a saturated guard that would have admitted more entries, which
    the replay does not credit
  - manual-close rule A: toward NARROWER. It caps a wide exit's upside at
    the operator's close (S2 removes it)
  - terminal MTM on an underwater book: toward NARROWER. Wider exits leave
    more layers open at the end (S5 moves the end)
- **M1 resolution:** a level touched and left within one minute counts as
  filled. Limit exits filled at touch live (`exit_penetration_pips_mean`
  0.0), so this matches.

## 13. QUESTIONS FOR REVIEW

1. Is any rule in s4 to s10 biased toward wider or narrower exits in a way
   not listed in s12?
2. Is the 95% parity threshold strict enough to trust the counterfactuals?
3. Is the selection rule in s10 robust to seven days of data, or should
   pairs be pooled into groups?
4. Is MTM at window end the right treatment for open layers, given the
   week ended with most of the book underwater?

Answer each with the smallest fix. Do not call the method fatal for a
fixable issue.

Reviewed by DeepSeek 2026-09-20; dispositions in s11 A1.

Line count: 340
