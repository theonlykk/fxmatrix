This message has a line count at the bottom

# ADR-153 FOLLOW-UP -- CLOSE THE IMPLEMENTATION AUDIT

## AUDIT TRAIL

| item | detail | status |
|---|---|---|
| Branch | `feat/adr153-geometry-independence`, head `c9997b2` | reviewed by Claude |
| Audit | `prompts/adr153_impl_deepseek_response.md`, branch `review/adr153-impl-deepseek` at `e469f1f` | findings below |
| Suite | head 1367/1370; the 3 failures (IV5 x2, EF3) also fail on `main` 1351/1354 -- pre-existing, environment-dependent, NOT in scope | verified by operator |

## BRANCH

Work on `feat/adr153-geometry-independence` itself. ONE commit. Push. Do
NOT merge. Do NOT open a PR.

## WHAT TO ADD

### 1. `add > exit` exit-queue test (DeepSeek finding 7)

Claude verified in source: `Grind_ExitQRanks` (`ea/grind_exitq.mqh:84`)
ranks layers by ENTRY price only (`Grind_ExitQEntryBeats`). Every exit
target is `entry +/- exit_pips` with one `exit_pips`, so target order
mirrors entry order whatever `add` is. The test pins that down.

Add `Test_ADR153_AddGreaterThanExitRanks` in `ea/fxgrind_tests.mq5`, called
immediately after `Test_ADR153_OnInitGeometry();`:

- A LONG ladder of three layers built at add 4.0, exit 2.0 pips
  (`add > exit`), entries 1.25000, 1.24960, 1.24920, layer indices 0, 1, 2.
- Call `Grind_ExitQRanks` on those entries.
- Assert: the layer at 1.24920 (the newest, lowest) has rank 0; 1.24960
  rank 1; 1.25000 rank 2.
- Compute each target with `Grind_ExitPrice(entry, 2.0, _Point, 1)` and
  assert the targets are strictly increasing in rank order (rank 0 target
  < rank 1 target < rank 2 target).
- Mirror the whole test for a SHORT ladder (entries 1.25000, 1.25040,
  1.25080; newest is the highest; targets strictly decreasing in rank
  order).

**The two functions take direction in DIFFERENT TYPES. Get this right:**

| function | parameter | long | short |
|---|---|---|---|
| `Grind_ExitQRanks` (`grind_exitq.mqh:84`) | `const bool is_long` | `true` | **`false`** |
| `Grind_ExitPrice` (`grind_pure.mqh:116`) | `const int direction` | `1` | **`-1`** |

**Never pass `-1` to `is_long`.** A non-zero integer coerces to `true`, so
the short ladder would be ranked as long and the assertions would fail for
a reason unrelated to the code under test. If an assertion in this test
fails, check these arguments BEFORE touching anything else, and do not
modify ranking or pricing code to make it pass -- this change touches
tests and the ADR only.

Use the real signatures. If `Grind_ExitQRanks` differs from
`(entries[], layer_indices[], n, is_long, ranks_out[])` or `Grind_ExitPrice`
from `(entry, exit_pips, point, direction)`, STOP and report.

### 2. `stranded <= 0` rejection (audit gap)

In `Test_ADR153_OnInitGeometry`, add:

| id | call | expect |
|---|---|---|
| G6 | `Grind_TestOnInitGeometryCheck(5.0, 10.0, 8, 0.0, 10.0, 4.0, 22260101UL)` | `INIT_FAILED` |
| G7 | `Grind_TestOnInitGeometryCheck(5.0, 10.0, 8, -1.0, 10.0, 4.0, 22260101UL)` | `INIT_FAILED` |

### 3. ADR-153 Decision 4 wording

In `docs/architecture/ADR-153-geometry-independence.md`, replace the
paragraph that begins `` `Grind_TryRecenterOppositeL0` returns early when
the entry stop is active`` through the end of the sentence ending
`before entries are cut.` with exactly:

    `Grind_TryRecenterOppositeL0` returns early when
    `Grind_ApiCounterSoftWarnActive()` -- the 1,800 soft-warn level --
    while entries and adds keep their 1,900 stop. **Required, per Gemini's
    ruling of 2026-09-20:** re-quotes earn nothing, so they must yield to
    entries and adds, leaving a 100-request buffer for revenue-generating
    orders.

Then append one bullet to the `## Review` list:

    - **DeepSeek audited the implementation 2026-09-20**
      (`prompts/adr153_impl_deepseek_response.md`): findings 1-5 and 8-10
      resolved; 6 verified clear by grep across `ea/`; 7 closed by source
      reasoning (ranking is by entry only) plus
      `Test_ADR153_AddGreaterThanExitRanks`. Implementation accepted.

And change the `## Status` block's first line from `Proposed -- 2026-09-20.
Revision 3, same day.` to `Accepted -- 2026-09-20. Revision 3, same day.`

## NEGATIVE SPACE

- Do NOT touch any `.mqh` or `fxgrind.mq5`. Tests and the ADR only.
- Do NOT touch IV5 or EF3. They are pre-existing and out of scope.
- Do NOT CLI compile, launch MetaTrader or deploy.
- Stage by exact path. No merge, no PR. ASCII only.

## RESPONSE FORMAT

Append a section `## Follow-up commit` to
`prompts/adr153_implementation_response.md` with the new commit hash AS IT
EXISTS ON ORIGIN and the diff stat for that commit. Update that file's
footer so it states the TRUE line count (the existing footer is wrong --
it says 52; count the file). Also correct its commit-3 hash from
`ceb8c31` to the actual `c9997b2`.

Reply in chat with ONLY: the branch name, the new hash on origin, and one
line saying it is pushed.

## AFTER CURSOR (operator)

Compile and run the suite on the branch head. Expect 1367 + the new
assertions passing, with exactly the same 3 pre-existing failures.

Line count: 118
