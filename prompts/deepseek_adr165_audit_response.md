# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit. Need be exhaustive. We have no line numbers attached. Need cite file, function, quote one line/part. Need sections GIVENS CHECK G1-G6, T-1..T-8, PREMISE VERDICT, TEST GAPS. Need find lookahead bias etc. We're auditing ADR-165 branch. Need inspect code.

We need reason deeply.

We have code snippets. Need verify givens.

Let's parse key functions.

ADRs and code.

Input: InpLatticeReroll default false. OnInit validates reroll requires lattice before MagicLock? In fxgrind OnInit: after geometry, magic, validate lattice, validate reroll, then `if(!Grind_MagicLockClaim(InpMagic))`. So G2 true: FATAL before MagicLockClaim. Need quote line. `if(!Grind_ValidateRerollInputs(InpVirtualLattice, InpLatticeReroll)) { Print("FATAL: ..."); return INIT_FAILED; }` before `if(!Grind_MagicLockClaim(InpMagic))`. Yes.

G1: With reroll false every path behaves exactly old. Need inspect TrySide. New block: `if(idx < 0) { if(reroll && rerolls >= 1) break; if(!reroll || Grind_LatticeRerollPaused(now)) { Grind_LatticeMaybeStranded(...); break; } ... }`. With reroll false => `if(reroll && rerolls >=1)` false, then `!reroll` true, strand and break. Same as old? Need compare old? According ADR old at 1201-1204 calls MaybeStranded and breaks. Yes. allow_reroll at calls: first rolls pass `is_reroll` (false) as allow_reroll; so false. Roll call: `Grind_LatticeRollLayer(..., roll_source, is_reroll)` and default? Signature has allow_reroll default false; passing false. OnTick passes reroll. If InpLatticeReroll false, false. So G1 true. Need quote. We can quote `if(!reroll || Grind_LatticeRerollPaused(now)) {` and `Grind_LatticeRollLayer(..., is_reroll)`? one line quote enough. Also `const int rc = ... roll_source, is_reroll);`. The final arg false when reroll off. But G1 says allow_reroll false at every call site. There is also first roll call passes is_reroll; if not reroll false. Good. But check other calls? `Grind_LatticeRollLayer` only called in TrySide? Search code: one call. It passes `is_reroll`, not hardcoded false. With reroll off false. Good. `Grind_LatticeOnTick` passes reroll to both. OnTick passes InpLatticeReroll. If input false, false. So yes.

Need maybe issue: new block modifies stranded cleared latch: at top: `if(Grind_LatticeCandidateIndex(side, is_long) >= 0) { clear stranded }`. This existed before? It clears stranded if any unrolled candidate exists. With reroll off, same. But re-roll clear latch on success. Off no difference. Also `rerolls` variable unused maybe. Fine.

G3: allow_reroll true differs only skipping ALREADY_ROLLED and recording from_level; closing refusal still applies. Inspect RollLayer:
- `if(Grind_VLHas(pos)) { if(!allow_reroll) return GRIND_ROLL_ALREADY_ROLLED; from_level = Grind_VLGet(pos); }`
- `if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;`
- exit order select closing check. So closing still applies. Other differences? The detail includes reroll/from_level always but for first roll false/0.0. Also `from_level` used. The code also when allow_reroll true still uses `entry = layer.entry_price` for cost, not effective. Same as first. It uses `Grind_LatticeCountRolled` includes. It calls same. It records detail. It passes `allow_reroll` into detail as `reroll` param. So yes. Need quote closing refusal. `if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;` quote. And `if(!allow_reroll) return GRIND_ROLL_ALREADY_ROLLED;`. Good.

G4: re-roll path sends no market order and opens/closes no position: requests are exit modify and exit queue remove/place. Need inspect RollLayer: if exit_order_ticket !=0 modify; else no modify. Then `Grind_ExitQManageSide` may remove and place. Does it ever close? It can `Grind_ExitQHoldCancelLayer`, which can cancel pending exit. It can detect exit deal position and queue closeby? Wait `Grind_ExitQManageSide`: first for ranks not allowed and exit_order_ticket !=0, calls `Grind_ExitQHoldCancelLayer`. That function if cancel succeeds, no close. If cancel fails and order not selectable, it looks up an exit deal position and if found sets `exit_position_ticket`, queues CloseBy. That is a closeby operation. But is that part of re-roll path? The exit queue manage is called after every roll, including first. T-4/G4 says "its requests are the exit modify and the exit queue's remove/place." But the exit queue's `Grind_ExitQHoldCancelLayer` may queue close-by if an exit order already filled but not processed. That could close a position? However it's existing behavior of exit queue. For a re-roll with a valid resting exit and no closing, likely remove/place. But G4 "The re-roll path sends no market order and opens or closes no position: its requests are the exit modify and the exit queue's remove/place." Need verify if `Grind_ExitQManageSide` in re-roll path can call `Grind_QueueCloseBy`? It could if `Grind_ExitQHoldCancelLayer` called. But that path only when rank not allowed and exit_order_ticket != 0. After a re-roll, maybe the re-rolled layer becomes rank 0, and old rank0 becomes rank? The queue may cancel old rank0, but if its exit order has filled, it detects a deal and queues close-by. That is a closing operation but due to pre-existing fill. Is that a "re-roll path sends no market order and opens or closes no position"? It queues close-by via closeby queue, not market order. The requirement likely means no new position/exposure. But could be considered closes position via close-by. However close-by path is initiated by exit fill, not by re-roll? Actually if exit order filled, the position is already being closed by broker? It queues close by to net. Hm.

Also `Grind_ExitQManageSide` can call `Grind_PlaceLimit` only. No market. `Grind_LatticeRollLayer` calls `Grind_ModifyPendingPrice` only. No open. So G4 likely holds for requests. But if `exit_order_ticket == 0` branch, it doesn't modify; just sets VL and `exit_target`, then `Grind_ExitQManageSide` places exit. No close. Good.

Need check `Grind_ExitQHoldCancelLayer` can `Grind_QueueCloseBy`, but not a request? It queues to later process; OnTick `Grind_ProcessCloseByQueues` may send closeby requests. That could be caused by a re-roll if cancel fails and there is an existing filled exit. But the re-roll path itself doesn't send market order. I'd mark G4 VERIFIED with caveat maybe? The prompt says GIVENS verify. Need be strict. We can quote `if(!Grind_ModifyPendingPrice(...))` and `Grind_ExitQManageSide(side, ...)`. But "requests are modify and remove/place" - in RollLayer if no exit_order_ticket, no modify, only queue place. If exit_order_ticket, modify. Exit queue may cancel/place. It may also queue closeby in unusual path. But no market. Hm.

G5: EffectiveEntry of rolled layer equals VL, so RerollIndex by VL picks highest effective. Code `Grind_EffectiveEntry`: `if(!Grind_VLHas(position_ticket)) return entry; return Grind_VLGet(position_ticket);`. VLSet overwrites. RerollIndex uses `Grind_VLGet`. It chooses highest VL for long. But ties: uses `vl == bv && lower layer_index`. EffectiveEntry equals VL. Need consider if VL exists but 0? VLHas true if GV exists, even if value 0. EffectiveEntry returns 0, not entry. RerollIndex could choose zero. But rolls set level >0. So yes.

But wait T-1 says after a re-roll re-rolled layer has LOWEST effective entry (long), because its VL is new level. RerollIndex picks highest VL, i.e. furthest old level. After reroll to new level, that layer's VL becomes current level, which is the lowest among rolled? Actually existing rolled layers have old levels higher than new level? Suppose market trends down. Long side capped. Initially entries 1.214...1.207, no VL. First rolls occur unrolled highest entry to level computed from anchor. When all rolled, VLs are levels along the way. The highest VL is furthest from market for long? Since price trending down, levels descend: earlier rolls have higher VL, later rolls lower VL near market. RerollIndex picks highest VL = oldest/furthest. It rolls it to current new level (lowest so far). After, its VL = current level, which is lower than all others. Thus it has lowest effective entry. Yes.

G6: LatticeOnTick called only from OnTick not OnTimer. Search code. In fxgrind OnTimer: calls ReplayOnTimer, GvFlush, Snapshot, Archive, SessionStep, telemetry block includes Carry, no LatticeOnTick. OnTick calls Grind_LatticeOnTick. So true. Dead market never re-rolls? OnTick only on ticks; OnTimer doesn't. But TimeCurrent maybe? Yes. Quote.

Now threats.

Need examine T-1: Wrong layer or wrong level. Need find if any path next level stale, same layer rerolled twice in row, layer without resting exit repriced wrongly (`exit_target` only, no modify).

Key logic in `Grind_LatticeTrySide`:
```
for iter:
  if depth < max break;
  const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));
  ...
  int idx = Grind_LatticeCandidateIndex(side, is_long);
  bool is_reroll=false;
  if(idx < 0) {
     if(reroll && rerolls >=1) break;
     if(!reroll || Grind_LatticeRerollPaused(now)) { MaybeStranded; break; }
     idx = Grind_LatticeRerollIndex(side, is_long);
     if(idx < 0) { MaybeStranded; break; }
     is_reroll = true;
  }
  if(side.layers[idx].exit_position_ticket != 0) { NoteClosing; closing_stop=true; break; }
  const string roll_source=...
  rc = RollLayer(..., level, roll_source, is_reroll);
```
If idx <0 and reroll==false: MaybeStranded and break. If reroll true and no rolled layer: MaybeStranded and break. If reroll true and already rerolls>=1: break (throttle). Wait this throttle check is before pause. If a first roll happened in same call, rerolls? No, rerolls counts only is_reroll. If reroll and rerolls>=1, break. Good at most one re-roll per call. But what about first rolls unlimited? If `rerolls` remains 0, first rolls can continue. If after a first roll, next iteration idx maybe >=0 (unrolled) so it does first roll, no throttle. If after a re-roll, rerolls=1, next iteration if idx<0, break. If idx>=0 (unrolled candidate exists), it continues first rolls even after a re-roll? The rule says at most ONE re-roll per side per call, first rolls unlimited. So yes it could do first rolls after re-roll. But wait if it does a re-roll when idx<0, then after roll, there remains no unrolled layer? Actually all rolled, so next iteration idx<0 and breaks. If there were unrolled layers but CandidateIndex returned <0 impossible. Unless after re-roll? No new unrolled. So fine.

Potential T-1 issue: The loop recomputes level each iteration from `Grind_ComputeAddTarget`. After re-roll, the re-rolled layer's VL is set to current `level`. `Grind_ComputeAddTarget` anchors on lowest effective entry among all layers if any_vl. For long, lowest effective entry is the newly re-rolled layer's VL = current level. Next iteration level = anchor - add = current level - add. Good. It steps down by add. If same layer re-rolled twice in row? It is now highest? RerollIndex picks highest VL. After re-roll, its VL = lowest, so won't be picked again until all others have been rerolled to lower? Actually if it continues within same call? Throttle prevents second re-roll in same call. Next call, if market still crossed next level, RerollIndex picks highest VL among rolled. The re-rolled layer has lowest VL, so not chosen; another layer chosen. So no same layer twice in row unless there is only one rolled layer? But at cap all 8 rolled? Could be depth < max? The reroll only when all rolled (idx<0) and at cap. At cap max_layers maybe 8. If there are fewer than max? TrySide only called if depth >= max. So all 8. So multiple rolled. Unless some layers closing, but candidate includes closing? RerollIndex does not skip closing. It could pick a closing layer if it has highest VL. Then closing check stops loop. Good.

But what about "a layer without a resting exit (the exit queue holds only two) is re-priced wrongly (`exit_target` only, no modify)." In `Grind_LatticeRollLayer`, if `layer.exit_order_ticket == 0`, it sets VL, deletes offset, deletes shift, `side.layers[idx].exit_target = formula`, then calls ExitQManageSide. The exit queue may place it if rank required. But if not rank required? It may not place. Is that wrong? ADR-162 R3 says "modifies the resting exit (or, with none resting, only re-prices the target for the queue)". For a re-roll, if the selected layer has no resting exit (because exit queue only keeps rank 0 and highest), it will not be modified but `exit_target` updated. But if it's not required by exit queue, the exit target is stored. Later queue may place. Is that okay? T-1 says any path where a layer without resting exit is re-priced wrongly (`exit_target` only, no modify). Is it wrong? The design says if none resting, only re-prices target for queue. So likely okay. But the threat asks to find. Need inspect `Grind_ExitQManageSide` ranks. It uses effective entries. After re-roll, the re-rolled layer's effective entry becomes new level (lowest for long), so it becomes rank 0. The old rank0 becomes something else; highest rank resting. So the re-rolled layer will be rank 0 and will get an exit placed if none. Wait if it had no exit_order_ticket, after RollLayer sets exit_target, then ExitQManageSide sees rank 0 required, no exit_order_ticket, places limit. So it will place. If it had an exit_order_ticket, it modified. So no "only target" unless slot limit prevents placing? `Grind_SlotExitAllowed` may block. But then later manage. So fine.

Potential T-1 issue: `Grind_LatticeRerollIndex` picks highest VL, but T-1's stated "After a re-roll the re-rolled layer has the LOWEST effective entry (long), so the next level steps down by add." Need verify in code. It sets `Grind_VLSet(pos, level)` where `level` is current level. Then next loop computes level from `Grind_ComputeAddTarget` which uses any_vl anchor lowest effective. Yes.

But there's a subtle bug: `Grind_LatticeRerollIndex` uses VL, but if a rolled layer was ejected (has eject offset), its effective entry is VL, but its exit may be at market. Rerolling it? ADR-155? T-5.

Also T-1 mentions "Any path where the next level is computed from a stale value". In loop, `level` recomputed each iteration from side, so not stale. But `Grind_ComputeAddTarget` uses `side.layers[0].entry_price` and loops. After re-roll, `side.layers[idx].exit_target` updated, but effective entry via VL updated. Good.

But: `Grind_LatticeCandidateIndex` uses `side.layers[i].entry_price` for unrolled layers, not effective entry. Unrolled have no VL so entry=effective. Fine.

Potential bug: In `Grind_LatticeTrySide`, at top clears stranded latch if `Grind_LatticeCandidateIndex >= 0`. With reroll on, if all rolled, CandidateIndex -1, so latch may remain set from previous episode. But on successful re-roll, it clears. If pause prevents reroll and MaybeStranded warns, latch set. After pause ends, re-roll success clears. Good.

T-2: Loop control. Need examine throttle break, closing break, backoff break, rolled_count, closing_stop / ResetClosingState after loop. Any path re-roll leaves closing state wrong, or throttle hides needed ROLL_STRANDED.

Potential issue: The throttle `if(reroll && rerolls >= 1) break;` occurs before pause and before MaybeStranded. Suppose within a single call, first roll(s) occurred, then all remaining rolled? Actually if a re-roll happened (rerolls=1), and next level crossed, idx<0 -> break without MaybeStranded. That's intended at most one re-roll; remaining backlog next tick. But if after that break, the side might be at cap, market crossed next level, all rolled. It doesn't warn ROLL_STRANDED on that call. Next tick will attempt next re-roll. If pause? If paused next tick, it will warn. But if there's a persistent reason cannot reroll? The throttle only breaks if one reroll already happened in this call. So not hiding persistent failure; next call handles. Good.

Closing break: after re-roll success? If the re-rolled layer's exit_position_ticket !=0, code checks before roll. If closing after roll? RollLayer can return GRIND_ROLL_CLOSING if `layer.exit_position_ticket !=0` or exit order unselectable. Then TrySide `if(rc != GRIND_ROLL_OK) { if(rc == GRIND_ROLL_CLOSING) { NoteClosing; closing_stop=true; } break; }`. Good. Then after loop if !closing_stop ResetClosingState. If closing_stop true, does not reset. Good.

But for re-roll path, if `idx` candidate is a closing layer with exit_position_ticket !=0, TrySide catches before roll. If exit_order_ticket !=0 but unselectable, RollLayer returns GRIND_ROLL_CLOSING. Good.

Could a re-roll leave `g_grind_vl_closing_ticket_long` set incorrectly? If a previous closing candidate was noted, then next call re-roll success? Suppose closing_stop true, not reset. Later layer closes, depth drops below cap. On next call maybe TrySide not called (depth < max). ResetClosingState only called in TrySide when not closing_stop. But `Grind_LatticeTrackOneSide` when depth < max resets `g_grind_vl_closing_ticket_long=0` etc. So okay.

`rolled_count` counts both first rolls and re-rolls. Return value used only tests? In OnTick ignored. Fine.

