# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit. Need inspect code, givens, threats. Need cite file function quote. Need be exhaustive. We need produce sections GIVENS CHECK G1-G5, T-1...T-9, PREMISE VERDICT, TEST GAPS. Need no preamble. We need use given code. Need verify each. Need find subtle defects tests can't see. Let's analyze deeply.

We have MQL5 code. C52 fix in grind_carry.mqh. Need check givens.

First understand structs. GrindLayer fields? Not fully shown but from usage: entry_price, position_ticket, layer_index, exit_order_ticket, exit_position_ticket, exit_target. GrindSideState has layers dynamic array plus l0_pending, add_pending, add_held, etc. Grind_CarryCurrentExitTicket code:

bool Grind_CarryCurrentExitTicket(const ulong position_ticket,
                                  const bool is_long,
                                  ulong &exit_ticket_out,
                                  bool &closing_out)
{
   exit_ticket_out = 0;
   closing_out = false;
   const GrindSideState side = is_long ? g_grind_long : g_grind_short;
   for(int i = 0; i < ArraySize(side.layers); i++) {
      if(side.layers[i].position_ticket != position_ticket)
         continue;
      exit_ticket_out = side.layers[i].exit_order_ticket;
      closing_out = (side.layers[i].exit_position_ticket != 0);
      return true;
   }
   return false;
}

Potential issue: `const GrindSideState side = is_long ? g_grind_long : g_grind_short;` In MQL5, struct copy of dynamic array? Need know semantics. MQL5 structures with dynamic arrays cannot be copied? Actually MQL5 supports copying structures containing dynamic arrays? I think yes? But MQL5 does not allow dynamic arrays in structures? Wait MQL5 structures can contain dynamic arrays? Let's recall: MQL5 structures can contain simple types, strings, objects? Dynamic arrays inside structs? They can contain arrays only fixed size? Actually MQL5: "Structures containing dynamic arrays cannot be copied"? Hmm. The code already uses `const GrindSideState side = is_long ? g_grind_long : g_grind_short;` in fix. If MQL5 does not support copying structs with dynamic arrays, compile fails. But tests passed 1882/1882, so compiles. MQL5 may allow copy. However in MQL5, arrays in structs are copied deeply by value? Need assess T-7. They ask "helper copies a side struct (with dynamic array of up to 8 layers) per item. Any MQL5 semantics (deep copy, aliasing) that could make the copy stale or wrong?" Since it's called per item at step time, copy is current at call. But copy of dynamic array maybe deep. However `const GrindSideState side = ...` creates a copy of selected global. It reads current. But potential bug: `GrindSideState side` copy includes dynamic array, and ArraySize(side.layers) works. But if MQL5 struct assignment of dynamic arrays is shallow? It could alias? But since we only read, not mutate, even shallow okay. Stale? It copies at call, no interleaving because single-threaded. So okay. But MQL5 struct copy with dynamic array: I need be careful. MQL5 docs: "Structures containing dynamic arrays, class objects, or pointers cannot be copied using assignment operator"? Actually I recall MQL5 has restrictions: "Structures containing objects or dynamic arrays cannot be copied." Let's recall exact: MQL5 structures can contain dynamic arrays? In MQL5, a structure can contain dynamic arrays, but such structures can be passed to functions only by reference? Hmm. They already have functions taking `const GrindSideState &side` by reference. But here assignment by value. If unsupported, compile error. But tests passed on both symbols, so it's supported in their build. Could be MQL5 recent supports copying dynamic arrays (deep). We'll note ASSUMED.

Need examine G1: returns book's current exit_order_ticket and closing for matching position on side; false if absent. Code exactly. But it sets closing_out = exit_position_ticket != 0. True if closing. False if absent. However does it return false if layer exists but position_ticket==0? It's called with position ticket from work. It scans layers. If `position_ticket` is 0? The work items are captured from layers with position_ticket != 0 in Begin, so 0 shouldn't happen. But if position_ticket 0, it could match a layer with position_ticket 0? But layers should have nonzero. It would return true for a layer with position_ticket=0 if exists, not absent. But work pos nonzero. So okay. G1 VERIFIED with quote.

G2: `Grind_CarryExitPassStep` calls it per item and passes `current_exit` where it passed `g_grind_carry_exit_work_exit[idx]`. Code in step:

      ulong current_exit = 0;
      bool closing = false;
      if(!Grind_CarryCurrentExitTicket(g_grind_carry_exit_work_pos[idx],
                                       g_grind_carry_exit_work_long[idx],
                                       current_exit, closing)
         || closing) {
         g_grind_carry_exit_skipped++;
         processed++;
         continue;
      }
      ...
      if(Grind_CarryExitShiftLayer(g_grind_carry_exit_work_pos[idx],
                                   current_exit,
                                   ...
Yes. VERIFIED.

G3: Absent/closing: skip++ processed++ continue; nothing else runs. Code exactly; but need check after continue, nothing else in loop? It increments cursor before. Then skip branch continues to next iteration. `Grind_CarryExitShiftLayer` not called. However note `processed++` then continue. But `g_grind_carry_exit_work_done` not incremented. At end of loop maybe if cursor >= count and retry_count==0 emits summary. Since processed increments, it can finish? If all items skipped, processed increments and cursor advances. Then summary with skipped count. But if only 2 items and both skipped, processed=2, cursor=2, summary emitted. Fine. G3 VERIFIED. But subtle: `Grind_CarryExitShiftLayer` itself can also increment skipped for ledger conversion fail and sign guard. But for absent/closing branch, nothing else. VERIFIED.

G4: unchanged by 6831436. We only have current code, no diff. Need determine from prompt: fix commit only added helper and step modifications. But G4 says `Grind_CarryExitShiftLayer`, `Grind_CarryExitPassBegin`, `Grind_CarryWorkBase` and event formats unchanged by `6831436`. We can inspect: In current code, `Grind_CarryWorkBase` at ~? It reads live entry? Wait G4 says unchanged. The code for `Grind_CarryWorkBase`:

double Grind_CarryWorkBase(const int idx, const double exit_pips, const double point)
{
   const int dir = g_grind_carry_exit_work_long[idx] ? 1 : -1;
   return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx],
                                               g_grind_carry_exit_work_pos[idx]),
                          exit_pips, point, dir)
          + Grind_EjectOffsetGet(g_grind_carry_exit_work_pos[idx]);
}

It reads entry from work array, not live layer entry. G5 says base reads eject offset and virtual level at step time, not capture. Actually it uses `Grind_EffectiveEntry(work_entry, pos)` which reads VL GV at step time (if VL exists). Entry passed is captured entry_price. Eject offset GV read at step time. So G5 maybe VERIFIED. But G4 event formats unchanged? We can't verify unchanged from diff, but can say no evidence in current code; maybe VERIFIED by scope? We need maybe mark as VERIFIED or NEEDS-FIX? We need use quotes. If cannot verify absence, maybe "VERIFIED (no counterevidence in supplied code; helper absent from those functions)". But givens check requires VERIFIED/FALSE with quote. For G4, we can quote that `Grind_CarryExitShiftLayer` has no call to helper and `Grind_CarryExitPassBegin` uses `layer.exit_order_ticket` at capture, and events same. But "unchanged" cannot be proven from final code alone. We can say VERIFIED as far as observable: the fix helper is not referenced in those functions; quote. But if there was change, no diff. We can mark "VERIFIED (observable)". Need be honest.

G5: base reads eject offset and virtual level GVs at step time, not capture. Quote `Grind_CarryWorkBase`: `Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx], g_grind_carry_exit_work_pos[idx])` and `+ Grind_EjectOffsetGet(...)`. `Grind_EffectiveEntry` reads `Grind_VLGet` if has. Both at call time. So VERIFIED. But note it uses captured `g_grind_carry_exit_work_entry[idx]` if no VL. Entry is fixed by design; if entry changes? Layer entry_price doesn't change. It uses captured entry value not live layer.entry_price. T-2 asks list captured state. This is important: base uses captured entry_price even if layer's entry_price differs? Entry is fixed at fill; but reconstruction could rebuild? During pass no trade? Single-threaded, no interleaving inside step, but between steps a layer could be removed and another added? Position ticket unique. Entry of existing layer doesn't change. However if layer is removed and a new layer reuses same position_ticket? Position tickets unique. So okay. But the work array stores entry from PassBegin. If VL GV changes mid-pass, EffectiveEntry uses current VL, not captured entry. So base can change. That's intended? G5 says base reads VL and offset at step time. Yes.

Now threats.

T-1 Lookup. Need examine if lookup can return wrong layer or miss. It scans side array for position_ticket. Position ticket should be unique per side and across sides? In MT5 position tickets are unique globally. But there is possibility: a position ticket from long side may be found in long side; if item side is wrong? Work item's `g_grind_carry_exit_work_long[idx]` captured at Begin. Could side change mid-pass? A layer cannot move from long to short; position side fixed. If layer removed and another layer with same position_ticket? No. Duplicate position tickets? Invariants should prevent I5 duplicate? There is I5 layer indices, not position tickets. Could duplicate position_ticket exist? Recon checks duplicate layer index but not duplicate position ticket? In rebuild, if two positions same ticket? Broker unique. But maybe test? Not live. Could a layer being rebuilt by reconstruction or quarantine? The pass runs in OnTimer. OnTimer does not call reconstruction. OnTick runs reconstruction? Actually `Grind_ReconstructState` only in OnInit and test stub. Quarantine? OnTick when quarantined calls `Grind_RetryMissingExits`, not rebuild. So during pass, book is live and only modified by queue in tick/trade events, not within timer step. But between timer steps, a tick/trade could run. If a layer is removed and re-added? A position can only be added on deal fill; if it was removed, position closed. New position would have new ticket. So lookup by ticket won't find old. Good.

But subtle: The lookup copies `const GrindSideState side = is_long ? g_grind_long : g_grind_short;`. In MQL5, conditional operator with structs? Maybe it returns a reference or copy? If it returns reference to global, then `side` might alias? But const. If it returns a copy, okay. If it aliases, reading current. No issue. But if the struct contains dynamic array and assignment is shallow, and then the array is modified in another event? Single-threaded, no interleaving inside step. Between steps, the helper is called fresh each item. So no stale.

Could it miss a layer whose exit rests? It scans all layers on side. If layer exists, returns true. If layer missing (closed), skip. That is intended. But consider layer with `exit_position_ticket != 0` (closing). It returns true closing. Skip, commit nothing. But what if layer is closing but still has an exit_order_ticket? In code when EXT fills, `side.layers[layer_idx].exit_order_ticket = 0; exit_position_ticket = position_id;` so exit_order_ticket zero. In `Grind_ExitQHoldCancelLayer`, if cancel fails and finds exit deal position, sets exit_position_ticket=pos_out, exit_order_ticket=0. So closing implies no exit order. Skip. Fine.

Potential wrong layer: If there are duplicate position_ticket entries in the same side array (invariant violation), it returns first. But invariants I5 duplicate layer indices, not position tickets. Could duplicate position tickets occur? In `Grind_AppendLayer`, position_ticket from deal. Broker won't have duplicate. But if recon rebuilds from comments, two ENT positions with same position ticket? Broker unique. So not.

Another issue: The helper takes `is_long` from work item. If the work item's side is wrong because the layer migrated? Not possible. But what if position ticket from long side is accidentally also present in short side? Broker unique. No.

Miss a layer whose exit rests: If the layer is in the book but its position_ticket is 0? Not possible. If layer was removed from book but position still open? Invariants? Could happen if `Grind_RemoveLayerAt` called incorrectly? But then skip, commit nothing; accrual not committed, and exit may still rest? If layer missing but exit orders still exist? That's invariant orphan. The pass skips, leaving exit unshifted. But if invariants say wrong, instance halted? T-5. Need consider.

