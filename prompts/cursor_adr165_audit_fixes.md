This message has a line count at the bottom

# CURSOR PROMPT -- ADR-165 POST-AUDIT FIX (skip hand-ejected layers; latch test)

**Workspace: `D:\fxmatrix`** (NOT `D:\pipshed`). Start a NEW Cursor chat
in that workspace. Branch `adr165-reroll`, at the commit that carries
THIS file (on top of `d9dbad7`, the DeepSeek response; EA code ==
`ac4433e`, suite 2434/2434 on GBPUSD and EURUSD). Design:
`docs/architecture/ADR-165-continuous-reroll.md` s4.2 and s10 (D-T5,
D-T3) -- read them first. Written by Claude from source at `d9dbad7`,
1 Oct ~18:10Z. Line numbers are that code.

## 0. RESTATE AND STOP (do this first, then wait)

1. `git fetch origin`; `git switch adr165-reroll`; `git pull --ff-only`.
   `git diff --stat ac4433e HEAD -- ea/` must be EMPTY. If not, STOP.
2. Restate each change in s2 in ONE line, quoting this prompt's words,
   and list every test name in s4 with its assertion count.
3. Then STOP. Do not edit anything until the operator replies "go".

## AUDIT TRAIL

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | `Grind_LatticeRerollIndex` skips layers with no position or no VL (`if(!Grind_VLHas(ticket)) continue;`) and nothing else | `ea/grind_engine.mqh` 958-983, 966 | VERIFIED |
| A2 | `Grind_EjectIsEjected(ticket)` = the ADR-155 offset GV is non-zero; `Grind_EjectOffsetSet(ticket, offset)` sets it | `ea/grind_carry.mqh` 553-579 | VERIFIED |
| A3 | A roll deletes the eject offset (`Grind_EjectOffsetDelete(pos)`, 1067 and 1075; ADR-162 GB3); the only other delete is on close (2856) | `ea/grind_engine.mqh` | VERIFIED |
| A4 | The re-roll clears the stranded latch on success (C7 of the first prompt); `Grind_LatticeMaybeStranded` returns early while the latch is set | `ea/grind_engine.mqh` `Grind_LatticeTrySide`, `Grind_LatticeMaybeStranded` | VERIFIED |
| A5 | `Adr162b_Reset` -> `Grind_TestEjectHarnessReset` -> `Grind_TestClearCarryState` deletes every `GRIND_EJECT_` and `GRIND_VL_` GV; `Grind_LatticeResetBackoff` clears the latch | `ea/fxgrind_tests.mq5` 2450-2457, 6972-6978; `grind_engine.mqh` 896-917 | VERIFIED |
| A6 | `ROLL_ACCEPTED` detail begins `{"ticket":<position ticket>,` | `Grind_LatticeRollDetail` | VERIFIED |

## 1. WHAT TO BUILD (summary)

`Grind_LatticeRerollIndex` also skips a layer whose position is
hand-ejected (ADR-155 offset present): the eject stands and the next
highest VL is re-rolled instead. First rolls are NOT changed (ADR-162
GB3 still applies to them). Plus tests for that and for the latch clear.

## 2. CHANGES

| # | File | Change |
|---|---|---|
| X1 | `ea/grind_engine.mqh` | in `Grind_LatticeRerollIndex`, directly after `if(!Grind_VLHas(ticket)) continue;` (966-967) add `if(Grind_EjectIsEjected(ticket)) continue;` (same two-line style). Nothing else |
| X2 | `ea/fxgrind_tests_adr165.mqh` | append the s4 tests after `Test_RR13_FirstRollsThenOneReroll` (before the `#endif`) |
| X3 | `ea/fxgrind_tests.mq5` | call `Test_RR14_RerollIndexSkipsEjected(); Test_RR15_EjectedCandidateKept(); Test_RR16_LatchClearedThenRearmed();` right after `Test_RR13_FirstRollsThenOneReroll();` (9427) |

## 3. COMMITS

1. **Tests first:** X2, X3 only. Message: tests first, 6 F / 7 G.
2. **Fix:** X1 only.
Do not compile (the operator compiles and runs the suite; do NOT report
a suite figure).

