# MEMO -- ADDING A NEW PAIR END TO END: NZDJPY

For the new chat. This is the complete process from an empty slate to a preset
file ready to attach. Run it for **NZDJPY**.

It is written as a worked example because the steps are not obvious and several
have traps that have already bitten once.

**Do each stage and report before moving on.** The operator runs the MetaEditor
and Surface steps; you cannot.

---

## STAGE 0 -- WHAT ALREADY EXISTS FOR JPY, AND WHAT DOES NOT

**Exists:** `sim_costs.py` has specs for USDJPY, AUDJPY and CHFJPY, so the
JPY pip-value branch is written and parity-tested.

**Also exists (CORRECTION, verified 2026-09-12):** the conversion loader is
generic. `load_aligned_conversion_closes(primary_times, symbol, data_root,
window_suffix)` reads `conversion_pair` from the spec, returns None for
USD-quoted pairs, and RAISES if a conversion pair is configured but its CSV
is missing. The 2026-09-07 handoff recorded "something will have to supply
the USDJPY series" as an open gap; that gap is CLOSED in code. You still
need the USDJPY export (Stage 2c), but no loader change.

**Critical caveat: it has NEVER been tested against real market data.** The
parity tests used synthetic values. NZDJPY will be among the first JPY pairs to
touch a real series here. Treat any JPY result with more suspicion than an
ordinary one.

**Does not exist:** NZDJPY spec, NZDJPY cap, NZDJPY data, NZDJPY geometry.

**The JPY conventions, which differ from every other pair in the fleet:**

    pip size    0.01      not 0.0001
    point       0.01      in this codebase `point` means ONE PIP IN PRICE
                          UNITS, not the MT5 tick size. This tripped up the
                          original JPY work.
    conversion  DIVIDE by USDJPY. JPY-quoted pairs convert the opposite way
                to GBP-quoted ones. Getting this backwards produces a figure
                wrong by a factor of ~150 that still looks plausible.

---

## STAGE 1 -- CONFIRM THE PAIR IS TRADEABLE

**1a.** Operator checks NZDJPY is in FTMO's Market Watch on the VPS terminal and
reports the live bid/ask.

**1b.** Compute the spread in pips from that quote. **JPY pairs quote to three
decimals**, so a spread of 0.025 is 2.5 pips, not 25.

**1c.** Sanity check it against the geometry you intend. A 5-pip exit on a pair
with a 3-pip spread is a different proposition from one with 0.8. If the spread
is wide, say so now rather than after a sweep.

**Report:** the quote, the derived spread, and whether the pair looks viable.

---

## STAGE 2 -- EXPORT THE DATA

**2a.** `scripts/DataExporterEA.mq5` is committed and works. It runs in the
**Strategy Tester**, not on a chart -- the live terminal only holds ~16 months
of M5, whereas the Tester reaches back to 2014.

**2b.** Operator runs it on the DESKTOP terminal with:

    Expert:     DataExporterEA
    Symbol:     NZDJPY
    Period:     M5
    Modelling:  Open prices only
    Date:       Custom, 2015.01.01 to today
    InpFrom:    2015.01.01
    InpTo:      today
    InpOutFile: NZDJPY_m5.csv

**2c. You also need the CONVERSION SERIES.** NZDJPY is JPY-quoted, so USD
conversion needs **USDJPY**. Export that too if it is not already in `data/`.

**2d.** The first run per symbol is slow -- the Tester downloads M1 history and
derives M5 from it, which took 2m32s for AUDUSD. Later runs on cached symbols
take seconds. **It also pulls constituent symbols automatically**, so expect
unrequested symbols to appear in the log. That is correct behaviour.

