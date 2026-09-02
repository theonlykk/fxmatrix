# Phase 1 Audit Request — Turnover-Metric Reframing for ADR-097 GBPUSD Sweep

## Role reminder
This is a Phase 1 Red Team submission per ARCHITECT.md. No implementation
code is being requested or should be produced in response. The ask is
adversarial, statistically rigorous critique of a proposed **evaluation
metric**, not a code change.

## What is being proposed
FXMatrix is a market-making/grid strategy that never voluntarily closes at
a loss — every layer holds to a fixed ~3-pip target however long it takes.
"Recycling scalps is our business," run as a going concern, not scored by
a point-in-time liquidation value.

The existing ADR-097 GBPUSD threshold sweep ranked configs (no_op, default
2/5, tighter 1/3, middle 1/4) by raw in-test P&L alone. The proposal is to
ALSO rank by a turnover metric:

    dollar_turnover = in-test P&L / time-avg |net lots|

on the reasoning that raw P&L rewards configs that simply tie up more
capital for longer, while turnover measures return per unit of capital
tied up — closer to how a going-concern churn business should be scored.

## What changed with the corrected data
An earlier draft of this reframing claimed default easing improved the
picture on every window. That was wrong and has been corrected. The
verified, script-computed comparison (default 2/5 vs. true same-binary
no-op, all four canonical windows) is:

| Window | Raw P&L verdict | dollar_turnover verdict | Agree? |
|---|---|---|---|
| Truss Crisis | default helps (+$28.87) | default helps (+2174.58) | Yes |
| Q1 2024 Chop | default hurts (−$22.94) | default **helps** (+321.52) | **No** |
| Vaccine Rally | default helps (+$7.97) | default helps (+2533.30) | Yes |
| Full Quarter | default hurts (−$2.69) | default hurts (−72.27) | Yes |

Only Q1 2024 Chop flips sign. Full Quarter is negative under both metrics
and is NOT explained away by this reframing — it stands as a real,
unresolved drag under default easing on that window, on either lens.

Mechanism claimed for the Q1 Chop flip: default easing produces fewer
exits (409 vs. 486) but also a proportionally larger reduction in
time-avg net exposure (0.015150 vs. 0.019281 lots, −21.4%) than in dollar
return (−17.7%), so turnover ranks default above no_op despite lower raw
P&L.

## Full dataset (all 16 cells, GBPUSD)

| cfg | window | in-test P&L | total exits | max\|net\| | time-avg\|net\| | dollar_turnover | scalp_density |
|---|---|---:|---:|---:|---:|---:|---:|
| no_op | truss_crisis | 161.74 | 600 | 0.0400 | 0.017755 | 9109.44 | 33792.89 |
| no_op | q1_2024_chop | 129.81 | 486 | 0.0500 | 0.019281 | 6732.56 | 25206.25 |
| no_op | vaccine_rally | 246.48 | 815 | 0.0600 | 0.030550 | 8068.20 | 26677.95 |
| no_op | full_quarter | 118.98 | 460 | 0.0700 | 0.019454 | 6116.06 | 23645.89 |
| default | truss_crisis | 190.61 | 659 | 0.0400 | 0.016892 | 11284.02 | 39012.47 |
| default | q1_2024_chop | 106.87 | 409 | 0.0500 | 0.015150 | 7054.08 | 26996.53 |
| default | vaccine_rally | 254.45 | 967 | 0.0700 | 0.024001 | 10601.50 | 40289.43 |
| default | full_quarter | 116.29 | 443 | 0.0700 | 0.019241 | 6043.79 | 23023.45 |
| tighter | truss_crisis | 232.96 | 853 | 0.0400 | 0.014057 | 16572.57 | 60681.66 |
| tighter | q1_2024_chop | 142.76 | 535 | 0.0400 | 0.012397 | 11515.68 | 43155.55 |
| tighter | vaccine_rally | 230.09 | 877 | 0.0500 | 0.020915 | 11001.23 | 41931.77 |
| tighter | full_quarter | 126.11 | 491 | 0.0700 | 0.013895 | 9076.10 | 35337.11 |
| middle | truss_crisis | 237.24 | 869 | 0.0400 | 0.017445 | 13598.94 | 49812.34 |
| middle | q1_2024_chop | 117.79 | 458 | 0.0400 | 0.010690 | 11018.51 | 42843.00 |
| middle | vaccine_rally | 253.51 | 963 | 0.0700 | 0.022702 | 11166.69 | 42418.55 |
| middle | full_quarter | 112.89 | 432 | 0.0700 | 0.015281 | 7387.53 | 28270.11 |

`scalp_density = total exits / time-avg |net lots|` is reported alongside as an
alternative that uses exit count rather than dollar P&L in the numerator.

## Confirmed from code (not assumed)
`InpLotSize` is applied identically to L0, Add, Reload, and exit orders. It
does not scale with layer depth. So raw P&L and exit count are not
decoupled by volume scaling across configs — that part of the metric is
sound. What is NOT resolved by this: **time-avg |net lots| measures net
exposure (capital tied up), not gross lots traded.** This is an explicit
open modeling assumption, not something the lot-size code settles.

## Explicit questions for Red Team critique

1. **Denominator choice.** Is time-avg |net lots| (net exposure) the right
   denominator for a "return per unit of capital" argument, or should this
   be gross lots traded (total volume filled), or something else entirely?
   Net exposure is arguably the right denominator for a risk-adjusted
   return; it is not obviously the right one for a throughput/turnover
   argument. Attack this directly.

2. **Selection bias.** Is dollar_turnover being reached for because it
   flatters the desired conclusion (that default easing doesn't hurt
   GBPUSD), rather than because it's the correct lens on its own merits?
   Note the reframing was proposed with a mistaken "improves everywhere"
   claim initially, corrected only under independent script verification.

3. **Regime/window curve-fitting.** Four windows is a small sample. Does
   ranking configs by a metric invented after seeing the data risk fitting
   to these four specific historical windows rather than reflecting a
   real property of the strategy?

4. **Retail heuristic check in reverse.** Raw P&L is arguably the "retail"
   metric here (point-in-time snapshot), and turnover the more
   institutional one — but confirm this isn't itself an arbitrary
   normalization choice smuggled in to override an inconvenient result on
   Q1 Chop specifically (the one window where the two metrics disagree).

5. **Full Quarter.** This window is negative under both metrics. Does this
   invalidate applying the turnover reframing broadly, or is it just a
   window where default easing genuinely underperforms regardless of lens?

## What Red Team must NOT do
Per Phase 1 rules, do not write implementation code or propose a specific
threshold decision. The output of this phase is critique: identify the
metric's flaws, propose a corrected or alternative formulation if the
current one doesn't hold up, and flag anything that should block sending
this reframing to the Staff Architect until fixed.
