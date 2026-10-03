This message has a line count at the bottom

# DESIGN MEMO -- POST-ONCE EXECUTION, NETTING AND RINGS (IDEA, NOT RULED)

| | |
|---|---|
| Status | **IDEA** (operator and Claude, 2 Oct ~21:50Z to 3 Oct ~03:15Z). Not ruled; no code. Needs the checks in s10, then an ADR and Gemini |
| Backlog | C117 (post-once execution), C118 (Python engine port, equality tests); feeds C106 (FTMO request budget), C96 (rings) |
| Evidence | FTMO VPS Journal 2 Oct (C106 numbers, s3); pipshed `--l0churn` 2 Oct; study export 2 Oct; FTMO Market Watch 2 Oct close; HANDOFF s38 |

## 1. ORIGIN

MyFundedPerps (a simulated crypto-perps prop firm with a REST API) gave the
operator a free 2.5k account. Perps venues net every symbol, which started
the question: what if fxgrind kept its logic but held one netted position
per pair? Operator, 3 Oct ~03:15Z: "we might end up skipping myfundedperps
- and stick with ftmo/ic - it is just myfundedperps gave us the idea to
think about netting." MyFundedPerps facts (docs, 2 Oct): API in beta;
REST + WebSocket + MCP; ~300 requests/min per IP; per-account policy
(trades per minute, order cooldown, max resting orders); HFT and
"excessive order activity" banned without numbers; markets list not
checked (crypto; FX unknown).

## 2. FACTS (MT5)

- **Hedging accounts (FTMO 1514731800 and the IC demos):** every fill opens
  a position. An opposite limit fill opens a NEW position; it never reduces
  the existing one (ADR-125: the 7 Sep `I3_SHORT_NAKED` halts). Same-
  direction fills never merge: there is no "add by". Close-by works with
  unequal volumes (the smaller closes, the larger is reduced). So on a
  hedging account the floor is one position per open layer.
- **Netting accounts:** one position per symbol; the mode is fixed when the
  broker opens the account. MT5 began netting-only (2010); hedging came in
  build 1325 (2016) for retail FX. FTMO's US offering (with OANDA) is
  reported to run netting with FIFO; ours is hedging. Whether IC issues
  netting MT5 demos: not known.
- **Slots: 200 positions + pending orders combined** (FTMO, ADR-151;
  operator 3 Oct: the same software limit on IC, tested). TP and SL are
  position properties and are expected not to count (to confirm with FTMO).
- **A modify keeps the order's slot and costs one request, but cannot change
  its comment** (ADR-125).

## 3. THE REQUEST PROBLEM (C106, FTMO DAY 2 OCT)

| 22:00Z 1 Oct - 22:00Z 2 Oct, VPS Journal | |
|---|---|
| Requests sent | 1,476 (74% of 2,000) |
| sell limit / buy limit | 369 / 354 |
| cancel / modify | 355 / 181 |
| close position (close-by) | 206 |
| market buy | 11 |
| deal lines (fills) / failed | 608 / 10 |
| Requests per fill / per round trip | 2.4 / ~4.9 |
| 12Z-14Z (12Z alone) | 755 (396); likely US payrolls, unchecked |
| 16Z-21Z (after the cut to seven) | 97 |

