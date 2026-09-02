# FXMatrix V3 — Independent Audit Report: Tier 3 Incident (2026-07-02) + Bug-Class Sweep

**Auditor:** Claude Fable 5 (Claude Code, direct repo access, read-only)
**Repo sanity check:** Confirmed fxmatrix — `ea/FXMatrix.mq5` and `docs/architecture/ADR-074.md` both present; MQL5 EA source tree, not the pipshed Flask repo.
**Test baseline:** `python temp/run_tests_0_41.py` run read-only — **279/279 subtests PASS**, including Test 51 (ADR-074 poll mirror). Matches the stated baseline.
**No files were created, modified, or deleted in the repository. No mutating git commands were run.**

---

## Part A — Independent incident analysis

### A.1 The stated root causes are confirmed, with one correction of emphasis

I recovered the pre-incident code via `git show 51a9575` (the ADR-074 diff) and traced both trigger paths. Both stated causes are real and sufficient to produce exactly what was observed:

- **Cause 1 confirmed.** Pre-074 `CloseAllPositions()` (`ea/FXMatrix.mq5:884-908`, still present as dead code) filters `PositionGetInteger(POSITION_MAGIC) != (long)EA_MAGIC → continue`. Exact match only. Every `EA_MAGIC+1` (add-next grid) and `EA_MAGIC+2` (hedge) position was never selected — no close was ever *sent* for them.
- **Cause 2 confirmed.** Both Tier 3 trigger blocks then ran `ArrayResize(g_inventory_0/1/2, 0)` + `SaveAllInventoryState()` unconditionally, with no `PositionSelectByTicket` verification of anything. The 5/7/3 → 0/0/0 state-file transition in under 2 seconds is exactly this line pair executing.
- **The duplication is confirmed.** The 4%-daily block and the legacy absolute-floor block were byte-for-byte structural copies of the same sweep (visible in the ADR-074 diff), so the bug existed twice from copy-paste.

**Correction of emphasis:** the account frames Cause 1 as "a lesson learned in `CheckForOrphans()` and never propagated." Git history shows the true origin is slightly different and more instructive: **`CloseAllPositions()` was correct when written — the magic-offset scheme didn't exist yet — and became wrong when ADR-015 introduced the offsets, because that migration never swept all `POSITION_MAGIC` consumers.** The bug is a *semantic-migration gap*, not an originally-wrong function. That distinction matters for Part B, because it predicts where else to look: every consumer of `POSITION_MAGIC`/`ORDER_MAGIC` written before 2026-06-16, or written since by copying pre-offset patterns.

### A.2 Git-history dating — the evidence settles the two hypotheses decisively

| Date | Commit | Event |
|---|---|---|
| 2026-06-07 | `1b4f026` | `CloseAllPositions()` written with single-magic filter — **correct at the time** (one magic number existed) |
| 2026-06-13 | `e5c3a6f` | `ClosePodPositions()` (Tier 1) written; dual-tier circuit breaker |
| 2026-06-14 | `402ff29` | ADR-012: FTMO equity failsafe (the legacy floor path) wired to `CloseAllPositions()` |
| **2026-06-16** | `21a9144` | **ADR-015 introduces `EA_MAGIC+1`/`+2` offsets — `CloseAllPositions()` silently becomes wrong here** |
| 2026-06-19 | `5bcd31a` | F1: *the same Tier-3 sweep block* gets the three-magic fix **for order cancels**, with a comment naming the +1/+2 blind spot — **five lines below the still-unfixed `CloseAllPositions()` call**. The same commit introduces the unconditional `ArrayResize(...,0)` inventory clear (Cause 2 is born here) |
| 2026-06-20 | `d464497` | F4: `CheckForOrphans()` gets the three-magic fix (the comment quoted in the audit request) |
| 2026-06-29 | `1913305` | ADR-055 rewrites the whole Tier 3 block into Phase 3.A and **copy-pastes the half-fixed sweep into the second (absolute-floor) trigger** — nine days *after* F4, actively re-copying the "+1/+2 must be cancelled explicitly" comment for orders while leaving the position close at exact-match |
| 2026-07-02 | `51a9575` | ADR-074 fix, ~2h after the incident |

