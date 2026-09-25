This message has a line count at the bottom

# CURSOR PROMPT -- C54: ADR-162 B1 POST-AUDIT PATCH (T-3, T-10) AND THE C52 INTERACTION TESTS

Repo `D:\fxmatrix`, branch `adr162-phase-b1` at `73b1a8d` (EA == tested
`3188f72`, 2002/2002). `main` is at `2adc189` (docs-only on `5685e4f`, the
C52 fix, 1887/1887, LIVE on both fleets). Record: backlog C54
(`handoffs/Handover/08_BACKLOG.md`), ADR-162 s13, DeepSeek
`prompts/deepseek_adr162b1_audit_response.md` (on the branch) T-3 and
T-10. Gemini rules on this prompt BEFORE you start; his rulings are pasted
at the bottom. Where a ruling changes a default below, follow the ruling.
If a ruling is ambiguous, STOP and report.

Nothing here deploys. B1 never deploys without B2 (GB8).

## AUDIT TRAIL (read in source by Claude, 2026-09-25, on a sandbox merge of `origin/main` into `73b1a8d`)

| # | finding | where | status |
|---|---|---|---|
| A1 | T-3: an exit that filled at the broker but whose deal is not yet processed still has `exit_order_ticket != 0` and `exit_position_ticket == 0`. The roll takes branch M, `Grind_ModifyPendingPrice` fails inside `Grind_SelectOurOrder` (no broker call), the roll reports `ROLL_REFUSED` "MODIFY_FAILED", and `Grind_LatticeTrySide` counts a failure and sets a 60 s+ backoff for the whole side | `grind_engine.mqh` 760-817 (roll), 853-873 (backoff), 318-331 (`Grind_SelectOurOrder`) | fix in commit 2 |
| A2 | `Grind_LatticeTrySide` already treats `GRIND_ROLL_CLOSING` as "stop this tick, no count, no backoff" (`if(rc != GRIND_ROLL_OK) break;`, 875) | `grind_engine.mqh` 875 | verified; the fix only changes the code returned |
| A3 | T-10: LB30's "rolled target" assertion sits inside `if(position_ticket == 1001UL)`, so it passes by not running if the layer is missing | `fxgrind_tests_adr162b.mqh` 638-643 | commit 1 |
| A4 | T-10: no test calls `Grind_LatticeRollLayer`'s own ALREADY_ROLLED and CLOSING refusals (LB17 stops at the trigger); the failure-count reset is never asserted (LB15); no short-side gap (LB7 is long-only) | LB15, LB17, LB7 | commit 1 |
| A5 | B1's audit (`73b1a8d`) predates C52, and C52's audit (`e7202e8`) never saw B1. The roll (B1) and the nightly carry pass (C52) were never tested together. By reading: branch M modifies the SAME exit ticket and stores the VL; the pass reads the CURRENT ticket (C52) and prices from `Grind_CarryWorkBase` (carry 975-982), which reads the VL live, so it lands on base(VL) + accrued. Branch S is C52's release case | `grind_carry.mqh` 936-982, 1143-1222; roll 760-817 | UNVERIFIED by test: commit 1 locks it |
| A6 | A trial merge of `origin/main` into the branch conflicts ONLY in `ea/fxgrind_tests.mq5` (the include line and the `OnStart` registration block); `grind_carry.mqh` auto-merges (main's C52 lookup + B1's ticket-0 guard in `Grind_VLHas` and the prune without its `GRIND_VL_` branch). Merged `git diff --stat origin/main -- ea/`: exactly the nine B1 files, 1016 insertions, 8 deletions | sandbox | commit 0 |
| A7 | Test seams: `Adr162b_SeedLong8` / `Adr162b_Reset` clear every carry and VL GV and the side state (`Grind_TestEjectHarnessReset`), so carry fixtures must be set AFTER seeding. `F2_TestSeedCarryWindow` seeds the carry tick at 1.25000/1.25020, far from the B1 book (1.20-1.21): the carry clamp would move every long exit; reseed the carry tick next to the market seam | `fxgrind_tests_adr162b.mqh` 12-19, 53-73; `fxgrind_tests_adr151.mqh` 55-61; `grind_carry.mqh` 149-157 | used in commit 1 |

