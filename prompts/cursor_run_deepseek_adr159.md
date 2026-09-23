This message has a line count at the bottom.

# CURSOR TASK -- Commit the ADR-159 audit inputs and run the DeepSeek R1 audit

Pattern: `docs/deepseek_prompts_templates/deepseek_r1_audit_pattern_HOWTO.md`.
Cursor drives the runner only; it does not act as DeepSeek and does not
interpret the audit. Since C20 the runner is config-driven
(`tools\r1_audit\r1_audit.py --config`), so there is NO script edit step.

## CONTEXT
  - `D:\fxmatrix` on branch `adr159-ea` at `05f5ae7` (suite 1724/1724). The
    runner reads `ea\` from this working copy, so it MUST stay on this commit.
  - The operator has saved, untracked:
      `prompts\deepseek_adr159_audit.md` (the brief, 107 lines)
      `prompts\deepseek_adr159_audit_config.json` (the runner config)
      `prompts\cursor_run_deepseek_adr159.md` (this task)
  - Interpreter: `D:\candlelab\venv\Scripts\python.exe`. The API key lives only
    in `D:\candlelab\.env`; never print, log or commit it.

## STEP 0 -- Preconditions (STOP on any mismatch)
1. `git fetch origin`; `git branch --show-current` must print `adr159-ea`;
   `git rev-parse --short HEAD` and `git rev-parse --short origin/adr159-ea`
   must both print `05f5ae7`.
2. `git status -s` must show no modified tracked files (untracked files are
   fine; report them).
3. Brief checks on `prompts\deepseek_adr159_audit.md`:
     - `(Get-Content <f>).Count` is 107
     - line 1 begins `This message has a line count at the bottom`
     - line 50 is exactly `## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX`
     - line 107 is exactly `Line count: 107`
4. `D:\candlelab\venv\Scripts\python.exe -m json.tool prompts\deepseek_adr159_audit_config.json`
   must succeed (print only "valid" or the error).

## STEP 1 -- Commit the inputs (on adr159-ea)
    git add prompts/deepseek_adr159_audit.md prompts/deepseek_adr159_audit_config.json prompts/cursor_run_deepseek_adr159.md
    git commit -m "ADR-159 DeepSeek R1 audit inputs (brief, config, runner task)"
    git push origin adr159-ea
    git log --oneline -1
Stage NOTHING else. `git branch --show-current` before the commit.

## STEP 2 -- Dry run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_adr159_audit_config.json --dry-run
Expect `Preflight check passed: 11 files verified` and about 195,495 chars
(the operator's earlier dry run on this commit). STOP and report if
preflight fails or the size is under 170,000 or over 220,000.

## STEP 3 -- Real run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_adr159_audit_config.json
Up to about 10 minutes. On any error, STOP and print it verbatim (redact any
key).

## STEP 4 -- Mechanical checks on `prompts\deepseek_adr159_audit_response.md`
  - total line count and character count
  - YES/NO for each literal: `GIVENS CHECK`, `T-1`, `T-2`, `T-3`, `T-4`,
    `T-5`, `T-6`, `T-7`, `T-8`, `PREMISE VERDICT`, `TEST GAPS`
  - substring `sk-` present? Must be NO; if YES, STOP and do not commit
Do NOT summarise, judge or edit the content.

## STEP 5 -- Commit the response (on adr159-ea)
    git add prompts/deepseek_adr159_audit_response.md
    git commit -m "Add DeepSeek R1 response: ADR-159 EA audit"
    git push origin adr159-ea
    git log --oneline -1

## NEGATIVE SPACE
- Do not edit the brief, the config, the runner, or anything under `ea\`.
- Do not switch branches, merge, rebase, stash, amend, or open a PR.
- Do not compile or run anything in MetaTrader.
- Do not print or commit any API key. Do not interpret the audit.
- No `git add .` / `git add -u`. ASCII only.

## FINAL REPORT (print exactly these lines)
    BRANCH_HEAD_BEFORE: <hash>
    BRIEF_LINES: <n>   MID_ANCHOR_OK: YES|NO   CONFIG_JSON: valid|<error>
    INPUTS_COMMIT: <hash>
    DRY_RUN_FILES: <n>   DRY_RUN_CHARS: <n>
    RESPONSE_LINES: <n>   RESPONSE_CHARS: <n>
    SECTIONS_ALL_PRESENT: YES|NO (list any missing)
    KEY_LEAK: NO|YES
    RESPONSE_COMMIT: <hash>
    PUSHED: <git ls-remote origin adr159-ea>

Line count: 83
