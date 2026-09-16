This message has a line count at the bottom.

# Cursor Courier -- Relay DeepSeek Phase 1 Brief: order purgatory

## TASK
You are running as DeepSeek R1, Phase 1 Red Team, for ONE brief that lives on disk.
FIRST load the brief and integrity-check that it loaded whole. If the check fails,
HARD STOP -- never answer a half-loaded brief. If it passes, execute the teardown and
write your response to disk.

## CONTEXT
Repo root: d:\fxmatrix
Brief path: prompts/deepseek_order_purgatory.md
Design memo (reference only): docs/architecture/MEMO_2026-09-16_order_purgatory.md
The brief is self-contained (frame, GIVENS G1-G8, proposed design D1-D9, threats
T-1..T-9, required output format). You have READ access to ea/. You SHOULD open
ea/grind_engine.mqh, ea/fxgrind.mq5, ea/grind_recon.mqh, ea/grind_quarantine.mqh,
ea/grind_api_counter.mqh, ea/grind_closeby.mqh and ea/grind_cap.mqh to verify the
GIVENS and ground every threat. You may WRITE exactly one file: the response below.

## OBJECTIVE
1. Run `git rev-parse HEAD` and report the commit you are reading.
2. Read prompts/deepseek_order_purgatory.md in full.
3. Integrity gate -- confirm ALL FOUR, printing each PASS/FAIL with the observed value:
   - line 1      == "This message has a line count at the bottom."
   - line 55     == "## The proposed design (ATTACK it)"
   - last line   == "Line count: 118"
   - total lines == 118
4. If ANY check FAILs: print "COURIER HARD STOP -- brief did not load intact", name
   the failed check and observed value, and STOP. Do NOT answer.
5. If ALL PASS: perform the Phase 1 teardown per the brief's "Required output format"
   (four fields per T-1..T-9, GIVENS CHECK, PREMISE VERDICT, and the OVERRIDE CHECK as
   the final content line). Write ZERO code.
6. Write the full response to prompts/deepseek_order_purgatory_response.md, opening
   with "This message has a line count at the bottom.", stating the commit read on
   line 3, and closing with "Line count: N" (the actual count). Then print the
   response in chat.

## NEGATIVE SPACE
- Do NOT proceed past a FAILED integrity check.
- Do NOT write or modify any file except prompts/deepseek_order_purgatory_response.md.
- Do NOT write implementation code, edit ea/, compile, run tests, or touch git
  beyond the read-only rev-parse in step 1.
- Do NOT re-litigate G1-G8 without a concrete source-grounded counterexample.
- Do NOT retail-judge (leverage, "most traders lose", absence of stops).

## FAILURE MODES
- Brief missing or unreadable at the path: HARD STOP; report the exact path checked.
- Any integrity check FAIL: HARD STOP; do not answer.
- An ea/ file you need cannot be opened: fall back to the brief's GIVENS and say so
  explicitly in each affected verdict rather than guessing.
- The brief appears internally contradictory: report it under GIVENS CHECK; do NOT
  silently fix it.

## SELF-REVIEW
Before finalizing, confirm: (a) every threat has all four fields; (b) every
EXPLOIT-FOUND or DESIGN-UNSAFE has a concrete sequence, not an assertion; (c) every
LOAD-BEARING CLAIM names a real file and function you opened; (d) the OVERRIDE CHECK
is the literal last content line before the bookend; (e) you wrote exactly one file.
Print "SELF-REVIEW OK" or list what you corrected.

Line count: 62
