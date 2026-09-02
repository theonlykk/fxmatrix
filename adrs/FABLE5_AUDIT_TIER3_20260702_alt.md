The Fable 5 audit is complete. Here is the full report, verbatim:

---
FXMatrix V3 — Independent Audit Report: Tier 3 Incident (2026-07-02) + Bug-Class Sweep

Auditor: Claude Fable 5 (Claude Code, direct repo access, read-only)
Repo sanity check: Confirmed fxmatrix — ea/FXMatrix.mq5 and docs/architecture/ADR-074.md both present; MQL5 EA source tree, not the pipshed Flask repo.
Test baseline: python temp/run_tests_0_41.py run read-only — 279/279 subtests PASS, including Test 51 (ADR-074 poll mirror). Matches the stated baseline.
No files were created, modified, or deleted in the repository. No mutating git commands were run.

---
Part A — Independent incident analysis

A.1 The stated root causes are confirmed, with one correction of emphasis

I recovered the pre-incident code via git show 51a9575 (the ADR-074 diff) and traced both trigger paths. Both stated causes are real and sufficient to produce exactly what was observed:

- Cause 1 confirmed. Pre-074 CloseAllPositions() (ea/FXMatrix.mq5:884-908, still present as dead code) filters PositionGetInteger(POSITION_MAGIC) != (long)EA_MAGIC → continue. Exact match only. Every EA_MAGIC+1 (add-next grid) and EA_MAGIC+2 (hedge) position was never selected — no close was ever sent for them.
- Cause 2 confirmed. Both Tier 3 trigger blocks then ran ArrayResize(g_inventory_0/1/2, 0) + SaveAllInventoryState() unconditionally, with no PositionSelectByTicket verification of anything. The 5/7/3 → 0/0/0 state-file transition in under 2 seconds is exactly this line pair executing.
- The duplication is confirmed. The 4%-daily block and the legacy absolute-floor block were byte-for-byte structural copies of the same sweep (visible in the ADR-074 diff), so the bug existed twice from copy-paste.

Correction of emphasis: the account frames Cause 1 as "a lesson learned in CheckForOrphans() and never propagated." Git history shows the true origin is slightly different and more instructive: CloseAllPositions() was correct when written — the magic-offset scheme didn't exist yet — and became wrong when ADR-015 introduced the offsets, because that migration never swept all POSITION_MAGIC consumers. The bug is a semantic-migration gap, not an originally-wrong function. That distinction matters for Part B, because it predicts where else to look: every consumer of POSITION_MAGIC/ORDER_MAGIC written before 2026-06-16, or written since by copying pre-offset patterns.

A.2 Git-history dating — the evidence settles the two hypotheses decisively

