This message has a line count at the bottom

# F2: Held layers accrue carry -- response

Branch: feat/f2-held-layer-carry (three commits from origin/main at 3b0b853).
InpEnableCarryPass unchanged false; OnInit FATAL guard untouched.

## Commits

1. 443c686 -- F2-1..F2-7 tests + registration (fail on unfixed pass/queue/I6)
2. 1939c8b -- accrued store, pass split, formula target, I6, scalp clear
3. 6cfeffe -- ADR-135b F2 section

## Two-store arithmetic

intended = raw_formula + accrued_carry
actual   = intended or clamped
SHIFT    = actual - intended

I6: raw_formula + accrued_carry + SHIFT == actual

## Grind_ExitQFormulaTarget vs Grind_ReconExitMatchesEntry (terms agree)

Queue (grind_exitq.mqh:233-242):

  accrued = (position_ticket > 0) ? Grind_CarryAccruedGet(position_ticket) : 0.0
  return Grind_ExitPrice(entry, exit_pips, point, is_long ? 1 : -1) + accrued

I6 (grind_recon.mqh:353-364):

  accrued = (position_id > 0) ? Grind_CarryAccruedGet(position_id) : 0.0
  expected = Grind_ExitPrice(entry, exit_pips, point, dir) + accrued + shift

Both add the same raw exit price plus the same accrued GV for the position
ticket, then I6 adds shift for clamp delta. Explicit agreement.

## Pass split (grind_carry.mqh)

PassBegin (767, 775): skip only when position_ticket == 0.

Grind_CarryExitShiftLayer (884-888, 920-924):

  accrued_price = theoretical - formula_exit   // raw formula in work list
  Grind_CarryAccruedSet(position_ticket, accrued_price)
  if(exit_order_ticket == 0)
     return true;   // accrue only; queue owns placement

  ... modify order ...
  intended = formula_exit + accrued_price
  applied_shift = new_exit - intended
  Grind_CarryShiftSet(position_ticket, applied_shift)

## Grind_ExitQFormulaTarget callers (all updated)

| File | Line | position ticket |
|------|------|-----------------|
| ea/grind_engine.mqh | 1835 | side.layers[i].position_ticket |
| ea/grind_recon.mqh | 1095 | long_scratch[j].position_id |
| ea/grind_recon.mqh | 1111 | short_scratch[j].position_id |
| ea/fxgrind_tests_adr151.mqh | 137 | position_ticket (Adr151_TestSetupLongLayer) |
| ea/fxgrind_tests_adr151.mqh | 353 | 7001UL (EQ-CLAMP1) |
| ea/fxgrind_tests_adr151.mqh | 388 | 7002UL (EQ-CLAMP2) |
| ea/fxgrind_tests_adr152.mqh | 515 | 5003UL (T4c short layer) |

No call site lacked a ticket; none pass 0 except implicit default on
Grind_ReconExitMatchesEntry position_id for legacy CX6 direct calls in mq5.

## Hand-derived test expectations

pip price = pips * point * 10. point = 0.00001, exit_pips = 3.0 -> raw delta 0.00030.

F2-1: Three long layers; rank 0 at 1.25000 with exit order; rank 1/2 held
(1.25100, 1.25200) with exit_order_ticket 0. Pass runs in 23:50 window with
POSITION_SWAP -0.10 / vol 0.01. Unfixed: held tickets never enter work list ->
Grind_CarryAccruedGet == 0 FAIL. Fixed: all three tickets get non-zero accrued.

F2-2: entry 1.25000 -> raw 1.25030. Hand accrued 0.00050 (5 pips). intended
1.25080. Quiet market 1.24998/1.25000 -> place at 1.25080, shift 0. Unfixed:
FormulaTarget ignores accrued -> place 1.25030 FAIL; I6 FAIL.

F2-3: Same accrued 0.00050, intended 1.25080. Clamp market ask 1.25100,
min_dist 0.00001 -> actual 1.25101. shift = 1.25101 - 1.25080 = 0.00021 (not
0.00071 = actual - raw). Unfixed: shift stores clamp-only vs raw; I6 uses raw
+ shift without accrued -> FAIL F2-3 shift and I6.

F2-4: No accrued GV -> target raw 1.25030 exactly. PASS unfixed and fixed.

