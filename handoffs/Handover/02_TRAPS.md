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
- **Do not reattach with the market closed.** `OnInit` can place orders
  (missing exits, a re-priced add); each fails "market closed", and the
  first ticks after the Sunday open carry the widest spreads. Reattach
  in the session once spreads settle.
- **`send_logs` `duration_ms` 0 = the terminal refused the request
  locally** (10025 no changes, 10027 algo off, 10018 market closed):
  it never reached the broker.

## TRAPS FROM 2026-09-26 (BOX DESKTOP ACCESS)

- **RDP to the box can lock you out while the desktop is healthy.**
  `xrdp-sesman` restarted at 06:27:40Z 25 Sep (almost certainly a service
  restart after an unattended library upgrade; xrdp itself was not
  upgraded) and forgot khalid's session on `:10`, where MT5 runs. Every
  login then starts a NEW session on `:11`, whose XFCE dies at once
  (khalid already has one): the login box just reappears. The sesman log
  says "window manager ... exited quickly". No `mstsc` setting fixes it.
- **Do not reboot to fix it while Fleet B runs there** (06 said "reboot";
  corrected). Use x11vnc on `:10` (06 s4): no restart of anything. If a
  reboot is ever wanted: market closed, close MT5 GRACEFULLY first
  (`wine taskkill /IM terminal64.exe`, no `/F`) so every `OnDeinit`
  flushes GlobalVariables, then reboot, restart MT5 by hand, check 11/11.
  A hard kill skips the flush.
- **Unattended upgrades never reboot the box** (`Automatic-Reboot` left at
  its default, false; checked 26 Sep). They can still restart services.
- **Say where every command runs** (box SSH, desktop PowerShell, a GUI).
  "Install x11vnc" read as a Windows install; it goes on the BOX, the
  viewer on the desktop.

## TRAPS FROM 2026-09-26 (CYCLE 4 DIRECTION)

- **An EXIT change on a live book halts the instance today.** I6 checks
  each resting exit against the CURRENT `InpExitPips` (2 points) at
  reconstruction (`Grind_ReconExitMatchesEntry`). Claude first said the
  nightly carry pass would re-price exits after a new exit: it would, but
  the instance halts at init first. Read the invariants before claiming
  what a reattach does. ADD changes are safe (geometry-cycle3 A6).
- **Both ejection paths act only at cap.** A rule that stops adds (the
  ADR-161 window, the breaker, the entry gate) also stops a side below
  cap from reaching the lattice.
- **Search the docs before designing.** The cycle-4 note (21 Sep) and
  C46-C48 already held most of the 26 Sep direction; it was found only
  when the write-up started. `git grep` the idea first.
- **A resting limit is an option WE give.** Closer = more valuable to the
  market, not less.

## TRAPS FROM 2026-09-26 (C56: THREE FIXES TO GET TELEMETRY RIGHT)

- **Read ARCHITECT s10 before specifying ANY pipshed endpoint.** The web
  service never holds `DATABASE_URL`; the worker reads Postgres and
  publishes to Redis. C56's first endpoint queried Postgres from the web,
  found no URL in production and built from empty lists.
- **Zeros are not data.** Three times in one day an "unknown" rendered as
  0.0 (no DB; no deal tickets; commission unknown). Unknown must be NULL
  or a 503, with a count of what is missing.
- **Pull a production sample BEFORE writing fixtures.** Production
  `scalp_history` has NO deal tickets (360 rows, 0 tickets); commission
  is on IN deals only (-0.04 each), 0 on OUT_BY; the EA's `gross_pnl`
  includes swap. Every fixture assumed otherwise and every test passed.
- **Fixed-date fixtures rot.** A test with 24 Sep data and a 48 h window
  expired at 10:00Z on 26 Sep. Shift fixtures by whole days to "now".
- **Run every verify script yourself; never trust "done".** Cursor
  reported a branch green whose `verify_archive_codes_depth` could not
  pass anywhere (duplicate unique key; checks reading the wrong output).
- **Claude's sandbox PostgreSQL can stop between runs.** A burst of
  "connection refused" is the harness, not the code: check `select 1`
  and rerun before reading failures.
- **Counts exclude, money includes.** Rolls and ejections leave scalp
  COUNTS; they never leave P&L totals (fix 1 found the daily summary's
  net dropping them).

## TRAPS FROM 2026-09-26/27 (GRIND V2.0 NIGHT)

- **Name the workspace in every Cursor handover.** The v2.0 prompt was
  pasted into the pipshed Cursor chat; it found none of the `ea/` files
  and did nothing, but a looser prompt could have written into the wrong
  repo. Start each task in a NEW Cursor chat in the named workspace and
  check its first line names that path.
- **Cite definition lines and call lines separately.** An audit row
  mixing them ("PassStep (1148; 1175)") had the wrong definition lines;
  an advisor then misread the call. Give each function's definition line
  and each call line on its own.
- **"X's setup" is ambiguous.** Cursor read "GV9's setup" as including
  GV9's calls. Say which lines: "the setup lines of GV9, not its calls".
- **Check a red-team verdict against the spec's rulings.** DeepSeek's
  "NEEDS-FIX" (base inputs still required) was the spec's stated design,
  and its DEINIT finding was pre-existing on `main`. Both went to the
  backlog or were rejected with the reason, not "fixed".
- **Experts logs are UTF-16.** A copied log saved without a byte-order
  mark defeats `Select-String`; read the bytes and pick the encoding
  (the parser in this chat). `git log`/`git branch` page with a `:`
  prompt in PowerShell: use `git --no-pager`.
- **An advisor can be wrong and still useful.** Gemini's "line 1175
  cannot call PassBegin" was false, but it pointed at a real error next
  to it. Verify the claim in source, then look at what made him think it.
- **A Flask route that does not exist yet returns an HTML 404.** A test
  that expects `404` with a JSON body (`{"error": "not found"}`, the
  token check) FAILS before the route exists, since Flask's default page
  is HTML. Pipshed FC6 was predicted to pass at the tests-only commit
  and failed (3 of 9, not 4). When predicting a tests-first run, ask what
  answers the request before the code exists, not only what the new code
  will answer.

## TRAPS FROM 2026-09-27 (FLEET STRIP, SUNDAY OPEN, B1 RELOAD, FLEET C ATTACH)

- **Only the MAE reporter's heartbeat carries balance and equity**
  (`grind_mae.mqh` 314-326); every other instance sends null. A fixture
  giving every instance a balance hides that (C72). Pull a production
  heartbeat per fleet before writing fixtures (the C56 trap again).
- **A daily snapshot row is keyed to the day that ENDED** (`s.ftmo_day =
  ended_key`): "today's row" never exists during today. Today's start
  balance is the latest earlier row's `balance_end` (GS-F1).
- **`verify_ejection_telemetry` is not safe to rerun on a used
  database:** ET2 fails on a duplicate key. Drop and create the database
  before each run.
- **The fetch tool caches by path for longer than a turn and its
  summaries misquote** (it gave `ftmo_day` 26 when the raw value was 27;
  it served a pre-deploy copy). Use a NEW last segment, and ask for exact
  quotes of the fields that matter.
- **Look at a page, not only its tests:** the v2 strip passed 28/28 with
  an amber bar at 10.9%, "DAY_LOSS --:" and ISO timestamps; a local
  render found all three.
- **Sunday open spreads on IC:** 17:24 ET, 24 minutes in, the crosses
  were 130-180 points and GBPUSD 72, wider than the L0 widths; normal
  (1-6 points) by ~19:00 ET. Attach or reload only when every spread is
  well under its pair's width.
- **The weekend gap fills resting limits at BETTER than their price:**
  21:05Z exits filled 6.4-11.2 pips beyond their limits, and long adds
  5.7-13.2 pips below theirs (C73). The same gap adds inventory on the
  other side; the day P&L moved -54 -> -70 while the scalps booked.
- **An exit fill at the open shows as `QUARANTINE_ENTER`** on that
  instance at the same second (the close-by gap, C40): harmless, amber.
- **The EA Inputs dialog shows `TelemetryAPIKey` in clear.** A screenshot
  of it puts the key in the chat (27 Sep, twice). Read the dialog back
  yourself or crop the last rows (C9).
- **Twin charts (AUDNZD, NZDCAD) need the identity read before Load:**
  an `_opt` preset on the ALT chart gives it the OPT magic and the EA
  stops with FATAL duplicate magic. Read `InpTelemetryInstance` and
  `InpMagic` first, Cancel if wrong.
- **The Experts log file is named by UTC date:** a reload clicked before
  00:00Z and checked after it is in the previous day's file.

## TRAPS FROM 2026-09-28 (FIRST EJECTIONS, STUDY TOOLS, BOX 2 RDP)

- **Box 2 RDP can die while MT5 keeps trading:** a teal screen after
  login, a slow logout, `:10` not answering, x11vnc hanging. The card
  (LIVE 11/11) is the truth about the fleet, not the desktop. Do not
  restart xrdp, the X session or the box with a live fleet on it
  without a plan: MT5 runs in that X session (C75). C63 needs this GUI.
- **icacls on Windows:** several options in ONE call processed 0 files;
  one option per call worked (`/inheritance:r`, then each `/grant:r`).
  OpenSSH refuses a config readable by others.
- **Stop hook asks Claude to push a local branch:** decline; the
  operator pushes. Once the operator's push lands (same tree, new
  hashes), reset the sandbox `main` to `origin/main` and delete the
  local branch.
- **`export_m1_bidask.mq5` is quadratic** (a linear minute search per
  tick, a bubble sort): fine for a day of one pair, not for a week of
  nine beside live EAs. Use `grind_bar_dump.mq5` (CopyRates) instead.
- **An M1 bar's `spread` is one stored value per bar** (typically its
  lowest), so bid + spread can understate the ask in a spike; the study
  flags hits within 1 pip as borderline.
- **Sandbox PostgreSQL stops between sessions:** start it with
  `su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /var/tmp/pgdata_c -o '-p 55432 -k /var/tmp' -l /var/tmp/pgdata_c/log start"`
  and give every verify run a fresh database.

## TRAPS FROM 2026-09-28 AFTERNOON (RESYNC HALT, PIPSHED FIXES, PROBES)

- **A fill during a broker resync has NO event.** Box 2 lost the trade
  server for ~5 s (16:27:29-34Z); two fills in the gap reached the book
  only through "terminal synchronized": no journal deal line, no
  `OnTradeTransaction`, no `fill_logs` row, no layer (C76). A missed ENT
  halts on I3; a missed EXT stalls silently. Read the terminal JOURNAL
  (`<install>/logs`, not `MQL5/logs`) for `connection ... lost` first.
- **`HistoryDealSelect` replaces the `HistorySelect` list** with that one
  deal (MQL5 docs; P1 on box 2: 26 -> 1). Loop with `HistoryDealGetTicket`
  and read by ticket; snapshot tickets before calling anything that may
  select (C77, ADR-164 D1).
- **An advisor's "confirmed safe" needs the docs, not only the source.**
  Gemini's GQ3 ruled history selection safe by reading call sites; the
  MQL5 documentation says otherwise. Praise and no questions again.
- **The fetch tool invented "NONE FOUND"** for exit positions the raw
  JSON listed. For anything that decides an action, save the raw JSON to
  Downloads (`Invoke-WebRequest -UseBasicParsing -UserAgent "Mozilla/5.0"
  <url> -OutFile ...`) and parse it; the sandbox cannot reach pipshed.
- **MT5 reinitialises an EA only when an input changes.** Properties -> OK
  with nothing changed does nothing; append " x" to `InpConfigWarning`
  (reporting only: config line and archive record).