T-1 maybe breaks if the layer is in the *other* side due to reconstruction? No.

But there is a subtle bug: The helper scans `side.layers` and checks `side.layers[i].position_ticket != position_ticket`. It does NOT check `exit_position_ticket` or layer_index. The work item stores position_ticket. For a layer that is closing, `position_ticket` remains original. So it finds it and returns closing. Good.

What about a layer that was removed and re-added with same position_ticket? Not possible.

What about a layer whose position_ticket matches but it's a different layer because position ticket reused after close? MT5 position tickets are unique for account history? They are identifiers for open positions; after close, position ID might be reused? I think MT5 position tickets are not reused? They are unique within account? Actually position ID is unique for open positions, but after close, the same ID could theoretically be reused? MT5 uses ticket numbers from broker; not guaranteed never reused? In practice not within days. But a closed position's ticket could be reused after long time. During a pass minutes, not.

So T-1 likely HOLDS. But need mention duplicate/rebuild not possible in pass; if invariant violation, I5/I2 would catch. Smallest fix maybe none. But maybe there is a real bug: `const GrindSideState side = is_long ? g_grind_long : g_grind_short;` If MQL5 conditional operator with structs selects by value and copies dynamic array, okay. But if it doesn't deep copy? We'll cover T-7.

T-2 Remaining captured state. List: entry (`g_grind_carry_exit_work_entry[idx]`), side (`...long[idx]`), layer index (`...layer[idx]`), formula (`...formula[idx]`), order/position ticket (`...pos[idx]`), the order of items. Also `g_grind_carry_exit_work_count`, cursor, eligible count, etc. During pass, entry fixed. Side fixed. Layer index fixed? A layer's layer_index doesn't change. Formula captured at Begin is used? Check step: It calls `Grind_CarryExitShiftLayer(... Grind_CarryWorkBase(idx, ...), ...)`. It does NOT pass `g_grind_carry_exit_work_formula[idx]` to ShiftLayer. Wait in step code:

      if(Grind_CarryExitShiftLayer(g_grind_carry_exit_work_pos[idx],
                                   current_exit,
                                   g_grind_carry_exit_work_entry[idx],
                                   Grind_CarryWorkBase(idx, exit_pips,
                                                       SymbolInfoDouble(symbol, SYMBOL_POINT)),
                                   g_grind_carry_exit_work_long[idx],
                                   g_grind_carry_exit_work_layer[idx],
                                   magic, symbol, exit_pips,
                                   clamped, sign_skip, retcode))

It passes `Grind_CarryWorkBase(idx, ...)` as formula_exit, not the captured `g_grind_carry_exit_work_formula[idx]`. Wait the work array has `g_grind_carry_exit_work_formula` but step uses `Grind_CarryWorkBase`. In original defect description: "the step passed the CAPTURED exit ticket... Grind_CarryExitShiftLayer commits... moves it by accrual". The work array formula is stored but maybe used for events? Let's inspect `Grind_CarryExitShiftLayer` uses `formula_exit` param. It computes `theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);` So it uses the passed formula. The step passes `Grind_CarryWorkBase(idx, exit_pips, point)`, which recomputes formula from captured entry, live VL, live eject offset. So the captured `g_grind_carry_exit_work_formula` is NOT used in the step? Search code: `g_grind_carry_exit_work_formula` appears in append, reset, arrays. It is not referenced elsewhere? In current code, `Grind_CarryExitPassStep` does not use it. `Grind_CarryWorkBase` uses work_entry and work_pos. So the stored formula is dead? But maybe used in tests? Or event? In `Grind_CarryExitShiftLayer`, event uses `formula_exit` param, not array. So T-2: stored formula is not used for anything but maybe events? Actually not even events; the formula passed is WorkBase. Wait `Grind_CarryWorkBase` uses `Grind_ExitPrice(Grind_EffectiveEntry(work_entry, work_pos), exit_pips, point, dir) + EjectOffsetGet(work_pos)`. This is formula at step time, not captured formula. The captured `work_formula` is unused. That means G4? The work array formula stays but not used. T-2 asks "Is the stored `g_grind_carry_exit_work_formula` used for anything but events?" It is not used at all in the supplied code. But maybe event? The event is emitted inside `Grind_CarryExitShiftLayer` with `formula_exit` param, not array. So answer: no, it's dead. But wait original before fix might have passed `g_grind_carry_exit_work_formula[idx]`? The fix description says step passed captured exit ticket, not formula. The formula was maybe always WorkBase? Let's check original? In prompt: "The carry pass ... For each item Grind_CarryExitShiftLayer ... commits ... if layer has exit order, moves it by accrual (ticket-0 branch ~1086: accrual only)." The fix says "passes the CURRENT exit ticket, and skips... Nothing else changes: not Grind_CarryExitShiftLayer, not Grind_CarryExitPassBegin, not Grind_CarryWorkBase, not the work arrays..." So before fix, step likely passed `Grind_CarryWorkBase(idx, ...)` too, not work_formula. The work_formula array is vestigial. So T-2: stored formula unused. However if it were used for events? No.

Captured entry: If VL GV is present, `Grind_EffectiveEntry` uses VL, so the captured entry is ignored. If no VL, entry from capture. Entry doesn't change. Captured side: side doesn't change. Layer index: layer_index doesn't change. Order of items: If a layer is removed, its item later skipped; if a new layer is added, it is not in work list, so not processed. That is intended? If a new layer fills during the pass, it was not captured, so its exit (if any) is placed by queue at formula with current accrual? Wait new layer's exit placement uses `Grind_ExitQFormulaTarget` which includes `Grind_CarryAccruedGet(position_ticket)`. At that moment, accrued GV may be 0 (new position not processed). But the carry pass for new layer won't process it because not in work list. It will be processed next night. That's normal? The carry pass runs nightly; new layer opening during the window won't get that night's accrual? Actually if it opens during 23:50-00:00, the swap may be applied? MT5 swap is applied at rollover. The pass shifts exits for existing layers before rollover? The window 23:50-00:00 broker. If a new layer opens during the window, its entry may occur before/after rollover. The pass doesn't include it. But it may get swap at rollover? The exit formula might need accrual? Not in scope? T-2: "Can any change mid-pass and matter?" Yes, a new layer not captured, so it is not shifted. But that's by design? The pass captures at Begin. If a new layer fills mid-pass, it will not be processed this pass. Its exit, if placed by queue, uses current accrued GV (0) and thus may be missing that night's accrual if it is held over rollover? But if it opens during 23:50-00:00 before rollover, the swap for that night may be applied to the position at rollover. The carry pass is supposed to shift exits by accrued swap. If the new layer isn't processed, its exit won't be shifted for that night. However it might be processed next night? The next pass will compute ledger swap including the missed night? The ledger is `PositionGetDouble(POSITION_SWAP)` at step time. If the position accrued swap at rollover, the next night's pass will include that swap in ledger and shift the exit by it then. But the exit would be wrong for the entire day after rollover until next pass? Wait carry pass runs nightly in 23:50-00:00. It shifts exits to account for upcoming swap? Let's understand carry: MT5 swap is charged at rollover (00:00 broker). The pass at 23:50 shifts exits by accrued swap + pending tomorrow's swap? Actually `ledger_pips = swap account / ...` from `POSITION_SWAP` (already charged swaps), `pending_pips` from symbol swap rates * mult_tomorrow. So at 23:50 before rollover, it shifts by already accrued swap plus tomorrow's swap? Hmm. The pass is meant to move exits by the carry cost so that the exit price includes carry. If a new layer opens during the pass window, it may not have accrued swap yet. But it might be opened just before rollover, so it will incur swap at rollover. The next pass will include that swap in ledger and shift. But until then, its exit is not accounting for that swap. However the exit is placed by queue with current accrued GV (0) and no pending? `Grind_ExitQFormulaTarget` adds only `Grind_CarryAccruedGet`, not pending. So new layer's exit won't include pending tomorrow's swap. It will be corrected next night. Is that a defect? Possibly but not in scope. The prompt says nothing re-prices a live exit except nightly carry pass and commanded eject. So new layer opened after pass begin but before end will miss that night's carry shift. The fix doesn't address. T-2 asks "Can any change mid-pass and matter?" This is a change: new layer added. It is not in work list, so skipped (not processed). But is that a problem? The pass's work list is captured; new layers are not processed. That was true before fix. The fix doesn't change. But T-2 asks list every value pass still uses from capture; can any change mid-pass and matter? The order of items means new layers not processed. Could matter for RACE? Not the specific races. Should report as residual risk? The instructions say "If you find another place where the pass uses a value captured at PassBegin that can change mid-pass: do not change it; report it." T-2 likely wants this. We need report: The work list itself is captured; layers added after Begin are never processed in that pass. A new layer filled mid-pass will not have its accrual committed nor its exit shifted this pass. If its exit is placed by queue, it uses current accrued GV (likely 0) and no pending carry, so I6 may hold initially (because I6 uses accrued GV 0) but the economic carry is missing until next pass. But I6 uses accrued GV, so it won't halt; it just under-shifts. That's a carry loss for one night if the layer is held over rollover. Is that a defect? The pass is supposed to run nightly. If a layer opens during the window, it might be too late to include? The pass captures at Begin. It could miss layers opened during the 10-minute window. That is a pre-existing limitation. We should note.

But T-2 asks "Is the stored `g_grind_carry_exit_work_formula` used for anything but events?" Answer: It is not used at all in current code. Wait check `Grind_CarryWorkBase` uses `g_grind_carry_exit_work_entry` and `g_grind_carry_exit_work_pos`. It does not use `work_formula`. So yes dead. But maybe in tests? The tests don't inspect. So it's dead. However if it were used for events, the event uses formula_exit param. So no.

Captured layer index: Used for event and comment? In ShiftLayer, `layer_index` passed for event. If layer index changed mid-pass? It doesn't. If a layer is removed and another layer with same index added? Could happen if a layer closes and a new layer fills with same layer_index? Layer indices are assigned by `c_layer` from comment. After a layer closes, the next add fills with `c_layer` from `Grind_SideNextIndex`? Let's see: `Grind_HandleSideDealFill` for ENT calls `Grind_AppendLayer(side, deal_price, position_id, c_layer, ...)` where `c_layer` is parsed from the deal comment. The entry order was placed with `next_layer = Grind_SideNextIndex(side)`, which is max existing layer_index + 1. If a layer with high index closes, the max might drop, and a new layer could reuse the same `layer_index`? Example layers indices 0,1. Layer 1 closes, depth becomes 1 (index 0). Next add uses `Grind_SideNextIndex` = max existing (0) + 1 = 1. So layer index 1 is reused. Thus during a pass, a layer with index 1 could close and a new layer with index 1 could fill. The work item for the old layer has same layer_index but old position_ticket. The lookup by position_ticket finds old layer? If old layer removed, lookup returns false, skip. The new layer with same layer_index but new position_ticket is not in work list. So no wrong event? The event for old layer skipped. If old layer still exists, no reuse. So layer_index captured could match a new layer if old layer removed and new layer added before old item runs. But the lookup uses position_ticket, so it won't find old; it skips. It doesn't process new. So no wrong layer. But what if old layer removed, new layer added with same position_ticket? Not possible. So okay.

Captured side: If a position ticket is on long side, the work item side is long. The new layer with same layer_index but other side? Work item side fixed. Lookup scans long side, won't find. Skip. So no wrong.

Order of items: If a layer is released/demoted, its item may be processed with current exit. That's fix. If a layer is released after processing? T-3.

T-3 Release after processing. A layer processed with ticket 0 (accrual committed) and later released in the same pass. New exit placed by queue via `Grind_ExitQFormulaTarget`. Does that include new accrual? `Grind_ExitQFormulaTarget` code:

