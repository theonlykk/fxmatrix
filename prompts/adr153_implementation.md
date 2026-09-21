This message has a line count at the bottom

# IMPLEMENT ADR-153 REV 3 -- GEOMETRY INDEPENDENCE AND THE RECENTRE BUDGET

## AUDIT TRAIL

| item | detail | status |
|---|---|---|
| Decision | `docs/architecture/ADR-153-geometry-independence.md`, rev 3 | fxmatrix `63b98fb` |
| Gemini | approved rev 3 on 2026-09-20; ruled the recentre gate at **1,800** (soft-warn), entries stay at 1,900 | ruling recorded in the ADR by this change |
| DeepSeek | audited rev 2 (`prompts/adr153_deepseek_response.md`); findings 1-10 dispositioned in the ADR. **The implementation branch is audited again before merge** | pending |
| Baseline | fxmatrix `origin/main` at `63b98fb` | read by Claude |
| Suite | 1354/1354 at `605bc85`; operator-run | baseline |

## BRANCH

`feat/adr153-geometry-independence` from `origin/main`. Three commits, in
this order. Push. Do NOT merge. Do NOT open a PR.

1. **Tests and stubs.** The new tests MUST fail against this commit.
2. **Implementation.** All tests pass. No test file edited.
3. **Response document** plus the ADR status line.

## CONTEXT -- VERIFIED IN SOURCE AT 63b98fb

- `ea/grind_pure.mqh:9` `#define GRIND_ADD_WIDTH_MULTIPLE 2.0`.
- `ea/grind_pure.mqh:20` `Grind_ValidateGeometryInputs(width, exit,
  max_layers, stranded, add)` already rejects each of those `<= 0`. Keep it.
- `ea/grind_pure.mqh:40` `Grind_ValidateAddWidthRelationship` -- exact
  equality to 1e-8. **To be removed.**
- `ea/grind_pure.mqh:47` `Grind_TestOnInitGeometryCheck(width, exit,
  max_layers, stranded, add, magic)` -- calls only
  `Grind_ValidateGeometryInputs` and the magic check. It never reaches the
  add/width check (DeepSeek finding 8).
- `ea/fxgrind.mq5:113-123` `OnInit` calls both validators; the second
  prints a message naming `GRIND_ADD_WIDTH_MULTIPLE`.
- `ea/grind_engine.mqh:1482` `Grind_TryRecenterOppositeL0(...)`. At
  `:1498` it reads the resting price with the raw
  `OrderGetDouble(ORDER_PRICE_OPEN)`, which returns 0.0 under the order-test
  harness. `Grind_OrderGetPriceOpen(ticket)` at `:348` serves test records
  (DeepSeek finding 5).
- **Consequence you must understand:** the existing
  `Test_PO4_RecenterOppositeL0StillWorks` (`fxgrind_tests.mq5:5944`) PASSES
  TODAY FOR THE WRONG REASON. The raw call returns 0.0, the distance from
  mid is enormous, so the recentre fires regardless of the real resting
  price. Any test that expects NO recentre will fail until `:1498` is
  switched.
- `ea/grind_api_counter.mqh:14` `#define GRIND_DAILY_API_SOFT_WARN 1800`;
  `Grind_ApiCounterSoftWarnActive()` at `:120` returns
  `Grind_ApiCounterRead() >= GRIND_DAILY_API_SOFT_WARN`, and
  `Grind_ApiCounterRead()` already calls `Grind_ApiCounterMaybeReset()`.
- Tests seed the counter with `Grind_ApiCounterTestSeed(n)` and reset with
  `Adr152_TestResetAll()` (see `fxgrind_tests_adr152.mqh:290-310`).
- `Test_T17_AddWidthRelationship` (`fxgrind_tests.mq5:257`, called at
  `:6310`) asserts the old equality.

## DESIGN

### D1. `ea/grind_pure.mqh`

- Delete `GRIND_ADD_WIDTH_MULTIPLE` and `Grind_ValidateAddWidthRelationship`.
- Add:

      #define GRIND_ADD_WIDTH_RATIO_MIN 0.5
      #define GRIND_ADD_WIDTH_RATIO_MAX 4.0

      bool Grind_ValidateAddWidthRatio(const double width_pips,
                                       const double add_pips)
      {
         if(width_pips <= 0.0 || add_pips <= 0.0)
            return false;
         const double r = add_pips / width_pips;
         if(r < GRIND_ADD_WIDTH_RATIO_MIN - 1e-9)
            return false;
         if(r > GRIND_ADD_WIDTH_RATIO_MAX + 1e-9)
            return false;
         return true;
      }

      bool Grind_ValidateDeadband(const double deadband_pips)
      {
         return (deadband_pips >= 0.0);
      }

