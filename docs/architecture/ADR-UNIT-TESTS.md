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
    Expected: 0.86526 (using doc AB_history=0.86491; exact ratio 1.14600/1.32500=0.864906 gives 0.86525 — tolerance pass)
4b. offer_price = 0.86491 * MathExp(+0.001200) = 0.86595
    Expected: 0.86595
4c. bid passive? 0.86526 < 0.86450 = FALSE
4d. ADR-013 fires on bid: clamps to 0.86450 - 0.00001 = 0.86449
    Expected: 0.86449

---

## TEST 5 — Exit Pricing, BUY Position (ADR-034)
BUY filled at 1.14554 (from Test 0).
entry_spread = log(1.14554 / 1.14600) = -0.00040008 (not exactly -0.0004 due to fill rounding)
exit_spread_target = -0.00040008 * 0.99 = -0.00039608
// is_exit=true → T = +0.00039608
exit_price_raw = 1.14600 * exp(+0.00039608)
5a. Raw exit = 1.14600 * MathExp(+0.00039608) = 1.14645
    Expected: 1.14645  (note: using exact log gives 1.14646 at 5dp — tolerance pass)
5b. Exit price must be > entry price (1.14554): TRUE
5c. Exit price must be <= SELL limit (1.14646): TRUE  (1.14645 <= 1.14646)
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

## TEST 10 — ADR-036 Exit Clamp (SUPERSEDED by ADR-038)
Status: SUPERSEDED
ADR-036 clamp block has been removed from PlaceExitLimit (ADR-038).
10a — overrun SELL: PlaceExitLimit now hits IsPassive and returns 0. No re-pricing. SUPERSEDED.
10b — overrun BUY: PlaceExitLimit now hits IsPassive and returns 0. No re-pricing. SUPERSEDED.
10c — passive case: exit_price unchanged, order placed. PASS (behaviour unchanged).

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

## TEST 11 — ADR-037 Weak Signal Gate
11a — STALE: doc expected `continue`; current behaviour is baseline bracket fallback (see Test 12). SUPERSEDED by ADR-037 revision in ADR-038.
11b — wash trade math: PASS (behaviour unchanged).
11c — strong signal passes gate: PASS (behaviour unchanged).

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

## TEST 13 — MinLayerExitPoints / SkewFloor0 synchronisation
Given: SkewFloor0=0.0002, MinLayerExitPoints=2, point=0.00001
floor_n = MathMax(0.0002 * MathPow(0.618, 0), 2 * 0.00001)
        = MathMax(0.0002, 0.00002)
        = 0.0002

13a. entry_adj=0.000276
     floor_skew = 0.0002 / 0.000276 = 0.72464
     effective_skew = MathMax(0.618, 0.72464) = 0.72464
     exit_spread = 0.000276 × 0.72464 = 0.000200
     Expected: NOT a wash trade — PASS

13b. entry_adj=0.000149
     abs(0.000149) <= 0.0002 = TRUE → baseline fallback, no entry placed
     Expected: gate fires correctly — PASS

13c. Regression — old MinLayerExitPoints=30:
     floor_n = MathMax(0.0002, 0.0003) = 0.0003
     entry_adj=0.000276
     floor_skew = 0.0003 / 0.000276 = 1.08696
     effective_skew = MathMin(0.99, 1.08696) = 0.99
     exit_spread = 0.000276 × 0.99 = 0.000273 ≈ entry_spread → wash trade
     Expected: FAIL — confirms bug is fixed by new parameter

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

## TEST 14 — Deterministic Function Statelessness (ADR-040, replaces ADR-039 JIT stateless test)
`ComputeExitPriceDeterministic` must be a pure function — identical inputs
must produce identical outputs with no side effects between calls.

Inputs:
- entry_price=1.13000, entry_spread_raw=0.0010, layer_index=0
- direction=1 (BUY), half_spread=0.000005, min_layer_exit_points=2
- point_value=0.00001

14a. Call ComputeExitPriceDeterministic twice with identical inputs.
     result_1 == result_2
     Expected: TRUE — PASS

14b. No module-level or global state mutated between calls.
     Expected: function is demonstrably stateless — PASS

---

## TEST 15 — Zero Spread Sentinel and Floor Clamp (ADR-040, replaces ADR-039 invalid anchor test)
ADR-039 used INVALID_EXIT_SPREAD (-1.0) sentinel to block order submission
when anchor was zero. ADR-040 replaces this: ComputeExitPriceDeterministic
with entry_spread_raw=0.0 produces E_n=0.0, floor clamp engages.
PlaceExitLimit sentinel guard (exit_price_fixed < 0.0) blocks submission
for any layer not yet computed.

Inputs:
- entry_price=1.13000, entry_spread_raw=0.0, layer_index=0
- direction=1 (BUY), half_spread=0.0, min_layer_exit_points=2
- point_value=0.00001

15a. E_n = 0.0 * MathPow(0.618, 1) = 0.0
     raw_target = 1.13000 + 0.0 - 0.0 = 1.13000
     floor_dist = 2 * 0.00001 = 0.00002
     exit_price_fixed = MathMax(1.13000, 1.13000 + 0.00002) = 1.13002
     Expected: 1.13002 — floor clamp engages — PASS

