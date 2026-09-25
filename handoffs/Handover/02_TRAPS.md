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

**That framing was incomplete. The real defect is the WRITE GUARD, and it is
pre-existing.** Measured 2026-09-19 by `Test_CARRY_PROBE_replace_after_cancel`
(`prompts/carry_replace_probe.md`):

    CARRY-PROBE re_placed=1.2503 raw_formula=1.2503 carry_target=1.2505
                gv_before_replace=0.0002 gv_after_replace=0.0002
                relexists=true exit_target=1.2503
    CARRY-PROBE I6 ok=false reason=I6_LONG_EXIT

Sequence: an exit is cancelled when its layer drops below rank 0, which under
K=1/H=0 happens on EVERY add fill. When the layer returns to rank 0 the queue
places a FRESH exit from the raw formula. The write guard is

    if(clamped || MathAbs(price - formula) > _Point * 0.5)

With no clamp, `price == formula`, so the guard is FALSE. The GV is neither
updated NOR cleared. **The broker now holds an order at the raw price while
the store still claims a shift, and I6 halts the instance.**

This is why carry has never shipped. It is latent today only because carry is
off, so nothing writes a real shift -- the clamp block writes on the same
pass it clamps, so it stays consistent. Enable carry and the fleet halts on
the first rank rotation. It is the concrete mechanism the `OnInit` FATAL
guard has been protecting against.

**Any carry design must therefore solve two things, not one:** the queue must
place at the carry-adjusted price, AND the stored offset must be maintained
on every placement path including the no-clamp one. A separate store for
carry is probably still right, but it is not sufficient on its own.

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

### Regression test, on main

`Test_CARRY_PROBE_replace_after_cancel` in `fxgrind_tests_adr151.mqh` is the
regression test for whatever the fix turns out to be. It currently PASSES
because it only asserts that a second placement occurred; the defect shows in
its `Print` output, not in an assertion. **When the fix lands, turn those
printed values into assertions.**

### Known unknown, still open

No test covers a clamp on a layer that ALSO has a carry shift. `MQ5` runs
with no shift stored, so it cannot see the interaction. Establish this before
carry ships.

---

## A CHANGE TO WHAT AN INVARIANT REQUIRES MUST SURVIVE ONINIT ON THE BOOK THAT EXISTS

2026-09-20 01:08Z. F1, the barbell exit queue, was deployed. **All 16
instances halted on `I3_LONG_NAKED` within two minutes.** Reverted 01:20Z;
all 16 recovered, books intact.

### What happened

The barbell changes which ranks require a resting exit, from a prefix
(`rank < K`) to two ends (`rank < K OR rank == depth - 1`). So it requires an
exit on the MOST UNDERWATER layer of every side.

**Every existing book was built under the prefix rule, so no such layer had
one.** Reconstruction runs I3 before the exit queue gets a pass, so every
instance failed the invariant on its first reinit.

CADCHF OPT, exactly: long layers 0.58963 (L00), 0.58863 (L01), 0.58763 (L02),
only long exit on L02. Depth 3, so L02 is rank 0 and **L00 is rank 2 =
depth-1**. No exit. Offending comment `GRIND|OPT|L|L00|ENT`.

### Why it was not survivable -- in ANY market

**Correction, 2026-09-20.** This entry first said the halt "normally
self-heals within a tick" and was stuck only because the market was shut,
and it listed "deploy into a live market and accept a transient halt" as an
option. That was reasoned from what the queue WOULD do, never checked against
the `OnInit` path, and written into two handover documents. It was wrong:

- `fxgrind.mq5:170`: a failed `Grind_ReconstructState` prints "halted in
  place". `Grind_RetryMissingExits` is in the `else` branch and never runs.
- The halt path sets `g_grind_halted = true`; `OnTick` gates everything
  behind `if(!g_grind_halted)`. Nothing retries.
- `I3_*_NAKED` IS quarantinable (`grind_quarantine.mqh:37`), but quarantine
  runs only on the `OnTick` invariant path. `OnInit` bypasses it.

**The `[Market closed]` lines were the halt path**, `Grind_CancelOwnEntryOrders`
cancelling ENT orders -- not exit placements being refused.

