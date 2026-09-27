This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM GRIND V2.0: ADD, EXIT AND WIDTH PER SIDE

You are auditing a feature branch BEFORE it merges to `main`. It is
tested on GBPUSD and EURUSD: stubs and tests (`0d46c26`) 2145/2168,
failing exactly the 23 predicted; the implementation (`907b1c7`)
2168/2168. Find what tests cannot see. The attached files carry NO line
numbers: cite `file`, `function` and QUOTE the line (one line, or part
of one). A claim without a quote is discarded. Line numbers below are
ours, for orientation (at `907b1c7`).

**The system:** an MQL5 passive limit-order FX market maker (no stops,
no market orders, hedging account, 0.01 lots, cap 8 layers per side).
Eleven instances per terminal share global variables. Each side (long,
short) is a ladder: L0 rests `width` from mid; each add rests `add`
beyond the deepest entry; each layer's exit rests `exit` beyond its
(effective) entry, plus carry accrual, an eject offset and a clamp
shift. The exit queue (ADR-151, K=1, H=0) keeps only rank 0 and the
highest rank resting. I6 checks each resting exit against that formula
within 2 points, at init (`Grind_ReconstructState`) and every tick
(`Grind_CheckBookInvariants`); a failure quarantines, then halts. The
ADR-162 lattice (input `InpVirtualLattice`) rolls the oldest layer's
exit to a virtual level past cap; a nightly carry pass re-prices resting
exits; a commanded eject moves the deepest exit to the market and stores
an offset.

**This branch (v2.0).** Before it, one `InpWidthPips`, `InpAddPips`,
`InpExitPips` priced both sides. Now:
- six inputs `InpWidthPipsLong/Short`, `InpAddPipsLong/Short`,
  `InpExitPipsLong/Short` (`fxgrind.mq5` 19-24): exactly -1 inherits the
  base input, > 0 overrides, anything else is FATAL
  (`Grind_ResolveSideInput`, `grind_pure.mqh` ~68); each side's resolved
  triple passes the existing geometry and add/width (ADR-153) checks;
- the resolved LONG values travel where the single value travelled; the
  SHORT values travel in NEW LAST PARAMETERS (default 0.0) of thirteen
  dispatch functions, resolved by `Grind_SidePips(is_long, long_or_both,
  short_value)` (`grind_pure.mqh` ~61): short_value when `!is_long &&
  short_value > 0.0`, else long_or_both. Inner pricing functions are
  unchanged and still take one value;
- globals: `g_grind_engine_add_pips_short` (engine ~26, the add at fill,
  ADR-152) and `g_grind_recon_exit_pips_short` (recon ~18, retry and I6
  wrappers), set in `OnTickEngine`/`OnTradeTransactionEngine` and
  `OnInit`;
- reporting: the legacy `width_pips`/`add_pips`/`exit_pips` keys carry the
  LONG values; six new keys in the heartbeat and INIT/DEINIT fields; a
  `GRIND_GEOMETRY` line at init.

The thirteen: engine `Grind_OnTickEngine` (~2770),
`Grind_ServiceDueAddFlags` (~2291), `Grind_OnTradeTransactionEngine`
(~2915), `Grind_LatticeOnTick` (~1253), `Grind_AutoEjectOnTick` (~626),
`Grind_EjectPollCommand` (~435); recon `Grind_ReconCheckInvariants`
(~462), `Grind_RebuildBookFromTicketsInner` (~842),
`Grind_RebuildBookFromTickets` (~1162); carry `Grind_CarryExitPassBegin`
(~936), `Grind_CarryWorkBase` (~977), `Grind_CarryOnTimerStep` (~1150),
`Grind_CarryExitPassStep` (~1168). Also changed without a new parameter:
`Grind_HandleSideDealFill` (~2551, add at fill) and
`Grind_RetryMissingExits` (~2759).

**Ruled -- do not re-open (Gemini GV-Q1..Q8):** one EA with inherit-by-
default overrides rather than a new file; short values as new last
parameters at dispatch level; the ADR-153 guard per side, unchanged; NO
rebuild at start in v2.0 (a reattach with a changed exit on a live book
halts on I6 exactly as before, by design; the first deployment is a
flat account); legacy keys carry long values; the sentinel is exactly
-1; the lattice takes its side's add and exit; `Grind_CheckBookInvariants`
and `Grind_ReconstructState` read the broker book with no test seam, so
their short wiring is checked at deploy (the first preset whose sides
differ), not in tests. Deadband, stranded threshold, cap and lots stay
symmetric.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. `Grind_SidePips` returns `short_value` only for the short side and
  only when `short_value > 0.0`.