15b. Sentinel guard: exit_price_fixed=-1.0 (uncomputed layer)
     PlaceExitLimit checks: -1.0 < 0.0 → TRUE → return without OrderSend
     Expected: no order submitted — PASS

15c. exit_price_fixed=1.13002 > entry_price=1.13000
     Expected: TRUE — correct side even for zero spread — PASS

---

## TEST 16 — Sign Contract, BUY, SLOT_AC (EURUSD) (ADR-040 revised)
Original ADR-039 test failed in live production — JIT sign guard blocked
exit placement on profitable positions. ADR-040 deterministic function
must pass this by construction.

Inputs:
- entry_price=1.13554, entry_spread_raw=-0.0004, layer_index=0
- direction=1 (BUY), half_spread=0.000005, min_layer_exit_points=2
- point_value=0.00001

E_0 = MathAbs(-0.0004) * 0.618 = 0.0002472
raw_target = 1.13554 + 0.0002472 - 0.000005 = 1.1357822
floor_dist = 0.00002
exit_price_fixed = MathMax(1.1357822, 1.13554 + 0.00002) = 1.1357822

16a. exit_price_fixed > entry_price: 1.1357822 > 1.13554
     Expected: TRUE — exit above entry for BUY — PASS
16b. Order type must be sell limit (direction=-1 exit for BUY position)
     Expected: SELL LIMIT — PASS
16c. Pip delta = (1.1357822 - 1.13554) / 0.00001 = 2.4 pips
     Expected: > 0 — PASS

---

## TEST 17 — Sign Contract, SELL, SLOT_AC (EURUSD) (ADR-040 revised)
Mirror of Test 16 for SELL position.

Inputs:
- entry_price=1.13646, entry_spread_raw=0.0004, layer_index=0
- direction=-1 (SELL), half_spread=0.000005, min_layer_exit_points=2
- point_value=0.00001

E_0 = MathAbs(0.0004) * 0.618 = 0.0002472
raw_target = 1.13646 - 0.0002472 + 0.000005 = 1.1362178
floor_dist = 0.00002
exit_price_fixed = MathMin(1.1362178, 1.13646 - 0.00002) = 1.1362178

17a. exit_price_fixed < entry_price: 1.1362178 < 1.13646
     Expected: TRUE — exit below entry for SELL — PASS
17b. Order type must be buy limit (direction=1 exit for SELL position)
     Expected: BUY LIMIT — PASS
17c. Pip delta = (1.13646 - 1.1362178) / 0.00001 = 2.4 pips
     Expected: > 0 — PASS

---

## TEST 18 — Sign Contract, All Three Slots (ADR-040 revised)
Run sign contract verification for all slot/direction combinations.
All six cases must produce correct-side exit and correct order type.

18a. SLOT_AC (EURUSD) BUY:
     entry=1.13554, spread=-0.0004
     exit = 1.13554 + (0.0004*0.618) - 0.000005 = 1.1357822 > entry — SELL LIMIT — PASS

18b. SLOT_AC (EURUSD) SELL:
     entry=1.13646, spread=+0.0004
     exit = 1.13646 - (0.0004*0.618) + 0.000005 = 1.1362178 < entry — BUY LIMIT — PASS

18c. SLOT_BC (GBPUSD) BUY:
     entry=1.32447, spread=-0.0004
     exit = 1.32447 + (0.0004*0.618) - 0.000005 = 1.3247122 > entry — SELL LIMIT — PASS

18d. SLOT_BC (GBPUSD) SELL:
     entry=1.32553, spread=+0.0004
     exit = 1.32553 - (0.0004*0.618) + 0.000005 = 1.3252878 < entry — BUY LIMIT — PASS

18e. SLOT_AB (EURGBP) BUY:
     entry=0.86455, spread=-0.0004
     exit = 0.86455 + (0.0004*0.618) - 0.000005 = 0.8647922 > entry — SELL LIMIT — PASS

18f. SLOT_AB (EURGBP) SELL:
     entry=0.86526, spread=+0.0004
     exit = 0.86526 - (0.0004*0.618) + 0.000005 = 0.8650178 < entry — BUY LIMIT — PASS

---

## TEST 19 — Deterministic Lock (ADR-040)
Exit price computed at fill time must not change across subsequent ticks.

Inputs:
- fill_price = 1.13000
- entry_spread_raw = 0.0010
- layer_index = 0
- direction = BUY (1)
- MinLayerExitPoints = 2, point = 0.00001
- half_spread = 0.000005

E_0 = 0.0010 * MathPow(0.618, 1) = 0.000618
raw_target = 1.13000 + 0.000618 = 1.130618
after_half_spread = 1.130618 - 0.000005 = 1.130613
floor_price = 1.13000 + 2 * 0.00001 = 1.13002
exit_price_fixed = MathMax(1.130613, 1.13002) = 1.130613

19a. exit_price_fixed = 1.130613
     Expected: 1.130613  PASS

19b. Simulate 100 ticks with varying live bid/ask.
     exit_price_fixed unchanged across all ticks.
     Expected: invariant holds — PASS

---

## TEST 20 — Golden Rule A_n > E_n (ADR-040, updated per Gemini live ruling)
Linear add distance must exceed exit distance on every layer.
A_n uses golden inverse spacing: A_golden = E_n * 1.618, A_n = max(base_add, A_golden)

