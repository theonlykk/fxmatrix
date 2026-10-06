# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer user's requested audit. Need produce sections in order: GIVENS CHECK G1-G6, T-1..T-7 verdict evidence quotes smallest fix, PREMISE VERDICT, TEST GAPS. Must be exhaustive, cite file/function and quote line. No preamble. Need not use analysis. We have code. Need inspect.

We need verify givens. Need perhaps there are hidden bugs. Let's analyze deeply.

Important: user message says "This message has a line count at bottom" but no line numbers in attached files. We must cite file, function and quote one line/part. Need line count? At bottom of prompt says Line count: 143. Maybe final answer should include line count? Probably not? The prompt says "This message has a line count at the bottom" maybe asks? Actually initial says "This message has a line count at the bottom". At bottom of user content: Line count: 143. We should maybe mention? The requested output sections, line count? Hmm likely they expect line count? It says "This message has a line count at the bottom" perhaps part of challenge? Wait top of user: "This message has a line count at the bottom" then content. At bottom: "Line count: 143". Might be instruction to include line count? The assistant output maybe should also have line count? But OUTPUT doesn't mention. We can ignore or include? Need follow OUTPUT. Maybe final answer not need line count. But perhaps they want line count of message? Hmm.

Need audit.

Let's inspect code.

Key branch features. 

G1: With no list change and no duplicate, collector returns same entries, fields and order as before this branch, and no marker. Need verify. Collector now loops: walks while !stable. With no list change, positions_before==after and orders_before==after, stable true after first walk. count reset 0, array resize 0. Walk same positions from PositionsTotal()-1 down, same filters, append unique. Since no duplicate, all appended. Then orders. stable true. Raced false (dupes=0 walks=1), no marker. Fields: For positions uses (ulong)PositionGetInteger(POSITION_IDENTIFIER), magic g_grind_recon_magic, comment, price, kind POSITION. Before? Need know old collector lines? Spec says same fields. Is this same? The old code maybe appended ticket from PositionGetTicket? Wait audit trail A1: collector walks PositionsTotal()-1..0 (PositionGetTicket(i), stores POSITION_IDENTIFIER), then OrdersTotal... filters symbol and magic, appends. Current code for positions uses PositionGetTicket(i), then if ticket==0 or !PositionSelectByTicket(ticket) continue, then filters, then appends ticket = (ulong)PositionGetInteger(POSITION_IDENTIFIER). Is that same as old? It stores POSITION_IDENTIFIER for positions, yes. For orders, appends ticket = OrderGetTicket(i) and filters. Need check fields: magic passed g_grind_recon_magic not PositionGetInteger(POSITION_MAGIC). Old likely same? Spec V6 says same fields. Need verify no change. Use quote. Order: positions then orders, each top index down. Good. No marker. G1 likely VERIFIED.

Potential subtle: if no list change but duplicate? G1 says no duplicate. Good.

G2: callers unchanged and signatures. Grind_CheckBookInvariants calls Grind_ReconCollectBrokerTickets(tickets); Grind_ReconstructState same. Signatures of collector same `int Grind_ReconCollectBrokerTickets(GrindReconTicket &tickets[])`. Existing signatures unchanged. Need verify maybe Grind_RebuildBookFromTickets etc. Yes. VERIFIED.

G3: No ticket number reaches g_grind_recon_failure_json, heartbeat or archive marker: RECON_SCAN_RACE carries counts only, API markers carry limits only. Need verify. In failure JSON: Grind_ReconFailureCapture builds JSON with kind, comment, price, side_hint; no ticket. But wait it uses offending_comment maybe no ticket. It doesn't include ticket. The new log line has ticket but not JSON. Heartbeat embeds g_grind_recon_failure_json as recon_failure. So no ticket. RECON_SCAN_RACE detail = StringFormat("{\"dupes\":%d,\"walks\":%d,\"stable\":%s}",...) counts only, no tickets. Archive marker gets detail. API markers: API_LIMITS_INVALID detail includes input_entry_stop, input_soft_warn, using_entry_stop, using_soft_warn values; API_LIMITS_CONFIG entry_stop, soft_warn; API_LIMITS_MISMATCH limits. No ticket numbers. However, API_LIMITS_INVALID includes inputs, no tickets. Good. VERIFIED.

G4: With default inputs limits in force equal old constants (1000000/999000), and no path added returns INIT_FAILED, halts, quarantines or blocks entry for API limit. Check default inputs InpApiEntryStop=1000000, InpApiSoftWarn=999000. Grind_ApiLimitsApplyInputs valid -> sets globals to inputs? Wait spec says globals default to defines. In OnInit, `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);` This calls set to input values. So globals = inputs (1000000,999000) same as defines. If invalid, fallback to defines. No INIT_FAILED. K7 no return. On invalid, later API_LIMITS_INVALID WARN. No halt/quarantine. API limits affect Grind_ApiCounterEntryStopped and SoftWarnActive. Could entry block for API limit? With defaults 1000000, old constants. But G4 says no path added by this branch returns INIT_FAILED, halts, quarantines or blocks an entry for an API limit. The branch itself does not alter trading except globals. With default equal old, behavior same. Even invalid fallback to old. So no new block beyond existing API limit behavior. But note API limit functionality already blocks entries at stop. G4 says "no path added by this branch ... blocks an entry for an API limit." The new inputs can change g_grind_api_entry_stop, which can cause entry stop at lower value if valid. Is that "added by this branch"? It is a path added: setting input to 1900 will block entries. But G4 says "With default inputs ... and no path added by this branch returns INIT_FAILED, halts, quarantines or blocks an entry for an API limit." This might mean apart from normal API stop behavior, no new hard block. But the branch intentionally allows API limit to block entries (as before). The wording "for an API limit" maybe "for an API limit [value/mismatch]" i.e., no WARN/halt. Need interpret. G4 likely VERIFIED: invalid inputs don't fail; mismatch doesn't halt; defaults behave same. Quote K7 no return, K8 warnings only. Need mention if input valid lower, Grind_ApiCounterEntryStopped will block entries, but that's existing mechanism A11 and intended. The branch doesn't add a new block path beyond feeding existing guard. G4 as stated: no path added returns INIT_FAILED etc. Yes.

G5: Grind_IsQuarantinableReason unchanged. Check code lists I2_LONG_EXIT_DUP/SHORT, I3_NAKED, I4_ORPHAN, I6_*_EXIT_FILL_ADVERSE. Everything else false -> halt. AMBIGUOUS false. VERIFIED.

G6: Collector runs every tick while not halted through Grind_CheckBookInvariants and once at init. OnTick calls if !halted Grind_ReplayCheckInvariants -> Grind_ReplayInvariantOk -> if no test active return Grind_CheckBookInvariants(). Also Grind_ReplayCheckInvariants may call again after sweep if ok. But yes every tick? Actually if replay active? In production not. On init Grind_ReconstructState calls collector. Also if halted? G6 says while not halted. OnTick only calls if !g_grind_halted. Good. Once at init: Grind_ReconstructState called in OnInit, calls collector. VERIFIED.

Now threats.

T-1 The dedupe key. Key = ticket AND kind, because a position's POSITION_IDENTIFIER equals ticket of order that opened it. Need determine any real case where two distinct broker entries share ticket and kind => dropped -> hides true AMBIGUOUS or I-failure. Or same entry appears under both kinds counted twice (it was before too?).

Need analyze MT5 ticket uniqueness. In MT5, order tickets are unique. Position identifier: In hedging account, a position is identified by POSITION_IDENTIFIER. In MT5, position ticket/identifier often equals the order ticket that opened it? Actually for hedging, a position ticket is same as order ticket that opened position? I need know. The spec says "a position's POSITION_IDENTIFIER equals the ticket of the order that opened it". But is it possible two distinct broker entries share ticket and kind? Two positions cannot share same position identifier. Two orders cannot share same order ticket. A position and an order can share same number (different kind), hence key includes kind. Could an order and a position both have same ticket and both kind? No kind differs. Could two positions with same identifier? No. Could two orders with same ticket? No. But wait: The collector appends positions with `ticket = POSITION_IDENTIFIER`, kind POSITION. Then orders with `ticket = OrderGetTicket`, kind ORDER. If a position's identifier equals the ticket of a *different* order that did not open it? In MT5, the position ticket is the ticket of the first order that opened it? For hedging, a position's ticket may be the ticket of the order that opened it; but after partial close? The position identifier remains same. For a position, the opening order might be an entry order that converted to position? In MT5, when a pending order triggers, the resulting position may have ticket equal to the order ticket? I think in netting, position ticket is first order ticket. In hedging, position ticket is same as order that opened. So a position and its opening order share number, different kind. Key includes kind. Good.

But potential issue: When an entry order fills, it disappears from OrdersTotal and a position appears with same ticket. During the walk, could both the order and the position be present? In MT5, not simultaneously for same ticket? The order becomes a deal and position. The order list after fill removes order. OnTradeTransaction might be during transition? Broker lists are snapshot at call. Could be both in different lists? If both present, they have same ticket but different kind, so both appended. Rebuild handles ENT order kind vs ENT position kind: If both same layer and same ticket, the position sets entry; the order (ENT kind ORDER) for layer>=1 sets add_pending_ticket. That would be ambiguous? Wait if an entry order (pending) and a position with same ticket both exist, the code would process position first? Order of tickets array: positions then orders. For a layer, position sets has_position. Then later ENT ORDER sets add_pending_ticket. This could cause AMBIGUOUS? If order fills, order should be gone. But if both present due to race, it might fail. But key including kind means both counted. Was before too. T-1 asks "or where the same entry appears under both kinds and is now counted twice (it was before too)?" We need answer. It was before too: old collector appended positions and orders without dedupe. So no change.

Could there be real case where two distinct broker entries share ticket and kind? Need consider MT5 magic filter: They filter by symbol and magic. But ticket uniqueness is global per broker. No two orders same ticket. No two positions same identifier. However, is POSITION_IDENTIFIER unique? In MT5, POSITION_IDENTIFIER is position ticket, unique. In hedging, multiple positions on same symbol can have different identifiers. So no. But what about a position's POSITION_IDENTIFIER equals an order ticket of a *different* order with same kind? Different kind? No. So T-1 HOLDS (no real case). But need be careful: The key is ticket AND kind. If two distinct broker entries share ticket and kind, that would require two orders with same ticket (impossible) or two positions with same identifier (impossible), or an order and a position with same ticket and same kind (impossible because kind differs by source). So no. Could an order be both an exit order and an entry order? Same ticket, kind ORDER. The collector appends each order once. Dedupe by ticket+kind would drop a second occurrence of the same ticket if the order appears twice in OrdersTotal() due to race. That's intended. No distinct entries.

But wait: There's a potential real case: In MT5, an order can be both in OrdersTotal() and also represented as a position? Different kind. Not dropped. Good.

However, there is a subtle issue: The dedupe key uses `ticket` and `kind`, but for positions it uses `POSITION_IDENTIFIER`, not the actual position ticket? In MT5, POSITION_IDENTIFIER is the position ticket. Good.

Could two positions have same POSITION_IDENTIFIER if one is a "close by" or hedge? No.

Thus T-1 HOLDS. But maybe there is a hidden issue: The collector filters by symbol and magic. Suppose a position from magic A and an order from magic B share ticket? Different magic, but same ticket? Ticket global unique, so no. If same ticket, it can only be same order/position. If magic filter passes one but not other? For same ticket, magic likely same. Not relevant.

T-2 What a SKIP can still cause. Need list every reason a single skipped entry can produce in Grind_RebuildBookFromTickets: skipped position, skipped exit order, skipped entry order, skipped L0. Is any NOT quarantinable so one tick's skip still halts at once, as duplicate did?

We need analyze rebuild logic. The collector returns list of tickets. If one entry is skipped due to race, what does rebuild produce? Need consider scenarios.

Skipped position: If a position (ENT POSITION) is skipped, then that layer has no position. Depending on other entries: If there is an exit order or exit position for that layer, then layer has exit coverage but no position -> I4_*_ORPHAN_EXIT. Is I4 quarantinable? Yes: I4_LONG_ORPHAN_EXIT / SHORT in Grind_IsQuarantinableReason. So quarantine. If no exit coverage and no position, layer not created unless exit order/position exists. If no other entries for that layer, the layer is absent entirely. Then invariants on remaining layers might pass? But if a position is skipped, your book is missing a layer. Would that cause any invariant failure? The book just has fewer layers. That may not be detected by invariants! Important. If a position is skipped and there is no exit order for that layer (or exit also skipped?), then the rebuild book simply doesn't include that layer. The invariants check the book reconstructed from tickets; they don't know about the missing position. So a skipped position could silently produce a book missing a layer, and no I-failure. That is dangerous: it could lead to duplicate entry or wrong state. But T-2 asks "List every reason a single skipped entry can produce in Grind_RebuildBookFromTickets ... Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" So need list reasons that can be produced. A skipped position may produce no reason at all (silent missing layer) or I4 if exit present. A skipped exit order: If layer has position but exit order skipped, then if exit required (rank) -> I3_*_NAKED (quarantinable). If not exit required? Grind_ExitQRequired? Need know. If exit not required, no failure. Or if there is no other exit coverage, the book may just have no exit target; later it may compute formula target. But invariants might pass? I3 only if Grind_ExitQRequired(rank,count) and no coverage. If exit not required, no failure. So skipped exit order can be silent if rank doesn't require exit. If exit order skipped and layer has position, but exit not required, no failure. If exit order skipped and there is an exit position? Not likely. Skipped exit order could also cause I6 if there is still exit coverage? No, skipped means not in list, so no coverage. Could cause I1 if duplicate? No. Skipped entry order: If an entry order (ENT ORDER) for layer >=1 is skipped, then add_pending_ticket is not set. The rebuild may pass if no other issues. That means the state thinks no pending add. Might be okay? But if the order exists, engine may later try to place another add -> double layer? But invariant doesn't see it. If skipped L0 entry order: l0_pending_ticket not set. If a position for that layer exists? L0 order is pending entry for layer 0. If skipped, book may think no L0 pending; engine may place another L0 order? But not invariant failure. If skipped entry order but also there is a position? Could cause I? Let's examine.

