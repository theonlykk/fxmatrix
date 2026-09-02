# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer user's request. Need audit specification against code. Need no implementation code. We are red team. Need be exhaustive. We need flag blockers and assumptions false. Need analyze provided spec and code. We need respond as Phase 1 audit. Need not code. Need mechanical/architectural critique.

Need understand task. We have full spec for unified V2 engine. Need audit: lookahead bias, silent failures, schema mismatches, statistical flaws? The role says "quantitative auditor hunting for lookahead bias, silent failures, schema mismatches, and statistical flaws in FX algorithmic trading infrastructure." Need audit spec and code. Need answer questions from Claude and Cursor's open questions. Need flag blocking issues.

Need inspect code for discrepancies with spec. Need perhaps cite production code. Need evaluate:
- Pair preset mechanism with struct and input overrides.
- Unified L0 signal dispatch with easing.
- Cap module selection.
- Shared engine body.
- Parity verification plan exact match.
- ADR-102/103 preservation.

Need identify any issues that block. Need maybe "lookahead bias" in production? Need check signal path uses CopyClose(_Symbol, PERIOD_M5, 1, 60, closes), so starts from bar 1, not current forming bar. No lookahead. But V2_L0ResolveLiveSpreadPrice uses SYMBOL_SPREAD current live spread; ok. V2_MidNowFromSymbol uses fallback_close + (ask-bid)/2 where fallback_close is closes[0] (previous completed M5 close), plus current half-spread. This is a weird hybrid: bc_now = closes[0] + half. If closes[0] is the last completed bar's close and half is current spread/2, that's not current mid; it's previous close plus current half-spread. That may be intended. In BC production code, same: bc_now = closes[0] + half. No lookahead.

Need audit unified spec for "must extract from production .mq5 bodies, not signal.mqh stubs". Good.

Need evaluate "V2_L0SignalContext struct (quote_spread, spread_multiplier, spread_multiplier_eased, ease_depth_start/full, passivity_buffer_pips, opposite_depth, quoting_side_flat, leg symbols, passivity_buffer_price)" and entry points. Need maybe flag "opposite_depth" and "quoting_side_flat" unnecessary? Need check production logic.

Let's parse production L0 signal in detail:
Long_ComputeBidSignal (GBPUSD):
- CopyClose(_Symbol,M5,1,60)
- c6=closes[6], c12=closes[12], c48=closes[48]
- fv=0.5c6+0.3c12+0.2c48
- mean=(c6+c12+c48)/3
- sigma=sqrt(avg squared deviations)
- bid=SymbolInfoDouble(SYMBOL_BID), ask=SymbolInfoDouble(SYMBOL_ASK)
- half=(ask-bid)/2
- bc_now=closes[0]+half  (NOTE: not current mid; uses last closed bar close + half spread)
- r_bc=MathLog(bc_now/fv)
- effective_multiplier = InpSpreadMultiplier; if ArraySize(g_long_layers)==0 then V2_EffectiveSpreadMultiplier(ArraySize(g_short_layers), ease start/full, multiplier, eased)
- live_spread_price=V2_L0ResolveLiveSpreadPrice(InpQuoteSpread)
- dynamic_hs=V2_L0DynamicHalfSpread(InpQuoteSpread, sigma, effective_multiplier, live_spread_price, Long_PipsToPrice(InpPassivityBuffer))
- bid_theoretical=fv*MathExp(r_bc - dynamic_hs)

Important: effective_multiplier easing is applied only when own layers == 0, based on opposite depth (short layers). In short, same. For EURUSD same as GBPUSD except deadband vol scale; signal path same BC native. EURGBP AB triad:
- V2_CopyM5Closes(InpLegAC, ac_closes) and InpLegBC
- fv_ac/sig_ac, fv_bc/sig_bc
- ac_now=V2_MidNowFromSymbol(InpLegAC, ac_closes[0]) -> fallback_close + (ask-bid)/2 for AC symbol
- bc_now similarly
- r_ac=log(ac_now/fv_ac), r_bc=log(bc_now/fv_bc)
- inst_spread=r_ac - r_bc
- ratio=fv_ac/fv_bc
- effective_multiplier same based on own long layers==0 and opposite depth.
- dynamic_hs = V2_L0DynamicHalfSpread(InpQuoteSpread, MathMax(sig_ac,sig_bc), effective_multiplier, live_spread_price, Long_PipsToPrice(InpPassivityBuffer))
- bid=ratio*MathExp(inst_spread - dynamic_hs)

Need note production uses Long_PipsToPrice(InpPassivityBuffer), which is pips * _Point * 10.0. For EURGBP, same Long_PipsToPrice. For all pairs, pips conversion always *_Point*10, despite signal.mqh has V2_PipsToPriceForSymbol with digits 3/5. Production uses Long_PipsToPrice for all (including EURGBP? yes). EURGBP point maybe 0.00001, digits 5, pips*point*10. Fine.

Need note "leg symbols" in context for AB: InpLegAC and InpLegBC. For BC path, leg symbols maybe none. Need preserve runtime overrides.

Need inspect cap modules. Production GBPUSD includes gbp_cap; calls V2_GbpCapBlocksNewAdd("GBPUSD", true, InpGbpCapThreshold) in Long_EnsureAddNext and V2_GbpCapSyncInstance("GBPUSD", true, ArraySize). EURUSD includes eur_cap; V2_EurCap*. EURGBP includes both plus dual cap; Long_EnsureAddNext uses V2_AnyCapBlocksNewAdd(true, InpGbpCapThreshold, InpEurCapThreshold) and V2_SyncAllCaps. Note in EURGBP, Long_EnsureAddNext does NOT call V2_GbpCapRecordBlock explicitly but V2_AnyCapBlocksNewAdd does both record blocks. In EURGBP, cap sync in AppendLayer/RemoveLayer uses V2_SyncAllCaps. In OnInit, cap publish uses V2_SyncAllCaps for non-orphan side.

Need assess unified cap profile design: "GBPUSD -> V2_CAP_GBP_ONLY -> gbp_cap.mqh. EURUSD -> V2_CAP_EUR_ONLY -> eur_cap.mqh. EURGBP -> V2_CAP_DUAL_GBP_EUR -> gbp_cap + eur_cap + eurgbp_dual_cap. Engine uses Engine_CapBlocksNewAdd()/Engine_CapSyncInstance() switching on g_preset.cap_profile. No cross_exposure_cap.mqh. ADR-103 preserved: orphan-aware cap publish via V2_ShouldPublishCapSyncOnInit, no trigger GV reset. Each shell includes only the cap headers its profile needs."

Potential issue: If each shell includes only cap headers its profile needs, then engine's cap helper functions (e.g., Engine_CapBlocksNewAdd) cannot be compiled generically unless they are defined differently per profile. If cap_profile enum switches on profile, and code references V2_GbpCap* functions, those functions are only available if gbp_cap.mqh included. For GBPUSD shell, eur_cap not included, so engine cannot call V2_EurCap* for EURUSD if engine has switch on cap_profile that includes calls to both. Need think. Spec says "cap headers included per preset profile" and "Each shell includes only the cap headers its profile needs." But if shared engine has a switch statement on cap_profile that calls V2_GbpCap* and V2_EurCap* and V2_AnyCap* depending on profile, then every shell must include all cap headers for the engine to compile. Alternatively, engine could use macros or function pointers? But spec says no macros? Need flag this as schema mismatch. Need design: Could have cap_profile-specific bridge functions in per-shell or per-profile fragment that implement Engine_CapBlocksNewAdd and Engine_CapSyncInstance, so engine doesn't call undefined functions. But spec's "Engine uses Engine_CapBlocksNewAdd()/Engine_CapSyncInstance() switching on g_preset.cap_profile" is ambiguous. If it means engine contains switch with all cap functions, then include strategy fails. Need recommend: define per-profile bridge functions (e.g., in preset fragment) that call appropriate cap module, and engine calls bridge. Or include all cap headers in all shells. But including all cap headers in all shells is okay? It may add compile dependencies but no logic? If all cap headers compiled in each shell, the functions exist and can be called; cap GV keys and logic are independent of attached pair, but calling them from engine switch is fine. But shells "include only the cap headers its profile needs" would be false. Need flag.

Also "V2CapProfile enum [GBP_ONLY/EUR_ONLY/DUAL_GBP_EUR]" maybe not enough for compile-time include if using switch. Need mention.

Need assess "preset struct" from compile-time with input overrides. Claude question 1: preset-vs-input override resolution order. Need answer. The spec says "easing defaults locked per pair must be overridable via input". In current production, inputs are declared in each .mq5 with direct defaults. In unified shell, if preset defines defaults and inputs are declared in shell, what wins? Need design exactly. Could use input defaults equal to preset defaults? But if preset is compile-time, can't set `input double InpEaseDepthStart = g_preset.ease_depth_start` because MQL5 input initializers must be compile-time constants, not runtime struct value? Actually `g_preset` is a compile-time struct variable initialized with constants? In MQL5, `input` variables must be initialized with constant expressions, not with non-constant global variable. If `g_preset` is a global const struct, maybe can initialize input with `g_preset.ease_depth_start`? In MQL5, global variable initialization occurs before input? I think input initializers require constant expressions, so not allowed. The shell could define `#define PRESET_EASE_DEPTH_START 1` and use that in preset struct and input default? But spec says "typed pair preset" and "input declarations" in shell. Need define mechanism: each shell declares inputs with their own defaults matching preset values; or preset fragment defines macros for defaults used both in struct and input declarations. Without that, ambiguity and risk.

Need read exact spec: "V2PairPreset struct (identity: symbol, telemetry instance names, EA name, magic numbers; signal: V2SignalSlot enum [BC_NATIVE/AB_TRIAD], leg symbols; L0 deadband flag and reference spread; easing defaults; V2CapProfile enum), with per-pair preset fragment files carrying values copied verbatim from current production." "easing defaults locked ... overridable via input." "Each shell defines a compile-time V2_PAIR_PRESET struct and #include shared engine." "shells remain because ... default inputs ... differ per pair." So inputs are in shells. Need audit: if shell input defaults are not derived from preset, two sources of truth. Need specify resolution. Silent error if mismatch. Need maybe propose: input values must be used as runtime overrides; preset values are only used for non-input constants? But easing defaults need to be inputs. Could simply have shell input declarations with correct defaults and no preset easing defaults? But preset should encode easing defaults? "easing and cap differences encoded in a typed pair preset, not copy-pasted." Need avoid duplicate.

Need answer: current production already has `input` declarations with defaults per pair. Unified engine can use those inputs directly. The preset struct can hold constants that are not inputs (magic, labels, cap profile, signal slot, leg symbols, deadband reference). Easing defaults are already in input defaults; they don't need to be in preset unless you want the engine to reset to defaults? But "easing defaults" in preset and "overridable via input" creates conflict. There is a tested pattern: use preprocessor macros in preset fragment to define both compile-time constants and default values for input declarations. For example `#define V2_PRESET_EASE_DEPTH_START 1` then `input int InpEaseDepthStart = V2_PRESET_EASE_DEPTH_START;` and `g_preset.ease_depth_start = V2_PRESET_EASE_DEPTH_START;`. But code snippets? We can describe.