L0 entry modifies are 14% of all modifies (565 of 4,093 in 14 days); the
rest of the cancels and modifies are mostly exit-queue rank swaps (ADR-151).
Operator: 2,000 should be ample ("50 buys and 50 sells for a position in a
day for 21 positions ... 2100 api hits would be more than enough"). That
holds at ~1 request per fill.

## 4. THE DESIGN: POST ONCE, LEAVE IT

Operator, 3 Oct ~03:10Z: "we place a bid, we leave it. we place an offer -
we leave it. occasionally we do a roll." The only cancel is a roll.
Purgatory's exit queue exists to ration slots and churns requests; it
cannot coexist with post-once.

Every layer then always holds exactly one slot. Two ways to execute:

| Per layer | (a) Hedging + TP exits | (b) Netting, virtual book |
|---|---|---|
| Entry | one limit carrying the exit as TP | one limit |
| Exit | the TP (server closes; no request) | one exit order, sent after the fill |
| Requests per round trip | **1** | 2 |
| Slots | 1 (resting entry or position with TP) | 1 (resting entry or exit order) + 1 position per pair |
| Close-by | none | none |

Under post-once, (a) matches (b) on slots and beats it on requests, on the
accounts we already have. Netting's remaining edge is carry on offsetting
long and short volume (total carry was $1.2-1.8/day per fleet, C10).

- **Rolls as modifies:** one request, same slot, never uncovered. The
  engine maps layers by ticket, so the unchanged comment does not matter.
  If a roll must cancel and place: place first when a slot is free, else
  cancel first; at most one roll in flight per pair.
- **Hard ceiling:** the EA never sends an order that would pass 200; a
  10040 refusal (naked layer, halt) becomes a logged non-event.
- **Accounting:** a scalp completes on the TP close (`[tp]` suffix in the
  comment is already parsed, ADR-125); layer P&L from the EA's ledger.
- **Ejection (ADR-155/157):** every layer's exit already exists at the
  broker as a TP; the ejection paths change with it.

## 5. SLOT ARITHMETIC

Slots at full depth = 2 x pairs x cap (+ pairs on a netting account).

| Universe | Pairs | Cap | (a) TP | (b) Netting |
|---|---|---|---|---|
| 7-currency ring | 7 | 8 / 10 | 112 / 140 | 119 / 147 |
| 6-currency ring | 6 | 8 | 96 | 102 |
| All 15 pairs of 6 currencies | 15 | 8 | 240 (over) | 255 (over) |
| **Operator's five: EUR GBP CHF CAD AUD, all 10 pairs** | 10 | **9** | **180** | **190** |
| All 21 pairs of 7 currencies | 21 | 8 | 336 (over) | 357 (over) |

Operator, 3 Oct ~03:07Z: 5 currencies, 10 pairs, 9 layers -> 190; "we have
the space of 10 to do the rolls" (one roll in flight per pair). With rolls
as modifies the 10 are margin. 21 pairs = three accounts, one ring each
(s8: rings 0-2 cover all 21 pairs once).

## 6. RISK OF THE FIVE-CURRENCY SET

- Layers stay 0.01. Each currency is in 4 pairs instead of 2, so a one-
  currency trend is about double (operator: "only double the risk"); a two-
  currency divergence touches 7 of 10 pairs vs 3 of 7 (~2.3x).
- On a 100k account the daily limit is x10 ($5,000 vs $500), so a bad
  currency day is ~0.2x today's share of the limit (B 2 Oct: 44.6% of $500
  -> ~9%). Room to raise lots later.
- Claude's cautions (operator heard, not ruled): every currency in 4 pairs
  is the opposite of the ring rule (C96; the 1 Oct CHF trend capped three
  CHF pairs at once); no USD (EURUSD, GBPUSD: tightest spreads, best pairs
  this week); several of the ten crosses are the widest (GBPAUD, GBPCAD,
  EURCAD at the 2 Oct close). All 10 triangles are traded directly.

## 7. REQUEST BUDGET

