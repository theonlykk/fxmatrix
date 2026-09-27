# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit. Need obey user asks sections. Need exhaustive, cite file/function quote line. Need identify lookahead/silent/schema/statistical flaws? But task specifically GIVENS, T-1..T-7, premise, test gaps. We must audit code provided. We need reason.

Need parse. We need produce final with sections. Need be accurate.

Let's understand system and v2. Need verify G1-G5, threats.

We have code snippets.

Key pure:
```
double Grind_SidePips(const bool is_long, const double long_or_both,
                      const double short_value)
{
   return (!is_long && short_value > 0.0) ? short_value : long_or_both;
}
```
G1 true.

G2: every new parameter defaults 0.0. Need check dispatch functions listed. Some have `=0.0` in signatures. Need quote. We can cite each? Maybe not all but need verify. Need ensure every new param default 0.0 for thirteen plus? The prompt says thirteen dispatch functions plus. In code:
- Grind_EjectPollCommand(... const double exit_pips_short = 0.0) yes.
- Grind_AutoEjectOnTick(... const double exit_pips_short = 0.0) yes.
- Grind_LatticeOnTick(... const double exit_pips_short = 0.0, const double add_pips_short = 0.0) yes.
- Grind_CarryExitPassBegin(... const double exit_pips_short = 0.0) yes.
- Grind_CarryWorkBase(... const double exit_pips_short = 0.0) yes.
- Grind_CarryOnTimerStep(... const double exit_pips_short = 0.0) yes.
- Grind_CarryExitPassStep(... const double exit_pips_short = 0.0) yes.
- Grind_OnTickEngine(... const double width_pips_short = 0.0, const double add_pips_short = 0.0) yes.
- Grind_ServiceDueAddFlags(... const double add_pips_short = 0.0) yes.
- Grind_OnTradeTransactionEngine(... const double exit_pips_short = 0.0, const double add_pips_short = 0.0) yes.
- Grind_ReconCheckInvariants(... const bool tolerate_exit_shortfall = false, const double exit_pips_short = 0.0) Wait new param after default tolerate. yes.
- Grind_RebuildBookFromTicketsInner(... const bool tolerate_exit_shortfall = false, const double exit_pips_short = 0.0) yes.
- Grind_RebuildBookFromTickets(... const bool tolerate_exit_shortfall = false, const double exit_pips_short = 0.0) yes.
Also Grind_AutoEjectTrySide? It takes exit_pips only no short; called with side_exit. Not dispatch? Prompt thirteen doesn't include? It has no new param. Good.

G3: all six inputs -1 -> base. `Grind_ResolveSideInput`:
```
if(MathAbs(override_value + 1.0) <= 1e-9) out_value=base; return true;
if(override_value >0)...
```
So yes all -1 equals base. Need note exactly -1 with tolerance.

G4: inner functions unchanged. Need check list. We can't compare to main, but code has functions. Need verify no per-side params in them. We can quote signatures. Need decide if any changed? The prompt says none changed. In provided code, inner functions still one value: Grind_ExitPrice(entry, exit_pips, point, direction); Grind_AddTargetPrice(anchor_entry, add_pips,...); Grind_ExitQFormulaTarget(entry, exit_pips, point, is_long, position_ticket); Grind_ComputeAddTarget(side,is_long,add_pips); Grind_SendNextAddEnt(... add_pips,...); Grind_EnsureAddNext(... add_pips,...); Grind_LatticeTrySide(... exit_pips, add_pips,...); Grind_LatticeRollLayer(... exit_pips,...); Grind_ExitQManageSide(... exit_pips); Grind_EjectAcceptLayer(... exit_pips,...). Yes no new param. G4 verified.

G5: fxgrind passes long old slots and short new at every engine call in OnInit, OnTick, OnTimer, OnTradeTransaction. Need inspect. OnInit:
- Grind_RetryMissingExits(InpMagic, InpSlot, InpLots) - this function uses globals, no side params. But prompt mentions G5 every engine call in OnInit? `Grind_RetryMissingExits` no long/short args. It reads globals set earlier. Need maybe okay.
- `Grind_CarryEmitSnapshot(_Symbol, InpMagic);` no.
- `Grind_SessionStep` no side.
- `Grind_CarryPruneShiftGvs` no.
No direct dispatch with width/add/exit except? OnInit doesn't call OnTickEngine etc. But it calls `Grind_RetryMissingExits` after globals set. Need G5 maybe true for calls that have slots. OnTimer:
```
Grind_CarryOnTimerStep(_Symbol, InpMagic, g_geo_exit_long, InpEnableCarryPass, carry_now,
                             g_geo_exit_short);
```
passes long old, short new. OnTick:
```
Grind_EjectPollCommand(InpMagic, InpEnableCommandedEject, g_geo_exit_long,
                          g_grind_halted || g_grind_quarantined, g_geo_exit_short);
   Grind_AutoEjectOnTick(InpMagic, InpAutoEject, g_geo_exit_long, InpMaxLayers,
                         g_grind_halted || g_grind_quarantined,
                         InpAutoEjectStableMinutes, InpAutoEjectSpreadMult,
                         g_geo_exit_short);
   Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice,
                       g_geo_exit_long, g_geo_add_long,
                       InpMaxLayers, g_grind_halted || g_grind_quarantined, TimeCurrent(),
                       g_geo_exit_short, g_geo_add_short);
...
Grind_OnTickEngine(InpMagic,
                      InpSlot,
                      g_geo_width_long,
                      g_geo_exit_long,
                      g_geo_add_long,
                      InpStrandedThreshPips,
                      InpDeadbandPips,
                      InpMaxLayers,
                      InpLots,
                      g_geo_width_short,
                      g_geo_add_short);
```
Order for OnTickEngine parameters: (magic, slot, width_pips, exit_pips, add_pips, stranded, deadband, max, lots, width_pips_short, add_pips_short). They pass exit long in old exit slot? Wait OnTickEngine signature: width_pips, exit_pips, add_pips, ... width_short, add_short. No exit_short! Interesting. OnTickEngine does not take exit_pips_short. It only computes width_s/add_s and calls RetryMissingExits which uses global recon_exit_pips_short. It uses exit_pips only where? Let's inspect OnTickEngine body: it doesn't use exit_pips except maybe? Search within function: no exit_pips? It calls Grind_RetryMissingExits(magic, slot, lots) which uses globals. It does not use exit_pips. So OnTickEngine not needing exit_short. Good.

OnTradeTransaction passes exit long, add long, ..., exit short, add short. Signature: (trans, magic, slot, exit_pips, add_pips, deadband, max, lots, exit_pips_short, add_pips_short). Yes.

G5: engine call in OnInit? `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);` no params. But "every engine call" maybe includes this. It doesn't pass long/short because uses globals set. Need mention.

Now threats.

T-1 missed site. Need hunt every path that prices SHORT-side with long/base. Need follow callers. We have code. Need inspect all functions and calls. Find potential missed wiring.

Key list:
- `Grind_ExitPrice`: called in:
  - `Grind_EjectAcceptLayer` with exit_pips passed from caller. Callers:
    - `Grind_EjectPollCommand` computes side_exit = Grind_SidePips(is_long, exit_pips, exit_pips_short); passes to EjectAcceptLayer. Good for short if exit_pips_short >0. But note if exit_pips_short default 0, side_exit=long_or_both. That's intended inherit.
    - `Grind_AutoEjectTrySide` receives exit_pips (already side-specific? Call sites in AutoEjectOnTick: long passes exit_pips (long), short passes exit_s computed). Then passes to EjectAcceptLayer. Good.
  - `Grind_LatticeRollLayer`: computes formula = Grind_ExitPrice(level, exit_pips,...). Called from `Grind_LatticeTrySide` with exit_pips param. `Grind_LatticeTrySide` called from LatticeOnTick for long with exit_pips, short with exit_s computed. Good. Also cost uses `Grind_LatticeRollCost(entry, level, exit_pips,...)`, uses same exit_pips. Good.
  - `Grind_LatticeRollCost` in pure: calls Grind_ExitPrice.
  - `Grind_CarryWorkBase`: computes side_exit = Grind_SidePips(dir >0, exit_pips, exit_pips_short). Good. Called from CarryExitPassStep with exit_pips and short. Good.
  - `Grind_CarryExitPassBegin`: builds work formula for long using exit_pips; short uses `const double short_exit = Grind_SidePips(false, exit_pips, exit_pips_short);` inside loop. Good.
  - `Grind_ReconExitMatchesEntry` and `Grind_InvariantDetailI6`: use exit_pips passed from ReconCheckInvariants; short uses exit_s computed. Good.
  - `Grind_RebuildBookFromTicketsInner`: uses exit_s for short fallback exit targets; passes exit_pips_short to ReconCheckInvariants. Good.
  - `Grind_ExitQFormulaTarget`: called in:
    - `Grind_AppendLayer`: with exit_pips passed to HandleSideDealFill. HandleSideDealFill called from OnTradeTransactionEngine for long with exit_pips and short with exit_s. Good.
    - `Grind_ExitQManageSide`: uses exit_pips passed. Callers:
       - HandleSideDealFill after append/close, passes its exit_pips (side-specific). Good.
       - LatticeRollLayer calls `Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips)` with side-specific exit_pips? LatticeRollLayer called from LatticeTrySide with side-specific exit_pips. Good.
       - RetryMissingExits calls long with g_grind_recon_exit_pips, short with exit_s. Good.
       - Maybe others? Need search in code. Also `Grind_ExitQManageSide` called in `Grind_HandleSideDealFill`. Good.
    - `Grind_RebuildBookFromTicketsInner` fallback for long/short: long uses exit_pips, short uses exit_s. Good.
  - `Grind_CarryShiftedExitPrice` not.

- `Grind_AddTargetPrice`: called in `Grind_LatticeMaybeStranded` with add_pips passed from LatticeTrySide side-specific; in `Grind_ComputeAddTarget` with add_pips passed. `Grind_ComputeAddTarget` callers:
  - `Grind_ApplyEntryHorizon` with add_pips. Called from `Grind_TryPlaceAddAtFill` and `Grind_EnsureAddNext`. Need ensure short side passes short add. `Grind_TryPlaceAddAtFill` called from HandleSideDealFill with `fill_add` computed side-specific:
```
const double fill_add = is_long ? g_grind_engine_add_pips
                                : Grind_SidePips(false, g_grind_engine_add_pips,
                                                 g_grind_engine_add_pips_short);
Grind_TryPlaceAddAtFill(side, is_long, ..., fill_add,...)
```
Good. `Grind_EnsureAddNext` callers:
  - OnTickEngine long with add_pips, short with add_s. Good.
  - ServiceDueAddFlags: long with add_pips, short with add_s. Good.
  - `Grind_EnsureAddNext` itself calls `Grind_ApplyEntryHorizon` with add_pips, and SendNextAddEnt with add_pips. Good if passed side-specific.
  - `Grind_ApplyEntryHorizon` also maybe called from TryPlaceAddAtFill only. Good.
  - `Grind_SendNextAddEnt` callers: ApplyEntryHorizon, EnsureAddNext, ServiceDueAddFlags, TryPlaceAddAtFill. All pass side-specific? Need check `Grind_ApplyEntryHorizon` call sites: in TryPlaceAddAtFill with add_pips side-specific; in EnsureAddNext with add_pips side-specific. Good.
  - `Grind_SendNextAddEnt` is inner and uses add_pips.
  - `Grind_AddTargetNearMarket` uses add_pips passed. Good.
  - `Grind_LatticeMaybeStranded` uses add_pips passed from LatticeTrySide side-specific. Good.

- `Grind_StraddleSellPrice`: called in `Grind_TryRecenterOppositeL0` with width_pips param. Caller in OnTickEngine:
```
if(long depth>0 && short depth==0)
  Grind_TryRecenterOppositeL0(g_grind_short, false, mid, ..., width_s,...)
if(short depth>0 && long depth==0)
  Grind_TryRecenterOppositeL0(g_grind_long, true, mid, ..., width_pips,...)
```
For short opposite, passes width_s; for long passes width_pips. Good. Also OnTickEngine L0 sell uses width_s.

- `Grind_EjectAcceptLayer`: uses exit_pips passed. Good.

- `Grind_EjectTargetPrice`: uses market only no width/exit.

- `Grind_TryPlaceAddAtFill`: uses add_pips passed from fill_add side-specific. But wait `g_grind_engine_add_pips_short` set in OnTradeTransactionEngine before HandleSideDealFill. In HandleSideDealFill uses global. Good. But `Grind_OnTickEngine` also sets `g_grind_engine_add_pips` and short. But if OnTradeTransaction happens before OnTick? We'll examine T-3.

Potential missed site: `Grind_AutoEjectOnTick` computes `exit_s` only inside if short depth >= max. Good. But `Grind_AutoEjectTrySide` for short receives exit_s. Good.

Potential missed site: `Grind_AutoEjectOnTick` long side uses `exit_pips` without SidePips? For long, SidePips would return long_or_both, so same. Good.

Potential missed site: `Grind_EjectPollCommand` uses `Grind_SidePips(is_long, exit_pips, exit_pips_short)` after validation. Good.

Potential missed site: `Grind_CarryExitPassBegin`: for short, short_exit computed inside loop. But `g_grind_carry_exit_work_formula` stores formula with EjectOffsetGet, not accrued? Actually formula = ExitPrice(effective entry, short_exit, point,-1)+EjectOffsetGet. WorkBase later also adds EjectOffsetGet. Good.

Potential missed site: `Grind_CarryExitPassBegin` long formula uses `Grind_EffectiveEntry` and `exit_pips`; short uses short_exit. Good.

Potential missed site: `Grind_CarryWorkBase` uses `dir >0` as is_long. Good.

Potential missed site: `Grind_CarryExitShiftLayer`: `shift_exit` parameter is passed from CarryExitPassStep computed `Grind_SidePips(g_grind_carry_exit_work_long[idx], exit_pips, exit_pips_short)`. But inside CarryExitShiftLayer, it uses `formula_exit` passed from WorkBase. It also computes `swap_points` based on is_long for pending pips, independent. It uses exit_pips? Actually signature includes `const double exit_pips` but in body? Let's scan: in CarryExitShiftLayer parameters: (..., const double exit_pips, bool &clamped_out...). Does it use exit_pips? I don't see it! It uses `formula_exit` argument, not exit_pips. Wait `shift_exit` passed as `exit_pips` to CarryExitShiftLayer but unused? Let's inspect:
```
bool Grind_CarryExitShiftLayer(const ulong position_ticket,
                               const ulong exit_order_ticket,
                               const double entry_price,
                               const double formula_exit,
                               const bool is_long,
                               const int layer_index,
                               const ulong magic,
                               const string symbol,
                               const double exit_pips,
                               bool &clamped_out,
...
```
Inside: uses `formula_exit`, `is_long`, entry_price, no `exit_pips`. Indeed `exit_pips` unused. But formula_exit from WorkBase already side-specific. So fine but dead parameter. Could mention T-1? It doesn't price with wrong value because unused. But the call passes side-specific anyway.

Potential missed site: `Grind_CarryExitPassBegin` short formula uses `short_exit` computed inside loop each iteration; okay.

Potential missed site: `Grind_CarryOnTimerStep`: emits snapshot then step; passes exit_pips_short to step. Good.

Potential missed site: `Grind_RetryMissingExits`: computes exit_s and passes long/short. Good.

Potential missed site: `Grind_ReconCheckInvariants`: short uses exit_s. Good. But note `Grind_InvariantDetailI6` call for short passes `exit_s` in failure detail. Good.

Potential missed site: `Grind_ReconFailureOffendingForReason`: reason strings for I6_SHORT_EXIT? It checks reason == "I6_SHORT_EXIT" but actual failure reason includes fill-adverse "I6_SHORT_EXIT_FILL_ADVERSE"? Wait ReconCheckInvariants sets reason `i6_reason = short_exit_filled ? "I6_SHORT_EXIT_FILL_ADVERSE" : "I6_SHORT_EXIT";`. `Grind_ReconFailureOffendingForReason` only handles "I6_SHORT_EXIT" not FILL_ADVERSE. That is unrelated to v2? Maybe existing bug. Not threat? Could mention test gap? But task is v2.0 per-side. Focus.

Potential missed site: `Grind_RebuildBookFromTicketsInner`: `exit_s` computed at top, passed to ReconCheckInvariants. But note it calls `Grind_ReconExitMatchesEntry` via ReconCheckInvariants with `exit_s`. Good.

Potential missed site: In `Grind_RebuildBookFromTicketsInner`, for short fallback exit target when no exit coverage:
```
short_out.layers[n].exit_target =
            Grind_ExitQFormulaTarget(short_scratch[j].entry_price, exit_s, point, false,
                                     short_scratch[j].position_id);
```
Good.

Potential missed site: `Grind_CheckBookInvariants` passes `g_grind_recon_exit_pips_short` as new param. `Grind_ReconstructState` same. Good. Set in OnInit. Good.

Potential missed site: `Grind_HandleSideDealFill` for EXT fill: doesn't price exit. For ENT fill uses exit_pips passed. Good.

Potential missed site: `Grind_OnTickEngine` computes `sell_target = Grind_StraddleSellPrice(mid, width_s, _Point);` good. `buy_target` long. `Grind_TryPlaceL0` uses target_price. Good.

Potential missed site: `Grind_TryRecenterOppositeL0` for short uses `Grind_StraddleSellPrice(current_mid, width_pips, _Point)`. Caller passes width_s for short. Good.

Potential missed site: `Grind_EjectAcceptLayer` offset uses `Grind_ExitPrice(Grind_EffectiveEntry(...), exit_pips,...)` where exit_pips passed side-specific. Good. But `target` for eject is `Grind_EjectTargetPrice(is_long)` market-based. The offset calculation uses raw exit with side exit. Good.

Potential missed site: `Grind_LatticeTrySide` `Grind_LatticeMaybeStranded(side, is_long, level, mkt, add_pips,...)` uses side add. Good.

Potential missed site: `Grind_LatticeRollLayer` `Grind_LatticeRollCost(entry, level, exit_pips,...)` uses side exit. Good. `Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips)` after roll uses side exit. Good.

Potential missed site: `Grind_AutoEjectTrySide` when `Grind_EjectIsEjected(position_ticket)` uses `Grind_EjectTargetPrice` and `Grind_CarryMinPassiveDistance` no exit. Good.

Potential missed site: `Grind_AutoEjectOnTick` builds vals_short = high+spread, etc. no exit.

Potential missed site: `Grind_EjectPollCommand` validation: side_exit computed after validation. Good.

Potential missed site: `Grind_ServiceDueAddFlags` computes add_s before use. Good.

Potential missed site: `Grind_OnTradeTransactionEngine` sets `g_grind_engine_add_pips = add_pips; g_grind_engine_add_pips_short = Grind_SidePips(false, add_pips, add_pips_short);` then handles long with exit_pips, short with exit_s. Good.

Potential missed site: `Grind_OnTickEngine` sets `g_grind_engine_add_pips = add_pips; g_grind_engine_add_pips_short = add_s;` then calls RetryMissingExits (uses recon globals, not engine add). But `g_grind_engine_add_pips_short` used in HandleSideDealFill. OnTick could overwrite with same. Good.

Potential missed site: if `Grind_OnTickEngine` returns early due GuardsAllowTrading false, it doesn't set `g_grind_engine_add_pips_short` for this tick. But OnTradeTransaction sets it before fill. So okay.

Potential missed site: `Grind_TryPlaceAddAtFill` uses `g_grind_engine_add_pips_short` global. If fill event processed before any OnTick/OnTradeTransaction? OnTradeTransaction sets it immediately before HandleSideDealFill, so no. But if some other caller invokes HandleSideDealFill? Only OnTradeTransactionEngine. Good. Tests might call directly? In tests GV? They call OnTradeTransactionEngine. Good.

Potential missed site: `Grind_HandleSideDealFill` for EXT fill uses no exit. But after EXT fill? It doesn't call ExitQManageSide. Wait for EXT DEAL_ENTRY_IN, it sets exit_position_ticket and queues closeby, returns. It does not manage exits. Fine.

Potential missed site: `Grind_TryPlaceExitForLayer` uses `layer.exit_target`, which was set by AppendLayer/ExitQ. It doesn't compute. Good.

Potential missed site: `Grind_ExitQHoldCancelLayer` no pricing except cancel.

Potential missed site: `Grind_ExitQManageSide` uses `exit_pips` param. Callers all side-specific? Need list all calls in code:
- `Grind_HandleSideDealFill`: yes.
- `Grind_LatticeRollLayer`: yes side-specific.
- `Grind_RetryMissingExits`: yes.
- maybe in tests only. Good.