Need evaluate hidden issue with `input` variables in included engine. Current production's `Long_ComputeBidSignal` directly references `Inp*` inputs. If engine is in .mqh and shells declare inputs before include, okay. But if engine references inputs that aren't declared in all shells (e.g., `InpEurCapThreshold` for GBPUSD), compile fails. Need ensure shared engine only references common inputs, and profile-specific inputs are declared in shells/preset? Actually `Long_EnsureAddNext` in GBPUSD uses `InpGbpCapThreshold`; EURUSD uses `InpEurCapThreshold`; EURGBP uses both. Unified engine with cap bridge may need both inputs? If engine has a generic `Engine_CapBlocksNewAdd` that takes thresholds? Could use preset to know which threshold input to read? But input variable names differ. Need design: all shells could declare both `InpGbpCapThreshold` and `InpEurCapThreshold`, even if unused for GBPUSD? But current EURUSD doesn't have InpGbpCapThreshold, GBPUSD doesn't have InpEurCapThreshold. Changing inputs will affect .set compatibility and Strategy Tester .set files. Spec says production inputs remain? It says "shells get distinct names"; "Strategy Tester/.set compatibility" is a reason to preserve input declarations. If unified engine requires both inputs, .set files for GBPUSD that don't include InpEurCapThreshold would use default, okay? But adding new input changes .set compatibility? Maybe not fatal but changes input list, and existing .set might not set it, but that's okay. However spec says "thin per-pair entry shells ... default inputs differ per pair" and "compile-time cap includes differ per pair". Need not include irrelevant cap inputs? But engine may use them.

Need audit "thin shells ~40-60 lines each define compile-time V2_PAIR_PRESET struct and #include shared engine". If shell includes shared engine, where are input declarations? Likely in shell before include, as current. If engine uses all possible inputs, each shell must declare all inputs. That erodes thinness but maybe manageable. Need flag.

Need identify production surprises:
1. Signal inlined not helper-called. In provided code, yes Long_ComputeBidSignal/Short_ComputeOfferSignal are in .mq5, not signal.mqh. The unified spec acknowledges.
2. EURUSD vol-scale deadband orthogonal to signal dispatch (L0 replace path). In EURUSD, Long_ReplacePendingBuy calls V2_L0RestingWithinDeadband with EurUsd_L0DeadbandSpreadRef(), while GBPUSD and EURGBP call without. Spec says "L0 deadband flag and reference spread" in preset. Need include in L0 signal context? It is used in L0 replace path, not signal compute. Need ensure engine's L0 replace functions use preset. Could be okay.
3. EURGBP leg symbol runtime overrides remain. Yes InpLegAC/InpLegBC inputs in EURGBP; not in others. Unified shell must declare them for EURGBP, and signal dispatch uses them.
4. Three .ex5 binaries required for VPS. Yes.
5. logic.mqh/exits.mqh stay production — no _r1 fork. Good.

Need check "no cross_exposure_cap.mqh" in spec. Provided code includes no cross_exposure_cap.mqh. Good.

Need check "ADR-103 preserved: orphan-aware cap publish via V2_ShouldPublishCapSyncOnInit, no trigger GV reset." In production code, OnInit:
- V2_ShouldPublishCapSyncOnInit(long_orphan) then cap sync.
- No GlobalVariableSet trigger reset anywhere in provided code? Need search. None in OnInit. Good.

Need check "ADR-102 preserved: per-side halt gate after deal-ownership validation". In production code, Long_HandleDealFill:
- Dedup, HistoryDealSelect, symbol check, extract fields, MarkDealProcessed.
- Then compute is_long_entry/is_long_exit.
- If (is_long_entry || is_long_exit) && g_long_halted -> alert and return.
This is after validation and mark processed. Good. It does not check magic before? It uses V2_IsManaged... which checks magic. Good. For exit deal, V2_IsManagedExitDeal checks entry_type == DEAL_ENTRY_IN and magic == exit magic. It doesn't check deal_type (buy/sell) for exit, so exit fills of either direction? Fine.

Need check "No CloseBy queuing on exit-magic fills while halted". In halted path, returns before queue. Good.

Need check ADR-102 "per-side gate after deal-ownership validation (symbol + magic), not before." It is after symbol and magic computed. Good.

Need check ADR-103 "cap publish ordering relative to Long_OnInit/Short_OnInit and orphan scan." In production, after both Long_OnInit and Short_OnInit, orphan scan; then publish. Good.

Need check "trigger GV reset removed" in production. No trigger reset. Good.

Need check "EURGBP dual-cap block logging" in production: V2_AnyCapBlocksNewAdd prints "INFO V2 cap eval | ..." every time regardless of verbose. Spec says parity edge case includes "EURGBP dual-cap block logging". Need preserve. Unified engine cap bridge must print same. Good.

Need check "cap publish skip" ADR-103: V2_ShouldPublishCapSyncOnInit(side_orphan) returns !side_orphan. Good.

Need check "easing thresholds (ADR-097: 1/3, ADR-098: 1/4, ADR-099: 1/3)" spec says production has pair-specific easing thresholds. Let's verify from code:
- GBPUSD: InpEaseDepthStart=1, InpEaseDepthFull=3, InpSpreadMultiplier=0.5, InpSpreadMultiplierEased=0.0. So ADR-097? Maybe 1/3 means start depth 1, full depth 3. "1/3" maybe start/full. 
- EURUSD: start=1, full=4. Wait spec says "Spread-easing thresholds (ADR-097: 1/3, ADR-098: 1/4, ADR-099: 1/3)"? Actually in code EURUSD has InpEaseDepthFull=4, so 1/4. Yes.
- EURGBP: start=1, full=3. Good.
So preset must encode start/full per pair. Good.

Need check "Cap module wiring (GBP-only, EUR-only, dual)" yes.

Need check "EURUSD-only L0 deadband vol-scale" yes.

Need audit "V2L0SignalContext struct (quote_spread, spread_multiplier, spread_multiplier_eased, ease_depth_start/full, passivity_buffer_pips, opposite_depth, quoting_side_flat, leg symbols, passivity_buffer_price)". Need note "passivity_buffer_pips" and "passivity_buffer_price" both included; production uses `Long_PipsToPrice(InpPassivityBuffer)`, so price is pips converted. Could compute in helper. Need ensure for all pairs, pip conversion is same. Yes. But `V2_PipsToPriceForSymbol` exists and could differ for 3/5 digits; production uses Long_PipsToPrice for all, which is pips * _Point * 10. For EURGBP digits maybe 5, okay. For JPY? not relevant. Need preserve exact.

Need check "V2_L0ComputeBid(preset, ctx, out bid) / V2_L0ComputeOffer(preset, ctx, out offer)" maybe need not have separate context for bid/offer because only difference is sign. Could share. Need not.

Need assess "unified L0 dispatch with native easing" vs signal.mqh helpers. The provided signal.mqh has V2_ComputeBcBid / V2_ComputeBcOffer / V2_ComputeAbBidOffer with fixed multiplier (no floor). Production's inlined signal uses V2_L0DynamicHalfSpread (with live spread price and passivity floor) and easing. Unified spec says lift production inlined logic, NOT pre-ADR helpers. Good.

Need audit "parity verification: exact match on exits, P&L, stats counts, max layers, peak net lots — exact." Claude question 3: Should be tolerance? Need answer with technical reasoning. Need inspect precision in code:
- Prices normalized to SYMBOL_DIGITS (5 digits) via NormalizeDouble.
- P&L computed from deal fields with double; exact equality across refactored code likely achievable if operations identical. But if call structure changes, floating-point operation order can change slightly. However MQL5 double arithmetic is deterministic for same operations; if refactor uses same multiplication/division and function calls, bit-for-bit can match. But if unified signal helper consolidates `Long_PipsToPrice(InpPassivityBuffer)` vs `V2_PipsToPriceForSymbol`, might change. Need propose explicit parity bar:
  - For order placement decisions: exact normalized price equality (since prices are normalized to integer ticks; compare after NormalizeDouble to pip/point).
  - For P&L and stats counts: integer counts exact; P&L from broker deal fields not recomputed, so exact if same deals and same sequence.
  - For floating-point internal values like sigma/dynamic_hs: no output requirement; if used in pricing, normalized prices should match within 0.5 point. But if any slight difference crosses a normalization boundary, order price differs by 1 point. Therefore parity should require exact normalized limit prices and exact order timing/counts; maybe allow P&L exact because broker-provided. Need mention deterministic Strategy Tester with same .set and data should produce identical if code path identical. But refactor may introduce "same math through different call structure" can cause floating-point differences if reassociation. Use "defensible tolerance": normalized prices exact at normalized tick (point); internal double tolerance 1e-12 relative; final P&L within 0.01 USD? But if entry prices same, P&L same from broker. Need not overstate. The question asks "define explicit numerical tolerance instead of bit-for-bit equality, and if so what's defensible." We can say: insist on exact equality for all discrete outcomes (order count, layer count, stats, max layers, peak net lots) and for normalized order prices/tickets; for floating-point telemetry/DIAG values, allow 1e-9 relative; P&L should be exact because it is read from deal fields, but if account currency rounding differences in backtest, allow 0.01 currency units. But if "peak net lots" is integer layer count times lot size? Lot size input same, so exact.

Need maybe "peak net lots" in production stats not present, but maybe telemetry. Fine.

Need audit "side-by-side Strategy Tester, production vs unified shell, Model=4, identical .set, canonical windows (truss_crisis, full_quarter, EURGBP + june_blowup). Match target: exits, P&L, V2_STATS counts, max layers, peak net lots — exact." Need note: Strategy Tester with real tick model and order send timing can be nondeterministic if market orders? But EAs use pending limit orders; backtest with "Every tick based on real ticks" should be deterministic for same EA? Maybe. Need mention if any use of `TimeCurrent`/`TimeGMT` vs server time can be same. Need "Model=4" likely real tick. Good.

Need check "canonical windows" not in docs. Need perhaps "truss_crisis", "full_quarter", "EURGBP + june_blowup" are not defined in code/docs; need specify exact date ranges and data source. This is a blocker if parity gate cannot be reproduced. Need flag: "canonical windows" must be precisely defined with start/end timestamps and symbol, otherwise parity gate is vacuous.

Need audit "side-by-side Strategy Tester, production vs unified shell" with same .set. But if new shells have different names and default input names, .set file uses EA name? Strategy Tester .set is per EA? Actually .set files can be applied to any EA if input names match. If unified shell changes input set, old .set may not map. Need include a set-translation mechanism. Spec says "Strategy Tester/.set compatibility" but doesn't specify. Need flag.

Need inspect "preset fragment files with values copied verbatim from current production." This is a source of drift; need tests to assert preset values match production. But no implementation.

Need audit "logic.mqh/exits.mqh stay production — no _r1 fork." Good, but unified engine .mqh will include them; if they reference `_Symbol` and current pair, fine. Need ensure no duplicate includes.

Need identify "silent failures" potential:
- If preset struct default vs input mismatch, silent wrong threshold.
- If cap bridge includes only needed headers but engine switch references missing functions, compile error (not silent).
- If `InpLegAC`/`InpLegBC` not present in BC shells, engine's AB path conditional compile? Need avoid runtime if signal slot BC but code references InpLegAC; compile error if absent. Need use preset leg symbols that are compile-time? But EURGBP requires runtime input overrides. For BC shells, no need to declare leg inputs, but unified signal dispatch may need to reference leg symbols only in AB branch. If code has `if (g_preset.signal_slot == AB_TRIAD)` and uses `InpLegAC`, compiler still needs declaration. Could use preset.leg_ac default and runtime override? In MQL5, can't assign input to struct? Could use global string `g_leg_ac` initialized from `InpLegAC` after OnInit? But signal compute may occur before? OnInit sets. Could use function `V2_GetLegAC() { return (InpLegAC != "" ? InpLegAC : g_preset.leg_ac); }` but InpLegAC absent in BC shells. Need define all leg inputs in all shells or use preprocessor. Need flag.

- Similarly `InpL0DeadbandVolScale` exists only in EURUSD; unified engine L0 replace path may reference it. Preset says "L0 deadband flag and reference spread" encode it; but if input override is needed? In production, EURUSD has `InpL0DeadbandVolScale` input; GBPUSD/EURGBP do not. Unified engine can use preset.deadband_vol_scale flag, but if it needs to allow user override, only EURUSD shell declares input. Need design: common input `InpL0DeadbandVolScale` declared in all shells? But current GBPUSD doesn't have it. Or per-shell input only and engine references via wrapper. Need flag.

- `InpEurCapThreshold`/`InpGbpCapThreshold` distribution. Similar.

