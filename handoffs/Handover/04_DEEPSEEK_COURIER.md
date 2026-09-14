# THE DEEPSEEK COURIER PATTERN

DeepSeek is NOT called directly. It is reached by having **Cursor, switched to
the DeepSeek R1 model**, load a brief from disk, integrity-check that it loaded
whole, hard-stop if it did not, and only then run the task and write the answer
back to disk.

**Why the integrity gate exists:** pasting a long brief through another tool
silently truncates. The gate catches that BEFORE DeepSeek answers a half-loaded
prompt.

---

## THE CANONICAL DOCS -- READ THESE, DO NOT RE-DERIVE

In the fxmatrix repo, `docs/deepseek_prompts_templates/`:

| File | What it is |
|---|---|
| `deepseek_courier_pattern_HOWTO.md` | the full procedure and conventions |
| `deepseek_straddle_rebuild.md` | a real BRIEF, 106 lines, use as a template |
| `cursor_courier_deepseek_straddle_rebuild.md` | the matching COURIER wrapper |

Further worked examples live in `prompts/` --
`DEEPSEEK_TEARDOWN_V2.5_ratchet.md` and its `_response.md`,
`DEEPSEEK_TEARDOWN_BCC.md` and its response,
`TEMPLATE_cursor_deepseek_handoff.md`.

---

## THE FLOW

1. **Claude writes TWO files** to `prompts/`: the BRIEF (the task for DeepSeek)
   and the COURIER wrapper (the prompt the operator pastes into Cursor).
2. The operator saves the brief to `D:\fxmatrix\prompts\<name>.md` byte-exact.
3. He sets Cursor's model to DeepSeek R1 and pastes the COURIER wrapper.
4. Cursor loads the brief, runs the integrity gate, and either prints
   **"COURIER HARD STOP -- brief did not load intact"** and answers nothing, or
   performs the task and writes `prompts/<name>_response.md`.
5. The operator pastes the response back, in chunks. **Wait for "finished".**
6. **Claude verifies the response's load-bearing claims against real source
   before using it. DeepSeek over-flags; its verdicts are not taken on trust.**

---

## CONVENTIONS THAT MAKE IT RELIABLE

**ASCII only** in every file. No smart quotes or em-dashes -- MQL5 and agent
tooling choke on non-ASCII.

**Line-count bookends on the BRIEF.** First line EXACTLY
`This message has a line count at the bottom.` Last line EXACTLY
`Line count: N`, with N the real total.

**A stable MID-FILE anchor** -- a heading on a known line number -- as a third
integrity check, so truncation in the MIDDLE is caught, not just at the ends.

**The courier's integrity signature must match** the brief's actual line 1, the
mid anchor and its line number, the last line, and the total N. **If you edit
the brief, re-count and update the courier.**

**The brief carries its own required output format** and a final OVERRIDE CHECK
line, so the response comes back structured and parseable.

---

## THE INTEGRITY GATE -- WHAT CURSOR CHECKS

    line 1        == "This message has a line count at the bottom."
    line <MID>    == "<the exact mid-file heading>"
    last line     == "Line count: <N>"
    total lines   == <N>

Print each PASS/FAIL with the observed value. **HARD STOP on any FAIL.** Never
answer a brief that did not load intact.

---

## WHEN TO USE DEEPSEEK AT ALL

Adversarial red-team critique of a mathematical framework, or finding
pathologies **before** code exists. Not for implementation, not for review of
working code.

**Do not send an audit built on a theory you cannot support.** On 2026-09-14
Gemini rejected a DeepSeek audit on exactly these grounds: auditing an unknown
state transition without a telemetry payload is guessing, and the round trip is
wasted. Build the lens first, then audit what it shows.
