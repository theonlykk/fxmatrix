This message has a line count at the bottom

# CURSOR -- ADR-155 PART A: EJECT OFFSET PLUMBING (C15), TESTS FIRST

**Part A of two.** This adds the `GRIND_EJECT_OFFSET_<position>` state and
wires every place that must read, delete or prune it. **It adds no command
and no way to create an offset**, so with no offset in existence every read
is 0.0 and behaviour is unchanged. Part B (the `grind_eject` command,
validation, telemetry, the input switch) comes after this is merged.

Design: `docs/architecture/ADR-155-commanded-passive-ejection.md` rev 3
(Gemini ruled; DeepSeek audited, `prompts/adr155_deepseek_response.md`).
Spec reviewed by Gemini 2026-09-22: approved, with the append-path patch
(step 9) and test Y14 added.
Do not re-decide anything in it. If something there cannot be implemented
as written, STOP and report.

## AUDIT TRAIL (verified by Claude at `main` `6d1ecfa`)

| what | where |
|---|---|
| Formula target (reads accrued) | `Grind_ExitQFormulaTarget`, `grind_exitq.mqh:241-251` |
| I6 check (reads accrued + shift) | `Grind_ReconExitMatchesEntry`, `grind_recon.mqh:355-372` |
| I6 detail (omits accrued -- pre-existing bug) | `Grind_InvariantDetailI6`, `grind_recon.mqh:120-128`; callers `:513`, `:543` |
| Carry pass builds work items from the RAW formula | `Grind_CarryExitPassBegin`, `grind_carry.mqh:778-808`; the two `Grind_ExitPrice(...)` lines at `:796` and `:804` |
| Carry shift applies accrual to that base | `Grind_CarryExitShiftLayer`, `grind_carry.mqh:838-940`: theoretical = base shifted by accrued, then clamp, then the clamp delta is stored as the carry shift |
| Work-item arrays a test can read | `g_grind_carry_exit_work_formula[]` and friends, `grind_carry.mqh:61-66` |
| Sign guard | `Grind_CarrySignGuardBlocks`, `grind_carry.mqh:425-432`; called once, at `:890` |
| Accrual written BEFORE the guard and the modify | `Grind_CarryAccruedSet` at `grind_carry.mqh:885`; guard return `:890-899`; modify-fail return `:918-922` |
| Plain I6 is not quarantinable | `grind_quarantine.mqh:37` (I3) and `:41` (I6 FILL_ADVERSE only); OnTick halts on the rest, `fxgrind.mq5:282-292` |
| Delete on layer close | beside `Grind_CarryAccruedDelete`, `grind_engine.mqh:1408` |
| Prune orphans | `Grind_CarryPruneShiftGvs`, `grind_carry.mqh:813` |
| GV helper pattern to mirror | `Grind_CarryShiftGet/Set/Delete`, `grind_carry.mqh:481-512` |
| Clean-ups | `scripts/grind_gv_clean.mq5:27-43`; `Grind_TestClearCarryState`, `fxgrind_tests.mq5:2437` |
| Scratch layer's ticket field | `GrindReconLayerScratch.position_id`, `grind_recon.mqh:54` |
| Append on fill, raw formula (9th site, Gemini) | `Grind_AppendLayer`, `grind_engine.mqh:873-890`, target set at `:888`; called from `:1436` and from tests at `fxgrind_tests.mq5:3929` |

## COMMIT 0 -- AMEND ADR-155 TO REV 4 (docs)

In `docs/architecture/ADR-155-commanded-passive-ejection.md`, line 91 is a
table row that starts with the two carry function names and says the carry
pass bypasses the formula. Replace THAT WHOLE LINE with this one line:

    | `Grind_CarryExitPassBegin` (`grind_carry.mqh:796`, `:804`) | builds each work item from the RAW formula, so the first rollover after an ejection would move the exit back to formula + accrued and wipe the ejection | **build the work item from `raw + eject offset`.** Do NOT skip ejected layers (rev 4, 2026-09-22): carry is a real cost on every open layer, so an ejected exit must drift with the swap it pays like any other; freezing it would leave an exit that no longer covers its funding. `Grind_CarryExitShiftLayer` is unchanged -- it adds accrual to whatever base it is given |

Then in the Status block (lines 5-9), after the sentence ending
`bypasses the formula.`, insert:

    Rev 4 after the operator (2026-09-22): the carry pass INCLUDES ejected
    layers, base = raw + offset, replacing rev 3's skip.

The file has no `Line count:` footer; add none.

Commit 0 message: `ADR-155 rev 4: carry pass includes ejected layers (base = raw + offset)`

## SETUP

1. `git fetch origin && git checkout main && git pull --ff-only`;
   `git log --oneline -1` -- report it.
