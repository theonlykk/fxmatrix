# DeepSeek Narrow Sweep Audit Response

## Internal Reasoning

We need answer single question audit. Need be exhaustive. We have code. Need analyze sweep function V2_SRE_SweepEntryPendingOrders. Need determine if can ever delete order reconstructed state still needs or harm. We need pressure test six questions. Need inspect code. The sweep function is given but not in included code? It appears in prompt as fix as written, likely added to V2_SRE_RunSideOnInit success path? Need include context. Need evaluate.

We need understand system.

EA: three pairs each dual side. Entry magic long/short distinct per pair. Exit magic = entry magic + 2. Pending entry orders: L0, Add, Reload, all entry magic. Exit pending orders: exit magic. Positions: entry magic positions (open layers), exit magic positions (hedge positions from exits? Actually exit hedge positions opened by exit limit fills? Need understand: When exit limit fills, a hedge position in opposite direction with exit magic is opened, then CloseBy queued to close both. Reconstruction precheck halts if any exit-magic position open. So on success path no exit magic positions. Pending exit orders may exist, matched to positions by reconstruction. Pending entry orders are consistency-checked and then left on broker per issue. Fix sweeps pre-existing entry-magic pending limit orders after successful reconstruction so tick loop places fresh pair. Need audit deletion safety.

Let's parse sweep code:

int V2_SRE_SweepEntryPendingOrders(const string symbol, const long entry_magic)
{
   int swept = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != entry_magic) continue;
      long otype = OrderGetInteger(ORDER_TYPE);
      if(otype != ORDER_TYPE_BUY_LIMIT && otype != ORDER_TYPE_SELL_LIMIT) continue;
      MqlTradeRequest req = {}; MqlTradeResult res = {};
      req.action = TRADE_ACTION_REMOVE; req.order = ticket;
      if(V2_OrderSendCounted(req, res)) swept++;
   }
   return swept;
}

Called once, on success path only (after halt-path early-return), with cfg.symbol and cfg.entry_magic.

Need answer questions.

Need identify all places entry pending orders can be created/magic/comment.

Per side:
- Long L0: magic=20260901 (GBP), comment V2_L0, type BUY_LIMIT, placed by Long_PlaceBuyLimit.
- Long Add/Reload: magic=20260901, comment V2_Add/V2_Reload, type BUY_LIMIT, placed by Long_PlaceBuyLimit.
- Short L0: magic=20260902, comment V2_L0, type SELL_LIMIT.
- Short Add/Reload: magic=20260902, type SELL_LIMIT.

EURUSD long 20260911, short 20260912; EURGBP long 20260921, short 20260922.

Exit orders: magic = entry magic + 2, e.g. long exit 20260903, short exit 20260904; EURUSD long exit 20260913 etc. They are pending limit orders opposite direction (for long position, exit is SELL_LIMIT? Wait V2_BuildExitLimitRequest: exit_dir = -entry_direction. For long entry direction=1, exit_dir=-1 => ORDER_TYPE_SELL_LIMIT. For short, exit_dir=1 => BUY_LIMIT.) Exit magic differs by +2. Could entry_magic ever equal exit_magic? Need configuration constants: in logic default if not defined, but each EA defines entry. Exit = entry + 2. If entry_magic == exit_magic impossible unless entry_magic == entry_magic+2 no. Could an exit order carry entry magic? V2_SendExitLimit called with MM_LONG_V2_EXIT etc, not entry. But what about CloseBy requests? They use magic closeby_magic = MM_LONG_V2 (entry) in V2_ProcessCloseByQueue. But that's a request magic on CloseBy, maybe deal has entry magic? Pending orders? No pending exit orders always exit magic. However, the "exit-hedge orders" phrase maybe means exit hedge positions? Wait Q1: "Exit-hedge orders carry the EXIT magic (e.g. ...904), NOT entry_magic. The filter is magic != entry_magic -> skip. Confirm the exit-hedge (which MatchExitOrders adopts) can NEVER match entry_magic and so is never swept. Is there any config where entry_magic == exit_magic, or where an exit order carries the entry magic?" Need answer.

Exit-hedge orders? Actually MatchExitOrders matches pending exit-magic orders (resting exit limits) to positions. In spec §1.2 exit ticket assignment. These are "exit orders", not hedge positions. They are pending orders with exit magic. The sweep only iterates OrdersTotal, not positions. It filters magic == entry_magic. Exit-magic orders skip. No config where entry==exit because offset 2. But need consider if an exit order could have entry magic due to some bug? We see all placement uses exit magic. V2_ProcessCloseByQueue sends TRADE_ACTION_CLOSE_BY with magic=MM_LONG_V2 (entry magic) but no pending order; maybe a CloseBy request creates a deal/order in history with entry magic? But not within OrdersTotal unless it creates pending? No.

Q2: entry_magic per side. Long vs short distinct by 1 (e.g., 20260901 vs 20260902). Sweep called per side with cfg.entry_magic. Could long-side sweep delete short-side's pending entries? Filter magic == entry_magic. Long sweep only magic 20260901; short pending magic 20260902 skip. Short sweep vice versa. Could same-magic cross-side order exist? No, each side has unique entry magic; unless EA config mistake duplicates magics across sides? In each file, MM_LONG_V2 and MM_SHORT_V2 differ by 1. Across pairs, distinct. But maybe due to defines? Need check: fxmatrix_v2.mq5 has MM_LONG_V2=20260901, MM_SHORT_V2=20260902. logic includes default only if not defined. OK. So yes.

But question asks "given both are buy_limit/sell_limit" and "could a same-magic cross-side order exist?" Need consider an order with long magic but sell_limit? Long side always buy limits; but could there be stale/wrong-direction pending entry order? Spec §1.1b and HALT_20 check pending entry direction mismatch halts. On success path, pending_entries were consistency-checked: V2_SRE_CheckPendingEntryConsistency checks pending[i].direction != side_direction => halt. In gathering, direction for pending order is set to side_direction regardless of actual order type! Wait V2_SRE_GatherPendingOrders: for entry magic orders, pending_entries[n].direction = side_direction; it does not set based on order type. It sets direction = cfg.side_direction. So check pending[i].direction != side_direction always false. Hmm spec §1.1b says wrong-direction pending order can survive and halts, but implementation seems not actually detect wrong-direction pending entry: It doesn't inspect ORDER_TYPE at all in GatherPendingOrders. It sets direction = side_direction by assumption. Thus a wrong-direction pending order with entry magic would not halt; it would be considered a valid pending entry. This is upstream out of scope? Reconstruction logic unchanged? But for sweep safety, a wrong-direction pending entry with entry magic would be swept. Is that harmful? No, it's an entry-magic pending order that shouldn't exist; sweeping it is beneficial. But could it be an exit order carrying entry magic? No.

Need consider if there are entry magic orders of both types due to some manual or bug. The sweep deletes all buy/sell limit orders with entry magic. It could delete same-side pending entry orders that reconstruction still needs. The question: "Can this sweep, as written, EVER delete an order that the reconstructed state still needs?" The tick loop places exactly one fresh pair: L0 if stack empty, add/reload if non-empty. What pending entry orders does reconstructed state "need"? After reconstruction, in-memory layer state has positions and exit tickets. Pending entry orders on broker are NOT represented in g_long_l0_ticket/g_long_add_ticket state? Let's inspect V2_ApplyLongSRECommit: sets layers, last_exit_valid, last_exit_price, current_add_pips. It does NOT set g_long_l0_ticket or g_long_add_ticket. Those globals remain 0 (from Long_OnInit? Actually Long_OnInit resets last_exit etc but not l0/add tickets? It resets processed arrays, not l0/add tickets. OnInit calls Long_OnInit; global l0/add tickets might retain from previous attach? OnInit runs once at attach, globals initialized to 0 at program start. If reattach, new EA instance globals zero. So yes l0/add ticket = 0.) Thus tick loop sees no L0 quote if stack empty, places fresh L0. If stack non-empty, Long_OnNewBar calls Long_EnsureAddNext; if n>0 and n<max, if g_long_add_ticket==0, places add at computed target. So after sweep, tick loop will place exactly one fresh pair (L0 or add). The sweep deletes pre-existing entry-magic pending orders that were not adopted into state. Reconstruction's pending entry consistency allows at most one L0 on empty or one add/reload on non-empty. So there is at most one pending entry order per side on success path (unless multiple? Consistency halts on more than one). Actually if stack empty: L0_count <=1, add_reload_count=0. If non-empty: l0_count=0, add_reload<=1. So at most one. The sweep deletes that one. Does reconstructed state "need" it? No because not tracked; tick loop re-places. But what about the semantics of that pending order: If stack is empty and L0 pending exists, it's a pre-existing L0 quote at some price. Tick loop will compute new L0 price and replace if outside deadband/place if no ticket. So safe. If stack non-empty and add pending exists, tick loop's EnsureAddNext will compute add target and place new. Safe.

But possible scenario: reconstruction success with non-empty stack and a pending entry order that is actually the "next layer" quote. Deleting it means tick loop places a new one at correct price. Safe, though may lose the specific price/time priority? It's a limit order; deleting and re-placing changes queue priority but not harmful? Could be harmful if the market moves and the tick loop's new quote is at a different price, possibly not as good? But the pre-existing order was placed before; if it gets filled soon, deleting could avoid an intended fill? Wait the reconstructed state doesn't include that pending order. The whole fix is to delete duplicates. But is the pre-existing pending order "intended" by the EA's previous running state? If EA crashed/reattached, the pending order was placed by previous session and may represent a valid desired quote. Reconstruction validates consistency but does not adopt it. The design spec §1.4 says pending entry-order consistency is checked, but then "left on the broker" per Tier 2. The duplicate problem: tick loop, seeing no L0 quote in rebuilt state, places fresh one -> duplicate. So they delete pre-existing entry pendings. Could deleting an order that is "still needed" by reconstructed state cause missing intended next-layer quote? The tick loop will re-place. The question asks specifically Q5: "Does deleting entry pendings on the success path ever strand the reconstructed positions without their intended next-layer quote in a way the tick loop does NOT then correctly re-place? (i.e. is 'delete-then-let-tick-loop-requote' actually safe, or is there a layer whose quote the tick loop won't re-place?)"

Need analyze tick loop behavior for each layer state.