Inputs:
- entry_spread_raw = 0.0010
- QuoteSpread = 0.0004  (4 bps base add)
- layer_index n = 0..5
- E_n = 0.0010 * MathPow(0.618, n+1)
- A_golden_n = E_n * 1.618
- A_n = MathMax(QuoteSpread * (n+1), A_golden_n)

n=0: E_0=0.000618, A_golden=0.000999, A_0=MathMax(0.0004, 0.000999)=0.000999  → A_0 > E_0 PASS
n=1: E_1=0.000382, A_golden=0.000618, A_1=MathMax(0.0008, 0.000618)=0.000800  → A_1 > E_1 PASS
n=2: E_2=0.000236, A_golden=0.000382, A_2=MathMax(0.0012, 0.000382)=0.001200  → A_2 > E_2 PASS
n=3: E_3=0.000146, A_golden=0.000236, A_3=MathMax(0.0016, 0.000236)=0.001600  → A_3 > E_3 PASS
n=4: E_4=0.000090, A_golden=0.000146, A_4=MathMax(0.0020, 0.000146)=0.002000  → A_4 > E_4 PASS
n=5: E_5=0.000056, A_golden=0.000090, A_5=MathMax(0.0024, 0.000090)=0.002400  → A_5 > E_5 PASS

20a-f. A_n > E_n for all n=0..5
       Expected: all TRUE — PASS

20g. Strong signal golden ratio check (entry_spread_raw=0.0010, n=0):
     A_golden = 0.000618 * 1.618 = 0.000999
     A_0 = 0.000999
     A_0 / E_0 = 0.000999 / 0.000618 = 1.618
     Expected: ratio = 1.618 (tol 0.001) — PASS

---

## TEST 21 — 3-Pip Hard Floor (ADR-041, MinLayerExitPoints=30)
Degenerate near-zero signal entry must be clamped to MinLayerExitPoints floor.
MinLayerExitPoints=30 enforces a 3.0 pip minimum exit distance.

Inputs:
- fill_price = 1.13000
- entry_spread_raw = 0.00003  (0.3 pip — toxic entry, below SkewFloor0)
- layer_index = 0
- direction = BUY (1)
- MinLayerExitPoints = 30, point = 0.00001
- half_spread = 0.000005

E_0 = 0.00003 * 0.618 = 0.00001854
raw_target = 1.13000 + 0.00001854 = 1.13001854
after_half_spread = 1.13001854 - 0.000005 = 1.13001354
floor_dist = 30 * 0.00001 = 0.00030  (3.0 pips)
floor_price = 1.13000 + 0.00030 = 1.13030
exit_price_fixed = MathMax(1.13001354, 1.13030) = 1.13030

21a. exit_price_fixed clamped to 3-pip floor = 1.13030
     Expected: 1.13030  PASS
21b. exit_price_fixed > fill_price (1.13000)
     Expected: TRUE  PASS
21c. Near-zero signal WARNING logged
     Expected: WARNING present in log  PASS

---

## TEST 22 — Grid Expansion (ADR-040 Addendum)
Add distance must grow or safely plateau as layer index increases and spread widens.
entry_spread_raw is not static — it widens as market moves to fill each successive layer.

# Layer 0
spread_0 = 0.0010; qs = 0.0004
E_0 = spread_0 * 0.618 = 0.000618
A_golden_0 = 0.000618 * 1.618 = 0.001000
A_0 = MathMax(0.0004 * 1, 0.001000) = 0.001000  (10.0 pips)

# Layer 1 — market moves A_0 against us to fill, spread widens by A_0
spread_1 = spread_0 + A_0 = 0.0010 + 0.0010 = 0.0020
E_1 = spread_1 * MathPow(0.618, 2) = 0.0020 * 0.381924 = 0.000764
A_golden_1 = 0.000764 * 1.618 = 0.001236
A_1 = MathMax(0.0004 * 2, 0.001236) = 0.001236  (12.4 pips)

22a. A_1 >= A_0: 0.001236 > 0.001000
     Expected: TRUE — grid expands as divergence widens PASS
22b. A_1 / A_0 ratio = 0.001236 / 0.001000 = 1.236
     Expected: > 1.0 — add spacing grows monotonically at layer 1 PASS

---

## TEST 23 — Phi Curve (ADR-040)
Exit multiplier must follow exact golden ratio conjugate decay.

phi = 0.618

n=0: MathPow(0.618, 1) = 0.618000
n=1: MathPow(0.618, 2) = 0.381924
n=2: MathPow(0.618, 3) = 0.236029

23a. multiplier n=0 = 0.618000   Expected: 0.618000  PASS (tol 0.000001)
23b. multiplier n=1 = 0.381924   Expected: 0.381924  PASS (tol 0.000001)
23c. multiplier n=2 = 0.236029   Expected: 0.236029  PASS (tol 0.000001)

---

## TEST 24 — Strong Signal Invariant A_n > E_n (ADR-040, Q3 Ruling revised)
Validates golden ratio add spacing on SniperThreshold-level entry (14 pips).

Inputs:
- entry_spread_raw = 0.0014  (14 pip SNIPER entry)
- QuoteSpread = 0.0004
- layer_index = 0