double Grind_ExitQFormulaTarget(const double entry,
                                const double exit_pips,
                                const double point,
                                const bool is_long,
                                const ulong position_ticket)
{
   const double accrued = (position_ticket > 0)
                          ? Grind_CarryAccruedGet(position_ticket)
                          : 0.0;
   ...
   return Grind_ExitPrice(eff, exit_pips, point, is_long ? 1 : -1) + accrued + eject_offset;
}

So yes, if ticket-0 branch committed `Grind_CarryAccruedSet(position_ticket, accrued_price)` earlier, later release reads it and places at formula with new accrual. Need check `Grind_CarryExitShiftLayer` ticket-0 branch:

   if(exit_order_ticket == 0) {
      if(Grind_CarryShouldCommitAccrual(false, false, true))
         Grind_CarryAccruedSet(position_ticket, accrued_price);
      return true;
   }

It commits accrual. `Grind_CarryShouldCommitAccrual` not shown, but likely true. Then later queue release uses `Grind_ExitQFormulaTarget` and includes accrued. So I6 holds. But wait: The ticket-0 branch commits `accrued_price = theoretical - formula_exit`. Here `formula_exit` is `Grind_CarryWorkBase(idx, exit_pips, point)` which includes current eject offset and VL. `theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size)`. So `accrued_price` is the shift amount. When queue later places exit, it computes formula = base + accrued. The base in queue is `Grind_ExitPrice(eff, exit_pips, point, dir) + eject_offset`. That matches `formula_exit` if no changes to VL/eject offset between. If VL or eject offset changes mid-pass, then the committed accrual was based on old base, and new exit uses new base, so I6? Let's see. `Grind_ExitQFormulaTarget` uses current VL and eject offset. The committed accrued_price is just the carry shift, independent of base? Actually `accrued_price = theoretical - formula_exit` = `- direction * accrued_pips * pip_size` (since theoretical = formula_exit - dir*accrued_pips*pip_size). So accrued_price does not depend on formula_exit! Wait `Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size)` returns `formula_exit - direction * accrued_pips * pip_size`. So `theoretical - formula_exit = - direction * accrued_pips * pip_size`. So accrued_price is independent of base. Good. So commit is just the carry shift. Later release uses current base + accrued, so correct. So T-3 HOLDS. But need consider if queue release places at formula *without* pending? `Grind_ExitQFormulaTarget` includes only accrued GV, not pending. The pass committed `accrued_price` which includes ledger + pending. So yes.

But there is a subtlety: If the layer was processed with ticket 0 and committed accrual, then later released, the queue's `Grind_ExitQManageSide` may place exit and then if clamped or not, call `Grind_CarryRecordShift` which sets carry shift GV and possibly release marker. I6 uses carry_shift GV. The exit price is formula + accrued + eject. If the exit is placed at that formula, and carry shift GV is set to price - formula (if clamped), then I6 expected = formula + accrued + eject + carry_shift = exit_target. So holds. If not clamped, shift GV deleted (0). So holds. Good.

But what if the layer is released *after* the pass summary and reset? The pass ends, then later tick releases. It uses accrued GV committed. So correct.

T-4 Idempotence and restarts. The carry pass uses gate GV `GRIND_CARRY_DAY_<magic>` marked done only when cursor reaches count and retry_count==0. If restart mid-window, gate not marked done, pass starts again from Begin. It will capture all layers again and process. Accrual computed absolutely? `Grind_CarryExitShiftLayer` computes `swap` from `Grind_CarryPositionSwapVolume`, which for real uses `PositionGetDouble(POSITION_SWAP)` and volume, open_time. It computes `ledger_pips` from current swap. It does not use previous accrued GV to compute new accrual; it computes absolute shift from ledger + pending. Then it commits `Grind_CarryAccruedSet(position_ticket, accrued_price)` where `accrued_price = -dir*accrued_pips*pip_size`. Wait if already shifted last night, the exit price is already at formula + accrued. On a second pass same night, it will compute the same accrued (since swap and pending same) and set accrued GV to same value. Then it moves the exit by accrual again? Let's examine `Grind_CarryExitShiftLayer` for non-zero exit:

   const double theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);
   const double accrued_price = theoretical - formula_exit;
   ...
   double new_exit = theoretical;
   ...
   if(!Grind_ModifyPendingPrice(exit_order_ticket, new_exit, magic)) ...
   if(Grind_CarryShouldCommitAccrual(true, false, true))
      Grind_CarryAccruedSet(position_ticket, accrued_price);
   const double intended = formula_exit + accrued_price;
   const double applied_shift = Grind_Normalize(new_exit) - intended;
   Grind_CarryRecordShift(position_ticket, applied_shift, clamped_out);

Wait: It sets `new_exit = theoretical = formula_exit + accrued_price`. But `formula_exit` is `Grind_CarryWorkBase` which is the base without accrued. So it modifies the exit to base + accrued. That is the absolute target, not a relative shift. So if run twice, it modifies to the same price again. It does not double the shift. Good. It sets accrued GV to same value. So idempotent for non-zero exit.

For ticket-0 branch: commits `Grind_CarryAccruedSet(position_ticket, accrued_price)`. Same absolute value. So idempotent.

But what about a restart mid-pass where some exits already shifted? The second pass will recompute from current swap. The swap may have changed? If restart after rollover, server time/swap may differ. But within same night, same. It will re-modify them to same target. If some exits were already shifted, modifying again to same price is okay. But note: For layers that were already processed and had their exit moved, when the second pass runs, the work list is re-captured. It will include them again. For each, it computes `formula_exit` from current live VL/eject offset (unchanged). It then moves to base + accrued. Same. So no double. Good.

However, there is a subtle issue: The pass summary and gate mark done. If restart happens after some items processed but before completion, gate not done. Second pass starts. But the first pass may have already incremented `g_grind_carry_exit_shifted` etc. Those are reset in `Grind_CarryExitPassBegin`. So counters reset. Fine.

What about a restart mid-pass where some exits were shifted and some not. The second pass will process all. For already shifted, it re-modifies. But the modify might fail if the order is not found? If the exit is still resting, fine. If it was filled/closed, lookup skips. Good.

What about a restart after the pass completed and gate marked done? Then no second pass. Good.

What about a restart during the window after gate marked done? `Grind_CarryGateDue` checks stored day. If gate marked done, stored == day_of_year, so `Grind_CarryGateDue` returns false. So pass doesn't start. Good.

But T-4 asks: "Is the accrual computed absolutely (ledger + pending) so a second pass commits the same value, not a double?" Yes. Need quote: `const double accrued_pips = ledger_pips + pending_pips;` and `Grind_CarryAccruedSet(position_ticket, accrued_price);` and `theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);` It uses absolute formula. So HOLDS. But wait: `Grind_CarryAccruedSet` sets the *accrued shift*, not the total accrued since entry? The ledger_pips is from `POSITION_SWAP`, which is total accumulated swap for the position since open. So `accrued_price` is the total carry shift since open, not just tonight's. The pass sets it to total. So second pass same. Good.

What does a restart mid-pass do to exits already shifted? They are re-shifted to same target. No harm. But what if the restart happens after the rollover (00:00) and before next 23:50? The gate window is only 23:50-00:00. If restart mid-window after rollover? Window ends at 00:00. At 00:00, `Grind_CarryGateInWindow` returns false. The pass on window close emits incomplete summary and resets. If restart after 00:00, no pass. But if restart at 23:59:59, second pass may run with new day? The gate stored day is previous day? `Grind_CarryGateStoredDay` returns day_of_year. At 00:00, window closes. The pass may not complete. Then next day's window will run again. But the accrual computed next day will include the swap from the rollover? That might be correct. Not an issue.

Potential T-4 issue: The gate mark done is only called when `cursor >= count && retry_count == 0`. If the pass is incomplete at window close, `Grind_CarryExitPassOnWindowClose` resets but does NOT mark gate done. So next day it will run again. That is intended to retry. But if it never completes, it runs every night. Not double because absolute. Good.

But there is a subtle bug: `Grind_CarryGateDue` checks `if(stored == dt.day_of_year) return false;`. It does not check year. If the EA runs across new year, day_of_year resets. But gate GV stores day_of_year only. On Jan 1, day_of_year=1. If previous stored day was 1 from Jan 1 last year? It would incorrectly skip? But gate is reset? Not relevant.

T-5 Halted or quarantined instance. The carry step runs in `OnTimer` regardless of halt. `OnTimer` calls `Grind_CarryOnTimerStep` unconditionally. In `OnTick`, if halted, it returns before engine, but OnTimer still runs. So a halted instance's pass will still modify exits. The fix changes what it does: It looks up live book. If halted due to invariant failure, the book may be wrong. Previously it used captured tickets, which might also be wrong. The fix doesn't change the fact that it runs. But it may skip missing/closing layers. Was it already so before? Yes, carry pass always ran in OnTimer regardless of halt. The fix doesn't introduce running while halted. But does it change behavior? Before, it would use captured exit tickets; if book is wrong, it might modify an order that is no longer associated? Now it looks up current book, which may be wrong. But same. T-5 verdict: HOLDS? Or NEEDS-FIX? The threat asks "Does the fix change what a halted instance's pass does (modifies exits of a book that invariants say is wrong)? Was that already so before the fix?" The fix does change: it now looks up the live book and may skip layers missing from a corrupt book, or modify the current exit of a layer that is still present. Before, it would blindly modify captured ticket even if the book was corrupt. But since it already ran while halted, the risk existed. The fix arguably reduces risk for missing/closing layers. However, if the book is corrupt and contains a layer with a wrong exit_order_ticket (e.g., an orphan), the fix might modify it. But before it used captured ticket which might be the same. Not a new regression. We can say HOLDS/NEEDS-FIX? The prompt's ruled items don't mention halt. The audit should flag if carry pass should be gated by halt. But it's pre-existing. T-5 asks verdict. I'd say HOLDS (pre-existing; fix does not worsen, and skipping missing/closing is safer). But if we find that the fix now skips a layer that is in the live book but closing, committing nothing, whereas before it might have modified a captured exit? Actually before, if a layer was closing, the captured exit ticket might be non-zero? At capture, it had an exit. Mid-pass, the exit filled and became a position, exit_order_ticket=0. Before fix, it would call ShiftLayer with captured non-zero ticket. The order no longer exists, so modify fails, accrual not committed. After fix, it skips, commits nothing. So no worse. If the book is corrupt, the fix could skip a layer that is missing but still has an exit order? If missing from book but exit order exists, that's orphan; skipping leaves it unshifted. Before, it might have modified the captured exit order (still resting) using the captured ticket, even though layer missing. That would shift the orphan exit. After fix, it skips, leaving orphan exit unshifted. But if book is corrupt/halted, maybe not important. However, T-5 asks if fix changes what a halted instance's pass does. Yes: it may skip layers no longer in the book, so it no longer shifts orphan exits. But in a halted state, invariants say book is wrong; modifying exits could be dangerous. Skipping is safer. So HOLDS.

But there is a subtlety: `Grind_CarryExitPassStep` is called from `Grind_CarryOnTimerStep` in OnTimer. It does not check `g_grind_halted` or `g_grind_quarantined`. So a halted instance still runs the pass. This is a pre-existing issue. The fix doesn't change. We can note as NEEDS-FIX? The prompt says "Nothing re-prices a live exit except the nightly carry pass and a commanded eject." If halted, should it re-price? Maybe the halt is due to I6 failure; the carry pass is the only thing that can fix it? Actually if halted due to I6, the pass might re-price and fix? But if halted, OnTick doesn't run, but OnTimer does. The pass could shift exits and maybe fix I6? But I6 is checked in OnTick, which is halted. So instance stays halted. Re-pricing while halted might be okay. Not a defect.