The rebuild code:
- ENT POSITION: creates layer, sets has_position. If duplicate same layer -> I5_*_DUP (not quarantinable? I5 reasons are not in quarantinable list. They halt at once. But duplicate position would require two distinct positions same layer, not a skip.)
- EXT ORDER: creates layer if needed, sets has_exit_order. If layer already has exit coverage -> I2_*_EXIT_DUP (quarantinable). A skip of an EXT ORDER wouldn't cause I2.
- EXT POSITION: similar.
- ENT ORDER: layer 0 -> l0_pending_ticket; if already set -> AMBIGUOUS_L0_* (halt). layer >=1 -> add_pending_ticket; if already set -> AMBIGUOUS_ADD_* (halt).
- Later checks: for each layer, if has_position and ExitQRequired and no exit coverage -> I3_*_NAKED (quarantinable). If !has_position and has exit coverage -> I4_*_ORPHAN_EXIT (quarantinable). Then Grind_ReconCheckInvariants also checks I7 depth, I5 corrupt, I3/I6 etc, I1 exit count. So possible reasons from a single skip:
   - Skipped position:
       * If exit coverage exists for that layer -> I4_*_ORPHAN_EXIT (quarantinable).
       * If no exit coverage -> layer absent, no reason. Silent.
       * Could affect rank/ExitQRequired of other layers? If layer skipped, depth decreases, ranks change. Could cause an existing position that previously had exit not required? Actually if count decreases, ExitQRequired might change. Could cause I3 or I6? Let's think. Grind_ExitQRequired(rank, count) probably requires exits for some layers based on count. If count decreases, required exits may decrease, so less likely I3. But rank changes might make a layer's rank different, possibly causing I6? I6 checks exit target matches entry. If rank changes, exit tolerance? No, I6 independent of rank? I6 only checks if has exit coverage, exit target matches. So no.
       * Could cause I1? exit count? If position skipped, exit coverage for that layer might be I4 before I1. If no exit, no.
       * Could cause depth? I7 only if too many, skip reduces.
       * Could cause I5 duplicate layer indices? No.
   - Skipped exit order (EXT ORDER):
       * If layer has position and ExitQRequired -> I3_*_NAKED (quarantinable).
       * If layer has position and not ExitQRequired -> no failure (book lacks exit target; later may compute formula target? In rebuild, if no exit coverage, exit_target = Grind_ExitQFormulaTarget. That may be fine).
       * If layer also has position and some other exit? No, skipped means absent. If there is an exit position too? Then not skipped exit order maybe also exit position exists -> coverage exists. No failure.
       * Could affect I1? no.
   - Skipped exit position (EXT POSITION):
       * Similar to skipped exit order: if position and ExitQRequired -> I3_*_NAKED (quarantinable). If not required -> silent. If position also has exit order? Then coverage exists. If exit position skipped but exit order present, no failure.
   - Skipped entry order (ENT ORDER layer >=1):
       * No invariant checks on pending add except Grind_ReconCheckPendingAddCorrupt checks if add_pending_ticket !=0 but ticket not found or not order. If skipped, add_pending_ticket = 0, so passes.
       * Could hide a real ambiguity? If there was only one entry order, skipping it just means no pending. Silent.
       * If there were two entry orders for same layer? A skip of one might avoid AMBIGUOUS_ADD_*? Wait collector dedupe would drop duplicates. But a SKIP (miss an entry) could cause a duplicate? Suppose there are two distinct entry orders for same layer. The collector should collect both, and rebuild would fail AMBIGUOUS_ADD_LONG. If a race skips one, the rebuild sees only one and passes. That hides a true AMBIGUOUS_ADD_LONG (which is a halt reason). That's a false negative. This is a skip of an entry order that could hide a real failure. The T-2 question: "Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" Wait they ask "what a SKIP can still cause... Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" Actually duplicate caused AMBIGUOUS (halt). A skip could cause a reason that is not quarantinable? Let's parse. They want reasons a single skipped entry can produce in rebuild. For each, is it quarantinable? If not, it halts at once. They ask "Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" So we need find if a skip can produce a non-quarantinable reason. Could a skip cause I5_DUP? Suppose skip an entry order? No. Skip a position? Could cause I5? No. Skip an exit order? Could cause I? I3 is quarantinable. Skip an entry order could cause AMBIGUOUS? No, skip removes an entry, so it cannot create ambiguity; it can hide ambiguity. But could a skip create an ambiguity? Imagine two entry orders for same layer, but one is skipped. The remaining one is collected. If there was also a position? Not ambiguity. What if a skip of a position causes a layer to have an exit order but no position -> I4 (quarantinable). Skip of an exit order with position -> I3 (quarantinable). Skip of an L0 entry order: l0_pending_ticket missing. Could that cause AMBIGUOUS_L0? No. Could it cause I8_CORRUPT_PENDING_ADD? If l0_pending_ticket? I8 only checks add_pending_ticket, not l0_pending_ticket. Wait Grind_ReconCheckPendingAddCorrupt checks add_pending_ticket (for layers >=1) only. L0 pending is not checked. So skipped L0 entry order is silent.

Thus a single skip can be silent for entry orders (including L0) and for exit orders/positions when exit not required, and for positions with no exit coverage. None of these produce a non-quarantinable reason. The only reasons produced by a skip are I3_*_NAKED and I4_*_ORPHAN_EXIT, both quarantinable. So a skip does NOT halt at once as the duplicate did. The duplicate caused AMBIGUOUS_ADD_LONG (non-quarantinable halt). A skip can hide a real AMBIGUOUS_ADD_LONG (if two entry orders and one skipped) but cannot itself cause AMBIGUOUS. It can cause only quarantinable I3/I4 or silence. So answer: no non-quarantinable reason from a skip. But also note a skip can hide a non-quarantinable failure (e.g., two entry orders -> AMBIGUOUS_ADD_LONG, one skipped -> passes). That's a false negative, not a halt. T-2 asks "Is any of them NOT quarantinable, so that one tick's skip still halts at once?" So verdict: HOLDS? The threat is "What a SKIP can still cause." The design relies on skip consequences being quarantinable. That holds for reasons produced. But the skip can hide a real AMBIGUOUS, which is worse? The threat says "A skip inside a walk whose counts match (a same-count swap) is accepted (GV-2). List every reason a single skipped entry can produce... Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" So the concern is a skip causing an immediate halt. Answer: none of the reasons a skip can produce are non-quarantinable; skips produce I3/I4 (quarantinable) or no reason. However, a skip can *hide* a non-quarantinable reason (AMBIGUOUS_ADD), which is a different risk. The question asks "what a SKIP can still cause." I should mention that a skip can hide an existing AMBIGUOUS_ADD if two entry orders and one skipped, so the immediate halt is missed. But it doesn't itself cause a halt. The verdict maybe NEEDS-FIX? The threat is T-2 "What a SKIP can still cause." The design says skip of exit or position gives quarantinable I3/I4 that clears on next tick. But if skip of an entry order, it can hide a real AMBIGUOUS (non-quarantinable) failure. That's a serious lookahead? It allows a real invariant violation to be missed. However, the next tick likely catches it unless race repeats. A same-count swap is rare. But T-2 asks specifically: "List every reason a single skipped entry can produce... Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" The duplicate caused a halt. A skip does not cause a halt; it can hide a halt. So the answer: none of the produced reasons are non-quarantinable. But the hidden AMBIGUOUS is not produced; it's hidden. So verdict HOLDS? Or NEEDS-FIX because skip of entry order can hide an AMBIGUOUS that would halt? The threat wording: "What a SKIP can still cause. A skip inside a walk whose counts match (a same-count swap) is accepted (GV-2). List every reason a single skipped entry can produce in Grind_RebuildBookFromTickets (skipped position, skipped exit order, skipped entry order, skipped L0). Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" I think they want to verify that a skip cannot cause an immediate halt. But they also want list. We can say: skip of position -> I4 (quarantinable) or silent; skip of exit order -> I3 (quarantinable) or silent; skip of entry order -> silent or hides AMBIGUOUS_ADD (non-quarantinable) if two entry orders; skip of L0 -> silent or hides AMBIGUOUS_L0. None of these *produced* reasons are non-quarantinable. So no, a skip does not halt at once. But it can hide a halt. The risk is a false negative for one tick. If the underlying ambiguity persists, next tick catches (unless race repeats). That's acceptable per GV-2? GV-2 accepted same-count swap. So T-2 HOLDS with caveat. Smallest fix? Could add a check that no entry order was skipped? Hard to know without full list. Or make collector use a stable snapshot? But out of scope. Maybe smallest fix: if `stable` false or walks>1, do not trust the walk for AMBIGUOUS? But they use last walk. Actually if a skip occurs in a walk that ends with counts matching (same-count swap), `stable` is true and no marker. That's the accepted GV-2. To catch hidden AMBIGUOUS, would need compare ticket sets between walks, which is rejected. So no fix. We can note as accepted risk.

T-3 Marker and log volume. RECON_SCAN_RACE and Print fire on EVERY raced walk, every tick, every instance, no throttle. On busy terminal, how often can a walk race? Archive queue holds 5000 rows per instance and archive batch answered 400 is dropped. Is unthrottled WARN risk to archive or telemetry, and smallest bound (once per N seconds, or count in heartbeat)?

Need inspect archive queue behavior. We have grind_archive? Not provided. But spec mentions archive queue 5000 rows per instance and batch answered 400 dropped. We need reason. The marker fires if `Grind_ReconScanRaced(dupes_total, walks)` true. That is if any duplicate dropped or walks>1. In a busy terminal with nine instances, each tick calls collector. Other EAs remove orders. A race can occur when a list changes during a walk. How often? Every time another EA modifies orders/positions during the walk. With nine instances, they may place/cancel/modify frequently. On FOMC, many orders. The walk is short (PositionsTotal+OrdersTotal loops). But other EAs might modify at any time. Probability per walk maybe moderate. If race occurs, it triggers up to 3 walks. If it becomes stable after second walk, marker fires once per collector call. That could be many times per second per instance. On tick, if market busy, ticks can be many per second. Nine instances => potentially thousands of WARN per minute. Archive queue 5000 rows per instance. Unthrottled WARN could fill queue and cause drops. Also Print to Experts log every time, huge log volume. Telemetry marker? Grind_ArchiveMarker likely enqueues archive and maybe telemetry. Need check. The archive queue holds 5000 rows per instance; if exceeded, maybe drop? The prompt says "an archive batch answered 400 is dropped." That suggests if too many rows, batch fails and rows dropped. So risk: yes, unthrottled WARN can overwhelm archive, cause loss of more important markers. Smallest bound: throttle to once per N seconds per instance (e.g., 30 s) or include count in heartbeat. The prompt suggests. We can recommend: only emit RECON_SCAN_RACE marker when state changes or at most once per N seconds; keep a per-instance counter and emit in heartbeat. Since G3 says no ticket numbers, counts okay. Smallest fix: guard with `g_grind_recon_scan_last_marker_ms` and only emit if elapsed > e.g. 10000 ms; always increment a counter for heartbeat. But heartbeat changes not in scope? Could be backlog. For audit, verdict NEEDS-FIX.

Need quote lines: `if(Grind_ReconScanRaced(dupes_total, walks)) {` and `Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail); Print(...)`. No throttle. Also note `Grind_ReconScanRaced` returns true if `dupes > 0 || walks > 1`. A duplicate can happen on every walk if a race causes duplicate. Also if walks>1 even if no duplicate? Actually walks>1 means first walk unstable, second stable. Marker fires. So every time list changes during walk. With nine instances, any order modification by any instance can cause other instances' walks to race. So frequent.

T-4 The walk loop. `count` and array reset per walk; `dupes_total` accumulates over walks; totals read before and after each walk. Any path where returned `count` and array disagree, stale entry survives, or `stable` reported wrongly? Cost up to three walks per tick per instance.

