# ARCHITECT.md -- Engineering Rules for fxmatrix / fxgrind

**Master copy:** `docs/architecture/ARCHITECT.md` in the repo. Any copy on
the desktop, Surface or elsewhere is stale by definition; delete it rather
than editing it.

**Scope:** how work is proposed, audited, specified, verified and deployed.
It is not a design document for the EA -- that is what ADRs are for -- and
it is not a status report -- that is what the dated handoffs in `handoffs/`
are for.

**Era:** fxgrind (single-pair passive market maker, twelve instances).
V2-era material lives in `ARCHITECT_V2_HISTORY.md`; this file keeps only
the V2 lessons that still bind.

---

## 1. THE SYSTEM (fixed frame block)

Paste this verbatim at the top of every DeepSeek brief and every Gemini
design memo, so no reviewer reasons about an imagined system.

> fxgrind is a passive limit-order market maker on MT5. Twelve instances
> (six symbols x two geometry arms, OPT and ALT) share one FTMO demo
> account, separated by magic number. It NEVER crosses the spread and NEVER
> uses stop losses.
>
> Per side (long and short) an instance holds a ladder of "layers". Each
> layer is one open position plus exactly one resting exit limit:
> a long layer is a BUY position whose exit is a SELL LIMIT above market;
> a short layer is a SELL position whose exit is a BUY LIMIT below market.
> The exit is priced at entry +/- exit_pips and fixed at fill time. Entry
> orders are different: L0 is re-quoted toward MID every tick outside a
> deadband, and adds are priced from the layer anchor at add_pips spacing.
>
> Invariants run on EVERY tick and halt the instance when the book and the
> tracker disagree. A halted instance stops trading but keeps observing.

Two consequences follow from that frame and are easy to get wrong:

- **Mid-anchored orders and basis-anchored orders are not the same thing.**
  L0 follows mid and owes nothing to any position. Exits and adds are
  anchored to a filled entry. Any rule about cost, carry or basis applies
  only to the basis-anchored ones. (Proof: applying carry "equivalence" to
  an unfilled bid and offer raises the bid and lowers the offer, closing the
  spread every night until the quotes cross.)
- **Exits close exposure; adds open it.** A rule that is safe on an exit can
  be unsafe on an add, because an add starts a new position with its own
  cost clock.

---

## 2. THE PIPELINE

The point of splitting models is cognitive partition: an agent cannot
ruthlessly critique logic it is simultaneously trying to build. We tear
down with one, synthesize with another, rule with a third, and implement
with a fourth.

### Roles

| Model | Role | Authority |
|---|---|---|
| DeepSeek R1 | Red team. Adversarial teardown, statistics, mechanism audit | Finds; never rules |
| Claude | Lead engineer. Design, specs, verification, handoffs | Proposes; verifies everything |
| Gemini | Staff architect. Rulings, prompt refinement, consultation | Rules on design conflicts |
| Cursor | Implementer | Writes code to spec; rules on nothing |
| Operator (Khalid) | Owns the account, the risk and the final call | Overrules anyone |

### When DeepSeek is MANDATORY

- Geometry and grid spacing.
- Statistics, sweeps, calibration methodology.
- State-machine logic of an existing mechanism (invariants, halts,
  reconstruction, order lifecycle).
- Anything that moves a live order or changes when one is placed.

### When DeepSeek is OPTIONAL

Telemetry plumbing, dashboards, deploy scripts, report formatting. Use it
anyway when the change touches money, exposure or an invariant.

### Source-grounding mandate (ratified Gemini, 2026-08-14)

A teardown of an EXISTING mechanism must either be given direct source
excerpts, or be explicitly scoped to methodology and specification
consistency. A source-blind teardown of existing code hallucinates attack
vectors against assumed internals. Demonstrated both ways: a source-grounded
audit returned 4/4 valid findings; a spec-blind one produced largely invalid
mechanism reds.

### Everyone is checked, including the architect

Gemini's rulings stand, but his reasoning is verified like anyone's. Live
examples worth remembering:

- ADR-128: claimed exit retry clears the transient (it does not -- the layer
  still holds its exit ticket) and that 3000 ms is a maximum (it is a
  minimum). Both corrected; the ruling survived.
- ADR-135b: "carry is a cost of inventory, not a cost of time" -- nearly
  right; carry is a cost of inventory held over time.
- ADR-135a: credited the spec with reading `SYMBOL_SWAP_ROLLOVER3DAYS` when
  it asked for the broker's weekly table with that as fallback.

