## Internal Reasoning

We need answer as adversarial quant phase1, required format. Need inspect threats. Need write zero implementation code. Need be rigorous. Need no actual code. Need infer from given context. Need provide verdicts, load-bearing claims, minimal repro, severity, final override.

Need address T-1 primary false positives transient. Need propose debounce/gating rule that fires C1 only persistent orphan and never mid-CloseBy exit. We need prove any sequence defeats gating. Need consider partial fills, requotes, exit-retry/re-place. Need decide exploit found? Need craft robust gating.

Context: Existing AuditExitLimits every tick, layer arrays, exit_live per layer. BCC per side after reconstruction and per-tick. C1 enumerates broker exit orders 9x3/9x4 and asks live position justifies. Async CloseBy: when exit fills, exit-hedge position QUEUED for CloseBy netting and layer removed on SAME tick, CloseBy processed on LATER tick. So for window >=1 tick, hedge/exit legitimately exists with counterparty mid-net. Need gating: fires only persistent same unmatched exit >=2 consecutive audits and not present in either CloseBy queue. But "same unmatched exit across >=2 consecutive audits" could still transient if CloseBy processing delayed >? Need examine. CloseBy processed later tick, likely one tick. But failures can delay? Need think.

T-1: We need attack gating. Need identify if proposed "not present in either CloseBy queue" is sufficient? The exit order? Let's understand lifecycle. "when an exit fills, the exit-hedge position is QUEUED for CloseBy netting (V2_QueueCloseBy) and the layer removed on the SAME tick, but the CloseBy is PROCESSED on a LATER tick (V2_ProcessCloseByQueue in OnTick). So for a window of >=1 tick, a hedge/exit legitimately exists with its counterparty mid-net." C1 scans exit orders (magic 9x3/9x4) from OrdersTotal. If an exit fills, the order is no longer resting in OrdersTotal? Actually filled order disappears from open orders, but position exists. "exit-hedge position" maybe counterparty position created by exit order? Need parse: "when an exit fills, the exit-hedge position is QUEUED for CloseBy netting". There might be an exit order that fills, creating a hedge position of opposite direction; layer removed. That filled exit order is no longer in OrdersTotal. The C1 scan is for resting exit orders, not positions? In C1: "for every managed exit order (magic 9x3/9x4) from OrdersTotal, is there a live position that justifies it under SRE-equivalent eligibility" If filled exit order is gone, not scanned. The window's "hedge/exit legitimately exists with its counterparty mid-net" maybe an exit order remains? Let's parse more carefully.

Market making: Long side has entry buy orders (9x1) and exit sell orders (9x3) resting. When buy entry fills, position opens; exit sell order is placed to close it. When sell exit fills, it closes buy position? Wait if both entry and exit are orders, "exit-hedge position" maybe because an exit order on a long position is a sell order; when it fills, it closes the long position outright, not creates hedge. But in a market-making grid, perhaps they use a "hedge" model: MM_LONG side places buy entries (9x1) and sell exits (9x3). If a sell exit fills, it may close the buy position, but if it fills without a corresponding buy? Hmm.

Let's infer from G2: "Normal layer removal always cancels the exit (Long_RemoveLayerAt -> V2_CancelExitOrder). Orphans arise from (a) the async CloseBy window and (b) external/manual closes the EA never observes." "async CloseBy window: when an exit fills, the exit-hedge position is QUEUED for CloseBy netting (V2_QueueCloseBy) and the layer removed on the SAME tick, but the CloseBy is PROCESSED on a LATER tick" This sounds the exit order maybe is a "hedge" order in opposite direction, not an order closing existing position. Actually "exit-hedge position" queued for CloseBy netting. In MT5, CloseBy is a deal that closes two opposite positions. If the exit is a resting sell order, when it fills, it opens a sell position (hedge) in addition to the existing buy position. Then CloseBy closes both. That makes sense for a market maker: they have entry buy position, and exit sell order is a "hedge" to close? It may be implemented as separate position.

So Orphan exit: a resting exit-hedge order (magic 9x3/9x4) whose position was gone. That is, an exit sell order is resting, but there is no corresponding buy position to justify it. C1 enumerates broker exit orders; if no live position justifies, orphan. In async CloseBy window: an exit sell order has filled -> created a sell position; the buy position remains until CloseBy later. C1's scan of OrdersTotal doesn't see the filled exit order. So why would C1 flag? Maybe there is still another exit order? Let's re-read directive: "when an exit fills, the exit-hedge position is QUEUED for CloseBy netting ... layer removed on the SAME tick ... a naive C1 exit-first scan will call this an ORPHAN and alert-storm on every single normal harvest." It says the hedge/exit legitimately exists with its counterparty mid-net. If C1 scans "resting exit orders" maybe an exit order remains (a limit exit order at price level) even after one fill? It might have partial fill leftover? Or if the exit is market order, no. But directive explicitly says "exit-first scan" will call this orphan, so likely C1 sees an exit order from OrdersTotal that is the "exit-hedge position"? Wait, "exit-hedge position" not order. But T-1 says "C1 ONLY on a PERSISTENT orphan (e.g. same unmatched exit across >=2 consecutive audits AND not present in either CloseBy queue) and NEVER on a mid-CloseBy exit." If C1 is order-based, "not present in CloseBy queue" makes sense if the exit order itself is tracked in queue? Hmm.

Need not fully resolve; need attack with concrete sequences.

Need answer with verdicts. We should be critical. Need find flaws.

Let's enumerate each T.

T-1: Need prove debounce/gating rule. Potential exploit: An orphan can be "not present in either CloseBy queue" for first two audits if CloseBy queue processing is delayed by an exception/requote? But if CloseBy is processed next tick, one audit maybe? ">=2 consecutive audits" might catch transient if CloseBy processing delayed by >2 ticks due to market closed, trade context busy, or terminal disconnect. The directive asks "Exhibit any fill/crash/tick sequence that defeats the gating (a real orphan suppressed, or a transient flagged)." Need find.

The gating rule has two conditions: same unmatched exit across >=2 consecutive audits AND not present in either CloseBy queue. If CloseBy queue is persisted? Need inspect? Not given. Need make assumptions.

Potential defect: "same unmatched exit" identity after AuditExitLimits "clears stale exit tickets, re-places missing exits." If a legitimate exit is missing and re-placed, ticket changes; the "same unmatched exit" cannot be tracked by ticket; need tracking by layer/price/direction? If re-place changes ticket, consecutive audits might see different unmatched exit, never reach threshold? Actually if the orphan remains, it has same ticket? Orphan left by manual close: exit order resting, same ticket. If re-place path? Hmm.

Potential defect: gating on "not present in either CloseBy queue" can suppress a real orphan if an orphan order is accidentally enqueued in CloseBy queue but never processed. But is that possible? Need mechanism. Queue likely keyed by position? If manual close closes the position, could a stale exit order be enqueued? The CloseBy queue is for filled exit-hedge positions. An orphan exit order (resting) wouldn't be in queue because queue contains positions to net, not orders. Unless C1 somehow checks exit orders against queue. Need avoid hand-wave.

Potential defect: ">=2 consecutive audits" vs "persistent" in a crash sequence: audit ticks are per tick. If a transient inconsistency lasts one tick, no alert. If it lasts two ticks, alert. Is the async CloseBy window at least 1 tick, maybe exactly 1 tick; with >=2, safe. But if a crash/reattach occurs during the CloseBy window, the queue may be lost? Actually EA restart loses queued CloseBy? If V2_QueueCloseBy state is in memory only, then after restart the exit-hedge position is no longer in queue but still pending CloseBy; C1 after OnInit may see the filled exit? Again order gone. Hmm.

Need frame as "we are attacking the proposal; can we find a sequence defeating gating?" Let's think of exact data model.

Let's build a plausible model:
- Grid layers g_*_layers[] have fields: position_ticket, exit_ticket, etc.
- When price crosses exit level, the EA sends an exit order. If exit order fills, it creates an opposite position (hedge). The EA queues that hedge position ticket in V2_QueueCloseBy and removes the layer. On a later tick, V2_ProcessCloseByQueue sends CloseBy to net against the original entry position.
- During the window, there are two positions: original entry and hedge. Open orders: possibly none from that layer.
- C1 is "for every managed exit order (magic 9x3/9x4) from OrdersTotal, is there a live position that justifies it?" This would see the exit order only if it is still open. If the exit order filled, it's closed; no C1 hit. So how does C1 call this orphan? Maybe the "exit" in C1 refers to "exit-hedge position" (a position), and OrdersTotal? In MT5, OrdersTotal returns orders, not positions. But maybe "order" includes positions? No, MT5 has PositionsTotal. The context says "broker exit orders (9x3/9x4)" and "OrdersTotal" explicitly. So C1 is orders, not positions. So why T-1? Perhaps when an exit order is a limit order, it can be partially filled: the order remains with remaining volume while a partial hedge position is created and queued. C1 sees the partially-filled exit order in OrdersTotal and no longer sees a live position justifying it? Wait if original position still exists, then C1 sees a live position? Let's model: A long entry position of 0.5 lots; a resting exit sell order for 0.5 lots. When price hits, the exit order may fill partially (0.2 lots) leaving a 0.3 lot sell order. The original 0.5 buy position remains. The partially-filled 0.3 sell order is justified by the original buy position? Enter price + exit pips? The remaining sell order's price is still around original entry? If the original position's entry price is at lower grid level, the remaining exit sell order at higher price. SRE-equivalent eligibility checks "price ~= entry +/- exit_pips within tolerance." The remaining exit order's price is much higher than the original position's entry, but that's expected for a take-profit exit. Wait "price ~= entry +/- exit_pips within tolerance" seems weird: an exit order's price should be entry +/- exit_pips, so yes, it is at a distance from entry. If the original buy entry price is e.g. 1.1000 and exit sell limit is 1.1050, C1 sees exit order at 1.1050 and live buy position at 1.1000; price difference = exit_pips, within tolerance. Good. If partial fill and queue, the remaining exit order still has the original position so justified. If the partial fill caused layer removal? In T-1, "layer removed on the SAME tick" maybe after an exit order fully fills, not partial.

Wait maybe "exit fills" is the exit order in the opposite direction of position, and after it fills, the layer is removed. Since the exit order is filled, it is no longer in OrdersTotal. Then C1 cannot see it. Unless C1 also scans exit-hedge positions? But directive says "OrdersTotal". Contradiction. Perhaps "OrdersTotal" includes history? No, C1 says "for every managed exit order ... from OrdersTotal" and "broker exit orders." T-1 says "naive C1 exit-first scan will call this an ORPHAN" but if order filled, no. Could be a "resting exit-hedge order" means an exit order that remains after the position was closed, which is the orphan. In the async CloseBy window, perhaps the exit order has filled and has been removed from OrdersTotal, but C1 may consider the hedge position as an "exit" and scan positions? Hmm.

Let's not obsess; we can design gating robust to any order/position ambiguity.

Need address T-3: exit-first scan sufficiency. Need confirm broker-first, not layer-driven. Then attack eligibility false negatives. Need characterize false-negative surface.