E_0 = 0.0014 * 0.618 = 0.0008652
A_golden = 0.0008652 * 1.618 = 0.0013998
A_0 = MathMax(0.0004 * 1, 0.0013998) = 0.0013998

24a. A_0 / E_0 = 0.0013998 / 0.0008652 = 1.618
     Expected: 1.618 (tol 0.001) — golden ratio preserved on strong signal PASS
24b. A_0 > E_0: 0.0013998 > 0.0008652
     Expected: TRUE PASS
24c. A_base < A_golden: 0.0004 < 0.0013998
     Expected: TRUE — golden add dominates on strong signal PASS

---

## TEST 25 — Reattach Reconciliation (ADR-040, Q1 Ruling)
On reattach, any layer with exit_price_fixed at sentinel (-1.0) must be
recomputed from stored entry_spread_raw before PlaceExitLimit is armed.

Inputs (simulated JSON state layer):
- entry_spread_raw = 0.0010
- layer_index = 0
- direction = BUY (1)
- fill_price (entry_price) = 1.13000
- exit_price_fixed = -1.0  (sentinel — unpopulated)
- exit_tickets = []
- MinLayerExitPoints = 2, point = 0.00001
- half_spread = 0.000005

After reconciliation pass:
E_0 = 0.0010 * 0.618 = 0.000618
raw_target = 1.13000 + 0.000618 = 1.130618
after_half_spread = 1.130613
floor_price = 1.13002
exit_price_fixed = 1.130613

25a. exit_price_fixed recomputed from sentinel = 1.130613
     Expected: 1.130613  PASS
25b. exit_price_fixed != sentinel (-1.0)
     Expected: TRUE  PASS
25c. reconciliation_pending flag set in OnInit, cleared after first OnTick pass
     Expected: behavioral — verify via log line "Reconciliation pass complete. N layers re-armed."

---

## TEST 26 — 70% Binary Gate Math (ADR-042)

**Purpose:** Verify the binary gate threshold fires correctly at, above, and below the 70% cutoff.

**Constants:** `BaseLotSize=0.01`, `size_mult=1.0`, `min_vol=0.01`

**Formula:**
```
raw_vol = BaseLotSize * size_mult * w
if raw_vol < min_vol * 0.70 → return 0.0  (quote pulled)
else                         → return max(raw_vol, min_vol)
```

### 26a — Below threshold (gate does not fire)
```
w = 0.68
raw_vol = 0.01 * 1.0 * 0.68 = 0.0068
threshold = 0.01 * 0.70 = 0.007
0.0068 < 0.007 → TRUE
expected: return 0.0
```

### 26b — Above threshold (gate does not fire)
```
w = 0.71
raw_vol = 0.01 * 1.0 * 0.71 = 0.0071
threshold = 0.01 * 0.70 = 0.007
0.0071 < 0.007 → FALSE
lot_size = max(0.0071, 0.01) = 0.01
expected: return 0.01
```

### 26c — Exact boundary (gate does NOT fire — condition is strict less-than)
```
w = 0.70
raw_vol = 0.01 * 1.0 * 0.70 = 0.0070
threshold = 0.01 * 0.70 = 0.007
0.0070 < 0.007 → FALSE  (equal, not less than)
lot_size = max(0.0070, 0.01) = 0.01
expected: return 0.01
```

**Expected results:**
| Subtest | w | raw_vol | Gate fires? | Return |
|---------|---|---------|-------------|--------|
| 26a | 0.68 | 0.0068 | YES | 0.0 |
| 26b | 0.71 | 0.0071 | NO | 0.01 |
| 26c | 0.70 | 0.0070 | NO | 0.01 |

---

## TEST 27 — Intent Gate S_eff Collapse (ADR-042)

**Purpose:** Verify that forcing `S_eff=10.0` on intent overlap produces `raw_vol` well below the 70% gate threshold, and that the no-overlap path is unaffected.

**Constants:** `BaseLotSize=0.01`, `size_mult=1.0`, `min_vol=0.01`

**Formula:**
```
w = 1.0 / (1.0 + S_eff * S_eff)
raw_vol = BaseLotSize * size_mult * w
```

### 27a — Intent overlap detected (S_eff forced to 10.0)
```
S_eff = 10.0
w = 1.0 / (1.0 + 10.0 * 10.0)
  = 1.0 / (1.0 + 100.0)
  = 1.0 / 101.0
  = 0.00990099...
raw_vol = 0.01 * 1.0 * 0.00990099 = 0.0000990099
threshold = 0.01 * 0.70 = 0.007
0.0000990099 < 0.007 → TRUE
expected: return 0.0  (quote pulled)
```

### 27b — No overlap, zero correlation (S_eff = 0.0)
```
S_eff = 0.0
w = 1.0 / (1.0 + 0.0) = 1.0
raw_vol = 0.01 * 1.0 * 1.0 = 0.01
threshold = 0.007
0.01 < 0.007 → FALSE
lot_size = max(0.01, 0.01) = 0.01
expected: return 0.01
```