## WHAT C54 IS

1. Commit 0: bring `main` (C52) into the branch, so the tests run on the
   code that will ship.
2. Commit 1: tests. T-3 (two tests that FAIL now), T-10 (LB30 made
   unconditional; refusals, reset and short gap locked), and three
   roll-during-carry-pass tests that lock the B1 x C52 interaction.
3. Commit 2: the T-3 fix, one guard in `Grind_LatticeRollLayer`.

## COMMIT 0 -- SYNC MERGE OF MAIN INTO THE BRANCH (the ONLY merge you make)

    git switch adr162-phase-b1
    git pull --ff-only
    git fetch origin
    git merge --no-ff origin/main -m "C54 commit 0: merge main (C52 5685e4f) into adr162-phase-b1 before the post-audit patch"

Expected: ONE conflict, in `ea/fxgrind_tests.mq5`, two hunks. Resolve by
keeping BOTH sides, main's first:

- includes (near line 22): `#include "fxgrind_tests_c52.mqh"` then
  `#include "fxgrind_tests_adr162b.mqh"`;
- `OnStart` (after `Test_VL16_ParseL100();`): the five
  `Test_CR1_...` to `Test_CR5_...` calls, then `Test_LB1_ValidateInputs();`
  to `Test_LB32_BackoffCapNoOverflow();` in their existing order.

Then `git add ea/fxgrind_tests.mq5` (that file only), `git commit`
(keep the message above), and check before pushing:

- `git diff --stat origin/main -- ea/` lists exactly `fxgrind.mq5`,
  `fxgrind_tests.mq5`, `fxgrind_tests_adr162.mqh`,
  `fxgrind_tests_adr162b.mqh`, `grind_carry.mqh`, `grind_config.mqh`,
  `grind_engine.mqh`, `grind_pure.mqh`, `grind_scalp_events.mqh`, with
  1016 insertions and 8 deletions;
- no conflict markers anywhere in `ea/`.

Push. Suite at this state (the operator runs it): **2014/2014**
(1875 + 12 C52 + 127 B1).

## COMMIT 1 -- TESTS (against the unfixed roll)

**LB30 (existing test, deliberate change -- T-10 vacuous assertion).** In
`ea/fxgrind_tests_adr162b.mqh` 638-643: add `bool found = false;` before
the loop, set `found = true;` inside the `if` beside the existing
`AssertNear`, and after the loop add
`AssertTrue("LB30 rolled layer found", found);`. Change nothing else in
LB30 or in any other existing test.

**New file `ea/fxgrind_tests_c54.mqh`**, included from `fxgrind_tests.mq5`
directly after `#include "fxgrind_tests_adr162b.mqh"`; register LB33 to
LB39 in `OnStart` directly after `Test_LB32_BackoffCapNoOverflow();`. NO
forward declarations (a mistyped one broke the B1 compile). Use the B1
helpers as they are: `Adr162b_Reset`, `Adr162b_SeedLong8`,
`Adr162b_SeedShort8`, `Adr162b_TryLong`, `Adr162b_TryShort`,
`Adr162b_ArchiveFind`, `Adr162b_RefreshExit`, and
`Adr151_TestCountRestingExits`. Magic 22260101 throughout (the B1 order
fixtures use it). End every test with `Adr162b_Reset();` (LB37-LB39 also
`Grind_CarryTestReset(); Grind_CarryGateReset(22260101UL);`).

`now` = `D'2026.09.28 10:00'` unless stated. "Order gone" means the exit
is still on the layer but its record is removed from the order store:
`Grind_OrderTestRemove(8001UL)` with `g_grind_long.layers[0].exit_order_ticket`
left at 8001.