Let's inspect `Grind_ReconCollectBrokerTickets`:
```
int count = 0;
int dupes_total = 0;
int walks = 0;
bool stable = false;
while(walks < 3 && !stable) {
   walks++;
   count = 0;
   ArrayResize(tickets, 0);
   const int positions_before = PositionsTotal();
   const int orders_before = OrdersTotal();

   for positions...
      count = Grind_ReconAppendUnique(tickets, count, ..., dupes_total);
   for orders...
      count = Grind_ReconAppendUnique(tickets, count, ..., dupes_total);
   stable = Grind_ReconScanStable(positions_before, orders_before, PositionsTotal(), OrdersTotal());
}
...
return count;
```
Potential issues:
- `dupes_total` accumulates over walks. If first walk has duplicate due to race, dupes_total increments. Then even if second walk is clean, dupes_total >0, so marker says raced and detail includes dupes from earlier walk. That's intended? The spec says "A dropped duplicate or more than one walk raises..." dupes_total over all walks. It's okay.
- `count` reset per walk. ArrayResize(tickets,0) resets. So no stale entries. `count` matches array size? `Grind_ReconAppendUnique` returns count+1 and resizes to count+1. It sets fields. If count is reset to 0 and array size 0, after appends, array size = count. So yes, count == ArraySize(tickets). However, if `ArrayResize(tickets, 0)` fails? It could fail? ArrayResize returns int; they ignore. If it fails, stale entries could survive? In MQL5, ArrayResize to 0 should succeed. ASSUMED. Also `ArrayResize(tickets, count + 1)` inside AppendUnique ignores failure; if fails, could write out of bounds? MQL5 ArrayResize returns -1 on failure? Actually returns int, if fails, array not resized, then writing tickets[count] would be out of bounds. But that's existing pattern. The branch uses same. Could be a risk but not new? The old collector used ArrayResize too. We can mention.
- `stable` reported wrongly: `stable` is set based on counts before and after each walk. If the list changes but counts return to same (same-count swap), stable true. That's GV-2 accepted. But `stable` is also used in `Grind_ReconScanDetail(dupes_total, walks, stable)`. If the loop exits because walks == 3, `stable` is false (since while condition !stable; if exited due to walks limit, stable remains false from last check). Good. If the loop exits because stable true, stable true. If a walk is unstable but then next walk stable, stable true. So `stable` reflects last walk stability. That seems correct.
- Could `count` and array disagree if `Grind_ReconAppendUnique` is called with count but array has more elements? It resets array per walk. Within walk, AppendUnique iterates `i < count`. If array size > count due to failed resize? No.
- Cost: up to 3 walks per tick per instance. With nine instances, 27 walks per tick per terminal. But if lists change frequently, each walk up to 3. Could be CPU heavy but not fatal. Need mention.
- Potential bug: The loop condition `while(walks < GRIND_RECON_SCAN_MAX_WALKS && !stable)`. If first walk stable, walks=1, stable=true. Fine. If first walk unstable, walks=1, stable=false -> second walk. If second stable, walks=2, stable=true -> exit. `Grind_ReconScanRaced(dupes, walks)` sees walks>1 true -> marker. Good.
- `dupes_total` accumulates over walks. Suppose first walk had a duplicate (dupes_total=1) and second walk clean. `dupes_total` remains 1. The returned count from second walk is clean. Marker says dupes=1. That's correct because a duplicate was dropped in first walk. But the detail says "dupes":1, "walks":2. Fine.
- If a duplicate is dropped in a walk, the count is lower. But the duplicate was likely due to race. The second walk may be clean. Good.
- Stale entry: If `ArrayResize(tickets, 0)` is called, it clears array. But does it reset elements? Resize to 0 removes all. Good.
- Returned `count` matches array size. Unless `Grind_ReconAppendUnique` returns count unchanged on duplicate, array size remains count. Good.
- One subtle bug: `Grind_ReconAppendUnique` uses `ArrayResize(tickets, count + 1)`. If `count` is the logical count, but array size might be larger if previous walk had more elements and `ArrayResize(tickets, 0)` failed? No.
- Another subtle: The positions loop uses `for(int i = PositionsTotal() - 1; i >= 0; i--)`. It calls `PositionsTotal()` each iteration? No, the loop initializer evaluates once, but the condition `i >= 0` and decrement. It does not re-read PositionsTotal inside loop. The old code likely same. However, inside the loop, `PositionGetTicket(i)` uses current list. If a removal below i occurs, the next i-- re-reads an entry already counted -> duplicate. Dedupe drops it. If a removal above i, the entry at i shifts? Let's analyze: walk from top index down. If an order above i (higher index) is removed, indices below i? Actually if list size decreases, the top index becomes smaller. The loop started with initial total-1. If an entry above current i is removed, the list shifts down, so the element that was at i+1 moves to i. But we are at i-- next, so we might skip the element that moved into i? Wait we just processed i. Next iteration i-1. If removal above i (index > i), indices <= i are unchanged. So no skip. If removal below i (index < i), indices above i? Actually removing below i shifts elements below? Let's be precise: list indices 0..N-1. Walk from N-1 down. At index i, process element. If an element at index j < i is removed, then elements at indices > j shift down by 1. So the element that was at i+1 moves to i? But i+1 was already processed (since descending). The element at i? It was just processed. The next iteration is i-1. The element that was at i (processed) is now at i-1? Wait if j < i, removing index j shifts elements j+1..N-1 down by 1. So element at i becomes i-1. Next iteration i-1 will re-read the same element we just processed -> duplicate. That's the duplicate case. If removal above i (j > i), elements <= i unchanged. Next iteration i-1 reads original element i-1, no skip. If insertion above i, elements >= insertion shift up. Next iteration i-1 reads original i-1? Insertion at j > i doesn't affect <=i. If insertion below i, elements >= j shift up. The element at i moves to i+1. Next iteration i-1 reads original i-1? Actually if insertion at j < i, then elements j..i-1? Let's not. The point is dedupe handles duplicates, skips can occur. But the loop condition uses initial `PositionsTotal()`? Actually `for(int i = PositionsTotal() - 1; i >= 0; i--)` evaluates `PositionsTotal()` once at start. So if list grows, new elements at higher indices are not processed. If list shrinks, i may refer to out-of-range? `PositionGetTicket(i)` returns 0 if i >= new total? The code checks `ticket == 0` and continue. So it skips. Fine.
- Totals before/after are read at start and after both loops. If list changes during positions loop but returns to same count by end, stable true. Same-count swap accepted.
- Could `stable` be reported wrongly if totals change during the walk but return to same count before the after-read? Yes, that's the same-count swap. Accepted GV-2.
- Could `stable` be true even if a duplicate occurred? Yes, if a duplicate was dropped due to a removal below i, the total count likely changed? If a removal below i caused duplicate, total count decreased. Then after walk, PositionsTotal() might be less than before. stable false. So loop repeats. But if the removal was compensated by an insertion, total same, stable true, but duplicate dropped. Then dupes_total >0, marker fires. The returned walk is after the compensation; it might be clean? Actually the duplicate occurred in the walk. The walk also skipped? The walk ended with same total. The returned array from that walk may have duplicate dropped but could be missing an entry? Let's analyze: If a removal and insertion happen, total same. The walk from top down may re-read an entry (duplicate dropped) and miss the newly inserted entry (if inserted at higher index? Actually if insertion at index > current i, not processed; removal below i causes duplicate). The net result could be that one old entry is missing (the one removed) and the new inserted entry is not processed (if inserted above initial top? No, insertion increases total, but after read? The loop started with initial total. If insertion occurs after start, new element at index >= initial total, so not processed. The removed entry was below i, causing duplicate of another. So the returned array may have one duplicate dropped (so count one less than expected) and missing the new entry. But the totals match before/after. This is a same-count swap. The returned book could be missing a layer. The marker fires because dupes_total>0. But the collector returns the last walk (this one). No retry because stable true. That's the accepted GV-2. T-4 asks any path where returned count and array disagree, stale entry, stable reported wrongly. In same-count swap, stable is true but the walk is not actually a consistent snapshot. That's by design (GV-2). Also `stable` reported as true though a race occurred. The detail says stable true even though dupes_total>0. `Grind_ReconScanDetail(dupes_total, walks, stable)` would show `"stable":true` while `"dupes":1`. That's okay. But is that "stable reported wrongly"? It means count-stable, not race-free. The field name stable might be misleading. But spec says stable is count check. So not a bug per rulings.
- Another issue: `dupes_total` accumulates over walks, but if a duplicate is dropped, the count is lower. If the walk then becomes stable, the returned array is from a walk that had a duplicate dropped. That means the returned array is missing the duplicate entry. But the duplicate was likely a duplicate, so dropping it is correct. However, if the duplicate arose because of a skip? No, duplicate means re-read same entry. Dropping it is correct. But what if the duplicate was a real second entry? T-1 says impossible. So okay.
- Cost: up to three walks per tick per instance. With nine instances, 27 walks per tick. On busy tick thousands per second? FX ticks can be many. But code runs on every tick, so could be heavy. However, the original ran one walk per tick. Three times only when unstable. In busy periods, could be frequent. Mention as performance risk but not necessarily break.

T-5 RECON_TICKETS. Printed on change only; memory reset by Grind_ReconFailureClear, which rebuild calls on success. A failure that alternates with success prints every time. Any path where line is built from a different list than JSON (order, count, truncation at 40), or where `%I64u` misprints a `ulong` ticket?

Check `Grind_ReconTicketsLogLine`:
```
string s = StringFormat("RECON_TICKETS reason=%s n=%d", reason, count);
const int emit = MathMin(count, GRIND_RECON_FAILURE_MAX_EMIT);
for(int i = 0; i < emit; i++) {
   s += StringFormat(" %s:%I64u",
                     tickets[i].kind == GRIND_RECON_TICKET_POSITION ? "P" : "O",
                     tickets[i].ticket);
}
if(count > GRIND_RECON_FAILURE_MAX_EMIT)
   s += StringFormat(" +%d more", count - GRIND_RECON_FAILURE_MAX_EMIT);
return s;
```
JSON in `Grind_ReconFailureCapture`:
```
const int emit_count = MathMin(ticket_count, GRIND_RECON_FAILURE_MAX_EMIT);
...
for(int i = 0; i < emit_count; i++) {
   ...
   json += StringFormat(
      "{\"kind\":\"%s\",\"comment\":\"%s\",\"price\":%.5f,\"side_hint\":%s}",
      Grind_ReconFailureKindLabel(tickets[i].kind),
      ...
```
Both use same `tickets` array, same count, same max emit, same order 0..emit-1. JSON doesn't include ticket number. So line and JSON rows correspond in order and truncation. The line includes P/O prefix based on kind; JSON includes kind label POSITION/ORDER. Count in line is `count`; JSON has `ticket_count`. Both same. Truncation: line says `+%d more` with `count - GRIND_RECON_FAILURE_MAX_EMIT`; JSON has `truncated` true and emits 40. So consistent.

Potential bug: `%I64u` for ulong. In MQL5, `StringFormat` uses `%I64u` for unsigned 64-bit? Typically MQL5 supports `%I64d` for long, `%I64u` for ulong? I think MQL5 uses `%I64d` for long and `%I64u` for ulong? Actually MQL5 documentation: `%I64d` for long, `%I64u` for ulong. So yes. But ticket is `ulong`. In some MQL5 versions, `%I64u` may not be supported? It is used elsewhere in code: `StringFormat("...%I64u...", elapsed)` in quarantine, `%I64d` for long. So likely correct.

Any path where line built from different list? In `Grind_ReconFailureCapture`, it builds JSON then line with same `tickets` and `ticket_count`. But note: `Grind_ReconFailureCapture` is called from `Grind_RebuildBookFromTickets` with the `tickets` array and `ticket_count` that were passed to rebuild. In `Grind_RebuildBookFromTicketsInner`, the `tickets` array is the same as collector output? Yes, `Grind_CheckBookInvariants` passes `tickets, count` to `Grind_RebuildBookFromTickets`. `Grind_RebuildBookFromTickets` calls inner, if fail calls `Grind_ReconFailureCapture(tickets, ticket_count, reason_out, offending);`. So same list. Good.
But note: `Grind_ReconFailureMeasureWorstCase` calls capture with a synthetic list, and then `Grind_ReconFailureClear`. That could affect the last line memory in tests/telemetry? Not production. In production, only failure capture on failure.
Memory reset: `Grind_ReconFailureClear` sets `g_grind_recon_tickets_last_line = ""`. It is called on success in `Grind_RebuildBookFromTickets`. So if failure alternates with success, each failure prints because memory cleared on success. That's intended? T-5 says "A failure that alternates with success prints every time." Yes, because success clears memory. Is that a problem? It could spam if toggling. But if failure alternates, that's a serious issue. Not a bug per se.

One subtle bug: `Grind_ReconFailureCapture` updates `g_grind_recon_failure_json` and then prints line if differs. If the same failure repeats without success in between, it won't print again. Good.

Another subtle: `Grind_ReconTicketsLogLine` uses `tickets[i].kind == GRIND_RECON_TICKET_POSITION ? "P" : "O"`. If kind is neither 0 nor 1, prints O. But kind only 0/1.

Truncation: `GRIND_RECON_FAILURE_MAX_EMIT` = 40. Line emits 40 entries and `+N more`. JSON emits 40 entries. Consistent.

Could `%I64u` misprint a `ulong` ticket? In MQL5, `ulong` is unsigned 64-bit. `%I64u` is correct. However, in `StringFormat`, MQL5 might require `%d` for int and `%I64d` for long. `%I64u` for ulong is documented? Let's check memory: MQL5 StringFormat supports `%I64d` for long, `%I64u` for ulong, `%I64x` for unsigned hex. Yes. So no.

T-6 API limit inputs. `Grind_ApiLimitsApplyInputs` runs in OnInit before magic lock; globals versus a reason-5 re-init; the `(int)` cast of `GlobalVariableGet`; the two Global Variables persist on terminal (suite deletes them, desktop only). Any path where limits in force differ from what `GRIND_API_LIMITS` / `API_LIMITS_CONFIG` report, or where WARN markers emitted before archive can take them?

Let's inspect OnInit order. In fxgrind.mq5:
- Many geometry validations, returns INIT_FAILED.
- `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);`
- Then magic lock claim. If duplicate magic, returns INIT_FAILED. So API limits apply before magic lock. If magic lock fails, EA unloads. The API limit globals were set in memory but EA unloads. However, `Grind_ApiLimitsApplyInputs` sets global variables in memory only, not terminal GVs. It also does not publish. Then if magic lock fails, OnInit returns INIT_FAILED before publishing. So no API_LIMITS_CONFIG marker, no publish. But globals are per-program? In MQL5, global variables in EA are reset on unload? They are not persistent across unload. So no issue.
- After magic lock, many initializations, then prints `GRIND_REROLL`, `GRIND_API_LIMITS` (prints globals). Then `GRIND_GEOMETRY`, `GRIND_REBUILD`, `LATTICE_CONFIG` marker. Then `if(!api_inputs_ok) { ... ArchiveMarker WARN API_LIMITS_INVALID; Print(...); }` Then `Grind_ArchiveMarker("INFO", "API_LIMITS_CONFIG", ...);` Then `Grind_ApiLimitsPublishAndCheck();` Then `EventSetTimer(1); return INIT_SUCCEEDED;`