Potential missed site: `Grind_ApplyEntryHorizon` uses add_pips for floor and ComputeAddTarget, SendNextAddEnt. It is called from `Grind_TryPlaceAddAtFill` and `Grind_EnsureAddNext`. Need ensure both callers pass side-specific add. `TryPlaceAddAtFill` receives add_pips from HandleSideDealFill's fill_add. `EnsureAddNext` receives add_pips from its callers. In `Grind_ServiceDueAddFlags` short passes add_s. In OnTickEngine short passes add_s. In `Grind_EnsureAddNext` itself calls `Grind_ApplyEntryHorizon(side, is_long, magic, slot, add_pips, ...)` with its param, side-specific. Good.

Potential missed site: `Grind_ApplyEntryHorizon` uses `g_grind_engine_entry_horizon_pips` global symmetric. Fine.

Potential missed site: `Grind_EntryHorizonClampAddTarget` uses market and add_target only. Good.

Potential missed site: `Grind_AddTargetNearMarket` uses add_pips passed. Good.

Potential missed site: `Grind_ComputeAddTarget` uses `add_pips` passed. Callers:
- ApplyEntryHorizon: side-specific.
- EnsureAddNext: side-specific.
- SendNextAddEnt: side-specific.
- LatticeTrySide: side-specific via ComputeAddTarget(side,is_long,add_pips) where add_pips side-specific.
- Maybe `Grind_LatticeMaybeStranded` not.
Good.

Potential missed site: `Grind_LatticeCandidateIndex` uses entries, no exit/add.

Potential missed site: `Grind_LatticeRollDetail` no.

Potential missed site: `Grind_EjectAcceptLayer` passed `exit_pips` from AutoEjectTrySide. AutoEjectTrySide called from AutoEjectOnTick with exit_s for short. Good.

Potential missed site: `Grind_EjectPollCommand` may be called from tests with 5 args, default 0 => short inherits. G2.

Potential missed site: `Grind_LatticeOnTick` called from OnTick with short exit/add. Good.

Potential missed site: `Grind_CarryOnTimerStep` called from OnTimer with short exit. Good.

Potential missed site: `Grind_CarryExitPassStep` called from CarryOnTimerStep with short exit; also maybe tests call with 4 args, default 0 => inherits. G2.

Potential missed site: `Grind_CarryExitPassBegin` called from CarryExitPassStep with short exit. Good.

Potential missed site: `Grind_CarryWorkBase` called from CarryExitPassStep with short exit. Good.

Potential missed site: `Grind_ReconCheckInvariants` called from RebuildBookFromTicketsInner with exit_s? It passes `exit_pips, point, max_layers, reason_out, tolerate_exit_shortfall, exit_pips_short`. Wait in RebuildBookFromTicketsInner call:
```
if(!Grind_ReconCheckInvariants(long_scratch, long_count, long_ranks,
                                 short_scratch, short_count, short_ranks,
                                 exit_pips, point, max_layers, reason_out,
                                 tolerate_exit_shortfall, exit_pips_short)) {
```
Yes passes original exit_pips and exit_pips_short, not exit_s. Good. Inside computes exit_s. Good.

Potential missed site: `Grind_ReconExitMatchesEntry` calls from ReconCheckInvariants with exit_pips for long and exit_s for short. Good.

Potential missed site: `Grind_InvariantDetailI6` calls for long with exit_pips and short with exit_s. Good.

Potential missed site: `Grind_ReconFailureOffendingForReason` no pricing.

Potential missed site: `Grind_RebuildBookFromTickets` passes to inner. Good.

Potential missed site: `Grind_CheckBookInvariants` uses `g_grind_recon_exit_pips_short`. Good.

Potential missed site: `Grind_ReconstructState` uses `g_grind_recon_exit_pips_short`. Good.

Now hidden possibility: `g_grind_recon_exit_pips_short` is set in OnInit. But `Grind_ReconstructState` is called after setting. Good. However `Grind_CheckBookInvariants` runs every tick even before? OnTick after OnInit. Good.

Potential missed site: `Grind_RetryMissingExits` called in OnInit after setting globals. It computes exit_s. Good. But it calls `Grind_ExitQManageSide` for long with `g_grind_recon_exit_pips` and short with exit_s. Good.

Potential missed site: `Grind_RetryMissingExits` is also called in OnTick quarantine branch and in OnTickEngine before ServiceDueAddFlags. It uses globals. Good.

Now need find any actual bug? The branch likely has planted issues. We need hunt. Let's scrutinize signatures and calls. Maybe OnTickEngine missing exit_pips_short parameter? It doesn't need? Let's see OnTickEngine body. It calls `Grind_RetryMissingExits` which uses globals. It also calls `Grind_EnsureAddNext` and `Grind_TryRecenterOppositeL0`, L0 pricing. It doesn't use exit. So no.

But wait: OnTickEngine sets `g_grind_engine_add_pips = add_pips; g_grind_engine_add_pips_short = add_s;`. However it does not set `g_grind_recon_exit_pips` or `g_grind_recon_exit_pips_short`. Those are set only in OnInit. In tests, they may modify. In production, OnInit sets. Fine.

Potential issue: `Grind_OnTradeTransactionEngine` sets `g_grind_engine_add_pips` and short, but not `g_grind_recon_exit_pips`/short. `Grind_HandleSideDealFill` uses `exit_pips` param, not globals. Good.

Potential issue: `Grind_ReconstructState` in OnInit uses `g_grind_recon_exit_pips_short` set just before. Good.

Potential issue: In OnInit, `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);` is called after ReconstructState. It uses `g_grind_recon_exit_pips_short`. Good.

Now T-2 producer/checker agree. For short side, every producer of exit price uses same exit value I6 checks. Producers:
- fill append `Grind_AppendLayer` uses `exit_pips` passed from HandleSideDealFill, which for short is `exit_s = Grind_SidePips(false, exit_pips, exit_pips_short)` in OnTradeTransactionEngine. Good.
- queue release/promotion `Grind_ExitQManageSide`: callers pass side-specific. Good.
- retry `Grind_RetryMissingExits`: uses `exit_s` from `g_grind_recon_exit_pips_short`. I6 checker `Grind_CheckBookInvariants` uses `g_grind_recon_exit_pips_short` too. Good.
- lattice roll `Grind_LatticeRollLayer`: receives side-specific from LatticeOnTick. But I6 checker uses `g_grind_recon_exit_pips_short`, which is set in OnInit from same `g_geo_exit_short`. If LatticeOnTick called with a different `exit_pips_short` than global recon? In production, OnTick passes g_geo_exit_short and global recon is g_geo_exit_short. In tests could differ. In production same. Good.
- carry pass: `Grind_CarryExitPassBegin/Step` uses exit_pips_short passed from OnTimer `g_geo_exit_short`. Same as recon global. Good. But wait carry pass modifies exits using `Grind_CarryWorkBase` with formula using exit_pips_short. Then it records shift? The invariant expected includes carry_shift? Let's verify I6 formula: `Grind_ReconExitMatchesEntry` expects `ExitPrice(eff, exit_pips) + accrued + eject_offset + shift`. Carry pass computes theoretical = `Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size)` where formula_exit = ExitPrice(eff, exit_pips) + eject_offset. Then sets new_exit = theoretical (plus clamps). It records `applied_shift = Normalize(new_exit) - intended` where intended = formula_exit + accrued_price. Accrued_price = theoretical - formula_exit. So applied_shift = new_exit - (formula_exit + theoretical - formula_exit) = new_exit - theoretical, i.e. clamp residual. Also sets `Grind_CarryAccruedSet(position_ticket, accrued_price)`. Then I6 expected = ExitPrice(eff, exit_pips)+accrued+eject_offset+carry_shift. Now accrued = accrued_price = theoretical - formula_exit. carry_shift = new_exit - theoretical. So expected = formula_exit + (theoretical - formula_exit) + (new_exit - theoretical) = new_exit. Good. Uses exit_pips same as carry pass. Good.
- eject: `Grind_EjectAcceptLayer` sets target = market, then stores offset = target - raw - accrued. Raw uses exit_pips passed. I6 expected = ExitPrice(eff, exit_pips)+accrued+eject_offset. Since eject_offset = target - raw - accrued, expected = target. Good. Uses recon exit_pips? Eject raw uses `exit_pips` passed from EjectPollCommand/AutoEjectTrySide. In OnTick, EjectPollCommand receives g_geo_exit_long and g_geo_exit_short. I6 uses g_grind_recon_exit_pips_short = g_geo_exit_short. Same. AutoEjectOnTick receives g_geo_exit_long and g_geo_exit_short. Same. Good.

But there may be a disagreement: `Grind_LatticeRollLayer` if exit_order_ticket exists sets `Grind_VLSet(pos, level)` and modifies exit to `price = formula` where formula = ExitPrice(level, exit_pips, ...) + accrued. It does NOT add eject offset? Wait it calculates formula then `Grind_ExitQClampPassive`, then if clamped records shift; if not deletes shift. But `Grind_ExitQFormulaTarget` includes eject_offset. Lattice roll formula does not include eject offset. Hmm maybe before roll, if ejected, `Grind_EjectOffsetDelete(pos)` is called. It deletes eject offset. So I6 expected = ExitPrice(eff, exit_pips)+accrued+eject_offset(0)+shift. Price = formula = ExitPrice(level, exit_pips)+accrued. EffectiveEntry = level (VL set). So expected = ExitPrice(level, exit_pips)+accrued+0+shift. If not clamped, shift deleted -> price = formula. If clamped, records shift = price - formula. Good. Eject offset deleted. Good. Uses same exit_pips side-specific. Good.
- carry pass on ejected layers: `Grind_CarryShiftGetValidated` returns shift even if ejected. Formula includes EjectOffsetGet. Good.
- `Grind_ExitQManageSide` for required exits after lattice roll uses formula with `Grind_ExitQFormulaTarget` which includes eject_offset. But roll deleted eject offset. Good.

Potential T-2 issue: `Grind_AutoEjectTrySide` when already ejected uses `Grind_EjectTargetPrice` and `Grind_AutoEjectTargetWorse`; then `Grind_EjectAcceptLayer` recomputes target. No.

Potential T-2 issue: I6 checker uses `Grind_CarryShiftGetForRecon(position_id)`, which validates shift against bound. Producer might have shift that fails validation and gets deleted by checker? But that's existing.

Potential T-2 issue: `Grind_ReconCheckInvariants` short uses exit_s computed as `Grind_SidePips(false, exit_pips, exit_pips_short)`. If `exit_pips_short` is exactly 0.0 or negative, it inherits long. But in production if user sets short override >0, it's used. Good.

Potential T-2 issue: `Grind_CheckBookInvariants` passes `g_grind_recon_exit_pips_short` which is set in OnInit from `g_geo_exit_short`. But if `InpExitPipsShort` is -1, `g_geo_exit_short = InpExitPips`. Good. If asymmetric, set. Good.

Potential T-2 issue: `Grind_OnTickEngine` sets `g_grind_engine_add_pips_short = add_s` but does not update `g_grind_recon_exit_pips_short`. If runtime inputs could change? MT5 inputs don't change without reinit. Fine.

Now T-3 stale globals. Need examine. `g_grind_engine_add_pips_short` and `g_grind_recon_exit_pips_short` set in OnTickEngine/OnTradeTransactionEngine and OnInit. Can reader see 0.0 or stale? 

- `g_grind_engine_add_pips_short`: readers: `Grind_HandleSideDealFill` (via fill_add), `Grind_ServiceDueAddFlags`? Actually ServiceDueAddFlags takes add_pips_short param, not global. `Grind_HandleSideDealFill` reads `g_grind_engine_add_pips_short` only for short. It is set in `Grind_OnTradeTransactionEngine` immediately before calling `Grind_HandleSideDealFill`. So a fill processed there sees correct current params. Also set in OnTickEngine every tick. If a fill arrives before first OnTick? OnTradeTransaction sets it. So not 0.0 unless OnTradeTransaction not called? If handler invoked directly? Only tests. But could `Grind_HandleSideDealFill` be called from somewhere else? Search: only OnTradeTransactionEngine? In code, also maybe tests call? The provided tests call `Grind_OnTradeTransactionEngine`. So production safe.

- But wait: In `Grind_OnTradeTransactionEngine`, if `g_grind_halted` return before setting globals? It first archives fill, then `if(g_grind_halted) return;` before setting globals. If halted, no fills processed. If a fill arrives while halted, HandleSideDealFill not called. So no.

- If `trans.type != TRADE_TRANSACTION_DEAL_ADD` returns before setting. Fine.

- If `Grind_HandleSideDealFill` for long side, it uses `g_grind_engine_add_pips` not short. short global set anyway. Good.

- `g_grind_recon_exit_pips_short`: set in OnInit only. Readers: `Grind_RetryMissingExits`, `Grind_CheckBookInvariants`, `Grind_ReconstructState`. OnTick can run after OnInit. No issue. But in tests, `GV_RestoreEngineGlobals` resets to 0.0. Could leave stale. Threat mentions tests leaving value behind. Need check tests. `GV_RestoreEngineGlobals` sets both shorts to 0.0. Some tests set `g_grind_recon_exit_pips_short = 7.0` then restore. Good. But maybe tests don't restore `g_grind_engine_add_pips_short`? They call GV_Restore at end of each. Good. But in test harness, after tests, globals restored to 0.0. If production? Not.

- Potential stale: `g_grind_engine_add_pips_short` is not set in OnInit. If an early `OnTradeTransaction` for a fill arrives before first OnTick but after OnInit, OnTradeTransactionEngine sets it. Good. If `Grind_HandleSideDealFill` called from OnInit? No.

- What if `OnTradeTransactionEngine` is called with a deal that belongs to long side, but `g_grind_engine_add_pips_short` is set to `Grind_SidePips(false, add_pips, add_pips_short)`. If `add_pips_short` default 0.0 from a caller that doesn't pass short, then short global becomes long. That's intended inherit. If production asymmetric, passed. Good.

- Test leaving a value: `GV_RestoreEngineGlobals` sets both shorts 0.0, but does it restore `g_grind_recon_exit_pips`? It takes saved_recon and sets. Good. But it doesn't restore `g_grind_engine_add_pips_short`? It sets to 0.0, not saved. Since saved_short not captured. If prior value non-zero, test wipes it. But tests run isolated? Could affect later tests? Later tests set as needed. Not production. Threat asks can a test leaving a value behind cause reader see stale? If a test sets `g_grind_recon_exit_pips_short = 7.0` and doesn't restore, next test maybe. They call restore. But `GV_RestoreEngineGlobals` sets short globals to 0.0, so it clears, which could make a later test that relies on nonzero inherited? Tests typically set. Could be a test gap.

- More serious: `g_grind_recon_exit_pips_short` is set in OnInit, but `Grind_CheckBookInvariants` is called at start of OnTick. If OnInit failed before setting? OnInit sets before ReconstructState. If ReconstructState fails, halted. OnTick still calls CheckBookInvariants? OnTick:
```
if(!g_grind_halted) { ... CheckBookInvariants ...}
```
If ReconstructState failed, g_grind_halted true, so skip. Good.

- `g_grind_recon_exit_pips_short` is set to g_geo_exit_short. g_geo_exit_short resolved. Good.

Potential issue: `g_grind_engine_add_pips_short` set in OnTickEngine after `Grind_GuardsAllowTrading`. If guards fail, not set. But OnTradeTransaction sets before fill. If a fill is processed from OnTradeTransaction, okay. If a fill is processed via `Grind_HandleSideDealFill` from somewhere else? No.

Potential issue: `g_grind_engine_add_pips_short` is set in OnTickEngine before `Grind_RetryMissingExits`. But RetryMissingExits doesn't use it. It uses recon globals. Good.

Now T-4 Inputs. Sentinel and validation: MT5 parsing of -1.0 in .set file can it arrive as -0.99999? `Grind_ResolveSideInput` uses tolerance 1e-9 around -1:
```
if(MathAbs(override_value + 1.0) <= 1e-9)
```
So -1.000000001? Difference 1e-9? Actually if -0.99999, diff 1e-5 > 1e-9, so not inherit, then `-0.99999 > 0` false, returns false FATAL. MT5 .set parsing for double likely uses `StringToDouble` which is exact enough for "-1.0"? Could be -1.0 exactly in binary? `-1.0` is exactly representable. If .set has "-1" it's exact. If "-1.0" exact. If "-1.0000000001" maybe. The tolerance only 1e-9. MT5 likely exact for decimal -1.0. ASSUMED. But if .set writes `-1.0000000000000002`, then fatal. Need mention.

Also order of checks in OnInit: They resolve all six side inputs first. Then validate base geometry and ratios. Then validate long geometry, long ratio, short geometry, short ratio. Then deadband, magic, lattice, magic lock. If any fatal, return INIT_FAILED before order placement. But `Grind_MagicLockClaim` after validation; no orders. Good. Could any order be placed before validation fails? No trading before OnInit returns. However `Grind_ResolveSideInput` for long/short sets g_geo values even if later validation fails; no orders.

Potential issue: `Grind_ResolveSideInput` treats `override_value > 0.0` as override. If override is NaN? `MathAbs(NaN+1)<=` false, `NaN >0` false, returns false. Good fatal. If infinity? >0 true, out=inf. Then geometry validation `width_pips <=0` false? inf >0, exit etc. Add/width ratio inf/inf NaN? Could pass? `Grind_ValidateAddWidthRatio` with inf/inf = NaN; `r < min -1e-9` false, `r > max +1e-9` false, returns true. Then later PipsToPrice(inf) -> inf, orders maybe invalid. But MT5 inputs can't be inf? Maybe not. Could mention? But not per-side specific.

Potential issue: Validation of base inputs uses `InpWidthPips`, `InpExitPips`, `InpAddPips` even if those are -1 and all six overrides set positive. Logic: They first resolve each side. Suppose base inputs are -1 (unset) but long/short overrides positive for all three. Then:
- Resolve width long/short: if override positive, ok. If base -1 and override -1 for some side, then g_geo_width_long = -1. Then `Grind_ValidateGeometryInputs(g_geo_width_long,...)` fails. That's correct: each resolved value must be >0.
- But then still `Grind_ValidateGeometryInputs(InpWidthPips, InpExitPips, InpMaxLayers, InpStrandedThreshPips, InpAddPips)` is called before side-specific checks. If base inputs are -1 but all sides overridden positive, this base check fails and OnInit returns INIT_FAILED, even though resolved sides are valid. Is that intended? The prompt says "each side's resolved triple passes the existing geometry and add/width (ADR-153) checks". But code also validates base inputs (InpWidthPips etc.) unconditionally. That means if user wants to specify only side overrides and leave base at -1, OnInit fails. Is that a bug? Let's read OnInit:
```
if(!Grind_ValidateGeometryInputs(InpWidthPips, InpExitPips,
                                    InpMaxLayers, InpStrandedThreshPips,
                                    InpAddPips)) { ... return INIT_FAILED; }
if(!Grind_ValidateAddWidthRatio(InpWidthPips, InpAddPips)) ...
if(!Grind_ValidateGeometryInputs(g_geo_width_long,...)) ...
...
```
Yes base is still required >0 and ratio valid. Since new inputs default -1, if user sets only long/short overrides and leaves base -1, OnInit fails. Is that intended? The ruled says "one EA with inherit-by-default overrides" and sentinel -1 inherits base. It doesn't say base can be omitted. The comment in fxgrind inputs: `InpWidthPips = -1.0` default, but presets likely set base. The branch tests probably have base >0? In tests they call functions directly not OnInit. The G3 says with all six inputs at -1, every resolved value equals base. If base is invalid, fail. So maybe base must be set. Not a threat? It could be a usability bug: user must set base even if both sides overridden. But not a missed short pricing. Could mention under T-4? The question: "the order of checks in OnInit, and whether any order can be placed before validation fails." We can note base validation still requires base even when both sides overridden; if intended to allow all-side overrides without base, BREAKS. But is that a threat? It says each side's resolved triple passes existing geometry and add/width checks. The base check is extra. If base -1 and all sides >0, resolved sides valid but base invalid -> INIT_FAILED. That means you cannot configure per-side only via overrides without also setting base. But maybe presets set base. The user says "with all six inputs at -1, every resolved value equals base" which implies base must be valid. They didn't say base can be -1 with overrides. However "six inputs ... -1 inherits base input, >0 overrides" implies if all six are >0, base unused. But code still validates base. That is a potential silent failure / usability. But threat T-4 asks sentinel and validation. We should flag as NEEDS-FIX? Let's see if this is a known? The prompt: "Before it, one InpWidthPips... Now six inputs... exactly -1 inherits base input, >0 overrides, anything else FATAL". It doesn't say base can be omitted. In OnInit, base inputs are still inputs. If all six are overrides, base can be -1 but then base validation fails. Is that a bug? If presets for asymmetric likely set base to something (maybe one side) and override other. But if user wants both sides different from each other, they could set base to long and short override, or base to any valid. The code requires base valid. That's not necessarily wrong: base is a fallback; if no side inherits, base is unused but still required. Could be considered a flaw: the base is not used but must be set. But T-4 "0 or negative overrides" etc. We'll mention.

