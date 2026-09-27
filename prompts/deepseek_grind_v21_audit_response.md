# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit. We need produce sections GIVENS CHECK, T-1..T-7, PREMISE VERDICT, TEST GAPS. Need cite file, function, quote line. No line numbers. We need find issues. Let's deeply analyze code. We have all files. Need be exhaustive but final moderate. Let's reason.

We need verify givens G1-G5 with quotes. Then threats.

Key branch v2.1: labels gating tolerance. Need detect bugs.

Let's inspect relevant code.

G1: With no label for side, init I6 exactly strict as before. In Grind_ReconstructState:
```
g_grind_rebuild_long = Grind_GeoExitChanged(...);
g_grind_rebuild_short = Grind_GeoExitChanged(...);
```
Grind_GeoExitChanged returns false if no label. Then Grind_RebuildBookFromTickets(..., tolerate_exit_price_long=g_grind_rebuild_long, ...). In Grind_ReconCheckInvariants:
```
if(!Grind_ReconExitMatchesEntry(...)) {
   if(tolerate_exit_price_long && !long_exit_filled)
      continue;
   ... fail
}
```
So if flag false, strict. Filled exits not tolerated because condition includes !long_exit_filled. Also note if tolerate_exit_short same. So G1 likely VERIFIED.

G2: Grind_CheckBookInvariants calls Grind_RebuildBookFromTickets with no tolerance flags? Need examine signature. It calls:
```
const bool ok = Grind_RebuildBookFromTickets(tickets, count, ..., reason,
                                                false,
                                                g_grind_recon_exit_pips_short);
```
The function signature after reason:
```
const bool tolerate_exit_shortfall = false,
const double exit_pips_short = 0.0,
const bool tolerate_exit_price_long = false,
const bool tolerate_exit_price_short = false
```
So it passes false for shortfall and exit_pips_short; exit price flags default false. Thus passes no tolerance. VERIFIED.

G3: FILLED exit never tolerated. In ReconCheckInvariants:
```
if(tolerate_exit_price_long && !long_exit_filled)
   continue;
```
So filled false? If long_exit_filled true, no continue, fails. Also Grind_ReconExitMatchesEntry has if(exit_is_filled) adverse condition. So filled strict. VERIFIED. Need quote.

G4: Grind_RebuildExitsAtStartSide prices non-ejected exit with same formula I6 checks (ExitQFormulaTarget + recorded shift). In side:
```
const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);
double price = formula;
const bool clamped = Grind_ExitQClampPassive(...);
...
if(clamped || MathAbs(price - formula) > _Point * 0.5)
   Grind_CarryRecordShift(pos, price - formula, true);
else
   Grind_CarryShiftDelete(pos);
```
Then modifies order to price. I6 checks formula? Grind_ExitQFormulaTarget includes effective entry + accrued + eject_offset. I6 in Grind_ReconExitMatchesEntry: expected = ExitPrice(eff, exit_pips, point, dir) + accrued + eject_offset + shift. Formula target = ExitPrice(eff, ...) + accrued + eject_offset. Then if clamped/shifted, shift recorded = price - formula. So price = formula + shift. I6 expected = formula + shift. Match. If no clamp, shift deleted, price formula. Match. So G4 VERIFIED? But note I6 uses Grind_CarryShiftGetForRecon which validates and may delete shift if out of bound. Rebuild records shift with `clamped` boolean true only if clamped; if not clamped but price differs > 0.5 point, it records shift with clamped=true? Wait code:
```
if(clamped || MathAbs(price - formula) > _Point * 0.5)
   Grind_CarryRecordShift(pos, price - formula, true);
else
   Grind_CarryShiftDelete(pos);
```
It passes `true` for clamped arg always when recording, even if not clamped? That sets release marker. Is that intended? In Grind_ExitQManageSide similar? It records shift with true always:
```
if(clamped || MathAbs(price - formula) > _Point * 0.5) {
   Grind_CarryRecordShift(..., true);
} else ...
```
So same. G4: formula plus recorded shift = target. But need check if non-ejected exit with existing shift record? It recalculates formula via ExitQFormulaTarget which includes accrued and eject_offset. If not ejected, offset 0. It doesn't include old shift. It modifies to price and records new shift. So I6 sees new shift. Good.

G5: Labels written only when rebuild returned true. In OnInit:
```
if(!Grind_RebuildExitsAtStart(InpMagic)) {
   ... halt, cancel, Print...
} else {
   Grind_GeoExitWriteLabels(...)
   ...
}
```
So yes.

Now threats.

T-1 Tolerance leak. Need find any path where tolerance applies incorrectly. Let's inspect Grind_ReconCheckInvariants logic carefully.

Tolerance flags are per side: tolerate_exit_price_long/short. In Grind_ReconCheckInvariants they skip I6 price mismatch on RESTING exit for flagged side:
```
if(!Grind_ReconExitMatchesEntry(...)) {
   if(tolerate_exit_price_long && !long_exit_filled)
      continue;
   ... fail
}
```
`long_exit_filled = long_layers[i].has_exit_position`. So only resting (not filled) tolerated. Filled strict. Other side strict. Good.

But what about mismatch the tolerance lets through that rebuild does NOT fix? Need identify cases where recon with tolerance passes but rebuild won't fix and first tick halts / trades.

Potential issue: ReconCheckInvariants also has earlier check for I3 naked:
```
if(Grind_ExitQRequired(long_rank, long_count) && !Grind_ReconLayerHasExitCoverage(long_layers[i])) {
   if(tolerate_exit_shortfall)
      continue;
   return fail I3_LONG_NAKED
}
```
Tolerate_exit_shortfall is always true in ReconstructState. But that's separate flag not tolerance for price. The branch passes tolerate_exit_shortfall=true always. That's old behavior? ReconstructState before branch likely passed true. Threat T-1 maybe about tolerance leak via exit shortfall? But question says price tolerance. Let's focus.

Possible issue: In Grind_ReconCheckInvariants, the tolerance skip for long side:
```
if(!Grind_ReconExitMatchesEntry(...)) {
   if(tolerate_exit_price_long && !long_exit_filled)
      continue;
   ...
}
```
This continues to next i, skipping all remaining checks for this layer? Actually it's inside for loop for each layer. The `continue` goes to next i. So it skips any subsequent checks? There are no subsequent checks after I6 for same layer except maybe exit_count? Wait exit_count check is separate loop after. So okay.

But what about wrong type? If an exit order exists but is wrong type, recon doesn't check type at all. The rebuild also doesn't check type; it modifies price. I6 only checks price. So not new.

