This message has a line count at the bottom.

# DeepSeek Phase 1 Response — Fill-Transition Race and Stale-State Defects

## Integrity gate

| Check | Result | Observed |
|-------|--------|----------|
| line 1 | PASS | `This message has a line count at the bottom.` |
| line 128 | PASS | `## Threats / questions (spend effort here)` |
| last line | PASS | `Line count: 210` |
| total lines | PASS | 210 |

---

## T-1 — PRIMARY: does P1 mask a real naked position or fail to absorb transients?

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** `OnTick` (`ea/fxgrind.mq5` 180–204) halts on `Grind_CheckBookInvariants` failure and returns before `Grind_OnTickEngine`; `Grind_OnTickEngine` (`ea/grind_engine.mqh` 967–976) is the only per-tick path that retries `Grind_TryPlaceExitForLayer` for layers with zero exit tickets; `Grind_OnTradeTransactionEngine` (`grind_engine.mqh` 993–994) ignores all `DEAL_ADD` when halted (G2); `Grind_CheckBookInvariants` (`grind_recon.mqh` 837–855) rebuilds from broker tickets only and flags I3 when `!Grind_ReconLayerHasExitCoverage` (`grind_recon.mqh` 150–152, 217–224).

**(a) Genuine naked in quarantine indefinitely**

**MINIMAL REPRO / MECHANISM:**
1. Short ENT fill processed: `Grind_HandleSideDealFill` appends layer (`grind_engine.mqh` 848) and calls `Grind_TryPlaceExitForLayer` (`851`); `Grind_PlaceLimit` / `Grind_OrderSendCounted` (`grind_api_counter.mqh` 74–76) returns failure — layer remains with `exit_order_ticket == 0` (`Grind_AppendLayer` 503).
2. Tick N: `Grind_CheckBookInvariants` sees broker position, no exit order → `I3_SHORT_NAKED`. Under P1, enter QUARANTINE; skip `Grind_OnTickEngine`.
3. Ticks N+1…N+k (k < GRACE_MS/ tick interval): no EXT `DEAL_ADD` will arrive; quarantine blocks the 967–976 exit-retry loop; I3 persists.
4. At T0+GRACE_MS with continuous I3: halt (as today). **Not infinite** if GRACE_MS fires on an unbroken I3 streak.

Flip-flop deferral: if the book alternates I3-fail / pass faster than GRACE_MS because a transient exit order or position leg appears then vanishes (CloseBy leg removal, G1 CloseBy before invariant), each PASS exits quarantine (`P1` spec) and resets the grace window. A **structurally naked** book (no exit, no exit position) cannot pass I3 (`grind_recon.mqh` 239–241) — flip-flop does not indefinitely mask true nakedness; it only defers halt on **transient** I3.

**SEVERITY:** fixable-within-design

**RECOMMENDED AMENDMENT:** In quarantine, still run the naked-exit retry slice of `Grind_OnTickEngine` (967–976) for the failing side only, or escalate to halt immediately when I3 persists and exit-retry fails twice. Do not rely on GRACE_MS alone to cover failed `OrderSend`.

**(b) Legitimate transition still halts despite P1**

**MINIMAL REPRO / MECHANISM (Incident B class, 91 ms fill-after-halt):**
1. Tick T: broker shows long entry position; EXT limit not yet in open orders (exit `OrderSend` still in flight inside a prior handler, G4) OR EXT `DEAL_ADD` not yet delivered to `OnTradeTransaction`.
2. `Grind_CheckBookInvariants` → `I3_LONG_NAKED`. Today: immediate halt (`fxgrind.mq5` 186–188); `Grind_OnTradeTransactionEngine` returns at 993 — exit fill at T+91 ms ignored (G2).
3. With P1 only: quarantine at T; at T+91 ms `OnTradeTransaction` fires → `Grind_HandleSideDealFill` EXT branch (`grind_engine.mqh` 855–871) sets `exit_position_ticket`, queues CloseBy; next invariant pass → I3 clears. **P1 absorbs this class.**

