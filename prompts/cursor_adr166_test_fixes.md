This message has a line count at the bottom

# CURSOR PROMPT -- ADR-166 TEST FIXES (ONE COMMIT, TESTS ONLY)

**Workspace: `D:\fxmatrix`**, the SAME Cursor chat (or a new one), branch
`adr166-roll-gate` at `e9661dd`. Written by Claude, 6 Oct ~19:00Z, after
reading `47facb4` and `e9661dd` on GitHub. The production code is exactly
as `prompts/cursor_adr166_roll_gate.md` (Gemini-reviewed) specifies; these
are three test-mechanics corrections, two of them caused by that prompt's
wording ("RG8 and RG13 first call `Grind_MarketTestReset()`" meant: as
cleanup, just before each test's final reset).

## 0. RESTATE AND STOP

1. `git log --oneline -1` must print `e9661dd`. If not, STOP and report.
2. Restate F1-F3 in one line each, quoting this prompt. Then STOP until
   the operator replies "go".

## 1. FIXES (only `ea/fxgrind_tests_adr166.mqh`)

| # | Where | Change |
|---|---|---|
| F1 | `Test_RG8_ExtremeRestartsWhileGated`, the RG8c line | replace `AssertEqInt("RG8c (F)", (int)g_grind_vl_from_msc_long, 1790000000001);` with `AssertTrue("RG8c (F)", g_grind_vl_from_msc_long == 1790000000001);` (a long comparison; `AssertEqInt` takes int and truncates both sides) |
| F2 | `Test_RG8_ExtremeRestartsWhileGated` | MOVE the line `Grind_MarketTestReset();` from just after `Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);` to just before the test's final `Adr162b_Reset();` (the seeded market must stay for the call) |
| F3 | `Test_RG13_DipNotReplayedAtRelease` | ADD `Grind_MarketTestReset();` just before the test's final `C55_Reset();` |

Nothing else. Tags and counts are unchanged: 55 assertions, 31 F, 24 G
(RG8c stays F at `47facb4`: from_msc 1000 != 1790000000001).

## 2. COMMIT

One commit: "ADR-166 test fixes: RG8c long comparison; market-time seam
reset as cleanup in RG8 and RG13 (prompts/cursor_adr166_test_fixes.md)".
Add the file by name. Do not compile, do not run the suite, do not launch
MetaTrader, do not stash, do not merge, no PR, no `git add .` or `-u`.
Then push the branch: `git push origin adr166-roll-gate`.

## 3. STOP AND REPORT IF

- any line named in s1 is not found exactly as quoted;
- any other change seems needed.

## 4. REPORT

Hash, `git diff --stat HEAD~1`, and the three changed lines before / after.

Line count: 47