- **The desktop terminal's scripts are flat in `MQL5\Scripts\`**
  (`desktop_sync.ps1` 25-27); `Scripts\fxmatrix\` exists only on the Linux
  boxes.
- **Files scp'd to `/root` are unreadable to `khalid`:** `install -o khalid
  -g khalid -m 664 <src> <dest>` as root. And `scp` to `box2` asks root's
  password while `ssh box2` may not: the key is not used by scp (unchecked).
- **PowerShell paths with a space and a trailing backslash** break a quoted
  argument (`"$HOME\Downloads\"` -> `Downloads"`): give the full file name,
  no trailing backslash.
- **The daily summary took ABS pips**, so every ejection's loss counted as
  + pips (Fleet B 28 Sep partial day +1382.9 old vs +618.3 net). Signed by
  direction now; commission by account (FTMO 0.06, IC 0.08 per close from
  the ledger). "Deepest stack" was long + short, not a side.
- **Weekend nights write `CARRY_PASS_INCOMPLETE`** on every fleet (Sat and
  Sun 21:00Z, 44 rows): the pass starts, finds eligible layers, cannot act
  with the market closed. Nothing committed; no swap on those nights.
  Noise, not a fault.
- **A test that passes before the change is not testing it** (FS42 checked
  the text summary only; FS32 passed on `invariant_ok` false, not on the
  halted state). Run every new guard against the old code AND break the
  new code once per rule.
- **Study export: `--days 14`, not 7.** The depth timeline needs every ENT
  since each fleet started; `fill_logs` keeps 14 days.
- **The Monday 20:50Z `CARRY_SNAPSHOT` is missing for any instance that ran
  through the weekend** (C79): an incomplete weekend pass leaves the
  snapshot flag set. Read the `CARRY_PASS_SUMMARY` rows, not the snapshot
  list, for the nightly check. A parameter reload does not clear it
  (inferred: MQL5 keeps program globals across a reason-5 reinit; a fresh
  attach does).

## TRAPS FROM 2026-09-28/29 NIGHT (ADR-164 BUILD, AUDIT, FIX ROUNDS)

- **Derive every "(guard)" tag against the STUBS, not from intent.** Rev
  1 of the ADR-164 spec tagged by intent: ~20 untagged assertions passed
  against stubs returning 0/false ("sweep returns 0", "step false"), and
  one "passes in both states" test FAILED at commit 1 (the history flag
  alone left `Grind_DealSelect` live). Write down what each stub returns,
  then derive each assertion from it. An independent re-derivation by a
  second agent found three more (below).
- **An init that reads the clock takes the clock at init.** Tests that
  set the model's "now" to a later time BEFORE `Grind_ReplayInit` put
  every fixture deal before init. Pin the clock to I around init.
- **A reset called by init must not clear what the test set before
  init** (test seams). Split state reset from test-seam reset.
- **A two-step test script built as one step crashes the suite, not a
  test.** `Adr164_ScriptInv` decided the entry count from an empty
  reason; the second call would read past the array (critical error
  stops the whole run). Pass the count explicitly.
- **A fix prompt can move a gap instead of closing it.** "Mark seen
  after processing" does not close "seen but never handled": a failing
  handler select followed by a succeeding mark-seen select still loses
  the deal. Model the failure at EVERY position in the call sequence
  before claiming a fix; a transient between two calls can fail either
  one. Gemini accepted the wrong premise ("mathematically guarantee").
- **A prompt that forbids what its design needs makes Cursor improvise**
  (round 1 forbade changing `Grind_ProcessDeal`'s signature while needing
  it to report success). Check every design line against every "do not".
- **Cursor can ignore a prompt entirely** (round 2's first run built its
  own DR21/DR22 and reused the prompt's labels for other changes). The
  gate: RESTATE AND STOP inside the prompt (BOOT s2); read every commit
  before the operator compiles; revert, never force-push.
- **A clock of 0 is not "no window".** `from = 0` selects the account's
  whole history and replays every unseen deal of the magic: ghost layers
  with exits. Defer instead (ADR-164 `REPLAY_INIT_DEFERRED`).
- **`DEAL_REPLAYED` on a healthy day is not a fault.** The 1 s timer can
  run before a fill's queued `OnTradeTransaction`; the sweep handles the
  deal and the event is dropped as `DEAL_EVENT_AFTER_REPLAY`. Only
  `DEAL_EVENT_MISSED` (no event 60 s after a replay) means C76.
- **`git pull` from the desktop can fail "Recv failure: Connection was
  reset"** and the rest of a `;` chain still runs. Check the output, and
  re-run a failed push; a push onto a moved remote is refused, never
  overwrites.

## TRAPS FROM 2026-09-30 (STUDY DATA, BOX 2, POWERSHELL)

- **PowerShell eats `{}`: quote `"HEAD^{tree}"`.** Unquoted, git gets
  `HEAD^` and prints the PARENT COMMIT hash, which looks like a tree.
- **A trailing backslash escapes the closing quote in PowerShell:**
  `scp ... "$HOME\Downloads\"` fails; write `"$HOME\Downloads"`.
- **Under Wine the Experts log folder is lowercase:** `MQL5/logs/`
  (not `MQL5/Logs`).
- **Compile ONE file in MetaEditor.** `Scripts/fxmatrix` holds copies of
  the whole EA; compiling the folder builds them there (harmless: live
  EAs run `Experts/fxmatrix/fxgrind.ex5`). **CORRECTED 1 Oct: WRONG for
  wine-c, whose charts load `Scripts\fxmatrix\fxgrind.ex5`: that 30 Sep
  15:22 compile rebuilt the live EAs' binary (same source, so no harm).** Check that file's date and
  the log for `deinit` if unsure; never RUN `fxgrind_tests` on a live box.
- **An M1 bar's spread is the minute's MINIMUM.** At news and rollover
  the bid spikes while the real ask stays far away: bid + bar spread
  invents fills. Use `scripts/grind_bidask_dump.mq5` (true ask).
- **Cycle 2 used fleet A's instance ids.** Any archive window reaching
  before 24 Sep mixes two books; filter by session -> account.

## TRAPS FROM 2026-09-30 AFTERNOON (PIPSHED FLEET D, SANDBOX PG, WINE-D)

- **The sandbox scratch PostgreSQL role is `verify`, not `postgres`.**
  After a container restart a stale `.s.PGSQL.55432.lock` and
  `postmaster.pid` stop it starting. As root:
  `rm -f /var/tmp/pgverify/.s.PGSQL.55432* /var/tmp/pgverify/data/postmaster.pid`
  then
  `su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /var/tmp/pgverify/data -l /var/tmp/pgverify/log -o '-p 55432 -k /var/tmp/pgverify -c listen_addresses=127.0.0.1' start"`
  (`log` is a FILE). Per suite: drop and create database `verify` as
  role `verify`, `VERIFY_DATABASE_URL=postgresql://verify@127.0.0.1:55432/verify`.
- **A test asserting a null is a design statement.** FS3 ("D url must be
  null") broke when D got its address; grep the verify scripts for the
  old value and change them IN the tests-first commit, not after.
- **The JSON was right and the page was wrong:** the dashboard's
  placeholder card hard-coded "Fleet D -- not built yet" / NOT BUILT
  whatever the API said. Read the template branch too (FD12 guards it).
- **A fake Redis without `lrange` passes with tracebacks:** the fleet
  strip logs ERROR per fleet and carries on, hiding a real failure. Give
  every fake the methods the code path calls (`lrange` -> `[]`).
- **Say the hostname:** wine-test, wine-c, wine-d (operator 30 Sep), not
  box 1/2/3; the desktop SSH short names stay `box1`/`box2`.

## TRAPS FROM 2026-09-30 EVENING (C81, WINE-D OPTIONS, STUDY s12, SWAP DAY)

- **A sum over a filtered subset is a sum over a DIFFERENT basket each
  run.** The reconciliation gate picks which instances enter a fleet
  total; noon's "B peaks at cap 6-7" came from one trending instance
  (EURGBP_OPTB) that was in B's noon basket and out of the evening one.
  Compare runs on the intersection of their baskets, and never compare
  fleets whose baskets differ (Gemini GQ13, study s12.4).
- **"Settled empirically" in an ADR is a claim, not a measurement.**
  ADR-135b says the triple-swap day was settled from 16 Sep snapshots;
  the ledger (one-night positions, study s12.7) shows the EA's pending
  multiplier one day off (Tue 3 / Wed 1 / Fri 0 vs truth 1 / 3 / 1).
  Check the premise against broker deals before building on it (C86).
- **MT5 under Wine keeps options in `<install>/Config/` (capital C), and
  `WebRequestUrl` is encoded per install.** A grep proves WebRequest is
  on, not which URL; read the list in the GUI (06 s10).
- **The fetch tool caches a 404 by path:** `linuxd.pipshed.com/` stayed
  404 in the tool after the domain went live, while a new path on the
  same host answered. Use a new path, or have the operator open it.
- **Screenshot and fetch disagree -> trust the page.** At 21:29-21:32Z
  the fetch tool quoted 146 scalps / $48.18 for cycle 3 where the
  rendered card read 144 / $47.14 (and C 184 vs 182).
- **A study's control rate divides by hours at cap:** sides at cap for
  seconds print rates like 39130/h (study s12.6). Read the count.
- **scp from the desktop to `box2` asked root's password** (30 Sep
  22:21Z; the key is used by `ssh box2` but not by scp): the operator
  typed it. Unresolved; add `IdentityFile` use for scp or copy through
  `ssh box2 cat` when it matters.

## TRAPS FROM 2026-10-01 EARLY (IC ROLLOVER, C60 MISREAD, DASHBOARD)

