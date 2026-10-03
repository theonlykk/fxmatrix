This message has a line count at the bottom.

# CURSOR TASK -- Run the v2.2a DeepSeek R1 audit

Workspace: `D:\fxmatrix` (NOT `D:\pipshed`). Start a NEW Cursor chat.
Pattern: `docs/deepseek_prompts_templates/deepseek_r1_audit_pattern_HOWTO.md`.
Cursor drives the runner only; it does not act as DeepSeek and does not
interpret the audit. The runner is config-driven
(`tools\r1_audit\r1_audit.py --config`), so there is NO script edit step.

## CONTEXT
  - `D:\fxmatrix` on branch `v22a-recon-api`. The inputs are ALREADY
    committed on it (the commit after `24b886d`; suite 2508/2508 on
    GBPUSD and EURUSD at `24b886d`; 2475/2508 at `2b23dcf`, exactly the
    33 predicted):
      `prompts\deepseek_v22a_audit.md` (the brief, 143 lines)
      `prompts\deepseek_v22a_audit_config.json` (the runner config)
      `prompts\cursor_run_deepseek_v22a.md` (this task)
    The runner reads `ea\` and `prompts\cursor_v22a_c93_c100.md` from
    this working copy, so it MUST stay on this branch head. The EA code
    at the head is identical to `24b886d`.
  - Interpreter: `D:\candlelab\venv\Scripts\python.exe`. The API key lives only
    in `D:\candlelab\.env`; never print, log or commit it.

## STEP 0 -- Preconditions (STOP on any mismatch)
1. `git fetch origin`; `git switch v22a-recon-api`; `git pull --ff-only`;
   `git branch --show-current` must print `v22a-recon-api`;
   `git rev-parse --short HEAD` must equal
   `git rev-parse --short origin/v22a-recon-api`; report it.
2. `git diff --stat 24b886d HEAD -- ea/ docs/ prompts/cursor_v22a_c93_c100.md`
   must print nothing.
3. `git status -s` must show no modified tracked files (untracked are
   fine; report them).
4. Brief checks on `prompts\deepseek_v22a_audit.md`:
     - `(Get-Content <f>).Count` is 143
     - line 1 begins `This message has a line count at the bottom`
     - line 87 is exactly `## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX`
     - line 143 is exactly `Line count: 143`
5. `D:\candlelab\venv\Scripts\python.exe -m json.tool prompts\deepseek_v22a_audit_config.json`
   must succeed (print only "valid" or the error).

## STEP 1 -- Dry run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_v22a_audit_config.json --dry-run
Expect `Preflight check passed: 11 files verified` (9 code, 1 doc, the
brief) and roughly 192,000 chars. STOP and report if preflight fails or
the size is under 185,000 or over 200,000.

## STEP 2 -- Real run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_v22a_audit_config.json
Up to about 10 minutes. On any error (including a context-length error),
STOP and print it verbatim (redact any key). Do not trim inputs to retry.

## STEP 3 -- Mechanical checks on `prompts\deepseek_v22a_audit_response.md`
  - total line count and character count
  - YES/NO for each literal: `GIVENS CHECK`, `T-1`, `T-2`, `T-3`, `T-4`,
    `T-5`, `T-6`, `T-7`, `PREMISE VERDICT`, `TEST GAPS`
  - number of characters AFTER the last occurrence of `TEST GAPS`
    (an empty final section means DeepSeek ran out of output)
  - does the text match the regex `sk-[A-Za-z0-9]{20,}`? Must be NO; if
    YES, STOP and do not commit
Do NOT summarise, judge or edit the content.

## STEP 4 -- Commit the response (on v22a-recon-api)
    git add prompts/deepseek_v22a_audit_response.md
    git commit -m "Add DeepSeek R1 response: v2.2a audit (C93 recon scan race, C100 API limit inputs)"
    git push origin v22a-recon-api
    git log --oneline -1
Stage NOTHING else. `git branch --show-current` before the commit.

## NEGATIVE SPACE
- Do not edit the brief, the config, the runner, or anything under `ea\`,
  `docs\` or the v2.2a spec.
- Do not switch to another branch, merge, rebase, stash, amend, or open a PR.
- Do not compile or run anything in MetaTrader.
- Do not print or commit any API key. Do not interpret the audit.
- No `git add .` / `git add -u`. ASCII only.

## FINAL REPORT (print exactly these lines)
    BRANCH_HEAD_BEFORE: <hash>
    EA_DOCS_SPEC_DIFF_VS_24B886D: empty|<stat>
    BRIEF_LINES: <n>   MID_ANCHOR_OK: YES|NO   CONFIG_JSON: valid|<error>
    DRY_RUN_FILES: <n>   DRY_RUN_CHARS: <n>
    RESPONSE_LINES: <n>   RESPONSE_CHARS: <n>
    SECTIONS_ALL_PRESENT: YES|NO (list any missing)
    CHARS_AFTER_TEST_GAPS: <n>
    KEY_LEAK: NO|YES
    RESPONSE_COMMIT: <hash>
    PUSHED: <git ls-remote origin v22a-recon-api>

Line count: 90