- **One pool of 2,000, first come first served** (operator: "no point
  keeping 200 ring fenced if one pair is stationary and the other is going
  wild"). The existing per-account counter (GV) already works this way.
- Busy-day estimate per pair (2 Oct: ~55-65 fills per instance, ~4 rolls
  per pair on IC): ~40 requests with (a), ~70 with (b); a payrolls hour
  ~20 per pair.
- Runaway loops: no EA logic for now (operator: we would have seen a loop
  this week; Claude: 16 Sep FOMC went 822 -> 3,414 requests in 23 minutes,
  ADR-151, and the new code is new). Cheap option: pipshed shows requests
  per fill per instance.

## 8. RINGS

- A single ring = each of the 7 currencies exactly twice, one closed loop:
  (7-1)!/2 = **360**. Triangle + square layouts (today's): 105. Chains of 7
  pairs that only share a currency with the next ("loose"): 18,735, all but
  the 360 with some currency 3-6 times.
- From today's nine pairs (the EUR/GBP/USD triangle + all six AUD/CAD/CHF/
  NZD pairs) no single ring exists; the best keep 5 and add 2 crosses (72
  rings).
- **Triples:** in a ring each pair of adjacent legs implies the skipped
  cross (EURUSD + GBPUSD -> EURGBP); stepping along gives 7 consistent
  triples.
- Operator's candidate: **EUR-USD-GBP-CHF-AUD-NZD-CAD** = EURUSD, GBPUSD,
  GBPCHF, AUDCHF, AUDNZD, NZDCAD, EURCAD (implied: EURGBP, USDCHF, GBPAUD,
  NZDCHF, AUDCAD, EURNZD, USDCAD).
- **The five most different, starting from it** (at most 3 rings can be
  disjoint: 21 / 7; rings 0-2 cover all 21 pairs once; no two of the five
  share more than 3 pairs):

| # | Ring (from USD) | Pairs |
|---|---|---|
| 0 | USD EUR CAD NZD AUD CHF GBP | EURUSD EURCAD NZDCAD AUDNZD AUDCHF GBPCHF GBPUSD |
| 1 | USD CAD AUD GBP NZD EUR CHF | USDCAD AUDCAD GBPAUD GBPNZD EURNZD EURCHF USDCHF |
| 2 | USD AUD EUR GBP CAD CHF NZD | AUDUSD EURAUD EURGBP GBPCAD CADCHF NZDCHF NZDUSD |
| 3 | USD AUD CAD CHF GBP NZD EUR | AUDUSD AUDCAD CADCHF GBPCHF GBPNZD EURNZD EURUSD |
| 4 | USD CAD EUR CHF NZD AUD GBP | USDCAD EURCAD EURCHF NZDCHF AUDNZD GBPAUD GBPUSD |

Shared pairs: 0-3 2, 0-4 3, 1-3 3, 1-4 3, 2-3 2, 2-4 1; 0-1, 0-2, 1-2,
3-4 none.
- **All 21 pairs are quoted on FTMO under plain names** (Market Watch,
  2 Oct close). The close spreads are not representative; Saturday's
  bid/ask dumps give spread by hour and spread vs range per pair.

## 9. PYTHON PORT AND EQUALITY TESTING (C118)

- One engine (layers, adds, exits, deadband, rolls, cap) that knows no
  broker; adapters: a simulated broker (tests), the MetaTrader5 Python
  package (IC and FTMO MT5 from Python on Windows), and any REST venue.
- Equality is judged on LAYER events (entries, exits, rolls, ejections:
  price and time), not orders: the new execution is meant to send
  different orders.
- Operator: no market data needed, "we can just feed in a stream of
  prices": seeded synthetic streams (trend to cap, sawtooth, gaps through
  levels, spread spikes, weekend gap), expected events derived by hand for
  short scripts. Both engines eat the same stream: the EA via a custom
  symbol in Strategy Tester (`CustomTicksAdd`; closest to live), the
  Python side directly. Market data only for the last check against live
  fills (the 2 Oct archive export).
- Port the current logic AS IS and prove equality first; change execution
  second, or a mismatch cannot tell a bug from a design change. Hard part:
  timing (an order placed on one tick fills on a later one; carry at fixed
  times; the 21:00Z broker day).

## 10. CHECKS BEFORE AN ADR

1. Do TP / SL count toward the 200? NOT by email (operator 3 Oct: "no
   emailing ftmo, we gotta keep low profile"): measure it on a spare IC
   demo with `grind_limit_probe.mq5`'s method (positions with TP and SL
   plus pending orders up to the refusal); the 200 is the same MT5
   account setting on both brokers (C78), so the answer is expected to
   carry over to FTMO (inferred).
2. IC demo, a separate account (never the fleets; the desktop terminal is
   logged in to FTMO): does a TP fill at its price or better? A few 0.01
   trades on a weekday.
3. IC: is a netting MT5 demo available (only if (b) is still wanted)?
4. Spreads and ranges of the candidate pairs (Saturday's dumps).

Sequence (Claude's proposal, not ruled): Monday's build as planned; the
checks; an ADR for post-once with TP exits (a) to Gemini; prove it on one
IC fleet against B (requests per round trip ~4.9 -> ~1); then FTMO on one
ring. C118 runs alongside as the test bed.

Line count: 211
