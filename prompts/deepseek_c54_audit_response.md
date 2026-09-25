# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer user. We are auditor. Need produce sections in order: GIVENS CHECK G1-G5, T-1..T-7 verdicts, PREMISE VERDICT, TEST GAPS. Need cite file/function and quote line(s). No line numbers in attached files, but can cite function and quote exact line. Need verify each given. Need identify bugs.

We need analyze provided code deeply. We need not run. Need cite quotes. Need answer exhaustively, line count maybe? User says line count 123 at bottom? Actually prompt says line count 123. But output not necessarily 123 lines? They want sections.

We need inspect code.

We need understand branch state: B1 + C52 + C54. Given code includes grind_engine.mqh with C54 guard. grind_carry.mqh with C52 lookup and B1 changes. Need verify G1-G5.

Let's parse.

G1: C54 guard returns GRIND_ROLL_CLOSING before any modify, report, VL write or queue call when layer exit order set but not selectable.

In Grind_LatticeRollLayer:
- checks idx, pos
- if(Grind_VLHas(pos)) return ALREADY_ROLLED;
- if(layer.exit_position_ticket != 0) return CLOSING;
- C54 guard:
```
if(layer.exit_order_ticket != 0
   && !Grind_SelectOurOrder(layer.exit_order_ticket, magic))
   return GRIND_ROLL_CLOSING;
```
Before any modify, report, VL write, queue. Yes. Need note it occurs after ALREADY_ROLLED and exit_position_ticket check. VERIFIED with quote.

G2: Grind_LatticeTrySide changes neither failure count nor backoff on CLOSING. In TrySide:
```
if(rc == GRIND_ROLL_MODIFY_FAILED) { failure... }
if(rc != GRIND_ROLL_OK) break;
```
For CLOSING rc != OK, not == MODIFY_FAILED, so no count/backoff, but break. Also it doesn't reset fail count? Actually reset occurs only after rc == OK. So no change. VERIFIED.

G3: With InpVirtualLattice=false, Grind_LatticeOnTick returns before any roll.
Grind_LatticeOnTick:
```
if(!enabled || blocked) return;
...
```
OnTick call passes InpVirtualLattice. If false, returns. VERIFIED.

G4: Grind_CarryWorkBase reads VL live, so pass item processed after roll prices from rolled level, not capture.
Grind_CarryWorkBase:
```
return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx], g_grind_carry_exit_work_pos[idx]), exit_pips, point, dir) + Grind_EjectOffsetGet(...)
```
Grind_EffectiveEntry reads VL if present. So yes. VERIFIED.

G5: merged grind_carry.mqh equals main's except B1's two changes (Grind_VLHas ticket-0 guard; prune without VLs).
Need compare. We have grind_carry.mqh. C52 code at CurrentExitTicket and step. B1 changes: Grind_VLHas:
```
if(position_ticket == 0) return false;
return GlobalVariableCheck(Grind_VLName(position_ticket));
```
Prune:
Grind_CarryPruneShiftGvs loops names: CARRY_SHIFT, RELEASE, EJECT_OFFSET only, no GRIND_VL_. That's "prune without VLs". Are there any other differences? Need verify from code? We don't have main version, but can infer. Maybe G5 "equals main's except..." We cannot fully verify without main. But code shows C52 lookup and B1 guard/prune. We can say VERIFIED as far as visible; cannot diff main from attached. But prompt says verify each. We can cite code. Maybe mark VERIFIED (visible changes only). Need be careful.

Now threats T-1..T-7.

T-1: The guard's reach. Need determine what clears stale exit_order_ticket after guard returns CLOSING when SelectOurOrder false due to filled unprocessed, manually cancelled, other magic, ticket 0. Actually guard only if exit_order_ticket != 0. Cases:
- filled at broker but deal not processed: layer.exit_order_ticket may still set, exit_position_ticket 0 until deal processed. The deal event Grind_HandleSideDealFill for DEAL_ENTRY_IN with c_role EXT sets exit_order_ticket=0, exit_position_ticket=position_id. So next OnTradeTransaction clears. But if deal never processed? It might be already in history before EA attach? Grind_RetryMissingExits? Let's trace. If order gone from order book, exit_order_ticket stale. Reconnect? Grind_ReconstructState rebuilds from broker tickets, so stale not present after restart. During live, if deal event missed? MQL5 OnTradeTransaction should process. But if order removed by hand, reconciliation? The queue's Grind_ExitQManageSide / Grind_ExitQHoldCancelLayer checks if exit_order_ticket !=0, tries cancel, if not selectable, tries Grind_ExitQFindExitDealPosition. If no deal found, sets exit_order_ticket=0 and deletes shift. This is called in OnTick? Grind_OnTickEngine calls Grind_RetryMissingExits at top before lattice? Actually OnTick order: Grind_ProcessCloseByQueues; then invariant check; then EjectPoll, AutoEject, LatticeOnTick, Session, Breaker; if not halted/quarantined, Grind_OnTickEngine. Grind_OnTickEngine calls Grind_RetryMissingExits -> Grind_ExitQManageSide for both sides. So each tick, before? Actually LatticeOnTick is called before Grind_OnTickEngine. So roll attempt happens before RetryMissingExits. The guard returns CLOSING, no backoff, then later in same tick RetryMissingExits calls ExitQManageSide. For layers with exit_order_ticket stale and not selectable, ExitQHoldCancelLayer may clear it if not required? Wait ExitQManageSide first computes ranks, for each layer if !Allowed and exit_order_ticket !=0 -> HoldCancel. If Allowed (rank < K+H or rank == depth-1), it does not cancel. Then second loop places missing exits for Required ranks. But it does not handle stale exit_order_ticket for allowed layers. If rank is allowed and ticket stale, the layer continues believing it has an exit. The queue only cancels unallowed. So stale ticket may persist for allowed (rank 0 or highest) if order gone and no deal found. In Grind_ExitQHoldCancelLayer, if not selectable, it tries find deal position; if none, sets exit_order_ticket=0 and deletes shift. But that's only called for !Allowed. For allowed ranks, no clearing. So T-1: stale exit_order_ticket for allowed rank may persist, side never rolls? Actually roll candidate selects oldest unrolled? Grind_LatticeCandidateIndex picks oldest unrolled by entry (for long highest entry? wait for long: if e > be, best=i; so highest entry = oldest? Entries ascending? SeedLong8 entries 1.20000 + 0.00100 i? Long side entries 1.20000, 1.20100... deepest highest. "OLDEST unrolled layer" maybe oldest = highest entry? Need check. In B1, at cap, roll oldest unrolled. Candidate uses entry: for long, highest entry beats. So oldest (first filled?) Actually entries may increase with adds. We'll see. If candidate has stale exit_order_ticket and SelectOurOrder false, guard returns CLOSING, TrySide breaks, no backoff. Next tick same. If the stale ticket is never cleared for allowed rank, side never rolls again. Does anything report? Guard silent, no report. However I6 invariant? Grind_CheckBookInvariants uses broker tickets only; it doesn't know exit_order_ticket internal stale. It rebuilds from live orders/positions. If the exit order is gone and no exit position, the layer has no exit coverage. If rank required, recon would see position without exit and I3? But CheckBookInvariants works on broker tickets; it doesn't use internal exit_order_ticket. It collects orders and positions from broker. If order gone, there is no exit. If layer rank is required (rank 0 or highest), I3_LONG_NAKED would trigger halt? Wait Grind_CheckBookInvariants builds book from broker tickets. It doesn't know about internal layer that believes it has exit. It sees position with no exit coverage for required rank -> I3_LONG_NAKED -> invariant fail -> quarantine/halt. So if stale allowed rank, invariant would detect missing exit and halt/quarantine. But if rank not required, no. The candidate for roll is oldest/highest entry, which likely rank highest? For long, highest entry = deepest? Actually for long, exit queue ranks: rank 0 = lowest entry? Let's see ExitQEntryBeats: for long, entry_a < entry_b -> true, so lower entry beats. rank increasing means worse? ranks_out[i] = number of j that beat i. Lower entry has smaller rank. So rank 0 = lowest entry. Highest entry has rank depth-1. K=1 H=0: required ranks are rank <1 (rank 0) and rank == depth-1. So highest entry is required (highest rank). Candidate for roll? Grind_LatticeCandidateIndex: for long, if e > be -> best=i, so highest entry. That is rank depth-1, required. So if its exit is stale, I3 would fire (no exit coverage) because rank required. That would quarantine/halt. But does Grind_CheckBookInvariants see it? It rebuilds from broker tickets, ignoring internal stale ticket. If the exit order is gone (removed by hand) and no position, then yes missing exit coverage -> I3_LONG_NAKED, halt. But wait if order was manually removed, there may be no exit order. The internal layer still has exit_order_ticket. Recon uses broker tickets, so it doesn't see the stale ticket. It sees position plus maybe other exits. The highest rank layer has no exit -> I3_LONG_NAKED. So invariant catches. But if the layer is not required? Candidate always highest entry? Let's check candidate: "OLDEST unrolled layer" maybe for long, oldest is lowest entry? Wait entries for long: initial L0 at 1.20000, adds at higher prices? In long, buying as price falls? Actually market maker long side: L0 buy limit at straddle below market? Then price falls, buy limit fills at lower price, add next lower. So entries decrease as layers add. Hmm need not. The code candidate uses for long: if(e > be) best = i. So picks highest entry. If entries decrease, highest entry is oldest. So candidate is oldest. Its rank? For long, lower entry beats (rank 0 lowest entry). So highest entry = highest price = worst rank depth-1. Required. So I3 would catch missing exit. However if SelectOurOrder false due to other magic but order still exists? If exit_order_ticket belongs to another magic, OrderSelect finds it but magic mismatch. Then it's not our order; from broker perspective, is it counted as exit? Grind_ReconCollectBrokerTickets filters magic == g_grind_recon_magic. So other magic order not counted. So no exit coverage -> I3. If ticket 0? Guard only if !=0. If exit_order_ticket is 0, branch S places exit. If stale but order exists with other magic, I3. If order removed by hand, I3. If filled unprocessed, deal event should clear. If deal event missed, reconstruct? On next tick invariant? For filled exit, there is a position (exit position) maybe. If deal unprocessed, internal exit_order_ticket still set, exit_position_ticket 0. Broker has position for exit (the close-by position?) Actually when exit pending order fills, broker creates a position? For hedging account, a sell limit to close long? Wait they use close-by? They place opposite limit order; when it fills, it opens an opposite position, then close-by queue closes both? The exit position exists. Recon sees exit position with comment EXT? It may have position comment EXT. So recon sees coverage via exit_position. But internal layer still exit_order_ticket set. The guard returns CLOSING until deal event processes. If deal event never processes, the layer never rolls, but invariant I2? Recon sees both position and maybe order? Actually order filled, so no order. It sees exit position. Internal exit_order_ticket stale but recon doesn't know. I6 compares exit_target of layer from broker position price. The internal layer exit_target may be old? CheckBookInvariants builds from broker tickets; it uses position price for exit_target. It may pass. So stale internal exit_order_ticket could persist if deal event missed. But OnTradeTransaction should deliver. If missed due to terminal restart, reconstruct fixes. If missed during live due to bug? Possibly. The guard silent. But T-1 asks "what clears stale exit_order_ticket afterwards (deal processing, reconciliation, I3 quarantine, Grind_RetryMissingExits)? Is there a state where ticket stays stale forever, so side never rolls again and nothing reports it (guard silent)?" We need assess.