| test | setup | assertion (name: expected) | now |
|---|---|---|---|
| LB33_OrderGoneNoBackoff | `Adr162b_SeedLong8()`; order gone on layer 0 (8001); `Grind_MarketTestSeed(1.20590, 1.20600, 0, 0)`; `rc = Adr162b_TryLong(now)` | "LB33 no roll": `rc == 0` | PASS |
| | | "LB33 no vl": `!Grind_VLHas(7001UL)` | PASS |
| | | "LB33 no broker call": `g_grind_order_test_modify_calls == 0` | PASS |
| | | "LB33 not refused": `Adr162b_ArchiveFind("ROLL_REFUSED", 0) == ""` | FAIL |
| | | "LB33 no failure counted": `g_grind_vl_fail_count_long == 0` | FAIL |
| | | "LB33 no backoff": `g_grind_vl_backoff_long == 0` | FAIL |
| LB34_RollRefusals | (a) `Adr162b_SeedLong8()`; `Grind_VLSet(7001UL, 1.20600)`; `Grind_MarketTestSeed(1.20590, 1.20600, 0, 0)`; `rc = Grind_LatticeRollLayer(g_grind_long, true, 0, 22260101UL, "OPT", 0.01, 5.0, 1.20500, "auto")` | "LB34 already rolled": `rc == GRIND_ROLL_ALREADY_ROLLED && g_grind_order_test_modify_calls == 0 && MathAbs(Grind_VLGet(7001UL) - 1.20600) <= 1e-9` | PASS |
| | (b) reseed; `layers[0].exit_order_ticket = 0; layers[0].exit_position_ticket = 9999UL;` same call with level 1.20600 | "LB34 closing, deal processed": `rc == GRIND_ROLL_CLOSING` | PASS |
| | (c) reseed; order gone on layer 0; same call with level 1.20600 | "LB34 closing, order gone": `rc == GRIND_ROLL_CLOSING` | FAIL |
| | | "LB34 order gone not refused": `Adr162b_ArchiveFind("ROLL_REFUSED", 0) == ""` | FAIL |
| | | "LB34 order gone no vl": `!Grind_VLHas(7001UL)` | PASS |
| LB35_FailCountReset | `Adr162b_SeedLong8()`; market 1.20590/1.20600; `g_grind_order_test_send_ok = false`; `Adr162b_TryLong(now)`; then `g_grind_order_test_send_ok = true`; `rc = Adr162b_TryLong(now + 61)` | "LB35 failure counted": `g_grind_vl_fail_count_long == 1`, asserted BEFORE the second call | PASS |
| | | "LB35 reset after success": `rc == 1 && g_grind_vl_fail_count_long == 0` | PASS |
| LB36_ShortGapFiresEveryLevel | `Adr162b_SeedShort8()`; `Grind_MarketTestSeed(1.19810, 1.19820, 0, 0)`; `rc = Adr162b_TryShort(now)` | "LB36 five rolls": `rc == 5` | PASS |
| | | "LB36 vl L0": `Grind_VLGet(7101UL)` = 1.19400 (1e-9) | PASS |
| | | "LB36 vl L4": `Grind_VLGet(7105UL)` = 1.19800 (1e-9) | PASS |
| | | "LB36 L5 unrolled": `!Grind_VLHas(7106UL)` | PASS |
| | | "LB36 two resting": `Adr151_TestCountRestingExits(g_grind_short) == 2` | PASS |
| | | "LB36 newest rolled rests": layers[4] has an exit priced 1.19750 (1e-9) | PASS |
| | | "LB36 oldest unrolled rests": layers[5] has an exit priced 1.19050 (1e-9) | PASS |
| | | "LB36 calls": modify 5, remove 5, place 5 | PASS |
| | | "LB36 in order": `ROLL_ACCEPTED` k (k = 0..4) contains `7101 + k` | PASS |

Hand derivation, LB36 (mirror of LB7): short entries 1.18600 + 0.00100 i
(i = 0..7, deepest 1.19300); the first virtual level is 1.19400 (LB16);
a short level fires when the bid is at or above it, so bid 1.19810 crosses
1.19400 to 1.19800 (five) and not 1.19900. Rolled exits are level - 5
pips; the newest rolled (layers[4], level 1.19800) rests at 1.19750; the
oldest unrolled (layers[5], entry 1.19100) rests at 1.19050.