2. `git checkout -b adr155-eject-offset`
3. `git branch --show-current` before EVERY commit.

## COMMIT 1 -- STUBS AND TESTS ONLY

**Stubs** -- put the helpers in `ea/grind_carry.mqh`, directly after
`Grind_CarryShiftDelete` (`:506-512`), so no include order changes:

    string Grind_EjectOffsetName(const ulong position_ticket)   // "GRIND_EJECT_OFFSET_" + ticket
    double Grind_EjectOffsetGet(const ulong position_ticket)    // stub: return 0.0;
    void   Grind_EjectOffsetSet(const ulong position_ticket, const double offset_price)  // stub: empty
    void   Grind_EjectOffsetDelete(const ulong position_ticket) // stub: empty
    bool   Grind_EjectIsEjected(const ulong position_ticket)    // stub: return false;

`Grind_EjectOffsetName` is REAL in this commit (the tests need it); the
other four are stubs. Mirror `Grind_CarryShiftGet/Set/Delete` exactly for
GlobalVariable handling.

**Tests** -- add to `ea/fxgrind_tests.mq5`, register them, and call
`Grind_TestClearCarryState()` at the start of each. Constants: entry
1.25000 long / 1.25000 short, exit_pips 3.0, point 0.00001, ticket 1001.
Long formula 1.25030, short formula 1.24970. Compare prices within 1e-9.

| test | set up | assert |
|---|---|---|
| `Test_Y1_NoOffsetUnchanged` | nothing | `Grind_ExitQFormulaTarget(1.25000, 3.0, 0.00001, true, 1001)` == 1.25030 |
| `Test_Y2_OffsetAddedToFormula` | offset 1001 = +0.00040 | == 1.25070 |
| `Test_Y3_OffsetAndAccrued` | offset +0.00040, accrued +0.00010 | == 1.25080 |
| `Test_Y4_ShortOffset` | offset 1001 = -0.00040 | short target == 1.24930 |
| `Test_Y5_I6AcceptsEjectedExit` | offset +0.00040 | `Grind_ReconExitMatchesEntry(1.25000, 1.25070, 3.0, 0.00001, true, 0.0, false, 1001)` true; with NO offset the same call is false |
| `Test_Y6_I6ShortEjected` | offset -0.00040 | short mirror: exit_target 1.24930 true |
| `Test_Y7_EjectIsEjected` | offset 0.0 then +0.00040 then delete | false, true, false |
| `Test_Y8_ShiftDeleteKeepsOffset` | offset +0.00040, then `Grind_CarryShiftDelete(1001)` | offset still +0.00040 (a trim cancel must not clear an ejection) |
| `Test_Y9_AccruedUnchangedByOffset` | accrued +0.00010, offset +0.00040 | `Grind_CarryAccruedGet(1001)` == +0.00010 |
| `Test_Y10_PrunePrefix` | offset for a ticket with no open position; plus a `GlobalVariableSet("GRIND_EJECT_22260101", 1001)` command variable | after `Grind_CarryPruneShiftGvs(22260101)`: the OFFSET is gone, the COMMAND variable still exists |
| `Test_Y11_ClearCarryStateRemovesBoth` | an offset and a `GRIND_EJECT_<magic>` variable | after `Grind_TestClearCarryState()` both are gone |
| `Test_Y12_ReconstructionWithEjectedExit` | long book L0 1.25000 (ticket 1001) + L1 1.24900 (1002), EXT orders at 1.25070 (ejected, offset set) and 1.24930 | `Grind_RebuildBookFromTickets` returns true (no `I6_LONG_EXIT`); without the offset it returns false |
| `Test_Y13_I6DetailIncludesBoth` | accrued +0.00010, offset +0.00040 | `Grind_InvariantDetailI6` payload's expected price == 1.25080, and the string contains both values |
| `Test_Y14_AppendUsesFormulaTarget` | offset for ticket 1004 = +0.00040 set BEFORE the call, then `Grind_AppendLayer(g_grind_long, 1.25000, 1004, 4, 3.0, true)` | the appended layer's `exit_target` == 1.25070 |
| `Test_Y15_CarryPassBaseIncludesOffset` | one long layer, ticket 1001, entry 1.25000, offset +0.00040; call `Grind_CarryExitPassBegin(_Symbol, 22260101, 3.0)` | `g_grind_carry_exit_work_count` == 1 and `g_grind_carry_exit_work_formula[0]` == 1.25070 (raw 1.25030 + offset); the ejected layer is NOT skipped |
| `Test_Y16_CarryPassNoOffsetUnchanged` | same layer, no offset | `g_grind_carry_exit_work_formula[0]` == 1.25030 (regression lock) |
| `Test_Y17_SignGuardPermitsEjected` | long, entry 1.25000, offset -0.00130 set for ticket 1001 (ejected target 1.24900) | the guard-with-bypass decision for ticket 1001 does NOT block. Test it through the call-site condition (extract `Grind_CarrySignGuardApplies(ticket, entry, new_exit, is_long)` if needed) |
| `Test_Y18_SignGuardBlocksOrdinary` | same prices, NO offset | blocks (regression lock; existing CX4 at `fxgrind_tests.mq5:5890` already covers the pure function) |
| `Test_Y19_CommitAccrualTruthTable` | pure | (no order, *, *) true; (order, blocked, *) false; (order, not blocked, modify ok) true; (order, not blocked, modify failed) false |