Long_OnTick -> Long_OnNewBar. At each new M5 bar only (g_last_bar_time). It computes bid signal. If n==0, it calls Long_ReplacePendingBuy(g_long_l0_ticket, bid_lvl, magic, "V2_L0") to place L0. If n>0, it skips L0 and calls Long_EnsureAddNext. Long_EnsureAddNext: if n<=0 or n>=InpMaxLayers return. If g_long_add_ticket !=0 and OrderSelect(g_long_add_ticket) return. Computes add target based on last_exit_valid and top layer. If !last_exit_valid, checks cap blocks new add (only if !last_exit_valid? Actually code: if(!g_long_last_exit_valid && V2_GbpCapBlocksNewAdd...). If last_exit_valid true, no cap check. Then places add. So for non-empty stack, it will place an add/reload at next M5 bar. Thus yes.

But wait: If stack non-empty and n>=InpMaxLayers, it won't place. Could there be a pending entry order at max layers? Consistency allows one add/reload pending even at stack_depth >= max? The EA wouldn't have placed one if max reached, but a pre-existing one could exist from when stack was below max; after layers filled, stack may reach max while pending add remains. On reattach, reconstruction sees stack_depth>=max and pending add/reload; pending consistency allows one add/reload on non-empty regardless of max. Sweep deletes it. Tick loop won't re-place because n>=max. Is that harmful? The pending order is above max layers; if it filled, it would create a layer beyond max, which EA would have prevented? Actually if pending order existed while stack below max, then stack filled additional layers? Need timeline: Suppose previous session had 18 layers, pending add placed. Market moves, pending add fills -> 19 layers, EA places next add (19<20). Another fill -> 20 layers, no add. Pending? No. If stack max reached, no pending should exist because when a fill occurred at 19? Let's simulate: At n=18, add pending. Fill -> n=19, Long_AppendLayer cancels g_long_add_ticket and Long_EnsureAddNext places new add because n=19<20. So pending exists at n=19. Fill -> n=20, Long_AppendLayer cancels add and EnsureAddNext returns due n>=20, so no pending. So at max layers no pending should exist. But if crash happened between? Maybe not. If reconstruction sees stack_depth=20 and a pending add, it's inconsistent with EA logic? It would have been placed when n=19 then not yet filled; stack cannot reach 20 without that pending filling and being cancelled. Unless n=19 and pending add placed, then another external? The pending add itself is the only way to reach 20. If stack_depth=20, the pending add that would have made 20 already filled and cancelled. So no pending. Thus not an issue.

But what about L0 pending on empty stack and max layers? no.

Could tick loop not re-place because of deadband skip? Long_ReplacePendingBuy: if ticket_ref ==0, V2_L0RestingWithinDeadband(0,...)=false, so places. Good. If there is some stale g_long_l0_ticket? On new instance zero. Good.

Could tick loop not re-place because OnNewBar only fires once per M5 bar and if OnInit occurs mid-bar, it will wait until next bar? Actually Long_OnTick runs on every tick; Long_OnNewBar gets bar_time = iTime(_Symbol, PERIOD_M5, 0) (current bar's opening time). If g_long_last_bar_time initially 0, first tick will see bar_time !=0 and process. So immediate.

Q3: Multi-instance distinct magics and symbols. Sweep filters symbol and magic. Confirm no cross-instance deletion. Need check symbol comparison: OrderGetString(ORDER_SYMBOL) != symbol. In MQL5, string comparison case-sensitive? Symbol names likely exact. Across EURUSD/GBPUSD/EURGBP distinct. Magic distinct. So no cross-instance. But what if same symbol on multiple charts? There is only one EA per pair? Three EAs on one account each distinct symbol. If two charts same symbol with different magic? Not in current scope. Filter magic prevents cross. Good.

Q4: Timing/state: fill between gather and sweep. Reconstruction gathered snapshot of open positions, pending orders, deals. It runs on gathered snapshot; sweep runs after. If a pending entry order fills between the gather and the sweep, then what happens? The sweep iterates OrdersTotal. If an order filled, it's no longer in OrdersTotal; it becomes a position and a deal. OrderSelect on old ticket? OrdersTotal won't include it. So sweep won't delete it. But the reconstructed state didn't include the new position because gather happened before fill. Then after sweep, the tick loop will see the new position? The new position is open with entry magic. It will be included in PositionsTotal on next tick? But in-memory layer arrays were committed from reconstruction and do not include this new position. OnTradeTransaction may fire when the fill occurs? Timing matters: If the fill occurs after gather but before/during sweep, OnTradeTransaction might be queued? OnInit is running; OnTradeTransaction maybe not called until after OnInit? In MT5, OnInit executes when EA attached. During OnInit, terminal events may be processed? Usually OnInit runs synchronously; trade transactions can occur asynchronously. If an order fills while OnInit is running, the deal event may be delivered after OnInit completes. Then Long_HandleDealFill will process the deal: it will see is_long_entry true, order_ticket maybe not equal to any in-memory tickets (g_long_l0_ticket=0, g_long_add_ticket=0), array size maybe >0. It will call Long_AppendLayer(deal_price, order_ticket, position_id, is_reload) even if order_ticket is not one of tracked tickets. Wait code in Long_HandleDealFill for entry: is_reload = g_long_last_exit_valid; if order_ticket == g_long_l0_ticket then l0=0; if order_ticket == g_long_add_ticket then add=0; if ArraySize==0 then last_exit_valid=false; Long_AppendLayer(...). It does NOT check whether the order ticket is one it knows. So if a pre-existing pending entry order fills after reconstruction, Long_HandleDealFill will append a layer for it, even though it was a duplicate/untracked order. Then the stack includes this layer, and the tick loop will place add etc. That might actually be correct? But the sweep deleted other pending orders after this fill? The filled order no longer pending, so not swept. The result: a position exists, reconstruction didn't include it, but OnTradeTransaction later adds it as a layer. This is the designed handling for fills. So no loss? But could the fill occur before sweep and yet the order still appears in OrdersTotal in a transitional state? Need consider MQL5 order states. A pending order that has been filled may still appear? No, filled order moves to history, not OrdersTotal. But there is a race: The sweep's iteration uses OrderGetTicket and OrderSelect. If the order is in the process of filling (server accepted but not yet removed), OrdersTotal might still contain it with ORDER_STATE_PARTIAL? Actually pending limit orders can be partially filled? In forex, pending limit orders typically fill fully or not; but MQL5 supports partial fills for some instruments? ORDER_STATE_PARTIAL possible. The filter doesn't check ORDER_STATE. If an order is partially filled and still in OrdersTotal, TRADE_ACTION_REMOVE might fail (cannot remove partially filled) or remove remaining volume? If it removes remaining volume after partial fill, that's okay? But the filled part became a position; OnTradeTransaction will append layer. If the order is removed remaining part, no harm. However, if it deletes a partially-filled order, could it corrupt state? The position from the filled part is handled by deal. The remaining volume removal is fine.

But more dangerous: If an order fills after reconstruction's validation but before sweep, and then sweep deletes it? Not possible if no longer in OrdersTotal. But what if OrdersTotal view is stale due to reconnection? Q6.

Need examine Q4 race: "Could an order fill BETWEEN the gather and the sweep, so we delete something that just became a position?" If it just became a position, it's not in OrdersTotal. But what if the sweep's OrdersTotal still includes it due to terminal not yet updated? Then OrderSelect(ticket) may return true? Need MQL5 caching: OrdersTotal() returns number of current orders in the "trade" list. It is synchronized with server; after a fill, the terminal should remove it. But there can be a delay. If the order is still listed as pending but server has filled it, sending TRADE_ACTION_REMOVE might return an error (order not found) or possibly delete a ghost. It wouldn't delete the position. So no loss of fill. But if the terminal's order book is stale and the order actually filled, the position exists; deletion attempt fails. The deal will append layer. No harm.

But there is another race: Order fills between gather and sweep; reconstructed state didn't include the position, but OnTradeTransaction will append. However, the sweep might delete another pending order (e.g., the add) while the newly filled L0 becomes position; then tick loop places a new L0? Let's map. Suppose stack empty before crash, one L0 pending. Reconstruction gathers: entry_positions empty? Wait if stack empty, no positions. Reconstruction only attempts if orphaned startup state: layer_count==0 and total_pos>0. If no positions but pending orders exist, total_pos = entry_positions + exit_positions. entry_positions from positions only, not pending orders. exit_positions = open exit-magic positions. Pending orders are not counted in total_pos. So if there are no open positions but pending entry orders exist, V2_IsOrphanedStartupState(layer_count=0, total_pos=0) returns false! Then V2_SRE_RunSideOnInit returns false without reconstruction and without sweep? Wait the sweep is called on success path after reconstruction? But if there are no positions and only pending entry orders, is there an issue? The fix described: "after a SUCCESSFUL reconstruction (seq == V2_SRE_OK), in the live caller V2_SRE_RunSideOnInit, sweep pre-existing entry-magic pending limit orders". If reconstruction not attempted because no positions, no sweep. Then tick loop will see no L0 quote? But g_long_l0_ticket=0, and it will place a fresh L0, leaving the pre-existing L0 pending -> duplicate! This is important. The original problem: "SRE reconstructs in-memory layer state from open POSITIONS + matched exit orders + deal replay, but pre-existing ENTRY-side pending quotes (L0/Add/Reload, entry magic) are consistency-checked and then left on the broker. The tick loop, seeing no L0 quote in its rebuilt state, places a fresh one -> DUPLICATE resting quotes (observed across all 3 instances)." If there are no open positions, there is no "reconstruction" because no orphans; but there could be a pre-existing L0 pending order from a previous session that has not filled, and the EA reattaches flat. The old orphan guard would have? Let's think: If no positions but L0 pending, the EA should reattach and continue placing L0? It would leave old L0 and place new? Actually Long_OnTick when n==0 calls Long_ReplacePendingBuy(g_long_l0_ticket, bid_lvl, magic, "V2_L0"). Since g_long_l0_ticket=0, it places a new L0. It does not cancel the old L0 because it doesn't know about it. So duplicate L0. The fix as described only sweeps on reconstruction success path. But if no open positions, reconstruction isn't triggered. Is that out of scope? The prompt says "Called once, on the success path only (after the halt-path early-return), with cfg.symbol and cfg.entry_magic." Need inspect actual code location? The provided V2_SRE_RunSideOnInit does not include the sweep call! The prompt says "The fix as written" but code to audit includes V2_SRE_RunSideOnInit without sweep. Maybe the sweep is new and to be added. We need audit as written. The single question says "Called once, on the success path only (after the halt-path early-return), with cfg.symbol and cfg.entry_magic." So we assume it is inserted in V2_SRE_RunSideOnInit after successful sequence before return false? Need identify success path. In V2_SRE_RunSideOnInit, if not orphaned, returns false early. So sweep only in reconstruction success. If no positions but pending entries, the function returns false early; no sweep. That means the fix may not solve the duplicate L0 when flat? But the problem observed "across all 3 instances" likely with open positions? Tier 2 drill found duplicates? It says "SRE reconstructs in-memory layer state from open POSITIONS + matched exit orders + deal replay, but pre-existing ENTRY-side pending quotes ... are consistency-checked and then left on the broker. The tick loop, seeing no L0 quote in its rebuilt state, places a fresh one -> DUPLICATE resting quotes." This implies there were open positions? If stack non-empty, tick loop doesn't place L0, only add. The duplicate could be add? It says "L0/Add/Reload, entry magic" and "no L0 quote" specifically. If there are open positions, no L0 should be placed. The duplicate could be add/reload? The described "tick loop, seeing no L0 quote in its rebuilt state, places a fresh one" applies only if stack empty. If stack empty but there are open positions? Contradiction. Maybe "L0 quote" means generic entry quote? Let's not over-index.

Need audit sweep safety, not completeness. If no positions, no sweep is safe (no deletion). If there are pending entries but no positions and no sweep, duplicate remains benign? But out of scope? The question says "Can this sweep, as written, EVER delete an order that the reconstructed state still needs, or otherwise cause harm?" The sweep not running in some scenarios is not harm. But maybe the "success path" actually runs even when not orphaned? The prompt says "Called once, on the success path only (after the halt-path early-return)" In V2_SRE_RunSideOnInit, the success path is after gathering and reconstruction. But if V2_IsOrphanedStartupState false, it returns false before halt-path? "halt-path early-return" maybe means after the if(seq != V2_SRE_OK) block. So yes.

But we need consider if sweep could delete an order that reconstruction still needs. The reconstruction may adopt exit orders into state (exit_ticket). It does NOT adopt pending entry orders into state. So no pending entry order is needed by reconstructed in-memory state. However, could a pending entry order be the same ticket as an adopted exit order? No, magic filter.

What about pending entry order that is actually the "entry_ticket" in a reconstructed layer? In V2_SRE_BuildLayerSnapshotsFromPositions, layers[i].entry_ticket = positions[i].ticket (position ticket? Actually positions[i].ticket is position ticket from PositionGetTicket, not entry order ticket. Wait gather open positions by magic: out[n].ticket = ticket (position ticket); position_id = POSITION_IDENTIFIER. Then layer.entry_ticket = positions[i].ticket, which is position ticket, not order ticket. But validation compares entry_ticket to broker_read entry_ticket = positions[i].ticket, so consistent. The entry order ticket is not used. So pending entry orders are not referenced by layer entry_ticket. Good.

Could a pending entry order have already been used to open a position that is in reconstructed layers? No, filled orders are gone from OrdersTotal. So no.

Need inspect V2_SRE_GatherPendingOrders: It gathers pending orders with magic == entry_magic and magic == exit_magic. It does NOT filter by order type. So if there is a pending order with entry magic but wrong type (e.g., BUY_STOP or SELL_STOP), it's included as pending entry. Consistency check only comment and direction; wrong type not detected. On success, pending entries may include stop orders. The sweep only deletes BUY_LIMIT and SELL_LIMIT, not stops. So if there is a stop order with entry magic, it remains. Is that harmful? It's not deleted, so no deletion harm. But could it be "needed"? No.

Could there be a pending order with entry magic and type BUY_LIMIT that is actually an exit hedge from a short position? No, short exit uses BUY_LIMIT with exit magic +2. Magic distinct.

Need examine MQL5 OrderGetInteger returns long; comparing to entry_magic (long). OK.

Potential issue: The sweep iterates OrdersTotal() - 1 down to 0 and calls OrderGetTicket(i). In MQL5, OrdersTotal() returns total number of orders in the "Orders" list (all symbols? Actually MQL5 OrdersTotal returns number of current orders in the trade server? It includes all orders for all symbols? I think OrdersTotal is "Returns the number of current orders" in the terminal, all symbols? Yes, OrdersTotal returns number of market orders? Let's recall MQL5: OrdersTotal() returns number of current orders, which includes all symbols? It might be only for the current symbol? Actually in MQL5, OrdersTotal returns number of orders in the list of current orders (all symbols). OrderGetTicket(i) gets ticket of order by index in the list. Need not be symbol-specific. The sweep filters symbol. Good.

Potential issue: OrderSelect(ticket) selects order for current symbol? In MQL5, OrderSelect(ticket) selects an order for further work; can select any order? Yes. If selecting by ticket, symbol property available.

Potential issue: If OrdersTotal includes orders from other EAs, filter protects.

Potential issue: The sweep uses V2_OrderSendCounted(req, res) but doesn't check res.retcode. It increments API counter on every OrderSend, even if fails. Already counted by function. Not harmful.

Potential issue: If the sweep deletes an order and then later OnTradeTransaction receives a deal for that order (e.g., a stale deal event from before deletion), could it append a layer incorrectly? Let's examine race. Suppose pending order filled just before sweep; terminal hasn't delivered OnTradeTransaction yet. Sweep sees order? If filled, no. If sweep deletes a pending order, no fill deal should occur after deletion unless the fill was already in flight. Could the server fill the order after receiving a remove request? Race: Order send REMOVE for a pending order; simultaneously market touches order price; broker may fill instead of remove, or remove. If the order fills despite removal request, then a position opens. The EA's OnTradeTransaction will append layer. That's the same as if it had been left; maybe it's a "lost fill" if the EA didn't expect it? But the order was a legitimate pre-existing entry order; its fill would be a real trade. Deleting it could prevent a fill if removal wins. If fill wins, the position is managed by OnTradeTransaction. So no corruption, but the fill may create a position that the sweep wasn't aware of? It will be handled. If the order fills after gather but before sweep, and sweep does not delete it, then OnTradeTransaction appends layer. If sweep deletes it before fill, no fill. Either way state remains consistent because pending orders are not part of reconstructed state. But is it a "real fill loss" if the order was about to fill and we delete it? The purpose is to delete pre-existing duplicates; if the market hits the order, maybe the EA would have wanted it? But the EA's state didn't include it, so it's a duplicate or stale. Deleting is intended. So not harm.

However, Q4 specifically: "Could an order fill BETWEEN the gather and the sweep, so we delete something that just became a position?" If fill happened, it is a position, not an order. If the terminal's order list is stale, the remove might fail or remove a ghost. Could it delete the position? No, TRADE_ACTION_REMOVE is for pending orders only; cannot remove a position. So no loss of fill. But what if the order partially filled; the remaining order volume is removed. The partial fill position remains. OnTradeTransaction will append. If the partial fill occurred before reconstruction gather, the position would be in entry_positions and the remaining order in pending_entries. Reconstruction would include the position. The sweep deletes the remaining order. That's fine. If partial fill occurred after gather, the position is not in reconstructed layers; OnTradeTransaction appends. But there is a subtlety: The reconstruction's validation checked layer count/tickets against broker reads gathered before the partial fill. Then partial fill creates a new position. After OnInit, OnTradeTransaction appends. If the sweep deletes the remaining order, no issue. But if the partial fill occurs before validation? Then broker reads would include new position? Gather happened before fill, so no. Validation uses gathered snapshot. Not a problem.

Potential issue: The sweep runs after reconstruction commits and before OnInit returns. What about OnTradeTransaction events that occur during sweep? They may be queued and processed after OnInit. The sweep deletes orders; no transactions for deletion? There may be TRADE_TRANSACTION_ORDER_DELETE events, but OnTradeTransaction only handles DEAL_ADD. So no effect.

Need examine Q6 reconnection delay deeply. This is important. The drill logged "terminal synchronized: 1 positions, 7 orders" BEFORE EA OnInit ran. Does OnInit reliably run only after full sync? In MT5, OnInit is called when an EA is attached to a chart. If the terminal was reconnecting, the EA may still initialize before synchronization completes? The question asks if the sweep needs to gate on sync-complete condition. Need know MQL5 behavior. There is no explicit "synchronized" event in MQL5 API? There is `TerminalInfoInteger(TERMINAL_CONNECTED)`, `TERMINAL_TRADE_ALLOWED`? `MQLInfoInteger(MQL_TRADE_ALLOWED)`. There is `SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE)`? The drill log "terminal synchronized: 1 positions, 7 orders" suggests some custom print after synchronization? The prompt says "The drill showed `terminal synchronized: 1 positions, 7 orders` logged BEFORE the EA OnInit ran -- does OnInit reliably run only after full sync, or can it fire mid-sync?" Need answer from MQL5 docs knowledge.

In MetaTrader 5, when terminal starts and reconnects, the trade server synchronization happens asynchronously. EAs attached to charts can start OnInit before the terminal has completed synchronization with the trade server? I think OnInit is called after the chart and EA are loaded; if terminal is not connected, OnInit may still run? There is `MQLInfoInteger(MQL_TESTER)` etc. `TerminalInfoInteger(TERMINAL_CONNECTED)` indicates connection to trade server. During reconnect, `OnInit` may be called when EA is attached, but trade data may not be fully synchronized. However, MT5 terminal typically loads EAs after synchronization? Not sure. The prompt specifically says "Terminal synchronized: 1 positions, 7 orders" logged BEFORE EA OnInit ran, implying that in the drill, synchronization completed before OnInit. But it asks if OnInit can fire mid-sync. Need assess.

MQL5 documentation: "The OnInit() handler is called after the expert has been loaded and before the first call of the OnTick() or OnTradeTransaction() handler." It doesn't say after trade sync. `OnInit` can happen when terminal is not connected? If terminal loses connection and reattaches EA, OnInit may run after reconnect? There is a known pattern: OnTesterInit? Hmm.

MT5 client terminal architecture: The terminal has a "Trade" tab with positions/orders after synchronization. The `OnInit` is called when an EA is attached to a chart; if the terminal is offline, the EA can still be initialized? I think yes: You can attach an EA while terminal is offline? It may still initialize, but trade functions return errors. The `OnInit` can run before synchronization. There is no built-in "synchronization complete" event in MQL5. Some developers use `OnTradeTransaction` or `OnTrade` to detect sync? There is `TERMINAL_TRADE_ALLOWED` and `TERMINAL_CONNECTED` flags. `OrdersTotal`, `PositionsTotal` may return cached data. After reconnection, they might reflect only partial data until sync.

Given the prompt asks "If mid-sync is possible, does the sweep need to gate on a sync-complete condition?" We need answer. We should be careful: The sweep deletes orders. If it runs on a partial/stale order book, could it delete an order that is actually there? Wait if partial view, it might see fewer orders, so it might miss some (benign duplicate) or see stale orders that no longer exist? Deleting stale orders? Suppose terminal has a stale order in its list that was already filled/cancelled on server. Sending remove would fail. No harm. But danger: If the partial view includes an order that is actually still pending but the terminal hasn't loaded all orders? If it sees fewer, misses deletion -> duplicate benign (tick loop recovers? Actually if it misses, duplicate remains because tick loop places new one. But if the order remains, there will be two pending orders. Is that "benign"? The tick loop may later cancel? No, it doesn't know about old order. So duplicate persists until one fills. That's the original problem, not harmful to state but not fixed. The prompt says missing duplicate benign, tick loop recovers? Wait if sweep misses an entry pending, the old order remains and tick loop places a fresh one -> duplicate. That's exactly the bug, not benign. The prompt Q6 says "misses an entry pending that IS there (leaving a duplicate -- benign, tick loop recovers)" Wait "benign" in the sense not causing deletion harm, but it's the issue the fix is meant to solve. However, if mid-sync partial view causes miss, the fix may be incomplete. But the question focuses on deletion safety: "or worse (b) sees an order in a transitional state and deletes something mid-sync that shouldn't be deleted?" Need address both.

Could a partial/stale view cause the sweep to delete an order that shouldn't be deleted? The sweep only deletes orders matching symbol+entry_magic+limit types. If the terminal hasn't synchronized, could it show an order that was already filled? It might show a stale pending order that server says filled. Removing would fail. Could it show an order that is actually not in current state? No deletion of real position. Could it show an exit hedge order with entry magic? No. Could it show an order from a previous session on same symbol+magic that was supposed to be replaced? The fix wants to delete all such pre-existing entry pendings. So any entry-magic limit order is a candidate. Is there any entry-magic limit order that "shouldn't be deleted"? Maybe one that the current reconstructed state actually wants to keep? But as argued, none are represented. So even mid-sync, deleting an entry-magic limit order is safe. The only risk is if the order is in a transitional state (e.g., about to fill/partially filled). But deleting a pending order cannot close a position; if it fills concurrently, the position remains. Could deleting an order mid-fill cause the fill to be reversed? No, broker would process one of two requests. If remove arrives before fill, order deleted, no fill. If fill arrives before remove, order filled, remove fails. No data loss. The position from fill is handled by deal events. So sweep is safe even mid-sync. But what about the broader reconstruction running mid-sync? Out of scope? The sweep itself only deletes orders. If reconstruction ran on incomplete data, it might halt or commit wrong state. But prompt says reconstruction unchanged/upstream; sweep only on success. If mid-sync caused reconstruction to think success incorrectly, that's upstream. But the sweep could amplify harm by deleting orders after a false-success reconstruction. However, the deletion of entry pendings is still not harmful because those orders are not in state. The harm would be from reconstruction committing missing positions etc, not sweep. But sweep could delete an order that would have filled and created a position that could rescue a bad reconstruction? Hmm if reconstruction committed wrong state due to incomplete view, deleting entry pendings might remove potential future layers, but the tick loop replaces them. Not harmful.

Need inspect if there is a sync gate in existing code. V2_SRE_RunSideOnInit doesn't check terminal connected or trade sync. It just gathers. The prompt says "terminal synchronized: 1 positions, 7 orders logged BEFORE the EA OnInit ran" maybe from a log in drill. They ask "does OnInit reliably run only after full sync?" We need answer: No, I believe OnInit can run before full sync? Need be precise. We can say in MQL5, OnInit is invoked when EA is attached/compiled/reloaded; the terminal's trade subsystem synchronization is asynchronous and there is no guaranteed ordering. There is no dedicated callback for "trade synchronization complete" exposed to MQL5. The `OnInit` can occur before `PositionsTotal()`/`OrdersTotal()` reflect a fully synchronized state, especially immediately after terminal start or network reconnect. Therefore a mid-sync sweep is possible. But because the sweep only removes orders matching entry magic and only on the success path, the worst mid-sync outcome is a missed deletion (duplicate persists) or a failed delete; it cannot delete a position or an exit order. The Q4 race also cannot lose a fill because a filled order leaves the pending list; a remove on a stale pending after fill fails. The only safety-critical need for a re-check would be to ensure the order is still pending and unfilled at the moment of deletion; however, even that doesn't protect against the server-side fill/remove race. No guard can fully eliminate fill/remove race. But it's benign because fill leads to a managed position via OnTradeTransaction.

But wait: Could the sweep delete an order that is "needed" by the reconstructed state in a different sense: The reconstructed layer's `entry_ticket` is set to position ticket, not pending order ticket. But what about `exit_ticket`? The pending exit orders are exit magic, not swept. Good.

Potential issue: What about an entry-magic pending order that is actually an L0 quote for the opposite side? No.

Potential issue: The sweep deletes all entry-magic pending limit orders regardless of comment. Suppose there is a manual or external system placing orders with the same magic (unlikely because magic is EA-specific). The EA can't distinguish. But that's outside code.

Potential issue: The sweep deletes entry-magic pending limit orders even if they are not "pre-existing duplicates" but are the only quote that the previous session intended. But tick loop re-places exactly one fresh pair. Is there any scenario where the tick loop's re-placement doesn't occur because the stack state after reconstruction has `last_exit_valid` true and `g_long_add_ticket`? Let's analyze all states to be sure.

We need understand Long_EnsureAddNext and Long_OnNewBar in detail for all reconstructed layer counts and last_exit_valid.

After reconstruction commit, g_long_l0_ticket = 0, g_long_add_ticket = 0 (assuming new EA instance). g_long_last_bar_time = 0 (reset in Long_OnInit). On first tick:
- Long_OnNewBar: bar_time = current bar open; g_long_last_bar_time set. Compute signal. If n==0, place L0. If n>0, call Long_EnsureAddNext.
- Long_EnsureAddNext:
  - if n <=0 or n >= InpMaxLayers return.
  - if g_long_add_ticket !=0 && OrderSelect(g_long_add_ticket) return. (0 so no)
  - add_price = Long_ComputeAddTarget()
  - if add_price <=0 return.
  - if !g_long_last_exit_valid && cap blocks new add -> return (no add placed!). This is a potential issue. If last_exit_valid is false and cap is blocking, the tick loop won't place an add. But the pre-existing pending add order was swept. So the reconstructed positions may be left without their intended next-layer quote if the cap is blocking. However, the cap gate in production is off by default (InpGbpCapThreshold=0, InpEurCapThreshold=0), but configurable. If cap threshold is set and blocks, then even before fix, the EA would not place a new add. But if a pre-existing add pending exists from before reattach, should it be kept? The cap logic says "block widening adds when |net|>N"; it's an intentional risk gate. If the cap blocks, it should not place a new add. The pre-existing add was placed before the cap condition maybe when net was lower; after reattach, should it be deleted? If it's swept and cap blocks new add, no add pending exists. This might be a behavior change: previously (before fix) the old add would remain and could fill, effectively bypassing the cap? But the cap only gates new adds, not existing pendings. The fix changes that by deleting the existing pending, then cap can block new placement. Is that harmful? It could strand positions without next-layer quote, but that's exactly the cap's purpose if configured. The question asks "Does deleting entry pendings on the success path ever strand the reconstructed positions without their intended next-layer quote in a way the tick loop does NOT then correctly re-place?" This cap scenario is one where tick loop may not re-place due to cap. But is that "harm"? The cap is an intentional gate; if it blocks, the EA doesn't want a new add. The pre-existing pending order would bypass the cap if left, so deleting it is consistent with cap. Not harm.

Also, if last_exit_valid is true, cap is not checked. So reload after a top exit will always place.

What about n==0 and L0 placement: no cap check on L0? Long_OnNewBar n==0 doesn't check cap. So L0 always placed.

What about "layer whose quote the tick loop won't re-place" due to `g_long_add_ticket` having a stale non-zero? On new instance zero. But what if OnInit is called without full reinitialization? In MT5, changing inputs triggers OnInit but globals may persist? Actually OnInit is called on input changes or recompile; global variables persist? According to MQL5, global variables of an EA are reinitialized? I think global variables persist between OnInit calls within same terminal instance? Let's recall: In MQL5, global variables are initialized at program load and can be modified; when OnInit is called again (e.g., after input change), global variables are NOT reset to zero? Actually in MQL5, global variables of an EA are reset only when program is unloaded? The documentation: "Global variables of an mql5 program are initialized with zero values at the start of its operation. They remain valid until the program is unloaded." When inputs change, OnInit is called again but global variables retain their values? I think yes, the program is not unloaded/reloaded; global variables persist. In MT5 Strategy Tester, each pass reloads. In live, clicking OK on properties triggers OnInit without reloading? It may call OnDeinit then OnInit, but global variables? I need know. This could be important: If OnInit re-runs on an already-running EA after input change, g_long_l0_ticket may hold the ticket of a currently resting L0 order that the EA placed and tracks. Then the sweep, called on "success path"? Wait if EA already has in-memory layer state, `cfg.layer_count` is set to ArraySize(g_long_layers) (non-zero if positions). If there are positions and pending orders, the SRE might attempt reconstruction? The orphaned startup state check `V2_IsOrphanedStartupState(cfg.layer_count, total_pos)` returns false if layer_count >0, even if total_pos>0. So reconstruction not attempted. So sweep not called if already have state. If layer_count==0 and total_pos>0, then maybe reconstruction. If g_long_l0_ticket has a leftover ticket value from previous running state but layers are zero? Could happen if stack flat but L0 pending exists and EA is running: layer_count=0, total_pos=0 (no positions), so SRE returns false; no sweep. If there are open positions but layer_count=0? That would mean orphaned positions; SRE attempts. Globals l0/add tickets maybe from previous state? If the EA had positions but layer_count somehow zero? Not normal. If OnInit re-runs while layers non-zero, no sweep. If OnInit re-runs after stack flat but L0 pending exists, no sweep because no positions. So sweep only in genuine orphaned startup where layer_count=0 and open positions exist; global ticket variables should be zero (new program load). But if input change triggers OnInit without unloading, layer_count might be zero? Actually if a program was running with no positions but L0 pending, layer_count=0, total_pos=0 => no sweep. So sweep not called. Thus stale g_long_l0_ticket not relevant? But if program was running with positions, layer_count>0, no sweep. If it was running and then positions closed externally, layer_count still >0 until OnTradeTransaction removes? It would remove. So by the time OnInit re-runs, if layer_count=0 and positions>0, that means orphaned; global tickets likely 0 because stack flat? Wait if stack flat, g_long_l0_ticket may be non-zero (resting L0). total_pos=0, so no sweep. OK.

But could global g_long_l0_ticket be non-zero while layer_count=0 and positions>0? No, if positions open, stack not flat, so L0 ticket should be 0 (L0 only placed when stack empty). Add ticket may be non-zero if position stack non-empty and add pending. So on an input-change OnInit with layer_count? If program running with positions, layer_count>0, no sweep. If program was unloaded, globals reset. So sweep runs only on fresh attach, no stale tracked tickets. Good.

However, in the code as provided, `V2_ApplyLongSRECommit` doesn't set g_long_l0_ticket or g_long_add_ticket. In a fresh attach, they are 0. OK.

Need consider if the sweep deletes a pending entry order that is actually represented by `g_long_l0_ticket` in a scenario where reconstruction is attempted despite layer_count>0? No, orphan check prevents reconstruction if layer_count>0. But what if layer_count is 0 because `Long_OnInit` resets arrays? It does `ArrayResize(g_long_layers,0)`? Actually Long_OnInit doesn't resize layers; but at program start arrays are empty. If input change without unload, Long_OnInit doesn't clear layers? Wait `Long_OnInit()` in provided code:
```
int Long_OnInit() {
   g_long_last_exit_valid = false;
   g_long_current_add_pips = InpAddPipsFloor;
   g_long_last_bar_time = 0;
   g_long_processed_count = 0;
   ArrayResize(g_long_processed_deals, 0);
   ...
}
```
It does NOT clear g_long_layers. So if OnInit is called due to input change while layers exist, layer_count remains >0. SRE not attempted. So no sweep. If OnInit is called due to fresh attach, layers empty. Good.

But if the EA is recompiled/reattached while terminal retains global variables? Fresh attach creates new program instance, globals zero.

Need examine "success path" in V2_SRE_RunSideOnInit: It calls V2_SRE_RunOnInitSteps3To10, which on success sets result.committed=true and returns V2_SRE_OK. Then V2_SRE_RunSideOnInit returns false. The sweep would be inserted before return false, after seq check. Good.

Now, question 1 specifically: "Exit-hedge orders carry the EXIT magic (e.g. ...904), NOT entry_magic. The filter is `magic != entry_magic -> skip`. Confirm the exit-hedge (which MatchExitOrders adopts) can NEVER match entry_magic and so is never swept. Is there any config where entry_magic == exit_magic, or where an exit order carries the entry magic?"

Need answer: The only exit order constructor is `V2_SendExitLimit` called with the exit magic (MM_LONG_V2_EXIT / MM_SHORT_V2_EXIT), which is defined as entry_magic + 2 in the shared header. There is no config path that sets exit_magic equal to entry_magic; it is derived, not input. Could an input override? Not in code. The CloseBy request uses the entry magic as the request magic, but that's not a pending order; it's a request/position-closing operation and never appears as an entry-magic pending limit order in OrdersTotal. The reconstruction's `exit_orders` are gathered by `omagic == exit_magic`, and `MatchExitOrders` only consumes those. The sweep checks `OrderGetInteger(ORDER_MAGIC) != entry_magic` skip, so exit magic orders are skipped. There is no code that places a pending exit order with entry magic. So safe.

Question 2: The long and short entry magics differ by 1 (e.g., 20260901/2). The sweep is called per side. Could long sweep delete short's pending entries? No, magic filter. Could same-magic cross-side order exist? Only if configuration defines same entry_magic for both sides, but all three files define distinct long/short constants. The shared logic defaults to 20260901/20260902 if not defined, but each production file defines them. No config input for magic. So safe.

Question 3: Cross-instance: symbol + magic required. Distinct. Safe.

Question 4: Need detailed race analysis. Let's think of exact sequence:

1. V2_SRE_GatherOpenPositionsByMagic reads positions. It is before sweep.
2. V2_SRE_GatherPendingOrders reads pending orders. Before sweep.
3. V2_SRE_GatherDealHistory reads deals. Before sweep.
4. Reconstruction runs on snapshot and commits.
5. Sweep runs.

If a pending entry order fills between step 2 and step 5:
- If fill happens before sweep's `OrdersTotal` enumeration, the order is no longer in OrdersTotal (or if stale, removal fails). The newly opened position is not in `entry_positions` used for reconstruction. However, `OnTradeTransaction` will fire (probably after OnInit) with a DEAL_ADD for the fill. `Long_HandleDealFill` will see a managed entry deal and call `Long_AppendLayer`, adding the position to the in-memory stack. This is exactly the same path as any normal fill. So no "lost fill" or corruption. There is a subtle point: `Long_HandleDealFill` for entry sets `is_reload = g_long_last_exit_valid`. If `g_long_last_exit_valid` is true (from reconstruction path state) and the filled order was a pre-existing L0 (which should only exist when stack empty), then `is_reload` would be true erroneously? Let's examine. If stack was empty before crash, there was an L0 pending, and it fills after reconstruction. At reconstruction, entry_positions empty? Wait if stack empty, there are no open positions, so reconstruction not attempted. So this scenario only occurs if there are open positions and a pending add/reload order fills after reconstruction. For a non-empty stack, pending entry order is add/reload. If it fills, `is_reload = g_long_last_exit_valid`. If `g_long_last_exit_valid` is true, it's classified reload; if false, add. That matches the order's intended semantics? The pending order's comment is V2_Add or V2_Reload. The code doesn't look at comment; it uses current last_exit_valid. Before crash, the pending order's comment was determined by last_exit_valid at placement time. If path state after reconstruction has same last_exit_valid, classification matches. If not? Reconstruction replays path state; should match. So OK. If the order was a duplicate/stale add from prior state, adding it as a layer is still managed. No harm.

Could the fill happen before the reconstruction's "broker read" validation? No, gather occurs once before. Validation uses broker_read snapshot from positions array, not live. So no mismatch.

Could the sweep delete an order that has already partially filled, and the remaining volume deletion causes the partial fill's position to be unmatched? The partial fill creates a position; the deal event appends layer using current move? Actually for a partial fill of a pending order, the deal has volume less than order volume, and the order remains with remaining volume. When OnTradeTransaction fires for the partial deal, `Long_AppendLayer(deal_price, order_ticket, position_id, is_reload)` appends a layer with volume? Layer doesn't store volume; it uses InpLotSize expected. If partial fill volume is less than InpLotSize, the layer is treated as full. But this is existing behavior for any partial fill, out of scope. The sweep deleting the remaining volume could prevent a second partial fill that would create another layer. Not harmful? Maybe if partial fills are possible, the reconstructed state should account for them; but spec expects volume mismatch halt. Out of scope.

Potential race: The sweep deletes a pending entry order; after deletion, OnTradeTransaction receives a DEAL_ADD for that order's fill that occurred before deletion but whose deal event arrives later. Then Long_HandleDealFill will append a layer for a position that exists. That's correct. If the order was deleted before fill, no deal arrives. If the fill occurred before deletion but terminal's order list still showed it and remove succeeded somehow? Can a remove succeed on an already-filled order? No. If it somehow removes the order record after fill, the position still exists. Deal event appends. No loss.

Thus Q4 safe. But they ask "If safe, confirm, and confirm whether any guard (e.g. re-select and verify still-pending before delete) is warranted for the Q4 race." We can say no guard is necessary for Q4 because the fill/remove race cannot lose a fill: a fill creates a broker position independent of the order record, and the deal event is the source of truth. But we can mention adding a re-check `OrderSelect(ticket)` and `OrderGetInteger(ORDER_STATE) == ORDER_STATE_PENDING` immediately before sending REMOVE would reduce stale-order remove attempts and avoid deleting an order that just transitioned to filled in the local cache, but it does not eliminate the server-side race and is not safety-critical. Also note that a re-check cannot prevent a fill between the check and the remove, but that's fine.

Question 5: Need see if any layer quote won't be re-placed. We identified cap block. Also `InpMaxLayers` block. Also if stack depth >= max, no add needed. Also if stack non-empty and `Long_ComputeAddTarget` returns 0? It returns 0 only if n<=0. For n>0, anchor positive, step positive, so >0. Unless prices zero? No. So add placed unless cap blocks or max. L0 placed unless signal copy fails or `MathExp` gives invalid? But that's environmental. If signal fails on first tick, it will retry next tick. So eventually.

What about if reconstructed stack has `g_long_last_exit_valid == true` and n>0? Long_ComputeAddTarget uses anchor = last_exit_price and step_pips = V2_ADD_PIPS_FLOOR. This places a "reload" pending even if there is already an existing pending add? But after sweep no existing. This is correct: a top exit happened, so next quote is reload. If a pre-existing reload order was swept, tick loop re-places.

What about if reconstructed stack has `g_long_last_exit_valid == false` and n>0 but `current_add_pips` maybe > ceiling? Replay caps at ceiling. OK.

What about if n==0 and `g_long_last_exit_valid` true? Is that possible? After stack flat, V2_OnOwnStackFlat sets last_exit_valid=false. In reconstruction, replay sets last_exit_valid false if stack empty? The replay path state: At the end, if stack empty, current_add_pips floor; last_exit_valid may remain true? Let's check V2_SRE_ReplayPathDependentState: On removal, if was_top, sets last_exit_valid true; after removal, if stack empty, it sets current_add_pips floor but does NOT set last_exit_valid false! Wait there's no `if ArraySize(stack)==0 last_exit_valid=false` in the replay. Let's inspect:
```
if(events[i].is_removal) {
   ...
   if(was_top) { last_exit_price=...; last_exit_valid=true; } else { last_exit_valid=false; }
   RemoveStackAt...
   if(ArraySize(stack)==0) current_add_pips=floor;
   continue;
}
...
```
If stack becomes empty after a top removal, last_exit_valid remains true. But production Long_RemoveLayerAt calls V2_OnOwnStackFlat which if layer_count==0 sets last_exit_valid=false. The replay does not mirror that? Actually spec §2.3 says reset only on full flat? Wait production logic: `V2_OnOwnStackFlat(g_long_last_exit_valid, ArraySize(g_long_layers));` sets `if(layer_count == 0) last_exit_valid = false;`. But `Long_RemoveLayerAt` sets last_exit_valid=true if was_top, then calls V2_OnOwnStackFlat which sets false if stack empty. So on full flat, last_exit_valid false. The replay's path state may incorrectly leave true on full flat. This is upstream SRE, out of scope? But for sweep safety and tick loop re-placement, if reconstructed stack empty but last_exit_valid true, and there are no positions, reconstruction wouldn't happen because no positions. If stack non-empty after reconstruction, last_exit_valid could be true if top was removed but stack not empty; that's valid reload state. If stack empty and positions? No positions means no reconstruction. So not relevant. If reconstruction has n>0, last_exit_valid true means a non-top? Wait if stack non-empty, last_exit_valid true only after top removal; stack still has lower layers. That's a valid reload state. Tick loop will place reload. Good.

But there is another issue: In production, after a top removal from a non-empty stack, `Long_RemoveLayerAt` sets last_exit_valid=true and then calls `Long_EnsureAddNext` immediately. In the reconstructed state, after sweep, the tick loop will place the reload on next bar. Safe.

What about a stack with n=0 and pending L0? No positions -> no reconstruction -> no sweep. So not relevant to sweep.

Thus Q5 safe, except cap block as intentional.

Question 6: Need decide about sync. Let's research from memory: In MQL5, `OnInit` is called when an EA is attached to a chart, after the terminal has loaded the program. There is a known issue: if the terminal is started, EAs attached to charts in profiles may be initialized before the trader server connection is established or before the account is known. The `OnInit` can run with `TerminalInfoInteger(TERMINAL_CONNECTED) == false`. Trade functions like `OrdersTotal` might return 0 or stale data. However, the terminal might still load EAs and call OnInit after synchronization? Hmm.

Let's reason from MT5 architecture: The MetaTrader 5 terminal has a "Market Watch", "Trade" tab. When you start the terminal, it loads charts and EAs. It may connect to the trade server asynchronously. The client terminal receives account data, positions, orders during synchronization. If an EA is attached and OnInit runs before synchronization, `PositionsTotal()` returns 0 even if there are positions. The terminal logs "terminal synchronized: 1 positions, 7 orders" maybe from a custom function after `OnInit`? The prompt says logged BEFORE EA OnInit ran. That suggests there is a terminal-level log "terminal synchronized" that happens before EA init? Maybe in MT5, the terminal ensures that by the time any EA's OnInit is called, the trade server state is synchronized? Let's recall MQL5: There is an `OnInit` event after the expert is loaded. The terminal may not call OnInit until the trade server is connected? The docs for `MQL5` "Program startup" say: "When starting the program, the OnInit handler is called. The program is loaded only after successful connection to the trade server and receiving of the trade account information..." Is that true? I'm not certain. Let's recall practical advice: Many EAs check `TerminalInfoInteger(TERMINAL_CONNECTED)` in OnInit and return INIT_FAILED if not connected. That suggests OnInit can be called when not connected. But maybe that's for network connection, not trade sync. There is a known `OnTradeTransaction` event with `TRADE_TRANSACTION_POSITION_ADD` etc. Some developers use `MQL5` "OnInit is called every time an EA is attached to a chart, when the chart symbol/period changes, on input changes, on recompile, on terminal restart." If terminal restarts, EAs are initialized after the symbol history and account data are loaded? Hmm.

Given the prompt specifically asks "does OnInit reliably run only after full sync, or can it fire mid-sync?" We need provide a decisive answer. We can say: There is no documented guarantee in the MQL5 language that OnInit is deferred until the trade subsystem's position/order cache is fully synchronized; the only documented ordering is that OnInit precedes OnTick/OnTradeTransaction. In practice, after a reconnect OnInit can observe a partial cache. Therefore a sync gate is advisable if a broker-side sweep must see the complete order book. However, for this specific sweep, the deletion set is correctly constrained by symbol+magic+limit type, and a mid-sync stale/partial view cannot cause deletion of a position or non-entry order. The worst mid-sync outcome is a missed deletion or a failed delete. The Q4 race is similarly benign. But if the goal is to actually eliminate the duplicate-order bug (not just deletion safety), a sync-complete gate may be warranted to ensure the sweep doesn't silently miss the very orders it is meant to remove. The prompt says "(a) misses an entry pending that IS there (leaving a duplicate -- benign, tick loop recovers)" Wait they call it benign but it's the original bug. They say "leaving a duplicate -- benign, tick loop recovers" Actually if a duplicate remains, tick loop doesn't recover; the duplicate is the problem. But maybe they mean for deletion safety, missing is benign (no harm) though not effective. We can note that.

Need see if there is a guard to gate on sync-complete. What API? `TERMINAL_TRADE_ALLOWED` maybe true when trading allowed, but not necessarily full sync? `TERMINAL_CONNECTED` indicates connection to trade server, not order cache sync. `MQLInfoInteger(MQL_TRADE_ALLOWED)` indicates whether trade allowed for this EA? There is no explicit "synchronized" flag in MQL5. One can use `OnTradeTransaction` or `OnTrade` to get events when positions/orders update, but in OnInit you cannot wait. You could wrap the sweep until `TERMINAL_CONNECTED` and maybe `OrdersTotal()` stable? There is no stable API. Some use `HistorySelect`? Not needed.

But the prompt says "The drill showed `terminal synchronized: 1 positions, 7 orders` logged BEFORE the EA OnInit ran -- does OnInit reliably run only after full sync, or can it fire mid-sync?" They may want us to infer that logs showed sync before OnInit, maybe evidence that OnInit runs after full sync. But they ask "or can it fire mid-sync?" We should not assume. Need answer based on known MQL5 behavior: In MT5, EAs are initialized only after the terminal has synchronized trading data? Let's search memory: When you attach an EA, the terminal first loads history? There is a "Trade" tab with "No data" until connection. The EA's `OnInit` is called after a successful chart load? I have seen EAs with `OnInit` that return `INIT_FAILED` if not connected. But that may be because terminal can be offline. For reconnection, the chart remains, and OnInit might be triggered by recompile? The terminal may call `OnInit` immediately on attach even if not connected. If it were guaranteed that OnInit only runs after sync, there would be no need for connection checks. Many EA templates include:
```
if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return(INIT_FAILED);
```
So yes, OnInit can run when trade not allowed/connected. Trade sync is part of connection. Thus mid-sync possible.

But if the terminal is started and EAs auto-loaded, maybe the platform waits for sync before starting EAs? I'm not entirely sure. The safest audit answer: It is not guaranteed; no documented guarantee; therefore a re-select/re-check before each remove is prudent but not strictly required for safety.

Need consider another potential harm: The sweep deletes *all* entry-magic pending limit orders, including those that are not duplicates but are actually the currently tracked `g_long_add_ticket` if reconstruction happened while globals non-zero due to an OnInit re-run? We argued no. But let's examine if `V2_IsOrphanedStartupState` can be false while layer_count >0 and total_pos>0? It returns true only if layer_count==0 && broker_position_count>0. If layer_count>0, false, no sweep. So no.

What if layer_count==0 and total_pos>0 but the pending entry order is the only thing that can open a layer and there are exit-magic positions? Precheck exit magic open halts, so no sweep on halt. If only entry positions and pending entries, sweep deletes pending. OK.

What if reconstruction succeeds with entry positions count n, and there is a pending entry order that the previous session placed as the next add. The sweep deletes it. But what if the tick loop's `Long_EnsureAddNext` sees `g_long_add_ticket !=0`? It's zero. Places. OK.

Potential issue: The tick loop uses `g_long_last_bar_time` to throttle to once per M5 bar. If OnInit occurs, first tick processes. But if the EA is attached on a different symbol? No.

Potential issue: The sweep removes orders one by one. If a pending entry order fills during the sweep after being selected but before `OrderSend` removal, the remove may fail with retcode "No money" etc. The deal event will append. OK.

Potential issue: `OrdersTotal` enumeration while removing orders. They iterate downward, so safe. If an order is filled/removed by external during loop, `OrderGetTicket(i)` might return 0? They handle ticket==0 continue. `OrderSelect` may fail. OK.

Potential issue: If there are multiple pending entry orders with same magic and symbol (the duplicate problem itself), the sweep deletes all. Good.

Potential issue: The sweep doesn't check `ORDER_STATE` or `ORDER_TIME_SETUP`; it deletes even expired? If expired, not in OrdersTotal. OK.

Potential issue: The sweep doesn't check if the order is a child of a position? No.

Potential issue: The sweep doesn't check `ORDER_FILLING` or `ORDER_TYPE_FILLING`; no.

Potential issue: It may delete entry magic orders that are actually "stop" orders? No, only limit types. If there were buy stop with entry magic, it remains. Not harm.

Potential issue: It may delete a BUY_LIMIT order with entry magic that is actually a manually placed order by the user on the same symbol, if the user used the same magic (unlikely). Out of scope.

Need think about "otherwise cause harm" beyond deletion of needed order. Could sweeping cause API counter increase and possibly hit daily API limit? It deletes at most a few orders. V2_OrderSendCounted increments counter. If there are many entry-magic pending orders (e.g., duplicates across all instances), sweep could send many remove requests. But broker limit ~2000/day; duplicates likely small. Not harm.

Could the sweep fail to remove and still increment API counter, contributing to rate limit? Minor.

Could the sweep remove an order and then the tick loop immediately places a new one, causing a temporary gap in resting quotes? Yes, between removal and placement there is no pending order. If the market spikes to the old order price in that interval, the EA misses an entry. But the old order was a duplicate/stale; the EA's state didn't include it. Is that harm? It could miss a profitable entry that would have occurred if the old order remained. But the purpose of the fix is to replace duplicates with exactly one fresh pair. There is an unavoidable gap between delete and re-place. The tick loop places on the next tick, which is immediate (milliseconds). So gap minimal. If the market moves exactly then, no fill; but the EA would have placed a new order at a different price anyway. Not a state inconsistency.

Could the sweep delete an order whose price is more favorable than the new L0, causing loss of queue position? Yes, any requote loses queue priority. But the old order was not represented in state; if it filled, it would create an unmanaged layer? Actually OnTradeTransaction would manage it, but the state's `g_long_l0_ticket` was zero, so the fill would be appended as a layer. It would be managed. So deleting it could prevent an unwanted extra layer? Hmm.

Let's examine a specific scenario: Previous session had stack empty, L0 pending at price P. It crashes. On reattach, no positions (stack empty), so SRE doesn't reconstruct because no positions. Tick loop sees no L0 ticket, places new L0 at price Q. Old L0 remains at P. Now there are two L0 orders. If price hits P, old fills -> position opens, OnTradeTransaction appends layer. Then the EA has one position and one L0 at Q still resting. The tick loop, seeing n>0, will not place L0; it will place add? `Long_EnsureAddNext` will place an add because g_long_add_ticket=0. This would create an extra layer (old L0 position + new add) even though the state only has one layer. This is the duplicate problem. The fix sweeps old L0 on reconstruction success. But in this scenario no reconstruction, so fix doesn't apply. Is this in scope? The prompt says "pre-existing ENTRY-side pending quotes ... are consistency-checked and then left on the broker. The tick loop, seeing no L0 quote in its rebuilt state, places a fresh one -> DUPLICATE resting quotes (observed across all 3 instances)." This scenario with no positions is exactly the duplicate L0. But the fix only on reconstruction success path would not fix it. Wait maybe reconstruction is attempted even when no positions? Let's re-read V2_SRE_RunSideOnInit: It gathers entry_positions and exit_positions. `total_pos = ArraySize(entry_positions)+ArraySize(exit_positions)`. If layer_count=0 and total_pos=0, V2_IsOrphanedStartupState returns false; returns false without reconstruction or sweep. But if there are no open positions but pending entry orders exist, are they included in total_pos? No, only positions. So no reconstruction. Thus the fix as described would not solve the flat duplicate L0 case. But maybe in the observed Tier 2 drill, there were open positions and duplicates were add/reload, not L0. The prompt says "no L0 quote" but maybe "L0 quote" generic. We should note this? The question is narrow: "Can this sweep, as written, EVER delete an order that the reconstructed state still needs, or otherwise cause harm?" We can mention that the sweep only runs on reconstruction success; if reconstruction isn't attempted (flat but pending L0), the sweep doesn't run, so no deletion harm. But the fix may be incomplete for the exact duplicate-L0 case. However, the prompt says "Tier 2 live drill found: SRE reconstructs in-memory layer state from open POSITIONS + matched exit orders + deal replay, but pre-existing ENTRY-side pending quotes ... are consistency-checked and then left on the broker." This implies there were open positions for reconstruction. The duplicates could be Add/Reload quotes on non-empty stacks, not L0. The phrase "no L0 quote in its rebuilt state" may be a mistake. We should be cautious: The single question includes Q5 "is there a layer whose quote the tick loop won't re-place?" We can say no for non-empty stacks. For empty stack, if there are no positions, no sweep; if there are positions, stack isn't empty. So within sweep's scope, safe.

Need consider if sweep runs on success path for a side with open positions and an L0 pending? Consistency check would halt if stack non-empty and L0 pending (HALT_06). If stack empty but there are open positions impossible. So no L0 pending on success path with positions. Thus the sweep on success path only deletes Add/Reload orders, not L0? Wait if stack empty and no positions, no sweep. If stack non-empty, pending entry should be add/reload, not L0. So the sweep actually deletes add/reload orders, not L0. The original duplicate "L0" may occur only when flat, which is not fixed. Hmm.

But maybe the "success path" includes a side with no entry positions but exit positions? No, if entry_n==0, halt. So no.

Let's verify pending consistency in success: `V2_SRE_CheckPendingEntryConsistency(pending_entries, entry_n, side_direction)`. If entry_n==0, it requires l0_count<=1 and add_reload_count=0. So if stack empty and there is an L0 pending, pending_halt OK. But if entry_n==0, earlier in V2_SRE_RunSideOnInit:
```
if(ArraySize(entry_positions) == 0) {
   result.halt_reason = V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN;
   ...
}
```
Wait this is in V2_SRE_RunSideOnInit after precheck. It treats entry_n==0 as HALT_01_EXIT_MAGIC_POSITION_OPEN even if there are no positions at all? Let's look:
```
const int total_pos = ArraySize(entry_positions) + ArraySize(exit_positions);
if(!V2_IsOrphanedStartupState(cfg.layer_count, total_pos))
    return false;
...
if(ArraySize(entry_positions) == 0) {
    result.halt_reason = V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN;
    result.side_halted = true;
    return ...
}
```
If total_pos>0 but entry_positions==0 and exit_positions==0? That can't happen because total_pos = sum. If total_pos==0, early return false before entry_positions check. So entry_n==0 only when total_pos>0 due to exit_positions>0. So no flat L0 sweep.

Thus the fix may be incomplete for flat L0, but out of scope? Not asked. We can mention in conclusion "within the sweep's actual execution domain (successful reconstruction with open positions), no L0 is present; it deletes only add/reload pending entry orders." But the fix description says sweep all entry pendings, so if there were L0 on a non-empty stack, consistency would halt, so no sweep. If there were L0 on empty stack, no reconstruction. So sweep never sees L0? Unless there is a wrong-direction L0 but still only one entry pending? For non-empty stack with L0 and also positions, pending_halt would be HALT_06, so sweep not called. Therefore the sweep effectively only deletes add/reload orders. But the function doesn't filter comment, so if it were called in a state with L0, it would delete. But in practice on success path it won't encounter L0. Good.

Need examine if the sweep could delete an order that `V2_SRE_GatherPendingOrders` classified as pending entry but `V2_SRE_CheckPendingEntryConsistency` considered valid. On success, pending_entries count:
- If entry_n >0: l0_count=0, add_reload_count <=1. So pending entries are add/reload. The sweep deletes all entry-magic limit orders, including this add/reload. Good.

Need think about "entry-magic pending limit orders" vs "entry_magic" parameter type long. In MQL5, `OrderGetInteger(ORDER_MAGIC)` returns long. Compare to long. OK.

Potential issue: The sweep uses `OrderGetString(ORDER_SYMBOL) != symbol` without ensuring `symbol` non-empty. cfg.symbol is _Symbol, non-empty. OK.

Potential issue: The sweep uses `OrderGetTicket(i)` but doesn't ensure i is valid after external order removal. OK.

Potential issue: It doesn't check `res.retcode` after `V2_OrderSendCounted`; but removal success not needed for safety? If it returns false due to order already gone, no harm. If it returns true? It only counts swept if true. But if retcode not DONE? V2_OrderSendCounted returns OrderSend return bool. OrderSend returns true if server accepted? It can return true with retcode not DONE? In MQL5, OrderSend returns true if request accepted? Actually returns true if placed/processed; res.retcode indicates details. If true but retcode e.g. TRADE_RETCODE_DONE. If retcode error? It may still return false. Not important.

Need consider if the sweep should verify `OrderSelect(ticket)` immediately before remove to ensure it's still pending. In MQL5, `OrderSend(TRADE_ACTION_REMOVE)` itself will fail if order not found. No harm. But a re-select could also inspect ORDER_STATE and skip if not `ORDER_STATE_PENDING` or `ORDER_STATE_PARTIAL`? However, if PARTIAL, removing remaining is acceptable? Maybe not. If an order is PARTIAL, it's still current; removing it cancels remaining. If partial fills are possible, the EA's layer management might be confused. But this is an edge case; the system uses InpLotSize=0.01 and broker may support partial? Usually no. Out of scope.

Could the sweep delete an order that is "needed" because it is part of a closeby pairing? No, closeby tasks use positions, not pending entry orders.

Could the sweep delete an order that belongs to a strategy on a different time frame? No.

Need answer with "safe, with caveats". The single question asks "Can this sweep, as written, EVER delete an order that the reconstructed state still needs, or otherwise cause harm?" We need say "No, as written it cannot delete a needed order; the magic/symbol/type filters make it impossible to touch exit orders or other instances/sides. The fill and reconnection races are benign. A guard is not required for safety, though a pre-delete re-check is harmless." But also note maybe "otherwise cause harm" via incomplete fix? The question wants pressure-test. We can mention the incomplete coverage of flat L0 as a non-harm issue? The wording "or otherwise cause harm" could include if sweep deletes order that tick loop won't re-place. We'll include cap/max caveat: There is an intentional case where the tick loop will not re-place an add: when `InpMaxLayers` is reached, or when the cap gate blocks. In those cases deleting the pre-existing pending order may leave no resting add. But those are intentional risk gates; and if a pending add exists at max layers it violates invariants. The cap gate is the only meaningful caveat. Should we flag it as a finding? The question asks confirm safe. If cap threshold configured, deleting an existing add and preventing re-placement could strand positions without next quote. Is that "harm"? Let's analyze more.

The cap gate only applies when `!g_long_last_exit_valid`. That means the next add is a "widening add" (not reload). The cap is designed to block widening adds when net exposure exceeds threshold. If the cap is active and blocks, the EA intentionally does not place a widening add. The pre-existing add order is a widening add from before. Should the sweep delete it? If the order remains, it could fill and increase net exposure beyond threshold, bypassing the cap. The cap was introduced for risk; sweeping it enforces the cap. Leaving it would be a risk bug. So deleting it is not harm, but a behavior change: the pre-existing order that was already on the book is cancelled, whereas the cap usually only gates new placements. If the order was there before the cap state changed, it might have been allowed when placed. But after reattach, the EA's state is rebuilt; the cap should apply to all future adds. The fix's sweep makes it comply. Not harm.

What if `g_long_last_exit_valid` is true and cap not checked; add placed. OK.

What if `InpMaxLayers` reached and there is a pending add? As argued impossible if invariants hold; but if it happens due to inconsistent external state, the pending order's fill would exceed max layers. The EA wouldn't want it; deleting is good. So no harm.

What about `Long_EnsureAddNext` may not place if `g_long_add_ticket !=0 && OrderSelect(g_long_add_ticket)` returns true for a ticket that remains in OrdersTotal from a previous tracked order. But after fresh attach, zero. If OnInit re-run, sweep not called. OK.

Need consider "reconstructed state still needs" in terms of entry order tickets used by the exit-order matching? Exit-order matching uses only exit magic. No.

Now, we need craft final answer with structure. The user likely expects a formal audit response. We should be exhaustive but concise enough. Desired oververbosity 5. Need include verdict, per question analysis, edge cases, recommendation.

Let's outline:

- Verdict: As written, the sweep cannot delete an order that the reconstructed state depends on. It is safe with respect to Q1-Q5; Q6 mid-sync cannot cause deletion of a position or exit order, only missed/deferred deletes. A pre-delete recheck is optional, not required for safety.

- Q1 magic isolation: Exit magic is entry_magic + 2 via `#define MM_LONG_V2_EXIT (MM_LONG_V2 + V2_EXIT_MAGIC_OFFSET)` in logic. All production pending exits are created only in `V2_SendExitLimit` with exit magic. CloseBy requests may use entry magic but are not pending limit orders. No config path can make entry==exit. Sweep's `magic != entry_magic` skip protects.

- Q2 side isolation: Entry magics are distinct per side (e.g., 20260901/2, 20260911/2, 20260921/2). The sweep is invoked per side with its entry_magic; it cannot see the other side's magic. No code creates a cross-side pending order with the same magic. The long/short type differences (buy_limit vs sell_limit) are irrelevant because magic filter already isolates.

- Q3 multi-instance: Each instance has a distinct symbol and magic pair. Sweep requires both ORDER_SYMBOL == cfg.symbol and ORDER_MAGIC == entry_magic. No cross-instance deletion.

- Q4 fill race: The only thing the sweep can remove is a pending order in OrdersTotal. A filled order is a position; it is not in OrdersTotal. If a fill occurs between gather and sweep:
   * If the terminal cache updates before enumeration, the order isn't seen -> no deletion.
   * If the cache is stale and the order is still seen, TRADE_ACTION_REMOVE will fail or remove a ghost; it cannot delete the position.
   * The fill's DEAL_ADD is handled by Long_HandleDealFill after OnInit, which appends the new layer. So no lost fill or state corruption.
   * A partial fill leaves a position and possibly a remaining order; deleting the remainder is consistent (the partial position is still dealt with by OnTradeTransaction). Note: partial fills are outside normal assumption.
   * Therefore no recheck/guard is strictly required. Optional re-select + verify ORDER_STATE before remove would reduce stale-order remove attempts but cannot close the server-side fill/remove race; it's not a safety control.

- Q5 re-place coverage: After successful commit, `g_long_l0_ticket` and `g_long_add_ticket` are zero (fresh attach), and layer arrays are built from reconstruction. On first tick:
   * If stack non-empty (the only case reconstruction succeeds with positions), `Long_OnNewBar` calls `Long_EnsureAddNext`; since no tracked add ticket exists, it computes the next add/reload price and places it (unless max layers or cap gate blocks; those are intentional).
   * If stack empty, reconstruction would not have been attempted because no open positions -> sweep not called; so the L0-only duplicate case is outside the fix's actual execution path. (This is a completeness caveat, not a deletion-safety issue.)
   * Thus no layer whose quote is needed by reconstructed state is stranded, except intentional cap/max blocks.

- Q6 sync: OnInit is not guaranteed to run only after full trade-subsystem synchronization; no MQL5 callback/flag guarantees cache completeness. A mid-sync sweep can therefore see a partial order list. Consequences:
   * Miss an entry-magic pending -> duplicate remains (the original issue persists, but no deletion harm).
   * See a stale entry-magic pending that no longer exists -> OrderSend remove fails; no harm.
   * It cannot see an exit order as entry magic; cannot delete a position.
   * If a sync gate is desired for effectiveness, you could gate the sweep on `TerminalInfoInteger(TERMINAL_CONNECTED) && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)` and perhaps a small retry loop, but there is no formal "order cache synchronized" API. For safety alone, not required.

- Overall: Safe. Suggested optional hardening: in the loop, before remove, re-select and verify `ORDER_STATE == ORDER_STATE_PENDING` and magic/type again; also log `swept`. This is defense-in-depth, not a fix for a demonstrated deletion hazard.

Need also mention "same-magic cross-side order could exist if configuration error" but no config. Maybe "No input allows magic configuration; values are compile-time constants in each file. A corrupted build with duplicate magic would be a separate deployment error, not a logic flaw." Good.

Need be careful about "exit-hedge (which MatchExitOrders adopts)" phrase. We can say "The 'exit orders' consumed by MatchExitOrders are gathered only from `omagic == exit_magic` in V2_SRE_GatherPendingOrders. They are never entry-magic. Even if a broker order were mislabeled, the sweep's type filter includes BUY_LIMIT/SELL_LIMIT, which are exactly the types exit orders use too, so the magic filter is the only separator — and it is correct."

Wait exit orders use both BUY_LIMIT and SELL_LIMIT (long exit SELL_LIMIT, short exit BUY_LIMIT). The sweep filters type to limit, but magic excludes exit. Good.

Potential subtlety: `V2_SRE_GatherPendingOrders` gathers exit orders by `omagic == exit_magic`, but it sets `exit_orders[n].direction = side_direction`, not opposite. That's upstream. Not relevant.

Need decide whether to mention that the sweep deletes all entry-magic limit orders, including ones that might be "L0" if called on a flat side. But on success path, not. We can include as completeness caveat.

Need consider if there is any "order that reconstructed state still needs" in the exit order list? The sweep deletes only entry magic, so no.

Let's craft final answer.

But before final, let's revisit the exact code in prompt: "Called once, on the success path only (after the halt-path early-return), with cfg.symbol and cfg.entry_magic." In V2_SRE_RunSideOnInit, after `const V2SREHaltReason seq = ...; if(seq != V2_SRE_OK) { ... return ...; } return false;` If sweep inserted after seq check, it runs after `result.committed=true`. Good.

Could there be a case where seq == V2_SRE_OK but result.committed=false? In V2_SRE_RunOnInitSteps3To10, V2_SRE_OK only returned if not halted and after commit; so committed true. Good.

Now, let's think if the sweep could delete an order that the reconstruction's pending-consistency check had identified as "add/reload" but the tick loop's add placement would be blocked by `V2_GbpCapBlocksNewAdd` and thus the positions remain without intended next-layer quote. We said cap intentional. But the question "strand the reconstructed positions without their intended next-layer quote in a way the tick loop does NOT then correctly re-place?" The cap is a reason it doesn't. Should we flag as "not a deletion safety issue but a behavior change under cap config"? The prompt asks "If safe: confirm, and confirm whether any guard is warranted for Q4 race." We can mention the cap caveat and say it is intentional risk gating, not an unsafe deletion. Also if cap threshold is 0 (default off), no issue.

Need maybe mention `InpMaxLayers`: if stack depth == max, no add should be pending by invariant. If a pending add exists due to crash, it shouldn't; deleting it is safe. Good.

Let's think about "duplicate resting quotes observed across all 3 instances" — if sweep only runs on reconstruction success, and reconstruction success with open positions, then the duplicate is an add/reload. Does deleting add/reload cause tick loop to place new add? Yes. But could there be two add/reload orders? Consistency check halts if >1. So sweep deletes at most one. If there were duplicates, reconstruction would halt, not sweep. Wait! This is critical. The original problem observed duplicate resting quotes. But the reconstruction's `V2_SRE_CheckPendingEntryConsistency` would halt if there is more than one pending add/reload on a non-empty stack or more than one L0 on empty. The Tier 2 drill found duplicates after a *successful* reconstruction? How could duplicates exist if consistency check allows only one? Maybe because the tick loop places a fresh one after reconstruction, creating the second duplicate after the consistency check. The consistency check ran before the tick loop placed the fresh one. So at reconstruction time there was only one pending order; after reconstruction, tick loop placed another -> duplicate. The fix sweeps the pre-existing one so tick loop's new one is the only one. Good. So sweep deletes exactly the one pre-existing pending entry order that passed consistency. No multiple pending at sweep time. Good.

What if the tick loop already ran before sweep? Not possible; sweep in OnInit before OnTick.

Could the sweep delete an order that the reconstruction's pending-consistency check considered valid and that represents the "next layer" that should be kept rather than replaced? The design decision is to delete and let tick loop re-place. Safe.

Potential issue: The sweep deletes the pre-existing pending order but does not cancel/replace any tracked `g_long_add_ticket` because none. If there is a tracked add ticket from a previous run in a re-OnInit scenario, sweep not called. OK.

Now, let's think about MQL5 specifics for `OrdersTotal` and `OrderGetTicket` during OnInit. Some sources say `OrdersTotal()` returns only orders for the current symbol? Let's verify. In MQL5, `OrdersTotal()` returns "Number of current orders" from the terminal's trade server. There is no symbol filter; you must filter via `OrderGetString(ORDER_SYMBOL)`. Documentation: "OrdersTotal returns the number of current active orders in the terminal." It doesn't say current symbol. So filter needed; present. Good.

Potential issue: `OrderGetTicket(i)` can be used only after calling `OrderSelect`? Actually `OrderGetTicket(i)` returns ticket of order by index; no prior select needed. Then `OrderSelect(ticket)` selects. Good.

Potential issue: If `OrderSelect(ticket)` succeeds but then `OrderGetString(ORDER_SYMBOL)` called without first selecting? They did select. Good.

Potential issue: If the order is a market order? Pending entry orders are limit; filter type. Good.

Potential issue: The sweep doesn't exclude `ORDER_STATE_CANCELED` etc because those aren't in OrdersTotal. OK.

Now, let's consider if there is any way an exit order carries the entry magic due to `req.magic = closeby_magic` in `V2_ProcessCloseByQueue`. In MQL5, `TRADE_ACTION_CLOSE_BY` request has a `magic` field that becomes the magic of the closing deal/order? The close-by operation creates deals (out by) with the magic specified? The spec §2.2 says "a CloseBy request is sent with entry magic, so the deal closing the hedge leg can also carry entry magic." Indeed! This is important. In spec §2.2 anchor-finding: "a CloseBy request is sent with entry magic, so the deal closing the hedge leg can also carry entry magic; tracking by raw magic corrupts the walk." So CloseBy deals can carry entry magic. But those are deals, not pending orders. The sweep only sees current pending orders. Could a CloseBy request create a pending order? No. So safe. But in Q1, "exit-hedge orders carry the EXIT magic" — Actually CloseBy deals can carry entry magic, but they are not orders. The prompt specifically says "Exit-hedge orders carry the EXIT magic (e.g. ...904), NOT entry_magic." Need not challenge.

Could there be pending orders created as a result of CloseBy? No.

Potential issue: The exit limit orders that MatchExitOrders adopts may be resting exit orders with exit magic. The sweep doesn't touch. Good.

Potential issue: The sweep deletes entry-magic pending orders on a side where reconstruction succeeded, but what if that side's entry_magic is also used as a closeby_magic for the opposite side? No.

Now, let's evaluate Q6 more rigorously. The prompt: "The drill showed `terminal synchronized: 1 positions, 7 orders` logged BEFORE the EA OnInit ran -- does OnInit reliably run only after full sync, or can it fire mid-sync? If mid-sync is possible, does the sweep need to gate on a sync-complete condition?"

We need answer maybe: "There is no reliable guarantee; the only robust answer is to not depend on it." But if we say OnInit can fire mid-sync, is that true? Let's try to recall actual MT5 behavior. I have used MT5: If you attach an EA while terminal is offline, OnInit returns INIT_FAILED? Actually if no connection, `OnInit` can be called and `MQL5` functions like `SymbolInfoDouble` may still work with cached data, but `OrderSend` fails. The terminal has a "Trading is disabled" state. So yes.

But "full sync" of positions/orders after reconnect: The terminal may show "Trade: ..." and an EA can be initialized before the trade tab populates. There is a known function `OnTradeTransaction` with `TRADE_TRANSACTION_ORDER_ADD` etc that fires during synchronization? Some EAs use `OnTrade` to catch sync. There is no documented "synchronization complete" event. So a mid-sync sweep is possible. We'll state that.

However, the prompt says "terminal synchronized: 1 positions, 7 orders" logged BEFORE EA OnInit ran, maybe they want us to confirm that in MT5, OnInit is called after synchronization. Let's search memory: In MT5, the terminal log has "terminal synchronized: 1 positions, 7 orders" when the trade server sends a "trade sync" message. EA initialization might be delayed until after synchronization? Actually the terminal loads EAs from profiles at startup after connecting? I'm not sure. In MT4, experts are loaded after history synchronized? In MT5, charts are loaded after terminal start, but EAs may be initialized before the first tick. There is a sequence: "loading history", "synchronization done", "EA OnInit". The prompt's observation might be evidence that in this runtime, synchronization completed before OnInit. But it asks "does OnInit reliably run only after full sync, or can it fire mid-sync?" We can say "The single drill observation is not a guarantee; the MQL5 language does not promise this ordering." That is safe.

If a sync gate is needed, how to implement? Could check `TerminalInfoInteger(TERMINAL_CONNECTED)` and maybe `TERMINAL_TRADE_ALLOWED`, and retry with `Sleep` in OnInit? Sleeping in OnInit is discouraged but possible. Or use `EventSetTimer`? But not needed. We can say "Given the deletion set is benign, no safety-critical gate is needed; if you want deterministic duplicate removal, a gate/retry loop would be needed, but no official API exists." Good.

Need also mention `OrdersTotal()` and `PositionsTotal()` can be zero during sync, causing reconstruction to not attempt and sweep not run. That means the fix may silently not fix duplicates after reconnect. But that's completeness, not deletion harm.

Now, let's think if there is any scenario where sweeping an entry-magic pending order could "delete an order that the reconstructed state still needs" because the reconstructed layer's `exit_ticket` happens to equal the pending entry ticket due to ticket collision? Tickets are unique across order types; an entry pending order and an exit pending order cannot share a ticket. An entry pending order could have the same ticket as a position? No, tickets unique across all orders/positions/deals? In MT5, tickets are unique across all operations? Positions have their own ticket numbers but could overlap with orders? I think order tickets and position tickets are in the same sequence? Actually in MT5, order tickets and position tickets are separate? A pending order when filled becomes a deal and a position with a new ticket, while the order ticket remains in history. They are different. So no collision.

Potential issue: The reconstructed layer `exit_ticket` may be 0 (NEEDS_PLACE). The tick loop/audit will place exit limits. The sweep doesn't touch exit. Good.

Potential issue: The sweep could delete an entry pending order that the reconstruction's pending-consistency check included in `pending_entries` and that the `V2_SRE_CheckPendingEntryConsistency` accepted as the single add/reload. If the tick loop fails to place a new add because `Long_ComputeAddTarget` uses `g_long_last_exit_valid` and `current_add_pips` from reconstruction, which may be wrong due to upstream SRE bug. But upstream is out of scope. If path state is wrong, the new add might be at wrong price, but that's not the sweep's fault. The fix assumes reconstruction correct.

Need maybe mention "the sweep itself does not update state variables; it only removes broker orders. All state changes occur in later tick handling, so no direct state corruption." Good.

Let's consider "entry_magic == exit_magic" possibility if `V2_EXIT_MAGIC_OFFSET` could be 0 due to macro override? In logic header:
```
#ifndef MM_LONG_V2
#define MM_LONG_V2 20260901
#endif
...
#define V2_EXIT_MAGIC_OFFSET 2
#define MM_LONG_V2_EXIT (MM_LONG_V2 + V2_EXIT_MAGIC_OFFSET)
```
No conditional override for offset. Could a test file override V2_EXIT_MAGIC_OFFSET before include? The header defines unconditionally. If a test file defines it, compiler warning? It's not `#ifndef`, so redefinition. Production not. So no.

Could a different EA file define `MM_LONG_V2` after include? The `#ifndef` defaults are used if production file doesn't define before include; but each production file defines before include. No config. Good.

Could an exit order carry entry magic because `V2_SendExitLimit` is called with `MM_LONG_V2_EXIT` but if `V2_OrderSendCounted` modifies request magic? No.

Potential issue: The sweep filters by `OrderGetInteger(ORDER_MAGIC) != entry_magic` where entry_magic is `long`. But `OrderGetInteger(ORDER_MAGIC)` could return `NULL`? No.

Potential issue: The sweep's `OrderSelect(ticket)` may select an order from history if a current order with same ticket? `OrderSelect` selects from current orders, not history. If ticket not in current orders, returns false. So no.

Potential issue: If an entry pending order is in the process of being "expired" or "canceled" but still in OrdersTotal, removing is okay.

Now, let's think about "could the long-side sweep delete the short-side's pending entries or vice versa, given both are buy_limit/sell_limit?" The magic filter prevents. But what if entry_magic for long side equals short side's exit_magic? Let's see: Long entry 20260901, short exit 20260904. No. Long entry for EURUSD 20260911, short exit EURUSD 20260914. No. Could long entry of one pair equal short entry of another? 20260901 vs 20260912/22 no. Across pairs distinct by 10/20. No.

Potential issue: If the same EA file is used on multiple symbols without redefining magic? For fxmatrix_v2.mq5, if attached to EURUSD instead of GBPUSD, it would use magics 20260901/2 on EURUSD. The prompt says three EAs on one account distinct symbols/magics. But if someone misattaches the GBPUSD EA to EURUSD, it would share symbol with EURUSD EA but different magic? Actually EURUSD EA uses 20260911/12; GBPUSD EA uses 20260901/2. If mistakenly attached to EURUSD, symbol filter in sweep would delete its own entry orders (magic 20260901/2 on EURUSD) but not EURUSD EA's orders. It might be unsafe if the wrong EA deletes its own orders on a symbol where it shouldn't trade, but that's deployment error, not code logic. Out of scope.

Potential issue: The sweep is called after reconstruction success for one side; if the other side halted, does the sweep still run? V2_SRE_RunOnInitSidePair calls RunSideOnInit for long and short. Each side's RunSideOnInit would sweep on its own success. If one side halted, it doesn't sweep that side. The other side can sweep. Fine.

Potential issue: The sweep doesn't skip orders that are currently being used by a CloseBy queue? CloseBy queue references positions, not pending entry orders.

Potential issue: "resting exit limits + CloseBy" — exit limits are exit magic. OK.

Now, let's consider the exact wording "entry-magic pending limit orders" — The sweep checks ORDER_TYPE_BUY_LIMIT and SELL_LIMIT. What about `ORDER_TYPE_BUY_STOP_LIMIT` or `ORDER_TYPE_SELL_STOP_LIMIT`? It skips. Are there any such orders with entry magic? The EA only places limit orders. So no.

Potential issue: The sweep does not check `ORDER_COMMENT` to distinguish V2_L0/Add/Reload from manually placed orders with same magic. But same magic implies EA owned. OK.

Potential issue: If a pending entry order is "filled" but the position is not yet visible in PositionsTotal due to sync, and the order remains in OrdersTotal (stale), the sweep could remove the order. The position still exists on server; when sync completes, OnTradeTransaction/OnTick will see it? In MT5, if a position is created by a deal, the deal event is fired. If the order was removed after fill, the deal still exists. If the terminal missed the deal due to being offline, HistorySelect after reconnect will retrieve it? OnTradeTransaction may not fire for deals that happened while offline? Actually when terminal reconnects, it synchronizes deals? It may generate OnTradeTransaction? Not sure. But even if no event, the next ticks see the position in PositionsTotal and the EA's layer arrays? Wait the EA only appends layers on OnTradeTransaction DEAL_ADD. If it misses the deal event, it won't know about the position. This is a general risk after reconnect, not specific to sweep. The reconstruction itself uses PositionsTotal to gather positions; if the fill occurred after gather, it won't be in reconstruction. If OnTradeTransaction doesn't fire for that fill because it happened while offline, the position would be orphaned. But is that possible? The sweep is running during OnInit after synchronization? If the fill happened before synchronization, it would be in PositionsTotal gather. If it happens after gather but before sweep, the terminal is connected and should fire OnTradeTransaction after OnInit. If it fires before sweep? It can't during OnInit? Actually events can be queued and processed after OnInit. So likely OK. If the terminal was mid-sync, a fill that occurred during the sync gap might not generate OnTradeTransaction? But if the position is in PositionsTotal after sync, the EA's OnTradeTransaction may not fire for historical sync. In MT5, OnTradeTransaction is called for all trade transactions, including those during synchronization? I think after reconnection, the terminal generates transactions for all received deals? Not sure. If not, the EA would miss positions entirely, but that's upstream reconstruction/sync issue, not sweep. The sweep deleting an order that filled during sync could exacerbate because the order is gone and the position might be unmanaged if no deal event. However, if the position is in PositionsTotal at gather? If fill happened before gather, yes it would be included. If after gather, the sync is presumably complete enough that deal events will be generated. This is edge. We can mention as a reason to gate on sync for robustness, but not a demonstrated deletion of needed order.

Should we recommend a guard? The prompt asks "If safe: confirm, and confirm whether any guard (e.g. re-select and verify still-pending before delete) is warranted for the Q4 race." We can say "A re-select guard is not required for Q4 safety, but it is a cheap defense-in-depth and would also reduce failed OrderSend calls. More important than a re-select would be a sync gate if you want the sweep to be reliably effective; for deletion safety, neither is mandatory."

Need decide final verdict: "Safe as written" vs "Safe with caveats". I think "Safe as written" for deletion safety. Include caveats: completeness (flat L0 not covered), sync gate for effectiveness, cap/max intentional.

Let's craft final answer with clear sections.

Potential issue: The sweep could delete an order that is "still needed" by reconstruction because the reconstruction's `entry_ticket` for a layer is set to `positions[i].ticket` which is a position ticket, but what if the position ticket equals the pending order ticket? In MT5, a pending order's ticket and a position's ticket are from the same global sequence? Let's verify: In MT5, order tickets and position tickets are both integer identifiers, but a position's ticket is assigned when the deal opens; it might be equal to the order ticket? I think order ticket and position ticket are different concepts but can have the same numeric value? Actually in MT5, a position has a ticket that is the ticket of the order that opened it? Let's recall: `PositionGetInteger(POSITION_TICKET)` returns position ticket, which is the ticket of the first deal? In MQL5, `POSITION_TICKET` is a unique position identifier, not necessarily the order ticket. For a netting account, position ticket may equal the order ticket? On hedging accounts, each position has identifier unique. It could be same numeric as the order that opened it? Let's check: When a pending order fills, the order itself gets filled and remains in history with its ticket; the resulting position receives a new ticket? I think in MT5, a position's identifier is the ticket of the order that opened it? Actually from MQL5 docs: "POSITION_IDENTIFIER - position identifier, unique within the whole client terminal, is set when position is opened." It is not the order ticket. "POSITION_TICKET" is the ticket of the position. It can be different. The sweep iterates pending orders, not positions. If a pending order ticket equals a position ticket (unlikely but possible?), OrderSelect(ticket) in OrdersTotal would select the pending order if it exists; if the ticket also equals a position's identifier, the position isn't in OrdersTotal. Deleting the pending order doesn't delete the position. So no.

Could the sweep's `OrderSelect(ticket)` select a pending order that is actually the same ticket as a position in a different context? No.

Let's think about "MatchExitOrders adopts exit orders" — If a pending entry order is swept, and later the reconstruction's validation compares broker_read entry_tickets to reconstructed entry_tickets. Those entry_tickets are position tickets, not pending order tickets. So no.

Need maybe mention "The sweep intentionally discards the pre-existing entry pending, which by design is not adopted into `V2SRELayerSnapshot`; the reconstruction's layer snapshots store `position_ticket` and `entry_ticket` as position identifiers, not the pending order's ticket." This addresses "still needs."

Let's inspect V2_SRE_BuildLayerSnapshotsFromPositions: `layers[i].entry_ticket = positions[i].ticket;` where positions[i].ticket is position ticket from PositionGetTicket. So yes.

Potential issue: After reconstruction, `Long_ApplySRECommit` sets `g_long_layers[i].entry_ticket = res.layers[i].entry_ticket` (position ticket). If a pending entry order fills and OnTradeTransaction appends a layer, `Long_AppendLayer` sets `g_long_layers[n].entry_ticket = entry_ticket` where entry_ticket is order_ticket from deal, not position ticket. So there is a mix: reconstructed layers have entry_ticket = position ticket; live-appended layers have entry_ticket = order ticket. That's pre-existing. Not relevant.

Need maybe mention "The sweep does not affect exit tickets, positions, or cap GVs." Good.

Now, let's consider if there is a scenario where the sweep deletes an order that the reconstructed state still needs because the order is not yet in `OrdersTotal`? No.

Potential issue: The sweep iterates `OrdersTotal()` but does not filter by `ORDER_STATE`; if an order is `ORDER_STATE_PARTIAL`, removing it may be rejected by broker. No harm. If accepted, the remaining unfilled volume is cancelled. The partial fill already created a position; OnTradeTransaction handles. If the partial fill happened before reconstruction gather, the position would be in entry_positions, and the remaining order in pending_entries. The reconstruction would count volume? Position volume would be partial volume (less than expected), causing `V2_SRE_CheckPositionVolumes` halt if not equal expected. So success path likely excludes partial fills. Thus not a concern.

Potential issue: The sweep uses `V2_OrderSendCounted(req, res)` and if `res.retcode` is e.g. TRADE_RETCODE_ORDER_NOT_FOUND, it still counts API use. Could eventually hit daily API limit? At most a few. Not harm.

Potential issue: If the same pending entry order is selected and removed, then the loop's i decrements; because OrdersTotal has changed, but iterating downward from original total is standard safe. If an order behind i is removed by external, `OrderGetTicket(i)` might return a different order? The downward loop with removals can skip or re-process? Let's analyze: Suppose list length N. Start i=N-1. Remove order at i. Now OrdersTotal becomes N-1 (assuming list order shifts). Loop i-- to N-2, which is the next order down. If an order earlier in list (lower index) was removed externally, the index mapping could shift and cause skipping/duplicate? This is standard because after removing at i, elements above shift down? In MQL5, `OrdersTotal` returns number of current orders; order indices can change when an order is removed. Iterating downward while removing is generally safe because you remove current last, then decrement. If an order at a lower index is removed externally, you might skip one. But that's fine; sweep is best-effort. No harm.

Potential issue: If an order is filled between `OrderGetTicket(i)` and `OrderSelect(ticket)`, OrderSelect may return false (if no longer in current list) or true (if still cache). If false, skip. If true, it's still pending. Remove. OK.

Potential issue: The sweep does not collect tickets before sending removes; it sends while iterating. If a remove fails, continue. OK.

Now, let's think about "reconstructed state still needs" if the pre-existing pending entry order is a `V2_Reload` when `last_exit_valid` true. The tick loop's `Long_EnsureAddNext` will place a reload if `last_exit_valid` true. But `Long_EnsureAddNext` checks `if (g_long_add_ticket != 0 && OrderSelect(g_long_add_ticket)) return;`. It doesn't check cap for reload. It computes add_price using `g_long_last_exit_valid` true => anchor = last_exit_price, step = floor. That's correct. So no issue.

What about if the pre-existing pending entry order is `V2_Add` when `last_exit_valid` false. Tick loop places add if cap not blocking. OK.

Could the tick loop place a *different* number of orders? It places only one add because once `g_long_add_ticket` set, subsequent ticks return. Good.

Potential issue: After the sweep deletes the add pending, there is a window before first tick where no add is resting. If the price gaps to the add level, the EA misses that layer. But the old add was at a price computed before crash; the new add will be placed at the same or similar price on next tick. If the market gaps through, the new add may be placed at a worse price? Actually if price moves to the old add price, the new add might be placed at the same price if signal unchanged; if the market gap means the price is beyond the old level, the add would fill immediately if placed. The EA might miss the fill if it doesn't place before the tick? Wait if price gaps to the old add level, the old pending order would fill immediately on market open. The EA deletes it in OnInit before the market moves? If the market is closed (e.g., weekend reattach), deleting an order that would fill at market open could lose an entry. But the whole fix deletes pre-existing orders that are not represented in state. If the market later reaches that price, the EA's new order at the same price would fill (if placed before price reaches). If price gaps through, the new order might fill at worse or not at all? This is a trading behavior change but not state corruption. The question focuses on deletion safety, not strategy performance. We can mention "the delete-then-requote gap is intentional and tiny; it can alter fill timing/queue priority but cannot corrupt state."

Should we flag the "flat L0 not swept" as a potential harm? It doesn't delete, so not harm. But if the user expects the fix to solve duplicates in all cases, it's incomplete. The prompt says scope is order-sweep side-effect safety ONLY, not completeness. So mention as "outside deletion-safety scope" perhaps.

Need answer "Can this sweep, as written, EVER delete an order that the reconstructed state still needs, or otherwise cause harm?" The answer should be "No" but with "provided the magics remain as constants and the sweep is only invoked on committed success." Because if a future config changes entry/exit magic relation, filter could fail. But as written, no.

Let's consider if the sweep could delete an order that is "still needed" because the reconstruction's path state `last_exit_valid` was computed from the existence of pending entry orders? No, replay doesn't use pending entries. Pending consistency only validates comments. So no.

Potential issue: `V2_SRE_GatherPendingOrders` gathers exit_orders and pending_entries by scanning all orders. If an entry-magic order has comment "V2_Exit" due to some bug, it would be gathered as pending entry and consistency check would HALT_11. So no success. If an exit-magic order has comment "V2_L0", it's gathered as exit order; sweep skips due magic. OK.

Potential issue: If the pending entry order is a `V2_Reload` but the reconstructed `last_exit_valid` is false (because replay didn't account for the reload reset? Actually reload reset is accounted). The sweep deletes it; tick loop places a `V2_Add` instead of `V2_Reload` because `last_exit_valid` false. This could be a semantic mismatch: The old pending order was a reload (placed after a top exit), but reconstruction's `last_exit_valid` may be false if a subsequent append? Wait if a reload order is pending, it was placed after a top exit and `last_exit_valid=true` at placement. If no further fills, reconstruction should have `last_exit_valid=true`. So tick loop places reload. If `last_exit_valid=false`, then a reload pending would not be consistent? The comment of pending order isn't checked against last_exit_valid in reconstruction. V2_SRE_CheckPendingEntryConsistency doesn't verify comment semantics (add vs reload) against stack state. Spec §1.4 says "any pending entry-magic order whose comment doesn't cleanly resolve given current stack state" is halt, but the implementation doesn't check. So a pending reload could exist while reconstruction path_state says last_exit_valid=false. The sweep deletes it; tick loop places an Add (because last_exit_valid false). Is that harmful? It changes the classification of the future layer from reload to add. This is an upstream SRE inconsistency, but the sweep's deletion may remove a reload that would have been semantically correct. However, the reconstructed state says last_exit_valid false, so from the EA's perspective the next quote should be an Add, not Reload. If the old reload was placed when last_exit_valid true but then a non-top removal? Let's see: Reload is placed only after top exit, setting last_exit_valid true. Could last_exit_valid become false while reload pending? Only if a new entry fills (reload) and sets false, but then pending would be cancelled. Or a lower layer removal sets false? In production, if a non-top exit occurs, Long_RemoveLayerAt sets last_exit_valid? It only sets true if was_top; otherwise leaves unchanged? Actually it doesn't set false on non-top removal; it just doesn't set true. But `Long_HandleDealFill` for entry sets last_exit_valid false only if ArraySize==0 or reload. So last_exit_valid true can persist through non-top removals. Replay path state: On non-top removal, it explicitly sets `last_exit_valid = false`! Wait in V2_SRE_ReplayPathDependentState:
```
if(events[i].is_removal) {
   ...
   if(was_top) { last_exit_valid=true; } else { last_exit_valid=false; }
   ...
}
```
This is different from production! Production Long_RemoveLayerAt: if was_top set true; if not top, it does NOT set false. Actually it doesn't change last_exit_valid. Let's check: In Long_RemoveLayerAt:
```
bool was_top = (layer_idx == n - 1);
if(was_top) {
   g_long_last_exit_valid = true;
}
...
if(ArraySize(g_long_layers) == 0)
   g_long_current_add_pips = ...
else if(was_top)
   Long_EnsureAddNext();
```
For non-top removal, it leaves g_long_last_exit_valid unchanged (could be true or false). The replay sets false on any non-top removal. This is an upstream discrepancy. Out of scope. But could cause `last_exit_valid` false while a pending reload exists. Then sweep deletes reload; tick loop places add. This is a semantic change, but again the sweep is not the cause; the reconstruction path state is. The prompt explicitly says reconstruction logic is out of scope and unchanged. We should not flag sweep for upstream inconsistency. But if we're auditing "can the sweep delete an order that reconstructed state still needs," the reconstructed state doesn't "need" the reload if last_exit_valid false? Actually it might need a reload, but state says add. Hmm.

Given scope says "ONE new thing is added: a broker side-effect (order deletion) on the reconstruction SUCCESS path. Audit ONLY whether that deletion can ever remove an order it should not." So we focus on deletion filter. The semantic classification issue is not caused by deletion? It could be considered "deletes an order it should not" if the old reload was still needed. But the fix's whole premise is delete pre-existing entry pendings and let tick loop requote based on reconstructed path state. If the reconstructed path state is wrong, the requote may be wrong. But that's upstream. We can note "assuming reconstruction is correct (as scoped), the requote is correct."

Need maybe include "The sweep does not verify the order's comment; it deletes all entry-magic limit orders. If a future entry-magic limit order is ever used for something other than L0/Add/Reload, this sweep would delete it. Currently none exists." Good.

Let's think about "otherwise cause harm" via deleting an order that is in a "transitional state" mid-sync. We can answer with "No, because a transitional fill is a position, not an order; delete cannot remove a position. The only theoretical harm is if the terminal's order cache is corrupt and OrderSelect returns an order that is actually a position? Not possible; different API."

Potential issue: If the broker is a hedging account and a pending order is used as a "position" for netting? No.

Potential issue: `TRADE_ACTION_REMOVE` on a pending order that is a BUY_LIMIT with entry magic could close the reverse side? No, only removes order.

Now, let's formulate final answer in a way that satisfies "be exhaustive" but not too long. We can use bullet points.

Let's structure:

1. Verdict.
2. Per-question pressure-test.
3. Additional edge cases/invariants.
4. Recommendation.

Let's include specific code references.

Detailed answer draft:

```
VERDICT: The sweep is safe as written. It cannot delete an order that the reconstructed layer state depends on, and the Q4/Q6 races do not create a deletion hazard. No guard is mandatory for safety. Optional hardening: re-select + ORDER_STATE check; sync gate for effectiveness.

1. Magic isolation ...
```

For Q1, mention `V2_EXIT_MAGIC_OFFSET=2` in fxmatrix_v2_logic.mqh. The sweep uses `entry_magic`; exit magic orders are `entry_magic+2`. No production path places a pending exit order with entry magic. `V2_ProcessCloseByQueue` sets `req.magic = closeby_magic` (entry magic) for CloseBy requests, but that's a position-closing request, not a pending limit order; it never appears in OrdersTotal as an entry-magic limit. Thus MatchExitOrders' adopted exit orders are never swept.

For Q2, list magics. Long/short differ by 1. Per-side call.

For Q3, symbol+magic.

For Q4:
- The sweep operates on OrdersTotal, not positions.
- Fill between gather and sweep -> order leaves OrdersTotal (or remove fails).
- Deal event appends layer.
- Partial fill: position exists; remaining order deletion doesn't delete position.
- Re-select guard not needed.

For Q5:
- On a successful reconstruction, layer_count >0 (because entry_n>0; if entry_n==0, halt HALT_01). Thus the only valid pending entry on success is a single Add/Reload (L0 on non-empty would halt HALT_06). After commit, l0/add tickets are 0, so `Long_EnsureAddNext` will place the next Add/Reload on first tick, unless max layers or cap gate blocks (both intentional).
- If stack empty, no reconstruction attempted, no sweep; so flat L0 duplicate is outside sweep's domain. If it were called in a flat state, it would delete L0 and tick loop would place a fresh L0, so still safe.

For Q6:
- No guarantee OnInit after full sync. But mid-sync partial/stale view:
   * miss -> duplicate remains (effectiveness, not safety)
   * stale order -> remove fails
   * cannot delete position or exit order.
- If you want deterministic sweep, you'd need to gate on connected/trade-allowed and/or re-scan; no official API for "order cache synchronized."

Then "Constraints for safety to remain true": entry/exit magic constants unchanged; sweep called only on seq==V2_SRE_OK; no future code places entry-magic limit orders for other purposes; cap/max blocks intentional.

Need maybe mention "the sweep's `if(V2_OrderSendCounted(req,res)) swept++` ignores `res.retcode`; a false positive (retcode not DONE) would miscount but not harm." Optional.

Let's also mention "The only 'harm' that could be argued is the intentional cancellation of a resting quote before the tick loop re-quotes; this is the fix's purpose and the re-quote occurs on the first tick, so the gap is minimal."

Potential issue: The prompt says "The tick loop, seeing no L0 quote in its rebuilt state, places a fresh one -> DUPLICATE resting quotes (observed across all 3 instances)." We might need to address "L0 quote" in our answer. We can say "Under the reconstruction success path, if the stack is non-empty, the tick loop doesn't place an L0; it places an Add/Reload. The sweep covers those. The flat-empty L0 case is not on the success path because reconstruction isn't attempted when there are no open positions. If the intent was to cover flat L0 duplicates, the sweep as placed would not run; that's a completeness gap, not a deletion-safety issue."

Should we include that as a "finding"? The question asks "single question" and pressure-test. We can say "I am not treating the flat-L0 coverage gap as a deletion-safety failure; flagging it for completeness." Good.

Let's ensure final answer not too verbose but includes all. Desired oververbosity 5. We'll be moderately detailed.

Let's now write final.

## Final Report

## Verdict

**The sweep, as written, is safe.** It cannot delete an order the reconstructed state depends on, and the two races you are most worried about (fill-between-gather-and-sweep, mid-sync stale order book) do not create a deletion hazard.

The only real caveats are:

- A mid-sync partial order-book view can make the sweep **miss** orders it was meant to delete — that is an effectiveness gap, not a deletion-safety failure.
- If `InpMaxLayers` is already reached, or the cap gate blocks a new add, the tick loop will deliberately not re-place the swept order. Those are intentional risk gates, not orphaned-state corruption.

---

## 1. Exit orders / exit magic — cannot be swept

The sweep filter is:

```mql5
if(OrderGetInteger(ORDER_MAGIC) != entry_magic) continue;
```

Exit magic is derived, never input:

```mql5
#define V2_EXIT_MAGIC_OFFSET 2
#define MM_LONG_V2_EXIT   (MM_LONG_V2 + V2_EXIT_MAGIC_OFFSET)
#define MM_SHORT_V2_EXIT  (MM_SHORT_V2 + V2_EXIT_MAGIC_OFFSET)
```

So:

- Long entry `...901` → long exit `...903`
- Short entry `...902` → short exit `...904`
- EURUSD / EURGBP follow the same `entry_magic + 2` pattern

Every resting exit order is created only through `V2_SendExitLimit`, which is always called with the exit magic. The `MatchExitOrders` path consumes only orders gathered by `omagic == exit_magic` in `V2_SRE_GatherPendingOrders`.

`V2_ProcessCloseByQueue` does set `req.magic = closeby_magic` where `closeby_magic` is an **entry** magic, but that is a `TRADE_ACTION_CLOSE_BY` request against positions, not a pending limit order. It never creates an entry-magic BUY_LIMIT/SELL_LIMIT resting order.

**Conclusion:** a `...904`-style exit order can never match an `entry_magic` filter. There is no configuration path where `entry_magic == exit_magic`.

---

## 2. Side isolation — one side cannot sweep the other side

Per pair, long and short entry magics differ by exactly 1:

| File | Long | Short |
|---|---|---|
| `fxmatrix_v2.mq5` | `20260901` | `20260902` |
| `fxmatrix_v2_eurusd.mq5` | `20260911` | `20260912` |
| `fxmatrix_v2_eurgbp.mq5` | `20260921` | `20260922` |

The caller passes `cfg.entry_magic` for that side only.

A long-side sweep with `20260901` cannot see a short-side order with `20260902`, regardless of order type. The same holds for every pair.

There is no production code path that creates a same-magic cross-side pending order.

**Conclusion:** the magic filter is sufficient to isolate sides.

---

## 3. Multi-instance isolation — distinct symbol + distinct magic

The sweep requires both:

```mql5
OrderGetString(ORDER_SYMBOL) == symbol
OrderGetInteger(ORDER_MAGIC) == entry_magic
```

The three instances run on distinct symbols and distinct magic ranges:

- GBPUSD: `20260901/2`
- EURUSD: `20260911/2`
- EURGBP: `20260921/2`

No cross-instance deletion is possible.

---

## 4. Fill-between-gather-and-sweep race — cannot lose a fill

The sweep only removes things that are still in `OrdersTotal()` as **pending orders**.

If a pending entry order fills between the SRE snapshot and the sweep:

1. The order is no longer in `OrdersTotal()` → the sweep does not see it.
2. If the terminal cache is stale and still shows it, `TRADE_ACTION_REMOVE` either fails or removes a ghost record — it cannot remove the newly opened position.
3. The fill itself appears as a `DEAL_ADD` transaction. After `OnInit` returns, `Long_HandleDealFill` / `Short_HandleDealFill` will append the layer from that deal.

So the fill is not lost and state is not corrupted.

A partially filled order is the same class of event: the filled part becomes a position and is handled by `OnTradeTransaction`; deleting the remaining unfilled volume is consistent.

**Is a re-select/verify-still-pending guard warranted?**

Not for safety. A pre-delete re-check like:

```mql5
if(!OrderSelect(ticket)) continue;
if(OrderGetInteger(ORDER_STATE) != ORDER_STATE_PENDING) continue;
```

would reduce stale-remove attempts, but it cannot close the server-side fill/remove race. The race is benign because the position is the source of truth, not the pending order.

Optional hardening: yes, harmless. Required for safety: no.

---

## 5. Delete-then-let-tick-loop-requote — safe

On a successful reconstruction path, the side has open entry positions, so the reconstructed stack is non-empty.

After `V2_ApplyLongSRECommit` / `V2_ApplyShortSRECommit`, the tick-loop tracking variables are zero on a fresh attach:

- `g_long_l0_ticket == 0`
- `g_long_add_ticket == 0`

On the first tick:

- Non-empty stack → `Long_OnNewBar()` / `Short_OnNewBar()` calls `EnsureAddNext()`
- `EnsureAddNext()` sees `add_ticket == 0`
- It computes the Add/Reload price from reconstructed path state and places one fresh order
- L0 is not re-placed because the stack is non-empty

So the swept Add/Reload order is immediately replaced by exactly one fresh order.

Two intentional cases where the tick loop will not re-place:

- `n >= InpMaxLayers` — no add should exist by invariant; if one somehow exists, deleting it is safer than letting it fill beyond max layers.
- The cap gate blocks a new add — that is the cap’s purpose. Deleting a pre-existing add that would bypass the cap is not harm; it enforces the gate.

**Flat-empty stack with a pre-existing L0** is not on this sweep’s execution path, because reconstruction is not attempted when there are zero open positions. If a flat-L0 duplicate is the observed problem, the sweep as placed would not run in that case. That is a **coverage gap**, not a deletion-safety defect.

---

## 6. Reconnection / mid-sync stale order book

There is no documented MQL5 guarantee that `OnInit` runs only after the trade-subsystem position/order cache is fully synchronized.

`TERMINAL_CONNECTED` and `TERMINAL_TRADE_ALLOWED` confirm connectivity/trade permission, but neither is a formal “order cache fully synchronized” flag.

So a mid-sync sweep is possible in principle.

But what actually happens if the order book is partial/stale:

| Mid-sync condition | Consequence |
|---|---|
| Sweep misses an entry-magic pending order that is actually there | Duplicate remains — this is the original effectiveness problem, not a deletion-safety failure |
| Sweep sees a stale pending order that no longer exists on the server | `OrderSend(REMOVE)` fails / no harm |
| Sweep sees an order mid-transition from pending to filled | The position still exists on the broker; the deal is the source of truth; deletion cannot remove the position |
| Sweep sees an exit order | Skipped by magic filter |
| Sweep sees another instance’s order | Skipped by symbol+magic filter |

So the sweep does not need a sync gate **for deletion safety**.

If you want the sweep to reliably fix the duplicate-order problem, a sync/retry gate before sweeping is reasonable, but there is no clean official API to wait for “order book fully synchronized.” A re-scan loop keyed off `TerminalInfoInteger(TERMINAL_CONNECTED)` and `TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)` would be a practical mitigation, not a safety control.

---

## Final answer

**The sweep cannot delete an order that the reconstructed layer state still needs.**

- Entry-magic filter excludes exit orders.
- Per-side magic excludes the opposite side.
- Symbol + magic excludes other instances.
- A filled order is a position, not an order; a delete cannot remove it.
- The tick loop re-places the single Add/Reload quote on the first tick after commit.
- Mid-sync stale views can cause missed or failed deletes, but not deletion of a position, exit order, or cross-instance order.

Optional hardening, not required:

```mql5
// Re-select immediately before removing to reduce stale-order remove attempts.
if(!OrderSelect(ticket)) continue;
if(OrderGetInteger(ORDER_STATE) != ORDER_STATE_PENDING) continue;
```

But this is defense-in-depth, not a fix for a demonstrated deletion hazard.