┌────────────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────────┐
│    Date    │ Commit  │                                           Event                                           │
├────────────┼─────────┼──────────────────────────────────────────────────────────────┤
│ 2026-06-07 │ 1b4f026 │ CloseAllPositions() written with single-magic filter — correct at the time (one magic     │
│            │         │ number existed)                                              │
├────────────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────┤
│ 2026-06-13 │ e5c3a6f │ ClosePodPositions()circuit breaker                           │
├────────────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────┤
│ 2026-06-14 │ 402ff29 │ ADR-012: FTMO equitpath) wired to CloseAllPositions()        │
├────────────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────┤
│ 2026-06-16 │ 21a9144 │ ADR-015 introduces AllPositions() silently becomes wrong     │
│            │         │ here                                                                                      │
├────────────┼─────────┼──────────────────────────────────────────────────────────────┤
│            │         │ F1: the same Tier-3 sweep block gets the three-magic fix for order cancels, with a        │
│ 2026-06-19 │ 5bcd31a │ comment naming the  below the still-unfixed                  │
│            │         │ CloseAllPositions() call. The same commit introduces the unconditional ArrayResize(...,0) │
│            │         │  inventory clear (C                                          │
├────────────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────┤
│ 2026-06-20 │ d464497 │ F4: CheckForOrphansthe comment quoted in the audit request)  │
├────────────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────┤
│            │         │ ADR-055 rewrites thse 3.A and copy-pastes the half-fixed     │
│ 2026-06-29 │ 1913305 │ sweep into the second (absolute-floor) trigger — nine days after F4, actively re-copying  │
│            │         │ the "+1/+2 must be  for orders while leaving the position    │
│            │         │ close at exact-match                                                                      │
├────────────┼─────────┼──────────────────────────────────────────────────────────────┤
│ 2026-07-02 │ 51a9575 │ ADR-074 fix, ~2h after the incident                                                       │  └────────────┴─────────┴──────────────────────────────────────────────────────────────┘
                                                                                                                      Verdict: hypothesis 1 ("lesson learned and tis supported, in its strongest possible form. This is not a case of Tier 3 predating the lesson. The Tier 3 sweep block was substantially rewritten twice after the three-magic lesson existed (June 19 and Junehe +1/+2 enumeration was correctlyapplied/re-applied to the order-cancel half of the block while the position-close half, one function call away, was
left at exact match. The lesson was literallof the code being edited. The failure modeis: the magic-offset invariant lived in comments at two call sites rather than in one shared filter function, so each
edit had to independently remember it — and  did.

A.3 Extensions — why this survived undetectent logging" point)

1. ADR-055 converted a noisy, self-retrying t one. Pre-055, the nuclear failsafe setg_halted = true but did not call ExpertRemove(), and (per the F1 fix) CheckCircuitBreakers() runs even when halted —
so the condition would have re-fired and re-, retrying the (still-incomplete) close andspamming the journal. Anyone watching would have noticed. ADR-055's ExpertRemove() made the failure fire exactly once,
wipe state, and vanish. A correctness-neutraegraded observability of the latent bug.
2. By construction, no feedback loop ever verified sweep closes. The pre-074 close requests set no req.magic (deal
magic 0), and OnTradeTransaction's DEAL_ENTREA_MAGIC+2 — every close deal from the sweepwas dropped as "unmanaged magic." Even if the sweep had partially worked, nothing in the event pipeline would have
reconciled the outcome. The system's only porphans) runs once at OnInit, which neverhappens after ExpertRemove() until manual reattach.
3. The Python test suite had zero Tier 3 covst-incident with ADR-074). The suite mirrorsmath/state logic, not broker-interaction paths, so this entire class is structurally outside its reach.
4. Tier 3 had never fired live before. The mhe system was also the least-exercised — theclassic emergency-code problem, correctly acknowledged in the audit request.                                       5. One small arithmetic loose end worth recoy: MM had 15 layers (5/7/3); exact-matchclose should have caught at most 3 Layer-0 positions, predicting 12 stranded from MM alone — the operator found 11 total. Plausible explanations (a layer alrealight, count including/excluding SNIPERpositions), but it has not been positively reconciled and would be cheap to confirm from the broker's deal history.the 11 cannot be made to add up, something at fully understood.
                                                                                                                   A.4 ADR-074 itself — verified against source
                                                                                                                   The implemented ExecuteEmergencySystemSweep() matches the ADR: broker-first scan, triadsymbols × all three magics, req.position set correctly, batched 5×50ms poll, critical alerts for stranded tickets, selective purge via PurgeClosedLayers(). A nttach, if equity is still under the(persisted) daily floor, Tier 3 re-fires on the first tick and the sweep retries stranded closes — a natural retry loop.
                                                                                                                   Two notes:
1. ADR-074's resumption attribution is imprecise. The doc says stranded layers resume via "ADR-040 OnInit          reconciliation (g_reconciliation_pending exires for sentinel exit_price_fixed < 0;stranded layers carry real exit prices. The mechanism that actually re-arms them is AuditExitLimits() (every tick):its F3 logic detects the sweep-cancelled exiem, and re-places. The safety outcome is thesame, but the doc credits the wrong mechanism — worth fixing so nobody later "cleans up" AuditExitLimits believing ADR-040 covers this.
2. The sweep's close requests still set no req.magic (deal magic 0). Functionally harmless (verification is by ticknot magic), but it degrades forensic attribuans sweep-close deals sail through everyinstance's ADR-049 gate (they are ignored anyway as non-+2 OUT deals). Cosmetic; noted for completeness.           
---                                                                                                                Part B — Codebase audit for the same bug cla
                                                                                                                   Calibration: today's incident = critical (em the whole book and wipes state). Findingsordered by severity.                                                                                               
