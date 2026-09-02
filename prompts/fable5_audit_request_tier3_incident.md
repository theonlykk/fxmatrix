# FXMatrix V3 — Full Codebase Audit Request
## For: Claude Fable 5, running via Claude Code with direct repository access
## Context: Post-incident review, EA currently detached, Algo Trading OFF, demo account flat
## Requested by: Khalid (Lead Quant), prepared by Claude (Lead Engineer)

---

## Read-only mandate — this applies even though you have write access

You are being run via Claude Code, which means you have real file-system
and git tool access to this repository — not just the ability to read
what's pasted in front of you. That access is being granted **so you can
investigate thoroughly, not so you can fix anything.**

**Do not, under any circumstances, as part of this task:**

- Edit, create, delete, or rename any file in this repository, including
  test files, ADR docs, or anything outside `ea/`.
- Run `git add`, `git commit`, `git push`, `git checkout -b`, or any
  other git command that changes repository state. Read-only git
  commands (`git log`, `git blame`, `git diff`, `git show`) are
  encouraged and useful — see below.
- Compile the EA, run `deploy.ps1`, or touch anything that would affect
  the live VPS, the FTMO account, Redis, or Pipshed.
- Attempt to reproduce, simulate, or test-fire any of the trading logic
  live. Static analysis only.

If you want to save your findings as a working file for your own use,
place it **outside this repository** (e.g. a temp directory), never
inside `ea/`, `docs/`, or anywhere git-tracked. Your actual deliverable
is the written report in your final response, not a file.

**One capability worth actually using, since you now have it: git
history.** You can check exactly when `CheckForOrphans()`'s "F4 fix"
(the three-magic-offset comment quoted in Part 2 below) was committed
relative to when the Tier 3 sweep code was last touched before today's
incident. That would settle, with real evidence rather than inference,
whether the Tier 3 bug is "a lesson that was learned and then forgotten
to propagate" or "a lesson that postdates when Tier 3 was last written
and simply never had a reason to be revisited." Worth including in Part
A if `git log`/`git blame` on the relevant files gives you a clear
answer.

---

## Purpose

