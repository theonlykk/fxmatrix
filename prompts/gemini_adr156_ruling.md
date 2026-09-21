This message has a line count at the bottom

# GEMINI RULING -- ADR-156 STARTUP EXIT SHORTFALL (2026-09-21)

Two memos from Gemini, summarised by Claude. The first ruled on five
items; the second withdrew the amendment in item 3 after a reconsider
memo (`prompts/gemini_adr156_item3_reconsider.md`, if saved).

## FINAL RULINGS

| # | question | ruling |
|---|---|---|
| 1 | Tolerant rebuild at startup only; the existing retry places the exit; the OnTick check stays strict | **APPROVE** |
| 2 | Tolerance covers ALL required ranks (rank 0 and `depth - 1`), not only `depth - 1` | **APPROVE** |
| 3 | What happens on a large startup shortfall | **No halt.** Count per side. If either side's shortfall is 2 (every required exit on that side), emit `Grind_TelemetryCritical` `STARTUP_EXIT_SHORTFALL_SIDE` plus the archive marker, then continue: the retry places the exits and the strict OnTick check follows |
| 4 | Quarantine counts checks even when the guard blocks the retry | **Out of scope.** Separate ADR |
| 5 | Wednesday build | **Include ADR-156 if the suite is green** |

## ITEM 3 -- HOW IT CHANGED

**First ruling (withdrawn):** return `INIT_FAILED` when the shortfall is
above 2 (or above 1 on a side), and add test X10 expecting `OnInit` to
fail.

**Reconsider memo, three source points:**
- `INIT_FAILED` unloads the EA from the chart: no heartbeat, no telemetry,
  and nothing managing its exits. This EA's pattern is to halt IN PLACE
  (`fxgrind.mq5:175-177`).
- The required set depends only on rank and depth
  (`grind_exitq.mqh:43-50`). With K = 1, at most two exits per side are
  ever required, so an add/width change cannot create a shortfall.
- Placing an exit never adds exposure. A startup halt cannot be cleared by
  a reattach, so it would recreate the unrecoverable state ADR-156 removes.

**Second ruling:** all three points conceded and the halt withdrawn. The
per-side counters, the critical telemetry at 2, and continuing to the
retry are approved. The original X10 is withdrawn (`OnInit` cannot be run
in the suite) and replaced by a pure helper test:
`Grind_StartupShortfallCritical(long_n, short_n)`.

## TEST EXPECTATIONS CONFIRMED BY GEMINI

- X6: long 2, short 1. Critical is TRUE.
- X3: long 1, short 0. Critical is FALSE.
- X4 (the roll): long 1. Critical is FALSE.

## STILL OPEN

- The DeepSeek audit (mandatory; ADR-156 changes when orders are placed).
- ADR Q3, whether `OnInit` placement depends on uninitialised state, is
  passed to DeepSeek as T-2.

Line count: 53