Need inspect "identity: symbol, telemetry instance names, EA name, magic numbers" — current production uses `#define` for telemetry instance names and magic. Some places use hardcoded magic numbers: in GBPUSD Long_HandleDealFill passes `(long)20260901` instead of MM_LONG_V2 in one place? Let's check: In fxmatrix_v2.mq5 Long_HandleDealFill:
```
const bool is_long_entry = V2_IsManagedLongEntryDeal(entry_type, deal_type, deal_magic, (long)20260901);
```
Yes hardcoded 20260901. In Short_HandleDealFill passes (long)20260902. In Long_EnsureAddNext uses `Long_PlaceBuyLimit(add_price, 20260901, ...)` hardcoded; Short uses 20260902. In OnInit, uses MM_LONG_V2 etc. This is a production surprise: some hardcoded magic numbers remain. Unified preset must ensure all uses use `g_preset.magic_long` or `MM_LONG_V2`, not mixed. Need flag as schema mismatch. Also in `Long_OnInit` print uses "magic=20260901" hardcoded. In EURUSD, uses MM_LONG_V2 in most places? In Long_HandleDealFill uses MM_LONG_V2. In EnsureAddNext uses MM_LONG_V2. Good. GBPUSD file is not fully macro-ized. So extraction must not copy hardcoded numbers; use preset. Need flag.

Need check "V2_TEL_INSTANCE_LONG" defined in EURUSD/EURGBP; in GBPUSD file, includes logic.mqh which defines no telemetry instance names. But fxmatrix_v2.mq5 references V2_TEL_INSTANCE_LONG in Long_HandleDealFill, Long_AuditExitLimits, etc. Where is it defined? Wait in provided GBPAUD? The fxmatrix_v2.mq5 file does NOT define V2_TEL_INSTANCE_LONG or V2_TEL_INSTANCE_SHORT or V2_EA_NAME. It uses them. Perhaps logic.mqh doesn't define. Maybe the snippet omitted defines at top? The header comment says Magic MM_LONG_V2=20260901 etc. It includes fxmatrix_v2_logic.mqh which has #ifndef MM_LONG_V2 default. No V2_TEL_INSTANCE_LONG. But Long_AuditExitLimits calls V2_EscalateExitAlert(g_long_system_alerts, V2_TEL_INSTANCE_LONG, ...). V2_TEL_INSTANCE_LONG undefined? In MQL5, undefined identifier causes compile error. Maybe the provided file snippet is incomplete? Check fxmatrix_v2.mq5 at top: no #defines. Maybe logic.mqh or telemetry.mqh defines? We don't have telemetry.mqh. Could be in telemetry.mqh. Need not.

Need check "V2_EA_NAME" used in orphan print? In V2_ProcessOrphanStartupCheck prints "fxmatrix_v2 " hardcoded; not V2_EA_NAME. So V2_EA_NAME maybe unused. Fine.

Need audit "three shells remain because MT5 attaches one EA binary per chart instance — magic numbers, default inputs, and compile-time cap includes differ per pair. Shells are deployment artifacts, not logic duplicates." Good.

Need examine "production files during transition: existing ... remain untouched until parity is proven; new shells get distinct names or replace production only after parity gate." Good.

Need identify "lookahead bias" in proposed unified L0 signal? The spec says "easing must be inside dispatch layer" based on opposite_depth and own stack flat. This is not lookahead; it uses current state. Need verify "effective_multiplier = InpSpreadMultiplier; if(ArraySize(g_long_layers)==0) { effective = V2_EffectiveSpreadMultiplier(ArraySize(g_short_layers), ...) }" This means if own layers >0, no easing even if opposite depth high. The spec's context has "quoting_side_flat" and "opposite_depth"; need preserve that. Good.

Potential "lookahead bias" in parity testing: Strategy Tester with Model=4 and same .set but different EA names may have different `MqlTradeRequest` comments or magic? If unified shell uses same magic, okay. But if magic numbers are in preset, must match production exactly. Need ensure no accidental change in order comments. Comments "V2_L0", "V2_Add", "V2_Reload", "V2_Exit" must remain identical. Telemetry instance labels must remain identical. Otherwise backtest order matching? P&L unaffected but V2_STATS logs? Need parity.

Need audit "V2_STATS counts" in production are printed on Deinit. Unified engine must preserve exact stat names and counts. If "Long_OnDeinit" in shell? In current production, Long_OnDeinit and Short_OnDeinit are inside .mq5. Unified engine can define them. Need ensure `Print("V2_STATS_LONG | ...")` exact strings? Parity requires counts; logs maybe not. But tests might compare? Need preserve.

Need check "API counter" V2_ApiCounterMaybeReset in OnTick and OnInit. Need preserve. Spec mentions.

Need audit "rollover reconciliation + retry (ADR-101)" in shared engine. The production code has V2_BuildLongRolloverSlots, V2_ApplyLongRolloverSlots, etc. duplicated in each file. Unified engine can hold these. Need ensure no pair-specific differences. They are identical. Good.

Need check "halt gate (ADR-102)" in OnTradeTransaction. Need preserve per-side halt. Good.

Need audit "telemetry" in shared engine: V2FillLongTelLayers, V2FillShortTelLayers, V2EmitTelemetry identical. Good.

Need inspect "logic.mqh/exits.mqh stay production — no _r1 fork." But signal.mqh is stale? The spec says "NEW unified fxmatrix_v2_l0_signal.mqh (unified L0 dispatch with easing)" and "logic.mqh/exits.mqh stay production." It doesn't mention signal.mqh. It says "NOT the pre-ADR V2_ComputeBcBid/V2_ComputeAbBidOffer helpers (fixed multiplier, no floor)." Need ensure new L0 signal header may replace signal.mqh or be added. Current production includes signal.mqh but does not use V2_ComputeBcBid/AbBid? Actually EURGBP uses V2_CopyM5Closes, V2_FvSigmaFromCloses, V2_MidNowFromSymbol from signal.mqh. GBPUSD/EURUSD use only V2_EffectiveSpreadMultiplier, V2_L0ResolveLiveSpreadPrice, V2_L0DynamicHalfSpread from signal.mqh. So signal.mqh is used for helpers. Unified new L0 signal header should probably include/reuse signal.mqh? Need avoid duplicate definitions of V2_EffectiveSpreadMultiplier etc. If new header defines V2_L0ComputeBid and uses V2_EffectiveSpreadMultiplier, it can include signal.mqh or contain those helpers. Need not.

Need identify "schema mismatch" in spec: "The engine in turn uses logic.mqh, exits.mqh, telemetry.mqh, a NEW unified fxmatrix_v2_l0_signal.mqh (unified L0 dispatch with easing), and cap headers included per preset profile." If new L0 signal header supersedes signal.mqh, then spec should say whether signal.mqh is still included. The "Production surprises #5: logic.mqh/exits.mqh stay production — no _r1 fork." It omits signal.mqh. Need ask. But not necessarily blocker.

Need audit "V2PairPreset struct" fields. Need include:
- identity: symbol, telemetry instance names, EA name, magic numbers
- signal: V2SignalSlot enum, leg symbols
- L0 deadband flag and reference spread
- easing defaults
- V2CapProfile enum

Missing fields to preserve exact production:
- `MM_LONG_V2_EXIT`/`MM_SHORT_V2_EXIT` magic numbers derived from entry magic + offset 2. Could be derived from identity magic.
- `V2_PAIR_SPREAD_PIPS_REF` for deadband scaling (EURUSD 0.18, EURGBP 0.63? Wait code: EURUSD V2_PAIR_SPREAD_PIPS_REF 0.18, EURGBP 0.63. Logic uses V2_L0_DEADBAND_VOL_REF_PIPS 0.64 as anchor. GBPUSD has no ref because no scaling. In spec, "L0 deadband flag and reference spread" should include reference spread. For GBPUSD, no ref? Could set ref=0.0 and flag false. For EURUSD, flag true, ref=0.18. For EURGBP, flag false? Production EURGBP has V2_PAIR_SPREAD_PIPS_REF 0.63 but does NOT use it in V2_L0RestingWithinDeadband (no fifth arg). Wait EURGBP code has define V2_PAIR_SPREAD_PIPS_REF 0.63 but Long_ReplacePendingBuy calls V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult) without ref. So EURGBP's reference spread is unused. This is important: spec says "L0 deadband flag and reference spread" per pair; for EURUSD only flag true. Need preserve: EURGBP should not apply deadband vol-scale despite having define. The preset must set deadband flag false for EURGBP. If spec uses "reference spread" for all pairs, need ensure not accidentally applied to EURGBP. Let's verify: In EURGBP, `V2_PAIR_SPREAD_PIPS_REF 0.63` exists but not used. Could have been intended but not. Unified must not apply it. Good catch. Need flag.

- `InpL0DeadbandMult` input exists all pairs. Good.
- `InpL0DeadbandVolScale` input only EURUSD. Preset flag maybe from input? But input overrides? In production EURUSD, `InpL0DeadbandVolScale = true` is an input, so user can turn off. Unified engine must allow runtime override. If preset has flag and input also, need resolution.

- `InpQuoteSpread` default 0.0004 all pairs. Good.
- `InpSpreadMultiplier` 0.5 all.
- `InpEaseDepthStart` 1 all; `InpEaseDepthFull` 3/4/3 per pair.
- `InpSpreadMultiplierEased` 0.0 all.
- `InpPassivityBuffer` 0.5 all.
- `InpAddPipsFloor` 9.0, InpExitPips 3.0, WidenRatio 1.304, AddPipsCeiling 1000.0, LotSize 0.01, MaxLayers 20 all.
- `InpRolloverRetryMinutes` 10, MaxRetries 15 all.
- `EnableTelemetry`, TelemetryURL, APIKey, IntervalSec all.

Need maybe magic numbers:
- GBPUSD: MM_LONG_V2=20260901, MM_SHORT_V2=20260902, exit = +2 (20260903/20260904). Telemetry? V2_TEL_INSTANCE_LONG maybe "MM_LONG_GBPUSD"? Need not know.
- EURUSD: 20260911/20260912; EURGBP 20260921/20260922. Yes.

Need inspect "V2_EA_NAME" in Eurusd/Eurgbp but no use? Maybe in telemetry? Not in provided snippets except define. Fine.

Need audit "V2_ProcessCloseByQueue" in exits.mqh has a bug? It uses `halted` parameter by reference and sets true on same-direction exhaustion. In Long_OnTick, passes g_long_halted. Good. Unified engine must preserve. Not relevant.

Need audit "Long_HandleDealFill" in production does not call `V2_ProcessCloseByQueue` on fills; queue processed in OnTick. Good.

Need identify "silent failures" in production? Unified spec should not introduce. But need maybe "parity exact" with `V2_STATS` counts: In Long_RemoveLayerAt, `g_long_stat_exits++` increments for any layer removal, including if exit fill with no matching layer? No. Fine.

Need think of "lookahead bias" in L0 signal: `bc_now = closes[0] + half`. `closes[0]` is the most recent completed bar at the time CopyClose with start position 1 returns closes[0]? In MQL5, CopyClose(symbol, timeframe, start_pos=1, count=60) returns 60 elements from bar 1 to 60, and ArraySetAsSeries true sets [0] to bar 1, [1] to bar 2, etc. So closes[0] is the last closed bar (one bar ago), not current forming. Good. `c6` = closes[6] = bar 7? Actually [6] is 7th element, bar 7? Wait with start_pos=1 and count=60, as series, element 0 corresponds to shift 1, element 1 shift 2, ... element 6 shift 7. So c6 is close 7 bars ago? Let's calculate: c6 = closes[6] => shift=7? Because ArraySetAsSeries true and CopyClose returns timeseries with oldest at end. The element index equals shift offset from start? If start_pos=1, the first returned element is bar with index 1 (last completed). So closes[6] is shift 7. That means FV weights closes at shifts 7, 13, 49. The comments in signal.mqh say "BC native term-structure" maybe. This is production. No lookahead.