Eligibility: same symbol/direction/volume; price ~= entry +/- exit_pips within tolerance, carry-drift tolerant. A real orphan can masquerade as justified by unrelated live position whose entry +/- exit_pips happens to land within tolerance of orphan's price. Need concrete mechanism. Suppose two long layers at adjacent grid levels. Layer A's position is closed manually, but its exit sell order remains at price P_A (entry_A + exit_pips). Layer B has a live buy position at entry_B that is lower by grid spacing. If P_A is within tolerance of entry_B + exit_pips? Actually for an exit order to be justified by position B, need P_A ≈ entry_B + exit_pips within tolerance. If grid spacing is small, maybe. But if exit_pips is e.g. grid step? Need know. The SRE eligibility likely checks exit order's price equals position's entry + exit_pips, not just any. The orphan's price is tied to its own layer's entry. If another live position has entry close enough, could masquerade. If exit_pips is much larger than tolerance, need another position whose entry is within tolerance of original entry. Could happen at overlapping grid levels? If grid levels don't overlap, no. But carry-drift: exit price may drift from entry due to rollover; tolerance "carry-drift tolerant" could be wide (e.g., a few pips daily). The orphan's price is fixed at placement; over time, carry-drift can move the justified exit price for a live position away. If tolerance is widened to admit carry-shifted exits, then the orphan's price might be within tolerance of a neighboring position's carry-shifted exit. Need quantify.

Also "volume": orphan order volume might be 0.5; unrelated position volume 0.5. Direction: exit order direction must be opposite to position direction (sell exit for long position). If orphan is a sell exit, any live long position with matching symbol and volume and entry such that entry + exit_pips ≈ orphan price justifies. In a grid, there can be multiple live long positions at different entries. If one entry is near orphan's original entry, yes. Need characterize false-negative surface: if manual close removed layer A but leaves exit order; layer B remains with an entry price within tolerance of A's entry. When does that happen? If grid has overlapping/repeated entries due to re-grid, or if price has traveled and new entries added at levels close to old. Need suggest tightening? But if we tighten too much, carry-drift false positives. Need maybe eligibility should use layer identity / ticket, not just price-volume. But if layer is gone, no identity. Could require unique position ticket? The orphan's exit order may be linked to the layer's position ticket? MT5 order has comment/magic and maybe position id? If the exit order was placed with a comment containing the position ticket? In many EAs, exit orders are tied to position ticket via comment or magic offset. If so, C1 can match on position identifier not just price. Need check "magic 9x3/9x4" suggests magic distinguishes side/order type, not position ticket. Maybe comment includes. Need mention.

Need T-2: BCC vs SRE view drift. Need prove call site after reconstruction or no-op on halted side. Need identify source? We don't have source, but we can state load-bearing claims about names. Need "stated so Claude can check it in source". We need give file/function/invariant. We can name functions from prompt: OnInit, V2_SRE_AssignRecurse, Long_/Short_AuditExitLimits, V2_QueueCloseBy, V2_ProcessCloseByQueue. Need not know files. Need provide checks: BCC_OnInit must be invoked after V2_SRE_RebuildLayers and only if side not halted; else no-op. Need mention if BCC inside AuditExitLimits which runs after reconstruction? Hmm.

Need T-4: short. Need confirm added OrdersTotal scan not materially consume API budget. Since Long_/Short_AuditExitLimits already run every tick and walk layers; they "clears stale exit tickets, re-places missing exits" likely use OrdersTotal/OrderSelect? C1's added OrdersTotal scan is O(#orders) per side. API calls: MT5 OrdersTotal is a terminal-side function? In MQL5, OrdersTotal returns number of orders in the order pool, no remote API cost; OrderGetTicket/OrderSelect maybe local. "daily API budget" likely broker API? Maybe VPS with MT5 terminal, no API cost. But if via MT4? Need short. To be safe, state C1 can run every N ticks or on state-change because orphans persistent; but given requirement "per-tick audit cadence", no material budget.

Need T-5: Upstream exit-lifecycle audit. Need classify each path:
- async CloseBy window: (a) crash between QueueCloseBy and ProcessCloseByQueue strands the exit? Need determine. If queue is in-memory, after crash, the exit-hedge position exists but no layer references it and the queue is lost. On restart, C1 will detect? If the exit order is filled, C1 scans OrdersTotal, not positions, so maybe not detect orphan exit order. But the audit of positions may see naked hedge position? Need careful. The "stranded exit" might be a position not an order. The Aug-14 orphan was "resting exit-hedge order (magic 9x3/9x4)" whose position was gone. In crash between Queue and Process, the exit order is gone (filled), but the hedge position is stranded. Is that an "orphan exit" under C1? It is a position, not order. BCC C1 as described only orders, so it might miss. But T-5 asks "does a crash between V2_QueueCloseBy and V2_ProcessCloseByQueue strand the exit?" If by "exit" they mean exit-hedge position, C1 won't see it because no resting exit order. But perhaps C1 also enumerates positions? Yet given "OrdersTotal" no. Maybe "exit order" remained because CloseBy not processed? Let's parse T-1: "when an exit fills, the exit-hedge position is QUEUED for CloseBy netting ... the CloseBy is PROCESSED on a LATER tick ... for a window of >=1 tick, a hedge/exit legitimately exists with its counterparty mid-net." A filled exit order creates a hedge position. The phrase "hedge/exit legitimately exists" means a position. C1's "broker exit orders" could be "positions" colloquially? But they explicitly "from OrdersTotal" not PositionsTotal. Hmm.

Maybe "exit order" in their system is a "pending order" used as hedge. In MT, "orders" include pending orders and positions? No, in MQL5, OrdersTotal includes pending orders and market orders? Wait MT5: "OrdersTotal" returns number of orders in the current trading account, includes pending orders and positions? Actually MQL5: Orders are "trading operations" with tickets; "Deals" and "Positions" separate. Order can be a market/pending order; a filled order disappears. So no.

Need answer in a way that acknowledges ambiguity and recommends C1 include broker positions? But user said "broker exit orders (9x3/9x4) from OrdersTotal" and "exit-first scan". Need not re-litigate.

Need maybe propose gating: C1 should maintain a "suspect set" keyed by order ticket (or exit position ticket) and alarm only after K consecutive audits with same unmatched exit AND no CloseBy queue entry. But T-1 asks "prove a debounce/gating rule that fires C1 ONLY on a PERSISTENT orphan ... and NEVER on a mid-CloseBy exit." We can prove by invariant: any mid-CloseBy exit is either (a) a filled order no longer in OrdersTotal -> invisible to C1, so no flag; or (b) a remaining unfilled exit order whose layer is still present (if partial fill) -> C1 sees a live position justifies it (the original position remains until CloseBy), so no flag. Wait if layer removed on same tick, but original position remains until CloseBy. If the remaining exit order still exists after partial fill, the original position still exists -> justified. So no flag. Thus no debounce needed? But directive says "naive C1 will call this an ORPHAN" maybe because the layer is removed, C1's per-layer check no longer sees a live position? But C1 is broker order vs broker positions, not g_layers. If original position exists until CloseBy, C1 sees it. So why orphan? Maybe because eligibility "price ~= entry +/- exit_pips" but the original position entry and exit order price? If exit order has been filled partially, the remaining exit order's price was set when placed; original position still matches. So no. Unless there are multiple positions and the match selected is wrong? Hmm.

Let's take directive at face value: The naive scan flags because the layer is removed. But if scan is truly broker-first, it shouldn't care about layers. Maybe the naive C1 uses g_layers to determine "live position" rather than broker positions? But C1 says from OrdersTotal and "live position that justifies it" likely broker position. Let's see: "C1 ORPHAN EXIT (the new exit-first scan): for every managed exit order (magic 9x3/9x4) from OrdersTotal, is there a live position that justifies it under SRE-equivalent eligibility (same symbol/direction/volume; price ~= entry +/- exit_pips within tolerance, carry-drift tolerant)? No justifying position -> ORPHAN." So it checks broker positions, not layers. In CloseBy window, original position remains until CloseBy processed, so C1 sees it. Unless the original position was already closed by the exit fill? But then exit order is filled, no order to scan. So T-1's premise seems inconsistent. Need not call out? We can say "Under the stated broker-first definition, the mid-CloseBy window is already invisible to C1 (filled exit is not in OrdersTotal; original position remains until ProcessCloseByQueue), so no debounce is needed for that specific window. The actual transient risk comes from partial fills and re-place path." That might be a valid adversarial observation. Need then attack proposed gating with a sequence.

But the directive explicitly says "Directive: prove a debounce/gating rule ... NEVER on a mid-CloseBy exit." We can comply by designing rule: require unmatched exit to satisfy (1) same ticket across >=2 consecutive audits; (2) no CloseBy queue entry with position ticket == the original position for that exit? Hmm.

Need maybe "CloseBy queue" contains the hedge position ticket, not the exit order. A C1 orphan exit order cannot be in CloseBy queue because order and position tickets differ. So "not present in either CloseBy queue" is unverifiable unless exit order's position ticket is stored. Need flag that.

Let's think of T-1 exploit sequences. Need find a real sequence where proposed gating suppresses a real orphan or flags transient. Since we don't know exact code, we need construct plausible from given functions.

Debounce: "same unmatched exit across >=2 consecutive audits AND not present in either CloseBy queue." Suppose an orphan exists and is unmatched for one audit, then AuditExitLimits's "clears stale exit tickets, re-places missing exits" cancels and re-places the orphan as a new exit order? Wait AuditExitLimits works layer-first: if an exit is missing for a layer, re-place. It won't cancel a layer-less exit. But maybe if an orphan exit is unmatched, C1 only alerts, doesn't cancel. The orphan order ticket remains same. So after 2 audits, alert.

Can a real orphan be suppressed because C1's "same unmatched exit across >=2 consecutive audits" resets due to a single audit not running? E.g., "2 consecutive audits" in a crash/reattach: after OnInit, the first audit occurs, then a tick causes re-init? Or a transient API error makes OrdersTotal return -1, skipping audit; count resets. Need concrete sequence: On an EA restart, OnInit runs reconstruction and C1 sees the orphan (first count). But before next per-tick audit, a "market closed" or "trade context busy" causes OnTick to return early before AuditExitLimits, so no audit for many ticks. Then when trade resumes, the same orphan is seen again but not "consecutive" (because no audit in between). This suppresses real orphan indefinitely during choppy connectivity. Is that "defeats gating"? Yes, if consecutive audits means adjacent ticks. A real orphan suppressed. Need maybe "at least 2 observations within N audits" rather than consecutive. But user's proposal says "same unmatched exit across >=2 consecutive audits." We can exploit.

Another: If an orphan exit is partially filled? "same unmatched exit" order ticket remains but volume decreases. C1 might compare volume: "same unmatched exit" by ticket same, so still recognized. But if partial fill changes ticket? No, same ticket.

Another: Re-place path: AuditExitLimits re-places missing exits. If an orphan's corresponding layer is gone, no re-place. But if C1 sees an unmatched exit and alerts, no remediation. Not relevant.

Transient flagged despite gating: Suppose an exit order is unmatched for 2 consecutive audits because in the async CloseBy window a crash/restart occurs between QueueCloseBy and ProcessCloseByQueue, and on restart the queue is in-memory lost. The exit order? Let's see: The exit order filled before queue, so no longer in OrdersTotal. C1 wouldn't see it. But if C1 also scans positions, maybe the hedge position is unmatched and would be flagged as orphan after 2 audits, even though it's a legitimate stranded hedge from a crash. Is that a real orphan or transient? The directive says "never on a mid-CloseBy exit." A crash during the window makes it not transient; it is a persistent stranded hedge. C1 should detect it? But C1 is for orphan exits, not hedge positions. If hedge position is stranded, maybe not C1's scope.

