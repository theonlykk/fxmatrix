# HANDOVER TO NEW CHAT -- FXMATRIX, 2026-09-11

You are picking up an active algorithmic FX market-making project. Twelve EA
instances are trading live on a demo account right now. Read this whole document
before doing anything.

**This document is also the template.** Section 12 notes what to carry forward
when you write the next one.

---

## 1. FIRST ACTIONS

**Ask the operator (Khalid) for `ARCHITECT.md`.** It is the governing document
for all engineering decisions and it is NOT in the repo -- it lives locally on
his desktop. Request it before proposing anything.

**Parts of it are likely stale.** It predates a great deal of this month's work.
Read it, then say plainly which sections no longer match reality rather than
following them blindly. Proposing an update is welcome.

**Then read `handoffs/HANDOFF_2026-09-10.md`** in the fxmatrix repo -- 384 lines
covering the current fleet, the open defects, the deployment traps and the
design decisions already ratified. `handoffs/HANDOFF_2026-09-07.md` has deeper
history.

**You have full repo access. Use it.** Clone and read the actual source rather
than reasoning from description. Several errors in the last session came from
assuming what code did instead of opening it.

    theonlykk/fxmatrix   the EA, the simulator, the sweep harness, ADRs
    theonlykk/pipshed    the dashboard and telemetry ingestion

---

## 2. THE PIPELINE -- FOUR MODELS, DISTINCT ROLES

**Claude (you) -- Lead Engineer.** You write the specifications, verify what
comes back against committed source, and diagnose. You do not write production
code directly; Cursor does. **You are expected to push back**, including on
Gemini, and to say when you are uncertain.

**Gemini -- Staff Architect, binding rulings.** Every substantive spec goes to
him before Cursor sees it. He catches things -- in one session alone he caught a
TOCTOU race in a lock fix, an `OnTick` sampling blind spot, an MQL4/MQL5 API
confusion, and a lifecycle trap where a diagnostic would have been destroyed
before it was emitted. Treat his amendments seriously, but **verify them**: one
named an invariant `I7` when `I7` was already taken, and another mandated
`ExpertRemove` against a standing ruling. Both were caught by checking.

**Cursor -- implementation.** Works in the repos, runs tests, commits to
branches. Never to main. It is good at reporting honestly when something does
not work, and it has caught real errors in specs -- including one where a task
contained deliverables copy-pasted from a previous unrelated task.

**DeepSeek -- adversarial red-team audits.** Used for pre-implementation
critique of mathematical frameworks and for finding pathologies before code
exists.

**The courier pattern:** Cursor carries prompts to DeepSeek. Examples live in
`prompts/deepseek_*.md` -- a dozen or so, e.g.
`prompts/deepseek_ldak_phase4.md`, `prompts/deepseek_entry_price_audit.md`.
Results land in `adrs/deepseek_audit_*.md`.

**There is no written template for this pattern.** The examples show the shape --
Mission, System Context, the proposal, then explicit instructions not to write
code. **Worth creating `prompts/TEMPLATE_deepseek_audit.md` and committing it**;
ask the operator whether he wants that.

---

## 3. HOW SPECS ARE WRITTEN -- CONVENTIONS THAT MATTER

Every Cursor task follows a house format, and these are not decoration:

**Line-count bookends.** First line `This message has a line count at the bottom`
and last line `Line count: N`. The operator counts mechanically on receipt;
self-reported counts are not authoritative.

**ASCII only.** No em-dashes, no smart quotes, no box characters. They corrupt
in transit.

**Explicit NEGATIVE SPACE.** What NOT to do, itemised. Most near-misses came
from something not being forbidden.

**FAILURE MODES with STOP instructions.** Tell Cursor when to stop and report
rather than improvise. This has repeatedly prevented bad fixes.

**Tests with independently derived expected values.** Never "assert it returns
what it returns". Derive the number by hand and state the derivation. A spec
that said "1.0 CAD" when the answer was 0.1 nearly produced a test written to
match broken output.

**Branch, push, do not merge, no PR.** The operator merges after verification.

**CLI compile is not trusted for MQL5.** MetaEditor GUI compile is the
authoritative gate and the operator runs it.

---

## 4. MACHINES AND HOW THEY ARE USED

**Desktop** (`D:\fxmatrix`, `D:\pipshed`) -- the working machine. Git, Cursor,
MetaEditor for compiling and running the test suite. **An MT5 terminal is
installed and Cursor can interact with it**, but no EAs are attached there and
algo trading is off. Compiles here are for testing only.

**VPS** (`C:\fxmatrix`, terminal hash `81A933A9AFC5DE3C23B15CAB19C63850`) --
**this is where the fleet actually trades.** Twelve EAs attached, algo trading
ON. Reached by RDP. Deploy with `.\deploy.ps1` then compile in MetaEditor --
**deploy copies files, only the compile reloads the EAs.** That distinction cost
an hour last session.