State the correction, keep the ruling if it survives, and record both.

---

## 3. THE DEEPSEEK COURIER PATTERN

Templates and a worked example live in `docs/deepseek_prompts_templates/`
(HOWTO plus one worked brief/response pair). The mechanism:

1. **Claude writes the BRIEF** and saves it to `prompts/<name>.md`. The
   brief carries integrity bookends: a known line 1, a known mid-file
   anchor line, a known last line, and the exact total line count.
2. **Claude writes a COURIER wrapper** -- a short prompt whose only job is
   to load the brief from disk, verify all four bookends, hard-stop on any
   mismatch, perform the task, and write `prompts/<name>_response.md`.
3. **The operator** saves the brief, switches Cursor to DeepSeek R1, and
   pastes the courier.
4. **The courier never touches git.** The operator commits the brief and
   response pair.
5. **Claude reads both from GitHub** and verifies every load-bearing claim
   against real source before acting on any of it.

Why the bookends: a brief that loads partially produces an audit of a
system that does not exist, and nothing downstream would reveal it.

Why the courier does not commit: the operator owns what enters the repo,
and an agent that both performs and records its own work has no independent
check.

---

## 4. PROMPT CONSTRUCTION (Cursor)

Every implementation prompt must contain:

- **Audit trail table** -- design source, who reviewed, what was ruled,
  baseline commit and current suite count.
- **Branch instruction** -- create a named branch, N commits, push, do NOT
  merge, do NOT open a PR.
- **Context** -- the exact functions and line anchors being touched,
  verified against source at the stated baseline.
- **Design** -- numbered, unambiguous, with worked arithmetic wherever a
  sign or direction could be read two ways.
- **Tests** -- named, with exact assertion counts and expected values
  derived independently (see section 6).
- **Negative space** -- an explicit list of what NOT to touch.
- **Failure modes** -- what to do when an assumption turns out false. Always
  "STOP and report", never "choose something sensible".
- **Self-review** -- re-read every diff, flag any hack or constraint
  violation before committing.
- **ADR instruction** -- generate the ADR alongside the code.
- **Line count bookends** -- open with "This message has a line count at the
  bottom", close with the exact count, require the same in the response.
- **ASCII only** in every file created.

### Prompt pacing: the silent error test

When a prompt pairs a confirmation step with implementation, ask: **would an
incorrect confirmation produce output that still looks correct under normal
diff review?**

- **Two-step (confirm alone, implementation withheld):** mathematical
  conversions, unit assumptions, hidden scope or state -- anything that
  would compile, pass tests and be wrong only in production.
- **Single-shot:** line anchoring, deletion boundaries, anything already
  bounded by negative space; an error shows up directly as an out-of-scope
  diff line.

When in doubt, name the specific failure mode rather than defaulting either
way.

### ADR content must be included in full

Naming an ADR file and its line count is not sufficient. "See repo for full
content" defeats the review step. This applies with no exception for length.

### The standard review loop

Claude drafts -> Gemini reviews -> Claude verifies each amendment and states
accepted or rejected with reasons -> Claude reissues the FULL prompt with a
fresh line count -> operator sends the final version to Cursor.

Never send the old prompt plus an amendment note. One document, one count.

---

## 5. VERIFICATION DISCIPLINE

This is the section that earns its keep. Every item below exists because
something got through.

### Read the branch, not the response

**Do not paste Cursor's response into chat.** Cursor pushes a branch;
Claude reads both commits directly from GitHub (`git fetch` also reveals new
branches, so even the branch name is optional). This is faster for the
operator and strictly more reliable: Cursor's summaries have repeatedly been
abbreviated, mis-numbered, or wrong about their own content.

Paste only what is NOT in git:
- MetaEditor compile output and SUMMARY lines
- VPS Experts/Journal log excerpts
- PowerShell errors
- pipshed URLs (as plain text on their own line)

### Claude verifies, in this order

1. **Scope** -- `git diff --stat` against the baseline. Any file outside the
   spec is a stop.
2. **The load-bearing lines** -- read the actual implementation of every
   rule the spec stated, not the summary of it.
3. **Safety properties** -- for an observe-only change, grep the whole diff
   for `OrderSend`, `OrderModify`, `TRADE_ACTION` and confirm zero.
4. **Tests as committed** -- read the test bodies and recount assertions;
   predictions must be derived from the stubs actually committed.