## 4. TESTS (F = fails at commit 1, G = passes at both)

Reuse `Adr165_Fixture()`, `Adr165_TryLong(now, reroll)`, `ADR165_T0`.
Every test ends with `Adr162b_Reset()`. The fixture's VLs are 1.20600
(7001) down to 1.19900 (7008); market 1.19000/1.19010; next level
1.19800.

**RR14 RerollIndexSkipsEjected** (3):
a F fixture, `Grind_EjectOffsetSet(7001UL, -0.00300);` ->
`Grind_LatticeRerollIndex(g_grind_long, true)` == 1 (7002, VL 1.20500);
b F then `Grind_EjectOffsetSet(7001UL + i, -0.00300)` for i = 1..7 (all
eight ejected) -> == -1;
c G `Adr162b_Reset(); Adr165_Fixture(); Grind_EjectOffsetSet(7008UL, -0.00300);`
-> == 0 (the ejected layer is not the candidate).

**RR15 EjectedCandidateKept** (6): fixture,
`Grind_EjectOffsetSet(7001UL, -0.00300);` then
`Adr165_TryLong(ADR165_T0, true)`:
a G rc == 1 (today 7001 is re-rolled; fixed, 7002);
b F `Grind_VLGet(7001UL)` == 1.20600 (AssertNear, 1e-9);
c F `Grind_VLGet(7002UL)` == 1.19800;
d F `Grind_EjectIsEjected(7001UL)` true;
e F `ROLL_ACCEPTED` #0 contains `"ticket":7002`;
f G `ROLL_STRANDED` #0 == "".

**RR16 LatchClearedThenRearmed** (4): fixture,
`g_grind_vl_stranded_warned_long = true;` then:
a G `Adr165_TryLong(ADR165_T0, true)` == 1;
b G `g_grind_vl_stranded_warned_long` false (AssertFalse);
c G `Adr165_TryLong(D'2026.09.28 23:55', true)` == 0 (paused; next level
1.19700 is crossed and 2 steps past it, 1.19500, too);
d G `ROLL_STRANDED` #0 != "".
(RR16 pins existing code: removing the latch clear fails b and d.)

Totals: **13 assertions; 6 F (RR14a-b, RR15b-e), 7 G.** At commit 1 the
suite reads 2447 total, 2441 passing, exactly the 6 F failing; at
commit 2, 2447/2447. ANY other count, any G failing, or any existing
test changing: STOP and report.

## 5. NEGATIVE SPACE

- Do not change `Grind_LatticeCandidateIndex`, `Grind_LatticeRollLayer`
  (it still deletes the offset on a FIRST roll of an ejected layer),
  `Grind_LatticeTrySide`, ADR-155/157 code, or any existing test.
- Do not touch presets, pipshed, docs, or any file not in s2.
- Do not compile, launch MetaTrader, run the suite, or CLI compile. No
  stash, no checkout of other commits, no merge, no PR, no force-push,
  no `git add .` or `-u` (add each file by name). ASCII only.

## 6. FAILURE MODES: STOP AND REPORT

- Step 0's diff is not empty.
- A helper named in s4 does not exist with the shape described.
- Your re-derivation of any F/G tag against the code at commit 1
  disagrees (report which; do not change it).
- You need to change anything outside s2.

## 7. REPORT

Per commit: hash, files, `git diff --stat`; the 13 assertion names with
their tags; for commit 1 your re-derivation of each tag (agree /
disagree with reason). Use exactly the commit messages in s3. No suite
figure.

## 8. FOR GEMINI (on this prompt, before Cursor starts)

- **GE-1** Skip hand-ejected layers for RE-rolls only, keeping ADR-162
  GB3 (a roll supersedes an eject) for FIRST rolls: for a re-roll the
  candidate and ADR-155's eject target are the same layer by
  construction (ADR s10 D-T5); for a first roll they rarely are. Agree,
  or should first rolls skip ejected layers too?
- **GE-2** With every rolled layer ejected the side strands and warns
  `ROLL_STRANDED` (the exits are already near the market by the
  operator's command). Acceptable?
- **GE-3** D-T4 (pause clock) and D-T7 (request budget) are rejected in
  ADR s10 with the source lines. Object to either?

Line count: 131