Potential issue: The `GRIND_API_LIMITS` Print occurs before the `API_LIMITS_INVALID` WARN and before `API_LIMITS_CONFIG`. It prints the globals in force. If inputs invalid, `Grind_ApiLimitsApplyInputs` already fell back to defines, so globals are defines. So print shows defines. Good.
- `API_LIMITS_INVALID` uses `InpApiEntryStop` and `InpApiSoftWarn` (the raw inputs) and `g_grind_api_entry_stop`/`g_grind_api_soft_warn` (the globals). Good.
- `API_LIMITS_CONFIG` uses globals. Good. So limits in force match report.
- `(int)GlobalVariableGet` cast: GlobalVariableGet returns double. Cast to int truncates. The limits are ints stored as double. Integers up to 1,000,000 are exactly representable in double. So no precision issue. If someone sets a GV with fractional value, cast truncates. But only code sets ints. ASSUMED.
- Global Variables persist on terminal. If a previous run set GV to 1900, and new run starts with defaults 1000000, `Grind_ApiLimitsPublishAndCheck` will see existing GVs, compare to 1000000, mismatch -> WARN. Then overwrite. That's intended. But on a fresh terminal with leftover GVs from a different preset, every chart will WARN until overwritten. That's noise. But ruling GV-7 says last init wins, mismatch WARN. Acceptable.
- Reason-5 re-init: When EA reinitializes (e.g., input change, timeframe change), OnInit runs again. Global variables of the EA are reset? Actually on reinit, global variables are not reinitialized? In MQL5, when an EA is reinitialized (reason 5?), `OnInit` is called again. Global variables retain their values? I think on reinit, the program is not unloaded completely? Actually for an EA, changing inputs or timeframe triggers deinit and init. The global variables are reset? Need recall: In MQL5, when you change inputs, the EA is removed and reloaded, so globals are reinitialized. For reason REASON_PARAMETERS (5)? Actually `OnDeinit` is called with reason 5 (REASON_PARAMETERS) when inputs changed. Then `OnInit` is called again. The global variables? The EA is not fully unloaded? I think global variables are reinitialized on init? Hmm. In MQL5, global variables (program variables) are initialized when the program is loaded. On reinit due to parameter change, the program is not unloaded? Actually `OnDeinit` is called, then `OnInit` is called. I believe global variables retain their values unless reinitialized in OnInit? Wait, MQL5 documentation: "When the EA is reinitialized, the global variables are not reset." Actually I'm not 100% sure. Let's think: In MQL5, if you change timeframe, OnInit is called again. Global variables are not reset? Many EAs rely on global variables being reset? Actually MQL4 had init/deinit. In MQL5, global variables are initialized once when the program is loaded. Reinitialization (changing symbol/timeframe) does not unload the program? It calls OnDeinit and OnInit. I think global variables retain their values. But `Grind_ApiLimitsApplyInputs` is called in OnInit, so it will set them again based on inputs. So no stale issue. If inputs invalid, it sets to defines. So fine.
- `Grind_ApiLimitsApplyInputs` runs before magic lock. If magic lock fails, `OnInit` returns INIT_FAILED. The API limits were set in memory but no publish. No trading. Fine.
- WARN markers emitted before archive can take them? Archive is configured later? Let's check: In OnInit, `Grind_ArchiveConfigure` is called before `Grind_ReconstructState`. Yes, at lines around after magic lock. The `API_LIMITS_INVALID` and `API_LIMITS_CONFIG` markers are after `Grind_ArchiveConfigure`. So archive is configured. But is `Grind_ArchiveMarker` safe before `EventSetTimer`? It enqueues. Archive flush happens in OnTimer. So markers are enqueued and will be flushed later. They are not emitted before archive can take them. However, if the EA unloads soon after (e.g., magic lock fails), no archive. But magic lock failure returns before markers. So fine.
- Potential issue: `Grind_ApiLimitsApplyInputs` is called before `g_grind_telemetry_instance` is set. It doesn't use telemetry. Fine.
- API limits in force vs `GRIND_API_LIMITS` / `API_LIMITS_CONFIG`: The `GRIND_API_LIMITS` Print is before the `API_LIMITS_INVALID` marker. It prints globals. If `Grind_ApiLimitsApplyInputs` returned false, globals are defines. So print shows defines. The `API_LIMITS_INVALID` marker shows inputs and using. The `API_LIMITS_CONFIG` marker shows globals. All consistent.
- But note: `Grind_ApiLimitsPublishAndCheck` is called after `API_LIMITS_CONFIG`. It may emit `API_LIMITS_MISMATCH` WARN if published GVs differ. That WARN uses globals. So consistent.
- Any path where WARN markers emitted before archive can take them? `Grind_ArchiveMarker` may be called before `Grind_ArchiveConfigure`? No, in OnInit, `Grind_ArchiveConfigure` is before `Grind_ReconstructState`, and `API_LIMITS_INVALID` is after that. So archive configured.
- However, if `EnableTelemetry` is false, archive is disabled? `Grind_ArchiveConfigure` may set `g_grind_archive_enabled` false. Then `Grind_ArchiveMarker` might not enqueue? But that's normal. The markers still Print. The question says "or where the WARN markers are emitted before the archive can take them?" If archive disabled, they are not taken. But that's expected. If archive enabled, they are enqueued. Need check if `Grind_ArchiveMarker` requires timer? It probably enqueues to a queue. The queue might be processed on timer. So fine.
- One subtle: `Grind_ApiLimitsPublishAndCheck` writes GVs. On re-init, if the EA had previously published GVs, and new inputs are different, it will WARN and overwrite. That's intended. But if the EA is re-initialized with same inputs, no mismatch. Good.
- Another: The `(int)GlobalVariableGet` cast could overflow if GV was set to a huge double outside int range. But only code sets it. If a user manually sets GV, could truncate. Not a concern.
- Another: The two new GVs are named `GRIND_API_LIMIT_ENTRY_STOP` and `GRIND_API_LIMIT_SOFT_WARN`. They are terminal-wide. The counter's GVs are `GRIND_DAILY_API_COUNT` and `GRIND_DAILY_API_DATE`. No collision. Good.
- `Grind_ApiLimitsApplyInputs` is called before magic lock. If invalid, it sets globals to defines. Then later `GRIND_API_LIMITS` prints defines. Then `API_LIMITS_INVALID` WARN. Good.
- But wait: The spec says "globals defaulting to the defines". In `grind_api_counter.mqh`, globals are initialized:
```
int g_grind_api_entry_stop = GRIND_DAILY_API_ENTRY_STOP;
int g_grind_api_soft_warn = GRIND_DAILY_API_SOFT_WARN;
```
So if `Grind_ApiLimitsApplyInputs` is not called (e.g., in tests), they default. Good.
- In `OnInit`, `Grind_ApiLimitsApplyInputs` is called before `g_grind_telemetry_instance` set. No issue.
- The `api_inputs_ok` variable is const bool at function scope. Used later. Good.
- If `Grind_ApiLimitsApplyInputs` returns false, it sets globals to defines. Then `api_inputs_ok` false. The WARN is emitted. Good.
- If `Grind_ApiLimitsApplyInputs` returns true, globals set to inputs. No WARN. Good.
- Any path where limits in force differ from `GRIND_API_LIMITS`? The print uses `g_grind_api_entry_stop` and `g_grind_api_soft_warn`. So no.
- Any path where `API_LIMITS_CONFIG` reports different? It uses same globals. So no.
- But note: The `GRIND_API_LIMITS` print occurs before `Grind_ApiLimitsPublishAndCheck`. If `Grind_ApiLimitsPublishAndCheck` were to change globals? It doesn't. Good.
- WARN markers before archive can take them? The archive marker function likely enqueues. But if the archive queue is full, marker dropped. That's T-3/T-6. The API markers are emitted once at init, so not high volume. Fine.

T-7 Tests. The collector itself not unit-tested (reads live lists); its parts are. Which behaviour has no test that fails without it? Any assertion in `fxgrind_tests_v22a.mqh` that passes vacuously (left-over Global Variables or globals from earlier test, a reset that does not clear what it should)? What is the smallest seam that would let a test drive the walk loop with a list that changes mid-walk?

Need analyze tests for vacuous passes. Look at tests.

- RS1: uses local array, no globals. Stub vs impl. F/G tags correct? Need check RS1f: `t[2].ticket == 9002 && t[2].kind == ORDER`. In stub (always appends), after A,B,C,D, array size 4: t[0]=A, t[1]=B, t[2]=C (9001 POSITION), t[3]=D. So t[2] is C (ticket 9001, kind POSITION), so assertion fails. In impl, after A, B duplicate dropped, C appended, D appended -> t[0]=A, t[1]=C, t[2]=D. t[2] = 9002 ORDER -> passes. So F correct. RS1g: t[0] fields. Stub: t[0]=A, same. Impl: t[0]=A. Passes both. G correct. RS1e: d==1. Stub d=0, fails. Impl d=1, passes. F correct. So RS1 good.
- RS2: raw duplicate leads to AMBIGUOUS_ADD_LONG. In stub, same. dd with AppendUnique: stub always appends -> count=2, rebuild fails. Impl count=1, rebuild succeeds. F tags correct. But note: RS2a uses `Grind_RebuildBookFromTickets(raw, 2, ...)`. This calls `Grind_ReconFailureCapture` on failure, which sets `g_grind_recon_tickets_last_line`. Then they call `Grind_ReconFailureClear(); Grind_TestResetSideState();`. Good. RS2c uses `dd_count` from AppendUnique. In stub, dd_count=2, rebuild fails -> RS2c fails. In impl, dd_count=1, rebuild succeeds -> RS2c passes. RS2d reason2 == "". Stub fails, impl passes. Good.
- RS3: pure function. Stub returns true always. RS3b: stub true, expected false -> fails. RS3c: stub true, expected false -> fails. RS3d: stub true, expected false -> fails. RS3a true, RS3e true. So 3F 2G. Good.
- RS4: TicketsLogLine. Stub returns "". RS4a expected non-empty -> fails. RS4b expected non-empty -> fails. RS4c StringFind("", "O:9038 +1 more") >=0? StringFind("", substring) returns -1? In MQL5, StringFind returns -1 if not found. So stub fails. RS4d StringFind("", "O:9039") < 0 -> true, passes. So 3F 1G. Good.
- RS5: Capture logs locally. Stub V9 not applied, so `g_grind_recon_tickets_last_line` remains "". RS5a: rebuild fails with I3_LONG_NAKED. Stub? The rebuild function itself is unchanged, so it fails. Passes both. RS5b expects last_line == "RECON_TICKETS reason=I3_LONG_NAKED n=1 P:87654321". Stub: "" -> fails. Impl: V9 sets it -> passes. RS5c: JSON doesn't contain ticket. Both pass. RS5d: heartbeat doesn't contain ticket. Both pass. RS5e: after clear, last_line == "". Both pass. So 1F 4G. Good.
- RS6: helpers. Stub V4 returns false, V5 returns "". RS6a expected non-empty -> fails. RS6b expected non-empty -> fails. RS6c Grind_ReconScanRaced(0,1) expected false. Stub returns false -> passes (G). RS6d expected true. Stub false -> fails. RS6e expected true. Stub false -> fails. So 4F 1G? Wait RS6c is G, so 4F 1G? Let's count: RS6 has 5 assertions: a F, b F, c G, d F, e F -> 4F 1G. Yes.
- AL1: ValidateApiLimitInputs. Stub K5 returns true. AL1a true -> passes G. AL1b true -> passes G. AL1c true -> passes G. AL1d expected false, stub true -> fails F. AL1e expected false, stub true -> fails F. AL1f expected false, stub true -> fails F. So 3F 3G. Good.
- AL2: entry stop at set limit. Stub K2 empty, K10? For AL2, they call `Grind_ApiLimitsSet(1900, 1800);` But K2 is stubbed empty? Wait s3 stubs: K2 empty body. K10 `return true;` (no other line). K4? Wait K4 in s2 is change to comparison. In commit 1 stubs, what about K4? The spec says "V1, V6, V7's global (NOT the reset line...), K1, K3, K4, K6, K7, K8, K9, T1, T2 as written." Then STUBS: V2..., K2 empty body; K5 return true; K10 return true (no other line); K11 return false. So K4 is as written? Wait K4: "Grind_ApiCounterSoftWarnActive compares with g_grind_api_soft_warn; Grind_ApiCounterEntryStopped compares with g_grind_api_entry_stop." That is implemented in commit 1? Actually K4 is part of tests first? The list says "K1, K3, K4, K6, K7, K8, K9, T1, T2 as written." So K4 is applied at commit 1. K1 adds globals defaulting to defines. K3 reset restores globals. So in commit 1, AL2: `Grind_ApiLimitsSet(1900,1800)` calls K2, but K2 is stub empty! Wait s3: "K2 empty body". So `Grind_ApiLimitsSet` does nothing. Thus g_grind_api_entry_stop remains default 1000000. AL2a expects 1900 -> fails F. AL2b: seed 1899, `Grind_ApiCounterEntryStopped()` compares with g_grind_api_entry_stop = 1000000, so false. Expected false -> passes G. AL2c: seed 1900, expected true, but 1900 < 1000000 -> false -> fails F. AL2d: seed 1000000, expected true, 1000000 >= 1000000 -> true -> passes G. So 2F 2G. Good.
- AL3: soft warn. K2 stub empty, so g_grind_api_soft_warn = 999000. AL3a seed 1799, expected false, 1799 < 999000 -> false, passes G. AL3b seed 1800, expected true, 1800 < 999000 -> false -> fails F. AL3c expects g_grind_api_soft_warn == 1800, stub 999000 -> fails F. AL3d seed 999000, expected true, 999000 >= 999000 -> true, passes G. 2F 2G. Good.
- AL4: reset restores defaults. K3 is applied at commit 1? Yes, K3 as written. So AL4a/b pass G. AL4c: seed 1900, expected !EntryStopped(). g_grind_api_entry_stop = 1000000, 1900 < 1000000 -> false, !false = true? Wait AL4c asserts `AssertFalse("AL4c (G)", Grind_ApiCounterEntryStopped());` Actually test: `Grind_ApiCounterTestSeed(1900); AssertFalse("AL4c (G)", Grind_ApiCounterEntryStopped());` So EntryStopped should be false. With default stop 1000000, 1900 < 1000000 -> false. So AssertFalse passes. G. 3G. Good.
- AL5: defaults. K1 sets globals to defines. AL5a expects 1000000, AL5b 999000. Passes G. 2G. Good.
- AL6: invalid inputs keep defines, no halt. Stub K10 returns true (no other line). So `Grind_ApiLimitsApplyInputs` does nothing? Wait K10 is function `Grind_ApiLimitsApplyInputs`. In stub, "K10 `return true;` (no other line)". So it always returns true and does not set globals. AL6a: `Grind_ApiLimitsApplyInputs(1900,1800)` expected true -> passes G. AL6b: expects g_grind_api_entry_stop == 1900. But stub K10 did nothing, globals remain defaults (1000000). So fails F. AL6c: expects soft_warn == 1800, stub 999000 -> fails F. AL6d: `Grind_ApiLimitsApplyInputs(1800,1900)` expected false. Stub returns true -> fails F. AL6e: expects globals == defines. Stub globals already defines -> passes G. AL6f: `Grind_ApiLimitsApplyInputs(0,0)` expected false. Stub returns true -> fails F. So 4F 2G. Good.
- AL7: publish and check. Stub K11 returns false (no other line). AL7a: after reset and delete GVs, `Grind_ApiLimitsSet(1900,1800)` (stub K2 empty? Wait K2 is empty in commit 1, so this does nothing, globals remain defaults). Then `Grind_ApiLimitsPublishAndCheck()` stub returns false. Expected false -> passes G. AL7b: expects GV exists and == 1900. Stub K11 doesn't write GVs. So fails F. AL7c: same for soft 1800, fails F. AL7d: `Grind_ApiLimitsSet(2000,1800)` (no effect), `Grind_ApiLimitsPublishAndCheck()` expected true. Stub returns false -> fails F. AL7e: expects GV stop == 2000. Stub no GV, `(int)GlobalVariableGet`? Actually if GV doesn't exist, GlobalVariableGet returns 0. So 0 != 2000 -> fails F. AL7f: `Grind_ApiLimitsPublishAndCheck()` expected false. Stub returns false -> passes G. So 4F 2G. Good.