5. **Run what can be run** -- for Python, Claude runs every verify script
   itself in its sandbox at both commits.

### Python: test against real infrastructure

Fake databases pass code that real ones reject. Claude installs a real
Postgres and Redis in its sandbox and repeats the critical paths: the
migration, duplicate inserts, a poison item, the service down at startup,
the service dropping mid-run.

Live proof this matters (ADR-130): all fake-DB tests passed; against real
Postgres three crash defects appeared immediately -- every live scalp
crashed the worker, a poison item crash-looped it, and a database outage
made it exit rather than retry.

### New events must be parsed, not substring-matched

Any spec that emits a new structured event MUST include a test that PARSES
the emitted payload. A `contains "code":"X"` assertion passes happily on
malformed JSON.

Live proof (ADR-135a): a snapshot event shipped with its `detail` object
missing its braces. Every test passed; pipshed answered 400; the EA dropped
the whole batch, taking 12 DEINIT and 12 INIT rows with it.

### Compile the EA itself, not just the tests

The test script does not exercise every code path the EA compiles. Compile
`fxgrind.mq5` in MetaEditor before every merge.

Live proof (ADR-134): `HistoryOrderGetDouble` called without its ticket
compiled fine in the tests and failed the EA build.

### Verify against committed source, never CLI compile output

CLI/headless compile is unreliable in specific, confirmed ways: a running
MetaEditor GUI makes `/compile:` silently no-op with exit code 0; exit codes
have been observed inverted; a stale log reads as a current result; unquoted
paths with spaces fail silently. If a CLI check is used at all it must kill
any GUI instance first, use a fresh uniquely-named log, quote paths, and
verify by `.ex5` timestamp rather than exit code. **The operator's GUI
compile remains the authoritative gate regardless.**

---

## 6. THE TESTS-FIRST PATTERN

Every fix ships as two commits:

- **Commit 1: tests (and stubs if needed).** The tests must FAIL. Any test
  that passes against the stubs is testing nothing and stops the job.
- **Commit 2: the implementation.** All tests pass.

The operator runs the suite at BOTH commits and reports the SUMMARY line.
The prompt states the exact expected count at each.

### Rules that make it work

- **Expected values are derived independently** -- from the fixtures and the
  arithmetic, never by running the code and recording what it said. If the
  code disagrees with the expectation, STOP and report; do not adjust the
  expectation.
- **The stub commit MUST compile on its own.** Every symbol the tests
  reference is declared in commit 1, including test hooks that live in
  EXISTING files. (ADR-131's stub commit failed exactly here: a hook
  belonged in `grind_telemetry.mqh`, which the stub commit did not touch.)
- **Predictions come from the stubs as committed**, not as intended. Cursor
  sometimes implements more than the stub spec asked; recount before
  predicting.
- **A prediction that misses is investigated, not overwritten.** Sometimes
  the code is wrong; sometimes the prediction was. Both have happened.

---

## 7. KNOWN AGENT FAILURE MODES

Observed, dated, and expected to recur.

| Failure | Seen | Countermeasure |
|---|---|---|
| Cursor reports the PROMPT's line count as its own | repeatedly | Count independently; treat as unverifiable across chunks |
| Cursor abbreviates diffs despite an explicit ban | 4+ times | Read the branch |
| Cursor puts test-only code in production (a `_Stop` check inside `except`) | ADR-130 | Review production diffs for test identifiers |
| Cursor edits test harnesses in the fix commit | ADR-131 | Diff the test files between commits |
| Cursor assumes an API exists (per-day swap constants) | ADR-135a | Failure mode: STOP and report, never guess |
| Gemini generates implementation instead of a review | ADR-135a | Disregard; the spec is the source |
| DeepSeek proposes remedies the EA cannot execute (query Postgres) | ADR-135b | Verify every remedy against the architecture |
| DeepSeek proposes checks already covered more tightly elsewhere | ADR-135b | Check for redundancy with existing invariants |
| DeepSeek mixes clocks (`TimeLocal` vs server time) | ADR-135b | Verify every primitive's semantics |

---

## 8. MACHINES AND SYNC

Three machines, three roles. Do not assume rules transfer.

**Desktop** -- repo at `D:\fxmatrix`, the working copy (not a clone that
needs pulling). MT5 here is for compiling and Strategy Tester only, never
attached to a live chart. All Strategy Tester work runs here.