Need audit "signal path (BC native vs AB triad)" in unified preset. Need ensure "BC native" includes EURUSD and GBPUSD; "AB triad" EURGBP. Yes.

Need check "spread-easing thresholds (ADR-097: 1/3, ADR-098: 1/4, ADR-099: 1/3)" in spec: "ADR-097: 1/3, ADR-098: 1/4, ADR-099: 1/3" likely yes.

Need maybe check "cap module wiring (GBP-only, EUR-only, dual)" and "No cross_exposure_cap.mqh." Good.

Need answer Claude question 2: Does unification survive EURGBP's genuine differences or just relocate branching? Need trace through actual production code. We need provide a concrete trace. Need use production code, not spec's self-description. Need analyze shared engine structure.

Let's define unified engine would have generic `Long_OnNewBar`:
- call `V2_L0ComputeBid(preset, ctx, bid_theoretical)`.
- `V2_L0ComputeBid` has branch on `preset.signal_slot`:
  - BC_NATIVE: use _Symbol closes, fv/sigma, `bc_now = closes[0] + half`, r, effective multiplier based on opposite_depth if own stack flat, dynamic_hs, bid = fv * exp(r - hs).
  - AB_TRIAD: use leg symbols, fv_ac/sig_ac, fv_bc/sig_bc, ac_now/bc_now, inst_spread, ratio, same easing/dynamic_hs, bid = ratio * exp(inst_spread - hs).
This is a branch inside dispatch. Is that "duplication in a different shape"? It is a real second signal path; cannot be parameterized away because math differs. But it is localized in one function, not scattered. The rest of engine (place orders, exits, layers, deal handling) is identical. So unification survives to the extent that all other behaviors are identical. Need be careful: "survive EURGBP's genuine differences" yes, with one clearly bounded branch for signal computation; no `if (pair == EURGBP)` in engine body outside signal dispatch and cap bridge. Need trace:
  - Long_EnsureAddNext: In production, GBPUSD calls GBP cap; EURUSD calls EUR cap; EURGBP calls `V2_AnyCapBlocksNewAdd`. Unified engine should call `Engine_CapBlocksNewAdd(preset, is_long, ...)` which branches on cap_profile. That's a second bounded branch. But if engine's `Engine_CapBlocksNewAdd` contains if/else, that's okay? It is a cap dispatch. Need ensure no scattered conditionals.
  - Deadband: In `Long_ReplacePendingBuy`, GBPUSD/EURGBP call no vol-scale, EURUSD calls with ref. Unified engine should call `V2_L0RestingWithinDeadband(..., preset.l0_deadband_vol_scale ? preset.pair_spread_pips_ref : 0.0)`. That is a parameter, not branch in engine body.
  - OnInit cap publish: same via cap bridge.
  - Signal: branch in dispatch.
  - `InpLegAC/InpLegBC` runtime inputs: only EURGBP shell declares them; signal dispatch uses them via preset? Need design. But not scattered.
So answer: Yes, if the design maintains the invariant that all `pair ==` branches live inside the signal dispatch and cap bridge; the spec must explicitly forbid pair-label conditionals elsewhere. Need note "pair == EURGBP" conditionals in engine body would be a smell. Need require a static test that scans engine body for pair-label literals outside whitelisted files. Good.

Need maybe identify "preset struct with V2SignalSlot enum" is analogous to branch; not duplication. Good.

Need answer Claude question 4: ADR-102/103 need traced. We need confirm from actual production source that full sequencing preserved in proposed engine. Let's trace.

ADR-102:
- In production `OnTradeTransaction`:
```
if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
Long_HandleDealFill(trans.deal, trans.position);
Short_HandleDealFill(trans.deal, trans.position);
```
- In `Long_HandleDealFill`, after dedup, HistoryDealSelect, symbol filter, extract fields, MarkDealProcessed, compute is_long_entry and is_long_exit using magic checks, then if halted and managed, emit alert and return; no append/remove/cap sync/closeby.
- If unified engine holds this function, it must preserve exactly this order. The spec says "per-side gate after deal-ownership validation (symbol + magic), not before" and "MarkDealProcessed on halted path." The spec's bullet "halt gate (ADR-102)" is not enough; implementation must copy the above. Need require a checklist test. We can say no blocker if the engine is a straight extraction; but need confirm no "reference" architecture. The spec's section 5 says "OnTradeTransaction ... halt gate (ADR-102)" as a bullet, not detailed. Need flag as "must be explicitly sequenced in engine" with exact order.

ADR-103:
- In production OnInit:
  1. `V2_ApiCounterMaybeReset()`; pod resets; telemetry reset; Long_OnInit(); Short_OnInit();
  2. orphan scan for long/short, setting halt flags and orphan flags.
  3. `if(V2_ShouldPublishCapSyncOnInit(long_orphan)) V2_GbpCapSyncInstance(...)` etc.
  4. If partial/both, emit telemetry if enabled.
  5. If both orphan, return INIT_FAILED; if partial, warning; return `V2_OnInitResultFromOrphanFlags`.
- No trigger GV reset anywhere.
- Unified engine's OnInit must preserve: `Long_OnInit`/`Short_OnInit` called before orphan scan? Yes production. Orphan scan after both init. Cap publish after orphan scan and per-side. No trigger reset. Also "partial halt: clean side publishes, halted side skips." Need preserve.
- Need note "Long_OnInit" initializes layers to empty; orphan scan uses ArraySize(g_long_layers) (0) to detect orphan. If unified engine moves init into engine, same.
- Potential issue: If engine uses `g_preset.cap_profile` and cap bridge, `V2_SyncAllCaps` for EURGBP calls both; for single-profile, only one. ADR-103's "per-side cap publish via V2_ShouldPublishCapSyncOnInit" must be invoked with the correct cap module. Good.

Need identify "ADR-101" trace:
- In OnTick, order: `V2_ApiCounterMaybeReset(); V2_RunDailyRolloverReconciliation(); V2_RunRolloverRetryPasses(); Long_OnTick(); Short_OnTick(); V2EmitTelemetry(false);`
- `V2_RunDailyRolloverReconciliation` consumes daily gate, resets retry states, builds slots, runs side pass for long and short, applies slots.
- `V2_RunRolloverRetryPasses` runs after daily reconciliation each tick, only if pending.
- Unified engine must preserve order: daily reconciliation before retry passes, before ticks. Spec says "rollover reconciliation + retry (ADR-101)" as bullet. Need confirm.

Need perhaps identify "LRU? no".

Need answer Cursor's open questions:
- context struct sufficiency
- shared half-spread helper
- cap include strategy
- deterministic parity tolerance
- include-guard risks

Let's address each.

Context struct sufficiency:
Need assess if V2L0SignalContext fields enough. Let's list production signal dependencies:
- For BC:
  - quote_spread (InpQuoteSpread)
  - sigma and fv from closes
  - half spread (ask-bid)/2
  - bc_now (closes[0]+half)
  - r_bc
  - own flat (ArraySize(g_long_layers)==0)
  - opposite_depth (ArraySize(g_short_layers))
  - ease start/full, multiplier, eased
  - live_spread_price (from quote_spread and current symbol spread)
  - passivity_buffer_price (from InpPassivityBuffer)
  - sign for bid/offer
- For AB:
  - leg symbols AC/BC (runtime InpLegAC/InpLegBC)
  - for each leg, closes, fv, sigma, now (mid from bid/ask + fallback)
  - inst_spread = r_ac - r_bc
  - ratio = fv_ac/fv_bc
  - sigma = MathMax(sig_ac, sig_bc)
  - same easing/dynamic_hs
  - sign
Context struct should include:
  - quote_spread
  - spread_multiplier, eased
  - ease_depth_start/full
  - passivity_buffer_price (not pips maybe)
  - opposite_depth
  - quoting_side_flat
  - leg symbols
Maybe not need `passivity_buffer_pips` if price included; but if pidgin. Need include `point`? Production uses `_Point` and `Long_PipsToPrice`; could use `point` from symbol. Need include `spread_quote?` no.
Need include `symbol`? The engine's `_Symbol` is chart symbol; for BC, use _Symbol. For AB, leg symbols. Maybe context should include `ab_symbol` if not _Symbol? Production uses _Symbol for chart and leg symbols for other. Not necessary.
Need include `live_spread` or `live_spread_price`? `V2_L0ResolveLiveSpreadPrice` uses `_Symbol` and static last valid. Could be computed in dispatch. Context could include live_spread_price, but if you want testable pure function, pass it in.
Need include `opposite_depth` and `quoting_side_flat`; yes.
Need include `leg_symbols` for AB; maybe `leg_ac`, `leg_bc`.
Potential missing fields:
- `is_long` direction? Separate bid/offer with sign.
- `passivity_buffer_price` and `passivity_buffer_pips` redundant.
- `halve_spread` raw? no.
- `last_valid_spread` static cannot be in context if pure function? Could pass in/out. Maybe not.
- `pair_label`? For signal not needed.
- `L0DeadbandVolScale` not signal; used in L0 replace, not compute.
Need answer: context is sufficient if it includes leg symbol runtime strings and passivity price; but it must not duplicate production's hidden use of `_Symbol` and `_Point` in a way that breaks unit tests. Need define a pure core that takes all market data (closes, bid/ask) as inputs to be testable without broker calls. The spec's `V2_L0ComputeBid(preset, ctx, out bid)` could still call CopyClose/SymbolInfo internally; that's not fully unit-testable. Better separate pure `V2_L0ComputeBidFromMarketData` from wrapper. But spec says unit tests extended for V2_L0Compute* — if it calls broker functions, unit tests in MQL5 test harness can mock? MQL5 doesn't easily mock CopyClose. So for unit tests, need a pure function accepting closes/bid/ask/live_spread. Need flag "context struct sufficiency" includes no market data inputs; unit tests would be impossible unless you add a pure core with closes arrays as parameters. This is an important architectural gap.

Shared half-spread helper:
Production computes `dynamic_hs` with `V2_L0DynamicHalfSpread` and `V2_EffectiveSpreadMultiplier`. Already helpers. Need suggest share exactly these, not recreate. Need also share `V2_ResolveLiveSpreadPriceFromRaw` for testability. Good.

Cap include strategy:
Need address include guard risks. If engine includes gbp_cap/eur_cap/dual_cap depending on profile, include guards have no dependencies. But if per-shell includes only needed headers, engine cannot call all. Need design:
- Option A: engine contains no direct cap calls; per-profile bridge functions in shell/preset fragment implement `Engine_CapBlocksNewAdd`, `Engine_CapSyncInstance`, `Engine_CapRecordBlock` using only included cap headers. Then each shell includes only its cap headers and defines bridge. This preserves spec.
- Option B: all shells include all cap headers, engine switch works. But spec says only needed headers; choose A.
Need also "cap include strategy" for dual cap: `eurgbp_dual_cap.mqh` itself includes gbp_cap and eur_cap, so EURGBP shell only includes dual +? It includes gbp/eur directly too in production. Fine.
Need mention include-guard risks:
- `fxmatrix_v2_eurgbp_dual_cap.mqh` includes gbp_cap and eur_cap; if engine includes all, no problem due guards.
- If engine .mqh includes cap headers and shell also includes them, guards prevent duplicate.
- If new L0 signal header includes signal.mqh and shell includes signal.mqh, guards prevent duplicate.
- Need ensure `MM_LONG_V2`/`MM_SHORT_V2` are defined before logic.mqh include because logic.mqh has default #ifndef. In current GBPUSD, logic.mqh defines defaults; but if shell defines preset before include, okay. Need if engine includes logic.mqh before shell defines magic? Shell must define preset before include. Need specify. This is a classic include-order risk. The spec says shell defines preset then includes engine. Need ensure engine includes logic after preset definitions. If engine needs `MM_LONG_V2_EXIT`, logic.mqh derives from MM_LONG_V2. If shell defines `MM_LONG_V2`, okay. But preset struct stores magic as field; engine may also use `MM_LONG_V2` macro directly in many places. To unify, better replace all macro references with `g_preset.magic_long` or local constants. If engine still references `MM_LONG_V2`, the shell must define that macro. The spec's preset struct includes magic numbers but doesn't say whether macros remain. Need flag: either keep macros for MQL5 compile-time (e.g., `MM_LONG_V2_EXIT` used in `V2_ProcessCloseByQueue` call? Actually `Long_OnTick` passes `MM_LONG_V2`; `V2_SendExitLimit` passes `MM_LONG_V2_EXIT`; `V2_IsManaged...` passes `MM_LONG_V2`). If engine uses `g_preset.magic_long`, no macro needed. But `MM_LONG_V2_EXIT` can be derived. Need decide. If both, risk divergence. Recommend engine uses only preset fields, and preset fragment macros are only used to initialize compile-time struct? But `input` defaults? Need specify.