- Extend `Grind_TestOnInitGeometryCheck` with a `const double
  deadband_pips` parameter placed BEFORE `magic`, and make it call, in
  order: `Grind_ValidateGeometryInputs`, `Grind_ValidateAddWidthRatio`,
  `Grind_ValidateDeadband`, then the magic check. It must reject exactly
  what `OnInit` rejects.
- **No check relating `stranded` to `width` or `deadband`.** ADR-153 rev 3
  removes it deliberately. Do not add one.

### D2. `ea/fxgrind.mq5` `OnInit`

Replace the `Grind_ValidateAddWidthRelationship` block with:

    if(!Grind_ValidateAddWidthRatio(InpWidthPips, InpAddPips)) {
       Print("FATAL: InpAddPips / InpWidthPips = ", InpAddPips / InpWidthPips,
             " is outside [", GRIND_ADD_WIDTH_RATIO_MIN, ", ",
             GRIND_ADD_WIDTH_RATIO_MAX, "] -- typo guard, ADR-153");
       return INIT_FAILED;
    }
    if(!Grind_ValidateDeadband(InpDeadbandPips)) {
       Print("FATAL: InpDeadbandPips must be >= 0");
       return INIT_FAILED;
    }

Placed immediately after the existing `Grind_ValidateGeometryInputs`
block. Nothing else in `OnInit` changes.

### D3. `ea/grind_engine.mqh` `Grind_TryRecenterOppositeL0`

Two changes, nothing else:

1. **API gate**, immediately after the existing depth check
   (`if(Grind_SideDepth(opposite_side) != 0) return;`):

       if(Grind_ApiCounterSoftWarnActive())
          return;

   Re-quotes yield at 1,800; entries and adds keep their 1,900 stop
   (Gemini ruling). Do NOT touch the five existing
   `Grind_ApiCounterEntryStopped()` call sites.
2. **Price read.** Replace

       const double resting = OrderGetDouble(ORDER_PRICE_OPEN);

   with

       const double resting = Grind_OrderGetPriceOpen(opposite_side.l0_pending_ticket);

   Keep the `Grind_SelectOurOrder` call above it unchanged.

### D4. Tests -- `ea/fxgrind_tests.mq5`, all in COMMIT 1

Commit 1 adds STUBS in `grind_pure.mqh` so the file compiles:
`Grind_ValidateAddWidthRatio` and `Grind_ValidateDeadband` each `return
false;`, and the extended `Grind_TestOnInitGeometryCheck` signature WITHOUT
the new calls. Commit 1 does NOT touch `grind_engine.mqh` or `fxgrind.mq5`.

Replace `Test_T17_AddWidthRelationship` (keep the name, keep the call at
`:6310`):

| id | call | expect |
|---|---|---|
| T17a | `Grind_ValidateAddWidthRatio(10.0, 4.9)` | false (0.49) |
| T17b | `Grind_ValidateAddWidthRatio(10.0, 5.0)` | true (0.5) |
| T17c | `Grind_ValidateAddWidthRatio(5.0, 10.0)` | true (2.0) |
| T17d | `Grind_ValidateAddWidthRatio(5.0, 20.0)` | true (4.0) |
| T17e | `Grind_ValidateAddWidthRatio(5.0, 20.05)` | false (4.01) |
| T17f | `Grind_ValidateAddWidthRatio(5.0, 4.0)` | true (cycle-3 geometry) |
| T17g | `Grind_ValidateDeadband(0.0)` | true |
| T17h | `Grind_ValidateDeadband(-1.0)` | false |
| T17i | `Grind_ValidateDeadband(4.0)` | true |

Add `Test_ADR153_OnInitGeometry`, called beside T17:

| id | `Grind_TestOnInitGeometryCheck(width, exit, max_layers, stranded, add, deadband, magic)` | expect |
|---|---|---|
| G1 | `(5.0, 10.0, 8, 10.0, 20.05, 4.0, 22260101UL)` | `INIT_FAILED` (ratio) |
| G2 | `(5.0, 10.0, 8, 10.0, 4.0, 4.0, 22260101UL)` | `INIT_SUCCEEDED` (cycle 3) |
| G3 | `(5.0, 10.0, 8, 5.0, 10.0, 6.0, 22260101UL)` | `INIT_SUCCEEDED` (stranded = width: the live design must be expressible) |
| G4 | `(5.0, 10.0, 8, 10.0, 10.0, -1.0, 22260101UL)` | `INIT_FAILED` (deadband) |
| G5 | `(3.0, 8.0, 8, 6.0, 6.0, 4.0, 22260101UL)` | `INIT_SUCCEEDED` (EURGBP's live preset: no floor) |

Update the TWO existing `Grind_TestOnInitGeometryCheck` calls in T11
(`fxgrind_tests.mq5:213` and `:214`) to pass `4.0` as the new deadband
argument. Their expectations do not change. Those are the only two call
sites in the repo; if you find more, STOP.

Add two recentre tests beside `Test_PO4_RecenterOppositeL0StillWorks`,
using its exact setup pattern (order-test records, `Grind_TestSetupLongDepth1`,
short L0 at ticket 6001, width 5.0, stranded 10.0, deadband 4.0):

| id | setup | expect |
|---|---|---|
| PO4b | short L0 resting at exactly `Grind_StraddleSellPrice(mid, 5.0, _Point)` -- freshly placed, not stranded | `g_grind_order_test_modify_calls == 0` |
| PO4c | as PO4 (stranded, 1.26050) but `Grind_ApiCounterTestSeed(GRIND_DAILY_API_SOFT_WARN)` first; reset with `Adr152_TestResetAll()` after | `g_grind_order_test_modify_calls == 0` |
| PO4d | as PO4c but seed `GRIND_DAILY_API_SOFT_WARN - 1` | `g_grind_order_test_modify_calls == 1` |

Call PO4b, PO4c, PO4d immediately after the PO4 call at `:6460`.

**Required failure pattern at commit 1:** T17a-i, G1, G4 and PO4b, PO4c
FAIL. G2, G3, G5 and PO4d may pass (they are regressions, not the change).
PO4 itself still passes. **If PO4b or PO4c PASSES at commit 1, STOP** --
the test is not exercising the recentre, and the harness is the reason
(see CONTEXT).

## NEGATIVE SPACE

- Do NOT change any preset. ADR-153 rev 3 forces no preset change.
- Do NOT touch the five `Grind_ApiCounterEntryStopped()` call sites or
  either API constant.
- Do NOT add any check relating stranded to width or deadband.
- Do NOT touch `grind_recon.mqh`, `grind_exitq.mqh`, `grind_cap.mqh`,
  `grind_state.mqh`, carry, telemetry, or any invariant.
- Do NOT edit any test file in commit 2. If commit 2 needs a test change,
  STOP and report which and why.
- Do NOT CLI compile or trust CLI output. Do NOT launch MetaTrader. Do NOT
  deploy. The operator compiles in the GUI and runs the suite.
- No `git add .` / `-u`; stage by exact path. No stash, no merge, no PR.
- ASCII only.

## FAILURE MODES -- STOP AND REPORT

- `Grind_OrderGetPriceOpen` is not visible from `grind_engine.mqh` at the
  point of use (include order): STOP, report, do not reorder includes.
- `Grind_ApiCounterSoftWarnActive` is not visible from `grind_engine.mqh`:
  STOP, report.
- Any other file references `GRIND_ADD_WIDTH_MULTIPLE` or
  `Grind_ValidateAddWidthRelationship`: STOP and list them. DeepSeek found
  none outside the validator and `OnInit`; if that was wrong, the scope is
  wrong.
- Any existing test other than T11 and T17 needs changing: STOP.

## SELF-REVIEW

Before each commit re-read the full diff. Grep the final tree for
`GRIND_ADD_WIDTH_MULTIPLE` and `ValidateAddWidthRelationship` -- zero hits.
Grep `grind_engine.mqh` for `OrderGetDouble(ORDER_PRICE_OPEN)` inside
`Grind_TryRecenterOppositeL0` -- zero hits.

## RESPONSE FORMAT

Commit 3 updates the ADR `## Status` block's last line to read
`Gemini approved rev 3; recentre gate at 1,800 per his ruling.
Implementation on feat/adr153-geometry-independence; DeepSeek audit of the
branch pending.` -- that line only.

Write `prompts/adr153_implementation_response.md`: the three commit hashes
AS THEY EXIST ON ORIGIN, `git diff --stat
origin/main...feat/adr153-geometry-independence`, the self-review greps
with their output, and the list of tests you expect to fail at commit 1.
Open with `This message has a line count at the bottom` and close with
`Line count: N`.

Push. Reply in chat with ONLY: the branch name, the three hashes on origin,
and one line saying the report is pushed.

## AFTER CURSOR (operator)

1. Check out commit 1, GUI compile `fxgrind_tests.mq5`, run it, record
   which tests fail. They must match the required failure pattern.
2. Check out the branch head, compile, run. All pass; record the total.
3. Then DeepSeek audits the branch diff before anything merges.

Line count: 247