Also order: They resolve long/short before validating base. If base is -1 and override -1 for a side, g_geo side = -1. Then base validation fails first, so error message generic. Fine.

Could any order be placed before validation fails? No, OnInit returns INIT_FAILED before setting timer. But note `Grind_MagicLockClaim` is after validations; if validation fails, no lock. Good.

Potential issue: `Grind_ResolveSideInput` with override exactly -1 but base also -1 returns out=-1 true. Then later geometry fails. Good.

T-5 Same when symmetric. With all six at -1 (every existing preset), behavior identical to main including reporting? Need check. `Grind_SidePips(false, x, 0.0)` returns x. All new params default 0.0; if passed g_geo_*_short = base (because -1), then `Grind_SidePips(false, long, short)` where short = base. Condition `short_value > 0.0` true, so returns short_value. But short_value equals long_or_both? In production, if all six -1, g_geo_width_short = InpWidthPips, and OnTick passes long_or_both = g_geo_width_long = InpWidthPips. So short_value == long_or_both. So returns same. Identical. If long_or_both and short differ? Not symmetric. So T-5 holds.

But there is a subtle: `Grind_SidePips` returns `short_value` if `short_value > 0.0` regardless of whether it came from override or inherited. If all -1, short_value = base. If base >0, returns base. Same. If base 0? invalid. Good.

Reporting: legacy keys carry long values. Heartbeat StringFormat has six new keys? Need verify count and order. Let's count. In `Grind_BuildHeartbeatJson`, the `StringFormat` format string after existing:
```
",\"width_pips_long\":%.4f,\"width_pips_short\":%.4f,"
"\"add_pips_long\":%.4f,\"add_pips_short\":%.4f,"
"\"exit_pips_long\":%.4f,\"exit_pips_short\":%.4f}"
```
Arguments after previous:
```
g_geo_width_long,
g_geo_width_short,
g_geo_add_long,
g_geo_add_short,
g_geo_exit_long,
g_geo_exit_short);
```
Order matches: width_long, width_short, add_long, add_short, exit_long, exit_short. Good. Count? Need ensure earlier specifiers match. The format string has many. We can count but likely okay. The heartbeat JSON appends after removing closing brace. It has comma before first new key. Good. Potential invalid JSON if `hb` doesn't end with `}`? Code checks. If `len<2 || last != '}'` returns hb without new keys. So if base heartbeat invalid, no new keys. Not v2.

INIT/DEINIT JSON: `Grind_ArchiveConfigFields(...) + "," + Grind_ArchiveGeometryFields(...)`. Need check `Grind_ArchiveGeometryFields` signature? Not provided. It is called with six values: long width/add/exit, short width/add/exit. But prompt: six new keys in heartbeat and INIT/DEINIT fields; a GRIND_GEOMETRY line. We don't see grind_archive.mqh. Can't verify commas/key names. Need note cannot verify due missing include? But code to audit includes references. We can only reason from call. If `Grind_ArchiveConfigFields` returns JSON object with closing brace? Then concatenating "," may produce invalid JSON if it includes closing brace. But likely returns fields no braces. Need not. Could mention not verifiable from provided code: `Grind_ArchiveGeometryFields` not in attached files. But the prompt expects us to audit. Maybe we can infer from call pattern: They call `Grind_ArchiveConfigFields(...) + "," + Grind_ArchiveGeometryFields(...)`. If both return comma-separated key-value without outer braces, fine. We don't have source. Should we mark NEEDS-FIX? The rule: claim without quote discarded. We can quote call. But cannot verify schema. Maybe mention as unverifiable / test gap.

Reporting legacy keys: `Grind_ArchiveConfigFields` likely still takes long values. The call passes `g_geo_width_long, g_geo_add_long, g_geo_exit_long` in old slots. Good. DEINIT too. INIT. So legacy keys long. Good.

GRIND_GEOMETRY line:
```
Print("GRIND_GEOMETRY long width=", DoubleToString(g_geo_width_long, 4),
         " add=", DoubleToString(g_geo_add_long, 4),
         " exit=", DoubleToString(g_geo_exit_long, 4),
         " short width=", DoubleToString(g_geo_width_short, 4),
         " add=", DoubleToString(g_geo_add_short, 4),
         " exit=", DoubleToString(g_geo_exit_short, 4));
```
Looks fine.

Potential T-6 issue: In `Grind_BuildHeartbeatJson`, the new keys are appended after `Grind_TelemetryHeartbeatJson`. But `Grind_TelemetryHeartbeatJson` may already include `width_pips`, `add_pips`, `exit_pips` legacy? The prompt says legacy keys carry long values; six new keys in heartbeat and INIT/DEINIT. The code appends only six long/short keys. It does not include legacy width_pips/add_pips/exit_pips in the appended part; maybe `Grind_TelemetryHeartbeatJson` includes them. We don't see. The call to `Grind_TelemetryHeartbeatJson` passes `g_geo_width_long, g_geo_add_long, g_geo_exit_long` in old slots. So legacy keys there. Good.

Potential T-6 invalid JSON: If `Grind_TelemetryHeartbeatJson` returns JSON with no trailing `}`? Check. If it ends with `}`, code strips and appends. If the base JSON has commas? The appended starts with `,"...` so fine. If base JSON is empty? returns hb. Fine.

Potential T-6: `Grind_BuildHeartbeatJson` uses `grind_short.add_held ? DoubleToString(...) : "null"` for add_held_target. That can produce unquoted number or null. Good.

Potential T-6: INIT/DEINIT JSON: `Grind_ArchiveConfigFields(...) + "," + Grind_ArchiveGeometryFields(...)`. If `Grind_ArchiveConfigFields` returns a JSON object with outer braces, concatenation invalid. But likely it returns fields. The function name "ConfigFields" suggests comma-separated fields without braces. `Grind_ArchiveGeometryFields` likely same. Could not verify. Maybe mention as ASSUMED.

Potential T-6: In `Grind_EmitHeartbeat`, no newline. Fine.

T-7 Tests. Need identify v2.0 behavior with no test that fails without it. We have tests file provided. Need scrutinize. The tests GV1-GV13. Which v2 behaviors tested? 
- GV1 SidePips
- GV2 ResolveSideInput
- GV3 RetryMissingExits per side
- GV4 I6 per side
- GV5 Rebuild per side
- GV7 FillShortExitAndAdd
- GV8 FillLongControl
- GV9 L0WidthPerSide
- GV10 AddNextPerSide
- GV11 LatticeShortPerSide
- GV12 CarryPerSide
- GV13 EjectShortPerSide

Missing GV6? Maybe intentionally. Need find gaps. The prompt mentions GV10 first runs two ticks on flat book, so short side has resting L0 when layer is seeded; engine cancels it as stray (STRAY_L0_CANCEL) before placing add. Does that setup weaken the test? Let's analyze.

GV10:
- After two OnTickEngine with width short=3.0 add short=10.0? Actually first two calls: `Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0);` twice. This places long L0 and short L0. Then manually `ArrayResize(g_grind_short.layers,1)` and set short layer. It does not clear `g_grind_short.l0_pending_ticket`. So short side has a resting L0 order. Then third OnTickEngine: `Grind_OnTickEngine(... 5.0,10.0,10.0,10.0,4.0,8,0.01,5.0,6.0)` calls `Grind_ReconcileStrayL0(g_grind_short, false, magic)` at start. Since depth >0 and l0_pending_ticket !=0, and order exists, it cancels it as STRAY_L0_CANCEL. Then later `Grind_EnsureAddNext` places add. The test asserts add price 1.20060. Does the cancellation affect? It uses same `g_grind_ent_sent_this_tick` false. It doesn't affect add pricing. But it means `g_grind_short.l0_pending_ticket` is cleared. The test might pass even if short add wiring broken? Let's see if short add used wrong value. The test expects add at 1.20060. Short entry 1.20000, add_pips_short=6.0 -> AddTargetPrice(anchor, 6, point, -1) = anchor - (-1)*6*point*10 = 1.20000 + 0.00060 = 1.20060. If it used long add=10.0, would be 1.20100. So assertion fails if wrong. The stray L0 cancel doesn't weaken that. But the setup means the short side has an L0 pending that is canceled; maybe if wiring caused the add to be placed differently? Not really.

But there might be a test gap: `Grind_EjectPollCommand` short wiring is tested in GV13. Good.
`Grind_AutoEjectOnTick` short wiring? No test? The thirteen include `Grind_AutoEjectOnTick` (~626). Is there a test? I don't see GV for auto eject per-side. There are existing tests maybe not in provided file. The prompt asks "Which v2.0 behaviour has no test that fails without it?" We need identify. Provided tests cover many but not all. Missing:
- `Grind_AutoEjectOnTick` short exit wiring: no test in fxgrind_tests_gv.mqh. There may be other test files? Only this provided? The prompt says "fxgrind_tests_gv.mqh". It mentions GV10. The provided file ends. So auto eject per-side likely no test.
- `Grind_LatticeOnTick` tests short exit and add? GV11 passes exit_pips=9.0, add_pips=3.0, exit_pips_short=5.0, add_pips_short=10.0. It asserts rolled exit 1.19350. Let's verify: SeedShort8 maybe short entries? Need know. It checks S0 rolled at short level. The exit uses short exit 5.0. If used long 9.0, exit would be different. It also likely tests add short? The level? It asserts `Grind_VLHas(7101) && level - 1.19400`. Add short used to compute level? Maybe. So tests lattice short.
- `Grind_CarryExitPassBegin`/WorkBase/OnTimerStep/ExitPassStep short: GV12 tests CarryExitPassBegin, WorkBase, Step. It passes short 5.0 and asserts. Good.
- `Grind_ServiceDueAddFlags` short: maybe no direct test? It is ADR-152 due flags. GV7 tests fill-time add via OnTradeTransaction, not ServiceDueAddFlags. GV10 tests OnTickEngine EnsureAddNext, not ServiceDueAddFlags. Is there a test for `Grind_ServiceDueAddFlags` with short? Not in provided. Could be missing.
- `Grind_OnTradeTransactionEngine` short exit/add: GV7 tests short fill and add. Good.
- `Grind_OnTickEngine` short width/recenter: GV9 tests L0 width short. Does it test recenter opposite L0 short? Not directly. It places both L0? Actually GV9 asserts both L0 placed. Recenter path only when one side depth>0 and other depth==0. Not tested.
- `Grind_RetryMissingExits` short: GV3 tests.
- `Grind_ReconCheckInvariants` short: GV4 tests.
- `Grind_RebuildBookFromTicketsInner` short: GV5 tests.
- `Grind_CheckBookInvariants`/`Grind_ReconstructState` short wiring: no test seam, ruled deploy only. The prompt says ruled do not re-open. But T-7 asks which v2 behavior has no test. This is one: the actual broker book readers have no test seam, so their short wiring is not tested. But that's ruled. Still mention.
- `Grind_HandleSideDealFill` short exit: GV7.
- `Grind_EnsureAddNext` short: GV10.
- `Grind_ApplyEntryHorizon` short: no test? Entry horizon active? GV tests configure? GV7/8 use `Grind_EngineConfigureAdr152(true,0)` without horizon (default 0), so not. GV10 uses fill_time_place true but horizon off. So `Grind_ApplyEntryHorizon` short wiring (add_pips) is untested. That's a v2.0 path: it takes add_pips and is called with side-specific; no test. Could be gap.
- `Grind_TryPlaceAddAtFill` short: GV7 tests (fill_time_place true, horizon off) -> calls SendNextAddEnt directly? Wait TryPlaceAddAtFill:
```
if(Grind_EntryHorizonActive()) { ApplyEntryHorizon } else { SendNextAddEnt(... add_pips ...) }
```
GV7 has horizon off, so tests SendNextAddEnt path, not ApplyEntryHorizon. Good.
- `Grind_ServiceDueAddFlags` short: no test.
- `Grind_AutoEjectOnTick` short: no test.
- `Grind_EjectPollCommand` short: GV13.
- `Grind_LatticeOnTick` short: GV11.
- `Grind_CarryExitPassBegin` short: GV12.
- `Grind_CarryWorkBase` short: GV12.
- `Grind_CarryOnTimerStep` short: not directly? GV12 calls CarryExitPassBegin/Step, not OnTimerStep. OnTimerStep is a wrapper that calls snapshot and step. The short parameter passthrough from OnTimerStep to Step is not tested. But it's trivial.
- `Grind_CarryExitPassStep` short: GV12.
- `Grind_ReconCheckInvariants` short: GV4.
- `Grind_RebuildBookFromTickets` short: GV5.
- `Grind_OnTickEngine` short add/width: GV9, GV10.
- `Grind_ServiceDueAddFlags` short: no.

Also tests vacuous. Need inspect assertions inside `if`. GV5:
```
AssertTrue("GV5 short depth", ArraySize(S2.layers) == 1);
AssertNear("GV5 short exit target",
              ArraySize(S2.layers) == 1 ? S2.layers[0].exit_target : 0.0,
              1.19930, 1e-10);
```
The AssertNear runs regardless; if ArraySize !=1, it compares 0.0 to 1.19930 and fails. So not vacuous.

GV7:
```
AssertTrue("GV7 short layer appended", ArraySize(g_grind_short.layers) == 1);
AssertNear("GV7 short exit target",
              ArraySize(g_grind_short.layers) == 1 ? g_grind_short.layers[0].exit_target : 0.0,
              1.19930, 1e-9);
```
If not appended, AssertNear fails. Good.

GV10: after two ticks, short L0 exists. Then manual layer seed. Then two more ticks. The test expects short add. But does the stray L0 cancel interfere with `g_grind_ent_sent_this_tick`? In first of two final ticks, ReconcileStrayL0 cancels L0, then EnsureAddNext places add. `g_grind_ent_sent_this_tick` set true. Second tick no new. Assert add price. The stray L0 cancel might hide a bug: if `Grind_EnsureAddNext` short wiring were broken (using long add), the test would still fail because price differs. So okay. But the setup means the short side depth was manually seeded, but the L0 pending ticket remains, so the engine cancels it. This could remove an order that might otherwise affect slot counts? In test mode, slot test active with limit 200 used 100 resting 0, so no. Not weaken.

Potential vacuous: GV1 `AssertNear("GV1 long takes long", Grind_SidePips(true, 10.0, 7.0), 10.0,...)` fine.
GV2 `AssertFalse("GV2 negative refused", Grind_ResolveSideInput(base, -2.0, out));` but out may be modified? It doesn't check out. Fine.

Potential test gap: No test for `Grind_SidePips` when short_value is negative but not -1? It tests -1.0 inherits. G1 says returns short only when >0. Good.

Potential test gap: No test for exactly -1.000000001? Not needed.

Now, need find actual bugs beyond tests. Let's scrutinize code for subtle wrong wiring.

Search all occurrences of `_short` in provided files. We can manually scan.

In grind_engine.mqh:
- globals `g_grind_engine_add_pips_short`.
- `Grind_EjectPollCommand(... exit_pips_short = 0.0)`; uses `Grind_SidePips(is_long, exit_pips, exit_pips_short)` good.
- `Grind_AutoEjectOnTick(... exit_pips_short = 0.0)`; uses side_s good.
- `Grind_LatticeOnTick(... exit_pips_short = 0.0, add_pips_short = 0.0)`; uses side_s good.
- `Grind_OnTickEngine(... width_pips_short = 0.0, add_pips_short = 0.0)`; good.
- `Grind_ServiceDueAddFlags(... add_pips_short = 0.0)`; good.
- `Grind_OnTradeTransactionEngine(... exit_pips_short = 0.0, add_pips_short = 0.0)`; good.
- `Grind_HandleSideDealFill` changed without new param: uses fill_add global. Good.

In grind_pure.mqh:
- `Grind_SidePips`, `Grind_ResolveSideInput`. Good.

In grind_carry.mqh:
- `Grind_CarryExitPassBegin(... exit_pips_short = 0.0)`; short inside loop. Good.
- `Grind_CarryWorkBase(... exit_pips_short = 0.0)`; good.
- `Grind_CarryOnTimerStep(... exit_pips_short = 0.0)`; good.
- `Grind_CarryExitPassStep(... exit_pips_short = 0.0)`; good.

In grind_recon.mqh:
- globals.
- `Grind_ReconCheckInvariants(... exit_pips_short = 0.0)`; good.
- `Grind_RebuildBookFromTicketsInner(... exit_pips_short = 0.0)`; good.
- `Grind_RebuildBookFromTickets(... exit_pips_short = 0.0)`; good.

In fxgrind.mq5:
- inputs, globals, OnInit resolves, sets recon globals, reporting, OnTimer, OnTick, OnTradeTransaction. Good.

Potential bug: In `Grind_OnTickEngine`, the short-side add used for `Grind_EnsureAddNext` is `add_s`, but the long side `Grind_EnsureAddNext` uses `add_pips`. Good. However `Grind_ServiceDueAddFlags` is called with `add_pips` and `add_s`. Good.

Potential bug: `Grind_OnTickEngine` computes `width_s` and `add_s` at top:
```
const double width_s = Grind_SidePips(false, width_pips, width_pips_short);
const double add_s = Grind_SidePips(false, add_pips, add_pips_short);
g_grind_engine_add_pips = add_pips;
g_grind_engine_add_pips_short = add_s;
```
Then `Grind_RetryMissingExits(magic, slot, lots);` uses `g_grind_recon_exit_pips` and short. Fine.
Then `Grind_ServiceDueAddFlags(magic, slot, add_pips, deadband_pips, max_layers, lots, add_s);` Good.
Then L0 placement uses `width_s` for sell. Good.
Recenter uses `width_s` for short opposite. Good.
EnsureAddNext short uses `add_s`. Good.

Potential bug: `Grind_OnTickEngine` does not pass `exit_pips_short` to `Grind_RetryMissingExits`, but RetryMissingExits uses globals. If someone calls OnTickEngine with per-side exit different from global recon, RetryMissingExits would use stale global. In production, global recon set in OnInit from same g_geo_exit_short. But tests might call OnTickEngine with a different short exit than `g_grind_recon_exit_pips_short`. Is that a v2 wiring bug? The function signature lacks exit_pips_short even though OnTick has exit long/short. But OnTickEngine doesn't need exit for its own operations except RetryMissingExits. It relies on global `g_grind_recon_exit_pips_short`. The prompt says the thirteen dispatch functions include `Grind_OnTickEngine` (~2770) with new last parameters? Wait the prompt says "the SHORT values travel in NEW LAST PARAMETERS (default 0.0) of thirteen dispatch functions". For `Grind_OnTickEngine`, the new last parameters are `width_pips_short, add_pips_short`. It does not have exit_pips_short! But it takes exit_pips in old slot. Does it need exit_pips_short? The list of thirteen says `Grind_OnTickEngine` (~2770). The description: "the resolved LONG values travel where the single value travelled; the SHORT values travel in NEW LAST PARAMETERS". For OnTickEngine, the single values included width, exit, add. The short values should travel in new last parameters. But the signature only has width_pips_short and add_pips_short, no exit_pips_short. Is that a missed short value? Let's check: OnTickEngine's `exit_pips` parameter is used? In body, I see no use of `exit_pips` at all. Search function body: 
```
void Grind_OnTickEngine(... const double exit_pips, ...)
{
   if(!Grind_GuardsAllowTrading...
   ...
   Grind_RetryMissingExits(magic, slot, lots);
   ...
   // no exit_pips
}
```
Indeed `exit_pips` is unused in OnTickEngine! That's suspicious. Previously maybe it was passed to RetryMissingExits? But now RetryMissingExits uses globals. Let's check `Grind_RetryMissingExits` signature: it takes magic, slot, lots, no exit. It reads `g_grind_recon_exit_pips`. So OnTickEngine's `exit_pips` is dead. Why is it in signature? It may be legacy. The v2.0 changed OnTickEngine to add short width/add but not exit short because exit handled via global recon. But the prompt says "the SHORT values travel in NEW LAST PARAMETERS of thirteen dispatch functions". Is OnTickEngine supposed to have `exit_pips_short`? The list says OnTickEngine (~2770) among thirteen. It has width_pips_short, add_pips_short. Maybe exit_pips_short not needed because OnTickEngine doesn't use exit_pips. But then why is exit_pips in old slot? It is unused. Could be a bug: OnTickEngine should call RetryMissingExits with per-side exit? But RetryMissingExits uses globals, which are set in OnInit. So okay if globals match. But if OnTickEngine is used as a dispatch function with exit_pips_short, tests might expect it. Let's check tests: They call `Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 5.0, 6.0)`. Here arguments: width=5, exit=10, add=10, stranded=10, deadband=4, max=8, lots=0.01, width_short=5, add_short=6. They do NOT pass exit_pips_short. So exit short is inherited from long? Actually `g_grind_recon_exit_pips` is set to 10.0 in GV10 before calls, and `g_grind_recon_exit_pips_short` is set to 7.0. So RetryMissingExits uses 7.0 for short. OnTickEngine's exit_pips=10 unused. So test works. In production, recon globals set. So OnTickEngine exit_pips unused is fine but dead. However T-1: "Is there ANY path that prices a SHORT-side order ... with long or base value?" RetryMissingExits uses `g_grind_recon_exit_pips_short`, which is correct if set. But if OnTickEngine is called with different exit_pips_short than global, it won't use it. In production they match. In tests, they set global. So not a break in production.