### 27c — No overlap, moderate correlation (g_corr=0.5, v_eff=1.3)
```
S = max(0.5, 0.0) * max(1.3 - 1.0, 0.0) = 0.5 * 0.3 = 0.15
S_eff = 0.15
w = 1.0 / (1.0 + 0.15 * 0.15)
  = 1.0 / (1.0 + 0.0225)
  = 1.0 / 1.0225
  = 0.97799511...
raw_vol = 0.01 * 1.0 * 0.97799511 = 0.0097799511
threshold = 0.007
0.0097799511 < 0.007 → FALSE
lot_size = max(0.0097799511, 0.01) = 0.01
expected: return 0.01
```

**Expected results:**
| Subtest | S_eff | w | raw_vol | Gate fires? | Return |
|---------|-------|---|---------|-------------|--------|
| 27a | 10.0 (forced) | 0.00990099 | 0.00009901 | YES | 0.0 |
| 27b | 0.0 | 1.0 | 0.01 | NO | 0.01 |
| 27c | 0.15 | 0.97799511 | 0.00977995 | NO | 0.01 |

---

## TEST 28 — size_mult Interaction with Binary Gate (ADR-042)

**Purpose:** Verify that pod drawdown stress (`size_mult < 1.0`) interacts correctly with the 70% gate — the gate can fire from drawdown stress alone, independently of LDAK penalty.

**Constants:** `BaseLotSize=0.01`, `min_vol=0.01`, `w=1.0` (no LDAK penalty, no intent override)

**Formula:**
```
raw_vol = BaseLotSize * size_mult * w
```

### 28a — Heavy drawdown stress (gate fires from size_mult alone)
```
size_mult = 0.50
w = 1.0
raw_vol = 0.01 * 0.50 * 1.0 = 0.005
threshold = 0.01 * 0.70 = 0.007
0.005 < 0.007 → TRUE
expected: return 0.0  (quote pulled)
```

### 28b — Moderate drawdown stress (gate does not fire)
```
size_mult = 0.75
w = 1.0
raw_vol = 0.01 * 0.75 * 1.0 = 0.0075
threshold = 0.007
0.0075 < 0.007 → FALSE
lot_size = max(0.0075, 0.01) = 0.01
expected: return 0.01
```

### 28c — Combined stress: moderate drawdown + moderate LDAK penalty (gate does not fire)
```
size_mult = 0.85
S_eff = 0.15  (no intent override — rolling correlation)
w = 1.0 / (1.0 + 0.15 * 0.15) = 1.0 / 1.0225 = 0.97799511
raw_vol = 0.01 * 0.85 * 0.97799511 = 0.00831296
threshold = 0.007
0.00831296 < 0.007 → FALSE
lot_size = max(0.00831296, 0.01) = 0.01
expected: return 0.01
```

### 28d — Combined stress: heavy drawdown + intent override (gate fires, doubly)
```
size_mult = 0.85
S_eff = 10.0  (intent override)
w = 1.0 / 101.0 = 0.00990099
raw_vol = 0.01 * 0.85 * 0.00990099 = 0.0000841584
threshold = 0.007
0.0000841584 < 0.007 → TRUE
expected: return 0.0
```

**Expected results:**
| Subtest | size_mult | w | raw_vol | Gate fires? | Return |
|---------|-----------|---|---------|-------------|--------|
| 28a | 0.50 | 1.0 | 0.005000 | YES | 0.0 |
| 28b | 0.75 | 1.0 | 0.007500 | NO | 0.01 |
| 28c | 0.85 | 0.97799511 | 0.008313 | NO | 0.01 |
| 28d | 0.85 | 0.00990099 | 0.000084 | YES | 0.0 |

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
| 13 | ADR-038 | MinLayerExitPoints / SkewFloor0 synchronisation |
| 14 | ADR-040 | Deterministic function statelessness |
| 15 | ADR-040 | Zero spread sentinel and floor clamp |
| 16 | ADR-040 | Sign contract — BUY exit above entry, SLOT_AC |
| 17 | ADR-040 | Sign contract — SELL exit below entry, SLOT_AC |
| 18 | ADR-040 | Sign contract — all three slots, both directions |
| 19 | ADR-040 | Deterministic lock — exit_price_fixed invariant |
| 20 | ADR-040 | Golden rule A_n > E_n all layers |
| 21 | ADR-041 | 3-pip hard floor — degenerate entry clamp |
| 22 | ADR-040 | Grid expansion — A grows, E decays |
| 23 | ADR-040 | Phi curve — golden ratio multiplier exact values |
| 24 | ADR-040 | Strong signal invariant — SNIPER-level entry scaling |
| 25 | ADR-040 | Reattach reconciliation — sentinel recovery |
| 26 | ADR-042 | 70% binary gate threshold — below / above / boundary |
| 27 | ADR-042 | Intent gate S_eff=10.0 collapse vs no-overlap paths |
| 28 | ADR-042 | size_mult drawdown stress interaction with gate |
| 29 | ADR-043 | Layer 0 inventory gate — Phase 3 resume ping-pong fix |
| 30 | Median anchor | StrengthWindow anchor + MathMedianCentered spike protection |
| 31 | ADR-045 | Spatial carry drift math — rollover limit adjustment |
| 32 | ADR-046 | Dynamic spread cooldown & exit decoupling |
| 33 | ADR-042 Fix | Symmetric slot-level LDAK gate |

---

## TEST 29 — Layer 0 Inventory Gate (ADR-043)

