This message has a line count at the bottom.

# Cursor Courier -- Relay DeepSeek Phase 1 Brief: straddle deadband rebuild

## TASK
You are running as DeepSeek R1, Phase 1 Red Team, for ONE brief that lives on disk.
FIRST load the brief and integrity-check that it loaded whole. If the check fails,
HARD STOP -- never answer a half-loaded brief. If it passes, execute the teardown and
write your response to disk.

## CONTEXT
Repo root: d:\fxmatrix
Brief path: prompts/deepseek_straddle_rebuild.md
The brief is a self-contained Phase 1 teardown (GIVENS G1-G6, the proposed rebuild,
threats T-1..T-6, required output format). You have READ access to ea/; you MAY and
SHOULD open those files to verify or attack the GIVENS against real source (encouraged
for every threat). You may WRITE exactly one file: the response named below.

## OBJECTIVE
1. Read prompts/deepseek_straddle_rebuild.md in full.
2. Integrity gate -- confirm ALL FOUR, printing each PASS/FAIL with the observed value:
   - line 1      == "This message has a line count at the bottom."
   - line 50     == "## The proposed rebuild (ATTACK it)"
   - last line   == "Line count: 106"
   - total lines == 106
3. If ANY check FAILs: print "COURIER HARD STOP -- brief did not load intact", name
   the failed check and observed value, and STOP. Do NOT answer.
4. If ALL PASS: perform the Phase 1 teardown per the brief's "Required output format"
   (VERDICT / LOAD-BEARING CLAIM / MINIMAL REPRO / SEVERITY per T-1..T-6, the PREMISE
   VERDICT, and the OVERRIDE CHECK as the final content line). Write ZERO code.
5. Write the full response to prompts/deepseek_straddle_rebuild_response.md, opening
   with "This message has a line count at the bottom." and closing with "Line count: N"
   (the actual count). Then also print the response in chat.

## NEGATIVE SPACE
- Do NOT proceed past a FAILED integrity check.
- Do NOT write/modify any file except prompts/deepseek_straddle_rebuild_response.md.
- Do NOT write implementation code, edit ea/, compile, run tests, or touch git.
- Do NOT re-litigate the brief's GIVENS without a concrete source-grounded
  counterexample from the actual ea/ files.
- Do NOT retail-judge (leverage, "most traders lose," absence of stops).

## FAILURE MODES
- Brief missing/unreadable at the path: HARD STOP; report the exact path checked.
- Any integrity check FAIL: HARD STOP; do not answer.
- If you cannot open an ea/ file you wanted to verify against: fall back to the brief's
  embedded GIVENS and say so explicitly in each affected verdict rather than guessing.
- If the brief appears internally contradictory: report it as a T-1 finding; do NOT
  silently "fix" it.

## SELF-REVIEW
Before finalizing, confirm: (a) every threat has all four fields; (b) every
EXPLOIT-FOUND / DESIGN-UNSAFE has a concrete minimal repro, not an assertion; (c) the
OVERRIDE CHECK is the literal last content line before your bookend; (d) you wrote
exactly one file. Print "SELF-REVIEW OK" or list what you corrected.

Line count: 57