But wait: `Grind_OnTickEngine` is called in OnTick with `g_geo_exit_long` as exit_pips, but no short exit. The `g_grind_recon_exit_pips_short` is set in OnInit to `g_geo_exit_short`. So RetryMissingExits uses correct short. Good.

Potential bug: `Grind_OnTickEngine` sets `g_grind_engine_add_pips = add_pips;` but does not set `g_grind_recon_exit_pips` or short. They are set in OnInit. If OnInit sets them, fine. If not? OnInit sets. Good.

Potential bug: `Grind_RetryMissingExits` is called in OnInit before `g_grind_recon_exit_pips_short`? No, set before. Good.

Potential bug: `Grind_ReconstructState` is called in OnInit and uses `g_grind_recon_exit_pips_short`. Set before. Good.

Now consider `Grind_OnTradeTransactionEngine` uses `add_pips` and `add_pips_short` to set `g_grind_engine_add_pips_short`. But it does not use `exit_pips_short` for anything except `exit_s` passed to HandleSideDealFill. Good.

Potential missed site: `Grind_HandleSideDealFill` when processing an EXT fill for short side doesn't use exit. Good.

Potential missed site: `Grind_AppendLayer` uses `exit_pips` for `exit_target`. For short, `exit_s` passed. Good.

Potential missed site: `Grind_RemoveLayerAt` then `Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);` in HandleSideDealFill after OUT_BY. It uses `exit_pips` param of HandleSideDealFill, which is side-specific. Good.

Potential missed site: In `Grind_HandleSideDealFill` for ENT, after AppendLayer, it calls `Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);` then computes fill_add and TryPlaceAddAtFill. Good.

Potential missed site: `Grind_TryPlaceAddAtFill` uses `g_grind_engine_add_pips_short` for short. In HandleSideDealFill, before calling TryPlaceAddAtFill, it computes:
```
const double fill_add = is_long
                              ? g_grind_engine_add_pips
                              : Grind_SidePips(false, g_grind_engine_add_pips,
                                               g_grind_engine_add_pips_short);
```
But note: `g_grind_engine_add_pips_short` was just set in OnTradeTransactionEngine to `Grind_SidePips(false, add_pips, add_pips_short)`. So this is effectively `Grind_SidePips(false, g_grind_engine_add_pips, g_grind_engine_add_pips_short)`. Since `g_grind_engine_add_pips_short` may already be the short value, this double applies. Let's test: Suppose long add=10, short add=6. OnTradeTransactionEngine sets `g_grind_engine_add_pips = 10`, `g_grind_engine_add_pips_short = Grind_SidePips(false,10,6)=6`. Then HandleSideDealFill short computes `fill_add = Grind_SidePips(false, g_grind_engine_add_pips=10, g_grind_engine_add_pips_short=6) = 6`. Good. If short add inherits (0), `g_grind_engine_add_pips_short` set to 10. Then `Grind_SidePips(false,10,10)=10`. Good. So double application is idempotent because `g_grind_engine_add_pips_short` is already side-resolved. If `g_grind_engine_add_pips_short` is 0 (stale) and short add should be 6, then `Grind_SidePips(false,10,0)=10` -> wrong. But OnTradeTransactionEngine sets it before. So no.

Potential bug: `Grind_ServiceDueAddFlags` computes add_s = `Grind_SidePips(false, add_pips, add_pips_short)`. It receives `add_s` from OnTickEngine already side-resolved! In OnTickEngine:
```
const double add_s = Grind_SidePips(false, add_pips, add_pips_short);
...
Grind_ServiceDueAddFlags(magic, slot, add_pips, deadband_pips, max_layers, lots, add_s);
```
Then inside ServiceDueAddFlags:
```
const double add_s = Grind_SidePips(false, add_pips, add_pips_short);
```
Parameter name `add_pips_short` here is actually `add_s` passed. So it computes `Grind_SidePips(false, add_pips, add_s)`. If add_s >0, returns add_s. If add_s == long (inherited), returns add_s. So double application idempotent if add_s already resolved. If add_s is 0? Not possible if add_pips>0 and inheritance: OnTickEngine computes add_s = add_pips (since short_value=0 -> long_or_both). Then ServiceDueAddFlags receives add_pips_short=add_pips, computes `Grind_SidePips(false, add_pips, add_pips)` = add_pips. Good. If asymmetric, add_s=6, receives 6, computes `Grind_SidePips(false,10,6)=6`. Good. So fine.

Potential bug: `Grind_LatticeOnTick` computes `exit_s` and `add_s` using passed short params. Good.

Potential bug: `Grind_AutoEjectOnTick` computes `exit_s` inside short block. Good.

Potential bug: `Grind_EjectPollCommand` computes `side_exit` after validation. If `is_long` false and `exit_pips_short` is 0 but long_or_both is 0? exit_pips can't be 0. Good.

Potential bug: `Grind_CarryExitPassBegin` short loop:
```
const double short_exit = Grind_SidePips(false, exit_pips, exit_pips_short);
const double formula = Grind_ExitPrice(..., short_exit, point, -1) + Grind_EjectOffsetGet(...);
```
It recomputes short_exit every iteration. Fine.

Potential bug: `Grind_CarryWorkBase` uses `const int dir = ...; const double side_exit = Grind_SidePips(dir > 0, exit_pips, exit_pips_short);` For short dir=-1, is_long false. Good.

Potential bug: `Grind_CarryExitPassStep` computes `shift_exit = Grind_SidePips(g_grind_carry_exit_work_long[idx], exit_pips, exit_pips_short);` then passes to CarryExitShiftLayer as `exit_pips`. But CarryExitShiftLayer doesn't use it. Dead. But formula_exit already computed with WorkBase. Good.

Potential bug: `Grind_CarryExitShiftLayer` uses `formula_exit` passed from WorkBase. WorkBase uses `exit_pips_short`. Good.

Potential bug: `Grind_CarryExitPassBegin` stores `formula_exit` without accrued and without carry shift. WorkBase recomputes formula including EjectOffset. It uses `exit_pips_short` passed. Good.

Potential bug: `Grind_ReconCheckInvariants` short uses `exit_s` for both check and detail. Good.

Potential bug: `Grind_RebuildBookFromTicketsInner` computes `exit_s` at top, but when calling `Grind_ReconCheckInvariants` it passes `exit_pips` and `exit_pips_short`, not `exit_s`. Inside ReconCheckInvariants recomputes exit_s. Good.

Potential bug: `Grind_ReconFailureOffendingForReason` doesn't handle `I6_SHORT_EXIT_FILL_ADVERSE`. Not v2.

Potential bug: `Grind_ReconFailureCapture` uses `Grind_ReconFailureSideHintJson` which parses comment. No.

Now, maybe there is a serious bug in `Grind_OnTickEngine`: It computes `width_s` and `add_s` at top, but then uses `width_s` for sell target and recenter, and `add_s` for EnsureAddNext. But what about the `Grind_TryPlaceL0` for short? It uses `sell_target` computed with `width_s`. Good.

But wait: `Grind_OnTickEngine` also calls `Grind_ServiceDueAddFlags(magic, slot, add_pips, deadband_pips, max_layers, lots, add_s);` before `Grind_ReconcileStrayL0`. ServiceDueAddFlags for short uses `add_s`. Good.

Potential bug: `Grind_OnTickEngine` calls `Grind_RetryMissingExits` before setting `g_grind_engine_add_pips_short`? It sets before. Good.

Potential bug: `Grind_OnTickEngine` sets `g_grind_engine_add_pips_short = add_s;` where `add_s = Grind_SidePips(false, add_pips, add_pips_short)`. If `add_pips_short` is 0, add_s = add_pips. So global short = long. Good. But if `add_pips_short` is negative (not -1) e.g. -2 from bad caller, Grind_SidePips returns long. But OnTickEngine inputs should be resolved g_geo_add_short (positive or inherited). In production, g_geo_add_short is positive. Good.

Potential bug: `Grind_OnTradeTransactionEngine` sets `g_grind_engine_add_pips_short = Grind_SidePips(false, add_pips, add_pips_short);` where add_pips_short passed from OnTradeTransaction as g_geo_add_short. If g_geo_add_short is positive asymmetric, good. If inherited, g_geo_add_short = g_geo_add_long. Then `Grind_SidePips(false, add_pips, add_pips_short)` returns add_pips_short (which equals add_pips). Good.

Now, T-3 stale globals: `g_grind_recon_exit_pips_short` set in OnInit. But in tests, `GV_RestoreEngineGlobals` sets it to 0.0. If a test calls `Grind_RetryMissingExits` without setting `g_grind_recon_exit_pips_short`, short inherits long. That's default. Good.

What about `g_grind_engine_add_pips_short` in tests: `GV_RestoreEngineGlobals` sets to 0.0. If a test calls `Grind_HandleSideDealFill` directly without setting `g_grind_engine_add_pips_short` and expecting short add, it would inherit long. But tests use OnTradeTransactionEngine which sets. Good.

Potential issue: `g_grind_engine_add_pips_short` is set in `Grind_OnTickEngine`, but if `Grind_OnTickEngine` is not called before a fill (e.g., first event is OnTradeTransaction), OnTradeTransaction sets it. Good.

Potential issue: If a fill is processed for long side, OnTradeTransactionEngine sets short global too. Good.

Now, maybe the branch has a bug in `Grind_OnTickEngine` signature: It has `width_pips_short` and `add_pips_short` but not `exit_pips_short`. The prompt says "the SHORT values travel in NEW LAST PARAMETERS (default 0.0) of thirteen dispatch functions". For OnTickEngine, the old function had `exit_pips` but no use? Let's verify old function maybe used exit_pips for something? In current code, `Grind_OnTickEngine` body does not use `exit_pips` at all. So maybe it was already unused before v2.0. The prompt says "the resolved LONG values travel where the single value travelled". If exit_pips was unused, it still travels nowhere. So no missing short. But why is it in the thirteen? Because it's a dispatch function that used to take exit_pips and now takes short width/add? The list includes OnTickEngine. It does have new short params. Fine.

Now, maybe there is a bug in `Grind_ReconCheckInvariants` signature parameter order: It has `const bool tolerate_exit_shortfall = false, const double exit_pips_short = 0.0`. Callers in tests GV4 call:
```
Grind_ReconCheckInvariants(l, 1, long_ranks, s, 1, short_ranks,
                                          10.0, point, 8, reason, false, 7.0)
```
So passes tolerate=false, short=7.0. Good.
In RebuildBookFromTicketsInner call:
```
Grind_ReconCheckInvariants(long_scratch, long_count, long_ranks,
                                 short_scratch, short_count, short_ranks,
                                 exit_pips, point, max_layers, reason_out,
                                 tolerate_exit_shortfall, exit_pips_short)
```
Good.

Potential bug: `Grind_RebuildBookFromTicketsInner` signature has `tolerate_exit_shortfall` before `exit_pips_short`. In `Grind_RebuildBookFromTickets` call, it passes `tolerate_exit_shortfall, exit_pips_short` to inner. Good.

Potential bug: `Grind_RebuildBookFromTickets` called from `Grind_CheckBookInvariants` with `false, g_grind_recon_exit_pips_short`. Good.
`Grind_ReconstructState` calls with `true, g_grind_recon_exit_pips_short`. Good.

Potential bug: In `Grind_CheckBookInvariants`, it passes `g_grind_recon_exit_pips` as exit_pips. That's long. For short, exit_s computed with short. Good.

Potential bug: In `Grind_ReconstructState`, same.

Now, maybe there is a bug in `Grind_RetryMissingExits`: It computes `exit_s = Grind_SidePips(false, g_grind_recon_exit_pips, g_grind_recon_exit_pips_short);` then calls `Grind_ExitQManageSide(g_grind_long, true, magic, slot, lots, g_grind_recon_exit_pips);` and `Grind_ExitQManageSide(g_grind_short, false, magic, slot, lots, exit_s);`. Good.

Potential bug: In `Grind_OnTickEngine`, it calls `Grind_RetryMissingExits(magic, slot, lots);` before setting `g_grind_recon_exit_pips_short`? It doesn't set it. But OnInit set. Good.

Now, maybe the tests have a flaw: GV7 sets `g_grind_engine_add_pips`? It does not set saved_add? It calls `Grind_OnTradeTransactionEngine(tr, GV_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);` So add_pips=10, add_pips_short=6. It expects short add at 1.20060. Good. It also asserts `g_grind_engine_add_pips_short == 6.0`. Good. But it doesn't test long add? GV8 does.

GV8: `Grind_OnTradeTransactionEngine(tr, ..., 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);` long add=10, short add=6. It expects long add at 1.19900. Good.

GV9: OnTickEngine with width_short=3.0, add_short=10.0 (but add_short not used for L0). It asserts short L0 at 1.20035. Mid = 1.20005. Width short=3 pips -> 0.00030. Sell = mid + 0.00030 = 1.20035. Good.

GV10: width_short=5.0, add_short=6.0. It expects short add at 1.20060. Good.

GV11: LatticeOnTick with exit_short=5.0, add_short=10.0. It asserts rolled exit at 1.19350. Need know seed. Adr162b_SeedShort8 likely short entries. If short exit=5, entry? The rolled level maybe from add_short. It asserts exit at 1.19350. If used long exit=9, would be different. Good.

GV12: Carry per side. Tests WorkBase with short 7.0 -> 1.19930. If used long 10 -> 1.20100? Wait for short, ExitPrice(entry, exit_pips, point, -1) = entry - exit*point*10. With entry 1.20000, exit 7 -> 1.19930. With long 10 -> 1.19900. It asserts 1.19930. Good.

GV13: Eject short per side. Fixture short depth 2, command for ticket 1101 (short layer 0). `Grind_EjectPollCommand(GV_MAGIC, true, 3.0, false, 7.0)`. It expects order price 1.24999 and offset 0.00269. Let's verify. Market seed 1.25000/1.25010. For short eject target = ask? `Grind_EjectTargetPrice(false)` clamps short exit to ask? Actually `Grind_EjectTargetPrice(false)` calls `Grind_CarryClampShortExit(ask, bid, ask, ...)`. With stops=0, min_dist=point. theoretical = ask = 1.25010. Clamp short exit: if theoretical >= bid - min_dist + 1e-12 -> out = bid - min_dist = 1.25000 - 0.00001 = 1.24999. So target=1.24999. Raw exit with short exit=7: entry effective? Layer 0 entry 1.24800. ExitPrice(eff, 7, point, -1) = 1.24800 - 0.00070 = 1.24730. Accrued from Grind_CarryAccruedGet(1101) likely 0. Offset = target - raw - accrued = 1.24999 - 1.24730 = 0.00269. Good. If used long exit=3? It would be 1.24770, offset 0.00229. So tests short wiring.

Thus many tests.

Now, which v2 behavior has no test? As above auto eject, service due flags, apply entry horizon, OnTimerStep passthrough, CheckBookInvariants/ReconstructState actual broker seam (ruled). Also perhaps `Grind_CarryExitPassOnWindowClose` short? No. `Grind_CarryEmitSnapshot` no per-side. `Grind_CarryExitPassReset` no.

Potential vacuous assertion: In GV12, `AssertTrue("GV12b all resting I6 at 5", C55_AllRestingI6Short());` This uses helper not defined in provided snippet. Could be vacuous if it doesn't check? We don't see. But prompt mentions. We can note not verifiable.

Potential test issue: GV10 setup as prompt says. Does it weaken? The stray L0 cancel happens before add placement. The test's purpose is to verify short add uses short add value. The stray L0 cancel does not affect the add calculation. However, if the short add wiring were missing, the code might use long add and still place add at 1.20100, test fails. So not weakened. But the setup triggers `STRAY_L0_CANCEL`, which could mask a bug where `Grind_ReconcileStrayL0` incorrectly cancels something needed. But not for the add value. We can say it does not weaken the add-value assertion; it does introduce an extra path (stray cancel) that is not the subject. The test would still fail on wrong add. However, it means the test does not verify that on a clean book (no stray L0) the short add is placed; but the stray cancel is orthogonal. We can mention as minor.

Now, need hunt for lookahead bias? This is not a strategy signal backtest, it's live EA. Lookahead may not apply. But the instruction says hunting lookahead, silent failures, schema mismatches, statistical flaws. We can mention no lookahead in provided code (live market). But maybe there is a lookahead in lattice tracking? `Grind_LatticeCopyTicks` uses ticks from `from_msc` to `Grind_MarketTimeMsc()`. It folds extreme over past ticks. Then in `Grind_LatticeTrySide`, it uses `extreme` to probe price and decide roll. This is not lookahead? It uses current market and past ticks to detect the most extreme price since layer open. It rolls when market crosses add level. Using the minimum ask over past ticks could be lookahead? Wait in live trading, when evaluating at `now`, it has access to past ticks. It uses `extreme` (lowest ask since tracking started) to decide if level was crossed. This could be a subtle lookahead: It rolls a layer if the add level was crossed at any time in the past, even if the market is now back. But that's by design: it's catching up on missed crosses. However, it could use future? No. It uses ticks up to current time. So no lookahead. But there is a potential: `Grind_LatticeFoldExtreme` includes `live = Grind_MarketAsk()` and folds into extreme. Then `Grind_LatticeTrySide` uses that extreme. That's current, not future. Fine.

Potential statistical flaw: Auto eject uses CopyRates current forming bar? `CopyRates(_Symbol, PERIOD_M1, 0, bar_count, rates);` includes current unfinished bar. It uses `rates[0].time + 60` and checks window intact with now. Could include incomplete bar causing lookahead? Not per-side. But not v2.

Focus on v2.

Let's inspect code for any missing short in `Grind_AutoEjectOnTick`. It computes `exit_s` only if short depth >= max. But `Grind_AutoEjectTrySide` for long uses `exit_pips` param. Good. However, `Grind_AutoEjectOnTick` builds `vals_long` and `vals_short`. For short, it uses `rates[i].high + rates[i].spread * _Point`. Good.

Potential bug: `Grind_AutoEjectOnTick` calls `Grind_AutoEjectTrySide(true, magic, exit_pips, ...)` for long. If long is active, exit_pips is the long_or_both param. In OnTick, it's `g_geo_exit_long`. Good. For short, it computes `exit_s`. Good.

Potential bug: `Grind_AutoEjectTrySide` has no short param; it's called with side-specific. Good.

Potential bug: `Grind_EjectPollCommand` has `exit_pips_short` default 0.0. In OnTick, called with g_geo_exit_short. Good.

Potential bug: `Grind_LatticeOnTick` computes `exit_s` and `add_s` only if short depth >= max. Good.

Potential bug: `Grind_LatticeTrySide` is called for short with `exit_s, add_s`. Good.

Potential bug: `Grind_LatticeRollLayer` uses `exit_pips` for both exit formula and cost. Good.

Potential bug: `Grind_LatticeMaybeStranded` uses `add_pips`. Good.

Now, check `Grind_LatticeRollLayer` cost: `const double cost = Grind_LatticeRollCost(entry, level, exit_pips, _Point, is_long);` For short, `Grind_LatticeRollCost` does:
```
if(is_long) return entry - ExitPrice(level, exit_pips, point, 1);
return ExitPrice(level, exit_pips, point, -1) - entry;
```
With short exit=5, entry=1.248, level=1.194? cost positive? Not relevant.

Potential bug: `Grind_LatticeRollDetail` uses `cost / (10.0 * _Point)`; not.

Now, T-1 "including paths from OnInit (`Grind_RetryMissingExits`), the quarantine branch of OnTick, the carry window close, ADR-152's due flags and held adds, and the opposite-L0 recentre (`Grind_TryRecenterOppositeL0`)."

We covered:
- OnInit RetryMissingExits uses globals set. Good.
- quarantine branch of OnTick:
```
if(g_grind_quarantined) {
      if(Grind_GuardsAllowTrading(InpMagic, InpLots))
         Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);
      return;
}
```
Uses globals. Good.
- carry window close:
```
void Grind_CarryExitPassOnWindowClose(...)
```
Does not price, just summary/reset. No.
- ADR-152 due flags and held adds:
`Grind_ServiceDueAddFlags` uses add_s computed. Good.
`Grind_EnsureAddNext` uses add_pips passed. Good.
`Grind_ApplyEntryHorizon` uses add_pips passed. Good.
- opposite-L0 recentre: covered.