**Purpose:** Verify that Phase 3 resume quoting does not reload Layer 0 directional risk when same-direction inventory is still live on the slot. Gate uses `position_ticket > 0` as the canonical live-position signal — not `remaining_exit_volume`.

**Function under test:** `SameDirectionInventoryExists(int instrument, int direction)`

**Gate applies to:** Phase 3 resume `PlaceEntryLimit()` calls only (post-exit-fill pod close path).

### 29a — Gate fires and blocks when same-direction inventory exists with position_ticket > 0

```
Setup:
  instrument = SLOT_AC (0)
  direction  = DIRECTION_BUY
  g_inventory_0[0].direction        = DIRECTION_BUY
  g_inventory_0[0].position_ticket  = 12345678  (> 0, live position)

Call: SameDirectionInventoryExists(0, DIRECTION_BUY)
Expected: return TRUE
Effect:   PlaceEntryLimit() NOT called for bid leg in Phase 3 resume
          EnableVerboseLog prints:
          "INFO [ADR-043] Layer 0 blocked — same-direction inventory exists."
          with direction=BUY
```

### 29b — Gate allows Layer 0 when inventory exists but position_ticket == 0 (closed position)

```
Setup:
  instrument = SLOT_AC (0)
  direction  = DIRECTION_BUY
  g_inventory_0[0].direction        = DIRECTION_BUY
  g_inventory_0[0].position_ticket  = 0  (closed — not live)

Call: SameDirectionInventoryExists(0, DIRECTION_BUY)
Expected: return FALSE
Effect:   PlaceEntryLimit() proceeds normally for bid leg in Phase 3 resume
```

### 29c — Gate allows Layer 0 when inventory exists but is in the opposite direction

```
Setup:
  instrument = SLOT_BC (1)
  direction  = DIRECTION_BUY  (bid leg under test)
  g_inventory_1[0].direction        = DIRECTION_SELL  (opposite)
  g_inventory_1[0].position_ticket  = 87654321  (> 0, live position)

Call: SameDirectionInventoryExists(1, DIRECTION_BUY)
Expected: return FALSE
Effect:   PlaceEntryLimit() proceeds normally for bid leg in Phase 3 resume
          (live SELL inventory does not block BUY Layer 0)
```

**Expected results:**
| Subtest | Same direction? | position_ticket | Gate blocks? | PlaceEntryLimit called? |
|---------|-----------------|-----------------|--------------|-------------------------|
| 29a | YES | > 0 | YES | NO |
| 29b | YES | 0 | NO | YES |
| 29c | NO (opposite) | > 0 | NO | YES |

---

## TEST 30 — Median Anchor Filter & StrengthWindow Fix

**Purpose:** Verify `MathMedianCentered()` median anchor immunization and `StrengthWindow`-driven anchor index (replacing hardcoded `closes[12]`).

### 30a — MathMedianCentered() odd count, clean series

```
arr = [..., 1.13500, 1.13510, 1.13520, 1.13530, 1.13540, ...]
center_index = 2 (value 1.13520), width = 5
window = [arr[0], arr[1], arr[2], arr[3], arr[4]]
       = [1.13500, 1.13510, 1.13520, 1.13530, 1.13540]
sorted = [1.13500, 1.13510, 1.13520, 1.13530, 1.13540]
median = sorted[2] = 1.13520
expected: 1.13520
```

### 30b — MathMedianCentered() spike immunization

```
arr = [..., 1.13500, 1.13510, 1.13999, 1.13530, 1.13540, ...]
center_index = 2 (spike at 1.13999), width = 5
window = [1.13500, 1.13510, 1.13999, 1.13530, 1.13540]
sorted = [1.13500, 1.13510, 1.13530, 1.13540, 1.13999]
median = sorted[2] = 1.13530
expected: 1.13530  (spike pushed to edge, median unaffected)
```

### 30c — StrengthWindow=12 anchor index

```
StrengthWindow = 12, width = 5
window covers indices 10, 11, 12, 13, 14
Before fix: single bar closes[12]
After fix:  median of closes[10..14]
At SW=12, clean series: median ≈ closes[12] (centre value)
expected: no material behavioural change on clean data
```

### 30d — StrengthWindow=6 anchor index

```
StrengthWindow = 6, width = 5
window covers indices 4, 5, 6, 7, 8
Before fix: single bar closes[12]  (wrong — always 1 hour ago)
After fix:  median of closes[4..8] (correct — centred on 30 min ago)
expected: different anchor value — fix is material when SW != 12
```

### 30e — CopyClose buffer guard

```
StrengthWindow = 48
min_bars = MathMax(289, 48 + 25) = MathMax(289, 73) = 289

StrengthWindow = 300 (hypothetical)
min_bars = MathMax(289, 300 + 25) = MathMax(289, 325) = 325

expected: min_bars = 289 for SW <= 264
          min_bars = SW + 25 for SW > 264
```

### 30f — MathMedianCentered() bounds degradation

```
arr = [1.13510, 1.13520, 1.13530]  (ArraySize = 3)
center_index = 1, width = 5 → half = 2
center_index - half = -1 < 0 → bounds check fires
expected: return arr[1] = 1.13520  (graceful degradation, no crash)
```

---

## TEST 31 — Spatial Carry Drift Math (ADR-045)

**Purpose:** Verify unified drift math for daily rollover spatial adjustment on entry and exit limits.

