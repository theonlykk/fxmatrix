---

# ADR-UNIT-TESTS — FXMatrix V3 Master Unit Test Suite
**Status:** Living Document — run before any change to MathEngine.mqh,
ExecutionEngine.mqh, or FXMatrix.mq5

---

## CORE PRINCIPLE

The matrix quotes based on log returns from a 12-bar anchor price.
Given an anchor, QuoteSpread determines exactly where bid and offer
must be placed. These levels are deterministic — no approximation,
no broker spread adjustment, no noise.

---

## TEST 0 — Fundamental Anchor Quote (The Ground Truth Test)

**This test must pass before any other test is meaningful.**

Inputs:
- anchor_A = 1.14600
- QuoteSpread = 0.0004

Expected outputs:
- BUY limit  = 1.14600 × exp(-0.0004) = **1.14554**
- SELL limit = 1.14600 × exp(+0.0004) = **1.14646**

If the code produces any other values for these two orders, it is wrong.
No half_spread. No clamp. No adjustment. Pure log-return levels.

---

## TEST 1 — Flat Signal, SLOT_AC (Baseline Symmetry)
inst_spread=0.0, anchor_A=1.14600, QuoteSpread=0.0004
current_bid=1.14600, current_ask=1.14601, min_dist=0.00001

bid_spread   = 0.0 - 0.0004 = -0.0004
offer_spread = 0.0 + 0.0004 = +0.0004

1a. bid_price (BUY branch, T=-0.0004)
    = 1.14600 * MathExp(-0.0004) = 1.14554
    Expected: 1.14554

1b. offer_price (SELL branch, T=+0.0004)
    = 1.14600 * MathExp(+0.0004) = 1.14646
    Expected: 1.14646

1c. Both passive?
    bid:   1.14554 < 1.14600 = TRUE
    offer: 1.14646 > 1.14601 = TRUE
    Expected: both TRUE

1d. ADR-013 fires?
    BUY pre-check:  1.14554 >= 1.14600 = FALSE
    SELL pre-check: 1.14646 <= 1.14601 = FALSE
    Expected: ADR-013 silent on both legs

---

## TEST 2 — Strong BUY Signal, SLOT_AC
inst_spread=+0.001539, anchor_A=1.14600, QuoteSpread=0.0004
current_bid=1.14600, current_ask=1.14601

bid_spread   = +0.001539 - 0.0004 = +0.001139
offer_spread = +0.001539 + 0.0004 = +0.001939

2a. bid_price  = 1.14600 * MathExp(+0.001139) = 1.14731
    Expected: 1.14731
2b. offer_price = 1.14600 * MathExp(+0.001939) = 1.14822
    Expected: 1.14822
2c. bid passive without clamp? 1.14731 < 1.14600 = FALSE
2d. ADR-013 fires on bid: clamps to 1.14600 - 0.00001 = 1.14599
    Expected: 1.14599

---

## TEST 3 — Strong SELL Signal, SLOT_BC
inst_spread=-0.001539, anchor_B=1.32500, QuoteSpread=0.0004
current_bid=1.32500, current_ask=1.32501

bid_spread   = -0.001539 - 0.0004 = -0.001939
offer_spread = -0.001539 + 0.0004 = -0.001139

3a. bid_price   = 1.32500 * MathExp(-0.001939) = 1.32243
    Expected: 1.32243
3b. offer_price = 1.32500 * MathExp(-0.001139) = 1.32349
    Expected: 1.32349
3c. offer passive? 1.32349 > 1.32501 = FALSE
3d. ADR-013 fires on offer: clamps to 1.32501 + 0.00001 = 1.32502
    Expected: 1.32502

---

## TEST 4 — SLOT_AB Synthetic Pair, BUY Signal
inst_spread=+0.000800, anchor_A=1.14600, anchor_B=1.32500
AB_history = 1.14600 / 1.32500 = 0.86491
current_bid_EURGBP=0.86450, current_ask_EURGBP=0.86451

bid_spread   = +0.000800 - 0.0004 = +0.000400
offer_spread = +0.000800 + 0.0004 = +0.001200

4a. bid_price   = 0.86491 * MathExp(+0.000400) = 0.86526
    Expected: 0.86526
4b. offer_price = 0.86491 * MathExp(+0.001200) = 0.86595
    Expected: 0.86595
4c. bid passive? 0.86526 < 0.86450 = FALSE
4d. ADR-013 fires on bid: clamps to 0.86450 - 0.00001 = 0.86449
    Expected: 0.86449

---

## TEST 5 — Exit Pricing, BUY Position (ADR-034)
BUY filled at 1.14554 (from Test 0).
entry_spread = log(1.14554 / 1.14600) = -0.0004
exit_spread_target = -0.0004 * skew (e.g. 0.99) = -0.000396

is_exit=true → T = -(-0.000396) = +0.000396 (ADR-034)
exit_price = 1.14600 * MathExp(+0.000396) + half_spread