F2-5: Resting layer pass modifies order; accrued non-zero; shift = order price
- (raw + accrued). Unfixed: shift = price - raw FAIL on shift assertion; fixed PASS.

F2-6: Cancel clears shift/release (241a905); accrued hand-set 0.00040 survives.
PASS unfixed and fixed (accrual was never cleared on cancel).

F2-7: Scalp OUT_BY close path. Unfixed: Grind_CarryAccruedDelete not called ->
accrued GV remains FAIL. Fixed: both shift and accrued deleted.

## Expected failures on unfixed code (commit 1 only)

| Test | Result |
|------|--------|
| F2-1 | FAIL held accrued |
| F2-2 | FAIL price, I6 |
| F2-3 | FAIL shift, I6 |
| F2-4 | PASS |
| F2-5 | FAIL shift formula |
| F2-6 | PASS |
| F2-7 | FAIL accrued gone |

## Self-review

- Formula and I6 side by side above; terms agree.
- Pass accrues always; modifies only when exit_order_ticket != 0.
- Scalp close: grind_engine.mqh:1413-1414 ShiftDelete + AccruedDelete.
- Diagnostic stubs removed from adr151; API lives in grind_carry.mqh only.
- InpEnableCarryPass and OnInit guard not touched.

Deleted-assert grep (must be empty):

  git diff origin/main -- ea/fxgrind_tests.mq5 ea/fxgrind_tests_adr151.mqh | grep "^-" | grep -i "Assert\|void Test_"
  (empty)

git diff --stat origin/main...feat/f2-held-layer-carry:

 .../architecture/ADR-135b-carry-exit-adjustment.md |  22 +-
 ea/fxgrind_tests.mq5                               |   7 +
 ea/fxgrind_tests_adr151.mqh                        | 306 ++++++++++++++++++++-
 ea/fxgrind_tests_adr152.mqh                        |   2 +-
 ea/grind_carry.mqh                                 |  39 ++-
 ea/grind_engine.mqh                                |   4 +-
 ea/grind_exitq.mqh                                 |   8 +-
 ea/grind_recon.mqh                                 |  16 +-
 8 files changed, 387 insertions(+), 17 deletions(-)

Line count: 134

## DIAGNOSTIC: F2-5 shift

Operator context: 1315/1316, F2-5 shift only failure. F2-3 passes (carry+clamp).
Hypothesis: Grind_ModifyPendingPrice stores Grind_Normalize(new_price) while
applied_shift uses un-normalised new_exit. Measure only; no fix this commit.

Print inserted immediately before AssertNear("F2-5 shift", ...) in
Test_F2_5_resting_layer_still_works (ea/fxgrind_tests_adr151.mqh):

   const double accrued = Grind_CarryAccruedGet(pos);
   const double intended = raw + accrued;
   Print("F2-5 DIAG raw=", DoubleToString(raw, 8),
         " accrued=", DoubleToString(accrued, 8),
         " intended=", DoubleToString(intended, 8),
         " rec_price=", DoubleToString(rec.price, 8),
         " norm_rec=", DoubleToString(Grind_Normalize(rec.price), 8),
         " stored_shift=", DoubleToString(Grind_CarryShiftGet(pos), 8),
         " expected_shift=", DoubleToString(rec.price - intended, 8),
         " delta=", DoubleToString(Grind_CarryShiftGet(pos) - (rec.price - intended), 10));
   AssertNear("F2-5 shift", Grind_CarryShiftGet(pos), rec.price - intended, 1e-12);

Locals raw, accrued, intended already declared; no new variables. No market
seed added. Assertion unchanged (1e-12). Grind_Normalize reachable via
grind_engine.mqh included from fxgrind_tests.mq5.

Change since bf780bc: one Print in ea/fxgrind_tests_adr151.mqh only. No
production file changed.

Operator: run suite, read F2-5 DIAG line, interpret delta per prompt spec.
Cause not stated here (values not available to agent).

git diff --stat bf780bc..HEAD (diagnostic commit only):

 ea/fxgrind_tests_adr151.mqh            | 8 ++++++++
 prompts/f2_held_layer_carry_response.md | 37 ++++++++++++++++++++++++++++++++

Line count: 172