---                                                                                                                B1 — CRITICAL: ClosePodPositions() (Tier 1) a hedging account its "closes" open newopposite positions                                                                                                 
File/function: ea/FXMatrix.mq5:725-787, ClosePodPositions(); close request built at lines 741-754. Written in e5c3a(2026-06-13), untouched since (confirmed viared by ADR-074's "negative space" section.
                                                                                                                   Mechanism: The close request sets action=TRAe, magic, type, price, type_filling,deviation, comment — but never req.position. On an MT5 hedging account (which this is — the system's premise), a   TRADE_ACTION_DEAL without a position ticket pens a new, independent position in theopposite direction. This is documented MT5 behavior, and the codebase itself corroborates that req.position is     required: the only three close paths that wositions() (line 893), ProcessCloseByQueue()(line 1188), ExecuteEmergencySystemSweep() (StateEngine line 494) — all set it. ClosePodPositions() is the sole clopath that doesn't.
                                                                                                                   Concrete risk scenario: A single pod bleeds  balance — by far the most probable breakerto fire on an ordinary bad day; note the comment at Globals.mqh:45 says "2% per pod" while the value is 0.03 —     separate small doc bug). Tier 1 fires. For eopposite market position opens (marginroughly doubles, P&L locks), the original positions remain open. Then the function unconditionally runs            ArrayResize(g_inventory_X, 0) + SaveAllInvenCause 2 verbatim, no verification) and —unlike Tier 3 — the EA keeps running (no halt, no detach). Cascade: the six new market fills come back as          DEAL_ENTRY_IN with magic=EA_MAGIC → HandleEnt-cleared inventory with six boguswrong-direction layers, computes exits for them, places exit limits, and potentially starts layering off them. The original six positions are unmanaged orphansch. GetPodUnrealizedPnL() now reads thelocked hedge (~0), so the breaker never re-fires while the loss is frozen open and the machine trades on top of it.

Severity: CRITICAL. Same class as the incident, in the breaker most likely to fire next, with a worse failure mode (EA
continues trading on corrupted state insteade audit rules: theno-req.position-opens-a-new-position behavior is asserted from documented MT5 semantics plus the codebase's own
internal inconsistency, not from a live repr a strategy-tester/demo experiment beforeanyone stakes anything on the exact failure shape. Either way the field is missing and the state-clear is unverified.

B2 — HIGH: ClosePodPositions() order-cancel loop has the exact Cause-1 magic scope gap

File/function: ea/FXMatrix.mq5:762-775 (same function as B1).

Mechanism: The pending-order cancel filters OrderGetInteger(ORDER_MAGIC) != (long)EA_MAGIC → continue. Exact match
only — the amputated instrument's add-next o exit limits (EA_MAGIC+2) are nevercancelled. Immediately after, g_add_next[instrument] = 0 and the inventory clear discard all knowledge of them —
assumed-outcome state mutation on top of a t of the incident pattern, in one function,still live post-ADR-074.

Concrete risk scenario: Even in the charitable case where B1's closes worked, the pod's GTC exit limits stay resting
on the book with no owner. Hours later one f hedge account → HandleExitFill() finds nomatching ticket (inventory was cleared) → HandleUnmatchedFill() fallback fails (volume/time window) → ADR-054
downgrades to "foreign noise — ignored" → a position accumulates while the EA continuesquoting normally. Discovered only at the next reattach.

Severity: HIGH. Identical structure to Cause 1 + Cause 2; slightly lower than B1 only because the exposure builds
through stale GTC orders rather than immedia

B3 — HIGH: positions closed outside the EA aning; their exit limits stay armed

File/function: ea/ExecutionEngine.mqh:1554-1ENTRY_OUT handler — only EA_MAGIC+2 deals are processed; everything else, including operator-manual closes with deal magic 0, is ignored). No periodic
position-liveness purge exists anywhere: Purside the Tier 3 sweep; CheckForOrphans() only at OnInit; CheckDirectionConsistency() (ADR-071) explicitly skips unselectable tickets.

