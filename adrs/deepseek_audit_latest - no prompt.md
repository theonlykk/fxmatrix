# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit. Need inspect docs/code for lookahead bias, silent failures, schema mismatches, statistical flaws, FX algo infrastructure. Need be exhaustive. We have documentation EURGBP L0 fill diagnosis and code. Need produce audit report likely. Need understand ask: "You are a quantitative auditor hunting for lookahead bias, silent failures, schema mismatches, and statistical flaws in FX algorithmic trading infrastructure. You have access to the full codebase and documentation. Be exhaustive." They provided docs/code. Need identify issues in provided code/docs. Need likely mention if no lookahead. Let's audit.

Need parse all code. Need identify potential bugs. Let's inspect MQL5 code.

Key files:
- fxmatrix_v2_eurgbp.mq5 dual instance EURGBP with AB signal using EURUSD/GBPUSD legs.
- fxmatrix_v2.mq5 GBPUSD production single-sigma BC.
- fxmatrix_v2_eurusd.mq5 EURUSD same single-sigma plus deadband vol scaling.
- signal mqh with functions.

Need audit for:
1. Lookahead bias: CopyClose(symbol, PERIOD_M5, 1, 60, closes) starts from bar 1, not current forming bar. ArraySetAsSeries true. closes[0] is previous completed bar close. Then c6=closes[6], etc. V2_MidNowFromSymbol uses current bid/ask? Wait for BC production: `bc_now = closes[0] + half` where half = (ask - bid)/2 current. closes[0] previous close, so bc_now approximates current mid? Actually current mid = (bid+ask)/2. closes[0] is previous bar close. They use closes[0] + half; that's previous close + half current spread, not current mid. Potential issue: if price moved since previous close, current mid differs. For AB signal, `ac_now = V2_MidNowFromSymbol(InpLegAC, ac_closes[0])` returns fallback_close + (ask - bid)/2. If bid/ask >0 fallback is ac_closes[0] plus half spread. So they don't use current mid from bid/ask, they use previous close + current half spread. That is a silent stale quote/signal issue. But maybe because CopyClose with shift 1 means previous closed M5; at new bar open, closes[0] is previous completed bar. Current mid might be stale by up to 5 minutes plus movement. Could cause signal to be mispriced, especially fast markets. Need flag. Also in V2_MidNowFromSymbol comment maybe says fallback but always uses fallback. `if(bid >0 && ask >0) return fallback_close + (ask - bid)/2.0;` It ignores actual bid/ask mid, uses previous close. This is odd. Could be deliberate to avoid microstructure? But docs "Live spread from CSV SPREAD column" may use close + half spread. Let's analyze.

In fxmatrix_v2.mq5 `Long_ComputeBidSignal`: CopyClose(_Symbol, PERIOD_M5, 1, 60, closes); `bc_now = closes[0] + half;` half current spread. This is not current price. Since CopyClose returns previous bar closes (shift=1), closes[0] is previous M5 close. At every tick after bar closed, until next bar close, closes[0] is fixed. So signal only changes when current spread changes (half), not when price changes. Pending limit is only updated each new bar anyway (Long_OnNewBar). So maybe intended to compute at new bar using previous close plus spread. It's not lookahead (uses previous close) but stale. However, in `V2_MidNowFromSymbol`, fallback close likely previous close. So okay.

But wait: CopyClose(symbol, PERIOD_M5, 1, 60, closes) copies the last 60 closed M5 bars before current forming bar. `closes[0]` is most recent closed bar. At the start of a new M5 bar, yes closes[0] = previous bar close. At any tick during bar, it remains previous closed bar. So "now" is not current. This may be intentional to avoid incorporating current price? But dynamic signal would be lagged. Potential statistical flaw: quote distance computed from CSV `SPREAD` and closes? They use "mid = closes[0]+half" where closes are from historical bars; at each bar close? If offline reproduction, need inspect. Could be.