What about a transient from an exit order's cancellation/replacement during audit? Suppose layer A has a live position and an exit order. AuditExitLimits decides the exit order's ticket is stale? It may cancel the old exit and place a new one as part of rebalancing. If the cancel occurs before the new order is placed (or OrderSend fails transiently), C1 sees no live exit order? Actually C1 scans broker exit orders; if no exit order, no orphan. If there is an old exit order that is no longer in g_layers (stale ticket) and a new position (maybe due to re-grid) causes mismatch, could be flagged for 2 audits until new order placed. Need concrete.

"partial fills, requotes, and the exit-retry / re-place path as additional transient sources." Let's construct:
- Exit order E at price P exits position P1. At tick t, E is partially filled, leaving residual E_res. The layer's exit_live is still E_res? Maybe the layer removed because the original position was closed? No, if E is a sell exit that closes a buy position, a partial sell fill closes part of buy position; residual buy position remains. The layer remains with reduced volume. E_res's volume may not match the position volume exactly due to partial fills? C1 requires same volume. If position volume is 0.5, E was 0.5; partial fill 0.2, residual E 0.3, position now 0.3. Match. Fine.
- Requote: An exit market order is re-quoted, the order may be re-submitted with different ticket/price. During the gap, no justifying position? If the position still exists, the new exit order should be justified. If no exit order, no C1.
- Exit-retry/re-place: If the EA cancels the wrong exit order (stale ticket) and does not place a new one before next tick, no orphan because no exit order. If it places a new exit order for a layer, but the position was already closed by an external/manual close in the same tick, then the new exit order is an orphan. C1 would flag after 2 audits. That's correct. But if the position is closed by a pending CloseBy? Hmm.

Need perhaps answer T-1 with "no exploit if gating uses K observations within sliding window" or "exploit found: consecutive audits can be starved by connectivity gaps." Need verdict: likely EXPLOIT-FOUND? Need be careful not over-flag. The directive says unsupported flags discarded. We need provide concrete mechanism. Let's choose a solid mechanism.

Let's define audit tick: OnTick runs, then Long_/Short_AuditExitLimits. "Consecutive audits" could mean consecutive invocations of OnTick. If a transient network issue prevents OrderSelect from returning (returns false), the audit may skip C1. A real orphan would not accumulate two consecutive detections. Is that plausible? In MQL5, OrderSelect is local and won't fail due to network; but if trade context busy? No API call. But if OnTick not called during market closed, that's not a crash. The orphan is persistent; once market reopens, first tick after gap sees it. But if C1 uses "consecutive audits" and there are no audits during gap, then when market reopens, it sees it once; subsequent tick sees twice -> alert after 2 consecutive post-gap ticks. So not suppressed. To suppress, need the orphan to be not seen on alternate ticks, e.g., an intermittent API error every other tick? OrdersTotal returns valid each tick unless terminal connection lost. If connection lost, OnTick not called. So consecutive audit condition is okay.

Need better exploit: If audit cadence is every tick, but "same unmatched exit" and "not present in either CloseBy queue" checks by ticket. If an orphan order is "not present in either CloseBy queue" is always true. Fine.

What if the EA's "CloseBy queue" stores orders, and an orphan order appears in it? Need mechanism.

Maybe the true flaw is C1 as described checks "same unmatched exit across >=2 consecutive audits" — but an orphan can be removed by an external actor (manual close) after first audit and replaced by a new orphan? Not relevant.

Maybe false-positive: partial fill of an exit order from a normal harvest creates a situation where the original exit order remains, but the position that justified it is partially closed and its ticket changes? In MT5, partial closing a position with a market/limit order may reduce volume, ticket same. If "position ticket" changes due to netting? In FIFO accounts, partial close may split position? MT5: a position can have multiple deals; ticket remains. If using hedging, partial close reduces volume. So match.

Maybe "same unmatched exit across >=2 consecutive audits" can flag a transient because the CloseBy window can last 2+ ticks if V2_ProcessCloseByQueue is executed after the audit rather than before, and if the exit order remains? Let's model with pending order still open:
- At tick t, exit order fills fully. No longer in OrdersTotal. No C1 flag. If C1's "exit" is the hedge position, then after t, the hedge position appears. C1 scans positions? It would see a position not justified? But the original position remains, so justified. At t+1, CloseBy processed and both gone. No flag. So safe.
- If V2_ProcessCloseByQueue fails due to requote for a few ticks, the hedge position remains. If C1 scans positions, it would see the hedge position justified by the original position, so no flag. Good.

Could an exit order be placed before the entry position exists? Example normal harvest: Entry order is pending/buy limit. The EA may place the exit order at the same time? If the entry order fills, position exists. If before fill, no position. C1 sees exit order with no live position -> after 2 audits flags, but the entry order may fill later -> transient. Is this in design? If grid places entry order and exit order simultaneously? The original incident: Aug-14 orphan exit whose position was gone. Normal operation: an exit order may be placed as a hedge before the entry position? In many grid EAs, they place both entry and exit pending orders. If entry hasn't filled, exit pending order can rest without a position. C1 would flag an orphan, but it's actually a paired take-profit order waiting for the entry to fill. This is a likely flaw! Need see if "live position that justifies it" includes an entry order? The prompt says "live position", not pending entry. If the market-making grid has resting entry orders (9x1/9x2) and exit orders (9x3/9x4), a normal "pre-positioned" exit order may be placed before the entry order fills to ensure exit is ready. Then C1 would see an exit order and no live position, falsely flagging. But is that in design? The C3 check "DUPLICATE PENDING: more resting entry orders than grid state expects" suggests entry orders are resting. "normal layer removal always cancels the exit" but "layers" may include entry orders? The SRE requires every position paired to an eligible exit; if no position, an exit order isn't in SRE? Hmm.

Let's examine G2: "Orphan creation is UPSTREAM... Normal layer removal always cancels the exit (Long_RemoveLayerAt -> V2_CancelExitOrder). Orphans arise from (a) the async CloseBy window and (b) external/manual closes the EA never observes." If a layer consists of a pending entry order and a paired exit order, then before entry fills, the exit order exists without a position. That's normal "pre-placed exit" not considered orphan. But C1 says "is there a live position that justifies it" would flag. Unless the SRE-equivalent eligibility also accepts a pending entry order as justification. The prompt says "live position", not pending order. Could be a real issue. But maybe the EA only places exit after entry fill. Need not assume. We can state as load-bearing claim: the only cases where an exit order may lawfully rest without a live position are (i) the pre-fill window of a paired entry order and (ii) the mid-CloseBy window; if the design places exits only post-fill, then not. Need ask Claude to verify.

The user's directive specifically: "Also consider: partial fills, requotes, and the exit-retry / re-place path (AuditExitLimits re-places a missing exit) as additional transient sources." We should address those.

Need perhaps propose a robust gating rule:
- Do not alarm on first detection. Keep per-order suspect counter keyed by order ticket + price + volume + side.
- Increment only when order has been scanned as unmatched in current audit AND order is not present in either CloseBy queue AND no pending entry order (same magic 9x1/9x2) on same symbol/direction with volume >= exit volume and entry price in a valid grid relation.
- Decrement/reset on any tick where the order is justifiable OR where the order ticket disappears (if it disappears and no replacement, no alert? Or reset? Need persistent orphan maybe if ticket disappears due to external close? If orphan order is manually closed, no issue).
- Alarm at threshold K; require K observations in a sliding window of M audits to avoid starvation.
- To avoid transient from re-place, key the suspect by layer identifier if available, or by (magic, symbol, price, volume, direction) rather than ticket, because a replaced exit has a new ticket but is the same logical exit. If an orphan's ticket changes due to someone re-placing? Orphans don't get re-placed by EA. But partial fills might change volume.
- For mid-CloseBy, suppression via queue membership.

But the directive asks "prove a debounce/gating rule that ... NEVER on a mid-CloseBy exit. Exhibit any sequence that defeats the gating." We can prove a rule with queue membership and threshold.

Need maybe show a sequence that defeats naive "same unmatched exit across >=2 consecutive audits AND not in CloseBy queue": a real orphan whose ticket is in the CloseBy queue due to a prior bug? Let's attempt.

CloseBy queue likely contains "exit-hedge position" tickets to be netted. An orphan exit order is not a position, so cannot be in queue. But if the orphan exit order was previously filled? Hmm.

Potential sequence: At time t, an exit order E fills, creating hedge position H and queueing H. The layer is removed. On the same tick, C1 scans OrdersTotal. E is gone. No flag. At t+1, ProcessCloseByQueue attempts CloseBy but fails because the original position was manually closed by the human between t and t+1. The queue still contains H. Now H has no counterparty. C1? If C1 is order-first, H isn't an order. If C1 also checks hedge positions, it might flag H. But the gating "not present in CloseBy queue" suppresses because H is in queue. The queue will retry every tick and fail forever -> a persistent orphan/hedge suppressed. This is a concrete sequence! It uses a manual close during the async CloseBy window, which is exactly one of the upstream orphan sources (T-5). This defeats the "not present in CloseBy queue" condition: the stranded hedge is in the queue but can never be netted because its counterparty is gone. C1 would suppress it forever. Does this count as "real orphan suppressed"? The orphan is a hedge position, not an exit order. But prompt says "exit-hedge position" and "mid-CloseBy exit". The Aug-14 orphan was a "resting exit-hedge order" whose position was gone. A hedge position left by manual close during CloseBy window is analogous. Great. Need include.