### 31a — Long side negative swap, Tuesday

```
swap_long = -4.0 points, multiplier = 1, point = 0.00001
shift = 4.0 * 1 * 0.00001 = 0.00004
BUY_LIMIT entry: 1.30000 + 0.00004 = 1.30004
SELL_LIMIT exit (long pos): 1.30800 + 0.00004 = 1.30804
expected: entry=1.30004, exit=1.30804
```

### 31b — Short side negative swap, Tuesday

```
swap_short = -6.0 points, multiplier = 1, point = 0.00001
shift = 6.0 * 1 * 0.00001 = 0.00006
SELL_LIMIT entry: 1.30500 - 0.00006 = 1.30494
BUY_LIMIT exit (short pos): 1.29800 - 0.00006 = 1.29794
expected: entry=1.30494, exit=1.29794
```

### 31c — Wednesday triple swap

```
swap_long = -4.0 points, multiplier = 3, point = 0.00001
shift = 4.0 * 3 * 0.00001 = 0.00012
BUY_LIMIT entry: 1.30000 + 0.00012 = 1.30012
expected: 1.30012
```

### 31d — Positive carry, no adjustment

```
swap_long = +2.0 points
swap >= 0 → no adjustment
expected: order price unchanged
```

### 31e — EURGBP 5-digit point value

```
swap_short = -3.0 points, multiplier = 1, point = 0.00001
shift = 3.0 * 1 * 0.00001 = 0.00003
SELL_LIMIT entry: 0.86500 - 0.00003 = 0.86497
expected: 0.86497
```

---

## TEST 32 — Dynamic Spread Cooldown & Exit Decoupling (ADR-046)

**Purpose:** Verify viscous cooldown high-water mark, decay floor, and exit spread decoupling from LDAK dilation.

### 32a — Cooldown snap on shock

```
g_cooldown_LDAK[0] = 1.2  (current)
live_dilation = 2.5        (new shock)
live_dilation > g_cooldown_LDAK[0] → snap
expected: g_cooldown_LDAK[0] = 2.5
```

### 32b — Cooldown viscous decay

```
g_cooldown_LDAK[0] = 2.5, CooldownDecayRate = 0.01
live_dilation = 1.1  (calm, below HWM)
g_cooldown_LDAK[0] * (1 - 0.01) = 2.5 * 0.99 = 2.475
MathMax(1.0, 2.475) = 2.475
expected: g_cooldown_LDAK[0] = 2.475
```

### 32c — Cooldown floor at 1.0

```
g_cooldown_LDAK[0] = 1.005, CooldownDecayRate = 0.01
live_dilation = 1.0
1.005 * 0.99 = 0.99495
MathMax(1.0, 0.99495) = 1.0
expected: g_cooldown_LDAK[0] = 1.0
```

### 32d — Exit decoupling: dilated spread capped at BaseThreshold

```
entry_spread_raw = 0.0035  (35 bps — dilated by LDAK shock)
BaseThreshold = 0.0004     (8 bps baseline — note: use MathAbs)
effective_spread = MathMin(0.0035, 0.0004) = 0.0004
E_0 = 0.0004 * MathPow(0.618, 1) = 0.0004 * 0.618 = 0.0002472
expected: E_0 = 0.0002472
```

### 32e — Exit decoupling: normal spread unchanged

```
entry_spread_raw = 0.0003  (3 bps — below BaseThreshold)
BaseThreshold = 0.0004
effective_spread = MathMin(0.0003, 0.0004) = 0.0003
E_0 = 0.0003 * 0.618 = 0.0001854
expected: E_0 = 0.0001854
```

### 32f — Cooldown decay rate boundary: exactly at 1.0

```
g_cooldown_LDAK[0] = 1.0 (already at floor)
live_dilation = 1.0
1.0 * 0.99 = 0.99 → MathMax(1.0, 0.99) = 1.0
expected: g_cooldown_LDAK[0] = 1.0  (no change)
```

---

## TEST 33 — Symmetric Slot-Level LDAK Gate (ADR-042 Fix)

**Purpose:** Verify slot-level LDAK suppression math and SLOT_AB exemption.

### 33a — High correlation does not suppress slot

```
g_corr[AC/BC] = 0.95, g_vratio[AC] = 1.3, g_vratio[BC] = 1.2
S_eff = 0.95 * max(1.3 - 1.0, 0) = 0.95 * 0.3 = 0.285
w = 1 / (1 + 0.285^2) = 1 / 1.081225 = 0.92487688
raw_vol = 0.01 * 0.92487688 = 0.00924877
0.00924877 >= 0.007 → NOT suppressed
expected: IsSlotSuppressedByLDAK = false
```

### 33b — Very high correlation suppresses slot

```
g_corr[AC/BC] = 0.95, g_vratio[AC] = 2.0, g_vratio[BC] = 1.8
S_eff = 0.95 * max(2.0 - 1.0, 0) = 0.95 * 1.0 = 0.95
w = 1 / (1 + 0.95^2) = 1 / 1.9025 = 0.52562418
raw_vol = 0.01 * 0.52562418 = 0.00525624
0.00525624 < 0.007 → SUPPRESSED
expected: IsSlotSuppressedByLDAK = true
```

### 33c — SLOT_AB never suppressed

