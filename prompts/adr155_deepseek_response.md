# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit. Need analyze code. We have ADR and code. Need find what breaks. Specific asks: every place exit target computed/checked that would NOT see new offset; any path that cancels and re-places deepest exit; whether reconstruction after ejection passes I6; whether anything besides Grind_ExitQFormulaTarget and Grind_ReconExitMatchesEntry needs offset.

We need be exhaustive. Let's inspect code mentally.

We need consider MQL5, variables. We have provided three files plus engine. Need identify all exit target computations/checks.

Let's list places where exit target computed or checked:

- Grind_ExitQFormulaTarget in grind_exitq.mqh: formula + accrued. ADR says add eject_offset.
- Grind_ReconExitMatchesEntry in grind_recon.mqh: expected = ExitPrice + accrued + shift. ADR says add eject_offset.
- Grind_InvariantDetailI6 in grind_recon.mqh: computes expected = ExitPrice + carry_shift. This is detail for I6 failure. It currently only includes carry_shift, not accrued either? Wait code:
```
string Grind_InvariantDetailI6(... carry_shift)
{
 const int dir...
 const double expected = Grind_ExitPrice(layer.entry_price, exit_pips, point, dir) + carry_shift;
 ...
}
```
It does NOT include accrued. That seems a pre-existing bug? Actually I6 check includes accrued via Grind_ReconExitMatchesEntry. But detail expected omits accrued. Maybe carry_shift includes accrued? Wait Grind_CarryShiftGetForRecon returns shift, not accrued. The detail expected = ExitPrice + carry_shift only. That's likely already inconsistent with the check when accrued != 0. But maybe accrued is included in carry_shift? Let's inspect: In Grind_CarryExitShiftLayer, accrued_price = theoretical - formula_exit; Grind_CarryAccruedSet(position_ticket, accrued_price). Then applied_shift = new_exit - intended where intended = formula_exit + accrued_price. So shift = new_exit - (formula+accrued). So shift doesn't include accrued. I6 check uses accrued + shift. Detail uses only shift. So detail is already wrong if accrued nonzero. But ADR only mentions adding eject_offset to Grind_ReconExitMatchesEntry and Grind_ExitQFormulaTarget. But detail also needs offset (and maybe accrued). The audit asks every place exit target computed/checked. So yes Grind_InvariantDetailI6 must include eject_offset. Also Grind_InvariantDetailI6 doesn't include accrued, so if we're auditing, note it.

- Grind_ReconLayerHasExitCoverage? no target.

- Grind_ReconCheckInvariants: I3 checks coverage, I6 calls Grind_ReconExitMatchesEntry with shift. Needs offset inside that function. But detail.

- Grind_ReconFailureOffendingForReason no target.

- Grind_RebuildBookFromTicketsInner: when layer has no exit coverage, it sets long_out.layers[n].exit_target = Grind_ExitQFormulaTarget(...). This will see offset if formula function updated. Good. When has exit coverage, it uses actual exit_target from broker. So okay. But note if no exit coverage, formula target used. If ejection variable exists, formula includes offset. Good.

- Grind_AppendLayer in engine: side.layers[n].exit_target = Grind_ExitPrice(entry, exit_pips, _Point, dir); This does NOT include accrued nor eject_offset. But this is for new layer when entry fills. At that moment no ejection for new layer. For existing layer? No. However if a layer closes and a new layer with same position? no. So fine. But if an ejected layer somehow? No.

- Grind_ExitQManageSide: computes formula = Grind_ExitQFormulaTarget (will include offset if updated). Then clamps and places. It also sets side.layers[i].exit_target = price. If clamped, stores shift = price - formula. But note formula includes eject_offset; so shift becomes price - (formula+accrued+eject). Then I6 expects ExitPrice + accrued + eject + shift. That works? Let's check: When re-placing an exit for a layer that already has an eject_offset, Grind_ExitQFormulaTarget returns ExitPrice + accrued + eject. Then clamp may adjust. They set shift = price - formula. So price = formula + shift = ExitPrice+accrued+eject+shift. I6 with offset+shift matches. Good. But if not clamped and price == formula, they delete shift. That's fine. However, ADR says an unclamped re-placement DELETES stale offset? Wait "stale-offset fix, grind_engine.mqh:~1847" refers Grind_CarryExitShiftLayer? Let's see: In Grind_ExitQManageSide, if clamped or price differs from formula > half point, set shift; else delete shift. So if an ejection offset exists, formula includes it. If price==formula, they delete shift, not eject offset. That's fine. But if eject_offset exists and the exit is re-placed, it will use formula+eject. So ejection persists. Good.

- Grind_CarryExitPassBegin: computes formula = Grind_ExitPrice(...) NOT via Grind_ExitQFormulaTarget. It appends work with formula (without accrued? Actually it uses Grind_ExitPrice only, then in Grind_CarryExitShiftLayer it computes theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size); accrued_price = theoretical - formula_exit; sets accrued. So the carry pass computes formula baseline without accrued/eject, then applies accrued based on swaps. This is a separate mechanism: nightly carry shift. It will NOT see the eject offset. It will compute theoretical = formula_exit - direction*accrued_pips*pip_size. Then it sets accrued and modifies exit. This will overwrite the ejected exit back to the formula/accrued price, undoing the ejection. The ADR mentions "The exit queue re-prices every exit from formula + accrued... A stored SHIFT is not part of that formula, and an unclamped re-placement DELETES it (the stale-offset fix...)" Hmm. Actually the carry pass is the one that re-prices every exit nightly. It uses formula_exit (without accrued/eject) and accrued_pips. It does not read Grind_ExitQFormulaTarget nor eject_offset. So if an ejection is active, the nightly carry pass will modify the exit to the carry-shifted price (formula + accrued), destroying the ejection. Unless ADR includes offset in this path? The table only lists Grind_ExitQFormulaTarget and Grind_ReconExitMatchesEntry. But the carry pass is a major path that cancels/re-places (modifies) the deepest exit. It needs the eject offset. This is likely the main finding. Let's verify: Grind_CarryExitPassBegin iterates all layers, appends work with formula = Grind_ExitPrice(entry, exit_pips, point, dir). It includes deepest. Then Grind_CarryExitShiftLayer computes theoretical from formula_exit + accrued (via Grind_CarryShiftedExitPrice) and modifies the exit order. It does not read eject_offset. So it will overwrite ejected price. The ADR's durability section claims offset added to Grind_ExitQFormulaTarget and I6, but does not mention carry pass. The carry pass is precisely "any path that cancels and re-places the deepest exit" and it will undo ejection. Also it sets Grind_CarryShiftSet to applied_shift based on intended = formula_exit + accrued_price. If there is an eject_offset, the intended is missing it, so shift stored would be wrong relative to I6 that includes eject_offset. Let's compute: Suppose formula F, accrued A, eject E, current exit P = F+A+E. Carry pass computes theoretical = F - dir*accrued_pips*pip = F + A (since accrued_price = A). It sets new_exit = theoretical (clamped). Then intended = formula_exit + accrued_price = F + A. applied_shift = new_exit - (F+A) = 0 (if no clamp). It modifies exit to F+A, deleting E. Then I6 expected = F + A + E + shift(0) = F+A+E, but actual exit = F+A, diff = -E -> I6 fail on restart. So it breaks both the ejection and I6. If clamped, shift = new_exit - (F+A) may be nonzero, but still missing E. So carry pass must include eject_offset. This is huge.

Also Grind_CarryExitPassStep and Grind_CarryExitPassBegin are in grind_carry.mqh. The ADR didn't mention. The audit task specifically asks "any path that cancels and re-places the deepest exit". This is one.

- Grind_ExitQHoldCancelLayer: cancels exit under slot pressure and deletes Grind_CarryShiftDelete (which deletes shift and release). It does NOT delete eject_offset. That's per ADR? It says trim cancels and re-releases ejected exit: comes back at EJECTED price. If cancel holds, it deletes shift but not eject_offset. Then when re-placed, formula includes eject_offset, so comes back at ejected price (modulo clamp). Good. But wait: it deletes shift but not eject_offset. That's correct. But note Grind_CarryShiftDelete also deletes release variable, not eject. Fine.

- Grind_HandleSideDealFill: on exit fill (DEAL_ENTRY_OUT_BY) it calls Grind_CarryShiftDelete and Grind_CarryAccruedDelete. ADR says delete eject_offset alongside accrued at grind_engine.mqh:1408. In code at that line: 
```
Grind_CarryShiftDelete(side.layers[i].position_ticket);
Grind_CarryAccruedDelete(side.layers[i].position_ticket);
Grind_RemoveLayerAt(side, i);
```
Need add Grind_EjectOffsetDelete. So audit note: missing deletion on close. If not deleted, GV leaks. It might not break I6 because position gone, but cleanup. Also next position with same ticket? Tickets are unique, but could leak. ADR says add. In code not present. So implementation gap.

- Also when exit fills via DEAL_ENTRY_IN for EXT, it queues CloseBy. Does it delete offset? The actual layer removal happens on DEAL_ENTRY_OUT_BY, so deletion there. Good.

- Grind_ExitQManageSide: when placing a new exit for a layer that has no exit (e.g., after trim), it uses Grind_ExitQFormulaTarget (with offset) and sets shift based on price - formula. If formula includes offset, then shift is relative to formula+offset. Good. But note it then sets `side.layers[i].exit_target = price`. If later I6 checks, it uses entry + accrued + offset + shift. Matches. But what about `Grind_ReconExitMatchesEntry` if `exit_is_filled`? It uses same. Fine.

- Grind_ReconCheckInvariants: I6 check calls Grind_ReconExitMatchesEntry with long_shift. It does not separately add offset. The function must add. The detail function must add for telemetry. Also note I6 for filled exits: if exit_is_filled, the check uses `exit_target` from exit position price. For a filled exit, the exit target is the actual fill price? In recon, for EXT position, `exit_target = tickets[i].price` which is POSITION_PRICE_OPEN of the exit position. For a passive limit, if filled, the fill price equals the limit price (or better). The check allows adverse. With ejection, the exit position price is the ejected price (or better). The expected = formula + accrued + eject + shift. If shift was set as price - (formula+accrued+eject), then expected = price. So passes. If shift is 0 and eject offset set, expected = F+A+E. Actual exit = E? Wait ejected price = F+A+E. So expected = actual. Good.

- Grind_InvariantDetailI6: missing accrued and eject. Need mention.

- Grind_CarryExitPassBegin and Grind_CarryExitShiftLayer: missing eject. Also Grind_CarryExitShiftLayer sets accrued based on swaps. If an ejection is active, the carry pass would overwrite. To preserve ejection, the carry pass should either skip ejected layers or incorporate eject_offset. ADR says offset added everywhere exit target computed. The carry pass computes theoretical = formula_exit + accrued (via shift). It should add eject_offset. Specifically, in Grind_CarryExitShiftLayer, `theoretical` should be `formula_exit + accrued_price + eject_offset`? But careful: it computes accrued_price = theoretical - formula_exit. If we add eject, then accrued_price would include ejection, violating Gemini's separation. Better: compute carry theoretical as formula + accrued, then add eject_offset separately for the exit placement. But they set accrued_price based on theoretical - formula_exit. If we include eject, accrual contaminates. So they need a separate variable read and not fold into accrued. The ADR only mentions formula and I6. But the carry pass needs to read eject_offset and add to new_exit without changing accrued. Something like: after computing carry theoretical, add eject_offset. And when storing shift, intended = formula_exit + accrued_price + eject_offset. Otherwise shift wrong. This is a major design gap.

- Grind_CarryExitShiftLayer also calls Grind_CarrySignGuardBlocks(entry, theoretical, is_long). For an ejected exit, theoretical may be far from entry; sign guard may block it if it crosses entry? Let's see: For long, sign guard blocks if new_exit <= entry. Ejected exit for long is set to best passive at market. If market is above entry? Actually long exit is above entry normally. Ejection to passive market could be below entry (if market has fallen). Then sign guard blocks, and carry pass skips, leaving ejection? If it skips, it won't overwrite. But if market is above entry, it may modify to theoretical (without eject) and undo. Also if ejection target is below entry, the initial command set exit at market (passive), which might be below entry. But sign guard in carry pass would block and leave it. However the carry pass also sets accrued before sign guard? It sets Grind_CarryAccruedSet before sign guard. So it may update accrued even if skipped. Hmm. But main issue: if eject target is beyond entry in the allowed direction, carry pass overwrites.

- Grind_CarryPruneShiftGvs: prunes only shift and release GVs. It does not prune eject GVs. ADR says clean-up script and suite reset add prefix. But this function also prunes orphan GVs. It should also prune GRIND_EJECT_OFFSET_ and GRIND_EJECT_<magic>? It currently only checks shift prefixes. If eject offset remains after position closed (e.g., if deletion missed), it will leak. Not directly breaking I6 but memory. The ADR mentions cleanup script and suite reset, but not this prune function. The audit asks "anything besides ... needs offset". Yes, pruning orphan eject GVs. Also account-switch clean-up script not shown but ADR says add prefix.

- Grind_CarryShiftGetForRecon: returns shift. Does not include eject. That's used in I6. The I6 function will add eject. But detail uses carry_shift only. Need add eject.

- Grind_CarryShiftWithinBound / Grind_CarryShiftGetValidated: bounds shift. Eject offset no bound. Fine.

- Grind_CarryShiftDelete: deletes shift and release. Should it delete eject? No, separate. But on layer close, both shift and accrued and eject should be deleted. Currently only shift and accrued. So add eject delete. If not, and a new position somehow gets same ticket? Position tickets are unique per position. But if not deleted, orphan GV. Also if a layer is removed and later a new layer with same position ticket? Impossible. But cleanup.

- Grind_ExitQFormulaTarget: only adds accrued. Needs eject offset. Good.

- Grind_ExitQClampPassive: no target computation, just clamp. Fine.

- Grind_ReconExitMatchesEntry: needs eject. Also note it has default parameters; if position_id == 0, accrued not fetched. For I6, position_id passed. Good.

- Grind_InvariantDetailI6: as above.

- Grind_ReconFailure... no.

- Grind_RebuildBookFromTicketsInner: when no exit coverage, sets exit_target = Grind_ExitQFormulaTarget. If formula function updated, good. But note: if no exit coverage, it may be an ejected layer whose exit was cancelled under slot pressure. Then formula includes eject_offset, so exit_target becomes ejected price. That's correct. However, if the layer has no exit coverage and no eject_offset, formula is normal. Good.

- Grind_AppendLayer: as noted, new layer exit_target = Grind_ExitPrice only. If a layer is somehow ejected immediately? No.

- Grind_ComputeAddTarget: uses entry only. No exit.

- Grind_TryPlaceExitForLayer: uses layer.exit_target. Not sure used? It places exit order with layer.exit_target. If layer.exit_target was set by recon with formula including eject, good. If set by Grind_AppendLayer (no eject), normal.

- Grind_ExitQManageSide: if it places a new exit, it computes formula via Grind_ExitQFormulaTarget. Good. But note it sets `side.layers[i].exit_target = price;` after placing. If price is clamped, it sets shift. If not clamped, it deletes shift. But what about eject_offset? It doesn't set it; it should already exist from command. If command set eject_offset, formula includes it. So price = formula+clamp. Then shift = price - formula. That's relative to formula including eject. When I6 checks, expected = F+A+E+shift = price. Good. But wait: the shift set here is `price - formula` where formula includes eject_offset. So shift is the clamp adjustment only. That's fine. But if the ejection was commanded, the exit target is supposed to be the ejected price. If the exit is re-placed and clamped, it may be clamped further. The clamp is "exactly as every exit is", so acceptable. But the stored shift will be relative to formula+eject. Then I6 expected = F+A+E+shift. Actual = price. Matches. However, the eject_offset itself remains E. If later the carry pass runs and overwrites, it's bad.

- Grind_CarryExitPassBegin: It builds work from current layers. It uses layer.exit_order_ticket and entry. It computes formula = Grind_ExitPrice(entry, exit_pips, point, dir). It does NOT include accrued nor eject. Then Grind_CarryExitShiftLayer computes theoretical = formula + accrued (via swap). It then modifies exit. This is the nightly carry re-price. It will overwrite ejection. This is the biggest missing place.

- Also Grind_CarryExitShiftLayer sets `Grind_CarryShiftSet(position_ticket, applied_shift);` where applied_shift = new_exit - intended, intended = formula_exit + accrued_price. If we add eject_offset to new_exit, then intended must include eject_offset. Otherwise shift will be off by -E, and I6 will fail. So if they patch just new_exit but not intended, I6 fails. Need both.

- What about Grind_CarryExitPassAppendWork: maybe should include eject_offset in formula? But then accrued calculation would be polluted. Better to pass eject separately or add to theoretical after accrued.

- Grind_CarryExitPassStep: no.

- Grind_CarryExitPassOnWindowClose: no.

- Grind_CarryEmitExitShiftEvent: telemetry old/new price. Not target check.

- Grind_CarrySnapshotFields: includes accrued swap. No.

- Grind_CarrySignGuardBlocks: uses theoretical. If eject makes theoretical cross entry, guard may skip. For an ejection, you might want to allow crossing? The ADR says clamped exactly as every exit. The sign guard is in carry pass, not in command? The command sets exit to best passive price, clamped. It may cross entry. The carry pass sign guard may later block. Not a correctness of I6 but path.

- Grind_CarryExitShiftLayer: if exit_order_ticket == 0, it returns true after setting accrued. So if an ejected layer has no resting exit (e.g., trim cancelled), the carry pass sets accrued but does not modify. Then eject_offset remains. Later Grind_ExitQManageSide re-places using formula+accrued+eject. Good. But the carry pass may set accrued, which changes formula target. That's normal.

- Grind_ExitQHoldCancelLayer: cancels exit and deletes shift. If an ejection was active, shift deleted, eject_offset remains. When re-placed, formula includes eject. Good. But note: it deletes shift, so the clamp adjustment is lost. That's okay; it will re-clamp.

- Grind_ExitQManageSide: when placing new exit, if `clamped || MathAbs(price - formula) > _Point * 0.5` sets shift, else deletes shift. If eject_offset exists, formula includes it. So if price == formula, it deletes shift, leaving eject_offset. Good.

- Grind_ReconCheckInvariants: I6 for filled exits. If an exit filled at the ejected price, and eject_offset exists, I6 passes if shift correct. If the exit filled at a better price (for long, higher), diff positive, exit_is_filled allows diff >= 0. So passes. If filled adverse, might fail. Not specific.

- Grind_ReconFailureOffendingForReason: reason checks "I6_LONG_EXIT" or "I3_LONG_NAKED". It doesn't include "I6_LONG_EXIT_FILL_ADVERSE". That's a pre-existing bug? In Grind_ReconFailureOffendingForReason, it only checks `reason == "I6_LONG_EXIT"` not `I6_LONG_EXIT_FILL_ADVERSE`. So if I6 fails with adverse fill, offending comment not captured. Not related to eject, but audit might note? Not required.

- Grind_CheckBookInvariants: calls rebuild. If I6 fails due to carry pass, recon fails.

- Grind_ReconstructState: same.

- Grind_Heartbeat? Not in code.

