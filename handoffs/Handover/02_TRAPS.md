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

---

## CAPACITY AND THE LIVE BOOK (2026-09-16)

**The account slot limit counts POSITIONS + PENDING ORDERS.** FTMO demo is
200. MT5 docs describe `ACCOUNT_LIMIT_ORDERS` as pending-only; on this account
the refusals came with 113 pending and 194 total. Read it with a script, not
the docs. The previous chat spent three handoffs on API-request capacity
while this limit was the one that halts.

**`retcode=10040` with `duration_ms=0` is the terminal refusing locally.** The
Journal text is "[Position limit reached]". It refuses the NEWEST order,
which after a fill is the exit.

**Detaching an EA frees no slots.** Its positions, exits and resting entries
all stay in the book and still count.

**On a hedging account an exit fill does not close the position.** It opens
an opposite position; the EA nets it with CloseBy. A detached arm's exits
leave locked pairs that still hold 2 slots. The session's Claude first said
route B would free slots as exits filled; the code said otherwise.

**Both arms of a pair share a chart title** (`fxgrind (NZDCAD,M5)`). Before
removing an EA, open its properties, confirm `InpMagic` and `InpSlot`, and
press CANCEL (OK can reinit).

**Pipshed shows a detached instance as "live" with its frozen last book**,
including orders already deleted, until it ages out. Compare P&L across two
reads: identical to the cent means frozen.

---

## SPECS (2026-09-16)

**Count the literal you mean, not a substring.** A test counted
`grind-ring-section` and would have matched two CSS selectors as well as the
class attribute. Three checks could never pass. Same family as the 09-15
self-contradicting verification criteria: derive checks from the SOURCE FILE,
not from the design text.

**Name functions from source.** Rev 1 cited `instances_for_ring`; the helper
is `_grind_instances_for_ring`.

**Do not put live state into a prompt as current fact.** "Two instances are
halted" was true for 90 minutes and false when the prompt was reviewed.
Gemini then repeated it back as current and asked how the halts were being
cleared. State the time, or state it as history.

**A Gemini approval is not a source check.** Rev 1 was approved with three
mechanical errors. Keep both steps.

---

## DESIGN AND RED TEAM (2026-09-16 evening)

**The DeepSeek runner is a script, not a Cursor model switch.**
`D:\candlelab\scripts\r1_audit.py` sends prompt + listed files by API. Three
handover docs described the courier; the operator had to dig out the script.
It had an API key hardcoded as a fallback -- removed; key lives in
`D:\candlelab\.env`, which candlelab does NOT gitignore.

**An empty `## Final Report` means DeepSeek ran out of output, not credit.**
The ADR-151 spec audit produced 249k chars of reasoning and no report. The
section literals appear in the reasoning, so a presence check passes anyway.
Check that text exists AFTER the final heading. Fix the runner to log
`finish_reason` and set a large `max_tokens`; keep briefs to one question set.

**Check for the SHAPE of a secret, not a substring.** `sk-` matched
`ask-stops`. Use `sk-[A-Za-z0-9]{20,}`.

**Claude's design memos had real source errors that only a source-grounded red
team found:** I8 cannot see a stale tracker; halted instances ignore fills;
reconstruction leaves `exit_target=0.0` for layers without exits; the carry
pass skips layers without exit orders; plain `I6_*_EXIT` is NOT quarantinable.
Three DeepSeek rounds took the premise from "dead" to "survives". Keep sending
design to DeepSeek with source attached.

**DeepSeek declares premises dead for fixable issues.** Ask for the smallest
fix per finding and forbid "fatal" on anything it rates fixable.

**Gemini's numbers need the same check.** A 1000 ms lock staleness would have
broken mutual exclusion across a synchronous OrderSend. Rejected; 10 s.

**A GlobalVariable is terminal-wide.** Any prune keyed on "not in my book"
deletes peers' data. Delete only when the underlying position no longer exists.

**MQL inputs cannot be fleet-wide.** Values that must match across instances
belong in compiled constants.

**Recompiling `fxgrind.mq5` reloads every chart using it at once.** Halted
instances with naked layers will fail reconstruction on reload; close naked
positions first.


---

## DEPLOY NIGHT (2026-09-17)

**A compile clears every halt.** `OnInit` sets `g_grind_halted=false`. The
16c plan assumed parked instances stay parked through a recompile; they do
not. Detach anything that must stay out.

**Count the names, not the number.** "8 halted" was repeated for hours; the
list had 7. Recount from the status every time a number is carried forward.