This is a review-only audit. **Do not write or propose fixes.** If you find
issues, describe them precisely (file, function, line if identifiable,
mechanism, and why it's a problem) so they can go through the project's
normal review pipeline (adversarial teardown → engineering blueprint →
architectural ruling → implementation) before any code changes.

Two things are being asked of you:

1. **Explain, in your own independent analysis, what caused today's
   incident** (full account below) — not to check our work against a
   script, but because an independent read of the same evidence is more
   likely to catch something we missed than us re-reading our own
   conclusion.
2. **Audit the wider codebase for the same *class* of bug** — not just
   the specific function that failed today, but anywhere else this
   pattern might exist, since today's incident revealed the pattern is
   already known to have occurred once before (in a different function)
   and gone unpropagated to the one that broke.

---

## 1. System Overview

FXMatrix V3 is a live MQL5 algorithmic market-making EA trading a
EUR/GBP/USD triangular triad on an FTMO demo account (hedge account
type — allows simultaneous long and short positions per symbol).

Three independent EA instances run simultaneously, segregated entirely
by magic number, each with zero runtime awareness of the other two:

| Instance | Bias | Magic base |
|----------|------|------------|
| MM | BIAS_BOTH | 20260000 |
| SNIPER_LONG | BIAS_LONG_ONLY | 20260100 |
| SNIPER_SHORT | BIAS_SHORT_ONLY | 20260200 |

Each instance uses three magic *offsets* for different order/position
types on its own base:

| Offset | Meaning |
|--------|---------|
| `EA_MAGIC` | Layer 0 (flat-quote) entry positions |
| `EA_MAGIC + 1` | Add-next — deeper grid-expansion layers |
| `EA_MAGIC + 2` | Exit limits / hedge-closing positions |

Each instance maintains an in-memory inventory of "layers" — one entry
per open position, tracked in three arrays (`g_inventory_0/1/2`, one
per triad symbol slot), each element a `Layer` struct holding
`position_ticket`, `direction`, `entry_price`, `lot_size`,
`exit_price_fixed`, `exit_tickets[]`, and other fields. This inventory
is the EA's own internal belief about what it holds; it is persisted to
JSON on disk and reloaded on reattach.

The EA also has a tiered risk-control system (`CheckCircuitBreakers()`,
called every `OnTick()`):

- **Tier 2** — 3% daily drawdown: push a warning, no market action.
- **Tier 3** — 4% daily drawdown, plus a legacy absolute-equity-floor
  check — full institutional sweep: close everything, cancel
  everything, detach the EA (`ExpertRemove()`).

Separately, `CheckForOrphans()` runs once, at `OnInit()` only: it scans
all broker positions matching this instance's three magic offsets and
halts (soft — no `ExpertRemove()`) if any broker position isn't
represented in inventory.

---

## 2. Today's Incident — Full Timeline and Root Cause

**2026-07-02, all times broker server time (UTC+3).**

A genuine, legitimate market move (GBPUSD and EURUSD both spiking hard
against the book's net short positions) pushed equity down through
Tier 2 at 08:12 and 08:36 (correctly logged, no action taken beyond the
warning — working as designed). The move continued, and Tier 3 fired
correctly at 12:39–12:40 across all three instances:

```
CRITICAL [Phase3A] Hard kill switch fired. equity=9712.69
daily_start=10117.59 tier3_floor=9712.89 instance=SNIPER_SHORT
```

(`tier3_floor` = `daily_start_balance × (1 − 0.04)` — exactly the 4%
threshold, confirmed correct.)

**What should have happened:** every open position across all three
magic offsets closes, every pending order cancels, inventory clears to
reflect the now-empty book, EA detaches cleanly.

**What actually happened:** orders were correctly cancelled. Positions
were not. MM's own `SaveInventoryState` log went from **5/7/3 layers
(EURUSD/GBPUSD/EURGBP) to 0/0/0 in under two seconds** — but the human
operator, watching the MT5 terminal directly, found **11 real
positions still open on the broker**, completely unmanaged (no EA
attached to any chart, Algo Trading still enabled but nothing watching
these positions). This was caught only by chance — an operator happened
to be looking at the terminal at that moment.

### Confirmed root causes (via direct code trace, not inference)

**Cause 1 — magic-number filter scope gap.** The function responsible
for closing positions on Tier 3 (`CloseAllPositions()`, prior to
today's fix) filtered on `POSITION_MAGIC == EA_MAGIC` — **exact match
only**. It never considered `EA_MAGIC + 1` or `EA_MAGIC + 2`. Since MM
alone was carrying 15 tracked layers across three symbols, and only the
Layer-0 position per symbol could possibly match this exact-equality
filter, the large majority of open positions were **never even
attempted** for closure — not a failed close, a close that was never
tried.

**Cause 2 — unconditional state clearing.** Immediately after the
close/cancel attempts (regardless of whether they were even attempted,
per Cause 1, or whether they succeeded), the code ran
`ArrayResize(g_inventory_0/1/2, 0)` and persisted that empty state to
disk — with **no verification step** of any kind confirming the
broker's position count had actually reached zero. Success and silent
failure were logged identically (nothing).

**The precedent that should have prevented this:** a different function
in the same codebase, `CheckForOrphans()`, already carries this exact
lesson in its own source comment:

```
// F4 fix: check all EA magic variants.
// EA_MAGIC   = flat-quote entry positions
// EA_MAGIC+1 = deep add-next layer positions
// EA_MAGIC+2 = hedge/exit positions
// All three must be inspected — blind spots in +1/+2 leave
// unmanaged deep-grid and hedge positions after blackout/reboot.
```

This fix was made once, in one function, and never propagated to the
Tier 3 emergency-close path — which had the *identical* three-magic
structure and the *identical* blind spot, and which is arguably the
single most safety-critical code path in the entire system (it's the
one meant to save the account when everything else has already gone
wrong).

**A second, independently confirmed instance of the same duplication
problem:** a "legacy absolute equity floor" check (a second Tier 3-style
trigger, separate from the 4% daily drawdown check) was a byte-for-byte
structural copy of the same buggy sweep logic — meaning the bug existed
**twice**, in two separately-triggered code paths, from copy-paste
rather than shared code.

### The fix already implemented (ADR-074, committed, not yet deployed to VPS at time of writing)

Both trigger paths were consolidated into one shared function,
`ExecuteEmergencySystemSweep()`:

1. Scans the broker directly (not inventory) for all positions
   matching the instance's triad symbols and **all three magic
   offsets** — same pattern as `CheckForOrphans()`.
2. Sends a market close (`TRADE_ACTION_DEAL`) for every match found,
   tracking every attempted ticket.
3. Cancels pending orders (unchanged from prior logic).
4. Runs a **batched, bounded verification poll** — up to 5 rounds of a
   50ms sleep, re-checking *all* outstanding tickets together each
   round (not serially per-ticket, to keep worst-case latency
   independent of position count), breaking early once everything
   confirms closed.
5. Any ticket still open after the poll is pushed to a critical-alert
   buffer (visible on an external dashboard) rather than logged
   silently.
6. **Inventory is purged selectively** — only layers whose
   `position_ticket` is confirmed closed are removed. Anything genuinely
   stranded stays in the JSON state file, so that on the next reattach
   the EA's existing state-reload and reconciliation logic naturally
   resumes managing it, rather than it becoming an orphan.

This has been code-reviewed, unit-tested (Python mirror of the poll
logic), and compiles clean locally. **It has not yet been exercised
against a real drawdown event** — the nature of this code path means it
can't be meaningfully soak-tested by passive observation, only by
deliberately triggering it under controlled conditions, which has not
yet happened.

---

## 3. What You're Being Asked To Do

### Part A — Independent incident analysis

Read the account above and the actual source (Part 4 below lists the
files). Confirm, correct, or extend the root-cause analysis. Do not
simply agree with it — if you see it differently, say so and explain
why. Specifically worth checking: is there anything about *why* this
bug existed for as long as it did without being caught (e.g., in
testing, in the tester logs, in other prior sessions) that the above
account doesn't capture?

### Part B — Broad codebase audit for the same bug class

The core pattern that caused today's incident is:

> **State (in-memory struct, or a persisted file) is mutated to reflect
> an assumed outcome, without verifying that outcome against the
> broker's actual reality first — and/or an operation scans/filters by
> a narrower criterion (e.g. one magic number) than the full set of
> things it's actually supposed to cover.**

Search the entire codebase for other instances of this pattern,
independent of whether they involve Tier 3 or circuit breakers at all.
Things worth specifically checking:

- **Every other place `ArrayResize(..., 0)` or similar wholesale array
  clearing occurs** — is it always preceded by verification, or are
  there other unconditional clears?
- **Every other magic-number filter in the codebase** — does it
  consistently check all three offsets (`EA_MAGIC`, `+1`, `+2`) where
  relevant, or are there other places, like the original
  `CloseAllPositions()`, that only check one?
- **`ClosePodPositions()` (Tier 1's own close mechanism)** — this
  closes positions by iterating inventory `position_ticket` values
  rather than scanning the broker by magic number, which structurally
  avoids Cause 1's specific bug — but confirm this independently rather
  than trusting that reasoning, and check whether it has any
  verification-before-state-mutation gap analogous to Cause 2.
- **Any other emergency/safety/circuit-breaker-style code path** not
  covered above — does anything else in the system detach, halt, or
  clear state based on an assumption rather than a confirmed broker
  read?
- **Partial-fill and partial-close handling generally** — the struct
  fields `lot_size`, `remaining_entry_volume`, and
  `remaining_exit_volume` all assume they track the broker's true
  current volume. Are there any code paths where the broker's actual
  position volume could change (partial closes, partial fills) without
  a corresponding update to these fields?
- **Anything else that looks structurally similar to today's bug, even
  if it doesn't fit the categories above.**

For each finding, state: the file/function, the mechanism, why it's
risky (ideally with a concrete scenario, similar in specificity to how
today's incident is described above), and a severity assessment
(critical / high / moderate / low) relative to today's incident as the
calibration point.

---

## 4. Where To Start — Not The Full Extent Of What You Can Look At

You have full read access to the repository. The list below is a
starting point to orient you quickly, not a boundary — use `grep`/
codebase search across the *entire* repo for the patterns described in
Part 3B (e.g. every `ArrayResize(..., 0)` call, every `POSITION_MAGIC`
comparison, every `PositionSelectByTicket` call) rather than limiting
yourself to these files. If your search turns up something relevant in
a file not listed here, follow it.

First, a sanity check worth doing before anything else: confirm you're
actually looking at the fxmatrix repo (presence of `ea/FXMatrix.mq5`
and `docs/architecture/ADR-074.md` is a quick check) — this project has
a sibling repo (`pipshed`, a Python/Flask telemetry dashboard) that has
been mixed up with this one more than once this session by pasting a
prompt into the wrong working directory. Not relevant to this audit's
content, just worth ruling out before spending time on the wrong repo.

Primary (most likely to matter):

- `ea/FXMatrix.mq5` — main EA loop, `OnTick`, `OnInit`, `OnTimer`,
  `CheckCircuitBreakers`, `ExecuteEmergencySystemSweep`,
  `ClosePodPositions`, `CancelAllPendingEntries`, `ProcessCloseByQueue`
- `ea/ExecutionEngine.mqh` — order placement, fill handling
  (`HandleEntryFill`, `HandleExitFill`), `PlaceEntryLimit`,
  `PlaceNextEntryLimit`, `PlaceExitLimit`, `ComputeLDAKLotSize`,
  `ComputeNextLayerPrice`
- `ea/StateEngine.mqh` — state persistence, `CheckForOrphans`,
  `CheckDirectionConsistency`, `PurgeClosedLayers`,
  `ExecuteEmergencySystemSweep`, `LoadInventoryState`,
  `SaveInventoryState`
- `ea/LayerStruct.mqh` — the `Layer` struct itself and its stated
  immutability contract
- `ea/Globals.mqh` — all global state, including
  `g_inventory_0/1/2[]`, `g_critical_alerts[]`, `g_closeby_queue[]`

Secondary (review if time allows, lower prior suspicion):

- `ea/MathEngine.mqh` — signal computation, price inversion, LDAK
  correlation math
- `ea/TelemetryEngine.mqh` — telemetry payload construction (read-only
  consumer of state, lower risk of causing this class of bug, but worth
  a pass)
- `ea/CarryEngine.mqh` — carry/rollover recalculation

Also available, useful for cross-referencing rather than as primary
audit targets:

- `docs/architecture/ADR-*.md` — the project's own decision record.
  Read directly rather than relying solely on the summaries in this
  document — cross-check anything in Part 2 against the actual ADR-074
  text, and skim earlier ADRs if you want fuller history on any
  mechanism you're inspecting.
- `temp/run_tests_0_41.py` — the existing pure-Python unit test suite
  (currently 279/279 passing per the last session). You may run this
  read-only (`python temp/run_tests_0_41.py`) to confirm the stated
  baseline if useful context, but do not modify it.

---

## 5. What NOT To Do

- Do not write, suggest, or output replacement code. Findings only.
- Do not modify, create, or delete any file — see the read-only mandate
  at the top of this document. This applies regardless of what tool
  access Claude Code makes available to you.
- Do not run any git command that mutates repository state (`add`,
  `commit`, `push`, branch creation, etc.). `git log`/`blame`/`diff`/
  `show` are fine and encouraged.
- Do not compile, deploy, or attempt to test-fire any trading logic.
  Static analysis and read-only test runs only.
- Do not assume anything about MT5/MQL5 broker behavior you can't
  verify from the actual source or its comments — if something depends
  on broker behavior the code doesn't make explicit, say so as an open
  question rather than asserting an answer.
- Do not limit yourself to confirming the known incident — the primary
  value of this audit is finding what we *haven't* already found.

---

## 6. Output Format Requested

1. Part A: your independent read of the incident — agreement,
   correction, or extension of the account above.
2. Part B: a findings list, each with file/function, mechanism,
   concrete risk scenario, and severity.
3. A closing summary: overall assessment of whether this codebase has
   other landmines of this specific class, and your honest read of
   whether it's safe to resume live trading once ADR-074 is deployed
   and verified, or whether something else should block that first.