Potential missed site: `Grind_EntryHorizonCheckGap` uses target passed. Good.
`Grind_EntryHorizonClampAddTarget` no side.

Potential missed site: `Grind_CancelOwnEntryOrders` no.

Potential missed site: `Grind_BreakerOnTick` no.

Potential missed site: `Grind_SessionStep` no.

Potential missed site: `Grind_CapPublishOwnExposure` no.

Thus T-1 likely HOLDS with maybe a note about OnTickEngine's unused exit_pips and ServiceDueAddFlags double resolving idempotent. But need decide verdict. Could be HOLDS.

However, let's look for a subtle bug: In `Grind_OnTradeTransactionEngine`, it sets `g_grind_engine_add_pips_short = Grind_SidePips(false, add_pips, add_pips_short);` but then in `Grind_HandleSideDealFill`, the short fill_add is computed as:
```
const double fill_add = is_long
                              ? g_grind_engine_add_pips
                              : Grind_SidePips(false, g_grind_engine_add_pips,
                                               g_grind_engine_add_pips_short);
```
As noted, double resolution. But consider `g_grind_engine_add_pips_short` is set to `Grind_SidePips(false, add_pips, add_pips_short)`. Suppose `add_pips_short` is exactly 0.0 (inherit). Then `g_grind_engine_add_pips_short = add_pips`. Then HandleSideDealFill computes `Grind_SidePips(false, g_grind_engine_add_pips, g_grind_engine_add_pips_short)` = `Grind_SidePips(false, add_pips, add_pips)` = add_pips. Good.
Suppose `add_pips_short` is positive 6.0. Then `g_grind_engine_add_pips_short = 6.0`. Handle computes `Grind_SidePips(false, add_pips, 6.0)` = 6.0. Good.
Suppose `add_pips_short` is negative -2 (invalid but could be passed in tests). Then `g_grind_engine_add_pips_short = add_pips` (since >0 false). Handle computes `Grind_SidePips(false, add_pips, add_pips)` = add_pips. So negative treated as inherit. That's consistent with Grind_SidePips.
No bug.

Potential bug: `g_grind_engine_add_pips_short` is set in OnTickEngine to `add_s`, which is already `Grind_SidePips(false, add_pips, add_pips_short)`. Then HandleSideDealFill computes `Grind_SidePips(false, g_grind_engine_add_pips, g_grind_engine_add_pips_short)`. If `g_grind_engine_add_pips` and `g_grind_engine_add_pips_short` are both set, double resolution idempotent. Good.

Potential bug: In `Grind_OnTickEngine`, `g_grind_engine_add_pips_short = add_s;` but `add_s` is computed with `add_pips_short` parameter. If `add_pips_short` is 0.0, add_s = add_pips. So global short = long. Good.

Potential bug: `Grind_OnTickEngine` does not set `g_grind_engine_add_pips` for short? It sets both.

Potential bug: `Grind_OnTradeTransactionEngine` sets `g_grind_engine_add_pips = add_pips;` and short. Good.

Now, maybe the bug is in `Grind_ServiceDueAddFlags`: It takes `add_pips` and `add_pips_short` (which is already `add_s`). Inside it recomputes `add_s = Grind_SidePips(false, add_pips, add_pips_short);`. If `add_pips_short` is already the short value, this is fine. But if `add_pips_short` is 0.0 (e.g., a caller invokes ServiceDueAddFlags directly with only 6 args, default 0.0), it inherits long. That's intended. If OnTickEngine passes `add_s`, and `add_s` equals long when inherited, then `Grind_SidePips(false, add_pips, add_pips)` = add_pips. Good.

Potential bug: In `Grind_ServiceDueAddFlags`, for long due flags, it uses `add_pips` for `Grind_EnsureAddNext` and `Grind_SendNextAddEnt`. For short, it uses `add_s`. Good.

Potential bug: In `Grind_ServiceDueAddFlags`, the long branch uses `add_pips` but if `add_pips` is the long value. Good.

Potential bug: In `Grind_EnsureAddNext`, it calls `Grind_ApplyEntryHorizon` with `add_pips`. Good.

Potential bug: In `Grind_ApplyEntryHorizon`, it uses `Grind_ComputeAddTarget(side, is_long, add_pips)` and `Grind_SendNextAddEnt(... add_pips ...)`. Good.

Potential bug: In `Grind_TryPlaceAddAtFill`, it calls `Grind_ApplyEntryHorizon(... add_pips ...)` or `Grind_SendNextAddEnt(... add_pips ...)`. The add_pips is side-specific from fill_add. Good.

Potential bug: In `Grind_HandleSideDealFill`, for short, `fill_add` uses `g_grind_engine_add_pips_short`. But what if the fill is processed in `OnTradeTransactionEngine` for a short ENT, and `g_grind_engine_add_pips_short` is set correctly. Good.

Potential bug: In `Grind_HandleSideDealFill`, for long, `fill_add` uses `g_grind_engine_add_pips`. Good.

Potential bug: In `Grind_HandleSideDealFill`, for EXT fill, it doesn't use add. Good.

Potential bug: In `Grind_HandleSideDealFill`, for OUT_BY, it calls `Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);` with side-specific exit. Good.

Now, let's consider `Grind_AutoEjectOnTick`: It has parameter `exit_pips_short = 0.0`. In OnTick, it passes `g_geo_exit_short`. Good. But inside, it only computes `exit_s` for short. Long uses `exit_pips`. Good.

Potential bug: `Grind_AutoEjectOnTick` calls `Grind_AutoEjectTrySide(true, magic, exit_pips, ...)` even if long depth < max? It checks before. Good.

Potential bug: `Grind_AutoEjectTrySide` uses `exit_pips` for `Grind_EjectAcceptLayer`. Good.

Potential bug: `Grind_AutoEjectTrySide` if already ejected uses `Grind_EjectTargetPrice` and `Grind_CarryMinPassiveDistance`, no exit. Good.

Potential bug: `Grind_EjectPollCommand` if not found returns -1. It computes side_exit after validation. Good.

Potential bug: `Grind_EjectPollCommand` uses `exit_pips_short` default 0.0. In tests GV13 passes 7.0. Good.

Now, T-2: Producer and checker agree. Need name any pair that can differ and when. We identified potential: `Grind_OnTickEngine` does not update `g_grind_recon_exit_pips_short`; if OnTickEngine is called with a short exit different from the global (e.g., a test or future caller), RetryMissingExits (producer) uses global, while I6 checker also uses global. So they agree with each other but may disagree with OnTickEngine's intent. In production, global set from same input. No halt. But if runtime input changed? MT5 reinit. So not.

Potential disagreement: `Grind_AutoEjectOnTick` and `Grind_EjectPollCommand` use `g_geo_exit_short` passed from OnTick. I6 uses `g_grind_recon_exit_pips_short` set in OnInit from `g_geo_exit_short`. Same. Good.

Potential disagreement: `Grind_LatticeOnTick` uses `g_geo_exit_short`; I6 uses same global. Good.

Potential disagreement: `Grind_CarryOnTimerStep` uses `g_geo_exit_short`; I6 uses same. Good.

Potential disagreement: `Grind_OnTradeTransactionEngine` uses `g_geo_exit_short` from OnTradeTransaction; I6 uses same. Good.

Potential disagreement: In `Grind_HandleSideDealFill`, for short, exit target uses `exit_s` passed from OnTradeTransactionEngine, which uses `g_geo_exit_short`. I6 uses `g_grind_recon_exit_pips_short` = g_geo_exit_short. Same.

Potential disagreement: `Grind_AppendLayer` uses `Grind_ExitQFormulaTarget(entry_price, exit_pips, _Point, is_long, position_ticket)`. This includes `Grind_CarryAccruedGet` and `Grind_EjectOffsetGet` at append time. At that moment, accrued=0, eject=0. I6 later expects same with current accrued/eject. Good.

Potential disagreement: In `Grind_ExitQManageSide`, when placing a new exit, it uses `Grind_ExitQFormulaTarget(... exit_pips ...)` then clamps. If clamped, records shift. I6 expects exit_pips + accrued + eject + carry_shift. Since clamped records shift = price - formula, expected = formula + shift = price. Good. Uses same exit_pips. Good.

Potential disagreement: In `Grind_LatticeRollLayer`, if `layer.exit_order_ticket != 0`, it modifies to `price = formula` where `formula = ExitPrice(level, exit_pips)+accrued`. It then if clamped or diff records shift = price - formula (the unclamped formula), else deletes. It also deletes eject offset. I6 expects ExitPrice(eff=level, exit_pips)+accrued+0+shift = formula+shift = price. Good. If not clamped, shift deleted -> price=formula. Good.

Potential disagreement: In `Grind_LatticeRollLayer`, if `layer.exit_order_ticket == 0`, it sets `side.layers[idx].exit_target = formula;` but does not place an order. I6 only checks resting exits? Wait `Grind_CheckBookInvariants` reads broker book, so if no exit order, not checked. `Grind_ReconstructState` checks? It checks exit coverage required. If no exit, I3. But that's existing. The `exit_target` stored is formula without eject offset? Actually it deletes EjectOffset and CarryShift. I6 not checking because no order. Later when `Grind_ExitQManageSide` places, it computes formula with `Grind_ExitQFormulaTarget` which includes exit_pips. Good. Uses same exit_pips passed to LatticeRollLayer. Good.

Potential disagreement: `Grind_CarryExitPassBegin` for short uses `short_exit` for formula. `Grind_CarryWorkBase` also uses `short_exit`. `Grind_CarryExitPassStep` passes `exit_pips_short` to WorkBase. Good.
But `Grind_CarryExitShiftLayer` receives `shift_exit` but doesn't use; it uses `formula_exit` from WorkBase. Good.

Potential disagreement: `Grind_CarryExitPassStep` computes `shift_exit = Grind_SidePips(is_long, exit_pips, exit_pips_short);` and passes to CarryExitShiftLayer as `exit_pips`. But CarryExitShiftLayer doesn't use it. If future code uses it, it's side-specific. Good.

Potential disagreement: `Grind_ReconCheckInvariants` short uses `exit_s` computed from `exit_pips_short`. I6 producer uses same. Good.

So T-2 likely HOLDS.

Now, T-3 stale globals. Need determine if any reader can see 0.0 or stale. Let's think about `g_grind_recon_exit_pips_short` set in OnInit. But `Grind_CheckBookInvariants` is called in OnTick before OnTickEngine. If OnTick runs before OnInit? No. If OnInit fails before setting? It sets before ReconstructState. Good.

`g_grind_engine_add_pips_short` set in OnTickEngine and OnTradeTransactionEngine. If an OnTradeTransaction arrives before OnInit? MT5 doesn't call OnTradeTransaction before OnInit? ASSUMED. If it does, globals default 0.0. Then HandleSideDealFill short would inherit long (0? actually g_grind_engine_add_pips default 0.0 too). But no trading before init. Not a concern.

Potential stale: `g_grind_engine_add_pips_short` is set in OnTickEngine, but if `Grind_GuardsAllowTrading` returns false, OnTickEngine returns before setting. However, OnTradeTransactionEngine sets before fills. So no stale for fills. But could `Grind_HandleSideDealFill` be called from OnTick? No.

Potential stale: `g_grind_engine_add_pips_short` is set in OnTradeTransactionEngine only for DEAL_ADD. If a fill arrives, set. Good.

Potential stale: `g_grind_recon_exit_pips_short` is set in OnInit, but if tests modify it and don't restore, later tests could see stale. The provided tests restore via `GV_RestoreEngineGlobals`, which sets it to 0.0. But if a test sets it to 7.0 and then calls `GV_RestoreEngineGlobals`, it clears. So no leftover. However, `GV_RestoreEngineGlobals` does not restore `g_grind_engine_add_pips_short` to its pre-test value; it sets to 0.0. If a prior test had set it to non-zero and not restored, this clears. Not a correctness issue for tests because each test sets what it needs. But if a test relies on inherited short add from a previous global? No.

Potential stale: In production, `g_grind_engine_add_pips_short` is not set in OnInit, but OnTickEngine sets it before any fills? OnTradeTransaction sets before fills. Good.

What does a reader see if 0.0? For short, `Grind_SidePips(false, long, 0.0)` returns long. So if stale 0.0, short inherits long. That's the default. If asymmetric short should be 6, and stale 0.0, then a fill processed before any OnTradeTransaction/OnTick would use long. But OnTradeTransaction sets it before. So no.

Potential stale: `g_grind_recon_exit_pips_short` default 0.0. If OnInit not run? No.

Thus T-3 likely HOLDS with note: readers before first set would inherit long (fail-safe), not 0.0 as a value; no path in production reads before set. But tests can leave values; test harness restores.

Now, T-4 Inputs. Need verdict. Sentinel and validation. Let's examine `Grind_ResolveSideInput` tolerance. `MathAbs(override_value + 1.0) <= 1e-9`. For -1.0 exactly, OK. For -0.999999999 (diff 1e-9? Actually +1 = 1e-9? Let's compute: -0.999999999 +1 = 0.000000001 = 1e-9. `<=1e-9` true. So within 1e-9. For -0.999999998, diff 2e-9 >, fatal. MT5 .set file parsing: likely exact for "-1.0". But if scientific notation? `-1e0` exact? Double -1.0 exact. So likely fine. Need say ASSUMED MT5 parses decimal -1.0 to exact binary -1.0; if it ever yields a value off by >1e-9, it FATALs. The tolerance is 1e-9, so -1.000000001 would pass? -1.000000001 +1 = -1e-9, abs 1e-9 <=1e-9 true. So ±1e-9. Good.

0 or negative overrides: `Grind_ResolveSideInput` returns false for 0, -0.5, -2. Good. Only -1 within tolerance is inherit. So fatal otherwise. Good.

Order of checks: Resolve all six first. If any invalid, return INIT_FAILED. Then base geometry, base ratio, long geometry, long ratio, short geometry, short ratio, deadband, magic, lattice, magic lock. No orders before. Good.

Potential issue: base validation still required even if all six overrides positive. If base inputs are -1 (default) and all side overrides positive, OnInit fails at base geometry check. Is that intended? The branch says "-1 inherits the base input, >0 overrides". If all six are >0, base is unused. But code requires base >0. This is a design flaw? It means you cannot use only per-side overrides without setting base. But maybe base inputs are still required for legacy and for stranded threshold? `InpStrandedThreshPips` is symmetric. `InpMaxLayers` symmetric. `InpWidthPips` etc. are base. If all six overridden, base can be any positive. The user might set base to one of the values. The presets likely have base set. The prompt says "six inputs exactly -1 inherits the base input, >0 overrides". It doesn't say base can be unset when all overrides. So not a bug. But worth noting as NEEDS-FIX? The question: "the order of checks in OnInit, and whether any order can be placed before validation fails." We can say order safe; but base validation is unconditional, so an all-overrides preset must still carry a valid base. If that's not intended, needs fix. I'd mark T-4 HOLDS with caveat.

Potential issue: `Grind_ResolveSideInput` uses `override_value + 1.0`; if override is NaN, `MathAbs(NaN) <= 1e-9` is false, `NaN >0` false, returns false. Good.

Potential issue: `Grind_ValidateGeometryInputs` uses `if(width_pips <= 0.0) return false;` etc. If `exit_pips` is NaN, `NaN <=0` false, so passes? Then later `Grind_ExitPrice` NaN. MT5 inputs can't be NaN. Not.

Potential issue: The base ratio check `Grind_ValidateAddWidthRatio(InpWidthPips, InpAddPips)` uses base values. If base values are -1 (unset) but all sides overridden, it fails. As above.

Potential issue: The side-specific ratio checks use resolved values. Good.

Potential issue: `InpMaxLayers` and `InpStrandedThreshPips` are validated with base and each side, symmetric. Good.

Now, T-5 same when symmetric. We think holds. But check reporting: In heartbeat, legacy keys carry long values. `Grind_TelemetryHeartbeatJson` gets `g_geo_width_long, g_geo_add_long, g_geo_exit_long` in old slots. New keys get long and short. If all -1, long=short=base. So reporting identical to main except six new keys. The prompt says "same in every path, including reporting?" Reporting has new keys, so not identical JSON. But legacy keys same. The threat likely asks behavior, not exact JSON. The new keys add fields. So not identical JSON, but values correct. If "identical to main" means no behavior change, extra fields are a change. But the branch adds new keys by design. The threat T-5 says "With all six at -1 (every existing preset), is the behaviour identical to `main` in every path, including reporting? Any path where `Grind_SidePips(false, x, 0.0)` or the wiring can differ from `x`?" We can say trading behavior identical; reporting has additional keys by design, legacy keys unchanged. No path where `Grind_SidePips(false,x,0.0)` differs from x. If short_value is 0.0, returns x. Good. If wiring passes `g_geo_*_short` which equals base, `Grind_SidePips(false, long, short)` returns short if short>0. Since short==long, same. Good.

Potential issue: `Grind_SidePips(false, x, 0.0)` returns x. But in production, if all -1, `g_geo_*_short` is not 0.0; it's base. So `Grind_SidePips(false, long, short)` returns short (which equals long). Same value. Good.

T-6 Reporting. Need scrutinize heartbeat StringFormat count/order. Let's count format specifiers and args in `Grind_BuildHeartbeatJson`. The first part is `Grind_TelemetryHeartbeatJson` call with 22 args? Not our concern. The appended StringFormat has format string:
```
",\"add_due_long\":%s,\"add_due_short\":%s,"
"\"entry_stopped\":%s,\"near_reserve_blocks\":%d,"
"\"guard_total\":%d,\"entry_place_latency_ms\":%d,"
"\"add_held_long\":%s,\"add_held_short\":%s,"
"\"add_held_target_long\":%s,\"add_held_target_short\":%s,"
"\"entry_transitions_used_long\":%d,\"entry_transitions_used_short\":%d,"
"\"add_gap_missed_long\":%d,\"add_gap_missed_short\":%d,"
"\"exit_clamped_promotions_long\":%d,\"exit_clamped_promotions_short\":%d,"
"\"width_pips_long\":%.4f,\"width_pips_short\":%.4f,"
"\"add_pips_long\":%.4f,\"add_pips_short\":%.4f,"
"\"exit_pips_long\":%.4f,\"exit_pips_short\":%.4f}"
```
Count specifiers:
1 add_due_long %s
2 add_due_short %s
3 entry_stopped %s
4 near_reserve_blocks %d
5 guard_total %d
6 entry_place_latency_ms %d
7 add_held_long %s
8 add_held_short %s
9 add_held_target_long %s
10 add_held_target_short %s
11 entry_transitions_used_long %d
12 entry_transitions_used_short %d
13 add_gap_missed_long %d
14 add_gap_missed_short %d
15 exit_clamped_promotions_long %d
16 exit_clamped_promotions_short %d
17 width_pips_long %.4f
18 width_pips_short %.4f
19 add_pips_long %.4f
20 add_pips_short %.4f
21 exit_pips_long %.4f
22 exit_pips_short %.4f

Args after format:
```
g_grind_add_due_long ? "true" : "false",      1
g_grind_add_due_short ? "true" : "false",     2
Grind_ApiCounterEntryStopped() ? "true" : "false", 3
g_grind_near_reserve_blocks,                  4
g_grind_last_guard_total,                     5
(int)g_grind_entry_place_latency_ms,          6
g_grind_long.add_held ? "true" : "false",     7
g_grind_short.add_held ? "true" : "false",    8
g_grind_long.add_held ? DoubleToString(...) : "null", 9
g_grind_short.add_held ? DoubleToString(...) : "null", 10
g_grind_long.entry_transitions_used,          11
g_grind_short.entry_transitions_used,         12
g_grind_long.add_gap_missed,                  13
g_grind_short.add_gap_missed,                 14
g_grind_long.exit_clamped_promotions,         15
g_grind_short.exit_clamped_promotions,        16
g_geo_width_long,                             17
g_geo_width_short,                            18
g_geo_add_long,                               19
g_geo_add_short,                              20
g_geo_exit_long,                              21
g_geo_exit_short);                            22
```
Matches. Good.

Potential JSON issue: `add_held_target_long` is either `DoubleToString(...)` or `"null"`. If it's a number, unquoted. If null, unquoted null. Valid. Good.

Potential JSON issue: The base heartbeat from `Grind_TelemetryHeartbeatJson` may already end with `}` and no newline. Code strips and appends. If base heartbeat length 0? returns hb (empty) no new keys. Not invalid.

Potential JSON issue: If `Grind_TelemetryHeartbeatJson` returns JSON with trailing comma before `}`? Not v2.

