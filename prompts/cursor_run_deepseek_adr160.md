This message has a line count at the bottom.

# CURSOR TASK -- Commit the ADR-160 audit inputs and run the DeepSeek R1 audit

Pattern: `docs/deepseek_prompts_templates/deepseek_r1_audit_pattern_HOWTO.md`.
Cursor drives the runner only; it does not act as DeepSeek and does not
interpret the audit. Since C20 the runner is config-driven
(`tools\r1_audit\r1_audit.py --config`), so there is NO script edit step.

## CONTEXT
  - `D:\fxmatrix` on branch `adr160-gate` at `6c57830` (suite 1766/1766). The
    runner reads `ea\` from this working copy, so it MUST stay on this commit.
  - The operator has saved, untracked:
      `prompts\deepseek_adr160_audit.md` (the brief, 94 lines)
      `prompts\deepseek_adr160_audit_config.json` (the runner config)
      `prompts\cursor_run_deepseek_adr160.md` (this task)
  - Interpreter: `D:\candlelab\venv\Scripts\python.exe`. The API key lives only
    in `D:\candlelab\.env`; never print, log or commit it.

## STEP 0 -- Preconditions (STOP on any mismatch)
1. `git fetch origin`; `git branch --show-current` must print `adr160-gate`;
   `git rev-parse --short HEAD` and `git rev-parse --short origin/adr160-gate`
   must both print `6c57830`.
2. `git status -s` must show no modified tracked files (untracked files are
   fine; report them).
3. Brief checks on `prompts\deepseek_adr160_audit.md`:
     - `(Get-Content <f>).Count` is 94
     - line 1 begins `This message has a line count at the bottom`
     - line 46 is exactly `## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX`
     - line 94 is exactly `Line count: 94`
4. `D:\candlelab\venv\Scripts\python.exe -m json.tool prompts\deepseek_adr160_audit_config.json`
   must succeed (print only "valid" or the error).

## STEP 1 -- Commit the inputs (on adr160-gate)
    git add prompts/deepseek_adr160_audit.md prompts/deepseek_adr160_audit_config.json prompts/cursor_run_deepseek_adr160.md
    git commit -m "ADR-160 DeepSeek R1 audit inputs (brief, config, runner task)"
    git push origin adr160-gate
    git log --oneline -1
Stage NOTHING else. `git branch --show-current` before the commit.

## STEP 2 -- Dry run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_adr160_audit_config.json --dry-run
Expect `Preflight check passed: 9 files verified` (6 code, 2 ADRs, the
brief) and roughly 185,000 chars. STOP and report if preflight fails or
the size is under 160,000 or over 215,000.

## STEP 3 -- Real run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_adr160_audit_config.json
Up to about 10 minutes. On any error, STOP and print it verbatim (redact any
key).

## STEP 4 -- Mechanical checks on `prompts\deepseek_adr160_audit_response.md`
  - total line count and character count
  - YES/NO for each literal: `GIVENS CHECK`, `T-1`, `T-2`, `T-3`, `T-4`,
    `T-5`, `T-6`, `T-7`, `PREMISE VERDICT`, `TEST GAPS`
  - substring `sk-` present? Must be NO; if YES, STOP and do not commit
Do NOT summarise, judge or edit the content.

## STEP 5 -- Commit the response (on adr160-gate)
    git add prompts/deepseek_adr160_audit_response.md
    git commit -m "Add DeepSeek R1 response: ADR-160 gate audit"
    git push origin adr160-gate
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
    PUSHED: <git ls-remote origin adr160-gate>

Line count: 83