Let's map:
- Normal harvest: exit order E fills, creates hedge H, queue Q contains H, original position P remains.
- Human manually closes P before V2_ProcessCloseByQueue runs (or after? If before queue? The sequence: EA queues H at tick t; at t+1 human closes P externally; EA doesn't observe. At t+2 ProcessCloseByQueue tries to CloseBy H against P, fails "no counterparty" or closes only part? H remains. Q still contains H? If close fails, maybe EA leaves it in queue. C1's gating says "not present in either CloseBy queue" — H is in queue, so C1 doesn't flag. The stale H is persistent but suppressed. This is a real orphan (or naked hedge) invisible. BCC C1 as order-based won't see H, but if C1's "exit" includes hedge positions, yes.

Need phrase: "If C1 is genuinely order-only, the mid-CloseBy window is not a false-positive source (the filled exit order is not in OrdersTotal), so the queue-membership condition is unnecessary and dangerous: it suppresses the one case that matters. If C1 is position-inclusive, the same condition suppresses a stranded hedge. Either way, the gating rule fails." This is a strong T-1 finding.

Need also address ">=2 consecutive audits" with re-place path. We can maybe not need.

Need answer T-3. Need decide verdict. Likely EXPLOIT-FOUND due to false-negative eligibility. Need characterize. Need be concrete.

Let's formalize C1 eligibility:
For each open exit order O (symbol s, direction d, volume v, price p_o, magic m):
- Find any open position P with same symbol, opposite direction, volume equal? "same symbol/direction/volume" maybe "same symbol/direction" of position relative? Need state.
- Check |p_o - (P.entry ± exit_pips)| <= tol, where ± depends on side.
- If none, orphan.

Aug-14 orphan: layer gone, exit order resting; no position. Broker-first scan sees it. Good.

False-negative: unrelated live position "justifies" orphan. Need concrete minimal repro using grid geometry.

Let's define:
- exit_pips = D (distance from entry to exit).
- tolerance = T (including carry drift).
- Grid levels spaced G.

At any time, a valid exit for a long position with entry E is a sell order at price E + D. So C1 accepts O at price p_o if there exists a long position with entry E such that |p_o - (E + D)| <= T.

Suppose layer A's position is manually closed at price E_A. Its exit order O_A at p_A = E_A + D remains.
Suppose layer B has a live long position with entry E_B. If |E_B - E_A| <= T, then |p_A - (E_B + D)| <= T, so O_A is justified by P_B. Thus orphan missed.

When can |E_B - E_A| <= T in a grid with spacing G? If T < G, no. If T >= G, then neighboring grid levels can masquerade. Carry-drift tolerance T could be much larger than grid spacing? Need know. In FX grids, grid spacing often 10-30 pips, exit_pips maybe 10-30, tolerance maybe 5 pips plus carry drift (a few pips over days). If T < grid spacing, no. But grid can have multiple entries at same or near level due to re-grid/stacking after price retrace. Need characterize: In a grid, levels can repeat when price moves out and back; old positions at similar entries may remain. If grid is additive and not FIFO, an entry at 1.1000 can be followed by another entry at 1.1002 after a retrace, within tolerance. Then an orphan at 1.1050 (exit for 1.1000) is justified by P at 1.1002 (since 1.1050 ≈ 1.1002 + 0.0048). So false-negative plausible.

Another: "carry-drift tolerant" means the valid exit price for a position shifts over time due to swap/rollover. If the EA adjusts exit order price? Let's read: "carry-drift tolerant" in C1: price ~= entry +/- exit_pips within tolerance, carry-drift tolerant. This could mean the acceptance tolerance includes the accumulated carry, maybe as high as daily swap. Over a week, carry can be 10 pips. If grid spacing 10 pips, T >= G, so neighboring positions masquerade. Need quantify with "ADR-114" mentioned: "carry-drifted exits (ADR-114)". Need use it. We can state: If ADR-114's carry allowance is not bounded below grid spacing, false-negative is unavoidable. Need name source: ADR-114 defines carry-drift offset; check whether offset tolerance < minimum grid spacing. If not, fixable by requiring the position ticket encoded in exit order comment or by checking no other position with closer entry/volume and by rejecting ambiguous matches.

Need maybe propose fixable-within-design: C1 can store an "exit fingerprint" at placement time: (position ticket, entry price, volume, target exit price). When scanning, match exit orders to positions by exact ticket if comment/magic carries it; only fall back to price/volume if no ticket. If an orphan's ticket is stale (no position), no position has that ticket, so flagged. This is a fix, not code.

Need also attack sufficiency of "broker-first vs layer-driven": Confirm C1 must enumerate OrdersTotal directly. If implemented by iterating g_*_layers[] and looking for exit tickets, it will miss layer-less exit. Need load-bearing claim: "C1 must not reuse g_*_layers[] as the iteration source; its only safe source is OrdersTotal filtered by magic 9x3/9x4." In source, check V2_CollectManagedExitOrders or similar. Need mention.

Need T-2: Need prove BCC call site. We can say:
- Verdict: NO-EXPLOIT if BCC_OnInit is called after V2_SRE_RebuildLayers and V2_HaltAssessments; otherwise EXPLOIT. Need maybe "fixable-within-design". Need be decisive.
Need load-bearing claim: "BCC's OnInit call must be after SRE reconstruction commits to g_*_layers[]; on a halted side it must return without alerting. The invariant is: g_*_layers[] is immutable during BCC's first scan." Check source: V2_SRE_RebuildLayers returns side_state; BCC_Init is invoked in the success branch, not before.
Need also "BCC eligibility mirrors SRE Tier1/Tier2" — if C1 uses exactly same match predicate as V2_SRE_AssignRecurse, then book clean under BCC reconstructs clean. Need mention "reuse predicate function, don't reimplement."

Potential view drift: BCC runs after reconstruction; reconstruction is all-or-nothing? If reconstruction fails, side is halted and BCC no-op. Good.

Need T-4: Need short answer. Verdict: NO-EXPLOIT (or "confirmed"). We can state: C1's added scan is local OrdersTotal enumeration; AuditExitLimits already calls OrdersTotal/OrderSelect per tick, so no new broker API round-trips. If the "daily API budget" is the external REST/WebSocket to the broker, the EA already uses that only for orders; C1 adds none. Orphans persistent; if budget concern, run C1 every Nth tick or on 1-second timer; 12 uses/day at 1/2 sec? Hmm.
Need "minimum cadence": C1 can be run every 60 ticks/1 minute because orphan persists. But audit is per tick; no material.

Need T-5: Need for each path:
- async CloseBy window crash between Queue and Process: The exit order is filled and gone; the hedge position is stranded. Preventable in-EA? Maybe yes, by persisting CloseBy queue to file/global variables before QueueCloseBy and reconstructing after restart? But "prevent" maybe no, because crash is external. We can say "not preventable in-EA if queue is memory-only; detect-only-via-BCC only if BCC includes positions, not just OrdersTotal." Need maybe "inherently detect-only via expanded BCC."
- CloseBy failure/partial: Failed CloseBy retry is in-EA; should not remove queue entry on failure. If queue entry is removed on any CloseBy failure, then the hedge becomes layer-less and C1 must detect. If queue entry is retained, C1 gating must not suppress it forever (see T-1). Preventable in-EA by keeping the queue entry and alerting via existing escalation after N retries? But auto-remediation no.
- external/manual closes: EA cannot observe; inherently detect-only-via-BCC. Need C1 scan order vs position: manual close of a position leaves its exit order (if EA never observed), so C1 catches. If manual close also closes the exit order? Then no orphan. Need mention.
- "position closes WITHOUT layer's V2_CancelExitOrder running": Any direct close by broker (stop out? no stops; margin stop-out maybe) or manual. Margin call/stop-out: EA may observe via OnTradeTransaction? If not, detect-only. Need include stop-out as a path? The system has no stops, but broker stop-out can close. Need mention.
- "CloseBy failure/partial": If closeby fails due to requote at t+1 but succeeds at t+2, transient. If closeby partially nets (e.g., one of two legs), residual hedge remains. Is that preventable? EA can retry. Not auto-remediation.

Need final override: Are findings fatal to BCC premise? We need decide. Likely all fixable within design. Need mention T-1 finding fixable by replacing queue-membership suppression with queue-age plus counterparty existence check; T-3 fixable by ticket-bound matching; T-2 fixable with call-site guard; T-5 expands scope. But if BCC remains order-only, a stranded hedge from crash won't be detected, but the premise is "passive exit-first detector"; maybe invalid? Need final line.

Need maybe answer "OVERALL: no fatal-to-premise finding; all fixable within design" or "premise unsafe"? Need be adversarial. Let's evaluate.

BCC premise: passive exit-first detector on existing audit rail, detects/alert only. T-1 found that the queue-membership suppression can suppress a stranded hedge. But that's fixable within design. T-3 found false-negative via masquerade, fixable with ticket-bound matching. T-5 says some upstream paths are not preventable and require detection only; BCC can detect if C1 scans orders and positions. So premise is sound, but only if C1 is *both* order-first and position-aware, and eligibility is bound to layer/position tickets, and CloseBy suppression is not naive. Need final line: "No finding invalidates the BCC premise; all are fixable within the design, but T-1 and T-3 are fixable-within-design, not cosmetic."

Need be careful with "EXPLOIT-FOUND" verdicts. For T-1, if we find exploit, verdict "EXPLOIT-FOUND". For T-3, "EXPLOIT-FOUND". For T-2, maybe "NO-EXPLOIT" if we assert source invariant. For T-4, "NO-EXPLOIT". For T-5, "EXPLOIT-FOUND" or "DESIGN-UNSAFE"? Need define: T-5 asks whether each path preventable or detect-only. Maybe "EXPLOIT-FOUND" because crash between queue and process strands hedge and current C1 cannot see it. But T-5 is upstream audit, not BCC. We can say "EXPLOIT-FOUND (fixable-within-design)" because prevent half incomplete.

Need ensure "LOAD-BEARING CLAIM: stated so Claude can check in source -- name file/function/invariant". We don't have file names. Need give function names from prompt. Maybe:
- T-1: V2_QueueCloseBy / V2_ProcessCloseByQueue — check whether queue entries are removed on failed CloseBy and whether C1's gating suppresses queue-present exits indefinitely. Invariant: "an entry remains in Q until a successful CloseBy; a failed CloseBy does NOT remove it." If that invariant holds, T-1 exploit real. If false, maybe not? Need phrase as claim to check.
- T-3: V2_SRE_AssignRecurse eligibility predicate — check whether it is a pure function of symbol/direction/volume/price or also uses layer ticket. If pure price-volume, false-negative. Also check ADR-114 carry-drift tolerance vs grid spacing.
- T-2: OnInit call order in V2_SRE_RebuildLayers / BCC_OnInit.
- T-4: Long_/Short_AuditExitLimits already invokes OrdersTotal; no new API budget.
- T-5: V2_QueueCloseBy persistence; V2_ProcessCloseByQueue retry/failure path.

Need include "MINIMAL REPRO / MECHANISM" for each.

Let's craft T-1 in detail.

T-1 response:

VERDICT: EXPLOIT-FOUND (fixable-within-design).

Load-bearing claim:
- The gating rule "not present in either CloseBy queue" suppresses any stranded exit that is still referenced by V2_QueueCloseBy. Check V2_ProcessCloseByQueue: on a CloseBy failure (counterparty gone/requote), does it leave the queue entry in place? If yes, the suppression is permanent. If it removes the entry on failure, then the ">=2 consecutive" no longer protects the transient window and can false-positive on retry. Either branch is a defect:
  1. queue entry retained forever -> real orphan suppressed.
  2. queue entry removed on first failure -> persistent orphan may be detected after 2 audits but transient CloseBy failure may also produce 2 unmatched audits? Need concrete.

Need choose one branch. We can't know source. Need maybe present both as a "forking repro" depending on invariant. This is acceptable? User wants "independently verifiable", unsupported flags discarded. We can say "Check invariant X; under the stated design the exploit is..." But maybe need be decisive. Could state "T-1 is real because the gating rule suppresses a stranded hedge if the CloseBy queue is not drained." Let's formulate concise.

Sequence:
- t0: Harvest exit order E fills -> hedge H created; V2_QueueCloseBy(H); layer removed. P (original position) still open.
- t1: Human (or external EA? manual) closes P. EA's audit still sees H? (if C1 position-inclusive) or if order residual? Because P gone, H is unmatched. H is still in CloseBy queue. V2_ProcessCloseByQueue runs and fails (no P), but does not drop H from queue (assuming retry design).
- t2/t3: C1 sees H as exit-like but queue-membership test says "in CloseBy queue -> defer". Every tick. H never leaves queue if ProcessCloseByQueue keeps failing. Result: H is a persistent orphan/stranded hedge but BCC never alerts. This directly recreates "exit whose position was gone" (but as a hedge position).
Need mention if C1 is order-only, then H isn't scanned; the exploit is even more direct: C1 misses it entirely. This is a strong point.

Another transient false-positive sequence:
- t0: exit order E's position P is manually closed; but before EA's audit, AuditExitLimits sees the layer still has P? Hmm.

For "transient flagged", need maybe:
- Audit t0: E unmatched (because position P is in the middle of a broker-side position transfer/ticket change due to partial close). Audit t1: still unmatched. At t2, the position ticket updates and E becomes justified. Because threshold=2, BCC alerts on a transient. Is position ticket change plausible? In MT5, partial close does not change ticket; in position netting, maybe. Not safe.

Need maybe focus on real orphan suppressed because that's enough for EXPLOIT-FOUND. The directive says "exhibit any fill/crash/tick sequence that defeats the gating (a real orphan suppressed, or a transient flagged)." We'll exhibit real orphan suppressed.

Need mention mid-CloseBy normal: If original position P is still present, H is justified (opposite directions, volumes, price relation) so C1 shouldn't flag even without queue membership. The only reason to use queue-membership is if C1's matcher can't see P due to layer removal. But if matcher is broker-first, P is visible. So the queue test is at best redundant for the normal window and at worst harmful in the failed-CloseBy-with-manual-close case. Nice.

Need T-3 in detail.

VERDICT: EXPLOIT-FOUND (fixable-within-design) — if the eligibility predicate is price/volume-only and not ticket-bound. Need maybe "DESIGN-UNSAFE" if no ticket binding? Let's craft.

Load-bearing claim:
- C1's "same symbol/direction/volume; price ~= entry +/- exit_pips within tolerance" predicate is exactly the SRE's Tier1/Tier2 matching? Check V2_SRE_AssignRecurse. If that predicate is a function of broker-visible fields only, the false-negative surface is non-empty. Need know if threshold tolerance T >= minimum absolute difference between two live positions' entries that could both justify the same exit.
- ADR-114 carry-drift: if carry offset is added to tolerance, T grows with holding time. In a grid, entries are spaced by grid step G; if T >= G, an orphan from layer A is "justified" by the neighboring layer B.

Minimal repro:
- Side MM_LONG. Grid step G = 10 pips. exit_pips D = 10 pips. Carry-drift tolerance T = 12 pips (ADR-114 allows cumulative carry).
- Layer A: entry E_A = 1.1000, position manually closed, exit order O_A resting at 1.1010 (sell).
- Layer B: live long entry E_B = 1.1008 (a re-grid add). O_A's target is within 2 pips of E_B + D = 1.1018? Wait |1.1010 - 1.1018| = 8 pips <= 12. So O_A is accepted as P_B's exit. But O_A's volume must match P_B. If both 0.5 lots, yes. Or use E_B = 1.1002 so target = 1.1012, diff 2 pips. Need ensure E_B is a valid live entry. In a grid after a retrace, entries can be near.
- Result: BCC sees O_A as justified, does not report, but P_A is gone and O_A will never be justified by P_B when P_B closes (P_B has its own exit). At next harvest, O_A may remain and eventually cause HALT_21 on reattach? Actually BCC false-negative means Aug-14 orphan missed.

Need also mention "direction/volume" is not enough; two positions can share volume. Need use "not present in either layer's exit ticket" maybe.

Severity: fixable-within-design. Need say: make C1 eligibility require the exit order's comment/ticket to reference a live position ticket; if the broker does not preserve the bound, require uniqueness: reject any exit for which the match is ambiguous (more than one live position within tolerance) and treat ambiguous as orphan? Wait treating ambiguous as orphan could false-positive. Better: if no ticket, and ambiguous, alert "UNVERIFIABLE" rather than clean. But no auto-remediation; alert.

Need also "is the exit-first scan actually sufficient?" Need confirm "broker-first, not layer-driven." We can state: "The design is sufficient only if the implementation enumerates OrdersTotal and filters by magic 9x3/9x4; it must not use g_*_layers[] as the source. If it does use layers, it reproduces G4 and misses the exact orphan." This is obvious but required.

Need T-2.

VERDICT: NO-EXPLOIT (provided invariant holds) or "fixable-within-design". Need decide.

Load-bearing claim:
- BCC_OnInit must be called after V2_SRE_RebuildLayers completes and must early-return on halted side. The invariant to check in source: "BCC's first scan is not reachable from inside the SRE recursion or before the layer arrays are committed; any failure in reconstruction leaves side_halted true and BCC reads a frozen/empty layer state."

Minimal repro for if violated:
- If BCC is called before reconstruction commits, g_*_layers[] is half-populated: layer 1 has exit ticket set, layer 2 does not. C1 may see exits without positions and report phantom orphan. But given prompt says "Runs per side after reconstruction (OnInit, on a non-halted side)" and G3 says piggyback audit, no exploit if source obeys. Need maybe "No exploit; confirm in source."

Need also "BCC eligibility mirrors SRE" — Need state: "If C1's justification predicate is not literally the same function used by V2_SRE_AssignRecurse, a book that BCC calls clean can be HALT_21 on the next reattach. Check that C1 calls the same predicate; do not reimplement." This is a "confirm only" not exploit. We can include in T-2.

Need T-4.

VERDICT: NO-EXPLOIT. Load-bearing claim: Long_/Short_AuditExitLimits already enumerates OrdersTotal/OrderSelect per tick; C1's scan is a filter over the same already-loaded order pool. It adds no broker round-trip. Minimum safe cadence: once per minute (orphan is persistent by definition). If there is a per-tick cost, C1 can run every 60 ticks.

Need maybe "API budget" from prompt "daily API budget" — In MT5, OrdersTotal is terminal-local, not broker API? Actually MT5 API calls are local. But if using cTrader? The prompt says EA. We'll say no material.

Need T-5.

Need structure:
- For each path:
  1. Async CloseBy window:
     - Preventable? If queue is memory-only, no. If queue is persisted to EA global variables/file before ProcessCloseBy, maybe yes? But "prevent" means avoid orphan? The orphan is not caused by window itself if P remains. A crash between Queue and Process leaves H stranded. The EA can prevent by making QueueCloseBy journal durable (write to EA-side storage) and on startup re-enqueue any hedge position whose counterparty still exists. But "do not propose auto-remediation" — this is prevention, not remediation? It is in-EA lifecycle fix. Could propose. But if "PREVENT" half asks whether we can prevent orphans; we can say no for external/manual, yes for crash if queue journaled.
  2. CloseBy failure/partial:
     - If CloseBy fails due to requote, queue remains; prevent by retry. If partial fill, residual volumes remain; C1 must see position pair. Preventable in-EA by retrying netting until residual zero, but if counterparty gone, detect-only.
  3. External/manual closes:
     - EA cannot observe; inherently detect-only-via-BCC. Need ensure C1 enumerates orders, not layers.
  4. Margin stop-out / broker-forced closes:
     - Same as external; detect-only.
- Need mention "a crash between Queue and Process strands the exit" — If crash occurs, the exit order has already filled, so C1 order-only won't see it. Need expand BCC to detect "unmatched exit-side positions" as well as orders. This is important. The prompt says C1 order-only. We can say "Within T-5, this is a design gap: C1 as specified detects a resting orphan order, but not a stranded hedge position from a crash after exit fill. If the intent is to detect all orphan exits, C1 must also scan PositionsTotal for magic 9x3/9x4 and apply the same justification test. That is still passive and within design."

Need maybe "DESIGN-UNSAFE" if C1 doesn't include positions. Let's decide severity. The final override can say "No fatal-to-premise; but if C1 remains OrdersTotal-only, the Aug-14 class is only half-covered (resting orders, not stranded filled exits)." Is that fatal to premise? The premise is "passive exit-first detector on existing audit rail" — could be extended. Not fatal.

Need write final with required format. Need maybe include a "OVERRIDE CHECK" section and last line. Keep desired oververbosity 5, but this is complex, need thorough.

Need ensure no implementation code. We can mention function names but not code.

Let's draft.

Potential issue: "T-1: EXPLOIT-FOUND" with queue suppression. Need make sure not "over-flag" because maybe C1 only scans OrdersTotal, so a hedge position isn't scanned. But the exploit is about the proposed gating "not present in either CloseBy queue." If C1 is order-only, queue membership is meaningless because closed exit order can't be in queue. But we can phrase: "If C1 is order-only, then the T-1 premise about mid-CloseBy false positives is false; the gating condition is unnecessary. If C1 is position-inclusive (as T-5 makes necessary), the gating condition suppresses a stranded hedge. In either reading, the presented gating is either a no-op or harmful." That is rigorous.

Need maybe "same unmatched exit across >=2 consecutive audits" could also suppress a real orphan if the orphan gets "matched" by a position that is not the true counterparty due to T-3 false negative; after 1 audit, the orphan is "justified" and counter resets, so never reaches threshold. We can mention under T-3, not T-1.

Need maybe "transient flagged" from CloseBy failure:
- Suppose CloseBy fails at t+1 and t+2 due to requote; the exit-side hedge H is unmatched? Wait if P remains, H is justified, so no. If P is manually closed at t+0, H becomes unmatched and remains in queue; gating suppresses. Not flagged. So no.

Maybe a "transient flagged" sequence:
- exit order placed before entry order fills, as mentioned. Let's use that? Is that in design? Need maybe not if no proof. But could be from "partial fills, requotes, exit-retry". Need maybe propose a potential "deferred" not exploit.

Let's think deeper about T-1 with "naive C1 exit-first scan will call this an ORPHAN" if "exit-first scan" enumerates "broker exit orders" from OrdersTotal. Could a filled exit order remain in OrdersTotal as an "order" with status filled? In MT5, OrdersTotal returns active orders, not filled. But in MT4, OrdersTotal returns all orders including closed? Actually MT4 OrdersTotal returns number of market/pending orders? In MT4, orders include closed? Hmm. This is MT5 likely. Need not.

Maybe "async CloseBy window" in an MT4/MT5 hedge account: The EA may place an "exit" order that is a pending order *and* the "exit-hedge position" is a separate position. When the exit order fills, it becomes a position, not an order. If C1 scans OrdersTotal, no flag. So T-1's premise is suspicious. We can call this out: "The stated mid-CloseBy false positive cannot occur for an order-only C1; the filled exit is not in OrdersTotal. Therefore the proposed queue gating is solving a phantom and introduces a suppression hole." This is a good adversarial insight.

Need include "partial fills" transients:
- If C1 is order-only and a partial fill leaves a residual exit order, the original position remains (reduced) and justifies it. So no false positive. Unless the position was fully closed by the partial? If partial fill volume equals position volume? Then no residual. So safe.
- Requote: an exit order may be re-submitted after requote; during the gap, if the EA cancels old and places new, there may be a two-tick window with no exit order, not an unmatched exit. So no false positive.
- Exit-retry/re-place: If the EA cancels an exit and places a new one with different ticket, C1 could see the new exit. If the position exists, justified. If the position was closed, it's a real orphan. So no transient.

Thus T-1's real issue is queue suppression, not false positives.

Need maybe mention "A real orphan suppressed by 'not present in CloseBy queue' if a stale position/ticket is in queue forever." This is enough.

Need T-3 false-negative more detail.

Let's estimate carry-drift tolerance. ADR-114 "carry-drift tolerant" likely means if a position is held overnight, the exit price may be adjusted by carry accrual to avoid a false orphan. If the EA periodically moves exit orders? Actually "carry-drift" in exit order: after rollover, the position's entry price may change? In MT5, swap is added/deducted, but entry price stays. The exit order's price may be adjusted? Maybe the EA re-places exit at a drifted price. If C1 tolerance admits carry shift, then an orphan from a closed layer could be "justified" by a nearby live position whose entry is within tolerance of the orphan's original entry. Need state.

Need maybe "same symbol/direction/volume" — "direction" of an exit order is opposite the position. If all long positions have same direction, direction is not discriminating. Volume not discriminating.

Need maybe "price ~= entry +/- exit_pips" should be specific:
- For MM_LONG, position entry = long, exit order = sell at bid/ask? Price p = entry - exit_pips? Wait in FX, long position profit if price rises; exit is sell at higher price. So p = entry + exit_pips. For MM_SHORT, exit is buy at lower price p = entry - exit_pips. Need not specify.

Need maybe "unrelated live position whose entry +/- exit_pips happens to land within tolerance" — yes.

Need "Minimal repro" with numbers:
- exit_pips = 10 pips. tolerance = 5 pips plus carry 5 = 10 pips. Grid spacing = 10 pips. Orphan O at 1.1010 (from E_A=1.1000). Live P_B entry E_B=1.1005. P_B's valid exit would be 1.1015. O at 1.1010 is 5 pips from valid, within tolerance. O is accepted. This is very plausible. Need ensure not too hand-wave: grid entries can be at 1.1000 and 1.1005? If grid adds on adverse movement and re-entries, yes. But if grid levels are fixed, not. Need maybe define "when price retraces and re-enters, the add layer can be at a nearby price." Maybe okay.

Need also "Broker-first scan is necessary but not sufficient." Good.

Need T-2 "BCC eligibility mirrors SRE" — If C1 uses "SRE-equivalent eligibility" with tolerance, but SRE itself might use perfect assignment across all positions/exits. BCC checks each exit independently; SRE checks global assignment. An exit can be individually justified by *some* position but the global assignment may still fail if two exits need the same position (duplicate). C1 doesn't detect that. But C4 duplicate pending? No, duplicate pending is entries, not exits. Is this a T-3 false-negative? Suppose two orphan exits O1, O2 both individually justified by the same position P (because P's entry near both). C1 sees both justified, calls clean; SRE, requiring perfect assignment, has one position and two exits -> no perfect assignment -> HALT_21. That's a concrete false negative. Need add! This is excellent.

