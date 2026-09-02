# DeepSeek R1 Audit — FXMatrix Entry Price Computation
# ROLE: Adversarial Quant (Red Team Prime)
# SCOPE: Mathematical audit of InvertSpreadToPrice() for
#        EURUSD and GBPUSD entry price computation only.
#        No implementation code. Pure math audit.

---

## CONTEXT

FXMatrix is a 3-currency mean-reversion EA trading EUR/GBP/USD.
The signal model decomposes EURUSD and GBPUSD log-returns into
tri-currency scores:

  r_EU = log(EURUSD_now / EURUSD_12bars_ago)
  r_GB = log(GBPUSD_now / GBPUSD_12bars_ago)
  usd  = -(r_EU + r_GB) / 3
  eur  =   r_EU + usd
  gbp  =   r_GB + usd

  spread = scores[weakest] - scores[strongest]

Signal fires when |spread| > BaseThreshold (0.0004).

The EA places a PASSIVE LIMIT ORDER at the entry price
computed by InvertSpreadToPrice(). The limit should be
placed BELOW current market for BUY, ABOVE for SELL.

---

## THE FORMULA UNDER AUDIT

For EURUSD BUY (strongest=2/USD, weakest=0/EUR):
  T = g_entry_spread = scores[0] - scores[2] = eur - usd < 0
  r_EU_target = r_GB_fixed - MathAbs(T)
  EU_target_mid = anchor_EU * MathExp(r_EU_target)

Where:
  anchor_EU = EURUSD price 12 bars ago (1h anchor)
  r_GB_fixed = g_r_GB_signal = current GBPUSD log-return
  MathAbs(T) = magnitude of the spread dislocation

Example from live log:
  spread = -0.005339, MathAbs(T) = 0.005339
  anchor_EU ≈ 1.155 (EURUSD 1h ago)
  r_GB_fixed ≈ 0.002 (GBPUSD log-return)
  r_EU_target = 0.002 - 0.005339 = -0.003339
  EU_target_mid = 1.155 * MathExp(-0.003339) ≈ 1.151
  Current EURUSD ≈ 1.155
  Limit placed at 1.151 — 40 pips below market

For a spread of -0.005339 (5× above BaseThreshold),
the limit is placed 40 pips below market. The market
rarely reaches this level, so the limit rarely fills.

---

## THE QUESTION

1. Is the formula r_EU_target = r_GB_fixed - MathAbs(T)
   mathematically correct for placing a passive BUY limit
   that represents the mean-reversion entry point?

2. Should the entry limit be placed at the FULL REVERSION
   price (where spread = 0), or at the CURRENT DISLOCATION
   price (where the spread is at its current value, i.e.
   close to current market)?

3. For EURGBP, the formula uses MathExp(-T) applied to
   the ratio anchor_EU/anchor_GB. This produces a price
   close to current market for small T. Why does EURGBP
   work correctly while EURUSD/GBPUSD produce prices far
   from market?

4. What is the mathematically correct formula for placing
   a passive BUY limit on EURUSD at the current dislocation
   level (i.e. close to current market price, not at full
   reversion)?

5. Is the passivity guard (IsPassive: BUY price < bid)
   the correct mechanism to validate the entry price,
   or should the entry price be computed differently?

---

## THE HYPOTHESIS

The current formula computes WHERE EURUSD WOULD BE if the
spread fully reverted to zero — i.e. the EXIT price, not
the ENTRY price. This would explain why:

- EURGBP works: MathExp(-T) for small T ≈ current EURGBP
  price, placing the limit close to market ✓
- EURUSD fails: full reversion price is far from current
  market for large spreads ✗

If correct, the fix would be to compute the entry price
as the CURRENT implied EURUSD price given the current
spread, not the zero-spread reversion price.

The current EURUSD price implied by the spread model:
  r_EU_current = r_GB_fixed + (eur - usd)
               = r_GB_fixed + spread_current
  EU_current_mid = anchor_EU * MathExp(r_EU_current)

This should produce a price close to current market,
with the passive limit placed slightly below for BUY.

---

## FILES PROVIDED

See attached MathEngine.mqh — audit InvertSpreadToPrice()
cases for strongest=2/weakest=0 (EURUSD BUY) and
strongest=2/weakest=1 (GBPUSD BUY) only.

No implementation code in response. Math audit only.
Provide corrected formulas if bugs found.