Exit on held rank: Grind_ExitQAllowed allows rank? Rebuild iterates all layers with resting exit and no exit_position, regardless of rank. It modifies even exits on held ranks? In Grind_ExitQManageSide, exits not required and not allowed are cancelled. But at init, if an exit on a held rank exists (shouldn't per queue but possible after restart), Grind_RebuildExitsAtStartSide will modify it to formula if flagged side. That could be a problem: it prices an exit that should be held/cancelled. But I6 in recon? ReconCheckInvariants: For each layer, if has exit coverage, it checks I6 regardless of rank? Let's see: The I6 check is after the I3 check, which only checks if exit coverage missing for required rank. It does not skip I6 for non-required ranks. So for any layer with exit coverage (order or position), it checks I6. So if an exit on a held rank exists, recon will check I6 and if mismatch and tolerance applies, it skips. Rebuild will modify it to formula, so I6 passes after rebuild. But then Grind_ExitQManageSide later (in OnTick) will cancel held-rank exits. So maybe okay? But rebuild might move an exit that should be held, causing a transient? Actually it modifies to formula, then next tick ExitQManageSide sees !Allowed and cancels it. That seems okay, though unnecessary. But threat asks "an exit on a held rank" as mismatch tolerance lets through that rebuild does NOT fix? Rebuild does fix price. But does it? It only modifies if `MathAbs(resting - price) > _Point * 0.5`. If mismatch within 2 points but > 0.5 point? Tolerance skips up to 2 points. Rebuild only modifies if >0.5 point. If mismatch is e.g. 1 point, tolerance lets through, rebuild sees difference 1 point >0.5, modifies. Okay. If mismatch is 0.6 point? modifies. If mismatch exactly 0.5 point? tolerance would not skip? Actually I6 strict is <=2 points, so mismatch 0.5 would pass strict. So tolerance only matters for >2 points. Rebuild modifies if >0.5, so fixes. So okay.

But what about exit whose order cannot be read (`resting <= 0.0` is skipped). Rebuild:
```
const double resting = Grind_OrderGetPriceOpen(exit_ticket);
if(resting <= 0.0)
   continue;
```
If order cannot be read (e.g., not selected), it skips. Then tolerance might have allowed I6 mismatch, and rebuild does NOT fix. Then next tick Grind_CheckBookInvariants is strict (no tolerance) and will halt. This is a real T-1 issue. Let's verify: In Grind_RebuildExitsAtStartSide, for each layer with exit_ticket != 0 and no exit_position, it reads resting. If resting <= 0.0, continue. So if order cannot be read, no modify. But recon with tolerance might have skipped a price mismatch for that exit because it saw it as a resting exit with some price from ticket collection? Wait Grind_ReconCollectBrokerTickets collects orders from OrdersTotal. If order cannot be read by OrderSelect? It uses OrderGetTicket and OrderSelect. If order exists, it should be readable. But there could be race: order ticket in state but order not visible? Or test seam? In production, if exit_order_ticket is in state from comments? Actually recon rebuilds from broker tickets, not from state. It collects all orders. So if an exit order exists, it's collected and price set. Then Grind_RebuildExitsAtStartSide iterates over `side.layers` which is the recon result? Wait OnInit order: `Grind_ReconstructState()` is called first. It rebuilds g_grind_long/short from broker tickets. Then `Grind_RetryMissingExits` calls Grind_ExitQManageSide, which may place missing exits. Then `Grind_RebuildExitsAtStart` iterates over g_grind_long/short layers. So the layers come from recon, with exit_order_ticket from broker. If order exists, resting should be readable via Grind_OrderGetPriceOpen. In production, OrderSelect should work. But what if OrderSelect fails due to order being on another symbol? Grind_OrderGetPriceOpen returns 0.0 if !OrderSelect. But it was selected in recon? Could fail later. That's a race. The threat explicitly mentions "an exit whose order cannot be read (`resting <= 0.0` is skipped)". So that's a hole. If tolerance applied and rebuild skips, next strict check halts. So T-1 BREAKS? But is there a path where tolerance applies and rebuild skips? Yes, if Grind_OrderGetPriceOpen returns 0.0 for a resting exit that recon saw. However, recon with tolerance would only skip if the exit_target from recon (ticket price) mismatched expected. If order cannot be read at rebuild, it's still in layers with exit_order_ticket. The rebuild skips, leaving order at old price. Then next tick Grind_CheckBookInvariants strict will see mismatch and halt. So the tolerance allowed init to succeed, but first tick halts. That's a silent failure? Actually it halts, but the instance may have been initialized and labels written. Then first tick halts. The threat asks "so the first tick halts, or worse, the instance trades on it". Here it halts on first tick. That's a BREAK? The premise says "a failure quarantines, then halts." So init succeeds but first tick halts. Is that acceptable? The threat is about tolerance leak causing first tick halt. The branch intended to avoid halt on reattach with changed exit by rebuilding. But if rebuild skips, it fails. So T-1 has a path. Need cite.

Another T-1: "a layer whose exit belongs to another layer". In recon, Grind_RebuildBookFromTicketsInner associates exit orders by comment's layer index. In Grind_RebuildExitsAtStartSide, it iterates layers and uses layer.exit_order_ticket. If the exit order belongs to another layer (e.g., comment mismatch), recon might have associated it to the layer based on comment. If the state has exit_order_ticket from recon, it's correct. But if an exit order's comment says layer 1 but is attached to layer 0? Recon uses comment to assign to layer index. So if comment says layer 1, it goes to layer 1. So no mismatch. However, if an exit order's comment is unparseable, recon fails. So not.

"an exit of the wrong type" not checked.

"an exit on a held rank" as above.

But the most concrete T-1 is `resting <= 0.0` skip. Also maybe: tolerance applies when label equals input? Grind_GeoExitChanged returns false if label present and equal. So no tolerance. Good. Label absent -> false. So no tolerance. Other side no. Filled exit no.

What about "after init"? Tolerance only passed in ReconstructState. Grind_CheckBookInvariants never passes flags. So after init no tolerance. Good.

But wait: In Grind_ReconstructState, it sets g_grind_rebuild_long/short from labels. But what if label present and differs, but the side has no resting exits? Rebuild does nothing, returns true, labels written. That's fine.

Potential T-1: The tolerance is applied to all resting exits on that side, even if the rebuild will not fix some because they are ejected? Wait ejected branch: if `Grind_EjectIsEjected(pos) && !Grind_VLHas(pos)`, it keeps price and re-derives offset. Does it modify order? No, keeps order. It sets offset so that I6 formula matches resting. But does it? Let's check: It computes raw = ExitPrice(eff, exit_pips) + accrued + shift. Then offset = resting - raw. Grind_EjectOffsetSet(pos, offset). Then I6 expected = ExitPrice(eff, exit_pips) + accrued + eject_offset + shift = raw + offset = resting. So matches. Good. But what if the layer had a shift? It uses `Grind_CarryShiftGetForRecon(pos)` which may validate and delete shift if out of bound. Then raw includes shift. Offset computed to include it. But then I6 uses Grind_CarryShiftGetForRecon again, which may delete shift if out of bound? Wait it calls Grind_CarryShiftGetForRecon(pos) in rebuild. That function may delete shift if invalid. Then offset computed using possibly deleted shift (0). Then later I6 calls Grind_CarryShiftGetForRecon again. If shift was deleted, it returns 0. So consistent. But if shift was valid, it remains. Then I6 uses shift. Offset was computed with shift. So expected = raw_with_shift + offset = resting. Good. However, note that `Grind_CarryShiftGetForRecon` can delete a shift if out of bound. In rebuild, it calls it and if it deletes, shift becomes 0. Then offset = resting - (ExitPrice + accrued + 0). Then I6 later uses shift=0. So consistent. But what if shift is deleted after offset set? No, same call? Actually rebuild calls Grind_CarryShiftGetForRecon once. Then sets offset. Later I6 calls Grind_CarryShiftGetForRecon again. If the shift was valid but the bound check depends on time? It uses open_time and nightly_max_pips. Could change? Time passes? In init, open_time fixed, nightly_max_pips from symbol. Bound check uses current server time? `Grind_CarryShiftWithinBound` uses `now = Grind_CarryServerTime()`. In rebuild, it's called during init. In I6, called later same init? Actually I6 is called in Grind_ReconstructState before rebuild? Wait Grind_ReconstructState calls Grind_RebuildBookFromTickets which calls Grind_ReconCheckInvariants, which calls Grind_CarryShiftGetForRecon. That happens BEFORE Grind_RebuildExitsAtStart. So the shift validation at recon time may delete shift. Then rebuild later uses Grind_CarryShiftGetForRecon again, which now returns 0. So consistent. But if shift is deleted during recon, then tolerance may have been applied? Actually if shift is deleted, I6 expected changes, maybe mismatch, tolerance skips. Then rebuild uses 0 shift, sets offset. So okay.

But T-2 asks "In the ejected branch the offset uses Grind_CarryShiftGetForRecon: can it delete or ignore a shift and leave I6 inconsistent?" Let's analyze. In rebuild ejected branch:
```
const double raw = Grind_ExitPrice(eff, exit_pips, _Point, dir)
                   + Grind_CarryAccruedGet(pos)
                   + Grind_CarryShiftGetForRecon(pos);
const double offset = resting - raw;
Grind_EjectOffsetSet(pos, offset);
```
It does NOT delete or modify the shift. It just uses the validated shift. If `Grind_CarryShiftGetForRecon` deletes the shift (because out of bound), then shift becomes 0. Then offset = resting - (ExitPrice + accrued). Then I6 later uses shift=0. So expected = ExitPrice + accrued + offset = resting. Good. If it doesn't delete, shift remains. I6 uses same shift. Good. So no inconsistency. However, there is a subtle issue: `Grind_CarryShiftGetForRecon` can delete a shift if not ejected? But here the layer is ejected (`Grind_EjectIsEjected(pos) && !Grind_VLHas(pos)`), so `Grind_CarryShiftGetValidated` first checks release marker, then checks `if(Grind_EjectIsEjected) return shift;` So it will NOT delete an ejected exit's shift. So no deletion. Good.

But what about ejected with a shift? The code keeps the shift. Then offset is re-derived from resting with shift included. That means the new offset absorbs the shift. Then I6 uses shift + offset. So resting = ExitPrice + accrued + shift + offset. Offset was computed as resting - (ExitPrice + accrued + shift). So matches. Good.

What about rolled VL and ejected? Condition `Grind_EjectIsEjected(pos) && !Grind_VLHas(pos)` means if it has VL, it goes to normal branch, which uses Grind_ExitQFormulaTarget. That formula uses effective entry (VL) + accrued + eject_offset. But note: if it has VL and is ejected, eject_offset may be non-zero from a previous eject? Wait ADR-162 roll deletes eject offset? In Grind_LatticeRollLayer, when it modifies, it calls `Grind_EjectOffsetDelete(pos)`. When no exit order, it also deletes. So rolled layers should not have eject offset. But what if both VL and eject offset exist? The normal branch uses ExitQFormulaTarget which includes eject_offset. Rebuild sets price = formula, records shift. That would preserve eject_offset. But is that correct? If a layer has both VL and offset, I6 would expect ExitPrice(VL) + accrued + offset + shift. Rebuild uses same. So okay. But does Grind_LatticeRollLayer delete offset? Yes. So probably not.

Another T-2 issue: In normal branch, it modifies only if `MathAbs(resting - price) > _Point * 0.5`. If difference is <= 0.5 point, it does NOT modify, but then it sets `side.layers[i].exit_target = price;` and then:
```
if(clamped || MathAbs(price - formula) > _Point * 0.5)
   Grind_CarryRecordShift(pos, price - formula, true);
else
   Grind_CarryShiftDelete(pos);
```
Wait if it did NOT modify because resting is within 0.5 point of price, it still sets exit_target to price. But the actual order remains at `resting`. Then if `price` differs from `resting` by <=0.5 point, it deletes shift. So I6 expects formula (price) but actual order is resting. Difference <=0.5 point. I6 tolerance is 2 points, so it passes. That's okay. But if the difference is exactly 0.5 point? I6 allows 2 points. So fine. However, if the old shift was non-zero, it deletes it. Then actual order resting might be formula + old_shift. New price = formula. Difference = old_shift. If old_shift <=0.5 point, delete shift. I6 passes. If old_shift >0.5 point, then `MathAbs(resting - price) > 0.5` so it modifies. So consistent.

But consider the case where `clamped` is true but `MathAbs(resting - price) <= 0.5`. Then it does not modify, but records shift = price - formula. Wait price is clamped, so price != formula. It records shift = price - formula. But actual order is resting, which is within 0.5 of price. So actual order ≈ price = formula + shift. I6 expects formula + shift = price. Difference between resting and expected is <=0.5. Pass. Good.

Now T-2: "For each branch (plain, clamped, rolled VL, accrued, ejected with and without a shift), is the post-rebuild state exactly what Grind_ReconExitMatchesEntry accepts at the NEW exit, per tick?" Need check if any branch fails.

Let's examine the non-ejected branch more closely. It computes:
```
const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);
double price = formula;
const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);
...
if(MathAbs(resting - price) > _Point * 0.5) {
   if(!Grind_ModifyPendingPrice(exit_ticket, price, magic))
      return false;
   repriced++;
}
side.layers[i].exit_target = price;
if(clamped || MathAbs(price - formula) > _Point * 0.5)
   Grind_CarryRecordShift(pos, price - formula, true);
else
   Grind_CarryShiftDelete(pos);
```
If clamped is true, price is clamped passive (ask+min_dist or bid-min_dist). Then it records shift = price - formula. I6 expected = ExitPrice(eff) + accrued + eject_offset + shift. Since formula = ExitPrice + accrued + eject_offset, expected = formula + shift = price. So if it modified, order at price, matches. If it did not modify (diff <=0.5), order at resting, diff to price <=0.5, passes tolerance 2. Good.

But what if `clamped` is true and `Grind_ModifyPendingPrice` succeeds, but the broker actually fills or rejects? Modify returns true on retcode DONE or PLACED. If PLACED, order might not be at new price? Usually PLACED means accepted. Assume.

What about `Grind_CarryRecordShift(pos, price - formula, true);` sets release marker. Then `Grind_CarryShiftGetForRecon` in I6 sees release marker and returns shift even if out of bound. So I6 uses shift. Good. But if shift is huge, it still passes? I6 computes expected = formula + shift = price. So passes. But the bound check is bypassed by release marker. That's intended for clamp.

Now, what about rolled VL branch? It uses `Grind_ExitQFormulaTarget` which uses `Grind_EffectiveEntry` -> VL. So price = ExitPrice(VL) + accrued + eject_offset. Then records shift if needed. I6 uses same. Good.

What about accrued? It uses `Grind_CarryAccruedGet(pos)` in formula. Rebuild does not modify accrued. So same.

Now T-2 ejected with and without shift. We did. Ejected without shift: offset = resting - (ExitPrice + accrued). I6 expects ExitPrice + accrued + offset = resting. Good. Ejected with shift: offset = resting - (ExitPrice + accrued + shift). I6 expects ExitPrice + accrued + shift + offset = resting. Good.

But wait: In the ejected branch, the code does NOT modify the order, but it also does NOT delete the shift. If the old shift was non-zero and valid, it remains. Then I6 uses shift. That's fine. But what about the release marker? If the shift had a release marker, Grind_CarryShiftGetForRecon returns it. Good.

What about the case where `Grind_EjectIsEjected(pos)` is true but `Grind_VLHas(pos)` is also true? Then it goes to normal branch. In normal branch, formula uses ExitQFormulaTarget which includes eject_offset. It modifies order to formula + shift. But wait: if a layer is ejected and rolled, the eject_offset might still be set? As noted, Grind_LatticeRollLayer deletes eject offset when rolling. But what if it didn't? Let's check Grind_LatticeRollLayer:
- If exit_order_ticket != 0: modifies, sets VL, `Grind_EjectOffsetDelete(pos)`, records shift.
- Else: sets VL, deletes offset, deletes shift.
So after roll, eject offset is deleted. So no layer should have both. But what if a layer was ejected, then rolled, then somehow eject offset set again? The only setting is in Grind_EjectAcceptLayer, which is called on commands/auto. If a layer is rolled, it has VL. Then a commanded eject? Grind_EjectAcceptLayer doesn't check VL. It modifies to target, computes offset = target - raw - accrued, sets offset, deletes shift. It does NOT delete VL. So a layer can be both ejected and have VL. Then in rebuild, condition `Grind_EjectIsEjected(pos) && !Grind_VLHas(pos)` is false, so it goes to normal branch. Normal branch uses ExitQFormulaTarget which includes eject_offset and effective entry (VL). It modifies to formula + shift. But the layer is ejected; its exit is supposed to be at market target. The normal branch would reprice it to formula (VL + exit + accrued + offset). That might be different from the current resting price (which was set by eject). But if the label changed, we want to reprice to new exit. For an ejected layer with VL, should it be kept or repriced? The operator ruled "a commanded eject moves the deepest exit to the market and stores an offset." If it's also rolled, the effective entry is VL. The offset was computed based on old exit? Actually eject offset is computed as target - raw - accrued, where raw = ExitPrice(effective entry, exit_pips). So offset depends on exit_pips. If exit_pips changes, the offset would be wrong if kept. The rebuild normal branch will recompute formula using new exit_pips and keep the old offset. That means the offset is not re-derived; it's kept. Then price = ExitPrice(new exit) + accrued + old_offset. But the old offset was target - (ExitPrice(old exit) + accrued). So price = target + (ExitPrice(new) - ExitPrice(old)). That might not be the market target. Is that intended? The branch description says for "each layer with a resting exit and no exit position: an EJECTED layer (offset, no VL) keeps its order and the offset is re-derived from the resting price; any other is modified to Grind_ExitQFormulaTarget". So if it's ejected AND has VL, it is "any other" and gets modified to formula. That formula includes the old eject_offset. So it does not re-derive offset. Is that correct? The I6 check will pass because it uses the same offset. But the ejected price may no longer be at market. The operator ruled "a commanded-eject exit keeps its price (operator)" only for ejected layers? The rule says "an EJECTED layer (offset, no VL) keeps its order and the offset is re-derived". So ejected with VL is treated as normal. Is that a bug? Could lead to an exit that was deliberately moved to market being moved back to a formula price based on old offset. But maybe it's rare. The threat T-2 asks "ejected with and without a shift". We should check.

Actually, the condition in code:
```
if(Grind_EjectIsEjected(pos) && !Grind_VLHas(pos)) {
   // ejected branch
}
const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);
```
So if ejected and has VL, it goes to normal branch. The normal branch will modify the order to formula. That formula includes `Grind_EjectOffsetGet(pos)`. So it keeps the offset. But the offset was computed for the old exit? Wait Grind_EjectOffsetFor(target, raw, accrued) = target - raw - accrued. raw = ExitPrice(eff, exit_pips). So offset = target - ExitPrice(eff, old_exit) - accrued. Then formula with new exit = ExitPrice(eff, new_exit) + accrued + offset = target + (ExitPrice(new) - ExitPrice(old)). That is not target unless new=old. So the exit moves by the exit difference. Is that desired? If operator changes exit input, they want the exit at new distance from entry. For a normal layer, yes. For an ejected layer, the operator may want to keep the marketed exit? But the rule says only ejected without VL keeps its price. So maybe ejected with VL is intentionally repriced to new exit. But then the offset is wrong? Actually if you reprice to new exit, you should delete the eject offset and let the formula be just ExitPrice(new) + accrued. But the code keeps the offset, so the exit is shifted by the old offset. That means I6 passes, but the exit is not at the new intended distance. Is that a bug? The rebuild's goal is to make I6 pass at the new exit. It does: I6 uses the offset. So the invariant passes. But the economic intent is wrong. However, the threat T-2 asks "is the post-rebuild state exactly what Grind_ReconExitMatchesEntry accepts at the NEW exit, per tick?" It accepts because it includes offset. So I6 passes. But the "NEW exit" might mean new exit_pips. The state is consistent with I6. So not an I6 failure. But could be a functional issue. The question: "In the ejected branch the offset uses Grind_CarryShiftGetForRecon: can it delete or ignore a shift and leave I6 inconsistent?" That's specifically about ejected branch. We already saw it doesn't delete for ejected. But what about the case where `Grind_CarryShiftGetForRecon` deletes a shift? For ejected, it returns shift without validation. So no.

But wait: In the ejected branch, it uses `Grind_CarryShiftGetForRecon(pos)`. That function first checks release marker, then if `Grind_EjectIsEjected` returns shift. Since we are in ejected branch, it returns shift. So it won't delete. So no inconsistency.

T-3 Partial failure and restart. Let's analyze.

In OnInit:
```
Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);
if(!Grind_RebuildExitsAtStart(InpMagic)) {
   g_grind_halted = true; ... CancelOwnEntryOrders ...
} else {
   Grind_GeoExitWriteLabels(...);
   g_grind_start_add_reprice_long = true;
   g_grind_start_add_reprice_short = true;
}
```
If rebuild fails on short side after long side succeeded: long side has been modified to new exit, shift recorded, labels not written (because else not executed). Short side may have been partially modified? Grind_RebuildExitsAtStart calls long side then short side. If short fails, long side changes are kept. Labels not written. Then halt. Next init: labels are still old (or absent). g_grind_rebuild_long/short computed from labels. If labels were old, they differ from new exit? Wait scenario: operator changes exit input, restarts. First init: labels are old (say from previous successful init with old exit). `Grind_GeoExitChanged` sees label != current exit -> true for both sides. Rebuild long succeeds, short fails. Halt. Labels NOT written. So labels remain old. Next restart (after fixing issue): labels still old, so both sides flagged again. Long side: its exits are already at new exit. Rebuild will see `MathAbs(resting - price) <= 0.5` so no modify. Short side tries again. So no double move. Good. But what if failure on second exit of a side? The side function returns false on first failed modify. It may have already modified some exits. Those are at new price. Next restart, they won't be modified again. Good. So partial failure seems safe.

But what about crash mid-rebuild (GVs flushed within 1s). If crash after modifying some exits and recording shifts, but before labels written. On restart, labels old. Rebuild will run again. For already modified exits, resting ≈ price, so no modify, but it will still set exit_target and record/delete shift. If it previously recorded a shift for a clamped exit, and now the market moved so clamp is different? Wait crash mid-rebuild: some exits modified with shift recorded. On restart, the market may have changed. The rebuild recomputes formula with current market, clamps again. It may modify again if the new clamped price differs from the already resting price. That could be a second move. The threat asks "no exit moved twice". Is that possible? Yes, if the market moved between the two rebuilds and the clamp target changed. For a clamped exit, the first rebuild moved it to ask+min_dist (say). It recorded shift. Then crash. On restart, the market moved, so the new formula/clamped price is different. The rebuild will see resting (old clamped price) vs new price, difference >0.5, and modify again. That's a second move. Is that a problem? The exit is being moved to the new correct clamped price. It's not a double move in the sense of moving to the same target twice. But the threat says "no exit moved twice" maybe meaning no exit is moved twice for the same reason? Actually moving again to a new correct price is fine. But if the market moved back, it could move back. However, the branch is about rebuild at start. It's acceptable to reprice to current market. But the label gating: if the first rebuild succeeded and wrote labels, then on restart labels would be new, so no rebuild. But crash before labels written means labels old, so rebuild runs again. That's intended. So moving again is expected. The threat might be about moving an exit that was already moved and then failing to record shift correctly? Let's check: On first rebuild, it recorded shift. On second rebuild, it recomputes formula and clamps. It will overwrite shift. So no stale shift. Good.

But what about an exit that was modified in the first rebuild but the shift was recorded. Then crash. On restart, recon with tolerance (labels old) skips I6 mismatch. Rebuild runs. For that exit, it reads resting (the new price). It recomputes formula. If the new price matches formula within 0.5, it does not modify, but it deletes shift? Wait code:
```
if(MathAbs(resting - price) > _Point * 0.5) {
   modify
}
side.layers[i].exit_target = price;
if(clamped || MathAbs(price - formula) > _Point * 0.5)
   Grind_CarryRecordShift(pos, price - formula, true);
else
   Grind_CarryShiftDelete(pos);
```
If it does not modify, it still sets exit_target = price (new formula). If the old shift was from a clamp, and now clamp is not needed (market moved), `clamped` is false, `MathAbs(price - formula)` likely 0, so it deletes shift. But the actual order is at resting, which is the old clamped price. The new price = formula (unclamped). The difference between resting and price might be <=0.5? If the old clamp was say 0.0005 (5 points), then resting is 5 points away from new formula. `MathAbs(resting - price) > 0.5` so it WILL modify. So it modifies. If the old clamp was small, maybe <=0.5, then it deletes shift and leaves order at resting. I6 expects formula (no shift). Difference <=0.5, passes. So okay.

But what about a stale shift that was recorded but the order was not modified? That could happen if `MathAbs(resting - price) <= 0.5` but `clamped` true. Then it records shift = price - formula, but does not modify. The actual order is resting, which is within 0.5 of price. I6 expected = formula + shift = price. So diff <=0.5. Pass. But the shift is recorded. On next tick, Grind_CheckBookInvariants strict will check I6. It will use the shift. Expected = formula + shift = price. Actual resting diff <=0.5, pass. So okay.

T-3 also asks "Is every next init tolerant exactly where needed and able to finish, with no exit moved twice and no stale shift or offset?" The key risk: the tolerance flags are computed from labels. If labels were written after a successful rebuild, next init no tolerance. Good. If labels not written due to halt, next init tolerance. Good. But what if the halt happened after labels were written? The code writes labels only in else when rebuild returns true. So no.

What about a failure on the short side after long succeeded: labels not written, so next init both sides flagged. Long side already fixed, so no modify. Short side tries again. Good.

What about a failure on the second exit of a side: same.

What about crash mid-rebuild: labels not written, so next init both flagged. It will finish. Good.

But there is a subtle issue: In OnInit, `Grind_CarryPruneShiftGvs(InpMagic)` is called AFTER the rebuild, regardless of success or halt. If rebuild failed on short side, long side may have recorded new shifts. Then `Grind_CarryPruneShiftGvs` prunes shifts for tickets that don't exist. That's fine. But what if the halt path cancels entries? It doesn't touch exits. So shifts remain. Next init, labels old, rebuild long side sees exits already at new price. It will recompute formula and possibly delete/record shifts. If the shift was for a clamped exit, it might be re-recorded. Good.

T-4 Label lifecycle. Need examine.

Labels are GVs `GRIND_GEO_EXIT_<magic>_L/_S`. They are written in OnInit after successful rebuild. They are never deleted except maybe by `Grind_CarryPruneShiftGvs`? Let's check. `Grind_CarryPruneShiftGvs` only deletes GVs with prefixes "GRIND_CARRY_SHIFT_", "GRIND_CARRY_RELEASE_", "GRIND_EJECT_OFFSET_". It does NOT delete "GRIND_GEO_EXIT_". So labels survive. Good.

But what about flush? `Grind_GeoExitSet` calls `Grind_GvMarkDirty()`. OnTimer flushes every second. OnInit returns, timer set at end. So labels will be flushed within 1s. If terminal crashes before flush, labels lost. Next init: labels absent, so `Grind_GeoExitChanged` returns false (no tolerance). Then recon will be strict. If exits were already rebuilt to new exit, they will pass strict I6? Wait if labels were lost, but the book is already at new exit. Recon strict will check I6 at current exit input. Since exits were rebuilt to new exit, they should pass strict. So no problem. But what if the crash happened after rebuild but before labels written/flushed, and the market moved such that clamped exits are now off? Strict I6 uses shift recorded. The shift was recorded in GVs. If those GVs were flushed? `Grind_CarryRecordShift` marks dirty. OnTimer flushes. If crash before flush, shifts lost too. Then strict I6 will see no shift, and clamped exit will be off by the clamp amount, causing halt. That's a risk. But the threat says GVs flushed within 1s. If crash within 1s, both labels and shifts may be lost. Then next init: labels absent -> no tolerance -> strict I6 on clamped exits fails -> halt. Is that a problem? The branch is supposed to handle exit change. If crash before flush, it's a hard failure. But that's a general GV persistence issue. The threat T-4 asks "Flush and survival across restarts, deletion by Grind_CarryPruneShiftGvs (called after the rebuild in OnInit) or by any prefix cleanup". The prune does not delete labels. So labels survive if flushed.

But there is a more serious T-4: "the same magic on another account or terminal". GVs in MT5 are global to the terminal, not per account? Actually global variables are per terminal, but they can be shared across accounts? In MT5, global variables are stored in the terminal folder, not per account. So if you run the same magic on another account in the same terminal? The magic lock prevents duplicate magic in same terminal? `Grind_MagicLockClaim` probably uses a GV or file. But GVs are terminal-wide. If another account uses the same magic in the same terminal, the labels would be shared. But the EA has a magic lock to prevent duplicate magic in same terminal. So same magic on another account in same terminal would fail to init. On another terminal, GVs are separate. So okay.

But what about "a label written when a missing exit could not be placed (ADR-156 startup shortfall)". In OnInit, after recon, it calls `Grind_RetryMissingExits`. That may place missing exits. Then `Grind_RebuildExitsAtStart`. If some exits were missing and couldn't be placed (shortfall), they have no exit order. The rebuild only iterates layers with resting exit. Missing exits are not touched. Then labels are written. So labels are written even though some exits are missing. Is that a problem? The labels just record the exit input. If the exit input hasn't changed, labels are same. If it changed, labels written even though missing exits couldn't be placed. Next restart, labels match current exit, so no tolerance. But the missing exits might still be missing. That's handled by shortfall logic. Not a label issue.

"an operator who changes the exit and restarts twice." First restart: label old, changed -> rebuild, labels written new. Second restart: label new, input new -> no rebuild. Good.

T-5 One-shot add. Code in Grind_EnsureAddNext:
```
const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;
if(is_long)
   g_grind_start_add_reprice_long = false;
else
   g_grind_start_add_reprice_short = false;
const double add_deadband = one_shot ? 0.05 : deadband_pips;
```
This is inside Grind_EnsureAddNext. It clears the flag as soon as this point is reached, before the comparison? Actually the flag is read and cleared, then used for deadband. The comparison happens later. Let's see function order:

```
void Grind_EnsureAddNext(...)
{
   const int n = Grind_SideDepth(side);
   const int required_index = Grind_SideNextIndex(side);

   if(side.add_pending_ticket != 0) {
      if(!Grind_SelectOurOrder(...)) {
         if(Grind_SelectOurPosition(...))
            return;
         side.add_pending_ticket = 0;
      } else {
         ... parse comment ...
         if(!label_ok) {
            Grind_Adr152ClearDueForSide(is_long);
            ...
            if(Grind_CancelPendingOrder(...))
               side.add_pending_ticket = 0;
            return;
         }
      }
   }

   if(n <= 0 || !Grind_CanPlaceEntryLayer(...)) {
      Grind_Adr152ClearDueForSide(is_long);
      return;
   }
   if(!Grind_CapAllowsEntry(...))
      return;
   if(Grind_EntriesBlocked())
      return;

   if(Grind_EntryHorizonActive()) {
      Grind_ApplyEntryHorizon(...);
      Grind_Adr152AssertHeldPendingExclusive(side);
      return;
   }

   const int next_layer = required_index;

   double add_target = Grind_ComputeAddTarget(...);
   if(add_target <= 0.0)
      return;

   const double bid = ...
   ...
   if(is_long && !Grind_BuyLimitMarketable(...))
      return;
   if(!is_long && !Grind_SellLimitMarketable(...))
      return;

   const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;
   if(is_long)
      g_grind_start_add_reprice_long = false;
   else
      g_grind_start_add_reprice_short = false;
   const double add_deadband = one_shot ? 0.05 : deadband_pips;

   if(side.add_pending_ticket != 0) {
      const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);
      if(Grind_PriceWithinDeadband(resting, clamped, add_deadband, _Point))
         return;
      Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
      return;
   }

   if(!Grind_ValidateAddLabelIndex(required_index, next_layer))
      return;

   if(g_grind_ent_sent_this_tick)
      return;

   Grind_SendNextAddEnt(...);
}
```

So the flag is cleared before the comparison. If any early return happens before the flag clearing (e.g., no add_pending, but n<=0, cap, entries blocked, entry horizon active, add_target <=0, marketable check fails), the flag is NOT cleared. It will survive into later ticks. The threat asks: "Can the flag be cleared without the comparison (early returns), survive into later ticks, cause more than one modify, or interfere with ADR-152's due-flag path or the entry horizon?"

Yes, if there is an early return before the flag clearing, the flag survives. For example, if `Grind_EntryHorizonActive()` is true, it calls `Grind_ApplyEntryHorizon` and returns. The one-shot flag is never cleared. Then on a later tick, when entry horizon is not active? Actually if entry horizon is active, it always takes that branch and returns. The flag will never be cleared while entry horizon is active. But if the operator turns off entry horizon? The flag is set at init. If entry horizon is active, the one-shot add reprice is never used. It will stay true. Later if entry horizon is turned off (requires restart? InpEntryHorizonPips is input, so restart). On restart, flags are reset? In OnInit, g_grind_start_add_reprice_long/short are set to true only if rebuild succeeded. But they are global variables, not reset at init? Actually in OnInit, before setting, they might retain values from previous run? But OnInit runs on fresh terminal start? In MT5, global variables of the EA are reinitialized? They are declared with initial values false. On init, if successful, they are set to true. So if entry horizon is active, the flag is set true at init. Then on each tick, Grind_EnsureAddNext is called? Actually if entry horizon is active, Grind_EnsureAddNext is called from OnTickEngine? Let's check: Grind_OnTickEngine calls `Grind_EnsureAddNext` only if `Grind_EntryHorizonActive()`? No, in Grind_OnTickEngine:
```
if(Grind_SideDepth(g_grind_long) > 0 || g_grind_long.add_pending_ticket != 0)
   Grind_EnsureAddNext(...);
```
Grind_EnsureAddNext itself checks `if(Grind_EntryHorizonActive()) { Grind_ApplyEntryHorizon(...); return; }`. So if entry horizon is active, the flag is never cleared. That's a bug: the one-shot flag survives indefinitely. But does it cause harm? The one-shot flag is only used to set a tighter deadband for add reprice. If it never clears, then whenever entry horizon is later deactivated (requires restart), on next init the flag is set true again anyway. But if entry horizon is active, the add reprice logic is not used; instead Grind_ApplyEntryHorizon manages the add. So the flag being true doesn't affect anything. However, if entry horizon is active, then later the EA is restarted without entry horizon, the flag is set true at init. So no issue.

But consider: early return before flag clearing due to `side.add_pending_ticket != 0` and `!label_ok`. In that case, it cancels the pending order and returns. The flag is not cleared. Next tick, the pending is gone, and it proceeds. The flag is still true, so it will use the one-shot deadband on the next evaluation. That might be intended? The one-shot should apply to the first evaluation after init. If the first evaluation hits a stale add and cancels it, the actual add reprice happens on the next tick, still using one-shot. That seems acceptable. The threat says "cleared without the comparison" meaning if it clears before comparing, then a later call won't use one-shot. But here it doesn't clear on early return. So it survives. That could be good or bad. But the threat asks "Can the flag be cleared without the comparison (early returns)"—actually it's NOT cleared on early returns. It is cleared only when it reaches the point before the comparison. Wait the code clears it before the comparison, but only after passing all early returns. So if it passes all early returns, it clears and then compares. So it is cleared without the comparison if the comparison is skipped? The comparison is the `Grind_PriceWithinDeadband` check. It is done after clearing. So if it clears, it will then do the comparison (unless `side.add_pending_ticket == 0`? Actually after clearing, it checks `if(side.add_pending_ticket != 0)`. If add_pending_ticket is 0, it skips the comparison and goes to `Grind_ValidateAddLabelIndex` and possibly sends new add. So the flag is cleared without a comparison when there is no resting add. That's fine: one-shot only applies to reprice an existing add. If there is no add, no reprice needed. But could it clear the flag and then fail to place a new add? Then the one-shot is lost. But that's probably fine.

More concerning: "cause more than one modify". The one-shot flag is a bool. It can only cause one modify because it's cleared after first use. But if the first use results in no modify (because within 0.05 deadband? Actually 0.05 pips is very tight. It will almost always modify if not exactly equal. If it modifies, flag cleared. If it doesn't modify because within 0.05, it returns without modify, flag cleared. So at most one modify. However, if the modify fails? `Grind_ModifyPendingPrice` return value ignored. It returns false, but the function returns anyway. The flag is already cleared. So no retry with one-shot. That's probably intended.

"interfere with ADR-152's due-flag path or the entry horizon?" In Grind_ServiceDueAddFlags, if entry horizon active, it calls Grind_EnsureAddNext. As noted, if entry horizon active, Grind_EnsureAddNext returns early before clearing flag. So the flag remains true. Then if later entry horizon is turned off (requires restart), the flag is set true again. So no interference.

But what about Grind_EnsureAddNext being called from Grind_OnTickEngine? It is called every tick. The one-shot flag is set at init. On the first tick, if entry horizon is not active, it will eventually reach the flag and clear it. If there is no add_pending_ticket, it clears and then may send a new add. That's fine.

T-6 OnInit ordering. Let's analyze.

OnInit sequence:
1. Validate inputs.
2. Magic lock.
3. Set globals.
4. Grind_ReconstructState().
5. If recon success: check shortfall, Grind_RetryMissingExits, Grind_RebuildExitsAtStart, write labels or halt.
6. Grind_CarryPruneShiftGvs(InpMagic)
7. Grind_MaeInit(), CapPublish, etc.
8. EventSetTimer(1).

Threats:
- `Grind_RetryMissingExits` before rebuild. This places missing exits using current exit input. If exit input changed, it places missing exits at new exit. Then rebuild reprices existing resting exits to new exit. So both end up at new exit. Good.
- `Grind_CarryPruneShiftGvs` after rebuild. It prunes shifts for positions that don't exist. If rebuild failed and halted, it still runs. Could it delete shifts for positions that exist? It checks `PositionSelectByTicket(ticket)`. If position exists, it keeps. If not, deletes. That's fine.
- Halt path: entries cancelled, timer still set. On halt, OnTick returns early after breaker etc. But timer still runs, so OnTimer will still flush GVs, session step, etc. Is that unsafe? The EA is halted, but timer still runs. It may emit telemetry, run carry pass? In OnTimer:
```
Grind_SnapshotOnTimer();
Grind_ArchiveFlush(false);
Grind_SessionStep(...);
if(telemetry due) {
   ...
   Grind_CarryOnTimerStep(...);
}
```
If halted, `Grind_CarryOnTimerStep` may still run if `InpEnableCarryPass` is true. That could modify exits during carry window even though halted! Let's check. `Grind_CarryOnTimerStep` calls `Grind_CarryExitPassStep` if `enable_carry_pass`. It modifies exit orders. There is no check for `g_grind_halted`. So a halted instance could still shift exits during the carry window. Is that a problem? The branch says halt path: entries cancelled, timer still set. The carry pass could still modify exits. That might be intentional? But if halted due to rebuild failure, the book is in an inconsistent state (I6 mismatches). The carry pass might further modify exits, potentially making things worse. But the halt is supposed to stop trading. Modifying exits might be considered trading? The carry pass is not entry, but it modifies exits. The threat T-6 asks "the halt path (entries cancelled, timer still set) ... Anything unsafe?" This could be unsafe: on halt, exits may be modified by carry pass, but I6 strict checks are skipped because OnTick returns early if halted. So the book could drift. However, the halt is a critical state; operator intervention expected. But it's a risk.

Let's verify: In OnTick, if `g_grind_halted`, after some initial calls, it returns before `Grind_CheckBookInvariants`? Actually OnTick:
```
Grind_ProcessCloseByQueues(...);
if(!g_grind_halted) {
   ... Grind_CheckBookInvariants ...
}
Grind_EjectPollCommand(...);
Grind_AutoEjectOnTick(...);
Grind_LatticeOnTick(...);
Grind_SessionStep(...);
Grind_BreakerOnTick(...);
if(g_grind_halted) return;
...
```
So even when halted, it still calls EjectPollCommand, AutoEjectOnTick, LatticeOnTick, SessionStep, BreakerOnTick. Wait, `Grind_EjectPollCommand` is called with `g_grind_halted || g_grind_quarantined` as `engine_blocked`. In `Grind_EjectPollCommand`, it checks `Grind_EjectValidate(engine_blocked, ...)` which returns `GRIND_EJECT_HALTED` if blocked. So commanded eject is blocked. `Grind_AutoEjectOnTick` is called with `blocked = g_grind_halted || g_grind_quarantined`. In `Grind_AutoEjectOnTick`, it checks `if(!enabled || blocked) return;` so auto eject is blocked. `Grind_LatticeOnTick` is called with `blocked = g_grind_halted || g_grind_quarantined`. In `Grind_LatticeOnTick`, it calls `Grind_LatticeTrackExtremes` then `if(blocked) return;` so lattice roll is blocked. `Grind_SessionStep` may still cancel entries, but entries already cancelled. `Grind_BreakerOnTick` may still run, but it only cancels entries. So no exit modifications on halt from OnTick. But OnTimer is separate. OnTimer calls `Grind_CarryOnTimerStep` without checking `g_grind_halted`. So carry pass can modify exits even when halted. That is a real T-6 issue. The halt is meant to stop trading, but the carry pass can still shift exits. Is that unsafe? It could move exits further, but it's a passive shift for carry. The operator might want carry pass to continue? The ADR-135b carry pass is meant to shift exits to cover swap. If halted, maybe it should not run. But the threat asks "Anything unsafe?" I'd flag as NEEDS-FIX or BREAKS? It's a potential unsafe path. However, the branch description says "OnInit then halts (REBUILD_EXIT_FAILED, entries cancelled, labels NOT written)". It doesn't mention stopping carry pass. The carry pass is in OnTimer. So yes, it continues. But is that a bug introduced by this branch? It's pre-existing. The branch adds a new halt reason. The threat is about OnInit ordering. I'll mention it as a risk.

- A reattach inside the carry window: If OnInit runs during the carry window (23:50-00:00 server time), `Grind_ReconstructState` runs, then `Grind_RetryMissingExits`, then `Grind_RebuildExitsAtStart`. The carry pass may also be active? OnTimer will run. The carry pass uses `Grind_CarryGateDue` and `Grind_CarryGateInWindow`. If reattach inside window, the carry pass might start. The rebuild may have just set exits to new formula. Then carry pass will shift them for carry. That's probably okay. But what if the rebuild uses the old exit? No, it uses current input. So okay.

- A reattach with the market closed (every modify fails: halt). If market closed, `Grind_ModifyPendingPrice` may fail. The rebuild returns false on first failed modify. Then halt. Labels not written. Next restart when market open, labels old, rebuild runs again. So it will eventually succeed. But if the market is closed, the EA halts. Is that unsafe? It cancels entries and halts. When market opens, the EA is still halted? The halt is in OnInit. It sets `g_grind_halted = true`. OnTick will return early. The EA will not trade. It requires a restart to clear halt? Actually `g_grind_halted` is a global variable. It is set to true. On subsequent ticks, it remains true. The only way to clear is reinit? In OnInit, `g_grind_halted = false;` is set before ReconstructState. Wait OnInit sets `g_grind_halted = false;` early:
```
g_grind_last_telemetry_tick = 0;
g_grind_halted = false;
...
if(!Grind_ReconstructState()) { ... } else { ... if(!Grind_RebuildExitsAtStart) { g_grind_halted = true; ... } }
```
So on restart, it clears halt. But if the market is closed, OnInit will halt. The EA remains halted until the next restart. But the terminal may not restart automatically when market opens. So the EA would be halted and not trade until manual restart. That is a serious issue: a reattach with market closed causes halt, and the EA won't resume when market opens. The threat T-6 explicitly mentions "a reattach with the market closed (every modify fails: halt). Anything unsafe?" This is unsafe: the instance is halted and won't recover without manual intervention. The branch's halt on failed modify is intended, but if the market is closed, every modify fails, so it always halts. The operator would need to restart after market opens. Is there any mechanism to retry? In OnTick, if halted, it returns early. No retry. So the EA is dead. This is a BREAKS for T-6. The smallest fix: defer rebuild until market is open, or don't halt on modify failure if market closed, or set a flag to retry on next tick. But the branch rule says "halt on the first failed modify". So maybe the operator expects to restart when market open. But the threat asks if anything unsafe. Yes, it's a availability issue.

But wait: Does the market being closed actually cause modify to fail? In MT5, pending order modification may fail if market is closed. The test seam `g_grind_order_test_send_ok = false` simulates failure. In production, if market closed, `Grind_ModifyPendingPrice` calls `Grind_OrderEngineSend` which calls `OrderSend`. If market closed, retcode may be TRADE_RETCODE_MARKET_CLOSED. The function returns false. So rebuild returns false, halt. That's a real risk. The branch should perhaps check `Grind_CarrySessionReady` or market open before rebuild, or not halt if failure is due to market closed. But the rule says halt on first failed modify. So the branch as specified will halt. The threat likely expects us to flag this as unsafe. So T-6 BREAKS.

T-7 Tests. Need find which v2.1 behaviour has no test that fails without it. Tests in fxgrind_tests_rb.mqh. Let's list tests:
- RB1 LongRebuild
- RB2 ShortRebuild
- RB3 EjectedKeepsPrice
- RB4 RolledFromVL
- RB5 AccruedKept
- RB6 ClampRecordsShift
- RB7 UnflaggedNoop
- RB8 FailClosed
- RB10 ReconTolerance
- RB11 Labels
- RB12 AddOneShot
- GV14 DueAddShort
- GV15 RecenterShortWidth

What v2.1 behaviour lacks test? 
- The gating logic `Grind_GeoExitChanged` is tested in RB11.
- Tolerance per side tested in RB10.
- Rebuild branches tested.
- But: `Grind_ReconstructState` and `OnInit` have no broker test seam (given). So the wiring from labels to `g_grind_rebuild_long/short` and the OnInit flow (retry missing exits, rebuild, labels write, halt) is not tested. RB tests call `Grind_RebuildExitsAtStart` directly with manually set flags. They do not test that `Grind_ReconstructState` sets `g_grind_rebuild_long/short` from labels. They do not test the OnInit sequence. So the branch's integration with OnInit is untested. Also the label lifecycle across restart (flush, prune) is not tested. The halt path (REBUILD_EXIT_FAILED) is not tested. The one-shot add flag clearing on early returns? RB12 tests one modify and flag cleared. But does it test that flag survives early returns? No.

Vacuous assertions? Check RB10: 
```
GrindReconLayerScratch l[1];
Grind_TestInitLayerScratch(l[0], 0, 1.20000, 7001UL);
l[0].has_exit_order = true;
l[0].exit_order_ticket = 8001;
l[0].exit_target = 1.20100;
...
AssertFalse("RB10 strict fails", Grind_ReconCheckInvariants(...));
```
This calls Grind_ReconCheckInvariants directly. It doesn't set up a real book. It uses a single layer. The function checks I6. It should fail. Then with tolerance true, it should pass. That's valid.

But note: `Grind_ReconCheckInvariants` also checks I3 naked? The layer has has_position? `Grind_TestInitLayerScratch` probably sets has_position true? Let's check signature? Not provided. We can't see. But it likely sets has_position true. If not, it would fail I3. But the test expects strict fails for I6, so it must pass I3. So okay.

What about RB12: It tests one-shot add. It sets `g_grind_start_add_reprice_short = true`. Calls `Grind_EnsureAddNext`. It asserts moved once and flag cleared. Then calls again with different add_pips and asserts modify_calls == mods_before + 1 (no additional modify). That tests that the flag doesn't persist. But does it test that the flag is not cleared on early return? No.

GV14 and GV15 are for ADR-152 path, not v2.1 specific? They test due flag and recenter with short geometry. Probably not v2.1.

Also, the test `RB7_UnflaggedNoop` tests that with no rebuild flags, no modify. That's G1 indirectly.

But the most glaring test gap: There is no test that `Grind_ReconstructState` sets `g_grind_rebuild_long/short` from labels. Since no seam, they can't. The given says "Grind_ReconstructState and OnInit have no broker test seam (their wiring is read, not unit-tested)." So that's a known gap.

Another gap: No test for the ejected branch with a shift. RB3 tests ejected without shift (offset set, no shift). RB6 tests clamp with shift but not ejected. There is no test for ejected with a nonzero carry shift. T-2 mentions ejected with and without a shift. The test RB3 has no shift. So that path is untested.

Also no test for `Grind_CarryShiftGetForRecon` deleting a shift in ejected branch. No test for partial failure (long success, short fail). RB8 tests failure on first modify (both? Actually RB8 sets send_ok=false and rebuild_long=true. It fails on L0. It doesn't test short failure after long success). No test for crash mid-rebuild.

T-7 also asks "Does any assertion in fxgrind_tests_rb.mqh pass vacuously (inside an if, on leftover state, on a fixture that never reaches the code)?" Let's scan.

RB1:
```
const bool ok = Grind_RebuildExitsAtStart(RB_MAGIC);
AssertTrue("RB1 ok", ok);
```
Then asserts. No if.

RB8:
```
g_grind_order_test_send_ok = false;
const bool ok = Grind_RebuildExitsAtStart(RB_MAGIC);
AssertFalse("RB8 fails closed", ok);
AssertNear("RB8 L0 untouched", ...);
g_grind_order_test_send_ok = true;
Grind_RebuildExitsAtStart(RB_MAGIC);
AssertNear("RB8 retry moves L0", ...);
```
Valid.

RB10: The test calls Grind_ReconCheckInvariants with a manually constructed layer. It asserts false/true. No vacuous.

RB11: 
```
AssertTrue("RB11 absent unchanged", !Grind_GeoExitChanged(RB_MAGIC, true, 7.0));
```
After RB_Reset deletes labels. Valid.

RB12: 
```
const int mods_before = g_grind_order_test_modify_calls;
Grind_EnsureAddNext(...);
AssertNear("RB12 moved once", ...);
AssertTrue("RB12 flag cleared", !g_grind_start_add_reprice_short);
Grind_EnsureAddNext(...);
AssertTrue("RB12 deadband back", g_grind_order_test_modify_calls == mods_before + 1);
```
This seems valid. But note: The second call uses add_pips=5.1. The first call moved to 1.20050. The second call with add_pips=5.1 computes new add target? It might be within deadband of 4.0 pips? Actually deadband_pips=4.0, so it won't modify unless difference >= 4 pips. 5.1 vs 5.0 is 0.1 pip, so within deadband. So no modify. That asserts deadband back. Valid.

But wait: In RB12, they set `g_grind_start_add_reprice_short = true` and call `Grind_EnsureAddNext`. The function first checks `if(side.add_pending_ticket != 0)`. It is 6201. It selects order, parses comment, label_ok? The comment is built with layer index 1. required_index = Grind_SideNextIndex(side). side has one layer with layer_index 0. So required_index = 1. So label_ok true. Then it goes on. n = 1, CanPlaceEntryLayer(1,8) true. Cap allows? Grind_CapAllowsEntry? Need check. Then EntriesBlocked? Probably false. EntryHorizonActive? They called `Grind_EngineConfigureAdr152(true, 0);` which sets fill_time_place=true, entry_horizon_pips default 0.0. So EntryHorizonActive false. Then computes add_target. Then marketable checks. Then one_shot flag read and cleared. Then add_deadband = 0.05. Then `if(side.add_pending_ticket != 0)` true. resting = 1.20060. clamped? Need see if clamped equals add_target. It computes add_target from entry 1.20000, add_pips=5.0. For short, add target = entry + add_pips? Grind_AddTargetPrice(anchor, add_pips, point, direction): for short direction -1? Wait Grind_AddTargetPrice(anchor_entry, add_pips, point, direction) returns anchor_entry - direction * pips. For short, direction = -1? In Grind_ComputeAddTarget, it calls `Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1)`. So for short is_long=false, direction=-1. So anchor - (-1)*pips = anchor + pips. So add_target = 1.20000 + 5*0.0001 = 1.20050. Yes. So clamped=1.20050. resting=1.20060. Difference 0.00010 = 10 points? Actually 0.00010 is 10 points (pip=0.0001? Wait for 5-digit, point=0.00001, pip=0.0001. 5 pips = 0.00050. So 1.20050. resting 1.20060 is 10 points = 1 pip? Actually 0.00010 = 10 points = 1 pip. So difference 1 pip. One-shot deadband 0.05 pips = 0.000005. So not within. Modify to 1.20050. Good. So test valid.

But note: `Grind_EnsureAddNext` is normally called from `Grind_OnTickEngine` which sets `g_grind_ent_sent_this_tick = false`. The test doesn't set it? It was reset in RB_Reset? RB_Reset calls Adr151_TestResetAll, Grind_OrderTestReset, etc. Grind_OrderTestReset sets g_grind_ent_sent_this_tick = false. So okay.

Now T-7: Which v2.1 behaviour has no test that fails without it? The label gating in `Grind_ReconstructState` is not tested. The `Grind_RebuildExitsAtStart` function itself is tested. The tolerance in `Grind_ReconCheckInvariants` is tested. The `Grind_GeoExitChanged` is tested. The `Grind_GeoExitWriteLabels` is tested. The one-shot add is tested. But the integration of `Grind_ReconstructState` setting flags from labels is not tested. Also the `Grind_RebuildExitsAtStart` side function's behavior when `resting <= 0.0` is not tested. The ejected with shift is not tested. Partial failure is not tested. The halt path is not tested. So TEST GAPS.

Now let's also check GIVENS carefully with quotes.

G1: With no label for a side, that side's init I6 is exactly as strict as before this branch.
Quote: `Grind_GeoExitChanged` returns false if no label: 
```
if(!Grind_GeoExitGet(magic, is_long, label))
   return false;
```
And `Grind_ReconCheckInvariants` only skips if `tolerate_exit_price_long` true:
```
if(tolerate_exit_price_long && !long_exit_filled)
   continue;
```
So if flag false, strict. VERIFIED.

G2: `Grind_CheckBookInvariants` passes no tolerance flag.
Quote:
```
const bool ok = Grind_RebuildBookFromTickets(tickets, count,
                                             g_grind_recon_magic,
                                             g_grind_recon_slot,
                                             g_grind_recon_exit_pips,
                                             g_grind_recon_max_layers,
                                             _Point,
                                             long_tmp, short_tmp, reason,
                                             false,
                                             g_grind_recon_exit_pips_short);
```
The call passes `false` for tolerate_exit_shortfall and `g_grind_recon_exit_pips_short` for exit_pips_short; the last two params default to false. So no tolerance. VERIFIED.

G3: A FILLED exit is never tolerated.
Quote:
```
if(tolerate_exit_price_long && !long_exit_filled)
   continue;
```
So if `long_exit_filled` true, it does not continue. Also in `Grind_ReconExitMatchesEntry`:
```
if(exit_is_filled) {
   if(is_long && diff >= 0.0)
      return true;
   if(!is_long && diff <= 0.0)
      return true;
}
```
This is the only tolerance for filled, but it's adverse check. The branch's tolerance flag does not apply. VERIFIED.

G4: `Grind_RebuildExitsAtStartSide` prices a non-ejected exit with the same formula I6 checks (`Grind_ExitQFormulaTarget` + the recorded shift).
Quote in function:
```
const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);
...
if(clamped || MathAbs(price - formula) > _Point * 0.5)
   Grind_CarryRecordShift(pos, price - formula, true);
else
   Grind_CarryShiftDelete(pos);
```
And I6 in `Grind_ReconExitMatchesEntry`:
```
const double expected = Grind_ExitPrice(eff, exit_pips, point, dir) + accrued + eject_offset + shift;
```
`Grind_ExitQFormulaTarget` returns the same without shift. So price = formula + shift. VERIFIED.

G5: Labels are written only when the rebuild returned true.
Quote in OnInit:
```
if(!Grind_RebuildExitsAtStart(InpMagic)) {
   g_grind_halted = true;
   ...
} else {
   Grind_GeoExitWriteLabels(InpMagic, g_geo_exit_long, g_geo_exit_short);
   ...
}
```
VERIFIED.

Now T-1 verdict. We have a concrete leak: `resting <= 0.0` skip in rebuild. Let's cite:
`Grind_RebuildExitsAtStartSide`:
```
const double resting = Grind_OrderGetPriceOpen(exit_ticket);
if(resting <= 0.0)
   continue;
```
If tolerance let a mismatch through, and then this skip happens, the exit is not fixed. Next tick `Grind_CheckBookInvariants` is strict and will halt. Also, the tolerance applies to any resting exit on the flagged side, including an exit on a held rank. But rebuild does fix those if readable. The skip is the main hole. Another: "an exit whose order cannot be read (`resting <= 0.0` is skipped)". So T-1 BREAKS. Smallest fix: in rebuild, if `resting <= 0.0`, do not skip silently; treat as failure (return false) or re-read/select order, or ensure order is selected before reading. Since rebuild already returns false on modify failure, it could return false if it cannot read the resting price. That would halt at init instead of letting a bad state through to first tick. But the branch rule says halt on first failed modify. A missing read is a failure. So return false.

Also note: The tolerance could let through an exit with a wrong type, but I6 doesn't check type. Not a price mismatch.

T-2 verdict. Check each branch. We found potential issue with ejected+VL. Let's analyze more.

In `Grind_RebuildExitsAtStartSide`, the condition for ejected branch is `Grind_EjectIsEjected(pos) && !Grind_VLHas(pos)`. If a layer is ejected and has VL, it falls through to normal branch. The normal branch computes `formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);` which includes `Grind_EjectOffsetGet(pos)`. It then modifies the resting order to `price` (clamped formula), and records shift. This means the eject offset is kept. But the eject offset was computed for the OLD exit_pips. If the operator changed exit_pips, the offset should be re-derived or deleted. The branch description says: "an EJECTED layer (offset, no VL) keeps its order and the offset is re-derived from the resting price; any other is modified to Grind_ExitQFormulaTarget". So for ejected+VL, it is modified to formula. But the formula uses the old offset. Is that correct? The I6 check uses the same offset, so it passes. But the exit price is not at the market target. However, the threat asks "is the post-rebuild state exactly what Grind_ReconExitMatchesEntry accepts at the NEW exit, per tick?" It accepts because it includes offset. So I6 passes. The "NEW exit" might mean new exit_pips. The state is consistent with I6. So from an invariant perspective, it's fine. But there is a subtle bug: if the layer is ejected+VL, the normal branch will modify the order to `price = ExitPrice(VL, new_exit) + accrued + offset + shift`. But the offset was defined as `target - ExitPrice(VL, old_exit) - accrued`. So `price = target + (ExitPrice(new) - ExitPrice(old)) + shift`. This is not necessarily the intended new exit. But the operator rule says "a commanded-eject exit keeps its price (operator)" only for ejected without VL. So for ejected+VL, they intentionally reprice to new exit. But should they keep the offset? If they keep the offset, the exit moves by the difference in exit. That means the eject offset is effectively applied on top of the new exit. Is that desired? If the operator wants to change the exit distance, they probably want the new exit distance from the effective entry, not the old offset. But the offset was a manual eject to market. If it was ejected, the exit was moved to market (near bid/ask). If the operator changes exit, they might want it to be at the new distance? The branch description says "any other is modified to Grind_ExitQFormulaTarget". `Grind_ExitQFormulaTarget` includes the eject offset. So it's defined that way. So maybe it's correct per spec. The threat T-2 specifically asks about ejected branch and `Grind_CarryShiftGetForRecon`. It doesn't ask about ejected+VL. So maybe not a bug.

Let's check `Grind_CarryShiftGetForRecon` in ejected branch. It uses:
```
const double raw = Grind_ExitPrice(eff, exit_pips, _Point, dir)
                   + Grind_CarryAccruedGet(pos)
                   + Grind_CarryShiftGetForRecon(pos);
```
Then `offset = resting - raw`. It does not include any existing eject offset? Wait `Grind_ExitQFormulaTarget` includes eject offset, but here `raw` does NOT include `Grind_EjectOffsetGet(pos)`. That's intentional: they are re-deriving the offset. The offset is set to `resting - raw`. So the new offset will be such that `resting = ExitPrice + accrued + shift + offset`. That matches I6 expected. Good.

What if `Grind_CarryShiftGetForRecon` deletes a shift? As we said, for ejected, it returns shift without deletion. So no.

But what if the layer has a shift that is out of bound and no release marker, and it's ejected? `Grind_CarryShiftGetValidated`:
```
const string release_gv = ...;
if(GlobalVariableCheck(release_gv))
   return Grind_CarryShiftGet(position_ticket);
if(Grind_EjectIsEjected(position_ticket))
   return Grind_CarryShiftGet(position_ticket);
```
So it returns the shift even if out of bound. So it doesn't delete. Good.

So T-2 seems okay for I6 consistency. However, there is a potential issue with the normal branch when `clamped` is true but `MathAbs(resting - price) <= 0.5`. It does not modify the order, but it records a shift = price - formula. The order stays at `resting`. I6 expected = formula + shift = price. Actual = resting. Difference = |resting - price| <= 0.5. I6 tolerance is 2 points, so passes. But wait: I6 also checks `Grind_CarryShiftGetForRecon`, which may validate the shift. Since we recorded shift with `clamped=true`, it sets release marker. So validation returns shift. So I6 uses the new shift. Expected = price. Actual = resting. Diff <= 0.5. Pass. Good.

What if `clamped` is false but `MathAbs(price - formula) > 0.5`? That can't happen because clamped false means price = formula. So `MathAbs(price - formula)` = 0. So only clamped true or difference >0.5. Actually the condition is `clamped || MathAbs(price - formula) > _Point * 0.5`. If clamped false, price = formula, so second condition false. So it only records shift if clamped true. Wait, is there any other way price differs from formula? `Grind_ExitQClampPassive` may return false but modify price_out? Let's check `Grind_CarryClampLongExit`:
```
out_price = theoretical;
if(theoretical <= ask + min_dist - 1e-12) {
   out_price = ask + min_dist;
   return true;
}
return false;
```
So if it returns false, out_price = theoretical = formula. So no difference. So the second condition is redundant. So shift is recorded only when clamped. That's fine.

Now T-3. We discussed partial failure seems safe. But there is a potential issue with `Grind_RetryMissingExits` before rebuild. In OnInit, `Grind_RetryMissingExits` is called before rebuild. It calls `Grind_ExitQManageSide` which places missing exits. If the exit input changed, it places missing exits at the NEW exit. Then rebuild reprices existing resting exits to NEW exit. So all exits end at new exit. Good. But what if `Grind_RetryMissingExits` places an exit at the new exit, and then `Grind_RebuildExitsAtStart` sees that exit as resting and tries to modify it? It will compute formula = new exit, compare to resting (which is new exit), difference 0, so no modify. Good.

What if the rebuild fails on the short side after long side succeeded, and then `Grind_CarryPruneShiftGvs` runs? It prunes shifts for non-existent positions. The long side shifts are for existing positions, so kept. Good.

What about crash mid-rebuild? The GVs for shifts are marked dirty. If crash before flush, shifts lost. Next init: labels old, tolerance applied. Recon will see I6 mismatches and skip. Rebuild runs. For exits already modified, if shift lost, the resting price may be clamped (e.g., ask+min_dist). The rebuild recomputes formula with current market, clamps again, modifies to new clamped price, records shift. So it fixes. If the market moved such that no clamp needed, it will modify to formula (unclamped). So it fixes. So no stale shift. But if the crash happened after some modifies but before others, the unmodified ones still have old price. Rebuild fixes them. So safe.

However, there is a subtle issue: `Grind_RebuildExitsAtStartSide` iterates over `side.layers` which is the recon result. If the recon was tolerant (labels old), it may have skipped I6 mismatches. But the recon also sets `exit_target` from the ticket price. In the rebuild, for each layer, it reads `resting = Grind_OrderGetPriceOpen(exit_ticket)`. If the order was already modified in a previous aborted rebuild, it reads the new price. It computes new formula. It modifies if needed. So fine.

T-4 Label lifecycle. We need check if labels are deleted by `Grind_CarryPruneShiftGvs`. We saw it only deletes prefixes: "GRIND_CARRY_SHIFT_", "GRIND_CARRY_RELEASE_", "GRIND_EJECT_OFFSET_". Not "GRIND_GEO_EXIT_". So labels survive. Good.

But what about "the same magic on another account or terminal"? In MT5, global variables are per terminal, not per account. If you run the same magic on another account in the same terminal, the magic lock prevents it. If you run on another terminal, GVs are separate. So safe.

"a label written when a missing exit could not be placed (ADR-156 startup shortfall)". As discussed, labels are written after rebuild returns true, regardless of shortfall. If a missing exit could not be placed, the layer has no exit order. The rebuild only iterates layers with exit_ticket != 0. So it doesn't touch missing exits. Labels are written. Next restart, if exit input hasn't changed, labels match, no tolerance. The missing exit is still missing. But the shortfall logic will try to place it again via `Grind_RetryMissingExits`. So no issue. If exit input changed, labels old, tolerance applied. Recon will see the missing exit as naked? Actually if the exit is missing and required, recon with `tolerate_exit_shortfall=true` will skip the I3 naked check. So recon succeeds. Then `Grind_RetryMissingExits` tries to place it at new exit. Then rebuild runs. If it still can't place, it remains missing. Labels written. So the missing exit is still missing. That's a separate issue.

"an operator who changes the exit and restarts twice." First restart: rebuild, labels written new. Second restart: labels match, no rebuild. Good.

T-4 verdict: Seems HOLDS. But wait: `Grind_GeoExitWriteLabels` is called after rebuild success. But what if `Grind_RebuildExitsAtStart` returns true but some exits were not modified because `resting <= 0.0`? In that case, labels are written even though some exits were not fixed. That's a T-1 issue, but also affects T-4: labels are written even though the rebuild didn't actually fix all exits. The threat T-4 says "a label written when a missing exit could not be placed (ADR-156 startup shortfall)". That's different: missing exit has no exit order, so rebuild doesn't see it. But if an exit order exists but cannot be read, rebuild skips it, returns true (if no other failures), and labels are written. Then next tick strict check halts. So labels are written for a side that is not actually consistent. That's a T-1/T-4 combined issue. But the question for T-4 is more about lifecycle. I'd mention that labels are written even if some exits were skipped due to `resting <= 0.0`, which is a T-1 leak.

T-5 One-shot add. We analyzed. The flag is cleared before comparison but only after early returns. So it survives early returns. Can it cause more than one modify? No, because once it reaches the comparison, it clears. But if it early returns, it doesn't clear. So it can survive into later ticks, but it will still only be used once when it finally reaches the comparison. That seems okay. But can it be cleared without the comparison? Yes, if `side.add_pending_ticket == 0`. In that case, it clears the flag, then skips the comparison (since no pending), then tries to send a new add. So the one-shot is consumed without a reprice. That's probably fine because there's no resting add to reprice. But what if there is a resting add that is not selected? The code first handles `side.add_pending_ticket != 0`: if not selected, it may clear the ticket and return? Actually:
```
if(side.add_pending_ticket != 0) {
   if(!Grind_SelectOurOrder(...)) {
      if(Grind_SelectOurPosition(...))
         return;
      side.add_pending_ticket = 0;
   } else {
      ...
   }
}
```
If the order is not selected and not a position, it sets `side.add_pending_ticket = 0` and does NOT return. It continues. So it will eventually clear the flag and may send a new add. The one-shot is used for the new add? Actually the one-shot deadband is only used in the `if(side.add_pending_ticket != 0)` block after clearing. If the ticket was cleared, then `side.add_pending_ticket` is 0, so it skips the comparison and goes to send new add. The one-shot flag has no effect on sending new add. So it's consumed without effect. That's fine.

"interfere with ADR-152's due-flag path or the entry horizon?" If entry horizon active, early return before clearing. So flag survives. Then if entry horizon is active, Grind_EnsureAddNext is called from OnTickEngine? Actually OnTickEngine calls Grind_EnsureAddNext directly. And Grind_ServiceDueAddFlags also calls Grind_EnsureAddNext if entry horizon active. So the flag never clears while entry horizon active. If the operator later turns off entry horizon (restart), the flag is set true again at init. So no interference.

But there is a potential bug: The one-shot flag is set in OnInit after rebuild. If the EA is halted (rebuild failed), the flag is NOT set (because else branch not executed). So if rebuild fails, the one-shot flags remain whatever they were before? They are global variables initialized to false at start? In MQL5, global variables are initialized to 0/false at terminal start. But on reinit (e.g., change settings), they might retain values? In MQL5, when an EA is reinitialized, global variables are reinitialized? Actually in MQL5, global variables are reset on reinitialization? No, global variables are reinitialized when the EA is reloaded? I believe they are reinitialized to their initial values on OnInit? Actually in MQL5, global variables are not reset on reinit; they retain values unless changed. But OnInit sets `g_grind_start_add_reprice_long = true;` only in success branch. If rebuild fails, it doesn't set them. So they could be true from a previous run? But the EA is halted anyway, so OnTick returns early. So no effect.

T-5 verdict: Mostly HOLDS, but note the flag survives early returns. Is that a problem? The branch description says "the first evaluation after init compares the resting add with its target using half a point instead of the deadband, then clears the side's flag." If the first evaluation hits an early return (e.g., entry blocked, cap blocked, no add target), the flag is not cleared. Then on a later tick, when the condition allows, it will use the one-shot. That means it's not strictly the "first evaluation" but the first evaluation that reaches the comparison. That could be considered a bug: the one-shot might be delayed until later, potentially after the market has moved. But the intent is to reprice the resting add at init to the current target. If it's blocked, maybe it's okay to wait. But if it waits too long, the one-shot deadband (0.05 pips) will cause a modify even if the add is far from target. That's fine. I'd say it's a minor NEEDS-FIX or HOLDS? The threat asks "Can the flag be cleared without the comparison (early returns), survive into later ticks, cause more than one modify, or interfere..." We can say it can survive into later ticks due to early returns, but it will still only cause one modify when it finally runs. Not a serious bug. But there is a case where it can cause more than one modify? No.

T-6 we already found the market closed issue. Let's solidify.

In OnInit:
```
Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);
if(!Grind_RebuildExitsAtStart(InpMagic)) {
   g_grind_halted = true;
   g_grind_halt_reason = "REBUILD_EXIT_FAILED";
   Grind_TelemetryCritical(...);
   Grind_CancelOwnEntryOrders(InpMagic, InpSlot);
   Print("CRITICAL: REBUILD_EXIT_FAILED -- halted in place");
}
```
If market is closed, `Grind_ModifyPendingPrice` fails. Rebuild returns false. Halt. The EA will not trade until restarted. Since OnInit only runs on load/reinit, and market being closed doesn't trigger reinit, the EA stays halted when market opens. This is a serious operational risk. The smallest fix: in `Grind_RebuildExitsAtStartSide`, if modify fails, check if market is closed (e.g., `!Grind_CarrySessionReady(_Symbol)` or `SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != FULL`), and if so, return a special code to retry later instead of halting. Or defer the rebuild to OnTick when market is open. But the branch rule says halt on first failed modify. So it's a design flaw.

Also, `Grind_CarryPruneShiftGvs` is called after the halt path. That's fine.

Another T-6: "Grind_RetryMissingExits before the rebuild". If the exit input changed, RetryMissingExits places missing exits at new exit. Then rebuild reprices existing. That's correct order. If reversed, missing exits would be placed at old exit? Actually if rebuild ran first, it would reprice existing to new exit, then RetryMissingExits would place missing at new exit. Both orders work. So okay.

"Grind_CarryPruneShiftGvs after it". If rebuild failed and halted, prune still runs. It may delete shifts for positions that don't exist. That's fine. But if rebuild succeeded and wrote labels, prune runs. It might delete shifts for tickets that were just modified? No, it only deletes if position doesn't exist. The positions exist. So shifts kept. Good.

"a reattach inside the carry window". If OnInit runs during carry window, `Grind_ReconstructState` runs, then rebuild. Then later OnTimer may start carry pass. The carry pass will shift exits for carry. That's expected. But note: the carry pass uses `Grind_CarryExitPassBegin` which calls `Grind_CarryPruneShiftGvs(magic)`. That's after rebuild. So shifts are pruned again. No issue.

T-6 verdict: BREAKS due to market closed halt.

T-7 Tests. We'll list gaps.

Now PREMISE VERDICT. Is the branch safe to merge to main and deploy with unchanged settings; and safe for the first exit change on a live book?

- Safe with unchanged settings? If labels are already present and match, no rebuild. If labels absent (first run after upgrade), `Grind_GeoExitChanged` returns false because no label. So no tolerance, no rebuild. So behavior is same as before. But wait: On first run after upgrade, labels are absent. `Grind_GeoExitChanged` returns false. So `g_grind_rebuild_long/short` false. `Grind_RebuildExitsAtStart` returns true immediately. Then labels are written in OnInit else branch. So the first run writes labels. If the book already has exits at the current exit input, strict recon passes, rebuild no-op, labels written. So safe. If the book has exits at a different exit (e.g., operator changed exit before upgrade), labels absent, so no tolerance, strict recon fails, halt. But that's the old behavior. So with unchanged settings, it's safe.

- Safe for the first exit change on a live book? If operator changes exit input and restarts, labels are present from previous run and differ, so tolerance applies. Reb builds. This should work, except for the T-1 leak (resting <= 0.0) and T-6 market closed. Also the ejected+VL issue? But generally, it's designed for this. The T-1 leak could cause first tick halt if an exit order is unreadable. The T-6 market closed could cause halt if restart during market closed. So not 100% safe. We should say: safe to merge with caution, but the market-closed halt and the `resting <= 0.0` skip are real defects that should be fixed before deployment. Also the test gap.

Let's now craft final answer with sections. Need cite file, function, quote. No line numbers. Be concise but exhaustive enough.

Let's organize:

GIVENS CHECK:
- G1 VERIFIED. quote from Grind_GeoExitChanged and Grind_ReconCheckInvariants.
- G2 VERIFIED. quote from Grind_CheckBookInvariants call.
- G3 VERIFIED. quote from Grind_ReconCheckInvariants.
- G4 VERIFIED. quote from Grind_RebuildExitsAtStartSide and Grind_ReconExitMatchesEntry.
- G5 VERIFIED. quote from OnInit.

T-1: BREAKS. Evidence: `const double resting = Grind_OrderGetPriceOpen(exit_ticket); if(resting <= 0.0) continue;` in Grind_RebuildExitsAtStartSide. If tolerance skipped a mismatch because label differs, and the order cannot be read, rebuild skips it, returns true, labels written, then next tick strict `Grind_CheckBookInvariants` fails. Also mention exit on held rank etc. Smallest fix: return false if resting <= 0.0 (or re-select order), so halt at init instead of first tick.

T-2: HOLDS (mostly). Check branches. Note ejected+VL edge case but I6 consistent. Ejected branch uses Grind_CarryShiftGetForRecon which does not delete for ejected. Quote. So I6 consistent. Maybe mention no issue.

T-3: HOLDS. Partial failure safe because labels not written, next init flags both sides again, already modified exits within 0.5 point so not modified again. Quote from Grind_RebuildExitsAtStartSide: `if(MathAbs(resting - price) > _Point * 0.5)`. Crash mid-rebuild safe because labels old. No stale shift because overwritten. But note: if crash before GV flush, shifts lost, but rebuild recomputes. So HOLDS.

T-4: HOLDS. Labels not deleted by prune. Quote from Grind_CarryPruneShiftGvs prefixes. Labels written after success. Same magic on another terminal separate GVs. But note T-1 leak means labels can be written even if some exits skipped. So maybe NEEDS-FIX? The threat asks "Label lifecycle". I'd say HOLDS with caveat: labels written even if some exits skipped due to T-1, so a label can be written for a side that is not actually consistent. That's a T-1 issue. But lifecycle itself holds.

T-5: HOLDS. One-shot clears before comparison but after early returns. Can survive into later ticks but only modifies once. Quote. No interference with ADR-152 or entry horizon because entry horizon returns before clearing. But note it can be consumed without comparison when no resting add. That's benign.

T-6: BREAKS. Market closed halt. Quote from OnInit: `if(!Grind_RebuildExitsAtStart(InpMagic)) { g_grind_halted = true; ... }` and `Grind_RebuildExitsAtStartSide` returns false on `Grind_ModifyPendingPrice` failure. If market closed, every modify fails, so halt, and EA stays halted when market opens. Smallest fix: check market open before rebuild or don't halt on market-closed failures, retry in OnTick.

Also mention carry pass continues on halt (OnTimer no halt check) as secondary.

T-7: TEST GAPS. List: no test for Grind_ReconstructState setting flags from labels (no seam). No test for OnInit sequence. No test for `resting <= 0.0` skip. No test for ejected with shift. No test for partial failure (long success, short fail). No test for market closed halt. RB12 tests one-shot but not early-return survival. Vacuous? None obvious, but RB10 uses manually constructed layer, not full book. So gaps.

PREMISE VERDICT: Not safe to deploy unchanged? With unchanged settings, safe. For first exit change, unsafe due to T-1 and T-6. Recommend fix T-1 (return false on unreadable resting) and T-6 (defer rebuild if market closed) before merge.

Let's ensure quotes are exact and one line or part of one. We can quote partial lines.

Now write final. Need no preamble. Line count? The instruction says "This message has a line count at the bottom" and at top "Line count: 121". We don't need to output line count? Probably not. The final answer should be sections. We'll just provide the audit.

Let's be careful with file names: grind_engine.mqh, grind_recon.mqh, grind_carry.mqh, fxgrind.mq5, fxgrind_tests_rb.mqh.

Let's write.

## Final Report

## GIVENS CHECK

**G1. VERIFIED.**
`Grind_GeoExitChanged` returns false when no label exists:
`if(!Grind_GeoExitGet(magic, is_long, label)) return false;`
and `Grind_ReconCheckInvariants` only skips a price mismatch when the side flag is true:
`if(tolerate_exit_price_long && !long_exit_filled) continue;`
So no label → no tolerance → strict I6 as before.

**G2. VERIFIED.**
`Grind_CheckBookInvariants` calls:
`Grind_RebuildBookFromTickets(tickets, count, ..., reason, false, g_grind_recon_exit_pips_short);`
The `tolerate_exit_price_long/short` parameters are not passed and default to false.

**G3. VERIFIED.**
The tolerance skip is guarded by `!long_exit_filled`:
`if(tolerate_exit_price_long && !long_exit_filled) continue;`
A filled exit therefore never takes the tolerance path.

**G4. VERIFIED.**
`Grind_RebuildExitsAtStartSide` computes:
`const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, is_long, pos);`
then records the applied residual:
`Grind_CarryRecordShift(pos, price - formula, true);`
I6 in `Grind_ReconExitMatchesEntry` checks the same base plus the stored shift:
`const double expected = Grind_ExitPrice(eff, exit_pips, point, dir) + accrued + eject_offset + shift;`
`Grind_ExitQFormulaTarget` is that base without `shift`, so the post-rebuild price is `formula + shift`.

**G5. VERIFIED.**
In `OnInit`:
`if(!Grind_RebuildExitsAtStart(InpMagic)) { ... } else { Grind_GeoExitWriteLabels(...); }`
Labels are only written in the success branch.

---

## T-1. Tolerance leak — **BREAKS**

The tolerance can let through a resting-exit mismatch that the rebuild then does **not** fix, because the rebuild silently skips an exit whose price cannot be read:

`grind_engine.mqh`, `Grind_RebuildExitsAtStartSide`:
```cpp
const double resting = Grind_OrderGetPriceOpen(exit_ticket);
if(resting <= 0.0)
   continue;
```

Path:
1. Label differs → `tolerate_exit_price_long` is true.
2. `Grind_ReconCheckInvariants` sees a resting exit whose price is off at the new exit and `continue`s.
3. `Grind_RebuildExitsAtStartSide` cannot read that order (`resting <= 0.0`) and skips it.
4. The side returns true, labels are written, init succeeds.
5. On the first tick, `Grind_CheckBookInvariants` runs with no tolerance and halts on the same mismatch.

The same skip also means an exit on a held rank, or an exit whose order ticket is stale but still present in the reconstructed layer, can be left unpriced. The rebuild assumes readability; it does not fail closed on an unreadable exit.

**Smallest fix:** replace the silent `continue` with a hard failure:
```cpp
if(resting <= 0.0)
   return false;
```
so the rebuild halts at init instead of leaving a known-bad exit for the first strict tick.

---

## T-2. Rebuild arithmetic — **HOLDS**

The plain, clamped, rolled-VL, accrued, and ejected-with/without-shift branches all end in a state accepted by `Grind_ReconExitMatchesEntry`.

- Plain / rolled / accrued: `Grind_ExitQFormulaTarget` produces the same base that I6 builds from effective entry, accrued, and eject offset. The recorded shift is `price - formula`, so I6 sees `formula + shift`.
- Clamped: the same shift mechanism is used, and `Grind_CarryRecordShift(..., true)` writes the release marker so `Grind_CarryShiftGetForRecon` will not later delete the clamp residual.
- Ejected without VL: the offset is re-derived from the current resting price:
  ```cpp
  const double raw = Grind_ExitPrice(eff, exit_pips, _Point, dir)
                     + Grind_CarryAccruedGet(pos)
                     + Grind_CarryShiftGetForRecon(pos);
  const double offset = resting - raw;
  Grind_EjectOffsetSet(pos, offset);
  ```
  I6 then checks `ExitPrice + accrued + shift + offset == resting`. `Grind_CarryShiftGetForRecon` does **not** delete a shift for an ejected position:
  ```cpp
  if(Grind_EjectIsEjected(position_ticket))
     return Grind_CarryShiftGet(position_ticket);
  ```
  so the shift used to derive the offset is the same one I6 later reads.

One edge case is ejected + VL: it falls through to the normal branch and keeps the old eject offset. That is consistent with I6 because the offset is carried into `Grind_ExitQFormulaTarget`, so no invariant violation occurs. It may not be the operator’s intended economic repricing, but it does not break I6.

---

## T-3. Partial failure and restart — **HOLDS**

If the long side succeeds and the short side fails, labels are not written (`OnInit` writes labels only in the `else` branch). On the next init the labels are still old, so both sides are flagged again. The long side’s exits are already at the new price, and the rebuild only modifies when outside half a point:

`grind_engine.mqh`, `Grind_RebuildExitsAtStartSide`:
```cpp
if(MathAbs(resting - price) > _Point * 0.5) {
   if(!Grind_ModifyPendingPrice(exit_ticket, price, magic))
      return false;
   repriced++;
}
```

So already-rebuilt exits are not moved a second time in the normal case. A crash mid-rebuild is also recoverable: labels are still old, so the next init flags both sides and finishes the remaining exits. If shifts were lost before a GV flush, the rebuild recomputes them from the current market and overwrites the old shift. No stale shift or offset is left intentionally.

---

## T-4. Label lifecycle — **HOLDS with T-1 caveat**

The label GVs are `GRIND_GEO_EXIT_<magic>_L/_S`. They are not pruned by `Grind_CarryPruneShiftGvs`, which only removes:
```cpp
if(StringFind(name, "GRIND_CARRY_SHIFT_") == 0) { ... }
else if(StringFind(name, GRIND_CARRY_RELEASE_PREFIX) == 0) { ... }
else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) { ... }
```
So labels survive restarts and are not deleted by the cleanup called after the rebuild in `OnInit`.

- Same magic on another terminal: GVs are terminal-local.
- Same magic on another account in the same terminal: blocked by `Grind_MagicLockClaim`.
- Missing exit that could not be placed: the rebuild only visits layers with `exit_order_ticket != 0`, so a missing exit is untouched and the label is still written. That is consistent with the shortfall logic.
- Operator changes exit and restarts twice: first restart rebuilds and writes the new label; second restart sees equal labels and performs no rebuild.

The caveat is T-1: if an existing exit order is unreadable, the rebuild can still return true and labels are written for a side that is not actually consistent. That is the T-1 defect, not a separate label-lifecycle defect.

---

## T-5. One-shot add — **HOLDS**

`Grind_EnsureAddNext` reads and clears the flag after the early guards but before the deadband comparison:

`grind_engine.mqh`, `Grind_EnsureAddNext`:
```cpp
const bool one_shot = is_long ? g_grind_start_add_reprice_long : g_grind_start_add_reprice_short;
if(is_long)
   g_grind_start_add_reprice_long = false;
else
   g_grind_start_add_reprice_short = false;
const double add_deadband = one_shot ? 0.05 : deadband_pips;
```

Consequences:
- If an early return happens before this point (no depth, cap blocked, entries blocked, entry horizon active, add target invalid, marketable check fails), the flag survives into later ticks. That is not unsafe: it will still be consumed at most once when the function finally reaches the comparison.
- It cannot cause more than one modify because it is a bool and is cleared before the modify path.
- It can be consumed without a comparison when `side.add_pending_ticket == 0`; that is benign because there is no resting add to reprice.
- It does not interfere with ADR-152’s due-flag path: the due-flag path calls `Grind_EnsureAddNext` only after the same checks, and when entry horizon is active the function returns before clearing the one-shot flag.

---

## T-6. `OnInit` ordering — **BREAKS**

The critical unsafe path is a reattach while the market is closed. Every `Grind_ModifyPendingPrice` call fails, so `Grind_RebuildExitsAtStartSide` returns false on the first failed modify, and `OnInit` halts:

`fxgrind.mq5`, `OnInit`:
```cpp
if(!Grind_RebuildExitsAtStart(InpMagic)) {
   g_grind_halted = true;
   g_grind_halt_reason = "REBUILD_EXIT_FAILED";
   ...
   Grind_CancelOwnEntryOrders(InpMagic, InpSlot);
   Print("CRITICAL: REBUILD_EXIT_FAILED -- halted in place");
}
```

The EA then stays halted. There is no retry in `OnTick` when the market opens:
```cpp
if(g_grind_halted)
   return;
```
So a restart during the weekend or a broker maintenance window can leave the instance permanently halted until an operator manually reinitializes it. That is unsafe for live deployment.

A secondary issue: `OnTimer` still runs the carry pass even when halted. `Grind_CarryOnTimerStep` does not check `g_grind_halted`, so a halted instance can still shift exit orders during the carry window. That is less severe than the permanent halt, but it is another reason not to leave the halt path as-is.

**Smallest fix:** do not halt on modify failure when the market is not ready. Either skip/defer the rebuild until the market is open, or have `Grind_RebuildExitsAtStart` return a “retry later” status and let `OnTick` finish the rebuild once trading is possible.

---

## T-7. Tests — **GAPS**

The v2.1 behaviours that lack a test that fails without them:

- **No test for `Grind_ReconstructState` setting `g_grind_rebuild_long/short` from the labels.** The given explicitly says this wiring has no broker test seam. `RB11` tests `Grind_GeoExitChanged` and `Grind_GeoExitWriteLabels` in isolation, but nothing verifies that `Grind_ReconstructState` passes those flags into `Grind_RebuildBookFromTickets`.
- **No test for the `OnInit` sequence.** `RB1`–`RB8` call `Grind_RebuildExitsAtStart` directly with manually set flags. They do not exercise `Grind_RetryMissingExits` before the rebuild, the halt path, or label writing after success.
- **No test for the `resting <= 0.0` skip.** There is no fixture where an exit order exists in the layer but `Grind_OrderGetPriceOpen` returns zero. That is the T-1 leak.
- **No test for ejected **with** a nonzero carry shift.** `RB3` tests ejected with no shift. `RB6` tests clamp with shift, but not the ejected branch using `Grind_CarryShiftGetForRecon`.
- **No test for partial failure: long side succeeds, short side fails.** `RB8` fails on the first modify of the only side. There is no test that a long-side success followed by a short-side failure leaves the book recoverable on the next init.
- **No test for the market-closed halt.** The order test seam can simulate `send_ok = false`, but no test distinguishes a transient broker failure from “market closed, retry later.”
- **`RB12` tests the one-shot add but not early-return survival.** It verifies one modify and flag clearing on the normal path, but not that the flag survives an early return such as `Grind_EntryHorizonActive()` or a blocked cap.

No assertion in `fxgrind_tests_rb.mqh` is obviously vacuous inside an `if`. The main weakness is coverage: several v2.1 branches are tested only at the direct-function level, and the integration points called out in the branch description are untested by construction.

---

## PREMISE VERDICT

**With unchanged settings:** safe. Labels absent → `Grind_GeoExitChanged` false → no tolerance, no rebuild; the first successful init then writes labels. Strict I6 behaves as before.

**For the first exit change on a live book:** not safe to deploy as-is without fixing T-1 and T-6. The intended path works for ordinary resting exits, but:
- T-1 can let a mismatched, unreadable exit through init and halt on the first tick.
- T-6 can permanently halt the instance if the exit change is applied while the market is closed.

**Recommendation:** do not merge to `main` for live deployment until:
1. `Grind_RebuildExitsAtStartSide` fails closed on `resting <= 0.0` instead of skipping.
2. `OnInit`/`Grind_RebuildExitsAtStart` can defer or retry a rebuild when the market is not ready, rather than halting permanently.
3. The missing integration tests (label → flags, `OnInit` ordering, ejected-with-shift, partial failure) are added or the wiring is otherwise verified.

<!-- finish_reason=stop -->
