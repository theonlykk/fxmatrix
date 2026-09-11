# How we send a prompt to DeepSeek (via Cursor as courier)

DeepSeek is NOT called directly. It is reached by having Cursor -- switched to the
DeepSeek R1 model -- load a brief from disk, integrity-check that it loaded whole,
hard-stop if it did not, and only then run the task and write the answer back to disk.
This exists because pasting a long brief through another tool silently truncates; the
integrity gate catches that before DeepSeek answers a half-loaded prompt.

## The flow (Phase 1 red-team teardown, but the pattern is general)
1. Claude writes TWO files to the repo `prompts/` folder:
   - the BRIEF (the actual task for DeepSeek)
   - the COURIER wrapper (the prompt you paste into Cursor)
2. You save the brief to `d:\fxmatrix\prompts\<name>.md` byte-exact.
3. You set Cursor's model to DeepSeek R1 and paste the COURIER wrapper.
4. Cursor loads the brief, runs the integrity gate, and:
   - if any check FAILS -> prints "COURIER HARD STOP -- brief did not load intact" and
     answers nothing (you re-save the brief and retry);
   - if all PASS -> performs the task and writes `prompts/<name>_response.md`.
5. You paste the response back to Claude (in chunks; Claude waits for "finished").
6. Claude verifies the response's load-bearing claims against real source before using
   it -- DeepSeek over-flags, so its verdicts are not taken on trust.

## Conventions that make it reliable
- ASCII only in every file (no smart quotes / em-dashes) -- MQL5/agent tooling chokes
  on non-ASCII.
- Line-count bookends on the BRIEF:
  - first line EXACTLY: `This message has a line count at the bottom.`
  - last line EXACTLY:  `Line count: N`   (N = real total line count)
- Pick a stable MID-FILE anchor (a heading on a known line number) as a third
  integrity check, so truncation in the middle is caught, not just the ends.
- The courier's integrity signature must match the brief's actual line 1, the mid
  anchor line/number, the last line, and the total N. If you edit the brief, re-count
  and update the courier.
- The brief carries its own "required output format" and a final OVERRIDE CHECK line so
  the response is structured and parseable.

## The courier integrity gate (what Cursor checks)
- line 1        == "This message has a line count at the bottom."
- line <MID>    == "<the exact mid-file heading>"
- last line     == "Line count: <N>"
- total lines   == <N>
Print each PASS/FAIL with the observed value. HARD STOP on any FAIL. Never answer a
brief that did not load intact.

## Worked example (attached)
Two real files from a session, use them as templates:
- `deepseek_straddle_rebuild.md`            -- the BRIEF (106 lines; bookended; GIVENS +
                                               threats + required output format)
- `cursor_courier_deepseek_straddle_rebuild.md` -- the COURIER wrapper (integrity gate
                                               keyed to line 1 / line 50 / "Line count:
                                               106" / total 106; hard-stop; writes
                                               prompts/deepseek_straddle_rebuild_response.md)

Copy those two, swap in your own brief content, re-count the lines, and update the four
integrity values in the courier to match. That's the whole pattern.