- Other files? We only have these. But ADR mentions grind_gv_clean.mq5 and Grind_TestClearCarryState. Not shown. We can infer they need prefix. The audit asks "whether anything besides Grind_ExitQFormulaTarget and Grind_ReconExitMatchesEntry needs the offset." Yes: Grind_InvariantDetailI6, Grind_CarryExitPassBegin/ShiftLayer, Grind_CarryPruneShiftGvs, deletion on close, maybe Grind_TestClearCarryState, grind_gv_clean, and possibly Grind_CarryExitPassBegin formula? Also any other place that computes exit target: Grind_AppendLayer? No, but maybe when a layer is appended, if there is an existing eject_offset for that position? Impossible. But if a position is re-opened with same ticket? No.

- Also check Grind_ExitQManageSide's `Grind_CarryShiftSet` and `Grind_CarryReleaseGvName`. If an ejection offset exists, and the exit is re-placed with clamp, it sets shift = price - formula. Then I6 expects F+A+E+shift. But the actual exit is price. So passes. However, the release GV is set. That affects Grind_CarryShiftGetValidated: if release GV exists, it returns shift without bound check. This is for clamp adjustments. Eject offset has no bound. Fine.

- What about Grind_CarryShiftGetForRecon: it validates shift. If shift is zero but eject_offset nonzero, I6 function adds eject. Good.

- What about I6 for an ejected layer whose exit is still resting: `exit_target` in recon is the order price. The formula target is F+A+E. The actual order price is E? Wait E is offset, not price. Let's define: command sets exit to passive market price P. It stores eject_offset = P - (F + A). So P = F + A + eject_offset. In recon, exit_target = P. I6 expected = F + A + eject_offset + shift. If shift is 0, expected = P. Passes. If the carry pass overwrote to F+A, then exit_target = F+A. I6 expected = F+A+E+shift. If shift was set by carry pass? Carry pass sets shift = new_exit - (F+A) = 0. So expected = F+A+E, actual = F+A, diff = -E -> fails. So yes.

- What about `Grind_ReconExitMatchesEntry` when `exit_is_filled` and the exit position price is P. If shift is 0, expected = F+A+E. Passes. If the exit filled at better price, diff allowed. Good.

- Another path: `Grind_CarryExitPassBegin` calls `Grind_CarryPruneShiftGvs(magic)`. That prunes shift GVs for non-existent positions. It does not prune eject GVs. If a position closed and eject GV not deleted, it stays. Not a correctness but cleanup.

- `Grind_CarryExitShiftLayer` uses `Grind_CarryAccruedSet` before checking sign guard. If an ejection is active, and sign guard blocks, it still updates accrued. That's normal carry behavior. But if it blocks, it doesn't modify exit. So ejection preserved. However, if it doesn't block, it overwrites.

- `Grind_CarryExitShiftLayer` also computes `theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);` where formula_exit is without accrued. It then sets `accrued_price = theoretical - formula_exit`. If we need to incorporate eject, we should not put it in accrued. So need separate addition.

- `Grind_CarryExitPassAppendWork` could pass eject_offset as an additional argument. Not in ADR.

- `Grind_CarryExitPassBegin` is called on timer during rollover window. It processes all layers. So any ejection will be undone at next rollover. This is a critical operational bug: operator ejects, then at 23:50 rollover, carry pass overwrites. The ADR says durability, but misses this.

- Also `Grind_CarryExitShiftLayer` is called from `Grind_CarryExitPassStep` which is part of `Grind_CarryOnTimerStep`. It is likely scheduled nightly. So ejection won't survive a rollover. The ADR's test "restart after accepted ejection: reconstruction passes I6" might pass if restart before carry pass. But after carry pass, it fails. The test should include a carry pass.

- What about `Grind_ExitQManageSide` being called on every tick via Grind_RetryMissingExits. That uses formula with eject if patched. Good.

- What about `Grind_ExitQHoldCancelLayer` being called under slot pressure. It cancels exit and deletes shift. It does not delete eject. Then later `Grind_ExitQManageSide` re-places using formula+eject. Good. But if the layer is no longer required (rank changes), it may stay cancelled. But if it's deepest, it's required. So okay.

- What about `Grind_ReconComputeRanks`: ranks by entry only. Ejected exit price doesn't affect. Good.

- What about `Grind_ExitQAllowed` / `Required`: uses rank and depth. Good.

- What about `Grind_ExitQManageSide` when it places exit for a layer that is not required? It only places if required. Good.

- What about `Grind_TryPlaceExitForLayer`: uses layer.exit_target. This is only called? Search in code: not called in provided engine? Maybe in other files. But if it is called, layer.exit_target may be set by recon with formula including eject. So okay.

- What about `Grind_AppendLayer`: sets exit_target = Grind_ExitPrice(entry, exit_pips, _Point, dir). If a layer is appended and later ejected, the command will set exit_target to P and set eject_offset. But Grind_AppendLayer doesn't use formula with accrued either. At entry, accrued may not be set yet. So it's baseline. When exit placed, Grind_ExitQManageSide computes formula with accrued+eject. So the initial exit_target is overwritten. Fine.

- What about `Grind_ReconRebuild` when no exit coverage: uses Grind_ExitQFormulaTarget. That includes accrued+eject. Good.

- What about `Grind_ReconRebuild` when has exit coverage: uses actual exit_target. So if the actual exit is at ejected price, it uses P. I6 check uses formula with eject. Passes.

- What about `Grind_ReconExitMatchesEntry` default parameter `shift = 0.0`. In I6, it's called with shift. In some other calls? Search: only in Grind_ReconCheckInvariants. So okay.

- What about `Grind_InvariantDetailI6` used for failure telemetry. It computes expected without accrued. Even after adding eject, it still misses accrued. Should include both. The audit should point out that this detail function is already inconsistent with I6 check when accrued != 0. With eject, it will be even more misleading. It must be updated to match `Grind_ReconExitMatchesEntry`: expected = ExitPrice + accrued + eject + shift. Currently it only has carry_shift. So it's a bug.

- What about `Grind_CarryShiftGetForRecon`: returns validated shift. It does not fetch accrued. The I6 check fetches accrued internally. The detail fetches shift separately. To fix detail, need fetch accrued and eject. So need a function to get eject offset. Not present.

- What about `Grind_CarryAccruedGet` and set/delete. Need analogous EjectOffsetGet/Set/Delete. ADR says variable name `GRIND_EJECT_OFFSET_<position>`. Need functions. Not in code. Implementation gap.

- What about `GRIND_EJECT_<magic>` command variable. The ADR says clean-up script and suite reset add prefix `GRIND_EJECT_`, which covers both command and offset? Wait command is `GRIND_EJECT_<magic>`, offset is `GRIND_EJECT_OFFSET_<position>`. Prefix `GRIND_EJECT_` covers both. But note: `GRIND_EJECT_OFFSET_` starts with `GRIND_EJECT_`. So adding prefix `GRIND_EJECT_` to cleanup will delete both. But careful: if cleanup deletes all `GRIND_EJECT_`, it will also delete `GRIND_EJECT_OFFSET_` and `GRIND_EJECT_<magic>`. That's intended. But if it deletes while a command is pending? On account switch, fine. On suite reset, fine. But `Grind_CarryPruneShiftGvs` currently only prunes `GRIND_CARRY_SHIFT_` and `GRIND_CARRY_RELEASE_`. It does not prune `GRIND_EJECT_OFFSET_`. Should it? It prunes orphan carry state. Orphan eject offset should also be pruned. But if we add prefix `GRIND_EJECT_` to cleanup script, that's a manual/account switch cleanup. The periodic prune should also prune orphan eject offsets. The ADR doesn't mention `Grind_CarryPruneShiftGvs`. So audit: add there too.

- What about `Grind_TestClearCarryState`: not shown. Should reset eject GVs. ADR says add prefix. But if tests run in same terminal, GVs persist. Need to clear. Also need test hooks for eject offset. Not in code.

- What about `Grind_CarryTestReset`: resets carry test state. Does not reset eject test state because none. Need test hooks.

- What about `Grind_OrderTestReset`: resets order test. Not relevant.

- What about `Grind_CarryExitPassBegin` uses `Grind_CarryPruneShiftGvs(magic)`. If we add eject prune, it should not delete eject offset for open positions. It should check position existence. The existing prune does that for shift. So add similar loop for eject offset.

- What about `Grind_CarryShiftDelete` being called on layer close. Should also delete eject offset. ADR says alongside accrued. So in `Grind_HandleSideDealFill` where `Grind_CarryAccruedDelete` is called, add `Grind_EjectOffsetDelete`. Also anywhere else layers are removed? `Grind_RemoveLayerAt` is called only in `Grind_HandleSideDealFill`? Let's check: `Grind_RemoveLayerAt` is called in `Grind_HandleSideDealFill` on DEAL_ENTRY_OUT_BY. Also maybe elsewhere? Search in provided code: only there. So deletion there. But also if recon rebuilds and layers are reset? `Grind_ReconResetSide` clears layers without deleting GVs. If recon fails or restarts, GVs persist. But they are keyed by position ticket. If position is gone, orphan. The cleanup script handles. But `Grind_CarryPruneShiftGvs` handles orphan shift on next carry pass. Eject should be pruned similarly. Also if a layer is removed due to recon? Not.

- What about `Grind_ExitQHoldCancelLayer`: if it cancels exit and deletes shift, but does not delete eject. Correct per ADR (eject persists). But if the layer is later removed (e.g., manually closed), the eject offset remains until close deletion. If close deletion missing, leak.

- What about `Grind_ExitQManageSide`: when it places a new exit, it sets `side.layers[i].exit_target = price;`. If the ejection offset is active, and the exit is re-placed, it uses formula+eject. Good.

- What about `Grind_ReconExitMatchesEntry` uses `Grind_CarryAccruedGet(position_id)`. If position_id is 0, accrued 0. For I6, position_id passed. Good.

- What about `Grind_ExitQFormulaTarget`: if position_ticket > 0, gets accrued. Needs eject. If position_ticket == 0, accrued 0 and eject 0. Could be called with 0? In recon rebuild for no exit coverage, it passes position_id. In exitq manage, passes position_ticket. So >0.

- What about `Grind_ExitQFormulaTarget` being used in recon for no exit coverage. If an ejected layer has no exit coverage, it computes F + A + E. That is the desired exit price. Good.

- What about `Grind_ReconRebuild` when has exit coverage: it sets `long_out.layers[n].exit_target = long_scratch[j].exit_target;` (actual). So after restart, the in-memory exit_target is the actual order price. Then on next tick, `Grind_ExitQManageSide` sees exit_order_ticket != 0, so does nothing. The actual order remains. I6 passes. Good.

- What about `Grind_ReconRebuild` when no exit coverage: it computes formula with eject. Then `Grind_ExitQManageSide` on next tick will place exit at that formula (clamped). Good.

- What about `Grind_CarryExitPassBegin` being called during rollover. If an ejection is active, it will modify the exit. To prevent, either skip ejected layers or add eject. The ADR doesn't mention. This is the main break.

- What about `Grind_CarryExitShiftLayer` setting `Grind_CarryAccruedSet(position_ticket, accrued_price);` even if exit_order_ticket == 0. If an ejection is active and the exit is missing (trim cancelled), the carry pass will set accrued based on swaps. That's normal. Then later re-place uses formula + accrued + eject. Good.

- What about `Grind_CarryExitShiftLayer` when exit_order_ticket != 0, it modifies the exit. If we add eject offset to new_exit, we must also adjust `intended` and `applied_shift`. The ADR doesn't mention this function. So it's a missing place.

- What about `Grind_CarryExitShiftLayer` sign guard. If the ejected price is beyond entry, sign guard might block. For an ejection, you might want to allow it. But the ADR says "clamped exactly as every exit is". The sign guard is a separate guard in carry pass. If ejection moves exit to best passive price, for a long, if market is below entry, the best passive exit (sell limit) must be above market, but could be below entry. The sign guard blocks if new_exit <= entry. So the carry pass would skip and not update. That might preserve the ejection, but the accrued update still occurs. However, the ejection itself is supposed to be allowed to cross entry? The ADR doesn't mention sign guard. The command sets exit to best passive price clamped. It doesn't apply sign guard. So an ejected exit could be below entry for a long. Then the carry pass sign guard would block further carry shifts, leaving the ejection. That's maybe okay. But if market recovers and theoretical becomes above entry, the carry pass might overwrite. So still a path.

- What about `Grind_CarryClampLongExit` / `ShortExit`: used by command. No change.

- What about `Grind_ExitQClampPassive`: used by exitq manage. No change.

- What about `Grind_ExitPrice`: pure formula. No change.

- What about `Grind_CarryShiftedExitPrice`: used in carry pass. It computes formula - dir*accrued*pip. No eject.

- What about `Grind_CarryShiftGetValidated`: if release GV set, returns shift even if out of bounds. This is used for I6. If an ejection offset is large, it doesn't affect shift. But if the carry pass overwrites and sets shift, it might set release GV? In carry pass, it does not set release GV. Wait `Grind_CarryExitShiftLayer` calls `Grind_CarryShiftSet` but does NOT set `Grind_CarryReleaseGvName`. Only `Grind_ExitQManageSide` sets release GV when placing/clamping. So in carry pass, shift is set without release. Then `Grind_CarryShiftGetForRecon` calls `Grind_CarryShiftGetValidated`, which checks release GV. If not set, it checks bound. If the applied_shift from carry pass is within bound? For normal carry, yes. For an ejection, if we don't add eject, shift may be small. So it passes bound. If we add eject to intended but not to new_exit, shift becomes -E, huge. Then bound check might delete it, causing I6 to use shift=0, and fail. So careful.

- What about `Grind_CarryShiftDelete` on hold cancel: deletes shift and release. If an ejection offset exists, it remains. Then re-place uses formula+eject. Good. But if the carry pass later runs, it will overwrite. So ejection lost.

- What about `Grind_CarryExitPassBegin` being called on timer. It uses current layers. If the deepest layer has been ejected and its exit order is at P, the carry pass will compute formula F, accrued A, and set new_exit = F+A. It will modify the exit order to F+A. This is a direct undo of the ejection. The operator would see the exit jump back. This is a critical operational bug.

- What about `Grind_CarryExitPassBegin` only runs in window 23:50-??. So ejection survives until next rollover. If operator ejects mid-day, it may survive until night. Then it's undone. The ADR's test "restart after accepted ejection: reconstruction passes I6" would pass if restart before carry pass. But the test suite might not simulate carry pass. The audit should demand a test for carry pass preserving ejection.

- What about `Grind_CarryExitPassBegin` being called even if `InpEnableCommandedEject` is false? It always runs if carry pass enabled. So ejection would be undone regardless.

- What about `Grind_ExitQManageSide` on every tick: it only places missing exits. It does not modify existing exits. So it won't overwrite ejection. Good. The only overwrite is carry pass and maybe `Grind_EnsureAddNext` for entries (not exits). `Grind_ApplyEntryHorizon` modifies entry orders, not exits. `Grind_TryRecenterOppositeL0` modifies L0 entry. So exits are only modified by carry pass and exitq manage (when missing). So carry pass is the main overwrite.

- What about `Grind_ExitQHoldCancelLayer` cancels exit under slot pressure. It deletes shift. Then later `Grind_ExitQManageSide` re-places using formula+eject. But during the time it's cancelled, if carry pass runs, it will see exit_order_ticket == 0, so it will not modify, but will set accrued. So ejection offset remains. When re-placed, formula includes accrued+eject. Good. But if carry pass runs after re-place, it will overwrite. So still.

- What about `Grind_CarryExitPassBegin` computing formula without accrued. It then in ShiftLayer computes theoretical with accrued. If we add eject, where? If we add to theoretical after accrued, then `accrued_price = theoretical - formula_exit` would include eject if we compute accrued_price after adding. So must compute accrued_price before adding eject. Something like:
```
const double theoretical_carry = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);
const double accrued_price = theoretical_carry - formula_exit;
Grind_CarryAccruedSet(position_ticket, accrued_price);
const double eject_offset = Grind_EjectOffsetGet(position_ticket);
const double theoretical = theoretical_carry + eject_offset;
...
const double intended = formula_exit + accrued_price + eject_offset;
const double applied_shift = Grind_Normalize(new_exit) - intended;
```
But the ADR didn't specify. So it's a missing implementation detail.

- What about `Grind_CarryExitShiftLayer` when `exit_order_ticket == 0`: it returns true after setting accrued. It should not add eject to accrued. So if we add eject, ensure only when modifying.

- What about `Grind_CarryExitPassBegin` passing formula_exit to work. It doesn't pass eject. Could pass eject offset as additional field.

- What about `Grind_CarryExitPassAppendWork` signature. Not in ADR.

- What about `Grind_CarryExitPassStep` processing. No.

- What about `Grind_CarryExitPassOnWindowClose`: no.

- What about `Grind_CarryPruneShiftGvs`: should also prune `GRIND_EJECT_OFFSET_`. It currently parses `GRIND_CARRY_SHIFT_` and `GRIND_CARRY_RELEASE_PREFIX`. Need add branch for `GRIND_EJECT_OFFSET_`. But careful: `GRIND_EJECT_<magic>` is a command variable, not keyed by position. It should not be pruned by position existence. So prune only offset prefix. The command variable is transient and cleared by EA. Cleanup script should delete both. The periodic prune should only delete orphan offsets. If we add prefix `GRIND_EJECT_` to prune, it might delete the command variable if we don't distinguish. So need specific `GRIND_EJECT_OFFSET_` for prune. The ADR says add prefix `GRIND_EJECT_` to clean-up script and suite reset. That's fine for account switch. But `Grind_CarryPruneShiftGvs` is a different function; if we add prefix `GRIND_EJECT_` there, it would try to parse suffix as ticket and check position existence. For `GRIND_EJECT_<magic>`, suffix is magic, not position. It might incorrectly treat magic as ticket and delete if no position with that ticket. That could delete a pending command. So should not use broad prefix there. Need specific `GRIND_EJECT_OFFSET_`. The audit should note this distinction.

- What about `Grind_CarryReleaseGvName`: returns prefix + position. The ADR says add prefix `GRIND_EJECT_` to clean-up script. But there is also `GRIND_CARRY_RELEASE_PREFIX`. Need check constant. Not shown. Probably "GRIND_CARRY_RELEASE_". The new offset prefix is "GRIND_EJECT_OFFSET_". The command is "GRIND_EJECT_" + magic. So broad prefix deletion in cleanup script would delete both. But if cleanup script runs while EA is running? It's account-switch clean-up, probably when EA off. So okay. But in `Grind_CarryPruneShiftGvs`, we need specific.

- What about `Grind_TestClearCarryState`: not shown. Should clear both command and offset. ADR says add prefix. But if it uses broad prefix, it will clear both. Good.

- What about `Grind_CarryTestReset`: resets carry test state. Should reset eject test state? If there are test hooks for eject, need reset. Not in code.

- What about `Grind_OrderTestReset`: no.

- What about `Grind_MarketTestReset`: no.

- What about `Grind_ReconResetSide`: does not clear GVs. If recon resets side, layers cleared. Eject GVs for those positions remain. If the positions still exist, recon will rebuild and I6 will read them. That's correct. If positions gone, orphan. Cleanup.