**Surface** (`C:\fxmatrix`) -- the dedicated research machine. Python venv, all
sweeps run here. Reached by RDP, and **its drive is mapped from the desktop** --
watch the path depth, a copy once landed in `C:\fxmatrix\fxmatrix\data`.

**Sweep work lives on the Surface.** Ten years of M5 data for the AUD/CAD/CHF
ring is already exported and sliced into five pre-registered windows. **The next
extension is JPY and NZD** -- see section 9 of the handoff. Export is about
eight seconds per symbol via the Strategy Tester; the sweep itself is hours.

---

## 5. YOU CAN SEE THE FLEET DIRECTLY -- USE IT

This was built precisely so you do not work from screenshots.

    https://pipshed.com/api/g/k7m9p2x4q/status/<segment>
    https://pipshed.com/api/g/k7m9p2x4q/scalps/<segment>
    https://pipshed.com/api/g/k7m9p2x4q/scalps/<segment>?date=2026-09-10

**The trailing segment is a cache-buster and MUST CHANGE every time you fetch.**
Your fetch tool caches by PATH and strips query strings, so `?v=2` does nothing.
Use `/status/a1`, then `a2`, and so on. The server ignores it entirely.

**You cannot construct these URLs yourself** -- the fetch tool only accepts URLs
that have appeared in the conversation. Ask the operator to paste each one.

**What you get:** every position and pending order under every magic, with
ticket numbers, prices, millisecond timestamps, raw broker comments and
per-position profit. Plus layer state, resting levels, account balance, equity,
intraday MAE, and -- when reconstruction rejects a book -- everything it saw
before halting.

**Last session this reproduced the MT5 Trade tab exactly**: 18 positions, 36
orders, every field matching.

**Screenshots should now be a double-check, not a primary source.** Ask for one
to confirm something surprising, not to do routine diagnosis. At the fleet's cap
this is 190+ orders and screenshots stop working entirely.

**Always check `generated_at` before trusting a read.** A stale cached response
caused two wrong conclusions in an earlier session.

---

## 6. THE MYSTERY BUGS

Three defects remain unexplained. **The telemetry was built specifically to
catch them next time.**

**Missing exits.** A position fills and its exit order never appears -- five
halts in one day on `I3_*_NAKED`. In two cases one arm placed its exit while its
twin, filling the same price in the SAME SECOND, did not. So it is not
deterministic. **We never established whether the `OrderSend` failed or was
never attempted**, and that distinction is the entire diagnosis.

**14 of 27 scalp events never emitted.** The code was live for most of the day
and the missing ones INTERLEAVE with ones that did -- 15:30 missing, 15:24
present. Thirteen were SHORT and one LONG, so no simple side-based theory fits.
They were recovered from deal history by backfill.

**Phantom layers.** A layer survived its own close. `invariant_ok` stayed true
because a phantom layer with a phantom exit is internally self-consistent.
Cleared by reloading; the layer reconciler is the real fix and is not built.

**What now catches them:** `recon_failure` emits every ticket reconstruction saw
plus the offending one -- it diagnosed an `I5_SHORT_DUP` in seconds.
`resting_entries_*` is counted from the BROKER, so a duplicate the EA cannot see
still shows. `open_time_msc` orders artifacts created in the same second.

**What still does not:** we log STATE, not ATTEMPTS. Which is exactly what the
Postgres work is for.

---

## 7. THE NEXT PIECE OF WORK -- POSTGRES ARCHIVE

**Provision a Postgres database in the pipshed project on Railway.** There is a
50 GB instance available and unused.

Full design and rulings are in section 5b of the handoff. The essentials:

**Isolation is absolute.** Redis is operational truth; Postgres is an
asynchronous shadow. `/api/telemetry/push` must NEVER fail because the archive
is down -- the EA would see POST failures and the dashboard would go dark for a
storage problem. Pattern: receive, write Redis, return 200, `RPUSH` to a Redis
queue, and a SEPARATE worker drains it to Postgres in batches. If Postgres is
down the list backs up and drains later.

**Transport: a separate `/api/telemetry/action` endpoint, NOT the heartbeat.**
The decisive argument is lifecycle -- the heartbeat runs on a timer, and **if
the EA dies between beats you lose the event that killed it.** For a diagnostic
log that is exactly backwards.

**Schema: distinct tables, normalised.** Not one `events` table with a type
column -- the point of Postgres here is clean indexed SQL when debugging under
pressure.

**Phase 1: send log and scalp history. Snapshots are phase 2** -- they are
largely inferable from a complete event log.

### Curating the logs -- ratified criteria

Do NOT ship the journal wholesale. Yesterday's Experts log was **125 MB** with
`InpVerboseLog=true` across twelve instances, and **it truncates at 4096
characters** -- so archiving heartbeat lines preserves the truncation rather
than the data, while the structured payload already arrives intact.

