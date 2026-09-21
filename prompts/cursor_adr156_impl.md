This message has a line count at the bottom

# CURSOR -- ADR-156 STARTUP EXIT SHORTFALL (C2), TESTS FIRST -- REV 2

**Gemini has ruled (folded into this rev). Do not start until the
operator says the DeepSeek audit is in.** If DeepSeek amends the design,
the operator will say so and this spec will be revised. Do not guess at
amendments.

## AUDIT TRAIL

| item | where | status |
|---|---|---|
| Design | `docs/architecture/ADR-156-startup-exit-shortfall.md` | Proposed |
| Startup halt with no retry | `ea/fxgrind.mq5:175-180` | verified by Claude at `5124bd2` |
| I3 coverage sites (4) | `ea/grind_recon.mqh:493-497`, `:520-524`, `:1033-1043`, `:1050-1060` | verified |
| Forward declaration | `ea/fxgrind_tests_adr151.mqh:34` declares `Grind_ReconCheckInvariants` | verified; must stay consistent |
| Fixture pattern | `Test_T49_InvariantRestingExtOrderPasses`, `ea/fxgrind_tests.mq5` ~2683 | use as the model |

## SETUP

1. `git fetch origin && git checkout main && git pull --ff-only`
2. `git log --oneline -1` -- report the SHA.
3. `git checkout -b adr156-startup-shortfall`
4. `git branch --show-current` before EVERY commit. It must print
   `adr156-startup-shortfall`.
5. **Commit 0 (docs).** The operator has saved rev 2 of
   `docs/architecture/ADR-156-startup-exit-shortfall.md`, rev 2 of this
   file (`prompts/cursor_adr156_impl.md`), and
   `prompts/gemini_adr156_ruling.md`. For each one, check line 1 and the
   `Line count:` footer against a mechanical count (STOP on mismatch).
   Then commit
   ONLY the ones that differ from `origin/main`, by explicit path, with
   message `ADR-156 rev 2 (Gemini ruling) + impl spec rev 2`. If none
   differ, skip commit 0 and say so.

## COMMIT 1 -- STUBS AND TESTS ONLY

**Stub (no behaviour change):**
- Add `const bool tolerate_exit_shortfall = false` as the LAST parameter of
  `Grind_RebuildBookFromTicketsInner`, `Grind_RebuildBookFromTickets` and
  `Grind_ReconCheckInvariants`. The outer function passes it to the inner
  function, and the inner function passes it to CheckInvariants. The
  parameter is IGNORED in this commit.
- Update the forward declaration at `ea/fxgrind_tests_adr151.mqh:34` to
  match. If MQL5 rejects a default value in both the declaration and the
  definition, put the default ONLY where the compiler requires it and
  report which.
- Add `int g_grind_recon_exit_shortfall_long = 0;` and
  `int g_grind_recon_exit_shortfall_short = 0;` beside the other
  `g_grind_recon_*` globals in `grind_recon.mqh`. They are never written
  in this commit.
- Add a pure helper to `ea/grind_pure.mqh`:
  `bool Grind_StartupShortfallCritical(const int long_n, const int short_n)`.
  The stub body is `return false;`.

**Tests** -- add to `ea/fxgrind_tests.mq5`, register them in the run list.
At the start of each test, call `Grind_TestClearCarryState()` (added in
`29df88f`), then set both
per-side shortfall globals to 0. A leftover carry shift for ticket
1001 would move the formula target.

Constants: magic 22260101, slot "OPT", exit_pips 3.0, max_layers 12,
point 0.00001. Tickets: ENT positions 1001+, EXT orders 2001+. Build them
like T49, with `GrindCommentBuild("OPT", side, layer, role)`.

Long book: L0 1.25000, L1 1.24900, L2 1.24800 (ENT positions, layer
indices 0, 1, 2). EXT orders at entry + 0.00030: L0 1.25030, L1 1.24930,
L2 1.24830.
Short book: S0 1.25000, S1 1.25100, S2 1.25200. EXT at entry - 0.00030:
S0 1.24970, S2 1.25170.

| test | tickets | call | assert |
|---|---|---|---|
| `Test_X1_BarbellCoveredStrictOk` | L0, L1, L2 + EXT L2, EXT L0 | 10-arg | returns true; long 0, short 0 |
| `Test_X2_DeepestMissingStrictFails` | L0, L1, L2 + EXT L2 | 10-arg | false; reason `I3_LONG_NAKED` |
| `Test_X3_DeepestMissingTolerantOk` | same as X2 | `true` | true; long 1, short 0; layer_index 0 has `exit_target` within 1e-9 of 1.25030 and `exit_order_ticket == 0` |
| `Test_X4_RollBookTolerantOk` | L1, L2 + EXT L2 (L0 closed by a roll) | 10-arg, then `true` | strict: false, `I3_LONG_NAKED`; tolerant: true, long 1, short 0 |
| `Test_X5_ShortDeepestMissingTolerantOk` | S0, S1, S2 + EXT S2 | `true` | true; long 0, short 1; layer_index 0 `exit_target` within 1e-9 of 1.24970 |
| `Test_X6_ShortfallCountsBothSides` | L0, L1, L2 (no EXT) + S0, S1, S2 + EXT S2 | `true` | true; long 2, short 1 |
| `Test_X7_TolerantStillFailsI6` | X1 but EXT L0 priced 1.25040 | `true` | false; reason `I6_LONG_EXIT` |
| `Test_X8_TolerantStillFailsI4` | X1 + EXT order for layer 5, no position | `true` | false; reason `I4_LONG_ORPHAN_EXIT` |
| `Test_X9_DefaultIsStrict` | same as X2 | 10-arg | false; reason `I3_LONG_NAKED` (locks the OnTick path) |
| `Test_X10_ShortfallCriticalHelper` | none (pure), then X6, X3, X4 books tolerant | helper | (2,1) true; (0,2) true; (1,1) false; (1,0) false; (0,0) false; helper on X6's per-side counts true, on X3's false, on X4's false |