Now vacuous passes. Any assertion that passes vacuously due to left-over GVs or globals from earlier test? 
- AL7 starts by `Grind_ApiCounterTestReset(); V22A_DeleteApiLimitGvs();` So it deletes GVs. Good. But `Grind_ApiCounterTestReset` resets globals to defines, not to 1900. Then `Grind_ApiLimitsSet(1900,1800)` is called. In implementation, K2 sets globals. In stub, K2 empty, so globals remain defines. For AL7a, expected false; stub returns false, passes vacuously because no GVs. But that's a G tag, intended to pass at both. The F tags fail. AL7f: after AL7d/e, implementation writes GVs. AL7f expects false because now equal. In stub, no GVs, so `Grind_ApiLimitsPublishAndCheck` stub returns false, passes vacuously. That's a G tag, intended. Is it vacuous? Yes, but it's a guard. Could it pass for wrong reason? In implementation, it should pass because GVs exist and equal. In stub, it passes because stub always returns false. That's the nature of G tags. The prompt asks "Any assertion in fxgrind_tests_v22a.mqh that passes vacuously (left-over Global Variables or globals from an earlier test, a reset that does not clear what it should)?" We need identify if any G tag passes due to not resetting something, so it would also pass if implementation broken in a way. For example, AL7f passes in stub because stub returns false. But in implementation, if `Grind_ApiLimitsPublishAndCheck` always returned false, AL7f would pass, but AL7d would fail. So the suite catches. But individually AL7f is vacuous in stub. Is that a test flaw? It's a G tag, expected to pass at both. The design of G tags is to guard against breaking. AL7f is intended to verify that when equal, no mismatch. But in stub, it passes because function returns false always. So it doesn't verify that the function correctly distinguishes equal from unequal. However, AL7d verifies that it returns true when unequal. Together they cover. But if the function always returned false, AL7d fails. If always returned true, AL7f fails. So combined they are not vacuous. But individually AL7f is vacuous in stub. The question likely wants to identify assertions that could pass even if the feature is broken, due to state not cleared. Let's look for left-over GVs.
- AL7 starts by deleting GVs. Good. But `Grind_ApiCounterTestReset` does not delete the new API limit GVs. The test explicitly deletes. Good.
- RS5: `Grind_ReconFailureClear()` at start. Good. RS5e checks clear. Good.
- RS2: after raw rebuild failure, it calls `Grind_ReconFailureClear(); Grind_TestResetSideState();`. Good. Then dd rebuild. At end, clear and reset. Good.
- RS1: no globals.
- RS4: no globals.
- AL tests: `Grind_ApiCounterTestReset()` at start and end. This resets globals to defines, deletes counter GVs. But does it reset the new API limit GVs? No, K3 only restores globals to defines, not delete GVs. AL7 deletes them at start and end. Other AL tests don't touch GVs. So no left-over GVs affecting them. But wait: AL6 calls `Grind_ApiLimitsApplyInputs`, which in implementation may set globals. Then at end `Grind_ApiCounterTestReset()` restores to defines. Good.
- AL2/AL3 call `Grind_ApiLimitsSet(1900,1800)` then `Grind_ApiCounterTestReset()` at end. Good.
- AL4/AL5 reset at start/end. Good.
- One potential vacuous: AL4c `AssertFalse("AL4c (G)", Grind_ApiCounterEntryStopped());` after seed 1900. This passes if g_grind_api_entry_stop is >1900. If reset failed to restore defaults but left 1900, then EntryStopped would be true (1900 >= 1900) and AssertFalse would fail. But AL4a/b already check globals equal defines. So AL4c is redundant but not vacuous. Actually if K3 reset didn't restore but AL4a/b pass? They check equality to defines, so if not restored, they fail. So AL4c is a stronger check? It seeds 1900, expects not stopped. If stop is 1000000, passes. If stop is 1900, fails. So it checks behavior. Good.
- AL5: just checks globals equal literals. Good.
- AL1: no globals.
- RS3: pure.
- RS6: pure.
- Any test that relies on `g_grind_recon_tickets_last_line` left from a previous test? RS5 starts with clear. RS2 doesn't check last line. RS4 doesn't. Good.

No obvious vacuous assertions due to left-over state. However, there is a possible vacuous G: RS2a/RS2b are G tags. They test that a raw duplicate still fails. In both stub and impl, `Grind_RebuildBookFromTickets` is unchanged, so passes. That's a guard. Fine.
Another: RS5c/RS5d check ticket not in JSON/heartbeat. These pass in both because JSON never had ticket. They are guards. They could pass even if V9 accidentally added ticket to JSON? Wait RS5c checks `g_grind_recon_failure_json` doesn't contain ticket. If V9 (new code) accidentally added ticket to JSON, RS5c would fail. So it's a guard. Good.
RS5d checks heartbeat. Good.

Smallest seam to let a test drive the walk loop with a list that changes mid-walk: The collector reads live lists via `PositionsTotal()`, `PositionGetTicket`, etc. To unit-test the walk loop, need to abstract the list access. Currently, `Grind_ReconCollectBrokerTickets` directly calls MT5 functions. The smallest seam would be to extract the loop body to a function that takes a callback or an interface? In MQL5, no function pointers. Could introduce a test mode with injectable arrays: e.g., add global test arrays for positions and orders and a flag `g_grind_recon_test_active`, and in collector, if active, use those arrays instead of MT5 calls. Then test can simulate a list changing between iterations. Or simpler: extract the inner walk logic into a function that takes a "provider" struct with virtual methods? MQL5 supports structs but not polymorphism? It has interfaces? Actually MQL5 supports interfaces and classes. Could define an interface with methods `PositionsTotal()`, `PositionGetTicket(i)`, etc. But that's heavy. Smallest seam: add a test-only function `Grind_ReconCollectBrokerTicketsFromArrays` that takes arrays of positions and orders and a "change" callback? In MQL5, no callbacks easily. Could use global test arrays and a test flag. For example:
```
bool g_grind_recon_test_active = false;
int g_grind_recon_test_pos_total = 0;
...
```
Then in collector, if test active, use test arrays instead of `PositionsTotal()`. To simulate mid-walk change, the test can set a flag and have a helper that modifies the test arrays when called. But the collector calls `PositionsTotal()` etc. directly. The smallest seam might be to wrap the MT5 list access in functions:
```
int Grind_ReconPositionsTotal() { return PositionsTotal(); }
ulong Grind_ReconPositionGetTicket(int i) { return PositionGetTicket(i); }
...
```
Then in tests, override? MQL5 doesn't support function overriding. Could use macros? Hmm.
Alternatively, extract the walk into a function that takes the total counts and a function to get ticket? Not easy.
Maybe the smallest seam is to make the collector take an optional `const bool test_mode` and use global test arrays. But it's a signature change, which G2 forbids? G2 says callers and existing signatures unchanged. Adding an optional parameter with default value would change signature? It would still compile unchanged. But the spec says no existing signature changes. Could add a new overload? MQL5 doesn't support overloading? It does support function overloading? MQL5 supports function overloading? I think MQL5 does NOT support function overloading (same name different parameters)? Actually MQL5 supports function overloading? In MQL5, you can have multiple functions with same name if different parameters? I think yes, MQL5 supports overloading. But not sure. Safer: add a separate test-only function that duplicates the loop logic but with injectable arrays. But that duplicates code, and the test doesn't test the real collector. The prompt asks "What is the smallest seam that would let a test drive the walk loop with a list that changes mid-walk?" So we can propose: introduce a small provider function abstraction:
```
int Grind_ReconPositionsTotal();
ulong Grind_ReconPositionTicketAt(int i);
...
```
and in production they call MT5; in tests, set a global flag to use test arrays. But that's a design change. The smallest is to add a test hook to `Grind_ReconCollectBrokerTickets` via global flags that make it read from test arrays. Since the collector is in the EA, tests can set globals. This is a seam.

Need also mention that the collector itself is not unit-tested. The tests cover helpers but not the loop. The walk loop's stability and dedupe over multiple walks are untested. The RS2 test only tests AppendUnique and rebuild, not the collector's retry logic. So behavior with no test: the retry loop, the counts before/after, the use of last walk, the marker on walks>1, the interaction of dupes_total across walks. None of that is tested. The smallest seam would be to allow injecting a sequence of list states.

Now GIVENS CHECK details. Need provide quotes.

Let's map quotes.

G1: Quote from `Grind_ReconCollectBrokerTickets`:
```
if(Grind_ReconScanRaced(dupes_total, walks)) {
```
and
```
while(walks < GRIND_RECON_SCAN_MAX_WALKS && !stable) {
```
and
```
count = Grind_ReconAppendUnique(tickets, count,
                    (ulong)PositionGetInteger(POSITION_IDENTIFIER),
...
```
and `Grind_ReconAppendUnique` logic. But need show no marker when no race. `Grind_ReconScanRaced` returns `(dupes > 0 || walks > 1)`. With no list change and no duplicate, walks=1, dupes=0, so false. Quote:
`return (dupes > 0 || walks > 1);` in `Grind_ReconScanRaced`.
Also order: positions then orders. Quote `for(int i = PositionsTotal() - 1; i >= 0; i--) {` and `for(int i = OrdersTotal() - 1; i >= 0; i--) {`. Fields: quote `GRIND_RECON_TICKET_POSITION` and `GRIND_RECON_TICKET_ORDER`. Good.

G2: Quote `int Grind_ReconCollectBrokerTickets(GrindReconTicket &tickets[])` and callers:
`const int count = Grind_ReconCollectBrokerTickets(tickets);` in `Grind_CheckBookInvariants` and `Grind_ReconstructState`. Also `Grind_RebuildBookFromTickets` signature unchanged. Quote.

G3: Quote JSON build no ticket:
```
json += StringFormat(
         "{\"kind\":\"%s\",\"comment\":\"%s\",\"price\":%.5f,\"side_hint\":%s}",
```
No ticket. RECON_SCAN_RACE detail:
```
return StringFormat("{\"dupes\":%d,\"walks\":%d,\"stable\":%s}",
```
No ticket. API markers:
`StringFormat("{\"input_entry_stop\":%d,...` and `StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}",...` and mismatch. No ticket.
Heartbeat embeds `g_grind_recon_failure_json`. Quote `Grind_ReconFailureHeartbeatField()` returns it. But G3 says no ticket reaches heartbeat. Since JSON no ticket. Good.

G4: Quote default inputs:
`input int    InpApiEntryStop       = 1000000;` and `input int    InpApiSoftWarn        = 999000;` in fxgrind.mq5. And `Grind_ValidateApiLimitInputs` returns true. `Grind_ApiLimitsApplyInputs` sets them. No return INIT_FAILED:
`const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);` no return. The invalid block only WARN:
`Grind_ArchiveMarker("WARN", "API_LIMITS_INVALID", "", 0, bad);` no return. Mismatch only WARN:
`Grind_ArchiveMarker("WARN", "API_LIMITS_MISMATCH", "", 0, detail);` no return. No halt/quarantine. But note: API limit can block entries via existing `Grind_ApiCounterEntryStopped`. With defaults 1000000, same as old. The branch doesn't add a new block for mismatch. So G4 VERIFIED.

G5: Quote `Grind_IsQuarantinableReason`:
```
if(reason == "I2_LONG_EXIT_DUP" || reason == "I2_SHORT_EXIT_DUP")
      return true;
   if(reason == "I3_LONG_NAKED" || reason == "I3_SHORT_NAKED")
      return true;
   if(reason == "I4_LONG_ORPHAN_EXIT" || reason == "I4_SHORT_ORPHAN_EXIT")
      return true;
   if(reason == "I6_LONG_EXIT_FILL_ADVERSE" || reason == "I6_SHORT_EXIT_FILL_ADVERSE")
      return true;
   return false;
```
No AMBIGUOUS. VERIFIED.

G6: Quote OnTick:
```
if(!g_grind_halted) {
      Grind_CapPublishOwnExposure(...);
      const bool ok = Grind_ReplayCheckInvariants(...);
```
and `Grind_ReplayInvariantOk`:
```
return Grind_CheckBookInvariants();
```
Actually `Grind_ReplayInvariantOk` returns `Grind_CheckBookInvariants()` if not test active. And `Grind_CheckBookInvariants` calls collector. Init: `Grind_ReconstructState()` in OnInit, and `Grind_ReconstructState` calls `Grind_ReconCollectBrokerTickets(tickets);`. Quote. VERIFIED.

Now T-1 details. Need quote dedupe key:
```
if(tickets[i].ticket == ticket && tickets[i].kind == kind) {
         dupes_io++;
         return count;
      }
```
And comment in spec? No quote from code. We can say MT5 uniqueness assumed. ASSUMED: MT5 order tickets unique and position identifiers unique; a position identifier equals the opening order ticket but kind differs. If a broker ever reuses a ticket across magic or symbol? Ticket is global unique. So no real case. Verdict HOLDS. Smallest fix if any: none. But if paranoid, could use a unique composite (magic, symbol, ticket, kind) but magic/symbol are filtered same for all entries in the walk? Actually collector filters by symbol and magic, so magic same. Ticket uniqueness global. So key sufficient.