2. Lookahead in V2_FvSigmaFromCloses: uses closes[6], closes[12], closes[48] from array of closed bars (shift 1 means bars 1..60). Index 6 corresponds bar 7 (i.e., close 6 bars ago? Wait with series: array index 0 = shift 1, index 1 = shift 2, etc. closes[6] = shift 7? Actually CopyClose(_Symbol, PERIOD_M5, 1, 60) with ArraySetAsSeries true: element 0 is oldest? Need MQL5: ArraySetAsSeries changes indexing so first element is most recent in time series. But CopyClose parameters: start_pos=1, count=60. It copies from current bar? It returns 60 elements starting from bar 1 (previous closed bar) to bar 60. With series, element 0 = bar 1 (most recent), element 59 = bar 60. So closes[6] = bar 7 (6 bars before the most recent closed bar). closes[12]=bar 13, closes[48]=bar 49. They call c6,c12,c48 but actually are 7,13,49 bars back from now? If they wanted closes[6] = current bar 6? Let's verify MQL5 CopyClose: If start_pos=0, copies current (forming) bar? Documentation: "Copies to the array data on the specified symbol, timeframe, number of elements into the array, starting from the specified position. The elements order is from present to past." If start_pos=1, skip current bar and start with previous. If ArraySetAsSeries(closes, true), indexing from present to past, element 0 corresponds start_pos=1. So closes[6] = bar 7. They may have intended bar 6, 12, 48? Usually index naming c6 could mean closes[6] which is 6 bars ago if start_pos=0. But they start at 1 so off by one. Is this lookahead? It's using older bars than intended; no lookahead. But if V1 used closes[6] from start_pos=0? Here code says CopyClose(...,1,60) and c6=closes[6]. If intended "6 bars ago" maybe should be closes[5] because shift 1 offsets. But docs maybe use c6/c12/c48 as exact. Need flag potential off-by-one. Need also check `V2_FvSigmaFromCloses` requires ArraySize >=49, uses index 48 (49th element). With count 60 okay.

Would using previous closed bar instead of current forming bar be lookahead? It avoids lookahead. But if using current bid/ask for half spread at same time as previous close? Not lookahead. However, in `V2_MidNowFromSymbol`, `fallback_close + half_spread` uses previous close and current half spread. If current bid/ask available, should use `(bid+ask)/2` to reflect current mid. Using previous close + half current spread can produce "now" price inconsistent with actual current price, causing signal stale and maybe quotes far from reachable? Actually at new bar open, previous close equals previous bar's close; current spread at open maybe larger, so mid estimate = previous close + half. But actual current mid = previous close + actual move + half. If price has gapped, stale. This could affect fill rates. This is a silent flaw.

3. AB signal formula: Need audit math.

For EURGBP cross: Want quote theoretical price for EURGBP. They compute fv_ac from EURUSD closes, fv_bc from GBPUSD closes, ratio = fv_ac/fv_bc. inst_spread = r_ac - r_bc = log(ac_now/fv_ac) - log(bc_now/fv_bc) = log((ac_now/bc_now)*(fv_bc/fv_ac)). bid = ratio * exp(inst_spread - dynamic_hs) = fv_ac/fv_bc * exp(log(ac_now/bc_now * fv_bc/fv_ac) - hs) = ac_now/bc_now * exp(-hs). Wait because ratio * exp(inst_spread) = fv_ac/fv_bc * (ac_now/bc_now)*(fv_bc/fv_ac) = ac_now/bc_now. So bid = (ac_now/bc_now) * exp(-hs). This is basically current cross mid = ac_now/bc_now, shifted down by half-spread. But ac_now and bc_now are previous close + spread, not current. Let's derive: `ratio * exp(inst_spread - dynamic_hs)` = (ac_now/bc_now) * exp(-dynamic_hs). Yes. So the AB formula is simply quote = current implied cross mid (from leg mid estimates) scaled by exp(-hs). No mean-reversion component beyond using current vs fv? Actually ac_now/bc_now is current cross, so signal is just current price minus half-spread, no long-term reversion? Wait inst_spread includes r_ac - r_bc; ratio = fv_ac/fv_bc; product gives ac_now/bc_now. Indeed the fair value cancels. So "theoretical" is always current cross mid shifted by dynamic_hs. The fv and sigma only determine dynamic_hs. So it's not a mean-reversion signal; it's a passive limit order at current mid minus hs. For BC formula: fv * exp(r_bc - hs) = fv * exp(log(bc_now/fv) - hs) = bc_now * exp(-hs). Also current mid shifted. So same, no reversion! Wait in BC, fv * exp(r_bc) = fv * bc_now/fv = bc_now. So bid theoretical = bc_now * exp(-dynamic_hs). So all formulas are just current mid scaled down by half-spread, not fair-value reversion. Huh. The fair value cancels entirely. So why compute FV? Only for sigma. The quote is at a fixed distance from current mid, not from fair value. That's important. The "quote distance" table in docs says quote distance = fair mid minus bid quote. They call fair mid maybe current mid? If current mid = fv*exp(r), yes. Their quote distance = mid - bid = mid*(1 - exp(-hs)) ≈ mid*hs. So dynamic_hs controls distance. Fine.

But potential issue: If current mid moves, quote moves with it; not mean-reverting. The algorithm is basically placing limit orders at a dynamic distance behind current price, which is market-making not reversion.

4. Use of `MathMax(sig_ac, sig_bc)` in eurgbp vs native sigma in BC. Docs identify this as cause. Need audit if statistical flaw: Should use EURGBP's own volatility? But for AB pair, cross-asset volatility derived from legs: VAR(EURGBP) ≈ VAR(EURUSD)+VAR(GBPUSD)-2COV. Using max of leg sigmas is not the same; could overestimate. Actually typical realized vol of EURGBP = sqrt(σ_AC^2 + σ_BC^2 - 2ρσ_ACσ_BC). If ρ high, cross vol low. Max is even larger. Using max is ad hoc. The doc says it was deliberate? "Dual-sigma AB-slot" maybe intended to use max of leg sigmas to avoid too tight? But statistical flaw: not variance-consistent. Should use native cross-currency sigma or combination. Need flag as statistical flaw in risk sizing: dynamic half-spread should be based on volatility of the traded symbol, not max of components, unless there is a rationale for stress. Their own diagnosis says native EURGBP σ 0.000176, max legs 0.000655, 3.7x larger. This causes low fill rate and is likely the main cause. Need maybe cite.

5. Silent failures:
- `V2_L0ResolveLiveSpreadPrice` has static `g_last_valid_spread_price = -1.0;` This static persists across calls within EA. In signal.mqh included in multiple EAs? Each EA separate process, okay. But in single EA, both long and short calls share static. If first call raw spread >0 sets. If later raw spread =0 (some symbols? market closed?), it continues last valid. Fine. But if server spread returns 0 during illiquid, uses stale spread. Could be silent.
- `V2_MidNowFromSymbol` returns `fallback_close + (ask - bid)/2.0`, but if bid/ask >0 it never uses actual mid; maybe intentional but odd. If symbol quotes unavailable? It uses fallback close. If bid/ask =0, uses fallback close. But if bid/ask both >0, still fallback + half. Need mention as schema mismatch/inconsistent "now" semantics.
- `Long_ComputeBidSignal` in fxmatrix_v2.mq5 calls `CopyClose(_Symbol, PERIOD_M5, 1, 60, closes)` directly with no check `CopyClose` return? It checks if <49. But does not call `ArraySetAsSeries(closes, true)` until after CopyClose. Yes line 107. Good.
- In `V2_CopyM5Closes`, only checks `CopyClose(symbol, PERIOD_M5, 1, 60, closes) < 49`; if CopyClose returns -1, `closes` may be empty. Good.
- In `V2_FvSigmaFromCloses`: `ArraySize(closes) < 49` returns false, but no check for `closes` series orientation. If caller passes array not series, c6 etc. wrong. V2_CopyM5Closes sets series. In fxmatrix_v2.mq5 direct code sets series. Good.
- `V2_ComputeBcBid` and `V2_ComputeBcOffer` use `now = V2_MidNowFromSymbol(symbol, closes[0])` but not used? They compute r using now. okay.
- `V2_ComputeAbBidOffer` unused? It computes `dynamic_hs = quote_spread + MathMax(sig_ac, sig_bc) * spread_multiplier;` missing live_spread/passivity buffer and effective multiplier ease. In eurgbp EA uses V2_L0DynamicHalfSpread, not this helper. But signal.mqh contains helper with simplified formula. Potential silent if future use. Need flag schema mismatch: two functions for same AB signal diverge. In `V2_ComputeAbBidOffer`, it doesn't include `effective_multiplier` or `V2_L0DynamicHalfSpread`, so would not match. Also includes sanity check that does nothing:
```
if(ab_symbol != _Symbol && ab_symbol != "")
{
   // Prices are already in AB terms; no further conversion needed.
}
```
This is dead code, perhaps schema mismatch.
- The AB helper uses `MathMax(sig_ac, sig_bc)` but no passivity buffer; docs compare to production formula? It's a library helper not used by eurgbp? Need mention.

6. Deadband logic:
`V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult)` called with 4 args in GBPUSD/EURGBP and 5 args in EURUSD. Need inspect logic.mqh not provided. But likely okay. However, in `Long_ReplacePendingBuy`, if resting within deadband, it increments `g_long_stat_l0_deadband_skip` and returns false without updating the order. If the new `bid_lvl` is outside deadband but the resting order is within deadband? Actually if distance between resting price and new price < deadband, skip; if >, cancel and replace. That means quote lags until move exceeds deadband. Fine.
Potential bug: `V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult)` with ticket_ref=0? Need function not shown. likely handles.

7. L0 quote placement:
`Long_OnNewBar` only updates L0 when `n == 0` (no positions). If positions exist, L0 ticket may remain? When position fills, `Long_HandleDealFill` clears `g_long_l0_ticket = 0` if order_ticket == g_long_l0_ticket. But if L0 ticket is not the one filled? If an L0 buy limit fills, yes. If add fills, clears add. If no positions, updates. Good.
But `Long_EnsureAddNext` after n >0 places pending add orders. It doesn't check L0. Good.

Potential silent failure: In `Long_HandleDealFill`, when exit fill occurs, it calls `Long_RemoveLayerAt(layer_idx)` before logging, and `Long_RemoveLayerAt` increments exits and maybe triggers `Long_EnsureAddNext`. In exit fill handling, after removing layer, if stack becomes 0, maybe `g_long_last_exit_valid` set true. But it queues CloseBy for original position and hedge. There may be a race: if position was closed by exit limit, `orig_pos` may no longer be resolved? `Long_ResolvePositionTicket(g_long_layers[layer_idx].position_ticket)` returns 0 if position closed? Wait deal entry for exit limit creates a position? Let's understand hedging mode. They place exit limit with magic MM_LONG_V2_EXIT; when it fills, it likely opens a new opposite position (hedge) rather than closing original? They queue CloseBy to close original and hedge. In `Long_HandleDealFill` for exit fill, `position_id` from deal maybe new position. `orig_pos = Long_ResolvePositionTicket(g_long_layers[layer_idx].position_ticket)`; the original position may still be open (hedged), so resolves. Good.
If exit fill happens and `orig_pos` is 0 (original closed), `V2_QueueCloseBy(g_long_closeby_queue, orig_pos, position_id)` with orig_pos=0? It checks `if(orig_pos > 0 && position_id > 0)`, so no. But then layer removed, leaving hedge position orphan. Could be silent. But maybe original position remains until CloseBy. Not major.
Need check `V2_ComputeExitRealizedPnl(deal_ticket, orig_pos)` if orig_pos=0. Unknown.

8. OnTradeTransaction:
```
if (trans.type != TRADE_TRANSACTION_DEAL_ADD)
   return;
Long_HandleDealFill(trans.deal, trans.position);
Short_HandleDealFill(trans.deal, trans.position);
```
If a deal is for another symbol? Long_HandleDealFill checks `deal_sym != _Symbol` returns. Good.
Potential issue: They call both long and short handlers for every deal. Each has processed array. Fine.
Could miss deals if transaction type is `TRADE_TRANSACTION_DEAL_ADD` but deal not yet in history? They call `HistoryDealSelect` immediately; likely okay. If not, deal lost forever because no startup reconciliation of deals. Potential silent failure: If `OnTradeTransaction` is called before history deal available, `HistoryDealSelect` may fail, and since not processed, later ticks won't re-fetch unless another deal occurs. There is no periodic history scan. This could cause missed fills, positions tracked incorrectly. Need flag.
Also `Long_MarkDealProcessed` is called after `HistoryDealSelect` succeeds; if fail, unprocessed. But no retry. Could be a source of silent failure.

9. `Long_OnNewBar`:
- Uses `iTime(_Symbol, PERIOD_M5, 0)` to get current bar time. If no new bar, return. On first tick, `g_long_last_bar_time=0`, so processes. Good.
- But if `Long_ComputeBidSignal` returns false (e.g., no closes) on a new bar, then `g_long_last_bar_time` is already set to bar_time before compute? Actually it sets `g_long_last_bar_time = bar_time;` before compute. If compute fails, it returns without updating L0. On subsequent ticks same bar, `bar_time == g_long_last_bar_time`, so it will never retry until next bar. That's a silent failure if CopyClose temporarily fails (e.g., history not fully loaded). Should set last_bar_time after successful computation or use fallback. Flag.
Same in Short_OnNewBar.

10. `V2_ApiCounterMaybeReset` calls? Not shown.

11. Capital caps:
In fxmatrix_v2.mq5 (GBPUSD), `Long_EnsureAddNext` uses `V2_GbpCapBlocksNewAdd("GBPUSD", true, InpGbpCapThreshold)`; `Short_EnsureAddNext` same. In eurgbp EA, uses `V2_AnyCapBlocksNewAdd(true, InpGbpCapThreshold, InpEurCapThreshold)` (from dual cap include). In eurusd uses `V2_EurCapBlocksNewAdd`. Need not audit.

12. Magic numbers:
- In fxmatrix_v2.mq5, `#define MM_LONG_V2` and `MM_SHORT_V2`? It uses `20260901` literal in many places instead of define? At top of file, code output doesn't show defines? It likely defines in logic.mqh? In eurgbp it defines. In fxmatrix_v2.mq5 at top, I don't see `#define MM_LONG_V2 20260901` in provided excerpt? It uses `MM_LONG_V2` in code, but no definition in file? Maybe included from logic.mqh. In `Long_EnsureAddNext`, uses `Long_PlaceBuyLimit(add_price, 20260901, ...)` literal; in `Long_HandleDealFill` compares `deal_magic == (long)20260901`; in `Short_EnsureAddNext` uses 20260902; in `Short_HandleDealFill` compares 20260902. But in `Long_SetExitTakeProfit`, uses `MM_LONG_V2_EXIT`, likely defined in logic. Could be fine but inconsistent. Magic mismatch silent: In eurgbp, `Long_EnsureAddNext` uses `MM_LONG_V2`; `Long_HandleDealFill` compares `MM_LONG_V2`. Good. In EURUSD uses macros. In GBPUSD uses literals, but macro likely same. No issue if macro defined. But code as shown has no `#define MM_LONG_V2`, maybe omitted due to excerpt starting after includes? Actually it says "fxmatrix_v2.mq5 — Production V2 dual instance (MM_LONG + MM_SHORT)" and magic numbers comment. It likely includes logic.mqh that defines? The code output includes no #define, but uses `MM_LONG_V2_EXIT`, so must be defined in logic.mqh. Not our focus.

13. Statistical flaw in documentation:
- "full_quarter, 2026-03-09 → 2026-06-05" future date? Current date? We don't know. Could be synthetic. Not relevant.
- Step 2 says "Reproduced offline from data/*_full_quarter.csv using production formulas. Assumed L0 empty stack (`effective_multiplier = 0.5`)." But production formula includes `live_spread_price = V2_L0ResolveLiveSpreadPrice(InpQuoteSpread)`, which uses current symbol spread from terminal, not CSV `SPREAD` column? Wait `V2_L0ResolveLiveSpreadPrice` uses `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` at runtime. In offline reproduction, cannot call MT5, so they used CSV SPREAD column to compute live_spread_price. The doc says "Live spread from CSV `SPREAD` column (points × 0.00001)." So they computed `dynamic_hs = max(InpQuoteSpread + sigma*mult, spread_points*0.00001 + 0.00005)`. Good.
- But in production, `V2_L0ResolveLiveSpreadPrice` stores static last valid spread and uses `_Point` of `_Symbol`. For EURGBP _Point maybe 0.00001, raw spread points from SymbolInfoInteger is in points. CSV SPREAD points × 0.00001, okay.
- Quote distance = "fair mid minus bid quote, in pips." Formula: bid = ratio*exp(inst_spread - dynamic_hs), fair mid = ratio*exp(inst_spread) = ac_now/bc_now. Distance in price = mid - bid = mid*(1-exp(-hs)). Convert to pips: price / (point*10) because EURGBP 5-digit. Good. But if using previous close + half spread as mid, "fair mid" is not actual fair value but stale current cross mid. They call "fair mid" incorrectly. This may affect fill rate analysis.

14. Potential major issue: `V2_MidNowFromSymbol` using previous close + half spread vs current bid/ask. Let's examine if for legs, `ac_now` and `bc_now` should be current mid. The code computes `double ac_now = V2_MidNowFromSymbol(InpLegAC, ac_closes[0]);` But in `V2_MidNowFromSymbol`, if bid/ask > 0 returns `fallback_close + (ask - bid) / 2.0`. It doesn't use bid. So if EURUSD price moved from previous M5 close to current, signal doesn't move. Since L0 order updated only on new M5 bars, maybe at new bar open they want to use previous close; but during the bar, bid/ask may be current. Wait they call this at new bar event, which occurs on first tick of new bar, so current bid/ask are at that moment, but `closes[0]` is previous bar close. `fallback_close + half` = previous close + half current spread. But actual current mid may differ from previous close due to the gap from last tick of previous bar to first tick of new bar. Usually at bar boundary, last price of previous bar equals first price of new bar if continuous; if there is no gap, current mid ≈ previous close. So okay at bar open. But `Long_OnNewBar` is triggered on first tick after bar_time changes, which could be seconds/minutes into bar, not necessarily at exact boundary if no tick? If no tick at boundary, first tick later; current price may have moved. Still stale.

For BC production, `CopyClose(_Symbol, PERIOD_M5, 1, 60, closes)` with shift 1 returns previous closed bar. If called on first tick after bar close, okay. If called at a random time when iTime current bar changes? It only calls once per new bar, first tick. So likely okay-ish. But for AB helper in other contexts, could be stale. Need mention.

15. Lookahead bias specific:
- In `V2_FvSigmaFromCloses`, uses `closes[6]`, `closes[12]`, `closes[48]` from closed bars. No current bar. No lookahead.
- In `V2_MidNowFromSymbol`, uses `fallback_close` (closed bar) and current spread. It does not use current bid/ask mid. That avoids lookahead? Actually using current spread at time t while also using close from time t-1 can be considered mixing timestamps, but not lookahead because current spread is available. If using current bid/ask mid, also available. No lookahead.
- In `Long_ComputeBidSignal` in fxmatrix_v2.mq5, `bc_now = closes[0] + half`; `closes[0]` is previous closed bar. If `half` current, no lookahead. But if they intended to use current mid, they might be using previous close and current half spread, causing signal to be based on previous close plus spread; still no future data.

Potential lookahead in order placement: On new bar, they compute signal and place limit order based on previous bar's close. If a big move occurred during previous bar, the order is based on previous close, not current; not lookahead. It might be filled immediately if current price has already passed the limit, leading to adverse selection. Actually the limit is placed after the bar close at a price derived from the just-closed bar's close (known). If current price at bar open has moved beyond, the pending order may be filled immediately. This is not lookahead but stale signal causing adverse selection. Need flag.

16. Schema mismatches:
- The documentation says "Private `Long_ComputeBidSignal` in fxmatrix_v2.mq5 uses `bc_now = closes[0] + half`, where `half` is current spread, not `V2_MidNowFromSymbol`." In eurgbp uses `V2_MidNowFromSymbol`. But both effectively previous close + half current spread. Fine.
- `fxmatrix_v2_eurusd.mq5` has `Long_ComputeBidSignal` placed after Short struct, not before Long_OnNewBar? In code, `Long_ComputeBidSignal` appears in short section but okay. It lacks `Short_ComputeOfferSignal`? It has both.
- `fxmatrix_v2_eurusd.mq5` has `input bool InpL0DeadbandVolScale = true;` and `EurUsd_L0DeadbandSpreadRef` used only in deadband calls. But `V2_L0RestingWithinDeadband` signature likely has optional `spread_ref` parameter. Since `fxmatrix_v2.mq5` and `eurgbp` call with 4 args, `eurusd` with 5 args. Need know logic.mqh. Could be okay if function has default. But if not, compile error. Since docs say generated files, likely okay. Need not.
- In `fxmatrix_v2.mq5`, `V2_EffectiveSpreadMultiplier` is in signal.mqh but `Long_ComputeBidSignal` uses dynamic_hs with `V2_L0DynamicHalfSpread`. Good.
- In `fxmatrix_v2.mq5`, `Long_ComputeBidSignal` missing `if(InpVerboseLog && ArraySize(g_long_layers) == 0 && ArraySize(g_short_layers) > InpEaseDepthStart)`? It has. Good.
- In `fxmatrix_v2.mq5`, `Long_OnNewBar` uses `Long_ReplacePendingBuy` with 4 args, no deadband vol scale. `EURUSD` uses 5. Good.

17. Critical statistical flaw in AB formula vs BC: The docs says "dual-sigma AB-slot vs single-sigma BC-slot". It claims AB uses `MathMax(sig_ac, sig_bc)` intentionally. But deriving from duo-leg:
For an FX cross X/Y, if X and Y both quoted against USD, the log return of X/Y = r_X/USD - r_Y/USD. Variance = σ_X^2 + σ_Y^2 - 2ρσ_Xσ_Y, not max. Since EURUSD and GBPUSD are positively correlated, variance can be much lower. Using max is a rough upper bound, not the variance of the cross. The median native EURGBP sigma is 0.000176 vs max 0.000655. That's 3.7x. Because half-spread is exponential, quote distance = mid*(1-exp(-hs)). Pips distance scales with hs maybe. So fill rate severely reduced. If goal is to have similar fill probability, should use native sigma or formula. This is a statistical flaw.

Need also examine if `MathMax(sig_ac,sig_bc)` should at least be `MathSqrt(sig_ac*sig_ac + sig_bc*sig_bc)` (uncorrelated) or native. The doc mentions "dual-sigma" maybe intended to use both, but `MathMax` discards one entirely. If needing both, maybe use RMS, not max. So flag.

18. Potential issue in `V2_FvSigmaFromCloses`: Sigma is computed from only 3 points (c6,c12,c48). That's a very small sample, high variance. It is not a robust estimate of volatility. Using it for dynamic half-spread could be noisy. For each symbol, sigma from closes at lags 7,13,49 (actually). This is essentially a 3-point dispersion around mean. It may vary. Statistical flaw: "sigma" not standard deviation of returns, but dispersion of levels. Could be okay as a term-structure curvature measure. But docs treat as volatility. Need mention: It measures deviation of three closing prices from their mean, not return volatility; this is a weak proxy and may not scale with true realized volatility. But production code uses it. The diagnostic report uses this as sigma. Could be a statistical flaw: The 3-point "sigma" is not comparable across pairs unless prices normalized? It is absolute price deviation. For EURUSD/GBPUSD ~0.0004-0.0006; for EURGBP 0.000176. This is price level dispersion, not volatility. But still.

19. L0 fill count statistics in docs:
- Step 4: "Counts = OUT deals on positions that had V2 magic IN entries (magics 20260901/02, 20260911/12, 20260921/22)." For EURGBP, IN entries magics 20260921/22 (long/short). EXIT events: 6. But it says 6 (5 wins, 1 loss) in table; table "With P&L | 6" and "6 (5 wins, 1 loss)" maybe. Good.
- Potential statistical flaw: Comparing counts across pairs without exposure time. EURGBP may be less frequent because fewer opportunities or because quote distance. The report uses quote distance/range to explain. Good.
- Median time between exits for EURGBP ~31.6 hr could be affected by one long trade (14.4 hr position? Actually holds). Small sample n=6, so medians unreliable. Need mention small sample.
- The case study: "M5 price path Jul 20 14:00 → Jul 21 02:17: best low 0.84874 — past the exit target (243% of exit distance)." For a short entry 0.84947, exit target 0.84917 (3 pips below). Best low 0.84874 is 7.3 pips below entry? Distance from entry to best low = 0.00073 = 7.3 pips, 243% of 3 pips. Yes. "L0 did fill; price reached exit zone; failure was exit resolution, not quote distance." But if exit resolution failed because exit limit not placed or non-V2 exit, that's separate. Need maybe mention that if exit limit was not placed due to bug, the "unresolved scalp" is an exit failure, not L0 fill rate. But docs already.

20. Need audit "line count 310" from doc? Not relevant.

21. Potential hidden lookahead in the offline reproduction:
The diagnostic report says "Reproduced offline from data/*_full_quarter.csv using production formulas." If they used full_quarter data including future to compute quote distance vs realized movement, that's not lookahead in trading code but in analysis? They compare quote distance to realized 1-bar range. If they calculate quote distance at each bar from data available at that bar (previous closes and current spread), okay. Need no.

22. Code bugs:
- In `Long_OnNewBar`, `g_long_last_bar_time = bar_time` before computing signal. If signal false, no retry. Already flag.
- In `Short_OnNewBar` same.
- In `Long_AppendLayer`, `open_depth = n`, where n before resize is old size, so first layer 0. Good. After removals, open_depth stays original depth? They don't update when shifting. If layer 0 removed, layer 1 shifts to index 0 but open_depth remains 1. Could affect telemetry "stable after compaction"? In struct they say "0=L0 at fill (Python sim parity; stable after compaction)". Actually after removing layer 0, remaining layer at index 0 has open_depth=1 (original), so not stable? The comment says stable after compaction? Let's inspect: `Long_RemoveLayerAt` shifts layers and array resizes, but does not update open_depth. So if first layer exits, second layer shifts to index 0 but open_depth remains 1. In `Long_HandleDealFill` for exit, it computes `open_depth = g_long_layers[layer_idx].open_depth`. This is original depth at fill. Good. But in `Long_AppendLayer` for new layers after compaction, `n = ArraySize(g_long_layers)` old size; if old size after compaction =1, new layer open_depth=1, same as shifted layer? Wait if one layer remains with open_depth=1, and you add a new layer, old n=1, so new layer open_depth=1. Two layers with same open_depth. That's a bug if open_depth should represent current depth. But comment says stable after compaction? Let's understand layer stacking: They append layers as price moves against position. If top layer exits (was_top), they remove it, set last_exit_valid, shift lower layers? Actually if top layer exits, it's last index; no shifting. If a non-top layer exits (e.g., layer 0 hits exit target while deeper layers remain), they remove it and shift deeper layers down; open_depth remains original. New additions after that use current array size as depth, which may duplicate. For telemetry, open_depth maybe intended as original depth for performance metrics. But if duplicate in active stack, could confuse. This is a data integrity flaw. Need mention? Maybe beyond scope.
- `Long_RemoveLayerAt` when `was_top` sets `g_long_last_exit_price` and valid. If non-top layer exits, it doesn't update last_exit. That's correct because stack remains. But `g_long_stat_exits++` increments per layer.
- `Long_ClearExitTakeProfit` defined but never used? Probably okay.

23. More critical: `V2_L0DynamicHalfSpread` uses `MathMax(quote_spread + sigma * effective_multiplier, live_spread_price + passivity_buffer_price)`. For EURGBP, `InpQuoteSpread=0.0004`, sigma ~0.000655, mult 0.5 => 0.0004+0.0003275=0.0007275. `live_spread_price + passivity` = current spread + 0.00005. Median spread 0.00004? Wait EURGBP median CSV spread 0.4 pips = 0.00004 (not 0.0004). InpQuoteSpread 0.0004 = 4 pips? Let's calculate: EURGBP point 0.00001, pip=0.0001. 0.0004 = 4 pips. `quote_spread` is not actual spread but a floor in price units? It says 0.0004 = 4 pips. In production inputs identical. Live spread floor = `live_spread_price + passivity_buffer` = 0.00004 + 0.00005 = 0.00009 (0.9 pips). But `quote_spread + sigma*mult` = 0.0004 + 0.0003275 = 0.0007275 (7.3 pips). So the huge `InpQuoteSpread` dominates. Wait docs say `dynamic_hs` median 0.000730. That means the dominant term is `InpQuoteSpread` 0.0004 plus 0.00033, not live spread. The "passivity floor binds <1%" yes. But `InpQuoteSpread` is 4 pips, which is already huge relative to EURGBP median 1.4 pip range. The diagnosis says "specific inputs: decisive input is MathMax(sig_ac,sig_bc), not InpQuoteSpread or passivity buffer (which bind <1% of bars)." But actually `InpQuoteSpread` contributes 0.0004 out of 0.00073 (55%). If EURGBP used native sigma, dynamic_hs = 0.0004 + 0.000088 = 0.000488 (4.9 pips), still quote distance ~? Docs say "median dynamic_hs would drop from 0.000730 → ~0.000488, cutting quote distance to ~3.4 pips". That's still 3.4 pips vs 1.4 pip range, ratio 2.4. So `InpQuoteSpread` 4 pips is also far too high for EURGBP 1.4 pip range. For GBPUSD, 0.0004 = 4 pips? GBPUSD point 0.00001, pip=0.0001, also 4 pips. But GBPUSD 1-bar range 3.8 pips, so quote distance 9.5 pips. The quote distance includes sigma. Wait `InpQuoteSpread` 4 pips + sigma*0.5 ~3 pips = 7 pips half-spread; quote distance ~9.5 pips due to exponential? Actually if hs=0.000708 (7.08 pips), mid=1.25, price distance = mid*(1-exp(-0.000708)) ≈ 0.000885 = 8.85 pips. Table median quote distance 9.51 pips. So 4 pips floor is significant. For EURGBP, hs=7.3 pips, mid ~0.85, distance ≈ 0.0062? Wait 0.85*(1-exp(-0.00073)) = 0.00062 = 6.2 pips. Yes.

So the diagnostic's conclusion that "decisive input is MathMax" may be questionable because `InpQuoteSpread=0.0004` is also oversized relative to EURGBP's realized vol. But they compare ratio: If native sigma, dynamic_hs ~0.000488 (4.9 pips) gives quote/1-bar ratio ~2.4x similar to others. If `InpQuoteSpread` alone (0.0004=4 pips) with no sigma gives quote distance ~3.4 pips, ratio 2.4. Hmm. Actually with native sigma + InpQuoteSpread = 0.000488, quote distance 0.85*(1-exp(-0.000488)) ≈ 0.000414 = 4.14 pips, ratio 2.96. The doc says 3.4 pips maybe using fair mid? Let's compute 0.000488 price = 4.88 pips. But because mid~0.85, price distance in pips = 0.85*(1-exp(-0.000488))*10000 = 0.85*0.0004877*10000 = 4.15 pips. Not 3.4. Their "quote distance ~3.4 pips" maybe uses dynamic_hs in pips directly? Actually if native hs=0.000488, price distance ≈ 0.85*0.000488 = 0.000415 = 4.15 pips. To get 3.4, mid maybe 0.70? No, EURGBP ~0.85. So docs' "~3.4 pips" maybe wrong. Let's not overdo. But as auditor, could mention arithmetic inconsistency? Need be careful.

Let's re-evaluate docs table: "Median dynamic_hs" 0.000730. "Median quote distance (pips) 6.32". If mid ~0.86, distance in price = mid*(1-exp(-hs)) ≈0.86*0.000729=0.000627 = 6.27 pips. Yes. If dynamic_hs drops to 0.000488, distance ≈0.86*0.000488=0.000420 = 4.20 pips. Not 3.4. But maybe they calculate quote distance = hs in pips? For GBPUSD, hs=0.000708, quote distance 9.51 pips; if mid=1.27, 1-exp(-0.000708)=0.000708, price=0.000899, pips=8.99, close to 9.51. For EURGBP, hs=0.000730, mid=0.85 -> 6.2 pips, table 6.32. If hs=0.000488, mid=0.85 -> 4.15 pips. So docs' 3.4 seems off by 0.75 pips. Minor.

More importantly, the conclusion "specific inputs: The decisive input is `MathMax(sig_ac, sig_bc)` feeding `V2_L0DynamicHalfSpread`, not `InpQuoteSpread` or passivity buffer" is partially false. `InpQuoteSpread=0.0004` is 4 pips, and EURGBP median 1-bar range 1.4 pips. It is a major contributor. But since all pairs share same InpQuoteSpread, the difference between EURGBP and USD legs is due to sigma. However, absolute quote distance for EURGBP is still dominated by quote spread floor. The docs acknowledge "if EURGBP used native sigma, median dynamic_hs drops to 0.000488" (still 4.9 pips). That means `InpQuoteSpread` contributes 82%, sigma 18% after drop. Actually original: quote_spread=0.0004, sigma contribution=0.000330. So quote_spread is 55% of hs. Native sigma contribution=0.000088, so quote_spread is 82%. So to make EURGBP fill rate comparable, you'd need reduce `InpQuoteSpread` too. The report says "not InpQuoteSpread" but it's a floor that binds >99% of bars? Wait the floor in `MathMax` is two terms: `quote_spread + sigma*mult` vs `live_spread + buffer`. The first term contains `InpQuoteSpread`, so it's not just a floor? It's the base term. The "passivity floor" is live_spread + buffer. The report says "not InpQuoteSpread or passivity buffer (which bind <1% of bars)" — they mean passivity buffer binds <1%, but InpQuoteSpread is in the main term, not a binding floor. They may be saying `InpQuoteSpread` is identical across pairs so not the differentiator. That's true. But for absolute fill rate, it matters. Need mention nuance.

24. Need identify possible lookahead in `V2_MidNowFromSymbol`: It uses `fallback_close + (ask - bid)/2.0` instead of actual `(bid+ask)/2`. This is a "schema mismatch" because function name says MidNow but returns previous close + half spread. Is this lookahead? It uses previous close, so no. But it's inconsistent with current mid. Could cause signal to be off by the price move since previous close. In a fast market, this is dangerous. For example, if EURUSD gaps up 20 pips between bar close and first tick of new bar, ac_now remains old close + spread, so signal doesn't reflect gap; the L0 buy limit may be placed far above/below current price and could fill immediately at a bad price. Actually if price gaps down, a buy limit set relative to old mid may be above current market, causing immediate buy at old mid-hs, but current price lower, maybe adverse. This is a significant silent flaw. Need flag as high severity. It is in both `fxmatrix_v2.mq5` and `fxmatrix_v2_eurgbp.mq5`. Wait in `fxmatrix_v2.mq5`, `bc_now = closes[0] + half`, where `half` is current half spread. If price gaps down 20 pips, `bc_now` old close + half, so bid_theoretical = fv*exp(r_bc-hs) = bc_now*exp(-hs) ≈ old mid - hs. If current bid is much lower, a buy limit at old mid-hs may be above current ask, so it fills immediately at price above market? Actually a buy limit placed above current ask is normally rejected? In `Long_PlaceBuyLimit`, it checks `if (price > bid - min_dist) return 0;` It will not place if price is too close to current bid. If old mid-hs > current bid - min_dist, it returns 0. So L0 ticket not placed (silent). If price gaps up, old mid-hs < current bid, it may place limit far below market and not fill. So stale signal can cause missed or rejected orders. This could contribute to low fill rate. Need mention.

25. More about `V2_MidNowFromSymbol`: It takes `fallback_close` and if `bid>0 && ask>0`, returns `fallback_close + (ask - bid)/2`. Why not `(bid+ask)/2`? Maybe because they want to avoid using current bid/ask mid due to spread? But `fallback_close + half_spread` is equivalent to `bid + (fallback_close - bid) + half_spread`? It's wrong. It would be current bid plus (previous close - current bid) + half_spread. No.

Potentially this is a bug introduced by trying to use close + half-spread to approximate mid at close. If the previous close is the last traded price, and current spread is current, then previous close + half current spread might approximate current mid if the last trade occurred at the bid or ask? No. Should use `(bid+ask)/2`. Unless the CSV offline data only has close and spread, not bid/ask; then they used that formula to reproduce. But production code also uses it. Need flag.

26. Need inspect `V2_ComputeBcBid` in signal.mqh: It uses `now = V2_MidNowFromSymbol(symbol, closes[0])`, then r = log(now/fv). If `V2_MidNowFromSymbol` returns previous close + half spread, same issue. But `V2_ComputeBcBid` maybe not used in production EAs? The production EAs implement inline duplicate. Still a library helper.

27. Schema mismatch between AB helper `V2_ComputeAbBidOffer` and actual EURGBP implementation:
- Helper uses `quote_spread + MathMax(sig_ac,sig_bc)*spread_multiplier` for dynamic_hs.
- Actual EURGBP uses `V2_L0DynamicHalfSpread(InpQuoteSpread, MathMax(sig_ac,sig_bc), effective_multiplier, live_spread_price, Long_PipsToPrice(InpPassivityBuffer))`.
- Helper does not include passivity buffer, live spread, effective multiplier/easing. If any future code calls helper, behavior differs. Since the file is included and defines both, but actual code uses its own logic. This is a maintenance/schema mismatch. Need flag.
- Also helper's `ab_symbol` sanity check is a no-op with a misleading comment. It does not verify that computed prices are for `ab_symbol`; it simply proceeds. Could be okay but dead code.
- The helper uses `MathMax(sig_ac, sig_bc)`; perhaps it was used in Python validation? The docs mention "Python validation (score_EUR - score_GBP)". Hmm.

28. Look at `V2_ComputeAbBidOffer` formula: `inst_spread = r_ac - r_bc`, `ratio = fv_ac/fv_bc`, so bid = ratio * exp(r_ac - r_bc - hs) = (ac_now/bc_now)*exp(-hs). If `ac_now`/`bc_now` are previous close + half spreads, okay. No lookahead.

29. Check `V2_FvSigmaFromCloses`: It requires `ArraySize(closes) < 49` return false. If closes array has 49, index 48 is last. Good.
But if `closes` not series and CopyClose default orientation? They set series in `V2_CopyM5Closes`. In `fxmatrix_v2.mq5`, they set series after copy. Good.

30. Potential precision/order issue in `V2_EffectiveSpreadMultiplier`:
If `opposite_depth <= ease_depth_start`, returns `spread_multiplier`. If `>= ease_depth_full`, returns `spread_multiplier_eased`. If `ease_depth_full == ease_depth_start`, division by zero. They check in OnInit `InpEaseDepthFull <= InpEaseDepthStart` -> fail. Good.
If `opposite_depth` negative? ArraySize never negative. Good.

31. In `Long_ReplacePendingBuy`, if it cancels existing order and placement fails, it leaves `ticket_ref=0`? It does:
```
if(V2_L0RestingWithinDeadband(...)) { skip; return false; }
Long_CancelTicket(ticket_ref);
ticket_ref = Long_PlaceBuyLimit(price, magic, comment);
if(ticket_ref > 0) { requote++; return true; }
return false;
```
If placement fails, ticket_ref set to 0 (because assignment from PlaceBuyLimit returns 0). So existing order was canceled and not replaced. This is a silent failure: on a transient API failure, L0 order is removed, and no retry until next bar (because `Long_ReplacePendingBuy` returns false; `Long_OnNewBar` doesn't retry until next bar). This can significantly reduce fill rate. Need flag. Same for Short. Also `Long_PlaceBuyLimit` can return 0 if price too close to market or API error; `Long_ReplacePendingBuy` cancels old order first, then attempts new. If new price violates min distance, it destroys the old resting order. Should place new before cancel or re-place on failure. This is a serious silent failure. In `Long_ReplacePendingBuy`, the order is canceled before validating new price? It calls `Long_PlaceBuyLimit` after cancel. `Long_PlaceBuyLimit` checks distance and returns 0 if too close. So if theoretical price moves too close to market, old order is canceled and no new order placed. This could be intended to avoid stale quote, but leaves no L0. Fill rate affected. Need mention.

32. In `Long_OnNewBar`, if `n==0` and `Long_ReplacePendingBuy` returns false due to deadband skip, it doesn't log a "skipped" event? It increments stat. okay. If returns false due to placement failure, no log unless InpVerboseLog and inside? `Long_ReplacePendingBuy` only returns bool; `Long_OnNewBar` logs only if true. If false due to placement failure, there is no warning. Silent. Same for Short. Need flag.

33. `V2_OrderSendCounted` not shown; maybe counts API calls. Not needed.

34. Telemetry schema:
- `V2EmitTelemetry` sends long and short payloads. If `EnableTelemetry` false, returns. Good.
- `V2BuildInstanceTelemetryPayload` arguments differ? In eurgbp and eurusd, same. okay.
- `V2EmitScalpClosed` parameters include `layer_depth`, `stack_depth`, `open_depth`. In exit fill, `stack_depth` computed before removal, `layer_depth = layer_idx+1`, `open_depth = g_long_layers[layer_idx].open_depth`. Good.
- But in `Long_HandleDealFill`, after exit fill, it calls `Long_RemoveLayerAt(layer_idx)`, then logs `layers=ArraySize(g_long_layers)`. The log says `layers=` after removal. It may be confusing but not bug.
- `V2PodAccumulateExit(g_long_pod, real_profit)` is called before removing; `real_profit` computed from deal and orig_pos. If `orig_pos` is 0, function may compute wrong. Unknown.
- `g_long_pod.layer0_entry` maybe set in AppendLayer. Good.

35. Rollover functions:
- `V2_BuildLongRolloverSlots` uses `V2_ResolvePositionTicket` (capital V2) but in eurgbp file, that function is not defined? It may be in logic.mqh. In eurgbp, they have `Long_ResolvePositionTicket` lowercase. The rollover function calls `V2_ResolvePositionTicket(g_long_layers[i].position_ticket)`, likely external. Fine.
- In `V2_ApplyLongRolloverSlots`, if slots array size smaller than layers, it updates only first n. If rollover pass modifies slots for positions that were closed meanwhile, could mismatch. Not enough.

36. `V2_RunRolloverRetryPasses` runs every tick, but `V2_RunRolloverRetryPass` likely has throttling. okay.

37. Potential issue in `OnInit` of eurgbp:
It calls `Long_OnInit()` and `Short_OnInit()` after printing. Then `V2_SyncAllCaps`. Then `GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0); GlobalVariableSet("V2EUR_CAP_TRIGGERS", 0.0);` This resets caps on every EA start, possibly if two EAs share global variables (EURUSD and GBPUSD separate EAs) it could reset another EA's cap triggers. In eurgbp, it sets both GBP and EUR cap triggers to 0, which might interfere with the other EURUSD/GBPUSD EAs running on same account. This is a cross-instance global variable collision. Need flag as silent failure/schema mismatch. The docs mention "No config, code, cap, geometry, position, commit, or VPS changes made." But code does GlobalVariableSet. If multiple EAs on same terminal/account, they share global variables. Resetting `V2EUR_CAP_TRIGGERS` in eurgbp on init could erase EURUSD's cap trigger count. But maybe global variable names are separated? In fxmatrix_v2.mq5 (GBPUSD) it sets `V2GBP_CAP_TRIGGERS`. EURUSD sets `V2EUR_CAP_TRIGGERS`. eurgbp sets both. That could be a problem. Need mention.
- Also `V2_AnyCapBlocksNewAdd` in eurgbp likely uses global variables? Not shown.
- In first `OnInit` of eurgbp after `V2_SyncAllCaps`, it calls `GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0)` and `V2EUR_CAP_TRIGGERS`. If `V2_SyncAllCaps` increments? Unknown.

38. In `fxmatrix_v2.mq5`, global var reset `V2GBP_CAP_TRIGGERS` on init. If multiple GBPUSD EAs? Only one. Fine. But eurgbp resetting both could be issue.

39. In `Long_EnsureAddNext` in fxmatrix_v2.mq5, if `g_long_add_ticket != 0 && OrderSelect(g_long_add_ticket)`, it returns, but doesn't verify the order is still of the add magic or if it's a stale ticket. If an add order fills, `OrderSelect` may still select it from history? `OrderSelect` selects active orders only? MQL5 `OrderSelect` selects an order from the list of current pending orders, not history? Actually `OrderSelect(ticket)` selects an order from current pending orders (by ticket). If filled, it may still be in history but not current, so `OrderSelect` returns false. If the order was filled and `Long_HandleDealFill` already cleared `g_long_add_ticket`, okay. If `Long_HandleDealFill` missed the deal, `g_long_add_ticket` remains non-zero, but `OrderSelect` false, so it proceeds to place another add. Could duplicate. This ties to missed deal issue.
- In `Short_EnsureAddNext`, same.

40. In `Long_OnNewBar`, if `n==0` and `g_long_l0_ticket` already non-zero and order is not filled but maybe stale, `Long_ReplacePendingBuy` cancels and replaces. If order filled, `g_long_l0_ticket` should have been cleared in HandleDealFill. If missed, it might cancel a filled order? Can't cancel filled order? `Long_CancelTicket` uses OrderSelect; filled order not current, so returns. Then places new L0 even though position exists? But `n` would be 0 if missed, so could double open. This is a risk from missed OnTradeTransaction. Need mention.

41. Need inspect `V2_ScanInstanceOrphanPositions` and `V2_ProcessOrphanStartupCheck` not shown. No.

42. Potential integer division in `V2_EffectiveSpreadMultiplier`: `(double)(opposite_depth - ease_depth_start)` okay.
43. Potential use of `MathMax(sig_ac, sig_bc)` where sig values are positive; okay.

44. Need check exact line references in docs? We can cite code.

45. Need decide format. Probably final answer should be an audit report with findings, severity, evidence. User wants exhaustive. We can structure:
- Summary
- Lookahead Bias
  - No direct future data found
  - Potential stale-bar/lookahead-adjacent issues
- Statistical Flaws
  - Sigma mismatch for EURGBP (max vs component/cross)
  - 3-point sigma proxy
  - InpQuoteSpread as floor underappreciated
  - Small sample in counts
  - Fair mid nomenclature
- Silent Failures
  - ReplacePending cancel-before-place
  - OnNewBar sets last_bar_time before compute success
  - OnTradeTransaction no retry/history scan
  - Wasted/duplicate open_depth after compaction
  - Cross-EA global variable reset
  - Missed deal can cause duplicate add
- Schema Mismatches
  - V2_MidNowFromSymbol returns close+half-spread instead of actual mid
  - V2_ComputeAbBidOffer diverges from production eurgbp formula
  - Dead code in helper
  - Magic literal inconsistency (maybe minor)
- Documentation/Statistical flaws in report
  - Conclusion "decisive input" not fully supported
  - Arithmetic mismatch for native sigma quote distance
- Recommendations.

Need be precise and not overclaim. We don't have logic.mqh, so some inferred. We can say "requires confirmation" for external functions. But user wants exhaustive. Maybe include "not audited due to missing files" for logic/exits/telemetry/cap includes? The codebase includes only some files; but they say full codebase? We only have docs and code snippets. We can note we are auditing provided code; includes in logic.mqh etc not available. But we can still infer.

Let's deeply examine each code snippet for other subtle bugs.

### Detailed code audit

#### fxmatrix_v2_signal.mqh

```
bool V2_FvSigmaFromCloses(const double &closes[], double &fv_out, double &sigma_out)
{
   if(ArraySize(closes) < 49) return false;
   double c6 = closes[6];
   double c12 = closes[12];
   double c48 = closes[48];
   if(c6 <= 0.0 || c12 <= 0.0 || c48 <= 0.0) return false;
   fv_out = 0.50*c6 + 0.30*c12 + 0.20*c48;
   double mean = (c6+c12+c48)/3.0;
   sigma_out = sqrt(((c6-mean)^2 + (c12-mean)^2 + (c48-mean)^2)/3.0);
   return (fv_out > 0.0);
}
```
This uses population variance /3, not sample /2. Is that intentional? "sigma" maybe population. No issue.
But c6/c12/c48 are not necessarily "6, 12, 48 bars ago" due to start_pos=1. Let's verify MQL5 CopyClose with series. Need be certain. Documentation: `CopyClose(symbol_name, timeframe, start_pos, count, close_array)` "Copies to the close_array the close prices of bars in the specified quantity from the chart, starting from the specified position. The elements order is from present to past." If `start_pos=1`, then element 0 is the close price of the bar with index 1 (the previous bar). If `ArraySetAsSeries` true, indexing is from present to past, so element 0 = previous bar. Thus `closes[6]` = bar 7. If they wanted "6", off by one. But maybe start_pos=0 would include current unclosed bar, causing lookahead; they start at 1 to avoid lookahead and don't care about one-bar offset. In documentation table, they call `closes[6]` "c6" but maybe just labels. The diagnostic report says "uses closes[6], closes[12], closes[48]" and "c6=closes[6]" no mention shift. Need flag as potential off-by-one if precise lag intended. Also `V2_CopyM5Closes` check `<49` ensures index 48 exists, but does not ensure `closes[48]` is not 0.

`V2_MidNowFromSymbol`:
```
double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
if(bid > 0.0 && ask > 0.0)
   return fallback_close + (ask - bid)/2.0;
return fallback_close;
```
This is definitely suspicious. Why not `(bid+ask)/2`? Maybe because in signal, `fallback_close` is the last closed M5 close, and current bid/ask are not used. The function name "MidNow" but returns close plus half spread. This is a schema mismatch. It also means if the symbol has a non-zero spread but price moved, the "mid" is wrong. In a backtest/offline context, maybe they only have close and spread; but in live terminal, bid/ask are available. Need flag high.

`V2_ComputeBcBid`:
```
double now = V2_MidNowFromSymbol(symbol, closes[0]);
double r = MathLog(now / fv);
double dynamic_hs = quote_spread + sigma * spread_multiplier;
bid_theoretical = fv * MathExp(r - dynamic_hs);
```
This simplifies to now*exp(-hs). It does not include passivity/live spread. This helper is not used by production? But if used in tests, inconsistency.

`V2_ComputeAbBidOffer`:
- Uses `MathMax(sig_ac, sig_bc) * spread_multiplier`.
- Does not include `effective_multiplier`, passivity, live spread.
- Computes `dynamic_hs` before ratio. okay.
- If `ab_symbol != _Symbol` no conversion. But if `_Symbol` is not EURGBP and `ab_symbol` is EURGBP, prices are still EURGBP terms, may be okay if called in backtester. But no validation.

`V2_L0DynamicHalfSpread`: `MathMax(quote_spread + sigma*effective_multiplier, live_spread_price + passivity_buffer_price)`. Good.

#### fxmatrix_v2.mq5 (GBPUSD)

Need examine `Long_ComputeBidSignal`:
- Uses `CopyClose(_Symbol, PERIOD_M5, 1, 60, closes)`. If returns exactly 49? It checks `<49`, okay.
- `closes[6]`, `[12]`, `[48]`.
- `bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); ask = ...; half = (ask-bid)/2; bc_now = closes[0] + half;` This is previous close + half current spread. Should be `(bid+ask)/2`. Because `closes[0]` is previous close; current mid is `(bid+ask)/2`. The current half spread added to previous close is not current mid. This is a bug. It likely originates from offline CSV where "close" is last price and "spread" is used to approximate mid. But in live, current bid/ask are available. High severity.
- `r_bc = MathLog(bc_now / fv)`. If bc_now <=0 check.
- `effective_multiplier` uses `InpEaseDepthStart`, etc.
- `live_spread_price = V2_L0ResolveLiveSpreadPrice(InpQuoteSpread);` This uses current `_Symbol` spread points. If SymbolInfoInteger returns 0, uses last valid static or fallback. okay.
- `dynamic_hs = max(quote_spread + sigma*mult, live_spread+passivity)`.
- `bid_theoretical = fv * exp(r_bc - dynamic_hs)`. Since fv*exp(r_bc)=bc_now, this is `bc_now * exp(-hs)`.
- If `InpVerboseLog && ArraySize(g_long_layers)==0 && ArraySize(g_short_layers)>InpEaseDepthStart` prints. okay.

`Long_Adr013ClampBuy`:
```
if (theoretical >= bid)
   out_price = Long_NormalizeSym(MathMin(theoretical, bid - min_dist));
else
   out_price = Long_NormalizeSym(theoretical);
return (MathAbs(out_price - theoretical) > _Point * 0.1);
```
If theoretical is above bid, clamp to bid-min_dist (sell side? For buy limit, cannot place above bid - min_dist; so clamp). If theoretical below bid, use it. Good.

`Long_PlaceBuyLimit`:
- Checks `if(price > bid - min_dist) return 0;` If price is too close to bid (i.e., above bid-min_dist), return 0. That means a buy limit must be at least min_dist below bid. If theoretical is equal to bid - min_dist, okay. If price is below, okay. Good.
- `req.type_filling = ORDER_FILLING_RETURN;` For pending order, filling type maybe irrelevant. okay.
- `req.type_time = ORDER_TIME_GTC;` good.

`Long_CancelTicket`:
```
if (ticket == 0) return;
if (!OrderSelect(ticket)) return;
MqlTradeRequest req={}; req.action=TRADE_ACTION_REMOVE; req.order=ticket; V2_OrderSendCounted(req,res);
```
If OrderSelect fails because order already filled/canceled, no action. Good. But if order is in history, not canceled. okay.

`Long_ReplacePendingBuy`:
- If resting within deadband, skip.
- Else cancel old, then place new. If placement fails, L0 ticket lost. This is silent. Need flag. Also if `Long_PlaceBuyLimit` returns 0 due to price too close, the old order was canceled unnecessarily. Could be intentional to move stop? But if price moves into no-zone, you want no order. But destroying old order without replacement means no L0 until next bar. Maybe okay if theoretical price now invalid. But if API failure transient, should retry.

`Long_ComputeAddTarget`:
- If `g_long_last_exit_valid`, anchor = last exit price, step = `V2_ADD_PIPS_FLOOR` (probably 9). This is reload after full exit? If a reload add is placed after a win, okay.
- Else anchor = last layer entry. If layers <3, step floor. Once >=3, uses widened `g_long_current_add_pips`.
- Returns `anchor - pips`. For long add downward. Good.
- `g_long_current_add_pips` initialized to floor in OnInit. After 3 layers, multiply by widen ratio each append. Good.

`Long_EnsureAddNext`:
- `if (n <=0 || n >= InpMaxLayers) return;`
- `if (g_long_add_ticket != 0 && OrderSelect(g_long_add_ticket)) return;` If ticket 0, no. If order filled, OrderSelect false, proceeds. Good.
- `if(!g_long_last_exit_valid && V2_GbpCapBlocksNewAdd(...)) return;` So if last exit valid (reload state after top layer exit), cap doesn't block reload? Maybe intentional.
- `g_long_add_ticket = Long_PlaceBuyLimit(add_price, 20260901, comment);` If placement fails, silently leaves 0. Next tick calls again because n>0 and add_ticket=0; but only within same OnNewBar? `Long_EnsureAddNext` is called at end of OnNewBar and also after AppendLayer/Remove. If placement fails due to price too close, it will retry every tick? `Long_OnTick` calls `Long_OnNewBar`, which returns early if same bar, so no. After a new bar, it will retry. okay.

`Long_OnNewBar`:
- Sets `g_long_last_bar_time = bar_time` before compute. If compute false, no retry. High-ish.
- If n==0, `g_long_last_exit_valid = false;` every new bar while flat. This resets reload state! After a winning exit that closed stack, `g_long_last_exit_valid` becomes true. If no new L0 fill yet, on next bar with n==0, it sets false. That means "reload" state only lasts within the same bar? Let's examine: A winning exit removes top layer leaving stack empty? Wait if stack becomes empty via exit fill, `Long_RemoveLayerAt` sets `g_long_last_exit_valid=true`. On next incoming L0 entry, `Long_HandleDealFill` checks `is_reload = g_long_last_exit_valid` at time of fill. But before fill, if a new bar occurs while flat, `Long_OnNewBar` sets `g_long_last_exit_valid = false;`. So if the L0 order fills after a new bar has started, the "reload" flag is lost, and the entry is classified as a new L0 rather than reload. This affects add placement and caps. Maybe intentional? Let's inspect:
```
int n = ArraySize(g_long_layers);
if (n == 0) {
   g_long_last_exit_valid = false;
   ...
}
```
So every new bar when flat resets last_exit_valid. The reload state is not persistent across bars. But `Long_RemoveLayerAt` sets last_exit_valid=true immediately when stack becomes flat, then if it's the same bar, `Long_EnsureAddNext` may place reload add? Wait `Long_RemoveLayerAt` when stack becomes 0 calls `Long_EnsureAddNext()`? In `Long_RemoveLayerAt`, after array resize, if ArraySize==0, `g_long_current_add_pips = InpAddPipsFloor; else if(was_top) Long_EnsureAddNext();` So no add when stack empty. It doesn't place reload L0. The L0 order is placed separately by `Long_OnNewBar` when flat. On the next new bar, `g_long_last_exit_valid` is reset false. So the `is_reload` flag in `Long_HandleDealFill` will always be false for L0 entries after a bar boundary? But if the L0 order was already resting before exit and fills within the same bar after stack became flat? Let's scenario: L0 order resting, position exits via take profit, stack empty, `last_exit_valid=true`. The L0 order (which may have been canceled/requoted?) Actually while positions existed, `Long_OnNewBar` did not update L0 order (since n>0). But the old L0 order from before entry may still be resting? When the L0 entry filled, `Long_HandleDealFill` sets `g_long_l0_ticket=0`; no new L0 order placed while position open. So after exit, there is no L0 resting. On next new bar, `Long_OnNewBar` computes new L0 and `Long_ReplacePendingBuy` places it. At that point `g_long_last_exit_valid` is set false at the start of `Long_OnNewBar` before placing. So the new L0 order comment is "V2_L0", and when it fills, `is_reload = g_long_last_exit_valid` will be false because reset on that bar. Therefore the `reload_flat=1` feature and `is_reload` logic never triggers? Wait if `Long_OnNewBar` sets `g_long_last_exit_valid=false` every flat bar, then after a win, the next L0 entry is not considered reload. But maybe `Long_ReplacePendingBuy` places order and if it fills in the same tick before `Long_OnNewBar`? No, order fills later. It will be after the same bar's processing but still the same bar, and `g_long_last_exit_valid` remains false because set false. So reload state is effectively meaningless. Could be a bug. However, maybe `g_long_last_exit_valid` is used only for add placement while positions exist; when stack flattens, it's reset intentionally to start fresh? But the `Long_AppendLayer` uses `is_reload` to classify stats/reload. If no reloads ever occur, stats wrong. Need flag as potential bug: "reload state is cleared at the start of every flat-bar processing before a new L0 order is placed; thus the `is_reload` path may be dead." This is important. Let's verify in code:
`Long_OnNewBar`:
```
int n = ArraySize(g_long_layers);
if (n == 0) {
   g_long_last_exit_valid = false;
   ...
   if(Long_ReplacePendingBuy(...)) ...
}
```
Yes. So `g_long_last_exit_valid` set false every bar when flat. If `Long_RemoveLayerAt` sets it true after exit, and the same bar no new L0 placement? Actually if position exit happens on a tick, `Long_HandleDealFill` -> `Long_RemoveLayerAt` -> sets true. But `Long_OnTick` calls `Long_OnNewBar` before `Long_AuditExitLimits` and before processing closeby? `OnTick` order in main: `Long_OnTick` -> `Long_OnNewBar`; `Long_AuditExitLimits`; `V2_ProcessCloseByQueue`. Deal fill triggers via OnTradeTransaction, which is separate from tick? In MT5, OnTradeTransaction called when trade transaction occurs, likely before next tick? It may be called during OrderSend processing. The exit limit fill is asynchronous; OnTradeTransaction fires, updates g_long_layers to empty and `last_exit_valid=true`. Later next tick, `Long_OnNewBar` runs. If new bar already happened between fill and next tick, it resets false. If same bar, it also resets false because flat. So yes, the flag is set false before any new L0 placement. Therefore `is_reload` in entry fill will be false. Unless `Long_PlaceExitForLayer` or `Long_RemoveLayerAt` calls `Long_EnsureAddNext` which could place a reload add before stack empty? No. So reload mechanism likely broken. This is a subtle but significant bug. Need include as "silent failure/dead code". But maybe they intend `g_long_last_exit_valid` to mean "the last exit was a winning exit and we should use reload spacing for the next add"; but if flat, it's irrelevant? They use it in `Long_ComputeAddTarget` and `Long_EnsureAddNext` while n>0. If n==0, no adds. For the next L0 entry, they use `is_reload = g_long_last_exit_valid` to decide whether L0 entry is a reload. Since they reset, no reload. The comment "reload_flat=1" in init suggests it should work. So this is a bug.

Wait maybe `Long_OnNewBar` resets `g_long_last_exit_valid=false` only when `n==0` to prevent a new L0 from being treated as a reload until after it fills? That seems to defeat reload. Need flag.

Similarly in eurgbp and eurusd? They have same pattern:
`Long_OnNewBar` in eurgbp:
```
int n = ArraySize(g_long_layers);
if (n == 0) {
   g_long_last_exit_valid = false;
   ...
}
```
So same bug in all EAs. The documentation says "reload_flat=1" feature. Need mention.

Let's think of intended behavior from comments: In `Long_AppendLayer`, `bool is_reload = g_long_last_exit_valid;` If last exit was profitable and stack is flat, an L0 entry after that should be a "reload" (perhaps means re-entering after a complete exit, not a new initial setup). They want to track reload stats and maybe use different add spacing. But they clear the flag on every flat bar. Could be they clear it only when a new L0 is *placed*, not when bar starts. The correct place to reset might be in `Long_ReplacePendingBuy` after placing new L0? Actually if you want the next L0 fill to be classified as reload, you should preserve `last_exit_valid=true` until fill, then set false after fill. But `Long_OnNewBar` sets false before placement. So yes bug.

However, maybe `g_long_last_exit_valid` is set false in `Long_OnNewBar` only when `n==0` and no prior L0 order? But it doesn't check. So definitely.

Need also check `Short_OnNewBar` same. Good.

This bug could affect cap logic: `Long_EnsureAddNext` checks `if(!g_long_last_exit_valid && V2_AnyCapBlocksNewAdd(...))`. If after exit flat and adding new L0, last_exit_valid false, caps can block? Actually caps block "new add" only when placing add orders, not L0. After L0 fills, `Long_AppendLayer` sets `is_reload` and calls `Long_EnsureAddNext`; if is_reload false, caps block adds. If true, caps don't block reload adds. So broken reload could cause caps to block what should be reload adds. Not major.

46. `Long_AuditExitLimits`:
- If `position_live` false and `exit_live` false, `V2_EvaluateExitAudit` likely returns something. It may recover exit order for a closed position? If position closed, `Long_SetExitTakeProfit` returns false because `position_ticket==0`. So it increments exit_place_fail repeatedly. Not major.
- If `exit_live` true but position_live false (position closed by other means), it leaves exit order? Wait if position closed due to stop loss, exit_ticket may still be live? A take-profit limit order attached to a closed position may be canceled by server? Maybe not. `Long_AuditExitLimits` sees position_live false, exit_live true, action? Unknown. Could leave orphan exit order. But not enough.

47. `Long_HandleDealFill`:
- For an exit fill, it looks for layer by `g_long_layers[i].exit_ticket == order_ticket`. If the exit limit order was replaced, `order_ticket` is the current exit ticket. If a stale exit ticket filled, no matching layer -> warning and return; but it still marks deal processed? Actually `Long_MarkDealProcessed` is called before the checks. So if an exit fill has no matching layer, it's marked processed and ignored, potentially leaving a hedge position open. This is a silent failure. It warns but doesn't queue CloseBy/remove layer. Could happen due to stale exit orders. Need flag.
- If an IN deal with wrong magic (e.g., magic=0) fills, ignored. The case study in docs had a non-V2 exit; not relevant.
- For an IN deal with `DEAL_ENTRY_IN` and `DEAL_TYPE_BUY` and magic==MM_LONG_V2, if it's an add order but `order_ticket` doesn't match `g_long_l0_ticket` or `g_long_add_ticket`, it still appends a layer. This is okay for manual? But could be an unexpected buy from another system; it will be treated as V2 layer if magic matches. Good.
- `if(order_ticket == g_long_l0_ticket) g_long_l0_ticket=0; if(order_ticket == g_long_add_ticket) g_long_add_ticket=0;` If an L0 order fills, and also equals g_long_add_ticket? impossible.
- `bool is_reload = g_long_last_exit_valid;` as discussed.

48. `Long_RemoveLayerAt`:
- If removing a non-top layer, it shifts layers but doesn't update `open_depth`. Already.
- `V2_CancelExitOrder(g_long_layers[layer_idx].exit_ticket);` If exit ticket was just filled, no active order. It calls with maybe 0? In exit fill flow, `exit_ticket` likely set to 0? Actually in `Long_HandleDealFill`, after exit fill, `g_long_layers[layer_idx].exit_ticket` still contains the filled order ticket. Then `Long_RemoveLayerAt` calls `V2_CancelExitOrder` on that ticket. If `V2_CancelExitOrder` handles filled orders gracefully, okay. If not, could error. But likely.
- When exit fill occurs, `position_id` from deal is the hedge position. `Long_RemoveLayerAt` calls `V2_CancelExitOrder` but not `Long_ClearExitTakeProfit`. Good.
- `g_long_stat_exits++` increments even if exit was from non-V2 magic? Only called in exit fill path where magic==MM_LONG_V2_EXIT. Good.

49. OnDeinit stats not reset? They print stats. okay.

#### fxmatrix_v2_eurusd.mq5

This is mostly identical but has deadband vol scaling. Need check `EurUsd_L0DeadbandSpreadRef`:
```
return InpL0DeadbandVolScale ? V2_PAIR_SPREAD_PIPS_REF : 0.0;
```
`V2_PAIR_SPREAD_PIPS_REF` defined 0.18. This is passed as `spread_ref` to `V2_L0RestingWithinDeadband`. If `spread_ref=0`, no scaling. But in `Long_ReplacePendingBuy`, it calls `V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult, EurUsd_L0DeadbandSpreadRef())`. If `InpL0DeadbandVolScale=false`, spread_ref=0. The function signature unknown. Could be okay.

Potential deadband unit mismatch: `EurUsd_L0DeadbandSpreadRef()` returns 0.18 (pips), while `InpQuoteSpread` is price 0.0004 (4 pips? Actually 0.0004 for EURUSD = 4 pips). The deadband function probably expects price? Need not.
Actually `V2_PAIR_SPREAD_PIPS_REF` for EURUSD 0.18, for EURGBP 0.63 commented but not used. In eurgbp, V2_PAIR_SPREAD_PIPS_REF=0.63 but deadband calls don't pass it. That's inconsistent: EURUSD scales deadband by its spread ref, EURGBP does not. The deadband in EURGBP uses only InpQuoteSpread=0.0004 (4 pips), not 0.63. Maybe a schema mismatch. But not core.

50. `fxmatrix_v2_eurusd.mq5` includes `fxmatrix_v2_eur_cap.mqh` and no `fxmatrix_v2_gbp_cap.mqh`. Good.

51. In eurgbp, `V2_PAIR_SPREAD_PIPS_REF 0.63` defined but not used? Search: In eurgbp code, `V2_PAIR_SPREAD_PIPS_REF` not used except maybe in includes? It doesn't appear in deadband calls. This is dead config. Could be intended for deadband but not implemented. Mention.

52. More on `V2_L0DynamicHalfSpread`:
For EURGBP, they pass `Long_PipsToPrice(InpPassivityBuffer)` (0.5 pips = 0.00005). For `InpQuoteSpread` 0.0004, live_spread_price maybe points*point. If raw spread 40 points * 0.00001 = 0.00040? Wait EURGBP spread in points? If point=0.00001, 0.4 pips = 4 points? Actually a pip = 0.0001 = 10 points. 0.4 pips = 4 points = 0.00004. SymbolInfoInteger SYMBOL_SPREAD returns "current spread in points" where point is smallest price increment. For 5-digit, 0.00001. So 4 points = 0.00004. Good.
Then `live_spread_price + passivity = 0.00004 + 0.00005 = 0.00009`. `quote_spread + sigma*mult = 0.0004 + 0.000327 = 0.000727`. So quote_spread 0.0004 is 4 pips? Wait 0.0004 / 0.0001 = 4 pips. Yes. So if they wanted quote_spread to be a floor of 0.4 pips, they'd set 0.00004. They set 0.0004 = 4 pips. This is a huge floor. Maybe `InpQuoteSpread` is in price units, not pips. V2_PAIR_SPREAD_PIPS_REF 0.63 suggests typical spread is 0.63 pips = 0.000063 price. InpQuoteSpread 0.0004 is 6.3x typical spread. This seems intentional? For GBPUSD, 0.0004 = 4 pips, while typical spread 0.3 pips, so also huge. So all EAs use a 4-pip floor, which is much larger than typical spread. This is a major cause of wide quotes. The docs mention "all three share same InpQuoteSpread" but not flag that it's 4 pips. It likely is 0.0004 because in MQL5 price, 0.0004 is 4 pips for 5-digit. Maybe they meant `InpQuoteSpread=0.0004` as 0.4 pips? Wait in finance, for EURUSD quote "spread 0.4 pips" = 0.00004. If they set input as 0.0004, that's 4 pips. The docs say "Passivity buffer conversion (EURGBP): Long_PipsToPrice(pips) = pips * _Point * 10.0 → 0.5 pips = 0.00005 price." So they know 0.5 pips = 0.00005. Then `InpQuoteSpread=0.0004` = 4 pips. But in docs, "InpQuoteSpread=0.0004" and "median CSV spread = 0.4 pips vs ..." They might think 0.0004 is 0.4 pips? Let's check: `_Point * 10.0` = 0.0001 per pip. 0.0004 / 0.0001 = 4. So yes. Did they perhaps use `_Point`=0.00001 and `Long_PipsToPrice` multiplies by 10, so 0.4 pips = 0.00004. The input is 0.0004. That corresponds to 4 pips. The docs table: "Median dynamic_hs GBPUSD 0.000708" = 7.08 pips. "Median quote distance 9.51 pips". If quote_spread were 0.4 pips, dynamic_hs would be ~0.7 pips not 7. So definitely `InpQuoteSpread` is 4 pips. This is a massive input. The docs' "Live spread floor: passivity buffer +0.5 pips binds the floor only ~0.8% of bars; InpQuoteSpread + σ·mult dominates" — they separate the first term. So yes.

Thus the fill rate issue may be largely due to `InpQuoteSpread=0.0004` (4 pips), not just sigma. The docs conclusion "not InpQuoteSpread" is misleading. As auditor, need highlight.

53. Need inspect `Long_PipsToPrice` in eurgbp: uses `_Point * 10.0` for 5-digit. If `_Point` = 0.00001, 1 pip = 0.0001. Good. For JPY pairs would need different, but not used.
`V2_PipsToPriceForSymbol` in signal.mqh handles digits 3/5 vs 2/4, but eurgbp uses Long_PipsToPrice fixed *10. Since EURGBP 5-digit, okay.

54. Potential "lookahead" in statistics/documentation: The diagnostic report says "Quote distance = fair mid minus bid quote, in pips." But in production formula, bid quote is `mid*exp(-hs)`, so "fair mid" is `ac_now/bc_now` or `bc_now`, which is not a fair value in the mean-reversion sense. It's current mid. The fair value terms cancel. This means the strategy is not actually trading deviations from fair value; it's just passive market-making at a fixed distance. If the intent is mean reversion, this is a conceptual flaw. Need mention.

Actually let's prove: `bid_theoretical = ratio * exp(inst_spread - hs) = (fv_ac/fv_bc)*exp(log(ac_now/fv_ac)-log(bc_now/fv_bc)-hs) = (fv_ac/fv_bc)*(ac_now/fv_ac)*(fv_bc/bc_now)*exp(-hs) = (ac_now/bc_now)*exp(-hs)`. Yes. So any deviation from fair value cancels. The order price tracks current mid exactly, not a target. This is not a "fair value signal"; it's a tight/wide passive quote. Therefore the entire "fair-value" calculation is irrelevant to the mid except for sigma. Is that intended? The code calls it "fair-value signal" but mathematically it's not. This is a major finding: **the fair value cancels out of the quote formula; no mean-reversion is expressed.** Let's see BC formula: `bid = fv * exp(log(bc_now/fv) - hs) = bc_now * exp(-hs)`. Yes. So no matter what fv is, bid is just current mid scaled by a constant-ish factor. The "signal" is essentially current mid, not fv deviation. That means the strategy cannot profit from reversion to fv; it only provides liquidity at a spread. The docs may know? The diagnostic report says "fair value" and "inst_spread" but not that it cancels. This is important.

However, if `dynamic_hs` depends on sigma and maybe `live_spread`, the distance varies. But the anchor is current mid. The fair value is not used as anchor. So the "signal" can be simplified. Is this a bug? In V1, maybe the signal was meant to be `ratio * exp(dynamic_hs?)`? Let's derive for a long bid in a mean-reversion pair: You want to buy when current cross is below fair value, i.e., `ratio * exp(inst_spread - hs)` = if inst_spread negative (current below fv), bid below ratio. But ratio*exp(inst_spread) = current cross, so the bid is always current cross * exp(-hs), regardless of inst_spread. Wait if inst_spread = log(ac_now/fv_ac) - log(bc_now/fv_bc), then ratio*exp(inst_spread) = ac_now/bc_now. Ah yes, because both use same "now" at same timestamp. The current cross mid is exactly ac_now/bc_now. So no reversion. If they wanted a reversion signal, they might use `fv_ac/fv_bc * exp(-hs)` not multiplied by exp(inst_spread)? Or `ratio * exp(-hs)`? But they multiply by exp(inst_spread), causing cancellation. Maybe intended formula was `ratio * exp(-dynamic_hs)`? Let's see: For AB pair, if EURUSD overvalued relative to GBPUSD, inst_spread >0, you want to sell EURGBP (offer high) and buy when inst_spread <0. The current cross is high/low. The half-spread should be added to `inst_spread`, not to current cross? Actually to quote bid = fair_mid * exp(-hs), where fair_mid = fv_ac/fv_bc, you'd need `ratio * exp(-hs)`. To quote offer = ratio * exp(+hs). But they use `ratio * exp(inst_spread ± hs)`, which makes the quote dependent on current cross, not fair. So maybe the bug is multiplying by exp(inst_spread). But `inst_spread` is by definition log(current_cross/fair_cross). So `ratio*exp(inst_spread)` = current_cross. If they intended to quote around fair value, they should not include `inst_spread`? Wait to express `current_cross = fair_cross * exp(inst_spread)`, so if you want bid = fair_cross * exp(-hs), you can also say bid = current_cross * exp(-inst_spread - hs). They use current_cross * exp(-hs), missing `-inst_spread`. So yes, the `inst_spread` term cancels instead of being preserved. The correct mean-reversion quote should be `ratio * exp(-dynamic_hs)` for bid (or `ratio * exp(inst_spread - dynamic_hs)`? Let's define fair = ratio. If instrument is mean-reverting to fair, you want to buy below fair by hs: bid = ratio * exp(-hs). If you also want to account for current deviation? No, the signal is that current price differs from fair; the limit order is at fair ± hs. But if you place at ratio*exp(-hs), it may be far from current price if current is above fair. That's the point. The code's use of `inst_spread` cancels the deviation, so the order is always near current price. This is a fundamental statistical/signal flaw. The documentation's Step 2 "quote distance = fair mid minus bid quote" maybe they compute fair mid as `ratio*exp(inst_spread)` = current cross, not fair value. They might be unaware of cancellation.

Let's check V1? The signal might be "dual-sigma AB-slot" from earlier systems. Maybe the intent was to quote around "theoretical mid" = current mid, not fair value? But they call it fair-value signal. The code comments in signal.mqh: "AB-slot: inst_spread = r_AC - r_BC, base = fv_AC / fv_BC. Matches V1 SLOT_AB + Python validation (score_EUR - score_GBP)." If V1's quote = ratio * exp(inst_spread - hs), then V1 also cancels. Maybe they intentionally use current mid as anchor because they are a market maker, and fair value only determines volatility/distance. But then why compute fv? Only sigma. That's plausible: the "signal" is current mid with a dynamic half-spread. The "fair value" is used to compute sigma but not anchor. The name is misleading but not necessarily a bug. Still, as an auditor, we should note that any claim of mean reversion to fair value is not supported by the formula; the quote is centered on the current cross rate, not on the fair-value ratio. This is a statistical/design flaw in the diagnosis.

Need see if `dynamic_hs` depends on `sigma` (curvature) and `inst_spread` is not used in half-spread. If `inst_spread` large, quote remains near current, not near fair. Thus it won't "buy dips" relative to fair; it just follows price. The fill rate analysis "quote distance vs realized movement" still applies, but not "fair value" mean reversion.

Could this be considered lookahead? No, but it's a design issue.

55. Potential issue in `V2_ComputeAbBidOffer`: If `ab_symbol` is different from `_Symbol`, no conversion. But the formula ratio*fv etc is already in cross terms. If `_Symbol` is not EURGBP, placing order on `_Symbol` would be wrong. But actual eurgbp EA runs on EURGBP. helper unused.

56. Need maybe mention "MQL5 `MathMax(sig_ac, sig_bc)` if both arrays have size 60 but any close zero? sig could be 0 if all three equal. dynamic_hs then quote_spread. okay.

57. Potential issue: In `V2_FvSigmaFromCloses`, `sigma_out` uses population standard deviation of three closing prices. If c6, c12, c48 are highly autocorrelated, sigma is not independent. It may be very small for cross. Already.

58. Need examine `V2_L0RestingWithinDeadband` calls in eurgbp:
```
if(V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult))
```
But `InpQuoteSpread` is 0.0004 (4 pips). Deadband width maybe 4 pips. If new price moves less than 4 pips from resting, skip replacing. That means L0 order can be up to 4 pips away from theoretical before it is requoted. This further increases quote distance/response lag. The docs say `InpL0DeadbandMult=1.0`; "1.0=V1 parity; 2.0/3.0=wider L0 skip band". So deadband is at least 4 pips. For EURGBP realized 1-bar range 1.4 pips, the quote may never be updated (deadband skip) because price movement within bar is less than 4 pips? Wait `Long_OnNewBar` computes new theoretical every M5 bar based on previous close. The theoretical changes by the close-to-close move plus sigma changes. If the change is less than deadband, the L0 order is not requoted. So the resting order stays at old price. This could be a major cause of low fill rate: quote lags by deadband > realized movement. The diagnostic report mentions "l0_deadband_skip" stats but doesn't include in conclusion. It says `InpL0DeadbandMult=1.0` ADR-017. It doesn't discuss deadband as cause. But if deadband is 4 pips and 1-bar range is 1.4 pips, many bars won't update quote, so quote distance can be even larger. This is a significant statistical flaw/silent behavior. Need mention. However, the deadband function is not provided, but we can infer from args. `InpQuoteSpread` is 0.0004; if function uses it as price threshold, deadband = 4 pips. For EURGBP, 1.4 pip range, so almost every new bar theoretical shift <4 pips, meaning L0 order is rarely requoted; after a big move it may update but with large lag. This could explain fill rate. The docs table l0_deadband_skip stats? It mentions `g_long_stat_l0_deadband_skip` in code but not in doc. Need flag.

But wait, maybe `V2_L0RestingWithinDeadband` uses `InpQuoteSpread` and `InpL0DeadbandMult` as a fraction of spread? Need no. In EURUSD, they added vol scaling `V2_PAIR_SPREAD_PIPS_REF` to scale band by 0.18 vs GBPUSD 0.64. So deadband is in pips relative to spread ref. The function likely computes `deadband = max(quote_spread, spread_ref * point?) * mult`? Not sure. But the input `InpL0DeadbandMult=1.0` suggests the deadband is proportional to `InpQuoteSpread`. If `InpQuoteSpread=0.0004`, deadband 0.0004. For EURUSD with spread ref 0.18, maybe deadband scaled down. EURGBP does not scale, so deadband remains 0.0004? That would be huge. The docs mention "EURGBP fill rate low" but not deadband. Maybe important.

Let's look at docs Step 1: "Shared: sigma, effective_multiplier, V2_L0DynamicHalfSpread". They don't mention deadband except `InpL0DeadbandMult`. "All three share same InpQuoteSpread, InpSpreadMultiplier, and InpPassivityBuffer." Differences: "Ease depth: EURUSD InpEaseDepthFull=4; EURGBP/GBPUSD use 3. Irrelevant at L0 when opposite side is empty." They don't mention deadband scaling. The EURUSD EA has `InpL0DeadbandVolScale` and `EurUsd_L0DeadbandSpreadRef`, while EURGBP/GBPUSD do not. So deadband differs. This could be a schema mismatch: EURUSD deadband is scaled to its spread ref, EURGBP not. Need flag.

59. Let's inspect `Long_ReplacePendingBuy` in eurgbp: same as production. Uses deadband with 4 args. If new price within deadband, it leaves old order. If old order was canceled/filled, `ticket_ref` may be 0 or stale; if stale and `OrderSelect`? The deadband function likely handles. Not enough.

60. More on `V2_L0ResolveLiveSpreadPrice`:
- Static variable `g_last_valid_spread_price` is function-local static in included mqh. If the same mqh is included in multiple EAs, each compiled EA has its own static. Fine.
- If `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` returns 0 during market closed, the function returns previous valid spread. If market closed, no ticks. okay.
- If symbol changes? The function is in each EA, so `_Symbol` fixed. okay.
- But if the first call occurs when spread is 0 (e.g., weekend), `g_last_valid_spread_price` remains -1, falls back to quote_spread 0.0004. okay.

61. Potential issue: `V2_ResolveLiveSpreadPriceFromRaw` receives `point` but if raw_spread_points >0, `live_spread_price = raw_spread_points * point`. For EURGBP, point=0.00001, raw spread 4 points => 0.00004. Good.
But `InpQuoteSpread` is 0.0004, 10x larger. So if live spread > 0.00035? Not often. The first term dominates.

62. Need maybe identify "schema mismatch" in docs vs code:
- The docs Step 1 says "Production inputs (identical across all three V2 EAs): InpQuoteSpread=0.0004, InpSpreadMultiplier=0.500, InpPassivityBuffer=0.5, InpSpreadMultiplierEased=0.0." But EURUSD has additional `InpL0DeadbandVolScale` input not in others. Also `InpEaseDepthFull` differs (4 vs 3). So "identical" is only partially true. The docs later notes ease depth difference. Fine.
- The docs says "EURUSD `InpEaseDepthFull=4`; EURGBP and GBPUSD use `3`." In code, EURUSD input indeed 4, GBPUSD 3, EURGBP 3. Good.
- The docs says "Ease depth irrelevant at L0 when opposite side is empty (typical fill attempt case)." But L0 fill attempts happen when own side empty; opposite side could be not empty. If own side empty and opposite side has layers, `effective_multiplier` depends on opposite depth. So ease depth is not always irrelevant. The docs' parenthetical "typical fill attempt case" maybe assumes opposite empty too? Not necessarily. Need mention.
- Actually when n==0 (own empty), `effective_multiplier` is computed based on opposite layers. If opposite depth >0, ease ramp applies. In diagnostics Step 2 "Assumed L0 empty stack (`effective_multiplier=0.5`)" means both own and opposite empty? They say `effective_multiplier=0.5` (no easing). But if opposite stack has depth, multiplier would be lower (eased), making dynamic_hs smaller and quote distance smaller. Fill attempts when opposite side has layers are more likely? Hmm. The diagnostic's offline reproduction assumes no opposite depth, which may overstate quote distance when opposite stack non-empty. But at L0, own empty, opposite could have depth. The docs say "Typical fill attempt case" opposite empty? If no positions at all, opposite empty. But if opposite side has positions, L0 quote is eased closer, increasing fill chance. So the median quote distance table may be biased by ignoring opposite depth. This is a statistical flaw in the diagnosis: it assumed empty stack for all bars, but actual L0 quotes may occur with opposite-side layers present, which would reduce distance. Need mention.
- However, if opposite side has layers, the system already has a position on opposite side, maybe L0 not "typical". Still.

63. Need check `Long_OnNewBar` and `Short_OnNewBar` interplay: Both can place L0 orders on opposite sides simultaneously if both stacks empty. The system can have buy and sell limit resting at same time. If both fill, positions hedge. Maybe okay. The ease multiplier for long depends on short layers; for short depends on long layers. At fresh start both empty, multiplier 0.5. Good.
- If short stack exists and long empty, long L0 quote eased (multiplier decreases). This means as opposite side grows, the empty-side L0 moves closer to mid, potentially filling and hedging. That's intended.
- The docs table assumes empty stack but "L0 empty stack" maybe means own empty, not opposite. It explicitly says "Assumed L0 empty stack (`effective_multiplier = 0.5`)" but if opposite empty too. okay.

64. More on AB signal: `Long_ComputeBidSignal` in eurgbp uses `MathMax(sig_ac, sig_bc)` for both bid and offer. If EURUSD sigma > GBPUSD sigma, the max is EURUSD. But the cross volatility is not max. Could also be that using max of leg sigmas makes dynamic_hs symmetric, whereas the cross vol might be asymmetric? No.

65. Potential "silent failure" in `V2_MidNowFromSymbol`: If bid/ask >0 but `fallback_close` is 0? It returns half spread. It doesn't check fallback_close >0. `V2_FvSigmaFromCloses` ensures closes[6] etc >0, but `closes[0]` could be 0? If previous close zero? Unlikely. In eurgbp, after `V2_CopyM5Closes`, `ac_closes[0]` could be 0 if market data missing, but `V2_FvSigmaFromCloses` only checks c6,c12,c48, not closes[0]. Then `ac_now = V2_MidNowFromSymbol(InpLegAC, ac_closes[0]);` If `ac_closes[0]=0` but bid/ask >0, it returns 0 + half spread = small positive, not 0. Then `MathLog(ac_now/fv_ac)` with fv>0 and ac_now positive (half spread) could be a large negative return, corrupting signal. This is a silent data-validation gap: should ensure closes[0] >0. In production BC code, it checks `bc_now = closes[0] + half; if(fv<=0.0 || bc_now<=0.0) return false;` Since half >0, bc_now >0 even if closes[0]=0. So a zero close could be masked. Need flag. In `V2_CopyM5Closes`, it doesn't validate every close. This could cause bad signals if history has zero values. Low probability but silent.

66. `V2_FvSigmaFromCloses` only checks c6/c12/c48 >0, not if the array has enough valid data (e.g., after 48 bars). Good.

67. Potential order of `ArraySetAsSeries` in `V2_CopyM5Closes` after `CopyClose`: In MQL5, if you set as-series after copy, the array's indexing changes, but the data is copied in the current indexing mode? Need know: If the array is not as-series before CopyClose, the copy fills "from present to past" in the array (i.e., element 0 is oldest? Actually by default arrays are as-series? In MQL5, time series arrays have indexing from present to past; ordinary arrays from past to present. `CopyClose` always copies "as is" into array starting from 0, but if array is timeseries, indexing 0 is present. The docs recommend calling ArraySetAsSeries before CopyClose. Here they call after. This is a critical MQL5 gotcha. Let's recall: In MQL5, to copy time series, you can either create a dynamic array and call ArraySetAsSeries(array, true) before CopyClose, or after? Example:
```
double price_array[];
ArraySetAsSeries(price_array, true);
int copied=CopyClose(_Symbol,_Period,0,100,price_array);
```
This is standard. If you call ArraySetAsSeries after CopyClose, the data values are not reordered; indexing changes from 0.. to last.. first. But the first element in the array's memory is the oldest or newest? Let's reason from MQL5 docs: `CopyClose` copies data into array "regardless of the array's AS_SERIES flag" maybe? Actually docs: "The data is copied so that the element with the index 0 in the array contains the oldest data, unless the array is a timeseries. If the array is a timeseries, the element with index 0 contains the newest data." No, if you set AS_SERIES after copying, the data may be interpreted reversed. Let's recall exact behavior: In MQL4, ArraySetAsSeries changes indexing order of existing time series arrays; values remain in same physical order but index changes. If you copy into a non-series array, element 0 is oldest. Then set series true, element 0 becomes newest? Actually ArraySetAsSeries changes the indexing direction but does not move data. So if data was stored oldest-first, setting series true would make index 0 the last element (newest) because array indexing from end? Hmm, MQL arrays are 0-based; "series" means indexing from present to past, so element 0 is present, element N-1 is oldest. If you copy into a non-series array with CopyClose, according to docs: "If the array is not a time series, the copied data is ordered from oldest to newest, i.e., index 0 is the oldest." Then if you call ArraySetAsSeries(true), the indexing is reversed logically: index 0 is the newest, which would be the last physical element. Does ArraySetAsSeries reorder memory? It probably does not; it just changes access mapping. So data may be wrong. Many MQL5 examples call ArraySetAsSeries before CopyClose. The code here calls after. This could be a serious bug. Need verify.

Let's be precise. MQL5 documentation for ArraySetAsSeries: "The function sets the AS_SERIES flag of the specified dynamic array. The flag determines the indexing direction of the array: if true, indexing of elements is performed from the end of the array to the beginning, i.e., the last element has index 0. If false, normal indexing from 0 to the last element." If you copy an array with CopyClose into a normal array, the copy is done according to the source time series? The `CopyClose` function has a parameter? No. The docs say: "If the array is a dynamic array, it will be resized to match the copied data. If the array is not a timeseries, the copied data will be arranged in the order of the time axis: the oldest data at index 0." Hmm, I think MQL5 `CopyClose` copies time series into arrays in chronological order? Let's check memory: In MQL5, the timeseries access functions always return data "from present to past" regardless of AS_SERIES? Actually the `CopyRates` documentation: "The elements are copied in order from the present to the past regardless of the AS_SERIES flag. To change the order, use ArraySetAsSeries." I need know.

From MQL5 docs: "When copying data from a timeseries, the elements are arranged in the array from present to past, i.e., the element with index 0 is the current one... If the AS_SERIES flag is not set, then the array indexing is performed in the usual way, from 0 to ... but the copied data may not be in chronological order. It is recommended to set the AS_SERIES flag before calling Copy functions." Let's find memory: I have used MQL5. Standard code:
```
double close_array[];
ArraySetAsSeries(close_array,true);
int copied=CopyClose(_Symbol,_Period,0,100,close_array);
for(int i=0;i<copied;i++) Print(close_array[i]);
```
This is from docs. They set series before. If you don't set before, the first element (index 0) is the oldest? Actually examples often use:
```
double prices[];
if(CopyClose(_Symbol, PERIOD_M5, 0, 10, prices) < 10) return;
ArraySetAsSeries(prices, true);
```
Does that work? I have seen both. Need determine.

Let's reason from MQL5's internal representation. `CopyClose` fills the array with time series data. If the array has AS_SERIES flag set, copy begins with the most recent bar at index 0. If not set, I think it still begins with the most recent bar at index 0, because the Copy functions always write in that order; AS_SERIES only affects how you should interpret indices? Wait no, AS_SERIES sets index 0 as the most recent. If not set, index 0 is the oldest? Let's check docs snippet:
"Timeseries and array indexing. Since in the timeseries the indexing is performed from the end to the beginning, the first element of the array is the last (current) element of the timeseries. When copying to a usual array, indexing is performed in the standard way: the first element of the array corresponds to the oldest period." Hmm.

Let's find a concrete memory: In MQL5, if you do:
```
double arr[];
CopyClose(_Symbol, PERIOD_M1, 0, 3, arr);
Print(arr[0], " ", arr[1], " ", arr[2]);
```
I believe arr[0] is the most recent close, arr[2] oldest, even without ArraySetAsSeries? Actually many people complain that without ArraySetAsSeries, arr[0] is the oldest? Let's recall from MetaTrader 5: The `CopyClose` function copies `count` elements starting from `start_pos`. "The array indexing is the same as the timeseries indexing, unless the AS_SERIES flag is set." That phrase means if AS_SERIES is true, indexing from present to past; if false, normal indexing from 0 upward, but the element at index 0 is the same as timeseries index start_pos (i.e., most recent). Wait "same as timeseries indexing" maybe means 0 = most recent. Actually in MQL5, timeseries arrays have AS_SERIES true by default? No, ordinary arrays false. Copy functions require an array; they copy elements in the order "starting from start_pos", so first copied element is the bar at start_pos. If start_pos=0, that's current bar. So arr[0] = current bar regardless of AS_SERIES. AS_SERIES only affects indexing for functions like iHigh? Hmm.

Let's look at MQL5 reference: "ArraySetAsSeries" description: "It is necessary to understand that when copying timeseries into an array, indexing of the copied data may not coincide with the indexing of the array. For example, after copying the last 10 elements of a timeseries into an array of 10 elements, the element with index 0 in the array will contain the oldest of the copied elements if the AS_SERIES flag is not set, and the newest if it is set." I recall this is true. For example, in MQL4, `CopyClose` fills array with oldest first if not series; then `ArraySetAsSeries` reverses indexing. In MQL5, many code samples:
```
double myarray[];
ArraySetAsSeries(myarray,true);
int copied=CopyBuffer(handle,0,0,100,myarray);
```
They set series before to get current at index 0. If you set after, you need to reverse? Actually `ArraySetAsSeries` sets flag but "doesn't change the physical order of elements; it only changes the order of indexing". If data copied with arr[0]=oldest, after setting series true, arr[0] would become the newest (which is physically last). So it would be correct! Wait if arr[0] initially oldest, setting series true maps index 0 to the last physical element (newest), so arr[0] becomes newest. So calling after would also work, because the flag changes indexing of existing data. Is that true? If the flag simply reinterprets indices, then yes. If data was oldest-first, setting series true makes index 0 point to the physical last element (newest). So either method can work if you set before? Let's think: If you set series true before CopyClose, the copy function writes data according to the timeseries order: index 0 gets newest, index 1 next, etc. If you set after, the physical array was filled oldest-first, index 0 physical oldest; setting series true makes logical index 0 = physical last (newest). So both yield same logical arr[0]=newest. Thus calling after is okay. But is the physical array filled oldest-first when not series? I think yes. So both are okay. Actually if CopyClose always fills oldest-first regardless of flag, then setting before doesn't change physical order? Let's settle: The physical order after CopyClose into a non-series array is oldest at index 0. If you set series true after, logical index 0 = oldest or newest? `ArraySetAsSeries` "changes the indexing direction", so logical index 0 should be the most recent, which is at the physical end. So yes, after setting works. Many examples set before to avoid confusion, but after should work. Need not flag as bug without certainty. But if physical order is newest-first, then setting after would make index 0 = oldest, wrong. Which is it? Let's search memory: MQL5 documentation for CopyClose: "Note that when CopyClose() copies data into an array that is not a timeseries, the data is copied in chronological order (from the past to the present), i.e., the oldest data at index 0." I think this is true. Example:
```
double close[];
CopyClose(_Symbol, PERIOD_H1, 0, 10, close);
// close[0] - the most recent? 
```
I have seen code that does `ArraySetAsSeries(price, true);` after copy? In MQL5, the common pattern from official docs is to create array, then call ArraySetAsSeries(array, true) before CopyClose. They don't rely on after. There are many forum threads: "Why do I need ArraySetAsSeries before CopyClose?" It is recommended before. If you call after, the data order is wrong because CopyClose copies data from present to past regardless, so arr[0] is most recent; then setting AS_SERIES makes arr[0] the most recent? Wait if arr[0] already most recent and you set AS_SERIES true, index 0 remains most recent. If CopyClose always copies present-to-past, then setting before/after doesn't change arr[0] (still present). Actually if AS_SERIES true, indexing is present-to-past; if false, indexing is normal 0,1,2 but data is still present-to-past. The flag only tells functions like ArrayMaximum whether index 0 is present or not. It doesn't move data. If data is present-to-past, arr[0]=present regardless of flag. So setting after is fine. Hmm.

Let's check actual MQL5: The timeseries array is a concept of an array with AS_SERIES. "The AS_SERIES flag in the array means that the array is indexed like a timeseries, i.e., the most recent data has the smallest index." If the flag is absent, indexing is standard (oldest first). But the physical data after CopyClose may be in either order depending on the flag at copy time? The CopyClose function probably fills the array according to the array's AS_SERIES flag. If flag not set, it fills oldest first. If flag set, newest first. If you set after, the physical data was oldest-first, then flag changes logical indexing to newest-first; as a result logical arr[0]=newest. So it works. If the CopyClose ignores flag and always fills newest-first, setting after leaves arr[0]=newest and flag true, also works. So no issue in either case? Wait if CopyClose always fills newest-first regardless and then set series false, arr[0]=newest but flag false means normal indexing but data still newest-first, so arr[0] is still newest. The flag just tells other functions. So no issue. The only risk is if you assume index 0 is oldest when flag false but data is newest-first, weird. But code uses series true. So likely okay. Not flag.

68. Potential issue in `V2_CopyM5Closes`: It copies 60 closes but only uses indices 0,6,12,48. If market data less than 60 due to weekend, returns false. okay.

69. Need think about "lookahead bias" more: The dynamic half-spread uses `sigma` from historical closes, and quote placed at new bar after those closes are known. No future data. The `live_spread_price` is current spread at placement. No lookahead. The offline diagnosis uses current bar's M5 range (future) to evaluate fillability, but that's analysis, not trading. So final likely "no direct lookahead found" but mention stale bar and off-by-one.

70. Potential silent failure in `V2_L0DynamicHalfSpread`: If `live_spread_price` becomes stale from previous valid spread, and current actual spread is much wider, the order may be placed too close and fill at bad price. Since `V2_L0ResolveLiveSpreadPrice` retains last valid, if spread data missing during high volatility maybe stale. But SYMBOL_SPREAD should be updated. Low.

71. More on stats: In docs Step 3, "position 499807332 (the 'unresolved' scalp): M5 price path best low 0.84874 — past the exit target (243% of exit distance)." This shows the price did reach exit zone, so L0 fill was not issue. But the exit target was 0.84917, best low 0.84874, so yes. However, if the exit limit order was placed at 0.84917, price would have to trade at that price. Best low below target means it traded through. Why didn't exit fill? They close by non-V2 exit at 0.84951. This indicates exit limit order wasn't live or was canceled. The report says "exit resolution, not quote distance." Good.

72. Need maybe mention "lookahead bias" in case study? It uses full M5 path from 14:00 to next day to claim L0 did fill. If evaluating whether L0 would fill, using future path is okay because the order was already resting; not lookahead in trading, but in diagnosis.

73. Need inspect `Long_RemoveLayerAt` and `g_long_last_exit_valid` reset issue deeper. Let's verify if `Long_OnNewBar` setting false when flat could be intentional to initialize state before placing L0. But `is_reload` is used to determine if the L0 entry is a "reload" (i.e., re-entry after full exit) to perhaps avoid cap block. If they always reset, then the `reload_flat=1` feature only applies to adds while stack is still open? Let's trace:
Scenario: Long stack has 2 layers. Top layer exits, stack becomes 1 layer. `Long_RemoveLayerAt` with was_top=true sets `g_long_last_exit_valid=true`. Then because stack not empty, it calls `Long_EnsureAddNext()`. In `Long_EnsureAddNext`, if `!g_long_last_exit_valid && cap...` -> since true, cap doesn't block. It computes add price based on `g_long_last_exit_price` (the top layer's entry) rather than last layer entry. This is the reload/add behavior for remaining stack. So `g_long_last_exit_valid` is meant to persist while stack remains open after a partial top exit. When stack becomes fully flat, `Long_OnNewBar` resets it, so the next L0 is not a reload. Maybe "reload" means adding a new layer after a partial exit, not re-entering after full exit. The `Long_AppendLayer` uses `is_reload = g_long_last_exit_valid` for any new entry, including add orders? Wait `Long_AppendLayer` is called for every IN deal, not just L0. `is_reload` is true if last_exit_valid at the time an add fills. So if a top layer exits and stack remains, then an add order placed by `Long_EnsureAddNext` fills; `is_reload=true` for that add. That makes sense. If the stack becomes empty and then a new L0 fills, `last_exit_valid` might have been reset by OnNewBar; so it's not a reload. But if the L0 order was already resting before stack emptied? It wouldn't exist because L0 orders are not placed while n>0. So no. Thus "reload_flat" may be misnamed; it's about add after partial exit, not flat re-entry. The `Long_OnNewBar` reset when flat is correct to avoid treating a fresh start after complete exit as reload. So maybe not a bug. But the code comment in `Long_OnInit` says "reload_flat=1" maybe "reload flat" means after full exit? Hard to know. We can mention as potential ambiguity not definitive.

74. Potential issue: `Long_HandleDealFill` for an add fill with `is_reload = g_long_last_exit_valid` after a full exit? If stack empty, `g_long_last_exit_valid` was set false by OnNewBar. So `is_reload=false`. But if `Long_RemoveLayerAt` made stack empty and then before next OnNewBar, an L0 order? No L0 order exists. So no.

75. Need maybe audit `Long_ComputeAddTarget` for reload after partial exit:
If `g_long_last_exit_valid` true and stack not empty, anchor = last exit price (the top layer that just exited), step = `V2_ADD_PIPS_FLOOR`. So a new add is placed at last exit price - 9 pips. If the stack currently has remaining layers, this is a "reload" to replace the exited top layer. If `V2_ADD_PIPS_FLOOR` maybe 9 pips, okay. If `g_long_last_exit_valid` false, anchor = last layer entry. Good.
If `Long_AppendLayer` is called for a reload add and `is_reload=true`, it sets `g_long_last_exit_valid=false` after appending:
```
if (is_reload)
   g_long_last_exit_valid = false;
```
So reload flag resets after using it. Good.
Thus reload logic works for adds. Not a bug.

76. Potential issue in `Long_RemoveLayerAt` when `was_top` and stack becomes empty: It sets `g_long_last_exit_valid=true`; then `V2_OnOwnStackFlat(g_long_last_exit_valid, ArraySize(g_long_layers));` with size 0. Could trigger something. Then `g_long_current_add_pips = InpAddPipsFloor` if size 0. But it does not set `g_long_last_exit_valid=false` when stack empty. So if an L0 fill occurs before next OnNewBar? Is that possible? The L0 order may have been placed and filled? But L0 orders are not placed while stack non-empty. After stack empties, there is no L0 order, so cannot fill before next OnNewBar. Unless a manual order. So no.

77. Need maybe mention "Long_OnNewBar sets `g_long_last_exit_valid=false` when n==0, which means if an L0 order from before the position was opened is still resting and fills after exit? Wait earlier we said L0 ticket is set to 0 when entry fills. What if an L0 order was never the one that filled? There can be only one L0 per side. When entry fills, `g_long_l0_ticket=0`. So no.
Thus okay.

78. Potential issue with `V2_OnOwnStackFlat` not shown. no.

79. Need perhaps provide "recommendations" not just findings. The user asks audit. We'll produce.

Need decide severity levels. Use High/Medium/Low.

Let's list findings with evidence.

### Finding 1: Fair-value cancellation in signal formula
- In `fxmatrix_v2.mq5` Long_ComputeBidSignal: `bid_theoretical = fv * MathExp(r_bc - dynamic_hs)` = `bc_now * exp(-dynamic_hs)` because `fv*exp(r_bc)=bc_now`. Same for eurgbp: `ratio * MathExp(inst_spread - dynamic_hs)` = `ac_now/bc_now * exp(-dynamic_hs)`.
- Thus the fair value (`fv`, `ratio`) cancels; the quote is always anchored to current mid, not a fair-value target. Any `inst_spread` deviation from fair value is removed. This means the strategy is not mean-reverting to fair value; it only places a passive limit order a fixed distance behind current price.
- Docs refer to "fair mid" and "fair value" but the quoted price is not based on fair value. Statistical interpretation of fill rates and signal efficacy is flawed.
- Severity: High (design/signal logic).

Need be careful: Maybe they intentionally want current mid anchor. But then "fair-value signal" is a misnomer. We can state "If the intended strategy is mean reversion to FV, this is a bug; if it is deliberate market-making, documentation should say so." Good.

### Finding 2: Sigma for EURGBP is not the cross-asset volatility
- `V2_ComputeAbBidOffer` and eurgbp use `MathMax(sig_ac, sig_bc)`.
- Correct cross volatility of EURGBP (if legs are EURUSD, GBPUSD) is sqrt(sig_ac^2 + sig_bc^2 - 2 rho sig_ac sig_bc), not max. Max overstates by ~3.7x per docs (0.000655 vs native 0.000176). This causes dynamic_hs too wide and lower fill rate.
- Also `MathMax` discards the smaller sigma entirely; a simple RMS would be more defensible.
- Severity: High (statistical/risk).

### Finding 3: `V2_MidNowFromSymbol` does not return current mid
- Code:
```
if(bid>0 && ask>0)
   return fallback_close + (ask-bid)/2.0;
return fallback_close;
```
- It should return `(bid+ask)/2` if current mid is desired. Instead it uses the last closed bar close + current half-spread. This can be materially stale after a bar gap or within-bar move.
- This affects both AB legs and the BC helper. In `fxmatrix_v2.mq5` inline, `bc_now = closes[0] + half` same issue.
- Because L0 orders are only placed on new bars, the stale value may be acceptable at the exact bar open, but not if first tick is delayed; and the helper can be called at any time.
- Severity: High/Medium (silent signal stale). We'll assign Medium-High.

### Finding 4: L0 replacement cancels before placement, can silently remove resting order
- `Long_ReplacePendingBuy` (and Short) cancels existing order then calls `Long_PlaceBuyLimit`. If new price is within minimum stop distance or API request fails, `PlaceBuyLimit` returns 0 and the old order is gone.
- There is no retry until the next M5 bar (because `OnNewBar` returns if same bar). No warning is logged on failure in this path.
- This can reduce fill rate and leave the side unquoted.
- Severity: High (silent failure).
- Recommendation: validate/place new order before cancel, or restore old order on failure.

### Finding 5: `OnNewBar` marks bar processed before signal success
- `Long_OnNewBar`/`Short_OnNewBar` set `g_long_last_bar_time = bar_time` before `Long_ComputeBidSignal`. If `CopyClose`/history fails once, the function returns and the bar is never retried, leaving stale L0 order until next bar.
- Severity: Medium (silent failure).
- Recommendation: set last_bar_time after successful signal computation, or retry on next tick.

### Finding 6: `OnTradeTransaction` has no retry/history reconciliation
- If `HistoryDealSelect` or deal fetch fails transiently when `OnTradeTransaction` fires, the deal is not processed and no periodic scan will recover it. This can leave a live position untracked, or an add ticket non-zero, leading to duplicate add orders or lost exit handling.
- Severity: High (silent failure under transient failure). Need maybe medium.
- Evidence: `Long_HandleDealFill` returns if `HistoryDealSelect` fails; `Long_MarkDealProcessed` not called, but no retry mechanism.
- Recommendation: add a startup/periodic reconciliation of deals by magic within recent window, and retry on next tick.

### Finding 7: `InpQuoteSpread` is 4 pips and dominates `dynamic_hs`; docs understate it
- `InpQuoteSpread=0.0004` = 4 pips at 5-digit pairs (using `pips = price/(_Point*10)`). For EURGBP median 1-bar range 1.4 pips, 4 pips is already ~2.9x the 1-bar range.
- In docs, "decisive input is MathMax, not InpQuoteSpread" is misleading: `InpQuoteSpread` contributes ~55% of dynamic_hs before sigma change and ~82% after switching to native sigma.
- The passivity buffer is not the term being discussed; `InpQuoteSpread` is the main floor term, not a binding alternative floor.
- Severity: Medium (statistical interpretation/performance).
- Recommendation: re-evaluate `InpQuoteSpread` for each pair; it should be in pips, not a constant price for all pairs, if fill-rate parity is desired.

### Finding 8: Deadband behavior is not accounted for in diagnosis and differs across EAs
- `Long_ReplacePendingBuy` skips requoting if the new target is within `InpQuoteSpread * InpL0DeadbandMult` (?) of the resting order. With `InpQuoteSpread=0.0004` and `InpL0DeadbandMult=1.0`, the deadband is 4 pips — larger than EURGBP's median 1-bar range (1.4 pips). So in many bars the L0 order is not updated at all, adding further lag.
- EURUSD has `InpL0DeadbandVolScale` and passes `EurUsd_L0DeadbandSpreadRef()`, while EURGBP/GBPUSD use the unscaled 4-arg call. The docs don't mention this difference.
- Severity: Medium (silent behavior/statistical omission).
- Recommendation: include deadband-skip stats and requote frequency in the diagnosis; confirm deadband units.

### Finding 9: `V2_ComputeAbBidOffer` helper diverges from production eurgbp formula
- Signal.mqh contains `V2_ComputeAbBidOffer` with `dynamic_hs = quote_spread + MathMax(sig_ac, sig_bc)*spread_multiplier` and no passivity/live-spread/multiplier easing. The actual eurgbp uses `V2_L0DynamicHalfSpread` with effective multiplier, live spread, passivity buffer.
- Any code path that uses the helper (or tests/backtests) will produce different quotes than production.
- The `ab_symbol` sanity-check block is a no-op.
- Severity: Medium (schema mismatch/maintenance).

### Finding 10: `V2_FvSigmaFromCloses` uses a 3-point level dispersion, not a return volatility, and uses hard-coded lags with an off-by-one relative to the naming
- `sigma` is population std dev of three closing prices, not standard deviation of returns. It is a weak proxy and likely not comparable to realized M5 range.
- `CopyClose(...,1,60)` means `closes[6]` is bar 7, `closes[12]` bar 13, `closes[48]` bar 49 relative to current bar (if MQL5 series indexing is as expected). The labels `c6/c12/c48` imply a 1-bar offset. No lookahead, but it may not be the intended lag structure.
- Severity: Low-Medium (statistical robustness).

### Finding 11: No direct lookahead bias found, but the analysis is vulnerable to stale-bar artifacts
- All signal inputs are from closed bars (`start_pos=1`) and current spread. No future data is used in order generation.
- However, because quotes are only recalculated on new M5 bars and use previous close + current half spread, a large move in the first ticks of the bar can leave the theoretical quote far from the actual market; orders may be rejected or fill stale.
- This is not lookahead but is an execution latency/quality issue.
- Severity: Medium.

### Finding 12: Small sample / diagnostic limitations
- Step 4 EURGBP exit count n=6; median time between exits (~31.6 hr) is not statistically robust.
- Step 2 offline reproduction "assumed L0 empty stack" ignores cases where opposite layers are present and `effective_multiplier` would be eased, making quotes closer. This may overstate the median quote distance for actual L0 attempts.
- Docs' "quote distance = fair mid minus bid" actually uses current mid (because FV cancels), not a true fair value.
- Severity: Low (diagnostic quality).

### Finding 13: Cross-EA global variable overwrite
- `fxmatrix_v2_eurgbp.mq5` `OnInit` executes `GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0); GlobalVariableSet("V2EUR_CAP_TRIGGERS", 0.0);`. If EURUSD and GBPUSD EAs are running on the same terminal/account, this resets their cap counters. Could allow unintended adds or lose cap state.
- Severity: Medium (if multi-EA deployment).

### Finding 14: `open_depth` is not updated after layer compaction
- `Long_RemoveLayerAt` shifts layers but does not rewrite `open_depth`. After a non-top layer exits, a deeper layer with `open_depth=1` shifts to index 0, and a subsequently appended layer gets `open_depth=1` as well. Telemetry and audit metrics can contain duplicate depths.
- This is a data schema/integrity issue.
- Severity: Low.

### Finding 15: `V2_L0ResolveLiveSpreadPrice` uses a static last-valid value with no timestamp
- If the market spread changes to 0 or is not reported on a tick, the previous spread is reused indefinitely. The fallback can be stale across a weekend or after a symbol change.
- Not major.

### Finding 16: `V2_L0DynamicHalfSpread` uses `MathMax` of sigma and buffer, but quote_spread is a hard price floor of 4 pips; local EA logs don't include `sig_ac/sig_bc` for EURGBP? Actually eurgbp DIAG log prints them when opposite_depth > ease_depth_start. The docs say logs contain almost no DIAG lines. Not code issue.

Need prioritize. The final answer should be an audit report. We can present findings in a table then details.

Need ensure not too long but exhaustive. Desired oververbosity 5. User said be exhaustive, so long answer okay. But we shouldn't include every minor speculation. We'll include all substantial findings with code evidence.

Need maybe mention "lookahead bias: none found in quote generation" explicitly early to satisfy.

Let's craft final answer with sections:

- Audit scope & method
- Summary of critical findings
- Lookahead bias assessment
- Statistical flaws
- Silent failure modes
- Schema/design mismatches
- Documentation issues
- Recommendations
- Appendix: line references? We can cite file/function.

Need maybe use `Severity` column. We'll write in prose.

Let's be precise with code snippets.

Let's formulate Finding 1 in detail:

In `fxmatrix_v2_signal.mqh`:
```
bid_theoretical = ratio * MathExp(inst_spread - dynamic_hs);
```
where `ratio = fv_ac/fv_bc`, `inst_spread = log(ac_now/fv_ac) - log(bc_now/fv_bc)`.
Then:
`ratio * exp(inst_spread) = (fv_ac/fv_bc) * exp(log(ac_now/fv_ac) - log(bc_now/fv_bc)) = ac_now/bc_now`.
So `bid_theoretical = (ac_now/bc_now) * exp(-dynamic_hs)`.
For BC:
`fv * exp(log(bc_now/fv) - hs) = bc_now * exp(-hs)`.
Thus the "fair value" cancels. If the system is intended to be mean-reverting to FV, the `inst_spread` should move the quote relative to current mid, not cancel. The current formula is equivalent to a passive market-maker centered at spot. The diagnosis "fair mid minus bid" is actually "spot minus bid".

Need perhaps mention this could be intentional (market-making). But docs call it fair-value signal; if intentional, docs false.

Finding 2 details:
The docs already note median native EURGBP σ 0.000176 vs max 0.000655. Correct cross-vol formula. Use `MathMax` can be conservative but not accurate. Also `V2_ComputeAbBidOffer` uses max without cross-correlation. This causes half-spread 3.7x. Fill rate lower. This is likely primary.

Finding 3 details:
In `fxmatrix_v2.mq5`:
```
double half = (ask - bid)/2.0;
double bc_now = closes[0] + half;
```
In signal.mqh:
```
if(bid > 0.0 && ask > 0.0)
   return fallback_close + (ask - bid)/2.0;
```
If `closes[0]` is previous M5 close, at a new tick after price moved, this is not current mid. Should be `(bid+ask)/2.0`. This can make quotes stale and cause placement failures. It also means the "current" leg mid in AB is not current.

Finding 4 details:
In `Long_ReplacePendingBuy`:
```
Long_CancelTicket(ticket_ref);
ticket_ref = Long_PlaceBuyLimit(price, magic, comment);
if(ticket_ref > 0) ...
return false;
```
If placement fails, the old order is gone. Similar in Short. Add logging/retry. This is a silent failure not mentioned in docs.

Finding 5 details:
In `Long_OnNewBar`:
```
datetime bar_time = iTime(_Symbol, PERIOD_M5, 0);
if (bar_time == g_long_last_bar_time) return;
g_long_last_bar_time = bar_time;
double bid_theoretical;
if (!Long_ComputeBidSignal(bid_theoretical)) return;
```
If compute fails, no retry until next bar. Same for short.

Finding 6 details:
`OnTradeTransaction` only handles `DEAL_ADD`; if `HistoryDealSelect` fails, no retry. Need add deal reconciliation.

Finding 7 details:
Compute pips:
`pips = price/(_Point*10)` for 5-digit; for 0.0004 = 4 pips. The docs' `InpQuoteSpread` is 4 pips. In original `dynamic_hs`, 4 pips + sigma contribution. For EURGBP, 4 pips alone is ~2.9x median one-bar range. So not a minor floor. The conclusion "not InpQuoteSpread" is unsupported.

Finding 8 details:
Deadband skip:
`Long_ReplacePendingBuy` returns false if `V2_L0RestingWithinDeadband(...)`. With `InpQuoteSpread=0.0004` and mult=1, deadband likely 4 pips. Since EURGBP 1-bar range 1.4 pips, many bar-to-bar theoretical changes won't requote. The docs' Step 2 didn't include deadband simulation. EURUSD has `InpL0DeadbandVolScale`, EURGBP doesn't.

Finding 9 details:
signal.mqh helper vs EA.

Finding 10 details:
3-point sigma and off-by-one.

Finding 11 no lookahead.

Finding 12 small samples etc.

Finding 13 global variable overwrite.

Finding 14 open_depth.

Maybe mention "No direct lookahead bias" in summary.

Need maybe include "Schema mismatch: `MM_LONG_V2` literal vs macro" but low. We can include as minor.

Let's also mention "manual/offline reproduction uses `SPREAD` from CSV points × 0.00001, but production uses `SymbolInfoInteger(SYMBOL_SPREAD) * _Point`. If `_Point` for EURGBP is 0.00001, okay. If CSV SPREAD is in pips not points, off by 10. Need confirm schema." The docs say "SPREAD column (points × 0.00001)" so okay. Not necessary.

Potential issue in `V2_L0ResolveLiveSpreadPrice`: It uses `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` which can return a value already in points. If the spread is 0.4 pips, raw=4. 4*0.00001=0.00004. Good. `InpQuoteSpread` 0.0004 is 40 points? Wait 0.0004 / 0.00001 = 40 points = 4 pips. Good.

Let's verify pips: For 5-digit, 1 pip = 0.0001 = 10 points. 0.0004 = 4 pips. Yes.

Need maybe mention "InpAddPipsFloor=9.0 pips, InpExitPips=3.0 pips" etc. Not relevant.

Let's think if "lookahead bias" could be hidden in `V2_ComputeAbBidOffer` because `ac_now` and `bc_now` use current bid/ask? It doesn't; it uses fallback close. So no.

Could `CopyClose` with shift 1 include a bar that is still forming due to start_pos=1? No, shift 1 is closed. No lookahead.

Could `iTime(_Symbol, PERIOD_M5, 0)` and `CopyClose(...,1,...)` at the first tick of new bar use the bar that just closed; okay.

Need mention "No direct lookahead bias found" but "the 1-bar offset in CopyClose means the signal is one bar old; if backtests shifted incorrectly, could appear as lookahead? Actually if production uses shift 1, it's safe. But if validation compares to closes[6] etc with shift 0, schema mismatch."

Let's perhaps include a "Lookahead bias" section:
- Low risk: quote generation uses only closed bars; no future data.
- Medium risk: `V2_MidNowFromSymbol` mixes current spread with previous close; not lookahead, but timestamp mismatch.
- Off-by-one in lag labels may cause offline/backtest to use different bars than production.

Need maybe mention "statistical flaws in documentation":
- The report's "Quote distance / 1-bar range ratio 4.52×" uses future realized range to say quote unreachable. But if quote was computed from previous close, comparing to future range is a fair out-of-sample fill proxy, not lookahead. okay.
- "Median sigma (price)" for EURGBP native 0.000176, max-leg 0.000655. This is not a "sigma" in returns. Already.

Let's ensure final answer doesn't say "I don't have logic.mqh" too much. We can say "Cannot audit external includes; findings based on provided files." Good.

Let's maybe include code line references approximate:
- `fxmatrix_v2_signal.mqh`: V2_MidNowFromSymbol lines 40-51; V2_ComputeAbBidOffer lines 103-150; V2_FvSigmaFromCloses lines 10-29.
- `fxmatrix_v2_eurgbp.mq5`: Long_ComputeBidSignal lines 320? In provided code, line numbers not exact. We can cite function names.

Let's craft the final report.

Potential need to answer as "quantitative auditor" with "lookahead bias, silent failures, schema mismatches, statistical flaws" explicitly. We'll title findings by category.

Let's prioritize findings in a table:

| # | Category | Finding | Severity |
|---|---|---|---|
| 1 | Signal logic | FV cancels; quote centered at spot | High |
| 2 | Statistical | EURGBP sigma uses max, not cross-vol | High |
| 3 | Silent failure | MidNow uses close+half-spread, not current mid | High |
| 4 | Silent failure | ReplacePending cancels before replace | High |
| 5 | Silent failure | OnNewBar caches bar before compute success | Medium |
| 6 | Silent failure | No trade-deal reconciliation/retry | High |
| 7 | Statistical | InpQuoteSpread=4 pips dominates, docs blame sigma only | Medium |
| 8 | Silent/statistical | Deadband skip ignored, differs across EAs | Medium |
| 9 | Schema | AB helper diverges from production | Medium |
| 10 | Statistical | 3-point sigma proxy + off-by-one lag | Low/Medium |
| 11 | Lookahead | No direct lookahead found | Info |
| 12 | Schema | Cross-EA global variable overwrite | Medium |
| 13 | Data integrity | open_depth duplication after compaction | Low |
| 14 | Diagnostic | Small sample and empty-stack assumption | Low |

Need maybe not overdo with 14; but exhaustive is requested. We'll include all.

Let's write details under each.

For Finding 7, be careful: Docs says "Live spread floor: passivity buffer binds ~0.8% of bars; InpQuoteSpread + σ·mult dominates >99% of bars". They say "not InpQuoteSpread" because it's shared. We can say "shared doesn't mean irrelevant; it's a major absolute distance." Good.

For Finding 8, need avoid speculation about deadband implementation. We can say "If `V2_L0RestingWithinDeadband` uses `InpQuoteSpread` as width, then..." Since logic.mqh not provided, but likely. Use conditional.

For Finding 14, "open_depth" duplication: In `Long_AppendLayer`, `open_depth = n`; in `Long_RemoveLayerAt`, no update on shifted layers. If a non-top layer is removed, the layer that shifts from index i+1 to i retains open_depth. A newly added layer gets `open_depth = ArraySize(g_long_layers)` (current size before append) which may equal the shifted layer's open_depth. Example: layers [L0 depth0, L1 depth1, L2 depth2], remove L0 -> [L1 depth1, L2 depth2], append new L2? `n=2`, new layer depth=2, duplicate with existing depth2. This can mislabel telemetry. Need mention.

Finding 13: GlobalVariableSet in eurgbp resets both cap triggers. In code:
```
GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0);
GlobalVariableSet("V2EUR_CAP_TRIGGERS", 0.0);
```
If running simultaneously with fxmatrix_v2.mq5 and fxmatrix_v2_eurusd.mq5, this clobbers their counters. Severity Medium. If each EA runs in separate terminal, no. But docs imply same account/terminal? It says account 1513973831 via MT5 API, and telemetry on VPS; likely all EAs on same terminal. Good.

Finding 6: "No retry" but maybe `OnTick` calls `Long_AuditExitLimits` and `Long_OnNewBar` doesn't scan history. There is no `HistoryDealsGet` loop. True for provided code.

Potential Finding 15: "Magic literal inconsistency in fxmatrix_v2.mq5: uses `20260901` literal instead of macro in `Long_EnsureAddNext` and `Long_HandleDealFill`. If macros ever change, stale literals." Low. We can omit or include in schema.

Potential Finding 16: "`V2_ComputeBcBid` and `V2_ComputeBcOffer` in signal.mqh do not use `V2_L0DynamicHalfSpread`, so if used they omit passivity buffer/live spread." This is similar to Finding 9. Combine: "signal.mqh helper functions diverge from production."

Potential Finding 17: "`Long_PlaceBuyLimit` uses `ORDER_FILLING_RETURN` for pending orders, which is unusual." Not enough.

Potential Finding 18: "No `#define` for MM_LONG_V2 / MM_LONG_V2_EXIT in fxmatrix_v2.mq5 shown, but likely from logic.mqh." Not.

Need maybe mention "No code changes made" no.

Let's ensure final answer "exhaustive" but not too verbose. We can write ~2500-3500 words. Desired oververbosity 5. We'll do maybe 2500 words.

Let's craft final.

Need use "lookahead" section explicitly:
"Direct lookahead in order generation: I found none. The use of `CopyClose(...,1,60)` excludes the forming bar. The dynamic half-spread uses current spread only; fv/sigma from prior closed bars. No future bar is referenced in `Long_ComputeBidSignal` / `Short_ComputeOfferSignal`."
Then "However..." mention stale.

Let's include "code quote" snippets for key findings.

Let's formulate final answer now.

## Final Report

# FX V2 Infrastructure Audit

**Scope:** `fxmatrix_v2_eurgbp.mq5`, `fxmatrix_v2.mq5`, `fxmatrix_v2_eurusd.mq5`, `fxmatrix_v2_signal.mqh`, and the EURGBP L0 fill-rate diagnostic report. External includes (`logic.mqh`, `exits.mqh`, `telemetry.mqh`, cap modules) were not available, so findings below are based on the supplied files.

---

## 1. Lookahead Bias Assessment

### 1.1 No direct lookahead found in quote generation

All quote computations use closed M5 bars via:

```c
CopyClose(symbol, PERIOD_M5, 1, 60, closes)
```

`start_pos = 1` excludes the forming bar, so `closes[0]` is the previous completed M5 close. `fv`, `sigma`, and `r` are therefore computed from information known at the time the order is placed. I found **no direct lookahead** in the L0 signal path.

### 1.2 Off-by-one ambiguity in the `c6/c12/c48` lags

`CopyClose(..., 1, 60)` means, with series indexing, `closes[6]` is **not** “6 bars ago” from the current forming bar — it is 7 bars back. `closes[12]` is 13 bars back, `closes[48]` is 49 bars back.

The code and documentation call them `c6`, `c12`, and `c48` without acknowledging the constant 1-bar shift. This is not lookahead, but it is a schema/validation mismatch if any backtest or offline script indexes from bar 0 instead of bar 1.

**Severity:** Low / Medium — no lookahead, but possible inconsistent lag structure.

---

## 2. Critical Signal-Logic Flaw: Fair Value Cancels Out

This is the most important finding.

In the BC production formula:

```c
double r_bc = MathLog(bc_now / fv);
bid_theoretical = fv * MathExp(r_bc - dynamic_hs);
```

But `fv * exp(r_bc) = bc_now`, so the formula simplifies to:

```text
bid_theoretical = bc_now * exp(-dynamic_hs)
```

In the EURGBP AB formula:

```c
double inst_spread = r_ac - r_bc;
double ratio = fv_ac / fv_bc;
bid_theoretical = ratio * MathExp(inst_spread - dynamic_hs);
```

But:

```text
ratio * exp(inst_spread)
= (fv_ac / fv_bc) * exp(log(ac_now / fv_ac) - log(bc_now / fv_bc))
= ac_now / bc_now
```

So the EURGBP bid also simplifies to:

```text
bid_theoretical = (ac_now / bc_now) * exp(-dynamic_hs)
```

In both cases, **the fair value cancels out completely**. The “signal” is not anchored to fair value at all; it is simply the current cross/spot mid, pushed away by `dynamic_hs`.

### Implication

This system is not expressing a mean-reversion view. It is placing liquidity at a fixed distance behind the current market price. The diagnostic report’s phrase “fair mid minus bid quote” is therefore misleading: the “fair mid” used in the statistics is actually the current market mid, not a model fair value.

If the intended strategy is mean reversion to `fv`, then the formula is wrong: the bid should be something like `ratio * exp(-dynamic_hs)`, not `ratio * exp(inst_spread - dynamic_hs)`. If the strategy is intended to be a market-making/passive-liquidity strategy, then the documentation and variable naming should say so.

**Severity:** High — invalidates the interpretation of the signal and the diagnostic report.

---

## 3. Statistical Flaw: EURGBP Volatility Is Not the Max of Leg Sigmas

The EURGBP EA uses:

```c
MathMax(sig_ac, sig_bc)
```

as the volatility input to `V2_L0DynamicHalfSpread`.

For a cross rate constructed from two USD legs, the approximate log-return variance is:

```text
Var(EURGBP) ≈ Var(EURUSD) + Var(GBPUSD) - 2 * Cov(EURUSD, GBPUSD)
```

Using `max(sig_ac, sig_bc)` is not a variance-consistent estimate. It discards the smaller leg volatility and ignores the high positive correlation between EURUSD and GBPUSD, which materially lowers the true EURGBP volatility.

The diagnostic report itself shows the consequence:

| Metric | Value |
|---|---|
| Native EURGBP median sigma | ~0.000176 |
| `max(EURUSD, GBPUSD)` median | ~0.000655 |
| Ratio | ~3.7x |

This is very likely the main statistical driver of the low EURGBP fill rate. The correct approach would be to estimate EURGBP volatility directly, or at minimum use a combination such as an RMS/correlation-adjusted formula.

**Severity:** High — systematically widens EURGBP quotes relative to its own realized volatility.

---

## 4. Silent Failure: `V2_MidNowFromSymbol` Does Not Return Current Mid

In `fxmatrix_v2_signal.mqh`:

```c
double V2_MidNowFromSymbol(const string symbol, const double fallback_close)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
      return fallback_close + (ask - bid) / 2.0;
   return fallback_close;
}
```

Despite the name `MidNow`, when live bid/ask are available it returns:

```text
previous M5 close + half current spread
```

not:

```text
(bid + ask) / 2
```

The same pattern is inlined in `fxmatrix_v2.mq5`:

```c
double half = (ask - bid) / 2.0;
double bc_now = closes[0] + half;
```

This means the “current” mid is stale by whatever price movement has occurred since the previous M5 close. At the exact instant of a bar boundary, this may be approximately correct, but if the first tick of the bar is delayed, or if a gap occurs, the computed signal can be far from the actual market.

### Consequences

- The L0 order may be placed at a price that is not related to the current market.
- If the market has moved toward/through the order, the order may be rejected by `Long_PlaceBuyLimit` or fill immediately on stale terms.
- The AB signal for EURGBP is also affected because both leg “current mids” use stale closes.

**Severity:** High — silent, deterministic price-source error.

---

## 5. Silent Failure: L0 Replacement Cancels Before Placing New Order

In `Long_ReplacePendingBuy`:

```c
Long_CancelTicket(ticket_ref);
ticket_ref = Long_PlaceBuyLimit(price, magic, comment);
if(ticket_ref > 0)
{
   g_long_stat_l0_requote++;
   return true;
}
return false;
```

If the new price is too close to market, or the broker/API rejects the request, `Long_PlaceBuyLimit` returns `0`. The old resting order has already been canceled. The EA is then **unquoted on that side until the next M5 bar**, because `Long_OnNewBar` will return early on subsequent ticks of the same bar.

There is also no warning logged for this specific failure path.

The same problem exists in `Short_ReplacePendingSell`.

**Severity:** High — directly suppresses L0 fill opportunities and hides failures.

---

## 6. Silent Failure: Bar Time Is Cached Before Signal Computation Succeeds

In `Long_OnNewBar`:

```c
datetime bar_time = iTime(_Symbol, PERIOD_M5, 0);
if (bar_time == g_long_last_bar_time)
   return;
g_long_last_bar_time = bar_time;

double bid_theoretical;
if (!Long_ComputeBidSignal(bid_theoretical))
   return;
```

If `CopyClose` or `V2_FvSigmaFromCloses` fails once — e.g., history not ready after startup or a temporary terminal data glitch — the EA marks the bar as processed and does not retry until the next M5 bar.

During that entire M5 bar, the L0 quote can remain stale or missing.

**Severity:** Medium / High — transient data failures become sustained quote failures.

---

## 7. Silent Failure: No Deal Reconciliation / Retry

`OnTradeTransaction` handles deal fills only when `TRADE_TRANSACTION_DEAL_ADD` fires, and `Long_HandleDealFill` calls:

```c
if (!HistoryDealSelect(deal_ticket))
   return;
```

If `HistoryDealSelect` fails transiently, the deal is never processed. There is no periodic `history_deals_get` reconciliation, no startup replay, and no retry queue.

Possible consequences:

- A filled L0 order is not registered; `g_long_l0_ticket` is not cleared.
- A filled add order is not registered; `g_long_add_ticket` remains set.
- An exit fill is not detected; the layer is not removed and the CloseBy is not queued.
- The next `Long_EnsureAddNext` may place a duplicate add because the stale ticket is no longer selectable.

This is a serious operational hole for an always-on FX EA.

**Severity:** High — can silently corrupt position tracking and order placement.

---

## 8. Statistical/Config Flaw: `InpQuoteSpread = 0.0004` Is 4 Pips and Is Underweighted in the Diagnosis

`Long_PipsToPrice` defines 1 pip for 5-digit symbols as `_Point * 10 = 0.00010`.

Therefore:

```text
InpQuoteSpread = 0.0004 = 4 pips
```

For EURGBP, the report states the median 1-bar M5 range is only **1.4 pips**. A 4-pip base quote spread alone is therefore ~2.9× the typical one-bar movement.

The diagnostic report says the decisive input is `MathMax(sig_ac, sig_bc)`, “not `InpQuoteSpread`”. That is misleading:

- `InpQuoteSpread` contributes 4 pips to `dynamic_hs`.
- The `MathMax` sigma contribution adds roughly 3.3 pips under current inputs.
- If EURGBP used native sigma, `InpQuoteSpread` would become ~82% of the half-spread.

`InpQuoteSpread` is a shared input across all three EAs, so it does not explain the *difference* between EURGBP and the USD pairs. But it is a major absolute cause of the wide quote distance and low fill rate on EURGBP.

**Severity:** Medium — documentation conclusion is not fully supported.

---

## 9. Deadband Behavior Is Not Accounted For

`Long_ReplacePendingBuy` skips requoting when:

```c
V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult)
```

With `InpQuoteSpread = 0.0004` and `InpL0DeadbandMult = 1.0`, the deadband is presumably at least 4 pips. For EURGBP, whose median M5 1-bar range is 1.4 pips, the theoretical quote will often move less than the deadband between bars. In those cases, the L0 order is **not updated at all**.

This can add further, unquantified quote lag on top of the already-wide `dynamic_hs`.

Additionally, EURUSD has a new input:

```c
input bool InpL0DeadbandVolScale = true;
```

and passes `EurUsd_L0DeadbandSpreadRef()` into the deadband call. EURGBP and GBPUSD do not. The diagnostic report does not mention this difference or its effect on L0 requote frequency.

**Severity:** Medium — silent behavioral difference and omitted from the fill-rate diagnosis.

---

## 10. Schema Mismatch: Helpers in `fxmatrix_v2_signal.mqh` Divergge from Production Logic

`V2_ComputeBcBid`, `V2_ComputeBcOffer`, and `V2_ComputeAbBidOffer` all compute `dynamic_hs` as:

```c
quote_spread + sigma * spread_multiplier
```

and do **not** use:

- `V2_L0DynamicHalfSpread`
- live spread resolution
- passivity buffer
- effective multiplier easing (`V2_EffectiveSpreadMultiplier`)

But the production EAs call `V2_L0DynamicHalfSpread` with all of those components:

```c
double dynamic_hs = V2_L0DynamicHalfSpread(
   InpQuoteSpread,
   sigma,
   effective_multiplier,
   live_spread_price,
   Long_PipsToPrice(InpPassivityBuffer));
```

So any test, backtest, or future code path that calls the helpers will produce different quotes from the live EAs.

Also, `V2_ComputeAbBidOffer` contains a no-op block:

```c
if(ab_symbol != _Symbol && ab_symbol != "")
{
   // Prices are already in AB terms; no further conversion needed.
}
```

This is dead code and gives a false sense of validation.

**Severity:** Medium — maintenance and reproducibility hazard.

---

## 11. Statistical Weakness: `sigma` Is a 3-Point Level Dispersion, Not Return Volatility

`V2_FvSigmaFromCloses` computes:

```c
double mean = (c6 + c12 + c48) / 3.0;
sigma_out = sqrt(((c6-mean)^2 + (c12-mean)^2 + (c48-mean)^2) / 3.0);
```

This is the standard deviation of three price levels, not the standard deviation of returns. It is heavily dependent on the absolute price level and on the arbitrary lag choice. It is not a robust measure of realized volatility and is not directly comparable to the M5 range statistics used in the diagnostic report.

Using this as the volatility input to `dynamic_hs` injects noise and makes the half-spread hard to interpret statistically.

**Severity:** Medium — the “sigma” in the diagnosis is not a proper volatility estimate.

---

## 12. Cross-EA Global Variable Collision

`fxmatrix_v2_eurgbp.mq5` `OnInit` executes:

```c
GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0);
GlobalVariableSet("V2EUR_CAP_TRIGGERS", 0.0);
```

If the EURUSD and GBPUSD V2 EAs run on the same terminal/account, this resets their cap-trigger global variables, potentially erasing cap state and allowing adds that should have been blocked.

This is particularly dangerous because the diagnostic/doc scope explicitly mentions a single FTMO account running multiple pairs.

**Severity:** Medium — cross-instance state corruption.

---

## 13. Data Integrity: `open_depth` Duplicates After Layer Compaction

`Long_RemoveLayerAt` compacts the layer array by shifting later layers down, but does **not** update their `open_depth` fields. A subsequent `Long_AppendLayer` assigns `open_depth = ArraySize(g_long_layers)` before the append.

Example:

- Layers: `open_depth = 0, 1, 2`
- Remove layer 0 → remaining layers: `open_depth = 1, 2`
- Append new layer when array size is 2 → new layer also gets `open_depth = 2`

Now two active layers have `open_depth = 2`, which corrupts telemetry and any performance attribution that depends on fill depth.

**Severity:** Low — data/telemetry integrity issue, not an immediate trading loss.

---

## 14. Diagnostic Report Limitations

The report is generally well-structured, but several statistical caveats should be stated:

1. **Small sample for EURGBP:** Step 4 is based on only 6 EURGBP exit events. Median time-between-exits of ~31.6 hours is not statistically meaningful.
2. **Empty-stack assumption:** Step 2 assumes `effective_multiplier = 0.5`, i.e., both sides are empty. In production, L0 quotes are eased when the opposite side has depth. Ignoring that state likely overstates median quote distance during actual fill attempts.
3. **“Fair mid” is not fair:** Because the FV cancels out of the formula, the report’s “fair mid minus bid” is actually “current spot minus bid.”
4. **Deadband ignored:** The report does not model `V2_L0RestingWithinDeadband` requote skipping, which can make the effective quote even stickier.

**Severity:** Low — diagnostic quality only.

---

## 15. No Direct Lookahead Bias: Summary

I found **no direct lookahead** in order generation. The code is careful to use closed bars and current spread only. The main problems are not lookahead but:

- Stale mid construction
- Cancellation-before-replacement
- No deal reconciliation
- Statistically inconsistent volatility sizing
- A signal formula whose fair-value component cancels out

---

## Priority Recommendations

1. **Fix `V2_MidNowFromSymbol`** to return `(bid + ask) / 2.0`, and update the inline BC computation in `fxmatrix_v2.mq5` accordingly.
2. **Revisit the EURGBP sigma input.** Use native EURGBP volatility or a correlation-adjusted cross volatility, not `MathMax(sig_ac, sig_bc)`.
3. **Fix `Long_ReplacePendingBuy` / `Short_ReplacePendingSell`** to place the new order before canceling the old one, or restore the old order on failure.
4. **Move `g_long_last_bar_time` assignment** to after successful signal computation.
5. **Add deal-history reconciliation** on startup and periodically, so missed `OnTradeTransaction` events are recovered.
6. **Re-evaluate `InpQuoteSpread = 0.0004`.** At 4 pips, it is likely a primary absolute cause of low EURGBP fills and should not be treated as a minor shared parameter.
7. **Unify the helper functions** in `fxmatrix_v2_signal.mqh` with production `V2_L0DynamicHalfSpread`, or remove them.
8. **Avoid resetting shared global variables** in pair-specific EAs unless the cap state is intentionally shared.
9. **Update `open_depth` during layer compaction**, or stop using it for active-depth reporting.
10. **Correct the diagnostic report** to acknowledge FV cancellation, the 4-pip `InpQuoteSpread`, deadband skipping, and the small EURGBP sample.