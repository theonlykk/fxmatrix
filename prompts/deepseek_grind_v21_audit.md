This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM GRIND V2.1: REBUILD AT START (ADR-163)

You are auditing a feature branch BEFORE it merges to `main`. It is
tested on GBPUSD and EURUSD: stubs and tests (`bc16f0d`) 2187/2218,
failing exactly the 31 predicted; the implementation (`fbd3227`)
2218/2218. Find what tests cannot see. The attached files carry NO line
numbers: cite `file`, `function` and QUOTE the line (one line, or part
of one). A claim without a quote is discarded. Line numbers below are
ours, for orientation (at `fbd3227`).

**The system:** an MQL5 passive limit-order FX market maker (no stops,
no market orders, hedging account, 0.01 lots, cap 8 layers per side).
Eleven instances per terminal share global variables (GVs). Each
layer's exit rests at `ExitPrice(effective entry, exit) + carry accrual
+ eject offset`, plus a clamp SHIFT (with a release marker) when it had
to be moved passive. The exit queue (ADR-151, K=1, H=0) keeps only rank 0
and the highest rank resting; the others are held (no order). I6 checks
each resting exit against that formula within 2 points at init
(`Grind_ReconstructState`) and every tick (`Grind_CheckBookInvariants`,
strict); a failure quarantines, then halts. A lattice roll (ADR-162)
stores a virtual level (VL) that becomes the effective entry; a
commanded eject moves the deepest exit to the market and stores an
offset. v2.0 (on `main`) added per-side width, add and exit inputs.

**Before this branch,** a reattach with a changed EXIT input halted on I6
(the resting exits sat at the old distance). **This branch (v2.1):**
- a label GV per instance and side, `GRIND_GEO_EXIT_<magic>_L/_S`
  (`grind_carry.mqh` ~612-649): the exit the side was last priced for.
  It GATES; it never prices. `Grind_GeoExitChanged` (~635) = label
  present AND different from the current exit.
- `Grind_ReconstructState` (recon ~1281) sets `g_grind_rebuild_long/
  _short` from the labels and passes them to reconstruction; in
  `Grind_ReconCheckInvariants` (~464) a flagged side's I6 PRICE mismatch
  on a RESTING exit is skipped (`continue`); filled exits and the other
  side stay strict; `Grind_CheckBookInvariants` (~1253) never passes the
  flags.
- `Grind_RebuildExitsAtStart` (engine ~2841) and
  `Grind_RebuildExitsAtStartSide` (~2768), called in `OnInit`
  (`fxgrind.mq5` ~268) right after `Grind_RetryMissingExits`: for each
  flagged side, each layer with a resting exit and no exit position:
  an EJECTED layer (offset, no VL) keeps its order and the offset is
  re-derived from the resting price; any other is modified to
  `Grind_ExitQFormulaTarget` (clamped passive; shift recorded or deleted
  as `Grind_ExitQManageSide` does); the first failed modify returns
  false. `OnInit` then halts (`REBUILD_EXIT_FAILED`, entries cancelled,
  labels NOT written) or writes both labels and sets two one-shot flags.
- `Grind_EnsureAddNext` (~2344): the first evaluation after init compares
  the resting add with its target using half a point instead of the
  deadband, then clears the side's flag.

**Ruled -- do not re-open:** rebuild, not delta (the old exit never
prices); the label as a third stored value that only gates (operator,
27 Sep); tolerance only when the label differs, per side (Gemini GR-Q1);
modify in place; halt on the first failed modify; a commanded-eject exit
keeps its price (operator); stored accrual, no ledger read at start; no
one-shot for a resting L0 (it would snap L0 to the mid at every restart,
GR-S1); a clamped resting add may be modified once per restart (GR-S2);
labels written for both sides after every clean init and never after a
halt (GR-S4); `Grind_ReconstructState` and `OnInit` have no broker test
seam (their wiring is read, not unit-tested).

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. With no label for a side, that side's init I6 is exactly as strict
  as before this branch.
- G2. `Grind_CheckBookInvariants` passes no tolerance flag.
- G3. A FILLED exit (`*_exit_filled`) is never tolerated.
- G4. `Grind_RebuildExitsAtStartSide` prices a non-ejected exit with the
  same formula I6 checks (`Grind_ExitQFormulaTarget` + the recorded
  shift).
- G5. Labels are written only when the rebuild returned true.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Tolerance leak.** Any path where the price tolerance applies when
  the label equals the input or is absent, to the other side, to a
  filled exit, or after init? Any mismatch the tolerance lets through
  that the rebuild then does NOT fix (so the first tick halts, or worse,
  the instance trades on it): an exit on a held rank, an exit whose
  order cannot be read (`resting <= 0.0` is skipped), a layer whose exit
  belongs to another layer, an exit of the wrong type?
- **T-2 Rebuild arithmetic.** For each branch (plain, clamped, rolled VL,
  accrued, ejected with and without a shift), is the post-rebuild state
  exactly what `Grind_ReconExitMatchesEntry` accepts at the NEW exit,
  per tick? In the ejected branch the offset uses
  `Grind_CarryShiftGetForRecon`: can it delete or ignore a shift and
  leave I6 inconsistent?
- **T-3 Partial failure and restart.** A failure on the short side after
  the long side succeeded; a failure on the second exit of a side; a
  crash mid-rebuild (GVs flushed within 1 s). Is every next init
  tolerant exactly where needed and able to finish, with no exit moved
  twice and no stale shift or offset?
- **T-4 Label lifecycle.** Flush and survival across restarts, deletion
  by `Grind_CarryPruneShiftGvs` (called after the rebuild in `OnInit`)
  or by any prefix cleanup, the same magic on another account or
  terminal, a label written when a missing exit could not be placed
  (ADR-156 startup shortfall), and an operator who changes the exit and
  restarts twice.
- **T-5 One-shot add.** Can the flag be cleared without the comparison
  (early returns), survive into later ticks, cause more than one modify,
  or interfere with ADR-152's due-flag path or the entry horizon?
- **T-6 `OnInit` ordering.** `Grind_RetryMissingExits` before the rebuild,
  `Grind_CarryPruneShiftGvs` after it, the halt path (entries cancelled,
  timer still set), a reattach inside the carry window, a reattach with
  the market closed (every modify fails: halt). Anything unsafe?
- **T-7 Tests.** Which v2.1 behaviour has no test that fails without it?
  Does any assertion in `fxgrind_tests_rb.mqh` pass vacuously (inside an
  `if`, on leftover state, on a fixture that never reaches the code)?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G5), `T-1` ... `T-7`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` and deploy with unchanged
settings; and safe for the first exit change on a live book), `TEST
GAPS`. No preamble. If you assume a value (an MT5 behaviour, an order of
events), say ASSUMED and why.

Line count: 121