- G2. Every new parameter defaults to 0.0, so every pre-existing call
  (tests included) resolves the short side to the value it used before.
- G3. With all six inputs at -1, every resolved value equals its base
  input.
- G4. None of these inner functions changed: `Grind_ExitPrice`,
  `Grind_AddTargetPrice`, `Grind_ExitQFormulaTarget`,
  `Grind_ComputeAddTarget`, `Grind_SendNextAddEnt`,
  `Grind_EnsureAddNext`, `Grind_LatticeTrySide`, `Grind_LatticeRollLayer`,
  `Grind_ExitQManageSide`, `Grind_EjectAcceptLayer`.
- G5. `fxgrind.mq5` passes long values in the old slots and short values
  in the new parameters at EVERY engine call in `OnInit`, `OnTick`,
  `OnTimer` and `OnTradeTransaction`.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 A missed site.** Is there ANY path that prices a SHORT-side
  order (L0, add, exit, lattice level, roll target or cost, stranded
  threshold, carry shift, eject offset) with the long or base value?
  Follow every caller of `Grind_ExitPrice`, `Grind_AddTargetPrice`,
  `Grind_ComputeAddTarget`, `Grind_ExitQFormulaTarget`,
  `Grind_StraddleSellPrice`, `Grind_ExitQManageSide`,
  `Grind_EnsureAddNext`, `Grind_SendNextAddEnt`,
  `Grind_TryPlaceAddAtFill`, `Grind_ApplyEntryHorizon`,
  `Grind_LatticeTrySide`, `Grind_EjectAcceptLayer`,
  `Grind_CarryExitShiftLayer`, including paths from `OnInit`
  (`Grind_RetryMissingExits`), the quarantine branch of `OnTick`, the
  carry window close, ADR-152's due flags and held adds, and the
  opposite-L0 recentre (`Grind_TryRecenterOppositeL0`).
- **T-2 Producer and checker agree.** For the short side, does every
  producer of an exit price (fill, queue release, retry, lattice roll,
  carry pass, eject) use the SAME exit value that I6 checks with, per
  tick and at init? A disagreement halts the instance. Name any pair
  that can differ, and when.
- **T-3 Stale globals.** `g_grind_engine_add_pips_short` and
  `g_grind_recon_exit_pips_short` are set in specific places. Can any
  reader see 0.0 or a stale value (for example a fill processed before
  the first `OnTick`, a path that sets `g_grind_engine_add_pips` but not
  the short twin, a test leaving a value behind)? What does it do then?
- **T-4 Inputs.** Sentinel and validation: MT5's parsing of `-1.0` in a
  `.set` file (can it arrive as -0.99999...?), 0 or negative overrides,
  the order of checks in `OnInit`, and whether any order can be placed
  before validation fails.
- **T-5 Same when symmetric.** With all six at -1 (every existing
  preset), is the behaviour identical to `main` in every path, including
  reporting? Any path where `Grind_SidePips(false, x, 0.0)` or the wiring
  can differ from `x`?
- **T-6 Reporting.** The heartbeat `StringFormat` (count and order of
  specifiers against arguments), the INIT and DEINIT JSON (commas, key
  names), the config dump: can any produce invalid JSON or wrong values?
- **T-7 Tests.** Which v2.0 behaviour has no test that fails without it?
  Does any assertion in `fxgrind_tests_gv.mqh` pass vacuously (inside an
  `if`, on leftover state, on a fixture that never reaches the code)?
  Note: GV10 first runs two ticks on a flat book, so the short side has
  a resting L0 when its layer is seeded; the engine cancels it as a
  stray (`STRAY_L0_CANCEL`) before placing the add. Does that setup
  weaken the test?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G5), `T-1` ... `T-7`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` and to deploy with every value
inherited; and with asymmetric presets), `TEST GAPS`. No preamble. If
you assume a value (an MT5 behaviour, an order of events), say ASSUMED
and why.

Line count: 142
