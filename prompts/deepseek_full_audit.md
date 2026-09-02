# DeepSeek R1 Audit — FXMatrix Full Codebase Review

## Role
You are the Red Team auditor for FXMatrix, a native MQL5 Expert
Advisor running on an FTMO funded account. Your job is to conduct
an exhaustive adversarial audit of the full codebase, identify all
logic flaws, state leaks, race conditions, and architectural gaps,
and propose minimal targeted fixes.

Do not propose architectural redesigns. Flag issues with severity
(Critical / High / Medium / Low) and propose exact fixes where
possible.

---

## System context

FXMatrix is a 3-currency mean-reversion EA (EUR/GBP/USD) running
on EURGBP M5. It trades EURUSD, GBPUSD, and EURGBP via passive
limit orders. It uses a LIFO layer system (up to 5 layers per pod),
CloseBy for position merging, and a state persistence engine
(StateEngine.mqh) for reload safety.

Key architectural decisions locked:
- Physical ledger is ground truth: L.instrument and L.direction
  derived from deal_symbol and deal_type at fill time
- Reverse derivation: strongest_at_entry/weakest_at_entry derived
  from physical fill (not live globals)
- All exits route through CloseBy
- EA_MAGIC = 20260608 on all new orders
- Highlander Rule: one pending entry limit at a time
- Pod teardown: CancelAllPendingEntries() when inventory empties
- StateEngine: SaveInventoryState() at all 5 mutation points

---

## Known issues (already identified, include in audit)

1. Compile warning — 1 warning reported on last F7. Unknown cause.
2. CarryEngine stale ticket check — OrderSelect() not verified
   before OrderModify() on exit_tickets[]
3. LAYER_EXIT gross_pnl=0.00 — CloseBy P&L not captured in log
4. CloseBy retcode=10013 still occurs for passive limit exits in
   multi-layer pods in the strategy tester (not live)
5. Radar model mismatch — GetBestRadarTarget() uses raw log-returns
   while RunSignalOnBarClose() uses tri-currency decomposition.
   These two models disagree on strongest/weakest, corrupting
   ComputeEntryPrice() when Radar overrides globals. Radar has
   been reverted — see question 3 below.

---

## Audit questions

### 1. Full codebase review
Review all 7 files for:
- State leaks between bar closes
- Race conditions in OnTradeTransaction
- Logic gaps in HandleEntryFill() and HandleExitFill()
- Carry engine correctness — is the forward price drift
  calculation mathematically sound?
- StateEngine correctness — are all mutation points covered?
  Is the JSON parser robust to edge cases?
- CloseBy async queue — are all edge cases handled?
- Circuit breaker logic — any gaps?
- MaxLayers overflow — is the current handling correct?

### 2. Compile warning
Identify the source of the 1 compile warning. Provide exact fix.

### 3. Radar redesign feasibility
The Radar concept: on each bar close, identify the single most
dislocated routing case across all 6 thresholds and hunt that
case. It was implemented and reverted due to:
a) Model mismatch: GetBestRadarTarget uses raw log-returns
   (r_EU, r_GB, r_EG) while RunSignalOnBarClose uses
   tri-currency score decomposition. The two models disagree.
b) Rotation thrash: Radar cancelled valid limits every 1-5 bars.

Question: Can the model mismatch be resolved by unifying the two
signal models? Specifically — can GetBestRadarTarget be rewritten
to use the same tri-currency decomposition as RunSignalOnBarClose,
so both models agree on which case is most dislocated? If yes,
provide exact implementation guidance. If no, explain why.

Also: is a rotation dampener (only rotate if new dislocation
exceeds current by X%) sufficient to fix rotation thrash, or
is there a deeper structural reason why Radar underperforms
commit-and-hold for this strategy?

### 4. Risk sizing
Current backtest results at EntryThreshold=0.0006, BaseLotSize=0.01:
- 3 months (Mar-Jun 2026): +$380, PF 19.70, 322 trades, 90% win rate
- Max equity drawdown: 3.41%

FTMO $10k Swing 2-Step rules:
- Phase 1: +10% profit target ($1,000), max 5% daily DD, max 10% total DD
- Phase 2: +5% profit target ($500), max 5% daily DD, max 10% total DD

Question: What BaseLotSize is appropriate to target Phase 2
($500 profit) while staying within FTMO drawdown rules? Provide
a position sizing formula accounting for:
- Expected win rate and average profit per trade
- Max consecutive losses observed
- Safety margin for drawdown limits
- Whether running multiple pods simultaneously is advisable

---

## Files provided for audit
See attached: FXMatrix.mq5, ExecutionEngine.mqh, MathEngine.mqh,
LayerStruct.mqh, Globals.mqh, StateEngine.mqh, CarryEngine.mqh