**The same compile in a live market halts all 16 identically**, and a halted
instance ignores fills. The shut market was incidental.

### The rule

**Before deploying any change that alters what an invariant REQUIRES, ask:
does the book that exists NOW pass the new rule through the `OnInit` path?**

If it does not, the change needs one of:

- **Place before checking** -- in `OnInit`, reconstruct under a rule the old
  book satisfies, run the queue, then check under the new rule.
- **A grace state** -- reconstruction tolerates the old shape and routes the
  shortfall into quarantine instead of a halt.

**There is no "transient halt" option.** A reconstruction failure is
permanent until a compile or reattach.

**Quarantine facts, for any fix that routes through it.** Escalation to halt
needs BOTH `>= GRIND_QUARANTINE_MIN_MS` (3000) AND
`>= GRIND_QUARANTINE_MIN_CHECKS` (3), and checks run only in `OnTick`
(`fxgrind.mq5:277-278`). A shut market delivers no ticks, so quarantine does
not escalate over a weekend. **Both questions are answered (read at `5124bd2`, 2026-09-21).**
`Grind_RetryMissingExits` is `Grind_ExitQManageSide` on both sides and
places every required rank, `depth - 1` included
(`grind_engine.mqh:1530-1536`). The feed-staleness guard blocks ONE tick:
it compares with the previous tick and then updates it, and after
`OnInit` the stored value is 0 (`grind_pure.mqh:231-242`).

**That test was never written** -- judged moot because the new account
starts flat. It was not moot: see "F1 CHANGES WHAT A RESTART NEEDS" at the
end of this file. ADR-156 tests X1-X11 now cover it.

### How it got through

**The steady state was tested exhaustively** -- 7 new tests, 25 re-derived
assertions, suite 1354/1354, and Gemini reviewed the spec four times. **Every
test built its own fixture under the NEW rule.** Not one started from a book
built under the old one.

**Neither Claude nor Gemini considered the migration.** The reviews caught
mechanical traps -- array bounds, ticket binding, regex classes -- and missed
the question of what happens to books that already exist.

**A test that constructs its own world cannot tell you whether the world you
already have will survive the change.**

### Also learned that night

**`deploy.ps1` starts with `git pull origin main`**, so it cannot be used to
deploy a reverted build. Use `git checkout <sha>` then a bare `xcopy ea\*`.

**Tags are not fetched by `git pull origin main`.** `git fetch origin --tags`,
or just use the SHA.

**Changing `InpExitPips` on an arm that holds resting exits halts it on
reattach** -- the same `OnInit` mechanism. I6 compares each resting exit with
`entry +/- InpExitPips` at 2-point tolerance, so exits priced under the old
value fail. Same family as the I7 trap on lowering `InpMaxLayers`.

**Verify what landed in the TERMINAL, not just the repo.** The check that
matters is `Select-String -Path "$term\grind_exitq.mqh" -Pattern "const int
depth"` -- empty means the barbell is not there.

---

## A STUDY THAT HOLDS ITS INPUTS FIXED CANNOT JUDGE WHAT PRODUCED THEM

2026-09-20. The exit counterfactual was executed properly -- pre-registered,
DeepSeek-audited, Gemini-ruled, parity 610/612 scalps within one minute --
and it answered the wrong question.

It replayed different `exit_pips` over the REAL entries. Entries were held
fixed by design, which is what made the parity check possible. But the
entries were produced by the grid under test, so the study was blind to the
defect that mattered: **pairs differ in pips per day almost entirely because
they differ in ENTRY volume.** Every pair converts 67-82% of entries into
scalps; GBPUSD gets 30.3 entries/day and CADCHF 10.0, on the same add
spacing of 10.

The operator caught it, and was right to be annoyed: "why are you focused on
exits when that is obviously polluted by the entry".

**Rules that follow:**

- Read an uneven scalp or pip distribution across pairs as **add spacing too
  wide for the quieter pair** FIRST. Check exits second.
- Before running a study, name what it holds constant and ask whether that
  constant is itself the suspect.
- **"No alternative beat it" is not "it is correct".** A narrow null result
  reported as "change nothing" wasted an hour and was wrong.