- **A "failed" count is not a retcode.** C60 explained carry-pass
  failures as 10025 "no changes" (Friday's zero pending); C's AUDNZD
  failures on 30 Sep were 10021 PRICE_OFF (IC had no quotes at 23:50
  server). Read `send_logs` (`--table send_logs --instance X`) before
  attributing a failure count to a known cause.
- **IC Markets holds order requests across its 00:00 server rollover**
  (C87): `[Market closed]` answers arrive minutes late and requests time
  out at exactly 180 s, with the terminal still connected (once in seven
  nights: the 30 Sep quarter-end rollover; every IC night rejects
  'market closed' fast at 23:59-00:01). Expect slow
  or failed modifies, rolls and exit moves at 21:00-21:15Z (EDT) on the
  IC fleets; FTMO is unaffected. Do not read a ROLL_CLOSING_STUCK or a
  timeout in that window as a lattice fault without this.
- **The MT5 Journal's lines are almost all trade lines:** a filter that
  drops lines containing "order" leaves nothing. Grep for "connection",
  "authorized", "synchroniz" positively instead.
- **Dashboard secondary text was #666 (3.2:1 on the cards):** the
  operator could not read it. `verify_dashboard_contrast` now guards
  --muted at >= 6.0:1 (pipshed `052c72a`).
- **A mutation that keeps the file the same size within one second can
  run against STALE bytecode** (`__pycache__` checks mtime and size): a
  correct test then "fails" or a mutant "survives". Run mutation checks
  with `PYTHONDONTWRITEBYTECODE=1` and delete `__pycache__` first (1 Oct,
  `research/grid_thesis`).

## TRAPS FROM 2026-10-01 C63 (WRONG BINARY, RELOADS, QUOTING, KEY)

- **A chart loads the `.ex5` at the path it was attached from.** wine-c's
  eleven charts were attached from `Scripts/fxmatrix` on 27 Sep; every
  compile of `Experts/fxmatrix/fxgrind.mq5` tonight changed nothing live.
  Read the chart profiles before compiling (`Profiles/Charts/*/chart*.chr`,
  UTF-16: `path=`). wine-test's charts load the Experts copy.
- **A parameter reload (reason 5) keeps the loaded binary**, and a
  terminal restart reloads from the chart's path: neither picks up a
  compile of another copy. Proof of the new build at init is
  `GRIND_REPLAY ready` (`replay=ready` in the checker).
- **PowerShell splits an unquoted comma list** before `railway ssh` sees
  it: `--codes A,B` arrived as "A B" and returned "none.". Quote it:
  `--codes 'A,B'`.
- **The live telemetry key = the key committed in `ea/Globals.mqh` since
  19 Jun** (the first 34 of 43 characters compared in the sandbox,
  neither printed), after the Inputs tab's key row appeared in a
  screenshot again. The key has been public for months: C9 is a
  data-integrity item now (anyone can push telemetry), not a trading one.
- **A screenshot of the Inputs dialog must stop above `TelemetryAPIKey`.**

## TRAPS FROM 2026-10-01 EARLY MORNING (WINE-D: A WEDGED X, VNC)

- **Stale RDP tunnels wedge the X display.** After connection drops, two
  old `sshd` sessions on wine-d still held forwarded RDP connections;
  xrdp had ~9.8 MB queued to a dead client and blocked, and with it X
  (`xdpyinfo` hung, x11vnc froze after printing its version). Fix: list
  them (`ss -tnp | grep ':3389'`), kill only the stale `sshd` pids (never
  the session you are typing in: `ps -o ppid= -p $$`), and X answers
  again within seconds. MT5 kept running throughout.
- **x11vnc for a shaky line:** `-noipv6 -forever` (the tunnel's
  "localhost" tried `[::1]` first and five attempts sat unaccepted in its
  queue; `-once` exits after one dropped client). One SSH window can be
  both shell and tunnel: `ssh -o ServerAliveInterval=15 -o
  ServerAliveCountMax=8 -L 5912:localhost:5912 root@216.128.158.33`, run
  from the DESKTOP prompt (it was once typed inside wine-d).
- **A fresh box has no `MQL5/Presets`:** create it as khalid before
  staging (`sudo -u khalid mkdir -p`).

## TRAPS FROM 2026-10-01 D1 (TWIN CHARTS, MAGIC LOCK, SCREENSHOTS)

- **After Load, the Properties dialog shows the PRESET's magic, not the
  chart's.** Both twin charts are titled "fxgrind 2.00 (NZDCAD,M5)", so a
  readback after Load cannot tell which chart you are on. Read `InpMagic`
  BEFORE clicking Load; if it is the other instance, Cancel (nothing is
  applied until OK). 1 Oct 06:24Z: the twin's preset went onto the
  primary chart, which failed init on a duplicate magic and was unloaded
  (fleet-d.md s7).
- **A failed init is not a halt: the EA is UNLOADED from the chart.**
  The chart keeps no EA (no name top-right); its book sits at the broker
  unmanaged until a re-attach. Re-attach from Navigator -> Expert
  Advisors -> fxmatrix -> fxgrind with the chart's OWN preset.
- **`OnDeinit` frees the magic lock of whatever `InpMagic` it holds,
  even after a FAILED init** (`fxgrind.mq5` 372; `deinit reason=8` in the
  log): the failed duplicate deleted the live twin's lock, so a third
  duplicate would have passed the guard. Re-established by the twin's
  next reload. Backlog C89.
- **pipshed keeps a CRITICAL red for 24 h unless it is a halt code**
  (`_FLEET_STRIP_HALT_CODES`, `app.py` 902): `DUPLICATE_MAGIC` stays red
  after the fix; the card (LIVE 11/11) is the truth. Backlog C90.
- **Crop screenshots so `TelemetryURL` is the LAST row.** A dialog
  captured to its bottom edge showed the top half of the
  `TelemetryAPIKey` row (wine-c, 06:48Z). The key is the public one
  (C9), so nothing new leaked; C9 records it.
- **Two shells, two boxes: read the prompt.** A wine-c command typed in
  the wine-d window ran on wine-d (harmless: read-only plus a no-op pull).

## TRAPS FROM 2026-10-01 AFTERNOON (CHF TREND, COMMANDED EJECTS, FTMO HALTS)

- **A commanded eject is a Global Variable, not a script.** In the box's
  MT5: F3 -> Add, name `GRIND_EJECT_<magic>`, value = the position ticket of
  the side's MOST UNDERWATER layer (highest effective entry for a long; any
  other is refused `NOT_DEEPEST`). The EA reads it within a second and
  deletes it. `scripts/grind_eject.mq5` is not compiled on the boxes.
- **F3 Add creates the variable with value 0 first:** the EA reads it at
  once and logs `eject refused ticket=0 reason=NOT_FOUND`. Harmless; the
  typed value arrives as a second write and is accepted.
- **A passive eject trails a running market.** Its exit goes just beyond
  the market at accept time; if the trend continues it sits unfilled
  (AUDCHF B 15:30-16:00Z). Re-issue the same command: it re-prices to the
  current market (no "already ejected" refusal, `grind_engine.mqh` 382).
- **`ROLL_STRANDED` is sent once per episode; nothing marks recovery.**
  It stayed amber 24 h after the side was unstranded (fixed: pipshed C94).
  Test from status: a side is stranded only if it is at cap, EVERY layer is
  rolled (long exit below entry) and the market is 2 add steps past the
  lowest level.
- **FTMO can fill a pending limit WORSE than its price in a fast market**
  (AUDNZD short L02: BUY_LIMIT 1.23360 filled 1.23365). The EA's start-up
  I6 treats that as impossible and halts (`I6_*_EXIT_FILL_ADVERSE`). Repair:
  Close By the layer with its filled exit position in the terminal, then a
  reason-5 restart (C92).
- **A halt cancels the instance's ENTRY orders but leaves exits resting;**
  exits that fill during the halt are not closed by (the EA is idle): the
  restart's reconstruction must accept them (or see the trap above).
- **The day total, not closed P&L, compares ejection with rolling:** 1 Oct
  A closed -$119 / open -$144 vs B +$46 / -$282; totals -$263 vs -$235.
  (Line restored 2 Oct; a later commit had dropped it.)

## TRAPS FROM 2026-10-01 EVENING (LINK STALL, ORPHANS, SUITE COPY)

- **A stalled link drops deals BEFORE MT5 says "connection lost".** The
  VPS fill at 17:55:20.9Z came ~20 s before the Journal's `lost` line
  (17:55:41.3). After ANY `connection ... lost` line on A, check every
  book, not only the instance that halted: a missed ENT halts on I3, a
  missed EXT stalls a side with no alert at all.
- **The orphan check reads each instance's NEWEST book only.** Reading
  the last N `HEARTBEAT_BOOK` lines includes books from before a repair
  and reports orphans that are already gone. The working command (VPS):
  `$log = "$env:APPDATA\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Logs\<yyyymmdd>.log"; $last = @{}; Get-Content $log -Encoding Unicode | Select-String 'HEARTBEAT_BOOK' | Select-Object -Last 60 | ForEach-Object { $last[($_.Line -split '\|')[1]] = $_.Line }; foreach ($k in $last.Keys) { $j = ($last[$k] -split '\|HEARTBEAT_BOOK\|', 2)[1] | ConvertFrom-Json; $j.book.positions | Where-Object { $_.comment -like '*|EXT' } | ForEach-Object { "ORPHAN? $k $($_.ticket) $($_.comment) $($_.open_time)" } }; "instances seen: $($last.Count)"`
  An EXT seconds old is a close-by in flight; minutes old is an orphan.
  Repair = reattach that chart (`InpConfigWarning` + " x"); twins: read
  `InpTelemetryInstance` and `InpSlot` first.
- **Grep logs, do not paste them** (operator). The Experts log is UTF-16:
  `Get-Content <log> -Encoding Unicode | Select-String ...`; the VPS clock
  and log times are UTC; the Journal is `<data>\logs\`, the Experts log
  `<data>\MQL5\Logs\`. Output saved under `D:\fxmatrix\temp\` or
  Downloads can be read by Claude directly (both folders connected).
- **Suite run without `desktop_sync.ps1` ran the OLD suite** (total 2366,
  no RR rows) and on a USDJPY chart (3-digit point: ~200 price failures).
  Sync after every checkout, confirm a branch-only symbol in the Scripts
  copy, run on GBPUSD and EURUSD only.
- **The desktop test terminal is logged in to FTMO 1514731800.** It is the
  "previous successful authorization performed from 64.229.9.87" in the
  VPS Journal (17:16Z 1 Oct: the first suite run). The operator keeps it
  (useful for testing). The suite has never sent a request: 0 `Trades '`
  lines in every desktop Journal 25 Aug-1 Oct. Re-count if anything looks
  off: `Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\logs\*.log" | ForEach-Object { $n = (Get-Content $_.FullName -Encoding Unicode | Select-String "Trades '").Count; "$($_.Name) $n" }`.
  A second session on the account is visible to the VPS (and to FTMO).
- **Gemini restated a Cursor prompt as if he were Cursor** (RESTATE AND
  STOP applies to him too when he reads it). Harmless; his GE answers
  followed.

## TRAPS FROM 2026-10-01 NIGHT (IC BREAKER OFF BY F7)

- **The Inputs dialog shows an input's COMMENT, not its name, when it has
  one.** `InpBreakerEnable` appears as "ADR-158 account daily-loss
  breaker"; likewise "ADR-157 automatic passive ejection", "ADR-162
  virtual lattice past cap", "ADR-161 entry window ...". Checklists must
  give the label as the dialog shows it.
- **`InpBreakerEnable` is not in the CONFIG line**, so a grep proves the
  re-init, not the value. Proof of the value is the outcome: resting
  entries back. Per box: `iconv -f UTF-16LE -t UTF-8 "$L" | awk -F'\t'
  '$3>="<hh:mm>"' | grep -a "CONFIG InpMagic" | grep -ao
  "InpTelemetryInstance=[A-Z_]*" | sort | uniq -c` (field 3 is the time;
  11 instances, count 1 each). Entry orders per instance from the newest
  `HEARTBEAT_BOOK` (python3 is on the boxes): see HANDOFF s30.
- **x11vnc on wine-c and wine-test runs `-once`**: restart it inside the
  tunnel session each time (`sudo -u khalid x11vnc -display :10 -auth
  /home/khalid/.Xauthority -localhost -rfbport 5911|5910 -nopw -once
  -shared -noxdamage -bg -o /tmp/x11vnc-...log`). wine-d's runs
  `-forever` on 5912.
- **The FTMO request counter resets on the first quote stamped with the
  new server date**, not at 21:00Z sharp (1881 at 21:02Z, 4 at 21:14Z).
- **The strip endpoint can time out** (C102): when it is slow, read the
  EA logs on the box instead of refreshing.
- **A run of the grep before the edits returns nothing**: an empty list
  means "no re-init since that time", check the clock before debugging.

## TRAPS FROM 2026-10-02 EARLY (STUCK SIDES, L0 RE-QUOTE, READING STATUS)

- **"Stuck" comes before `ROLL_STRANDED`.** A capped side with every layer
  rolled cannot roll again once the ask (long) passes the next level
  (lowest effective - add); the WARN fires only one add step later
  (`GRIND_VL_STRANDED_STEPS` 2, engine 1127-1160 at `0335f25`). Watch the
  distance to the next level, not the alert. Commanded eject over VNC
  worked in under a minute per side (2 Oct: B 28 s, C 52 s to fill).