But wait: The collector filters by `g_grind_recon_magic` and `_Symbol`. So all entries have same magic and symbol. Ticket AND kind is enough. Could two distinct positions have same POSITION_IDENTIFIER? No. Could a position and an order share ticket and kind? Kind differs. So HOLDS.

T-2 verdict. Need list reasons. Let's enumerate with quotes from rebuild.

Skipped position:
- If layer has exit coverage: `if(!long_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(long_scratch[i])) { return Grind_InvariantFail(... "I4_LONG_ORPHAN_EXIT" ...); }` also short. I4 is quarantinable (G5).
- If no exit coverage: layer not created at all (if no other entry for that layer). No reason. Silent missing layer.
- Could cause I3? If position skipped, layer has no position, so I3 not triggered (I3 requires has_position). So no.
- Could cause I1? I1 requires exit coverage and checks duplicates; if position skipped but exit coverage exists, I4 triggers first. If no exit coverage, no I1.
- Could cause I7? depth decreases.

Skipped exit order/position:
- If layer has position and ExitQRequired: `if(long_scratch[i].has_position && Grind_ExitQRequired(rank, long_count) && !Grind_ReconLayerHasExitCoverage(long_scratch[i])) { ... return Grind_InvariantFail(reason_out, "I3_LONG_NAKED"...); }` I3 quarantinable.
- If exit not required: no I3, book computes formula exit target. Silent.
- Could cause I6? If exit skipped, no coverage, so I6 not checked (I6 only if exit coverage). So no.
- Could cause I4? If position also skipped? That's two skips.
- Could cause I1? no.

Skipped entry order (ENT ORDER layer >=1):
- If add_pending_ticket is 0, no check. `Grind_ReconCheckPendingAddCorrupt` returns true if `add_pending_ticket == 0`. So silent.
- If there was another entry order for same layer, skipping one may avoid AMBIGUOUS_ADD_LONG. That hides a non-quarantinable halt. Quote:
```
if(long_out.add_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_ADD_LONG";
```
If one skipped, add_pending_ticket may be 0 or set once, so no AMBIGUOUS. This is a false negative.
- If add_pending_ticket is set by another? Not by skip.

Skipped L0 entry order:
- `if(c_layer == 0) { if(is_long) { if(long_out.l0_pending_ticket != 0) { reason_out = "AMBIGUOUS_L0_LONG"; ... } long_out.l0_pending_ticket = tickets[i].ticket; } ... }`
- If skipped, l0_pending_ticket remains 0. No check. Silent. Could hide AMBIGUOUS_L0 if two L0 orders and one skipped.

Thus no reason produced by a skip is non-quarantinable. The only non-quarantinable reasons (AMBIGUOUS_*) are *hidden* by skips, not caused. So a single skip does not halt at once; it can hide a halt. Verdict: NEEDS-FIX? The threat is "What a SKIP can still cause." The design relies on skip consequences being quarantinable. That is true for causes. But the ability to hide an AMBIGUOUS for one tick is a real false negative. GV-2 accepted same-count swap. The smallest fix would be to compare ticket sets between walks when a walk is unstable? But GV-2 rejects set comparison. Alternatively, when `dupes_total > 0` or `walks > 1`, we could force a conservative failure? But that would halt on race. Not desired. Or we could, on a raced walk, not use the last walk for AMBIGUOUS checks? That's complex. Given rulings, this is accepted. So verdict HOLDS with caveat? The question asks "Is any of them NOT quarantinable, so that one tick's skip still halts at once, as the duplicate did?" Answer: No, none of the reasons a skip can produce are non-quarantinable. So the specific concern (skip causing immediate halt) does not break. The hidden AMBIGUOUS is a separate false-negative. I'd say T-2: HOLDS (no non-quarantinable reason is *caused* by a skip), but note the false-negative. If we consider the threat as "what a skip can still cause" including hiding, it's a NEEDS-FIX? The prompt says "THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX". I think they want to judge if the skip is still dangerous. Since a skip can hide a non-quarantinable AMBIGUOUS, that means the safety property "a real AMBIGUOUS halts" can fail for one tick. But the next tick likely catches. Is that acceptable? GV-2 explicitly accepts same-count swap. So it's accepted. I'd mark HOLDS with note, or NEEDS-FIX? The smallest fix if any: on a raced walk, if the walk is not stable, maybe don't return the last walk? But GV-3 says use last walk. The prompt says "A skip inside a walk whose counts match (a same-count swap) is accepted (GV-2)." So it's ruled. Thus T-2 should be HOLDS, because the ruling accepts it. The question is to verify that a skip does not halt at once. It doesn't. So HOLDS.

T-3: NEEDS-FIX. Evidence: no throttle in marker. Quote:
```
if(Grind_ReconScanRaced(dupes_total, walks)) {
          const string detail = ...
          Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail);
          Print(Grind_LogTag(), "WARN GRIND_RECON_SCAN ", detail);
       }
```
No time guard. `Grind_ReconScanRaced` returns true if `dupes > 0 || walks > 1`. With nine instances, any list change during a walk triggers. On busy terminal, thousands of WARNs per minute. Archive queue 5000 rows per instance. If filled, markers dropped. Smallest fix: add a per-instance static last-emit timestamp and only emit archive/Print when elapsed > e.g. 10 s or when the detail changes; increment a counter for heartbeat. Or emit only on transition from stable to raced. Quote from archive? Not provided. We can mention.

