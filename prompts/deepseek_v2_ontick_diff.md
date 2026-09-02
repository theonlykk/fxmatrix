# DeepSeek R1 Audit — ADR-009 Serial Mode Trade Frequency Gap

## Mission

You are performing a strict adversarial code audit. Do NOT write implementation code. Your only job is to identify the mechanical root cause of the following observed discrepancy.

## The Discrepancy

Pre-V2 FXMatrix EA (commit 42914eb) and V2 FXMatrix EA (with SerialMode=true diagnostic flag) are run against identical inputs:
- Same historical price feed (EURGBP M5, 2026.03.07–2026.06.07)
- Same parameters (GridMode=2, GridBase=0.0008, GridExpBase=1.5, BaseLotSize=0.02, all Phase 3 levers disabled)

Results:
- Pre-V2 (42914eb): +$249, PF 7.80, Sharpe 6.54, 415 trades
- V2 SerialMode=true: +$144, PF 7.25, Sharpe 1.51, 227 trades

Trade frequency is 45% lower in V2 SerialMode. PF is similar, suggesting the edge is intact but the EA is missing valid entry opportunities.

## What SerialMode=true Does

The V2 EA has a diagnostic block injected in OnTick() that attempts to replicate pre-V2 global deafness:

1. Counts total_system_inventory across all three instruments
2. If total_system_inventory > 0 AND this instrument has no inventory:
   - Cancels any live pending entry on this instrument (OrderSend TRADE_ACTION_REMOVE)
   - Clears the per-instrument pending ticket global
   - Calls SaveAllInventoryState()
   - Fires continue to skip signal evaluation

## Your Task

Compare the four provided code files:
- preV2_FXMatrix: OnTick() and OnTradeTransaction() from commit 42914eb
- preV2_ExecutionEngine: HandleEntryFill() and OnTradeTransaction() from commit 42914eb
- v2_FXMatrix: OnTick() and OnTradeTransaction() from diagnostic/serial-mode
- v2_ExecutionEngine: HandleEntryFill() and OnTradeTransaction() from diagnostic/serial-mode

Identify every mechanical difference in the state machine that could cause V2 SerialMode to miss valid entry opportunities that pre-V2 would have captured. Specifically hunt for:

1. SIGNAL EVALUATION DIFFERENCES
   - Does pre-V2 evaluate signals differently per bar vs V2?
   - Are there conditions in V2 OnTick that block signal evaluation that did not exist in pre-V2?

2. PENDING ORDER LIFECYCLE DIFFERENCES
   - How does pre-V2 manage its single global pending ticket vs V2's per-instrument pending tickets?
   - Does the SerialMode cancel block fire at the wrong time — cancelling orders that pre-V2 would have retained?
   - Is there a timing difference in when the pending ticket global is cleared?

3. FILL ROUTING DIFFERENCES
   - Does HandleEntryFill behave differently in V2 in a way that affects whether add_next gets placed?
   - Are there guards in V2 HandleEntryFill that did not exist in pre-V2 that could suppress subsequent layer entries?

4. STATE MACHINE HANDOFF DIFFERENCES
   - Is there a difference in how OnTradeTransaction routes fills to HandleEntryFill between pre-V2 and V2?
   - Could the per-instrument routing in V2 cause any fills to be missed or double-processed?

5. THE REARM BLOCK
   - V2 has a Phase 3 re-arm block that fires when inst_inv_size > 0 and inst_add_next == 0. Does this block interact with SerialMode in a way that suppresses entries?

## Output Format

For each discrepancy found:
- LOCATION: which function and which lines
- PRE-V2 BEHAVIOUR: what the old code does
- V2 BEHAVIOUR: what the new code does
- IMPACT: whether this could cause missed entries
- SEVERITY: LOCAL (fixable within diagnostic branch scope) or STRUCTURAL (requires deep architecture change)

If the root cause is STRUCTURAL, state explicitly that it cannot be fixed within the diagnostic branch and explain why.

Do NOT propose implementation fixes. Do NOT write MQL5 code. Analysis only.