T-6 Counts and events. The skip adds to `g_grind_carry_exit_skipped`. The pass summary and pipshed report (carry clamps C26 use `clamped`, not `skipped`). Any consumer that now misreads a closing layer as a sign-guard skip? `g_grind_carry_exit_skipped` is also incremented inside `Grind_CarryExitShiftLayer` for sign guard and for ledger failure. In the new skip branch, it increments `skipped` before calling ShiftLayer. So the same counter conflates three reasons: layer absent/closing, sign guard blocked, ledger conversion failed. The summary only has `skipped`. Previously `skipped` was incremented for sign guard and ledger failure. Now closing/missing adds to it. A consumer that interprets `skipped` as sign-guard skips will misread. The prompt says "carry clamps C26 use `clamped`, not `skipped`". But the summary includes `skipped` without reason. The event `CARRY_EXIT_SHIFT` has `sign_guard_skipped` true. For absent/closing, no event is emitted. So the only signal is the counter. If downstream pipshed uses `skipped` to alert on sign guards, it will now see extra. T-6 verdict: BREAKS or NEEDS-FIX? It's a reporting conflation. The fix description says count as skipped. Gemini accepted CG2. But the threat asks if any consumer misreads. We can say NEEDS-FIX if there is a consumer. We don't have pipshed code. But the summary `CARRY_PASS_SUMMARY` field `skipped` is now ambiguous. The smallest fix: add a new counter or event for closing/missing, or emit an event. But the prompt says don't change summary format. However audit can recommend. I'd say NEEDS-FIX (or at least WARN). Need quote: `g_grind_carry_exit_skipped++;` in step and in ShiftLayer sign guard. We can show.

T-7 Cost. Helper copies side struct per item. MQL5 semantics. Need determine if `const GrindSideState side = is_long ? g_grind_long : g_grind_short;` is legal and deep copy. In MQL5, structures with dynamic arrays cannot be copied by value? Let's recall exactly. MQL5 documentation: "Structures can contain dynamic arrays. Such structures cannot be copied using the assignment operator." Actually I think MQL5 does not allow copying structures containing dynamic arrays. Let me search memory: In MQL5, you cannot use structures with dynamic arrays as function parameters by value. But you can assign? Example: struct A { int x[]; }; A a; A b = a; // error? I recall "Structures containing dynamic arrays cannot be copied." If that's true, the code would not compile. But the prompt says tests passed 1882/1882. So either MQL5 supports it or the struct doesn't contain dynamic array? Wait `GrindSideState` has `GrindLayer layers[];` which is a dynamic array of structs. So it does contain dynamic array. The code `const GrindSideState side = is_long ? g_grind_long : g_grind_short;` would be a copy. If MQL5 disallows, compile fails. Since tests passed, maybe MQL5 does support copying dynamic arrays in structs? Let's verify from MQL5 docs: "Structures can contain arrays of simple types, but cannot contain dynamic arrays." Actually I think MQL5 structures cannot contain dynamic arrays at all? But the code clearly has `GrindLayer layers[];` inside GrindSideState. Wait maybe MQL5 allows dynamic arrays in structures as members? I recall MQL5: "A structure cannot contain a dynamic array." Let me think. In MQL5, you can declare dynamic arrays as structure members? I've seen MQL5 code with dynamic arrays in structs? Actually MQL5 does not support dynamic arrays inside structures? Let's check memory: MQL5 structures can contain simple types, strings, and other structures, but not arrays? Hmm. I have seen MQL5 code: `struct MyStruct { int array[]; };` I think it's allowed? There is a note: "Structures containing dynamic arrays cannot be used as MqlParam parameters." But they can be members. Assignment? I'm not sure. Since the code is from a tested repo, it compiles. So MQL5 must support it. The copy may be deep or shallow. If shallow, both structs share the same dynamic array. But since the helper only reads, and no modifications occur during the call (single-threaded), even shallow is fine. However, the copy is created each call. If shallow, it might copy the array pointer; the array size and elements are current. No stale. If deep, it copies all elements; more cost but up to 8 layers, negligible. T-7 HOLDS. But we should mention ASSUMED MQL5 deep-copies or at least read-consistent; no aliasing mutation within call. Smallest fix: take a const reference instead of value to avoid copy. But not necessary. Actually we can suggest `const GrindSideState &side = is_long ? g_grind_long : g_grind_short;` but can you bind a reference to conditional expression? In MQL5, maybe not. Could use pointer. But cost is trivial. T-7 HOLDS.

T-8 Repair runbook. If race fires before deploy: delete mispriced EXT order by hand, reattach only that chart; reconstruction's startup shortfall tolerance (ADR-156) accepts missing required exit and `Grind_RetryMissingExits` re-places it at its formula. Does any invariant, recon step or other GV (release marker, carry shift) make that fail or place it wrong?

We need examine. The runbook: delete the mispriced EXT order manually, reattach chart. On init, `Grind_ReconstructState` runs. It collects broker tickets. The missing exit order is absent. The position exists with comment ENT. In `Grind_RebuildBookFromTicketsInner`, for each layer, if `has_position` and `Grind_ExitQRequired(rank, count)` and `!has_exit_coverage`, and `tolerate_exit_shortfall` is true (called from OnInit with `true`), it increments `g_grind_recon_exit_shortfall_long` and continues. So it tolerates missing exit. Then it builds the layer with no exit_order_ticket, and sets `exit_target = Grind_ExitQFormulaTarget(entry, exit_pips, point, is_long, position_id)`. This includes current accrued GV and eject offset. The accrued GV is still present? The mispriced exit was shifted by carry pass? Wait the race: RACE 1: layer held at capture, released before item runs. Its item carries ticket 0, so commits new accrual but doesn't move new exit. The new exit was placed at yesterday's accrual. So the exit order is mispriced by one night's swap. The accrued GV has been set to the new accrual. So when we delete the EXT order and reattach, recon will see no exit, tolerate shortfall, and set exit_target = formula + accrued (new) + eject. Then `Grind_RetryMissingExits` calls `Grind_ExitQManageSide` which will place the missing exit at `Grind_ExitQFormulaTarget` using the current accrued GV and eject offset. That should place at correct price. But wait: Does recon reset or delete GVs? `Grind_ReconstructState` calls `Grind_ReconResetSide(g_grind_long)` etc. It does not delete carry GVs. `Grind_CarryPruneShiftGvs(InpMagic)` is called after reconstruction in OnInit. That prunes shift GVs for tickets that no longer exist as positions. The position still exists, so GVs remain. But what about `GRIND_CARRY_SHIFT_` GV? The mispriced exit had a carry shift recorded? In RACE 1, the new exit was placed by queue. When queue places an exit, it may call `Grind_CarryRecordShift` if clamped. The carry shift GV for the position was set/deleted. The exit is mispriced by one night's swap, but the carry shift GV might be 0 (if not clamped) or some clamp residual. The accrued GV is correct (new). The exit order price is wrong because it was placed at formula + old accrued. I6 expected = formula + accrued (new) + eject + carry_shift. If carry_shift is 0, expected = formula + new accrued. Actual exit = formula + old accrued. Diff = new-old = one night's swap. I6 fails. When we delete the exit and recon places new exit at `Grind_ExitQFormulaTarget` = formula + accrued (new) + eject. If not clamped, it calls `Grind_CarryShiftDelete(position_ticket)`? In `Grind_ExitQManageSide`, after placing:

      if(clamped || MathAbs(price - formula) > _Point * 0.5) {
         Grind_CarryRecordShift(side.layers[i].position_ticket, price - formula, true);
      } else {
         Grind_CarryShiftDelete(side.layers[i].position_ticket);
      }

Here `formula` is `Grind_ExitQFormulaTarget` (includes accrued). So if price == formula, it deletes carry shift. So carry shift GV becomes 0. I6 expected = formula + accrued + eject + 0 = price. Holds. If clamped, it records shift = price - formula, and release marker. I6 includes carry_shift. Holds. So runbook seems sound.

But need check if recon's startup shortfall tolerance actually allows missing required exit. In `Grind_RebuildBookFromTicketsInner`, for each side, it checks `if(long_scratch[i].has_position && Grind_ExitQRequired(rank, long_count) && !Grind_ReconLayerHasExitCoverage(long_scratch[i])) { if(tolerate_exit_shortfall) { g_grind_recon_exit_shortfall_long++; continue; } ... }`. So yes. Then later `Grind_ReconCheckInvariants` is called with `tolerate_exit_shortfall` true. It also skips I3 for missing coverage. So recon succeeds. Then `Grind_RetryMissingExits` is called in OnInit:

      if(a + b > 0) {
         Print("WARN STARTUP_EXIT_SHORTFALL long=", a, " short=", b);
         ...
      }
      Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);

`Grind_RetryMissingExits` calls `Grind_ExitQManageSide` for both sides. That will place missing exits for required ranks. But wait: `Grind_ExitQManageSide` uses `Grind_ExitQRequired(ranks[i], n)`. For the layer missing exit, rank must be required (rank 0 or highest). In RACE 1, the layer was held and released by queue. It was likely rank 0 or highest? The exit queue only keeps rank 0 and highest. The race occurs for a layer that was held at capture and released before its item ran. It had no exit at capture, so it was not required? Wait if it had no exit at capture, why did queue release it? The queue releases exits when ranks change. A held layer with no exit could become required due to rank change. So at capture, it was not required (maybe rank middle), so no exit. Mid-pass, another layer closed, it became required (rank 0 or highest), so queue placed an exit. That exit was placed at yesterday's accrual (because accrued GV hadn't been updated yet? Actually the carry pass commits accrual for each layer. The layer's item hadn't run yet, so its accrued GV was still yesterday's. The queue placed exit using yesterday's accrued. Then the pass item runs, sees ticket 0 branch (captured exit 0), commits new accrual, but doesn't move the newly placed exit. So the exit is mispriced.) After the instance halts, the layer is still in the book with an exit order (mispriced). The runbook deletes that EXT order. Then recon sees the position without exit. Its rank is still required (rank 0 or highest). So `Grind_ExitQRequired` true. Tolerate shortfall. `Grind_RetryMissingExits` places it at formula with current accrued (new). Correct.

But what if the layer is not required after reattach? If its rank changed? The position set is same. If it was required before, it remains required unless other layers closed. If other layers closed, it might be middle rank and not required. Then `Grind_ExitQManageSide` will not place an exit. But the runbook says "re-places it at its formula". If the layer is no longer required, it won't be re-placed. But then it shouldn't have an exit anyway (queue holds only required). If it was mispriced EXT, it was required at the time. If between halt and reattach another layer closes, the rank could change. But the operator reattaches only that chart immediately. Other instances? Each instance is per chart. The book for this instance? Actually one EA instance per chart? Wait "Eleven instances per terminal share global variables". Each chart runs an EA instance with same magic? No, each instance has its own magic? The system: eleven instances per terminal share GVs. Each side holds filled layers... The pass runs per instance? The prompt says "The carry pass (`grind_carry.mqh`) runs in the 23:50-00:00 broker window from `OnTimer`, 2 work items per 60 s step." Each instance has its own magic and own book? Actually `g_grind_long` and `g_grind_short` are global variables per EA instance? In MQL5, global variables are per terminal? Wait MQL5 global variables (GVs) are terminal-wide. But `g_grind_long` is a program variable, not a terminal GV. Each EA instance has its own copy of global variables? In MQL5, global variables declared in the EA are per instance (per chart). Terminal GVs are shared. The prompt says "Eleven instances per terminal share global variables (GVs)." So they share terminal GVs like GRIND_CARRY_ACCRUED_<position_ticket>. The book `g_grind_long` is per instance. Each instance manages its own magic? Actually the system may have multiple instances for different slots/magics? The prompt says "Eleven instances per terminal share global variables". So the GVs are shared across instances. The position tickets are unique across account. The carry pass runs in each instance. The race affects one instance. The runbook says reattach only that chart. So the book for that instance is rebuilt. Other instances' books are unaffected. The layer's rank is computed within that instance's book. If other layers in that instance changed, rank could change. But if the instance was halted, no ticks processed, so book unchanged. Reattach rebuilds from broker. The set of positions/orders for that magic/slot may have changed? The halt stops trading, but other instances with different magic? The position belongs to this instance's magic. Other instances with different magic don't affect this book. So rank likely same. If the layer is no longer required, it means another layer with better rank exists? But the set is same as before. The missing exit was required before. So it will be required after. Unless the queue had also cancelled other exits? But halt stops ticks. So likely fine.

