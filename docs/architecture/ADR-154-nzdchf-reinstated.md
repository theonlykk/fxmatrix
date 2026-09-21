# ADR-154: NZDCHF Reinstated -- Supersedes ADR-146 D1

## Status

Accepted -- 2026-09-21, operator decision. Supersedes Decision 1 of
ADR-146 (`ADR-146-chf-tail-window-recalibration.md`). ADR-146's other
decisions stand.

## Context

ADR-146 D1 rejected NZDCHF. The evidence was a simulator sweep at width 7
over three holdout windows: both ordinary windows passed with zero
breaches, and `holdout_tail_2015q1` -- the January 2015 SNB floor removal
-- failed, 90% of seeds breaching the daily drawdown gate (mean 1105
against a 500 limit).

The operator challenged the rejection on 2026-09-20. Reading ADR-146
itself:

1. **It rejected a GEOMETRY, not a pair.** Its own s5.2 shows survival on
   the same grid and seeds varying about sevenfold with width: 8-10% at
   width 7, **60-74% at width 3**. NZDCHF at a narrower width was never
   the thing tested.
2. **The same gate disqualifies the live fleet.** ADR-146 s5.1 ran it on
   AUDCHF and CADCHF, which are trading: every cell breached, up to 82%.
   Applied consistently the rule would withdraw four live instances. The
   ADR noticed this and treated it as a reason for leniency elsewhere,
   not for consistency.
3. **It is simulator evidence.** ARCHITECT s12 requires a parameter
   derived from simulated fills to be re-validated against real fills
   before it governs live orders. NZDCHF has no fills, so nothing was
   validated either way.

**It was not a carry decision.** The rejection rested on the tail-window
drawdown gate, not on swap.

## Decision

NZDCHF joins geometry cycle 3 (`docs/architecture/geometry-cycle3.md`),
one arm, on the OPT magic `22260701`:

| add | exit | width | stranded | deadband | cap | lots |
|---:|---:|---:|---:|---:|---:|---:|
| 6 | 10 | **3** | 8 | 4 | 8 | 0.01 |

Width 3 is the width ADR-146's own data shows surviving the tail window
most often. Add 6 and exit 10 follow the cycle's conventions for a pair
with no fills of its own.

## Consequences

**It completes the AUD/CAD/CHF/NZD block.** With NZDCHF, the cycle holds
every pairing of those four currencies, so each appears exactly three
times. CHF carries no structural extra weight.

**CHF instance count falls, not rises:** four today (AUDCHF and CADCHF,
two arms each), three in cycle 3.

**The tail risk is accepted, not dismissed.** The 2015 SNB event is real,
and a CHF shock hits three pairs at once. What changes is that the risk is
now priced by live fills rather than refused on one simulated window.
Symmetric pair counts do not guarantee symmetric EXPOSURE: a trending week
can still leave the book positioned one way in CHF. Watch position, not
pair count.

**Spread is unknown.** NZDCHF was not quoted by the fleet before; if its
spread proves wide, it will fill rarely at any width. The cycle's
volume metric will show that within two days.

## Review

Operator decision on the operator's challenge; recorded rather than put
through DeepSeek, since no code changes -- one preset.