- **`/status*` layer rows have no `virtual_level`.** Infer the effective
  entry from `exit_target -/+ exit_pips` (long/short; accrual is a
  fraction of a pip); a layer is rolled when that sits more than half an
  add below its entry (long). Only `/ejection` carries the VL. Bid/ask
  are not in the heartbeat either: fit them from the book's positions
  (profit = k (bid - open) for a BUY; k = 1000 on USD-quoted pairs).
- **Claude's sandbox cannot reach pipshed** (proxy 403) and fetch
  summaries garble numbers: save the JSON to Downloads with
  `Invoke-WebRequest ... -OutFile` and let Claude read the file.
- **The L0 re-centre has NO direction check.** It moves the empty side's
  L0 to mid +/- W whenever it sits more than S from mid AND the move is at
  least D (`grind_pure.mqh` 170: inside the band is `< D`). If S < W - D
  it also moves the L0 AWAY from a market approaching it. Keep S >= W - D
  (S = W + 1 now). The drift that re-quotes is max(D, S - W) (ADR-153).
- **`InpStrandedThreshPips` and `InpDeadbandPips` have no input comment:**
  the Inputs dialog shows their names, and both are in the CONFIG line
  (a grep proves the values, unlike `InpBreakerEnable`).
- **A connected VNC viewer stays usable for the whole session** (2 Oct,
  wine-test and wine-c: the operator kept both viewers open across the
  ejects and 22 reloads). `-once` ends the server only when that client
  disconnects: keep the viewer open while working, restart x11vnc after
  closing it.


## TRAPS FROM 2026-10-02 DAY (PIPSHED OUTAGE, HOTFIX DEPLOYS)

- **`deploy.ps1` starts with `git pull origin main`.** On any branch
  other than main it MERGES main into it and you compile main's code.
  For a branch build on the VPS do its copy and hash-check by hand
  (HANDOFF s32 has the command).
- **pipshed.com ran on `flask run` (the dev server) until 2 Oct.** One
  thread per request, one core: slow responses -> EA posts abandoned at
  200 ms -> cut-off bodies answered 400 -> the same growing batch re-sent
  every 2 s -> threads pile up -> `can't start new thread`. A restart
  only buys ~10 minutes. The start command now runs gunicorn (Railway
  setting only; C102).
- **A dead pipshed does not stop trading** (200 ms WebRequest timeout)
  and loses no archive rows while each EA's queue (5000) holds; a
  restart, compile or reattach of an EA DOES lose its queued rows: no EA
  restarts while pipshed is down.
- **Which `.ex5` the charts load, when profiles are not saved:** MT5
  writes chart profiles only on exit, so `Profiles/Charts` can hold the
  stock samples. Match the INIT record's `ea_build` (the compile time,
  `GRIND_EA_BUILD`) to the `.ex5` files' modified times: wine-test and
  wine-d load Experts, wine-c Scripts, the VPS Experts (2 Oct).
- **`Select-String` ignores case:** `RECON_FAIL` matched `recon_failure`
  inside every HEARTBEAT line (12 false hits after the VPS compile). Use
  `-CaseSensitive`, or read the newest HEARTBEAT's flags.
- **Git on the VPS asks "Unlink of file ... failed. Should I try again?"**
  after a fetch (auto-gc, a locked pack file): answer n; harmless.
- **Claude cannot read `AppData` folders** (the device bridge refuses
  them); it reads only Downloads and `D:\fxmatrix\temp` unless the
  operator connects a folder with the desktop app's folder picker.
- **x11vnc on wine-test and wine-c now runs `-forever -noipv6`** (2 Oct):
  after a desktop reboot only the SSH tunnels need reopening.


## TRAPS FROM 2026-10-02 AFTERNOON (RETIRING INSTANCES BY HAND)

- **There is no "stop new entries" input.** Retiring an instance: remove
  the EA (right-click the chart -> Expert Advisors -> Remove: Experts log
  `deinit reason=1`), delete its resting orders ENTRIES FIRST (an entry
  that fills after removal is unmanaged), then Close By long against
  short, then close the rest at market. `OnDeinit` touches no orders.
- **F7 then OK is a restart, not a removal** (`deinit reason=5`, the EA
  re-initialises). Read the instance in the dialog, then Cancel.
- **Twin positions carry near-identical tickets** (opened in the same
  second: 555273730 ALT vs 555273732 OPT; 552677357 vs 552677358). Pick
  by magic and comment, never by ticket shape.
- **Journal formats:** a deleted order logs `accepted cancel order #N`; a
  close-by `close position #A ... by position #B ... done`; a market close
  `market buy 0.01 X, close #N ... placed for execution`. A cached
  `$c = Get-Content` is a snapshot: re-read after acting.
- **A deinit line names the chart, not the instance:** confirm which twin
  stopped from the newest HEARTBEAT per instance.
- **FTMO counts requests, not lines:** ~2 Journal lines per request (sent +
  accepted). Count sent lines only (exclude accepted/done/placed/failed).


## TRAPS FROM 2026-10-02 LATE AFTERNOON (PIPSHED AFTER THE RETIREMENTS; HANDOVER)

- **Retiring an instance is not finished until pipshed knows.** Add its
  id to `GRIND_RETIRED_INSTANCES` (C108: its critical rows show resolved)
  and drop it from the fleet's strip list (`GRIND_A_STRIP_INSTANCES`,
  C107); otherwise the card says PARTIAL and the banner stays red for a
  problem that can never "run again".
- **Jinja's `tojson` SORTS dict keys.** The page's rings JSON arrives in
  alphabetical order (`aud_cad_chf` first), not `GRIND_RINGS` order:
  never take "the first instance" from it. The page opens on
  `GRIND_DEFAULT_INSTANCE` since C109 (on 2 Oct it opened on retired
  AUDCAD_OPT and the badge said CONNECTION LOST over a healthy fleet).
- **The top-right badge follows ONE instance** (the selected tile), not
  the fleet: CONNECTION LOST there with LIVE cards means the selected
  instance has no state key (retired, or a cycle-2 `_ALT` tile). Read the
  footer "Instance:".
- **Claude can read pipshed after all:** WebFetch of
  `/api/telemetry/live?instance=<id>` works (a summary), and the browser
  pane on the operator's desktop (allowed for pipshed.com, scope site)
  runs page JS: `currentInstance`, the badge text, fetches per instance.
  The sandbox shell still gets 403.
- **PowerShell eats `{tree}`:** `git rev-parse HEAD^{tree}` prints the
  parent COMMIT and an `-encodedCommand` error. Quote it:
  `git rev-parse "HEAD^{tree}"`.
- **A patch can be applied and not pushed.** Before building on GitHub's
  main, ask for `git log origin/main..HEAD` on the desktop; on 2 Oct a
  combined patch failed on every file because its first commit was
  already applied locally (`2fce0d4`). Undo with `git am --abort`
  (the working tree stays clean).


## TRAPS FROM 2026-10-02 EVENING (PIPSHED SATURATED BY PAGE READS)

- **CPU pinned with FEW requests means each request is expensive,** not
  that there are many. 2 Oct: ~4.5 vCPU at ~80 requests a minute. Look for
  reads whose cost grows with stored history (`lrange(key, 0, -1)` then
  parse every row) before suspecting volume or workers.
- **Railway: read the ACTIVE deployment.** The Deployments list can open
  an old one (badge "Removed"); its logs say nothing about today. Network
  Logs show path, status and duration only (no user agent or IP). Status
  499 = the client gave up. A `/api/g/<token>/.../<n>` path's last segment
  is the browser's `Date.now()` in ms: it dates when a page SENT the call.
- **"Close the tabs" may not find the poller.** A page kept polling after
  the operator closed his tabs (device never found). Fix the server's cost;
  do not depend on hunting tabs.
- **The EA DROPS an archive batch the server answers 400**
  (`grind_archive_flush.mqh` 70-78: counted, `TELEMETRY_BATCH_REJECTED`);
  only a timeout or other status keeps it queued. "No rows lost" needs that
  marker (or the Experts log's `archive batch rejected`) checked, not
  `TELEMETRY_QUEUE_DROPPED` alone (C112).
- **Scalp lists in Redis hold 3,000 rows per instance**
  (`SCALP_HISTORY_LIST_MAX`): anything summed from them since a date
  (the strip's cycle totals) is short once a list is full (C111). The
  archive (PG) is the complete record.
- **A granted folder does not always bring the file tools.** 2 Oct:
  Downloads granted, but no device write tool loaded; the patch went out
  as a file card and the operator saved it.


## TRAPS FROM 2026-10-02 NIGHT (PIPSHED TABLES, PATCH HASHES)

- **After the operator's `git am` and push, reset the sandbox to GitHub.**
  `git am` gives the commits new hashes (same tree); a sandbox still on its
  own copies builds the next patch from `origin/main..HEAD` WITH the old
  commits, and that patch fails `git am` on a clean clone (2 Oct, C115's
  first build). Check the trees match, then `git reset --hard origin/main`.
- **A test that checks an exact call breaks when an argument is added.**
  C114's QG5 checked `renderFleetBooks(data && data.books, data && data.gaps)`
  literally; C115's third argument broke it (caught by C115's guard). Check
  the intent (the argument passed), not the whole call; when an old test
  must change, change it in the tests-first commit if foreseen, else say so
  in the fix commit.
- **The sandbox's scratch PostgreSQL stops between turns.** Suites then
  fail with "Connection refused" (four archive suites). Restart it (the
  2026-09-30 command) in the same step as the suite run.
- **The first strip call after a pipshed deploy is slow** (14 s on 2 Oct):
  each gunicorn worker builds its C110 scalp cache on its first read.
- **The quote tables show resting orders only.** A one-sided cell means
  that side cannot trade with us until something fills (EURGBP D 8/0: every
  resting order a sell). The italic level is the lattice's next level on a
  capped side (no order; reaching it rolls an exit); "no roll" = capped and
  fully rolled. Held adds are not shown (C116).
- **The heartbeat carries no lattice flag and only the base `add_pips`**
  (per-side adds are -1 everywhere since D1). pipshed's FLEET_STRIP says
  which fleets run the lattice (C115): change it if a fleet's mode changes.
- **IC's carry pass on a Friday finishes before the close** (2 Oct: 40/40
  summaries 20:52-20:57Z, none incomplete, the 14-layer books last at
  20:56Z); `failed` 2-4 per instance is Friday's zero pending (C86).


## TRAPS FROM 2026-10-03 EARLY (REQUEST COUNT, EXPORTS)

- **FTMO's day = 22:00Z to 22:00Z across two Journal files.** The working
  count (VPS, 2 Oct; dates are the two files; it leaves `$rows` for an
  hourly split): `$d = "$env:APPDATA\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\logs"; $rows = foreach ($f in '20261001','20261002') { Get-Content "$d\$f.log" -Encoding Unicode | Select-String "Trades\s+'" | ForEach-Object { if ($_.Line -match '\s(\d\d:\d\d:\d\d)\.\d{3}\s') { $t = $Matches[1]; if (($f -eq '20261001' -and $t -ge '22:00:00') -or ($f -eq '20261002' -and $t -lt '22:00:00')) { $_.Line } } } }; $sent = $rows | Where-Object { $_ -notmatch 'accepted|done|placed|failed|rejected' }; "lines $($rows.Count)  sent $($sent.Count)  deals $(($rows | Select-String 'deal #').Count)  failed $(($rows | Select-String 'failed|rejected').Count)"`.
  The by-type split groups `"':\s+(\w+ \w+)"` over `$sent`. The six types
  summed to the sent total on 2 Oct; check that again.