Write the hand derivation above each assert, e.g. "Y3: 1.25000 + 3 pips
(0.00030) + accrued 0.00010 + offset 0.00040 = 1.25080."

**Commit 1 message:** `ADR-155A eject-offset tests and stubs (Y2-Y15, Y17, Y19 expected to fail)`

**Expected against the stubs:** Y2, Y3, Y4, Y5, Y6, Y7, Y8, Y9 (offset
part), Y10, Y11, Y12, Y13, Y14, Y15, Y17, Y19 FAIL. Y1, Y16 and Y18
PASS (regression locks). Stub `Grind_CarryShouldCommitAccrual` as
`return true;` so the truth-table's false rows fail. Report any that
behave otherwise and STOP.

## COMMIT 2 -- IMPLEMENTATION

1. **Helpers real**, mirroring the carry ones: `Get` returns 0.0 when the
   variable is absent; `Set` writes; `Delete` removes;
   `Grind_EjectIsEjected` is `Grind_EjectOffsetGet(t) != 0.0`.
2. **`Grind_ExitQFormulaTarget`** (`grind_exitq.mqh:241`): add
   `Grind_EjectOffsetGet(position_ticket)` when `position_ticket > 0`,
   alongside `accrued`. No other change.
3. **`Grind_ReconExitMatchesEntry`** (`grind_recon.mqh:355`): add the same
   to `expected`, when `position_id > 0`.
4. **`Grind_InvariantDetailI6`** (`grind_recon.mqh:120`): `expected` becomes
   `Grind_ExitPrice(...) + accrued + eject_offset + carry_shift`, using
   `layer.position_id`; add `accrued` and `eject_offset` to the payload.
   Do not change either call site's arguments beyond what this needs.
5. **Carry pass base includes the offset** (ADR-155 rev 4, replacing
   rev 3's skip). In `Grind_CarryExitPassBegin`, both loops (`:796`,
   `:804`), build the work item from
   `Grind_ExitPrice(...) + Grind_EjectOffsetGet(layer.position_ticket)`.
   `Grind_CarryExitShiftLayer` needs NO change: it receives that base,
   adds accrual, clamps, and stores the clamp delta as the shift, so the
   order lands at raw + offset + accrued + shift -- exactly the four terms
   I6 reads. **Do not skip ejected layers.** A layer that pays swap must
   have its exit move with that cost whether or not it was ejected.
6. **Delete on close:** beside `Grind_CarryAccruedDelete` at
   `grind_engine.mqh:1408`, call `Grind_EjectOffsetDelete` for the same
   ticket. Do NOT put it inside `Grind_CarryShiftDelete`.
7. **Prune:** in `Grind_CarryPruneShiftGvs` (`grind_carry.mqh:813`), prune
   orphan variables with the EXACT prefix `GRIND_EJECT_OFFSET_` only,
   using the same "is the ticket still an open position" test as the shift
   prune. **Never prune the broad `GRIND_EJECT_` prefix here** -- that
   would delete a pending command keyed by magic.
8. **Clean-ups:** add the broad prefix `GRIND_EJECT_` to the list in
   `scripts/grind_gv_clean.mq5:27-40` and to `Grind_TestClearCarryState`.
9. **Append path** (`Grind_AppendLayer`, `grind_engine.mqh:888`): replace
   the raw `Grind_ExitPrice(entry_price, exit_pips, _Point, dir)` with
   `Grind_ExitQFormulaTarget(entry_price, exit_pips, _Point, is_long, position_ticket)`.
   Reason: ONE formula path. The re-price at `:1831` already goes through
   it, and two ways of computing the same target invite drift. (Not a
   race: an offset is keyed by a ticket that does not exist until the fill
   this function handles.) `dir` may become unused -- remove it only if the
   compiler would warn, and say so in the report.