**Verdict: hypothesis 1 ("lesson learned and then forgotten to propagate") is supported, in its strongest possible form.** This is not a case of Tier 3 predating the lesson. The Tier 3 sweep block was substantially rewritten **twice after the three-magic lesson existed** (June 19 and June 29), and on both occasions the +1/+2 enumeration was correctly applied/re-applied to the *order-cancel half* of the block while the *position-close half*, one function call away, was left at exact match. The lesson was literally embedded in adjacent lines of the code being edited. The failure mode is: the magic-offset invariant lived in comments at two call sites rather than in one shared filter function, so each edit had to independently remember it — and the position-close side never did.

### A.3 Extensions — why this survived undetected (beyond the account's "silent logging" point)

1. **ADR-055 converted a noisy, self-retrying failure into a one-shot silent one.** Pre-055, the nuclear failsafe set `g_halted = true` but did **not** call `ExpertRemove()`, and (per the F1 fix) `CheckCircuitBreakers()` runs even when halted — so the condition would have re-fired and re-logged `CRITICAL` on every tick, retrying the (still-incomplete) close and spamming the journal. Anyone watching would have noticed. ADR-055's `ExpertRemove()` made the failure fire exactly once, wipe state, and vanish. A correctness-neutral-looking change materially degraded observability of the latent bug.
2. **By construction, no feedback loop ever verified sweep closes.** The pre-074 close requests set no `req.magic` (deal magic 0), and `OnTradeTransaction`'s `DEAL_ENTRY_OUT` handler only processes `EA_MAGIC+2` — every close deal from the sweep was dropped as "unmanaged magic." Even if the sweep had partially worked, nothing in the event pipeline would have reconciled the outcome. The system's only position-truth check (`CheckForOrphans`) runs once at `OnInit`, which never happens after `ExpertRemove()` until manual reattach.
3. **The Python test suite had zero Tier 3 coverage until Test 51 (added post-incident with ADR-074).** The suite mirrors math/state logic, not broker-interaction paths, so this entire class is structurally outside its reach.
4. **Tier 3 had never fired live before.** The most safety-critical path in the system was also the least-exercised — the classic emergency-code problem, correctly acknowledged in the audit request.
5. **One small arithmetic loose end worth reconciling against broker history:** MM had 15 layers (5/7/3); exact-match close should have caught at most 3 Layer-0 positions, predicting 12 stranded from MM alone — the operator found 11 total. Plausible explanations (a layer already flat, CloseBy netting in flight, count including/excluding SNIPER positions), but it has not been positively reconciled and would be cheap to confirm from the broker's deal history. If the 11 cannot be made to add up, something about the incident is still not fully understood.

### A.4 ADR-074 itself — verified against source, two accuracy notes

The implemented `ExecuteEmergencySystemSweep()` (`ea/StateEngine.mqh:476-567`) matches the ADR: broker-first scan, triad symbols × all three magics, `req.position` set correctly, batched 5×50ms poll, critical alerts for stranded tickets, selective purge via `PurgeClosedLayers()`. A nice emergent property: on reattach, if equity is still under the (persisted) daily floor, Tier 3 re-fires on the first tick and the sweep retries stranded closes — a natural retry loop.

Two notes:
1. **ADR-074's resumption attribution is imprecise.** The doc says stranded layers resume via "ADR-040 OnInit reconciliation (`g_reconciliation_pending` exit re-arm)." That path only fires for sentinel `exit_price_fixed < 0`; stranded layers carry real exit prices. The mechanism that actually re-arms them is `AuditExitLimits()` (every tick): its F3 logic detects the sweep-cancelled exit tickets as stale, clears them, and re-places. The safety outcome is the same, but the doc credits the wrong mechanism — worth fixing so nobody later "cleans up" `AuditExitLimits` believing ADR-040 covers this.
2. **The sweep's close requests still set no `req.magic`** (deal magic 0). Functionally harmless (verification is by ticket, not magic), but it degrades forensic attribution in broker history and means sweep-close deals sail through every instance's ADR-049 gate (they are ignored anyway as non-+2 OUT deals). Cosmetic; noted for completeness.

