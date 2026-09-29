This message has a line count at the bottom.

# CURSOR TASK -- Run the ADR-164 DeepSeek R1 audit

Workspace: `D:\fxmatrix` (NOT `D:\pipshed`). Start a NEW Cursor chat.
Pattern: `docs/deepseek_prompts_templates/deepseek_r1_audit_pattern_HOWTO.md`.
Cursor drives the runner only; it does not act as DeepSeek and does not
interpret the audit. The runner is config-driven
(`tools\r1_audit\r1_audit.py --config`), so there is NO script edit step.

## CONTEXT
  - `D:\fxmatrix` on branch `adr164-deal-replay`. The inputs are ALREADY
    committed on it (the commit after `7ff1c97`; suite 2350/2350 on
    GBPUSD and EURUSD at `7ff1c97`):
      `prompts\deepseek_adr164_audit.md` (the brief, 157 lines)
      `prompts\deepseek_adr164_audit_config.json` (the runner config)
      `prompts\cursor_run_deepseek_adr164.md` (this task)
    The runner reads `ea\` and the ADR from this working copy, so it
    MUST stay on this branch head. The EA code at the head is identical
    to `7ff1c97`.
  - Interpreter: `D:\candlelab\venv\Scripts\python.exe`. The API key lives only
    in `D:\candlelab\.env`; never print, log or commit it.

## STEP 0 -- Preconditions (STOP on any mismatch)
1. `git fetch origin`; `git switch adr164-deal-replay`; `git pull --ff-only`;
   `git branch --show-current` must print `adr164-deal-replay`;
   `git rev-parse --short HEAD` must equal
   `git rev-parse --short origin/adr164-deal-replay`; report it.
2. `git diff --stat 7ff1c97 HEAD -- ea/ docs/` must print nothing.
3. `git status -s` must show no modified tracked files (untracked are
   fine; report them).
4. Brief checks on `prompts\deepseek_adr164_audit.md`:
     - `(Get-Content <f>).Count` is 157
     - line 1 begins `This message has a line count at the bottom`
     - line 99 is exactly `## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX`
     - line 157 is exactly `Line count: 157`
5. `D:\candlelab\venv\Scripts\python.exe -m json.tool prompts\deepseek_adr164_audit_config.json`
   must succeed (print only "valid" or the error).

## STEP 1 -- Dry run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_adr164_audit_config.json --dry-run
Expect `Preflight check passed: 9 files verified` (7 code, 1 doc, the
brief) and roughly 301,000 chars. STOP and report if preflight fails or
the size is under 290,000 or over 315,000.

## STEP 2 -- Real run
    D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\deepseek_adr164_audit_config.json
Up to about 10 minutes. On any error (including a context-length error),
STOP and print it verbatim (redact any key). Do not trim inputs to retry.

## STEP 3 -- Mechanical checks on `prompts\deepseek_adr164_audit_response.md`
  - total line count and character count
  - YES/NO for each literal: `GIVENS CHECK`, `T-1`, `T-2`, `T-3`, `T-4`,
    `T-5`, `T-6`, `T-7`, `T-8`, `T-9`, `PREMISE VERDICT`, `TEST GAPS`
  - substring `sk-` present? Must be NO; if YES, STOP and do not commit
Do NOT summarise, judge or edit the content.

## STEP 4 -- Commit the response (on adr164-deal-replay)
    git add prompts/deepseek_adr164_audit_response.md
    git commit -m "Add DeepSeek R1 response: ADR-164 audit (missed-deal replay, C77)"
    git push origin adr164-deal-replay
    git log --oneline -1
Stage NOTHING else. `git branch --show-current` before the commit.

## NEGATIVE SPACE
- Do not edit the brief, the config, the runner, or anything under `ea\`
  or `docs\`.
- Do not switch to another branch, merge, rebase, stash, amend, or open a PR.
- Do not compile or run anything in MetaTrader.
- Do not print or commit any API key. Do not interpret the audit.
- No `git add .` / `git add -u`. ASCII only.

## FINAL REPORT (print exactly these lines)
    BRANCH_HEAD_BEFORE: <hash>
    EA_DOCS_DIFF_VS_7FF1C97: empty|<stat>
    BRIEF_LINES: <n>   MID_ANCHOR_OK: YES|NO   CONFIG_JSON: valid|<error>
    DRY_RUN_FILES: <n>   DRY_RUN_CHARS: <n>
    RESPONSE_LINES: <n>   RESPONSE_CHARS: <n>
    SECTIONS_ALL_PRESENT: YES|NO (list any missing)
    KEY_LEAK: NO|YES
    RESPONSE_COMMIT: <hash>
    PUSHED: <git ls-remote origin adr164-deal-replay>

Line count: 84