Mechanism: If a human closes an EA-owned position in the MT5 terminal while an instance is attached, inventory is
never updated: the layer persists, its positosition, and — critically — its GTC exitlimit remains live on the book. If that exit limit later fills, it opens a fresh position (+2); HandleExitFill()
matches the ticket, decrements remaining_exiy pairing the new position against the deadposition_ticket; ProcessCloseByQueue() then hits HistorySelectByPosition(ticket1) = true → "already closed in history.
Discarding task gracefully" (FXMatrix.mq5:11s left open, untracked, unmanaged.

Concrete risk scenario: This is not hypotheterational posture the team is in right now.Post-incident triage involved manually flattening a book. The next time an operator manually closes positions while
any instance is still attached (a natural trple), this cascade fires. The system'simplicit assumption — only the EA ever closes EA positions — is enforced nowhere and was already violated this week.

Severity: HIGH, elevated by current operational reality.

B4 — HIGH (mechanism) / MODERATE (likelihood): partial fill of an exit limit de-tracks the still-live order and
triggers duplicate exit placement

File/function: ea/ExecutionEngine.mqh:1075-1ting with AuditExitLimits()(FXMatrix.mq5:990-1083).

Mechanism: On any matched exit fill — including a partial one — the code decrements remaining_exit_volume and then
unconditionally ArrayRemoves the exit tickettially filled limit remains live on thebroker (ORDER_STATE_PARTIAL) for its residual volume. Next tick, AuditExitLimits() sees exit_tickets empty +
remaining_exit_volume > 0 and places a secontill-resting original already covers. If both fill: over-close → a new opposite naked position (+2 fill with no matching ticket → ADR-054 "foreign noise") and
remaining_exit_volume driven negative, so thray position lives on. State was mutated toreflect the assumed outcome "one fill event = order gone," never verified against ORDER_STATE. Note the codebase
already knows better elsewhere — the F3 logiadd-next check explicitly distinguishORDER_STATE_PARTIAL; HandleExitFill never got that lesson (same non-propagation signature as the incident).

