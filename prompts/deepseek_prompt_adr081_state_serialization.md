# DeepSeek Review Request — ADR-081 Struct Serialization Safety
## Read-Only Adversarial Code Review — No Implementation

---

## Mandate

This is a **read-only structural review**. You have been given the
contents of several files for context. Do not output modified code, a
diff, or a proposed fix — findings and citations only. If you believe
a fix is warranted, describe *what* is needed in prose; do not write it.

Every claim must cite the **exact file and line range** it comes from.
If you cannot verify something directly from the provided source,
say so explicitly rather than asserting it as fact — an unsupported
guess is worse than no answer, given this exact question already has a
history of costly wrong assumptions this session (see Context below).

---

## Context

FXMatrix (MQL5 trading EA) persists its core `Layer` struct to JSON via
`SaveAllInventoryState()` and reloads it via `LoadInventoryState()` on
every reattach/restart, and (separately) at the start of every Strategy
Tester backtest run.

We are about to add three new fields to `Layer`:

```mql5
datetime last_exit_retry_time;
datetime first_exit_retry_time;
bool     exit_escalated;
```

These will drive a new retry-throttle and one-shot escalation-alert
mechanism (`ADR-081`) inside `AuditExitLimits()`. Before implementing,
we need to understand exactly how the serialization layer will behave
when it encounters state files that predate this change.

**Why this matters more than a routine schema question:** this session
already confirmed, from direct log evidence, a real production incident
where a stale JSON state file — persisting across separate Strategy
Tester executions — was loaded into a fresh run and produced a
corrupted layer (an `entry_time` recorded chronologically *after* its
own `exit_time`, only possible if the layer was never actually created
during that run at all). That confirmed failure mode is the reason this
question is being asked carefully rather than assumed safe.

---

## Questions

**A) Report the exact serialization mechanism.** Is `Layer`→JSON
conversion hand-rolled string construction/parsing, a library, or
something else? Cite the exact functions and file/line ranges for both
the write path (`SaveAllInventoryState` / whatever it calls) and the
read path (`LoadInventoryState`).

**B) Trace precisely what happens when `LoadInventoryState()` reads a
JSON file saved *before* these three fields existed** — i.e., the keys
`last_exit_retry_time`, `first_exit_retry_time`, `exit_escalated` are
simply absent from the file. Does the parsing code:
- default missing keys to zero-value equivalents (`0`, `0`, `false`) safely,
- read uninitialized/garbage memory,
- throw a runtime error or skip the layer entirely, or
- something else?

Report the actual code path that would execute, not an assumption
about how "JSON parsers typically behave" — quote the real logic.

**C) Given the confirmed prior corruption finding above**, could a
stale pre-`ADR-081` state file, loaded by a binary that now includes
these three fields, produce values that feed incorrectly into the new
throttle/escalation logic? Concretely:
- Could a garbage non-zero `first_exit_retry_time` cause the
  `ExitRetryMaxSeconds` escalation alert to fire immediately/incorrectly
  on load, before any real retry has actually happened?
- Could a garbage `last_exit_retry_time` incorrectly block a
  legitimate first retry attempt for longer than intended?
- Could `exit_escalated` load as `true` when it was never actually
  escalated, permanently suppressing a real future alert for that layer?

**D) Is this a systemic pattern, or specific to `Layer`?** Check
whether any *other* struct in the provided files is serialized to disk
using the same mechanism identified in (A). If so, does it share the
same missing-field behavior identified in (B)? We want to know whether
fixing this for `Layer` addresses an isolated case or a class of risk
across the codebase.

**E) Recommendation.** Based on (A)–(D), state plainly: is an explicit
defensive check needed at load time (e.g., sanity-bounding these three
fields regardless of what the file contains, or an explicit schema-
version check), or is the existing mechanism already safe as-is? Give
your reasoning, not just a yes/no.

---

## Explicitly Out of Scope

- Do not propose or output the `ADR-081` throttle/escalation logic
  itself — that has already been designed and ruled on separately.
  This review is scoped **only** to the serialization/backward-
  compatibility question above.
- Do not suggest unrelated refactors, style changes, or improvements
  to code outside this specific question.
