TO: DeepSeek (Red Team Adversarial Audit)
FROM: Claude (Lead Engineer)
RE: FX Matrix EA — ADR-002 Execution Audit (Round 3)

What is already locked — do not re-audit
The following have been ruled by Gemini (Staff Architect) and are not open for discussion:

FTMO account type: FTMO MT5 accounts are hedging accounts by default. Multiple simultaneous independent tickets on the same instrument are fully supported. Do not raise netting account constraints — this was audited in Round 2 and dismissed as factually incorrect.
Basis risk: Zero, analytically proven. S = −r_EG. The 3-currency pod spread is mathematically identical to the inverse log return of the EURGBP cross rate. Do not re-audit the math.
Entry threshold: Fixed at 0.0008 log-return units for V1. Volatility-scaling deferred to V2.
Layer spacing units: H4 ATR in price space (pips), not spread standard deviation. This was the key Round 1 finding (Q6/Q8) and is already incorporated.
LIFO via independent exit limit orders: Each layer places its own passive exit limit order at entry time. LIFO order is enforced by price geometry, not ticket sequencing. This is valid on FTMO hedging accounts.
Cases 3–6 fixed-leg approximation: Anchoring the un-traded USD leg to the M5 bar close (rather than tick-level recalculation) is acceptable for V1. Gemini ruled this explicitly.
NudgeThreshold: 0.5 pips confirmed for intra-bar limit price updates.


What you are auditing: ADR-002
ADR-002 defines the spatial (price-space) exit mechanism for the EUR/GBP/USD pod. It covers:

The six closed-form price inversions (full routing table)
Bid/ask convention: mid for signal, correct side for execution
Ticket-based LIFO array management
Freeze level guardrail
Intra-bar limit price nudging via OnTick

Full ADR-002 file path follows below. Read it in full before auditing.

"D:\fxmatrix\adrs\ADR-002-matrix-driven-exits.md"

Audit scope — focus exclusively on these areas:
1. The six inversion formulas (Section 3)

For each of the six cases: is the bid/ask side selection correct? Specifically — for a passive sell limit, is the EA using the correct side of the USD legs to compute the synthetic limit price without placing the order inside the spread?
Case 1 and 2 use EU_bid / GB_ask and EU_ask / GB_bid respectively as the synthetic EURGBP reference. Is this the correct conservative adjustment for passivity, or is there a sign error?
Cases 3–6 use a half-spread offset on the execution leg. Is this a valid approximation for ensuring passivity, or does it introduce a directional bias?
Are there any cases where the inversion formula could produce a limit price on the wrong side of the market (e.g. a buy limit above the ask, or a sell limit below the bid)?

2. Ticket-based LIFO array management (Section 4)

The OnTradeTransaction handler matches fills by deal_ticket to find the correct layer in the inventory array. Is there any MT5-specific scenario where a deal arrives in OnTradeTransaction without a valid ticket that can be matched (e.g. partial fills, requotes, broker-side modifications)?
When a layer is removed from the middle of the inventory array and remaining elements are shifted, is there a risk of an index corruption or off-by-one error in the MQL5 dynamic array handling?
Is there any scenario where both an entry fill and an exit fill for different layers arrive in the same OnTradeTransaction call, and if so does the sequential processing assumption hold?

3. Freeze level guardrail (Section 5)

The ADR checks abs(computed_limit_price - current_market_price) <= freeze_price and skips placement if true. Is current_market_price correctly defined here — should it be the Bid, the Ask, or the mid, depending on order direction?
Gemini clarified that the relevant error is TRADE_RETCODE_INVALID_PRICE (10015) not INVALID_STOPS (10016) for limit order price violations. Do you agree with this taxonomy?

4. Intra-bar limit price nudging (Section 6)

The EA cancels and replaces the pending limit order when the recomputed price differs by more than 0.5 pips (NudgeThreshold). On a fast market, cancel and replace introduces a window where no limit order is resting. Is this window a meaningful execution risk on EURGBP, EURUSD, or GBPUSD at M5 frequency?
Is there a race condition between the cancel request and a fill event — i.e. can the order fill in the instant between the cancel being sent and the new order being placed, and if so does OnTradeTransaction handle this gracefully?

5. The existential question
Given the full ADR-002 specification: is there any structural flaw in the spatial inversion logic, the bid/ask convention, or the MT5 execution mechanics that would cause this EA to systematically place limit orders at incorrect prices, on the wrong side of the market, or in violation of FTMO platform constraints?

Output requested
For each finding: area, finding, severity (critical / moderate / low), recommended resolution. Flag anything that requires an architectural change before Cursor implementation begins. If a finding touches something already ruled as locked above, state that explicitly rather than re-opening it.