```
instrument = SLOT_AB (2)
expected: IsSlotSuppressedByLDAK = false immediately (no peer check)
```

### 33d — Low correlation allows both legs

```
g_corr[AC/BC] = 0.0007 (from live log 04:05)
g_vratio[AC] = 0.670, g_vratio[BC] = 0.686
v_eff = max(0.670, 0.686) = 0.686
S = 0.0007 * max(0.686 - 1.0, 0) = 0.0007 * 0 = 0.0
S_eff = 0.0
w = 1.0
raw_vol = 0.01 >= 0.007 → NOT suppressed
expected: IsSlotSuppressedByLDAK = false
```

---

## TEST 34 — Phase 3 Resume ADR-047

**Purpose:** Verify spread sign correction and ADR-037 weak signal gate on Phase 3 resume.

### 34a — Spread sign correction (BUY slot, positive inst_spread)

```
inst_spread = 0.000686, QuoteSpread = 0.0004
bid_spread   = 0.000686 - 0.0004 = 0.000286  ← bid below mid
offer_spread = 0.000686 + 0.0004 = 0.001086  ← offer above mid
expected: bid_spread=0.000286, offer_spread=0.001086
```

### 34b — Spread sign correction (SELL slot, negative inst_spread)

```
inst_spread = -0.000779, QuoteSpread = 0.0004
bid_spread   = -0.000779 - 0.0004 = -0.001179  ← bid below mid
offer_spread = -0.000779 + 0.0004 = -0.000379  ← offer above mid (less negative)
expected: bid_spread=-0.001179, offer_spread=-0.000379
```

### 34c — ADR-037 gate fires (weak signal)

```
inst_spread = 0.000109, SkewFloor0 = 0.0002, MinLayerExitPoints = 30, point = 0.00001
floor_n = MathMax(0.0002 * 0.618^0, 30 * 0.00001) = MathMax(0.0002, 0.0003) = 0.0003
MathAbs(0.000109) = 0.000109 <= 0.0003 → gate fires
expected: resume suppressed, no PlaceEntryLimit calls
```

### 34d — ADR-037 gate does not fire (strong signal)

```
inst_spread = -0.000779, SkewFloor0 = 0.0002, MinLayerExitPoints = 30, point = 0.00001
floor_n = MathMax(0.0002, 0.0003) = 0.0003
MathAbs(-0.000779) = 0.000779 > 0.0003 → gate does not fire
expected: resume proceeds, PlaceEntryLimit called for both directions
```

### 34e — floor_n computation

```
SkewFloor0 = 0.0002, phi = 0.6180339887
SkewFloor0 * MathPow(phi, 0) = 0.0002 * 1.0 = 0.0002
MinLayerExitPoints = 30, point = 0.00001
MinLayerExitPoints * point = 0.0003
floor_n = MathMax(0.0002, 0.0003) = 0.0003
expected: floor_n = 0.0003
```

---

## TEST 35 — Freeze Level Clamp (ADR-048)

**Purpose:** Verify freeze-zone clamp and post-clamp direction checks in cooldown drag.

### 35a — BUY limit inside freeze zone, clamp fires

```
bid = 1.32200, freeze_pts = 20, point = 0.00001
freeze_dist = 20 * 0.00001 = 0.00020
min_dist = 0.00020 + 2 * 0.00001 = 0.00022
ideal_price = 1.32190  (bid - ideal = 0.00010 < 0.00022 → clamp fires)
clamped = bid - min_dist = 1.32200 - 0.00022 = 1.32178
expected: ideal_price = 1.32178
```

### 35b — SELL limit inside freeze zone, clamp fires

```
ask = 1.32210, freeze_pts = 20, point = 0.00001
freeze_dist = 0.00020, min_dist = 0.00022
ideal_price = 1.32220  (ideal - ask = 0.00010 < 0.00022 → clamp fires)
clamped = ask + min_dist = 1.32210 + 0.00022 = 1.32232
expected: ideal_price = 1.32232
```

### 35c — BUY limit outside freeze zone, no clamp

```
bid = 1.32200, freeze_pts = 20, point = 0.00001
min_dist = 0.00022
ideal_price = 1.31970  (bid - ideal = 0.00230 > 0.00022 → no clamp)
expected: ideal_price = 1.31970 (unchanged)
```

### 35d — Post-clamp direction check: clamped BUY not above cur_price, skip

```
cur_price = 1.32185  (current resting BUY limit price)
clamped ideal_price = 1.32178
direction = DIRECTION_BUY
ideal_price (1.32178) <= cur_price (1.32185) → continue (skip, not moving toward market)
expected: drag skipped
```

### 35e — Post-clamp direction check: clamped BUY above cur_price, proceed

```
cur_price = 1.32150  (current resting BUY limit price)
clamped ideal_price = 1.32178
direction = DIRECTION_BUY
For a BUY limit, dragging toward market means moving UP (closer to bid).
ideal_price (1.32178) > cur_price (1.32150) → proceed
expected: drag proceeds
```

---

## PROTOCOL

Before any code change to MathEngine.mqh, ExecutionEngine.mqh, or
FXMatrix.mq5, embed these tests in the Cursor prompt and require all
tests to PASS before diffs are generated.

Test 0 is the gate. If Test 0 fails, nothing else matters.

---