**LB37-LB39: roll during the carry pass (the B1 x C52 interaction).**
Common carry setup, in THIS order (A7):

1. `Grind_CarryTestReset();`
2. the B1 seed (`Adr162b_SeedLong8()`, or LB18's setup for LB39);
3. `F2_TestSeedCarryWindow(22260101UL);` then
   `Grind_CarryTestSeedTick(g_grind_carry_test_server_time, <bid>, <ask>);`
   with the SAME bid/ask as the market seam;
4. for every position ticket on the long side:
   `Grind_CarryTestSetPosition(pos, -0.10, 0.01, D'2026.09.01 12:00');
   Grind_PositionTestAdd(pos);`
5. `Grind_MarketTestSeed(<bid>, <ask>, 0, 0);`
   `g_grind_carry_eligible_magic = 22260101UL;`
   `Grind_CarryExitPassBegin(_Symbol, 22260101UL, 5.0);`

"Step" = `Grind_CarryExitPassStep(_Symbol, 22260101UL, 5.0,
g_grind_carry_test_server_time);` (2 work items each; the work list is
the long array in index order). "Finish" = step while
`g_grind_carry_exit_pass_active`, at most 10 times.

"I6(i)" = `Grind_ReconExitMatchesEntry(layers[i].entry_price, <order
price of layers[i].exit_order_ticket>, 5.0, _Point, true,
Grind_CarryShiftGet(pos_i), false, pos_i)` (it applies the VL through
`pos_i`). "All resting I6" = I6 holds for every layer with
`exit_order_ticket != 0` AND the number checked equals 2 (K=1/H=0), in
ONE `AssertTrue`. "All accrued" = `MathAbs(Grind_CarryAccruedGet(pos)) >
2.0 * _Point` for every long position, in ONE `AssertTrue`.

| test | sequence (bid/ask) | assertion (name: expected) | now |
|---|---|---|---|
| LB37_PassThenRollBranchM | SeedLong8 (1.20590/1.20600); PassBegin; ONE step (items 0 and 1: L0 with exit 8001, L1 held); `rc = Adr162b_TryLong(now)`; finish | "LB37 L0 accrued before roll": after the step, `MathAbs(Grind_CarryAccruedGet(7001UL)) > 2.0 * _Point` | PASS |
| | | "LB37 rolled mid-pass": `rc == 1 && g_grind_carry_exit_pass_active`, asserted right after the roll | PASS |
| | | "LB37 pass completed": `!g_grind_carry_exit_pass_active && Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0) != ""` | PASS |
| | | "LB37 L0 off bare level": `MathAbs(<price of 8001> - 1.20650) > 2.0 * _Point` | PASS |
| | | "LB37 L0 I6": I6(0) | PASS |
| | | "LB37 all resting I6" | PASS |
| | | "LB37 all accrued" | PASS |
| LB38_RollThenPassBranchM | SeedLong8 (1.20590/1.20600); PassBegin; `rc = Adr162b_TryLong(now)` BEFORE any step; finish | "LB38 rolled before first step": `rc == 1 && g_grind_carry_exit_work_cursor == 0` | PASS |
| | | "LB38 pass completed" (as LB37) | PASS |
| | | "LB38 L0 off bare level" (as LB37) | PASS |
| | | "LB38 L0 I6": I6(0) | PASS |
| | | "LB38 all resting I6" | PASS |
| | | "LB38 all accrued" | PASS |
| LB39_RollMidPassBranchS | LB18's setup exactly (VLs on 7001-7006, layers 6 and 7 = 7009 at 1.20000 and 7010 at 1.19900, exits 8001 and 8010), bid/ask 1.19790/1.19800; positions 7001-7006, 7009, 7010; PassBegin; `rc = Adr162b_TryLong(now)`; finish | "LB39 one roll, branch S": `rc == 1 && MathAbs(Grind_VLGet(7009UL) - 1.19800) <= 1e-9 && g_grind_order_test_modify_calls == 0`, asserted right after the roll | PASS |
| | | "LB39 rolled layer has an exit": `g_grind_long.layers[6].exit_order_ticket != 0` | PASS |
| | | "LB39 pass completed" (as LB37) | PASS |
| | | "LB39 rolled exit off bare level": `MathAbs(<price of layers[6] exit> - 1.19850) > 2.0 * _Point` | PASS |
| | | "LB39 rolled exit I6": I6(6) | PASS |
| | | "LB39 all resting I6" | PASS |
| | | "LB39 all accrued" | PASS |

Why LB37-LB39 matter although they pass in both states: they fail if the
pass ever prices a rolled layer from the base CAPTURED at `PassBegin`
(entry-based, 5 pips above the entry) instead of the live VL, if it
modifies a ticket the queue cancelled, or if the roll overwrites the
accrual the pass committed. Why LB37 "off bare level" holds by hand:
swap -0.10 USD at 0.01 lots is about 1 pip of cost on GBPUSD and EURUSD
(C52's CR1 asserts the same bound), and pending swap adds cost on both
symbols' long side, so a long exit moves UP from 1.20650.

**Predicted** (the operator runs each state on GBPUSD and EURUSD; you do
NOT run them): commit 0 **2014/2014**. Commit 1 adds 43 assertions (LB30
+1, LB33 6, LB34 5, LB35 2, LB36 9, LB37 7, LB38 6, LB39 7): **2052/2057**,
failing EXACTLY "LB33 not refused", "LB33 no failure counted", "LB33 no
backoff", "LB34 closing, order gone", "LB34 order gone not refused".
Commit 2 **2057/2057**. Report your own mechanical count of new `Assert*`
calls and any difference from 43.

PASS in both states BY DESIGN, list them as such in the report: LB30
found; LB33 no roll / no vl / no broker call; LB34 already rolled /
deal processed / order gone no vl; all of LB35, LB36, LB37, LB38, LB39.

## COMMIT 2 -- THE FIX

`ea/grind_engine.mqh`, `Grind_LatticeRollLayer`, directly after

    if(layer.exit_position_ticket != 0)
       return GRIND_ROLL_CLOSING;

(774-775), add:

    // C54 (DeepSeek T-3): an exit on the layer that can no longer be
    // selected has filled (deal not processed yet) or was removed: the
    // layer is closing. Refuse without a broker call, a report or a
    // backoff; the next tick sees the processed deal.
    if(layer.exit_order_ticket != 0
       && !Grind_SelectOurOrder(layer.exit_order_ticket, magic))
       return GRIND_ROLL_CLOSING;

Nothing else changes: not `Grind_LatticeTrySide`, not the refusal
report, not the backoff.

## NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run
  the suite (the operator compiles in the MetaEditor GUI; suite figures
  are pending), do not `git stash`, do not check out files from other
  commits, do not merge anything except commit 0, do not merge the branch
  into `main`, no PR, no `git add .` or `-u`.
- PUSH THE BRANCH after each commit: `git push origin adr162-phase-b1`.
- Do not change any existing test, expected value or registration except
  LB30 as written, and commit 0's conflict resolution.
- Do not touch `grind_carry.mqh`, the queue (`grind_exitq.mqh`), the
  backoff arithmetic, `Grind_ModifyPendingPrice`, or any event format.
- Out of scope (DeepSeek, pre-existing or ruled): T-1 (unchecked GV
  writes; slot guard after a roll), T-5 (anchor on the highest index,
  ruled GA1/GB7), T-9's TimeCurrent point, C57 (offset/carry prune),
  C58, C60. Do not fix them; report anything new you see.
- Nothing outside `ea/`. No presets, no docs, no pipshed.

## FAILURE MODES -- STOP AND REPORT

- Commit 0 conflicts anywhere other than the two `fxgrind_tests.mq5`
  hunks, or its `--stat` differs from the check: STOP before committing
  (`git merge --abort`).
- A line cited above does not hold the code described (drift): STOP.
- A helper named above is missing or has another signature
  (`Adr162b_*`, `Adr151_TestCountRestingExits`, `F2_TestSeedCarryWindow`,
  `Grind_CarryTestSeedTick`, `Grind_CarryTestSetPosition`,
  `Grind_PositionTestAdd`, `Grind_OrderTestRemove`,
  `Grind_LatticeRollLayer`, `Grind_ReconExitMatchesEntry`): STOP.
- Any existing test would need a change to compile or pass (other than
  LB30): STOP.
- You believe one of LB37-LB39 would FAIL on the merged code: do not
  change the code or the expected value. Write the test as specified and
  report why; a failure there is a finding, not a fixture problem to
  tune away.

## REPORT

All three commit hashes (pushed); `git diff --stat origin/main..adr162-phase-b1 -- ea/`;
each new test by name with its assertion names; your count of new
assertions; the PASS-in-both list.

## FOR GEMINI -- RULE BEFORE CURSOR STARTS

Verified in source by Claude unless marked. Answer each; say what you
would change.

- **GC1. The T-3 fix.** Return `GRIND_ROLL_CLOSING` when the layer's exit
  ticket is set but `Grind_SelectOurOrder` fails, before the modify.
  `TrySide` then stops for this tick with no failure count and no
  backoff (verified, 875). The same guard also catches an exit REMOVED by
  hand, which the C52 repair runbook does on purpose (BOOT s6: delete the
  mispriced EXT, reattach that chart). In that case the roll returns
  CLOSING on every tick until the reattach, at no API cost (the select is
  local). Accept, or do you want a distinct code (e.g. EXIT_GONE) for
  reporting?
- **GC2. Commit 0 merges `main` into the feature branch** so that the
  suite and DeepSeek see the code that will ship (C52 changed the pass
  the roll interacts with). The final merge to `main` stays `--no-ff`
  after C54. Accept, or merge B1 into an integration branch off `main`
  instead?
- **GC3. LB30** is an existing test changed on purpose (T-10: its only
  target assertion is inside an `if`). Accept adding an unconditional
  "found" assertion?
- **GC4. LB37-LB39 pass in both states by design:** they lock the B1 x
  C52 interaction (A5) rather than test the T-3 change. The premise that
  they pass is Claude's reading of source (A5), NOT a run. Is the
  sequence (pass then roll; roll then pass; branch S) the right set? Is
  there an interleaving you expect to BREAK that should be a test here
  (e.g. a roll between the two items of one step is impossible: the pass
  runs in OnTimer, the roll in OnTick -- verified that both are
  single-threaded MQL5 handlers)?
- **GC5. Scope.** T-1, T-5, T-9's clock point, C57, C58 and C60 stay out
  (NEGATIVE SPACE). Accept?

After Gemini, Cursor, and the operator's three suite states: DeepSeek
audits the MERGED branch (a separate runner prompt from Claude), then the
merge to `main` `--no-ff`.

## GEMINI RULINGS (2026-09-25) -- ALL FIVE ACCEPTED, NO CHANGES TO THE BUILD

Build exactly as written above. Condensed; reasons checked by Claude.

- **GC1 ACCEPTED, no distinct code.** Filled-but-unprocessed and removed
  by hand need the same response: do nothing to that layer this tick.
- **GC2 ACCEPTED.** Merge `main` into the branch (commit 0); the final
  merge to `main` stays `--no-ff`.
- **GC3 ACCEPTED.** LB30 gains the unconditional "found" assertion.
- **GC4 ACCEPTED, no interleaving missed.** OnTimer and OnTick are
  single-threaded per instance, so a roll lands before or after a pass
  step, never inside one. CORRECTION (Claude): in LB39 the pass does not
  SKIP the rolled layer; it captured the layer with no exit, and C52's
  lookup finds the exit the queue placed after the roll and shifts it.
  And LB37-LB39 are checks predicted by reading, not a proof: if one
  fails, STOP and report (as written above).
- **GC5 ACCEPTED.** T-1, T-5, T-9's clock point, C57, C58 and C60 stay
  out. CORRECTION (Claude): C57 is open in the backlog, not scheduled;
  T-9's clock point is low risk, not merely stylistic.

Line count: 314