**Ship only what has no schema: `ERROR`, `WARN` and `CRITICAL` lines.** That is
roughly 1% of the volume and nearly all of the diagnostic value.

**Also ship config events** -- the `fxgrind CONFIG ...` dump on attach and the
`deinit reason=N` on detach. These catch a wrong-chart attach (a `symbol=` that
disagrees with the instance name -- this happened), confirm whether a compile
took effect, and surface configuration drift.

**Once this exists, `InpVerboseLog` can go back to false.**

### Retention -- per table, not one global rule

    send_logs       14 days
    log_lines       14 days
    scalp_history   KEEP -- the performance record, ~10k rows a year
    config_events   KEEP -- rare, small, and worth having historically
    book_snapshots  14 days (phase 2)

A nightly `DELETE WHERE time < now() - interval '14 days'` suffices at this
volume. **The job has to actually run** -- design retention in, do not retrofit.

### The template repo -- READ ONLY

**`theonlykk/candlelab` has a working Postgres instance** on Railway. Use it as
a reference for connection handling, migrations and deployment config. It also
has a **Postgres bounce feature** that may be worth adopting.

**READ ONLY. Do not write to it, do not deploy to it, do not cross the
streams.** CandleLab is a mothballed project and resurrecting it by accident
would be a genuine problem.

---

## 8. ANALYSIS TOOLING ALREADY BUILT

**`notebooks/signal_vs_dumb_ab.ipynb`** -- the A/B analysis on REAL broker P&L,
terminal `DEAL_PROFIT` plus swap plus commission. Unaffected by every simulator
defect found so far, which makes it the trustworthy performance record. It
produced the result that retired the signal arm.

**`scripts/dump_deals_range.mq5`** -- run in MetaEditor on the terminal holding
the account, produces a CSV of deal history to `MQL5\Files\`. The operator
copies it to `data\local\` which is gitignored. **Never commit a CSV; the repo
is public.**

**`scripts/backfill_scalp_closed.py`** -- replays scalps from a deal dump into
the history panel. Dry run by default. Three traps it handles, all silent
failures: CloseBy splits P&L across TWO `OUT_BY` deals so you must sum both; MT5
CSV dates use PERIODS and `fromisoformat` throws; and **Cloudflare blocks
Python-urllib's default User-Agent with error 1010** -- any script hitting
pipshed needs an explicit UA.

---

## 9. ASK QUESTIONS. THIS IS EXPECTED.

**The previous chat is still open.** The operator will copy your questions
across and paste the answers back.

Use this. Much of the reasoning behind current decisions is in that
conversation rather than in any document -- why a cap is 8 rather than 12, why
live data outranks the simulator, why the slot tokens cannot be renamed.

**Ask especially when:**
  - something in the handoff seems to contradict the code
  - you are about to reverse a decision and want to know why it was made
  - a spec you are writing touches code that has produced defects before
  - you are unsure whether something is ratified or merely discussed

A question costs a copy-paste. A wrong assumption last session cost an hour and
nearly closed the wrong position.

---

## 10. STANDING DISCIPLINES

These were earned, each by something going wrong:

**Verify against committed source, never a self-report.** Fetch the branch and
read it.

**Report cause before fixing.** Do not apply a plausible change without
diagnosis.

**Never adjust an expected value to match output.** That converts a test into a
description.

**Fail closed.** Invariants halt rather than compound.

**A code path that has never run is not a path that works.** Four defects in one
week were all first-time-ever paths.

**An invariant and a reconciler must never target the same condition.** One
defines a state the system cannot survive; the other defines one it heals.

**Live measurement outranks simulation.** Where real fills exist, they decide.
The simulator has four known divergences from reality.

---

## 11. CURRENT STATE IN ONE PARAGRAPH

Twelve fxgrind instances on FTMO demo **1514582088**, cycle 2, an A/B where exit
distance is the only variable. Six pairs: EURUSD, GBPUSD, EURGBP, AUDCAD,
AUDCHF, CADCHF. Unpaced, caps enforced, currency caps disabled. Yesterday: 27
scalps, $20.87 scalp P&L, account +$16 after manual recovery closes. Worst
floating drawdown about $9 against a $500 daily gate. The account is a demo --
nothing here risks real money.

---

## 12. WHEN YOU WRITE THE NEXT HANDOVER

Sections 1 through 4, 9 and 10 are **boilerplate** -- carry them forward mostly
unchanged. They describe how the project works rather than what is happening.

Sections 5 through 8 and 11 are **current state** -- rewrite them.

Keep a running handoff in `handoffs/HANDOFF_<date>.md` for the detail, and let
this document stay a pointer to it rather than duplicating it.

**Commit both.** The handoffs directory already holds two and the sequence is
worth preserving.