Sequence:
- P live at E=1.1000. O1 orphan at 1.1010, O2 orphan at 1.1008. Both within tolerance of P's exit. C1 individually matches each to P; no orphan. But SRE sees two exits competing for one position; no perfect assignment -> HALT_21. So BCC clean but reconstruct fails. This is a stronger T-3 exploit. Need include.

Need name "V2_SRE_AssignRecurse requires every managed exit consumed. If C1 uses a per-order existential match instead of a bijective assignment, it can call clean a book that SRE will halt." This is view drift between C1 and SRE, also relevant T-2. But T-3 says "can a real orphan masquerade ... false-negative" — yes, exactly. Need characterize false-negative surface as "any exit that shares a unique justifying position with another exit."

Need maybe "volume" can mitigate if P volume insufficient for two exits. But if P volume >= sum, then SRE could assign one exit and one? Wait SRE requires every managed exit consumed; a single position can be paired to multiple exit orders if total volume <= position volume? If exit orders are for reducing position, multiple exits can close same position. SRE might accept that if combined volume <= position volume. If two exits each 0.5 and P 1.0, perfect assignment exists. If P 0.5, no. Need use volumes to ensure no perfect assignment.

Need T-2 also: "C1 as a set of independent existential matches cannot prove a global perfect assignment; SRE view is global." This is a divergence even if eligibility predicate identical. Is this within T-2? Yes "BCC eligibility mirrors SRE so a book BCC calls clean will reconstruct clean" — false if per-exit existential vs global perfect assignment. Need flag under T-2 or T-3. The user assigned T-2 explicitly "Confirm BCC's eligibility mirrors the SRE's Tier1/Tier2 so a book BCC calls clean will also reconstruct clean (and vice versa) -- if they diverge, BCC gives false confidence exactly where it matters." This is a real flaw if C1 is just "does any position justify this exit" not "can every exit be assigned to a distinct position without conflict." Need include. This is important. Maybe T-2 verdict should be EXPLOIT-FOUND if no global assignment. Let's think.