**Liveness is not in `api_count` or in one P&L change.** A detached instance
shows "live" with a frozen book and repeats the fleet-wide `api_count`. Two
reads taken AFTER the detach, identical to the cent, prove frozen. Pipshed
shows `book: null` for a detached instance, so AccountLimits is the only full
book count.

**Two-dot diffstat lies about merges.** `origin/main..branch` compares trees:
a file added to main after the branch point shows as "deleted". Use
`origin/main...branch` (three dots) to see what the branch changed.

**A commit report file is still a self-report.** Both Cursor reports tonight
had wrong counts or hashes. The branch was right both times.

**Test seams must model what the test asserts.** A constant `used` seam made
AM2 (recompute before each send) untestable; a per-tick flag reset only in
`OnTickEngine` leaked across direct-call tests; a function reading the live
terminal ignored the order seam. Twenty-one failures, none in live logic.

**A stub commit must compile.** A forward declaration of a new overload with
no body fails MQL5 compile (`function must have a body`). The tests-first
proof was lost for ADR-151.

**Never run the test suite on a terminal with live EAs.** LK tests delete the
fleet slot lock GV; prune tests delete carry GVs terminal-wide.

**Screenshots of EA inputs contain `TelemetryAPIKey`.** Crop or rotate.

**The guard binds in steady state.** Missing entries after a reattach are
usually deferral (`positions + orders + resting_ent > 194`), not a fault.
Compute it before diagnosing.

**`status=401` in the Experts tab means the telemetry key is wrong, not the
network.** The EA keeps trading; pipshed and the archive see nothing. Check
the Experts tab for 401 in the first minute after every attach.

**Loading a preset overwrites a pasted `TelemetryAPIKey`** (presets store it
blank), and RDP copy-paste can fail silently. Load preset first, paste key
last, look at the field before OK.

**Closing positions under a running EA quarantines then halts it.** Detach,
delete that instance's ENT orders (a fill while detached would be a naked
rank-0 layer), close, then reattach. Reattaching with a lower `InpMaxLayers`
than a side's depth trips I7 (not quarantinable): close first.

**An input changed in the EA dialog is not in the repo.** The next preset
load restores the old value. Commit preset changes the same night.

**Manual closes are invisible to EA realised, `scalp_history` and the pipshed
summary.** Record tickets and take P&L from MT5 History.

**Carry exit adjustment is a settled principle, not an option** (ADR-135b,
Economics). An exit that does not move by accrued carry changes the financial
terms of the trade; the sweep priced carry on that assumption (`725391f`).
Never frame it as "shifting makes exits fill less often" or offer "don't
shift" as an alternative.

**"Carry pass off" is not "no risk".** With it off (ADR-151 Phase A), every
layer held across a rollover exits on changed terms and the fleet diverges
from the carry-priced calibration. Do not justify deferring carry work by its
being disabled.

**`api_count` is per BROKER day, reset at 21:00Z, and includes every
`OrderSend` attempt, failed or not.** A night of incident ops lands in the
next day's count. `GRIND_DAILY_API_LIMIT 2000` is defined but unused: only
the 1,800 soft warning emits telemetry, and nothing stops the fleet. Manual
terminal actions are server requests FTMO counts but we do not.

**Layer index is a label, not a count.** Closed indices are never reused, so
a capped ladder can read L05-L12. Depth is `open_layers_long/short`.

**MT5 loads presets from `MQL5\Presets`, which `git pull` and `deploy.ps1`
never touch** (`xcopy ea\*` has no /S). A preset commit is live only after a
manual copy there. Loading a stale preset silently reverted a cap to 12.

**The guard is first-come.** Freeing room does not mean the instance you
freed it for gets it: other instances' far adds and short L0s took it first,
repeatedly. Deleting an attached instance's ENT orders just re-places them;
detach first.

**A detached instance's pipshed heartbeat is frozen**, including orders you
have since deleted. Verify in the MT5 Trade tab. Its resting exits keep
filling at the broker; the fills net on reattach.

**A roll's cost is not the realised loss.** That loss is already in MTM and
in today's daily-loss figure. The cost is spread + commission plus the
forgone recovery of the closed layer. And the resting bid re-anchors to the
deepest layer, so it follows price both ways.

**The roll-mode simulator is single-sided with touch fills.** A capped stall
ladder idles the whole instance in the sim, so early results overstate
rolling by an order of magnitude versus live. Compare modes; do not quote
magnitudes.

---

## CARRY IS NOT CLAMP. 2026-09-18, SIX HOURS LOST.

**Read this before touching exit pricing.**

### Carry, with numbers. There is nothing complicated here.

Entry 100, `exit_pips` 5. Carry in pips, signed, negative means paid.