Counter-sequence (still halts): GRACE_MS = 3000 ms but a **blocking** `OrderSend` inside `Grind_TryPlaceExitForLayer` runs 35 s (within G4 journal range). While blocked, no ticks run; on resume, invariant may still see I3 if exit order not yet visible to `Grind_ReconCollectBrokerTickets`. If quarantine timer does not include blocked time, halt at 3 s wall-clock after first post-block tick despite legitimate in-flight exit.

**SEVERITY:** fixable-within-design

**RECOMMENDED AMENDMENT:** Prefer event-based release: exit quarantine on processing a `DEAL_ADD` whose `position_id` matches a quarantined I3 layer ticket, or on observing exit coverage in the broker snapshot — not wall-clock alone.

**(c) GRACE_MS vs event-based**

**VERDICT (sub-question):** AMEND toward event-based; GRACE_MS alone is a weak primitive for fill/invariant ordering (G4, Incident B).

**(d) Side-scoped vs whole-instance quarantine**

**VERDICT (sub-question):** AMEND — freeze `Grind_OnTickEngine` quoting/modifies only on the side that failed I3/I4; keep the opposite side and shared CloseBy queue (`fxgrind.mq5` 182) active to avoid unnecessary cap/straddle drift.

---

## T-2 — P2 history lookup

**VERDICT:** EXPLOIT-FOUND (bounded-stall risk); NO-EXPLOIT on (b)(c)

**LOAD-BEARING CLAIM:** `Grind_TryPlaceL0` (`grind_engine.mqh` 429–444) clears `l0_pending_ticket` when `!Grind_SelectOurOrder` and immediately places a new L0; same pattern in `Grind_EnsureAddNext` 581–583; `Grind_OnTickEngine` calls `Grind_TryPlaceL0` only when `Grind_SideDepth == 0` (952–955).

**(a) "Not yet in history" stall**

**MINIMAL REPRO / MECHANISM:**
1. Sell limit L0 #538969489 fills; order disappears from open orders before `TRADE_TRANSACTION_DEAL_ADD` is dispatched.
2. Tick: `Grind_SelectOurOrder(538969489)` false; P2 history lookup returns "not yet in history" → keep ticket, place nothing.
3. `Grind_SideDepth(short) == 0` (transaction not processed) → `Grind_TryPlaceL0` not called for new quote (952–955), but **opposite-side** recenter and add paths still run.
4. If history latency exceeds N ticks (terminal load, G4 backlog), short side posts no new L0 and does not clear the stale ticket — **one-sided quoting stall** until history or transaction arrives.

Without a max-wait and fallback (reconcile to position ticket or force transaction poll), stall is unbounded in principle.

**SEVERITY:** fixable-within-design

**RECOMMENDED AMENDMENT:** Cap "not in history" at K ticks or M ms; on expiry, query deal history by order ticket or infer FILLED if a matching `GRIND|…|L00|ENT` position exists in `Grind_ReconCollectBrokerTickets`.

**(b) Partial fills at 0.01 lots**

**MINIMAL REPRO / MECHANISM:** At `InpLots = 0.01`, partial state is broker-dependent and unlikely; if PARTIAL, P2 "keep ticket, place nothing" is correct until final fill or cancel. **NO-EXPLOIT** at stated lot size.