T-2 asks "BCC vs SRE view drift" secondary. We can find exploit: C1 per-exit existential vs SRE global assignment. If two exits both matched to same position but volume mismatch, C1 clean, SRE HALT. Need minimal repro:
- Live long P volume 0.5 at 1.1000.
- Exit order O1 (orphan) sell 0.5 at 1.1010.
- Exit order O2 (orphan) sell 0.5 at 1.1008.
- Both orders individually match P by price/volume. SRE has one position 0.5 and two exits totaling 1.0 -> no perfect assignment. BCC C1 sees no orphan. Reconstruct HALT_21. This is a direct false-confidence. This is even better than T-3. Need perhaps put in T-2 as "view drift" and reference T-3. The final override says all fixable. Need be careful not to duplicate too much.

Need formulate T-2 verdict: EXPLOIT-FOUND. Load-bearing claim: C1 must not be a one-to-many existential check; it must consume exits in a bijective/volume-aware assignment exactly like V2_SRE_AssignRecurse. If it only asks "does a live position justify this exit?" it can call clean a book SRE will halt. Check source: C1's suggested test is "is there a live position that justifies it" — existential, not global. Good. Severity: fixable-within-design (change C1 to run the same assignment, or if assignment fails, treat as inconsistency and alert).

But wait BCC is supposed to be a lightweight detector on existing audit rail, not reconstruct SRE every tick? Running SRE every tick may be expensive. But BCC could use simpler global constraint. Need not propose implementation.

Need also T-2 "OnInit call after reconstruction" — if that invariant holds, no issue. But view drift is an issue. So T-2 verdict EXPLOIT-FOUND with two findings? Need keep required format with load-bearing claim/minimal repro/severity.

Need maybe T-3 "exit-first scan sufficient?" If C1 is changed to global assignment, false-negative from masquerade is handled. Still need ticket binding to avoid orphan masquerade.

Need T-5 maybe include "queue suppression" from T-1.

Need final OVERRIDE: "No finding invalidates BCC premise; all are fixable within design if C1 is made global-assignment, ticket-bound, queue-age-aware, and position-inclusive." Need mention "but if the implementation keeps C1 as an order-only existential price-match, the premise is unsafe (false confidence)." Last line.

Let's structure final:

Start with a short preamble maybe "No code written; findings below." Then sections.

Need maintain exact required output format for each T. Use headings.

Let's draft each section carefully.

### T-1

VERDICT: EXPLOIT-FOUND (fixable-within-design)

LOAD-BEARING CLAIM:
- The bad idea is the gating predicate "not present in either CloseBy queue." Check V2_QueueCloseBy / V2_ProcessCloseByQueue: an entry is removed only after a successful CloseBy. If a CloseBy fails because its counterparty is already gone, the queue entry remains. Then C1's queue-membership suppression is permanent suppression. Also check: if C1 is truly order-only (OrdersTotal), a filled exit is not in OrdersTotal, so the "mid-CloseBy" false positive cannot happen; the queue check is unnecessary but harmful.
- The ">=2 consecutive audits" piece can also be defeated by a stop/start or trade-context-busy gap? Maybe not include to avoid over-flag.

MINIMAL REPRO:
- t0: exit E fills -> hedge H opened; H is queued in V2_QueueCloseBy; layer removed. Original position P still exists.
- t1: human manually closes P; EA does not observe it.
- t2...tn: V2_ProcessCloseByQueue tries to CloseBy H, fails (no counterparty), leaves H in queue. C1 sees H as an exit-side item but "not present in either CloseBy queue" is false (H is in queue), so the debounce keeps suppressing. H remains forever; next reattach would HALT_21 / re-halt.
- If C1 is order-only, H isn't scanned at all; the "queue" suppression is inoperative, and the crash/manual-close stranded hedge is invisible. In either reading, the proposed gating does not deliver persistent detection.

Wait if C1 scans H as "exit-side item", is H an order or position? If C1 order-only, H is not scanned. Need phrase "if the intended C1 is later widened to positions (T-5)..." But the gating rule includes "not present in either CloseBy queue," so it assumes C1 can see queued items. If C1 order-only, queue membership test irrelevant. We'll present as "either C1 is order-only and the queue test is meaningless, or C1 includes hedge positions and the queue test suppresses the failed-CloseBy orphan."

Need maybe "normal mid-CloseBy exit" no false positive:
- If P still exists, C1 sees H justified by P; no alert. So no debounce needed at all. Actually if order-only, no H. So the directive's premise is questionable.

SEVERITY: fixable-within-design. Fix: replace queue-membership suppression with "age of queue entry" and "does the counterparty position still exist?" Only suppress during the first K ticks while the counterparty exists; if the counterparty is gone, the queue entry is itself the inconsistency. But no code.

Need maybe "exhibit transient flagged" not necessary due to real orphan suppressed.

### T-2

VERDICT: EXPLOIT-FOUND (fixable-within-design)

LOAD-BEARING CLAIM:
- C1's wording "is there a live position that justifies it" is an existential per-order test. V2_SRE_AssignRecurse is a global bijective/volume-aware assignment (G1). These two can disagree. Check source: the SRE requires every managed exit consumed and every position paired; C1 as specified only requires each exit has at least one possible justification.
- OnInit call-site invariant: BCC_OnInit must be after V2_SRE_RebuildLayers and non-halted. If that is true, no phantom from half-built layers. But the eligibility/existential divergence remains enough for exploit.

