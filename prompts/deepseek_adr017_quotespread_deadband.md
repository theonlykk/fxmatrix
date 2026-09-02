ROLE: You are an adversarial quantitative auditor (Red Team Prime).
Your sole objective is to find fatal flaws in the proposed changes below.
Do not write implementation code. Hunt for logic failures, race conditions,
edge cases, and constraint violations only.

SYSTEM CONTEXT
--------------
FXMatrix is a native MQL5 Expert Advisor implementing always-on two-sided
market making across EUR/GBP/USD on an FTMO funded demo account ($10,000,
1:30 leverage). The EA maintains six passive limit orders simultaneously
(bid + offer per instrument). Orders are refreshed on every M5 bar close
(cancel + resubmit). The nudge block has been deleted (ADR-016). The NY
rollover dead zone (23:55-02:05 broker time) gates PlaceEntryLimit calls
(ADR-018). The bar-close loop currently blindly cancels and resubmits all
six quotes every M5 bar regardless of price drift.

CURRENT PARAMETERS RELEVANT TO THIS AUDIT
------------------------------------------
BaseThreshold = 0.0004 (4 bps) — signal measurement gate, LDAK gate input
GridBase      = 0.0008 (8 bps) — grid spacing between layers
QuoteSpread   = NOT YET IMPLEMENTED — this ADR introduces it

ADR-017 PROPOSES THREE INTERLOCKING CHANGES
--------------------------------------------

CHANGE 1 — QuoteSpread Parameter Decoupling
Add new input parameter QuoteSpread (initially 0.0008, sweep at 0.0008 /
0.0010 / 0.0012). Replace BaseThreshold in all quoting math with QuoteSpread:
  bid_spread   = inst_spread + QuoteSpread  (was BaseThreshold)
  offer_spread = inst_spread - BaseThreshold (was BaseThreshold)

QuoteSpread governs execution distance from FairValue. BaseThreshold remains
unchanged as signal measurement gate and LDAK input.

QuoteSpread must be substituted in:
  (a) FXMatrix.mq5 new_bar loop flat-instrument quoting block
  (b) ExecutionEngine.mqh HandleExitFill Phase 3 resume quoting block

Gemini rulings (binding):
- QuoteSpread is independent absolute value, not pegged to BaseThreshold
- Phase 3 resume quoting uses same QuoteSpread (no teaser quotes)
- GridBase geometry does not constrain QuoteSpread

CHANGE 2 — Spatial Deadband on Bar-Close Resubmit
In the new_bar loop, before the cancel-stale-bid block, add:

  double current_bid_price   = (inst_bid   > 0) ? GetPendingOrderPrice(inst_bid)   : -1;
  double current_offer_price = (inst_offer > 0) ? GetPendingOrderPrice(inst_offer) : -1;

  if (current_bid_price   > 0 &&
      current_offer_price > 0 &&
      MathAbs(bid_price   - current_bid_price)   < QuoteSpread * 0.25 &&
      MathAbs(offer_price - current_offer_price) < QuoteSpread * 0.25)
      continue; // quotes still valid — skip cancel+resubmit

Gemini rulings (binding):
- Deadband = QuoteSpread * 0.25 (self-scaling, not a new input parameter)
- Symmetric && operator — if either side breaches, refresh both atomically
- Deadband check must happen BEFORE cancel logic, not after
- Deadband does NOT apply to HandleExitFill Phase 3 resume quoting
- Deadband does NOT apply to the add-next re-arm block

CHANGE 3 — Hard API Counter (g_api_halt)
New globals:
  int  g_daily_api_count = 0;
  bool g_api_halt        = false;

Mechanic: increment g_daily_api_count on every OrderSend returning true.
Tripwire: if g_daily_api_count >= 1800, set g_api_halt = true.
Reset: at broker midnight (same rollover logic as g_daily_start_balance),
       reset g_daily_api_count = 0 and g_api_halt = false.