**(c) Modify-then-fill below limit (Incident A #538969489)**

**MINIMAL REPRO / MECHANISM:** Modify completes; fill at 1.16231 vs resting 1.16244 is a valid sell-limit fill (price improvement). Order history state is FILLED regardless of modify race. P2 classifies FILLED → keep ticket, wait for transaction — **does not mis-classify as cancelled**. **NO-EXPLOIT** for P2 classification; the duplicate-L0 defect remains G5 (pre-P2), not P2 history logic.

**SEVERITY:** cosmetic (for c)

**RECOMMENDED AMENDMENT:** None for (b)(c).

---

## T-3 — P3 and P4 under racing fills

**VERDICT:** EXPLOIT-FOUND

**LOAD-BEARING CLAIM:** ENT branch uses `Grind_FindLayerByIndex(side, c_layer)` then unconditional `exit_order_ticket` overwrite (`grind_engine.mqh` 848–851, 449–459); P4 proposes cancel of stray L0 when depth > 0; reconstruction adopts L0/add pending without depth guard (`grind_recon.mqh` 658–690); duplicate positions halt `I5_*_DUP` (`grind_recon.mqh` 578–580).

**(a) P4 cancel races stray fill**

**MINIMAL REPRO / MECHANISM (Incident A shaped):**
1. Tracker: one short layer L00 @ 1.16231; stray broker L0 #539592770 @ 1.16277 (G5 duplicate).
2. Tick: P4 engine rule issues cancel on #539592770; cancel `OrderSend` enters G4 block.
3. While blocked, price trades through 1.16277; fill generates `DEAL_ADD` ENT L00.
4. Transaction: append second L00 @ 1.16282; P3 routes exit via **new** position ticket — but first layer still holds exit order at 1.16161 (Incident A log).
5. Invariant → `I2_SHORT_EXIT_DUP` or `I5_SHORT_DUP` depending on book; P3 protective exit + halt may fire **after** wrong exit already sent from pre-P3 `FindLayerByIndex` conflation.

P4 cancel does not serialize before fill; race remains.

**SEVERITY:** fixable-within-design

**RECOMMENDED AMENDMENT:** P4 cancel must be idempotent with reconstruction: cancel stray pending **before** `Grind_OnTickEngine` quoting, and suppress new L0 placement while any cancel/fill for that side is in flight; pair with P3 exit-by-`position_id` before any second ENT is accepted.

**(b) Reattach after P3 halt**

**MINIMAL REPRO / MECHANISM:**
1. P3 places protective EXT for duplicate position, halts `I5_SHORT_DUP`.
2. Operator reattaches: `Grind_ReconstructState` (`grind_recon.mqh` 859–892) rebuilds from broker — two `S|L00|ENT` positions remain → `I5_SHORT_DUP` again (`578–580`), `g_grind_halted = true` (885).
3. CloseBy queue derivation (`Grind_DeriveCloseByQueueFromBook`, `grind_closeby.mqh` 268–290) does not remove duplicate entry legs.

**SEVERITY:** fixable-within-design (operational)

**RECOMMENDED AMENDMENT:** Document operator playbook: manual flatten duplicate L00 before reattach; long-term, recon should not halt-on-reattach if protective exit covers all duplicate entries (out of scope here — flag only).

---

## T-4 — legitimate states P4 would destroy

**VERDICT:** DESIGN-UNSAFE (P4 as written)

**LOAD-BEARING CLAIM:** `Grind_OnTickEngine` invokes `Grind_EnsureAddNext` when `add_pending_ticket != 0` even if `Grind_SideDepth == 0` (`grind_engine.mqh` 978–981); `Grind_EnsureAddNext` returns at 608–609 when `n <= 0` **after** the stale-add cleanup block (581–605); `Grind_TryRecenterOppositeL0` requires `Grind_SideDepth(opposite_side) == 0` (892–893) — opposite L0 with layers on the other side is intentional, not same-side; same-side L0 is only placed when depth == 0 (952–955).

**MINIMAL REPRO / MECHANISM:**
1. Short side unwinds to flat; orphaned `add_pending_ticket` remains (tracker not cleared).
2. Tick: `Grind_SideDepth(short) == 0` but `add_pending_short != 0` → `Grind_EnsureAddNext` entered (980–981).
3. Block 581–605: select add, parse label, cancel if stale — **legitimate cleanup path on empty side**.
4. P4 rule "depth 0 must not hold add pending; cancel it" in recon/engine **before** this logic runs would cancel blindly; if cancel races a valid in-flight add fill, same class as T-3(a).

Same-side L0 coexisting with layers is **not** a legitimate engine path (952–955); it is stale-state pathology (Incident A, G5/G7) — P4 target is valid for **same-side L0 + layers**.

**SEVERITY:** fixable-within-design

**RECOMMENDED AMENDMENT:** Scope P4 recon rule to "do not **adopt** L0 when depth > 0; cancel instead" (recon 658–674), and engine rule to cancel same-side L0 when `Grind_SideDepth > 0` — **do not** blanket-cancel all add pendings on depth 0; delegate empty-side orphan adds to existing `Grind_EnsureAddNext` stale-label path.

---

## T-5 — governance rule (invariant vs reconciler)

**VERDICT:** EXPLOIT-FOUND (process overlap)

**LOAD-BEARING CLAIM:** I3 is pure invariant on broker rebuild (`grind_recon.mqh` 217–241); I8 is reconciler on add-pending corruption (`156–175`); P1 quarantines on I3; P4 actively cancels pendings that would **cause** future I3/I5/I8.

**MINIMAL REPRO / MECHANISM:**
1. Stray L0 on side with depth (broker) → next invariant: `I5_SHORT_DUP` or naked exit mismatch, not I3 alone.
2. P4 cancel (reconciler) removes stray L0.
3. P1 quarantine on I3 from transient missing exit **while** P4 has not yet run on same tick → both mechanisms address "book looks wrong" with different timing; if P4 runs inside quarantine without invariant coupling, an I8 fail (`add_pending` ticket missing from orders, 174–175) could still halt immediately while I3 quarantines — **split brain**.

**SEVERITY:** fixable-within-design

**RECOMMENDED AMENDMENT:** On each tick: run P4 reconciler passes **before** `Grind_CheckBookInvariants`; map I8 to the same quarantine class as I3 (or make I8 self-healing via cancel + re-check); never quarantine and halt-on-recon-fail on the same condition in one tick without defined precedence.

---

## P1–P4 summary

| Proposal | Verdict | Reason |
|----------|---------|--------|
| P1 — Invariant quarantine | AMEND | Correct target (G2/Incident B) but must retain exit-retry, prefer event-based release over GRACE_MS alone, and scope by side. |
| P2 — Filled vs cancelled | AMEND | Fixes G5 root cause; requires bounded "not in history" with position-ticket fallback to avoid quoting stall. |
| P3 — Exit targets new position | KEEP | Directly fixes `FindLayerByIndex` wrong-layer exit (848–851) seen in Incident A; pair with halt on duplicate index. |
| P4 — Stray pending reconciliation | AMEND | Same-side L0+layers and recon non-adoption are necessary; blind cancel of all empty-side add pendings breaks `EnsureAddNext` cleanup (978–981). |

---

## Async OrderSend note (out of scope)

P1–P4 remain directionally sound if sends become asynchronous **only if** invariant/quarantine logic keys off broker book + processed transactions, not single-threaded handler completion; otherwise I3 transients multiply. No proposal assumes async sends today (G4).

---

## SELF-REVIEW OK

(a) T-1 through T-5 each have all five fields (VERDICT, LOAD-BEARING CLAIM, MINIMAL REPRO / MECHANISM, SEVERITY, RECOMMENDED AMENDMENT). (b) EXPLOIT-FOUND / DESIGN-UNSAFE items include ordered sequences. (c) OVERRIDE CHECK is the last content line before the bookend. (d) Exactly one file written: `prompts/deepseek_grind_fill_race_stale_state_response.md`.

OVERRIDE CHECK: No finding invalidates the premise — transient I3 from fill/invariant ordering (G2, G4) and stale pending re-quote (G5–G7) are confirmed in source; all findings are fixable within the quarantine + history-classification + targeted-recon design without abandoning fail-closed invariants.

Line count: 187
