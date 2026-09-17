# HOW DEEPSEEK IS REACHED -- THE r1_audit.py RUNNER

**DeepSeek is called by API from a Python script, not by switching Cursor's
model.** Earlier versions of this file described a Cursor "courier"; that is
not what the operator uses, and a Cursor chat set to its own model will just
summarise the file you hand it.

    Script:  D:\candlelab\scripts\r1_audit.py   (candlelab repo, UNTRACKED)
    Key:     D:\candlelab\.env  ->  DEEPSEEK_API_KEY   (never in code, never printed)
    Model:   deepseek-reasoner  (usage page reports it as a flash model)

The script loads a prompt file plus the files listed in its config block,
preflight-checks every path exists, sends one request, and writes the reasoning
and the report to one output file.

---

## THE FLOW (what worked five times on 2026-09-16)

1. **Claude writes the BRIEF** (bookended, ASCII, source-verified GIVENS, the
   design to attack, threats, required output format).
2. **Claude writes a CURSOR RUN PROMPT** that: pulls; checks the brief's and any
   design doc's line counts; commits them to main; replaces ONLY the config
   block (`FILES_TO_AUDIT`, `DOCS_TO_INCLUDE`, `LATEST_ADR = None`,
   `PROMPT_PATH`) and the `output_path` line of `r1_audit.py`; runs
   `python r1_audit.py --dry-run` and checks file count and character size;
   runs for real; checks the response mechanically; commits the response;
   prints a fixed FINAL REPORT block.
3. **The operator saves Claude's files, pastes the run prompt into Cursor.**
4. **Claude reads the committed response from GitHub** and verifies every
   load-bearing claim against source before accepting or rejecting it.

Worked examples, all in `prompts/`: `deepseek_order_purgatory_rev4.md` (brief),
`deepseek_order_purgatory_rev4_response.md`, and the ADR-151 spec audit pair.
The run prompts themselves were not committed; rebuild from step 2.

---

## CHECKS THAT MATTER

**Attach the source.** The script sends whole files. A design that touches
recon, carry or CloseBy needs those files in `FILES_TO_AUDIT`, or DeepSeek
attacks imagined internals. Payloads of 150k-200k chars worked.

**Check the report exists.** The response file has `## Internal Reasoning` then
`## Final Report`. If nothing follows `## Final Report`, the model ran out of
output (2026-09-16 ADR-151 spec audit: 249k chars of reasoning, empty report).
A literal-presence check passes anyway, because the reasoning mentions every
section name. Check for non-empty text after the final heading.

**Secret check by shape.** `sk-[A-Za-z0-9]{20,}` count must be 0 before commit.
A plain `sk-` substring matches words like `ask-stops`.

**Do not let it re-litigate.** Say what changed, forbid re-raising settled
findings unless the fix fails, and ask for the smallest fix per finding.
DeepSeek otherwise declares premises dead over fixable issues.

---

## OPEN IMPROVEMENTS TO THE RUNNER (not done)

  - Record `response.choices[0].finish_reason`; warn loudly on `length`.
  - Pass an explicit large `max_tokens`.
  - Write reasoning and report to separate files.
  - Add `.env` to candlelab's `.gitignore`; consider tracking the script.

---

## WHEN TO USE DEEPSEEK

Adversarial critique before code exists: order lifecycle, invariants, halts,
reconstruction, geometry, statistics (ARCHITECT s2 mandatory list). Not for
implementation.

**Do not send an audit built on a theory you cannot support.** Build the lens
first, then audit what it shows.