Potential issue: The `GRIND_CARRY_SHIFT_` GV for the position. When the mispriced exit was placed by queue, it may have called `Grind_CarryRecordShift` or `Grind_CarryShiftDelete`. If it was mispriced by one night's swap but not clamped, it likely called `Grind_CarryShiftDelete`, so shift GV is 0. If it was clamped, shift GV is non-zero. When we delete the EXT order manually, the shift GV remains. Recon sets `exit_target` using `Grind_ExitQFormulaTarget` which includes accrued + eject, but does NOT include carry shift. Wait `Grind_ExitQFormulaTarget` does not include carry shift. It includes accrued + eject. The shift GV is separate. In recon, when a layer has exit coverage, it uses the exit's price as `exit_target`; when no coverage, it computes `exit_target = Grind_ExitQFormulaTarget(...)`. This does not include carry shift. Then later `Grind_ExitQManageSide` places at `formula` (same) and then if not clamped, deletes carry shift. So the old shift GV is deleted. If clamped, it records new shift. So the old shift GV is overwritten/deleted. So no stale shift. Good.

What about `GRIND_CARRY_RELEASE_PREFIX` GV (release marker)? If the old exit was clamped, `Grind_CarryRecordShift` set release marker to 1. When we delete the exit and recon places new, if not clamped, `Grind_CarryShiftDelete` deletes both shift and release GVs. If clamped, `Grind_CarryRecordShift` sets release marker to 1 again. So no stale. If recon doesn't place because not required, the shift GV remains? But if not required, no exit. The position is held. The shift GV might remain from old exit. But `Grind_CarryShiftGetForRecon` is used in I6 only if layer has exit coverage. If no exit, I6 not checked. The shift GV could affect future? When later released, `Grind_ExitQManageSide` uses `Grind_ExitQFormulaTarget` (ignores shift) and then sets/deletes shift. So old shift is overwritten. Not a problem.

But wait: In recon, for layers with no exit coverage, it sets `exit_target = Grind_ExitQFormulaTarget(...)`. That includes accrued. Then `Grind_RetryMissingExits` places exit at `Grind_ExitQFormulaTarget` and if not clamped deletes shift. So correct. But what if the layer has an exit order that is present but mispriced? The runbook says delete it. If operator deletes it, recon sees no exit. If operator forgets to delete, recon will see the mispriced exit and use its price as `exit_target`. Then I6 will fail because accrued GV is new and exit price is old. Recon would fail? Actually `Grind_RebuildBookFromTicketsInner` with tolerate_exit_shortfall true still checks I6 for layers with exit coverage. It calls `Grind_ReconCheckInvariants` with tolerate_exit_shortfall. In that function, for layers with exit coverage, it does NOT skip I6. It computes expected with accrued and shift and compares to exit_target. The mispriced exit has diff = one night's swap > 2 points. So I6 fails, recon fails, instance halts again. So runbook requires deleting the mispriced EXT. If done, sound.

Any other GV? The `GRIND_CARRY_DAY_<magic>` gate GV. When reattaching during the carry window? The runbook likely after halt, which could be during the night. If reattach during 23:50-00:00, the gate may be due or done. If the race fired before deploy, the instance halted. The halt likely occurred after the carry pass, maybe shortly after. If operator reattaches during the same carry window, `Grind_CarryGateStoredDay` may not be marked done because the pass didn't complete? Wait the race: layer held at capture, released before its item ran. Its item carries ticket 0, commits new accrual but doesn't move new exit. Then the pass continues. At the end, if all items processed, it emits summary and `Grind_CarryGateMarkDone(magic, now)`. So the gate is marked done. The I6 failure is detected on next OnTick, which could be after the window. So when operator reattaches, the gate stored day is marked done. On init, `Grind_CarryEmitSnapshot` and `Grind_CarryPruneShiftGvs` run. `Grind_CarryOnTimerStep` will check gate due. If stored day == current day, it won't start the pass. So the pass won't run again that night. That's okay because the accrual is already committed and the runbook re-places the exit. But what if the reattach happens *before* the gate is marked done? If the instance halted mid-pass? The race causes I6 failure on next OnTick. The pass may still be active? Actually the pass runs in OnTimer. If it halts, OnTimer still runs. But the operator may reattach immediately. The gate might not be marked done if pass incomplete. On init, the pass state is reset (global variables reset to defaults). The gate is not marked done. Then in the carry window, `Grind_CarryGateDue` returns true, and the pass starts again. It will capture layers including the one just re-placed. It will compute accrual and shift again. Since accrual is absolute, it will set the same and move exit to same target. So no double. Good.

So T-8 HOLDS. But need check ADR-156 startup shortfall tolerance: `Grind_StartupShortfallCritical(a, b)` maybe halts if too many shortfalls? Not shown. If it halts, `Grind_RetryMissingExits` still called? In OnInit:

      if(a + b > 0) {
         Print("WARN STARTUP_EXIT_SHORTFALL long=", a, " short=", b);
         Grind_ArchiveMarker(...);
         if(Grind_StartupShortfallCritical(a, b))
            Grind_TelemetryCritical(...);
      }
      Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);

Even if critical, it doesn't halt? It just telemetry. It still calls RetryMissingExits. So sound.

T-9 Tests. Which new behaviour has no test that fails without it (short side; a layer missing from the book; a release AFTER processing)? Does any assertion pass vacuously?