10. **Sign guard bypass for ejected layers** (Gemini, 2026-09-22). At the
    one call site (`grind_carry.mqh:890`), skip the guard when
    `Grind_EjectIsEjected(position_ticket)`. An ejected exit is on the
    loss side of entry BY DESIGN; the guard exists to catch carry
    arithmetic putting an ORDINARY exit there. Do not change
    `Grind_CarrySignGuardBlocks` itself -- the bypass is at the call site.
11. **Commit accrual only when the book agrees.** Today the new accrual is
    written at `:885`, BEFORE the guard (`:890`) and the modify (`:918`).
    If either then returns early, the stored accrual says the exit should
    move while the order has not, so the next OnTick I6 check halts the
    instance (plain I6 is not quarantinable). Add a pure helper to
    `grind_pure.mqh`:

        bool Grind_CarryShouldCommitAccrual(const bool has_exit_order,
                                            const bool guard_blocked,
                                            const bool modify_ok)
        // true when !has_exit_order, or when !guard_blocked && modify_ok

    and move the `Grind_CarryAccruedSet` call so it runs only when the
    helper returns true: immediately for the no-order case (unchanged
    behaviour), otherwise after a successful modify. On a guard block or a
    failed modify, the previous accrual stays, the order stays, I6 stays
    consistent, and the next pass retries.


**Commit 2 message:** `ADR-155A: eject offset in formula, I6, detail; include in carry pass, bypass sign guard, commit accrual after modify`

## NEGATIVE SPACE

- **No command, no script, no input, no telemetry event, no order is
  placed or modified.** Anything that CREATES an offset is Part B.
- Do not change `Grind_ExitQRequired`, ranking, quarantine, the halt path,
  or any invariant other than the I6 expected-price computation.
- Do not alter `Grind_CarryShiftDelete`'s behaviour.
- Do not deploy, CLI compile, launch MetaTrader, run the suite, merge,
  open a PR, amend, `git stash`, or use `git add .` / `-u`.

## FAILURE MODES -- STOP AND REPORT

- Any anchor is not where the audit trail says.
- `Grind_InvariantDetailI6` cannot reach the position ticket from its
  arguments.
- A test needs an expected value not derivable by hand from the rules
  above.
- Any existing test would need its expected value changed.

## QUESTIONS FOR THE REVIEWING ARCHITECT (answer before Cursor runs)

1. **Rev 4 (commit 0, step 5).** Carry now applies to ejected layers,
   base = raw + offset. Confirm the arithmetic: the order lands at
   raw + offset + accrued + shift, and I6 reads the same four terms;
   accrual keeps its own variable, so carry and ejection stay separable
   (your rev-2 ruling). Any path where a term is double-counted?
2. **Clamp interaction.** An ejected exit sits AT the market, so the carry
   clamp (`Grind_CarryClampLongExit` / `...ShortExit`) bites more often
   than for an ordinary exit, and the clamp delta is stored as the carry
   SHIFT. Is that storage ambiguous for an ejected layer?
3. **Sign guard.** `Grind_CarrySignGuardBlocks` skips a layer whose
   shifted exit crosses its entry. An ejected exit is usually on the wrong
   side of entry by design. Does the guard therefore block every ejected
   layer from accruing -- and if so, is the fix Part A's or Part B's?
4. **Test set Y1-Y19.** What is missing, with hand-derived values?
5. **Step 11, accrual ordering (found while checking your item 3).** The
   guard does not block ACCRUAL: `Grind_CarryAccruedSet` (`:885`) runs
   BEFORE the guard (`:890`) and the modify (`:918`). A guard block or a
   rejected modify therefore leaves stored accrual ahead of the resting
   order, and the next OnTick I6 check HALTS (plain I6 is not
   quarantinable, `grind_quarantine.mqh:37,41`). This is latent today
   (carry off) and affects ORDINARY layers too: positive carry past the
   exit pips, or any requote. Is "commit accrual only when there is no
   order, or after a successful modify" the right rule, or should a
   blocked layer instead be moved to purgatory (cancel the order, keep
   the accrual, let re-release place it)?

## FINAL REPORT (fixed format)

```
BRANCH:  <git branch --show-current>
BASE:    <sha>
COMMIT0: <sha from git log>   files: docs/architecture/ADR-155-commanded-passive-ejection.md
COMMIT1: <sha from git log>   files: <list>
COMMIT2: <sha from git log>   files: <list>
PUSHED:  <git ls-remote origin adr155-eject-offset>
LINES:   <wc -l of every changed file>
DIFF:    <git diff --stat origin/main..adr155-eject-offset>
STUB-STATE EXPECTATION: Y1, Y16, Y18 pass; Y2-Y15, Y17, Y19 fail (not run)
DEVIATIONS: <none, or each with reason>
```

Line count: 246