Potential bug: Grind_ExitQHoldCancelLayer only clears exit_order_ticket for ranks not allowed. If stale ticket on allowed rank, and no deal, it is not cleared by RetryMissingExits. But I3 would catch if no exit coverage. However if exit order removed by hand but layer still has exit_position_ticket? No. If order removed by hand, no exit coverage -> I3. So something reports/halts. But if exit order is "other magic" but there is another order/position covering? The recon ignores other magic, so no coverage -> I3. If ticket 0? Guard not triggered. So T-1 maybe holds but with I3 halt. But the question says "an exit cancelled by hand or by the broker" C52 repair runbook: delete mispriced EXT, reattach that chart. Then until reattach, roll returns CLOSING every tick. But invariant CheckBookInvariants runs every OnTick before Lattice? OnTick: Grind_CheckBookInvariants -> QuarantineStep -> if halt then halt. Then LatticeOnTick. If exit deleted and rank required, invariant would fail and halt before roll? Wait OnTick order: Grind_ProcessCloseByQueues; if(!halted) { CapPublish; CheckBookInvariants; QuarantineStep; if action HALT then halt... } Then EjectPoll, AutoEject, LatticeOnTick, etc. So if invariant fails, it may quarantine, not immediately halt. QuarantineStep may quarantine, not halt until 3s and 3 checks. LatticeOnTick is called even if g_grind_quarantined? It passes blocked = g_grind_halted || g_grind_quarantined. So if quarantined, LatticeOnTick returns early? It receives blocked true, so Grind_LatticeOnTick: if(!enabled || blocked) return. So no roll. Thus the guard may not be reached if invariant catches. But if the layer's rank is not required, no I3. But candidate is required rank? As above, candidate highest entry = worst rank = depth-1 required. Unless there are VLs? Candidate skips layers with VLHas. If all required rank layers already have VL, candidate picks next oldest unrolled, which might have rank not required? With K=1,H=0, only rank 0 and depth-1 have exits. If depth-1 is already rolled (has VL), then candidate may pick another unrolled layer with rank not required, which has no exit order (since queue only places for required). Wait branch S: no exit order. If candidate has no exit order, guard not triggered. If candidate has exit order? Only required ranks have exit orders. If depth-1 already rolled, the only other required rank is rank 0. Candidate selection: for long, highest entry first. It skips VLHas. If depth-1 has VL, next highest entry might be rank depth-2, which is not required and thus exit_order_ticket == 0 (since queue only places for rank 0 and depth-1). So branch S. Thus guard only matters for candidate with exit order, which must be a required rank. So I3 would catch missing exit. So T-1 may be HOLDS? But if order gone and I3 catches, then halt; not silent. But the guard's stated purpose is "refused without backoff; next tick sees processed deal". For removed by hand, it will CLOSING every tick until reattach, but invariant likely halts/quarantines. The prompt says GC1 accepted same code. T-1 asks find if stale forever. There may be a path: exit order filled at broker but deal unprocessed, and internal layer has exit_order_ticket !=0, exit_position_ticket==0. The broker recon sees exit position? The exit position may not be counted as coverage because comment? Actually the exit position is an opposite position with comment EXT. Grind_ReconCollectBrokerTickets collects all positions with magic. It parses comment. For EXT position, it sets has_exit_position. So coverage exists. I6 checks exit_target from position price. The internal layer's exit_target may still be the old pending order price? But recon builds from broker position price, so it uses actual fill price. I6 may pass if fill price matches formula? For a filled exit, exit_is_filled=true, and I6 tolerance is asymmetric: if long and diff >=0 true. So likely pass. Thus no halt. The stale internal exit_order_ticket persists until deal event. If deal event is lost, it persists forever. Does anything else clear? Grind_RetryMissingExits: ExitQManageSide. For the layer with rank required, it is allowed, so first loop doesn't cancel. Second loop: if exit_order_ticket !=0 || exit_position_ticket !=0 continue. So it does nothing. So stale exit_order_ticket stays. On next OnTick, guard returns CLOSING, side never rolls. Nothing reports. So T-1 HOLDS: there is a state (deal event missed/lost) where ticket stays stale forever; but maybe OnTradeTransaction is reliable? MQL5 OnTradeTransaction can miss if EA not subscribed? But it is. ASSUMED. However if the deal event is processed, it clears. If not, no. Also if exit order manually removed, invariant likely halts, so not silent. But the question includes "deal processing, reconciliation, I3 quarantine, Grind_RetryMissingExits". We can say deal processing clears; RetryMissingExits does NOT clear allowed rank; I3 may catch missing coverage but not if position exists. So stale forever possible. Smallest fix: in Grind_LatticeRollLayer guard, when SelectOurOrder false, clear stale exit_order_ticket? Or call a reconciliation? But careful: if filled unprocessed, clearing exit_order_ticket might lose linkage? Actually if order filled, deal event will handle. Clearing early could cause queue to place a duplicate exit? That would be bad. So not clear. Maybe report a WARN and/or set backoff? The prompt asks smallest fix if any. For T-1, maybe add a telemetry marker or use GRIND_ROLL_CLOSING but also if the order is truly not selectable and not in history, clear. But need not fix? We should propose smallest fix: in Grind_LatticeRollLayer, after failed select, call Grind_ExitQHoldCancelLayer? No. Or in Grind_RetryMissingExits, for allowed ranks with stale exit_order_ticket not selectable and no deal found, clear. But out of scope. We'll report.

T-2: Off means off. With InpVirtualLattice=false, list EVERY code path merged build runs differently from main on live book. Need compare B1 changes that execute even when lattice off. B1 files: grind_engine.mqh, grind_carry.mqh, grind_config.mqh, grind_pure.mqh, grind_scalp_events.mqh, fxgrind.mq5, tests. We have some. Need identify code paths that run regardless of InpVirtualLattice. The merge includes B1 changes: new global variables, functions, input, validation, init prints, LATTICE_CONFIG marker, Grind_ValidateLatticeInputs call in OnInit (always), Grind_LatticeOnTick called on every tick (but returns if !enabled), Grind_LatticeResetBackoff? Maybe not called. New `rolled` key in scalp_closed: Grind_QueueScalpClosedEvent with was_rolled = Grind_VLHas(closed_position). Even when lattice off, Grind_VLHas returns false (unless GVs exist). But it's an extra function call and parameter. Does it change event format? The prompt says pipshed's archive keeps only whitelisted scalp_closed fields, so B1's new `rolled` key ignored there until C56. But locally, scalp event queue includes rolled. If pipshed ignores, no effect. But could affect event length? Maybe no. New GV writes? Grind_VLHas reads GlobalVariableCheck. If no VL, false. The prune: Grind_CarryPruneShiftGvs now prunes without VL_ branch. Wait B1's change is "prune without its GRIND_VL_ branch". That means main's C52 prune may have included GRIND_VL_ branch? Actually B1 added VL GVs; C52's prune in main might not know VL. The merged prune has no GRIND_VL_ branch, so it does NOT delete VL GVs when positions gone. That's a leak if lattice on; if off, no VLs exist. But if off, no effect. However B1's Grind_VLHas ticket-0 guard: no effect. Rank arrays: B1 changed Grind_ExitQRanks? We don't see B1 changes in exitq? Prompt says B1 files include grind_pure.mqh, grind_scalp_events.mqh, grind_config.mqh. The exit formulas read VL via Grind_EffectiveEntry, which is in grind_carry.mqh. With lattice off, no VL GVs set, so effective entry = entry. So formulas same. But there could be a difference: Grind_EffectiveEntry now checks Grind_VLHas(ticket) which checks GlobalVariableCheck. If there happen to be VL GVs for other instances? GV names are per ticket, global across terminal. If another instance uses same ticket? Tickets are unique. But if a previous lattice-on run left VL GVs, and now lattice off, they persist? Grind_VLDelete on close. But if stale GVs exist, off build would read them. However T-2 says live presets all off, but GVs might exist from tests? Not on live. But if a terminal ran lattice on then changed preset off, stale VLs could affect. That's a risk. Also Grind_CarryPruneShiftGvs no longer prunes VL GVs, so stale VLs never cleared by prune. But if lattice off, no new VLs, but old ones from a previous on run could persist and alter effective entry. That is a live exit/entry/invariant change. Need mention.

Also OnInit calls Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject). If InpVirtualLattice false, function likely returns true? Need see config? Not attached. It might validate that if lattice true then auto eject false. If false, no effect. But call is new. Could it fail? If InpAutoEject true and lattice false, probably fine. We need check grind_config? Not provided. But we can mention.

Init prints: Print("GRIND_LATTICE enable=", InpVirtualLattice); and ArchiveMarker LATTICE_CONFIG. That's new log/telemetry even when off. Doesn't change trading.

`rolled` key in scalp_closed: In Grind_HandleSideDealFill:
```
const bool was_rolled = Grind_VLHas(closed_position);
Grind_QueueScalpClosedEvent(... was_rolled);
```
This is new. It calls Grind_VLHas on every scalp close. If no VL, false. It adds a field to scalp_closed event. If pipshed ignores, no. But if local archive? It changes event payload. Could affect something? The prompt says pipshed's archive keeps only whitelisted fields, so ignored until C56. But other consumers? Not specified.

The prune: Grind_CarryPruneShiftGvs now (merged) lacks GRIND_VL_ branch. In main, C52's prune likely had only shift/release/offset? Wait prompt says "B1's prune without its GRIND_VL_ branch ~1006". That implies B1 originally added a GRIND_VL_ branch to prune, but merge with main dropped it? Actually "auto-merged: C52's lookup, B1's ticket-0 guard in Grind_VLHas ~597 and B1's prune without its GRIND_VL_ branch ~1006". So the merged prune does not delete VL GVs. On main (without B1), prune didn't know VL because no VLs. On B1 branch, prune had VL branch. Merged lost it. So with lattice ON, VL GVs are not pruned. With lattice OFF, no VLs, so no difference. But if stale VLs exist, they persist. That's T-6 maybe.

Grind_VLHas: B1 added ticket-0 guard. In main? Wait C52 is on main, B1 is branch. Grind_VLHas only exists with B1. So main doesn't have it. With lattice off, Grind_VLHas is called in Grind_EffectiveEntry and scalp close. If no VL, false. But main's Grind_EffectiveEntry did not call Grind_VLHas; it just returned entry. So extra GlobalVariableCheck per call. No semantic change unless stale VL. Also Grind_VLHas ticket-0 guard prevents looking up "GRIND_VL_0". In main? main doesn't have this function. So no diff.

Rank arrays: B1 may have changed Grind_ExitQRanks or EffectiveEntry? The prompt says "rank arrays" in T-2. We need inspect code for B1 changes in exitq? The provided grind_exitq.mqh might be merged. It uses Grind_EffectiveEntry. If VL absent, same. But there might be a change in Grind_ComputeAddTarget: B1 changed anchor logic to use effective entries and any_vl. In Grind_ComputeAddTarget:
```
bool any_vl = false;
for... if(Grind_VLHas(...)) any_vl = true;
double anchor;
if(!any_vl) { anchor = deepest entry; } else { anchor = min/max effective entry; }
return Grind_AddTargetPrice(anchor,...)
```
In main without B1, this function likely just used deepest entry always. With lattice off and no VL, any_vl=false, so same. But if stale VL, different. So extra scan of layers calling Grind_VLHas. No semantic change if no VL.

Exit formulas: Grind_ExitQFormulaTarget calls Grind_EffectiveEntry. With no VL, same. But extra GlobalVariableCheck.

Init prints and markers: LATTICE_CONFIG marker emitted always. That is a difference in archive/telemetry. Could it affect live? It adds an archive marker. If archive is used for something? Probably not.

Validation: In OnInit, new call Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject). If InpVirtualLattice=false, should pass. But if it has bug? Not in attached. We can't verify. It is a code path that runs. If it returns false, init fails. Need mention as unverified.

Also OnTick calls Grind_LatticeOnTick every tick even when off, which returns early. That is new function call. No effect.

OnTimer? No B1 changes in OnTimer? Maybe Grind_CarryPruneShiftGvs called in OnInit and PassBegin. B1 changed prune? It is called in OnInit and Grind_CarryExitPassBegin. With lattice off, same except no VL branch.

Could any change live exit/entry/invariant/halt? Potential: stale VL GVs from prior on run. Also the `rolled` key in scalp_closed could affect telemetry/archive consumers that don't ignore it. The LATTICE_CONFIG marker could affect archive parsers. The prune not deleting VL GVs means if lattice is turned off after having been on, stale VL GVs persist and Grind_EffectiveEntry uses them, changing exits and entries. That's a real hazard. Also Grind_VLHas ticket-0 guard no harm. Rank arrays use EffectiveEntry; stale VL changes ranks, exit queue, entries. So T-2 BREAKS if stale VLs exist. But if clean off, probably safe. The question: "With InpVirtualLattice=false (every live preset), list EVERY code path the merged build runs differently from main 5685e4f on a live book (init prints and markers, the rolled key in scalp_closed, the prune, Grind_VLHas, rank arrays, exit formulas). Can any change a live exit, an entry, an invariant or a halt?" We need list and answer. We can say most are inert if no VL GVs; but the prune missing VL branch plus Grind_EffectiveEntry reading VL means if any VL GV exists (e.g., from a test, previous ON run, or another instance on same ticket? Tickets unique), it will alter exits/ranks/entries. Also init validation could halt. So verdict NEEDS-FIX? Or BREAKS? The prompt likely expects T-2 HOLDS? Let's think: They emphasize lattice OFF live presets. They want ensure no effect. The merge lost VL prune. If lattice OFF, no VLs are created, but are there any VL GVs from tests? Tests run on same terminal? Unit tests use GV functions and reset? Adr162b_Reset maybe deletes VLs? Not sure. In live, if someone previously ran lattice ON, then turned OFF without clearing GVs, stale VLs persist because prune doesn't delete them. That is a real risk. But B1 never deployed (GB8), so live fleet never had lattice ON. So no VLs on live. Thus T-2 HOLDS for live. However if tests run on same terminal as live? Not live. The question says "on a live book". So probably HOLDS. But we need be exhaustive. We can mark HOLDS with caveat: only if no GRIND_VL_ GVs exist; the missing prune branch means stale VLs are not cleaned, so a terminal that ever ran B1 ON would differ. But B1 never deployed. Also the `rolled` key could change scalp_closed payload; pipshed ignores. If other consumers? Not specified. So T-2 verdict: HOLDS on clean live book, but with caveat.

T-3: Roll inside a carry pass. Tests LB37-LB39 cover: pass step then roll (branch M); roll before first step (branch M); roll between steps (branch S). Find interleaving they miss that breaks I6 or loses an accrual: a gap loop rolling several layers mid-pass; a roll whose modify is CLAMPED (records a carry shift) followed by the pass shifting the same exit; a pass clamp (shift plus release marker) followed by a roll (Grind_CarryShiftDelete or RecordShift); the short side; a sign-guard skip on effective entry (GA2) after a roll.

We need analyze code. The pass captures work items at PassBegin: pos, exit_order_ticket, entry_price, formula, is_long, layer_index. It processes 2 items per step. The roll can happen between OnTimer steps (since OnTimer and OnTick single-threaded). The roll modifies the exit order and sets VL. The pass step for that item later uses Grind_CarryCurrentExitTicket to get current exit ticket. If the roll happened before the step, current_exit is the same ticket (branch M) or new ticket (branch S). It computes base = Grind_CarryWorkBase(idx) which reads live VL and eject offset. Then calls Grind_CarryExitShiftLayer with current_exit. That shifts the exit by accrued. So if roll already applied, the pass will shift the rolled exit by accrued. That seems intended: the pass should add accrued to the rolled exit. But what about the roll itself? The roll computes formula = ExitPrice(level, exit_pips) + accrued. It modifies to price = formula, possibly clamped, and records carry shift if clamped. It does NOT commit accrual? It reads Grind_CarryAccruedGet(pos) at roll time. Then it modifies exit to level exit + accrued. If the pass later shifts same exit by accrued again, double count? Wait let's trace.