Degraded state when g_api_halt is true:
- new_bar quote placement blocked entirely (both flat quoting and deadband
  skip are bypassed — EA sits deaf)
- HandleExitFill continues executing (close open risk)
- Cancel-on-pod-close continues executing (orphan prevention)
- ADR-018 rollover gate continues executing

AUDIT TARGETS
-------------
Hunt specifically for:

1. DEADBAND TIMING: The deadband check computes bid_price and offer_price
   from InvertSpreadToPrice() using current bar signals, then compares to
   resting order prices. If the deadband check passes (skip), the EA does
   nothing. If it fails (refresh), it cancels and resubmits. Is there a
   race condition where the signal changes between the deadband check and
   the actual OrderSend placement, causing the new quote to be placed at a
   stale price?

2. DEADBAND + ROLLOVER GATE INTERACTION: ADR-018 gates PlaceEntryLimit
   calls during 23:55-02:05. The deadband check runs BEFORE the cancel
   block. If the deadband check passes (skip) during the rollover window,
   the EA correctly leaves resting quotes in place. But if the deadband
   check fails (refresh needed) during the rollover window, the EA will
   cancel the resting quotes and then the rollover gate will suppress
   PlaceEntryLimit — leaving the instrument with no quotes at all until
   02:05. Is this the correct behavior, or does the deadband check need
   to be aware of the rollover window?

3. DEADBAND + INVENTORY STATE: The deadband check only runs when
   inst_inv_size == 0 (flat instrument). When inventory is open, the
   bar-close loop runs the add-next re-arm logic and then continues.
   Confirm: does the deadband check correctly fire only for flat
   instruments, and does it correctly skip instruments with open inventory?

4. g_api_halt COUNTER SCOPE: The proposal increments g_daily_api_count on
   every OrderSend returning true. FXMatrix uses OrderSend for: (a) limit
   order placement, (b) limit order cancellation (TRADE_ACTION_REMOVE),
   (c) TRADE_ACTION_CLOSE_BY for hedge position closing. Should all three
   count against the daily limit, or only placements? Cancellations consume
   FTMO API quota the same as placements — is it correct to count them?

5. g_api_halt MIDNIGHT RESET INTERACTION: g_daily_start_balance resets at
   broker midnight (CET). The proposed g_api_halt reset uses the same
   trigger. If the EA is halted (g_api_halt = true) and midnight fires,
   the reset clears g_api_halt and the EA immediately resumes quoting.
   Is there a scenario where the midnight reset fires during a volatility
   burst that caused the halt, immediately triggering another burst and
   re-tripping the limit within minutes of reset?

6. g_api_halt DEGRADED STATE — OPEN INVENTORY RISK: When g_api_halt is
   true, flat-instrument quoting is blocked. But if inventory is open on
   an instrument, the add-next re-arm block still runs (it is inside the
   inv_size > 0 branch, which continues before the quoting block). Does
   the add-next re-arm also need to be gated by g_api_halt, or is it
   correct to allow add-next re-arming during halt?

7. QUOTESPREAD SUBSTITUTION COMPLETENESS: QuoteSpread must replace
   BaseThreshold in exactly two locations: (a) new_bar flat quoting loop,
   (b) HandleExitFill Phase 3 resume quoting. Are there any other locations
   in the codebase where BaseThreshold is used as an execution distance
   (rather than as a signal measurement threshold) that would also need
   substitution? Specifically: the nudge block used BaseThreshold as
   NudgeThreshold — but the nudge block was deleted (ADR-016). Confirm
   no residual BaseThreshold execution uses remain.

8. ANY OTHER FATAL FLAW not listed above.

OUTPUT FORMAT
-------------
For each audit target: state whether it is a PASS, WARNING, or FATAL.
FATAL = implementation must not proceed without a fix.
WARNING = risk exists but does not block implementation.
PASS = no issue found.
For any FATAL or WARNING: state the exact fix required.
Write zero implementation code.