**VPS** -- separate clone at `C:\fxmatrix`. Runs the twelve live instances.
Cursor has NO execution access, deliberately: the one machine with real
trading consequences stays off the automated-agent surface. Code reaches it
only via `deploy.ps1` pulling from git; the VPS never pushes.

**Surface** -- Python only, no MT5, separate `C:\fxmatrix`. Cursor has no
write access. Data moves over RDP, with `S:\` as a backup route.

### Sync scripts

- `deploy.ps1` (VPS): `git pull origin main`, xcopy into
  `MQL5\Experts\fxmatrix\`, then SHA256-verify every copied file against the
  just-pulled repo. Added after an xcopy was found able to partially fail on
  a locked file with no error surfaced.
- `desktop_sync.ps1` (desktop): no git pull; copies production `.mq5` plus
  the full tracked header set into `MQL5\Experts\` (flat) AND `MQL5\Scripts\`,
  both SHA256-verified. Two destinations are required, not optional: MQL5
  resolves a quoted `#include` relative to the compiling file's folder, so
  Scripts needs its own physical copy of every header.
- The header set is derived from the actual `#include` graph, never
  hand-edited from memory. A stale assumed list once produced a 58-error
  compile failure.

### Before every compile that matters

Confirm repo and terminal copies are byte-identical by CONTENT HASH -- never
by size or timestamp, both of which have produced false confidence. A clean
compile against a stale file is not evidence of anything. Both sync scripts
do this automatically and print "verified byte-identical"; trust that line,
not the absence of errors.

Also: use MetaEditor's File -> Open on the explicit path before compiling. A
tab left open from an earlier session can silently compile old content.