Find each layer in the output by `layer_index`, not by array position.
For each shortfall value, write the hand derivation in a comment above
the assert. Example: "X6: long ranks 0 and 2 required, both uncovered =
2; short rank 2 uncovered = 1."

**Commit 1 message:** `ADR-156 tests and stubs (X3-X6, X10 true cases expected to fail)`

**Expected against the stub:** X3, X4 (tolerant half), X5, X6, and X10's
TRUE cases (the pure (2,1) and (0,2), and the one on X6's counts) FAIL.
X1, X2, X7, X8, X9 and X10's FALSE cases PASS; these are regression locks,
so report them as passing in both states. If X1's shortfall asserts fail,
or any of the expected failures passes against the stub, STOP and
report.

## COMMIT 2 -- IMPLEMENTATION

1. At the start of `Grind_RebuildBookFromTicketsInner`, set both
   per-side shortfall globals to 0.
2. At the two Inner sites (`:1033-1043`, `:1050-1060`): if the
   `has_position && Required && !coverage` condition holds and
   `tolerate_exit_shortfall` is true, increment that SIDE's shortfall and
   `continue` past the I3 return. The I4 check later in the same loop
   body needs `!has_position`, so it cannot apply to this iteration and
   `continue` is safe. Confirm that by reading the code, and say so in
   the report.
3. At the two CheckInvariants sites (`:493-497`, `:520-524`): if tolerant,
   skip only the `no_exit_coverage` return. Do NOT increment here. The
   I6 block below already `continue`s for uncovered layers; leave it as
   it is.
4. In `Grind_ReconstructState()`, pass `true` to the rebuild. Do not
   change `Grind_CheckBookInvariants()`.
5. In `OnInit`, inside the existing `else` branch at `fxgrind.mq5:178`,
   BEFORE `Grind_RetryMissingExits`, with `a` = long and `b` = short
   shortfall:
   - if `a + b > 0`: `Print` one line
     `WARN STARTUP_EXIT_SHORTFALL long=<a> short=<b>` and call
     `Grind_ArchiveMarker("WARN", "STARTUP_EXIT_SHORTFALL", "", 0, StringFormat("{\"long\":%d,\"short\":%d}", a, b))`.
     Check the signature at `grind_archive.mqh:535`. If it differs, STOP.
   - if `Grind_StartupShortfallCritical(a, b)`: also call
     `Grind_TelemetryCritical(g_grind_telemetry_instance, "STARTUP_EXIT_SHORTFALL_SIDE", StringFormat("long=%d short=%d", a, b))`.
     Do NOT set `g_grind_halted` or `g_grind_halt_reason`. **No halt**
     (Gemini ruling).
6. Implement the helper: `return (long_n >= 2 || short_n >= 2);`

**Commit 2 message:** `ADR-156: startup tolerates exit shortfall, retry places, OnTick stays strict`

## NEGATIVE SPACE

- Do NOT return `INIT_FAILED` or halt on a shortfall.
- Do NOT change `Grind_ExitQRequired`, the quarantine constants or the
  quarantinable list, `Grind_CheckBookInvariants`, the halt path, or any
  I1/I2/I4-I8 check.
- Do NOT add inputs, and do not touch presets, pipshed, the runbooks or
  handoffs.
- Do NOT deploy, do NOT CLI compile, do NOT launch MetaTrader, do NOT run
  the suite. The operator compiles in MetaEditor and runs the suite; the
  suite figure is pending until they do.
- Do NOT `git stash`, check out files from other commits, merge, open a
  PR, or use `git add .` / `git add -u`. Add files by explicit path.
- Do NOT amend commits. If something needs fixing, make a new commit.

## FAILURE MODES -- STOP AND REPORT

- Any of the four I3 sites is not where the audit trail says (source
  drifted).
- The Inner loop body does not match the description in step 2 (for
  example, a check after I3 that could apply to a layer with a
  position).
- The forward-declaration default causes a conflict you cannot resolve
  by the rule above.
- Any existing test would need its expected value changed. Never adjust
  an expected value.

## FINAL REPORT (fixed format)

```
BRANCH: <git branch --show-current>
BASE:   <sha>
COMMIT1: <sha from git log, not memory>  files: <list>
COMMIT2: <sha from git log>              files: <list>
PUSHED: <git ls-remote origin adr156-startup-shortfall>
LINES:  <wc -l of every changed file>
DIFF:   <git diff --stat origin/main..adr156-startup-shortfall>
COMMIT0: <sha or SKIPPED>                files: <list>
STUB-STATE EXPECTATION: X3,X4b,X5,X6,X10-true fail; X1,X2,X4a,X7,X8,X9,X10-false pass (not run)
DEVIATIONS: <none, or each one with reason>
```

Line count: 174