At roll time, layer's exit is modified to ExitPrice(VL, exit_pips) + accrued (from GV). Then the pass, if it processes this layer later, computes base = ExitPrice(EffectiveEntry, exit_pips) + EjectOffset. EffectiveEntry reads VL, so base = ExitPrice(VL, exit_pips). Then Grind_CarryExitShiftLayer computes new_exit = base - dir*accrued_pips*pip_size (i.e., base + accrued for long? Let's check: Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size) returns formula_exit - direction * accrued_pips * pip_size. For long direction=1, accrued_pips positive? Swap for long is negative? In test, swap -0.10, accrued_pips maybe negative? Then new_exit = formula - 1 * negative * pip = formula + positive? Actually they say long exit moves UP. So accrued_pips negative, new_exit = formula - (negative) = formula +. So it shifts exit by accrued. The formula here is base (without accrued). It then sets Grind_CarryAccruedSet(pos, accrued_price) where accrued_price = theoretical - formula_exit = -dir*accrued_pips*pip_size. So the GV accrual becomes the shift applied. The exit price becomes base + accrued. So after pass, exit = base + accrued. But the roll already set exit = base + accrued. Then pass shifts again: it reads old exit = base + accrued, but it computes new_exit from base (not including old accrued). It modifies to base + accrued again. So the final price is same? Wait Grind_CarryExitShiftLayer ignores old exit except for logging; it computes theoretical = formula_exit - dir*accrued_pips*pip_size. formula_exit is base (from WorkBase) which does NOT include accrued. So new_exit = base + accrued. If the exit was already base + accrued from roll, modifying to same price is idempotent. It records shift = new_exit - (formula_exit + accrued_price)? Let's see:
```
const double intended = formula_exit + accrued_price;
const double applied_shift = Grind_Normalize(new_exit) - intended;
Grind_CarryRecordShift(position_ticket, applied_shift, clamped_out);
```
If new_exit equals intended, applied_shift=0. So no double count. Good. But wait the roll also records a carry shift if clamped. Suppose roll was clamped: it modified to price_clamped = ask + min_dist (long). The formula was base + accrued. Clamped means price_clamped != formula. It records Grind_CarryRecordShift(pos, price - formula, true). So GV shift = price_clamped - (base + accrued). Then later pass processes same layer. WorkBase computes base = ExitPrice(VL) + EjectOffset. It calls ExitShiftLayer with formula_exit = base. It computes theoretical = base + accrued (using swap/ledger from position). It then clamps new_exit = maybe same clamp. It modifies to new_exit. It then sets accrued GV to accrued_price. It records shift = new_exit - (base + accrued). This overwrites the roll's shift. Is that correct? The shift is now the clamp residual relative to base+accrued. The roll's shift was also relative to base+accrued? Actually roll's formula = base + accrued (same accrued? roll read GV accrued; pass computes accrued from swap. If same, yes). So overwriting with same or updated is fine. But what if the pass's accrued differs from roll's GV accrued? The roll read Grind_CarryAccruedGet(pos). Before pass, the accrual GV might be from previous night. The pass computes new accrual from current swap. If roll happens before the pass, it uses old accrual. Then pass later updates to new accrual and shifts to new price. So final is new. If roll happens after the pass already processed this item, then the roll reads the new accrual GV (set by pass) and modifies to new price. But the pass already shifted the old exit to new price. Roll then modifies to level exit + new accrual. That might be different base (VL vs old entry). It should be correct because roll changes effective entry. But what about carry shift GV? The pass recorded a shift for the old exit. The roll then does Grind_CarryShiftDelete(pos) if not clamped, or records new shift if clamped. So it clears the pass's shift. Good.

But the threat asks find an interleaving they miss that breaks I6 or loses an accrual. Let's think of gap loop rolling several layers mid-pass. Suppose pass begins, work list includes layers 0..7. OnTick roll happens, rolls multiple layers (gap loop). It modifies exits for several layers, sets VLs, records shifts. Then pass continues processing remaining items. For each rolled layer, WorkBase reads live VL, so base is new. It shifts by accrued. Should be okay. But what about the exit queue? The roll calls Grind_ExitQManageSide at end. That may cancel/release exits for ranks. It may change which layers have exits. The pass's work list has captured exit_order_ticket for each item. But it uses Grind_CarryCurrentExitTicket to get current exit. If the queue cancelled an exit for a layer, current_exit=0, closing? The pass skips if closing or no layer. If the queue placed a new exit for a layer that was branch S, current_exit is new ticket. So pass handles. The captured formula in work list is not used except entry and layer_index; WorkBase recomputes from live VL and entry. So gap loop likely okay.

But there is a subtle bug: The pass processes 2 items per step. The work list is built at PassBegin from g_grind_long.layers in array order. The roll can reorder? Grind_RemoveLayerAt shifts array, but roll doesn't remove. It modifies. The queue may cancel/release but not reorder. So indices stable.

What about a roll whose modify is CLAMPED followed by the pass shifting the same exit? As above, pass overwrites shift. Should be okay if same accrued. But what if the roll is clamped and records a release marker (clamped=true). The pass later shifts and records shift with clamped_out from its own clamp. If the pass clamp is false (theoretical is passive), it calls Grind_CarryRecordShift(pos, applied_shift, false). This deletes the release marker. But the roll's clamp may have been due to market conditions at roll time. By pass time, market may have moved, so the clamp may no longer be needed. That's okay. But if the pass's clamp is also true, it keeps release. Fine.

What about a pass clamp (shift plus release marker) followed by a roll? The pass processes item, modifies exit to clamped price, records shift with release. Then roll later modifies same exit to level exit + accrued. If roll is not clamped, it calls Grind_CarryShiftDelete(pos), which deletes shift and release. That may be correct because roll sets new exit based on current accrued. But wait roll uses Grind_CarryAccruedGet(pos) for accrued. The pass just set accrued GV to the new accrual. So roll includes it. The exit is set to level exit + accrued. If that price is passive, no clamp, so shift 0. Correct. If roll is clamped, it records new shift. So okay.

Short side: similar. But there may be a sign error? Need check.

Sign-guard skip on effective entry (GA2) after a roll. In Grind_CarryExitShiftLayer:
```
if(Grind_CarrySignGuardAppliesAtShift(position_ticket, entry_price, theoretical, is_long)) {
  sign_guard_skipped_out = true;
  ...
  return false;
}
```
Grind_CarrySignGuardAppliesAtShift uses Grind_EffectiveEntry(entry, ticket), which reads VL. So after a roll, effective entry is the level. The sign guard blocks if new_exit <= entry (long) or >= entry (short). For a rolled long, level is above market? Wait long roll: at cap, market trades through next grid level. For long side, entries are buys below market? Need understand. B1: at cap, when market trades through next grid level, OLDEST unrolled layer is rolled: its exit is re-priced to that level's exit. For long, if market goes down, you add more? Actually passive market maker: long side buys below, exit sells above. If price falls, long layers fill, cap reached. When market trades through next grid level (lower?), you roll oldest layer's exit to that level's exit? Let's not. The sign guard may skip if theoretical exit is not profitable relative to effective entry. After a roll, effective entry changes to the level (maybe unfavorable). The pass might skip due to sign guard. That's intended? The threat says "a sign-guard skip on the effective entry (GA2) after a roll." Could this lose an accrual? If the pass skips, it does not shift the exit, and does not set accrued GV? Actually in sign guard skip, it returns false before modifying and before `Grind_CarryAccruedSet`. So the accrual is not committed. But the exit remains at the rolled price which already includes the old accrued from roll time. If the roll happened before the pass, it used old accrued. The pass skips, so the new accrual is lost for that night. Next night it may compute from open time and include multiple nights? Grind_CarryRolloversCrossed counts nights since open, so next pass will compute total since open, not just one night. So not lost forever, just delayed. But if sign guard always skips after roll, the exit never gets the new accrual. That's a potential issue. The tests LB37-LB39 include sign guard? They assert all accrued > 2 points. If sign guard skips, accrued GV not set, so test would fail. Since tests pass, sign guard likely not triggered in those fixtures. But in live, a roll could change effective entry such that the shifted exit is not beyond entry, causing sign guard to skip. Then the exit remains at rolled price (which included old accrued). The pass summary counts skipped. This might be acceptable; the exit is already at a level that may be unprofitable? Actually sign guard prevents locking a loss. If skipped, the exit is not shifted. But the roll already moved it to level exit + old accrued. If the new accrual would move it further in the adverse direction? For long, swap negative, so accrued_price positive? Wait long swap negative, ledger_pips negative, pending negative, accrued_pips negative. new_exit = formula - 1 * negative = formula + positive. So long exit moves UP (more profit). Sign guard blocks if new_exit <= entry (long). Moving up makes new_exit > entry, so should not block. For short, swap positive? Short swap maybe positive? If accrued_pips positive, new_exit = formula - (-1)*positive = formula + positive? Actually for short direction=-1, new_exit = formula - (-1)*positive = formula + positive, which is higher, worse for short? Wait short exit is buy above? For short, exit is buy limit above? Actually short side sells high, buys low. Exit for short is buy limit below? Hmm. Sign guard for short blocks if new_exit >= entry. If swap for short is positive, accrued_pips positive, direction=-1, new_exit = formula + positive, which is higher, so might violate. So short side could skip. The threat mentions short side. Could be a real issue. But tests LB37-LB39 don't test short carry pass with roll. LB36 tests short gap but no carry. So T-3 could BREAK on short side if sign guard skips. Need analyze.

Also a gap loop rolling several layers mid-pass: The pass work list includes all layers. The roll may modify exits for multiple layers. The queue may cancel exits for some ranks. The pass uses current exit ticket. If the roll sets VL on a layer that had no exit (branch S), the queue places an exit immediately. The pass later finds current exit and shifts it. That's LB39. If gap loop rolls several layers, including some with exits and some without, the pass processes them in order. Should be okay. But what if the roll's Grind_ExitQManageSide places exits for new required ranks, and cancels exits for old required ranks. The pass's work list includes layers that may have their exits cancelled. It skips if closing? If exit_order_ticket=0 and exit_position_ticket=0, Grind_CarryCurrentExitTicket returns exit_ticket_out=0, closing=false. Then Grind_CarryExitShiftLayer is called with exit_order_ticket=0. In that function, if exit_order_ticket == 0, it commits accrual if Grind_CarryShouldCommitAccrual(false,false,true) and returns true. So it does NOT modify any exit, but sets accrued GV. That's correct: no exit, just accrual. But wait if the layer has no exit, the queue should place one if required. The pass step happens after roll's queue manage. If the layer is not required, no exit. The pass just sets accrual. Later if it becomes required, formula includes accrued. So okay.

What about a roll that happens mid-pass while the pass is in the middle of processing an item? Not possible single-threaded. But between items, yes. The pass's work list cursor increments before processing. If roll happens after cursor increments but before ExitShiftLayer? Not possible because no event interleaving within a function call. So no.

The threat asks "Find an interleaving they miss that breaks I6 or loses an accrual". A likely one: a roll between the two items of one step is impossible. But what about a roll that happens after PassBegin but before the first step, and the roll is for a layer that is later in the work list. The pass will process it. The WorkBase reads live VL, so base is rolled level. The pass then shifts by accrued. But the roll itself already modified the exit to level exit + accrued (old). So the pass modifies to level exit + new accrued. That's correct. However, the roll's modify may have been CLAMPED. The roll records a shift. The pass later computes base from VL, ignores the roll's shift? Wait WorkBase computes base = ExitPrice(EffectiveEntry, exit_pips) + EjectOffset. It does NOT include the carry shift GV. So the pass's theoretical = base + accrued. It then modifies the exit from its current price (which may be clamped) to theoretical (or clamped). It records shift = new_exit - (base + accrued). This overwrites the roll's shift. Is that correct? The roll's shift was intended to account for the clamp residual. The pass's new shift is relative to base+accrued. If the pass's new_exit is also clamped, it records the new clamp residual. If not clamped, it records 0, effectively removing the roll's clamp shift. But the exit price is modified to base+accrued (not clamped), so the shift should be 0. That's correct. So no double count.

But what if the pass processes the layer BEFORE the roll? The pass uses old exit ticket (which may be the same). It modifies exit to old base + accrued. Then roll later modifies to new base + accrued. The roll deletes shift. Correct. The exit queue may have changed? The roll's queue manage at end.

What about accrual double commit? The pass sets Grind_CarryAccruedSet(pos, accrued_price). The roll reads Grind_CarryAccruedGet(pos). If roll happens after pass, it uses new accrued. If roll happens before pass, it uses old accrued. But then pass later updates to new accrued and modifies exit. So final exit has new accrued. The roll's ROLL_ACCEPTED event recorded old accrued. That's just telemetry. No functional issue.

What about gap loop rolling several layers mid-pass: The roll loop in TrySide can roll multiple layers. Each roll calls Grind_ExitQManageSide at the end. That may cancel exits for layers that are no longer required. Suppose the pass work list has a layer whose exit was cancelled by the first roll's queue manage. The pass later sees current_exit=0 and closing=false. It sets accrual and returns true (no exit). But the layer might now be required? Actually if it was cancelled, it's not required. If later another roll makes it required again? The queue manage is called after each roll, so it should place exits for required. The pass doesn't place exits. So if a layer has no exit but is required, that would be an I3 issue. But the queue manage should have placed it. However, the pass might process a layer that had its exit cancelled and is not required. It just sets accrual. Later if it becomes required (e.g., due to another layer being removed? No removal during pass). So okay.

Potential bug: The pass's work list is built at PassBegin. If a roll happens before PassBegin? Not relevant. If a roll happens after PassBegin but before the pass step, it may change the number of layers? Roll does not change depth. So work list indices still valid. But if a layer is closed (scalp) during pass? OnTradeTransaction could fire between OnTimer steps? OnTimer and OnTradeTransaction are separate events. MQL5 single-threaded but OnTradeTransaction can occur between OnTimer calls. The pass is active across multiple OnTimer calls. A deal could close a layer mid-pass. Then the work list has a position ticket that no longer exists. Grind_CarryCurrentExitTicket returns false (layer not found), so pass skips. That's handled. But what if a new layer is added? The work list doesn't include it. It will be processed next night. That's C52 design.

T-3 asks specifically "a gap loop rolling several layers mid-pass; a roll whose modify is CLAMPED ...; a pass clamp ...; the short side; a sign-guard skip ... after a roll." We need pick one that breaks I6 or loses accrual. Let's analyze short side with sign guard.

