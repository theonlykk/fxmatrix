ROLE: You are an adversarial quantitative auditor (Red Team Prime).
Your sole objective is to find fatal flaws in the proposed fix below.
Do not write implementation code. Hunt for logic failures, race
conditions, edge cases, and constraint violations only.

SYSTEM CONTEXT
--------------
FXMatrix is a native MQL5 Expert Advisor implementing always-on two-sided
market making across EUR/GBP/USD on an FTMO funded demo account. The EA
maintains six passive limit orders simultaneously (bid + offer per
instrument). Orders are refreshed on every M5 bar close (cancel +
resubmit). Between bar closes, a nudge block inside OnTick() monitors
resting order prices and fires TRADE_ACTION_MODIFY if fair value has
drifted beyond NudgeThreshold.

THE PROBLEM
-----------
FTMO flagged the account for exceeding 2,000 API requests per day.
Log analysis confirmed:
- 2,855 accepted TRADE_ACTION_MODIFY requests in one day
- All concentrated in a 20-minute burst (21:05-21:24 EST, NY close)
- Peak rate: 190 modifies/minute
- Min delta between consecutive modifies: 88ms
- EURGBP: 1,614 modifies, GBPUSD: 1,230, EURUSD: 11
- Root cause: nudge block fires on every OnTick() with no rate gate.
  During GBP volatility, the ADR-013 passivity clamp dynamically reads
  current_bid on every tick, causing the clamped price to drift tick by
  tick, triggering TRADE_ACTION_MODIFY at tick rate across all 6 orders.

THE PROPOSED FIX — ADR-016
---------------------------
Introduce one datetime global per instrument:
  datetime g_last_nudge_EURUSD = 0;
  datetime g_last_nudge_GBPUSD = 0;
  datetime g_last_nudge_EURGBP = 0;

In the nudge block inside OnTick(), wrap the TRADE_ACTION_MODIFY call
with a temporal gate:

  if (TimeCurrent() - g_last_nudge_X < 60) continue; // skip this inst

  // existing NudgeThreshold distance check runs here
  // existing TRADE_ACTION_MODIFY fires here
  g_last_nudge_X = TimeCurrent(); // update timestamp on successful modify

Architectural constraints already ruled by Gemini (Staff Architect):
- Throttle interval: exactly 60 seconds (not configurable)
- Scope: nudge block ONLY. Bar-close cancel+resubmit and HandleExitFill
  state transitions are explicitly exempt from this gate
- g_last_nudge_X timers are NEVER zeroed on pod open/close. The 60s
  clock is absolute and lifecycle-agnostic. This is intentional —
  prevents API backdoor via rapid pod cycling during chop events.
- Three discrete globals (not an array) to match existing per-instrument
  global pattern in this codebase

AUDIT TARGETS
-------------
Hunt specifically for:

1. TIMESTAMP SEMANTICS: TimeCurrent() returns broker server time in
   seconds. Is subtraction of two datetime values safe in MQL5? Are
   there edge cases at midnight rollover, DST transitions, or broker
   server time resets that could cause the gate to permanently lock or
   permanently open?

2. FIRST-BAR COLD START: g_last_nudge_X initialised to 0. On EA attach,
   TimeCurrent() - 0 is a large positive number (unix timestamp ~1.7B).
   Does this mean the gate is open on first tick (correct behavior) or
   does it create any overflow/type issue in MQL5 datetime arithmetic?

3. UPDATE TIMING: The proposal updates g_last_nudge_X = TimeCurrent()
   after the OrderSend call. Should it update on send attempt or only
   on confirmed success (checking OrderSend return value)? If OrderSend
   fails, should the timer still advance to prevent retry spam?

4. INTERACTION WITH BAR-CLOSE RESUBMIT: On every M5 bar close, the EA
   cancels all resting orders and places fresh ones with new ticket
   numbers. The nudge block identifies orders by ticket. After bar-close
   resubmit, new tickets are live. Does the 60s timer interact correctly
   with ticket rotation — i.e., could the new ticket be immediately
   nudged before the 60s expires if the timer check happens to pass?

5. INTERACTION WITH HANDLEEXITFILL: When a layer exit fills, Phase 3
   places fresh bid+offer immediately (exempt from throttle per Gemini
   ruling). On the next OnTick() after that placement, the nudge block
   will see a new ticket for that instrument. Is there any scenario where
   the nudge block fires immediately on a Phase 3 fresh quote before
   the 60s gate has expired — contradicting the lifecycle-agnostic
   intent?

6. CONCURRENT INSTRUMENT INDEPENDENCE: The three globals are independent.
   Could a scenario exist where throttling one instrument's nudge
   inadvertently affects another — e.g., through shared loop state or
   the `continue` statement skipping the wrong iteration?

7. ANY OTHER FATAL FLAW not listed above.

OUTPUT FORMAT
-------------
For each audit target: state whether it is a PASS, WARNING, or FATAL.
FATAL = implementation must not proceed without a fix.
WARNING = risk exists but does not block implementation.
PASS = no issue found.
For any FATAL or WARNING: state the exact fix required.
Write zero implementation code.
