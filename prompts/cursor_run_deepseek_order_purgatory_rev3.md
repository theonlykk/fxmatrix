This message has a line count at the bottom.

# CURSOR TASK -- Commit order purgatory rev 3 and run the DeepSeek R1 audit

## CONTEXT
  - `D:\fxmatrix` -- the operator has saved two files from Claude:
      `docs\architecture\MEMO_2026-09-16_order_purgatory.md` (rev 3, overwrites rev 2)
      `prompts\deepseek_order_purgatory_rev3.md` (the brief)
  - `D:\candlelab\scripts\r1_audit.py` -- the audit runner (already edited last
    run; the API key now comes only from `D:\candlelab\.env`).

## STEP 0 -- Preconditions
1. In `D:\fxmatrix`: `git pull origin main`; print `git rev-parse --short HEAD`.
2. Print line counts (`(Get-Content <f>).Count`) and STOP on mismatch:
     - `docs\architecture\MEMO_2026-09-16_order_purgatory.md` (expect 263)
     - `prompts\deepseek_order_purgatory_rev3.md`             (expect 118)
3. Print the first line and last line of each; expect line 1 to begin
   `This message has a line count at the bottom` and the last line to be
   `Line count: 263` / `Line count: 118`.
4. If `prompts\gemini_order_purgatory_rev2.md` exists, report whether it is
   tracked (`git ls-files`). Do NOT commit it; it is superseded.

## STEP 1 -- Commit the inputs (fxmatrix)
    git add docs/architecture/MEMO_2026-09-16_order_purgatory.md prompts/deepseek_order_purgatory_rev3.md
    git commit -m "Order purgatory memo rev 3 (exit queue, capacity formula) + DeepSeek rev 3 brief"
    git push origin main
    git log --oneline -1
Stage NOTHING else.

## STEP 2 -- Edit `D:\candlelab\scripts\r1_audit.py` (two edits only)
Edit A. Replace the config block (from `FILES_TO_AUDIT = {` through the
`PROMPT_PATH = ...` line) with exactly:

    FILES_TO_AUDIT = {
        "grind_engine.mqh": r"d:\fxmatrix\ea\grind_engine.mqh",
        "fxgrind.mq5": r"d:\fxmatrix\ea\fxgrind.mq5",
        "grind_recon.mqh": r"d:\fxmatrix\ea\grind_recon.mqh",
        "grind_quarantine.mqh": r"d:\fxmatrix\ea\grind_quarantine.mqh",
        "grind_carry.mqh": r"d:\fxmatrix\ea\grind_carry.mqh",
        "grind_closeby.mqh": r"d:\fxmatrix\ea\grind_closeby.mqh",
    }
    DOCS_TO_INCLUDE = {
        "MEMO_2026-09-16_order_purgatory.md": r"d:\fxmatrix\docs\architecture\MEMO_2026-09-16_order_purgatory.md",
    }
    LATEST_ADR = None
    PROMPT_PATH = r"d:\fxmatrix\prompts\deepseek_order_purgatory_rev3.md"

Edit B. Change the output path line to exactly:

    output_path = r"D:\fxmatrix\prompts\deepseek_order_purgatory_rev3_response.md"

Print both edited sections. Never print, log or commit any API key.

## STEP 3 -- Dry run
    cd D:\candlelab\scripts
    python r1_audit.py --dry-run
Expect `Preflight check passed: 8 files verified` and roughly 180,000 chars.
STOP and report if preflight fails or the size is under 150,000 or over 230,000.

## STEP 4 -- Real run
    python r1_audit.py
Up to 10 minutes. On any error, STOP and print it verbatim (redact any key).

## STEP 5 -- Mechanical checks on
`D:\fxmatrix\prompts\deepseek_order_purgatory_rev3_response.md`
  - total line count and character count
  - YES/NO for each literal: `T-1` .. `T-9`, `GIVENS CHECK`, `PREMISE VERDICT`,
    `OVERRIDE CHECK`
  - substring `sk-` present? must be NO; if YES, STOP
Do NOT summarise, judge or edit the content.

## STEP 6 -- Commit the response (fxmatrix only)
    cd D:\fxmatrix
    git add prompts/deepseek_order_purgatory_rev3_response.md
    git commit -m "Add DeepSeek R1 response: order purgatory rev 3 teardown"
    git push origin main
    git log --oneline -1

## NEGATIVE SPACE
- Do not edit the memo, the brief, or anything under `ea\`.
- Do not change any other line of r1_audit.py. Do not commit in candlelab.
- Do not print or commit any API key.
- Do not interpret the audit.

## FINAL REPORT (print exactly these lines)
    FXMATRIX_HEAD_BEFORE: <hash>
    MEMO_LINES: <n>   BRIEF_LINES: <n>
    GEMINI_REV2_FILE: ABSENT | UNTRACKED | TRACKED
    INPUTS_COMMIT: <hash>
    DRY_RUN_FILES: <n>   DRY_RUN_CHARS: <n>
    RESPONSE_LINES: <n>   RESPONSE_CHARS: <n>
    SECTIONS_ALL_PRESENT: YES|NO (list any missing)
    RESPONSE_COMMIT: <hash>

Line count: 95
