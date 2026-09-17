# How we send a prompt to DeepSeek (r1_audit runner, current pattern)

DeepSeek R1 is reached through an API runner script, `D:\candlelab\scripts\r1_audit.py`.
The key lives only in `D:\candlelab\.env` and is never printed, logged or committed.
Cursor does NOT act as DeepSeek: Cursor only drives the runner (commit inputs, edit two
config lines, dry run, real run, mechanical checks, commit the response).

## Three files per consult (Claude writes all three; operator saves them)
1. **The memo** -- `prompts/<topic>_memo.md`. The design being torn down, written for a
   reader with the source. Context for the runner, not the task itself.
2. **The brief** -- `prompts/deepseek_<topic>.md`. The actual task: role, fixed frame
   (do-not-retail-judge), source-verified GIVENS, the proposal to attack, numbered
   threats, and the required output format.
3. **The Cursor runner task** -- `prompts/cursor_run_deepseek_<topic>.md`. The prompt
   the operator pastes into Cursor. Steps 0-6 as below.

## The runner task, step by step (copy `cursor_run_deepseek_entry_purgatory.md`)
- **Step 0 preconditions.** `git pull`; print each input's line count and first/last
  line; print the brief's mid-anchor line. STOP on any mismatch. This is what replaced
  the old courier integrity gate: truncation is caught before anything runs.
- **Step 1.** Commit ONLY the memo and the brief. Stage nothing else.
- **Step 2.** Two edits to `r1_audit.py`, printed back:
  - the config block: `FILES_TO_AUDIT` (the ea/ files this teardown actually needs),
    `DOCS_TO_INCLUDE` (memo plus any ADR), `LATEST_ADR`, `PROMPT_PATH` (the brief);
  - `output_path` -> `prompts/deepseek_<topic>_response.md`.
- **Step 3.** `python r1_audit.py --dry-run`. Expect "Preflight check passed: N files
  verified" and a payload size in the expected band; STOP outside it.
- **Step 4.** `python r1_audit.py`. Up to ~10 minutes. Any error: STOP, print verbatim,
  redact keys.
- **Step 5.** Mechanical checks on the response only: line and character counts,
  YES/NO for each required literal (`GIVENS CHECK`, `T-1`..`T-n`, `PREMISE VERDICT`,
  `OVERRIDE CHECK`), and `sk-` must be absent. No summarising, judging or editing.
- **Step 6.** Commit the response file in fxmatrix only.
- **Final report block.** Fixed lines: heads, line counts, commit hashes, dry-run
  numbers, sections-present.

## Conventions that make it reliable
- ASCII only in every file (MQL5 and agent tooling choke on non-ASCII).
- Line-count bookends on memo and brief:
  - first line begins `This message has a line count at the bottom`
  - last line is exactly `Line count: N` (N = real total)
- A stable MID-FILE anchor (a heading at a known line number) checked in Step 0, so
  truncation in the middle is caught, not just at the ends.
- Re-count and update the runner task whenever the brief changes.
- The brief carries its own required output format and a final OVERRIDE CHECK line, so
  the response is structured and parseable.
- Claude verifies the response's load-bearing claims against real source before using
  it -- DeepSeek over-flags, so its verdicts are not taken on trust.

## Worked example (current)
- `prompts/entry_purgatory_memo.md` (119 lines) -- the memo
- `prompts/deepseek_entry_purgatory.md` (111 lines) -- the brief, mid anchor at line 55
- `prompts/cursor_run_deepseek_entry_purgatory.md` (97 lines) -- the runner task

## Superseded
`deepseek_courier_pattern_HOWTO.md` describes an older route where Cursor itself was
switched to the DeepSeek R1 model and loaded the brief behind an integrity gate. That
is no longer how DeepSeek is reached. `deepseek_straddle_rebuild.md` remains a good
BRIEF template; `cursor_courier_deepseek_straddle_rebuild.md` is superseded by the
runner task above.