- What about `Grind_ReconRebuild` when a layer has exit coverage: it uses actual exit_target. But it does not set `exit_target` to formula+accrued+eject if the exit order is present. It uses actual. That's correct. I6 checks. But what if the exit order is present but at a wrong price? I6 fails. If it's at ejected price, I6 passes. Good.

- What about `Grind_ReconRebuild` when a layer has no exit coverage: it sets exit_target = formula. That formula includes eject. But then `Grind_ExitQManageSide` will place exit at that formula (clamped). If the ejection offset is large, the clamped price may be different from the ejected price? Wait, if the exit was cancelled and re-released, the formula target is F+A+E. Clamping may adjust it if it's not passive. But the original ejected price P was already clamped to be passive at command time. Market may have moved. The re-placement will clamp to current market. That's per ADR: "re-released would quietly undo an ejection stored as a shift." They want it to come back at EJECTED price, not formula price. But if we use formula+eject and clamp, it may come back at a price that is clamped to current market. Is that considered "ejected price"? The ADR test: "trim cancels and re-releases the ejected exit: it comes back at the EJECTED price, not the formula price". If the market has moved such that the ejected price is no longer passive, clamping will move it. That's acceptable? The ADR says "clamped exactly as every exit is". So the re-release will clamp. But if the market is unchanged, it comes back at P. If market moved, it will be at best passive. The test likely assumes market unchanged. So okay.

- But wait: `Grind_ExitQManageSide` computes formula = Grind_ExitQFormulaTarget (F+A+E). Then `Grind_ExitQClampPassive` clamps. If not clamped, price = F+A+E = P. If clamped, price = clamped. Then it sets shift = price - formula. If clamped, shift = clamped - (F+A+E). Then I6 expected = F+A+E+shift = clamped. Actual = clamped. Passes. So the ejection offset remains E, but the actual exit is clamped. That's fine. However, the stored eject_offset is still P - (F+A). The actual exit is clamped price Q. Then I6 expected = F+A+E+shift = F+A+ (P - F - A) + (Q - (F+A+E))? Wait shift = Q - (F+A+E) = Q - (F+A) - E. Then expected = F+A+E + Q - (F+A) - E = Q. So it matches. So the eject_offset plus shift together represent the actual price. The ejection offset is not updated to Q - (F+A). It remains P - (F+A). The shift compensates. That's fine. But if later the exit is re-placed again and shift is deleted? If not clamped and price == formula, shift deleted. If the actual price is Q (clamped), and later market moves so clamping no longer applies, the exit is not modified unless cancelled. So okay.

- What about `Grind_CarryExitPassBegin` when it runs after a re-place with clamp. It will compute formula F, accrued A, and theoretical F+A. It does not read eject E nor shift. It will modify exit to F+A. This will undo both ejection and clamp. So again carry pass is the destroyer.

- What about `Grind_CarryExitPassBegin` if the layer has no exit order (cancelled). It will set accrued but not modify. Then later re-place uses formula+eject. Good. But if carry pass runs after re-place, it overwrites.

- What about `Grind_ExitQManageSide` being called on every tick. It doesn't modify existing exits. So ejection survives ticks. Only carry pass modifies.

- What about `Grind_EnsureAddNext` for entries: it modifies entry orders, not exits. No.

- What about `Grind_ApplyEntryHorizon`: modifies entry orders. No.

- What about `Grind_TryRecenterOppositeL0`: modifies L0 entry. No.

- What about `Grind_ReconcileStrayL0`: cancels L0 entry. No.

- What about `Grind_CancelOwnEntryOrders`: cancels entry orders only. No.

- What about `Grind_ExitQHoldCancelLayer`: cancels exit. No re-place except via exitq manage.

- What about `Grind_ExitQManageSide` when `Grind_SlotExitAllowed` false? It skips placing. If exit was cancelled, it stays cancelled. But ejection offset remains. Later when slot available, it re-places. Good.

- What about `Grind_CarryExitPassBegin` being triggered by rollover gate. It runs once per day. So ejection lasts until next rollover. If operator ejects after rollover, lasts until next day. If before, undone same night. Critical.

- What about `Grind_CarryExitPassBegin` uses `Grind_CarryGateDue` and `Grind_CarryGateInWindow`. So only in 23:50-24:00. It processes all layers. So yes.

- What about `Grind_CarryExitPassStep` if `enable_carry_pass` is false? It might not run. Depends on config. But if enabled, it runs. The ADR doesn't mention disabling carry pass for ejected layers. So must patch.

- What about `Grind_CarryExitShiftLayer` modifies exit even if `InpEnableCommandedEject` is false? Yes, it doesn't know about eject. So if an ejection was done manually before, it would overwrite. But if switch false, command refused. However, the offset could exist from a previous run with switch true. Then switch false, carry pass still overwrites. Not a big concern.

- What about `Grind_ExitQFormulaTarget` being used in `Grind_ReconRebuild` for no exit coverage. If an ejection offset exists but the position is not the deepest? The ejection command validated deepest at time. But later depth may change (new layers added, or other layers closed). If the ejected layer is no longer deepest, its exit may not be required. `Grind_ExitQManageSide` may cancel it under `Grind_ExitQAllowed` if not required. It will delete shift but not eject. If later it becomes required again, formula includes eject. So it could re-appear at ejected price. Is that desired? The ADR says ejection is for deepest layer. If it's no longer deepest, should the ejection persist? The ADR doesn't say to delete offset when rank changes. It only deletes on layer close. So an ejected layer that becomes non-deepest will keep its offset. If its exit is cancelled and later re-released, it will come back at ejected price. That might be okay? But it could cause an exit far from market to be required again if it becomes deepest due to other layers closing. The ADR says "ejected price is fixed at command time; a second command re-ejects." It doesn't mention rank changes. But the validation only at command time. So this is a potential issue: ejection offset persists even if the layer is no longer deepest. If it later becomes deepest again, its exit will be re-placed at the old ejected price, which may be far from market. That could be undesirable. But the ADR says "The layer then exits as a limit when the market touches it." If it's not deepest, its exit may be cancelled. If re-released, it comes back at ejected price. The test only covers trim cancels and re-releases. It doesn't cover rank changes. But this is more policy. The audit asks "any path that cancels and re-places the deepest exit". The trim path is covered. Rank changes could cancel and later re-place. But the offset persistence is by design? They want ejection to survive cancel/re-release. So if it becomes non-deepest, it's still an ejected layer. The validation only at command time. Not a bug per ADR.

- What about `Grind_ExitQManageSide` when it cancels non-allowed layers: it calls `Grind_ExitQHoldCancelLayer` which deletes shift. It does not delete eject. So if an ejected layer becomes non-deepest, its exit is cancelled, shift deleted, eject remains. If later it becomes deepest, re-place uses formula+eject. That's consistent with "durability". But if it never becomes deepest, eject offset leaks until layer closes. On close, if deletion missing, leak. If deletion added, okay.

- What about `Grind_ExitQHoldCancelLayer` when it cancels due to slot pressure, not rank. It deletes shift. Eject remains. Re-place uses formula+eject. Good.

- What about `Grind_CarryExitPassBegin` pruning shift GVs. It calls `Grind_CarryPruneShiftGvs(magic)`. This function checks position existence and deletes shift/release for non-existent. It does not touch eject. So orphan eject offsets persist. Not a correctness break for open positions, but memory leak. Over time, many orphans. The cleanup script handles account switch, but not periodic. Should add prune for eject offset.

- What about `Grind_CarryExitPassBegin` when it appends work for layers. It uses `layer.exit_order_ticket`. If an exit was cancelled, ticket 0. It still appends work. In `Grind_CarryExitShiftLayer`, if exit_order_ticket == 0, it returns true after setting accrued. So it doesn't modify. Good.

- What about `Grind_CarryExitShiftLayer` if exit_order_ticket != 0 but the order was already filled? It calls `Grind_ModifyPendingPrice`. If order no longer exists, `Grind_SelectOurOrder` fails, returns false, increments failed. It doesn't modify. But it already set accrued. That's normal.

- What about `Grind_CarryExitShiftLayer` setting `Grind_CarryShiftSet` even if the modification failed? Let's check: 
```
const double old_price = Grind_OrderGetPriceOpen(exit_order_ticket);
if(!Grind_ModifyPendingPrice(exit_order_ticket, new_exit, magic)) {
   g_grind_carry_exit_failed++;
   retcode_out = ...;
   return false;
}
const double intended = formula_exit + accrued_price;
const double applied_shift = Grind_Normalize(new_exit) - intended;
Grind_CarryShiftSet(position_ticket, applied_shift);
```
It sets shift only after successful modify. Good. If modify fails, shift not set. But accrued was set. So I6 after failed carry pass? The exit remains at old price. I6 expected = F+A+E+shift_old. If shift_old was from previous, and accrued changed, expected changes. The actual exit is old. I6 may fail because accrued changed. Wait, this is a pre-existing issue: carry pass updates accrued before modifying exit. If modify fails, accrued is updated but exit not modified. Then I6 check on restart would expect new accrued, but actual exit is old. That would fail. But maybe the carry pass retries? There is retry mechanism? In code, `Grind_CarryExitShiftLayer` returns false, and `g_grind_carry_exit_failed++`. The retry arrays are present but not used in this snippet? There's `g_grind_carry_exit_retry_tickets` etc. but I don't see logic to retry. Maybe incomplete. Anyway, not directly eject. But if we add eject, same issue.

- What about `Grind_ReconExitMatchesEntry` tolerance 2 points. Ejection offset can be large. If carry pass overwrites, diff huge, fails.

- What about `Grind_InvariantDetailI6` missing accrued. Let's verify: 
```
const double expected = Grind_ExitPrice(layer.entry_price, exit_pips, point, dir) + carry_shift;
```
No accrued. So if accrued != 0, detail expected is wrong. The check in `Grind_ReconExitMatchesEntry` uses accrued + shift. So on I6 failure, the logged expected will not match the actual expected used. This is a pre-existing bug. With eject, it will be even more wrong. The ADR only says add eject to I6 check. But the detail function must also be updated to include accrued and eject. Otherwise telemetry is misleading. The audit should flag.

- What about `Grind_ReconFailureOffendingForReason`: it checks reason == "I6_LONG_EXIT" but not "I6_LONG_EXIT_FILL_ADVERSE". Pre-existing. Not eject.

- What about `Grind_ReconCheckInvariants` when exit_is_filled: it calls `Grind_ReconExitMatchesEntry` with `exit_is_filled = true`. If the exit filled at the ejected price, and eject_offset is set, expected = F+A+E+shift. If shift is 0, expected = P. Actual deal price = P. diff=0, passes. If the exit filled at a better price, diff positive, passes. If the exit filled at a worse price (adverse), diff negative, fails with I6_*_EXIT_FILL_ADVERSE. But for a passive limit, fill should be at limit or better. So okay.

- What about `Grind_ReconRebuild` when an exit position exists (DEAL_ENTRY_IN). It sets `exit_target = tickets[i].price`. That is the exit position's open price, which is the fill price of the exit order. For a passive limit, that's the limit price. Good.

- What about `Grind_ReconRebuild` when both exit order and exit position exist? It overwrites exit order with exit position. That's normal.

- What about `Grind_ReconRebuild` when an EXT order exists but no ENT position? It creates orphan exit. I4 fails. Not eject.

- What about `Grind_ReconRebuild` when an ENT position exists but no EXT coverage? It sets exit_target = formula. If that layer is not required (rank not required), I3 doesn't fail. But it still sets exit_target. If later it becomes required, exitq manage will place at that exit_target? Wait `Grind_ExitQManageSide` computes its own formula, not using layer.exit_target. It computes formula = Grind_ExitQFormulaTarget. So the layer.exit_target set in recon is only used for display? `Grind_TryPlaceExitForLayer` uses layer.exit_target. But `Grind_ExitQManageSide` does not use layer.exit_target for placement; it recomputes. So the recon-set exit_target for non-covered layers is only for in-memory state. When exitq manage places, it computes formula again. So it will include eject. Good.

- What about `Grind_TryPlaceExitForLayer`: if used, it places at layer.exit_target. If layer.exit_target was set by recon with formula+eject, good. If set by AppendLayer without eject, but then ejected, the command would update layer.exit_target? The command sets exit target to passive price and modifies order. It should also update layer.exit_target. The ADR doesn't explicitly say, but likely yes. If `Grind_TryPlaceExitForLayer` is used later, it would use the updated exit_target. Not in provided code. But audit can note.

- What about `Grind_AppendLayer` sets exit_target without accrued. Then `Grind_ExitQManageSide` is called immediately after in `Grind_HandleSideDealFill`. It will compute formula with accrued (which may be 0 initially) and eject (0). So it will place exit at formula. It sets layer.exit_target = price. So the AppendLayer exit_target is overwritten. Good.

- What about `Grind_ExitQManageSide` when placing a new exit for a layer that already has an eject_offset. It computes formula with eject. If clamped, it sets shift. If not clamped, it deletes shift. It does not touch eject. Good.

- What about `Grind_CarryShiftDelete` on layer close: should delete eject. Missing.

- What about `Grind_CarryAccruedDelete` on layer close: should delete eject. Missing.

- What about `Grind_CarryShiftDelete` in `Grind_ExitQHoldCancelLayer`: deletes shift, not eject. Correct.

- What about `Grind_CarryShiftDelete` in `Grind_ExitQManageSide` when not clamped: deletes shift, not eject. Correct.

- What about `Grind_CarryShiftDelete` in `Grind_CarryShiftGetValidated` when out of bound: deletes shift, not eject. Correct, but if shift is deleted, I6 will use shift=0. If eject exists, expected = F+A+E. Actual exit may be F+A+E+shift_old. If shift_old is out of bound, it's deleted, so I6 may fail because actual exit differs from expected by shift_old. This is a pre-existing issue with carry shift bounds. For ejection, the shift might be a clamp adjustment. If the clamp adjustment is large (e.g., market moved far), it could exceed bound and be deleted, causing I6 failure. But the ADR says eject offset has no bound. The shift is separate. If shift is out of bound, it gets deleted, potentially breaking I6 for an ejected layer. Is that possible? The shift is set in `Grind_ExitQManageSide` when clamped. Clamp distance is max(stops, freeze, point). Normally small. So unlikely out of bound. But if market gaps, clamp could be large. Not main.

- What about `Grind_CarryShiftGetValidated` uses `Grind_CarryNightlyMaxPips`. For an ejected layer, if the carry pass sets a shift (without eject), it may be small. If we patch carry pass to include eject in intended but not new_exit, shift would be -E, likely out of bound, deleted. Then I6 expected = F+A+E, actual = F+A (if carry pass modified). Fails. So patch must be consistent.

- What about `Grind_CarryShiftWithinBound` max_price = max_nights * nightly_max_pips * pip_size * 2.0. Eject offset has no bound. The shift for clamp might be within bound. But if ejection offset is huge, and we don't include it in shift, shift is just clamp. So bound not issue. If we incorrectly include eject in shift, bound deletes it. So keep separate.

- What about `Grind_CarryShiftGetForRecon`: if release GV exists, returns shift without bound. If not, validates. For an ejected layer, if the exit was re-placed without clamp, shift is 0 and release GV deleted. I6 uses shift=0. Good. If clamped, release GV set, shift returned. Good.

- What about `Grind_CarryReleaseGvName`: used to bypass bound. Not eject.

- What about `Grind_CarryPruneShiftGvs`: prunes shift and release. If it prunes a release GV but not shift? It deletes both? It checks name prefix and if position doesn't exist, deletes the specific name. So it deletes whichever GV it found. If it finds release first, deletes release. Then shift remains. Next iteration deletes shift. So both. For eject, need similar.

- What about `Grind_CarryExitPassBegin` calls `Grind_CarryPruneShiftGvs(magic)` before processing. If we add eject prune, it should be careful not to delete eject offset for open positions. The existing function checks position existence. So add branch for `GRIND_EJECT_OFFSET_` and check position exists. Do not add branch for `GRIND_EJECT_` because it's magic-keyed.

- What about `Grind_ExitQFormulaTarget` uses `Grind_CarryAccruedGet`. Need `Grind_EjectOffsetGet`. The ADR says variable `GRIND_EJECT_OFFSET_<position>`. So implement functions.

- What about `Grind_ReconExitMatchesEntry` uses `Grind_CarryAccruedGet`. Need `Grind_EjectOffsetGet`. Also `Grind_CarryShiftGetForRecon` is separate. The function signature has `shift` parameter. It should add eject inside. Or caller could add. ADR says add inside.

- What about `Grind_InvariantDetailI6`: needs `Grind_CarryAccruedGet` and `Grind_EjectOffsetGet`. The function currently only takes carry_shift. It doesn't take position_id? It takes layer, which has position_id. So can fetch inside. Should update expected.

- What about `Grind_ReconFailureOffendingForReason`: not target.

- What about `Grind_ReconCheckInvariants` I3 checks: `Grind_ExitQRequired` and `Grind_ReconLayerHasExitCoverage`. No target. But if an ejected layer's exit is cancelled, and it's required, I3 fails. That's correct. Eject offset doesn't affect.

- What about `Grind_ReconCheckInvariants` I1 counts: no target.

- What about `Grind_ReconCheckInvariants` I7 depth: no.

- What about `Grind_ReconCheckInvariants` I5 indices: no.

- What about `Grind_ReconCheckInvariants` I8 pending add: no.

- What about `Grind_ReconCheckPendingAddCorrupt`: no.

- What about `Grind_ReconComputeRanks`: no.

- What about `Grind_ExitQRanks`: no.

- What about `Grind_ExitQEntryBeats`: no.

- What about `Grind_ExitQFormulaTarget` in `Grind_RebuildBookFromTicketsInner`: yes.

- What about `Grind_ExitQFormulaTarget` in `Grind_ExitQManageSide`: yes.

- What about `Grind_ExitQFormulaTarget` anywhere else? Search in code: only those two. So ADR table lists two places. But actually there are more: `Grind_CarryExitPassBegin` uses `Grind_ExitPrice` directly, not `Grind_ExitQFormulaTarget`. So it's a third place where exit target is computed. The ADR missed it. That's the main finding.

- Also `Grind_CarryExitShiftLayer` computes `theoretical` using `Grind_CarryShiftedExitPrice`. That's another computation.

- Also `Grind_AppendLayer` computes `exit_target` with `Grind_ExitPrice`. But no accrued/eject. Could be considered a place where exit target is computed. But it's for new layer. If an eject offset somehow existed for that position, it wouldn't see it. Not possible.

- Also `Grind_TryPlaceExitForLayer` uses `layer.exit_target`. Not a computation.

- Also `Grind_CarryShiftedExitPrice` is used in carry pass. It's a computation.

- Also `Grind_CarryClampLongExit` and `ShortExit` are clamps, not target.

- Also `Grind_ExitQClampPassive` is clamp.

- Also `Grind_ReconExitMatchesEntry` is check.

- Also `Grind_InvariantDetailI6` is check/detail.

- Also `Grind_ReconRebuild` when no coverage uses `Grind_ExitQFormulaTarget`. That's covered if function patched.

- Also `Grind_CarryExitPassBegin` uses `Grind_ExitPrice` to compute formula. It does not use `Grind_ExitQFormulaTarget` because it wants to apply accrued itself. But it needs eject. So add.