Need audit "V2CapProfile enum [GBP_ONLY/EUR_ONLY/DUAL_GBP_EUR]" with "cap headers included per preset profile." Need maybe define "cap profile" not by enum switching but by function pointers? MQL5 supports function pointers? Yes but complex. Better bridge.

Need answer "deterministic parity tolerance" as above.

Need "Any assumption in spec that doesn't hold once checked against real production source." Need enumerate:
1. Spec says "Pair-specific `#define` constants (magic numbers, telemetry labels)" — but production also has runtime `input` differences beyond defines; spec acknowledges. However "Three thin shells ... each define a compile-time V2_PAIR_PRESET struct" conflicts with runtime inputs needing per-shell declarations. Need specify.
2. Spec says "EURUSD-only L0 deadband vol-scale" — yes, but note EURGBP has `V2_PAIR_SPREAD_PIPS_REF` 0.63 unused. Preset must not enable deadband scaling for EURGBP.
3. Spec says "cap headers included per preset profile" — cannot work with engine switch if only needed headers included. Need bridge.
4. Spec says "new shells get distinct names or replace production only after parity gate" — but .set compatibility: adding/removing inputs changes .set. Need account.
5. Spec says "parity ... exact" — for floats, need tolerance and deterministic setup.
6. Spec says "easing defaults locked ... overridable via input" — no resolution mechanism. Need design.
7. Spec says "V2PairPreset struct ... values copied verbatim from current production" — but GBPUSD production has hardcoded magic numbers in some paths; "copied verbatim" could preserve hardcoded values instead of preset. Need not copy hardcoded; centralize.
8. Spec says "signal is inlined in production, not helper-called" — true.
9. Spec says "EURUSD vol-scale deadband is orthogonal to signal dispatch (L0 replace path)" — true, but unified L0 signal context doesn't include deadband; L0 replace path must use preset separately. Good.
10. Spec says "logic.mqh/exits.mqh stay production — no _r1 fork" — okay.
11. "No cross_exposure_cap.mqh" — okay.
12. "Rollover reconciliation + retry (ADR-101)" — in production it is in .mq5, not carry.mqh? The shared engine should include.

Need maybe check "V2_L0DynamicHalfSpread" implementation in signal.mqh:
```
return MathMax(quote_spread + sigma * effective_multiplier,
               live_spread_price + passivity_buffer_price);
```
Production inlined calls with `V2_L0ResolveLiveSpreadPrice(InpQuoteSpread)` and `Long_PipsToPrice(InpPassivityBuffer)`. This is "live_spread + buffer" floor. Good.
Need note "V2_L0DynamicHalfSpread" uses quote_spread (0.0004) as base, not `live_spread_price`; so if live spread is below quote_spread, floor uses quote_spread + sigma*mult. Good.

Need identify potential "statistical flaw" in proposed parity: "canonical windows (truss_crisis, full_quarter, EURGBP + june_blowup)" if not defined. Need flag.

Need perhaps audit "Model=4" in Strategy Tester. In MT5, model "Every tick based on real ticks" is 0? Actually MT5 testing models: 0 = every tick based on real ticks, 1 = every tick, 2 = 1 minute OHLC, 3 = open prices? Let's recall: In MetaTrader 5 Strategy Tester, "Every tick based on real ticks" = 0, "Every tick" = 1, "1 minute OHLC" = 2, "Open prices" = 3? Hmm maybe. Actually MT5 has "Every tick based on real ticks" (0), "Every tick" (1), "1 minute OHLC" (2), "M1 bars" (?), "Open prices" (3). The spec says "Model=4" maybe in MT4? Need not. But "Model=4" could be "Every tick based on real ticks" in some contexts? Let's not assume; but can flag that if model number wrong, parity invalid. Need know? In MT5, `ENUM_TESTING_MODEL` values: TEST_MODEL_EVERY_TICK = 0, TEST_MODEL_CONTROL_POINTS = 1, TEST_MODEL_BAR_OHLC = 2, TEST_MODEL_OPEN_PRICES = 3, TEST_MODEL_MATH_CALCULATIONS = 4? Actually maybe. I should not assert. But "Model=4" might be "math calculations" not real ticks, which would not capture spreads. Need verify from docs? Not available. Could flag "Model=4 must be explicitly identified by enum name, not number; if it is not real-tick, parity won't test spread-dependent logic." But the request says no implementation code, but can mention. Need be careful.

Need audit "V2_L0ResolveLiveSpreadPrice" uses static `g_last_valid_spread_price`; in Strategy Tester, `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` may be fixed or variable depending on model. If Model=4 not real ticks, live spread may be constant and deadband/easing floor not tested. Parity gate with wrong model could pass while live behavior differs. Need flag.

Need perhaps inspect "side-by-side Strategy Tester, production vs unified shell, Model=4, identical .set" — if model is not "every tick based on real ticks", it may not exercise pending order fills accurately. Need include "use real-tick model with actual spread data."

Need answer "lookahead bias" in spec? Maybe "unified L0 signal dispatch with native easing" uses `opposite_depth` from `ArraySize(g_short_layers)` at time of signal. This is current state, not future. No lookahead. But "parity exact" with backtest: using `TimeCurrent()` in pod/telemetry and `TimeGMT()` can differ? Not lookahead.

Need audit "silent failures" in unified spec:
- If input overrides not resolved, could silently use wrong default for one pair. This is the biggest. Need specify mechanism with fail-fast validation.
- If preset struct and input defaults are both present, need runtime validation in OnInit to compare? But if input is intentionally overridden, comparing to preset is wrong. Need define resolution: runtime inputs are the sole source of truth for overridable behavioral parameters; preset only supplies non-input compile-time constants and default values for input declarations. To prevent mismatch, generate input defaults from same macros. And add OnInit validation that all behavioral inputs are within allowed ranges (already ease depth check). For per-pair locked defaults? But they are overridable via inputs, so no "locked" if user changes. If some defaults must be locked (e.g., cap profile, signal slot), not inputs. Need distinguish "locked" ADR thresholds are defaults, not hard requirements. The spec says "ADR-097/098/099 locked different default easing thresholds per pair that must be overridable via input." So default not lock. Good.

Need maybe "silent failures" in cap bridge: If cap profile enum wrong or bridge missing, compile error maybe. But if using `if (g_preset.cap_profile == DUAL_GBP_EUR)` and `V2_AnyCapBlocksNewAdd` only defined in dual cap header, and shell for GBPUSD doesn't include dual, compile error if engine references it. This is not silent but blocks. Need resolve.

Need perhaps "schema mismatch" between spec's "V2CapProfile enum" and actual production's cap "thresholds inputs". Actual cap heads:
- `V2_GbpCapBlocksNewAdd(pair_label, is_long, threshold)` and `V2_GbpCapSyncInstance(pair_label, is_long, layer_count)`.
- `V2_EurCapBlocksNewAdd` same.
- `V2_AnyCapBlocksNewAdd(is_long, gbp_threshold, eur_threshold)` for EURGBP.
Unified engine's `Engine_CapBlocksNewAdd()` must know which threshold input(s) to use. If it switches on cap_profile and reads `InpGbpCapThreshold`/`InpEurCapThreshold`, all shells need both inputs. If instead shell provides a function `Engine_CapBlocksNewAdd` that uses its own inputs, then preset enum not needed for cap dispatch? But spec wants enum. Need decide.

Need maybe "cap profile enum" unnecessary if bridge functions per shell; the preset can still hold cap_profile for telemetry/validation, but dispatch uses bridge. Need mention.

Need answer "Do we need three shells or can one shell with input pair?" Spec says three binaries because compile-time capabilities and magic numbers differ. But could a single parameterized binary with all cap headers and runtime pair selection work? Since MT5 chart can be EURGBP, but magic numbers and telemetry labels need pair constants; they could be derived from `_Symbol` at runtime. Default inputs could be set via .set. Cap headers all compiled. Why need three binaries? Magic numbers can be assigned from symbol in OnInit. But current ADRs and risk require pair-specific magic? Actually if one EA attached to any chart, it could define magic based on symbol. However existing production uses three binaries and VPS deployment. The spec says three shells remain because MT5 attaches one EA binary per chart instance — magic numbers, default inputs, and compile-time cap includes differ per pair. But if you parameterize by symbol, you might only need one binary. Gemini mandated "unified engine from current production as sole reference" and "three thin shells" because pair-specific magic and cap includes? The spec's reason "compile-time cap includes differ per pair" is weak if all cap headers can be included. But maybe risk of running wrong cap profile? Need audit: Is "three shells" actually necessary? Magic numbers could be derived from `_Symbol` or a `V2_PAIR_PRESET` selected at runtime. Default inputs could be initialized based on symbol in OnInit (if inputs have generic defaults). Cap profile can be selected at runtime. The only true reason for separate binaries is if you need different `input` defaults in the GUI/Strategy Tester without manual .set. But you can have one EA with inputs and a `Select pair` input? Not the same. However current production has already three .ex5. Gemini ruling says "three thin shells ... deployment artifacts, not logic duplicates." So we shouldn't challenge too hard, but can note "the spec asserts three binaries are required; from a pure logic standpoint they are not, because magic/cap can be runtime-selected. But if the goal is preserving existing deployment and input defaults, shells are acceptable. This is a schema decision, not a blocker." But the role asks to flag assumptions that don't hold. Need include.

Wait, "Gemini's ruling (2026-08-02) directed abandoning stale `_ref` branch and building a genuinely unified, parameterized engine from current production as the sole reference; the specification below is Cursor's first draft against that mandate." The mandate says "parameterized engine." Maybe one shared engine + shells. So okay.

Need audit "production consists of three ~1,600-line .mq5 files structurally identical except pair-specific..." Actually EURUSD file has `Long_ComputeBidSignal` inserted after short stats and before Short_PipsToPrice, causing duplicate? In provided EURUSD, there is `bool Long_ComputeBidSignal` defined in middle of file after `g_short_processed_count;`, then later? Let's inspect: In fxmatrix_v2_eurusd.mq5, there is a `bool Long_ComputeBidSignal` after `int g_short_processed_count;`, but earlier in file there is no Long_ComputeBidSignal before Long_OnNewBar? Wait Long_OnNewBar calls Long_ComputeBidSignal, and later definition appears after short globals. In MQL5, functions can be called before definition? MQL5 requires declaration before use? The compiler may allow definitions anywhere? Actually MQL5 is C-like, functions must be declared before use? It might search whole file? I think MQL5 allows functions defined later? Not sure. In provided EURUSD, Long_ComputeBidSignal is defined after Long_OnNewBar and globals, so maybe compiler handles. This is a weird duplication/ordering. The unified extraction must be careful.

Need check "EURUSD file includes `#define V2_PAIR_SPREAD_PIPS_REF 0.18` and `InpL0DeadbandVolScale`; but Long_ComputeBidSignal is identical to GBPUSD (no vol-scale). Deadband vol-scale used only in L0 replace and l0_lag diag." Yes.

