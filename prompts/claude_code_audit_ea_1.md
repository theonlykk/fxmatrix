Good workflow. Here's the Claude Code prompt:

---

You are implementing three bug fixes in the FXMatrix EA codebase at `d:\fxmatrix\ea\`. Read all files in that directory before proposing any fixes.

You have an audit report identifying three WARNING findings. For each finding, propose the exact code change with file name, line numbers, and the replacement code. Do NOT implement anything yet — propose only.

**W1 — AuditExitLimits does not validate exit ticket liveness**
File: `FXMatrix.mq5`, function `AuditExitLimits()`
Current code skips a layer if `ArraySize(L.exit_tickets) > 0` without verifying the ticket still exists on the broker via `OrderSelect()`. If the broker silently cancelled the exit limit, the layer is stranded forever.
Proposed fix: wrap the `ArraySize(L.exit_tickets) > 0` check with an `OrderSelect()` validation loop. If all tickets are stale, clear the array and fall through to re-placement.

**W2 — add_next re-arm does not validate stale ticket**
File: `FXMatrix.mq5`, OnTick add_next re-arm block
Current code only re-arms when `g_add_next[inst] == 0`. If the broker silently cancelled a non-zero `g_add_next[inst]` ticket, the re-arm never fires.
Proposed fix: before the `g_add_next[inst] == 0` check, add an `OrderSelect(g_add_next[inst])` validation. If it fails and the ticket is non-zero, zero the global and log a warning.

**W3 — Resume quoting in HandleExitFill uses score-dependent routing**
File: `ExecutionEngine.mqh`, function `HandleExitFill()`, resume two-way quoting block
Current code uses score-dependent `inst_strongest/inst_weakest` derivation identical to the bug that caused the machine-gun incident today. When scores are equal, indices collapse to same value, directions invert, marketable orders fire.
Also: the two `PlaceEntryLimit` calls in this block are missing the `inst` 4th parameter added in commit `5bcd31a`.
Proposed fix: replace the score-dependent block with the same structural `bid_strongest/bid_weakest` and `offer_strongest/offer_weakest` mapping already in the flat-quoting loop in `FXMatrix.mq5`. Pass `inst` as 4th argument to both `PlaceEntryLimit` calls.

**Output format:** For each finding, show:
1. Exact file and line numbers of the block being replaced
2. The current code (verbatim)
3. The proposed replacement code

Do not implement. Propose only.

---