| side | entry | exit, no carry | carry | new exit |
|---|---:|---:|---:|---:|
| long | 100 | 105 | -2 | **107** |
| long | 100 | 105 | +2 | **103** |
| short | 100 | 95 | -2 | **93** |
| short | 100 | 95 | +2 | **97** |

**Negative carry pushes the exit further from entry; positive pulls it
closer.** "Further" is up for a long, down for a short. That is the whole
rule, and it is `Grind_CarryShiftedExitPrice`:
`formula_exit - direction * accrued_pips * pip_size`.

It applies to EXITS only -- basis-anchored orders. Never to adds or L0
(ARCHITECT s1). pipshed's carry audit already walks every order and skips ENT
with exactly that reason.

### Clamp is a completely unrelated thing

A clamp is the broker refusing a price. A sell limit must rest above the ask;
if the formula target is below it, `Grind_ExitQClampPassive` moves the order
to `ask + min_dist`. Market proximity. Nothing to do with financing.

**They share no mechanism, no cause and no maths.** If a discussion of carry
starts involving the clamp, something has gone wrong.

### How they got tangled, and it is a real defect

`Grind_ExitQManageSide` stores the clamp offset in the CARRY shift GV:

    if(clamped || MathAbs(price - formula) > _Point * 0.5) {
       Grind_CarryShiftSet(side.layers[i].position_ticket, price - formula);
       GlobalVariableSet(Grind_CarryReleaseGvName(...), 1.0);
    }

That is ADR-151 Phase A, Gemini's Q2 release marker. Its purpose is real: a
clamped exit sits far from `entry +/- exit_pips`, so I6 would reject it. The
block records the offset so `Grind_ReconExitMatchesEntry` accepts the placed
price. **It is load-bearing and it is live on the fleet.**

Its mistake is the STORE, not the idea. While carry is off the GV holds
nothing else, so it works. **Turn carry on and a clamp overwrites accrued
swap with market noise** -- measured at 4,513 points of "shift" against a
nightly bound of 3.318 pips/night, with the release GV set so validation is
bypassed forever after.

**Carry therefore needs its own store.** Leave `GRIND_CARRY_SHIFT_` to the
clamp. Add a separate key for accrued carry, written only by the carry pass.
Both get added to the formula by the queue and by I6.

### The ludicrous part -- what Claude actually did

1. Saw the block, checked only whether the current spec asked for it, and
   told Cursor it was **"invented scope"** and **"nothing in the spec asked
   for it."** Never ran `git log` on it. It predated the branch by two days.
2. Had Cursor delete it. Suite went 1266/1267. Nearly green.
3. `MQ5 shift gv` / `MQ5 release gv` failed -- they assert the block. **One
   instruction away from telling Cursor to update them, which would have made
   the suite fully green and shipped a fleet-halting bug.**
4. Only then read Cursor's own report, which correctly identified the block's
   origin as ADR-151 Phase A.
5. Measured it: clamped exit with the block gone gives
   `invariants_ok=false reason=I6_LONG_EXIT`, 71 points against a 2-point
   tolerance.
6. Reverted the whole commit -- including a legitimate test market-seed that
   had shipped alongside -- so a test that had been fixed broke again.
7. Meanwhile answered a clean question about carry by talking about the
   clamp, twice, when they are unrelated.

**Net: six hours, nothing shipped, the branch abandoned.** The fleet was
never at risk because nothing merged -- but only because the deletion
happened to leave two assertions failing.

### The rules that come out of it

**Never call existing code unnecessary without `git log`-ing it.** "The spec
did not ask for it" is not evidence of anything. Two commands would have
ended this in the first minute.

**A near-green suite after deleting code is a warning, not a result.** Ask
what the failing assertions were protecting BEFORE deciding they are stale.

**Never update a test to match new behaviour in the same change that altered
the behaviour.** If an assertion objects, it is doing its job.

**Check the deleted-assertion inventory on every branch:**

    git diff origin/main -- ea/fxgrind_tests*.mq* | grep "^-" | grep -i "Assert\|void Test_"

Anything listed that existed on main means the green is fake.

**Revert surgically.** `git revert <hash>` takes everything in that hash. If
a legitimate fix shipped alongside the mistake, revert the hunk, not the
commit.

**When a branch has accumulated reverts of reverts, abandon it.** Return to
the last green commit on main and restart with what was learned. That is
cheaper than archaeology.

### Known unknown, still open

`Grind_ExitQFormulaTarget` gaining a shift changes what `price - formula`
means inside the clamp block. **No test covers a clamp on a layer that also
has a carry shift.** `MQ5` runs with no shift stored, so it cannot see the
interaction. Establish this before carry ships.