T-4: Potential issues. Need verdict. Let's analyze if any real bug. 
- `count` and array disagree? `count` is always the return of AppendUnique. Array size after last append is count. But initial `ArrayResize(tickets, 0)` then appends. If `ArrayResize` fails, could disagree. But MQL5 ArrayResize to 0 should succeed. ASSUMED.
- Stale entry survives? `ArrayResize(tickets, 0)` clears. But note: `ArrayResize(tickets, 0)` does not necessarily set elements to default? It sets size to 0, so no stale entries. Next append writes at index 0. Good.
- `stable` reported wrongly? `stable` is count-based. Same-count swap accepted. If a walk is unstable due to count change, loop repeats. If after three walks still unstable, `stable` false. Good. If the loop exits because `walks == GRIND_RECON_SCAN_MAX_WALKS`, `stable` is false because the last iteration set it false. Good.
- But there is a subtle bug: `dupes_total` accumulates over walks. Suppose first walk has a duplicate (dupes_total=1) and is unstable. Second walk is stable and has no duplicate. The returned `count` is from second walk. The marker says `"dupes":1,"walks":2,"stable":true`. That is correct. But what if the first walk had a duplicate *because of a real duplicate entry* that was actually a distinct order? T-1 says impossible. So okay.
- Another subtle: The duplicate counter increments even when the duplicate is the *same* entry re-read due to race. But if the same ticket and kind appears twice legitimately? T-1 says no. So okay.
- Cost: up to three walks per tick per instance. With nine instances, 27 walks per tick. On a busy tick, could be CPU heavy. But not a correctness bug. Mention as performance risk.
- Any path where returned count and array disagree? If `ArrayResize(tickets, 0)` is called, but `tickets` is a dynamic array passed by reference. It resets. Good.
- One potential: In `Grind_ReconAppendUnique`, if `count` is greater than actual array size (shouldn't happen), it would access out of bounds. But count is maintained.
- Another: The loop reads `PositionsTotal()` in the `for` condition? No, `for(int i = PositionsTotal() - 1; i >= 0; i--)` evaluates `PositionsTotal()` once. But inside the loop, it calls `PositionGetTicket(i)`. If the list shrinks, `i` might be >= new total. `PositionGetTicket(i)` returns 0, then `continue`. That's fine. If the list grows, new entries at higher indices are not processed. But totals after will differ, so walk repeats. Good.
- What about the orders loop? Same.
- `stable` is computed after both loops using `PositionsTotal()` and `OrdersTotal()` at that moment. If a list changes during the positions loop and then changes back during the orders loop, counts match. Accepted.
- Verdict: HOLDS. No correctness bug in loop mechanics, except accepted GV-2 and performance. Smallest fix if any: none required, but could add a cap on retries (already 3). Maybe add a log if ArrayResize fails. Not necessary.

T-5: HOLDS. Evidence: same array and count used. Quote both JSON and line loops. `%I64u` correct. Potential issue: alternating failure/success prints every time because success clears memory. That's intended. But could cause log spam if alternating. Not a bug. Verdict HOLDS. Smallest fix: none.

T-6: HOLDS mostly. Need check if limits in force differ from report. The only potential: `Grind_ApiLimitsApplyInputs` runs before magic lock. If magic lock fails, OnInit returns INIT_FAILED, no report. So no mismatch. If inputs invalid, globals set to defines, `GRIND_API_LIMITS` prints defines, `API_LIMITS_INVALID` shows inputs and using, `API_LIMITS_CONFIG` shows defines. Consistent. If inputs valid, globals set to inputs, reports match. The `(int)` cast of `GlobalVariableGet` is safe for int values. The GVs persist; mismatch WARN on next init if different. That's intended. WARN markers emitted after archive configured. But wait: `Grind_ArchiveConfigure` is called before `Grind_ReconstructState`. Let's verify order in OnInit. From code:
- magic lock
- set g_grind_telemetry_instance, etc.
- Grind_EngineConfigureAdr152
- Grind_Adr152ResetDueFlags
- Grind_ScalpTelemetryConfigure
- Grind_ArchiveConfigure
- ...
- Grind_ReplayInit
- Grind_ReconstructState
...
- later prints and markers.
So archive configured. Good.
- One potential: `Grind_ApiLimitsApplyInputs` is called before `Grind_ArchiveConfigure`. It doesn't archive. So fine.
- If `Grind_ArchiveConfigure` is disabled, markers not archived. But that's expected.
- Any path where WARN markers emitted before archive can take them? If `Grind_ArchiveMarker` uses `g_grind_archive_enabled` and queue, it's after configure. So no.
- Verdict HOLDS. Smallest fix: none.

T-7: NEEDS-FIX (test gap). The collector itself not tested. The retry loop, stability check, dedupe across walks, marker emission are untested. Also, there may be a vacuous assertion: AL7f passes in stub because stub returns false always. But as a G tag, it's designed to pass at both. However, it doesn't verify that the function returns false *because* the GVs match; it could pass if the function always returns false. But AL7d fails if always false. So combined, it's okay. Another vacuous: AL7a passes in stub because stub returns false, but implementation also returns false when no GVs. That's correct. AL7f is a guard that the function returns false when equal. In stub, it passes for wrong reason (function always false). But the suite as a whole catches the always-false case via AL7d. So not a test gap? The prompt asks "Any assertion ... that passes vacuously (left-over Global Variables or globals from an earlier test, a reset that does not clear what it should)?" I think we should mention AL7f is vacuous in commit 1 because K11 stub returns false; it would also pass if the implementation forgot to compare and always returned false, but AL7d catches that. AL7b/c/e fail if not implemented. So the suite is adequate for that function. But the collector loop itself has no test. The smallest seam: introduce a test-mode provider for the broker list. For example, add a test flag and arrays:
```
bool g_grind_recon_test_scan_active = false;
int g_grind_recon_test_pos_total = 0;
ulong g_grind_recon_test_pos_ticket[];
...
```
Then in `Grind_ReconCollectBrokerTickets`, if active, use these instead of MT5 calls. The test can set a sequence of list states and simulate changes between index reads via a callback that mutates the test arrays when a certain index is accessed. That's more complex. Alternatively, extract the loop body to a function that takes a function pointer? MQL5 doesn't have function pointers. But it does have virtual methods. The smallest seam might be to define an interface `IGrindReconListProvider` with methods `PositionsTotal()`, `PositionGetTicket(i)`, etc., and have production use a concrete class. That's larger. Another smallest seam: make the collector take two arrays of `GrindReconTicket` and a "change schedule"? Not testing the actual walk. The prompt asks "What is the smallest seam that would let a test drive the walk loop with a list that changes mid-walk?" I'd say: add a test-only hook at the top of `Grind_ReconCollectBrokerTickets` that, when a global test flag is set, calls a test function that returns the list for the current walk index and can inject a change. But that's essentially mocking the MT5 calls. The smallest practical: wrap the MT5 list access in small functions (e.g., `Grind_ReconPositionsTotal()`, `Grind_ReconPositionTicketAt(i)`, `Grind_ReconPositionsTotalAfterWalk()`), and add test globals that override those functions. Since they are functions, tests can set a global flag and arrays. This is a seam. We can describe.

Also, test gap: No test for `Grind_ReconCollectBrokerTickets` itself. So behavior like "last walk returned", "dupes_total accumulates", "stable false after 3 walks", "marker fired" has no test that fails without it. The helpers are tested, but the integration is not. The smallest seam is to allow injecting a sequence of list states (positions/orders totals and tickets) into the collector, perhaps by adding a test-only parallel implementation? But the prompt wants smallest seam. I'll propose: add optional test arrays and a test active flag; in the collector, replace `PositionsTotal()` with `Grind_ReconTestPositionsTotal()` etc. But to simulate mid-walk changes, the test needs to change the arrays between calls. That can be done by having a test callback index counter that mutates the test arrays when `Grind_ReconTestPositionGetTicket(i)` is called for a specific i. This is feasible.

Now PREMISE VERDICT. Is branch safe to merge to main after Monday build and deploy on IC fleets? Need consider T-3 (unthrottled WARN) is a real risk to archive/telemetry. It could flood archive queue, drop important markers. That is a NEEDS-FIX before deployment? The prompt asks "is the branch safe to merge ... and deploy". Given T-3 risk, I'd say NOT SAFE until the RECON_SCAN_RACE marker is throttled. Also T-2 hidden AMBIGUOUS is accepted by GV-2, but T-3 is a new operational risk. The branch otherwise safe. So PREMISE VERDICT: NEEDS-FIX (throttle) before merge/deploy. If throttled, safe. Also note test gap for collector loop; tests can't see it. But the ruling says deployed not before Monday build. So verdict: do not merge until T-3 fixed. The smallest fix is throttle.

Need also consider T-4 performance: up to 3 walks per tick per instance. On nine instances, could be CPU heavy but likely okay. T-3 is the main.

Now TEST GAPS. Summarize: collector itself untested; retry loop untested; marker volume untested; no test for `Grind_ReconCollectBrokerTickets` dedupe across walks; no test for same-count swap; no test for last walk used; no test for `dupes_total` accumulation; no test for `stable` false after 3 walks. Also AL7f vacuous as noted. Smallest seam: injectable list provider.

Need also mention G1-G6 all VERIFIED. Let's ensure G4 wording: "no path added by this branch returns INIT_FAILED, halts, quarantines or blocks an entry for an API limit." The branch adds inputs; if set valid but low, it can block entries via existing `Grind_ApiCounterEntryStopped`. Is that a "path added by this branch"? The path exists before; this branch just changes the threshold. The G4 says "for an API limit" maybe means the invalid/mismatch handling. I'll mark VERIFIED with note: the only entry block remains the pre-existing `Grind_ApiCounterEntryStopped`; the branch adds no new block for invalid or mismatch. Quote `Grind_ApiLimitsApplyInputs` no INIT_FAILED; `API_LIMITS_INVALID` WARN only; `API_LIMITS_MISMATCH` WARN only.

G5: quote.

G6: quote OnTick and init.

Now let's formulate final answer. Must be in sections. No preamble. Cite file, function, quote. Use quotes one line or part. Need be precise. Since no line numbers, we can say `fxgrind.mq5, OnInit` and quote. We can use relative line numbers? The prompt says cite file, function and QUOTE the line. We can include function names.

Need ensure no claim without quote. So every verdict should have quotes.

Let's draft.

GIVENS CHECK

G1: VERIFIED.
Evidence: `grind_recon.mqh, Grind_ReconCollectBrokerTickets`: `while(walks < GRIND_RECON_SCAN_MAX_WALKS && !stable) {` and `stable = Grind_ReconScanStable(positions_before, orders_before, PositionsTotal(), OrdersTotal());`. With no change, first walk sets stable true, loop exits. `Grind_ReconScanRaced` returns `(dupes > 0 || walks > 1);` so with walks=1, dupes=0 no marker. Same order: `for(int i = PositionsTotal() - 1; i >= 0; i--)` then `for(int i = OrdersTotal() - 1; i >= 0; i--)`. Same fields: positions use `(ulong)PositionGetInteger(POSITION_IDENTIFIER)` and `GRIND_RECON_TICKET_POSITION`; orders use `ticket` and `GRIND_RECON_TICKET_ORDER`.

G2: VERIFIED.
`int Grind_ReconCollectBrokerTickets(GrindReconTicket &tickets[])` unchanged. Callers: `const int count = Grind_ReconCollectBrokerTickets(tickets);` in `Grind_CheckBookInvariants` and `Grind_ReconstructState`. `Grind_RebuildBookFromTickets` signature unchanged: `bool Grind_RebuildBookFromTickets(const GrindReconTicket &tickets[], const int ticket_count, ...)`.

G3: VERIFIED.
JSON: `json += StringFormat("{\"kind\":\"%s\",\"comment\":\"%s\",\"price\":%.5f,\"side_hint\":%s}", ...` no ticket. RECON_SCAN_RACE: `return StringFormat("{\"dupes\":%d,\"walks\":%d,\"stable\":%s}", ...`. API markers: `StringFormat("{\"input_entry_stop\":%d,\"input_soft_warn\":%d,\"using_entry_stop\":%d,\"using_soft_warn\":%d}", ...` and `StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}", ...` and mismatch detail. Heartbeat embeds `g_grind_recon_failure_json` via `Grind_ReconFailureHeartbeatField()`.

G4: VERIFIED.
Defaults: `input int    InpApiEntryStop       = 1000000;` and `input int    InpApiSoftWarn        = 999000;`. `Grind_ValidateApiLimitInputs` returns `(entry_stop >= 1 && soft_warn >= 1 && soft_warn <= entry_stop);`. `Grind_ApiLimitsApplyInputs` on invalid: `Grind_ApiLimitsSet(GRIND_DAILY_API_ENTRY_STOP, GRIND_DAILY_API_SOFT_WARN); return false;`. OnInit: `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(...)` no return. Invalid block: `Grind_ArchiveMarker("WARN", "API_LIMITS_INVALID", "", 0, bad); Print(...);` no return. Mismatch: `Grind_ArchiveMarker("WARN", "API_LIMITS_MISMATCH", "", 0, detail); Print(...);` no return. No INIT_FAILED/halt/quarantine for limits. Note pre-existing entry block remains `Grind_ApiCounterEntryStopped`.

G5: VERIFIED.
`grind_quarantine.mqh, Grind_IsQuarantinableReason`: quotes for I2, I3, I4, I6, then `return false;`. No AMBIGUOUS.

G6: VERIFIED.
OnTick: `if(!g_grind_halted) { ... const bool ok = Grind_ReplayCheckInvariants(...); ... }` and `Grind_ReplayInvariantOk` returns `Grind_CheckBookInvariants();`. `Grind_CheckBookInvariants` calls `const int count = Grind_ReconCollectBrokerTickets(tickets);`. Init: `Grind_ReconstructState` calls `const int count = Grind_ReconCollectBrokerTickets(tickets);`.

T-1: HOLDS.
Key: `if(tickets[i].ticket == ticket && tickets[i].kind == kind) { dupes_io++; return count; }`. ASSUMED: MT5 order tickets are unique and POSITION_IDENTIFIER is unique; a position identifier may equal the opening order ticket but kind differs. No real case of two distinct broker entries sharing ticket AND kind. Same entry under both kinds was appended twice before too, because old collector had no dedupe. No fix.

T-2: HOLDS (with accepted false-negative).
List reasons:
- Skipped position: if exit coverage present, `if(!long_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(long_scratch[i])) { return Grind_InvariantFail(... "I4_LONG_ORPHAN_EXIT" ...); }` (and short). I4 is quarantinable. If no exit coverage, layer is simply absent; no reason.
- Skipped exit order/position: if position and ExitQRequired, `return Grind_InvariantFail(reason_out, "I3_LONG_NAKED", ...);` (and short). I3 quarantinable. If exit not required, no reason.
- Skipped entry order layer >=1: `if(add_pending_ticket == 0) return true;` in `Grind_ReconCheckPendingAddCorrupt`; if skipped, no reason. It can hide `AMBIGUOUS_ADD_LONG` if two entry orders existed: `if(long_out.add_pending_ticket != 0) { reason_out = "AMBIGUOUS_ADD_LONG"; ... }`.
- Skipped L0 entry order: `if(long_out.l0_pending_ticket != 0) { reason_out = "AMBIGUOUS_L0_LONG"; ... }`; if skipped, no reason. Can hide AMBIGUOUS_L0.
No reason *caused* by a skip is non-quarantinable. A skip does not halt at once; it can hide a non-quarantinable AMBIGUOUS for one tick. That is accepted by GV-2. No smallest fix without adding set comparison (rejected).

T-3: NEEDS-FIX.
Evidence: `if(Grind_ReconScanRaced(dupes_total, walks)) { ... Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail); Print(Grind_LogTag(), "WARN GRIND_RECON_SCAN ", detail); }` with `Grind_ReconScanRaced` `return (dupes > 0 || walks > 1);`. No throttle. On nine instances, any list change during a walk triggers. Busy terminal can produce thousands of WARNs/min. Archive queue 5000 rows per instance; if filled, markers dropped. Smallest fix: throttle per instance, e.g., emit marker/Print at most once per 10 s (or on state change), and keep a count in heartbeat. Quote if needed.

T-4: HOLDS (with performance note).
Evidence: `count = 0; ArrayResize(tickets, 0);` per walk. `count = Grind_ReconAppendUnique(...)` always returns new count and resizes. `dupes_total` accumulates. `stable = Grind_ReconScanStable(...)`. No path where count/array disagree (except ignored ArrayResize failure, existing pattern). `stable` is count-stable, not snapshot-stable; same-count swap accepted (GV-2). Cost up to 3 walks per tick per instance. No fix required.

T-5: HOLDS.
Evidence: `Grind_ReconTicketsLogLine` uses `tickets[i].ticket` and `tickets[i].kind` for i<emit. JSON uses same `tickets` and `ticket_count` in `Grind_ReconFailureCapture`; both use `MathMin(ticket_count, GRIND_RECON_FAILURE_MAX_EMIT)`. `%I64u` is correct for ulong in MQL5 (ASSUMED). Memory reset: `Grind_ReconFailureClear` sets `g_grind_recon_tickets_last_line = "";` and is called on success. Alternating failure/success prints every failure. No mismatch. No fix.

T-6: HOLDS.
Evidence: `Grind_ApiLimitsApplyInputs` runs in OnInit before magic lock: `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);`. Reports use same globals: `Print("GRIND_API_LIMITS entry_stop=", g_grind_api_entry_stop, " soft_warn=", g_grind_api_soft_warn);` and `Grind_ArchiveMarker("INFO", "API_LIMITS_CONFIG", "", 0, StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}", g_grind_api_entry_stop, g_grind_api_soft_warn));`. `(int)GlobalVariableGet` safe for ints. GVs persist; mismatch WARN is intended. WARN markers are after `Grind_ArchiveConfigure` and `LATTICE_CONFIG`; archive configured. No path of divergence. No fix.

T-7: NEEDS-FIX (test gap).
Evidence: No test calls `Grind_ReconCollectBrokerTickets`. Tests cover `Grind_ReconAppendUnique`, `Grind_ReconScanStable`, `Grind_ReconScanRaced`, `Grind_ReconScanDetail`, `Grind_ReconTicketsLogLine`, and API helpers. The retry loop, last-walk return, `dupes_total` accumulation, `stable` false after 3 walks, and marker emission have no test. AL7f is vacuous in stub: `AssertFalse("AL7f (G)", Grind_ApiLimitsPublishAndCheck());` passes because stub K11 returns false always; it would also pass if implementation always returned false, but AL7d catches that. Smallest seam: add a test-only provider for the broker lists. E.g., globals `g_grind_recon_test_scan_active`, arrays for positions/orders, and in `Grind_ReconCollectBrokerTickets` branch to `Grind_ReconTestPositionsTotal()` etc.; a test can mutate the test arrays between index accesses to simulate a mid-walk change. This is the smallest seam to drive the walk loop.

PREMISE VERDICT: NOT SAFE to merge/deploy until T-3 fixed. The unthrottled `RECON_SCAN_RACE` WARN on every raced walk can flood the archive queue and Experts log on the nine-instance IC fleets, risking dropped archive rows and lost telemetry. With a throttle (once per N seconds or count in heartbeat), the branch is otherwise safe: G1-G6 verified, T-1/T-2/T-4/T-5/T-6 hold, T-7 is a test gap not a production bug. The branch should not merge before Monday build until T-3 is fixed.

TEST GAPS: summarize.

Need include line count? The prompt says "This message has a line count at the bottom" and at bottom "Line count: 143". Maybe final answer should have a line count? The OUTPUT sections don't mention. I can add at very end "Line count: X" but that might violate "No preamble". I think ignore.

Let's ensure quotes are accurate. I'll use exact text from code.

Check quote for T-2: `if(!long_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(long_scratch[i])) { return Grind_InvariantFail(reason_out, "I4_LONG_ORPHAN_EXIT", ...); }` In code, it's spread. I can quote part: `return Grind_InvariantFail(reason_out, "I4_LONG_ORPHAN_EXIT",` and for short. Also `if(long_scratch[i].has_position && Grind_ExitQRequired(rank, long_count) && !Grind_ReconLayerHasExitCoverage(long_scratch[i])) { ... return Grind_InvariantFail(reason_out, "I3_LONG_NAKED",`. Good.

Check T-2 entry order: `if(add_pending_ticket == 0) return true;` in `Grind_ReconCheckPendingAddCorrupt`. Quote: `if(add_pending_ticket == 0) return true;`. And `if(long_out.add_pending_ticket != 0) { reason_out = "AMBIGUOUS_ADD_LONG";`. Good.

T-3 quote: `Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail);` and `Print(Grind_LogTag(), "WARN GRIND_RECON_SCAN ", detail);`. Also `return (dupes > 0 || walks > 1);`.

T-4 quote: `count = 0; ArrayResize(tickets, 0);` and `stable = Grind_ReconScanStable(positions_before, orders_before, PositionsTotal(), OrdersTotal());`.

T-5 quote: `s += StringFormat(" %s:%I64u", tickets[i].kind == GRIND_RECON_TICKET_POSITION ? "P" : "O", tickets[i].ticket);` and JSON `json += StringFormat("{\"kind\":\"%s\",\"comment\":\"%s\",\"price\":%.5f,\"side_hint\":%s}", ...`. And reset `g_grind_recon_tickets_last_line = "";`.

T-6 quote: `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);` and `Print("GRIND_API_LIMITS entry_stop=", g_grind_api_entry_stop, " soft_warn=", g_grind_api_soft_warn);` and `Grind_ArchiveMarker("INFO", "API_LIMITS_CONFIG", "", 0, StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}", g_grind_api_entry_stop, g_grind_api_soft_warn));`.

T-7 quote: no test calls `Grind_ReconCollectBrokerTickets`. I can quote a test call to show coverage: `Grind_ReconAppendUnique` in RS1, `Grind_ReconScanStable` in RS3, etc. And AL7f: `AssertFalse("AL7f (G)", Grind_ApiLimitsPublishAndCheck());`. Seam: describe.

Now final answer. Need be concise but exhaustive. Desired oververbosity 5. We can use bullet lists. Ensure sections in order. No preamble. Let's write.

## Final Report

## GIVENS CHECK

**G1 — VERIFIED.**  
`grind_recon.mqh, Grind_ReconCollectBrokerTickets`: `while(walks < GRIND_RECON_SCAN_MAX_WALKS && !stable) {` and `stable = Grind_ReconScanStable(positions_before, orders_before, PositionsTotal(), OrdersTotal());`. With no list change the first walk sets `stable = true`, so the loop exits with `walks = 1`. `grind_recon.mqh, Grind_ReconScanRaced`: `return (dupes > 0 || walks > 1);` — with `dupes = 0` and `walks = 1` it returns false, so no marker. Order is unchanged: `for(int i = PositionsTotal() - 1; i >= 0; i--)` then `for(int i = OrdersTotal() - 1; i >= 0; i--)`. Fields are unchanged: positions use `(ulong)PositionGetInteger(POSITION_IDENTIFIER)` and `GRIND_RECON_TICKET_POSITION`; orders use `ticket` and `GRIND_RECON_TICKET_ORDER`.

**G2 — VERIFIED.**  
`grind_recon.mqh`: `int Grind_ReconCollectBrokerTickets(GrindReconTicket &tickets[])` is unchanged. Both callers are unchanged: `grind_recon.mqh, Grind_CheckBookInvariants`: `const int count = Grind_ReconCollectBrokerTickets(tickets);`; `grind_recon.mqh, Grind_ReconstructState`: `const int count = Grind_ReconCollectBrokerTickets(tickets);`. `Grind_RebuildBookFromTickets` signature is unchanged: `bool Grind_RebuildBookFromTickets(const GrindReconTicket &tickets[], const int ticket_count, ...`.

**G3 — VERIFIED.**  
The failure JSON is ticket-free: `grind_recon.mqh, Grind_ReconFailureCapture`: `json += StringFormat("{\"kind\":\"%s\",\"comment\":\"%s\",\"price\":%.5f,\"side_hint\":%s}", ...`. `RECON_SCAN_RACE` carries counts only: `grind_recon.mqh, Grind_ReconScanDetail`: `return StringFormat("{\"dupes\":%d,\"walks\":%d,\"stable\":%s}", ...`. API markers carry limits only: `fxgrind.mq5, OnInit`: `StringFormat("{\"input_entry_stop\":%d,\"input_soft_warn\":%d,\"using_entry_stop\":%d,\"using_soft_warn\":%d}", ...` and `StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}", ...`; `grind_api_counter.mqh, Grind_ApiLimitsPublishAndCheck`: `StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d,\"published_entry_stop\":%d,\"published_soft_warn\":%d}", ...`. The heartbeat embeds only `g_grind_recon_failure_json` via `Grind_ReconFailureHeartbeatField()`.

**G4 — VERIFIED.**  
Defaults: `fxgrind.mq5`: `input int    InpApiEntryStop       = 1000000;` and `input int    InpApiSoftWarn        = 999000;`. Validation: `grind_pure.mqh, Grind_ValidateApiLimitInputs`: `return (entry_stop >= 1 && soft_warn >= 1 && soft_warn <= entry_stop);`. Invalid inputs fall back: `grind_api_counter.mqh, Grind_ApiLimitsApplyInputs`: `Grind_ApiLimitsSet(GRIND_DAILY_API_ENTRY_STOP, GRIND_DAILY_API_SOFT_WARN); return false;`. OnInit does not fail: `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);`. The invalid branch only warns: `Grind_ArchiveMarker("WARN", "API_LIMITS_INVALID", "", 0, bad); Print("WARN API_LIMITS_INVALID ", bad);`. Mismatch only warns: `Grind_ArchiveMarker("WARN", "API_LIMITS_MISMATCH", "", 0, detail); Print("WARN API_LIMITS_MISMATCH ", detail);`. No new `INIT_FAILED`, halt, quarantine, or entry block for an API limit value/mismatch. The pre-existing entry block at `Grind_ApiCounterEntryStopped()` remains.

**G5 — VERIFIED.**  
`grind_quarantine.mqh, Grind_IsQuarantinableReason`: `if(reason == "I2_LONG_EXIT_DUP" || reason == "I2_SHORT_EXIT_DUP") return true;`, `if(reason == "I3_LONG_NAKED" || reason == "I3_SHORT_NAKED") return true;`, `if(reason == "I4_LONG_ORPHAN_EXIT" || reason == "I4_SHORT_ORPHAN_EXIT") return true;`, `if(reason == "I6_LONG_EXIT_FILL_ADVERSE" || reason == "I6_SHORT_EXIT_FILL_ADVERSE") return true;`, `return false;`. No `AMBIGUOUS_*` is quarantinable.

**G6 — VERIFIED.**  
Per tick while not halted: `fxgrind.mq5, OnTick`: `if(!g_grind_halted) { ... const bool ok = Grind_ReplayCheckInvariants(...);`. `grind_replay.mqh, Grind_ReplayInvariantOk`: `return Grind_CheckBookInvariants();`. `grind_recon.mqh, Grind_CheckBookInvariants`: `const int count = Grind_ReconCollectBrokerTickets(tickets);`. At init: `grind_recon.mqh, Grind_ReconstructState`: `const int count = Grind_ReconCollectBrokerTickets(tickets);`, called from `fxgrind.mq5, OnInit`: `if(!Grind_ReconstructState())`.

---

## T-1 — The dedupe key

**VERDICT: HOLDS.**  
`grind_recon.mqh, Grind_ReconAppendUnique`: `if(tickets[i].ticket == ticket && tickets[i].kind == kind) { dupes_io++; return count; }`. ASSUMED: in MT5, order tickets are globally unique and `POSITION_IDENTIFIER` is unique; a position identifier may equal the ticket of the order that opened it, but the kind differs (`GRIND_RECON_TICKET_POSITION` vs `GRIND_RECON_TICKET_ORDER`). Therefore no real case of two distinct broker entries sharing ticket AND kind exists: two orders cannot share a ticket, two positions cannot share a position identifier, and an order and position with the same number differ by kind. The same entry under both kinds was already counted twice before this branch because the old collector had no dedupe. No fix required.

---

## T-2 — What a SKIP can still cause

**VERDICT: HOLDS** (with the accepted GV-2 false-negative).  
A single skipped entry can produce:

- **Skipped position:** if exit coverage exists, `grind_recon.mqh, Grind_RebuildBookFromTicketsInner`: `if(!long_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(long_scratch[i])) { return Grind_InvariantFail(reason_out, "I4_LONG_ORPHAN_EXIT",` (and the short equivalent). `I4_*_ORPHAN_EXIT` is quarantinable. If no exit coverage exists, the layer is simply absent; no reason is produced.
- **Skipped exit order or exit position:** if the layer has a position and `Grind_ExitQRequired(rank, count)`, `return Grind_InvariantFail(reason_out, "I3_LONG_NAKED",` (and short). `I3_*_NAKED` is quarantinable. If exit is not required, no reason is produced.
- **Skipped entry order for layer >= 1:** `Grind_ReconCheckPendingAddCorrupt`: `if(add_pending_ticket == 0) return true;` — skipping the order leaves `add_pending_ticket == 0`, so no reason. It can hide a real `AMBIGUOUS_ADD_LONG`: `if(long_out.add_pending_ticket != 0) { reason_out = "AMBIGUOUS_ADD_LONG";`.
- **Skipped L0 entry order:** `grind_recon.mqh`: `if(long_out.l0_pending_ticket != 0) { reason_out = "AMBIGUOUS_L0_LONG";` — skipping leaves `l0_pending_ticket == 0`, so no reason. It can hide a real `AMBIGUOUS_L0_LONG`.

No reason *caused* by a skip is non-quarantinable: skips cause only `I3_*_NAKED` / `I4_*_ORPHAN_EXIT` (both quarantinable) or nothing. A skip does **not** halt at once as the duplicate did. It can hide a non-quarantinable `AMBIGUOUS_*` for one tick, which is the accepted GV-2 same-count-swap risk. The only fix would be a ticket-set comparison between walks, which is explicitly rejected by GV-2.

---

## T-3 — Marker and log volume

**VERDICT: NEEDS-FIX.**  
`grind_recon.mqh, Grind_ReconCollectBrokerTickets`:  
`if(Grind_ReconScanRaced(dupes_total, walks)) { ... Grind_ArchiveMarker("WARN", "RECON_SCAN_RACE", "", 0, detail); Print(Grind_LogTag(), "WARN GRIND_RECON_SCAN ", detail); }`.  
`grind_recon.mqh, Grind_ReconScanRaced`: `return (dupes > 0 || walks > 1);`.  
There is no throttle. On a nine-instance terminal, any order/position list change during any walk triggers the marker. On a busy terminal or FOMC-like burst, the walk can race many times per tick, on every instance. The archive queue holds 5000 rows per instance; if filled, an archive batch answered 400 is dropped. Unthrottled `RECON_SCAN_RACE` WARNs can therefore flood the archive queue and the Experts log, causing loss of higher-value markers and telemetry.  
**Smallest fix:** throttle per instance — emit the marker/Print at most once per N seconds (e.g. 10 s) or only on state change, and keep a count in the heartbeat. The marker already carries only counts, so no ticket exposure is added.

---

## T-4 — The walk loop

**VERDICT: HOLDS.**  
`grind_recon.mqh, Grind_ReconCollectBrokerTickets`: `count = 0; ArrayResize(tickets, 0);` per walk. Every append returns the new count: `count = Grind_ReconAppendUnique(...)`, and `Grind_ReconAppendUnique` resizes to `count + 1` and returns `count + 1`. Therefore `count` and the array size agree. `dupes_total` accumulates across walks, as intended. `stable = Grind_ReconScanStable(positions_before, orders_before, PositionsTotal(), OrdersTotal());` is a count check, not a snapshot check; a same-count swap is accepted by GV-2. If three walks remain unstable, the loop exits with `stable == false`, and the last walk is returned. Cost is up to three walks per tick per instance; on nine instances this is a CPU load risk but not a correctness bug. No fix required. (ASSUMED: `ArrayResize(tickets, 0)` and `ArrayResize(tickets, count + 1)` do not fail; the code ignores their return values, as did the old collector.)

---

## T-5 — RECON_TICKETS

**VERDICT: HOLDS.**  
`grind_recon.mqh, Grind_ReconTicketsLogLine`: `s += StringFormat(" %s:%I64u", tickets[i].kind == GRIND_RECON_TICKET_POSITION ? "P" : "O", tickets[i].ticket);`.  
`grind_recon.mqh, Grind_ReconFailureCapture` builds the JSON from the same `tickets` and `ticket_count`: `json += StringFormat("{\"kind\":\"%s\",\"comment\":\"%s\",\"price\":%.5f,\"side_hint\":%s}", ...`. Both use `MathMin(ticket_count, GRIND_RECON_FAILURE_MAX_EMIT)`, so order, count, and truncation at 40 match. `%I64u` is the correct MQL5 format for `ulong` (ASSUMED). Memory reset is `grind_recon_failure.mqh, Grind_ReconFailureClear`: `g_grind_recon_tickets_last_line = "";`, called on rebuild success. A failure alternating with success prints every time, which is intended. No fix required.

---

## T-6 — The API limit inputs

**VERDICT: HOLDS.**  
`fxgrind.mq5, OnInit`: `const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);` runs before the magic lock. The in-force values are the globals: `Print("GRIND_API_LIMITS entry_stop=", g_grind_api_entry_stop, " soft_warn=", g_grind_api_soft_warn);`. `API_LIMITS_CONFIG` reports the same globals: `Grind_ArchiveMarker("INFO", "API_LIMITS_CONFIG", "", 0, StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}", g_grind_api_entry_stop, g_grind_api_soft_warn));`. `(int)GlobalVariableGet` is safe for the integer limits set by code. The Global Variables persist, so a later init with different limits WARNs and overwrites — that is GV-7. The WARN markers are emitted after `Grind_ArchiveConfigure` and after `LATTICE_CONFIG`, so the archive is configured. No path of divergence found. No fix required.

---

## T-7 — Tests

**VERDICT: NEEDS-FIX (test gap).**  
No test calls `Grind_ReconCollectBrokerTickets`. The tests cover `Grind_ReconAppendUnique` (RS1, RS2), `Grind_ReconScanStable` (RS3), `Grind_ReconScanRaced`/`Detail` (RS6), `Grind_ReconTicketsLogLine` (RS4), and the API helpers (AL1–AL7). The retry loop, last-walk return, `dupes_total` accumulation, `stable == false` after three walks, and `RECON_SCAN_RACE` emission have no test that fails without the implementation.  
`fxgrind_tests_v22a.mqh, Test_AL7_PublishAndCheck`: `AssertFalse("AL7f (G)", Grind_ApiLimitsPublishAndCheck());` passes vacuously in the stub because K11 is stubbed to `return false;`. It would also pass if the implementation always returned false, but `AL7d` catches that.  
**Smallest seam:** add a test-only provider for the broker lists — e.g. globals `g_grind_recon_test_scan_active`, arrays for test positions/orders, and in `Grind_ReconCollectBrokerTickets` branch to `Grind_ReconTestPositionsTotal()`, `Grind_ReconTestPositionTicketAt(i)`, etc. A test can then mutate the test arrays between index accesses to simulate a mid-walk change and drive the real walk loop.

---

## PREMISE VERDICT

**NOT SAFE to merge to `main` or deploy on the IC fleets until T-3 is fixed.**  
G1–G6 are verified. T-1, T-2, T-4, T-5 and T-6 hold. T-7 is a test gap, not a production bug. The blocker is T-3: the unthrottled `RECON_SCAN_RACE` WARN and Print fire on every raced walk, on every tick, on every instance. On the nine-instance IC fleets a busy terminal can produce far more than the archive queue’s 5000 rows per instance, risking dropped archive rows and lost telemetry. The smallest fix is a per-instance throttle (once per N seconds, or on state change) plus a count in the heartbeat. With that throttle, the branch is otherwise safe to merge after the Monday build and to deploy on the IC fleets.

---

## TEST GAPS

- No test for `Grind_ReconCollectBrokerTickets`: the walk loop, retry logic, last-walk return, `dupes_total` accumulation, `stable` flag after three walks, and `RECON_SCAN_RACE` emission are untested.
- No test for a same-count swap (a list change that preserves totals); GV-2 is not exercised.
- No test for the interaction of `dupes_total` across walks (e.g. first walk duplicate, second walk clean).
- No test for the marker being emitted when `walks > 1` but `dupes == 0`.
- `AL7f` passes vacuously in the stub; its guard value is only meaningful together with `AL7d`.
- Smallest seam to close the collector gap: a test-only list provider (test arrays plus a flag) read by `Grind_ReconCollectBrokerTickets`, allowing a test to mutate the list between index accesses.

<!-- finish_reason=stop -->
