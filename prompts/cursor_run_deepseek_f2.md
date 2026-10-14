This message has a line count at the bottom.

# CURSOR TASK -- Run the F2 DeepSeek R1 audit (plan 4's replay harness)

Workspace: `D:\fxmatrix` (NOT `D:\pipshed`). Start a NEW Cursor chat.
Pattern: `docs/deepseek_prompts_templates/deepseek_r1_audit_pattern_HOWTO.md`.
Cursor drives the runner only; it does not act as DeepSeek and does not interpret the audit.
The runner is config-driven (`tools\r1_audit\r1_audit.py --config`): NO script edit step.

## CONTEXT
  - The inputs are committed on `main`:
      `prompts\deepseek_f2_audit.md` (the brief, 121 lines)
      `prompts\deepseek_f2_audit_config.json` (the runner config)
      `prompts\deepseek_f2_inputs.py` (extracts the code inputs from git into
      `temp\deepseek_f2\` and checks each one's line count and sha256)
      `prompts\cursor_run_deepseek_f2.md` (this task)
  - The code under audit is read from GIT (commits `7d8fa13` and `efada62`), not from the
    working copy, so `D:\fxmatrix` stays on `main` throughout.
  - Interpreter: `D:\candlelab\venv\Scripts\python.exe`. The API key lives only in
    `D:\candlelab\.env`; never print, log or commit it.

## STEP 0 -- Preconditions (STOP on any mismatch)
1. `git fetch origin`; `git switch main`; `git branch --show-current` must print `main`;
   `git rev-parse --short HEAD` must equal `git rev-parse --short origin/main`; report it.
2. `git status -s` must show no modified tracked files (untracked are fine; report them).
3. `git cat-file -t 7d8fa13` and `git cat-file -t efada62` must both print `commit`.
4. Brief checks on `prompts\deepseek_f2_audit.md`:
     - `(Get-Content <f>).Count` is 121
     - line 1 begins `This message has a line count at the bottom`
     - line 72 is exactly `## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX`
     - line 121 is exactly `Line count: 121`
5. `D:\candlelab\venv\Scripts\python.exe -m json.tool prompts\deepseek_f2_audit_config.json`
   must succeed (print only "valid" or the error).

## STEP 1 -- Build the inputs
    D:\candlelab\venv\Scripts\python.exe -B prompts\deepseek_f2_inputs.py
It must end `INPUTS 5/5 ok` (each line `OK`). STOP and print its whole output on any
`MISMATCH` or error. Do not edit the script or the files it writes.

## STEP 2 -- Dry run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_f2_audit_config.json --dry-run
Expect `Preflight check passed: 7 files verified` (5 code, 1 doc, the brief) and roughly
260,000 chars. STOP and report if preflight fails or the size is under 245,000 or over
275,000.

## STEP 3 -- Real run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_f2_audit_config.json
Up to about 10 minutes. On any error (including a context-length error), STOP and print it
verbatim (redact any key). Do not trim inputs to retry.

## STEP 4 -- Mechanical checks on `prompts\deepseek_f2_audit_response.md`
  - total line count and character count
  - YES/NO for each literal: `GIVENS CHECK`, `T-1`, `T-2`, `T-3`, `T-4`, `T-5`, `T-6`,
    `T-7`, `T-8`, `PREMISE VERDICT`, `TEST GAPS`
  - number of characters AFTER the last occurrence of `TEST GAPS` (an empty final section
    means DeepSeek ran out of output)
  - does the text match the regex `sk-[A-Za-z0-9]{20,}`? Must be NO; if YES, STOP and do not
    commit
Do NOT summarise, judge or edit the content.

## STEP 5 -- Commit the response on its own review branch, then back to main
    git switch -c review/deepseek-f2 origin/main
    git branch --show-current
    git add prompts/deepseek_f2_audit_response.md
    git commit -m "Add DeepSeek R1 response: F2 sync close-by audit (replay-plan4 7d8fa13)"
    git push -u origin review/deepseek-f2
    git log --oneline -1
    git switch main
Stage NOTHING else. `git branch --show-current` must print `main` at the end.

## NEGATIVE SPACE
- Do not edit the brief, the config, the inputs script, the runner, or anything under `ea\`,
  `docs\`, `research\` or `tools\`.
- Do not check out `replay-plan4`, `replay-harness` or any other branch except as in STEP 5;
  do not merge, rebase, stash, amend, pull, or open a PR.
- Do not compile or run anything in MetaTrader.
- Do not print or commit any API key. Do not interpret the audit.
- No `git add .` / `git add -u`. ASCII only.

## FINAL REPORT (print exactly these lines)
    MAIN_HEAD: <hash>
    BRIEF_LINES: <n>   MID_ANCHOR_OK: YES|NO   CONFIG_JSON: valid|<error>
    INPUTS: <n>/5 ok
    DRY_RUN_FILES: <n>   DRY_RUN_CHARS: <n>
    RESPONSE_LINES: <n>   RESPONSE_CHARS: <n>
    SECTIONS_ALL_PRESENT: YES|NO (list any missing)
    CHARS_AFTER_TEST_GAPS: <n>
    KEY_LEAK: NO|YES
    RESPONSE_COMMIT: <hash>
    PUSHED: <git ls-remote origin review/deepseek-f2>
    BRANCH_AT_END: <name>

Line count: 93