- **A day that straddles a fleet change is not that fleet's day:** 2 Oct
  ran more FTMO instances until ~15:40Z; split by hour before comparing.
- **Exports from PowerShell carry a BOM** (`Set-Content -Encoding utf8`);
  `ev_data.load_export` handles it, other readers need `utf-8-sig`.
- **Hedging accounts never merge positions:** an opposite limit fill opens
  a new position and same-direction fills stay separate (no "add by");
  only netting accounts hold one position per pair (C117).
- **The 200 positions + orders limit applies on IC too** (operator, tested):
  more pairs means more accounts, not a bigger book.


## TRAPS FROM 2026-10-03 MORNING (DUMPS, REPORTS)

- **PowerShell: never end a native command's quoted path with a
  backslash.** `scp ... "$HOME\Downloads\"` passes `Downloads"` (the `\"`
  escapes the quote): give the full target file name. Remote Wine paths:
  `Program*Files/MetaTrader*5` globs avoid the spaces.
- **wine-d's `Scripts/fxmatrix` lacks the research scripts** (its repo is
  on `hotfix-api-stop`). Install one without changing the branch:
  `sudo -u khalid git -C /home/khalid/fxmatrix-repo fetch -q origin`, then
  `git show origin/main:scripts/<file>` into the Scripts folder with
  `install -o khalid -g khalid -m 664`; check the sha; compile ONE file.
- **FTMO's deal history can be dumped from the desktop terminal** (the
  same account): read-only, no request counted.
- **`gt_report.py` knows fleets A, B, C only** (`ev_data.fleet_of`): drop
  the `_OPTD`/`_ALTD` rows from the export first; and it crashes on a
  bid/ask folder holding pairs outside `GEO_A`: give it the traded pairs
  only. No code change made (C83 note).
- **A provisional compass run divides by the round's full days** (2), so
  mid-round per-day values are halved; only Monday's run is a verdict.


## TRAPS FROM 2026-10-03 AFTERNOON (C105 MERGE, MONDAY BUILD PREP)

