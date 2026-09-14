# TRAPS -- HOW THE PREVIOUS CHAT GOT THINGS WRONG

Each cost real time. Several were repeated TWICE in a single session, which is
why they are written down. **Append to this file when it happens again.**

---

## MEASUREMENT

**`api_count` is FLEET-WIDE, not per-instance.** It is one terminal
GlobalVariable (`GRIND_DAILY_API_COUNT`, no magic in the name) that every
instance increments. Twelve instances reporting 1941 means the FLEET made 1941
requests, not 23,292. I first summed them, then read one as the fleet's. Both
wrong, in opposite directions, and three handoffs of capacity conclusions rested
on the error.

**Two clocks. Do not compare them.** Terminal log timestamps are local;
`received_at` in the archive is pipshed's wall clock; `deal_time_broker` is
broker time (GMT+3). **Broker midnight is 21:00 UTC = 17:00 Toronto.** I ordered
two events across two clocks and drew the wrong conclusion about which caused
which.

**`received_at` is the FLUSH time, not the event time.** Rows sharing a
microsecond were queued together, not simultaneous. `halted_at_receipt`, by
contrast, IS stamped at transaction time and can be trusted for ordering.

---

## GREPPING

**A grep for `failed` or `HALT` matches HEARTBEAT JSON.** Every heartbeat
contains `peer_read_failed` and `halt_reason`. A grep for `failed` returned
15,621 "failures" that were all telemetry. The halt line is
`CRITICAL_INVARIANT_FAIL` inside a TELEM line.

**A grep for `FAIL|SUMMARY` in test output buries real failures.** A dozen test
NAMES contain "fail" (`C5 second fails`, `I5c fail`, `AR7 fail post`). Use
`'^FAIL \|'` after stripping the tab prefix. This is exactly how a genuinely
broken test (R1) sat unnoticed across three runs.

**Reconcile pass COUNTS between runs, not just the FAIL list.** 910/910 became
909/910 and I did not notice. Then the SAME COMMIT produced both numbers --
which is how the suite was found to be non-deterministic (MQL5 GlobalVariables
persist between script runs; `Test_SuiteResetGlobals` now clears them).

---

## READING CODE

**Never characterise a function from its body. READ ITS CALL SITES.** I
described `Grind_TryRecenterOppositeL0` as a "stranded-order rescue" from the
distance gate inside it, without reading the twenty lines below that show it
fires ONLY when the opposite side holds layers. It is ADR-124's fill-triggered
recentre. The operator corrected me. **Same class of error three times in one
session**, all from reading 20-40 line extracts and treating "I read the
function" as "I understand when it runs".

**Check the ORDER of operations, not just their presence.**
`Grind_ArchiveRecordFill` runs BEFORE the `if(g_grind_halted) return` guard, so
`halted_at_receipt=true` means the instance was ALREADY halted. Getting that
backwards produced a completely inverted causal story.

---

## GIT

**Confirm the merge actually landed.** Four tested branches sat unmerged and
silently blocked work for a full session: the export script, a loader fix, the
carry cost model, and the ring-extension PAIRS list. Run `git log --oneline -1
origin/main` after every merge.

**Read `git diff --stat origin/main..<branch>` BEFORE merging.** One Cursor
branch silently REVERTED a merged ADR -- 98-line ADR file deleted, constant
removed, tests gone -- because it branched from a stale commit. The diffstat was
the only thing that showed it.

**A branch rebuild changes every hash.** Always `git fetch` and re-read. Cursor
once rebuilt a branch to amend the test commit and dropped the fix commit
entirely.

**Check `git branch --show-current` before anything.** Both the desktop and the
Surface have been found sitting on a research branch, which turns
`git pull origin main` into a MERGE into that branch.

**ADR numbering is SHARED across fxmatrix and pipshed.** Neither repo can see
the other's files. Check both. 140 is burned on an abandoned branch.

---

## REASONING

**State a claim with the evidence you actually have.** In one investigation I
proposed four causes in sequence and the data contradicted all four:
"favourable slippage" (the sign was backwards), "systematic adverse slippage"
(measured: mean +0.1 pips), "inconsistent enforcement" (CloseBy runs before the
invariant check), and "the exit fill caused the halt" (the halt came first).

The useful output was not a theory. It was noticing that **the halt marker
carried no detail** -- which became ADR-141, and answered the next occurrence in
seconds instead of an hour.

**When the operator pushes back on a technical claim, check before defending
it.** Every time he did, he was right and I was pattern-matching.

**Measure before specifying a fix.** Twice a spec was written on an assumption
that the data then contradicted. `archive_counts.py` flags exist for this.

---

## OPERATIONAL

**Dragging an order line on an MT5 chart modifies it INSTANTLY** -- no
confirmation, no undo. The operator moved an exit 5 pips while trying to
maximise a chart and I6 halted the instance. Mitigation: chart Properties ->
Show -> untick "Show trade levels" on VPS charts.

**Detaching EAs is safe only for the book AS IT STANDS.** Orders that fill
afterwards get NO exit. Nine positions were left naked overnight this way.

**With EAs attached but algo OFF**, every instance keeps attempting on every
tick and the terminal rejects locally with retcode 10027, which still counts in
`api_count`. Detach rather than leaving them attached.

**A recompile REINITIALISES attached EAs** and resets in-memory daily counters
(`realised_pnl_today`, `scalps`). Use the archive for daily totals.

**Both arms of a pair log as `fxgrind (GBPUSD,M5)`** with nothing to
distinguish OPT from ALT. ADR-141 added an instance prefix to EA Prints.