5a. Raw exit = 1.14600 * MathExp(+0.000396) = 1.14645
    Expected: between entry (1.14554) and anchor (1.14600) — NO.
    Expected: above anchor (1.14600) toward SELL limit (1.14646)
5b. Exit price must be > entry price (1.14554): TRUE
5c. Exit price must be <= SELL limit (1.14646): TRUE
5d. IsPassive SELL: exit_price > current_ask (1.14601): TRUE
    Expected: PASS

---

## TEST 6 — Gap Scenario: add_next Far from Market (ADR-035)
Layer 0 BUY on GBPUSD, entry_spread_raw=+0.001061
anchor_B=1.32500, S=0.0008, skew=0.618
Market gaps to 1.31990, min_dist=0.00001

add_next_spread = 0.001061 - 0.0008 - 0.0008*(0.382) = -0.000045
price_add_next = 1.32500 * MathExp(-0.000045) = 1.32494

6a. PlaceNextEntryLimit gap clamp (ADR-035):
    MathMin(1.32494, 1.31990 - 0.00001) = 1.31989
6b. IsPassive BUY: 1.31989 < 1.31990 = TRUE
    Expected: PASS

---

## TEST 7 — Anchor Lag: Market Crashes 50 Pips
anchor_A=1.14600, bid_spread=-0.0004
current_bid=1.14100, min_dist=0.00001

7a. bid_price = 1.14600 * MathExp(-0.0004) = 1.14554
7b. Passive? 1.14554 < 1.14100 = FALSE
7c. ADR-013 pre-check: 1.14554 >= 1.14100 = TRUE
7d. Clamp: MathMin(1.14554, 1.14100 - 0.00001) = 1.14099
    Expected: 1.14099

---

## TEST 8 — Zero Delta: Theoretical Price Equals Market
theoretical_bid=1.14554, current_bid=1.14554, min_dist=0.00001

8a. IsPassive: 1.14554 < 1.14554 = FALSE
8b. ADR-013 pre-check: 1.14554 >= 1.14554 = TRUE
8c. Clamp: MathMin(1.14554, 1.14554 - 0.00001) = 1.14553
    Expected: 1.14553

---

## TEST 9 — Broker Glitch: Zero Spread Feed
theoretical_offer=1.14600, current_ask=1.14600, min_dist=0.00001

9a. IsPassive SELL: 1.14600 > 1.14600 = FALSE
9b. ADR-013 pre-check: 1.14600 <= 1.14600 = TRUE
9c. Clamp: MathMax(1.14600, 1.14600 + 0.00001) = 1.14601
    Expected: 1.14601

---

## TEST 10 — Exit Clamp: ADR-036 Overrun Protection
min_dist=0.00001

10a. BUY Position Overrun (SELL Exit):
     raw_exit=1.32410, current_ask=1.32415
     Pre-check: 1.32410 <= 1.32415 = TRUE
     Clamp: MathMax(1.32410, 1.32415 + 0.00001) = 1.32416
     IsPassive: 1.32416 > 1.32415 = TRUE
     Expected: PASS

10b. SELL Position Overrun (BUY Exit):
     raw_exit=1.14505, current_bid=1.14500
     Pre-check: 1.14505 >= 1.14500 = TRUE
     Clamp: MathMin(1.14505, 1.14500 - 0.00001) = 1.14499
     IsPassive: 1.14499 < 1.14500 = TRUE
     Expected: PASS

10c. Native Passivity (No Clamp):
     raw_exit=1.32450, current_ask=1.32415
     Pre-check: 1.32450 <= 1.32415 = FALSE
     exit_price = 1.32450 (unclamped)
     Expected: PASS

---

## TEST 0b — Fundamental Anchor Quote with half_spread (EURUSD)

Confirms half_spread shifts each leg by exactly 0.5 pip (assuming 1-pip spread).

Inputs:
- anchor_A = 1.14600
- QuoteSpread = 0.0004
- ac_bid = 1.14600, ac_ask = 1.14601
- ac_half_spread = (1.14601 - 1.14600) / 2 = 0.000005

Expected:
- BUY limit  = 1.14600 * exp(-0.0004) - 0.000005 = 1.14554
- SELL limit = 1.14600 * exp(+0.0004) + 0.000005 = 1.14646

(At 5dp broker rounding both still display as 1.14554 / 1.14646)
Deviation from pure log-return: 0.5 pip per leg, bracket narrowed by 1 pip total.
Expected: PASS — deviation is acceptable and by design.

---

## TEST 0c — Fundamental Anchor Quote with half_spread (GBPUSD)

Inputs:
- anchor_B = 1.32500
- QuoteSpread = 0.0004
- bc_bid = 1.32500, bc_ask = 1.32501
- bc_half_spread = (1.32501 - 1.32500) / 2 = 0.000005

Expected:
- BUY limit  = 1.32500 * exp(-0.0004) - 0.000005 = 1.32447
- SELL limit = 1.32500 * exp(+0.0004) + 0.000005 = 1.32554