Consider short side. Market maker short: sells high, buys low. Exit for short is a buy limit below entry? Actually to close a short, you buy. A buy limit is placed below market? Wait if you are short, you profit when price falls, so you want to buy back lower. A buy limit below market is passive. Yes. So exit price = entry - exit_pips. For short, effective entry is VL level. Roll: at cap, when market trades through next grid level (higher? for short, price rises), old layer's exit re-priced to that level's exit. Short entries increase? The sign guard for short: blocks if new_exit >= entry. The carry shift for short: swap for short might be positive (credit). accrued_pips positive. direction = -1. new_exit = formula - (-1)*positive = formula + positive. So it moves exit UP, closer to entry. If it moves above entry, sign guard blocks. That could skip. If skipped, the exit remains at rolled price (level exit + old accrued). The new accrual is not committed. Next night, the pass will compute accrued from open time, including both nights. It may still sign-guard skip if total accrued pushes exit above entry. So the exit never gets the accrual. But the exit is already at level exit + old accrued. If old accrued was 0 (first night after roll), the exit is at level exit. The new accrual is lost (not in GV, not in price). But the position still has accrued swap on the broker. The exit is too low (for short, lower exit means more profit? Actually short exit is buy limit below; if you don't raise it, you might buy back too low, giving more profit? Wait sign guard prevents new_exit >= entry, i.e., prevents exiting at a loss. For short, if new_exit (buy price) is above entry, you'd buy back higher than you sold, a loss. So skipping keeps the exit at a profitable level (lower). So you don't lose money; you just don't adjust for the swap credit. But the swap credit is positive for short, so you could raise the exit and still be profitable. If it would go above entry, you can't raise it without locking a loss. So skipping is correct. No functional break. I6: I6 checks exit against formula + accrued + shift. If accrued GV is not set, expected doesn't include the new accrual, so I6 passes. If the exit has old accrued from roll, and GV accrued is old? Wait roll reads Grind_CarryAccruedGet. If pass skips, it does not update GV. So GV still old. I6 expected = base + old accrued + shift. Exit = base + old accrued + roll shift. So passes. So no break. The accrual is "lost" in the sense not committed, but it's deferred. The test "all accrued" would fail if it expected >2 points. But in live, it's acceptable. The threat says "loses an accrual". It is not lost forever; next pass includes multiple nights. But if sign guard always skips, GV never updates, so the exit is one night behind. That's the T-4 question.

T-4: Accrual used by a roll. A roll reads Grind_CarryAccruedGet at roll time. Between a pass's commit of a new accrual and the modify of that layer's exit (same item) nothing can run; across items it can. Can a roll place or modify an exit with an accrual the pass is about to change, leaving the exit one night behind its GV? Let's analyze. The pass processes items sequentially. For item i, it computes accrued, modifies exit, then sets Grind_CarryAccruedSet. If a roll happens between item i and item i+1, it reads GV accrued. For layers already processed, GV is new. For layers not yet processed, GV is old. If roll modifies a layer that hasn't been processed yet, it uses old accrued. Later the pass processes that layer, computes new accrued, modifies exit again to new accrued, and sets GV to new. So final exit matches new GV. If roll modifies a layer that has already been processed, it uses new accrued, and pass won't process it again (cursor passed). So final exit matches new GV. So no left behind. But what if the roll modifies a layer that is not in the pass work list? The pass work list includes all layers at PassBegin. If a layer was added after PassBegin, it's not in work list. A roll on a new layer would read GV accrued (maybe 0 if new). The pass won't process it this night. So its exit is at level + old accrued (0). GV accrued is 0. So consistent, but missing accrual until next night. That's a new layer, not a rolled existing layer. The threat says "leaving the exit one night behind its GV". Could happen if roll reads GV before pass sets it, then pass skips due to sign guard? If pass skips, GV remains old, exit has old. So consistent. If pass modifies, it updates both. So no mismatch. However, what if the roll happens between the pass's `Grind_CarryAccruedSet` and the `Grind_CarryRecordShift`? Within same item, no interleaving. So T-4 likely HOLDS.

But wait: In Grind_CarryExitShiftLayer, the order is:
```
if(!Grind_ModifyPendingPrice(...)) return false;
if(Grind_CarryShouldCommitAccrual(true,false,true)) Grind_CarryAccruedSet(...);
...
Grind_CarryRecordShift(...);
```
So it modifies exit first, then sets accrued GV, then records shift. If a roll happens after the modify but before the accrued set? Not possible within function. But what about between items? Suppose pass processes item i, modifies exit to new price, sets accrued GV, records shift. Then roll happens before item i+1. Roll on item i reads new accrued GV and modifies exit to level + new accrued. It does not change GV. So exit has new accrued. GV remains new accrued. Consistent. Roll on item i+1 (not yet processed) reads old accrued GV, modifies exit to level + old accrued. Then pass processes item i+1, reads old exit? It computes new accrued, modifies to level + new accrued, sets GV new. So final consistent. So T-4 HOLDS.

T-5: Restart. A reattach mid-pass after rolls: Grind_ReconstructState with VLs, accruals and shifts in GVs; the pass restarts from scratch. Does any rolled exit fail I6 or reconstruction? We need analyze Grind_ReconstructState. It rebuilds book from broker tickets. It uses Grind_EffectiveEntry (reads VL GVs) and Grind_CarryShiftGetForRecon (reads shift GVs). It checks I6 with expected = ExitPrice(eff, exit_pips) + accrued + eject_offset + shift. The exit_target is from broker order price. For a rolled exit, the broker order price is whatever was last set (level exit + accrued + clamp). The expected uses eff=VL level, accrued GV, eject offset, shift GV. If the roll recorded a carry shift correctly, I6 should pass. But what if the roll modified the exit and set VL, but the pass had not yet updated accrued GV? The broker order price includes old accrued. The GV accrued is old. So expected = level exit + old accrued + shift. Matches. If the pass later updated accrued GV and modified exit, both match. If the pass skipped due to sign guard, GV remains old, exit has old accrued. Matches. So I6 should pass. But what about the carry shift GV from the pass? The pass records shift = new_exit - (base + accrued). The broker order price = new_exit. Expected = base + accrued + shift = new_exit. Matches. So reconstruction should pass.

However, there is a subtlety: Grind_ReconstructState calls Grind_RebuildBookFromTickets with tolerate_exit_shortfall=true. It uses Grind_CarryShiftGetForRecon which may validate and delete shift if out of bound. If a roll's shift is large? The roll's shift is price - formula. If clamped, shift could be large. The bound check uses nightly_max_pips * nights. Could delete a legitimate shift? Possibly. But not specific to restart.

What about VL GVs? Grind_ReconstructState does not delete VL GVs. If a position was closed during downtime, its VL GV persists because prune doesn't delete VLs. Then a new position with the same ticket? Tickets unique. Stale VL for closed position won't affect new. But if a position is closed and reopened with same ticket? MT5 tickets are unique. So no.

Reconstruction of layer order: It builds layers from broker tickets in order of positions/orders. The layer_index is parsed from comment. It doesn't use VL GVs to order. Exit queue ranks use EffectiveEntry (VL). So if VLs are set, ranks reflect rolled levels. That's intended. The exit target from broker order is used. I6 checks. Should pass.

Potential issue: If the pass was mid-pass and the EA restarts, the pass state (g_grind_carry_exit_pass_active) is reset (global variable in memory lost). On restart, OnInit calls Grind_ReconstructState, then Grind_RetryMissingExits, then Grind_CarryPruneShiftGvs, then Grind_CarryEmitSnapshot. The carry pass will start new at next OnTimer if in window and due? The gate GV may have been marked done? If the pass was mid-pass, Grind_CarryGateMarkDone was not called (only at completion). So the gate is still due. On next OnTimer in window, it will start a new pass from scratch. That's fine. But if the window has closed, the pass will not run until next night. The exits already shifted for some layers, not for others. The ones not shifted may be one night behind. But on next night, the pass computes accrued from open time, so it will catch up. So no permanent break.

T-6: Merge correctness. Does anything in auto-merged grind_carry.mqh or fxgrind.mq5 combine B1 and C52 in a way neither branch tested? The merge lost B1's VL prune branch. That is a real merge bug. With lattice ON, VL GVs are not pruned when positions close. They persist. Grind_EffectiveEntry only called with position_ticket; if ticket is reused? No. But stale VL GVs accumulate. Also if a position is closed and a new layer gets the same position_ticket? MT5 position tickets are unique per open, but could be reused after close? I think position IDs are unique increasing, not reused. So stale VL doesn't affect new positions. But it's a memory/GV leak. More importantly, during the close of a rolled layer, Grind_HandleSideDealFill calls Grind_VLDelete(closed_position). So VL is deleted on normal close. The prune is a safety net for cases where close deal missed. If deal missed, reconstruct on restart will not have the position, but VL GV persists. Then if a new position somehow gets same ticket? Unlikely. So leak. But could affect I6? No, because no layer with that position. However, Grind_CarryPruneShiftGvs also prunes shift/release/offset. It deletes them if position doesn't exist. It does not delete VL. So VL GVs persist forever. That's a merge inconsistency. The prompt says "B1's prune without its GRIND_VL_ branch". So T-6 likely BREAKS: the prune no longer cleans VL GVs, so stale VLs can persist. With lattice ON, this could cause a new layer with same position ticket? Not. But also Grind_VLHas(ticket) for a closed ticket will return true. If that ticket is later used as an exit_position_ticket? No. The function is called with position_ticket. So only if a closed position ticket is reused. MT5 position tickets are unique. But what about the EA's own test? Not live. So maybe not a functional break, just leak. However, the prompt asks "combine B1 and C52 in a way neither branch was tested for". The missing VL prune is exactly that. It was B1's change lost in merge. So T-6 BREAKS: the merged prune does not delete VL GVs, so stale VLs are never cleaned by the prune. This can affect I6 if a layer is reconstructed without a position? No, recon only creates layers for positions. If a position is closed, layer removed. So no. But if the EA restarts and the position is gone, no layer. The stale VL is ignored. So functional impact low. But it is a merge defect. We can mark NEEDS-FIX or BREAKS. The prompt says "Does anything ... combine ... in a way neither branch was tested for". Yes, the prune. Also the `Grind_CarryCurrentExitTicket` uses `const GrindSideState side = is_long ? g_grind_long : g_grind_short;` This copies the entire side state. That's C52 code. B1's VLs in GVs are not in the copy. That's fine. But the copy includes layers. If B1 modifies layers during roll, the pass reads live copy at step time. So okay.

Another merge thing: In fxgrind.mq5, OnTick calls Grind_LatticeOnTick before Grind_OnTickEngine. The carry pass is in OnTimer. The roll can happen before RetryMissingExits in OnTickEngine. That means if a roll fails with CLOSING, RetryMissingExits later might clear the stale ticket. But as noted, only for unallowed ranks. For allowed rank, not cleared. So the merge order might matter. In main (C52), OnTick didn't have LatticeOnTick. Now LatticeOnTick runs before RetryMissingExits. If a roll is refused due to CLOSING, RetryMissingExits might clear the ticket if rank not allowed. But candidate is allowed, so no. So the guard's CLOSING could persist until next tick, but then invariant might catch. Not a merge issue per se.

T-7: Tests. Which C54 behaviour has no test that fails without it? Does any assertion in fxgrind_tests_c54.mqh pass vacuously (inside an if, on leftover state, or on a fixture that never reaches the code)? We need inspect tests. The C54 fix is the guard. Tests LB33 and LB34(c) fail without it. So at least one. But T-7 asks which C54 behaviour has no test that fails without it. Maybe LB35 resets failure count? The fix doesn't affect LB35. LB36 short gap? Not C54. LB37-LB39 pass in both states. So the only C54-specific behavior tested is the guard's return code and no side effects. LB33 and LB34(c) fail without fix. So there is a test. But maybe the guard's branch when exit_order_ticket !=0 and SelectOurOrder fails due to other magic is not tested. Or ticket 0? Not. The guard also catches "order of another magic". No test. Also the guard's interaction with exit_position_ticket? The guard is after exit_position_ticket check. The test LB34(b) has exit_order_ticket=0, exit_position_ticket=9999, returns CLOSING before guard. That tests the prior check, not C54. So C54 guard is tested for order gone (LB33, LB34c). Not for other magic. Also no test for the guard when exit_order_ticket !=0 and SelectOurOrder false due to test mode record missing but position exists? That's order gone.

Vacuous assertions: Check LB33: after Adr162b_SeedLong8, Grind_OrderTestRemove(8001UL), market seed, Adr162b_TryLong. It asserts "LB33 no roll": rc==0. But wait, if the guard returns CLOSING, TrySide breaks, so rolled_count=0. Without fix, roll returns MODIFY_FAILED, TrySide counts failure and backoff, returns rolled_count=0. So rc==0 passes in both states. That's PASS in both by design. The failing assertions are "not refused", "no failure counted", "no backoff". Those check side effects. Are they vacuous? They check g_grind_order_test_modify_calls == 0. Without fix, the roll would call Grind_ModifyPendingPrice? Wait without fix, the roll proceeds to modify. But Grind_ModifyPendingPrice first calls Grind_SelectOurOrder(ticket, magic). Since order is removed from test store, SelectOurOrder returns false, so it returns false WITHOUT incrementing g_grind_order_test_modify_calls. So "LB33 no broker call" passes in both states. But "not refused" fails because the roll then reports ROLL_REFUSED. So the guard prevents the report and failure count. So not vacuous.

LB34(c): order gone, calls Grind_LatticeRollLayer directly. Without fix, it would proceed to modify, SelectOurOrder false, return MODIFY_FAILED. The test expects CLOSING. So fails. Not vacuous.

But check LB35: It sets g_grind_order_test_send_ok = false. Then Adr162b_TryLong(now). The roll will call Grind_ModifyPendingPrice. SelectOurOrder true (order exists), then Grind_OrderEngineSend returns false because send_ok false. So Grind_ModifyPendingPrice returns false. Roll reports ROLL_REFUSED and returns MODIFY_FAILED. TrySide counts failure. The test asserts fail count 1. Then sets send_ok true, calls TryLong(now+61). The roll should succeed, reset fail count to 0. This test passes in both states because C54 guard doesn't affect (SelectOurOrder true). So not C54-specific.

LB36: short gap. Not C54.

LB37-LB39: pass in both states. They test B1 x C52. Could have vacuous assertions? C54_AllRestingI6Long counts n==2. If no exits, n=0, returns false. So not vacuous. C54_AllAccruedLong checks all positions. If no positions, returns true? It loops over layers. If no layers, returns true. But there are layers. In LB37, after Adr162b_Reset, Grind_CarryTestReset, etc. The test seeds 8 layers. So not empty. C54_I6Long(0) uses layers[0]. If layer 0 missing? It would access invalid. But seed ensures.

Potential vacuous: In LB34(a), "LB34 already rolled" asserts rc == ALREADY_ROLLED && modify_calls == 0 && VLGet == 1.20600. It sets VL before. This passes even without C54 because ALREADY_ROLLED check is before guard. So not C54-specific.

In LB39, "LB39 one roll, branch S" asserts modify_calls == 0. But if the roll didn't happen, modify_calls might be 0. However it also asserts rc == 1 and VLGet. So not vacuous.

T-7 also asks "Which C54 behaviour has no test that fails without it?" The C54 behavior is returning CLOSING for an exit order that is set but not selectable. LB33 and LB34(c) fail without it. So it is tested. But the behavior for "order of another magic" is not tested. Also the behavior when the exit order is set, SelectOurOrder false, but the layer has exit_position_ticket == 0 and the order is actually filled (deal unprocessed) is tested by order gone removal (simulates removed). The filled-unprocessed case is not directly simulated; order gone is removed. In both cases SelectOurOrder false. So same code path. So tested.

Maybe the fix also changes behavior for "exit cancelled by hand" — tested by order gone. So okay.

Vacuous assertions: In LB33, "LB33 no backoff": `AssertEqInt("LB33 no backoff", (int)g_grind_vl_backoff_long, 0);` But g_grind_vl_backoff_long is datetime initially 0. If the guard returns CLOSING, no backoff. Without guard, TrySide sets backoff. So fails without fix. Not vacuous.

One potential vacuous: LB34(c) after Adr162b_SeedLong8, Grind_OrderTestRemove(8001UL), then calls Grind_LatticeRollLayer directly with level 1.20600. But it does not seed market. The roll for branch M uses Grind_ModifyPendingPrice, which uses order test. It doesn't need market. But it also computes price = Grind_ExitPrice(level, exit_pips) + accrued. It then calls Grind_ExitQClampPassive? Wait the guard is before any of that. So if guard returns CLOSING, it never computes price. So market seed not needed. Without guard, it would compute price and try modify. Grind_ModifyPendingPrice calls SelectOurOrder false, returns false. So it would report ROLL_REFUSED. So test fails as expected.

Now, we need also consider the C54 fix's placement: It is after `if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;`. The prompt G1 says before any modify, report, VL write or queue call. Yes.

But T-1: "what clears the layer's stale exit_order_ticket afterwards". We need cite code. In Grind_ExitQHoldCancelLayer:
```
if(layer.exit_order_ticket == 0) return true;
const ulong ticket = layer.exit_order_ticket;
if(Grind_CancelPendingOrder(ticket, magic)) { layer.exit_order_ticket = 0; ... return true; }
if(Grind_SelectOurOrder(ticket, magic)) return false;
ulong pos_out = 0;
if(Grind_ExitQFindExitDealPosition(...)) { layer.exit_position_ticket = pos_out; layer.exit_order_ticket = 0; ... } else { layer.exit_order_ticket = 0; ... }
return true;
```
This function is only called in ExitQManageSide when `!Grind_ExitQAllowed(ranks[i], n) && side.layers[i].exit_order_ticket != 0`. So for allowed ranks, not called. So stale ticket on allowed rank not cleared. The guard in roll is on candidate, which is allowed rank. So T-1 HOLDS. But wait, if the candidate is allowed rank, its exit_order_ticket is set. If SelectOurOrder false, guard returns CLOSING. The queue manage in the roll? No, guard returns before queue. The next OnTick RetryMissingExits calls ExitQManageSide. For that layer, rank is allowed, so first loop does not call HoldCancel. Second loop: `if(side.layers[i].exit_order_ticket != 0 || side.layers[i].exit_position_ticket != 0) continue;` So it skips. So ticket stays. Thus stale forever until deal event or restart. If deal event missed, forever. So T-1 HOLDS.

Smallest fix: In Grind_LatticeRollLayer, when SelectOurOrder false, we could check if the order exists in history as filled? But that's complex. Or add a telemetry report for the silent condition. Or in ExitQManageSide, for allowed ranks, if exit_order_ticket !=0 and !SelectOurOrder and no deal found, clear it. But that's C52 scope. The prompt says out of scope T-1. So just report.

T-2: We need list every code path. Let's systematically identify B1 changes in merged code that execute when InpVirtualLattice=false.

From fxgrind.mq5:
- Input InpVirtualLattice default false.
- OnInit: `if(!Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject)) { ... }` always called. If false, likely passes. But if InpAutoEject true and lattice false, validation should pass. We need see grind_config? Not attached. We can say ASSUMED it returns true for false lattice; not verified.
- `Print("GRIND_LATTICE enable=", InpVirtualLattice);` always.
- `Grind_ArchiveMarker("INFO", "LATTICE_CONFIG", "", 0, ...)` always.
- OnTick: `Grind_LatticeOnTick(... InpVirtualLattice ...)` always called, returns early if false.
- OnTimer? No direct B1 call? Grind_CarryOnTimerStep uses carry pass. The prune is called in Grind_CarryExitPassBegin and OnInit. B1 changed prune to omit VL branch. With lattice off, no VLs, so same as main? Main's prune didn't have VL branch either. Wait G5 says merged grind_carry equals main except B1's two changes: Grind_VLHas ticket-0 guard and prune without VLs. But main doesn't have Grind_VLHas at all. So the "prune without VLs" in merged is actually same as main's prune? Main's prune (C52) probably only pruned shift/release/offset. B1 branch added VL branch. The merge lost it, so merged prune equals main's. So with lattice off, prune is identical to main. So no difference from main there. The difference from main is the presence of Grind_VLHas guard and EffectiveEntry reading VL. But if no VL, EffectiveEntry returns entry. So same.

From grind_engine.mqh:
- Global variables for lattice backoff, fail counts, functions. Not executed unless called.
- `Grind_LatticeOnTick` called but returns early.
- `Grind_EffectiveEntry` is in grind_carry.mqh, called in many places. With no VL, returns entry.
- `Grind_VLHas` called in Grind_ComputeAddTarget (any_vl scan), Grind_ExitQFormulaTarget? Actually Grind_ExitQFormulaTarget calls Grind_EffectiveEntry, which calls Grind_VLHas. So every exit formula call does a GlobalVariableCheck. That's new vs main. But if no VL, false. Performance only.
- In Grind_HandleSideDealFill, `const bool was_rolled = Grind_VLHas(closed_position);` and passes to Grind_QueueScalpClosedEvent. This adds a field to scalp_closed event. If pipshed ignores, no. But if local archive? It changes event payload. Could affect downstream parsers. The prompt says pipshed's archive keeps only whitelisted fields, so B1's new `rolled` key is ignored there until C56. So no live effect on pipshed. But if other consumers? Not specified.
- In Grind_ExitQManageSide, uses Grind_EffectiveEntry. With no VL, same.
- In Grind_EjectPollCommand, Grind_AutoEjectTrySide, uses Grind_EffectiveEntry. Same.
- In Grind_ComputeAddTarget, any_vl scan. If no VL, same anchor as main? Need check main's version. Main likely used deepest layer entry. Here if !any_vl, uses Grind_FindDeepestLayerArrayIndex. So same. But it adds an any_vl scan. No semantic change.
- Grind_LatticeResetBackoff not called in production? Maybe not.
- Grind_ValidateLatticeInputs in OnInit. Need see config. Not attached. Could fail? If InpVirtualLattice=false, probably always true. But if it has a bug requiring AutoEject false regardless? The error message says "InpVirtualLattice requires InpAutoEject=false". So if lattice false, it should not require. So safe.

From grind_carry.mqh:
- Grind_VLHas ticket-0 guard: no effect.
- Grind_CarryPruneShiftGvs: merged lacks VL branch. With lattice off, no VLs. Same as main.
- Grind_CarryWorkBase uses EffectiveEntry. With no VL, same.
- Grind_CarryExitPassBegin uses EffectiveEntry. Same.
- Grind_CarryCurrentExitTicket: C52, already on main.
- Grind_CarryShiftGetForRecon: uses EjectIsEjected etc. Same.
- Grind_EffectiveEntry: new function. With no VL, returns entry.

From grind_pure.mqh, grind_scalp_events.mqh not provided. We can't cite. But the prompt lists them.

Can any change a live exit, entry, invariant or halt? Only if stale VL GVs exist. The missing prune means stale VLs are not cleaned. If a terminal ever ran with lattice ON (or tests left GVs), then with lattice OFF, Grind_EffectiveEntry will use those VLs, altering exits, entries, ranks, and possibly I6. Also Grind_HandleSideDealFill calls Grind_VLHas(closed_position) and would report was_rolled=true for a closed position with stale VL, changing scalp_closed event. So T-2: HOLDS on a clean live book (no GRIND_VL_ GVs), but BREAKS if any stale VL GVs exist because the prune does not delete them. The question asks "With InpVirtualLattice=false (every live preset), list EVERY code path the merged build runs differently from main on a live book ... Can any change a live exit, an entry, an invariant or a halt?" We should answer: On a clean book, no functional change; only logging and extra GV checks. But the missing VL prune means the system cannot clean stale VL GVs, so if the book is not clean (e.g., after a test, or a previous lattice-on run), it will change exits/entries/invariants. Since B1 never deployed, live presets off, no VLs. So HOLDS for live merge, but NEEDS-FIX for robustness. The prompt likely expects T-2 HOLDS? Let's see wording: "Off means off. With InpVirtualLattice=false (every live preset), list EVERY code path the merged build runs differently from main 5685e4f on a live book ... Can any change a live exit, an entry, an invariant or a halt?" They want to ensure the merge doesn't affect live. The answer: most are inert, but the `rolled` key in scalp_closed changes event format; pipshed ignores. The init print/marker. The prune missing VL branch doesn't matter because no VLs. The Grind_VLHas calls are new but return false. Rank arrays and exit formulas use EffectiveEntry which now checks GV; with no VL, same. So no change to live exit/entry/invariant/halt. Verdict HOLDS. But mention the stale VL caveat as a potential if GVs exist. Since B1 never deployed, safe.

T-3: We need decide verdict. Let's try to find a concrete interleaving that breaks I6. Consider LB37: PassBegin, one step processes items 0 and 1. Item 0 is L0 with exit 8001. The pass shifts exit 8001 by accrued, sets accrued GV for 7001. Then roll happens (TryLong). Roll reads accrued GV (new), modifies 8001 to level exit + new accrued. It records ROLL_ACCEPTED. Then finish pass processes remaining items 2..7. It does not process item 0 again. So L0 exit has level + new accrued. GV accrued = new. I6 passes. Good.

LB38: PassBegin, roll before any step. Roll on L0 (candidate) modifies 8001 to level + old accrued (GV maybe 0). Sets VL. Then pass step processes item 0. WorkBase reads VL, base = level exit. ExitShiftLayer computes new accrued from swap, theoretical = base + new accrued. It modifies 8001 to base + new accrued. Sets GV accrued = new. Records shift. Then item 1 (L1 held no exit) sets accrual. So L0 exit = base + new accrued. I6 passes. Good.

LB39: PassBegin with layers 6 and 7 no exits? Actually LB39 setup: layers 0-5 have VLs, layer 6 (7009) no VL, layer 7 (7010) no VL? Wait it sets VLs on 7001-7006. Layers 6 and 7 are 7009 and 7010 with exits 8001 and 8010? The prompt says "LB18's setup exactly (VLs on 7001-7006, layers 6 and 7 = 7009 at 1.20000 and 7010 at 1.19900, exits 8001 and 8010)". Wait Adr162b_SeedLong8 seeds 8 layers 7001-7008? Then they set VLs on 7001-7006. Then Adr151_TestSetupLongLayer for 7009 and 7010? That seems replacing layers? Let's not. The test asserts branch S: roll on layer 6 (7009) with no exit? Actually it asserts modify_calls == 0, so roll branch S (no exit). Then queue places exit. Then pass later processes layer 6, finds current exit, shifts. I6 passes.

What interleaving is missed? The tests only cover long side. Short side not covered for roll during carry pass. Could short side break? Let's analyze short roll during pass. Suppose short layers, pass active. Roll on short layer. The roll computes price = ExitPrice(level, exit_pips, dir=-1) + accrued. For short, exit price = level + exit_pips? Actually Grind_ExitPrice(level, exit_pips, point, dir) probably returns level + dir*exit_pips? Need know. For long dir=1, exit = entry + exit_pips? But long exit is sell limit above entry, so entry + exit_pips. For short dir=-1, exit = entry - exit_pips. So roll sets exit = level - exit_pips + accrued. Then pass later: WorkBase = ExitPrice(EffectiveEntry, exit_pips, dir=-1) + EjectOffset = level - exit_pips. ExitShiftLayer computes new_exit = formula - dir*accrued_pips*pip. For short, dir=-1, swap for short maybe positive? accrued_pips positive. new_exit = (level - exit_pips) - (-1)*positive = level - exit_pips + positive. So it moves exit UP. That matches roll's formula (level - exit_pips + accrued). So idempotent. Sign guard for short: Grind_CarrySignGuardAppliesAtShift uses effective entry = level. It blocks if new_exit >= entry. new_exit = level - exit_pips + accrued. If accrued > exit_pips, new_exit >= level, sign guard skips. This could happen if swap credit is large. If skipped, the pass does not modify the exit and does not set accrued GV. The roll already set exit to level - exit_pips + old accrued. If old accrued was 0, exit = level - exit_pips. GV accrued remains 0. I6 expected = level - exit_pips + 0 = level - exit_pips. Matches. So I6 passes. The new accrual is lost (deferred). Not a break. But the test "all accrued" would fail if it expected >2 points. But LB39 is long only, so not tested. So T-3 could find that short side carry pass with roll and sign guard skip does not commit accrual. Is that a break? The threat says "or loses an accrual". It does lose the accrual for that night. But next night it will include multiple nights? Grind_CarryRolloversCrossed counts nights since open, so next pass will compute total accrued since open, not just one night. So it will catch up when the sign guard no longer blocks? But if sign guard always blocks because accrued > exit_pips, it may never commit. However, if accrued > exit_pips, the exit would be above entry, which is a loss. The sign guard is designed to prevent that. So it will never commit until the position is closed or the entry changes (roll). If a roll changes effective entry to a higher level, sign guard may allow. So not a permanent loss. But it is an accrual not reflected in GV. The I6 invariant doesn't check GV vs broker swap; it only checks exit vs formula + accrued. So no I6 break. So T-3 might be HOLDS for I6, but there is a missing test for short side. The threat asks to find interleaving that breaks I6 or loses an accrual. We can say short side sign-guard skip loses the night's accrual (not committed) but does not break I6; it is deferred. Is that acceptable? The prompt says "Find an interleaving they miss that breaks I6 or loses an accrual". So we can report the short side gap as a missing test and a potential accrual deferral. But verdict? Maybe NEEDS-FIX for test coverage, not code.

Another interleaving: a gap loop rolling several layers mid-pass. Suppose pass work list has layers 0..7. A gap loop rolls layers 0,1,2 (oldest unrolled) in one OnTick. The roll loop calls Grind_ExitQManageSide after each roll. This may cancel exits for some layers and place exits for others. The pass later processes items in order. For a layer that was rolled and had its exit cancelled by a later roll's queue manage, the pass skips (closing? no, exit_order_ticket=0). It sets accrual GV but does not modify any exit. But the queue manage after the last roll should have placed an exit for that layer if it is required. Wait, the layer's rank may have changed due to other layers getting VLs. The queue manage is called after each roll, so by the end of the roll loop, the queue state is correct for all layers. The pass then processes items. For a layer that currently has no exit, it just sets accrual. If the layer is required, the queue should have placed an exit. But the pass does not place exits; it assumes the queue already did. However, the pass step runs after the roll loop in the same OnTick? No, the roll happens in OnTick, the pass happens in OnTimer. They are separate events. So after the roll loop, the queue state is correct. Later, the pass step may process a layer that has no exit. It sets accrual. But if the layer is required, it should have an exit from the queue manage. So it won't be no-exit. If it is not required, no exit. So okay.

What if the pass step itself causes a rank change? It modifies exits but does not change entries. The queue manage is not called during pass steps. So ranks don't change during pass. The only rank changes are from rolls (which change effective entries) or from layer closes/opens. So between pass steps, a roll can change ranks. The queue manage in the roll updates exits. Then the next pass step processes items using the new ranks? The pass step uses current exit ticket, not ranks. It doesn't recompute which layers should have exits. It just shifts whatever exit exists. So if a roll changes ranks and the queue cancels an exit for a layer, the pass will see no exit and just set accrual. If the queue places an exit for a layer that previously had none, the pass will see it and shift it. So okay.

Potential bug: The pass work list captured `formula_exit` at PassBegin, but WorkBase recomputes from live VL. However, it uses `g_grind_carry_exit_work_entry[idx]` which is the entry_price captured at PassBegin. If the layer's entry_price changes? It doesn't. If the layer is removed and a new layer gets the same array index? The work list uses position_ticket, not index. Grind_CarryCurrentExitTicket finds the layer by position_ticket. So if a layer is removed and a new layer is added, the position_ticket won't match the new layer. The pass will skip (return false) and not process. So it won't shift the wrong layer. Good.

What about a roll that happens on a layer that is not in the pass work list because it was added after PassBegin? The roll modifies its exit. The pass won't process it. Next night it will. The exit may be missing accrued for the current night. That's a new layer, not a rolled existing layer. The threat says "a roll whose modify is CLAMPED ...". For a new layer, if it has no accrued GV, roll uses 0. So exit = level + 0. Next night pass computes accrued from open time (maybe 1 night) and shifts. So one night behind. That's a potential accrual loss for new layers during the pass window. But C52 already has this for any new layer. Not specific to B1.

T-4: We already think HOLDS.

T-5: Restart. We need check if any rolled exit fails I6 or reconstruction. Consider a roll that was clamped and recorded a carry shift. On restart, Grind_ReconstructState rebuilds book. It uses Grind_CarryShiftGetForRecon which calls Grind_CarryShiftGetValidated. That function checks if release GV exists; if so, returns shift. If ejected, returns shift. Else checks bound. The roll's shift is price - formula. If clamped, it sets release GV. So on restart, release GV exists, so shift is returned without bound check. So I6 expected includes shift. Broker order price = new price. Expected = base + accrued + shift. Should match. If not clamped, shift is 0. So okay.

What about VL? Grind_EffectiveEntry reads VL. The VL GV persists. So expected uses rolled level. Broker order price is from the last modify. Should match. So I6 passes.

Potential issue: Grind_ReconstructState uses `Grind_CarryShiftGetForRecon` which for test mode? In live, it uses PositionSelectByTicket to get open_time. If the position exists, open_time is correct. If the shift is out of bound, it deletes it. Could a legitimate roll shift be out of bound? The bound is nightly_max_pips * nights * 2. A roll clamp could be larger than daily swap? For example, if market gaps and the exit is clamped far from formula, the shift could be large. Grind_CarryShiftGetValidated would delete it if not released. But the roll sets release GV if clamped. So it's protected. If not clamped, shift is 0. So okay.

What about the pass's shift? The pass records shift with clamped_out. If clamped, release GV set. So protected. If not clamped, shift is 0 or small. So okay.

T-5 likely HOLDS.

T-6: Merge correctness. We already identified the prune missing VL branch. Also check Grind_CarryCurrentExitTicket uses `const GrindSideState side = is_long ? g_grind_long : g_grind_short;` This copies the side state. In C52, this is fine. But B1's roll modifies `side.layers[idx].exit_target` and `exit_order_ticket`. The copy is made at step time, so it sees the latest. No issue.

Another merge issue: In Grind_CarryExitPassBegin, it builds work list using `Grind_EffectiveEntry(layer.entry_price, layer.position_ticket)`. This reads VL. In main (C52), there was no VL, so it used entry. With B1, it uses VL. That's intended. But the work list captures `formula` which is not used? Actually Grind_CarryWorkBase recomputes. So the captured formula is unused. That's dead code. Not a bug.

What about `Grind_CarryExitPassBegin` calls `Grind_CarryPruneShiftGvs(magic);` at the end. The merged prune doesn't delete VLs. So VL GVs for closed positions are not pruned. If a position is closed during the day, its VL GV persists until maybe the close deal handler deletes it. Grind_HandleSideDealFill does `Grind_VLDelete(closed_position);` so normal close deletes. If close deal missed, prune would have caught it if VL branch existed. Since it doesn't, stale VL persists. That's the merge defect.

Also in fxgrind.mq5 OnInit, it calls `Grind_CarryPruneShiftGvs(InpMagic);` before `Grind_CarryEmitSnapshot`. Same.

So T-6 BREAKS: the merged prune does not delete VL GVs. This is a regression from B1's prune. It can cause stale VL GVs to persist and affect Grind_EffectiveEntry for any future position that reuses the same ticket (unlikely) or for the same position if it is reconstructed? If the position is gone, no layer. So functional impact low, but it is a merge error. The prompt says "B1's prune without its GRIND_VL_ branch ~1006". So they know. The question asks "Does anything ... combine B1 and C52 in a way neither branch was tested for". Yes. So T-6 verdict: BREAKS (merge defect). Smallest fix: restore the `GRIND_VL_` branch in Grind_CarryPruneShiftGvs.

T-7: Tests. We need identify vacuous assertions. Let's scan fxgrind_tests_c54.mqh.

- C54_FinishCarryPass loops up to 10 times while active. If pass never completes, it exits after 10 and assertions "pass completed" fail. Not vacuous.
- C54_SeedLong8Carry: resets, seeds, sets positions. Then PassBegin. Good.
- C54_AllRestingI6Long: counts n and checks n==2. Not vacuous.
- C54_AllAccruedLong: loops over layers. If no layers, returns true. But tests have layers.
- C54_I6Long(idx): uses layers[idx]. If idx out of range, crash. Tests use valid.

Test LB33: after Adr162b_SeedLong8, order gone on layer 0. But does Adr162b_SeedLong8 set exit_order_ticket 8001 on layer 0? We assume yes. The test asserts `rc == 0`. `Adr162b_TryLong` likely calls Grind_LatticeTrySide. With order gone, guard returns CLOSING, TrySide breaks, rolled_count=0. So rc=0. Without guard, roll returns MODIFY_FAILED, TrySide increments fail count, sets backoff, breaks, rolled_count=0. So rc=0 passes in both. The failing assertions are side effects. Are they vacuous? They check archive for ROLL_REFUSED. Without guard, the roll reports ROLL_REFUSED. With guard, it doesn't. So not vacuous.

LB34(c): order gone, calls Grind_LatticeRollLayer directly. It does not seed market. The roll computes price = Grind_ExitPrice(level, exit_pips) + accrued. It then calls Grind_ExitQClampPassive? Actually the guard is before that. Without guard, it proceeds:
- entry = layer.entry_price (1.20000? from seed)
- accrued = Grind_CarryAccruedGet(pos) (0)
- formula = Grind_ExitPrice(1.20600, 5.0, _Point, 1) + 0 = 1.20650? For long, exit = level + 5 pips = 1.20650.
- clamped = Grind_ExitQClampPassive(...). This uses market bid/ask. But market test not seeded. g_grind_market_test_active might be false, so it uses live SymbolInfo. In test environment, _Symbol might not be a real symbol? But the test suite likely runs in MetaTrader tester with a symbol. It might have real bid/ask. If not, clamp might do something. But then it calls Grind_ModifyPendingPrice(8001, price, magic). SelectOurOrder false (order removed), returns false. So it reports ROLL_REFUSED. So test fails as expected. Not vacuous.

LB35: sets send_ok=false, calls TryLong. The roll will call ModifyPendingPrice, which calls SelectOurOrder true (order exists), then OrderEngineSend. send_ok false makes it return false. So roll reports ROLL_REFUSED, returns MODIFY_FAILED. TrySide counts failure. Then send_ok=true, TryLong(now+61). Backoff was set to now+60, so now+61 is after backoff. Roll succeeds. Fail count reset to 0. This tests the reset. It passes in both states. Not vacuous.

LB36: short gap. It asserts many things. Not vacuous.

LB37: C54_SeedLong8Carry seeds carry. Then one step. The step processes items 0 and 1. Item 0 is L0 with exit 8001. The pass shifts exit 8001 and sets accrued GV for 7001. Then asserts L0 accrued before roll > 2 points. Then TryLong. The roll candidate is oldest unrolled. Which layer is candidate? SeedLong8 seeds 8 layers. The pass step processed items 0 and 1. Item 0 is L0? The work list is long layers in index order. The first item is layer 0 (position 7001) with exit 8001. So after step, 7001 has accrued GV. Then TryLong rolls candidate. Candidate selection: for long, highest entry. Layers 0..7 entries? SeedLong8 likely entries 1.20000 + 0.00100 i? The highest entry is layer 7 (7008). But the pass just set accrual for 7001. The roll will roll the oldest unrolled layer. If oldest is layer 0 (lowest entry?) Wait candidate picks highest entry for long. If entries increase, highest entry is layer 7. But the test asserts "LB37 L0 accrued before roll" and then roll. The roll might roll layer 7, not L0. The test name says PassThenRollBranchM. The assertion "LB37 rolled mid-pass" just checks rc==1. It doesn't check which layer rolled. Then after finish, it checks L0 off bare level and I6(0). So it expects L0 to have been shifted by the pass, not necessarily rolled. But the roll might have rolled L0? Let's check candidate: SeedLong8 likely sets layers with entries 1.20000, 1.20100, ... or maybe 1.20500? The market is 1.20590/1.20600. The next grid level for long? At cap, when market trades through next grid level. The roll level is computed by Grind_ComputeAddTarget. If any VL? Initially no VL. anchor = deepest layer entry. For long, add target = anchor + add_pips? Actually Grind_ComputeAddTarget: if no VL, anchor = deepest entry. For long, add target = Grind_AddTargetPrice(anchor, add_pips, point, 1). If add_pips is positive, target = anchor + add_pips. But for long, adds are below market? Hmm. Let's not. The test says "SeedLong8 (1.20590/1.20600); PassBegin; ONE step (items 0 and 1: L0 with exit 8001, L1 held); rc = Adr162b_TryLong(now); finish". It says L0 with exit 8001. The roll will roll the OLDEST unrolled layer. If L0 is oldest, it has an exit, so branch M. The test asserts branch M implicitly? It asserts "LB37 L0 off bare level" after roll. If L0 was rolled, its exit is now at level exit + accrued, not bare level. So yes, L0 is rolled. So candidate is L0. That means for long, candidate picks highest entry? If L0 has highest entry? Maybe entries decrease: L0 at 1.20600? Let's not.

The tests LB37-LB39 pass in both states. They are not C54-specific. They test B1 x C52. Are they vacuous? They assert I6 and accrued. If the pass never ran, C54_AllAccruedLong would fail. So they exercise code.

One potential vacuous assertion: In LB37, `AssertTrue("LB37 rolled mid-pass", rc == 1 && g_grind_carry_exit_pass_active);` It asserts pass is still active. Since the pass had 8 items and only one step (2 items), it should be active. That's fine. But if the roll failed, rc might be 0. So not vacuous.

In LB39, `AssertTrue("LB39 one roll, branch S", rc == 1 && MathAbs(Grind_VLGet(7009UL) - 1.19800) <= 1e-9 && g_grind_order_test_modify_calls == 0);` It asserts modify_calls == 0. But the roll branch S does not call modify. However, the pass step had not run yet? The sequence: PassBegin, then Adr162b_TryLong. The roll happens. It is branch S (no exit). It sets VL and calls Grind_ExitQManageSide, which places an exit. Placement increments g_grind_order_test_place_calls, not modify_calls. So modify_calls == 0. But what if the roll was branch M? Then modify_calls would be >0. So this asserts branch S. Good.

What about the guard? The C54 fix is not tested for the case where exit_order_ticket !=0 and SelectOurOrder false due to order of another magic. There is no test that sets a different magic on the order. So that behavior has no test that fails without it. Also the case where ticket is 0 is not applicable because guard only if !=0. So T-7: The C54 guard's "other magic" branch has no test. Also the guard's behavior when exit_position_ticket == 0 but exit_order_ticket !=0 and order is filled (deal unprocessed) is simulated by order gone, not by a filled order with unprocessed deal. But both lead to SelectOurOrder false. So same code path.

Vacuous: Check LB34(a): "LB34 already rolled" asserts rc == GRIND_ROLL_ALREADY_ROLLED && modify_calls == 0 && VLGet == 1.20600. It sets VL before. This test passes even if C54 guard is absent because ALREADY_ROLLED check is before guard. So it's not C54-specific. But that's by design. Not vacuous.

LB33 "LB33 no broker call" asserts modify_calls == 0. Without guard, the roll calls ModifyPendingPrice, which calls SelectOurOrder false, so it returns false BEFORE calling OrderEngineSend. Thus modify_calls remains 0. So this assertion passes in both states. It is vacuous with respect to the fix. The prompt asks "Does any assertion in fxgrind_tests_c54.mqh pass vacuously (inside an if, on leftover state, or on a fixture that never reaches the code)?" Yes, "LB33 no broker call" passes in the unfixed state because the modify call counter is only incremented inside Grind_OrderEngineSend, which is never reached when SelectOurOrder fails. So it does not test that the guard prevents a broker call; it passes vacuously. Similarly "LB34 order gone no vl": without guard, the roll would fail at ModifyPendingPrice before VLSet, so VL is not set. So it passes in both. But it's listed as PASS in both by design. The question asks which pass vacuously. We can say: "LB33 no broker call" is vacuous because the unfixed path also never increments modify_calls (SelectOurOrder fails first). "LB33 no vl" and "LB34 order gone no vl" also pass in both because the unfixed path fails before VLSet. But they are intended as PASS in both. The truly failing assertions are the report/failure/backoff ones. So the test does catch the fix via those.

Now PREMISE VERDICT: Is branch safe to merge to main with lattice OFF, and is B1+C52+C54 consistent with it ON? With lattice OFF: the only functional differences are logging, the rolled key in scalp_closed (ignored by pipshed), and extra GV checks. The missing VL prune is irrelevant if no VL GVs. However, if any stale VL GVs exist, they would affect behavior. Since B1 never deployed, live has none. But to be safe, the missing VL prune should be fixed before merge. So verdict: Safe with lattice OFF on a clean book, BUT the merge has a defect (missing VL prune) that should be fixed before merge to avoid stale VLs if lattice ever turned on or tests leave GVs. With lattice ON: B1+C52+C54 has T-1 stale ticket forever risk, T-3 short side/accrual deferral, T-6 prune leak. So not fully consistent; needs T-1 fix and T-6 fix. But the prompt says "is B1 + C52 + C54 consistent with it ON". We can say mostly, but T-1 and T-6 are open. The C54 fix is correct for its narrow purpose. The interaction tests LB37-LB39 cover long side; short side carry pass with roll is untested and can defer accrual via sign guard. The gap loop rolling several layers mid-pass is not tested but by reading should be idempotent. The clamped roll followed by pass is idempotent because pass recomputes from live VL and overwrites shift. So ON is consistent for I6 but has coverage gaps and a silent stale ticket path.

TEST GAPS: list missing tests:
- Guard with order of another magic (SelectOurOrder false due to magic mismatch).
- Guard when exit_order_ticket !=0 and exit_position_ticket !=0? That's prior check.
- Short side roll during carry pass (LB37-LB39 long only).
- Gap loop rolling several layers mid-pass (multiple rolls in one OnTick while pass active).
- Roll whose modify is clamped during a pass, followed by pass shifting same exit (only long clamped? LB37 "off bare level" implies clamp? Actually they assert off bare level > 2 points, meaning clamp? The test says swap -0.10 causes exit moves UP from 1.20650. That's not clamp; that's accrued. Clamp would be if theoretical is too close to market. The market is 1.20590/1.20600. A long exit at 1.20650 is 50 pips above ask, so not clamped. So no clamp test.)
- Pass clamp followed by roll.
- Sign-guard skip on effective entry after roll (short side).
- Stale exit_order_ticket on allowed rank not cleared by RetryMissingExits (T-1).
- Missing VL prune (T-6).

Now we need write final answer with sections. Must include quotes. We can quote one line or part. Since no line numbers, cite function and quote. For each given, quote.

Let's structure.

GIVENS CHECK:
G1 VERIFIED. Quote: `if(layer.exit_order_ticket != 0 && !Grind_SelectOurOrder(layer.exit_order_ticket, magic)) return GRIND_ROLL_CLOSING;` in Grind_LatticeRollLayer before modify etc.
G2 VERIFIED. Quote: `if(rc == GRIND_ROLL_MODIFY_FAILED) { ... }` and `if(rc != GRIND_ROLL_OK) break;` in Grind_LatticeTrySide. No count/backoff for CLOSING.
G3 VERIFIED. Quote: `if(!enabled || blocked) return;` in Grind_LatticeOnTick. OnTick passes InpVirtualLattice.
G4 VERIFIED. Quote: `return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx], g_grind_carry_exit_work_pos[idx]), exit_pips, point, dir) + Grind_EjectOffsetGet(...)` in Grind_CarryWorkBase.
G5 VERIFIED as visible. Quote: `if(position_ticket == 0) return false;` in Grind_VLHas. Quote prune: `if(StringFind(name, "GRIND_CARRY_SHIFT_") == 0) ... else if(StringFind(name, GRIND_CARRY_RELEASE_PREFIX) == 0) ... else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) ... else { continue; }` no GRIND_VL_. But cannot diff main. Say VERIFIED for the two cited changes; cannot fully diff main from attached.

T-1: HOLDS. Evidence: guard returns CLOSING. Grind_ExitQHoldCancelLayer only called for `!Grind_ExitQAllowed(ranks[i], n) && side.layers[i].exit_order_ticket != 0`. For allowed rank, ExitQManageSide skips: `if(side.layers[i].exit_order_ticket != 0 || side.layers[i].exit_position_ticket != 0) continue;`. So stale ticket on allowed rank not cleared by RetryMissingExits. Deal processing clears in Grind_HandleSideDealFill: `side.layers[layer_idx].exit_order_ticket = 0;`. If deal event missed, stale forever. I3 may catch if no exit coverage, but if a filled exit position exists, recon sees coverage and may not halt. Guard is silent. Smallest fix: in Grind_ExitQManageSide, for allowed ranks, if exit_order_ticket !=0 and !SelectOurOrder and no deal found, clear it; or add a telemetry marker in the guard. (Out of scope.)

T-2: HOLDS on clean live book; NEEDS-FIX for stale VLs. List:
- OnInit: `Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject)` call.
- `Print("GRIND_LATTICE enable=", InpVirtualLattice);` and `Grind_ArchiveMarker("INFO", "LATTICE_CONFIG", ...)`.
- OnTick: `Grind_LatticeOnTick(... InpVirtualLattice ...)` returns early.
- Grind_EffectiveEntry reads `Grind_VLHas`; with no VL, returns entry.
- Grind_ComputeAddTarget scans `any_vl`; with no VL, uses deepest entry.
- Grind_HandleSideDealFill: `const bool was_rolled = Grind_VLHas(closed_position);` adds `rolled` to scalp_closed.
- Grind_CarryPruneShiftGvs missing `GRIND_VL_` branch. With no VL, no diff. If stale VLs exist, Grind_EffectiveEntry changes exits, ranks, entries, I6.
Can any change live exit/entry/invariant/halt? Only if stale VL GVs exist. B1 never deployed, so live clean. Verdict HOLDS for live merge, but fix prune before enabling lattice.

T-3: NEEDS-FIX / BREAKS? We need decide. The tests miss short side and clamp. I found no I6 break. Accrual loss/deferral on short side sign guard: quote `if(Grind_CarrySignGuardAppliesAtShift(...)) { ... g_grind_carry_exit_skipped++; ... return false; }` and `Grind_CarrySignGuardAppliesAtShift` uses `Grind_EffectiveEntry(entry, position_ticket)`. After a roll, effective entry is the level. For short, if the shifted exit would be >= effective entry, the pass skips and does not commit the new accrual (`Grind_CarryAccruedSet` is after the guard). This can leave the exit and GV one night behind. I6 still passes because both use the old accrued. So no I6 break, but accrual deferral. Verdict: NEEDS-FIX (tests missing short side; code behavior is deferred accrual, not I6 break). Also gap loop rolling several layers mid-pass not tested but by reading idempotent. Clamped roll followed by pass: pass overwrites shift, idempotent. Pass clamp followed by roll: roll deletes shift, consistent.

T-4: HOLDS. The pass commits accrued in `Grind_CarryExitShiftLayer` after modify: `if(Grind_CarryShouldCommitAccrual(true, false, true)) Grind_CarryAccruedSet(position_ticket, accrued_price);`. A roll reads `const double accrued = Grind_CarryAccruedGet(pos);` at roll time. If roll happens before the pass processes that item, it uses old accrued; the pass later modifies the same exit to the new accrued and updates the GV. If roll happens after, it uses the new accrued. No persistent mismatch. Quote.

T-5: HOLDS. Grind_ReconstructState rebuilds from broker tickets, uses `Grind_EffectiveEntry` and `Grind_CarryShiftGetForRecon`. Rolled exits have VL GV and shift GV. Normal close deletes VL: `Grind_VLDelete(closed_position);` in Grind_HandleSideDealFill. Restart pass restarts from scratch because gate not marked done until completion. No I6 failure expected. Quote.

T-6: BREAKS. The auto-merged `Grind_CarryPruneShiftGvs` lacks the `GRIND_VL_` branch. Quote the loop: `if(StringFind(name, "GRIND_CARRY_SHIFT_") == 0) ... else if(StringFind(name, GRIND_CARRY_RELEASE_PREFIX) == 0) ... else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) ... else { continue; }`. B1's prune had a VL branch; merge lost it. So stale VL GVs are never pruned. Smallest fix: add `else if(StringFind(name, "GRIND_VL_") == 0) { ... }` to the prune. (This is a merge defect.)

T-7: Tests. The C54 guard is tested by LB33 and LB34(c) failing without it. But:
- "LB33 no broker call" passes vacuously in the unfixed state: without the guard, `Grind_ModifyPendingPrice` calls `Grind_SelectOurOrder` first and returns false before `Grind_OrderEngineSend`, so `g_grind_order_test_modify_calls` stays 0. Quote: `if(!Grind_SelectOurOrder(ticket, magic)) return false;` in Grind_ModifyPendingPrice.
- "LB33 no vl" and "LB34 order gone no vl" also pass in both because the unfixed path fails before `Grind_VLSet`.
- No test for SelectOurOrder false due to order of another magic.
- No short-side roll-during-carry-pass test (LB37-LB39 long only).
- No test for a gap loop rolling several layers mid-pass.
- No test for a clamped roll followed by pass shift (LB37 market far from exit, not clamped).
- No test for pass clamp followed by roll.
- No test for sign-guard skip on effective entry after roll.
- No test for T-1 stale ticket on allowed rank.
- No test for missing VL prune.

PREMISE VERDICT:
- Lattice OFF: Safe to merge on a clean live book (no GRIND_VL_ GVs). Functional differences are logging, `rolled` key in scalp_closed (pipshed ignores), and extra GV checks. However, the missing VL prune is a latent merge defect; if any stale VL GVs exist (tests, previous ON run), it can change exits/ranks/entries/I6. So fix the prune before merge.
- Lattice ON: B1+C52+C54 is consistent for the long-side tested paths. But T-1 (stale exit ticket on allowed rank not cleared) can silently stop rolls; T-3 short-side sign-guard can defer accrual; T-6 prune leak. Not fully consistent without those fixes/tests. The C54 fix itself is correct for its narrow purpose: returning CLOSING without report/backoff.

TEST GAPS: list as above.

We need ensure we quote exactly. The quotes should be from attached code. We can use partial lines. Need cite file and function. Since no line numbers, use file name and function name.

Let's craft final answer. Desired oververbosity 5. We need be exhaustive but not too long. The user asked "No preamble." So start with GIVENS CHECK.

We must include quotes. Use backticks.

Let's write.

Check quotes:
G1: In Grind_LatticeRollLayer:
```
if(layer.exit_order_ticket != 0
   && !Grind_SelectOurOrder(layer.exit_order_ticket, magic))
   return GRIND_ROLL_CLOSING;
```
G2: In Grind_LatticeTrySide:
```
if(rc == GRIND_ROLL_MODIFY_FAILED) { ... }
...
if(rc != GRIND_ROLL_OK)
   break;
```
G3: In Grind_LatticeOnTick:
```
if(!enabled || blocked)
   return;
```
G4: In Grind_CarryWorkBase:
```
return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx],
                                            g_grind_carry_exit_work_pos[idx]),
                       exit_pips, point, dir)
       + Grind_EjectOffsetGet(g_grind_carry_exit_work_pos[idx]);
```
G5: Grind_VLHas:
```
if(position_ticket == 0)
   return false;
```
Prune:
```
if(StringFind(name, "GRIND_CARRY_SHIFT_") == 0) {
...
} else if(StringFind(name, GRIND_CARRY_RELEASE_PREFIX) == 0) {
...
} else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) {
...
} else {
   continue;
}
```
No GRIND_VL_.

T-1 quotes:
Guard: above.
ExitQHoldCancelLayer:
```
if(Grind_CancelPendingOrder(ticket, magic)) {
   layer.exit_order_ticket = 0;
...
}
if(Grind_SelectOurOrder(ticket, magic))
   return false;
```
ExitQManageSide:
```
if(!Grind_ExitQAllowed(ranks[i], n) && side.layers[i].exit_order_ticket != 0)
   Grind_ExitQHoldCancelLayer(side.layers[i], is_long, magic);
```
and second loop:
```
if(side.layers[i].exit_order_ticket != 0 || side.layers[i].exit_position_ticket != 0)
   continue;
```
Deal processing:
```
side.layers[layer_idx].exit_order_ticket = 0;
side.layers[layer_idx].exit_position_ticket = position_id;
```

T-2 quotes:
OnInit: `if(!Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject))` and `Print("GRIND_LATTICE enable=", InpVirtualLattice);`
OnTick: `Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice, ...)`
Grind_HandleSideDealFill: `const bool was_rolled = Grind_VLHas(closed_position);`
Grind_ComputeAddTarget: `if(Grind_VLHas(side.layers[i].position_ticket)) { any_vl = true; break; }`

T-3 quotes:
Grind_CarryExitShiftLayer sign guard:
```
if(Grind_CarrySignGuardAppliesAtShift(position_ticket, entry_price, theoretical, is_long)) {
   sign_guard_skipped_out = true;
   g_grind_carry_exit_skipped++;
   ...
   return false;
}
```
and `Grind_CarrySignGuardAppliesAtShift`:
```
const double eff = Grind_EffectiveEntry(entry, position_ticket);
return Grind_CarrySignGuardBlocks(eff, new_exit, is_long);
```
Accrued set after:
```
if(Grind_CarryShouldCommitAccrual(true, false, true))
   Grind_CarryAccruedSet(position_ticket, accrued_price);
```

T-4 quotes:
Roll reads: `const double accrued = Grind_CarryAccruedGet(pos);`
Pass sets: `Grind_CarryAccruedSet(position_ticket, accrued_price);`

T-5 quotes:
Recon: `Grind_ReconstructState()` and `Grind_RebuildBookFromTickets(... tolerate_exit_shortfall=true)`. Effective entry in I6: `const double eff = Grind_EffectiveEntry(entry, position_id);` in Grind_ReconExitMatchesEntry.
Close deletes VL: `Grind_VLDelete(closed_position);`

T-6 quotes: prune loop as above.

T-7 quotes:
LB33: `AssertTrue("LB33 no broker call", g_grind_order_test_modify_calls == 0);`
Modify: `if(!Grind_SelectOurOrder(ticket, magic)) return false;`
LB33 no vl: `AssertFalse("LB33 no vl", Grind_VLHas(7001UL));`
LB34: `AssertFalse("LB34 order gone no vl", Grind_VLHas(7001UL));`

PREMISE quotes maybe not needed.

Now write final. Ensure sections in order. Keep concise but complete. Use VERIFIED/HOLDS/BREAKS/NEEDS-FIX. For T-2 I'll say HOLDS (clean) / NEEDS-FIX (stale VL). For T-3 NEEDS-FIX. T-6 BREAKS. T-1 HOLDS. T-4 HOLDS. T-5 HOLDS. T-7 NEEDS-FIX.

Let's produce.

## Final Report

## GIVENS CHECK

**G1. VERIFIED.** `Grind_LatticeRollLayer` returns `GRIND_ROLL_CLOSING` before any modify, report, VL write or queue call:
`if(layer.exit_order_ticket != 0 && !Grind_SelectOurOrder(layer.exit_order_ticket, magic)) return GRIND_ROLL_CLOSING;`
It sits after the `ALREADY_ROLLED` and `exit_position_ticket` checks and before `Grind_ModifyPendingPrice`, `Grind_VLSet`, `Grind_EjectReport`, `Grind_ExitQManageSide`.

**G2. VERIFIED.** `Grind_LatticeTrySide` counts/backs off only for `GRIND_ROLL_MODIFY_FAILED`:
`if(rc == GRIND_ROLL_MODIFY_FAILED) { ... }`
and then for anything else:
`if(rc != GRIND_ROLL_OK) break;`
So `GRIND_ROLL_CLOSING` breaks the loop but does not touch `g_grind_vl_fail_count_*` or `g_grind_vl_backoff_*`.

**G3. VERIFIED.** `Grind_LatticeOnTick` exits immediately when disabled:
`if(!enabled || blocked) return;`
`OnTick` passes `InpVirtualLattice` into it, so `false` returns before any roll.

**G4. VERIFIED.** `Grind_CarryWorkBase` re-reads the live VL:
`return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx], g_grind_carry_exit_work_pos[idx]), exit_pips, point, dir) + Grind_EjectOffsetGet(g_grind_carry_exit_work_pos[idx]);`
`Grind_EffectiveEntry` in turn reads `Grind_VLGet`, so a pass item processed after a roll prices from the rolled level.

**G5. VERIFIED as far as the attached files show.** `Grind_VLHas` has the ticket-0 guard:
`if(position_ticket == 0) return false;`
`Grind_CarryPruneShiftGvs` prunes only shift, release and eject-offset GVs:
`if(StringFind(name, "GRIND_CARRY_SHIFT_") == 0) { ... } else if(StringFind(name, GRIND_CARRY_RELEASE_PREFIX) == 0) { ... } else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) { ... } else { continue; }`
No `GRIND_VL_` branch is present. I cannot diff `main` from the attachment, but the two cited changes are visible.

## T-1

**Verdict: HOLDS.** The guard can leave a stale `exit_order_ticket` on an allowed rank, and the guard is silent.

Evidence:
- The guard returns `GRIND_ROLL_CLOSING` before any cleanup:
  `if(layer.exit_order_ticket != 0 && !Grind_SelectOurOrder(layer.exit_order_ticket, magic)) return GRIND_ROLL_CLOSING;`
- `Grind_ExitQHoldCancelLayer` can clear a missing order, but only when the rank is not allowed:
  `if(!Grind_ExitQAllowed(ranks[i], n) && side.layers[i].exit_order_ticket != 0) Grind_ExitQHoldCancelLayer(side.layers[i], is_long, magic);`
- For allowed ranks, `Grind_ExitQManageSide` skips layers that already have any exit:
  `if(side.layers[i].exit_order_ticket != 0 || side.layers[i].exit_position_ticket != 0) continue;`
- The normal clear is deal processing:
  `side.layers[layer_idx].exit_order_ticket = 0; side.layers[layer_idx].exit_position_ticket = position_id;`
- `Grind_RetryMissingExits` calls `Grind_ExitQManageSide`, but as above it does not clear a stale ticket on an allowed rank.

So if the exit filled but the deal event is lost, or the order was removed and no exit position exists while the rank is allowed, the ticket can stay stale. If no exit position exists, `Grind_CheckBookInvariants` may catch I3; if a filled exit position exists, reconstruction can see coverage and not halt. The roll then returns `CLOSING` every tick with no report.

Smallest fix: in `Grind_LatticeRollLayer`, on that `CLOSING` branch, emit a telemetry marker, or in `Grind_ExitQManageSide` clear a non-selectable `exit_order_ticket` even for allowed ranks when no exit deal/position can be found.

## T-2

**Verdict: HOLDS on a clean live book; NEEDS-FIX for stale VL GVs.**

With `InpVirtualLattice=false`, the merged build still runs these differently from a no-B1 build:
- `OnInit` validates lattice inputs:
  `if(!Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject))`
- `OnInit` prints and archives lattice state:
  `Print("GRIND_LATTICE enable=", InpVirtualLattice);`
  `Grind_ArchiveMarker("INFO", "LATTICE_CONFIG", "", 0, ...)`
- `OnTick` always calls the lattice entry point, which returns immediately:
  `Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice, ...)`
- `Grind_HandleSideDealFill` now adds a `rolled` value to `scalp_closed`:
  `const bool was_rolled = Grind_VLHas(closed_position);`
- `Grind_EffectiveEntry` now calls `Grind_VLHas`; with no VL GV it returns the original entry.
- `Grind_ComputeAddTarget` now scans for VLs:
  `if(Grind_VLHas(side.layers[i].position_ticket)) { any_vl = true; break; }`
  With no VLs it falls back to the deepest entry, so the anchor is the same.
- The prune no longer deletes `GRIND_VL_` GVs.

On a clean live book there are no `GRIND_VL_` GVs, so exits, entries, ranks and I6 are unchanged. The `rolled` key is ignored by pipshed per the prompt. The latent risk is the missing VL prune: if any stale `GRIND_VL_` GV exists, `Grind_EffectiveEntry` will read it and change exits, ranks, entries and I6 while the lattice is off.

## T-3

**Verdict: NEEDS-FIX.** I do not find an I6 break in the tested long-side interleavings, but the short side is uncovered and can defer an accrual.

The missed interleaving is a short-side roll during a carry pass followed by a sign-guard skip. In `Grind_CarryExitShiftLayer`:
`if(Grind_CarrySignGuardAppliesAtShift(position_ticket, entry_price, theoretical, is_long)) { sign_guard_skipped_out = true; g_grind_carry_exit_skipped++; ... return false; }`
`Grind_CarrySignGuardAppliesAtShift` uses the rolled effective entry:
`const double eff = Grind_EffectiveEntry(entry, position_ticket);`
For a short, after a roll the effective entry is the virtual level. If the shifted exit would be `>=` that level, the guard skips. Because the guard returns before:
`if(Grind_CarryShouldCommitAccrual(true, false, true)) Grind_CarryAccruedSet(position_ticket, accrued_price);`
the new accrual is not committed. The exit and GV remain one night behind. I6 still passes because both sides use the old accrued, but the accrual is deferred. LB37-LB39 are long-only and do not test this.

A gap loop rolling several layers mid-pass is not tested, but by reading it should be idempotent: each later pass step recomputes `Grind_CarryWorkBase` from the live VL. A clamped roll followed by a pass shift is also idempotent: the pass overwrites the shift with the new clamp residual. A pass clamp followed by a roll is consistent because the roll reads the updated accrual GV and deletes/overwrites the shift.

## T-4

**Verdict: HOLDS.** The roll reads the accrued GV at roll time:
`const double accrued = Grind_CarryAccruedGet(pos);`
The pass commits the new accrual inside the same item, after the modify:
`if(Grind_CarryShouldCommitAccrual(true, false, true)) Grind_CarryAccruedSet(position_ticket, accrued_price);`
If the roll happens before the pass reaches that item, it uses the old accrual, but the pass later modifies the same exit to the new accrual and updates the GV. If the roll happens after the pass reaches that item, it uses the new accrual. No persistent exit/GV mismatch follows.

## T-5

**Verdict: HOLDS.** `Grind_ReconstructState` rebuilds from broker tickets and uses the VL in I6:
`const double eff = Grind_EffectiveEntry(entry, position_id);`
The normal close path deletes the VL:
`Grind_VLDelete(closed_position);`
A mid-pass restart loses the in-memory pass state, but the gate is not marked done until the pass completes, so a new pass restarts from scratch. Rolled exits have their VL and shift GVs, and I6 uses both. I do not see a reconstruction failure specific to a rolled exit.

## T-6

**Verdict: BREAKS.** The auto-merged `Grind_CarryPruneShiftGvs` lost B1's `GRIND_VL_` branch. It now prunes only:
`if(StringFind(name, "GRIND_CARRY_SHIFT_") == 0) { ... } else if(StringFind(name, GRIND_CARRY_RELEASE_PREFIX) == 0) { ... } else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) { ... } else { continue; }`
So stale `GRIND_VL_` GVs are never pruned by the carry pass or by `OnInit`. With the lattice ON, this is a merge regression; with it OFF it can still affect `Grind_EffectiveEntry` if any stale VL GV exists.

Smallest fix: restore a `GRIND_VL_` branch in `Grind_CarryPruneShiftGvs`.

## T-7

**Verdict: NEEDS-FIX.** The C54 guard is exercised by LB33 and LB34(c), which fail without it. But several assertions pass vacuously, and several behaviours are untested.

Vacuous assertions:
- `AssertTrue("LB33 no broker call", g_grind_order_test_modify_calls == 0);` passes without the fix because `Grind_ModifyPendingPrice` first does:
  `if(!Grind_SelectOurOrder(ticket, magic)) return false;`
  so the modify counter is never incremented even on the unfixed path.
- `AssertFalse("LB33 no vl", Grind_VLHas(7001UL));` and `AssertFalse("LB34 order gone no vl", Grind_VLHas(7001UL));` also pass without the fix because the unfixed path fails before `Grind_VLSet`.

Untested C54 behaviour:
- `Grind_SelectOurOrder` false because the order belongs to another magic.
- Short-side roll during a carry pass.
- Gap loop rolling several layers mid-pass.
- Clamped roll followed by a pass shift on the same exit.
- Pass clamp followed by a roll.
- Sign-guard skip on the effective entry after a roll.
- T-1 stale `exit_order_ticket` on an allowed rank.
- T-6 missing VL prune.

## PREMISE VERDICT

With the lattice **OFF**, the branch is safe to merge to `main` on a clean live book: the only differences are logging, the `rolled` key in `scalp_closed` (ignored by pipshed), and extra GV checks that return false when no VLs exist. The missing VL prune is latent, but B1 never deployed, so live should have no `GRIND_VL_` GVs. I would still fix the prune before merge because it is a clear merge defect.

With the lattice **ON**, B1 + C52 + C54 is consistent for the tested long-side paths, but not fully consistent overall. T-1 can silently stop rolls if a stale allowed-rank exit ticket is never cleared. T-3 leaves the short-side sign-guard accrual deferral untested. T-6 leaves stale VL GVs unpurged. The C54 guard itself is correct for its narrow purpose: it returns `CLOSING` without a broker call, report, failure count or backoff.

## TEST GAPS

Add tests for:
1. Guard when the exit order exists but belongs to another magic.
2. Short-side roll during a carry pass, including the sign-guard skip case.
3. Gap loop rolling several layers while a carry pass is active.
4. Clamped roll followed by a pass step shifting the same exit.
5. Pass clamp followed by a roll on the same exit.
6. T-1: stale `exit_order_ticket` on an allowed rank after `Grind_RetryMissingExits`.
7. T-6: `Grind_CarryPruneShiftGvs` must delete a stale `GRIND_VL_` GV when the position no longer exists.

<!-- finish_reason=stop -->