INIT/DEINIT JSON: We can't see `Grind_ArchiveConfigFields` and `Grind_ArchiveGeometryFields`. Need quote call. The code:
```
const string init_fields = Grind_ArchiveConfigFields(
      "INIT", 0, _Symbol, InpSlot, GRIND_EA_BUILD,
      (long)AccountInfoInteger(ACCOUNT_LOGIN),
      g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,
      InpDeadbandPips, InpStrandedThreshPips,
      InpCapLegA, InpCapLegB, InpCapLegAThresh, InpCapLegBThresh,
      InpTelemetryInstance, InpVerboseLog, InpConfigWarning,
      EnableTelemetry, TelemetryIntervalSec, InpEnableCarryPass) +
      "," + Grind_ArchiveGeometryFields(g_geo_width_long, g_geo_add_long, g_geo_exit_long,
                                        g_geo_width_short, g_geo_add_short, g_geo_exit_short);
   Grind_ArchiveEnqueue("config_event", init_fields);
```
If `Grind_ArchiveConfigFields` returns a JSON object with outer braces, concatenation invalid. But likely returns fields. We can mark as ASSUMED. Key names? `Grind_ArchiveGeometryFields` not shown. The prompt says six new keys in INIT/DEINIT. We can't verify key names. Could be a schema mismatch if it emits `width_long` vs expected `width_pips_long`. But no documentation. We can only note unverifiable. The task expects us to find what tests cannot see. Maybe there is a bug in the reporting: In DEINIT, they call `Grind_ArchiveConfigFields` with `g_geo_width_long, g_geo_add_long, g_geo_exit_long` (long values) for legacy keys, then `Grind_ArchiveGeometryFields` with all six. Good. In INIT, same. The legacy keys carry long. Good.

Potential bug: In OnInit, the `GRIND_GEOMETRY` Print line uses `g_geo_*` values. Good.

Potential bug: The heartbeat new keys use `g_geo_width_long` etc. But these globals are set in OnInit from resolved inputs. Good.

Potential bug: If OnInit fails before setting globals? It resolves before validation. If validation fails, no heartbeat. Good.

Potential bug: `Grind_ArchiveConfigFields` call in DEINIT uses `g_geo_exit_long` etc. If DEINIT happens after a reinit with new inputs? MT5 reinit calls OnDeinit then OnInit. The globals may be from old init. That's correct for old deinit. Good.

Potential bug: The DEINIT event is read at next init and enqueued with old values. It uses `prev_reason` etc. and current `g_geo_*`? Wait:
```
if(Grind_ArchiveReadPendingDeinit(InpMagic, prev_reason, prev_time, prev_anchor)) {
      const string deinit_fields = Grind_ArchiveConfigFields(
         "DEINIT", prev_reason, _Symbol, InpSlot, GRIND_EA_BUILD,
         (long)AccountInfoInteger(ACCOUNT_LOGIN),
         g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,
         ...
```
This is in OnInit of the *new* instance. It uses current `g_geo_*` values (just resolved from new inputs), not the old ones from when the DEINIT was recorded. Wait `Grind_ArchiveReadPendingDeinit` reads pending deinit fields like reason, time, anchor. But the config fields passed here are the *new* Init's geometry, not the old instance's. That seems like a pre-existing bug? Let's examine: OnDeinit calls `Grind_ArchiveRecordDeinit(InpMagic, reason, TimeCurrent(), g_grind_archive_anchor_ms);` It records reason, time, anchor. It does not record geometry. Then on next OnInit, when reading pending deinit, it constructs DEINIT config fields using the new `g_geo_*` values. That would report new geometry with old deinit reason. That is a reporting bug, but is it v2.0? The prompt says "the INIT and DEINIT JSON (commas, key names)". This could be a schema mismatch: DEINIT should report old geometry. But was it already like that before v2? In main, there was only one geometry, and a reinit with changed inputs would also use new geometry in DEINIT. So pre-existing. But with v2, per-side geometry makes it more likely. Should we flag? The task is audit feature branch before merge. If it's pre-existing, maybe not. But the prompt asks can any produce invalid JSON or wrong values? DEINIT could produce wrong values (new geometry instead of old). Let's verify code: `Grind_ArchiveRecordDeinit` only stores reason, time, anchor. The DEINIT event is enqueued at *next* OnInit after resolving current inputs. So indeed it uses current inputs. This is a wrong value bug. But is it introduced by v2? The branch adds geometry fields to DEINIT. So it's in scope. Let's quote:
```
const string deinit_fields = Grind_ArchiveConfigFields(
         "DEINIT", prev_reason, _Symbol, InpSlot, GRIND_EA_BUILD,
         (long)AccountInfoInteger(ACCOUNT_LOGIN),
         g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,
```
These are the new init's resolved values. If the user changes inputs between runs, the DEINIT record for the previous run will show the new values. That is a reporting flaw. However, the branch may have always had this for legacy keys. But the v2 adds per-side keys, making it more visible. The prompt explicitly asks T-6 reporting. We should flag as NEEDS-FIX or at least note. Is there a test? No test for DEINIT cross-init. This is a "test cannot see" issue. Good catch.

But wait: `Grind_ArchiveReadPendingDeinit` might read stored fields including geometry? We don't see implementation. It returns reason, time, anchor. The call to `Grind_ArchiveConfigFields` uses current globals. So if the pending deinit had stored geometry, it would be ignored. The code as shown uses current. So likely wrong. But could `g_geo_*` be set from stored deinit? No, they are set from Inp inputs at top of OnInit. So yes.

However, the task's threat T-6 says "the INIT and DEINIT JSON (commas, key names), the config dump: can any produce invalid JSON or wrong values?" So wrong values: DEINIT geometry uses new inputs. We can quote and mark NEEDS-FIX. Smallest fix: persist resolved geometry in `Grind_ArchiveRecordDeinit` and use it when building deinit fields, or build deinit fields in OnDeinit. But OnDeinit lacks telemetry? It can enqueue. Actually OnDeinit calls `Grind_ArchiveRecordDeinit` which probably writes to disk. Could instead enqueue config_event in OnDeinit directly. But they defer to next init to avoid losing logs? Anyway.

Is there another reporting bug: In OnInit, the `deinit_fields` concatenates `Grind_ArchiveConfigFields(...) + "," + Grind_ArchiveGeometryFields(...) + "," + Grind_ArchiveDeinitExtraFields(...)`. If `Grind_ArchiveConfigFields` returns trailing comma? Unknown. We can note unverifiable.

Potential JSON comma bug: In INIT, it does:
```
const string init_fields = Grind_ArchiveConfigFields(...) +
      "," + Grind_ArchiveGeometryFields(...);
   Grind_ArchiveEnqueue("config_event", init_fields);
```
If `Grind_ArchiveConfigFields` returns a complete JSON object with outer braces, this is invalid. But likely it returns fields. We can only assume. Maybe `Grind_ArchiveEnqueue` wraps? Not shown.

Potential heartbeat JSON: If `Grind_TelemetryHeartbeatJson` returns a JSON object with outer braces, code strips last `}` and appends `,...}`. That's valid if it had no trailing comma. Good.

Potential bug: The new heartbeat keys are appended only if `hb` ends with `}`. If the base heartbeat is an empty string or invalid, new keys omitted. Not v2.

Potential bug: In `Grind_BuildHeartbeatJson`, the new keys are after the base heartbeat, so if the base heartbeat already has a key named `width_pips_long`? Unlikely. Schema mismatch? The prompt says six new keys. The code uses `width_pips_long`, `width_pips_short`, `add_pips_long`, `add_pips_short`, `exit_pips_long`, `exit_pips_short`. The prompt says "six new keys in the heartbeat and INIT/DEINIT fields". It doesn't specify names. Could be okay.

Now, T-7 Tests. Need list test gaps and vacuous. We can be exhaustive.

Test gaps:
1. `Grind_AutoEjectOnTick` per-side short exit: no GV test. There may be existing auto eject tests, but not in `fxgrind_tests_gv.mqh`. The prompt says which v2 behavior has no test that fails without it. We can say no test in the provided GV file exercises `Grind_AutoEjectOnTick` with `exit_pips_short` different from `exit_pips`; the short wiring would be unverified if GV13 is not enough? Actually GV13 tests `Grind_EjectPollCommand` only. Auto eject uses `Grind_AutoEjectOnTick` -> `Grind_AutoEjectTrySide` -> `Grind_EjectAcceptLayer`. The short `exit_s` is computed in AutoEjectOnTick. If that computation were missing, GV13 wouldn't catch. So gap.
2. `Grind_ServiceDueAddFlags` per-side short add: no test. GV7/GV10 test fill-time and tick paths, not ADR-152 due flags. If the short `add_s` computation in ServiceDueAddFlags were wrong, no test in GV file fails. (There may be existing ADR-152 tests, but not per-side.)
3. `Grind_ApplyEntryHorizon` per-side short add: no test with `InpEntryHorizonPips > 0`. GV tests keep horizon off. If short add passed wrong to ApplyEntryHorizon, no test.
4. `Grind_CarryOnTimerStep` passthrough of `exit_pips_short` to `Grind_CarryExitPassStep`: GV12 calls `Grind_CarryExitPassBegin`/`Step` directly, not `OnTimerStep`. If OnTimerStep dropped the short param, GV12 wouldn't catch.
5. `Grind_CheckBookInvariants` and `Grind_ReconstructState` actual broker book short wiring: ruled deploy-only. No test seam.
6. `Grind_TryRecenterOppositeL0` short width: no test for opposite-L0 recenter with asymmetric short width. GV9 tests initial L0 placement, not recenter. If recenter passed long width to short, no GV test.
7. `Grind_OnTickEngine` exit_pips_short wiring? Since OnTickEngine doesn't have exit_pips_short, no test. But it uses global recon. If global recon short is stale, no test? GV10 sets global. Not.
8. `Grind_RetryMissingExits` in OnInit path? GV3 tests function directly with globals set. OnInit path sets globals and calls function. Good enough.
9. `Grind_CarryExitPassOnWindowClose` no per-side pricing.
10. `Grind_CarryWorkBase` old arity test in GV12: `AssertNear("GV12 short base old arity", Grind_CarryWorkBase(1, 10.0, 0.00001), 1.19900, 1e-9);` This tests default short=0 inherits long. Good.

Vacuous assertions:
- In GV5, `AssertNear("GV5 short exit target", ArraySize(S2.layers) == 1 ? S2.layers[0].exit_target : 0.0, 1.19930, 1e-10);` If array size not 1, it compares 0.0 and fails. Not vacuous.
- In GV7, similar. Not vacuous.
- In GV10, the stray L0 setup: The test first runs two ticks on flat book, so short L0 exists. Then it manually seeds short layer and leaves `g_grind_short.l0_pending_ticket` set. The next tick cancels it as STRAY_L0_CANCEL. Does this weaken the test? The assertion on short add price still fails if wrong. However, the test's setup does not test the clean book path; it tests add placement after a stray L0 cancellation. If the stray cancellation had a bug that also cleared the add pending or affected `g_grind_ent_sent_this_tick`, the test might fail for unrelated reasons. But it doesn't make the short add assertion vacuous. The prompt asks "Does that setup weaken the test?" We can say it does not make the add-value assertion vacuous, but it adds a stray-cancel side effect; the test would still fail if short add used long. It does mean the test does not verify short add placement on a book without a stray L0. So minor.
- GV1 `Test_GV1_SidePips` calls `GV_RestoreEngineGlobals(saved_add, saved_recon);` at end, but it doesn't modify them. Harmless.
- GV2 doesn't check `out` on false returns. Not vacuous.
- GV3: `AssertTrue("GV3 long exit placed", g_grind_long.layers[0].exit_order_ticket != 0);` If placement fails, next AssertNear uses `Grind_OrderGetPriceOpen(0)`? It would compare 0.0 to expected and fail. Not vacuous.
- GV4: `AssertFalse` / `AssertTrue` with reason. Good.
- GV11: `AssertTrue("GV11 S0 rolled at short level", Grind_VLHas(7101UL) && MathAbs(Grind_VLGet(7101UL) - 1.19400) <= 1e-9);` If not rolled, fails. Then `AssertFalse("GV11 one level only", Grind_VLHas(7102UL));` If first fails, still executes. Good.
- GV12: `AssertTrue("GV12 two work items", g_grind_carry_exit_work_count == 2);` Then `AssertNear` uses index 0 and 1. If work_count != 2, index 1 might be out of bounds? ArraySize maybe 0, accessing index 1 could be out of range. MQL5 arrays? If array size 0, accessing index 1 may cause runtime error. But test would fail. Not vacuous.
- GV13: If eject fails, `Grind_OrderGetPriceOpen(2101)` still returns old price? It asserts rc first. If rc fails, test continues and price assert may fail. Good.

Now, premise verdict: is branch safe to merge to main and deploy with every value inherited; and with asymmetric presets?
- With every value inherited: likely safe. Trading behavior same. Reporting adds new keys; legacy keys same. Need note DEINIT wrong values if inputs changed, but existing presets all -1? Actually "every value inherited" means all six new inputs -1, base set. Then g_geo_long = g_geo_short = base. DEINIT uses current values; if reinit with same preset, same values. No wrong. If preset changed between runs, DEINIT reporting wrong. But deploy with every value inherited on existing presets: safe.
- With asymmetric presets: Need ensure producers and checker agree. We think yes. But potential gap: OnTickEngine doesn't take exit_pips_short; relies on global recon set in OnInit. If asymmetric preset is set, OnInit sets `g_grind_recon_exit_pips_short = g_geo_exit_short`. OnTick passes g_geo_exit_short to eject/auto/lattice/carry. OnTradeTransaction passes g_geo_exit_short. All consistent. So safe. But there are untested paths (auto eject, service due flags, entry horizon, recenter). If those have a subtle missed short, deploy fails. We didn't find a concrete missed short. Need decide if any concrete bug makes asymmetric unsafe. The DEINIT reporting is not trading. The base validation requiring base even when all sides overridden is not trading if presets set base. The stale globals are safe. So premise: safe to merge for inherited; asymmetric likely safe but with untested paths and one reporting bug. Should we mark "safe with caveats" or "not safe"? The question: "is the branch safe to merge to main and to deploy with every value inherited; and with asymmetric presets?" We can say inherited: YES. Asymmetric: CONDITIONAL/NEEDS-FIX due untested paths? The instruction wants verdict. Maybe "Merge: safe for inherited, but do not deploy asymmetric until the DEINIT reporting and the untested paths are addressed." But if no concrete trading bug, maybe safe to merge but deploy asymmetric with caution.

Wait, let's re-examine T-4: base validation still required. If asymmetric preset sets base and overrides one side, okay. If a preset wants both sides different and sets base to one side, okay. The typical asymmetry is long=base, short=override. So base is set. Good.

Potential concrete bug: In `Grind_OnTickEngine`, the `exit_pips` parameter is unused, and it calls `Grind_RetryMissingExits` which uses `g_grind_recon_exit_pips_short`. But `g_grind_recon_exit_pips_short` is set in OnInit. If the EA is reattached with a changed short exit on a live book, it halts on I6 by design (ruled). So no.

Potential concrete bug: In `Grind_ReconCheckInvariants`, for short, it uses `exit_s = Grind_SidePips(false, exit_pips, exit_pips_short)`. But `Grind_SidePips` returns short_value only if `short_value > 0.0`. If a user sets `InpExitPipsShort = 0.0`? But `Grind_ResolveSideInput` rejects 0. So in production, exit_pips_short is either -1 (inherits) or >0. After resolution, g_geo_exit_short is either base (>0) or override (>0). So always >0. Good.

Potential concrete bug: In `Grind_OnTickEngine`, `width_s` and `add_s` are computed with `Grind_SidePips(false, width_pips, width_pips_short)`. If `width_pips_short` is 0.0 (default), returns width_pips. In production, OnTick passes g_geo_width_short which is >0. If all -1, g_geo_width_short = base. So returns base. Good.

Potential concrete bug: In `Grind_ServiceDueAddFlags`, the parameter is named `add_pips_short` but OnTickEngine passes `add_s` (already resolved). If OnTickEngine passed `add_s`, and `add_s` is the short value, then inside `Grind_SidePips(false, add_pips, add_pips_short)` returns add_s. Good. But if OnTickEngine passed `add_s` and `add_s` equals long when inherited, returns long. Good. However, if a caller calls ServiceDueAddFlags directly with `add_pips_short=0.0` and `add_pips` long, it inherits. Good. No bug.

Potential concrete bug: In `Grind_OnTradeTransactionEngine`, `g_grind_engine_add_pips_short = Grind_SidePips(false, add_pips, add_pips_short);` Then `Grind_HandleSideDealFill` for short computes `fill_add = Grind_SidePips(false, g_grind_engine_add_pips, g_grind_engine_add_pips_short);`. If `g_grind_engine_add_pips_short` is set to short, fine. But what if `g_grind_engine_add_pips` was set by OnTickEngine to a different long add than the current OnTradeTransaction's `add_pips`? OnTradeTransaction sets both before call. So fine.

Potential concrete bug: In `Grind_HandleSideDealFill`, for short, it uses `g_grind_engine_add_pips_short`. But if the fill is for short and `g_grind_engine_add_pips_short` is 0.0 because OnTradeTransactionEngine didn't set it? It sets it. Good.

Potential concrete bug: In `Grind_OnTickEngine`, it sets `g_grind_engine_add_pips_short = add_s;` but if `add_pips_short` is 0.0, add_s = add_pips. So global short becomes long. Then if an OnTradeTransaction for a short fill arrives, it sets it again to correct. Good.

Potential concrete bug: In `Grind_CarryExitPassStep`, it computes `shift_exit = Grind_SidePips(g_grind_carry_exit_work_long[idx], exit_pips, exit_pips_short);` and passes to `Grind_CarryExitShiftLayer` as `exit_pips`. But `Grind_CarryExitShiftLayer` uses `formula_exit` from `Grind_CarryWorkBase(idx, exit_pips, point, exit_pips_short)`. Wait look at the call:
```
if(Grind_CarryExitShiftLayer(g_grind_carry_exit_work_pos[idx],
                                   current_exit,
                                   g_grind_carry_exit_work_entry[idx],
                                   Grind_CarryWorkBase(idx, exit_pips,
                                                       SymbolInfoDouble(symbol, SYMBOL_POINT),
                                                       exit_pips_short),
                                   g_grind_carry_exit_work_long[idx],
                                   g_grind_carry_exit_work_layer[idx],
                                   magic, symbol, shift_exit,
                                   clamped, sign_skip, retcode))
```
It passes `Grind_CarryWorkBase(... exit_pips, exit_pips_short)` as `formula_exit`. WorkBase computes side_exit based on `dir > 0`. So formula_exit is correct. The `shift_exit` is passed as `exit_pips` but unused. So no bug.

Potential concrete bug: In `Grind_CarryExitPassBegin`, for short, it computes `short_exit` inside the loop. But it uses `Grind_EjectOffsetGet(layer.position_ticket)` for formula. Good. It does not include accrued. WorkBase also does not include accrued? Wait WorkBase:
```
return Grind_ExitPrice(Grind_EffectiveEntry(...), side_exit, point, dir)
          + Grind_EjectOffsetGet(...);
```
It does NOT include accrued! But earlier I thought it included accrued? Let's re-read WorkBase:
```
double Grind_CarryWorkBase(const int idx, const double exit_pips, const double point,
                           const double exit_pips_short = 0.0)
{
   const int dir = g_grind_carry_exit_work_long[idx] ? 1 : -1;
   const double side_exit = Grind_SidePips(dir > 0, exit_pips, exit_pips_short);
   return Grind_ExitPrice(Grind_EffectiveEntry(g_grind_carry_exit_work_entry[idx],
                                               g_grind_carry_exit_work_pos[idx]),
                          side_exit, point, dir)
          + Grind_EjectOffsetGet(g_grind_carry_exit_work_pos[idx]);
}
```
No accrued. But `Grind_CarryExitPassBegin` also computes formula without accrued:
```
const double formula = Grind_ExitPrice(... exit_pips ...) + Grind_EjectOffsetGet(...);
```
So WorkBase matches. In `Grind_CarryExitShiftLayer`, it computes `theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction, accrued_pips, pip_size);` where `accrued_pips = ledger_pips + pending_pips`. So it applies accrued. Good. I6 expected includes `accrued` from `Grind_CarryAccruedGet`. The carry pass sets `Grind_CarryAccruedSet(position_ticket, accrued_price)` where `accrued_price = theoretical - formula_exit`. So accrued_price = -direction * accrued_pips * pip_size. Then I6 expected = ExitPrice(eff, exit_pips)+accrued_price+eject_offset+shift. Since formula_exit = ExitPrice(eff, exit_pips)+eject_offset, expected = formula_exit + accrued_price + shift. And new_exit = theoretical + (new_exit - theoretical) = formula_exit + accrued_price + shift. Good. So WorkBase no accrued is correct.

Now, potential concrete bug: In `Grind_CarryExitPassBegin`, for long, it uses `exit_pips` directly. For short, it uses `short_exit`. But it does not pass `exit_pips_short` to `Grind_CarryWorkBase`? It does via `Grind_CarryExitPassStep`. Good.