**2e.** Output lands in
`%APPDATA%\MetaQuotes\Terminal\Common\Files\NZDJPY_m5.csv`. Operator copies it
to `D:\fxmatrix\data\`.

**2f. Read the `WROTE ... bars= first= last=` line.** `first=` is what matters:
if NZDJPY does not go back to 2015 the pre-registered windows may not all be
available. AUDCAD gave 867,913 bars from 2015.01.02.

**Report:** bar count, first and last bar, and any coverage shortfall.

---

## STAGE 3 -- ADD THE PAIR SPEC

**3a.** Add NZDJPY to `PAIR_SPECS` in `scripts/sim_costs.py`:

    symbol          NZDJPY
    point           0.01      one pip in price units
    pip_size        0.01
    quote_currency  JPY
    contract_size   100_000
    conversion_pair USDJPY

**3b. MEASURE the spread from the data, do not assume it.** The exported CSV has
a per-bar `SPREAD` column in MT5 POINTS. Take the median across the series and
divide appropriately for a three-decimal quote. State the figure and the sample
period, and comment in source that it is measured.

**While you are there, RE-MEASURE the three existing JPY spreads.** Stage 0
says JPY specs exist, which is true, but `PAIR_SPREAD_PIPS` carries USDJPY
1.1, AUDJPY 1.6 and CHFJPY 2.6 as single-observation Labor Day snapshots,
commented in source as "re-measure before informing any deployment
decision". Any JPY sweep inherits them. The CAD/CHF ring values (0.90 /
0.80 / 1.10) are measured medians over ~867k bars and are the pattern to
follow. Replace the three provisional constants in the same commit as the
NZDJPY spec, and state the sample period in the comment.

**This matters:** measured spreads for the AUD/CAD/CHF ring came out at
0.90/0.80/1.10 pips against assumed constants that were wrong by a factor of
six for EURUSD.

**3c. Add the cap.** `get_pair_max_layers` RAISES for unconfigured pairs by
design -- the sweep will not run without it. **Ratified value for cross pairs is
8**, matching EURGBP and the existing ring.

Before accepting 8, run the drawdown arithmetic: worst case is
`sum over k of (D - k*add) * pip_value` for 8 layers at your intended spacing,
against the $500 daily gate. The AUD/CAD/CHF pairs came out at $288-479 for a
500-pip excursion against EURGBP's $517, which is what justified 8.

**3d. Parity assertions, independently derived.** Follow the pattern used for
the CAD/CHF work:

  - pip_value_quote_currency at 0.01 lots is **0.1 JPY** (1,000 units x 0.01)
  - pip_value_usd DIVIDES by USDJPY: at 153.0 that is 0.1/153 = **0.000654**
  - a HIGHER USDJPY gives a LOWER USD pip value
  - regression: EURGBP still MULTIPLIES by GBPUSD, unchanged

**Report:** the spec, the measured spread, the cap justification, and the test
pass count.

---

## STAGE 4 -- SLICE THE WINDOWS

**4a.** `scripts/slice_ring_windows.py` cuts the continuous series into the five
pre-registered windows. Extend it for NZDJPY, or run it with the pair added.

The five windows, ratified and not to be altered:

    calib_chop_2020q3      calibration  harvest  2020-07-10 to 2020-10-08
    calib_stress_2022q1    calibration  stress   2022-02-01 to 2022-05-01
    holdout_chop_2026q2    holdout      harvest  2026-04-24 to 2026-07-23
    holdout_stress_2020q1  holdout      stress   2020-02-01 to 2020-05-01
    holdout_tail_2015q1    holdout      tail     2015-01-02 to 2015-03-01

**4b. The chronology is deliberate.** Calibration harvest (2020) precedes
holdout harvest (2026) so the holdout is a genuine forward walk. Do not
"correct" it.

**4c. USDJPY must be sliced to the IDENTICAL windows** and LEFT JOINED onto
NZDJPY's timestamps with forward-fill. **Never inner join** -- an illiquid cross
has empty M5 bars where a major does not, and an inner join silently deletes
thousands of primary bars. **Never drop a primary pair bar.**

**4d.** Report per window: bar counts, first and last timestamps, forward-fill
counts, and the median spread. **A stress window with a much wider spread is a
real finding**, not an artifact -- the 2015 tail window showed 7-9 pips on the
ring pairs, which is why it is a survival test rather than an economic one.

---

## STAGE 5 -- RUN THE SWEEP

**On the SURFACE.** RDP in, activate the venv.

**5a. DRY RUN FIRST. Always.**

    python scripts/run_width_exit_sweep.py --dry-run --pairs NZDJPY \
      --windows calib_chop_2020q3 calib_stress_2022q1

This prints the resolved CSV path for every cell and exits. **`_window_file_suffix`
decides which file each cell reads** -- a wrong mapping runs happily against the
wrong window and produces a clean-looking result that is silently invalid.

**5b.** NZDJPY must be added to `PAIRS`, `WINDOW_META` and `WINDOW_ROLES` in
`run_width_exit_sweep.py`, or it is not selectable. Note `--pairs` only SUBSETS
the hardcoded tuple.

**5c.** Then the sweep:

    python scripts/run_width_exit_sweep.py --pairs NZDJPY \
      --windows calib_chop_2020q3 calib_stress_2022q1 \
      --widths 3,5,7 --exits 2,5,7 --n-seeds 50 --substeps 100 \
      --runtag nzdjpy_v1 --fresh

**Use `--fresh`** -- the cost model has changed and any old checkpoint is
invalid.

**5d.** Eighteen cells at roughly 4-5 minutes each, so about 90 minutes. The
Surface is a 4-core i5-8350U; set it not to sleep.

---

## STAGE 6 -- READ THE RESULT SCEPTICALLY

**6a. Check `mean_max_layers` against the cap.** If every cell pegs at exactly 8,
the cap binds everywhere and the sweep is comparing a constrained system rather
than discriminating between geometries. That is what happened with AUD/CAD/CHF
and it makes the "winner" much weaker evidence.

**6b. Check gate breach rates.** Under a working cap these came out at 0% on
every ring cell. If yours show breaches, that is worth understanding -- it would
be the first.

**6c. Sanity-check the P&L magnitude by hand.**

    mean_exits x exit_pips x pip_value_usd - (mean_exits x commission)

against the reported `mean_realised`.

**Commission is now a measured figure, not an estimate.** FTMO's symbol
specification reads `2.5 USD per lot, in and out`, which at 0.01 lots is
**0.05 USD per round trip**. Earlier versions of this check used 0.06; use
0.05 and say where it came from.

**The simulator does NOT model financing.** Carry is charged per night held
and is material: measured on 2026-09-11, a week-held AUDCHF short costs
-7.47 pips against a 5-pip exit target. NZDJPY's own carry must be read
from the symbol specification (Swap long / Swap short, in points, divided by
10 for pips on a three-decimal quote) and stated alongside the sweep result.
A sweep that looks profitable before financing may not be after it. For AUDCAD this tied to within $0.40 and
confirmed the conversion was right. **For a JPY pair this check matters more
than usual**, because the conversion direction has never been exercised on real
data.

**6d. THE SIMULATOR'S KNOWN DIVERGENCES.** Do not treat its answer as truth:

  - **single-sided** -- it latches one direction and runs one ladder, while
    production runs both. This UNDERSTATES chop harvest, which is exactly where
    a wider exit benefits.
  - **touch-fill**, no adverse selection -- a documented ceiling.
  - **Brownian bridge** between bars, not real ticks.

**Live fills outrank the simulator.** On the majors the capped sweep preferred
tighter exits while the live A/B found wider ones won on every measure. The
sweep's role is pairs with no live data -- which NZDJPY is -- so it is the only
evidence available, not a verdict.

---

## STAGE 7 -- CHOOSE THE GEOMETRY

**7a. Arm A** = the sweep's pick, subject to 6d's caveats. For the ring this
came out at 5/5 -- exit 5 topped five of six pair-window combinations, and
width 5 was the compromise between chop preferring 3 and stress preferring 7.

**7b. Arm B** = same width, wider exit. For the ring this was 5/10, putting the
exit exactly ON the add spacing -- ratio 1.00, the symmetric case.

**The fleet-wide experiment is exit distance as the ONLY variable.** Whatever
you pick must preserve that: same width, same add spacing, same cap between
arms.

**7c.** Note where NZDJPY's ratios land relative to the existing fleet, which
currently spans 0.50 to 1.33. A new pair at a ratio already well covered adds
less than one filling a gap.

---

## STAGE 8 -- WRITE THE PRESETS

Two files, `nzdjpy_opt.set` and `nzdjpy_alt.set`, in `ea/presets/`.

**8a. Copy the STRUCTURE from `eurgbp_opt.set`** -- 20 inputs, cap 8. **But NOT
its geometry**: it runs width 3 and the ring runs 5. Set every geometric field
explicitly rather than inheriting.

**8b.** `InpAddPips` and `InpStrandedThreshPips` are BOTH `2.0 x InpWidthPips`.
**The EA asserts this at init and refuses to start on a mismatch.**

**8c. Magic numbers.** The scheme is `2226` + pair code + slot. Currently:
GBPUSD 01, EURUSD 02, EURGBP 03, AUDCAD 04, AUDCHF 05, CADCHF 06. **NZDJPY would
be 07** -- 22260701 and 22260702. Verify no collision across the whole fleet.

**8d.** `InpCapLegA=NZD`, `InpCapLegB=JPY`, both thresholds **0.0** -- currency
caps are disabled fleet-wide.

**8e.** `InpTelemetryInstance` must be **exactly** `GRIND_NZDJPY_OPT` /
`GRIND_NZDJPY_ALT`. pipshed keys Redis on this string; a typo means the card
never appears and the data lands under a name nothing reads.

**8f.** `InpConfigWarning` under 60 chars, no quotes, naming arm and geometry --
e.g. `NZDJPY ArmA 5/5 ring cycle2`. **This is what prints in the config dump at
attach and it is your last chance to notice a wrong file.**

**8g.** `TelemetryAPIKey=` **EMPTY**. Pasted at attach time. The repo is public.

---

## STAGE 9 -- PIPSHED AND DEPLOYMENT

**9a.** Add both instances to `GRIND_INSTANCES` in pipshed's `app.py` and to the
ring mapping. The OPT/ALT lists derive by suffix, so they follow automatically.

**9b.** Three verify scripts derive their counts from `GRIND_INSTANCES`, so they
adapt without edits. Run them.

**9c. Deployment, in order:**

    1. merge to main on both repos
    2. VPS: .\deploy.ps1
    3. VPS: COPY THE PRESETS SEPARATELY -- deploy.ps1 does NOT copy them
    4. VPS: compile fxgrind.mq5 in MetaEditor -- deploy does NOT compile
    5. attach two charts, load the presets, paste the key
    6. CHECK `symbol=` IN THE CONFIG DUMP against the instance name

**Step 6 is not optional.** A EURGBP preset was loaded onto a GBPUSD chart and
placed orders before it was caught.

**9d.** After attaching, read the fleet from the status endpoint and confirm
both instances show the right geometry, `recon_ok`, and nothing halted.

**9e.** Confirm NZDJPY appears in the pipshed carry table
(`/api/g/<token>/carry/<segment>`) with `swap_mode` 1 and non-zero pips on a
weekday. Every fleet pair so far quotes swap in POINTS; if NZDJPY does not,
STOP and report -- the carry maths assumes points mode.

---

## STAGE 10 -- VALIDATE THE COST MODEL AGAINST LIVE FILLS (NEW)

This stage did not exist when the ring pairs were added. The archive
(ADR-130/131/134) now records every send and every fill with its limit
price, so a pair's assumed costs can be CHECKED after deployment instead of
being trusted indefinitely.

After roughly one week live:

**10a. Spread.** Compare the measured spread from Stage 3b against what the
live book actually shows. The status endpoint reports live bid/ask per
instance; the archive's `send_logs` records every requested price.

**10b. Slippage.** Query `fill_logs WHERE entry_type='IN'` for NZDJPY and
compare `deal_price` against `order_price_open`. A passive limit should fill
at its price; the fleet has already recorded fills 0.1 pips WORSE than the
resting limit, which the simulator's touch-fill model cannot produce.

**10c. Commission.** `fill_logs.commission` carries the real figure per
deal. Confirm 0.05 USD per round trip at 0.01 lots.

**10d. Financing.** Two consecutive CARRY_SNAPSHOT rows give what the broker
actually charged overnight. Compare against the quoted rate used in 6c.

**If any of these disagree with the sweep's assumptions, correct
`sim_costs.py` and note the correction in the ADR.** A cost model that has
never been checked against live fills is an assumption, not a measurement.

---

## WHAT TO REPORT BACK AT EACH STAGE

Stage 1: quote, spread, viability.
Stage 2: bar count, date coverage.
Stage 3: spec, measured spread, cap justification, test count.
Stage 4: per-window bars, ffill counts, spreads.
Stage 5: dry-run paths, then the sweep summary.
Stage 6: the hand-checked P&L, cap saturation, your reading of the result.
Stage 7: proposed Arm A and Arm B with reasoning.
Stage 8: both preset files in full.

**Stop and ask if anything surprises you.** A JPY pair is new ground for this
simulator and a result that looks too good is more likely a conversion error
than an opportunity.

Stage 9: config dump per instance, status read.
Stage 10: the four live-versus-assumed comparisons, after a week.

---

**Revised 2026-09-12:** conversion-loader gap corrected (Stage 0), JPY
spread re-measurement added (Stage 3b), commission figure measured and
financing noted (Stage 6c), carry-table check added (Stage 9e), and Stage 10
added for live cost-model validation.