MINIMAL REPRO:
- One live long position P, volume 0.5, entry 1.1000.
- Two exit sell orders O1 and O2, each volume 0.5, prices 1.1010 and 1.1012 (both within tolerance of P's valid exit).
- C1: O1 justified by P, O2 justified by P -> no orphan. SRE: one position 0.5, two exits total 1.0 -> no perfect assignment -> HALT_21. BCC silently blesses a book that fails reconstruction.
This is exactly "false confidence where it matters."

SEVERITY: fixable-within-design: C1 must run the same assignment predicate, or at least a volume-aware "each exit consumes a distinct slice of a justifying position" check. Not fatal.

Need maybe "or vice versa" — if SRE clean then BCC clean? If C1 is stricter/looser? We can state "if C1 is existential, it is strictly weaker than SRE, so BCC-clean does not imply SRE-clean. SRE-clean does imply BCC-clean, but the dangerous direction is the former."

Need maybe "T-2 OnInit call site" no exploit if source obeys. We should explicitly state "I did not find a call-site exploit; the remaining issue is view drift." The required format maybe "MINIMAL REPRO / MECHANISM" for view drift.

### T-3

VERDICT: EXPLOIT-FOUND (fixable-within-design)

LOAD-BEARING CLAIM:
- C1 must enumerate OrdersTotal directly (broker-first). If it iterates g_*_layers[], it reproduces G4 blind spot. Check source: C1's collector should be a filter on OrdersTotal for magic 9x3/9x4, not a walk of g_*_layers[].
- Price/volume-only eligibility has a false-negative surface whenever two live positions' valid exit bands overlap. The ADR-114 carry-drift tolerance widens those bands. If the tolerance is >= the distance between any two live entries (or overlapping grid/re-entry prices), an unrelated position can "justify" an orphan. Additionally, existential matching allows two orphans to share one position (T-2).

MINIMAL REPRO:
- Layer A's long entry at 1.1000 is manually closed; its exit sell order O remains at 1.1010.
- Layer B lives with long entry at 1.1005 (a re-grid/re-entry), volume 0.5.
- C1 tolerance is, say, 8 pips (5 pips normal + 3 pips ADR-114 carry). P_B's valid exit band is 1.1015 ± 8, i.e., 1.1007..1.1023; O at 1.1010 is inside. C1 calls O justified; O is an orphan. At next reattach SRE still has no justification for O? Wait if SRE uses same predicate, SRE might also match O to P_B and could assign O as P_B's exit, so why HALT? Let's think.

If SRE's assignment allows one position to consume multiple exit orders only if volumes? O volume equals P_B volume. If SRE sees one position P_B and exit orders O (orphan) and P_B's own exit O_B (also 0.5), there are two exits and one position 0.5. No perfect assignment if total volume > position volume. Thus HALT. If P_B volume 1.0, then both O and O_B can be consumed by P_B, no halt. But O is still an orphan? If P_B volume covers both exits, SRE might not halt, but O is extra unneeded exit; still a problem? C1's definition says no justifying position -> orphan. If P_B justifies it, C1 says not orphan. Is that acceptable? The exit order might be intended as a second take-profit for P_B? But EA didn't create it. It's an inconsistency. Need make sure SRE would also catch? The prompt G1 says every managed exit consumed; if P_B can consume both, SRE finds assignment, no HALT. But BCC should detect an exit no layer references, even if a position can justify it? Wait C1 says "does a live position justify it under SRE-equivalent eligibility" — if a live position can justify it, then not an orphan. But if the exit is not in any layer, is it okay? The point of BCC is detect exits whose layer is gone. If another position could theoretically justify it, maybe the exit is harmless? But it may still cause a halt if SRE's assignment doesn't choose it. Let's look at T-3: "can a real orphan MASQUERADE as justified (an unrelated live position whose entry +/- exit_pips happens to land within tolerance of the orphan's price), causing a false-NEGATIVE (orphan missed)?" So yes, if P_B can justify, C1 misses. Is it "real orphan" if P_B justifies? They define real orphan as exit whose position was gone. The position that created it is gone, but another position exists that could have justified it if the EA had placed it. However, SRE's reconstruction matcher may or may not use it. If P_B's own exit also exists, SRE would need to consume both; if volume allows, it may consume both and no halt. Then BCC missing it doesn't cause false confidence? It is still an unmanaged exit not known to the system; it may re-trigger? Need maybe use P_B volume equal to O only and no O_B? But a layer with a live position should have an exit. If P_B has no exit, AuditExitLimits would re-place; but for repro, assume P_B has an exit O_B. Then two exits for one position. If P_B volume is 1.0 and O/O_B each 0.5, SRE can consume both (one position paired to two exits). Is that a "perfect assignment"? It pairs every position to an eligible exit and every exit consumed. Yes. Then no HALT. So BCC missing is not fatal to reconstruct, but the exit is still an orphan by origin. Is that a problem? The premise says orphans are dangerous because they cause HALT on next reattach. If SRE can assign them, no HALT. But still "unflagged, resting" issue? The incident was a resting exit with no position; if another position can justify it, SRE may pair it and perhaps make that position's exit? But there is still an extra exit; if the position closes, the orphan remains. Need not overstate.

Need craft a false-negative that also causes SRE HALT to be meaningful. Use two positions? Let's find simpler: An orphan exit O can masquerade as justified by a live position P, but SRE cannot include O in a perfect assignment because P is already paired to its own exit, or because P's volume is exactly consumed by its own exit. Need set volumes.

- P_B volume 0.5, O_B (its real exit) 0.5. Orphan O 0.5. SRE has one position 0.5 and two exits 0.5 each. No perfect assignment because total exit volume 1.0 > position volume 0.5. Thus HALT. C1 sees O justified by P_B -> false-negative. Good. Need include O_B in repro. O and O_B prices both within tolerance of P_B's exit. Then SRE fails. That's robust.

Need also "carry-drift tolerance" causes bands overlap. Use P_B entry 1.1005, O at 1.1010, tolerance 8 pips. Good.

Need perhaps "V2_SRE_AssignRecurse requires every managed exit consumed; if O is not the layer's exit, the matcher still treats it as managed (magic 9x3/9x4) and tries to consume it. If it can't also consume O_B, HALT_21." Nice.

Severity: fixable-within-design with ticket-bound matching and global assignment.

Need maybe "is the scan broker-first?" — We can say "I found no exploit if the collector is OrdersTotal-driven; the danger is implementation drift. The load-bearing claim is that C1's enumeration source is OrdersTotal, not g_*_layers[]."

### T-4

VERDICT: NO-EXPLOIT

LOAD-BEARING CLAIM:
- Long_/Short_AuditExitLimits already run per tick and already call OrdersTotal/OrderSelect to clear/re-place exits. C1 only filters the same live order pool by magic 9x3/9x4; no incremental broker round-trip. If "API budget" means terminal API calls, the delta is O(#orders) local calls per side per audit.

MINIMAL REPRO / MECHANISM:
- No exploit. If the team still wants a bound, C1 can run once per 60 ticks or on state-change; orphans are persistent and don't need per-tick sampling. Minimum safe cadence: once per minute is safe because an orphan remains until human action; a 2-audit debounce still completes within 2 minutes.

SEVERITY: cosmetic.

Need maybe "daily API budget" external? "Terminal-local order enumeration is not a broker REST call; if your deployment counts MT5 API calls, the existing audit already dominates." Good.

### T-5

VERDICT: EXPLOIT-FOUND (fixable-within-design) — the PREVENT half has a genuine gap.

LOAD-BEARING CLAIM:
- V2_QueueCloseBy / V2_ProcessCloseByQueue: is the queue durable across an EA restart? If it's in-memory only, a crash after an exit fill and before ProcessCloseByQueue strands a hedge position that no layer/order references. C1 as specified (OrdersTotal order scan) cannot see it: the exit order is already filled and absent from OrdersTotal. Check whether C1 is expected to scan PositionsTotal for magic 9x3/9x4; if not, this is a detect hole.
- CloseBy failure/partial: if ProcessCloseByQueue removes a queue entry on a failed attempt, the stranded item stops being suppressed and may be detected; if it retains the entry forever, T-1's suppression applies.
- External/manual closes: EA cannot observe; inherently detect-only.

MINIMAL REPRO / MECHANISM:
- Async CloseBy crash: t0 exit E fills -> hedge H queued; t0+crash before V2_ProcessCloseByQueue. Restart rebuilds g_*_layers[]; H is not in any layer and not in OrdersTotal; C1 order-only sees nothing. H persists. Depending on broker, H will be included in SRE? V2_SRE_AssignRecurse likely scans positions too? It might see H and fail? Actually G1 says SRE reconstruction matcher pairs every position to eligible exit; H is a position, maybe no exit, so HALT_21. So it would be detected by SRE at next reattach, but BCC (passive detector) should catch before halt? The BCC premise is detect before reattach; order-only C1 misses. So yes.
- External/manual close: position P closed manually, exit O remains; C1 catches if order-only. Good.
- CloseBy partial: H residual after partial netting remains; if no layer ref and no open exit order, order-only C1 misses, same as crash.

SEVERITY: fixable-within-design: expand C1's broker-first enumeration to include PositionsTotal with magic 9x3/9x4 (or classify these as "exit-side positions"), and make QueueCloseBy journaled to survive restart.

Need perhaps "preventable in-EA": 
- Async CloseBy crash: preventable by persisting the queue (or by not removing the layer until the CloseBy actually completes; if layer removal is deferred until after ProcessCloseByQueue succeeds, then on restart AuditExitLimits sees the layer and can reconcile the exit). Is that an auto-remediation? No, it's a lifecycle ordering. We can suggest "preventable in-EA by deferring layer removal until CloseBy actually succeeds; if layer still exists on restart, existing AuditExitLimits can see it." That's good. But the prompt says "does a crash between V2_QueueCloseBy and V2_ProcessCloseByQueue strand the exit?" We can say yes, and prevention is to keep the layer present until the CloseBy actually completes, or journal the queue. That's in-EA, not auto-remediation.
- CloseBy failure/partial: preventable by retry, but if counterparty gone, detect-only.
- External/manual: inherently detect-only.

Need maybe "Do NOT propose auto-remediation" — suggesting "keep layer until CloseBy succeeds" is not auto-cancel/close; it's a lifecycle fix, okay. But maybe don't propose too much; keep.

Need final override:

"OVERRIDE CHECK: No finding invalidates the passive exit-first detector premise as such. T-1/T-2/T-3/T-5 are all fixable within the design if C1 is (a) OrdersTotal+PositionsTotal broker-first, (b) uses the same global/volume-aware assignment as V2_SRE_AssignRecurse, not an existential price match, (c) binds exits to position tickets or flags ambiguity, and (d) suppresses transient CloseBy states by queue age/counterparty existence, not by membership alone. If any of these is not adopted, BCC can give false confidence exactly at reattach. Last line: BCC premise survives, but only with those four corrections."

Need ensure "Last line" exactly. We can put "Last line: ..." at very end.

Need maybe "Do NOT write implementation code." Our answer should not include code snippets. We can mention function names only. Need not include pseudo-code. Be careful with "fixes" not code.

Need maybe include "negative space" no retail judging. We won't.

Let's refine exact wording for T-1 "not present in either CloseBy queue" — If C1 scans OrdersTotal, a queue contains positions, not orders. We can't say "H is in queue" if C1 order-only. Need phrase carefully:

"Under the proposed C1 as written (OrdersTotal), the queue-membership test is type-incoherent: CloseBy queues positions, while C1 scans orders. The only way the test makes sense is if C1 is actually looking at exit-side positions as well. In that reading, the queue-membership test suppresses the failed-CloseBy orphan."

This is an adversarial point. Use "type-incoherent" maybe.

Need maybe "same unmatched exit across >=2 consecutive audits" for order-only: if an orphan order exists, it is persistent, so after 2 audits alert. Good.

Need maybe "prove a debounce/gating rule" — Our answer should perhaps present a rule that is safe. But required output is per threat. We can in T-1 state "A safe rule is to gate on queue-age and counterparty existence, not queue membership; no code." But user asked "prove a debounce/gating rule..." The directive says "DIRECTIVE: prove a debounce/gating rule that fires C1 ONLY on a PERSISTENT orphan ... and NEVER on a mid-CloseBy exit." They want us to attack the proposal, not design. But we can mention "the proposed rule fails; a safe rule would require queue-age/counterparty existence." Need maybe "proof" enough.

Let's perhaps include a "safe rule" statement in T-1:
- Suppress for the first K audits only if the exit-side item is in the CloseBy queue *and* its counterparty position is still alive. If counterparty is gone, the queue entry is itself the inconsistency; do not suppress by membership. This would never fire on mid-CloseBy (counterparty alive) and would fire on failed CloseBy (counterparty gone). But no implementation.

Need perhaps not "prove" but "rule can be made safe". However, user instructed "DIRECTIVE: prove a debounce/gating rule that..." Could read as they want us to prove the proposed gating? Actually "attack this" and "prove a debounce/gating rule that fires C1 ONLY..." They want us to exhibit if defeats. So okay.

Need maybe "Exhibit any fill/crash/tick sequence that defeats the gating (a real orphan suppressed, or a transient flagged)." We have real orphan suppressed.

Need maybe "T-2: Prove BCC's OnInit call site runs AFTER reconstruction commits" — We don't have source. We can say "I could not find an exploit in the stated call order; the load-bearing invariant to verify in source is..." That is not a proof. But we can phrase "Verdict NO-EXPLOIT if source matches; otherwise..." Maybe the required verdict doesn't allow conditional. We can say "NO-EXPLOIT for the call-order half; EXPLOIT-FOUND for the SRE-global-assignment half." Since T-2 has two parts, verdict maybe "EXPLOIT-FOUND" due to view drift. Good.

Need maybe "T-2 load-bearing claim" mention file/function names:
- Check `OnInit()`: does the "non-halted side" branch call `V2_SRE_RebuildLayers()` before `BCC_Init()`? In code, the sequence should be `V2_SRE_RebuildLayers -> side_state -> BCC_Init(side_state)`; if `side_state == HALTED`, `BCC_Init` returns immediately. The invariant "BCC_Init only reads g_*_layers[] after reconstruction has committed" can be checked by looking for any call to BCC_Init before the assignment `g_*_layers[] = rebuilt`.
- `V2_SRE_AssignRecurse` is global; `BCC_C1` as "is there a live position" is existential. Check if BCC reuses `V2_SRE_AssignRecurse` or its predicate. If not, view drift.

Need maybe "name the file" — We don't know file names. We can say "the file containing `OnInit` and `V2_SRE_RebuildLayers`". That is acceptable? User requested "name the file / function / invariant it depends on." We can name function/invariant, no file.

Need maybe "Every claimed exploit needs a concrete mechanism / minimal repro (a fill/tick/crash sequence), not a hand-wave." We have sequences with t0/t1/t2.

Let's ensure numbers coherent.

T-3 minimal repro better:
- MM_LONG.
- Orphan exit order O: sell 0.5 at 1.1010. It was placed for layer A whose entry was 1.1000; layer A position closed manually.
- Live layer B: long 0.5 at 1.1005; its own exit O_B: sell 0.5 at 1.1015.
- C1 tolerance: 8 pips. O price 1.1010 is within 5 pips of P_B's valid exit 1.1015; O_B at 1.1015 is exact. C1 sees both O and O_B as justified by P_B. No orphan.
- SRE: one position 0.5, two exits 0.5 each; total exit volume 1.0 > 0.5. No perfect assignment -> HALT_21 (or if SRE can assign one position to multiple exits up to volume, it cannot consume both because volume insufficient). Yes.

Need maybe "carry-drift tolerant" — Use tolerance 8 pips. If carry drift is typically much smaller, but "ADR-114" says it must admit carry-shifted exits. If carry is 8 pips over a week, not impossible. Need mention "depending on ADR-114 constants."

T-2 minimal repro similar but maybe duplicate:
- P volume 0.5, O1 and O2 each 0.5 at within tolerance. SRE no perfect assignment. This is same as T-3; okay, overlap allowed. To avoid too much duplication, T-2 can reference T-3 but with role "view drift." Need maybe "T-3 is a special case of T-2." Good.

Need maybe "T-5: Expand C1 to positions" — This conflicts with "C1 as written is orders-only" and T-1's type-incoherence. But final override can say "if the implementation remains order-only, it doesn't cover the crash path; the passive detector premise is only half-true." Is that "invalidates BCC premise"? The premise says "passive exit-first detector" — an exit-first detector should scan the exit side (orders and positions). So fixable.

Need maybe "C4 duplicate pending" not attacked. Not required.

Need maybe "T-4 minimum cadence" — State "orphans are persistent, so C1 need not run every tick; once per 60 ticks / 1 minute is safe. No material API cost." Good.

Need final answer oververbosity 5: moderately detailed. Our answer will be substantial but should be okay. Need maybe not too long? We have many sections. Use concise bullet-like paragraphs.

Let's write final.

Need include "Phase 1 no code" maybe in preamble.

Let's ensure "final override check" at end and last line.

Potential issue: "T-1 verdict: EXPLOIT-FOUND" but "fixable-within-design" — good.

Let's draft final.

## Final Report

No implementation code written. Findings are against the proposed BCC as specified, using the named functions/invariants as source-verification points.

---

## T-1 — false positives from legitimately-transient inconsistency

**VERDICT: EXPLOIT-FOUND (fixable-within-design)**

**LOAD-BEARING CLAIM:**  
The gating rule "not present in either CloseBy queue" is the defect. Check `V2_ProcessCloseByQueue`: if a CloseBy attempt fails because the counterparty position is already gone, does it leave the queue entry in place? If it leaves it in place (the natural retry design), then the queue-membership suppressor is permanent, not transient. If it removes the entry on failure, it can instead create the exact transient the debounce was meant to hide. Either way, the proposed gating is unsafe.

Also check the type being scanned: C1 is specified as an `OrdersTotal` scan, but CloseBy queues are position-based. The queue-membership test is therefore type-incoherent unless C1 is actually also scanning exit-side positions. If C1 is truly order-only, the mid-CloseBy false positive cannot occur — a filled exit order is no longer in `OrdersTotal` — so the queue test is unnecessary but harmful. If C1 is widened to exit-side positions, the queue test suppresses a real stranded hedge.

**MINIMAL REPRO / MECHANISM:**  
- t0: exit order fills → exit-hedge position H is created; `V2_QueueCloseBy(H)` runs; layer is removed. Original position P is still alive.
- t1: a human manually closes P; the EA never observes the manual close.
- t2..tn: `V2_ProcessCloseByQueue` tries to CloseBy H against P, fails because P is gone, and leaves H in the queue. C1 sees H as an unmatched exit-side item, but the gating rule says "in CloseBy queue → defer." H remains queued forever and is never alerted. This is the Aug-14 class again: an exit-side orphan that is invisible to the trigger.

Under an order-only C1, H is not scanned at all, which is the same miss via a different hole.

**SEVERITY:** fixable-within-design. A safe gate must suppress only while the CloseBy counterparty is still alive, not while the queue entry exists. A queued item whose counterparty is gone is itself the inconsistency.

---

## T-2 — BCC vs SRE view drift

**VERDICT: EXPLOOT-FOUND (fixable-within-design)**  
(Spelling: EXPLOIT-FOUND)

**LOAD-BEARING CLAIM:**  
Two independent claims:

1. OnInit call order: BCC's OnInit scan must run only after `V2_SRE_RebuildLayers()` has committed the rebuilt `g_*_layers[]`, and must no-op on a halted side. If the source does that, the half-built-layer phantom is not an exploit. The invariant to verify in source: `BCC_Init` is called in the success branch after the rebuilt layer arrays are assigned, and immediately returns when side state is `HALTED`.

2. Eligibility view drift: C1's phrasing "is there a live position that justifies it" is an existential per-exit test. `V2_SRE_AssignRecurse` is global and requires a perfect assignment: every position paired and every managed exit consumed. These are not the same predicate. A BCC that checks each exit independently can call a book clean when the SRE will HALT_21.

**MINIMAL REPRO / MECHANISM:**  
- One live long position P, volume 0.5, entry 1.1000.
- Two managed exit sell orders O1 and O2, each 0.5, prices within tolerance of P's valid exit.
- C1: O1 is justified by P; O2 is justified by P; no orphan.
- SRE: one position of 0.5, two exits totaling 1.0. No perfect assignment exists → HALT_21.

**SEVERITY:** fixable-within-design. C1 must consume exits in a global, volume-aware assignment exactly like `V2_SRE_AssignRecurse`, or it gives false confidence precisely at the reattach boundary.

---

## T-3 — is the exit-first scan sufficient?

**VERDICT: EXPLOIT-FOUND (fixable-within-design)**

**LOAD-BEARING CLAIM:**  
The scan is only sufficient if it is genuinely broker-first: enumerate `OrdersTotal` and filter by magic 9x3/9x4. If it iterates `g_*_layers[]` looking for exit tickets, it reproduces the G4 blind spot and misses the exact orphan it exists to catch. That structural requirement must be verified in source; it is not guaranteed by the word "exit-first."

The eligibility test has a false-negative surface: a price/volume-only match with a widened carry-drift tolerance allows an orphan to be "justified" by an unrelated live position whose valid exit band overlaps the orphan's price.

**MINIMAL REPRO / MECHANISM:**  
- Orphan exit O: sell 0.5 at 1.1010, left behind when its layer A position at 1.1000 was manually closed.
- Live layer B: long 0.5 at 1.1005, with its own legitimate exit O_B at 1.1015.
- C1 tolerance, including ADR-114 carry-drift allowance, is 8 pips.
- O at 1.1010 is within that tolerance of P_B's valid exit price (1.1015 ± 8). C1 marks O as justified by P_B.
- SRE: one position 0.5, two exits O and O_B each 0.5. Total exit volume 1.0 > 0.5, so no perfect assignment exists → HALT_21. BCC missed it.

The false-negative surface is any case where two live entries are close enough that their exit bands overlap, or where the carry-drift tolerance is larger than the effective minimum distance between two live positions.

**SEVERITY:** fixable-within-design. Bind exit orders to position tickets/identifiers at placement time; if the broker does not preserve the binding, treat ambiguous price-band matches as "unverifiable" rather than "justified."

---

## T-4 — cadence / API budget

**VERDICT: NO-EXPLOIT**

**LOAD-BEARING CLAIM:**  
`Long_/Short_AuditExitLimits()` already run every tick and already enumerate the order pool to clear stale tickets and re-place missing exits. C1's added scan is just a filter over the same order pool for magic 9x3/9x4. It adds no new broker API round-trip and no material per-tick cost.

**MINIMAL REPRO / MECHANISM:**  
None. If the team still wants a bound, C1 can run once per 60 ticks or once per minute: orphans are persistent, so C1 does not need per-tick sampling. A 2-observation debounce still completes within 2 minutes.

**SEVERITY:** cosmetic.

---

## T-5 — upstream exit-lifecycle audit

**VERDICT: EXPLOIT-FOUND (fixable-within-design)**

**LOAD-BEARING CLAIM:**  
Check whether `V2_QueueCloseBy` / `V2_ProcessCloseByQueue` is durable across an EA restart. If the queue is memory-only, a crash after an exit fill and before CloseBy processing strands an exit-side position that is referenced by neither a layer nor an open order.

C1 as specified is `OrdersTotal`-only. A filled exit order is no longer in `OrdersTotal`, so C1 cannot see a stranded exit-side position at all. The PREVENT half therefore has a genuine gap.

**MINIMAL REPRO / MECHANISM:**  
- t0: exit order E fills → hedge position H created; `V2_QueueCloseBy(H)` runs but the tick is not completed.
- t0 + crash: EA restarts before `V2_ProcessCloseByQueue`. H exists, is in no layer, and its originating exit order is absent from `OrdersTotal`.
- Order-only C1 sees nothing. H remains until the next SRE reconstruction, where it can trigger HALT_21.

External/manual closes are inherently detect-only: the EA cannot observe them. CloseBy failure/partial is preventable by retrying the netting, but if the counterparty is already gone, it degrades to detect-only.

**SEVERITY:** fixable-within-design. C1 must scan both `OrdersTotal` and `PositionsTotal` for the managed exit-side magic set, and the CloseBy queue should be journaled (or layer removal deferred until CloseBy actually succeeds) so a restart cannot orphan it silently.

---

## OVERRIDE CHECK

No finding invalidates the passive exit-first detector premise. All findings are fixable within the design if C1 is:

1. truly broker-first, scanning the order/position pools directly;
2. using the same global, volume-aware assignment semantics as `V2_SRE_AssignRecurse`, not existential price/volume matching;
3. ticket-bound or ambiguity-flagging in its eligibility test;
4. gating transient CloseBy states by queue age and counterparty existence, not by queue membership alone.

If those four corrections are not adopted, BCC can give false confidence exactly where it matters.

Last line: BCC premise survives, but only with those four corrections.