- **The desktop terminal has a stale `MQL5\Experts\fxmatrix\` folder**
  (its `grind_api_counter.mqh` still says 1800 on 3 Oct). `desktop_sync.ps1`
  writes the FLAT `MQL5\Experts\` and `MQL5\Scripts\`; check those after a
  sync, never the subfolder.
- **A suite that seeds at a define passes on either value** (the API
  stop tests read `GRIND_DAILY_API_*`): after a constant change, prove the
  terminal copy carries the new value (Select-String the define) as well.
- **ADR-165 throttles one re-roll per side per CALL** (tick or timer
  pass), not per second: a gap backlog clears over successive ticks,
  several a second by design. A throttle failure is two re-rolls of one
  side with the same `ea_time_ms` (Monday build STOP list, GB-4).
- **pipshed's strip counts, slots and API are summed over the STRIP
  list**: deploy a retire patch (C119) only after the instances are gone,
  or the card undercounts a live account.


## TRAPS FROM 2026-10-03 AFTERNOON (C93, C107)

- **`OrdersTotal()` / `PositionsTotal()` walks race with other EAs.** The
  account's lists are shared by every EA thread; an item removed below the
  walk's index makes the next index re-read one already seen (a removal
  above skips one). C93's halt was a duplicate read of ONE order (v2.2
  fix). When a halt lists the same item twice, check the Journal before
  believing the book.
- **The EA does not print order placements in the Experts log;** every
  request is in the terminal Journal (`<data>\logs\YYYYMMDD.log`,
  "buy limit ... at <price>", "accepted", "order #N ... done").
- **Global Variables: list, classify, delete by EXACT name, dry run
  first** (`scripts/grind_gv_list.mq5`, `scripts/grind_gv_delete_exact.mq5`,
  C107). Ticket-named carry records (`GRIND_CARRY_ACCRUED_<ticket>`,
  `_SHIFT_`) are classified against the account's deal history (open vs
  closed, and whose magic). Never delete by prefix on a live terminal.
- **`GlobalVariableTime` is the last ACCESS time:** reading a variable
  updates it, so a listing's times are the listing's own time.


## TRAPS FROM 2026-10-03 LATE AFTERNOON (v2.2a prompt)

- **No ticket numbers in the heartbeat or the recon-failure JSON** (ADR-125:
  the public status endpoint carries the heartbeat; `Test_F4` and
  `Test_D5` enforce it). A backlog line can ask for something a standing
  policy forbids (C93 item 3 did): grep the tests for the field before
  specifying it. Tickets go to the local Experts log.
- **`git diff 2859be6 HEAD -- ea/` is no longer empty:** the 51 IC presets
  under `ea/presets_*` changed (`InpLatticeReroll=true`). For "no EA code
  change", diff `ea/*.mq5 ea/*.mqh` only.
- **Clock times in the handoff come from the clock tool, not estimates:**
  s41 and s42's end times (~17:45Z, ~18:10Z) ran ahead; s42 ended
  before ~17:10Z.
- **A one-tick false duplicate halts; a one-tick skip does not:**
  `AMBIGUOUS_*` is not quarantinable, I2 / I3 / I4 / I6 are (3 s and 3
  checks). That is why C93 halted at once.


## TRAPS FROM 2026-10-03 EVENING (HASHES AFTER GIT AM, STALE RUNBOOK CHECKS)

- **A hash written into docs before the operator's `git am` does not
  exist on GitHub.** `git am` re-stamps the committer, so each commit
  gets a new hash with the same tree: the v2.2a prompt `9d3ac45` is
  `c92d9c2` on `main`, the s43 docs `a9115b1` are `27e1e77`. Cite the
  tree beside a pre-am hash, and point Cursor and Gemini at the hash on
  GitHub.
- **A runbook check written before a later commit can trip a false
  STOP.** Monday's s3.3 diffed all of `ea/` against `2859be6`; the preset
  commit `4a1e30e` came after and the check would print 51 files. The
  trap was recorded (3 Oct late afternoon) but the runbook was amended
  only in s44. Before a runbook's night, re-run each of its checks
  against current `main` in the sandbox.
- **MT5 writes the Experts log in chunks.** A grep run seconds after
  the second suite run can miss it (3 Oct: the EURUSD run at 14:57:29
  was not in the file at 14:57:5x; a re-run caught it). Wait ~10 s, and
  check that both SUMMARY lines are in the saved file before reading
  the failures.
- **Cursor commits but does not push unless the prompt says so.** The
  v2.2a prompt asked for commits only, so the branch stayed on the
  desktop until the operator pushed it; the audit-fix prompt put
  `git push origin <branch>` in its negative-space block. Say it in
  every Cursor prompt whose commits Claude must read.
- **pipshed's C110 SR3 fails every evening 21:00-24:00Z** (C122): the
  fixture dates rows in UTC, the endpoint by broker date. A 39/40 run in
  that window with SR3 the only failure is this, not your change; check
  it on untouched `main` before believing either way.
- **A fresh sandbox has no scratch PostgreSQL:** `initdb -U verify
  --auth=trust` into `/var/tmp/pgverify/data` as postgres, then the
  2026-09-30 `pg_ctl ... start` line; `pip install -r requirements.txt
  --break-system-packages` for pipshed's suites.


## TRAPS FROM 2026-10-03 NIGHT (HASHES FROM ANOTHER SANDBOX, A RULE ACCEPTED MID-ROUND)

- **A commit hash written by another chat's sandbox may exist nowhere.**
  The C119 commits are `99980da` / `4d294a6` in the docs and `93f7595` /
  `65dbd36` in the sandbox that delivered the patch; neither is on GitHub
  (the patch is only in Downloads). The mfperp root was written as
  `8fd6e87`; GitHub has `643fa12` (same tree `764520d9`). For anything
  not yet pushed, cite the TREE and the patch file name; check a cited
  hash with `git cat-file -t` before building on it.
- **A rule accepted after a round opens does not silently bind that
  round.** GC-1 (control-pair threshold) was accepted 3 Oct ~05:30Z;
  round 1 opened Thu 22:00Z with `round1.json`'s fixed $1.19, and the
  scorer computes only that. Report both and let the operator choose
  (compass-round s4.3); never switch a round's rule quietly.

## TRAPS FROM 2026-10-04 EARLY (GEMINI READS ATTACHMENTS ONLY)

- **Gemini cannot open GitHub or the operator's files.** The operator
  attaches the document to Gemini's chat. Never ask Gemini to "check the
  source at <hash>": give him the verified facts with file and lines
  (an audit trail) and ask which he wants re-checked; Claude re-checks.
  A Cursor prompt still goes to Cursor by its GitHub path (Cursor runs
  in `D:\fxmatrix`).
- **A ruling's "missing fact" may already be measurable:** Gemini's
  GW-4 asked for IC's spread distribution; wine-c's bid/ask dump in
  Downloads answered it in minutes (cap10-reload K17). Look for the
  data before taking a ruling built on a guess about it.

## TRAPS FROM 2026-10-05 EARLY (OPEN MTM, ONE-SIDED BOOKS, JOURNAL NAMES)

- **The first hour after the open marks every book down at once:** IC's
  21Z spreads (crosses' median 9.6-20.5 pips) price longs at the bid and
  shorts at the ask, so both sides of a hedged book lose together (4 Oct:
  B -$244 -> -$333 at 21:10Z, -$227 by 22:10Z). Read MTM after ~22:00Z.
- **A one-sided book defeats the bid / ask fit** (no SELL to pin the
  ask): price it from the longs with the quote currency's USD rate
  (EURGBP: profit = 1000 x GBPUSD x (bid - open) per 0.01 lot).
- **`disconnects.py` dates each journal by its file NAME** (first eight
  characters): copy `YYYYMMDD.log` per box into its own folder; never
  rename or mix boxes.
- **`ea_build` is only in the archive** (`config_events`), not the
  Experts log: prove a build with `archive_counts.py --table
  config_events --instance <id> --limit 2`.

## TRAPS FROM 2026-10-05 DAY (C93 ON FTMO, THE BRIDGE, FTMO'S S, PRE-REGISTRATION)

- **C93 recurs on FTMO until v2.2a is there.** A halt `AMBIGUOUS_ADD_*`
  is usually a duplicate read: grep the VPS Journal for the halt
  millisecond (another instance's cancel completing then) and the halt's
  own cancels (one add of that side = a duplicate read). Then GBPUSD's
  trade lines since the halt (a `deal #` = an exit filled while halted;
  read it before restarting, the 1 Oct I6 case). Repair: F7, read
  `InpTelemetryInstance`, add ` x` to `InpConfigWarning`, OK; check
  `deinit reason=5` and CONFIG, then both entries re-placed.
- **The device bridge can keep the FIRST version of a file name in
  Downloads.** A corrected patch saved under the same name read back as
  the old one twice (C124, memo): re-deliver under a NEW name (`_r2`),
  read it back, and say which file to apply.
- **FTMO's empty-side re-quote is governed by S, not the deadband:**
  cycle-3 presets have S = 2W (or W + 5 / W + 7), so the drift that
  re-quotes is max(D, S - W) = 5-7 pips. Lowering D on FTMO changes
  nothing unless S comes to W + 1 (IC has had S = W + 1 since 2 Oct).
- **A pre-registered window is closed to analysis until it ends:** no
  markout, VR, realised P&L or equity of 6-9 Oct computed before Friday's
  close (criteria s6); status reads for safety continue. And FTMO (A),
  which decides the verdict, gets no input change until then.
- **Lowering the cap halts a deeper side** (I7, not quarantinable):
  with re-roll on, capped sides stay at 8; a reload to a lower cap needs
  every side at or below it first.
- **Check Gemini's factual premises in the data:** GH-3 called FTMO the
  first pass's "only control group"; 65% of its fills were IC's. GH-1's
  mechanism (clustering biases the mean) was wrong, his remedy right.
- **Clock times from the clock tool, every time:** a doc and a patch
  said ~18:30Z for a run at ~17:40Z (corrected before delivery).

## TRAPS FROM 2026-10-05 NIGHT (THE BUILD, RE-ROLL ON, THIN QUOTES)

- **Re-roll ON walks far rolled levels down to the market:** a side
  holding contiguous rolled levels plus far ones from an older move
  re-rolls once per EMPTY level between them (EURUSD L C: a 60-pip gap
  at add 6 = 9 re-rolls in 28 s; EURGBP L B 10). Count the gap's levels
  before calling it a burst; the STOP is two re-rolls of a side in ONE
  call (same `ea_time_ms`; arrivals seconds apart are separate calls).
- **A re-rolled exit near the market fills on the next bounce and
  realises the old layer's whole loss** (EURUSD L C ~-110 pips a layer):
  equity does not move (open MTM becomes balance), the card's realised
  does. Expect it on the first night after re-roll ON.
- **`ROLL_STRANDED` fires at a recompile's re-init on a fully rolled
  side while re-roll is still OFF** (EURGBP L B 23:16:40Z); it clears at
  the first re-roll. pipshed's amber stays because the side is still
  fully rolled at cap (C94's rule predates ADR-165; C131).
- **`[No prices]` / a greyed Close in the hour after 22:00Z on a cross
  (AUDNZD):** thin quotes, not a market close. Wait for Market Watch to
  tick, retry once; never click repeatedly. Not a STOP while the position
  has no orders.
- **IC cards' "Day % of $500" counts carried open MTM and hand closes**
  from the 21Z day-start balance: on IC (no limit, breaker off) it is a
  display, not a loss for the day.
- **Twin and primary tickets on wine-test differ by ONE digit**
  (NZDCAD 1981281322 / 1981281323, AUDNZD 1988248188 / 1988248189):
  match the `|ALT|` comment on every delete and Close By.
- **The checker's `from=` is a time, not a placeholder:** `HH:MM:00`
  compares above every real time and prints nothing; and a Linux command
  pasted into the desktop PowerShell fails with `L=... is not
  recognized`: say which window every command runs in.
- **Read the compile time from the log's `deinit=2` rows:** a time read
  off the screen (22:35:05) was before the copy; the rows (22:38:01)
  and the archive `ea_build` settle it.

## TRAPS FROM 2026-10-06 EARLY (PIPSHED TABLES, GEMINI ON ROUND 2)

- **pipshed's `renderFleetBooks(...)` call string is pinned by two tests**
  (C114 QG5 and C115 QT6 match the exact arguments): a new strip table
  gets its own renderer and its own line in `fetchFleetStrip` (C129's
  `renderFleetGeometry`), not a fourth argument.
- **The geometry table shows what each EA runs, not what a preset says:**
  per-side values come from v2.0 heartbeats; FTMO's `aa6970a` sends only
  the base (long) values, shown for both sides. S and the deadband are
  not in any heartbeat.
- **Gemini on a round's tables reasoned from structure he did not have**
  (GR2-2: "re-roll defers losses", it realises them sooner; GR2-4: the
  width is set by the pair's largest add, not the probe; GR2-6: GC-1 is
  re-estimated every round). Give him the mechanism with lines (re-roll
  s5, the width rule, compass s4.3) in the document, not only the tables.
- **A round reload is presets only: stage, fingerprint, read back.**
  Pull, compare the fleet's `_rN` fingerprint with the sandbox's, `sed`
  the key in (never printed), `SAME_EXCEPT_KEY` x 9, F7 + Load per chart
  with a full read-back (`docs/runbooks/round-reload.md`, as run 6 Oct
  03:18-03:35Z, BAD 0 on 27 charts). Stopping between boxes is safe: the
  round starts at the first 22:00Z after the last reload.
- **Widths alone are not a reload to do separately:** they ship in the
  round's presets with the deadband and the probes; a widths-only reload
  is a second structural change.

## TRAPS FROM 2026-10-06 DAY (READING PIPSHED, WORK BETWEEN MESSAGES)

- **pipshed from a new chat:** WebFetch of `/fleets/<n>` timed out twice
  and the sandbox shell cannot reach pipshed.com (the proxy refuses the
  CONNECT, 403). The desktop app's built-in browser pane opens the URL
  and its JavaScript tool parses the JSON on the page: one call for the
  geometry, one for the fleet cards (live, halted, guard, api, MTM,
  today). Nothing is saved to Downloads; quote `generated_at`.
- **Claude does not work between the operator's messages:** a turn ends
  with the reply. "I'll do X meanwhile" means X is done in that same
  turn or not at all (4-14Z on 6 Oct: nothing was done).
- **x11vnc mode differs by box:** wine-d `-forever`; wine-test and wine-c
  were started `-once` for the round-2 reload (BOOT said `-forever` on
  all three). Check `pgrep -a x11vnc` before relying on a viewer.

## TRAPS FROM 2026-10-06 AFTERNOON (ADR-166 THROUGH THE PIPELINE)

- **"First call X()" in a prompt is ambiguous:** it reads as "make X
  the first statement" or "call X before the first call of Y". Cursor
  placed `Grind_MarketTestReset()` where neither was meant. Name the
  line it goes after (quoted), and say whether it is setup or cleanup.
- **`AssertEqInt` on a `long` or `datetime` truncates** (MetaEditor
  warns, and a test can pass on the low 32 bits). Use
  `AssertTrue(name, x == y)` for every long comparison; say so in the
  prompt.
- **Cursor's branches track `origin/main`:** `git status` on the branch
  says "diverged". Ignore it; never `git pull` a feature branch. Prompts
  check `git rev-parse --short HEAD` against
  `git rev-parse --short origin/<branch>` after `git fetch`.
- **Reconcile the suite count with the F / G totals to the test:** at
  `47facb4` the suite read 2548/2580, one fewer passing than the 31 F
  predicted (2549): RG7c, tagged G, fails at the stubs (the first call
  already rolls). Derive each tag by walking the stub path, and treat ANY
  difference in the count as a finding before reading the FAIL list.
- **pipshed's C80 MQ6 test double keeps only the LAST query's SQL:** a
  new query in `build_critical_list` runs before `CRITICAL_EVENTS_SQL`
  (C131) or MQ6 breaks.

## TRAPS FROM 2026-10-06 EVENING (A NEW INPUT AT A COMPILE; REGENERATED PRESETS)

- **A recompile gives a NEW input its default on every attached chart**
  (inputs are kept by name): after the Wednesday compile every IC chart
  runs `main` with `InpRollGateOpposite=-1` (off) until its own F7 + Load.
  The checker's `gate=-1` after the compile is expected, `gate=0` after
  the Load. An F7 that changes nothing else leaves the gate where it was.
- **A preset regenerated under the same name changes its fingerprint:**
  the `_r2` files gained three inputs (the geometry unchanged), so the
  fingerprints in round-reload / the register (6 Oct) are history; the
  Wednesday runbook's (b `fce104ecbacf`, c `6f8a3d3b1a5f`, d
  `f02163b4e417`) are the ones to match, and the presets are staged again.
- **The gate is invisible on pipshed:** not in the heartbeat; read it in
  the box log (`GRIND_ROLL_GATE opposite_max=`) or the archive
  (`LATTICE_CONFIG`, `ROLL_DEFERRED` with `archive_counts.py --codes`).

## TRAPS FROM 2026-10-07 (READING THE GATE)

- **The cards' "Rolls" count is rolled layers CLOSING** (`ROLL_FILLED`,
  realised P&L), old rolls included: it rises after the gate is on. New
  rolls are `ROLL_ACCEPTED` in the archive; count those against each
  chart's Load time.
- **A book rebuilt from `fill_logs` shows the counter layer still "open"
  at a roll released by its exit:** the layer closes by close-by 0.0-0.5 s
  AFTER the roll (the exit fills, the EA drops the layer, the gate opens,
  the roll goes, then the close-by deal). Check the close time against the
  roll before calling it a leak; the EA's own view is `ROLL_DEFERRED`'s
  `opposite_depth`.
- **A mutation round can be fooled by a stale .pyc:** a mutated file
  restored at the SAME size within the same second keeps the mutated
  bytecode (CPython checks mtime in seconds and size), so later runs test
  the mutant ("caught" or "survived" both wrong). Run every mutation round
  with `PYTHONDONTWRITEBYTECODE=1` and `python -B`, delete `__pycache__`
  after, and confirm the restored file is byte-identical (`cmp`).
- **Under the gate a trend still rolls:** the counter L0 fills on a 1-2.5
  pip bounce (holds), its exit fills only if the fall continues (releases):
  rolls come at counter-scalp moments (P3), as designed.


## TRAPS FROM 2026-10-07 EVENING (THE FTMO SWITCH)

- **`Copy-Item` keeps the SOURCE file's time:** a script copied into
  `MQL5\Scripts` shows the repo file's old mtime, so "is it new?" cannot
  be read from the `.mq5`. Copy, then F7, then check the `.ex5` time
  (`Get-ChildItem "$T\Scripts" -Recurse -Filter 'grind_gv_clean.*'`).
  On 7 Oct the first cleaner run used an OLD `.ex5` (twelve prefixes, no
  `GRIND_VL_` / `GRIND_SNAPSHOT_`); its output gives it away: count the
  `prefix` lines (fourteen now).
- **The cleaner deletes `GRIND_DEINIT_*`, so the archive gets NO
  `DEINIT` row for the old fleet** (the EA archives a deinit at its next
  init). Record the detach from the Experts log (`fxgrind deinit
  reason=1`) instead.
- **PowerShell eats braces:** `git rev-parse HEAD^{tree}` passes `HEAD^`
  and an `-encodedCommand` block; quote it: `git rev-parse "HEAD^{tree}"`.
- **Rollover spreads on the NZD crosses outlast the rest:** at 22:07Z
  (seven minutes after the FTMO day) EURUSD 2, GBPUSD 5, EURGBP 7 points
  but NZDCAD 61 and AUDNZD 88; both under 25 by 22:14:47Z. Read Market
  Watch before attaching tight widths and hold the wide pairs.
- **An expiring FTMO trial keeps its book after the session** (FTMO had
  not flushed 1514731800 by 21:28Z) and opening a new trial forced the
  old account closed: dump history and bid / ask BEFORE opening the new
  one. The trial's 14 days count from its first trade (operator).
- **A stray untracked `C:\fxmatrix\deploy_presets.ps1`** sits at the VPS
  repo root; the real one is `scripts\deploy_presets.ps1`.
- **pipshed's fleets endpoint can time out for Claude's fetch** (twice,
  20:46Z) while `status` answers; a screenshot of the cards is the
  fallback. The cards' "scalps" in the old Arm A/B view is the EA's
  layer-removal count since init, not today's scalps (C136).
- **The VPS Experts log is in UTC; the desktop terminal's clock is ET:**
  checker FROM times on the VPS are UTC.


## TRAPS FROM 2026-10-08 EARLY (PIPSHED C137, THE STRIP'S TIME)

- **Profile on the server, not by guessing:** a local profile with
  production-sized scalp lists blamed the scalp summaries (~1-2 s); the
  Server-Timing header on the live /fleets put them at 68 ms and the
  ejection view at 8,727 of 8,830 ms. Read `Server-Timing` from the pane
  (`fetch(...).headers.get('server-timing')`) before any strip fix.
- **A pipshed push deploys at once:** Railway rebuilds the web services
  AND the archive worker from `main` within ~3 minutes (`/sr` 404 at
  23:55Z, live by 23:58Z). Push outside 20:50-21:00Z (carry pass posts).
  A new table (migration) is applied separately: `railway ssh --service
  archive-worker ... python db_migrate.py`; code that writes to it must
  skip quietly until then (C137's snapshot writer does).
- **Account fields come from one instance per account:** in
  `state_snapshots` (and the heartbeat) `balance` / `equity` are filled
  on GBPUSD for A, B, D and AUDCAD for C, empty elsewhere. Read the
  account's equity from that row.
- **The book's per-position `profit` and the EA's `net_mtm` differ by
  ~$1 on deep books** (inferred: swap / commission in `net_mtm`; not yet
  checked in source). Do not sum `mtm_long + mtm_short` against the FTMO
  limit; use `equity`.
- **The pane's JavaScript tool times out at 45 s:** a loop of six slow
  /fleets fetches never returned. Start the loop, store results on
  `window`, return at once, and read them in a second call.
- **A browser-pane site approval is per host:** `linux.pipshed.com`
  needed its own approval (granted "site" 7 Oct ~23:20Z).

## TRAPS FROM 2026-10-08 NIGHT (READING OUR OWN TRADES)

- **Realised-only ratios flatter a trending week:** open losses are rolls
  in waiting. Count them (R_eff, `grid-as-variance-trade.md` s11) or the
  "edge" hides in the open book (D 1-8 Oct: AUDCHF 1.06 realised, 0.81
  with the book).
- **Per-day ratios filtered to days with a roll are biased low:** days
  of pure scalping drop out. Pool, or use multi-day blocks with the open
  book at each end.
- **scalp_history flags exist only from their migrations:** `ejected`
  from 28 Sep, `rolled` from 1 Oct (the lattice); before that a close's
  kind is unknown. Cycle 3's rows carry `rolled` null (no lattice).
- **The Downloads folder is too large to list** (184 k characters): stage
  a file by its exact name instead of listing the folder.
- **Literature by subagent:** arXiv PDFs are read through text extraction
  (figures and some equations lost); every result a reader derived or
  checked itself is marked so in s9. Verify before building on one.

## TRAPS FROM 2026-10-08 NIGHT, LATE (THE REPLAY HARNESS)

- **Cursor leaves the desktop working copy on ITS branch** (`replay-harness`
  after the harness build, 8 Oct ~03:35Z): a docs `git am` then lands on
  Cursor's branch. Before every `git am`, `git status` must say `On branch
  main`; if not: `git checkout main` (a commit already applied there by
  mistake: `git reset --hard origin/<branch>` on that branch first, then
  check out `main` and apply again).
- **The Experts log on wine-d is `MQL5/logs/` (lower case)**, not `Logs/`.
- **A Cursor build that "passes" its own tests is not read until Claude has
  read the commits:** `a280736` would not have compiled (undeclared arrays)
  and wrote fills where the engine never looks; its RT5 asserted a state
  that a correct harness cannot have.

## TRAPS FROM 2026-10-08 EARLY MORNING (THE HARNESS COMPILE)

- **MQL5 CSV: one `FileReadString` on a `FILE_CSV` handle reads ONE field,
  not a line.** Skipping a header line, counting rows or reading a row means
  reading field by field to the line end. Cursor's readers (fix 2, D3) and
  tests (fix 3, E4, E10) have carried this.
- **`FileIsLineEnding` is set BY a read** and stays set until the next one:
  test it after reading, never before (a `while(!FileIsLineEnding)` loop
  reads nothing after line 1; fix 3, E1). Read in a do-while.
- **Compile EVERY `.mq5` Cursor touches:** the replay runner
  (`fxgrind_replay.mq5`) went uncompiled from the base build to fix 2 and
  could not have compiled at `8a92e22` (it called a tests-file function).
- **`desktop_sync.ps1` puts only `*_tests.mq5` in `MQL5\Scripts\`;** every
  other `.mq5` (the replay runner included) goes to `MQL5\Experts\`. Open it
  there for F7. The replay terminal's copy step (`D:\mt5-replay`) is Cursor's
  own (base s5), not this script.
- **A test that indexes rows "from the end" breaks when a fill closes by
  close-by on the same tick:** the OUT_BY pair is appended after the IN rows
  (RT18, fix 3, E9). Index from the start with an exact count.

## TRAPS FROM 2026-10-08 DAY (THE BOXES FROM POWERSHELL)

- **PowerShell drops the INNER double quotes of an `ssh box '...'` command**
  (Windows PowerShell 5.1 passing to a native exe): `"Program Files/..."`
  reaches the box as two words, `"TICKS|"` as a pipe, `"$f"` as a split
  path. Write remote commands with NO inner double quotes: glob the spaces
  (`Program*Files/MetaTrader*5`), `cd` through the glob and use bare file
  names, `grep -a TICKS` instead of `"TICKS|"`, `tr -d \\000`.
- **`e3b0c44298fc1c14` is the sha256 of EMPTY input:** a hash that starts
  so means the file was never read.
- **"Connection refused by the computer" in the VNC viewer is the DESKTOP:**
  no tunnel is listening on the local port (x11vnc on wine-c was up,
  `-forever`). Open the tunnel in its own window and leave it:
  `ssh -o ServerAliveInterval=15 -L 5911:127.0.0.1:5911 box2` (127.0.0.1:
  x11vnc runs `-noipv6`).
- **Cursor left the desktop on `replay-harness` again** after fix 3: check
  `git status -sb` before every `git am` (traps 8 Oct night late).

## TRAPS FROM 2026-10-08 AFTERNOON (THE REPLAY TERMINAL)

- **A portable copy of the FTMO-branded MT5 logs in to IC:** search the
  server name `ICMarketsSC-Demo` in the Open an Account wizard (it lists
  as Raw Trading Ltd); the brand only sets the default server list.
- **"Investor" = the same login with the read-only password.** The IC
  portal shows only the master; set the read-only one from a terminal
  logged in with the master (Tools -> Options -> Server -> Change ->
  investor). Check the journal: "trading has been disabled - investor
  mode" (the master prints "trading has been enabled"). Delete a saved
  master login (Navigator -> Accounts) before logging in read-only.
- **A `[StartUp]` .ini must be UTF-16 LE:** a UTF-8 file is refused
  ("cannot load config ... at start").
- **`SYMBOL_TRADE_TICK_VALUE` reads 0 for ~2 s after a scripted terminal
  start:** anything that multiplies by it (carry, profit, swap) is 0, and
  a test whose expected value uses the same live 0 passes vacuously.
  Wait for it (fix 5 H4) and assert hand-derived values.
- **A replay harness test can be right in name and wrong in timing:**
  RT15 asserted "after the first tick" after all ticks; it passed only
  while every swap was 0.

## TRAPS FROM 2026-10-08 EVENING (THE REPLAY'S INPUT FILES)

- **The archive's `ea_time_ms` is UTC epoch ms; `deal_time_broker` /
  `deal_time_broker_msc` are SERVER time (GMT+3).** The harness's run,
  seed and real-deal files want server ms: add 10,800,000 to any
  `ea_time_ms`. Check a builder on the real archive before trusting its
  synthetic tests (the first segment builder passed its own tests with
  the wrong premise).
- **`--export-archive` files start with a UTF-8 BOM:** `json.loads` on
  line 1 fails; open with `encoding='utf-8-sig'`. Files written FOR the
  harness carry no BOM.
- **No `pytest` in the sandbox:** the tests run with `python -B -m
  unittest`. A mutation loop that calls a missing runner "catches" every
  mutant; check the unmutated run passes inside the loop.
- **Plan s2's table counts deals to the 01:10Z export (8 Oct 01:10Z =
  1791421800000 UTC ms = 1791432600000 SERVER ms; corrected s73):** a cut-off one hour out changes only the last
  segment's count, which looks like a builder error.

## TRAPS FROM 2026-10-08 NIGHT (THE REPLAY'S INPUTS; ROUND 2 SCORED)

- **"To the cent" must be measured with NO tolerance.** s72's swap model
  "622 of 622 to the cent" held only within half a cent: exactly, it
  matched 600 of 626. A missing CARRY_SNAPSHOT night (Mon 5 Oct) left
  "the latest snapshot before" on Saturday's rate, and the broker rounds
  EACH NIGHT's charge to the cent. Compare `==` on rounded values.
- **A ROLL_ACCEPTED row's own `level` is the LOG level ("INFO");** the
  roll level is `detail.level` (and `detail.ticket`).
- **Tick `flags` change after the fact; times and prices do not.** w1
  (dumped near-live) and w2 (the same hours dumped ~17 h later) agree on
  time, bid and ask for all 405,245 ticks; the last ~12,800 of w1 lack
  bit 128 that w2 carries (6 -> 134, 2 -> 130). Compare dumps on the
  first three columns; the harness reads only those.
- **The K19 probe answers only "at or after InpFrom":** w1 started at
  06:30 because the probe was asked from 06:30. IC serves EURUSD from 1
  Oct 04:00:00.097 server (probe 8 Oct 21:30Z). A seed AT CAP needs ticks
  back to its newest open (C seg 11: 06:01:24): run `cap_warnings`.
- **PowerShell: a destination ending `\"` escapes the quote** (`scp ...
  "$HOME\Downloads\"` fails "No such file"): name the file in full.
- **`python -I` hides the script's own folder:** a research driver that
  imports its sibling modules (build_inputs.py) must run with `-B` only;
  `-I` is for scripts reading untrusted downloads with no local imports.
- **The scorer's "provisional" flag fires on the evening lull:** no fill
  on any instance from 20:08Z to the 22:35Z export on 8 Oct (7 Oct: 0 at
  19Z, 5 at 20Z, 0 at 21Z). Check the hourly fill counts and the carry
  pass before calling data missing.
- **PowerShell: quote `"HEAD^{tree}"`.** Unquoted, `{tree}` is a script
  block: git receives `HEAD^` plus `-encodedCommand ...` and prints the
  PARENT COMMIT's hash, which looks like a wrong tree (9 Oct ~03:00Z).

## TRAPS FROM 2026-10-09 (THE REPLAY'S FIRST RUNS)

- **Copy the replay code into `D:\mt5-replay` BEFORE compiling.** Its
  MetaEditor builds `MQL5\Scripts\fxmatrix\` there, not `D:\fxmatrix\ea`;
  fix 1's prompt put the copy (R0) after "compiled", so the first compile
  would have rebuilt the old code. Check with `Select-String` for a string
  new in the commit. Fix 2 on: R0 copies, then the operator compiles.
- **Close the replay terminal before Cursor's runs;** each run starts it
  with its own `/config` and it shuts itself down. Cursor's run block
  begins `taskkill /IM terminal64.exe /F` (allowlisted "Always Run" 9 Oct):
  it closes EVERY MT5 on the desktop. The desktop terminal never trades
  (operator), but anything open there is closed without warning. To be
  replaced by a replay-only script (`tools/replay_run.ps1`, fix 3).
- **An absent archive marker can be a reporter-only marker.**
  `BREAKER_GATE_ON` is written only by an account's reporter instance;
  "none on EURUSD" (plan s4.2 check 2) read as "the gate never bound" and it
  had. Read the EA's emit path before concluding from an absence.
- **send_logs keep 14 days** (archive_worker retention): 1 Oct's orders go
  on 15 Oct. `archive_counts.py --export-sends --instance X | Set-Content
  -Encoding utf8 <file>` copies one instance (pipshed `6ea487e`).
- **The EA's carry ledger, VLs and carry day live in terminal Global
  Variables** (`GRIND_CARRY_ACCRUED_`, `_SHIFT_`, `GRIND_VL_`,
  `GRIND_CARRY_DAY_`) and survive a restart; the harness deletes them per
  segment. Anything the EA keeps in a GV is state a replay must seed.
- **The real EA keeps its resting orders across an init** (no send after
  23 of 29 inits): a replay that seeds positions only re-places exits at
  the formula, without the carry shifts the real ones carry.
- **Compare a replay on the ORDER price, not the deal price:** IC fills
  carry price improvement (D: 237 of 370 deals, up to 2.3 pips).
- **In the replay's deals output the close-by leg of an exit position also
  reads `role` EXT** (entry_type 3): count exit FILLS with entry_type 0.
- **The Friday carry pass fails 3-4 per instance every week** (25 Sep, 2
  Oct, 9 Oct: `failed`, nothing incomplete, mult_tomorrow 0): a pattern, not
  news. Retcodes not yet read.

## TRAPS FROM 2026-10-09 EVENING (FIX 3)

- **A replay exit deletes its layer's carry GVs** (`grind_engine.mqh`
  2925-2940: SHIFT, ACCRUED, eject offset, VL on close). A sync re-seed
  restores only what the true book holds: any per-position state the real
  EA keeps must be in the true book too (fix 3 A2).
- **An allowlisted script must check its arguments before it builds a path
  or a command line** (`-Label ..\x`, a quote, `&`); the fixed paths alone
  do not hold the limits (fix 3 P1 step 0).
- **Claude's sandbox after the operator's `git am`:** the pushed commits
  carry new hashes, so the sandbox's `main` "diverges". `git fetch`, `git
  reset --hard origin/main` before every `format-patch`. To check a patch,
  clone and reset to the REAL base hash: a clone of the sandbox repo has
  the sandbox as `origin`, so its `origin/main` already holds the patch and
  `git am` "fails" (9 Oct ~21:35Z).
- **Gemini found a real gap with the wrong mechanism (GF3-4):** "the pass
  adds to 0" where the pass recomputes from swap. Keep the finding, check
  the mechanism in source.


## TRAPS FROM 2026-10-09 NIGHT (FIX 3 THROUGH; THE RUNS)

- **A count with no committed check is not a fact.** "15 (B 9, C 4, D 2)"
  and "174 of 174" came from uncommitted scratch work and could not be
  reproduced the same night. Commit the check (`check_accrued.py`,
  `classify_misses.py`) with its rule written in its header, or do not cite
  the number.
- **Anything added to a prompt after Gemini's reading must go back to him**
  (A2, RT45 and P1 step 0 were added in s7 and he had not seen them). He
  reads only the attached file: a commit hash means nothing to him.
- **"Exactly as your previous runs did" is not a spec:** the fix-2 run files
  on `D:\mt5-replay` disagreed (`Expert=` for B / C, `Script=` for D and the
  suite). Name every key and byte. The earlier presets are LF with a stray
  CRLF at the end, not CRLF (Claude's s8 description was wrong; MT5 reads
  both).
- **The replay terminal's log is in the desktop's LOCAL time** (EDT), named
  by the local date.
- **An allowlist line is a prefix, not a command:** the script needs
  `-Mode`; approve the first real call to allowlist it.
- **PowerShell `-match '^...$'` is case-insensitive and `$` accepts one
  trailing newline** (.NET); `\z` would not. Worked through for
  `replay_run.ps1`: the worst case is a throw. Use `-cmatch` and `\z` in the
  next script.
- **Read every Cursor script line by line against its spec:** 4e624fc
  stopped any terminal under `D:\mt5-replay*` (prefix without `\`) and
  would have dropped a run's lines after local midnight.
- **The harness's close-by is instant; the broker's takes ~1 s:** the
  replay places the next L0 at another mid. A miss whose replay twin sits a
  few points away 1-10 s earlier is placement timing, not an L0 rule.

## TRAPS FROM 2026-10-10 EARLY (FIXES 4 AND 5; T1 PASSES)

- **Before a spec deletes a behaviour, grep the tests for any that assert
  it.** Fix 5's S2 removed the sync VL overwrite; RT8b asserted it, R1 went
  388 / 389, and the amendment had to go back through Gemini (GF5b-1).
- **Two prices that print the same can differ as doubles:** order prices
  are NormalizeDouble'd at the send, file prices were StringToDouble'd; 14
  price values never filled on an exact touch. Put every file price on the
  symbol grid (`Rpl_FilePrice`).
- **A sync reset must not write state the replay owns:** setting the true
  VL on held layers marked them rolled 0.6 s early (ROLL rows carry the
  EA's clock); the replay then never rolled them.
- **The order of steps inside one tick matters:** `Rpl_ScanNewOrders` runs
  before `Rpl_ProcessCloseByDone`, so an order placed after a close-by
  gets its placement time one tick late and cannot fill on the next tick.
- **Timing misses come in three kinds, read from send_logs:** the broker's
  close-by (~1 s; the harness's is instant), the EA's serial sends (a
  re-centre goes out behind other sends), and the broker's fill after a
  touch (up to ~2 s in bursts). A placement difference carries forward
  (D 1 Oct: only the replay crossed the 14-pip stranded mark).
- **T2 can fail with every side's sums passing:** the UNPRICED share counts
  whole segments, and a 5- or 7-deal segment fails T1's mark on one miss.

## TRAPS FROM 2026-10-10 EARLY, NEW CHAT (BEFORE THE HOLDOUT)

- **Read the plan's conditions before planning its next step.** s8 puts
  the holdout after a PASS (T2 included). The handover planned the
  holdout after T2 failed, and nobody had ruled it. A step the plan does
  not allow is a question for Gemini, not a task.
- **A fix can be real and still not move the verdict.** The CB_DONE
  defect touches at most one replay-only deal in each of the three
  segments it reaches, and each sits more than one above its allowance.
  Count what a fix can change before selling it as the route to a pass.
- **A handover's timestamp can run ahead of the clock.** s77i was stamped
  ~01:45Z; the new chat's first message came at 01:34Z. Use the operator's
  message times.
- **Unseen data is spent the first time anyone looks.** The 9-13 Oct
  EURUSD data are the new pre-registration's holdout. Export and hash
  them on Tue 13; no replay, `compare.py` or T0 on them until the new plan
  is ruled.
- **A reviewer's "sub-second ticks" is a session-hours premise.** In the
  carry window (23:50-23:59 server) EURUSD ticks are ~1 a minute at
  worst (w2: 61-62 s gaps every Mon-Thu night): anything on the tick path
  there can run a minute late. Check timing claims against the tick file
  for the hour in question.
- **Cursor may compile from the command line on its own** (fix 6 R0,
  10 Oct: `MetaEditor64.exe` after it found a stale `.ex5`). The prompt's
  "do not compile" is not enough: say "if the `.ex5` is stale, STOP and ask
  the operator to compile". A suite from a CLI build does not count.
- **A reset that runs per segment must not clear what lives for the whole
  run** (fix 6 C8: `Rpl_ResetAll` cleared the timing file's handle, opened
  once per run). When a spec lists what a reset keeps, name the output
  handles too.

## TRAPS FROM 2026-10-10 MIDDAY (PLAN 2'S RESULT AND ITS CLASSIFICATION)

- **A replay's "server now" in a timer step is the timer moment, not the
  newest tick.** Live's `OnTimer` reads `TimeTradeServer()`, which runs on
  with no ticks (weekends, quiet nights); the harness's TIMER stage gave
  the carry code the newest tick's time, so the 120 s freshness check
  could never fail and a Saturday carry pass ran that live never did (plan
  2 s15, D 24). Check any clock a stage seeds against what live reads, and
  check weekend behaviour against the archive's `CARRY_*` rows.
- **Compare like with like.** With `timing = 1` the replay's deal row
  carries R1's MARKET price; matching it against the real ORDER price
  mixed two prices (first read: T1 73-78%). `compare.py` now reads the
  order price from the order log keyed by segment AND ticket (tickets
  repeat across segments).
- **Tests that pass by accident prove nothing.** `compare.py`'s first
  tests passed because the rows happened to be in order; make them
  order-adversarial, then run the mutants.
- **Every UNPRICED segment fails by one or two deals.** The per-segment bar
  is the fleet's 95%, so a segment under 20 deals may miss none, and which
  segments fall under it is close to chance. Before calling a fix "the
  route to a pass", recount the UNPRICED share without the segments it
  can change (s15: still 23.7% C, 34.6% D).
- **The run outputs are in git, `timing.csv` is not.** `replay-harness`
  `e4fda38` holds `research/replay/runs/eurusd_*_868bcc3*/` (orders,
  deals, events, book, summary); each run's `timing.csv` stays on the
  desktop (GitHub's 100 MB limit). A question about a handler's stages
  needs it staged from there.
- **Never assume the desktop is on `main`.** Cursor leaves it on
  `replay-harness`; every patch step starts with `git checkout main`.

## TRAPS FROM 2026-10-10 AFTERNOON (NEW CHAT; FIX 7)

- **A timed run's event rows carry the time they were WRITTEN, not emitted**
  (to `868bcc3`): `Rpl_DrainOutputs(t)` runs once per tick, so a DEAL,
  CLOSEBY_DONE, TIMER or QUEUED_ONTICK handler's rows read the next tick's
  time, and handlers after a segment's last tick are written in the next
  segment (or never). Read deal and order times from the deals and orders
  files; read event times as "written at" until fix 7 F2.
- **A harness divergence that commits state persists.** A successful carry
  shift writes `GRIND_CARRY_ACCRUED_<position>`, which every later exit
  placement for that position adds: one wrong Saturday pass moved Monday's
  re-placed exits (B 4, C 14, D 24). Trace a miss back through the GVs a
  handler commits, not only through the orders it sends.
- **Name layers from the committed log, not from memory.** s15 named the
  wrong shifted layers (S L4 / L3 / L2; the log says L L0, L L3, S L1, S
  L4).
- **An incomplete carry pass does not reset the snapshot flag**: after a
  weekend there is no snapshot until a complete pass (live, Mon 5 Oct:
  SUMMARY only). Derive expected events from the code path, then check them
  against the archive.
- **Live's carry MODIFYs carry no side, layer or role in send_logs**:
  match them by server night and requested price.
- **A test of a weekend step with no later tick sees no events** on the
  timed path at `868bcc3`: nothing drains them. Design tests so each
  assertion has a state in which it fails (fix 7 s3's table).

## TRAPS FROM 2026-10-10 EVENING (FIX 7 RUNS)

- **The suite rewrites `replay\swaps.csv`** for its own tests: R2 (inputs)
  must run AFTER the last suite run and before R4, or R4's hash check
  refuses the file.
- **Cursor may run R1 before the operator's compile** and may "fix" a
  failing test instead of stopping. Name the stop in the operator's line
  too: "on any failure STOP and report, do not fix".
- **Events files write fill_log rows with an empty code column**: the type
  is in the json (`"type":"fill_log"`). Specify tests from a real output
  row, not from memory.
- **A handler can start after its event** (the EA busy): compare a handler's
  rows with its timing row's start, never with the event time.
- **A small placement difference can cross a threshold the rule tests**
  (D 21: 0.3 pip took the replay past the 14-pip stranded mark; live
  stayed at 14.00). Before calling a re-centre "a rule miss", compute the
  rule's input for live's price and the replay's on the ticks.

Line count: 2432