- Also `Grind_ExitQManageSide` sets `side.layers[i].exit_target = price;` after placing. If an eject offset exists, price includes it. Good.

- Also `Grind_HandleSideDealFill` on EXT fill: it sets `side.layers[layer_idx].exit_order_ticket = 0; exit_position_ticket = position_id;` It does not update exit_target. The exit_target remains whatever it was (the order price). The exit position price is the same. So I6 uses exit_target from recon? Actually in live, I6 isn't called on every tick. It's called on recon/restart. So fine.

- What about `Grind_ExitQManageSide` on next tick after EXT fill: it sees exit_position_ticket != 0, so skips. Good.

- What about `Grind_HandleSideDealFill` on DEAL_ENTRY_OUT_BY: it deletes shift and accrued. Need add eject. Also it calls `Grind_RemoveLayerAt`. If eject not deleted, leak.

- What about `Grind_ExitQHoldCancelLayer`: it deletes shift. If the exit order was actually filled but not yet processed, it tries to find exit deal position and set exit_position_ticket. It does not delete eject. That's correct because layer not closed yet. When closed, deletion.

- What about `Grind_ExitQManageSide` when it cancels non-allowed layers: if an exit position exists, `Grind_ExitQHoldCancelLayer` checks `layer.exit_order_ticket == 0` and returns true immediately. So it doesn't cancel exit positions. That's for trim of orders only. If an exit has filled into a position, it's not cancelled. Good.

- What about `Grind_CarryExitPassBegin` iterating layers: it includes layers with exit_position_ticket != 0? It uses `layer.exit_order_ticket`. If exit_order_ticket == 0, it still appends work with exit_order_ticket 0. In `Grind_CarryExitShiftLayer`, if exit_order_ticket == 0, it sets accrued and returns. So it doesn't touch filled exits. Good.

- What about `Grind_CarryExitShiftLayer` when exit_order_ticket != 0 but the layer has exit_position_ticket != 0? That shouldn't happen if exit order filled, ticket becomes 0. So okay.

- What about `Grind_CarryExitPassBegin` when a layer has no position? It skips? It checks `layer.position_ticket == 0`. Good.

- What about `Grind_CarryExitPassBegin` using `Grind_ExitPrice(layer.entry_price, exit_pips, point, dir)`. If an ejection offset exists, it ignores it. So yes.

- What about `Grind_CarryExitShiftLayer` using `Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size)`. If an ejection offset exists, it ignores it. So yes.

