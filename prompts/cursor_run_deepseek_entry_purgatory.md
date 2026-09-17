This message has a line count at the bottom.

# CURSOR TASK -- Commit the entry purgatory inputs and run the DeepSeek R1 audit

## CONTEXT
  - `D:\fxmatrix` -- the operator has saved two files from Claude:
      `prompts\entry_purgatory_memo.md`      (design memo, 119 lines)
      `prompts\deepseek_entry_purgatory.md`  (the brief, 111 lines)
  - `D:\candlelab\scripts\r1_audit.py` -- the audit runner. The API key comes
    only from `D:\candlelab\.env`.

## STEP 0 -- Preconditions
1. In `D:\fxmatrix`: `git pull origin main`; print `git rev-parse --short HEAD`.
2. Print line counts (`(Get-Content <f>).Count`) and STOP on mismatch:
     - `prompts\entry_purgatory_memo.md`     (expect 119)
     - `prompts\deepseek_entry_purgatory.md` (expect 111)
3. Print the first and last line of each; expect line 1 to begin
   `This message has a line count at the bottom` and the last lines to be
   `Line count: 119` / `Line count: 111`.
4. Print line 55 of `prompts\deepseek_entry_purgatory.md`; expect
   `## The proposal (ATTACK it)`. STOP on mismatch.

## STEP 1 -- Commit the inputs (fxmatrix)
    git add prompts/entry_purgatory_memo.md prompts/deepseek_entry_purgatory.md
    git commit -m "Entry purgatory design memo + DeepSeek teardown brief (ADR-152 candidate)"
    git push origin main
    git log --oneline -1
Stage NOTHING else. If `prompts\cursor_run_deepseek_order_purgatory_rev3.md` is
untracked, leave it untracked.

## STEP 2 -- Edit `D:\candlelab\scripts\r1_audit.py` (two edits only)
Edit A. Replace the config block (from `FILES_TO_AUDIT = {` through the
`PROMPT_PATH = ...` line) with exactly:

    FILES_TO_AUDIT = {
        "grind_exitq.mqh": r"d:\fxmatrix\ea\grind_exitq.mqh",
        "grind_engine.mqh": r"d:\fxmatrix\ea\grind_engine.mqh",
        "grind_config.mqh": r"d:\fxmatrix\ea\grind_config.mqh",
        "grind_state.mqh": r"d:\fxmatrix\ea\grind_state.mqh",
        "grind_recon.mqh": r"d:\fxmatrix\ea\grind_recon.mqh",
        "grind_api_counter.mqh": r"d:\fxmatrix\ea\grind_api_counter.mqh",
        "grind_pure.mqh": r"d:\fxmatrix\ea\grind_pure.mqh",
    }
    DOCS_TO_INCLUDE = {
        "entry_purgatory_memo.md": r"d:\fxmatrix\prompts\entry_purgatory_memo.md",
        "ADR-151-order-purgatory.md": r"d:\fxmatrix\docs\architecture\ADR-151-order-purgatory.md",
    }
    LATEST_ADR = None
    PROMPT_PATH = r"d:\fxmatrix\prompts\deepseek_entry_purgatory.md"

Edit B. Change the output path line to exactly:

    output_path = r"D:\fxmatrix\prompts\deepseek_entry_purgatory_response.md"

Print both edited sections. Never print, log or commit any API key.

## STEP 3 -- Dry run
    cd D:\candlelab\scripts
    python r1_audit.py --dry-run
Expect `Preflight check passed: 10 files verified`. STOP and report if preflight
fails, or if the total size is under 80,000 or over 250,000 chars.

## STEP 4 -- Real run
    python r1_audit.py
Up to 10 minutes. On any error, STOP and print it verbatim (redact any key).

## STEP 5 -- Mechanical checks on
`D:\fxmatrix\prompts\deepseek_entry_purgatory_response.md`
  - total line count and character count
  - YES/NO for each literal: `G1`, `G8`, `T-1` .. `T-8`, `GIVENS CHECK`,
    `PREMISE VERDICT`, `OVERRIDE CHECK`
  - substring `sk-` present? must be NO; if YES, STOP
Do NOT summarise, judge or edit the content.

## STEP 6 -- Commit the response (fxmatrix only)
    cd D:\fxmatrix
    git add prompts/deepseek_entry_purgatory_response.md
    git commit -m "Add DeepSeek R1 response: entry purgatory teardown"
    git push origin main
    git log --oneline -1

## NEGATIVE SPACE
- Do not edit the memo, the brief, or anything under `ea\`.
- Do not change any other line of r1_audit.py. Do not commit in candlelab.
- Do not print or commit any API key.
- Do not interpret the audit.

## FINAL REPORT (print exactly these lines)
    FXMATRIX_HEAD_BEFORE: <hash>
    MEMO_LINES: <n>   BRIEF_LINES: <n>   BRIEF_L55_OK: YES|NO
    INPUTS_COMMIT: <hash>
    DRY_RUN_FILES: <n>   DRY_RUN_CHARS: <n>
    RESPONSE_LINES: <n>   RESPONSE_CHARS: <n>
    SECTIONS_ALL_PRESENT: YES|NO (list any missing)
    RESPONSE_COMMIT: <hash>

Line count: 97