Potential issue: `closing_stop` and `Grind_LatticeResetClosingState` after loop: If re-roll succeeds and then next iteration throttle breaks, `closing_stop` false, so ResetClosingState called. That's fine.

T-3: Stranded latch. Cleared on successful re-roll. With reroll on, side can stay at cap for days. Is latch ever left set so later real failure never warns? Is it cleared anywhere it should not be?

Latch `g_grind_vl_stranded_warned_long/short`. Set true in MaybeStranded. Cleared:
- in `Grind_LatticeTrackOneSide` when depth < max (all closing) -> resets.
- in `Grind_LatticeResetBackoff` (init? maybe).
- at top of TrySide: if `Grind_LatticeCandidateIndex(side, is_long) >= 0` clear. That means if there is any unrolled layer, clear. This is existing ADR-162: if a first roll candidate exists, not stranded. It clears even if the candidate is not rolled due to level not crossed? Wait at top before loop: if CandidateIndex >=0, clear latch unconditionally. So if an unrolled layer appears (e.g., new add filled? But at cap, new add not filled; depth decreases then increases? Actually when an exit fills, depth drops below cap, then new add may fill, depth returns to cap. During below cap, tracking resets latch. When back at cap with some unrolled layer, top clears latch. So fine.
- On successful re-roll: `if(is_reroll) { rerolls++; clear stranded; }`.

Potential bug: The latch is cleared on successful re-roll, but if re-roll fails (modify fails) or pause, MaybeStranded will warn once. But once warned, later real failure (every layer closing, modify failing, pause) may not warn because latch remains set? The ADR says reset when a re-roll succeeds so later failure warns afresh. If no successful re-roll, warning already issued. The threat: "With re-roll on, a side can stay at cap for days. Is the latch ever left set so that a later real failure (every layer closing, modify failing, the pause) never warns?" Suppose side at cap all rolled. A re-roll succeeds, clears latch. Then later modify fails repeatedly: first fail backoff, no MaybeStranded? Actually on modify fail, code breaks without MaybeStranded. The latch is false. On subsequent ticks while backoff, TrySide returns 0 at `if(now < backoff) return 0;` before MaybeStranded, so no warning. After backoff, if still all rolled and level crossed, it tries re-roll again; if modify fails again, breaks no MaybeStranded. So `ROLL_STRANDED` may never warn for repeated modify failures! But ADR says keep ROLL_STRANDED as failure signal (re-rolls failing / paused). The code on modify failure emits `ROLL_REFUSED` (via RollLayer) but not `ROLL_STRANDED`. Is that intended? R5 says modify failure backs off; a closing layer feeds ROLL_CLOSING_STUCK. For first rolls, modify failure also no ROLL_STRANDED; it breaks with ROLL_REFUSED. So maybe failure signal is ROLL_REFUSED not ROLL_STRANDED. The ruling GR-5 says keep ROLL_STRANDED as failure signal (every layer closing, or re-rolls failing / paused). Here re-rolls failing do NOT emit ROLL_STRANDED. But that's same as first roll? The ADR says "GR-5 ACCEPTED: keep ROLL_STRANDED as the failure signal (every layer closing, or re-rolls failing / paused)." The implementation only emits ROLL_STRANDED when no candidate and pause/no roll, or no rolled index. On modify fail, it emits ROLL_REFUSED and breaks. So GR-5 not satisfied? But G3 says allow_reroll differs only skip. T-6 failures. Need evaluate.

Also "Is it cleared anywhere it should not be?" At top of TrySide clears if any unrolled candidate. That is existing. Could clear latch even if market not crossed? The latch was set because all rolled and market 2 add steps past level. Later a new unrolled layer appears? How? If a layer closes, depth < max, tracking resets anyway. If depth stays max? A layer could be unrolled if a new position opened without depth dropping? At cap, add logic doesn't add because depth cap. A layer could be unrolled if a roll failed? No. So probably fine.

Smallest test for T-3: Arrange all rolled, reroll on. First trigger pause or no reroll? Maybe test latch clear: set `g_grind_vl_stranded_warned_long=true`, perform successful re-roll, then make next level crossed with no candidate and pause/no reroll, assert ROLL_STRANDED appears again. Existing RR tests reset archive. But no test covers clear? Actually RR4m asserts no ROLL_STRANDED, not clear. RR7c pause warns. But does it start with latch set? Adr165_Fixture calls Adr162b_SeedLong8 which Adr162b_Reset resets `Grind_LatticeResetBackoff` clearing latch. So no. Need smallest test: set stranded latch true, call successful re-roll, assert latch false, then simulate pause and assert ROLL_STRANDED present.

T-4 pause and server time. `Grind_LatticeRerollPaused` uses `MqlDateTime t; TimeToStruct(server_now, t); const int m = t.hour*60+t.min; return (m >= 23*60+50) || (m < 15);` So pause 23:50 through 00:14:59. Server time. `now` passed from `TimeCurrent()` in OnTick. `Grind_LatticeTrySide` receives `now`. `Grind_LatticeRerollPaused(now)`.

T-4 says IC server UTC+3 summer, Sunday open ~00:00-00:05 server Monday inside pause. Weekend gap strands capped side until 00:15 and may warn ROLL_STRANDED; one re-roll per tick then works backlog. Hazard? Let's think.

At Sunday open, market gaps. Side capped all rolled. On first tick after open, `now` maybe 00:00 server Monday. Pause returns true. If level crossed, idx<0, `if(!reroll || Paused)` true, calls MaybeStranded. MaybeStranded checks if market crossed `level` plus (GRIND_VL_STRANDED_STEPS -1)*add = level + add? Wait level is next level. It computes stranded_level = AddTargetPrice(level, (2-1)*add, is_long? direction). For long, `Grind_AddTargetPrice(level, add, point, 1)` = level - add. Hmm need check: `Grind_AddTargetPrice(anchor, add_pips, point, direction)` returns anchor - direction * pips. For long direction=1, returns anchor - add. Wait in ComputeAddTarget: `Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1)`. For long, anchor - add (lower). For short, anchor + add. So AddTargetPrice with direction 1 subtracts. In MaybeStranded: `Grind_AddTargetPrice(level, (STEPS-1)*add, point, is_long ?1:-1)`. For long, stranded_level = level - add. But level is already lowest effective entry - add. So stranded_level = lowest effective - 2*add. The market must be 2 add steps past the level? ADR says warns at 2 add steps past the level. Wait level = next level (lowest effective - add). 2 steps past the level would be level - 2*add? Maybe they define "past the level" as beyond by one more add? Actually `GRIND_VL_STRANDED_STEPS=2`. Code uses (STEPS-1)*add = 1*add, so stranded_level = level - add = lowest effective - 2*add. So market must cross lowest effective - 2*add. That's 2 add steps below lowest effective, i.e. one add step past next level. ADR text says "2 add steps past the level" maybe. Anyway.

At pause, on Sunday open gap, market may cross stranded_level, so MaybeStranded warns once. Then from 00:00 to 00:15, each tick pause, no re-roll, latch set so no repeated warns. At 00:15, re-roll resumes. The first tick after 00:15, `now` >= 00:15, not paused, idx<0, reroll true, rerolls 0, get RerollIndex, roll. Throttle one per call. Next tick another. Backlog of levels? The loop would normally roll multiple levels in one call for first rolls, but throttle one re-roll per call. So if gap through many levels, it takes many ticks. That's intended. Hazard: `Grind_LatticeMaybeStranded` at pause sets latch. At 00:15, re-roll success clears. Fine.

Potential hazard: A quote stamped before 23:50 arriving after it. `TimeCurrent()` is last quote's server time, not wall clock. If a tick arrives after 23:50 but its `TimeCurrent()` is stale before 23:50, pause check uses stale time, so it may allow a re-roll during the carry window. Conversely a tick stamped 23:49:59 but arriving 23:50:00? `TimeCurrent()` returns last quote time, so if broker delays, it may not pause. The ADR says pause server time. This is known. Hazard: during carry pass, re-roll may conflict. But T-4 asks "Any hazard in that, or in a quote stamped before 23:50 arriving after it?" We should note ASSUMED: TimeCurrent is last quote time; a stale tick can bypass pause. Smallest fix? Use TimeTradeServer() or TimeCurrent? ADR says server clock, `TimeCurrent()` is last quote server time. They explicitly set `now = TimeCurrent()` in OnTick. If no new quote exactly, pause window may be missed. The carry pass uses `TimeTradeServer()` in OnTimer: `const datetime carry_now = TimeTradeServer();`. So the re-roll pause uses quote time while carry uses trade server. Mismatch. A re-roll can occur during carry pass if last quote before 23:50 but timer at 23:55. But OnTick only on ticks; if a tick arrives at 23:50 with quote time 23:49:59, it will not pause. This is a real hazard: re-roll during carry window, both modify same exits. ADR says pause to avoid. Smallest fix: pass `TimeTradeServer()` or use `MathMax(TimeCurrent(), TimeTradeServer())`? But ADR says server time. `TimeTradeServer()` is server time independent of quote. Better. However ruling GR-4 says pause 23:50-00:15 SERVER time. `TimeCurrent()` is last quote server time, not necessarily current server time. The prompt asks "or in a quote stamped before 23:50 arriving after it?" So we should mark T-4 BREAKS/NEEDS-FIX? Let's assess.

T-4 includes assumed weekend gap. The hazard: a quote stamped before 23:50 arriving after it can bypass pause. This is plausible. Is it a break? The pause is not guaranteed. But does it cause harm? Carry pass window is 23:50-00:00? `Grind_CarryGateInWindow`: `return (dt.hour == 23 && dt.min >= 50);` So carry pass only 23:50-23:59:59 server time. If re-roll occurs at 23:50+ with stale quote time 23:49, it could conflict. The code uses `now` for both pause and backoff. OnTimer carry uses TimeTradeServer. So yes, a re-roll could run concurrently. But re-roll only on ticks. If there is a tick at 23:50, TimeCurrent is the tick's time, so it would be 23:50 if quote is current. If quote is delayed (e.g., last quote 23:49:59 but tick event delivered at 23:50:00), then TimeCurrent returns 23:49:59. MT5 `TimeCurrent()` returns last known server time by last quote. If the incoming tick itself has time 23:50:00, then TimeCurrent becomes 23:50. If the event is triggered by something else? OnTick only on new tick, so the tick time is current. A quote stamped before 23:50 arriving after it would itself have time before 23:50, so OnTick would process at that stale quote time. But then the carry pass on timer might have already run at 23:50. The re-roll would be on a stale quote? Actually if the tick's time is before 23:50, it's not after 23:50. So "arriving after it" means event delivered after wall clock but stamp before. `TimeCurrent()` returns stamp, so pause check false. This can happen due to network delay. Then re-roll during carry window. Yes.

But is that a threat? The ADR says pause window is to avoid nightly carry pass. If bypassed, both may modify same exit. The carry pass uses `current_exit` and modifies; re-roll modifies. Could cause duplicate modifies, or race. MT5 single-threaded EA, OnTick and OnTimer not concurrent (same thread). So no true concurrency. But order: OnTimer may run carry pass step; OnTick may run re-roll. They are serialized. If re-roll runs after carry, it overwrites exit to new formula, and carry shift maybe. The carry pass might have recorded accrued. Could be messed. But not catastrophic? T-4 likely NEEDS-FIX: use `TimeTradeServer()` for pause, or at least `MathMax(TimeCurrent(), TimeTradeServer())`. But the ADR explicitly says `now = TimeCurrent()`. The prompt says "The pause and server time. TimeCurrent() is the last quote's server time... Any hazard..." So expected answer: yes, stale quote can bypass pause. Smallest fix: pass `TimeTradeServer()` instead of `TimeCurrent()` in `Grind_LatticeOnTick` or compute pause from both. However if no ticks, OnTick doesn't run anyway. But OnTimer doesn't call lattice. So re-roll only on tick. If a tick arrives at 23:55 with time 23:55, pause works. If a tick arrives with time 23:49:59, it's not in pause. That tick itself is before pause, so maybe okay? The issue is a tick event at wall 23:55 but stamp 23:49. This is possible if market quiet, but on FX at 23:50 there are ticks. Probably rare. Still.

T-5 Interactions. Nightly carry pass re-prices rolled exits from VL. I6 (`Grind_ReconExitMatchesEntry` from VL). Restart/reconstruction (VL GVs persist; ADR-163 rebuild). ADR-155 commanded eject (validates most underwater by effective entry). ROLL_CLOSING_STUCK, breaker and quarantine (`blocked` returns early). Any broken by a VL overwritten again and again?

Need inspect these functions.

- Carry pass: `Grind_CarryExitPassBegin` uses `Grind_EffectiveEntry(layer.entry_price, layer.position_ticket)` and `Grind_EjectOffsetGet`. It captures formula at pass begin. Then `Grind_CarryExitShiftLayer` computes `formula_exit` passed from `Grind_CarryWorkBase(idx,...)` which recomputes from `Grind_EffectiveEntry` and `Grind_EjectOffsetGet`. So if VL overwritten between PassBegin and shift, it uses current VL. Good. `Grind_CarryCurrentExitTicket` uses current exit. The accrued swap GV is kept. Re-roll keeps accrual. So carry pass should price from new VL. But if a re-roll happens during carry pass, it overwrites VL and modifies exit. The carry pass later may shift the same exit again. It uses current VL. It may double-apply swap? `Grind_CarryAccruedSet` commits accrued. Re-roll uses `Grind_CarryAccruedGet` in formula and keeps it. Carry pass computes accrued again and sets `Grind_CarryAccruedSet(position_ticket, accrued_price)`. Wait `Grind_CarryAccruedSet` sets absolute accrued price? Let's see: in `Grind_CarryExitShiftLayer`, `const double accrued_price = theoretical - formula_exit;` Then `Grind_CarryAccruedSet(position_ticket, accrued_price);` So it overwrites with current swap price, not accumulates? Maybe. Re-roll formula uses `Grind_CarryAccruedGet(pos)` and adds. If carry pass runs after re-roll, it will set accrued based on current formula (which includes new VL). Then modify exit to `formula + accrued`. That's okay. But if re-roll runs after carry pass, it uses accrued from carry. Fine.

- I6 `Grind_ReconExitMatchesEntry`: Need inspect? Not in provided code? Search: only called in tests. Not in provided. We can infer it uses effective entry. ADR says I6 from VL. Probably okay.

- Restart/reconstruction: VL GVs persist. `Grind_VLSet` overwrites. On restart, VL persists. `Grind_RebuildBookFromTickets` probably uses VL to compute exit target. ADR-163. A re-rolled layer's VL is the new level. Restart rebuild should compute same exit. Tests LB30. Fine.

- ADR-155 commanded eject: `Grind_EjectPollCommand` validates most underwater by effective entry. It computes ranks via `Grind_ExitQRanks` using `Grind_EffectiveEntry`. After re-roll, the re-rolled layer has lowest effective entry (long), so it becomes rank 0 (nearest). The most underwater by effective entry for long is highest effective entry (furthest above market), which would be an older unrolled or rolled layer. `Grind_ExitQRanks` probably ranks by distance. ADR-155 validates rank == depth-1 (deepest/most underwater). After re-roll, the re-rolled layer is rank 0, so not ejectable. The most underwater is some other layer. So safe. But if a layer's VL is overwritten repeatedly, its effective entry changes. Could the same layer become most underwater again? For long, re-roll sets VL to current level (lowest so far). It rotates to nearest. Over time, as price trends down, all layers get re-rolled in order, each getting the new lower level. The layer re-rolled first gets new level at that time; later another layer gets even lower level. Eventually all layers have VLs at various levels. The one with highest VL (furthest above market) is most underwater. It will be the next re-roll candidate. So commanded eject would target it. If operator commands eject, it ejects the most underwater layer, which is also the next re-roll candidate. Is that safe? Yes, it closes it. But then depth drops below cap, side recovers. Re-roll might also try to re-roll it if not ejected? But eject modifies exit to market and sets eject offset. Then re-roll? `Grind_LatticeRerollIndex` does not skip ejected layers. It picks highest VL. If operator commanded eject on that layer, its exit is now at market (target price) and `Grind_EjectOffset` set. The layer's VL still exists. A re-roll could pick it and re-price its exit back to `level + exit + accrued`, deleting eject offset. That would undo the commanded eject! This is a potential T-5 hazard. Let's examine.

ADR-155 commanded eject: `Grind_EjectAcceptLayer` modifies the exit to `Grind_EjectTargetPrice(is_long)` (near market), sets `Grind_EjectOffsetSet(position_ticket, offset)`, deletes carry shift, sets `exit_target = target`. It does NOT delete VL. The layer remains with a VL. If the side is at cap and all rolled, and market crosses next level, `Grind_LatticeRerollIndex` picks highest VL. The ejected layer likely has the highest VL (most underwater). Then `Grind_LatticeRollLayer` with allow_reroll true will:
- see VL has, from_level = old VL
- exit_position_ticket == 0
- exit_order_ticket != 0 and selectable (the ejected exit order)
- compute formula = level + exit + accrued
- modify pending price to formula (moving exit away from market!)
- `Grind_VLSet(pos, level)`
- `Grind_EjectOffsetDelete(pos)` -> deletes eject offset
- clears shift
So it cancels/undoes the commanded eject. That seems broken. ADR-165 s9 says "His line that a commanded eject then targets 'the most recently re-rolled (furthest)' layer is wrong: after a re-roll that layer is the NEAREST; ADR-155 still takes the most underwater by effective entry, so it is safe." They considered eject after re-roll. But not re-roll after eject. The threat T-5 explicitly: "ADR-155 commanded eject (validates the most underwater by effective entry), ... Any of them broken by a VL that is overwritten again and again?" This is likely the key bug: re-roll can undo a commanded eject because it doesn't skip ejected layers. Let's verify code: `Grind_LatticeRerollIndex` only checks `Grind_VLHas`, not `Grind_EjectIsEjected`. `Grind_LatticeRollLayer` does `const bool was_ejected = Grind_EjectIsEjected(pos);` but then proceeds to modify, VLSet, `Grind_EjectOffsetDelete(pos)`. So yes, it re-rolls an ejected layer and deletes the eject offset. The first-roll candidate `Grind_LatticeCandidateIndex` also skips only `Grind_VLHas`, not ejected. ADR-162 first roll could also pick an ejected unrolled layer? Actually eject requires rank depth-1 (most underwater). If unrolled, effective entry = entry. If ejected, its exit is near market but its entry remains original. Could it be the highest entry unrolled? Yes. ADR-162 first roll might re-roll an ejected layer too. But maybe ADR-155 eject is on the most underwater layer, which is likely the highest entry unrolled or highest VL rolled. First-roll candidate picks highest entry among unrolled. If that layer was ejected, it has no VL, so it could be picked. The code `Grind_LatticeRollLayer` deletes eject offset for any roll, including first. So this bug may predate ADR-165. But T-5 asks interactions with ADR-155. The new re-roll makes it more likely because with reroll on, the side never strands; an ejected rolled layer remains in the pool and can be re-rolled. Actually if all rolled and one is ejected, the side might still be at cap. The next level crossing will trigger re-roll and pick the highest VL, which is likely the ejected layer. So the re-roll undoes the eject. That is a serious flaw. Is there any guard? `Grind_LatticeRollLayer` checks `was_ejected` only records detail. No skip. The ADR s9 says "ADR-155 still takes the most underwater by effective entry, so it is safe" but that's about eject after re-roll, not re-roll after eject. So T-5 BREAKS. Smallest fix: skip ejected layers in `Grind_LatticeRerollIndex` (and maybe `Grind_LatticeCandidateIndex`?) or in `Grind_LatticeRollLayer` refuse if `Grind_EjectIsEjected(pos)` when allow_reroll? But ADR-162 first roll also might need? The threat is T-5. For reroll, add `if(Grind_EjectIsEjected(ticket)) continue;` in `Grind_LatticeRerollIndex`. That prevents re-roll undoing eject. But what if all rolled layers are ejected? Then idx<0 -> strand? Maybe that's correct: an ejected side is already being worked down. But if all ejected, no reroll candidate, it would strand and warn. Could be acceptable. Alternatively, in `Grind_LatticeRollLayer` with allow_reroll true, if `Grind_EjectIsEjected(pos)` return GRIND_ROLL_CLOSING? No. Better skip.

Need check if ejected layer's exit_order_ticket is still selectable? `Grind_EjectAcceptLayer` modifies existing exit order. So yes. The re-roll would modify it. This is a real bug.

Also ADR-155 commanded eject might be disabled on IC fleets? Deployment: lattice on, auto-eject off; but commanded eject maybe off? InpEnableCommandedEject default false. On IC fleets maybe not used? The ADR says not on FTMO; on IC demo fleets only (lattice on, auto-eject off). Commanded eject could be off. But the threat asks interactions. We should mark BREAKS/NEEDS-FIX.

- ROLL_CLOSING_STUCK: If a re-roll candidate is closing, TrySide notes closing and breaks. `Grind_LatticeNoteClosing` warns after 60s. Then `closing_stop=true` so `Grind_LatticeResetClosingState` not called. Good. But what if a re-roll succeeds on another layer while a different layer is closing? The loop breaks on closing candidate only if the candidate chosen is closing. The re-roll candidate is chosen by highest VL. If a different layer is closing but not the highest VL, the loop may re-roll the highest VL and continue. Next iteration, level recomputed. If the closing layer is not the candidate (idx from RerollIndex may still pick highest VL, not closing), it might skip? Actually RerollIndex doesn't skip closing. If the closing layer has highest VL, it will be picked and stop. If a lower-VL layer is closing, it won't be picked until it becomes highest. But the side is at cap; a closing layer's exit has filled, so depth will drop when deal processed. The loop may re-roll other layers while one is closing. Is that okay? Possibly. But `Grind_LatticeNoteClosing` is only called for the candidate. If a non-candidate is closing, no note. But the exit queue may handle. Not a new issue.

- Breaker and quarantine: `Grind_LatticeOnTick` returns early if `blocked` (g_grind_halted || g_grind_quarantined). In OnTick, it calls `Grind_LatticeOnTick(... blocked ...)` before `if(g_grind_halted) return;`. So if blocked, LatticeOnTick returns after tracking extremes? It does `if(!enabled) return; Grind_LatticeTrackExtremes(...); if(blocked) return;`. So no re-roll when halted/quarantined. That's correct: blocked returns early. T-5 says breaker and quarantine (`blocked` returns early). Any broken? Probably holds.

- `Grind_LatticeTrackExtremes` runs even when blocked. It may update extremes. No re-roll. Fine.

T-6 Failures. A modify failure on a re-roll: backoff, fail count, VL not overwritten, rerolls not counted. Code: `Grind_LatticeRollLayer` modify fail returns `GRIND_ROLL_MODIFY_FAILED` before `Grind_VLSet`. TrySide handles rc: increments fail count, sets backoff, break. `is_reroll` not counted because count after success. Good. A `GRIND_ROLL_CLOSING` return from the roll itself (exit position appears between check and roll). Code: `if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;` then if exit order unselectable return closing. TrySide handles rc != OK: if closing, NoteClosing, closing_stop=true; break. Same as first roll. But is there any rc not handled same? `GRIND_ROLL_ALREADY_ROLLED` can only happen if allow_reroll false and VL has. For re-roll allow true. For first roll allow false; if candidate has no VL, won't happen. Could happen if race? Not. `GRIND_ROLL_MODIFY_FAILED` same. `GRIND_ROLL_OK` same. So T-6 holds? Need check modify failure on re-roll: does it leave `from_level`? No report? It emits `ROLL_REFUSED` with `"source":"reroll"`? The refused detail includes `source`. It does not include `reroll` flag. But okay.

Potential issue: On modify failure, `g_grind_vl_fail_count_long++` and backoff. But the re-roll candidate remains. On next tick after backoff, it will retry. `rerolls` not counted. Good.

T-7 Cost. Requests per re-roll: modify plus exit queue remove/place. At most one re-roll per side per tick, eleven instances. Worst plausible day against 2,000 requests/day budget. Burst at 00:15 after pause.

Need calculate. Each re-roll: 1 modify (if resting exit) + exit queue remove/place (2) = 3 requests. Could be more if no resting exit? Then 0 modify + place? Exit queue may place one (1) and remove others? Actually after re-roll, ExitQManageSide may cancel old rank0 and place new rank0, and also maybe place highest? It maintains two. In RR4, modify_calls=1 remove=1 place=1. If no exit_order_ticket, modify=0, remove maybe 1, place 1. So ~2-3. Max one re-roll per side per call, two sides per tick, so up to 6 requests per tick per instance. Eleven instances = 66 requests per tick. A tick can be many per second. But throttle per side per call, not per second. On each tick, each side can re-roll once. In a fast market, many ticks per second, so could do many re-rolls quickly. But each re-roll moves one layer to next level; the market must cross next level again for another re-roll. In a gap through many levels, it will re-roll once per tick per side, so if ticks are frequent, it can clear backlog quickly. Worst plausible day: continuous trend with retraces? The ADR says one per side per call. At 11 instances, 2 sides, 3 requests = 66 per tick. If 100 ticks in a minute? 6600 requests/min, exceeding 2000/day. But realistically, each re-roll moves the layer to a lower level, so the next level is one add step away. If market moves one add step per tick, one re-roll per tick per side. Add step maybe 10 pips. FX can move 10 pips in seconds. So burst possible. The 2,000/day budget per account is small. This is a known concern GR-3. They ruled throttle one per call. But "per call" of `Grind_LatticeTrySide` which is once per tick per side. So in a fast moving market, many ticks per second, each can re-roll. That could churn requests. The ADR says "a gap through three levels -> three re-rolls over three calls". But if ticks are frequent, three calls can be within one second. The 2,000/day budget: 11 instances each with own budget? The prompt says "2,000-requests-a-day budget per account". Each account slot? Actually eleven instances per terminal, one symbol/magic each. They share the account. The API budget is per account (terminal?). So 11 instances x requests. Each re-roll 3 requests. 2000/day / 3 = 666 re-rolls/day across all instances. That's ~60 per instance per day. A trend day could easily exceed. But the breaker/account? The API counter stops entries at 1900 but rolls/exit queue modifies are not entries? `Grind_ApiCounterEntryStopped` only entries? The counter maybe counts all. Need check `grind_api_counter.mqh` not provided. The ADR says budget 2,000-a-day per account. T-7 asks "the worst plausible day against a 2,000-requests-a-day budget per account, and the burst at 00:15 after a pause." We can note risk: at most one re-roll per side per tick, but no per-day or per-minute cap on re-rolls; a fast trend with 8 layers and repeated rotations can generate 3 requests per re-roll. 11 instances * 2 sides * 3 requests = 66 per tick. If 30 ticks/min, ~2000/min. This can blow budget. The existing breaker may block entries but not rolls? `Grind_LatticeTrySide` is called before breaker? In OnTick, `Grind_LatticeOnTick` is called before `Grind_BreakerOnTick`? Let's see OnTick order:
```
Grind_ProcessCloseByQueues
if(!halted) { ... quarantine ... }
Grind_EjectPollCommand
Grind_AutoEjectOnTick
Grind_LatticeOnTick(..., blocked, ...)
Grind_SessionStep
Grind_BreakerOnTick
if(halted) return;
if(quarantined) ...
Grind_OnTickEngine
```
Breaker is after lattice. So lattice rolls are not blocked by breaker. `blocked` is only halted/quarantined. `Grind_EntriesBlocked` not checked in LatticeTrySide. So even if API entry stop, rolls continue. That's intended: LB10 entries blocked don't block rolls. But for cost, rolls can continue during breaker. The breaker may cancel entry orders but not exits. So a trend day could cause many re-rolls. The ADR says account breaker is backstop, but breaker only trips on equity, not request count. API counter has hard stop for entries only. So request budget could be exceeded. T-7 likely NEEDS-FIX? The ADR acknowledges cost but no hard cap. The operator ruled out wind-down brake. But maybe a simple request counter for re-rolls? The prompt asks to verdict T-7 HOLDS/BREAKS/NEEDS-FIX. We can say BREAKS/NEEDS-FIX: no per-day cap on re-roll requests; throttle is per call, not per time. Smallest fix: check `Grind_ApiCounter` or add a re-roll request budget? But the ADR ruling says no wind-down brake. Maybe fix: rate-limit re-rolls to one per side per N seconds, or count requests. However "do not call anything fatal that has a fix: give smallest fix." So T-7 NEEDS-FIX with smallest fix: add a per-side cooldown (e.g., use existing backoff or a minimum interval) or count re-roll requests against API budget. But the ADR says at most one re-roll per side per call; the "call" is per tick. If ticks are fast, many. A simple fix: enforce at most one re-roll per side per *broker minute* or per *tick timestamp second*? But GR-3 ruled at most one per side per call; changing to per time may violate? The prompt says ruled do not re-open: "at most ONE re-roll per side per call, first rolls unlimited (GR-3, GC-2)". So cannot change that. But cost threat can still be flagged. Maybe the smallest fix is to count re-roll requests in API counter and let the existing hard stop block entries only? Not enough. Or use the existing `g_grind_vl_backoff` as a short cooldown after each re-roll? That would violate one per call? It would further throttle. The ADR ruled one per call, not "at most one per call"; adding a cooldown is extra safety, but may be considered re-opening. The operator ruled out wind-down brake. Hm.

Let's quantify worst plausible day. 8 layers per side. A re-roll rotates one layer. To re-roll all 8, 8 re-rolls = 24 requests. A trend day could have many rotations. Each rotation through the side is 8 re-rolls. If price trends down 100 pips with add=10, that's 10 levels, ~10 re-rolls per side = 30 requests. Not huge. But if it retraces and re-adds, each new layer unrolled rolls, etc. The ADR says realised loss grows by cap x add per rotation. A choppy trend could cause many rotations. The 2,000/day budget: 2000/3 = 666 re-rolls. Across 11 instances, 60 per instance. A single side with 8 layers rotating 7 times = 56 re-rolls. So one instance could consume the whole account budget. That's plausible. The burst at 00:15 after pause: after a weekend gap, market has moved many levels; the backlog could be large. But throttle one per tick. At 00:15, first tick, one re-roll per side. If ticks every second, 2 re-rolls/sec = 6 requests/sec. For 1 minute = 360 requests. For 11 instances = 3960 requests. That's double the daily budget in one minute. So T-7 BREAKS. The pause itself causes a backlog burst. The ADR says "one re-roll per tick then works the backlog." That is exactly the hazard. So T-7 likely BREAKS/NEEDS-FIX. Smallest fix: during the post-pause backlog, spread the re-rolls (e.g., one per side per minute) or count against API budget and stop. But the ADR ruled one per call. Hmm. Maybe the API counter already has a soft warn and hard stop for entries only; rolls are not counted. So no cap. We can suggest: add re-roll requests to the API counter or a per-side re-roll cooldown (e.g., reuse `g_grind_vl_backoff_long = now + 1` after a successful re-roll). But that changes GR-3? It still is at most one per call; it just adds a minimum interval. The ruling says "at most ONE re-roll per side per call", not "at least one per call". So a cooldown is compatible. However the ADR s4.7 says one per call (one tick or timer pass); a gap's backlog clears on following ticks. A cooldown would delay. But if needed for cost, it's a fix. We'll mark NEEDS-FIX.

T-8 Tests. Which behaviour has no test that fails without it? Any assertion in `fxgrind_tests_adr165.mqh` that passes vacuously (left over state from earlier fixture, a reset that does not clear stranded latch or closing ticket, an `ArchiveFind` that would also pass if nothing ran)?

Need inspect tests.

`Adr165_Fixture`:
```
Adr162b_SeedLong8();
for i 0..7 Grind_VLSet(7001+i, 1.20600 - 0.00100*i);
Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
Adr162b_RefreshExit(g_grind_long, true, 7, 8008UL);
Grind_MarketTestSeed(1.19000, 1.19010, 0, 0);
```
`Adr162b_SeedLong8` calls `Adr162b_Reset` which calls `Grind_LatticeResetBackoff`, `Adr151_TestResetAll`, etc. Does `Adr162b_Reset` clear stranded latch? `Grind_LatticeResetBackoff` clears `g_grind_vl_stranded_warned_long/short` and closing tickets. Yes. So before fixture, latch cleared. `Adr165_Fixture` sets VLs for all 8. Then `Adr162b_RefreshExit` for layers 0 and 7. Other layers have exit_order_ticket? In SeedLong8, all layers were set up with `Adr151_TestSetupLongLayer`, which likely sets exit_order_ticket=0? Let's see: SeedLong8 sets layers, then sets layer[0].exit_order_ticket=8001, layer[7].exit_order_ticket=8008. Others 0. Then Adr165_Fixture sets VL for all 8. RefreshExit for 0 and 7 updates their exit target based on effective entry (VL now set) and upserts order records. Wait: `Adr162b_RefreshExit` computes `target = Grind_ExitQFormulaTarget(entry, 5.0, _Point, is_long, pos)`. `Grind_ExitQFormulaTarget` likely uses effective entry. So for layer 0 with entry 1.21400 and VL 1.20600, target = VL + exit = 1.20650. That's what RR4c expects. For layer 7 entry 1.20700, VL 1.20000? Wait VLs: i=0 1.20600, i=1 1.20500, ..., i=7 1.19900? Let's compute: 1.20600 - 0.00100*7 = 1.19900. Yes. RefreshExit for layer 7 sets target = 1.19900 + 0.00050 = 1.19950. But RR4g asserts layer[7].exit_order_ticket == 0 after re-roll? Wait after re-roll of layer 0 to level 1.19800, the exit queue should hold rank 0 (layer 0) and highest rank (layer 1? or layer 7?). The old rank0 was layer 7? Let's understand ranks. Effective entries: layer 0 VL 1.20600 (highest for long, furthest above market). Long exit ranks: rank 0 = nearest to market? For long, exit is above entry. Effective entry higher means exit further above market. The exit queue keeps rank 0 (nearest) and highest rank resting. In ADR-151, rank 0 is nearest to market? Need know. For long, lower effective entry = nearer to market? Actually market at 1.19000. Effective entries: layer 7 VL 1.19900 (closest), layer 0 VL 1.20600 (furthest). Exit for layer 7 = 1.19950, layer 0 = 1.20650. Nearest is layer 7. Highest rank is layer 0 (furthest). So resting exits should be layer 7 (rank 0) and layer 0 (highest). That matches SeedLong8 initially set exit orders on 0 and 7. After re-roll layer 0 to level 1.19800, its VL becomes 1.19800, exit 1.19850. Now effective entries: layer 0 1.19800 (lowest), layer 7 1.19900. Nearest is layer 0 (rank 0), highest is layer 7 (rank 7). So exit queue should cancel old rank0 (layer 7?) Wait old resting exits: layer 0 (highest) and layer 7 (rank 0). After re-roll, layer 0 becomes rank 0, layer 7 becomes highest. So both resting? Actually layer 0 already has exit order 8001. It gets modified to 1.19850 and remains. Layer 7 has exit order 8008 at 1.19950, which is now highest. So both remain? But RR4g asserts `g_grind_long.layers[7].exit_order_ticket == 0`. Why would layer 7 be cancelled? Let's re-evaluate ranks. Maybe `Grind_ExitQAllowed` keeps only rank 0 and highest rank *resting as broker limit orders*. If both rank 0 and highest are already resting, they stay. After re-roll, layer 0 is rank 0, layer 7 is highest. Both should rest. But RR4g says layer[7].exit_order_ticket == 0. That suggests my rank direction is opposite. Let's check `Grind_ExitQRanks` not provided. From ADR-151: "exit queue keeps only rank 0 (nearest) and the highest rank resting as broker limit orders." For a long, nearest to market is the lowest exit price? Market ask 1.19010. Exits above market. The nearest exit is the lowest exit price, i.e., lowest effective entry + exit. Layer with lowest effective entry is nearest. Before re-roll, lowest effective entry is layer 7 (1.19900). So layer 7 is rank 0 (nearest). Highest rank is highest effective entry, layer 0 (1.20600). So resting: layer 7 and layer 0. Correct. After re-roll, layer 0's effective entry becomes 1.19800, which is lowest. So layer 0 becomes rank 0. Layer 7 effective entry 1.19900 is now highest? Wait there are 8 layers. Layer 7 has VL 1.19900. Layers 1-6 have VLs 1.20500 down to 1.20000. Layer 7 is 1.19900, which is lower than layers 1-6. Actually let's list after re-roll:
- layer 0 VL = 1.19800
- layer 1 VL = 1.20500
- layer 2 VL = 1.20400
- layer 3 VL = 1.20300
- layer 4 VL = 1.20200
- layer 5 VL = 1.20100
- layer 6 VL = 1.20000
- layer 7 VL = 1.19900
Lowest effective = layer 0 (1.19800). Highest effective = layer 1 (1.20500). So rank 0 = layer 0 (nearest), highest rank = layer 1 (furthest). Layer 7 is now neither rank 0 nor highest! Its effective entry 1.19900 is second-lowest. So the exit queue should cancel layer 7's exit order (rank not allowed) and place layer 1's exit order (highest). That matches RR4g layer[7].exit_order_ticket == 0, and RR4h layer[1].exit_order_ticket != 0. Good. So my rank was right. Great.

Now T-8: Check test RR4i asserts modify=1, remove=1, place=1. That seems correct: modify layer 0's exit, remove layer 7's exit, place layer 1's exit. Good.

Vacuous assertions? Let's scan.

- RR2c: `Grind_VLSet(7002UL, 1.20600); AssertEqInt("RR2c (F)", Grind_LatticeRerollIndex(...), 0);` Fixture set layer 0 VL=1.20600, layer 1 VL=1.20500. Setting layer 2 (ticket 7002? Wait tickets: 7001+i. layer 1 ticket 7002. Fixture set layer 1 VL=1.20500. Then `Grind_VLSet(7002UL, 1.20600);` sets layer 1 VL to 1.20600, tying with layer 0. Tie to lower layer_index: layer 0 index 0 vs layer 1 index 1, so returns 0. This tests tie. Good.

- RR2d: Short. `Adr162b_SeedShort8();` then set VLs for 7101..7108: `1.19400 + 0.00100*i`. For short, lowest effective entry is most underwater? Wait short entries: 1.18600 + 0.00100*i. Market? No market seeded here. RerollIndex for short picks lowest VL. VLs: 7101=1.19400, 7102=1.19500, ..., 7108=1.20100. Lowest is 7101 (layer 0) -> index 0. Good.

- RR4: `Adr165_Fixture(); AssertEqInt("RR4a", Adr165_TryLong(ADR165_T0, true), 1);` The loop: depth=8, level = ComputeAddTarget. Since any VL, anchor = lowest effective entry. Lowest effective among all layers? Layer 7 VL=1.19900, so anchor=1.19900. level = 1.19900 - 0.00100? add_pips=10.0, point? In tests, _Point likely 0.00001? Wait `Grind_PipsToPrice(10.0, _Point)` = 10 * 0.00001 * 10 = 0.00100. Yes. So level = 1.19800. Market ask=1.19010. `Grind_LatticeLevelCrossed(true, probe=min(ask, extreme=0)=1.19010, level=1.19800)` returns true because price <= level. So triggers. CandidateIndex: all layers have VL, so -1. reroll true. RerollIndex: highest VL = layer 0 VL 1.20600 -> idx 0. Roll to level=1.19800. Good. Then next iteration: depth still 8. ComputeAddTarget now anchor = lowest effective = layer 0 VL=1.19800. level = 1.19700. Market 1.19010 <= 1.19700, so crossed. idx<0, rerolls=1 -> break. So returns 1. Good.

- RR4e: `Grind_ReconExitMatchesEntry(1.21400, 1.19850, 5.0, _Point, true, 0.0, false, 7001UL)`. This likely checks exit matches formula from effective entry (VL) 1.19800 + 5 pips = 1.19850. Good.

- RR4f: `AssertNear("RR4f (G)", Grind_VLGet(7002UL), 1.20500, 1e-9);` Layer 1 unchanged. Good.

- RR4g: layer[7].exit_order_ticket == 0. We reasoned yes.
- RR4h: layer[1].exit_order_ticket != 0. Yes.

- RR4i: modify/remove/place counts. Good.
- RR4j,k,l: archive find. `Adr162b_ArchiveFind("ROLL_ACCEPTED", 0)`. Is there any other ROLL_ACCEPTED from previous fixtures? `Adr162b_Reset` calls `Grind_ArchiveTestReset` so queue cleared. Good.
- RR4m: `Adr162b_ArchiveFind("ROLL_STRANDED", 0) == ""`. Good.

- RR5 InputOff: `Adr165_Fixture(); AssertEqInt("RR5a", Adr165_TryLong(ADR165_T0, false), 0);` With reroll false, idx<0, `!reroll` true, MaybeStranded. But will MaybeStranded warn? It checks if market crossed stranded_level. level = 1.19800. stranded_level = level - add = 1.19700. Market ask 1.19010 <= 1.19700, so yes. So ROLL_STRANDED present. Good. RR5d asserts present.

- RR6 Throttle: after RR4, fixture again? `Adr165_Fixture()` at start. First call returns 1, VL 7001=1.19800. Second call: depth 8. ComputeAddTarget anchor lowest effective = 1.19800. level=1.19700. Market 1.19010 <= level. idx<0, rerolls=0, reroll true, not paused. RerollIndex: VLs: layer0=1.19800, layer1=1.20500, ... highest is layer1=1.20500. So idx=1. Roll layer1 to level=1.19700. VL 7002 becomes 1.19700. Return 1. RR6d asserts 7002=1.19700. Good. Third call: anchor lowest effective = layer1 VL=1.19700? Wait layer0=1.19800, layer1=1.19700. Lowest is 1.19700. level=1.19600. RerollIndex highest VL: layer2=1.20400? Actually layer2 VL=1.20400? Fixture set layer2 (i=2) = 1.20400. Yes. idx=2. Roll to 1.19600. RR6f asserts 7003=1.19600. Good. RR6g modify_calls==3. But note each re-roll may also cause remove/place. They only assert modify calls. Good.

- RR7 Pause: `Adr165_Fixture(); AssertEqInt("RR7a", Adr165_TryLong(D'2026.09.28 23:55', true), 0);` Pause true, idx<0, `!reroll || Paused` true -> MaybeStranded. Market crossed stranded_level? level=1.19800, stranded_level=1.19700, market 1.19010 yes. So ROLL_STRANDED. RR7c asserts present. Then `Adr162b_Reset(); Adr165_Fixture();` and 00:16 returns 1. Good.

- RR8 Short: `Adr162b_SeedShort8();` set VLs, refresh exits for 0 and 7, market 1.21000/1.21010. For short, ComputeAddTarget: any_vl true, anchor = highest effective entry. VLs: layer0=1.19400, layer1=1.19500, ..., layer7=1.20100. Highest = layer7 1.20100. level = anchor + add = 1.20200. Market bid 1.21000 >= level 1.20200 -> crossed. CandidateIndex -1 (all VL). RerollIndex for short picks lowest VL = layer0 1.19400. Roll to level=1.20200. VL 7101 becomes 1.20200. Exit formula for short: level - exit = 1.20200 - 0.00050 = 1.20150. RR8c expects 1.20150. Good. RR8d: `AssertNear("RR8d (G)", Grind_VLGet(7102UL), 1.19500, 1e-9);` Layer1 unchanged? Wait after rolling layer0 to 1.20200, the next iteration: anchor = highest effective. Layer0 now 1.20200, layer7 1.20100. Highest is layer0 1.20200. level = 1.20300. Market 1.21000 >= 1.20300 -> crossed. idx<0, rerolls=1 -> break. So layer1 unchanged 1.19500. Good.

- RR9 Accrual: Fixture, set accrued 0.00010, shift 0.00003, refresh exit layer0. TryLong. Exit target should be formula = level 1.19800 + exit 0.00050 + accrued 0.00010 = 1.19860. RR9a expects 1.19860. Shift deleted. Good.

- RR10 ModifyFails: Fixture, send_ok=false. TryLong. First roll? Wait all rolled, so is_reroll. RollLayer modify fails. It returns MODIFY_FAILED before VLSet. TrySide increments fail count, sets backoff, break. Returns 0. RR10b modify_calls==1. RR10c VL 7001 still 1.20600. RR10d ROLL_REFUSED MODIFY_FAILED. RR10e exit unchanged 1.20650. Good.

- RR11 ClosingCandidateStops: Fixture. Set layer[0].exit_order_ticket=0, exit_position_ticket=9999. TryLong. CandidateIndex -1. RerollIndex picks layer0 (highest VL 1.20600). idx=0. Then check `if(side.layers[idx].exit_position_ticket != 0)` -> true. NoteClosing, closing_stop=true, break. Returns 0. No roll. RR11a 0. RR11b VL unchanged. RR11c modify_calls==0. RR11d no ROLL_STRANDED. RR11e `(int)g_grind_vl_closing_ticket_long == 7001`. Good.

- RR12 OnTickWiring: Fixture. Call LatticeOnTick with reroll false. It passes reroll false. TrySide? `Grind_LatticeOnTick` calls `Grind_LatticeTrackExtremes` then if depth>=max calls TrySide. With reroll false, TrySide will MaybeStranded and break. VL unchanged. RR12a asserts. Then call with true, VI 7001=1.19800. Good. But note `Grind_LatticeOnTick` uses `Grind_SideDepth(g_grind_long) >= max_layers`. Depth 8. Good.

- RR13 FirstRollsThenOneReroll: `Adr162b_SeedLong8();` set VLs for layers 0..5. Layers 6,7 unrolled. Then `Adr151_TestSetupLongLayer` for indices 6 and 7 with layer_index 8 and 9? Wait:
```
Adr151_TestSetupLongLayer(g_grind_long, 6, 8, 1.20000, 7009UL, 0, 5.0);
Adr151_TestSetupLongLayer(g_grind_long, 7, 9, 1.19900, 7010UL, 0, 5.0);
```
So layer array index 6 has layer_index 8, ticket 7009; index 7 has layer_index 9, ticket 7010. Then RefreshExit for index 0 and 7. Market 1.19000/1.19010. TryLong with reroll true.
Let's trace. ComputeAddTarget: any_vl true (layers 0-5 have VLs). Anchor = lowest effective entry. Effective entries:
- layers 0-5 VLs: 1.20600, 1.20500, 1.20400, 1.20300, 1.20200, 1.20100? Wait loop `for i<6 VLSet(7001+i, 1.20600 - 0.00100*i)`. So layer0=1.20600, layer1=1.20500, layer2=1.20400, layer3=1.20300, layer4=1.20200, layer5=1.20100.
- layer6 (index 6, ticket 7009) entry 1.20000, no VL -> effective 1.20000.
- layer7 (index 7, ticket 7010) entry 1.19900, no VL -> effective 1.19900.
Lowest effective = 1.19900 (layer7). level = 1.19900 - 0.00100 = 1.19800.
Market ask 1.19010 <= 1.19800 -> crossed.
CandidateIndex: finds unrolled layers with highest entry. Unrolled: layer6 entry 1.20000, layer7 entry 1.19900. Highest is layer6 (index 6). So idx=6, not reroll. Roll layer6 to level 1.19800. VL 7009=1.19800. rolled_count=1.
Next iteration: depth 8. ComputeAddTarget: now any_vl true. Effective entries: layer7 1.19900, layer6 VL 1.19800. Lowest = 1.19800 (layer6). level = 1.19700.
Market 1.19010 <= 1.19700 -> crossed.
CandidateIndex: unrolled? layer7 entry 1.19900 no VL. Highest unrolled = layer7. idx=7. Roll layer7 to level 1.19700. VL 7010=1.19700. rolled_count=2.
Next iteration: ComputeAddTarget: lowest effective = layer7 VL 1.19700. level = 1.19600.
Market 1.19010 <= 1.19600 -> crossed.
CandidateIndex: all layers have VL? Layers 0-5 have VL, 6,7 now have VL. So -1.
reroll true, rerolls=0. Not paused. RerollIndex: highest VL among all. VLs: layer0=1.20600, layer1=1.20500, ..., layer5=1.20100, layer6=1.19800, layer7=1.19700. Highest = layer0 1.20600. idx=0. is_reroll=true. Roll layer0 to level=1.19600. VL 7001 becomes 1.19600. rerolls=1. rolled_count=3.
Next iteration: ComputeAddTarget: lowest effective = layer0 VL 1.19600? Wait layer7 VL 1.19700, layer6 1.19800. Lowest = 1.19600. level = 1.19500. Market 1.19010 <= 1.19500 -> crossed.
CandidateIndex -1. reroll true, rerolls>=1 -> break. Return 3.
RR13a expects 3. Good.
RR13b: VL 7009=1.19800. RR13c: 7010=1.19700. RR13d: 7001=1.19600. Good.

Now T-8: Any test passes vacuously? Let's look for assertions that would pass even if nothing ran.

- RR4g: `g_grind_long.layers[7].exit_order_ticket == 0`. If nothing ran, layer7 still has exit_order_ticket 8008 from fixture, so false. So test fails if no run. Good.
- RR4h: `g_grind_long.layers[1].exit_order_ticket != 0`. If nothing ran, layer1 had 0, so false. Good.
- RR4i: modify_calls==1 etc. If nothing ran, 0, false. Good.
- RR4j/k/l: ArchiveFind. If nothing ran, ROLL_ACCEPTED absent, so false. Good.
- RR4m: ArchiveFind ROLL_STRANDED == "". If nothing ran, no stranded, so passes vacuously! But it's an absence assertion. It would pass if the whole function did nothing. However the preceding assertions ensure something ran. But as an individual assertion, it's vacuous if no roll and no stranded? Actually if TryLong did nothing, no ROLL_ACCEPTED, but RR4j would fail. So not vacuous in context. But T-8 asks "Any assertion in fxgrind_tests_adr165.mqh that passes vacuously (left over state from an earlier fixture, a reset that does not clear the stranded latch or the closing ticket, an ArchiveFind that would also pass if nothing ran)?" The absence assertions like RR4m, RR6h, RR11d are vacuous if nothing ran, but other assertions cover. We can mention.

Potential vacuous: RR5d asserts `ROLL_STRANDED != ""`. That would fail if nothing. Good.
RR11d asserts `ROLL_STRANDED == ""`. Could pass vacuously if TryLong didn't run? But RR11a expects 0, RR11c modify_calls==0, RR11e closing_ticket==7001. RR11e would fail if nothing. Good.

Check reset clears stranded latch and closing ticket. `Adr162b_Reset` calls `Grind_LatticeResetBackoff` which clears stranded and closing tickets. Yes. So no leftover.

But wait `Adr165_Fixture` calls `Adr162b_SeedLong8` which calls `Adr162b_Reset` (clears), then sets up. Then `Adr165_Fixture` sets VLs. But it does NOT call `Grind_LatticeResetBackoff` after setting VLs. So latch is cleared from SeedLong8. Good.

What about `g_grind_order_test_modify_calls` etc? `Adr162b_Reset` calls `Grind_TestEjectHarnessReset`? Let's see `Adr162b_Reset`:
```
Grind_TestEjectHarnessReset();
Grind_ArchiveTestReset();
Grind_LatticeResetBackoff();
Adr151_TestResetAll();
g_grind_order_test_send_ok = true;
```
Does `Grind_TestEjectHarnessReset` reset order test counters? Not sure. `Adr151_TestResetAll` may. In RR4, they assert modify_calls==1. If counters not reset, could be left over. But presumably `Adr151_TestResetAll` resets. We don't have code. But tests pass.

Potential vacuous: RR9b `AssertNear("RR9b (G)", Grind_CarryAccruedGet(7001UL), 0.00010, 1e-9);` This is marked (G) good, meaning it's not a new behavior; it would pass even if re-roll didn't keep accrual? Actually if re-roll deleted accrual, it would fail. But the test sets accrual and then calls TryLong. If TryLong didn't run, accrual remains 0.00010, so passes vacuously. But RR9a checks exit price includes accrual, so it would fail if no run. RR9c checks shift deleted. If no run, shift remains, so fails. So not vacuous overall.

T-8 also asks "Which behaviour has no test that fails without it?" We need identify missing tests. Candidates:
- The stranded latch clear on successful re-roll (T-3) has no direct test.
- The pause using stale quote time? No test.
- The re-roll after commanded eject undoing it? No test.
- The cost/burst? No test.
- The `from_level` detail for first roll? No test? RR tests for reroll.
- The `allow_reroll` first roll call with false? Not directly.
- The closing refusal in RollLayer for re-roll? RR11 tests closing candidate stops before roll, but not the `GRIND_ROLL_CLOSING` return from RollLayer when exit order unselectable. There is no RR test for `exit_order_ticket != 0 && !Grind_SelectOurOrder` on a re-roll. That is a behavior of allow_reroll true? G3 says closing refusal still applies. No test. Smallest test: set layer0 exit_order_ticket to a ticket not in order test records, all rolled, market crossed, call TryLong with reroll true, assert 0, no modify, VL unchanged, closing ticket noted, no ROLL_STRANDED.
- The `GRIND_ROLL_ALREADY_ROLLED` skip for allow_reroll true is tested indirectly (re-roll succeeds).
- The latch clear: no test.
- The `RerollIndex` tie on short? RR2c ties long. Short tie not tested.
- The `RerollIndex` none -> -1: RR2a tests none for long. Short none? Not.
- The throttle after a first roll and one reroll? RR13 does first rolls then one reroll, but does it test that a second reroll is throttled? In RR13, after one reroll, next iteration breaks due to rerolls>=1. It returns 3. If throttle were absent, would it do another reroll? Let's see after reroll layer0 to 1.19600, next iteration level=1.19500, market crossed. If throttle absent, idx<0, reroll true, not paused, RerollIndex would pick next highest VL (layer1 1.20500) and reroll it too. Then return 4. RR13a expects 3, so it does test throttle after a reroll in presence of first rolls. Good.
- The pause boundaries tested in RR3.
- The `TimeCurrent` stale quote not tested.

T-8 also: `Adr165_Fixture` sets VLs for all layers but does not clear `g_grind_vl_stranded_warned_long` after setting? It was cleared by reset. Good.

But there's a subtle bug in `Adr165_Fixture`: It sets VLs for all 8 layers, then calls `Adr162b_RefreshExit` for layer 0 and 7. For layer 0, entry 1.21400, VL 1.20600, target = 1.20650. For layer 7, entry 1.20700, VL 1.19900, target = 1.19950. But `Adr162b_RefreshExit` uses `Grind_ExitQFormulaTarget(entry, 5.0, _Point, is_long, pos)`. Does that use effective entry? Yes, it likely calls `Grind_EffectiveEntry`. So target uses VL. Good.

Now, need check G1 more carefully: "With InpLatticeReroll = false every path behaves exactly as before this branch: the new block reduces to the old strand-and-break, and allow_reroll is false at every call site." Is there any other change? The `Grind_LatticeRollLayer` signature gained `allow_reroll` default false, and `Grind_LatticeRollDetail` gained params default. The detail JSON now includes `"reroll":false,"from_level":0.0` even for first rolls. That changes archive output! The ADR s7 says "no change with the input OFF (byte-identical behaviour, suite green)". But the `ROLL_ACCEPTED` detail for first rolls now includes extra fields `"reroll":false,"from_level":0.0`. That is a schema change, not byte-identical. Tests may not check absence. This is a G1 violation? G1 says "every path behaves exactly as before this branch". The archive detail changed. If downstream parsers expect exact JSON? It's still valid JSON, but schema changed. The ADR says byte-identical behaviour. This is a silent schema mismatch. Also `LATTICE_CONFIG` gains `"reroll"`. That changes archive. `Print("GRIND_REROLL enable=")` new print. So G1 is FALSE if we interpret "exactly as before" including telemetry/archive. But the given G1 says "the new block reduces to the old strand-and-break, and allow_reroll is false at every call site." It focuses on control flow and allow_reroll. It might not require archive byte-identical. But the ADR s7 says "no change with the input OFF (byte-identical behaviour, suite green)". The actual code changes `Grind_LatticeRollDetail` for all rolls to include `"reroll":%s,"from_level":%s`. That is a change in output. So G1 as stated ("every path behaves exactly as before") is FALSE. Let's verify: `Grind_LatticeRollDetail` always includes `\"reroll\":%s,\"from_level\":%s}`. It is called from `Grind_LatticeRollLayer` for all rolls, including first rolls. The call passes `allow_reroll` which is false for first rolls, and `from_level` default 0.0. So first roll `ROLL_ACCEPTED` detail now has `"reroll":false,"from_level":0.0`. Previously it did not. This is a schema change. The tests LB31 check first roll detail? `Test_LB31_RollDetail` calls `Grind_LatticeRollDetail` directly and asserts contains fields, but does not assert absence of reroll/from_level. The existing ADR-162 suite may not check exact JSON. So tests cannot see. This is a G1 violation if "exactly as before" includes archive. The prompt says "G1. With InpLatticeReroll = false every path behaves exactly as before this branch: the new block reduces to the old strand-and-break, and allow_reroll is false at every call site." The colon seems to define what they mean: new block reduces, allow_reroll false. But "every path behaves exactly" is broader. We should mark G1 FALSE/NEEDS-FIX? The prompt expects verify each GIVEN. We need be precise. Let's read G1: "With `InpLatticeReroll = false` every path behaves exactly as before this branch: the new block reduces to the old strand-and-break, and `allow_reroll` is false at every call site." They assert two things. The code satisfies the new block and allow_reroll false. But the detail JSON changed. Does that count as a path? It's an output path. Also `LATTICE_CONFIG` changed. So G1 is not fully true. However the ADR s7 says "no change with the input OFF (byte-identical behaviour, suite green)". The code violates byte-identical. We should flag G1 FALSE with quote: `\"reroll\":%s,\"from_level\":%s}` in `Grind_LatticeRollDetail`, and `StringFormat("{\"enable\":%s,\"reroll\":%s}", ...)` in OnInit. The smallest fix: only append reroll/from_level when `source=="reroll"` or when reroll param true, to preserve old JSON for first rolls. Or version the schema. Since the prompt says "Do not call anything fatal that has a fix: give the smallest fix." We can mark G1 FALSE (schema-only) and give fix.

But wait, the given G1 might be intended to be verified as true. The red-team might expect finding this. The prompt says "GIVENS -- verify each (VERIFIED or FALSE, with the quote)". So we can mark G1 FALSE due to archive schema change. Let's consider if `allow_reroll` is false at every call site. In `Grind_LatticeTrySide`, `const int rc = Grind_LatticeRollLayer(..., roll_source, is_reroll);` If `is_reroll` is false, allow_reroll false. If `is_reroll` true, allow true. So with InpLatticeReroll false, `reroll` param false, so `is_reroll` never true. Thus allow_reroll false. Good. The new block reduces. So the only issue is archive/print. The G1 wording "every path behaves exactly" is violated. We'll mark FALSE with note: control flow verified, but archive schema changed. That's a good catch.

Also G2: "The reroll FATAL in OnInit runs before Grind_MagicLockClaim." True. Quote: `if(!Grind_ValidateRerollInputs(InpVirtualLattice, InpLatticeReroll)) { ... return INIT_FAILED; }` before `if(!Grind_MagicLockClaim(InpMagic))`. Yes.

G3: "With allow_reroll = true, Grind_LatticeRollLayer differs from a first roll ONLY in skipping the ALREADY_ROLLED refusal and recording from_level; the closing refusal still applies." Is there any other difference? It also records `"reroll":true` in detail (the `allow_reroll` param used as `reroll` in detail). That's part of recording? The given says "recording from_level" but also the detail has `"reroll"` boolean. That's a difference. Also `from_level` is recorded. The closing refusal still applies. But is there a difference in `Grind_LatticeCountRolled`? It counts rolled layers; with allow_reroll true, the layer was already rolled, so count includes it before and after. For first roll, count increments. But that's inherent. The function computes `rolled` after setting VL. For a re-roll, the layer already had VL, so `Grind_LatticeCountRolled` before and after same. But the detail's `rolled` field will be same. Not a behavioral difference in the roll itself. The only code difference is the `if(!allow_reroll) return ALREADY_ROLLED; from_level = ...` and passing to detail. Also the detail includes `"reroll":true`. So G3 is essentially TRUE, with note that `reroll` flag is also recorded. The prompt says "ONLY in skipping ... and recording from_level". The `reroll` flag is also recorded. Minor. We can mark VERIFIED with that note. Or FALSE? The given says "ONLY in skipping ... and recording from_level". The code also records `"reroll":true` (which is part of the new detail). But that's arguably part of recording the re-roll. I'd mark VERIFIED (the closing refusal still applies) and note the extra `"reroll"` field.

G4: "The re-roll path sends no market order and opens or closes no position: its requests are the exit modify and the exit queue's remove/place." Need check if `Grind_ExitQManageSide` can call `Grind_QueueCloseBy` which later sends close-by. But the re-roll path itself calls `Grind_ExitQManageSide`, which can call `Grind_ExitQHoldCancelLayer`. That function can detect an exit deal position and call `Grind_QueueCloseBy`. That queues a close-by, not sends now. Later `Grind_ProcessCloseByQueues` in OnTick sends closeby. Is that "re-roll path sends ... no close"? The queue is part of exit queue management. Also `Grind_ExitQHoldCancelLayer` can cancel pending exit, which is a remove. It doesn't place. So requests from re-roll path: modify (if resting), remove (cancel), place (queue). No market order. No position opened. It may queue a close-by if an exit already filled, but that's not a market order and not opening. Closing? It queues a close-by to close an already-hedged position. That is a close, but not initiated by re-roll; it's resolving a filled exit. The given says "opens or closes no position". Strictly, if `Grind_ExitQHoldCancelLayer` queues closeby, the re-roll path can lead to closing a position. But that's an edge case where an exit already filled. The re-roll itself doesn't close. I'd mark G4 VERIFIED with caveat, or FALSE? The threat T-5 might cover. The prompt specifically says "its requests are the exit modify and the exit queue's remove/place." In the edge case, it's not a request. So I'd mark VERIFIED.

G5: "Grind_EffectiveEntry of a rolled layer equals its VL, so Grind_LatticeRerollIndex (by VL) picks the highest EFFECTIVE entry." Code: `Grind_EffectiveEntry` returns VL if VLHas. `RerollIndex` uses `Grind_VLGet`. So yes. But tie-breaking: RerollIndex uses VL, not effective. Since equal, fine. Mark VERIFIED.

G6: "Grind_LatticeOnTick is called only from OnTick (not from OnTimer); a dead market therefore never re-rolls." OnTimer does not call. OnTick calls. Mark VERIFIED.

Now T-1: Need find any bug. Let's scrutinize `Grind_LatticeRerollIndex` tie-breaking and selection.

```
int best = -1;
for i:
  ticket = side.layers[i].position_ticket;
  if(ticket==0) continue;
  if(!Grind_VLHas(ticket)) continue;
  vl = Grind_VLGet(ticket);
  if(best<0){ best=i; continue; }
  bv = Grind_VLGet(side.layers[best].position_ticket);
  if(is_long) {
    if(vl > bv || (vl == bv && side.layers[i].layer_index < side.layers[best].layer_index))
      best = i;
  } else {
    if(vl < bv || (vl == bv && side.layers[i].layer_index < side.layers[best].layer_index))
      best = i;
  }
return best;
```
This picks highest VL for long. But effective entry = VL. Good.

Potential T-1 bug: After a re-roll, the re-rolled layer's VL is set to `level`. But `level` is the level computed before the roll. In the next iteration, `Grind_ComputeAddTarget` uses the lowest effective entry among all layers. For long, lowest effective entry is the re-rolled layer's new VL = `level`. Then next level = `level - add`. That is correct. However, what if the re-rolled layer was not the lowest effective entry? It was the highest VL (furthest). Its new VL is the new `level`, which is lower than all existing VLs? The new `level` is computed from the lowest effective entry before the roll. Before the roll, the lowest effective entry might be some other layer (the nearest). The new level = lowest_effective - add. So it is lower than all existing effective entries. So the re-rolled layer becomes the lowest. Yes.

Potential T-1 bug: `Grind_LatticeCandidateIndex` for first rolls uses `entry_price`, not effective. For unrolled layers, effective=entry. But what if a layer has no VL but is ejected? `Grind_EffectiveEntry` returns entry. So candidate by entry. Fine.

Potential T-1 bug: "same layer is re-rolled twice in a row". Could happen if there is only one rolled layer? But at cap, depth = max_layers. If max_layers could be 1? The system cap 8 layers per side. But `max_layers` is input. If max_layers=1, then at cap depth=1. All rolled (one layer). RerollIndex picks it. Roll to level. Next call, it is still the only rolled layer. RerollIndex picks it again! So the same layer is re-rolled twice in a row. Is that allowed? ADR says "the layers rotate through the levels in roll order". With only one layer, it would re-roll the same layer every time. But the system cap is 8 layers per side. Could max_layers be 1? The system says cap 8 layers per side. So max_layers=8. But if depth drops to 1? TrySide only called if depth >= max_layers. So if max_layers=8, depth must be 8. So at least 8 layers. So no.

But what if some layers have position_ticket=0? `Grind_SideDepth` is array size. Could have layers with no position? At cap, all should have positions. If some closing, depth may still be 8 but one has exit_position_ticket. RerollIndex could pick the same layer if others are closing? It skips ticket==0, not closing. If only one rolled layer with VL and others closing? But all rolled initially. If one re-rolls, it gets lowest VL. Next call, if market crosses next level, RerollIndex picks highest VL, which is another layer. So not same.

Potential T-1 bug: "a layer without a resting exit (the exit queue holds only two) is re-priced wrongly (`exit_target` only, no modify)." In `Grind_LatticeRollLayer`, if `layer.exit_order_ticket == 0`, it sets `side.layers[idx].exit_target = formula` and calls `Grind_ExitQManageSide`. But `Grind_ExitQManageSide` computes ranks from effective entries. The re-rolled layer's effective entry is now `level` (lowest for long). So it becomes rank 0. `Grind_ExitQRequired(ranks[i], n)` likely returns true for rank 0. Then it places a limit. So it will be placed. However, what if the layer already had `exit_position_ticket != 0`? It would have been caught earlier. So no.

But there is a subtle bug: In `Grind_LatticeRollLayer`, the variable `layer` is a copy: `GrindLayer layer = side.layers[idx];`. After modifying, it sets `side.layers[idx].exit_target = price`. But when `layer.exit_order_ticket == 0`, it sets `side.layers[idx].exit_target = formula`. Then calls `Grind_ExitQManageSide`. That function uses `side.layers[i].exit_order_ticket` and `exit_target`. So it sees updated. Good.

Potential T-1 bug: `Grind_LatticeRollLayer` uses `const double entry = layer.entry_price;` for cost and detail, but for re-roll the "entry" field in detail is still original entry, not effective. The ADR says detail gains `from_level`. That's fine.

Potential T-1 bug: The next level is computed from `Grind_ComputeAddTarget` which uses `Grind_EffectiveEntry(side.layers[0].entry_price, side.layers[0].position_ticket)` then loops. It initializes anchor with layers[0] even if layers[0].position_ticket == 0? `Grind_EffectiveEntry` with position_ticket 0 returns entry_price. If layers[0] has no position, it might use its entry. But at cap all have positions. If some closing, position_ticket may still be set. Fine.

T-1 verdict: HOLDS? There might be no bug. But the prompted threat mentions "a layer without a resting exit ... is re-priced wrongly (`exit_target` only, no modify)." We can say it is handled by exit queue placing it. So HOLDS. But we found T-5 bug with ejected layer. T-1 might still hold.

T-2: Loop control. Let's scrutinize closing state.

`closing_stop` is set true if candidate closing before roll, or if RollLayer returns CLOSING. After loop, `if(!closing_stop) Grind_LatticeResetClosingState(is_long);`. If closing_stop true, the closing state persists. But what if the closing candidate was a re-roll candidate and the roll later succeeded on a different layer? Actually if a closing candidate is encountered, the loop breaks immediately. So no further rolls. So closing_stop true only when loop stopped due to closing. Good.

But consider: The loop may break due to throttle (`if(reroll && rerolls >= 1) break;`). `closing_stop` false, so ResetClosingState called. Could that reset a closing state that should persist from a previous call? Suppose on a previous call, a closing candidate was noted (closing_stop true, state set). On the next call, the loop starts, maybe the first iteration throttle breaks before reaching the closing candidate? If throttle breaks, closing_stop remains false, so ResetClosingState is called, clearing the closing state from the previous call. That could hide a `ROLL_CLOSING_STUCK` warning! Let's analyze.

Scenario: Side at cap, all rolled. There is a closing layer (exit filled) that has the highest VL, so it is the re-roll candidate. On call 1: loop iteration 1: idx<0, reroll true, rerolls=0, RerollIndex picks the closing layer. idx>=0. Check `if(side.layers[idx].exit_position_ticket != 0)` -> true. `Grind_LatticeNoteClosing` sets `g_grind_vl_closing_ticket_long = pos`, since, warned=false. `closing_stop = true; break;`. After loop, `if(!closing_stop)` false, so closing state persists. Return 0.

Call 2 (next tick): `backoff` no. At top, CandidateIndex? All rolled, so -1. Loop iter 1: level crossed? If market still crossed. idx<0. `if(reroll && rerolls >= 1)` rerolls=0, so false. `if(!reroll || paused)` false. `idx = RerollIndex` picks the same closing layer (highest VL). `if(side.layers[idx].exit_position_ticket != 0)` true. `Grind_LatticeNoteClosing` called again. Now `g_grind_vl_closing_ticket_long == pos`, so it checks `now - since >= 60`. If less than 60, no warn. `closing_stop=true; break`. Reset not called. So state persists. Good.

But what if on call 2, the throttle check triggers before the closing check? That requires `rerolls >= 1`, meaning a re-roll already happened in this call. But the closing candidate is encountered at the start of the loop, before any re-roll. So rerolls=0. So no throttle break. What if the first iteration does a first roll (unrolled candidate) and then a re-roll? Then closing candidate might be encountered later. Suppose there is an unrolled candidate (so not all rolled). The loop does first roll, then next iteration maybe all rolled? Actually if there was an unrolled candidate, after rolling it, all may be rolled. Then next iteration, idx<0, rerolls=0, it may pick a closing layer as re-roll candidate. So closing_stop set. No throttle before. If it does a re-roll first (rerolls=1), then next iteration, if there is a closing candidate, the throttle `if(reroll && rerolls >= 1) break;` is checked when idx<0. But if the closing layer has VL, `Grind_LatticeCandidateIndex` returns -1 (all rolled). So it enters idx<0. It checks `if(reroll && rerolls >= 1) break;` BEFORE checking pause or getting RerollIndex. So it breaks immediately, without checking if the next candidate is closing! That means if a re-roll already happened in this call, and the next level is crossed, the loop breaks due to throttle and does NOT check whether the next re-roll candidate is a closing layer. Consequently, `closing_stop` remains false, and after loop, `Grind_LatticeResetClosingState(is_long)` is called. If there was a closing state from a previous call, it gets cleared! This is a real bug in T-2. Let's verify.

Scenario: On call 1, a closing candidate was noted (closing_stop=true, state set, no reset). On call 2, the loop does a successful re-roll on some non-closing layer (rerolls=1), then next iteration throttle breaks. `closing_stop` false, so ResetClosingState clears the closing state. Then if the closing layer remains closing, the `ROLL_CLOSING_STUCK` warning may be delayed or never emitted because the state was reset. But on call 3, the closing layer might be picked again and NoteClosing starts a new timer. So it could delay the warning, but not permanently hide? If every call does a re-roll then throttle breaks before reaching the closing candidate, the closing state could be reset every call, and `now - since` never reaches 60 because since keeps resetting. Let's construct.

Suppose side at cap, all rolled. There is a closing layer C with highest VL. There is another layer A with second-highest VL. On call 1: market crossed next level. RerollIndex picks C (closing). NoteClosing sets since=now1, closing_stop=true, break. No reset. Call 2: market crossed next level again (because price moved). RerollIndex picks C again? If C is still highest VL, yes. But if C was not re-rolled (because closing stopped), its VL unchanged. So C remains highest. So call 2 also picks C and stops. It will never re-roll A because C is always chosen first and stops the loop. So throttle never triggers before closing check in this scenario. The throttle break before closing check only happens if a re-roll already happened in the same call, which requires the first re-roll to be on a non-closing layer. But the first re-roll candidate is the highest VL. If C is the highest VL, it would be chosen first and stop. So to have a re-roll on A, A must be highest VL, meaning C has lower VL. Then C is not the candidate. The closing layer C is not the highest VL, so it wouldn't be picked as candidate anyway. But could C be closing and not highest VL? Yes. Then the loop may re-roll A (highest VL), then throttle break. The closing layer C is not checked because it's not the candidate. But was C noted in a previous call? How could C be noted if it's not the highest VL? It would only be noted if it became the candidate in some call. That could happen if A was already re-rolled and its VL became lower, making C the highest VL. Let's trace.

Suppose layers: A VL=1.20600 (highest), C VL=1.20500 (second), C is closing. Call 1: RerollIndex picks A. A is not closing. Roll A to new level, say 1.19800. A's VL becomes 1.19800. rerolls=1. Next iteration: ComputeAddTarget anchor lowest effective = A 1.19800. level=1.19700. Market crossed. idx<0. `if(reroll && rerolls>=1) break;` -> breaks immediately. closing_stop=false. ResetClosingState called. But C was never noted. Call 2: RerollIndex picks highest VL. Now A VL=1.19800, C VL=1.20500, others... Highest is C (if C=1.20500). So C becomes candidate. Check `exit_position_ticket !=0` -> true. NoteClosing sets since=now2, closing_stop=true, break. No reset. Call 3: RerollIndex picks C again? C remains highest VL. Yes. NoteClosing checks since. If <60, no warn, closing_stop=true, break. No reset. So warning eventually. The reset in call 1 didn't matter because C wasn't noted yet. So the throttle break resetting closing state only matters if a closing state was already set from a previous call, and in the current call a re-roll happens before the closing candidate is checked. But if a closing state was set, that means a closing candidate was the highest VL in the previous call. If in the current call a different layer is re-rolled first, that layer must have become the highest VL, meaning the closing layer's VL is no longer highest. How could that happen? The closing layer's VL doesn't change unless it is re-rolled (which doesn't happen because it's closing). Other layers' VLs can only decrease (for long) when re-rolled. So if C was highest VL and closing, its VL remains highest until it closes and is removed. Other layers' VLs are lower. Re-rolling a lower-VL layer would make its VL even lower, so it won't surpass C. Thus C remains highest. So it will be picked first every call. So the throttle break before closing check won't bypass C. Therefore the reset scenario might not occur. But what if C's VL is overwritten? Not if closing. So T-2 maybe holds. However, consider first rolls. If there is an unrolled layer with high entry, it could be rolled to a level lower than C? Actually first roll candidate is unrolled, not by VL. If there is an unrolled layer, `Grind_LatticeCandidateIndex` returns >=0, so the loop does first rolls before considering rolled layers. The closing state from a previous call might be set? If there is an unrolled layer, the side is not all rolled, so a closing state might have been set in a previous call when all were rolled? But then an unrolled layer appears? That happens if a new add fills? At cap, no new add. Or if a roll failed? Not likely. So T-2 probably holds.

Another T-2 issue: `rolled_count` counts re-rolls too. The return value is used in tests to assert number of rolls. In RR4, returns 1. In RR13, returns 3 (2 first + 1 reroll). The ADR says first rolls unlimited. `rolled_count` includes both. No issue.

`closing_stop` / `Grind_LatticeResetClosingState` after the loop: If the loop breaks due to backoff (`rc == MODIFY_FAILED`), `closing_stop` false, so ResetClosingState called. That's fine; a modify failure is not a closing state. If it breaks due to throttle, same. If it breaks due to level not crossed, same. Only closing_stop true skips reset. Good.

T-2 verdict: HOLDS.

T-3: Stranded latch. Let's examine possible failure to warn. The latch is set in MaybeStranded. It is cleared on successful re-roll. On modify failure, latch is not set (it was cleared before? Let's trace). Suppose all rolled, latch false. Market crosses. TrySide: idx<0, reroll true, not paused. RerollIndex returns idx. RollLayer modify fails. TrySide increments fail count, backoff, break. It does NOT call MaybeStranded, so `g_grind_vl_stranded_warned_long` remains false. The failure is reported as `ROLL_REFUSED`. Next tick, backoff may prevent TrySide entirely (`if(now < backoff) return 0;`), so no warning. After backoff, tries again. If it keeps failing, it never emits `ROLL_STRANDED`. The ADR GR-5 says keep ROLL_STRANDED as the failure signal (re-rolls failing / paused). So this is a bug: modify failures on re-roll do not set or warn ROLL_STRANDED. However, is `ROLL_STRANDED` supposed to be emitted for modify failure? The existing first-roll behavior also doesn't emit ROLL_STRANDED on modify failure; it emits ROLL_REFUSED. The ADR GR-5 specifically says "every layer closing, or re-rolls failing / paused" for ROLL_STRANDED. So the new re-roll path should perhaps emit ROLL_STRANDED when re-roll fails? But the code doesn't. This is a T-3/T-6 issue.

Also pause: when paused, `MaybeStranded` is called and will warn once. Latch set. Then after pause, re-roll success clears. Good.

Every layer closing: if all layers are closing, `Grind_LatticeRerollIndex` might return -1? It skips ticket==0 but not closing. If all layers have exit_position_ticket !=0, they still have VLs. RerollIndex returns highest VL. Then TrySide checks `exit_position_ticket !=0` and calls NoteClosing, closing_stop=true, break. It does NOT call MaybeStranded. So `ROLL_STRANDED` is not emitted for every layer closing; instead `ROLL_CLOSING_STUCK` is emitted after 60s. ADR GR-5 says ROLL_STRANDED for every layer closing. The code uses ROLL_CLOSING_STUCK. Is that a conflict? ADR-165 s4.3 says "With no rolled layer to take, the input OFF, or the pause: today's stranded WARN, unchanged." But if the candidate is closing, the existing closing check STOPS the loop, exactly as for a first roll. So it does not emit ROLL_STRANDED; it emits ROLL_CLOSING_STUCK. The GR-5 ruling says keep ROLL_STRANDED as failure signal (every layer closing...). There's a discrepancy. But s4.2 says closing candidate stops the loop, no stranded WARN. So maybe GR-5 is not strictly implemented. The threat T-3 asks: "Is the latch ever left set so that a later real failure (every layer closing, modify failing, the pause) never warns?" For modify failing, no ROLL_STRANDED warn (only ROLL_REFUSED). For every layer closing, no ROLL_STRANDED (only ROLL_CLOSING_STUCK). So yes, the failure signal is not ROLL_STRANDED. But is that a bug? The ADR says keep ROLL_STRANDED as the failure signal. The code doesn't for these cases. However, maybe ROLL_CLOSING_STUCK and ROLL_REFUSED are considered different signals. The threat T-3 specifically asks about the latch being left set. Let's focus on latch.

Scenario: Latch is set true (e.g., from a pause). Then a re-roll succeeds, clearing latch. Later modify fails. Latch false. It never warns ROLL_STRANDED on modify fail. So the real failure does not warn via ROLL_STRANDED. Is that "latch left set"? No, it's clear, but no warn because MaybeStranded not called. The threat says "Is the latch ever left set so that a later real failure ... never warns?" If latch is set, MaybeStranded returns early. So if a failure occurs that does call MaybeStranded, and latch is already set, it won't warn. When could latch be set and a new failure occur? Suppose pause sets latch. Then pause ends, but before a successful re-roll, a modify failure occurs? At pause, no re-roll attempted. At 00:15, first call: not paused, tries re-roll. If modify fails, it breaks with ROLL_REFUSED, does not call MaybeStranded. Latch remains true (set from pause). So later, if after backoff it still fails, no ROLL_STRANDED. But it already warned at pause. The new failure is different (modify vs pause). The latch prevents a new warning because it's still set and MaybeStranded isn't called anyway. So the operator may not get a new ROLL_STRANDED for the modify failure, but they do get ROLL_REFUSED. So maybe acceptable.

What about latch left set after a re-roll fails? On failure, latch is not cleared because clear only on success. So if it was set from a previous pause, it stays set. Then if later all layers close, MaybeStranded not called; closing state. If later pause again, MaybeStranded called but returns early because latch still set. So no new pause warning. But the pause warning is not critical since already warned. The ADR says reset on successful re-roll so later failure warns afresh. If no successful re-roll, it's the same episode. So maybe okay.

The smallest test for T-3: Set latch true, perform successful re-roll, assert latch false; then trigger a pause or no-reroll condition and assert ROLL_STRANDED present. Or more directly: test that after a modify failure, a subsequent pause emits ROLL_STRANDED? But the latch might be clear. Hmm.

T-3 verdict: NEEDS-FIX? The failure to emit ROLL_STRANDED on modify failure/all closing might be a gap. But the prompt says T-3 specifically about the stranded latch. We can say T-3 NEEDS-FIX: the latch is not cleared on a failed re-roll, so a pause after a modify failure may not warn. But is that a real issue? Let's find a concrete path where latch left set prevents a needed warning.

Consider: All rolled, latch false. Market crosses next level. TrySide: reroll true, not paused. RerollIndex returns idx. RollLayer modify fails. TrySide breaks. Latch remains false (never set). No ROLL_STRANDED. Next call after backoff: tries again. If modify fails again, still no ROLL_STRANDED. So the real failure (modify failing) never warns ROLL_STRANDED. But it does warn ROLL_REFUSED each time? Actually RollLayer emits ROLL_REFUSED on each modify failure. So operator sees ROLL_REFUSED. The ADR s4.8 says "A side may raise ROLL_STRANDED there: expected." For pause, it does. For modify failing, GR-5 says ROLL_STRANDED as failure signal. So the code doesn't follow GR-5. But T-3 asks about latch, not GR-5. We can mention both.

T-4: Pause. We already found stale quote hazard. Also `Grind_LatticeRerollPaused` uses `TimeToStruct(server_now, t); const int m = t.hour*60 + t.min;`. It ignores seconds. At 23:50:00 exactly, m=1430, paused. At 00:14:59, m=14, paused. At 00:15:00, m=15, not paused. Good. Boundaries match tests.

Weekend gap: At Sunday open ~00:00 server Monday, pause. The side may warn ROLL_STRANDED. At 00:15, one re-roll per tick. Hazard: burst of requests (T-7). Also if the market gaps through many levels, the stranded warning is emitted at 2 add steps past the level. The latch is set. At 00:15, first re-roll success clears latch. If the market is still far beyond, after one re-roll per tick, the loop breaks due to throttle, but no new stranded warning because latch cleared and rerolls>=1? Actually next tick, it will re-roll again. If it fails? We covered. The backlog works one per tick. The danger is request burst. So T-4 NEEDS-FIX or HOLDS? The stale quote bypass is a fix. Also server UTC+3 assumption: The code uses server time from `TimeCurrent()`, which is broker server time. IC server is UTC+3 in summer. The pause window 23:50-00:15 server time. Sunday open is 00:00-00:05 server Monday? Actually IC server UTC+3, market opens Sunday 17:00 EST = 00:00 UTC Monday? Wait FX market opens Sunday 17:00 New York time (EDT UTC-4) = 21:00 UTC Sunday. Server UTC+3 = 00:00 Monday. So yes, open at ~00:00 server Monday. The pause window ends 00:15. So the first 15 minutes after open are paused. That is inside the pause. The ADR says "A side may raise ROLL_STRANDED there: expected." So the weekend gap hazard is known and accepted. The stale quote bypass is not mentioned. I'll mark T-4 NEEDS-FIX for the stale quote, with smallest fix: use `TimeTradeServer()` or `MathMax(TimeCurrent(), TimeTradeServer())` for the pause check. But wait: `TimeCurrent()` is the last quote's server time. If no ticks, OnTick doesn't run, so no re-roll anyway. The only issue is a tick with stale timestamp. In MT5, `TimeCurrent()` is updated on each tick to the tick's time. If a tick arrives with an old timestamp, it's because the broker sent a delayed tick. That could happen. Using `TimeTradeServer()` would use the terminal's current server time, which is more reliable for wall clock. The carry pass uses `TimeTradeServer()`. So fix is to pass `TimeTradeServer()` to `Grind_LatticeOnTick` instead of `TimeCurrent()`. But the ADR says pause 23:50-00:15 server time. `TimeTradeServer()` is server time. So yes.

T-5: We found commanded eject bug. Let's detail.

`Grind_LatticeRerollIndex` does not skip ejected layers:
```
if(!Grind_VLHas(ticket))
   continue;
const double vl = Grind_VLGet(ticket);
```
No `Grind_EjectIsEjected`. `Grind_LatticeRollLayer` with allow_reroll true:
```
const bool was_ejected = Grind_EjectIsEjected(pos);
...
if(layer.exit_order_ticket != 0) {
   if(!Grind_ModifyPendingPrice(...)) ...
   Grind_VLSet(pos, level);
   Grind_EjectOffsetDelete(pos);
   ...
}
```
So it modifies the ejected exit back to the far side and deletes the eject offset. This undoes ADR-155 commanded eject. The operator commanded eject to reduce exposure; the re-roll re-prices the exit away from market, so it won't fill. That is a serious bug. Smallest fix: in `Grind_LatticeRerollIndex`, skip `if(Grind_EjectIsEjected(ticket)) continue;`. Or in `Grind_LatticeRollLayer`, if `allow_reroll && Grind_EjectIsEjected(pos)` return `GRIND_ROLL_CLOSING` or refuse. But skipping in index is better. Also maybe first-roll candidate should skip ejected? ADR-162 first roll also deletes eject offset. But that's existing. For ADR-165, at least re-roll should skip.

Test gap: No test for re-roll after eject. Smallest test: Fixture, set eject offset on layer0, set its exit to eject target (near market), call TryLong with reroll true, assert layer0 not re-rolled, eject offset still present, another layer re-rolled.

Other T-5 interactions:
- Carry pass: likely holds, but if re-roll undoes eject, carry pass? 
- I6: holds.
- Restart: holds.
- ROLL_CLOSING_STUCK: holds.
- Breaker/quarantine: blocked returns early, holds.

T-6: Failures. We noted modify failure handled same. `GRIND_ROLL_CLOSING` handled same. But one rc not handled same? `GRIND_ROLL_ALREADY_ROLLED` for re-roll? allow true skips. For first roll, if candidate has VL, CandidateIndex skips, so won't be called. So no. `GRIND_ROLL_MODIFY_FAILED` same. So T-6 HOLDS. But the failure to emit ROLL_STRANDED on modify failure might be T-3. T-6 asks "Any rc not handled the same as for a first roll?" The rc handling in TrySide is the same for both. So T-6 HOLDS.

T-7: Cost. We'll mark NEEDS-FIX with burst. Let's compute better.

Requests per re-roll: 1 modify if exit resting; exit queue may remove 1 and place 1. If the re-rolled layer had no resting exit, 0 modify, but queue may remove another and place the new one. So 2-3 requests. The ADR says about three requests. At most one re-roll per side per tick. Two sides. 11 instances. So up to 66 requests per tick. FX ticks can be 10-100 per second. A fast market could generate thousands per minute. The 2,000/day budget per account (shared by 11 instances) is tiny. The burst at 00:15 after pause: a weekend gap may have moved many add steps. The backlog clears one re-roll per side per tick. If ticks are frequent, it will drain quickly, but that's a burst of requests. The API counter stops entries only; rolls are not counted against `GRIND_DAILY_API_ENTRY_STOP`. The breaker may not trip. So T-7 BREAKS/NEEDS-FIX. Smallest fix: add a minimum interval between re-rolls per side (e.g., reuse `g_grind_vl_backoff` set to `now + 1` or a configurable `GRIND_VL_REROLL_COOLDOWN_SEC`) or count re-roll requests in the API counter and apply the same hard stop to re-rolls. But the ADR ruled no wind-down brake. A cooldown is not a brake, just rate limit. We can suggest: after a successful re-roll, set a per-side cooldown of a few seconds. That still respects one per call but prevents burst. However, it may delay backlog. But cost safety.

T-8: Tests. We need list missing tests. Let's compile.

- T-3 latch clear: no test.
- T-5 re-roll after commanded eject: no test.
- T-4 stale quote bypass: no test.
- T-7 burst/request count: no test.
- T-6 `GRIND_ROLL_CLOSING` from RollLayer on re-roll (exit order unselectable): no test. RR11 tests closing candidate via `exit_position_ticket !=0`, but not the `exit_order_ticket != 0 && !Grind_SelectOurOrder` path.
- G1 archive schema change: existing ADR-162 suite may not catch new fields. No test asserts absence of `"reroll"` in first-roll detail. So test gap.
- RerollIndex short tie? No test.
- RerollIndex none for short? No.
- Pause with stale quote? No.
- `Grind_LatticeRerollPaused` boundaries tested.
- The throttle after a re-roll when a closing layer exists? Not tested.
- The `from_level` field for first roll? Not tested absence.

Vacuous assertions: The absence assertions `Adr162b_ArchiveFind("ROLL_STRANDED", 0) == ""` (RR4m, RR6h, RR11d) would pass if the function did nothing, but other assertions in the same test ensure it ran. However, as individual assertions, they are vacuous if the function failed early. For example, RR4m could pass if TryLong returned 0 and did nothing, but RR4a expects 1, so the test would fail earlier. So not vacuous in context. We can mention that `Adr162b_ArchiveFind` only searches the archive queue; if `Grind_ArchiveTestConfigureCommon` is not called, it might return ""? But fixtures call it. So fine.

Another potential vacuous: `RR9b` accrual kept passes if TryLong didn't run, but RR9a and RR9c would fail. So not.

Now, need also consider G1 and archive schema. We should include in GIVENS CHECK.

Let's also check G2: Is there any other FATAL before? The reroll FATAL is after lattice validation, before MagicLockClaim. Yes.

G3: The closing refusal still applies. Quote `if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;` and `if(layer.exit_order_ticket != 0 && !Grind_SelectOurOrder(...)) return GRIND_ROLL_CLOSING;`. Good.

G4: The re-roll path calls `Grind_ExitQManageSide`, which may call `Grind_ExitQHoldCancelLayer`, which can `Grind_QueueCloseBy`. But that's not a market order. The requests are modify/remove/place. We can mark VERIFIED with caveat that it can queue a close-by if an exit already filled. But the given says "opens or closes no position". If it queues close-by, it eventually closes a position. But that's an existing exit queue behavior, not the re-roll. I'll mark VERIFIED but note the edge.

G5: Verified.

G6: Verified.

Now, T-1: We should verdict HOLDS? But wait, T-1 mentions "Any path where the next level is computed from a stale value, the same layer is re-rolled twice in a row, or a layer without a resting exit ... is re-priced wrongly (`exit_target` only, no modify)." We found no bug. But let's double-check the "same layer re-rolled twice in a row" with the throttle. After a re-roll, the re-rolled layer becomes lowest VL. If there are multiple rolled layers, next re-roll picks highest VL, different layer. If there is only one layer? At cap max_layers=8, so no. So HOLDS.

But wait: `Grind_LatticeRerollIndex` tie-breaks to lower `layer_index`. What if two layers have the same VL? After a re-roll, the re-rolled layer's VL is set to the new level. Could another layer already have that exact level? Yes, if a previous re-roll set it to the same level? Levels are decreasing for long, so each new re-roll sets a lower level than all previous. So no tie except if a layer was first-rolled to the same level? First rolls set VL to levels computed sequentially. Could tie? Possibly if multiple layers had same entry? But ties broken. Not a bug.

T-1 HOLDS.

T-2: HOLDS? Let's think about `closing_stop` and reset again. There is a scenario where a closing candidate is noted, then on a later call, a re-roll succeeds on a different layer, and then the loop breaks due to throttle before checking the closing candidate. We argued this can't happen because the closing candidate would be highest VL. But what if the closing candidate's VL is not highest because it was ejected? Ejected layer has VL, but its exit is at market. If it's closing? Not. What if the closing candidate is not the highest VL because another layer has higher VL but was not re-rollable? The loop always picks highest VL. So if closing candidate is not highest, it's not picked. It could be noted only if it becomes highest. If it becomes highest, it stays highest until it closes. So a re-roll on another layer can't happen before it is checked. Thus no reset while closing state set. So T-2 HOLDS.

T-3: We'll mark NEEDS-FIX for failure signal / latch. Let's formulate: The latch is cleared on successful re-roll, but on a modify failure or all-layers-closing, `Grind_LatticeMaybeStranded` is not called, so `ROLL_STRANDED` is not emitted (only `ROLL_REFUSED` / `ROLL_CLOSING_STUCK`). If the latch was set from an earlier pause, it remains set, so a later pause also won't warn. Smallest fix: on a re-roll modify failure after backoff (or on entry to backoff), if the latch is clear, call `Grind_LatticeMaybeStranded`? But that would warn immediately, maybe not desired. Or clear the latch on a failed re-roll? The ADR says reset on success. For failure, maybe set it? Actually to ensure later failure warns, you want to clear latch on failure? If latch is set from pause, and then modify fails, you want a new warning. So clear latch when a re-roll is attempted but fails? That would allow MaybeStranded on next pause. But the modify failure itself should warn. The simplest: when `rc == GRIND_ROLL_MODIFY_FAILED` and `is_reroll`, after backoff, call `Grind_LatticeMaybeStranded`? That would emit ROLL_STRANDED on failure. But the code currently breaks. Or just clear the latch on any re-roll attempt (before roll). But then if pause set latch, and at 00:15 modify fails, latch clears, next pause warns. Not immediate. The smallest fix for the stated T-3: clear the stranded latch on any re-roll attempt, not only success, so a later real failure warns afresh. But the ADR says reset when a re-roll succeeds. If we clear on attempt, a failed attempt then next pause warns. That seems okay. But the modify failure itself still doesn't emit ROLL_STRANDED. The threat asks "Is the latch ever left set so that a later real failure ... never warns?" Clearing on attempt fixes that. But the real failure (modify failing) never warns via ROLL_STRANDED anyway. So maybe the missing signal is T-6/GR-5. We'll mention both.

T-4: NEEDS-FIX for stale quote. Smallest fix: use `TimeTradeServer()` for pause.

T-5: BREAKS for commanded eject. Smallest fix: skip ejected layers in `Grind_LatticeRerollIndex`.

T-6: HOLDS, but note no ROLL_STRANDED on modify failure (T-3).

T-7: NEEDS-FIX for cost/burst.

T-8: List test gaps.

Now, PREMISE VERDICT: Is branch safe to merge to main with input OFF, and to switch on for IC fleets after round 1?

With input OFF: Control flow identical, but archive schema changed (`reroll`/`from_level` fields, `LATTICE_CONFIG` field, new print). If downstream telemetry parsers are strict, this could break. Also `Grind_LatticeRollDetail` now always includes those fields. If no strict parsers, safe. The ADR claims byte-identical; not fully. So merge with input OFF is mostly safe but needs a schema check. If we consider G1 FALSE, then not strictly safe. But the prompt asks "Is the branch safe to merge to main with the input OFF". We can say: YES for trading behaviour, NO for byte-identical telemetry; fix the JSON to only add fields when source=="reroll" or when reroll flag true. That is a small fix. So safe with that fix.

Switch on for IC fleets after round 1: NO. Because T-5 commanded eject bug, T-4 stale quote, T-7 cost burst. Also T-3 failure signal. So not safe to enable until fixes.

TEST GAPS: List smallest tests.

Need ensure quotes are exact and cite function. We must use file, function, quote. The prompt says "cite `file`, `function` and QUOTE the line (one line, or part of one)." So for each claim, we need file, function, quote. We'll format like:

`grind_engine.mqh`, `Grind_LatticeTrySide`: `if(!reroll || Grind_LatticeRerollPaused(now)) {`

We need be careful with exact quotes from provided code. Since no line numbers, we can quote a substring.

Let's prepare final answer.

We'll structure:

GIVENS CHECK
- G1: FALSE (control flow verified, but archive schema changed). Quote: `"reroll":%s,"from_level":%s}` in `Grind_LatticeRollDetail`. And `StringFormat("{\"enable\":%s,\"reroll\":%s}", ...)` in OnInit. Also `Print("GRIND_REROLL enable=", InpLatticeReroll);`. Smallest fix: only append fields when `source=="reroll"` or `reroll` true.
- G2: VERIFIED. Quote: `if(!Grind_ValidateRerollInputs(InpVirtualLattice, InpLatticeReroll)) { ... }` before `if(!Grind_MagicLockClaim(InpMagic)) {`.
- G3: VERIFIED. Quote: `if(!allow_reroll) return GRIND_ROLL_ALREADY_ROLLED;` and `if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;`.
- G4: VERIFIED (with caveat). Quote: `if(!Grind_ModifyPendingPrice(...))` and `Grind_ExitQManageSide(side, ...);`. No market order.
- G5: VERIFIED. Quote: `if(!Grind_VLHas(position_ticket)) return entry; return Grind_VLGet(position_ticket);` and `const double vl = Grind_VLGet(ticket);`.
- G6: VERIFIED. Quote: OnTimer has no `Grind_LatticeOnTick`; OnTick has `Grind_LatticeOnTick(...)`.

T-1: HOLDS. Evidence quotes. Smallest fix: none.
T-2: HOLDS. Evidence quotes.
T-3: NEEDS-FIX. Evidence: on modify failure, `break;` without `Grind_LatticeMaybeStranded`; latch cleared only on success `if(is_reroll) { ... g_grind_vl_stranded_warned_long = false; }`. Smallest fix: clear latch on any re-roll attempt, or emit ROLL_STRANDED on repeated re-roll failure. Smallest test.
T-4: NEEDS-FIX. Evidence: `TimeCurrent()` passed in OnTick; `Grind_LatticeRerollPaused` uses server_now. Carry pass uses `TimeTradeServer()`. Smallest fix: pass `TimeTradeServer()` or `MathMax(TimeCurrent(), TimeTradeServer())`. Quote OnTick: `TimeCurrent(),` and OnTimer: `const datetime carry_now = TimeTradeServer();`.
T-5: BREAKS. Evidence: `Grind_LatticeRerollIndex` doesn't check `Grind_EjectIsEjected`; `Grind_LatticeRollLayer` deletes offset `Grind_EjectOffsetDelete(pos);`. Smallest fix: skip ejected in RerollIndex.
T-6: HOLDS. Evidence: modify fail returns before VLSet; TrySide handles same backoff. Quote `if(!Grind_ModifyPendingPrice(...)) { ... return GRIND_ROLL_MODIFY_FAILED; }` and `if(rc == GRIND_ROLL_MODIFY_FAILED) { ... }`. Smallest fix: none (except T-3 signal).
T-7: NEEDS-FIX. Evidence: no request count on rolls; `GRIND_DAILY_API_ENTRY_STOP` is entries only. Quote `if(!enabled || blocked) return 0;` and no API counter check. Smallest fix: add cooldown or count.
T-8: Test gaps. List.

Need also mention T-8 vacuous assertions. For example, `RR4m` absence assertion passes if no roll, but other assertions cover. The main missing tests: latch clear, re-roll after eject, stale quote, request burst, RollLayer closing from unselectable exit. Also no test for first-roll archive schema absence.

Let's ensure we don't miss T-2 potential bug with `closing_stop` reset. We'll state HOLDS with reasoning.

Now, let's write final answer with appropriate brevity but exhaustive. Desired oververbosity 5. The answer will be long but structured.

We need include quotes exactly. Let's copy exact lines.

For G1 fix quote:
`Grind_LatticeRollDetail` in `grind_engine.mqh`:
`"\"reroll\":%s,\"from_level\":%s}",`
Actually the line is:
```
"\"rolled\":%d,\"was_ejected\":%s,\"source\":\"%s\","
"\"reroll\":%s,\"from_level\":%s}",
```
We can quote: `"\"reroll\":%s,\"from_level\":%s}"`.

OnInit:
`StringFormat("{\"enable\":%s,\"reroll\":%s}",`
and `Print("GRIND_REROLL enable=", InpLatticeReroll);`

G2:
`if(!Grind_ValidateRerollInputs(InpVirtualLattice, InpLatticeReroll)) {`
`if(!Grind_MagicLockClaim(InpMagic)) {`

G3:
`if(!allow_reroll)`
`return GRIND_ROLL_ALREADY_ROLLED;`
`if(layer.exit_position_ticket != 0)`
`return GRIND_ROLL_CLOSING;`

G4:
`if(!Grind_ModifyPendingPrice(layer.exit_order_ticket, price, magic)) {`
`Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);`

G5:
`if(!Grind_VLHas(position_ticket))`
`return entry;`
`return Grind_VLGet(position_ticket);`
`const double vl = Grind_VLGet(ticket);`

G6:
OnTimer: no quote needed, but we can quote the absence? We can quote OnTick: `Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice,` and OnTimer: `Grind_CarryOnTimerStep(...)` no lattice. We can say OnTimer has no `Grind_LatticeOnTick`.

T-1:
`const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));` recomputed each loop.
`idx = Grind_LatticeRerollIndex(side, is_long);`
`Grind_VLSet(pos, level);`
`else` branch for no exit: `side.layers[idx].exit_target = formula;` then `Grind_ExitQManageSide`.

T-2:
`if(reroll && rerolls >= 1) break;`
`if(side.layers[idx].exit_position_ticket != 0) { Grind_LatticeNoteClosing(...); closing_stop = true; break; }`
`if(!closing_stop) Grind_LatticeResetClosingState(is_long);`

T-3:
`if(is_reroll) { rerolls++; if(is_long) g_grind_vl_stranded_warned_long = false; ... }`
On modify fail: `if(rc == GRIND_ROLL_MODIFY_FAILED) { ... break; }` no MaybeStranded.
MaybeStranded early return: `if(g_grind_vl_stranded_warned_long) return;`

T-4:
OnTick: `InpMaxLayers, g_grind_halted || g_grind_quarantined, TimeCurrent(),`
`Grind_LatticeRerollPaused(const datetime server_now)`
`const int m = t.hour * 60 + t.min; return (m >= 23 * 60 + 50) || (m < 15);`
Carry: `const datetime carry_now = TimeTradeServer();`

T-5:
RerollIndex: `if(!Grind_VLHas(ticket)) continue;` no eject check.
RollLayer: `Grind_EjectOffsetDelete(pos);`
`const bool was_ejected = Grind_EjectIsEjected(pos);` only record.

T-6:
`if(!Grind_ModifyPendingPrice(layer.exit_order_ticket, price, magic)) { ... return GRIND_ROLL_MODIFY_FAILED; }`
`if(rc == GRIND_ROLL_MODIFY_FAILED) { ... break; }`
`if(rc == GRIND_ROLL_CLOSING) { Grind_LatticeNoteClosing(...); closing_stop = true; }`

T-7:
`if(!enabled || blocked) return 0;` no request budget.
`GRIND_DAILY_API_ENTRY_STOP 1900 // hard stop, entries only`
`Grind_ApiCounterEntryStopped()` entries only.

T-8:
Tests: `AssertTrue("RR4m (F)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");` vacuous if nothing ran, but covered.
Missing: latch clear, eject, stale quote, burst, RollLayer closing.

Now write final. Ensure no preamble. Use sections. Keep line count not relevant. We'll answer in final.

## Final Report

## GIVENS CHECK

**G1 — FALSE (control flow VERIFIED; archive/telemetry NOT byte-identical).**  
The new block reduces to the old strand-and-break: `grind_engine.mqh`, `Grind_LatticeTrySide`: `if(!reroll || Grind_LatticeRerollPaused(now)) {` and the first-roll call passes `is_reroll`, which is false when the input is off: `Grind_LatticeRollLayer(..., roll_source, is_reroll);`. But the archive schema changes for every first roll: `grind_engine.mqh`, `Grind_LatticeRollDetail`: `"\"reroll\":%s,\"from_level\":%s}"`, and `fxgrind.mq5`, `OnInit`: `StringFormat("{\"enable\":%s,\"reroll\":%s}", ...)` plus `Print("GRIND_REROLL enable=", InpLatticeReroll);`. So first-roll `ROLL_ACCEPTED` now carries `"reroll":false,"from_level":0.0`. Smallest fix: emit the new fields only when `source=="reroll"` or when `reroll==true`.

**G2 — VERIFIED.**  
`fxgrind.mq5`, `OnInit`: `if(!Grind_ValidateRerollInputs(InpVirtualLattice, InpLatticeReroll)) {` appears before `if(!Grind_MagicLockClaim(InpMagic)) {`.

**G3 — VERIFIED (with the extra `"reroll"` flag).**  
`grind_engine.mqh`, `Grind_LatticeRollLayer`: `if(!allow_reroll) return GRIND_ROLL_ALREADY_ROLLED;` and `if(layer.exit_position_ticket != 0) return GRIND_ROLL_CLOSING;`. The closing refusal still applies. The only other recording difference is the bool passed into the detail as `reroll`.

**G4 — VERIFIED (edge caveat).**  
`grind_engine.mqh`, `Grind_LatticeRollLayer`: the only broker request in the roll itself is `if(!Grind_ModifyPendingPrice(layer.exit_order_ticket, price, magic)) {`; then `Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);` does the remove/place. No market order is sent. Caveat: `Grind_ExitQManageSide` can queue a close-by if it discovers an already-filled exit, but that is exit-queue repair, not a market order from the re-roll.

**G5 — VERIFIED.**  
`grind_carry.mqh`, `Grind_EffectiveEntry`: `if(!Grind_VLHas(position_ticket)) return entry; return Grind_VLGet(position_ticket);`. `grind_engine.mqh`, `Grind_LatticeRerollIndex`: `const double vl = Grind_VLGet(ticket);`.

**G6 — VERIFIED.**  
`fxgrind.mq5`, `OnTick` calls `Grind_LatticeOnTick(...)`; `OnTimer` does not. The timer path has `Grind_CarryOnTimerStep(...)` but no lattice call.

## T-1 — Wrong layer or wrong level

**Verdict: HOLDS.**  
The level is recomputed every loop iteration: `grind_engine.mqh`, `Grind_LatticeTrySide`: `const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));`. After a re-roll, `Grind_LatticeRollLayer` sets `Grind_VLSet(pos, level);`, so the next iteration’s `Grind_ComputeAddTarget` anchors on the new lowest effective entry and steps down by `add`. The re-rolled layer becomes lowest, and `Grind_LatticeRerollIndex` picks `const double vl = Grind_VLGet(ticket);` highest for long, so the same layer is not selected twice consecutively while other rolled layers exist. A layer with no resting exit is handled by the `else` branch: `side.layers[idx].exit_target = formula;` followed by `Grind_ExitQManageSide(...)`, which places the required rank-0 exit. No fix required.

## T-2 — Loop control

**Verdict: HOLDS.**  
The throttle is explicit: `grind_engine.mqh`, `Grind_LatticeTrySide`: `if(reroll && rerolls >= 1) break;`. The closing stop is explicit: `if(side.layers[idx].exit_position_ticket != 0) { Grind_LatticeNoteClosing(...); closing_stop = true; break; }`, and the post-loop reset is guarded: `if(!closing_stop) Grind_LatticeResetClosingState(is_long);`. Backoff failures break with the same `break;` pattern as first rolls. `rolled_count` counts both first rolls and re-rolls, but the callers ignore it in production; tests use it only as a count. No fix required.

## T-3 — The stranded latch

**Verdict: NEEDS-FIX.**  
The latch is cleared only on a successful re-roll: `grind_engine.mqh`, `Grind_LatticeTrySide`: `if(is_reroll) { rerolls++; if(is_long) g_grind_vl_stranded_warned_long = false; ... }`. On a modify failure the code breaks without calling `Grind_LatticeMaybeStranded`: `if(rc == GRIND_ROLL_MODIFY_FAILED) { ... break; }`. On an all-closing candidate it stops via `Grind_LatticeNoteClosing` and `closing_stop = true;`, not via `MaybeStranded`. So a real re-roll failure can produce only `ROLL_REFUSED` / `ROLL_CLOSING_STUCK`, not `ROLL_STRANDED`. If the latch was already set from a pause, `Grind_LatticeMaybeStranded` returns early: `if(g_grind_vl_stranded_warned_long) return;`, so a later pause also stays silent.  
Smallest fix: clear the stranded latch on any re-roll attempt (or on a failed re-roll after backoff), and/or emit `ROLL_STRANDED` when a re-roll fails after backoff.  
Smallest test: set `g_grind_vl_stranded_warned_long = true`, perform a successful re-roll, assert the latch is false, then simulate a pause and assert `ROLL_STRANDED` is present again.

## T-4 — The pause and server time

**Verdict: NEEDS-FIX.**  
`fxgrind.mq5`, `OnTick` passes `TimeCurrent()`: `InpMaxLayers, g_grind_halted || g_grind_quarantined, TimeCurrent(),`. `TimeCurrent()` is the last quote’s server time, not the current server clock. The carry pass uses `TimeTradeServer()`: `const datetime carry_now = TimeTradeServer();`. A tick stamped before 23:50 but delivered after 23:50 can therefore bypass the pause: `grind_pure.mqh`, `Grind_LatticeRerollPaused`: `return (m >= 23 * 60 + 50) || (m < 15);`. The Sunday-open assumption is as stated: IC UTC+3 puts the open around 00:00–00:05 Monday server, inside the pause; the side may warn `ROLL_STRANDED` until 00:15, then one re-roll per tick drains the backlog.  
Smallest fix: use `TimeTradeServer()` (or `MathMax(TimeCurrent(), TimeTradeServer())`) for the pause check.

## T-5 — Interactions

**Verdict: BREAKS.**  
ADR-155 commanded eject is undone by a later re-roll. `grind_engine.mqh`, `Grind_LatticeRerollIndex` filters only on VL presence: `if(!Grind_VLHas(ticket)) continue;` — it never checks `Grind_EjectIsEjected`. `Grind_LatticeRollLayer` then records `const bool was_ejected = Grind_EjectIsEjected(pos);` but still proceeds to modify the ejected exit back to the far side and deletes the offset: `Grind_EjectOffsetDelete(pos);`. That cancels the commanded eject and re-prices the exit away from the market. The nightly carry pass, I6, restart/reconstruction, `ROLL_CLOSING_STUCK`, and breaker/quarantine otherwise appear compatible: carry and I6 derive from `Grind_EffectiveEntry`, and `blocked` returns early in `Grind_LatticeOnTick`.  
Smallest fix: in `Grind_LatticeRerollIndex`, skip ejected layers: `if(Grind_EjectIsEjected(ticket)) continue;`.  
Smallest test: fixture, set an eject offset on the highest-VL layer, call `Adr165_TryLong(..., true)`, assert that layer was not re-rolled and its eject offset still exists.

## T-6 — Failures

**Verdict: HOLDS (with T-3 signal gap).**  
A modify failure on a re-roll returns before overwriting the VL: `grind_engine.mqh`, `Grind_LatticeRollLayer`: `if(!Grind_ModifyPendingPrice(...)) { ... return GRIND_ROLL_MODIFY_FAILED; }`. `Grind_LatticeTrySide` handles it identically to a first roll: `if(rc == GRIND_ROLL_MODIFY_FAILED) { ... break; }`. A `GRIND_ROLL_CLOSING` return from inside the roll is also handled identically: `if(rc == GRIND_ROLL_CLOSING) { Grind_LatticeNoteClosing(...); closing_stop = true; }`. No rc handling differences found. The only gap is that a failed re-roll does not produce `ROLL_STRANDED` (covered under T-3).

## T-7 — Cost

**Verdict: NEEDS-FIX.**  
A re-roll costs about three requests: one modify, plus the exit queue’s remove/place. The throttle is per call, not per time: `grind_engine.mqh`, `Grind_LatticeTrySide`: `if(reroll && rerolls >= 1) break;`. Two sides × eleven instances × three requests = up to 66 requests per tick. The existing hard stop is entries only: `grind_config.mqh`: `#define GRIND_DAILY_API_ENTRY_STOP    1900  // hard stop, entries only`. Rolls are not counted against it. The 00:15 post-pause burst is exactly the worst case: a weekend gap can leave a multi-level backlog, and the code drains it one re-roll per side per tick.  
Smallest fix: add a per-side minimum interval between re-rolls (e.g., set `g_grind_vl_backoff_long = now + N` after a successful re-roll) or count re-roll requests in the API counter and stop re-rolls when the daily budget is exhausted.

## T-8 — Tests

**Verdict: INCOMPLETE.**  
Tests that pass vacuously only in isolation: `fxgrind_tests_adr165.mqh`, `Test_RR4_SingleRerollLong`: `AssertTrue("RR4m (F)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");` would pass if nothing ran, but RR4a/RR4j would fail earlier. Same for RR6h and RR11d. The fixture resets the stranded latch and closing ticket through `Adr162b_Reset` → `Grind_LatticeResetBackoff()`, so no obvious leftover-state vacuity.

Missing tests that should fail without the behaviour:

1. **T-3 latch clear.** No test sets `g_grind_vl_stranded_warned_long = true`, performs a successful re-roll, then asserts the latch is false and a later pause re-warns.
2. **T-5 re-roll after commanded eject.** No test checks that `Grind_LatticeRerollIndex` skips an ejected layer or that `Grind_EjectOffsetDelete` is not reached on a re-roll.
3. **T-4 stale quote / pause bypass.** No test passes a `now` before 23:50 while a carry-window timer is active and asserts no re-roll.
4. **T-6 `GRIND_ROLL_CLOSING` from an unselectable exit on a re-roll.** RR11 covers `exit_position_ticket != 0`; it does not cover `layer.exit_order_ticket != 0 && !Grind_SelectOurOrder(...)` inside `Grind_LatticeRollLayer`.
5. **T-7 request burst.** No test bounds re-roll requests per minute or per day.
6. **G1 archive schema.** No test asserts that a first-roll `ROLL_ACCEPTED` does **not** contain `"reroll":false` or `"from_level":0.0` when the input is off.

## PREMISE VERDICT

**Merge to `main` with `InpLatticeReroll=false`: safe only after the G1 archive/telemetry schema fix.**  
Trading control flow is unchanged, and `allow_reroll` is false at every call site when the input is off. But first-roll `ROLL_ACCEPTED` and `LATTICE_CONFIG` now carry new fields, so the ADR’s “byte-identical” claim is false. If downstream parsers tolerate the extra fields, the OFF path is operationally safe; otherwise fix `Grind_LatticeRollDetail` to append the new fields only for `source=="reroll"`.

**Switch on for the IC fleets after round 1: not safe yet.**  
The branch has a real ADR-155 interaction break (T-5), a pause-bypass path via `TimeCurrent()` (T-4), and an unbounded re-roll request burst (T-7). T-3 also weakens the failure signal. Fix T-5 (skip ejected in `Grind_LatticeRerollIndex`), T-4 (use `TimeTradeServer()` for the pause), T-7 (rate-limit or budget re-roll requests), and T-3 (latch/failure signal) before enabling on IC.

<!-- finish_reason=stop -->