Desktop and VPS layouts are NOT symmetric: desktop is flat
`MQL5\Experts\` and `MQL5\Scripts\`; VPS deploys into
`MQL5\Experts\fxmatrix\`.

---

## 9. DEPLOY

### fxgrind recompile (current practice)

1. **Status read before** -- fetch `/api/g/<token>/status/<segment>` and
   confirm the book is consistent and nothing is halted.
2. `deploy.ps1` on the VPS; confirm "verified byte-identical".
3. GUI-compile `fxgrind.mq5` in MetaEditor; confirm 0 errors.
4. **Status read after** -- same check, plus confirm all twelve reloaded.

AlgoTrading off is OPTIONAL for a recompile on a consistent book: the EA
reconstructs layer state from the broker book on OnInit. Turn it off when
deliberately flattening a side, or when the book is already inconsistent.

### Traps confirmed live

- Pressing OK in the EA properties dialog without changing anything does NOT
  reinit. Append to `InpConfigWarning` to force a parameter-change reinit.
- Deleting a stray add while a phantom layer remains is futile: the next
  tick replaces it.
- `TelemetryAPIKey` is blank in repo presets (public repo). Fill it in the
  dialog or the instance goes dark.
- The pipshed status snapshot lags the EA by up to 60 s.
- A recompile resets every in-memory daily counter; use the archive, not the
  heartbeat counters, for daily totals.

---

## 10. OBSERVABILITY

**Redis is operational truth. Postgres is an asynchronous shadow.** The
pipshed web service must NEVER hold `DATABASE_URL`; the worker reads
Postgres and publishes computed views into Redis.

- **Live book, scalps, carry table, summary, carry audit** -- pipshed
  endpoints under `/api/g/<token>/...`, each accepting a trailing
  cache-buster segment that must change on every fetch.
- **Durable history** -- Postgres tables `send_logs`, `fill_logs`,
  `config_events`, `ea_events`, `scalp_history`. Query with
  `scripts/archive_counts.py` inside the worker via `railway ssh`.
- **Migrations** -- plain SQL in `migrations/`, applied by hand with
  `db_migrate.py` from INSIDE the worker container (private network; the
  database never needs public access). Never at application startup.

Rule: if a number can be read from the archive, do not ask an agent to
recompute it from logs.

---

## 11. STANDING ENGINEERING RULES

- **ASCII only** in every prompt, ADR and generated file.
- **Never `git add .` or blind `git add -u`.** Stage only the confirmed file
  list, by exact name. The desktop tree accumulates thousands of lines of
  untracked experimental files.
- **Never commit CSVs** or raw data exports.
- **Branch, push, do not merge.** The operator merges.
- **Invariants are not reconcilers.** An invariant detects and halts; a
  reconciler repairs. Never let one silently do the other's job.
- **Live evidence beats simulation.** When they disagree, the live book
  wins and the sim is wrong until proven otherwise.
- **Never-run code paths are suspect.** A branch that has never executed
  against real data is unverified regardless of test coverage.
- **GlobalVariables are terminal-scoped**, survive restarts, and MT5 keeps
  unused ones about four weeks. Anything stored there needs a defined
  deletion point.
- **pipshed requires an explicit User-Agent** and has two gates (bearer key
  for writes, public token for reads).
- **Timestamps:** broker time is stored in `*_broker` columns as naive local
  broker time and is NEVER labelled `Z`. Wall-clock arrival is
  `received_at timestamptz`. The EA's own clock is a UTC anchor taken once
  at OnInit plus elapsed monotonic milliseconds.
- **Cap thresholds stay at 0** (`InpCapLegAThresh`, `InpCapLegBThresh`)
  until a failing ALLOW test exists. The destructive-reset defect is fixed;
  the stale/missing-GV-reads-as-permissive-zero problem is not.

---

## 12. CALIBRATION AND REFACTOR GATES (carried forward from V2)

### Mandatory calibration / holdout discipline

Any parameter derivation, grid calibration or threshold selection must
pre-register a calibration/holdout split BEFORE the sweep: at most half the
windows for selection, the rest evaluated strictly after the parameter is
locked. If the holdout degrades materially, the change is REJECTED, not
re-tuned. (Adopted per Gemini, 2026-08-02, after an in-sample selection
pattern was found in ADR-099.)

### Mandatory refactoring parity gate

A refactor claiming behavioural equivalence must pass a dual-tolerance
real-tick backtest: exact match on order counts, exit counts, max layers,
peak net lots and tick-rounded order prices; ~1e-9 relative tolerance on
internal unrounded floating-point state; P&L exact when the deal sequence is
identical, otherwise bounded by an explicitly stated rounding tolerance.
(Adopted per Gemini, 2026-08-02.)

### V2 carry-forward items

- **300 s pacing gate** and the **ADR-114 layer-anchor ratchet** remain
  live concepts in fxgrind.
- **The AddPipsFloor slippage lesson generalises:** a geometry parameter
  derived from simulated fills must be re-derived, or at minimum
  re-validated, against real fill data before it governs live orders.

---

## 13. MQL5 FACTS LEARNED THE HARD WAY

- A floating-point division by zero STOPS the EA with a critical error. It
  does not yield inf or nan. Guard every divisor.
- `HistoryOrderGetDouble(ticket, property)` requires the ticket even after
  `HistoryOrderSelect`. The one-argument form does not exist.
- nan/inf arise from functions like `MathSqrt(-1)`; `DoubleToString` prints
  them as non-JSON text. Emit `null` when `!MathIsValidNumber`.
- `TimeCurrent()` is the LAST QUOTE time and freezes when quotes stop --
  including all weekend. `TimeTradeServer()` is the calculated server clock
  and keeps advancing. Use `TimeTradeServer()` for any gate or staleness
  check.
- `SYMBOL_TRADE_MODE` is a static "tradeable in principle" property, NOT a
  market-open check. It reads FULL with the market closed.
- WebRequest during `OnDeinit` is not guaranteed to complete. Persist the
  state locally and send it on the next OnInit instead.
- `Sleep()` inside `OnTimer` blocks that instance's entire event loop,
  including OnTick and OnTradeTransaction. Chunk work across timer calls.
- A position's ticket equals its opening order's ticket, which makes
  "did this order fill?" answerable without an order-history lookup.
- Order history can lag the DEAL_ADD transaction, so a lookup that works
  most of the time will fail some of the time. Keep a local fallback.

---

## 14. POINTERS

- **ADRs:** `docs/architecture/ADR-*.md`. Every shipped change has one.
- **V2 history:** `docs/architecture/ARCHITECT_V2_HISTORY.md` -- machine
  topology of the V2 era, the SRE, HALT_09 genesis-orphan behaviour, EURGBP
  cap work, the BCC sweep, and the parked V2 backlog.
- **Incident first-response doctrine:** `ARCHITECT_V2_HISTORY.md` until
  rewritten for fxgrind. Manual levers only; nothing there is automated.
- **Session state:** the dated files in `handoffs/`. The most recent one is
  authoritative for what is live, what is queued and what is parked.
- **DeepSeek templates:** `docs/deepseek_prompts_templates/`.

---

**Revised:** 2026-09-12.
**Supersedes:** the pre-fxgrind ARCHITECT.md in full.
