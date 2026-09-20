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
- **Primary:** the first eligible minute is the one AFTER the entry
  minute. **Sensitivity S1:** include the entry minute.
- Fill time for hold-time purposes = the start of the fill minute.

## 5. MANUAL CLOSES

- **Primary (rule A):** if the layer was closed manually at time T and the
  counterfactual exit does not fill before T, the layer closes at T at the
  actual manual price. Operator actions are held fixed, like entries.
- **Sensitivity S2 (rule B):** ignore manual closes; the layer runs to its
  exit or to window end.

## 6. LAYERS STILL OPEN AT WINDOW END

Marked to market at the 2026-09-18 23:54 bar close: a long at `bid_close`,
a short at `ask_close`. Included in every total. **Never dropped** -- a
wider exit must pay for the layers that never reach it.

## 7. COSTS

- **Commission is an FTMO account charge, not a property of the
  strategy.** Every figure is therefore reported both GROSS (no
  commission) and NET. If the selected X differs between the two, that
  difference is reported as the dependence of the choice on this broker's
  fee schedule.
- **Commission:** measured from the deals, not assumed. Every entry,
  exit fill and manual close is charged 0.03 USD per 0.01 lot; CloseBy is
  free. A scalp costs 0.06 USD, a manual close 0.06, an open layer 0.03.
- **To pips:** USD per pip per pair = median of `profit / pips` over that
  pair's observed scalps. Reported per pair in the output.
- **Swap: excluded from the primary.** **Sensitivity S3:** per-night swap
  rate per pair and side, inferred from the swap booked on closed layers
  divided by rollovers crossed, applied to each counterfactual hold. Its
  magnitude is reported whether or not it changes the answer.

## 8. OBJECTIVE AND OUTPUT

Per pair, per X in {3, 4, ..., 15}, per arm and pooled across arms:

- realised pips, MTM pips, **gross pips** (their sum), commission pips,
  **net pips** (gross minus commission)
- **net pips per trading day** -- **PRIMARY**
- slot-days (sum of layer hold time, entry to fill, manual close, or
  window end) and **net pips per slot-day** -- secondary
- fill count and median hold

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

**Selection, per pair, on calibration only:** among X whose pooled net pips
per day is at least 90% of that pair's maximum, choose the MIDDLE value
(round down). A flat region, not the peak. The same rule is applied to
GROSS pips and both selections are reported.

**Holdout test, per pair:** accept X* only if holdout net pips per day at
X* is at least 90% of the better of the pair's two current live values on
the holdout. Otherwise keep the current values.

**Acceptance does not ship anything.** It produces a recommendation, which
goes to Gemini with the curves attached.

## 11. AMENDMENTS

None yet. Every later change to s4 to s10 goes here, dated, with its reason
and whether results had been seen.

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

Line count: 184
