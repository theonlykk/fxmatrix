TO: DeepSeek (Red Team Adversarial Audit)
FROM: Claude (Lead Engineer)
RE: FX Matrix EA — Execution Layer Audit (Round 2)

Context and what is already settled
This is a 3-currency pod FX mean-reversion EA targeting FTMO live deployment. The pod is EUR/GBP/USD. The execution instrument is the direct cross between the strongest and weakest currency at signal time.
Math is not up for audit. The basis risk proof has been confirmed analytically by Gemini: the spread S = r_GBP − r_EUR collapses exactly to −r_EURGBP. The signal is a perfect sufficient statistic for P&L. No empirical proof is needed.
Entry threshold is fixed at 0.0008 (log-return units, ≈8 pips EURUSD equivalent). Gemini ruling confirmed. Not a discussion item.
Prior DeepSeek audit (Round 1) findings — already resolved, do not re-audit:

Q1–Q4: OnBar pattern, CopyClose usage, OrderModify vs cancel-replace, dynamic arrays — all confirmed correct
Q5: Same-candle race condition — resolved via sequential OnTradeTransaction processing
Q7: Circuit breaker sequence — cancel pending orders first, then close positions at market
Q6/Q8 (most important): Unit mismatch between spread-space (dimensionless log-return) and price-space (EURGBP pips). Resolution already incorporated into ADR-001: layer spacing uses H4 ATR in price space (EURGBP pips), not spread standard deviation. This was the correct fix — confirm you agree and move on.


Architecture being audited (from ADR-001)
Inventory model:
mql5struct Layer {
    double entry_price;
    double exit_target;
    double add_next;
    double lot_size;
    int    ticket;
};

Layer    inventory[];   // LIFO stack
double   peak_equity;
bool     halted;
datetime last_bar_time;
Layer spacing and exits:

Add ratio: 0.75 × H4_ATR (adverse move triggers next layer)
Exit ratio: 0.25 × H4_ATR (favourable move from each layer's entry price)
Both ratios parameterised per layer depth via LayerRatios[5][2]
ATR blendable across timeframes via ATRConfig[N][2]
Max layers: 5 (hard cap)
Sizing: uniform per layer, no tapering

LIFO unwind:

Most recent layer exits first
Each layer's exit limit is placed immediately on fill, fixed at entry time
Exit targets are NOT updated after placement (spatial, not dynamic)

Execution hooks:

OnTick(): detect new M5 bar, run signal, update limit prices, check circuit breakers
OnTradeTransaction(): on entry fill → place exit limit + next entry limit; on exit fill → pop LIFO stack

Circuit breakers:

Per-pod: if unrealised loss > MAX_POD_DRAWDOWN (2%) → cancel pending, close at market, halt pod
Global: if equity drops 5% from peak → cancel ALL pending, close ALL positions, halt all pods

Pre-positioning (key architectural insight):
Strategy places passive limit orders at analytically computed price levels before market arrives. No market orders. For target spread T and known EURUSD price, the system solves analytically for the EURGBP price that would produce spread T, then places the limit there.

Audit scope — focus exclusively on these four areas:
1. LIFO queue logic

Is the LIFO stack implementable correctly in MQL5 given that OnTradeTransaction() may fire multiple times per tick?
Can exit fills and entry fills for different layers arrive out of order? If so, does the LIFO pop logic corrupt the inventory stack?
When the most recent layer exits and the stack pops, does the next layer's add_next level need to be recalculated, or is it safe to leave it as originally set at that layer's entry?

2. MT5 order book assumptions

The strategy places passive limit orders at pre-calculated price levels. On FTMO MT5, what is the realistic minimum distance from current price for a pending limit order? Is there a broker-enforced minimum distance that could prevent pre-positioning at the analytically computed level?
When EURUSD and GBPUSD move simultaneously, the analytically computed EURGBP limit price may shift. The EA recomputes on each new M5 bar. Is one M5 bar the right recomputation frequency, or is there a structural risk that the limit order is stale for too long between bars?
Are there any MT5-specific order management constraints (max pending orders, lot size rounding, FIFO enforcement on some brokers) that could break the LIFO design?

3. Margin constraints at max-layer drawdown

At MAX_LAYERS=5 with BaseLotSize=0.01 on FTMO, what is the approximate margin consumed by a full stack on EURGBP? Is this within FTMO's standard margin requirements without triggering a margin call before the circuit breaker fires?
The per-pod circuit breaker fires at 2% unrealised loss. At max layers with H4 ATR spacing, is 2% a realistic threshold or will the circuit breaker fire too early (before the trade has room to breathe) or too late (after meaningful equity damage)?
Does FTMO enforce FIFO order closing? If so, LIFO is structurally incompatible with FTMO's account rules. This is potentially an existential finding — audit this explicitly.

4. Latency and pre-positioning risks

The strategy's edge depends on limit orders being filled passively. What is the realistic risk of a gap or spike through the limit level without a fill on FTMO MT5 (i.e., slippage past the order)?
At M5 recomputation frequency, how stale can the analytically computed limit price get? If EURGBP moves 5 pips within a single M5 bar, the pre-positioned limit may be at a price that no longer corresponds to the target spread. Is this a structural problem or noise?
Is there a risk that the OnTick circuit breaker check and the OnTradeTransaction fill handler create a race condition on a fast-moving bar?


The existential question
Setting aside all implementation details: is this strategy — passive limit laddering with LIFO unwind, matrix-driven entry, ATR-spaced layers, on a direct cross between strongest and weakest currency in a 3-currency pod — fundamentally flawed for live FTMO deployment?
Specifically: is there any structural reason (FTMO rules, MT5 platform constraints, market microstructure) why this cannot work even if the math is sound and the implementation is correct?

Output requested
For each of the four audit areas: finding, severity (critical / moderate / low), and recommended resolution. Flag anything that is a potential show-stopper before we proceed to ADR-002.