Potential concrete bug: In `Grind_CarryExitPassBegin`, the short loop computes `short_exit` inside the loop, but if there are no short layers, no effect. Good.

Potential concrete bug: In `Grind_CarryExitPassBegin`, the long loop uses `exit_pips` but if `exit_pips` is actually the long_or_both and short override exists, long is correct. Good.

Now, maybe there is a bug in `Grind_ReconCheckInvariants`: It computes `exit_s` at top. For long, it uses `exit_pips`. For short, `exit_s`. Good. But in the I6 failure detail for short, it calls `Grind_InvariantDetailI6(short_layers[i], false, exit_s, point, short_shift)`. Good. For long, `exit_pips`. Good.

Potential concrete bug: In `Grind_ReconFailureOffendingForReason`, it checks `reason == "I6_SHORT_EXIT"` but not `"I6_SHORT_EXIT_FILL_ADVERSE"`. So if a short exit filled adverse, offending_comment_out remains empty. That's a reporting bug unrelated to per-side. Could mention? The task is v2.0. Not necessary.

Now, maybe there is a lookahead issue in `Grind_LatticeTrackOneSide`: It uses `Grind_CarryPositionOpenTime(pos, magic, ot)` and sets `g_grind_vl_from_msc_long = MathMax((long)(newest + 1) * 1000, ...);` Then it copies ticks from that time to current. It folds extreme over all past ticks. This is not lookahead. But it uses `Grind_MarketAsk()` live in `Grind_LatticeFoldExtreme` and folds it. Then `Grind_LatticeTrySide` uses `probe = extreme >0 ? MathMin(mkt, extreme) : mkt;` For long, it checks if the lowest ask over the tracking window crossed the level. If the market is now above the level but was below in the past, it will roll. This is a catch-up, not lookahead. However, it could be considered using future information if `CopyTicksRange` includes ticks after `now`? It passes `Grind_MarketTimeMsc()` as to. `Grind_MarketTimeMsc()` returns current time. So no future. Good.

Potential statistical flaw: `Grind_AutoEjectStable` uses `Grind_ExtremeIndexMostRecent` on `vals` array which is rates from CopyRates with index 0 current bar? It uses `times[i] = rates[i].time + 60;` and `now`. It checks `(now - times[idx]) >= window_sec`. If the extreme occurred in the current forming bar, `times[idx]` is bar open + 60, which may be > now, so `now - times[idx]` negative, fails. So it requires extreme to be at least W seconds old. Good. Not v2.

Now, we need produce final answer with sections. No preamble. Need include quotes. We can structure.

Need cite file, function, quote. Since files no line numbers, cite file and function and quote. Use backticks. Keep concise but exhaustive.

Let's plan sections.

GIVENS CHECK:
G1 VERIFIED. Quote `Grind_SidePips` body.
G2 VERIFIED. Quote default params. Maybe say every new param in listed signatures defaults `= 0.0`: e.g., `const double exit_pips_short = 0.0` in `Grind_EjectPollCommand`; `const double width_pips_short = 0.0, const double add_pips_short = 0.0` in `Grind_OnTickEngine`; etc. Could list a few and say same pattern in all thirteen. Need maybe quote all? We can quote representative and state checked all. To be safe, list each function with quote of default. But final length desired oververbosity 5, but user wants exhaustive. We can include a table.

G3 VERIFIED. Quote `Grind_ResolveSideInput` first branch.

G4 VERIFIED. Quote signatures of inner functions. Need quote each? Maybe one sentence: all listed inner functions still take single `exit_pips`/`add_pips` and no `_short` parameter. Quote e.g. `double Grind_ExitPrice(const double entry, const double exit_pips, const double point, const int direction)` and `bool Grind_SendNextAddEnt(... const double add_pips, ...)` etc. Since G4 lists many, we can quote a few and say the others match. But user wants verify each given. We can list each with a short quote. That's long but okay.

G5 VERIFIED. Quote fxgrind calls in OnTick, OnTimer, OnTradeTransaction. Note OnInit `Grind_RetryMissingExits` has no side params and uses globals set just above. Quote.

T-1: HOLDS. Evidence: follow callers. We can summarize each path with quotes. Need cite. Maybe list:
- `Grind_OnTickEngine` computes `const double width_s = Grind_SidePips(false, width_pips, width_pips_short);` and uses `sell_target = Grind_StraddleSellPrice(mid, width_s, _Point);`, recenter `width_s`, `add_s`, EnsureAddNext short `add_s`.
- `Grind_ServiceDueAddFlags` `const double add_s = Grind_SidePips(false, add_pips, add_pips_short);` and uses `add_s` for short.
- `Grind_OnTradeTransactionEngine` `const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);` and passes to short.
- `Grind_LatticeOnTick` `const double exit_s = ...; const double add_s = ...;` and passes to `Grind_LatticeTrySide`.
- `Grind_AutoEjectOnTick` `const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);` passes to short.
- `Grind_EjectPollCommand` `const double side_exit = Grind_SidePips(is_long, exit_pips, exit_pips_short);` passes.
- `Grind_RetryMissingExits` `const double exit_s = Grind_SidePips(false, g_grind_recon_exit_pips, g_grind_recon_exit_pips_short);` passes.
- `Grind_CarryExitPassBegin` short loop uses `short_exit`.
- `Grind_CarryWorkBase` uses `Grind_SidePips(dir > 0, exit_pips, exit_pips_short)`.
- `Grind_CarryExitPassStep` passes `exit_pips_short` to WorkBase.
- `Grind_ReconCheckInvariants` `const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);`.
- `Grind_RebuildBookFromTicketsInner` `const double exit_s = ...;` and uses for short fallback.
- `Grind_HandleSideDealFill` short add uses `Grind_SidePips(false, g_grind_engine_add_pips, g_grind_engine_add_pips_short)`.
- `Grind_ApplyEntryHorizon`/`Grind_EnsureAddNext`/`Grind_SendNextAddEnt` take `add_pips` from side-specific callers.

Note dead/unused: `Grind_OnTickEngine` `exit_pips` parameter is unused; `Grind_CarryExitShiftLayer` `exit_pips` parameter is unused. No wrong pricing because the actual value comes from side-specific globals/formula. Could mention as no missed site but code smell.

T-2: HOLDS. Explain producers/checker use same globals/passed values. Potential pair that could differ: if `Grind_OnTickEngine` were called with an `exit_pips_short` distinct from `g_grind_recon_exit_pips_short`; it has no such parameter and `Grind_RetryMissingExits` reads the global, so the checker and retry producer agree with the global, not with the call site. In production OnTick passes the same `g_geo_exit_short` to both. Quote `OnTick` and `OnInit`. Also note `Grind_CheckBookInvariants` uses `g_grind_recon_exit_pips_short`; `OnInit` sets it from `g_geo_exit_short`. No disagreement when inputs consistent.

T-3: HOLDS with caveat. `g_grind_recon_exit_pips_short` set in OnInit before ReconstructState/Retry. Quote. `g_grind_engine_add_pips_short` set in OnTradeTransactionEngine immediately before HandleSideDealFill, and in OnTickEngine. If a reader saw 0.0, `Grind_SidePips(false, x, 0.0)` returns x (inherits long), not a wrong short override. Tests reset to 0.0 in `GV_RestoreEngineGlobals`. Quote. No production path reads before set. Caveat: direct unit calls to `Grind_HandleSideDealFill` without OnTradeTransactionEngine would use whatever global is present.

T-4: NEEDS-FIX? Let's decide. The main issue: base validation unconditional. Is it a threat? The threat asks sentinel and validation. We can mark HOLDS for sentinel, but NEEDS-FIX for base validation if all six overridden. But is that a critical flaw? It means an asymmetric preset with base=-1 and all six overrides positive fails at init. The prompt says "six inputs ... exactly -1 inherits the base input, >0 overrides". It implies base can be -1 if no side inherits. But code requires base >0. If a user sets all six overrides and leaves base=-1 (the default), OnInit fails. That's a real usability/validation bug. But is it intended? The ruled says "one EA with inherit-by-default overrides rather than a new file". It might be intended that base is always set. However, the branch description says "Before it, one InpWidthPips... Now six inputs... exactly -1 inherits the base input, >0 overrides". If all six are >0, base is irrelevant. Requiring base >0 is an unnecessary fatal. This could cause silent failure on a valid config. I'd mark T-4 BREAKS/NEEDS-FIX with this. But wait, in OnInit, the base validation uses `InpWidthPips`, etc. If user sets all six overrides, they likely also set base because it's an existing preset. But a new preset could omit base. The threat specifically: "Inputs. Sentinel and validation: MT5's parsing of -1.0 in a .set file (can it arrive as -0.99999...?), 0 or negative overrides, the order of checks in OnInit, and whether any order can be placed before validation fails." It doesn't ask about base omitted. But we can mention as additional. The verdict for T-4 could be HOLDS for sentinel/validation, with a NEEDS-FIX note: base inputs are still required even when every side overrides. But if I mark BREAKS, need be sure. The prompt says "anything else is FATAL" for the six inputs. It doesn't say base can be -1 when all overrides. The base inputs themselves are still inputs; they default -1. If all six are overrides, base is not used. But code still validates base. That means the sentinel contract is incomplete: -1 on base is not allowed even if unused. I'd call it NEEDS-FIX. Let's phrase: "Sentinel parsing is tolerant (1e-9); 0/negative overrides fatal; no order before failure. But the base geometry checks are unconditional, so an all-overrides preset with base=-1 dies before reaching the per-side checks. If that preset shape is allowed, this is a fatal validation bug." That covers.

Also MT5 parsing: ASSUMED exact for "-1.0"; tolerance 1e-9. If .set writes -0.99999, fatal. Good.

T-5: HOLDS. Quote `Grind_SidePips` with short=0 returns long. In symmetric resolved values, short==long. Reporting: legacy keys long; new keys same. No trading path differs. Note JSON has additional keys by design, so not byte-identical.

T-6: NEEDS-FIX for DEINIT geometry wrong values. Also maybe unverifiable INIT/DEINIT schema. Let's detail:
- Heartbeat: count/order verified. Quote format and args? We can say format has 22 specifiers and 22 args, ending `exit_pips_short\":%.4f}` and args `g_geo_exit_long, g_geo_exit_short);`. Good.
- INIT/DEINIT: In `OnInit`, legacy fields get long values; `Grind_ArchiveGeometryFields` gets six. But DEINIT event is constructed in the *next* OnInit with the *new* `g_geo_*` values:
```
const string deinit_fields = Grind_ArchiveConfigFields(
         "DEINIT", prev_reason, _Symbol, InpSlot, GRIND_EA_BUILD,
         (long)AccountInfoInteger(ACCOUNT_LOGIN),
         g_geo_width_long, g_geo_add_long, g_geo_exit_long, ...
```
This reports the new resolved geometry with the previous run's reason. If inputs changed, DEINIT values are wrong. Smallest fix: record resolved geometry in `Grind_ArchiveRecordDeinit` and use it when building `deinit_fields`, or enqueue the DEINIT config event in `OnDeinit` while old globals are alive.
- Schema: `Grind_ArchiveGeometryFields` not in attached code, so key names/commas not verifiable; ASSUMED it returns comma-separated fields without outer braces. Quote call.

T-7: TEST GAPS. List missing tests and vacuous notes. Need mention GV10 stray L0 does not weaken add-value assertion but adds side effect. Also mention no test for DEINIT. Also no test for AutoEjectOnTick short, ServiceDueAddFlags short, ApplyEntryHorizon short, OnTimerStep short passthrough, recenter short width, CheckBookInvariants/ReconstructState actual broker seam (ruled). Also maybe no test for base=-1 all overrides fatal. Also no test for MT5 .set parsing. Also no test for `g_grind_engine_add_pips_short` stale before first OnTick (though safe).

PREMISE VERDICT:
- Merge to main: likely safe for inherited values; for asymmetric, trading logic appears wired, but untested paths and the DEINIT reporting bug mean I would not call it fully safe until fixes. Say: "Safe to merge for inherited presets. Do not deploy asymmetric presets until (a) DEINIT geometry fix and (b) at least smoke tests for AutoEjectOnTick/ServiceDueAddFlags/ApplyEntryHorizon/recenter short wiring are added; no concrete wrong-price path found in code review, but coverage is insufficient." Or if we found base validation bug, asymmetric all-overrides with base=-1 fails. So "asymmetric presets that keep a valid base and override one side: safe by inspection; all-overrides with base=-1: fails init."

Need include file names. Use `fxgrind.mq5`, `grind_engine.mqh`, etc.

Let's ensure we quote exactly. Quotes from provided code.

For G2, maybe list all thirteen with default param quote. Let's prepare concise:
- `Grind_OnTickEngine`: `const double width_pips_short = 0.0,` and `const double add_pips_short = 0.0`
- `Grind_ServiceDueAddFlags`: `const double add_pips_short = 0.0`
- `Grind_OnTradeTransactionEngine`: `const double exit_pips_short = 0.0,` `const double add_pips_short = 0.0`
- `Grind_LatticeOnTick`: `const double exit_pips_short = 0.0,` `const double add_pips_short = 0.0`
- `Grind_AutoEjectOnTick`: `const double exit_pips_short = 0.0`
- `Grind_EjectPollCommand`: `const double exit_pips_short = 0.0`
- `Grind_ReconCheckInvariants`: `const bool tolerate_exit_shortfall = false, const double exit_pips_short = 0.0`
- `Grind_RebuildBookFromTicketsInner`: same
- `Grind_RebuildBookFromTickets`: same
- `Grind_CarryExitPassBegin`: `const double exit_pips_short = 0.0`
- `Grind_CarryWorkBase`: `const double exit_pips_short = 0.0`
- `Grind_CarryOnTimerStep`: `const double exit_pips_short = 0.0`
- `Grind_CarryExitPassStep`: `const double exit_pips_short = 0.0`
Also `Grind_AutoEjectTrySide` no short param (called with side-specific), not in thirteen? Actually prompt thirteen includes AutoEjectOnTick not TrySide. Good.

For G4, quote each inner function signature. We can abbreviate:
- `double Grind_ExitPrice(const double entry, const double exit_pips, const double point, const int direction)`
- `double Grind_AddTargetPrice(const double anchor_entry, const double add_pips, const double point, const int direction)`
- `double Grind_ExitQFormulaTarget(const double entry, const double exit_pips, const double point, const bool is_long, const ulong position_ticket)`
- `double Grind_ComputeAddTarget(const GrindSideState &side, const bool is_long, const double add_pips)`
- `bool Grind_SendNextAddEnt(... const double add_pips, ...)`
- `void Grind_EnsureAddNext(... const double add_pips, ...)`
- `int Grind_LatticeTrySide(... const double exit_pips, const double add_pips, ...)`
- `int Grind_LatticeRollLayer(... const double exit_pips, ...)`
- `void Grind_ExitQManageSide(... const double exit_pips)`
- `int Grind_EjectAcceptLayer(... const double exit_pips, ...)`
All no `_short`.

For G5, quote OnTick calls:
```
Grind_EjectPollCommand(InpMagic, InpEnableCommandedEject, g_geo_exit_long,
                          g_grind_halted || g_grind_quarantined, g_geo_exit_short);
...
Grind_OnTickEngine(... g_geo_width_long, g_geo_exit_long, g_geo_add_long, ... g_geo_width_short, g_geo_add_short);
```
OnTimer:
```
Grind_CarryOnTimerStep(_Symbol, InpMagic, g_geo_exit_long, InpEnableCarryPass, carry_now,
                             g_geo_exit_short);
```
OnTradeTransaction:
```
Grind_OnTradeTransactionEngine(trans, InpMagic, InpSlot, g_geo_exit_long, g_geo_add_long, ..., g_geo_exit_short, g_geo_add_short);
```
OnInit sets globals:
```
g_grind_recon_exit_pips = g_geo_exit_long;
g_grind_recon_exit_pips_short = g_geo_exit_short;
```
And calls `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);` which uses globals. Good.

Now, maybe T-1 mentions `Grind_TryPlaceAddAtFill` and `Grind_ApplyEntryHorizon`. We can quote fill_add:
```
const double fill_add = is_long
                              ? g_grind_engine_add_pips
                              : Grind_SidePips(false, g_grind_engine_add_pips,
                                               g_grind_engine_add_pips_short);
```
Good.

Now, final answer should be in required order. No preamble. We can start with `GIVENS CHECK`.

Need ensure no unsupported claims. Use "ASSUMED" where needed.

Let's also mention lookahead? The prompt says hunting lookahead. We can in PREMISE or TEST GAPS note no lookahead found in v2 pricing; all readers use current/past ticks. But not necessary. Maybe add a sentence in T-2 or premise.

Potential issue: In `Grind_LatticeFoldExtreme`, it uses `Grind_MarketAsk()` live and folds into extreme. That's current, not future. Good.

Potential issue: `Grind_AutoEjectOnTick` uses `CopyRates(_Symbol, PERIOD_M1, 0, bar_count, rates);` includes current incomplete bar. It uses `rates[0].time + 60` and checks window intact. It may consider the current bar's low/high as completed? It uses `rates[i].low` for i=0 (current bar) in `vals_long`. But `Grind_AutoEjectStable` requires the extreme be at least `stable_minutes*60` old. Since `times[0] = rates[0].time + 60` (bar close time), `now - times[0]` is negative until bar closes, so current bar extreme cannot satisfy stability. So no lookahead. Good.

Potential issue: `Grind_LatticeTrackOneSide` uses `Grind_LatticeCopyTicks` with `from_msc` to `Grind_MarketTimeMsc()`. `Grind_MarketTimeMsc()` uses `g_grind_market_test_time_msc` in tests, but in production uses symbol time. It could be stale? Not v2.

Now, write final. Need be concise but thorough. Desired oververbosity 5, but user wants exhaustive. We'll produce maybe 3000-4000 words? The line count of prompt 142, but answer can be longer. We need include many quotes. Let's aim organized.

Let's draft.

---

GIVENS CHECK

G1 VERIFIED. Quote.

G2 VERIFIED. Quote all defaults. To save space, use semicolon list. Each quote from signature.

G3 VERIFIED. Quote.

G4 VERIFIED. Quote list.

G5 VERIFIED. Quote calls. Note OnInit path.

T-1 HOLDS. Evidence bullets.

T-2 HOLDS. Evidence.

T-3 HOLDS (with caveat).

T-4 NEEDS-FIX. Sentinel tolerant; base validation issue.

T-5 HOLDS. Evidence.

T-6 NEEDS-FIX. Heartbeat ok; DEINIT wrong values; schema unverifiable.

T-7 TEST GAPS. List.

PREMISE VERDICT.

TEST GAPS.

Maybe combine T-7 and TEST GAPS? The OUTPUT wants `T-1`...`T-7` and `PREMISE VERDICT`, `TEST GAPS`. So T-7 can be verdict on tests, and TEST GAPS section separately. We'll do T-7 verdict then TEST GAPS detailed.

Need ensure T-7 addresses "Does that setup weaken the test?" Yes.

Let's write.

For T-4, quote:
```
if(!Grind_ValidateGeometryInputs(InpWidthPips, InpExitPips,
                                    InpMaxLayers, InpStrandedThreshPips,
                                    InpAddPips)) {
      Print("FATAL: geometry not configured — width/add/exit/max_layers/stranded must be > 0");
      return INIT_FAILED;
   }
```
This runs after resolving sides. If all six overrides >0 but base -1, fails. Smallest fix: validate base only if any side inherits, or use long/short resolved values for the base check when both sides override.

Also quote sentinel:
```
if(MathAbs(override_value + 1.0) <= 1e-9) {
      out_value = base_value;
      return true;
   }
```
and
```
if(override_value > 0.0) {
      out_value = override_value;
      return true;
   }
```
and final `return false`.

For T-6, quote DEINIT construction. Also quote heartbeat ending. For schema, say ASSUMED.

Now, final.

## Final Report

## GIVENS CHECK

**G1 — VERIFIED.** `grind_pure.mqh`, `Grind_SidePips`:
```cpp
return (!is_long && short_value > 0.0) ? short_value : long_or_both;
```
Short value is returned only when `!is_long` and `short_value > 0.0`.