Need inspect "EURGBP file uses `Long_ComputeBidSignal` defined after short globals and before Short_PipsToPrice; short uses `Long_PipsToPrice` in dynamic_hs for both? In Short_ComputeOfferSignal uses `Long_PipsToPrice(InpPassivityBuffer)` not Short_PipsToPrice. That's a bug? In EURGBP Short_ComputeOfferSignal:
```
double dynamic_hs = V2_L0DynamicHalfSpread(
      InpQuoteSpread,
      MathMax(sig_ac, sig_bc),
      effective_multiplier,
      live_spread_price,
      Long_PipsToPrice(InpPassivityBuffer));
```
Uses Long_PipsToPrice, which is same as Short_PipsToPrice (both pips * _Point * 10), so no difference. Fine.
Need note "V2_MidNowFromSymbol" in signal.mqh uses `fallback_close + (ask - bid)/2.0` — This is not the actual midpoint if `fallback_close` is previous close and current bid/ask differ. It is `previous close + half spread`, not `(bid+ask)/2`. In production, for BC, `bc_now = closes[0] + half`, same. For AB, `ac_now = ac_closes[0] + (ask_ac - bid_ac)/2`, and for BC `bc_now = bc_closes[0] + (ask_bc - bid_bc)/2`. This means the "current" value is anchored to last close plus half spread, not current mid. Is that intended? Maybe to avoid lookahead? Actually using last close + half spread approximates current mid if last close is mid? But closes are close prices (bid? In MT5, close is bid? For forex, close price is bid). `closes[0] + half` gives last bid close + current half spread = approximate current ask? Wait if closes[0] is bid close, adding half spread gives something near current mid/ask? Let's think: At the time of last bar close, close price is bid. Current bid may differ. Using old bid close + current half spread gives old bid + half current spread. That is not current mid. But maybe production intentionally uses "bc_now" as "fundamental current" from last close + half spread to capture spread? Need not.

Need perhaps flag this in unified spec? It says "must extract from production .mq5 inlined logic, NOT signal.mqh stubs". Good.

Need audit "V2_ComputeBcBid" in signal.mqh uses `dynamic_hs = quote_spread + sigma * spread_multiplier` (no live spread floor) and `now = V2_MidNowFromSymbol(symbol, closes[0])` (same weird). Production inlined uses same `bc_now = closes[0] + half` and L0DynamicHalfSpread. So difference is dynamic_hs. Good.

Need maybe identify "V2_L0SignalContext struct has `passivity_buffer_pips` and `passivity_buffer_price` both; if both are present, need define which is authoritative. Production uses price computed from pips. For unit tests, use price. Redundant fields can silently diverge. Flag.

Need maybe "V2_L0SignalContext struct includes `quote_spread`, but `V2_L0DynamicHalfSpread` also uses `live_spread_price` from `V2_L0ResolveLiveSpreadPrice` which has static state. If context is reused across ticks, no issue. But if `V2_L0ComputeBid` called multiple times per tick? OnNewBar only once per bar. Fine.

Need "opposite_depth" in context: production uses `ArraySize(g_short_layers)` for long and `ArraySize(g_long_layers)` for short. In unified engine, `Long_OnNewBar` and `Short_OnNewBar` call same signal dispatch with different context. Need ensure "quoting_side_flat" = own layers == 0 and "opposite_depth" = other side layers count. Good.

Need perhaps "V2_L0ComputeBid/Offer" should take `own_stack_flat` as bool; if `g_long_layers` empty but `g_short_layers` maybe also empty, effective_multiplier remains base. Good.

Need audit "V2_EffectiveSpreadMultiplier" if `ease_depth_full == ease_depth_start` could divide by zero. OnInit validates full > start. Good. If input override invalid, fail. Good.

Need perhaps "unified engine with `g_preset` for all pair-specific behavior" but production has `Long_OnInit` print `"INFO: fxmatrix_v2_long init magic=..."` vs EURUSD `"INFO: fxmatrix_v2_eurusd_long init magic=..."` vs EURGBP. If logs differ, parity? Not critical. Need preserve if tests compare logs.

Need answer "What should block spec from proceeding?" Need list "BLOCKERS" and "NON-BLOCKING". Need be direct.

Let's formulate final response.

Need avoid implementation code. We can mention code identifiers and functions—not code blocks? The prompt says no implementation code. We can reference function names and structs, but not provide code. That's okay. Need not produce code snippets. Should avoid code with semicolons? We can name. We can include minimal identifiers. The final answer should be prose.

Need maybe structure:
- Verdict
- Blockers
  1. Input-override resolution undefined (Claude Q1).
  2. Cap include strategy inconsistent with engine dispatch; will not compile as written.
  3. Runtime inputs and preset fields create two sources of truth; need single macro-derived defaults.
  4. Unit-testability of V2_L0Compute* impossible with broker calls; need pure core.
  5. Parity "exact" vs tolerance; canonical windows undefined; model enum ambiguity.
  6. Magic number hardcoding in production not captured by preset; "copied verbatim" risks preserving it.
  7. EURGBP deadband ref unused; preset must not enable.
- Claude Q2 trace: yes with bounded dispatch, but need static rule.
- Claude Q4 trace: ADR-102/103 must be copied exactly; checklist.
- Answers to Cursor open questions.
- Assumptions that don't hold.

Need be exhaustive but not too long? Desired oververbosity 5. But user asks exhaustive. Need produce thorough.

Need include "lookahead bias" check: none seen in production signal path; unified extraction must not reorder closes or use current bar. Need mention `CopyClose(...,1,60)` starts at closed bar; preserve exactly. Also `V2_MidNowFromSymbol` uses last close + half spread; do not "fix" it during extraction. Any "improvement" to current mid would be a behavioral change. Good.

Need mention "silent failures": input/preset mismatch, cap bridge, magic hardcoding are silent.

Need maybe mention "schema mismatch": preset struct missing exit magic derivation, missing `MM_LONG_V2_EXIT` etc; if engine uses macros, not struct.

Let's craft details.

Need think through cap include strategy with example:
- Suppose `fxmatrix_v2_engine.mqh` has a switch:
```
switch (g_preset.cap_profile) {
 case GBP_ONLY: V2_GbpCapSyncInstance(...); break;
 case EUR_ONLY: V2_EurCapSyncInstance(...); break;
 case DUAL: V2_SyncAllCaps(...); break;
}
```
For GBPUSD shell, which includes only `fxmatrix_v2_gbp_cap.mqh`, the call to `V2_EurCapSyncInstance` is undeclared -> compile error. Therefore either engine must see all cap headers, or cap calls must be delegated to a per-profile bridge defined in the shell. The spec explicitly says engine uses a switch on profile; this contradicts "shell includes only cap headers its profile needs." Need choose one. We can say "This is a hard blocker because the document as written cannot compile."

Need maybe mention "MQL5 include guards are not a substitute; they prevent duplicate definitions, not missing definitions."

Need input resolution:
- `input` variables cannot be initialized from a struct field in MQL5. The spec doesn't define how "preset default" and "input default" relate. If the shell writes `input int InpEaseDepthFull = 3;` and the preset fragment also sets `g_preset.ease_depth_full = 3`, there are two copies. A future edit to one without the other is a silent behavioral change. Need define a single source: use preprocessor constants in the preset fragment to set both the struct and the input default, e.g., `#define V2_EASE_DEPTH_FULL_DEFAULT 3` and use in both. Then runtime input is used everywhere after OnInit; the struct field can be omitted for overridable values or used only as a fallback. Need include fail-fast `OnInit` assertion? MQL5 has no static_assert? It does. But dynamic validation: if `InpEaseDepthFull <= InpEaseDepthStart` fail (already). For locked pair constants like signal slot/cap profile, no input override.

Need maybe "What happens if shell's input value and preset default disagree?" If input is user override, input wins. If no user override, input should equal default. But if they disagree because code changed one not the other, you can't distinguish user override from drift. To eliminate, don't store overridable values in preset at all; store only in input defaults generated from same macro. If you want preset to hold "spec default" for telemetry/DIAG, add an OnInit warning when input differs? That would be noisy. Better single source.

Need answer "Does 'easing defaults overridable via input' mean preset not needed for easing?" We can say yes.

Need parity tolerance detail:
- Discrete outcomes (order count, layer count, stats, max layers, peak net lots) must be exactly equal.
- Normalized order prices must be exactly equal at the symbol's tick/point precision; use `NormalizeDouble(price, digits)` and compare as integers? If both normalize to same digits, exact.
- Internal float calculations not directly observable except through order prices and DIAG logs. DIAG logs can differ in last ulp and still be behaviorally equivalent, but if logs are compared, allow relative tolerance 1e-9 or compare parsed numeric fields within 1e-9.
- P&L: because it is read from deal fields, should be exact if deal sequence and prices match; if account currency differences, allow 0.01 units. But if "exact" means no tolerance, a refactor that changes operation order could change sigma by 1 ulp; when multiplied by 0.5 and added to quote_spread, then MathExp, then NormalizeDouble, it almost always normalizes to same price, but boundary cases can cross a normalization threshold. Thus exact normalized prices are the right bar, not exact raw doubles.
- Need define "peak net lots" exactly; production doesn't track, so maybe from report.

Need "canonical windows" define with dates. We can say "The names truss_crisis/full_quarter/june_blowup are not defined in the provided ADRs or code; the parity gate must specify UTC start/end, symbol, deposit currency, leverage, spread model, and data source. Otherwise the gate is not reproducible." Good.

Need "Model=4" maybe flag: "The method 'Model=4' is not defined in this document. Use the MT5/MT4 enum name from the test framework (likely real-tick model) and verify it replays actual spreads; otherwise easing and deadband parity are meaningless." Good.

Need "Lookahead" in parity: "Both production and unified must use same data source and same 'from bar shift' parameters. The new L0 dispatch must not change `CopyClose(..., 1, 60)` to `0`; that would introduce lookahead. The spec doesn't explicitly say preserve start position=1; add it."

Need maybe "V2_MidNowFromSymbol" uses fallback_close + half spread. If unified spec says "BC native closes to FV/sigma" and "ratio * exp(...)" okay. Need not.

Need "Magic hardcoding" detail:
In fxmatrix_v2.mq5:
- `Long_HandleDealFill`: `(long)20260901`
- `Short_HandleDealFill`: `(long)20260902`
- `Long_EnsureAddNext`: `20260901`
- `Short_EnsureAddNext`: `20260902`
- `Long_OnInit` print: `"magic=20260901"`
This means the "GBPUSD production file untouched" has hardcoded numbers. If the preset fragment copies values verbatim, these hardcoded numbers won't be replaced by `g_preset.magic_long`. Unified engine must sweep all magic literal references and route through preset/macro. Need add a grep test for magic literals outside preset fragment. Good.

Need "telemetry labels" defined by macros, but if engine uses `V2_TEL_INSTANCE_LONG` macro, shell must define before include. If preset has `telemetry_instance_long` field, engine should use `g_preset.telemetry_instance_long`. Need avoid both.

Need "leg symbol runtime overrides" detail:
EURGBP has `input string InpLegAC = "EURUSD"; input string InpLegBC = "GBPUSD";` and signal dispatch uses them. If unified engine's L0 signal header is a .mqh compiled into all shells, it cannot reference `InpLegAC` unless the symbol is declared in every shell or the signal context is populated by shell-specific code before calling. The preset struct can hold defaults, but cannot be an `input`. Need define a wrapper in shell that sets context.leg_ac from `InpLegAC` at call time? In MQL5, global input can be read. For BC shells, no InpLegAC input. To keep one engine, use a function `V2_GetLegAC()` defined by each shell? That's again bridge. Or declare `InpLegAC`/`InpLegBC` in all shells but hidden? Inputs appear in UI. Not ideal. Need flag.

Need "cap threshold inputs" similarly.

Need "L0 deadband vol scale input" only EURUSD; unified engine's `V2_L0RestingWithinDeadband` call needs a flag. Could use preset flag and ignore input override? But production has input override. If unified engine references `InpL0DeadbandVolScale`, only EURUSD shell has it; compile error in others. Need bridge or all-shell input.