- What about `Grind_CarryExitShiftLayer` setting `Grind_CarryAccruedSet(position_ticket, accrued_price);` before checking sign guard. If sign guard blocks, it still sets accrued. Then the exit order is not modified. The ejection remains. But the accrued has changed. Then I6 expected = F + newA + E + shift. Actual exit = P = F + oldA + E. Diff = newA - oldA. If newA != oldA, I6 fails! Wait, this is important. Let's analyze. In normal carry pass, if sign guard blocks, it sets accrued but does not modify exit. Then the exit is still at the old price which reflected old accrued. The new accrued is stored. On restart, I6 expects F + newA + shift. Shift was from previous? Actually if sign guard blocks, it does not set shift. So shift remains whatever it was. The actual exit is old_price. Expected = F + newA + shift_old. For this to match old_price, we need old_price = F + newA + shift_old. But old_price was computed with oldA: old_price = F + oldA + shift_old (if shift was the only adjustment). So if newA != oldA, mismatch. This suggests the carry pass sign guard skip is a pre-existing bug? Or maybe when sign guard blocks, it means the new theoretical would cross entry, so it skips modifying and also does not update accrued? But the code sets accrued before the sign guard. Let's re-read:
```
const double accrued_price = theoretical - formula_exit;
Grind_CarryAccruedSet(position_ticket, accrued_price);

if(exit_order_ticket == 0)
   return true;

if(Grind_CarrySignGuardBlocks(entry_price, theoretical, is_long)) {
   sign_guard_skipped_out = true;
   g_grind_carry_exit_skipped++;
   Grind_CarryEmitExitShiftEvent(...);
   return false;
}
...
```
Yes, it sets accrued before sign guard. So if sign guard blocks, accrued is updated but exit not modified. This would cause I6 failure on restart. Unless the sign guard block only happens when theoretical crosses entry, and in that case the exit is left at a price that is not based on the new accrued? But the new accrued is stored. Then I6 expected includes new accrued. So mismatch. This is a pre-existing bug in carry pass. Maybe the sign guard is rare. But with ejection, it could be more common because ejected exit may be far. If an ejection places exit below entry for a long, then later carry pass computes theoretical (F+A) which may also be below entry? Actually for a long, normal exit is above entry. The theoretical is F + A (where A is negative for positive swap? Let's check sign. `Grind_CarryShiftedExitPrice` returns formula_exit - direction * accrued_pips * pip_size. For long, direction=1. If accrued_pips > 0, theoretical = formula - accrued*pip. So it moves exit down. If accrued_pips is large enough, theoretical <= entry, sign guard blocks. Meanwhile accrued_price = theoretical - formula = -accrued_pips*pip. So accrued is negative. It stores negative accrued. The exit remains at old price. I6 expected = F + newA + shift. If shift is 0, expected = F + newA. Actual = old price = F + oldA. If oldA != newA, fails. So indeed, any sign guard skip causes I6 failure on restart. This is a real bug. But maybe the carry pass retries and eventually modifies? It returns false, increments skipped. The pass continues. It doesn't retry? There is retry array but not used. So it's a latent bug. With ejection, if an ejected long exit is below entry, and carry pass runs, it will compute theoretical maybe below entry, sign guard blocks, accrued updated, exit unchanged. Then I6 fails. So the ejection could cause I6 failure even without overwriting. But the ADR's test "restart after accepted ejection: reconstruction passes I6" would fail if a carry pass ran and sign guard blocked. But if carry pass overwrites, it fails anyway. So the carry pass is a major problem.

- What about `Grind_CarryExitShiftLayer` when `exit_order_ticket == 0`: it returns true after setting accrued. If an ejection offset exists and the exit is missing, it sets accrued. No exit modified. I6 is not checked until exit re-placed. When re-placed, formula uses new accrued + eject. So I6 will match. Good.

- What about `Grind_CarryExitShiftLayer` when modify fails: it returns false, but accrued already set. The exit remains at old price. Same I6 mismatch. Pre-existing.

- So the carry pass is fundamentally not designed to preserve an external offset. It recomputes everything from formula+accrued and overwrites. The ADR's approach of adding offset to formula and I6 is insufficient because the carry pass bypasses `Grind_ExitQFormulaTarget`. It directly computes formula and accrued. The offset must be incorporated there, but also the sign guard and failure paths must be handled to avoid I6 mismatch. The safest is to skip layers with an eject offset in the carry pass, or to add offset to both the modified price and the intended shift, and ensure accrued is not polluted. But even then, sign guard could block and cause mismatch. So maybe skip ejected layers entirely in carry pass? But then carry shifts won't apply to them. The ADR says carry and ejection stay separable. It might be acceptable to skip carry for ejected layers because the operator command overrides. But then if the ejection is later cleared? It's only cleared on close. So the layer will never get carry adjustments. That might be intended: an ejected layer is heading for exit soon. So skipping carry for ejected layers is probably the right fix. The audit should point this out.

- What about `Grind_CarryExitPassBegin` could check `Grind_EjectOffsetGet(position_ticket) != 0.0` and skip appending work. That would prevent overwrite and accrued changes. That's a simple fix. The ADR doesn't mention. So audit: need to skip ejected layers in carry pass, or incorporate offset consistently.

- What about `Grind_CarryPruneShiftGvs`: if we skip ejected layers, their shift GVs? They might still have shift from clamp. If we skip, we don't delete shift. But shift is used by I6. If we skip, the exit remains as is. I6 uses eject + shift. Good. But if the layer closes, shift deleted. If not, prune. So fine.

- What about `Grind_CarryExitPassBegin` appending work for ejected layers: if we don't skip, it will overwrite. So must skip.

- What about `Grind_CarryExitPassBegin` also emits snapshot with accrued swaps. No.

- What about `Grind_ExitQManageSide` on every tick: it doesn't modify existing exits. So if carry pass is skipped for ejected layers, ejection survives. Good.

- What about `Grind_ExitQManageSide` when it needs to re-place an ejected exit (after trim). It uses formula+eject. Good.

- What about `Grind_ExitQManageSide` when it places a new exit for a layer that has an eject offset but the offset is huge. It clamps. Good.

- What about `Grind_ExitQManageSide` when it places a new exit for a layer that has an eject offset, and the exit is not required? It doesn't place. If it becomes required later, it places. Good.

- What about `Grind_ExitQManageSide` when it cancels a non-allowed layer that has an eject offset. It deletes shift. Eject remains. If later allowed, re-places with eject. Good.

- What about `Grind_ExitQManageSide` when it cancels a non-allowed layer that has an eject offset, and then the layer closes without exit? That can't happen because it's not allowed, so no exit. If it closes, the layer is removed somehow? Only via exit fill. If it has no exit, it can't close. Unless manual close. Manual close would trigger DEAL_ENTRY_OUT_BY? Not sure. If manual close, the EA might process deal and remove layer. The DELETE of eject should happen. If missing, leak.

- What about `Grind_HandleSideDealFill` on DEAL_ENTRY_OUT_BY: it deletes shift and accrued. Need add eject. This is the layer close path. Missing.

- What about `Grind_ExitQHoldCancelLayer` when it finds an exit deal position (exit order filled) and sets exit_position_ticket. It does not delete shift or accrued. It deletes shift? Wait:
```
if(Grind_ExitQFindExitDealPosition(...)) {
   layer.exit_position_ticket = pos_out;
   layer.exit_order_ticket = 0;
   ... queue closeby
} else {
   layer.exit_order_ticket = 0;
   Grind_CarryShiftDelete(layer.position_ticket);
}
```
In the branch where it finds an exit deal position, it does NOT delete shift. That's correct because the layer is not closed yet; it's waiting for CloseBy. When CloseBy fills, DEAL_ENTRY_OUT_BY will delete shift/accrued/eject. In the else branch, it deletes shift because the exit order is gone and not filled? Actually if cancel failed and order not found, it deletes shift. Eject remains. Good.

- What about `Grind_HandleSideDealFill` on DEAL_ENTRY_OUT_BY: it deletes shift and accrued, then removes layer. Add eject.

- What about `Grind_CarryShiftDelete` called in `Grind_ExitQHoldCancelLayer` else branch: deletes shift and release. Eject remains. Good.

- What about `Grind_CarryShiftDelete` called in `Grind_ExitQManageSide` when not clamped: deletes shift and release. Eject remains. Good.

- What about `Grind_CarryShiftDelete` called on close: should also delete eject. Missing.

- What about `Grind_CarryAccruedDelete` called on close: should be alongside eject. Missing.

- What about `Grind_CarryShiftDelete` and `Grind_CarryAccruedDelete` are separate functions. The ADR says "deleted when the layer closes, alongside the existing Grind_CarryAccruedDelete (grind_engine.mqh:1408)". In code, both are called at that line? Let's check line numbers: in `Grind_HandleSideDealFill`, there is:
```
Grind_CarryShiftDelete(side.layers[i].position_ticket);
Grind_CarryAccruedDelete(side.layers[i].position_ticket);
```
So both. The ADR says alongside existing `Grind_CarryAccruedDelete`, implying add `Grind_EjectOffsetDelete` next to it. Missing.

- What about `Grind_CarryShiftDelete` also deletes release. The eject delete should just delete offset.

- What about `Grind_TestClearCarryState`: not shown. Need add prefix `GRIND_EJECT_`. But also need to ensure it clears both offset and command. ADR says add prefix `GRIND_EJECT_` to both clean-up script and suite reset. So okay.

- What about `scripts/grind_gv_clean.mq5`: not shown. Need add prefix.

- What about `Grind_CarryPruneShiftGvs`: should add `GRIND_EJECT_OFFSET_` to prune. Not in ADR.

- What about `Grind_CarryExitPassBegin` calling `Grind_CarryPruneShiftGvs(magic)`. If we add eject prune, it will delete orphan eject offsets. Good.

- What about `Grind_CarryExitPassBegin` appending work: if we skip ejected layers, we should not append. So check `Grind_EjectOffsetGet(position_ticket) != 0.0`.

- What about `Grind_CarryExitShiftLayer` if we don't skip: must add eject to theoretical and intended. But also handle sign guard and accrued. The simplest is skip.

- What about `Grind_ExitQFormulaTarget`: implement `Grind_EjectOffsetGet`. The variable name is `GRIND_EJECT_OFFSET_<position>`. Note the command variable is `GRIND_EJECT_<magic>`. The prefix `GRIND_EJECT_` is shared. When implementing `Grind_EjectOffsetGet`, use specific prefix `GRIND_EJECT_OFFSET_`. When cleaning up, use broad `GRIND_EJECT_` to delete both. But careful: `Grind_CarryPruneShiftGvs` should not use broad prefix because it would misinterpret command variable. So use specific `GRIND_EJECT_OFFSET_` for prune.

- What about `Grind_EjectOffsetSet` and `Delete`. Need.

- What about `Grind_EjectCommand` polling. Not in code. The ADR describes script writes `GRIND_EJECT_<magic>`. The EA polls and clears. This is a new feature. Not in provided code. So we can't audit its implementation. But we can note that the command variable shares prefix with offset. Cleanup must distinguish.

- What about validation: "the layer has a resting exit order (guaranteed by F1)". F1 goes live cycle 3. This ADR depends. Not code.

- What about "the layer at rank == depth - 1 on its side (the deepest)". In code, ranks are computed by entry. `Grind_FindDeepestLayerArrayIndex` finds max layer_index. But rank == depth-1 is based on entry ranking. The deepest by entry is not necessarily the highest layer_index. The validation says "rank == depth - 1". In code, `Grind_ExitQRequired` uses rank and depth. The deepest by entry is the one with rank depth-1. So the command should identify the layer with that rank. The ADR says "the layer at rank == depth - 1 on its side (the deepest)". So it's entry-ranked deepest, not layer_index deepest. This is consistent with exit queue. But note: `Grind_FindDeepestLayerArrayIndex` finds max layer_index, which may not be the same as rank depth-1. The add target uses `Grind_FindDeepestLayerArrayIndex` (max layer_index). So there is a discrepancy between "deepest" for add target and "deepest" for exit queue. The ADR's validation says rank == depth-1, which is entry-ranked. The mechanism moves that layer's exit. Does the add target use the same layer? `Grind_ComputeAddTarget` uses `Grind_FindDeepestLayerArrayIndex` (max layer_index). If an ejection moves the exit of the entry-ranked deepest layer, but the max layer_index layer is different, the add target might be anchored to a different layer. This could affect the roll: after the exit fills, the side depth decreases, and the next add is quoted near market. The ADR says "The side is now one below its cap, so the engine re-quotes its next add -- which lands near the market." The add target is based on the deepest layer by layer_index. If the ejected layer was not the max layer_index, the add target might be based on another layer. But after the exit fills, that layer is removed. The next add uses the new max layer_index. So maybe okay. But the validation could allow ejecting a layer that is not the max layer_index. Then the exit moves, but the add target still anchored to a different layer. The roll might not complete as expected. The ADR says "the deepest layer" but defines it by rank. The code's `Grind_FindDeepestLayerArrayIndex` uses layer_index. This is a potential mismatch. Let's examine: In a side, layers have layer_index assigned sequentially. Entry price ranking can differ from layer_index if prices cross. The exit queue ranks by entry price. The deepest by rank is the one with worst entry (for long, lowest entry? Let's check `Grind_ExitQEntryBeats`: for long, if entry_a < entry_b - eps, a beats b. So rank 0 is best (lowest entry? Actually for long, lower entry is better? Wait, for a long, lower entry is better (bought cheaper). So rank 0 is lowest entry. rank depth-1 is highest entry (worst). That is the deepest layer (most recent add, usually highest entry). Typically layer_index also increases with add, so max layer_index is the highest entry. But if price moves such that a newer add has a lower entry? Add targets are at intervals; for long, adds are above previous? Actually for long, add target = anchor + add_pips. So each add is higher than previous. So entry price increases with layer_index. So max layer_index = highest entry = rank depth-1. So they match. For short, add target = anchor - add_pips, so entry price decreases with layer_index. Rank for short: `Grind_ExitQEntryBeats` for short: if entry_a > entry_b + eps, a beats b. So rank 0 is highest entry (best for short). rank depth-1 is lowest entry (worst). Max layer_index has lowest entry. So match. So normally max layer_index = rank depth-1. So validation using rank is consistent with `Grind_FindDeepestLayerArrayIndex`. But if prices cross due to gaps, they might differ. The ADR explicitly says ranking stay by entry price. So the deepest is entry-ranked. The add target uses max layer_index. If they differ, there is a bug. But probably not the main audit.

- What about `Grind_ExitQManageSide` uses `Grind_ExitQRanks` and `Grind_ExitQRequired`. So it protects the entry-ranked deepest. `Grind_ComputeAddTarget` uses max layer_index. This is a pre-existing potential inconsistency. With ejection, if you eject the entry-ranked deepest, and it's not max layer_index, the add target might not be near market after exit fills. But after exit fills, that layer is removed. The new max layer_index might be the one that was second deepest. The add target will be based on it. That's normal. So the roll completes. The ejection just removes a layer. The add target is based on the remaining deepest. So okay.

- What about `Grind_ExitQManageSide` when it places exits: it iterates i in array order. It computes ranks. It places for required. It doesn't use layer_index order. So ejection offset on a specific position is read by `Grind_ExitQFormulaTarget` via position_ticket. So it's per-position. Good.

- What about `Grind_ReconRebuild` building layers: it adds layers in order of discovery. The layer_index is from comment. So order in array may not be sorted. But ranks computed by entry. So okay.

- What about `Grind_ReconRebuild` when no exit coverage: it sets exit_target = formula. If there are multiple layers, it computes for each. If an ejected layer has no exit, it gets formula+eject. Good.

- What about `Grind_ReconRebuild` when has exit coverage: it sets exit_target = actual. If the actual is ejected price, good. If the actual is formula (because carry pass overwrote), then I6 fails. So carry pass is the issue.

- What about `Grind_CarryExitPassBegin` being called on timer. It uses `g_grind_long.layers` and `g_grind_short.layers`. If an ejection was commanded but not yet processed, the layer may not have exit? The command moves the exit. So it has exit. If carry pass runs, it overwrites. So yes.

- What about `Grind_CarryExitPassBegin` if `InpEnableCommandedEject` is true and an ejection is pending? The command is processed in EA poll, not shown. It might set eject offset and modify exit. Then carry pass could run. So need to handle.

- What about `Grind_ExitQFormulaTarget` being called with position_ticket > 0. It fetches accrued. Need fetch eject. If eject offset exists, it adds. Good.

- What about `Grind_ReconExitMatchesEntry` being called with position_id > 0. It fetches accrued. Need fetch eject. Good.

- What about `Grind_InvariantDetailI6` being called with layer. It has position_id. Need fetch accrued and eject. Good.

- What about `Grind_CarryShiftGetForRecon` being called with position_id. It fetches shift. No eject. The I6 check adds eject separately. The detail should add eject. Good.

- What about `Grind_CarryShiftGetValidated` bound check. If an ejection offset is large, it doesn't affect shift. So shift bound check still works. Good.

- What about `Grind_CarryShiftSet` in `Grind_ExitQManageSide` when clamping an ejected exit. The shift is relative to formula+eject. So shift is small. Bound check okay. If the exit is clamped far due to market gap, shift could be large. Bound check might delete it. Then I6 expected = F+A+E, actual = clamped price. Mismatch. But this is a pre-existing risk with clamp shifts. The ADR says offset has no bound, but shift still has bound. If the clamp shift is out of bound, it gets deleted, breaking I6. Is that possible? The clamp shift is the difference between clamped price and formula+eject. If the ejection set exit to P = F+A+E. Then when re-placed, if market moved such that P is not passive, clamp moves it to Q. The shift = Q - (F+A+E). Q is the best passive price at market. If market moved far, Q could be far from P. The shift could be large. The bound check uses max_nights * nightly_max_pips * pip * 2. This is based on swap pips. It's meant for carry shifts. A clamp shift due to market movement could exceed it. Then `Grind_CarryShiftGetValidated` would delete the shift, and I6 would fail because actual Q != expected F+A+E. This is a pre-existing issue for any clamped exit, but ejection increases the chance because the ejected price may be far from the formula+accrued. Actually, the ejection itself is large. The clamp shift is relative to formula+eject. The ejection offset E is already large and not bounded. The clamp shift is Q - (F+A+E). If Q is near market, and E is large, then Q - (F+A+E) is roughly -E (if Q ~ F+A). So the shift would be large negative! Wait, let's analyze carefully.

Suppose initial state: formula F, accrued A, no eject. Exit target = F+A. Operator ejects: sets exit to P = best passive at market. Suppose market is far from F+A. Eject offset E = P - (F+A). This E can be large. The exit is modified to P. No shift is set? The command should set eject offset and modify exit. It might also set shift? The ADR says "Set the layer's exit target to the best PASSIVE price at the market... and modify the resting exit order to it." It doesn't mention setting shift. It stores eject offset = P - (F+A). So after command, actual exit = P, eject_offset = E, shift = whatever it was (probably 0). I6 expected = F+A+E+shift = P. Passes.

Now, later, the exit is cancelled (e.g., trim) and re-released. `Grind_ExitQManageSide` computes formula = F+A+E = P. It clamps to current market. Suppose market has moved such that P is no longer passive. It clamps to Q. It sets shift = Q - formula = Q - P. So shift = Q - P. This shift is the clamp adjustment. If market moved significantly, Q - P could be large. The bound check on shift might delete it if |Q-P| exceeds bound. Then I6 expected = F+A+E = P, actual = Q. Fails. So the re-release after a market move could break I6 due to shift bound. The ADR test "trim cancels and re-releases the ejected exit: it comes back at the EJECTED price, not the formula price" assumes market unchanged, so Q = P, shift = 0, passes. If market moved, it comes back at clamped price, and I6 might fail if shift out of bound. This is a subtle issue. The ADR says "The offset has no bound check, deliberately: an ejection is supposed to be large." But the shift (clamp adjustment) does have a bound check. If the clamp adjustment is large, it gets deleted, breaking I6. To be robust, maybe the exit target should be updated to the clamped price and the eject offset adjusted to absorb the clamp, keeping shift 0. Or the shift bound should be bypassed for clamped re-placements of ejected layers. The ADR doesn't address. This could be a finding: the shift bound check in `Grind_CarryShiftGetValidated` can delete a large clamp shift on an ejected layer, causing I6 failure. But is the clamp shift likely to be large? The clamp distance is max(stops, freeze, point). Usually small (e.g., 10 points). So Q - P is small if P was already passive at command time and market moved slightly. If market moved a lot, P might be far from market, and clamping to best passive could move it a lot. For example, long exit P = 1.2000. Market drops to 1.1000. Best passive sell limit is ask + min_dist ~ 1.1000. So Q = 1.1000. Shift = Q - (F+A+E) = 1.1000 - 1.2000 = -0.1000. That's huge. The bound check would delete it. Then I6 expected = 1.2000, actual = 1.1000. Fails. So yes, this is a real scenario. The ejection is supposed to be large; if the market trends away, the exit trails behind. If it gets cancelled and re-released, it will be clamped to market, and the shift will be large. The bound check will delete it. I6 fails. The ADR's test only covers unchanged market. So this is a gap.

But wait: in `Grind_ExitQManageSide`, when it places a new exit and clamps, it sets `Grind_CarryShiftSet` and also `GlobalVariableSet(Grind_CarryReleaseGvName(...), 1.0)`. The release GV bypasses the bound check in `Grind_CarryShiftGetValidated`. Let's check:
```
if(GlobalVariableCheck(release_gv))
   return Grind_CarryShiftGet(position_ticket);
```
So if the release GV is set, the shift is returned without bound check. In `Grind_ExitQManageSide`, when it sets shift due to clamp, it also sets release GV. So for re-released clamped exits, the shift is not bound-checked. Good! So the large clamp shift is preserved. Then I6 expected = F+A+E+shift = P + (Q-P) = Q. Passes. So that's okay. The release GV protects it. But what about the carry pass? The carry pass sets shift but does NOT set release GV. So if the carry pass sets a large shift (which it shouldn't for normal carry), it could be bound-checked. But for ejected layers, if we don't skip them, the carry pass might set a shift that's small (since it ignores E). But if we patch carry pass to include E, it might set a large shift? Let's see: if we patch carry pass to add E to new_exit and intended, then applied_shift = new_exit - (F+A+E+clamp?) Actually if no clamp, new_exit = F+A+E, intended = F+A+E, shift = 0. So no large shift. If clamped, new_exit = Q (clamped), intended = F+A+E, shift = Q - (F+A+E) = Q - P. That could be large. But carry pass does not set release GV. So if clamped, the large shift would be bound-checked and deleted, breaking I6. So if we patch carry pass to handle eject, we must also set release GV for clamped carry shifts on ejected layers. Or better, skip ejected layers in carry pass. That avoids the issue.

Thus, skipping ejected layers in carry pass is the safest. The audit should recommend that.

- What about `Grind_CarryExitPassBegin` if it skips ejected layers, then the carry pass won't update accrued for them. That's fine because ejection overrides. But what if the ejection is later cleared? It's only cleared on close. So the layer will exit soon. So skipping is okay.

- What about `Grind_CarryExitPassBegin` if it skips, it should also skip the prune? No, prune is separate.

- What about `Grind_CarryExitPassBegin` if it skips, the `g_grind_carry_exit_eligible` count will be lower. That's fine.

- What about `Grind_CarryExitPassBegin` if it skips, the summary telemetry will show fewer eligible. Fine.

- What about `Grind_CarryExitPassStep` retry logic? Not used.

- What about `Grind_CarryExitShiftLayer` if we don't skip, we need to add eject to theoretical and intended, and set release GV if clamped. But also the sign guard. If sign guard blocks, it returns false but accrued is already set. That would cause I6 mismatch. So for ejected layers, we probably want to skip entirely before setting accrued. So skip at append time.

- What about `Grind_CarryExitPassBegin` appending work: it should check `Grind_EjectOffsetGet(layer.position_ticket) != 0.0` and `continue`. That's a simple patch.

- What about `Grind_CarryExitPassBegin` if the ejection offset is zero but there is a shift? That's normal carry. It processes.

- What about `Grind_CarryExitPassBegin` if the ejection offset is nonzero but the layer has no exit order? It still skips, so accrued won't be updated. But if the exit is missing, later re-place will use old accrued + eject. Is that okay? The old accrued might be stale. But if the layer is ejected, we don't want carry to interfere. The operator command overrides. So okay.

- What about `Grind_ExitQFormulaTarget` when computing for an ejected layer with stale accrued (because carry skipped). It uses the stale accrued + eject. The ejected price was computed with the stale accrued at command time. So it remains consistent. Good.

- What about `Grind_ReconExitMatchesEntry` with stale accrued. It matches. Good.

- What about `Grind_ExitQManageSide` when re-placing an ejected exit. It uses stale accrued + eject. If the market has moved, it clamps. It sets shift relative to that. I6 matches. Good.

- What about `Grind_CarryPruneShiftGvs`: if we skip ejected layers, their shift GVs might still be pruned if position exists? It only deletes if position doesn't exist. So it won't delete shift for open positions. Good.

- What about `Grind_CarryPruneShiftGvs` for eject offset: should prune orphan offsets. Add specific prefix.

- What about `Grind_HandleSideDealFill` deletion: add eject.

- What about `Grind_TestClearCarryState` and `grind_gv_clean.mq5`: add prefix.

- What about `Grind_InvariantDetailI6`: add accrued and eject.

- What about `Grind_ReconFailureOffendingForReason`: not target, but if I6 fails due to eject, it might not capture offending comment for I6_LONG_EXIT_FILL_ADVERSE. Pre-existing.

- What about `Grind_ReconCheckInvariants` I6 check: it passes `long_shift` from `Grind_CarryShiftGetForRecon`. It does not pass eject. The function `Grind_ReconExitMatchesEntry` must fetch eject. Good.

- What about `Grind_ReconCheckInvariants` when `exit_is_filled` and diff adverse. The check allows diff >= 0 for long. If eject offset is positive, expected > actual? Let's not overcomplicate.

- What about `Grind_ExitQFormulaTarget` being used in `Grind_RebuildBookFromTicketsInner` for layers without exit coverage. If the layer has an eject offset, it computes F+A+E. But if the layer is not required (rank not required), it still sets exit_target. That's fine. If it later becomes required, exitq manage will recompute and place. The exit_target set here is not used for placement. So okay.

- What about `Grind_ExitQManageSide` when placing a new exit: it computes formula = Grind_ExitQFormulaTarget. It clamps. It places. It sets `side.layers[i].exit_target = price;`. If the layer has an eject offset, price = F+A+E or clamped. It does not update the eject offset. So the eject offset remains E = P - (F+A). If the price is clamped to Q, then the actual exit is Q. The eject offset E is no longer equal to Q - (F+A). The shift is set to Q - (F+A+E). So the combination of eject and shift gives Q. If later the exit is cancelled and re-released again, `Grind_ExitQManageSide` will again compute formula = F+A+E = P, clamp to current market, and set a new shift. The old shift is deleted (since not clamped or different). So it will use the original eject P, not the last clamped Q. That means the ejection target is always the original P, not the last clamped Q. Is that desired? The ADR says "The ejected price is fixed at command time; a second command re-ejects." So yes, the ejected price is P. If the market moved and it was clamped, then later re-released, it goes back to P (or clamps again). So the ejected price is persistent. That's consistent.

- What about `Grind_CarryExitPassBegin` if it doesn't skip, it would overwrite P with F+A. So skip is needed.

- What about `Grind_ExitQManageSide` when it places a new exit for a layer that has no eject offset but has a shift from carry. It computes formula = F+A. It clamps. It sets shift = price - (F+A). This overwrites the carry shift. That's normal.

- What about `Grind_CarryExitShiftLayer` when it modifies an exit that has a clamp shift from `Grind_ExitQManageSide`. It computes new_exit = F+A (carry). It sets shift = new_exit - (F+A) = 0. It overwrites the clamp shift. That's normal carry behavior. But if the layer had an ejection, it overwrites. So skip.

- What about `Grind_CarryExitPassBegin` if it skips ejected layers, it won't prune their shift GVs? The prune function is called separately. It will prune if position doesn't exist. If position exists, it leaves shift. So okay.

- What about `Grind_CarryExitPassBegin` if it skips ejected layers, the `g_grind_carry_exit_eligible` count won't include them. The summary will show fewer. Fine.

- What about `Grind_CarryExitPassBegin` if it skips, it doesn't emit `CARRY_EXIT_SHIFT` event for them. Fine.

- What about `Grind_CarrySnapshotFields` includes accrued_swap_long/short. It doesn't include eject. Not needed.

- What about `Grind_CarryEmitExitShiftEvent` fields. Not needed.

- What about `Grind_CarryShiftGetForRecon` for an ejected layer. It returns shift. If shift is 0, I6 adds eject. Good. If shift is nonzero, adds both. Good.

- What about `Grind_CarryShiftGetValidated` when release GV is set. It returns shift. For an ejected layer that was clamped, release is set. So shift returned. I6 adds eject. Good.

- What about `Grind_CarryShiftDelete` on close: deletes shift and release. Should also delete eject. Missing.

- What about `Grind_CarryAccruedDelete` on close: deletes accrued. Should also delete eject. Missing.

- What about `Grind_CarryShiftDelete` in `Grind_ExitQHoldCancelLayer`: deletes shift and release. Does not delete eject. Correct.

- What about `Grind_CarryShiftDelete` in `Grind_ExitQManageSide` when not clamped: deletes shift and release. Does not delete eject. Correct.

- What about `Grind_CarryShiftDelete` in `Grind_CarryShiftGetValidated` when out of bound: deletes shift and release. Does not delete eject. Correct.

- What about `Grind_CarryPruneShiftGvs`: if it prunes shift/release for a non-existent position, it should also prune eject offset for that position. Add.

- What about `Grind_CarryExitPassBegin` calling `Grind_CarryPruneShiftGvs(magic)`: if we add eject prune, it will delete orphan eject. Good.

- What about `Grind_TestClearCarryState`: not shown. Should clear all `GRIND_EJECT_` variables. The ADR says add prefix. Good.

- What about `scripts/grind_gv_clean.mq5`: not shown. Add prefix.

- What about `Grind_ExitQFormulaTarget` implementation: need to add `+ Grind_EjectOffsetGet(position_ticket)`. But careful: `Grind_CarryAccruedGet` returns 0 if not exists. `Grind_EjectOffsetGet` should return 0 if not exists. Good.

- What about `Grind_ReconExitMatchesEntry`: add `+ Grind_EjectOffsetGet(position_id)`. But note: `position_id` is the position ticket. The eject offset is keyed by position ticket. Good.

- What about `Grind_InvariantDetailI6`: add `+ accrued + eject_offset`. It currently only has `carry_shift`. It should fetch accrued and eject. The function signature could be changed to accept them, or fetch inside. Since it has `layer.position_id`, it can fetch. But note: `Grind_CarryAccruedGet` and `Grind_EjectOffsetGet` are in grind_carry.mqh, which is included? `grind_recon.mqh` includes `grind_exitq.mqh` which includes `grind_carry.mqh`. So functions available. Good.

- What about `Grind_ReconFailureOffendingForReason`: if reason is `I6_LONG_EXIT_FILL_ADVERSE`, it doesn't capture offending comment. Pre-existing. Not eject-specific.

- What about `Grind_ReconCheckInvariants` I6 check: if `exit_is_filled` and the exit was ejected, the expected includes eject. If the exit filled at the ejected price, diff 0. Passes. If it filled at a better price, passes. If it filled at a worse price, fails. Good.

- What about `Grind_ReconRebuild` when an exit position exists: `exit_target = tickets[i].price` (the fill price). I6 check uses that as `exit_target`. If the exit filled at a better price than the limit, the diff will be favorable. Passes. If the exit filled at the limit, diff 0. Passes.

- What about `Grind_ExitQManageSide` when it places an exit for a layer that has an eject offset, and the formula target is already passive. It places at formula. It sets `side.layers[i].exit_target = price;`. It deletes shift if price == formula. So eject offset remains, shift 0. I6 expected = F+A+E = price. Passes.

- What about `Grind_ExitQManageSide` when it places an exit for a layer that has an eject offset, and the formula target is not passive. It clamps to Q. It sets shift = Q - formula. It sets release. I6 expected = F+A+E+shift = Q. Passes.

- What about `Grind_ExitQManageSide` when it places an exit for a layer that has an eject offset, but the layer is not required? It doesn't place. If it becomes required later, places. Good.

- What about `Grind_ExitQManageSide` when it cancels a non-allowed layer that has an eject offset. It deletes shift. Eject remains. If later allowed, re-places with eject. Good.

- What about `Grind_ExitQManageSide` when it cancels a non-allowed layer that has an eject offset, and then the layer closes? If it closes without exit? Not possible unless manual. Manual close would trigger DEAL_ENTRY_OUT? Actually manual close would generate DEAL_ENTRY_OUT (not OUT_BY) maybe. The EA's `Grind_HandleSideDealFill` only handles DEAL_ENTRY_OUT_BY for layer removal. So manual close might not be processed? That's a different issue. If manual close, the layer might remain in state until recon. Recon would rebuild from broker tickets, see no position, and remove. But the eject GV would remain unless cleanup. The recon rebuild doesn't delete GVs. So orphan. The cleanup script handles account switch, but not recon. So orphan eject GV could persist. The `Grind_CarryPruneShiftGvs` would eventually prune if it runs. But if carry pass is skipped for ejected layers? Prune is separate. It runs at start of carry pass. It checks position existence. If position is gone, it deletes. So if we add eject prune, it will clean up. Good.

- What about `Grind_ReconRebuild` when a layer is removed due to no position? It doesn't delete GVs. So prune is needed.

- What about `Grind_ExitQFormulaTarget` when position_ticket > 0 but the eject offset is for a closed position. It would still return it if called. But it's only called for open layers. So okay.

- What about `Grind_CarryExitPassBegin` if it skips ejected layers, it won't update accrued. If the layer closes, deletion handles. If it doesn't close, accrued stays stale. But the ejected price is based on stale accrued. That's consistent. So okay.

- What about `Grind_ExitQFormulaTarget` if accrued is stale and eject is set. The formula target is F + staleA + E. The actual exit is P = F + staleA_at_command + E. If staleA changes (because carry skipped), then F+staleA+E changes. Wait! This is crucial. The eject offset E is defined as P - (F + A_at_command). If later A changes (even if we skip carry, A doesn't change; but if carry pass updates A for other reasons? We skip, so A doesn't change). But what if A changes due to some other path? The only path that updates accrued is `Grind_CarryExitShiftLayer`. If we skip ejected layers, A remains at the value it had when the ejection was commanded. So E remains valid. If we don't skip, A changes, and E is no longer P - (F+A). Then formula F+A+E = P + (A_new - A_old). I6 expected = F+A_new+E+shift. Actual exit = P (if not overwritten). Diff = A_new - A_old. So I6 fails. This is another reason to skip ejected layers in carry pass: to keep A stable. If we don't skip, we must also update E when A changes, or not change A. Skipping is simpler.

- What if accrued changes due to a manual command? There is no other. So skip works.

- What about `Grind_CarryAccruedSet` in `Grind_CarryExitShiftLayer` when `exit_order_ticket == 0`. If we skip ejected layers, this won't run for them. So A stays. Good.

- What about `Grind_ExitQFormulaTarget` using accrued. If A is stable, E is valid. Good.

- What about `Grind_ReconExitMatchesEntry` using accrued. If A is stable, matches. Good.

- What about `Grind_InvariantDetailI6` using accrued. If we add, matches.

- So the fix is to skip ejected layers in carry pass. The ADR didn't specify, but it's necessary.

- What about `Grind_CarryExitPassBegin` if it skips, it should still prune orphan eject GVs. So call prune before loop, and in loop skip if eject offset exists.

- What about `Grind_CarryExitPassBegin` if it skips, the `g_grind_carry_exit_eligible` count should be the number of non-ejected layers. That's fine.

- What about `Grind_CarryExitPassBegin` if it skips, the `Grind_CarryExitPassAppendWork` could be given a flag. Or just check inside.

- What about `Grind_CarryExitShiftLayer` if called directly (e.g., tests) with an ejected layer. Should it skip? The skip should be in `Grind_CarryExitPassBegin` or `Grind_CarryExitPassStep`. The ADR doesn't specify. Audit can recommend.

- What about `Grind_CarryExitShiftLayer` setting `Grind_CarryAccruedSet` even if `exit_order_ticket == 0`. If we skip ejected layers in `Grind_CarryExitPassBegin`, this won't be called for them. Good.

- What about `Grind_CarryExitPassBegin` if the layer has an eject offset but the offset is 0? That's not ejected. Process normally.

- What about `Grind_EjectOffsetGet` returning 0.0 if not exists. Need to distinguish between no offset and offset of 0.0. An ejection could theoretically result in exactly 0 offset if the passive price equals formula+accrued. That's unlikely. But if it happens, the skip condition `!= 0.0` would not skip, and carry pass would process. But if offset is 0, it means the ejected price equals the formula target. Then there's nothing to preserve. So it's fine to process. So `!= 0.0` is okay.

- What about `Grind_EjectOffsetGet` should return a bool or check existence. Not critical.

- What about `Grind_ExitQFormulaTarget` if eject offset is 0 but variable exists. It adds 0. Fine.

- What about `Grind_ReconExitMatchesEntry` if eject offset is 0. Fine.

- What about `Grind_InvariantDetailI6` if eject offset is 0. Fine.

- What about `Grind_CarryPruneShiftGvs` for eject: it should delete the variable if position doesn't exist. Use `GRIND_EJECT_OFFSET_` prefix. It should not delete `GRIND_EJECT_<magic>`. So specific.

- What about `Grind_CarryExitPassBegin` calling `Grind_CarryPruneShiftGvs(magic)`. If we add eject prune, it will delete orphan offsets. Good.

- What about `Grind_TestClearCarryState` and `grind_gv_clean.mq5`: they should delete all `GRIND_EJECT_` variables. That includes command and offset. Good.

- What about `Grind_CarryShiftDelete` on close: should call `Grind_EjectOffsetDelete`. Missing.

- What about `Grind_CarryAccruedDelete` on close: should also call `Grind_EjectOffsetDelete`. Missing.

- What about `Grind_ExitQHoldCancelLayer`: when it cancels exit due to slot pressure, it deletes shift. It does not delete eject. Correct.

- What about `Grind_ExitQManageSide` when it cancels non-allowed layers: calls `Grind_ExitQHoldCancelLayer`. Correct.

- What about `Grind_ExitQManageSide` when it places new exit: it does not reset eject. Correct.

- What about `Grind_ExitQManageSide` when it places new exit for a layer that has no eject offset but has a shift. It deletes shift if not clamped. That's normal.

- What about `Grind_ExitQManageSide` when it places new exit for a layer that has an eject offset and is clamped. It sets shift and release. It does not delete eject. Correct.

- What about `Grind_ExitQManageSide` when it places new exit for a layer that has an eject offset and is not clamped. It deletes shift. Eject remains. Correct.

- What about `Grind_ExitQManageSide` when it places new exit for a layer that has an eject offset, and the price equals formula. It deletes shift. Eject remains. Correct.

- What about `Grind_ExitQManageSide` when it places new exit for a layer that has an eject offset, and the price is clamped, and the clamp shift is large. It sets release GV. So I6 will use shift without bound. Correct.

- What about `Grind_CarryExitPassBegin` if it skips ejected layers, it won't set release GV for them. But their release GV might already be set from a previous clamp. If the exit is not modified, release GV remains. That's fine. If the exit is later re-placed and not clamped, `Grind_ExitQManageSide` deletes shift and release. So release cleared. Good.

- What about `Grind_CarryExitPassBegin` if it skips ejected layers, it won't update accrued. So if the layer had a release GV, it stays. Not an issue.

- What about `Grind_CarryPruneShiftGvs` if it prunes release GV for an open position? It only prunes if position doesn't exist. So no.

- What about `Grind_CarryPruneShiftGvs` if it prunes eject offset for an open position? It should not. It checks position existence. So no.

- What about `Grind_CarryPruneShiftGvs` if it encounters `GRIND_EJECT_<magic>` and we add a branch for `GRIND_EJECT_`? It would parse magic as ticket and check position existence. That could delete the command variable if no position with that ticket exists. That would be bad: a pending command would be deleted. So we must NOT add broad `GRIND_EJECT_` to prune. Only `GRIND_EJECT_OFFSET_`. The ADR says add prefix `GRIND_EJECT_` to clean-up script and suite reset. That's different from prune. So audit should warn: do not use broad prefix in `Grind_CarryPruneShiftGvs`; use specific `GRIND_EJECT_OFFSET_`.

- What about `Grind_CarryPruneShiftGvs` parsing suffix: for `GRIND_EJECT_OFFSET_<position>`, suffix is position. Good.

- What about `Grind_CarryPruneShiftGvs` if it sees `GRIND_EJECT_OFFSET_` with non-numeric suffix? It will parse 0 and skip. Good.

- What about `Grind_CarryPruneShiftGvs` if it sees `GRIND_EJECT_` command variable? If we don't add branch, it will hit `else continue`. So it won't delete. Good.

- What about `Grind_TestClearCarryState` and `grind_gv_clean.mq5`: they should use `StringFind(name, "GRIND_EJECT_") == 0` to delete all. That will delete both command and offset. That's intended for cleanup. But if run while EA is running, it could delete a pending command or offset. But account-switch cleanup is presumably when EA is off. Suite reset is in tests. So okay.

- What about `Grind_CarryExitPassBegin` if it skips ejected layers, the `g_grind_carry_exit_eligible` count should be adjusted. Not a bug.

- What about `Grind_CarryExitPassBegin` if it skips, the `Grind_CarryExitPassAppendWork` should not be called. So need a check.

- What about `Grind_CarryExitPassBegin` if it skips, the `Grind_CarryPruneShiftGvs` still runs. Good.

- What about `Grind_CarryExitPassStep` if `g_grind_carry_exit_work_count` is 0, it emits summary and resets. Good.

- What about `Grind_CarryExitPassOnWindowClose`: no.

- What about `Grind_CarryExitPassReset`: no.

- What about `Grind_CarryExitPassAppendWork`: no.

- What about `Grind_CarryExitShiftLayer`: if we don't skip, need to add eject. But skip is recommended.

- What about `Grind_CarryExitShiftLayer` if we add eject, the `theoretical` used for sign guard should include eject? If the ejected price is far, the sign guard might block. If it blocks, accrued is set. To avoid I6 mismatch, we should not set accrued before sign guard. Or skip. So skip is better.

- What about `Grind_CarryExitShiftLayer` if we skip ejected layers, the function won't be called. So no change needed.

- What about `Grind_CarryExitPassBegin` if we skip, the `Grind_CarryExitPassAppendWork` loop should check `Grind_EjectOffsetGet(layer.position_ticket) != 0.0` and `continue`. That's the patch.

- What about `Grind_CarryPruneShiftGvs` if we add eject prune, it should be called before the loop. It is called at the end of `Grind_CarryExitPassBegin`. Good.

- What about `Grind_CarryPruneShiftGvs` if it prunes eject offset for a position that is closed, but the position ticket might be reused? MQL5 position tickets are unique and not reused. So okay.

- What about `Grind_ExitQFormulaTarget` implementation: add `+ Grind_EjectOffsetGet(position_ticket)`. But note: `Grind_CarryAccruedGet` returns 0 if not exists. `Grind_EjectOffsetGet` should return 0 if not exists. Good.

- What about `Grind_ReconExitMatchesEntry`: add `+ Grind_EjectOffsetGet(position_id)`. But note: it already has `shift` parameter. The order should be `ExitPrice + accrued + eject + shift`. ADR says `exit + accrued + eject_offset + shift`. Good.

- What about `Grind_InvariantDetailI6`: add `accrued` and `eject`. The function currently only takes `carry_shift`. It should fetch `accrued` and `eject` from position_id. Or the caller can pass them. Since it has `layer`, it can fetch. But `Grind_InvariantDetailI6` is in `grind_recon.mqh`, which includes `grind_exitq.mqh` which includes `grind_carry.mqh`. So functions available. So:
```
const double accrued = (layer.position_id > 0) ? Grind_CarryAccruedGet(layer.position_id) : 0.0;
const double eject = (layer.position_id > 0) ? Grind_EjectOffsetGet(layer.position_id) : 0.0;
const double expected = Grind_ExitPrice(...) + accrued + eject + carry_shift;
```
And update JSON to include these fields. Currently it includes `carry_shift`. Should add `accrued` and `eject_offset`. This is a telemetry fix.

- What about `Grind_ReconFailureOffendingForReason`: if reason is `I6_LONG_EXIT`, it finds offending comment. If reason is `I6_LONG_EXIT_FILL_ADVERSE`, it doesn't. This is pre-existing. Not eject-specific. But if an ejection causes adverse fill, it might fail with `I6_LONG_EXIT_FILL_ADVERSE` and the offending comment won't be captured. That's a minor bug. Could mention.

- What about `Grind_ReconCheckInvariants` I6: it calls `Grind_ReconExitMatchesEntry` with `long_shift`. It does not pass eject. The function fetches. Good.

- What about `Grind_ReconCheckInvariants` I6 detail: it calls `Grind_InvariantDetailI6` with `long_shift`. The detail function must fetch accrued/eject. Good.

- What about `Grind_ReconRebuild` when no exit coverage: it sets `exit_target = Grind_ExitQFormulaTarget`. That function fetches eject. Good.

- What about `Grind_ReconRebuild` when has exit coverage: it sets `exit_target = long_scratch[j].exit_target`. That's from broker. No formula. Good.

- What about `Grind_ExitQManageSide` when placing new exit: it uses `Grind_ExitQFormulaTarget`. Good.

- What about `Grind_ExitQManageSide` when it sets `side.layers[i].exit_target = price;`. It does not update eject offset. Good.

- What about `Grind_ExitQManageSide` when it sets `Grind_CarryShiftSet` and `Grind_CarryReleaseGvName`. It does not touch eject. Good.

- What about `Grind_ExitQHoldCancelLayer` when it deletes shift: `Grind_CarryShiftDelete` deletes shift and release. It does not touch eject. Good.

- What about `Grind_CarryShiftDelete` on close: should also delete eject. Missing.

- What about `Grind_CarryAccruedDelete` on close: should also delete eject. Missing.

- What about `Grind_CarryShiftDelete` in `Grind_CarryShiftGetValidated`: deletes shift and release. Does not touch eject. Good.

- What about `Grind_CarryPruneShiftGvs`: if it prunes shift/release, it should also prune eject. Add.

- What about `Grind_TestClearCarryState`: not shown. Add.

- What about `scripts/grind_gv_clean.mq5`: not shown. Add.

- What about `Grind_CarryTestReset`: no eject test state. If tests use GVs, need reset. The ADR says `Grind_TestClearCarryState` handles suite reset. Not `Grind_CarryTestReset`. So okay.

- What about `Grind_OrderTestReset`: no.

- What about `Grind_MarketTestReset`: no.

- What about `Grind_ReconResetSide`: no.

- What about `Grind_ReconResetCounters`: no.

- What about `Grind_ReconFailureClear`: no.

- What about `Grind_ArchiveMarker`: no.

- What about `Grind_TelemetryCritical`: no.

- What about `Grind_QueueScalpClosedEvent`: no.

- What about `Grind_AccumulateScalpPnl`: no.

- What about `Grind_SpreadPipsLive`: no.

- What about `Grind_QueueExitMicrostructureMeasure`: no.

- What about `Grind_DeriveCloseByQueueFromBook`: no.

- What about `Grind_QueueCloseBy`: no.

- What about `Grind_CloseBy`: no.

- What about `Grind_CancelOwnEntryOrders`: no.

- What about `Grind_HaltCritical`: no.

- What about `Grind_GuardsAllowTrading`: no.

- What about `Grind_OnTickEngine`: no.

- What about `Grind_OnTradeTransactionEngine`: no.

- What about `Grind_ArchiveRecordFill`: no.

- What about `Grind_ArchiveResolveOrderPrice`: no.

- What about `Grind_ArchiveFillLogFields`: no.

- What about `Grind_ArchiveEnqueue`: no.

- What about `Grind_Heartbeat...`: no.

So the main findings:

1. **Carry pass overwrites ejection**: `Grind_CarryExitPassBegin` and `Grind_CarryExitShiftLayer` compute exit target from `Grind_ExitPrice` + accrued, ignoring `GRIND_EJECT_OFFSET_`. They will modify the ejected exit back to formula+accrued at the next rollover window. This breaks the ejection and causes I6 failure on restart. Fix: skip ejected layers in carry pass, or incorporate offset consistently (but skip is safer due to accrued/sign guard issues).

2. **I6 detail telemetry missing accrued and eject**: `Grind_InvariantDetailI6` computes expected without accrued (pre-existing) and without eject. Must include both to match `Grind_ReconExitMatchesEntry`.

3. **Eject offset not deleted on layer close**: `Grind_HandleSideDealFill` deletes shift and accrued but not eject. Add `Grind_EjectOffsetDelete`.

4. **Orphan eject offsets not pruned**: `Grind_CarryPruneShiftGvs` only prunes shift/release. Add specific `GRIND_EJECT_OFFSET_` pruning. Do not use broad `GRIND_EJECT_` because it would delete command variable.

5. **Cleanup script and test reset**: ADR says add prefix `GRIND_EJECT_` to `grind_gv_clean.mq5` and `Grind_TestClearCarryState`. Ensure they are updated. Not in code.

6. **Potential shift bound on clamped re-release**: If an ejected exit is cancelled and re-released after market move, `Grind_ExitQManageSide` sets a large clamp shift and release GV, which bypasses bound. So okay. But if carry pass processes it (if not skipped), it sets shift without release, and bound may delete it, breaking I6. So again skip carry pass.

7. **Sign guard and accrued update in carry pass**: Even if offset is added to carry pass, the sign guard can block and leave accrued updated, causing I6 mismatch. So skip ejected layers in carry pass.

8. **Ranking**: Verified `Grind_ExitQRanks` ranks by entry only. Eject offset doesn't affect. Good.

9. **Reconstruction after ejection**: If no carry pass has run, I6 passes if `Grind_ReconExitMatchesEntry` includes eject. If carry pass runs, fails. So test must include carry pass.

10. **Other places**: `Grind_AppendLayer` sets exit_target without accrued/eject. But it's for new layers. Not a problem. `Grind_TryPlaceExitForLayer` uses layer.exit_target. If layer.exit_target is set by recon with formula+eject, okay. If it's set by command, command should update it. Not in code. But not in provided code.

11. **Command variable and offset share prefix**: Cleanup must use broad `GRIND_EJECT_`, but prune must use specific `GRIND_EJECT_OFFSET_`. Otherwise pending command could be deleted by prune.

12. **`Grind_CarryExitPassBegin` uses `Grind_ExitPrice` directly, not `Grind_ExitQFormulaTarget`**. So adding offset to `Grind_ExitQFormulaTarget` alone does nothing for carry pass. This is the key architectural miss.

13. **`Grind_CarryExitShiftLayer` sets `Grind_CarryAccruedSet` before sign guard and before modification**. If an ejected layer is processed and sign guard blocks, accrued changes, I6 fails. Skip avoids.

14. **`Grind_ReconExitMatchesEntry` default shift parameter**: if called without shift (e.g., other callers), it still adds eject if patched. That's correct. But ensure no other callers expect no eject. Only I6 calls it. Good.

15. **`Grind_ExitQFormulaTarget` default position_ticket 0**: if called with 0, no eject. Could be called from somewhere with 0? In recon no coverage, passes position_id. In exitq manage, passes position_ticket. So >0. Good.

16. **`Grind_InvariantDetailI6` missing `position_id` in JSON?** It includes `position_ticket`. Good.

17. **`Grind_ReconFailureOffendingForReason` doesn't handle `I6_*_EXIT_FILL_ADVERSE`**. Pre-existing. If ejection leads to adverse fill, telemetry won't capture offending comment. Minor.

18. **`Grind_CarryExitPassBegin` if it skips ejected layers, the `g_grind_carry_exit_eligible` count should reflect. Not a bug.

19. **`Grind_CarryExitPassBegin` if it skips, the `Grind_CarryExitPassAppendWork` should not be called for ejected layers. Need to add check.

20. **`Grind_CarryExitPassStep` retry logic** not implemented. Not eject-specific.

21. **`Grind_ExitQManageSide` when placing new exit for an ejected layer**: It uses formula+eject. If the layer is not the deepest, it might not be required, so it won't place. But if it's required, it places. Good.

22. **`Grind_ExitQManageSide` when it cancels a non-allowed layer that has an eject offset**: It deletes shift. Eject remains. If later allowed, re-places with eject. Good.

23. **`Grind_ExitQHoldCancelLayer` when it finds an exit deal position**: It does not delete shift. Eject remains. When CloseBy fills, deletion. Good.

24. **`Grind_HandleSideDealFill` on DEAL_ENTRY_OUT_BY**: deletes shift and accrued. Add eject. Also note it calls `Grind_ExitQManageSide` after removing layer. That will re-place exits for remaining layers. It does not touch eject for remaining. Good.

25. **`Grind_HandleSideDealFill` on DEAL_ENTRY_IN for EXT**: it sets exit_position_ticket, clears exit_order_ticket. It does not delete shift. The shift is still needed for I6 if recon runs before CloseBy. Eject remains. Good.

26. **`Grind_ReconRebuild` when an EXT position exists**: it sets exit_target = position price. I6 uses that. If the exit filled at ejected price, and shift is set, expected = F+A+E+shift. If shift is 0, expected = P. Passes. If shift is nonzero (clamp), expected = Q. The position price should be Q (the limit price). So passes. Good.

27. **`Grind_ReconRebuild` when an EXT order exists**: it sets exit_target = order price. I6 uses that. Passes if order price = expected.

28. **`Grind_ReconRebuild` when no EXT coverage**: sets exit_target = formula. I6 not checked if not required? Actually I3 only checks if required and no coverage. I6 only checks if coverage. So if no coverage, I6 not checked. So the exit_target set is not used by I6. But if it becomes required later, exitq manage will place. Good.

29. **`Grind_ReconCheckInvariants` I6**: it checks only if `Grind_ReconLayerHasExitCoverage`. If no coverage, skips. So an ejected layer with no exit coverage (cancelled) won't fail I6. But I3 will fail if it's required and no coverage. So if it's deepest, it must have coverage. Good.

30. **`Grind_ExitQRequired`**: rank == depth-1. So deepest required. If ejected deepest has no exit, I3 fails on recon. So the trim cancel/re-release test must ensure re-release happens before recon. Or recon would halt. The ADR test says "trim cancels and re-releases the ejected exit: it comes back at the EJECTED price". This is an in-memory test. On restart, if the exit is cancelled and not re-released, I3 fails. That's expected.

31. **`Grind_CarryExitPassBegin` if it skips ejected layers, and the ejected layer's exit is cancelled, the carry pass won't set accrued. So when re-released, it uses old accrued. That's consistent with ejection. Good.

32. **`Grind_CarryPruneShiftGvs` if it prunes eject offset for a position that is closed, but the position ticket might be used in a pending command?** Command uses magic, not ticket. So no conflict.

33. **`Grind_CarryPruneShiftGvs` if it prunes eject offset for a position that is closed, but the offset is needed for cleanup?** No, position closed, offset not needed.

34. **`Grind_TestClearCarryState`**: if it clears all `GRIND_EJECT_`, it will clear command and offset. Good.

35. **`scripts/grind_gv_clean.mq5`**: same.

36. **`Grind_CarryShiftDelete` and `Grind_CarryAccruedDelete` on close**: should be paired with `Grind_EjectOffsetDelete`. Missing.

37. **`Grind_ExitQFormulaTarget` and `Grind_ReconExitMatchesEntry` need `Grind_EjectOffsetGet`**. Not implemented. The ADR says new variable, but code doesn't have functions. Audit should note missing implementation.

38. **`Grind_EjectOffsetGet` should use `GRIND_EJECT_OFFSET_` prefix**. The command uses `GRIND_EJECT_`. Ensure no collision.

39. **`Grind_CarryPruneShiftGvs`** should add `GRIND_EJECT_OFFSET_` to the if-else chain. Not in ADR.

40. **`Grind_CarryExitPassBegin`** should skip ejected layers. Not in ADR.

41. **`Grind_CarryExitShiftLayer`** if not skipped, must add eject to `theoretical` and `intended`, and set release GV if clamped. Not in ADR.

42. **`Grind_InvariantDetailI6`** must add accrued and eject. Not in ADR.

43. **`Grind_ReconFailureOffendingForReason`** doesn't handle `I6_*_EXIT_FILL_ADVERSE`. Pre-existing.

44. **`Grind_ReconExitMatchesEntry`** uses `GRIND_PRICE_EPS` and tolerance. With eject, tolerance is still 2 points. If the ejected price is far, the expected and actual should match exactly if no clamp. If clamped, shift makes them match. So tolerance is fine.

45. **`Grind_ExitQFormulaTarget`** uses `Grind_ExitPrice(entry, exit_pips, point, is_long ? 1 : -1) + accrued`. Need `+ eject`. Note: `Grind_ExitPrice` might return normalized? Not sure. Adding eject offset (which is a price difference) is fine.

46. **`Grind_ReconExitMatchesEntry`** uses `Grind_ExitPrice(...) + accrued + shift`. Need `+ eject`. Order doesn't matter.

47. **`Grind_InvariantDetailI6`** uses `Grind_ExitPrice(...) + carry_shift`. Need `+ accrued + eject`. Also update JSON to include `accrued` and `eject_offset` for debugging.

48. **`Grind_CarryExitPassBegin`** uses `Grind_ExitPrice` directly. If we skip ejected layers, no change. If we don't skip, need to add eject to `formula_exit`? No, because `formula_exit` is the base formula without accrued. The eject offset is separate. So in `Grind_CarryExitShiftLayer`, after computing `theoretical_carry`, add `eject_offset`. But careful with `accrued_price` calculation. So:
```
const double theoretical_carry = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);
const double accrued_price = theoretical_carry - formula_exit;
Grind_CarryAccruedSet(position_ticket, accrued_price);
const double eject_offset = Grind_EjectOffsetGet(position_ticket);
const double theoretical = theoretical_carry + eject_offset;
...
const double intended = formula_exit + accrued_price + eject_offset;
const double applied_shift = Grind_Normalize(new_exit) - intended;
...
if(clamped_out) {
   Grind_CarryShiftSet(position_ticket, applied_shift);
   GlobalVariableSet(Grind_CarryReleaseGvName(position_ticket), 1.0); // add this if clamped
} else {
   Grind_CarryShiftSet(position_ticket, applied_shift);
}
```
But also sign guard: if sign guard blocks, should not set accrued? Or should not process ejected layers. So skip is better.

49. **`Grind_CarryExitPassBegin`** if it skips, the `Grind_CarryExitPassAppendWork` signature doesn't need change. Just add check in loop:
```
if(Grind_EjectOffsetGet(layer.position_ticket) != 0.0)
   continue;
```
But `Grind_EjectOffsetGet` is in grind_carry.mqh, which is included. So available.

50. **`Grind_CarryPruneShiftGvs`** add:
```
else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) {
   const string suffix = StringSubstr(name, StringLen("GRIND_EJECT_OFFSET_"));
   ticket = (ulong)StringToInteger(suffix);
}
```
Then existing position check deletes if not exists. Do not add broad `GRIND_EJECT_`.

51. **`Grind_HandleSideDealFill`** add `Grind_EjectOffsetDelete(side.layers[i].position_ticket);` alongside `Grind_CarryAccruedDelete`.

52. **`Grind_CarryAccruedDelete`** doesn't delete eject. Need separate function.

53. **`Grind_TestClearCarryState`** and `grind_gv_clean.mq5`: add prefix `GRIND_EJECT_`.

54. **Tests**: Add test for carry pass not overwriting ejection. Add test for I6 detail telemetry. Add test for orphan prune. Add test for deletion on close. Add test for cleanup script.

55. **Potential issue with `Grind_CarryExitPassBegin` skipping ejected layers**: The `g_grind_carry_exit_eligible` count will be lower. The pass summary might show fewer eligible. Not a bug.

56. **Potential issue with `Grind_CarryExitPassBegin` skipping ejected layers**: If an ejected layer's exit is cancelled and re-released, the carry pass won't update accrued. So the re-released exit uses old accrued + eject. That's the desired "ejected price" persistence. Good.

57. **Potential issue with `Grind_CarryExitPassBegin` skipping ejected layers**: If the ejection offset is later deleted (on close), the layer is gone. So no issue.

58. **Potential issue with `Grind_ExitQFormulaTarget` fetching eject offset for a position that has no offset**. `Grind_EjectOffsetGet` returns 0. Good.

59. **Potential issue with `Grind_ReconExitMatchesEntry` fetching eject offset for a position that has no offset**. Returns 0. Good.

60. **Potential issue with `Grind_InvariantDetailI6` fetching eject offset**. Returns 0. Good.

61. **Potential issue with `Grind_CarryPruneShiftGvs` and command variable**: As noted, don't use broad prefix.

62. **Potential issue with `Grind_CarryShiftDelete` on close**: It deletes shift and release. Should it also delete eject? No, separate. So add separate delete.

63. **Potential issue with `Grind_CarryShiftDelete` in `Grind_ExitQHoldCancelLayer`**: It deletes shift. Eject remains. Correct.

64. **Potential issue with `Grind_CarryShiftDelete` in `Grind_ExitQManageSide` when not clamped**: It deletes shift. Eject remains. Correct.

65. **Potential issue with `Grind_CarryShiftDelete` in `Grind_CarryShiftGetValidated`**: It deletes shift. Eject remains. Correct.

66. **Potential issue with `Grind_CarryShiftDelete` on close**: It deletes shift. Eject should also be deleted. Add.

67. **Potential issue with `Grind_CarryAccruedDelete` on close**: It deletes accrued. Eject should also be deleted. Add.

68. **Potential issue with `Grind_ReconResetSide`**: It clears layers. Does not clear GVs. If recon fails and halts, GVs remain. Cleanup script handles. But if recon succeeds, GVs are used. Good.

69. **Potential issue with `Grind_ReconstructState`**: It rebuilds layers. If an ejection offset exists, I6 passes if `Grind_ReconExitMatchesEntry` includes eject. Good.

70. **Potential issue with `Grind_CheckBookInvariants`**: Same.

71. **Potential issue with `Grind_ExitQManageSide` after recon**: It may place exits for layers without coverage. It uses formula+eject. Good.

72. **Potential issue with `Grind_ExitQManageSide` when it places an exit for a layer that has an eject offset, and the layer is not required?** It only places if required. If not required, it doesn't. If later required, places. Good.

73. **Potential issue with `Grind_ExitQManageSide` when it cancels a non-allowed layer that has an eject offset**: It deletes shift. Eject remains. If later allowed, re-places with eject. Good.

74. **Potential issue with `Grind_ExitQHoldCancelLayer` when it cancels a non-allowed layer that has an eject offset, and then the layer closes?** If it closes without exit, manual close. Eject offset remains until cleanup. Not a correctness break for I6 because layer gone. But leak.

75. **Potential issue with `Grind_HandleSideDealFill` on DEAL_ENTRY_OUT_BY**: It deletes shift and accrued. Add eject. This is the normal close path. Good.

76. **Potential issue with `Grind_HandleSideDealFill` on DEAL_ENTRY_OUT (not OUT_BY)**: The code only handles DEAL_ENTRY_OUT_BY and DEAL_ENTRY_IN. It does not handle DEAL_ENTRY_OUT. So if a position is closed by stop out or manual close, the layer might not be removed. That's a pre-existing issue. Not eject-specific. But if manual close happens, eject offset might leak. Cleanup/prune handles.

77. **Potential issue with `Grind_CarryPruneShiftGvs`**: It prunes shift/release for non-existent positions. If an ejected layer is manually closed, the position is gone, so if we add eject prune, it will delete the eject offset. Good.

78. **Potential issue with `Grind_CarryPruneShiftGvs` timing**: It runs at start of carry pass. So orphan eject offsets are cleaned daily. Good.

79. **Potential issue with `Grind_TestClearCarryState`**: Should clear all `GRIND_EJECT_` variables. If tests use GVs, need reset between tests. ADR says add prefix. Good.

80. **Potential issue with `Grind_CarryTestReset`**: If tests seed eject offsets, they need a reset. Not in ADR. But `Grind_TestClearCarryState` is the suite reset. So okay.

81. **Potential issue with `Grind_ExitQFormulaTarget` being used in `Grind_RebuildBookFromTicketsInner` for layers without coverage**: If the layer has an eject offset but is not required, it sets exit_target = formula+eject. This might be far from market. But it's not used for placement until it becomes required. If it becomes required, exitq manage will compute formula+eject and clamp. So okay.

82. **Potential issue with `Grind_ReconRebuild` when a layer has no coverage and is required**: It sets exit_target = formula+eject. Then I3 fails because no coverage. So recon halts. That's correct: a required layer must have an exit. So if trim cancels a required exit, recon will halt unless it re-releases before restart. The ADR says trim cancels and re-releases. So in live, exitq manage re-releases on next tick. If restart happens between cancel and re-release, I3 fails. That's pre-existing? The ADR test "trim cancels and re-releases the ejected exit: it comes back at the EJECTED price" is in-memory. The restart test is separate. So okay.

83. **Potential issue with `Grind_ExitQManageSide` when it re-releases**: It uses formula+eject. Good.

84. **Potential issue with `Grind_CarryExitPassBegin` if it skips ejected layers, then the `Grind_CarryExitPassAppendWork` is not called. But what if the ejected layer's exit is missing? The carry pass would normally set accrued even if exit missing. If we skip, accrued stays stale. Then re-release uses stale accrued+eject. That's consistent with the ejected price. Good.

85. **Potential issue with `Grind_CarryExitPassBegin` if it skips, the `g_grind_carry_exit_eligible` count is lower, but the summary might be interpreted as fewer eligible layers. Not a bug.

86. **Potential issue with `Grind_CarryExitPassBegin` if it skips, the `Grind_CarryExitPassOnWindowClose` incomplete check might trigger if work_count is 0? If all layers are ejected, work_count = 0. Then `g_grind_carry_exit_work_cursor >= g_grind_carry_exit_work_count` is true, and `g_grind_carry_exit_retry_count == 0`, so it emits summary and resets. So fine.

87. **Potential issue with `Grind_CarryExitPassBegin` if it skips, the `Grind_CarryPruneShiftGvs` still runs. Good.

88. **Potential issue with `Grind_CarryExitPassBegin` if it skips, the `Grind_CarryExitPassAppendWork` is not called for ejected layers. So their exit_order_ticket is not in work arrays. Good.

89. **Potential issue with `Grind_CarryExitPassStep` if work_count is 0. It processes 0, then emits summary. Good.

90. **Potential issue with `Grind_CarryExitPassReset`**: no.

So final answer should be structured: list findings, each with file/function, what breaks, fix. The audit task specifically asks:

- every place an exit target is computed or checked that would NOT see the new offset
- any path that cancels and re-places the deepest exit
- whether reconstruction after an ejection passes I6
- whether anything besides Grind_ExitQFormulaTarget and Grind_ReconExitMatchesEntry needs the offset.

We should answer these directly.

Let's compile the list of places exit target computed/checked:

1. `Grind_ExitQFormulaTarget` (grind_exitq.mqh) — needs offset. ADR says.
2. `Grind_ReconExitMatchesEntry` (grind_recon.mqh) — needs offset. ADR says.
3. `Grind_InvariantDetailI6` (grind_recon.mqh) — computes expected for telemetry; missing accrued and eject. Needs offset (and accrued).
4. `Grind_CarryExitPassBegin` (grind_carry.mqh) — computes `formula = Grind_ExitPrice(...)` for each layer; does not use `Grind_ExitQFormulaTarget`; ignores eject.
5. `Grind_CarryExitShiftLayer` (grind_carry.mqh) — computes `theoretical = Grind_CarryShiftedExitPrice(formula_exit, ...)` and `intended = formula_exit + accrued_price`; ignores eject. This is the actual modification that overwrites the exit.
6. `Grind_AppendLayer` (grind_engine.mqh) — sets `exit_target = Grind_ExitPrice(...)`. Does not include accrued/eject. But for new layer, no eject exists. Not a break, but note if a layer is re-added with same ticket? No. Could mention as a place that computes exit target but doesn't need offset for new layers.
7. `Grind_ReconRebuild` when no exit coverage — calls `Grind_ExitQFormulaTarget`; covered if function patched.
8. `Grind_ExitQManageSide` when placing new exit — calls `Grind_ExitQFormulaTarget`; covered.
9. `Grind_TryPlaceExitForLayer` — uses `layer.exit_target`; if layer.exit_target was set by command or recon with eject, okay. But if command doesn't update `layer.exit_target`, it could be stale. The ADR says command modifies the resting exit order; it should also update `layer.exit_target`. Not in provided code. Could be a gap.
10. `Grind_CarryExitPassAppendWork` — stores formula_exit; no offset.
11. `Grind_CarryExitShiftLayer` sign guard — uses `theoretical` without eject. If ejected layer is processed, sign guard may block or allow incorrectly.
12. `Grind_CarryExitShiftLayer` sets `Grind_CarryAccruedSet` before sign guard/modify. If ejected layer processed, accrued changes, breaking I6 even if exit not modified.
13. `Grind_CarryExitPassBegin` calls `Grind_CarryPruneShiftGvs` — does not prune eject offset.
14. `Grind_CarryPruneShiftGvs` — only prunes shift/release. Needs specific `GRIND_EJECT_OFFSET_` prune.
15. `Grind_HandleSideDealFill` on close — deletes shift and accrued, not eject.
16. `Grind_CarryShiftDelete` — deletes shift and release; not eject. Correct, separate.
17. `Grind_CarryAccruedDelete` — deletes accrued; not eject. Need separate.
18. `Grind_TestClearCarryState` — not shown; ADR says add prefix.
19. `scripts/grind_gv_clean.mq5` — not shown; ADR says add prefix.
20. `Grind_CarryExitPassBegin` if it skips ejected layers — needed to prevent overwrite.

Paths that cancel and re-place deepest exit:
- `Grind_ExitQHoldCancelLayer` cancels exit under slot pressure or rank change. Deletes shift but not eject. Re-place via `Grind_ExitQManageSide` uses formula+eject (if patched). Good, but if carry pass runs in between, it may overwrite when exit missing? Carry pass skips if we add skip. If not, carry pass sees exit_order_ticket == 0 and only sets accrued, not modify. Then re-place uses new accrued + eject -> I6 mismatch because eject was based on old accrued. So even if exit missing, carry pass corrupts accrued. This is another reason to skip ejected layers entirely.
- `Grind_ExitQManageSide` itself cancels non-allowed layers and re-places required ones. It recomputes formula with eject.
- `Grind_CarryExitPassBegin` is not a cancel/re-place but a modify of existing exit. It overwrites.

Reconstruction after ejection passes I6?
- Only if `Grind_ReconExitMatchesEntry` is patched to include eject. If not, fails.
- If carry pass has run and overwritten exit or changed accrued, fails even if patched. So need skip carry pass.
- If exit was clamped and shift is set, I6 passes if release GV bypasses bound. If shift is bound-checked and deleted, fails. But `Grind_ExitQManageSide` sets release GV on clamp. Carry pass does not set release GV. So if carry pass processes an ejected layer and clamps, shift may be deleted, failing I6. Skip avoids.

Anything besides the two functions needs offset?
- Yes: `Grind_InvariantDetailI6`, `Grind_CarryExitPassBegin`, `Grind_CarryExitShiftLayer`, `Grind_CarryPruneShiftGvs`, `Grind_HandleSideDealFill` (delete), `Grind_TestClearCarryState`, `grind_gv_clean.mq5`. Also test hooks for eject. Also command polling code (not shown). Also `Grind_AppendLayer`? Not strictly, but if a layer is re-added? No. Also `Grind_TryPlaceExitForLayer` uses `layer.exit_target`; command should update it. Also `Grind_ExitQManageSide` when it cancels non-allowed layers: it deletes shift, but should not delete eject. It doesn't, so correct. But it should be aware not to delete eject. It isn't deleting it, so fine.
- Also `Grind_CarryShiftGetValidated` bound check: if shift is deleted, I6 fails. But release GV protects clamped re-placements. For carry pass, need skip or set release.
- Also `Grind_CarryExitPassBegin` uses `Grind_CarryPruneShiftGvs`; if we add broad prefix there, it could delete command variable. So use specific prefix.

We should write the audit in a clear, exhaustive manner. The user wants quantitative auditor hunting for lookahead, silent failures, schema mismatches, statistical flaws. But this is an ADR audit. We should focus on the specific asks. We can structure as:

- Summary: ADR's durability design is incomplete; the carry pass will silently undo ejection.
- Findings:
  1. Carry pass overwrites eject (critical).
  2. I6 detail telemetry missing accrued and eject.
  3. Eject offset not deleted on close / not pruned.
  4. Cleanup/reset missing.
  5. Command/offset prefix collision in prune.
  6. Shift bound / release GV issue.
  7. Sign guard / accrued update in carry pass.
  8. Layer.exit_target update on command.
- Answers to specific questions.

Let's ensure we mention exact code locations and variables.

We should also note that `Grind_ExitQFormulaTarget` is not used by carry pass, so adding offset there is insufficient. `Grind_CarryExitPassBegin` directly calls `Grind_ExitPrice`. `Grind_CarryExitShiftLayer` directly computes `theoretical`. So the ADR table's "where today" is incomplete: it lists only two places, but there are at least three more.

Also note `Grind_ReconExitMatchesEntry` is called from `Grind_ReconCheckInvariants` with `long_shift`/`short_shift`. It fetches accrued internally. Adding eject inside is correct. But `Grind_InvariantDetailI6` is called with only `carry_shift` and computes its own expected without accrued. So even the existing I6 telemetry is inconsistent with the check when accrued != 0. This is a pre-existing bug that will be exacerbated by eject. Must fix.

Also note `Grind_ReconFailureOffendingForReason` doesn't handle `I6_LONG_EXIT_FILL_ADVERSE` / `I6_SHORT_EXIT_FILL_ADVERSE`. If an ejected exit fills adversely, the failure telemetry won't capture the offending comment. This is a minor pre-existing bug.

Also note `Grind_CarryExitShiftLayer` sets `Grind_CarryAccruedSet` before checking sign guard and before successful modify. If an ejected layer is processed, even a sign-guard skip will change accrued, causing I6 mismatch. So skip is necessary.

Also note `Grind_CarryExitPassBegin` appends work for all layers regardless of eject. So the skip must be added there.

Also note `Grind_CarryPruneShiftGvs` currently prunes only `GRIND_CARRY_SHIFT_` and `GRIND_CARRY_RELEASE_PREFIX`. Adding broad `GRIND_EJECT_` here would delete the command variable `GRIND_EJECT_<magic>` incorrectly (it would parse magic as ticket and check position existence). So add specific `GRIND_EJECT_OFFSET_`.

Also note `Grind_HandleSideDealFill` on DEAL_ENTRY_OUT_BY deletes shift and accrued. Add eject delete. Also `Grind_CarryShiftDelete` and `Grind_CarryAccruedDelete` are separate; don't merge eject into shift delete because shift delete is also used on trim cancel where eject must persist. So need a separate `Grind_EjectOffsetDelete` and call it only on layer close.

Also note `Grind_ExitQHoldCancelLayer` deletes shift on cancel. Correct: eject persists. `Grind_ExitQManageSide` deletes shift when re-placing unclamped. Correct: eject persists.

Also note `Grind_ExitQManageSide` when placing new exit sets `side.layers[i].exit_target = price`. If an ejection is commanded, the command should set `side.layers[i].exit_target` to the ejected price and set the offset. The ADR doesn't specify, but if it doesn't, any code using `layer.exit_target` (like `Grind_TryPlaceExitForLayer`) could place at the old formula. Not in provided code, but worth flagging.

Also note `Grind_AppendLayer` sets `exit_target = Grind_ExitPrice(...)`. For a new layer, no accrued/eject. But if a layer is appended after an ejection? The ejected layer is already present. New layers are different positions. So no issue.

Also note `Grind_ReconRebuild` when no exit coverage sets `exit_target = Grind_ExitQFormulaTarget`. If `Grind_ExitQFormulaTarget` is patched, it includes eject. Good.

Also note `Grind_ReconRebuild` when exit coverage exists uses actual exit_target. I6 check uses `Grind_ReconExitMatchesEntry`. If patched, passes. Good.

Also note `Grind_ExitQFormulaTarget` is used in `Grind_ExitQManageSide` for new exit placement. If patched, includes eject. Good.

Also note `Grind_ExitQFormulaTarget` is used in `Grind_RebuildBookFromTicketsInner` for no coverage. If patched, includes eject. Good.

So the only missing target computation in the ADR is the carry pass.

Let's also consider `Grind_CarryExitPassBegin` uses `Grind_ExitPrice` not `Grind_ExitQFormulaTarget`. Why? Because it wants to compute accrued itself. So it cannot just use the patched function. It needs a separate eject addition. But skip is simpler.

What about `Grind_CarryExitShiftLayer` when `exit_order_ticket == 0`? It sets accrued. If we skip ejected layers in append, this won't run for them. Good.

What about `Grind_CarryExitPassBegin` if we skip, the `g_grind_carry_exit_eligible` count should be the number of non-ejected layers. The summary telemetry will show fewer eligible. That's acceptable.

What about `Grind_CarryExitPassBegin` if we skip, the `Grind_CarryPruneShiftGvs` still runs. Good.

What about `Grind_CarryExitPassBegin` if we skip, the `Grind_CarryExitPassAppendWork` is not called for ejected layers. So their `exit_order_ticket` is not in work arrays. Good.

What about `Grind_CarryExitPassStep` if work_count is 0. It processes 0, then emits summary. Good.

What about `Grind_CarryExitPassOnWindowClose`: no.

What about `Grind_CarryExitPassReset`: no.

What about `Grind_CarryExitPassAppendWork`: no.

What about `Grind_CarryExitShiftLayer`: if we don't skip, need to add eject. But skip is recommended.

Now, let's write the final answer. We should be concise but exhaustive. Use bullet points. Include code references.

We should also mention that the ADR's test "restart after accepted ejection: reconstruction passes I6" will pass only if no carry pass has run. The test must include a simulated carry pass to catch the overwrite. This is a testing gap.

Also mention that the cleanup script and `Grind_TestClearCarryState` must clear both `GRIND_EJECT_<magic>` and `GRIND_EJECT_OFFSET_<position>`. The broad prefix works for cleanup, but not for prune.

Also mention that `Grind_CarryPruneShiftGvs` should not use broad prefix.

Also mention that `Grind_InvariantDetailI6` is missing `accrued` even before eject. This is a pre-existing telemetry bug.

Also mention that `Grind_ReconFailureOffendingForReason` doesn't handle `I6_*_EXIT_FILL_ADVERSE`. Minor.

Also mention that `Grind_CarryExitShiftLayer` sets accrued before sign guard and before modify; if an ejected layer is processed, even a sign-guard skip corrupts I6. So skip.

Also mention that `Grind_ExitQManageSide` sets release GV on clamp, which bypasses shift bound. Carry pass does not set release GV, so if it clamps an ejected layer (if not skipped), the large shift may be bound-deleted, breaking I6. Another reason to skip.

Also mention that `Grind_ExitQManageSide` when re-placing an ejected exit uses `Grind_ExitQFormulaTarget` which includes eject. If the market has moved, it clamps and sets shift relative to formula+eject. This is correct and I6 passes because release GV bypasses bound.

Also mention that `Grind_ExitQHoldCancelLayer` deletes shift but not eject. Correct.

Also mention that `Grind_HandleSideDealFill` on close must delete eject. Missing.

Also mention that `Grind_CarryPruneShiftGvs` must prune orphan eject offsets. Missing.

Also mention that `Grind_AppendLayer` does not include accrued/eject. For new layers, fine. But if a layer is re-added with same position? No.

Also mention that `Grind_TryPlaceExitForLayer` uses `layer.exit_target`. The command must update `layer.exit_target`; otherwise this path could place at the old formula. Not in provided code, but flag.

Also mention that `Grind_ExitQManageSide` when placing new exit sets `side.layers[i].exit_target = price`. If the command already set `exit_target` to ejected price, this overwrites it with the placed price (which may be clamped). That's fine.

Also mention that `Grind_ReconRebuild` when no exit coverage sets `exit_target` via formula. If patched, includes eject. Good.

Now write final.

## Final Report

## Audit findings: ADR-155 Commanded Passive Ejection

The ADR’s durability design is incomplete. The new offset is read by `Grind_ExitQFormulaTarget` and `Grind_ReconExitMatchesEntry`, but **the nightly carry pass bypasses both and will silently overwrite the ejected exit**, then cause I6 to fail on the next restart. There are also missing cleanup paths, a telemetry mismatch, and a dangerous prefix collision if the cleanup/prune logic is implemented naively.

---

## 1. Critical: the carry pass overwrites the ejection

The ADR table lists only two places where the exit target is computed:

| where | today | after |
|---|---|---|
| `Grind_ExitQFormulaTarget` | `exit + accrued` | `exit + accrued + eject_offset` |
| `Grind_ReconExitMatchesEntry` | `exit + accrued + shift` | `exit + accrued + eject_offset + shift` |

**This misses the carry pass entirely.**

`Grind_CarryExitPassBegin` (`grind_carry.mqh`) does **not** call `Grind_ExitQFormulaTarget`. It computes:

```mql5
const double formula = Grind_ExitPrice(layer.entry_price, exit_pips, point, 1);
Grind_CarryExitPassAppendWork(layer.position_ticket, layer.exit_order_ticket,
                              layer.entry_price, formula, true, layer.layer_index);
```

Then `Grind_CarryExitShiftLayer` computes:

```mql5
const double theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction,
                                                     accrued_pips, pip_size);
const double accrued_price = theoretical - formula_exit;
Grind_CarryAccruedSet(position_ticket, accrued_price);
...
const double intended = formula_exit + accrued_price;
const double applied_shift = Grind_Normalize(new_exit) - intended;
Grind_CarryShiftSet(position_ticket, applied_shift);
```

Neither reads `GRIND_EJECT_OFFSET_<position>`.

**Consequence:** at the next rollover window (`23:50`), the carry pass will modify the deepest layer’s exit from the ejected price back to `formula + accrued`. It will also set a shift relative to `formula + accrued`, not `formula + accrued + eject_offset`. On the next restart, `Grind_ReconExitMatchesEntry` (once patched) will expect `formula + accrued + eject_offset + shift`, but the broker order will be at `formula + accrued`. I6 fails: `I6_*_EXIT`.

Even worse, `Grind_CarryExitShiftLayer` sets `Grind_CarryAccruedSet` **before** the sign guard and **before** the modify succeeds. So even if the sign guard blocks the modification, accrued changes, and I6 will mismatch because the actual exit price still reflects the old accrued.

**Fix:** skip layers with a non-zero `GRIND_EJECT_OFFSET_<position>` in `Grind_CarryExitPassBegin`. Do not merely add the offset to `theoretical`; the sign-guard and accrued-update ordering make that fragile. An ejected layer is an operator override and should not receive nightly carry repricing.

---

## 2. I6 failure detail telemetry is already wrong and will get worse

`Grind_InvariantDetailI6` (`grind_recon.mqh`) computes:

```mql5
const double expected = Grind_ExitPrice(layer.entry_price, exit_pips, point, dir) + carry_shift;
```

It **omits `accrued` entirely**. This is a pre-existing bug: `Grind_ReconExitMatchesEntry` uses `exit + accrued + shift`, but the failure detail logs `exit + shift`. With the new offset, it will also omit `eject_offset`.

**Consequence:** when I6 fails after an ejection, the emitted telemetry will show a bogus `expected` price, making diagnosis impossible.

**Fix:** `Grind_InvariantDetailI6` must fetch and include both:

```mql5
const double accrued = (layer.position_id > 0) ? Grind_CarryAccruedGet(layer.position_id) : 0.0;
const double eject   = (layer.position_id > 0) ? Grind_EjectOffsetGet(layer.position_id) : 0.0;
const double expected = Grind_ExitPrice(...) + accrued + eject + carry_shift;
```

Also add `accrued` and `eject_offset` to the JSON payload.

---

## 3. Eject offset is never deleted when the layer closes

`Grind_HandleSideDealFill` (`grind_engine.mqh`) on `DEAL_ENTRY_OUT_BY` does:

```mql5
Grind_CarryShiftDelete(side.layers[i].position_ticket);
Grind_CarryAccruedDelete(side.layers[i].position_ticket);
Grind_RemoveLayerAt(side, i);
```

The ADR says the offset is deleted “alongside the existing `Grind_CarryAccruedDelete`”, but there is no `Grind_EjectOffsetDelete` call. The offset leaks.

**Fix:** add `Grind_EjectOffsetDelete(side.layers[i].position_ticket);` next to `Grind_CarryAccruedDelete`. Do **not** fold it into `Grind_CarryShiftDelete`, because `Grind_CarryShiftDelete` is also called on trim cancel where the eject offset must persist.

---

## 4. Orphan eject offsets are not pruned

`Grind_CarryPruneShiftGvs` (`grind_carry.mqh`) prunes orphan `GRIND_CARRY_SHIFT_` and `GRIND_CARRY_RELEASE_` variables when the position no longer exists. It does not know about `GRIND_EJECT_OFFSET_`.

**Fix:** add a branch for the specific prefix `GRIND_EJECT_OFFSET_`:

```mql5
} else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) {
   const string suffix = StringSubstr(name, StringLen("GRIND_EJECT_OFFSET_"));
   ticket = (ulong)StringToInteger(suffix);
}
```

**Do not** add the broad prefix `GRIND_EJECT_` here. `GRIND_EJECT_<magic>` is the command variable, and its suffix is a magic number, not a position ticket. Treating it as a position ticket would delete a pending operator command when no position with that ticket exists.

---

## 5. Cleanup script and test reset

The ADR correctly says to add the prefix `GRIND_EJECT_` to:

- `scripts/grind_gv_clean.mq5`
- `Grind_TestClearCarryState`

That broad prefix is correct for those two because they are wholesale clean-up paths and must remove both `GRIND_EJECT_<magic>` and `GRIND_EJECT_OFFSET_<position>`. Ensure they are actually updated. If they only remove `GRIND_EJECT_OFFSET_`, the command variable leaks. If they only remove `GRIND_EJECT_<magic>`, the offset leaks.

---

## 6. Shift bound / release-GV interaction

`Grind_ExitQManageSide` sets both the shift and the release GV when it clamps a re-placed exit:

```mql5
Grind_CarryShiftSet(side.layers[i].position_ticket, price - formula);
GlobalVariableSet(Grind_CarryReleaseGvName(side.layers[i].position_ticket), 1.0);
```

`Grind_CarryShiftGetValidated` bypasses the bound check when the release GV exists. This is necessary because a clamped re-release of an ejected exit can produce a large shift (`Q - (formula + accrued + eject)`). If the carry pass ever processes an ejected layer without setting the release GV, a large shift will be bound-checked and deleted, and I6 will fail.

This is another reason the carry pass must skip ejected layers.

---

## 7. Command must update `layer.exit_target`

The ADR says the command modifies the resting exit order. It does not explicitly say it updates `GrindLayer.exit_target`. If any code uses `layer.exit_target` directly—e.g. `Grind_TryPlaceExitForLayer` (`grind_engine.mqh`) places at `layer.exit_target`—then a later re-place could use the stale formula target instead of the ejected price.

**Fix:** on command acceptance, set `layer.exit_target` to the ejected price and set `GRIND_EJECT_OFFSET_<position>`.

---

## 8. Minor: adverse-fill telemetry misses the offending comment

`Grind_ReconFailureOffendingForReason` (`grind_recon.mqh`) handles `"I6_LONG_EXIT"` and `"I6_SHORT_EXIT"` but not `"I6_LONG_EXIT_FILL_ADVERSE"` / `"I6_SHORT_EXIT_FILL_ADVERSE"`. If an ejected exit fills adversely and I6 fails with the adverse-fill reason, the offending comment will not be captured. Pre-existing, but relevant because ejections are negative-P&L scalps and may fill adversely.

---

## Direct answers to the audit questions

### Every place an exit target is computed or checked that would NOT see the new offset

1. **`Grind_CarryExitPassBegin`** (`grind_carry.mqh`) — computes `Grind_ExitPrice(...)` directly, not `Grind_ExitQFormulaTarget`.
2. **`Grind_CarryExitShiftLayer`** (`grind_carry.mqh`) — computes `theoretical` and `intended` without the offset. This is the path that actually modifies the exit.
3. **`Grind_InvariantDetailI6`** (`grind_recon.mqh`) — computes `expected` without accrued and without offset.
4. **`Grind_AppendLayer`** (`grind_engine.mqh`) — sets `exit_target` with `Grind_ExitPrice(...)`. For a brand-new layer this is fine (no offset exists yet), but if a layer is ever re-added with the same position ticket it would miss the offset. Not a practical path today.
5. **`Grind_TryPlaceExitForLayer`** uses `layer.exit_target`; if the command does not update `layer.exit_target`, this path would miss the offset.
6. **`Grind_CarryPruneShiftGvs`** does not see the offset, so orphan offsets are not pruned.

### Any path that cancels and re-places the deepest exit

- **`Grind_ExitQHoldCancelLayer`** cancels the exit under slot pressure or rank change. It deletes the carry shift but **correctly leaves the eject offset**. Re-placement happens later via `Grind_ExitQManageSide`, which uses `Grind_ExitQFormulaTarget`. If that function is patched, the re-placed exit will be at the ejected price (clamped). Good.
- **`Grind_ExitQManageSide`** itself cancels non-allowed layers and places required layers. It uses `Grind_ExitQFormulaTarget`. Good if patched.
- **`Grind_CarryExitPassBegin` / `Grind_CarryExitShiftLayer`** is not a cancel/re-place, but it **modifies the existing exit** and overwrites the ejection. This is the path that breaks the ADR.

### Does reconstruction after an ejection pass I6?

Only if:

1. `Grind_ReconExitMatchesEntry` is patched to add `Grind_EjectOffsetGet(position_id)`.
2. No carry pass has run since the ejection, or the carry pass skips ejected layers.
3. The exit has not been re-placed with a clamp whose shift was bound-deleted. `Grind_ExitQManageSide` sets the release GV on clamp, so this is protected for normal re-placement. The carry pass does **not** set the release GV, so if it processes an ejected layer and clamps, I6 can fail even if the offset is added.

The ADR’s test “restart after an accepted ejection: reconstruction passes I6” will pass in isolation, but it will not catch the carry-pass overwrite unless the test also simulates a rollover window.

### Does anything besides `Grind_ExitQFormulaTarget` and `Grind_ReconExitMatchesEntry` need the offset?

Yes:

- `Grind_InvariantDetailI6` — for telemetry.
- `Grind_CarryExitPassBegin` — must skip ejected layers.
- `Grind_CarryExitShiftLayer` — must skip ejected layers (or incorporate offset consistently, which is fragile).
- `Grind_CarryPruneShiftGvs` — must prune orphan `GRIND_EJECT_OFFSET_` variables using the specific prefix.
- `Grind_HandleSideDealFill` — must delete the offset on layer close.
- `Grind_TestClearCarryState` — must clear `GRIND_EJECT_*`.
- `scripts/grind_gv_clean.mq5` — must clear `GRIND_EJECT_*`.
- The command handler (not shown) must set `layer.exit_target` and write `GRIND_EJECT_OFFSET_<position>`.
- Test hooks for the command and offset (not shown) must exist and be reset.

---

## Recommended minimum changes before this ships

1. Patch `Grind_ExitQFormulaTarget` to add `Grind_EjectOffsetGet(position_ticket)`.
2. Patch `Grind_ReconExitMatchesEntry` to add `Grind_EjectOffsetGet(position_id)`.
3. Patch `Grind_InvariantDetailI6` to include both `accrued` and `eject_offset`.
4. In `Grind_CarryExitPassBegin`, skip any layer where `Grind_EjectOffsetGet(layer.position_ticket) != 0.0`.
5. Add `Grind_EjectOffsetDelete` and call it in `Grind_HandleSideDealFill` on layer close.
6. Add `GRIND_EJECT_OFFSET_` pruning to `Grind_CarryPruneShiftGvs` (specific prefix only).
7. Add broad `GRIND_EJECT_` cleanup to `grind_gv_clean.mq5` and `Grind_TestClearCarryState`.
8. Add a test that simulates a carry-pass rollover after an ejection and asserts the exit remains at the ejected price and I6 still passes.
9. Add a test that verifies an ejected exit is not bound-deleted after a large market move and re-release.

<!-- finish_reason=stop -->