The new tests: CR1_ReleasedMidPass (long side, layer captured with NO exit, then release simulated). This tests release before processing. It fails without fix (CR1 exit moved, CR1 I6 holds). CR2_DemotedMidPass (long side, exit captured then cancelled). Tests demotion before processing. Fails without fix. CR3_ClosingMidPass (long side, exit filled, closing). Tests skip branch. Passes both by design. Missing tests: short side. The helper has `is_long` parameter. Tests only long. If the helper accidentally used long side for short, no test. A layer missing from the book (not just closing, but removed entirely). CR3 tests closing (exit_position_ticket != 0) but layer still in book. It does not test layer removed from book (e.g., position closed and layer removed). The new branch `if(!Grind_CarryCurrentExitTicket(...) || closing)` handles both absent and closing. CR3 tests closing (returns true, closing true). No test for absent (returns false). So the `!helper` branch is untested. A release AFTER processing: CR1 tests release before processing (capture no exit, then set exit, then step). It does not test a layer processed with ticket 0 (accrual committed) and then released later in the same pass, then the queue's new exit uses the committed accrual. That is T-3. No test. Also no test that a second pass (restart) doesn't double. No test for missing layer skip not committing. No test for `skipped` counter. No test for wrong side. Also "Does any assertion pass vacuously?" Check CR1: `AssertTrue("CR1 accrued", MathAbs(Grind_CarryAccruedGet(pos)) > 1e-12);` This passes in both states. It is designed to pass. But could it pass vacuously? The setup seeds swap -0.10, so accrued should be > 0. It asserts precondition. Not vacuous. `CR1 accrued beyond I6 tolerance` also precondition. `CR1 exit moved` fails without fix, so not vacuous. `CR1 I6 holds` fails without fix. CR2: `CR2 cancelled` asserted before step. It checks `exit_order_ticket == 0 && !Grind_OrderTestFind(exit_ticket, rec)`. This is precondition, passes both. `CR2 accrual committed` fails without fix. CR3: `CR3 closing not shifted` asserts `MathAbs(Grind_CarryAccruedGet(pos)) <= 1e-12`. This passes both because setup doesn't commit accrual? Wait in CR3, layer captured with exit, then fill simulated, then step. The step sees closing and skips, so no accrual committed. The assertion checks accrual is <= 1e-12. But is there any prior accrual? `F2_TestClearPositionCarry(pos)` clears. So initially 0. The step skips, so remains 0. So passes. But does it pass vacuously? It would also pass if the step crashed and never ran? The test calls step. If step returned early due to not in window? `g_grind_carry_test_server_time` is set by `F2_TestSeedCarryWindow(magic)`. Need check what that does. It likely sets server time in window. So step runs. If the fix didn't exist, the step would call ShiftLayer with captured exit ticket (which was removed from order test? Actually CR3 setup: after capture, `Grind_OrderTestRemove(exit_ticket); g_grind_long.layers[0].exit_order_ticket = 0; exit_position_ticket = exit_pos;` Then step. Without fix, it would call ShiftLayer with captured exit_ticket (non-zero). In ShiftLayer, it tries `Grind_ModifyPendingPrice(exit_order_ticket, ...)`. The order was removed from test order book, so `Grind_SelectOurOrder` fails, returns false. It increments `failed`, does NOT commit accrual. So accrual remains 0. So assertion passes without fix. That's why CR3 is PASS in both. So it's not vacuous in the sense it tests that the new skip branch doesn't commit, but it also passes without fix because the modify fails and doesn't commit. It doesn't distinguish skip from failed modify. So it locks the new branch against committing, but it would pass even if the branch didn't exist. The prompt says "CR3 locks the new skip branch against committing; list them as such." So it's a guard, not a failing test. The missing tests are short side, missing layer, release after processing.

Also, the tests use `Grind_CarryExitPassBegin` to build work list. For CR1, after capture, they manually set `g_grind_long.layers[0].exit_order_ticket = exit_ticket` and upsert order. That simulates release. But they do not call `Grind_ExitQManageSide` which would be the real release path. They manually set the layer's exit_order_ticket and upsert order. That bypasses queue logic. It doesn't test that the queue placed the exit at the wrong price (yesterday's accrual). In CR1, they upsert the order at `formula` (1.25030) which is the base formula without accrued. Then the step shifts it to base+accrued. The assertion checks I6 holds. This tests that the step moves the current exit. But does it reproduce the actual race? In the actual race, the queue places the new exit at `Grind_ExitQFormulaTarget`, which includes the *current* accrued GV. At the time of release mid-pass, the layer's accrued GV is still yesterday's value (or 0 if first night). In the test, they upsert at `formula` (base without accrued), and the accrued GV is initially 0 (cleared). So the queue would have placed at formula + 0 = formula. So it matches first night. If there was a previous accrual, the test would need to seed accrued. They don't. So CR1 only tests first night (accrued 0 before). The defect is one night's swap. If there was already previous accrued, the mispriced exit would be at formula + old accrued, and the step should move to formula + new accrued. The test doesn't cover that. But the fix uses current exit ticket and passes `Grind_CarryWorkBase` as formula, so it moves to new accrued regardless. The test with old accrued 0 is sufficient to fail without fix? Without fix, step sees captured exit 0, commits new accrual but doesn't move exit. Exit remains at formula. I6 expected = formula + new accrued. Fails. So it catches. With old accrued non-zero, it would also fail. So okay.

But CR2: They capture with exit 99312, then `Grind_ExitQHoldCancelLayer` cancels it. This is real queue function. Then step should commit accrual via ticket-0 branch. Without fix, step passes captured exit 99312, tries modify, fails (order cancelled), does not commit accrual. Test checks accrual committed. Good. This tests demotion before processing.

Missing: release AFTER processing. To test, need capture with no exit, run step (commits accrual), then simulate queue release (set exit_order_ticket and upsert at formula + accrued? Actually queue would place at formula + accrued because accrued now set). Then assert I6 holds. The fix doesn't change this, but it's a new behavior? Actually it's existing behavior. The threat asks which new behaviour has no test. Release after processing is not directly changed by fix, but it's the complementary race. Not tested.

Also missing: short side. The helper has `is_long` parameter; if it always scanned long, CR1/CR2/CR3 would pass? If helper always scanned long, for short tests it would fail. But no short tests. So short side untested.

Missing: a layer missing from the book entirely. CR3 uses closing (exit_position_ticket != 0) but layer still in book. The `!helper` branch (not found) is not tested. If the helper returned true for missing? It returns false. If the step accidentally didn't skip on false, it would process with stale ticket. No test.

Missing: Does any assertion pass vacuously? CR3 passes without fix, as noted. The precondition assertions pass in both. CR1 accrued and CR1 accrued beyond I6 tolerance are preconditions; they pass because `F2_TestSeedCarryWindow` and swap -0.10 ensure accrual > 0? Wait in CR1, the step with fix calls ShiftLayer with current_exit = 99311. It computes accrued and commits. Without fix, step passes captured exit 0, ticket-0 branch commits accrual. So in both, accrual is committed. So "CR1 accrued" passes in both. It is not vacuous; it confirms the ticket-0 branch ran. But it would also pass if the step did nothing? No, if step did nothing, accrual would be 0. So it tests that step ran and committed. Good.

CR2 "CR2 accrual committed" fails without fix because modify fails and does not commit. With fix, lookup finds layer with exit_order_ticket 0 (after cancel), calls ShiftLayer with 0, ticket-0 branch commits. So passes. Good.

Now PREMISE VERDICT: does the live-book lookup close RACE 1 and RACE 2 completely? Need assess. RACE 1: layer held at capture, released before item runs. Fix: step looks up live book, finds layer, current_exit = new exit ticket, passes to ShiftLayer. It modifies the new exit by accrual. So I6 holds. Closes RACE 1. RACE 2: layer with exit at capture, cancelled before item runs. Fix: lookup finds layer, current_exit = 0 (since cancelled), calls ShiftLayer with 0, ticket-0 branch commits accrual. So when later released, queue uses committed accrual. Closes RACE 2. But need check if there are remaining holes: The lookup is by position_ticket and side. If the layer is missing (closed), skip. If closing, skip. That covers. What about a layer that is released after its item runs (ticket 0 processed, then release later)? That's not a race; it's handled by accrued GV. What about a layer whose exit is cancelled and re-released later in the pass? If its item runs while cancelled (ticket 0), it commits accrual. Later release uses committed. Good. If its item runs while new exit exists, it modifies new exit. If later cancelled again, the modify might have happened, then cancel deletes carry shift? But `Grind_ExitQHoldCancelLayer` calls `Grind_CarryShiftDelete(layer.position_ticket)` when cancelling. That deletes the carry shift GV, but not the accrued GV. So the exit is cancelled; later release uses accrued. The modified exit is gone. No issue. If the exit was modified to include carry, then cancelled, the accrued GV remains. Later release places at formula + accrued. Correct. So RACE 1 and 2 closed.

But is there a remaining race: A layer processed with ticket 0 (accrual committed), then released later in the pass. The queue places exit at `Grind_ExitQFormulaTarget` which includes accrued. But what if the queue places the exit *before* the pass item runs? That's RACE 1 fixed. What if the queue places the exit *after* the pass item runs but before the pass ends? The pass item already committed accrued. The queue uses accrued. Correct. What if the queue places the exit *during* the pass item? Single-threaded, no interleaving inside timer step. So no.

What about a layer that is released and then its item runs, but the release happens *after* the lookup but before ShiftLayer? Cannot, single-threaded. So complete.

However, there is a subtle remaining hole: The step's lookup uses `g_grind_carry_exit_work_long[idx]` to choose side. But what if the layer's side changed? Not possible. What if the position ticket is on the other side due to a bug? Then helper returns false and skips, leaving accrual uncommitted. But that would be an invariant violation. Not normal.

Another hole: The helper scans the live book, but the live book may contain a layer with the same position_ticket but different `layer_index`? Not possible.

Another hole: The fix skips a layer that is closing (`exit_position_ticket != 0`). But what if the layer is closing and its position is about to close via CloseBy, and the close path deletes the accrual GV anyway? Gemini CG2 says the close path deletes the accrual GV when CloseBy completes. But what if the CloseBy does not complete? The layer remains closing, no accrual committed. Could that lose a night's carry? The position still exists with an opposite position pending CloseBy. The exit is filled. The position's carry may not be shifted. But the exit is already filled, so no resting exit to shift. The close will happen. The accrual is irrelevant because the position is closing. If CloseBy fails, the instance might halt? Not sure. But not a carry exit shift issue. So okay.

Another hole: The fix commits nothing for a layer missing from the book. If a layer is missing but its position still exists (book corrupt), its accrual is not committed. But book corrupt means invariant failure. Not normal.

So PREMISE VERDICT: The live-book lookup closes RACE 1 and RACE 2 completely for the normal single-threaded execution and valid book. But it does not close the pre-existing gap of layers added after PassBegin (not processed) and it conflates skip reasons. Also halted/corrupt book. We can state closes RACE 1 and 2, with residual T-2/T-6.

Now need produce output with quotes. Need cite file, function, quote one line or part. We have no line numbers. We can cite function and quote code line. Need be precise. The prompt says "cite file, function and QUOTE the line (one line, or part of one)." So for each claim, include quote.

Let's organize.

GIVENS CHECK:

G1: VERIFIED. Quote from `grind_carry.mqh` function `Grind_CarryCurrentExitTicket`:
`exit_ticket_out = side.layers[i].exit_order_ticket;`
`closing_out = (side.layers[i].exit_position_ticket != 0);`
`return true;`
and `return false;`. We can quote one line: `closing_out = (side.layers[i].exit_position_ticket != 0);` and `return false;`. Also note it sets both 0/false at start.

G2: VERIFIED. Quote from `Grind_CarryExitPassStep`:
`if(!Grind_CarryCurrentExitTicket(g_grind_carry_exit_work_pos[idx],`
`g_grind_carry_exit_work_long[idx],`
`current_exit, closing)`
and later `current_exit,` passed to `Grind_CarryExitShiftLayer`. Quote: `Grind_CarryExitShiftLayer(g_grind_carry_exit_work_pos[idx],` `current_exit,`.

G3: VERIFIED. Quote:
`g_grind_carry_exit_skipped++;`
`processed++;`
`continue;`
Nothing else in that branch.

G4: VERIFIED (observable). Need quote that helper not used in those functions. For `Grind_CarryExitShiftLayer`, quote its signature and note no `Grind_CarryCurrentExitTicket`. For `Grind_CarryExitPassBegin`, quote `Grind_CarryExitPassAppendWork(layer.position_ticket, layer.exit_order_ticket,` showing it still captures exit. For `Grind_CarryWorkBase`, quote its body. For event format, quote `Grind_CarryEmitExitShiftEvent` fields? We can say the helper is not called in these; no diff available. Maybe mark "VERIFIED (no reference to helper; supplied code shows original capture still in Begin)". But G4 says unchanged by 6831436. Without diff, can't prove. I can say "VERIFIED as far as the supplied code shows; no counterevidence." But the instruction says verify each. We can say "VERIFIED (observable in final code; the fix helper is absent from these functions)". That's acceptable.

G5: VERIFIED. Quote `Grind_CarryWorkBase`:
`return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx],`
`g_grind_carry_exit_work_pos[idx]),`
`exit_pips, point, dir)`
`+ Grind_EjectOffsetGet(g_grind_carry_exit_work_pos[idx]);`
`Grind_EffectiveEntry` reads `Grind_VLGet` at call time. Quote from `Grind_EffectiveEntry`: `return Grind_VLGet(position_ticket);`. So live.

T-1: HOLDS. Evidence: scans only side array by position_ticket; returns first match. Quote:
`if(side.layers[i].position_ticket != position_ticket)`
`continue;`
`exit_ticket_out = side.layers[i].exit_order_ticket;`
No check of other side. Wrong layer requires duplicate position_ticket in same side; invariants I5/I2 and broker uniqueness prevent. Missing layer with resting exit would be an orphan; recon I4 would fail. If layer closing, returns true with closing. No fix. But note if `position_ticket` is 0, it could match a zero placeholder; work items are appended only for `layer.position_ticket != 0` in Begin. Quote from Begin: `if(layer.position_ticket == 0)` `continue;`. So safe. Smallest fix: guard `if(position_ticket == 0) return false;` in helper for robustness. But not needed. I'll mention.

T-2: BREAKS? Or NEEDS-FIX? Let's decide. The question: "List every value the pass still uses from capture (entry, side, layer index, the stored formula, the order of items). Can any change mid-pass and matter? Is the stored `g_grind_carry_exit_work_formula` used for anything but events?" We should list:
- entry: `g_grind_carry_exit_work_entry[idx]` passed to ShiftLayer and WorkBase. Entry fixed; if VL GV present, EffectiveEntry uses live VL, so captured entry ignored. If no VL, entry won't change.
- side: `g_grind_carry_exit_work_long[idx]` used to choose side. Side fixed.
- layer index: `g_grind_carry_exit_work_layer[idx]` used for event/comment. Layer index can be reused after a close+new fill, but the work item's position_ticket is old, so if old layer gone it skips; if old layer present, index unchanged. No wrong.
- stored formula: `g_grind_carry_exit_work_formula` is not used in step; step uses `Grind_CarryWorkBase`. Quote: `Grind_CarryWorkBase(idx, exit_pips, SymbolInfoDouble(symbol, SYMBOL_POINT))`. The array is dead. If it were used, it would be stale for VL/eject changes. But not.
- order of items: new layers filled after Begin are not in work list. This can matter: a layer opened mid-pass is never processed that night. Quote from Begin: appends only current `g_grind_long.layers` at Begin. Quote: `for(int i = 0; i < ArraySize(g_grind_long.layers); i++)` at Begin. If a layer fills after, it is absent. Its exit if placed by queue uses `Grind_ExitQFormulaTarget` with current accrued GV (likely 0) and no pending. It will miss that night's carry shift until next pass. This is a pre-existing gap, not fixed by C52. Verdict: NEEDS-FIX? The threat asks "Can any change mid-pass and matter?" Yes, new layers. But is it in scope? The fix doesn't address. We can mark NEEDS-FIX (residual, not introduced by fix). The prompt says "If you find another place where the pass uses a value captured at PassBegin that can change mid-pass: do not change it; report it." So we report it. Verdict for T-2: NEEDS-FIX (residual). The captured entry/side/layer index are safe. The stored formula is dead. The order of items misses new layers.
Also captured `g_grind_carry_exit_work_exit[idx]` is still stored but not used by step after fix? The fix description says the array itself stays. The step no longer uses it. It is dead too. We can mention. The helper uses current. So `work_exit` is dead. That's okay.

T-3: HOLDS. Evidence: ticket-0 branch commits `Grind_CarryAccruedSet(position_ticket, accrued_price);`. Later queue release uses `Grind_ExitQFormulaTarget` which reads `Grind_CarryAccruedGet(position_ticket)`. Quote from exitq: `const double accrued = (position_ticket > 0) ? Grind_CarryAccruedGet(position_ticket) : 0.0;` and `return Grind_ExitPrice(...) + accrued + eject_offset;`. So new exit placed at formula with new accrual. I6 holds. Smallest fix: none.

T-4: HOLDS. Evidence: accrual absolute: `const double accrued_pips = ledger_pips + pending_pips;` and target absolute: `const double theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);`. Second pass sets same `accrued_price`. Restart mid-pass re-runs; already shifted exits re-modified to same target. Gate not marked done until complete. Quote from step: `if(g_grind_carry_exit_work_cursor >= g_grind_carry_exit_work_count && g_grind_carry_exit_retry_count == 0) { ... Grind_CarryGateMarkDone(magic, now); ... }`. If restart before completion, gate not done. No double. Smallest fix: none.

T-5: HOLDS (pre-existing). Evidence: OnTimer calls `Grind_CarryOnTimerStep` unconditionally; quote from fxgrind: `Grind_CarryOnTimerStep(_Symbol, InpMagic, InpExitPips, InpEnableCarryPass, carry_now);` It does not check `g_grind_halted`. The fix doesn't add a halt check. Before fix, same. The fix changes skip behavior for missing/closing, which is safer. If want, smallest fix: gate carry pass on `!g_grind_halted`? But that might prevent repair? The prompt says don't change. We can say NEEDS-FIX? The threat asks "Does the fix change what a halted instance's pass does ... Was that already so before the fix?" The verdict could be HOLDS because it was already so. But the audit might want to flag that the carry pass still runs while halted, modifying exits of a book invariants say is wrong. That is a pre-existing risk. Since T-5 asks verdict, I'd say HOLDS (pre-existing, not introduced). But if I mark NEEDS-FIX, that suggests change required. The prompt's ruled items don't include gating. I'll say HOLDS with note: pre-existing; fix does not worsen; it reduces orphan modification by skipping absent layers. If desired, add halt guard, but out of scope.

T-6: NEEDS-FIX. Evidence: `g_grind_carry_exit_skipped++` now incremented in step for absent/closing, and also in ShiftLayer for sign guard and ledger failure. Quote step: `g_grind_carry_exit_skipped++;` Quote ShiftLayer: `g_grind_carry_exit_skipped++;` (sign guard) and `g_grind_carry_exit_skipped++;` (ledger failure). The summary field `"skipped"` conflates. Consumers cannot distinguish closing/missing from sign guard. Smallest fix: add separate counter/event for `closed_or_missing` or emit an event with reason. Since summary format can't change per scope, at least log an event.

T-7: HOLDS. Evidence: helper copies side struct by value: `const GrindSideState side = is_long ? g_grind_long : g_grind_short;`. MQL5 ASSUMED deep copy or read-consistent; single-threaded so no mutation between copy and scan. Up to 8 layers, cost negligible. If MQL5 shallow-copies dynamic array, still read-only within call. No aliasing issue. Smallest fix: use reference/pointer if allowed to avoid copy. But not necessary.

T-8: HOLDS. Evidence: recon tolerates missing required exit: `if(tolerate_exit_shortfall) { g_grind_recon_exit_shortfall_long++; continue; }`. Then `Grind_RetryMissingExits` places via `Grind_ExitQManageSide`, which uses `Grind_ExitQFormulaTarget` with current accrued. Quote from exitq: `const double formula = Grind_ExitQFormulaTarget(side.layers[i].entry_price, exit_pips, _Point, is_long, side.layers[i].position_ticket);`. It deletes/overwrites old shift. The old release marker is deleted by `Grind_CarryShiftDelete` when not clamped, or overwritten by `Grind_CarryRecordShift` when clamped. Quote from `Grind_ExitQManageSide`: `Grind_CarryShiftDelete(side.layers[i].position_ticket);` else `Grind_CarryRecordShift(...)`. So no stale GV. Smallest fix: none. ASSUMED operator deletes the exact mispriced EXT and reattaches only that chart before other rank changes.

T-9: TEST GAPS. List:
- Short side: no test calls helper with `is_long=false`. If helper always read `g_grind_long`, CR1-CR3 would still pass. Quote tests use `Adr151_TestSetupLongLayer(g_grind_long, ...)`.
- Missing layer (not found): CR3 tests closing (`exit_position_ticket != 0`) but layer still in book. No test for `!Grind_CarryCurrentExitTicket(...)` returning false. Quote CR3 sets `g_grind_long.layers[0].exit_position_ticket = exit_pos;` not removal.
- Release AFTER processing: no test captures ticket 0, runs step, then simulates release, then checks I6. CR1 does release before step.
- Restart/idempotence: no test runs two passes.
- Skip counter conflation: no test asserts `skipped` distinguishes closing from sign-guard.
- Vacuous: CR3 "closing not shifted" passes without fix because modify fails and does not commit; it does not prove the new skip branch executed. CR1/CR2 precondition assertions pass in both by design. CR1 "accrued" and "accrued beyond I6 tolerance" pass in both because ticket-0 branch commits; they are preconditions, not fix-sensitive. CR2 "cancelled" is precondition.

PREMISE VERDICT: The live-book lookup closes RACE 1 and RACE 2 completely for single-threaded execution and a valid book. RACE 1: released mid-pass -> current exit found, modified. Quote step `current_exit` passed. RACE 2: cancelled mid-pass -> current exit 0, ticket-0 branch commits. Quote `if(exit_order_ticket == 0) { ... Grind_CarryAccruedSet(position_ticket, accrued_price); }`. Residual: new layers after Begin not processed (T-2), skip counter conflation (T-6), halted pass (T-5). But the races themselves are closed.

Need ensure all quotes are exact from provided code. We must not use line numbers. We can cite file and function.

Let's write final answer. Need no preamble. Desired oververbosity 5. We need be thorough but not too long. The prompt wants exhaustive. We'll produce sections.

Let's double-check code for exact quotes.

From grind_carry.mqh:

`bool Grind_CarryCurrentExitTicket(...)`
```
   exit_ticket_out = 0;
   closing_out = false;
   const GrindSideState side = is_long ? g_grind_long : g_grind_short;
   for(int i = 0; i < ArraySize(side.layers); i++) {
      if(side.layers[i].position_ticket != position_ticket)
         continue;
      exit_ticket_out = side.layers[i].exit_order_ticket;
      closing_out = (side.layers[i].exit_position_ticket != 0);
      return true;
   }
   return false;
```
Quote: `closing_out = (side.layers[i].exit_position_ticket != 0);` and `return false;`.

Step:
```
      if(!Grind_CarryCurrentExitTicket(g_grind_carry_exit_work_pos[idx],
                                       g_grind_carry_exit_work_long[idx],
                                       current_exit, closing)
         || closing) {
         g_grind_carry_exit_skipped++;
         processed++;
         continue;
      }
```
Then:
```
      if(Grind_CarryExitShiftLayer(g_grind_carry_exit_work_pos[idx],
                                   current_exit,
                                   g_grind_carry_exit_work_entry[idx],
                                   Grind_CarryWorkBase(idx, exit_pips,
                                                       SymbolInfoDouble(symbol, SYMBOL_POINT)),
```
Good.

G4: `Grind_CarryExitPassBegin`:
```
      Grind_CarryExitPassAppendWork(layer.position_ticket, layer.exit_order_ticket,
                                    layer.entry_price, formula, true, layer.layer_index);
```
and short side similarly. `Grind_CarryWorkBase`:
```
   return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx],
                                               g_grind_carry_exit_work_pos[idx]),
                          exit_pips, point, dir)
          + Grind_EjectOffsetGet(g_grind_carry_exit_work_pos[idx]);
```
`Grind_CarryExitShiftLayer` signature:
```
bool Grind_CarryExitShiftLayer(const ulong position_ticket,
                               const ulong exit_order_ticket,
...
```
No helper. Event format `Grind_CarryEmitExitShiftEvent` unchanged; we can say no `current` in it.

G5: `Grind_EffectiveEntry`:
```
   if(!Grind_VLHas(position_ticket))
      return entry;
   return Grind_VLGet(position_ticket);
```
Quote.

T-1: Begin:
```
      if(layer.position_ticket == 0)
         continue;
```
Helper quote. Also invariants: I4 orphan exit in recon. Quote from recon: `return Grind_InvariantFail(reason_out, "I4_LONG_ORPHAN_EXIT",` etc.

T-2: work_formula not used. We can quote step using WorkBase: `Grind_CarryWorkBase(idx, exit_pips,` and no `work_formula`. The array is in Append: `g_grind_carry_exit_work_formula[n] = formula_exit;`. But not read. We can say dead. New layers: Begin loops `for(int i = 0; i < ArraySize(g_grind_long.layers); i++)` at Begin. Quote. So new layers after Begin not in work list. Verdict NEEDS-FIX (residual). But is this "new behaviour"? No. The threat asks "Can any change mid-pass and matter?" Yes. We'll mark NEEDS-FIX (pre-existing).

T-3: quote from `Grind_CarryExitShiftLayer` ticket-0:
```
   if(exit_order_ticket == 0) {
      if(Grind_CarryShouldCommitAccrual(false, false, true))
         Grind_CarryAccruedSet(position_ticket, accrued_price);
      return true;
   }
```
Quote from exitq `Grind_ExitQFormulaTarget`:
```
   const double accrued = (position_ticket > 0)
                          ? Grind_CarryAccruedGet(position_ticket)
                          : 0.0;
...
   return Grind_ExitPrice(eff, exit_pips, point, is_long ? 1 : -1) + accrued + eject_offset;
```
So HOLDS.

T-4: quote `const double accrued_pips = ledger_pips + pending_pips;` and `const double theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);`. Gate mark done quote. HOLDS.

T-5: quote `Grind_CarryOnTimerStep(_Symbol, InpMagic, InpExitPips, InpEnableCarryPass, carry_now);` from OnTimer. No halt check. HOLDS/pre-existing.

T-6: quotes for skipped. In step: `g_grind_carry_exit_skipped++;`. In ShiftLayer sign guard: `g_grind_carry_exit_skipped++;`. In ledger fail: `g_grind_carry_exit_skipped++;`. Summary: `",\"skipped\":" + IntegerToString(skipped) +`. NEEDS-FIX.

T-7: quote `const GrindSideState side = is_long ? g_grind_long : g_grind_short;`. HOLDS.

T-8: quote recon tolerate:
```
         if(tolerate_exit_shortfall)
            continue;
```
Actually in `Grind_RebuildBookFromTicketsInner`:
```
         if(tolerate_exit_shortfall) {
            g_grind_recon_exit_shortfall_long++;
            continue;
         }
```
Quote. `Grind_RetryMissingExits` quote from fxgrind: `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);`. ExitQManageSide quote `const double formula = Grind_ExitQFormulaTarget(...)`. And `Grind_CarryShiftDelete`. HOLDS.

T-9: test quotes. CR1 setup `Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, pos, 0, exit_pips);` (ticket 0). CR2 uses `Grind_ExitQHoldCancelLayer(...)`. CR3 uses `g_grind_long.layers[0].exit_position_ticket = exit_pos;` not removal. No short side. No missing layer. No release after processing. CR3 passes without fix because modify fails. Quote `AssertTrue("CR3 closing not shifted", MathAbs(Grind_CarryAccruedGet(pos)) <= 1e-12);`. It would pass even if skip branch absent because modify failure does not commit. Good.

PREMISE VERDICT: Closes RACE 1 and 2. Residuals.

Now write final answer. Ensure no line numbers. Use headings. Keep concise but thorough. The output order as requested. We'll include quotes in code format.

Need avoid claiming line numbers. Use file names and function names. We'll format.

Let's draft.

Potential issue: G4 "unchanged by 6831436" - I will mark "VERIFIED (observable; no diff available)". But the instruction says verify each. We can say "VERIFIED as far as the supplied tree shows". That's acceptable.

Also for G1, note it sets both 0/false before scan. Quote `exit_ticket_out = 0;` `closing_out = false;`.

Let's produce final.

## Final Report

## GIVENS CHECK

**G1 — VERIFIED.** `grind_carry.mqh`, `Grind_CarryCurrentExitTicket`:
`closing_out = (side.layers[i].exit_position_ticket != 0);`
and for absence:
`return false;`
It returns the matched layer’s current `exit_order_ticket`; `closing_out` is true only when `exit_position_ticket != 0`. Initial `exit_ticket_out = 0; closing_out = false;` covers absent.

**G2 — VERIFIED.** `grind_carry.mqh`, `Grind_CarryExitPassStep`:
`if(!Grind_CarryCurrentExitTicket(g_grind_carry_exit_work_pos[idx],`
`g_grind_carry_exit_work_long[idx],`
`current_exit, closing)`
and the call now passes:
`Grind_CarryExitShiftLayer(g_grind_carry_exit_work_pos[idx],`
`current_exit,`
The captured `g_grind_carry_exit_work_exit[idx]` is no longer passed.

**G3 — VERIFIED.** `grind_carry.mqh`, `Grind_CarryExitPassStep`:
`g_grind_carry_exit_skipped++;`
`processed++;`
`continue;`
No shift-layer call, no accrual commit, no event emit runs in that branch.

**G4 — VERIFIED as far as the supplied tree shows.** No diff is attached, but the final code shows no helper use in the named functions. `Grind_CarryExitPassBegin` still captures:
`Grind_CarryExitPassAppendWork(layer.position_ticket, layer.exit_order_ticket,`
`layer.entry_price, formula, true, layer.layer_index);`
`Grind_CarryWorkBase` still reads captured entry/pos:
`Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx],`
`g_grind_carry_exit_work_pos[idx]),`
`Grind_CarryExitShiftLayer` signature and body are unchanged by the helper. Event builder still takes `formula_exit` and emits the same fields.

**G5 — VERIFIED.** `grind_carry.mqh`, `Grind_CarryWorkBase`:
`+ Grind_EjectOffsetGet(g_grind_carry_exit_work_pos[idx]);`
and `Grind_EffectiveEntry`:
`return Grind_VLGet(position_ticket);`
Both VL and eject offset GVs are read at step time via `Grind_EffectiveEntry` / `Grind_EjectOffsetGet`, not snapshotted at `PassBegin`.

---

## T-1 Lookup — HOLDS

`Grind_CarryCurrentExitTicket` scans only the chosen side by position ticket:
`if(side.layers[i].position_ticket != position_ticket)`
`continue;`
`exit_ticket_out = side.layers[i].exit_order_ticket;`

Wrong-layer risk requires a duplicate `position_ticket` on the same side, or the same position ticket on both sides. MT5 position tickets are account-unique; the book invariants (`I5_*_DUP`, `I2_*_EXIT_DUP`, `I4_*_ORPHAN_EXIT`) and reconstruction reject duplicate/orphan structures. A missing layer with a resting exit is an orphan by definition and is rejected by recon:
`return Grind_InvariantFail(reason_out, "I4_LONG_ORPHAN_EXIT",`
so the helper’s “miss a layer whose exit rests” case cannot persist in a valid book. `PassBegin` never appends ticket-zero placeholders:
`if(layer.position_ticket == 0)`
`continue;`
so the helper is not asked to match the zero ticket. Smallest hardening, not required: add `if(position_ticket == 0) return false;`.

## T-2 Remaining captured state — NEEDS-FIX (residual, pre-existing)

Values still used from capture:

- Entry: `g_grind_carry_exit_work_entry[idx]` passed to `Grind_CarryExitShiftLayer` and used by `Grind_CarryWorkBase`. Entry is fixed at fill; if a VL GV exists, `Grind_EffectiveEntry` overrides it live:
  `return Grind_VLGet(position_ticket);`
  so the captured entry is not authoritative when VL exists.
- Side: `g_grind_carry_exit_work_long[idx]`. A position cannot change side.
- Layer index: `g_grind_carry_exit_work_layer[idx]`. Reused layer indices can occur after close+new fill, but the lookup is by `position_ticket`; if the old layer is gone the item is skipped, and if it is present its index has not changed.
- Stored formula: `g_grind_carry_exit_work_formula` is **not** used by the step. The step passes:
  `Grind_CarryWorkBase(idx, exit_pips,`
  so the stored formula is dead for this path. It is not used for events either; events use the `formula_exit` argument.
- Work order: `Grind_CarryExitPassBegin` captures only layers present at Begin:
  `for(int i = 0; i < ArraySize(g_grind_long.layers); i++) {`
  A layer filled after Begin is never appended. Its exit, if the queue places one, uses `Grind_ExitQFormulaTarget` with the current accrued GV (likely zero for a just-filled layer) and no pending carry. It will not receive that night’s carry shift until a later pass. This is pre-existing, not fixed by C52, and is the main remaining captured-state gap.

## T-3 Release after processing — HOLDS

Ticket-0 branch commits the absolute shift:
`if(exit_order_ticket == 0) {`
`if(Grind_CarryShouldCommitAccrual(false, false, true))`
`Grind_CarryAccruedSet(position_ticket, accrued_price);`
The later queue release reads that GV:
`const double accrued = (position_ticket > 0)`
`? Grind_CarryAccruedGet(position_ticket)`
`: 0.0;`
and places at:
`return Grind_ExitPrice(eff, exit_pips, point, is_long ? 1 : -1) + accrued + eject_offset;`
So a layer processed with ticket 0 and released later in the same pass places its new exit with the new accrual. I6 then holds because `Grind_ReconExitMatchesEntry` also adds `Grind_CarryAccruedGet(position_id)`.

## T-4 Idempotence and restarts — HOLDS

The accrual is absolute:
`const double accrued_pips = ledger_pips + pending_pips;`
and the moved target is absolute:
`const double theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction,`
`accrued_pips, pip_size);`
A second pass recomputes the same ledger+pending from current broker swap and moves the exit to the same target. It does not subtract from or add to a stored prior shift. The gate is marked done only on completion:
`if(g_grind_carry_exit_work_cursor >= g_grind_carry_exit_work_count`
`&& g_grind_carry_exit_retry_count == 0) {`
`Grind_CarryGateMarkDone(magic, now);`
If a restart occurs mid-window before completion, the gate is not done, the pass restarts, and already shifted exits are re-modified to the same absolute price. No double commit.

## T-5 Halted or quarantined instance — HOLDS (pre-existing)

`fxgrind.mq5`, `OnTimer` calls the pass unconditionally:
`Grind_CarryOnTimerStep(_Symbol, InpMagic, InpExitPips, InpEnableCarryPass, carry_now);`
It does not check `g_grind_halted`. That was true before the fix. The fix does not add a halt gate; it does make the pass safer for a corrupt/missing layer by skipping absent or closing layers instead of blindly modifying a captured ticket. If one wants the stricter policy, the smallest fix is to guard the call with `!g_grind_halted`, but that is outside the accepted scope and may also block a repair pass.

## T-6 Counts and events — NEEDS-FIX

The new skip adds to the same counter used by unrelated failures. `Grind_CarryExitPassStep`:
`g_grind_carry_exit_skipped++;`
`Grind_CarryExitShiftLayer` also increments it for sign guard:
`g_grind_carry_exit_skipped++;`
and for ledger conversion failure:
`g_grind_carry_exit_skipped++;`
The summary exposes only one field:
`",\"skipped\":" + IntegerToString(skipped) +`
A consumer cannot distinguish “layer was closing/missing” from “sign guard blocked” or “ledger conversion failed.” The event path for closing/missing emits no `CARRY_EXIT_SHIFT` event, so the counter is the only signal. Smallest fix within the existing event format: emit a distinct event such as `CARRY_EXIT_SKIP` with a reason, or add a separate counter if the summary format is allowed to change.

## T-7 Cost — HOLDS

`Grind_CarryCurrentExitTicket` copies a side struct by value:
`const GrindSideState side = is_long ? g_grind_long : g_grind_short;`
ASSUMED: MQL5 copies the dynamic `layers` array deeply, or if it aliases it, the helper only reads it and no tick/trade event can interleave inside the single-threaded timer step. Either way the scan sees the current book at call time. Up to 8 layers makes the copy negligible. A reference/pointer form would avoid the copy but is not required.

## T-8 Repair runbook — HOLDS

Reconstruction’s startup shortfall tolerance accepts a missing required exit:
`if(tolerate_exit_shortfall) {`
`g_grind_recon_exit_shortfall_long++;`
`continue;`
Then the EA calls the retry path:
`Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);`
`Grind_ExitQManageSide` places at the current formula:
`const double formula = Grind_ExitQFormulaTarget(side.layers[i].entry_price,`
`exit_pips, _Point, is_long,`
`side.layers[i].position_ticket);`
which reads `Grind_CarryAccruedGet` and `Grind_EjectOffsetGet`. It then deletes or overwrites the old carry-shift/release GVs:
`Grind_CarryShiftDelete(side.layers[i].position_ticket);`
or records a new clamp shift via `Grind_CarryRecordShift`. No stale release marker or carry shift survives to make the repair exit wrong. ASSUMED: the operator deletes the exact mispriced EXT before reattaching, as the runbook says; if left in place, recon sees exit coverage and I6 fails on the stale price.

## T-9 Tests — TEST GAPS

New behaviour with no failing-without-fix test:

- **Short side.** All three tests use:
  `Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, pos, ...)`
  No test exercises `is_long == false`. If `Grind_CarryCurrentExitTicket` accidentally always read `g_grind_long`, CR1–CR3 would still pass.
- **Layer missing from the book.** CR3 tests closing:
  `g_grind_long.layers[0].exit_position_ticket = exit_pos;`
  but the layer remains in the book. No test covers `!Grind_CarryCurrentExitTicket(...)` returning false because the layer was removed.
- **Release AFTER processing.** CR1 releases before the step:
  `g_grind_long.layers[0].exit_order_ticket = exit_ticket;`
  then runs the step. No test captures ticket 0, runs the step to commit accrual, then simulates a later queue release and checks I6.
- **Restart/idempotence.** No test runs two passes or checks that the second pass does not double.
- **Skip conflation.** No test asserts that closing/missing is distinguishable from sign-guard skip in `skipped`.

Vacuous/pass-in-both assertions:

- `CR1 accrued` and `CR1 accrued beyond I6 tolerance` pass in both states because the ticket-0 branch commits in the unfixed code too; they are preconditions, not fix-sensitive.
- `CR2 cancelled` is asserted before the step and is a precondition.
- `CR3 closing not shifted` passes without the fix because the captured ticket’s modify fails (`Grind_ModifyPendingPrice` returns false) and therefore does not commit. It does not prove the new skip branch executed; it only proves nothing committed.

---

## PREMISE VERDICT

The live-book lookup closes **RACE 1** and **RACE 2** completely for normal single-threaded execution and a valid book.

- RACE 1: a layer held at capture and released before its item runs. The step now finds the live layer and passes:
  `current_exit,`
  so `Grind_CarryExitShiftLayer` modifies the newly placed exit by the accrual. I6 holds.
- RACE 2: a layer with an exit at capture that is cancelled before its item runs. The helper returns current ticket 0, and the ticket-0 branch commits:
  `Grind_CarryAccruedSet(position_ticket, accrued_price);`
  Later release reads it through `Grind_ExitQFormulaTarget`. The night’s carry is not lost.

Residual non-race gaps remain: new layers filled after `PassBegin` are not processed that night (T-2), the `skipped` counter conflates closing/missing with sign-guard and ledger failures (T-6), and the pass still runs while halted (T-5, pre-existing). None of these reopen RACE 1 or RACE 2.

## TEST GAPS

The suite does not cover: short side; a layer absent from the live book (as opposed to merely closing); a release after the item has already committed ticket-0 accrual; restart/idempotence; and the distinction between closing/missing skips and sign-guard/ledger skips. Several assertions pass in both pre-fix and post-fix states by design, and CR3 passes without the fix because a failed modify also commits nothing.

<!-- finish_reason=stop -->
