This message has a line count at the bottom.

# DeepSeek -- Pre-implementation audit of the ADR-151 Phase A Cursor spec
# Appended below by the runner: ADR-151, the Cursor spec, and the EA source it edits.

## Role
Red team auditing a SPEC before Cursor implements it tonight on a live demo
fleet. Write ZERO code. Find what in the spec is wrong, missing, or would halt
or corrupt the fleet when deployed. You find; you do not rule.

## Frame
fxgrind: passive limit-order market maker, MT5, 14 instances on one FTMO demo
account (hedging), limit 200 positions + pending orders. Never crosses the
spread, no stop losses. Invariants rebuild the book from broker tickets every
tick; failure quarantines (3000 ms, 3 checks) or halts immediately if not
quarantinable. The design (exit queue K=2, H=1; commitment guard margin 4;
fleet GV lock; trim before protect; halt cancels entries) has survived three of
your teardowns and a Gemini ruling. Do NOT re-litigate the design. Audit the
SPEC against the SOURCE.

## Deployment context (attack this path hardest)
Tonight's book is ~200/200 with every exit resting (legacy). Instances will be
recompiled and reinitialised one at a time on that book. Some instances are
halted with naked layers; others running.

## Audit these
A1 ANCHORS. Every function, line anchor and call site the spec names: exists?
   Any call site of a changed function the spec misses (e.g. other callers of
   `Grind_ReconCheckInvariants`, `Grind_TryPlaceExitForLayer`,
   `Grind_RetryMissingExits`, `Grind_CarryShiftGetValidated`)?
A2 SEQUENCING. OnInit (6a, 6b, 6e), OnTick halt/quarantine branches (6c, 6d),
   engine order (4g), deal handler (4d, 4e). Any order that places before it
   trims, cancels an exit it needs, or double-places?
A3 DEPLOY ON A LEGACY FULL BOOK. Reinit one instance at 200/200: walk OnInit
   trim, first ticks, peers still on the old build (they place entries without
   the guard). Can the new instance halt? Can it make an old-build peer halt?
A4 MIXED FLEET. While some instances run the old build, do shared GVs (lock,
   shift, release marker, prune) or the new resting_ent count cause harm?
A5 CONSERVATION AND GUARD. Any engine send path that bypasses 4c/4h
   (recentre modify is fine; any PENDING send is not)?
A6 HOLD-CANCEL (4b). Deal lookup correctness in live MT5 (HistorySelect
   window, DEAL_ORDER on the IN deal, hedging), and in the test seam.
A7 RECON (5a-5d). Rank arrays through every caller; I3/I1/I6 gating; any
   invariant now silently weakened beyond ADR-151 decision 7.
A8 CARRY (3a-3c). Prune fix correctness; marker skip; any path deleting a
   live peer's GV.
A9 LOCK (2d). CAS semantics with doubles, token equality, GetTickCount64
   wrap/restart, GlobalVariableTemp lifetime, steal race.
A10 TESTS (s7). Missing tests for any failure you found; tests that cannot
   fail; seams that let a test pass while live code is wrong.

## Output format
Numbered findings. For each:
- SEVERITY: BLOCKER (must fix before implementing) / MAJOR (fix in this
  implementation) / MINOR (note)
- WHERE: spec section and file : function
- WHAT: the defect, with a concrete sequence where behavioural
- FIX: smallest spec change
Then: MISSED CALL SITES (list, or none).
Then: VERDICT -- IMPLEMENT AS WRITTEN / IMPLEMENT AFTER BLOCKER FIXES / DO NOT IMPLEMENT.
Final line: OVERRIDE CHECK -- any finding that should stop deployment tonight?

Line count: 63