---

## Part B — Codebase audit for the same bug class

Calibration: today's incident = **critical** (emergency path silently strands the whole book and wipes state). Findings ordered by severity.

---

### B1 — CRITICAL: `ClosePodPositions()` (Tier 1) never sets `req.position` — on a hedging account its "closes" open *new opposite positions*

**File/function:** `ea/FXMatrix.mq5:725-787`, `ClosePodPositions()`; close request built at lines 741-754. Written in `e5c3a6f` (2026-06-13), untouched since (confirmed via `git blame`). Explicitly deferred by ADR-074's "negative space" section.

**Mechanism:** The close request sets `action=TRADE_ACTION_DEAL, symbol, volume, magic, type, price, type_filling, deviation, comment` — but **never `req.position`**. On an MT5 *hedging* account (which this is — the system's premise), a `TRADE_ACTION_DEAL` without a position ticket does not close anything; it opens a **new, independent position** in the opposite direction. This is documented MT5 behavior, and the codebase itself corroborates that `req.position` is required: the only three close paths that work or were fixed — `CloseAllPositions()` (line 893), `ProcessCloseByQueue()` (line 1188), `ExecuteEmergencySystemSweep()` (StateEngine line 494) — all set it. `ClosePodPositions()` is the sole close path that doesn't.

**Concrete risk scenario:** A single pod bleeds through `MaxPodDrawdown` (3% of balance — by far the most probable breaker to fire on an ordinary bad day; note the comment at `Globals.mqh:45` says "2% per pod" while the value is 0.03 — separate small doc bug). Tier 1 fires. For each of, say, 6 layers: a new opposite market position opens (margin roughly doubles, P&L locks), the original positions remain open. Then the function unconditionally runs `ArrayResize(g_inventory_X, 0)` + `SaveAllInventoryState()` (lines 781-785 — **Cause 2 verbatim, no verification**) and — unlike Tier 3 — **the EA keeps running** (no halt, no detach). Cascade: the six new market fills come back as `DEAL_ENTRY_IN` with `magic=EA_MAGIC` → `HandleEntryFill()` **repopulates the just-cleared inventory with six bogus wrong-direction layers**, computes exits for them, places exit limits, and potentially starts layering off them. The original six positions are unmanaged orphans until the next manual reattach. `GetPodUnrealizedPnL()` now reads the locked hedge (~0), so the breaker never re-fires while the loss is frozen open and the machine trades on top of it.

**Severity: CRITICAL.** Same class as the incident, in the breaker most likely to fire next, with a worse failure mode (EA continues trading on corrupted state instead of detaching). Caveat per the audit rules: the no-`req.position`-opens-a-new-position behavior is asserted from documented MT5 semantics plus the codebase's own internal inconsistency, not from a live repro — it should be confirmed in a strategy-tester/demo experiment before anyone stakes anything on the *exact* failure shape. Either way the field is missing and the state-clear is unverified.

### B2 — HIGH: `ClosePodPositions()` order-cancel loop has the exact Cause-1 magic scope gap

**File/function:** `ea/FXMatrix.mq5:762-775` (same function as B1).

**Mechanism:** The pending-order cancel filters `OrderGetInteger(ORDER_MAGIC) != (long)EA_MAGIC → continue`. Exact match only — the amputated instrument's add-next order (`EA_MAGIC+1`) and all its exit limits (`EA_MAGIC+2`) are never cancelled. Immediately after, `g_add_next[instrument] = 0` and the inventory clear discard all knowledge of them — assumed-outcome state mutation on top of a too-narrow filter. Both halves of the incident pattern, in one function, still live post-ADR-074.

**Concrete risk scenario:** Even in the charitable case where B1's closes worked, the pod's GTC exit limits stay resting on the book with no owner. Hours later one fills → new `+2` position on the hedge account → `HandleExitFill()` finds no matching ticket (inventory was cleared) → `HandleUnmatchedFill()` fallback fails (volume/time window) → ADR-054 downgrades to "**foreign noise — ignored**" → a naked, unmanaged directional position accumulates while the EA continues quoting normally. Discovered only at the next reattach.

**Severity: HIGH.** Identical structure to Cause 1 + Cause 2; slightly lower than B1 only because the exposure builds through stale GTC orders rather than immediately.

### B3 — HIGH: positions closed outside the EA are never reconciled while running; their exit limits stay armed

**File/function:** `ea/ExecutionEngine.mqh:1554-1565` (`OnTradeTransaction` `DEAL_ENTRY_OUT` handler — only `EA_MAGIC+2` deals are processed; everything else, including operator-manual closes with deal magic 0, is ignored). No periodic position-liveness purge exists anywhere: `PurgeClosedLayers()` runs only inside the Tier 3 sweep; `CheckForOrphans()` only at `OnInit`; `CheckDirectionConsistency()` (ADR-071) explicitly *skips* unselectable tickets.

**Mechanism:** If a human closes an EA-owned position in the MT5 terminal while an instance is attached, inventory is never updated: the layer persists, its `position_ticket` points at a dead position, and — critically — **its GTC exit limit remains live on the book**. If that exit limit later fills, it opens a fresh position (`+2`); `HandleExitFill()` matches the ticket, decrements `remaining_exit_volume`, and queues a CloseBy pairing the new position against the *dead* `position_ticket`; `ProcessCloseByQueue()` then hits `HistorySelectByPosition(ticket1)` = true → "already closed in history. Discarding task gracefully" (`FXMatrix.mq5:1153-1159`) → the new position is left open, untracked, unmanaged.

**Concrete risk scenario:** This is not hypothetical — it is precisely the operational posture the team is in right now. Post-incident triage involved manually flattening a book. The next time an operator manually closes positions while any instance is still attached (a natural triage move at Tier 2, for example), this cascade fires. The system's implicit assumption — *only the EA ever closes EA positions* — is enforced nowhere and was already violated this week.

**Severity: HIGH,** elevated by current operational reality.

### B4 — HIGH (mechanism) / MODERATE (likelihood): partial fill of an exit limit de-tracks the still-live order and triggers duplicate exit placement

**File/function:** `ea/ExecutionEngine.mqh:1075-1083` (`HandleExitFill`), interacting with `AuditExitLimits()` (`FXMatrix.mq5:990-1083`).

**Mechanism:** On *any* matched exit fill — including a partial one — the code decrements `remaining_exit_volume` and then **unconditionally `ArrayRemove`s the exit ticket from `exit_tickets`**. But a partially filled limit remains live on the broker (`ORDER_STATE_PARTIAL`) for its residual volume. Next tick, `AuditExitLimits()` sees `exit_tickets` empty + `remaining_exit_volume > 0` and places a **second** exit limit for volume the still-resting original already covers. If both fill: over-close → a new opposite naked position (`+2` fill with no matching ticket → ADR-054 "foreign noise") and `remaining_exit_volume` driven negative, so the layer is removed while a stray position lives on. State was mutated to reflect the assumed outcome "one fill event = order gone," never verified against `ORDER_STATE`. Note the codebase already knows better elsewhere — the F3 logic in `AuditExitLimits` and the add-next check explicitly distinguish `ORDER_STATE_PARTIAL`; `HandleExitFill` never got that lesson (same non-propagation signature as the incident).

**Concrete risk scenario:** A 0.03-lot exit limit on GBPUSD during a news spike fills 0.01/0.02 across two deals. Between deal 1 and deal 2, `AuditExitLimits` fires (it runs every tick) and places a duplicate 0.02 exit. Both residuals fill → book is short 0.02 naked, invisible to inventory.

**Severity:** mechanism HIGH; probability tempered by micro-lot sizes making broker partials rare — but the incident taught exactly what "rare" is worth on unverified paths.

### B5 — MODERATE-HIGH: cancelled partially-filled entry orders permanently corrupt layer volume state; no volume field is ever reconciled against the broker

**File/function:** `ea/ExecutionEngine.mqh:705-713, 815-817, 937-960` (`HandleEntryFill`: `lot_size = ORDER_VOLUME_INITIAL`; `remaining_entry_volume` decremented only by fill deals), plus every path that cancels entry orders (Tier 3 sweep order loop, `CancelAllPendingEntries()`, ADR-014 quote substitution `ExecutionEngine.mqh:909-931`, SNIPER cancels, manual deletion).

**Mechanism:** A layer's `lot_size`/`remaining_entry_volume` are initialized to the order's *full* initial volume. If the entry order is cancelled after a partial fill, no code path ever reduces these fields — there is no handler for order cancellation and no comparison of any volume field against broker `POSITION_VOLUME`, anywhere. The layer is stuck with `remaining_entry_volume > VOLUME_EPSILON` forever: `remaining_exit_volume` never arms, `AuditExitLimits` skips it ("entry not complete"), so **the real partial position never gets an exit order**, and since `inst_inv_size > 0` suppresses Layer-0 quoting, the slot is also frozen. This is the purest form of the audited pattern: state assumes "orders always fully fill before they die."

**Concrete risk scenario:** Layer-0 bid 0.03 lots fills 0.01; Layer-0 fill triggers ADR-014 quote substitution which cancels the opposing quote — fine — but if instead the *partially filled* order itself is cancelled (Tier 3 order sweep on a day the sweep succeeds, or manual), the EA now holds 0.01 lots with no exit, no add-next, no breaker awareness beyond P&L, indefinitely.

**Severity: MODERATE-HIGH.** Also note B6 shares this root: after an ADR-074 sweep, a *partially* IOC-closed stranded position is retained with its original volume fields; on reattach the re-armed exit is sized to the stale `remaining_exit_volume` → over-close → naked opposite position. (Whether FTMO partially fills IOC market orders at these sizes is an open broker-behavior question — flagged, not asserted.)

### B6 — MODERATE: soft-halt states leave the book armed while the brain is off

**File/function:** `ea/ExecutionEngine.mqh:1487-1491` (`OnTradeTransaction`: "fired while EA is halted. Event **dropped**"), in combination with every `g_halted = true` path that does *not* detach or cancel orders: alien fill (`ExecutionEngine.mqh:694`), unrecognised symbol (`:742`), ADR-072 same-direction CloseBy exhaustion (`FXMatrix.mq5:1126`), CloseBy symbol mismatch (`:1181`), orphan halt at OnInit (`StateEngine.mqh:623`).

**Mechanism:** A soft halt stops all management logic but cancels nothing — every GTC exit limit and entry limit stays live — while simultaneously guaranteeing that any fill occurring during the halt is *dropped unprocessed*. Divergence between broker and inventory is therefore not just possible during a halt; it is the certain result of any fill during one. Detection is deferred to the next manual reattach (`CheckForOrphans`), which then halts again, compounding triage.

**Concrete risk scenario:** ADR-072 exhaustion soft-halts MM at 03:00 with 8 layers of resting exits. Overnight, two exits fill (each opening a `+2` hedge position needing a CloseBy that will never be queued). Operator reattaches at 08:00: orphan halt, book in a three-way tangle that never appears in any state file.

**Severity: MODERATE.** Exposure is partially bounded (an exit fill delta-neutralizes its layer) but margin grows, CloseBys are lost, and the halt state is silently worse than it looks.

### B7 — MODERATE: `g_pending_bid/offer` have no liveness validation, and the code that would repair stale quotes is unreachable

**File/function:** `ea/FXMatrix.mq5:366` — `if (inst_inv_size > 0 || inst_bid > 0 || inst_offer > 0) continue;` — versus everything after it in the per-instrument loop.

**Mechanism:** Two consequences, both statically verifiable. (a) The F3 liveness fix (dead-order detection via `HistoryOrderSelect`) was applied to `g_add_next` only; `g_pending_bid/offer` restored from JSON, or left nonzero after any missed cancel, are trusted blindly. A nonzero ticket referencing a dead order makes line 366 `continue` forever → **that slot silently never quotes again**, with no log and no self-heal. (b) Because line 366 short-circuits whenever any pending ticket is nonzero, all downstream code predicated on `inst_bid > 0 / inst_offer > 0 / active_ticket > 0` — the MM spatial deadband, MM stale-quote cancels (lines 414-474), the SNIPER opposite-side flip cancel, the SNIPER below-threshold cancel, and the **ADR-051 SNIPER expiry (lines 585-615)** — is unreachable. On this reading, **ADR-051 expiry is dead code and unfilled SNIPER limits can never expire via the path written for them.** This should be checked against production logs: if any `"[ADR-051] SNIPER order expired"` line has ever been emitted live, my static reading is wrong and I'd want to know why.

**Severity: MODERATE** (in-class: state assumed live without verification; plus a functional regression on ADR-051 worth verifying independently).

### B8 — LOW-MODERATE: `CancelAllPendingEntries()` zeroes all pending-ticket state regardless of cancel success

**File/function:** `ea/FXMatrix.mq5:955-970`.

**Mechanism:** Failed cancels are logged, but the trailing loop unconditionally zeroes all six `g_pending_bid/offer` slots anyway — assumed outcome without verification. A cancel that failed (or a ticket skipped by the exact-match `ORDER_MAGIC == EA_MAGIC` filter at line 938 — another single-magic filter, though defensible given the function's "entries" scope *when the caller also sweeps +1/+2, which only the ADR-074 path does*) leaves a live untracked order. Mitigated: if it later fills, `HandleEntryFill` will process and track it. Mostly relevant as reattach-time zombie orders.

### B9 — LOW-MODERATE: `DetectInventoryCorruption()` — ADR-054's "fatal" checks are defined but never called

**File/function:** `ea/ExecutionEngine.mqh:1461-1483`. Grep confirms a single occurrence: the definition. Its own header comment says "Called from HandleExitFill after a successful ticket match" — it is not. The volume-mismatch-on-owned-fill and inventory-overflow hard halts documented in ADR-054 do not exist at runtime. Whichever way the team resolves it (wire it in or delete it), right now the documentation asserts a safety net that isn't there — the same doc-vs-code drift genus as the incident's "the F4 lesson exists in a comment."

### B10 — LOW: `CloseAllPositions()` and `CancelAllPending()` retained as dead code with the known-bad filters

**File/function:** `ea/FXMatrix.mq5:884-925`. No callers remain (grep-verified). ADR-074 acknowledges the deferral. Risk is purely prospective: any future caller reintroduces Cause 1 verbatim, and the function *looks* like the obvious thing to call. Given this exact function already burned the project once, leaving it loaded is a poor trade for the cost of deleting it.

### B11 — LOW: `g_closeby_queue` is not persisted

**Mechanism:** `HandleExitFill` can remove a layer (at `remaining_exit_volume ≤ ε`) while its CloseBy pair is still open on the broker, pending `ProcessCloseByQueue()`. A crash/VPS reboot in that window loses the queue; both legs become untracked. Fails relatively safe — `CheckForOrphans` halts at next `OnInit` — but it is a real broker-vs-state divergence window, and the halt it produces will look mysterious.

### B12 — LOW: `HandleEntryFill` MaxLayers guard silently orphans a real fill

**File/function:** `ea/ExecutionEngine.mqh:679-683.` A fill arriving when `inv_size >= MaxLayers` logs a warning and `return`s — the broker position exists with EA magic but is never entered into inventory: an instant orphan, undetected until next `OnInit`. Hard to reach (add-next placement is capacity-gated), but reachable via config change (`MaxLayers` lowered between sessions with orders resting) — an unverified-assumption path, in-class, low probability.

**Clean bills of health, for completeness:** `CheckForOrphans()` (all three magics, ADR-054 transient re-check — sound); `CheckDirectionConsistency()` (verify-before-act, correct enum normalization); `ExecuteEmergencySystemSweep()`/`PurgeClosedLayers()` (verify-before-purge, fails toward retaining state — the right direction); `CarryEngine`/`RunDailyRolloverReconciliation` (skip-on-failure throughout, struct synced only after successful `OrderSend`, exit modifies driven off inventory not blind order scans); `RunSpreadCooldownReconciliation` ADR-060 `magic != EA_MAGIC` restriction (intentional and correct per the 2026-06-30 grid-collapse lesson); `TelemetryEngine` (read-only consumer, the `g_inventory_X[0]` access is guarded by the `layer_count == 0` early return); ADR-049 `OnTradeTransaction` magic gate (correctly enumerates all three offsets; the deliberate magic-0 pass-through is what surfaces B3, but the gate itself is right).

---

## Closing summary

**Does this codebase have other landmines of this class? Yes — and the largest one is in the breaker most likely to fire next.** The incident's two causes (narrow magic filter; unverified state clear) are not isolated: they recur in `ClosePodPositions()` (B1/B2 — both causes, plus a probable close-that-doesn't-close), in the absence of any running-session broker↔inventory reconciliation (B3), in partial-fill volume handling (B4/B5), and in the soft-halt/event-drop combination (B6). The pattern's root is architectural, and the git history proves it: safety invariants ("all three magics," "verify before mutating," "orders can die partially filled") live as comments and per-site idioms rather than as shared enforced code, so every new or edited call site must independently re-remember them — and on 2026-06-19 and 2026-06-29 the record shows edits touching the exact lines that half-embodied the lesson while missing it one call away. ADR-074's consolidation into one shared sweep function is precisely the right structural antidote; it has been applied to one of roughly six sites that need it.

**Is it safe to resume live trading once ADR-074 is deployed and verified?** My honest read: **not yet — ADR-074 is necessary but not sufficient, and two items should block resumption:**

1. **B1/B2 (`ClosePodPositions()`) must be fixed first.** Tier 1 fires at 3% *per-pod* drawdown — statistically far ahead of Tier 3 in the queue — and its current failure mode is worse than the incident's: unverified state wipe, probable non-close (missing `req.position`) that doubles margin into a locked hedge, and the EA *continues trading* on repopulated garbage inventory rather than detaching. Deploying ADR-074 while leaving this in place fixes the path that just failed and leaves an equal-or-worse copy of the same bug armed in front of it. ADR-074's own "negative space" section defers exactly this; that deferral should not survive contact with a live-resumption decision.
2. **B3 needs at minimum an operational control before resumption:** a written rule that no manual position intervention happens on a symbol while an instance is attached (detach first, flatten, reattach), until a runtime liveness-reconciliation exists. The team manually flattened a book this week; the current code turns that exact action, performed with an EA attached, into a naked-position generator.

Additionally, before resumption I would want (not blocking, but soon): confirmation of the ADR-074 sweep under a deliberately triggered controlled drawdown on demo — the request itself notes it has never been exercised against a real event, and the incident's core lesson is that this class of code cannot be trusted on review alone; the 11-vs-12 stranded-position arithmetic reconciled from broker history (A.3.5); and a decision on B7's ADR-051 dead-code question, verified against production logs. B4/B5/B8-B12 can go through the normal pipeline on ordinary priority.

One process observation the team has effectively already made, stated plainly: every finding above except B4 was *findable* on 2026-06-20, the day the F4 comment was written — the comment itself is a complete specification of the bug class. The gap was never knowledge; it was that the knowledge had no mechanism to propagate. Consolidation into shared, singly-audited functions (as ADR-074 began) is the fix for the class, not just the instance.
