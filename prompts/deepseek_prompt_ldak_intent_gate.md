# DeepSeek R1 Red-Team Audit — LDAK Intent Gate (ADR-042 Proposal)

## Mission

You are the adversarial red-team for FXMatrix V3, an MQL5 market-making EA trading a EUR/GBP/USD triangular triad (EURUSD=SLOT_AC, GBPUSD=SLOT_BC, EURGBP=SLOT_AB). Your job is to find fatal flaws, not validate the proposal. If you find a fatal flaw, say so explicitly and propose an alternative. Do not soften findings.

**CRITICAL: FXMatrix is a strict Liquidity Provider. We NEVER cross the spread. We NEVER use market orders. We park limit orders and wait for fills. Do not waste analysis on slippage, market execution speed, or bid/ask crossing risks.**

## Architectural context

The EA places passive limit orders (entry and exit) across three currency pairs. LDAK (adapted from statistical genetics) provides a volatility-gated correlation penalty that scales lot sizes down when cross-slot correlation is high. The current `ComputeLDAKLotSize()` function in `ExecutionEngine.mqh` applies:

```
w = 1 / (1 + S_eff²)
lot_size = BaseLotSize * w  →  floor at SYMBOL_VOLUME_MIN
```

With `BaseLotSize=0.01` already at broker minimum, `w` is a dead path — lot size always floors at 0.01 regardless of S_eff. The only active LDAK output today is grid dilation in `MathEngine.mqh`.

## The problem being solved

During a fast unilateral USD move, EURUSD (SLOT_AC) and GBPUSD (SLOT_BC) both breach signal threshold on the same OnTick() call. The rolling `g_corr` window has not yet updated to reflect the correlation spike. S_eff ≈ 0, w ≈ 1.0, and both legs fill at full size — doubling directional USD exposure with no triangular edge. This was observed live on 2026-06-25.

## Approved architectural framework (Gemini ruling)

Two prior Gemini rulings are binding:

**Ruling 1 — LDAK Volume Scaling with 70% threshold:**
```
raw_vol = BaseLotSize * w
if raw_vol >= SYMBOL_VOLUME_MIN * 0.70 → round up to SYMBOL_VOLUME_MIN
if raw_vol <  SYMBOL_VOLUME_MIN * 0.70 → vol = 0.0 → pull quote, log INFO [LDAK] Size scaled below broker minimum. Quote pulled.
```
Binary gate today at BaseLotSize=0.01, true fractional scaling when BaseLotSize moves to 0.05.

**Ruling 2 — Intent Gate to fix S_eff staleness:**
When SLOT_BC is computing its LDAK lot size, it must scan SLOT_AC for:
- Open inventory in the same direction as the BC signal
- Pending limit orders (entry intent) in the same direction as the BC signal

If overlap is detected → override `g_corr[AC/BC]` to 1.0 → S_eff spikes → w collapses → raw_vol < 0.007 → quote pulled via Ruling 1 math.

The gate is symmetric: AC must also check BC before placing its own entry.

## Proposed implementation (to be red-teamed)

Inside `ComputeLDAKLotSize(int instrument)`, before computing S_eff from rolling `g_corr`:

1. Identify the correlated peer slot (if instrument=SLOT_AC, peer=SLOT_BC; if instrument=SLOT_BC, peer=SLOT_AC; if instrument=SLOT_AB, no intent check needed)
2. Determine the current signal direction for `instrument` (BUY or SELL) from the signal engine output
3. Scan peer slot inventory (open positions) for same-direction entries
4. Scan peer slot pending orders for same-direction entry limit orders — **excluding exit limit orders**
5. If overlap found in either scan → force `g_corr[ci] = 1.0` for the AC/BC pair before S_eff computation
6. Proceed with existing S_eff → w → volume math → 70% threshold gate

## Attack vectors to stress-test

### Attack 1 — Direction detection on pending limits
A pending SELL limit on SLOT_AC is entry intent (short). But in MQL5, `OrderGetInteger(ORDER_TYPE)` returns `ORDER_TYPE_SELL_LIMIT` for both entry sell limits and exit sell limits on a BUY position. The proposal says "exclude exit limit orders" — but how? The EA tracks exit limits via the `exit_tickets[]` array inside the local `Layer` struct inventory, but those are only populated after an entry fills. Can the BC intent scan safely query the local `g_inventory[SLOT_AC]` struct to distinguish entry intent from exit limits — i.e. a pending order whose ticket does NOT appear in any `exit_tickets[]` entry in SLOT_AC's inventory is an entry order? If this struct-based disambiguation is not reliable, the intent scan will false-fire on exit limits constantly, blocking all BC entries whenever AC has any open position with exit limits on the book.

### Attack 2 — Same-tick race condition
Gemini states AC processes microseconds before BC in the sequential OnTick() loop. But if AC's entry limit is placed via `OrderSendAsync()`, the pending order may not appear in `OrdersTotal()` when BC evaluates on the same tick. BC scans for AC intent, finds nothing, computes S_eff from stale g_corr, and fills at full size. The gate fires one tick too late. How does the implementation guarantee the AC pending order is visible to BC's intent scan within the same OnTick() call?

### Attack 3 — False positives blocking genuine dislocations
The intent gate forces `g_corr=1.0` whenever AC and BC have same-direction overlap. But genuine triangular dislocations can also produce same-direction entries on AC and BC. By definition, if EURUSD and GBPUSD are both signaling SELL simultaneously, it implies EUR and GBP are both considered weak relative to USD (a universal USD strength event). Does forcing `g_corr=1.0` permanently blind the EA to genuine triangular edge? Or is it mathematically true that any simultaneous same-direction signal on AC and BC is ALWAYS primarily a USD-leg correlation event — meaning the EURGBP signal (SLOT_AB) is the only true triangular dislocation signal, and same-direction AC+BC entries are never genuinely independent — thereby justifying the block unconditionally?

## What to produce

For each attack vector:
- PASS: the proposal handles this correctly, with explanation
- PARTIAL: the proposal partially handles this, with the residual risk quantified
- FATAL: the proposal fails here, with an explicit alternative

Then a final overall verdict: APPROVE for Gemini review, CONDITIONAL APPROVE with required changes, or REJECT with alternative architecture.

Do not write any MQL5 implementation code. Red-team only.