- **Price-action proxies do not persuade the operator, and should not
  persuade you.** Lead with trade volume from fills -- scalps and pips per
  day, per pair, per arm.

## OTHER TRAPS FROM 2026-09-20

**Cursor leaves the desktop on its own branch.** Twice in one session a
commit or merge landed on `review/...` instead of `main`, and `git merge`
answered "Already up to date" because the branch was being merged into
itself. **Run `git branch --show-current` after every Cursor job**, and read
the last line of `git log --oneline -1` for `HEAD -> main`.

**`git add a b` stages NOTHING if one path is wrong.** A missing file in the
list silently takes the good one with it. Check `git status --short` after.

**Commission is charged per FILL, including passive limit fills.** 0.03 USD
per 0.01 lot on ENT, EXT and manual OUT; CloseBy is free. That is 0.45 pip
per scalp on EURGBP and 1.05 on AUDNZD. It is an FTMO account charge, not
spread, and it is not evidence that the strategy crosses the spread --
report gross AND net and let the reader choose.

**A terminal restart clears only TEMPORARY GlobalVariables.** Those
created with `GlobalVariableTemp` -- the slot lock, cap lock, magic locks
and the MAE reporter lease -- vanish when the terminal closes. PERSISTENT
ones survive restarts AND account switches: the API counter, the MAE day
anchor and equity low (anchored on the OLD account's balance), carry state,
cap exposure, deinit records. `scripts/grind_gv_clean.mq5` deletes exactly
those; run it after the restart. Also: GlobalVariables belong to ONE
TERMINAL, not to the account -- the desktop and the VPS never share them.

**Never push the deals dump to git.** The repo is public and the dump is the
complete fill history. Upload it to the chat instead; 341 KB is nothing.

**DeepSeek reads "slot" as the OPT/ALT arm.** Say "account slot" in briefs,
or it will reject correct work on a misreading. Five of its 22 findings this
session were wrong on MT5 mechanics; all five were caught by checking the
deals and the source.

**Gemini's conclusion can be right while its reason is wrong** -- it argued
tight exits "give up the spread", which passive limit exits never do. Keep
the ruling, correct the reason in the record.

**Screenshots of EA inputs expose `TelemetryAPIKey`.** It happened again.
Rotate at the next planned reattach, which is Wednesday.

**Wine 11 breaks MT5** on the new Linux box -- "A debugger has been found
running in your system". Ubuntu's own Wine 9 works. Details in
`06_LINUX_WINE_BOX.md`.

## TRAPS FROM ADR-153 (2026-09-20, overnight)

**Check the suite TOTAL, not just the FAIL rows.** A stale compile of
`main`'s tests produced exactly the same FAIL rows as the branch -- only
the total (1354 against the branch's 1380) gave it away. After every
checkout, run `.\desktop_sync.ps1` (repo ROOT, not `scripts\`) BEFORE
compiling, and confirm a branch-only symbol is present in the copy that
actually runs. **The suite runs from `MQL5\Scripts\`**:
`Select-String -Path "$env:APPDATA\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Scripts\fxgrind_tests.mq5" -Pattern "<new test name>"`.
A stale copy also sits in `MQL5\Experts\fxmatrix\` which the sync does
NOT update -- compiling that one silently runs an old suite (backlog C13).

**Cursor's self-reported hashes and line counts are unreliable.** Twice in
one ADR its response document recorded a commit hash from before an amend
(`ceb8c31` for `c9997b2`, `74f1b93` for `ce0cb28`) and a wrong line count.
The code was right both times. Verify every hash against origin and count
every file.

**A green suite can depend on the chart you run it on.** IV5 and EF3
failed on `main` for a week. Cause: twelve tests place exits on the 1001
fixture WITHOUT seeding the market, so `Grind_MarketBid/Ask` return the
LIVE quote of the chart; depending on its price an exit clamped, and the
clamp stored a shift plus a release flag for 1001 that nobody deleted.
The release flag bypasses the bound check, so IV5 and EF3 inherited a
non-zero shift. (An earlier diagnosis blamed live swap rates -- wrong.)
Fixed in `29df88f`: the shared reset clears carry state, and IV5/EF3 clear
it themselves. Proof was running the suite on two charts at very
different prices (GBPUSD, AUDCAD): 1387/1387 on both.

Before blaming a branch for a failure, run `main` -- it settles "ours or
pre-existing" in one compile.

**A test that passes can be passing for the wrong reason.**
`Test_PO4_RecenterOppositeL0StillWorks` passed for weeks because the
recentre read `OrderGetDouble` directly, which returns 0.0 under the test
harness, so the distance from mid was always enormous and the recentre
always fired. Only a test expecting NO recentre (PO4b) exposed it. When a
test asserts that something happens, add its negative twin.

**An inequality in an ADR is not automatically a safety rule.** ADR-153's
`stranded >= max(2 x width, width + deadband + 1)` was derived in one
evening, approved, audited, and then removed: it encoded one quoting
design and would have forbidden another. Ask what a fatal check protects
against; if the answer is "a preference", it is a preset convention.

**Say which parameter TYPE a direction argument is.** `Grind_ExitQRanks`
takes `bool is_long`; `Grind_ExitPrice` takes `int direction`. Passing
`-1` to a `bool` coerces to `true`. Specs must name the value per function.

## F1 CHANGES WHAT A RESTART NEEDS (2026-09-21)

The barbell requires an exit on `depth - 1`, and before ADR-156 a missing
required exit at startup was a PERMANENT halt (`fxgrind.mq5:175-180`).
EVERY manual roll produced one (the new deepest was an uncovered middle
layer), and so could any restart during a fill gap or a blocked
placement. Both reviews of the Wednesday plan judged the old-book test
moot because the account would be flat. **A flat START is not a flat book
at the next restart.** Fixed by ADR-156 (`3f72b9f`).

**MQL5 cannot cast away `const` on a reference.** ADR-156's first test
helper did `(GrindSideState &)side` on a `const` parameter; it compiles
in C++, fails in MetaEditor. Cursor cannot compile, and review missed
it. Only the operator's MetaEditor compile catches this class.

**Prove test-first with a stub-check branch.** Branch from the tested
tip, `git revert` the implementation commit, run the suite: the new tests
must fail by NAME and COUNT as predicted, nothing may crash (guard any
array index a failing assert can make -1). ADR-156: 19 predicted, 19
failed, 1410/1429; then 1432/1432 on the real branch.

## TRAPS FROM 2026-09-22/23 (ejection, carry, breaker)

**A default-off guard can hide a live bug for months.** `OnInit` refused
carry (ADR-151 phase A); the carry pass wrote accrual BEFORE its modify, so
a sign-guard block or a rejected modify left state ahead of the order ->
I6 halt. It would have gone live the day carry was switched on. Before
enabling any dormant path, re-audit it as if new.

**MT5 GlobalVariables reach disk only on a clean terminal close.** The EA
never called `GlobalVariablesFlush()`; a crash after the nightly carry pass
would have restarted every carry-shifted instance into an I6 halt. Fixed
(C25): writers mark dirty, `OnTimer` flushes. A lost DELETE is as bad as a
lost write.

**Snapshotting state at the start of a multi-minute pass is a TOCTOU
race.** The carry pass captured each exit base at pass start; an ejection
mid-pass was reverted -> I6 halt. Recompute at processing time (ADR-157).

**Anything that fires every tick needs a backoff.** A failed auto-eject
modify retried every tick (~600 requests/min/side). And fetch history only
when it can matter (cap-first).

**Bars by COUNT span gaps.** After a weekend, 10 M1 bars reach back to
Friday; check the wall-clock window.

**In-memory fields drift from the book.** The carry pass moves orders but
never updates `layer.exit_target`; read the order's own price when it
matters.

**FTMO's daily anchor is BALANCE at 00:00 CE(S)T, not equity, and not broker
midnight** (01:00 broker, UTC+3). Floating loss carried over FTMO midnight
spends the new day's allowance before any trade.

**Reviewer models complete templates.** A prompt ending in an unfilled
"FINAL REPORT" got a fabricated one back from Gemini (non-existent SHAs).
Verify every SHA in git.

**Windows PowerShell 5.1:** no `-NoNewline`; BOM-less UTF-8 is read as
ANSI. Use `[System.IO.File]` with `UTF8Encoding($false)`.

**Specs must be unambiguous about index vs value.** "want_max -> 4" meant
index 4; Cursor wrote value 4 (index 2). Say "index".

## TRAPS FROM 2026-09-23/24 (ADR-159, ADR-160, cycle-3 attach)

**The daily limit kills on carried inventory, not on the day's trading.**
FTMO measures from the day-start BALANCE and equity includes open MTM;
cycle 2 opened its last day ~$330 down and died at -$505. A breaker that
trips on the day's move cannot save a day that STARTS spent (ADR-160).

**A test whose expected value is zero passes against a stub.** SN1's
`swap_day` expected 0.00; the stub never computed it and still passed. Use
non-zero expectations, and mutation-test anything that converts clocks or
units (pipshed DS11 passed with the broker offset disabled).

**Verify every agent change item by item.** Cursor made 1 of 4 specified
fixture changes in one commit; added a test without registering it in the
run list; and once implemented pure functions inside a "stub" commit,
which blunts the stub check. Read the diff against the spec's list.

**Changing a shared table breaks fixtures that encode it.** Growing the
fleet magic table from 16 to 18 failed CM2, CL1-CL2, CL4 and RX3, which
seeded or asserted the 16-magic fleet. Grep the tests for literal magic
lists, sizes and hand sums before changing any table.

**A swallowed exception must roll the DB connection back.** Postgres keeps
a transaction aborted after a failed statement; every later statement on
that connection fails until a rollback (pipshed fix 1).

**DeepSeek mis-assumes and overstates.** It assumed a 5000 ms WebRequest
timeout (the code passes 200), and called a stuck-ON gate reachable when the
state that feeds it cannot recur in a session. Each verdict needs the line
that confirms or refutes it.

**A fresh Gemini chat has no codebase memory.** It cited an invented
`Grind_GridReconstruct`. Send `01_BOOT.md` with the prompt and point at
files; adopt verdicts, but record wrong reasons as wrong.

**PowerShell `Write-Host` bypasses the pipeline.** `Select-String` cannot
filter `desktop_sync.ps1` or `deploy.ps1` output; check files by hash. Their
closing "Done - ... byte-identical" line is the script's own, not an
agent's claim.

**Railway Postgres is private.** `railway run` injects
`postgres.railway.internal`, which only resolves inside Railway; run DB
scripts with `railway ssh --service archive-worker <command>` after the code
that needs them is deployed.

**`deploy.ps1` runs `git pull origin main`.** Pin the VPS by being ON
`main` at the intended commit, not on a detached SHA.

**The VPS checkout may predate a script the runbook copies.** The close-out
step copied `grind_gv_clean.mq5` from a detached build that did not have it;
copy from `origin/main` with `git show` (runbook fixed).

**On the VPS terminal, Algo Trading must be ON before attaching,** so each
EA trades on OK. Read every input back BEFORE OK; if one is wrong, remove it
AND delete its pending orders by hand (removing an EA leaves its orders).

**Tag on the desktop.** `vps-a01a5d4` was created and pushed from the VPS
(lightweight). Harmless for a tag; the rule stands (BOOT s3).

## TRAPS FROM 2026-09-24 NIGHT (FLEET B, LINUX BOX)

**Linux is case-sensitive: MT5 under Wine writes `MQL5/logs`, lowercase.**
A path with `Logs` does not exist; find logs with `find ~/.mt5 -name
'*.log' -mmin -60`. The logs are UTF-16: `iconv -f UTF-16LE -t UTF-8`
before `grep`.

**A broker portal can add, not set.** IC Markets' "Set Balance" added
$10k to a $10k demo. The breaker's allowance is 5% of the FIRST deposit,
so open a fresh demo with the right balance rather than repair one.

**A portal can hide the account you asked for.** The Raw Spread demo was
created under "Hidden Accounts" while the visible card said Standard.
Check the title bar after login: account, server, Hedge/Netting, entity.

**Hedge, not netting, for any new account.** The EA does not check it at
startup; a netting account breaks CloseBy.

**Cursor opened in the wrong workspace can commit to the wrong repo.**
It did not tonight (the prompt named `D:\pipshed`), but check
BOTH repos on GitHub and `git status` in both working copies afterwards.

**Never write a commit hash from memory.** A hash quoted in a summary
without looking it up was wrong; every hash in a message must come from
`git`.

**Railway: "Duplicate" is on the canvas card's right-click menu, not in
Settings; a new service's networking cannot load until its first deploy.**
Add variables BEFORE the first deploy. Never move the custom domain to the
copy; never duplicate the archive worker (one worker serves both fleets).

**A spec can contradict itself.** The fleet-select spec asked for a CSS
class `fleet-label` AND a check that the page lacks `fleet-label` when no
label is set; the stylesheet made that impossible. Cursor narrowed the
check to the rendered element. Read a test's assertion against everything
else the same spec adds to the page.

**A log filter with "last N matches" can drop the lines you need.** The
quarantine search kept the last 25 matches; heartbeats (which contain the
word) crowded out the ENTER lines. Exclude heartbeats first.

## TRAPS FROM 2026-09-24 EVENING (DELIVERY BY PATCH, FIRST REAL DATA)

- **A publish path that never saw a real row fails on the first one.**
  ADR-159's daily card was tested only with fake rows (floats). Real
  `numeric` columns come back as `Decimal`; `json.dumps` raised, the
  worker swallowed it, and the card sat empty for 1.5 hours after the
  first snapshots landed. After deploying anything that publishes, check
  the FIRST real datum end to end; test with database-typed values.
- **A downloaded copy of a file a patch creates blocks `git am`**
  ("already exists in working directory"). `git am --abort`, remove the
  copy, re-apply. Keep review copies OUTSIDE the repo.
- **Saving a downloaded copy over a committed file** shows it modified
  with no text change (LF vs CRLF). `git restore <file>`.
- **Cursor leaves its branch checked out.** A merge then says "Already up
  to date". `git switch main` first, always.
- **Claude's web fetch can return a cached page** (its own cache and
  Cloudflare). Trust the operator's hard refresh or a fresh cache-buster
  URL pasted by the operator; "pipshed Copy" also deploys minutes after
  `pipshed`.
- **A patch made but not presented is invisible** to the operator. Every
  patch needs a present_files card, with its byte size to check.
- **Gemini asserts code behaviour it has not read.** ADR-162 G3 claimed
  trim-before-protect ranks by floating loss (false: barbell rank
  predicate, same as I3). His unsourced IC Markets 23:59-00:01 claim
  turned out right. Verify each either way.

## TRAPS FROM 2026-09-25 (ADR-162 PHASE A)

- **A stored copy is not the value used.** The carry pass stores
  `g_grind_carry_exit_work_formula` but modifies to `Grind_CarryWorkBase`,
  which recomputes from the entry. Listing "formula sites" from one field
  misses the recomputation; test the price the ORDER is sent at.
- **A prune inside the function under test eats test fixtures.**
  `Grind_CarryExitPassBegin` ends with `Grind_CarryPruneShiftGvs`, which
  deletes per-ticket GVs of positions that do not exist: every test
  position. Set per-ticket GVs AFTER `PassBegin` (F5, VL10).
- **A test can fail for two reasons at once.** VL10's new assertion
  failed before the fix (no substitution) and after it (pruned VL), so
  the before-fix run proved less than claimed. When a fix does not turn a
  test green, read source before blaming the build.
- **Tell Cursor to push its branch.** "Commit to a branch" alone leaves
  it local, and GitHub has nothing to verify.
- **Every suite run is checkout, `desktop_sync.ps1`, GUI compile, run,**
  with the compile time after the sync. `Get-FileHash` repo vs terminal
  proves the sync, not the compile.

## TRAPS FROM 2026-09-25 (ADR-162 PHASE B1)

- **A forward declaration with the wrong type is a second function.**
  Cursor re-declared `Adr151_TestSeedSlotSeams(const int, ...)` (the real
  one takes `long`); the calls matched the bodiless overload exactly and
  the compile failed "must have a body". MQL5 resolves functions defined
  later in the program: test headers need no forward declarations.
- **ArrayResize does not clear structs.** LB25 resized a side's layers
  and set only entry, index and ticket; the rest held a previous test's
  book, so three assertions passed on leftovers and the queue placed
  nothing. Set every field, or use a helper that does.
- **A fixture can fail the right assertion for the wrong reason.** LB30
  was to drop ticket 2001; Cursor copied `tickets[0..4]` and dropped the
  last one. Read fixtures, not only assertion names.
- **An assertion inside an `if` passes by not running** (LB30).
- **Cap before the cast.** `(int)(60 * 2^(n-1))` overflowed at n = 27 and
  the backoff went negative; LB32 proved it on this build (2000/2002
  before the fix). Clamp in double, then cast.
- **Check an advisor's premise, not only his conclusion.** Gemini
  accepted a fixed 60 s backoff because 1,440 retries fit a 2,000 budget;
  the budget is one GV for the whole fleet. Given the fact, he re-ruled.
- **A red-team finding can be older than the change it audits.** DeepSeek
  filed the carry-pass race (C52) against B1; it is live in cycle 3
  already. Ask "does this need the new code?" before scoping the fix.
- **PowerShell eats braces:** quote `'HEAD^{tree}'`.
- **Log greps meet heartbeats.** `halted` matches every heartbeat
  (`"halted":false`); drop `HEARTBEAT` lines first. The carry pass writes
  to the archive (`CARRY_PASS_SUMMARY`), not the Experts log.

## TRAPS FROM 2026-09-25 (C52 FIX AND LIVE DEPLOY)

- **NEVER run `fxgrind_tests` on a terminal with live EAs.** Its setup
  deletes shared GVs by prefix (`GRIND_CARRY_SHIFT_`,
  `GRIND_CARRY_ACCRUED_`, `GRIND_EJECT_`, `GRIND_VL_`) and some tests
  write breaker GVs: on a live terminal that wipes every instance's carry
  and trips I6 fleet-wide. `06_LINUX_WINE_BOX.md` s7 step 5 ran the suite
  BEFORE Fleet B attached; it must not be repeated there now. The desktop
  (no EAs) is the only place to run it.
- **Deploy check lines:** 11 `deinit reason=2` + 11 `GRIND_SESSION
  enable=...` at the compile second, then no RECON_FAIL / INVARIANT_FAIL /
  CRITICAL / FATAL, and heartbeats from all 11.
- **PowerShell `-match` is case-insensitive:** `WARN` matched
  `InpConfigWarning` in the CONFIG dumps. Use `-cmatch` for codes.
- **Git on the VPS may ask "Unlink of file ... pack ... failed. Should I
  try again?"** during a pull: answer n. The old pack is left behind; the
  pull completes.
- **A patch that recreates a file you already saved in the repo fails
  "does not match index":** keep downloaded prompts and patches in
  Downloads, never in the repo, and `git restore` the file if it happens.
- **Before/after beats absolute.** A 3:1 heartbeat ratio after a deploy
  looked like a regression; the same window before the reload showed
  39:13 (C59).

## TRAPS FROM 2026-09-25 (C54 AND THE CARRY CHECK)

- **A red-team "BREAKS" can be a ruling it did not know.** DeepSeek
  called the prune's missing `GRIND_VL_` branch a merge regression; B1
  removed it on purpose (GB2). Check a verdict against the rulings, not
  only against source.
- **`CARRY_SNAPSHOT` is also written at every EA init.** A "newest row
  per symbol" view (`--carry`) shows the reload, not the night; use
  `--carrypass`.
- **A roll or a pass modify at an unchanged price is a request, not a
  no-op** (C60): count it before reading `failed` as a fault.
- **Merge `main` into a long-lived feature branch before its audit**
  when `main` changed code the feature touches (C52 vs B1): test and
  audit what will ship, then merge back `--no-ff`.
- **MQL5 rejects `static` on file-scope functions** ("cannot be declared
  static"): C55's six helpers failed the GUI compile. There is no
  precedent in this codebase; do not accept it from a spec or an agent.