Need perhaps "default inputs differ per pair" means shell-specific input declarations in the shell, not in engine. The engine can call wrapper functions defined in shell that capture input values. But then engine isn't fully shared? It is, but the wrappers are per-shell. Good.

Need maybe "preset fragment files carrying values copied verbatim" might become stale; need a unit test comparing preset values to production .mq5 AST? Hard. But for audit, just flag.

Need answer "Open for DeepSeek: context struct sufficiency" with "not sufficient unless pure core accepts market data; include own/opposite depth, leg symbols, passivity price, live spread; avoid redundant pips/price."

Need answer "shared half-spread helper" with "use production helpers V2_EffectiveSpreadMultiplier and V2_L0DynamicHalfSpread exactly; don't create another."

Need answer "cap include strategy" with "use per-profile bridge, not switch across all cap modules in engine."

Need answer "deterministic parity tolerance" as above.

Need answer "include-guard risks" with "order of defines vs logic.mqh; ensure `MM_LONG_V2` not defaulted by logic.mqh before shell defines it; engine must include logic after preset macros. Use guards but don't rely on them for dispatch."

Need perhaps mention "V2_PAIR_SPREAD_PIPS_REF" for EURUSD is 0.18 and logic anchor 0.64. Wait in logic `V2_L0_DEADBAND_VOL_REF_PIPS 0.64`. This means for EURUSD, deadband scaled by 0.18/0.64 = 0.28125, making deadband much narrower. That seems odd; maybe because EURUSD spread reference pips is 0.18 vs GBPUSD 0.64. If current spread is 0.4 pips? Not relevant. But unified preset must set ref=0.18 for EURUSD. For EURGBP, define 0.63 unused. Good.

Need maybe "l0_ease/l0_lag DIAG diff bar-for-bar" — production DIAG conditions:
- l0_ease prints only if `InpVerboseLog && ArraySize(g_own_layers)==0 && ArraySize(g_opposite_layers) > InpEaseDepthStart`. Actually if opposite_depth > ease_depth_start, not >=. If equal, no DIAG. Unified must preserve.
- l0_lag prints if `InpVerboseLog && ArraySize(g_opposite_layers) > InpEaseDepthStart`. Same.
Need include in parity. If unified changes condition to >=, DIAG diff fails. Good.

Need perhaps "l0_quote" log prints only when replace succeeded. Good.

Need maybe "V2_EffectiveSpreadMultiplier" ramp:
- If opposite_depth <= start => base.
- If >= full => eased.
- Else linear interpolation.
Production uses exactly. Need preserve.

Need perhaps "EURGBP signal uses `MathMax(sig_ac, sig_bc)` for sigma; EURUSD/GBPUSD use own sigma. Unified dispatch branch. Good.

Need "AB path uses `Long_PipsToPrice` not `Short_PipsToPrice`" same.

Need perhaps "AB path uses `ratio * MathExp(inst_spread - dynamic_hs)` and then checks `bid_theoretical <= 0.0`; BC path doesn't check after exp? It returns true. Actually Long_ComputeBidSignal in GBPUSD does not check `bid_theoretical` positivity after computing; it just returns true. EURUSD also no check. EURGBP checks. To preserve parity, unified BC path should not add a positivity check that could change behavior (if fv positive and exp positive, always positive, so no difference). Not issue.

Need "BC path uses `bc_now = closes[0] + half`; if CopyClose returns less than 49, false." Good.

Need "V2_L0DynamicHalfSpread" with `live_spread_price` may be larger than quote_spread + sigma*mult, so dynamic_hs can be huge, making bid_theoretical below market. Good.

Need maybe "lookahead bias in `V2_L0ResolveLiveSpreadPrice` static `g_last_valid_spread_price` persists across symbols in same EA? Each shell only one symbol. Good.

Need perhaps "unified engine should not use `_Symbol` in signal for AB path except to place orders; AB path uses leg symbols for signal." Good.

Need "telemetry instance names" in production for GBPUSD not defined in provided snippet; maybe telemetry.mqh defines? Hmm. Need not.

Need maybe "no cross_exposure_cap.mqh" okay.

Need "Three .ex5 binaries still required for VPS" but if unified engine uses all cap headers and one binary, not. But spec says three. Not a blocker.

Need perhaps "VPS changes out of scope" okay.

Need "filename swap before parity" out of scope okay.

Need perhaps "new shells get distinct names" — if new shells have different magic numbers? No, should use same magic as production per pair. If they use same magic and run on same account simultaneously with production, conflicts. The spec says production files remain untouched during transition; new shells get distinct names. But if user attaches both old and new EAs to same chart/symbol, they would use same magic numbers and conflict. During parity testing in Strategy Tester, not live. But rollout may need ensure not running both on same account simultaneously. Spec says "production files during transition remain untouched until parity is proven; new shells get distinct names or replace production only after parity gate." If during parity testing in Strategy Tester, okay. If on VPS, can't run both with same magic on same account. Need mention as operational blocker? Maybe not.

Need "parity testing side-by-side production vs unified shell" in Strategy Tester cannot run two EAs on same chart simultaneously; need two separate tester runs with same inputs/data. The wording "side-by-side" means compare runs. Fine.

Need perhaps "Model=4 identical .set" with different EA names: `.set` file may not be identical because input names differ. Need define an input mapping table. Good.

Need maybe "V2_STATS counts" printed on Deinit; in Strategy Tester, Deinit may not print if tester stops? Need parse journal. Good.

Need maybe "peak net lots" not in code; perhaps from report. Not.

Need perhaps "exact match on exits" if order tickets differ due to different order placement sequence, but exits count should match. Good.

Need final response should not be overly code. Use headings.

Let's formulate with enough detail.

Potential output:

```
VERDICT: NOT READY. Blocked by 6 issues...
```

Need maybe "No implementation code" so no code snippets. I can mention names but not syntax.

Let's write.

Detailed blockers:

B1: Two-source-of-truth for overridable defaults.
Explain: MQL5 `input` defaults must be compile-time constants. Spec wants preset struct and input override, but doesn't define relationship. If both exist, a mismatch is silent. Need single source via preset-fragment macros that feed both struct and input defaults; runtime `input` values are authoritative for overridable parameters. Add an OnInit invariant check that validates the actual resolved values.

B2: Cap include strategy vs engine switch contradiction.
Explain compile failure if each shell includes only its cap headers but engine references all cap functions in switch. Need per-shell bridge functions that implement a common cap interface (block/sync/record) using only included headers; engine calls bridge. The cap profile enum can remain for validation/telemetry, but not as a switch over functions that may be absent.

B3: Unified L0 dispatch as specified is not unit-testable.
The `V2_L0ComputeBid(preset, ctx, out bid)` entry point as described would call CopyClose/SymbolInfo internally. Unit tests can't mock broker data. Need split into pure core taking closes/bid/ask/live_spread arrays and a thin production wrapper. Otherwise parity unit tests cannot run.

B4: Parity gate not reproducible/tolerance not defined.
Define canonical windows with dates; identify Model=4 by enum name and ensure real-tick spread replay. Define exact equality for discrete outcomes and normalized prices; tolerance for internal floats/DIAG/P&L. Otherwise gate can pass/fail spuriously.

B5: Magic numbers hardcoded in production not captured.
List examples. Need sweep.

B6: EURGBP deadband reference false assumption.
EURGBP defines V2_PAIR_SPREAD_PIPS_REF 0.63 but never passes it to deadband; only EURUSD vol-scales. Preset must encode EURGBP flag false. Also deadband vol-scale is an input in EURUSD, so resolution with preset needed.

Then answer Claude Q2, Q3, Q4.

Q2:
Trace:
- Signal: only branch needed is signal slot: BC path and AB path differ in source symbols and formula. This is localized in L0 dispatch.
- Cap: only branch needed is cap profile in a bridge; if bridge functions are per-shell, engine has no pair conditionals.
- Deadband: parameterized via preset flag/ref.
- All layer/exit/deal/rollover/telemetry code is identical once side parameterized by long/short. Thus no scattered pair conditionals if and only if spec mandates "no pair-label literals outside preset/dispatch/bridge" and tests enforce. Need "pair == EURGBP" conditionals scattered would fail.

Q3:
As above.

Q4:
ADR-102 trace:
- OnTradeTransaction filters DEAL_ADD.
- Long/Short_HandleDealFill: dedup, HistoryDealSelect, symbol filter, mark processed, magic classification, then halt gate and return before mutating layers/caps/closeby.
Need preserve exact order in engine. The spec bullet is insufficient; add a sequence checklist and unit tests.
ADR-103 trace:
- Long_OnInit/Short_OnInit before orphan scan; orphan scan per side; cap publish per side via ShouldPublish; no trigger GV reset; partial halt returns INIT_SUCCEEDED, both halt returns INIT_FAILED. Need preserve exact order.

Need also answer "Cursor's open questions" maybe integrated.

Need "Additional assumptions that don't hold":
- "copied verbatim" from production could copy hardcoded magic numbers.
- "Each shell includes only cap headers its profile needs" cannot coexist with engine switch.
- "exact" needs refinement.
- "thin shells ~40-60 lines" may be larger because shell must declare all inputs and bridge functions; not a blocker but estimate off.
- "one shared engine body ~1,500 lines" likely okay.
- "logic.mqh/exits.mqh stay production" good.
- "no cross_exposure_cap.mqh" good.

Need maybe mention "lookahead bias" explicitly:
"None found in the production signal extraction; it copies closes from shift 1 onward. The unified L0 dispatch must keep start shift 1 and the `closes[0] + half` convention exactly; do not 'modernize' it to current bar or current mid, because that would introduce a behavioral change and potentially lookahead."

Need perhaps "Statistical flaw": none. But "parity windows" not defined.

Need perhaps "silent failures" in preset: "If preset values are copied by hand from production, no compile-time protection."

Let's ensure final is not too long but enough. Desired oververbosity 5. We can be thorough.

Need not include code. Use names.

Let's write final in Markdown.

Need avoid "implementation code" means no code snippets. Function names okay. I will avoid code blocks and semicolon syntax. Use prose.

Let's craft.

## Final Report

# Phase 1 Audit — Verdict: NOT READY

The direction is correct: production’s three files are structurally identical, the `_ref` branch was the wrong reference, and a parameterized engine is the right target. But the specification as written contains one hard compile-blocking contradiction, one high-risk silent-failure path, and a parity gate that is not yet reproducible.

The following are the blocking issues, the answers to Claude’s four questions, and the open questions from Cursor.

---

## Blockers

### 1. Preset-default vs input-override resolution is undefined — silent wrong-pair risk

This is the most important issue.

The spec says the preset carries “easing defaults” that are “overridable via input,” but it never defines:

- where the input default comes from,
- whether the preset struct is authoritative,
- what happens when a shell’s `input` default and the preset field disagree.

In current production, each `.mq5` file directly declares `input` variables with the pair’s correct defaults. That is the real source of truth at runtime. If the unified engine also carries the same value in `V2PairPreset`, there are now two copies of the same behavioral constant. A later edit to one copy but not the other will compile cleanly, pass existing tests, and silently change the easing threshold on exactly one pair.

The spec needs a single-source mechanism, for example: the preset fragment defines a compile-time constant, and both the struct field and the shell’s `input` default are derived from that same constant. The runtime `input` value should then be the only value used by engine logic for overridable parameters. The preset struct should store only non-overridable identity and profile fields, or should be kept only for validation/telemetry.

Also add a fail-fast invariant in `OnInit` that validates resolved runtime parameters against allowed ranges, as the current ease-depth input validation does.

**Blocking.**

---

### 2. “Each shell includes only the cap headers its profile needs” contradicts “engine switches on `g_preset.cap_profile`”

This is a compile error as written.

If the shared engine contains a dispatch on `V2CapProfile` that calls:

- `V2_GbpCapSyncInstance` for `GBP_ONLY`,
- `V2_EurCapSyncInstance` for `EUR_ONLY`,
- `V2_SyncAllCaps` / `V2_AnyCapBlocksNewAdd` for `DUAL_GBP_EUR`,

then every shell must include all cap headers, because the engine’s switch references functions from all of them. A GBPUSD shell that includes only `gbp_cap.mqh` will fail with undeclared identifier when the engine compiles the `EUR_ONLY` branch.

Include guards prevent duplicate definitions, but they do not solve missing definitions.

The clean fix is per-profile bridge functions: each shell or preset fragment defines a small, pair-specific cap interface — block, sync, record — using only the cap headers that shell includes. The engine calls that bridge, not the raw cap functions directly. The `V2CapProfile` enum can remain for validation and telemetry, but it should not be the dispatch mechanism inside the shared engine body.

**Blocking.**

---

### 3. The proposed `V2_L0ComputeBid` / `V2_L0ComputeOffer` entry points are not unit-testable as described

The spec says unit tests will be extended for `V2_L0Compute*` — ramp, floor, swap-independence matrix. But the entry points as described take a preset and context, not market data.

Production signal computation needs:

- 60 M5 closes,
- current bid/ask,
- live spread,
- own-layer flat state,
- opposite-layer depth.

If `V2_L0ComputeBid` calls `CopyClose` / `SymbolInfoDouble` internally, then unit tests cannot isolate the signal math. MQL5 does not allow mocking broker functions.

The architecture needs a pure core that accepts closes, bid/ask, live spread, and state as inputs, plus a thin production wrapper that fetches market data and calls the pure core. That is the only way the parity tests can realistically be written.

**Blocking for the stated verification plan.**

---

### 4. Parity gate is not reproducible and “exact” is not precisely defined

The spec names `truss_crisis`, `full_quarter`, and `EURGBP + june_blowup` but does not define:

- UTC start/end timestamps,
- symbols and deposit currency,
- leverage / margin mode,
- spread and commission model,
- data source / tick data set,
- order-execution model.

“Model=4” is also ambiguous in the provided documentation. The parity gate must identify the exact MT5/MT4 testing model by enum name, and it must be a real-tick model that replays actual spreads. Otherwise the easing, deadband, and live-spread floor logic will not be exercised meaningfully.

On “exact”:

- Discrete outcomes — exits, stats counts, max layers, peak net lots — should be exactly equal.
- Normalized order prices should match exactly at symbol precision; these are tick-rounded values, so exact equality is the correct bar.
- Raw internal doubles — sigma, log returns, dynamic half-spread — can differ by an ulp across a refactor without being a behavioral bug. But because a one-ulp difference can sometimes cross a normalization boundary, the gate should require exact normalized prices, not exact raw doubles.
- P&L is read from broker deal fields, so if the deal sequence is identical, P&L should be exact; if the tester rounds account-currency P&L, allow a small currency-unit tolerance and define it explicitly.

**Blocking.**

---

### 5. Production has hardcoded magic numbers that “copied verbatim” would preserve

In `fxmatrix_v2.mq5`, several paths bypass the pair macros:

- long deal classification uses `20260901` directly,
- short deal classification uses `20260902` directly,
- long `EnsureAddNext` places orders with `20260901`,
- short `EnsureAddNext` places orders with `20260902`,
- `Long_OnInit` prints `magic=20260901`.

If the preset fragments are “copied verbatim from current production,” these hardcoded values will silently migrate into the unified engine. The unified engine must route all magic-number references through the preset or through macros derived from the preset. Add a static test that fails if any raw magic literal appears outside the preset fragments.

**Blocking.**

---

### 6. EURGBP deadband vol-scale assumption is false

The spec lists “EURUSD-only L0 deadband vol-scale.” That is correct in production: only `fxmatrix_v2_eurusd.mq5` passes `EurUsd_L0DeadbandSpreadRef()` into `V2_L0RestingWithinDeadband`.

But `fxmatrix_v2_eurgbp.mq5` also defines `V2_PAIR_SPREAD_PIPS_REF 0.63` and never uses it. If the preset struct encodes a generic “reference spread” for all pairs, and someone assumes EURGBP should also scale its deadband because the define exists, that would change production behavior.

The preset needs an explicit boolean `l0_deadband_vol_scale_enabled` and a rule:

- GBPUSD: disabled,
- EURUSD: enabled, ref = 0.18,
- EURGBP: disabled despite the unused 0.63 define.

**Blocking.**

---

## Claude Q1: Preset-vs-input resolution — answer

No mechanism is specified, and as written it is a Silent Error Test failure. Runtime `input` values must be authoritative for all overridable behavioral parameters. The preset should not carry a second copy of those values unless it is derived from the same compile-time constant that initializes the input defaults.

The specification must also say what happens on disagreement:

- If a user intentionally overrides an input, the input wins.
- If the preset fragment and input default disagree because of a code drift, there is no way to distinguish that from a user override.
- Therefore, remove the duplication rather than add precedence rules.

---

## Claude Q2: Does unification relocate EURGBP branching?

It can, if done strictly.

Trace against production:

- **Signal path:** EURGBP genuinely needs the AB-triad formula: two leg symbols, separate FV/sigma for each leg, `inst_spread = r_AC - r_BC`, `ratio = FV_AC / FV_BC`, and `MathMax(sig_AC, sig_BC)` in the half-spread. This is a real second math path; it cannot be parameterized away. It belongs inside the L0 dispatch as a signal-slot branch, and nowhere else.
- **Cap path:** EURGBP genuinely needs dual-cap evaluation and sync. This belongs inside the per-profile cap bridge.
- **Deadband path:** EURGBP does not vol-scale; that is a preset parameter, not a branch.
- **Everything else:** layer append/remove, exits, reload state, rollover, orphan guard, halt gate, telemetry, deal classification, CloseBy queue — all three production files are structurally identical once direction is parameterized as long/short.

So the answer is: the design survives only if all pair-specificity is forced into three places — preset values, the signal-slot dispatch, and per-shell cap bridge — and the engine body is explicitly banned from containing pair-label conditionals. The spec should add a test that scans the shared engine for pair literals outside those whitelisted components.

---

## Claude Q3: Should parity be bit-for-bit?

No. It should be:

- **Exact:** number of orders, exits, stats counters, max layers, peak net lots.
- **Exact at normalized price precision:** all order prices after `NormalizeDouble` to the symbol digits.
- **Tolerant at raw-double level:** computed sigma, log-return, and dynamic half-spread values may differ in the last stored bit without being behavioral bugs. Allow a relative tolerance of roughly `1e-9` for DIAG numeric fields.
- **Defined for P&L:** because P&L comes from broker deal fields, it should be exactly equal if the deal sequence is identical; if the tester applies currency rounding, allow a small explicit tolerance such as `0.01` account units.

The reason exact normalized prices matter is that a tiny float difference only becomes a real bug when it crosses a price-normalization boundary. That is the correct threshold to test, not raw equality of doubles.

---

## Claude Q4: ADR-102 / ADR-103 must be traced, not named

Confirmed from production source that the following must be preserved exactly:

### ADR-102

Current production:

1. `OnTradeTransaction` ignores non-DEAL_ADD transactions.
2. Each side’s `HandleDealFill`:
   - dedup via processed-deal list,
   - `HistoryDealSelect`,
   - symbol filter,
   - extract entry type, magic, deal type, order ticket, position id, price,
   - mark deal processed,
   - classify managed entry/exit using magic,
   - **then** if the side is halted and the deal is managed, emit the halted-fill alert and return.
3. The halted path must not append layers, remove layers, sync cap GVs, queue CloseBy, or call `EnsureAddNext`.

The unified engine must retain this exact ordering. The spec’s “halt gate” bullet is not sufficient; write the sequence into the spec and add a unit test that verifies the halt path returns before all mutation points.

### ADR-103

Current production:

1. `Long_OnInit()` / `Short_OnInit()` run first.
2. Orphan scan runs per side after init.
3. Cap publish runs per side, only if `V2_ShouldPublishCapSyncOnInit(side_orphan)` is true.
4. No trigger GV reset exists anywhere in `OnInit`.
5. Partial halt still returns `INIT_SUCCEEDED`; both halted returns `INIT_FAILED`.

The unified engine must preserve the per-side publish semantics: a clean side publishes, a halted side skips — not a blanket skip on partial halt, and not a blanket publish.

---

## Cursor’s open questions — responses

### Context struct sufficiency

The listed fields are close but not sufficient as described.

The context must also include:

- `own_side_flat` and `opposite_depth` — production uses these to gate easing, and `V2_EffectiveSpreadMultiplier` is applied only when the quoting side has zero layers.
- live spread price, or enough raw information to compute it.
- leg symbols for the AB path.
- passivity buffer in price terms, not just pips, because production converts pips to price before the half-spread call.
- a way to test the pure math without broker calls.

Redundant fields such as both `passivity_buffer_pips` and `passivity_buffer_price` are dangerous: if they drift apart, which one wins? Pick one authoritative representation.

### Shared half-spread helper

Yes — use the production helpers `V2_EffectiveSpreadMultiplier` and `V2_L0DynamicHalfSpread` as the canonical implementation, and keep `V2_L0ResolveLiveSpreadPriceFromRaw` as the testable core. Do not create a third version of the same math in the new L0 header.

### Cap include strategy

Use per-shell bridge functions. The engine should not call `V2_GbpCap*` / `V2_EurCap*` / `V2_AnyCap*` directly from a profile switch unless every shell includes every cap header. The bridge approach preserves “each shell includes only what it needs” and keeps the engine compilable.

### Deterministic parity tolerance

Covered above: exact discrete outcomes and normalized prices, tolerances for raw floats and possibly rounded account-currency P&L.

### Include-guard risks

The main risk is ordering, not duplicate guards:

- `fxmatrix_v2_logic.mqh` has default `MM_LONG_V2` / `MM_SHORT_V2` definitions guarded by `#ifndef`.
- If the engine includes `logic.mqh` before the shell defines its pair magic numbers, the shell’s values will be silently replaced by the generic defaults.
- The spec must require that preset definitions happen before the engine include, and should add a test that catches the wrong order.

---

## Additional assumptions that do not survive contact with production

1. **“Three thin shells ~40-60 lines each”** is optimistic. Each shell must still declare its input set, pair macros, cap bridge functions, and possibly leg-symbol inputs. That is fine, but the estimate should be revisited.

2. **`.set` compatibility** is stated as a requirement but not designed. If unified shells add or remove inputs — for example, declaring both cap threshold inputs in all shells, or moving `InpL0DeadbandVolScale` into a common input set — existing `.set` files will not map cleanly. The parity plan needs an explicit input-mapping table.

3. **Runtime overrides for EURGBP legs and EURUSD deadband vol-scale** mean the engine cannot reference those inputs directly unless all shells declare them. The L0 dispatch and deadband path need per-shell bridge accessors or a common input contract.

4. **No lookahead was found in the production signal path**, but the unified L0 dispatch must preserve the exact data conventions:
   - copy closes starting from bar `1`, not bar `0`,
   - use `closes[0] + half_spread` as the “now” anchor,
   - keep the production semantics of `V2_MidNowFromSymbol`.
   
   If the refactor “fixes” this to current mid or includes the forming bar, it changes both behavior and possibly introduces lookahead. The spec should explicitly say these conventions are frozen.

5. **“Peak net lots”** is not defined in the supplied production code or ADRs. The parity gate needs a precise definition before it can be tested.

---

## Bottom line

The spec should not proceed to implementation until:

- the preset/input single-source mechanism is defined,
- the cap bridge architecture replaces the profile-switch contradiction,
- the L0 signal math is split into a pure testable core,
- the parity gate is made reproducible with defined windows, model enum, and tolerance policy,
- hardcoded magic literals are swept out of the production extraction,
- EURGBP deadband behavior is explicitly encoded as disabled,
- ADR-102 and ADR-103 are written into the spec as exact sequencing requirements, not feature names.