Deviation from pure log-return: 0.5 pip per leg, bracket narrowed by 1 pip total.
Expected: PASS — deviation is acceptable and by design.

---

## TEST 0d — Fundamental Anchor Quote with half_spread (EURGBP)

Inputs:
- AB_history = anchor_A / anchor_B = 1.14600 / 1.32500 = 0.864906
- QuoteSpread = 0.0004
- ab_bid = 0.86450, ab_ask = 0.86451
- ab_half_spread = (0.86451 - 0.86450) / 2 = 0.000005

Expected:
- BUY limit  = 0.864906 * exp(-0.0004) - 0.000005 = 0.86455
- SELL limit = 0.86491 * exp(+0.0004) + 0.000005 = 0.86526

Deviation from pure log-return: 0.5 pip per leg, bracket narrowed by 1 pip total.
Expected: PASS — deviation is acceptable and by design.

---

## TEST 11 — ADR-037 SkewFloor0 Signal Gate (Wash Trade Preventer)
Validates that Option A refuses to quote when signal is too weak to
support a meaningful exit, preventing the SkewFloor0 wash trade trap.

Inputs: SkewFloor0 = 0.0002

11a. Weak signal blocked:
     inst_spread = -0.000140
     abs(inst_spread) <= SkewFloor0?
     0.000140 <= 0.0002 = TRUE
     Expected: Option A skips — continue fired

11b. Why gate is mandatory even with corrected SkewFloor0=0.0002:
     floor_skew = 0.0002 / 0.000140 = 1.43 → clamped to 0.99
     exit_spread = -0.000140 * 0.99 = -0.0001386
     Still a wash trade — gate correctly prevents entry
     Expected: PASS (gate fires before order placed)

11c. Strong signal passes gate:
     inst_spread = -0.000500
     abs(inst_spread) <= SkewFloor0?
     0.000500 <= 0.0002 = FALSE
     Expected: Option A proceeds to quote

---

## TEST 12 — ADR-037 Baseline Fallback (Weak Signal, Flat Pod)
When abs(inst_spread) <= SkewFloor0, MM mode resets to flat anchor
bracket (±QuoteSpread) and recomputes bid_price/offer_price before
PlaceEntryLimit — no continue, no wash-trade entry at weak signal level.

Inputs:
- inst_spread = 0.000151 (weak, below SkewFloor0)
- SkewFloor0 = 0.0002
- QuoteSpread = 0.0004
- anchor_B = 1.32441 (GBPUSD / SLOT_BC)
- bc_half_spread = 0.000030

12a. Gate fires — baseline reset (no continue):
     MathAbs(0.000151) <= 0.0002 = TRUE
     bid_spread   = -0.0004
     offer_spread = +0.0004
     Expected: proceeds to place orders

12b. bid_price (BUY, strongest=2, weakest=1):
     1.32441 × exp(−0.0004) − 0.000030 = 1.32385
     Expected: 1.32385 PASS

12c. offer_price (SELL, strongest=1, weakest=2):
     1.32441 × exp(+0.0004) + 0.000030 = 1.32497
     Expected: 1.32497 PASS

12d. Bracket width:
     1.32497 − 1.32385 = 0.00112 = 11.2 pips
     Expected: 11.2 pips PASS

12e. Orders placed?
     Expected: YES — PlaceEntryLimit uses recomputed bid_price/offer_price

---

## COVERAGE MAP

| Test | ADR | Component |
|------|-----|-----------|
| 0 | Core | Fundamental anchor quote — ground truth |
| 0b | Core | EURUSD half_spread bracket verification |
| 0c | Core | GBPUSD half_spread bracket verification |
| 0d | Core | EURGBP half_spread bracket verification |
| 1 | ADR-032, ADR-033 | Flat signal baseline geometry |
| 2 | ADR-032, ADR-033, ADR-013 | Strong BUY clamp rescue |
| 3 | ADR-032, ADR-033, ADR-013 | Strong SELL clamp rescue |
| 4 | ADR-032, ADR-033, ADR-013 | SLOT_AB synthetic pair |
| 5 | ADR-034 | Exit pricing sign inversion |
| 6 | ADR-035 | Option B gap clamp |
| 7 | ADR-013 | Anchor lag crash protection |
| 8 | ADR-013 | Zero-delta boundary |
| 9 | ADR-013 | Broker zero-spread glitch |
| 10 | ADR-036 | Dynamic exit clamp overrun |
| 11 | ADR-037 | SkewFloor0 signal gate — wash trade preventer |
| 12 | ADR-037 | Baseline bracket fallback — weak signal flat pod |

---

## PROTOCOL

Before any code change to MathEngine.mqh, ExecutionEngine.mqh, or
FXMatrix.mq5, embed these tests in the Cursor prompt and require all
tests to PASS before diffs are generated.

Test 0 is the gate. If Test 0 fails, nothing else matters.

---