Concrete risk scenario: A 0.03-lot exit limit on GBPUSD during a news spike fills 0.01/0.02 across two deals. Between
deal 1 and deal 2, AuditExitLimits fires (ita duplicate 0.02 exit. Both residuals fill →book is short 0.02 naked, invisible to inventory.

Severity: mechanism HIGH; probability tempered by micro-lot sizes making broker partials rare — but the incident
taught exactly what "rare" is worth on unver

B5 — MODERATE-HIGH: cancelled partially-fillorrupt layer volume state; no volume field is ever reconciled against the broker

File/function: ea/ExecutionEngine.mqh:705-713, 815-817, 937-960 (HandleEntryFill: lot_size = ORDER_VOLUME_INITIAL;
remaining_entry_volume decremented only by fhat cancels entry orders (Tier 3 sweep orderloop, CancelAllPendingEntries(), ADR-014 quote substitution ExecutionEngine.mqh:909-931, SNIPER cancels, manual
deletion).

Mechanism: A layer's lot_size/remaining_entrhe order's full initial volume. If the entryorder is cancelled after a partial fill, no code path ever reduces these fields — there is no handler for order
cancellation and no comparison of any volumeN_VOLUME, anywhere. The layer is stuck withremaining_entry_volume > VOLUME_EPSILON forever: remaining_exit_volume never arms, AuditExitLimits skips it ("entry
not complete"), so the real partial positiond since inst_inv_size > 0 suppresses Layer-0quoting, the slot is also frozen. This is the purest form of the audited pattern: state assumes "orders always fully
fill before they die."

Concrete risk scenario: Layer-0 bid 0.03 lotiggers ADR-014 quote substitution whichcancels the opposing quote — fine — but if instead the partially filled order itself is cancelled (Tier 3 order sweep
on a day the sweep succeeds, or manual), theno exit, no add-next, no breaker awarenessbeyond P&L, indefinitely.

Severity: MODERATE-HIGH. Also note B6 shares this root: after an ADR-074 sweep, a partially IOC-closed stranded
position is retained with its original volumarmed exit is sized to the staleremaining_exit_volume → over-close → naked opposite position. (Whether FTMO partially fills IOC market orders at these
sizes is an open broker-behavior question —

B6 — MODERATE: soft-halt states leave the boff

File/function: ea/ExecutionEngine.mqh:1487-1ed while EA is halted. Event dropped"), incombination with every g_halted = true path that does not detach or cancel orders: alien fill
(ExecutionEngine.mqh:694), unrecognised symbtion CloseBy exhaustion (FXMatrix.mq5:1126),CloseBy symbol mismatch (:1181), orphan halt at OnInit (StateEngine.mqh:623).

Mechanism: A soft halt stops all management logic but cancels nothing — every GTC exit limit and entry limit stays
live — while simultaneously guaranteeing thahe halt is dropped unprocessed. Divergencebetween broker and inventory is therefore not just possible during a halt; it is the certain result of any fill during
one. Detection is deferred to the next manua which then halts again, compounding triage.

Concrete risk scenario: ADR-072 exhaustion slayers of resting exits. Overnight, two exits fill (each opening a +2 hedge position needing a CloseBy that will never be queued). Operator reattaches at 08:00:
orphan halt, book in a three-way tangle thatile.

Severity: MODERATE. Exposure is partially botralizes its layer) but margin grows,CloseBys are lost, and the halt state is silently worse than it looks.

B7 — MODERATE: g_pending_bid/offer have no liveness validation, and the code that would repair stale quotes is
unreachable

File/function: ea/FXMatrix.mq5:366 — if (ins0 || inst_offer > 0) continue; — versuseverything after it in the per-instrument loop.

Mechanism: Two consequences, both statically verifiable. (a) The F3 liveness fix (dead-order detection via
HistoryOrderSelect) was applied to g_add_nexestored from JSON, or left nonzero after anymissed cancel, are trusted blindly. A nonzero ticket referencing a dead order makes line 366 continue forever → that
slot silently never quotes again, with no lose line 366 short-circuits whenever anypending ticket is nonzero, all downstream code predicated on inst_bid > 0 / inst_offer > 0 / active_ticket > 0 — the
MM spatial deadband, MM stale-quote cancels pposite-side flip cancel, the SNIPERbelow-threshold cancel, and the ADR-051 SNIPER expiry (lines 585-615) — is unreachable. On this reading, ADR-051
expiry is dead code and unfilled SNIPER limiath written for them. This should be checkedagainst production logs: if any "[ADR-051] SNIPER order expired" line has ever been emitted live, my static reading is
wrong and I'd want to know why.

Severity: MODERATE (in-class: state assumed us a functional regression on ADR-051 worthverifying independently).

B8 — LOW-MODERATE: CancelAllPendingEntries() zeroes all pending-ticket state regardless of cancel success

File/function: ea/FXMatrix.mq5:955-970.

Mechanism: Failed cancels are logged, but the trailing loop unconditionally zeroes all six g_pending_bid/offer slots
anyway — assumed outcome without verificatio ticket skipped by the exact-matchORDER_MAGIC == EA_MAGIC filter at line 938 — another single-magic filter, though defensible given the function's
"entries" scope when the caller also sweeps  path does) leaves a live untracked order.Mitigated: if it later fills, HandleEntryFill will process and track it. Mostly relevant as reattach-time zombie
orders.

B9 — LOW-MODERATE: DetectInventoryCorruption are defined but never called

File/function: ea/ExecutionEngine.mqh:1461-1ccurrence: the definition. Its own headercomment says "Called from HandleExitFill after a successful ticket match" — it is not. The
volume-mismatch-on-owned-fill and inventory-d in ADR-054 do not exist at runtime.Whichever way the team resolves it (wire it in or delete it), right now the documentation asserts a safety net that
isn't there — the same doc-vs-code drift genlesson exists in a comment."

B10 — LOW: CloseAllPositions() and CancelAllde with the known-bad filters

File/function: ea/FXMatrix.mq5:884-925. No c. ADR-074 acknowledges the deferral. Risk ispurely prospective: any future caller reintroduces Cause 1 verbatim, and the function looks like the obvious thing to
call. Given this exact function already burnit loaded is a poor trade for the cost ofdeleting it.

B11 — LOW: g_closeby_queue is not persisted

Mechanism: HandleExitFill can remove a layer (at remaining_exit_volume ≤ ε) while its CloseBy pair is still open on
the broker, pending ProcessCloseByQueue(). Adow loses the queue; both legs becomeuntracked. Fails relatively safe — CheckForOrphans halts at next OnInit — but it is a real broker-vs-state divergence
window, and the halt it produces will look m

B12 — LOW: HandleEntryFill MaxLayers guard s

File/function: ea/ExecutionEngine.mqh:679-68ize >= MaxLayers logs a warning and returns — the broker position exists with EA magic but is never entered into inventory: an instant orphan, undetected until
next OnInit. Hard to reach (add-next placemeachable via config change (MaxLayers loweredbetween sessions with orders resting) — an unverified-assumption path, in-class, low probability.

Clean bills of health, for completeness: CheckForOrphans() (all three magics, ADR-054 transient re-check — sound);
CheckDirectionConsistency() (verify-before-an);ExecuteEmergencySystemSweep()/PurgeClosedLayers() (verify-before-purge, fails toward retaining state — the right
direction); CarryEngine/RunDailyRolloverRecohroughout, struct synced only aftersuccessful OrderSend, exit modifies driven off inventory not blind order scans); RunSpreadCooldownReconciliation
ADR-060 magic != EA_MAGIC restriction (inten26-06-30 grid-collapse lesson);TelemetryEngine (read-only consumer, the g_inventory_X[0] access is guarded by the layer_count == 0 early return);
ADR-049 OnTradeTransaction magic gate (corresets; the deliberate magic-0 pass-through iswhat surfaces B3, but the gate itself is right).

---
Closing summary

Does this codebase have other landmines of test one is in the breaker most likely to fire next. The incident's two causes (narrow magic filter; unverified state clear) are not isolated: they recur in
ClosePodPositions() (B1/B2 — both causes, pln't-close), in the absence of anyrunning-session broker↔inventory reconciliation (B3), in partial-fill volume handling (B4/B5), and in the
soft-halt/event-drop combination (B6). The pl, and the git history proves it: safetyinvariants ("all three magics," "verify before mutating," "orders can die partially filled") live as comments and
per-site idioms rather than as shared enforced call site must independently re-rememberthem — and on 2026-06-19 and 2026-06-29 the record shows edits touching the exact lines that half-embodied the lesson
while missing it one call away. ADR-074's coweep function is precisely the rightstructural antidote; it has been applied to one of roughly six sites that need it.

Is it safe to resume live trading once ADR-074 is deployed and verified? My honest read: not yet — ADR-074 is
necessary but not sufficient, and two items

1. B1/B2 (ClosePodPositions()) must be fixedr-pod drawdown — statistically far ahead ofTier 3 in the queue — and its current failure mode is worse than the incident's: unverified state wipe, probable
non-close (missing req.position) that double and the EA continues trading on repopulatedgarbage inventory rather than detaching. Deploying ADR-074 while leaving this in place fixes the path that just failed
and leaves an equal-or-worse copy of the samDR-074's own "negative space" section defers exactly this; that deferral should not survive contact with a live-resumption decision.
2. B3 needs at minimum an operational contron rule that no manual position interventionhappens on a symbol while an instance is attached (detach first, flatten, reattach), until a runtime
liveness-reconciliation exists. The team maneek; the current code turns that exactaction, performed with an EA attached, into a naked-position generator.

Additionally, before resumption I would want (not blocking, but soon): confirmation of the ADR-074 sweep under a deliberately triggered controlled drawdown ootes it has never been exercised against areal event, and the incident's core lesson is that this class of code cannot be trusted on review alone; the 11-vs-stranded-position arithmetic reconciled froma decision on B7's ADR-051 dead-codequestion, verified against production logs. B4/B5/B8-B12 can go through the normal pipeline on ordinary priority.  
One process observation the team has effectively already made, stated plainly: every finding above except B4 was   findable on 2026-06-20, the day the F4 commeitself is a complete specification of the bug class. The gap was never knowledge; it was that the knowledge had no mechanism to propagate. Consolidation into    shared, singly-audited functions (as ADR-074ass, not just the instance.
                                                                                                                   ---
That's the complete report. The headline items if you want the shortest possible version: the incident analysis is confirmed with git-dated proof that the lessode was rewritten twice, and the audit's most urgent new finding is B1 — Tier 1's ClosePodPositions() likely doesn't close positions at all (missing req.position on a hedging account), wipes state unverified. The agent recommends B1/B2 block liveresumption alongside ADR-074 deployment. If you want follow-up questions answered against the evidence it gathered, I can send them back to the same agent with it