**G2 — VERIFIED.** Every new short-side parameter in the listed dispatch functions defaults to `0.0`. Examples:
- `Grind_EjectPollCommand`: `const double exit_pips_short = 0.0`
- `Grind_AutoEjectOnTick`: `const double exit_pips_short = 0.0`
- `Grind_LatticeOnTick`: `const double exit_pips_short = 0.0,` / `const double add_pips_short = 0.0`
- `Grind_OnTickEngine`: `const double width_pips_short = 0.0,` / `const double add_pips_short = 0.0`
- `Grind_ServiceDueAddFlags`: `const double add_pips_short = 0.0`
- `Grind_OnTradeTransactionEngine`: `const double exit_pips_short = 0.0,` / `const double add_pips_short = 0.0`
- `Grind_ReconCheckInvariants`: `const bool tolerate_exit_shortfall = false,` then `const double exit_pips_short = 0.0`
- `Grind_RebuildBookFromTicketsInner`: same pattern
- `Grind_RebuildBookFromTickets`: same pattern
- `Grind_CarryExitPassBegin`: `const double exit_pips_short = 0.0`
- `Grind_CarryWorkBase`: `const double exit_pips_short = 0.0`
- `Grind_CarryOnTimerStep`: `const double exit_pips_short = 0.0`
- `Grind_CarryExitPassStep`: `const double exit_pips_short = 0.0`

Therefore legacy callers and tests with omitted new arguments resolve short to the old single value.

**G3 — VERIFIED.** `grind_pure.mqh`, `Grind_ResolveSideInput`:
```cpp
if(MathAbs(override_value + 1.0) <= 1e-9) {
      out_value = base_value;
      return true;
   }
```
With all six inputs at `-1`, every resolved side value equals its base input.

**G4 — VERIFIED.** The listed inner pricing functions still take one value and have no `_short` parameter. Representative signatures:
- `double Grind_ExitPrice(const double entry, const double exit_pips, const double point, const int direction)`
- `double Grind_AddTargetPrice(const double anchor_entry, const double add_pips, const double point, const int direction)`
- `double Grind_ExitQFormulaTarget(const double entry, const double exit_pips, const double point, const bool is_long, const ulong position_ticket)`
- `double Grind_ComputeAddTarget(const GrindSideState &side, const bool is_long, const double add_pips)`
- `bool Grind_SendNextAddEnt(... const double add_pips, ...)`
- `void Grind_EnsureAddNext(... const double add_pips, ...)`
- `int Grind_LatticeTrySide(... const double exit_pips, const double add_pips, ...)`
- `int Grind_LatticeRollLayer(... const double exit_pips, ...)`
- `void Grind_ExitQManageSide(... const double exit_pips)`
- `int Grind_EjectAcceptLayer(... const double exit_pips, ...)`

**G5 — VERIFIED with one scope note.** `fxgrind.mq5` passes long values in the old slots and short values in the new parameters at the engine dispatch sites that carry them:
- `OnTick`: `Grind_EjectPollCommand(InpMagic, InpEnableCommandedEject, g_geo_exit_long, ..., g_geo_exit_short);`
- `OnTick`: `Grind_AutoEjectOnTick(..., g_geo_exit_long, ..., g_geo_exit_short);`
- `OnTick`: `Grind_LatticeOnTick(..., g_geo_exit_long, g_geo_add_long, ..., g_geo_exit_short, g_geo_add_short);`
- `OnTick`: `Grind_OnTickEngine(..., g_geo_width_long, g_geo_exit_long, g_geo_add_long, ..., g_geo_width_short, g_geo_add_short);`
- `OnTimer`: `Grind_CarryOnTimerStep(_Symbol, InpMagic, g_geo_exit_long, InpEnableCarryPass, carry_now, g_geo_exit_short);`
- `OnTradeTransaction`: `Grind_OnTradeTransactionEngine(..., g_geo_exit_long, g_geo_add_long, ..., g_geo_exit_short, g_geo_add_short);`

`OnInit` does not call those dispatchers directly; it sets the recon globals:
```cpp
g_grind_recon_exit_pips = g_geo_exit_long;
g_grind_recon_exit_pips_short = g_geo_exit_short;
```
and then calls `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots)`, which reads those globals. That is consistent.

## T-1 — A missed site

**Verdict: HOLDS.**

I followed the listed callers. The short side is re-priced at each dispatch boundary:

- `Grind_OnTickEngine` resolves short width/add:
```cpp
const double width_s = Grind_SidePips(false, width_pips, width_pips_short);
const double add_s = Grind_SidePips(false, add_pips, add_pips_short);
```
and uses `width_s` for the short L0 and recenter:
```cpp
double sell_target = Grind_StraddleSellPrice(mid, width_s, _Point);
...
Grind_TryRecenterOppositeL0(g_grind_short, false, mid, magic, slot,
                                  width_s, stranded_thresh_pips, deadband_pips);
...
Grind_EnsureAddNext(g_grind_short, false, magic, slot, add_s, deadband_pips, max_layers, lots);
```

- `Grind_ServiceDueAddFlags` resolves short add:
```cpp
const double add_s = Grind_SidePips(false, add_pips, add_pips_short);
...
Grind_EnsureAddNext(g_grind_short, false, magic, slot, add_s, deadband_pips, ...);
Grind_SendNextAddEnt(g_grind_short, false, magic, slot, add_s, ...);
```

- `Grind_OnTradeTransactionEngine` resolves short exit and sets the short add global:
```cpp
g_grind_engine_add_pips_short = Grind_SidePips(false, add_pips, add_pips_short);
const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);
...
Grind_HandleSideDealFill(g_grind_short, false, trans.deal, magic, slot,
                            exit_s, deadband_pips, max_layers, lots);
```

- `Grind_HandleSideDealFill` uses the resolved short add for the fill-time add:
```cpp
const double fill_add = is_long
                              ? g_grind_engine_add_pips
                              : Grind_SidePips(false, g_grind_engine_add_pips,
                                               g_grind_engine_add_pips_short);
Grind_TryPlaceAddAtFill(side, is_long, magic, slot, fill_add, ...);
```

- `Grind_LatticeOnTick` resolves both short exit and short add before calling `Grind_LatticeTrySide`:
```cpp
const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);
const double add_s = Grind_SidePips(false, add_pips, add_pips_short);
Grind_LatticeTrySide(g_grind_short, false, magic, slot, lots, exit_s, add_s, ...);
```

- `Grind_AutoEjectOnTick` resolves short exit:
```cpp
const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);
Grind_AutoEjectTrySide(false, magic, exit_s, max_layers, ...);
```

- `Grind_EjectPollCommand` resolves short exit:
```cpp
const double side_exit = Grind_SidePips(is_long, exit_pips, exit_pips_short);
return Grind_EjectAcceptLayer(is_long, idx, magic, side_exit, "command");
```

- `Grind_RetryMissingExits` resolves short recon exit:
```cpp
const double exit_s = Grind_SidePips(false, g_grind_recon_exit_pips,
                                        g_grind_recon_exit_pips_short);
...
Grind_ExitQManageSide(g_grind_short, false, magic, slot, lots, exit_s);
```

- `Grind_CarryExitPassBegin` uses short exit inside the short loop:
```cpp
const double short_exit = Grind_SidePips(false, exit_pips, exit_pips_short);
const double formula = Grind_ExitPrice(..., short_exit, point, -1) + Grind_EjectOffsetGet(...);
```

- `Grind_CarryWorkBase` resolves per work-item side:
```cpp
const double side_exit = Grind_SidePips(dir > 0, exit_pips, exit_pips_short);
```

- `Grind_ReconCheckInvariants` resolves short exit:
```cpp
const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);
```

- `Grind_RebuildBookFromTicketsInner` resolves short exit and uses it for the short fallback target:
```cpp
const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);
...
Grind_ExitQFormulaTarget(short_scratch[j].entry_price, exit_s, point, false, ...);
```

Two dead-parameter observations, not wrong-price breaks:
- `Grind_OnTickEngine` accepts `exit_pips` but never reads it; retry pricing comes from `g_grind_recon_exit_pips_short`.
- `Grind_CarryExitShiftLayer` accepts `exit_pips` but the actual formula comes from `Grind_CarryWorkBase(... exit_pips, ..., exit_pips_short)`.

No path found that prices a short-side order with the long/base value in production wiring.

## T-2 — Producer and checker agree

**Verdict: HOLDS, with one operational condition.**

All short-side producers and the I6 checker read the same short exit source, provided the inputs are unchanged after init.

- Init sets the checker’s short exit:
```cpp
g_grind_recon_exit_pips = g_geo_exit_long;
g_grind_recon_exit_pips_short = g_geo_exit_short;
```
`Grind_CheckBookInvariants` passes that global into the checker:
```cpp
g_grind_recon_exit_pips,
g_grind_recon_max_layers,
_Point,
long_tmp, short_tmp, reason,
false,
g_grind_recon_exit_pips_short);
```
`Grind_ReconstructState` does the same with `true` for `tolerate_exit_shortfall`.

- Fill producer: `Grind_OnTradeTransactionEngine` computes `exit_s` and passes it to `Grind_HandleSideDealFill`, which appends the layer with `Grind_AppendLayer(side, deal_price, position_id, c_layer, exit_pips, is_long);`.

- Queue/retry producer: `Grind_RetryMissingExits` uses `g_grind_recon_exit_pips_short`, the same global the checker uses.

- Lattice producer: `Grind_LatticeOnTick` passes `g_geo_exit_short` into `Grind_LatticeTrySide`; `OnTick` and `OnInit` both use `g_geo_exit_short`.

- Carry producer: `OnTimer` passes `g_geo_exit_short` into `Grind_CarryOnTimerStep`, which passes it to `Grind_CarryExitPassStep` and then `Grind_CarryWorkBase`.

- Eject producer: `OnTick` passes `g_geo_exit_short` into `Grind_EjectPollCommand` and `Grind_AutoEjectOnTick`.

The only disagreement path is if someone calls `Grind_OnTickEngine` with a short exit different from `g_grind_recon_exit_pips_short`. `Grind_OnTickEngine` has no `exit_pips_short` parameter, and its retry path reads the global. In production `OnTick` and `OnInit` are sourced from the same `g_geo_exit_short`, so no halt. In an external caller/test with mismatched globals, retry and I6 would agree with the stale global, not with the call-site intent.

## T-3 — Stale globals

**Verdict: HOLDS for production, with a test-harness caveat.**

`g_grind_recon_exit_pips_short` is set in `OnInit` before any book reconstruction or retry:
```cpp
g_grind_recon_exit_pips_short = g_geo_exit_short;
...
if(!Grind_ReconstructState()) { ... } else { ... Grind_RetryMissingExits(InpMagic, InpSlot, InpLots); }
```
`Grind_CheckBookInvariants` and `Grind_ReconstructState` both read it. No production path reads it before `OnInit` sets it.

`g_grind_engine_add_pips_short` is set immediately before the fill handler in `Grind_OnTradeTransactionEngine`:
```cpp
g_grind_engine_add_pips_short = Grind_SidePips(false, add_pips, add_pips_short);
const double exit_s = Grind_SidePips(false, exit_pips, exit_pips_short);
Grind_HandleSideDealFill(g_grind_long, true, ...);
Grind_HandleSideDealFill(g_grind_short, false, ..., exit_s, ...);
```
It is also refreshed every `OnTickEngine`:
```cpp
g_grind_engine_add_pips_short = add_s;
```
If some reader ever saw `0.0`, `Grind_SidePips(false, x, 0.0)` returns `x` — i.e. it falls back to the long/base value, not a bogus short override. That is fail-safe for symmetric presets.

Test caveat: `GV_RestoreEngineGlobals` clears both short globals:
```cpp
g_grind_engine_add_pips_short = 0.0;
g_grind_recon_exit_pips_short = 0.0;
```
So a test that directly calls `Grind_HandleSideDealFill` or `Grind_RetryMissingExits` without first setting the short global will see inherited long behavior. The GV tests that matter set the short globals or pass the short parameters through the dispatchers.

## T-4 — Inputs

**Verdict: NEEDS-FIX for the unconditional base validation; sentinel handling itself is correct.**

Sentinel: `Grind_ResolveSideInput` treats `-1` within `1e-9` as inherit:
```cpp
if(MathAbs(override_value + 1.0) <= 1e-9) {
      out_value = base_value;
      return true;
   }
```
`0.0`, `-0.5`, `-2.0` are rejected:
```cpp
if(override_value > 0.0) {
      out_value = override_value;
      return true;
   }
   out_value = 0.0;
   return false;
```
`OnInit` resolves all six side inputs before any geometry checks or order-capable setup. If any is invalid, it returns `INIT_FAILED` before timer creation, before `Grind_MagicLockClaim`, and before any order can be placed.

MT5 parsing: ASSUMED MT5 writes `-1.0` in a `.set` file as the exact double `-1.0`, which is exactly representable. If a writer/parser ever produced `-0.999999` or similar, that is outside the `1e-9` tolerance and becomes FATAL. That is arguably correct — the sentinel is documented as exactly `-1`.

The defect: base validation is unconditional even when every side is overridden. `OnInit` does:
```cpp
if(!Grind_ValidateGeometryInputs(InpWidthPips, InpExitPips,
                                    InpMaxLayers, InpStrandedThreshPips,
                                    InpAddPips)) {
      Print("FATAL: geometry not configured — width/add/exit/max_layers/stranded must be > 0");
      return INIT_FAILED;
   }
if(!Grind_ValidateAddWidthRatio(InpWidthPips, InpAddPips)) { ... }
```
after resolving `g_geo_*_long` and `g_geo_*_short`. Therefore a preset that sets all six side overrides but leaves the base inputs at their default `-1` dies in `OnInit` before the per-side checks, even though neither base value is used. Smallest fix: only run the base geometry/ratio checks if at least one resolved side inherited from that base, or validate the resolved long/short triples only.

No order can be placed before validation fails.

## T-5 — Same when symmetric

**Verdict: HOLDS for trading behavior; reporting is intentionally extended.**

With all six at `-1`, `OnInit` sets:
```cpp
g_geo_width_long  = InpWidthPips;
g_geo_width_short = InpWidthPips;
g_geo_add_long    = InpAddPips;
g_geo_add_short   = InpAddPips;
g_geo_exit_long   = InpExitPips;
g_geo_exit_short  = InpExitPips;
```
Then `Grind_SidePips(false, x, 0.0)` returns `x`:
```cpp
return (!is_long && short_value > 0.0) ? short_value : long_or_both;
```
and in production the passed short value equals the long value, so both the default-argument path and the resolved-short path return the same number. All short dispatch sites listed in T-1 resolve to the same value as the legacy single value.

Reporting: legacy `width_pips`/`add_pips`/`exit_pips` still carry the long values. The heartbeat gains six new keys with equal long/short values; INIT/DEINIT gain `Grind_ArchiveGeometryFields(...)`. That is an additional-fields change, not a behavioral trading change.

## T-6 — Reporting

**Verdict: NEEDS-FIX for DEINIT values; heartbeat count/order is correct; INIT/DEINIT schema is partly unverifiable from the attached code.**

Heartbeat `StringFormat` has 22 specifiers and 22 arguments in matching order. The new block ends:
```cpp
"\"width_pips_long\":%.4f,\"width_pips_short\":%.4f,"
"\"add_pips_long\":%.4f,\"add_pips_short\":%.4f,"
"\"exit_pips_long\":%.4f,\"exit_pips_short\":%.4f}",
...
g_geo_width_long,
g_geo_width_short,
g_geo_add_long,
g_geo_add_short,
g_geo_exit_long,
g_geo_exit_short);
```
The leading comma is present, and the base heartbeat’s trailing `}` is stripped first:
```cpp
if(len < 2 || StringGetCharacter(hb, len - 1) != '}')
      return hb;
   hb = StringSubstr(hb, 0, len - 1);
   hb += StringFormat(
      ",\"add_due_long\":%s,\"add_due_short\":%s,"
```
So the appended JSON is syntactically valid provided the base heartbeat is well-formed.

The DEINIT defect: the DEINIT event is constructed in the *next* `OnInit`, using the *new* resolved `g_geo_*` values:
```cpp
const string deinit_fields = Grind_ArchiveConfigFields(
         "DEINIT", prev_reason, _Symbol, InpSlot, GRIND_EA_BUILD,
         (long)AccountInfoInteger(ACCOUNT_LOGIN),
         g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,
         ...
         InpTelemetryInstance, InpVerboseLog, InpConfigWarning,
         EnableTelemetry, TelemetryIntervalSec, InpEnableCarryPass) +
         "," + Grind_ArchiveGeometryFields(g_geo_width_long, g_geo_add_long, g_geo_exit_long,
                                           g_geo_width_short, g_geo_add_short, g_geo_exit_short) +
         "," + Grind_ArchiveDeinitExtraFields(prev_time, InpMagic, prev_anchor);
```
If the operator changes inputs between runs, the DEINIT record for the previous run reports the new geometry, not the geometry the dead instance was actually running. Smallest fix: persist the resolved geometry in `Grind_ArchiveRecordDeinit` and use the persisted values when building `deinit_fields`, or enqueue the DEINIT config event directly in `OnDeinit` while the old `g_geo_*` values are still live.

INIT path itself passes long values in the legacy slots:
```cpp
g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,
```
and then appends the six-field geometry:
```cpp
Grind_ArchiveGeometryFields(g_geo_width_long, g_geo_add_long, g_geo_exit_long,
                            g_geo_width_short, g_geo_add_short, g_geo_exit_short);
```
Key names and comma correctness inside `Grind_ArchiveGeometryFields` cannot be verified because that function is not in the attached code. ASSUMED it returns comma-separated fields without an outer `{}`; otherwise the concatenation would produce invalid JSON.

## T-7 — Tests

**Verdict: TESTS ARE INSUFFICIENT for asymmetric deployment.**

The GV tests cover many v2.0 paths: `Grind_SidePips`, `Grind_ResolveSideInput`, retry exits, I6 per side, rebuild per side, short fill+exit+add, long control, short L0 width, short add-next, short lattice, short carry, short eject. But several v2.0 short-wiring paths have no failing GV test:

- `Grind_AutoEjectOnTick` short exit: GV13 tests `Grind_EjectPollCommand`, not `Grind_AutoEjectOnTick`. If `AutoEjectOnTick` dropped `exit_pips_short`, no GV test would fail.
- `Grind_ServiceDueAddFlags` short add: GV7/GV10 exercise fill-time and `OnTickEngine` add paths, not ADR-152 due flags.
- `Grind_ApplyEntryHorizon` short add: the GV tests keep entry horizon off (`Grind_EngineConfigureAdr152(true, 0)`), so the horizon path is untested per side.
- `Grind_CarryOnTimerStep` short passthrough: GV12 calls `Grind_CarryExitPassBegin`/`Step` directly; it does not verify `OnTimerStep` forwards `exit_pips_short`.
- `Grind_TryRecenterOppositeL0` short width: GV9 tests initial short L0 placement, not the opposite-L0 recenter path.
- `Grind_CheckBookInvariants` and `Grind_ReconstructState` against the real broker book: ruled deploy-only, but this remains the largest untested seam for asymmetric short exit wiring.
- `OnInit` all-overrides-with-base=-1: no test covers the T-4 unconditional base validation failure.

Vacuous/weak assertions:
- GV5 and GV7 guard array-size-dependent assertions with `ArraySize(...) == 1 ? ... : 0.0`; if the size check fails, the numeric assertion compares `0.0` to the expected price and fails. Not vacuous.
- GV10’s setup does not make the add-price assertion vacuous. It first runs two ticks on a flat book, so `g_grind_short.l0_pending_ticket` is set; then it seeds a short layer; the next tick hits `Grind_ReconcileStrayL0` and cancels the L0 as `STRAY_L0_CANCEL` before `Grind_EnsureAddNext` places the add. If short add wiring used long add, the expected `1.20060` would still fail. The setup adds a stray-cancel side effect, so it does not test short add placement on a clean book without a stray L0, but it does not weaken the short-add-value assertion.
- GV12 relies on `C55_AllRestingI6Short()` and `C55_AllAccruedShort()`, whose implementations are not in the attached file. Cannot verify whether those helpers are non-vacuous.

## PREMISE VERDICT

**Safe to merge to `main` for inherited presets:** yes, by inspection. With all six new inputs at `-1`, short resolution collapses to the old single values, the legacy JSON keys still carry long values, and the short dispatch paths use `Grind_SidePips(false, x, 0.0)`/resolved-short values that equal `x`. The only non-trading reporting caveat is the DEINIT geometry record using the next run’s inputs.

**Safe to deploy with every value inherited:** yes, subject to the T-4 base-validation caveat not being triggered — i.e. the preset still supplies a valid base `InpWidthPips`/`InpAddPips`/`InpExitPips`.

**Safe to deploy with asymmetric presets:** not yet fully evidenced. I did not find a concrete wrong-price path in the short-side wiring; producers and I6 checker agree when inputs are consistent. But `Grind_AutoEjectOnTick`, `Grind_ServiceDueAddFlags`, `Grind_ApplyEntryHorizon`, `Grind_CarryOnTimerStep`, and `Grind_TryRecenterOppositeL0` have no per-side short tests, and the DEINIT reporting bug is real. Smallest gate before asymmetric deployment: fix the DEINIT geometry source and add at least one asymmetric smoke test for each of those five untested dispatch paths.

<!-- finish_reason=stop -->
