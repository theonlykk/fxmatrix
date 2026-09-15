# 05 -- GIT AS TRANSPORT

Specs and Cursor responses travel through the repo, not through the chat
window. All three parties can already reach it.

| | reads repo | writes repo | pushes |
|---|---|---|---|
| Claude | yes -- clones and reads any PUSHED branch | no | no |
| Cursor | yes | yes | yes, to branches |
| Operator | yes | yes | yes, merges to main |

Note the word PUSHED. Claude reads GitHub, not your disk. A branch that
exists locally is invisible to it. This cost two round trips on 2026-09-14:
Cursor committed and reported done, the operator relayed "done", and Claude
could see nothing. See `02_TRAPS.md`.

---

## DIRECTION 1 -- SPEC GOING IN

1. Claude writes the spec to a file.
2. The operator saves it to `prompts/<task-name>.md`, commits, pushes.
3. **Claude reads it back off the branch and diffs it against what it
   generated.** This is the integrity check -- not a self-count by Cursor.
   The failure mode is no longer truncated paste; it is a mangled save, an
   editor rewriting line endings, or a partial drag, and all three are
   invisible to whoever reads the file afterwards because what they read is
   internally consistent. Claude has the original and can compare.
4. Only then does the operator paste this to Cursor, and nothing else:

       Read prompts/<task-name>.md at commit <sha> and execute it exactly as
       written. It contains its own audit trail, negative space, failure
       modes and response format. Do not deviate. If the file does not end
       with a line reading "Line count: N" where N is the actual number of
       lines, STOP and report that it did not load whole. Report the commit
       you read it at.

Naming the commit matters. "Read prompts/x.md from the repo" is satisfied by
a stale copy on whatever branch Cursor happens to be sitting on. Naming the
sha makes a stale read visible instead of silent.

The line-count bookend stays, but it is now the cheap check. The diff is the
real one.

This is the DeepSeek courier pattern (see
`docs/deepseek_prompts_templates/deepseek_courier_pattern_HOWTO.md`) applied
to Cursor.

---

## DIRECTION 2 -- RESPONSE COMING BACK

Every spec's RESPONSE FORMAT section ends with:

    Write your full response to prompts/<task-name>_response.md on the same
    branch. PUSH the branch to origin. Reply in chat with ONLY: the branch
    name, the commit hashes AS THEY EXIST ON ORIGIN, and one line saying the
    report is pushed.

Two deliberate choices there.

**`prompts/<task>_response.md`, not a new `reports/` directory.** The
original proposal was `reports/`, gitignored from main and left on feature
branches. That does not work: `.gitignore` is a single file at the repo root
and is not branch-scoped, so an ignored path cannot be committed on a feature
branch either. `prompts/` already exists and is already the courier
convention. One fewer thing to explain.

**"As they exist on origin."** This makes "done" mean pushed by
construction, rather than meaning "committed somewhere Claude cannot see".

---

## A REPORT FILE IS STILL A SELF-REPORT

This is the part not to lose.

Writing Cursor's summary to a file and committing it makes it *committed*,
which on this project is a word that means verified. It is not. It is the
same unreliable summary with a git hash attached, and the risk is that the
hash launders it.

ARCHITECT s5 is unchanged: **read the branch, not the response.** The report
file is a convenience for transporting diffs and ADR text without pasting.
It is not evidence.

Put this line at the top of every response file:

    UNVERIFIED WORKING MATERIAL -- verify against the branch, not this file.

---

## WHAT STILL HAS TO BE PASTED BY HAND

**Test output. Only test output.**

ARCHITECT forbids CLI compile for MQL5 -- it silently no-ops when a GUI
instance is open, exit codes have been observed inverted, and a stale log
reads as a current result. The suite is run by the operator in the MetaEditor
GUI and Cursor never sees the result.

Keep that paste small:

    Select-String -Path D:\fxmatrix\temp\tests.txt -Pattern '^FAIL \|' |
      ForEach-Object { ($_.Line -split "`t")[-1] }
    Select-String -Path D:\fxmatrix\temp\tests.txt -Pattern 'SUMMARY' |
      ForEach-Object { ($_.Line -split "`t")[-1] }

**Do not use `'FAIL|SUMMARY'`** -- a dozen test NAMES contain the word "fail"
and a real failure hides among them. That is how a genuinely broken test sat
unnoticed for three runs.

**Report the SUMMARY total, not just the FAIL lines.** Some regressions
change the assertion COUNT rather than producing a failure. See
`HANDOFF_2026-09-14c.md` s5.

---

## WHAT THIS DOES NOT CHANGE

- Cursor commits to branches only, never to main. The operator merges after
  verification.
- Claude verifies against committed source. Reading the branch IS the
  verification -- do not skip it because the response file says it went well.
- `git diff --stat origin/main..<branch>` before merging. A Cursor branch
  once silently reverted a merged ADR because it branched from a stale
  commit. The diffstat was the only thing that showed it.
- Every prompt still carries a BRANCH INSTRUCTION naming the branch, the
  number of commits, **push**, do NOT merge, do NOT open a PR. Omitting the
  word "push" is what caused the 2026-09-14 round trips; a branch name in an
  audit-trail table is not an instruction.

---

## ONE THING TO CHECK BEFORE RELYING ON THIS

Claude reads both repos by **unauthenticated clone**. That works today
because both are public.

Making fxmatrix private does not degrade this. It removes it. Specs,
branches, diffs and verification all go back to pasting, with no warning and
no fallback.

So the repo-privacy decision and this workflow are coupled, and the privacy
decision must be tested before it is taken:

  1. Create a throwaway private repo.
  2. Ask Claude to clone it.
  3. Only then decide.

Do not flip fxmatrix and find out afterwards.
